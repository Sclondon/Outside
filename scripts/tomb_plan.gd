class_name TombPlan
extends RefCounted
## What a tomb is, before any of it is built: rooms, the ways between them,
## the things that can be carried or pushed, and the things that open doors.
## `TombGenerator` makes one from a seed, `TombSolver` proves it can be
## finished, and `TombBuilder` turns it into stone. Nothing here knows which
## way the camera looks or how big a room is, and the same plan is set out two
## ways: as a section seen from the side (`TombLayout`), and as rooms to be
## walked through with the camera at his back (`TombLayout3D`, which is what a
## room's `cell` is for).
##
## The rooms follow a royal tomb of the New Kingdom, in order down its axis:
## an entrance, corridors, sometimes a well, a pillared hall, an antechamber
## and the burial chamber; with chambers off them above (a loft: a relieving
## chamber or a robbers' cutting) and below (the chamber at the foot of the well).

## What a room is.
enum Role { ENTRANCE, CORRIDOR, WELL, HALL, GALLERY, ANTECHAMBER, BURIAL, LOFT, CRYPT }
## How the way from one room to the next is got along.
enum Pass {
	OPEN, ## A level doorway. A block can be pushed through it.
	STAIRS, ## A flight down.
	CRAWL, ## A passage too low to walk in.
	FLOOD, ## Water to swim: whatever he carries is let go of.
	GAP, ## A pit too wide to jump: swung across on the grappling hook.
	SHAFT, ## Straight down, by a ladder. Both hands are needed.
	CLIMB, ## Up over a ledge by the hands (and down by stepping off: that way, carrying).
	DROP, ## A drop too high to get back up: one way.
	ROPE, ## Straight down a shaft by a hanging rope. The rope wants both hands; with them full he can still step off and drop.
	SAND, ## Up over a face too high to catch, by walking up the heap of sand that pours in when its switches are done.
}
## What can be carried (one thing at a time) or, a block, pushed.
enum Item { TORCH, HOOK, JAR, BLOCK }
## What opens a door. Every one stays done once it is done.
enum Switch {
	LEVER, ## A seal stone in the floor that he treads down.
	WORK_PLATE, ## A plate with its own block in the room: push the one onto the other.
	PLATE, ## A plate whose block has to be brought from the room before.
	OFFERING, ## An offering table that only a jar set on it will weigh down.
	BRAZIER, ## A cold brazier, to be lit with a torch he brings.
	TREASURE, ## What he came for. Taking it opens nothing: it is the goal.
	LEAF, ## A leaf of the Book of the Dead, taken by walking onto it. It takes no hand, and is never put down or lost.
	NAME, ## A gate guardian, who bars the way until he is named: done once he has the leaf (`Trigger.needs`) that says the name.
	SPHINX, ## A sphinx, who wants one of the things he can carry (`Trigger.wants`), and keeps it.
}
## What stands between a mummy and the rest of its room (see `Mummy.KINDS`:
## each is something that kind cannot get past).
enum Barrier { NONE, TRENCH, KERB, NARROW }

const ROLE_NAMES := ["entrance", "corridor", "well", "hall", "gallery", "antechamber", "burial", "loft", "crypt"]
const PASS_NAMES := ["open", "stairs", "crawl", "flood", "gap", "shaft", "climb", "drop", "rope", "sand"]
const ITEM_NAMES := ["torch", "hook", "jar", "block"]
const SWITCH_NAMES := ["lever", "work_plate", "plate", "offering", "brazier", "treasure", "leaf", "name", "sphinx"]
const BARRIER_NAMES := ["none", "trench", "kerb", "narrow"]
## The room a thing is in once a sphinx has it: nowhere. (So a plan with a sphinx has a room fewer to use.)
const GONE := 15
## A room's `cell` until it is given one.
const NO_CELL := Vector3i(-9999, -9999, -9999)


class Room:
	var id := 0
	var role := Role.CORRIDOR
	## Its place down the axis (0 is the entrance), or -1 for a room off it.
	var spine := -1
	## The room it is off, for a loft or a crypt.
	var parent := -1
	## No torches on its walls.
	var dark := false
	## Which `Mummy.Kind` is in it, or -1; what holds that kind back; and
	## whether it is the guardian, woken by the treasure being taken.
	var mummy := -1
	var barrier := Barrier.NONE
	var guardian := false
	## Whether it has a pit across it that kills (a trench does not).
	var pit := false
	## Where it is on the floor plan of a tomb that is walked through: x and z
	## are the square it stands on and y its level, counted downwards (see
	## `TombLayout3D`, which has the rules, and which works the cells out
	## itself for a plan that has none). The tomb seen from the side takes no
	## notice of it.
	var cell := NO_CELL


class Link:
	var id := 0
	var a := 0
	var b := 0
	var pass_kind := Pass.OPEN
	## The switches that must all be done for its door to open (none: no door).
	## For a way up over sand, what must be done for the sand to pour.
	var switches: Array[int] = []
	## A word for what opens it, for the inscription over the door (see TombHooks.HINTS).
	var hint := ""
	## No slab shuts it: Medjed stands in the passage and looks back down it, and
	## nobody crosses his look. Its switches shut his eyes, for good. (To the
	## solver it is a door like any other.)
	var watched := false
	## Set while the plan is made: something has to be carried, or pushed, along here.
	var keep_carry := false
	var keep_push := false
	var fixed := false


class Thing:
	## For a block: the room whose plate it is for. It goes nowhere else.
	var dest := -1
	var id := 0
	var kind := Item.TORCH
	var room := 0


class Trigger:
	var id := 0
	var kind := Switch.LEVER
	var room := 0
	## For a gate guardian (NAME): the leaf that has its name on it (a LEAF's id).
	var needs := -1
	## For a sphinx: what it wants (an `Item`).
	var wants := -1


var seed_value := 0
var difficulty := 0
## Which try this is: 0 unless earlier ones could not be finished.
var sub_seed := 0
var rooms: Array[Room] = []
var links: Array[Link] = []
var things: Array[Thing] = []
var triggers: Array[Trigger] = []
## What `TombSolver` found: the steps of one way through, each an Array
## beginning with what is done (see TombSolver), and what it counted.
var solution: Array = []
var proof: Dictionary = {}


func add_room(role: Role, parent := -1) -> Room:
	var room := Room.new()
	room.id = rooms.size()
	room.role = role
	room.parent = parent
	rooms.append(room)
	return room


func add_link(a: int, b: int, pass_kind: Pass) -> Link:
	var link := Link.new()
	link.id = links.size()
	link.a = a
	link.b = b
	link.pass_kind = pass_kind
	links.append(link)
	return link


func add_thing(kind: Item, room: int) -> Thing:
	var thing := Thing.new()
	thing.id = things.size()
	thing.kind = kind
	thing.room = room
	things.append(thing)
	return thing


func add_trigger(kind: Switch, room: int) -> Trigger:
	var trigger := Trigger.new()
	trigger.id = triggers.size()
	trigger.kind = kind
	trigger.room = room
	triggers.append(trigger)
	return trigger


## The rooms down the axis, in order.
func spine() -> Array[Room]:
	var along: Array[Room] = []
	for room in rooms:
		if room.spine >= 0:
			along.append(room)
	along.sort_custom(func(one: Room, other: Room) -> bool: return one.spine < other.spine)
	return along


## The link from the room at `place` on the axis to the next.
func spine_link(place: int) -> Link:
	var along := spine()
	for link in links:
		if link.a == along[place].id and link.b == along[place + 1].id:
			return link
	return null


func links_of(room: int) -> Array[Link]:
	var found: Array[Link] = []
	for link in links:
		if link.a == room or link.b == room:
			found.append(link)
	return found


## The room off `parent` of that role, or null.
func side_room(parent: int, role: Role) -> Room:
	for room in rooms:
		if room.parent == parent and room.role == role:
			return room
	return null


func entrance() -> int:
	return spine()[0].id


## Whether a switch is one he works by standing on it: a seal stone, or a leaf of the Book lying there.
static func is_trodden(trigger: Trigger) -> bool:
	return trigger.kind == Switch.LEVER or trigger.kind == Switch.LEAF


## The guardian that keeps a way (its NAME switch), the sphinx that does (its SPHINX), or null.
func keeper_of(link: Link, kind: Switch) -> Trigger:
	for id in link.switches:
		if triggers[id].kind == kind:
			return triggers[id]
	return null


## The way a switch is one of the locks of, or null.
func link_of(trigger: int) -> Link:
	for link in links:
		if trigger in link.switches:
			return link
	return null


## Whether a way is kept by one of the creatures: a gate guardian or a sphinx at
## its door, or Medjed beyond it. No block is pushed along such a way.
func keeps(link: Link) -> bool:
	return link.watched or keeper_of(link, Switch.NAME) != null or keeper_of(link, Switch.SPHINX) != null


## Whether the way out of a room is kept by something that stands at its door
## (a guardian, a sphinx) or beyond it (Medjed): no loft goes over such a room.
func is_kept(room: int) -> bool:
	for link in links:
		if link.a != room:
			continue
		if keeps(link):
			return true
	return false


func goal_trigger() -> Trigger:
	for trigger in triggers:
		if trigger.kind == Switch.TREASURE:
			return trigger
	return null


## Whether the way can be gone along from `from` at all.
static func goes(link: Link, from: int) -> bool:
	return link.pass_kind != Pass.DROP or from == link.a


## Whether a thing in the hand comes along the way too, going from `from`.
## (`hook`: the thing is the grappling hook.)
static func carries(link: Link, from: int, hook: bool) -> bool:
	match link.pass_kind:
		Pass.OPEN, Pass.STAIRS, Pass.CRAWL, Pass.DROP:
			return true
		Pass.GAP:
			return hook
		Pass.CLIMB:
			# (down off a ledge with his hands full, yes; up onto it, no)
			return from == link.b
		Pass.ROPE:
			# (the rope is caught and climbed with both hands: but he can step off
			# the lip with them full, and what he drops down with stays down)
			return from == link.a
		Pass.SAND:
			# (the heap, once it is full, comes to within a hop of the lip: his hands are not wanted)
			return true
	return false


## The whole plan as text, the same for the same plan: what is printed, and
## what is fingerprinted to compare two tombs.
func describe() -> String:
	var lines: PackedStringArray = []
	lines.append("tomb seed=%d difficulty=%d sub=%d" % [seed_value, difficulty, sub_seed])
	for room in rooms:
		var line := "room %d %s spine=%d parent=%d" % [room.id, ROLE_NAMES[room.role], room.spine, room.parent]
		if room.dark:
			line += " dark"
		if room.pit:
			line += " pit"
		if room.mummy >= 0:
			line += " mummy=%d behind=%s%s" % [room.mummy, BARRIER_NAMES[room.barrier], " guardian" if room.guardian else ""]
		# (only a plan that was given cells says so: one that was not is the plan it always was)
		if room.cell != NO_CELL:
			line += " cell=%d,%d,%d" % [room.cell.x, room.cell.y, room.cell.z]
		lines.append(line)
	for link in links:
		var line := "link %d %d>%d %s" % [link.id, link.a, link.b, PASS_NAMES[link.pass_kind]]
		if not link.switches.is_empty():
			line += " door=%s hint=%s" % [str(link.switches), link.hint]
		if link.watched:
			line += " watched"
		lines.append(line)
	for thing in things:
		lines.append("thing %d %s in %d%s" % [thing.id, ITEM_NAMES[thing.kind], thing.room, " for %d" % thing.dest if thing.dest >= 0 else ""])
	for trigger in triggers:
		var told := "switch %d %s in %d" % [trigger.id, SWITCH_NAMES[trigger.kind], trigger.room]
		if trigger.needs >= 0:
			told += " needs=%d" % trigger.needs
		if trigger.wants >= 0:
			told += " wants=%s" % ITEM_NAMES[trigger.wants]
		lines.append(told)
	return "\n".join(lines)


func fingerprint() -> String:
	return TombRandom.fingerprint(describe())
