class_name TombLayout
extends RefCounted
## A plan set out as a tomb seen from the side: where every piece of stone and
## every working part goes, as plain numbers. No nodes are made here (that is
## `TombBuilder`), so it can be made, measured and compared with nothing drawn.
##
## The tomb is a section, like the drawings of the tombs in the Valley of the
## Kings: its axis runs along X and goes down as it goes in, he keeps to the
## line Z = 0, and everything nearer the camera than `FRONT` is cut away. Rooms
## off the axis are above (a loft: a slab he catches the edge of by jumping, and
## walks under otherwise) or below (the chamber at the foot of the well).
##
## A room is laid as a run of spans, each a stretch of floor and ceiling at one
## height; walls with doorways, stairs, pits and pools are all spans. The stone
## is then drawn round the spans (`_shell`).
##
## Every length here that he has to jump, climb, duck under or fit through is a
## constant below, and `moves` lists each one the tomb uses, for `TombReach`
## to hold against what the Player can really do.

# --- The section
## Where the back wall's face is, and where the tomb is cut open.
const BACK := -2.5
const FRONT := 2.5
## How thick the floors and ceilings are drawn, and the wall between two rooms.
const ROCK := 1.2
const WALL := 1.0
const FILL := 0.6
## How far down under a floor the rock is drawn (it is only to look at).
const UNDER := 3.0
## How high a doorway is, and the low one under a loft that goes on over it.
const DOORWAY := 2.4
const LOW_DOORWAY := 1.6
## The height of each kind of room (`TombPlan.Role`), floor to ceiling.
const HEIGHTS := [9.0, 3.4, 3.8, 4.8, 5.6, 3.6, 5.0, 0.0, 2.6]

# --- What he has to get past (see TombReach)
const STEP_RISE := 0.25
const STEP_RUN := 0.45
## A loft: how high its top is over the floor, and how thick it is.
const LOFT_TOP := 1.9
const LOFT_SLAB := 0.3
const LOFT_ROOM := 2.2
## A trench (it holds a mummy; he can get out of it) and a pit (he cannot).
const TRENCH_WIDE := 1.8
const TRENCH_DEEP := 1.2
const PIT_WIDE := 1.6
const PIT_DEEP := 7.0
## A kerb high enough to stop what cannot lift its feet, and the low one that
## stops a pushed block and nothing else.
const KERB_HIGH := 0.45
const KERB_THICK := 0.3
const STOP_HIGH := 0.25
const STOP_THICK := 0.24
## The gap between two piers that the brute is too wide for.
const SLOT_WIDE := 0.7
## The well, and the chamber at the foot of it.
const WELL_WIDE := 2.0
const WELL_STEP := 0.8
const WELL_DEEP := 3.8
const CRYPT_LONG := 4.0
## The pit the hook swings him over, and how high over its edges the ring is.
const GAP_WIDE := 5.5
const RING_HIGH := 6.1
const GAP_ROOM := 7.6
## A passage to go through bent double.
const CRAWL_HIGH := 0.8
const CRAWL_LONG := 2.4
## Water: how long, how deep the basin, and how far under its rim the water lies.
const POOL_LONG := 5.0
const POOL_DEEP := 2.2
const POOL_BELOW := 0.35
## A shaft with a ladder down it.
const SHAFT_DEEP := 4.5
## A block to push, and how far it has to go to its plate.
const BLOCK := 0.9
const TRACK := 2.6
## The low table that only a jar weighs down.
const TABLE_HIGH := 0.3
const TABLE_LONG := 1.4


class Span:
	var xa := 0.0
	var xb := 0.0
	var floor := 0.0
	var ceil := 0.0
	var room := 0
	## Nothing to stand on, and no coming out.
	var deadly := false
	## A wall with a way through it: the stone over it is solid from side to side.
	var wall := false
	## Solid all through: the end of the tomb.
	var solid := false
	## Out of doors: sand underfoot, nothing overhead or behind.
	var sky := false
	## No stone is put under the edge of the higher floor to the west of this.
	var open_west := false


var plan: TombPlan
var spans: Array[Span] = []
## Stone: each [middle, size, what it is made of, whether it is solid, room].
var boxes: Array = []
## Working parts, lights and dressing: each a Dictionary with `kind`, `at`, `room`.
var parts: Array[Dictionary] = []
## By the plan's room: `x0`, `x1`, `floor`, `west` and `east` (where he stands
## just inside each end), and for a loft `edge` (where its lip is caught).
var rooms: Array[Dictionary] = []
## By the plan's thing, switch and link: where it is.
var thing_at: Array[Vector3] = []
var switch_at: Array[Vector3] = []
var door_at: Array[Vector3] = []
## Everything in it that tests what he can do: `kind` and a length (see TombReach).
var moves: Array[Dictionary] = []
## Where a thing that is put down or dropped cannot be carried out again (the
## water, the well and the chamber under it): each is from x, to x, below y.
## What comes to rest there is put back where he last had it at a door.
var sunk: Array[Vector3] = []
var start := Vector3.ZERO
## He is out once he is west of this with the treasure.
var exit_x := 0.0
var length := 0.0
var depth := 0.0

var _rng: TombRandom
var _x := 0.0
var _y := 0.0
var _ceil := 0.0
var _room := 0
var _sky := false


## Sets out `plan`.
static func lay(from: TombPlan) -> TombLayout:
	var layout := TombLayout.new()
	layout.plan = from
	layout._lay()
	return layout


func _lay() -> void:
	_rng = TombRandom.new(TombRandom.mix([TombGenerator.VERSION, plan.seed_value, plan.difficulty, plan.sub_seed, 4177]))
	rooms.resize(plan.rooms.size())
	for i in rooms.size():
		rooms[i] = {}
	thing_at.resize(plan.things.size())
	switch_at.resize(plan.triggers.size())
	door_at.resize(plan.links.size())
	door_at.fill(Vector3.INF)
	var along := plan.spine()
	# (a loft that goes on over the wall into the next room: where it began, and how high)
	var over := {}
	for i in along.size():
		var room := along[i]
		var way_in := plan.spine_link(i - 1) if i > 0 else null
		var way_out := plan.spine_link(i) if i < along.size() - 1 else null
		over = _lay_room(room, way_in, way_out, over)
	length = _x
	depth = -_y
	_shell()


# One room on the axis, from the way in to the wall at its far end.
func _lay_room(room: TombPlan.Room, way_in: TombPlan.Link, way_out: TombPlan.Link, over: Dictionary) -> Dictionary:
	_room = room.id
	_sky = room.role == TombPlan.Role.ENTRANCE
	var high: float = HEIGHTS[room.role]
	var loft := plan.side_room(room.id, TombPlan.Role.LOFT)
	var crypt := plan.side_room(room.id, TombPlan.Role.CRYPT)
	var loops := false
	if loft:
		for link in plan.links_of(loft.id):
			if link.pass_kind == TombPlan.Pass.DROP:
				loops = true
	var info := {"x0": _x, "top": _y}

	# --- What the way in is made of, this side of the wall
	if way_in:
		match way_in.pass_kind:
			TombPlan.Pass.STAIRS:
				var steps := 8 if not over.is_empty() else _rng.between(4, 8)
				var roof := _y + 3.4
				if not over.is_empty():
					roof = maxf(roof, float(over["top"]) + LOFT_ROOM)
				for step in steps:
					_y -= STEP_RISE
					_span(STEP_RUN, roof)
				moves.append({"kind": "step", "is": STEP_RISE, "room": _room})
			TombPlan.Pass.FLOOD:
				_span(1.0, _y + high)
				var basin := _span(POOL_LONG, _y + high)
				basin.floor = _y - POOL_DEEP
				sunk.append(Vector3(basin.xa, basin.xb, _y - POOL_BELOW - 0.25))
				parts.append({"kind": "pool", "room": _room, "at": Vector3((basin.xa + basin.xb) * 0.5, _y - POOL_BELOW, 0.0),
						"size": Vector3(POOL_LONG, POOL_DEEP - POOL_BELOW, FRONT - BACK)})
				moves.append({"kind": "swim_out", "is": POOL_BELOW, "room": _room})
				moves.append({"kind": "swim_deep", "is": POOL_DEEP - POOL_BELOW, "room": _room})
			TombPlan.Pass.SHAFT:
				# The floor ends, and a ladder goes down the face under it.
				var top := _y
				_y -= SHAFT_DEEP
				parts.append({"kind": "ladder", "room": _room, "at": Vector3(_x + 0.06, _y, 0.0), "high": SHAFT_DEEP, "yaw": PI * 0.5})
				_span(2.0, top + 2.6)
				moves.append({"kind": "ladder", "is": SHAFT_DEEP, "room": _room})
	_ceil = _y + high
	if loft:
		_ceil = maxf(_ceil, _y + LOFT_TOP + LOFT_ROOM)
	if way_out and way_out.pass_kind == TombPlan.Pass.GAP:
		_ceil = maxf(_ceil, _y + GAP_ROOM)
	if not over.is_empty():
		# The loft from the room before ends a little past the foot of the stairs.
		var lip := _x + 0.5
		_slab(float(over["from"]), lip, float(over["top"]), int(over["room"]))
		rooms[int(over["room"])]["x1"] = lip
		rooms[int(over["room"])]["east"] = Vector3(lip - 0.6, float(over["top"]), 0.0)
		moves.append({"kind": "drop", "is": float(over["top"]) - _y, "room": _room})
		_span(1.6, maxf(_ceil, float(over["top"]) + LOFT_ROOM))
	info["floor"] = _y

	# --- Just inside: a seal stone that opens the door behind him, the things that lie here, a plate
	for trigger in plan.triggers:
		if trigger.room == room.id and trigger.kind == TombPlan.Switch.LEVER:
			var stone := _span(1.6, _ceil)
			_lever(trigger, (stone.xa + stone.xb) * 0.5, _y)
	var entry := _span(2.6, _ceil)
	info["west"] = Vector3(entry.xa + (2.2 if _sky else 1.0), _y, 0.0)
	if _sky:
		start = Vector3(entry.xa + 2.2, _y, 0.0)
		exit_x = entry.xa + 3.4
		var yard := _span(5.0, _ceil)
		for z: float in [BACK + 0.6, FRONT - 0.6]:
			parts.append({"kind": "bowl", "room": _room, "at": Vector3(yard.xb - 0.6, _y, z)})
	parts.append({"kind": "check", "room": _room, "at": info["west"]})
	# (the plate first: nothing may lie in the way of the block that is pushed to it)
	for trigger in plan.triggers:
		if trigger.room == room.id and trigger.kind == TombPlan.Switch.PLATE:
			_plate(trigger)
	for thing in plan.things:
		if thing.room != room.id or thing.kind == TombPlan.Item.BLOCK:
			continue
		var place := _span(1.3, _ceil)
		thing_at[thing.id] = Vector3((place.xa + place.xb) * 0.5, _y, 0.0)
		parts.append({"kind": "item", "room": _room, "thing": thing.id, "what": thing.kind, "at": thing_at[thing.id]})

	# --- What the room is
	match room.role:
		TombPlan.Role.WELL:
			_span(2.2, _ceil)
			var shaft := _span(WELL_WIDE, _ceil)
			shaft.floor = _y - WELL_DEEP
			shaft.open_west = crypt != null
			info["well"] = shaft.xa
			sunk.append(Vector3(shaft.xa - (CRYPT_LONG if crypt else 0.0), shaft.xb, _y - 1.0))
			# The way out is up the far side in two: a step half its depth, then
			# the floor. (Not a ladder: one at the lip takes hold of whoever walks
			# over it, and coming back he could not then jump the well.) So falling
			# in costs time and nothing else, and takes him on, not back.
			_box(Vector3(shaft.xb - WELL_STEP * 0.5, _y - WELL_DEEP * 0.75, 0.0), Vector3(WELL_STEP, WELL_DEEP * 0.5, FRONT - BACK), "floor", true)
			moves.append({"kind": "jump", "is": WELL_WIDE, "room": _room})
			moves.append({"kind": "ledge", "is": WELL_DEEP * 0.5, "room": _room})
			_span(1.6, _ceil)
			if crypt:
				_lay_crypt(crypt, shaft)
		TombPlan.Role.HALL:
			var hall := _span(float(_rng.between(5, 7)), _ceil)
			var pillars := int((hall.xb - hall.xa) / 2.4)
			for k in pillars:
				parts.append({"kind": "pillar", "room": _room, "at": Vector3(hall.xa + 1.2 + k * 2.4, _y, BACK + 0.55), "high": _ceil - _y})
		TombPlan.Role.GALLERY:
			_span(float(_rng.between(3, 5)), _ceil)
		TombPlan.Role.ANTECHAMBER:
			var ante := _span(float(_rng.between(4, 5)), _ceil)
			_prop("statue_anubis", Vector3((ante.xa + ante.xb) * 0.5, _y, BACK + 0.9), PI * 0.5)
		TombPlan.Role.CORRIDOR:
			_span(float(_rng.between(1, 3)), _ceil)

	if room.role == TombPlan.Role.BURIAL:
		_lay_burial(room, info)
		return {}

	# --- A mummy, and after it what holds it back
	if room.mummy >= 0:
		var niche := _span(4.0, _ceil)
		var mummy := {"kind": "mummy", "room": _room, "what": room.mummy, "guardian": false,
				"at": Vector3((niche.xa + niche.xb) * 0.5, _y, BACK + 0.7), "from": niche.xa, "to": niche.xb, "east": true}
		_barrier(room.barrier)
		# (he is out of its reach once he is this far on: nothing he has to stand at is nearer)
		mummy["safe"] = _x
		parts.append(mummy)
		_span(2.6, _ceil)
	if room.pit:
		var pit := _span(PIT_WIDE, _ceil)
		pit.floor = _y - PIT_DEEP
		pit.deadly = true
		moves.append({"kind": "jump", "is": PIT_WIDE, "room": _room})
		_span(1.2, _ceil)

	# --- What opens the way on, under the loft if there is one
	var under := 0.0
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
		var hearth := _span(2.4, _ceil)
		switch_at[fire.id] = Vector3((hearth.xa + hearth.xb) * 0.5, _y, -1.0)
		parts.append({"kind": "brazier", "room": _room, "trigger": fire.id, "at": switch_at[fire.id]})
		parts.append({"kind": "scarabs", "room": _room, "at": Vector3(hearth.xa - 1.0, _y, BACK + 0.4)})
	if work:
		var stand := _span(1.4 + BLOCK, _ceil)
		parts.append({"kind": "block", "room": _room, "thing": -1, "serves": work.id, "at": Vector3(stand.xb - BLOCK * 0.5, _y + BLOCK * 0.5, 0.0)})
		_span(TRACK - 1.5, _ceil)
		var slab := _span(1.5, _ceil)
		switch_at[work.id] = Vector3((slab.xa + slab.xb) * 0.5, _y, 0.0)
		parts.append({"kind": "plate", "room": _room, "trigger": work.id, "at": switch_at[work.id]})
		if table == null:
			_box(Vector3(_x + STOP_THICK * 0.5, _y + STOP_HIGH * 0.5, 0.0), Vector3(STOP_THICK, STOP_HIGH, FRONT - BACK), "kerb", true)
			moves.append({"kind": "stop", "is": STOP_HIGH, "room": _room})
			_span(0.9, _ceil)
	if table:
		# (the table stops the block too: it is a step the height of one)
		var dais := _span(TABLE_LONG, _ceil)
		switch_at[table.id] = Vector3((dais.xa + dais.xb) * 0.5, _y + TABLE_HIGH, 0.0)
		_box(Vector3((dais.xa + dais.xb) * 0.5, _y + TABLE_HIGH * 0.5, 0.0), Vector3(TABLE_LONG, TABLE_HIGH, 2.4), "gold", true)
		parts.append({"kind": "offering", "room": _room, "trigger": table.id, "at": switch_at[table.id]})
		moves.append({"kind": "stop", "is": TABLE_HIGH, "room": _room})
		_span(0.9, _ceil)
	# The loft, if there is one, is over what is left of the room: not over a
	# block on its plate, which he could not then get past.
	if loft:
		# (room to run at its lip)
		_span(1.4, _ceil)
	under = _x
	# A block for the plate in the next room starts beyond anything that would stop it.
	for thing in plan.things:
		if thing.room == room.id and thing.kind == TombPlan.Item.BLOCK:
			var stand := _span(1.4 + BLOCK, _ceil)
			thing_at[thing.id] = Vector3(stand.xb - BLOCK * 0.5, _y + BLOCK * 0.5, 0.0)
			parts.append({"kind": "block", "room": _room, "thing": thing.id, "serves": _plate_after(room), "at": thing_at[thing.id]})
	if loft and _x - under < 4.2:
		_span(4.2 - (_x - under), _ceil)

	# --- The way out
	var out_kind := way_out.pass_kind
	var loft_to := -1.0
	if out_kind == TombPlan.Pass.GAP:
		loft_to = _x
		var approach := _span(2.6, _ceil)
		var gulf := _span(GAP_WIDE, _ceil)
		gulf.floor = _y - PIT_DEEP
		gulf.deadly = true
		parts.append({"kind": "ring", "room": _room, "at": Vector3((gulf.xa + gulf.xb) * 0.5, _y + RING_HIGH, 0.0)})
		moves.append({"kind": "swing", "is": GAP_WIDE, "room": _room, "high": RING_HIGH})
		info["gap"] = [approach.xb, gulf.xb]
	var last := _span(1.6, _ceil)
	info["east"] = Vector3(last.xb - 0.9, _y, 0.0)
	info["x1"] = _x
	parts.append({"kind": "check", "room": _room, "at": info["east"]})
	rooms[room.id] = info

	var next_over := {}
	if loft:
		var top := _y + LOFT_TOP
		if loft_to < 0.0:
			loft_to = _x - 0.2
		rooms[loft.id] = {"x0": under, "x1": loft_to, "floor": top, "edge": under,
				"west": Vector3(under + 1.0, top, 0.0), "east": Vector3(loft_to - 1.0, top, 0.0)}
		moves.append({"kind": "ledge", "is": LOFT_TOP, "room": loft.id})
		moves.append({"kind": "under", "is": LOFT_TOP - LOFT_SLAB, "room": _room})
		parts.append({"kind": "torch", "room": _room, "at": Vector3((under + loft_to) * 0.5, top + 1.5, BACK + 0.05)})
		parts.append({"kind": "cobweb", "room": _room, "at": Vector3(under + 2.0, top + (_ceil - top) * 0.5, 0.0), "size": Vector2(FRONT - BACK, _ceil - top)})
		if loops:
			next_over = {"from": under, "top": top, "room": loft.id}
		else:
			_slab(under, loft_to, top, loft.id)
			for trigger in plan.triggers:
				if trigger.room == loft.id:
					_lever(trigger, loft_to - 1.2, top)

	# --- The wall, and the door in it
	match out_kind:
		TombPlan.Pass.SHAFT:
			# (no wall: the room ends at the head of the ladder)
			pass
		TombPlan.Pass.CRAWL:
			var tunnel := _span(CRAWL_LONG, _y + CRAWL_HIGH)
			tunnel.sky = false
			tunnel.wall = true
			moves.append({"kind": "crawl", "is": CRAWL_HIGH, "room": _room})
			parts.append({"kind": "cobweb", "room": _room, "at": Vector3(tunnel.xa - 0.3, _y + 1.0, 0.0), "size": Vector2(FRONT - BACK, 2.0)})
		_:
			var way := DOORWAY
			if loops:
				way = LOFT_TOP - LOFT_SLAB
			var gate := _span(WALL, _ceil if loops else _y + way)
			gate.wall = not loops
			gate.sky = false
			if loops:
				# (the loft is the lintel; a jamb behind shows where the wall is)
				_box(Vector3((gate.xa + gate.xb) * 0.5, (_y + _ceil) * 0.5, BACK + 0.3), Vector3(WALL, _ceil - _y, 0.6), "wall", false)
				moves.append({"kind": "under", "is": way, "room": _room})
			if not way_out.switches.is_empty():
				door_at[way_out.id] = Vector3((gate.xa + gate.xb) * 0.5, _y + way * 0.5, 0.0)
				parts.append({"kind": "door", "room": _room, "link": way_out.id, "at": door_at[way_out.id],
						"size": Vector3(0.5, way, FRONT - BACK - 0.1), "sinks": loops})
				parts.append({"kind": "inscription", "room": _room, "link": way_out.id, "hint": way_out.hint,
						"at": Vector3(gate.xa - 1.3, _y + 2.0 if loops else _y + way + 0.45, BACK + 0.02)})
	return next_over


# The burial chamber: the sarcophagus, the treasure at the far end, and beyond
# it whatever guards it, which wakes behind him as he takes it.
func _lay_burial(room: TombPlan.Room, info: Dictionary) -> void:
	if room.mummy >= 0:
		_span(1.6, _ceil)
		info["safe"] = _x
		_barrier(room.barrier)
		_span(1.0, _ceil)
	var hall := _span(8.0, _ceil)
	_prop("sarcophagus", Vector3(hall.xa + 2.3, _y, BACK + 1.2), PI * 0.5)
	_prop("statue_anubis", Vector3(hall.xa + 6.1, _y, BACK + 0.9), PI * 0.5)
	_prop("pot_large", Vector3(hall.xa + 0.4, _y, BACK + 0.6), 0.0)
	for k in 2:
		parts.append({"kind": "pillar", "room": _room, "at": Vector3(hall.xa + 0.2 + k * 4.0, _y, BACK + 0.55), "high": _ceil - _y})
	var plinth := _span(2.0, _ceil)
	var goal := plan.goal_trigger()
	switch_at[goal.id] = Vector3((plinth.xa + plinth.xb) * 0.5, _y, 0.0)
	parts.append({"kind": "treasure", "room": _room, "trigger": goal.id, "at": switch_at[goal.id]})
	parts.append({"kind": "inscription", "room": _room, "link": -1, "hint": "treasure", "at": Vector3(plinth.xa, _y + 2.6, BACK + 0.02)})
	info["east"] = Vector3(plinth.xa - 0.8, _y, 0.0)
	if room.mummy >= 0:
		var niche := _span(2.6, _ceil)
		parts.append({"kind": "mummy", "room": _room, "what": room.mummy, "guardian": true,
				"at": Vector3(niche.xb - 0.9, _y, BACK + 1.4), "from": info["west"].x, "to": niche.xb, "east": false, "safe": info["safe"]})
		parts.append({"kind": "jackal", "room": _room, "at": Vector3(niche.xb - 0.9, _y, FRONT - 1.2)})
	info["x1"] = _x
	rooms[room.id] = info
	var end := _span(ROCK, _ceil)
	end.solid = true


# The chamber at the foot of the well: under the floor he came in by.
func _lay_crypt(crypt: TombPlan.Room, shaft: Span) -> void:
	var floor := shaft.floor
	var west := shaft.xa - CRYPT_LONG
	var top := floor + WELL_DEEP - ROCK
	_box(Vector3((west + shaft.xa) * 0.5, floor - ROCK * 0.5, (BACK - 1.0 + FRONT) * 0.5), Vector3(CRYPT_LONG, ROCK, FRONT - BACK + 1.0), "floor", true)
	_box(Vector3((west + shaft.xa) * 0.5 - ROCK * 0.5, floor - ROCK - UNDER * 0.5, (BACK - 1.0 + FRONT) * 0.5), Vector3(CRYPT_LONG + ROCK, UNDER, FRONT - BACK + 1.0), "rock", false)
	# (up into the floor over it, so that there is no seam at the ceiling to catch at)
	_box(Vector3(west - ROCK * 0.5, (floor - ROCK + top + ROCK) * 0.5, (BACK - 1.0 + FRONT) * 0.5), Vector3(ROCK, top - floor + ROCK * 2.0, FRONT - BACK + 1.0), "wall", true)
	_box(Vector3((west + shaft.xa) * 0.5, (floor + top) * 0.5, BACK - 0.5), Vector3(CRYPT_LONG, top - floor, 1.0), "wall", true)
	_box(Vector3((west + shaft.xa) * 0.5, (floor + top) * 0.5, FRONT + 0.25), Vector3(CRYPT_LONG, top - floor, 0.5), "", true)
	rooms[crypt.id] = {"x0": west, "x1": shaft.xb, "floor": floor, "west": Vector3(west + 1.0, floor, 0.0), "east": Vector3(shaft.xa + 0.6, floor, 0.0)}
	parts.append({"kind": "torch", "room": _room, "at": Vector3(west + CRYPT_LONG * 0.5, floor + 1.7, BACK + 0.05)})
	_prop("pot_large", Vector3(west + 0.5, floor, BACK + 0.6), 0.0)
	for trigger in plan.triggers:
		if trigger.room == crypt.id:
			_lever(trigger, west + 1.3, floor)
	moves.append({"kind": "fall", "is": WELL_DEEP, "room": crypt.id})


# --- The pieces

func _span(long: float, ceil: float) -> Span:
	var span := Span.new()
	span.xa = _x
	span.xb = _x + long
	span.floor = _y
	span.ceil = ceil
	span.room = _room
	span.sky = _sky
	spans.append(span)
	_x += long
	return span


func _box(at: Vector3, size: Vector3, made_of: String, solid: bool, room := -1) -> void:
	boxes.append([at, size, made_of, solid, _room if room == -1 else room])


func _prop(scene: String, at: Vector3, yaw: float) -> void:
	parts.append({"kind": "prop", "room": _room, "scene": scene, "at": at, "yaw": yaw})


# The floor of a loft, from `from` to `to`.
func _slab(from: float, to: float, top: float, room: int) -> void:
	_box(Vector3((from + to) * 0.5, top - LOFT_SLAB * 0.5, 0.0), Vector3(to - from, LOFT_SLAB, FRONT - BACK), "loft", true, room)


func _lever(trigger: TombPlan.Trigger, x: float, y: float) -> void:
	switch_at[trigger.id] = Vector3(x, y, 0.0)
	parts.append({"kind": "lever", "room": _room, "trigger": trigger.id, "at": switch_at[trigger.id]})


# A plate for a block that comes from the room before, and what stops the block on it.
func _plate(trigger: TombPlan.Trigger) -> void:
	var slab := _span(1.5, _ceil)
	switch_at[trigger.id] = Vector3((slab.xa + slab.xb) * 0.5, _y, 0.0)
	parts.append({"kind": "plate", "room": _room, "trigger": trigger.id, "at": switch_at[trigger.id]})
	_box(Vector3(_x + STOP_THICK * 0.5, _y + STOP_HIGH * 0.5, 0.0), Vector3(STOP_THICK, STOP_HIGH, FRONT - BACK), "kerb", true)
	moves.append({"kind": "stop", "is": STOP_HIGH, "room": _room})
	_span(0.9, _ceil)


# The plate in the room after `room` that a block from `room` is for.
func _plate_after(room: TombPlan.Room) -> int:
	for trigger in plan.triggers:
		if trigger.kind == TombPlan.Switch.PLATE and plan.rooms[trigger.room].spine == room.spine + 1:
			return trigger.id
	return -1


# What a mummy cannot get past: he can.
func _barrier(kind: TombPlan.Barrier) -> void:
	match kind:
		TombPlan.Barrier.TRENCH:
			var trench := _span(TRENCH_WIDE, _ceil)
			trench.floor = _y - TRENCH_DEEP
			moves.append({"kind": "jump", "is": TRENCH_WIDE, "room": _room})
			moves.append({"kind": "ledge", "is": TRENCH_DEEP, "room": _room})
		TombPlan.Barrier.KERB:
			_span(0.4, _ceil)
			_box(Vector3(_x + KERB_THICK * 0.5, _y + KERB_HIGH * 0.5, 0.0), Vector3(KERB_THICK, KERB_HIGH, FRONT - BACK), "kerb", true)
			moves.append({"kind": "hop", "is": KERB_HIGH, "room": _room})
			_span(0.6, _ceil)
		TombPlan.Barrier.NARROW:
			_span(0.4, _ceil)
			var deep := -SLOT_WIDE * 0.5 - BACK
			_box(Vector3(_x + 0.25, (_y + _ceil) * 0.5, BACK + deep * 0.5), Vector3(0.5, _ceil - _y, deep), "wall", true)
			_box(Vector3(_x + 0.25, _y + 0.5, FRONT - deep * 0.5), Vector3(0.5, 1.0, deep), "wall", true)
			moves.append({"kind": "slot", "is": SLOT_WIDE, "room": _room})
			_span(0.8, _ceil)


# --- The stone round the spans

func _shell() -> void:
	var deep := FRONT - BACK + 1.0
	var mid := (BACK - 1.0 + FRONT) * 0.5
	# Runs of spans that are the same are one piece of stone.
	var runs: Array[Span] = []
	for span in spans:
		var last: Span = runs.back() if not runs.is_empty() else null
		if last and last.room == span.room and is_equal_approx(last.floor, span.floor) and is_equal_approx(last.ceil, span.ceil) \
				and last.deadly == span.deadly and last.wall == span.wall and last.solid == span.solid and last.sky == span.sky \
				and last.open_west == span.open_west and not span.deadly:
			last.xb = span.xb
		else:
			var run := Span.new()
			for key: String in ["xa", "xb", "floor", "ceil", "room", "deadly", "wall", "solid", "sky", "open_west"]:
				run.set(key, span.get(key))
			runs.append(run)
	for k in runs.size():
		var run := runs[k]
		var before: Span = runs[k - 1] if k > 0 else null
		var after: Span = runs[k + 1] if k < runs.size() - 1 else null
		var long := run.xb - run.xa
		var middle := (run.xa + run.xb) * 0.5
		if run.solid:
			_box(Vector3(middle, (run.floor + run.ceil) * 0.5, mid), Vector3(long, run.ceil - run.floor + ROCK * 2.0, deep), "wall", true, run.room)
			continue
		# The floor, or the death at the bottom of a pit. No two pieces of stone
		# meet in a level seam on a face he can jump at: his hands would find
		# the seam and take it for a ledge. So where the floor next to this is
		# much lower, the end of this floor is one piece all the way down to it.
		var from := run.xa
		var to := run.xb
		for side: Array in [[before, 1.0], [after, -1.0]]:
			var other: Span = side[0]
			if run.deadly or other == null or other.solid or run.floor - other.floor <= ROCK + 0.01:
				continue
			# (the chamber at the foot of the well opens under this floor)
			if side[1] < 0.0 and other.open_west:
				continue
			var wide := minf(FILL, to - from)
			var bottom := other.floor - ROCK
			var x := from + wide * 0.5 if side[1] > 0.0 else to - wide * 0.5
			_box(Vector3(x, (run.floor + bottom) * 0.5, mid), Vector3(wide, run.floor - bottom, deep), "floor", true, run.room)
			if side[1] > 0.0:
				from += wide
			else:
				to -= wide
		if run.deadly:
			parts.append({"kind": "death", "room": run.room, "at": Vector3(middle, run.floor + 1.5, 0.0), "size": Vector3(long, 3.0, deep)})
		elif run.sky:
			_box(Vector3(middle - 20.0 if k == 0 else middle, run.floor - ROCK * 0.5, -26.0), Vector3(long + 40.0 if k == 0 else long, ROCK, 80.0), "sand", true, run.room)
		elif to - from > 0.01:
			_box(Vector3((from + to) * 0.5, run.floor - ROCK * 0.5, mid), Vector3(to - from, ROCK, deep), "floor", true, run.room)
			# The rock it is cut in, as far down as is ever seen: only to look at.
			var hollow := false
			for room in plan.rooms:
				if room.role == TombPlan.Role.CRYPT and to > float(rooms[room.id]["x0"]) - ROCK and from < float(rooms[room.id]["x1"]):
					hollow = true
			if not hollow:
				_box(Vector3((from + to) * 0.5, run.floor - ROCK - UNDER * 0.5, mid), Vector3(to - from, UNDER, deep), "rock", false, run.room)
		if run.sky:
			# (out of doors: only something to stop what is thrown)
			_box(Vector3(middle, run.floor + 6.0, FRONT + 0.25), Vector3(long, 12.0, 0.5), "", true, run.room)
			_box(Vector3(middle, run.floor + 6.0, BACK - 0.75), Vector3(long, 12.0, 0.5), "", true, run.room)
			continue
		# The ceiling, and the stone over it where the next ceiling is higher:
		# again one piece from this ceiling up, never one on another.
		var higher := run.ceil
		for other: Span in [before, after]:
			if other == null or other.solid:
				continue
			higher = maxf(higher, other.ceil if not other.sky else run.ceil + 2.6)
		if run.wall:
			_box(Vector3(middle, (run.ceil + higher + ROCK) * 0.5, mid), Vector3(long, higher + ROCK - run.ceil, deep), "wall", true, run.room)
		else:
			from = run.xa
			to = run.xb
			for side: Array in [[before, 1.0], [after, -1.0]]:
				var other: Span = side[0]
				if other == null or other.solid or other.sky or other.ceil <= run.ceil + 0.01:
					continue
				var wide := minf(FILL, to - from)
				var x := from + wide * 0.5 if side[1] > 0.0 else to - wide * 0.5
				_box(Vector3(x, (run.ceil + other.ceil + ROCK) * 0.5, mid), Vector3(wide, other.ceil + ROCK - run.ceil, deep), "rock", true, run.room)
				if side[1] > 0.0:
					from += wide
				else:
					to -= wide
			if to - from > 0.01:
				_box(Vector3((from + to) * 0.5, run.ceil + ROCK * 0.5, mid), Vector3(to - from, ROCK, deep), "rock", true, run.room)
		# The wall behind, and something unseen in front.
		var low := run.floor - ROCK
		var tall := run.ceil + ROCK - low
		_box(Vector3(middle, low + tall * 0.5, BACK - 0.5), Vector3(long, tall, 1.0), "wall", true, run.room)
		_box(Vector3(middle, low + tall * 0.5, FRONT + 0.25), Vector3(long, tall, 0.5), "", true, run.room)
		# Torches along the back wall, and a band of signs over them.
		if run.wall or run.deadly or run.ceil - run.floor < 2.8 or long < 2.0:
			continue
		if plan.rooms[run.room].dark:
			continue
		var count := clampi(int(long / 6.0) + 1, 1, 3)
		for n in count:
			parts.append({"kind": "torch", "room": run.room, "at": Vector3(run.xa + long * (n + 0.5) / count, run.floor + 2.3, BACK + 0.05)})
		if long > 3.0:
			parts.append({"kind": "glyphs", "room": run.room, "at": Vector3(run.xa + 0.5, run.floor + 2.9, BACK + 0.01), "long": long - 1.0})


# --- Telling two apart

## Every number in it as text, to the millimetre: the same for the same tomb.
func describe() -> String:
	var lines: PackedStringArray = []
	lines.append("layout %s long=%s deep=%s" % [plan.fingerprint(), _mm(length), _mm(depth)])
	for box: Array in boxes:
		lines.append("box %s %s %s %s %d" % [_vec(box[0]), _vec(box[1]), box[2], box[3], box[4]])
	for part in parts:
		var keys := part.keys()
		keys.sort()
		var line := "part"
		for key: String in keys:
			var value: Variant = part[key]
			if value is Vector3:
				line += " %s=%s" % [key, _vec(value)]
			elif value is Vector2:
				line += " %s=%s,%s" % [key, _mm(value.x), _mm(value.y)]
			elif value is float:
				line += " %s=%s" % [key, _mm(value)]
			else:
				line += " %s=%s" % [key, str(value)]
		lines.append(line)
	return "\n".join(lines)


func fingerprint() -> String:
	return TombRandom.fingerprint(describe())


static func _mm(value: float) -> String:
	return str(roundi(value * 1000.0))


static func _vec(value: Vector3) -> String:
	return "%s,%s,%s" % [_mm(value.x), _mm(value.y), _mm(value.z)]


## Which room on the axis a place along it is in (the room's id), or -1.
func room_at(x: float) -> int:
	var found := -1
	for room in plan.spine():
		if x >= float(rooms[room.id]["x0"]):
			found = room.id
	return found
