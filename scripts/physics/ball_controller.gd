## BallController
## Attached to the ball's RigidBody3D node in the visual scene.
## Handles:
##   - Receiving shots (direction + power)
##   - Detecting when the ball stops (stroke complete)
##   - Detecting when the ball enters the cup
##   - Emitting signals for the HUD and game manager
class_name BallController
extends RigidBody3D

# ── Signals ───────────────────────────────────────────────────────────────────

## Emitted when the ball comes to rest after a stroke
signal stroke_ended(final_position: Vector3)

## Emitted when the ball enters the cup
signal ball_holed(strokes: int)

## Emitted when a shot is fired
signal shot_fired(direction: Vector3, power: float)

# ── Constants ─────────────────────────────────────────────────────────────────

const MAX_POWER        := 12.0   # m/s at full power
const MIN_SPEED_CUTOFF := 0.04   # ball considered stopped below this speed
const STOP_FRAMES      := 30     # frames ball must be slow before declaring stopped
const BALL_RADIUS      := 0.04   # metres (regulation ~42mm)

# ── State ─────────────────────────────────────────────────────────────────────

var strokes: int = 0
var ball_in_motion: bool = false
var _slow_frame_count: int = 0
var _holed: bool = false

# ── Godot lifecycle ───────────────────────────────────────────────────────────

func _ready() -> void:
	# Lock rotation on X/Z to keep ball from tumbling unrealistically
	# (treat it as a smooth sphere — no spin effect in MVP)
	freeze_mode = RigidBody3D.FREEZE_MODE_KINEMATIC
	axis_lock_angular_x = true
	axis_lock_angular_z = true

	# Connect cup detection — done by the HoleScene after building
	# (see HoleScene._on_cup_area_body_entered)

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

# ── Public API ────────────────────────────────────────────────────────────────

## Fire a shot. direction is a normalised Vector3 in the XZ plane.
## power is 0.0–1.0 (fraction of MAX_POWER).
func fire_shot(direction: Vector3, power: float) -> void:
	if ball_in_motion or _holed:
		return
	strokes += 1
	ball_in_motion = true
	_slow_frame_count = 0
	freeze = false

	var impulse := direction.normalized() * (power * MAX_POWER)
	# Keep in XZ plane (no vertical launch from flat ground)
	impulse.y = 0.0
	apply_central_impulse(impulse)
	shot_fired.emit(direction, power)

## Reset ball to a position and clear state.
func reset_to(pos: Vector3) -> void:
	freeze = true
	position = pos
	linear_velocity  = Vector3.ZERO
	angular_velocity = Vector3.ZERO
	ball_in_motion = false
	_slow_frame_count = 0
	_holed = false
	strokes = 0

## Called by HoleScene when the ball enters the cup Area3D.
func on_entered_cup() -> void:
	if _holed:
		return
	_holed = true
	ball_in_motion = false
	freeze = true
	ball_holed.emit(strokes)

# ── Internal ──────────────────────────────────────────────────────────────────

func _declare_stopped() -> void:
	ball_in_motion = false
	_slow_frame_count = 0
	linear_velocity  = Vector3.ZERO
	angular_velocity = Vector3.ZERO
	freeze = true
	stroke_ended.emit(position)
