class_name TombBranching
extends RefCounted
## Makes the plan of a tomb that branches: rooms on a floor plan, with ways
## off to either side, side chambers, dead ends and loops. It is the third
## kind of tomb (`TombGenerator` makes the other two, which are one plan seen
## two ways), and what it makes is only ever walked through (`TombLayout3D`):
## every room is given its `cell`, and the cells keep that layout's rules.
## Like `TombGenerator` it never hands back a tomb that cannot be finished.
##
## How (each stage only adds what the ones before allow):
##
##  1. The trunk: the way from the entrance to the burial chamber, a royal
##     tomb's rooms in their order, on squares of the plan, turning as the dice
##     say and never onto a square that is taken.
##  2. Locks, each on a way that is the only way to whatever is beyond it, and
##     each put in with its key in one move (the rules below). Most keys go
##     somewhere off the way he is on: in a side chamber that is made for it
##     off a room at or before the door (so that he goes and fetches it), in a
##     loft, at the foot of a well. A side chamber can be locked in its turn.
##     Before a lock is put in, it is asked whether every room could still be
##     got to with the locks and keys as they would then be (`_reaches_all`),
##     and whether everything that is carried could still be carried to where
##     it is wanted from anywhere it could be left (`_carry_sound`).
##  3. Dead ends: rooms off the others with nothing in them (in a harder tomb,
##     nothing but a mummy).
##  4. The ways themselves (stairs, a crawl, water, a ladder, a rope), never one
##     that a thing which has to be carried along it could not pass; and from
##     them the level of each room.
##  5. Loops: where two rooms that are not joined stand on squares side by side,
##     a second way between them. Where the one is further down the same way
##     as the other, it is a door that opens only from the far side (a seal
##     stone just inside the further room): a short cut back, which gets him
##     past no lock he has not already opened. Between two branches it is a
##     plain way (a doorway, a crawl, water, stairs), and only where no lock
##     stands on the way round.
##  6. Mummies (the dead ends first) and pits.
##  7. `TombSolver` plays it through, as for any tomb: thrown away and made
##     again from the next sub-seed if it fails, up to `MAX_TRIES`, and after
##     that a plain branching tomb with no locks.
##
## Everything random comes from one `TombRandom`, seeded from the version of
## this generator, the seed, the difficulty and the sub-seed.

## Changed whenever a change here would make a different tomb from the same
## seed. (Its own: `TombGenerator.VERSION` is the other generator's.)
const VERSION := 1
const MAX_TRIES := 40
## For each difficulty: the fewest and most rooms from the entrance to the
## burial chamber, locks, rooms off that way (side chambers and dead ends),
## the fewest and most loops (where there are rooms side by side to close one between), and how many mummies.
const TRUNK := [[4, 5], [5, 6], [6, 7]]
const LOCKS := [[1, 2], [3, 4], [5, 6]]
const SIDE_ROOMS := [[1, 2], [3, 4], [4, 6]]
const LOOPS := [[0, 1], [1, 2], [1, 3]]
const MUMMIES := [1, 2, 4]
## The most rooms (with lofts and crypts), things and switches: what `TombSolver` can count.
const MOST_ROOMS := 16
const MOST_THINGS := 7
const MOST_SWITCHES := 12
## A plan that takes more positions than this to prove is thrown away as too
## tangled: it is proved on a phone, as the tomb is opened.
const MOST_POSITIONS := 30000

## The rules that put in a lock, and how likely each is at each difficulty.
## (`_afar`: what opens the door is in a side chamber.)
const RULES := ["work", "work_afar", "lever", "lever_afar", "brazier", "brazier_afar", "offering", "cross", "pair", "gap", "sand", "bypass"]
const RULE_WEIGHTS := [
	[3, 2, 2, 3, 3, 0, 0, 0, 0, 0, 2, 0],
	[2, 2, 2, 3, 3, 1, 2, 2, 1, 3, 2, 2],
	[1, 2, 2, 3, 3, 2, 2, 2, 2, 3, 2, 3],
]

var plan: TombPlan
var _rng: TombRandom
## Which room stands on each square of the plan, and by room: its square, the
## way it lies (an index into `TombLayout3D.TURNS`), the room it is off, the
## link it is entered by, and whether it is on the way to the burial chamber.
var _square := {}
var _where := {}
var _heading := {}
var _up := {}
var _way_in := {}
var _trunk := {}
## By link: the rooms that must be got to before it can be passed (where its
## switches are, and where what they want lies).
var _needs := {}
## By thing: the rooms it has to be carried to.
var _uses := {}
## By link: how many flights its stairs have, where that is not one.
var _flights := {}
## Rooms that have something to push or to light in them already, a seal
## stone just inside, a block for the next room; and rooms nothing more is to
## be made off (a dark one: he is not to be sent through it without a torch).
var _busy := {}
var _sealed := {}
var _blocked := {}
var _shut := {}


## A tomb that can be finished. `plan.sub_seed` says how many were thrown away
## first, and `plan.proof["rejected"]` why.
static func generate(seed_value: int, difficulty: int) -> TombPlan:
	difficulty = clampi(difficulty, 0, 2)
	var rejected: Array[String] = []
	for sub in MAX_TRIES:
		var made := attempt(seed_value, difficulty, sub)
		var wrong := TombLayout3D.cells_wrong(made)
		if not wrong.is_empty():
			rejected.append("its cells break the rules (%s)" % wrong[0])
			continue
		var result := TombSolver.solve(made, false, MOST_POSITIONS)
		if result["ok"]:
			made.solution = result["steps"]
			result["rejected"] = rejected
			made.proof = result
			return made
		rejected.append(result["reason"])
	var plain_plan := plain(seed_value, difficulty)
	var proof := TombSolver.solve(plain_plan)
	plain_plan.solution = proof["steps"]
	proof["rejected"] = rejected
	plain_plan.proof = proof
	return plain_plan


## One try at a plan, not yet checked.
static func attempt(seed_value: int, difficulty: int, sub: int) -> TombPlan:
	var maker := TombBranching.new()
	return maker._make(seed_value, difficulty, sub, false)


## A branching tomb with nothing in it but stairs: what is fallen back on if every try fails.
static func plain(seed_value: int, difficulty: int) -> TombPlan:
	var maker := TombBranching.new()
	return maker._make(seed_value, difficulty, MAX_TRIES, true)


func _make(seed_value: int, difficulty: int, sub: int, bare: bool) -> TombPlan:
	_rng = TombRandom.new(TombRandom.mix([0xB2A, VERSION, seed_value, difficulty, -1 if bare else sub]))
	plan = TombPlan.new()
	plan.seed_value = seed_value
	plan.difficulty = difficulty
	plan.sub_seed = sub
	_lay_trunk()
	if not bare:
		_locks()
	_dead_ends()
	if bare:
		for link in plan.links:
			link.pass_kind = TombPlan.Pass.STAIRS
	else:
		_ways()
	_levels()
	if not bare:
		_closers()
		_people()
	return plan


# --- The floor plan

# The way from the entrance to the burial chamber. (It turns left, right or
# goes on, never back: so few rooms cannot shut themselves in.)
func _lay_trunk() -> void:
	var count := _rng.between(TRUNK[plan.difficulty][0], TRUNK[plan.difficulty][1])
	var roles: Array = []
	var wells := 0
	var halls := 0
	var galleries := 0
	for k in count - 3:
		var pick := _rng.weighted([3, 2 if wells == 0 and k > 0 else 0, 3 if halls < 2 else 0, 2 if plan.difficulty >= 1 and galleries == 0 else 0])
		match pick:
			1:
				wells += 1
				roles.append(TombPlan.Role.WELL)
			2:
				halls += 1
				roles.append(TombPlan.Role.HALL)
			3:
				galleries += 1
				roles.append(TombPlan.Role.GALLERY)
			_:
				roles.append(TombPlan.Role.CORRIDOR)
	roles.append(TombPlan.Role.ANTECHAMBER)
	roles.append(TombPlan.Role.BURIAL)
	var first := plan.add_room(TombPlan.Role.ENTRANCE)
	first.spine = 0
	_square[Vector2i.ZERO] = 0
	_where[0] = Vector2i.ZERO
	_heading[0] = 0
	_up[0] = -1
	_way_in[0] = -1
	_trunk[0] = true
	var at := 0
	var straight := 0
	for place in roles.size():
		# (the way in from the court is straight ahead: it is the front of the tomb)
		var weights: Array = [3 if straight == 0 else 1, 2 if place > 0 else 0, 0, 2 if place > 0 else 0]
		var made := -1
		var turned := 0
		while made == -1:
			turned = _rng.weighted(weights)
			if turned == -1:
				break
			weights[turned] = 0
			made = _grow(at, (int(_heading[at]) + turned) % 4, roles[place])
		if made == -1:
			break
		_trunk[made] = true
		straight = straight + 1 if turned == 0 else 0
		at = made
	# (whatever the last room is, it is where the treasure is)
	plan.rooms[at].role = TombPlan.Role.BURIAL
	plan.add_trigger(TombPlan.Switch.TREASURE, at)


# A new room off `from`, on the square next to it the way `facing` points
# (an index into `TombLayout3D.TURNS`). Returns its id, or -1 if the square is
# taken or the tomb has as many rooms as can be checked.
func _grow(from: int, facing: int, role: TombPlan.Role) -> int:
	var step := TombLayout3D.TURNS[facing]
	var square: Vector2i = (_where[from] as Vector2i) + Vector2i(step.x, step.z)
	# (one is kept back for a loft or a crypt)
	if _square.has(square) or plan.rooms.size() >= MOST_ROOMS - 1:
		return -1
	var room := plan.add_room(role)
	# (every room that stands on a square is numbered as the rooms down an axis
	# are: the entrance is the first of them)
	room.spine = room.id
	var link := plan.add_link(from, room.id, TombPlan.Pass.OPEN)
	_square[square] = room.id
	_where[room.id] = square
	_heading[room.id] = facing
	_up[room.id] = from
	_way_in[room.id] = link.id
	return room.id


# The ways a new room could still be made off this one: ahead, left or right
# of the way it lies, onto a free square. (The court at the way in has the one
# way, and nothing is beyond the burial chamber.)
func _free_turns(room: int) -> Array:
	var found: Array = []
	var role := plan.rooms[room].role
	if role == TombPlan.Role.ENTRANCE or role == TombPlan.Role.BURIAL or _shut.has(room) or TombLayout3D.is_side(plan.rooms[room]):
		return found
	for turned: int in [0, 1, 3]:
		var facing := (int(_heading[room]) + turned) % 4
		var step := TombLayout3D.TURNS[facing]
		if not _square.has((_where[room] as Vector2i) + Vector2i(step.x, step.z)):
			found.append(facing)
	return found


# A side chamber off `from`, or -1. Of the squares it could stand on, one that
# has another room beside it is likelier: that is where a loop can be closed.
func _side_chamber(from: int) -> int:
	var turns := _free_turns(from)
	if turns.is_empty():
		return -1
	var weights: Array = []
	for facing: int in turns:
		var step := TombLayout3D.TURNS[facing]
		var square: Vector2i = (_where[from] as Vector2i) + Vector2i(step.x, step.z)
		var beside := 0
		for other in TombLayout3D.TURNS:
			var next := square + Vector2i(other.x, other.z)
			if _square.has(next) and int(_square[next]) != from:
				beside += 1
		weights.append(1 + 2 * beside)
	var facing: int = turns[_rng.weighted(weights)]
	var role: int = [TombPlan.Role.CORRIDOR, TombPlan.Role.ANTECHAMBER, TombPlan.Role.GALLERY, TombPlan.Role.HALL][_rng.weighted([4, 3, 1 if plan.difficulty >= 1 else 0, 1 if plan.difficulty >= 2 else 0])]
	return _grow(from, facing, role)


# Whether `room` is `top` or is beyond it (a loft or a crypt is with the room it is off).
func _inside(room: int, top: int) -> bool:
	var at := room
	while at != -1:
		if at == top:
			return true
		at = _up[at]
	return false


func _is_leaf(room: int) -> bool:
	for other: int in _up:
		if int(_up[other]) == room:
			return false
	return true


# The room a door is in, and the rooms before it towards the entrance, up to `back` of them.
func _anchors(link: TombPlan.Link, back: int) -> Array:
	var found: Array = []
	var at := link.a
	for n in back + 1:
		if at == -1:
			break
		found.append(at)
		at = _up[at]
	return found


# A side chamber for what opens the door on `link`: a new one off one of
# `anchors` more often than not, or one that is there already and has nothing
# of the kind in it (`taken`). -1 if there is none to be had.
func _chamber(link: TombPlan.Link, anchors: Array, taken: Dictionary) -> int:
	var from: Array = anchors.duplicate()
	_rng.shuffle(from)
	var old: Array = []
	for room: int in _up:
		if _trunk.has(room) or TombLayout3D.is_side(plan.rooms[room]) or taken.has(room) or _shut.has(room) or _inside(room, link.b):
			continue
		if int(_up[room]) in anchors or (_up[int(_up[room])] != -1 and int(_up[int(_up[room])]) in anchors and not _trunk.has(int(_up[room]))):
			old.append(room)
	if old.is_empty() or _rng.chance(75):
		# (now and then off a side chamber: a branch off a branch)
		if not old.is_empty() and _rng.chance(25):
			var deeper := _side_chamber(old[_rng.below(old.size())])
			if deeper != -1:
				return deeper
		for room: int in from:
			var made := _side_chamber(room)
			if made != -1:
				return made
	if old.is_empty():
		return -1
	return old[_rng.below(old.size())]


# A room for a thing that has to be carried to `use` for the lock on `link`:
# a side chamber off the room the door is in or one of the `back` before it,
# or one of those rooms; from which it can be carried there. -1 if there is none.
# (`through`: whether it may lie beyond the room the door is in.)
func _host_for_item(link: TombPlan.Link, back: int, use: int, hook: bool, through := true) -> int:
	var anchors: Array = []
	for room: int in _anchors(link, back):
		if _carried_from(room, hook).has(use) and (through or room != link.a):
			anchors.append(room)
	if anchors.is_empty():
		return -1
	var found := _chamber(link, anchors, {})
	if found != -1 and _carried_from(found, hook).has(use):
		return found
	# (not in the room itself if there is another)
	var others: Array = anchors.filter(func(room: int) -> bool: return room != link.a)
	if others.is_empty():
		return anchors[0] if through else -1
	return others[_rng.below(others.size())]


# --- What keeps a plan from tying itself in a knot

# Every room that a thing in the hand can be brought to from `room`, doors
# taken as open. (`hook`: the thing is the grappling hook, which crosses its pit.)
func _carried_from(room: int, hook: bool) -> Dictionary:
	var reached := {room: true}
	var queue: Array[int] = [room]
	while not queue.is_empty():
		var at: int = queue.pop_back()
		for link in plan.links:
			if link.a != at and link.b != at:
				continue
			var to := link.b if link.a == at else link.a
			if reached.has(to) or not TombPlan.goes(link, at) or not TombPlan.carries(link, at, hook):
				continue
			reached[to] = true
			queue.append(to)
	return reached


# Whether everything that is carried can still be brought to where it is
# wanted from every room it could be carried to and left in. (So nothing can
# be taken down a rope, or down a drop, that is wanted at the top.)
func _carry_sound() -> bool:
	for thing in plan.things:
		if thing.kind == TombPlan.Item.BLOCK:
			continue
		var hook := thing.kind == TombPlan.Item.HOOK
		var wanted: Array = _uses.get(thing.id, [])
		for room: int in _carried_from(thing.room, hook):
			var onward := _carried_from(room, hook)
			for use: int in wanted:
				if not onward.has(use):
					return false
	return true


# Whether every room could be got to, taking a way to be open once every room
# its lock needs has been got to. (`with`: what one more lock would need, by
# link.) Less than the solver asks, and much quicker: it keeps a lock's key
# from being put behind that lock, or behind another whose key is behind it.
func _reaches_all(with := {}) -> bool:
	var reached := {plan.entrance(): true}
	var changed := true
	while changed:
		changed = false
		for link in plan.links:
			for from: int in [link.a, link.b]:
				var to := link.b if from == link.a else link.a
				if not reached.has(from) or reached.has(to) or not TombPlan.goes(link, from):
					continue
				var open := true
				for key: int in with.get(link.id, _needs.get(link.id, [])):
					open = open and reached.has(key)
				if open:
					reached[to] = true
					changed = true
	return reached.size() == plan.rooms.size()


func _has_room_for(things: int, switches: int) -> bool:
	return plan.things.size() + things <= MOST_THINGS and plan.triggers.size() + switches <= MOST_SWITCHES


# --- Locks

func _locks() -> void:
	var wanted := _rng.between(LOCKS[plan.difficulty][0], LOCKS[plan.difficulty][1])
	var made := 0
	# The doors down the way to the burial chamber first (not the first: that is the way in)...
	var doors: Array = []
	for link in plan.links:
		if link.a != plan.entrance():
			doors.append(link.id)
	_rng.shuffle(doors)
	# (one in a middling or a hard tomb is kept for a side chamber)
	var kept := 1 if plan.difficulty >= 1 else 0
	for id: int in doors:
		if made >= wanted - kept:
			break
		if _lock_one(plan.links[id]):
			made += 1
	# ... and then the doors of the side chambers that came of those and have something in them.
	var sides: Array = []
	for link in plan.links:
		var room := plan.rooms[link.b]
		if not _trunk.has(link.b) and not TombLayout3D.is_side(room) and int(_way_in.get(link.b, -1)) == link.id and _holds_something(link.b):
			sides.append(link.id)
	_rng.shuffle(sides)
	for id: int in sides:
		if made >= wanted:
			break
		if _lock_one(plan.links[id]):
			made += 1


func _holds_something(room: int) -> bool:
	for thing in plan.things:
		if thing.room == room:
			return true
	for trigger in plan.triggers:
		if trigger.room == room:
			return true
	return false


func _lock_one(link: TombPlan.Link) -> bool:
	var weights: Array = (RULE_WEIGHTS[plan.difficulty] as Array).duplicate()
	while true:
		var pick := _rng.weighted(weights)
		if pick == -1:
			return false
		weights[pick] = 0
		if _apply(RULES[pick], link):
			return true
	return false


# Puts a lock on a way, and its key somewhere that can be got to without it.
# Says whether it could.
func _apply(rule: String, link: TombPlan.Link) -> bool:
	if link.fixed or not link.switches.is_empty():
		return false
	var here := link.a
	var beyond := link.b
	match rule:
		"work":
			# A block and a plate in the room itself.
			if _busy.has(here) or not _has_room_for(0, 1):
				return false
			link.switches = [plan.add_trigger(TombPlan.Switch.WORK_PLATE, here).id]
			link.hint = "weight"
			_needs[link.id] = [here]
			_busy[here] = true
			return true
		"work_afar":
			# A block and a plate in a side chamber.
			if not _has_room_for(0, 1):
				return false
			var host := _chamber(link, _anchors(link, 2).filter(func(room: int) -> bool: return room != plan.entrance()), _busy)
			if host == -1 or not _reaches_all({link.id: [host]}):
				return false
			link.switches = [plan.add_trigger(TombPlan.Switch.WORK_PLATE, host).id]
			link.hint = "weight_afar"
			_needs[link.id] = [host]
			_busy[host] = true
			return true
		"lever":
			# A seal stone in a loft over this room or one of the two before it, or at the foot of a well.
			var side := _side_room(link, 2)
			if side == -1 or not _has_room_for(0, 1):
				return false
			link.switches = [plan.add_trigger(TombPlan.Switch.LEVER, side).id]
			link.hint = "lever_below" if plan.rooms[side].role == TombPlan.Role.CRYPT else "lever_above"
			_needs[link.id] = [side]
			return true
		"lever_afar":
			# A seal stone just inside a side chamber.
			if not _has_room_for(0, 1):
				return false
			var host := _chamber(link, _anchors(link, 2).filter(func(room: int) -> bool: return room != plan.entrance()), _sealed)
			if host == -1 or not _reaches_all({link.id: [host]}):
				return false
			link.switches = [plan.add_trigger(TombPlan.Switch.LEVER, host).id]
			link.hint = "seal_afar"
			_needs[link.id] = [host]
			_sealed[host] = true
			return true
		"brazier":
			# The room is dark, and its brazier wants lighting: a torch is to be
			# brought, from somewhere he need not go through the dark to get to.
			if _busy.has(here) or not _has_room_for(1, 1) or not _only_way_on(here, link):
				return false
			var from := _host_for_item(link, 3, here, false, false)
			if from == -1 or not _reaches_all({link.id: [here, from]}):
				return false
			var torch := plan.add_thing(TombPlan.Item.TORCH, from)
			_uses[torch.id] = [here]
			plan.rooms[here].dark = true
			link.switches = [plan.add_trigger(TombPlan.Switch.BRAZIER, here).id]
			link.hint = "fire"
			_needs[link.id] = [here, from]
			_busy[here] = true
			_shut[here] = true
			return true
		"brazier_afar":
			# The brazier is in a side chamber, which is dark: the torch is somewhere else again.
			if not _has_room_for(1, 1):
				return false
			var taken := _busy.duplicate()
			taken.merge(_sealed)
			for thing in plan.things:
				taken[thing.room] = true
			var host := _chamber(link, _anchors(link, 2).filter(func(room: int) -> bool: return room != plan.entrance()), taken)
			if host == -1 or not _is_leaf(host):
				return false
			var into := plan.links[int(_way_in[host])]
			var from := _host_for_item(into, 3, host, false)
			if from == -1 or from == host or _inside(from, beyond) or not _reaches_all({link.id: [host, from]}):
				return false
			var torch := plan.add_thing(TombPlan.Item.TORCH, from)
			_uses[torch.id] = [host]
			plan.rooms[host].dark = true
			link.switches = [plan.add_trigger(TombPlan.Switch.BRAZIER, host).id]
			link.hint = "fire_afar"
			_needs[link.id] = [host, from]
			_busy[host] = true
			_shut[host] = true
			return true
		"offering":
			# Two weights at once: its own block on a plate, and a jar on the offering table.
			if _busy.has(here) or not _has_room_for(1, 2):
				return false
			var from := _host_for_item(link, 2, here, false)
			if from == -1 or not _reaches_all({link.id: [here, from]}):
				return false
			var jar := plan.add_thing(TombPlan.Item.JAR, from)
			_uses[jar.id] = [here]
			link.switches = [plan.add_trigger(TombPlan.Switch.WORK_PLATE, here).id, plan.add_trigger(TombPlan.Switch.OFFERING, here).id]
			link.hint = "two_weights"
			_needs[link.id] = [here, from]
			_busy[here] = true
			return true
		"cross", "pair":
			# The plate is here and its block in the room before, which this room
			# is laid along the way from: that way is kept level. (`pair`: and a
			# second plate, for a block of the room's own.)
			var before: int = _up[here]
			if before == -1 or before == plan.entrance() or _busy.has(here) or _blocked.has(before) or not _has_room_for(1, 2 if rule == "pair" else 1):
				return false
			var way := plan.links[int(_way_in[here])]
			if way.pass_kind != TombPlan.Pass.OPEN or way.fixed:
				return false
			way.fixed = true
			plan.add_thing(TombPlan.Item.BLOCK, before).dest = here
			link.switches = [plan.add_trigger(TombPlan.Switch.PLATE, here).id]
			link.hint = "weight_from_afar"
			if rule == "pair":
				link.switches.append(plan.add_trigger(TombPlan.Switch.WORK_PLATE, here).id)
				link.hint = "two_stones"
			_needs[link.id] = [here, before]
			_busy[here] = true
			_blocked[before] = true
			return true
		"gap":
			# No door: a pit too wide to jump, and a grappling hook somewhere before it.
			if not _has_room_for(1, 0) or _count(TombPlan.Pass.GAP) >= 2:
				return false
			var from := _host_for_item(link, 3, here, true)
			if from == -1 or not _reaches_all({link.id: [from]}):
				return false
			link.pass_kind = TombPlan.Pass.GAP
			if not _carry_sound():
				link.pass_kind = TombPlan.Pass.OPEN
				return false
			var hook := plan.add_thing(TombPlan.Item.HOOK, from)
			_uses[hook.id] = [here]
			link.fixed = true
			link.hint = "hook"
			_needs[link.id] = [from]
			return true
		"sand":
			# No door: the way on is up, over a face too high to catch, and a seal
			# stone lets the sand in that he walks up. The stone is at the foot of
			# the face, or (not in an easy tomb) as often somewhere else: in a side
			# chamber, a loft or under a well. (No loft over the room itself: he
			# would get up by that instead. And one to a tomb: it is a long way up.)
			if plan.side_room(here, TombPlan.Role.LOFT) != null or _count(TombPlan.Pass.SAND) > 0 or not _has_room_for(0, 1):
				return false
			link.pass_kind = TombPlan.Pass.SAND
			link.fixed = true
			var host := here
			link.hint = "sand"
			if plan.difficulty >= 1 and _rng.chance(50):
				if _rng.chance(50):
					var side := _side_room(link, 2)
					if side != -1:
						host = side
						link.hint = "sand_below" if plan.rooms[side].role == TombPlan.Role.CRYPT else "sand_above"
				else:
					var chamber := _chamber(link, _anchors(link, 2).filter(func(room: int) -> bool: return room != plan.entrance()), _sealed)
					if chamber != -1 and _reaches_all({link.id: [chamber]}):
						host = chamber
						link.hint = "sand_afar"
						_sealed[chamber] = true
			link.switches = [plan.add_trigger(TombPlan.Switch.LEVER, host).id]
			_needs[link.id] = [host]
			return true
		"bypass":
			# A loop. The door is opened from behind, by a seal stone at the foot
			# of the stairs beyond it; the way to there is up into a cutting over
			# the wall, and down a drop there is no climbing back up.
			if plan.side_room(here, TombPlan.Role.LOFT) != null or _sand_out_of(here) or _sealed.has(beyond) or plan.rooms.size() >= MOST_ROOMS or not _has_room_for(0, 1):
				return false
			var loft := plan.add_room(TombPlan.Role.LOFT, here)
			_up[loft.id] = here
			plan.add_link(here, loft.id, TombPlan.Pass.CLIMB)
			plan.add_link(loft.id, beyond, TombPlan.Pass.DROP)
			link.pass_kind = TombPlan.Pass.STAIRS
			link.fixed = true
			_flights[link.id] = TombLayout3D.DROP_LEVELS
			if not _carry_sound():
				# (something that is wanted up here could be taken down the drop: then no loft)
				plan.links.resize(plan.links.size() - 2)
				plan.rooms.resize(plan.rooms.size() - 1)
				_up.erase(loft.id)
				link.pass_kind = TombPlan.Pass.OPEN
				link.fixed = false
				_flights.erase(link.id)
				return false
			link.switches = [plan.add_trigger(TombPlan.Switch.LEVER, beyond).id]
			link.hint = "over_the_wall"
			_needs[link.id] = [beyond]
			_sealed[beyond] = true
			return true
	return false


# Whether the way on `link` is the only one out of `room` besides its way in.
func _only_way_on(room: int, link: TombPlan.Link) -> bool:
	for other in plan.links:
		if other.a == room and other.id != link.id:
			return false
	return true


func _count(kind: TombPlan.Pass) -> int:
	var found := 0
	for link in plan.links:
		if link.pass_kind == kind:
			found += 1
	return found


func _sand_out_of(room: int) -> bool:
	for link in plan.links:
		if link.a == room and link.pass_kind == TombPlan.Pass.SAND:
			return true
	return false


# A new loft over the room a door is in or one of the `back` before it, or a
# new chamber at the foot of one of them that is a well: its id, or -1.
func _side_room(link: TombPlan.Link, back: int) -> int:
	if plan.rooms.size() >= MOST_ROOMS:
		return -1
	var hosts: Array = []
	for room: int in _anchors(link, back):
		if _side_role(room) != -1:
			hosts.append(room)
	if hosts.is_empty():
		return -1
	var host: int = hosts[_rng.below(hosts.size())]
	var role := _side_role(host)
	var side := plan.add_room(role, host)
	_up[side.id] = host
	plan.add_link(host, side.id, TombPlan.Pass.SHAFT if role == TombPlan.Role.CRYPT else TombPlan.Pass.CLIMB)
	return side.id


# What kind of room can still be made off this one: the chamber at the foot
# of a well, a loft over anything else that is roofed; or -1.
func _side_role(room: int) -> int:
	var role := plan.rooms[room].role
	if role == TombPlan.Role.WELL:
		return -1 if plan.side_room(room, TombPlan.Role.CRYPT) != null else TombPlan.Role.CRYPT
	if role == TombPlan.Role.ENTRANCE or role == TombPlan.Role.BURIAL or TombLayout3D.is_side(plan.rooms[room]):
		return -1
	# (from a loft at the foot of the sand's face he would get over it with no sand)
	if _sand_out_of(room):
		return -1
	return -1 if plan.side_room(room, TombPlan.Role.LOFT) != null else TombPlan.Role.LOFT


# --- Dead ends

# Rooms off the others with nothing in them, until there are as many rooms off
# the way to the burial chamber as the difficulty asks.
func _dead_ends() -> void:
	var wanted := _rng.between(SIDE_ROOMS[plan.difficulty][0], SIDE_ROOMS[plan.difficulty][1])
	for attempt in 12:
		var off := 0
		var from: Array = []
		var weights: Array = []
		for room: int in _where:
			if not _trunk.has(room):
				off += 1
			var turns := _free_turns(room)
			if turns.is_empty():
				continue
			# (likelier off the way to the burial chamber than off a side chamber, and
			# likelier still where the new room would have another beside it: a loop can be closed there)
			var beside := 0
			for facing: int in turns:
				var step := TombLayout3D.TURNS[facing]
				var square: Vector2i = (_where[room] as Vector2i) + Vector2i(step.x, step.z)
				for other in TombLayout3D.TURNS:
					var next := square + Vector2i(other.x, other.z)
					if _square.has(next) and int(_square[next]) != room:
						beside += 1
			from.append(room)
			weights.append((3 if _trunk.has(room) else 1) * (1 + 3 * beside))
		if off >= wanted or from.is_empty():
			return
		_side_chamber(from[_rng.weighted(weights)])


# --- The ways, and the levels

# What each way between two rooms is, where a rule has not already said.
func _ways() -> void:
	var deep := plan.difficulty >= 1
	var floods := 0
	var shafts := 0
	var ropes := 0
	for link in plan.links:
		if link.fixed or TombLayout3D.is_side(plan.rooms[link.a]) or TombLayout3D.is_side(plan.rooms[link.b]):
			continue
		if link.a == plan.entrance():
			# (the entrance stair)
			link.pass_kind = TombPlan.Pass.STAIRS
			continue
		var door := not link.switches.is_empty()
		var weights: Array = [
			2,
			4,
			0 if door else 2,
			2 if deep and floods < plan.difficulty else 0,
			2 if deep and shafts == 0 and not door else 0,
			3 if deep and ropes == 0 and not door else 0,
		]
		var kinds: Array = [TombPlan.Pass.OPEN, TombPlan.Pass.STAIRS, TombPlan.Pass.CRAWL, TombPlan.Pass.FLOOD, TombPlan.Pass.SHAFT, TombPlan.Pass.ROPE]
		while true:
			var pick := _rng.weighted(weights)
			if pick == -1:
				link.pass_kind = TombPlan.Pass.OPEN
				break
			weights[pick] = 0
			link.pass_kind = kinds[pick]
			if _carry_sound():
				break
		if link.pass_kind == TombPlan.Pass.FLOOD:
			floods += 1
		elif link.pass_kind == TombPlan.Pass.SHAFT:
			shafts += 1
		elif link.pass_kind == TombPlan.Pass.ROPE:
			ropes += 1
			link.hint = "rope"


# The level of each room, from the ways down to it; and so its cell.
func _levels() -> void:
	var level := {plan.entrance(): 0}
	var changed := true
	while changed:
		changed = false
		for room: int in _way_in:
			if level.has(room) or not level.has(int(_up[room])):
				continue
			var link := plan.links[int(_way_in[room])]
			var down := TombLayout3D.levels_down(link.pass_kind)
			if link.pass_kind == TombPlan.Pass.STAIRS:
				down = int(_flights.get(link.id, 1))
			level[room] = int(level[int(_up[room])]) + down
			changed = true
	for room: int in _where:
		var square: Vector2i = _where[room]
		plan.rooms[room].cell = Vector3i(square.x, int(level.get(room, 0)), square.y)


# --- Loops

# Whether the way is one that something has to be done, or had, to get along.
func _is_lock(link: TombPlan.Link) -> bool:
	return not link.switches.is_empty() or link.pass_kind == TombPlan.Pass.GAP or link.pass_kind == TombPlan.Pass.SAND


# The ways from `room` back towards the entrance as far as `top` (which is before it).
func _ways_up(room: int, top: int) -> Array:
	var found: Array = []
	var at := room
	while at != top and at != -1:
		found.append(plan.links[int(_way_in[at])])
		at = _up[at]
	return found


# Second ways between rooms that stand side by side and are not joined.
func _closers() -> void:
	var pairs: Array = []
	for room: int in _where:
		if not _may_close(room):
			continue
		for step in TombLayout3D.TURNS:
			var next: Vector2i = (_where[room] as Vector2i) + Vector2i(step.x, step.z)
			if not _square.has(next):
				continue
			var other: int = _square[next]
			if other <= room or not _may_close(other) or int(_up[room]) == other or int(_up[other]) == room:
				continue
			pairs.append([room, other])
	_rng.shuffle(pairs)
	var wanted := _rng.between(LOOPS[plan.difficulty][0], LOOPS[plan.difficulty][1])
	var made := 0
	for pair: Array in pairs:
		if made >= wanted:
			break
		if _close(pair[0], pair[1]):
			made += 1


# (not the court, not the burial chamber, and not a room with a loft: a way
# that closes a loop comes into the bay, which a loft is over)
func _may_close(room: int) -> bool:
	var role := plan.rooms[room].role
	return role != TombPlan.Role.ENTRANCE and role != TombPlan.Role.BURIAL and not TombLayout3D.is_side(plan.rooms[room]) \
			and plan.side_room(room, TombPlan.Role.LOFT) == null and not plan.rooms[room].dark


func _close(one: int, other: int) -> bool:
	# The ways round from each of the two to the room they both come from
	# (which is one of them, where the other is further down the same way).
	var near := one
	var far := other
	var near_ways: Array = []
	var far_ways: Array = []
	if _inside(other, one):
		far_ways = _ways_up(other, one)
	elif _inside(one, other):
		near = other
		far = one
		far_ways = _ways_up(one, other)
	else:
		var top := one
		while not _inside(other, top):
			top = _up[top]
		near_ways = _ways_up(one, top)
		far_ways = _ways_up(other, top)
	var near_locked := false
	for link: TombPlan.Link in near_ways:
		near_locked = near_locked or _is_lock(link)
	var far_locked := false
	for link: TombPlan.Link in far_ways:
		far_locked = far_locked or _is_lock(link)
	# (locks on both ways round: whichever side a door between them opened
	# from, it would let him past a lock he has not opened)
	if near_locked and far_locked:
		return false
	if near_locked:
		var kept := near
		near = far
		far = kept
		far_locked = true
	var down := plan.rooms[far].cell.y - plan.rooms[near].cell.y
	if absi(down) > 3:
		return false
	# It is written from the higher room to the lower, and between two on a
	# level, from the one nearer the entrance.
	var from := near
	var to := far
	if down < 0 or (down == 0 and _depth(far) < _depth(near)):
		from = far
		to = near
	if far_locked or _rng.chance(40):
		# A door that opens only from the far side, by a seal stone just inside
		# the room there: a short cut back, once he has been the long way round.
		if _sealed.has(far) or not _has_room_for(0, 1):
			return false
		var door := plan.add_link(from, to, TombPlan.Pass.OPEN if down == 0 else TombPlan.Pass.STAIRS)
		door.switches = [plan.add_trigger(TombPlan.Switch.LEVER, far).id]
		door.hint = "from_within"
		door.fixed = true
		_needs[door.id] = [far]
		if not _carry_sound():
			plan.links.resize(plan.links.size() - 1)
			plan.triggers.resize(plan.triggers.size() - 1)
			_needs.erase(door.id)
			return false
		_sealed[far] = true
		return true
	# A plain second way.
	var kind := TombPlan.Pass.STAIRS
	if down == 0:
		kind = [TombPlan.Pass.OPEN, TombPlan.Pass.CRAWL, TombPlan.Pass.FLOOD][_rng.weighted([2, 3, 2 if plan.difficulty >= 1 else 0])]
	var way := plan.add_link(from, to, kind)
	way.fixed = true
	if not _carry_sound():
		plan.links.resize(plan.links.size() - 1)
		return false
	# And now that there is a dry way round, one of the level doorways on the
	# old way may be under water: quicker, and nothing can be carried by it.
	if kind != TombPlan.Pass.FLOOD and plan.difficulty >= 1 and _rng.chance(60):
		var dry: Array = []
		for link: TombPlan.Link in near_ways + far_ways:
			if link.pass_kind == TombPlan.Pass.OPEN and not link.fixed and link.switches.is_empty():
				dry.append(link)
		if not dry.is_empty():
			var wet: TombPlan.Link = dry[_rng.below(dry.size())]
			wet.pass_kind = TombPlan.Pass.FLOOD
			if not _carry_sound():
				wet.pass_kind = TombPlan.Pass.OPEN
	return true


func _depth(room: int) -> int:
	var found := 0
	var at := room
	while int(_up[at]) != -1:
		found += 1
		at = _up[at]
	return found


# --- Mummies and pits

func _people() -> void:
	var left: int = MUMMIES[plan.difficulty]
	if plan.difficulty >= 1:
		# The guardian of the burial chamber: it wakes when the treasure is taken.
		var burial := plan.rooms[plan.goal_trigger().room]
		burial.mummy = TombGenerator.ROYAL if plan.difficulty == 2 else [TombGenerator.SHAMBLER, TombGenerator.PRIEST][_rng.below(2)]
		burial.barrier = TombGenerator.BARRIER_FOR[burial.mummy]
		burial.guardian = true
		left -= 1
	# The dead ends first (not in an easy tomb), then anywhere.
	var empty: Array = []
	var others: Array = []
	for room: int in _where:
		var role := plan.rooms[room].role
		if role == TombPlan.Role.ENTRANCE or role == TombPlan.Role.BURIAL:
			continue
		# (not where the way back out of the room is slow: he has to be able to outrun it)
		if plan.links[int(_way_in[room])].pass_kind not in [TombPlan.Pass.OPEN, TombPlan.Pass.STAIRS]:
			continue
		if not _trunk.has(room) and _is_leaf(room) and not _holds_something(room) and plan.links_of(room).size() == 1:
			empty.append(room)
		else:
			others.append(room)
	_rng.shuffle(empty)
	_rng.shuffle(others)
	var places: Array = others
	if plan.difficulty >= 1:
		places = empty + others
	for room: int in places:
		if left <= 0:
			break
		var kind := _rng.weighted([3, 2, 2 if plan.difficulty >= 1 else 0, 2 if plan.difficulty >= 1 else 0, 2 if plan.difficulty >= 2 else 0])
		plan.rooms[room].mummy = kind
		plan.rooms[room].barrier = TombGenerator.BARRIER_FOR[kind]
		left -= 1
	for room: int in _where:
		var made := plan.rooms[room]
		if made.role in [TombPlan.Role.ENTRANCE, TombPlan.Role.BURIAL, TombPlan.Role.WELL] or made.mummy != -1:
			continue
		if _rng.chance([0, 20, 40][plan.difficulty]):
			made.pit = true
