extends SceneTree
## Not part of the game. Pictures of Khepri and the sun: the beetle and its ball close to, from all round, pushing
## and sat on top; from where the game's cameras see it, with the boy beside it for size; rolling, turning at a wall
## and climbing up when it is stopped; coming through a dark room by its own light; the sunrise in the horizon, in
## the dark and by day; the horizon by itself; the court of the test yard; and that court in the yard itself. Strips are consecutive moments, left
## to right and top to bottom.
## godot --path . --fixed-fps 60 --resolution 960x960 --script tools/khepri_sheets.gd -- <outdir> [model camera roll dark sunrise akhet court yard]
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
	world.environment.background_color = Color(0.5, 0.56, 0.62) if day else Color(0.012, 0.014, 0.02)
	world.environment.ambient_light_energy = 0.7 if day else 0.04
	sun.light_energy = 1.2 if day else 0.0
	# (on the web a sun that casts shadows comes out much too bright, and the game turns it down: `TestYard.WEB_SUN`)
	if RenderingServer.get_current_rendering_method() == "gl_compatibility":
		sun.light_energy *= 0.3


func look(from: Vector3, at: Vector3, fov := 45.0) -> void:
	cam.global_position = from
	cam.look_at(at)
	cam.fov = fov


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
	return body


func put(at: Vector3, facing := 0.0) -> void:
	touch.move = Vector2.ZERO
	player.global_position = at
	player.velocity = Vector3.ZERO
	player.facing_yaw = facing


func sun_at(at: Vector3, go := false) -> Khepri:
	var khepri := Khepri.new()
	khepri.voice = false
	khepri.position = at
	stage.add_child(khepri)
	khepri.running = go
	return khepri


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
	box(Vector3(0, -1, 0), Vector3(240, 2, 240), Color(0.7, 0.62, 0.46))
	cam = Camera3D.new()
	stage.add_child(cam)
	cam.make_current()
	light(true)
	touch = TouchControls.new()
	touch.visible = false
	stage.add_child(touch)
	touch.set_process_input(false)
	player = load("res://player.tscn").instantiate()
	player.position = Vector3(80.0, 0.05, 80.0)
	player.rest_enabled = false
	stage.add_child(player)
	player.set_process_unhandled_input(false)
	for action: StringName in InputMap.get_actions():
		if not String(action).begins_with("ui_"):
			InputMap.action_erase_events(action)
	await frames(20)

	if wanted("model"):
		await model()
	if wanted("camera"):
		await from_the_camera()
	if wanted("roll"):
		await rolling()
	if wanted("dark"):
		await in_the_dark()
	if wanted("sunrise"):
		await sunrise()
	if wanted("akhet"):
		await the_akhet()
	if wanted("court"):
		await the_court()
	if wanted("yard"):
		await yard()
	quit()


## The beetle and its sun close to, from all round: pushing, and then sat on top of it.
func model() -> void:
	var at := Vector3(-60, 0, -60)
	var khepri := sun_at(at, true)
	await frames(100)
	for k in 6:
		var turn := [0.7, 2.3, 3.5, 5.2, 1.57, 3.14][k] as float
		var high := [0.45, 0.4, 0.3, 0.7, 0.12, 1.4][k] as float
		var middle := khepri.global_position + Vector3(0.0, 0.3, -0.2)
		look(middle + Vector3(sin(turn), high, cos(turn)).normalized() * 2.4, middle, 34.0)
		await frames(3)
		await snap()
	khepri.running = false
	await frames(150)
	for k in 3:
		var turn := [0.8, 2.6, 4.4][k] as float
		var middle := khepri.global_position + Vector3(0.0, 0.45, 0.0)
		look(middle + Vector3(sin(turn), 0.4, cos(turn)).normalized() * 2.4, middle, 34.0)
		await frames(25)
		await snap()
	sheet("model", 3)
	khepri.queue_free()


## From where the game sees it: the yard's camera (six metres behind him), the desert's a little higher, and the
## tomb's from the side, eleven metres off. The boy stands by it for size.
func from_the_camera() -> void:
	var at := Vector3(-40, 0, -60)
	var khepri := sun_at(at, true)
	put(at + Vector3(1.3, 0.05, 0.6), -1.2)
	await frames(110)
	var him := player.global_position + Vector3.UP * 0.85
	look(him + Vector3(0.6, 2.0, -5.6), him, 55.0)
	await frames(3)
	await snap()
	await frames(60)
	look(him + Vector3(-3.5, 2.6, 4.2), him, 55.0)
	await frames(3)
	await snap()
	await frames(50)
	look(Vector3(khepri.global_position.x + 11.0, 1.7, khepri.global_position.z + 0.5), Vector3(khepri.global_position.x, 0.85, khepri.global_position.z + 0.5), 30.0)
	await frames(3)
	await snap()
	khepri.running = false
	await frames(160)
	him = player.global_position + Vector3.UP * 0.85
	look(him + Vector3(0.6, 2.0, 5.6), (him + khepri.global_position) * 0.5, 55.0)
	await frames(3)
	await snap()
	sheet("camera", 2)
	khepri.queue_free()
	put(Vector3(80.0, 0.05, 80.0))


## Rolling: a strip of it setting off, a strip of it turning at a wall, and a strip of it stopping and climbing up.
func rolling() -> void:
	var at := Vector3(-20, 0, -60)
	box(at + Vector3(0.0, 0.6, 4.0), Vector3(5.0, 1.2, 1.0), Color(0.6, 0.54, 0.46))
	var khepri := sun_at(at)
	await frames(10)
	look(at + Vector3(-3.6, 1.5, 0.3), at + Vector3(0.0, 0.3, 0.45), 44.0)
	khepri.running = true
	for k in 8:
		await frames(15)
		await snap()
	sheet("roll_start", 4)
	await frames(60)
	look(at + Vector3(-2.6, 2.6, 0.4), at + Vector3(-0.7, 0.2, 3.0), 40.0)
	for k in 8:
		await frames(9)
		await snap()
	sheet("roll_turn", 4)
	khepri.running = false
	for k in 8:
		await frames(13)
		look(khepri.global_position + Vector3(1.2, 1.3, -2.6), khepri.global_position + Vector3(0.0, 0.45, 0.0), 40.0)
		await frames(1)
		await snap()
	sheet("roll_stop", 4)
	khepri.queue_free()


# A room: walls and a roof, dark inside. Its floor is the ground; `at` is the middle of it.
func room(at: Vector3, wide: float, long: float, tall := 3.0) -> Array[Node3D]:
	var stone := Color(0.56, 0.5, 0.42)
	var made: Array[Node3D] = []
	made.append(box(at + Vector3(0.0, tall * 0.5, -long * 0.5 - 0.25), Vector3(wide + 1.0, tall, 0.5), stone))
	made.append(box(at + Vector3(0.0, tall * 0.5, long * 0.5 + 0.25), Vector3(wide + 1.0, tall, 0.5), stone))
	made.append(box(at + Vector3(-wide * 0.5 - 0.25, tall * 0.5, 0.0), Vector3(0.5, tall, long), stone))
	made.append(box(at + Vector3(wide * 0.5 + 0.25, tall * 0.5, 0.0), Vector3(0.5, tall, long), stone))
	made.append(box(at + Vector3(0.0, tall + 0.25, 0.0), Vector3(wide + 1.0, 0.5, long + 1.0), stone.darkened(0.2)))
	return made


## A dark room, nine metres by seven, with pillars and the boy in it: the sun comes through by its own light.
func in_the_dark() -> void:
	var at := Vector3(0, 0, -60)
	var walls := room(at, 9.0, 7.0)
	# (the wall the pictures are taken through is not drawn)
	walls[1].visible = false
	for x: float in [-2.0, 2.0]:
		box(at + Vector3(x, 1.5, -2.0), Vector3(0.7, 3.0, 0.7), Color(0.6, 0.54, 0.46))
	box(at + Vector3(3.0, 0.45, 1.0), Vector3(0.9, 0.9, 0.9), Color(0.55, 0.4, 0.26))
	put(at + Vector3(1.0, 0.05, 1.6), 2.6)
	light(false)
	var khepri := Khepri.new()
	khepri.voice = false
	khepri.position = at + Vector3(-4.0, 0.0, 0.0)
	khepri.rotation.y = PI * 0.5
	stage.add_child(khepri)
	look(at + Vector3(0.0, 2.3, 7.4), at + Vector3(0.0, 0.8, -0.6), 55.0)
	await frames(20)
	await snap()
	khepri.running = true
	for k in 4:
		await frames(110)
		await snap()
	# (and close, as it passes him)
	look(khepri.global_position + Vector3(-1.6, 1.2, 2.6), khepri.global_position + Vector3(-0.3, 0.4, 0.0), 45.0)
	await frames(4)
	await snap()
	sheet("dark", 3)
	khepri.queue_free()
	for wall in walls:
		wall.queue_free()
	light(true)
	put(Vector3(80.0, 0.05, 80.0))


## The sunrise: the sun comes into the cradle, rises between the hills, and the beetle flies up onto one and opens
## its wings. In a dark room, from in front; then close; then by day.
func sunrise() -> void:
	for dark: bool in [true, false]:
		var at := Vector3(30 if dark else 60, 0, -60)
		var walls: Array[Node3D] = []
		if dark:
			walls = room(at, 9.0, 7.0)
			walls[1].visible = false
			light(false)
		var horizon := Akhet.new()
		horizon.position = at
		stage.add_child(horizon)
		var khepri := Khepri.new()
		khepri.voice = false
		khepri.position = at + Vector3(0.0, 0.0, 3.0)
		khepri.rotation.y = PI
		stage.add_child(khepri)
		look(at + Vector3(1.6, 2.2, 6.6) if dark else at + Vector3(2.4, 1.9, 4.6), at + Vector3(0.0, 0.7, 0.0), 50.0 if dark else 42.0)
		await frames(10)
		khepri.running = true
		await frames(48 + 120)
		await snap()
		for k in 7:
			await frames(50 if k == 0 else 38)
			await snap()
		sheet("sunrise_dark" if dark else "sunrise_day", 4)
		# Close, and from the other side.
		for k in 4:
			var turn := [0.5, -0.9, 2.6, 0.0][k] as float
			var high := [0.5, 0.35, 0.6, 1.6][k] as float
			var middle := at + Vector3(0.3, 0.75, 0.0)
			look(middle + Vector3(sin(turn), high, cos(turn)).normalized() * 3.4, middle, 40.0)
			await frames(20)
			await snap()
		sheet("risen_dark" if dark else "risen_day", 4)
		khepri.queue_free()
		horizon.queue_free()
		for wall in walls:
			wall.queue_free()
		light(true)
		await frames(3)


## The horizon by itself, off: from in front, from the side, from above.
func the_akhet() -> void:
	var at := Vector3(90, 0, -60)
	var horizon := Akhet.new()
	horizon.position = at
	stage.add_child(horizon)
	for k in 3:
		var from := [Vector3(0.8, 1.2, 3.6), Vector3(3.2, 1.0, 1.4), Vector3(0.0, 4.0, 0.6)][k] as Vector3
		look(at + from, at + Vector3(0.0, 0.3, 0.0), 40.0)
		await frames(4)
		await snap()
	sheet("akhet", 3)
	horizon.queue_free()


## The court in the test yard: from above; from the yard's camera at the way in; the sun going round, in the
## alcove, crossing with the blocks pushed, and risen.
func the_court() -> void:
	var at := Vector3(0, 0, 60)
	var court := KhepriCourt.new()
	court.signed = false
	court.position = at
	stage.add_child(court)
	court.khepri.voice = false
	await frames(20)
	look(at + Vector3(0.0, 17.0, -6.0), at + Vector3(0.0, 0.0, -0.6), 45.0)
	await frames(3)
	await snap()
	put(at + Vector3(2.0, 0.05, -6.6), 0.0)
	await frames(20)
	var him := player.global_position + Vector3.UP * 0.85
	look(him + Vector3(0.4, 2.4, -5.5), him + Vector3(0.0, 0.0, 2.0), 55.0)
	await frames(3)
	await snap()
	# Going round: in the alcove.
	court.lever.work()
	await frames(60 * 16)
	look(at + Vector3(0.6, 1.5, 3.4), court.khepri.global_position + Vector3.UP * 0.4, 55.0)
	await frames(3)
	await snap()
	court.reset()
	await frames(10)
	# The blocks pushed, and the sun let go: crossing, turning down, and risen.
	for i in 2:
		court.blocks[i].global_position = court.square(KhepriCourt.BLOCK_GOALS[i].x, KhepriCourt.BLOCK_GOALS[i].y) + Vector3.UP * 0.45
	put(at + Vector3(3.0, 0.05, -2.0), 0.0)
	court.lever.work()
	await frames(60 * 7)
	look(at + Vector3(2.2, 4.4, -7.4), at + Vector3(0.6, 0.3, -1.0), 55.0)
	await snap()
	await frames(60 * 4)
	await snap()
	await frames(60 * 6)
	await snap()
	sheet("court", 3)
	court.queue_free()
	put(Vector3(80.0, 0.05, 80.0))


## The station in the test yard itself, as it stands among the dunes: from above, from outside its way in, and
## with the sun let go.
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
	var court: KhepriCourt
	for child in scene.find_children("*", "", true, false):
		if child is KhepriCourt:
			court = child
	if court == null:
		print("YARD no court")
		return
	var at := court.global_position
	var boy := scene.get_node_or_null("Player") as Player
	if boy:
		boy.global_position = at + Vector3(2.0, 0.1, -7.0)
	look(at + Vector3(0.0, 24.0, -16.0), at + Vector3(0.0, 0.0, -1.0), 50.0)
	await frames(20)
	await snap()
	look(at + Vector3(4.0, 3.0, -12.5), at + Vector3(1.0, 0.6, -3.0), 55.0)
	await frames(5)
	await snap()
	court.lever.work()
	await frames(60 * 5)
	look(at + Vector3(8.5, 4.0, -8.0), at + Vector3(2.0, 0.3, -1.0), 55.0)
	await frames(3)
	await snap()
	print("YARD court at %s, the sun at %s after %d squares, ground under the court %.3f" % [at, court.khepri.global_position, court.khepri.path.size(), scene.get_node("Level").height_at(at.x, at.z)])
	sheet("yard", 3)
