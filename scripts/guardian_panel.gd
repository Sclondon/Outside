class_name GuardianPanel
extends Control
## What comes up over the game for the gate guardians: the leaf of the Book of
## the Dead he has just picked up, to read (`GuardianPanel.read`), and the
## three names a guardian offers, to choose from (`GuardianPanel.ask`).
##
## The game stands still while either is up, so he is safe to read. It is all
## drawn here, and worked by a finger: a leaf is put away by a touch anywhere;
## a name is said by touching it (each is a button the size of a hand), and
## "Step back" says nothing. The arrow keys and Enter, or a gamepad (its d-pad or stick, and A),
## do the same, and Esc or B steps back. What it says to do is said for whichever was used last (Gamepad.using).
##
## Nothing here is smaller than 88 high to touch, or written smaller than 26.

## A name was touched (its place in `BookOfTheDead.NAMES`), or -1 for none.
signal answered(choice: int)
## The leaf was put away.
signal closed

const TEXT := 26
## How long a leaf must have been up before a touch puts it away, seconds.
const PATIENCE := 0.45

## The one that is up, if one is.
static var current: GuardianPanel

## What is asked: the names offered (empty for a leaf to read), which of them
## is right, and whether he has the leaf that says so.
var dealt: Array[int] = []
var who := 0
var known := false
## The head the one who asks has.
var head := 0
## Where each name's button is on the screen, in the order of `dealt`; and "Step back".
var buttons: Array[Rect2] = []
var back := Rect2()

var _layer: CanvasLayer
var _up := 0.0
var _press := -1
var _held := -2
var _focus := -2
var _keys := false
var _was_paused := false
## A gamepad's d-pad and stick, as steps of the mark.
var _steps := Gamepad.Steps.new()


## Shows the leaf with this keeper's name on it. `from` is anything in the level.
static func read(from: Node, name: int) -> GuardianPanel:
	var panel := _open(from)
	if panel:
		panel.who = name
		panel.head = BookOfTheDead.NAMES[name]["head"]
	return panel


## Offers `names` to choose from: `name` is the right one, `has_leaf` whether
## he has found the leaf that says so, `beast` the head of the one who asks.
static func ask(from: Node, names: Array[int], name: int, has_leaf: bool, beast: int) -> GuardianPanel:
	var panel := _open(from)
	if panel:
		panel.dealt = names.duplicate()
		panel.who = name
		panel.known = has_leaf
		panel.head = beast
	return panel


static func _open(from: Node) -> GuardianPanel:
	if is_instance_valid(current) or from == null or not from.is_inside_tree():
		return null
	var tree := from.get_tree()
	var panel := GuardianPanel.new()
	# (over everything, and the last thing in the scene: so it is the first to hear of a touch)
	panel._layer = CanvasLayer.new()
	panel._layer.layer = 40
	panel._layer.process_mode = Node.PROCESS_MODE_ALWAYS
	panel._layer.add_child(panel)
	tree.root.add_child(panel._layer)
	current = panel
	Gamepad.ensure(tree)
	# The game stands still, and lets go of whatever the thumbs were holding.
	panel._was_paused = tree.paused
	tree.paused = true
	for controls: Node in tree.get_nodes_in_group(&"touch_controls"):
		controls.notification(NOTIFICATION_APPLICATION_FOCUS_OUT)
	return panel


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _process(delta: float) -> void:
	_up += delta
	# (the notebook lets the game go on when it is put away: not while this is up)
	if not get_tree().paused:
		get_tree().paused = true
	_work_pad(delta)
	queue_redraw()


# A gamepad: its d-pad or stick moves the mark from name to name (and down to
# "Step back"), as the arrow keys do. With one in his hands the mark is on the
# first name from the start.
func _work_pad(delta: float) -> void:
	if dealt.is_empty() or Loading.busy:
		return
	if Gamepad.using_pad() and not _keys:
		_keys = true
		if _focus == -2:
			_focus = dealt[0]
	var way := _steps.take(delta)
	if way != Vector2.ZERO:
		_step(way)


# Moves the mark a step: across the names, down to "Step back", up to the names again.
func _step(way: Vector2) -> void:
	_keys = true
	if way.x != 0.0:
		var now := dealt.find(_focus)
		_focus = dealt[clampi(now + int(way.x), 0, dealt.size() - 1)] if _focus >= 0 else dealt[0 if way.x > 0.0 else dealt.size() - 1]
	elif way.y > 0.0:
		_focus = -1
	else:
		_focus = dealt[1]


# A gamepad's buttons: any of them puts a leaf away; A says the name the mark is on, B steps back.
func _padded(event: InputEvent) -> void:
	if not (event is InputEventJoypadButton and event.pressed) or _up <= PATIENCE:
		return
	if dealt.is_empty():
		choose(-1)
	elif Gamepad.pressed(event, &"pad_b"):
		choose(-1)
	elif Gamepad.pressed(event, &"pad_a") and _keys and _focus != -2:
		choose(_focus)


## Puts it away, and lets the game go on.
func put_away() -> void:
	if current == self:
		current = null
	get_tree().paused = _was_paused
	set_process(false)
	set_process_input(false)
	_layer.queue_free()


## Says a name (or -1, none), as a touch on its button does.
func choose(choice: int) -> void:
	put_away()
	if dealt.is_empty():
		closed.emit()
	else:
		answered.emit(choice)


func _input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		var at: Vector2 = make_input_local(event).position
		if event.pressed and _press == -1:
			_keys = false
			_press = event.index
			_held = _button_at(at)
		elif not event.pressed and event.index == _press:
			_press = -1
			var was := _held
			_held = -2
			if dealt.is_empty():
				if _up > PATIENCE:
					choose(-1)
			elif was != -2 and _button_at(at) == was:
				choose(was)
		get_viewport().set_input_as_handled()
	elif event is InputEventScreenDrag or event is InputEventMouse:
		get_viewport().set_input_as_handled()
	elif event is InputEventJoypadButton or event is InputEventJoypadMotion:
		if Gamepad.heard(event):
			_padded(event)
			get_viewport().set_input_as_handled()
	elif event is InputEventKey:
		if event.is_echo():
			pass
		elif dealt.is_empty():
			if _up > PATIENCE and event.is_pressed():
				choose(-1)
		elif event.is_action_pressed(&"ui_cancel"):
			choose(-1)
		elif event.is_action_pressed(&"ui_left") or event.is_action_pressed(&"ui_right"):
			_keys = true
			var step := 1 if event.is_action_pressed(&"ui_right") else -1
			var now := dealt.find(_focus)
			_focus = dealt[clampi(now + step, 0, dealt.size() - 1)] if _focus >= 0 else dealt[0 if step > 0 else dealt.size() - 1]
		elif event.is_action_pressed(&"ui_down"):
			_keys = true
			_focus = -1
		elif event.is_action_pressed(&"ui_up"):
			_keys = true
			_focus = dealt[1]
		elif event.is_action_pressed(&"ui_accept") and _keys and _focus != -2:
			choose(_focus)
		get_viewport().set_input_as_handled()


# Which name's button a place on the screen is on: -1 for "Step back", -2 for none.
func _button_at(at: Vector2) -> int:
	lay_out()
	for n in buttons.size():
		if buttons[n].has_point(at):
			return dealt[n]
	if back.has_point(at):
		return -1
	return -2


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), Color(0.05, 0.03, 0.02, 0.62))
	if dealt.is_empty():
		_draw_leaf()
	else:
		_draw_names()


func _write(text: String, at: Vector2, points: int, colour: Color) -> void:
	draw_string(NotebookInk.font(), at, text, HORIZONTAL_ALIGNMENT_LEFT, -1, points, colour)


# Lines of writing, each in the middle of `wide` from `at` across. Returns how far down they went.
func _write_mid(text: String, at: Vector2, wide: float, points: int, colour: Color, lead := 0.0) -> float:
	if lead == 0.0:
		lead = points * 1.2
	var lines := NotebookInk.wrap(text, wide, points)
	for n in lines.size():
		var across := NotebookInk.width_of(lines[n], points)
		_write(lines[n], at + Vector2((wide - across) * 0.5, n * lead), points, colour)
	return lines.size() * lead


# The leaf he has found: the keeper, his name in signs, and what it says.
func _draw_leaf() -> void:
	var name: Dictionary = BookOfTheDead.NAMES[who]
	var sheet := Rect2((size.x - 1000.0) * 0.5, (size.y - 640.0) * 0.5, 1000.0, 640.0)
	BookOfTheDead.draw_papyrus(self, sheet)
	var picture := Rect2(sheet.position + Vector2(44.0, 70.0), Vector2(360.0, 432.0))
	draw_rect(picture, Color(BookOfTheDead.PAPYRUS.lightened(0.18), 0.7))
	draw_rect(picture, BookOfTheDead.INK, false, 2.0)
	BookOfTheDead.draw_vignette(self, picture.grow(-14.0), who)
	var left := picture.end.x + 36.0
	var wide := sheet.end.x - 44.0 - left
	_write_mid("A leaf of the Book of the Dead", Vector2(left, sheet.position.y + 78.0), wide, 30, BookOfTheDead.RUBRIC)
	BookOfTheDead.draw_signs(self, Rect2(left, sheet.position.y + 104.0, wide, 216.0), who, BookOfTheDead.INK, 120.0)
	draw_line(Vector2(left + 40.0, sheet.position.y + 338.0), Vector2(left + wide - 40.0, sheet.position.y + 338.0), BookOfTheDead.RUBRIC, 2.0)
	var down := sheet.position.y + 388.0
	down += _write_mid(name["name"], Vector2(left, down), wide, 40, BookOfTheDead.INK, 46.0)
	_write_mid(name["from"], Vector2(left, down + 6.0), wide, TEXT, Color(BookOfTheDead.INK, 0.72), 32.0)
	_write_mid("His name. Whoever says it may pass his gate.", Vector2(picture.position.x, picture.end.y + 44.0), picture.size.x, TEXT, BookOfTheDead.INK, 30.0)
	if _up > PATIENCE:
		var ink := Color(BookOfTheDead.RUBRIC, 0.6 + 0.4 * sin(_up * 3.0))
		if Gamepad.using_pad():
			var across := NotebookInk.width_of("puts it away", TEXT) + 44.0
			Gamepad.draw_row(self, [[&"pad_a", "puts it away"]], Vector2(left + (wide - across) * 0.5, sheet.end.y - 43.0), 15.0, ink, Color(0, 0, 0, 0), NotebookInk.font(), TEXT)
		else:
			_write_mid("Touch to put it away" if Gamepad.using == Gamepad.Using.TOUCH else "Any key puts it away", Vector2(left, sheet.end.y - 34.0), wide, TEXT, ink)


## Works out where the buttons are (`buttons`, `back`) from the size of the
## screen alone. Returns the sheet, the picture, and where the names start and how wide each is.
func lay_out() -> Array:
	var sheet := Rect2(48.0, 20.0, size.x - 96.0, size.y - 40.0)
	var picture := Rect2(sheet.position + Vector2(30.0, 84.0), Vector2(250.0, 300.0))
	var left := picture.end.x + 22.0
	var gap := 16.0
	var wide := (sheet.end.x - 30.0 - left - gap * 2.0) / 3.0
	var top := sheet.position.y + 84.0
	var deep := sheet.end.y - 24.0 - 88.0 - 16.0 - top
	buttons.clear()
	for n in dealt.size():
		buttons.append(Rect2(left + n * (wide + gap), top, wide, deep))
	back = Rect2(sheet.end.x - 30.0 - 320.0, sheet.end.y - 24.0 - 88.0, 320.0, 88.0)
	return [sheet, picture, left, wide]


# The three names, each a button, with the one who asks beside them.
func _draw_names() -> void:
	var set_out := lay_out()
	var sheet: Rect2 = set_out[0]
	var picture: Rect2 = set_out[1]
	var left: float = set_out[2]
	var wide: float = set_out[3]
	BookOfTheDead.draw_papyrus(self, sheet)
	draw_rect(picture, Color(BookOfTheDead.PAPYRUS.lightened(0.18), 0.7))
	draw_rect(picture, BookOfTheDead.INK, false, 2.0)
	BookOfTheDead.draw_keeper(self, picture.grow(-10.0), head)
	_write_mid("\"Say my name.\"", Vector2(sheet.position.x, sheet.position.y + 58.0), sheet.size.x, 38, BookOfTheDead.RUBRIC)
	var told := "I have his leaf: it is the name I can read." if known else "I have not found his leaf. A wrong name, and he strikes."
	_write_mid(told, Vector2(picture.position.x, picture.end.y + 40.0), picture.size.x, TEXT, BookOfTheDead.INK, 31.0)
	for n in dealt.size():
		var button := buttons[n]
		var down: bool = _held == dealt[n]
		draw_rect(Rect2(button.position + Vector2(4.0, 5.0), button.size), Color(0.2, 0.14, 0.06, 0.35))
		draw_rect(button, BookOfTheDead.PAPYRUS.lightened(0.06 if down else 0.3))
		draw_rect(button, BookOfTheDead.INK, false, 3.0)
		draw_rect(button.grow(-7.0), BookOfTheDead.RUBRIC, false, 1.5)
		if _keys and _focus == dealt[n]:
			draw_rect(button.grow(5.0), BookOfTheDead.RUBRIC, false, 4.0)
		var english: bool = known and dealt[n] == who
		var words := 150.0 if known else 0.0
		BookOfTheDead.draw_signs(self, Rect2(button.position + Vector2(18.0, 18.0), button.size - Vector2(36.0, 36.0 + words)), dealt[n], BookOfTheDead.INK, 104.0)
		if english:
			var lines := NotebookInk.wrap(BookOfTheDead.NAMES[who]["name"], wide - 30.0, 28)
			var points := 28 if lines.size() <= 4 else TEXT
			_write_mid(BookOfTheDead.NAMES[who]["name"], Vector2(button.position.x + 15.0, button.end.y - words + 30.0), wide - 30.0, points, BookOfTheDead.INK, 32.0)
	draw_rect(back,BookOfTheDead.PAPYRUS.lightened(0.06 if _held == -1 else 0.3))
	draw_rect(back, BookOfTheDead.INK, false, 3.0)
	if _keys and _focus == -1:
		draw_rect(back.grow(5.0), BookOfTheDead.RUBRIC, false, 4.0)
	_write_mid("Step back", Vector2(back.position.x, back.position.y + 56.0), back.size.x, 34, BookOfTheDead.INK)
	var faint := Color(BookOfTheDead.INK, 0.75)
	if Gamepad.using_pad():
		Gamepad.draw_row(self, [[&"pad_dpad", "choose"], [&"pad_a", "say it"], [&"pad_b", "step back"]], Vector2(left + 8.0, back.position.y + 45.0), 15.0, faint, Color(0, 0, 0, 0), NotebookInk.font(), TEXT)
	elif Gamepad.using == Gamepad.Using.TOUCH:
		_write_mid("Touch a name to say it.", Vector2(left, back.position.y + 54.0), back.position.x - left - 16.0, TEXT, faint)
	else:
		_write_mid("Click a name to say it.", Vector2(left, back.position.y + 54.0), back.position.x - left - 16.0, TEXT, faint)
