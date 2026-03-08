## HoleBuilder
## Converts a HoleData resource into a live 3D scene node tree.
## Returns a Node3D containing all floor, obstacle, boundary, cup, and tee nodes.
class_name HoleBuilder
extends RefCounted

# Material colours (simple StandardMaterial3D, no textures needed)
const COLOR_FLOOR    := Color(0.18, 0.50, 0.18)   # green felt
const COLOR_WALL     := Color(0.55, 0.40, 0.25)   # wood brown
const COLOR_BOUNDARY := Color(0.30, 0.22, 0.14)   # darker wood
const COLOR_RAMP     := Color(0.65, 0.50, 0.30)   # light wood
const COLOR_CUP      := Color(0.05, 0.05, 0.05)   # near-black

# ── Entry point ───────────────────────────────────────────────────────────────

## Builds and returns a Node3D hierarchy from hole data.
## Attach the returned node to your scene tree.
static func build(hole: HoleData) -> Node3D:
	var root := Node3D.new()
	root.name = hole.hole_name

	_build_floor(root, hole.floor_segments)
	_build_walls(root, hole.obstacles, "obstacle")
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
		var body := _static_box(
			seg["center"],
			seg["size"],
			seg.get("rot_y", 0.0),
			COLOR_FLOOR,
			"floor_%d" % i
		)
		body.add_to_group("floor")
		container.add_child(body)

# ── Walls & obstacles ─────────────────────────────────────────────────────────

static func _build_walls(parent: Node3D, items: Array[Dictionary], group: String) -> void:
	if items.is_empty():
		return
	var container := Node3D.new()
	container.name = group.capitalize() + "s"
	parent.add_child(container)

	var color := COLOR_BOUNDARY if group == "boundary" else COLOR_WALL

	for i in items.size():
		var item: Dictionary = items[i]
		var body := _static_box(
			item.get("pos", Vector3.ZERO),
			item.get("size", Vector3(0.2, 0.5, 1.0)),
			item.get("rot_y", 0.0),
			color,
			"%s_%d" % [group, i]
		)
		body.add_to_group(group)
		container.add_child(body)

# ── Cup ───────────────────────────────────────────────────────────────────────

static func _build_cup(parent: Node3D, pos: Vector3) -> void:
	# Visual cup (dark cylinder)
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

	# Detection area (slightly larger than visual)
	var area := Area3D.new()
	area.name = "CupArea"
	var shape_owner := area
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
	disc.top_radius    = 0.12
	disc.bottom_radius = 0.12
	disc.height        = 0.01
	mesh_inst.mesh = disc
	mesh_inst.material_override = _flat_material(Color(0.9, 0.9, 0.1))
	marker.add_child(mesh_inst)

	parent.add_child(marker)

# ── Helpers ───────────────────────────────────────────────────────────────────

static func _static_box(
	pos: Vector3,
	size: Vector3,
	rot_y_deg: float,
	color: Color,
	node_name: String
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

static func _flat_material(color: Color) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.roughness = 0.85
	mat.metallic  = 0.0
	return mat
