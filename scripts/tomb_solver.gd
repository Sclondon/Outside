class_name TombSolver
extends RefCounted
## Proves that a plan can be finished, by trying everything.
##
## It plays the plan as a board game. A position is: which room he is in, what
## he has in his hand, which room each loose thing lies in, and which switches
## have been done. From a position he can go along any way that is open to him
## (and that lets what he carries through), push a block through a level
## doorway, take a thing up, put it down, or do a switch that is in the room and
## that he has what it needs for. Every position that can be reached is visited
## (breadth first, so the first way found to the end is a shortest one).
##
## The plan passes if:
##   - there is a position with the treasure taken and him back at the entrance
##     (which is keys before locks, the goal, and the way out, all at once);
##   - every room is stood in at some position;
##   - and from EVERY position that can be reached, that end can still be
##     reached: nothing he may do, in any order, leaves the tomb unfinishable.
##
## What it knows of his limits is deliberately the least he can do (see
## `TombPlan.carries`): a thing in the hand does not go up a ledge or a ladder
## or a rope or through water (down a rope shaft he can drop with it: then it
## stays down). Putting a thing down is only tried where it could matter
## (where a way out needs free hands, where another thing lies, at an offering
## table); elsewhere he could put it down too, and pick it up again.

##
## The creatures that keep a way are doors to it. A leaf of the Book of the
## Dead is a switch he does by standing on it, which takes no hand and is never
## undone; its gate guardian is a switch in the room of his door that can be
## done once the leaf is. He can also be passed by a lucky guess, which is
## never counted on: the way through and the rooms stood in are found without
## one. But then every position a guess could bring about is visited as well
## (`_guesses`), and the end has to be reachable from each of those too, by
## moves that are not guesses. A sphinx is a switch done with the thing it
## wants in his hand, and the thing is then nowhere (`TombPlan.GONE`). A way
## that Medjed watches is a door like any other: its switches shut his eyes.
##
## `way_from` gives the shortest way to the end from any position, for a hint.

## More positions than this and the plan is called too tangled, and thrown away.
const MAX_POSITIONS := 120000

const POS_BITS := 4
const HAND_BITS := 3
const DONE_BITS := 12
const ROOM_BITS := 4
const HAND_SHIFT := POS_BITS
const DONE_SHIFT := POS_BITS + HAND_BITS
const THINGS_SHIFT := POS_BITS + HAND_BITS + DONE_BITS


## Returns what it found: `ok`, `reason` (if not), `positions` (how many were
## visited), `dead` (how many of them the end could not be reached from),
## `steps` (one shortest way through: see below) and `unreached` (rooms).
## A step is an Array: ["go", link, from, to], ["push", link, thing, from, to],
## ["take", thing], ["drop", thing] or ["do", switch].
## (`thorough`: putting a thing down is tried in every room, not only where it
## could matter. Many more positions for the same answer: it is there for the
## tests to hold the quick way against. `most`: how many positions it will
## visit before it calls the plan too tangled.)
static func solve(plan: TombPlan, thorough := false, most := MAX_POSITIONS) -> Dictionary:
	var result := {"ok": false, "reason": "", "positions": 0, "dead": 0, "steps": [], "unreached": []}
	if _too_big(plan):
		result["reason"] = "too big to check"
		return result
	var goal := plan.goal_trigger()
	if goal == null:
		result["reason"] = "no treasure"
		return result
	var home := plan.entrance()
	var goal_bit := 1 << (DONE_SHIFT + goal.id)

	# What does not change from one position to the next, set out by room.
	var ways: Array = []
	var switches_in: Array = []
	var hands_free: Array[bool] = []
	var door_masks: Array[int] = []
	_set_out(plan, ways, switches_in, hands_free, door_masks)

	var start := home
	for thing in plan.things:
		start |= thing.room << (THINGS_SHIFT + thing.id * ROOM_BITS)

	# Breadth first over every position.
	var order: Array[int] = [start]
	var came_from := {start: -1}
	var how := {start: []}
	var nexts := {}
	var head := 0
	var room_mask := (1 << ROOM_BITS) - 1
	var first_win := -1
	while head < order.size():
		var state: int = order[head]
		head += 1
		if first_win == -1 and state & goal_bit and (state & room_mask) == home:
			first_win = state
		var moves := _moves(plan, state, ways, switches_in, hands_free, door_masks, thorough)
		var onward := PackedInt64Array()
		for move: Array in moves:
			var to: int = move[0]
			onward.append(to)
			if not came_from.has(to):
				came_from[to] = state
				how[to] = move[1]
				order.append(to)
		nexts[state] = onward
		if order.size() > most:
			result["reason"] = "too tangled to check"
			result["positions"] = order.size()
			return result
	result["positions"] = order.size()

	var stood := {}
	for state in order:
		stood[state & room_mask] = true
	for room in plan.rooms:
		if not stood.has(room.id):
			result["unreached"].append(room.id)
	if first_win == -1:
		var took := false
		for state in order:
			if state & goal_bit:
				took = true
				break
		result["reason"] = "no way back out" if took else "the treasure cannot be reached"
		return result
	if not result["unreached"].is_empty():
		result["reason"] = "a room cannot be reached"
		return result
	var steps: Array = []
	var at := first_win
	while came_from[at] != -1:
		steps.push_front(how[at])
		at = came_from[at]

	# A gate guardian can be passed without its leaf, by a lucky guess (one in
	# three). Nothing above counts on one. But a guess must not be able to
	# strand him either: so every position a guess could bring about is visited
	# too, with everything that can be done from it, and the end has to be
	# reachable from each of those as well, without any more luck.
	var keepers := false
	for trigger in plan.triggers:
		keepers = keepers or trigger.kind == TombPlan.Switch.NAME
	if keepers:
		head = 0
		while head < order.size():
			var state: int = order[head]
			head += 1
			if not nexts.has(state):
				var onward := PackedInt64Array()
				for move: Array in _moves(plan, state, ways, switches_in, hands_free, door_masks, thorough):
					var to: int = move[0]
					onward.append(to)
					if not came_from.has(to):
						came_from[to] = state
						order.append(to)
				nexts[state] = onward
			for to: int in _guesses(state, switches_in):
				if not came_from.has(to):
					came_from[to] = state
					order.append(to)
			if order.size() > most:
				result["reason"] = "too tangled to check"
				result["positions"] = order.size()
				return result
		result["positions"] = order.size()

	# From which positions can the end still be reached? Back along every move
	# from the positions that are an end.
	var back := {}
	for state in order:
		for to: int in nexts[state]:
			if not back.has(to):
				back[to] = []
			(back[to] as Array).append(state)
	var alive := {}
	var stack: Array[int] = []
	for state in order:
		if state & goal_bit and (state & room_mask) == home:
			alive[state] = true
			stack.append(state)
	while not stack.is_empty():
		var state: int = stack.pop_back()
		if back.has(state):
			for from: int in back[state]:
				if not alive.has(from):
					alive[from] = true
					stack.append(from)
	result["dead"] = order.size() - alive.size()
	if result["dead"] > 0:
		result["reason"] = "it can be made unfinishable"
		return result

	result["steps"] = steps
	result["ok"] = true
	return result


## The position the plan is in: he is in `pos`, holds the thing `hand` (or -1),
## each thing lies in `thing_rooms` (by thing; `TombPlan.GONE` for one a sphinx
## has), and `done` says which switches are done (by switch).
static func position(plan: TombPlan, pos: int, hand: int, thing_rooms: Array, done: Array) -> int:
	var state := pos | ((hand + 1) << HAND_SHIFT)
	for thing in plan.things:
		state |= (int(thing_rooms[thing.id]) & ((1 << ROOM_BITS) - 1)) << (THINGS_SHIFT + thing.id * ROOM_BITS)
	for trigger in plan.triggers:
		if done[trigger.id]:
			state |= 1 << (DONE_SHIFT + trigger.id)
	return state


## One shortest way to the end from a position (see `position`), as `solve`
## gives the way from the start: the steps, or none if there is no way (or the
## plan is too big, or it would take more than `most` positions to find).
## Nothing here counts on a guess at a guardian.
static func way_from(plan: TombPlan, start: int, most := MAX_POSITIONS) -> Array:
	var none: Array = []
	var goal := plan.goal_trigger()
	if goal == null or _too_big(plan):
		return none
	var home := plan.entrance()
	var goal_bit := 1 << (DONE_SHIFT + goal.id)
	var ways: Array = []
	var switches_in: Array = []
	var hands_free: Array[bool] = []
	var door_masks: Array[int] = []
	_set_out(plan, ways, switches_in, hands_free, door_masks)
	var room_mask := (1 << ROOM_BITS) - 1
	var order: Array[int] = [start]
	var came_from := {start: -1}
	var how := {start: []}
	var head := 0
	while head < order.size():
		var state: int = order[head]
		head += 1
		if state & goal_bit and (state & room_mask) == home:
			var steps: Array = []
			var at := state
			while came_from[at] != -1:
				steps.push_front(how[at])
				at = came_from[at]
			return steps
		for move: Array in _moves(plan, state, ways, switches_in, hands_free, door_masks, false):
			var to: int = move[0]
			if not came_from.has(to):
				came_from[to] = state
				how[to] = move[1]
				order.append(to)
		if order.size() > most:
			return none
	return none


static func _too_big(plan: TombPlan) -> bool:
	var rooms := 1 << POS_BITS
	for trigger in plan.triggers:
		# (the last room's number is where a thing is once a sphinx has it)
		if trigger.kind == TombPlan.Switch.SPHINX:
			rooms = TombPlan.GONE
	return plan.rooms.size() > rooms or plan.things.size() > (1 << HAND_BITS) - 1 or plan.triggers.size() > DONE_BITS


# What does not change from one position to the next, set out by room and by link.
static func _set_out(plan: TombPlan, ways: Array, switches_in: Array, hands_free: Array[bool], door_masks: Array[int]) -> void:
	for room in plan.rooms:
		ways.append(plan.links_of(room.id))
		var here: Array[TombPlan.Trigger] = []
		for trigger in plan.triggers:
			if trigger.room == room.id:
				here.append(trigger)
		switches_in.append(here)
		var needs := false
		for link: TombPlan.Link in ways[room.id]:
			if TombPlan.goes(link, room.id) and not TombPlan.carries(link, room.id, false):
				needs = true
		for trigger in here:
			if trigger.kind == TombPlan.Switch.OFFERING:
				needs = true
		hands_free.append(needs)
	for link in plan.links:
		var mask := 0
		for id in link.switches:
			mask |= 1 << (DONE_SHIFT + id)
		door_masks.append(mask)


# The positions a lucky guess at a guardian's name could bring about from this
# one: the guardian named, and the leaf he has not got of no more use to him.
static func _guesses(state: int, switches_in: Array) -> Array[int]:
	var found: Array[int] = []
	for trigger: TombPlan.Trigger in switches_in[state & ((1 << ROOM_BITS) - 1)]:
		if trigger.kind != TombPlan.Switch.NAME or state & (1 << (DONE_SHIFT + trigger.id)):
			continue
		var after := state | (1 << (DONE_SHIFT + trigger.id))
		if trigger.needs >= 0:
			after |= 1 << (DONE_SHIFT + trigger.needs)
		found.append(after)
	return found


# Everything that can be done from a position: [position after, step] each.
static func _moves(plan: TombPlan, state: int, ways: Array, switches_in: Array, hands_free: Array[bool], door_masks: Array[int], thorough := false) -> Array:
	var moves: Array = []
	var room_mask := (1 << ROOM_BITS) - 1
	var pos := state & room_mask
	var hand := ((state >> HAND_SHIFT) & ((1 << HAND_BITS) - 1)) - 1
	var hand_kind := -1
	if hand >= 0:
		hand_kind = plan.things[hand].kind

	# Along a way, with or without a block before him.
	for link: TombPlan.Link in ways[pos]:
		if not TombPlan.goes(link, pos):
			continue
		if (state & door_masks[link.id]) != door_masks[link.id]:
			continue
		if link.pass_kind == TombPlan.Pass.GAP and hand_kind != TombPlan.Item.HOOK:
			continue
		if hand >= 0 and not TombPlan.carries(link, pos, hand_kind == TombPlan.Item.HOOK):
			continue
		var to := link.b if pos == link.a else link.a
		var after := (state & ~room_mask) | to
		if hand >= 0:
			after = _put_thing(after, hand, to)
		moves.append([after, ["go", link.id, pos, to]])
		if link.pass_kind == TombPlan.Pass.OPEN:
			for thing in plan.things:
				if thing.kind == TombPlan.Item.BLOCK and _thing_room(state, thing.id) == pos and (to == thing.dest or to == thing.room):
					moves.append([_put_thing(after, thing.id, to), ["push", link.id, thing.id, pos, to]])

	# Taking up and putting down.
	var others := false
	for thing in plan.things:
		if thing.kind == TombPlan.Item.BLOCK or thing.id == hand or _thing_room(state, thing.id) != pos:
			continue
		others = true
		if hand < 0:
			moves.append([state | ((thing.id + 1) << HAND_SHIFT), ["take", thing.id]])
	if hand >= 0 and (thorough or hands_free[pos] or others):
		moves.append([state & ~(((1 << HAND_BITS) - 1) << HAND_SHIFT), ["drop", hand]])

	# The switches in the room.
	for trigger: TombPlan.Trigger in switches_in[pos]:
		var bit := 1 << (DONE_SHIFT + trigger.id)
		if state & bit:
			continue
		var after := state | bit
		match trigger.kind:
			TombPlan.Switch.PLATE:
				var weighted := false
				for thing in plan.things:
					if thing.kind == TombPlan.Item.BLOCK and thing.dest == pos and _thing_room(state, thing.id) == pos:
						weighted = true
				if not weighted:
					continue
			TombPlan.Switch.OFFERING:
				if hand_kind != TombPlan.Item.JAR:
					continue
				# (the jar is left on the table)
				after &= ~(((1 << HAND_BITS) - 1) << HAND_SHIFT)
			TombPlan.Switch.BRAZIER:
				if hand_kind != TombPlan.Item.TORCH:
					continue
			TombPlan.Switch.NAME:
				# (he has the leaf that says the name: a guess is not counted on)
				if trigger.needs >= 0 and not state & (1 << (DONE_SHIFT + trigger.needs)):
					continue
			TombPlan.Switch.SPHINX:
				if hand_kind != trigger.wants:
					continue
				# (the sphinx keeps it: it is nowhere he can get it again)
				after &= ~(((1 << HAND_BITS) - 1) << HAND_SHIFT)
				after = _put_thing(after, hand, TombPlan.GONE)
		moves.append([after, ["do", trigger.id]])
	return moves


static func _thing_room(state: int, thing: int) -> int:
	return (state >> (THINGS_SHIFT + thing * ROOM_BITS)) & ((1 << ROOM_BITS) - 1)


static func _put_thing(state: int, thing: int, room: int) -> int:
	var shift := THINGS_SHIFT + thing * ROOM_BITS
	return (state & ~(((1 << ROOM_BITS) - 1) << shift)) | (room << shift)


## A step in words, for printing.
static func words(plan: TombPlan, step: Array) -> String:
	match step[0]:
		"go":
			var link: TombPlan.Link = plan.links[step[1]]
			return "go %d>%d by %s" % [step[2], step[3], TombPlan.PASS_NAMES[link.pass_kind]]
		"push":
			return "push the block %d>%d" % [step[3], step[4]]
		"take":
			return "take the %s" % TombPlan.ITEM_NAMES[plan.things[step[1]].kind]
		"drop":
			return "put the %s down" % TombPlan.ITEM_NAMES[plan.things[step[1]].kind]
		"do":
			var trigger: TombPlan.Trigger = plan.triggers[step[1]]
			match trigger.kind:
				TombPlan.Switch.LEAF:
					return "take the leaf of the Book in %d" % trigger.room
				TombPlan.Switch.NAME:
					return "name the guardian in %d" % trigger.room
				TombPlan.Switch.SPHINX:
					return "give the sphinx in %d the %s" % [trigger.room, TombPlan.ITEM_NAMES[trigger.wants]]
			return "%s in %d" % [TombPlan.SWITCH_NAMES[trigger.kind], trigger.room]
	return str(step)
