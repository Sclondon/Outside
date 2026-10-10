extends SceneTree
## Not part of the game. Checks tombs made by hand (`TombSpec`) and the tomb
## editor that makes them, with nothing drawn.
## godot --headless --path . --fixed-fps 60 --script tools/tomb_editor_test.gd -- [seeds=60] [fuzz=400]
##
##  - the tomb a new one starts as can be built and finished;
##  - every generated tomb (seeds 1 to `seeds`, each difficulty) taken into the
##    editor's form and made into a plan again can still be finished, and has
##    as many rooms, doors and things as it had;
##  - `fuzz` tombs put together at random: whichever of them `problems` lets
##    through is laid out and solved without a script error;
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
	print("fuzz: %d of %d let through, %d of them can be finished" % [let_through, fuzz, finishable])
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
