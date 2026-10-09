class_name GameMenu
extends Control
## A small menu behind a button in the top right corner (or Esc): swap between
## the full and demade models, change level, restart, and turn the boy out: his
## face, the cut and colour of his hair, his skin, what he wears and the colour
## of each thing, his cap on or off, or all of it at random. The game pauses
## while it is open; it sits to one side, so he can be seen while he is dressed.
##
## What there is to choose from is in CharacterLook (scripts/character_look.gd);
## what has been chosen is kept in Settings.

const LEVELS := [
	["Test yard", "res://test_yard.tscn"],
	["Desert", "res://desert.tscn"],
]
const WIDTH := 344.0

var _panel: PanelContainer
var _scroll: ScrollContainer
var _pages: VBoxContainer
## The two pages of the menu: everything, and the dresser.
var _main: VBoxContainer
var _dresser: VBoxContainer
var _face: Label
var _hair: Label
var _outfit: Label
var _cap_button: Button
## A swatch for each thing he has on that can be coloured; made again when he changes clothes.
var _wardrobe: GridContainer
var _swatches: Array[ColorPickerButton] = []
var _garments: Array = []
var _edit_button: Button


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

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
	_panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER_LEFT)
	_panel.offset_left = 18.0
	_panel.grow_horizontal = Control.GROW_DIRECTION_END
	_panel.grow_vertical = Control.GROW_DIRECTION_BOTH
	_panel.visible = false
	add_child(_panel)
	var margin := MarginContainer.new()
	for edge: String in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + edge, 16)
	_panel.add_child(margin)
	# (it scrolls, if a screen is too short for it: drag it, or use the wheel)
	_scroll = ScrollContainer.new()
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	margin.add_child(_scroll)
	_pages = VBoxContainer.new()
	_pages.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_scroll.add_child(_pages)

	_main = _page()
	_main.add_child(_heading("Look"))
	_main.add_child(_button("Figures: demade (low poly)" if Settings.low_poly else "Figures: full detail", _swap_models))
	_main.add_child(_button("World: banded light" if Settings.world_banded else "World: smooth light", _swap_world))
	_main.add_child(_heading("The boy"))
	_main.add_child(_button("Dress him...", _show_page.bind(true)))
	_main.add_child(_heading("Level"))
	for level: Array in LEVELS:
		# (a level that has not been made yet is left out)
		if not ResourceLoader.exists(level[1]):
			continue
		_main.add_child(_button(level[0], _go_to.bind(level[1])))
	_main.add_child(_button("Restart this level", _restart))
	# (a level made from a layout can be changed: see LevelEditor)
	_edit_button = _button("Edit this level", _edit)
	_main.add_child(_edit_button)
	_main.add_child(_button("Close", func() -> void: _set_open(false)))

	_dresser = _page()
	_dresser.add_child(_heading("The boy"))
	_face = _chooser("Face", _step_face)
	_hair = _chooser("Hair", _step_hair)
	_outfit = _chooser("Clothes", _step_outfit)
	_cap_button = _button("", _swap_cap)
	_dresser.add_child(_cap_button)
	_dresser.add_child(_heading("Skin"))
	_dresser.add_child(_palette(CharacterLook.SKINS, "skin"))
	_dresser.add_child(_heading("Hair colour"))
	_dresser.add_child(_palette(CharacterLook.HAIR_COLOURS, "hair"))
	_dresser.add_child(_heading("Colours"))
	_wardrobe = GridContainer.new()
	_wardrobe.columns = 3
	_wardrobe.add_theme_constant_override("h_separation", 8)
	_dresser.add_child(_wardrobe)
	var ends := HBoxContainer.new()
	ends.add_theme_constant_override("separation", 8)
	for made: Array in [["Random", _random], ["As he was", _reset_clothes]]:
		var button := _button(made[0], made[1])
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		ends.add_child(button)
	_dresser.add_child(ends)
	_dresser.add_child(_button("Back", _show_page.bind(false)))
	_dresser.visible = false
	get_viewport().size_changed.connect(_fit)


func _input(event: InputEvent) -> void:
	if event.is_action_pressed(&"ui_cancel"):
		_set_open(not _panel.visible)
		get_viewport().set_input_as_handled()


func _set_open(open: bool) -> void:
	_panel.visible = open
	_edit_button.visible = get_tree().get_first_node_in_group(&"editable_level") != null
	get_tree().paused = open
	if open:
		_show_page(false)


## Opens the dresser, with the menu if it is not open already.
func open_dresser() -> void:
	_panel.visible = true
	get_tree().paused = true
	_show_page(true)


func _show_page(dressing: bool) -> void:
	_main.visible = not dressing
	_dresser.visible = dressing
	if dressing:
		_show_clothes()
	_scroll.scroll_vertical = 0
	_fit()


## Makes the panel as tall as what is in it, or as the screen if that is less.
func _fit() -> void:
	var room := get_viewport_rect().size.y - 76.0
	_scroll.custom_minimum_size = Vector2(WIDTH, minf(_pages.get_combined_minimum_size().y, room))


## Sets everything in the dresser to what he has on.
func _show_clothes() -> void:
	var boy := _boy()
	for entry: Array in CharacterLook.FACES:
		if entry[0] == Settings.face:
			_face.text = entry[1]
	_hair.text = CharacterLook.hair(Settings.hair)["label"]
	var worn := CharacterLook.outfit(Settings.outfit)
	_outfit.text = worn["label"]
	_cap_button.text = "Cap: on" if Settings.cap else "Cap: off"
	if _garments != worn["garments"]:
		_garments = worn["garments"]
		for cell in _wardrobe.get_children():
			_wardrobe.remove_child(cell)
			cell.queue_free()
		_swatches.clear()
		for garment: Array in _garments:
			var cell := VBoxContainer.new()
			cell.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			var label := Label.new()
			label.text = garment[0]
			label.add_theme_font_size_override("font_size", 14)
			cell.add_child(label)
			var swatch := ColorPickerButton.new()
			swatch.custom_minimum_size = Vector2(96.0, 36.0)
			swatch.edit_alpha = false
			swatch.focus_mode = Control.FOCUS_NONE
			swatch.color_changed.connect(_recolour.bind(garment[1]))
			cell.add_child(swatch)
			_swatches.append(swatch)
			_wardrobe.add_child(cell)
	for i in _garments.size():
		var made: Color = boy.made_colours.get(_garments[i][1], Color.GRAY) if boy else Color.GRAY
		_swatches[i].color = Settings.colours.get(_garments[i][1], made)
	# (once the new swatches have been laid out)
	_fit.call_deferred()


## The boy's rig: the first figure that is neither something else's model nor
## somebody else turned out on his (see CharacterRig.look).
func _boy() -> CharacterRig:
	for figure: CharacterRig in get_tree().get_nodes_in_group(&"figures"):
		if figure.model == null and figure.look.is_empty():
			return figure
	return null


func _restyle() -> void:
	get_tree().call_group(&"figures", &"restyle")
	_show_clothes()


func _recolour(colour: Color, material: String) -> void:
	Settings.colours[material] = colour
	CharacterLook.matched(Settings.colours, Settings.outfit)
	get_tree().call_group(&"figures", &"restyle")


func _swap_cap() -> void:
	Settings.cap = not Settings.cap
	_restyle()


func _step_face(by: int) -> void:
	var names: Array = CharacterLook.FACES.map(func(entry: Array) -> String: return entry[0])
	Settings.face = names[posmod(names.find(Settings.face) + by, names.size())]
	_restyle()


func _step_hair(by: int) -> void:
	var names: Array = CharacterLook.HAIRS.map(func(entry: Dictionary) -> String: return entry["name"])
	Settings.hair = names[posmod(names.find(Settings.hair) + by, names.size())]
	_restyle()


func _step_outfit(by: int) -> void:
	var names: Array = CharacterLook.OUTFITS.map(func(entry: Dictionary) -> String: return entry["name"])
	# What one outfit makes of his shirt and breeches is not carried into the next.
	var was := CharacterLook.outfit(Settings.outfit)
	for material: String in was.get("wear", {}).keys() + was.get("same", {}).keys():
		Settings.colours.erase(material)
	Settings.outfit = names[posmod(names.find(Settings.outfit) + by, names.size())]
	var wear: Dictionary = CharacterLook.outfit(Settings.outfit).get("wear", {})
	for material: String in wear:
		Settings.colours[material] = wear[material]
	CharacterLook.matched(Settings.colours, Settings.outfit)
	_restyle()


func _random() -> void:
	Settings.wear(CharacterLook.random())
	_restyle()


func _reset_clothes() -> void:
	Settings.undress()
	_restyle()


func _swap_models() -> void:
	Settings.low_poly = not Settings.low_poly
	_restart()


func _swap_world() -> void:
	Settings.world_banded = not Settings.world_banded
	_restart()


## Opens the level editor over this level.
func _edit() -> void:
	_panel.visible = false
	var editor := get_tree().get_first_node_in_group(&"level_editor") as LevelEditor
	if editor == null:
		editor = LevelEditor.new()
		get_parent().add_child(editor)
	editor.open()


func _restart() -> void:
	get_tree().paused = false
	get_tree().reload_current_scene()


func _go_to(scene: String) -> void:
	get_tree().paused = false
	get_tree().change_scene_to_file(scene)


func _page() -> VBoxContainer:
	var page := VBoxContainer.new()
	page.add_theme_constant_override("separation", 6)
	page.custom_minimum_size.x = WIDTH - 14.0
	_pages.add_child(page)
	return page


## A row to step through a list with: its name, an arrow each way, and what is
## chosen between them. Returns the label that shows the choice.
func _chooser(title: String, step: Callable) -> Label:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)
	var name_label := Label.new()
	name_label.text = title
	name_label.custom_minimum_size.x = 62.0
	name_label.add_theme_font_size_override("font_size", 15)
	name_label.modulate.a = 0.7
	row.add_child(name_label)
	var back := _button("<", step.bind(-1))
	back.custom_minimum_size.x = 44.0
	row.add_child(back)
	var chosen := Label.new()
	chosen.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	chosen.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	chosen.clip_text = true
	chosen.add_theme_font_size_override("font_size", 16)
	row.add_child(chosen)
	var on := _button(">", step.bind(1))
	on.custom_minimum_size.x = 44.0
	row.add_child(on)
	_dresser.add_child(row)
	return chosen


## A row of colours to pick from, for one material.
func _palette(colours: Array[Color], material: String) -> Control:
	var row := HFlowContainer.new()
	row.add_theme_constant_override("h_separation", 5)
	row.add_theme_constant_override("v_separation", 5)
	for colour in colours:
		var button := Button.new()
		button.focus_mode = Control.FOCUS_NONE
		button.custom_minimum_size = Vector2(36.0, 34.0)
		for state: String in ["normal", "hover", "pressed"]:
			var box := StyleBoxFlat.new()
			box.bg_color = colour
			box.set_corner_radius_all(5)
			box.set_border_width_all(2)
			box.border_color = Color(1, 1, 1, 0.55 if state == "normal" else 0.95)
			button.add_theme_stylebox_override(state, box)
		button.pressed.connect(_recolour.bind(colour, material))
		row.add_child(button)
	return row


func _button(text: String, pressed: Callable) -> Button:
	var button := Button.new()
	button.text = text
	button.focus_mode = Control.FOCUS_NONE
	button.custom_minimum_size.y = 40.0
	button.add_theme_font_size_override("font_size", 19)
	button.pressed.connect(pressed)
	return button


func _heading(text: String) -> Label:
	var label := Label.new()
	label.text = text.to_upper()
	label.modulate.a = 0.6
	label.add_theme_font_size_override("font_size", 14)
	return label
