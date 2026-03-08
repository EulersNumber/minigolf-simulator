## Main
## Top-level scene controller. Wires HUD ↔ HoleScene ↔ SimRunner.
## Responsible for loading holes, handling input, running simulations.
extends Node3D

# ── Node refs ─────────────────────────────────────────────────────────────────

@onready var hole_scene     : Node3D      = $HoleScene
@onready var hud            : CanvasLayer = $HUD
@onready var sim_results    : CanvasLayer = $SimResults

var _hole_scene_ctrl : HoleScene    = null
var _hud_ctrl        : HudController = null
var _results_ctrl    : ResultsDisplay = null

var _current_hole    : HoleData = null
var _current_bot     : BotPlayer = null

# ── Lifecycle ─────────────────────────────────────────────────────────────────

func _ready() -> void:
	_hole_scene_ctrl = hole_scene as HoleScene
	_hud_ctrl        = hud        as HudController
	_results_ctrl    = sim_results as ResultsDisplay

	# Wire HUD signals
	_hud_ctrl.shot_requested.connect(_on_shot_requested)
	_hud_ctrl.reset_requested.connect(_on_reset_requested)
	_hud_ctrl.simulation_requested.connect(_on_simulation_requested)

	# Wire hole scene signals
	_hole_scene_ctrl.hole_completed.connect(_on_hole_completed)

	# Wire ball controller signals for stroke updates
	var ball_ctrl := _hole_scene_ctrl.ball_ctrl
	if ball_ctrl:
		ball_ctrl.stroke_ended.connect(_on_stroke_ended)
		ball_ctrl.ball_holed.connect(_on_ball_holed_visual)

	# Load default hole
	_load_hole_by_template("straight_classic")

	# Default bot (intermediate aggressive)
	_current_bot = BotPlayer.create("intermediate", "aggressive")

func _unhandled_key_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed:
		match event.keycode:
			KEY_R:
				_on_reset_requested()
			KEY_1:
				_load_hole_by_template("straight_classic")
			KEY_2:
				_load_hole_by_template("dogleg_left")
			KEY_3:
				_load_hole_by_template("s_bend")
			KEY_4:
				_load_hole_by_template("island_green")
			KEY_G:
				# Quick: generate a fresh straight hole procedurally
				var h := HoleGenerator.generate("straight")
				_load_hole(h)

# ── Hole loading ──────────────────────────────────────────────────────────────

func _load_hole_by_template(name: String) -> void:
	var h := SaveLoad.load_hole("res://data/templates/%s.json" % name)
	if h == null:
		# Fall back to procedural generator
		h = HoleGenerator.generate(name)
	_load_hole(h)

func _load_hole(hd: HoleData) -> void:
	_current_hole = hd
	_hole_scene_ctrl.load_hole(hd)
	_hud_ctrl.set_hole(hd)
	_hud_ctrl.set_status("Hole: %s  (par %d) — drag to aim." % [hd.hole_name, hd.par])

# ── Signal handlers ───────────────────────────────────────────────────────────

func _on_shot_requested(direction: Vector3, power: float) -> void:
	_hole_scene_ctrl.fire_shot(direction, power)

func _on_reset_requested() -> void:
	_hole_scene_ctrl.reset_ball()
	_hud_ctrl.update_strokes(0)

func _on_stroke_ended(_final_pos: Vector3) -> void:
	var ball_ctrl := _hole_scene_ctrl.ball_ctrl
	if ball_ctrl:
		_hud_ctrl.update_strokes(ball_ctrl.strokes)

func _on_ball_holed_visual(strokes: int) -> void:
	_hud_ctrl.show_holed(strokes, _current_hole.par if _current_hole else 3)

func _on_hole_completed(strokes: int, par: int) -> void:
	print("Hole completed: %d strokes (par %d)" % [strokes, par])

func _on_simulation_requested(num_rounds: int) -> void:
	if _current_hole == null:
		_hud_ctrl.set_status("No hole loaded.")
		return

	_hud_ctrl.set_status("Simulating %d rounds…" % num_rounds)

	# Run all 9 bot types and collect comparison data
	var results := {}
	for skill in BotProfiles.all_skill_names():
		for style in BotProfiles.all_style_names():
			var bot := BotPlayer.create(skill, style)
			results[bot.display_name()] = SimRunner.run(bot, _current_hole, num_rounds)

	_results_ctrl.show_comparison(results)
	_hud_ctrl.set_status("Simulation complete.")
