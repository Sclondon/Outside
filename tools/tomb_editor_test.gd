extends SceneTree
## Not part of the game. Checks tombs made by hand (`TombSpec`) and the tomb
## editor that makes them, with nothing drawn.
## godot --headless --path . --fixed-fps 60 --script tools/tomb_editor_test.gd -- [seeds=60] [fuzz=400]
##
##  - the tomb a new one starts as can be built and finished;
##  - every generated tomb (seeds 1 to `seeds`, each difficulty) taken into the
##    editor's form and made into a plan again can still be finished, and has
##    as many rooms, doors and things as it had;
##  - `fuzz` tombs put together at random (every way and every lock the editor
##    offers, the two-plate door, the rope and the sand among them): whichever
##    of them `problems` lets through is laid out and solved without a script
##    error, and its rope and its sand are ones he can use;
##  - what `problems` is there to refuse is refused;
##  - a tomb comes back from text as it went;
##  - the editor itself: opened, a room added, changed, moved and removed,
##    undone, and a tomb played from it and finished by the solver's way.
## Ends with PASSED or FAILED.

var seeds := 60
var fuzz := 400
var failed := false


func _initialize() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("seeds="):
			seeds = int(arg.trim_prefix("seeds="))
		elif arg.begins_with("fuzz="):
			fuzz = int(arg.trim_prefix("fuzz="))
	_run.call_deferred()


func expect(what: bool, said: String) -> void:
	if not what:
		failed = true
		print("WRONG: ", said)


func _run() -> void:
	_fresh()
	_generated()
	_fuzzed()
	_refused()
	_text()
	await _editor()
	_floor_specs()
	await _floor_editor()
	print("FAILED" if failed else "PASSED")
	quit(1 if failed else 0)


func _fresh() -> void:
	var found := TombSpec.check(TombSpec.fresh())
	expect((found["problems"] as PackedStringArray).is_empty(), "a new tomb has problems: %s" % str(found["problems"]))
	expect(found["ok"], "a new tomb cannot be finished: %s" % found["says"])
	print("fresh: ", found["says"])


func _generated() -> void:
	var sound := 0
	var total := 0
	for difficulty in 3:
		for seed_value in range(1, seeds + 1):
			total += 1
			var plan := TombGenerator.generate(seed_value, difficulty)
			var spec := TombSpec.from_plan(plan)
			var found := TombSpec.check(spec)
			if not (found["problems"] as PackedStringArray).is_empty():
				expect(false, "seed %d:%d taken into the editor has problems: %s" % [seed_value, difficulty, str(found["problems"])])
				continue
			var again: TombPlan = found["plan"]
			expect(again.rooms.size() == plan.rooms.size(), "seed %d:%d: %d rooms became %d" % [seed_value, difficulty, plan.rooms.size(), again.rooms.size()])
			expect(again.things.size() == plan.things.size(), "seed %d:%d: %d things became %d" % [seed_value, difficulty, plan.things.size(), again.things.size()])
			expect(again.triggers.size() == plan.triggers.size(), "seed %d:%d: %d switches became %d" % [seed_value, difficulty, plan.triggers.size(), again.triggers.size()])
			expect(found["ok"], "seed %d:%d taken into the editor: %s" % [seed_value, difficulty, found["says"]])
			expect((found["warnings"] as PackedStringArray).is_empty(), "seed %d:%d: %s" % [seed_value, difficulty, str(found["warnings"])])
			if found["ok"]:
				sound += 1
	print("generated: %d of %d come back sound" % [sound, total])


func _fuzzed() -> void:
	var rng := TombRandom.new(90210)
	var let_through := 0
	var finishable := 0
	var reach := TombReach.measure()
	var had := {"pair": 0, "rope": 0, "sand": 0}
	var sound := {"pair": 0, "rope": 0, "sand": 0}
	for n in fuzz:
		var spec := TombSpec.fresh("Fuzz %d" % n)
		spec["seed"] = rng.between(1, 9999)
		var rooms: Array = [TombSpec.room("entrance")]
		rooms[0]["way"] = ["open", "stairs"][rng.below(2)]
		var middle := rng.between(1, 8)
		for i in middle:
			var told := TombSpec.room(TombSpec.MIDDLE_ROLES[rng.below(TombSpec.MIDDLE_ROLES.size())])
			told["dark"] = rng.chance(30)
			told["pit"] = rng.chance(25)
			told["mummy"] = rng.between(0, 5) if rng.chance(35) else -1
			told["barrier"] = ["auto", "auto", "trench", "kerb", "narrow"][rng.below(5)]
			for what: String in TombSpec.THINGS:
				told[what] = 1 if rng.chance(25) else 0
			told["way"] = TombSpec.WAYS[rng.below(TombSpec.WAYS.size())]
			told["lock"] = TombSpec.LOCKS[rng.below(TombSpec.LOCKS.size())] if rng.chance(60) else "none"
			told["stone_in"] = rng.between(1, i + 1)
			rooms.append(told)
		for what: String in TombSpec.THINGS:
			rooms[0][what] = 1 if rng.chance(40) else 0
		var burial := TombSpec.room("burial")
		burial["mummy"] = rng.between(0, 5) if rng.chance(50) else -1
		rooms.append(burial)
		spec["rooms"] = rooms
		var found := TombSpec.check(spec)
		if (found["problems"] as PackedStringArray).is_empty():
			let_through += 1
			expect(found["layout"] != null and (found["layout"] as TombLayout).length > 0.0, "fuzz %d was not laid out" % n)
			if found["ok"]:
				finishable += 1
			var has := {}
			for told: Dictionary in rooms.slice(0, rooms.size() - 1):
				if told["lock"] == "pair":
					has["pair"] = true
				if told["way"] in ["rope", "sand"] and told["lock"] != "bypass":
					has[told["way"]] = true
			for what: String in has:
				had[what] += 1
				if found["ok"]:
					sound[what] += 1
			# (what a mummy is held by is chosen at random here, and may not hold it: that is not looked at)
			for warning: String in found["warnings"]:
				expect(not ("rope" in warning or "sand" in warning or "face" in warning), "fuzz %d: %s" % [n, warning])
			var moves := {}
			for move in (found["layout"] as TombLayout).moves:
				moves[move["kind"]] = true
			expect(moves.has("rope") == has.has("rope") and moves.has("sand") == has.has("sand"), "fuzz %d: its rope or its sand was not laid out" % n)
	print("fuzz: %d of %d let through, %d of them can be finished" % [let_through, fuzz, finishable])
	print("      of those let through, with a two-plate door %d (%d can be finished), a rope %d (%d), the sand %d (%d)" % [had["pair"], sound["pair"], had["rope"], sound["rope"], had["sand"], sound["sand"]])
	for what: String in had:
		expect(int(sound[what]) > 0, "no random tomb with %s can be finished" % what)
	expect(let_through > fuzz / 20, "hardly any random tomb is let through")
	expect(finishable > 0, "no random tomb can be finished")


func _refused() -> void:
	var spec := TombSpec.fresh()
	spec["rooms"][1]["way"] = "crawl"
	spec["rooms"][1]["lock"] = "work"
	expect(not TombSpec.problems(spec).is_empty(), "a locked crawl was let through")
	spec = TombSpec.fresh()
	spec["rooms"][1]["lock"] = "cross"
	expect(not TombSpec.problems(spec).is_empty(), "a plate with no room before it for its block was let through")
	spec = TombSpec.fresh()
	spec["rooms"][2]["lock"] = "lever_below"
	spec["rooms"][2]["stone_in"] = 1
	expect(not TombSpec.problems(spec).is_empty(), "a seal stone under a room that is no well was let through")
	spec["rooms"][1]["role"] = "well"
	expect(TombSpec.problems(spec).is_empty(), "a seal stone under a well was refused: %s" % str(TombSpec.problems(spec)))
	expect(TombSpec.check(spec)["ok"], "a seal stone under a well cannot be finished")
	spec = TombSpec.fresh()
	spec["rooms"].pop_back()
	spec["rooms"].pop_back()
	expect(not TombSpec.problems(spec).is_empty(), "a tomb of two rooms was let through")
	# The two-plate door, the rope and the sand: what cannot be built, and that what can is sound.
	spec = TombSpec.fresh()
	spec["rooms"][1]["lock"] = "pair"
	expect(not TombSpec.problems(spec).is_empty(), "two plates with no room before for the second block were let through")
	spec = TombSpec.fresh()
	spec["rooms"].insert(1, TombSpec.room("corridor"))
	spec["rooms"][2]["lock"] = "pair"
	expect(TombSpec.problems(spec).is_empty(), "a two-plate door was refused: %s" % str(TombSpec.problems(spec)))
	expect(TombSpec.check(spec)["ok"], "a two-plate door cannot be finished")
	expect(JSON.stringify(TombSpec.from_plan(TombSpec.compile(spec))["rooms"]) == JSON.stringify(spec["rooms"]), "a two-plate door did not come back from its plan as it went")
	spec["rooms"][1]["way"] = "stairs"
	expect(not TombSpec.problems(spec).is_empty(), "two plates were let through with stairs between the block and its plate")
	spec = TombSpec.fresh()
	spec["rooms"][1]["way"] = "rope"
	expect(TombSpec.problems(spec).is_empty() and TombSpec.check(spec)["ok"], "a rope down a shaft was refused, or cannot be finished")
	spec["rooms"][1]["lock"] = "work"
	expect(not TombSpec.problems(spec).is_empty(), "a door at the head of a rope was let through")
	# (the hook can be dropped down a rope with, and not brought back up for the pit)
	spec = TombSpec.fresh()
	spec["rooms"].insert(1, TombSpec.room("corridor"))
	spec["rooms"][0]["hook"] = 1
	spec["rooms"][1]["way"] = "gap"
	spec["rooms"][2]["way"] = "rope"
	var lost := TombSpec.check(spec)
	expect((lost["problems"] as PackedStringArray).is_empty() and not lost["ok"] and lost["solved"]["reason"] == "it can be made unfinishable", "a rope beyond a pit, that the hook can be lost down, was called sound")
	spec = TombSpec.fresh()
	spec["rooms"][1]["way"] = "sand"
	expect(TombSpec.problems(spec).is_empty() and TombSpec.check(spec)["ok"], "a way up the sand was refused, or cannot be finished")
	expect(TombSpec.compile(spec).links[1].hint == "sand", "the sand with no lock has no seal stone at its foot")
	expect(JSON.stringify(TombSpec.from_plan(TombSpec.compile(spec))["rooms"]) == JSON.stringify(spec["rooms"]), "a way up the sand did not come back from its plan as it went")
	spec["rooms"][1]["lock"] = "lever_above"
	spec["rooms"][1]["stone_in"] = 1
	expect(not TombSpec.problems(spec).is_empty(), "a loft at the foot of the sand's face was let through")
	spec["rooms"][1]["lock"] = "bypass"
	expect(not TombSpec.problems(spec).is_empty(), "a way over the wall and up the sand at once was let through")
	spec["rooms"][1]["lock"] = "work"
	expect(TombSpec.problems(spec).is_empty() and TombSpec.check(spec)["ok"], "sand let in by a block on its plate was refused, or cannot be finished")
	spec = TombSpec.fresh()
	spec["rooms"].insert(1, TombSpec.room("corridor"))
	spec["rooms"][2]["way"] = "sand"
	spec["rooms"][2]["lock"] = "lever_above"
	spec["rooms"][2]["stone_in"] = 1
	expect(TombSpec.problems(spec).is_empty() and TombSpec.check(spec)["ok"], "sand let in from a loft over the room before was refused, or cannot be finished")
	expect(TombSpec.compile(spec).links[2].hint == "sand_above", "sand let in from a loft is not said to be")
	spec = TombSpec.fresh()
	spec["rooms"].insert(1, TombSpec.room("corridor"))
	spec["rooms"][1]["way"] = "sand"
	spec["rooms"][2]["mummy"] = 4
	expect(not TombSpec.problems(spec).is_empty(), "a mummy at the top of the sand was let through")
	# A brazier and no torch: it is built, and said not to be sound.
	spec = TombSpec.fresh()
	spec["rooms"][1]["lock"] = "brazier"
	var found := TombSpec.check(spec)
	expect((found["problems"] as PackedStringArray).is_empty() and not found["ok"], "a brazier with no torch to light it was called sound")
	spec["rooms"][0]["torch"] = 1
	expect(TombSpec.check(spec)["ok"], "a brazier with a torch at the door cannot be finished")


func _text() -> void:
	var spec := TombSpec.from_seed(7, 2)
	var back := TombSpec.from_text(TombSpec.to_text(spec))
	expect(not back.is_empty(), "a tomb did not come back from text")
	expect(TombSpec.to_text(back) == TombSpec.to_text(spec), "a tomb came back from text changed")
	expect(TombSpec.compile(back).describe() == TombSpec.compile(spec).describe(), "its plan came back from text changed")
	expect(TombSpec.from_text("not a tomb").is_empty(), "nonsense was taken for a tomb")
	expect(TombSpec.from_text("{\"rooms\": 4}").is_empty(), "nonsense was taken for a tomb")


func _editor() -> void:
	var scene := (load("res://tomb_editor.tscn") as PackedScene).instantiate()
	var editor := scene as TombEditor
	TombEditor.keeps = false
	root.add_child(scene)
	await process_frame
	await process_frame
	editor.take(TombSpec.fresh("Test tomb"))
	editor.rebuild()
	expect(editor.found["ok"], "the editor's new tomb: %s" % editor.found["says"])
	var before := editor.rooms().size()
	editor.choose(1)
	editor.add_after()
	expect(editor.rooms().size() == before + 1 and editor.chosen == 2, "a room was not added after the chosen one")
	editor.set_value("role", "well")
	editor.set_value("lock", "lever_below")
	expect(editor.rooms()[2]["stone_in"] == 2, "the seal stone was not put under its own well")
	editor.rebuild()
	expect(editor.found["ok"], "a well with its seal stone: %s" % editor.found["says"])
	editor.set_value("lock", "brazier")
	editor.rebuild()
	expect(editor.found["ok"], "the editor did not leave a torch for the brazier it added: %s" % editor.found["says"])
	expect(editor.rooms()[2]["dark"], "the room of a brazier was not made dark")
	editor.set_value("way", "gap")
	editor.rebuild()
	expect(not (editor.found["problems"] as PackedStringArray).is_empty(), "a brazier's door at a pit was let through")
	editor.undo()
	editor.rebuild()
	expect(editor.found["ok"], "undoing did not put it right: %s" % editor.found["says"])
	editor.move(-1)
	expect(editor.chosen == 1 and editor.rooms()[1]["role"] == "well", "the room was not moved earlier")
	editor.move(1)
	editor.copy()
	expect(editor.rooms().size() == before + 2, "the room was not copied")
	editor.remove()
	editor.remove()
	expect(editor.rooms().size() == before, "the rooms were not removed")
	editor.choose(0)
	editor.remove()
	expect(editor.rooms().size() == before, "the entrance was removed")
	# Every frame of it with a full tomb standing, for a while.
	editor.take(TombSpec.from_seed(3, 2))
	editor.rebuild()
	expect(editor.found["ok"], "seed 3 in the editor: %s" % editor.found["says"])
	for i in 30:
		await process_frame
	editor.show_way()
	editor.show_tombs(true)
	await process_frame
	scene.queue_free()
	await process_frame
	print("editor: done")


# --- Tombs that branch: the floor plan

# A spec of a tomb that branches: the one a new one starts as; every one the
# generator makes, taken into the editor's form and back; what is to be
# refused; and what the floor plan does to one.
func _floor_specs() -> void:
	var fresh := TombFloorSpec.fresh()
	var found := TombSpec.check(fresh)
	expect((found["problems"] as PackedStringArray).is_empty(), "a new branching tomb has problems: %s" % str(found["problems"]))
	expect(found["ok"], "a new branching tomb cannot be finished: %s" % found["says"])
	expect(found["layout"] is TombLayout3D and (found["warnings"] as PackedStringArray).is_empty(), "a new branching tomb is not set out sound: %s" % str(found["warnings"]))
	print("floor, fresh: ", found["says"])
	# A tomb down one axis is still what it was: it says nothing of a shape.
	expect(not TombSpec.is_branching(TombSpec.fresh()) and TombSpec.check(TombSpec.fresh())["layout"] is TombLayout and not TombSpec.check(TombSpec.fresh())["layout"] is TombLayout3D, "a tomb down one axis was taken for one that branches")

	var sound := 0
	var total := 0
	for difficulty in 3:
		for seed_value in range(1, seeds + 1):
			total += 1
			var plan := TombBranching.generate(seed_value, difficulty)
			var spec := TombFloorSpec.from_plan(plan)
			var said := TombSpec.check(spec)
			if not (said["problems"] as PackedStringArray).is_empty():
				expect(false, "branching seed %d:%d taken into the editor has problems: %s" % [seed_value, difficulty, str(said["problems"])])
				continue
			var again: TombPlan = said["plan"]
			expect(again.rooms.size() == plan.rooms.size() and again.links.size() == plan.links.size(), "branching seed %d:%d: %d rooms and %d ways became %d and %d" % [seed_value, difficulty, plan.rooms.size(), plan.links.size(), again.rooms.size(), again.links.size()])
			expect(again.things.size() == plan.things.size() and again.triggers.size() == plan.triggers.size(), "branching seed %d:%d: %d things and %d switches became %d and %d" % [seed_value, difficulty, plan.things.size(), plan.triggers.size(), again.things.size(), again.triggers.size()])
			expect((again.solution as Array).size() == (plan.solution as Array).size(), "branching seed %d:%d: its way through was %d steps and is %d" % [seed_value, difficulty, plan.solution.size(), again.solution.size()])
			expect(said["ok"], "branching seed %d:%d taken into the editor: %s" % [seed_value, difficulty, said["says"]])
			expect((said["warnings"] as PackedStringArray).is_empty(), "branching seed %d:%d: %s" % [seed_value, difficulty, str(said["warnings"])])
			var back := TombSpec.from_text(TombSpec.to_text(spec))
			expect(TombSpec.to_text(back) == TombSpec.to_text(spec) and TombSpec.compile(back).describe() == again.describe(), "branching seed %d:%d came back from text changed" % [seed_value, difficulty])
			if said["ok"]:
				sound += 1
	print("floor, generated: %d of %d come back sound" % [sound, total])

	# What the floor plan does. The new tomb is: 1 entrance (0,0), 2 corridor (1,0), 3 antechamber (2,0), 4 burial (3,0), 5 corridor (1,1) off 2.
	var spec := TombFloorSpec.fresh()
	expect(TombFloorSpec.free_sides(spec, 1) == [3], "the free sides of the first corridor are %s, not north alone" % str(TombFloorSpec.free_sides(spec, 1)))
	expect(TombFloorSpec.free_sides(spec, 0).is_empty() and TombFloorSpec.free_sides(spec, 3).is_empty(), "a room could be put off the entrance or the burial chamber")
	expect(TombFloorSpec.add_room(spec, 1, 1) == -1, "a room was put on a square that is taken")
	var added := TombFloorSpec.add_room(spec, 4, 0)
	expect(added == 5 and TombFloorSpec.cell_of(spec["rooms"][5]) == Vector2i(2, 1) and int(spec["rooms"][5]["from"]) == 4, "a room was not added east of the side chamber")
	expect(TombSpec.check(spec)["ok"], "with a room added: %s" % TombSpec.check(spec)["says"])
	# (the new room is beside the antechamber: a second way between them closes a loop)
	expect(TombFloorSpec.join_wrong(spec, 5, 2) == "", "the new room cannot be joined to the antechamber beside it: %s" % TombFloorSpec.join_wrong(spec, 5, 2))
	expect(TombFloorSpec.join_wrong(spec, 5, 4) != "" and TombFloorSpec.join_wrong(spec, 5, 1) != "" and TombFloorSpec.join_wrong(spec, 5, 3) != "", "a second way was allowed to a room it is entered from, to one not beside it, or to the burial chamber")
	expect(TombFloorSpec.join(spec, 5, 2) and (spec["joins"] as Array).size() == 1, "the loop was not closed")
	var looped := TombSpec.check(spec)
	expect(looped["ok"] and (looped["problems"] as PackedStringArray).is_empty(), "with a loop: %s %s" % [looped["says"], str(looped["problems"])])
	expect((looped["plan"] as TombPlan).links.size() == 6, "the plan with a loop has %d ways, not 6" % (looped["plan"] as TombPlan).links.size())
	expect(not TombFloorSpec.join(spec, 2, 5), "the same two rooms were joined twice")
	# Stairs into the new room put it a level down: the doorway that closes the loop no longer fits, and that is said.
	spec["rooms"][5]["way"] = "stairs"
	var said_wrong := TombSpec.problems(spec)
	expect(said_wrong.size() == 1 and "make it stairs" in said_wrong[0], "a level doorway between two levels: %s" % str(said_wrong))
	spec["joins"][0]["way"] = "stairs"
	expect(TombSpec.check(spec)["ok"], "stairs closing the loop: %s" % TombSpec.check(spec)["says"])
	spec["joins"][0]["lock"] = "within"
	spec["joins"][0]["seal"] = 5
	expect(TombSpec.check(spec)["ok"], "a door that opens only from within: %s %s" % [TombSpec.check(spec)["says"], str(TombSpec.problems(spec))])
	# A room with others beyond it stays; one with none can be moved, and its second way does not go with it.
	expect(not TombFloorSpec.move_room(spec, 4, 2, 3) and not TombFloorSpec.remove_room(spec, 4), "a room that another is entered from was moved or removed")
	expect(TombFloorSpec.move_room(spec, 5, 2, 3) and TombFloorSpec.cell_of(spec["rooms"][5]) == Vector2i(2, -1) and int(spec["rooms"][5]["from"]) == 2 and (spec["joins"] as Array).is_empty(), "the room was not moved north of the antechamber")
	expect(not TombFloorSpec.move_room(spec, 5, 1, 1), "a room was moved onto a square that is taken")
	expect(TombSpec.check(spec)["ok"], "with the room moved: %s" % TombSpec.check(spec)["says"])
	# Removing a room: the rooms after it are counted afresh, and what named one of them still names it.
	spec["rooms"][3]["stone_in"] = 5
	expect(TombFloorSpec.remove_room(spec, 4) and (spec["rooms"] as Array).size() == 5 and int(spec["rooms"][3]["stone_in"]) == 4 and int(spec["rooms"][4]["from"]) == 2, "a room was not removed, or the others lost count")
	expect(TombSpec.check(spec)["ok"], "with a room removed: %s %s" % [TombSpec.check(spec)["says"], str(TombSpec.problems(spec))])
	expect(not TombFloorSpec.remove_room(spec, 0) and not TombFloorSpec.remove_room(spec, 3), "the entrance or the burial chamber was removed")

	# What is to be refused, and in what words.
	var cases: Array = [
		["two rooms on one square", func(broken: Dictionary) -> void: broken["rooms"][4]["cell"] = [2, 0], "same square"],
		["a room entered from one that is not beside it", func(broken: Dictionary) -> void: broken["rooms"][4]["cell"] = [5, 5], "not on a square next to it"],
		["rooms entered from each other in a ring", func(broken: Dictionary) -> void:
			broken["rooms"].append(TombFloorSpec.room("corridor", Vector2i(2, 1), 4))
			broken["rooms"][4]["from"] = 5, "round in a ring"],
		["two burial chambers", func(broken: Dictionary) -> void: broken["rooms"][4]["role"] = "burial", "one burial chamber"],
		["two ways on from the entrance", func(broken: Dictionary) -> void:
			broken["rooms"][4]["cell"] = [0, 1]
			broken["rooms"][4]["from"] = 0, "The entrance has one way on"],
		["a locked crawl", func(broken: Dictionary) -> void: broken["rooms"][4]["lock"] = "work", "no door to lock"],
		["two blocks and plates in one room", func(broken: Dictionary) -> void:
			broken["rooms"][2]["lock"] = "work"
			broken["rooms"][4]["way"] = "open"
			broken["rooms"][4]["lock"] = "work", "would have two blocks and plates"],
		["a seal stone under a room that is no well", func(broken: Dictionary) -> void:
			broken["rooms"][2]["lock"] = "lever_below"
			broken["rooms"][2]["stone_in"] = 1, "under a room that is a well"],
		["a second way to a room with a loft", func(broken: Dictionary) -> void:
			broken["rooms"].append(TombFloorSpec.room("corridor", Vector2i(2, 1), 4))
			broken["rooms"][2]["lock"] = "lever_above"
			broken["rooms"][2]["stone_in"] = 2
			broken["joins"].append({"a": 2, "b": 5, "way": "open", "lock": "none", "seal": 5}), "has a loft over its far end"],
		["a mummy at the top of the sand", func(broken: Dictionary) -> void:
			broken["rooms"][2]["way"] = "sand"
			broken["rooms"][2]["mummy"] = 0, "top of the sand"],
	]
	for case: Array in cases:
		var broken := TombFloorSpec.fresh()
		(case[1] as Callable).call(broken)
		var said := TombSpec.problems(broken)
		var right := false
		for line in said:
			right = right or String(case[2]) in line
		expect(right, "%s: %s" % [case[0], "let through" if said.is_empty() else "refused, but in other words: %s" % str(said)])
	print("floor, refused: %d ways of breaking a floor plan" % cases.size())


# The editor's floor plan: a tomb that branches opened in it, a room put off a
# side, chosen by a touch on the plan, joined into a loop, moved, removed,
# undone; and a tomb down one axis opened after it, as before.
func _floor_editor() -> void:
	var scene := (load("res://tomb_editor.tscn") as PackedScene).instantiate()
	var editor := scene as TombEditor
	TombEditor.keeps = false
	root.add_child(scene)
	await process_frame
	await process_frame
	editor.take(TombFloorSpec.fresh("Test plan"))
	editor.rebuild()
	expect(editor._floor and editor.found["ok"] and editor._layout is TombLayout3D, "the editor's new branching tomb: %s" % editor.found["says"])
	for i in 4:
		await process_frame
	expect(editor._cam.projection == Camera3D.PROJECTION_ORTHOGONAL, "the floor plan is not seen from overhead")
	# A touch in the middle of a room chooses it; a touch on a + puts a room there.
	editor.look_at_all()
	await process_frame
	var middle := editor._box_of(4).get_center()
	editor._tapped(editor._to_screen(middle.x, middle.y))
	expect(editor.chosen == 4, "a touch on the side chamber chose room %d" % (editor.chosen + 1))
	await process_frame
	await process_frame
	expect(editor._marks.size() == TombFloorSpec.free_sides(editor.spec, 4).size() and editor._marks.size() == 3, "the side chamber has %d marks to touch, and %d free sides" % [editor._marks.size(), TombFloorSpec.free_sides(editor.spec, 4).size()])
	var east := editor._mark_at(4, 0)
	editor._tapped(east)
	expect(editor.rooms().size() == 6 and editor.chosen == 5 and TombFloorSpec.cell_of(editor.rooms()[5]) == Vector2i(2, 1), "a touch on the + east of the side chamber did not put a room there")
	expect(editor.found["ok"], "with the room added: %s" % editor.found["says"])
	# Join: the marks are on the rooms it can be joined to, and a touch on one closes the loop.
	editor.start("join")
	await process_frame
	await process_frame
	expect(editor.mode == "join" and editor._marks.size() == 1, "joining shows %d rooms to join to, not the one beside it" % editor._marks.size())
	editor._tapped(editor._marks[0][0])
	expect((editor.spec["joins"] as Array).size() == 1 and editor.mode == "" and editor.found["ok"], "the touch did not join the two rooms: %s" % editor.found["says"])
	expect((editor.found["plan"] as TombPlan).links.size() == 6, "the tomb in the editor has no loop")
	editor.set_join(editor.spec["joins"][0], "way", "crawl")
	expect(editor.found["ok"] and (editor.found["plan"] as TombPlan).links[5].pass_kind == TombPlan.Pass.CRAWL, "the second way was not made a crawl")
	# The inspector: the door of the new room opened by a block and plate in another room.
	editor.set_value("lock", "seal")
	editor.rebuild()
	expect(editor.found["ok"] and int(editor.rooms()[5]["stone_in"]) != 4, "a seal stone for the new room: %s (in room %d)" % [editor.found["says"], int(editor.rooms()[5]["stone_in"]) + 1])
	editor.set_value("lock", "brazier")
	editor.rebuild()
	expect(editor.found["ok"] and editor.rooms()[4]["dark"], "the editor did not leave a torch for the brazier, or make its room dark: %s" % editor.found["says"])
	# Move: with the loop there are places marked; the touch moves it, and the loop goes.
	editor.start("move")
	await process_frame
	await process_frame
	expect(editor.mode == "move" and editor._marks.size() >= 3, "moving shows %d places" % editor._marks.size())
	editor.move_to(2, 3)
	expect(TombFloorSpec.cell_of(editor.rooms()[5]) == Vector2i(2, -1) and (editor.spec["joins"] as Array).is_empty(), "the room was not moved north of the antechamber")
	editor.undo()
	expect(TombFloorSpec.cell_of(editor.rooms()[5]) == Vector2i(2, 1) and (editor.spec["joins"] as Array).size() == 1, "undoing did not put the room and its second way back")
	editor.rebuild()
	editor.choose(4)
	editor.remove()
	expect(editor.rooms().size() == 6, "a room that another is entered from was removed")
	editor.choose(5)
	editor.remove()
	expect(editor.rooms().size() == 5 and (editor.spec["joins"] as Array).is_empty() and editor.chosen == 4, "the room was not removed with its second way")
	editor.choose(0)
	editor.remove()
	expect(editor.rooms().size() == 5, "the entrance was removed")
	# One of the generator's, standing for a while; then a tomb down one axis again.
	editor.take(TombFloorSpec.from_seed(3, 2))
	editor.rebuild()
	expect(editor.found["ok"], "branching seed 3 in the editor: %s" % editor.found["says"])
	editor.look_at_all()
	for i in 30:
		await process_frame
	editor.show_way()
	editor.show_tombs(true)
	await process_frame
	editor.take(TombSpec.fresh("Test tomb"))
	editor.rebuild()
	for i in 4:
		await process_frame
	expect(not editor._floor and editor.found["ok"] and editor._cam.projection == Camera3D.PROJECTION_PERSPECTIVE and not editor._layout is TombLayout3D, "a tomb down one axis after one that branches is not seen from the side")
	editor.choose(1)
	editor.add_after()
	expect(editor.rooms().size() == 5 and editor.chosen == 2, "a room was not added to a tomb down one axis")
	scene.queue_free()
	await process_frame
	print("floor, editor: done")
