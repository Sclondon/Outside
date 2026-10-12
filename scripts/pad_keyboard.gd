class_name PadKeyboard
extends Control
## Letters to choose with a gamepad, for a name or an inscription: a desk has
## no keyboard on the screen of its own, and a gamepad has no keys. It comes up
## over the foot of the screen with what has been written so far above it.
##
##   d-pad or left stick   from letter to letter
##   A                     writes the one the mark is on
##   X                     rubs out the last
##   Y                     capitals, and back
##   Start                 done: what is written is kept
##   B                     away, and nothing is changed
##
## "Space", "Rub out", "Capitals" and "Done" are in the bottom row as well.
## `done(text, kept)` is sent as it goes, and it takes itself away. PadFocus
## brings it up for any line of writing that A is pressed on.

signal done(text: String, kept: bool)

const ROWS := ["1234567890", "qwertyuiop", "asdfghjkl'", "zxcvbnm,.?", "-:;!()/\"@&"]
const WORDS := ["Capitals", "Space", "Rub out", "Done"]
const KEY := Vector2(64.0, 54.0)
const GAP := 6.0

## What has been written, and what it is (written small over it).
var text := ""
var title := ""

var _at := Vector2i(0, 1)
var _capitals := false
var _steps := Gamepad.Steps.new()
var _up := 0.0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	# (over whatever is put on the screen after it)
	z_index = 100
	Gamepad.ensure(get_tree())


func _process(delta: float) -> void:
	_up += delta
	var way := _steps.take(delta)
	if way != Vector2.ZERO:
		_move(Vector2i(way))
	queue_redraw()


func _move(by: Vector2i) -> void:
	var last := ROWS.size()
	if by.y != 0:
		var was := _at.y
		_at.y = posmod(_at.y + by.y, last + 1)
		# (ten letters to a row, four words in the last: the mark keeps as near under itself as it can)
		if _at.y == last and was != last:
			_at.x = clampi(_at.x * WORDS.size() / 10, 0, WORDS.size() - 1)
		elif was == last and _at.y != last:
			_at.x = clampi(_at.x * 10 / WORDS.size() + 1, 0, 9)
	else:
		_at.x = posmod(_at.x + by.x, WORDS.size() if _at.y == last else 10)


## The letter the mark is on, as it would be written; or one of WORDS.
func on_key() -> String:
	if _at.y == ROWS.size():
		return WORDS[_at.x]
	var letter: String = ROWS[_at.y][_at.x]
	return letter.to_upper() if _capitals else letter


## Puts the mark on a letter (or one of WORDS). For the tools.
func go_to(key: String) -> void:
	var at := WORDS.find(key)
	if at != -1:
		_at = Vector2i(at, ROWS.size())
		return
	for y in ROWS.size():
		at = (ROWS[y] as String).find(key.to_lower())
		if at != -1:
			_at = Vector2i(at, y)
			_capitals = key != key.to_lower()
			return


func _press() -> void:
	match on_key():
		"Capitals":
			_capitals = not _capitals
		"Space":
			text += " "
		"Rub out":
			text = text.left(-1)
		"Done":
			_finish(true)
		var letter:
			text += letter


func _finish(kept: bool) -> void:
	set_process(false)
	set_process_input(false)
	done.emit(text, kept)
	queue_free()


func _input(event: InputEvent) -> void:
	if not Gamepad.heard(event):
		return
	if event is InputEventJoypadButton and event.pressed and _up > 0.15:
		if Gamepad.pressed(event, &"pad_a"):
			_press()
		elif Gamepad.pressed(event, &"pad_x"):
			text = text.left(-1)
		elif Gamepad.pressed(event, &"pad_y"):
			_capitals = not _capitals
		elif Gamepad.pressed(event, &"pad_start"):
			_finish(true)
		elif Gamepad.pressed(event, &"pad_b"):
			_finish(false)
	# (while it is up the gamepad is its own, and nothing else's)
	get_viewport().set_input_as_handled()


func _draw() -> void:
	var font := ThemeDB.fallback_font
	var wide := KEY.x * 10.0 + GAP * 9.0
	var tall := (KEY.y + GAP) * (ROWS.size() + 1) + 84.0 + 44.0
	var board := Rect2((size.x - wide) * 0.5 - 18.0, size.y - tall - 14.0, wide + 36.0, tall)
	draw_rect(Rect2(Vector2.ZERO, size), Color(0.0, 0.0, 0.0, 0.35))
	draw_rect(board, Color(0.11, 0.09, 0.07, 0.97))
	draw_rect(board, Color(1.0, 1.0, 1.0, 0.25), false, 2.0)
	# What has been written, with a line where the next letter goes.
	var line := Rect2(board.position + Vector2(18.0, 30.0), Vector2(wide, 46.0))
	if title != "":
		draw_string(font, board.position + Vector2(20.0, 22.0), title, HORIZONTAL_ALIGNMENT_LEFT, wide, 15, Color(1.0, 1.0, 1.0, 0.6))
	draw_rect(line, Color(0.04, 0.03, 0.02))
	draw_rect(line, Color(1.0, 1.0, 1.0, 0.4), false, 1.5)
	var shown := text
	while shown.length() > 1 and font.get_string_size(shown, HORIZONTAL_ALIGNMENT_LEFT, -1.0, 26).x > wide - 30.0:
		shown = shown.substr(1)
	draw_string(font, line.position + Vector2(10.0, 33.0), shown, HORIZONTAL_ALIGNMENT_LEFT, -1.0, 26, Color(1.0, 0.97, 0.88))
	if fmod(_up, 1.0) < 0.55:
		var end := line.position.x + 12.0 + font.get_string_size(shown, HORIZONTAL_ALIGNMENT_LEFT, -1.0, 26).x
		draw_rect(Rect2(end, line.position.y + 8.0, 3.0, 30.0), PadFocus.MARK)
	var top := line.end.y + 10.0
	for y in ROWS.size() + 1:
		var count := WORDS.size() if y == ROWS.size() else 10
		var each := (wide - GAP * (count - 1)) / count
		for x in count:
			var key := Rect2(board.position.x + 18.0 + x * (each + GAP), top + y * (KEY.y + GAP), each, KEY.y)
			var chosen := _at == Vector2i(x, y)
			var word: String = WORDS[x] if y == ROWS.size() else ROWS[y][x]
			if y < ROWS.size() and _capitals:
				word = word.to_upper()
			var lit: bool = word == "Capitals" and _capitals
			draw_rect(key, Color(0.66, 0.5, 0.22) if lit else Color(0.3, 0.25, 0.18))
			if chosen:
				draw_rect(key, Color(PadFocus.MARK, 0.3))
				draw_rect(key.grow(2.0), Color(0, 0, 0, 0.8), false, 7.0)
				draw_rect(key.grow(2.0), PadFocus.MARK, false, 3.5)
			draw_string(font, Vector2(key.position.x, key.get_center().y + 9.0), word, HORIZONTAL_ALIGNMENT_CENTER, key.size.x, 26 if y < ROWS.size() else 21, Color(1.0, 0.97, 0.88))
	Gamepad.draw_row(self, [[&"pad_a", "write"], [&"pad_x", "rub out"], [&"pad_y", "capitals"], [&"pad_start", "done"], [&"pad_b", "leave it as it was"]],
		Vector2(board.position.x + 20.0, board.end.y - 22.0), 12.0, Color(1.0, 1.0, 1.0, 0.85), Color(0, 0, 0, 0), font, 16)
