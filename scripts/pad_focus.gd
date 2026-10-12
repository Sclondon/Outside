class_name PadFocus
extends Control
## A gamepad's mark on a screen made of buttons, sliders and lists (the cards
## of a tomb, the panels of the two editors): the d-pad or the left stick moves
## it from one to the next, whichever way is pushed; A works what it is on, as
## a touch would; left and right slide a slider and step through a list; A on
## a line of writing brings up letters to choose (PadKeyboard); B is for
## whoever owns it to make something of (`left`).
##
## None of those things need know of it, and none take Godot's own focus: this
## looks through what it is given (`roots`) each frame for whatever can be
## worked and can be seen, and draws its mark over the one it is on. What it
## is on may be made again under it at any time (the editors make a panel
## again whenever anything in it changes): it stays on whatever is in the same
## place in the list.
##
##     var mark := PadFocus.new()
##     mark.roots = [panel]
##     add_child(mark)            # last, so that it is drawn over the rest
##     mark.active = true
##
## `scope`, if it gives something back, is the only thing looked through (a
## card or a sheet that is over everything else). `extra` gives things that are
## not Controls at all but only drawn: [{"id", "rect" (on the screen), "act"}].
## It listens only to a gamepad: a mouse, a finger and the keys are as they were.

## B was pressed with nothing of its own to go back from.
signal left
## Something was worked (the Control, or the id of one of the `extra`).
signal worked(what: Variant)

const MARK := Color(1.0, 0.84, 0.3)

## Where it looks for things to work.
var roots: Array[Node] = []
## Asked each frame: a Control to look through and nothing else, or null.
var scope := Callable()
## Asked each frame: what else can be worked, that is only drawn.
var extra := Callable()
## Whether the gamepad is its to listen to. (Nothing is drawn, either, unless a gamepad was the last thing used.)
var active := false:
	set(value):
		active = value
		_steps = Gamepad.Steps.new()
		queue_redraw()
## Whether the left stick moves it as well as the d-pad (not where the stick is wanted for something else).
var stick := true
## A button that gives it the gamepad when it has not got it (and takes it away again, as B does): for the few
## buttons at the edge of a game that is being played. While it has it so, only the d-pad moves the mark: the
## stick is still the game's. `wake_at` is where that button's mark is drawn while it waits (x from the right
## edge of the screen if it is under 0).
var wake := &""
var wake_at := Vector2.INF
## Whether what the buttons do is written along the foot of the screen while it has the gamepad.
var legend := false
## What the mark is on: a Control, or the id of one of the `extra`; null for nothing.
var on_what: Variant = null

var _steps := Gamepad.Steps.new()
var _index := 0
var _scope_was: Control
var _list: Array = []
var _keyboard: PadKeyboard
var _since_slid := 10.0
var _awake := false
var _in_scope := false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	# (over whatever is put on the screen after it)
	z_index = 100
	Gamepad.ensure(get_tree())


## Whether letters are being chosen for a line of writing.
func typing() -> bool:
	return is_instance_valid(_keyboard)


## Everything that can be worked now, in the order it stands in the tree: Controls, then the `extra`.
func things() -> Array:
	var found: Array = []
	var only: Control = scope.call() if scope.is_valid() else null
	if only != null and is_instance_valid(only) and only.is_visible_in_tree():
		_gather(only, found)
	else:
		only = null
		for root in roots:
			if is_instance_valid(root) and (not root is CanvasItem or (root as CanvasItem).is_visible_in_tree()):
				_gather(root, found)
		if extra.is_valid():
			found.append_array(extra.call())
	_in_scope = only != null
	if only != _scope_was:
		# (something has come up over the rest, or gone: the mark starts at the top of what there is now)
		_scope_was = only
		on_what = null
		_index = 0
	return found


func _gather(from: Node, found: Array) -> void:
	for child in from.get_children():
		if child is PadFocus or child is PadKeyboard or (child is CanvasItem and not (child as CanvasItem).visible):
			continue
		if _works(child):
			found.append(child)
		# (what is inside a slider or a line of writing is its own business)
		elif not child is Range and not child is LineEdit and not child is TextEdit:
			_gather(child, found)


func _works(node: Node) -> bool:
	if node is BaseButton:
		return not (node as BaseButton).disabled
	if node is Slider:
		return (node as Slider).editable
	if node is LineEdit:
		return (node as LineEdit).editable
	return node.has_meta(&"pad_press")


## Puts the mark on something (a Control, or the id of one of the `extra`).
func put_on(what: Variant) -> void:
	on_what = what
	_show()


## Puts the mark on the first thing there is.
func put_on_first() -> void:
	on_what = null
	_index = 0


## Whether the gamepad is its own now: because it was given it (`active`), woken (`wake`), or something is up that
## is all there is to work (`scope`).
func has_pad() -> bool:
	return active or _awake or _in_scope


func _process(delta: float) -> void:
	_since_slid += delta
	if typing():
		return
	_list = things()
	queue_redraw()
	if not has_pad():
		return
	# Keep hold of what it is on; or, if that has gone, of whatever stands where it stood.
	var at := _find(on_what)
	if at == -1:
		if _list.is_empty():
			on_what = null
		else:
			_index = clampi(_index, 0, _list.size() - 1)
			on_what = _name_of(_list[_index])
	else:
		_index = at
	_steps.stick = stick and (active or _in_scope)
	var way := _steps.take(delta)
	if way != Vector2.ZERO:
		step(way)
	queue_redraw()


func _name_of(thing: Variant) -> Variant:
	return thing["id"] if thing is Dictionary else thing


func _find(what: Variant) -> int:
	if what == null or (what is Object and not is_instance_valid(what)):
		return -1
	for i in _list.size():
		if typeof(_name_of(_list[i])) == typeof(what) and _name_of(_list[i]) == what:
			return i
	return -1


## Where one of the things is on the screen.
func rect_of(thing: Variant) -> Rect2:
	if thing is Dictionary:
		return thing["rect"]
	return (thing as Control).get_global_rect()


## What the mark is on: a Control, one of the `extra` (a Dictionary), or null.
func now() -> Variant:
	var at := _find(on_what)
	return _list[at] if at != -1 else null


## A step of the d-pad: slides what the mark is on, if it slides that way; or else moves the mark.
func step(way: Vector2) -> void:
	var thing: Variant = now()
	if thing == null:
		return
	if thing is HSlider and way.x != 0.0:
		_slide(thing, way.x)
		return
	if thing is VSlider and way.y != 0.0:
		_slide(thing, -way.y)
		return
	if thing is OptionButton and way.x != 0.0:
		_pick(thing, int(way.x))
		return
	var here := rect_of(thing).get_center()
	var best: Variant = null
	var least := INF
	for other: Variant in _list:
		if _name_of(other) == _name_of(thing) and typeof(_name_of(other)) == typeof(_name_of(thing)):
			continue
		var rect := rect_of(other)
		if rect.size.x <= 0.0 or rect.size.y <= 0.0:
			continue
		# (from the nearest edge of it, so that something wide is not passed over for something small beyond it)
		var near := Vector2(clampf(here.x, rect.position.x, rect.end.x), clampf(here.y, rect.position.y, rect.end.y))
		var to := near.lerp(rect.get_center(), 0.25) - here
		var along := to.dot(way)
		var across := absf(to.dot(way.orthogonal()))
		if along < 4.0 or across > along * 2.5:
			continue
		var far := along + across * 2.2
		if far < least:
			least = far
			best = other
	if best != null:
		on_what = _name_of(best)
		_index = _find(on_what)
		_show()


# Brings what the mark is on into sight, where it is in something that scrolls.
func _show() -> void:
	if not (on_what is Control) or not is_instance_valid(on_what):
		return
	var above := (on_what as Control).get_parent()
	while above:
		if above is ScrollContainer:
			(above as ScrollContainer).ensure_control_visible.call_deferred(on_what)
		above = above.get_parent()


func _slide(slider: Slider, by: float) -> void:
	# (what notes the level before a slider is dragged is told a drag has begun: once, for a run of steps)
	if _since_slid > 0.8:
		slider.drag_started.emit()
	_since_slid = 0.0
	var step := slider.step if slider.step > 0.0 else (slider.max_value - slider.min_value) / 100.0
	slider.value = clampf(slider.value + step * by, slider.min_value, slider.max_value)


func _pick(list: OptionButton, by: int) -> void:
	if list.item_count == 0:
		return
	var to := posmod(list.selected + by, list.item_count)
	list.select(to)
	list.item_selected.emit(to)


## Works what the mark is on, as a touch on it would.
func work() -> void:
	var thing: Variant = now()
	if thing == null:
		return
	if thing is Dictionary:
		(thing["act"] as Callable).call()
		worked.emit(thing["id"])
		return
	if thing is OptionButton:
		_pick(thing, 1)
	elif thing is BaseButton:
		var button := thing as BaseButton
		button.button_down.emit()
		if button.toggle_mode:
			button.button_pressed = not button.button_pressed
		button.pressed.emit()
		if is_instance_valid(button):
			button.button_up.emit()
	elif thing is LineEdit:
		_type_in(thing)
	elif (thing as Node).has_meta(&"pad_press"):
		((thing as Node).get_meta(&"pad_press") as Callable).call()
	worked.emit(thing)


# Brings up the letters, for a line of writing.
func _type_in(line: LineEdit) -> void:
	_keyboard = PadKeyboard.new()
	_keyboard.text = line.text
	_keyboard.title = line.placeholder_text
	get_parent().add_child(_keyboard)
	_keyboard.done.connect(func(text: String, kept: bool) -> void:
		if kept and is_instance_valid(line):
			line.text = text
			line.text_changed.emit(text)
			line.text_submitted.emit(text))


func _input(event: InputEvent) -> void:
	if typing() or not Gamepad.heard(event):
		return
	if wake != &"" and Gamepad.pressed(event, wake) and not active and not _in_scope:
		_awake = not _awake
		get_viewport().set_input_as_handled()
	elif not has_pad():
		return
	elif Gamepad.pressed(event, &"pad_a"):
		work()
		get_viewport().set_input_as_handled()
	elif Gamepad.pressed(event, &"pad_b"):
		if _awake and not active and not _in_scope:
			_awake = false
		left.emit()
		get_viewport().set_input_as_handled()


func _draw() -> void:
	if typing() or not Gamepad.using_pad():
		return
	if not has_pad():
		# (waiting: the button that wakes it, where whoever owns it wants that shown)
		if wake != &"" and wake_at != Vector2.INF and not _list.is_empty():
			var wide := Gamepad.mark_width(wake, 14.0, ThemeDB.fallback_font)
			Gamepad.draw(self, wake, Vector2((size.x + wake_at.x if wake_at.x < 0.0 else wake_at.x) - wide * 0.5, wake_at.y), 14.0, Color(1, 1, 1, 0.9), Color(0, 0, 0, 0.4))
		return
	if legend:
		var told := [[&"pad_dpad", "move"], [&"pad_a", "choose"]]
		if _awake and not _in_scope:
			told.append([&"pad_b", "back to the game"])
		draw_rect(Rect2(8.0, size.y - 44.0, 16.0 + Gamepad.draw_row(self, told, Vector2(-4000.0, 0.0), 13.0, Color.WHITE), 36.0), Color(0, 0, 0, 0.55))
		Gamepad.draw_row(self, told, Vector2(16.0, size.y - 26.0), 13.0, Color.WHITE)
	var thing: Variant = now()
	if thing == null:
		return
	var rect: Rect2 = get_global_transform().affine_inverse() * rect_of(thing)
	rect = rect.grow(5.0)
	var beat := 0.5 + 0.5 * sin(Time.get_ticks_msec() * 0.006)
	draw_rect(rect, Color(MARK, 0.10 + 0.06 * beat))
	draw_rect(rect.grow(1.5), Color(0.0, 0.0, 0.0, 0.75), false, 7.0)
	draw_rect(rect.grow(1.5), MARK.lerp(Color.WHITE, 0.35 * beat), false, 3.5)
	# (and a bracket at each corner, so that it is found at a glance)
	for corner: Vector2 in [Vector2(-1, -1), Vector2(1, -1), Vector2(1, 1), Vector2(-1, 1)]:
		var at := rect.get_center() + (rect.size * 0.5 + Vector2(7.0, 7.0)) * corner
		draw_polyline([at - Vector2(corner.x * 14.0, 0.0), at, at - Vector2(0.0, corner.y * 14.0)], Color.WHITE, 3.0)
