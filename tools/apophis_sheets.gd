extends SceneTree
## Not part of the game. Pictures of Apophis: coiled, from all round, and his head close to; waking;
## coming up out of his hole; in full chase behind the running boy, seen from the game's own orbit
## camera turned to look back, and from behind as it sits when it is left alone; going over a kerb;
## under a ledge and up it; rearing at the edge of torchlight in the dark; the strike; battering at a
## door; going home. Strips are moments in order, left to right and top to bottom. It prints what a
## frame of him costs (`COST`).
## godot --path . --fixed-fps 60 --resolution 960x960 --script tools/apophis_sheets.gd -- <outdir> [model head wake hole chase behind kerb ledge torch strike door home daylight yard cost ...]
## (add `--rendering-method gl_compatibility` to see him as the web build draws him)

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


## One picture, whole, at the size of the window: what the player would see.
func whole(name: String) -> void:
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(out.path_join(name + ".png"))
	print("SHEET ", name)


func frames(count: int) -> void:
	for i in count:
		await physics_frame
		await process_frame


func light(day: bool) -> void:
	world.environment.background_color = Color(0.5, 0.56, 0.62) if day else Color(0.015, 0.017, 0.025)
	world.environment.ambient_light_energy = 0.7 if day else 0.05
	sun.light_energy = 1.25 if day else 0.0
	# (the renderer the web has draws a sun that casts shadows much too bright: the game turns it down there, and so does this)
	if RenderingServer.get_current_rendering_method() == "gl_compatibility":
		sun.light_energy *= 0.3


func look(from: Vector3, at: Vector3, fov := 45.0) -> void:
	cam.make_current()
	cam.global_position = from
	cam.look_at(at)
	cam.fov = fov


func steer(way: Vector3) -> void:
	var basis := root.get_camera_3d().global_basis
	var right := Vector3(basis.x.x, 0, basis.x.z).normalized()
	var forward := Vector3(-basis.z.x, 0, -basis.z.z).normalized()
	touch.move = Vector2(way.dot(right), -way.dot(forward))


func box(at: Vector3, size: Vector3, colour: Color) -> StaticBody3D:
	var body := StaticBody3D.new()
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


func put(at: Vector3) -> void:
	touch.move = Vector2.ZERO
	player.global_position = at
	player.velocity = Vector3.ZERO
	if player.carried:
		player._let_go()


func snake_at(at: Vector3, long := 18.0, rest := Apophis.Rest.COILED) -> Apophis:
	var snake := Apophis.new()
	snake.length = long
	snake.rest = rest
	snake.voice = false
	snake.position = at
	stage.add_child(snake)
	snake.target = player
	return snake


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
	box(Vector3(0, -1, 0), Vector3(400, 2, 400), Color(0.7, 0.62, 0.46))
	cam = Camera3D.new()
	stage.add_child(cam)
	cam.make_current()
	light(true)
	touch = TouchControls.new()
	touch.visible = false
	stage.add_child(touch)
	touch.set_process_input(false)
	player = load("res://player.tscn").instantiate()
	player.position = Vector3(40.0, 0.05, 40.0)
	player.rest_enabled = false
	stage.add_child(player)
	player.set_process_unhandled_input(false)
	for action: StringName in InputMap.get_actions():
		if not String(action).begins_with("ui_"):
			InputMap.action_erase_events(action)
	await frames(20)

	for part: String in ["model", "head", "wake", "hole", "chase", "behind", "kerb", "ledge", "torch", "strike", "door", "home", "daylight", "cost", "yard"]:
		if wanted(part):
			await call(part)
	quit()


## Coiled, from all round and from above, with the boy beside him for his size.
func model() -> void:
	var at := Vector3(-60, 0, -60)
	put(at + Vector3(2.6, 0.05, 0.6))
	var snake := snake_at(at)
	await frames(20)
	for k in 6:
		var turn := [0.5, 1.6, 2.7, 3.8, 4.9, 0.0][k] as float
		var high := [2.0, 1.2, 2.6, 1.4, 2.2, 9.0][k] as float
		var far := 6.5 if k < 5 else 0.6
		look(at + Vector3(sin(turn) * far, high, cos(turn) * far), at + Vector3(0.6, 0.3, 0.2), 42.0)
		await frames(3)
		await snap()
	sheet("model", 3)
	snake.queue_free()


## His head close to: asleep, awake, mouth shut and open, from the side, the front and above.
func head() -> void:
	var at := Vector3(-60, 0, -30)
	put(at + Vector3(16.0, 0.05, 0.0))
	var snake := snake_at(at)
	await frames(10)
	snake.loose = true
	await frames(260)
	snake.set_physics_process(false)
	for k in 6:
		snake._gape_to = [0.0, 0.0, 0.5, 1.0, 1.0, 1.0][k]
		snake._rear_to = 0.9
		snake._gaze = player.global_position + Vector3.UP * 0.8
		await frames(30)
		var way := snake.head_way
		var across := Vector3.UP.cross(way).normalized()
		var from: Vector3 = [across * 1.5 + Vector3.UP * 0.2, way * 1.6 + across * 0.5 + Vector3.UP * 0.1, across * 1.5 + way * 0.5 + Vector3.UP * 0.2, across * 1.6 + way * 0.3,
				way * 1.9 + Vector3.UP * 0.05, way * 0.4 + Vector3.UP * 1.9 + across * 0.2][k]
		look(snake.head_at + way * 0.35 + from, snake.head_at + way * 0.35, 40.0)
		await frames(2)
		await snap()
	sheet("head", 3)
	snake.queue_free()


## Let out: his head comes up off his coils, and he slides out along himself.
func wake() -> void:
	var at := Vector3(-30, 0, -60)
	put(at + Vector3(11.0, 0.05, 1.0))
	var snake := snake_at(at)
	await frames(20)
	look(at + Vector3(5.5, 2.6, 6.5), at + Vector3(1.2, 0.5, 0.0), 45.0)
	await snap()
	snake.loose = true
	await frames(95)
	for k in 7:
		await frames(22)
		await snap()
	sheet("wake", 4)
	snake.queue_free()


## One that waits down a hole: nothing but the hole, and then him.
func hole() -> void:
	var at := Vector3(0, 0, -60)
	put(at + Vector3(12.0, 0.05, 1.0))
	var snake := snake_at(at, 18.0, Apophis.Rest.HOLE)
	await frames(20)
	look(at + Vector3(4.5, 2.4, 5.5), at + Vector3(0.8, 0.5, 0.0), 45.0)
	await snap()
	snake.loose = true
	await frames(90)
	for k in 7:
		await frames(16)
		await snap()
	sheet("hole", 4)
	snake.queue_free()


# The game's own camera, as the yard and the desert have it, on the boy.
func orbit() -> FollowCamera:
	var view := FollowCamera.new()
	view.mode = FollowCamera.Mode.ORBIT
	view.target = player
	stage.add_child(view)
	view.make_current()
	return view


## In full chase, from the game's camera turned to look back past the boy at what is behind him.
func chase() -> void:
	for dark: bool in [false, true]:
		light(not dark)
		var at := Vector3(-60, 0, 20)
		put(at + Vector3(5.0, 0.05, 0.0))
		var carried: HandTorch
		if dark:
			# (a brazier back where he started lights the snake from behind, and the moon the rest)
			world.environment.ambient_light_energy = 0.22
			sun.light_energy = 0.12
		var snake := snake_at(at)
		await frames(10)
		var view := orbit()
		view.settle_speed = 0.0
		view._yaw = PI * 0.5 + 0.5
		view._pitch = 0.22
		snake.loose = true
		await frames(130)
		steer(Vector3(1, 0, 0))
		# (he runs, tires, and it gains on him: the stick is eased until it is close behind)
		for k in 6:
			await frames(40)
			var gap := snake.head_at.distance_to(player.global_position)
			steer(Vector3(1, 0, 0) * (0.5 if gap > 3.4 else 1.0))
			await snap()
			if k == 4:
				await whole("chase_whole_dark" if dark else "chase_whole")
		print("CHASE %s: his head is %.1f m behind the boy, going %.2f m/s" % ["dark" if dark else "day", snake.head_at.distance_to(player.global_position), snake.velocity.length()])
		touch.move = Vector2.ZERO
		sheet("chase_dark" if dark else "chase", 3)
		view.queue_free()
		snake.queue_free()
		if carried:
			carried.queue_free()
		await frames(3)
	light(true)


## The same, as the camera sits when it is left alone: behind the boy, looking the way he runs. He is heard before he is seen.
func behind() -> void:
	var at := Vector3(-60, 0, 50)
	put(at + Vector3(5.0, 0.05, 0.0))
	var snake := snake_at(at)
	await frames(10)
	var view := orbit()
	snake.loose = true
	await frames(130)
	for k in 6:
		var gap := snake.head_at.distance_to(player.global_position)
		steer(Vector3(1, 0, 0) * (0.5 if gap > 3.0 else 1.0))
		await frames(45)
		await snap()
	touch.move = Vector2.ZERO
	sheet("behind", 3)
	view.queue_free()
	snake.queue_free()


## Over a kerb half a metre high and a block, and round a pillar: his body goes where his head went.
func kerb() -> void:
	var at := Vector3(-20, 0, 20)
	var things: Array[Node] = [box(at + Vector3(6, 0.25, 0), Vector3(0.5, 0.5, 8), Color(0.55, 0.5, 0.42)), box(at + Vector3(10, 0.45, 0.2), Vector3(0.9, 0.9, 0.9), Color(0.55, 0.4, 0.26)),
			box(at + Vector3(14, 1.5, 0), Vector3(0.8, 3.0, 0.8), Color(0.5, 0.45, 0.4))]
	put(at + Vector3(22.0, 0.05, 0.0))
	var snake := snake_at(at)
	await frames(10)
	snake.loose = true
	await frames(180)
	for k in 6:
		await frames(40)
		look(at + Vector3(10.0, 5.5, 9.5), at + Vector3(10.0, 0.3, 0.0), 50.0)
		await snap()
	sheet("kerb", 3)
	snake.queue_free()
	for thing in things:
		thing.queue_free()


## Under a ledge 2.5 m high with the boy up on it: he rears against it and sways, and then goes up the face.
func ledge() -> void:
	var at := Vector3(20, 0, 20)
	var block := box(at + Vector3(12, 1.25, 0), Vector3(6, 2.5, 6), Color(0.55, 0.5, 0.42))
	put(at + Vector3(11.0, 2.55, 0.0))
	var snake := snake_at(at)
	await frames(10)
	snake.loose = true
	await frames(260)
	look(at + Vector3(4.5, 3.4, 7.5), at + Vector3(8.6, 1.3, 0.0), 50.0)
	for k in 8:
		await snap()
		await frames(58)
	sheet("ledge", 4)
	snake.queue_free()
	block.queue_free()


## In the dark, the boy with a torch in his hand: he will not bring his head into the light. He rears and circles at the edge of it.
func torch() -> void:
	light(false)
	var at := Vector3(60, 0, -20)
	put(at + Vector3(9.0, 0.05, 0.0))
	var carried := HandTorch.new()
	carried.position = at + Vector3(9.0, 0.05, 0.5)
	carried.freeze = true
	stage.add_child(carried)
	await frames(30)
	player._act()
	await frames(60)
	var snake := snake_at(at)
	snake.loose = true
	await frames(330)
	for k in 6:
		look(player.visual_position + Vector3(1.5, 2.3, 6.5), player.visual_position + Vector3(-1.2, 0.8, 0.0), 50.0)
		await frames(3)
		await snap()
		if k == 2:
			await whole("torch_whole")
		await frames(50)
	print("TORCH carried %s, he is %s, his head %.2f m from the flame" % [player.carried is HandTorch, Apophis.State.keys()[snake.state], snake.global_position.distance_to(carried.global_position)])
	sheet("torch", 3)
	# (and the same from the game's camera)
	var view := orbit()
	view._yaw = PI * 0.5 - 0.5
	view.settle_speed = 0.0
	await frames(40)
	await whole("torch_game")
	view.queue_free()
	snake.queue_free()
	player._let_go()
	carried.queue_free()
	await frames(5)
	light(true)


## The strike: he stops, rears back with his mouth open, and throws his head. Every fifth frame from when he stops.
func strike() -> void:
	for dodge: bool in [false, true]:
		var at := Vector3(60, 0, 20)
		put(at + Vector3(8.0, 0.05, 0.0))
		var snake := snake_at(at)
		var hit := [false]
		snake.caught.connect(func() -> void: hit[0] = true)
		await frames(10)
		snake.loose = true
		for i in 600:
			await frames(1)
			if snake.state == Apophis.State.STRIKE:
				break
		for k in 12:
			look(player.global_position + Vector3(-1.2, 1.7, 4.6), player.global_position + Vector3(-1.2, 0.8, 0.0), 50.0)
			await snap()
			if k == 6 and not dodge:
				await whole("strike_whole")
			# (he steps aside in the moment's warning)
			if dodge and k >= 3:
				steer(Vector3(0, 0, 1))
			await frames(5)
		touch.move = Vector2.ZERO
		print("STRIKE %s: %s" % ["he steps aside" if dodge else "he stands", "caught" if hit[0] else "missed"])
		sheet("strike_dodged" if dodge else "strike", 4)
		snake.queue_free()
		await frames(3)


## A door shut in his face in a passage: he batters at it.
func door() -> void:
	var at := Vector3(20, 0, -20)
	var things: Array[Node] = [box(at + Vector3(7, 1.5, -1.3), Vector3(7, 3.0, 0.4), Color(0.55, 0.5, 0.42)), box(at + Vector3(8.5, 1.5, 1.3), Vector3(0.5, 3.0, 0.4), Color(0.55, 0.5, 0.42))]
	var slab := TombParts.Door.new(Vector3(0.4, 2.4, 2.2), Color(0.42, 0.38, 0.33))
	slab.position = at + Vector3(8.5, 1.2, 0)
	stage.add_child(slab)
	put(at + Vector3(13.0, 0.05, 0.0))
	var snake := snake_at(at)
	await frames(10)
	snake.loose = true
	await frames(330)
	look(at + Vector3(4.2, 2.2, 5.0), at + Vector3(7.2, 0.9, 0.0), 50.0)
	for k in 6:
		await frames(9)
		await snap()
	sheet("door", 3)
	snake.queue_free()
	slab.queue_free()
	for thing in things:
		thing.queue_free()


## Called off: he turns, goes back, and winds himself into his coil.
func home() -> void:
	var at := Vector3(-20, 0, -20)
	put(at + Vector3(30.0, 0.05, 0.0))
	var snake := snake_at(at)
	await frames(10)
	snake.loose = true
	await frames(280)
	snake.loose = false
	look(at + Vector3(3.0, 8.0, 9.0), at + Vector3(2.0, 0.0, 0.0), 50.0)
	for k in 8:
		await frames(80)
		await snap()
	sheet("home", 4)
	snake.queue_free()


## In the sun, from above: the whole length of him turning after the boy, who runs in a curve.
func daylight() -> void:
	var at := Vector3(60, 0, 60)
	put(at + Vector3(6.0, 0.05, 0.0))
	var snake := snake_at(at, 24.0)
	await frames(10)
	snake.loose = true
	await frames(120)
	for k in 6:
		look(snake.global_position + Vector3(-3.0, 19.0, 9.0), snake.global_position + Vector3(-3.0, 0.0, 0.0), 50.0)
		steer(Vector3(1, 0, 0).rotated(Vector3.UP, -k * 0.55))
		await frames(70)
		look(snake.global_position + Vector3(-3.0, 19.0, 9.0), snake.global_position + Vector3(-3.0, 0.0, 0.0), 50.0)
		await frames(2)
		await snap()
	touch.move = Vector2.ZERO
	sheet("sun", 3)
	snake.queue_free()


## What a frame of him costs: to move him, to lay his body, and to draw him.
func cost() -> void:
	put(Vector3(100, 0.05, -60))
	var snake := snake_at(Vector3(60, 0, -60), 30.0)
	await frames(10)
	snake.loose = true
	await frames(200)
	look(snake.global_position + Vector3(4.0, 5.0, 9.0), snake.global_position + Vector3(-4.0, 0.0, 0.0), 50.0)
	await frames(10)
	var with := Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)
	var began := Time.get_ticks_usec()
	for i in 240:
		snake._physics_process(1.0 / 60.0)
	var moving := (Time.get_ticks_usec() - began) / 240000.0
	began = Time.get_ticks_usec()
	for i in 240:
		snake._draw(1.0 / 60.0)
	var laying := (Time.get_ticks_usec() - began) / 240000.0
	var made := snake.cost()
	snake.visible = false
	for part: Node in snake.get_children():
		if part is GeometryInstance3D:
			(part as GeometryInstance3D).visible = false
	await frames(10)
	var without := Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)
	print("COST 30 m of him: %.3f ms a frame to move, %.3f ms to lay his body; %d triangles in %d meshes; %d draw calls with him in the picture, %d without (shadows and all)" % [
			moving, laying, made["triangles"], made["draws"], int(with), int(without)])
	snake.queue_free()


## His station in the test yard: coiled at the east end of the course, and let out.
func yard() -> void:
	stage.queue_free()
	await frames(2)
	var scene: Node = load("res://test_yard.tscn").instantiate()
	root.add_child(scene)
	await frames(30)
	var view := Camera3D.new()
	root.add_child(view)
	cam = view
	var boy := scene.get_node_or_null("Player") as Player
	var snake: Apophis
	for child in scene.find_children("*", "", true, false):
		if child is Apophis:
			snake = child
	if snake == null or boy == null:
		print("YARD no Apophis in the yard")
		return
	var at := snake.global_position
	boy.global_position = at + Vector3(-7.0, 0.3, 0.5)
	look(at + Vector3(-9.0, 5.0, 9.0), at + Vector3(-3.0, 0.5, 0.0), 55.0)
	await frames(30)
	await snap()
	look(Vector3(40.0, 22.0, -32.0), Vector3(40.0, 0.0, -57.0), 55.0)
	await frames(5)
	await snap()
	snake.loose = true
	look(at + Vector3(-9.0, 5.0, 9.0), at + Vector3(-3.0, 0.5, 0.0), 55.0)
	await frames(150)
	await snap()
	var touches := scene.find_children("*", "TouchControls", true, false)
	for k in 3:
		if not touches.is_empty():
			(touches[0] as TouchControls).move = Vector2(-1, 0)
		await frames(90)
		look(boy.global_position + Vector3(-3.0, 4.5, 9.0), boy.global_position + Vector3(2.5, 0.5, 0.0), 55.0)
		await frames(2)
		await snap()
	print("YARD he is %s, %.1f m behind the boy" % [Apophis.State.keys()[snake.state], snake.head_at.distance_to(boy.global_position)])
	sheet("yard", 3)
