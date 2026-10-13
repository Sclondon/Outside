extends SceneTree
## Not part of the game. Goes from each level to the others by every way there is (the notebook's map
## and list, the tomb's card, a doorway of the Valley of the Kings and back outside, each editor's Play
## and the way back, starting again, the level being put back as it came, the game's first start, a
## level that is not there) with the notebook's page asked for (`Loading.instant = false`), and checks
## of each change: the page was right across before the old level went and stayed so until the new one
## was built and stood ready; nothing pressed meanwhile did anything; a tomb's clock did not run; and at
## the end no page is left, the game is not stopped and he can be walked. Nothing of the player's is written.
## godot --headless --path . --fixed-fps 60 --script tools/loading_test.gd

var failed := 0
## What was seen of the change now being made.
var seen := {}
var old_scene: Node


func _initialize() -> void:
	run.call_deferred()


func check(what: String, good: bool, note := "") -> void:
	print("%s  %s%s" % ["ok   " if good else "FAIL ", what, "   (%s)" % note if note != "" else ""])
	if not good:
		failed += 1


func level() -> Node:
	return current_scene.get_node_or_null("Level") if current_scene else null


func boy() -> Player:
	return current_scene.get_node_or_null("Player") as Player if current_scene else null


func menu() -> GameMenu:
	return current_scene.get_node_or_null("HUD/Menu") as GameMenu


func frames(count: int) -> void:
	for i in count:
		await physics_frame
		await process_frame


func button(text: String) -> Button:
	for found in current_scene.find_children("*", "Button", true, false):
		if (found as Button).text == text and (found as Button).is_visible_in_tree():
			return found
	return null


## Works a place on the notebook's pages that can be touched, by its name.
func spot(part: String, id: String) -> bool:
	var book := menu()
	book._set_open(true)
	book._turn_to(part)
	book._out = 1.0
	book._turn = 1.0
	book._arrange()
	book._refresh()
	await frames(3)
	for found: Dictionary in book._spots:
		if found["id"] == id:
			(found["act"] as Callable).call()
			return true
	return false


func _on_covered() -> void:
	seen["covered"] = true
	seen["old_there"] = old_scene == null or (is_instance_valid(old_scene) and old_scene.is_inside_tree())
	seen["across_at_covered"] = Loading.page().across


func _on_ready_under() -> void:
	seen["ready"] = true
	seen["across_at_ready"] = Loading.page().across
	var him := boy()
	seen["on_floor"] = him == null or him.is_on_floor() or not him.is_physics_processing()
	seen["eye_at"] = root.get_camera_3d().global_position if root.get_camera_3d() else Vector3.ZERO
	seen["stood_at"] = him.global_position if him else Vector3.ZERO
	var camera := current_scene.get_node_or_null("Camera") as Camera3D if current_scene else null
	seen["camera_near"] = camera == null or him == null or camera.global_position.distance_to(him.global_position) < 40.0
	var tomb := level() as TombLevel
	seen["built"] = true
	if level() is Desert:
		seen["built"] = (level() as Desert).terrain.ground != null and (level() as Desert).nodes.size() > 20 and (level() as Desert).wind != null
	elif tomb:
		seen["built"] = tomb.built != null and tomb._player != null
	elif current_scene.scene_file_path == "res://test_yard.tscn":
		seen["built"] = level().get_child_count() > 100


## Makes a change of level with `start`, presses things all through it, and checks how it went.
## `to` is the scene it should end in; `stays` for a change that keeps the level that is there.
func change(what: String, to: String, start: Callable, stays := false) -> void:
	print("--- ", what)
	seen = {"low": 2.0, "second": true}
	old_scene = current_scene
	var was := old_scene.get_instance_id() if old_scene else 0
	var count := Loading.count
	await start.call()
	check("it was asked of Loading, once", Loading.busy and (stays or Loading.count == count + 1), "busy %s, count %d -> %d" % [Loading.busy, count, Loading.count])
	if not Loading.busy:
		return
	count = Loading.count
	# (held down the whole time: the stick over, jump)
	Input.action_press(&"move_right")
	Input.action_press(&"move_up")
	Input.action_press(&"jump")
	var guard := 0
	while Loading.busy and guard < 20000:
		guard += 1
		await process_frame
		if not Loading.busy:
			break
		var page := Loading.page()
		if seen.get("covered", false) and not seen.get("ready", false):
			seen["low"] = minf(seen["low"], page.across)
			seen["high"] = maxf(seen.get("high", 0.0), page.across)
		if guard % 7 == 3:
			# Esc for the menu, a finger on the notebook in the corner and one in the middle, and another change asked for
			var key := InputEventAction.new()
			key.action = &"ui_cancel"
			key.pressed = true
			root.push_input(key)
			for at: Vector2 in [Vector2(root.get_visible_rect().size.x - 60.0, 30.0), root.get_visible_rect().size * 0.5]:
				for down: bool in [true, false]:
					var finger := InputEventScreenTouch.new()
					finger.index = 0
					finger.position = at
					finger.pressed = down
					root.push_input(finger)
			seen["second"] = seen["second"] and not Loading.go("res://test_yard.tscn") and not Loading.again()
	check("the page was right across before the old level went", seen.get("covered", false) and seen.get("old_there", false) and is_equal_approx(seen.get("across_at_covered", 0.0), 1.0), str(seen.get("across_at_covered", -1.0)))
	check("and stayed across until the new one was ready", seen.get("ready", false) and is_equal_approx(seen["low"], 1.0) and is_equal_approx(seen.get("high", 1.0), 1.0) and is_equal_approx(seen.get("across_at_ready", 0.0), 1.0), "from %s to %s" % [seen["low"], seen.get("high", 1.0)])
	if stays:
		check("the level that was there is still there", current_scene == old_scene)
	else:
		check("the new level is %s" % to, current_scene != null and current_scene.scene_file_path == to and current_scene.get_instance_id() != was, current_scene.scene_file_path if current_scene else "none")
		check("built, him on the ground, the camera by him, when the page came off", seen.get("built", false) and seen.get("on_floor", false) and seen.get("camera_near", false), "built %s, on the floor %s, camera %s" % [seen.get("built"), seen.get("on_floor"), seen.get("camera_near")])
	check("a second change asked for meanwhile was refused", seen["second"] and Loading.count == count)
	var book := menu() if current_scene and current_scene.has_node("HUD/Menu") else null
	check("nothing pressed meanwhile did anything: the notebook is shut and the game is not stopped", (book == null or not book._open) and (not paused or stays), "paused %s" % paused)
	var him := boy()
	var tomb := level() as TombLevel
	if him and not stays:
		var moved := Vector2(him.global_position.x - seen["stood_at"].x, him.global_position.z - seen["stood_at"].z).length()
		check("he did not walk or jump while it was up", moved < 0.25 and him.velocity.y < 0.5, "moved %.2f m" % moved)
	if tomb and not stays:
		check("the tomb's clock did not run", tomb.ticks == 0 and not tomb._started, "%d ticks" % tomb.ticks)
	var swept: float = (root.get_camera_3d().global_position.distance_to(seen["eye_at"]) if root.get_camera_3d() and not stays else 0.0)
	check("the camera was where it starts before the page came off", swept < 1.5, "it went %.2f m as the page went" % swept)
	check("no page is left", not Loading.busy and not Loading.page().visible and Loading.page().across == 0.0)
	Input.action_release(&"jump")
	Input.action_release(&"move_up")
	Input.action_release(&"move_right")
	if tomb and not stays and not tomb._held:
		# The clock starts at his first step, as it always did: not before, and then at once.
		await frames(20)
		check("with nothing pressed the clock still waits", tomb.ticks == 0)
		Input.action_press(&"move_right")
		Input.action_press(&"move_up")
		var steps := 0
		while not tomb._started and steps < 240:
			steps += 1
			await frames(1)
		var at_start := him.global_position.distance_to(tomb.layout.start)
		await frames(10)
		Input.action_release(&"move_right")
		Input.action_release(&"move_up")
		check("and starts at his first step", tomb._started and tomb.ticks >= 10 and tomb.ticks <= 12 and at_start < 0.9, "started %s, %d ticks, %.2f m from the start" % [tomb._started, tomb.ticks, at_start])
	elif him and not stays and not (tomb and tomb._held):
		var from := him.global_position
		Input.action_press(&"move_right")
		await frames(45)
		Input.action_release(&"move_right")
		check("and he can be walked again", him.global_position.distance_to(from) > 0.3, "%.2f m" % him.global_position.distance_to(from))
	await frames(4)


func run() -> void:
	Loading.instant = false
	TombLevel.bare = false
	# (nothing of the player's is read or written: the desert the game came with, and files of this test's own)
	LevelLayout.saved_at = "user://loading_test_layout.json"
	TombSpec.path = "user://loading_test_my_tombs.json"
	TombDaily.path = "user://loading_test_tombs.json"
	for file: String in [LevelLayout.saved_at, TombSpec.path, TombDaily.path]:
		if FileAccess.file_exists(file):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(file))
	var page := Loading._the_page()
	page.covered.connect(_on_covered)
	page.ready_under.connect(_on_ready_under)

	# The game's first start: the page is there at once, and the first level builds behind it.
	print("--- the first start")
	change_scene_to_file("res://start.tscn")
	await process_frame
	await process_frame
	check("the game starts with the page already up", Loading.busy and page.visible and is_equal_approx(page.across, 1.0), str(page.across))
	await page.finished
	check("and opens in the desert", current_scene.scene_file_path == "res://desert.tscn" and not Loading.busy and not paused and boy().is_on_floor())
	check("the desert was built in stages", Loading.stages.has("Laying out the sand") and Loading.stages.has("Setting out the dig") and Loading.stages.has("Raising the wind"), str(Loading.stages.keys()))
	await frames(5)

	await change("the notebook's list: desert to the test yard", "res://test_yard.tscn", func() -> void: await spot("places", "go:res://test_yard.tscn"))
	check("the yard was built in stages", Loading.stages.has("Setting up: hounds") and Loading.stages.has("Setting up: the sand"))
	await change("the notebook: start this place again", "res://test_yard.tscn", func() -> void: await spot("places", "restart"))
	await change("the notebook's map: test yard to the tombs", "res://tomb.tscn", func() -> void: await spot("places", "map:res://tomb.tscn"))
	check("today's tomb is behind its card, and he is held", (level() as TombLevel)._held and button("Play today's tomb") != null)
	await change("the tomb's card: one for practice", "res://tomb.tscn", func() -> void: button("Middling").pressed.emit())
	check("it is a tomb for practice, with no card", (level() as TombLevel).mode == "random" and button("Play today's tomb") == null)
	await change("the tomb's card: walked through", "res://tomb.tscn", func() -> void: (level() as TombLevel)._open_tomb({"mode": "random", "seed": 12, "difficulty": 1, "view": "3d"}))
	check("it is walked through", (level() as TombLevel).view == "3d")
	await change("the tomb's card: branching", "res://tomb.tscn", func() -> void: (level() as TombLevel)._open_tomb({"mode": "random", "seed": 12, "difficulty": 1, "shape": "branching"}))
	await change("the tomb to the tomb editor", "res://tomb_editor.tscn", func() -> void: (level() as TombLevel)._to_editor())
	await change("the tomb editor's Play", "res://tomb.tscn", func() -> void: (current_scene as TombEditor).play())
	check("it is the tomb made by hand", (level() as TombLevel).mode == "custom")
	await change("and back to the tomb editor", "res://tomb_editor.tscn", func() -> void: (level() as TombLevel)._to_editor())
	await change("the tomb editor's way out", "res://tomb.tscn", func() -> void: (current_scene as TombEditor).leave())
	await change("the notebook's list: the tombs to the desert", "res://desert.tscn", func() -> void: await spot("places", "go:res://desert.tscn"))

	# Where there is no other thread to read a level's file on (a web build without them), it is read in one go.
	Loading.threads = false
	await change("with no threads: the desert to the test yard", "res://test_yard.tscn", func() -> void: await spot("places", "go:res://test_yard.tscn"))
	check("the page said it was finding the place first", Loading.stages.has("Finding the place"), str(Loading.stages.keys()))
	await change("with no threads: and back to the desert", "res://desert.tscn", func() -> void: await spot("places", "map:res://desert.tscn"))
	Loading.threads = OS.has_feature("threads")

	# In at a doorway of the Valley of the Kings, and back outside by the card at the end.
	var door: TombDoor
	for node in current_scene.find_children("*", "Node3D", true, false):
		if node is TombDoor and not (node as TombDoor).tomb().is_empty():
			door = node
			break
	check("the desert has a doorway that leads to a tomb", door != null)
	if door:
		await change("a doorway into its tomb", "res://tomb.tscn", func() -> void: door.enter())
		check("the way back is kept", TombLevel.back_to == "res://desert.tscn" and TombLevel.back_at != Vector3.INF)
		var back := TombLevel.back_at
		var tomb := level() as TombLevel
		tomb.has_treasure = true
		tomb._finish()
		await frames(3)
		check("the card at the end offers the way back outside", button("Back outside") != null)
		await change("back outside", "res://desert.tscn", func() -> void: button("Back outside").pressed.emit())
		check("he is before the doorway he went in at", Vector2(boy().global_position.x - back.x, boy().global_position.z - back.z).length() < 3.0, str(boy().global_position))

	# The level editor: Play, and the level put back as it came (which keeps the scene, and the editor).
	menu()._edit()
	await frames(4)
	var editor := get_first_node_in_group(&"level_editor") as LevelEditor
	check("the level editor is open", editor != null and editor.visible and paused)
	if editor:
		await change("the level editor: back to the original level", "res://desert.tscn", func() -> void: editor._back_to_original(), true)
		check("the editor is still open over the stopped game", editor.visible and paused and (level() as Desert).nodes.size() > 20)
		await change("the level editor's Play", "res://desert.tscn", func() -> void: editor._play(false))

	# A level that is not there: the page says so, and he is back where he was.
	print("--- a level that is not there")
	var here := current_scene
	Loading.go("res://no_such_level.tscn")
	await process_frame
	await process_frame
	var said := false
	while Loading.busy:
		said = said or page._trouble != ""
		await process_frame
	check("the page said it could not be found", said)
	check("and he is back in the level he was in, with no page", current_scene == here and here.is_inside_tree() and not page.visible and not paused)
	var from := boy().global_position
	Input.action_press(&"move_right")
	await frames(45)
	Input.action_release(&"move_right")
	check("and can be walked", boy().global_position.distance_to(from) > 0.3)

	# With `instant` set there is no page at all: the scene is changed as it always was.
	print("--- asked to be instant")
	Loading.instant = true
	Loading.go("res://test_yard.tscn")
	check("no page is asked for", not Loading.busy and not page.visible)
	await frames(3)
	check("and the level has changed by the next frames", current_scene != null and current_scene.scene_file_path == "res://test_yard.tscn" and current_scene.get_node("Level").get_child_count() > 100)
	Loading.again()
	await frames(3)
	check("and the same starting again", current_scene != null and current_scene.scene_file_path == "res://test_yard.tscn" and not Loading.busy)

	for file: String in [LevelLayout.saved_at, TombSpec.path, TombDaily.path]:
		if FileAccess.file_exists(file):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(file))
	print("PASSED" if failed == 0 else "FAILED (%d)" % failed)
	quit(1 if failed > 0 else 0)
