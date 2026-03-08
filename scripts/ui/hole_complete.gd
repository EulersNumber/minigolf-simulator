## HoleComplete
## Overlay shown after a player finishes the hole.
## Shows their score and the full scoreboard.
class_name HoleComplete
extends CanvasLayer

@onready var panel         : PanelContainer = $PanelContainer
@onready var title_label   : Label          = $PanelContainer/VBox/TitleLabel
@onready var score_label   : Label          = $PanelContainer/VBox/ScoreLabel
@onready var scoreboard    : Label          = $PanelContainer/VBox/Scoreboard
@onready var continue_btn  : Button         = $PanelContainer/VBox/ContinueButton
@onready var menu_btn      : Button         = $PanelContainer/VBox/MenuButton

signal continue_requested()
signal menu_requested()

func _ready() -> void:
	panel.visible = false
	continue_btn.pressed.connect(func() -> void:
		panel.visible = false
		continue_requested.emit()
	)
	menu_btn.pressed.connect(func() -> void:
		menu_requested.emit()
	)

## Show result for a player.
## all_done = true means every player has now finished — show "Game Over" UI.
func show_result(
	player_name: String,
	strokes: int,
	par: int,
	all_players: Array,
	all_done: bool
) -> void:
	title_label.text = _score_word(strokes, strokes - par)
	score_label.text  = "%s — %d strokes  (par %d)" % [player_name, strokes, par]

	var lines: Array[String] = ["Scoreboard:"]
	for p in all_players:
		var s: int = p["score"]
		var s_str: String = str(s) if s >= 0 else "—"
		lines.append("  %s: %s" % [p["name"], s_str])
	scoreboard.text = "\n".join(lines)

	continue_btn.text    = "Main Menu" if all_done else "Next Player"
	continue_btn.visible = true
	panel.visible = true

func _score_word(strokes: int, diff: int) -> String:
	if strokes == 1:
		return "Hole in One!"
	match diff:
		-3: return "Albatross!"
		-2: return "Eagle!"
		-1: return "Birdie!"
		0:  return "Par"
		1:  return "Bogey"
		2:  return "Double Bogey"
		_:
			if diff >= 3:
				return "Triple Bogey+"
			return "Eagle!"
