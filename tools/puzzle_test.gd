extends SceneTree
## Not part of the game. Runs the puzzle parts with nothing drawn and says whether each thing happened. First each by
## itself, on a bare floor, with the boy: he pulls a lever over and back, and one that springs back does; he carries a
## key to its lock (and the wrong key does nothing); a timed plate goes off after its time; a beam of light reaches a
## sun disc by way of two mirrors once he has turned one of them, and is stopped by a block and by the boy; a sluice
## lets a tank of water down and he stands on its floor, then up and he swims again; a jar is set on an offering
## table; a torch lights a brazier; a seal stone takes him and not a block. Then in the desert, made from items as the
## level editor makes them: each of them opens the door linked to it, a lever covers the light and opens the sluice,
## and all of it is taken out and put back.
## godot --headless --path . --fixed-fps 60 --script tools/puzzle_test.gd
## Ends with PASSED or FAILED (and exits 0 or 1).

var stage: Node3D
var failed := 0
var boy: Player
var level: Desert


func _initialize() -> void:
	stage = Node3D.new()
	root.add_child(stage)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-48.0, -35.0, 0.0)
	stage.add_child(sun)
	box(Vector3(30, -1, 0), Vector3(120, 2, 60))
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


func run() -> void:
	for action: StringName in InputMap.get_actions():
		if not String(action).begins_with("ui_"):
			InputMap.action_erase_events(action)
	var touch := TouchControls.new()
	touch.visible = false
	stage.add_child(touch)
	touch.set_process_input(false)
	boy = load("res://player.tscn").instantiate()
	boy.position = Vector3(0, 0.05, 0.9)
	boy.rest_enabled = false
	stage.add_child(boy)
	boy.set_process_unhandled_input(false)
	await wait(0.5)

	await levers()
	await keys()
	await timed()
	await light()
	await water()
	await tomb_things()
	boy.set_physics_process(false)
	stage.queue_free()
	await wait(0.2)
	await in_the_desert()
	print("PASSED" if failed == 0 else "FAILED (%d)" % failed)
	quit(1 if failed > 0 else 0)


func levers() -> void:
	var lever := place(Lever.new(), Vector3(0, 0, 0)) as Lever
	var said := [0]
	lever.changed.connect(func(_on: bool) -> void: said[0] += 1)
	put(Vector3(0, 0.05, 0.9), PI)
	await wait(0.4)
	check("a lever starts off", not lever.on and lever.is_in_group(&"workable"))
	boy._act()
	await wait(0.2)
	check("he pulls it over with the act button", lever.on and said[0] == 1 and boy.carried == null, "said %d" % said[0])
	await wait(0.8)
	check("and the arm goes over", lever._arm.rotation.x > Lever.LEAN - 0.01, "%.2f" % lever._arm.rotation.x)
	boy._act()
	await wait(0.3)
	check("pulled again it goes back", not lever.on and said[0] == 2)
	await wait(0.6)
	# From too far off he does not reach it.
	put(Vector3(0, 0.05, 2.4), PI)
	await wait(0.3)
	boy._act()
	await wait(0.3)
	check("he does not reach it from across the room", not lever.on)
	# Something to pick up that is nearer is picked up instead.
	var key := place(DoorKey.new(), Vector3(0.9, 0.1, 0.9)) as DoorKey
	put(Vector3(0.5, 0.05, 0.9), PI)
	await wait(0.5)
	boy._act()
	await wait(0.7)
	check("a thing to pick up that is nearer is picked up instead", boy.carried == key and not lever.on)
	boy.let_go()
	key.queue_free()
	lever.queue_free()
	# One that springs back.
	var sprung := Lever.new()
	sprung.returns = 1.5
	place(sprung, Vector3(0, 0, -6))
	put(Vector3(0, 0.05, -5.1), PI)
	await wait(0.6)
	boy._act()
	await wait(0.2)
	check("a lever that springs back is on when pulled", sprung.on)
	await wait(1.0)
	check("and still on a second later", sprung.on, "%.2f s left" % sprung.left)
	await wait(0.8)
	check("and off again when its time is up", not sprung.on)
	sprung.reset()
	sprung.queue_free()


func keys() -> void:
	var lock := place(KeyLock.new(), Vector3(8, 0, 0)) as KeyLock
	var wrong := DoorKey.new()
	wrong.which = DoorKey.Metal.BRONZE
	place(wrong, Vector3(8, 0.1, 0.7))
	var key := place(DoorKey.new(), Vector3(8, 0.1, 5.0)) as DoorKey
	await wait(1.2)
	check("a key of another metal does not open a lock", not lock.on and wrong.held_by == null)
	put(Vector3(8, 0.05, 5.6), PI)
	await wait(0.4)
	boy._act()
	await wait(0.8)
	check("he picks the key up", boy.carried == key)
	check("the lock is shut until it is brought", not lock.on)
	put(Vector3(8, 0.05, 0.9), PI)
	var opened := await wait(3.0, func() -> bool: return lock.on)
	check("brought to its lock, the key opens it", opened and lock.key == key)
	check("and is taken out of his hand, into the keyhole", boy.carried == null and key.held_by == lock and key.global_position.distance_to(lock.hole()) < 0.05 and not key.is_in_group(&"throwable"),
			"%.2f m from the hole" % key.global_position.distance_to(lock.hole()))
	await wait(1.0)
	check("it stays open", lock.on)
	lock.reset()
	await wait(0.1)
	check("put back, the lock is shut and the key is where it was put", not lock.on and key.held_by == null and key.is_in_group(&"throwable") and key.global_position.distance_to(Vector3(8, 0.1, 5.0)) < 0.3)
	# A lock taken out of the level with its key in it lets the key go.
	key.global_position = lock.hole() + Vector3(0, 0, 0.3)
	await wait(1.5)
	check("a key thrown down at the lock opens it too", lock.on)
	lock.queue_free()
	await wait(0.2)
	check("taken away, the lock lets its key go", key.held_by == null and not key.freeze)
	key.queue_free()
	wrong.queue_free()


func timed() -> void:
	var plate := TimedPlate.new()
	plate.seconds = 1.5
	plate.span = Vector3(1.2, 0.5, 1.2)
	place(plate, Vector3(16, 0, 0))
	plate.collision_mask = 2
	await wait(0.3)
	check("a timed plate starts up", not plate.pressed)
	put(Vector3(16, 0.05, 0))
	await wait(0.5)
	check("it goes down under him", plate.pressed and is_equal_approx(plate.left, 1.5))
	put(Vector3(16, 0.05, 4))
	await wait(1.0)
	check("and is still on a second after he has left it", plate.pressed and plate.left < 0.8 and plate.left > 0.3, "%.2f s left" % plate.left)
	await wait(0.8)
	check("and off when its time is up", not plate.pressed and plate.left == 0.0)
	plate.queue_free()


func light() -> void:
	# The light sets out along +Z; one mirror sends it along +X, the next back along -Z to the disc.
	var beam := place(SunBeam.new(), Vector3(24, 0, 0)) as SunBeam
	var first := Mirror.new()
	first.turned = 2
	place(first, Vector3(24, 0, 6))
	var second := Mirror.new()
	second.turned = 1
	second.fixed = true
	place(second, Vector3(30, 0, 6))
	var disc := place(SunDisc.new(), Vector3(30, 0, 0)) as SunDisc
	put(Vector3(24.9, 0.05, 6.7), -PI * 0.5)
	await wait(0.5)
	check("the light goes out from its lens along +Z", beam.path.size() >= 2 and beam.way().is_equal_approx(Vector3(0, 0, 1)) and absf(beam.path[0].y - 0.7) < 0.01)
	check("a mirror edge on to it stops it", beam.bounces == 0 and not disc.on and Mirror.of(beam.ends_on) == first, "ends on %s" % beam.ends_on)
	boy._act()
	await wait(2.0, func() -> bool: return first.is_still())
	await wait(0.2)
	check("he turns the mirror a step with the act button", first.steps == 3 and absf(first.normal().dot(Vector3(1, 0, -1).normalized())) > 0.999)
	check("and the light goes by two mirrors to the sun disc", beam.bounces == 2 and disc.on and SunDisc.of(beam.ends_on) == disc and beam.path.size() == 4,
			"%d mirrors, %d points, ends on %s" % [beam.bounces, beam.path.size(), beam.ends_on])
	if beam.path.size() == 4:
		check("along the way it should", beam.path[1].distance_to(Vector3(24, 0.7, 6)) < 0.05 and beam.path[2].distance_to(Vector3(30, 0.7, 6)) < 0.05 and beam.path[3].distance_to(Vector3(30, 0.7, 0)) < 0.3,
				str(beam.path))
	# A block in the way.
	var block := box(Vector3(30, 0.45, 3), Vector3(0.9, 0.9, 0.9))
	await wait(0.2)
	check("a block stood in the light stops it", not disc.on and beam.ends_on == block)
	block.queue_free()
	await wait(0.2)
	check("and it is on again when the block is gone", disc.on)
	put(Vector3(27, 0.05, 6))
	await wait(0.3)
	check("he stops it himself, standing in it", not disc.on and beam.ends_on == boy)
	put(Vector3(27, 0.05, 9))
	await wait(0.2)
	# The fixed mirror is not his to turn.
	put(Vector3(30.9, 0.05, 6.7), -PI * 0.5)
	await wait(0.6)
	boy._act()
	await wait(0.8)
	check("a fixed mirror is not turned", second.steps == 1 and disc.on)
	# Covered, there is no light; and a disc that latches stays on.
	beam.shining = false
	await wait(0.2)
	check("with the light covered the disc is off", not disc.on and beam.path.is_empty())
	disc.latches = true
	beam.shining = true
	await wait(0.2)
	beam.shining = false
	await wait(0.2)
	check("a disc that latches stays on", disc.on and not disc.is_struck())
	# A beam with no mirror to meet runs out where its reach does.
	first.queue_free()
	beam.shining = true
	beam.reach = 12.0
	await wait(0.2)
	check("light that meets nothing runs out", beam.ends_on == null and beam.path.size() == 2 and absf(beam.path[0].distance_to(beam.path[1]) - 12.0) < 0.01)
	# Mirrors face to face do not hold it for ever.
	var near := Mirror.new()
	near.fixed = true
	place(near, Vector3(24, 0, 3))
	var far := Mirror.new()
	far.fixed = true
	place(far, Vector3(24, 0, -3))
	beam.reach = 500.0
	await wait(0.2)
	check("between two mirrors face to face it gives up", beam.bounces == SunBeam.BOUNCES, "%d" % beam.bounces)
	for node: Node in [beam, second, disc, near, far]:
		node.queue_free()


func water() -> void:
	# A tank four metres square with two metres of water in it, standing on the floor.
	var pool := Pool.new()
	pool.size = Vector3(4, 2, 4)
	place(pool, Vector3(40, 2.0, 0))
	for way: Vector3 in [Vector3(1, 0, 0), Vector3(-1, 0, 0), Vector3(0, 0, 1), Vector3(0, 0, -1)]:
		box(Vector3(40, 1.5, 0) + way * 2.25, Vector3(0.5 + absf(way.z) * 4.5, 3.0, 0.5 + absf(way.x) * 4.5))
	var sluice := Sluice.new()
	sluice.drop = 1.7
	sluice.speed = 1.5
	place(sluice, Vector3(43, 0, 0))
	put(Vector3(40, 1.2, 0))
	var swam := await wait(3.0, func() -> bool: return boy.state == Player.State.SWIM)
	await wait(1.5)
	check("the sluice finds the tank", sluice.pool == pool)
	check("he swims in the full tank", swam and boy.state == Player.State.SWIM and boy.global_position.y > 0.7, "at %.2f" % boy.global_position.y)
	sluice.open = true
	var down := await wait(4.0, func() -> bool: return is_equal_approx(sluice.lowered, 1.7))
	await wait(1.0)
	check("opened, it lets the water down", down and absf(pool.surface_y() - 0.3) < 0.01 and absf(pool.depth_at(Vector3(40, 0, 0)) - 0.3) < 0.01, "surface at %.2f" % pool.surface_y())
	check("and he stands on the floor of the tank", boy.state == Player.State.FREE and boy.is_on_floor() and boy.global_position.y < 0.1, "at %.2f, state %d" % [boy.global_position.y, boy.state])
	sluice.open = false
	var up := await wait(4.0, func() -> bool: return sluice.lowered == 0.0)
	await wait(1.5)
	check("shut, the water comes up again", up and absf(pool.surface_y() - 2.0) < 0.01)
	check("and takes him up with it", boy.state == Player.State.SWIM and boy.global_position.y > 0.7, "at %.2f" % boy.global_position.y)
	# Let right down, there is no water left.
	sluice.drop = 2.0
	sluice.open = true
	await wait(3.0, func() -> bool: return is_equal_approx(sluice.lowered, 2.0))
	check("let right down, the tank is dry", pool.depth_at(Vector3(40, 0.0, 0)) <= 0.001 and not pool.water.visible)
	sluice.queue_free()
	await wait(0.2)
	check("taken away, the sluice leaves the water as it was", absf(pool.surface_y() - 2.0) < 0.01 and pool.water.visible)
	put(Vector3(50, 0.05, 6))
	pool.queue_free()
	await wait(0.3)


func tomb_things() -> void:
	# An offering table.
	var table := place(OfferingTable.new(), Vector3(50, 0, 0)) as OfferingTable
	var jar := (load("res://props/jar_canopic.tscn") as PackedScene).instantiate() as RigidBody3D
	place(jar, Vector3(50, 0.3, 4))
	var rock := RigidBody3D.new()
	rock.add_to_group(&"throwable")
	PuzzleKit.shape(rock, Vector3.ZERO, Vector3.ONE * 0.2)
	place(rock, Vector3(50, 0.2, 0.9))
	await wait(0.8)
	check("an offering table wants a jar, not a stone", not table.on and OfferingTable.is_offering(jar) and not OfferingTable.is_offering(rock))
	put(Vector3(50, 0.05, 4.6), PI)
	await wait(0.4)
	boy._act()
	await wait(0.8)
	put(Vector3(50, 0.05, 1.2), PI)
	await wait(0.5)
	check("he carries the jar to it: it is not given while he holds it", boy.carried == jar and not table.on)
	boy.let_go()
	var given := await wait(3.0, func() -> bool: return table.on)
	check("put down at the table, the jar is set on it", given and table.jar == jar and jar.freeze and jar.global_position.distance_to(table.place()) < 0.01 and jar.has_meta(&"offered"))
	table.latches = false
	jar.remove_meta(&"offered")
	jar.global_position = Vector3(50, 0.3, 6)
	jar.freeze = false
	await wait(0.3)
	check("a table that does not latch is off when the jar is taken away", not table.on and table.jar == null)
	for node: Node in [table, jar, rock]:
		node.queue_free()

	# A brazier to light.
	var brazier := place(ColdBrazier.new(), Vector3(58, 0, 0)) as ColdBrazier
	var dead := HandTorch.new()
	dead.lit = false
	dead.freeze = true
	place(dead, Vector3(58, 0.9, 0.6))
	var torch := HandTorch.new()
	torch.freeze = true
	place(torch, Vector3(58, 0.9, 4.0))
	await wait(0.6)
	check("a cold brazier is not lit by a torch that is out, nor one across the room", not brazier.on and brazier.fire == null)
	torch.global_position = Vector3(58.8, 0.9, 0.5)
	await wait(0.3)
	check("a burning torch brought to it lights it", brazier.on and brazier.fire != null)
	check("and a torch that was out takes fire from it", dead.lit and dead.fire != null)
	torch.global_position = Vector3(58, 0.9, 12)
	await wait(0.3)
	check("it stays lit", brazier.on)
	for node: Node in [brazier, dead, torch]:
		node.queue_free()

	# A seal stone.
	var seal := place(SealStone.new(), Vector3(66, 0, 0)) as SealStone
	var weight := RigidBody3D.new()
	PuzzleKit.shape(weight, Vector3.ZERO, Vector3.ONE * 0.6)
	place(weight, Vector3(66, 0.4, 0))
	await wait(0.6)
	check("a seal stone is not pressed by a block", not seal.pressed)
	put(Vector3(66, 0.05, 0.6))
	await wait(0.4)
	check("it is pressed by him", seal.pressed)
	put(Vector3(66, 0.05, 5))
	await wait(0.4)
	check("and stays down", seal.pressed)
	seal.queue_free()
	weight.queue_free()


# --- In the desert, made from items ---

func add(kind: String, what: String, at: Vector2, more := {}) -> Dictionary:
	var item := LevelLayout.new_item(level.layout, kind, what, at)
	item.merge(more, true)
	level.layout["items"].append(item)
	level.make(item)
	return item


# How far above the ground at a place a height is: what an item's `lift` must be to stand at that height.
func lift_to(at: Vector2, y: float) -> float:
	return y - level.height_at(at.x, at.y)


func node(item: Dictionary) -> Node3D:
	return level.nodes.get(item["id"])


func door_for(trigger: Dictionary, at: Vector2) -> TombParts.Door:
	return node(add("door", "", at, {"links": [trigger["id"]]})) as TombParts.Door


func in_the_desert() -> void:
	var scene: Node = load("res://desert.tscn").instantiate()
	root.add_child(scene)
	await wait(0.6)
	level = scene.get_node("Level")
	var him := scene.get_node("Player") as Player
	him.set_physics_process(false)
	var before: int = level.layout["items"].size()
	# Everything on the palette that is ours makes a node, with its fields as they start.
	var made := 0
	var wanted := 0
	for entry: Array in LevelLayout.PALETTE["Puzzle"]:
		if entry[1] in ["lever", "key", "lock", "beam", "mirror", "sundisc", "sluice", "offering", "brazier"] or entry[2] in ["timed", "seal"]:
			wanted += 1
			var item := add(entry[1], entry[2], Vector2(40.0 + wanted * 3.0, 80.0))
			if node(item) != null and LevelLayout.label(item) == entry[0] and not LevelLayout.fields(item).is_empty():
				made += 1
			level.forget(item["id"])
			level.layout["items"].erase(item)
	check("every puzzle part on the palette makes a node", made == wanted and wanted == 11, "%d of %d" % [made, wanted])

	var x := 60.0
	# A lever.
	var lever := add("lever", "", Vector2(x, 100.0))
	var lever_door := door_for(lever, Vector2(x, 104.0))
	await wait(0.3)
	check("a door linked to a lever is shut", not lever_door.is_open)
	(node(lever) as Lever).work()
	await wait(0.2)
	check("and opens when the lever is pulled", lever_door.is_open)
	# A lock and its key.
	var lock := add("lock", "", Vector2(x + 6.0, 100.0), {"which": 1})
	var key := add("key", "", Vector2(x + 6.0, 110.0), {"which": 1, "lift": 0.2})
	var lock_door := door_for(lock, Vector2(x + 6.0, 104.0))
	await wait(0.3)
	check("a door linked to a lock is shut", not lock_door.is_open and (node(key) as DoorKey).which == DoorKey.Metal.BRONZE)
	node(key).global_position = (node(lock) as KeyLock).hole() + Vector3(0.0, 0.0, 0.4)
	(node(key) as RigidBody3D).linear_velocity = Vector3.ZERO
	var unlocked := await wait(3.0, func() -> bool: return lock_door.is_open)
	check("and opens when the key is brought", unlocked)
	# A timed plate.
	var plate := add("plate", "timed", Vector2(x + 12.0, 100.0), {"seconds": 1.0})
	var plate_door := door_for(plate, Vector2(x + 12.0, 104.0))
	await wait(0.3)
	check("a timed plate in a level is pressed only by him", node(plate) is TimedPlate and (node(plate) as Area3D).collision_mask == 2)
	him.global_position = node(plate).global_position + Vector3.UP * 0.1
	await wait(0.3)
	check("its door opens while he is on it", plate_door.is_open)
	him.global_position += Vector3(0.0, 0.0, 30.0)
	await wait(0.5)
	check("and is still open just after", plate_door.is_open)
	await wait(1.0)
	check("and shuts when its time is up", not plate_door.is_open)
	# A seal stone.
	var seal := add("plate", "seal", Vector2(x + 18.0, 100.0))
	var seal_door := door_for(seal, Vector2(x + 18.0, 104.0))
	await wait(0.3)
	him.global_position = node(seal).global_position + Vector3.UP * 0.1
	await wait(0.3)
	him.global_position += Vector3(0.0, 0.0, 30.0)
	await wait(0.3)
	check("a seal stone opens its door, and it stays open", node(seal) is SealStone and seal_door.is_open)
	# Light: the lens looks along +Z at the disc, four metres off, both lifted clear of the dunes.
	var beam := add("beam", "", Vector2(x + 24.0, 100.0), {"lift": lift_to(Vector2(x + 24.0, 100.0), 60.0), "links": [lever["id"]]})
	var disc := add("sundisc", "", Vector2(x + 24.0, 104.0), {"lift": lift_to(Vector2(x + 24.0, 104.0), 60.0)})
	var disc_door := door_for(disc, Vector2(x + 24.0, 108.0))
	await wait(0.3)
	check("with the lever pulled the light is covered", not (node(beam) as SunBeam).shining and not disc_door.is_open)
	(node(lever) as Lever).work()
	await wait(0.3)
	check("pulled back, the light is on the disc and its door opens", (node(beam) as SunBeam).shining and (node(disc) as SunDisc).on and disc_door.is_open and not lever_door.is_open)
	var mirror := add("mirror", "", Vector2(x + 24.0, 102.0), {"lift": lift_to(Vector2(x + 24.0, 102.0), 60.0), "turned": 2})
	await wait(0.3)
	check("a mirror put in the way takes the light off it", node(mirror) is Mirror and not disc_door.is_open)
	level.forget(mirror["id"])
	level.layout["items"].erase(mirror)
	await wait(0.3)
	check("and taken out again, gives it back", disc_door.is_open)
	# Water.
	var tank := add("pool", "", Vector2(x + 34.0, 100.0), {"y": 60.0})
	var sluice := add("sluice", "", Vector2(x + 38.0, 100.0), {"lift": lift_to(Vector2(x + 38.0, 100.0), 58.0), "links": [lever["id"]], "drop": 1.5, "speed": 3.0})
	await wait(0.3)
	check("a sluice finds the tank beside it", (node(sluice) as Sluice).pool == node(tank))
	(node(lever) as Lever).work()
	await wait(1.0)
	check("the lever opens it, and the water goes down", (node(tank) as Pool).surface_y() < 58.6, "%.2f" % (node(tank) as Pool).surface_y())
	# (the tank is made again, as the editor makes it when it is changed: the water is still down)
	level.make(tank)
	await wait(0.3)
	check("made again, the tank is still let down", (node(sluice) as Sluice).pool == node(tank) and (node(tank) as Pool).surface_y() < 58.6, "%.2f" % (node(tank) as Pool).surface_y())
	(node(lever) as Lever).work()
	await wait(1.0)
	check("and it comes up when the lever goes back", absf((node(tank) as Pool).surface_y() - 60.0) < 0.01)
	# An offering table, and a brazier.
	var table := add("offering", "", Vector2(x + 44.0, 100.0))
	var jar := add("prop", "jar_canopic", Vector2(x + 44.0, 110.0), {"lift": 0.3})
	var table_door := door_for(table, Vector2(x + 44.0, 104.0))
	await wait(0.3)
	check("a door linked to an offering table is shut", not table_door.is_open)
	node(jar).global_position = node(table).global_position + Vector3(0.0, 0.3, 0.9)
	(node(jar) as RigidBody3D).linear_velocity = Vector3.ZERO
	var offered := await wait(3.0, func() -> bool: return table_door.is_open)
	check("and opens when a jar is set on it", offered)
	var brazier := add("brazier", "", Vector2(x + 50.0, 100.0))
	var torch := add("torch", "", Vector2(x + 50.0, 110.0))
	var brazier_door := door_for(brazier, Vector2(x + 50.0, 104.0))
	await wait(0.3)
	check("a door linked to a cold brazier is shut", not brazier_door.is_open and not (node(brazier) as ColdBrazier).on)
	(node(torch) as RigidBody3D).freeze = true
	node(torch).global_position = node(brazier).global_position + Vector3(0.7, 0.8, 0.0)
	await wait(0.4)
	check("and opens when the brazier is lit", brazier_door.is_open and (node(brazier) as ColdBrazier).on)
	# All of it taken out and put back, as the editor does at any change.
	var ours: Array = level.layout["items"].slice(before)
	for item: Dictionary in ours:
		level.make(item)
	await wait(0.5)
	check("everything made again, and the lock and the offering table start afresh", ours.all(func(item: Dictionary) -> bool: return node(item) != null and node(item).is_inside_tree()) and (node(lock) as KeyLock).key == null and (node(table) as OfferingTable).jar == null)
	for item: Dictionary in ours:
		level.forget(item["id"])
		level.layout["items"].erase(item)
	await wait(0.5)
	check("and everything taken out again", level.layout["items"].size() == before and level._worked.all(func(entry: Array) -> bool: return is_instance_valid(entry[1])))
