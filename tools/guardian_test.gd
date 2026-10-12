extends SceneTree
## Not part of the game. Runs the gate guardians and the leaves of the Book of the Dead with nothing drawn and says
## whether each thing happened. First on a bare floor, with the boy: a guardian asks when he steps onto its threshold
## and when he acts at it; without the leaf no English is shown, and the names are the same every time; "Step back"
## says nothing; a wrong name (touched on the screen) makes it strike and catches him, and deals new names; a leaf is
## taken by walking onto it, comes up to be read and is put away by a touch; with the leaf the English is shown, and
## the right name (touched) turns the guardian on and unbars its gateway; a leaf with no name chosen takes the nearest
## guardian's. Then in the desert, made from items as the level editor makes them: the right name opens a linked
## door, a wrong one lays him out, and a level started again has forgotten its leaves.
## godot --headless --path . --fixed-fps 60 --script tools/guardian_test.gd
## Ends with PASSED or FAILED (and exits 0 or 1).

var stage: Node3D
var failed := 0
var boy: Player
var level: Desert


func _initialize() -> void:
	LevelLayout.saved_at = "user://guardian_test_layout.json"
	stage = Node3D.new()
	stage.name = "Stage"
	root.add_child(stage)
	var sun := DirectionalLight3D.new()
	stage.add_child(sun)
	var body := StaticBody3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(200, 2, 200)
	var collider := CollisionShape3D.new()
	collider.shape = shape
	body.add_child(collider)
	body.position = Vector3(0, -1, 0)
	stage.add_child(body)
	run.call_deferred()


func check(what: String, passed: bool, detail := "") -> void:
	print("PASS " if passed else "FAIL ", what, "  ", detail)
	if not passed:
		failed += 1


## Lets `seconds` go by, or fewer if `until` comes true first. Returns whether it did.
func wait(seconds: float, until := Callable()) -> bool:
	for i in int(seconds * 60.0):
		await physics_frame
		await process_frame
		if until.is_valid() and until.call():
			return true
	return not until.is_valid()


func put(at: Vector3, facing := 0.0) -> void:
	boy.global_position = at
	boy.velocity = Vector3.ZERO
	boy.facing_yaw = facing


## A finger down and up at a place on the screen.
func tap(at: Vector2) -> void:
	for down: bool in [true, false]:
		var event := InputEventScreenTouch.new()
		event.index = 0
		event.position = at
		event.pressed = down
		root.push_input(event, true)
		await process_frame


func panel() -> GuardianPanel:
	return GuardianPanel.current if is_instance_valid(GuardianPanel.current) else null


## Touches the button of a name on the panel that is up (-1: "Step back").
func say(name: int) -> void:
	var up := panel()
	up.lay_out()
	var at := up.back.get_center() if name < 0 else up.buttons[up.dealt.find(name)].get_center()
	await tap(up.get_global_transform() * at)


func keeper(at: Vector3, who: int, more := {}) -> GateGuardian:
	var made := GateGuardian.new()
	made.who = who
	for key: String in more:
		made.set(key, more[key])
	made.position = at
	stage.add_child(made)
	return made


func run() -> void:
	for action: StringName in InputMap.get_actions():
		if not String(action).begins_with("ui_"):
			InputMap.action_erase_events(action)
	var touch := TouchControls.new()
	touch.visible = false
	stage.add_child(touch)
	boy = load("res://player.tscn").instantiate()
	boy.position = Vector3(0, 0.05, 20)
	boy.rest_enabled = false
	stage.add_child(boy)
	boy.set_process_unhandled_input(false)
	await wait(0.5)
	await the_names()
	await alone()
	await leaves()
	boy.set_physics_process(false)
	stage.queue_free()
	await wait(0.2)
	await in_the_desert()
	print("PASSED" if failed == 0 else "FAILED (%d)" % failed)
	quit(1 if failed > 0 else 0)


func the_names() -> void:
	var count := BookOfTheDead.NAMES.size()
	check("there are a dozen names or more, and a title for each", count >= 12 and BookOfTheDead.TITLES.size() == count and BookOfTheDead.LEAF_TITLES.size() == count + 1, "%d" % count)
	var heads := {}
	var written := 0
	var same_titles := true
	for who in count:
		var name: Dictionary = BookOfTheDead.NAMES[who]
		heads[name["head"]] = true
		var layout := Hieroglyphs.write(BookOfTheDead.text(who), {"rules": false, "wrap": 6})
		if (layout["unknown"] as Array).is_empty() and (layout["signs"] as Array).size() >= 3 and Hieroglyphs.read(BookOfTheDead.text(who)) == name["name"]:
			written += 1
		else:
			print("   not written: ", name["name"], "  ", layout["unknown"], "  ", Hieroglyphs.read(BookOfTheDead.text(who)))
		same_titles = same_titles and BookOfTheDead.TITLES[who] == name["name"] and BookOfTheDead.LEAF_TITLES[who + 1] == name["name"]
	check("every name is written in signs the sign list has, and reads back as its English", written == count, "%d of %d" % [written, count])
	check("the lists to choose from say the same names", same_titles)
	check("every head has a name that wears it", heads.size() == BookOfTheDead.HEADS.size(), "%d" % heads.size())
	var first := BookOfTheDead.deal(4, 99, 0)
	var again := BookOfTheDead.deal(4, 99, 0)
	check("three names are dealt, the right one among them, none twice", first.size() == 3 and first.has(4) and first[0] != first[1] and first[1] != first[2] and first[0] != first[2], str(first))
	check("the same seed deals the same names", first == again)
	var moved := 0
	for round in 12:
		if BookOfTheDead.deal(4, 99, round) != first:
			moved += 1
	check("a wrong answer deals others", moved >= 8, "%d of 12 rounds differ" % moved)
	var places := [0, 0, 0]
	for seed in 300:
		places[BookOfTheDead.deal(4, seed, 0).find(4)] += 1
	check("the right name is in each place about as often", places.min() > 70, str(places))


func alone() -> void:
	var book := BookOfTheDead.of(stage)
	var made := keeper(Vector3.ZERO, 6, {"bars_way": true, "seed": 7})
	var said := [0, 0]
	made.changed.connect(func(_on: bool) -> void: said[0] += 1)
	made.caught.connect(func() -> void: said[1] += 1)
	await wait(0.3)
	check("a guardian starts off, is something to act at, and has its name's head", not made.on and made.is_in_group(&"workable") and made.beast() == BookOfTheDead.Head.SNAKE)
	check("far off, it does not ask", panel() == null and not paused)
	# Its gateway is 1.9 m to its left, on a line 0.75 m behind it.
	put(Vector3(1.9, 0.05, 2.4), PI)
	await wait(0.3)
	check("nor from before the threshold", panel() == null)
	var from := PhysicsRayQueryParameters3D.create(Vector3(1.9, 1.0, 2.0), Vector3(1.9, 1.0, -3.0))
	from.exclude = [boy.get_rid()]
	check("the gateway is barred", not stage.get_world_3d().direct_space_state.intersect_ray(from).is_empty())
	put(Vector3(1.9, 0.05, 0.1), PI)
	var asked := await wait(1.0, func() -> bool: return panel() != null)
	check("he steps onto the threshold and it asks", asked and paused and made.dealt.size() == 3 and made.dealt.has(6), str(made.dealt))
	if not asked:
		return
	var up := panel()
	check("without the leaf the English is not shown", not up.known and not book.has(6))
	# How it is laid out on a phone held sideways.
	up.set_anchors_preset(Control.PRESET_TOP_LEFT)
	up.size = Vector2(1560, 720)
	up.lay_out()
	var least := Vector2(INF, INF)
	var apart := INF
	var inside := true
	var all: Array[Rect2] = up.buttons.duplicate()
	all.append(up.back)
	for n in all.size():
		least = Vector2(minf(least.x, all[n].size.x), minf(least.y, all[n].size.y))
		inside = inside and Rect2(48, 0, 1560 - 96, 719).encloses(all[n])
		for m in n:
			var between := maxf(maxf(all[n].position.x - all[m].end.x, all[m].position.x - all[n].end.x), maxf(all[n].position.y - all[m].end.y, all[m].position.y - all[n].end.y))
			apart = minf(apart, between)
	check("on a phone its three names and Step back are big enough for a thumb, apart, and on the screen", least.x >= 88.0 and least.y >= 88.0 and apart >= 12.0 and inside and GuardianPanel.TEXT >= 26,
		"least %s, %.0f apart" % [least, apart])
	up.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	await process_frame
	var first: Array[int] = made.dealt.duplicate()
	await say(-1)
	await wait(0.2)
	check("Step back (touched) says nothing: the game goes on, it is not on, nobody is caught", panel() == null and not paused and not made.on and said == [0, 0])
	await wait(0.8)
	check("it does not ask again while he stands there", panel() == null)
	put(Vector3(1.9, 0.05, 6.0), PI)
	await wait(0.3)
	put(Vector3(1.9, 0.05, 0.1), PI)
	asked = await wait(1.0, func() -> bool: return panel() != null)
	check("he goes and comes back, and it asks again: the same three names", asked and made.dealt == first, str(made.dealt))
	# A wrong name, by touch.
	var wrong: int = first[0] if first[0] != 6 else first[1]
	await say(wrong)
	check("a wrong name (touched) puts the names away", panel() == null and not paused)
	var struck := await wait(1.5, func() -> bool: return said[1] > 0)
	check("and it strikes: he is caught", struck and said[1] == 1 and not made.on and made.wrong == 1, "caught %d" % said[1])
	check("it has risen to do it", made._rise > 0.6, "%.2f" % made._rise)
	await wait(2.6)
	check("and sits down again", made._striking < 0.0 and made._rise < 0.15, "%.2f" % made._rise)
	# Asked again, by the act button from before it: new names.
	put(Vector3(0.0, 0.05, 6.0), PI)
	await wait(0.3)
	put(Vector3(0.0, 0.05, 1.05), PI)
	await wait(0.4)
	boy._act()
	asked = await wait(0.6, func() -> bool: return panel() != null)
	check("he acts at it and it asks", asked)
	check("after a wrong name the three are dealt afresh, from its seed", made.dealt == BookOfTheDead.deal(6, 7, 1) and made.dealt.has(6), "%s then %s" % [first, made.dealt])
	if asked:
		await say(-1)
	await wait(0.2)
	# The leaf.
	var leaf := BookPage.new()
	leaf.who = 6
	leaf.position = Vector3(8, 0, 6)
	stage.add_child(leaf)
	var journal := Notebook.entries.size()
	put(Vector3(8, 0.05, 8.5))
	await wait(0.4)
	check("a leaf lies there until he comes to it", not leaf.is_taken and leaf.visible and leaf.name_on_it() == 6)
	put(Vector3(8, 0.05, 6.2))
	var read := await wait(1.0, func() -> bool: return panel() != null)
	check("he walks onto the leaf and it comes up to read, the game standing still", read and leaf.is_taken and not leaf.visible and paused and panel().dealt.is_empty() and panel().who == 6)
	check("it is his: the level has it, and the journal", book.has(6) and Notebook.entries.size() == journal + 1)
	await wait(0.7)
	await tap(Vector2(200, 600))
	await wait(0.2)
	check("a touch anywhere puts it away", panel() == null and not paused)
	# With the leaf.
	put(Vector3(1.9, 0.05, 6.0), PI)
	await wait(0.3)
	put(Vector3(1.9, 0.05, 0.1), PI)
	asked = await wait(1.0, func() -> bool: return panel() != null)
	check("with the leaf the English is shown under the right name", asked and panel().known and panel().who == 6)
	await say(6)
	await wait(0.3)
	check("the right name (touched) turns it on, for good", made.on and said[0] == 1 and said[1] == 1 and panel() == null and not paused)
	await wait(2.5)
	check("it bows its head and lowers its knives", made._bow > 0.4 and made._knife > 1.2, "%.2f %.2f" % [made._bow, made._knife])
	check("and the gateway is open", stage.get_world_3d().direct_space_state.intersect_ray(from).is_empty())
	put(Vector3(1.9, 0.05, 6.0), PI)
	await wait(0.3)
	put(Vector3(1.9, 0.05, 0.1), PI)
	await wait(0.6)
	check("named, it does not ask again", panel() == null and not made.challenge())
	made.queue_free()
	leaf.queue_free()
	put(Vector3(0, 0.05, 30))
	await wait(0.2)


func leaves() -> void:
	# Two keepers and leaves with no name chosen: each leaf takes the nearer keeper's name, and they do not share one.
	var east := keeper(Vector3(20, 0, 0), 3, {"asks_at_threshold": false})
	var west := keeper(Vector3(-20, 0, 0), 9, {"asks_at_threshold": false})
	var pages: Array[BookPage] = []
	for x: float in [16.0, 14.0, -12.0]:
		var page := BookPage.new()
		page.position = Vector3(x, 0, 4)
		page.rolled = x < 0.0
		stage.add_child(page)
		pages.append(page)
	await wait(0.2)
	check("a leaf with no name chosen takes the nearest keeper's", pages[0].name_on_it() == 3 and pages[2].name_on_it() == 9, "%d %d" % [pages[0].name_on_it(), pages[2].name_on_it()])
	check("and a second one near the same keeper takes a name nobody has", pages[1].name_on_it() not in [3, 9], "%d" % pages[1].name_on_it())
	check("taken without being shown, it does not stop the game", pages[2].take(false) and not paused and BookOfTheDead.of(stage).has(9) and not pages[2].take(false))
	for node: Node in [east, west, pages[0], pages[1], pages[2]]:
		node.queue_free()
	await wait(0.2)


# --- In the desert, made from items ---

func add(kind: String, what: String, at: Vector2, more := {}) -> Dictionary:
	var item := LevelLayout.new_item(level.layout, kind, what, at)
	item.merge(more, true)
	level.layout["items"].append(item)
	level.make(item)
	return item


func node(item: Dictionary) -> Node3D:
	return level.nodes.get(item["id"])


func in_the_desert() -> void:
	var scene: Node = load("res://desert.tscn").instantiate()
	root.add_child(scene)
	await wait(0.6)
	level = scene.get_node("Level")
	var him := scene.get_node("Player") as Player
	him.set_physics_process(false)
	var on_palette := 0
	for entry: Array in LevelLayout.PALETTE["Puzzle"]:
		if entry[0] in ["Gate guardian", "Leaf of the Book of the Dead"]:
			on_palette += 1
	check("both are on the editor's Puzzle page", on_palette == 2)
	var x := 60.0
	var guard := add("guardian", "", Vector2(x, 100.0), {"who": 7, "bars": true, "dress": 1, "two": false, "asks": false})
	var page := add("bookpage", "", Vector2(x, 112.0))
	var door := node(add("door", "", Vector2(x, 90.0), {"links": [guard["id"]]})) as TombParts.Door
	var made := node(guard) as GateGuardian
	var leaf := node(page) as BookPage
	await wait(0.4)
	check("an item makes a guardian as its fields say", made != null and made.who == 7 and made.bars_way and made.dress == GateGuardian.Dress.KILT and made.knives == 1 and made.seed != 0
		and made.beast() == BookOfTheDead.Head.HIPPOPOTAMUS and LevelLayout.label(guard) == "Gate guardian")
	check("and a leaf, which takes that guardian's name", leaf != null and leaf.name_on_it() == 7 and LevelLayout.label(page) == "Leaf of the Book of the Dead")
	check("a door linked to a guardian is shut", not door.is_open)
	var book := BookOfTheDead.of(made)
	check("the leaves found are kept under the level", book != null and book.get_parent() == scene and book.found.is_empty())
	# A wrong name lays him out.
	him.global_position = made.global_position + Vector3(0.0, 0.3, 3.0)
	check("it asks", made.challenge() and panel() != null and not panel().known)
	var wrong: int = made.dealt[0] if made.dealt[0] != 7 else made.dealt[1]
	await say(wrong)
	var down := await wait(1.5, func() -> bool: return him.is_limp)
	check("a wrong name in a level: he is caught, and goes down", down and not door.is_open)
	await wait(3.0)
	check("and starts again", not him.is_limp)
	# The leaf, and the right name.
	him.global_position = leaf.global_position + Vector3(0.0, 0.2, 0.1)
	var read := await wait(1.0, func() -> bool: return panel() != null)
	check("he finds the leaf", read and book.has(7))
	await wait(0.6)
	await tap(Vector2(640, 360))
	await wait(0.2)
	him.global_position = made.global_position + Vector3(0.0, 0.3, 3.0)
	check("asked again, the English is there", made.challenge() and panel().known)
	await say(7)
	await wait(0.4)
	check("the right name opens the door linked to it", made.on and door.is_open)
	# The menu has a page for the leaves.
	var menu := scene.find_child("Menu", true, false) as GameMenu
	check("the notebook has a page for the leaves found", menu != null and menu._parts().has("dead"))
	# A level started again has forgotten them.
	root.remove_child(scene)
	scene.queue_free()
	await wait(0.2)
	scene = load("res://desert.tscn").instantiate()
	root.add_child(scene)
	await wait(0.6)
	var fresh := BookOfTheDead.of(scene.get_node("Level"))
	menu = scene.find_child("Menu", true, false) as GameMenu
	check("a level started again has forgotten its leaves", fresh.found.is_empty() and not fresh.has(7) and menu != null and not menu._parts().has("dead"))
	check("the player's own level was not written to", not FileAccess.file_exists("user://guardian_test_layout.json"))
	scene.queue_free()
	await wait(0.2)
