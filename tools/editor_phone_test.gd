extends SceneTree
## Not part of the game. Works the level editor as it is laid out for a phone, with nothing but touches: every
## button is found on the screen by its word and touched in its middle, as a thumb would. Puts in a door, a plate, a
## bridge and a sign; chooses, moves (by the ring, by the arrows, held), raises and turns; changes a number (a tap,
## a hold, the slider), a switch, one of a list and words; joins the plate to the door both ways about; removes and
## undoes; drags a page by its buttons; saves and reads back; plays the level and comes back to the editor.
## At each state it measures what there is to touch (`tools/touch_audit.gd`) and fails if any of it is under 88
## pixels, nearer the next than 12, or in the margins. Saves a picture of each.
## What it makes is kept in a file of its own, not where the game keeps a level made on this device.
## godot --path . --resolution 1560x720 --script tools/editor_phone_test.gd -- <outdir> phone

const Audit := preload("res://tools/touch_audit.gd")

var out := ""
var editor: LevelEditor
var ui: LevelEditorPhone
var level: Desert
var failed := 0
var shot := 0
var least := 1.0e9
var least_name := ""
var least_text := 999


func _initialize() -> void:
	# (levels are changed at once here, with no notebook page over them: tools/loading_test.gd tries that)
	Loading.instant = true
	DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_NO_FOCUS, true)
	DisplayServer.window_set_position(Vector2i(-6000, -6000))
	# (a real gamepad on the desk is heard whether the window has the focus or not, and somebody may be playing: none is listened to)
	Gamepad.device = 99
	out = OS.get_cmdline_user_args()[0]
	DirAccess.make_dir_recursive_absolute(out)
	run.call_deferred()


func check(what: String, good: bool, note := "") -> void:
	print("%s  %s%s" % ["ok   " if good else "FAIL ", what, "   (%s)" % note if note != "" else ""])
	if not good:
		failed += 1


# A picture of the screen, and a measure of what there is to touch on it.
func state(name: String) -> void:
	for i in 4:
		await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(out.path_join("%02d_%s.png" % [shot, name]))
	shot += 1
	var result := Audit.measure(editor)
	if result["count"] > 0 and result["area"] < least:
		least = result["area"]
		least_name = "%s (in '%s')" % [result["smallest"], name]
	least_text = mini(least_text, result["text"])
	var good: bool = result["small"] == 0 and result["close"] == 0 and result["edge"] == 0 and result["text"] >= Audit.TEXT
	check("to touch in '%s'" % name, good, Audit.line("", result).strip_edges())
	for line: String in result["lines"]:
		print("        ", line)


func frames(count: int) -> void:
	for i in count:
		await process_frame


func wait(seconds: float) -> void:
	var until := Time.get_ticks_msec() + int(seconds * 1000.0)
	while Time.get_ticks_msec() < until:
		await process_frame


# A finger, as the phone would report it: through the game's own input, so that buttons feel it too.
func finger(index: int, at: Vector2, down: bool) -> void:
	var event := InputEventScreenTouch.new()
	event.index = index
	event.position = at * window_scale()
	event.pressed = down
	Input.parse_input_event(event)
	await frames(2)


func slide(index: int, from: Vector2, to: Vector2, steps := 8) -> void:
	for i in steps:
		var event := InputEventScreenDrag.new()
		event.index = index
		event.position = from.lerp(to, float(i + 1) / steps) * window_scale()
		event.relative = (to - from) / steps * window_scale()
		Input.parse_input_event(event)
		await frames(2)


# (the screen is stretched to fit the window: a touch is reported in the window's own pixels)
func window_scale() -> float:
	return float(DisplayServer.window_get_size().y) / root.get_visible_rect().size.y


func tap(at: Vector2) -> void:
	await finger(0, at, true)
	await frames(2)
	await finger(0, at, false)
	await frames(3)


func swipe(from: Vector2, to: Vector2) -> void:
	await finger(0, from, true)
	await slide(0, from, to)
	await finger(0, to, false)
	await frames(3)


# The button on show that is called this, or whose words begin with it.
func button(word: String) -> Control:
	for found: Node in ui.find_children("*", "BaseButton", true, false):
		var control := found as BaseButton
		if not control.is_visible_in_tree():
			continue
		if String(control.get_meta(&"word", "")) == word or (control is Button and (control as Button).text.begins_with(word)):
			return control
	return null


# Brings a row of a page into sight by dragging the page, as a thumb would.
func bring(control: Control) -> void:
	var body := ui._page_body
	if not body.is_ancestor_of(control):
		return
	for i in 14:
		var window := body.get_global_rect().grow(-50.0)
		var middle := control.get_global_rect().get_center()
		if middle.y >= window.position.y and middle.y <= window.end.y:
			return
		var by := clampf(window.get_center().y - middle.y, -260.0, 260.0)
		await swipe(Vector2(window.position.x + 200.0, window.get_center().y - by * 0.5), Vector2(window.position.x + 200.0, window.get_center().y + by * 0.5))
		await wait(0.3)


func press(word: String) -> bool:
	var control := button(word)
	if control == null:
		check("there is '%s' to touch" % word, false)
		return false
	await bring(control)
	await tap(control.get_global_rect().get_center())
	return true


func hold(word: String, seconds: float) -> void:
	var control := button(word)
	if control == null:
		check("there is '%s' to hold" % word, false)
		return
	await bring(control)
	var at := control.get_global_rect().get_center()
	await finger(0, at, true)
	await wait(seconds)
	await finger(0, at, false)
	await frames(3)


func spot(item: Dictionary) -> Vector2:
	return editor.cam.unproject_position(level.place_of(item))


func again(item: Dictionary) -> Dictionary:
	for found: Dictionary in editor.layout["items"]:
		if found["id"] == item["id"]:
			return found
	return {}


func count(kind: String) -> int:
	var found := 0
	for item: Dictionary in editor.layout["items"]:
		if item["kind"] == kind:
			found += 1
	return found


# Puts a thing in by touch: Add, its kind, itself, and the ground.
func add(kind: String, name: String, at: Vector2) -> Dictionary:
	await press("Add")
	await press(kind)
	await press(name)
	await tap(at)
	return editor.chosen


func run() -> void:
	LevelLayout.saved_at = "user://editor_phone_test.json"
	LevelLayout.forget_saved()
	var scene: Node = load("res://desert.tscn").instantiate()
	root.add_child(scene)
	current_scene = scene
	for i in 30:
		await physics_frame
	level = scene.get_node("Level")
	editor = LevelEditor.new()
	check("asked for with `-- phone`, it is laid out for a phone", editor.phone)
	scene.get_node("HUD").add_child(editor)
	editor.open()
	ui = editor._phone
	await wait(0.3)
	var screen := root.get_visible_rect().size
	print("SCREEN ", screen, " in a window of ", DisplayServer.window_get_size())
	check("it opens over the level, and the game stands still", editor.visible and paused)
	check("the bar has six buttons, and Undo is one", ui._bar.get_child_count() == 6 and button("Undo") != null)
	var things: int = editor.layout["items"].size()
	var props := count("prop")
	await state("opened")

	# Looking about
	var middle := screen * 0.5
	var looked := editor._focus
	await swipe(middle + Vector2(-60, 40), middle + Vector2(60, 40))
	check("one finger drags the ground", editor._focus.distance_to(looked) > 3.0, "%.1f m" % editor._focus.distance_to(looked))
	var reach := editor._reach
	await finger(0, middle + Vector2(-100, 40), true)
	await finger(1, middle + Vector2(100, 40), true)
	await slide(1, middle + Vector2(100, 40), middle + Vector2(240, 40))
	await finger(1, middle + Vector2(240, 40), false)
	await finger(0, middle + Vector2(-100, 40), false)
	check("two fingers drawn apart come nearer", editor._reach < reach * 0.8, "%.0f m to %.0f m" % [reach, editor._reach])
	await press("View")
	await state("view")
	reach = editor._reach
	await press("Further")
	check("and so does a button, for one hand", editor._reach > reach * 1.05)
	var yaw := editor._yaw
	await hold("turn_left", 1.2)
	check("held, a button keeps on", absf(editor._yaw - yaw) > 0.3, "%.2f" % absf(editor._yaw - yaw))
	editor._yaw = 0.0
	await press("Done")
	check("Done puts the sheet away", ui.panel == "" and not ui._sheet.visible)
	await press("Add")
	await press("Done")
	check("and a page", ui.panel == "" and not ui._page.visible and ui._bar.visible)
	editor._focus = looked
	editor._reach = 60.0
	await frames(3)

	# Putting things in
	await press("Add")
	await state("add")
	await press("Puzzle")
	await state("puzzle")
	check("the page of puzzle parts has every one of them", ui._rows.find_children("*", "Button", true, false).size() == (LevelLayout.PALETTE["Puzzle"] as Array).size())
	# (a finger dragging the page by a button moves the page, and does not press the button)
	var grip := button("Sluice").get_global_rect().get_center()
	await swipe(grip, grip + Vector2(0, -170))
	check("a page is dragged by its buttons, and they are not pressed", ui._page_body.scroll > 100.0 and ui.panel == "kind", "to %.0f of %.0f" % [ui._page_body.scroll, ui._page_body.most()])
	await press("Scarab socket")
	check("the last of them is reached by dragging, and touched", ui.panel == "place" and editor._armed[0] == "Scarab socket")
	await press("Another kind")
	check("Another kind goes back for another", ui.panel == "kind")
	# (the level has doors of its own: at Abu Simbel)
	var doors := count("door")
	await press("Door")
	check("touching Door says what to do next", ui.panel == "place" and ui._line.text.begins_with("Door: tap the ground"), ui._line.text)
	await state("placing")
	await tap(middle + Vector2(-40, 30))
	var door: Dictionary = editor.chosen
	check("a touch on the ground puts a door there, and it is chosen", count("door") == doors + 1 and door.get("kind", "") == "door" and level.nodes.get(door.get("id", -1)) != null)
	check("and its sheet is up", ui.panel == "thing" and button("Move") != null and button("Opened by") != null)
	await state("door")
	var plate := await add("Puzzle", "Pressure plate", middle + Vector2(200, 110))
	check("a pressure plate is put in", plate.get("kind", "") == "plate")
	await press("Add")
	await press("Puzzle")
	await press("Bridge or lift")
	await swipe(middle + Vector2(0, 60), middle + Vector2(150, -20))
	await press("Put here")
	var bridge: Dictionary = editor.chosen
	var under := editor.ground_under(middle)
	check("Put here puts a bridge at the cross", bridge.get("kind", "") == "mover" and Vector2(bridge["at"][0], bridge["at"][1]).distance_to(Vector2(under.x, under.z)) < 0.5)
	await swipe(middle + Vector2(150, -20), middle + Vector2(0, 60))

	# Choosing, and moving
	await tap(spot(door))
	check("a touch on the door chooses it", editor.chosen.get("id", -1) == door["id"], LevelLayout.label(editor.chosen) if not editor.chosen.is_empty() else "nothing")
	await tap(spot(plate))
	check("and one on the plate chooses that instead", editor.chosen.get("id", -1) == plate["id"])
	var was := Vector2(plate["at"][0], plate["at"][1])
	var from := spot(plate)
	await swipe(from + Vector2(20, 10), from + Vector2(-70, -50))
	var now := Vector2(plate["at"][0], plate["at"][1])
	check("dragged by its ring, it moves as far as the finger", now.distance_to(was) > 1.0 and editor.chosen.get("id", -1) == plate["id"], "%.2f m" % now.distance_to(was))
	check("and the plate itself is there", Vector2(level.nodes[plate["id"]].global_position.x, level.nodes[plate["id"]].global_position.z).distance_to(now) < 0.05)
	await press("Move")
	await state("move")
	was = now
	await press("Right")
	now = Vector2(plate["at"][0], plate["at"][1])
	check("an arrow moves it a step", is_equal_approx(now.distance_to(was), editor._nudge), "%.2f m" % now.distance_to(was))
	var undos := editor._undo.size()
	was = now
	await hold("Far", 1.3)
	now = Vector2(plate["at"][0], plate["at"][1])
	check("held, it keeps going; and that is one thing to undo", now.distance_to(was) > 2.5 and editor._undo.size() == undos + 1, "%.1f m, %d to undo" % [now.distance_to(was), editor._undo.size() - undos])
	await press("Step")
	check("Step changes how far a step is", is_equal_approx(editor._nudge, 5.0))
	await press("Step")
	await press("Step")
	await press("Step")
	var lift: float = plate["lift"]
	await press("Raise")
	check("Raise lifts it a step", is_equal_approx(plate["lift"], lift + 1.0), "%.2f to %.2f" % [lift, plate["lift"]])
	await press("Lower")
	await press("turn_left")
	check("Turn turns it", is_equal_approx(plate["yaw"], 15.0) and absf(level.nodes[plate["id"]].rotation_degrees.y - 15.0) < 0.5)
	await press("turn_right")
	await swipe(middle + Vector2(0, 60), middle + Vector2(40, 90))
	await press("Here")
	under = editor.ground_under(middle)
	check("Here brings it to the cross", Vector2(plate["at"][0], plate["at"][1]).distance_to(Vector2(under.x, under.z)) < 0.5)
	await press("Undo")
	check("Undo is there to be touched the while", ui.panel == "move" and editor.chosen.get("id", -1) == plate["id"])
	# (undone, the level is made again from what it was: these are new, though the same)
	door = again(door)
	plate = again(plate)
	bridge = again(bridge)
	await press("Done")
	check("Done goes back to the thing's sheet", ui.panel == "thing")
	await tap(spot(door))

	# Changing it: a number three ways, a switch, one of a list, words
	await press("Change")
	await state("change_door")
	var wide: float = door["wide"]
	var row := button("Width")
	await tap(row.get_parent().get_child(2).get_global_rect().get_center())
	check("plus takes a number up a step", is_equal_approx(door["wide"], wide + 0.1) and (row as Button).text == "Width: 3.1", (row as Button).text)
	var held := row.get_parent().get_child(2) as Control
	await finger(0, held.get_global_rect().get_center(), true)
	await wait(2.6)
	await finger(0, held.get_global_rect().get_center(), false)
	check("held, plus runs, and faster", door["wide"] > wide + 2.0, "%.1f" % door["wide"])
	await tap(row.get_parent().get_child(1).get_global_rect().get_center())
	await press("Width")
	check("a touch on its name puts the page away, to see it change", ui.panel == "number" and ui._sheet.visible and not ui._page.visible)
	await state("number")
	var slider := ui._sheet_row.get_child(2) as Control
	var track := slider.get_global_rect()
	await swipe(Vector2(track.position.x + 60.0, track.get_center().y), Vector2(track.end.x - 36.0, track.get_center().y))
	check("the slider takes it all the way", is_equal_approx(door["wide"], 12.0), "%.1f" % door["wide"])
	check("and the door is made that wide", level.nodes[door["id"]] != null)
	await press("minus")
	check("minus beside it takes it down a step", is_equal_approx(door["wide"], 11.9), "%.2f" % door["wide"])
	await press("Done")
	check("Done goes back to the page", ui.panel == "change" and ui._page.visible)
	await press("Needs every one")
	check("a switch is turned on by a touch", door["needs_all"] == true and (button("Needs every one") as Button).text.ends_with("yes"))
	await state("change_door_end")
	await press("Done")
	check("Done puts the page away", ui.panel == "thing" and not ui._page.visible)

	await tap(spot(bridge))
	check("the bridge is chosen by a touch", editor.chosen.get("id", -1) == bridge["id"])
	await press("Change")
	await press("Which way")
	await state("choice")
	await press("Up")
	check("one of a list is chosen from a page of them", int(bridge["way"]) == 1 and ui.panel == "change" and button("Which way: Up") != null)
	await press("Done")

	var sign := await add("Puzzle", "Sign", middle + Vector2(-230, -30))
	await press("Change")
	await press("Says")
	check("words are typed on a page of their own, with the line at the top", ui.panel == "words" and ui._entry.get_global_rect().end.y < screen.y * 0.4 and ui._entry.has_focus(), str(ui._entry.get_global_rect()))
	await state("words")
	await press("Rub it out")
	for letter: String in "DIG".split(""):
		var key := InputEventKey.new()
		key.keycode = OS.find_keycode_from_string(letter)
		key.unicode = letter.unicode_at(0)
		key.pressed = true
		root.push_input(key)
		await frames(2)
	await press("Done")
	check("and the sign says them", sign.get("text", "") == "DIG" and ui.panel == "change", str(sign.get("text", "")))
	await press("Done")

	# Joining: from the plate, then from the door
	await tap(spot(plate))
	check("the plate is chosen by a touch", editor.chosen.get("id", -1) == plate["id"])
	await state("plate")
	await press("Works")
	check("Works says what to touch next", ui.panel == "link_from" and ui._line.text.contains("Tap each door"), ui._line.text)
	await state("joining_from_plate")
	await tap(spot(door))
	check("plate, Works, door: the door is opened by the plate", door.get("links", []) == [plate["id"]], str(door.get("links", [])))
	await press("Done")
	await tap(spot(door))
	await press("Opened by")
	check("Opened by says what to touch next", ui.panel == "link" and ui._line.text.contains("Tap each plate") and ui._line.text.contains("1 so far"), ui._line.text)
	await state("joining_from_door")
	await tap(spot(plate))
	check("a touch on the plate again undoes it", door.get("links", []) == [])
	await tap(spot(plate))
	check("and another joins them again", door.get("links", []) == [plate["id"]])
	await press("Done")

	# Removing, and undoing
	await tap(spot(sign))
	check("the sign is chosen by a touch", editor.chosen.get("id", -1) == sign["id"])
	await press("Remove")
	check("Remove takes it away, and says Undo brings it back", count("sign") == 0 and ui._line.text.contains("Undo") and ui.panel == "", ui._line.text)
	await state("removed")
	await press("Undo")
	check("Undo, one touch, brings it back", count("sign") == 1)
	await press("More")
	await state("more")
	await press("Redo")
	check("Redo is in More", count("sign") == 0 and ui.panel == "")
	await add("Camp", "Palm", middle + Vector2(-300, 120))
	await press("Add")
	await press("Camp")
	await press("Palm")
	await press("Undo")
	check("Undo while putting a thing in takes back the last one", count("prop") == props)
	await tap(middle + Vector2(-300, 120))
	check("and a touch still puts in what was being put in", editor.chosen.get("what", "") == "palm_a" and count("prop") == props + 1)
	await press("Remove")
	check("which Remove takes away", count("prop") == props)
	await press("Undo")

	# The desert itself
	await press("Level")
	await state("level")
	var size: float = editor.layout["terrain"]["dune_height"]
	row = button("Height of the dunes")
	await tap(row.get_parent().get_child(2).get_global_rect().get_center())
	await press("Weather")
	await press("A storm")
	check("the level has its own page", is_equal_approx(editor.layout["terrain"]["dune_height"], size + 0.25) and int(editor.layout["weather"]) == 2)
	await press("Done")
	await wait(1.4)
	check("and the dunes are made again", is_equal_approx(level.terrain.dune_height, size + 0.25))

	# Kept
	await press("More")
	await press("Save now")
	var saved := LevelLayout.load_layout()
	check("it is saved, and is what the game would now play", LevelLayout.has_saved() and saved["items"].size() == things + 4, "%d things, %d before" % [saved["items"].size(), things])
	var kept_door := {}
	for item: Dictionary in saved["items"]:
		if item["id"] == door["id"]:
			kept_door = item
	check("as it was made", kept_door.get("links", []) == [plate["id"]] and is_equal_approx(kept_door.get("wide", 0.0), 11.9) and kept_door.get("needs_all", false) == true)
	check("in the same form as ever", saved.keys() == LevelLayout.built_in().keys() and kept_door.keys() == LevelLayout.new_item(saved, "door", "", Vector2.ZERO).keys(), str(kept_door.keys()))
	await press("More")
	await press("The level as text")
	await state("level_as_text")
	check("the level as text is there to copy", ui._level_text.text == LevelLayout.to_text(editor.layout))
	await press("Done")
	check("Done on a page inside More goes back to More", ui.panel == "more")
	await press("Back to the level")
	await state("original")
	await press("No")
	await press("How it all works")
	await state("help")
	await press("Done")
	await press("Done")
	check("and Done again to the level", ui.panel == "")

	# Played, and back
	await press("Play")
	for i in 90:
		await physics_frame
	check("Play starts the level", not paused and current_scene != null and current_scene != scene and current_scene.get_node_or_null("Level") is Desert)
	var playing := current_scene.get_node("Level") as Desert
	check("with what was made in it", playing.layout["items"].size() == things + 4)
	(current_scene.get_node("HUD/Menu") as GameMenu)._edit()
	await wait(0.3)
	editor = get_first_node_in_group(&"level_editor") as LevelEditor
	check("the notebook's Edit this level comes back to the editor, laid out for a phone", editor != null and editor.visible and editor.phone and paused)
	ui = editor._phone
	level = playing
	await state("back")

	LevelLayout.forget_saved()
	print("smallest thing to touch: %s; smallest writing: %d" % [least_name, least_text])
	print("EDITOR PHONE TEST: %s" % ("all passed" if failed == 0 else "%d FAILED" % failed))
	paused = false
	quit(1 if failed > 0 else 0)
