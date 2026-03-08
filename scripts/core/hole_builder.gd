## HoleBuilder
## Converts HoleData into a live 3D scene node tree.
## Supports obstacle types: "wall", "cylinder" (for volcano etc.)
class_name HoleBuilder
extends RefCounted

const COLOR_FLOOR      := Color(0.13, 0.55, 0.13)   # tropical green felt
const COLOR_WALL       := Color(0.22, 0.18, 0.12)   # dark volcanic rock
const COLOR_BOUNDARY   := Color(0.18, 0.14, 0.10)   # darker rock
const COLOR_CUP        := Color(0.04, 0.04, 0.04)
const COLOR_TEE        := Color(0.90, 0.85, 0.20)   # yellow marker
const COLOR_LAVA_FLOOR := Color(0.90, 0.25, 0.05)   # lava orange (hazard tiles)
const COLOR_RAMP       := Color(0.72, 0.62, 0.45)   # sandy timber ramp

# ── Entry point ───────────────────────────────────────────────────────────────

static func build(hole: HoleData) -> Node3D:
	var root := Node3D.new()
	root.name = hole.hole_name

	_build_floor(root, hole.floor_segments)
	_build_obstacles(root, hole.obstacles)
	_build_walls(root, hole.boundary_walls, "boundary")
	_build_cup(root, hole.cup_position)
	_build_tee_marker(root, hole.tee_position)

	return root

# ── Floor ─────────────────────────────────────────────────────────────────────

static func _build_floor(parent: Node3D, segments: Array[Dictionary]) -> void:
	var container := Node3D.new()
	container.name = "Floor"
	parent.add_child(container)

	for i in segments.size():
		var seg: Dictionary = segments[i]
		var color := COLOR_LAVA_FLOOR if seg.get("lava", false) else COLOR_FLOOR
		var body := _static_box(
			seg["center"], seg["size"], seg.get("rot_y", 0.0), color, "floor_%d" % i
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
		var obstacle_type: String = item.get("type", "wall")
		if obstacle_type == "cylinder":
			var body := _static_cylinder(
				item.get("pos", Vector3.ZERO),
				float(item.get("radius", 0.5)),
				float(item.get("height", 1.0)),
				_cylinder_color(item),
				"obstacle_%d" % i
			)
			body.add_to_group("obstacle")
			container.add_child(body)
		elif obstacle_type == "ramp":
			var body := _static_ramp(
				item.get("pos", Vector3.ZERO),
				item.get("size", Vector3(2.0, 0.05, 2.0)),
				float(item.get("rot_y", 0.0)),
				float(item.get("slope_angle", 15.0)),
				"obstacle_%d" % i
			)
			body.add_to_group("obstacle")
			body.add_to_group("ramp")
			container.add_child(body)
		else:
			var body := _static_box(
				item.get("pos", Vector3.ZERO),
				item.get("size", Vector3(0.2, 0.5, 1.0)),
				item.get("rot_y", 0.0),
				COLOR_WALL,
				"obstacle_%d" % i
			)
			body.add_to_group("obstacle")
			container.add_child(body)

static func _cylinder_color(item: Dictionary) -> Color:
	var role: String = item.get("role", "")
	match role:
		"volcano_base": return Color(0.25, 0.22, 0.20)   # dark rock
		"volcano_peak": return Color(0.80, 0.20, 0.05)   # glowing lava red
		_:              return COLOR_WALL

# ── Boundary walls ────────────────────────────────────────────────────────────

static func _build_walls(parent: Node3D, items: Array[Dictionary], group: String) -> void:
	if items.is_empty():
		return
	var container := Node3D.new()
	container.name = group.capitalize() + "s"
	parent.add_child(container)

	for i in items.size():
		var item: Dictionary = items[i]
		var body := _static_box(
			item.get("pos", Vector3.ZERO),
			item.get("size", Vector3(0.2, 0.5, 1.0)),
			item.get("rot_y", 0.0),
			COLOR_BOUNDARY,
			"%s_%d" % [group, i]
		)
		body.add_to_group(group)
		container.add_child(body)

# ── Cup ───────────────────────────────────────────────────────────────────────

static func _build_cup(parent: Node3D, pos: Vector3) -> void:
	var cup_body := StaticBody3D.new()
	cup_body.name = "Cup"
	cup_body.position = pos
	cup_body.add_to_group("cup")

	var mesh_inst := MeshInstance3D.new()
	var cyl := CylinderMesh.new()
	cyl.top_radius    = 0.22
	cyl.bottom_radius = 0.22
	cyl.height        = 0.05
	mesh_inst.mesh = cyl
	mesh_inst.material_override = _flat_material(COLOR_CUP)
	cup_body.add_child(mesh_inst)

	# Flag pole
	var pole := MeshInstance3D.new()
	var pole_cyl := CylinderMesh.new()
	pole_cyl.top_radius    = 0.015
	pole_cyl.bottom_radius = 0.015
	pole_cyl.height        = 0.8
	pole.mesh = pole_cyl
	pole.position = Vector3(0.0, 0.45, 0.0)
	pole.material_override = _flat_material(Color(0.85, 0.85, 0.85))
	cup_body.add_child(pole)

	# Flag
	var flag := MeshInstance3D.new()
	var flag_box := BoxMesh.new()
	flag_box.size = Vector3(0.25, 0.15, 0.01)
	flag.mesh = flag_box
	flag.position = Vector3(0.125, 0.8, 0.0)
	flag.material_override = _flat_material(Color(0.95, 0.15, 0.15))
	cup_body.add_child(flag)

	# Detection area
	var area := Area3D.new()
	area.name = "CupArea"
	var col := CollisionShape3D.new()
	var cyl_shape := CylinderShape3D.new()
	cyl_shape.radius = 0.22
	cyl_shape.height = 0.15
	col.shape = cyl_shape
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

	var mesh_inst := MeshInstance3D.new()
	var disc := CylinderMesh.new()
	disc.top_radius    = 0.14
	disc.bottom_radius = 0.14
	disc.height        = 0.01
	mesh_inst.mesh = disc
	mesh_inst.material_override = _flat_material(COLOR_TEE)
	marker.add_child(mesh_inst)
	parent.add_child(marker)

# ── Static body helpers ───────────────────────────────────────────────────────

static func _static_box(
	pos: Vector3, size: Vector3, rot_y_deg: float, color: Color, node_name: String
) -> StaticBody3D:
	var body := StaticBody3D.new()
	body.name = node_name
	body.position = pos
	body.rotation_degrees.y = rot_y_deg

	var mesh_inst := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = size
	mesh_inst.mesh = box
	mesh_inst.material_override = _flat_material(color)
	body.add_child(mesh_inst)

	var col := CollisionShape3D.new()
	var box_shape := BoxShape3D.new()
	box_shape.size = size
	col.shape = box_shape
	body.add_child(col)

	return body

static func _static_cylinder(
	pos: Vector3, radius: float, height: float, color: Color, node_name: String
) -> StaticBody3D:
	var body := StaticBody3D.new()
	body.name = node_name
	body.position = pos + Vector3(0.0, height * 0.5, 0.0)

	var mesh_inst := MeshInstance3D.new()
	var cyl := CylinderMesh.new()
	cyl.top_radius    = radius
	cyl.bottom_radius = radius
	cyl.height        = height
	mesh_inst.mesh = cyl
	mesh_inst.material_override = _flat_material(color)
	body.add_child(mesh_inst)

	var col := CollisionShape3D.new()
	var cyl_shape := CylinderShape3D.new()
	cyl_shape.radius = radius
	cyl_shape.height = height
	col.shape = cyl_shape
	body.add_child(col)

	return body

## Build a ramp: a box tilted by slope_angle degrees around its local X axis.
## The high end faces -Z in local space; slope_dir in XZ sets the downhill direction.
static func _static_ramp(
	pos: Vector3, size: Vector3, rot_y_deg: float, slope_angle_deg: float, node_name: String
) -> StaticBody3D:
	var body := StaticBody3D.new()
	body.name = node_name
	body.position = pos
	body.rotation_degrees.y = rot_y_deg

	var mesh_inst := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = size
	mesh_inst.mesh = box
	mesh_inst.material_override = _flat_material(COLOR_RAMP)
	mesh_inst.rotation_degrees.x = -slope_angle_deg
	body.add_child(mesh_inst)

	var col := CollisionShape3D.new()
	var box_shape := BoxShape3D.new()
	box_shape.size = size
	col.shape = box_shape
	col.rotation_degrees.x = -slope_angle_deg
	body.add_child(col)

	return body

static func _flat_material(color: Color) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.roughness    = 0.80
	mat.metallic     = 0.0
	return mat
