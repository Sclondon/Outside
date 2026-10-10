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
static func solve(plan: TombPlan) -> Dictionary:
	var result := {"ok": false, "reason": "", "positions": 0, "dead": 0, "steps": [], "unreached": []}
	if plan.rooms.size() > (1 << POS_BITS) or plan.things.size() > (1 << HAND_BITS) - 1 or plan.triggers.size() > DONE_BITS:
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
	var door_masks: Array[int] = []
	for link in plan.links:
		var mask := 0
		for id in link.switches:
			mask |= 1 << (DONE_SHIFT + id)
		door_masks.append(mask)

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
		var moves := _moves(plan, state, ways, switches_in, hands_free, door_masks)
		var onward := PackedInt64Array()
		for move: Array in moves:
			var to: int = move[0]
			onward.append(to)
			if not came_from.has(to):
				came_from[to] = state
				how[to] = move[1]
				order.append(to)
		nexts[state] = onward
		if order.size() > MAX_POSITIONS:
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

	var steps: Array = []
	var at := first_win
	while came_from[at] != -1:
		steps.push_front(how[at])
		at = came_from[at]
	result["steps"] = steps
	result["ok"] = true
	return result


# Everything that can be done from a position: [position after, step] each.
static func _moves(plan: TombPlan, state: int, ways: Array, switches_in: Array, hands_free: Array[bool], door_masks: Array[int]) -> Array:
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
	if hand >= 0 and (hands_free[pos] or others):
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
			return "%s in %d" % [TombPlan.SWITCH_NAMES[trigger.kind], trigger.room]
	return str(step)
