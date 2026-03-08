## HudController
## Manages the in-game HUD: stroke counter, power bar, shot controls.
## Attached to the HUD scene. Communicates with HoleScene via signals.
class_name HudController
extends CanvasLayer

# ── Signals ───────────────────────────────────────────────────────────────────

## Emitted when the player confirms a shot (direction + power come from aim UI)
signal shot_requested(direction: Vector3, power: float)

## Emitted when the player wants to reset the ball to the tee
signal reset_requested()

## Emitted when the player wants to run a simulation
signal simulation_requested(num_rounds: int)

# ── Node references (set in _ready via $path) ─────────────────────────────────

@onready var stroke_label   : Label        = $MarginContainer/VBox/StrokeLabel
@onready var par_label      : Label        = $MarginContainer/VBox/ParLabel
@onready var power_bar      : ProgressBar  = $MarginContainer/VBox/PowerBar
@onready var status_label   : Label        = $MarginContainer/VBox/StatusLabel
@onready var reset_button   : Button       = $MarginContainer/VBox/ResetButton
@onready var sim_button     : Button       = $MarginContainer/VBox/SimButton
@onready var rounds_spin    : SpinBox      = $MarginContainer/VBox/RoundsSpin
@onready var aim_indicator  : Node2D       = $AimIndicator   # optional overlay

# ── State ─────────────────────────────────────────────────────────────────────

var _current_hole: HoleData = null
var _strokes: int = 0
var _aiming: bool = false
var _aim_start: Vector2 = Vector2.ZERO
var _power: float = 0.5

# ── Godot lifecycle ───────────────────────────────────────────────────────────

func _ready() -> void:
	reset_button.pressed.connect(_on_reset_pressed)
	sim_button.pressed.connect(_on_sim_pressed)
	rounds_spin.value = 500
	_set_status("Click and drag on the green to aim a shot.")

func _unhandled_input(event: InputEvent) -> void:
	# Shot aiming: click-hold sets direction, release fires
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT:
			if event.pressed:
				_aiming    = true
				_aim_start = event.position
			else:
				if _aiming:
					_aiming = false
					_fire_aimed_shot(event.position)

	if _aiming and event is InputEventMouseMotion:
		var drag := (event as InputEventMouseMotion).position - _aim_start
		_power = clampf(drag.length() / 200.0, 0.05, 1.0)
		power_bar.value = _power * 100.0

# ── Public API ────────────────────────────────────────────────────────────────

func set_hole(hole: HoleData) -> void:
	_current_hole = hole
	par_label.text = "Par: %d" % hole.par
	update_strokes(0)

func update_strokes(n: int) -> void:
	_strokes = n
	stroke_label.text = "Strokes: %d" % n

func set_status(text: String) -> void:
	_set_status(text)

func show_holed(strokes: int, par: int) -> void:
	var diff  := strokes - par
	var label := _score_label(strokes, diff)
	_set_status("%s! Hole complete in %d strokes." % [label, strokes])

# ── Internal ──────────────────────────────────────────────────────────────────

func _fire_aimed_shot(release_pos: Vector2) -> void:
	var drag := release_pos - _aim_start
	if drag.length() < 5.0:
		return  # too short, ignore

	# Convert 2D screen drag to 3D XZ direction (camera is top-down-ish)
	# Positive drag.x = right = +X world, positive drag.y = down = +Z world
	var dir3d := Vector3(drag.x, 0.0, drag.y).normalized()
	var power := clampf(drag.length() / 200.0, 0.05, 1.0)

	_set_status("Stroke %d — power %.0f%%" % [_strokes + 1, power * 100.0])
	shot_requested.emit(dir3d, power)

func _on_reset_pressed() -> void:
	reset_requested.emit()
	update_strokes(0)
	_set_status("Ball reset to tee.")

func _on_sim_pressed() -> void:
	var n := int(rounds_spin.value)
	simulation_requested.emit(n)
	_set_status("Running %d simulations…" % n)

func _set_status(text: String) -> void:
	if status_label:
		status_label.text = text

func _score_label(strokes: int, diff: int) -> String:
	if strokes == 1:
		return "Hole-in-one"
	match diff:
		-2: return "Eagle"
		-1: return "Birdie"
		0:  return "Par"
		1:  return "Bogey"
		_:
			if diff >= 2:
				return "Double bogey+"
			return "Eagle"
