class_name TombFloorSpec
extends RefCounted
## A tomb made by hand that branches: the part of `TombSpec` that is about a
## floor plan. Such a spec says `"shape": "branching"`, and of each room, as
## well as what any room says, where it stands and what it is entered from:
##
##     {"version": 1, "name": "My tomb", "shape": "branching", "seed": 1, "difficulty": 0, "sub": 0,
##      "rooms": [
##         {"role": "entrance", "cell": [0, 0], "from": -1},
##         {"role": "corridor", "cell": [1, 0], "from": 0, "way": "stairs"},
##         {"role": "antechamber", "cell": [2, 0], "from": 1},
##         {"role": "burial", "cell": [3, 0], "from": 2, "lock": "seal", "stone_in": 4},
##         {"role": "corridor", "cell": [1, 1], "from": 1, "way": "crawl"}],
##      "joins": [{"a": 2, "b": 4, "way": "open", "lock": "none", "seal": 4}]}
##
## `cell` is the square of the floor plan it stands on (x, then z: east and
## south), and `from` the room it is entered from, which stands on a square
## next to it (rooms are counted from 0, the entrance). A room has one way in
## and up to three ways on, so here `way` and `lock` are of the way INTO the
## room, not of the way on from it as they are in a tomb down one axis: `way`
## is how it is got into from `from`, and `lock` what opens the door there
## (which stands in the wall of `from`). `lock_in` is the room the lock's
## block and plate, brazier or table stand in (-1: the room the door is in),
## so that a door can be opened from down another way; `stone_in` the room a
## seal stone's loft is over, or its well is, or (for the lock `seal`) the
## room it lies just inside.
##
## `joins` are second ways between two rooms on squares side by side: what
## makes a loop. `way` is a doorway, a crawl or water where the two are on a
## level, and stairs where one is one to three levels below the other; with
## the lock `within`, its door opens only from the room `seal`, by a seal stone
## just inside that room.
##
## The level of each room is not said: it follows from the ways down to it
## (`levels`). `problems` says in plain words whatever of this cannot be built,
## and then asks `TombLayout3D.cells_wrong` of the plan as well; `compile`
## makes the plan, its rooms with their cells. `add_room`, `move_room`,
## `remove_room`, `join` and `unjoin` are what the tomb editor's floor plan
## does to a spec (and say whether they could).

## The most rooms that stand on squares.
const MOST := 14
## What opens the door into a room (`seal`: a seal stone just inside another room).
const LOCKS := ["none", "work", "cross", "pair", "brazier", "offering", "lever_above", "lever_below", "seal", "bypass", "name", "name_above", "name_below"]
const LOCK_TITLES := {"none": "No door", "work": "A block and its plate", "cross": "A plate, its block from the room before",
	"pair": "Two plates: its own block, and one from the room before",
	"brazier": "A brazier to light", "offering": "A block, and a jar on the table", "lever_above": "A seal stone up in a loft",
	"lever_below": "A seal stone under a well", "seal": "A seal stone in another room", "bypass": "Opened from behind, over the wall",
	"name": "A gate guardian, his leaf in a room you choose", "name_above": "A gate guardian, his leaf up in a loft", "name_below": "A gate guardian, his leaf under a well"}
const LOCK_NOTES := {
	"none": "",
	"work": "A block is pushed onto a plate: in the room the door is in, or in any other you choose below.",
	"cross": "The plate is in the room the door is in, and its block starts in the room before that one, which has to be joined to it by a level doorway.",
	"pair": "Two plates in the room the door is in, and both must be down: that room's own block on one, and on the other a block pushed in from the room before it, through a level doorway.",
	"brazier": "Wants a torch brought to the brazier: leave one somewhere he can carry it from. The room the brazier is in is usually dark.",
	"offering": "A block to push, and a jar to set on the table: leave a jar somewhere he can carry it from.",
	"lever_above": "A slab over a room, caught by its edge. The stone on it opens this door.",
	"lever_below": "The chamber at the foot of a well. The stone in it opens this door.",
	"seal": "A seal stone just inside the room you choose below: down another way, if you like.",
	"bypass": "A cutting goes over the wall and drops beyond it; the stone that opens the door is there. The way becomes stairs, two flights down.",
	"name": "A keeper sits by the way with his knives across it until he is told his name. The leaf that says it lies in the room you choose below: down another way, if you like. Without it he can guess: one chance in three, and a wrong name is his death.",
	"name_above": "A keeper bars the way until he is told his name. The leaf that says it is on a slab over a room, caught by its edge.",
	"name_below": "A keeper bars the way until he is told his name. The leaf that says it is in the chamber at the foot of a well.",
}
## How a second way between two rooms can be got along.
const JOIN_WAYS := ["open", "crawl", "flood", "stairs"]
## The four sides of a square: east, south, west, north (as `TombLayout3D.TURNS`).
const SIDES: Array[Vector2i] = [Vector2i(1, 0), Vector2i(0, 1), Vector2i(-1, 0), Vector2i(0, -1)]
const SIDE_NAMES := ["east", "south", "west", "north"]


# --- Making one

## A room as it starts, on the square `cell`, entered from the room `from`.
static func room(role: String, cell: Vector2i, from: int) -> Dictionary:
	var made := TombSpec.room(role)
	made["way"] = "stairs" if from == 0 else "open"
	made["cell"] = [cell.x, cell.y]
	made["from"] = from
	made["lock_in"] = -1
	return made


## A small tomb that branches, to begin from: the door of the burial chamber
## is opened by a seal stone in a side chamber off the first corridor.
static func fresh(name := "My tomb") -> Dictionary:
	var rooms: Array = [room("entrance", Vector2i(0, 0), -1), room("corridor", Vector2i(1, 0), 0), room("antechamber", Vector2i(2, 0), 1),
			room("burial", Vector2i(3, 0), 2), room("corridor", Vector2i(1, 1), 1)]
	rooms[3]["lock"] = "seal"
	rooms[3]["stone_in"] = 4
	rooms[4]["way"] = "crawl"
	return {"version": TombSpec.VERSION, "name": name, "shape": "branching", "seed": 1, "difficulty": 0, "sub": 0, "rooms": rooms, "joins": []}


## The tomb that branches which the generator makes from a number, as one to change by hand.
static func from_seed(seed_value: int, difficulty: int) -> Dictionary:
	var spec := from_plan(TombBranching.generate(seed_value, difficulty))
	spec["name"] = "Branching tomb %d" % seed_value
	return spec


## A plan with cells (one of `TombBranching`'s) as a tomb to change by hand.
static func from_plan(plan: TombPlan) -> Dictionary:
	var spec := {"version": TombSpec.VERSION, "name": "Tomb", "shape": "branching", "seed": plan.seed_value, "difficulty": plan.difficulty, "sub": plan.sub_seed, "rooms": [], "joins": []}
	# (a loft or a crypt is not a room here: it comes of a lock)
	var index := {}
	for made in plan.rooms:
		if not TombLayout3D.is_side(made):
			index[made.id] = index.size()
	var way_in := {}
	for link in plan.links:
		if index.has(link.a) and index.has(link.b) and not way_in.has(link.b) and link.b != plan.entrance():
			way_in[link.b] = link
	for made in plan.rooms:
		if not index.has(made.id):
			continue
		var came: TombPlan.Link = way_in.get(made.id, null)
		var told := room(TombPlan.ROLE_NAMES[made.role], Vector2i(made.cell.x, made.cell.z), int(index[came.a]) if came else -1)
		told["dark"] = made.dark
		told["pit"] = made.pit
		told["mummy"] = made.mummy
		if made.mummy >= 0 and made.barrier != TombGenerator.BARRIER_FOR.get(made.mummy, TombPlan.Barrier.NONE):
			told["barrier"] = TombPlan.BARRIER_NAMES[made.barrier]
		for thing in plan.things:
			if thing.room == made.id and thing.kind != TombPlan.Item.BLOCK:
				var what: String = TombPlan.ITEM_NAMES[thing.kind]
				told[what] = int(told[what]) + 1
		if came:
			told["way"] = TombPlan.PASS_NAMES[came.pass_kind]
			var first: TombPlan.Trigger = plan.triggers[came.switches[0]] if not came.switches.is_empty() else null
			var held := plan.rooms[first.room] if first else null
			match came.hint:
				"weight", "weight_afar":
					told["lock"] = "work"
					told["lock_in"] = index[first.room]
				"weight_from_afar":
					told["lock"] = "cross"
				"two_stones":
					told["lock"] = "pair"
				"fire", "fire_afar":
					told["lock"] = "brazier"
					told["lock_in"] = index[first.room]
				"two_weights":
					told["lock"] = "offering"
				"over_the_wall":
					told["lock"] = "bypass"
				"lever_above", "lever_below", "sand_above", "sand_below":
					told["lock"] = "lever_above" if came.hint.ends_with("above") else "lever_below"
					told["stone_in"] = index[held.parent]
				"name", "name_afar":
					told["lock"] = "name"
					told["stone_in"] = index[plan.triggers[first.needs].room]
				"name_above", "name_below":
					told["lock"] = came.hint
					told["stone_in"] = index[plan.rooms[plan.triggers[first.needs].room].parent]
				"seal_afar", "sand_afar":
					told["lock"] = "seal"
					told["stone_in"] = index[first.room]
		(spec["rooms"] as Array).append(told)
	for link in plan.links:
		if not index.has(link.a) or not index.has(link.b) or way_in.get(link.b, null) == link:
			continue
		var join := {"a": index[link.a], "b": index[link.b], "way": TombPlan.PASS_NAMES[link.pass_kind], "lock": "none", "seal": index[link.b]}
		if not link.switches.is_empty():
			join["lock"] = "within"
			join["seal"] = index[plan.triggers[link.switches[0]].room]
		(spec["joins"] as Array).append(join)
	return spec


# --- Reading one

static func cell_of(told: Dictionary) -> Vector2i:
	var cell: Variant = told.get("cell", null)
	if cell is Array and (cell as Array).size() >= 2:
		return Vector2i(int(cell[0]), int(cell[1]))
	return Vector2i(-9999, -9999)


## Which room stands on each square (the first, where two do).
static func squares(spec: Dictionary) -> Dictionary:
	var taken := {}
	var rooms: Array = spec.get("rooms", [])
	for i in rooms.size():
		if not taken.has(cell_of(rooms[i])):
			taken[cell_of(rooms[i])] = i
	return taken


## The rooms that are entered from `index`.
static func ways_on(spec: Dictionary, index: int) -> Array:
	var found: Array = []
	var rooms: Array = spec.get("rooms", [])
	for i in range(1, rooms.size()):
		if int(rooms[i].get("from", -1)) == index:
			found.append(i)
	return found


## How many levels the way into a room goes down (up, for the sand).
static func down_into(told: Dictionary) -> int:
	if told.get("lock", "none") == "bypass":
		return TombLayout3D.DROP_LEVELS
	return TombLayout3D.levels_down(maxi(TombPlan.PASS_NAMES.find(told.get("way", "open")), 0) as TombPlan.Pass)


## The level of each room, counted downwards from the entrance at 0; 9999 for
## a room that is not come to from the entrance.
static func levels(spec: Dictionary) -> Array[int]:
	var rooms: Array = spec.get("rooms", [])
	var found: Array[int] = []
	found.resize(rooms.size())
	found.fill(9999)
	if rooms.is_empty():
		return found
	found[0] = 0
	var changed := true
	while changed:
		changed = false
		for i in range(1, rooms.size()):
			var from := int(rooms[i].get("from", -1))
			if found[i] == 9999 and from >= 0 and from < rooms.size() and from != i and found[from] != 9999:
				found[i] = found[from] + down_into(rooms[i])
				changed = true
	return found


## The sides of a room that a new room could be made off (indices into SIDES):
## not the side its way in is on, and not onto a square that is taken. None for
## the burial chamber, and for the entrance once it has its one way on.
static func free_sides(spec: Dictionary, index: int) -> Array:
	var found: Array = []
	var rooms: Array = spec.get("rooms", [])
	if index < 0 or index >= rooms.size() or rooms[index].get("role", "") == "burial":
		return found
	if index == 0 and not ways_on(spec, 0).is_empty():
		return found
	var taken := squares(spec)
	for side in SIDES.size():
		if not taken.has(cell_of(rooms[index]) + SIDES[side]):
			found.append(side)
	return found


## The second ways a room has: each an entry of `joins`.
static func joins_of(spec: Dictionary, index: int) -> Array:
	var found: Array = []
	for join: Dictionary in spec.get("joins", []):
		if int(join.get("a", -1)) == index or int(join.get("b", -1)) == index:
			found.append(join)
	return found


# --- Changing one (what the editor's floor plan does)

## A new corridor off the room `off`, on its side `side`. Returns its number, or -1 if it cannot stand there.
static func add_room(spec: Dictionary, off: int, side: int) -> int:
	var rooms: Array = spec["rooms"]
	if rooms.size() >= MOST or not side in free_sides(spec, off):
		return -1
	rooms.append(room("corridor", cell_of(rooms[off]) + SIDES[side], off))
	return rooms.size() - 1


## Why a room cannot be taken away or moved, or "" if it can: only a room with nothing beyond it.
static func fixed_because(spec: Dictionary, index: int) -> String:
	var rooms: Array = spec["rooms"]
	if index <= 0 or index >= rooms.size():
		return "The entrance stays where it is."
	if not ways_on(spec, index).is_empty():
		return "Other rooms are entered from this one: move or remove those first."
	return ""


## Takes a room away, and every second way it had. Says whether it could.
static func remove_room(spec: Dictionary, index: int) -> bool:
	var rooms: Array = spec["rooms"]
	if fixed_because(spec, index) != "" or rooms[index].get("role", "") == "burial" or rooms.size() <= TombSpec.FEWEST:
		return false
	var parent := int(rooms[index]["from"])
	rooms.remove_at(index)
	var kept: Array = []
	for join: Dictionary in spec.get("joins", []):
		if int(join["a"]) == index or int(join["b"]) == index:
			continue
		for key: String in ["a", "b", "seal"]:
			if int(join[key]) > index:
				join[key] = int(join[key]) - 1
		kept.append(join)
	spec["joins"] = kept
	# (whatever said this room by its number now says the room it was off, or the one that has its number)
	for told: Dictionary in rooms:
		for key: String in ["from", "stone_in", "lock_in"]:
			var said := int(told.get(key, -1))
			if said == index:
				told[key] = -1 if key == "lock_in" else parent
			elif said > index:
				told[key] = said - 1
	return true


## Moves a room to the side `side` of the room `off`, which it is then entered
## from. Its second ways do not go with it. Says whether it could.
static func move_room(spec: Dictionary, index: int, off: int, side: int) -> bool:
	var rooms: Array = spec["rooms"]
	if fixed_because(spec, index) != "" or off == index or off < 0 or off >= rooms.size():
		return false
	# (its own square is free to it: asked with it lifted off the plan)
	var was: Variant = rooms[index]["cell"]
	rooms[index]["cell"] = [-9999, -9999]
	var free := side in free_sides(spec, off)
	if not free:
		rooms[index]["cell"] = was
		return false
	var to := cell_of(rooms[off]) + SIDES[side]
	rooms[index]["cell"] = [to.x, to.y]
	rooms[index]["from"] = off
	if off == 0:
		rooms[index]["way"] = "stairs"
		rooms[index]["lock"] = "none"
	spec["joins"] = (spec.get("joins", []) as Array).filter(func(join: Dictionary) -> bool: return int(join["a"]) != index and int(join["b"]) != index)
	return true


## Why two rooms cannot be given a second way between them, or "" if they can.
static func join_wrong(spec: Dictionary, one: int, other: int) -> String:
	var rooms: Array = spec["rooms"]
	if one == other or mini(one, other) < 0 or maxi(one, other) >= rooms.size():
		return "There are no such two rooms."
	for index: int in [one, other]:
		if index == 0 or rooms[index].get("role", "") == "burial":
			return "The entrance has one way, and the burial chamber one: no second way comes to either."
	var step := cell_of(rooms[one]) - cell_of(rooms[other])
	if absi(step.x) + absi(step.y) != 1:
		return "%s and %s are not on squares side by side." % [TombSpec.room_title(spec, one), TombSpec.room_title(spec, other)]
	if int(rooms[one].get("from", -1)) == other or int(rooms[other].get("from", -1)) == one:
		return "%s and %s are joined already: the one is entered from the other." % [TombSpec.room_title(spec, one), TombSpec.room_title(spec, other)]
	for join: Dictionary in joins_of(spec, one):
		if int(join["a"]) == other or int(join["b"]) == other:
			return "%s and %s have a second way between them already." % [TombSpec.room_title(spec, one), TombSpec.room_title(spec, other)]
	var apart := absi(levels(spec)[one] - levels(spec)[other])
	if apart > 3:
		return "%s and %s are %d levels apart: too far for stairs." % [TombSpec.room_title(spec, one), TombSpec.room_title(spec, other), apart]
	return ""


## A second way between two rooms: a doorway if they are on a level, stairs if not. Says whether it could.
static func join(spec: Dictionary, one: int, other: int) -> bool:
	if join_wrong(spec, one, other) != "":
		return false
	var level := levels(spec)
	if not spec.has("joins"):
		spec["joins"] = []
	(spec["joins"] as Array).append({"a": mini(one, other), "b": maxi(one, other), "way": "open" if level[one] == level[other] else "stairs", "lock": "none", "seal": maxi(one, other)})
	return true


## Takes away the second way between two rooms. Says whether there was one.
static func unjoin(spec: Dictionary, one: int, other: int) -> bool:
	var before := (spec.get("joins", []) as Array).size()
	spec["joins"] = (spec.get("joins", []) as Array).filter(func(join: Dictionary) -> bool:
		return not ((int(join["a"]) == one and int(join["b"]) == other) or (int(join["a"]) == other and int(join["b"]) == one)))
	return (spec["joins"] as Array).size() < before


# --- What is wrong with one

# Notes that a room is to hold one more of something a room holds one of; says what is wrong if it has one already.
static func _claim(held: Dictionary, spec: Dictionary, where: int, door: int, what: String, wrong: PackedStringArray) -> void:
	if held.has(where):
		wrong.append("%s would have two %s (for the ways into %s and %s): a room has one." % [TombSpec.room_title(spec, where), what, TombSpec.room_title(spec, held[where]), TombSpec.room_title(spec, door)])
	else:
		held[where] = door


## Everything in it that could not be built; empty if it can be.
static func problems(spec: Dictionary) -> PackedStringArray:
	var wrong: PackedStringArray = []
	var rooms: Array = spec.get("rooms", [])
	var count := rooms.size()
	if count < TombSpec.FEWEST:
		wrong.append("A tomb wants at least %d rooms." % TombSpec.FEWEST)
		return wrong
	if count > MOST:
		wrong.append("A tomb that branches has at most %d rooms on its floor plan." % MOST)
	if rooms[0].get("role", "") != "entrance":
		wrong.append("The first room has to be the entrance.")
	var burial := -1
	var burials := 0
	var taken := {}
	for i in count:
		var told: Dictionary = rooms[i]
		var title := TombSpec.room_title(spec, i)
		var role: String = told.get("role", "")
		if role == "burial":
			burial = i
			burials += 1
		elif i > 0 and not role in TombSpec.MIDDLE_ROLES:
			wrong.append("%s: only the first room is an entrance." % title)
		var cell := cell_of(told)
		if cell.x == -9999:
			wrong.append("%s has no square of the floor plan to stand on." % title)
		elif taken.has(cell):
			wrong.append("%s and %s stand on the same square." % [TombSpec.room_title(spec, taken[cell]), title])
		else:
			taken[cell] = i
		if i == 0:
			continue
		var from := int(told.get("from", -1))
		if from < 0 or from >= count or from == i:
			wrong.append("%s is entered from nowhere: say which room it is off." % title)
		elif absi((cell - cell_of(rooms[from])).x) + absi((cell - cell_of(rooms[from])).y) != 1:
			wrong.append("%s is entered from %s, which is not on a square next to it." % [title, TombSpec.room_title(spec, from)])
		elif rooms[from].get("role", "") == "burial":
			wrong.append("%s: nothing is beyond the burial chamber." % title)
	if burials != 1:
		wrong.append("A tomb has one burial chamber: this has %d." % burials)
	if not wrong.is_empty():
		return wrong
	var level := levels(spec)
	for i in count:
		if level[i] == 9999:
			wrong.append("%s cannot be got to from the entrance: the rooms it is entered through go round in a ring." % TombSpec.room_title(spec, i))
	if ways_on(spec, 0).size() != 1:
		wrong.append("The entrance has one way on: this has %d." % ways_on(spec, 0).size())
	if not wrong.is_empty():
		return wrong

	# What each room holds one of, by room: the way whose lock put it there.
	var lofts := {}
	var crypts := {}
	var works := {}
	var plates := {}
	var fires := {}
	var tables := {}
	var seals := {}
	var blocks := {}
	var sand_from := {}
	if rooms[0].get("pit", false) or int(rooms[0].get("mummy", -1)) >= 0:
		wrong.append("%s: nothing waits out of doors, and there is no pit there." % TombSpec.room_title(spec, 0))
	for i in range(1, count):
		var told: Dictionary = rooms[i]
		var title := TombSpec.room_title(spec, i)
		var into := "The way into %s" % title
		var from := int(told["from"])
		var way: String = told.get("way", "open")
		var lock: String = told.get("lock", "none")
		if int(told.get("mummy", -1)) >= TombSpec.MUMMY_TITLES.size():
			wrong.append("%s: there is no such mummy." % title)
		if i == burial and told.get("pit", false):
			wrong.append("%s: there is no pit in the burial chamber." % title)
		if not way in TombSpec.WAYS:
			wrong.append("%s: there is no such way." % into)
			continue
		if not lock in LOCKS:
			wrong.append("%s: there is no such lock." % into)
			continue
		if from == 0:
			if not way in ["open", "stairs"]:
				wrong.append("%s: the way in from outside is a doorway or stairs." % into)
			if lock != "none":
				wrong.append("%s: the way in from outside has no door." % into)
			continue
		if lock != "none" and lock != "bypass" and way in ["crawl", "shaft", "rope", "gap"]:
			wrong.append("%s: %s has no door to lock. Make it a doorway, stairs or water." % [into, String(TombSpec.WAY_TITLES[way]).to_lower()])
		if way == "sand":
			sand_from[from] = i
			if lock == "bypass":
				wrong.append("%s: the way over the wall comes down stairs: it cannot also go up the sand." % into)
			if i != burial and int(told.get("mummy", -1)) >= 0:
				wrong.append("%s: nothing can wait at the top of the sand: it would come down it after him." % title)
		var held := int(told.get("lock_in", -1))
		if held < 0 or held >= count:
			held = from
		if held == 0 and lock in ["work", "brazier", "offering"]:
			wrong.append("%s: nothing that opens a door stands out of doors." % into)
			continue
		match lock:
			"work":
				_claim(works, spec, held, i, "blocks and plates of their own", wrong)
			"brazier":
				_claim(fires, spec, held, i, "braziers", wrong)
			"offering":
				_claim(works, spec, held, i, "blocks and plates of their own", wrong)
				_claim(tables, spec, held, i, "offering tables", wrong)
			"cross", "pair":
				var before := int(rooms[from].get("from", -1))
				if before <= 0:
					wrong.append("%s: there is no room before %s to bring a block from." % [into, TombSpec.room_title(spec, from)])
				elif rooms[from].get("way", "open") != "open" or rooms[from].get("lock", "none") == "bypass":
					wrong.append("%s: its block is pushed into %s from %s, so the way between those two has to be a level doorway." % [into, TombSpec.room_title(spec, from), TombSpec.room_title(spec, before)])
				elif TombSpec.keeps_way(rooms[from].get("lock", "none")):
					wrong.append("%s: its block is pushed into %s from %s, by a way a guardian, a sphinx or Medjed keeps: no block goes that way." % [into, TombSpec.room_title(spec, from), TombSpec.room_title(spec, before)])
				elif cell_of(rooms[from]) - cell_of(rooms[before]) == cell_of(rooms[before]) - cell_of(rooms[int(rooms[before]["from"])]) \
						and (ways_on(spec, before).size() > 1 or not joins_of(spec, before).is_empty()):
					# (see `TombBranching`: the strip of floor a side way leaves at the end of the bay catches a block pushed straight on)
					wrong.append("%s: its block is pushed straight on out of the far end of %s, and would catch where another way leaves that room. Give %s no other way on, or have the way to %s turn a corner out of it." % [
							into, TombSpec.room_title(spec, before), TombSpec.room_title(spec, before), TombSpec.room_title(spec, from)])
				else:
					_claim(plates, spec, from, i, "plates for a block from the room before", wrong)
					_claim(blocks, spec, before, i, "blocks for other rooms", wrong)
					if lock == "pair":
						_claim(works, spec, from, i, "blocks and plates of their own", wrong)
			"name":
				var host := int(told.get("stone_in", from))
				if host < 1 or host >= count:
					wrong.append("%s: say which room the leaf with its keeper's name lies in (not the entrance)." % into)
			"lever_above", "name_above":
				var host := int(told.get("stone_in", from))
				if host < 1 or host >= count or host == burial:
					wrong.append("%s: say which room the loft with its seal stone is over (not the entrance, nor the burial chamber)." % into)
				elif rooms[host].get("role", "") == "well":
					wrong.append("%s: there is no loft over a well. Put its seal stone under the well instead." % into)
				else:
					_claim(lofts, spec, host, i, "lofts", wrong)
			"lever_below", "name_below":
				var host := int(told.get("stone_in", from))
				if host < 1 or host >= count or rooms[host].get("role", "") != "well":
					wrong.append("%s: its seal stone has to be under a room that is a well." % into)
				else:
					_claim(crypts, spec, host, i, "chambers under it", wrong)
			"seal":
				var host := int(told.get("stone_in", from))
				if host < 1 or host >= count:
					wrong.append("%s: say which room its seal stone lies just inside (not the entrance)." % into)
				else:
					_claim(seals, spec, host, i, "seal stones just inside it", wrong)
			"bypass":
				_claim(lofts, spec, from, i, "lofts", wrong)
				_claim(seals, spec, i, i, "seal stones just inside it", wrong)
	for host: int in lofts:
		if sand_from.has(host):
			wrong.append("There is no loft over %s, from which a way goes up the sand: he would get up the face from it." % TombSpec.room_title(spec, host))
	# (a gate guardian sits by his door, under where the floor of a loft would be)
	for i in range(1, count):
		if not TombSpec.is_keeper(rooms[i].get("lock", "none")):
			continue
		var door_in := int(rooms[i].get("from", 0))
		if rooms[i].get("way", "open") == "sand":
			wrong.append("The way into %s: a gate guardian keeps a doorway, stairs or water, not the way up the sand." % TombSpec.room_title(spec, i))
		if lofts.has(door_in):
			wrong.append("The way into %s has a gate guardian, who sits in %s where a loft over it would be: put the loft over another room." % [TombSpec.room_title(spec, i), TombSpec.room_title(spec, door_in)])

	# The second ways.
	var joined := {}
	for join: Dictionary in spec.get("joins", []):
		var a := int(join.get("a", -1))
		var b := int(join.get("b", -1))
		if a == b or mini(a, b) < 0 or maxi(a, b) >= count:
			wrong.append("A second way joins two rooms: one of these is not there.")
			continue
		var both := "The second way between %s and %s" % [TombSpec.room_title(spec, a), TombSpec.room_title(spec, b)]
		var step := cell_of(rooms[a]) - cell_of(rooms[b])
		if mini(a, b) == 0 or a == burial or b == burial:
			wrong.append("%s: no second way comes to the entrance or to the burial chamber." % both)
		elif absi(step.x) + absi(step.y) != 1:
			wrong.append("%s: they are not on squares side by side." % both)
		elif int(rooms[a]["from"]) == b or int(rooms[b]["from"]) == a or joined.has(Vector2i(mini(a, b), maxi(a, b))):
			wrong.append("%s: they are joined already." % both)
		else:
			joined[Vector2i(mini(a, b), maxi(a, b))] = true
			var way: String = join.get("way", "open")
			var apart := absi(level[a] - level[b])
			if not way in JOIN_WAYS:
				wrong.append("%s: it can be a doorway, a crawl, water or stairs." % both)
			elif way == "stairs" and (apart < 1 or apart > 3):
				wrong.append("%s is stairs, and they are %s: stairs go down one to three levels. %s" % [both, "on a level" if apart == 0 else "%d levels apart" % apart, "Make it a doorway, a crawl or water." if apart == 0 else ""])
			elif way != "stairs" and apart != 0:
				wrong.append("%s is %s, and %s is %d %s lower: make it stairs." % [both, String(TombSpec.WAY_TITLES[way]).to_lower(), TombSpec.room_title(spec, a if level[a] > level[b] else b), apart, "level" if apart == 1 else "levels"])
			for end: int in [a, b]:
				if lofts.has(end):
					wrong.append("%s: a second way comes into the far end of a room, and %s has a loft over its far end." % [both, TombSpec.room_title(spec, end)])
			if join.get("lock", "none") == "within":
				var seal := int(join.get("seal", b))
				if seal != a and seal != b:
					wrong.append("%s: its door opens from one of those two rooms." % both)
				elif way == "crawl":
					wrong.append("%s: a crawl has no door to lock." % both)
				else:
					_claim(seals, spec, seal, seal, "seal stones just inside it", wrong)
	if not wrong.is_empty():
		return wrong
	var plan := compile(spec)
	for said in TombLayout3D.cells_wrong(plan):
		wrong.append("The floor plan cannot be set out: %s." % said)
	if plan.rooms.size() > (1 << TombSolver.POS_BITS):
		wrong.append("Too many rooms, with the lofts and chambers: %d, and %d is the most." % [plan.rooms.size(), 1 << TombSolver.POS_BITS])
	if plan.things.size() > (1 << TombSolver.HAND_BITS) - 1:
		wrong.append("Too many things to carry and push: %d, and %d is the most." % [plan.things.size(), (1 << TombSolver.HAND_BITS) - 1])
	if plan.triggers.size() > TombSolver.DONE_BITS:
		wrong.append("Too many plates, stones and braziers: %d, and %d is the most." % [plan.triggers.size() - 1, TombSolver.DONE_BITS - 1])
	return wrong


# --- The plan of one

## The plan it describes, its rooms with their cells. (Ask `problems` first: this takes it as it is.)
static func compile(spec: Dictionary) -> TombPlan:
	var plan := TombPlan.new()
	plan.seed_value = int(spec.get("seed", 1))
	plan.difficulty = clampi(int(spec.get("difficulty", 0)), 0, 2)
	plan.sub_seed = int(spec.get("sub", 0))
	var rooms: Array = spec.get("rooms", [])
	var count := rooms.size()
	var level := levels(spec)
	var burial := count - 1
	for i in count:
		var told: Dictionary = rooms[i]
		var made := plan.add_room(maxi(TombPlan.ROLE_NAMES.find(told.get("role", "corridor")), 0) as TombPlan.Role)
		made.spine = i
		made.dark = told.get("dark", false)
		made.pit = told.get("pit", false)
		made.mummy = int(told.get("mummy", -1))
		var cell := cell_of(told)
		made.cell = Vector3i(cell.x, level[i] if level[i] != 9999 else 0, cell.y)
		if made.role == TombPlan.Role.BURIAL:
			burial = i
		if made.mummy >= 0:
			var barrier: String = told.get("barrier", "auto")
			if barrier == "auto":
				made.barrier = TombGenerator.BARRIER_FOR.get(made.mummy, TombPlan.Barrier.TRENCH)
			else:
				made.barrier = maxi(TombPlan.BARRIER_NAMES.find(barrier), 0) as TombPlan.Barrier
			made.guardian = made.role == TombPlan.Role.BURIAL
	# The way into each room, which is the first that ends at it.
	var into := {}
	for i in range(1, count):
		var told: Dictionary = rooms[i]
		var way := maxi(TombPlan.PASS_NAMES.find(told.get("way", "open")), 0) as TombPlan.Pass
		if told.get("lock", "none") == "bypass":
			way = TombPlan.Pass.STAIRS
		into[i] = plan.add_link(clampi(int(told.get("from", 0)), 0, count - 1), i, way)
	plan.add_trigger(TombPlan.Switch.TREASURE, burial)
	for i in count:
		for what: String in TombSpec.THINGS:
			for n in int(rooms[i].get(what, 0)):
				plan.add_thing(TombPlan.ITEM_NAMES.find(what) as TombPlan.Item, i)
	# The locks, each as the generators' rule of the same name puts it in.
	for i in range(1, count):
		var told: Dictionary = rooms[i]
		var link: TombPlan.Link = into[i]
		var from := link.a
		var held := int(told.get("lock_in", -1))
		if held < 0 or held >= count:
			held = from
		if link.pass_kind == TombPlan.Pass.GAP:
			link.hint = "hook"
		elif link.pass_kind == TombPlan.Pass.ROPE:
			link.hint = "rope"
		match told.get("lock", "none"):
			"work":
				link.switches = [plan.add_trigger(TombPlan.Switch.WORK_PLATE, held).id]
				link.hint = "weight" if held == from else "weight_afar"
			"cross", "pair":
				plan.add_thing(TombPlan.Item.BLOCK, clampi(int(rooms[from].get("from", 0)), 0, count - 1)).dest = from
				link.switches = [plan.add_trigger(TombPlan.Switch.PLATE, from).id]
				link.hint = "weight_from_afar"
				if told["lock"] == "pair":
					link.switches.append(plan.add_trigger(TombPlan.Switch.WORK_PLATE, from).id)
					link.hint = "two_stones"
			"brazier":
				link.switches = [plan.add_trigger(TombPlan.Switch.BRAZIER, held).id]
				link.hint = "fire" if held == from else "fire_afar"
			"offering":
				link.switches = [plan.add_trigger(TombPlan.Switch.WORK_PLATE, held).id, plan.add_trigger(TombPlan.Switch.OFFERING, held).id]
				link.hint = "two_weights"
			"name":
				var host := clampi(int(told.get("stone_in", from)), 0, count - 1)
				# (back the way he came, or down another way)
				var back := from
				for n in count:
					if back == host or back <= 0:
						break
					back = clampi(int(rooms[back].get("from", 0)), 0, count - 1)
				TombSpec._keeper(plan, link, from, host, "name" if back == host else "name_afar")
			"lever_above", "name_above":
				var host := clampi(int(told.get("stone_in", from)), 0, count - 1)
				var loft := plan.add_room(TombPlan.Role.LOFT, host)
				plan.add_link(host, loft.id, TombPlan.Pass.CLIMB)
				if told["lock"] == "name_above":
					TombSpec._keeper(plan, link, from, loft.id, "name_above")
				else:
					link.switches = [plan.add_trigger(TombPlan.Switch.LEVER, loft.id).id]
					link.hint = "lever_above"
			"lever_below", "name_below":
				var host := clampi(int(told.get("stone_in", from)), 0, count - 1)
				var crypt := plan.add_room(TombPlan.Role.CRYPT, host)
				plan.add_link(host, crypt.id, TombPlan.Pass.SHAFT)
				if told["lock"] == "name_below":
					TombSpec._keeper(plan, link, from, crypt.id, "name_below")
				else:
					link.switches = [plan.add_trigger(TombPlan.Switch.LEVER, crypt.id).id]
					link.hint = "lever_below"
			"seal":
				link.switches = [plan.add_trigger(TombPlan.Switch.LEVER, clampi(int(told.get("stone_in", from)), 0, count - 1)).id]
				link.hint = "seal_afar"
			"bypass":
				var loft := plan.add_room(TombPlan.Role.LOFT, from)
				plan.add_link(from, loft.id, TombPlan.Pass.CLIMB)
				plan.add_link(loft.id, i, TombPlan.Pass.DROP)
				link.switches = [plan.add_trigger(TombPlan.Switch.LEVER, i).id]
				link.hint = "over_the_wall"
		# Up the sand: with no lock of its own, a seal stone at the foot of the face lets it in.
		if link.pass_kind == TombPlan.Pass.SAND:
			match link.hint:
				"":
					link.switches = [plan.add_trigger(TombPlan.Switch.LEVER, from).id]
					link.hint = "sand"
				"lever_above":
					link.hint = "sand_above"
				"lever_below":
					link.hint = "sand_below"
				"seal_afar":
					link.hint = "sand_afar"
	# The second ways: each written from the higher room to the lower, and between two on a level, from the lower number.
	for join: Dictionary in spec.get("joins", []):
		var a := clampi(int(join.get("a", 0)), 0, count - 1)
		var b := clampi(int(join.get("b", 0)), 0, count - 1)
		if level[a] > level[b] or (level[a] == level[b] and a > b):
			var kept := a
			a = b
			b = kept
		var link := plan.add_link(a, b, maxi(TombPlan.PASS_NAMES.find(join.get("way", "open")), 0) as TombPlan.Pass)
		if join.get("lock", "none") == "within":
			link.switches = [plan.add_trigger(TombPlan.Switch.LEVER, clampi(int(join.get("seal", b)), 0, count - 1)).id]
			link.hint = "from_within"
	return plan


## Makes what was read back from text into what the rest expects, for the
## part of a spec that is about the floor plan: `whole` is the room as
## `TombSpec.tidy` has made it, `read` as it was read.
static func tidy_room(read: Dictionary, whole: Dictionary, index: int) -> void:
	var cell := cell_of(read)
	whole["cell"] = [cell.x, cell.y]
	for key: String in ["from", "lock_in"]:
		var value: Variant = read.get(key, -1)
		whole[key] = int(value) if (value is float or value is int) else -1
	if index == 0:
		whole["from"] = -1


static func tidy_joins(spec: Dictionary) -> void:
	var kept: Array = []
	var read: Variant = spec.get("joins", [])
	if read is Array:
		for join: Variant in read:
			if not join is Dictionary:
				continue
			var made := {"a": -1, "b": -1, "way": "open", "lock": "none", "seal": -1}
			for key: String in ["a", "b", "seal"]:
				var value: Variant = join.get(key, -1)
				made[key] = int(value) if (value is float or value is int) else -1
			made["way"] = str(join.get("way", "open"))
			made["lock"] = str(join.get("lock", "none"))
			if int(made["seal"]) < 0:
				made["seal"] = made["b"]
			kept.append(made)
	spec["joins"] = kept
