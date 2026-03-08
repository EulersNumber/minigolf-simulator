## HudController
## In-game HUD: player name, stroke counter, power bar, buttons.
class_name HudController
extends CanvasLayer

signal shot_requested(direction: Vector3, power: float)
signal reset_requested()
signal simulation_requested(num_rounds: int)
signal help_requested()
signal standings_requested()

@onready var player_label   : Label       = $Panel/VBox/PlayerLabel
@onready var par_label      : Label       = $Panel/VBox/ParLabel
@onready var stroke_label   : Label       = $Panel/VBox/StrokeLabel
@onready var power_bar      : ProgressBar = $Panel/VBox/PowerBar
@onready var status_label   : Label       = $Panel/VBox/StatusLabel
@onready var reset_button   : Button      = $Panel/VBox/ResetButton
@onready var help_button    : Button      = $Panel/VBox/HelpButton
@onready var standings_btn  : Button      = $Panel/VBox/StandingsButton
@onready var sim_label      : Label       = $Panel/VBox/SimLabel
@onready var rounds_spin    : SpinBox     = $Panel/VBox/RoundsSpin
@onready var sim_button     : Button      = $Panel/VBox/SimButton

var _aiming    : bool    = false
var _aim_start : Vector2 = Vector2.ZERO
var _power     : float   = 0.5
var _strokes   : int     = 0

func _ready() -> void:
	reset_button.pressed.connect(func() -> void: reset_requested.emit())
	help_button.pressed.connect(func() -> void: help_requested.emit())
	standings_btn.pressed.connect(func() -> void: standings_requested.emit())
	sim_button.pressed.connect(_on_sim_pressed)
	rounds_spin.value = 500
	set_status("Drag to aim.")

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mbe := event as InputEventMouseButton
		if mbe.button_index == MOUSE_BUTTON_LEFT:
			if mbe.pressed:
				_aiming    = true
				_aim_start = mbe.position
			elif _aiming:
				_aiming = false
				_fire_aimed_shot(mbe.position)

	if _aiming and event is InputEventMouseMotion:
		var drag := (event as InputEventMouseMotion).position - _aim_start
		_power = clampf(drag.length() / 200.0, 0.05, 1.0)
		power_bar.value = _power * 100.0

# ── Public API ────────────────────────────────────────────────────────────────

func set_hole(hole: HoleData) -> void:
	par_label.text = "Par: %d" % hole.par
	update_strokes(0)

func set_player(name: String) -> void:
	player_label.text = name

func update_strokes(n: int) -> void:
	_strokes = n
	stroke_label.text = "Strokes: %d" % n

func set_status(text: String) -> void:
	if status_label:
		status_label.text = text

func set_sim_visible(visible_flag: bool) -> void:
	sim_label.visible   = visible_flag
	rounds_spin.visible = visible_flag
	sim_button.visible  = visible_flag

# ── Internal ──────────────────────────────────────────────────────────────────

func _fire_aimed_shot(release_pos: Vector2) -> void:
	var drag := release_pos - _aim_start
	if drag.length() < 5.0:
		return
	var dir3d := Vector3(drag.x, 0.0, drag.y).normalized()
	var power := clampf(drag.length() / 200.0, 0.05, 1.0)
	set_status("Stroke %d — power %.0f%%" % [_strokes + 1, power * 100.0])
	shot_requested.emit(dir3d, power)

func _on_sim_pressed() -> void:
	simulation_requested.emit(int(rounds_spin.value))
