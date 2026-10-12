extends SceneTree
## Not part of the game. Runs the sphinx with nothing drawn and says whether each thing happened. On a bare floor, with
## the boy: it is asleep until he comes between its paws, and then its eyes open and its riddle is put up (and is what
## its stele says); a wrong thing put down there is knocked clear, lands unbroken on the floor a few metres off and can
## be picked up again; so is one thrown onto the slab; the right thing turns it on for good and is kept; every riddle
## has a thing that answers it and no other does; a wrathful one catches him at the third wrong thing; one that opens
## itself lets him through from its chest to its tail; one that is buried sleeps until its sand has been cleared; and he
## can stand on its back, its paws, its haunches and its head, at three sizes, without falling through. Then in the
## desert, made from items as the level editor makes them: it opens the door linked to it, and a lever clears its sand.
## godot --headless --path . --fixed-fps 60 --script tools/sphinx_test.gd
## Ends with PASSED or FAILED (and exits 0 or 1).

var stage: Node3D
var failed := 0
var boy: Player
var touch: TouchControls
var level: Desert


func _initialize() -> void:
	# (nothing here saves a level, but if it did it would not be the player's)
	LevelLayout.saved_at = "user://sphinx_test_layout.json"
	stage = Node3D.new()
	root.add_child(stage)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-48.0, -35.0, 0.0)
	stage.add_child(sun)
	box(Vector3(0, -1, 0), Vector3(400, 2, 400))
	run.call_deferred()


func box(at: Vector3, size: Vector3) -> StaticBody3D:
	var body := StaticBody3D.new()
	var shape := BoxShape3D.new()
	shape.size = size
	var collider := CollisionShape3D.new()
	collider.shape = shape
	body.add_child(collider)
	body.position = at
	stage.add_child(body)
	return body


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


func place(node: Node3D, at: Vector3, yaw := 0.0) -> Node3D:
	node.position = at
	node.rotation.y = yaw
	stage.add_child(node)
	return node


func sphinx(at: Vector3, size := 6.0, more := {}) -> Sphinx:
	var made := Sphinx.new()
	made.size = size
	for key: String in more:
		made.set(key, more[key])
	return place(made, at) as Sphinx


func prop(name: String, at: Vector3) -> RigidBody3D:
	return place((load("res://props/%s.tscn" % name) as PackedScene).instantiate() as Node3D, at) as RigidBody3D


## He takes a thing up (as the act button would have him, without the stoop), carries it in between the paws, and lets go of it.
func give(one: Sphinx, thing: RigidBody3D) -> void:
	if boy.carried:
		boy.let_go()
	boy._take(thing)
	put(one.global_transform * Vector3(0.0, one._foot + 0.05, one.size * 0.5 + 0.4), one.rotation.y + PI)
	await wait(0.5)
	boy.let_go()


func run() -> void:
	for action: StringName in InputMap.get_actions():
		if not String(action).begins_with("ui_"):
			InputMap.action_erase_events(action)
	touch = TouchControls.new()
	touch.visible = false
	stage.add_child(touch)
	touch.set_process_input(false)
	boy = load("res://player.tscn").instantiate()
	boy.position = Vector3(0, 0.05, 30)
	boy.rest_enabled = false
	stage.add_child(boy)
	boy.set_process_unhandled_input(false)
	await wait(0.5)

	await riddles()
	await asking()
	await wrath()
	await opening()
	await sand()
	await standing()
	boy.set_physics_process(false)
	stage.queue_free()
	await wait(0.2)
	await in_the_desert()
	print("PASSED" if failed == 0 else "FAILED (%d)" % failed)
	quit(1 if failed > 0 else 0)


## Every riddle has one thing that answers it.
func riddles() -> void:
	var things := {}
	var torch := HandTorch.new()
	things[&"torch"] = place(torch, Vector3(-40, 0.1, 40))
	var cold := HandTorch.new()
	cold.lit = false
	things[&"cold_torch"] = place(cold, Vector3(-41, 0.1, 40))
	things[&"amulet"] = place(ScarabAmulet.new(), Vector3(-42, 0.1, 40))
	for metal in 3:
		var key := DoorKey.new()
		key.which = metal as DoorKey.Metal
		things[[&"key_iron", &"key_bronze", &"key_gold"][metal]] = place(key, Vector3(-43 - metal, 0.1, 40))
	things[&"jar"] = prop("jar_canopic", Vector3(-46, 0.3, 40))
	things[&"oil"] = place(OilJar.new(), Vector3(-47, 0.05, 40))
	things[&"stone"] = prop("rock_small", Vector3(-48, 0.2, 40))
	things[&"pot"] = prop("pot", Vector3(-49, 0.3, 40))
	things[&"shovel"] = prop("shovel", Vector3(-50, 0.3, 40))
	things[&"pickaxe"] = prop("pickaxe", Vector3(-51, 0.3, 40))
	things[&"brush"] = prop("brush", Vector3(-52, 0.3, 40))
	things[&"lantern"] = prop("lantern", Vector3(-53, 0.3, 40))
	things[&"basket"] = prop("dig_basket", Vector3(-54, 0.3, 40))
	things[&"khopesh"] = prop("khopesh", Vector3(-55, 0.3, 40))
	things[&"hook"] = place(GrappleHook.new(), Vector3(-56, 0.3, 40))
	await wait(0.3)
	var one := sphinx(Vector3(-40, 0, 60), 2.5)
	var answered := 0
	var only := 0
	var carried := 0
	var missing := ""
	for i in Sphinx.THINGS.size():
		one.wants = i
		var name: StringName = Sphinx.THINGS[i][0]
		if things.has(name) and one.is_answer(things[name]):
			answered += 1
		else:
			missing += " %s" % name
		var others := 0
		for other: StringName in things:
			if other != name and one.is_answer(things[other]):
				others += 1
		if others == 0:
			only += 1
		if things.has(name) and (things[name] as Node).is_in_group(&"throwable") and things[name] is RigidBody3D:
			carried += 1
	check("it has a riddle for each of at least eight things", Sphinx.THINGS.size() >= 8 and Sphinx.TITLES.size() == Sphinx.THINGS.size(), "%d" % Sphinx.THINGS.size())
	check("each riddle is answered by a thing in the game", answered == Sphinx.THINGS.size(), "%d%s" % [answered, missing])
	check("and by no other", only == Sphinx.THINGS.size(), "%d" % only)
	check("and that thing is one he can pick up", carried == Sphinx.THINGS.size(), "%d" % carried)
	var titled := 0
	for i in Sphinx.THINGS.size():
		if Sphinx.TITLES[i] == Sphinx.THINGS[i][1] and String(Sphinx.THINGS[i][2]).length() > 20 and String(Sphinx.THINGS[i][2]).length() < 130:
			titled += 1
	check("each has its name for the editor, and is short", titled == Sphinx.THINGS.size(), "%d" % titled)
	one.queue_free()
	for name: StringName in things:
		(things[name] as Node).queue_free()
	await wait(0.2)


## It wakes, asks, refuses a wrong thing and takes the right one.
func asking() -> void:
	var one := sphinx(Vector3(0, 0, 0), 6.0, {"wants": 2})
	var said := [0]
	one.changed.connect(func(_on: bool) -> void: said[0] += 1)
	var amulet := place(ScarabAmulet.new(), Vector3(8, 0.1, 8)) as RigidBody3D
	var jar := prop("jar_canopic", Vector3(9, 0.3, 8))
	var rock := prop("rock_small", Vector3(10, 0.2, 8))
	put(Vector3(0, 0.05, 14), PI)
	await wait(0.6)
	check("a sphinx is asleep while he is far off", not one.awake and not one.on and one._glow < 0.05 and (one._caption == null or not one._caption.visible))
	check("its stele says its riddle", one._carved != null and one._carved.translation() == one.riddle_text() and one.riddle_text() == Sphinx.THINGS[2][2], one._carved.translation())
	check("it is solid", one.get_child_count() > 10 and one.is_in_group(&"interest"))
	# He comes between its paws.
	put(Vector3(0, 0.3, 3.3), PI)
	var woke := await wait(2.0, func() -> bool: return one.awake)
	await wait(1.0)
	check("it wakes when he comes between its paws: its eyes open and glow", woke and one._glow > 0.7 and one._open > 0.9 and one._eyes.size() == 2 and one._light.light_energy > 0.05, "glow %.2f" % one._glow)
	check("and its riddle comes up as a caption", one._caption != null and one._caption.visible and one._caption.text.contains(one.riddle_text()) and one._caption.get_theme_font_size("font_size") >= 26)
	put(Vector3(0.6, 0.3, 3.6), PI)
	await wait(1.5)
	check("its head turns a little towards him, and down", one._head.rotation.y > 0.02 and one._head.rotation.y < 0.2 and one._head.rotation.x >= 0.0, "%.3f %.3f" % [one._head.rotation.y, one._head.rotation.x])
	# A wrong thing.
	await give(one, jar)
	var refused := await wait(5.0, func() -> bool: return one.strikes == 1)
	await wait(1.5)
	var off := jar.global_position.distance_to(one.slab_place())
	check("a wrong thing is refused: it is not on", refused and not one.on and said[0] == 0)
	check("and is knocked clear, onto the floor a few metres off", off > 2.0 and off < 9.0 and jar.global_position.y > 0.0 and jar.global_position.y < 0.6 and not jar.freeze and not jar.has_meta(&"offered"),
			"%.1f m off, at height %.2f" % [off, jar.global_position.y])
	check("clear of the sphinx itself", absf(one.to_local(jar.global_position).x) > SphinxMesh.BASE.x * one.size + 0.5)
	put(jar.global_position + Vector3(0.0, 0.0, 0.5), PI)
	await wait(0.5)
	boy._act()
	var again := await wait(2.0, func() -> bool: return boy.carried == jar)
	check("and he can pick it up again", again)
	boy.let_go()
	await wait(0.3)
	# One thrown onto the slab from in front.
	put(Vector3(0, 0.05, 7.6), PI)
	await wait(0.3)
	boy._take(rock)
	await wait(0.6)
	boy._act()
	var thrown := await wait(6.0, func() -> bool: return one.strikes == 2)
	await wait(1.5)
	check("a wrong thing thrown between the paws is refused too", thrown and not one.on and rock.global_position.distance_to(one.slab_place()) > 2.0 and not rock.freeze,
			"strikes %d, %.1f m off" % [one.strikes, rock.global_position.distance_to(one.slab_place())])
	# Fragile things are not broken by it.
	var oil := place(OilJar.new(), Vector3(11, 0.05, 8)) as OilJar
	await wait(0.3)
	one.offer(oil)
	await wait(4.0)
	check("a jar of oil it refuses is put down whole", not oil.is_broken and one.strikes == 3 and oil.global_position.distance_to(one.slab_place()) > 2.0)
	check("without `wrathful` it never strikes", not one._wrath_due and one._wrath <= 0.0)
	# The right thing.
	await give(one, amulet)
	var taken := await wait(5.0, func() -> bool: return one.on)
	await wait(1.0)
	check("the right thing turns it on, once", taken and said[0] == 1 and one.kept == amulet)
	check("its eyes blaze", one._glow > 1.8, "%.2f" % one._glow)
	check("the thing is kept on the slab", amulet.freeze and amulet.global_position.distance_to(one.slab_place()) < 0.3 and not amulet.is_in_group(&"throwable"),
			"%.2f" % amulet.global_position.distance_to(one.slab_place()))
	put(Vector3(0.0, 0.3, 2.6), PI)
	await wait(0.3)
	boy._act()
	await wait(1.0)
	check("he cannot take it back", boy.carried == null and one.on)
	put(Vector3(0, 0.05, 30), PI)
	await wait(6.0)
	check("it stays on when he has gone", one.on and one._glow > 1.5)
	one.reset()
	await wait(0.5)
	check("put back as it was, it is off and the thing is his again", not one.on and said[0] == 2 and one.kept == null and amulet.is_in_group(&"throwable") and not amulet.freeze)
	# Its own words.
	var own := sphinx(Vector3(30, 0, 0), 2.5, {"riddle": "What walks on four legs at dawn?", "head": Sphinx.Head.RAM, "painted": true})
	await wait(0.2)
	check("a riddle typed by the level's maker is what it says", own.riddle_text() == "What walks on four legs at dawn?" and own._carved.translation() == own.riddle_text(), own._carved.translation())
	for node: Node in [one, own, amulet, jar, rock, oil]:
		node.queue_free()
	await wait(0.2)


func wrath() -> void:
	var one := sphinx(Vector3(60, 0, 0), 4.0, {"wants": 0, "wrathful": true, "head": Sphinx.Head.FALCON})
	var caught := [0]
	one.caught.connect(func() -> void: caught[0] += 1)
	var jar := prop("jar_canopic", Vector3(66, 0.3, 6))
	put(Vector3(60, 0.05, 3.2), PI)
	await wait(1.0)
	for i in 3:
		check("a wrathful one has not struck after %d wrong things" % i, caught[0] == 0)
		await give(one, jar)
		await wait(5.0, func() -> bool: return one.strikes == i + 1 or caught[0] > 0)
		await wait(1.6)
	check("at the third it strikes: `caught`, once", caught[0] == 1, "%d" % caught[0])
	check("and starts counting again", one.strikes == 0)
	# A torch that is out is not fire; one that burns is.
	var cold := HandTorch.new()
	cold.lit = false
	place(cold, Vector3(66, 0.1, 8))
	await wait(0.2)
	one.offer(cold)
	await wait(3.5)
	check("it wants a burning torch, and one that is out is wrong", not one.on and one.strikes == 1)
	cold.lit = true
	await wait(0.2)
	one.offer(cold)
	await wait(2.5)
	check("lit, it is right", one.on and one.kept == cold and caught[0] == 1)
	for node: Node in [one, jar, cold]:
		node.queue_free()
	await wait(0.2)


func opening() -> void:
	var one := sphinx(Vector3(100, 0, 0), 12.0, {"wants": 5, "opens_itself": true})
	var key := DoorKey.new()
	key.which = DoorKey.Metal.GOLD
	place(key, Vector3(108, 0.1, 10))
	await wait(0.4)
	# Before: the stele stands in the way.
	put(Vector3(100, one._foot + 0.05, 3.4), PI)
	await wait(0.3)
	touch.move = Vector2(0, -1)
	await wait(2.5)
	touch.move = Vector2.ZERO
	check("the stele stands in the way of one that has not been answered", boy.global_position.z > 1.4, "z %.2f" % boy.global_position.z)
	await give(one, key)
	var taken := await wait(5.0, func() -> bool: return one.on)
	await wait(4.0)
	check("given its key, its stele sinks into the ground", taken and one._sunk >= 1.0 and one._stele.position.y < -1.0, "%.2f" % one._stele.position.y)
	put(Vector3(100, one._foot + 0.05, 4.2), PI)
	await wait(0.3)
	touch.move = Vector2(0, -1)
	var through := await wait(9.0, func() -> bool: return boy.global_position.z < -6.4)
	touch.move = Vector2.ZERO
	check("and he walks in at its chest and out under its tail", through, "z %.2f" % boy.global_position.z)
	one.queue_free()
	key.queue_free()
	await wait(0.2)


func sand() -> void:
	var one := sphinx(Vector3(140, 0, 0), 6.0, {"wants": 6, "buried": 1.0, "uncover_time": 2.0})
	await wait(0.5)
	check("a buried one lies in a heap of sand to its neck", one._pile != null and one._pile.height > 1.5 and one._pile.height < 0.34 * one.size and one.is_covered(), "%.2f m" % (one._pile.height if one._pile else 0.0))
	put(Vector3(140, 4.0, 3.3), PI)
	await wait(1.5)
	check("he stands on the sand, over its paws", boy.is_on_floor() and boy.global_position.y > 0.8, "%.2f" % boy.global_position.y)
	check("and it sleeps", not one.awake)
	one.uncovering = true
	await wait(1.0)
	check("the sand goes down while something clears it", one.sand < 0.6 and one.sand > 0.3, "%.2f" % one.sand)
	one.uncovering = false
	await wait(0.5)
	var held := one.sand
	await wait(0.5)
	check("and stops when that stops", absf(one.sand - held) < 0.001)
	one.uncovering = true
	await wait(2.0)
	check("until it is gone", one.sand <= 0.0 and not one.is_covered() and one._pile.radius < 0.05)
	put(Vector3(140, 0.3, 3.3), PI)
	var woke := await wait(2.0, func() -> bool: return one.awake)
	check("and then it wakes for him", woke)
	one.queue_free()
	await wait(0.2)


## Set down on it from just above, he stays where he is put.
func standing() -> void:
	var x := -190.0
	for size: float in [2.5, 6.0, 12.0]:
		for head: int in [Sphinx.Head.KING, Sphinx.Head.RAM] if size == 6.0 else [Sphinx.Head.KING]:
			var one := sphinx(Vector3(x, 0, 0), size, {"head": head})
			var foot := one._foot
			await wait(0.3)
			# [where (in lengths of the sphinx), how high its top is there (the same, above its base)]
			var spots := {"its back": [Vector3(0.0, 0.0, -0.25), 0.245], "its shoulders": [Vector3(0.0, 0.0, -0.09), 0.24], "a forepaw": [Vector3(0.11, 0.0, 0.35), 0.075],
				"the other forepaw": [Vector3(-0.11, 0.0, 0.3), 0.075], "a haunch": [Vector3(0.17, 0.0, -0.33), 0.186], "its head": [Vector3(0.0, 0.0, SphinxMesh.HEAD_AT.z), 0.47],
				"its base": [Vector3(0.2, 0.0, 0.2), 0.0]}
			var stood := 0
			var said := ""
			for name: String in spots:
				var spot: Vector3 = spots[name][0]
				var top: float = foot + float(spots[name][1]) * size
				put(Vector3(x + spot.x * size, top + 0.5, spot.z * size), PI)
				await wait(1.2)
				var at := boy.global_position
				# (a rounded top lets him settle a little to one side; not through, and not off)
				if boy.is_on_floor() and at.y > top - maxf(0.06 * size, 0.2) and at.y < top + 0.3:
					stood += 1
				else:
					said += " %s (%.2f, wanted %.2f)" % [name, at.y, top]
			check("he stands on a sphinx of %.1f m (%s): back, shoulders, paws, haunch, head, base" % [size, ["king", "ram", "falcon"][head]], stood == spots.size(), "%d of %d%s" % [stood, spots.size(), said])
			one.queue_free()
			x += 30.0
			await wait(0.2)
	# And he gets onto a great one by himself: up onto a forepaw from the side, by its edge.
	var great := sphinx(Vector3(x, 0, 0), 12.0)
	await wait(0.3)
	put(Vector3(x + 0.155 * 12.0 + 1.6, great._foot + 0.05, 4.0), -PI * 0.5)
	await wait(0.4)
	touch.move = Vector2(-1, 0)
	await wait(0.5)
	touch.jump_held = true
	boy._queue_jump()
	var up := await wait(5.0, func() -> bool: return boy.is_on_floor() and boy.global_position.y > great._foot + 0.07 * 12.0)
	touch.jump_held = false
	touch.move = Vector2.ZERO
	check("he gets up onto a great one's forepaw by its edge", up, "at %s, of %.2f" % [boy.global_position - great.global_position, great._foot + 0.075 * 12.0])
	# And from the ground onto a haunch, and from the haunch onto its back.
	put(Vector3(x + 0.235 * 12.0 + 1.5, 0.05, -0.36 * 12.0), -PI * 0.5)
	await wait(0.4)
	var heights: Array[float] = [great._foot + 0.17 * 12.0, great._foot + 0.225 * 12.0]
	var got := 0
	for want in heights:
		touch.move = Vector2(-1, 0)
		for attempt in 4:
			touch.jump_held = true
			boy._queue_jump()
			var there := await wait(4.0, func() -> bool: return boy.is_on_floor() and boy.global_position.y > want)
			touch.jump_held = false
			if there:
				got += 1
				break
			await wait(0.3)
	touch.move = Vector2.ZERO
	check("and climbs from the ground onto a haunch, and from there onto its back", got == 2 and absf(boy.global_position.x - x) < 0.16 * 12.0, "at %s" % (boy.global_position - great.global_position))
	great.queue_free()
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
	var on_page := false
	for entry: Array in LevelLayout.PALETTE["Stone"]:
		if entry[0] == "Sphinx" and entry[1] == "sphinx":
			on_page = true
	var fresh := add("sphinx", "", Vector2(60.0, 100.0))
	var keys: Array = []
	for field: Array in LevelLayout.fields(fresh):
		keys.append(field[0])
	check("\"Sphinx\" is on the editor's Stone page, and makes one", on_page and node(fresh) is Sphinx and LevelLayout.label(fresh) == "Sphinx")
	var has_all := true
	for key: String in ["size", "head", "wear", "wants", "riddle", "buried", "opens", "wrathful", "links"]:
		has_all = has_all and keys.has(key)
	check("with its size, head, wear, what it wants, its own riddle, buried, opens itself and wrathful", has_all, str(keys))
	var editor := LevelEditor.new()
	check("the editor knows it for a trigger, and for a thing that is worked", editor._is_trigger(fresh) and editor._is_worked(fresh))
	editor.free()
	level.forget(fresh["id"])
	level.layout["items"].erase(fresh)

	# One that opens a door.
	var item := add("sphinx", "", Vector2(60.0, 100.0), {"size": 4.0, "head": 2, "wants": 4, "wrathful": true, "wear": 0.8, "painted": true, "riddle": "Bring the brown key."})
	var one := node(item) as Sphinx
	var door := node(add("door", "", Vector2(60.0, 110.0), {"links": [item["id"]]})) as TombParts.Door
	var key_item := add("key", "", Vector2(64.0, 108.0), {"which": 1, "lift": 0.3})
	var key := node(key_item) as DoorKey
	await wait(0.4)
	check("a sphinx in a level is as its item says", one.size == 4.0 and one.head == Sphinx.Head.FALCON and one.wants == 4 and one.wrathful and one.painted and one.riddle_text() == "Bring the brown key.")
	check("a door linked to it is shut", not door.is_open and not one.on)
	one.offer(key)
	var opened := await wait(4.0, func() -> bool: return door.is_open)
	check("and opens when it is given what it wants", opened and one.on and one.kept == key)
	check("it is wired to catch him as the mummy is", one.caught.get_connections().size() == 1)
	# One that is buried, and a lever.
	var lever := add("lever", "", Vector2(80.0, 100.0))
	var sunk_item := add("sphinx", "", Vector2(80.0, 110.0), {"buried": 1.0, "links": [lever["id"]]})
	var sunk := node(sunk_item) as Sphinx
	await wait(0.5)
	check("a buried one in a level keeps its sand until its lever is pulled", sunk.is_covered() and sunk.sand == 1.0 and not sunk.uncovering)
	(node(lever) as Lever).work()
	await wait(1.0)
	check("and then the sand goes down", sunk.uncovering and sunk.sand < 0.95, "%.2f" % sunk.sand)
	await wait(8.0)
	check("and is gone in eight seconds", sunk.sand <= 0.0 and not sunk.is_covered())
	# Taken out and put back.
	for made: Dictionary in [item, sunk_item]:
		level.forget(made["id"])
	await wait(0.3)
	check("taken out of the level, it lets go of what it kept", is_instance_valid(key) and key.held_by == null and key.is_in_group(&"throwable"))
	level.make(item)
	await wait(0.3)
	check("and can be made again", node(item) is Sphinx and not (node(item) as Sphinx).on)
	scene.queue_free()
	await wait(0.2)
