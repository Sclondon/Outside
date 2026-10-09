class_name TombReach
extends RefCounted
## What the boy can do, worked out from the Player's own numbers (read from
## player.tscn, so that retuning him is found out here and not by a daily tomb
## that cannot be finished), and a tomb's layout held against it.

## How much of the furthest he can jump a tomb may ask of him.
const JUMP_SHARE := 0.8
## The highest ledge a tomb asks him to catch: the wall in the test yard that
## is "too high to jump onto, not too high to reach".
const LEDGE_MOST := 2.1


## The numbers: `far` (a running jump over level ground, metres), `ledge` (the
## highest top he can catch from a standing jump), `hop`, `step`, `tall`,
## `crouched`, `wide`, `run`, and the swimmer's and the hook's.
static func measure() -> Dictionary:
	var player := (load("res://player.tscn") as PackedScene).instantiate() as Player
	var gravity := 2.0 * player.jump_height / (player.time_to_apex * player.time_to_apex)
	var down := sqrt(2.0 * player.jump_height / (gravity * player.fall_gravity_scale))
	var capsule := (player.get_node(^"Collision") as CollisionShape3D).shape as CapsuleShape3D
	var hook := GrappleHook.new()
	var reach := {
		"far": player.run_speed * (player.time_to_apex + down),
		"ledge": player.jump_height + player.ledge_reach.y,
		"catch_low": player.ledge_reach.x,
		"catch_high": player.ledge_reach.y,
		"hop": player.jump_height,
		"step": player.max_step_height,
		"tall": capsule.height,
		"crouched": player.crouch_height,
		"wide": capsule.radius * 2.0,
		"run": player.run_speed,
		"hang": player.hang_height,
		"float": Player.FLOAT_DEPTH,
		"hook_reach": hook.reach,
		"hook_rise": hook.rise,
		"hook_steep": hook.steep,
	}
	hook.free()
	player.free()
	return reach


## Everything in `layout` that he could not do, or that would not hold what it
## is there to hold; empty if it is sound.
static func check(layout: TombLayout, reach: Dictionary) -> PackedStringArray:
	var wrong: PackedStringArray = []
	for move in layout.moves:
		var size: float = move["is"]
		var bad := ""
		match move["kind"]:
			"step", "stop":
				if size > float(reach["step"]):
					bad = "a step of %.2f is more than he steps up (%.2f)" % [size, reach["step"]]
			"hop":
				if size > float(reach["hop"]) * 0.6:
					bad = "a kerb of %.2f is too high to hop" % size
			"jump":
				if size > float(reach["far"]) * JUMP_SHARE:
					bad = "a jump of %.2f is more than %.0f%% of his furthest (%.2f)" % [size, JUMP_SHARE * 100.0, reach["far"]]
			"ledge":
				if size > minf(LEDGE_MOST, float(reach["ledge"]) * 0.8) or size > float(reach["hop"]) + float(reach["catch_high"]):
					bad = "a ledge of %.2f is too high to catch" % size
			"under":
				if size < float(reach["tall"]) + 0.1:
					bad = "%.2f is too low to walk under" % size
			"crawl":
				if size < float(reach["crouched"]) + 0.05 or size >= float(reach["tall"]):
					bad = "a passage %.2f high is not one to go through ducked" % size
			"slot":
				if size < float(reach["wide"]) + 0.2:
					bad = "a gap %.2f wide is too narrow for him" % size
			"swim_out":
				var up := float(reach["float"]) + size
				if up > float(reach["catch_high"]) or up < float(reach["catch_low"]):
					bad = "the side of the water (%.2f over it) is out of his reach from it" % size
			"swim_deep":
				if size < float(reach["float"]) + 0.3:
					bad = "water %.2f deep is not deep enough to swim" % size
			"drop":
				if size <= float(reach["ledge"]):
					bad = "a drop of %.2f that should be one way could be climbed back up" % size
			"swing":
				var across := size * 0.5
				var up := float(move["high"]) - float(reach["hang"])
				if Vector2(across, up).length() > float(reach["hook_reach"]) or up < float(reach["hook_rise"]) \
						or rad_to_deg(atan2(across, up)) > float(reach["hook_steep"]):
					bad = "the ring over a gap of %.2f is out of the hook's reach from its edge" % size
				if size <= float(reach["far"]):
					bad = "a gap of %.2f that should want the hook can be jumped" % size
		if bad != "":
			wrong.append("room %d: %s" % [move["room"], bad])
	# What is meant to hold each mummy must hold that kind, and let him by.
	for part in layout.parts:
		if part["kind"] != "mummy":
			continue
		var kind: int = part["what"]
		var own: Dictionary = Mummy.KINDS[kind]
		var barrier: int = layout.plan.rooms[part["room"]].barrier
		var holds := false
		match barrier:
			TombPlan.Barrier.TRENCH:
				holds = float(own["drop"]) < TombLayout.TRENCH_DEEP or float(own["step_up"]) < TombLayout.TRENCH_DEEP
			TombPlan.Barrier.KERB:
				holds = float(own["step_up"]) < TombLayout.KERB_HIGH
			TombPlan.Barrier.NARROW:
				holds = float(own["radius"]) * 2.0 > TombLayout.SLOT_WIDE
		if not holds:
			wrong.append("room %d: a %s does not hold mummy kind %d" % [part["room"], TombPlan.BARRIER_NAMES[barrier], kind])
		if float(own["walk_speed"]) * 1.3 > float(reach["run"]):
			wrong.append("room %d: mummy kind %d is too fast to run from" % [part["room"], kind])
	return wrong
