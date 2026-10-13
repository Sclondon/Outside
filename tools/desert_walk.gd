extends SceneTree
## Not part of the game. Walks the Player about desert.tscn without drawing anything, to
## find out whether he can cross the dunes, swim the pool, climb the sphinx and the
## pyramids and take the ladder, whether he can get from where he starts to the gate of
## each temple by the river, in to its sanctuary and out again, and whether anything
## traps him. Prints what happened, and how many legs he did not finish.
## godot --headless --path . --fixed-fps 60 --script tools/desert_walk.gd
## The desert is the one the game came with, not the one kept on this device.

var player: Player
var touch: TouchControls
var cam: Camera3D
var lowest := 1000.0
var level: Desert
var legs := 0
var short := 0
## Where the old places are now: they were all moved together when the desert was made bigger for the temples.
var moved := Vector3.ZERO


func _initialize() -> void:
	LevelLayout.saved_at = "user://desert_walk_none.json"
	var scene: Node = load("res://desert.tscn").instantiate()
	root.add_child(scene)
	player = scene.get_node("Player")
	cam = scene.get_node("Camera")
	touch = scene.get_node("HUD/TouchControls")
	level = scene.get_node("Level")
	run.call_deferred()


func run() -> void:
	touch.set_process_input(false)
	player.set_process_unhandled_input(false)
	for action: StringName in InputMap.get_actions():
		if not String(action).begins_with("ui_"):
			InputMap.action_erase_events(action)
			Input.action_release(action)
	await frames(60)
	print("START state=%d limp=%s floor=%s at %s" % [player.state, player.is_limp, player.is_on_floor(), player.global_position])

	# (the old places are given as they were when he started at 0, 165: `o` says where each is now)
	for item: Dictionary in level.layout["items"]:
		if item["kind"] == "start":
			moved = Vector3(float(item["at"][0]), 0.0, float(item["at"][1]) - 165.0)
	await leg("start to colonnade", o(0, 0, 165), o(0, 0, 73))
	await leg("up the colonnade", Vector3.INF, o(0, 0, 4))
	await leg("colonnade to sphinx", Vector3.INF, o(0, 0, -10))
	await leg("round the sphinx to the pyramid", Vector3.INF, o(16, 0, -30))
	await leg("...", Vector3.INF, o(10, 0, -68))
	await leg("camp to oasis shore", o(-62, 0, 118), o(40, 0, 80))
	var swam := [false]
	await leg("across the pool", Vector3.INF, o(84, 0, 78), swam)
	print("  swam: %s" % swam[0])
	await leg("oasis to ruined pyramid", Vector3.INF, o(100, 0, -38))
	await leg("shrine to fallen obelisk", o(-112, 0, -20), o(-100, 0, 56))
	await leg("fallen obelisk to camp", Vector3.INF, o(-62, 0, 96))
	await leg("outpost to start", o(105, 0, 143), o(4, 0, 160))
	# (the far north-west is the Valley of the Kings now, and a cliff stands along the north edge)
	await leg("start to the mouth of the valley", o(0, 0, 165), o(-126, 0, -62))
	await leg("up the valley to its head", Vector3.INF, o(-130, 0, -138))
	await leg("the valley to the north-east, before the cliff", o(-126, 0, -62), o(120, 0, -148))
	await leg("start to the chalk rocks", o(0, 0, 165), o(-150, 0, 100))

	# The sphinx: onto a paw from the side, then the shoulder, then the back
	print("SPHINX")
	await climb(o(6, 2.05, -22), Vector3(-1, 0, 0), "paw")
	await climb(Vector3.INF, Vector3(0, 0, -1), "shoulder")
	await climb(Vector3.INF, Vector3(0, 0, -1), "back")
	print("PYRAMID")
	await climb(o(10, 4.05, -76), Vector3(0, 0, -1), "course 1")
	await climb(Vector3.INF, Vector3(0, 0, -1), "course 2")
	await climb(Vector3.INF, Vector3(0, 0, -1), "course 3")
	print("LADDER at the ruined pyramid")
	place(o(113.5, 1.55, -48.55))
	await frames(10)
	for i in 120:
		await frames(1, Vector3(1, 0, 0))
		if player.state == Player.State.LADDER:
			break
	print("  state=%d (5 is LADDER) at %s" % [player.state, player.global_position])
	for i in 400:
		steer(Vector3.ZERO)
		touch.move = Vector2(0, -1)
		await physics_frame
		if player.state != Player.State.LADDER:
			break
	touch.move = Vector2.ZERO
	await frames(30)
	print("  off the ladder: state=%d at %s (the deck is at 5.0)" % [player.state, player.global_position])
	await frames(120, Vector3(0, 0, 1))
	print("  walked on towards the pyramid: at %s" % player.global_position)
	await temples()
	print("LOWEST he ever was: %.2f" % lowest)
	print("WALKED %d legs, %d of them not to the end" % [legs, short])
	quit(1 if short > 0 else 0)


## Where an old place is now.
func o(x: float, y: float, z: float) -> Vector3:
	return Vector3(x, y, z) + moved


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
		lowest = minf(lowest, player.global_position.y)


func ground_at(x: float, z: float) -> float:
	var query := PhysicsRayQueryParameters3D.create(Vector3(x, 80, z), Vector3(x, -40, z), 1)
	var hit := player.get_world_3d().direct_space_state.intersect_ray(query)
	return hit.position.y if not hit.is_empty() else 0.0


## Walks from one place to another, jumping and stepping aside when he stops.
func leg(name: String, from: Vector3, to: Vector3, swam: Array = []) -> void:
	if from != Vector3.INF:
		place(Vector3(from.x, ground_at(from.x, from.z) + 0.1, from.z))
		await frames(20)
	var start := player.global_position
	var count := 0
	var checked := player.global_position
	var stuck := 0
	var side := 1.0
	var limit := int(Vector2(to.x - start.x, to.z - start.z).length() / 4.4 * 60.0 * 2.5) + 600
	while count < limit:
		var at := player.global_position
		var toward := Vector3(to.x - at.x, 0, to.z - at.z)
		if toward.length() < 1.5:
			break
		var heading := toward.normalized()
		if stuck > 0:
			# Aside for a while, then on
			heading = (heading * 0.3 + Vector3(heading.z, 0, -heading.x) * side).normalized()
			stuck -= 1
		await frames(1, heading)
		count += 1
		if not swam.is_empty() and player.state == Player.State.SWIM:
			swam[0] = true
		if player.state == Player.State.HANG:
			player._queue_jump()
		if count % 60 == 0:
			if player.global_position.distance_to(checked) < 0.6:
				stuck = 110
				side = -side if count % 240 == 0 else side
				touch.jump_held = true
				player._queue_jump()
			else:
				touch.jump_held = false
			checked = player.global_position
	touch.move = Vector2.ZERO
	touch.jump_held = false
	var left := Vector2(to.x - player.global_position.x, to.z - player.global_position.z).length()
	legs += 1
	short += 0 if left < 1.6 else 1
	print("LEG %-44s %s in %5.1f s (%.0f m as the crow flies), ends at %s" % [name, "ARRIVED" if left < 1.6 else "FAILED, %.1f m short" % left,
		count / 60.0, Vector2(to.x - start.x, to.z - start.z).length(), player.global_position])


## Runs at a wall, catches its top and climbs up.
func climb(from: Vector3, heading: Vector3, name: String) -> void:
	if from != Vector3.INF:
		place(from)
	await frames(15)
	var before := player.global_position.y
	for i in 50:
		await frames(1, heading)
	touch.jump_held = true
	player._queue_jump()
	var hung := false
	for i in 90:
		await frames(1, heading)
		if player.state == Player.State.HANG:
			hung = true
			break
	touch.jump_held = false
	touch.move = Vector2.ZERO
	await frames(20)
	if hung:
		player._queue_jump()
	await frames(110)
	print("  %-10s hung=%s  rose %.2f m, now at %s state=%d" % [name, hung, player.global_position.y - before, player.global_position, player.state])


# --- The temples by the river ---

## The node of the item with a name.
func named(called: String) -> Node3D:
	for item: Dictionary in level.layout["items"]:
		if item.get("name", "") == called:
			return level.nodes.get(item["id"])
	return null


## Walks a line of places, one leg each. The first is where he is put (or `Vector3.INF`: he goes on from where he is).
func way(name: String, points: Array) -> void:
	for i in range(1, points.size()):
		await leg("%s%s" % [name, "" if points.size() == 2 else " (%d of %d)" % [i, points.size() - 1]], points[0] if i == 1 else Vector3.INF, points[i])


## From where he starts to the gate of each temple, in to its sanctuary and out; from one temple to the next
## along the river; and back to the start. A keeper that bars a sanctuary is told its name first (the leaf and
## the names are tried in `tools/desert_temples_test.gd`), and the lever at Abu Simbel is pulled.
func temples() -> void:
	var edfu := named("Edfu") as Temple
	var kom := named("KomOmbo") as Temple
	var abu := named("AbuSimbel") as AbuSimbel
	if edfu == null or kom == null or abu == null:
		print("TEMPLES: there are none in this level")
		return
	print("TEMPLES")
	var start := o(0, 0, 165)
	# Edfu: round the corner of its wall to the gate, in along its axis, and out.
	var gate := edfu.global_transform * edfu.ways[0][0]
	var corner := edfu.global_transform * Vector3(-edfu.breadth * 0.5 - 14.0, 0.0, edfu.length * 0.5 + 16.0)
	await way("start to Edfu's gate", [start, edfu.global_transform * Vector3(-edfu.breadth * 0.5 - 14.0, 0.0, -edfu.length * 0.5), corner, gate])
	(named("EdfuKeeper") as GateGuardian).answer((named("EdfuKeeper") as GateGuardian).who)
	await frames(90)
	var inward: Array = [Vector3.INF]
	for point: Vector3 in edfu.ways[0]:
		inward.append(edfu.global_transform * point)
	await way("Edfu's gate to its sanctuary", inward)
	print("  at the sanctuary of Edfu: %s (its mark is at %s)" % [player.global_position, get_nodes_in_group(&"temple_sanctuary").filter(func(mark: Node) -> bool: return edfu.is_ancestor_of(mark))[0].global_position])
	inward.reverse()
	inward.pop_back()
	await way("and out again", [Vector3.INF] + inward)
	# Kom Ombo, along the river: up its steps, in by the left-hand door to the sanctuary of Sobek, and out.
	var steps := kom.global_transform * kom.ways[0][0]
	await way("Edfu to Kom Ombo", [Vector3.INF, steps + Vector3(40.0, 0.0, 30.0), steps])
	(named("KomOmboKeeper") as GateGuardian).answer((named("KomOmboKeeper") as GateGuardian).who)
	await frames(90)
	inward = [Vector3.INF]
	for point: Vector3 in kom.ways[0]:
		inward.append(kom.global_transform * point)
	await way("Kom Ombo's steps to the sanctuary of Sobek", inward)
	inward.reverse()
	inward.pop_back()
	await way("and out again", [Vector3.INF] + inward)
	# Abu Simbel, along the bank: up the terrace, in at the door, the lever, and on to the gods.
	var terrace := abu.global_transform * Vector3(0.0, 0.0, 27.0)
	var bank := kom.global_transform * Vector3(kom.breadth * 0.5 + 26.0, 0.0, 0.0)
	await way("Kom Ombo to Abu Simbel", [Vector3.INF, Vector3(bank.x, 0.0, steps.z), Vector3(bank.x, 0.0, kom.global_position.z - kom.length * 0.5 - 12.0), terrace])
	var marks := {}
	for group: StringName in [&"abu_simbel_door", &"abu_simbel_hall", &"abu_simbel_sanctuary"]:
		for mark in get_nodes_in_group(group):
			marks[String(mark.name)] = (mark as Node3D).global_position
	await way("the terrace to the great hall", [Vector3.INF, marks["GreatDoor"], marks["GreatHall"]])
	var lever := named("AbuLever") as Lever
	var mouth := abu.global_transform * Vector3(-7.4, 1.2, -8.7)
	await way("to the lever in the store-room", [Vector3.INF, mouth, lever.global_position + (mouth - lever.global_position).normalized() * 1.2])
	lever.work(player)
	await frames(240)
	await way("and on to the gods", [Vector3.INF, mouth, marks["GreatHall"], marks["GreatSanctuary"]])
	print("  before the gods: %s; the sun reaches them: %s" % [player.global_position, abu.on])
	await way("out to the terrace", [Vector3.INF, marks["GreatHall"], marks["GreatDoor"], terrace])
	var north := abu.global_transform * Vector3(99.0, 0.0, 30.0)
	await way("to the small temple and in", [Vector3.INF, north, marks["SmallDoor"], marks["SmallHall"], marks["SmallSanctuary"]])
	await way("and out", [Vector3.INF, marks["SmallHall"], marks["SmallDoor"], north])
	await way("Abu Simbel back to the start", [Vector3.INF, terrace + Vector3(4.0, 0.0, 0.0), Vector3(bank.x, 0.0, kom.global_position.z - kom.length * 0.5 - 12.0),
			Vector3(kom.global_position.x - kom.breadth * 0.5 - 24.0, 0.0, kom.global_position.z - kom.length * 0.5 - 12.0), start])
