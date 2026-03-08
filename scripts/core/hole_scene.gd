## HoleScene
## Runtime controller for a loaded hole.
## Manages geometry, ball, cameras (overview + follow), and OOB kill plane.
class_name HoleScene
extends Node3D

signal hole_completed(strokes: int, par: int)

@onready var hole_geometry  : Node3D      = $HoleGeometry
@onready var ball           : RigidBody3D = $Ball
@onready var overview_cam   : Camera3D    = $OverviewCamera
@onready var follow_cam     : Camera3D    = $FollowCamera

var hole_data   : HoleData       = null
var ball_ctrl   : BallController = null

var _last_safe_pos : Vector3 = Vector3.ZERO
var _cam_mode      : int     = 0   # 0 = overview, 1 = follow

# ── Lifecycle ─────────────────────────────────────────────────────────────────

func _ready() -> void:
	ball_ctrl = ball as BallController
	if ball_ctrl == null:
		push_error("HoleScene: Ball node missing BallController script.")
		return
	ball_ctrl.stroke_ended.connect(_on_stroke_ended)
	ball_ctrl.ball_holed.connect(_on_ball_holed)
	ball_ctrl.out_of_bounds.connect(_on_out_of_bounds)

	_build_kill_plane()

	overview_cam.current = true
	follow_cam.current   = false

func _process(_delta: float) -> void:
	if _cam_mode == 1 and ball_ctrl:
		_update_follow_cam()

func _unhandled_key_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed:
		if event.keycode == KEY_C:
			_toggle_camera()

# ── Public API ────────────────────────────────────────────────────────────────

func load_hole(hd: HoleData) -> void:
	hole_data = hd
	for child in hole_geometry.get_children():
		child.queue_free()
	var built := HoleBuilder.build(hd)
	hole_geometry.add_child(built)

	var cup_area := _find_cup_area(built)
	if cup_area:
		cup_area.body_entered.connect(_on_cup_area_body_entered)

	ball_ctrl.reset_to(hd.tee_position)
	_last_safe_pos = hd.tee_position
	_frame_overview(hd)

func reset_ball() -> void:
	if hole_data:
		ball_ctrl.reset_to(hole_data.tee_position)
		_last_safe_pos = hole_data.tee_position

func fire_shot(direction: Vector3, power: float) -> void:
	ball_ctrl.fire_shot(direction, power)

# ── Camera ────────────────────────────────────────────────────────────────────

func _toggle_camera() -> void:
	_cam_mode = 1 - _cam_mode
	overview_cam.current = (_cam_mode == 0)
	follow_cam.current   = (_cam_mode == 1)

func _frame_overview(hd: HoleData) -> void:
	var mid  := (hd.tee_position + hd.cup_position) * 0.5
	var dist := hd.tee_position.distance_to(hd.cup_position)
	var height   := dist * 0.9 + 4.0
	var back_off := dist * 0.35
	overview_cam.position = Vector3(mid.x, height, mid.z + back_off)
	overview_cam.look_at(mid, Vector3.UP)

func _update_follow_cam() -> void:
	var ball_pos := ball_ctrl.position
	var cup_pos  := hole_data.cup_position if hole_data else ball_pos + Vector3(0, 0, 5)

	var to_cup := cup_pos - ball_pos
	to_cup.y = 0.0
	if to_cup.length() < 0.1:
		to_cup = Vector3(0, 0, 1)
	var behind := -to_cup.normalized()

	follow_cam.position = ball_pos + behind * 2.8 + Vector3(0, 1.4, 0)
	follow_cam.look_at(ball_pos + Vector3(0, 0.15, 0), Vector3.UP)

# ── Kill plane ────────────────────────────────────────────────────────────────

func _build_kill_plane() -> void:
	var area := Area3D.new()
	area.name = "KillPlane"
	var col := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(200.0, 0.5, 200.0)
	col.shape = box
	area.add_child(col)
	area.position = Vector3(0, -3.0, 0)
	area.body_entered.connect(_on_kill_plane_entered)
	add_child(area)

func _on_kill_plane_entered(body: Node3D) -> void:
	if body == ball:
		ball_ctrl.on_out_of_bounds()

# ── Event handlers ────────────────────────────────────────────────────────────

func _on_stroke_ended(final_pos: Vector3) -> void:
	_last_safe_pos = final_pos

func _on_ball_holed(strokes: int) -> void:
	hole_completed.emit(strokes, hole_data.par if hole_data else 3)

func _on_out_of_bounds() -> void:
	# Respawn at last safe position, preserving stroke count
	var saved_strokes := ball_ctrl.strokes
	ball_ctrl.reset_to(_last_safe_pos)
	ball_ctrl.strokes = saved_strokes

func _on_cup_area_body_entered(body: Node3D) -> void:
	if body == ball:
		ball_ctrl.on_entered_cup()

# ── Helpers ───────────────────────────────────────────────────────────────────

func _find_cup_area(geometry: Node3D) -> Area3D:
	for child in geometry.get_children():
		if child.name == "Cup":
			for sub in child.get_children():
				if sub is Area3D:
					return sub as Area3D
		var found := _find_cup_area(child)
		if found:
			return found
	return null
