class_name LevelEditor
extends Control
## The level editor: changes the desert's layout (`LevelLayout`) from inside
## the game, with fingers. It is opened from the menu ("Edit this level"),
## over a level that can be edited (`Desert`); the game stands still under it.
##
## LOOKING ABOUT. One finger drags the ground about; two pinch to come nearer
## or go further, and turn to turn; the slider at the left tips the view. (With
## a mouse: drag, the wheel, and the right button to turn and tip.)
##
## PUTTING THINGS IN. The pages down the left (Ground, Water, Stone, Camp,
## People, Puzzle, Guns) each fill the strip along the bottom with what can be
## placed. Touch one, then touch the ground: it is put there, and chosen.
##
## CHANGING THEM. Touch a thing to choose it; what can be changed about it
## comes up at the right. Drag it by its mark to move it, or use "Move to..."
## and touch where it should go. A river is a line of points: drag each, add
## more. Whatever is worked by something else (a door, a bridge, a hound) has
## "Choose what works it": touch the plates and targets that should.
##
## THE GROUND. "Level" at the top of the pages has the size of the desert, its
## dunes, the wind and the weather. Level ground, dunes placed by hand, ponds
## and rivers are things like any other; the ground is made again a moment
## after any of them is changed.
##
## KEEPING IT. Every change is saved on the device as it is made, and is what
## the game plays from then on. "More" has the way back to the level the game
## came with, and the whole level as text, to copy it somewhere else or bring
## one in. "Play" starts the level from its start; "Play here" from where the
## view is.

const PANEL := 330.0
## How far a touch may be from a thing's mark and still be meant for it, in pixels of the 720-high screen.
const TOUCH := 54.0
const DOT := {
	"pad": Color(0.95, 0.85, 0.5), "dune": Color(0.95, 0.75, 0.4), "ridge": Color(0.95, 0.75, 0.4), "pond": Color(0.4, 0.75, 0.95),
	"river": Color(0.4, 0.75, 0.95), "pool": Color(0.4, 0.75, 0.95), "person": Color(0.95, 0.5, 0.5), "plate": Color(0.7, 0.95, 0.5),
	"door": Color(0.7, 0.95, 0.5), "mover": Color(0.7, 0.95, 0.5), "thing": Color(0.85, 0.6, 0.95), "checkpoint": Color(1.0, 1.0, 1.0), "start": Color(1.0, 1.0, 1.0),
}
## What only changes the ground: there is no node to move, the ground is made again.
const GROUND_KINDS := ["pad", "dune", "ridge", "pond", "river"]
## What can work something else.
const TRIGGERS := ["plate", "thing"]

var level: Desert
var layout: Dictionary
var cam: Camera3D
## The item that is chosen, or empty.
var chosen := {}

var _focus := Vector3.ZERO
var _yaw := 0.0
var _pitch := 0.95
var _reach := 70.0
var _eye: Node3D
# What the next touch on the ground does: "" (choose), "place", "move", "point", "link".
var _next := ""
var _armed: Array = []
var _touches := {}
var _started := {}
var _travel := 0.0
var _began := 0
var _dragging := ""
var _drag_point := -1
var _undo: Array[String] = []
var _redo: Array[String] = []
var _shape_in := -1.0
var _save_in := -1.0
var _page := ""
var _radii := {}

var _overlay: Control
var _ui: Control
var _shelf: PanelContainer
# How far the arrows move a thing, metres; and where it was taken hold of, from its own middle.
var _nudge := 1.0
var _held_at := Vector2.ZERO
var _status: Label
var _strip: HBoxContainer
var _inspector: VBoxContainer
var _side: PanelContainer
var _share: PanelContainer
var _share_text: TextEdit
var _tilt: VSlider
var _hint := ""
var _hint_until := 0.0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	add_to_group(&"level_editor")
	visible = false
	level = get_tree().get_first_node_in_group(&"editable_level") as Desert
	_build_ui()


## Opens it: the game stops, and the view goes up over where he is.
func open() -> void:
	if level == null or visible:
		return
	layout = level.layout
	visible = true
	get_tree().paused = true
	for other: Node in get_parent().get_children():
		if other != self and other is Control:
			(other as Control).visible = false
	cam = Camera3D.new()
	cam.process_mode = Node.PROCESS_MODE_ALWAYS
	cam.far = 4000.0
	cam.fov = 50.0
	level.add_child(cam)
	cam.make_current()
	_eye = Node3D.new()
	level.add_child(_eye)
	var sky := level.get_node_or_null(^"Sky") as WorldEnvironment
	if sky and sky.environment:
		sky.environment.fog_enabled = false
	if level.wind:
		level.wind.visible = false
	var player := level.get_parent().get_node_or_null(^"Player") as Node3D
	if player:
		_focus = player.global_position
	_yaw = 0.0
	_follow_ground()
	_keep_clear()
	_show_page("Level")
	_show_inspector()
	_say("One finger moves the ground, two zoom and turn. Touch a thing to choose it.  ( ? for more )", 7.0)


# Keeps everything clear of the edges a phone cannot show or be touched at.
func _keep_clear() -> void:
	var window := Vector2(DisplayServer.window_get_size())
	var safe := DisplayServer.get_display_safe_area()
	var edges := [0.0, 0.0, 0.0, 0.0]
	# (what the system says is safe means something only where the game fills the
	# screen, as it does on a phone: in a window on a desk it is the desk's)
	var fills := (window - Vector2(DisplayServer.screen_get_size())).abs().length() < 8.0
	if fills and OS.has_feature("mobile") and safe.size.x > 0 and safe.size.y > 0:
		var scale := size.x / window.x
		edges = [safe.position.x * scale, safe.position.y * scale, (window.x - safe.end.x) * scale, (window.y - safe.end.y) * scale]
	elif OS.has_feature("web") and DisplayServer.is_touchscreen_available():
		# (a browser does not say: a phone held sideways is allowed a margin at each end)
		edges = [30.0, 0.0, 30.0, 6.0]
	_ui.offset_left = clampf(edges[0], 0.0, 90.0)
	_ui.offset_top = clampf(edges[1], 0.0, 60.0)
	_ui.offset_right = -clampf(edges[2], 0.0, 90.0)
	_ui.offset_bottom = -clampf(edges[3], 0.0, 60.0)


# Shows the panel at the right, or puts it away; what is along the bottom takes the room.
func _show_side(shown: bool) -> void:
	_side.visible = shown
	_shelf.offset_right = -PANEL - 16.0 if shown else -8.0


func _build_ui() -> void:
	_overlay = Control.new()
	_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_overlay.draw.connect(_draw_overlay)
	add_child(_overlay)

	# Everything else stands inside the part of the screen that is safe to use:
	# clear of a phone's rounded corners and whatever is cut out of its edge.
	_ui = Control.new()
	_ui.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_ui.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_ui)
	get_viewport().size_changed.connect(_keep_clear)

	# Along the top: what is done to the whole level.
	var top := HBoxContainer.new()
	top.position = Vector2(8.0, 8.0)
	top.add_theme_constant_override("separation", 7)
	_ui.add_child(top)
	top.add_child(_button("Play", _play.bind(false)))
	top.add_child(_button("Play here", _play.bind(true)))
	top.add_child(_button("Undo", _step_back))
	top.add_child(_button("Redo", _step_on))
	top.add_child(_button("Save", _save_now))
	top.add_child(_button("More", _show_share.bind(true)))
	top.add_child(_button("Panel", func() -> void: _show_side(not _side.visible)))
	top.add_child(_button(" ? ", func() -> void: _say("One finger drags the ground. Two fingers: pinch to come nearer, turn to turn, slide up or down together to tip the view.\nTouch a thing to choose it; drag it by its ring, or use Move to and the arrows.\nA page on the left, then a thing along the bottom, then touch the ground to put it there.", 14.0)))
	_status = Label.new()
	_status.add_theme_font_size_override("font_size", 19)
	_status.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.85))
	_status.add_theme_constant_override("outline_size", 7)
	_status.position = Vector2(140.0, 70.0)
	_status.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_ui.add_child(_status)

	# Down the left: the pages (they scroll, when there are more than fit), and
	# beside them what moves the view for one hand: nearer, further, and tipped.
	var page_scroll := ScrollContainer.new()
	page_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	page_scroll.anchor_bottom = 1.0
	page_scroll.offset_left = 8.0
	page_scroll.offset_right = 128.0
	page_scroll.offset_top = 70.0
	page_scroll.offset_bottom = -92.0
	_ui.add_child(page_scroll)
	var pages := VBoxContainer.new()
	pages.add_theme_constant_override("separation", 6)
	page_scroll.add_child(pages)
	for page: String in ["Level"] + LevelLayout.PALETTE.keys():
		var button := _button(page, _show_page.bind(page))
		button.custom_minimum_size = Vector2(108.0, 52.0)
		pages.add_child(button)
	var nearer := _button("+", func() -> void: _reach = maxf(_reach * 0.75, 6.0))
	nearer.position = Vector2(138.0, 108.0)
	nearer.custom_minimum_size = Vector2(54.0, 54.0)
	_ui.add_child(nearer)
	var further := _button("-", func() -> void: _reach = minf(_reach * 1.33, 900.0))
	further.position = Vector2(138.0, 168.0)
	further.custom_minimum_size = Vector2(54.0, 54.0)
	_ui.add_child(further)
	_tilt = VSlider.new()
	_tilt.min_value = 0.25
	_tilt.max_value = 1.5
	_tilt.step = 0.01
	_tilt.value = _pitch
	_tilt.position = Vector2(140.0, 236.0)
	_tilt.custom_minimum_size = Vector2(50.0, 200.0)
	_tilt.size = Vector2(50.0, 200.0)
	_tilt.focus_mode = Control.FOCUS_NONE
	_tilt.value_changed.connect(func(value: float) -> void: _pitch = value)
	_ui.add_child(_tilt)
	var tip := _caption("Tip")
	tip.autowrap_mode = TextServer.AUTOWRAP_OFF
	tip.position = Vector2(150.0, 438.0)
	tip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_ui.add_child(tip)

	# Along the bottom: what the page offers.
	_shelf = PanelContainer.new()
	_shelf.anchor_top = 1.0
	_shelf.anchor_bottom = 1.0
	_shelf.anchor_right = 1.0
	_shelf.offset_left = 8.0
	_shelf.offset_right = -PANEL - 16.0
	_shelf.offset_top = -84.0
	_shelf.offset_bottom = -8.0
	_ui.add_child(_shelf)
	var scroll := ScrollContainer.new()
	scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_shelf.add_child(scroll)
	_strip = HBoxContainer.new()
	_strip.add_theme_constant_override("separation", 7)
	scroll.add_child(_strip)

	# At the right: the thing that is chosen. ("Panel" puts it away, to see more of the level.)
	_side = PanelContainer.new()
	_side.anchor_left = 1.0
	_side.anchor_right = 1.0
	_side.anchor_bottom = 1.0
	_side.offset_left = -PANEL - 8.0
	_side.offset_right = -8.0
	_side.offset_top = 8.0
	_side.offset_bottom = -8.0
	_ui.add_child(_side)
	var side_scroll := ScrollContainer.new()
	side_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_side.add_child(side_scroll)
	_inspector = VBoxContainer.new()
	_inspector.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_inspector.add_theme_constant_override("separation", 6)
	side_scroll.add_child(_inspector)

	# Over everything, when asked for: the level as text, and the way back.
	_share = PanelContainer.new()
	_share.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_share.offset_left = 120.0
	_share.offset_right = -120.0
	_share.offset_top = 40.0
	_share.offset_bottom = -40.0
	_share.visible = false
	add_child(_share)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 6)
	_share.add_child(column)
	column.add_child(_heading("The level as text"))
	var words := Label.new()
	words.text = "Changes are saved on this device as you make them. To keep a level anywhere else, or to send it to be built into the game, copy this text. To bring one in, paste it here and press Use this text."
	words.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	words.add_theme_font_size_override("font_size", 15)
	column.add_child(words)
	_share_text = TextEdit.new()
	_share_text.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_share_text.add_theme_font_size_override("font_size", 12)
	column.add_child(_share_text)
	var row := HFlowContainer.new()
	row.add_theme_constant_override("h_separation", 6)
	column.add_child(row)
	row.add_child(_button("Copy", func() -> void:
		DisplayServer.clipboard_set(_share_text.text)
		_say("Copied.")))
	row.add_child(_button("Paste", func() -> void: _share_text.text = DisplayServer.clipboard_get()))
	row.add_child(_button("Use this text", _use_text))
	row.add_child(_button("Back to the original level", _back_to_original))
	row.add_child(_button("Close", _show_share.bind(false)))


# --- Looking about, and touching things ---

func _process(delta: float) -> void:
	if not visible or cam == null:
		return
	var away := Vector3(sin(_yaw) * cos(_pitch), sin(_pitch), cos(_yaw) * cos(_pitch))
	cam.global_position = _focus + away * _reach
	cam.look_at(_focus)
	_eye.global_position = _focus
	# The ground draws itself finely round whatever it is told to follow.
	var ground := level.terrain.ground
	if ground and ground.get(&"focus") != _eye:
		ground.set(&"focus", _eye)
		ground.process_mode = Node.PROCESS_MODE_ALWAYS
	if _shape_in >= 0.0:
		_shape_in -= delta
		if _shape_in < 0.0:
			level.reshape()
			_radii.clear()
			_follow_ground()
			_say("The ground is made again.")
	if _save_in >= 0.0:
		_save_in -= delta
		if _save_in < 0.0:
			_save_now(true)
	_status.text = _status_line()
	_overlay.queue_redraw()


func _status_line() -> String:
	if Time.get_ticks_msec() * 0.001 < _hint_until:
		return _hint
	match _next:
		"place":
			return "Touch the ground to put %s there." % String(_armed[0]).to_lower()
		"move":
			return "Touch where it should go."
		"point":
			return "Touch where the river goes next."
		"link":
			return "Touch the plates and targets that work it. Touch Done when finished."
	if _shape_in >= 0.0:
		return "Making the ground..."
	return ""


func _say(text: String, seconds := 2.5) -> void:
	_hint = text
	_hint_until = Time.get_ticks_msec() * 0.001 + seconds


func _gui_input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		var touch := event as InputEventScreenTouch
		if touch.pressed:
			_touches[touch.index] = touch.position
			_started[touch.index] = touch.position
			if _touches.size() == 1:
				_travel = 0.0
				_began = Time.get_ticks_msec()
				_dragging = _grab(touch.position)
				if _dragging != "":
					_remember()
			else:
				_dragging = ""
				_travel = 1000.0
		else:
			var was_tap := _touches.size() == 1 and _travel < 14.0 and Time.get_ticks_msec() - _began < 450
			_touches.erase(touch.index)
			if _dragging != "":
				_dragging = ""
				_changed(chosen, "at")
			elif was_tap:
				_tapped(touch.position)
		accept_event()
	elif event is InputEventScreenDrag:
		var drag := event as InputEventScreenDrag
		if not _touches.has(drag.index):
			return
		var before: Vector2 = _touches[drag.index]
		_touches[drag.index] = drag.position
		if _touches.size() == 1:
			_travel += drag.relative.length()
			if _dragging != "":
				_drag_to(drag.position)
			elif _travel >= 14.0:
				_pan(before, drag.position)
		elif _touches.size() == 2:
			var other: Vector2 = _touches[_touches.keys()[0] if _touches.keys()[1] == drag.index else _touches.keys()[1]]
			var was := before - other
			var now := drag.position - other
			if was.length() > 10.0 and now.length() > 10.0:
				_reach = clampf(_reach * was.length() / now.length(), 6.0, 900.0)
				_yaw -= was.angle_to(now)
			# (both fingers slid up or down together tip the view)
			_pitch = clampf(_pitch + drag.relative.y * 0.5 * 0.006, 0.25, 1.5)
			_tilt.set_value_no_signal(_pitch)
		accept_event()
	elif event is InputEventMouseButton:
		var button := event as InputEventMouseButton
		if button.pressed and button.button_index == MOUSE_BUTTON_WHEEL_UP:
			_reach = maxf(_reach * 0.9, 6.0)
		elif button.pressed and button.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			_reach = minf(_reach * 1.1, 900.0)
	elif event is InputEventMouseMotion and (event as InputEventMouseMotion).button_mask & MOUSE_BUTTON_MASK_RIGHT:
		var motion := event as InputEventMouseMotion
		_yaw -= motion.relative.x * 0.006
		_pitch = clampf(_pitch + motion.relative.y * 0.006, 0.25, 1.5)
		_tilt.set_value_no_signal(_pitch)


# Moves the view so that the ground stays under the finger.
func _pan(from: Vector2, to: Vector2) -> void:
	var was := _on_plane(from)
	var now := _on_plane(to)
	if was == Vector3.INF or now == Vector3.INF:
		return
	_focus += was - now
	var edge: float = level.terrain.size * 0.5
	_focus.x = clampf(_focus.x, -edge, edge)
	_focus.z = clampf(_focus.z, -edge, edge)
	_follow_ground()


func _follow_ground() -> void:
	_focus.y = level.height_at(_focus.x, _focus.z)


# Where a touch meets the level plane through what is being looked at.
func _on_plane(screen: Vector2) -> Vector3:
	var from := cam.project_ray_origin(screen)
	var way := cam.project_ray_normal(screen)
	if way.y > -0.02:
		return Vector3.INF
	return from + way * ((_focus.y - from.y) / way.y)


## Where a touch meets the ground itself.
func ground_under(screen: Vector2) -> Vector3:
	var from := cam.project_ray_origin(screen)
	var way := cam.project_ray_normal(screen)
	var step := maxf(_reach * 0.02, 0.4)
	var along := 0.0
	while along < 3000.0:
		along += step
		var at := from + way * along
		if at.y <= level.height_at(at.x, at.z):
			var near := along - step
			var far := along
			for i in 10:
				var middle := (near + far) * 0.5
				var there := from + way * middle
				if there.y <= level.height_at(there.x, there.z):
					far = middle
				else:
					near = middle
			return from + way * far
	return _on_plane(screen)


# What a finger coming down takes hold of: "item" (the mark of what is chosen),
# "point" (one of a river's points), or nothing.
func _grab(screen: Vector2) -> String:
	if chosen.is_empty() or _next != "":
		return ""
	if chosen["kind"] == "river":
		var points: Array = chosen["points"]
		for i in points.size():
			var at := Vector3(points[i][0], level.height_at(points[i][0], points[i][1]), points[i][1])
			if not cam.is_position_behind(at) and cam.unproject_position(at).distance_to(screen) < TOUCH:
				_drag_point = i
				_held_at = Vector2.ZERO
				return "point"
		return ""
	var mark := level.place_of(chosen)
	if not cam.is_position_behind(mark) and cam.unproject_position(mark).distance_to(screen) < TOUCH:
		# (it is moved by as much as the finger moves: it does not jump to be under it, where it could not be seen)
		var under := ground_under(screen)
		_held_at = Vector2(under.x - mark.x, under.z - mark.z) if under != Vector3.INF else Vector2.ZERO
		return "item"
	return ""


func _drag_to(screen: Vector2) -> void:
	var at := ground_under(screen)
	if at == Vector3.INF:
		return
	if _dragging == "point":
		chosen["points"][_drag_point] = [snappedf(at.x, 0.01), snappedf(at.z, 0.01)]
		chosen["at"] = chosen["points"][0]
	else:
		chosen["at"] = [snappedf(at.x - _held_at.x, 0.01), snappedf(at.z - _held_at.y, 0.01)]
		if not chosen["kind"] in GROUND_KINDS:
			level.put(chosen)


func _tapped(screen: Vector2) -> void:
	var at := ground_under(screen)
	match _next:
		"place":
			if at == Vector3.INF:
				return
			_remember()
			var item := LevelLayout.new_item(layout, _armed[1], _armed[2], Vector2(at.x, at.z))
			if item.has("y"):
				item["y"] = snappedf(at.y + (-0.3 if item["kind"] == "pool" else 0.0), 0.01)
			layout["items"].append(item)
			level.make(item)
			_next = ""
			_choose(item)
			_changed(item, "at")
		"move":
			if at == Vector3.INF or chosen.is_empty():
				return
			_remember()
			var by := Vector2(at.x, at.z) - Vector2(chosen["at"][0], chosen["at"][1])
			if chosen["kind"] == "river":
				for point: Array in chosen["points"]:
					point[0] = snappedf(point[0] + by.x, 0.01)
					point[1] = snappedf(point[1] + by.y, 0.01)
				chosen["at"] = chosen["points"][0]
			else:
				chosen["at"] = [snappedf(at.x, 0.01), snappedf(at.z, 0.01)]
			_next = ""
			_changed(chosen, "at")
		"point":
			if at == Vector3.INF or chosen.is_empty():
				return
			_remember()
			chosen["points"].append([snappedf(at.x, 0.01), snappedf(at.z, 0.01)])
			_changed(chosen, "points")
		"link":
			var trigger := _pick(screen, at, true)
			if trigger.is_empty() or chosen.is_empty():
				return
			_remember()
			var links: Array = chosen.get("links", [])
			if links.has(trigger["id"]):
				links.erase(trigger["id"])
			else:
				links.append(trigger["id"])
			chosen["links"] = links
			_changed(chosen, "links")
			_show_inspector()
		_:
			_choose(_pick(screen, at, false))


# The item under a touch: the one whose mark is nearest it, or failing that
# the smallest thing standing where it meets the ground.
func _pick(screen: Vector2, ground: Vector3, triggers_only: bool) -> Dictionary:
	var best := {}
	var nearest := TOUCH
	for item: Dictionary in layout["items"]:
		if triggers_only and not _is_trigger(item):
			continue
		var mark := level.place_of(item)
		if cam.is_position_behind(mark):
			continue
		var off := cam.unproject_position(mark).distance_to(screen)
		if off < nearest:
			nearest = off
			best = item
	if not best.is_empty() or ground == Vector3.INF:
		return best
	var smallest := 1.0e9
	var spot := Vector2(ground.x, ground.z)
	for item: Dictionary in layout["items"]:
		if triggers_only and not _is_trigger(item):
			continue
		var room := _radius(item)
		var off := spot.distance_to(Vector2(item["at"][0], item["at"][1]))
		if item["kind"] == "river":
			var points: Array = item["points"]
			for i in points.size() - 1:
				off = minf(off, spot.distance_to(Geometry2D.get_closest_point_to_segment(spot, Vector2(points[i][0], points[i][1]), Vector2(points[i + 1][0], points[i + 1][1]))))
		if off < room and room < smallest:
			smallest = room
			best = item
	return best


func _is_trigger(item: Dictionary) -> bool:
	# (oil: a spill that has burnt through, a fire dish that oil burns in, a jar that has been broken)
	if item["kind"] in ["oil_spill", "oil_mark", "oil_jar"]:
		return true
	if item["kind"] == "plate":
		return true
	return item["kind"] == "thing" and (String(item.get("what", "")).begins_with("target") or item.get("what", "") in ["bottle"])


# How far a thing reaches over the ground, roughly.
func _radius(item: Dictionary) -> float:
	match item["kind"]:
		"pad":
			return maxf(item.get("half_x", 8.0), item.get("half_z", 8.0))
		"pond":
			return item.get("radius", 8.0)
		"river":
			return float(item.get("width", 9.0)) * 0.5
		"dune":
			return float(item.get("width", 46.0)) * 0.35
		"ridge":
			return 8.0
		"pool":
			return maxf(item.get("size_x", 6.0), item.get("size_z", 6.0)) * 0.5
	var id: int = item["id"]
	if not _radii.has(id):
		var reach := 1.2
		var node: Node3D = level.nodes.get(id)
		if node:
			for part: Node in node.find_children("*", "VisualInstance3D", true, false):
				var box: AABB = (part as VisualInstance3D).global_transform * (part as VisualInstance3D).get_aabb()
				reach = maxf(reach, maxf(box.size.x, box.size.z) * 0.5)
		_radii[id] = reach
	return _radii[id]


func _choose(item: Dictionary) -> void:
	chosen = item
	_next = ""
	if not item.is_empty():
		_show_side(true)
	_show_inspector()


# --- Changing things ---

# Notes the level as it is, to come back to.
func _remember() -> void:
	_undo.append(LevelLayout.to_text(layout))
	if _undo.size() > 40:
		_undo.pop_front()
	_redo.clear()


# What has to follow a change to one thing of an item.
func _changed(item: Dictionary, key: String) -> void:
	if item.is_empty():
		return
	if item["kind"] in GROUND_KINDS or key == "terrain":
		_shape_in = 0.6
	elif key in ["at", "lift", "yaw", "tilt_x", "tilt_z", "scale"] or (item["kind"] == "pool" and key == "y"):
		level.put(item)
	else:
		level.make(item)
		_radii.erase(item["id"])
	_save_in = 1.2


func _step_back() -> void:
	if _undo.is_empty():
		_say("Nothing to undo.")
		return
	_redo.append(LevelLayout.to_text(layout))
	_restore(_undo.pop_back())


func _step_on() -> void:
	if _redo.is_empty():
		_say("Nothing to redo.")
		return
	_undo.append(LevelLayout.to_text(layout))
	_restore(_redo.pop_back())


# Makes the whole level again from a layout as text.
func _restore(text: String) -> void:
	var was: int = chosen.get("id", -1)
	layout = LevelLayout.from_text(text)
	level.layout = layout
	for id: int in level.nodes.keys():
		level.forget(id)
	level.terrain.shape_from(layout)
	level.terrain.rebuild()
	for item: Dictionary in layout["items"]:
		level.make(item)
	chosen = {}
	for item: Dictionary in layout["items"]:
		if item["id"] == was:
			chosen = item
	_radii.clear()
	_next = ""
	_follow_ground()
	_show_inspector()
	_save_in = 1.0


func _save_now(quietly := false) -> void:
	_save_in = -1.0
	if LevelLayout.save(layout):
		if not quietly:
			_say("Saved on this device.")
	else:
		_say("It could not be saved here. Use More to copy it as text.", 6.0)


func _play(here: bool) -> void:
	_save_now(true)
	Desert.play_from = _focus if here else Vector3.INF
	get_tree().paused = false
	get_tree().reload_current_scene()


func _show_share(open: bool) -> void:
	_share.visible = open
	if open:
		_share_text.text = LevelLayout.to_text(layout)


func _use_text() -> void:
	var brought := LevelLayout.from_text(_share_text.text)
	if brought.is_empty():
		_say("That text is not a level.", 4.0)
		return
	_remember()
	_restore(LevelLayout.to_text(brought))
	_show_share(false)
	_say("The level is as that text says.")


func _back_to_original() -> void:
	_remember()
	LevelLayout.forget_saved()
	_restore(LevelLayout.to_text(LevelLayout.built_in()))
	_save_in = -1.0
	_show_share(false)
	_say("The level is as the game came with it. Undo brings yours back.", 5.0)


func _remove() -> void:
	if chosen.is_empty():
		return
	_remember()
	var gone := chosen
	layout["items"].erase(gone)
	level.forget(gone["id"])
	# (and nothing is left worked by it)
	for item: Dictionary in layout["items"]:
		if item.has("links"):
			(item["links"] as Array).erase(gone["id"])
	chosen = {}
	_say("Taken away. Undo brings it back.")
	if gone["kind"] in GROUND_KINDS:
		_shape_in = 0.6
	_save_in = 1.2
	_show_inspector()


# Moves what is chosen one step across the screen (x) or up it (y, negative: away).
func _nudge_by(way: Vector2) -> void:
	if chosen.is_empty():
		return
	_remember()
	var by := (Vector2(cos(_yaw), -sin(_yaw)) * way.x + Vector2(sin(_yaw), cos(_yaw)) * way.y) * _nudge
	if chosen["kind"] == "river":
		for point: Array in chosen["points"]:
			point[0] = snappedf(point[0] + by.x, 0.01)
			point[1] = snappedf(point[1] + by.y, 0.01)
		chosen["at"] = chosen["points"][0]
	else:
		chosen["at"] = [snappedf(chosen["at"][0] + by.x, 0.01), snappedf(chosen["at"][1] + by.y, 0.01)]
	_changed(chosen, "at")


func _copy() -> void:
	if chosen.is_empty():
		return
	_remember()
	var twin: Dictionary = chosen.duplicate(true)
	twin["id"] = LevelLayout.next_id(layout)
	var shift := maxf(_radius(chosen) * 0.6, 1.5)
	twin["at"] = [chosen["at"][0] + shift, chosen["at"][1] + shift]
	if twin.has("points"):
		for point: Array in twin["points"]:
			point[0] += shift
			point[1] += shift
	layout["items"].append(twin)
	level.make(twin)
	_choose(twin)
	_changed(twin, "at")


# --- The pages ---

func _show_page(page: String) -> void:
	_page = page
	for old in _strip.get_children():
		_strip.remove_child(old)
		old.queue_free()
	if page == "Level":
		chosen = {}
		_next = ""
		_show_inspector()
		var note := Label.new()
		note.text = "The desert itself: its size, dunes, wind and weather are at the right."
		note.add_theme_font_size_override("font_size", 18)
		_strip.add_child(note)
		return
	for entry: Array in LevelLayout.PALETTE[page]:
		var button := _button(entry[0], _arm.bind(entry))
		button.custom_minimum_size = Vector2(0.0, 58.0)
		_strip.add_child(button)


func _arm(entry: Array) -> void:
	_armed = entry
	_next = "place"


func _show_inspector() -> void:
	for old in _inspector.get_children():
		_inspector.remove_child(old)
		old.queue_free()
	if chosen.is_empty():
		_show_level()
		return
	var item := chosen
	_inspector.add_child(_heading("%s  (%d)" % [LevelLayout.label(item), item["id"]]))
	var row := HFlowContainer.new()
	row.add_theme_constant_override("h_separation", 5)
	row.add_theme_constant_override("v_separation", 5)
	_inspector.add_child(row)
	row.add_child(_button("Move to...", func() -> void: _next = "move"))
	row.add_child(_button("Copy", _copy))
	row.add_child(_button("Remove", _remove))
	row.add_child(_button("Look at", func() -> void:
		_focus = level.place_of(item)
		_reach = clampf(_radius(item) * 3.5, 10.0, 220.0)))
	# Arrows, to move it a step at a time (a finger hides what it drags): away
	# from the eye, towards it, and to either side, as the view is turned.
	var arrows := HBoxContainer.new()
	arrows.add_theme_constant_override("separation", 5)
	_inspector.add_child(arrows)
	for way: Array in [["<", Vector2(-1, 0)], ["^", Vector2(0, -1)], ["v", Vector2(0, 1)], [">", Vector2(1, 0)]]:
		var arrow := _button(way[0], _nudge_by.bind(way[1]))
		arrow.custom_minimum_size.x = 54.0
		arrows.add_child(arrow)
	var step := _button("%s m" % String.num(_nudge, 1), Callable())
	step.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	step.pressed.connect(func() -> void:
		var steps: Array[float] = [0.1, 0.5, 1.0, 5.0]
		_nudge = steps[(steps.find(_nudge) + 1) % steps.size()]
		step.text = "%s m" % String.num(_nudge, 1))
	arrows.add_child(step)
	if not item["kind"] in ["dune", "pond", "river", "pool", "start", "checkpoint", "sign"]:
		_number("Turned", item, "yaw", -180.0, 180.0, 1.0)
	if not item.has("y") and not item["kind"] in GROUND_KINDS:
		_number("Above the ground", item, "lift", -8.0, 30.0, 0.05)
	if item["kind"] == "river":
		var points := HFlowContainer.new()
		points.add_theme_constant_override("h_separation", 5)
		_inspector.add_child(points)
		points.add_child(_button("Add points...", func() -> void: _next = "point"))
		points.add_child(_button("Done", func() -> void: _next = ""))
		points.add_child(_button("Take the last away", func() -> void:
			if (item["points"] as Array).size() > 2:
				_remember()
				(item["points"] as Array).pop_back()
				_changed(item, "points")))
	for field: Array in LevelLayout.fields(item):
		match field[2]:
			"n":
				_number(field[1], item, field[0], field[3], field[4], field[5])
			"b":
				var box := CheckButton.new()
				box.text = field[1]
				box.focus_mode = Control.FOCUS_NONE
				box.custom_minimum_size.y = 50.0
				box.button_pressed = item.get(field[0], field[3])
				box.toggled.connect(func(on: bool) -> void:
					_remember()
					item[field[0]] = on
					_changed(item, field[0]))
				_inspector.add_child(box)
			"c":
				_inspector.add_child(_caption(field[1]))
				var choice := OptionButton.new()
				choice.focus_mode = Control.FOCUS_NONE
				choice.custom_minimum_size.y = 50.0
				for option: String in field[3]:
					choice.add_item(option)
				choice.selected = int(item.get(field[0], field[4]))
				choice.item_selected.connect(func(index: int) -> void:
					_remember()
					item[field[0]] = index
					_changed(item, field[0]))
				_inspector.add_child(choice)
			"t":
				_inspector.add_child(_caption(field[1]))
				var line := LineEdit.new()
				line.text = item.get(field[0], field[3])
				line.custom_minimum_size.y = 50.0
				line.text_submitted.connect(func(text: String) -> void:
					_remember()
					item[field[0]] = text
					_changed(item, field[0])
					line.release_focus())
				line.focus_exited.connect(func() -> void:
					if line.text != item.get(field[0], ""):
						_remember()
						item[field[0]] = line.text
						_changed(item, field[0]))
				_inspector.add_child(line)
			"links":
				var links: Array = item.get(field[0], [])
				_inspector.add_child(_caption("%s: %s" % [field[1], "nothing yet" if links.is_empty() else "%d thing%s (the lines)" % [links.size(), "" if links.size() == 1 else "s"]]))
				var link_row := HFlowContainer.new()
				link_row.add_theme_constant_override("h_separation", 5)
				_inspector.add_child(link_row)
				link_row.add_child(_button("Choose what works it...", func() -> void: _next = "link"))
				link_row.add_child(_button("Done", func() -> void: _next = ""))
	if _is_trigger(item):
		_inspector.add_child(_caption("To have this work a door, a bridge or anything else, choose that and use Choose what works it."))


# The desert itself.
func _show_level() -> void:
	_inspector.add_child(_heading("The desert"))
	if layout.is_empty():
		return
	var own: Dictionary = layout["terrain"]
	_number("How far across", own, "size", 160.0, 800.0, 20.0, "terrain")
	_number("Height of the dunes", own, "dune_height", 0.0, 18.0, 0.25, "terrain")
	_number("Dunes scattered about", own, "scatter", 0.0, 2.5, 0.05, "terrain")
	_number("Which scatter", own, "seed", 0.0, 99.0, 1.0, "terrain")
	_number("Height of the edge", own, "rim_height", 0.0, 30.0, 0.5, "terrain")
	var blows: Array = own.get("wind", [1.0, 0.0])
	var turn := {"deg": snappedf(rad_to_deg(atan2(blows[1], blows[0])), 1.0)}
	_number("The wind blows towards", turn, "deg", -180.0, 180.0, 5.0, "wind")
	_inspector.add_child(_caption("Weather"))
	var weather := OptionButton.new()
	weather.focus_mode = Control.FOCUS_NONE
	weather.custom_minimum_size.y = 50.0
	for kind: String in ["Calm", "A breeze", "A storm"]:
		weather.add_item(kind)
	weather.selected = int(layout.get("weather", 1))
	weather.item_selected.connect(func(index: int) -> void:
		_remember()
		layout["weather"] = index
		_save_in = 1.2)
	_inspector.add_child(weather)
	_number("Heat mirage (0: none)", layout, "mirage", 0.0, 1.0, 0.05, "mirage")
	_inspector.add_child(_caption("%d things in the level. Touch one to change it; the pages at the left have more to put in." % (layout["items"] as Array).size()))


# A number to change: what it is and what it stands at, and under that a
# slider with a step down and a step up at its ends. `what` is "" for a thing
# of an item's own, "terrain" for the ground's, "wind" for the way it blows,
# "mirage" for the heat.
func _number(title: String, holder: Dictionary, key: String, least: float, most: float, step: float, what := "") -> void:
	var caption := _caption("")
	_inspector.add_child(caption)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 4)
	_inspector.add_child(row)
	var slider := HSlider.new()
	slider.min_value = least
	slider.max_value = most
	slider.step = step
	slider.allow_greater = true
	slider.allow_lesser = true
	slider.value = holder.get(key, 0.0)
	slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	slider.custom_minimum_size.y = 50.0
	slider.focus_mode = Control.FOCUS_NONE
	var show := func() -> void: caption.text = "%s: %s" % [title, String.num(slider.value, 0 if step >= 1.0 else 2)]
	show.call()
	var apply := func(value: float) -> void:
		holder[key] = value
		show.call()
		match what:
			"terrain":
				_shape_in = 0.6
				_save_in = 1.2
			"wind":
				layout["terrain"]["wind"] = [snappedf(cos(deg_to_rad(value)), 0.001), snappedf(sin(deg_to_rad(value)), 0.001)]
				_shape_in = 0.6
				_save_in = 1.2
			"mirage":
				level.heat(value)
				_save_in = 1.2
			_:
				_changed(holder, key)
	slider.drag_started.connect(_remember)
	slider.value_changed.connect(apply)
	var less := _button("-", func() -> void:
		_remember()
		slider.value -= step)
	less.custom_minimum_size.x = 54.0
	var more := _button("+", func() -> void:
		_remember()
		slider.value += step)
	more.custom_minimum_size.x = 54.0
	row.add_child(less)
	row.add_child(slider)
	row.add_child(more)


# --- What is drawn over the level ---

func _draw_overlay() -> void:
	if cam == null or layout.is_empty():
		return
	var over := _overlay
	for item: Dictionary in layout["items"]:
		var mark := level.place_of(item)
		if cam.is_position_behind(mark):
			continue
		var at := cam.unproject_position(mark)
		if at.x < -200.0 or at.y < -200.0 or at.x > size.x + 200.0 or at.y > size.y + 200.0:
			continue
		var is_chosen: bool = not chosen.is_empty() and item["id"] == chosen["id"]
		var colour: Color = DOT.get(item["kind"], Color(0.9, 0.9, 0.9))
		match item["kind"]:
			"pad":
				_outline(_pad_ring(item), colour, is_chosen)
			"pond":
				_outline(_circle(Vector2(item["at"][0], item["at"][1]), item.get("radius", 8.0)), colour, is_chosen)
			"dune":
				_outline(_circle(Vector2(item["at"][0], item["at"][1]), float(item.get("width", 46.0)) * 0.5, 16), colour, is_chosen)
			"ridge":
				var yaw := deg_to_rad(item.get("yaw", 0.0))
				var along := Vector2(sin(yaw), cos(yaw)) * float(item.get("length", 110.0)) * 0.5
				var middle := Vector2(item["at"][0], item["at"][1])
				_outline([_on_ground(middle - along), _on_ground(middle), _on_ground(middle + along)], colour, is_chosen, false)
			"river":
				var line: Array = []
				for point: Array in item["points"]:
					line.append(_on_ground(Vector2(point[0], point[1])))
				_outline(line, colour, is_chosen, false)
				if is_chosen:
					for point: Vector3 in line:
						if not cam.is_position_behind(point):
							over.draw_circle(cam.unproject_position(point), 15.0, Color(colour, 0.9))
							over.draw_arc(cam.unproject_position(point), 15.0, 0.0, TAU, 24, Color(1, 1, 1, 0.9), 2.0, true)
			"pool":
				var half := Vector2(item.get("size_x", 6.0), item.get("size_z", 6.0)) * 0.5
				var corner := Vector2(item["at"][0], item["at"][1])
				var ring: Array = []
				for way: Vector2 in [Vector2(-1, -1), Vector2(1, -1), Vector2(1, 1), Vector2(-1, 1)]:
					ring.append(Vector3(corner.x + way.x * half.x, item["y"], corner.y + way.y * half.y))
				_outline(ring, colour, is_chosen)
		if is_chosen:
			over.draw_arc(at, 28.0, 0.0, TAU, 40, Color(0, 0, 0, 0.55), 6.0, true)
			over.draw_arc(at, 28.0, 0.0, TAU, 40, Color(1, 1, 1, 0.95), 3.0, true)
			over.draw_circle(at, 9.0, colour)
			# What works it: a line to each.
			for link: int in item.get("links", []):
				for other: Dictionary in layout["items"]:
					if other["id"] == link:
						var to := level.place_of(other)
						if not cam.is_position_behind(to):
							over.draw_dashed_line(at, cam.unproject_position(to), Color(0.7, 1.0, 0.5, 0.95), 3.0, 10.0)
							over.draw_circle(cam.unproject_position(to), 9.0, Color(0.7, 1.0, 0.5, 0.95))
		else:
			var show_all := _next == "link" and _is_trigger(item)
			over.draw_circle(at, 13.0 if show_all else 6.5, Color(colour, 0.95 if show_all else 0.75))
			over.draw_arc(at, 13.0 if show_all else 6.5, 0.0, TAU, 16, Color(0, 0, 0, 0.6), 1.5, true)
	# The middle of the view, where "Play here" starts him.
	var centre := size * 0.5
	over.draw_line(centre + Vector2(-9, 0), centre + Vector2(9, 0), Color(1, 1, 1, 0.4), 1.5)
	over.draw_line(centre + Vector2(0, -9), centre + Vector2(0, 9), Color(1, 1, 1, 0.4), 1.5)


func _on_ground(at: Vector2) -> Vector3:
	return Vector3(at.x, level.height_at(at.x, at.y) + 0.1, at.y)


func _circle(middle: Vector2, radius: float, count := 28) -> Array:
	var ring: Array = []
	for i in count:
		ring.append(_on_ground(middle + Vector2.from_angle(TAU * i / count) * radius))
	return ring


func _pad_ring(item: Dictionary) -> Array:
	var ring: Array = []
	var middle := Vector2(item["at"][0], item["at"][1])
	var half := Vector2(item.get("half_x", 8.0), item.get("half_z", 8.0))
	var yaw := -deg_to_rad(item.get("yaw", 0.0))
	if item.get("round", false):
		for i in 28:
			var out := Vector2.from_angle(TAU * i / 28.0) * half
			ring.append(_on_ground(middle + out.rotated(yaw)))
	else:
		for way: Vector2 in [Vector2(-1, -1), Vector2(0, -1), Vector2(1, -1), Vector2(1, 0), Vector2(1, 1), Vector2(0, 1), Vector2(-1, 1), Vector2(-1, 0)]:
			ring.append(_on_ground(middle + (way * half).rotated(yaw)))
	return ring


func _outline(points: Array, colour: Color, bold: bool, closed := true) -> void:
	var line := PackedVector2Array()
	for point: Vector3 in points:
		if cam.is_position_behind(point):
			return
		line.append(cam.unproject_position(point))
	if closed and line.size() > 2:
		line.append(line[0])
	if line.size() > 1:
		_overlay.draw_polyline(line, Color(colour, 0.95 if bold else 0.45), 3.0 if bold else 1.5, true)


# --- Making its buttons ---

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
