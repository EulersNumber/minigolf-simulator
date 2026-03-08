## HoleScene
## The runtime controller for a loaded/built hole.
## Wires together: HoleData → HoleBuilder → physics ball → HUD → simulation.
class_name HoleScene
extends Node3D

# ── Signals ───────────────────────────────────────────────────────────────────

signal hole_completed(strokes: int, par: int)

# ── Node refs ─────────────────────────────────────────────────────────────────

@onready var hole_geometry : Node3D      = $HoleGeometry
@onready var ball          : RigidBody3D = $Ball
@onready var camera        : Camera3D    = $Camera3D

# ── State ─────────────────────────────────────────────────────────────────────

var hole_data   : HoleData      = null
var ball_ctrl   : BallController = null

# ── Lifecycle ─────────────────────────────────────────────────────────────────

func _ready() -> void:
	ball_ctrl = ball as BallController
	if ball_ctrl == null:
		push_error("HoleScene: Ball node does not have BallController script.")
		return
	ball_ctrl.stroke_ended.connect(_on_stroke_ended)
	ball_ctrl.ball_holed.connect(_on_ball_holed)

## Load and display a hole from HoleData.
func load_hole(hd: HoleData) -> void:
	hole_data = hd

	# Clear old geometry
	for child in hole_geometry.get_children():
		child.queue_free()

	# Build new geometry
	var built := HoleBuilder.build(hd)
	hole_geometry.add_child(built)

	# Connect cup area
	var cup_area := _find_cup_area(built)
	if cup_area:
		cup_area.body_entered.connect(_on_cup_area_body_entered)

	# Place ball at tee
	ball_ctrl.reset_to(hd.tee_position)

	# Frame camera on the hole
	_frame_camera(hd)

func reset_ball() -> void:
	if hole_data:
		ball_ctrl.reset_to(hole_data.tee_position)

func fire_shot(direction: Vector3, power: float) -> void:
	ball_ctrl.fire_shot(direction, power)

# ── Camera framing ────────────────────────────────────────────────────────────

func _frame_camera(hd: HoleData) -> void:
	# Compute midpoint between tee and cup
	var mid := (hd.tee_position + hd.cup_position) * 0.5
	var dist := hd.tee_position.distance_to(hd.cup_position)

	# Angled top-down view looking at midpoint
	var height   := dist * 0.9 + 4.0
	var back_off := dist * 0.4

	camera.position = Vector3(mid.x, height, mid.z + back_off)
	camera.look_at(mid, Vector3.UP)

# ── Event handlers ────────────────────────────────────────────────────────────

func _on_stroke_ended(final_pos: Vector3) -> void:
	# Notify HUD via Main (signals bubble up)
	pass  # HUD listens to ball_ctrl directly in Main

func _on_ball_holed(strokes: int) -> void:
	hole_completed.emit(strokes, hole_data.par if hole_data else 3)

func _on_cup_area_body_entered(body: Node3D) -> void:
	if body == ball:
		ball_ctrl.on_entered_cup()

# ── Helpers ───────────────────────────────────────────────────────────────────

func _find_cup_area(geometry: Node3D) -> Area3D:
	# Depth-first search for the cup Area3D
	for child in geometry.get_children():
		if child.name == "Cup":
			for sub in child.get_children():
				if sub is Area3D:
					return sub as Area3D
		var found := _find_cup_area(child)
		if found:
			return found
	return null
