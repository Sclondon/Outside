class_name GameMenu
extends Control
## A small menu behind a button in the top right corner (or Esc): swap between
## the full and demade models, change level, restart. The game pauses while it
## is open.

const LEVELS := [
	["The tomb", "res://main.tscn"],
	["Test yard", "res://mechanics.tscn"],
	["Hound run", "res://test_course.tscn"],
]

var _panel: PanelContainer


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	mouse_filter = Control.MOUSE_FILTER_IGNORE

	var open := _button("Menu", func() -> void: _set_open(not _panel.visible))
	open.modulate.a = 0.55
	open.anchor_left = 1.0
	open.anchor_right = 1.0
	open.offset_left = -118.0
	open.offset_right = -14.0
	open.offset_top = 12.0
	open.offset_bottom = 54.0
	add_child(open)

	_panel = PanelContainer.new()
	_panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	_panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_panel.grow_vertical = Control.GROW_DIRECTION_BOTH
	_panel.visible = false
	add_child(_panel)
	var margin := MarginContainer.new()
	for edge: String in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + edge, 22)
	_panel.add_child(margin)
	var list := VBoxContainer.new()
	list.add_theme_constant_override("separation", 10)
	list.custom_minimum_size.x = 340.0
	margin.add_child(list)

	list.add_child(_heading("Look"))
	list.add_child(_button("Figures: demade (low poly)" if Settings.low_poly else "Figures: full detail", _swap_models))
	list.add_child(_button("World: banded light" if Settings.world_banded else "World: smooth light", _swap_world))
	list.add_child(_heading("Level"))
	for level: Array in LEVELS:
		list.add_child(_button(level[0], _go_to.bind(level[1])))
	list.add_child(_button("Restart this level", _restart))
	list.add_child(_button("Close", func() -> void: _set_open(false)))


func _input(event: InputEvent) -> void:
	if event.is_action_pressed(&"ui_cancel"):
		_set_open(not _panel.visible)
		get_viewport().set_input_as_handled()


func _set_open(open: bool) -> void:
	_panel.visible = open
	get_tree().paused = open


func _swap_models() -> void:
	Settings.low_poly = not Settings.low_poly
	_restart()


func _swap_world() -> void:
	Settings.world_banded = not Settings.world_banded
	_restart()


func _restart() -> void:
	get_tree().paused = false
	get_tree().reload_current_scene()


func _go_to(scene: String) -> void:
	get_tree().paused = false
	get_tree().change_scene_to_file(scene)


func _button(text: String, pressed: Callable) -> Button:
	var button := Button.new()
	button.text = text
	button.focus_mode = Control.FOCUS_NONE
	button.custom_minimum_size.y = 46.0
	button.add_theme_font_size_override("font_size", 20)
	button.pressed.connect(pressed)
	return button


func _heading(text: String) -> Label:
	var label := Label.new()
	label.text = text.to_upper()
	label.modulate.a = 0.6
	label.add_theme_font_size_override("font_size", 14)
	return label
