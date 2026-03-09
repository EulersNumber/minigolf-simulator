## HoleBuilder
## Converts HoleData into a live 3D scene node tree.
## Supports obstacle types: "wall", "cylinder"
## Adds world decoration: lava ground, palm trees, volcano lighting + particles.
class_name HoleBuilder
extends RefCounted

# ── Palette ───────────────────────────────────────────────────────────────────

const COLOR_FLOOR    := Color(0.11, 0.52, 0.14)   # tropical green felt
const COLOR_WALL     := Color(0.20, 0.16, 0.10)   # dark volcanic rock
const COLOR_BOUNDARY := Color(0.16, 0.12, 0.08)
const COLOR_CUP      := Color(0.03, 0.03, 0.03)
const COLOR_TEE      := Color(0.90, 0.85, 0.18)
const COLOR_TRUNK    := Color(0.38, 0.24, 0.10)
const COLOR_CANOPY   := Color(0.09, 0.44, 0.11)
const COLOR_LAVA     := Color(0.85, 0.18, 0.01)
const COLOR_LAVA_EMI := Color(1.00, 0.22, 0.00)

# ── Entry point ───────────────────────────────────────────────────────────────

static func build(hole: HoleData) -> Node3D:
	var root := Node3D.new()
	root.name = hole.hole_name

	_build_lava_ground(root)
	_build_floor(root, hole.floor_segments)
	_build_obstacles(root, hole.obstacles)
	_build_walls(root, hole.boundary_walls)
	_build_cup(root, hole.cup_position)
	_build_tee_marker(root, hole.tee_position)
	_build_palm_trees(root)

	return root

# ── World decoration ──────────────────────────────────────────────────────────

static func _build_lava_ground(parent: Node3D) -> void:
	var inst := MeshInstance3D.new()
	inst.name = "LavaGround"
	var box := BoxMesh.new()
	box.size = Vector3(26.0, 0.15, 32.0)
	inst.mesh = box
	inst.position = Vector3(0.0, -0.18, 12.0)
	inst.material_override = _lava_mat()
	parent.add_child(inst)

static func _build_palm_trees(parent: Node3D) -> void:
	var positions := [
		Vector3(-3.3, 0.0,  3.0),
		Vector3( 3.6, 0.0,  7.0),
		Vector3(-3.8, 0.0, 13.5),
		Vector3( 3.3, 0.0, 17.5),
		Vector3(-3.5, 0.0, 21.5),
		Vector3( 3.1, 0.0, 23.0),
	]
	for i in positions.size():
		_build_palm(parent, positions[i], i)

static func _build_palm(parent: Node3D, pos: Vector3, index: int) -> void:
	var tree := Node3D.new()
	tree.name = "Palm_%d" % index
	tree.position = pos

	# Trunk — slight random lean per tree
	var trunk_inst := MeshInstance3D.new()
	var trunk_mesh := CylinderMesh.new()
	trunk_mesh.top_radius    = 0.06
	trunk_mesh.bottom_radius = 0.11
	trunk_mesh.height        = 2.6
	trunk_inst.mesh = trunk_mesh
	trunk_inst.position = Vector3(0, 1.3, 0)
	trunk_inst.rotation_degrees = Vector3(0, float(index) * 37.0, 5.0 + float(index % 3) * 3.0)
	trunk_inst.material_override = _flat_mat(COLOR_TRUNK)
	tree.add_child(trunk_inst)

	# Canopy
	var canopy_inst := MeshInstance3D.new()
	var canopy_mesh := SphereMesh.new()
	canopy_mesh.radius = 0.95
	canopy_mesh.height = 1.5
	canopy_inst.mesh = canopy_mesh
	canopy_inst.position = Vector3(0.3, 2.7, 0)
	canopy_inst.material_override = _flat_mat(COLOR_CANOPY)
	tree.add_child(canopy_inst)

	parent.add_child(tree)

# ── Floor ─────────────────────────────────────────────────────────────────────

static func _build_floor(parent: Node3D, segments: Array[Dictionary]) -> void:
	var container := Node3D.new()
	container.name = "Floor"
	parent.add_child(container)
	for i in segments.size():
		var seg: Dictionary = segments[i]
		var body := _static_box(
			seg["center"], seg["size"], seg.get("rot_y", 0.0),
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
			var mat := _volcano_peak_mat() if role == "volcano_peak" else _flat_mat(COLOR_WALL)
			var body := _static_cylinder(
				item.get("pos", Vector3.ZERO),
				float(item.get("radius", 0.5)),
				float(item.get("height", 1.0)),
				mat, "obstacle_%d" % i
			)
			body.add_to_group("obstacle")
			container.add_child(body)

			# Lava glow light + smoke on peak only
			if role == "volcano_peak":
				var peak_pos: Vector3 = item.get("pos", Vector3.ZERO)
				var peak_h: float     = float(item.get("height", 1.0))
				_build_volcano_light(container, peak_pos, peak_h)
				_build_volcano_smoke(container, peak_pos, peak_h)
		else:
			var body := _static_box(
				item.get("pos", Vector3.ZERO),
				item.get("size", Vector3(0.2, 0.5, 1.0)),
				item.get("rot_y", 0.0),
				_flat_mat(COLOR_WALL), "obstacle_%d" % i
			)
			body.add_to_group("obstacle")
			container.add_child(body)

static func _build_volcano_light(parent: Node3D, pos: Vector3, peak_height: float) -> void:
	var light := OmniLight3D.new()
	light.name = "LavaGlow"
	light.position = pos + Vector3(0, peak_height + 0.5, 0)
	light.light_color  = Color(1.0, 0.32, 0.04)
	light.light_energy = 4.5
	light.omni_range   = 7.0
	light.shadow_enabled = true
	parent.add_child(light)

static func _build_volcano_smoke(parent: Node3D, pos: Vector3, peak_height: float) -> void:
	var particles := GPUParticles3D.new()
	particles.name     = "VolcanoSmoke"
	particles.amount   = 28
	particles.lifetime = 3.2
	particles.preprocess = 1.5
	particles.position = pos + Vector3(0, peak_height + 0.2, 0)
	particles.visibility_aabb = AABB(Vector3(-3, -1, -3), Vector3(6, 10, 6))

	var mat := ParticleProcessMaterial.new()
	mat.direction            = Vector3(0, 1, 0)
	mat.spread               = 20.0
	mat.initial_velocity_min = 0.4
	mat.initial_velocity_max = 1.1
	mat.gravity              = Vector3(0.08, -0.04, 0)
	mat.scale_min            = 0.08
	mat.scale_max            = 0.24

	var gradient := Gradient.new()
	gradient.set_color(0, Color(0.95, 0.38, 0.05, 0.90))
	gradient.set_color(1, Color(0.30, 0.28, 0.28, 0.00))
	var grad_tex := GradientTexture1D.new()
	grad_tex.gradient = gradient
	mat.color_ramp = grad_tex

	particles.process_material = mat

	var sphere_mesh := SphereMesh.new()
	sphere_mesh.radius = 0.12
	sphere_mesh.height = 0.24
	var smoke_mat := StandardMaterial3D.new()
	smoke_mat.transparency  = BaseMaterial3D.TRANSPARENCY_ALPHA
	smoke_mat.shading_mode  = BaseMaterial3D.SHADING_MODE_UNSHADED
	smoke_mat.albedo_color  = Color(1, 1, 1, 1)
	smoke_mat.vertex_color_use_as_albedo = true
	sphere_mesh.material = smoke_mat

	particles.draw_pass_1 = sphere_mesh
	parent.add_child(particles)

# ── Boundary walls ────────────────────────────────────────────────────────────

static func _build_walls(parent: Node3D, items: Array[Dictionary]) -> void:
	if items.is_empty():
		return
	var container := Node3D.new()
	container.name = "BoundaryWalls"
	parent.add_child(container)
	for i in items.size():
		var item: Dictionary = items[i]
		var body := _static_box(
			item.get("pos", Vector3.ZERO),
			item.get("size", Vector3(0.2, 0.5, 1.0)),
			item.get("rot_y", 0.0),
			_flat_mat(COLOR_BOUNDARY), "boundary_%d" % i
		)
		body.add_to_group("boundary")
		container.add_child(body)

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

	# Flag pole
	var pole := MeshInstance3D.new()
	var pole_cyl := CylinderMesh.new()
	pole_cyl.top_radius = 0.015;  pole_cyl.bottom_radius = 0.015;  pole_cyl.height = 0.85
	pole.mesh = pole_cyl
	pole.position = Vector3(0.0, 0.47, 0.0)
	pole.material_override = _flat_mat(Color(0.88, 0.88, 0.88))
	cup_body.add_child(pole)

	# Flag
	var flag := MeshInstance3D.new()
	var flag_box := BoxMesh.new()
	flag_box.size = Vector3(0.28, 0.16, 0.01)
	flag.mesh = flag_box
	flag.position = Vector3(0.14, 0.82, 0.0)
	flag.material_override = _flat_mat(Color(0.95, 0.12, 0.12))
	cup_body.add_child(flag)

	# Detection area
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

# ── Tee ───────────────────────────────────────────────────────────────────────

static func _build_tee_marker(parent: Node3D, pos: Vector3) -> void:
	var marker := Node3D.new()
	marker.name = "TeeMarker"
	marker.position = pos
	marker.add_to_group("tee_marker")

	var mesh_inst := MeshInstance3D.new()
	var disc := CylinderMesh.new()
	disc.top_radius = 0.14;  disc.bottom_radius = 0.14;  disc.height = 0.01
	mesh_inst.mesh = disc
	mesh_inst.material_override = _flat_mat(COLOR_TEE)
	marker.add_child(mesh_inst)
	parent.add_child(marker)

# ── Static body helpers ───────────────────────────────────────────────────────

static func _static_box(
	pos: Vector3, size: Vector3, rot_y: float,
	mat: StandardMaterial3D, node_name: String
) -> StaticBody3D:
	var body := StaticBody3D.new()
	body.name = node_name
	body.position = pos
	body.rotation_degrees.y = rot_y

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

static func _volcano_peak_mat() -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color              = Color(0.95, 0.18, 0.02)
	mat.emission_enabled          = true
	mat.emission                  = Color(1.0, 0.25, 0.0)
	mat.emission_energy_multiplier = 3.5
	mat.roughness                 = 0.75
	return mat

static func _lava_mat() -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color              = COLOR_LAVA
	mat.emission_enabled          = true
	mat.emission                  = COLOR_LAVA_EMI
	mat.emission_energy_multiplier = 1.8
	mat.roughness                 = 0.90
	return mat
