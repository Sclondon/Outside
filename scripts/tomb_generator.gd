class_name TombGenerator
extends RefCounted
## Makes the plan of a tomb from a seed and a difficulty (0 easy, 1 middling,
## 2 hard), and never hands back one that cannot be finished.
##
## How (the order matters: each stage only adds what the one before allows):
##
##  1. The axis. A royal tomb's rooms in their order: the entrance, then
##     corridors, perhaps a well, one or two pillared halls, perhaps a high
##     gallery, then the antechamber and the burial chamber with the treasure.
##     Every way between them starts as a plain level doorway.
##  2. Locks, each put in with its key in one move, so that the key is always
##     somewhere he can get to before the lock (the rules below). Some keys go
##     in a new room off the axis (a loft over a room, the chamber at the foot
##     of the well); one rule makes a loop: the door is opened from behind, and
##     the way round to behind it is over the wall and down a drop.
##  3. The ways themselves: stairs, a crawl, a flooded stretch, a shaft with a
##     ladder or a rope; never one that a thing which has to be carried or
##     pushed along it could not pass.
##  4. Mummies, each of a kind with something in its room that kind cannot get
##     past (`BARRIER_FOR`), and pits.
##  5. `TombSolver` plays it through. If it cannot be finished, or could be
##     made unfinishable, the whole plan is thrown away and made again from the
##     next sub-seed, up to `MAX_TRIES`; after that, a plain tomb with no locks
##     (which cannot fail). So `generate` always returns a tomb that passes.
##
## Everything random comes from one `TombRandom`, seeded from the version of
## this generator, the seed, the difficulty and the sub-seed.

## Changed whenever a change here would make a different tomb from the same
## seed. It is part of the seed, and of every result that is kept.
const VERSION := 2
const MAX_TRIES := 40
## For each difficulty: the fewest and most rooms down the axis, the fewest and
## most locks, and how many mummies.
const SPINE := [[4, 5], [6, 7], [8, 9]]
const LOCKS := [[1, 2], [3, 4], [5, 6]]
const MUMMIES := [1, 2, 3]
const DIFFICULTY_NAMES := ["Easy", "Middling", "Hard"]

## The kinds of mummy (the numbers are `Mummy.Kind`, which this file does not
## otherwise need), and what holds each back: a trench for what will not step
## down or cannot get out, a kerb for what cannot lift its feet, a narrow gap
## for the one that is too wide.
const SHAMBLER := 0
const PRIEST := 1
const BRUTE := 2
const CRAWLER := 3
const CHILD := 4
const ROYAL := 5
const BARRIER_FOR := {
	SHAMBLER: TombPlan.Barrier.TRENCH, PRIEST: TombPlan.Barrier.KERB, BRUTE: TombPlan.Barrier.NARROW,
	CRAWLER: TombPlan.Barrier.KERB, CHILD: TombPlan.Barrier.TRENCH, ROYAL: TombPlan.Barrier.TRENCH,
}

## The rules that put in a lock, and how likely each is at each difficulty.
const RULES := ["work", "lever", "brazier", "cross", "gap", "bypass", "offering", "pair", "sand"]
const RULE_WEIGHTS := [
	[4, 3, 2, 0, 0, 0, 0, 0, 2],
	[3, 3, 3, 2, 2, 2, 1, 1, 2],
	[2, 3, 3, 3, 3, 3, 2, 2, 2],
]


## A tomb that can be finished. `plan.sub_seed` says how many were thrown away
## first, and `plan.proof["rejected"]` why.
static func generate(seed_value: int, difficulty: int) -> TombPlan:
	difficulty = clampi(difficulty, 0, 2)
	var rejected: Array[String] = []
	for sub in MAX_TRIES:
		var plan := attempt(seed_value, difficulty, sub)
		var result := TombSolver.solve(plan)
		if result["ok"]:
			plan.solution = result["steps"]
			result["rejected"] = rejected
			plan.proof = result
			return plan
		rejected.append(result["reason"])
	var plain_plan := plain(seed_value, difficulty)
	var proof := TombSolver.solve(plain_plan)
	plain_plan.solution = proof["steps"]
	proof["rejected"] = rejected
	plain_plan.proof = proof
	return plain_plan


## One try at a plan, not yet checked.
static func attempt(seed_value: int, difficulty: int, sub: int) -> TombPlan:
	var rng := TombRandom.new(TombRandom.mix([VERSION, seed_value, difficulty, sub]))
	var plan := _axis(seed_value, difficulty, sub, rng)
	var count := plan.rooms.size()

	# Locks, on doors picked at random from the second on (the first is the way in).
	var doors: Array = []
	for i in range(1, count - 1):
		doors.append(i)
	rng.shuffle(doors)
	var wanted := mini(rng.between(LOCKS[difficulty][0], LOCKS[difficulty][1]), doors.size())
	var made := 0
	for i: int in doors:
		if made >= wanted:
			break
		var weights: Array = (RULE_WEIGHTS[difficulty] as Array).duplicate()
		while true:
			var pick := rng.weighted(weights)
			if pick == -1:
				break
			weights[pick] = 0
			if _apply(RULES[pick], plan, i, rng):
				made += 1
				break

	_ways(plan, rng)
	_people(plan, rng)
	return plan


## A tomb with nothing in it but stairs: what is fallen back on if every try fails.
static func plain(seed_value: int, difficulty: int) -> TombPlan:
	var rng := TombRandom.new(TombRandom.mix([VERSION, seed_value, difficulty, -1]))
	var plan := _axis(seed_value, difficulty, MAX_TRIES, rng)
	for link in plan.links:
		link.pass_kind = TombPlan.Pass.STAIRS
	return plan


static func _axis(seed_value: int, difficulty: int, sub: int, rng: TombRandom) -> TombPlan:
	var plan := TombPlan.new()
	plan.seed_value = seed_value
	plan.difficulty = difficulty
	plan.sub_seed = sub
	var count := rng.between(SPINE[difficulty][0], SPINE[difficulty][1])
	var roles: Array = [TombPlan.Role.ENTRANCE]
	var wells := 0
	var halls := 0
	var galleries := 0
	for k in count - 3:
		var pick := rng.weighted([3, 2 if wells == 0 and k > 0 else 0, 3 if halls < 2 else 0, 2 if difficulty >= 1 and galleries == 0 else 0])
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
	for i in roles.size():
		var room := plan.add_room(roles[i])
		room.spine = i
		if i > 0:
			plan.add_link(i - 1, i, TombPlan.Pass.OPEN)
	plan.add_trigger(TombPlan.Switch.TREASURE, roles.size() - 1)
	return plan


# Puts a lock on the door out of the room at `i` on the axis, and its key
# somewhere before it. Says whether it could.
static func _apply(rule: String, plan: TombPlan, i: int, rng: TombRandom) -> bool:
	var link := plan.spine_link(i)
	if link.fixed or not link.switches.is_empty():
		return false
	match rule:
		"work":
			# A block and a plate in the room itself.
			link.switches = [plan.add_trigger(TombPlan.Switch.WORK_PLATE, i).id]
			link.hint = "weight"
			return true
		"lever":
			# A seal stone in a room off this one or one of the two before it.
			var hosts: Array = []
			for j in range(maxi(i - 2, 1), i + 1):
				if _side_role(plan, j) != -1:
					hosts.append(j)
			if hosts.is_empty():
				return false
			var host: int = hosts[rng.below(hosts.size())]
			var role := _side_role(plan, host)
			var side := plan.add_room(role, host)
			plan.add_link(host, side.id, TombPlan.Pass.SHAFT if role == TombPlan.Role.CRYPT else TombPlan.Pass.CLIMB)
			link.switches = [plan.add_trigger(TombPlan.Switch.LEVER, side.id).id]
			link.hint = "lever_below" if role == TombPlan.Role.CRYPT else "lever_above"
			return true
		"brazier":
			# The room is dark, and its brazier wants lighting: a torch is to be brought.
			var from := _carry_from(plan, i, rng, 3)
			plan.add_thing(TombPlan.Item.TORCH, from)
			plan.rooms[i].dark = true
			link.switches = [plan.add_trigger(TombPlan.Switch.BRAZIER, i).id]
			link.hint = "fire"
			return true
		"offering":
			# Two weights at once: its own block on a plate, and a jar on the offering table.
			var from := _carry_from(plan, i, rng, 2)
			plan.add_thing(TombPlan.Item.JAR, from)
			link.switches = [plan.add_trigger(TombPlan.Switch.WORK_PLATE, i).id, plan.add_trigger(TombPlan.Switch.OFFERING, i).id]
			link.hint = "two_weights"
			return true
		"cross":
			# The plate is here and its block in the room before: the way between is kept level.
			if i < 2:
				return false
			var before := plan.spine_link(i - 1)
			if before.pass_kind != TombPlan.Pass.OPEN or before.fixed:
				return false
			before.keep_push = true
			before.fixed = true
			plan.add_thing(TombPlan.Item.BLOCK, i - 1).dest = i
			link.switches = [plan.add_trigger(TombPlan.Switch.PLATE, i).id]
			link.hint = "weight_from_afar"
			return true
		"pair":
			# Two plates on one door: one for the room's own block, and one for a
			# block that is pushed in from the room before.
			if i < 2:
				return false
			var before := plan.spine_link(i - 1)
			if before.pass_kind != TombPlan.Pass.OPEN or before.fixed:
				return false
			before.keep_push = true
			before.fixed = true
			plan.add_thing(TombPlan.Item.BLOCK, i - 1).dest = i
			link.switches = [plan.add_trigger(TombPlan.Switch.PLATE, i).id, plan.add_trigger(TombPlan.Switch.WORK_PLATE, i).id]
			link.hint = "two_stones"
			return true
		"sand":
			# No door: the way on is up, over a face too high to catch, and a seal
			# stone lets the sand in that he walks up. The stone is at the foot of
			# the face, or (not in an easy tomb) as often in a room off this one or
			# one of the two before it. (No loft over the room itself: he would
			# get up by that instead.)
			if link.keep_push or plan.side_room(i, TombPlan.Role.LOFT) != null:
				return false
			# (one to a tomb: it is a long way up)
			for other in plan.links:
				if other.pass_kind == TombPlan.Pass.SAND:
					return false
			link.pass_kind = TombPlan.Pass.SAND
			link.fixed = true
			var hosts: Array = []
			if plan.difficulty >= 1 and rng.chance(50):
				for j in range(maxi(i - 2, 1), i + 1):
					if _side_role(plan, j) != -1:
						hosts.append(j)
			if hosts.is_empty():
				link.switches = [plan.add_trigger(TombPlan.Switch.LEVER, i).id]
				link.hint = "sand"
				return true
			var host: int = hosts[rng.below(hosts.size())]
			var role := _side_role(plan, host)
			var side := plan.add_room(role, host)
			plan.add_link(host, side.id, TombPlan.Pass.SHAFT if role == TombPlan.Role.CRYPT else TombPlan.Pass.CLIMB)
			link.switches = [plan.add_trigger(TombPlan.Switch.LEVER, side.id).id]
			link.hint = "sand_below" if role == TombPlan.Role.CRYPT else "sand_above"
			return true
		"gap":
			# No door: a pit too wide to jump, and a grappling hook somewhere before it.
			if link.keep_carry or link.keep_push:
				return false
			var from := _carry_from(plan, i, rng, 3)
			plan.add_thing(TombPlan.Item.HOOK, from)
			link.pass_kind = TombPlan.Pass.GAP
			link.fixed = true
			link.hint = "hook"
			return true
		"bypass":
			# A loop. The door is opened from behind, by a seal stone at the foot
			# of the stairs beyond it; the way to there is up into a cutting over
			# the wall, and down a drop there is no climbing back up.
			if link.keep_push or plan.side_room(i, TombPlan.Role.LOFT) != null or plan.rooms[i].role == TombPlan.Role.ENTRANCE:
				return false
			var loft := plan.add_room(TombPlan.Role.LOFT, i)
			plan.add_link(i, loft.id, TombPlan.Pass.CLIMB)
			plan.add_link(loft.id, i + 1, TombPlan.Pass.DROP)
			link.pass_kind = TombPlan.Pass.STAIRS
			link.fixed = true
			link.switches = [plan.add_trigger(TombPlan.Switch.LEVER, i + 1).id]
			link.hint = "over_the_wall"
			return true
	return false


# What kind of room can still be made off the room at `i`: the chamber at the
# foot of a well, a loft over anything else that is roofed; or -1.
static func _side_role(plan: TombPlan, i: int) -> int:
	var room := plan.rooms[i]
	if room.role == TombPlan.Role.WELL:
		return -1 if plan.side_room(i, TombPlan.Role.CRYPT) != null else TombPlan.Role.CRYPT
	if room.role == TombPlan.Role.ENTRANCE or room.role == TombPlan.Role.BURIAL:
		return -1
	# (from a loft at the foot of the sand's face he would get over it with no sand)
	if plan.spine_link(i).pass_kind == TombPlan.Pass.SAND:
		return -1
	return -1 if plan.side_room(i, TombPlan.Role.LOFT) != null else TombPlan.Role.LOFT


# A room on the axis up to `back` before the room at `i` (or that room itself
# if there is no other) from which a thing can be carried to it, and marks the
# ways between so that they stay ways a thing can be carried along.
static func _carry_from(plan: TombPlan, i: int, rng: TombRandom, back: int) -> int:
	var from := i
	var furthest := i
	# (not past a pit that only the hook crosses)
	while furthest > 0 and i - furthest < back and TombPlan.carries(plan.spine_link(furthest - 1), plan.spine()[furthest - 1].id, false):
		furthest -= 1
	if furthest < i:
		from = rng.between(furthest, i - 1)
	for j in range(from, i):
		plan.spine_link(j).keep_carry = true
	return from


# What each way on the axis is, where a rule has not already said.
static func _ways(plan: TombPlan, rng: TombRandom) -> void:
	var count := plan.spine().size()
	var floods := 0
	var shafts := 0
	var ropes := 0
	# (the hook has to come back over its pit: there is no rope beyond one, that
	# it could be dropped down and not brought up again)
	var hooked := false
	for i in count - 1:
		var link := plan.spine_link(i)
		if link.fixed:
			hooked = hooked or link.pass_kind == TombPlan.Pass.GAP
			continue
		if i == 0:
			# (the entrance stair)
			link.pass_kind = TombPlan.Pass.STAIRS
			continue
		var door := not link.switches.is_empty()
		var deep := plan.difficulty >= 1
		var pick := rng.weighted([
			2,
			4,
			0 if door else 2,
			2 if deep and floods == 0 and not link.keep_carry else 0,
			2 if deep and shafts == 0 and not link.keep_carry and not door else 0,
			3 if deep and ropes == 0 and not hooked and not link.keep_carry and not door else 0,
		])
		link.pass_kind = [TombPlan.Pass.OPEN, TombPlan.Pass.STAIRS, TombPlan.Pass.CRAWL, TombPlan.Pass.FLOOD, TombPlan.Pass.SHAFT, TombPlan.Pass.ROPE][pick]
		if link.pass_kind == TombPlan.Pass.FLOOD:
			floods += 1
		elif link.pass_kind == TombPlan.Pass.SHAFT:
			shafts += 1
		elif link.pass_kind == TombPlan.Pass.ROPE:
			ropes += 1
			link.hint = "rope"


# Mummies and pits.
static func _people(plan: TombPlan, rng: TombRandom) -> void:
	var along := plan.spine()
	var count := along.size()
	var left: int = MUMMIES[plan.difficulty]
	if plan.difficulty >= 1:
		# The guardian of the burial chamber: it wakes when the treasure is taken.
		var burial := along[count - 1]
		burial.mummy = ROYAL if plan.difficulty == 2 else [SHAMBLER, PRIEST][rng.below(2)]
		burial.barrier = BARRIER_FOR[burial.mummy]
		burial.guardian = true
		left -= 1
	var places: Array = []
	for i in range(1, count - 1):
		places.append(i)
	rng.shuffle(places)
	for i: int in places:
		if left <= 0:
			break
		var room := along[i]
		# (not where the way back out of the room is slow: he has to be able to outrun it)
		if plan.spine_link(i - 1).pass_kind not in [TombPlan.Pass.OPEN, TombPlan.Pass.STAIRS]:
			continue
		var kind := rng.weighted([3, 2, 2 if plan.difficulty >= 1 else 0, 2 if plan.difficulty >= 1 else 0, 2 if plan.difficulty >= 2 else 0])
		room.mummy = kind
		room.barrier = BARRIER_FOR[kind]
		left -= 1
	for i in range(1, count - 1):
		if along[i].mummy == -1 and along[i].role != TombPlan.Role.WELL and rng.chance([0, 20, 40][plan.difficulty]):
			along[i].pit = true
