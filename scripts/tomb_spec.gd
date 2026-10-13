class_name TombSpec
extends RefCounted
## A tomb made by hand (in the tomb editor, `tomb_editor.tscn`), as plain data
## that can be kept as text: its rooms in their order down the axis, and of
## each what it is, what is in it, the way on from it and what locks that way.
## `compile` makes the `TombPlan` it describes, which is then laid out, built
## and played exactly as a tomb from the generator is (`TombLayout`,
## `TombBuilder`, `TombLevel`), and proved by the same `TombSolver`.
##
## It says no more than the generator's own rules can make, because those are
## what the layout knows how to set in stone: `problems` lists whatever in a
## tomb is outside them, and nothing with a problem is built.
##
##     {"version": 1, "name": "My tomb", "seed": 7, "difficulty": 0, "sub": 0, "rooms": [
##         {"role": "entrance", "way": "stairs"},
##         {"role": "corridor", "torch": 1, "way": "open"},
##         {"role": "hall", "dark": true, "mummy": 0, "way": "stairs", "lock": "brazier"},
##         {"role": "burial", "mummy": 5}]}
##
## Of a room: `role` (one of `TombPlan.ROLE_NAMES`: the first is the entrance,
## the last the burial chamber), `dark`, `pit`, `mummy` (a `Mummy.Kind`, or -1)
## and `barrier` ("auto", or one of `TombPlan.BARRIER_NAMES`), how many of each
## thing lie in it (`torch`, `hook`, `jar`), `way` (one of WAYS: how the next
## room is got to), `lock` (one of LOCKS: what opens the door on), and for a
## seal stone `stone_in` (which room it is over, or under: counted from 0).
## Where the way on is up the sand (`sand`), the lock is what lets the sand in,
## and with no lock it is a seal stone at the foot of the face.
## `seed`, `difficulty` and `sub` only settle the sizes of the rooms.
##
## A tomb that branches says `"shape": "branching"`, and of each room which
## square of a floor plan it stands on and which room it is entered from, with
## `joins` for second ways between rooms (loops). That part is `TombFloorSpec`,
## which has what such a spec says and means; `problems`, `compile`, `check`
## and `tidy` here go to it for one. A spec that does not say so is a tomb down
## one axis, as every spec was before there were any that branch.

const VERSION := 1
const FILE := "user://my_tombs.json"
## The fewest and the most rooms down the axis.
const FEWEST := 3
const MOST := 12

## What a room between the entrance and the burial chamber can be.
const MIDDLE_ROLES := ["corridor", "well", "hall", "gallery", "antechamber"]
const ROLE_TITLES := {"entrance": "Entrance", "corridor": "Corridor", "well": "Well", "hall": "Pillared hall", "gallery": "High gallery",
	"antechamber": "Antechamber", "burial": "Burial chamber", "loft": "Loft", "crypt": "Chamber under the well"}
## How the next room is got to, and what each is called.
const WAYS := ["open", "stairs", "crawl", "flood", "shaft", "rope", "gap", "sand"]
const WAY_TITLES := {"open": "A level doorway", "stairs": "Stairs down", "crawl": "A crawl", "flood": "Water to swim",
	"shaft": "A ladder down a shaft", "rope": "A rope down a shaft", "gap": "A pit to swing over (hook)", "sand": "Up a face, on poured sand"}
## What each way asks of whoever is making the tomb (nothing, for most).
const WAY_NOTES := {
	"flood": "He lets go of whatever he carries in the water.",
	"shaft": "Nothing is carried up or down a ladder.",
	"rope": "He jumps into the rope to take hold, and at the top leaps off onto the floor. It wants both hands: nothing comes back up it, though he can drop down with a thing.",
	"gap": "Wants a grappling hook, left in an earlier room.",
	"sand": "The next room is higher, over a face he cannot climb until sand has poured in to stand on. What lets it in is the lock below; with none, a seal stone at the foot of the face. Nothing is carried up it.",
}
## What opens the door on, and what each is called.
const LOCKS := ["none", "work", "cross", "pair", "brazier", "offering", "lever_above", "lever_below", "bypass", "name", "name_above", "name_below", "sphinx_jar", "sphinx_torch", "sphinx_hook", "gaze_work", "gaze_above", "gaze_below"]
const LOCK_TITLES := {"none": "No door", "work": "A block and its plate", "cross": "A plate, its block from the room before",
	"pair": "Two plates: its own block, and one from the room before",
	"brazier": "A brazier to light", "offering": "A block, and a jar on the table", "lever_above": "A seal stone up in a loft",
	"lever_below": "A seal stone under a well", "bypass": "Opened from behind, over the wall",
	"name": "A gate guardian, his leaf in a room before", "name_above": "A gate guardian, his leaf up in a loft", "name_below": "A gate guardian, his leaf under a well",
	"sphinx_jar": "A sphinx that wants a jar", "sphinx_torch": "A sphinx that wants a burning torch", "sphinx_hook": "A sphinx that wants the grappling hook",
	"gaze_work": "Medjed, his eyes shut by a block on its plate", "gaze_above": "Medjed, his eyes shut by a seal stone in a loft", "gaze_below": "Medjed, his eyes shut by a seal stone under a well"}
## What each lock asks of whoever is making the tomb.
const LOCK_NOTES := {
	"none": "",
	"work": "The block stands in this room: he pushes it onto the plate.",
	"cross": "The block starts in the room before, and that room's way on has to be a level doorway.",
	"pair": "Two plates, and both must be down: this room's own block on one, and on the other a block pushed in from the room before, whose way on has to be a level doorway.",
	"brazier": "Wants a torch brought here: leave one in an earlier room. The room is usually dark.",
	"offering": "A block to push, and a jar to set on the table: leave a jar in an earlier room.",
	"lever_above": "A slab over a room, caught by its edge. The stone on it opens this door.",
	"lever_below": "The chamber at the foot of a well. The stone in it opens this door.",
	"bypass": "A cutting goes over the wall and drops beyond it; the stone that opens the door is there. The way on becomes stairs.",
	"name": "A keeper sits by the way with his knives across it until he is told his name. The leaf that says it lies in the room you choose below. Without it he can guess: one chance in three, and a wrong name is his death.",
	"name_above": "A keeper bars the way until he is told his name. The leaf that says it is on a slab over a room, caught by its edge.",
	"name_below": "A keeper bars the way until he is told his name. The leaf that says it is in the chamber at the foot of a well.",
	"sphinx_jar": "A small sphinx lies at the end of the room and asks a riddle: the answer is a canopic jar, put down before its paws. It keeps the jar, and the door is open for good. Leave a jar in an earlier room.",
	"sphinx_torch": "A small sphinx lies at the end of the room and asks a riddle: the answer is a burning torch, put down before its paws. It keeps the torch, and the door is open for good. Leave a torch in an earlier room.",
	"sphinx_hook": "A small sphinx lies at the end of the room and asks a riddle: the answer is the grappling hook, put down before its paws. It keeps the hook: if a pit wants one too, leave two.",
	"gaze_work": "No door: Medjed stands in the way beyond and looks back down it, and whoever comes under his eyes is struck dead after a moment. The block in this room, pushed onto its plate, shuts them for good.",
	"gaze_above": "No door: Medjed stands in the way beyond and looks back down it, and whoever comes under his eyes is struck dead after a moment. A seal stone on a slab over a room shuts them for good.",
	"gaze_below": "No door: Medjed stands in the way beyond and looks back down it, and whoever comes under his eyes is struck dead after a moment. A seal stone at the foot of a well shuts them for good.",
}
## What the editors say of Apophis, who is only ever put in by hand.
const APOPHIS_NOTE := "The serpent lies down a hole at the far end of the burial chamber and comes out when the falcon is taken. He follows the boy out by the boy's own trail, a little slower than a clean run. Nothing proves he can be outrun: try the tomb."
const THINGS := ["torch", "hook", "jar"]
const THING_TITLES := {"torch": "Torch", "hook": "Grappling hook", "jar": "Jar"}
const MUMMY_TITLES := ["Shambler", "Priest", "Brute", "Crawler", "Child", "Royal"]
const BARRIER_TITLES := {"auto": "What suits it", "trench": "A trench", "kerb": "A kerb", "narrow": "A narrow gap", "none": "Nothing"}

## Where the thing a lock wants lies, for a lock whose `stone_in` says which
## room: "above" (in a loft over it), "below" (in the chamber under it, a
## well), "inside" (on its floor); or nothing, for a lock that has no such thing.
static func host_kind(lock: String) -> String:
	match lock:
		"lever_above", "name_above", "gaze_above":
			return "above"
		"lever_below", "name_below", "gaze_below":
			return "below"
		"seal", "name", "gaze_seal":
			return "inside"
	return ""


## What the editors call the room a lock's `stone_in` says.
static func host_title(lock: String) -> String:
	return {"lever_above": "Its stone is over", "lever_below": "Its stone is under", "seal": "Its stone lies just inside",
		"name": "His leaf lies in", "name_above": "His leaf is over", "name_below": "His leaf is under",
		"gaze_above": "The stone is over", "gaze_below": "The stone is under", "gaze_seal": "The stone lies just inside"}.get(lock, "It is in")


## A lock that Medjed keeps (`gaze_...`) as the plain lock that would have had a door: what shuts his eyes is what would have opened it.
static func plain_lock(lock: String) -> String:
	return {"gaze_work": "work", "gaze_above": "lever_above", "gaze_below": "lever_below", "gaze_seal": "seal"}.get(lock, lock)


## And the other way about: the lock of that kind that Medjed keeps, or the lock itself if he keeps none such.
static func gaze_lock(lock: String) -> String:
	return {"work": "gaze_work", "lever_above": "gaze_above", "lever_below": "gaze_below", "seal": "gaze_seal"}.get(lock, lock)


## Whether a lock is one of the creatures' that keep a way: no block is pushed along it.
static func keeps_way(lock: String) -> bool:
	return lock.begins_with("name") or lock.begins_with("sphinx") or lock.begins_with("gaze")


## Whether a lock is a gate guardian's.
static func is_keeper(lock: String) -> bool:
	return lock.begins_with("name")


static var _reach := {}
## Where they are kept. The tools set another, or one is given on the command
## line (`-- tombs_file=<file>`), so that nothing they do is written over the
## player's own (as `TombDaily.path`).
static var path := FILE


static func _static_init() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("tombs_file="):
			path = arg.trim_prefix("tombs_file=")


## Whether it is a tomb that branches: rooms on a floor plan (see `TombFloorSpec`).
static func is_branching(spec: Dictionary) -> bool:
	return spec.get("shape", "line") == "branching"


# --- Making one

## A room of that kind as it starts.
static func room(role: String) -> Dictionary:
	var made := {"role": role, "dark": false, "pit": false, "mummy": -1, "barrier": "auto", "torch": 0, "hook": 0, "jar": 0, "way": "open", "lock": "none", "stone_in": 0, "apophis": false}
	if role == "entrance":
		made["way"] = "stairs"
	return made


## A small tomb to begin from.
static func fresh(name := "My tomb") -> Dictionary:
	return {"version": VERSION, "name": name, "seed": 1, "difficulty": 0, "sub": 0,
		"rooms": [room("entrance"), room("corridor"), room("antechamber"), room("burial")]}


## The tomb the generator makes from a number, as one to change by hand.
static func from_seed(seed_value: int, difficulty: int) -> Dictionary:
	var spec := from_plan(TombGenerator.generate(seed_value, difficulty))
	spec["name"] = "Tomb %d" % seed_value
	return spec


## A plan (one of the generator's) as a tomb to change by hand.
static func from_plan(plan: TombPlan) -> Dictionary:
	var spec := {"version": VERSION, "name": "Tomb", "seed": plan.seed_value, "difficulty": plan.difficulty, "sub": plan.sub_seed, "rooms": []}
	var along := plan.spine()
	for i in along.size():
		var from := along[i]
		var told := room(TombPlan.ROLE_NAMES[from.role])
		told["dark"] = from.dark
		told["pit"] = from.pit
		told["apophis"] = from.snake
		told["mummy"] = from.mummy
		if from.mummy >= 0 and from.barrier != TombGenerator.BARRIER_FOR.get(from.mummy, TombPlan.Barrier.NONE):
			told["barrier"] = TombPlan.BARRIER_NAMES[from.barrier]
		for thing in plan.things:
			if thing.room == from.id and thing.kind != TombPlan.Item.BLOCK:
				var what: String = TombPlan.ITEM_NAMES[thing.kind]
				told[what] = int(told[what]) + 1
		if i < along.size() - 1:
			var link := plan.spine_link(i)
			told["way"] = TombPlan.PASS_NAMES[link.pass_kind]
			match link.hint.trim_prefix("gaze_"):
				"weight":
					told["lock"] = "work"
				"weight_from_afar":
					told["lock"] = "cross"
				"two_stones":
					told["lock"] = "pair"
				"fire":
					told["lock"] = "brazier"
				"two_weights":
					told["lock"] = "offering"
				"over_the_wall":
					told["lock"] = "bypass"
				"sphinx_jar", "sphinx_torch", "sphinx_hook":
					told["lock"] = link.hint
				"name":
					told["lock"] = "name"
					told["stone_in"] = plan.rooms[plan.triggers[plan.triggers[link.switches[0]].needs].room].spine
				"name_above", "name_below":
					told["lock"] = link.hint
					told["stone_in"] = plan.rooms[plan.triggers[plan.triggers[link.switches[0]].needs].room].parent
				"lever_above", "lever_below", "sand_above", "sand_below":
					told["lock"] = "lever_above" if link.hint.ends_with("above") else "lever_below"
					told["stone_in"] = plan.rooms[plan.triggers[link.switches[0]].room].parent
		if i < along.size() - 1 and plan.spine_link(i).watched:
			told["lock"] = gaze_lock(told["lock"])
		(spec["rooms"] as Array).append(told)
	return spec


# --- What is wrong with one

## What a room is called, with its number as the editor counts them (from 1).
static func room_title(spec: Dictionary, index: int) -> String:
	var rooms: Array = spec.get("rooms", [])
	if index < 0 or index >= rooms.size():
		return "Room %d" % (index + 1)
	return "%d %s" % [index + 1, ROLE_TITLES.get(rooms[index].get("role", ""), "Room")]


## Everything in it that could not be built; empty if it can be.
static func problems(spec: Dictionary) -> PackedStringArray:
	if is_branching(spec):
		return TombFloorSpec.problems(spec)
	var wrong: PackedStringArray = []
	var rooms: Array = spec.get("rooms", [])
	var count := rooms.size()
	if count < FEWEST:
		wrong.append("A tomb wants at least %d rooms." % FEWEST)
		return wrong
	if count > MOST:
		wrong.append("A tomb has at most %d rooms down its axis." % MOST)
	if rooms[0].get("role", "") != "entrance":
		wrong.append("The first room has to be the entrance.")
	if rooms[count - 1].get("role", "") != "burial":
		wrong.append("The last room has to be the burial chamber.")
	# (which rooms have a slab over them already, and what for; and which wells a chamber under them)
	var lofts := {}
	var crypts := {}
	for i in count:
		var told: Dictionary = rooms[i]
		var title := room_title(spec, i)
		var role: String = told.get("role", "")
		var way: String = told.get("way", "open")
		var lock: String = plain_lock(told.get("lock", "none"))
		if i > 0 and i < count - 1 and not role in MIDDLE_ROLES:
			wrong.append("%s: only the first room is an entrance and only the last a burial chamber." % title)
		var mummy := int(told.get("mummy", -1))
		if mummy >= MUMMY_TITLES.size():
			wrong.append("%s: there is no such mummy." % title)
		if i == 0:
			if mummy >= 0 or told.get("pit", false):
				wrong.append("%s: nothing waits out of doors, and there is no pit there." % title)
			if not way in ["open", "stairs"]:
				wrong.append("%s: the way in from outside is a doorway or stairs." % title)
			if lock != "none":
				wrong.append("%s: the way in has no door." % title)
		if i < count - 1 and told.get("apophis", false):
			wrong.append("%s: Apophis lies in the burial chamber, and nowhere else." % title)
		if i == count - 1:
			if told.get("pit", false):
				wrong.append("%s: there is no pit in the burial chamber." % title)
			continue
		if not way in WAYS:
			wrong.append("%s: there is no such way on." % title)
		if not lock in LOCKS:
			wrong.append("%s: there is no such lock." % title)
			continue
		if lock != "none" and lock != "bypass" and way in ["crawl", "shaft", "rope", "gap"]:
			wrong.append("%s: %s has no door to lock. Make the way on a doorway, stairs or water." % [title, String(WAY_TITLES[way]).to_lower()])
		if way == "sand":
			if lock == "bypass":
				wrong.append("%s: the way over the wall comes down stairs: it cannot also go up the sand." % title)
			if i + 1 < count - 1 and int(rooms[i + 1].get("mummy", -1)) >= 0:
				wrong.append("%s: nothing can wait at the top of the sand: it would come down it after him." % room_title(spec, i + 1))
		match lock:
			"cross", "pair":
				if i < 2:
					wrong.append("%s: there is no room before it to bring a block from." % title)
				elif rooms[i - 1].get("way", "open") != "open" or rooms[i - 1].get("lock", "none") == "bypass":
					wrong.append("%s: its block is pushed in from %s, so that room's way on has to be a level doorway." % [title, room_title(spec, i - 1)])
				elif keeps_way(rooms[i - 1].get("lock", "none")):
					wrong.append("%s: its block is pushed in from %s, whose door a guardian, a sphinx or Medjed keeps: no block goes that way." % [title, room_title(spec, i - 1)])
			"bypass":
				if lofts.has(i):
					wrong.append("%s: it has a loft already (for a seal stone); the way over the wall wants one of its own." % title)
				lofts[i] = "bypass"
			"name":
				var host := int(told.get("stone_in", i))
				if host < 1 or host > i:
					wrong.append("%s: the leaf with its keeper's name has to lie in this room or an earlier one (not out of doors)." % title)
			"lever_above", "name_above":
				var host := int(told.get("stone_in", i))
				if host < 1 or host > i:
					wrong.append("%s: the loft with its seal stone has to be over this room or an earlier one." % title)
				elif rooms[host].get("role", "") == "well":
					wrong.append("%s: there is no loft over a well. Put its seal stone under the well instead." % title)
				elif rooms[host].get("way", "open") == "sand":
					wrong.append("%s: there is no loft over %s, whose way on is up the sand: he would get up the face from it." % [title, room_title(spec, host)])
				elif lofts.has(host):
					wrong.append("%s: the loft over %s is already used." % [title, room_title(spec, host)])
				else:
					lofts[host] = "lever"
			"lever_below", "name_below":
				var host := int(told.get("stone_in", i))
				if host < 1 or host > i or rooms[host].get("role", "") != "well":
					wrong.append("%s: its seal stone has to be under a well, in this room or an earlier one." % title)
				elif crypts.has(host):
					wrong.append("%s: the chamber under %s already has a seal stone." % [title, room_title(spec, host)])
				else:
					crypts[host] = true
	# (a gate guardian sits by his door, under where the floor of a loft would be)
	for i in count - 1:
		var kept_by: String = rooms[i].get("lock", "none")
		if keeps_way(kept_by):
			if rooms[i].get("way", "open") == "sand":
				wrong.append("%s: a gate guardian, a sphinx or Medjed keeps a doorway, stairs or water, not the way up the sand." % room_title(spec, i))
			if lofts.has(i) and not kept_by.begins_with("gaze"):
				wrong.append("%s: its door has a gate guardian or a sphinx, and there is no loft over the room of one: put the loft over another room." % room_title(spec, i))
	if not wrong.is_empty():
		return wrong
	var plan := compile(spec)
	var most_rooms := 1 << TombSolver.POS_BITS
	for trigger in plan.triggers:
		# (what a sphinx has been given is kept, by the solver, in a room that is not there)
		if trigger.kind == TombPlan.Switch.SPHINX:
			most_rooms = TombPlan.GONE
	if plan.rooms.size() > most_rooms:
		wrong.append("Too many rooms, with the lofts and chambers: %d, and %d is the most%s." % [plan.rooms.size(), most_rooms, " in a tomb with a sphinx" if most_rooms == TombPlan.GONE else ""])
	if plan.things.size() > (1 << TombSolver.HAND_BITS) - 1:
		wrong.append("Too many things to carry and push: %d, and %d is the most." % [plan.things.size(), (1 << TombSolver.HAND_BITS) - 1])
	if plan.triggers.size() > TombSolver.DONE_BITS:
		wrong.append("Too many plates, stones and braziers: %d, and %d is the most." % [plan.triggers.size() - 1, TombSolver.DONE_BITS - 1])
	return wrong


# --- The plan of one

## The plan it describes. (Ask `problems` first: this takes it as it is.)
static func compile(spec: Dictionary) -> TombPlan:
	if is_branching(spec):
		return TombFloorSpec.compile(spec)
	var plan := TombPlan.new()
	plan.seed_value = int(spec.get("seed", 1))
	plan.difficulty = clampi(int(spec.get("difficulty", 0)), 0, 2)
	plan.sub_seed = int(spec.get("sub", 0))
	var rooms: Array = spec.get("rooms", [])
	var count := rooms.size()
	for i in count:
		var told: Dictionary = rooms[i]
		var made := plan.add_room(maxi(TombPlan.ROLE_NAMES.find(told.get("role", "corridor")), 0) as TombPlan.Role)
		made.spine = i
		made.dark = told.get("dark", false)
		made.pit = told.get("pit", false)
		made.snake = told.get("apophis", false) and made.role == TombPlan.Role.BURIAL
		made.mummy = int(told.get("mummy", -1))
		if made.mummy >= 0:
			var barrier: String = told.get("barrier", "auto")
			if barrier == "auto":
				made.barrier = TombGenerator.BARRIER_FOR.get(made.mummy, TombPlan.Barrier.TRENCH)
			else:
				made.barrier = maxi(TombPlan.BARRIER_NAMES.find(barrier), 0) as TombPlan.Barrier
			made.guardian = i == count - 1
		if i > 0:
			var way := TombPlan.PASS_NAMES.find(rooms[i - 1].get("way", "open"))
			plan.add_link(i - 1, i, maxi(way, 0) as TombPlan.Pass)
	plan.add_trigger(TombPlan.Switch.TREASURE, count - 1)
	for i in count:
		for what: String in THINGS:
			for n in int(rooms[i].get(what, 0)):
				plan.add_thing(TombPlan.ITEM_NAMES.find(what) as TombPlan.Item, i)
	# The locks, each as the generator's rule of the same name puts it in.
	for i in count - 1:
		var told: Dictionary = rooms[i]
		var link := plan.spine_link(i)
		if link.pass_kind == TombPlan.Pass.GAP:
			link.hint = "hook"
		elif link.pass_kind == TombPlan.Pass.ROPE:
			link.hint = "rope"
		var lock: String = plain_lock(told.get("lock", "none"))
		match lock:
			"work":
				link.switches = [plan.add_trigger(TombPlan.Switch.WORK_PLATE, i).id]
				link.hint = "weight"
			"cross":
				plan.add_thing(TombPlan.Item.BLOCK, i - 1).dest = i
				link.switches = [plan.add_trigger(TombPlan.Switch.PLATE, i).id]
				link.hint = "weight_from_afar"
			"pair":
				plan.add_thing(TombPlan.Item.BLOCK, i - 1).dest = i
				link.switches = [plan.add_trigger(TombPlan.Switch.PLATE, i).id, plan.add_trigger(TombPlan.Switch.WORK_PLATE, i).id]
				link.hint = "two_stones"
			"brazier":
				link.switches = [plan.add_trigger(TombPlan.Switch.BRAZIER, i).id]
				link.hint = "fire"
			"offering":
				link.switches = [plan.add_trigger(TombPlan.Switch.WORK_PLATE, i).id, plan.add_trigger(TombPlan.Switch.OFFERING, i).id]
				link.hint = "two_weights"
			"sphinx_jar", "sphinx_torch", "sphinx_hook":
				_sphinx(plan, link, i, told["lock"])
			"name":
				_keeper(plan, link, i, clampi(int(told.get("stone_in", i)), 0, count - 1), "name")
			"lever_above", "name_above":
				var host := int(told.get("stone_in", i))
				var loft := plan.add_room(TombPlan.Role.LOFT, host)
				plan.add_link(host, loft.id, TombPlan.Pass.CLIMB)
				if told["lock"] == "name_above":
					_keeper(plan, link, i, loft.id, "name_above")
				else:
					link.switches = [plan.add_trigger(TombPlan.Switch.LEVER, loft.id).id]
					link.hint = "lever_above"
			"lever_below", "name_below":
				var host := int(told.get("stone_in", i))
				var crypt := plan.add_room(TombPlan.Role.CRYPT, host)
				plan.add_link(host, crypt.id, TombPlan.Pass.SHAFT)
				if told["lock"] == "name_below":
					_keeper(plan, link, i, crypt.id, "name_below")
				else:
					link.switches = [plan.add_trigger(TombPlan.Switch.LEVER, crypt.id).id]
					link.hint = "lever_below"
			"bypass":
				var loft := plan.add_room(TombPlan.Role.LOFT, i)
				plan.add_link(i, loft.id, TombPlan.Pass.CLIMB)
				plan.add_link(loft.id, i + 1, TombPlan.Pass.DROP)
				link.pass_kind = TombPlan.Pass.STAIRS
				link.switches = [plan.add_trigger(TombPlan.Switch.LEVER, i + 1).id]
				link.hint = "over_the_wall"
		if lock != told.get("lock", "none"):
			link.watched = true
			link.hint = "gaze_" + link.hint
		# Up the sand: with no lock of its own, a seal stone at the foot of the face lets it in.
		if link.pass_kind == TombPlan.Pass.SAND:
			match link.hint:
				"":
					link.switches = [plan.add_trigger(TombPlan.Switch.LEVER, i).id]
					link.hint = "sand"
				"lever_above":
					link.hint = "sand_above"
				"lever_below":
					link.hint = "sand_below"
	return plan


## Puts a gate guardian on a way, in the room `door` its door is in, and the
## leaf that has his name on it in the room `lies`.
static func _keeper(plan: TombPlan, link: TombPlan.Link, door: int, lies: int, hint: String) -> void:
	var leaf := plan.add_trigger(TombPlan.Switch.LEAF, lies)
	var keeper := plan.add_trigger(TombPlan.Switch.NAME, door)
	keeper.needs = leaf.id
	link.switches = [keeper.id]
	link.hint = hint


## Puts a sphinx at a way, in the room `door` its door is in, that wants what the lock's name says.
static func _sphinx(plan: TombPlan, link: TombPlan.Link, door: int, lock: String) -> void:
	var asks := plan.add_trigger(TombPlan.Switch.SPHINX, door)
	asks.wants = maxi(TombPlan.ITEM_NAMES.find(lock.trim_prefix("sphinx_")), 0)
	link.switches = [asks.id]
	link.hint = lock


## Everything there is to say of it. `problems` (it cannot be built: then
## nothing else is here), `plan`, `layout`, `solved` (what `TombSolver` found),
## `ok` (it can be finished, whatever he does), `says` (that, in a line) and
## `warnings` (what is in it that he could not do, or that would not hold a mummy).
static func check(spec: Dictionary) -> Dictionary:
	var found := {"problems": problems(spec), "warnings": PackedStringArray(), "plan": null, "layout": null, "solved": {}, "ok": false, "says": ""}
	if not (found["problems"] as PackedStringArray).is_empty():
		found["says"] = found["problems"][0]
		return found
	var plan := compile(spec)
	var solved := TombSolver.solve(plan)
	plan.solution = solved["steps"]
	plan.proof = solved
	var layout: TombLayout = TombLayout3D.set_out(plan) if is_branching(spec) else TombLayout.lay(plan)
	if _reach.is_empty():
		_reach = TombReach.measure()
	found["plan"] = plan
	found["layout"] = layout
	found["solved"] = solved
	found["warnings"] = TombReach.check(layout, _reach)
	found["ok"] = solved["ok"]
	if solved["ok"]:
		found["says"] = "It can be finished: %d moves, in and out." % (solved["steps"] as Array).size()
	else:
		var why: String = solved["reason"]
		match why:
			"a room cannot be reached":
				var names: PackedStringArray = []
				for id: int in solved["unreached"]:
					names.append(place_title(spec, plan, id))
				why = "he cannot get into %s" % ", ".join(names)
			"it can be made unfinishable":
				why = "it can be finished, but he can also get himself stuck (%d ways)" % int(solved["dead"])
		found["says"] = "Not sound: %s." % why
	return found


## What a room of the plan is called: one on the axis by its number, a loft or a chamber by the room it is off.
static func place_title(spec: Dictionary, plan: TombPlan, id: int) -> String:
	var made := plan.rooms[id]
	if made.spine >= 0:
		return room_title(spec, made.spine)
	if made.role == TombPlan.Role.LOFT:
		return "the loft over %s" % room_title(spec, made.parent)
	return "the chamber under %s" % room_title(spec, made.parent)


## One step of the solver's way through, in words.
static func step_words(spec: Dictionary, plan: TombPlan, step: Array) -> String:
	match step[0]:
		"go":
			var link: TombPlan.Link = plan.links[step[1]]
			var how: String = {"open": "through the doorway", "stairs": "by the stairs", "crawl": "through the crawl", "flood": "through the water", "gap": "over the pit, on the hook",
				"shaft": "by the ladder", "climb": "over the edge", "drop": "down the drop", "rope": "by the rope", "sand": "over the sand"}[TombPlan.PASS_NAMES[link.pass_kind]]
			if link.watched:
				how += ", past Medjed, whose eyes are shut"
			elif plan.keeper_of(link, TombPlan.Switch.NAME) != null and step[2] == link.a:
				how += ", under the guardian's knives"
			return "Go to %s, %s" % [place_title(spec, plan, step[3]), how]
		"push":
			return "Push the block into %s" % place_title(spec, plan, step[4])
		"take":
			return "Take the %s" % String(TombPlan.ITEM_NAMES[plan.things[step[1]].kind])
		"drop":
			return "Put the %s down" % String(TombPlan.ITEM_NAMES[plan.things[step[1]].kind])
		"do":
			match plan.triggers[step[1]].kind:
				TombPlan.Switch.LEVER:
					return "Tread on the seal stone"
				TombPlan.Switch.WORK_PLATE, TombPlan.Switch.PLATE:
					return "Push the block onto the plate"
				TombPlan.Switch.OFFERING:
					return "Set the jar on the offering table"
				TombPlan.Switch.BRAZIER:
					return "Light the brazier"
				TombPlan.Switch.TREASURE:
					return "Take the falcon"
				TombPlan.Switch.SPHINX:
					return "Put the %s down before the sphinx: it keeps it" % String(TombPlan.ITEM_NAMES[plan.triggers[step[1]].wants])
				TombPlan.Switch.LEAF:
					return "Walk onto the leaf of the Book of the Dead, and read the keeper's name"
				TombPlan.Switch.NAME:
					return "Go up to the gate guardian, and tell him his name"
	return str(step)


# --- Keeping them

## Everything kept on this device: `tombs` (each by its name) and `current` (the name of the one last worked on).
static func load_all() -> Dictionary:
	var kept := {"version": VERSION, "current": "", "tombs": {}}
	if not FileAccess.file_exists(path):
		return kept
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return kept
	var read: Variant = JSON.parse_string(file.get_as_text())
	if read is Dictionary:
		for key: String in kept:
			if read.has(key) and typeof(read[key]) == typeof(kept[key]):
				kept[key] = read[key]
	return kept


static func save_all(kept: Dictionary) -> bool:
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		return false
	file.store_string(JSON.stringify(kept, "\t"))
	return true


## Keeps a tomb under its name, and makes it the one being worked on. Says whether it could.
static func keep(spec: Dictionary) -> bool:
	var kept := load_all()
	var name: String = spec.get("name", "My tomb")
	kept["tombs"][name] = spec.duplicate(true)
	kept["current"] = name
	return save_all(kept)


## The tomb last worked on, or a new one.
static func current() -> Dictionary:
	var kept := load_all()
	var found: Variant = kept["tombs"].get(kept["current"], null)
	if found is Dictionary and tidy(found):
		return found
	return fresh()


static func names() -> Array:
	var found: Array = load_all()["tombs"].keys()
	found.sort()
	return found


static func open(name: String) -> Dictionary:
	var found: Variant = load_all()["tombs"].get(name, null)
	if found is Dictionary and tidy(found):
		return found
	return {}


static func forget(name: String) -> void:
	var kept := load_all()
	kept["tombs"].erase(name)
	if kept["current"] == name:
		kept["current"] = ""
	save_all(kept)


## A name like `wanted` that no kept tomb has.
static func free_name(wanted: String) -> String:
	var taken := names()
	if not wanted in taken:
		return wanted
	var n := 2
	while "%s %d" % [wanted, n] in taken:
		n += 1
	return "%s %d" % [wanted, n]


static func to_text(spec: Dictionary) -> String:
	return JSON.stringify(spec, "\t")


## The tomb that text says, or an empty Dictionary if it is not one.
static func from_text(text: String) -> Dictionary:
	# (asked this way, text that is nothing of the kind is not complained of)
	var reader := JSON.new()
	if reader.parse(text) != OK:
		return {}
	var read: Variant = reader.data
	if read is Dictionary and tidy(read):
		return read
	return {}


## Makes what was read back from text into what the rest expects (text keeps
## every number as a fraction), and fills in whatever a room does not say.
## Says whether it is a tomb at all.
static func tidy(spec: Dictionary) -> bool:
	if not spec.get("rooms", null) is Array or (spec["rooms"] as Array).is_empty():
		return false
	spec["version"] = VERSION
	spec["name"] = str(spec.get("name", "My tomb"))
	if is_branching(spec):
		spec["shape"] = "branching"
		TombFloorSpec.tidy_joins(spec)
	for key: String in ["seed", "difficulty", "sub"]:
		spec[key] = int(spec.get(key, 1 if key == "seed" else 0))
	var rooms: Array = spec["rooms"]
	for i in rooms.size():
		if not rooms[i] is Dictionary:
			return false
		var whole := room(str(rooms[i].get("role", "corridor")))
		for key: String in whole:
			var value: Variant = rooms[i].get(key, whole[key])
			if whole[key] is int:
				value = int(value) if (value is float or value is int) else whole[key]
			elif typeof(value) != typeof(whole[key]):
				value = whole[key]
			whole[key] = value
		if is_branching(spec):
			TombFloorSpec.tidy_room(rooms[i], whole, i)
		rooms[i] = whole
	return true
