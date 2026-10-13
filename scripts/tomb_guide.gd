class_name TombGuide
extends RefCounted
## What the Ba of a tomb's owner knows: from where everything in a tomb is at
## this moment, the next thing to do, and the way to it through the stone.
##
## It asks `TombSolver` for the shortest way to the end from the position the
## level is really in (`position`: which room he is in, what he holds, where
## each thing lies, which switches are done), so it never leads him wrong: a
## tomb is proved to be finishable from every position he can bring about, and
## where the level is somewhere the solver has no way from (it should not be),
## there is no hint at all. Nothing here changes anything, or is part of a
## tomb's plan or its stone: the same tomb has the same fingerprints with it.

## How far it will fly to show one step: further than this and the way is cut short there.
const FAR := 60.0
## How much higher than the Ba's own height over a floor the places on a way are flown by.
const LIFT := 0.3


## The level as a position of the solver's (`TombSolver.position`), or -1 if he is nowhere it knows.
static func position(level: TombLevel) -> int:
	var plan := level.plan
	var layout := level.layout
	var player := level.get_parent().get_node_or_null(^"Player") as Player
	if player == null:
		return -1
	var here := layout.plan_room_at(player.global_position)
	if here < 0 or here >= plan.rooms.size():
		return -1
	var hand := -1
	var lies: Array = []
	for thing in plan.things:
		var room := thing.room
		if thing.kind == TombPlan.Item.BLOCK:
			for block in level.built.blocks:
				if int(block["thing"]) == thing.id:
					var stands := layout.plan_room_at((block["body"] as Node3D).global_position)
					room = thing.dest if stands == thing.dest else thing.room
		elif level.built.items.has(thing.id):
			var body: RigidBody3D = level.built.items[thing.id]
			if body == player.carried:
				hand = thing.id
				room = here
			elif _kept(level, body):
				room = TombPlan.GONE
			else:
				var found := layout.plan_room_at(body.global_position)
				room = found if found >= 0 and found < plan.rooms.size() else thing.room
		lies.append(room)
	var done: Array = []
	for trigger in plan.triggers:
		done.append(level.done[trigger.id])
	# (the falcon is a switch: taken, it stays taken)
	done[plan.goal_trigger().id] = level.has_treasure
	return TombSolver.position(plan, here, hand, lies, done)


# Whether a sphinx has a thing, for good.
static func _kept(level: TombLevel, body: RigidBody3D) -> bool:
	for trigger in level.plan.triggers:
		if trigger.kind == TombPlan.Switch.SPHINX and (level.built.switches[trigger.id] as Sphinx).kept == body:
			return true
	return false


## The shortest way to the end from where the level is now: the solver's steps, or none.
static func steps(level: TombLevel) -> Array:
	var at := position(level)
	if at < 0:
		return []
	return TombSolver.way_from(level.plan, at)


## The first of those steps that is somewhere to go (putting a thing down is
## not), as a way to fly: `points` (through the tomb from where he stands, each
## at the height of the floor there, the last of them the place itself),
## `step` (which step it is) and `says` (it, in words). Empty if there is none.
static func way(level: TombLevel, found: Array) -> Dictionary:
	var player := level.get_parent().get_node_or_null(^"Player") as Player
	if player == null or found.is_empty():
		return {}
	var index := 0
	while index < found.size() - 1 and found[index][0] == "drop":
		index += 1
	var step: Array = found[index]
	var from := player.global_position
	var places := targets(level, step)
	if places.is_empty():
		return {}
	var points := PackedVector3Array()
	var at := from
	var far := 0.0
	for place: Vector3 in places:
		for point in between(level.layout, at, place):
			far += at.distance_to(point)
			if far > FAR:
				break
			points.append(point)
			at = point
	# (it starts beside him: a place hardly a step off, or behind him on his line, is not somewhere to be shown)
	while points.size() > 1 and (points[0].distance_to(from) < 2.5 or (points[0] - from).dot(points[1] - from) < 0.0):
		points.remove_at(0)
	if points.is_empty():
		return {}
	# (the places on the way are flown by a little higher than it would of itself, to clear the head of a flight of stairs)
	for i in points.size() - 1:
		points[i] += Vector3.UP * LIFT
	return {"points": points, "step": step, "says": TombSpec.step_words(level.spec, level.plan, found[0])}


## The whole of the way out, once he has the falcon: every place the steps go by, in order.
static func way_out(level: TombLevel, found: Array) -> Array[Vector3]:
	var out: Array[Vector3] = []
	var player := level.get_parent().get_node_or_null(^"Player") as Player
	if player == null:
		return out
	var at := player.global_position
	for step: Array in found:
		if step[0] != "go":
			continue
		for place in targets(level, step):
			for point in between(level.layout, at, place):
				if out.is_empty() or out[-1].distance_to(point) > 1.0:
					out.append(point)
				at = point
	out.append(level.layout.start)
	return out


## The places a step takes him to, in order: the thing to take, the switch to
## do (for a plate, its block and then the plate), or for a way the door of it
## and where it brings him out.
static func targets(level: TombLevel, step: Array) -> Array[Vector3]:
	var plan := level.plan
	var layout := level.layout
	var out: Array[Vector3] = []
	match step[0]:
		"take":
			out.append((level.built.items[step[1]] as Node3D).global_position)
		"push":
			for block in level.built.blocks:
				if int(block["thing"]) == int(step[2]):
					out.append(_on_floor((block["body"] as Node3D).global_position))
			out.append(_room_point(layout, step[4], plan.links[step[1]]))
		"do":
			var trigger: TombPlan.Trigger = plan.triggers[step[1]]
			if trigger.kind == TombPlan.Switch.WORK_PLATE or trigger.kind == TombPlan.Switch.PLATE:
				for block in level.built.blocks:
					var for_it: bool = int(block["serves"]) == trigger.id
					if for_it and (trigger.kind == TombPlan.Switch.WORK_PLATE) == (int(block["thing"]) < 0):
						out.append(_on_floor((block["body"] as Node3D).global_position))
			# (where he stands to work it, in a tomb that is walked through)
			out.append((layout as TombLayout3D).stand_at[trigger.id] if layout is TombLayout3D else layout.switch_at[trigger.id])
		"go":
			var link: TombPlan.Link = plan.links[step[1]]
			var door := layout.door_at[link.id]
			if door != Vector3.INF and not layout is TombLayout3D:
				out.append(Vector3(door.x, float(layout.rooms[step[2]].get("floor", door.y)), 0.0))
			out.append(_room_point(layout, step[3], link))
	return out


# Where a way brings him out in the room it goes to.
static func _room_point(layout: TombLayout, to: int, link: TombPlan.Link) -> Vector3:
	var info: Dictionary = layout.rooms[to]
	var room := layout.plan.rooms[to]
	var other := layout.plan.rooms[link.a if to == link.b else link.b]
	if layout is TombLayout3D:
		var walked := layout as TombLayout3D
		if TombLayout3D.is_side(room):
			return info["west"] if room.role == TombPlan.Role.LOFT else info["east"]
		if TombLayout3D.is_side(other):
			# (down out of a loft, or up out of the chamber under the well)
			var off: Dictionary = layout.rooms[other.id]
			if other.role == TombPlan.Role.CRYPT:
				return off["over"]
			if link.pass_kind == TombPlan.Pass.CLIMB:
				var lip: Vector3 = off["edge"]
				return Vector3(lip.x, float(info["floor"]), lip.z)
			return info["west"]
		return info["west"] if to == link.b and walked._in[to] == link.id else info["east"]
	if room.spine < 0:
		return info["west"] if room.role == TombPlan.Role.LOFT else info["east"]
	if other.spine < 0:
		if other.role == TombPlan.Role.CRYPT:
			return Vector3(float(layout.rooms[other.id]["x1"]) + 0.9, float(info["floor"]), 0.0)
		if link.pass_kind == TombPlan.Pass.DROP:
			return info["west"]
		return Vector3(float(layout.rooms[other.id]["edge"]) - 1.4, float(info["floor"]), 0.0)
	return info["west"] if room.spine > other.spine else info["east"]


static func _on_floor(at: Vector3) -> Vector3:
	return at - Vector3.UP * TombLayout.BLOCK * 0.5


## The places to go by from one place to another: in a tomb seen from the
## side, only the other; in one that is walked through, along the lines he is
## expected to walk (`TombLayout3D.walk_lines`), by the corners of them, keeping
## to the rooms the two places are in.
static func between(layout: TombLayout, from: Vector3, to: Vector3) -> PackedVector3Array:
	var out := PackedVector3Array()
	var walked := layout as TombLayout3D
	if walked == null or Vector2(to.x - from.x, to.z - from.z).length() < 1.0:
		out.append(to)
		return out
	var a := _on_line(walked, from)
	var b := _on_line(walked, to)
	if a.is_empty() or b.is_empty():
		out.append(to)
		return out
	out.append(a["at"])
	if a["line"] != b["line"]:
		var mine := walked.plan_room_at(from)
		var its := walked.plan_room_at(to)
		var count := walked.walk_points.size()
		var cost: Array[float] = []
		cost.resize(count)
		cost.fill(INF)
		var came: Array[int] = []
		came.resize(count)
		came.fill(-1)
		var first := walked.walk_lines[a["line"]]
		var open: Array[int] = [first.x, first.y]
		for end: int in open:
			cost[end] = (a["at"] as Vector3).distance_to(walked.walk_points[end])
		while not open.is_empty():
			var least := 0
			for i in open.size():
				if cost[open[i]] < cost[open[least]]:
					least = i
			var here: int = open[least]
			open.remove_at(least)
			for line in walked.walk_lines:
				if line.x != here and line.y != here:
					continue
				var there := line.y if line.x == here else line.x
				if walked.walk_rooms[there] != mine and walked.walk_rooms[there] != its:
					continue
				var by := cost[here] + walked.walk_points[here].distance_to(walked.walk_points[there])
				if by < cost[there] - 0.001:
					cost[there] = by
					came[there] = here
					if not there in open:
						open.append(there)
		var last := walked.walk_lines[b["line"]]
		var end := last.x
		if cost[last.y] + (b["at"] as Vector3).distance_to(walked.walk_points[last.y]) < cost[last.x] + (b["at"] as Vector3).distance_to(walked.walk_points[last.x]):
			end = last.y
		if cost[end] < INF:
			var back: Array[Vector3] = []
			var at := end
			while at != -1:
				back.append(walked.walk_points[at])
				at = came[at]
			back.reverse()
			for point in back:
				out.append(point)
	out.append(b["at"])
	out.append(to)
	# (a place hardly a step from the one before it is not worth flying to)
	var kept := PackedVector3Array()
	var before := from
	for i in out.size():
		if i == out.size() - 1 or before.distance_to(out[i]) > 0.8:
			kept.append(out[i])
			before = out[i]
	return kept


# The place on his lines nearest to `at`: `line` (which) and `at` (where on it); the lines of the room it is in first.
static func _on_line(walked: TombLayout3D, at: Vector3) -> Dictionary:
	var room := walked.plan_room_at(at)
	var best := {}
	for pass_number in 2:
		var least := INF
		for n in walked.walk_lines.size():
			var line := walked.walk_lines[n]
			if pass_number == 0 and walked.walk_rooms[line.x] != room and walked.walk_rooms[line.y] != room:
				continue
			var one := walked.walk_points[line.x]
			var other := walked.walk_points[line.y]
			var along := other - one
			var share := clampf((at - one).dot(along) / maxf(along.length_squared(), 0.0001), 0.0, 1.0)
			var nearest := one + along * share
			var off := Vector3(nearest.x - at.x, (nearest.y - at.y) * 3.0, nearest.z - at.z).length()
			if off < least:
				least = off
				best = {"line": n, "at": nearest}
		if not best.is_empty():
			break
	return best
