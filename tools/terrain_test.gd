extends SceneTree
## Not part of the game. Checks the desert's dunes and rock with nothing drawn, driving the
## boy as a player would, and ends by printing PASSED or FAILED.
## godot --headless --path . --fixed-fps 60 --script tools/terrain_test.gd
##
## - the same seed gives the same ground, the same field of rocks and the same cliff; another gives another
## - a level saved before there were kinds of dune loads, and its ground is what it was
## - the shipped level loads, with its valley, its cliffs and its rocks
## - he walks up the back of a dune and over its crest, and no sand runs under him on the way up
## - on the slip face the sand lets go
## - thrown at every rock formation, at a mesa and at a cliff, from all round, running and
##   jumping, he does not get inside, and he can walk away afterwards
## - the ledges of a cliff's way up are climbed, to its top
## - an open tomb doorway says so when he walks in, and a shut one keeps him out
## It keeps the level it makes in a file of its own (`LevelLayout.saved_at`), and leaves alone
## the one made in the game.

const KEPT := "user://terrain_test_layout.json"

var scene: Node
var level: Desert
var player: Player
var touch: TouchControls
var cam: Camera3D
var failed := 0


func _initialize() -> void:
	LevelLayout.saved_at = KEPT
	run.call_deferred()


func check(what: String, good: bool, more := "") -> void:
	print("%s  %s%s" % ["ok  " if good else "FAIL", what, "  (%s)" % more if more != "" else ""])
	if not good:
		failed += 1


func run() -> void:
	for action: StringName in InputMap.get_actions():
		if not String(action).begins_with("ui_"):
			InputMap.action_erase_events(action)
			Input.action_release(action)
	same_from_same()
	await old_level()
	await shipped_level()
	await open(layout_for_tests())
	await dune()
	await rocks()
	await cliffs()
	await doors()
	for phone: bool in [false, true]:
		await editing(phone)
	await into_a_tomb()
	if FileAccess.file_exists(KEPT):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(KEPT))
	print("PASSED" if failed == 0 else "FAILED (%d)" % failed)
	quit(0 if failed == 0 else 1)


# --- What is checked ---

func same_from_same() -> void:
	var fields: Array = []
	for seed: int in [7, 7, 8]:
		var dunes := SandDunes.new()
		dunes.wind = Vector2(-0.96, -0.28)
		dunes.seed = seed
		dunes.sharp = 0.8
		dunes.field(Rect2(-150, -150, 300, 300), SandDunes.Field.MIXED, Vector2(2.5, 9.0), 0.35)
		fields.append(dunes.bake(Vector2(-150, -150), 2.5, 121, 121))
	check("the same seed gives the same dunes", fields[0] == fields[1])
	check("another seed gives other dunes", fields[0] != fields[2])
	var rocks: Array = []
	var tops: Array = []
	for seed: int in [3, 3, 4]:
		var field := RockField.new()
		field.seed = seed
		field.build()
		rocks.append(field.rocks.duplicate(true))
		field.free()
		var cliff := Cliff.new()
		cliff.seed = seed
		cliff.build()
		tops.append(cliff.top.duplicate())
		cliff.free()
	check("the same seed gives the same field of rocks", rocks[0] == rocks[1] and rocks[0] != rocks[2], "%d rocks" % (rocks[0] as Array).size())
	check("the same seed gives the same cliff", tops[0] == tops[1] and tops[0] != tops[2])


## A level from before: no kind of dunes, no sharpness, no far hills.
func old_level() -> void:
	var old := {"version": 1, "terrain": {"size": 300.0, "cell": 2.5, "dune_height": 7.0, "seed": 7, "scatter": 1.0, "rim_height": 9.0, "rim_width": 45.0, "wind": [0.96, 0.28]},
		"weather": 0, "items": [
			{"id": 1, "kind": "start", "at": [0.0, 0.0], "lift": 0.0, "yaw": 0.0},
			{"id": 2, "kind": "pad", "at": [0.0, 0.0], "y": 0.0, "yaw": 0.0, "half_x": 8.0, "half_z": 8.0, "round": true, "ease": 12.0},
			{"id": 3, "kind": "dune", "at": [60.0, 40.0], "lift": 0.0, "yaw": 0.0, "width": 46.0, "height": 6.0, "horns": 0.55},
			{"id": 4, "kind": "ridge", "at": [-60.0, -40.0], "lift": 0.0, "yaw": 20.0, "length": 110.0, "height": 7.0},
			{"id": 5, "kind": "pond", "at": [40.0, -60.0], "lift": 0.0, "yaw": 0.0, "radius": 8.0, "depth": 1.4, "level": -0.4, "bank": 6.0},
			{"id": 6, "kind": "prop", "at": [20.0, 20.0], "lift": 0.0, "yaw": 0.0, "what": "rock_a", "scale": 1.0, "tilt_x": 0.0, "tilt_z": 0.0},
		]}
	await open(old)
	var terrain := level.terrain
	check("an old level loads", level.nodes.size() >= 2 and terrain.ground != null)
	check("its dunes are scattered and round at the crest, as they were", terrain.dunes == 0 and terrain.sharp == 0.0)
	check("it has no far hills", level.get_node_or_null(^"Horizon") == null)
	# Its ground is what the old way of making it gives: asked point by point of the dunes, the pads and the water.
	var worst := 0.0
	var step := terrain.size / int(terrain.size / terrain.cell)
	for i in 400:
		var x := (floorf(Rock.chance(i, 1) * 100.0) - 50.0) * step
		var z := (floorf(Rock.chance(i, 2) * 100.0) - 50.0) * step
		var was := terrain._dry_at(x, z)
		for carve: Array in terrain._carves:
			if (carve[5] as Rect2).has_point(Vector2(x, z)):
				was = terrain._carved(was, carve, x, z)
		worst = maxf(worst, absf(terrain.height_at(x, z) - was))
	check("its ground is what it was", worst < 0.002, "%.5f m off at the worst of 400 places" % worst)
	check("the ground is made in under a second", terrain.made_in < 1000.0, "%.0f ms" % terrain.made_in)


func shipped_level() -> void:
	await open(LevelLayout.built_in())
	var kinds := {}
	for node: Node in level.nodes.values():
		kinds[node.get_script()] = true
	check("the shipped level loads with its valley, cliffs and rocks", kinds.has(KingsValley) and kinds.has(Cliff) and kinds.has(RockField) and level.get_node_or_null(^"Horizon") != null)
	check("its ground is made in under a second", level.terrain.made_in < 1000.0, "%.0f ms" % level.terrain.made_in)
	var open_doors := 0
	for door: TombDoor in root.get_tree().get_nodes_in_group(&"tomb_doors"):
		open_doors += 1 if door.open else 0
	check("its valley has tomb doors, one of them open", root.get_tree().get_nodes_in_group(&"tomb_doors").size() >= 4 and open_doors == 1)


func layout_for_tests() -> Dictionary:
	var items: Array = [
		{"id": 1, "kind": "start", "at": [0.0, 0.0], "lift": 0.0, "yaw": 0.0},
		{"id": 2, "kind": "dune", "at": [0.0, -110.0], "lift": 0.0, "yaw": 0.0, "width": 70.0, "height": 7.0, "horns": 0.55},
		{"id": 3, "kind": "cliff", "what": "mesa", "at": [110.0, 60.0], "lift": 0.0, "yaw": 0.0, "width": 30.0, "height": 9.0, "scree": 0.35, "rough": 2.0, "ways": 1, "seed": 4, "stone": 2},
		{"id": 4, "kind": "cliff", "at": [0.0, 130.0], "lift": 0.0, "yaw": 0.0, "length": 60.0, "bend": 30.0, "height": 10.0, "depth": 12.0, "scree": 0.3, "rough": 2.0, "ways": 1, "seed": 2, "stone": 1},
		{"id": 5, "kind": "tomb_door", "at": [-40.0, -20.0], "lift": 0.0, "yaw": 0.0, "number": 9, "open": true, "leads": 0},
		{"id": 6, "kind": "tomb_door", "at": [-60.0, -20.0], "lift": 0.0, "yaw": 0.0, "number": 17, "open": false, "leads": 0},
	]
	for k in RockFormation.KINDS.size():
		items.append({"id": 10 + k, "kind": "rock", "what": RockFormation.KINDS[k], "at": [-125.0 + k * 30.0, 60.0], "lift": 0.0, "yaw": 0.0,
			"size": [5.0, 7.0, 5.0, 4.5, 9.0, 8.0][k], "seed": k + 1, "stone": 0})
	return {"version": 1, "terrain": {"size": 400.0, "cell": 2.5, "dune_height": 7.0, "seed": 7, "scatter": 0.0, "rim_height": 9.0, "rim_width": 45.0, "wind": [1.0, 0.0],
		"dunes": 1, "sharp": 0.8, "flat": 0.35}, "weather": 0, "items": items}


func dune() -> void:
	var sand := level.terrain.ground as SandGround
	place_on(Vector2(-47.0, -110.0))
	await frames(20)
	var from := player.global_position
	var highest := from.y
	var ran_before := 0
	var ran_after := 0
	var steepest_up := 0.0
	var steepest_down := 0.0
	for i in 1500:
		await frames(1, Vector3(1, 0, 0))
		var at := player.global_position
		highest = maxf(highest, at.y)
		var running := 0
		for lobe: Dictionary in sand._lobes:
			running += 1 if lobe.runs else 0
		var normal := sand.normal_at(at.x, at.z)
		var steep := rad_to_deg(acos(clampf(normal.y, -1.0, 1.0)))
		if at.x < -1.5:
			ran_before = maxi(ran_before, running)
			steepest_up = maxf(steepest_up, steep)
		elif at.x > 1.0:
			ran_after = maxi(ran_after, running)
			steepest_down = maxf(steepest_down, steep)
		if at.x > 16.0:
			break
	check("he walks up the back of a dune and over its crest", player.global_position.x > 16.0 and highest - from.y > 5.0, "rose %.1f m, the back %.0f degrees at its steepest" % [highest - from.y, steepest_up])
	check("the back of a dune is 10 to 15 degrees at its steepest", steepest_up > 9.0 and steepest_up < 16.0, "%.1f" % steepest_up)
	check("no sand runs under him on the way up", ran_before == 0)
	check("the slip face is at the angle sand lies at", steepest_down > 28.0 and steepest_down < 36.0, "%.1f degrees" % steepest_down)
	check("on the slip face the sand lets go", ran_after > 0, "%d lobes running at once" % ran_after)


func rocks() -> void:
	for k in RockFormation.KINDS.size():
		var rock := level.nodes[10 + k] as RockFormation
		# (he may stand under the cap of a mushroom, and under a block of an outcrop that leans)
		var inside := await throw_at(rock, rock.size * 0.75 + 5.0, rock.height, rock.kind == RockFormation.Kind.MUSHROOM or rock.kind == RockFormation.Kind.OUTCROP)
		check("he cannot get inside a %s" % RockFormation.KINDS[k], inside == "", inside)


func cliffs() -> void:
	var mesa := level.nodes[3] as Cliff
	var inside := await throw_at(mesa, 30.0, mesa.height, false)
	check("he cannot get inside a mesa", inside == "", inside)
	var cliff := level.nodes[4] as Cliff
	inside = await throw_at(cliff, 48.0, cliff.height, false)
	check("he cannot get inside a cliff", inside == "", inside)
	# Up its ledges: from the top of the scree, ledge by ledge, to its top.
	for made: Cliff in [mesa, cliff]:
		var named := "the mesa" if made == mesa else "the cliff"
		var foot := made.global_transform * made.ways_up[0]
		place(foot + Vector3.UP * 0.3)
		await frames(30)
		var steps: Array = made.ledges[0]
		var reached := 0
		for top: Vector3 in steps:
			if await go_to(made.global_transform * top, 480):
				reached += 1
		check("the ledges of %s are climbed, to its top" % named, reached == steps.size() and player.global_position.y > made.global_position.y + made.height - 0.4,
				"%d of %d ledges, ends %.1f m up of %.1f" % [reached, steps.size(), player.global_position.y - made.global_position.y, made.height])
		check("he can walk about on top of %s" % named, player.is_on_floor())


func doors() -> void:
	var opened := level.nodes[5] as TombDoor
	var shut := level.nodes[6] as TombDoor
	var went_in := [false]
	opened.entered.connect(func() -> void: went_in[0] = true)
	var fell := [false]
	shut.entered.connect(func() -> void: fell[0] = true)
	for door: TombDoor in [opened, shut]:
		place(door.global_transform * Vector3(0.0, 0.3, 9.0))
		await frames(20)
		for i in 500:
			await frames(1, -door.global_basis.z)
			if i % 50 == 49:
				player._queue_jump()
		touch.move = Vector2.ZERO
	check("walking in at an open tomb doorway says so", went_in[0])
	var local := shut.global_transform.affine_inverse() * player.global_position
	check("a shut doorway keeps him out", not fell[0] and local.z > 0.3, "he is %.2f m in front of the cliff" % local.z)
	check("both are in the group tomb_doors", opened.is_in_group(&"tomb_doors") and shut.is_in_group(&"tomb_doors"))


## The level editor, on its panels for a desk and on its screen for a phone: each new thing is put
## in, changed and made again; the kind of dunes is changed on the Level page, and the ground follows.
func editing(phone: bool) -> void:
	await open(layout_for_tests())
	var named := "phone" if phone else "desk"
	var editor := LevelEditor.new()
	editor.phone = phone
	scene.get_node("HUD").add_child(editor)
	editor.open()
	await frames(5)
	var made := 0
	var remade := 0
	var wanted := [["cliff", "", Cliff], ["cliff", "mesa", Cliff], ["rock", "mushroom", RockFormation], ["rock", "outcrop", RockFormation], ["rocks", "", RockField],
		["valley", "", KingsValley], ["tomb_door", "", TombDoor]]
	for entry: Array in wanted:
		editor._remember()
		var item := LevelLayout.new_item(editor.layout, entry[0], entry[1], Vector2(-150.0 + made * 45.0, -150.0 if entry[0] != "valley" else 60.0))
		editor.layout["items"].append(item)
		level.make(item)
		editor._choose(item)
		editor._changed(item, "at")
		if phone:
			editor._phone._show("change")
		var first: Node = level.nodes.get(item["id"])
		if first != null and is_instance_of(first, entry[2]):
			made += 1
		# (a number of its own is changed: it is made again)
		item["seed"] = 5.0
		editor._changed(item, "seed")
		var second: Node = level.nodes.get(item["id"])
		if second != null and second != first and is_instance_of(second, entry[2]):
			remade += 1
	check("the editor (%s) puts in each new thing" % named, made == wanted.size(), "%d of %d" % [made, wanted.size()])
	check("the editor (%s) makes each again when it is changed" % named, remade == wanted.size(), "%d of %d" % [remade, wanted.size()])
	# The Level page: its rows are there, and the kind of dunes changes the ground.
	editor._choose({})
	if phone:
		editor._phone._of_level = true
		editor._phone._show("change")
	else:
		editor._show_inspector()
	var own: Dictionary = editor.layout["terrain"]
	editor._remember()
	editor._put_number(own, "dunes", 3.0, "terrain")
	editor._put_number(own, "hills", 0.5, "terrain")
	for i in 90:
		await process_frame
	check("the editor (%s) changes the kind of dunes and puts the far hills up" % named, level.terrain.dunes == 3 and level.get_node_or_null(^"Horizon") != null and own.has("sharp"),
			"dunes %d, made in %.0f ms" % [level.terrain.dunes, level.terrain.made_in])
	var valleys := 0
	for node: Node in level.nodes.values():
		valleys += 1 if node is KingsValley and is_instance_valid(node) and (node as KingsValley).doors.size() == 4 else 0
	check("the editor (%s) stands the rock on the new ground" % named, valleys == 1)
	editor._step_back()
	for i in 10:
		await process_frame
	check("the editor (%s) undoes it" % named, level.terrain.dunes == 1)
	var kept := LevelLayout.from_text(LevelLayout.to_text(editor.layout))
	check("the level with all of it in is saved and read back", (kept.get("items", []) as Array).size() == (editor.layout["items"] as Array).size())
	paused = false
	editor.queue_free()


## Walking in at an open door that leads to a tomb opens the tomb, and the way back is kept.
func into_a_tomb() -> void:
	var layout := layout_for_tests()
	layout["items"][4]["leads"] = 2
	layout["items"][4]["tomb_seed"] = 12
	await open(layout)
	current_scene = scene
	TombLevel.bare = true
	var door := level.nodes[5] as TombDoor
	place(door.global_transform * Vector3(0.0, 0.3, 9.0))
	await frames(20)
	for i in 500:
		if not is_instance_valid(door):
			break
		await frames(1, -door.global_basis.z)
	for i in 30:
		await process_frame
	var now := current_scene
	var tomb := now.get_node_or_null(^"Level") as TombLevel if now else null
	check("an open door that leads to a tomb opens it", now != null and now.scene_file_path == "res://tomb.tscn" and tomb != null and tomb.seed_value == 12 and tomb.view == "3d",
			now.scene_file_path if now else "no scene")
	check("and the way back to the desert is kept", TombLevel.back_to == "res://desert.tscn" and TombLevel.back_at != Vector3.INF, "%s at %s" % [TombLevel.back_to, TombLevel.back_at])
	scene = null


# --- Driving him ---

func open(layout: Dictionary) -> void:
	if scene:
		scene.queue_free()
		await process_frame
		await process_frame
	var file := FileAccess.open(KEPT, FileAccess.WRITE)
	file.store_string(LevelLayout.to_text(layout))
	file.close()
	scene = (load("res://desert.tscn") as PackedScene).instantiate()
	root.add_child(scene)
	level = scene.get_node("Level") as Desert
	player = scene.get_node("Player") as Player
	cam = scene.get_node("Camera") as Camera3D
	touch = scene.get_node("HUD/TouchControls") as TouchControls
	touch.set_process_input(false)
	player.set_process_unhandled_input(false)
	for i in 30:
		await physics_frame


## Throws him at a thing from eight ways round, running and then jumping as he
## goes, and then has him walk away. Says what went wrong, or nothing.
func throw_at(thing: Node3D, from_far: float, high: float, hollow_under: bool) -> String:
	var middle := thing.global_position
	for jumping: bool in [false, true]:
		for way in 8:
			var out := Vector3(cos(way * TAU / 8.0 + 0.2), 0.0, sin(way * TAU / 8.0 + 0.2))
			var from := middle + out * from_far
			place_on(Vector2(from.x, from.z))
			await frames(10)
			for i in 300:
				await frames(1, -out)
				if jumping and i % 28 == 0:
					touch.jump_held = true
					player._queue_jump()
				elif jumping and i % 28 == 6:
					touch.jump_held = false
				if player.state == Player.State.HANG and i % 40 == 39:
					player._queue_jump()
			touch.jump_held = false
			var at := player.global_position
			# Is there rock of this thing over his head? (Under a mushroom's cap there may be.)
			var above := PhysicsRayQueryParameters3D.create(Vector3(at.x, middle.y + high + 6.0, at.z), at + Vector3.UP * 1.9, 1)
			var hit := player.get_world_3d().direct_space_state.intersect_ray(above)
			if not hit.is_empty() and not hollow_under and _belongs(hit["collider"], thing):
				return "from %d (%s) he ended at %s with rock over him at %.1f" % [way, "jumping" if jumping else "running", at, (hit["position"] as Vector3).y]
			if at.y < level.height_at(at.x, at.z) - 1.0 and at.y < middle.y - 1.0:
				return "from %d he went through the ground, to %s" % [way, at]
			# And he can get away again.
			var was := player.global_position
			var moved := 0.0
			for i in 240:
				await frames(1, out)
				moved = maxf(moved, Vector2(player.global_position.x - was.x, player.global_position.z - was.z).length())
				if i % 60 == 59 and moved < 0.5:
					player._queue_jump()
			touch.move = Vector2.ZERO
			if moved < 1.5:
				return "from %d (%s) he was wedged at %s, state %d" % [way, "jumping" if jumping else "running", was, player.state]
	return ""


func _belongs(what: Variant, to: Node) -> bool:
	return what is Node and (what == to or to.is_ancestor_of(what))


## Walks to a place, jumping when he stops and pulling up when he hangs. Says whether he got there.
func go_to(to: Vector3, limit: int) -> bool:
	var checked := player.global_position
	for count in limit:
		var at := player.global_position
		var toward := Vector3(to.x - at.x, 0.0, to.z - at.z)
		if toward.length() < 0.8 and absf(at.y - to.y) < 0.6 and player.is_on_floor():
			touch.move = Vector2.ZERO
			return true
		await frames(1, toward.normalized() if toward.length() > 0.2 else Vector3.ZERO)
		if player.state == Player.State.HANG:
			if count % 20 == 0:
				player._queue_jump()
		elif count % 45 == 44:
			if player.global_position.distance_to(checked) < 0.4 or at.y < to.y - 0.5:
				touch.jump_held = true
				player._queue_jump()
			else:
				touch.jump_held = false
			checked = player.global_position
	touch.move = Vector2.ZERO
	touch.jump_held = false
	return false


func place_on(at: Vector2) -> void:
	var probe := PhysicsRayQueryParameters3D.create(Vector3(at.x, 80.0, at.y), Vector3(at.x, -40.0, at.y), 1)
	var hit := level.get_world_3d().direct_space_state.intersect_ray(probe)
	place(Vector3(at.x, ((hit["position"] as Vector3).y if not hit.is_empty() else level.height_at(at.x, at.y)) + 0.1, at.y))


func place(at: Vector3) -> void:
	touch.move = Vector2.ZERO
	touch.jump_held = false
	player.state = Player.State.FREE
	player.global_position = at
	player.velocity = Vector3.ZERO
	player._spawn = Transform3D(Basis.IDENTITY, at)
	player.respawn()
	player._reset_visuals()


func steer(world: Vector3) -> void:
	var basis := cam.global_basis
	var right := Vector3(basis.x.x, 0, basis.x.z).normalized()
	var forward := Vector3(-basis.z.x, 0, -basis.z.z).normalized()
	touch.move = Vector2(world.dot(right), -world.dot(forward))


func frames(count: int, heading := Vector3.INF) -> void:
	for i in count:
		if heading != Vector3.INF:
			steer(heading)
		await physics_frame
