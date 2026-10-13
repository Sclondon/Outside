class_name TombEditorPad
extends Control
## The tomb editor worked with a gamepad, on a desk (`TombEditor` makes one of
## these beside its panels and is told nothing more). The editor is all
## buttons, so a mark is on one of them always (PadFocus), and the marks drawn
## on a floor plan (the "+" off a room, the places it could move to, the rooms
## it could join) are things the mark can be put on like any other.
##
##   d-pad           the mark: over the buttons, the row of rooms, the panel, the marks on a floor plan
##   A               works what the mark is on;  left and right step through a list it is on
##   left stick      moves the tomb about;   triggers: left nearer, right further off
##   shoulders       the room before, the room after
##   Y               the mark to the top of the panel: the settings of the chosen room
##   X               removes the chosen room
##   B               closes a sheet; or gives up moving or joining a room
##   left stick in   undo;   right stick in: redo
##   Start           the mark to Play
##
## A tomb's name, or the number of one of the generator's, is written with letters that come up for it (PadKeyboard).

var editor: TombEditor
var mark: PadFocus


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mark = PadFocus.new()
	mark.roots = [editor._ui]
	mark.scope = func() -> Control: return editor._sheet if editor._sheet.visible else null
	mark.extra = _marks
	mark.stick = false
	mark.left.connect(_back)
	add_child(mark)
	mark.active = true


# The marks drawn on a floor plan, as things the mark can be put on.
func _marks() -> Array:
	var found: Array = []
	if not editor._floor:
		return found
	for i in editor._marks.size():
		var drawn: Array = editor._marks[i]
		var reach := float(drawn[1]) - 8.0
		found.append({"id": "mark:%d" % i, "rect": Rect2(drawn[0] - Vector2(reach, reach), Vector2(reach, reach) * 2.0), "act": drawn[2]})
	return found


func _back() -> void:
	if editor._sheet.visible:
		editor._close_sheet()
	elif editor.mode != "":
		editor.mode = ""


func _process(delta: float) -> void:
	if mark.typing():
		return
	var stick := Gamepad.left()
	if stick != Vector2.ZERO and not editor._sheet.visible:
		stick *= stick.length() * editor._per_pixel() * 760.0 * delta
		editor._focus += Vector2(stick.x, stick.y if editor._floor else -stick.y)
	var pull := Gamepad.triggers()
	if pull != 0.0:
		editor.zoom(exp(pull * 1.3 * delta))
	queue_redraw()


func _input(event: InputEvent) -> void:
	if mark.typing() or not Gamepad.heard(event) or not event is InputEventJoypadButton or not event.pressed:
		return
	var handled := true
	if editor._sheet.visible:
		# (a sheet is up: only the mark, A and B)
		handled = false
	elif Gamepad.pressed(event, &"pad_lb") or Gamepad.pressed(event, &"pad_rb"):
		var to := clampi(editor.chosen + (1 if Gamepad.pressed(event, &"pad_rb") else -1), 0, editor.rooms().size() - 1)
		editor.mode = ""
		editor.choose(to)
		editor.look_at_room(to)
	elif Gamepad.pressed(event, &"pad_y"):
		editor._show_side(true)
		_put_under(editor._inspector)
	elif Gamepad.pressed(event, &"pad_start"):
		_put_under(editor._ui)
	elif Gamepad.pressed(event, &"pad_x"):
		editor.remove()
	elif Gamepad.pressed(event, &"pad_l3"):
		editor.undo()
	elif Gamepad.pressed(event, &"pad_r3"):
		editor.redo()
	else:
		handled = false
	if handled:
		get_viewport().set_input_as_handled()


# Puts the mark on the first thing there is to work inside something.
func _put_under(above: Node) -> void:
	for thing: Variant in mark.things():
		if thing is Control and above.is_ancestor_of(thing):
			mark.put_on(thing)
			return


func _draw() -> void:
	if not Gamepad.using_pad() or mark.typing():
		return
	var told := [[&"pad_dpad", "the mark"], [&"pad_a", "press"], [&"pad_ls", "move the tomb"], [&"pad_lb", ""], [&"pad_rb", "rooms"], [&"pad_y", "this room"], [&"pad_x", "remove it"], [&"pad_l3", "undo"]]
	if editor._sheet.visible:
		told = [[&"pad_dpad", "the mark"], [&"pad_a", "press"], [&"pad_b", "close"]]
	elif editor.mode != "":
		told = [[&"pad_dpad", "to a ringed place"], [&"pad_a", "there"], [&"pad_b", "not now"]]
	var room := size.x - 74.0 - (TombEditor.PANEL + 24.0 if editor._side.visible else 16.0)
	Gamepad.draw_legend(self, told, Vector2(74.0, size.y - 92.0), room)
