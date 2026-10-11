class_name TombLayout3D
extends TombLayout
## A plan set out as a tomb to be walked through: rooms with four walls and a
## roof, on a floor plan that turns corners, seen by the camera that follows
## him about the desert. It is the same plan the tomb seen from the side is
## made from (`TombLayout`), and it answers the same questions, so that
## `TombBuilder` and `TombLevel` take either. No nodes are made here.
##
## THE CELLS. Every room that is not a loft or a crypt stands on a square of
## a floor plan, its `cell` (`TombPlan.Room.cell`): x and z say which square, y
## which level, counted downwards from the entrance at 0. A plan whose rooms
## all have cells is set out as it says (`TombBranching` makes those, and a tomb
## made by hand on a floor plan has them); one with none (every plan that
## `TombGenerator` makes) has them worked out here, down its axis, turning as
## the dice say (`_own_cells`), and the plan itself is left as it was. What a
## plan with cells must keep to (`cells_wrong` lists whatever it does not):
##
##  - No two rooms on the same square, whatever their levels: nothing is under
##    anything else. (A loft and a crypt are part of the room they are off, on
##    its square, and need no cell of their own; whatever they have is not read.)
##  - A way between two rooms joins squares that share a side, and is written
##    going in: `a` is the room nearer the entrance. The first way that ends at
##    a room is its way in, and the room is laid along it, the way he comes in.
##    Every other way a room has leaves from the bay at its far end: ahead, to
##    the left or to the right, never back beside its way in. So a room has up
##    to three ways on, and a way that closes a loop arrives at a bay.
##  - How many levels a way goes down from `a` to `b` (a level is `LEVEL`, 1.6 m):
##        OPEN, CRAWL, FLOOD, GAP   0   level floor
##        STAIRS                    1 or more: a flight of eight steps for each
##        SHAFT, ROPE               3   (4.8 m, straight down)
##        SAND                     -2   (3.2 m up: `SAND_RISE`)
##  - CLIMB is from a room up to its own loft, and SHAFT to a crypt is from a
##    well down to its own crypt: neither is between squares. DROP is from a loft
##    down into a room next to the loft's own, which that room must also have a
##    way to, at least two levels down (`DROP_LEVELS`: stairs of two flights): the
##    loft goes on over that way as a cutting, and ends over the foot of it.
##  - A block that is for the plate of another room stands in the bay, in line
##    with the way to that room, and is pushed straight along it: so a room
##    holds one such block, and the way is level (OPEN).
##
## A square is as big as what stands on it needs: the columns and rows of the
## plan are each as wide as their widest room (`_grid`), and a way is made
## longer with plain passage where its two rooms are further apart than it needs.
##
## HOW A ROOM IS LAID. Along the way he comes in, as a run of floors from wall
## to wall (so that a trench, a kerb or a pit cannot be walked round), exactly
## as the tomb seen from the side is a run of spans; and then the bay. The ways
## on are passages `PASSAGE` wide, each with all of its stairs, water, shaft or
## sand in it. The line he is expected to walk (`WALK`) is a metre left of the
## middle, which leaves the middle for a block pushed through from the room
## before, and the right for the room's own block and plate, its offering table,
## its brazier and whatever lies about to be picked up.
##
## The stone is then cut round all of it at once (`_shell`): the air is laid on
## a grid of its own edges, and floors, roofs and walls are drawn round it,
## so that nothing overlaps and no face he can jump at has a seam across it.

# --- The floor plan
## How far down one level is, and how many steps a flight of that has.
const LEVEL := 1.6
const STEPS := 8
## How many levels a shaft goes down, and the sand comes up.
const SHAFT_LEVELS := 3
const SAND_LEVELS := 2
## How wide a way between two rooms is, how high where it is nothing else, and
## how long the bay at the far end of a room that the ways on leave from.
const PASSAGE := 3.6
const PASSAGE_HIGH := 2.8
const BAY := 4.0
## How far to either side of the way on the chamber at the foot of the sand
## goes, and the pit that the hook swings him over; and the short plain passage
## that keeps such a chamber a wall's thickness from the rooms at either end of it.
const SAND_SIDE := 3.5
const GAP_SIDE := 2.4
const THROAT := 1.2
## How many levels down a room is that a loft's cutting drops into: far enough
## that the lip cannot be got back up to, even by a kick off the wall beside it.
const DROP_LEVELS := 2
## How thick a wall is drawn.
const THICK := 1.0
## How far from the middle of a room or a passage the line he walks is (to the
## left as he goes in), and the lane a room's own block is pushed along (to the right).
const WALK := -1.0
const LANE := 1.3
## How wide a plate is across the lane its block comes along.
const PAD := 1.4
## How wide each kind of room is (`TombPlan.Role`), wall to wall.
const WIDTHS := [9.0, 5.0, 5.0, 9.0, 6.0, 7.0, 9.0, 0.0, 0.0]
## How high the rock stands round the court at the way in.
const CLIFF := 8.0
## The four ways a room can lie: east, south, west, north (each a quarter turn on from the last).
const TURNS: Array[Vector3i] = [Vector3i(1, 0, 0), Vector3i(0, 0, 1), Vector3i(-1, 0, 0), Vector3i(0, 0, -1)]


## A piece of air: a floor and a roof over a rectangle of the plan.
class Area:
	var x0 := 0.0
	var x1 := 0.0
	var z0 := 0.0
	var z1 := 0.0
	var floor := 0.0
	var ceil := 0.0
	var room := 0
	## Where it begins and ends along the room or the passage it is part of.
	var u0 := 0.0
	var u1 := 0.0
	var deadly := false
	var sky := false
	## A doorway or a crawl: the stone over it is wall, not roof.
	var gate := false


## Where a room or a passage lies: `at` turns a place in it (so far along, so
## high, so far to the right) into a place in the tomb.
class Frame:
	var origin := Vector3.ZERO
	var turn := 0

	func dir() -> Vector3:
		return Vector3(TombLayout3D.TURNS[turn])

	func side() -> Vector3:
		var along := dir()
		return Vector3(-along.z, 0.0, along.x)

	func at(u: float, y: float, v: float) -> Vector3:
		return Vector3(origin.x, y, origin.z) + dir() * u + side() * v

	func size(long: float, high: float, wide: float) -> Vector3:
		return Vector3(long, high, wide) if turn % 2 == 0 else Vector3(wide, high, long)

	## The turn about Y of a thing that would be turned `local` in a room lying east.
	func yaw(local := 0.0) -> float:
		return local - turn * PI * 0.5


## By the plan's room: its cell as it was set out (a loft's or a crypt's is its room's).
var cells: Array[Vector3i] = []
## By the plan's room: which way it lies (an index into TURNS), or -1 for a loft or a crypt.
var turns: Array[int] = []
var areas: Array[Area] = []
## Where a thing cannot be carried out again (the water, the well and what is under it).
var holes: Array[AABB] = []
## By link: `turn` (which way it goes), `from` and `to` (where it leaves the bay
## and where it comes to the next room, on his line), and whatever of these it has: `gap` (the two edges of the
## pit, on his line), `lip`, `rope`, `upper` and `lower` (a rope: the edge he
## steps off, where it hangs, and where he stands at its head and its foot),
## `before`, `face` and `top` (the sand: short of the heap, the foot of the
## face, and over it).
var ways: Array[Dictionary] = []
## By switch: where he stands to work it.
var stand_at: Array[Vector3] = []
## The lines he is expected to walk, for whatever plays a tomb by itself: places,
## the plan's room each is in, and which are joined by a straight walk (with
## whatever is to be jumped, ducked under or climbed on the way). Where the
## way is not a walk (a rope, the sand, a pit to swing over, up into a loft,
## down into a crypt) there is no line.
var walk_points: Array[Vector3] = []
var walk_rooms: Array[int] = []
var walk_lines: Array[Vector2i] = []
## He is out once he is in the court at the way in, beyond `exit_at` the way `exit_way` points.
var exit_at := Vector3.ZERO
var exit_way := Vector3.LEFT
## What was wrong with the cells the plan came with, if it came with any: then they were not used.
var wrong: PackedStringArray = []

var _f: Frame
var _u := 0.0
var _w := 0.0
var _clear_to := -1.0
## By room: the link it is entered by, or -1.
var _in: Array[int] = []
var _centres: Array[Vector3] = []
var _hops: Array = []
var _last_room := -1
## By link: how far to either side of its middle the widest part of it reaches.
var _wides := {}
var _most := 0.0
## Whether the plan came with its cells: rooms then stand to every side of one
## another, and the edges of one cut the stone round another into thin pieces
## (see `_shell`: there a roof looks further than the next square for higher air).
var _crowded := false


## Sets out `plan` as a tomb to be walked through.
static func set_out(from: TombPlan) -> TombLayout3D:
	var layout := TombLayout3D.new()
	layout.plan = from
	layout._lay()
	return layout


static func is_side(room: TombPlan.Room) -> bool:
	return room.role == TombPlan.Role.LOFT or room.role == TombPlan.Role.CRYPT


## How many levels down the way goes, from `a` to `b` (STAIRS: at least).
static func levels_down(kind: TombPlan.Pass) -> int:
	match kind:
		TombPlan.Pass.STAIRS:
			return 1
		TombPlan.Pass.SHAFT, TombPlan.Pass.ROPE:
			return SHAFT_LEVELS
		TombPlan.Pass.SAND:
			return -SAND_LEVELS
	return 0


## Whatever in a plan's cells breaks the rules at the top of this file; empty
## if they can be set out. (For whatever fills cells in: ask before building.)
static func cells_wrong(plan: TombPlan) -> PackedStringArray:
	var found: PackedStringArray = []
	var taken := {}
	for room in plan.rooms:
		if is_side(room):
			continue
		if room.cell == TombPlan.NO_CELL:
			found.append("room %d has no cell" % room.id)
			continue
		var square := Vector2i(room.cell.x, room.cell.z)
		if taken.has(square):
			found.append("rooms %d and %d are on the same square" % [taken[square], room.id])
		taken[square] = room.id
	if not found.is_empty():
		return found
	var way_in := {}
	var entrance := plan.entrance()
	for link in plan.links:
		var a := plan.rooms[link.a]
		var b := plan.rooms[link.b]
		if is_side(a) or is_side(b):
			var side := b if is_side(b) else a
			var other := a if is_side(b) else b
			if link.pass_kind == TombPlan.Pass.DROP and is_side(a):
				var from := plan.rooms[a.parent]
				var by := false
				for also in plan.links:
					by = by or (also.a == from.id and also.b == b.id)
				if not by or b.cell.y - from.cell.y < DROP_LEVELS:
					found.append("link %d: a drop from a loft wants a way from the loft's own room to the same room, at least %d levels down" % [link.id, DROP_LEVELS])
			elif side.parent != other.id:
				found.append("link %d: a loft or a crypt is reached only from the room it is off" % link.id)
			continue
		var step := b.cell - a.cell
		if absi(step.x) + absi(step.z) != 1:
			found.append("link %d: rooms %d and %d are not on squares that share a side" % [link.id, a.id, b.id])
			continue
		var down := levels_down(link.pass_kind)
		if link.pass_kind == TombPlan.Pass.STAIRS:
			if step.y < 1:
				found.append("link %d: stairs go down at least a level from %d to %d" % [link.id, a.id, b.id])
		elif step.y != down:
			found.append("link %d: %s wants room %d to be %d levels below room %d, not %d" % [link.id, TombPlan.PASS_NAMES[link.pass_kind], b.id, down, a.id, step.y])
		if not way_in.has(b.id) and b.id != entrance:
			way_in[b.id] = link
	for room in plan.rooms:
		if is_side(room) or room.id == entrance:
			continue
		if not way_in.has(room.id):
			found.append("room %d has no way in (no link ends at it)" % room.id)
			continue
		var came: TombPlan.Link = way_in[room.id]
		var back := plan.rooms[came.a].cell - room.cell
		for link in plan.links:
			if link == came or (link.a != room.id and link.b != room.id):
				continue
			var other := plan.rooms[link.b if link.a == room.id else link.a]
			if is_side(other):
				continue
			var step := other.cell - room.cell
			if step.x == back.x and step.z == back.z:
				found.append("room %d: link %d leaves beside its way in" % [room.id, link.id])
	return found


func _lay() -> void:
	var count := plan.rooms.size()
	rooms.resize(count)
	for i in count:
		rooms[i] = {}
	thing_at.resize(plan.things.size())
	switch_at.resize(plan.triggers.size())
	stand_at.resize(plan.triggers.size())
	door_at.resize(plan.links.size())
	door_at.fill(Vector3.INF)
	ways.resize(plan.links.size())
	for i in ways.size():
		ways[i] = {}
	cells.resize(count)
	var given := true
	for room in plan.rooms:
		cells[room.id] = room.cell
		given = given and (is_side(room) or room.cell != TombPlan.NO_CELL)
	if given:
		wrong = cells_wrong(plan)
	if not given or not wrong.is_empty():
		_own_cells()
	else:
		_crowded = true
	for room in plan.rooms:
		if is_side(room):
			cells[room.id] = cells[room.parent]
	_headings()

	# Each room and each way is laid once to be measured and then again in its place.
	var longs: Array[float] = []
	longs.resize(count)
	for room in placed():
		var marks := _marks()
		longs[room.id] = _set_room(room, Frame.new())
		_rewind(marks)
	var needs := {}
	for link in _joins():
		var marks := _marks()
		needs[link.id] = _set_way(link, Frame.new(), 0.0)
		_rewind(marks)
	_grid(longs, needs)
	for room in placed():
		var frame := Frame.new()
		frame.turn = turns[room.id]
		frame.origin = _centres[room.id] - frame.dir() * (longs[room.id] - BAY * 0.5)
		_set_room(room, frame)
	for link in _joins():
		var frame := Frame.new()
		frame.turn = _turn_of(link.a, link.b)
		var from := _port(link.a, frame.turn, longs)
		var to := _port(link.b, (frame.turn + 2) % 4, longs)
		frame.origin = _centres[link.a] + frame.dir() * from
		var between := absf((_centres[link.b] - _centres[link.a]).dot(frame.dir())) - from - to
		_set_way(link, frame, between - float(needs[link.id]))
		length += between
	for room in placed():
		length += longs[room.id]
	for area in areas:
		if not area.deadly:
			depth = maxf(depth, -area.floor)
	_shell()
	_count_hops()


# --- The floor plan

# Cells for a plan that has none: down its axis from the entrance, which lies
# east, each room ahead of the last or round a corner from it, as the dice say
# (a corner is likelier after a straight, so that it is no tube), never onto a
# square that is taken; and where that would leave no square to go on to, the
# last choice is taken back.
func _own_cells() -> void:
	var along := plan.spine()
	var rng := TombRandom.new(TombRandom.mix([TombGenerator.VERSION, plan.seed_value, plan.difficulty, plan.sub_seed, 9241]))
	cells.fill(TombPlan.NO_CELL)
	cells[along[0].id] = Vector3i.ZERO
	var taken := {Vector2i.ZERO: true}
	_walk_on(along, 1, Vector3i.ZERO, 0, 0, taken, rng)


func _walk_on(along: Array[TombPlan.Room], place: int, from: Vector3i, heading: int, straight: int, taken: Dictionary, rng: TombRandom) -> bool:
	if place >= along.size():
		return true
	var link := plan.spine_link(place - 1)
	# (the way in from the court is straight ahead: it is the front of the tomb)
	var weights: Array = [3 if straight == 0 else 1, 2 if place > 1 else 0, 0, 2 if place > 1 else 0]
	while true:
		var turn := rng.weighted(weights)
		if turn == -1:
			return false
		weights[turn] = 0
		var facing := (heading + turn) % 4
		var next := from + TURNS[facing]
		next.y = from.y + levels_down(link.pass_kind)
		# (a way that a loft's cutting goes on over, and drops him at the end of)
		if _dropped_onto(along[place - 1].id, along[place].id):
			next.y = from.y + DROP_LEVELS
		var square := Vector2i(next.x, next.z)
		if taken.has(square):
			continue
		taken[square] = true
		cells[along[place].id] = next
		if _walk_on(along, place + 1, next, facing, straight + 1 if turn == 0 else 0, taken, rng):
			return true
		taken.erase(square)
	return false


# Whether a loft over `from` has a drop into `to`.
func _dropped_onto(from: int, to: int) -> bool:
	var loft := plan.side_room(from, TombPlan.Role.LOFT)
	if loft == null:
		return false
	for link in plan.links:
		if link.pass_kind == TombPlan.Pass.DROP and link.a == loft.id and link.b == to:
			return true
	return false


# The ways between two rooms that each stand on a square.
func _joins() -> Array[TombPlan.Link]:
	var found: Array[TombPlan.Link] = []
	for link in plan.links:
		if not is_side(plan.rooms[link.a]) and not is_side(plan.rooms[link.b]) and cells[link.a] != TombPlan.NO_CELL and cells[link.b] != TombPlan.NO_CELL:
			found.append(link)
	return found


func _turn_of(from: int, to: int) -> int:
	var step := cells[to] - cells[from]
	return maxi(TURNS.find(Vector3i(signi(step.x), 0, signi(step.z))), 0)


# Which way each room lies: the way its way in comes into it.
func _headings() -> void:
	var count := plan.rooms.size()
	turns.resize(count)
	turns.fill(-1)
	_in.resize(count)
	_in.fill(-1)
	var entrance := plan.entrance()
	for link in _joins():
		if _in[link.b] == -1 and link.b != entrance:
			_in[link.b] = link.id
			turns[link.b] = _turn_of(link.a, link.b)
	for room in placed():
		if turns[room.id] != -1:
			continue
		turns[room.id] = 0
		for link in _joins():
			if link.a == room.id:
				turns[room.id] = _turn_of(link.a, link.b)
				break


# The ways a room has besides its way in: each [link, which way it leaves].
func _outs(room: int) -> Array:
	var found: Array = []
	for link in _joins():
		if link.id == _in[room] or (link.a != room and link.b != room):
			continue
		found.append([link, _turn_of(room, link.b if link.a == room else link.a)])
	return found


# How far from the middle of a room's bay the way out of it that way begins.
func _port(room: int, turn: int, longs: Array[float]) -> float:
	var heading := turns[room]
	if turn == (heading + 2) % 4:
		return longs[room] - BAY * 0.5
	if turn == heading:
		return BAY * 0.5
	return float(WIDTHS[plan.rooms[room].role]) * 0.5


# Where the middle of each room's bay is. The squares of the plan are made as
# big as what is on them: each column as wide to the east and to the west of
# its middle as any room in it reaches (with the whole of each way out of it),
# and each row likewise.
func _grid(longs: Array[float], needs: Dictionary) -> void:
	var reach := {}
	for room in placed():
		var heading := turns[room.id]
		var wide := float(WIDTHS[room.role]) * 0.5 + THICK
		var each: Array[float] = [wide, wide, wide, wide]
		each[heading] = BAY * 0.5 + THICK
		each[(heading + 2) % 4] = longs[room.id] - BAY * 0.5 + THICK
		reach[room.id] = each
	for link in _joins():
		var turn := _turn_of(link.a, link.b)
		reach[link.a][turn] = maxf(reach[link.a][turn], _port(link.a, turn, longs) + float(needs[link.id]))
		reach[link.b][(turn + 2) % 4] = maxf(reach[link.b][(turn + 2) % 4], _port(link.b, (turn + 2) % 4, longs))
		# (and where it is wider than a passage, a chamber for sand or over a pit,
		# it is as likely to be on the one square as the other)
		for room: int in [link.a, link.b]:
			for aside: int in [(turn + 1) % 4, (turn + 3) % 4]:
				reach[room][aside] = maxf(reach[room][aside], float(_wides[link.id]) + THICK)
	var east := {}
	var west := {}
	var south := {}
	var north := {}
	for room in placed():
		var cell := cells[room.id]
		var each: Array[float] = reach[room.id]
		east[cell.x] = maxf(east.get(cell.x, 0.0), each[0])
		south[cell.z] = maxf(south.get(cell.z, 0.0), each[1])
		west[cell.x] = maxf(west.get(cell.x, 0.0), each[2])
		north[cell.z] = maxf(north.get(cell.z, 0.0), each[3])
	var xs := _middles(east, west)
	var zs := _middles(south, north)
	_centres.resize(plan.rooms.size())
	for room in placed():
		var cell := cells[room.id]
		_centres[room.id] = Vector3(xs[cell.x], -LEVEL * cell.y, zs[cell.z])


# The middle of each column (or row), from how far each reaches either way.
func _middles(after: Dictionary, before: Dictionary) -> Dictionary:
	var keys := after.keys()
	keys.sort()
	var found := {}
	var at := 0.0
	for i in keys.size():
		var key: int = keys[i]
		if i > 0:
			at += float(after[keys[i - 1]]) + float(before[key])
			# (a column with nothing on it, between two that have)
			at += 6.0 * (key - int(keys[i - 1]) - 1)
		found[key] = at
	# (the entrance's is where the tomb is measured from)
	var zero: float = found.get(0, 0.0)
	for key: int in found:
		found[key] = float(found[key]) - zero
	return found


# What has been laid so far, so that a room laid only to be measured can be taken away again.
func _marks() -> Array:
	return [areas.size(), boxes.size(), parts.size(), moves.size(), holes.size(), walk_points.size(), walk_lines.size()]


func _rewind(marks: Array) -> void:
	areas.resize(marks[0])
	boxes.resize(marks[1])
	parts.resize(marks[2])
	moves.resize(marks[3])
	holes.resize(marks[4])
	walk_points.resize(marks[5])
	walk_rooms.resize(marks[5])
	walk_lines.resize(marks[6])


# --- A room

# One room, from the wall its way in comes through to the far wall of its bay.
# Returns how long it is.
func _set_room(room: TombPlan.Room, frame: Frame) -> float:
	_f = frame
	_room = room.id
	_u = 0.0
	_y = frame.origin.y
	_w = WIDTHS[room.role]
	_sky = room.role == TombPlan.Role.ENTRANCE
	_rng = TombRandom.new(TombRandom.mix([TombGenerator.VERSION, plan.seed_value, plan.difficulty, plan.sub_seed, 5381, room.id]))
	var way_in: TombPlan.Link = plan.links[_in[room.id]] if _in[room.id] >= 0 else null
	var outs := _outs(room.id)
	var loft := plan.side_room(room.id, TombPlan.Role.LOFT)
	var crypt := plan.side_room(room.id, TombPlan.Role.CRYPT)
	_ceil = _y + float(HEIGHTS[room.role])
	if _sky:
		_ceil = _y + CLIFF - ROCK
	if loft:
		_ceil = maxf(_ceil, _y + LOFT_TOP + LOFT_ROOM)
	# (he has come up over the edge of this floor: half the heap is in the rock under it)
	_clear_to = SAND_PILE * SAND_SKIRT - SAND_OUT - THROAT if way_in and way_in.pass_kind == TombPlan.Pass.SAND else -1.0
	var info := {"floor": _y, "turn": frame.turn, "wide": _w}

	# --- Just inside: a seal stone that opens the door behind him, the things that lie here, a plate
	for trigger in plan.triggers:
		if trigger.room == room.id and trigger.kind == TombPlan.Switch.LEVER and not _lets_sand_in(trigger, room.id):
			_area(1.6)
			_seal(trigger, frame.at(_u - 0.8, _y, WALK))
	var entry := _area(2.6)
	var west := frame.at(entry.u0 + 1.0, _y, WALK)
	if _sky:
		# (well out in the court, with room behind him for the camera)
		west = frame.at(entry.u0 + 6.0, _y, WALK)
		start = west
		exit_at = frame.at(entry.u0 + 3.4, _y, 0.0)
		exit_way = -frame.dir()
		_area(5.0)
	info["west"] = west
	info["w"] = _point(west, room.id)
	parts.append({"kind": "check", "room": _room, "at": west, "along": frame.dir(), "wide": _w})
	# (the plate first: nothing may lie in the way of the block that is pushed to it)
	for trigger in plan.triggers:
		if trigger.room == room.id and trigger.kind == TombPlan.Switch.PLATE:
			_pad(trigger, 0.0)
			moves.append({"kind": "beside", "is": _w * 0.5 - BLOCK * 0.5, "room": _room})
	for thing in plan.things:
		if thing.room != room.id or thing.kind == TombPlan.Item.BLOCK:
			continue
		_area(1.3)
		thing_at[thing.id] = frame.at(_u - 0.65, _y, _w * 0.5 - 0.9)
		parts.append({"kind": "item", "room": _room, "thing": thing.id, "what": thing.kind, "at": thing_at[thing.id]})

	# --- What the room is
	match room.role:
		TombPlan.Role.WELL:
			_clear(CRYPT_LONG + ROCK if crypt else 0.0)
			_area(2.2)
			var shaft := _area(WELL_WIDE)
			shaft.floor = _y - WELL_DEEP
			var west_end := shaft.u0 - (CRYPT_LONG if crypt else 0.0)
			holes.append(_aabb(frame.at(west_end, _y - WELL_DEEP - 1.0, -_w * 0.5), frame.at(shaft.u1, _y - 1.0, _w * 0.5)))
			# The way out is up the far side in two: a step half its depth, then
			# the floor (see TombLayout: not a ladder).
			_box(frame.at(shaft.u1 - WELL_STEP * 0.5, _y - WELL_DEEP * 0.75, 0.0), frame.size(WELL_STEP, WELL_DEEP * 0.5, _w), "floor", true)
			moves.append({"kind": "jump", "is": WELL_WIDE, "room": _room})
			moves.append({"kind": "ledge", "is": WELL_DEEP * 0.5, "room": _room})
			_area(1.6)
			if crypt:
				_set_crypt(crypt, shaft)
		TombPlan.Role.HALL:
			var hall := _area(float(_rng.between(6, 9)))
			var pairs := int((hall.u1 - hall.u0) / 3.0)
			for k in pairs:
				for side: float in [-1.0, 1.0]:
					parts.append({"kind": "pillar", "room": _room, "solid": true, "high": _ceil - _y,
							"at": frame.at(hall.u0 + (hall.u1 - hall.u0) * (k + 0.5) / pairs, _y, side * (_w * 0.5 - 1.5))})
		TombPlan.Role.GALLERY:
			_area(float(_rng.between(3, 5)))
		TombPlan.Role.ANTECHAMBER:
			var ante := _area(float(_rng.between(4, 5)))
			_prop("statue_anubis", frame.at((ante.u0 + ante.u1) * 0.5, _y, -_w * 0.5 + 0.9), frame.yaw(PI * 0.5))
		TombPlan.Role.CORRIDOR:
			_area(float(_rng.between(1, 3)))

	if room.role == TombPlan.Role.BURIAL:
		_set_burial(room, info, not outs.is_empty())
		_light(room, _u - (BAY if not outs.is_empty() else 0.0), outs)
		rooms[room.id] = info
		return _u

	# --- A mummy, and after it what holds it back
	if room.mummy >= 0:
		var niche := _area(4.0)
		var stands := frame.at((niche.u0 + niche.u1) * 0.5, _y, _w * 0.5 - 0.8)
		_barrier(room.barrier)
		# (he is out of its reach once he is this far on: nothing he has to stand at is nearer)
		parts.append({"kind": "mummy", "room": _room, "what": room.mummy, "guardian": false, "at": stands,
				"safe_at": frame.at(_u, _y, 0.0), "safe_way": frame.dir(), "wake": _w * 0.5 - 0.8 - WALK + 1.2})
		_area(2.6)
	if room.pit:
		_clear()
		var pit := _area(PIT_WIDE)
		pit.floor = _y - PIT_DEEP
		pit.deadly = true
		moves.append({"kind": "jump", "is": PIT_WIDE, "room": _room})
		_area(1.2)

	# --- What opens the way on
	var work: TombPlan.Trigger
	var table: TombPlan.Trigger
	var fire: TombPlan.Trigger
	for trigger in plan.triggers:
		if trigger.room != room.id:
			continue
		match trigger.kind:
			TombPlan.Switch.WORK_PLATE:
				work = trigger
			TombPlan.Switch.OFFERING:
				table = trigger
			TombPlan.Switch.BRAZIER:
				fire = trigger
	if fire:
		var hearth := _area(2.4)
		var middle := (hearth.u0 + hearth.u1) * 0.5
		switch_at[fire.id] = frame.at(middle, _y, 0.6)
		stand_at[fire.id] = frame.at(middle, _y, -0.5)
		parts.append({"kind": "brazier", "room": _room, "trigger": fire.id, "at": switch_at[fire.id]})
		parts.append({"kind": "scarabs", "room": _room, "at": frame.at(hearth.u0 - 1.0, _y, -_w * 0.5 + 0.4)})
	if work:
		# Its block stands in a lane to the right of his line, and is pushed along it.
		var stand := _area(1.4 + BLOCK)
		parts.append({"kind": "block", "room": _room, "thing": -1, "serves": work.id, "lane": frame.turn % 2,
				"at": frame.at(stand.u1 - BLOCK * 0.5, _y + BLOCK * 0.5, LANE)})
		_area(TRACK - 1.5)
		_pad(work, LANE)
		moves.append({"kind": "beside", "is": LANE - BLOCK * 0.5 + _w * 0.5, "room": _room})
	if table:
		var dais := _area(TABLE_LONG)
		var middle := (dais.u0 + dais.u1) * 0.5
		var out := _w * 0.5 - 0.7
		switch_at[table.id] = frame.at(middle, _y + TABLE_HIGH, out)
		stand_at[table.id] = frame.at(middle, _y, out - 1.25)
		_box(frame.at(middle, _y + TABLE_HIGH * 0.5, out), frame.size(TABLE_LONG, TABLE_HIGH, 1.2), "gold", true)
		parts.append({"kind": "offering", "room": _room, "trigger": table.id, "at": switch_at[table.id], "size": frame.size(TABLE_LONG - 0.2, 0.6, 1.0)})
		_area(0.9)

	# --- The bay, and over it the loft if there is one: its lip is caught from this side
	_clear()
	var under := 0.0
	if loft:
		# (room to run at its lip)
		_area(1.4)
		under = _u
		_area(0.2)
	var bay := _area(BAY)
	var middle := (bay.u0 + bay.u1) * 0.5
	# A block for the plate of another room stands in line with the way to that room.
	for thing in plan.things:
		if thing.room != room.id or thing.kind != TombPlan.Item.BLOCK:
			continue
		var lane := frame.turn
		for out: Array in outs:
			var link: TombPlan.Link = out[0]
			if link.a == thing.dest or link.b == thing.dest:
				lane = out[1]
		thing_at[thing.id] = frame.at(middle, _y + BLOCK * 0.5, 0.0)
		parts.append({"kind": "block", "room": _room, "thing": thing.id, "serves": _plate_in(thing.dest), "lane": lane % 2, "at": thing_at[thing.id]})
		moves.append({"kind": "door", "is": PASSAGE, "room": _room})
	info["east"] = frame.at(middle, _y, WALK)
	info["e"] = _point(info["east"], room.id)
	_line(info["w"], info["e"])
	info["centre"] = frame.at(middle, _y, 0.0)
	parts.append({"kind": "check", "room": _room, "at": info["east"], "along": frame.dir(), "wide": _w})
	if _sky:
		# (he is out once he is clear of the bay before the door)
		exit_at = frame.at(bay.u0 - 0.5, _y, 0.0)

	if loft:
		var top := _y + LOFT_TOP
		_box(frame.at((under + _u) * 0.5, top - LOFT_SLAB * 0.5, 0.0), frame.size(_u - under, LOFT_SLAB, _w), "loft", true)
		var up := {"floor": top, "turn": frame.turn, "edge": frame.at(under, top, WALK),
				"west": frame.at(under + 1.0, top, WALK), "east": frame.at(_u - 1.0, top, WALK),
				"boxes": [_aabb(frame.at(under - 0.3, top - 0.4, -_w * 0.5), frame.at(_u, top + LOFT_ROOM, _w * 0.5))]}
		up["w"] = _point(up["west"], loft.id)
		up["e"] = _point(up["east"], loft.id)
		_line(up["w"], up["e"])
		rooms[loft.id] = up
		moves.append({"kind": "ledge", "is": LOFT_TOP, "room": loft.id})
		moves.append({"kind": "under", "is": LOFT_TOP - LOFT_SLAB, "room": _room})
		parts.append({"kind": "torch", "room": _room, "at": frame.at((under + _u) * 0.5, top + 1.5, -_w * 0.5 + 0.05), "yaw": frame.yaw()})
		parts.append({"kind": "cobweb", "room": _room, "at": frame.at(under + 2.0, top + (_ceil - top) * 0.5, 0.0), "size": Vector2(_w, _ceil - top), "yaw": frame.yaw(PI * 0.5)})
		for trigger in plan.triggers:
			if trigger.room == loft.id:
				_seal(trigger, frame.at(_u - 1.2, top, WALK))
	_light(room, bay.u0, outs)
	info["long"] = _u
	rooms[room.id] = info
	return _u


# The burial chamber: the sarcophagus, the treasure at the far end, and beyond
# it whatever guards it, which wakes behind him as he takes it.
func _set_burial(room: TombPlan.Room, info: Dictionary, with_bay: bool) -> void:
	var held := Vector3.INF
	if room.mummy >= 0:
		_area(1.6)
		held = _f.at(_u, _y, 0.0)
		_barrier(room.barrier)
		_area(1.0)
	var hall := _area(8.0)
	_prop("sarcophagus", _f.at(hall.u0 + 3.2, _y, 1.9), _f.yaw(PI * 0.5))
	_prop("statue_anubis", _f.at(hall.u0 + 6.1, _y, -_w * 0.5 + 0.9), _f.yaw(PI * 0.5))
	_prop("statue_anubis", _f.at(hall.u0 + 6.1, _y, _w * 0.5 - 0.9), _f.yaw(-PI * 0.5))
	_prop("pot_large", _f.at(hall.u0 + 0.4, _y, -_w * 0.5 + 0.6), 0.0)
	for k in 2:
		for side: float in [-1.0, 1.0]:
			parts.append({"kind": "pillar", "room": _room, "solid": true, "high": _ceil - _y, "at": _f.at(hall.u0 + 1.4 + k * 3.4, _y, side * (_w * 0.5 - 1.3))})
	var plinth := _area(2.0)
	var goal := plan.goal_trigger()
	var middle := (plinth.u0 + plinth.u1) * 0.5
	switch_at[goal.id] = _f.at(middle, _y, 0.0)
	stand_at[goal.id] = _f.at(middle - 0.85, _y, 0.0)
	parts.append({"kind": "treasure", "room": _room, "trigger": goal.id, "at": switch_at[goal.id]})
	parts.append({"kind": "inscription", "room": _room, "link": -1, "hint": "treasure", "at": _f.at(plinth.u0, _y + 2.6, -_w * 0.5 + 0.02), "yaw": _f.yaw()})
	info["east"] = _f.at(plinth.u0 - 0.8, _y, WALK)
	if room.mummy >= 0:
		var niche := _area(2.6)
		parts.append({"kind": "mummy", "room": _room, "what": room.mummy, "guardian": true, "at": _f.at(niche.u1 - 0.9, _y, 1.4),
				"safe_at": held, "safe_way": -_f.dir(), "wake": 3.0})
		parts.append({"kind": "jackal", "room": _room, "at": _f.at(niche.u1 - 0.9, _y, -2.4)})
	if with_bay:
		var bay := _area(BAY)
		info["east"] = _f.at((bay.u0 + bay.u1) * 0.5, _y, WALK)
	info["e"] = _point(info["east"], room.id)
	_line(info["w"], info["e"])
	info["centre"] = _f.at(_u - BAY * 0.5, _y, 0.0)
	info["long"] = _u


# The chamber at the foot of the well: under the floor he came in by.
func _set_crypt(crypt: TombPlan.Room, shaft: Area) -> void:
	var floor := shaft.floor
	var west := shaft.u0 - CRYPT_LONG
	var top := floor + WELL_DEEP - ROCK
	var kept := _u
	_u = west
	var under := _area(CRYPT_LONG, top)
	under.floor = floor
	_u = kept
	var down := {"floor": floor, "turn": _f.turn, "west": _f.at(west + 1.0, floor, WALK), "east": _f.at(shaft.u0 + 0.6, floor, WALK),
			"before": _f.at(shaft.u0 - 0.9, _y, WALK), "over": _f.at(shaft.u1 + 0.9, _y, WALK),
			"boxes": [_aabb(_f.at(west - 0.3, floor - 1.0, -_w * 0.5), _f.at(shaft.u1 + 0.3, floor + 1.0, _w * 0.5))]}
	down["w"] = _point(down["west"], crypt.id)
	down["e"] = _point(down["east"], crypt.id)
	_line(down["w"], down["e"])
	rooms[crypt.id] = down
	parts.append({"kind": "torch", "room": _room, "at": _f.at(west + CRYPT_LONG * 0.5, floor + 1.7, -_w * 0.5 + 0.05), "yaw": _f.yaw()})
	_prop("pot_large", _f.at(west + 0.5, floor, _w * 0.5 - 0.6), 0.0)
	for trigger in plan.triggers:
		if trigger.room == crypt.id:
			_seal(trigger, _f.at(west + 1.3, floor, WALK))
	moves.append({"kind": "fall", "is": WELL_DEEP, "room": crypt.id})


# Torches along the walls of a room that has them (never more than three: each
# is a light), on one side and then the other, and a band of signs.
func _light(room: TombPlan.Room, bay_from: float, outs: Array) -> void:
	if room.dark or _sky:
		if _sky:
			# (two bowls of fire either side of the way in)
			for side: float in [-1.0, 1.0]:
				parts.append({"kind": "bowl", "room": _room, "at": _f.at(_u - 0.7, _y, side * (PASSAGE * 0.5 + 0.9))})
		return
	if _ceil - _y < 2.8:
		return
	# (not where a way leaves the bay through that wall)
	var open := [false, false]
	for out: Array in outs:
		var turned := (int(out[1]) - _f.turn + 4) % 4
		if turned == 3:
			open[0] = true
		elif turned == 1:
			open[1] = true
	var count := clampi(int(_u / 7.0) + 1, 1, 3)
	for n in count:
		var right := n % 2 == 1
		var along := _u * (n + 0.5) / count
		if along > bay_from - 0.6 and open[1 if right else 0]:
			along = bay_from - 0.8
		parts.append({"kind": "torch", "room": _room, "at": _f.at(along, _y + 2.3, (_w * 0.5 - 0.05) * (1.0 if right else -1.0)), "yaw": _f.yaw(PI if right else 0.0)})
	var long := minf(bay_from - 1.0, 10.0)
	if long > 3.0 and _ceil - _y >= 3.4:
		parts.append({"kind": "glyphs", "room": _room, "at": _f.at(0.5, _y + 2.9, -_w * 0.5 + 0.01), "long": long, "yaw": _f.yaw()})


# --- A way between two rooms

# The passage from the bay of `link.a` to `link.b`, with whatever the way is
# in it, and `filler` metres of plain passage to make up the distance. `frame`
# is where it leaves the bay, and which way. Returns how long it is.
func _set_way(link: TombPlan.Link, frame: Frame, filler: float) -> float:
	var a := plan.rooms[link.a]
	var b := plan.rooms[link.b]
	_f = frame
	_room = a.id
	_u = 0.0
	_y = frame.origin.y
	_w = PASSAGE
	_sky = false
	_most = PASSAGE * 0.5
	_ceil = _y + PASSAGE_HIGH
	var kind := link.pass_kind
	var loft := plan.side_room(a.id, TombPlan.Role.LOFT)
	# (a loft is over the bay, so the doorway under it is a low one; and where
	# the way on from the loft is a drop into the next room, it goes on over this way)
	var over := false
	if loft:
		for other in plan.links:
			over = over or (other.pass_kind == TombPlan.Pass.DROP and other.a == loft.id and other.b == b.id)
	var way_high := LOFT_TOP - LOFT_SLAB if loft else DOORWAY
	var top := _y + LOFT_TOP
	var roof := top + LOFT_ROOM if over else _y + PASSAGE_HIGH
	var way := {"turn": frame.turn, "from": frame.at(0.0, _y, WALK)}
	var turned := (frame.turn - maxi(turns[a.id], 0) + 4) % 4
	var last := -1
	if rooms[a.id].has("e"):
		# (where his line through the room meets his line down the passage)
		var corner := frame.at(0.0, _y, WALK)
		var east: Vector3 = rooms[a.id]["east"]
		corner += frame.dir() * (east - corner).dot(frame.dir())
		last = _point(corner, a.id)
		_line(rooms[a.id]["e"], last)

	# --- This side of it: the wall, and the door in it
	match kind:
		TombPlan.Pass.CRAWL:
			var tunnel := _area(CRAWL_LONG, _y + CRAWL_HIGH, WALK - 0.7, WALK + 0.7)
			tunnel.gate = true
			moves.append({"kind": "crawl", "is": CRAWL_HIGH, "room": _room})
			parts.append({"kind": "cobweb", "room": _room, "at": frame.at(-0.3, _y + 1.0, WALK), "size": Vector2(1.8, 2.0), "yaw": frame.yaw(PI * 0.5)})
		TombPlan.Pass.SHAFT, TombPlan.Pass.ROPE, TombPlan.Pass.SAND:
			# (no wall: the bay opens onto the head of the ladder or the rope, or the foot of the face)
			pass
		_:
			var gate := _area(WALL, roof if over else _y + way_high)
			gate.gate = true
			if loft:
				moves.append({"kind": "under", "is": way_high, "room": _room})
			if not link.switches.is_empty():
				door_at[link.id] = frame.at(WALL * 0.5, _y + way_high * 0.5, 0.0)
				parts.append({"kind": "door", "room": _room, "link": link.id, "at": door_at[link.id],
						"size": frame.size(0.5, way_high, PASSAGE - 0.1), "sinks": over})
				_sign(link, frame, turned, float(rooms[a.id].get("wide", PASSAGE)), _y + way_high + 0.5 if not loft else -1.0)
	if kind == TombPlan.Pass.GAP:
		# A pit too wide to jump, in a chamber high enough to swing in, and the ring over the middle of it.
		# The pit is wider than the way to it: its side walls are too far from
		# his line, and from each other, to be kicked off across it.
		var high := _y + GAP_ROOM
		var approach := _area(2.6, high)
		var gulf := _area(GAP_WIDE, high, -PASSAGE * 0.5 - GAP_SIDE, PASSAGE * 0.5 + GAP_SIDE)
		gulf.floor = _y - PIT_DEEP
		gulf.deadly = true
		_area(1.6, high)
		parts.append({"kind": "ring", "room": _room, "at": frame.at((gulf.u0 + gulf.u1) * 0.5, _y + RING_HIGH, WALK)})
		moves.append({"kind": "swing", "is": GAP_WIDE, "room": _room, "high": RING_HIGH, "apart": PASSAGE + GAP_SIDE * 2.0})
		way["gap"] = [frame.at(approach.u1, _y, WALK), frame.at(gulf.u1, _y, WALK)]
		var near := _point(frame.at(approach.u1 - 0.7, _y, WALK), a.id)
		_line(last, near)
		last = _point(frame.at(gulf.u1 + 0.7, _y, WALK), a.id)
	if filler > 0.01:
		var plain := _area(filler, roof)
		if filler >= 5.0 and not a.dark:
			parts.append({"kind": "torch", "room": _room, "at": frame.at((plain.u0 + plain.u1) * 0.5, _y + 2.1, -PASSAGE * 0.5 + 0.05), "yaw": frame.yaw()})

	# --- The far side of it: what the way is, and so down (or up) to the room it goes to
	_room = b.id
	match kind:
		TombPlan.Pass.STAIRS:
			var flights := maxi(cells[b.id].y - cells[a.id].y, 1)
			var high := maxf(_y + 3.4, roof)
			for step in STEPS * flights:
				_y -= LEVEL / STEPS
				_area(STEP_RUN, high)
			moves.append({"kind": "step", "is": LEVEL / STEPS, "room": _room})
			if over:
				# The loft from the room before ends a little past the foot of the stairs.
				var landing := _area(1.6, roof)
				var lip := landing.u0 + 0.5
				_box(frame.at(lip * 0.5, top - LOFT_SLAB * 0.5, 0.0), frame.size(lip, LOFT_SLAB, PASSAGE), "loft", true, a.id)
				moves.append({"kind": "drop", "is": top - _y, "room": _room, "walled": true})
				var up := rooms[loft.id]
				if up.has("w"):
					up["east"] = frame.at(lip - 0.6, top, WALK)
					(up["boxes"] as Array).append(_aabb(frame.at(-0.2, top - 0.4, -PASSAGE * 0.5), frame.at(lip + 0.3, top + LOFT_ROOM, PASSAGE * 0.5)))
					var corner := frame.at(0.0, top, WALK)
					corner += frame.dir() * ((up["west"] as Vector3) - corner).dot(frame.dir())
					var bend := _point(corner, loft.id)
					_line(up["w"], bend)
					up["e"] = _point(up["east"], loft.id)
					_line(bend, up["e"])
		TombPlan.Pass.FLOOD:
			var high := _y + 3.4
			_area(1.0, high)
			var basin := _area(POOL_LONG, high)
			basin.floor = _y - POOL_DEEP
			holes.append(_aabb(frame.at(basin.u0, _y - POOL_DEEP - 1.0, -PASSAGE * 0.5), frame.at(basin.u1, _y - POOL_BELOW - 0.25, PASSAGE * 0.5)))
			parts.append({"kind": "pool", "room": _room, "at": frame.at((basin.u0 + basin.u1) * 0.5, _y - POOL_BELOW, 0.0),
					"size": frame.size(POOL_LONG, POOL_DEEP - POOL_BELOW, PASSAGE)})
			parts.append({"kind": "torch", "room": _room, "at": frame.at((basin.u0 + basin.u1) * 0.5, _y + 2.2, -PASSAGE * 0.5 + 0.05), "yaw": frame.yaw()})
			moves.append({"kind": "swim_out", "is": POOL_BELOW, "room": _room})
			moves.append({"kind": "swim_deep", "is": POOL_DEEP - POOL_BELOW, "room": _room})
		TombPlan.Pass.SHAFT:
			# The floor ends, and a ladder goes down the face under it, on his line.
			var head := _y
			var deep := LEVEL * SHAFT_LEVELS
			_y -= deep
			parts.append({"kind": "ladder", "room": _room, "at": frame.at(_u + 0.06, _y, WALK), "high": deep, "yaw": frame.yaw(PI * 0.5)})
			var lip := _point(frame.at(_u - 0.8, head, WALK), a.id)
			_line(last, lip)
			last = _point(frame.at(_u + 1.0, _y, WALK), b.id)
			_line(lip, last)
			_area(2.0, head + 2.6)
			moves.append({"kind": "ladder", "is": deep, "room": _room})
		TombPlan.Pass.ROPE:
			# The floor ends over a shaft, and a rope hangs down it from a beam under the roof, clear of the face.
			var head := _y
			var deep := LEVEL * SHAFT_LEVELS
			_y -= deep
			var tied := head + ROPE_OVER
			parts.append({"kind": "rope", "room": _room, "at": frame.at(_u + ROPE_OUT, tied, WALK), "long": tied - _y - ROPE_CLEAR,
					"beam": frame.size(0.16, 0.14, PASSAGE), "beam_at": frame.at(_u + ROPE_OUT, tied + 0.03, 0.0)})
			_sign(link, frame, turned, float(rooms[a.id].get("wide", PASSAGE)), -1.0, "rope")
			way["lip"] = frame.at(_u, head, WALK)
			way["rope"] = frame.at(_u + ROPE_OUT, tied, WALK)
			way["upper"] = frame.at(_u - 1.6, head, WALK)
			way["lower"] = frame.at(_u + ROPE_OUT + 1.3, _y, WALK)
			_line(last, _point(way["upper"], a.id))
			last = _point(way["lower"], b.id)
			_area(ROPE_WIDE, tied + 0.1)
			moves.append({"kind": "rope", "is": deep, "out": ROPE_OUT, "over": ROPE_OVER, "clear": ROPE_CLEAR, "room": _room})
		TombPlan.Pass.SAND:
			# The foot of a face he cannot get up: the seal stone that lets the
			# sand in, if it is here, and then a chamber for the heap. The sand
			# comes out of the roof hard by the face, over his line, so that the
			# top of the heap is under the lip, a hop short of it. Only the half of
			# the heap this side of the face is seen: the rest is in the rock.
			#
			# The chamber is a good deal wider than the way on over the face
			# (`SAND_SIDE` to either side of it). At a corner he can kick off the
			# one wall and catch at the top of the other, which gets him a metre
			# higher than a jump does: so the lip is kept that far from any corner,
			# and the face beside it goes on up to the roof.
			_room = a.id
			var seal := false
			for id in link.switches:
				var trigger := plan.triggers[id]
				if trigger.kind == TombPlan.Switch.LEVER and trigger.room == a.id:
					_area(1.6)
					_seal(trigger, frame.at(_u - 0.8, _y, WALK))
					seal = true
			if not seal:
				_area(THROAT)
			var reach := SAND_PILE * SAND_SKIRT
			var half := PASSAGE * 0.5 + SAND_SIDE
			var heap := _area(SAND_OUT + reach, _y + SAND_RISE + SAND_ROOM, -half, half)
			door_at[link.id] = frame.at(_u, _y + SAND_RISE, 0.0)
			parts.append({"kind": "sand", "room": _room, "link": link.id, "at": frame.at(_u - SAND_OUT, heap.ceil, WALK), "cap": SAND_PILE})
			if link.hint != "":
				parts.append({"kind": "inscription", "room": _room, "link": link.id, "hint": link.hint,
						"at": frame.at(_u - 0.02, _y + 1.9, -PASSAGE * 0.5 - 1.2), "yaw": frame.yaw(-PI * 0.5)})
			if not a.dark:
				for side: float in [-1.0, 1.0]:
					parts.append({"kind": "torch", "room": _room, "at": frame.at(heap.u0 + 2.2, _y + 2.6, side * (half - 0.05)), "yaw": frame.yaw(0.0 if side < 0.0 else PI)})
			moves.append({"kind": "sand", "is": SAND_RISE, "pile": SAND_PILE, "skirt": SAND_SKIRT, "room": _room})
			moves.append({"kind": "corner", "is": SAND_RISE, "aside": SAND_SIDE, "room": _room})
			way["before"] = frame.at(heap.u0 - 0.6, _y, WALK)
			way["face"] = frame.at(_u, _y, WALK)
			_line(last, _point(way["before"], a.id))
			_y += SAND_RISE
			way["top"] = frame.at(_u + 0.8, _y, WALK)
			last = _point(way["top"], b.id)
			_room = b.id
			# (and the way on over it is no wider than a passage, whatever the room beyond is)
			_area(THROAT, _y + PASSAGE_HIGH)
	# (and so into the room: at its way in, or for a way that closes a loop, its bay)
	var into: Dictionary = rooms[b.id]
	if into.has("w") and last >= 0:
		_line(last, into["w"] if _in[b.id] == link.id else into["e"])
	way["to"] = frame.at(_u, _y, WALK)
	ways[link.id] = way
	_wides[link.id] = _most
	return _u


# What is written by a door: over it, or where a loft leaves no wall over it
# (`high` is -1), on the wall beside it. (And at the head of a rope.)
func _sign(link: TombPlan.Link, frame: Frame, turned: int, wide: float, high: float, hint := "") -> void:
	var at := frame.at(-0.02, high, 0.0)
	var yaw := frame.yaw(-PI * 0.5)
	if high < 0.0:
		var level := _y + 0.95 if hint == "" else _y + 1.6
		match turned:
			1:
				at = frame.at(-1.3, level, -BAY * 0.5 + 0.02)
				yaw = frame.yaw()
			3:
				at = frame.at(-1.3, level, BAY * 0.5 - 0.02)
				yaw = frame.yaw(PI)
			_:
				at = frame.at(-1.3, level, -wide * 0.5 + 0.02)
				yaw = frame.yaw()
	parts.append({"kind": "inscription", "room": _room, "link": link.id, "hint": hint if hint != "" else link.hint, "at": at, "yaw": yaw})


# --- The pieces

# A stretch of floor, from wall to wall unless it is told how wide.
func _area(long: float, ceil := INF, left := INF, right := INF) -> Area:
	var area := Area.new()
	var one := _f.at(_u, 0.0, -_w * 0.5 if left == INF else left)
	var other := _f.at(_u + long, 0.0, _w * 0.5 if right == INF else right)
	area.x0 = minf(one.x, other.x)
	area.x1 = maxf(one.x, other.x)
	area.z0 = minf(one.z, other.z)
	area.z1 = maxf(one.z, other.z)
	area.u0 = _u
	area.u1 = _u + long
	area.floor = _y
	area.ceil = _ceil if ceil == INF else ceil
	area.room = _room
	area.sky = _sky
	if left != INF:
		_most = maxf(_most, maxf(absf(left), absf(right)))
	areas.append(area)
	_u += long
	return area


func _aabb(one: Vector3, other: Vector3) -> AABB:
	return AABB(one, Vector3.ZERO).expand(other)


func _point(at: Vector3, room: int) -> int:
	walk_points.append(at)
	walk_rooms.append(room)
	return walk_points.size() - 1


func _line(one: int, other: int) -> void:
	if one >= 0 and other >= 0 and one != other:
		walk_lines.append(Vector2i(one, other))


func _seal(trigger: TombPlan.Trigger, at: Vector3) -> void:
	switch_at[trigger.id] = at
	stand_at[trigger.id] = at
	parts.append({"kind": "lever", "room": _room, "trigger": trigger.id, "at": at, "size": Vector3(1.2, 0.5, 1.2)})


# A plate in the lane `out` from the middle, and what stops the block on it.
func _pad(trigger: TombPlan.Trigger, out: float) -> void:
	var slab := _area(1.5)
	switch_at[trigger.id] = _f.at((slab.u0 + slab.u1) * 0.5, _y, out)
	stand_at[trigger.id] = switch_at[trigger.id]
	parts.append({"kind": "plate", "room": _room, "trigger": trigger.id, "at": switch_at[trigger.id], "size": _f.size(1.5, 0.5, PAD)})
	_box(_f.at(_u + STOP_THICK * 0.5, _y + STOP_HIGH * 0.5, out), _f.size(STOP_THICK, STOP_HIGH, PAD + 0.2), "kerb", true)
	moves.append({"kind": "stop", "is": STOP_HIGH, "room": _room})
	_area(0.9)


# The plate in `room` that a block from the room before is for.
func _plate_in(room: int) -> int:
	for trigger in plan.triggers:
		if trigger.kind == TombPlan.Switch.PLATE and trigger.room == room:
			return trigger.id
	return -1


# Whether a seal stone in `room` is what lets the sand in on a way out of it
# (then it is at the foot of the face, not just inside the room).
func _lets_sand_in(trigger: TombPlan.Trigger, room: int) -> bool:
	for link in plan.links:
		if link.a == room and link.pass_kind == TombPlan.Pass.SAND and trigger.id in link.switches:
			return true
	return false


# Plain floor as far as the rock has to be left whole for a heap of sand (and `beyond`).
func _clear(beyond := 0.0) -> void:
	if _u < _clear_to + beyond:
		_area(_clear_to + beyond - _u)


# What a mummy cannot get past, from wall to wall: he can.
func _barrier(kind: TombPlan.Barrier) -> void:
	match kind:
		TombPlan.Barrier.TRENCH:
			_clear()
			var trench := _area(TRENCH_WIDE)
			trench.floor = _y - TRENCH_DEEP
			moves.append({"kind": "jump", "is": TRENCH_WIDE, "room": _room})
			moves.append({"kind": "ledge", "is": TRENCH_DEEP, "room": _room})
		TombPlan.Barrier.KERB:
			_area(0.4)
			_box(_f.at(_u + KERB_THICK * 0.5, _y + KERB_HIGH * 0.5, 0.0), _f.size(KERB_THICK, KERB_HIGH, _w), "kerb", true)
			moves.append({"kind": "hop", "is": KERB_HIGH, "room": _room})
			_area(0.6)
		TombPlan.Barrier.NARROW:
			# Two piers with a gap between them on his line: one to the roof, the other low enough to see over.
			_area(0.4)
			var left := WALK - SLOT_WIDE * 0.5 + _w * 0.5
			var right := _w * 0.5 - WALK - SLOT_WIDE * 0.5
			_box(_f.at(_u + 0.25, (_y + _ceil) * 0.5, -_w * 0.5 + left * 0.5), _f.size(0.5, _ceil - _y, left), "wall", true)
			_box(_f.at(_u + 0.25, _y + 0.5, _w * 0.5 - right * 0.5), _f.size(0.5, 1.0, right), "wall", true)
			moves.append({"kind": "slot", "is": SLOT_WIDE, "room": _room})
			_area(0.8)


# --- The stone round the air

# Every edge of every piece of air, and a wall's thickness out from it, cuts
# the plan into a grid. Each square of the grid is then air (one piece over
# another, where there is a crypt) or stone, and the stone that touches air is
# drawn: a floor under it down past the lowest floor beside it, a roof over it
# up past the highest roof beside it, and a wall from below the one to above
# the other, each in one piece from top to bottom (two pieces meeting in a level
# seam on a face he can jump at would be taken by his hands for a ledge). What
# has the same top and bottom and lies together is then made one box.
func _shell() -> void:
	var xs := {}
	var zs := {}
	for area in areas:
		for x: float in [area.x0, area.x1, area.x0 - THICK, area.x1 + THICK]:
			xs[roundi(x * 1000.0)] = true
		for z: float in [area.z0, area.z1, area.z0 - THICK, area.z1 + THICK]:
			zs[roundi(z * 1000.0)] = true
	var xl: Array = xs.keys()
	var zl: Array = zs.keys()
	xl.sort()
	zl.sort()
	var xi := {}
	var zi := {}
	for i in xl.size():
		xi[xl[i]] = i
	for j in zl.size():
		zi[zl[j]] = j
	var air := {}
	for n in areas.size():
		var area := areas[n]
		for i in range(int(xi[roundi(area.x0 * 1000.0)]), int(xi[roundi(area.x1 * 1000.0)])):
			for j in range(int(zi[roundi(area.z0 * 1000.0)]), int(zi[roundi(area.z1 * 1000.0)])):
				var key := i * 100000 + j
				if air.has(key):
					(air[key] as Array).append(n)
				else:
					air[key] = [n]
	# The lowest floor and the highest roof of each square of air.
	var low := {}
	var high := {}
	for key: int in air:
		var here: Array = air[key]
		here.sort_custom(func(one: int, other: int) -> bool: return areas[one].floor < areas[other].floor)
		low[key] = areas[here[0]].floor
		high[key] = areas[here[-1]].ceil
	var around: Array[int] = [-100001, -100000, -99999, -1, 1, 99999, 100000, 100001]
	var pieces := {}
	var walls := {}
	for key: int in air:
		var here: Array = air[key]
		var lowest: float = low[key]
		var highest: float = high[key]
		for by in around:
			if air.has(key + by):
				lowest = minf(lowest, low[key + by])
				highest = maxf(highest, high[key + by])
			else:
				walls[key + by] = true
		var first := areas[here[0]]
		var last := areas[here[-1]]
		if _crowded:
			# Where a low room meets higher air (the foot of a loft's drop, a tall
			# chamber) the stone over the low room is a wall to that air, as thick
			# as the square it is over; and in a plan with cells a square can be a
			# hand's breadth, cut by the edge of a room off to one side. A wall
			# that thin he could reach over, to the top of the low roof behind it.
			# So here the roof stands as high as any air within a wall's thickness.
			highest = maxf(highest, _highest_near(key, xl, zl, air, high))
		_piece(pieces, key, lowest - ROCK, first.floor, "sand" if first.sky else "floor", first.room)
		for n in range(1, here.size()):
			var under := areas[here[n - 1]]
			var over := areas[here[n]]
			if over.floor > under.ceil + 0.001:
				_piece(pieces, key, under.ceil, over.floor, "floor", over.room)
		if not last.sky:
			_piece(pieces, key, last.ceil, highest + ROCK, "wall" if last.gate or highest > last.ceil + 0.01 else "rock", last.room)
		if first.deadly:
			# (he dies in it before he is at the bottom)
			pass
	for key: int in walls:
		var lowest := INF
		var highest := -INF
		var room := 1000000
		var open := true
		for by in around:
			if not air.has(key + by):
				continue
			lowest = minf(lowest, low[key + by])
			highest = maxf(highest, high[key + by])
			var here: Array = air[key + by]
			room = mini(room, areas[here[0]].room)
			open = open and areas[here[-1]].sky
		_piece(pieces, key, lowest - ROCK, highest + ROCK, "rock" if open else "wall", room)
	var kinds := pieces.keys()
	kinds.sort()
	for kind: String in kinds:
		var said := kind.split("|")
		var bottom := float(said[0]) / 1000.0
		var top := float(said[1]) / 1000.0
		var squares: Array = pieces[kind]
		squares.sort()
		var left := {}
		for key: int in squares:
			left[key] = true
		for key: int in squares:
			if not left.has(key):
				continue
			var i0 := key / 100000
			var j0 := key % 100000
			var j1 := j0 + 1
			while left.has(i0 * 100000 + j1):
				j1 += 1
			var i1 := i0 + 1
			while true:
				var whole := true
				for j in range(j0, j1):
					whole = whole and left.has(i1 * 100000 + j)
				if not whole:
					break
				i1 += 1
			for i in range(i0, i1):
				for j in range(j0, j1):
					left.erase(i * 100000 + j)
			var from := Vector3(float(xl[i0]) / 1000.0, bottom, float(zl[j0]) / 1000.0)
			var to := Vector3(float(xl[i1]) / 1000.0, top, float(zl[j1]) / 1000.0)
			boxes.append([(from + to) * 0.5, to - from, said[2], true, int(said[3])])
	for area in areas:
		if area.deadly:
			parts.append({"kind": "death", "room": area.room, "at": Vector3((area.x0 + area.x1) * 0.5, area.floor + 1.5, (area.z0 + area.z1) * 0.5),
					"size": Vector3(area.x1 - area.x0, 3.0, area.z1 - area.z0)})


# The highest roof of any air within a wall's thickness of a square of the
# grid (`xl`, `zl`: the grid's lines, in thousandths of a metre).
func _highest_near(key: int, xl: Array, zl: Array, air: Dictionary, high: Dictionary) -> float:
	var i := key / 100000
	var j := key % 100000
	var reach := roundi(THICK * 1000.0)
	var i0 := i
	while i0 > 0 and int(xl[i]) - int(xl[i0]) < reach:
		i0 -= 1
	var i1 := i
	while i1 < xl.size() - 2 and int(xl[i1 + 1]) - int(xl[i + 1]) < reach:
		i1 += 1
	var j0 := j
	while j0 > 0 and int(zl[j]) - int(zl[j0]) < reach:
		j0 -= 1
	var j1 := j
	while j1 < zl.size() - 2 and int(zl[j1 + 1]) - int(zl[j + 1]) < reach:
		j1 += 1
	var found := -INF
	for a in range(i0, i1 + 1):
		for b in range(j0, j1 + 1):
			if air.has(a * 100000 + b):
				found = maxf(found, high[a * 100000 + b])
	return found


func _piece(pieces: Dictionary, key: int, bottom: float, top: float, made_of: String, room: int) -> void:
	var kind := "%d|%d|%s|%d" % [roundi(bottom * 1000.0), roundi(top * 1000.0), made_of, room]
	if pieces.has(kind):
		(pieces[kind] as Array).append(key)
	else:
		pieces[kind] = [key]


# How many ways lie between each two rooms.
func _count_hops() -> void:
	var count := plan.rooms.size()
	_hops.resize(count)
	for from in count:
		var far: Array[int] = []
		far.resize(count)
		far.fill(99)
		far[from] = 0
		var queue: Array[int] = [from]
		while not queue.is_empty():
			var at: int = queue.pop_front()
			for link in _joins():
				if link.a != at and link.b != at:
					continue
				var to := link.b if link.a == at else link.a
				if far[to] > far[at] + 1:
					far[to] = far[at] + 1
					queue.append(to)
		_hops[from] = far


# --- What a level asks of it

func walked() -> bool:
	return true


func placed() -> Array[TombPlan.Room]:
	var found: Array[TombPlan.Room] = []
	for room in plan.rooms:
		if not is_side(room):
			found.append(room)
	return found


func room_of(at: Vector3) -> int:
	for area in areas:
		if at.x >= area.x0 - 0.3 and at.x <= area.x1 + 0.3 and at.z >= area.z0 - 0.3 and at.z <= area.z1 + 0.3 \
				and at.y >= area.floor - 1.0 and at.y <= area.ceil + 0.5:
			_last_room = area.room
			return area.room
	return _last_room


func plan_room_at(at: Vector3) -> int:
	for room in plan.rooms:
		if not is_side(room):
			continue
		for box: AABB in rooms[room.id].get("boxes", []):
			if box.has_point(at):
				return room.id
	return room_of(at)


func rooms_apart(one: int, other: int) -> int:
	return _hops[one][other]


func drawn_within() -> int:
	return 2


## In a plan that came with its cells a room has ways to every side, and the
## rooms within two ways of his can be ten: too many to draw on a phone, and
## most of them round a corner. There the rooms next to his are drawn, and of
## those two ways off only the ones straight on through a room next to his
## (on three squares in a line), which is as far as he sees through two doorways.
func is_drawn(room: int, here: int) -> bool:
	var apart := rooms_apart(room, here)
	if not _crowded or apart <= 1:
		return apart <= drawn_within()
	if apart > 2:
		return false
	for link in _joins():
		if link.a != here and link.b != here:
			continue
		var between := link.b if link.a == here else link.a
		var step := cells[between] - cells[here]
		var on := cells[room] - cells[between]
		if rooms_apart(between, room) == 1 and step.x == on.x and step.z == on.z:
			return true
	return false


func apart(one: Vector3, other: Vector3) -> float:
	return Vector2(one.x - other.x, one.z - other.z).length()


func is_out(at: Vector3) -> bool:
	return (at - exit_at).dot(exit_way) > 0.0 and room_of(at) == plan.entrance()


func is_sunk(at: Vector3) -> bool:
	for hole in holes:
		if hole.has_point(at):
			return true
	return false


func is_in_pit(at: Vector3, middle: Vector3, size: Vector3) -> bool:
	var from := at - middle
	return absf(from.x) < size.x * 0.5 and absf(from.z) < size.z * 0.5 and from.y < size.y * 0.5


func is_past(part: Dictionary, at: Vector3) -> bool:
	var from: Vector3 = part.get("safe_at", Vector3.INF)
	if from == Vector3.INF:
		return false
	return (at - from).dot(part["safe_way"]) > 0.0


func beside(spot: Vector3) -> Vector3:
	return spot + Vector3(0.0, 0.3, 0.0)


func is_at_check(part: Dictionary, at: Vector3, within: float) -> bool:
	# (anywhere across the room, as he goes by: he is not kept to the line it is on)
	var from: Vector3 = at - (part["at"] as Vector3)
	var along: Vector3 = part["along"]
	return absf(from.dot(along)) < within and absf(from.dot(Vector3(-along.z, 0.0, along.x))) < float(part["wide"]) * 0.5 + 0.5 and absf(from.y) < 1.2
