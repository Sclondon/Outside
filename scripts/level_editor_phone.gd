class_name LevelEditorPhone
extends Control
## The level editor's screen for a phone held sideways: what `LevelEditor` puts
## over the level where there is a touch screen (and on the web), in place of
## its panels for a desk. Everything in it is sized for a thumb: nothing to
## touch is under 88 pixels of the 720-high screen either way (about 8 mm on a
## phone), nothing is nearer the next than 12, no writing is under 26, and it
## all keeps 48 clear of the ends of the screen and off its bottom edge.
##
## THE BAR. Six buttons along the top, always there: Add, Level, Undo, View,
## Play, More. Under it one line of plain words says what a touch will do now.
##
## ONE PANEL AT A TIME. Everything else is either a SHEET, one row of buttons
## along the bottom with the level still in sight over it, or a PAGE, which
## covers the screen with big rows that are dragged up and down. Its way out is
## always at its top right corner: Done.
##
##     Add      a page of the kinds of thing, then a page of the things of one
##              kind. Touch one, then touch the ground: or bring the cross in the
##              middle of the screen to the place, and touch Put here.
##     a thing  touch it: a sheet with Move, Change, what works it, Copy, Remove.
##              Move is a sheet of arrows (a step at a time, held to keep going),
##              Raise and Lower, the two ways to turn it. Change is a page of
##              everything about it: a number has a minus and a plus (held, they
##              run), and a touch on its name puts the page away to change it with
##              a slider and the level in sight; yes or no is a switch; one of a
##              list is a page of the list; words are a page with the keyboard.
##     joining  from a door, "Opened by", then touch each plate that should; or
##              from a plate, "Works", then touch each door. The line of words
##              says what to touch next, and lines show what is joined.
##     Level    the desert itself: its size, dunes, wind, weather and heat.
##     View     nearer, further, from above, from the side, turned: for one hand.
##     More     Redo, Save, Play from here, the level as text, the level the game
##              came with, and all this in words.
##
## `LevelEditor` still does the work: this only asks it to. See `phone` there.

const BIG := 88.0
const GAP := 12
const ENDS := 48.0
const FOOT := 20.0
const WORDS := 26
const INK := Color(0.99, 0.95, 0.85)
const DARK := Color(0.13, 0.1, 0.07, 0.95)
const KEY := Color(0.37, 0.3, 0.2)
const GREEN := Color(0.27, 0.42, 0.2)
const RED := Color(0.55, 0.22, 0.15)
## The panels that are about the thing that is chosen: they go when nothing is.
const OF_A_THING := ["thing", "move", "link", "link_from", "points"]
## What the next touch on the ground does while each of these is open (`LevelEditor._next`).
const MODES := {"place": "place", "link": "link", "link_from": "link_from", "points": "point"}
## What each sub-page goes back to.
const UP := {"choice": "change", "words": "change", "number": "change", "text": "more", "help": "more", "original": "more"}
const HELP := [
	"LOOKING ABOUT. One finger drags the ground. Two fingers pinch to come nearer or go further, turn to turn the view, and slide up or down together to tip it. View has a button for each.",
	"PUTTING A THING IN. Add, then the kind of thing, then the thing. Touch the ground where it goes. Or drag the ground until the cross in the middle of the screen is on the place, and touch Put here.",
	"CHANGING A THING. Touch it. Drag it by its ring, or touch Move for arrows that move it a step at a time (hold one to keep going), raise and lower it, and turn it. Change has everything else about it. Hold a minus or a plus to run; touch a number's name to change it with a slider while you watch.",
	"JOINING. A door, a bridge, a sluice, a hound and others are worked by plates, levers, locks and targets. Choose the door and touch Opened by, then touch each plate. Or choose the plate and touch Works, then touch each door. Touch one again to undo it.",
	"A RIVER is a line of points. Drag each; Points adds more.",
	"KEEPING IT. Every change is saved on this phone as it is made. Undo takes back the last forty. More has Redo, the whole level as text to copy somewhere else, and the way back to the level the game came with.",
	"PLAY starts the level from its start; More has Play from here. To come back, open the notebook, Places, Edit this level.",
]

var editor: LevelEditor
## Which panel is open: "" (none), or a sheet ("thing", "move", "place", "link", "link_from", "points", "view",
## "number"), or a page ("add", "kind", "change", "choice", "words", "more", "text", "help", "original").
var panel := ""

var _bar: HBoxContainer
var _line: Label
var _said := ""
var _say_at := 0
var _sheet: PanelContainer
var _sheet_row: HBoxContainer
var _page: Panel
var _page_box: VBoxContainer
var _page_left: Button
var _page_title: Label
var _page_fixed: VBoxContainer
var _page_body: Scroller
var _rows: VBoxContainer
# The button being held down, to do what it does again and again.
var _held := {}
# Whether Change is about the desert itself, and not the thing that is chosen.
var _of_level := false
# Which kind of thing Add last showed; the number, the list or the words being changed; where Change was scrolled to.
var _kind := ""
var _number := {}
var _choice := {}
var _words := {}
var _entry: LineEdit
var _level_text: TextEdit
var _change_at := 0.0
# Which thing the sheet of arrows is moving (its id).
var _moving := -1


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	theme = _make_theme()
	_build()


# --- What everything is made of ---

func _make_theme() -> Theme:
	var made := Theme.new()
	made.default_font_size = WORDS
	for state: String in ["normal", "hover", "pressed", "disabled", "focus", "hover_pressed"]:
		var colour := KEY
		if state == "pressed" or state == "hover_pressed":
			colour = Color(0.66, 0.5, 0.22)
		elif state == "disabled":
			colour = Color(0.26, 0.23, 0.19, 0.8)
		made.set_stylebox(state, "Button", _box(colour, 12.0, 14.0))
	for name: String in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color", "font_hover_pressed_color"]:
		made.set_color(name, "Button", INK)
	made.set_color("font_disabled_color", "Button", Color(INK, 0.4))
	made.set_color("font_color", "Label", INK)
	for kind: String in ["LineEdit", "TextEdit"]:
		made.set_stylebox("normal", kind, _box(Color(0.05, 0.04, 0.03), 10.0, 16.0))
		made.set_stylebox("focus", kind, _box(Color(0.05, 0.04, 0.03), 10.0, 16.0, Color(0.95, 0.8, 0.4)))
		made.set_color("font_color", kind, INK)
		made.set_font_size("font_size", kind, 30)
	made.set_stylebox("panel", "PanelContainer", _box(DARK, 16.0, 12.0))
	made.set_stylebox("panel", "Panel", _box(Color(0.13, 0.1, 0.07, 0.985), 0.0, 0.0))
	return made


func _box(colour: Color, round: float, pad: float, edge := Color(0, 0, 0, 0)) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = colour
	box.set_corner_radius_all(int(round))
	box.set_content_margin_all(pad)
	if edge.a > 0.0:
		box.border_color = edge
		box.set_border_width_all(3)
	return box


func _width_of(words: String, size := WORDS) -> float:
	return ThemeDB.fallback_font.get_string_size(words, HORIZONTAL_ALIGNMENT_LEFT, -1.0, size).x


# A button with a picture and a word under it. (The word is kept as its "word", to be found by.)
func _tile(word: String, icon: String, action: Callable, wide := BIG, colour := KEY) -> Button:
	var button := Button.new()
	button.focus_mode = Control.FOCUS_NONE
	button.custom_minimum_size = Vector2(maxf(wide, _width_of(word) + 24.0), BIG)
	button.set_meta(&"word", word if word != "" else icon)
	button.set_meta(&"shown", word)
	button.set_meta(&"icon", icon)
	if colour != KEY:
		button.add_theme_stylebox_override("normal", _box(colour, 12.0, 14.0))
		button.add_theme_stylebox_override("hover", _box(colour, 12.0, 14.0))
	button.draw.connect(_draw_tile.bind(button))
	if action.is_valid():
		button.pressed.connect(action)
	return button


func _draw_tile(button: Button) -> void:
	var word := String(button.get_meta(&"shown"))
	var icon := String(button.get_meta(&"icon"))
	var ink := Color(INK, 0.4) if button.disabled else INK
	var middle := Vector2(button.size.x * 0.5, 31.0 if word != "" else button.size.y * 0.5)
	if icon.begins_with("="):
		var said := icon.substr(1)
		button.draw_string(ThemeDB.fallback_font, Vector2(0.0, middle.y + 11.0), said, HORIZONTAL_ALIGNMENT_CENTER, button.size.x, 30, ink)
	else:
		_draw_icon(button, icon, middle, 19.0, ink)
	if word != "":
		button.draw_string(ThemeDB.fallback_font, Vector2(0.0, button.size.y - 13.0), word, HORIZONTAL_ALIGNMENT_CENTER, button.size.x, WORDS, ink)


# A wide button of words, for a page; with a mark at its right end if it is given one.
func _row(words: String, action: Callable, mark := "") -> Button:
	var button := Button.new()
	button.text = words
	button.focus_mode = Control.FOCUS_NONE
	button.alignment = HORIZONTAL_ALIGNMENT_LEFT
	button.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	button.clip_text = true
	button.custom_minimum_size = Vector2(BIG, BIG)
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.add_theme_font_size_override("font_size", 28)
	if mark != "":
		button.set_meta(&"icon", mark)
		for state: String in ["normal", "hover", "pressed", "disabled"]:
			var box := (theme.get_stylebox(state, "Button") as StyleBoxFlat).duplicate() as StyleBoxFlat
			box.content_margin_right = 130.0 if mark.begins_with("switch") else 64.0
			button.add_theme_stylebox_override(state, box)
		button.draw.connect(func() -> void:
			var at := Vector2(button.size.x - 40.0, button.size.y * 0.5)
			var icon := String(button.get_meta(&"icon"))
			if icon.begins_with("switch"):
				_draw_switch(button, Vector2(button.size.x - 70.0, at.y), icon == "switch_on")
			else:
				_draw_icon(button, icon, at, 15.0, Color(INK, 0.8)))
	if action.is_valid():
		# (a finger that was dragging the page did not mean to press what it ended on)
		button.pressed.connect(func() -> void:
			if not _page_body.just_moved():
				action.call())
	return button


func _draw_switch(on: Control, at: Vector2, yes: bool) -> void:
	var track := Rect2(at - Vector2(46.0, 23.0), Vector2(92.0, 46.0))
	var box := _box(Color(0.35, 0.62, 0.27) if yes else Color(0.2, 0.18, 0.15), 23.0, 0.0, Color(INK, 0.5))
	on.draw_style_box(box, track)
	on.draw_circle(at + Vector2(23.0 if yes else -23.0, 0.0), 17.0, INK)


func _label(text: String, size := WORDS) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", size)
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return label


# Makes a button do what it does when it is touched, and again and again while it is held: slowly, then faster
# (`action` is given how many steps to take at once). What is changed is noted once, to be undone as one thing.
func _hold(button: Button, action: Callable, remembers := true) -> void:
	button.button_down.connect(func() -> void:
		_held = {"button": button, "action": action, "since": Time.get_ticks_msec(), "next": 0, "fired": 0, "remembers": remembers})
	button.pressed.connect(func() -> void:
		var ran: bool = _held.get("button") == button and int(_held["fired"]) > 0
		_held = {}
		if ran or _page_body.just_moved():
			return
		if remembers:
			editor._remember()
		action.call(1.0))


func _process(_delta: float) -> void:
	if editor == null or not editor.visible:
		return
	if not _held.is_empty():
		var button := _held["button"] as Button
		if not is_instance_valid(button) or not button.is_visible_in_tree() or not button.is_pressed():
			_held = {}
		else:
			var now := Time.get_ticks_msec()
			if now - int(_held["since"]) > 420 and now >= int(_held["next"]):
				var fired: int = _held["fired"]
				if fired == 0 and _held["remembers"]:
					editor._remember()
				(_held["action"] as Callable).call(1.0 if fired < 8 else (5.0 if fired < 22 else 20.0))
				_held["fired"] = fired + 1
				_held["next"] = now + 110
	# (the line of words is looked at again a few times a second, or at once when something has changed)
	var now := Time.get_ticks_msec()
	if _said == "?" or now >= _say_at or now * 0.001 < editor._hint_until:
		_say_at = now + 200
		_say(_status())


func _build() -> void:
	# Along the top: the bar.
	_bar = HBoxContainer.new()
	_bar.anchor_right = 1.0
	_bar.offset_top = 8.0
	_bar.offset_bottom = 8.0 + BIG
	_bar.add_theme_constant_override("separation", GAP)
	_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_bar)
	for made: Array in [["Add", "add", _show.bind("add")], ["Level", "level", _open_change.bind(true)], ["Undo", "undo", func() -> void: editor._step_back()],
			["View", "view", _show.bind("view")], ["Play", "play", func() -> void: editor._play(false)], ["More", "more", _show.bind("more")]]:
		var button := _tile(made[0], made[1], made[2])
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		_bar.add_child(button)

	# Under it: what is happening, in a line of words.
	_line = Label.new()
	_line.add_theme_font_size_override("font_size", WORDS)
	_line.add_theme_stylebox_override("normal", _box(Color(0.1, 0.08, 0.06, 0.82), 12.0, 10.0))
	_line.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_line)

	# Along the bottom: a sheet, one row of buttons.
	_sheet = PanelContainer.new()
	_sheet.anchor_top = 1.0
	_sheet.anchor_bottom = 1.0
	_sheet.anchor_right = 1.0
	_sheet.grow_vertical = Control.GROW_DIRECTION_BEGIN
	_sheet.mouse_filter = Control.MOUSE_FILTER_STOP
	_sheet.visible = false
	add_child(_sheet)
	_sheet_row = HBoxContainer.new()
	_sheet_row.add_theme_constant_override("separation", GAP)
	_sheet.add_child(_sheet_row)

	# Over everything: a page.
	_page = Panel.new()
	_page.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_page.mouse_filter = Control.MOUSE_FILTER_STOP
	_page.visible = false
	add_child(_page)
	_page_box = VBoxContainer.new()
	_page_box.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_page_box.add_theme_constant_override("separation", GAP)
	_page.add_child(_page_box)
	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", GAP)
	_page_box.add_child(head)
	_page_left = _tile("All kinds", "back", _show.bind("add"), 170.0)
	head.add_child(_page_left)
	_page_title = Label.new()
	_page_title.add_theme_font_size_override("font_size", 34)
	_page_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_page_title.clip_text = true
	_page_title.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	_page_title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_page_title.custom_minimum_size.y = BIG
	head.add_child(_page_title)
	head.add_child(_tile("Done", "done", done, 170.0, GREEN))
	_page_fixed = VBoxContainer.new()
	_page_fixed.add_theme_constant_override("separation", GAP)
	_page_box.add_child(_page_fixed)
	_page_body = Scroller.new()
	_page_body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_page_box.add_child(_page_body)
	_rows = VBoxContainer.new()
	_rows.add_theme_constant_override("separation", GAP)
	_page_body.hold(_rows)
	keep_clear(ENDS, 0.0, ENDS, FOOT)


## Keeps everything clear of the ends of the screen: at least `ENDS` at the left and right, `FOOT` at the bottom,
## and more where the phone says more is cut away.
func keep_clear(left: float, top: float, right: float, bottom: float) -> void:
	left = maxf(left, ENDS)
	right = maxf(right, ENDS)
	bottom = maxf(bottom, FOOT)
	_bar.offset_left = left
	_bar.offset_right = -right
	_bar.offset_top = 8.0 + top
	_bar.offset_bottom = 8.0 + top + BIG
	_line.position = Vector2(left, _bar.offset_bottom + 10.0)
	_sheet.offset_left = left
	_sheet.offset_right = -right
	_sheet.offset_bottom = -bottom
	_sheet.offset_top = -bottom
	_page_box.offset_left = left
	_page_box.offset_right = -right
	_page_box.offset_top = 8.0 + top
	_page_box.offset_bottom = -bottom
	_said = "?"


# --- The line of words ---

func _status() -> String:
	if Time.get_ticks_msec() * 0.001 < editor._hint_until:
		return editor._hint
	# (the ground is made again a moment after it is changed: said, unless there is something to be told to do)
	if editor._shape_in >= 0.0 and panel in ["", "thing", "view"]:
		return "Making the ground..."
	var name := LevelLayout.label(editor.chosen).to_lower() if not editor.chosen.is_empty() else ""
	match panel:
		"place":
			return "%s: tap the ground where it goes. Or bring the cross there and tap Put here." % String(editor._armed[0])
		"thing":
			if editor.chosen.get("kind", "") == "river":
				return "The river is chosen. Drag any of its points to move it."
			return "The %s is chosen. Drag it by its ring, or tap another thing." % name
		"move":
			return "Moving the %s: drag its ring, or use the arrows (hold one to keep going)." % name
		"link":
			var count: int = (editor.chosen.get("links", []) as Array).size()
			return "Tap each plate, lever or target that should work the %s. Tap one again to undo it. %s" % [name, "None yet." if count == 0 else "%d so far." % count]
		"link_from":
			var works := editor.worked_by(editor.chosen).size()
			return "Tap each door, bridge or other ringed thing the %s should work. Tap one again to undo it. %s" % [name, "None yet." if works == 0 else "%d so far." % works]
		"points":
			return "Tap where the river goes next. Or bring the cross there and tap Add here."
		"view":
			return "One finger drags the ground, two pinch and turn. Or use these (hold one to keep going)."
		"number":
			return "%s. Drag the slider, or tap minus and plus." % _number_words(_number)
	return "Drag to look about, pinch to zoom. Tap a thing to choose it. Add puts a new one in."


func _say(words: String) -> void:
	if words == _said:
		return
	_said = words
	var room := size.x + _bar.offset_right - _bar.offset_left
	_line.autowrap_mode = TextServer.AUTOWRAP_OFF
	_line.text = words
	_line.custom_minimum_size = Vector2.ZERO
	if _width_of(words) + 24.0 > room:
		_line.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		_line.custom_minimum_size.x = room
	_line.reset_size()


# --- Which panel is open ---

## Opens a panel, in place of whichever is open; "" for none.
func show_panel(which: String) -> void:
	_show(which)


func _show(which: String) -> void:
	if panel == "change" and _page_body.visible:
		_change_at = _page_body.scroll
	if panel == "words" and which != "words":
		_take_words()
	panel = which
	_held = {}
	editor._next = MODES.get(which, "")
	_sheet.visible = false
	_page.visible = false
	for old: Node in _sheet_row.get_children():
		_sheet_row.remove_child(old)
		old.queue_free()
	for old: Node in _rows.get_children() + _page_fixed.get_children():
		old.get_parent().remove_child(old)
		old.queue_free()
	_page_left.visible = false
	_page_body.scroll = 0.0
	_page_body.visible = true
	_entry = null
	_level_text = null
	match which:
		"thing":
			_sheet_thing()
		"move":
			_sheet_move()
		"place":
			_sheet_place()
		"link", "link_from":
			_sheet_link()
		"points":
			_sheet_points()
		"view":
			_sheet_view()
		"number":
			_sheet_number()
		"add":
			_page_add()
		"kind":
			_page_kind()
		"change":
			_page_change()
		"choice":
			_page_choice()
		"words":
			_page_words()
		"more":
			_page_more()
		"text":
			_page_text()
		"help":
			_page_help()
		"original":
			_page_original()
	# (a page covers the bar: there is nothing under it to touch)
	_bar.visible = not _page.visible
	_line.visible = not _page.visible
	_page_body.arrange()
	_said = "?"


## The way out of whatever is open: a sheet or a page is put away, a page inside another goes back to that.
## (Put away, the sheet of the thing that is chosen is left: Done on that lets go of the thing.)
func done() -> void:
	var back: String = UP.get(panel, "")
	if back != "":
		_show(back)
		return
	if panel == "thing":
		editor.chosen = {}
	_rest()


# Nothing open: but for the sheet of the thing that is chosen, if one is.
func _rest() -> void:
	_show("" if editor.chosen.is_empty() else "thing")


## Told by the editor that a thing has been chosen, or that nothing now is.
func chose() -> void:
	if not editor.chosen.is_empty():
		# (touched again while it is being moved, it is still being moved)
		if panel == "move" and int(editor.chosen["id"]) == _moving:
			return
		_show("thing")
	elif panel in OF_A_THING or (panel in ["number", "change"] and not _of_level):
		_show("")


## Told by the editor that what is chosen may have changed, or gone (it was removed, or a change was undone).
func refresh() -> void:
	if editor.chosen.is_empty() and (panel in OF_A_THING or (panel in ["number", "change", "choice", "words"] and not _of_level)):
		_show("")
	elif panel == "number":
		# (what it was changing may have been made again)
		_show("" if _of_level else "thing")
	elif panel in OF_A_THING:
		_show(panel)
	editor._next = MODES.get(panel, "")


## Whether the cross in the middle of the screen means something just now: a thing is put there, or brought there.
func wants_cross() -> bool:
	return panel in ["place", "move", "points"]


func _open_sheet() -> HBoxContainer:
	_sheet.visible = true
	return _sheet_row


# The way out, at the right hand end of a sheet.
func _close_sheet(word := "Done", icon := "done") -> void:
	var gap := Control.new()
	gap.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	gap.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_sheet_row.add_child(gap)
	_sheet_row.add_child(_tile(word, icon, done, 130.0, GREEN))


func _open_page(title: String) -> VBoxContainer:
	_page.visible = true
	_page_title.text = title
	return _rows


func _grid(columns: int) -> GridContainer:
	var grid := GridContainer.new()
	grid.columns = columns
	grid.add_theme_constant_override("h_separation", GAP)
	grid.add_theme_constant_override("v_separation", GAP)
	_rows.add_child(grid)
	return grid


# --- The sheets ---

func _sheet_thing() -> void:
	var row := _open_sheet()
	var item := editor.chosen
	row.add_child(_tile("Move", "move", _show.bind("move"), 120.0))
	row.add_child(_tile("Change", "change", _open_change.bind(false), 120.0))
	if item["kind"] == "river":
		row.add_child(_tile("Points", "points", _show.bind("points"), 120.0))
	for field: Array in LevelLayout.fields(item):
		if field[2] == "links":
			row.add_child(_tile(field[1], "link", _show.bind("link"), 120.0))
	if editor._is_trigger(item):
		row.add_child(_tile("Works", "link", _show.bind("link_from"), 120.0))
	row.add_child(_tile("Copy", "copy", func() -> void: editor._copy(), 110.0))
	row.add_child(_tile("Remove", "remove", func() -> void: editor._remove(), 110.0, RED))
	row.add_child(_tile("Find", "find", func() -> void: editor.look_at_chosen(), 110.0))
	_close_sheet()


func _sheet_move() -> void:
	var row := _open_sheet()
	var item := editor.chosen
	_moving = int(item["id"])
	for way: Array in [["Left", "left", Vector2(-1, 0)], ["Far", "far", Vector2(0, -1)], ["Near", "near", Vector2(0, 1)], ["Right", "right", Vector2(1, 0)]]:
		var arrow := _tile(way[0], way[1], Callable())
		_hold(arrow, func(_times: float) -> void: editor.nudge(way[2]))
		row.add_child(arrow)
	var step := _tile("Step", "=" + _metres(editor._nudge), Callable())
	step.pressed.connect(func() -> void:
		var steps: Array[float] = [0.1, 0.5, 1.0, 5.0]
		editor._nudge = steps[(steps.find(editor._nudge) + 1) % steps.size()]
		step.set_meta(&"icon", "=" + _metres(editor._nudge))
		step.queue_redraw()
		editor._say("The arrows, Raise and Lower now move it %s at a time." % _metres(editor._nudge)))
	row.add_child(step)
	# (what the ground is made from has a height of its own, or none: the rest are lifted off the ground)
	var height := "y" if item.has("y") else ("" if item["kind"] in LevelEditor.GROUND_KINDS else "lift")
	if height != "":
		for way: Array in [["Lower", "lower", -1.0], ["Raise", "raise", 1.0]]:
			var lift := _tile(way[0], way[1], Callable())
			_hold(lift, func(_times: float) -> void:
				item[height] = snappedf(float(item.get(height, 0.0)) + float(way[2]) * editor._nudge, 0.01)
				editor._changed(item, height)
				editor._say("%s: %s m" % ["Its height" if height == "y" else "Above the ground", String.num(item[height], 2)]))
			row.add_child(lift)
	if editor.turns(item):
		for way: Array in [["Turn", "turn_left", 15.0], ["Turn", "turn_right", -15.0]]:
			var turn := _tile(way[0], way[1], Callable())
			turn.set_meta(&"word", way[1])
			_hold(turn, func(_times: float) -> void:
				item["yaw"] = wrapf(snappedf(float(item.get("yaw", 0.0)) + float(way[2]), 1.0), -180.0, 180.0)
				editor._changed(item, "yaw")
				editor._say("Turned: %d" % int(item["yaw"])))
			row.add_child(turn)
	row.add_child(_tile("Here", "here", func() -> void: editor.bring_to_cross()))
	_close_sheet()


func _sheet_place() -> void:
	var row := _open_sheet()
	row.add_child(_tile("Put here", "here", func() -> void: editor._tapped(editor.size * 0.5), 150.0))
	row.add_child(_tile("Another kind", "add", _show.bind("kind"), 150.0))
	_close_sheet("Cancel", "cancel")


func _sheet_link() -> void:
	var row := _open_sheet()
	row.add_child(_tile("Find", "find", func() -> void: editor.look_at_chosen(), 110.0))
	_close_sheet()


func _sheet_points() -> void:
	var row := _open_sheet()
	var item := editor.chosen
	row.add_child(_tile("Add here", "here", func() -> void: editor._tapped(editor.size * 0.5), 150.0))
	row.add_child(_tile("Take the last away", "remove", func() -> void:
		if (item["points"] as Array).size() > 2:
			editor._remember()
			(item["points"] as Array).pop_back()
			editor._changed(item, "points")
		else:
			editor._say("A river has two points at the least."), 150.0))
	_close_sheet()


func _sheet_view() -> void:
	var row := _open_sheet()
	for made: Array in [["Nearer", "nearer", 0.0, 0.88, 0.0], ["Further", "further", 0.0, 1.14, 0.0], ["Above", "above", 0.0, 1.0, 0.07], ["Side", "side", 0.0, 1.0, -0.07],
			["Turn", "turn_left", 0.12, 1.0, 0.0], ["Turn", "turn_right", -0.12, 1.0, 0.0]]:
		var button := _tile(made[0], made[1], Callable(), 110.0)
		if made[0] == "Turn":
			button.set_meta(&"word", made[1])
		_hold(button, func(_times: float) -> void: editor.look(made[2], made[3], made[4]), false)
		row.add_child(button)
	_close_sheet()


func _sheet_number() -> void:
	var row := _open_sheet()
	var spec := _number
	var name := _label(_number_words(spec))
	name.custom_minimum_size.x = 250.0
	name.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(name)
	var slide := Slide.new()
	slide.least = spec["least"]
	slide.most = spec["most"]
	slide.step = spec["step"]
	slide.value = float((spec["holder"] as Dictionary).get(spec["key"], 0.0))
	slide.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	slide.taken.connect(func() -> void: editor._remember())
	slide.changed.connect(func(value: float) -> void:
		editor._put_number(spec["holder"], spec["key"], value, spec["what"])
		name.text = _number_words(spec))
	var less := _tile("", "minus", Callable(), 100.0)
	_hold(less, func(times: float) -> void:
		_step(spec, -times)
		slide.show_value(float(spec["holder"][spec["key"]]))
		name.text = _number_words(spec))
	var more := _tile("", "plus", Callable(), 100.0)
	_hold(more, func(times: float) -> void:
		_step(spec, times)
		slide.show_value(float(spec["holder"][spec["key"]]))
		name.text = _number_words(spec))
	row.add_child(less)
	row.add_child(slide)
	row.add_child(more)
	_sheet_row.add_child(_tile("Done", "done", done, 130.0, GREEN))


# --- The pages ---

func _page_add() -> void:
	_open_page("Add: which kind of thing?")
	var grid := _grid(3)
	for kind: String in LevelLayout.PALETTE:
		grid.add_child(_row("%s  (%d)" % [kind, (LevelLayout.PALETTE[kind] as Array).size()], func() -> void:
			_kind = kind
			_show("kind")))


func _page_kind() -> void:
	if not LevelLayout.PALETTE.has(_kind):
		_kind = LevelLayout.PALETTE.keys()[0]
	_open_page("%s: tap one, then tap the ground" % _kind)
	_page_left.visible = true
	var grid := _grid(4 if size.x >= 1500.0 else 3)
	for entry: Array in LevelLayout.PALETTE[_kind]:
		grid.add_child(_row(entry[0], func() -> void:
			editor._arm(entry)
			_show("place")))


func _open_change(of_level: bool) -> void:
	_of_level = of_level
	_change_at = 0.0
	_show("change")


func _page_change() -> void:
	var item := editor.chosen
	if _of_level or item.is_empty():
		_of_level = true
		_open_page("The desert itself")
		for spec: Dictionary in _level_numbers():
			_number_row(spec)
		DesertScenery.phone_rows(self, editor.layout["terrain"])
		_rows.add_child(_row("Weather: %s" % ["Calm", "A breeze", "A storm"][int(editor.layout.get("weather", 1))], func() -> void:
			_choice = {"title": "Weather", "options": ["Calm", "A breeze", "A storm"], "holder": editor.layout, "key": "weather", "usual": 1}
			_show("choice"), "next"))
		_rows.add_child(_label("%d things in the level." % (editor.layout["items"] as Array).size()))
	else:
		_open_page("%s  (%d)" % [LevelLayout.label(item), item["id"]])
		if editor.turns(item):
			_number_row(_spec("Turned", item, "yaw", -180.0, 180.0, 1.0))
		if not item.has("y") and not item["kind"] in LevelEditor.GROUND_KINDS:
			_number_row(_spec("Above the ground", item, "lift", -8.0, 30.0, 0.05))
		for field: Array in LevelLayout.fields(item):
			match field[2]:
				"n":
					_number_row(_spec(field[1], item, field[0], field[3], field[4], field[5]))
				"b":
					var on: bool = item.get(field[0], field[3])
					var box := _row("%s: %s" % [field[1], "yes" if on else "no"], Callable(), "switch_on" if on else "switch_off")
					box.pressed.connect(func() -> void:
						if _page_body.just_moved():
							return
						editor._remember()
						var now: bool = not item.get(field[0], field[3])
						item[field[0]] = now
						editor._changed(item, field[0])
						box.text = "%s: %s" % [field[1], "yes" if now else "no"]
						box.set_meta(&"icon", "switch_on" if now else "switch_off")
						box.queue_redraw())
					_rows.add_child(box)
				"c":
					var options: Array = field[3]
					_rows.add_child(_row("%s: %s" % [field[1], options[clampi(int(item.get(field[0], field[4])), 0, options.size() - 1)]], func() -> void:
						_choice = {"title": field[1], "options": options, "holder": item, "key": field[0], "usual": field[4]}
						_show("choice"), "next"))
				"t":
					_rows.add_child(_row("%s: %s" % [field[1], item.get(field[0], field[3])], func() -> void:
						_words = {"title": field[1], "holder": item, "key": field[0]}
						_show("words"), "next"))
				"links":
					var links: Array = item.get(field[0], [])
					_rows.add_child(_row("%s: %s" % [field[1], "nothing yet" if links.is_empty() else "%d thing%s" % [links.size(), "" if links.size() == 1 else "s"]], _show.bind("link"), "next"))
		if editor._is_trigger(item):
			_rows.add_child(_row("Works: %d thing%s" % [editor.worked_by(item).size(), "" if editor.worked_by(item).size() == 1 else "s"], _show.bind("link_from"), "next"))
	_page_body.scroll = _change_at


func _spec(title: String, holder: Dictionary, key: String, least: float, most: float, step: float, what := "") -> Dictionary:
	return {"title": title, "holder": holder, "key": key, "least": least, "most": most, "step": step, "what": what}


func _level_numbers() -> Array:
	var own: Dictionary = editor.layout["terrain"]
	var blows: Array = own.get("wind", [1.0, 0.0])
	var turn := {"deg": snappedf(rad_to_deg(atan2(blows[1], blows[0])), 1.0)}
	return [
		_spec("How far across", own, "size", 160.0, 800.0, 20.0, "terrain"), _spec("Height of the dunes", own, "dune_height", 0.0, 18.0, 0.25, "terrain"),
		_spec("Dunes scattered about", own, "scatter", 0.0, 2.5, 0.05, "terrain"), _spec("Which scatter", own, "seed", 0.0, 99.0, 1.0, "terrain"),
		_spec("Height of the edge", own, "rim_height", 0.0, 30.0, 0.5, "terrain"), _spec("The wind blows towards", turn, "deg", -180.0, 180.0, 5.0, "wind"),
		_spec("Heat mirage (0: none)", editor.layout, "mirage", 0.0, 1.0, 0.05, "mirage"),
	]


func _number_words(spec: Dictionary) -> String:
	if spec.is_empty():
		return ""
	return "%s: %s" % [spec["title"], String.num(float((spec["holder"] as Dictionary).get(spec["key"], 0.0)), 0 if float(spec["step"]) >= 1.0 else 2)]


func _metres(by: float) -> String:
	return "%s m" % String.num(by, 1 if by < 1.0 else 0)


# Takes a number so many steps up or down, no further than it may go (or than it already is).
func _step(spec: Dictionary, times: float) -> void:
	var holder: Dictionary = spec["holder"]
	var was := float(holder.get(spec["key"], 0.0))
	var step: float = spec["step"]
	var now := snappedf(was + step * times, step)
	now = clampf(now, minf(spec["least"], was), maxf(spec["most"], was))
	if not is_equal_approx(now, was):
		editor._put_number(holder, spec["key"], now, spec["what"])


# A number, as a row of a page: its name and what it stands at (touched, it is changed with the level in sight),
# and a minus and a plus.
func _number_row(spec: Dictionary) -> void:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", GAP)
	_rows.add_child(row)
	var name := _row(_number_words(spec), func() -> void:
		_number = spec
		_show("number"), "slide")
	row.add_child(name)
	for way: Array in [["minus", -1.0], ["plus", 1.0]]:
		var button := _tile("", way[0], Callable(), 120.0)
		_hold(button, func(times: float) -> void:
			_step(spec, times * float(way[1]))
			name.text = _number_words(spec))
		row.add_child(button)


func _page_choice() -> void:
	_open_page("%s: tap one" % _choice["title"])
	var holder: Dictionary = _choice["holder"]
	var options: Array = _choice["options"]
	var now := int(holder.get(_choice["key"], _choice["usual"]))
	var grid := _grid(1 if options.size() <= 5 else 2)
	for index in options.size():
		var row := _row(options[index], func() -> void:
			editor._remember()
			holder[_choice["key"]] = index
			if holder == editor.layout:
				editor._save_in = 1.2
			else:
				editor._changed(holder, _choice["key"])
			_show("change"), "done" if index == now else "")
		if index == now:
			row.add_theme_stylebox_override("normal", _box(GREEN, 12.0, 14.0))
			row.add_theme_stylebox_override("hover", _box(GREEN, 12.0, 14.0))
		grid.add_child(row)


# Words to type: the line is at the top of the page, where the keyboard does not cover it.
func _page_words() -> void:
	_open_page("%s: type it, then Done" % _words["title"])
	_entry = LineEdit.new()
	_entry.text = String((_words["holder"] as Dictionary).get(_words["key"], ""))
	_entry.custom_minimum_size.y = BIG
	_entry.select_all_on_focus = false
	_entry.caret_column = _entry.text.length()
	_entry.text_submitted.connect(func(_text: String) -> void: done())
	_page_fixed.add_child(_entry)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", GAP)
	_page_fixed.add_child(row)
	row.add_child(_tile("Rub it out", "cancel", func() -> void:
		_entry.text = ""
		_entry.grab_focus(), 170.0))
	_page_body.visible = false
	_entry.grab_focus.call_deferred()


func _take_words() -> void:
	if _entry == null or _words.is_empty():
		return
	var holder: Dictionary = _words["holder"]
	if _entry.text != String(holder.get(_words["key"], "")):
		editor._remember()
		holder[_words["key"]] = _entry.text
		editor._changed(holder, _words["key"])
	_entry.release_focus()


func _page_more() -> void:
	_open_page("More")
	var grid := _grid(2)
	grid.add_child(_row("Redo: bring back what Undo took", func() -> void:
		_rest()
		editor._step_on()))
	grid.add_child(_row("Save now", func() -> void:
		_rest()
		editor._save_now()))
	grid.add_child(_row("Play from here", func() -> void: editor._play(true)))
	grid.add_child(_row("Play from the start", func() -> void: editor._play(false)))
	grid.add_child(_row("The level as text", _show.bind("text"), "next"))
	grid.add_child(_row("Back to the level as it came", _show.bind("original"), "next"))
	grid.add_child(_row("How it all works", _show.bind("help"), "next"))
	_rows.add_child(_label("Every change is saved on this phone as you make it."))


func _page_text() -> void:
	_open_page("The level as text")
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", GAP)
	_page_fixed.add_child(row)
	_level_text = TextEdit.new()
	_level_text.text = LevelLayout.to_text(editor.layout)
	_level_text.custom_minimum_size.y = 190.0
	_level_text.add_theme_font_size_override("font_size", WORDS)
	_page_fixed.add_child(_level_text)
	var text := _level_text
	row.add_child(_tile("Copy it", "copy", func() -> void:
		DisplayServer.clipboard_set(text.text)
		editor._say("Copied."), 170.0))
	row.add_child(_tile("Paste", "put", func() -> void: text.text = DisplayServer.clipboard_get(), 170.0))
	row.add_child(_tile("Use this text", "done", func() -> void:
		if editor._use_text(text.text):
			_show(""), 200.0))
	_rows.add_child(_label("To keep a level anywhere else, or to send it to be built into the game, tap Copy it. To bring one in, paste it into the box in place of what is there, and tap Use this text."))


func _page_original() -> void:
	_open_page("Back to the level the game came with?")
	_rows.add_child(_label("The level goes back to how the game came, and what you have made is no longer saved on this phone. (Undo brings it back, until you leave the editor.)"))
	_rows.add_child(_row("Yes: the level the game came with", func() -> void:
		_show("")
		editor._back_to_original()))
	_rows.add_child(_row("No: keep mine", _show.bind("more")))


func _page_help() -> void:
	_open_page("How it all works")
	for words: String in HELP:
		_rows.add_child(_label(words, 27))


# --- Pictures for the buttons ---

func _arrow(on: Control, from: Vector2, to: Vector2, ink: Color, thick := 4.0) -> void:
	on.draw_line(from, to, ink, thick, true)
	var way := (to - from).normalized()
	var across := Vector2(-way.y, way.x)
	on.draw_colored_polygon(PackedVector2Array([to + way * 7.0, to - way * 5.0 + across * 8.0, to - way * 5.0 - across * 8.0]), ink)


# Part of a circle with an arrow head where it ends, going round from one angle to another.
func _round_arrow(on: Control, at: Vector2, radius: float, from: float, to: float, ink: Color) -> void:
	on.draw_arc(at, radius, from, to, 20, ink, 4.0, true)
	var end := at + Vector2.from_angle(to) * radius
	var way := Vector2.from_angle(to).orthogonal() * (-1.0 if to > from else 1.0)
	var across := Vector2(-way.y, way.x)
	on.draw_colored_polygon(PackedVector2Array([end + way * 9.0, end - way * 3.0 + across * 8.0, end - way * 3.0 - across * 8.0]), ink)


func _draw_icon(on: Control, icon: String, at: Vector2, r: float, ink: Color) -> void:
	match icon:
		"add", "plus", "nearer":
			on.draw_line(at - Vector2(r, 0), at + Vector2(r, 0), ink, 5.0)
			on.draw_line(at - Vector2(0, r), at + Vector2(0, r), ink, 5.0)
		"minus", "further":
			on.draw_line(at - Vector2(r, 0), at + Vector2(r, 0), ink, 5.0)
		"level":
			on.draw_polyline(PackedVector2Array([at + Vector2(-r * 1.3, r * 0.7), at + Vector2(-r * 0.45, -r * 0.7), at + Vector2(r * 0.15, r * 0.15), at + Vector2(r * 0.6, -r * 0.3), at + Vector2(r * 1.3, r * 0.7), at + Vector2(-r * 1.3, r * 0.7)]), ink, 4.0, true)
		"undo", "turn_left":
			_round_arrow(on, at, r * 0.85, deg_to_rad(70.0), deg_to_rad(-180.0), ink)
		"redo", "turn_right":
			_round_arrow(on, at, r * 0.85, deg_to_rad(110.0), deg_to_rad(360.0), ink)
		"view":
			var lid := PackedVector2Array()
			for i in 25:
				var along := -1.0 + i / 12.0
				lid.append(at + Vector2(along * r * 1.3, -sin(acos(clampf(along, -1.0, 1.0))) * r * 0.75))
			on.draw_polyline(lid, ink, 4.0, true)
			for i in lid.size():
				lid[i] = Vector2(lid[i].x, 2.0 * at.y - lid[i].y)
			on.draw_polyline(lid, ink, 4.0, true)
			on.draw_circle(at, r * 0.33, ink)
		"play":
			on.draw_colored_polygon(PackedVector2Array([at + Vector2(-r * 0.7, -r), at + Vector2(r, 0), at + Vector2(-r * 0.7, r)]), ink)
		"more":
			for i in 3:
				on.draw_circle(at + Vector2((i - 1) * r * 0.9, 0), 5.0, ink)
		"move":
			for way: Vector2 in [Vector2.LEFT, Vector2.RIGHT, Vector2.UP, Vector2.DOWN]:
				_arrow(on, at, at + way * r * 0.85, ink, 3.0)
		"change", "slide":
			for i in 3:
				var y := at.y + (i - 1) * r * 0.65
				on.draw_line(Vector2(at.x - r, y), Vector2(at.x + r, y), ink, 3.0)
				on.draw_circle(Vector2(at.x + [-0.4, 0.5, -0.1][i] * r, y), 5.5, ink)
		"link":
			on.draw_arc(at - Vector2(r * 0.45, 0), r * 0.55, 0.0, TAU, 20, ink, 4.0, true)
			on.draw_arc(at + Vector2(r * 0.45, 0), r * 0.55, 0.0, TAU, 20, ink, 4.0, true)
		"copy":
			on.draw_rect(Rect2(at + Vector2(-r * 0.9, -r * 0.9), Vector2(r * 1.2, r * 1.2)), ink, false, 3.5)
			on.draw_rect(Rect2(at + Vector2(-r * 0.3, -r * 0.3), Vector2(r * 1.2, r * 1.2)), ink, false, 3.5)
		"remove", "cancel":
			on.draw_line(at - Vector2(r, r) * 0.75, at + Vector2(r, r) * 0.75, ink, 5.0, true)
			on.draw_line(at + Vector2(-r, r) * 0.75, at + Vector2(r, -r) * 0.75, ink, 5.0, true)
		"find":
			on.draw_arc(at, r * 0.7, 0.0, TAU, 24, ink, 3.5, true)
			on.draw_circle(at, 4.0, ink)
		"here":
			on.draw_arc(at, r * 0.55, 0.0, TAU, 24, ink, 3.5, true)
			for way: Vector2 in [Vector2.LEFT, Vector2.RIGHT, Vector2.UP, Vector2.DOWN]:
				on.draw_line(at + way * r * 0.3, at + way * r * 1.05, ink, 3.5)
		"done":
			on.draw_polyline(PackedVector2Array([at + Vector2(-r, 0), at + Vector2(-r * 0.3, r * 0.7), at + Vector2(r, -r * 0.7)]), ink, 5.0, true)
		"left":
			_arrow(on, at + Vector2(r, 0), at - Vector2(r * 0.7, 0), ink)
		"right":
			_arrow(on, at - Vector2(r, 0), at + Vector2(r * 0.7, 0), ink)
		"far":
			_arrow(on, at + Vector2(0, r), at - Vector2(0, r * 0.7), ink)
		"near", "put":
			_arrow(on, at - Vector2(0, r), at + Vector2(0, r * 0.7), ink)
		"raise":
			_arrow(on, at + Vector2(0, r * 0.7), at - Vector2(0, r * 0.75), ink)
			on.draw_line(at + Vector2(-r, r), at + Vector2(r, r), ink, 4.0)
		"lower":
			_arrow(on, at - Vector2(0, r), at + Vector2(0, r * 0.4), ink)
			on.draw_line(at + Vector2(-r, r), at + Vector2(r, r), ink, 4.0)
		"above", "side":
			var eye := at + (Vector2(r * 0.25, -r * 0.95) if icon == "above" else Vector2(r * 1.05, r * 0.2))
			on.draw_line(at + Vector2(-r * 1.2, r * 0.8), at + Vector2(r * 1.2, r * 0.8), ink, 4.0)
			_arrow(on, eye, at + Vector2(-r * 0.2, r * 0.55), ink, 3.0)
			on.draw_circle(eye, 6.0, ink)
		"back":
			on.draw_polyline(PackedVector2Array([at + Vector2(r * 0.4, -r * 0.8), at + Vector2(-r * 0.5, 0), at + Vector2(r * 0.4, r * 0.8)]), ink, 5.0, true)
		"next":
			on.draw_polyline(PackedVector2Array([at + Vector2(-r * 0.4, -r * 0.8), at + Vector2(r * 0.5, 0), at + Vector2(-r * 0.4, r * 0.8)]), ink, 4.0, true)
		"points":
			var line := PackedVector2Array([at + Vector2(-r, r * 0.5), at + Vector2(-r * 0.2, -r * 0.5), at + Vector2(r, r * 0.3)])
			on.draw_polyline(line, ink, 3.0, true)
			for point: Vector2 in line:
				on.draw_circle(point, 5.5, ink)


## A page's rows, to be dragged up and down by a finger anywhere on them: on a button as well as between two. (A
## button under a finger that has begun to drag is let go of, and does nothing.)
class Scroller:
	extends Control

	var content: Control
	var scroll := 0.0
	var _finger := -1
	var _travel := 0.0
	var _moving := false
	var _speed := 0.0
	var _moved_at := -10000

	func _init() -> void:
		clip_contents = true
		mouse_filter = Control.MOUSE_FILTER_PASS

	func hold(what: Control) -> void:
		content = what
		add_child(what)
		what.minimum_size_changed.connect(arrange)
		resized.connect(arrange)

	## How far it can be scrolled.
	func most() -> float:
		return maxf(content.get_combined_minimum_size().y - size.y, 0.0) if content else 0.0

	func arrange() -> void:
		if content == null:
			return
		scroll = clampf(scroll, 0.0, most())
		content.position = Vector2(0.0, -roundf(scroll))
		content.size = Vector2(size.x - 16.0, content.get_combined_minimum_size().y)
		queue_redraw()

	## Whether a finger has only just been dragging it (so that what it was lifted from was not meant to be pressed).
	func just_moved() -> bool:
		return _moving or Time.get_ticks_msec() - _moved_at < 250

	func _input(event: InputEvent) -> void:
		if not is_visible_in_tree():
			return
		if event is InputEventScreenTouch:
			var touch := event as InputEventScreenTouch
			if touch.pressed:
				if _finger == -1 and get_global_rect().has_point(touch.position):
					_finger = touch.index
					_travel = 0.0
					_moving = false
					_speed = 0.0
			elif touch.index == _finger:
				_finger = -1
				if _moving:
					_moved_at = Time.get_ticks_msec()
				_moving = false
		elif event is InputEventScreenDrag and (event as InputEventScreenDrag).index == _finger:
			var drag := event as InputEventScreenDrag
			_travel += drag.relative.y
			if not _moving and absf(_travel) > 18.0:
				_moving = true
				propagate_notification(NOTIFICATION_SCROLL_BEGIN)
			if _moving:
				scroll -= drag.relative.y
				_speed = clampf(-drag.velocity.y, -4000.0, 4000.0)
				arrange()
		elif event is InputEventMouseButton and (event as InputEventMouseButton).pressed and get_global_rect().has_point((event as InputEventMouseButton).position):
			var wheel := (event as InputEventMouseButton).button_index
			if wheel == MOUSE_BUTTON_WHEEL_UP or wheel == MOUSE_BUTTON_WHEEL_DOWN:
				scroll += 90.0 if wheel == MOUSE_BUTTON_WHEEL_DOWN else -90.0
				arrange()

	func _process(delta: float) -> void:
		# (let go of while moving, it runs on a little)
		if _finger == -1 and absf(_speed) > 20.0 and is_visible_in_tree():
			scroll += _speed * delta
			_speed *= pow(0.04, delta)
			if scroll < 0.0 or scroll > most():
				_speed = 0.0
			arrange()

	func _draw() -> void:
		var room := most()
		if room <= 0.0:
			return
		var tall := size.y * size.y / (size.y + room)
		draw_rect(Rect2(size.x - 8.0, 0.0, 8.0, size.y), Color(1, 1, 1, 0.08))
		draw_rect(Rect2(size.x - 8.0, (size.y - tall) * scroll / room, 8.0, tall), Color(1, 1, 1, 0.55))


## A number as a slider wide enough and thick enough for a thumb.
class Slide:
	extends Control

	signal taken
	signal changed(value: float)

	var least := 0.0
	var most := 1.0
	var step := 0.1
	var value := 0.0
	var _finger := -1

	func _init() -> void:
		custom_minimum_size = Vector2(240.0, 88.0)
		set_meta(&"touch", true)
		set_meta(&"word", "slider")

	func show_value(now: float) -> void:
		value = now
		queue_redraw()

	func _gui_input(event: InputEvent) -> void:
		if event is InputEventScreenTouch:
			var touch := event as InputEventScreenTouch
			if touch.pressed and _finger == -1:
				_finger = touch.index
				taken.emit()
				_to(touch.position.x)
			elif not touch.pressed and touch.index == _finger:
				_finger = -1
			accept_event()
		elif event is InputEventScreenDrag and (event as InputEventScreenDrag).index == _finger:
			_to((event as InputEventScreenDrag).position.x)
			accept_event()

	func _to(x: float) -> void:
		var now := snappedf(lerpf(least, most, clampf((x - 36.0) / maxf(size.x - 72.0, 1.0), 0.0, 1.0)), step)
		if not is_equal_approx(now, value):
			value = now
			changed.emit(now)
			queue_redraw()

	func _draw() -> void:
		var middle := size.y * 0.5
		var along := clampf(inverse_lerp(least, most, value), 0.0, 1.0)
		var grip := Vector2(36.0 + along * (size.x - 72.0), middle)
		draw_line(Vector2(36.0, middle), Vector2(size.x - 36.0, middle), Color(0.05, 0.04, 0.03), 22.0, true)
		draw_line(Vector2(36.0, middle), grip, Color(0.8, 0.62, 0.28), 22.0, true)
		draw_circle(grip, 34.0, Color(0.99, 0.95, 0.85))
		draw_arc(grip, 34.0, 0.0, TAU, 32, Color(0, 0, 0, 0.5), 3.0, true)
