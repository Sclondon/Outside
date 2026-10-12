extends SceneTree
## Not part of the game. Stands Abu Simbel (scripts/abu_simbel.gd) on ground of its own with nothing drawn and
## says whether each thing is so: it is made from `new()` with both temples, with either alone, and the same
## numbers make the same place; the boy walks from the terrace in at each door and down the axis to each
## sanctuary; with the sand at 0.5 and at 1 he still gets in (at 1, only by ducking under the lintel);
## run and jumped at the facade, the colossi, what fell and the pillars from many sides he is never inside
## stone; the hill can be got up by the ramp at its back; and the temple is on only while the sun down its axis
## reaches the sanctuary.
## godot --headless --path . --fixed-fps 60 --script tools/abu_simbel_test.gd [-- small=<scale>]
## Ends with PASSED or FAILED (and exits 0 or 1).

var stage: Node3D
var failed := 0
var boy: Player
var touch: TouchControls
var temple: AbuSimbel
var size := 1.0
var worst := ""


func _initialize() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("small="):
			size = float(arg.trim_prefix("small="))
	stage = Node3D.new()
	root.add_child(stage)
	var body := StaticBody3D.new()
	var collider := CollisionShape3D.new()
	collider.shape = WorldBoundaryShape3D.new()
	body.add_child(collider)
	stage.add_child(body)
	# (a camera that looks along -Z, so that the stick's right is +X and its up is -Z)
	var camera := Camera3D.new()
	camera.position = Vector3(0, 300, 0)
	stage.add_child(camera)
	camera.make_current()
	run.call_deferred()


func check(what: String, passed: bool, detail := "") -> void:
	print("PASS " if passed else "FAIL ", what, "  ", detail)
	if not passed:
		failed += 1


func stand(numbers: Dictionary) -> AbuSimbel:
	if temple:
		temple.queue_free()
		await physics_frame
	numbers["scale"] = size
	temple = AbuSimbel.from_item(numbers)
	stage.add_child(temple)
	for i in 5:
		await physics_frame
	return temple


## What is solid of it, as one number: the same place gives the same.
func print_of(made: AbuSimbel) -> int:
	var parts: Array = []
	for child in made.get_children():
		if child is CollisionShape3D:
			var shape: Shape3D = (child as CollisionShape3D).shape
			parts.append((child as CollisionShape3D).transform)
			if shape is BoxShape3D:
				parts.append((shape as BoxShape3D).size)
			elif shape is ConcavePolygonShape3D:
				parts.append((shape as ConcavePolygonShape3D).get_faces().size())
		elif child is Marker3D:
			parts.append((child as Marker3D).position)
	var sand := made.get_node_or_null("Sand") as MeshInstance3D
	if sand:
		parts.append(sand.mesh.get_faces())
	return hash(parts)


func put(at: Vector3) -> void:
	touch.move = Vector2.ZERO
	touch.jump_held = false
	touch.duck_held = false
	boy.state = Player.State.FREE
	boy.global_position = at
	boy.velocity = Vector3.ZERO
	boy._spawn = Transform3D(Basis.IDENTITY, at)
	boy.respawn()
	boy._reset_visuals()
	for i in 10:
		await physics_frame


func marker(called: String) -> Vector3:
	return (temple.get_node(called) as Marker3D).global_position


## Whether he is in stone now (and notes where, if so).
func in_stone() -> bool:
	var at := boy.global_position + Vector3.UP * 0.6
	if temple.is_in_stone(at):
		worst = str(temple.to_local(at))
		return true
	return false


## Makes for each place in turn, for so many seconds at most; ducking if told to, and jumping at what stops him
## if `jumps`. Returns how far he was from the last of them when he stopped. Counts the steps he was in stone.
func go(places: Array, seconds: float, duck := false, jumps := false) -> Array:
	var stuck := 0
	var checked := boy.global_position
	var i := 0
	var crawled := false
	for count in int(seconds * 60.0):
		var to: Vector3 = places[i]
		var toward := Vector3(to.x - boy.global_position.x, 0, to.z - boy.global_position.z)
		if toward.length() < 0.7:
			i += 1
			if i >= places.size():
				break
			continue
		toward = toward.normalized()
		touch.move = Vector2(toward.x, toward.z)
		touch.duck_held = duck
		await physics_frame
		crawled = crawled or boy.is_crawling
		if boy.state == Player.State.HANG:
			touch.jump_held = false
			for wait in 10:
				await physics_frame
			boy._queue_jump()
			for wait in 80:
				await physics_frame
		if in_stone():
			stuck += 1
		if jumps and count % 40 == 39:
			if boy.global_position.distance_to(checked) < 0.6:
				touch.jump_held = true
				boy._queue_jump()
			else:
				touch.jump_held = false
			checked = boy.global_position
	touch.move = Vector2.ZERO
	touch.duck_held = false
	touch.jump_held = false
	var last: Vector3 = places[places.size() - 1]
	return [Vector2(last.x - boy.global_position.x, last.z - boy.global_position.z).length(), stuck, crawled]


func run() -> void:
	for action: StringName in InputMap.get_actions():
		if not String(action).begins_with("ui_"):
			InputMap.action_erase_events(action)
	touch = TouchControls.new()
	touch.visible = false
	stage.add_child(touch)
	touch.set_process_input(false)
	boy = load("res://player.tscn").instantiate()
	boy.position = Vector3(0, 0.05, 60) * size
	boy.rest_enabled = false
	stage.add_child(boy)
	boy.set_process_unhandled_input(false)
	var s := size

	# --- It is made, whole, from its numbers.
	var prints := {}
	for which in 3:
		var made := await stand({"which": which})
		var name: String = ["both temples", "the Great Temple alone", "the Small Temple alone"][which]
		check("made with " + name, made.triangles > 5000 and made.shapes > 40 and made.get_node_or_null("GreatDoor" if which != 2 else "SmallDoor") != null,
			"%d triangles, %d draw calls, %d shapes, %.0f ms" % [made.triangles, made.draw_calls, made.shapes, made.build_ms])
		prints[which] = print_of(made)
	var again := await stand({"which": 0})
	check("the same numbers make the same place", print_of(again) == prints[0])
	var other := await stand({"which": 0, "drift": 0.8})
	check("other numbers make another", print_of(other) != prints[0])

	# --- He walks in at each door and down the axis to each sanctuary.
	await stand({"which": 0, "drift": 0.0})
	await put(Vector3(4.0, 1.3, 16.0) * s)
	var went := await go([marker("GreatDoor"), marker("GreatHall"), marker("GreatSanctuary")], 40.0)
	check("from the terrace through the door to the sanctuary of the Great Temple", went[0] < 1.0 and went[1] == 0, "ended %.1f m off, %d steps in stone %s" % [went[0], went[1], worst])
	var north := Transform3D(Basis(Vector3.UP, deg_to_rad(AbuSimbel.NORTH_TURN)), AbuSimbel.NORTH * s)
	await put(north * (Vector3(3.0, 0.8, 6.0) * s))
	went = await go([marker("SmallDoor"), marker("SmallHall"), marker("SmallSanctuary")], 30.0)
	check("and to the sanctuary of the Small Temple", went[0] < 1.0 and went[1] == 0, "ended %.1f m off, %d steps in stone %s" % [went[0], went[1], worst])

	# --- He can be got out again, and onto the hill by the ramp at its back.
	await put(marker("GreatSanctuary"))
	went = await go([marker("GreatHall"), marker("GreatDoor")], 40.0)
	check("and out again", went[0] < 1.0, "ended %.1f m off" % went[0])
	var top := marker("GreatTop")
	var foot := Vector2(0.0, -37.5 * s) + Vector2(-0.62, -0.78).normalized() * (9.0 * s + 46.0 * s / tan(deg_to_rad(27.0)) + 4.0)
	await put(Vector3(foot.x, 0.3, foot.y))
	went = await go([top], 60.0 * maxf(s, 0.5), false, true)
	check("up the ramp of sand to the top of the hill", went[0] < 3.0 and boy.global_position.y > top.y - 1.5, "ended %.1f m off, %.1f m up of %.1f" % [went[0], boy.global_position.y, top.y])

	# --- With the sand at 0.5 and at 1 he still gets in.
	for amount: float in [0.5, 1.0]:
		await stand({"which": 0, "drift": amount})
		await put(Vector3(-1.0, 1.3, 17.0) * s)
		went = await go([Vector3(0.0, 0.0, 9.0) * s, Vector3(0.0, 0.0, 1.5 * s)], 30.0)
		var at_door := boy.global_position.y
		var upright := [0.0, 0, false]
		if amount > 0.9:
			# (first on his feet: he should not get under the lintel)
			upright = await go([Vector3(0.0, 0.0, -5.0 * s)], 8.0)
		var inward := await go([Vector3(0.0, 0.0, -3.0 * s), marker("GreatHall")], 60.0, amount > 0.9)
		check("with the sand at %.1f he gets into the great hall" % amount, inward[0] < 1.5 and inward[1] == 0,
			"%s (he stood %.1f m up at the door; ended %.1f m off, %d steps in stone %s)" % [("crawling" if inward[2] else "ducking") if amount > 0.9 else "walking", at_door, inward[0], inward[1], worst])
		if amount > 0.9:
			check("and at 1 only by ducking under the lintel, not on his feet", upright[0] > 3.0 * s and at_door > 4.0 * s, "on his feet he stopped %.1f m short" % upright[0])

	# --- Thrown at it from many sides, running and jumping, he is never inside stone.
	await stand({"which": 0, "drift": 0.3})
	var bad := 0
	var runs := 0
	var aims: Array = []
	for x: float in [-13.4, -5.1, 5.1, 13.4]:
		# (each colossus: at its feet from the front, from either side, and into the gap beside it)
		aims.append([Vector3(x, 1.3, 17.0), Vector3(x, 0, 2.0)])
		aims.append([Vector3(x - 9.0, 1.3, 13.0), Vector3(x + 1.0, 0, 3.0)])
		aims.append([Vector3(x + 9.0, 1.3, 13.0), Vector3(x - 1.0, 0, 3.0)])
	for x: float in [-9.25, 9.25, -16.5, 16.5, 0.0]:
		aims.append([Vector3(x * 0.8, 1.3, 16.0), Vector3(x, 0, -1.0)])
	# (what fell, from all round)
	for turn in 6:
		var from := Vector3(-10.0, 1.3, 12.0) + Vector3(sin((turn + 0.5) * TAU / 6.0), 0, cos((turn + 0.5) * TAU / 6.0)) * 6.5
		aims.append([from, Vector3(-10.0, 0, 11.0)])
	# (the pillars of the great hall and the second, from the aisle, the side aisles and cornerwise; and the gods)
	for z: float in [-6.4, -10.5, -14.6, -18.7]:
		aims.append([Vector3(0.0, 1.3, z - 2.0), Vector3(6.0, 0, z)])
		aims.append([Vector3(7.6, 1.3, z + 2.2), Vector3(4.0, 0, z - 0.5)])
		aims.append([Vector3(-0.5, 1.3, z + 2.0), Vector3(-6.0, 0, z - 0.5)])
	aims.append([Vector3(0.0, 1.3, -24.0), Vector3(3.0, 0, -28.0)])
	aims.append([Vector3(-4.5, 1.3, -24.5), Vector3(-2.5, 0, -29.0)])
	aims.append([Vector3(0.0, 1.3, -38.0), Vector3(1.2, 0, -45.0)])
	aims.append([Vector3(-1.5, 1.3, -38.0), Vector3(-0.5, 0, -45.0)])
	for aim: Array in aims:
		# (not from a place that is itself in stone)
		if temple.is_in_stone((aim[0] as Vector3) * s + Vector3.UP * 0.6):
			continue
		await put(aim[0] * s)
		worst = ""
		var thrown := await go([aim[1] * s], 4.5 * maxf(s, 0.6), false, true)
		runs += 1
		if thrown[1] > 0:
			bad += 1
			print("  in stone going from ", aim[0], " at ", aim[1], ": ", worst)
	# (and the small temple: its colossi, its door, its pillars)
	for x: float in [-11.5, -7.2, -3.0, 0.0, 3.0, 7.2, 11.5]:
		await put(north * (Vector3(x * 0.7, 0.8, 7.0) * s))
		var thrown := await go([north * (Vector3(x, 0, -0.5) * s)], 3.5, false, true)
		runs += 1
		bad += 1 if thrown[1] > 0 else 0
	for z: float in [-5.0, -8.0, -11.0]:
		await put(north * (Vector3(0.0, 0.8, z + 1.5) * s))
		var thrown := await go([north * (Vector3(3.2, 0, z) * s)], 3.0, false, true)
		runs += 1
		bad += 1 if thrown[1] > 0 else 0
	check("run and jumped at the facades, the colossi, what fell and the pillars, he is never inside stone", bad == 0, "%d of %d runs" % [bad, runs])

	# --- The sanctuary is on only while the sun reaches it.
	await put(Vector3(8.0, 1.3, 16.0) * s)
	var dark := await stand({"which": 1, "drift": 0.0, "sun": false})
	for i in 30:
		await physics_frame
	check("without the sun on the axis it is off", not dark.on)
	var lit := await stand({"which": 1, "drift": 0.0, "sun": true})
	var said: Array = []
	lit.changed.connect(func(on: bool) -> void: said.append(on))
	for i in 30:
		await physics_frame
	check("with the sun on the axis and the door clear it is on", lit.on)
	await put(lit.to_global(Vector3(lit.to_local(lit.beam.global_position).x, 1.3 * s, 10.0 * s)))
	for i in 20:
		await physics_frame
	check("the boy standing in the light puts it off, and it says so", not lit.on and said == [false], "the light ends on %s" % lit.beam.ends_on)
	await put(Vector3(8.0, 1.3, 16.0) * s)
	for i in 20:
		await physics_frame
	check("and it comes on again when he steps out of it", lit.on and said == [false, true])
	var buried := await stand({"which": 1, "drift": 1.0, "sun": true})
	for i in 30:
		await physics_frame
	check("with the door all but buried the sun does not reach it", not buried.on)

	# --- A level keeps it: as the editor lists it and a layout holds it, written out and read back, it is the same place.
	var listed := false
	for entry: Array in LevelLayout.PALETTE["Stone"]:
		listed = listed or (entry[0] == "Abu Simbel" and entry[1] == "abusimbel")
	var item := LevelLayout.new_item({"items": []}, "abusimbel", "", Vector2(600.0, 600.0))
	check("the level editor has it on the Stone page, at its true size", listed and is_equal_approx(item.get("scale", 0.0), 1.0) and LevelLayout.fields(item).size() == 6)
	item["drift"] = 0.6
	item["sun"] = true
	item["scale"] = size
	var first := AbuSimbel.from_item(item)
	stage.add_child(first)
	var second := AbuSimbel.from_item(JSON.parse_string(JSON.stringify(item)))
	second.position.x = 1000.0
	stage.add_child(second)
	await physics_frame
	check("and a level keeps it", first.sun_on_axis and is_equal_approx(first.drift, 0.6) and print_of(first) == print_of(second))

	print("PASSED" if failed == 0 else "FAILED (%d)" % failed)
	quit(0 if failed == 0 else 1)
