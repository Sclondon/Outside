class_name TombMap
extends Control
## The map of a tomb that branches, on the HUD: a small plan of the rooms he
## has been in, drawn as he finds them, since in such a tomb he can lose his
## way and there is nobody to ask. A touch on it makes it large, and another
## small again; nothing about it wants a keyboard.
##
## It is a diagram, not a survey: each room is a square on the plan's own grid
## of cells (`TombPlan.Room.cell`: north is up, as the tomb is set out), darker
## the deeper it lies, and the ways between rooms are lines. What it shows
## (`shown`, which the tests ask as well):
##
##  - a room, once he has stood in it; the one he is in is bright, with a mark
##    for him that points the way the camera looks;
##  - a way, once he has been in a room at either end of it: whole if he has
##    been in both, and otherwise a stub that says there is somewhere he has
##    not been;
##  - a bar across a way whose door is still shut (or whose sand has not come
##    in), in red; it goes when the door opens;
##  - a loft (a mark at the top of its room) or a crypt (at the bottom), hollow
##    until he has been up or down into it;
##  - the way out, and the falcon's chamber once he has found it.

const SMALL := 168.0
const LARGE := 400.0
const PAPER := Color(0.05, 0.05, 0.07, 0.62)
const STONE := Color(0.82, 0.74, 0.58)
const HERE := Color(1.0, 0.93, 0.7)
const SHUT := Color(0.9, 0.22, 0.16)
const GOLD := Color(1.0, 0.8, 0.25)
const WATER := Color(0.4, 0.62, 0.86)

var layout: TombLayout3D
## By the plan's room: whether he has stood in it. By link: whether it is open
## now (it has no door, or its switches are all done). Both are the level's own
## lists, looked at and never changed here.
var seen: Array[bool] = []
var open: Array[bool] = []
## The room he is in, the way the camera looks over the ground (x and z), and
## whether he has the falcon.
var here := -1
var heading := Vector2.ZERO
var has_treasure := false
var large := false


## What the map has on it: `rooms` (the ids of those drawn), `ways` (each
## [link id, whether it is drawn whole, whether it is barred]) and `sides`
## (each [the id of a loft or a crypt, whether he has been in it]).
static func shown(of: TombLayout3D, been: Array[bool], passable: Array[bool]) -> Dictionary:
	var found := {"rooms": [], "ways": [], "sides": []}
	var plan := of.plan
	for room in plan.rooms:
		if TombLayout3D.is_side(room):
			if been[room.parent] or been[room.id]:
				found["sides"].append([room.id, been[room.id]])
		elif been[room.id]:
			found["rooms"].append(room.id)
	for link in plan.links:
		if TombLayout3D.is_side(plan.rooms[link.a]) or TombLayout3D.is_side(plan.rooms[link.b]):
			continue
		if not been[link.a] and not been[link.b]:
			continue
		found["ways"].append([link.id, been[link.a] and been[link.b], not link.switches.is_empty() and not passable[link.id]])
	return found


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	focus_mode = Control.FOCUS_NONE
	_place()


# Small, it is in the corner under the buttons; large, in the middle of the screen.
func _place() -> void:
	if large:
		set_anchors_preset(Control.PRESET_CENTER)
		offset_left = -LARGE * 0.5
		offset_right = LARGE * 0.5
		offset_top = -LARGE * 0.5
		offset_bottom = LARGE * 0.5
	else:
		set_anchors_preset(Control.PRESET_TOP_RIGHT)
		offset_left = -SMALL - 14.0
		offset_right = -14.0
		offset_top = 66.0
		offset_bottom = 66.0 + SMALL
	queue_redraw()


func _gui_input(event: InputEvent) -> void:
	var pressed := false
	if event is InputEventScreenTouch:
		pressed = (event as InputEventScreenTouch).pressed
	elif event is InputEventMouseButton:
		pressed = (event as InputEventMouseButton).pressed and (event as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT
	if pressed:
		toggle()
		accept_event()


## Large if it is small, and small if it is large.
func toggle() -> void:
	large = not large
	_place()


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), Color(PAPER, 0.88) if large else PAPER)
	draw_rect(Rect2(Vector2.ZERO, size), Color(STONE, 0.5), false, 1.5)
	if layout == null or seen.is_empty():
		return
	var plan := layout.plan
	var what := shown(layout, seen, open)
	# The squares of the whole plan set how big a square is drawn: so the map
	# does not jump about as it grows.
	var low := Vector2i(9999, 9999)
	var high := Vector2i(-9999, -9999)
	var deepest := 1
	for room in layout.placed():
		var cell := layout.cells[room.id]
		low = Vector2i(mini(low.x, cell.x), mini(low.y, cell.z))
		high = Vector2i(maxi(high.x, cell.x), maxi(high.y, cell.z))
		deepest = maxi(deepest, absi(cell.y))
	var across := Vector2(high - low) + Vector2.ONE
	var margin := 9.0 if not large else 44.0
	var pitch := minf((size.x - margin * 2.0) / across.x, (size.y - margin * 2.0) / across.y)
	pitch = minf(pitch, 64.0 if large else 30.0)
	var origin := (size - across * pitch) * 0.5
	var half := pitch * 0.31
	var middle := func(room: int) -> Vector2:
		var cell := layout.cells[room]
		return origin + (Vector2(cell.x - low.x, cell.z - low.y) + Vector2(0.5, 0.5)) * pitch
	var thick := 3.0 if large else 2.0

	for way: Array in what["ways"]:
		var link := plan.links[int(way[0])]
		var a: Vector2 = middle.call(link.a)
		var b: Vector2 = middle.call(link.b)
		var colour := WATER if link.pass_kind == TombPlan.Pass.FLOOD else STONE
		if way[1]:
			draw_line(a, b, colour, thick)
		else:
			# (from the room he knows, part of the way to the one he does not)
			var from := a if seen[link.a] else b
			var to := b if seen[link.a] else a
			draw_line(from, from.lerp(to, 0.62), Color(colour, 0.7), thick)
			draw_circle(from.lerp(to, 0.62), thick * 0.9, Color(colour, 0.7))
		if way[2]:
			# (the door is in the wall of the room the way is written from)
			var at := a.lerp(b, 0.4)
			var along := (b - a).normalized()
			var side := Vector2(-along.y, along.x)
			draw_line(at - side * half * 0.75, at + side * half * 0.75, SHUT, thick + 1.5)

	var goal := plan.goal_trigger().room
	for id: int in what["rooms"]:
		var at: Vector2 = middle.call(id)
		var shade := 1.0 - 0.45 * float(absi(layout.cells[id].y)) / float(deepest)
		var colour := Color(STONE.r * shade, STONE.g * shade, STONE.b * shade)
		if plan.rooms[id].dark and not _lit(id):
			colour = colour.darkened(0.45)
		var rect := Rect2(at - Vector2(half, half), Vector2(half, half) * 2.0)
		draw_rect(rect, colour)
		if id == here:
			draw_rect(rect, HERE, false, thick)
		if id == goal:
			# (the falcon: gone from here once he has it)
			var gem := PackedVector2Array([at + Vector2(0, -half * 0.6), at + Vector2(half * 0.6, 0), at + Vector2(0, half * 0.6), at + Vector2(-half * 0.6, 0)])
			if has_treasure:
				draw_polyline(gem + PackedVector2Array([gem[0]]), GOLD, 1.5)
			else:
				draw_colored_polygon(gem, GOLD)
		if id == plan.entrance():
			# (the way out: an arrow out of the court, gold once he has what he came for)
			var out := Vector2(layout.exit_way.x, layout.exit_way.z).normalized()
			var tip := at + out * half * 1.9
			var across_out := Vector2(-out.y, out.x)
			draw_colored_polygon(PackedVector2Array([tip, tip - out * half * 0.9 + across_out * half * 0.6, tip - out * half * 0.9 - across_out * half * 0.6]),
					GOLD if has_treasure else STONE)

	for side: Array in what["sides"]:
		var room := plan.rooms[int(side[0])]
		var at: Vector2 = middle.call(room.parent)
		var up := room.role == TombPlan.Role.LOFT
		var tip := at + Vector2(half * 0.55, (-half * 0.75) if up else (half * 0.75))
		var base := half * 0.42
		var mark := PackedVector2Array([tip, tip + Vector2(base, base * (1.3 if up else -1.3)), tip + Vector2(-base, base * (1.3 if up else -1.3))])
		if side[1]:
			draw_colored_polygon(mark, Color(0.2, 0.16, 0.1))
		else:
			draw_polyline(mark + PackedVector2Array([mark[0]]), Color(0.2, 0.16, 0.1), 1.5)

	# Him: a mark in the room he is in, pointing the way the camera looks.
	if here >= 0:
		var room := plan.rooms[here]
		var at: Vector2 = middle.call(room.parent if TombLayout3D.is_side(room) else here)
		var way := heading.normalized() if heading.length() > 0.01 else Vector2.RIGHT
		var wing := Vector2(-way.y, way.x)
		var long := half * 0.8
		draw_colored_polygon(PackedVector2Array([at + way * long, at - way * long * 0.7 + wing * long * 0.65, at - way * long * 0.25, at - way * long * 0.7 - wing * long * 0.65]), Color(0.75, 0.1, 0.08))

	if large:
		var font := ThemeDB.fallback_font
		draw_string(font, Vector2(14.0, 22.0), "MAP", HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color(1, 1, 1, 0.6))
		draw_string(font, Vector2(14.0, 22.0), "touch to put away", HORIZONTAL_ALIGNMENT_RIGHT, size.x - 28.0, 14, Color(1, 1, 1, 0.6))
		draw_string(font, Vector2(14.0, size.y - 30.0), "Red bar: a door still shut, or sand not yet let in.", HORIZONTAL_ALIGNMENT_LEFT, size.x - 28.0, 14, Color(1, 1, 1, 0.8))
		draw_string(font, Vector2(14.0, size.y - 12.0), "A line with a knob: a way not yet taken.   Blue: water.", HORIZONTAL_ALIGNMENT_LEFT, size.x - 28.0, 14, Color(1, 1, 1, 0.8))


# Whether a dark room's brazier has been lit.
func _lit(room: int) -> bool:
	for trigger in layout.plan.triggers:
		if trigger.room == room and trigger.kind == TombPlan.Switch.BRAZIER:
			for link in layout.plan.links:
				if trigger.id in link.switches and link.switches.size() == 1:
					return open[link.id]
	return false
