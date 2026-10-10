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
## How much higher than the highest edge he can possibly catch a face must be
## that is meant to stop him (the foot of the sand, with no sand).
const FACE_OVER := 0.4
## How far below where a rope is tied the Player stops climbing it.
const ROPE_TOP := 0.4
## How far over the lip his feet must be at the top of a rope, to leap off onto it.
const ROPE_STEP_OFF := 0.3


## The numbers: `far` (a running jump over level ground, metres), `ledge` (the
## highest top he can catch from a standing jump), `hop`, `step`, `tall`,
## `crouched`, `wide`, `run`, and the swimmer's, the hook's and the rope's.
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
		"rope_near": player.rope_reach.x,
		"rope_far": player.rope_reach.y,
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
			"rope":
				# Stepping off the lip he must be within reach of it, and hang clear
				# of the face; from the floor below its end must be no higher than
				# his hands; and at the top of it his feet must be over the lip.
				var out: float = move["out"]
				var feet := float(move["over"]) - ROPE_TOP - float(reach["hang"])
				if size <= float(reach["ledge"]):
					bad = "a rope down %.2f is no shaft: its lip can be caught from below" % size
				elif out > float(reach["rope_far"]) + float(reach["wide"]) * 0.5:
					bad = "a rope %.2f out from the lip is out of his reach as he steps off" % out
				elif out < float(reach["wide"]) + 0.3:
					bad = "a rope %.2f out from the face leaves him no room to hang" % out
				elif float(move["clear"]) > float(reach["hang"]) - 0.3:
					bad = "a rope that ends %.2f over the floor is too high to jump into" % move["clear"]
				elif feet < ROPE_STEP_OFF or feet + float(reach["tall"]) > float(move["over"]):
					bad = "at the top of the rope his feet are %.2f over the lip: he cannot leap off onto it" % feet
			"sand":
				# With no sand the face must be past catching; the top of the heap
				# must be near enough under the lip to hop up with his hands full;
				# and the heap must be what the layout has left room for.
				var heap := float(move["pile"]) * tan(SandPile.SLOPE) * SandPile.PROFILE[0].y
				var left := size - heap
				if size < float(reach["ledge"]) + FACE_OVER:
					bad = "a face of %.2f could be got up with no sand" % size
				elif left > float(reach["hop"]) * 0.6:
					bad = "the lip is %.2f over the top of the sand: too high to hop onto" % left
				elif left < 0.0:
					bad = "the sand heaps %.2f higher than the lip" % -left
				elif SandPile.PROFILE[-1].x > float(move["skirt"]) + 0.001:
					bad = "the heap of sand spreads further than there is room for"
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
		# Nothing waits at the top of the sand (but the guardian, behind what
		# holds it): the heap is as good a way down for it as it is a way up for him.
		if not part["guardian"]:
			for link in layout.plan.links:
				if link.pass_kind == TombPlan.Pass.SAND and link.b == part["room"]:
					wrong.append("room %d: a mummy at the top of the sand would come down it after him" % part["room"])
	return wrong
