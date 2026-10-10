class_name TombEditor
extends Node3D
## The tomb editor (`tomb_editor.tscn`): makes a tomb by hand, with fingers,
## to be played like the daily one. What it makes is a `TombSpec`; the tomb
## that stands on the screen is that, built as the game builds it, seen from
## the side as it is played.
##
## LOOKING ABOUT. One finger drags the tomb about; two pinch to come nearer or
## go further ("+", "-" and "All" do the same). Touch a room to choose it.
##
## THE ROOMS run along the bottom in their order, from the entrance to the
## burial chamber. Touch one to choose it and go to it; "+ Room" puts a new one
## after the chosen one. What the chosen room is comes up at the right: what
## kind of room, whether it is dark, a pit, a mummy and what holds it back,
## what lies in it to be carried, the way on to the next room, and what locks
## the door on (with whatever that lock needs left somewhere for it).
##
## WHETHER IT WORKS is worked out again after every change (`TombSolver`: every
## order he could do things in is tried) and said under the buttons: that it
## can be finished, or why not. "Way through" shows one way, step by step.
## A tomb that cannot be built at all (a locked crawl, say) says what is wrong,
## and what stood before stays standing until it is put right.
##
## KEEPING IT. Every change is saved on the device under the tomb's name.
## "Tombs" has the others, a new one, one of the generator's from a number to
## change, and the tomb as text. "Play" plays it; from there "Edit" comes back.

const PANEL := 340.0
const FOV := 30.0
const NEAREST := 8.0
const FURTHEST := 420.0
const WAY_SHORT := {"open": "doorway", "stairs": "stairs", "crawl": "crawl", "flood": "water", "shaft": "ladder", "gap": "pit, hook"}
const LOCK_SHORT := {"none": "", "work": "block + plate", "cross": "plate, block from before", "brazier": "brazier", "offering": "block + jar",
	"lever_above": "stone in a loft", "lever_below": "stone under a well", "bypass": "over the wall"}
const HELP := "One finger drags the tomb about; two pinch to come nearer. Touch a room to choose it, or use the row along the bottom.\nThe panel at the right changes the chosen room: what it is, what is in it, the way on, and what locks the door on.\nUnder these buttons it says whether the tomb can be finished. Way through shows how."

## For the tools: nothing is written to the device.
static var keeps := true

## The tomb being made (see TombSpec), which room of it is chosen, and what
## `TombSpec.check` last said of it.
var spec := {}
var chosen := 1
var found := {}
var built: TombBuilder

var _layout: TombLayout
var _holder: Node3D
var _cam: Camera3D
var _focus := Vector2(6.0, 2.0)
var _reach := 30.0
var _dirty := -1.0
var _undo: Array[String] = []
var _redo: Array[String] = []
var _touches := {}
var _travel := 0.0
var _began := 0
var _hint := ""
var _hint_until := 0.0

var _pad: Control
var _ui: Control
var _status: Label
var _strip: HBoxContainer
var _shelf: PanelContainer
var _side: PanelContainer
var _inspector: VBoxContainer
var _sheet: PanelContainer
var _rows: VBoxContainer


func _ready() -> void:
	get_tree().paused = false
	_build_world()
	_build_ui()
	take(TombSpec.current())
	rebuild()
	look_at_room(chosen)
	_say("One finger drags the tomb about, two pinch. Touch a room to choose it.  ( ? for more )", 7.0)


# --- The tomb itself

func rooms() -> Array:
	return spec["rooms"]


## Takes a tomb to work on, in place of the one there was.
func take(tomb: Dictionary) -> void:
	spec = tomb.duplicate(true)
	_undo.clear()
	_redo.clear()
	chosen = clampi(1, 0, rooms().size() - 1)
	_dirty = 0.0
	_keep()
	_show_strip()
	_show_inspector()


## Works out again whether it can be finished, and stands it up again.
func rebuild() -> void:
	_dirty = -1.0
	found = TombSpec.check(spec)
	if found["layout"] == null:
		return
	_layout = found["layout"]
	if _holder:
		_holder.queue_free()
	_holder = Node3D.new()
	add_child(_holder)
	built = TombBuilder.build(_layout, _holder)
	# Nothing in it stirs: it is only to look at.
	for entry in built.mummies:
		(entry["node"] as Node).set_physics_process(false)
	for block in built.blocks:
		(block["body"] as RigidBody3D).freeze = true


func choose(index: int) -> void:
	chosen = clampi(index, 0, rooms().size() - 1)
	_show_strip()
	_show_inspector()


## Changes something of the chosen room, and whatever has to follow from it.
func set_value(key: String, value: Variant) -> void:
	_remember()
	var told: Dictionary = rooms()[chosen]
	told[key] = value
	if key == "lock":
		match value:
			"brazier":
				told["dark"] = true
				_leave_one("torch")
			"offering":
				_leave_one("jar")
			"lever_above", "lever_below":
				var hosts := _hosts(value)
				if not hosts.is_empty():
					told["stone_in"] = hosts.back()
	elif key == "way" and value == "gap":
		_leave_one("hook")
	_changed()
	_show_inspector()


## Puts a new room after the chosen one.
func add_after() -> void:
	if rooms().size() >= TombSpec.MOST:
		_say("A tomb has at most %d rooms down its axis." % TombSpec.MOST, 4.0)
		return
	_remember()
	var at := mini(chosen, rooms().size() - 2) + 1
	_renumber(func(index: int) -> int: return index + 1 if index >= at else index)
	rooms().insert(at, TombSpec.room("corridor"))
	chosen = at
	_changed()
	_show_inspector()


## A second room like the chosen one, after it.
func copy() -> void:
	if not _is_middle(chosen) or rooms().size() >= TombSpec.MOST:
		return
	_remember()
	var at := chosen + 1
	_renumber(func(index: int) -> int: return index + 1 if index >= at else index)
	rooms().insert(at, (rooms()[chosen] as Dictionary).duplicate(true))
	chosen = at
	_changed()
	_show_inspector()


## Takes the chosen room away (not the entrance, nor the burial chamber).
func remove() -> void:
	if not _is_middle(chosen):
		return
	if rooms().size() <= TombSpec.FEWEST:
		_say("A tomb wants at least %d rooms." % TombSpec.FEWEST, 4.0)
		return
	_remember()
	var at := chosen
	rooms().remove_at(at)
	_renumber(func(index: int) -> int: return index - 1 if index > at else index)
	chosen = mini(chosen, rooms().size() - 2)
	_changed()
	_show_inspector()


## Moves the chosen room one place earlier (-1) or later (1).
func move(by: int) -> void:
	var to := chosen + by
	if not _is_middle(chosen) or not _is_middle(to):
		return
	_remember()
	var from := chosen
	var held: Dictionary = rooms()[from]
	rooms()[from] = rooms()[to]
	rooms()[to] = held
	_renumber(func(index: int) -> int: return to if index == from else (from if index == to else index))
	chosen = to
	_changed()
	_show_inspector()


func undo() -> void:
	if _undo.is_empty():
		return
	_redo.append(TombSpec.to_text(spec))
	_restore(_undo.pop_back())


func redo() -> void:
	if _redo.is_empty():
		return
	_undo.append(TombSpec.to_text(spec))
	_restore(_redo.pop_back())


func _restore(text: String) -> void:
	spec = TombSpec.from_text(text)
	chosen = clampi(chosen, 0, rooms().size() - 1)
	_changed()
	_show_inspector()


func _is_middle(index: int) -> bool:
	return index > 0 and index < rooms().size() - 1


# Every seal stone says which room it is over or under by that room's place: when places change, so must they.
func _renumber(to: Callable) -> void:
	for told: Dictionary in rooms():
		told["stone_in"] = int(to.call(int(told.get("stone_in", 0))))


# Leaves one of a thing in the room before the chosen one, if there is none at or before it.
func _leave_one(what: String) -> void:
	for i in chosen + 1:
		if int(rooms()[i].get(what, 0)) > 0:
			return
	var at := maxi(chosen - 1, 0)
	rooms()[at][what] = 1
	_say("A %s is left in %s for it." % [String(TombSpec.THING_TITLES[what]).to_lower(), TombSpec.room_title(spec, at)], 5.0)


# The rooms a seal stone for the chosen room's door could be over (a loft) or under (a well).
func _hosts(lock: String) -> Array:
	var hosts: Array = []
	for i in range(1, chosen + 1):
		if (rooms()[i]["role"] == "well") == (lock == "lever_below"):
			hosts.append(i)
	return hosts


func _remember() -> void:
	_undo.append(TombSpec.to_text(spec))
	if _undo.size() > 60:
		_undo.pop_front()
	_redo.clear()
	# (whatever was being said gives way to what the change brings)
	_hint_until = 0.0


func _changed() -> void:
	_dirty = 0.25
	_keep()
	_show_strip()


func _keep() -> void:
	if keeps and not TombSpec.keep(spec):
		_say("It could not be saved here. Use Tombs to copy it as text.", 6.0)


# --- Playing it, and the others

func play() -> void:
	if _dirty >= 0.0:
		rebuild()
	if not (found["problems"] as PackedStringArray).is_empty():
		_say("It cannot be built yet: %s" % found["problems"][0], 6.0)
		return
	_keep()
	TombLevel.play = {"mode": "custom", "spec": spec.duplicate(true)}
	get_tree().change_scene_to_file("res://tomb.tscn")


func leave() -> void:
	_keep()
	TombLevel.play = {}
	get_tree().change_scene_to_file("res://tomb.tscn")


## One way through, step by step; or what is wrong.
func show_way() -> void:
	if _dirty >= 0.0:
		rebuild()
	var rows := _open_sheet("Whether it works")
	rows.add_child(_heading(found["says"]))
	for problem: String in found["problems"]:
		rows.add_child(_caption(problem))
	for warning: String in found["warnings"]:
		rows.add_child(_caption("Take care: %s." % warning))
	var steps: Array = found["solved"].get("steps", [])
	if not steps.is_empty():
		var lines: PackedStringArray = []
		for i in steps.size():
			lines.append("%d.  %s" % [i + 1, TombSpec.step_words(spec, found["plan"], steps[i])])
		rows.add_child(_caption("One way through (the shortest):"))
		rows.add_child(_caption("\n".join(lines)))
	elif (found["problems"] as PackedStringArray).is_empty():
		rows.add_child(_caption("Every order he could do things in was tried (%d positions)." % int(found["solved"].get("positions", 0))))
	rows.add_child(_button("Close", _close_sheet))


## The tombs kept on this device, a new one, one from a number, and this one as text.
func show_tombs(open: bool) -> void:
	if not open:
		_close_sheet()
		return
	var rows := _open_sheet("Your tombs")
	rows.add_child(_caption("This one is called:"))
	var name := LineEdit.new()
	name.text = spec.get("name", "")
	name.custom_minimum_size.y = 50.0
	name.add_theme_font_size_override("font_size", 20)
	var rename := func(_text := "") -> void:
		var wanted := name.text.strip_edges()
		if wanted == "" or wanted == spec["name"]:
			return
		if keeps:
			TombSpec.forget(spec["name"])
		spec["name"] = TombSpec.free_name(wanted) if keeps else wanted
		name.text = spec["name"]
		name.release_focus()
		_keep()
	name.text_submitted.connect(rename)
	name.focus_exited.connect(rename)
	rows.add_child(name)
	for other: String in TombSpec.names():
		if other == spec["name"]:
			continue
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 6)
		rows.add_child(row)
		var open_it := _button(other, func() -> void:
			take(TombSpec.open(other))
			look_at_room(chosen)
			_close_sheet())
		open_it.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(open_it)
		row.add_child(_button("Delete", func() -> void:
			TombSpec.forget(other)
			show_tombs(true)))
	rows.add_child(_button("A new tomb", func() -> void:
		take(TombSpec.fresh(TombSpec.free_name("My tomb")))
		look_at_room(chosen)
		_close_sheet()))
	rows.add_child(_caption("Or begin from one of the generator's: a number, then how hard."))
	var number := LineEdit.new()
	number.placeholder_text = "any number"
	number.custom_minimum_size.y = 50.0
	rows.add_child(number)
	var hard := HBoxContainer.new()
	hard.add_theme_constant_override("separation", 6)
	rows.add_child(hard)
	for level in 3:
		var pick := _button(TombGenerator.DIFFICULTY_NAMES[level], func() -> void:
			var from := int(number.text) if number.text.is_valid_int() else randi_range(1, 999999)
			var made := TombSpec.from_seed(from, level)
			made["name"] = TombSpec.free_name(made["name"])
			take(made)
			look_at_room(chosen)
			_close_sheet())
		pick.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		hard.add_child(pick)
	rows.add_child(_button("Other sizes for the rooms", func() -> void:
		_remember()
		spec["seed"] = int(spec.get("seed", 1)) + 1
		_changed()
		_close_sheet()))
	rows.add_child(_caption("The tomb as text: copy it to keep it anywhere else or to send it; paste one here and press Use this text to bring it in."))
	var text := TextEdit.new()
	text.text = TombSpec.to_text(spec)
	text.custom_minimum_size.y = 150.0
	text.add_theme_font_size_override("font_size", 12)
	rows.add_child(text)
	var row := HFlowContainer.new()
	row.add_theme_constant_override("h_separation", 6)
	rows.add_child(row)
	row.add_child(_button("Copy", func() -> void:
		DisplayServer.clipboard_set(text.text)
		_say("Copied.")))
	row.add_child(_button("Paste", func() -> void: text.text = DisplayServer.clipboard_get()))
	row.add_child(_button("Use this text", func() -> void:
		var brought := TombSpec.from_text(text.text)
		if brought.is_empty():
			_say("That text is not a tomb.", 4.0)
			return
		_remember()
		var name_now: String = spec["name"]
		spec = brought
		spec["name"] = name_now
		chosen = clampi(chosen, 0, rooms().size() - 1)
		_changed()
		_show_inspector()
		_close_sheet()))
	rows.add_child(_button("Close", _close_sheet))


# --- Looking about

## Goes to a room: it fills most of the view.
func look_at_room(index: int) -> void:
	var span := _span_of(index)
	if span.is_empty():
		return
	_reach = clampf((span[1] - span[0]) * 2.4, 22.0, 70.0)
	_focus = Vector2((span[0] + span[1]) * 0.5 + _hidden() * 0.5 * _per_pixel(), span[2] + 2.4)


func look_at_all() -> void:
	if _layout == null:
		return
	var free := maxf(_pad.size.x - _hidden(), 200.0)
	_reach = clampf((_layout.length + 8.0) / (2.0 * tan(deg_to_rad(FOV * 0.5)) * free / _pad.size.y), 22.0, FURTHEST)
	_focus = Vector2(_layout.length * 0.5 - 2.0 + _hidden() * 0.5 * _per_pixel(), -_layout.depth * 0.5 + 2.0)


# How much of the width of the screen the panel at the right covers.
func _hidden() -> float:
	return PANEL + 16.0 if _side and _side.visible else 0.0


# Where a room on the axis is, as it stands: from x, to x, its floor, its ceiling. Empty if it does not stand.
func _span_of(index: int) -> Array:
	if _layout == null or index < 0 or index >= _layout.plan.spine().size():
		return []
	var room := _layout.plan.spine()[index]
	var info: Dictionary = _layout.rooms[room.id]
	if not info.has("x0") or not info.has("x1"):
		return []
	var floor: float = info.get("floor", 0.0)
	return [float(info["x0"]), float(info["x1"]), floor, floor + float(TombLayout.HEIGHTS[room.role])]


func _per_pixel() -> float:
	return 2.0 * _reach * tan(deg_to_rad(FOV * 0.5)) / maxf(_pad.size.y, 1.0)


func _to_screen(x: float, y: float) -> Vector2:
	var each := _per_pixel()
	return Vector2(_pad.size.x * 0.5 + (x - _focus.x) / each, _pad.size.y * 0.5 - (y - _focus.y) / each)


func _process(delta: float) -> void:
	if _dirty >= 0.0:
		_dirty -= delta
		if _dirty < 0.0:
			rebuild()
	if _layout:
		_focus.x = clampf(_focus.x, -12.0, _layout.length + 12.0)
		_focus.y = clampf(_focus.y, -_layout.depth - 12.0, 16.0)
	_cam.position = Vector3(_focus.x, _focus.y, _reach)
	# Only what is in sight is drawn.
	if built and _layout:
		var half := _per_pixel() * _pad.size.x * 0.5 + 8.0
		for room in _layout.plan.spine():
			var info: Dictionary = _layout.rooms[room.id]
			var node := built.room_nodes[room.id]
			if is_instance_valid(node) and info.has("x1"):
				node.visible = float(info["x1"]) > _focus.x - half and float(info["x0"]) < _focus.x + half
	_status.text = _status_line()
	_status.modulate = Color(1.0, 0.72, 0.6) if not found.get("ok", true) and Time.get_ticks_msec() * 0.001 >= _hint_until else Color.WHITE
	_pad.queue_redraw()


func _status_line() -> String:
	if Time.get_ticks_msec() * 0.001 < _hint_until:
		return _hint
	if _dirty >= 0.0:
		return "Working it out..."
	var says: String = found.get("says", "")
	var warnings: PackedStringArray = found.get("warnings", PackedStringArray())
	if not warnings.is_empty():
		says += "\nTake care: %s." % warnings[0]
	return says


func _say(text: String, seconds := 2.5) -> void:
	_hint = text
	_hint_until = Time.get_ticks_msec() * 0.001 + seconds


func _pad_input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		var touch := event as InputEventScreenTouch
		if touch.pressed:
			_touches[touch.index] = touch.position
			if _touches.size() == 1:
				_travel = 0.0
				_began = Time.get_ticks_msec()
			else:
				_travel = 1000.0
		else:
			var was_tap := _touches.size() == 1 and _travel < 14.0 and Time.get_ticks_msec() - _began < 450
			_touches.erase(touch.index)
			if was_tap:
				_tapped(touch.position)
		_pad.accept_event()
	elif event is InputEventScreenDrag:
		var drag := event as InputEventScreenDrag
		if not _touches.has(drag.index):
			return
		var before: Vector2 = _touches[drag.index]
		_touches[drag.index] = drag.position
		if _touches.size() == 1:
			_travel += drag.relative.length()
			if _travel >= 14.0:
				var each := _per_pixel()
				_focus += Vector2(-(drag.position.x - before.x), drag.position.y - before.y) * each
		elif _touches.size() == 2:
			var other: Vector2 = _touches[_touches.keys()[0] if _touches.keys()[1] == drag.index else _touches.keys()[1]]
			var was := before - other
			var now := drag.position - other
			if was.length() > 10.0 and now.length() > 10.0:
				_reach = clampf(_reach * was.length() / now.length(), NEAREST, FURTHEST)
		_pad.accept_event()
	elif event is InputEventMouseButton:
		var button := event as InputEventMouseButton
		if button.pressed and button.button_index == MOUSE_BUTTON_WHEEL_UP:
			_reach = maxf(_reach * 0.9, NEAREST)
		elif button.pressed and button.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			_reach = minf(_reach * 1.1, FURTHEST)


func _tapped(screen: Vector2) -> void:
	if _layout == null:
		return
	var x := _focus.x + (screen.x - _pad.size.x * 0.5) * _per_pixel()
	var room := _layout.room_at(x)
	if room >= 0:
		choose(_layout.plan.rooms[room].spine)


# What is drawn over the tomb: each room's number and name, what the way on from it is, and the chosen one ringed.
func _draw_pad() -> void:
	if _layout == null:
		return
	var font := ThemeDB.fallback_font
	var count := mini(rooms().size(), _layout.plan.spine().size())
	# (from far off there is no room for more than each room's number)
	var far := _reach > 85.0
	for i in count:
		var span := _span_of(i)
		if span.is_empty():
			continue
		var low := _to_screen(span[0], span[2])
		var high := _to_screen(span[1], span[3])
		if high.x < -40.0 or low.x > _pad.size.x + 40.0:
			continue
		var told: Dictionary = rooms()[i]
		var is_chosen := i == chosen
		var colour := Color(1.0, 0.9, 0.5) if is_chosen else Color(1.0, 1.0, 1.0, 0.55)
		if is_chosen:
			_pad.draw_rect(Rect2(low.x, high.y, high.x - low.x, low.y - high.y), Color(1.0, 0.9, 0.5, 0.9), false, 3.0)
		else:
			_pad.draw_line(Vector2(low.x, low.y), Vector2(low.x, low.y + 16.0), colour, 2.0)
		var at := Vector2(low.x + 8.0, high.y - 10.0)
		var title := str(i + 1) if far else TombSpec.room_title(spec, i)
		_pad.draw_string_outline(font, at, title, HORIZONTAL_ALIGNMENT_LEFT, -1.0, 20, 7, Color(0.0, 0.0, 0.0, 0.8))
		_pad.draw_string(font, at, title, HORIZONTAL_ALIGNMENT_LEFT, -1.0, 20, colour)
		if i < count - 1 and not far:
			var way: String = WAY_SHORT.get(told.get("way", "open"), "")
			var lock: String = LOCK_SHORT.get(told.get("lock", "none"), "")
			if told.get("lock", "none") == "bypass":
				way = "stairs"
			var says := way if lock == "" else "%s  ·  door: %s" % [way, lock]
			var wide := font.get_string_size(says, HORIZONTAL_ALIGNMENT_LEFT, -1.0, 16).x
			var under := Vector2(high.x - wide - 6.0, low.y + 30.0)
			_pad.draw_string_outline(font, under, says, HORIZONTAL_ALIGNMENT_LEFT, -1.0, 16, 6, Color(0.0, 0.0, 0.0, 0.8))
			_pad.draw_string(font, under, says, HORIZONTAL_ALIGNMENT_LEFT, -1.0, 16, Color(0.7, 0.95, 0.6) if lock != "" else Color(0.8, 0.85, 1.0, 0.8))


# --- What is on the screen

func _build_world() -> void:
	var environment := Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = Color(0.05, 0.055, 0.075)
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color(0.6, 0.58, 0.62)
	# (lighter than it is played in: here it is to be seen, all of it, the dark rooms too)
	environment.ambient_light_energy = 1.1
	environment.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	var world := WorldEnvironment.new()
	world.environment = environment
	add_child(world)
	var fill := DirectionalLight3D.new()
	fill.rotation_degrees = Vector3(-24.0, 14.0, 0.0)
	fill.light_color = Color(0.9, 0.86, 0.8)
	fill.light_energy = 0.6
	add_child(fill)
	Sand.sun_gain = 1.0
	Sand.sky = Color.BLACK
	_cam = Camera3D.new()
	_cam.fov = FOV
	_cam.far = 1200.0
	add_child(_cam)
	_cam.make_current()


func _build_ui() -> void:
	var layer := CanvasLayer.new()
	add_child(layer)
	_pad = Control.new()
	_pad.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_pad.mouse_filter = Control.MOUSE_FILTER_STOP
	_pad.gui_input.connect(_pad_input)
	_pad.draw.connect(_draw_pad)
	layer.add_child(_pad)
	# Everything else stands inside the part of the screen that is safe to use.
	_ui = Control.new()
	_ui.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_ui.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(_ui)
	get_viewport().size_changed.connect(_keep_clear)
	_keep_clear.call_deferred()

	# Along the top: what is done to the whole tomb.
	var top := HBoxContainer.new()
	top.position = Vector2(8.0, 8.0)
	top.add_theme_constant_override("separation", 7)
	_ui.add_child(top)
	top.add_child(_button("Play", play))
	top.add_child(_button("Undo", undo))
	top.add_child(_button("Redo", redo))
	top.add_child(_button("Tombs", show_tombs.bind(true)))
	top.add_child(_button("Way through", show_way))
	top.add_child(_button("Panel", func() -> void: _show_side(not _side.visible)))
	top.add_child(_button(" ? ", func() -> void: _say(HELP, 14.0)))
	top.add_child(_button("Leave", leave))
	_status = Label.new()
	_status.add_theme_font_size_override("font_size", 19)
	_status.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.85))
	_status.add_theme_constant_override("outline_size", 7)
	_status.position = Vector2(76.0, 70.0)
	_status.size = Vector2(820.0, 60.0)
	_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_status.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_ui.add_child(_status)

	# Down the left: nearer, further, and all of it.
	var views := [["+", func() -> void: _reach = maxf(_reach * 0.75, NEAREST)], ["-", func() -> void: _reach = minf(_reach * 1.33, FURTHEST)], ["All", look_at_all]]
	for i in views.size():
		var view := _button(views[i][0], views[i][1])
		view.position = Vector2(8.0, 70.0 + i * 60.0)
		view.custom_minimum_size = Vector2(58.0, 54.0)
		_ui.add_child(view)

	# Along the bottom: the rooms in their order.
	_shelf = PanelContainer.new()
	_shelf.anchor_top = 1.0
	_shelf.anchor_bottom = 1.0
	_shelf.anchor_right = 1.0
	_shelf.offset_left = 8.0
	_shelf.offset_right = -PANEL - 16.0
	_shelf.offset_top = -84.0
	_shelf.offset_bottom = -8.0
	_shelf.add_theme_stylebox_override("panel", _backing(0.9))
	_ui.add_child(_shelf)
	var scroll := ScrollContainer.new()
	scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_shelf.add_child(scroll)
	_strip = HBoxContainer.new()
	_strip.add_theme_constant_override("separation", 7)
	scroll.add_child(_strip)

	# At the right: the room that is chosen.
	_side = PanelContainer.new()
	_side.anchor_left = 1.0
	_side.anchor_right = 1.0
	_side.anchor_bottom = 1.0
	_side.offset_left = -PANEL - 8.0
	_side.offset_right = -8.0
	_side.offset_top = 8.0
	_side.offset_bottom = -8.0
	_side.add_theme_stylebox_override("panel", _backing(0.94))
	_ui.add_child(_side)
	var side_scroll := ScrollContainer.new()
	side_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_side.add_child(side_scroll)
	_inspector = VBoxContainer.new()
	_inspector.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_inspector.add_theme_constant_override("separation", 6)
	side_scroll.add_child(_inspector)

	# Over everything, when asked for: the other tombs, or the way through.
	_sheet = PanelContainer.new()
	_sheet.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_sheet.offset_left = 150.0
	_sheet.offset_right = -150.0
	_sheet.offset_top = 30.0
	_sheet.offset_bottom = -30.0
	_sheet.visible = false
	_sheet.add_theme_stylebox_override("panel", _backing(0.98))
	_ui.add_child(_sheet)
	var sheet_scroll := ScrollContainer.new()
	sheet_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_sheet.add_child(sheet_scroll)
	_rows = VBoxContainer.new()
	_rows.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_rows.add_theme_constant_override("separation", 7)
	sheet_scroll.add_child(_rows)


# Keeps everything clear of the edges a phone cannot show or be touched at (as LevelEditor does).
func _keep_clear() -> void:
	var window := Vector2(DisplayServer.window_get_size())
	var safe := DisplayServer.get_display_safe_area()
	var edges := [0.0, 0.0, 0.0, 0.0]
	var fills := (window - Vector2(DisplayServer.screen_get_size())).abs().length() < 8.0
	if fills and OS.has_feature("mobile") and safe.size.x > 0 and safe.size.y > 0:
		var scale := _pad.size.x / window.x
		edges = [safe.position.x * scale, safe.position.y * scale, (window.x - safe.end.x) * scale, (window.y - safe.end.y) * scale]
	elif OS.has_feature("web") and DisplayServer.is_touchscreen_available():
		edges = [30.0, 0.0, 30.0, 6.0]
	_ui.offset_left = clampf(edges[0], 0.0, 90.0)
	_ui.offset_top = clampf(edges[1], 0.0, 60.0)
	_ui.offset_right = -clampf(edges[2], 0.0, 90.0)
	_ui.offset_bottom = -clampf(edges[3], 0.0, 60.0)


# What a panel stands on: dark enough that the tomb behind does not show through the words.
func _backing(solid: float) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = Color(0.07, 0.07, 0.09, solid)
	box.set_corner_radius_all(6)
	box.set_content_margin_all(8.0)
	return box


func _show_side(shown: bool) -> void:
	_side.visible = shown
	_shelf.offset_right = -PANEL - 16.0 if shown else -8.0


func _open_sheet(title: String) -> VBoxContainer:
	for old in _rows.get_children():
		_rows.remove_child(old)
		old.queue_free()
	_sheet.visible = true
	var heading := _caption(title.to_upper())
	heading.modulate.a = 0.6
	_rows.add_child(heading)
	_rows.add_child(_button("Close", _close_sheet))
	return _rows


func _close_sheet() -> void:
	_sheet.visible = false


# The rooms along the bottom, and between each two the way from one to the next.
func _show_strip() -> void:
	if _strip == null:
		return
	for old in _strip.get_children():
		_strip.remove_child(old)
		old.queue_free()
	var count := rooms().size()
	for i in count:
		var chip := _button(TombSpec.room_title(spec, i), func() -> void:
			choose(i)
			look_at_room(i))
		if i == chosen:
			chip.modulate = Color(1.0, 0.9, 0.5)
		_strip.add_child(chip)
		if i == chosen and i < count - 1:
			_strip.add_child(_button("+ Room", add_after))


# What can be changed about the chosen room.
func _show_inspector() -> void:
	if _inspector == null:
		return
	for old in _inspector.get_children():
		_inspector.remove_child(old)
		old.queue_free()
	var count := rooms().size()
	var index := chosen
	var told: Dictionary = rooms()[index]
	var last := index == count - 1
	_inspector.add_child(_heading("Room %d of %d" % [index + 1, count]))
	if _is_middle(index):
		var row := HFlowContainer.new()
		row.add_theme_constant_override("h_separation", 5)
		row.add_theme_constant_override("v_separation", 5)
		_inspector.add_child(row)
		row.add_child(_button("< Earlier", move.bind(-1)))
		row.add_child(_button("Later >", move.bind(1)))
		row.add_child(_button("Copy", copy))
		row.add_child(_button("Remove", remove))
		var titles: Array = []
		for role: String in TombSpec.MIDDLE_ROLES:
			titles.append(TombSpec.ROLE_TITLES[role])
		_choice("What it is", titles, TombSpec.MIDDLE_ROLES.find(told["role"]), func(picked: int) -> void: set_value("role", TombSpec.MIDDLE_ROLES[picked]))
	else:
		_inspector.add_child(_caption("The burial chamber: the falcon is here, at its far end." if last else "The entrance: out of doors, where he starts and where he has to get back to."))
	if index > 0:
		_toggle("Dark: no torches on its walls", "dark")
	if _is_middle(index):
		_toggle("A pit to jump", "pit")
	if index > 0:
		_choice("A mummy", ["None"] + TombSpec.MUMMY_TITLES, int(told["mummy"]) + 1, func(picked: int) -> void: set_value("mummy", picked - 1))
		if int(told["mummy"]) >= 0:
			if last:
				_inspector.add_child(_caption("It guards the falcon, and wakes when the falcon is taken."))
			var barriers: Array = TombSpec.BARRIER_TITLES.keys()
			var barrier_titles: Array = []
			for key: String in barriers:
				barrier_titles.append(TombSpec.BARRIER_TITLES[key])
			_choice("Held back by", barrier_titles, maxi(barriers.find(told["barrier"]), 0), func(picked: int) -> void: set_value("barrier", barriers[picked]))
	_inspector.add_child(_caption("Lying here, to be carried:"))
	for what: String in TombSpec.THINGS:
		_count(TombSpec.THING_TITLES[what], what)
	if last:
		return
	var ways: Array = ["open", "stairs"] if index == 0 else TombSpec.WAYS
	var way_titles: Array = []
	for way: String in ways:
		way_titles.append(TombSpec.WAY_TITLES[way])
	_choice("The way on", way_titles, maxi(ways.find(told["way"]), 0), func(picked: int) -> void: set_value("way", ways[picked]))
	if index == 0:
		return
	var lock_titles: Array = []
	for lock: String in TombSpec.LOCKS:
		lock_titles.append(TombSpec.LOCK_TITLES[lock])
	_choice("What opens the door on", lock_titles, maxi(TombSpec.LOCKS.find(told["lock"]), 0), func(picked: int) -> void: set_value("lock", TombSpec.LOCKS[picked]))
	if TombSpec.LOCK_NOTES[told["lock"]] != "":
		_inspector.add_child(_caption(TombSpec.LOCK_NOTES[told["lock"]]))
	if told["lock"] in ["lever_above", "lever_below"]:
		var hosts := _hosts(told["lock"])
		if hosts.is_empty():
			_inspector.add_child(_caption("There is no well at or before this room: make one of the rooms a well." if told["lock"] == "lever_below" else "There is no room to put a loft over."))
		else:
			var host_titles: Array = []
			for host: int in hosts:
				host_titles.append(TombSpec.room_title(spec, host))
			_choice("Its stone is under" if told["lock"] == "lever_below" else "Its stone is over", host_titles, maxi(hosts.find(int(told["stone_in"])), 0),
					func(picked: int) -> void: set_value("stone_in", hosts[picked]))


# One of a list, of the chosen room's.
func _choice(title: String, options: Array, now: int, picked: Callable) -> void:
	_inspector.add_child(_caption(title))
	var choice := OptionButton.new()
	choice.focus_mode = Control.FOCUS_NONE
	choice.custom_minimum_size.y = 52.0
	choice.add_theme_font_size_override("font_size", 18)
	for option: String in options:
		choice.add_item(option)
	# (the list that drops down wants rows a finger can hit)
	choice.get_popup().add_theme_font_size_override("font_size", 20)
	choice.get_popup().add_theme_constant_override("v_separation", 14)
	choice.selected = now
	choice.item_selected.connect(picked)
	_inspector.add_child(choice)


func _toggle(title: String, key: String) -> void:
	var box := CheckButton.new()
	box.text = title
	box.focus_mode = Control.FOCUS_NONE
	box.custom_minimum_size.y = 50.0
	box.button_pressed = rooms()[chosen].get(key, false)
	box.toggled.connect(func(on: bool) -> void: set_value(key, on))
	_inspector.add_child(box)


# How many of a thing lie in the chosen room: a step down, the number, a step up.
func _count(title: String, key: String) -> void:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 5)
	_inspector.add_child(row)
	var now := int(rooms()[chosen].get(key, 0))
	var less := _button("-", func() -> void: set_value(key, maxi(now - 1, 0)))
	less.custom_minimum_size.x = 54.0
	less.disabled = now <= 0
	var label := _caption("%s: %d" % [title, now])
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	label.autowrap_mode = TextServer.AUTOWRAP_OFF
	var more := _button("+", func() -> void: set_value(key, mini(now + 1, 3)))
	more.custom_minimum_size.x = 54.0
	row.add_child(less)
	row.add_child(label)
	row.add_child(more)


func _button(text: String, pressed: Callable) -> Button:
	var button := Button.new()
	button.text = text
	button.focus_mode = Control.FOCUS_NONE
	button.custom_minimum_size.y = 52.0
	button.add_theme_font_size_override("font_size", 19)
	if pressed.is_valid():
		button.pressed.connect(pressed)
	return button


func _heading(text: String) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", 22)
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	return label


func _caption(text: String) -> Label:
	var label := Label.new()
	label.text = text
	label.modulate.a = 0.85
	label.add_theme_font_size_override("font_size", 17)
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	return label
