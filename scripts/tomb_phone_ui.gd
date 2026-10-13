class_name TombPhoneUI
extends Control
## What is on the screen of the tomb editor (`TombEditor`) on a phone, held on
## its side and worked with two thumbs. The editor itself is the same one: this
## is only what is touched, in place of the top bar, the room strip, the panel
## and the sheet it has where there is a mouse.
##
## THE TOMB HAS THE SCREEN. Down the left edge, under the left thumb, is one
## bar of six buttons for the whole tomb: Play, Undo, Redo, Rooms, Tombs and
## More. Down the right edge, under the right thumb, are the buttons of the
## room that is chosen: Edit, Add, and then Copy, Earlier, Later and Remove
## (a tomb down one axis) or Move, Join and Remove (a floor plan). Along the
## top is one strip that says what is chosen and what a touch will do, and
## under that whether the tomb can be finished, or the first thing wrong with
## it: a touch on it opens the whole list. At the bottom are further, all of
## it, and nearer, for a hand that cannot pinch.
##
## EVERYTHING ELSE IS A PAGE over the tomb, one at a time, with its Done (or
## Back, on a page opened from another) at the top right every time. A room's
## page leaves a strip of the tomb showing at the left, with that room in it.
## A choice from a list is a page of rows, each with what it is called and a
## line about it; a number is a minus, the number and a plus; a yes or no is a
## switch as wide as its row. A page is dragged up and down with a finger.
##
## Nothing here is smaller than TOUCH each way or nearer its neighbour than
## GAP, no words are smaller than TEXT, and nothing stands within EDGE of the
## left and right of the screen or FOOT of the bottom (`tools/tomb_phone_probe.gd`
## measures all of that). Everything touched is a `Touch`, which is given the
## fingers themselves (`InputEventScreenTouch`), so a drag that begins on a row
## scrolls the page and does not press the row.

## The least a thing to touch measures each way, and the least between two of them.
const TOUCH := 88.0
const GAP := 12.0
## The smallest words, and the size of a heading.
const TEXT := 26
const TITLE := 30
## How wide the two bars down the sides are.
const COLUMN := 120.0
## What is kept clear at the left and right of the screen (notches, round corners), at the bottom (the
## system's own swipe) and at the top.
const EDGE := 48.0
const FOOT := 24.0
const HEAD := 8.0
## How far a finger may wander and still have tapped.
const SLOP := 14.0
## How much of the tomb is left showing beside a room's page, and the widest that page is.
const SLIVER := 300.0
const PAGE_MOST := 960.0

const INK := Color(0.96, 0.95, 0.92)
const DIM := Color(0.78, 0.78, 0.8)
const GOLD := Color(1.0, 0.86, 0.45)
const GOOD := Color(0.62, 0.92, 0.56)
const CARE := Color(1.0, 0.78, 0.42)
const BAD := Color(1.0, 0.62, 0.52)

const ROLE_NOTES := {
	"corridor": "A plain passage, low and narrow.",
	"well": "A shaft in the floor to jump. A chamber at its foot can hold a seal stone.",
	"hall": "A wide room with pillars down both sides.",
	"gallery": "The tallest of the rooms.",
	"antechamber": "A small room, as stands before a burial chamber.",
}
const MUMMY_NOTES := [
	"Slow, in lurches, and swipes an arm. A trench stops it.",
	"Tall and stiff; strikes far in front, and is slow to turn. A kerb stops it.",
	"Squat and heavy; sweeps an arm round, which he can duck. A narrow gap stops it.",
	"Hauls itself along fast and goes for his ankles: jump it. A kerb stops it.",
	"Small and quick, in bursts; springs at him from close to. A trench stops it.",
	"Gold-masked, and never hurries; strikes with its crook from far off. A trench stops it.",
]
const BARRIER_NOTES := {
	"auto": "Whatever this kind of mummy cannot get past.",
	"trench": "Cut across the floor: stops the shambler, the child and the royal one.",
	"kerb": "A step across the floor: stops the priest and the crawler.",
	"narrow": "Two piers close together: stops the brute.",
	"none": "It can follow him wherever it can walk.",
}
const WAY_SAYS := {
	"open": "Walked straight through. Its door can have a lock.",
	"stairs": "A flight down to a lower room. Things can be carried on it.",
	"crawl": "A low passage to duck through. It has no door, so no lock.",
	"flood": "He swims, and lets go of whatever he carries.",
	"shaft": "Nothing is carried up or down a ladder.",
	"rope": "He can drop down it with a thing, but nothing comes back up.",
	"gap": "Too wide to jump: wants a grappling hook left in an earlier room.",
	"sand": "The room beyond is higher: sand is let in to walk up. Nothing is carried up it.",
}
const HELP := [
	["Looking about", "One finger drags the tomb about and two pinch. The three buttons at the bottom go further off, show all of it, and come nearer."],
	["Choosing a room", "Touch a room on the tomb. The strip along the top says which is chosen. Rooms, at the left, lists them all."],
	["Changing a room", "Edit, at the right, opens the chosen room's page (so does a second touch on the room): what it is, what is in it, the way to the next room and what locks the door. The arrows at the top of the page go to the room before and the room after."],
	["Adding and taking away", "The buttons at the right are for the chosen room: Add puts a new one after it, Copy makes another like it, Earlier and Later move it along, and Remove takes it away. Undo, at the left, puts back whatever was last done."],
	["Whether it works", "After every change every order he could do things in is tried. The second line of the strip says whether the tomb can be finished, or the first thing wrong: touch the strip for all of it, and one way through step by step."],
	["Keeping it", "Every change is kept on this device under the tomb's name. Tombs has the others, a new one, one of the generator's to change, and the tomb as text to send or paste."],
]
const HELP_FLOOR := [
	["Looking about", "A tomb that branches is seen from overhead with its roofs off. One finger drags it about and two pinch. The three buttons at the bottom go further off, show all of it, and come nearer."],
	["Choosing a room", "Touch a room on the plan. The strip along the top says which is chosen. Rooms, at the left, lists them all."],
	["Adding a room", "A + stands off each side of the chosen room that a new room could be made on: touch one. Add, at the right, does the same from a list."],
	["Move, Join, Remove", "Move marks every place the chosen room could go instead (only a room with nothing beyond it moves). Join marks the rooms beside it that a second way could be made to, which is what closes a loop. Either has List for the same as rows, and Cancel. Remove takes the room away; Undo puts it back."],
	["Changing a room", "Edit opens the chosen room's page (so does a second touch on the room). Here the way and the lock are of the way INTO the room, and what opens its door may stand in any room of the tomb."],
	["Whether it works", "The second line of the strip says whether the tomb can be finished, or the first thing wrong: touch the strip for all of it, and one way through step by step."],
]

var editor: TombEditor
## Which page is open ("" for none: the tomb and its bars), and what it was opened with.
var page := ""
var _arg := {}
# The pages under this one, to go back to: each [which, what with, how far down it was scrolled].
var _stack: Array = []
var _stale := true
var _shown_for := ""
var _number := 1

var _bar: VBoxContainer
var _acts: VBoxContainer
var _acts_for := ""
var _strip: Touch
var _doing: Label
var _verdict: Label
var _zoom: HBoxContainer
var _page: PanelContainer
var _head: HBoxContainer
var _scroll: Scroller
var _field: Control
# On a room's page, the two lines at its top: which room it is (or what has just been said), and whether the tomb works.
var _room_says: Label
var _room_verdict: Label


## Something to touch. It is given the fingers themselves, not the mouse they are also made into: a finger
## that comes down on one and is lifted on it presses it, and one that has dragged the page it is on has not.
class Touch extends PanelContainer:
	var key := ""
	var action: Callable
	var look := "plain"
	var disabled := false:
		set(value):
			if disabled != value:
				disabled = value
				_restyle()
	var _finger := -1
	var _down := false
	var _moved := 0.0

	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_STOP
		focus_mode = Control.FOCUS_NONE
		custom_minimum_size = Vector2(TombPhoneUI.TOUCH, TombPhoneUI.TOUCH)

	func _ready() -> void:
		_restyle()

	func _gui_input(event: InputEvent) -> void:
		if event is InputEventScreenTouch:
			var touch := event as InputEventScreenTouch
			if touch.pressed and _finger == -1:
				_finger = touch.index
				_moved = 0.0
				_down = not disabled
				_restyle()
			elif not touch.pressed and touch.index == _finger:
				var fire := _down and Rect2(Vector2.ZERO, size).has_point(touch.position)
				_finger = -1
				_down = false
				_restyle()
				var holder := _scroller()
				if holder:
					holder.let_go()
				if fire and action.is_valid():
					action.call()
			accept_event()
		elif event is InputEventScreenDrag and (event as InputEventScreenDrag).index == _finger:
			var drag := event as InputEventScreenDrag
			_moved += drag.relative.length()
			var holder := _scroller()
			if holder and _moved > TombPhoneUI.SLOP:
				if _down:
					_down = false
					_restyle()
				holder.drag(drag.relative.y)
			accept_event()

	func _notification(what: int) -> void:
		# (hidden with a finger still on it: that finger is forgotten)
		if what == NOTIFICATION_VISIBILITY_CHANGED and not is_visible_in_tree():
			_finger = -1
			_down = false
			_restyle()

	func _scroller() -> Scroller:
		var above := get_parent()
		while above:
			if above is Scroller:
				return above as Scroller
			above = above.get_parent()
		return null

	func set_look(to: String) -> void:
		if look != to:
			look = to
			_restyle()

	func _restyle() -> void:
		var box := StyleBoxFlat.new()
		box.set_corner_radius_all(14)
		box.set_content_margin_all(8.0)
		box.set_border_width_all(2)
		match look:
			"main":
				box.bg_color = Color(0.2, 0.36, 0.22, 0.97)
				box.border_color = Color(0.5, 0.82, 0.5)
			"chosen":
				box.bg_color = Color(0.3, 0.26, 0.12, 0.97)
				box.border_color = TombPhoneUI.GOLD
			"warn":
				box.bg_color = Color(0.36, 0.17, 0.14, 0.97)
				box.border_color = TombPhoneUI.BAD
			"strip":
				box.bg_color = Color(0.07, 0.075, 0.1, 0.9)
				box.border_color = Color(1.0, 1.0, 1.0, 0.22)
			_:
				box.bg_color = Color(0.15, 0.16, 0.2, 0.96)
				box.border_color = Color(1.0, 1.0, 1.0, 0.3)
		if _down:
			box.bg_color = box.bg_color.lightened(0.25)
			box.border_color = Color.WHITE
		add_theme_stylebox_override(&"panel", box)
		for child in get_children():
			if child is CanvasItem:
				(child as CanvasItem).modulate.a = 0.32 if disabled else 1.0


## A page's rows, dragged up and down with a finger (wherever it comes down: on a row, or between them).
## It has no bar to catch hold of: the mark at its right only shows how far down it is.
class Scroller extends Control:
	var rows: VBoxContainer
	var offset := 0.0
	var _finger := -1
	var _held := false
	var _speed := 0.0
	var _pulled := 0.0

	func _init() -> void:
		clip_contents = true
		mouse_filter = Control.MOUSE_FILTER_STOP
		size_flags_vertical = Control.SIZE_EXPAND_FILL
		size_flags_horizontal = Control.SIZE_EXPAND_FILL
		rows = VBoxContainer.new()
		rows.add_theme_constant_override(&"separation", int(TombPhoneUI.GAP))
		rows.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(rows)

	## How far down it can be taken.
	func most() -> float:
		return maxf(rows.size.y - size.y, 0.0)

	func drag(by: float) -> void:
		_held = true
		offset = clampf(offset - by, 0.0, most())
		_pulled -= by
		settle()

	func let_go() -> void:
		_held = false

	## Puts the rows where they belong for the width there is and how far down it is.
	func settle() -> void:
		var wide := maxf(size.x - 14.0, 10.0)
		if not is_equal_approx(rows.size.x, wide):
			rows.size.x = wide
		rows.size.y = 0.0
		offset = clampf(offset, 0.0, most())
		rows.position = Vector2(0.0, -roundf(offset))
		queue_redraw()

	# While a finger has it, how fast it is being dragged is kept (and is nothing once the finger is still); let
	# go of, it runs on at that and slows, and stops dead at either end.
	func _process(delta: float) -> void:
		if _held:
			_speed = lerpf(_speed, _pulled / maxf(delta, 0.001), 0.5)
			_pulled = 0.0
		elif absf(_speed) > 12.0:
			offset += _speed * delta
			_speed *= exp(-5.0 * delta)
			if offset <= 0.0 or offset >= most():
				_speed = 0.0
		else:
			_speed = 0.0
		settle()

	func _gui_input(event: InputEvent) -> void:
		if event is InputEventScreenTouch:
			var touch := event as InputEventScreenTouch
			if touch.pressed and _finger == -1:
				_finger = touch.index
				_speed = 0.0
			elif not touch.pressed and touch.index == _finger:
				_finger = -1
				let_go()
			accept_event()
		elif event is InputEventScreenDrag and (event as InputEventScreenDrag).index == _finger:
			drag((event as InputEventScreenDrag).relative.y)
			accept_event()
		elif event is InputEventMouseButton and (event as InputEventMouseButton).pressed:
			var button := event as InputEventMouseButton
			if button.button_index == MOUSE_BUTTON_WHEEL_UP:
				offset -= 90.0
			elif button.button_index == MOUSE_BUTTON_WHEEL_DOWN:
				offset += 90.0
			settle()

	func _draw() -> void:
		if most() <= 0.0:
			return
		var long := maxf(size.y * size.y / rows.size.y, 40.0)
		var at := (size.y - long) * offset / most()
		draw_rect(Rect2(size.x - 8.0, 0.0, 6.0, size.y), Color(1.0, 1.0, 1.0, 0.08))
		draw_rect(Rect2(size.x - 8.0, at, 6.0, long), Color(1.0, 1.0, 1.0, 0.55))


## A small picture, drawn with lines: what a button is for, beside or over its word.
class Icon extends Control:
	var kind := ""
	var colour := TombPhoneUI.INK

	func _init(what := "", across := 34.0) -> void:
		kind = what
		custom_minimum_size = Vector2(across, across)
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		size_flags_vertical = Control.SIZE_SHRINK_CENTER

	func _at(x: float, y: float) -> Vector2:
		return size * 0.5 + Vector2(x, y) * minf(size.x, size.y) * 0.5

	func _line(points: Array) -> void:
		var packed: PackedVector2Array = []
		for point: Array in points:
			packed.append(_at(point[0], point[1]))
		draw_polyline(packed, colour, maxf(minf(size.x, size.y) / 9.0, 3.0), true)

	func _fill(points: Array) -> void:
		var packed: PackedVector2Array = []
		for point: Array in points:
			packed.append(_at(point[0], point[1]))
		draw_colored_polygon(packed, colour)

	func _draw() -> void:
		var half := minf(size.x, size.y) * 0.5
		var thick := maxf(half / 4.5, 3.0)
		match kind:
			"play":
				_fill([[-0.6, -0.85], [0.85, 0.0], [-0.6, 0.85]])
			"undo", "redo":
				var way := -1.0 if kind == "undo" else 1.0
				_line([[way * 0.5, -0.45], [way * -0.2, -0.45], [way * -0.75, -0.2], [way * -0.75, 0.35], [way * -0.2, 0.6], [way * 0.6, 0.6]])
				_fill([[way * 0.95, -0.45], [way * 0.4, -0.9], [way * 0.4, 0.0]])
			"rooms":
				for x: float in [-0.95, -0.28, 0.4]:
					_line([[x, -0.3], [x + 0.55, -0.3], [x + 0.55, 0.3], [x, 0.3], [x, -0.3]])
			"tombs":
				_line([[-0.95, 0.75], [0.0, -0.8], [0.95, 0.75], [-0.95, 0.75]])
				_line([[0.0, 0.75], [0.0, 0.25]])
			"more":
				for x: float in [-0.65, 0.0, 0.65]:
					draw_circle(_at(x, 0.0), half * 0.2, colour)
			"edit":
				_fill([[-0.5, 0.8], [-0.8, 0.5], [0.45, -0.8], [0.8, -0.45]])
				_fill([[-0.55, 0.9], [-0.9, 0.55], [-0.98, 0.98]])
			"add":
				_line([[-0.8, 0.0], [0.8, 0.0]])
				_line([[0.0, -0.8], [0.0, 0.8]])
			"copy":
				_line([[-0.85, -0.3], [0.25, -0.3], [0.25, 0.85], [-0.85, 0.85], [-0.85, -0.3]])
				_line([[-0.3, -0.3], [-0.3, -0.85], [0.85, -0.85], [0.85, 0.3], [0.25, 0.3]])
			"earlier", "later", "back":
				var way := 1.0 if kind == "later" else -1.0
				_line([[way * -0.85, 0.0], [way * 0.8, 0.0]])
				_line([[way * 0.2, -0.6], [way * 0.85, 0.0], [way * 0.2, 0.6]])
			"remove":
				_line([[-0.8, -0.5], [0.8, -0.5]])
				_line([[-0.28, -0.5], [-0.28, -0.85], [0.28, -0.85], [0.28, -0.5]])
				_line([[-0.6, -0.5], [-0.48, 0.85], [0.48, 0.85], [0.6, -0.5]])
			"move":
				_line([[-0.9, 0.0], [0.9, 0.0]])
				_line([[0.0, -0.9], [0.0, 0.9]])
				for turn in 4:
					var out := Vector2.RIGHT.rotated(turn * PI * 0.5)
					var side := Vector2(-out.y, out.x)
					var tip := out * 0.95
					var a := out * 0.6 + side * 0.3
					var b := out * 0.6 - side * 0.3
					_line([[a.x, a.y], [tip.x, tip.y], [b.x, b.y]])
			"join":
				_line([[-0.95, -0.4], [-0.35, -0.4], [-0.35, 0.4], [-0.95, 0.4], [-0.95, -0.4]])
				_line([[0.35, -0.4], [0.95, -0.4], [0.95, 0.4], [0.35, 0.4], [0.35, -0.4]])
				_line([[-0.35, -0.12], [0.35, -0.12]])
				_line([[-0.35, 0.12], [0.35, 0.12]])
			"cancel":
				_line([[-0.7, -0.7], [0.7, 0.7]])
				_line([[-0.7, 0.7], [0.7, -0.7]])
			"list":
				for y: float in [-0.6, 0.0, 0.6]:
					_line([[-0.8, y], [0.8, y]])
			"nearer", "further":
				draw_arc(_at(-0.15, -0.15), half * 0.62, 0.0, TAU, 24, colour, thick, true)
				_line([[0.32, 0.32], [0.9, 0.9]])
				_line([[-0.48, -0.15], [0.18, -0.15]])
				if kind == "nearer":
					_line([[-0.15, -0.48], [-0.15, 0.18]])
			"all":
				for corner: Array in [[-1.0, -1.0], [1.0, -1.0], [1.0, 1.0], [-1.0, 1.0]]:
					var x: float = corner[0] * 0.85
					var y: float = corner[1] * 0.85
					_line([[x, y - corner[1] * 0.5], [x, y], [x - corner[0] * 0.5, y]])
			"minus":
				_line([[-0.8, 0.0], [0.8, 0.0]])
			"done":
				_line([[-0.75, 0.05], [-0.25, 0.6], [0.8, -0.6]])
			"chevron":
				_line([[-0.3, -0.6], [0.3, 0.0], [-0.3, 0.6]])


## A switch as it shows: on or off. (What is touched is the whole row it is in.)
class Knob extends Control:
	var on := false

	func _init(is_on := false) -> void:
		on = is_on
		custom_minimum_size = Vector2(104.0, 56.0)
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		size_flags_vertical = Control.SIZE_SHRINK_CENTER

	func _draw() -> void:
		var box := StyleBoxFlat.new()
		box.bg_color = Color(0.3, 0.62, 0.34) if on else Color(0.3, 0.3, 0.34)
		box.set_corner_radius_all(int(size.y * 0.5))
		draw_style_box(box, Rect2(Vector2.ZERO, size))
		draw_circle(Vector2(size.x - size.y * 0.5 if on else size.y * 0.5, size.y * 0.5), size.y * 0.5 - 6.0, TombPhoneUI.INK)


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_number = randi_range(1, 999999)

	_bar = VBoxContainer.new()
	_bar.add_theme_constant_override(&"separation", int(GAP))
	add_child(_bar)
	_bar.add_child(_tile("bar:play", "play", "Play", func() -> void: editor.play(), "main"))
	_bar.add_child(_tile("bar:undo", "undo", "Undo", func() -> void: editor.undo()))
	_bar.add_child(_tile("bar:redo", "redo", "Redo", func() -> void: editor.redo()))
	_bar.add_child(_tile("bar:rooms", "rooms", "Rooms", open.bind("rooms")))
	_bar.add_child(_tile("bar:tombs", "tombs", "Tombs", open.bind("tombs")))
	_bar.add_child(_tile("bar:more", "more", "More", open.bind("more")))

	_acts = VBoxContainer.new()
	_acts.add_theme_constant_override(&"separation", int(GAP))
	add_child(_acts)

	_strip = _touch("strip", open.bind("works"), "strip")
	var lines := VBoxContainer.new()
	lines.add_theme_constant_override(&"separation", -2)
	lines.alignment = BoxContainer.ALIGNMENT_CENTER
	_strip.add_child(lines)
	_doing = _words("", TEXT, INK, true)
	_doing.max_lines_visible = 3
	lines.add_child(_doing)
	_verdict = _words("", TEXT, GOOD, false)
	lines.add_child(_verdict)
	_quiet(_strip)
	add_child(_strip)

	_zoom = HBoxContainer.new()
	_zoom.add_theme_constant_override(&"separation", int(GAP))
	add_child(_zoom)
	_zoom.add_child(_tile("zoom:further", "further", "", func() -> void: editor.zoom(1.33)))
	_zoom.add_child(_tile("zoom:all", "all", "", func() -> void: editor.look_at_all()))
	_zoom.add_child(_tile("zoom:nearer", "nearer", "", func() -> void: editor.zoom(0.75)))

	_page = PanelContainer.new()
	_page.mouse_filter = Control.MOUSE_FILTER_STOP
	_page.visible = false
	add_child(_page)
	var down := VBoxContainer.new()
	down.add_theme_constant_override(&"separation", int(GAP))
	_page.add_child(down)
	_head = HBoxContainer.new()
	_head.add_theme_constant_override(&"separation", int(GAP))
	_head.custom_minimum_size.y = TOUCH
	down.add_child(_head)
	_scroll = Scroller.new()
	down.add_child(_scroll)
	resized.connect(_place)
	_place()


# --- What the tools and the editor ask of it

## Something has changed: what is on the screen is made again (at the next frame, not under the finger that did it).
func refresh() -> void:
	_stale = true


## Opens a page: over the one that is open (which Back then comes back to) if `over`, or in place of it.
func open(which: String, with := {}, over := false) -> void:
	if over and page != "":
		_stack.append([page, _arg, _scroll.offset])
	else:
		_stack.clear()
	if which not in ["places", "joins"] and not over:
		editor.mode = ""
	page = which
	_arg = with
	_shown_for = ""
	_stale = true
	if which == "room":
		_place()
		editor.look_at_room(editor.chosen)


## The page under this one, or the tomb if there is none.
func back() -> void:
	if _stack.is_empty():
		close()
		return
	var under: Array = _stack.pop_back()
	page = under[0]
	_arg = under[1]
	_shown_for = _stamp()
	_scroll.offset = under[2]
	_stale = true


## Back to the tomb and its bars.
func close() -> void:
	var was := page
	page = ""
	_arg = {}
	_stack.clear()
	_stale = true
	_place()
	if was in ["room", "choice"]:
		editor.look_at_room(editor.chosen)


## The part of the screen the tomb is seen in: between the bars, or beside a room's page.
func open_rect() -> Rect2:
	var whole := Rect2(Vector2.ZERO, editor._pad.size)
	var mine := get_global_rect()
	if page == "":
		return Rect2(mine.position.x + COLUMN + GAP, mine.position.y + TOUCH + GAP, mine.size.x - 2.0 * (COLUMN + GAP), mine.size.y - 2.0 * (TOUCH + GAP))
	if _beside():
		return Rect2(0.0, 0.0, mine.end.x - _page_wide(), whole.size.y)
	return whole


## Everything that can be touched and is on the screen now: each `Touch`, and the two places words are typed.
func touches() -> Array[Control]:
	var found: Array[Control] = []
	_gather(self, found)
	return found


## The thing to touch that goes by that name, if it is there (on the screen or scrolled off it).
func find(key: String) -> Touch:
	return _find_in(self, key)


## The rows of the page that is open, and how far down they are.
func scroller() -> Scroller:
	return _scroll


## The line that says what is chosen and what a touch will do, and the line that says whether it works.
func says() -> Array[String]:
	return [_doing.text, _verdict.text]


## The places the chosen room could be moved to, as a list (those under one mark on the plan, or all of them).
func open_places(only: Array = []) -> void:
	open("places", {"only": only})


func _gather(node: Node, found: Array[Control]) -> void:
	for child in node.get_children():
		var control := child as Control
		if control == null or not control.visible:
			continue
		if control is Touch or control is LineEdit or control is TextEdit or control is BaseButton or control is Range:
			if not _scrolled_away(control):
				found.append(control)
		_gather(child, found)


func _find_in(node: Node, key: String) -> Touch:
	for child in node.get_children():
		if child is Control and not (child as Control).visible:
			continue
		if child is Touch and (child as Touch).key == key:
			return child as Touch
		var deeper := _find_in(child, key)
		if deeper:
			return deeper
	return null


# Whether a row has been scrolled off the part of its page that shows.
func _scrolled_away(control: Control) -> bool:
	if not _scroll.is_ancestor_of(control):
		return false
	return not _scroll.get_global_rect().intersects(control.get_global_rect())


# --- Keeping it in order

func _process(_delta: float) -> void:
	if editor == null:
		return
	if _stamp() != _shown_for:
		_stale = true
	if _stale:
		_fill()
	_page.visible = page != ""
	for part: Control in [_bar, _acts, _strip, _zoom]:
		part.visible = page == ""
	if page == "room":
		_say_of_room()
	if page != "":
		return
	_doing.text = _doing_now()
	var verdict := verdict_now()
	_verdict.text = verdict[0]
	_verdict.add_theme_color_override(&"font_color", verdict[1])
	_strip.size = Vector2(_strip.size.x, 0.0)
	_show_acts()
	(find("bar:undo") as Touch).disabled = editor._undo.is_empty()
	(find("bar:redo") as Touch).disabled = editor._redo.is_empty()


# What a page is of: when this changes under it, the page is made again from the top.
func _stamp() -> String:
	return "%s|%d|%s|%s" % [page, editor.chosen if page in ["room", "choice"] else 0, editor.spec.get("name", ""), editor._floor]


func _place() -> void:
	if _bar == null:
		return
	var tall := 6.0 * TOUCH + 5.0 * GAP
	_bar.position = Vector2(0.0, maxf((size.y - tall) * 0.5, 0.0))
	_bar.size = Vector2(COLUMN, 0.0)
	_acts.position = Vector2(size.x - COLUMN, _bar.position.y)
	_acts.size = Vector2(COLUMN, 0.0)
	_strip.position = Vector2(COLUMN + GAP, 0.0)
	_strip.size = Vector2(size.x - 2.0 * (COLUMN + GAP), 0.0)
	_zoom.size = Vector2.ZERO
	_zoom.position = Vector2((size.x - (3.0 * TOUCH + 2.0 * GAP)) * 0.5, size.y - TOUCH)
	var box := StyleBoxFlat.new()
	box.bg_color = Color(0.075, 0.078, 0.1)
	# (it goes on out to the edges of the screen, past where anything in it may stand)
	box.expand_margin_right = 120.0
	box.expand_margin_top = 80.0
	box.expand_margin_bottom = 80.0
	if _beside():
		var wide := _page_wide()
		_page.position = Vector2(size.x - wide, 0.0)
		_page.size = Vector2(wide, size.y)
		box.content_margin_left = 20.0
		box.border_width_left = 3
		box.border_color = Color(1.0, 0.86, 0.45, 0.7)
	else:
		_page.position = Vector2.ZERO
		_page.size = size
		box.expand_margin_left = 120.0
	_page.add_theme_stylebox_override(&"panel", box)


# Whether the page that is open leaves the tomb showing beside it: a room's, and a choice of something of a room's.
func _beside() -> bool:
	return page == "room" or (page == "choice" and not _stack.is_empty() and _stack[0][0] == "room")


func _page_wide() -> float:
	return clampf(size.x - SLIVER, 640.0, PAGE_MOST)


# --- The strip: what is happening

func _doing_now() -> String:
	if Time.get_ticks_msec() * 0.001 < editor._hint_until:
		return editor._hint
	var title := TombSpec.room_title(editor.spec, editor.chosen)
	match editor.mode:
		"move":
			return "Moving %s: touch a place marked \"here\", or List." % title
		"join":
			return "Joining %s: touch a room marked \"join\" or \"unjoin\", or List." % title
	if editor._floor:
		if TombFloorSpec.free_sides(editor.spec, editor.chosen).is_empty():
			return "%s is chosen. Touch another room, or Edit to change it." % title
		return "%s is chosen. Touch a + to add a room, or Edit to change it." % title
	return "%s is chosen. Touch another room, or Edit to change it." % title


## Whether the tomb can be finished, in a line, and the colour to say it in.
func verdict_now() -> Array:
	var found := editor.found
	if editor._dirty >= 0.0:
		return ["Working it out...", DIM]
	var problems: PackedStringArray = found.get("problems", PackedStringArray())
	if not problems.is_empty():
		return ["Cannot be built yet%s: %s" % ["" if problems.size() == 1 else " (%d things)" % problems.size(), problems[0]], BAD]
	var warnings: PackedStringArray = found.get("warnings", PackedStringArray())
	if not found.get("ok", false):
		return [String(found.get("says", "")), CARE]
	if not warnings.is_empty():
		return ["Can be finished, but take care: %s." % warnings[0], CARE]
	return [String(found.get("says", "")), GOOD]


# --- The buttons of the chosen room, down the right

func _show_acts() -> void:
	var e := editor
	var wanted := "%s|%s" % [e._floor, e.mode]
	if wanted != _acts_for:
		_acts_for = wanted
		_empty(_acts)
		if e.mode != "":
			_acts.add_child(_tile("act:cancel", "cancel", "Cancel", func() -> void: editor.start(editor.mode)))
			_acts.add_child(_tile("act:list", "list", "List", func() -> void: open("places" if editor.mode == "move" else "joins")))
		else:
			_acts.add_child(_tile("act:edit", "edit", "Edit", open.bind("room"), "chosen"))
			_acts.add_child(_tile("act:add", "add", "Add", _add))
			if e._floor:
				_acts.add_child(_tile("act:move", "move", "Move", func() -> void: editor.start("move")))
				_acts.add_child(_tile("act:join", "join", "Join", func() -> void: editor.start("join")))
			else:
				_acts.add_child(_tile("act:copy", "copy", "Copy", func() -> void: editor.copy()))
				_acts.add_child(_tile("act:earlier", "earlier", "Earlier", func() -> void: editor.move(-1)))
				_acts.add_child(_tile("act:later", "later", "Later", func() -> void: editor.move(1)))
			_acts.add_child(_tile("act:remove", "remove", "Remove", func() -> void: editor.remove()))
		var tall := _acts.get_child_count() * (TOUCH + GAP) - GAP
		_acts.position = Vector2(size.x - COLUMN, maxf((size.y - tall) * 0.5, 0.0))
		_acts.size = Vector2(COLUMN, 0.0)
	if e.mode != "":
		return
	var count := e.rooms().size()
	var middle := e._is_middle(e.chosen)
	if e._floor:
		(find("act:add") as Touch).disabled = TombFloorSpec.free_sides(e.spec, e.chosen).is_empty()
		for key: String in ["act:move", "act:join", "act:remove"]:
			(find(key) as Touch).disabled = e.chosen == 0
	else:
		(find("act:add") as Touch).disabled = count >= TombSpec.MOST
		(find("act:copy") as Touch).disabled = not middle or count >= TombSpec.MOST
		(find("act:earlier") as Touch).disabled = not middle or not e._is_middle(e.chosen - 1)
		(find("act:later") as Touch).disabled = not middle or not e._is_middle(e.chosen + 1)
		(find("act:remove") as Touch).disabled = not middle or count <= TombSpec.FEWEST


# Add: after the chosen room; or, on a floor plan, off its one free side, or the side chosen from a list.
func _add() -> void:
	if not editor._floor:
		editor.add_after()
		return
	var sides := TombFloorSpec.free_sides(editor.spec, editor.chosen)
	if sides.size() <= 1:
		editor.add_after()
	else:
		open("sides")


# --- Pages

func _fill() -> void:
	_stale = false
	# (a choice of something of a room's is of the room it was opened on: if another has been chosen since, it is left)
	if page == "choice" and int(_arg.get("room", editor.chosen)) != editor.chosen:
		back()
	var keep := _scroll.offset if _stamp() == _shown_for else 0.0
	_shown_for = _stamp()
	_place()
	_empty(_head)
	_empty(_scroll.rows)
	_field = null
	if page == "":
		return
	match page:
		"room":
			_fill_room()
		"choice":
			_fill_choice()
		"rooms":
			_fill_rooms()
		"tombs":
			_fill_tombs()
		"name":
			_fill_name()
		"generator":
			_fill_generator()
		"share":
			_fill_share()
		"more":
			_fill_more()
		"works":
			_fill_works()
		"help":
			_fill_help()
		"ask":
			_fill_ask()
		"sides":
			_fill_sides()
		"places":
			_fill_places()
		"joins":
			_fill_joins()
	_quiet(_head)
	_quiet(_scroll.rows)
	_scroll.offset = keep
	_scroll.settle()


# The top of a page: what it is, and at the right, as on every page, the way out of it.
func _top(title: String) -> void:
	var heading := _words(title, TITLE, INK, false)
	heading.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	heading.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_head.add_child(heading)
	_way_out()


func _way_out() -> void:
	var out := _wide("page:done", "back" if not _stack.is_empty() else "done", "Back" if not _stack.is_empty() else "Done", back if not _stack.is_empty() else close, "main")
	out.custom_minimum_size.x = 170.0
	_head.add_child(out)


func _fill_room() -> void:
	var e := editor
	var count := e.rooms().size()
	var index := e.chosen
	var told: Dictionary = e.rooms()[index]
	var floor := e._floor
	var burial: bool = told["role"] == "burial" if floor else index == count - 1
	var middle := index > 0 and not burial

	var before := _tile("page:prev", "earlier", "", _step.bind(-1))
	before.disabled = index == 0
	_head.add_child(before)
	var after := _tile("page:next", "later", "", _step.bind(1))
	after.disabled = index == count - 1
	_head.add_child(after)
	var whether := _touch("page:verdict", open.bind("works", {}, true), "strip")
	whether.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var lines := VBoxContainer.new()
	lines.add_theme_constant_override(&"separation", -2)
	lines.alignment = BoxContainer.ALIGNMENT_CENTER
	whether.add_child(lines)
	_room_says = _words("", TEXT, GOLD, false)
	lines.add_child(_room_says)
	_room_verdict = _words("", TEXT, GOOD, false)
	lines.add_child(_room_verdict)
	_say_of_room()
	_head.add_child(whether)
	_way_out()

	# What it is.
	_section("What it is")
	if middle:
		var roles: Array = []
		for role: String in TombSpec.MIDDLE_ROLES:
			roles.append([role, TombSpec.ROLE_TITLES[role], ROLE_NOTES[role]])
		_row("row:role", "What it is", TombSpec.ROLE_TITLES[told["role"]], ROLE_NOTES.get(told["role"], ""), func() -> void:
			_pick("What is this room?", roles, TombSpec.MIDDLE_ROLES.find(told["role"]), func(picked: int) -> void: editor.set_value("role", TombSpec.MIDDLE_ROLES[picked])))
	else:
		_say("The burial chamber: the falcon is here, at its far end." if burial else "The entrance: out of doors, where he starts and where he has to get back to.")

	# What is in it.
	if index > 0:
		_section("What is in it")
		_switch("switch:dark", "Dark", "No torches on its walls.", told["dark"], func() -> void: editor.set_value("dark", not told["dark"]))
		if burial:
			_switch("switch:apophis", "Apophis", TombSpec.APOPHIS_NOTE, told.get("apophis", false), func() -> void: editor.set_value("apophis", not told.get("apophis", false)))
		if not burial:
			_switch("switch:pit", "A pit to jump", "A pit across the floor, narrow enough to jump.", told["pit"], func() -> void: editor.set_value("pit", not told["pit"]))
		var mummies: Array = [["none", "None", "Nothing wakes in this room."]]
		for kind in TombSpec.MUMMY_TITLES.size():
			mummies.append([str(kind), TombSpec.MUMMY_TITLES[kind], MUMMY_NOTES[kind]])
		var mummy := int(told["mummy"])
		_row("row:mummy", "A mummy", mummies[mummy + 1][1], ("It guards the falcon, and wakes when the falcon is taken. " if burial and mummy >= 0 else "") + String(mummies[mummy + 1][2]), func() -> void:
			_pick("Which mummy is in this room?", mummies, mummy + 1, func(picked: int) -> void: editor.set_value("mummy", picked - 1)))
		if mummy >= 0:
			var barriers: Array = TombSpec.BARRIER_TITLES.keys()
			var held: Array = []
			for key: String in barriers:
				held.append([key, TombSpec.BARRIER_TITLES[key], BARRIER_NOTES[key]])
			var barrier := maxi(barriers.find(told["barrier"]), 0)
			_row("row:barrier", "Held back by", held[barrier][1], held[barrier][2], func() -> void:
				_pick("What holds the mummy back?", held, barrier, func(picked: int) -> void: editor.set_value("barrier", barriers[picked])))
	_section("Lying here, to be carried")
	for what: String in TombSpec.THINGS:
		var now := int(told.get(what, 0))
		_stepper("step:" + what, TombSpec.THING_TITLES[what], now, 0, 3, func(to: int) -> void: editor.set_value(what, to))
	if (index > 0) if floor else (not burial):
		_fill_way()
	if floor:
		_fill_second_ways()


# The way: on from the chosen room (a tomb down one axis), or into it (a floor plan); and what locks it.
func _fill_way() -> void:
	var e := editor
	var count := e.rooms().size()
	var index := e.chosen
	var told: Dictionary = e.rooms()[index]
	var floor := e._floor
	var from := int(told.get("from", 0)) if floor else index
	if floor:
		_section("The way in, from %s" % TombSpec.room_title(e.spec, from))
	else:
		_section("The way on, to %s" % TombSpec.room_title(e.spec, index + 1))
	var ways: Array = ["open", "stairs"] if from == 0 else TombSpec.WAYS
	var way_rows: Array = []
	for way: String in ways:
		way_rows.append([way, TombSpec.WAY_TITLES[way], WAY_SAYS[way]])
	_row("row:way", "How it is got into" if floor else "The way on", TombSpec.WAY_TITLES[told["way"]], TombSpec.WAY_NOTES.get(told["way"], WAY_SAYS[told["way"]]), func() -> void:
		_pick("How is this room got into?" if floor else "How is the next room got to?", way_rows, maxi(ways.find(told["way"]), 0), func(picked: int) -> void: editor.set_value("way", ways[picked])))
	if from == 0:
		return
	var sand: bool = told["way"] == "sand"
	var locks: Array = TombFloorSpec.LOCKS if floor else TombSpec.LOCKS
	var titles: Dictionary = TombFloorSpec.LOCK_TITLES if floor else TombSpec.LOCK_TITLES
	var notes: Dictionary = TombFloorSpec.LOCK_NOTES if floor else TombSpec.LOCK_NOTES
	var lock_rows: Array = []
	for lock: String in locks:
		if lock == "none":
			lock_rows.append([lock, "A seal stone at the foot of the face" if sand else "No door", "Trodden on, it lets the sand in." if sand else "The way is open."])
		else:
			lock_rows.append([lock, titles[lock], notes[lock]])
	var lock := maxi(locks.find(told["lock"]), 0)
	var asks := "What lets the sand in" if sand else ("What opens its door" if floor else "What opens the door on")
	_row("row:lock", asks, lock_rows[lock][1], lock_rows[lock][2], func() -> void:
		_pick(asks + "?", lock_rows, lock, func(picked: int) -> void: editor.set_value("lock", locks[picked])))
	if floor and told["lock"] in ["work", "brazier", "offering", "gaze_work"]:
		var others: Array = []
		var other_rows: Array = []
		for i in range(1, count):
			others.append(i)
			other_rows.append([str(i), TombSpec.room_title(e.spec, i) + (" (where the door is)" if i == from else ""), room_says(i)])
		var held_in := int(told.get("lock_in", -1))
		var at := maxi(others.find(from if held_in < 0 else held_in), 0)
		_row("row:lock_in", "It stands in", other_rows[at][1], "The room its block and plate, brazier or table are in: any room of the tomb.", func() -> void:
			_pick("Which room does it stand in?", other_rows, at, func(picked: int) -> void: editor.set_value("lock_in", others[picked])))
	elif TombSpec.host_kind(told["lock"]) != "":
		var hosts: Array = e._hosts_on_floor(told["lock"]) if floor else e._hosts(told["lock"])
		if hosts.is_empty():
			if TombSpec.host_kind(told["lock"]) == "below":
				_say("There is no well in this tomb: make one of the rooms a well." if floor else "There is no well at or before this room: make one of the rooms a well.", BAD)
			else:
				_say("There is no room to put a loft over.", BAD)
		else:
			var host_rows: Array = []
			for host: int in hosts:
				host_rows.append([str(host), TombSpec.room_title(e.spec, host), room_says(host)])
			var at := maxi(hosts.find(int(told["stone_in"])), 0)
			var where: String = TombSpec.host_title(told["lock"])
			_row("row:stone_in", where, host_rows[at][1], "", func() -> void:
				_pick(where + " which room?", host_rows, at, func(picked: int) -> void: editor.set_value("stone_in", hosts[picked])))


# The chosen room's second ways (a floor plan): each with how it is got along, its door, and taking it away.
func _fill_second_ways() -> void:
	var e := editor
	var index := e.chosen
	# Its second ways.
	var joins := TombFloorSpec.joins_of(e.spec, index)
	for n in joins.size():
		var join: Dictionary = joins[n]
		var other := int(join["b"]) if int(join["a"]) == index else int(join["a"])
		_section("A second way, to %s" % TombSpec.room_title(e.spec, other))
		var join_rows: Array = []
		for way: String in TombFloorSpec.JOIN_WAYS:
			join_rows.append([way, TombSpec.WAY_TITLES[way], WAY_SAYS[way]])
		_row("row:join%d:way" % n, "How it is got along", TombSpec.WAY_TITLES[join["way"]], WAY_SAYS[join["way"]], func() -> void:
			_pick("How is the second way got along?", join_rows, maxi(TombFloorSpec.JOIN_WAYS.find(join["way"]), 0), func(picked: int) -> void: editor.set_join(join, "way", TombFloorSpec.JOIN_WAYS[picked])))
		var ends: Array = [int(join["a"]), int(join["b"])]
		var door_rows: Array = [["none", "No door", "Open both ways."]]
		for end: int in ends:
			door_rows.append([str(end), "Opens only from %s" % TombSpec.room_title(e.spec, end), "A seal stone just inside that room opens it: a short cut back."])
		var door := 0 if join["lock"] != "within" else 1 + maxi(ends.find(int(join["seal"])), 0)
		_row("row:join%d:door" % n, "Its door", door_rows[door][1], door_rows[door][2], func() -> void:
			_pick("What door has the second way?", door_rows, door, func(picked: int) -> void: editor.set_join_door(join, ends[maxi(picked - 1, 0)], picked > 0)))
		_scroll.rows.add_child(_wide("row:join%d:away" % n, "remove", "Take this way away", func() -> void: editor.join_with(other), "warn"))



# The two lines at the top of a room's page, as they now are.
func _say_of_room() -> void:
	if not is_instance_valid(_room_says) or not is_instance_valid(_room_verdict):
		return
	var hinting := Time.get_ticks_msec() * 0.001 < editor._hint_until
	_room_says.text = editor._hint if hinting else "%s  (room %d of %d)" % [TombSpec.room_title(editor.spec, editor.chosen), editor.chosen + 1, editor.rooms().size()]
	_room_says.add_theme_color_override(&"font_color", INK if hinting else GOLD)
	var verdict := verdict_now()
	_room_verdict.text = verdict[0]
	_room_verdict.add_theme_color_override(&"font_color", verdict[1])

# The room before (-1) or after (1), without leaving the page.
func _step(by: int) -> void:
	editor.choose(editor.chosen + by)
	editor.look_at_room(editor.chosen)


## What is in a room and how it is got on from (or into), in a line.
func room_says(index: int) -> String:
	var told: Dictionary = editor.rooms()[index]
	var parts: PackedStringArray = []
	if told.get("dark", false):
		parts.append("dark")
	if told.get("pit", false):
		parts.append("a pit")
	if int(told.get("mummy", -1)) >= 0:
		parts.append("a %s" % String(TombSpec.MUMMY_TITLES[int(told["mummy"])]).to_lower())
	for what: String in TombSpec.THINGS:
		var lying := int(told.get(what, 0))
		if lying > 0:
			parts.append("%d %s" % [lying, String(TombSpec.THING_TITLES[what]).to_lower()] if lying > 1 else String(TombSpec.THING_TITLES[what]).to_lower())
	var last := index == editor.rooms().size() - 1
	if (editor._floor and index > 0) or (not editor._floor and not last):
		var way := String(TombSpec.WAY_TITLES.get(told.get("way", "open"), "")).to_lower()
		parts.append(("way in: %s" if editor._floor else "way on: %s") % way)
		if told.get("lock", "none") != "none":
			parts.append("door: %s" % String(TombFloorSpec.LOCK_TITLES.get(told["lock"], "")).to_lower())
	var line := ", ".join(parts)
	return "Nothing in it." if parts.is_empty() else line.left(1).to_upper() + line.substr(1) + "."


func _pick(title: String, options: Array, now: int, picked: Callable) -> void:
	open("choice", {"title": title, "options": options, "now": now, "picked": picked, "room": editor.chosen}, true)


func _fill_choice() -> void:
	_top(_arg["title"])
	var options: Array = _arg["options"]
	var picked: Callable = _arg["picked"]
	for i in options.size():
		var option: Array = options[i]
		var row := _touch("choice:" + String(option[0]), func() -> void:
			back()
			picked.call(i), "chosen" if i == int(_arg["now"]) else "plain")
		var across := HBoxContainer.new()
		across.add_theme_constant_override(&"separation", 16)
		row.add_child(across)
		var tick := Icon.new("done" if i == int(_arg["now"]) else "", 40.0)
		tick.colour = GOLD
		across.add_child(tick)
		across.add_child(_two_lines(option[1], option[2]))
		_scroll.rows.add_child(row)


func _fill_rooms() -> void:
	_top("The rooms of %s" % editor.spec.get("name", ""))
	for i in editor.rooms().size():
		var across := HBoxContainer.new()
		across.add_theme_constant_override(&"separation", int(GAP))
		_scroll.rows.add_child(across)
		var go := _touch("room:%d" % i, func() -> void:
			editor.choose(i)
			close(), "chosen" if i == editor.chosen else "plain")
		go.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		go.add_child(_two_lines(TombSpec.room_title(editor.spec, i), room_says(i)))
		across.add_child(go)
		var change := _wide("room:%d:edit" % i, "edit", "Edit", func() -> void:
			editor.choose(i)
			open("room"))
		change.custom_minimum_size.x = 170.0
		across.add_child(change)
	_say("Touch a room to go to it, or Edit to change it. Add, at the right of the tomb, puts a new room after the chosen one.")


func _fill_tombs() -> void:
	_top("Your tombs")
	var name: String = editor.spec.get("name", "")
	_row("tombs:name", "This one is called", name, "Touch to give it another name.", open.bind("name", {}, true))
	_row("tombs:new", "A new tomb", "", "A line of rooms, seen from the side: an entrance, a corridor, an antechamber and the burial chamber.", func() -> void:
		editor.new_tomb(false)
		close())
	_row("tombs:new_branching", "A new tomb that branches", "", "Rooms on a floor plan, seen from overhead, with ways off to the side.", func() -> void:
		editor.new_tomb(true)
		close())
	_row("tombs:generator", "One of the generator's, to change", "", "A whole tomb made from a number, at any of three difficulties, of either shape.", open.bind("generator", {}, true))
	_row("tombs:copy", "Copy this one", "", "A second tomb like this one, under another name, to change without losing this.", func() -> void:
		editor.copy_tomb(name)
		close())
	_row("tombs:share", "This tomb as text", "", "Copy it out to keep it somewhere else or to send it; or paste one in.", open.bind("share", {}, true))
	var others: Array = TombSpec.names().filter(func(other: String) -> bool: return other != name) if TombEditor.keeps else []
	_section("The others kept on this device" if not others.is_empty() else "No others are kept on this device")
	for other: String in others:
		var across := HBoxContainer.new()
		across.add_theme_constant_override(&"separation", int(GAP))
		_scroll.rows.add_child(across)
		var kept := TombSpec.open(other)
		var go := _touch("tomb:" + other, func() -> void:
			editor.open_tomb(other)
			close())
		go.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var shape := "a floor plan" if TombSpec.is_branching(kept) else "a line"
		go.add_child(_two_lines(other, "%d rooms, %s. Touch to open it." % [(kept.get("rooms", []) as Array).size(), shape]))
		across.add_child(go)
		var twin := _wide("tomb:%s:copy" % other, "copy", "Copy", func() -> void:
			editor.copy_tomb(other)
			close())
		twin.custom_minimum_size.x = 160.0
		across.add_child(twin)
		var forget := _wide("tomb:%s:forget" % other, "remove", "Forget", func() -> void:
			open("ask", {"title": "Forget %s?" % other, "says": "It is taken off this device for good: Undo does not bring a tomb back.", "yes": "Forget it", "no": "Keep it",
				"do": func() -> void: editor.forget_tomb(other)}, true), "warn")
		forget.custom_minimum_size.x = 180.0
		across.add_child(forget)


func _fill_name() -> void:
	_top("What is this tomb called?")
	var across := HBoxContainer.new()
	across.add_theme_constant_override(&"separation", int(GAP))
	_scroll.rows.add_child(across)
	var field := LineEdit.new()
	field.name = "Name"
	field.text = editor.spec.get("name", "")
	field.custom_minimum_size = Vector2(200.0, TOUCH)
	field.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	field.add_theme_font_size_override(&"font_size", TITLE)
	field.max_length = 40
	field.select_all_on_focus = true
	across.add_child(field)
	_field = field
	var use := func(_text := "") -> void:
		field.release_focus()
		editor.rename(field.text)
		back()
	field.text_submitted.connect(use)
	var done := _wide("name:use", "done", "Use this name", use, "main")
	done.custom_minimum_size.x = 280.0
	across.add_child(done)
	_say("Touch the name to type another. It stays at the top of the screen, over the keyboard.")


func _fill_generator() -> void:
	_top("One of the generator's")
	_say("Every number is a different tomb, and the same one every time. Choose a number, then how hard and which shape: it opens as a tomb of yours, to change.")
	_stepper("gen", "Number", _number, 1, 999999, func(to: int) -> void:
		_number = to
		refresh())
	_scroll.rows.add_child(_wide("gen:any", "", "Any other number", func() -> void:
		_number = randi_range(1, 999999)
		refresh()))
	_section("A line of rooms, seen from the side")
	for level in 3:
		_row("gen:line:%d" % level, TombGenerator.DIFFICULTY_NAMES[level], "", ["Four or five rooms and a lock or two.", "More rooms, more locks, a mummy or two.", "The longest, with the most to work out."][level], func() -> void:
			editor.from_number(_number, level, false)
			close())
	_section("A tomb that branches, on a floor plan")
	for level in 3:
		_row("gen:branching:%d" % level, TombGenerator.DIFFICULTY_NAMES[level], "", ["A short way in and a side room or two.", "Side chambers that hold what a door further on wants.", "The most rooms, with dead ends and loops."][level], func() -> void:
			editor.from_number(_number, level, true)
			close())


func _fill_share() -> void:
	_top("This tomb as text")
	var text := TextEdit.new()
	text.name = "Text"
	var across := HBoxContainer.new()
	across.add_theme_constant_override(&"separation", int(GAP))
	_scroll.rows.add_child(across)
	var copy := _wide("share:copy", "copy", "Copy", func() -> void:
		DisplayServer.clipboard_set(text.text)
		editor._say("Copied: paste it wherever you keep or send such things.", 4.0)
		_note_share("Copied."))
	var paste := _wide("share:paste", "", "Paste", func() -> void:
		text.text = DisplayServer.clipboard_get()
		_note_share("Pasted. Use this text brings it in." if text.text != "" else "Nothing came: touch the text and paste with the keyboard."))
	var use := _wide("share:use", "done", "Use this text", func() -> void:
		if editor.use_text(text.text):
			close()
		else:
			_note_share("That text is not a tomb."), "main")
	for button: Touch in [copy, paste, use]:
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		across.add_child(button)
	text.text = TombSpec.to_text(editor.spec)
	text.custom_minimum_size = Vector2(200.0, 230.0)
	text.add_theme_font_size_override(&"font_size", TEXT)
	text.wrap_mode = TextEdit.LINE_WRAPPING_BOUNDARY
	text.scroll_fit_content_height = false
	_scroll.rows.add_child(text)
	_field = text
	var says := _words("Copy takes all of it. To bring one in: Paste (or touch the text, clear it and paste with the keyboard), then Use this text. The tomb keeps its own name.", TEXT, DIM, true)
	says.name = "Says"
	_scroll.rows.add_child(says)


func _note_share(said: String) -> void:
	var says := _scroll.rows.get_node_or_null(^"Says") as Label
	if says:
		says.text = said
		says.add_theme_color_override(&"font_color", GOLD)


func _fill_more() -> void:
	_top("More")
	if editor._dirty >= 0.0:
		editor.rebuild()
	if not editor._floor:
		_row("more:walk", "Walk it", "", "Play it walked through, the camera at his back. (Play, at the left, plays it from the side.)", func() -> void:
			close()
			editor.play("3d"))
	_row("more:way", "Whether it works, and one way through", "", String(verdict_now()[0]), open.bind("works", {}, true))
	_row("more:sizes", "Other sizes for the rooms", "", "Every room is cut to another size; nothing else changes. Undo puts them back.", func() -> void:
		editor.other_sizes()
		close())
	_row("more:share", "This tomb as text", "", "Copy it out to keep or send, or paste one in.", open.bind("share", {}, true))
	_row("more:help", "How this works", "", "What each touch and each button does.", open.bind("help", {}, true))
	_row("more:leave", "Leave", "", "Back to the tombs. This one is kept as it is.", func() -> void: editor.leave(), "warn")


func _fill_works() -> void:
	_top("Whether it works")
	var e := editor
	if e._dirty >= 0.0:
		e.rebuild()
	var found := e.found
	var verdict := verdict_now()
	var problems: PackedStringArray = found.get("problems", PackedStringArray())
	var warnings: PackedStringArray = found.get("warnings", PackedStringArray())
	if problems.is_empty():
		_say(String(found.get("says", "")), verdict[1], TITLE)
	else:
		_say("It cannot be built yet. Touch one to go to its room:" if problems.size() > 1 else "It cannot be built yet. Touch it to go to its room:", BAD, TITLE)
	for n in problems.size():
		_trouble("problem:%d" % n, problems[n], "warn")
	for n in warnings.size():
		_trouble("warning:%d" % n, "Take care: %s." % warnings[n], "plain")
	var steps: Array = (found.get("solved", {}) as Dictionary).get("steps", [])
	if not steps.is_empty():
		_section("One way through (the shortest)")
		var lines: PackedStringArray = []
		for i in steps.size():
			lines.append("%d.  %s" % [i + 1, TombSpec.step_words(e.spec, found["plan"], steps[i])])
		_say("\n".join(lines), INK)
	elif problems.is_empty():
		_say("Every order he could do things in was tried (%d positions)." % int((found.get("solved", {}) as Dictionary).get("positions", 0)))


# Something wrong, as a row: a touch goes to the room it is about.
func _trouble(key: String, text: String, look: String) -> void:
	var room := editor.room_of(text)
	var row := _touch(key, func() -> void:
		if room >= 0:
			editor.choose(room)
		close(), look)
	row.add_child(_two_lines(text, "Touch to go to %s." % TombSpec.room_title(editor.spec, room) if room >= 0 else "Touch to go back to the tomb."))
	_scroll.rows.add_child(row)


func _fill_help() -> void:
	_top("How this works")
	for part: Array in (HELP_FLOOR if editor._floor else HELP):
		_section(part[0])
		_say(part[1], INK)


func _fill_ask() -> void:
	_top(_arg["title"])
	_say(_arg["says"], INK)
	var across := HBoxContainer.new()
	across.add_theme_constant_override(&"separation", int(GAP))
	_scroll.rows.add_child(across)
	var do: Callable = _arg["do"]
	var yes := _wide("ask:yes", "remove", _arg["yes"], func() -> void:
		back()
		do.call(), "warn")
	var no := _wide("ask:no", "back", _arg["no"], back)
	for button: Touch in [no, yes]:
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		across.add_child(button)


func _fill_sides() -> void:
	var title := TombSpec.room_title(editor.spec, editor.chosen)
	_top("A new room off %s" % title)
	for side: int in TombFloorSpec.free_sides(editor.spec, editor.chosen):
		_row("side:%d" % side, "To the %s" % TombFloorSpec.SIDE_NAMES[side], "", "A corridor on the square %s of %s, entered from it." % [TombFloorSpec.SIDE_NAMES[side], title], func() -> void:
			editor.add_off(side)
			close())
	_say("North is up the screen. The same places are marked + on the plan.")


func _fill_places() -> void:
	var title := TombSpec.room_title(editor.spec, editor.chosen)
	_top("Move %s to" % title)
	var only: Array = _arg.get("only", [])
	var places: Array = only if not only.is_empty() else editor.places()
	for place: Array in places:
		var off := int(place[0])
		var side := int(place[1])
		_row("place:%d:%d" % [off, side], "%s of %s" % [String(TombFloorSpec.SIDE_NAMES[side]).capitalize(), TombSpec.room_title(editor.spec, off)], "", "It would be entered from %s." % TombSpec.room_title(editor.spec, off), func() -> void:
			editor.move_to(off, side)
			close())
	_say("Its second ways do not go with it. North is up the screen." if not places.is_empty() else "There is nowhere it could go.")
	_scroll.rows.add_child(_wide("place:stay", "cancel", "Leave it where it is", func() -> void:
		editor.mode = ""
		close()))


func _fill_joins() -> void:
	var title := TombSpec.room_title(editor.spec, editor.chosen)
	_top("A second way from %s" % title)
	var beside := editor.joinable()
	for pair: Array in beside:
		var other := int(pair[0])
		if pair[1]:
			_row("join:%d" % other, "Take away the way to %s" % TombSpec.room_title(editor.spec, other), "", "They have a second way between them now.", func() -> void:
				editor.join_with(other)
				close(), "warn")
		else:
			_row("join:%d" % other, "To %s" % TombSpec.room_title(editor.spec, other), "", "A level doorway between the two, which closes a loop. Its page then has what it is and its door.", func() -> void:
				editor.join_with(other)
				close())
	_say("Only rooms on squares side by side can be joined, and not a room to the one it is entered from." if not beside.is_empty() else "No room beside this one can be joined to it: only rooms on squares side by side, and not a room to the one it is entered from.")
	_scroll.rows.add_child(_wide("join:stay", "cancel", "Leave it as it is", func() -> void:
		editor.mode = ""
		close()))


# --- The parts pages are made of

func _touch(key: String, action: Callable, look := "plain") -> Touch:
	var made := Touch.new()
	made.key = key
	made.name = key.replace(":", "_").validate_node_name()
	made.action = action
	made.look = look
	return made


# A button with its picture over its word (or the picture alone): the bars, and the arrows.
func _tile(key: String, icon: String, word: String, action: Callable, look := "plain") -> Touch:
	var made := _touch(key, action, look)
	made.custom_minimum_size = Vector2(COLUMN if word != "" else TOUCH, TOUCH)
	var down := VBoxContainer.new()
	down.alignment = BoxContainer.ALIGNMENT_CENTER
	down.add_theme_constant_override(&"separation", -4)
	made.add_child(down)
	down.add_child(Icon.new(icon, 32.0 if word != "" else 44.0))
	if word != "":
		var label := _words(word, TEXT, INK, false)
		label.clip_text = false
		label.text_overrun_behavior = TextServer.OVERRUN_NO_TRIMMING
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		down.add_child(label)
	_quiet(made)
	return made


# A button with its picture beside its word.
func _wide(key: String, icon: String, word: String, action: Callable, look := "plain") -> Touch:
	var made := _touch(key, action, look)
	var across := HBoxContainer.new()
	across.alignment = BoxContainer.ALIGNMENT_CENTER
	across.add_theme_constant_override(&"separation", 12)
	made.add_child(across)
	if icon != "":
		across.add_child(Icon.new(icon, 32.0))
	var label := _words(word, TEXT, INK, false)
	label.clip_text = false
	label.text_overrun_behavior = TextServer.OVERRUN_NO_TRIMMING
	label.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	across.add_child(label)
	_quiet(made)
	return made


# A row of a page that opens something: what it is, what it is now, a line about it.
func _row(key: String, title: String, now: String, note: String, action: Callable, look := "plain") -> Touch:
	var made := _touch(key, action, look)
	var across := HBoxContainer.new()
	across.add_theme_constant_override(&"separation", 16)
	made.add_child(across)
	var lines := _two_lines(title, note)
	across.add_child(lines)
	if now != "":
		var value := _words(now, TITLE, GOLD, true)
		value.name = "Now"
		lines.add_child(value)
		lines.move_child(value, 1)
	across.add_child(Icon.new("chevron", 34.0))
	_scroll.rows.add_child(made)
	return made


func _two_lines(title: String, note: String) -> VBoxContainer:
	var lines := VBoxContainer.new()
	lines.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	lines.alignment = BoxContainer.ALIGNMENT_CENTER
	lines.add_theme_constant_override(&"separation", 0)
	lines.add_child(_words(title, TITLE, INK, true))
	if note != "":
		lines.add_child(_words(note, TEXT, DIM, true))
	return lines


# A yes or a no: the whole row is the switch.
func _switch(key: String, title: String, note: String, on: bool, toggled: Callable) -> void:
	var made := _touch(key, toggled, "chosen" if on else "plain")
	var across := HBoxContainer.new()
	across.add_theme_constant_override(&"separation", 16)
	made.add_child(across)
	across.add_child(_two_lines(title, note))
	var says := _words("Yes" if on else "No", TITLE, GOLD if on else DIM, false)
	says.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	across.add_child(says)
	across.add_child(Knob.new(on))
	_scroll.rows.add_child(made)


# How many: a step down, the number, a step up.
func _stepper(key: String, title: String, now: int, least: int, most: int, changed: Callable) -> void:
	var across := HBoxContainer.new()
	across.add_theme_constant_override(&"separation", int(GAP))
	_scroll.rows.add_child(across)
	var label := _words(title, TITLE, INK, false)
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	across.add_child(label)
	var less := _tile(key + ":-", "minus", "", func() -> void: changed.call(maxi(now - 1, least)))
	less.disabled = now <= least
	across.add_child(less)
	var number := _words(str(now), TITLE + 6, GOLD if now > 0 else DIM, false)
	number.custom_minimum_size.x = 150.0 if most > 99 else 70.0
	number.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	number.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	number.name = "Number"
	across.add_child(number)
	var more := _tile(key + ":+", "add", "", func() -> void: changed.call(mini(now + 1, most)))
	more.disabled = now >= most
	across.add_child(more)


func _section(title: String) -> void:
	var label := _words(title.to_upper(), TEXT, GOLD, true)
	label.modulate.a = 0.8
	_scroll.rows.add_child(label)


func _say(text: String, colour := DIM, big := TEXT) -> void:
	_scroll.rows.add_child(_words(text, big, colour, true))


func _words(text: String, big: int, colour: Color, wraps: bool) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override(&"font_size", big)
	label.add_theme_color_override(&"font_color", colour)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if wraps:
		label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		label.custom_minimum_size.x = 60.0
	else:
		label.clip_text = true
		label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	return label


# Nothing inside a thing to touch takes the touch from it.
func _quiet(node: Node) -> void:
	for child in node.get_children():
		if child is Touch or child is LineEdit or child is TextEdit or child is Scroller:
			_quiet(child)
			continue
		if child is Control:
			(child as Control).mouse_filter = Control.MOUSE_FILTER_IGNORE
		_quiet(child)


func _empty(node: Node) -> void:
	for old in node.get_children():
		node.remove_child(old)
		old.queue_free()
