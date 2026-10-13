class_name LevelEditorPad
extends Control
## The level editor worked with a gamepad, on a desk: everything the panels
## for a desk do with a finger or a mouse (`LevelEditor`, which makes one of
## these beside them and is told nothing more), done from the sticks and
## buttons. It listens only to a gamepad, and draws nothing until one is used.
##
## A cross stands in the middle of the view, and is where things happen:
##
##   left stick      moves the cross over the ground (the view goes with it)
##   right stick     turns the view, and tips it
##   triggers        left comes nearer, right goes further off
##   A               chooses the thing at the cross; with something to put in,
##                   puts it there; while joining, joins or unjoins the thing there.
##                   Held on a thing (or on a point of a river) while the cross
##                   is moved, it carries it along
##   B               not now: lets go of what was to be put in, ends joining,
##                   or unchooses
##   X               removes what is chosen
##   Y               the settings of what is chosen (or, with nothing chosen,
##                   of the desert): up and down the rows, left and right to
##                   change a number or a choice, A to work a button, B back
##   shoulders       the page before, the page after (Ground, Water, Stone...)
##   d-pad           left and right through what the page offers (the one it
##                   is on is what A puts in); up and down, the pages
##   left stick in   undo;   right stick in: redo
##   Start           all the editor's own buttons (Play, Save, More, Panel...),
##                   to go about with the d-pad and work with A; B back
##
## A name or an inscription is written with letters that come up for it (PadKeyboard).

const CROSS := Color(1.0, 0.84, 0.3)

var editor: LevelEditor
## The mark on the editor's buttons and sliders, while it has the gamepad (see PadFocus).
var mark: PadFocus
## Where the gamepad is at work: "ground" (the cross), "panel" (the settings at the right) or "bar" (every button).
var mode := "ground"
## Which of the things along the bottom the d-pad is on (-1: none yet).
var slot := -1

var _steps := Gamepad.Steps.new()
var _next_was := ""
# A is held on something: where the cross was when it was taken hold of.
var _carrying := false
var _carried_from := Vector3.ZERO
var _was_using := false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_steps.stick = false
	mark = PadFocus.new()
	mark.roots = [editor._ui, editor._share]
	mark.scope = _scope
	mark.left.connect(_back)
	# (the editor stops the game itself, and its buttons are worked all the same)
	mark.when_paused = true
	add_child(mark)


# What the mark is kept to: the level as text while that is up, the panel at the right for "panel", or nothing.
func _scope() -> Control:
	if editor._share.visible:
		return editor._share
	return editor._side if mode == "panel" else null


func _working() -> bool:
	return not Loading.busy and editor.visible and editor.cam != null and not mark.typing()


func _middle() -> Vector2:
	return editor.size * 0.5


func _go(to: String) -> void:
	mode = to
	mark.active = to != "ground"
	if mark.active:
		mark.put_on_first()


func _back() -> void:
	if editor._share.visible:
		editor._show_share(false)
	_go("ground")


func _process(delta: float) -> void:
	if not _working():
		return
	# The right stick and the triggers move the view wherever the gamepad is at work.
	var turn := Gamepad.right()
	turn *= turn.length()
	var pull := Gamepad.triggers()
	if turn != Vector2.ZERO or pull != 0.0:
		editor.look(-turn.x * 1.9 * delta, exp(pull * 1.3 * delta), turn.y * 1.1 * delta)
	# (something in the panel has asked for a place on the ground: back to the cross to give it one)
	if editor._next != _next_was:
		_next_was = editor._next
		if editor._next != "" and mode != "ground" and not editor._share.visible:
			_go("ground")
	if editor._share.visible and mode == "ground":
		_go("bar")
	if mode == "ground":
		_move_cross(delta)
		var way := _steps.take(delta)
		if way.x != 0.0:
			_step_slot(int(way.x))
		elif way.y != 0.0:
			_step_page(int(way.y))
	if Gamepad.using_pad() or _was_using:
		_was_using = Gamepad.using_pad()
		queue_redraw()


# The left stick moves the cross over the ground, faster from further off; and whatever A is held on goes with it.
func _move_cross(delta: float) -> void:
	var stick := Gamepad.left()
	if stick == Vector2.ZERO:
		return
	stick *= stick.length()
	var yaw := editor._yaw
	var by := (Vector2(cos(yaw), -sin(yaw)) * stick.x + Vector2(sin(yaw), cos(yaw)) * stick.y) * editor._reach * 0.85 * delta
	var edge: float = editor.level.terrain.size * 0.5
	editor._focus.x = clampf(editor._focus.x + by.x, -edge, edge)
	editor._focus.z = clampf(editor._focus.z + by.y, -edge, edge)
	editor._follow_ground()
	if _carrying and editor._dragging != "" and editor._focus.distance_to(_carried_from) > 0.05:
		# (as a finger drags it: the level is noted once, as it first moves)
		if not editor._dragged:
			editor._dragged = true
			editor._remember()
		_set_view()
		editor._drag_to(_middle())


# Puts the editor's camera where it will be this frame, so that the cross can be asked what is under it now.
func _set_view() -> void:
	var away := Vector3(sin(editor._yaw) * cos(editor._pitch), sin(editor._pitch), cos(editor._yaw) * cos(editor._pitch))
	editor.cam.global_position = editor._focus + away * editor._reach
	editor.cam.look_at(editor._focus)


## The names of the pages, in their order down the left.
func pages() -> Array:
	return ["Level"] + LevelLayout.PALETTE.keys()


func _step_page(by: int) -> void:
	var all := pages()
	var to: String = all[posmod(all.find(editor._page) + by, all.size())]
	# (a page is turned to; what is chosen is left chosen, but for "Level", which is the desert's own)
	editor._next = ""
	editor._show_page(to)
	slot = -1
	editor._say(to + ".", 1.2)


# Moves along what the page offers: the one it comes to is what A puts in. (After one has been put in, the first
# push takes the same up again.)
func _step_slot(by: int) -> void:
	var offered: Array = LevelLayout.PALETTE.get(editor._page, [])
	if offered.is_empty():
		return
	if slot == -1:
		slot = 0 if by > 0 else offered.size() - 1
	elif editor._next == "place":
		slot = posmod(slot + by, offered.size())
	# (with nothing taken up, the first push takes up again the one it was on: to put in another of the same)
	slot = clampi(slot, 0, offered.size() - 1)
	editor._arm(offered[slot])
	var button := editor._strip.get_child(slot) as Control
	if button and button.get_parent().get_parent() is ScrollContainer:
		(button.get_parent().get_parent() as ScrollContainer).ensure_control_visible(button)


# The thing A would choose now: the one at the cross (while joining, only what can be joined).
func _under_cross() -> Dictionary:
	var only := Callable()
	if editor._next == "link":
		only = editor._is_trigger
	elif editor._next == "link_from":
		only = editor._is_worked
	elif editor._next != "":
		return {}
	return editor._pick(_middle(), editor.ground_under(_middle()), only)


func _input(event: InputEvent) -> void:
	if not _working() or not Gamepad.heard(event) or not event is InputEventJoypadButton:
		return
	if event.is_action_released(&"pad_a") and _carrying:
		_carrying = false
		editor._let_go()
		return
	if not event.pressed:
		return
	var handled := true
	if Gamepad.pressed(event, &"pad_start"):
		if mode == "bar" and not editor._share.visible:
			_go("ground")
		else:
			_go("bar")
	elif Gamepad.pressed(event, &"pad_y"):
		if mode == "panel":
			_go("ground")
		elif not editor._share.visible:
			editor._show_side(true)
			_go("panel")
	elif Gamepad.pressed(event, &"pad_l3"):
		editor._step_back()
	elif Gamepad.pressed(event, &"pad_r3"):
		editor._step_on()
	elif Gamepad.pressed(event, &"pad_lb") and not editor._share.visible:
		_go("ground")
		_step_page(-1)
	elif Gamepad.pressed(event, &"pad_rb") and not editor._share.visible:
		_go("ground")
		_step_page(1)
	elif mode != "ground":
		# (A and B are the mark's: see PadFocus)
		handled = false
	elif Gamepad.pressed(event, &"pad_a"):
		_press_a()
	elif Gamepad.pressed(event, &"pad_b"):
		if editor._next != "":
			editor._next = ""
			slot = -1
		elif not editor.chosen.is_empty():
			editor._choose({})
	elif Gamepad.pressed(event, &"pad_x"):
		if editor.chosen.is_empty():
			editor._say("Nothing is chosen. A on a thing chooses it.")
		else:
			editor._remove()
	else:
		handled = false
	if handled:
		get_viewport().set_input_as_handled()


# A, with the cross on the ground: what a touch there would do; and on a thing, it is taken hold of as well.
func _press_a() -> void:
	_set_view()
	if editor._next != "":
		editor._tapped(_middle())
		return
	var grabbed := editor._grab(_middle())
	if grabbed == "":
		var found := _under_cross()
		if found.is_empty() and editor.chosen.is_empty():
			editor._say("Nothing is at the cross.")
			return
		editor._choose(found)
		grabbed = editor._grab(_middle())
	if grabbed != "":
		editor._dragging = grabbed
		editor._dragged = false
		_carrying = true
		_carried_from = editor._focus


## What the line of words under the buttons says, for a gamepad: what the editor would say to a finger (`touch`), in the gamepad's words.
func says(touch: String) -> String:
	if not Gamepad.using_pad() or Time.get_ticks_msec() * 0.001 < editor._hint_until:
		return touch
	var a := Gamepad.said(&"pad_a")
	var b := Gamepad.said(&"pad_b")
	match editor._next:
		"place":
			return "Move the cross and press %s to put %s there.  %s: not now." % [a, String(editor._armed[0]).to_lower(), b]
		"move":
			return "Move the cross to where it should go and press %s.  %s: not now." % [a, b]
		"point":
			return "Move the cross to where it goes next and press %s.  %s when finished." % [a, b]
		"link", "link_from":
			return "Move the cross to each plate or target that works it and press %s.  %s when finished." % [a, b]
	return touch


func _draw() -> void:
	if not _working() or not Gamepad.using_pad():
		return
	var font := ThemeDB.fallback_font
	var centre := _middle()
	if mode == "ground":
		# The thing A would choose, ringed; and the cross, bold.
		var found := _under_cross()
		if not found.is_empty():
			var at := editor.level.place_of(found)
			if not editor.cam.is_position_behind(at):
				var on_screen := editor.cam.unproject_position(at)
				draw_arc(on_screen, 38.0, 0.0, TAU, 40, Color(0, 0, 0, 0.6), 7.0, true)
				draw_arc(on_screen, 38.0, 0.0, TAU, 40, CROSS, 3.5, true)
				var label := LevelLayout.label(found)
				draw_string_outline(font, on_screen + Vector2(46.0, 6.0), label, HORIZONTAL_ALIGNMENT_LEFT, -1.0, 18, 6, Color(0, 0, 0, 0.8))
				draw_string(font, on_screen + Vector2(46.0, 6.0), label, HORIZONTAL_ALIGNMENT_LEFT, -1.0, 18, CROSS)
		for way: Vector2 in [Vector2.LEFT, Vector2.RIGHT, Vector2.UP, Vector2.DOWN]:
			draw_line(centre + way * 9.0, centre + way * 34.0, Color(0, 0, 0, 0.7), 8.0)
			draw_line(centre + way * 10.0, centre + way * 33.0, CROSS, 4.0)
		draw_arc(centre, 20.0, 0.0, TAU, 32, Color(0, 0, 0, 0.7), 7.0, true)
		draw_arc(centre, 20.0, 0.0, TAU, 32, CROSS if not _carrying else Color.WHITE, 3.5, true)
		# The thing along the bottom that the d-pad is on.
		if slot != -1 and editor._next == "place" and slot < editor._strip.get_child_count():
			var rect: Rect2 = get_global_transform().affine_inverse() * (editor._strip.get_child(slot) as Control).get_global_rect()
			draw_rect(rect.grow(4.0), Color(0, 0, 0, 0.75), false, 7.0)
			draw_rect(rect.grow(4.0), CROSS, false, 3.5)
	# What the buttons do now, over the strip along the bottom.
	var told: Array = []
	if editor._share.visible:
		told = [[&"pad_dpad", "move"], [&"pad_a", "press"], [&"pad_b", "close"]]
	elif mode == "panel":
		told = [[&"pad_dpad", "rows; left and right change"], [&"pad_a", "press"], [&"pad_b", "back to the ground"]]
	elif mode == "bar":
		told = [[&"pad_dpad", "move"], [&"pad_a", "press"], [&"pad_b", "back to the ground"]]
	elif editor._next == "place":
		told = [[&"pad_ls", "the cross"], [&"pad_a", "put it here"], [&"pad_b", "not now"], [&"pad_dpad", "another"]]
	elif editor._next != "":
		told = [[&"pad_ls", "the cross"], [&"pad_a", "here"], [&"pad_b", "finished"]]
	elif editor.chosen.is_empty():
		told = [[&"pad_ls", "the cross"], [&"pad_a", "choose"], [&"pad_dpad", "what to put in"], [&"pad_lb", ""], [&"pad_rb", "pages"], [&"pad_y", "the desert"], [&"pad_start", "buttons"]]
	else:
		told = [[&"pad_a", "hold: carry it"], [&"pad_y", "its settings"], [&"pad_x", "remove"], [&"pad_b", "let it be"], [&"pad_l3", "undo"], [&"pad_r3", "redo"], [&"pad_start", "buttons"]]
	var room := size.x - 194.0 - (LevelEditor.PANEL + 24.0 if editor._side.visible else 16.0)
	Gamepad.draw_legend(self, told, Vector2(194.0, size.y - 92.0), room)
