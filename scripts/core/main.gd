## Main
## Top-level scene controller.
## Manages multi-player turn rotation, wires HUD ↔ HoleScene ↔ overlays.
extends Node3D

@onready var hole_scene_node : Node3D      = $HoleScene
@onready var hud             : CanvasLayer = $HUD
@onready var hole_complete   : CanvasLayer = $HoleComplete
@onready var help_overlay    : CanvasLayer = $HelpOverlay

var _hole_scene_ctrl : HoleScene     = null
var _hud_ctrl        : HudController = null
var _complete_ctrl   : HoleComplete  = null
var _help_ctrl       : HelpOverlay   = null
var _current_hole    : HoleData      = null

const HAWAII_PATH := "res://data/templates/hawaii.json"
const MENU_SCENE  := "res://scenes/main_menu.tscn"

# ── Lifecycle ─────────────────────────────────────────────────────────────────

func _ready() -> void:
	_hole_scene_ctrl = hole_scene_node as HoleScene
	_hud_ctrl        = hud             as HudController
	_complete_ctrl   = hole_complete   as HoleComplete
	_help_ctrl       = help_overlay    as HelpOverlay

	# Fallback for running game scene directly during development
	if GameState.players.is_empty():
		GameState.setup_practice()

	_current_hole = SaveLoad.load_hole(HAWAII_PATH)
	if _current_hole == null:
		push_error("Main: Failed to load hawaii.json!")
		return

	# Wire signals
	_hud_ctrl.shot_requested.connect(_on_shot_requested)
	_hud_ctrl.reset_requested.connect(_on_reset_requested)
	_hud_ctrl.help_requested.connect(func() -> void: _help_ctrl.toggle())
	_hud_ctrl.standings_requested.connect(_on_standings_requested)
	_hud_ctrl.simulation_requested.connect(_on_simulation_requested)

	_hole_scene_ctrl.hole_completed.connect(_on_hole_completed)

	var ball_ctrl := _hole_scene_ctrl.ball_ctrl
	if ball_ctrl:
		ball_ctrl.stroke_ended.connect(_on_stroke_ended)
		ball_ctrl.out_of_bounds.connect(_on_ball_oob)

	_complete_ctrl.continue_requested.connect(_on_continue)
	_complete_ctrl.menu_requested.connect(_on_menu)

	_start_current_turn()

func _unhandled_key_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed:
		match event.keycode:
			KEY_R:
				_on_reset_requested()
			KEY_ESCAPE:
				_on_menu()

# ── Turn management ───────────────────────────────────────────────────────────

func _start_current_turn() -> void:
	var player := GameState.current_player()
	if player.is_empty():
		return

	_hole_scene_ctrl.load_hole(_current_hole)
	_hud_ctrl.set_hole(_current_hole)
	_hud_ctrl.set_player(player["name"])
	_hud_ctrl.update_strokes(0)

	# Show/hide sim button based on mode
	var is_practice := GameState.mode == GameState.GameMode.PRACTICE
	_hud_ctrl.set_sim_visible(is_practice)

	if player["is_bot"]:
		_run_bot_turn(player)
	else:
		_hud_ctrl.set_status("Drag to aim — good luck, %s!" % player["name"])

func _run_bot_turn(player: Dictionary) -> void:
	_hud_ctrl.set_status("%s is playing…" % player["name"])
	var bot    := BotPlayer.from_profile(player["bot_profile"])
	var detail := SimRunner.run_detailed(bot, _current_hole, 1)
	var strokes := 15  # DNF default
	if not detail["rounds"].is_empty():
		var round_data: Dictionary = detail["rounds"][0]
		strokes = round_data["strokes"]
		if not round_data["holed"]:
			strokes = 15
	_finish_turn(strokes)

func _finish_turn(strokes: int) -> void:
	var player   := GameState.current_player()
	var all_done := GameState.record_score_and_advance(strokes)
	_complete_ctrl.show_result(
		player["name"], strokes, _current_hole.par, GameState.players, all_done
	)

func _on_continue() -> void:
	# If all_done was true the overlay button said "Main Menu", so this means
	# either "next player" or going back to menu (handled by menu_requested signal)
	_start_current_turn()

func _on_menu() -> void:
	GameState.reset()
	get_tree().change_scene_to_file(MENU_SCENE)

# ── Signal handlers ───────────────────────────────────────────────────────────

func _on_shot_requested(direction: Vector3, power: float) -> void:
	var player := GameState.current_player()
	if player.get("is_bot", false):
		return
	_hole_scene_ctrl.fire_shot(direction, power)

func _on_reset_requested() -> void:
	_hole_scene_ctrl.reset_ball()
	_hud_ctrl.update_strokes(0)

func _on_stroke_ended(_final_pos: Vector3) -> void:
	var ball_ctrl := _hole_scene_ctrl.ball_ctrl
	if ball_ctrl:
		_hud_ctrl.update_strokes(ball_ctrl.strokes)

func _on_ball_oob() -> void:
	var ball_ctrl := _hole_scene_ctrl.ball_ctrl
	if ball_ctrl:
		_hud_ctrl.update_strokes(ball_ctrl.strokes)
		_hud_ctrl.set_status("Out of bounds! +1 penalty. Stroke %d." % ball_ctrl.strokes)

func _on_hole_completed(strokes: int, _par: int) -> void:
	_finish_turn(strokes)

func _on_standings_requested() -> void:
	if _current_hole:
		_hud_ctrl.set_status(GameState.all_scores_summary(_current_hole.par))

func _on_simulation_requested(num_rounds: int) -> void:
	if _current_hole == null or GameState.mode != GameState.GameMode.PRACTICE:
		return
	_hud_ctrl.set_status("Simulating %d rounds…" % num_rounds)
	var results := {}
	for skill in BotProfiles.all_skill_names():
		for style in BotProfiles.all_style_names():
			var bot := BotPlayer.create(skill, style)
			results[bot.display_name()] = SimRunner.run(bot, _current_hole, num_rounds)
	_hud_ctrl.set_status("Done. Best: %s" % _best_bot(results))

func _best_bot(results: Dictionary) -> String:
	var best_name := ""
	var best_rate := -1.0
	for name in results:
		var rate: float = results[name].get("completion_rate", 0.0)
		if rate > best_rate:
			best_rate = rate
			best_name = name
	return "%s (%.0f%% completion)" % [best_name, best_rate * 100.0]
