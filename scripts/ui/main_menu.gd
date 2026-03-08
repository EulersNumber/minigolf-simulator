## MainMenu
## Top-level menu screen controller.
class_name MainMenu
extends Node

@onready var new_game_btn : Button = $CenterContainer/VBox/NewGameButton
@onready var practice_btn : Button = $CenterContainer/VBox/PracticeButton
@onready var quit_btn     : Button = $CenterContainer/VBox/QuitButton

const SETUP_SCENE := "res://scenes/ui/game_setup.tscn"
const GAME_SCENE  := "res://scenes/main.tscn"

func _ready() -> void:
	new_game_btn.pressed.connect(_on_new_game)
	practice_btn.pressed.connect(_on_practice)
	quit_btn.pressed.connect(_on_quit)

func _on_new_game() -> void:
	get_tree().change_scene_to_file(SETUP_SCENE)

func _on_practice() -> void:
	GameState.setup_practice()
	get_tree().change_scene_to_file(GAME_SCENE)

func _on_quit() -> void:
	get_tree().quit()
