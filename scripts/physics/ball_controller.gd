## BallController
## Attached to the ball's RigidBody3D node.
## Handles shot firing, stop detection, cup detection, and out-of-bounds.
class_name BallController
extends RigidBody3D

signal stroke_ended(final_position: Vector3)
signal ball_holed(strokes: int)
signal shot_fired(direction: Vector3, power: float)
signal out_of_bounds()

const MAX_POWER        := 5.0    # m/s at full power (tuned for minigolf feel)
const MIN_SPEED_CUTOFF := 0.03
const STOP_FRAMES      := 30
const BALL_RADIUS      := 0.04

var strokes: int = 0
var ball_in_motion: bool = false
var _slow_frame_count: int = 0
var _holed: bool = false

func _ready() -> void:
	freeze_mode       = RigidBody3D.FREEZE_MODE_KINEMATIC
	axis_lock_angular_x = true
	axis_lock_angular_z = true
	linear_damp       = 1.2   # rolling resistance on the green
	angular_damp      = 3.0

func _physics_process(_delta: float) -> void:
	if not ball_in_motion or _holed:
		return
	var speed := linear_velocity.length()
	if speed < MIN_SPEED_CUTOFF:
		_slow_frame_count += 1
		if _slow_frame_count >= STOP_FRAMES:
			_declare_stopped()
	else:
		_slow_frame_count = 0

func fire_shot(direction: Vector3, power: float) -> void:
	if ball_in_motion or _holed:
		return
	strokes += 1
	ball_in_motion = true
	_slow_frame_count = 0
	freeze = false
	var impulse := direction.normalized() * (power * MAX_POWER)
	impulse.y = 0.0
	apply_central_impulse(impulse)
	shot_fired.emit(direction, power)

func reset_to(pos: Vector3) -> void:
	freeze = true
	position = pos
	linear_velocity  = Vector3.ZERO
	angular_velocity = Vector3.ZERO
	ball_in_motion   = false
	_slow_frame_count = 0
	_holed  = false
	strokes = 0

func on_entered_cup() -> void:
	if _holed:
		return
	_holed = true
	ball_in_motion = false
	freeze = true
	ball_holed.emit(strokes)

func on_out_of_bounds() -> void:
	if _holed:
		return
	# Count as a penalty stroke and re-emit so Main can respawn the ball
	strokes += 1
	ball_in_motion = false
	linear_velocity  = Vector3.ZERO
	angular_velocity = Vector3.ZERO
	freeze = true
	out_of_bounds.emit()

func _declare_stopped() -> void:
	ball_in_motion    = false
	_slow_frame_count = 0
	linear_velocity   = Vector3.ZERO
	angular_velocity  = Vector3.ZERO
	freeze = true
	stroke_ended.emit(position)
