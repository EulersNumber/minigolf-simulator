## HelpOverlay
## In-game help popup showing controls and scoring reference.
class_name HelpOverlay
extends CanvasLayer

@onready var panel     : PanelContainer = $PanelContainer
@onready var close_btn : Button         = $PanelContainer/VBox/CloseButton

func _ready() -> void:
	panel.visible = false
	close_btn.pressed.connect(func() -> void: panel.visible = false)

func toggle() -> void:
	panel.visible = not panel.visible
