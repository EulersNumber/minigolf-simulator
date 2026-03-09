## HoleBuilder
## Converts HoleData into a live 3D scene node tree.
## Open-world style: no boundary walls — cliff edges drop into lava.
## Obstacle types: "wall" (rock), "cylinder" (volcano)
class_name HoleBuilder
extends RefCounted

# ── Palette ───────────────────────────────────────────────────────────────────

const COLOR_FLOOR      := Color(0.11, 0.50, 0.13)
const COLOR_ROCK       := Color(0.22, 0.18, 0.14)
const COLOR_ROCK_DARK  := Color(0.14, 0.11, 0.08)
const COLOR_CUP        := Color(0.03, 0.03, 0.03)
const COLOR_TEE        := Color(0.90, 0.85, 0.18)
const COLOR_TRUNK      := Color(0.42, 0.27, 0.10)
const COLOR_FROND      := Color(0.10, 0.50, 0.08)
const COLOR_FROND_DARK := Color(0.07, 0.40, 0.06)
const COLOR_LAVA       := Color(0.85, 0.18, 0.01)
const COLOR_LAVA_EMI   := Color(1.00, 0.22, 0.00)

# ── Entry point ───────────────────────────────────────────────────────────────

static func build(hole: HoleData) -> Node3D:
	var root := Node3D.new()
	root.name = hole.hole_name

	_build_lava_ground(root)
	_build_floor(root, hole.floor_segments)
	_build_obstacles(root, hole.obstacles)
	_build_cup(root, hole.cup_position)
	_build_tee_marker(root, hole.tee_position)
	_build_palm_trees(root)
	_build_cliff_rocks(root)

	return root

# ── Lava ground ───────────────────────────────────────────────────────────────

static func _build_lava_ground(parent: Node3D) -> void:
	var inst := MeshInstance3D.new()
	inst.name = "LavaGround"
	var box := BoxMesh.new()
	box.size = Vector3(30.0, 0.2, 36.0)
	inst.mesh = box
	inst.position = Vector3(0.0, -0.22, 12.0)
	inst.material_override = _lava_mat()
	parent.add_child(inst)

# ── Floor (with rot_x ramp support) ──────────────────────────────────────────

static func _build_floor(parent: Node3D, segments: Array[Dictionary]) -> void:
	var container := Node3D.new()
	container.name = "Floor"
	parent.add_child(container)
	for i in segments.size():
		var seg: Dictionary = segments[i]
		var body := _static_box(
			seg["center"], seg["size"],
			seg.get("rot_y", 0.0), seg.get("rot_x", 0.0),
			_flat_mat(COLOR_FLOOR), "floor_%d" % i
		)
		body.add_to_group("floor")
		container.add_child(body)

# ── Obstacles ─────────────────────────────────────────────────────────────────

static func _build_obstacles(parent: Node3D, items: Array[Dictionary]) -> void:
	if items.is_empty():
		return
	var container := Node3D.new()
	container.name = "Obstacles"
	parent.add_child(container)

	for i in items.size():
		var item: Dictionary = items[i]
		var role: String = item.get("role", "")

		if item.get("type", "wall") == "cylinder":
			var mat := _volcano_peak_mat() if role == "volcano_peak" else _rock_mat(0)
			var body := _static_cylinder(
				item.get("pos", Vector3.ZERO),
				float(item.get("radius", 0.5)),
				float(item.get("height", 1.0)),
				mat, "obstacle_%d" % i
			)
			body.add_to_group("obstacle")
			container.add_child(body)

			if role == "volcano_peak":
				var p: Vector3 = item.get("pos", Vector3.ZERO)
				var h: float = float(item.get("height", 1.0))
				_build_volcano_light(container, p, h)
				_build_volcano_smoke(container, p, h)
		else:
			# Rock obstacle
			var body := _static_box(
				item.get("pos", Vector3.ZERO),
				item.get("size", Vector3(0.5, 0.6, 0.5)),
				item.get("rot_y", 0.0), 0.0,
				_rock_mat(i), "obstacle_%d" % i
			)
			body.add_to_group("obstacle")
			container.add_child(body)

static func _build_volcano_light(parent: Node3D, pos: Vector3, h: float) -> void:
	var light := OmniLight3D.new()
	light.name = "LavaGlow"
	light.position = pos + Vector3(0, h + 0.4, 0)
	light.light_color   = Color(1.0, 0.32, 0.04)
	light.light_energy  = 5.0
	light.omni_range    = 8.0
	light.shadow_enabled = true
	parent.add_child(light)

static func _build_volcano_smoke(parent: Node3D, pos: Vector3, h: float) -> void:
	var particles := GPUParticles3D.new()
	particles.name       = "VolcanoSmoke"
	particles.amount     = 32
	particles.lifetime   = 3.5
	particles.preprocess = 1.5
	particles.position   = pos + Vector3(0, h + 0.15, 0)
	particles.visibility_aabb = AABB(Vector3(-3, -1, -3), Vector3(6, 10, 6))

	var mat := ParticleProcessMaterial.new()
	mat.direction            = Vector3(0, 1, 0)
	mat.spread               = 22.0
	mat.initial_velocity_min = 0.35
	mat.initial_velocity_max = 1.0
	mat.gravity              = Vector3(0.06, -0.03, 0)
	mat.scale_min            = 0.09
	mat.scale_max            = 0.26

	var gradient := Gradient.new()
	gradient.set_color(0, Color(0.95, 0.36, 0.04, 0.88))
	gradient.set_color(1, Color(0.28, 0.26, 0.26, 0.00))
	var grad_tex := GradientTexture1D.new()
	grad_tex.gradient = gradient
	mat.color_ramp = grad_tex

	particles.process_material = mat

	var sphere_mesh := SphereMesh.new()
	sphere_mesh.radius = 0.12
	sphere_mesh.height = 0.24
	var smoke_mat := StandardMaterial3D.new()
	smoke_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	smoke_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	smoke_mat.vertex_color_use_as_albedo = true
	sphere_mesh.material = smoke_mat

	particles.draw_pass_1 = sphere_mesh
	parent.add_child(particles)

# ── Palm trees ────────────────────────────────────────────────────────────────

static func _build_palm_trees(parent: Node3D) -> void:
	var positions := [
		Vector3(-3.4, 0.0,  3.2),
		Vector3( 3.8, 0.0,  6.5),
		Vector3(-4.0, 0.0, 13.0),
		Vector3( 3.5, 0.9, 16.5),
		Vector3(-3.8, 0.9, 20.5),
		Vector3( 3.2, 0.9, 23.5),
	]
	for i in positions.size():
		_build_palm(parent, positions[i], i)

static func _build_palm(parent: Node3D, pos: Vector3, seed: int) -> void:
	var tree := Node3D.new()
	tree.name = "Palm_%d" % seed
	tree.position = pos

	var rng := RandomNumberGenerator.new()
	rng.seed = uint32(seed * 7919 + 13)

	# Trunk — tapered cylinder with slight lean
	var trunk := MeshInstance3D.new()
	var trunk_cyl := CylinderMesh.new()
	trunk_cyl.top_radius    = 0.06
	trunk_cyl.bottom_radius = 0.13
	trunk_cyl.height        = 3.2
	trunk_cyl.radial_segments = 8
	trunk.mesh = trunk_cyl
	trunk.position = Vector3(0, 1.6, 0)
	var lean_z := 4.0 + float(seed % 4) * 2.5
	var lean_y := float(seed) * 53.7
	trunk.rotation_degrees = Vector3(0, lean_y, lean_z)
	trunk.material_override = _flat_mat(COLOR_TRUNK)
	tree.add_child(trunk)

	# Frond origin at trunk top (approximate, accounting for lean)
	var lean_rad := deg_to_rad(lean_z)
	var top_y    := 3.2 * cos(lean_rad)
	var top_x    := 3.2 * sin(lean_rad) * sin(deg_to_rad(lean_y))
	var top_z    := 3.2 * sin(lean_rad) * cos(deg_to_rad(lean_y))
	var frond_origin := Vector3(top_x, top_y, top_z)

	# 8 fronds spreading from trunk top
	var num_fronds := 8
	for f in num_fronds:
		var angle_y   := float(f) / float(num_fronds) * TAU + rng.randf() * 0.3
		var droop     := deg_to_rad(32.0 + rng.randf() * 18.0)
		var frond_len := 1.25 + rng.randf() * 0.45

		# World-space direction of this frond
		var fwd := Vector3(
			cos(angle_y) * cos(droop),
			-sin(droop),
			sin(angle_y) * cos(droop)
		).normalized()

		# Perpendicular (frond width axis — horizontal)
		var right := Vector3(-sin(angle_y), 0.0, cos(angle_y)).normalized()
		var up    := right.cross(fwd).normalized()

		# Primary frond (long, narrow leaf)
		var frond := MeshInstance3D.new()
		var box   := BoxMesh.new()
		box.size  = Vector3(0.10, 0.025, frond_len)
		frond.mesh = box
		frond.position = frond_origin + fwd * (frond_len * 0.5)
		frond.basis    = Basis(right, up, fwd)
		frond.material_override = _flat_mat(COLOR_FROND)
		tree.add_child(frond)

		# Secondary frond between primaries (smaller, offset angle)
		if f % 2 == 0:
			var a2    := angle_y + TAU / float(num_fronds) * 0.5
			var d2    := deg_to_rad(38.0 + rng.randf() * 12.0)
			var len2  := frond_len * 0.70
			var fwd2  := Vector3(cos(a2)*cos(d2), -sin(d2), sin(a2)*cos(d2)).normalized()
			var r2    := Vector3(-sin(a2), 0.0, cos(a2)).normalized()
			var u2    := r2.cross(fwd2).normalized()
			var frond2 := MeshInstance3D.new()
			var box2   := BoxMesh.new()
			box2.size  = Vector3(0.08, 0.02, len2)
			frond2.mesh = box2
			frond2.position = frond_origin + fwd2 * (len2 * 0.5)
			frond2.basis    = Basis(r2, u2, fwd2)
			frond2.material_override = _flat_mat(COLOR_FROND_DARK)
			tree.add_child(frond2)

	parent.add_child(tree)

# ── Cliff rocks (natural border decoration + collision) ───────────────────────

static func _build_cliff_rocks(parent: Node3D) -> void:
	# Left cliff edge
	_rock_cluster(parent, Vector3(-3.2,  0.0,  2.5), 1)
	_rock_cluster(parent, Vector3(-3.0,  0.0,  7.5), 2)
	_rock_cluster(parent, Vector3(-3.5,  0.0, 12.0), 3)
	_rock_cluster(parent, Vector3(-3.2,  0.9, 16.5), 4)
	_rock_cluster(parent, Vector3(-3.4,  0.9, 22.0), 5)
	# Right cliff edge
	_rock_cluster(parent, Vector3( 3.3,  0.0,  1.5), 6)
	_rock_cluster(parent, Vector3( 3.1,  0.0,  5.5), 7)
	_rock_cluster(parent, Vector3( 3.5,  0.0, 10.5), 8)
	_rock_cluster(parent, Vector3( 3.2,  0.9, 19.0), 9)
	_rock_cluster(parent, Vector3( 3.5,  0.9, 23.5), 10)
	# Behind tee
	_rock_cluster(parent, Vector3( 0.0, 0.0, -1.5), 11)
	# Far end beyond cup
	_rock_cluster(parent, Vector3( 0.0, 0.9, 25.5), 12)

static func _rock_cluster(parent: Node3D, center: Vector3, seed: int) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = uint32(seed * 3571 + 97)
	var count := 3 + seed % 3
	for i in count:
		var offset := Vector3(rng.randf_range(-0.6, 0.6), 0, rng.randf_range(-0.5, 0.5))
		var pos    := center + offset
		var w      := rng.randf_range(0.35, 0.85)
		var h      := rng.randf_range(0.4, 1.4)
		var d      := rng.randf_range(0.35, 0.80)
		var ry     := rng.randf_range(-45.0, 45.0)

		# Visual only for background rocks (no collision, purely decorative)
		var inst := MeshInstance3D.new()
		inst.name = "CliffRock_%d_%d" % [seed, i]
		var box  := BoxMesh.new()
		box.size = Vector3(w, h, d)
		inst.mesh = box
		inst.position = pos + Vector3(0, h * 0.5, 0)
		inst.rotation_degrees = Vector3(rng.randf_range(-8, 8), ry, rng.randf_range(-8, 8))
		var shade := rng.randf_range(0.0, 1.0)
		inst.material_override = _rock_mat(int(shade * 10))
		parent.add_child(inst)

# ── Cup ───────────────────────────────────────────────────────────────────────

static func _build_cup(parent: Node3D, pos: Vector3) -> void:
	var cup_body := StaticBody3D.new()
	cup_body.name = "Cup"
	cup_body.position = pos
	cup_body.add_to_group("cup")

	var mesh_inst := MeshInstance3D.new()
	var cyl := CylinderMesh.new()
	cyl.top_radius = 0.22;  cyl.bottom_radius = 0.22;  cyl.height = 0.05
	mesh_inst.mesh = cyl
	mesh_inst.material_override = _flat_mat(COLOR_CUP)
	cup_body.add_child(mesh_inst)

	var pole := MeshInstance3D.new()
	var pole_cyl := CylinderMesh.new()
	pole_cyl.top_radius = 0.015;  pole_cyl.bottom_radius = 0.015;  pole_cyl.height = 0.85
	pole.mesh = pole_cyl
	pole.position = Vector3(0.0, 0.47, 0.0)
	pole.material_override = _flat_mat(Color(0.88, 0.88, 0.88))
	cup_body.add_child(pole)

	var flag := MeshInstance3D.new()
	var flag_box := BoxMesh.new()
	flag_box.size = Vector3(0.28, 0.16, 0.01)
	flag.mesh = flag_box
	flag.position = Vector3(0.14, 0.82, 0.0)
	flag.material_override = _flat_mat(Color(0.95, 0.12, 0.12))
	cup_body.add_child(flag)

	var area := Area3D.new()
	area.name = "CupArea"
	var col := CollisionShape3D.new()
	var shape := CylinderShape3D.new()
	shape.radius = 0.22;  shape.height = 0.15
	col.shape = shape
	area.add_child(col)
	area.add_to_group("cup_area")
	cup_body.add_child(area)

	parent.add_child(cup_body)

# ── Tee marker ────────────────────────────────────────────────────────────────

static func _build_tee_marker(parent: Node3D, pos: Vector3) -> void:
	var marker := Node3D.new()
	marker.name = "TeeMarker"
	marker.position = pos
	marker.add_to_group("tee_marker")

	var mi := MeshInstance3D.new()
	var disc := CylinderMesh.new()
	disc.top_radius = 0.14;  disc.bottom_radius = 0.14;  disc.height = 0.01
	mi.mesh = disc
	mi.material_override = _flat_mat(COLOR_TEE)
	marker.add_child(mi)
	parent.add_child(marker)

# ── Static body helpers ───────────────────────────────────────────────────────

static func _static_box(
	pos: Vector3, size: Vector3, rot_y: float, rot_x: float,
	mat: StandardMaterial3D, node_name: String
) -> StaticBody3D:
	var body := StaticBody3D.new()
	body.name = node_name
	body.position = pos
	body.rotation_degrees = Vector3(rot_x, rot_y, 0.0)

	var mi := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = size
	mi.mesh = box
	mi.material_override = mat
	body.add_child(mi)

	var col := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = size
	col.shape = shape
	body.add_child(col)
	return body

static func _static_cylinder(
	pos: Vector3, radius: float, height: float,
	mat: StandardMaterial3D, node_name: String
) -> StaticBody3D:
	var body := StaticBody3D.new()
	body.name = node_name
	body.position = pos + Vector3(0.0, height * 0.5, 0.0)

	var mi := MeshInstance3D.new()
	var cyl := CylinderMesh.new()
	cyl.top_radius = radius;  cyl.bottom_radius = radius;  cyl.height = height
	mi.mesh = cyl
	mi.material_override = mat
	body.add_child(mi)

	var col := CollisionShape3D.new()
	var shape := CylinderShape3D.new()
	shape.radius = radius;  shape.height = height
	col.shape = shape
	body.add_child(col)
	return body

# ── Materials ─────────────────────────────────────────────────────────────────

static func _flat_mat(color: Color) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.roughness    = 0.82
	mat.metallic     = 0.0
	return mat

static func _rock_mat(index: int) -> StandardMaterial3D:
	# Vary between dark browns/grays for natural rock look
	var shades := [
		Color(0.22, 0.18, 0.14),
		Color(0.18, 0.15, 0.11),
		Color(0.26, 0.21, 0.16),
		Color(0.15, 0.12, 0.09),
		Color(0.20, 0.17, 0.13),
	]
	var color := shades[index % shades.size()]
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.roughness    = 0.92
	mat.metallic     = 0.0
	return mat

static func _volcano_peak_mat() -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color               = Color(0.95, 0.18, 0.02)
	mat.emission_enabled           = true
	mat.emission                   = Color(1.0, 0.25, 0.0)
	mat.emission_energy_multiplier = 3.5
	mat.roughness                  = 0.75
	return mat

static func _lava_mat() -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color               = COLOR_LAVA
	mat.emission_enabled           = true
	mat.emission                   = COLOR_LAVA_EMI
	mat.emission_energy_multiplier = 1.8
	mat.roughness                  = 0.90
	return mat
