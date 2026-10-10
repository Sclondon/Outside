extends SceneTree
## Not part of the game. Checks the tomb generator with nothing drawn.
## godot --headless --path . --fixed-fps 60 --script tools/tomb_test.gd -- [plans] [geometry] [same] [drive] [templates] [custom] [seeds=500] [drive_seeds=1,2,3] [per=3] [show=<seed>:<difficulty>]
##
##  plans     every seed from 1 to `seeds` at each difficulty: how many plans passed
##            the solver at the first try, why the others were thrown away, how many
##            tries the worst seed took, and that what `generate` hands back passes.
##  geometry  the same seeds built as a layout (no nodes), and every jump, climb,
##            drop and low place in it measured against what the Player can do
##            (the numbers are read from player.tscn, not written here).
##  same      each tomb made twice over: the fingerprint of its plan and of its
##            geometry must come out the same both times. Prints a few, to compare
##            between machines and renderers.
##  drive     opens tomb.tscn for a few seeds and plays the solver's way through
##            it with the real Player, by the TouchControls node.
##  templates the same for the first `per` seeds at each difficulty that have a
##            two-plate door, a rope down a shaft, or a way up over sand: each of
##            the three, wherever the generator makes it.
##  custom    the same for tombs made by hand (`TombSpec`): the one a new tomb
##            starts as, one with every kind of lock the editor offers, and one
##            with the two-plate door, the rope and the sand, a torch carried
##            down the one and up the other.
##            Then the sand by itself: that its face cannot be got up before
##            the sand is let in, however he jumps at it and kicks off it; how
##            long the heap takes; and that dying does not empty it.
##  show      prints one plan and the way through it.
##  shots=<folder>  (not headless: `--resolution 1280x720`, and its window is kept
##            off the screen) saves pictures of the new templates as they are
##            played, during `templates` and `custom`: the two plates, the rope
##            going down and up, the sand before, pouring, full and gone over.
## With no names: plans, geometry and same. Ends with PASSED or FAILED.

var seeds := 500
var drive_seeds: Array = [1, 2, 3]
var per := 3
var shots := ""
var shot_count := 0
var failed := false


func _initialize() -> void:
	var names: Array = []
	var shown := false
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("seeds="):
			seeds = int(arg.trim_prefix("seeds="))
		elif arg.begins_with("drive_seeds="):
			drive_seeds = []
			for part in arg.trim_prefix("drive_seeds=").split(","):
				drive_seeds.append(int(part))
		elif arg.begins_with("shots="):
			shots = arg.trim_prefix("shots=")
			DirAccess.make_dir_recursive_absolute(shots)
			DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_NO_FOCUS, true)
			DisplayServer.window_set_position(Vector2i(-6000, -6000))
		elif arg.begins_with("per="):
			per = int(arg.trim_prefix("per="))
		elif arg.begins_with("drive_difficulties="):
			drive_difficulties = []
			for part in arg.trim_prefix("drive_difficulties=").split(","):
				drive_difficulties.append(int(part))
		elif arg.begins_with("show="):
			var parts := arg.trim_prefix("show=").split(":")
			_show(int(parts[0]), int(parts[1]) if parts.size() > 1 else 1)
			shown = true
		else:
			names.append(arg)
	if names.is_empty() and not shown:
		names = ["plans", "geometry", "same"]
	_run.call_deferred(names)


func _run(names: Array) -> void:
	if "plans" in names:
		_solver_says_no()
		_plans()
	if "geometry" in names:
		_geometry()
	if "same" in names:
		_same()
	if "drive" in names:
		await _drive()
	if "templates" in names:
		await _drive_templates()
	if "custom" in names:
		await _drive_custom()
	if not names.is_empty():
		print("FAILED" if failed else "PASSED")
	quit(1 if failed else 0)


func _show(seed_value: int, difficulty: int) -> void:
	var plan := TombGenerator.generate(seed_value, difficulty)
	print(plan.describe())
	print("-- the way through (%d steps, %d positions checked, %d tries thrown away)" % [plan.solution.size(), plan.proof["positions"], plan.sub_seed])
	for step: Array in plan.solution:
		print("   ", TombSolver.words(plan, step))


# A plan of rooms down an axis, to be broken by hand.
func _axis_of(roles: Array) -> TombPlan:
	var plan := TombPlan.new()
	for i in roles.size():
		plan.add_room(roles[i]).spine = i
	plan.add_trigger(TombPlan.Switch.TREASURE, roles.size() - 1)
	return plan


# The solver must say no to what cannot be done, or its yes means nothing:
# four plans broken by hand, each a different way, and then real plans with
# one key moved to the far side of its own lock.
func _solver_says_no() -> void:
	print("SOLVER: plans that must be thrown away")
	var roles := [TombPlan.Role.ENTRANCE, TombPlan.Role.CORRIDOR, TombPlan.Role.HALL, TombPlan.Role.BURIAL]
	var cases: Array = []
	# The seal stone that opens a door is behind that door.
	var plan := _axis_of(roles)
	plan.add_link(0, 1, TombPlan.Pass.OPEN)
	plan.add_link(1, 2, TombPlan.Pass.OPEN).switches = [plan.add_trigger(TombPlan.Switch.LEVER, 3).id]
	plan.add_link(2, 3, TombPlan.Pass.OPEN)
	cases.append(["a key behind its own lock", plan, "the treasure cannot be reached"])
	# The torch a brazier wants is on the far side of water, which puts it out of his hand.
	plan = _axis_of(roles)
	plan.add_link(0, 1, TombPlan.Pass.OPEN)
	plan.add_link(1, 2, TombPlan.Pass.FLOOD)
	plan.add_link(2, 3, TombPlan.Pass.OPEN).switches = [plan.add_trigger(TombPlan.Switch.BRAZIER, 2).id]
	plan.add_thing(TombPlan.Item.TORCH, 1)
	cases.append(["a torch that has to be swum with", plan, "the treasure cannot be reached"])
	# The only way to the treasure is down a drop: it can be taken, and never brought out.
	plan = _axis_of(roles)
	plan.add_link(0, 1, TombPlan.Pass.OPEN)
	plan.add_link(1, 2, TombPlan.Pass.DROP)
	plan.add_link(2, 3, TombPlan.Pass.OPEN)
	cases.append(["no way back up", plan, "no way back out"])
	# It can be done; but the jar the door wants can be carried down a drop it cannot be brought back up.
	plan = _axis_of(roles)
	plan.add_link(0, 1, TombPlan.Pass.OPEN)
	plan.add_link(1, 2, TombPlan.Pass.DROP)
	plan.add_link(2, 1, TombPlan.Pass.CLIMB)
	plan.add_link(1, 3, TombPlan.Pass.OPEN).switches = [plan.add_trigger(TombPlan.Switch.OFFERING, 1).id]
	plan.add_thing(TombPlan.Item.JAR, 1)
	cases.append(["a jar that can be lost for good", plan, "it can be made unfinishable"])
	for case: Array in cases:
		var result := TombSolver.solve(case[1])
		var right: bool = not result["ok"] and result["reason"] == case[2]
		print("  %-34s %s (%s)" % [case[0], "thrown away" if right else "WRONGLY " + ("passed" if result["ok"] else "refused"), result["reason"]])
		if not right:
			failed = true
	# Real plans, with the first seal stone moved into the burial chamber: behind its own door.
	var moved := 0
	var refused := 0
	for seed_value in range(1, mini(seeds, 200) + 1):
		var broken := TombGenerator.attempt(seed_value, 1, 0)
		for trigger in broken.triggers:
			var locks := false
			for link in broken.links:
				if trigger.id in link.switches and broken.rooms[link.a].spine >= 0 and broken.rooms[link.b].spine >= 0:
					locks = true
			if trigger.kind == TombPlan.Switch.LEVER and locks and broken.rooms[trigger.room].spine < 0:
				trigger.room = broken.goal_trigger().room
				moved += 1
				if not TombSolver.solve(broken)["ok"]:
					refused += 1
				break
	print("  %d generated plans with a seal stone moved behind its own door: %d thrown away" % [moved, refused])
	if refused != moved:
		failed = true


func _plans() -> void:
	print("PLANS: seeds 1..%d at each difficulty" % seeds)
	for difficulty in 3:
		var began := Time.get_ticks_msec()
		var first := 0
		var reasons := {}
		var worst := 0
		var worst_seed := 0
		var fell_back := 0
		var bad := 0
		var positions := 0
		var most := 0
		var steps := 0
		var rooms := 0
		var kinds := {}
		for seed_value in range(1, seeds + 1):
			var plan := TombGenerator.generate(seed_value, difficulty)
			if plan.sub_seed == 0:
				first += 1
			for reason: String in plan.proof["rejected"]:
				reasons[reason] = int(reasons.get(reason, 0)) + 1
			if plan.sub_seed > worst:
				worst = plan.sub_seed
				worst_seed = seed_value
			if plan.sub_seed >= TombGenerator.MAX_TRIES:
				fell_back += 1
			# What comes back must itself pass, checked afresh.
			var again := TombSolver.solve(plan)
			if not again["ok"]:
				bad += 1
				print("  BAD seed %d: %s" % [seed_value, again["reason"]])
			positions += int(again["positions"])
			most = maxi(most, int(again["positions"]))
			steps += plan.solution.size()
			rooms += plan.rooms.size()
			for link in plan.links:
				var name: String = TombPlan.PASS_NAMES[link.pass_kind]
				kinds[name] = int(kinds.get(name, 0)) + 1
				if not link.switches.is_empty():
					kinds["door:" + link.hint] = int(kinds.get("door:" + link.hint, 0)) + 1
		var names := kinds.keys()
		names.sort()
		var tally := ""
		for name: String in names:
			tally += "%s %d  " % [name, kinds[name]]
		print("  %-8s passed first time %d/%d, handed back passing %d/%d, plain fall-backs %d, worst seed %d took %d tries" % [
			TombGenerator.DIFFICULTY_NAMES[difficulty], first, seeds, seeds - bad, seeds, fell_back, worst_seed, worst + 1])
		print("           thrown away: %s" % (str(reasons) if not reasons.is_empty() else "none"))
		print("           on average %.1f rooms, %.1f steps to finish, %d positions checked (most %d); %.1f s" % [
			float(rooms) / seeds, float(steps) / seeds, positions / seeds, most, (Time.get_ticks_msec() - began) / 1000.0])
		print("           ", tally)
		if bad > 0:
			failed = true


func _geometry() -> void:
	var reach := TombReach.measure()
	print("GEOMETRY: what he can do, from player.tscn: a running jump %.2f m, a ledge %.2f m (asked for no more than %.2f), a hop %.2f, a step %.2f; %.2f tall, %.2f ducked, %.2f wide" % [
		reach["far"], reach["ledge"], TombReach.LEDGE_MOST, reach["hop"], reach["step"], reach["tall"], reach["crouched"], reach["wide"]])
	for difficulty in 3:
		var bad := 0
		var moves := 0
		var boxes := 0
		var longest := 0.0
		var deepest := 0.0
		var kinds := {}
		var first := ""
		for seed_value in range(1, seeds + 1):
			var layout := TombLayout.lay(TombGenerator.generate(seed_value, difficulty))
			var wrong := TombReach.check(layout, reach)
			wrong.append_array(_overlaps(layout))
			if not wrong.is_empty():
				bad += 1
				if first == "":
					first = "seed %d: %s" % [seed_value, wrong[0]]
			moves += layout.moves.size()
			boxes += layout.boxes.size()
			longest = maxf(longest, layout.length)
			deepest = maxf(deepest, layout.depth)
			for move in layout.moves:
				kinds[move["kind"]] = int(kinds.get(move["kind"], 0)) + 1
		print("  %-8s sound %d/%d; %d things measured (%s); on average %d pieces of stone; the longest %.0f m, the deepest %.0f m" % [
			TombGenerator.DIFFICULTY_NAMES[difficulty], seeds - bad, seeds, moves, str(kinds), boxes / seeds, longest, deepest])
		if bad > 0:
			failed = true
			print("           first fault: ", first)


# Rooms off the axis are fitted in round the others: nothing of theirs may be
# where a floor he walks on is. (Lofts against the spans under them, crypts
# against everything.)
func _overlaps(layout: TombLayout) -> PackedStringArray:
	var wrong: PackedStringArray = []
	for room in layout.plan.rooms:
		if room.role != TombPlan.Role.CRYPT:
			continue
		var info := layout.rooms[room.id]
		for span in layout.spans:
			# (the well itself is the way in)
			if span.xb <= float(info["x0"]) + 0.01 or span.xa >= float(info["x1"]) - TombLayout.WELL_WIDE - 0.01:
				continue
			if span.floor - TombLayout.ROCK < float(info["floor"]) + TombLayout.WELL_DEEP - TombLayout.ROCK - 0.01:
				wrong.append("room %d: the chamber under the well runs into the floor over it" % room.id)
				break
	# The far half of a heap of sand lies in the rock the next room stands on: nothing is cut down into that.
	for room in layout.plan.spine():
		var info := layout.rooms[room.id]
		if not info.has("face"):
			continue
		var face: float = info["face"]
		for span in layout.spans:
			if span.xb > face + 0.01 and span.xa < face - TombLayout.SAND_OUT + TombLayout.SAND_PILE * TombLayout.SAND_SKIRT - 0.01 \
					and span.floor < float(info["floor"]) + TombLayout.SAND_RISE - 0.01:
				wrong.append("room %d: the sand heaped at its far end would come out in what is cut down beyond it" % room.id)
				break
	return wrong


func _same() -> void:
	print("SAME: each tomb made twice")
	var differ := 0
	var count := mini(seeds, 200)
	for difficulty in 3:
		for seed_value in range(1, count + 1):
			var one := TombLayout.lay(TombGenerator.generate(seed_value, difficulty))
			var two := TombLayout.lay(TombGenerator.generate(seed_value, difficulty))
			if one.plan.fingerprint() != two.plan.fingerprint() or one.fingerprint() != two.fingerprint():
				differ += 1
	print("  %d tombs at each difficulty: %d came out differently the second time" % [count, differ])
	if differ > 0:
		failed = true
	# These are the same on every machine, or the daily tomb is not.
	for seed_value: int in [1, 2, 3]:
		var layout := TombLayout.lay(TombGenerator.generate(seed_value, 1))
		print("  seed %d middling: plan %s  stone %s" % [seed_value, layout.plan.fingerprint(), layout.fingerprint()])
	var today := TombDaily.today()
	var daily := TombLayout.lay(TombGenerator.generate(TombDaily.seed_for(today), TombDaily.difficulty_for(today)))
	print("  today (day %d, tomb #%d, %s): plan %s  stone %s" % [today, TombDaily.number(today), TombGenerator.DIFFICULTY_NAMES[TombDaily.difficulty_for(today)],
			daily.plan.fingerprint(), daily.fingerprint()])


# --- Driving the real Player through a tomb

var player: Player
var touch: TouchControls
var level: TombLevel
var space: PhysicsDirectSpaceState3D
var frames_used := 0
var tomb_name := ""
var drive_difficulties: Array = [0, 1, 2]
## How often each new move was made, and how often a try at it went wrong.
var tally := {"rope_down": 0, "rope_up": 0, "rope_down_missed": 0, "rope_up_missed": 0, "sand_up": 0, "sand_up_carrying": 0, "sand_down": 0}


func _drive() -> void:
	print("DRIVE: the solver's way through, played by the real Player")
	TombLevel.bare = true
	var finished := 0
	var tried := 0
	for seed_value: int in drive_seeds:
		for difficulty: int in drive_difficulties:
			tried += 1
			if await _drive_one(seed_value, difficulty):
				finished += 1
	print("  finished %d of %d" % [finished, tried])
	_say_tally()
	if finished < tried:
		failed = true


## A tomb with one of every lock the tomb editor offers, and every thing to carry.
func every_lock() -> Dictionary:
	var spec := TombSpec.fresh("Every lock")
	var rooms: Array = []
	for role: String in ["entrance", "corridor", "hall", "well", "gallery", "corridor", "antechamber", "corridor", "corridor", "burial"]:
		rooms.append(TombSpec.room(role))
	rooms[0]["torch"] = 1
	rooms[0]["jar"] = 1
	rooms[1]["hook"] = 1
	rooms[2]["lock"] = "cross"
	rooms[2]["way"] = "stairs"
	rooms[3]["lock"] = "lever_below"
	rooms[3]["stone_in"] = 3
	rooms[4]["lock"] = "brazier"
	rooms[4]["dark"] = true
	rooms[4]["way"] = "stairs"
	rooms[5]["lock"] = "offering"
	rooms[6]["lock"] = "lever_above"
	rooms[6]["stone_in"] = 5
	rooms[6]["way"] = "stairs"
	rooms[7]["way"] = "gap"
	rooms[8]["lock"] = "bypass"
	rooms[9]["mummy"] = 0
	spec["rooms"] = rooms
	return spec


## A tomb with the two-plate door, the rope and the sand: the torch for the
## brazier beyond them is dropped down the shaft with, and carried up the heap.
func three_new() -> Dictionary:
	var spec := TombSpec.fresh("Two plates, a rope, the sand")
	var rooms: Array = []
	for role: String in ["entrance", "corridor", "hall", "corridor", "gallery", "antechamber", "corridor", "burial"]:
		rooms.append(TombSpec.room(role))
	rooms[0]["torch"] = 1
	rooms[2]["lock"] = "pair"
	rooms[2]["way"] = "stairs"
	rooms[3]["way"] = "rope"
	rooms[4]["way"] = "sand"
	rooms[5]["lock"] = "brazier"
	rooms[5]["dark"] = true
	rooms[5]["way"] = "sand"
	rooms[6]["way"] = "stairs"
	spec["rooms"] = rooms
	return spec


# The tombs that have each of the new templates: [seed, difficulty] each, the
# first `per` of each kind at each difficulty.
func _with_templates() -> Array:
	var found: Array = []
	for difficulty in 3:
		var counts := {"two_stones": 0, "rope": 0, "sand": 0}
		for seed_value in range(1, seeds + 1):
			var plan := TombGenerator.generate(seed_value, difficulty)
			var wanted := false
			for link in plan.links:
				var kind := ""
				if link.hint == "two_stones":
					kind = "two_stones"
				elif link.pass_kind == TombPlan.Pass.ROPE:
					kind = "rope"
				elif link.pass_kind == TombPlan.Pass.SAND:
					kind = "sand"
				if kind != "" and int(counts[kind]) < per:
					counts[kind] = int(counts[kind]) + 1
					wanted = true
			if wanted:
				found.append([seed_value, difficulty])
		print("  %-8s tombs with each among seeds 1..%d, up to %d of each: %s" % [TombGenerator.DIFFICULTY_NAMES[difficulty], seeds, per, str(counts)])
	return found


func _drive_templates() -> void:
	print("TEMPLATES: tombs with a two-plate door, a rope or the sand, played by the real Player")
	TombLevel.bare = true
	var finished := 0
	var tombs := _with_templates()
	for tomb: Array in tombs:
		if await _drive_one(tomb[0], tomb[1]):
			finished += 1
	print("  finished %d of %d" % [finished, tombs.size()])
	_say_tally()
	if finished < tombs.size():
		failed = true


func _say_tally() -> void:
	print("  the rope taken hold of %d times going down and %d going up (tries that went wrong: %d and %d); the sand gone up %d times (%d of them with his hands full) and down %d" % [
			tally["rope_down"], tally["rope_up"], tally["rope_down_missed"], tally["rope_up_missed"], tally["sand_up"], tally["sand_up_carrying"], tally["sand_down"]])


func _drive_custom() -> void:
	print("CUSTOM: tombs made by hand, played by the real Player")
	TombLevel.bare = true
	for spec: Dictionary in [TombSpec.fresh(), every_lock(), three_new()]:
		var found := TombSpec.check(spec)
		if not found["ok"]:
			print("  %s: %s %s" % [spec["name"], found["says"], str(found["problems"])])
			failed = true
			continue
		if not (found["warnings"] as PackedStringArray).is_empty():
			print("  %s: %s" % [spec["name"], str(found["warnings"])])
			failed = true
		if not await _drive_one(0, 0, spec):
			failed = true
	if not await _sand_holds():
		failed = true
	_say_tally()


## A tomb whose only way on is up the sand, which a block on its plate lets in.
func only_sand() -> Dictionary:
	var spec := TombSpec.fresh("Only the sand")
	spec["rooms"] = [TombSpec.room("entrance"), TombSpec.room("corridor"), TombSpec.room("burial")]
	spec["rooms"][1]["way"] = "sand"
	spec["rooms"][1]["lock"] = "work"
	return spec


# The sand by itself. Before it is let in he throws himself at the face for ten
# seconds and must not get up it; then the heap is timed; then he dies, and the
# heap must be as it was; then the tomb is played through as any other.
func _sand_holds() -> bool:
	await _open(0, 0, only_sand())
	var layout := level.layout
	var link := level.plan.spine_link(1)
	var lower: Dictionary = layout.rooms[link.a]
	var top: float = layout.rooms[link.b]["floor"]
	var fall: SandFall = level.built.sands[link.id]
	var block := _block_for(-1, link.switches[0])
	var sound := true
	# (round the block, which is not to be pushed yet)
	if not await _go(Vector3((block["body"] as RigidBody3D).global_position.x + 1.6, float(lower["floor"]), 0.0)) or not await _go(lower["east"]):
		print("  the sand: he could not get to the foot of the face")
		sound = false
	var highest := -INF
	var presses := 0
	for i in 600:
		touch.move = Vector2(1.0, 0.0)
		# (every way of pressing jump: held long and let go short, on the ground and in the air against the face)
		touch.jump_held = i % 23 < [14, 4, 22][(i / 23) % 3]
		if i % 23 == 0 or (i % 23 == 9 and (i / 23) % 2 == 0):
			player._queue_jump()
			presses += 1
		if player.state == Player.State.HANG and i % 10 == 0:
			player._queue_jump()
		await _wait(1)
		highest = maxf(highest, player.global_position.y)
	_still()
	await _wait(60)
	var bare := highest < top - 0.3 and player.global_position.x < float(lower["face"]) and not level.done[link.switches[0]]
	print("  the sand, before it is let in: %d presses of jump at a face of %.2f got his feet %.2f up it: %s" % [presses, TombLayout.SAND_RISE, highest - float(lower["floor"]), "it holds him" if bare else "HE GOT UP IT"])
	sound = sound and bare
	await _shot("sand_face_bare")
	# Let in, how long until he is over it (in a hurry, hands free), and until it is full.
	if not await _go(lower["west"]) or not await _push(block, link.switches[0]):
		print("  the sand: the block was not got onto its plate")
		sound = false
	var began := frames_used
	var over := await _sand_up(link, lower, layout.rooms[link.b])
	var over_at := frames_used - began
	for i in 60 * 30:
		if fall.pile != null and fall.pile.is_full():
			break
		await _wait(1)
	var full_at := frames_used - began
	var was := fall.pile.height if fall.pile else 0.0
	print("  the sand, let in: he was over it %.1f s after the plate went down, and the heap was full (%.2f high, %.2f under the lip) after %.1f s: %s" % [
			over_at / 60.0, was, TombLayout.SAND_RISE - was, full_at / 60.0, "sound" if over and full_at < 60 * 20 else "TOO SLOW, OR NOT AT ALL"])
	sound = sound and over and full_at < 60 * 20
	# Dying leaves it as it is.
	level.give_up()
	await _wait(180)
	var now := fall.pile.height if fall.pile else 0.0
	print("  the sand, after he has died (%d): the heap is %.2f high: %s" % [level.deaths, now, "it stays" if is_equal_approx(now, was) and level.deaths == 1 else "IT WAS EMPTIED"])
	sound = sound and is_equal_approx(now, was)
	var done := await _play_through("the sand")
	level.get_parent().queue_free()
	await _wait(5)
	return sound and done


func _drive_one(seed_value: int, difficulty: int, spec := {}) -> bool:
	await _open(seed_value, difficulty, spec)
	var done := await _play_through("seed %d %-8s" % [seed_value, TombGenerator.DIFFICULTY_NAMES[difficulty]] if spec.is_empty() else "\"%s\"" % spec["name"])
	level.get_parent().queue_free()
	await _wait(5)
	return done


# Opens tomb.tscn on a tomb, with the Player and the TouchControls taken hold of.
func _open(seed_value: int, difficulty: int, spec := {}) -> void:
	TombLevel.play = {"mode": "random", "seed": seed_value, "difficulty": difficulty}
	if not spec.is_empty():
		TombLevel.play = {"mode": "custom", "spec": spec}
	var scene: Node = load("res://tomb.tscn").instantiate()
	root.add_child(scene)
	player = scene.get_node("Player")
	touch = scene.get_node("HUD/TouchControls")
	level = scene.get_node("Level")
	touch.set_process_input(false)
	player.set_process_unhandled_input(false)
	player.sleep_after = 0.0
	for action: StringName in InputMap.get_actions():
		if not String(action).begins_with("ui_"):
			InputMap.action_erase_events(action)
			Input.action_release(action)
	await _wait(30)
	space = player.get_world_3d().direct_space_state
	frames_used = 0
	tomb_name = "custom" if not spec.is_empty() else "%d_%d" % [seed_value, difficulty]


# Plays the solver's way through the tomb that is open, and says how it went.
func _play_through(called: String) -> bool:
	var plan := level.plan
	var stopped := ""
	for i in plan.solution.size():
		var step: Array = plan.solution[i]
		var ok := await _do_step(step)
		if OS.has_environment("TOMB_TRACE"):
			print("    step %d %s: %s, now at %s" % [i + 1, TombSolver.words(plan, step), ok, player.global_position])
		if not ok:
			stopped = "step %d of %d (%s) at %s, state %d, on floor %s, limp %s, holding %s, deaths %d" % [i + 1, plan.solution.size(), TombSolver.words(plan, step), player.global_position, player.state, player.is_on_floor(), player.is_limp, player.carried, level.deaths]
			break
	_still()
	await _wait(30)
	if stopped == "" and not level.finished:
		if not await _go(level.layout.start):
			stopped = "the last walk out, at %s" % player.global_position
		await _wait(10)
	var done := level.finished and stopped == ""
	print("  %s %s  %d rooms, %d steps, %.0f m: %s" % [called,
			"FINISHED" if done else "STOPPED ", plan.rooms.size(), plan.solution.size(), level.layout.length,
			("in %s of play, %d deaths" % [TombDaily.time_text(level.time_ms()), level.deaths]) if done else stopped])
	return done


func _do_step(step: Array) -> bool:
	var plan := level.plan
	var layout := level.layout
	match step[0]:
		"go":
			var link: TombPlan.Link = plan.links[step[1]]
			var from: int = step[2]
			var to: int = step[3]
			match link.pass_kind:
				TombPlan.Pass.CLIMB:
					if to == link.b:
						return await _climb_loft(layout.rooms[to])
					var edge: float = layout.rooms[from]["edge"]
					return await _go(Vector3(edge - 1.4, float(layout.rooms[to]["floor"]), 0.0))
				TombPlan.Pass.DROP:
					if not await _go(layout.rooms[from]["east"]):
						return false
					return await _go(layout.rooms[to]["west"])
				TombPlan.Pass.SHAFT:
					if plan.rooms[link.b].role == TombPlan.Role.CRYPT:
						if to == link.b:
							return await _go(layout.rooms[to]["east"])
						return await _go(Vector3(float(layout.rooms[from]["x1"]) + 0.9, float(layout.rooms[to]["floor"]), 0.0))
				TombPlan.Pass.ROPE:
					if to == link.b:
						return await _rope_down(layout.rooms[from], layout.rooms[to])
					return await _rope_up(layout.rooms[to], layout.rooms[from])
				TombPlan.Pass.SAND:
					if to == link.b:
						return await _sand_up(link, layout.rooms[from], layout.rooms[to])
					return await _sand_down(layout.rooms[to], layout.rooms[from])
				TombPlan.Pass.GAP:
					if not await _swing(layout.rooms[link.a]["gap"], to == link.b):
						return false
					return to == link.a or await _go(layout.rooms[to]["west"])
			return await _go(layout.rooms[to]["west" if plan.rooms[to].spine > plan.rooms[from].spine else "east"])
		"push":
			var block := _block_for(step[2], -1)
			return await _push(block, _plate_of(block))
		"take":
			var body: RigidBody3D = level.built.items[step[1]]
			for attempt in 3:
				var side := -0.35 if player.global_position.x < body.global_position.x else 0.35
				if not await _go(Vector3(body.global_position.x + side, body.global_position.y, 0.0), 0.2):
					return false
				_still()
				await _wait(12)
				player._act()
				for i in 120:
					await _wait(1)
					if player.carried == body and player.pickup_progress >= 1.0:
						return true
			print("    could not take %s lying at %s (he is at %s, holding %s)" % [body.name, body.global_position, player.global_position, player.carried])
			return false
		"drop":
			return await _put_down()
		"do":
			var trigger: TombPlan.Trigger = plan.triggers[step[1]]
			if level.done[trigger.id]:
				return true
			var at := layout.switch_at[trigger.id]
			match trigger.kind:
				TombPlan.Switch.WORK_PLATE:
					return await _push(_block_for(-1, trigger.id), trigger.id)
				TombPlan.Switch.PLATE:
					return await _push(_block_for(-2, trigger.id), trigger.id)
				TombPlan.Switch.OFFERING:
					if not await _go(Vector3(at.x - 1.05, at.y - TombLayout.TABLE_HIGH, 0.0), 0.15):
						return false
					# (turned to face it)
					touch.move = Vector2(0.3, 0.0)
					await _wait(8)
					if not await _put_down():
						return false
				TombPlan.Switch.BRAZIER:
					if not await _go(Vector3(at.x, at.y, 0.0)):
						return false
				_:
					if not await _go(at - Vector3(0.85, 0.0, 0.0) if trigger.kind == TombPlan.Switch.TREASURE else at):
						return false
			_still()
			for i in 180:
				await _wait(1)
				if level.done[trigger.id]:
					return true
			print("    %s not done: he is at %s holding %s, it is at %s" % [TombPlan.SWITCH_NAMES[trigger.kind], player.global_position, player.carried, at])
			return false
	return false


func _block_for(thing: int, trigger: int) -> Dictionary:
	for block in level.built.blocks:
		if (thing >= 0 and block["thing"] == thing) or (thing < 0 and block["serves"] == trigger):
			return block
	return {}


func _plate_of(block: Dictionary) -> int:
	return block.get("serves", -1)


# Gets behind a block (over it, if he is beyond it) and walks it east until its plate is down.
func _push(block: Dictionary, trigger: int) -> bool:
	if block.is_empty() or trigger < 0:
		return false
	if level.done[trigger]:
		return true
	var body: RigidBody3D = block["body"]
	if not await _go(Vector3(body.global_position.x - 0.9, body.global_position.y - TombLayout.BLOCK * 0.5, 0.0)):
		return false
	var plate := level.layout.switch_at[trigger]
	var pushed := await _go(Vector3(plate.x + 3.0, plate.y, 0.0), 0.35, func() -> bool: return level.done[trigger], true)
	if _is_two_plates(trigger):
		await _wait(40)
		await _shot("two_plates")
	return pushed


# Whether a plate is one of the two on a two-plate door.
func _is_two_plates(trigger: int) -> bool:
	for link in level.plan.links:
		if link.hint == "two_stones" and trigger in link.switches:
			return true
	return false


func _put_down() -> bool:
	_still()
	# (stood still first: ducking out of a run is a slide)
	await _wait(30)
	touch.duck_held = true
	await _wait(20)
	player._act()
	for i in 90:
		await _wait(1)
		if i % 25 == 24:
			player._act()
		if player.carried == null:
			touch.duck_held = false
			await _wait(25)
			return true
	touch.duck_held = false
	print("    could not put down %s: ducking %s, progress %.2f %.2f, state %d" % [player.carried, player.is_ducking, player.pickup_progress, player.throw_progress, player.state])
	return false


# Runs at the lip of a loft, jumps for it and gets up onto it.
func _climb_loft(info: Dictionary) -> bool:
	var edge: float = info["edge"]
	var top: float = info["floor"]
	for attempt in 3:
		if not await _go(Vector3(edge - 0.62, top - TombLayout.LOFT_TOP, 0.0), 0.1):
			return false
		for i in 240:
			touch.move = Vector2(1.0, 0.0)
			if player.state == Player.State.FREE and player.is_on_floor() and i % 30 == 5:
				touch.jump_held = true
				player._queue_jump()
			if player.state == Player.State.HANG:
				touch.jump_held = false
				player._queue_jump()
			await _wait(1)
			if player.is_on_floor() and player.global_position.y > top - 0.3:
				touch.jump_held = false
				return await _go(info["west"])
			if player.global_position.x > edge + 1.5:
				break
		touch.jump_held = false
	return false


# Down a shaft by its rope: he runs off the lip into it, which is taking hold,
# and lets himself down with the stick. With his hands full he cannot take
# hold: he steps off and drops.
func _rope_down(upper: Dictionary, lower: Dictionary) -> bool:
	var foot: float = lower["floor"]
	if not await _go(upper["east"]):
		return false
	var full := player.carried != null
	var on := false
	for i in 300:
		touch.move = Vector2(1.0, 0.0)
		await _wait(1)
		if player.state == Player.State.ROPE:
			on = true
			break
		if player.is_on_floor() and player.global_position.y < foot + 0.3:
			break
	if on:
		tally["rope_down"] += 1
		await _shot("rope_down_caught")
		for i in 900:
			touch.move = Vector2(0.0, 1.0)
			await _wait(1)
			if i == 70:
				await _shot("rope_down_on_it")
			if player.state != Player.State.ROPE and player.is_on_floor():
				break
	elif not full:
		tally["rope_down_missed"] += 1
		print("    he ran off the lip and did not take hold of the rope (at %s)" % player.global_position)
		return false
	_still()
	# (a long drop is a hard landing: he gets up)
	await _wait(20 if on else 150)
	await _shot("rope_down_foot")
	if full and player.carried == null:
		print("    he dropped what he was carrying, coming down the shaft")
		return false
	return await _go(lower["west"])


# Up a shaft by its rope: he runs at it and jumps, which is taking hold; climbs
# it with the stick to the top; and leaps off it towards the lip.
func _rope_up(upper: Dictionary, lower: Dictionary) -> bool:
	var rope_x := float(lower["x0"]) + TombLayout.ROPE_OUT
	var top: float = upper["floor"]
	if player.carried != null:
		return false
	for attempt in 3:
		if not await _go(Vector3(rope_x + 1.3, float(lower["floor"]), 0.0), 0.2):
			return false
		var on := false
		for i in 150:
			touch.move = Vector2(-1.0, 0.0)
			if i == 6:
				touch.jump_held = true
				player._queue_jump()
			await _wait(1)
			if player.state == Player.State.ROPE:
				on = true
				break
		touch.jump_held = false
		if on:
			await _shot("rope_up_caught")
			for i in 900:
				touch.move = Vector2(0.0, -1.0)
				await _wait(1)
				if i == 120:
					await _shot("rope_up_on_it")
				if player.state != Player.State.ROPE or player._rope_at <= 0.41:
					break
		if on and player.state == Player.State.ROPE:
			await _shot("rope_up_top")
			touch.move = Vector2(-1.0, 0.0)
			touch.jump_held = true
			player._queue_jump()
			for i in 150:
				await _wait(1)
				if i == 12:
					await _shot("rope_up_leap")
				if player.is_on_floor() and player.state == Player.State.FREE:
					break
			touch.jump_held = false
			if player.is_on_floor() and player.global_position.y > top - 0.2:
				tally["rope_up"] += 1
				await _shot("rope_up_off")
				return await _go(upper["east"])
		tally["rope_up_missed"] += 1
		print("    try %d at the rope went wrong: on it %s, now at %s" % [attempt + 1, on, player.global_position])
		_still()
		await _wait(120)
	return false


# Up over the sand, as someone in a hurry does it: straight to the face, and
# jumping at it until the heap under him is high enough. (With his hands free
# that is when he can catch the lip; with them full, when it is a hop.)
func _sand_up(link: TombPlan.Link, lower: Dictionary, upper: Dictionary) -> bool:
	var face: float = lower["face"]
	var top: float = upper["floor"]
	var full := player.carried != null
	var hold_jump := 0
	# (as far as the foot of it by whatever is in the way)
	if player.global_position.x < float(lower["east"].x) and not await _go(lower["east"]):
		return false
	var fall: SandFall = level.built.sands[link.id]
	var seen := 0
	await _shot("sand_foot")
	for i in 60 * 40:
		touch.move = Vector2(1.0, 0.0)
		var at := player.global_position
		hold_jump -= 1
		touch.jump_held = hold_jump > 0
		if player.state == Player.State.HANG:
			if i % 10 == 0:
				player._queue_jump()
		elif player.state == Player.State.FREE and player.is_on_floor() and at.x > face - 0.7 and i % 45 == 0:
			hold_jump = 20
			touch.jump_held = true
			player._queue_jump()
		await _wait(1)
		at = player.global_position
		# (pictures: as he reaches the face, with the heap half grown, and with it full)
		var high := fall.pile.height if fall.pile else 0.0
		if (seen == 0 and at.x > face - 1.0) or (seen == 1 and high > 1.3 and player.is_on_floor()) or (seen == 2 and fall.pile != null and fall.pile.is_full() and player.is_on_floor()):
			seen += 1
			await _shot("sand_up_%d" % seen)
		if player.is_on_floor() and player.state == Player.State.FREE and at.y > top - 0.1 and at.x > face:
			_still()
			await _shot("sand_over")
			if full and player.carried == null:
				print("    he dropped what he was carrying, going up the sand")
				return false
			tally["sand_up"] += 1
			if full:
				tally["sand_up_carrying"] += 1
			return await _go(upper["west"])
	print("    not over the sand: he is at %s, state %d; the heap is %.2f high (full %s), pouring %s" % [player.global_position, player.state, fall.pile.height if fall.pile else -1.0, fall.pile != null and fall.pile.is_full(), fall.running])
	return false


# Back down it: off the lip onto the top of the heap, and down its side.
func _sand_down(lower: Dictionary, upper: Dictionary) -> bool:
	if not await _go(upper["west"]):
		return false
	var foot := float(lower["face"]) - TombLayout.SAND_PILE * TombLayout.SAND_SKIRT
	for i in 900:
		touch.move = Vector2(-1.0, 0.0)
		await _wait(1)
		if i == 45:
			await _shot("sand_down")
		if player.is_on_floor() and player.global_position.x < foot:
			tally["sand_down"] += 1
			return await _go(lower["east"])
	print("    not down the sand: he is at %s, state %d" % [player.global_position, player.state])
	return false


# Over the pit on the hook: throws it at the ring, pumps the swing, and lets go at the front of it.
func _swing(gap: Array, east: bool) -> bool:
	var way := 1.0 if east else -1.0
	var from: float = float(gap[0]) - 0.7 if east else float(gap[1]) + 0.7
	if player.carried == null or not player.carried.is_in_group(&"grapples"):
		return false
	for attempt in 3:
		if not await _go(Vector3(from, player.global_position.y, 0.0), 0.2):
			return false
		touch.move = Vector2(way * 0.3, 0.0)
		await _wait(10)
		_still()
		await _wait(30)
		player._act()
		var on := false
		for i in 150:
			await _wait(1)
			if player.state == Player.State.ROPE:
				on = true
				break
		if not on:
			continue
		var peaks := 0
		var side := 0.0
		var before := 0.0
		for i in 1200:
			if player.state != Player.State.ROPE:
				break
			var hold: Vector3 = player._rope.point_at(player._rope_at) - player._rope.global_position
			var angle := rad_to_deg(atan2(hold.x, -hold.y)) * way
			touch.move = Vector2(signf(player.velocity.x) if absf(player.velocity.x) > 0.2 else way, 0.0)
			if signf(angle) != side and absf(angle) > 0.5:
				peaks += 1
				side = signf(angle)
			if peaks >= 4 and player.velocity.x * way > 0.0 and angle > 22.0 and before <= 22.0:
				break
			before = angle
			await _wait(1)
		touch.move = Vector2(way, 0.0)
		touch.jump_held = true
		player._queue_jump()
		for i in 240:
			await _wait(1)
			if player.is_on_floor():
				break
		touch.jump_held = false
		_still()
		# (he comes down hard, and the hook is wound in)
		await _wait(150)
		var over := player.global_position.x > float(gap[1]) if east else player.global_position.x < float(gap[0])
		if over and not player.is_limp:
			return true
		await _wait(200)
	return false


# A picture of the game as it is now, if pictures were asked for.
func _shot(what: String) -> void:
	if shots == "":
		return
	await process_frame
	await RenderingServer.frame_post_draw
	shot_count += 1
	var name := "%02d_%s_%s" % [shot_count, tomb_name, what]
	root.get_texture().get_image().save_png(shots.path_join(name + ".png"))
	print("    SHOT ", name)


func _still() -> void:
	touch.move = Vector2.ZERO
	touch.jump_held = false
	touch.duck_held = false


func _wait(count: int) -> void:
	for i in count:
		await physics_frame
		frames_used += 1


func _ray(from: Vector3, to: Vector3) -> Dictionary:
	return space.intersect_ray(PhysicsRayQueryParameters3D.create(from, to, 1))


# Goes to a place along the tomb, doing whatever is in the way: jumping what
# there is no floor over, hopping kerbs, ducking under what is low, climbing
# out of what he is in, going up and down ladders, swimming, waiting at doors.
func _go(target: Vector3, near := 0.35, until := Callable(), pushing := false) -> bool:
	var limit := int(absf(target.x - player.global_position.x) / 1.0 * 60.0) + 1500
	var checked := player.global_position
	var since := 0
	var hold_jump := 0
	var back_off := -1000
	for frame in limit:
		var at := player.global_position
		if until.is_valid() and until.call():
			_still()
			return true
		if not until.is_valid() and absf(target.x - at.x) < near and absf(target.y - at.y) < 0.7 and player.is_on_floor() and player.state == Player.State.FREE:
			_still()
			return true
		var way := signf(target.x - at.x)
		if way == 0.0:
			way = 1.0
		back_off -= 1
		touch.move = Vector2(-way if back_off > 0 else way, 0.0)
		touch.duck_held = false
		hold_jump -= 1
		touch.jump_held = hold_jump > 0
		if player.is_limp:
			await _wait(1)
			continue
		match player.state:
			Player.State.LADDER:
				var up := target.y > at.y + 0.05
				touch.move = Vector2(0.0, -1.0 if up else 1.0)
				# (at the foot of it, he lets go)
				if not up and is_instance_valid(player._ladder) and at.y < player._ladder.bottom_y() + 0.12:
					touch.duck_held = true
			Player.State.HANG:
				if target.y > at.y + 0.4 or absf(target.x - at.x) > 1.5:
					if frame % 10 == 0:
						player._queue_jump()
				else:
					touch.duck_held = true
			Player.State.SWIM:
				if frame % 20 == 0 and absf(player.velocity.x) < 0.4:
					player._queue_jump()
			Player.State.FREE:
				if player.is_on_floor():
					var feet := at + Vector3.UP * 0.2
					var low := _ray(feet, feet + Vector3(way * 0.65, 0.0, 0.0))
					# (what lies about loose is stepped over or kicked along, not jumped)
					if not low.is_empty() and low["collider"] is RigidBody3D and not (low["collider"] as Node).is_in_group(&"tomb_blocks"):
						low = {}
					var chest := _ray(at + Vector3.UP * 1.0, at + Vector3(way * 0.65, 1.0, 0.0))
					var head := _ray(at + Vector3(way * 0.5, 0.5, 0.0), at + Vector3(way * 0.5, 1.45, 0.0))
					var over := _ray(at + Vector3.UP * 0.5, at + Vector3.UP * 1.45)
					var ground := _ray(at + Vector3(way * 0.5, 0.5, 0.0), at + Vector3(way * 0.5, -1.0, 0.0))
					var going_down := target.y < at.y - 1.2 and absf(target.x - at.x) < 4.5
					if not head.is_empty() or not over.is_empty():
						touch.duck_held = true
					elif ground.is_empty() and not going_down:
						if absf(player.velocity.x) < 3.6 and back_off < -90:
							# (too slow to clear it from here: back a few steps for a run at it)
							back_off = 32
						elif back_off <= 0:
							hold_jump = 22
							touch.jump_held = true
							player._queue_jump()
					elif not low.is_empty():
						var block := (low["collider"] as Node).is_in_group(&"tomb_blocks")
						if block and pushing:
							pass
						elif block or chest.is_empty():
							hold_jump = 12
							touch.jump_held = true
							player._queue_jump()
						elif target.y > at.y + 0.5:
							# (a wall with something to catch at the top of it)
							hold_jump = 20
							touch.jump_held = true
							player._queue_jump()
		await _wait(1)
		since += 1
		if OS.has_environment("TOMB_TRACE") and absf(player.global_position.x - float(OS.get_environment("TOMB_TRACE"))) < 4.0 and frame % 4 == 0:
			print("      x %.2f y %.2f v %.1f,%.1f state %d floor %s jump %s" % [player.global_position.x, player.global_position.y, player.velocity.x, player.velocity.y, player.state, player.is_on_floor(), touch.jump_held])
		if since >= 120:
			if player.global_position.distance_to(checked) < 0.25 and player.state == Player.State.FREE and player.is_on_floor() and not pushing:
				hold_jump = 15
				player._queue_jump()
			checked = player.global_position
			since = 0
	_still()
	return false
