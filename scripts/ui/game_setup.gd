## GameSetup
## Configures a new game: mode, players, bots.
class_name GameSetup
extends Node

@onready var mode_option     : OptionButton  = $CenterContainer/Panel/VBox/ModeOption
@onready var bot_section     : VBoxContainer = $CenterContainer/Panel/VBox/BotSection
@onready var local_section   : VBoxContainer = $CenterContainer/Panel/VBox/LocalSection
@onready var bot_count_spin  : SpinBox       = $CenterContainer/Panel/VBox/BotSection/BotCountSpin
@onready var bot_skill_opt   : OptionButton  = $CenterContainer/Panel/VBox/BotSection/BotSkillOption
@onready var bot_style_opt   : OptionButton  = $CenterContainer/Panel/VBox/BotSection/BotStyleOption
@onready var player_list     : VBoxContainer = $CenterContainer/Panel/VBox/LocalSection/PlayerList
@onready var add_player_btn  : Button        = $CenterContainer/Panel/VBox/LocalSection/AddPlayerButton
@onready var start_btn       : Button        = $CenterContainer/Panel/VBox/StartButton
@onready var back_btn        : Button        = $CenterContainer/Panel/VBox/BackButton

const GAME_SCENE := "res://scenes/main.tscn"
const MENU_SCENE := "res://scenes/main_menu.tscn"

var _name_edits: Array[LineEdit] = []

func _ready() -> void:
	mode_option.add_item("vs Bots")
	mode_option.add_item("Local Multiplayer")
	mode_option.item_selected.connect(_on_mode_changed)

	for s in ["Beginner", "Intermediate", "Expert"]:
		bot_skill_opt.add_item(s)
	bot_skill_opt.selected = 1

	for s in ["Aggressive", "Conservative", "Random"]:
		bot_style_opt.add_item(s)

	_add_player_entry("Player 1")

	add_player_btn.pressed.connect(_on_add_player)
	start_btn.pressed.connect(_on_start)
	back_btn.pressed.connect(_on_back)

	_on_mode_changed(0)

func _on_mode_changed(index: int) -> void:
	bot_section.visible   = (index == 0)
	local_section.visible = (index == 1)

func _add_player_entry(default_name: String) -> void:
	if _name_edits.size() >= 4:
		return
	var edit := LineEdit.new()
	edit.text = default_name
	edit.placeholder_text = "Player name"
	player_list.add_child(edit)
	_name_edits.append(edit)

func _on_add_player() -> void:
	_add_player_entry("Player %d" % (_name_edits.size() + 1))

func _on_start() -> void:
	if mode_option.selected == 0:
		# vs Bots
		var skills := ["beginner", "intermediate", "expert"]
		var styles := ["aggressive", "conservative", "random"]
		var skill: String = skills[bot_skill_opt.selected]
		var style: String = styles[bot_style_opt.selected]
		var n      := int(bot_count_spin.value)
		var cfgs: Array[Dictionary] = []
		for _i in n:
			cfgs.append({"skill": skill, "style": style})
		GameState.setup_vs_bots(cfgs)
	else:
		# Local multiplayer
		var names: Array[String] = []
		for e in _name_edits:
			var nm := e.text.strip_edges()
			if nm.length() > 0:
				names.append(nm)
		if names.is_empty():
			names.append("Player 1")
		GameState.setup_local_multi(names)

	get_tree().change_scene_to_file(GAME_SCENE)

func _on_back() -> void:
	get_tree().change_scene_to_file(MENU_SCENE)
