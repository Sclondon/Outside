extends SceneTree
## Not part of the game. Puts pyramids made by scripts/pyramid.gd into the desert, on
## level ground of their own, and sends the Player at them without drawing anything:
## up the courses of a stepped one, at the smooth face of a finished one (which he
## should not get up), in at a doorway, and up the rubble of a fallen corner. Prints
## what happened. Nothing is saved.
## godot --headless --path . --fixed-fps 60 --script tools/pyramid_walk.gd

const AT := Vector2(150.0, 40.0)

var level: Desert
var player: Player
var touch: TouchControls
var cam: Camera3D
var floor_y := 0.0


func _initialize() -> void:
	var scene: Node = load("res://desert.tscn").instantiate()
	root.add_child(scene)
	level = scene.get_node("Level")
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
	await frames(30)
	# Level ground to stand them on.
	floor_y = level.height_at(AT.x, AT.y)
	var pad := LevelLayout.new_item(level.layout, "pad", "", AT)
	pad.merge({"y": floor_y, "half_x": 45.0, "half_z": 45.0, "round": false}, true)
	level.layout["items"].append(pad)
	level.reshape()
	await frames(30)

	print("STEPPED, 40 m")
	var stepped := await stand({"base": 40.0})
	var edge := 20.0 - stepped._tread
	await climb(Vector3(AT.x + 3.0, floor_y + 0.05, AT.y + edge + 1.2), Vector3(0, 0, -1), "course 1")
	await climb(Vector3.INF, Vector3(0, 0, -1), "course 2")
	await climb(Vector3.INF, Vector3(0, 0, -1), "course 3")
	await up("to the top by the courses", Vector3(AT.x + 3.0, floor_y + 0.05, AT.y + edge + 1.2), Vector3(AT.x, 0, AT.y), 60.0, stepped.height)

	print("FINISHED (smooth casing, gold cap, a doorway), 40 m")
	var finished := await stand({"base": 40.0, "casing": 1.0, "cap": true, "door": true})
	await up("at the smooth face", Vector3(AT.x + 10.0, floor_y + 0.05, AT.y + 24.0), Vector3(AT.x + 10.0, 0, AT.y), 8.0, 0.0)
	place(Vector3(AT.x, floor_y + 0.05, AT.y + 24.0))
	await frames(240, Vector3(0, 0, -1))
	print("  in at the doorway: he is %.1f m inside the foot of the face (at %s)" % [AT.y + 20.0 - player.global_position.z, player.global_position])

	for ruin: float in [0.3, 0.6, 1.0]:
		print("FALLEN, ruin %.1f, 40 m" % ruin)
		var fallen := await stand({"base": 40.0, "ruin": ruin, "seed": 3})
		var corner := fallen.fallen_corners[0]
		var from := Vector3(AT.x + corner.x * 34.0, floor_y + 0.05, AT.y + corner.y * 34.0)
		await up("up the fallen corner", from, Vector3(AT.x, 0, AT.y), 40.0, fallen.height)
	quit()


## Stands a pyramid on the level ground in place of the last one.
func stand(numbers: Dictionary) -> Pyramid:
	for item: Dictionary in level.layout["items"].duplicate():
		if item["kind"] == "pyramid":
			level.forget(item["id"])
			level.layout["items"].erase(item)
	var item := LevelLayout.new_item(level.layout, "pyramid", "", AT)
	item.merge(numbers, true)
	level.layout["items"].append(item)
	var made := level.make(item) as Pyramid
	await frames(10)
	print("  %d triangles, %d shapes, %.1f m high" % [made.triangles, made.shapes, made.height])
	return made


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


## Makes for a place for so many seconds, jumping at whatever stops him and
## climbing whatever he catches, and says how high he got.
func up(name: String, from: Vector3, to: Vector3, seconds: float, top: float) -> void:
	place(from)
	await frames(20)
	var highest := player.global_position.y
	var checked := player.global_position
	var hangs := 0
	var walked := 0.0
	var last := player.global_position
	for count in int(seconds * 60.0):
		var toward := Vector3(to.x - player.global_position.x, 0, to.z - player.global_position.z)
		if toward.length() < 1.0:
			break
		await frames(1, toward.normalized())
		if player.state == Player.State.HANG:
			hangs += 1
			touch.jump_held = false
			await frames(12)
			player._queue_jump()
			await frames(70)
		if player.is_on_floor():
			walked += Vector2(player.global_position.x - last.x, player.global_position.z - last.z).length()
		last = player.global_position
		if count % 45 == 44:
			if player.global_position.distance_to(checked) < 0.5:
				touch.jump_held = true
				player._queue_jump()
			else:
				touch.jump_held = false
			checked = player.global_position
		highest = maxf(highest, player.global_position.y)
	touch.move = Vector2.ZERO
	touch.jump_held = false
	print("  %-26s got %.1f m up (it is %.1f m high), walking %.0f m and catching %d ledges; ends at %s" % [name, highest - floor_y, top, walked, hangs, player.global_position])
