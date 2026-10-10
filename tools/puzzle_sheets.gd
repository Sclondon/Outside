extends SceneTree
## Not part of the game. Pictures of the puzzle parts: each by itself in its states (`parts`), light and mirrors by
## day and in the dark with things stood in the beam (`light`), a tank being let down by its sluice (`water`), and the
## two stations in the test yard (`yard`).
## godot --path . --fixed-fps 60 --resolution 960x960 --script tools/puzzle_sheets.gd -- <outdir> [parts light water yard]

const CELL := 480
var out := ""
var want: Array[String] = []
var cells: Array[Image] = []
var cam: Camera3D
var world: WorldEnvironment
var sun: DirectionalLight3D
var stage: Node3D
var boy: Player


func _initialize() -> void:
	DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_NO_FOCUS, true)
	DisplayServer.window_set_position(Vector2i(-6000, -6000))
	var args := OS.get_cmdline_user_args()
	out = args[0]
	for i in range(1, args.size()):
		want.append(args[i])
	run.call_deferred()


func wants(name: String) -> bool:
	return want.is_empty() or want.has(name)


func snap() -> void:
	cam.make_current()
	await process_frame
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
	world.environment.background_color = Color(0.5, 0.56, 0.62) if day else Color(0.03, 0.035, 0.05)
	world.environment.ambient_light_energy = 0.7 if day else 0.12
	sun.light_energy = 1.2 if day else 0.0


## Looks at a place from a way off: `from` is where the camera is, from the place.
func look(at: Vector3, from: Vector3, fov := 40.0) -> void:
	cam.global_position = at + from
	cam.look_at(at)
	cam.fov = fov


func place(node: Node3D, at: Vector3, yaw := 0.0) -> Node3D:
	node.position = at
	node.rotation.y = yaw
	stage.add_child(node)
	return node


func box(at: Vector3, size: Vector3, colour := Color(0.58, 0.52, 0.44)) -> StaticBody3D:
	var body := StaticBody3D.new()
	PuzzleKit.shape(body, Vector3.ZERO, size)
	PuzzleKit.box(body, Vector3.ZERO, size, Toon.surface(colour))
	body.position = at
	stage.add_child(body)
	return body


func run() -> void:
	DirAccess.make_dir_recursive_absolute(out)
	for action: StringName in InputMap.get_actions():
		if not String(action).begins_with("ui_"):
			InputMap.action_erase_events(action)
	if wants("parts") or wants("light") or wants("water"):
		build_stage()
		await frames(20)
	if wants("parts"):
		await parts()
	if wants("light"):
		await beams()
	if wants("water"):
		await water()
	if stage:
		stage.queue_free()
		stage = null
		await frames(5)
	if wants("yard"):
		await yard()
	quit()


func build_stage() -> void:
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
	light(true)
	box(Vector3(60, -1, 0), Vector3(200, 2, 80), Color(0.66, 0.58, 0.44))
	cam = Camera3D.new()
	stage.add_child(cam)
	var touch := TouchControls.new()
	touch.visible = false
	stage.add_child(touch)
	touch.set_process_input(false)
	boy = load("res://player.tscn").instantiate()
	boy.position = Vector3(-20, 0.05, 20)
	boy.rest_enabled = false
	stage.add_child(boy)
	boy.set_process_unhandled_input(false)


func put(at: Vector3, facing := 0.0) -> void:
	boy.global_position = at
	boy.velocity = Vector3.ZERO
	boy.facing_yaw = facing


func parts() -> void:
	# A lever: off, on, one that springs back part of the way, and the boy pulling one.
	var lever := place(Lever.new(), Vector3(0, 0, 0)) as Lever
	await frames(10)
	look(Vector3(0, 0.5, 0), Vector3(1.5, 0.8, 1.6))
	await snap()
	lever.work()
	await frames(30)
	await snap()
	var sprung := Lever.new()
	sprung.returns = 3.0
	place(sprung, Vector3(4, 0, 0))
	await frames(5)
	sprung.work()
	await frames(100)
	look(Vector3(4, 0.5, 0), Vector3(1.5, 0.8, 1.6))
	await snap()
	lever.work()
	put(Vector3(0.75, 0.05, 0.1), -PI * 0.5)
	await frames(40)
	boy._act()
	await frames(16)
	look(Vector3(0.3, 0.6, 0), Vector3(0.8, 0.9, 2.6))
	await snap()
	await frames(50)
	put(Vector3(-20, 0.05, 20))

	# Keys of the three metals; a lock shut; one with its key in it; and the gold one.
	for i in 3:
		var key := DoorKey.new()
		key.which = i as DoorKey.Metal
		key.freeze = true
		place(key, Vector3(8.0 + i * 0.3, 0.03, 0.0), 0.5 + i * 0.3)
	look(Vector3(8.3, 0.0, 0.0), Vector3(0.3, 0.9, 0.8))
	await snap()
	for i in 3:
		var lock := KeyLock.new()
		lock.which = i as DoorKey.Metal
		place(lock, Vector3(12.0 + i * 4.0, 0, 0))
		if i == 1:
			var key := DoorKey.new()
			key.which = DoorKey.Metal.BRONZE
			place(key, Vector3(16.0, 0.9, 0.5))
			await frames(70)
		await frames(5)
		look(Vector3(12.0 + i * 4.0, 0.75, 0), Vector3(0.9 if i != 1 else 1.2, 0.5, 1.8), 36.0)
		await snap()

	# A timed plate: up, just pressed, half run, and a seal stone.
	var timed := TimedPlate.new()
	timed.seconds = 6.0
	place(timed, Vector3(24, 0, 0))
	await frames(10)
	look(Vector3(24.3, 0.4, 0), Vector3(1.4, 1.3, 2.2))
	await snap()
	put(Vector3(24, 0.05, 0), 0.6)
	await frames(40)
	await snap()
	put(Vector3(-20, 0.05, 20))
	await frames(180)
	look(Vector3(24.88, 0.8, 0), Vector3(0.3, 0.25, 0.9))
	await snap()
	place(SealStone.new(), Vector3(30, 0, 0))
	await frames(5)
	look(Vector3(30, 0.0, 0), Vector3(1.0, 1.4, 1.8))
	await snap()

	# An offering table: bare, and with a jar on it. A brazier: cold, and lit.
	var table := place(OfferingTable.new(), Vector3(36, 0, 0)) as OfferingTable
	await frames(5)
	look(Vector3(36, 0.5, 0), Vector3(1.4, 1.2, 2.2))
	await snap()
	var jar := (load("res://props/jar_canopic.tscn") as PackedScene).instantiate() as RigidBody3D
	place(jar, Vector3(36, 0.3, 0.9))
	await frames(40)
	await snap()
	print("OFFERED ", table.on)
	var brazier := place(ColdBrazier.new(), Vector3(42, 0, 0)) as ColdBrazier
	await frames(5)
	look(Vector3(42, 0.8, 0), Vector3(1.2, 0.8, 2.6))
	await snap()
	var torch := HandTorch.new()
	torch.freeze = true
	place(torch, Vector3(42.7, 0.5, 0.3))
	await frames(60)
	await snap()
	print("LIT ", brazier.on)
	sheet("parts", 4)


func beams() -> void:
	# The light goes out along +X, is sent along +Z by one mirror and back along -X by the next, to the disc.
	var at := Vector3(60, 0, 0)
	var beam := place(SunBeam.new(), at, PI * 0.5) as SunBeam
	var first := Mirror.new()
	first.turned = 3
	place(first, at + Vector3(5, 0, 0))
	var second := Mirror.new()
	second.turned = 1
	place(second, at + Vector3(5, 0, 4))
	var disc := place(SunDisc.new(), at + Vector3(0, 0, 4)) as SunDisc
	box(at + Vector3(2.5, 1.0, -2.5), Vector3(9, 2, 0.5))
	for day: bool in [true, false]:
		light(day)
		await frames(20)
		look(at + Vector3(2.5, 0.5, 2), Vector3(1.0, 5.0, 7.5))
		await snap()
		look(at + Vector3(0, 0.6, 0), Vector3(1.6, 0.6, 1.8))
		await snap()
		look(at + Vector3(5, 0.6, 0), Vector3(-1.8, 0.7, 2.0))
		await snap()
		look(at + Vector3(0, 0.7, 4), Vector3(1.4, 0.5, 2.0))
		await snap()
		print("BEAM ", "day" if day else "dark", " mirrors ", beam.bounces, " disc ", disc.on)
	# Things in the light: a block, and the boy. And a mirror turned away, with the disc out.
	light(true)
	var block := box(at + Vector3(5, 0.45, 2), Vector3(0.9, 0.9, 0.9), Color(0.55, 0.4, 0.26))
	await frames(10)
	look(at + Vector3(2.5, 0.5, 2), Vector3(1.0, 5.0, 7.5))
	await snap()
	block.queue_free()
	put(at + Vector3(2.5, 0.05, 4), 0.0)
	await frames(30)
	look(at + Vector3(2.5, 0.6, 4), Vector3(0.5, 1.2, 4.5))
	await snap()
	put(Vector3(-20, 0.05, 20))
	second.work()
	await frames(12)
	look(at + Vector3(2.5, 0.5, 2), Vector3(1.0, 5.0, 7.5))
	await snap()
	await frames(60)
	await snap()
	sheet("light", 4)


func water() -> void:
	# A tank four metres square, open at the front to see into, with a sluice in its side wall.
	var at := Vector3(90, 0, 0)
	for wall: Array in [[Vector3(-2.25, 1.0, 0), Vector3(0.5, 2.0, 4.0)], [Vector3(2.25, 1.0, 0), Vector3(0.5, 2.0, 4.0)], [Vector3(0, 1.0, -2.25), Vector3(5.0, 2.0, 0.5)]]:
		box(at + wall[0], wall[1])
	var pool := Pool.new()
	pool.size = Vector3(4, 1.8, 4)
	place(pool, at + Vector3(0, 1.8, 0))
	var sluice := Sluice.new()
	sluice.drop = 1.5
	place(sluice, at + Vector3(2.7, 0, 1.0), PI * 0.5)
	put(at + Vector3(-0.5, 1.0, 0.3), 0.6)
	await frames(90)
	for moment in 4:
		look(at + Vector3(0.6, 0.9, 0.5), Vector3(3.2, 2.6, 7.0))
		await snap()
		if moment == 0:
			look(at + Vector3(2.7, 0.9, 1.0), Vector3(2.4, 0.9, 1.6))
			await snap()
		sluice.open = true
		await frames(50)
	look(at + Vector3(2.7, 0.9, 1.0), Vector3(2.4, 0.9, 1.6))
	await snap()
	print("WATER lowered ", sluice.lowered, " he is at ", boy.global_position.y, " state ", boy.state)
	sluice.open = false
	await frames(200)
	look(at + Vector3(0.6, 0.9, 0.5), Vector3(3.2, 2.6, 7.0))
	await snap()
	sheet("water", 4)


func yard() -> void:
	var scene: Node = load("res://test_yard.tscn").instantiate()
	root.add_child(scene)
	await frames(60)
	cam = Camera3D.new()
	scene.add_child(cam)
	var west := Vector3(-50, 0, -12)
	var east := Vector3(54, 0, 12)
	look(west + Vector3(0, 1.0, 0), Vector3(16.0, 13.0, 6.0), 50.0)
	await snap()
	look(west + Vector3(3.5, 1.0, -3.5), Vector3(6.5, 2.2, 0.5), 50.0)
	await snap()
	look(west + Vector3(3.5, 1.0, 3.5), Vector3(6.5, 2.2, 0.5), 50.0)
	await snap()
	look(west + Vector3(-5.0, 1.0, -1.8), Vector3(6.5, 2.6, 1.0), 50.0)
	await snap()
	look(east + Vector3(0, 0.5, -4), Vector3(-2.0, 9.0, -10.0), 50.0)
	await snap()
	# The mirrors turned as they should be: the light comes to the disc, and its gate goes up.
	var mirrors := get_nodes_in_group(&"mirrors")
	for mirror: Mirror in mirrors:
		for i in 2 if mirror.steps == 1 else 1:
			mirror.work()
	await frames(150)
	await snap()
	look(east + Vector3(0, 0.6, -4), Vector3(-7.5, 2.0, 5.5), 50.0)
	await snap()
	look(east + Vector3(1.5, 0.8, 4.6), Vector3(7.0, 6.5, 7.5), 50.0)
	await snap()
	for lever: Lever in get_nodes_in_group(&"workable").filter(func(node: Node) -> bool: return node is Lever and node.global_position.x > 40.0):
		lever.work()
	await frames(200)
	await snap()
	look(east + Vector3(0.0, 0.5, 4.6), Vector3(-1.0, 7.5, -4.5), 50.0)
	await snap()
	sheet("yard", 5)
