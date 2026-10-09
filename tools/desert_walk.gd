extends SceneTree
## Not part of the game. Walks the Player about desert.tscn without drawing anything, to
## find out whether he can cross the dunes, swim the pool, climb the sphinx and the
## pyramids and take the ladder, and whether anything traps him. Prints what happened.
## godot --headless --path . --fixed-fps 60 --script tools/desert_walk.gd

var player: Player
var touch: TouchControls
var cam: Camera3D
var lowest := 1000.0


func _initialize() -> void:
	var scene: Node = load("res://desert.tscn").instantiate()
	root.add_child(scene)
	player = scene.get_node("Player")
	cam = scene.get_node("Camera")
	touch = scene.get_node("HUD/TouchControls")
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

	await leg("start to colonnade", Vector3(0, 0, 165), Vector3(0, 0, 73))
	await leg("up the colonnade", Vector3.INF, Vector3(0, 0, 4))
	await leg("colonnade to sphinx", Vector3.INF, Vector3(0, 0, -10))
	await leg("round the sphinx to the pyramid", Vector3.INF, Vector3(16, 0, -30))
	await leg("...", Vector3.INF, Vector3(10, 0, -68))
	await leg("camp to oasis shore", Vector3(-62, 0, 118), Vector3(40, 0, 80))
	var swam := [false]
	await leg("across the pool", Vector3.INF, Vector3(84, 0, 78), swam)
	print("  swam: %s" % swam[0])
	await leg("oasis to ruined pyramid", Vector3.INF, Vector3(100, 0, -38))
	await leg("shrine to fallen obelisk", Vector3(-112, 0, -20), Vector3(-100, 0, 56))
	await leg("fallen obelisk to camp", Vector3.INF, Vector3(-62, 0, 96))
	await leg("outpost to start", Vector3(105, 0, 143), Vector3(4, 0, 160))
	await leg("start to the far north-west", Vector3(0, 0, 165), Vector3(-150, 0, -150))
	await leg("north-west to north-east, behind the pyramid", Vector3.INF, Vector3(150, 0, -165))

	# The sphinx: onto a paw from the side, then the shoulder, then the back
	print("SPHINX")
	await climb(Vector3(6, 2.05, -22), Vector3(-1, 0, 0), "paw")
	await climb(Vector3.INF, Vector3(0, 0, -1), "shoulder")
	await climb(Vector3.INF, Vector3(0, 0, -1), "back")
	print("PYRAMID")
	await climb(Vector3(10, 4.05, -76), Vector3(0, 0, -1), "course 1")
	await climb(Vector3.INF, Vector3(0, 0, -1), "course 2")
	await climb(Vector3.INF, Vector3(0, 0, -1), "course 3")
	print("LADDER at the ruined pyramid")
	place(Vector3(113.5, 1.55, -48.55))
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
	print("LOWEST he ever was: %.2f" % lowest)
	quit()


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
