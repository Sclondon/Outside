extends SceneTree
## Not part of the game. Pictures of Medjed: the figure from all round and his eyes close to (as usual, wide, shut);
## his gaze sweeping a floor with pillars on it, from where the game's camera is, by day and in the dark by a torch;
## the boy seen, warned and smitten; the boy behind a block, and ducked behind a low one; one that is unseen; one
## that follows, coming and going home; a mirror shutting his eyes; the tomb's side view; and the station in the test
## yard. Strips are consecutive moments, left to right and top to bottom.
## godot --path . --fixed-fps 60 --resolution 960x960 --script tools/medjed_sheets.gd -- <outdir> [model eyes sweep smite cover unseen follow mirror side yard ...]
## (add --rendering-method gl_compatibility to see it as the web build draws it)

const CELL := 480
var out := ""
var names: Array[String] = []
var cells: Array[Image] = []
var cam: Camera3D
var world: WorldEnvironment
var sun: DirectionalLight3D
var stage: Node3D
var touch: TouchControls
var player: Player
var built: Array[Node] = []


func _initialize() -> void:
	DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_NO_FOCUS, true)
	DisplayServer.window_set_position(Vector2i(-6000, -6000))
	var args := OS.get_cmdline_user_args()
	out = args[0]
	for i in range(1, args.size()):
		names.append(args[i])
	DirAccess.make_dir_recursive_absolute(out)
	run.call_deferred()


func wanted(name: String) -> bool:
	return names.is_empty() or names.has(name)


func snap() -> void:
	await RenderingServer.frame_post_draw
	var image := root.get_texture().get_image()
	var side: int = mini(image.get_width(), image.get_height())
	image = image.get_region(Rect2i((image.get_width() - side) / 2, (image.get_height() - side) / 2, side, side))
	image.resize(CELL, CELL, Image.INTERPOLATE_LANCZOS)
	cells.append(image)


func sheet(name: String, columns: int) -> void:
	var rows := ceili(cells.size() / float(columns))
	var page := Image.create(CELL * columns, CELL * rows, false, cells[0].get_format())
	for i in cells.size():
		page.blit_rect(cells[i], Rect2i(0, 0, CELL, CELL), Vector2i((i % columns) * CELL, (i / columns) * CELL))
	page.save_png(out.path_join(name + ".png"))
	cells.clear()
	print("SHEET ", name)


func frames(count: int) -> void:
	for i in count:
		await physics_frame
		await process_frame


func light(day: bool) -> void:
	world.environment.background_color = Color(0.5, 0.56, 0.62) if day else Color(0.015, 0.017, 0.025)
	world.environment.ambient_light_energy = 0.7 if day else 0.06
	sun.light_energy = 1.2 if day else 0.0


func look(from: Vector3, at: Vector3, fov := 45.0) -> void:
	cam.global_position = from
	cam.look_at(at)
	cam.fov = fov


## Sends him a way over the ground, whatever way the camera looks.
func steer(way: Vector3) -> void:
	var basis := cam.global_basis
	var right := Vector3(basis.x.x, 0, basis.x.z).normalized()
	var forward := Vector3(-basis.z.x, 0, -basis.z.z).normalized()
	touch.move = Vector2(way.dot(right), -way.dot(forward))


func box(at: Vector3, size: Vector3, colour: Color, solid := true) -> Node3D:
	var body: Node3D = StaticBody3D.new() if solid else Node3D.new()
	if solid:
		var shape := BoxShape3D.new()
		shape.size = size
		var collider := CollisionShape3D.new()
		collider.shape = shape
		body.add_child(collider)
	var mesh := BoxMesh.new()
	mesh.size = size
	var visual := MeshInstance3D.new()
	visual.mesh = mesh
	visual.material_override = Toon.surface(colour)
	body.add_child(visual)
	body.position = at
	stage.add_child(body)
	built.append(body)
	return body


func put(at: Vector3, facing := 0.0) -> void:
	touch.move = Vector2.ZERO
	touch.duck_held = false
	player.global_position = at
	player.velocity = Vector3.ZERO
	player.facing_yaw = facing
	if player.carried:
		player._let_go()


## A Medjed at a place, facing +Z.
func medjed_at(at: Vector3, sweep := 90.0) -> Medjed:
	var one := Medjed.new()
	one.voice = false
	one.sweep = sweep
	one.position = at
	stage.add_child(one)
	built.append(one)
	return one


func clear() -> void:
	for thing in built:
		if is_instance_valid(thing):
			thing.queue_free()
	built.clear()
	put(Vector3(60.0, 0.05, 60.0))
	await frames(3)


## A torch burning, stuck in the ground.
func torch_at(at: Vector3) -> void:
	var torch := HandTorch.new()
	torch.position = at
	torch.freeze = true
	stage.add_child(torch)
	built.append(torch)


func run() -> void:
	stage = Node3D.new()
	root.add_child(stage)
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.62, 0.66, 0.74)
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	world = WorldEnvironment.new()
	world.environment = env
	stage.add_child(world)
	sun = DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-48.0, -35.0, 0.0)
	sun.shadow_enabled = true
	stage.add_child(sun)
	var floor := box(Vector3(0, -1, 0), Vector3(160, 2, 160), Color(0.7, 0.62, 0.46))
	built.erase(floor)
	cam = Camera3D.new()
	stage.add_child(cam)
	cam.make_current()
	light(true)
	touch = TouchControls.new()
	touch.visible = false
	stage.add_child(touch)
	touch.set_process_input(false)
	player = load("res://player.tscn").instantiate()
	player.position = Vector3(60.0, 0.05, 60.0)
	player.rest_enabled = false
	stage.add_child(player)
	player.set_process_unhandled_input(false)
	for action: StringName in InputMap.get_actions():
		if not String(action).begins_with("ui_"):
			InputMap.action_erase_events(action)
	await frames(20)

	if wanted("model"):
		await model()
	if wanted("eyes"):
		await eyes()
	for day: bool in [true, false]:
		light(day)
		if wanted("sweep"):
			await sweep(day)
		if wanted("smite"):
			await smite(day)
		if wanted("cover"):
			await cover(day)
		if wanted("unseen"):
			await unseen(day)
		if wanted("follow"):
			await follow(day)
		if wanted("mirror"):
			await mirror(day)
		if wanted("side"):
			await side(day)
	light(true)
	if wanted("yard"):
		await yard()
	quit()


## The figure from all round, beside the boy for size; then by a torch in the dark.
func model() -> void:
	var one := medjed_at(Vector3.ZERO, 0.0)
	put(Vector3(1.1, 0.05, -0.2))
	await frames(30)
	for k in 6:
		var turn := [0.0, 0.7, 1.57, 2.6, 3.14, 5.3][k] as float
		look(Vector3(sin(turn) * 4.2, 1.5, cos(turn) * 4.2) + Vector3(0.4, 0.0, 0.0), Vector3(0.4, 0.72, 0.0), 30.0)
		await frames(2)
		await snap()
	light(false)
	torch_at(Vector3(-0.9, 0.0, 1.2))
	await frames(20)
	for turn: float in [0.5, -0.9, 2.4]:
		look(Vector3(sin(turn) * 4.2, 1.5, cos(turn) * 4.2), Vector3(0.0, 0.72, 0.0), 30.0)
		await frames(2)
		await snap()
	light(true)
	sheet("model", 3)
	print("MODEL %d triangles in the shroud, %d in the eyes, %d in a foot" % [one._shroud.mesh.get_faces().size() / 3, one._eyes.mesh.get_faces().size() / 3, one._feet[0].mesh.get_faces().size() / 3])
	await clear()


## His eyes close to: as usual, looking aside, wide and bright, shut; and his feet.
func eyes() -> void:
	var one := medjed_at(Vector3.ZERO, 0.0)
	await frames(30)
	look(Vector3(0.25, 1.2, 1.5), Vector3(0.0, 1.05, 0.0), 30.0)
	await snap()
	one.sweep = 80.0
	await frames(50)
	look(Vector3(0.25, 1.2, 1.5), Vector3(0.0, 1.05, 0.0), 30.0)
	await snap()
	one.sweep = 0.0
	one.reset()
	put(Vector3(0.3, 0.05, 6.0))
	one.warning = 3.0
	await frames(60)
	await snap()
	put(Vector3(60.0, 0.05, 60.0))
	one.worked = true
	await frames(40)
	await snap()
	one.worked = false
	one.sweep = 100.0
	one.turn_speed = 60.0
	one.reset()
	await frames(40)
	look(Vector3(0.9, 0.5, 1.6), Vector3(0.0, 0.2, 0.2), 30.0)
	await snap()
	await frames(9)
	await snap()
	sheet("eyes", 3)
	await clear()


## What the game's camera sees of it: the boy near the front of the picture, the gaze sweeping across pillars.
func sweep(day: bool) -> void:
	var one := medjed_at(Vector3(0.0, 0.0, -4.0))
	one.sweep = 110.0
	for at: Vector3 in [Vector3(-2.2, 0.8, 0.5), Vector3(1.6, 0.8, 1.6)]:
		box(at, Vector3(1.0, 1.6, 1.0), Color(0.55, 0.5, 0.42))
	put(Vector3(-2.2, 0.05, 1.5), PI)
	if not day:
		torch_at(Vector3(-1.5, 0.0, 2.0))
	look(Vector3(-1.0, 4.4, 8.4), Vector3(-0.4, 0.6, 0.0), 55.0)
	await frames(30)
	for k in 9:
		await frames(34)
		await snap()
	sheet("sweep_day" if day else "sweep_dark", 3)
	await clear()


## Seen: every eighth step of the game from just before he is, to after he is smitten.
func smite(day: bool) -> void:
	var one := medjed_at(Vector3(0.0, 0.0, -3.0), 0.0)
	var down := [false]
	one.caught.connect(func() -> void:
		down[0] = true
		player.ragdoll(Vector3(0.0, 9.0, 14.0)))
	if not day:
		torch_at(Vector3(1.6, 0.0, 3.4))
	put(Vector3(3.0, 0.05, 2.0), PI)
	look(Vector3(2.6, 3.4, 8.2), Vector3(0.0, 0.7, 0.0), 50.0)
	await frames(30)
	await snap()
	steer(Vector3(-1, 0, 0))
	await frames(26)
	touch.move = Vector2.ZERO
	for k in 8:
		await frames(8 if k < 6 else 16)
		await snap()
	print("SMITE ", "day" if day else "dark", ": caught ", down[0])
	sheet("smite_day" if day else "smite_dark", 3)
	player.respawn()
	await clear()


## Behind a block; ducked behind a low one; standing up behind it; pushing a block along as a shield.
func cover(day: bool) -> void:
	var one := medjed_at(Vector3(0.0, 0.0, -4.0), 50.0)
	one.warning = 1.2
	box(Vector3(-1.0, 0.8, 0.6), Vector3(1.0, 1.6, 1.0), Color(0.55, 0.5, 0.42))
	box(Vector3(1.4, 0.3, 1.2), Vector3(1.6, 0.6, 0.6), Color(0.5, 0.45, 0.4))
	if not day:
		torch_at(Vector3(0.2, 0.0, 2.6))
	look(Vector3(1.2, 3.6, 7.6), Vector3(0.2, 0.6, -0.4), 50.0)
	put(Vector3(-1.0, 0.05, 1.5), PI)
	await frames(100)
	await snap()
	await frames(60)
	await snap()
	put(Vector3(1.4, 0.05, 1.8), PI)
	touch.duck_held = true
	await frames(100)
	await snap()
	print("COVER ", "day" if day else "dark", ": ducking ", player.is_ducking, ", seen ", one.sees, ", charge ", one.charge)
	touch.duck_held = false
	var seen := false
	for i in 200:
		await frames(1)
		if one.charge > 0.5:
			seen = true
			break
	await snap()
	print("COVER standing: seen ", seen)
	one.worked = true
	# A block pushed along in front of him.
	var block: RigidBody3D = (load("res://props/block_push.tscn") as PackedScene).instantiate()
	block.position = Vector3(3.6, 0.46, 1.0)
	stage.add_child(block)
	built.append(block)
	put(Vector3(3.6, 0.05, 2.0), PI)
	await frames(20)
	one.worked = false
	one.sweep = 0.0
	one.global_position = Vector3(3.6, 0.0, -5.0)
	one._post = one.global_position
	look(Vector3(6.0, 3.0, 6.2), Vector3(3.2, 0.6, -1.0), 50.0)
	steer(Vector3(0, 0, -1))
	for k in 2:
		await frames(50)
		await snap()
	touch.move = Vector2.ZERO
	print("COVER pushing: pushing ", player.is_pushing, ", seen ", one.sees, ", charge ", one.charge, ", the block has gone ", 1.0 - block.global_position.z)
	sheet("cover_day" if day else "cover_dark", 3)
	await clear()


## One that is unseen: only eyes, feet and gaze, until he fires.
func unseen(day: bool) -> void:
	var one := medjed_at(Vector3(0.0, 0.0, -3.0), 60.0)
	one.unseen = true
	one.caught.connect(func() -> void: player.ragdoll(Vector3(0.0, 9.0, 14.0)))
	box(Vector3(-2.0, 0.8, 0.4), Vector3(1.0, 1.6, 1.0), Color(0.55, 0.5, 0.42))
	if not day:
		torch_at(Vector3(-1.2, 0.0, 2.2))
	put(Vector3(-2.0, 0.05, 1.4), PI)
	look(Vector3(0.6, 3.0, 7.4), Vector3(-0.3, 0.7, 0.0), 50.0)
	await frames(40)
	for k in 3:
		await frames(40)
		await snap()
	look(Vector3(0.9, 1.3, 1.2), Vector3(0.0, 0.75, -3.0), 40.0)
	await frames(2)
	await snap()
	look(Vector3(0.6, 3.0, 7.4), Vector3(-0.3, 0.7, 0.0), 50.0)
	one.sweep = 0.0
	one.reset()
	put(Vector3(0.0, 0.05, 1.6), PI)
	await frames(30)
	await snap()
	await frames(14)
	await snap()
	sheet("unseen_day" if day else "unseen_dark", 3)
	player.respawn()
	await clear()


## One that follows: he sees the boy, loses him behind a wall, comes to look, and goes home.
func follow(day: bool) -> void:
	var one := medjed_at(Vector3(0.0, 0.0, -4.0), 0.0)
	one.follows = true
	one.roam = 4.0
	one.warning = 1.0
	box(Vector3(2.4, 0.9, 1.0), Vector3(2.2, 1.8, 0.5), Color(0.55, 0.5, 0.42))
	if not day:
		torch_at(Vector3(1.0, 0.0, 2.8))
	put(Vector3(0.0, 0.05, 1.2), PI)
	look(Vector3(-3.6, 4.2, 7.4), Vector3(0.6, 0.5, -1.2), 55.0)
	await frames(36)
	await snap()
	put(Vector3(2.6, 0.05, 1.9), PI)
	for k in 8:
		await frames([60, 110, 110, 110, 110, 150, 200, 260][k])
		await snap()
		print("FOLLOW ", "day" if day else "dark", " ", k, ": state ", one.state, ", ", snappedf(one.global_position.distance_to(one.post()), 0.01), " m from his post")
	sheet("follow_day" if day else "follow_dark", 3)
	await clear()


## A mirror turned to face him: his eyes shut.
func mirror(day: bool) -> void:
	var one := medjed_at(Vector3(0.0, 0.0, -3.0), 0.0)
	var glass := Mirror.new()
	glass.turned = 3
	glass.position = Vector3(0.0, 0.0, 1.0)
	stage.add_child(glass)
	built.append(glass)
	if not day:
		torch_at(Vector3(1.4, 0.0, 1.8))
	put(Vector3(2.4, 0.05, 1.2), PI)
	look(Vector3(3.4, 2.6, 5.4), Vector3(0.0, 0.7, -1.0), 50.0)
	await frames(60)
	await snap()
	glass.work()
	await frames(20)
	await snap()
	await frames(30)
	await snap()
	print("MIRROR ", "day" if day else "dark", ": shut ", one.is_shut())
	sheet("mirror_day" if day else "mirror_dark", 3)
	await clear()


## As the tomb's camera sees it: from the side, eleven metres off and low.
func side(day: bool) -> void:
	var one := medjed_at(Vector3(2.9, 0.0, 0.0), 0.0)
	one.rotation.y = -PI * 0.5
	one.reset()
	one.sweep = 50.0
	one.warning = 1.5
	box(Vector3(0.0, 1.5, -1.6), Vector3(16.0, 3.0, 0.4), Color(0.42, 0.38, 0.33))
	box(Vector3(-1.2, 0.8, 0.0), Vector3(1.0, 1.6, 1.0), Color(0.55, 0.5, 0.42))
	if not day:
		torch_at(Vector3(-3.0, 0.0, 0.9))
	put(Vector3(-2.1, 0.05, 0.0), PI * 0.5)
	look(Vector3(0.0, 1.7, 11.0), Vector3(0.0, 0.85, 0.0), 35.0)
	await frames(60)
	await snap()
	await frames(50)
	await snap()
	one.sweep = 0.0
	put(Vector3(0.6, 0.05, 0.4), PI * 0.5)
	await frames(50)
	await snap()
	sheet("side_day" if day else "side_dark", 3)
	await clear()


## The station in the test yard.
func yard() -> void:
	stage.queue_free()
	await frames(2)
	var scene: Node = load("res://test_yard.tscn").instantiate()
	root.add_child(scene)
	await frames(30)
	var view := Camera3D.new()
	root.add_child(view)
	view.make_current()
	cam = view
	var at := Vector3(76.0, 0.0, 12.0)
	var boy := scene.get_node_or_null("Player") as Player
	if boy:
		boy.global_position = at + Vector3(-6.5, 0.1, -3.0)
	for shot: Array in [[Vector3(-13.0, 9.0, 6.0), Vector3(1.0, 0.0, 0.0)], [Vector3(-9.5, 4.0, -3.4), Vector3(4.0, 0.6, -3.6)], [Vector3(-8.0, 4.0, 4.4), Vector3(4.0, 0.6, 4.2)],
			[Vector3(0.0, 17.0, 0.6), Vector3(0.0, 0.0, 0.0)], [Vector3(3.5, 1.6, -2.4), Vector3(7.5, 0.8, -3.5)], [Vector3(3.5, 1.6, 5.4), Vector3(7.5, 0.8, 4.2)]]:
		look(at + shot[0], at + shot[1], 55.0)
		await frames(50)
		await snap()
	sheet("yard", 3)
