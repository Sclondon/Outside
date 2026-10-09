extends SceneTree
## Not part of the game. Opens the test yard, walks and runs the boy over its
## sand, and saves contact sheets of what the sand makes of it: the kinds of
## ground, the prints he leaves in each, the collar pushed out round a foot,
## the sand thrown up by a run and a landing, and the lobes that ooze down a
## steep face when he treads on it. It prints what the ground costs a frame.
## godot --path . --fixed-fps 60 --resolution 960x960 --script tools/sand_sheets.gd -- <outdir> [q0|q1|q2] [banded] [breeze] [name ...]
## Names: kinds, prints, snow, collar, spray, land, ooze, slide. (q0..q2: `Sand.quality`.
## The air is still unless `breeze` is given.)

const CELL := 480

var out := ""
var only: Array = []
var scene: Node
var yard: Node3D
var ground: SandGround
var player: Player
var touch: TouchControls
var cam: Camera3D
var cells: Array[Image] = []
## Where the camera stands and what it looks at: fixed, or (if `follow`) both
## measured from where he is.
var eye := Vector3(0.0, 3.0, 4.0)
var target := Vector3.ZERO
var follow := false
var worst := 0.0


func _initialize() -> void:
	DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_NO_FOCUS, true)
	DisplayServer.window_set_position(Vector2i(-6000, -6000))
	var args := OS.get_cmdline_user_args()
	out = args[0]
	only = args.slice(1)
	for quality in 3:
		if "q%d" % quality in only:
			only.erase("q%d" % quality)
			Sand.quality = quality
	if "banded" in only:
		only.erase("banded")
		Settings.world_banded = true
	scene = load("res://test_yard.tscn").instantiate()
	root.add_child(scene)
	yard = scene.get_node("Level")
	player = scene.get_node("Player")
	player.set_process_unhandled_input(false)
	touch = scene.get_node("HUD/TouchControls")
	touch.set_process_input(false)
	(scene.get_node("HUD") as CanvasLayer).visible = false
	# (the yard's own camera follows him; this one is put where the pictures want it)
	var own := scene.get_node("Camera") as Camera3D
	own.set_process(false)
	own.set_physics_process(false)
	cam = Camera3D.new()
	cam.fov = 30.0
	root.add_child(cam)
	cam.make_current()
	run.call_deferred()


func run() -> void:
	# Someone may be playing with a gamepad, which is heard without the focus.
	for action: StringName in InputMap.get_actions():
		if not String(action).begins_with("ui_"):
			InputMap.action_erase_events(action)
			Input.action_release(action)
	await process_frame
	ground = yard.get("ground")
	ground.auto_quality = false
	# (still air, unless asked: the wind's streamers of sand cross every picture)
	if "breeze" in only:
		only.erase("breeze")
	else:
		(yard.get("wind") as SandWind).weather = SandWind.Weather.CALM
	await frames(10)
	# (his brother and the cat would walk through the pictures)
	for child in yard.get_children():
		if child is Brother or child is Cat:
			child.queue_free()
	await frames(5)
	print("QUALITY ", Sand.quality, "  renderer ", RenderingServer.get_current_rendering_method())
	for name: String in ["kinds", "prints", "snow", "collar", "spray", "land", "ooze", "slide"]:
		if only.is_empty() or name in only:
			worst = 0.0
			await call(name)
			print("COST %-8s ground %4d usec a frame at the end, %4d at the worst" % [name, ground.cost_usec, worst])
	quit()


func aim() -> void:
	var from := eye
	var at := target
	if follow:
		from += player.visual_position
		at += player.visual_position
	cam.global_position = from
	cam.look_at(at)
	cam.make_current()


## Sets the stick so that he heads `world` (its length is how hard it is pushed).
func steer(world: Vector3) -> void:
	var basis := cam.global_basis
	var right := Vector3(basis.x.x, 0, basis.x.z).normalized()
	var forward := Vector3(-basis.z.x, 0, -basis.z.z).normalized()
	touch.move = Vector2(world.dot(right), -world.dot(forward))


func frames(count: int, heading := Vector3.INF) -> void:
	for i in count:
		aim()
		if heading != Vector3.INF:
			steer(heading)
		await physics_frame
		await process_frame
		worst = maxf(worst, ground.cost_usec)


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
	page.save_png(out.path_join(name + ".png"))
	cells.clear()
	print("SHEET ", name)


## A strip of `count` pictures, one every `every` frames, steering `heading` if given.
func shots(name: String, count: int, every: int, heading := Vector3.INF, columns := 4) -> void:
	for i in count:
		await frames(every, heading)
		await snap()
	sheet(name, columns)


## Puts him down on the ground at (x, z), facing `heading`.
func place(x: float, z: float, heading: Vector3) -> void:
	var at := Vector3(x, ground.height_at(x, z) + 0.05, z)
	var yaw := atan2(heading.x, heading.z)
	touch.move = Vector2.ZERO
	touch.duck_held = false
	touch.jump_held = false
	player.state = Player.State.FREE
	player.global_position = at
	player.velocity = Vector3.ZERO
	player.facing_yaw = yaw
	player._spawn = Transform3D(Basis.IDENTITY, at)
	player.respawn()
	player.facing_yaw = yaw
	player._reset_visuals()


func stop() -> void:
	touch.move = Vector2.ZERO
	touch.duck_held = false
	touch.jump_held = false


## The row of kinds: all of it, each kind from near by, and the prints left by
## walking the length of it.
func kinds() -> void:
	var consts: Dictionary = (yard.get_script() as Script).get_script_constant_map()
	var row: Rect2 = consts["KINDS"]
	var gap: float = consts["KIND_GAP"]
	var first := row.position.x - gap * 2.5
	follow = false
	place(row.position.x, row.position.y - 6.0, Vector3(0, 0, 1))
	eye = Vector3(row.position.x, 12.0, row.position.y - 22.0)
	target = Vector3(row.position.x, 0.0, row.position.y)
	cam.fov = 50.0
	await frames(6)
	await snap()
	eye = Vector3(row.position.x, 30.0, row.position.y - 0.1)
	await frames(3)
	await snap()
	cam.fov = 40.0
	# (two edges: dirt into sandstone, and sandstone into white sand)
	for edge in 2:
		eye = Vector3(first + gap * (edge + 0.5), 4.0, row.position.y - 4.5)
		target = Vector3(first + gap * (edge + 0.5), 0.0, row.position.y)
		await frames(3)
		await snap()
	sheet("kinds", 2)
	for i in 6:
		eye = Vector3(first + gap * i + 0.6, 1.5, row.position.y - 2.2)
		target = Vector3(first + gap * i, 0.0, row.position.y)
		await frames(3)
		await snap()
	sheet("kinds_near", 3)
	# He walks the length of it, and what he leaves in each is looked at from
	# over his shoulder as he goes off it. (The ground remembers only what is
	# within a few metres of him.)
	place(first - gap * 0.6, row.position.y, Vector3(1, 0, 0))
	eye = Vector3(row.position.x, 14.0, row.position.y - 20.0)
	target = Vector3(row.position.x, 0.0, row.position.y)
	await frames(20)
	var steps := 0
	var next := 0
	while next < 6 and steps < 2500:
		eye = Vector3(row.position.x, 14.0, row.position.y - 20.0)
		target = Vector3(row.position.x, 0.0, row.position.y)
		cam.fov = 50.0
		await frames(1, Vector3(0.55, 0, 0))
		steps += 1
		if player.global_position.x > first + gap * next + 1.7:
			print("  %d: give %.2f here, %.2f in the middle of it" % [next, ground.give_at(player.global_position.x, player.global_position.z), ground.give_at(first + gap * next, row.position.y)])
			cam.fov = 30.0
			eye = Vector3(first + gap * next - 1.6, 1.5, row.position.y - 2.4)
			target = Vector3(first + gap * next + 0.5, 0.0, row.position.y)
			await snap()
			next += 1
	stop()
	sheet("kinds_prints", 3)
	# And stands on each, to see how far he sinks.
	for i in [0, 2]:
		place(first + gap * i, row.position.y + 0.9, Vector3(0, 0, -1))
		follow = true
		eye = Vector3(0.9, 0.35, -1.6)
		target = Vector3(0.0, 0.12, 0.0)
		await frames(150)
		await snap()
		follow = false
	sheet("kinds_sink", 2)


## Walked and run over level sand, and the prints looked at from above and from low down.
func prints() -> void:
	cam.fov = 30.0
	var from := Vector3(4.0, 0.0, -4.0)
	follow = false
	for pace: float in [0.5, 1.0]:
		place(from.x - 3.0, from.z, Vector3(1, 0, 0))
		eye = from + Vector3(0.0, 9.0, 6.0)
		target = from
		await frames(20)
		await frames(110 if pace < 1.0 else 60, Vector3(pace, 0, 0))
		stop()
		var here := player.global_position
		# (from above, behind him; and low, across the light)
		eye = here + Vector3(-1.4, 2.6, 0.01)
		target = here + Vector3(-1.4, 0.0, 0.0)
		await frames(4)
		await snap()
		eye = here + Vector3(-1.2, 0.5, 1.5)
		target = here + Vector3(-1.2, 0.0, 0.0)
		await frames(2)
		await snap()
		eye = here + Vector3(1.5, 0.9, 1.2)
		target = here + Vector3(-1.2, 0.0, 0.0)
		await frames(2)
		await snap()
		# (as the game shows it)
		eye = here + Vector3(0.0, 2.6, 10.0)
		target = here + Vector3(0.0, 0.8, 0.0)
		await frames(2)
		await snap()
		from += Vector3(0.0, 0.0, -2.5)
	sheet("prints", 4)


## The same on ground that is all snow: the print of the boot.
func snow() -> void:
	ground.snow = true
	cam.fov = 30.0
	follow = false
	var from := Vector3(-4.0, 0.0, -3.0)
	place(from.x - 3.0, from.z, Vector3(1, 0, 0))
	eye = from + Vector3(0.0, 9.0, 6.0)
	target = from
	await frames(20)
	await frames(120, Vector3(0.5, 0, 0))
	stop()
	var here := player.global_position
	eye = here + Vector3(-1.4, 2.6, 0.01)
	target = here + Vector3(-1.4, 0.0, 0.0)
	await frames(4)
	await snap()
	eye = here + Vector3(-1.2, 0.5, 1.5)
	target = here + Vector3(-1.2, 0.0, 0.0)
	await frames(2)
	await snap()
	eye = here + Vector3(1.5, 0.9, 1.2)
	target = here + Vector3(-1.2, 0.0, 0.0)
	await frames(2)
	await snap()
	eye = here + Vector3(0.0, 2.6, 10.0)
	target = here + Vector3(0.0, 0.8, 0.0)
	await frames(2)
	await snap()
	sheet("snow", 4)
	ground.snow = false


## One step, from close by, frame after frame: the dent, and the sand pushed out round it.
func collar() -> void:
	cam.fov = 30.0
	follow = false
	var from := Vector3(-3.0, 0.0, -5.5)
	place(from.x - 2.5, from.z, Vector3(1, 0, 0))
	eye = from + Vector3(0.3, 1.1, 1.3)
	target = from
	await frames(20)
	# (walk until he is nearly at the place the camera looks at)
	var steps := 0
	while player.global_position.x < from.x - 0.75 and steps < 400:
		await frames(1, Vector3(0.5, 0, 0))
		steps += 1
	await shots("collar", 12, 4, Vector3(0.5, 0, 0), 4)
	stop()


## A run past the camera, every other frame: the sand his feet throw up.
func spray() -> void:
	cam.fov = 30.0
	follow = false
	var from := Vector3(3.0, 0.0, -7.0)
	place(from.x - 7.0, from.z, Vector3(1, 0, 0))
	eye = from + Vector3(0.6, 0.55, 2.6)
	target = from + Vector3(0.2, 0.25, 0.0)
	await frames(20)
	var steps := 0
	while player.global_position.x < from.x - 1.0 and steps < 400:
		await frames(1, Vector3(1, 0, 0))
		steps += 1
	await shots("spray", 16, 2, Vector3(1, 0, 0), 4)
	stop()
	# And as the game shows it: the camera eleven metres off.
	place(from.x - 7.0, from.z - 2.0, Vector3(1, 0, 0))
	follow = true
	eye = Vector3(0.0, 2.2, 10.5)
	target = Vector3(0.0, 0.7, 0.0)
	await frames(20)
	await frames(60, Vector3(1, 0, 0))
	await shots("spray_far", 8, 3, Vector3(1, 0, 0), 4)
	follow = false
	stop()


## A jump on the spot, and the landing: a ring of sand.
func land() -> void:
	cam.fov = 30.0
	follow = false
	var from := Vector3(-2.0, 0.0, -3.5)
	place(from.x, from.z, Vector3(0, 0, 1))
	eye = from + Vector3(0.8, 0.7, 3.0)
	target = from + Vector3(0.0, 0.3, 0.0)
	await frames(30)
	touch.jump_held = true
	player._queue_jump()
	await frames(14)
	touch.jump_held = false
	var steps := 0
	while not player.is_on_floor() and steps < 200:
		await frames(1)
		steps += 1
	await snap()
	await shots("land", 11, 2, Vector3.INF, 4)


## Finds a steep face near the yard: a place where the ground runs steeply
## down for some way. Gives back where, and which way is downhill.
func steep_face() -> Array:
	var best := Vector3.ZERO
	var best_way := Vector3.ZERO
	var best_score := -1.0
	for z in range(-70, 71, 2):
		for x in range(-70, 71, 2):
			var facing := ground.normal_at(x, z)
			var steep := sqrt(maxf(1.0 - facing.y * facing.y, 0.0)) / maxf(facing.y, 0.01)
			if steep < 0.5:
				continue
			var way := Vector3(facing.x, 0.0, facing.z).normalized()
			# (still steep three metres further down, and a metre up)
			var down := ground.normal_at(x + way.x * 3.0, z + way.z * 3.0)
			var up := ground.normal_at(x - way.x * 1.0, z - way.z * 1.0)
			if down.y > 0.9 or up.y > 0.92:
				continue
			var score := steep - Vector2(x, z).length() * 0.004
			if score > best_score:
				best_score = score
				best = Vector3(x, ground.height_at(x, z), z)
				best_way = way
	return [best, best_way]


## He walks across a steep face, and the sand lets go under him: from the
## side, every few frames, and afterwards from above.
func ooze() -> void:
	var found := steep_face()
	var face: Vector3 = found[0]
	var way: Vector3 = found[1]
	var across := Vector3(way.z, 0.0, -way.x)
	var facing := ground.normal_at(face.x, face.z)
	print("  steep face at ", face, " downhill ", way, " slope ", sqrt(1.0 - facing.y * facing.y) / facing.y)
	cam.fov = 30.0
	follow = false
	var start := face - across * 2.2
	place(start.x, start.z, across)
	# (looking up the slope at it from below and a little to one side)
	eye = face + way * 3.4 + across * 0.5 + Vector3.UP * 0.6
	eye.y = ground.height_at(eye.x, eye.z) + 1.5
	target = face + way * 0.7
	target.y = ground.height_at(target.x, target.z)
	await frames(15)
	await snap()
	for i in 11:
		await frames(12, across * 0.5)
		await snap()
	stop()
	sheet("ooze", 4)
	# What he has left, as it goes on creeping and comes to rest.
	await shots("ooze_after", 8, 20, Vector3.INF, 4)
	# Nearer, and from above: he goes straight down it.
	start = face - way * 0.8 + across * 3.0
	place(start.x, start.z, way)
	target = start + way * 2.0
	target.y = ground.height_at(target.x, target.z)
	eye = start + way * 4.6 + across * 1.2
	eye.y = ground.height_at(eye.x, eye.z) + 2.2
	await frames(15)
	await shots("ooze_near", 6, 8, way * 0.45, 4)
	stop()
	await shots("ooze_near2", 10, 12, Vector3.INF, 4)
	# As the game shows it.
	start = face - across * 3.0 + way * 1.5
	place(start.x, start.z, across)
	follow = true
	eye = way * 10.5 + Vector3.UP * 3.0
	target = Vector3.UP * 0.6
	await frames(15)
	await shots("ooze_far", 8, 15, across * 0.6, 4)
	stop()
	follow = false


## He runs at the face and slides down it.
func slide() -> void:
	var found := steep_face()
	var face: Vector3 = found[0]
	var way: Vector3 = found[1]
	var across := Vector3(way.z, 0.0, -way.x)
	cam.fov = 30.0
	var start := face - way * 1.5 - across * 5.0
	place(start.x, start.z, way)
	follow = true
	eye = way * 3.2 + across * 1.2 + Vector3.UP * 1.5
	target = way * 0.6
	await frames(15)
	await frames(25, way)
	touch.duck_held = true
	await shots("slide", 12, 5, way, 4)
	stop()
	follow = false
