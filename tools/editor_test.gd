extends SceneTree
## Not part of the game. Opens the desert, opens the level editor over it as the
## menu does, and works it: puts in a pond, a river, a dune, a door and the plate
## that opens it, a hound; changes the ground; undoes; saves; and checks at each
## step that the level is as it should be. Saves a picture of the screen at each.
## Whatever was saved on this device before is put back at the end.
## godot --path . --resolution 1280x720 --script tools/editor_test.gd -- <outdir>

var out := ""
var editor: LevelEditor
var level: Desert
var failed := 0
var shot := 0


func _initialize() -> void:
	DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_NO_FOCUS, true)
	DisplayServer.window_set_position(Vector2i(-6000, -6000))
	out = OS.get_cmdline_user_args()[0]
	run.call_deferred()


func check(what: String, good: bool, note := "") -> void:
	print("%s  %s%s" % ["ok   " if good else "FAIL ", what, "   (%s)" % note if note != "" else ""])
	if not good:
		failed += 1


func picture(name: String) -> void:
	for i in 3:
		await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(out.path_join("%02d_%s.png" % [shot, name]))
	shot += 1


func touch(index: int, at: Vector2, down: bool) -> void:
	var event := InputEventScreenTouch.new()
	event.index = index
	event.position = at
	event.pressed = down
	root.push_input(event)
	await process_frame


func drag(index: int, at: Vector2, by: Vector2) -> void:
	var event := InputEventScreenDrag.new()
	event.index = index
	event.position = at
	event.relative = by
	root.push_input(event)
	await process_frame


func wait(seconds: float) -> void:
	var until := Time.get_ticks_msec() + int(seconds * 1000.0)
	while Time.get_ticks_msec() < until:
		await process_frame


func count(kind: String) -> int:
	var found := 0
	for item: Dictionary in editor.layout["items"]:
		if item["kind"] == kind:
			found += 1
	return found


func entry(page: String, name: String) -> Array:
	for found: Array in LevelLayout.PALETTE[page]:
		if found[0] == name:
			return found
	return []


func run() -> void:
	var kept := FileAccess.get_file_as_string(LevelLayout.SAVED) if LevelLayout.has_saved() else ""
	LevelLayout.forget_saved()
	var scene: Node = load("res://desert.tscn").instantiate()
	root.add_child(scene)
	for i in 30:
		await physics_frame
	level = scene.get_node("Level")
	editor = LevelEditor.new()
	scene.get_node("HUD").add_child(editor)
	editor.open()
	await wait(0.3)
	check("it opens over the level, and the game stands still", editor.visible and paused)
	var things: int = editor.layout["items"].size()
	await picture("opened")

	# Fingers: a touch on a thing chooses it, a drag moves the ground, two pinch
	var palm := {}
	for item: Dictionary in editor.layout["items"]:
		var at := level.place_of(item)
		if String(item.get("what", "")).begins_with("palm") and not editor.cam.is_position_behind(at):
			var on_screen := editor.cam.unproject_position(at)
			if Rect2(200, 100, 700, 500).has_point(on_screen):
				palm = item
	if not palm.is_empty():
		var spot := editor.cam.unproject_position(level.place_of(palm))
		await touch(0, spot, true)
		await touch(0, spot, false)
		check("a touch on a palm chooses it", editor.chosen.get("id", -1) == palm["id"], LevelLayout.label(editor.chosen) if not editor.chosen.is_empty() else "nothing")
	var looked := editor._focus
	await touch(0, Vector2(500, 400), true)
	for i in 8:
		await drag(0, Vector2(500 + i * 15, 400), Vector2(15, 0))
	await touch(0, Vector2(620, 400), false)
	check("a drag moves the ground under the finger", editor._focus.distance_to(looked) > 3.0, "%.1f m" % editor._focus.distance_to(looked))
	var reach := editor._reach
	await touch(0, Vector2(450, 400), true)
	await touch(1, Vector2(650, 400), true)
	for i in 6:
		await drag(1, Vector2(650 + (i + 1) * 20, 400), Vector2(20, 0))
	await touch(1, Vector2(770, 400), false)
	await touch(0, Vector2(450, 400), false)
	check("two fingers drawn apart come nearer", editor._reach < reach * 0.8, "%.0f m to %.0f m" % [reach, editor._reach])
	editor._focus = looked
	editor._reach = reach
	editor._choose({})

	var middle := Vector2(560, 380)
	# A pond
	editor._show_page("Water")
	editor._arm(entry("Water", "Pond"))
	editor._tapped(middle)
	check("a pond is put in and chosen", count("pond") == 1 and editor.chosen.get("kind", "") == "pond")
	var pond: Dictionary = editor.chosen
	var before: float = level.height_at(pond["at"][0], pond["at"][1])
	await wait(1.2)
	var after: float = level.height_at(pond["at"][0], pond["at"][1])
	check("the ground is cut away under it", after < before - 1.0, "%.2f to %.2f" % [before, after])
	check("and there is water in it", level.nodes.get(pond["id"]) is Pool)
	await picture("pond")

	# A river, with a third point
	editor._arm(entry("Water", "River"))
	editor._tapped(Vector2(300, 250))
	var river: Dictionary = editor.chosen
	editor._next = "point"
	editor._tapped(Vector2(700, 520))
	editor._next = ""
	check("a river is put in, and given a third point", river.get("kind", "") == "river" and (river["points"] as Array).size() == 3)
	await wait(1.2)
	check("and there is water along it", level.nodes.get(river["id"]) is Pool)
	await picture("river")

	# A dune placed by hand
	editor._show_page("Ground")
	editor._arm(entry("Ground", "Dune"))
	editor._tapped(Vector2(760, 250))
	var dune: Dictionary = editor.chosen
	await wait(1.2)
	var crest: float = level.height_at(dune["at"][0] - 6.0 * level.terrain.wind.x, dune["at"][1] - 6.0 * level.terrain.wind.y)
	check("a dune stands where one was put", crest > 2.0, "%.2f m" % crest)
	await picture("dune")

	# A door, and a plate that opens it
	editor._show_page("Puzzle")
	editor._arm(entry("Puzzle", "Door"))
	editor._tapped(Vector2(480, 470))
	var door: Dictionary = editor.chosen
	editor._arm(entry("Puzzle", "Pressure plate"))
	editor._tapped(Vector2(560, 520))
	var plate: Dictionary = editor.chosen
	editor._choose(door)
	editor._next = "link"
	var plate_at := editor.cam.unproject_position(level.place_of(plate))
	editor._tapped(plate_at)
	editor._next = ""
	check("the door is worked by the plate", door.get("links", []) == [plate["id"]], str(door.get("links", [])))
	await picture("door_and_plate")

	# A hound, and one of the people
	editor._show_page("People")
	editor._arm(entry("People", "Hound"))
	editor._tapped(Vector2(640, 300))
	check("a hound is put in", level.nodes.get(editor.chosen["id"]) is Hound)
	editor._arm(entry("People", "Townsperson"))
	editor._tapped(Vector2(600, 330))
	check("and a townsperson", level.nodes.get(editor.chosen["id"]) is Townsperson)
	await picture("people")

	# Something that was there already: turned, and moved
	var sphinx := {}
	for item: Dictionary in editor.layout["items"]:
		if item.get("what", "") == "sphinx":
			sphinx = item
	editor._choose(sphinx)
	editor._focus = level.place_of(sphinx)
	editor._reach = 90.0
	var node: Node3D = level.nodes[sphinx["id"]]
	var was := node.global_position
	editor._remember()
	sphinx["yaw"] = 90.0
	editor._changed(sphinx, "yaw")
	editor._next = "move"
	await wait(0.2)
	editor._tapped(Vector2(700, 300))
	check("the sphinx is turned and moved", node.global_position.distance_to(was) > 3.0 and absf(node.rotation_degrees.y - 90.0) < 0.5)
	await picture("sphinx")

	# The ground itself
	editor._show_page("Level")
	editor._remember()
	editor.layout["terrain"]["dune_height"] = 14.0
	editor._shape_in = 0.1
	await wait(1.5)
	check("the dunes are made higher", is_equal_approx(level.terrain.dune_height, 14.0))
	editor._reach = 260.0
	await picture("high_dunes")

	# Saved, and read back
	editor._save_now()
	var saved := LevelLayout.load_layout()
	check("it is saved, and is what the game would now play", LevelLayout.has_saved() and saved["items"].size() == editor.layout["items"].size() and saved["items"].size() == things + 7, "%d things" % saved["items"].size())

	# Undone, all the way
	var steps := 0
	while not editor._undo.is_empty() and steps < 60:
		editor._step_back()
		steps += 1
	await wait(0.3)
	check("undone, it is as it was", editor.layout["items"].size() == things and count("pond") == 0 and is_equal_approx(level.terrain.dune_height, 7.0), "%d steps" % steps)
	editor._reach = 90.0
	await picture("undone")

	# The level as text, and back
	var text := LevelLayout.to_text(editor.layout)
	check("the level goes to text and comes back the same", LevelLayout.to_text(LevelLayout.from_text(text)) == text)

	LevelLayout.forget_saved()
	if kept != "":
		var file := FileAccess.open(LevelLayout.SAVED, FileAccess.WRITE)
		file.store_string(kept)
		file.close()
	print("EDITOR TEST: %s" % ("all passed" if failed == 0 else "%d FAILED" % failed))
	paused = false
	quit()
