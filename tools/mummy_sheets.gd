extends SceneTree
## Not part of the game. Puts the mummy (scripts/mummy.gd) on a bare floor with the
## boy to go after, drives it through each thing it does, and saves contact sheets.
##
## godot --path . --fixed-fps 60 --resolution 960x960 --script tools/mummy_sheets.gd -- <outdir> [turnaround face wake walk swipe dodge drapes ...] [lo]
##
## With no names, all of them; `lo` among them uses the demade model. It also
## prints lines starting CHECK: whether a swipe at a boy who stands still has
## him, and whether one at a boy who runs does not.
## Its window is kept off the screen and takes no input.

const CELL := 480
var out := ""
var only: Array = []
var stage: Node3D
var mummy: Mummy
var player: Player
var touch: TouchControls
var cam: Camera3D
var cells: Array[Image] = []
## Yaw round it, pitch, distance. The yaw is from straight in front of it, or
## (with `fixed`) a compass bearing that does not turn when it does.
var view := Vector3(0.6, 0.1, 5.0)
var fixed := false
var look_h := 0.95
var pin := Vector3.INF
var hits := 0


func _initialize() -> void:
	DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_NO_FOCUS, true)
	DisplayServer.window_set_position(Vector2i(-6000, -6000))
	var args := OS.get_cmdline_user_args()
	out = args[0]
	only = args.slice(1)
	if "lo" in only:
		only.erase("lo")
		Settings.low_poly = true
	DirAccess.make_dir_recursive_absolute(out)
	stage = Node3D.new()
	root.add_child(stage)
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.5, 0.56, 0.62)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.62, 0.66, 0.74)
	env.ambient_light_energy = 0.7
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	var world := WorldEnvironment.new()
	world.environment = env
	stage.add_child(world)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-48.0, -35.0, 0.0)
	sun.light_color = Color(1.0, 0.96, 0.9)
	sun.light_energy = 1.2
	sun.shadow_enabled = true
	stage.add_child(sun)
	var ground := StaticBody3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(400, 2, 400)
	var collider := CollisionShape3D.new()
	collider.shape = shape
	ground.add_child(collider)
	var mesh := BoxMesh.new()
	mesh.size = shape.size
	var visual := MeshInstance3D.new()
	visual.mesh = mesh
	var material := StandardMaterial3D.new()
	material.albedo_color = Color(0.3, 0.32, 0.34)
	material.roughness = 1.0
	visual.material_override = material
	ground.add_child(visual)
	ground.position = Vector3(0, -1, 0)
	stage.add_child(ground)

	touch = TouchControls.new()
	touch.visible = false
	stage.add_child(touch)
	touch.set_process_input(false)
	player = load("res://player.tscn").instantiate()
	player.position = Vector3(0, 0.05, 60)
	stage.add_child(player)
	player.set_process_unhandled_input(false)
	mummy = Mummy.new()
	mummy.position = Vector3(0, 0.05, 0)
	stage.add_child(mummy)
	mummy.target = player
	mummy.caught.connect(func() -> void: hits += 1)
	cam = Camera3D.new()
	cam.fov = 30.0
	stage.add_child(cam)
	cam.make_current()
	run.call_deferred()


func aim() -> void:
	var yaw: float = view.x if fixed else mummy.facing_yaw + view.x
	var away := Vector3(sin(yaw) * cos(view.y), sin(view.y), cos(yaw) * cos(view.y))
	var watch: Vector3 = mummy.visual_position + Vector3.UP * look_h
	if pin != Vector3.INF:
		watch = pin
	cam.global_position = watch + away * view.z
	cam.look_at(watch)


## Runs the game on. `hold`: where the boy is kept standing. `flee`: or the way he goes, and how fast.
func frames(count: int, hold := Vector3.INF, flee := Vector3.ZERO) -> void:
	for i in count:
		aim()
		if hold != Vector3.INF:
			player.global_position = hold
			player.velocity = Vector3.ZERO
		if flee != Vector3.ZERO:
			player.global_position += flee / 60.0
			player.velocity = Vector3.ZERO
		await physics_frame
		await process_frame


func snap() -> void:
	aim()
	await RenderingServer.frame_post_draw
	var image := root.get_texture().get_image()
	var side: int = mini(image.get_width(), image.get_height())
	image = image.get_region(Rect2i((image.get_width() - side) / 2, (image.get_height() - side) / 2, side, side))
	image.resize(CELL, CELL, Image.INTERPOLATE_LANCZOS)
	cells.append(image)


func sheet(name: String, columns := 4) -> void:
	var rows := ceili(cells.size() / float(columns))
	var page := Image.create(CELL * columns, CELL * rows, false, cells[0].get_format())
	for i in cells.size():
		page.blit_rect(cells[i], Rect2i(0, 0, CELL, CELL), Vector2i((i % columns) * CELL, (i / columns) * CELL))
	var file := out.path_join(("lo_" if Settings.low_poly else "") + name + ".png")
	page.save_png(file)
	cells.clear()
	print("SHEET ", file)


## Puts the mummy back at the middle of the floor, dormant, facing +Z, and the boy at `boy`.
func place(boy: Vector3) -> void:
	mummy._spawn = Transform3D(Basis.IDENTITY, Vector3(0, 0.05, 0))
	mummy.reset()
	touch.move = Vector2.ZERO
	player.state = Player.State.FREE
	player.global_position = boy
	player.velocity = Vector3.ZERO
	player._spawn = Transform3D(Basis.IDENTITY, boy)
	player.respawn()
	player._reset_visuals()
	fixed = false
	look_h = 0.95


## Wakes it and lets it get going after the boy, who is kept at `boy`.
func rouse(boy: Vector3, lead: int) -> void:
	place(boy)
	mummy.wake()
	await frames(int(mummy.wake_time * 60.0) + lead, boy)


func wants(name: String) -> bool:
	return only.is_empty() or name in only


func run() -> void:
	# A gamepad is heard whether the window has the focus or not, and someone may be playing.
	for action: StringName in InputMap.get_actions():
		if not String(action).begins_with("ui_"):
			InputMap.action_erase_events(action)
			Input.action_release(action)
	await frames(5)
	for name: String in ["turnaround", "face", "wake", "walk", "swipe", "dodge", "drapes", "stop"]:
		if wants(name):
			await call(name)
	quit()


## All round it: as it stands dormant, and awake with nobody to go after.
func turnaround() -> void:
	place(Vector3(0, 0.05, 60))
	await frames(40)
	for yaw: float in [0.0, 0.7, PI * 0.5, PI - 0.6, PI, -0.7]:
		view = Vector3(yaw, 0.08, 5.6)
		await frames(2)
		await snap()
	sheet("dormant", 3)
	mummy.target = null
	mummy.wake()
	await frames(240)
	for yaw: float in [0.0, 0.7, PI * 0.5, PI - 0.6, PI, -0.7]:
		view = Vector3(yaw, 0.08, 5.6)
		await frames(2)
		await snap()
	sheet("turnaround", 3)
	# A hand, and its feet
	look_h = 0.55
	for yaw: float in [0.9, -0.9]:
		view = Vector3(yaw, 0.1, 2.0)
		await frames(2)
		await snap()
	look_h = 0.2
	for yaw: float in [0.7, PI - 0.7]:
		view = Vector3(yaw, 0.2, 2.2)
		await frames(2)
		await snap()
	sheet("closeups", 2)
	mummy.target = player


## Its face, close to, from several sides and from the boy's height.
func face() -> void:
	# (it is after the boy, so its head is up, but is held where it stands)
	place(Vector3(0, 0.05, 6))
	var speed := mummy.walk_speed
	mummy.walk_speed = 0.001
	mummy.wake()
	await frames(240, Vector3(0, 0.05, 6))
	var head: Node3D = mummy._rig._head
	for angle: Vector2 in [Vector2(0.0, 0.0), Vector2(0.45, 0.0), Vector2(0.9, 0.05), Vector2(PI * 0.5, 0.0), Vector2(-0.6, 0.1), Vector2(0.0, -0.45), Vector2(0.5, -0.4), Vector2(2.4, 0.1)]:
		pin = head.global_position + Vector3.UP * 0.09
		view = Vector3(angle.x, angle.y, 1.15)
		await frames(2)
		await snap()
	sheet("face", 4)
	pin = Vector3.INF
	mummy.walk_speed = speed


## Woken: from standing dead to coming on.
func wake() -> void:
	place(Vector3(0, 0.05, 30))
	await frames(30)
	view = Vector3(0.55, 0.08, 5.6)
	mummy.wake()
	for i in 12:
		await snap()
		await frames(14, Vector3(0, 0.05, 30))
	sheet("wake", 4)


## The walk: side on at every fourth frame, then coming at the camera, then going away.
func walk() -> void:
	await rouse(Vector3(200, 0.05, 0), 150)
	fixed = true
	view = Vector3(0.0, 0.04, 6.2)
	for i in 20:
		await frames(4, Vector3(200, 0.05, 0))
		await snap()
	sheet("walk_side", 5)
	view = Vector3(PI * 0.5 - 0.35, 0.1, 6.2)
	for i in 8:
		await frames(7, Vector3(200, 0.05, 0))
		await snap()
	sheet("walk_front", 4)
	view = Vector3(-PI * 0.5 + 0.4, 0.14, 6.2)
	for i in 8:
		await frames(7, Vector3(200, 0.05, 0))
		await snap()
	sheet("walk_back", 4)
	print("CHECK walk: going ", snappedf(Vector2(mummy.velocity.x, mummy.velocity.z).length(), 0.01), " m/s just now, ", snappedf(mummy.global_position.x / ((150 + 80 + 56 + 56) / 60.0), 0.01), " m/s over all of it")


## Runs it up to the boy and waits for it to begin its next swipe. False if it never does.
func closes(boy: Vector3) -> bool:
	var before := mummy._swipes
	for i in 900:
		if mummy._swipes > before:
			return true
		await frames(1, boy)
	print("CHECK swipe: it never began one")
	return false


## Three swipes at a boy who stands where he is: the right arm, the left, and both.
func swipe() -> void:
	var boy := Vector3(4.0, 0.05, 0)
	await rouse(boy, 0)
	for kind: String in ["right", "left", "both"]:
		hits = 0
		if not await closes(boy):
			return
		fixed = true
		view = Vector3(0.5, 0.12, 7.0)
		look_h = 0.9
		for i in 20:
			await snap()
			await frames(5, boy)
		sheet("swipe_" + kind, 5)
		print("CHECK swipe ", kind, ": the boy stood still and it ", "had him" if hits > 0 else "MISSED him", " (", hits, ")")
	# And one from in front, as he sees it
	if await closes(boy):
		view = Vector3(PI * 0.5 - 0.15, 0.05, 6.0)
		for i in 15:
			await snap()
			await frames(5, boy)
		sheet("swipe_front", 5)


## The same, at a boy who makes off as soon as it rears: at a run, at a walk, and sideways.
func dodge() -> void:
	for way: Array in [["runs away", Vector3(4.4, 0, 0)], ["walks away", Vector3(1.6, 0, 0)], ["runs across", Vector3(0, 0, 4.4)], ["walks across", Vector3(0, 0, 1.6)]]:
		var boy := Vector3(4.0, 0.05, 0)
		await rouse(boy, 0)
		hits = 0
		if not await closes(boy):
			return
		# (he takes a moment to see it)
		await frames(9, boy)
		await frames(110, Vector3.INF, way[1])
		print("CHECK dodge: the boy ", way[0], " and it ", "HAD him" if hits > 0 else "missed him")


## What hangs from it, as it turns hard about: from behind and to one side.
func drapes() -> void:
	await rouse(Vector3(200, 0.05, 0), 120)
	fixed = true
	view = Vector3(-PI * 0.5 - 0.6, 0.12, 5.6)
	# (the boy is suddenly behind it and to one side)
	var boy := mummy.global_position + Vector3(-6, 0, 5)
	for i in 20:
		await snap()
		await frames(5, boy)
	sheet("drapes_turn", 5)


## And as it stops dead.
func stop() -> void:
	await rouse(Vector3(200, 0.05, 0), 120)
	fixed = true
	view = Vector3(0.5, 0.1, 5.0)
	mummy.target = null
	for i in 15:
		await snap()
		await frames(5)
	sheet("drapes_stop", 5)
	mummy.target = player
