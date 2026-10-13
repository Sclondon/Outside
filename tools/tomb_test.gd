extends SceneTree
## Not part of the game. Checks the tomb generator with nothing drawn.
## godot --headless --path . --fixed-fps 60 --script tools/tomb_test.gd -- [3d] [branching] [plans] [geometry] [same] [drive] [templates] [custom] [grid] [map] [doors] [seeds=500] [drive_seeds=1,2,3] [drive_difficulties=0,1,2] [per=3] [show=<seed>:<difficulty>]
##
##  3d        everything after it is asked of the tomb that is walked through
##            (`TombLayout3D`) and not the one seen from the side: `geometry` and
##            `same` set it out that way (and also look for air cut through
##            air, and for anything that stands in stone), and `drive`,
##            `templates` and `custom` play it that way, steering him about the
##            floor by the camera as a thumb would. `custom` then also plays a
##            tomb with every way there is in it, one after another.
##  branching everything after it is asked of the tombs that branch (`TombBranching`:
##            they are only ever walked through, so it is `3d` as well). `plans` then
##            also holds the solver to plans made by hand whose answers are known
##            (forks, loops, drops, things carried about them) and to a thorough
##            way of its own, and says what is in the tombs: rooms, forks, loops,
##            dead ends, every switch and thing, and how long one takes to make and
##            to prove. `drive` plays them, and the day's own after them.
##  map       (with branching) the map on the HUD, held against what the level
##            knows as two tombs are played through; and that a touch makes it
##            large and another small.
##  doors     (with 3d or branching) every shut door of a few tombs jumped at from
##            in front and from behind: he must not get up it or through it.
##  grid      (with 3d) a plan whose rooms were given their cells by hand, with
##            a side chamber and a way that closes a loop: that the cells pass
##            the rules, that the same rules refuse cells that break them, and
##            that it is set out, sound, and can be played through.
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
##  kept      what is kept of a day's tomb finished seen from the side and
##            finished walked through: apart, with one run of days between them;
##            and of the day's tomb that branches: apart from both, in a file
##            kept before there was such a thing as well as in a new one.
##            (In a file of its own: the player's is not touched.)
##  sweep     the creatures of the funerary texts (gate guardian, sphinx, Medjed)
##            over `seeds` tombs of each shape at each difficulty: how many tombs
##            have each, that every one is proved, and how many tries were thrown away.
##  ba        (side-on, with 3d, or with branching) the Ba's hint, asked for at
##            every step of a few tombs as they are played, and sent; "Stuck"; and
##            the way out behind it.
##            (`custom` also runs a guardian, a sphinx, Medjed and Apophis each by
##            itself: guesses right and wrong, the wrong thing given, his look run
##            at flat out, the snake let out. `pick=guardian|sphinx|medjed|snake` for one.)
##  show      prints one plan and the way through it.
##  shots=<folder>  (not headless: `--resolution 1280x720`, and its window is kept
##            off the screen) saves pictures of the new templates as they are
##            played, during `templates` and `custom`: the two plates, the rope
##            going down and up, the sand before, pouring, full and gone over.
## With no names: plans, geometry, same and kept. Ends with PASSED or FAILED.

const Shapes := preload("res://tools/tomb_shapes.gd")

var seeds := 500
## Whether it is the tomb that is walked through that is asked about.
var walked := false
## Whether it is the tombs that branch that are asked about (`TombBranching`; they are only ever walked through).
var branch := false
var drive_seeds: Array = [1, 2, 3]
var per := 3
## With `custom`: only the tombs whose names have this in them (and not the sand by itself).
var pick := ""
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
		elif arg == "3d":
			walked = true
		elif arg == "branching":
			branch = true
			walked = true
		elif arg.begins_with("pick="):
			pick = arg.trim_prefix("pick=").to_lower()
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
		names = ["plans", "geometry", "same", "kept"]
	_run.call_deferred(names)


func _run(names: Array) -> void:
	if "plans" in names:
		_solver_says_no()
		if branch:
			_solver_on_a_graph()
		_plans()
	if "sweep" in names:
		_sweep()
	if "geometry" in names:
		_geometry()
	if "same" in names:
		_same()
	if "kept" in names:
		_kept()
	if "drive" in names:
		await _drive()
	if "templates" in names:
		await _drive_templates()
	if "custom" in names:
		await _drive_custom()
	if "ba" in names:
		await _ba_shows()
	if "map" in names:
		await _map_shows()
	if "doors" in names:
		await _doors_hold()
	if "grid" in names:
		await _grid()
	if not names.is_empty():
		print("FAILED" if failed else "PASSED")
	quit(1 if failed else 0)


# The creatures of the funerary texts, over many tombs of each shape and
# difficulty: how many tombs have each, that every one is proved (the solver
# asked afresh), and how many tries were thrown away on the way to them.
func _sweep() -> void:
	print("SWEEP: the creatures in the tombs, seeds 1..%d of each shape at each difficulty" % seeds)
	print("  %-10s %-9s %9s %7s %7s %6s %9s %7s %12s %10s" % ["shape", "", "guardian", "sphinx", "Medjed", "none", "2 or more", "proved", "thrown away", "fell back"])
	for shape: String in ["line", "branching"]:
		for difficulty in 3:
			var with := {"guardian": 0, "sphinx": 0, "medjed": 0}
			var none := 0
			var several := 0
			var proved := 0
			var thrown := 0
			var fell_back := 0
			var most := 0
			var over := 0
			for seed_value in range(1, seeds + 1):
				var plan := TombBranching.generate(seed_value, difficulty) if shape == "branching" else TombGenerator.generate(seed_value, difficulty)
				var has := {}
				var count := 0
				for link in plan.links:
					var keeps := _keeps(plan, link)
					if keeps != "":
						has[keeps] = true
						count += 1
				for keeps: String in has:
					with[keeps] = int(with[keeps]) + 1
				if count == 0:
					none += 1
				elif count > 1:
					several += 1
				most = maxi(most, count)
				if count > int(TombGenerator.KEEPERS[difficulty]):
					over += 1
				if TombSolver.solve(plan)["ok"]:
					proved += 1
				thrown += plan.sub_seed
				if plan.sub_seed >= (TombBranching.MAX_TRIES if shape == "branching" else TombGenerator.MAX_TRIES):
					fell_back += 1
			print("  %-10s %-9s %9d %7d %7d %6d %9d %7s %12d %10d" % [shape, TombGenerator.DIFFICULTY_NAMES[difficulty], with["guardian"], with["sphinx"], with["medjed"], none, several,
					"%d/%d" % [proved, seeds], thrown, fell_back])
			if proved < seeds or over > 0:
				failed = true
				print("    NOT ALL PROVED, or more keepers than a tomb of that difficulty may have (%d tombs; the most in one was %d)" % [over, most])


# A tomb of the kind that is being asked about.
func _generate(seed_value: int, difficulty: int) -> TombPlan:
	return TombBranching.generate(seed_value, difficulty) if branch else TombGenerator.generate(seed_value, difficulty)


func _show(seed_value: int, difficulty: int) -> void:
	var plan := _generate(seed_value, difficulty)
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
	# The leaf with a gate guardian's name is beyond that guardian: only a guess would get him by, and no guess is counted on.
	plan = _axis_of(roles)
	plan.add_link(0, 1, TombPlan.Pass.OPEN)
	var keeper := plan.add_trigger(TombPlan.Switch.NAME, 1)
	keeper.needs = plan.add_trigger(TombPlan.Switch.LEAF, 2).id
	plan.add_link(1, 2, TombPlan.Pass.OPEN).switches = [keeper.id]
	plan.add_link(2, 3, TombPlan.Pass.OPEN)
	cases.append(["a leaf behind its own guardian", plan, "the treasure cannot be reached"])
	# It can be done, and done in order nothing can go wrong: the jar opens the
	# way to the treasure and the leaf, and only then is the guardian named and
	# the rope beyond him open. But a lucky guess lets him by first, with the
	# jar still wanted, and it can be dropped down the rope and never brought up.
	plan = _axis_of(roles)
	plan.add_link(0, 1, TombPlan.Pass.OPEN)
	keeper = plan.add_trigger(TombPlan.Switch.NAME, 1)
	keeper.needs = plan.add_trigger(TombPlan.Switch.LEAF, 3).id
	plan.add_link(1, 2, TombPlan.Pass.ROPE).switches = [keeper.id]
	plan.add_link(1, 3, TombPlan.Pass.OPEN).switches = [plan.add_trigger(TombPlan.Switch.OFFERING, 1).id]
	plan.add_thing(TombPlan.Item.JAR, 1)
	cases.append(["a lucky guess that can strand him", plan, "it can be made unfinishable"])
	# The same with the leaf in the open: then nothing is beyond the guardian that a guess gets him to sooner than he should be.
	plan = _axis_of(roles)
	plan.add_link(0, 1, TombPlan.Pass.OPEN)
	keeper = plan.add_trigger(TombPlan.Switch.NAME, 1)
	keeper.needs = plan.add_trigger(TombPlan.Switch.LEAF, 3).id
	plan.add_link(1, 2, TombPlan.Pass.STAIRS).switches = [keeper.id]
	plan.add_link(1, 3, TombPlan.Pass.OPEN).switches = [plan.add_trigger(TombPlan.Switch.OFFERING, 1).id]
	plan.add_thing(TombPlan.Item.JAR, 1)
	cases.append(["(and the same with stairs: sound)", plan, ""])
	for case: Array in cases:
		var result := TombSolver.solve(case[1])
		var right: bool = (not result["ok"] and result["reason"] == case[2]) or (result["ok"] and case[2] == "")
		print("  %-34s %s (%s)" % [case[0], ("thrown away" if case[2] != "" else "passed") if right else "WRONGLY " + ("passed" if result["ok"] else "refused"), result["reason"]])
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
			var plan := _generate(seed_value, difficulty)
			if plan.sub_seed == 0:
				first += 1
			for reason: String in plan.proof["rejected"]:
				reasons[reason] = int(reasons.get(reason, 0)) + 1
			if plan.sub_seed > worst:
				worst = plan.sub_seed
				worst_seed = seed_value
			if plan.sub_seed >= (TombBranching.MAX_TRIES if branch else TombGenerator.MAX_TRIES):
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
		if branch:
			_plans_that_branch(difficulty)
		print("  %-8s passed first time %d/%d, handed back passing %d/%d, plain fall-backs %d, worst seed %d took %d tries" % [
			TombGenerator.DIFFICULTY_NAMES[difficulty], first, seeds, seeds - bad, seeds, fell_back, worst_seed, worst + 1])
		print("           thrown away: %s" % (str(reasons) if not reasons.is_empty() else "none"))
		print("           on average %.1f rooms, %.1f steps to finish, %d positions checked (most %d); %.1f s" % [
			float(rooms) / seeds, float(steps) / seeds, positions / seeds, most, (Time.get_ticks_msec() - began) / 1000.0])
		print("           ", tally)
		if bad > 0:
			failed = true


# The solver on plans that are not a line, made by hand so that the answer is
# known: a fork, a loop, a one-way drop, and things carried about them.
func _solver_on_a_graph() -> void:
	print("SOLVER: forks, loops, drops and carried things, on plans whose answer is known")
	var roles := [TombPlan.Role.ENTRANCE, TombPlan.Role.CORRIDOR, TombPlan.Role.CORRIDOR, TombPlan.Role.CORRIDOR, TombPlan.Role.BURIAL]
	var cases: Array = []
	# A fork: the seal stone is down the one way, the door on the other.
	var plan := _axis_of(roles)
	plan.add_link(0, 1, TombPlan.Pass.OPEN)
	plan.add_link(1, 2, TombPlan.Pass.CRAWL)
	plan.add_link(1, 3, TombPlan.Pass.OPEN)
	plan.add_link(3, 4, TombPlan.Pass.OPEN).switches = [plan.add_trigger(TombPlan.Switch.LEVER, 2).id]
	cases.append(["a seal stone down the other way", plan, "", 10])
	# A fork: a torch down the one way, across water; the brazier down the other. The torch cannot be swum with.
	plan = _axis_of(roles)
	plan.add_link(0, 1, TombPlan.Pass.OPEN)
	plan.add_link(1, 2, TombPlan.Pass.FLOOD)
	plan.add_link(1, 3, TombPlan.Pass.OPEN)
	plan.add_link(3, 4, TombPlan.Pass.OPEN).switches = [plan.add_trigger(TombPlan.Switch.BRAZIER, 3).id]
	plan.add_thing(TombPlan.Item.TORCH, 2)
	cases.append(["a torch beyond water, the only way", plan, "the treasure cannot be reached", 0])
	# The same, with a second way round to the torch that it can be carried along: a loop.
	plan = _axis_of(roles)
	plan.add_link(0, 1, TombPlan.Pass.OPEN)
	plan.add_link(1, 2, TombPlan.Pass.FLOOD)
	plan.add_link(1, 3, TombPlan.Pass.OPEN)
	plan.add_link(3, 2, TombPlan.Pass.CRAWL)
	plan.add_link(3, 4, TombPlan.Pass.OPEN).switches = [plan.add_trigger(TombPlan.Switch.BRAZIER, 3).id]
	plan.add_thing(TombPlan.Item.TORCH, 2)
	cases.append(["the same, with a crawl round the water", plan, "", 10])
	# A loop with a drop in it: down the drop to the seal stone, and out by the door it opens.
	plan = _axis_of(roles)
	plan.add_link(0, 1, TombPlan.Pass.OPEN)
	plan.add_link(1, 2, TombPlan.Pass.OPEN)
	plan.add_link(2, 3, TombPlan.Pass.DROP)
	plan.add_link(1, 3, TombPlan.Pass.STAIRS).switches = [plan.add_trigger(TombPlan.Switch.LEVER, 3).id]
	plan.add_link(3, 4, TombPlan.Pass.OPEN)
	cases.append(["a drop, and a door opened from below", plan, "", 9])
	# The same with no seal stone: down the drop there is no way back.
	plan = _axis_of(roles)
	plan.add_link(0, 1, TombPlan.Pass.OPEN)
	plan.add_link(1, 2, TombPlan.Pass.OPEN)
	plan.add_link(2, 3, TombPlan.Pass.DROP)
	plan.add_link(1, 3, TombPlan.Pass.STAIRS).switches = [plan.add_trigger(TombPlan.Switch.LEVER, 0).id, plan.add_trigger(TombPlan.Switch.BRAZIER, 1).id]
	plan.add_thing(TombPlan.Item.TORCH, 2)
	plan.add_link(3, 4, TombPlan.Pass.OPEN)
	cases.append(["a torch that can be taken down the drop", plan, "it can be made unfinishable", 0])
	# A hook down one branch, its pit on another, and a rope beyond the pit that the hook must not go down.
	plan = _axis_of(roles + [TombPlan.Role.CORRIDOR])
	plan.rooms[4].role = TombPlan.Role.CORRIDOR
	plan.rooms[5].role = TombPlan.Role.BURIAL
	plan.triggers[0].room = 5
	plan.add_link(0, 1, TombPlan.Pass.OPEN)
	plan.add_link(1, 2, TombPlan.Pass.STAIRS)
	plan.add_link(1, 3, TombPlan.Pass.GAP)
	plan.add_link(3, 4, TombPlan.Pass.ROPE)
	plan.add_link(4, 5, TombPlan.Pass.OPEN)
	plan.add_thing(TombPlan.Item.HOOK, 2)
	cases.append(["a hook that can be dropped down a rope beyond its pit", plan, "it can be made unfinishable", 0])
	# The same with a ladder for the rope: the hook stays at the top, and all is well.
	plan = _axis_of(roles + [TombPlan.Role.CORRIDOR])
	plan.rooms[4].role = TombPlan.Role.CORRIDOR
	plan.rooms[5].role = TombPlan.Role.BURIAL
	plan.triggers[0].room = 5
	plan.add_link(0, 1, TombPlan.Pass.OPEN)
	plan.add_link(1, 2, TombPlan.Pass.STAIRS)
	plan.add_link(1, 3, TombPlan.Pass.GAP)
	plan.add_link(3, 4, TombPlan.Pass.SHAFT)
	plan.add_link(4, 5, TombPlan.Pass.OPEN)
	plan.add_thing(TombPlan.Item.HOOK, 2)
	cases.append(["the same, with a ladder for the rope", plan, "", 14])
	for case: Array in cases:
		var result := TombSolver.solve(case[1])
		var all := TombSolver.solve(case[1], true)
		var right: bool = result["ok"] == (case[2] == "") and (result["ok"] or result["reason"] == case[2]) and all["ok"] == result["ok"]
		# (the way found is a shortest one: so many steps, and no more)
		if right and result["ok"] and (result["steps"] as Array).size() != int(case[3]):
			right = false
		print("  %-52s %s (%s; %d positions, %d with a thing put down anywhere)" % [case[0], ("as it should be" if right else "WRONG"),
				"it can be finished in %d steps" % (result["steps"] as Array).size() if result["ok"] else result["reason"], result["positions"], all["positions"]])
		if not right:
			failed = true


# What is in the tombs that branch, over the same seeds: how many rooms, forks,
# loops and dead ends; how long the solver takes; and that its quick way of
# trying where things are put down gives the answer the thorough way does.
func _plans_that_branch(difficulty: int) -> void:
	var rooms_least := 99
	var rooms_most := 0
	var placed := 0
	var forks := 0
	var forked := 0
	var loops := 0
	var looped := 0
	var drops := 0
	var dead := 0
	var off_trunk := 0
	var fetched := 0
	var bad_cells := 0
	var switches := {}
	var things := {}
	var slowest := 0
	var slowest_seed := 0
	var solve_time := 0
	var make_time := 0
	var slowest_make := 0
	var differ := 0
	var held := 0
	var most := 0
	var distinct := {}
	for seed_value in range(1, seeds + 1):
		var began := Time.get_ticks_usec()
		var plan := TombBranching.generate(seed_value, difficulty)
		var took := int(Time.get_ticks_usec() - began)
		make_time += took
		slowest_make = maxi(slowest_make, took)
		distinct[plan.fingerprint()] = true
		if not TombLayout3D.cells_wrong(plan).is_empty():
			bad_cells += 1
		began = Time.get_ticks_usec()
		var proof := TombSolver.solve(plan)
		took = int(Time.get_ticks_usec() - began)
		solve_time += took
		most = maxi(most, int(proof["positions"]))
		if took > slowest:
			slowest = took
			slowest_seed = seed_value
		# (the thorough way on the first of them, and on the first try at each, passed or not)
		if seed_value <= 60:
			for tried: TombPlan in [plan, TombBranching.attempt(seed_value, difficulty, 0)]:
				held += 1
				var quick := TombSolver.solve(tried)
				var whole := TombSolver.solve(tried, true)
				# (where the thorough way ran out of positions it has no answer to compare)
				if whole["reason"] == "too tangled to check" or quick["reason"] == "too tangled to check":
					held -= 1
				elif quick["ok"] != whole["ok"]:
					differ += 1
		var count := 0
		var joined := 0
		var ways_on := {}
		var way_in := {}
		for link in plan.links:
			if TombLayout3D.is_side(plan.rooms[link.a]) or TombLayout3D.is_side(plan.rooms[link.b]):
				if link.pass_kind == TombPlan.Pass.DROP:
					drops += 1
				continue
			joined += 1
			if not way_in.has(link.b):
				way_in[link.b] = link.a
			for room: int in [link.a, link.b]:
				ways_on[room] = int(ways_on.get(room, 0)) + 1
		# (the way to the burial chamber, back from it)
		var trunk := {}
		var at := plan.goal_trigger().room
		while true:
			trunk[at] = true
			if not way_in.has(at):
				break
			at = way_in[at]
		var holds := {}
		for thing in plan.things:
			holds[thing.room] = true
			things[TombPlan.ITEM_NAMES[thing.kind]] = int(things.get(TombPlan.ITEM_NAMES[thing.kind], 0)) + 1
		for trigger in plan.triggers:
			var room := plan.rooms[trigger.room]
			holds[room.parent if TombLayout3D.is_side(room) else trigger.room] = true
			switches[TombPlan.SWITCH_NAMES[trigger.kind]] = int(switches.get(TombPlan.SWITCH_NAMES[trigger.kind], 0)) + 1
		var tomb_forks := 0
		for room in plan.rooms:
			if TombLayout3D.is_side(room):
				continue
			count += 1
			# (a fork: more than one way on from it, besides the way in)
			if int(ways_on.get(room.id, 0)) - (0 if room.id == plan.entrance() else 1) >= 2:
				tomb_forks += 1
			if not trunk.has(room.id):
				off_trunk += 1
				if holds.has(room.id):
					fetched += 1
				elif int(ways_on.get(room.id, 0)) == 1:
					dead += 1
		placed += count
		rooms_least = mini(rooms_least, plan.rooms.size())
		rooms_most = maxi(rooms_most, plan.rooms.size())
		forks += tomb_forks
		if tomb_forks > 0:
			forked += 1
		loops += joined - (count - 1)
		if joined - (count - 1) > 0 or _has_drop(plan):
			looped += 1
	print("  %-8s that branch: %d different tombs of %d; %d to %d rooms (%.1f on squares on average, %.1f of them off the way to the falcon: %.1f with something he needs, %.1f dead ends)" % [
			TombGenerator.DIFFICULTY_NAMES[difficulty], distinct.size(), seeds, rooms_least, rooms_most, float(placed) / seeds, float(off_trunk) / seeds, float(fetched) / seeds, float(dead) / seeds])
	print("           forks %.1f a tomb (%d of %d tombs have one); second ways between rooms %.2f a tomb, drops from a loft %.2f (%d of %d tombs have a loop of either kind); cells that break the rules: %d" % [
			float(forks) / seeds, forked, seeds, float(loops) / seeds, float(drops) / seeds, looped, seeds, bad_cells])
	print("           switches %s  things %s" % [str(switches), str(things)])
	print("           to make one (with the tries thrown away) %.1f ms on average, %.1f at worst; to prove one %.2f ms on average, %.1f at worst (seed %d), %d positions at most; the thorough solver disagreed on %d of %d" % [
			make_time / 1000.0 / seeds, slowest_make / 1000.0, solve_time / 1000.0 / seeds, slowest / 1000.0, slowest_seed, most, differ, held])
	if bad_cells > 0 or differ > 0 or forked < seeds:
		failed = true


func _has_drop(plan: TombPlan) -> bool:
	for link in plan.links:
		if link.pass_kind == TombPlan.Pass.DROP:
			return true
	return false


# A plan set out the way that is being asked about.
func _lay(plan: TombPlan) -> TombLayout:
	return TombLayout3D.set_out(plan) if walked else TombLayout.lay(plan)


func _geometry() -> void:
	var reach := TombReach.measure()
	if walked:
		print("GEOMETRY of the tomb that is walked through. A kick off a wall takes his feet %.2f m higher than a jump, and sends him out from it at %.1f m/s" % [reach["kick"], reach["kick_out"]])
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
			var layout := _lay(_generate(seed_value, difficulty))
			var wrong := TombReach.check(layout, reach)
			wrong.append_array(_overlaps3(layout as TombLayout3D) if walked else _overlaps(layout))
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
	print("SAME: each tomb made twice%s" % (", walked through" if walked else ""))
	var differ := 0
	var count := mini(seeds, 200)
	for difficulty in 3:
		for seed_value in range(1, count + 1):
			var one := _lay(_generate(seed_value, difficulty))
			var two := _lay(_generate(seed_value, difficulty))
			if one.plan.fingerprint() != two.plan.fingerprint() or one.fingerprint() != two.fingerprint():
				differ += 1
	print("  %d tombs at each difficulty: %d came out differently the second time" % [count, differ])
	if differ > 0:
		failed = true
	# These are the same on every machine, or the daily tomb is not.
	for seed_value: int in [1, 2, 3]:
		var layout := _lay(_generate(seed_value, 1))
		print("  seed %d middling: plan %s  stone %s" % [seed_value, layout.plan.fingerprint(), layout.fingerprint()])
	var today := TombDaily.today()
	var daily := _lay(_generate(TombDaily.seed_for(today), TombDaily.difficulty_for(today)))
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
	print("DRIVE: the solver's way through, played by the real Player%s" % (", in the tomb that is walked through" if walked else ""))
	TombLevel.bare = true
	var finished := 0
	var tried := 0
	for seed_value: int in drive_seeds:
		for difficulty: int in drive_difficulties:
			tried += 1
			if await _drive_one(seed_value, difficulty):
				finished += 1
	if branch:
		# (and the day's own: the tomb that branches that everyone has today)
		var today := TombDaily.today()
		print("  today's (day %d, tomb #%d):" % [today, TombDaily.number(today)])
		tried += 1
		if await _drive_one(TombDaily.seed_for(today), TombDaily.difficulty_for(today)):
			finished += 1
	print("  finished %d of %d" % [finished, tried])
	_say_tally()
	if finished < tried:
		failed = true


## A tomb with one of every lock the tomb editor offers, and every thing to carry.
## (These three are in `tools/tomb_shapes.gd`, which the picture tools share.)
func every_lock() -> Dictionary:
	return Shapes.every_lock()


## A tomb with the two-plate door, the rope and the sand: the torch for the
## brazier beyond them is dropped down the shaft with, and carried up the heap.
func three_new() -> Dictionary:
	return Shapes.three_new()


# The tombs that have each of the new templates: [seed, difficulty] each, the
# first `per` of each kind at each difficulty.
func _with_templates() -> Array:
	var found: Array = []
	for difficulty in 3:
		var counts := {"two_stones": 0, "rope": 0, "sand": 0, "guardian": 0, "sphinx": 0, "medjed": 0}
		for seed_value in range(1, seeds + 1):
			var plan := _generate(seed_value, difficulty)
			var wanted := false
			for link in plan.links:
				var kind := ""
				if link.hint == "two_stones":
					kind = "two_stones"
				elif link.pass_kind == TombPlan.Pass.ROPE:
					kind = "rope"
				elif link.pass_kind == TombPlan.Pass.SAND:
					kind = "sand"
				# (and the creatures that keep a way: each wherever the generator puts it)
				var keeps := _keeps(plan, link)
				if keeps != "" and int(counts[keeps]) < per:
					counts[keeps] = int(counts[keeps]) + 1
					wanted = true
				if kind != "" and int(counts[kind]) < per:
					counts[kind] = int(counts[kind]) + 1
					wanted = true
			if wanted:
				found.append([seed_value, difficulty])
		print("  %-8s tombs with each among seeds 1..%d, up to %d of each: %s" % [TombGenerator.DIFFICULTY_NAMES[difficulty], seeds, per, str(counts)])
	return found


# What keeps a way, of the creatures of the funerary texts: "guardian", "sphinx", "medjed", or nothing.
func _keeps(plan: TombPlan, link: TombPlan.Link) -> String:
	if link.watched:
		return "medjed"
	if plan.keeper_of(link, TombPlan.Switch.NAME) != null:
		return "guardian"
	if plan.keeper_of(link, TombPlan.Switch.SPHINX) != null:
		return "sphinx"
	return ""


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
	print("  of the %d mummies in those tombs, %d woke as he went by or took the falcon" % [mummies_met, mummies_woken])
	print("  the rope taken hold of %d times going down and %d going up (tries that went wrong: %d and %d); the sand gone up %d times (%d of them with his hands full) and down %d" % [
			tally["rope_down"], tally["rope_up"], tally["rope_down_missed"], tally["rope_up_missed"], tally["sand_up"], tally["sand_up_carrying"], tally["sand_down"]])
	print("  leaves of the Book read %d, guardians named with their leaf %d (stepped back from for want of it %d); the clock ran %d sixtieths while a leaf or the names were up" % [
			keeper_tally["leaves"], keeper_tally["named"], keeper_tally["stepped_back"], keeper_tally["clock_ran"]])
	if int(keeper_tally["clock_ran"]) > 0:
		failed = true


func _drive_custom() -> void:
	print("CUSTOM: tombs made by hand, played by the real Player%s" % (", in the tomb that is walked through" if walked else ""))
	TombLevel.bare = true
	# (`pick=guardian`, `sphinx`, `medjed` or `snake`: only that one of the creatures by itself)
	if pick in ["guardian", "sphinx", "medjed", "snake"]:
		var held_up := true
		match pick:
			"guardian":
				held_up = await _guardian_holds()
			"sphinx":
				held_up = await _sphinx_holds()
			"medjed":
				held_up = await _gaze_holds()
			"snake":
				held_up = await _snake_comes()
		if not held_up:
			failed = true
		return
	var specs: Array = [TombSpec.fresh(), every_lock(), three_new(), Shapes.keepers()]
	if walked:
		specs.append(Shapes.every_way())
	if pick != "":
		specs = specs.filter(func(spec: Dictionary) -> bool: return pick in String(spec["name"]).to_lower())
	var finished := 0
	for spec: Dictionary in specs:
		var found := TombSpec.check(spec)
		if not found["ok"]:
			print("  %s: %s %s" % [spec["name"], found["says"], str(found["problems"])])
			failed = true
			continue
		if not (found["warnings"] as PackedStringArray).is_empty():
			print("  %s: %s" % [spec["name"], str(found["warnings"])])
			failed = true
		if await _drive_one(0, 0, spec):
			finished += 1
		else:
			failed = true
	print("  finished %d of %d" % [finished, specs.size()])
	var held := pick != "" or OS.has_environment("TOMB_SKIP_SAND") or (await _sand_holds3() if walked else await _sand_holds())
	if not held:
		failed = true
	if pick == "" and not await _guardian_holds():
		failed = true
	if pick == "" and not await _sphinx_holds():
		failed = true
	if pick == "" and not await _gaze_holds():
		failed = true
	if pick == "" and not await _snake_comes():
		failed = true
	if walked and pick == "" and not await _carried_back3():
		failed = true
	_say_tally()


## How a guardian that asks for a name he has no leaf for is answered: "back"
## (he steps back, as the driver always does), "wrong", or "right" (a lucky guess).
var guess := "back"


# A gate guardian by itself, and the guesses a player may make at him. With
# no leaf he is told a wrong name: he strikes, and the boy is put back at the
# last door, which is the guardian's own, with the gateway still barred. Then
# the right name by luck: the knives go up and stay up. Then the tomb is
# played through as any other (the leaf is still read on the way, for nothing).
func _guardian_holds() -> bool:
	var spec := TombSpec.fresh("One keeper")
	var rooms: Array = []
	for role: String in ["entrance", "corridor", "hall", "corridor", "burial"]:
		rooms.append(TombSpec.room(role))
	rooms[2]["lock"] = "name_above"
	rooms[2]["stone_in"] = 1
	spec["rooms"] = rooms
	await _open(0, 0, spec)
	var plan := level.plan
	var named: TombPlan.Trigger
	for trigger in plan.triggers:
		if trigger.kind == TombPlan.Switch.NAME:
			named = trigger
	var link := plan.link_of(named.id)
	var keeper: GateGuardian = level.built.switches[named.id]
	var stand: Vector3 = layout3.stand_at[named.id] if walked else level.layout.switch_at[named.id]
	var door: Vector3 = level.layout.door_at[link.id]
	var sound := true
	guess = "wrong"
	if walked:
		await _go3(stand, 0.2)
	else:
		await _go(stand, 0.2)
	var furthest := -INF
	var way := (door - stand).normalized()
	for i in 600:
		await _wait(1)
		furthest = maxf(furthest, (player.global_position - door).dot(way))
		if level.deaths >= 1 and not player.is_limp:
			break
	await _wait(60)
	var back := player.global_position.distance_to(stand)
	var held := level.deaths == 1 and not keeper.on and furthest < 0.0 and back < 6.0 and not level._open[link.id]
	print("  the guardian, told a wrong name: deaths %d, he is %.1f m from the gateway and never got nearer than %.2f short of its middle, the guardian %s: %s" % [
			level.deaths, back, -furthest, "is named" if keeper.on else "is not named", "it holds" if held else "IT DID NOT HOLD"])
	sound = sound and held
	guess = "right"
	if walked:
		await _go3(stand, 0.2)
	else:
		await _go(stand, 0.2)
	for i in 300:
		await _wait(1)
		if keeper.on and level._open[link.id]:
			break
	var lucky := keeper.on and level._open[link.id] and not level.done[named.needs]
	print("  the guardian, told the right name by luck (no leaf): %s" % ("his way is open, and stays open" if lucky else "IT DID NOT OPEN"))
	sound = sound and lucky
	guess = "back"
	var done := await _play_through("the guardian")
	level.get_parent().queue_free()
	await _wait(5)
	return sound and done


# A sphinx by itself, given the wrong thing first: its paw must put that
# back on the floor of its own room, where he can get at it (seen from the
# side: on his line), far enough off not to be taken for a second offer; he
# takes it up again; and then the tomb is played through, with the right thing
# given and kept.
func _sphinx_holds() -> bool:
	await _open(0, 0, Shapes.one_sphinx())
	var plan := level.plan
	var layout := level.layout
	var asks: TombPlan.Trigger
	for trigger in plan.triggers:
		if trigger.kind == TombPlan.Switch.SPHINX:
			asks = trigger
	var sphinx: Sphinx = level.built.switches[asks.id]
	var torch := -1
	var jar := -1
	for thing in plan.things:
		if thing.kind == TombPlan.Item.TORCH:
			torch = thing.id
		elif thing.kind == TombPlan.Item.JAR:
			jar = thing.id
	var body: RigidBody3D = level.built.items[torch]
	var before := layout.switch_at[asks.id]
	var sound := await _do_step(["go", 0, 0, 1]) and await _do_step(["take", torch]) and await _do_step(["go", 1, 1, 2])
	if walked:
		var stand := layout3.stand_at[asks.id]
		sound = sound and await _go3(stand, 0.2)
		touch.move = _stick(_flat(stand, before), 0.3)
		await _wait(8)
	else:
		sound = sound and await _go(Vector3(before.x, before.y, 0.0), 0.2)
	sound = sound and await _put_down()
	for i in 400:
		await _wait(1)
		if sphinx.strikes >= 1 and not body.has_meta(&"offered") and body.linear_velocity.length() < 0.2:
			break
	await _wait(90)
	var lies := body.global_position
	var floor: float = layout.rooms[asks.room]["floor"]
	var put_back := sphinx.strikes == 1 and not sphinx.on and layout.plan_room_at(lies) == asks.room and absf(lies.y - floor) < 0.6 \
			and layout.apart(lies, before) > TombLevel.OFFER_WITHIN and (walked or absf(lies.z) < 0.05) and not level.done[asks.id]
	print("  the sphinx, given a torch when it wants a jar: refused %d time(s); the torch lies %.2f m from where he stood, %.2f over the floor of room %d%s: %s" % [
			sphinx.strikes, layout.apart(lies, before), lies.y - floor, layout.plan_room_at(lies), "" if walked else (", %.2f off his line" % absf(lies.z)), "put back where he can get it" if put_back else "NOT PUT BACK RIGHT"])
	sound = sound and put_back
	var again := await _do_step(["take", torch])
	sound = sound and again and sphinx.strikes == 1
	# (carried out of the way, and put down)
	if walked:
		sound = sound and await _go3(layout3.rooms[asks.room]["west"])
	else:
		sound = sound and await _go(layout.rooms[asks.room]["west"])
	sound = sound and await _put_down()
	print("  the torch taken up again and carried off: %s" % ("yes" if sound else "NO"))
	var done := await _play_through("the sphinx")
	var kept: bool = sphinx.on and sphinx.kept == level.built.items[jar] and not (level.built.items[jar] as Node).is_in_group(&"throwable")
	print("  the sphinx, given the jar: %s" % ("it keeps it, and its door is open" if kept else "IT DID NOT KEEP IT"))
	level.get_parent().queue_free()
	await _wait(5)
	return sound and done and kept


# Medjed by himself. With his eyes open the boy is run at him flat out (as
# fast as he ever goes), down each side of the way and down the middle, and
# then from behind him back towards the door: each time he must be struck down
# well short, and put back at the last door. Then the tomb is played through.
func _gaze_holds() -> bool:
	await _open(0, 0, Shapes.one_medjed())
	var layout := level.layout
	var part := {}
	for found in layout.parts:
		if found["kind"] == "medjed":
			part = found
	var link: TombPlan.Link = level.plan.links[part["link"]]
	var medjed: Medjed = level.built.watchers[link.id]
	var post: Vector3 = part["at"]
	var along := _along(link) if walked else Vector3.RIGHT
	var across := Vector3(-along.z, 0.0, along.x)
	var door: Vector3 = layout.door_at[link.id]
	door.y = post.y
	var was_speed := player.run_speed
	player.run_speed = player.sprint_speed
	var sound := true
	var said: PackedStringArray = []
	var runs: Array = [[0.0, false]]
	if walked:
		runs = [[-1.45, false], [0.0, false], [1.45, false], [-1.45, true], [1.45, true]]
	else:
		runs.append([0.0, true])
	for run: Array in runs:
		var lane: float = run[0]
		var behind: bool = run[1]
		var deaths := level.deaths
		var from := (post + along * 2.5 if behind else door - along * 1.8) + across * lane
		var to := (door - along * 4.0 if behind else post + along * 4.0) + across * lane
		player.global_position = from + Vector3.UP * 0.1
		player.velocity = Vector3.ZERO
		await _wait(20)
		var got := INF
		for i in 420:
			var at := player.global_position
			var way := _flat(at, to).normalized()
			touch.move = _stick(way, 1.0) if walked else Vector2(way.x, 0.0)
			await _wait(1)
			if not player.is_limp and level.deaths == deaths:
				# (how near he came to being by: to Medjed from in front, to the door from behind)
				got = minf(got, (at - door).dot(along) if behind else (post - at).dot(along))
			if level.deaths > deaths and not player.is_limp:
				break
		_still()
		await _wait(60)
		var struck := level.deaths == deaths + 1 and got > 1.0
		said.append("%s%s: %s, %.1f m short" % ["from behind" if behind else "from in front", (" %+.1f off the middle" % lane) if walked else "", "struck down" if level.deaths > deaths else "NOT STRUCK", got])
		sound = sound and struck
	player.run_speed = was_speed
	print("  Medjed, his eyes open, run at flat out (%.1f m/s): %s: %s" % [player.sprint_speed, "; ".join(said), "nobody gets by" if sound else "HE GOT BY, OR NEARLY"])
	# (being put down behind Medjed made the door beyond him the place to start again from, which it never is for
	# a player who has not got by: he is put back before the doorway, and the tomb is played from there)
	var before: Vector3 = part["stand"]
	player.set_spawn(before + Vector3.UP * 0.05)
	player.global_position = before + Vector3.UP * 0.05
	player.velocity = Vector3.ZERO
	await _wait(30)
	var done := await _play_through("Medjed")
	var shut := medjed.is_shut() and level.deaths == runs.size()
	print("  Medjed, the block on its plate: %s" % ("his eyes are shut, and he was walked past" if shut and done else "HIS EYES DID NOT SHUT, or he struck again"))
	level.get_parent().queue_free()
	await _wait(5)
	return sound and done and shut


# The Ba, as tombs are played through. Before every step of the solver's way
# the guide is asked for the way on from where everything really is: it must
# have one, no longer than what is left of the solver's own, and the places it
# would fly by must be in the tomb, the last of them where the step is done.
# Every few steps the Ba is really sent: it must go, arrive there, and come
# back. With the falcon taken it must fly ahead of him, and he must still get
# out; and none of it may change the plan or the stone.
func _ba_shows() -> void:
	print("BA: the hint, asked for at every step of a few tombs%s" % (", walked through" if walked else ""))
	TombLevel.bare = true
	var tombs: Array = []
	for seed_value: int in drive_seeds:
		for difficulty: int in drive_difficulties:
			tombs.append([seed_value, difficulty, {}])
	if not branch:
		tombs.append([0, 0, Shapes.keepers()])
	for tomb: Array in tombs:
		await _open(tomb[0], tomb[1], tomb[2])
		var plan := level.plan
		var layout := level.layout
		var before := [plan.fingerprint(), layout.fingerprint()]
		var asked := 0
		var none := 0
		var longer := 0
		var astray := 0
		var flown := 0
		var arrived := 0
		var spirited := level.ba.spirited
		var landed := [Vector3.INF]
		var stuck_tried := false
		level.ba.arrived.connect(func(at: Vector3) -> void: landed[0] = at)
		var stopped := ""
		var todo: Array = plan.solution.duplicate()
		var i := -1
		while i + 1 < todo.size():
			i += 1
			if level.finished:
				break
			var found := TombGuide.steps(level)
			var way := TombGuide.way(level, found)
			asked += 1
			if found.is_empty() or way.is_empty():
				none += 1
			else:
				if found.size() > todo.size() - i:
					longer += 1
				var points: PackedVector3Array = way["points"]
				var last := points[points.size() - 1]
				var wanted: Array[Vector3] = TombGuide.targets(level, way["step"])
				for point in points:
					if layout.plan_room_at(point + Vector3.UP * 0.4) < 0:
						astray += 1
				if last.distance_to(wanted[wanted.size() - 1]) > 0.1 and points.size() < 40:
					astray += 1
				# (and sent, now and then, while he has not the falcon: after that it leads)
				if i % 4 == 1 and not level.has_treasure:
					landed[0] = Vector3.INF
					if level.hint():
						flown += 1
						for frame in 2400:
							await _wait(1)
							if not level._hinting:
								break
						if landed[0] != Vector3.INF and landed[0].distance_to(last) < 3.0 and not level._hinting:
							arrived += 1
						elif OS.has_environment("TOMB_TRACE"):
							print("    the Ba, sent to %s for \"%s\", landed at %s (still showing: %s)" % [last, way["says"], landed[0], level._hinting])
			# Once in each tomb: "Stuck" (a death, back at the last door, and the Ba
			# with words), and then standing about (it comes unasked, and not again at once).
			if i >= 2 and not stuck_tried and player.carried == null and not level.has_treasure:
				stuck_tried = true
				var deaths := level.deaths
				var had := level.hints
				level.stuck_asked()
				for frame in 400:
					await _wait(1)
					if level.hints > had:
						break
				var told: bool = level.deaths == deaths + 1 and level.hints == had + 1 and level._caption.visible
				for frame in 2400:
					await _wait(1)
					if not level._hinting:
						break
				level._idle = TombLevel.HINT_AFTER + 1.0
				level._since_hint = TombLevel.HINT_APART + 1.0
				await _wait(5)
				var unasked: bool = level.hints == had + 2
				level._idle = TombLevel.HINT_AFTER + 1.0
				for frame in 2400:
					await _wait(1)
					if not level._hinting:
						break
				level._idle = TombLevel.HINT_AFTER + 1.0
				await _wait(30)
				var quiet: bool = level.hints == had + 2
				print("    Stuck: a death and a hint in words: %s; getting nowhere: it comes unasked: %s, and holds its peace for half a minute after: %s" % [told, unasked, quiet])
				if not (told and unasked and quiet):
					failed = true
				level._since_hint = 0.0
				level._idle = 0.0
				# (and from the door he was put back at, the rest is played by the guide's own way from there)
				todo = TombGuide.steps(level)
				i = -1
				continue
			if not await _do_step(todo[i]):
				stopped = TombSolver.words(plan, todo[i])
				break
		_still()
		var led := level._leading and level.has_treasure
		if stopped == "" and not level.finished:
			if walked:
				await _go3(layout.start)
			else:
				await _go(layout.start)
			await _wait(10)
		var same: bool = before == [plan.fingerprint(), layout.fingerprint()] and before[0] == level.run.get("plan", "") and before[1] == level.run.get("stone", "")
		var sound: bool = level.finished and none == 0 and longer == 0 and astray == 0 and arrived == flown and flown > 0 and led and same
		print("  %s: asked at %d steps: no way %d, a longer way than the solver's %d, places out of the tomb or short of the mark %d; sent %d times and back from the right place %d (as a spirit, through stone, %d flights); led him out: %s; he got out: %s; fingerprints as they were: %s: %s" % [
				("\"%s\"" % tomb[2]["name"]) if not (tomb[2] as Dictionary).is_empty() else "seed %d %s" % [tomb[0], TombGenerator.DIFFICULTY_NAMES[tomb[1]]],
				asked, none, longer, astray, flown, arrived, level.ba.spirited - spirited, led, level.finished if stopped == "" else "STOPPED at " + stopped, same, "sound" if sound else "NOT SOUND"])
		if not sound:
			failed = true
		level.get_parent().queue_free()
		await _wait(5)


# Apophis, who is only ever put in a tomb by hand. With the falcon taken he
# must come out of his hole and after the boy; the boy caught is back at the
# last door and the snake back in his hole, and out again; and then the tomb
# is played through from the start, and the boy gets out or does not: that is
# said, with what it cost him, and is not held against the tomb (nothing proves
# he can be outrun, which the editor says of him too).
func _snake_comes() -> bool:
	await _open(0, 0, Shapes.one_snake())
	var snake := level.built.snake
	var sound := snake != null and not snake.loose and not snake.is_awake()
	var done := await _play_through("the snake")
	var came := snake != null and snake.loose
	print("  Apophis, in a tomb made by hand: asleep down his hole until the falcon is taken: %s; let out by it: %s; the boy %s, at a cost of %d deaths" % [
			sound, came, "got out ahead of him" if done else "DID NOT GET OUT", level.deaths])
	level.get_parent().queue_free()
	await _wait(5)
	# And caught on purpose: he stands by the falcon and waits for him.
	await _open(0, 0, Shapes.one_snake())
	snake = level.built.snake
	var steps: Array = level.plan.solution
	var took := true
	for step: Array in steps:
		took = took and await _do_step(step)
		if level.has_treasure:
			break
	_still()
	var woke := false
	for i in 1500:
		await _wait(1)
		woke = woke or snake.is_awake()
		if level.deaths >= 1 and not player.is_limp:
			break
	await _wait(30)
	var home := snake.global_position.distance_to(snake.get_parent().to_global(snake.position)) < 0.01 and level.deaths == 1
	var back: bool = level.layout.plan_room_at(player.global_position) >= 0 and level.has_treasure
	for i in 600:
		await _wait(1)
		if snake.is_awake():
			break
	var again := snake.is_awake() and snake.loose
	print("  Apophis, waited for by the falcon: he came (%s) and caught him (deaths %d); the boy is back at a door with the falcon (%s); the snake came out again (%s)" % [woke, level.deaths, back, again])
	level.get_parent().queue_free()
	await _wait(5)
	return sound and came and took and woke and home and back and again


## A tomb whose only way on is up the sand, which a block on its plate lets in.
func only_sand() -> Dictionary:
	return Shapes.only_sand()


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
func _open(seed_value: int, difficulty: int, spec := {}, given: TombPlan = null) -> void:
	TombLevel.play = {"mode": "random", "seed": seed_value, "difficulty": difficulty}
	if not spec.is_empty():
		TombLevel.play = {"mode": "custom", "spec": spec}
	if given:
		TombLevel.play = {"mode": "plan", "plan": given}
	TombLevel.play["view"] = "3d" if walked else "side"
	if branch and spec.is_empty() and given == null:
		TombLevel.play["shape"] = "branching"
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
	woken = {}
	layout3 = level.layout as TombLayout3D
	frames_used = 0
	tomb_name = "custom" if not spec.is_empty() else "%d_%d" % [seed_value, difficulty]


# Plays the solver's way through the tomb that is open, and says how it went.
func _play_through(called: String) -> bool:
	var plan := level.plan
	var stopped := ""
	for i in plan.solution.size():
		var step: Array = plan.solution[i]
		var died := level.deaths
		var ok := await _do_step(step)
		if not ok and level.deaths > died and not level.finished:
			# (he died on the way, and is back at the last door: the step is tried once more from there)
			await _wait(200)
			ok = await _do_step(step)
		if OS.has_environment("TOMB_TRACE"):
			print("    step %d %s: %s, now at %s" % [i + 1, TombSolver.words(plan, step), ok, player.global_position])
		if not ok:
			stopped = "step %d of %d (%s) at %s, state %d, on floor %s, limp %s, holding %s, deaths %d" % [i + 1, plan.solution.size(), TombSolver.words(plan, step), player.global_position, player.state, player.is_on_floor(), player.is_limp, player.carried, level.deaths]
			break
	_still()
	await _wait(30)
	if stopped == "" and not level.finished:
		var out := await _go3(level.layout.start) if walked else await _go(level.layout.start)
		if not out:
			stopped = "the last walk out, at %s" % player.global_position
		await _wait(10)
	var done := level.finished and stopped == ""
	print("  %s %s  %d rooms, %d steps, %.0f m: %s" % [called,
			"FINISHED" if done else "STOPPED ", plan.rooms.size(), plan.solution.size(), level.layout.length,
			("in %s of play, %d deaths" % [TombDaily.time_text(level.time_ms()), level.deaths]) if done else stopped])
	mummies_met += level.built.mummies.size()
	mummies_woken += woken.size()
	return done


func _do_step(step: Array) -> bool:
	if walked:
		return await _do_step3(step)
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
				TombPlan.Switch.SPHINX:
					# (stood before its paws, he puts down what it wants: it takes it from there)
					if not await _go(Vector3(at.x, at.y, 0.0), 0.2) or not await _put_down():
						return false
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
		# (carried on by a run he can be too near the lip to get off the ground before
		# he is under it: then he goes back a few steps, stands, and takes it from there)
		await _wait(12)
		if player.global_position.x > edge - 0.5:
			# (a few slow steps back, with no jumping: there may be a block close behind him)
			for i in 90:
				if player.global_position.x < edge - 0.8:
					break
				touch.move = Vector2(-0.45, 0.0)
				await _wait(1)
			_still()
			await _wait(15)
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


## What the gate guardians and their leaves came to: leaves read, guardians named
## (each with its leaf: he does not guess), times he stepped back for want of the
## leaf, and sixtieths the clock ran on while a leaf or the names were up (none).
var keeper_tally := {"leaves": 0, "named": 0, "stepped_back": 0, "clock_ran": 0}
var _panel_frames := 0
var _panel_ticks := 0


# A leaf of the Book that has come up is read and put away, and a guardian
# that asks is told his name if the leaf that says it has been found: as a
# player does it, after a moment. The game stands still meanwhile, and so must the clock.
func _answer_panel() -> void:
	var panel := GuardianPanel.current
	if not is_instance_valid(panel) or not is_instance_valid(level):
		_panel_frames = 0
		return
	if _panel_frames == 0:
		_panel_ticks = level.ticks
	_panel_frames += 1
	if _panel_frames < 30:
		return
	_panel_frames = 0
	keeper_tally["clock_ran"] = int(keeper_tally["clock_ran"]) + level.ticks - _panel_ticks
	if panel.dealt.is_empty():
		keeper_tally["leaves"] = int(keeper_tally["leaves"]) + 1
		panel.choose(-1)
	elif panel.known:
		keeper_tally["named"] = int(keeper_tally["named"]) + 1
		panel.choose(panel.who)
	else:
		if guess == "back":
			keeper_tally["stepped_back"] = int(keeper_tally["stepped_back"]) + 1
			panel.choose(-1)
		else:
			var said := panel.who
			for name: int in panel.dealt:
				if guess == "wrong" and name != panel.who:
					said = name
			panel.choose(said)


func _wait(count: int) -> void:
	for i in count:
		await physics_frame
		frames_used += 1
		_answer_panel()
		# (which mummies have been up, for the count at the end)
		if frames_used % 6 == 0 and is_instance_valid(level) and level.built:
			for n in level.built.mummies.size():
				var mummy: Node3D = level.built.mummies[n]["node"]
				if mummy.has_method(&"is_awake") and mummy.call(&"is_awake"):
					woken[n] = true


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


# --- The same, in a tomb that is walked through
#
# There he is steered over the floor, not along a line, and what is asked of
# the stick is turned to how the camera is looking, as a thumb's push is. He
# goes by the lines the layout says he is expected to walk
# (`TombLayout3D.walk_lines`): onto the nearest, along them from corner to
# corner, and off the last to where he is going. Each straight stretch is gone
# along as `_go` goes along the whole of a tomb seen from the side, with the
# same jumping, hopping, ducking, climbing and swimming.

const ARRIVED := 1
const LOST := 0
## He was thrown back to a door on the way (he died): the way has to be found again.
const THROWN := 2

var layout3: TombLayout3D
## Which mummies of the tomb that is open have been awake, and the count over every tomb played.
var woken := {}
var mummies_met := 0
var mummies_woken := 0


# The stick, for going `way` over the ground, as the camera now looks.
func _stick(way: Vector3, push := 0.92) -> Vector2:
	var flat := Vector3(way.x, 0.0, way.z)
	if flat.length() < 0.001:
		return Vector2.ZERO
	flat = flat.normalized() * push
	var right := Vector3.RIGHT
	var forward := Vector3.FORWARD
	var camera := player.get_viewport().get_camera_3d()
	if camera:
		var view := camera.global_basis
		right = Vector3(view.x.x, 0.0, view.x.z).normalized()
		forward = Vector3(-view.z.x, 0.0, -view.z.z)
		if forward.length_squared() < 0.001:
			forward = Vector3(view.y.x, 0.0, view.y.z)
		forward = forward.normalized()
	return Vector2(flat.dot(right), -flat.dot(forward))


func _flat(from: Vector3, to: Vector3) -> Vector3:
	return Vector3(to.x - from.x, 0.0, to.z - from.z)


# Straight to a place, doing whatever is in the way (see _go).
func _leg(target: Vector3, near := 0.35, until := Callable(), pushing := false) -> int:
	var limit := int(_flat(player.global_position, target).length() * 70.0) + 1500
	var checked := player.global_position
	var since := 0
	var hold_jump := 0
	var back_off := -1000
	var deaths := level.deaths
	var way := Vector3.ZERO
	for frame in limit:
		var at := player.global_position
		if until.is_valid() and until.call():
			_still()
			return ARRIVED
		var to := _flat(at, target)
		var far := to.length()
		if not until.is_valid() and far < near and absf(target.y - at.y) < 0.7 and player.is_on_floor() and player.state == Player.State.FREE:
			_still()
			return ARRIVED
		if level.deaths != deaths:
			_still()
			return THROWN
		if far > 0.08:
			way = to / far
		back_off -= 1
		touch.move = _stick(-way if back_off > 0 else way)
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
				if target.y > at.y + 0.4 or far > 1.5:
					if frame % 10 == 0:
						player._queue_jump()
				else:
					touch.duck_held = true
			Player.State.SWIM:
				if frame % 20 == 0 and Vector2(player.velocity.x, player.velocity.z).length() < 0.4:
					player._queue_jump()
			Player.State.FREE:
				if player.is_on_floor():
					var feet := at + Vector3.UP * 0.2
					var low := _ray(feet, feet + way * 0.65)
					# (what lies about loose is stepped over or kicked along, not jumped;
					# and what is beyond where he is going is nothing to him)
					if not low.is_empty() and low["collider"] is RigidBody3D and not (low["collider"] as Node).is_in_group(&"tomb_blocks"):
						low = {}
					if not low.is_empty() and feet.distance_to(low["position"]) > far + 0.25:
						low = {}
					var chest := _ray(at + Vector3.UP * 1.0, at + Vector3.UP * 1.0 + way * 0.65)
					var head := _ray(at + way * 0.5 + Vector3.UP * 0.5, at + way * 0.5 + Vector3.UP * 1.45)
					var over := _ray(at + Vector3.UP * 0.5, at + Vector3.UP * 1.45)
					var ground := _ray(at + way * 0.5 + Vector3.UP * 0.5, at + way * 0.5 + Vector3.DOWN * 1.0)
					var going_down := target.y < at.y - 1.2 and far < 4.5
					if not head.is_empty() or not over.is_empty():
						touch.duck_held = true
					elif ground.is_empty() and not going_down and far > 0.5:
						if Vector2(player.velocity.x, player.velocity.z).length() < 3.4 and back_off < -90:
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
		if OS.has_environment("TOMB_TRACE") and frame % 6 == 0:
			print("      at %s v %.1f state %d floor %s to %s" % [player.global_position, player.velocity.length(), player.state, player.is_on_floor(), target])
		if since >= 120:
			if player.global_position.distance_to(checked) < 0.25 and player.state == Player.State.FREE and player.is_on_floor() and not pushing:
				hold_jump = 15
				player._queue_jump()
			checked = player.global_position
			since = 0
	_still()
	return LOST


# The place on his lines nearest to `at`: `line` (which) and `at` (where on it).
func _on_line(at: Vector3) -> Dictionary:
	var room := layout3.plan_room_at(at)
	var best := {}
	for pass_number in 2:
		var least := INF
		for n in layout3.walk_lines.size():
			var line := layout3.walk_lines[n]
			if pass_number == 0 and layout3.walk_rooms[line.x] != room and layout3.walk_rooms[line.y] != room:
				continue
			var one := layout3.walk_points[line.x]
			var other := layout3.walk_points[line.y]
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


# The places to go by, in order, to get to `target` by his lines.
func _route(target: Vector3) -> Array[Vector3]:
	var from := player.global_position
	var out: Array[Vector3] = []
	var a := _on_line(from)
	var b := _on_line(target)
	if a.is_empty() or b.is_empty() or _flat(from, target).length() < 1.0:
		out.append(target)
		return out
	out.append(a["at"])
	if a["line"] != b["line"]:
		# The shortest way along the lines from the one he is on to the one it is on.
		# (In a tomb that branches there is often another way round, through
		# rooms he has no business in and doors that may be shut: only the lines
		# of the room he is in and of the room he is going to are gone by.)
		var fenced := level.shape == "branching"
		var mine := layout3.plan_room_at(from)
		var its := layout3.plan_room_at(target)
		var count := layout3.walk_points.size()
		var cost: Array[float] = []
		cost.resize(count)
		cost.fill(INF)
		var came: Array[int] = []
		came.resize(count)
		came.fill(-1)
		var first := layout3.walk_lines[a["line"]]
		for end: int in [first.x, first.y]:
			cost[end] = (a["at"] as Vector3).distance_to(layout3.walk_points[end])
		var open: Array[int] = [first.x, first.y]
		while not open.is_empty():
			var least := 0
			for i in open.size():
				if cost[open[i]] < cost[open[least]]:
					least = i
			var here: int = open[least]
			open.remove_at(least)
			for line in layout3.walk_lines:
				if line.x != here and line.y != here:
					continue
				var there := line.y if line.x == here else line.x
				if fenced and layout3.walk_rooms[there] != mine and layout3.walk_rooms[there] != its:
					continue
				var by := cost[here] + layout3.walk_points[here].distance_to(layout3.walk_points[there])
				if by < cost[there] - 0.001:
					cost[there] = by
					came[there] = here
					if not there in open:
						open.append(there)
		var last := layout3.walk_lines[b["line"]]
		var end := last.x
		if cost[last.y] + (b["at"] as Vector3).distance_to(layout3.walk_points[last.y]) < cost[last.x] + (b["at"] as Vector3).distance_to(layout3.walk_points[last.x]):
			end = last.y
		if cost[end] < INF:
			var back: Array[Vector3] = []
			var at := end
			while at != -1:
				back.append(layout3.walk_points[at])
				at = came[at]
			back.reverse()
			out.append_array(back)
	out.append(b["at"])
	out.append(target)
	# (a place hardly a step from the one before it is not worth stopping at)
	var kept: Array[Vector3] = []
	var before := from
	for i in out.size():
		if i == out.size() - 1 or _flat(before, out[i]).length() > 0.45 or absf(before.y - out[i].y) > 0.5:
			kept.append(out[i])
			before = out[i]
	return kept


# To a place, by his lines. `avoid` is something that stands where the last
# few steps would take him through it (a block he is getting behind): he goes round.
func _go3(target: Vector3, near := 0.35, avoid := Vector3.INF) -> bool:
	for attempt in 8:
		var route := _route(target)
		if avoid != Vector3.INF:
			var from := route[-2] if route.size() > 1 else player.global_position
			var along := _flat(from, target)
			var share := clampf(_flat(from, avoid).dot(along) / maxf(along.length_squared(), 0.0001), 0.0, 1.0)
			if _flat(from + along * share, avoid).length() < 0.85:
				var across := Vector3(-along.z, 0.0, along.x).normalized()
				for side: float in [1.4, -1.4]:
					var one := from + across * side
					var other := Vector3(target.x, from.y, target.z) + across * side
					var up := Vector3.UP * 0.5
					if _ray(from + up, one + up).is_empty() and _ray(one + up, other + up).is_empty() and _ray(other + up, Vector3(target.x, from.y, target.z) + up).is_empty():
						route.insert(route.size() - 1, one)
						route.insert(route.size() - 1, other)
						break
		var again := false
		for i in route.size():
			var got := await _leg(route[i], near if i == route.size() - 1 else 0.3)
			if got == ARRIVED:
				continue
			again = true
			if got == THROWN:
				# (he is back at a door: when he is on his feet, the way is found again from there)
				await _wait(150)
			elif attempt >= 2:
				return false
			break
		if not again:
			return true
	return false


func _along(link: TombPlan.Link) -> Vector3:
	return Vector3(TombLayout3D.TURNS[int(layout3.ways[link.id]["turn"])])


# Where a way brings him to in the room it goes to: just inside its way in, or its bay.
func _arrival(link: TombPlan.Link, to: int) -> Vector3:
	var info := layout3.rooms[to]
	if to == link.b and layout3._in[to] == link.id:
		return info["west"]
	return info["east"]


func _do_step3(step: Array) -> bool:
	var plan := level.plan
	match step[0]:
		"go":
			var link: TombPlan.Link = plan.links[step[1]]
			var from: int = step[2]
			var to: int = step[3]
			match link.pass_kind:
				TombPlan.Pass.CLIMB:
					var loft := layout3.rooms[link.b]
					var along := Vector3(TombLayout3D.TURNS[int(loft["turn"])])
					var edge: Vector3 = loft["edge"]
					if to == link.b:
						return await _climb_loft3(loft)
					if not await _go3(loft["west"]):
						return false
					return await _leg(Vector3(edge.x, float(layout3.rooms[to]["floor"]), edge.z) - along * 1.4) == ARRIVED
				TombPlan.Pass.DROP:
					if not await _go3(layout3.rooms[from]["east"]):
						return false
					return await _leg(layout3.rooms[to]["west"]) == ARRIVED
				TombPlan.Pass.SHAFT:
					if plan.rooms[link.b].role == TombPlan.Role.CRYPT:
						var crypt := layout3.rooms[link.b]
						if to == link.b:
							if not await _go3(crypt["before"]):
								return false
							return await _leg(crypt["east"]) == ARRIVED
						if not await _go3(crypt["east"]):
							return false
						return await _leg(crypt["over"]) == ARRIVED
				TombPlan.Pass.ROPE:
					if to == link.b:
						if not await _rope_down3(link):
							return false
					elif not await _rope_up3(link):
						return false
				TombPlan.Pass.SAND:
					if to == link.b:
						if not await _sand_up3(link):
							return false
					elif not await _sand_down3(link):
						return false
				TombPlan.Pass.GAP:
					if not await _swing3(link, to == link.b):
						return false
			return await _go3(_arrival(link, to))
		"push":
			var block := _block_for(step[2], -1)
			return await _push3(block, _plate_of(block))
		"take":
			var body: RigidBody3D = level.built.items[step[1]]
			for attempt in 3:
				var lies := body.global_position
				var beside := _on_line(lies)
				if not beside.is_empty() and _flat(player.global_position, lies).length() > 1.2 and not await _go3(beside["at"]):
					return false
				if await _leg(Vector3(lies.x, player.global_position.y, lies.z), 0.5) != ARRIVED:
					continue
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
			var at := layout3.switch_at[trigger.id]
			var stand := layout3.stand_at[trigger.id]
			match trigger.kind:
				TombPlan.Switch.WORK_PLATE:
					return await _push3(_block_for(-1, trigger.id), trigger.id)
				TombPlan.Switch.PLATE:
					return await _push3(_block_for(-2, trigger.id), trigger.id)
				TombPlan.Switch.SPHINX:
					if not await _go3(stand, 0.2):
						return false
					# (turned to face it)
					touch.move = _stick(_flat(stand, at), 0.3)
					await _wait(8)
					if not await _put_down():
						return false
				TombPlan.Switch.OFFERING:
					if not await _go3(stand, 0.15):
						return false
					# (turned to face it)
					touch.move = _stick(_flat(stand, at), 0.3)
					await _wait(8)
					if not await _put_down():
						return false
				_:
					if not await _go3(stand):
						return false
			_still()
			for i in 180:
				await _wait(1)
				if level.done[trigger.id]:
					return true
			print("    %s not done: he is at %s holding %s, it is at %s" % [TombPlan.SWITCH_NAMES[trigger.kind], player.global_position, player.carried, at])
			return false
	return false


# Gets behind a block, round it if it is in the way, and walks it along its lane until its plate is down.
func _push3(block: Dictionary, trigger: int) -> bool:
	if block.is_empty() or trigger < 0:
		return false
	if level.done[trigger]:
		return true
	var body: RigidBody3D = block["body"]
	var stands := body.global_position
	var plate := layout3.switch_at[trigger]
	var to := _flat(stands, plate)
	var along := Vector3(signf(to.x), 0.0, 0.0) if absf(to.x) > absf(to.z) else Vector3(0.0, 0.0, signf(to.z))
	var behind := Vector3(stands.x, stands.y - TombLayout.BLOCK * 0.5, stands.z) - along * 0.95
	if not await _go3(behind, 0.2, stands):
		return false
	var pushed := await _leg(plate + along * 3.0, 0.35, func() -> bool: return level.done[trigger], true) == ARRIVED
	if not pushed:
		var ahead := _ray(body.global_position, body.global_position + along * 2.0)
		print("    the block is at %s (it began at %s), its plate at %s; ahead of it within 2 m: %s" % [body.global_position, stands, plate, ("%s at %s" % [(ahead["collider"] as Node).get_path(), ahead["position"]]) if not ahead.is_empty() else "nothing"])
	if _is_two_plates(trigger):
		await _wait(40)
		await _shot("two_plates")
	return pushed


# Runs at the lip of a loft, jumps for it and gets up onto it.
func _climb_loft3(loft: Dictionary) -> bool:
	var along := Vector3(TombLayout3D.TURNS[int(loft["turn"])])
	var edge: Vector3 = loft["edge"]
	var top: float = loft["floor"]
	for attempt in 3:
		if not await _go3(Vector3(edge.x, top - TombLayout.LOFT_TOP, edge.z) - along * 0.62, 0.12):
			return false
		for i in 240:
			touch.move = _stick(along, 1.0)
			if player.state == Player.State.FREE and player.is_on_floor() and i % 30 == 5:
				touch.jump_held = true
				player._queue_jump()
			if player.state == Player.State.HANG:
				touch.jump_held = false
				player._queue_jump()
			await _wait(1)
			if player.is_on_floor() and player.global_position.y > top - 0.3:
				touch.jump_held = false
				return await _go3(loft["west"])
			if _flat(edge, player.global_position).dot(along) > 1.5:
				break
		touch.jump_held = false
	return false


# Down a shaft by its rope: he runs off the lip into it, which is taking hold,
# and lets himself down with duck. With his hands full he cannot take hold: he
# steps off and drops.
func _rope_down3(link: TombPlan.Link) -> bool:
	var way := layout3.ways[link.id]
	var along := _along(link)
	var hangs: Vector3 = way["rope"]
	var foot: float = (way["lower"] as Vector3).y
	if not await _go3(way["upper"]):
		return false
	var full := player.carried != null
	var on := false
	for i in 300:
		var to := _flat(player.global_position, hangs)
		touch.move = _stick(to if to.dot(along) > 0.3 else along, 1.0)
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
			touch.move = Vector2.ZERO
			touch.duck_held = true
			await _wait(1)
			if player.state != Player.State.ROPE and player.is_on_floor():
				break
	elif not full:
		tally["rope_down_missed"] += 1
		print("    he ran off the lip and did not take hold of the rope (at %s)" % player.global_position)
		return false
	_still()
	# (a long drop is a hard landing: he gets up)
	await _wait(20 if on else 150)
	if full and player.carried == null:
		print("    he dropped what he was carrying, coming down the shaft")
		return false
	return true


# Up a shaft by its rope: he runs at it and jumps, which is taking hold; climbs
# it with act held, to the top; and leaps off it towards the lip.
func _rope_up3(link: TombPlan.Link) -> bool:
	var way := layout3.ways[link.id]
	var along := _along(link)
	var hangs: Vector3 = way["rope"]
	var top: float = (way["lip"] as Vector3).y
	if player.carried != null:
		return false
	for attempt in 3:
		if not await _go3(way["lower"], 0.2):
			return false
		var on := false
		for i in 150:
			var to := _flat(player.global_position, hangs)
			touch.move = _stick(to if to.length() > 0.15 else -along, 1.0)
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
			touch.move = Vector2.ZERO
			# (he climbs with act held: but act has to be let go once he is on it, and pressed again)
			await _wait(4)
			for i in 900:
				touch.act_held = true
				await _wait(1)
				if OS.has_environment("ROPE_TRACE") and i % 20 == 0:
					print("      climbing: state %d, hands %.2f down, at %s, act %s" % [player.state, player._rope_at, player.global_position, player._rope_act])
				if player.state != Player.State.ROPE or player._rope_at <= 0.41:
					break
			if OS.has_environment("ROPE_TRACE"):
				print("      at the top of the rope: state %d, hands %.2f down it, at %s" % [player.state, player._rope_at, player.global_position])
			touch.act_held = false
		if on and player.state == Player.State.ROPE:
			await _shot("rope_up_top")
			touch.jump_held = true
			player._queue_jump()
			for i in 150:
				touch.move = _stick(-along, 1.0)
				await _wait(1)
				if player.is_on_floor() and player.state == Player.State.FREE:
					break
			touch.jump_held = false
			if player.is_on_floor() and player.global_position.y > top - 0.2:
				tally["rope_up"] += 1
				_still()
				return true
		tally["rope_up_missed"] += 1
		print("    try %d at the rope went wrong: on it %s, now at %s" % [attempt + 1, on, player.global_position])
		_still()
		await _wait(120)
	return false


# Up over the sand, as someone in a hurry does it: straight to the face, and
# jumping at it until the heap under him is high enough.
func _sand_up3(link: TombPlan.Link) -> bool:
	var way := layout3.ways[link.id]
	var along := _along(link)
	var face: Vector3 = way["face"]
	var top: float = (way["top"] as Vector3).y
	var full := player.carried != null
	var hold_jump := 0
	if _flat(way["before"], player.global_position).dot(along) < 0.0 and not await _go3(way["before"]):
		return false
	var fall: SandFall = level.built.sands[link.id]
	var seen := 0
	await _shot("sand_foot")
	for i in 60 * 40:
		var at := player.global_position
		touch.move = _stick(_flat(at, face + along * 1.5), 1.0)
		hold_jump -= 1
		touch.jump_held = hold_jump > 0
		if player.state == Player.State.HANG:
			if i % 10 == 0:
				player._queue_jump()
		elif player.state == Player.State.FREE and player.is_on_floor() and _flat(at, face).dot(along) < 0.7 and i % 45 == 0:
			hold_jump = 20
			touch.jump_held = true
			player._queue_jump()
		await _wait(1)
		at = player.global_position
		var high := fall.pile.height if fall.pile else 0.0
		if (seen == 0 and _flat(at, face).dot(along) < 1.0) or (seen == 1 and high > 1.3 and player.is_on_floor()) or (seen == 2 and fall.pile != null and fall.pile.is_full() and player.is_on_floor()):
			seen += 1
			await _shot("sand_up_%d" % seen)
		if player.is_on_floor() and player.state == Player.State.FREE and at.y > top - 0.1 and _flat(face, at).dot(along) > 0.0:
			_still()
			await _shot("sand_over")
			if full and player.carried == null:
				print("    he dropped what he was carrying, going up the sand")
				return false
			tally["sand_up"] += 1
			if full:
				tally["sand_up_carrying"] += 1
			return true
	print("    not over the sand: he is at %s, state %d; the heap is %.2f high (full %s), pouring %s" % [player.global_position, player.state, fall.pile.height if fall.pile else -1.0, fall.pile != null and fall.pile.is_full(), fall.running])
	return false


# Back down it: off the lip onto the top of the heap, and down its side.
func _sand_down3(link: TombPlan.Link) -> bool:
	var way := layout3.ways[link.id]
	var along := _along(link)
	var face: Vector3 = way["face"]
	if not await _go3(way["top"]):
		return false
	for i in 900:
		touch.move = _stick(_flat(player.global_position, way["before"]), 1.0)
		await _wait(1)
		if player.is_on_floor() and _flat(face, player.global_position).dot(along) < -TombLayout.SAND_PILE * TombLayout.SAND_SKIRT + 0.6:
			tally["sand_down"] += 1
			_still()
			return true
	print("    not down the sand: he is at %s, state %d" % [player.global_position, player.state])
	return false


# Over the pit on the hook: throws it at the ring, pumps the swing, and lets go at the front of it.
func _swing3(link: TombPlan.Link, forward: bool) -> bool:
	var gap: Array = layout3.ways[link.id]["gap"]
	var way := _along(link) * (1.0 if forward else -1.0)
	var from: Vector3 = (gap[0] if forward else gap[1]) - way * 0.7
	var far: Vector3 = gap[1] if forward else gap[0]
	if player.carried == null or not player.carried.is_in_group(&"grapples"):
		return false
	for attempt in 3:
		if not await _go3(from, 0.2):
			return false
		touch.move = _stick(way, 0.3)
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
			var angle := rad_to_deg(atan2(hold.dot(way), -hold.y))
			var going := player.velocity.dot(way)
			touch.move = _stick(way * (signf(going) if absf(going) > 0.2 else 1.0), 1.0)
			if signf(angle) != side and absf(angle) > 0.5:
				peaks += 1
				side = signf(angle)
			if peaks >= 4 and going > 0.0 and angle > 22.0 and before <= 22.0:
				break
			before = angle
			await _wait(1)
		touch.move = _stick(way, 1.0)
		touch.jump_held = true
		player._queue_jump()
		for i in 240:
			touch.move = _stick(way, 1.0)
			await _wait(1)
			if player.is_on_floor():
				break
		touch.jump_held = false
		_still()
		# (he comes down hard, and the hook is wound in)
		await _wait(150)
		if _flat(far, player.global_position).dot(way) > 0.0 and not player.is_limp and absf(player.global_position.y - far.y) < 1.0:
			return true
		await _wait(200)
	return false


# Air cut through air, and anything standing in stone: what a tomb that is
# walked through could get wrong that one seen from the side could not.
func _overlaps3(layout: TombLayout3D) -> PackedStringArray:
	var wrong: PackedStringArray = []
	if not layout.wrong.is_empty():
		wrong.append("its cells were refused: %s" % layout.wrong[0])
	for i in layout.areas.size():
		var one := layout.areas[i]
		for j in range(i + 1, layout.areas.size()):
			var other := layout.areas[j]
			if one.x0 < other.x1 - 0.001 and other.x0 < one.x1 - 0.001 and one.z0 < other.z1 - 0.001 and other.z0 < one.z1 - 0.001 \
					and one.floor < other.ceil - 0.001 and other.floor < one.ceil - 0.001:
				wrong.append("rooms %d and %d: two pieces of air are cut through each other at %.1f, %.1f" % [one.room, other.room, maxf(one.x0, other.x0), maxf(one.z0, other.z0)])
				break
	for part in layout.parts:
		if part["kind"] not in ["item", "block", "plate", "lever", "offering", "brazier", "treasure", "mummy", "check", "ladder", "prop", "pillar", "torch"]:
			continue
		var at: Vector3 = part["at"]
		var inside := false
		for area in layout.areas:
			if at.x > area.x0 - 0.06 and at.x < area.x1 + 0.06 and at.z > area.z0 - 0.06 and at.z < area.z1 + 0.06 and at.y > area.floor - 0.06 and at.y < area.ceil:
				inside = true
				break
		if not inside:
			wrong.append("room %d: a %s at %s is in the stone" % [part["room"], part["kind"], at])
	# Every place on his lines is somewhere he can stand.
	for n in layout.walk_points.size():
		var at := layout.walk_points[n]
		var stood := false
		for area in layout.areas:
			if at.x >= area.x0 and at.x <= area.x1 and at.z >= area.z0 and at.z <= area.z1 and absf(at.y - area.floor) < 0.05 and not area.deadly:
				stood = true
				break
		for box: Array in layout.boxes:
			if box[2] == "loft" and absf(at.y - ((box[0] as Vector3).y + (box[1] as Vector3).y * 0.5)) < 0.05:
				stood = true
		if not stood:
			wrong.append("room %d: a place on his line at %s has no floor under it" % [layout.walk_rooms[n], at])
	return wrong


# Shut doors, jumped at from both sides (a door that opens only from within is
# come to from behind while it is shut, in a tomb that branches): he must get
# no higher than a jump takes him, and not through.
func _doors_hold() -> void:
	print("DOORS: every shut door of a few tombs, jumped at from in front and from behind")
	TombLevel.bare = true
	var tried := 0
	var held := 0
	for seed_value: int in drive_seeds:
		for difficulty: int in drive_difficulties:
			await _open(seed_value, difficulty)
			for link in level.plan.links:
				# (not a door with a loft's cutting over it: the floor over that one is somewhere he may be)
				if not level.built.doors.has(link.id) or (level.built.doors[link.id] as TombParts.Door).height < 0.0:
					continue
				var door: Vector3 = layout3.door_at[link.id]
				var along := _along(link)
				for side: float in [-1.0, 1.0]:
					var spot := door - along * side * 1.3
					var under := _ray(spot, spot + Vector3.DOWN * 5.0)
					if under.is_empty():
						continue
					var foot: Vector3 = under["position"]
					player.state = Player.State.FREE
					player.global_position = foot + Vector3.UP * 0.05
					player.velocity = Vector3.ZERO
					level._player.set_spawn(foot + Vector3.UP * 0.05)
					await _wait(20)
					var highest := -INF
					var through := false
					for i in 420:
						touch.move = _stick(along * side, 1.0)
						touch.jump_held = i % 23 < [14, 4, 22][(i / 23) % 3]
						if i % 23 == 0 or i % 23 == 9 or (not player.is_on_floor() and i % 5 == 0):
							player._queue_jump()
						if player.state == Player.State.HANG and i % 10 == 0:
							player._queue_jump()
						await _wait(1)
						highest = maxf(highest, player.global_position.y)
						if OS.has_environment("TOMB_TRACE") and i % 4 == 0:
							print("      door %d side %.0f: at %s state %d floor %s (door %s, foot %s)" % [link.id, side, player.global_position, player.state, player.is_on_floor(), door, foot])
						through = through or _flat(door, player.global_position).dot(along * side) > 0.6
					_still()
					tried += 1
					var shut: bool = not (level.built.doors[link.id] as TombParts.Door).is_open
					# (a jump, and a kick off the side of the doorway, take his feet no higher than this)
					if highest < foot.y + 2.5 and not through and shut:
						held += 1
					else:
						print("  seed %d %s, the door on link %d (%s), from %s: his feet got %.2f m up, through it: %s, it stayed shut: %s" % [seed_value, TombGenerator.DIFFICULTY_NAMES[difficulty],
								link.id, link.hint, "in front" if side > 0.0 else "behind", highest - foot.y, through, shut])
			level.get_parent().queue_free()
			await _wait(5)
	print("  held %d of %d" % [held, tried])
	if held < tried:
		failed = true


# A plan whose rooms were given cells: the rules pass it, and refuse it broken; and it is built and played.
func _grid() -> void:
	print("GRID: a plan given its cells, with a side chamber and a way that closes a loop")
	var plan: TombPlan = Shapes.branching()
	var said := TombLayout3D.cells_wrong(plan)
	print("  the plan as it is: %s; the solver: %s (%d steps, %d positions)" % ["its cells pass" if said.is_empty() else "REFUSED %s" % said, "it can be finished" if plan.proof["ok"] else "IT CANNOT (%s)" % plan.proof["reason"], plan.solution.size(), plan.proof["positions"]])
	if not said.is_empty() or not plan.proof["ok"]:
		failed = true
	# Broken four ways: each must be refused.
	var breaks: Array = [
		["two rooms on one square", func(broken: TombPlan) -> void: broken.rooms[5].cell = broken.rooms[4].cell],
		["a way between squares that do not touch", func(broken: TombPlan) -> void: broken.rooms[6].cell = Vector3i(6, 2, 0)],
		["stairs that go nowhere down", func(broken: TombPlan) -> void: broken.rooms[1].cell = Vector3i(1, 0, 0)],
		["a level doorway between two levels", func(broken: TombPlan) -> void: broken.rooms[5].cell = Vector3i(3, 2, 1)],
	]
	for entry: Array in breaks:
		var broken: TombPlan = Shapes.branching()
		(entry[1] as Callable).call(broken)
		var found := TombLayout3D.cells_wrong(broken)
		print("  %-42s %s" % [entry[0], "refused (%s)" % found[0] if not found.is_empty() else "WRONGLY PASSED"])
		if found.is_empty():
			failed = true
	var layout := TombLayout3D.set_out(plan)
	var wrong := TombReach.check(layout, TombReach.measure())
	wrong.append_array(_overlaps3(layout))
	var kept := true
	for room in plan.rooms:
		kept = kept and layout.cells[room.id] == room.cell
	print("  set out: %d pieces of air, %d of stone, %.0f m of floor; its cells %s; %s" % [layout.areas.size(), layout.boxes.size(), layout.length,
			"are the plan's own" if kept else "WERE NOT KEPT", "sound" if wrong.is_empty() else "FAULTS %s" % wrong])
	if not wrong.is_empty() or not kept:
		failed = true
	if not walked:
		print("  (not played: that is asked for with 3d)")
		return
	TombLevel.bare = true
	await _open(0, 0, {}, plan)
	tomb_name = "grid"
	var done := await _play_through("the plan with a loop")
	level.get_parent().queue_free()
	await _wait(5)
	if not done:
		failed = true


# The sand, in the tomb that is walked through: there its chamber has walls
# beside the face, and a kick off a wall takes him higher than a jump. Before
# it is let in he throws himself at the face for ten seconds, and then at each
# corner of the chamber by the face for ten more, kicking off the one wall
# and steering at the other, and must not get up it; then the heap is timed;
# then he dies, and the heap must be as it was; then the tomb is played through.
func _sand_holds3() -> bool:
	await _open(0, 0, only_sand())
	var link := level.plan.spine_link(1)
	var way := layout3.ways[link.id]
	var along := _along(link)
	var across := Vector3(-along.z, 0.0, along.x)
	var face: Vector3 = way["face"]
	var top: float = (way["top"] as Vector3).y
	var fall: SandFall = level.built.sands[link.id]
	var block := _block_for(-1, link.switches[0])
	var sound := true
	if not await _go3(way["before"]):
		print("  the sand: he could not get to the foot of the face")
		sound = false
	var half := TombLayout3D.PASSAGE * 0.5 + TombLayout3D.SAND_SIDE
	var highest := -INF
	var presses := 0
	var kicks := [0]
	player.kicked_off.connect(func() -> void: kicks[0] += 1)
	# [where he starts from, what he steers at before a jump, and after one]: the face head on, then each corner.
	var tries: Array = [[face - along * 2.5, along, along]]
	for side: float in [-1.0, 1.0]:
		var corner := face + across * (side * half - TombLayout3D.WALK)
		tries.append([corner - along * 2.2 - across * side * 2.2, (along + across * side).normalized(), (along - across * side * 0.6).normalized()])
		tries.append([corner - along * 0.6 - across * side * 2.6, across * side, (along * 2.0 - across * side).normalized()])
	for attempt: Array in tries:
		if await _leg(attempt[0]) != ARRIVED:
			print("  the sand: he could not get to %s to try the face from" % attempt[0])
			sound = false
		for i in 600:
			var airborne := not player.is_on_floor() and player.state == Player.State.FREE
			touch.move = _stick(attempt[2] if airborne and i % 46 > 30 else attempt[1], 1.0)
			touch.jump_held = i % 23 < [14, 4, 22][(i / 23) % 3]
			# (every way of pressing jump: on the ground, and again and again in the air against whatever wall is there)
			if i % 23 == 0 or i % 23 == 9 or i % 23 == 15 or (airborne and i % 5 == 0):
				player._queue_jump()
				presses += 1
			if player.state == Player.State.HANG and i % 10 == 0:
				player._queue_jump()
			await _wait(1)
			highest = maxf(highest, player.global_position.y)
		_still()
		await _wait(60)
	var foot: float = face.y
	var bare := highest < top - 0.3 and player.global_position.y < top - 1.0 and not level.done[link.switches[0]]
	print("  the sand, before it is let in: %d presses of jump at a face of %.2f, head on and at both its corners (%d of them kicks off a wall), got his feet %.2f up it: %s" % [
			presses, TombLayout.SAND_RISE, kicks[0], highest - foot, "it holds him" if bare else "HE GOT UP IT"])
	sound = sound and bare
	await _shot("sand_face_bare")
	if not await _push3(block, link.switches[0]):
		print("  the sand: the block was not got onto its plate")
		sound = false
	var began := frames_used
	var over := await _sand_up3(link)
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
	level.give_up()
	await _wait(180)
	var now := fall.pile.height if fall.pile else 0.0
	print("  the sand, after he has died (%d): the heap is %.2f high: %s" % [level.deaths, now, "it stays" if is_equal_approx(now, was) and level.deaths == 1 else "IT WAS EMPTIED"])
	sound = sound and is_equal_approx(now, was)
	var done := await _play_through("the sand")
	level.get_parent().queue_free()
	await _wait(5)
	return sound and done


# What is kept of a day's tomb seen from the side and of the same tomb walked
# through must not run together. (Kept in a file of its own for the test: the
# player's is not touched.)
func _kept() -> void:
	print("KEPT: a day's tomb finished each way")
	var was := TombDaily.path
	TombDaily.path = "user://tombs_test.json"
	DirAccess.remove_absolute(TombDaily.path)
	var day := 30000
	var run := {"mode": "daily", "view": "side", "day": day, "seed": 1, "difficulty": 1, "time_ms": 60000, "deaths": 0}
	var first := TombDaily.keep(run)
	run["view"] = "3d"
	run["time_ms"] = 90000
	var second := TombDaily.keep(run)
	run["time_ms"] = 80000
	run["deaths"] = 2
	var third := TombDaily.keep(run)
	var side := TombDaily.day_record(day, "side")
	var through := TombDaily.day_record(day, "3d")
	var apart := int(side.get("best_ms", 0)) == 60000 and int(side.get("runs", 0)) == 1 and int(through.get("best_ms", 0)) == 80000 \
			and int(through.get("first_ms", 0)) == 90000 and int(through.get("runs", 0)) == 2 and int(through.get("best_deaths", -1)) == 2
	var firsts: bool = first["first"] and second["first"] and not third["first"] and third["best"]
	# (one run of days, whichever way: the same day twice is one day, and the next day by the other way goes on from it)
	var one_day: bool = int(first["streak"]) == 1 and int(second["streak"]) == 1
	run["day"] = day + 1
	var next := TombDaily.keep(run)
	var runs_on: bool = int(next["streak"]) == 2
	var practice := {"mode": "random", "view": "side", "day": 0, "seed": 5, "difficulty": 1, "time_ms": 50000, "deaths": 0}
	TombDaily.keep(practice)
	practice["view"] = "3d"
	practice["time_ms"] = 70000
	var walked_first: bool = TombDaily.keep(practice)["best"]
	var bests: Dictionary = TombDaily.load_all()["random_best"]
	var practice_apart := int(bests.get("5:1", 0)) == 50000 and int(bests.get("5:1:3d", 0)) == 70000 and walked_first
	var said := TombDaily.share_text(run)
	var says := "walked through" in said and not "walked through" in TombDaily.share_text({"mode": "daily", "day": day, "time_ms": 1, "deaths": 0})
	DirAccess.remove_absolute(TombDaily.path)
	TombDaily.path = was
	print("  the day's times %s; each has its own first and best: %s; the run of days counts a day once (%s) and goes on (%s); practice bests %s; the line to send says which (\"%s\"): %s" % [
			"are kept apart" if apart else "RAN TOGETHER", firsts, one_day, runs_on, "are kept apart" if practice_apart else "RAN TOGETHER", said, says])
	_kept_branching()
	if not (apart and firsts and one_day and runs_on and practice_apart and says):
		failed = true


# Dying, in the tomb that is walked through: he starts again at the last door
# he went through, across the room from wherever he went through it, and what
# he was carrying is back there where he last had it.
func _carried_back3() -> bool:
	await _open(0, 0, three_new())
	var plan := level.plan
	var torch: RigidBody3D = level.built.items[0]
	var sound := await _do_step3(["take", 0])
	var door: Vector3 = layout3.rooms[1]["west"]
	# (down the stairs and into the next room, on the far side of it from his line)
	sound = await _go3(door + Vector3(0.0, 0.0, 0.0)) and sound
	var across := Vector3(-_along(plan.spine_link(0)).z, 0.0, _along(plan.spine_link(0)).x)
	sound = await _leg(door + across * 2.6) == ARRIVED and sound
	var on := Vector3(TombLayout3D.TURNS[int(layout3.rooms[1]["turn"])])
	await _leg(door + across * 2.6 + on * 3.0)
	var had := player.carried == torch
	level.give_up()
	await _wait(150)
	var back := _flat(player.global_position, door).length() < 1.0 and absf(player.global_position.y - door.y) < 0.5
	var lies := _flat(torch.global_position, door).length() < 1.5 and player.carried == null
	print("  dying with a torch in his hand, three metres past a door he went through at the far wall: he had it %s, deaths %d, he is back at that door: %s, and the torch is there: %s" % [
			had, level.deaths, back, lies])
	var once := level.deaths == 1
	level.get_parent().queue_free()
	await _wait(5)
	return sound and had and back and lies and once


# --- Tombs that branch: what is kept of a day, and the map

# A day's tomb that branches is a third tomb for the day: what is kept of it
# is apart from the other two, in a file that was written before there was
# such a thing as well as in a new one. (In a file of its own for the test.)
func _kept_branching() -> void:
	var was := TombDaily.path
	TombDaily.path = "user://tombs_test.json"
	# A file as it was kept before: two days seen from the side, one walked through, a run of days, a practice best.
	var file := FileAccess.open(TombDaily.path, FileAccess.WRITE)
	file.store_string(JSON.stringify({"version": 1, "days": {"29998": {"first_ms": 71000, "first_deaths": 1, "best_ms": 70000, "best_deaths": 0, "runs": 2},
			"29999": {"first_ms": 61000, "first_deaths": 0, "best_ms": 61000, "best_deaths": 0, "runs": 1}},
			"days_3d": {"29999": {"first_ms": 95000, "first_deaths": 3, "best_ms": 95000, "best_deaths": 3, "runs": 1}},
			"streak": {"last": 29999, "length": 2, "best": 5}, "random_best": {"5:1": 50000, "5:1:3d": 70000}}))
	file.close()
	var day := 30000
	var run := {"mode": "daily", "view": "3d", "shape": "branching", "day": day, "seed": 1, "difficulty": 1, "time_ms": 120000, "deaths": 4,
			"plan": "p", "stone": "s", "ticks": 7200, "goal_ms": 60000, "splits": []}
	var first := TombDaily.keep(run)
	run["time_ms"] = 110000
	run["deaths"] = 1
	var second := TombDaily.keep(run)
	var through := run.duplicate()
	through["shape"] = "line"
	through["time_ms"] = 90000
	var walked_too := TombDaily.keep(through)
	var kept := TombDaily.load_all()
	var branching := TombDaily.day_record(day, "3d", "branching")
	var own: bool = int(branching.get("first_ms", 0)) == 120000 and int(branching.get("best_ms", 0)) == 110000 and int(branching.get("best_deaths", -1)) == 1 and int(branching.get("runs", 0)) == 2 \
			and first["first"] and not second["first"] and second["best"]
	var apart: bool = int(TombDaily.day_record(day, "3d").get("best_ms", 0)) == 90000 and walked_too["first"] and TombDaily.day_record(day, "side").is_empty() \
			and TombDaily.day_record(day, "side", "branching") == branching
	var old: bool = int(kept["days"]["29998"]["best_ms"]) == 70000 and int(kept["days"]["29998"]["runs"]) == 2 and int(kept["days"]["29999"]["best_ms"]) == 61000 and (kept["days"] as Dictionary).size() == 2 \
			and int(kept["days_3d"]["29999"]["best_ms"]) == 95000 and (kept["days_3d"] as Dictionary).size() == 2
	# (the day after the last kept: the run of days goes on from it, once, whichever of the three it was)
	var runs_on: bool = int(first["streak"]) == 3 and int(second["streak"]) == 3 and int(walked_too["streak"]) == 3 and int(kept["streak"]["best"]) == 5
	var practice := {"mode": "random", "view": "3d", "shape": "branching", "day": 0, "seed": 5, "difficulty": 1, "time_ms": 99000, "deaths": 0}
	var practice_first: bool = TombDaily.keep(practice)["best"]
	var bests: Dictionary = TombDaily.load_all()["random_best"]
	var practice_apart: bool = practice_first and int(bests.get("5:1", 0)) == 50000 and int(bests.get("5:1:3d", 0)) == 70000 and int(bests.get("5:1:branching", 0)) == 99000
	var said := TombDaily.share_text(run)
	var sent := TombDaily.submission(run)
	var plain := TombDaily.submission(through)
	var says: bool = "branching" in said and not "walked through" in said and sent.get("shape", "") == "branching" and int(sent["generator"]) == TombBranching.VERSION \
			and not plain.has("shape") and int(plain["generator"]) == TombGenerator.VERSION
	DirAccess.remove_absolute(TombDaily.path)
	TombDaily.path = was
	print("  the day's tomb that branches: it has its own first and best: %s; the other two are as they were: %s; days kept before it are not disturbed: %s; one run of days: %s; practice bests %s; the line to send (\"%s\") and the record say which: %s" % [
			own, apart, old, runs_on, "are kept apart" if practice_apart else "RAN TOGETHER", said, says])
	if not (own and apart and old and runs_on and practice_apart and says):
		failed = true


# The map on the HUD. In a tomb that branches it is there, and as the tomb is
# played through by the solver's way it shows the rooms he has stood in and no
# others, a way once he has been at one end of it, and a bar on every way whose
# door is still shut and on none that is open. A touch makes it large, and
# another small. A tomb down one axis has no map.
func _map_shows() -> void:
	print("MAP: the map of a tomb that branches, as it is played through")
	var asked := [branch, walked]
	branch = true
	walked = true
	TombLevel.bare = true
	var sound := true
	for tomb: Array in [[1, 2], [3, 1]]:
		await _open(tomb[0], tomb[1])
		var plan := level.plan
		var map := level._map
		if map == null:
			print("  seed %d: THERE IS NO MAP" % tomb[0])
			failed = true
			level.get_parent().queue_free()
			await _wait(5)
			continue
		await _wait(10)
		var start := TombMap.shown(layout3, level._seen, level._open)
		var only_court: bool = start["rooms"] == [plan.entrance()] and (start["ways"] as Array).size() == 1 and not start["ways"][0][1]
		var wrong := 0
		var barred_most := 0
		var opened := {}
		var was_barred := {}
		var stopped := ""
		for i in plan.solution.size():
			if not await _do_step(plan.solution[i]):
				stopped = "step %d (%s)" % [i + 1, TombSolver.words(plan, plan.solution[i])]
				break
			await _wait(3)
			var what := TombMap.shown(layout3, level._seen, level._open)
			# (what the map shows, held against what the level knows by other means)
			for room in plan.rooms:
				if TombLayout3D.is_side(room):
					continue
				if (room.id in what["rooms"]) != (level.splits[room.id] != -1):
					wrong += 1
			var barred := 0
			for way: Array in what["ways"]:
				var link := plan.links[int(way[0])]
				var done := true
				for id in link.switches:
					done = done and level.done[id]
				if bool(way[1]) != (level.splits[link.a] != -1 and level.splits[link.b] != -1) or bool(way[2]) != (not link.switches.is_empty() and not done):
					wrong += 1
				if way[2]:
					barred += 1
					was_barred[link.id] = true
				elif was_barred.has(link.id):
					opened[link.id] = true
			barred_most = maxi(barred_most, barred)
			if map.here != level._room or not (map.here in what["rooms"] or TombLayout3D.is_side(plan.rooms[map.here])):
				wrong += 1
		var rooms_seen := (TombMap.shown(layout3, level._seen, level._open)["rooms"] as Array).size()
		# A touch makes it large, and another small again.
		var small := map.size
		var touch_down := InputEventScreenTouch.new()
		touch_down.pressed = true
		map._gui_input(touch_down)
		await _wait(3)
		var large := map.size
		map._gui_input(touch_down)
		await _wait(3)
		var toggles: bool = large.x > small.x * 2.0 and map.size.is_equal_approx(small) and not map.large
		print("  seed %d %s: at the start the court alone, and its one way a stub: %s; played %s: %d rooms of %d on squares stood in and on the map, at most %d doors barred at once, %d seen shut and later open; what it showed that it should not, or did not that it should: %d; a touch makes it large and another small: %s" % [
				tomb[0], TombGenerator.DIFFICULTY_NAMES[tomb[1]], only_court, "through" if stopped == "" else "as far as " + stopped, rooms_seen, layout3.placed().size(), barred_most, opened.size(), wrong, toggles])
		sound = sound and only_court and stopped == "" and wrong == 0 and toggles and barred_most > 0 and opened.size() > 0
		level.get_parent().queue_free()
		await _wait(5)
	# A tomb down one axis, walked through, has none; a plan handed over with its cells has.
	branch = false
	await _open(1, 1)
	var none := level._map == null
	level.get_parent().queue_free()
	await _wait(5)
	await _open(0, 0, {}, Shapes.branching())
	var given := level._map != null
	level.get_parent().queue_free()
	await _wait(5)
	branch = asked[0]
	walked = asked[1]
	print("  a tomb down one axis, walked through, has no map: %s; a plan that came with its cells has: %s" % [none, given])
	if not (sound and none and given):
		failed = true
