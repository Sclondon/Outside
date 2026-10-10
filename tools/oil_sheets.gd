extends SceneTree
## Not part of the game. Pictures of oil. On a stone floor: a puddle, a trail, a jar and a fire dish by day
## and by torchlight; a trail burning from one end, a few frames apart, in the dark and by day; a heap of
## jars bursting. Then in the test yard, on sand: the oil station, the fuse close to, the boy carrying a jar
## and pouring from it, and the fuse burning under the web to the jars after dark.
## godot --path . --fixed-fps 60 --resolution 960x960 --script tools/oil_sheets.gd -- <outdir> [stone] [yard]
## (add --rendering-method gl_compatibility to see it as the web draws it)

const CELL := 480
var out := ""
var cells: Array[Image] = []
var cam: Camera3D
var world: WorldEnvironment
var sun: DirectionalLight3D
var day_sun := 1.2
var day_ambient := 0.7
var day_sky := Color(0.5, 0.56, 0.62)


func _initialize() -> void:
	DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_NO_FOCUS, true)
	DisplayServer.window_set_position(Vector2i(-6000, -6000))
	out = OS.get_cmdline_user_args()[0]
	run.call_deferred()


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
	world.environment.background_color = day_sky if day else Color(0.03, 0.035, 0.05)
	world.environment.ambient_light_energy = day_ambient if day else 0.08
	sun.light_energy = day_sun if day else 0.0


func look(from: Vector3, at: Vector3, fov := 40.0) -> void:
	cam.global_position = from
	cam.look_at(at)
	cam.fov = fov


func run() -> void:
	var which := OS.get_cmdline_user_args().slice(1)
	for action: StringName in InputMap.get_actions():
		if not String(action).begins_with("ui_"):
			InputMap.action_erase_events(action)
	if which.is_empty() or which.has("stone"):
		await stone()
	if which.is_empty() or which.has("yard"):
		await yard()
	quit()


func stone() -> void:
	var stage := Node3D.new()
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
	var floor_body := StaticBody3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(60, 2, 60)
	var collider := CollisionShape3D.new()
	collider.shape = shape
	floor_body.add_child(collider)
	var mesh := BoxMesh.new()
	mesh.size = shape.size
	var visual := MeshInstance3D.new()
	visual.mesh = mesh
	visual.material_override = Toon.sandstone()
	floor_body.add_child(visual)
	floor_body.position.y = -1.0
	stage.add_child(floor_body)
	var wall := MeshInstance3D.new()
	var wall_mesh := BoxMesh.new()
	wall_mesh.size = Vector3(30, 5, 0.5)
	wall.mesh = wall_mesh
	wall.material_override = Toon.sandstone()
	wall.position = Vector3(0, 2.5, -3.2)
	stage.add_child(wall)
	cam = Camera3D.new()
	stage.add_child(cam)
	cam.make_current()
	await frames(5)
	var oil := Oil.of(stage)
	await frames(3)

	# A puddle, a trail, a jar and a dish
	for n in 22:
		oil.pour(Vector3(0, 0.6, 0))
	oil.lay(Vector3(-2.4, 0, 1.2), Vector3(-0.2, 0, 0.5))
	oil.lay(Vector3(0.4, 0, 0.6), Vector3(2.6, 0, 1.5))
	var jar := OilJar.new()
	jar.position = Vector3(1.3, 0.0, -0.5)
	stage.add_child(jar)
	var tipped := OilJar.new()
	tipped.position = Vector3(1.9, 0.15, -0.9)
	tipped.rotation = Vector3(0.0, 0.7, 1.45)
	stage.add_child(tipped)
	var dish := OilMark.new()
	dish.position = Vector3(-1.5, 0, -0.7)
	stage.add_child(dish)
	var torch := HandTorch.new()
	torch.position = Vector3(2.7, 0.02, -0.5)
	torch.rotation.z = 0.12
	torch.freeze = true
	stage.add_child(torch)
	await frames(60)
	for day: bool in [true, false]:
		light(day)
		await frames(10)
		look(Vector3(0.3, 2.6, 4.6), Vector3(0.2, 0.0, 0.2))
		await snap()
		look(Vector3(-2.6, 0.7, 3.2), Vector3(0.0, 0.0, 0.3))
		await snap()
		look(Vector3(2.4, 0.55, 0.8), Vector3(1.4, 0.2, -0.6), 34.0)
		await snap()
		look(Vector3(-2.4, 0.9, 1.0), Vector3(-1.5, 0.0, -0.7), 34.0)
		await snap()
	sheet("stone_puddles", 4)
	for thing: Node in [jar, tipped, dish, torch]:
		thing.queue_free()
	oil.clear()
	await frames(5)

	# A trail burning from one end
	for day: bool in [false, true]:
		light(day)
		oil.lay(Vector3(-3, 0, 0.4), Vector3(0.5, 0, 0.9))
		oil.lay(Vector3(0.5, 0, 0.9), Vector3(3, 0, 0.2))
		for n in 12:
			oil.pour(Vector3(3.2, 0.6, 0.2))
		await frames(40)
		look(Vector3(0.0, 2.3, 6.4), Vector3(0.0, 0.3, 0.4), 44.0)
		oil.ignite(Vector3(-3, 0, 0.4))
		for k in 8 if not day else 4:
			await frames(45 if not day else 100)
			await snap()
		if not day:
			# (and close to, low down)
			look(Vector3(1.4, 0.5, 3.0), Vector3(0.8, 0.35, 0.8), 40.0)
			for k in 4:
				await frames(5)
				await snap()
			# (and as it dies, and what it leaves)
			look(Vector3(0.0, 2.3, 6.4), Vector3(0.0, 0.3, 0.4), 44.0)
			for k in 4:
				await frames(110)
				await snap()
		sheet("burn_dark" if not day else "burn_day", 4)
		while oil.burning:
			await frames(10)
		if day:
			await snap()
			look(Vector3(0.6, 0.8, 2.6), Vector3(0.3, 0.0, 0.7), 40.0)
			await snap()
			sheet("scorch", 2)
		oil.clear()
		await frames(5)

	# A heap of jars at the end of a fuse
	light(false)
	oil.lay(Vector3(-2.5, 0, 0.5), Vector3(0.0, 0, 0.5))
	var heap: Array[OilJar] = []
	for place: Vector3 in [Vector3(0.25, 0.0, 0.5), Vector3(0.6, 0.0, 0.9), Vector3(0.65, 0.0, 0.1)]:
		var one := OilJar.new()
		one.position = place
		stage.add_child(one)
		heap.append(one)
	await frames(30)
	look(Vector3(0.2, 2.0, 6.0), Vector3(0.2, 0.7, 0.5), 44.0)
	oil.ignite(Vector3(-2.5, 0, 0.5))
	while not heap[0].is_broken:
		await frames(1)
	for k in 8:
		await snap()
		await frames(3 if k < 4 else 25)
	sheet("burst", 4)
	# (the oil is the scene's, not the stage's: it would be there still in the yard)
	oil.queue_free()
	stage.queue_free()
	await frames(5)


func yard() -> void:
	var main: Node = (load("res://test_yard.tscn") as PackedScene).instantiate()
	root.add_child(main)
	await frames(20)
	var level := main.get_node(^"Level")
	(main.get_node(^"HUD") as CanvasLayer).visible = false
	var touch := main.get_node(^"HUD/TouchControls") as TouchControls
	touch.set_process_input(false)
	var player := main.get_node(^"Player") as Player
	player.set_process_unhandled_input(false)
	player.rest_enabled = false
	world = level.find_children("*", "WorldEnvironment", true, false)[0]
	sun = level.find_children("*", "DirectionalLight3D", true, false)[0]
	day_sun = sun.light_energy
	day_ambient = world.environment.ambient_light_energy
	day_sky = world.environment.background_color
	cam = Camera3D.new()
	main.add_child(cam)
	cam.make_current()
	var at := Vector3(52.0, 0.0, 10.0)
	player.global_position = at + Vector3(-4.6, 0.05, -1.3)
	player.velocity = Vector3.ZERO
	await frames(60)
	var oil := Oil.of(main)

	# The station, and the fuse on the sand
	look(at + Vector3(-1.0, 6.5, 13.0), at + Vector3(0.5, 0.3, 1.0), 44.0)
	await snap()
	look(at + Vector3(-3.2, 0.8, 6.2), at + Vector3(0.0, 0.0, 4.0), 40.0)
	await snap()
	look(at + Vector3(2.2, 0.6, 5.6), at + Vector3(4.4, 0.2, 4.0), 36.0)
	await snap()
	look(at + Vector3(0.3, 0.7, -1.4), at + Vector3(1.5, 0.0, -3.0), 40.0)
	await snap()
	sheet("yard_station", 2)

	# He takes a jar up, carries it, ducks and pours
	player._act()
	await frames(80)
	print("CARRIED ", player.carried is OilJar)
	for view: float in [0.6, -1.3, 2.6]:
		var watch := player.visual_position + Vector3.UP * 0.75
		look(watch + Vector3(sin(view), 0.25, cos(view)) * 3.2, watch)
		await snap()
	touch.duck_held = true
	await frames(40)
	for view: float in [0.6, -1.3, 2.6]:
		var watch := player.visual_position + Vector3.UP * 0.5
		look(watch + Vector3(sin(view), 0.3, cos(view)) * 3.0, watch)
		await snap()
	# (he sneaks off east with it, pouring: the camera is to the south)
	look(player.global_position + Vector3(1.5, 1.6, 5.0), player.global_position + Vector3(1.5, 0.3, 0.0), 44.0)
	touch.move = Vector2(1.0, 0.0)
	for k in 3:
		await frames(50)
		await snap()
	touch.move = Vector2.ZERO
	await frames(30)
	var jar := player.carried as OilJar
	print("POURED ", oil.amounts(), " left ", jar.left if jar else -1)
	var watch_low := player.visual_position + Vector3.UP * 0.4
	look(watch_low + Vector3(-1.6, 0.5, 2.0), watch_low - Vector3(0.6, 0.3, 0.0), 40.0)
	await snap()
	touch.duck_held = false
	await frames(30)
	look(player.global_position + Vector3(-2.5, 1.0, 2.6), player.global_position + Vector3(-1.2, 0.0, 0.0), 40.0)
	await snap()
	# Thrown, it breaks
	player._act()
	await frames(70)
	look(player.global_position + Vector3(1.0, 3.2, -5.5), player.global_position + Vector3(4.5, 0.0, 0.0), 44.0)
	await snap()
	sheet("yard_jar", 3)

	# After dark: the fuse is lit, and burns under the web to the jars
	light(false)
	player.global_position = at + Vector3(-5.0, 0.05, 6.0)
	await frames(20)
	look(at + Vector3(-6.0, 3.0, 11.0), at + Vector3(1.4, 0.7, 3.8), 44.0)
	await snap()
	oil.ignite(at + Vector3(-2.0, 0.0, 4.0))
	for k in 7:
		await frames(55)
		await snap()
	sheet("yard_fuse_dark", 4)
	print("WEBS LEFT ", level.find_children("*", "Cobweb", true, false).filter(func(web: Node) -> bool: return web.global_position.distance_to(at) < 8.0 and web.visible).size())
	# By day, what is left, and the poured trail lit
	light(true)
	oil.ignite(at + Vector3(-4.6, 0.0, -1.4), 1.5)
	look(at + Vector3(-3.0, 2.6, 5.5), at + Vector3(-2.5, 0.3, -1.0), 44.0)
	for k in 4:
		await frames(50)
		await snap()
	sheet("yard_fire_day", 4)
