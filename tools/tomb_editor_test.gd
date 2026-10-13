extends SceneTree
## Not part of the game. Checks tombs made by hand (`TombSpec`) and the tomb
## editor that makes them, with nothing drawn.
## godot --headless --path . --fixed-fps 60 --script tools/tomb_editor_test.gd -- [seeds=60] [fuzz=1200] [size=1280x720]
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
##  - a tomb that branches (`TombFloorSpec`): the one a new one starts as; every
##    one the generator makes taken into the editor's form and back, the same
##    tomb; what the floor plan does to one (a room added off a side, joined
##    into a loop, moved, removed, the others counted afresh); ten ways of
##    breaking one, each refused in the words meant for it; and the editor's
##    floor plan itself, by touches on it;
##  - the editor itself: opened, a room added, changed, moved and removed,
##    undone, and a tomb played from it and finished by the solver's way;
##  - the editor as it is on a phone (`TombPhoneUI`, `-- phone`), worked by
##    fingers and nothing else (`InputEventScreenTouch` and `ScreenDrag`, given
##    to the engine as a screen gives them): in both views a new tomb, rooms
##    added, each kind of list chosen from, the steppers and switches, a room
##    moved, joined and removed, undone and done again, the tomb named,
##    another opened, copied and forgotten, the tomb played and come back
##    from; and at every state of it everything that can be touched measured
##    (`tools/tomb_phone_probe.gd`: 88 by 88 at least, 12 apart, clear of the
##    edges, no words under 26).
## Ends with PASSED or FAILED: FAILED too if any script error was said on the
## way, whatever else passed. The tombs it keeps are in a file of its own
## (`user://test_my_tombs.json`), never the player's.

const Probe := preload("res://tools/tomb_phone_probe.gd")

var seeds := 60
var fuzz := 1200
## How big the screen of the phone is, for the part that is worked by touch.
var screen := Vector2i(1280, 720)
var failed := false
var watch: Watch
var editor: TombEditor
var phone: TombPhoneUI
var probed := 0
var smallest := Vector2(INF, INF)
var nearest := INF
var margin := INF
var foot := INF
var words := 9999
var mark := INF
var mark_gap := INF


## Counts what the engine says went wrong while the test runs, so that it cannot pass over a script error.
class Watch extends Logger:
	var script_errors := 0
	var other_errors := 0
	var first := ""

	func _log_error(function: String, file: String, line: int, code: String, rationale: String, _editor_notify: bool, error_type: int, _script_backtraces: Array[ScriptBacktrace]) -> void:
		if error_type == ERROR_TYPE_WARNING:
			return
		if error_type == ERROR_TYPE_SCRIPT:
			script_errors += 1
		else:
			other_errors += 1
		if first == "":
			first = "%s:%d in %s: %s %s" % [file, line, function, code, rationale]


func _initialize() -> void:
	watch = Watch.new()
	OS.add_logger(watch)
	TombSpec.path = "user://test_my_tombs.json"
	TombDaily.path = "user://test_tombs.json"
	DirAccess.remove_absolute(ProjectSettings.globalize_path(TombSpec.path))
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("seeds="):
			seeds = int(arg.trim_prefix("seeds="))
		elif arg.begins_with("size="):
			screen = Vector2i(int(arg.trim_prefix("size=").get_slice("x", 0)), int(arg.trim_prefix("size=").get_slice("x", 1)))
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
	TombEditor.layout = "desk"
	await _editor()
	_floor_specs()
	await _floor_editor()
	TombEditor.layout = "phone"
	root.size = screen
	await _phone_line()
	await _phone_floor()
	print("phone: %d states measured: smallest thing to touch %.0f x %.0f, nearest two %.0f apart, %.0f from the sides, %.0f from the bottom, smallest words %d; marks on the plan at least %.0f across and %.0f apart" % [
		probed, smallest.x, smallest.y, nearest, margin, foot, words, mark, mark_gap])
	DirAccess.remove_absolute(ProjectSettings.globalize_path(TombSpec.path))
	if watch.script_errors + watch.other_errors > 0:
		failed = true
		print("WRONG: %d script errors and %d other errors were said while this ran; the first: %s" % [watch.script_errors, watch.other_errors, watch.first])
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
	# The creatures, each chosen by name where the other locks are, and the way through said in words.
	editor.take(TombSpec.fresh("Keepers"))
	editor.choose(2)
	editor.set_value("lock", "name")
	editor.rebuild()
	expect(editor.found["ok"] and int(editor.rooms()[2]["stone_in"]) == 1, "a gate guardian chosen in the editor: %s (its leaf in room %d)" % [editor.found["says"], int(editor.rooms()[2]["stone_in"]) + 1])
	expect(_way_says(editor, ["leaf of the Book", "tell him his name"]), "the way through does not say to read the leaf and name the guardian")
	expect(TombSpec.from_text(TombSpec.to_text(editor.spec)) == editor.spec, "a tomb with a guardian did not come back from text as it went")
	editor.set_value("lock", "sphinx_jar")
	editor.rebuild()
	expect(editor.found["ok"] and int(editor.rooms()[1]["jar"]) == 1, "a sphinx chosen in the editor, and a jar left for it: %s" % editor.found["says"])
	expect(_way_says(editor, ["Take the jar", "before the sphinx"]), "the way through does not say to give the sphinx its jar")
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


# Whether the way through the tomb in the editor says each of these, in this order.
func _way_says(editor: TombEditor, wanted: Array) -> bool:
	var at := 0
	for step: Array in editor.found["solved"]["steps"]:
		if at < wanted.size() and String(wanted[at]) in TombSpec.step_words(editor.spec, editor.found["plan"], step):
			at += 1
	return at == wanted.size()


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
	editor.set_value("lock", "name")
	editor.rebuild()
	expect(editor.found["ok"] and (editor.found["plan"] as TombPlan).triggers.any(func(trigger: TombPlan.Trigger) -> bool: return trigger.kind == TombPlan.Switch.NAME), "a gate guardian for the new room, on a floor plan: %s" % editor.found["says"])
	editor.set_value("lock", "brazier")
	editor.rebuild()
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


# --- The editor on a phone, worked by fingers

func frames(count := 3) -> void:
	for i in count:
		await process_frame


# A finger comes down on the screen, or is lifted from it, as the screen itself would say.
func finger(index: int, at: Vector2, down: bool) -> void:
	var touch := InputEventScreenTouch.new()
	touch.index = index
	touch.position = root.get_final_transform() * at
	touch.pressed = down
	Input.parse_input_event(touch)


func slide(index: int, from: Vector2, to: Vector2) -> void:
	var drag := InputEventScreenDrag.new()
	drag.index = index
	drag.position = root.get_final_transform() * to
	drag.relative = root.get_final_transform().basis_xform(to - from)
	Input.parse_input_event(drag)


func tap(at: Vector2) -> void:
	finger(0, at, true)
	await frames(2)
	finger(0, at, false)
	await frames(4)


# One finger put down, dragged and lifted.
func swipe(from: Vector2, to: Vector2, steps := 6) -> void:
	finger(0, from, true)
	await frames(1)
	var at := from
	for i in steps:
		var next := from.lerp(to, float(i + 1) / steps)
		slide(0, at, next)
		at = next
		await frames(1)
	# (and held still a moment before it is lifted, so that a page is not flung on)
	await frames(8)
	finger(0, to, false)
	await frames(2)
	for i in 90:
		if phone == null or absf(phone.scroller()._speed) < 4.0:
			break
		await frames(1)


# Touches the thing that goes by that name: if it is on a page and scrolled off it, the page is dragged first.
func press(key: String) -> bool:
	for attempt in 40:
		await frames(2)
		var touch := phone.find(key)
		if touch == null:
			if attempt < 6:
				continue
			expect(false, "there is no \"%s\" to touch (the page is \"%s\")" % [key, phone.page])
			return false
		var rect := touch.get_global_rect()
		var view := root.get_visible_rect()
		if phone.scroller().is_ancestor_of(touch):
			view = phone.scroller().get_global_rect()
		var at := rect.get_center()
		if view.has_point(at - Vector2(0.0, 30.0)) and view.has_point(at + Vector2(0.0, 30.0)):
			if touch.disabled:
				expect(false, "\"%s\" cannot be touched: it is greyed out" % key)
				return false
			await tap(at)
			return true
		var by := clampf(view.get_center().y - at.y, -240.0, 240.0)
		var from := view.get_center() - Vector2(0.0, by * 0.5)
		await swipe(from, from + Vector2(0.0, by))
	expect(false, "\"%s\" could not be brought onto the screen" % key)
	return false


# Opens a list from a row of a room's page and chooses from it.
func pick(row: String, choice: String) -> void:
	await press(row)
	await frames(2)
	expect(phone.page == "choice", "%s did not open a list (the page is \"%s\")" % [row, phone.page])
	await check("the list of %s" % row)
	await press(choice)
	await frames(2)
	expect(phone.page == "room", "choosing %s did not come back to the room's page (the page is \"%s\")" % [choice, phone.page])


# Measures everything that can be touched as it now stands.
func check(state: String) -> void:
	await frames(4)
	var said := Probe.measure(editor)
	probed += 1
	if int(said["count"]) > 0:
		var size: Vector2 = said["smallest"]
		if size.x * size.y < smallest.x * smallest.y:
			smallest = size
		nearest = minf(nearest, said["nearest"])
		margin = minf(margin, said["margin"])
		foot = minf(foot, said["foot"])
	words = mini(words, said["text"])
	mark = minf(mark, said["mark"])
	mark_gap = minf(mark_gap, said["mark_gap"])
	for line: String in said["wrong"]:
		expect(false, "%s: %s" % [state, line])


# Opens the editor as the game does, as the scene that is running.
func _open_editor() -> void:
	change_scene_to_file("res://tomb_editor.tscn")
	for i in 60:
		await frames(1)
		if current_scene is TombEditor:
			break
	editor = current_scene as TombEditor
	phone = editor._phone if editor else null
	await frames(6)


# Where on the screen the middle of a room is.
func _room_at(index: int) -> Vector2:
	if editor._floor:
		var middle := editor._box_of(index).get_center()
		return editor._to_screen(middle.x, middle.y)
	var span := editor._span_of(index)
	return editor._to_screen((span[0] + span[1]) * 0.5, (span[2] + span[3]) * 0.5)


func _told(index: int) -> Dictionary:
	return editor.rooms()[index]


# Plays the tomb with a touch on `key`, sees that it is the tomb that is running, and comes back by its "Edit".
func _play_and_back(key: String, view: String) -> void:
	var name: String = editor.spec["name"]
	var count := editor.rooms().size()
	if key.begins_with("more:"):
		await press("bar:more")
	await press(key)
	var level: TombLevel = null
	for i in 240:
		await frames(1)
		if current_scene and not current_scene is TombEditor:
			level = current_scene.get_node_or_null(^"Level") as TombLevel
			if level:
				break
	expect(level != null, "%s did not play the tomb" % key)
	if level == null:
		return
	expect(level.mode == "custom" and level.view == view and (level.spec.get("rooms", []) as Array).size() == count,
			"%s played something other than the tomb being made, seen as \"%s\": %s, %s" % [key, view, level.mode, level.view])
	await frames(40)
	level._to_editor()
	for i in 120:
		await frames(1)
		if current_scene is TombEditor:
			break
	editor = current_scene as TombEditor
	expect(editor != null and editor._phone != null, "\"Edit\" in the tomb did not come back to the editor laid out for a phone")
	if editor == null:
		return
	phone = editor._phone
	await frames(8)
	expect(editor.spec["name"] == name and editor.rooms().size() == count, "the editor came back with %s (%d rooms), not %s (%d)" % [editor.spec["name"], editor.rooms().size(), name, count])


# A tomb down one axis, made on a phone with nothing but touches.
func _phone_line() -> void:
	TombEditor.keeps = true
	await _open_editor()
	expect(editor != null and phone != null, "the editor did not open laid out for a phone")
	if phone == null:
		return
	expect(editor._status == null and editor._side == null and editor._sheet == null, "the bar, the panel and the sheet of the other layout were made as well")
	await check("line: as it opens")

	# A new tomb.
	await press("bar:tombs")
	expect(phone.page == "tombs", "Tombs did not open its page")
	await check("line: Tombs")
	await press("tombs:new")
	expect(phone.page == "" and editor.rooms().size() == 4 and editor.spec["name"] == "My tomb 2" and not editor._floor, "a new tomb was not made: %s, %d rooms" % [editor.spec["name"], editor.rooms().size()])

	# A touch on a room chooses it; a second opens its page.
	await press("zoom:all")
	await tap(_room_at(2))
	expect(editor.chosen == 2 and phone.page == "", "a touch on the antechamber chose room %d" % (editor.chosen + 1))
	expect("3 Antechamber is chosen" in phone.says()[0] or Time.get_ticks_msec() * 0.001 < editor._hint_until, "the strip does not say what is chosen: %s" % phone.says()[0])
	await check("line: a room chosen")
	await tap(_room_at(2))
	await frames(2)
	expect(phone.page == "room", "a second touch on the chosen room did not open its page")
	await check("line: a room's page")
	expect(phone.open_rect().size.x >= 200.0, "a room's page leaves %.0f of the tomb showing" % phone.open_rect().size.x)
	var seen := _room_at(2)
	expect(phone.open_rect().has_point(seen), "the room being changed is not in the part of the tomb left showing (it is at %s)" % str(seen))

	# Each kind of list, the switches and the steppers.
	await pick("row:role", "choice:well")
	expect(_told(2)["role"] == "well", "the room was not made a well")
	await pick("row:mummy", "choice:2")
	expect(int(_told(2)["mummy"]) == 2, "the mummy was not made a brute")
	await pick("row:barrier", "choice:narrow")
	expect(_told(2)["barrier"] == "narrow", "the barrier was not made a narrow gap")
	await press("switch:dark")
	expect(_told(2)["dark"] == true, "the switch did not make the room dark")
	await press("switch:dark")
	expect(_told(2)["dark"] == false, "the switch did not make the room light again")
	await press("switch:pit")
	expect(_told(2)["pit"] == true, "the switch did not put a pit in")
	await press("switch:pit")
	await press("step:torch:+")
	await press("step:torch:+")
	expect(int(_told(2)["torch"]) == 2, "two steps up left %d torches" % int(_told(2)["torch"]))
	await press("step:torch:-")
	expect(int(_told(2)["torch"]) == 1, "a step down left %d torches" % int(_told(2)["torch"]))
	await press("step:jar:+")
	expect(int(_told(2)["jar"]) == 1, "a step up left no jar")
	await check("line: a room's page, scrolled")
	await pick("row:way", "choice:stairs")
	expect(_told(2)["way"] == "stairs", "the way on was not made stairs")
	await pick("row:lock", "choice:lever_below")
	expect(_told(2)["lock"] == "lever_below" and int(_told(2)["stone_in"]) == 2, "the lock was not made a seal stone under this well")
	await pick("row:stone_in", "choice:2")
	await check("line: a room's page, at its end")
	await pick("row:mummy", "choice:none")
	editor.rebuild()
	expect(editor.found["ok"], "the tomb made by touches: %s" % editor.found["says"])

	# From room to room without leaving the page; whether it works; and out.
	await press("page:next")
	expect(editor.chosen == 3 and phone.page == "room", "the arrow did not go on to the burial chamber")
	await check("line: the burial chamber's page")
	await press("page:prev")
	await press("page:prev")
	await press("page:prev")
	expect(editor.chosen == 0 and phone.page == "room", "the arrow did not go back to the entrance")
	await check("line: the entrance's page")
	await press("page:next")
	await press("page:next")
	await press("page:verdict")
	expect(phone.page == "works", "a touch on what it says of the tomb did not open the list")
	await check("line: whether it works")
	await press("page:done")
	expect(phone.page == "room", "Back did not come back to the room's page")
	await press("page:done")
	expect(phone.page == "" and editor.chosen == 2, "Done did not come back to the tomb")

	# The chosen room's buttons, and undoing.
	await press("act:add")
	expect(editor.rooms().size() == 5 and editor.chosen == 3, "Add did not put a room after the chosen one")
	await press("act:copy")
	expect(editor.rooms().size() == 6 and editor.chosen == 4, "Copy did not make another")
	await press("act:earlier")
	expect(editor.chosen == 3, "Earlier did not move the room")
	await press("act:later")
	expect(editor.chosen == 4, "Later did not move the room")
	await press("act:remove")
	expect(editor.rooms().size() == 5, "Remove did not take the room away")
	expect("Undo puts it back" in phone.says()[0], "nothing says the room can be brought back: %s" % phone.says()[0])
	await press("bar:undo")
	expect(editor.rooms().size() == 6, "Undo did not put the room back")
	await press("bar:redo")
	expect(editor.rooms().size() == 5, "Redo did not take it away again")
	await check("line: after adding and removing")

	# Looking about: one finger, two, and the buttons that do the same.
	var open := phone.open_rect()
	var was := editor._focus
	await swipe(open.get_center(), open.get_center() - Vector2(180.0, 0.0))
	expect(editor._focus.x > was.x + 0.5, "one finger did not drag the tomb")
	var reach := editor._reach
	finger(0, open.get_center() - Vector2(80.0, 0.0), true)
	finger(1, open.get_center() + Vector2(80.0, 0.0), true)
	await frames(2)
	var at := open.get_center() + Vector2(80.0, 0.0)
	for i in 6:
		slide(1, at, at + Vector2(20.0, 0.0))
		at += Vector2(20.0, 0.0)
		await frames(1)
	finger(1, at, false)
	finger(0, open.get_center() - Vector2(80.0, 0.0), false)
	await frames(3)
	expect(editor._reach < reach * 0.8, "two fingers moving apart did not bring the tomb nearer (%.1f, from %.1f)" % [editor._reach, reach])
	reach = editor._reach
	await press("zoom:further")
	expect(editor._reach > reach, "the button did not go further off")
	await press("zoom:nearer")
	await press("zoom:nearer")
	expect(editor._reach < reach, "the button did not come nearer")
	await press("zoom:all")

	# The rooms as a list.
	await press("bar:rooms")
	expect(phone.page == "rooms", "Rooms did not open its page")
	await check("line: Rooms")
	await press("room:1")
	expect(phone.page == "" and editor.chosen == 1, "a touch on a room in the list did not go to it")
	await press("bar:rooms")
	await press("room:2:edit")
	expect(phone.page == "room" and editor.chosen == 2, "Edit in the list did not open the room's page")

	# Something wrong: said on the strip, listed, and a touch on it goes to its room.
	await pick("row:way", "choice:crawl")
	await press("page:done")
	await press("bar:rooms")
	await press("room:0")
	await frames(30)
	expect(not (editor.found["problems"] as PackedStringArray).is_empty(), "a locked crawl was let through")
	expect(phone.says()[1].begins_with("Cannot be built"), "the strip does not say the tomb cannot be built: %s" % phone.says()[1])
	await check("line: something wrong")
	await press("strip")
	expect(phone.page == "works", "a touch on the strip did not open the list of what is wrong")
	await check("line: what is wrong")
	await press("problem:0")
	expect(phone.page == "" and editor.chosen == 2, "a touch on what is wrong went to room %d" % (editor.chosen + 1))
	await press("bar:undo")
	await frames(30)
	expect((editor.found["problems"] as PackedStringArray).is_empty(), "Undo did not put the tomb right: %s" % editor.found["says"])

	# Naming it (the one place, with the text of a tomb, that the keyboard is for).
	await press("bar:tombs")
	await press("tombs:name")
	expect(phone.page == "name", "the name did not open its page")
	await check("line: the name")
	var field := phone._field as LineEdit
	expect(field != null and field.get_global_rect().end.y < root.get_visible_rect().size.y * 0.45, "the name is not in the top of the screen, over where a keyboard comes up")
	await tap(field.get_global_rect().get_center())
	expect(field.has_focus(), "a touch on the name did not make it ready to type in")
	for letter in "Thumb tomb":
		var key := InputEventKey.new()
		key.unicode = letter.unicode_at(0)
		key.pressed = true
		Input.parse_input_event(key)
		await frames(1)
	await press("name:use")
	expect(editor.spec["name"] == "Thumb tomb" and phone.page == "tombs", "the tomb was not named: it is %s (the page is \"%s\")" % [editor.spec["name"], phone.page])
	expect("Thumb tomb" in TombSpec.names() and not "My tomb 2" in TombSpec.names(), "what is kept is %s" % str(TombSpec.names()))

	# Another opened, copied, and forgotten (which asks).
	await press("tomb:My tomb")
	expect(editor.spec["name"] == "My tomb" and editor.rooms().size() == 4 and phone.page == "", "the other tomb was not opened")
	await press("bar:tombs")
	await press("tomb:Thumb tomb:copy")
	expect(editor.spec["name"] == "Thumb tomb copy" and editor.rooms().size() == 5, "the tomb was not copied: %s" % editor.spec["name"])
	await press("bar:tombs")
	await check("line: Tombs, with others kept")
	await press("tomb:My tomb:forget")
	expect(phone.page == "ask", "Forget did not ask first")
	await check("line: forgetting a tomb")
	await press("ask:no")
	expect(phone.page == "tombs" and "My tomb" in TombSpec.names(), "Keep it did not keep it")
	await press("tomb:My tomb:forget")
	await press("ask:yes")
	expect(phone.page == "tombs" and not "My tomb" in TombSpec.names(), "the tomb was not forgotten")
	await press("tombs:copy")
	expect(editor.spec["name"] == "Thumb tomb copy 2", "Copy this one made %s" % editor.spec["name"])

	# One of the generator's, and the tomb as text.
	await press("bar:tombs")
	await press("tombs:generator")
	expect(phone.page == "generator", "the generator's did not open their page")
	await check("line: the generator's")
	var number := phone._number
	await press("gen:+")
	expect(phone._number == number + 1, "the step up did not change the number")
	await press("gen:-")
	await press("gen:any")
	number = phone._number
	await press("gen:line:1")
	expect(phone.page == "" and String(editor.spec["name"]).begins_with("Tomb %d" % number) and not editor._floor and int(editor.spec["difficulty"]) == 1, "the generator's tomb was not opened: %s" % editor.spec["name"])
	await frames(20)
	expect(editor.found["ok"], "the generator's tomb: %s" % editor.found["says"])
	await check("line: one of the generator's")
	await press("bar:tombs")
	await press("tombs:share")
	expect(phone.page == "share", "the tomb as text did not open its page")
	await check("line: the tomb as text")
	var text := phone._field as TextEdit
	expect(text != null and TombSpec.to_text(TombSpec.from_text(text.text)) == TombSpec.to_text(editor.spec), "the text on the page is not this tomb")
	await press("share:copy")
	text.text = "not a tomb"
	await press("share:use")
	expect(phone.page == "share", "nonsense was taken for a tomb")
	# (what a paste would leave in the box: the text itself cannot be pasted from here)
	text.text = TombSpec.to_text(TombSpec.fresh("Another"))
	await press("share:use")
	expect(phone.page == "" and editor.rooms().size() == 4 and String(editor.spec["name"]).begins_with("Tomb %d" % number), "the text was not brought in under the tomb's own name")
	await press("bar:undo")
	expect(editor.rooms().size() > 4, "Undo did not bring back the tomb the text replaced")

	# More: help, other sizes, whether it works.
	await press("bar:more")
	expect(phone.page == "more", "More did not open its page")
	await check("line: More")
	await press("more:help")
	expect(phone.page == "help", "the help did not open")
	await check("line: how it works")
	await press("page:done")
	expect(phone.page == "more", "Back did not come back to More")
	var seed_was := int(editor.spec["seed"])
	await press("more:sizes")
	expect(int(editor.spec["seed"]) != seed_was and phone.page == "", "the rooms were not cut to other sizes")
	await press("bar:undo")
	await press("bar:more")
	await press("more:way")
	expect(phone.page == "works", "More did not open whether it works")
	await press("page:done")
	await press("page:done")
	expect(phone.page == "", "Done did not close More")

	# Played, both ways, and come back from.
	await _play_and_back("bar:play", "side")
	if editor:
		await _play_and_back("more:walk", "3d")
	print("phone, line: done")


# A tomb that branches, made on a phone with nothing but touches.
func _phone_floor() -> void:
	if editor == null or phone == null:
		expect(false, "there is no editor to make a floor plan in")
		return
	await press("bar:tombs")
	await press("tombs:new_branching")
	await frames(6)
	expect(editor._floor and editor.rooms().size() == 5 and phone.page == "", "a new tomb that branches was not made")
	expect(editor._cam.projection == Camera3D.PROJECTION_ORTHOGONAL, "the floor plan is not seen from overhead")
	await check("floor: a new one")

	# A touch on a room chooses it, however far off; a touch on a + puts a room there.
	await tap(_room_at(4))
	expect(editor.chosen == 4, "a touch on the side chamber chose room %d" % (editor.chosen + 1))
	await frames(4)
	expect(editor._marks.size() == 3, "the side chamber has %d marks to touch, not 3" % editor._marks.size())
	await check("floor: a room and its marks")
	for i in 8:
		if editor._box_of(3).size.y / editor._per_pixel() < 36.0:
			break
		await press("zoom:further")
	var box := editor._box_of(3)
	var above := editor._to_screen(box.get_center().x, box.position.y) - Vector2(0.0, 16.0)
	expect(editor._room_on_floor(editor._focus + (above - editor._pad.size * 0.5) * editor._per_pixel()) == -1, "there is a room over the burial chamber")
	await tap(above)
	expect(editor.chosen == 3, "from far off, a touch just beside the burial chamber chose room %d" % (editor.chosen + 1))
	await tap(_room_at(4))
	await check("floor: from far off")
	expect(editor.chosen == 4 and editor._marks.size() == 3, "from far off the side chamber has %d marks" % editor._marks.size())
	var east: Vector2 = editor._marks[0][0]
	for found_mark: Array in editor._marks:
		if (found_mark[0] as Vector2).x > east.x:
			east = found_mark[0]
	await tap(east)
	expect(editor.rooms().size() == 6 and editor.chosen == 5 and TombFloorSpec.cell_of(_told(5)) == Vector2i(2, 1), "a touch on the + east of the side chamber did not put a room there")
	await press("zoom:all")

	# Join: by its mark, and by its list; and Cancel.
	await press("act:join")
	await frames(4)
	expect(editor.mode == "join" and editor._marks.size() == 1, "joining shows %d rooms to join to, not the one beside it" % editor._marks.size())
	expect("Joining" in phone.says()[0], "the strip does not say a room is being joined: %s" % phone.says()[0])
	await check("floor: joining")
	await tap(editor._marks[0][0])
	expect((editor.spec["joins"] as Array).size() == 1 and editor.mode == "", "a touch on the mark did not join the two rooms")
	await press("act:join")
	await press("act:list")
	expect(phone.page == "joins", "List did not open the rooms it could be joined to")
	await check("floor: the list of joins")
	await press("join:2")
	expect((editor.spec["joins"] as Array).is_empty() and phone.page == "", "the list did not take the second way away")
	await press("act:join")
	await press("act:list")
	await press("join:2")
	expect((editor.spec["joins"] as Array).size() == 1, "the list did not join the two rooms")
	await press("act:join")
	await press("act:cancel")
	expect(editor.mode == "", "Cancel did not leave joining")

	# The room's page: the way in, its lock from another room, and its second way.
	await press("act:edit")
	expect(phone.page == "room", "Edit did not open the room's page")
	await check("floor: a room's page")
	await pick("row:join0:way", "choice:crawl")
	expect(editor.spec["joins"][0]["way"] == "crawl", "the second way was not made a crawl")
	await pick("row:join0:way", "choice:open")
	await pick("row:join0:door", "choice:5")
	expect(editor.spec["joins"][0]["lock"] == "within" and int(editor.spec["joins"][0]["seal"]) == 5, "the second way was not given a door that opens from this room")
	await check("floor: a room's page, at its end")
	await pick("row:lock", "choice:seal")
	expect(_told(5)["lock"] == "seal", "the lock was not made a seal stone in another room")
	await pick("row:stone_in", "choice:%d" % int(_told(5)["stone_in"]))
	await pick("row:lock", "choice:work")
	await pick("row:lock_in", "choice:2")
	expect(_told(5)["lock"] == "work" and int(_told(5)["lock_in"]) == 2, "the block and plate were not put in the antechamber")
	await press("switch:dark")
	await press("step:hook:+")
	expect(_told(5)["dark"] == true and int(_told(5)["hook"]) == 1, "the switch and the stepper of a floor plan's room did nothing")
	editor.rebuild()
	expect((editor.found["problems"] as PackedStringArray).is_empty(), "the floor plan made by touches: %s" % editor.found["says"])
	await press("row:join0:away")
	expect((editor.spec["joins"] as Array).is_empty(), "the second way was not taken away from the page")
	await press("page:prev")
	expect(editor.chosen == 4 and phone.page == "room", "the arrow did not go to the room before")
	await press("page:next")
	await press("page:done")

	# Move: by its list, undone, and by its mark.
	await press("act:move")
	await frames(4)
	expect(editor.mode == "move" and editor._marks.size() >= 1, "moving shows %d places" % editor._marks.size())
	await check("floor: moving")
	await press("act:list")
	expect(phone.page == "places", "List did not open the places it could go")
	await check("floor: the list of places")
	await press("place:2:3")
	expect(TombFloorSpec.cell_of(_told(5)) == Vector2i(2, -1) and editor.mode == "" and phone.page == "", "the room was not moved north of the antechamber")
	await press("bar:undo")
	expect(TombFloorSpec.cell_of(_told(5)) == Vector2i(2, 1), "Undo did not put the room back")
	await press("act:move")
	await frames(4)
	var undone := editor._undo.size()
	for shown: Array in editor._marks:
		expect(phone.open_rect().grow(-40.0).has_point(shown[0]), "a place to move to is marked at %s, under the bars" % str(shown[0]))
	await tap(editor._marks[0][0])
	await frames(3)
	if phone.page == "places":
		# (two places under one mark: it lists them)
		await check("floor: the places under one mark")
		var first: Array = phone._arg["only"][0]
		await press("place:%d:%d" % [first[0], first[1]])
	expect(editor.mode == "" and phone.page == "" and editor._undo.size() == undone + 1 and editor.found["layout"] != null, "a touch on a place did not move the room")
	await press("bar:undo")

	# Add from a list of sides; Remove, undone and done again.
	await press("bar:rooms")
	await press("room:5")
	var sides := TombFloorSpec.free_sides(editor.spec, 5)
	expect(editor.chosen == 5 and sides.size() >= 2, "the new room has %d free sides" % sides.size())
	await press("act:add")
	expect(phone.page == "sides", "Add did not ask which side")
	await check("floor: which side")
	await press("side:%d" % int(sides[0]))
	expect(editor.rooms().size() == 7 and editor.chosen == 6 and phone.page == "", "a room was not added off the side chosen")
	await press("act:remove")
	expect(editor.rooms().size() == 6, "Remove did not take the room away")
	await press("bar:undo")
	expect(editor.rooms().size() == 7, "Undo did not put it back")
	await press("bar:redo")
	expect(editor.rooms().size() == 6, "Redo did not take it away again")
	await press("bar:rooms")
	await check("floor: Rooms")
	await press("room:0")
	expect(editor.chosen == 0 and phone.find("act:remove").disabled and phone.find("act:move").disabled, "the entrance can be moved or removed")
	await check("floor: the entrance")
	await press("act:edit")
	await check("floor: the entrance's page")
	await press("page:done")

	# One of the generator's; whether it works; and played.
	await press("bar:tombs")
	await press("tombs:generator")
	await press("gen:branching:2")
	await frames(20)
	expect(editor._floor and editor.found["ok"] and phone.page == "", "the generator's tomb that branches: %s" % editor.found["says"])
	await check("floor: one of the generator's")
	await press("strip")
	expect(phone.page == "works", "a touch on the strip did not open whether it works")
	await check("floor: whether it works")
	await press("page:done")
	await press("bar:more")
	await check("floor: More")
	await press("more:help")
	await check("floor: how it works")
	await press("page:done")
	await press("page:done")
	await _play_and_back("bar:play", "3d")
	if editor:
		expect(editor._floor, "the editor did not come back to the floor plan")
		editor.queue_free()
	await frames(2)
	print("phone, floor: done")
