## ResultsDisplay
## Shows simulation results in a panel overlay.
## Populated by SimRunner stats dict + optional per-round data.
class_name ResultsDisplay
extends CanvasLayer

@onready var panel        : PanelContainer = $PanelContainer
@onready var title_label  : Label          = $PanelContainer/VBox/TitleLabel
@onready var stats_label  : Label          = $PanelContainer/VBox/StatsLabel
@onready var close_button : Button         = $PanelContainer/VBox/CloseButton
@onready var bot_tabs     : TabContainer   = $PanelContainer/VBox/BotTabs

func _ready() -> void:
	panel.visible = false
	close_button.pressed.connect(hide_results)

## Show results for a single bot.
func show_single(bot_name: String, stats: Dictionary) -> void:
	title_label.text = "Simulation Results — %s" % bot_name
	stats_label.text = SimStats.format(stats)
	_clear_tabs()
	panel.visible = true

## Show a comparison of multiple bots.
func show_comparison(results: Dictionary) -> void:
	title_label.text = "Bot Comparison"
	stats_label.text = ""
	_clear_tabs()

	for bot_name in results:
		var tab_label := Label.new()
		tab_label.text = SimStats.format(results[bot_name])
		tab_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		bot_tabs.add_child(tab_label)
		# TabContainer uses the node name as the tab title
		tab_label.name = bot_name

	panel.visible = true

func hide_results() -> void:
	panel.visible = false

func _clear_tabs() -> void:
	for child in bot_tabs.get_children():
		child.queue_free()
