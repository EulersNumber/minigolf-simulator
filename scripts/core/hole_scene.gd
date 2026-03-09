## HoleScene
## Runtime controller for a loaded hole.
## Manages geometry, ball, cameras (overview + follow), environment, and kill plane.
class_name HoleScene
extends Node3D

signal hole_completed(strokes: int, par: int)

@onready var hole_geometry  : Node3D             = $HoleGeometry
@onready var ball           : RigidBody3D        = $Ball
@onready var overview_cam   : Camera3D           = $OverviewCamera
@onready var follow_cam     : Camera3D           = $FollowCamera
@onready var sun            : DirectionalLight3D = $Sun
@onready var world_env      : WorldEnvironment   = $WorldEnvironment

var hole_data   : HoleData       = null
var ball_ctrl   : BallController = null

var _last_safe_pos       : Vector3 = Vector3.ZERO
var _cam_mode            : int     = 0
var _follow_cam_pos      : Vector3 = Vector3.ZERO
var _follow_cam_ready    : bool    = false

# ── Lifecycle ─────────────────────────────────────────────────────────────────

func _ready() -> void:
	ball_ctrl = ball as BallController
	if ball_ctrl == null:
		push_error("HoleScene: Ball node missing BallController script.")
		return
	ball_ctrl.stroke_ended.connect(_on_stroke_ended)
	ball_ctrl.ball_holed.connect(_on_ball_holed)
	ball_ctrl.out_of_bounds.connect(_on_out_of_bounds)

	_setup_environment()
	_build_kill_plane()

	overview_cam.current = false
	follow_cam.current   = true
	_cam_mode            = 1

func _process(delta: float) -> void:
	if _cam_mode == 1 and ball_ctrl:
		_update_follow_cam(delta)

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
	_last_safe_pos       = hd.tee_position
	_follow_cam_ready    = false
	_frame_overview(hd)

func reset_ball() -> void:
	if hole_data:
		ball_ctrl.reset_to(hole_data.tee_position)
		_last_safe_pos = hole_data.tee_position

func fire_shot(direction: Vector3, power: float) -> void:
	ball_ctrl.fire_shot(direction, power)

# ── Environment ───────────────────────────────────────────────────────────────

func _setup_environment() -> void:
	var sky_mat := ProceduralSkyMaterial.new()
	sky_mat.sky_top_color        = Color(0.05, 0.14, 0.42)
	sky_mat.sky_horizon_color    = Color(0.58, 0.33, 0.12)
	sky_mat.sky_curve            = 0.12
	sky_mat.ground_bottom_color  = Color(0.10, 0.07, 0.04)
	sky_mat.ground_horizon_color = Color(0.36, 0.20, 0.07)
	sky_mat.sun_angle_max        = 22.0

	var sky := Sky.new()
	sky.sky_material = sky_mat

	var env := Environment.new()
	env.background_mode = Environment.BG_SKY
	env.sky             = sky

	env.ambient_light_source           = Environment.AMBIENT_SOURCE_SKY
	env.ambient_light_sky_contribution = 0.55
	env.ambient_light_color            = Color(1.0, 0.82, 0.62)
	env.ambient_light_energy           = 0.45

	env.glow_enabled           = true
	env.glow_normalized        = false
	env.glow_intensity         = 0.75
	env.glow_bloom             = 0.05
	env.glow_hdr_threshold     = 0.85
	env.glow_hdr_scale         = 2.0
	env.set_glow_level(2, 0.8)
	env.set_glow_level(3, 1.0)
	env.set_glow_level(4, 0.6)

	env.tonemap_mode     = Environment.TONE_MAPPER_FILMIC
	env.tonemap_exposure = 1.1

	env.ssao_enabled   = true
	env.ssao_radius    = 1.2
	env.ssao_intensity = 1.6

	world_env.environment = env

	# Warm Hawaiian sun
	sun.light_color       = Color(1.0, 0.92, 0.75)
	sun.light_energy      = 1.4
	sun.shadow_enabled    = true

# ── Camera ────────────────────────────────────────────────────────────────────

func _toggle_camera() -> void:
	_cam_mode = 1 - _cam_mode
	overview_cam.current = (_cam_mode == 0)
	follow_cam.current   = (_cam_mode == 1)

func _frame_overview(hd: HoleData) -> void:
	var mid      := (hd.tee_position + hd.cup_position) * 0.5
	var dist     := hd.tee_position.distance_to(hd.cup_position)
	var height   := dist * 0.9 + 4.0
	var back_off := dist * 0.35
	overview_cam.position = Vector3(mid.x, height, mid.z + back_off)
	overview_cam.look_at(mid, Vector3.UP)

func _update_follow_cam(delta: float) -> void:
	var ball_pos := ball_ctrl.position
	var cup_pos  := hole_data.cup_position if hole_data else ball_pos + Vector3(0, 0, 5)

	var to_cup := cup_pos - ball_pos
	to_cup.y = 0.0
	if to_cup.length() < 0.1:
		to_cup = Vector3(0, 0, 1)
	var behind     := -to_cup.normalized()
	var target_pos := ball_pos + behind * 2.8 + Vector3(0, 1.4, 0)

	if not _follow_cam_ready:
		_follow_cam_pos   = target_pos
		_follow_cam_ready = true
	else:
		_follow_cam_pos = _follow_cam_pos.lerp(target_pos, 1.0 - pow(0.01, delta))

	follow_cam.position = _follow_cam_pos
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
