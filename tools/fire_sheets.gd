extends SceneTree
## Not part of the game. Pictures of fire: each kind (candle, torch, brazier,
## bonfire) by day and in the dark, a few frames apart, to see it move; and the
## boy picking a torch up and carrying it.
## godot --path . --fixed-fps 60 --resolution 960x960 --script tools/fire_sheets.gd -- <outdir>

const CELL := 480
var out := ""
var cells: Array[Image] = []
var cam: Camera3D
var world: WorldEnvironment
var sun: DirectionalLight3D


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
	world.environment.background_color = Color(0.5, 0.56, 0.62) if day else Color(0.03, 0.035, 0.05)
	world.environment.ambient_light_energy = 0.7 if day else 0.08
	sun.light_energy = 1.2 if day else 0.0


func run() -> void:
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
	visual.material_override = Toon.surface(Color(0.62, 0.55, 0.42))
	floor_body.add_child(visual)
	floor_body.position.y = -1.0
	stage.add_child(floor_body)
	# A wall behind, to see the light it throws come and go
	var wall := MeshInstance3D.new()
	var wall_mesh := BoxMesh.new()
	wall_mesh.size = Vector3(30, 5, 0.5)
	wall.mesh = wall_mesh
	wall.material_override = Toon.surface(Color(0.55, 0.5, 0.42))
	wall.position = Vector3(0, 2.5, -2.2)
	stage.add_child(wall)
	cam = Camera3D.new()
	stage.add_child(cam)
	cam.make_current()

	var fires := [Fire.candle(), Fire.torch(), Fire.brazier(), Fire.bonfire()]
	for i in fires.size():
		fires[i].position = Vector3(i * 6.0, 0.9 if i < 2 else 0.1, 0.0)
		stage.add_child(fires[i])
	for day: bool in [true, false]:
		light(day)
		for i in fires.size():
			var tall: float = fires[i].size
			var watch: Vector3 = fires[i].position + Vector3.UP * tall * 0.8
			cam.global_position = watch + Vector3(0.0, tall * 0.4 + 0.1, 0.9 + tall * 3.2)
			cam.look_at(watch)
			cam.fov = 40.0
			await frames(40)
			for k in 6:
				await frames(4)
				await snap()
		sheet("fires_day" if day else "fires_dark", 6)

	# Carrying a torch
	light(false)
	var touch := TouchControls.new()
	touch.visible = false
	stage.add_child(touch)
	touch.set_process_input(false)
	var player: Player = load("res://player.tscn").instantiate()
	player.position = Vector3(-8.0, 0.05, 2.0)
	stage.add_child(player)
	player.set_process_unhandled_input(false)
	for action: StringName in InputMap.get_actions():
		if not String(action).begins_with("ui_"):
			InputMap.action_erase_events(action)
	var torch := HandTorch.new()
	torch.position = Vector3(-8.0, 0.05, 2.5)
	torch.freeze = true
	stage.add_child(torch)
	await frames(30)
	player._act()
	for view: Array in [[0.6, 3.4], [-1.2, 3.4], [2.6, 3.4]]:
		for k in 3:
			await frames(30 if k == 0 else 8)
			touch.move = Vector2(0.0, 0.0) if view[0] == 0.6 else Vector2(1.0, 0.0)
			var watch := player.visual_position + Vector3.UP * 0.75
			cam.global_position = watch + Vector3(sin(view[0]), 0.25, cos(view[0])) * view[1]
			cam.look_at(watch)
			await snap()
	print("CARRIED ", player.carried is HandTorch, " torch at ", torch.global_position, " up ", torch.global_basis.y)
	sheet("torch_carried", 3)
	quit()
