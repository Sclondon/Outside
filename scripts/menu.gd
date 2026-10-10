class_name GameMenu
extends Control
## The menu: the boy's field notebook. A small notebook lies in the top right
## corner of the screen (or Esc, or Start on a gamepad); touched, the book comes
## up from his pack over the stopped game, its cover swings open, and its pages
## are the menu. Tabs down its edge turn to each part:
##
##   Journal  what the game has written in it (see Notebook, scripts/notebook.gd)
##   Me       how he is turned out: his face, the cut and colour of his hair, his
##            skin and eyes, what he wears and the colour of each thing, his cap,
##            a helmet and a backpack, or all of it at random. A photograph of
##            him is stuck in beside the lists, and is him as he stands.
##   Places   the levels, on a map; starting this one again; the level editor
##   Notes    how things are drawn: figures full or demade, the world's light
##
## The game pauses while it is out. Touching anywhere off the book, the corner
## again, the strap at the foot of the tabs, or Esc puts it away.
##
## What there is to choose from is in CharacterLook (scripts/character_look.gd)
## and Worn (scripts/worn.gd); what has been chosen is kept in Settings.
##
## Nothing here is a Button: every page is drawn by hand (NotebookInk), and
## each thing that can be touched is a "spot", a rectangle on a page noted as
## the page is drawn (see `_spot`). A finger, the arrow keys or a stick, and
## Enter or the jump button, all work the same spots.

const Ink := preload("res://scripts/notebook_ink.gd")

const LEVELS := [
	["Test yard", "res://test_yard.tscn"],
	["Desert", "res://desert.tscn"],
	["Tombs", "res://tomb.tscn"],
]
## What is drawn and said of each place on the map, and whereabouts on its sheet it is.
const PLACES := {
	"res://desert.tscn": {"sketch": "pyramid", "about": "dunes, ruins, the pyramids", "at": Rect2(34, 92, 236, 150)},
	"res://tomb.tscn": {"sketch": "scarab", "about": "today's tomb, and any other", "at": Rect2(48, 336, 150, 110)},
	"res://test_yard.tscn": {"sketch": "yard", "about": "a station for everything I can do", "at": Rect2(226, 322, 236, 150)},
}
## The parts of the book, in the order of their pages, and what is written on the tab of each.
const SECTIONS := ["journal", "me", "places", "notes"]
const TABS := {"journal": "Journal", "me": "Me", "places": "Places", "notes": "Notes"}
const TAB_COLOURS := {"journal": Color(0.90, 0.84, 0.70), "me": Color(0.62, 0.72, 0.78), "places": Color(0.86, 0.70, 0.42), "notes": Color(0.68, 0.76, 0.58)}

## A page, the thickness of the boards round the pages, and how far a tab stands out (and how tall it is).
const PAGE := Vector2(520.0, 600.0)
const BOARD := 14.0
const TAB := Vector2(54.0, 108.0)
const BOOK := Vector2((PAGE.x + BOARD) * 2.0, PAGE.y + BOARD * 2.0)
## Where the spine is, across the book.
const SPINE := PAGE.x + BOARD
## Seconds to come out and open, to shut and go, and to turn a leaf.
const OPEN_TIME := 0.42
const CLOSE_TIME := 0.26
const TURN_TIME := 0.32
## The journal: where its first line is written, how far apart the lines are, and how many to a page.
const FIRST_LINE := 100.0
const LEAD := 30.0
const LINES := 16
const MARGIN := 38.0


## Something that only draws what it is told to: a page, a board, the cover.
## (A Node2D, not a Control, so that it can be squashed and sheared as a leaf turns.)
class Leaf extends Node2D:
	var paint: Callable

	func _draw() -> void:
		if paint.is_valid():
			paint.call(self)


## Whether the book is out (or on its way out), and how far: 0 away, 1 open.
var _open := false
var _out := 0.0
## Which part it is open at, and at which pair of the journal's pages.
var _section := "journal"
var _journal_at := 0
## A leaf being turned: how far over it is (1: none is), which way (1 on, -1 back), and what was open before.
var _turn := 1.0
var _turn_dir := 1
var _turn_from := {}
var _turn_face := -1
## Which of his garments the paints colour.
var _garment := 0
var _garments: Array = []
var _paints: Array[Color] = []

## What can be touched: {"on", "id", "rect", "act"} each, noted as the pages are drawn.
var _spots: Array[Dictionary] = []
## The spot the keys or stick are on, whether they are in use (it is only marked if so), and the one under a finger.
var _focus := ""
var _keys := false
var _held := ""
var _press_index := -1
var _press_at := Vector2.ZERO
var _quiet := false
var _seen_version := -1

var _book: Leaf
var _left_half: Leaf
var _left: Leaf
var _right: Leaf
var _shade: Leaf
var _turning: Leaf
var _cover: Leaf
## His photograph: a view of him as he stands, taken from in front.
var _view: SubViewport
var _eye: Camera3D
var _board_box: StyleBoxFlat
var _tab_box: StyleBoxFlat
var _pill: StyleBoxFlat


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_section = Settings.notebook_section if SECTIONS.has(Settings.notebook_section) else "journal"
	# PLACEHOLDER entries, so that the journal is not blank: see Notebook.placeholders
	Notebook.placeholders()
	_journal_at = _journal_spreads() - 1
	_paints.assign(CharacterLook.SHIRTS + CharacterLook.CLOTHS + CharacterLook.DRESSES + CharacterLook.LEATHERS + CharacterLook.STOCKINGS)

	_board_box = StyleBoxFlat.new()
	_board_box.bg_color = Ink.LEATHER
	_board_box.border_color = Ink.LEATHER_DARK
	_board_box.set_border_width_all(3)
	_board_box.set_corner_radius_all(12)
	_tab_box = StyleBoxFlat.new()
	_tab_box.set_corner_radius_all(9)
	_tab_box.corner_radius_top_left = 0
	_tab_box.corner_radius_bottom_left = 0
	_tab_box.border_color = Color(0.3, 0.2, 0.1, 0.5)
	_tab_box.set_border_width_all(1)
	_tab_box.shadow_color = Color(0, 0, 0, 0.25)
	_tab_box.shadow_size = 3
	_pill = StyleBoxFlat.new()
	_pill.bg_color = Color(0.0, 0.0, 0.0, 0.22)
	_pill.set_corner_radius_all(12)

	# The book: the right board and the tabs; over them the left board with its
	# page (which is the inside of the cover as it opens), the right page, a
	# leaf that turns, and the cover seen from outside.
	_book = _leaf(self, _paint_book)
	_left_half = _leaf(_book, _paint_left_board)
	_left = _leaf(_left_half, func(on: Leaf) -> void: _paint_side(on, _spread_on(0), 0))
	_left.position = Vector2(-PAGE.x, BOARD)
	_right = _leaf(_book, func(on: Leaf) -> void: _paint_side(on, _spread_on(1), 1))
	_right.position = Vector2(SPINE, BOARD)
	_shade = _leaf(_book, _paint_shade)
	_turning = _leaf(_book, _paint_turning)
	_cover = _leaf(_book, _paint_cover)
	_book.visible = false

	_view = SubViewport.new()
	_view.size = Vector2i(366, 543)
	_view.render_target_update_mode = SubViewport.UPDATE_DISABLED
	add_child(_view)
	_eye = Camera3D.new()
	_eye.fov = 27.0
	_eye.far = 3000.0
	_view.add_child(_eye)

	resized.connect(_arrange)
	_arrange()
	# (he comes into a level wearing what he had on in the last)
	_wear.call_deferred()


func _leaf(under: Node, paint: Callable) -> Leaf:
	var leaf := Leaf.new()
	leaf.paint = paint
	under.add_child(leaf)
	return leaf


func _input(event: InputEvent) -> void:
	# (the level editor hides the rest of the screen while it is open, this with it)
	if not is_visible_in_tree():
		return
	if event.is_action_pressed(&"ui_cancel") or (event is InputEventJoypadButton and event.pressed and event.button_index == JOY_BUTTON_START):
		_keys = true
		_set_open(not _open)
		get_viewport().set_input_as_handled()
	elif event is InputEventScreenTouch:
		_touched(event)
	elif not _open:
		return
	elif event is InputEventScreenDrag:
		get_viewport().set_input_as_handled()
	elif event is InputEventKey or event is InputEventJoypadButton or event is InputEventJoypadMotion:
		_keyed(event)


func _touched(event: InputEventScreenTouch) -> void:
	var at: Vector2 = make_input_local(event).position
	if event.pressed:
		if _corner().has_point(at):
			_keys = false
			_set_open(not _open)
			get_viewport().set_input_as_handled()
		elif _open:
			_keys = false
			_press_index = event.index
			_press_at = at
			_held = _spot_at(at).get("id", "")
			_refresh()
			get_viewport().set_input_as_handled()
	elif event.index == _press_index:
		_press_index = -1
		var let_go := _spot_at(at)
		var was := _held
		_held = ""
		get_viewport().set_input_as_handled()
		if not _open:
			return
		if was != "" and let_go.get("id", "") == was:
			(let_go["act"] as Callable).call()
		elif was == "" and absf(at.x - _press_at.x) > 110.0 and absf(at.y - _press_at.y) < 90.0:
			# (a finger drawn across the pages turns them)
			_step_section(1 if at.x < _press_at.x else -1)
		elif was == "" and not _on_book(at) and not _on_book(_press_at):
			_set_open(false)
		_refresh()


func _keyed(event: InputEvent) -> void:
	var handled := true
	if event.is_action_pressed(&"ui_left", true):
		_move_focus(Vector2.LEFT)
	elif event.is_action_pressed(&"ui_right", true):
		_move_focus(Vector2.RIGHT)
	elif event.is_action_pressed(&"ui_up", true):
		_move_focus(Vector2.UP)
	elif event.is_action_pressed(&"ui_down", true):
		_move_focus(Vector2.DOWN)
	elif event.is_action_pressed(&"ui_accept"):
		_keys = true
		for spot in _spots:
			if spot["id"] == _focus:
				(spot["act"] as Callable).call()
				break
		_refresh()
	elif event.is_action_pressed(&"ui_page_down") or event.is_action_pressed(&"ui_focus_next") or _button(event, JOY_BUTTON_RIGHT_SHOULDER):
		_keys = true
		_step_section(1)
	elif event.is_action_pressed(&"ui_page_up") or event.is_action_pressed(&"ui_focus_prev") or _button(event, JOY_BUTTON_LEFT_SHOULDER):
		_keys = true
		_step_section(-1)
	else:
		handled = false
	if handled:
		get_viewport().set_input_as_handled()


func _button(event: InputEvent, button: JoyButton) -> bool:
	return event is InputEventJoypadButton and event.pressed and event.button_index == button


## Moves the mark the keys work to the nearest spot that way.
func _move_focus(way: Vector2) -> void:
	_keys = true
	var here := Vector2.INF
	for spot in _spots:
		if spot["id"] == _focus:
			here = _middle(spot)
	if here == Vector2.INF:
		_focus = "tab:" + _section
		_refresh()
		return
	var best := ""
	var least := INF
	for spot in _spots:
		var to := _middle(spot) - here
		var along := to.dot(way)
		var across := absf(to.dot(way.orthogonal()))
		# (what is more to one side than ahead is not that way at all)
		if spot["id"] == _focus or along < 6.0 or across > along * 2.5:
			continue
		var far := along + across * 2.2
		if far < least:
			least = far
			best = spot["id"]
	if best != "":
		_focus = best
	_refresh()


func _middle(spot: Dictionary) -> Vector2:
	return (spot["on"] as Node2D).get_global_transform() * (spot["rect"] as Rect2).get_center()


func _spot_at(at: Vector2) -> Dictionary:
	if _out < 0.6:
		return {}
	var on_screen := get_global_transform() * at
	for i in range(_spots.size() - 1, -1, -1):
		var on := _spots[i]["on"] as Node2D
		if on.is_visible_in_tree() and (_spots[i]["rect"] as Rect2).grow(3.0).has_point(on.get_global_transform().affine_inverse() * on_screen):
			return _spots[i]
	return {}


func _on_book(at: Vector2) -> bool:
	var local := _book.get_global_transform().affine_inverse() * (get_global_transform() * at)
	return Rect2(Vector2.ZERO, BOOK + Vector2(TAB.x, 0.0)).grow(14.0).has_point(local)


## The top right corner of the screen, which the touch controls leave alone
## (see TouchControls._press), and the notebook that lies in it.
func _corner() -> Rect2:
	return Rect2(size.x - 130.0, 0.0, 130.0, 64.0)


func _corner_book() -> Rect2:
	return Rect2(size.x - 118.0, 12.0, 104.0, 42.0)


func _process(delta: float) -> void:
	var moved := false
	var to := 1.0 if _open else 0.0
	if _out != to:
		_out = move_toward(_out, to, delta / (OPEN_TIME if _open else CLOSE_TIME))
		moved = true
		if _out == 0.0:
			_refresh()
	if _turn < 1.0:
		_turn = minf(1.0, _turn + delta / TURN_TIME)
		moved = true
		if _turn >= 1.0:
			_refresh()
	if moved:
		_arrange()
		queue_redraw()
	if _seen_version != Notebook.version:
		# (what is written while he has it open at the journal he has seen written)
		if _open and _section == "journal":
			Notebook.read()
		_seen_version = Notebook.version
		_journal_at = clampi(_journal_at, 0, _journal_spreads() - 1)
		_refresh()


## Takes the book out, or puts it away.
func _set_open(open: bool) -> void:
	if open == _open:
		return
	_open = open
	get_tree().paused = open
	_held = ""
	if open:
		# (anything new in the journal is what it opens at)
		if Notebook.unread > 0:
			_section = "journal"
			_journal_at = _journal_spreads() - 1
		_turn = 1.0
		_at_section()
	_refresh()


## Opens the book at the page he is dressed on.
func open_dresser() -> void:
	_section = "me"
	if _open:
		_at_section()
		_refresh()
	else:
		_set_open(true)
		_section = "me"
		_at_section()
		# (it is wanted now, not after it has swung up)
		_out = 1.0
		_arrange()
		_refresh()


## As the menu once was, for whatever still asks: its two pages were the dresser and everything else.
func _show_page(dressing: bool) -> void:
	_section = "me" if dressing else "places"
	_at_section()
	_refresh()


## What follows from being at a part of the book.
func _at_section() -> void:
	Settings.notebook_section = _section
	if _section == "journal":
		Notebook.read()
		_seen_version = Notebook.version
	elif _section == "me":
		_look_at_boy()
	if _keys:
		_focus = "tab:" + _section


## What is open: which part, and which pair of pages of it.
func _now() -> Dictionary:
	return {"section": _section, "at": _journal_at if _section == "journal" else 0}


## Turns to a part of the book (and, in the journal, a pair of its pages): one leaf goes over.
func _turn_to(section: String, at := -1) -> void:
	var was := _now()
	if section == "journal" and at == -1:
		at = _journal_at
	var is_now := {"section": section, "at": clampi(at, 0, _journal_spreads() - 1) if section == "journal" else 0}
	if was == is_now:
		return
	var before: int = SECTIONS.find(was["section"]) * 1000 + int(was["at"])
	var after: int = SECTIONS.find(is_now["section"]) * 1000 + int(is_now["at"])
	_turn_from = was
	_turn_dir = 1 if after > before else -1
	_turn = 0.0
	_turn_face = -1
	_section = section
	if section == "journal":
		_journal_at = is_now["at"]
	_at_section()
	_arrange()
	_refresh()


func _step_section(by: int) -> void:
	# (through the journal's pages first, then on to the next part)
	if _section == "journal" and _journal_at + by >= 0 and _journal_at + by < _journal_spreads():
		_turn_to("journal", _journal_at + by)
		return
	var next := SECTIONS.find(_section) + by
	if next >= 0 and next < SECTIONS.size():
		_turn_to(SECTIONS[next], (_journal_spreads() - 1) if by < 0 else 0)


## Which pair of pages the page lying on that side (0 left, 1 right) belongs
## to: while a leaf turns, one side is still what was open before.
func _spread_on(side: int) -> Dictionary:
	if _turn < 1.0 and (_turn_dir > 0) == (side == 0):
		return _turn_from
	return _now()


## Draws everything again.
func _refresh() -> void:
	var showing_him: bool = _out > 0.0 and (_section == "me" or (_turn < 1.0 and _turn_from.get("section", "") == "me"))
	_view.render_target_update_mode = SubViewport.UPDATE_ALWAYS if showing_him else SubViewport.UPDATE_DISABLED
	queue_redraw()
	for leaf: Leaf in [_book, _left_half, _left, _right, _shade, _turning, _cover]:
		leaf.queue_redraw()


## Sets the book where it should be: coming up, its cover swinging over, a leaf turning.
func _arrange() -> void:
	_book.visible = _out > 0.0
	var fit := minf(1.15, minf((size.x - 32.0) / (BOOK.x + TAB.x), (size.y - 68.0) / BOOK.y))
	var rest := Vector2(size.x * 0.5 - TAB.x * fit * 0.5, 62.0 + (size.y - 66.0) * 0.5)
	# It comes up from the bottom right, turning level as it comes
	var risen := smoothstep(0.0, 0.62, _out)
	var down := (1.0 - risen) * (1.0 - risen)
	_book.transform = Transform2D(0.34 * down, Vector2.ONE * fit * lerpf(0.74, 1.0, risen), 0.0, rest + Vector2(150.0, size.y * 0.9) * down) * Transform2D(0.0, -BOOK * 0.5)
	# and its cover goes over from the right to lie on the left, where its inside is the left page.
	var swung := smoothstep(0.3, 1.0, _out) * PI
	_cover.visible = swung < PI * 0.5
	_left_half.visible = not _cover.visible
	_cover.transform = Transform2D(Vector2(maxf(absf(cos(swung)), 0.002), -0.07 * sin(swung)), Vector2.DOWN, Vector2(SPINE, 0.0))
	_cover.modulate = Color.WHITE.darkened(0.3 * sin(swung))
	_left_half.transform = Transform2D(Vector2(maxf(absf(cos(swung)), 0.002), 0.07 * sin(swung)), Vector2.DOWN, Vector2(SPINE, 0.0))
	_left_half.modulate = Color.WHITE.darkened(0.3 * sin(swung))
	# A leaf going over: squashed towards the spine, its free edge lifted, until it is edge on; then its other face, growing out the other way.
	_turning.visible = _turn < 1.0
	_shade.visible = _turning.visible
	if _turning.visible:
		var over := smoothstep(0.0, 1.0, _turn) * PI
		var wide := maxf(absf(cos(over)), 0.002)
		var face := 1 if (over < PI * 0.5) == (_turn_dir > 0) else 0
		if face == 1:
			_turning.transform = Transform2D(Vector2(wide, -0.1 * sin(over)), Vector2.DOWN, Vector2(SPINE, BOARD))
		else:
			_turning.transform = Transform2D(Vector2(wide, 0.1 * sin(over)), Vector2.DOWN, Vector2(SPINE, BOARD)) * Transform2D(0.0, Vector2(-PAGE.x, 0.0))
		_turning.modulate = Color.WHITE.darkened(0.2 * sin(over))
		if face != _turn_face:
			_turn_face = face
			_turning.queue_redraw()
		_shade.queue_redraw()


## Notes somewhere that can be touched, as it is drawn, and marks it if a finger or the keys are on it.
func _spot(on: Node2D, id: String, rect: Rect2, act: Callable) -> void:
	if _quiet:
		return
	_spots.append({"on": on, "id": id, "rect": rect, "act": act})
	if _held == id:
		on.draw_rect(rect.grow(-1.0), Color(0.35, 0.22, 0.08, 0.16))
	if _keys and _focus == id:
		Ink.box(on, rect.grow(2.0), Ink.RED, 2.6)


## Forgets the spots on something that is about to be drawn again.
func _forget(on: Node2D) -> void:
	_spots = _spots.filter(func(spot: Dictionary) -> bool: return spot["on"] != on)


# ---------------------------------------------------------------- the book

func _draw() -> void:
	if _out > 0.0:
		draw_rect(Rect2(Vector2.ZERO, size), Color(0.06, 0.04, 0.02, 0.36 * _out))
	# The notebook in the corner: a dark ground under it, so that it shows on bright sand
	var corner := _corner_book()
	draw_style_box(_pill, corner)
	draw_set_transform(corner.get_center() + Vector2(-8.0, 0.0), -0.07)
	var cover := Rect2(-31.0, -15.0, 60.0, 31.0)
	draw_rect(Rect2(cover.position + Vector2(2.0, 3.0), cover.size), Ink.PAPER_DARK)
	draw_rect(Rect2(cover.position + Vector2(1.0, 1.5), cover.size), Ink.PAPER)
	draw_rect(cover, Ink.LEATHER.lightened(0.12 if _open else 0.0))
	draw_rect(cover, Ink.LEATHER_DARK, false, 1.5)
	draw_rect(Rect2(-22.0, -8.0, 26.0, 12.0), Ink.CARD)
	draw_line(Vector2(-18.0, -3.5), Vector2(0.0, -3.5), Ink.FAINT, 1.2)
	draw_line(Vector2(-18.0, 0.5), Vector2(-6.0, 0.5), Ink.FAINT, 1.2)
	draw_rect(Rect2(15.0, -15.0, 5.0, 31.0), Color(0.09, 0.07, 0.07))
	# and his pencil beside it
	draw_set_transform(corner.get_center() + Vector2(37.0, 0.0), 0.22)
	draw_rect(Rect2(-3.0, -13.0, 6.0, 22.0), Color(0.80, 0.62, 0.20))
	draw_colored_polygon([Vector2(-3.0, 9.0), Vector2(3.0, 9.0), Vector2(0.0, 16.0)], Ink.CARD)
	draw_colored_polygon([Vector2(-1.2, 13.2), Vector2(1.2, 13.2), Vector2(0.0, 16.0)], Ink.PENCIL)
	draw_rect(Rect2(-3.0, -16.0, 6.0, 3.5), Ink.RED)
	draw_set_transform(Vector2.ZERO)
	# (something has been written in it that has not been read)
	if Notebook.unread > 0 and not _open:
		draw_circle(corner.position + Vector2(8.0, 7.0), 7.0, Ink.RED, true, -1.0, true)
		draw_arc(corner.position + Vector2(8.0, 7.0), 7.0, 0.0, TAU, 20, Ink.CARD, 1.5, true)


func _board(on: Leaf, rect: Rect2) -> void:
	on.draw_style_box(_board_box, rect)
	# The grain of the cloth it is bound in
	var y := rect.position.y + 9.0
	while y < rect.end.y - 6.0:
		on.draw_line(Vector2(rect.position.x + 5.0, y), Vector2(rect.end.x - 5.0, y), Color(0.0, 0.0, 0.0, 0.07), 1.0)
		y += 5.0


func _paint_book(on: Leaf) -> void:
	_forget(on)
	on.draw_rect(Rect2(SPINE + 8.0, 12.0, PAGE.x + BOARD, BOOK.y), Color(0.0, 0.0, 0.0, 0.3))
	_board(on, Rect2(SPINE - 12.0, 0.0, PAGE.x + BOARD + 12.0, BOOK.y))
	# The tabs: one stuck to the first page of each part, and the strap that holds the book shut below them
	var names: Array = SECTIONS + ["away"]
	for i in names.size():
		var part: String = names[i]
		var current: bool = part == _section and _open
		var top := BOARD + 10.0 + i * (TAB.y + 6.0)
		var tab := Rect2(BOOK.x - BOARD - 6.0, top, TAB.x + BOARD + (6.0 if current else -4.0), TAB.y)
		var colour: Color = TAB_COLOURS.get(part, Ink.LEATHER.lightened(0.1))
		_tab_box.bg_color = colour if current or part == "away" else colour.darkened(0.14)
		on.draw_style_box(_tab_box, tab)
		var label: String = TABS.get(part, "Put away")
		var middle := Vector2(BOOK.x + (TAB.x + (10.0 if current else 0.0)) * 0.5 - 4.0, top + TAB.y * 0.5)
		on.draw_set_transform(middle, PI * 0.5)
		var wide := Ink.width_of(label, 25)
		on.draw_string(Ink.font(), Vector2(-wide * 0.5, 8.0), label, HORIZONTAL_ALIGNMENT_LEFT, -1, 25, Ink.CARD if part == "away" else Ink.INK)
		if current:
			on.draw_line(Vector2(-wide * 0.5, 13.0), Vector2(wide * 0.5, 13.0), Ink.RED, 2.2, true)
		on.draw_set_transform(Vector2.ZERO)
		var touch := Rect2(BOOK.x - 8.0, top, TAB.x + 14.0, TAB.y)
		if part == "away":
			_spot(on, "tab:away", touch, _set_open.bind(false))
		else:
			_spot(on, "tab:" + part, touch, _turn_to.bind(part))
	# The edges of all the pages under the one that is open
	for i in 3:
		on.draw_rect(Rect2(SPINE, BOARD - 1.0 + i, PAGE.x + 5.0 - i * 1.5, PAGE.y + 5.0 - i * 2.0), Ink.PAPER_DARK.lightened(0.12 * i))


func _paint_left_board(on: Leaf) -> void:
	_board(on, Rect2(-SPINE, 0.0, SPINE + 12.0, BOOK.y))
	# (the spine, where the two boards meet)
	on.draw_rect(Rect2(-16.0, 0.0, 32.0, BOOK.y), Ink.LEATHER)
	on.draw_rect(Rect2(-16.0, 0.0, 32.0, 3.0), Ink.LEATHER_DARK)
	on.draw_rect(Rect2(-16.0, BOOK.y - 3.0, 32.0, 3.0), Ink.LEATHER_DARK)
	for i in 3:
		on.draw_rect(Rect2(-PAGE.x - 5.0 + i * 1.5, BOARD - 1.0 + i, PAGE.x + 5.0 - i * 1.5, PAGE.y + 5.0 - i * 2.0), Ink.PAPER_DARK.lightened(0.12 * i))


## The book shut, from the front: its board, a label pasted on, the elastic round it.
func _paint_cover(on: Leaf) -> void:
	_board(on, Rect2(0.0, 0.0, SPINE, BOOK.y))
	for corner: Array in [[Vector2(SPINE, 0.0), Vector2(-1, 1)], [Vector2(SPINE, BOOK.y), Vector2(-1, -1)]]:
		var at: Vector2 = corner[0]
		var way: Vector2 = corner[1]
		on.draw_colored_polygon([at + Vector2(way.x * 6.0, way.y * 4.0), at + Vector2(way.x * 44.0, way.y * 4.0), at + Vector2(way.x * 6.0, way.y * 44.0)], Ink.LEATHER.lightened(0.14))
	Ink.card(on, Rect2(110.0, 150.0, 300.0, 170.0), -0.012)
	Ink.box(on, Rect2(120.0, 160.0, 280.0, 150.0), Ink.FAINT, 1.4)
	Ink.write_mid(on, Vector2(260.0, 218.0), "Field Notes", 46, Ink.INK, 0.0)
	Ink.line(on, Vector2(170.0, 234.0), Vector2(350.0, 234.0), Ink.INK, 1.8)
	Ink.write_mid(on, Vector2(260.0, 272.0), "Egypt, 1912", 28, Ink.BLUE, 0.0)
	Ink.card_done(on)
	on.draw_rect(Rect2(SPINE - 86.0, 0.0, 18.0, BOOK.y), Color(0.08, 0.06, 0.06))
	on.draw_rect(Rect2(SPINE - 86.0, 0.0, 4.0, BOOK.y), Color(1.0, 1.0, 1.0, 0.07))


## The shadow a turning leaf throws on the page under it.
func _paint_shade(on: Leaf) -> void:
	if _turn >= 1.0:
		return
	var over := smoothstep(0.0, 1.0, _turn) * PI
	var side := 1.0 if (over < PI * 0.5) == (_turn_dir > 0) else -1.0
	var reach := (PAGE.x * absf(cos(over)) + 46.0 * sin(over)) * side
	var dark := Color(0.1, 0.06, 0.02, 0.34 * sin(over))
	var clear := Color(0.1, 0.06, 0.02, 0.0)
	on.draw_polygon([Vector2(SPINE, BOARD), Vector2(SPINE + reach, BOARD), Vector2(SPINE + reach, BOARD + PAGE.y), Vector2(SPINE, BOARD + PAGE.y)], [dark, clear, clear, dark])


func _paint_turning(on: Leaf) -> void:
	if _turn >= 1.0 or _turn_face < 0:
		return
	# (it shows the page it was until it is edge on, and after that the back of itself: a page of what is turned to)
	var first_half := smoothstep(0.0, 1.0, _turn) < 0.5
	_quiet = true
	_paint_side(on, _turn_from if first_half else _now(), _turn_face)
	_quiet = false


# ---------------------------------------------------------------- the pages

## Draws one page: the left (0) or right (1) of a pair.
func _paint_side(on: Leaf, spread: Dictionary, side: int) -> void:
	if not _quiet:
		_forget(on)
	var part: String = spread.get("section", "journal")
	Ink.paper(on, PAGE, 2 if part == "me" or part == "places" else 1, 1 if side == 0 else -1, SECTIONS.find(part) * 7.0 + side * 3.0 + int(spread.get("at", 0)) * 11.0)
	match part:
		"journal":
			_page_journal(on, int(spread.get("at", 0)), side)
		"me":
			if side == 0:
				_page_me(on)
			else:
				_page_wardrobe(on)
		"places":
			if side == 0:
				_page_map(on)
			else:
				_page_places(on)
		"notes":
			if side == 0:
				_page_notes(on)
			else:
				_page_getting_about(on)


func _title(on: Leaf, text: String) -> void:
	var wide := Ink.write(on, Vector2(MARGIN, 60.0), text, 40, Ink.INK, -0.012)
	Ink.line(on, Vector2(MARGIN - 4.0, 70.0), Vector2(MARGIN + wide + 14.0, 67.0), Ink.INK, 2.2)


## Words that do something when touched: in a pencil box.
func _word(on: Leaf, id: String, rect: Rect2, text: String, act: Callable, size := 24) -> void:
	Ink.box(on, rect.grow(-3.0), Ink.PENCIL, 1.8)
	Ink.write_mid(on, Vector2(rect.get_center().x, rect.get_center().y + size * 0.34), text, size, Ink.INK)
	_spot(on, id, rect, act)


# --- Journal

## How many lines of a page an entry takes, with the gap under it.
func _entry_lines(entry: Dictionary) -> int:
	var wide := PAGE.x - MARGIN * 2.0
	var heading := 1 if entry.get("heading", "") != "" else 0
	match entry["kind"]:
		&"task":
			return Ink.wrap(entry["text"], wide - 44.0, 23).size() + 1
		&"sketch":
			return heading + 5 + (Ink.wrap(entry["text"], wide, 21).size() if entry["text"] != "" else 0) + 1
		&"find":
			return 1 + maxi(3, Ink.wrap(entry["text"], wide - 124.0, 22).size()) + 1
		&"translation":
			return 2 + Ink.wrap(entry["text"], wide, 22).size() + heading + 1
	return heading + Ink.wrap(entry["text"], wide, 22).size() + 1


## The journal set out in pages: each a list of [entry, the line it starts on].
func _journal_pages() -> Array:
	var pages := [[]]
	var line := 0
	for entry in Notebook.entries:
		var takes := _entry_lines(entry)
		if line > 0 and line + takes - 1 > LINES:
			pages.append([])
			line = 0
		(pages[-1] as Array).append([entry, line])
		line += takes
	return pages


func _journal_spreads() -> int:
	return maxi(1, ceili(_journal_pages().size() / 2.0))


func _page_journal(on: Leaf, at: int, side: int) -> void:
	var pages := _journal_pages()
	var number := at * 2 + side
	if number == 0:
		_title(on, "Journal")
	if number < pages.size():
		for placed: Array in pages[number]:
			# (under the title on the first page; from the top line of the others)
			_entry(on, placed[0], FIRST_LINE + (float(placed[1]) - (0.0 if number == 0 else 1.0)) * LEAD - 3.0)
	elif number == 0 or pages[0].is_empty():
		Ink.write(on, Vector2(MARGIN, FIRST_LINE - 3.0), "Nothing yet.", 22, Ink.FAINT)
	Ink.write_mid(on, Vector2(PAGE.x * 0.5, PAGE.y - 14.0), str(number + 1), 18, Ink.FAINT)
	# Back and on through its pages, at the foot of each
	if side == 0 and at > 0:
		_word(on, "journal:back", Rect2(MARGIN - 8.0, PAGE.y - 58.0, 130.0, 48.0), "< earlier", _turn_to.bind("journal", at - 1), 22)
	if side == 1 and at < _journal_spreads() - 1:
		_word(on, "journal:on", Rect2(PAGE.x - MARGIN - 122.0, PAGE.y - 58.0, 130.0, 48.0), "later >", _turn_to.bind("journal", at + 1), 22)


## Writes one entry, its first line's baseline at `y`.
func _entry(on: Leaf, entry: Dictionary, y: float) -> void:
	var wide := PAGE.x - MARGIN * 2.0
	var heading: String = entry.get("heading", "")
	var text: String = entry["text"]
	match entry["kind"]:
		&"task":
			var is_done: bool = entry.get("done", false)
			Ink.box(on, Rect2(MARGIN + 2.0, y - 19.0, 21.0, 21.0), Ink.PENCIL, 1.8)
			if is_done:
				Ink.tick(on, Vector2(MARGIN + 11.0, y - 1.0), 17.0)
			Ink.write_lines(on, Vector2(MARGIN + 40.0, y), Ink.wrap(text, wide - 44.0, 23), 23, Ink.FAINT if is_done else Ink.BLUE, LEAD)
		&"sketch":
			if heading != "":
				Ink.write(on, Vector2(MARGIN, y), heading, 23, Ink.BLUE)
				y += LEAD
			Ink.sketch(on, entry.get("sketch"), Rect2(MARGIN + 60.0, y - 16.0, wide - 120.0, LEAD * 5.0 - 14.0))
			if text != "":
				Ink.write_lines(on, Vector2(MARGIN, y + LEAD * 5.0), Ink.wrap(text, wide, 21), 21, Ink.PENCIL, LEAD)
		&"find":
			# Numbered as the finds of a dig are, with the thing drawn small beside what is said of it
			Ink.ring(on, Vector2(MARGIN + 15.0, y - 8.0), Vector2(15.0, 13.0), Ink.RED, 1.8, float(entry.get("number", 0)))
			Ink.write_mid(on, Vector2(MARGIN + 15.0, y - 1.0), str(entry.get("number", 0)), 20, Ink.RED, 0.0)
			Ink.write(on, Vector2(MARGIN + 40.0, y), heading, 23, Ink.INK)
			Ink.write_lines(on, Vector2(MARGIN, y + LEAD), Ink.wrap(text, wide - 124.0, 22), 22, Ink.PENCIL, LEAD)
			if entry.get("sketch") != null:
				Ink.sketch(on, entry["sketch"], Rect2(PAGE.x - MARGIN - 108.0, y + 2.0, 104.0, LEAD * 3.0))
		&"translation":
			Ink.sketch(on, entry.get("signs"), Rect2(MARGIN + 6.0, y - 18.0, wide - 12.0, LEAD * 2.0 - 14.0))
			var down := Ink.write_lines(on, Vector2(MARGIN, y + LEAD * 2.0), Ink.wrap(text, wide, 22), 22, Ink.BLUE, LEAD)
			if heading != "":
				Ink.write(on, Vector2(MARGIN + 20.0, y + LEAD * 2.0 + down), "- " + heading, 20, Ink.FAINT)
		_:
			if heading != "":
				var under := Ink.write(on, Vector2(MARGIN, y), heading, 24, Ink.INK)
				Ink.line(on, Vector2(MARGIN, y + 5.0), Vector2(MARGIN + under, y + 4.0), Ink.INK, 1.4)
				y += LEAD
			Ink.write_lines(on, Vector2(MARGIN, y), Ink.wrap(text, wide, 22), 22, Ink.INK, LEAD)


# --- Me

## The left page: his photograph, and the paints for his skin, hair and eyes.
func _page_me(on: Leaf) -> void:
	_title(on, "Me")
	var photo := Rect2(28.0, 84.0, 262.0, 400.0)
	Ink.card(on, photo, -0.014, Color(0.95, 0.94, 0.89))
	var picture := Rect2(photo.position + Vector2(9.0, 9.0), Vector2(244.0, 362.0))
	if _boy() != null:
		on.draw_texture_rect(_view.get_texture(), picture, false, Color(1.0, 0.98, 0.93))
	else:
		on.draw_rect(picture, Color(0.55, 0.5, 0.42))
	on.draw_rect(picture, Color(0.2, 0.15, 0.1, 0.5), false, 1.0)
	Ink.write_mid(on, Vector2(photo.get_center().x, photo.end.y - 8.0), "at the dig, 1912", 19, Ink.FAINT, 0.0)
	# (held to the page by its corners)
	for corner: Array in [[photo.position, Vector2(1, 1)], [Vector2(photo.end.x, photo.position.y), Vector2(-1, 1)], [photo.end, Vector2(-1, -1)], [Vector2(photo.position.x, photo.end.y), Vector2(1, -1)]]:
		var at: Vector2 = corner[0] - Vector2(corner[1]) * 3.0
		on.draw_colored_polygon([at, at + Vector2(corner[1].x * 26.0, 0.0), at + Vector2(0.0, corner[1].y * 26.0)], Color(0.2, 0.17, 0.15))
	Ink.card_done(on)

	var y := 96.0
	y = _dabs(on, "Skin", "skin", CharacterLook.SKINS, Vector2(304.0, y))
	y = _dabs(on, "Hair", "hair", CharacterLook.HAIR_COLOURS, Vector2(304.0, y + 6.0))
	# (they show on the sculpted face, which is the one with eyes to colour)
	_dabs(on, "Eyes", "iris", CharacterLook.EYE_COLOURS, Vector2(304.0, y + 6.0))
	_word(on, "random", Rect2(28.0, 520.0, 226.0, 56.0), "Any old how", _random)
	_word(on, "as_he_was", Rect2(266.0, 520.0, 226.0, 56.0), "As he was", _reset_clothes)


## Paints to choose one from, for one material, four to a row. Returns how far down they come.
func _dabs(on: Leaf, title: String, material: String, colours: Array[Color], at: Vector2) -> float:
	Ink.write(on, at + Vector2(2.0, 0.0), title, 21, Ink.FAINT)
	var worn := _colour_of(material)
	for i in colours.size():
		var cell := Rect2(at + Vector2((i % 4) * 47.0, 6.0 + (i / 4) * 47.0), Vector2(46.0, 46.0))
		Ink.dab(on, cell.grow(-2.0), colours[i])
		if worn.is_equal_approx(colours[i]):
			Ink.ring(on, cell.get_center(), Vector2(23.0, 22.0), Ink.INK, 2.4, i)
		_spot(on, "%s:%d" % [material, i], cell, _recolour.bind(colours[i], material))
	return at.y + 6.0 + ceili(colours.size() / 4.0) * 47.0 + 22.0


## The right page: the lists he chooses from, his cap and pack, and a scrap of
## each thing he has on, with the paintbox that colours whichever is chosen.
func _page_wardrobe(on: Leaf) -> void:
	var helmet := ""
	for entry: Array in Worn.HELMETS:
		if entry[0] == Settings.helmet:
			helmet = entry[1]
	var face := ""
	for entry: Array in CharacterLook.FACES:
		if entry[0] == Settings.face:
			face = entry[1]
	var worn := CharacterLook.outfit(Settings.outfit)
	var rows := [["Face", face, _step_face], ["Hair", CharacterLook.hair(Settings.hair)["label"], _step_hair],
		["Clothes", worn["label"], _step_outfit], ["Helmet", helmet, _step_helmet]]
	for i in rows.size():
		_chooser(on, rows[i][0], rows[i][1], rows[i][2], 26.0 + i * 54.0)
	_box(on, "cap", Rect2(28.0, 246.0, 226.0, 50.0), "Cap", Settings.cap, _swap_cap)
	_box(on, "backpack", Rect2(266.0, 246.0, 226.0, 50.0), "Backpack", Settings.backpack, _swap_pack)

	_garments = worn["garments"]
	_garment = clampi(_garment, 0, _garments.size() - 1)
	Ink.write(on, Vector2(MARGIN - 6.0, 326.0), "Colours", 21, Ink.FAINT)
	Ink.write(on, Vector2(MARGIN + 70.0, 326.0), "- touch a scrap, then a paint", 18, Ink.FAINT)
	var each := 464.0 / maxi(_garments.size(), 5)
	for i in _garments.size():
		var cell := Rect2(28.0 + i * each, 334.0, each - 3.0, 66.0)
		Ink.scrap(on, Rect2(cell.position + Vector2(6.0, 4.0), Vector2(cell.size.x - 12.0, 36.0)), _colour_of(_garments[i][1]))
		Ink.write_mid(on, Vector2(cell.get_center().x, cell.end.y - 5.0), _garments[i][0], 18, Ink.INK if i == _garment else Ink.FAINT, 0.0)
		if i == _garment:
			Ink.ring(on, cell.get_center(), cell.size * 0.5 + Vector2(1.0, 1.0), Ink.RED, 2.2, 3.0)
		_spot(on, "garment:%d" % i, cell, _choose_garment.bind(i))
	var chosen := _colour_of(_garments[_garment][1])
	for i in _paints.size():
		var cell := Rect2(28.0 + (i % 10) * 46.4, 410.0 + (i / 10) * 48.0, 46.0, 47.0)
		Ink.dab(on, cell.grow(-2.0), _paints[i])
		if chosen.is_equal_approx(_paints[i]):
			Ink.ring(on, cell.get_center(), Vector2(23.0, 22.0), Ink.INK, 2.4, i)
		_spot(on, "paint:%d" % i, cell, _paint_garment.bind(_paints[i]))


## A line of a list to step through: what it is, an arrow each way, and what is chosen between them.
func _chooser(on: Leaf, title: String, chosen: String, step: Callable, y: float) -> void:
	Ink.write(on, Vector2(MARGIN - 6.0, y + 34.0), title, 21, Ink.FAINT)
	var back := Rect2(112.0, y, 52.0, 52.0)
	var onward := Rect2(440.0, y, 52.0, 52.0)
	for arrow: Array in [[back, -1.0], [onward, 1.0]]:
		var middle: Vector2 = (arrow[0] as Rect2).get_center()
		var way: float = arrow[1]
		Ink.ring(on, middle, Vector2(21.0, 20.0), Ink.FAINT, 1.5, y + way)
		on.draw_polyline([middle + Vector2(-5.0 * way, -10.0), middle + Vector2(7.0 * way, 0.0), middle + Vector2(-5.0 * way, 10.0)], Ink.INK, 3.2, true)
	var size := 25
	while size > 17 and Ink.width_of(chosen, size) > 262.0:
		size -= 1
	Ink.write_mid(on, Vector2(302.0, y + 35.0), chosen, size, Ink.BLUE)
	Ink.line(on, Vector2(174.0, y + 43.0), Vector2(430.0, y + 42.0), Ink.FAINT, 1.2)
	_spot(on, title.to_lower() + ":back", back, step.bind(-1))
	_spot(on, title.to_lower() + ":on", onward, step.bind(1))


## A box to tick.
func _box(on: Leaf, id: String, rect: Rect2, title: String, ticked: bool, act: Callable) -> void:
	var square := Rect2(rect.position + Vector2(12.0, 12.0), Vector2(26.0, 26.0))
	Ink.box(on, square, Ink.PENCIL, 2.0)
	if ticked:
		Ink.tick(on, square.position + Vector2(11.0, 23.0), 21.0)
	Ink.write(on, rect.position + Vector2(52.0, 34.0), title, 25, Ink.INK)
	_spot(on, id, rect, act)


# --- Places

## The left page: a map folded and stuck in, with each level drawn on it. Touch one to go there.
func _page_map(on: Leaf) -> void:
	var here := _level_path()
	var sheet := Rect2(20.0, 26.0, 480.0, 548.0)
	Ink.card(on, sheet, 0.008, Color(0.90, 0.85, 0.70))
	# (the creases it was folded on)
	for fold: float in [sheet.position.x + sheet.size.x / 3.0, sheet.position.x + sheet.size.x * 2.0 / 3.0]:
		on.draw_line(Vector2(fold, sheet.position.y), Vector2(fold, sheet.end.y), Color(0.3, 0.2, 0.1, 0.16), 2.0)
		on.draw_line(Vector2(fold + 2.0, sheet.position.y), Vector2(fold + 2.0, sheet.end.y), Color(1.0, 1.0, 1.0, 0.25), 1.0)
	on.draw_line(Vector2(sheet.position.x, sheet.get_center().y), Vector2(sheet.end.x, sheet.get_center().y), Color(0.3, 0.2, 0.1, 0.16), 2.0)
	Ink.write(on, Vector2(40.0, 66.0), "The workings", 30, Ink.INK, -0.01)
	# North, top right
	var north := Vector2(440.0, 96.0)
	Ink.line(on, north + Vector2(0.0, 32.0), north + Vector2(0.0, -30.0), Ink.PENCIL, 1.8)
	Ink.line(on, north + Vector2(-22.0, 0.0), north + Vector2(22.0, 0.0), Ink.PENCIL, 1.4)
	on.draw_colored_polygon([north + Vector2(0.0, -34.0), north + Vector2(-6.0, -16.0), north + Vector2(6.0, -16.0)], Ink.PENCIL)
	Ink.write_mid(on, north + Vector2(0.0, -40.0), "N", 20, Ink.PENCIL, 0.0)
	# The track between them, dotted
	var track: Array[Vector2] = [Vector2(278.0, 196.0), Vector2(330.0, 222.0), Vector2(362.0, 268.0), Vector2(352.0, 316.0)]
	for i in track.size() - 1:
		for dash in 4:
			Ink.line(on, track[i].lerp(track[i + 1], dash / 4.0), track[i].lerp(track[i + 1], dash / 4.0 + 0.13), Ink.RED, 2.0, 0.3)
	Ink.write(on, Vector2(378.0, 250.0), "by camel,", 18, Ink.FAINT)
	Ink.write(on, Vector2(378.0, 272.0), "half a day", 18, Ink.FAINT)
	for level: Array in LEVELS:
		# (a level that has not been made yet is left out)
		if not ResourceLoader.exists(level[1]) or not PLACES.has(level[1]):
			continue
		var place: Dictionary = PLACES[level[1]]
		var at: Rect2 = place["at"]
		Ink.sketch(on, place["sketch"], at)
		var wide := Ink.write_mid(on, Vector2(at.get_center().x, at.end.y + 24.0), level[0], 26, Ink.INK)
		if level[1] == here:
			var mark := Vector2(at.get_center().x - wide * 0.5 - 24.0, at.end.y + 15.0)
			Ink.line(on, mark + Vector2(-9.0, -9.0), mark + Vector2(9.0, 9.0), Ink.RED, 3.0)
			Ink.line(on, mark + Vector2(9.0, -9.0), mark + Vector2(-9.0, 9.0), Ink.RED, 3.0)
			Ink.write_mid(on, Vector2(at.get_center().x, at.end.y + 46.0), "(I am here)", 19, Ink.RED)
		_spot(on, "map:" + level[1], Rect2(at.position, at.size + Vector2(0.0, 52.0)), _go_to.bind(level[1]))
	Ink.card_done(on)


## The right page: the same places as a list, this one again, and the level editor.
func _page_places(on: Leaf) -> void:
	_title(on, "Places")
	var here := _level_path()
	var y := 92.0
	var number := 1
	for level: Array in LEVELS:
		if not ResourceLoader.exists(level[1]):
			continue
		var row := Rect2(28.0, y, 464.0, 64.0)
		Ink.write(on, Vector2(MARGIN, y + 30.0), "%d." % number, 24, Ink.FAINT)
		var wide := Ink.write(on, Vector2(MARGIN + 30.0, y + 30.0), level[0], 28, Ink.INK)
		Ink.write(on, Vector2(MARGIN + 30.0, y + 54.0), PLACES.get(level[1], {}).get("about", ""), 19, Ink.FAINT)
		if level[1] == here:
			Ink.write(on, Vector2(MARGIN + 44.0 + wide, y + 30.0), "- here", 21, Ink.RED)
		else:
			Ink.write(on, Vector2(row.end.x - 78.0, y + 38.0), "go >", 24, Ink.BLUE)
		_spot(on, "go:" + level[1], row, _go_to.bind(level[1]))
		y += 70.0
		number += 1
	y += 16.0
	Ink.line(on, Vector2(MARGIN, y - 8.0), Vector2(PAGE.x - MARGIN, y - 9.0), Ink.FAINT, 1.2)
	_word(on, "restart", Rect2(28.0, y, 464.0, 58.0), "Start this place again", _restart, 26)
	# (a level made from a layout can be changed: see LevelEditor)
	if get_tree().get_first_node_in_group(&"editable_level") != null:
		_word(on, "edit", Rect2(28.0, y + 66.0, 464.0, 58.0), "Edit this level", _edit, 26)
	# (and a tomb can be made by hand: see TombEditor)
	elif here == "res://tomb.tscn" and ResourceLoader.exists("res://tomb_editor.tscn"):
		_word(on, "edit", Rect2(28.0, y + 66.0, 464.0, 58.0), "Make a tomb of my own", _go_to.bind("res://tomb_editor.tscn"), 26)
	# His ticket up from Cairo, tucked into the foot of the page
	var ticket := Rect2(150.0, 468.0, 300.0, 104.0)
	Ink.card(on, ticket, -0.045, Color(0.83, 0.66, 0.52))
	Ink.box(on, ticket.grow(-7.0), Color(0.3, 0.16, 0.1, 0.7), 1.3)
	Ink.write_mid(on, Vector2(ticket.get_center().x, ticket.position.y + 31.0), "EGYPTIAN STATE RAILWAYS", 17, Color(0.3, 0.16, 0.1), 0.0)
	Ink.write_mid(on, Vector2(ticket.get_center().x, ticket.position.y + 63.0), "CAIRO  to  LUXOR", 27, Color(0.25, 0.12, 0.08), 0.0)
	Ink.write_mid(on, Vector2(ticket.get_center().x, ticket.position.y + 88.0), "3rd class   single   No. 0412", 17, Color(0.3, 0.16, 0.1), 0.0)
	on.draw_circle(Vector2(ticket.position.x + 24.0, ticket.get_center().y), 7.0, Ink.PAPER)
	Ink.card_done(on)


# --- Notes

## The left page: how things are drawn. Of each pair one is ringed and the other struck out.
func _page_notes(on: Leaf) -> void:
	_title(on, "Notes")
	_either(on, "figures", "Figures drawn", "in full", "demade", Settings.low_poly, _swap_models, 100.0)
	_either(on, "world", "Light on the world", "smooth", "in bands", Settings.world_banded, _swap_world, 220.0)
	Ink.write(on, Vector2(MARGIN, 356.0), "(changing either starts this place again)", 19, Ink.FAINT)
	# Room for more, later
	Ink.write(on, Vector2(MARGIN, 416.0), "Sound", 24, Ink.FAINT)
	Ink.write(on, Vector2(MARGIN + 150.0, 416.0), "- nothing to set yet", 20, Ink.FAINT)
	Ink.write(on, Vector2(MARGIN, 476.0), "Controls", 24, Ink.FAINT)
	Ink.write(on, Vector2(MARGIN + 150.0, 476.0), "- nothing to set yet", 20, Ink.FAINT)


## One thing or the other: `second` says whether it is the second that is chosen.
func _either(on: Leaf, id: String, title: String, one: String, other: String, second: bool, swap: Callable, y: float) -> void:
	Ink.write(on, Vector2(MARGIN, y + 24.0), title + ":", 24, Ink.INK)
	var words := [one, other]
	for i in 2:
		var cell := Rect2(MARGIN + 14.0 + i * 216.0, y + 38.0, 200.0, 60.0)
		var middle := cell.get_center()
		var wide := Ink.write_mid(on, middle + Vector2(0.0, 9.0), words[i], 28, Ink.BLUE if (i == 1) == second else Ink.FAINT)
		if (i == 1) == second:
			Ink.ring(on, middle, Vector2(wide * 0.5 + 22.0, 24.0), Ink.RED, 2.4, y + i)
			# (the one already chosen does nothing, but is somewhere for the keys to rest)
			_spot(on, "%s:%d" % [id, i], cell, func() -> void: pass)
		else:
			Ink.strike(on, middle + Vector2(-wide * 0.5 - 6.0, 2.0), middle + Vector2(wide * 0.5 + 6.0, 2.0), Ink.FAINT)
			_spot(on, "%s:%d" % [id, i], cell, swap)


## The right page: how he is moved about, for whoever has forgotten.
func _page_getting_about(on: Leaf) -> void:
	_title(on, "Getting about")
	var notes := [
		"Left thumb, anywhere: walk. Push further and I run; hold it there and I sprint.",
		"Right thumb: jump. Hold it for a higher one.",
		"The two rings, bottom right: duck, and my hand (pick up, throw, climb).",
		"Keys: W A S D, Space, C to duck, E for my hand. A gamepad works too.",
	]
	var y := FIRST_LINE - 3.0
	for text: String in notes:
		on.draw_circle(Vector2(MARGIN + 5.0, y - 8.0), 3.2, Ink.INK, true, -1.0, true)
		y += Ink.write_lines(on, Vector2(MARGIN + 20.0, y), Ink.wrap(text, PAGE.x - MARGIN * 2.0 - 20.0, 22), 22, Ink.INK, LEAD) + LEAD * 0.0
	# A leaf pressed between the pages
	var olive := Color(0.36, 0.40, 0.20)
	Ink.strokes(on, Rect2(310.0, 400.0, 150.0, 150.0), Ink.SKETCHES["leaf"], olive, 2.4)
	Ink.write(on, Vector2(MARGIN + 6.0, 540.0), "from the garden at Shepheard's", 19, Ink.FAINT, -0.03)


# ---------------------------------------------------------------- what the pages do

func _level_path() -> String:
	var level := owner if owner else get_tree().current_scene
	return level.scene_file_path if level else ""


## Sets the pages to what he has on. (They are drawn from Settings each time: this only draws them again.)
func _show_clothes() -> void:
	_refresh()


## The colour something of his is now: what has been chosen, or what he was made with.
func _colour_of(material: String) -> Color:
	var boy := _boy()
	var made: Color = boy.made_colours.get(material, Color.GRAY) if boy else Color.GRAY
	return Settings.colours.get(material, made)


## The boy's rig: the first figure that is neither something else's model nor
## somebody else turned out on his (see CharacterRig.look).
func _boy() -> CharacterRig:
	for figure: CharacterRig in get_tree().get_nodes_in_group(&"figures"):
		if figure.model == null and figure.look.is_empty():
			return figure
	return null


## Points the camera of his photograph at him: from in front and a little to
## one side, or from whichever side nothing stands in the way.
func _look_at_boy() -> void:
	var boy := _boy()
	if boy == null:
		return
	var ahead := Vector3(boy.global_basis.z.x, 0.0, boy.global_basis.z.z)
	ahead = ahead.normalized() if ahead.length() > 0.01 else Vector3.BACK
	var chest := boy.global_position + Vector3.UP * 0.74
	var from := chest + ahead * 3.9
	# (whatever he is standing in is not in the way of his own picture)
	var skip: Array[RID] = []
	var above: Node = boy
	while above:
		if above is CollisionObject3D:
			skip.append((above as CollisionObject3D).get_rid())
		above = above.get_parent()
	for turn: float in [0.4, -0.4, 1.0, -1.0, 0.0, 1.7, -1.7, PI]:
		from = chest + ahead.rotated(Vector3.UP, turn) * 3.9 + Vector3.UP * 0.12
		var ray := PhysicsRayQueryParameters3D.create(chest, from)
		ray.exclude = skip
		if boy.get_world_3d().direct_space_state.intersect_ray(ray).is_empty():
			break
	_eye.look_at_from_position(from, chest)


func _restyle() -> void:
	get_tree().call_group(&"figures", &"restyle")
	_show_clothes()


func _recolour(colour: Color, material: String) -> void:
	Settings.colours[material] = colour
	CharacterLook.matched(Settings.colours, Settings.outfit)
	get_tree().call_group(&"figures", &"restyle")
	_refresh()


func _choose_garment(index: int) -> void:
	_garment = index
	_refresh()


func _paint_garment(colour: Color) -> void:
	if _garment < _garments.size():
		_recolour(colour, _garments[_garment][1])


func _swap_cap() -> void:
	Settings.cap = not Settings.cap
	_restyle()


func _step_helmet(by: int) -> void:
	var names: Array = Worn.HELMETS.map(func(entry: Array) -> String: return entry[0])
	Settings.helmet = names[posmod(names.find(Settings.helmet) + by, names.size())]
	_wear()
	_show_clothes()


func _swap_pack() -> void:
	Settings.backpack = not Settings.backpack
	_wear()
	_show_clothes()


## Puts on the boy the helmet and the pack that have been chosen.
func _wear() -> void:
	Worn.dress_boy(_boy())


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


## Opens the level editor over this level. (The book is gone at once; the game stays stopped, which the editor wants.)
func _edit() -> void:
	_open = false
	_out = 0.0
	_arrange()
	_refresh()
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
