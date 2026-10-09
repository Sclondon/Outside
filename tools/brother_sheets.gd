extends SceneTree
## Not part of the game. A test stage for the brother's own moves (scripts/brother.gd,
## scripts/brother_rig.gd): throws each blow, braces him, and has a real Player climb
## onto his back and be thrown up a wall, saving contact sheets of it all and printing
## what was hit and how high the boy got.
## godot --path . --fixed-fps 60 --resolution 960x960 --script tools/brother_sheets.gd -- <outdir> [scenario ...]
## Scenarios: guard hook_l hook_r uppercut kick combo hits brace heights boost duck plain. None named: all of them.
## Its window is kept off the screen and takes no input.

const CELL := 320
## The wall he is boosted up: its face at z = 20, its top this high.
const WALL_TOP := 3.7

var out := ""
var only: Array = []
var stage: Node3D
var player: Player
var brother: Brother
var cam: Camera3D
var touch: TouchControls
var cells: Array[Image] = []
## Who the camera is on, and how: yaw round them (0: from straight in front), pitch, distance.
var subject: Node3D
var view := Vector3(0.6, 0.12, 4.2)
var look_h := 0.85
var pin := Vector3.INF
var pin_yaw := 0.0


func _initialize() -> void:
	DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_NO_FOCUS, true)
	DisplayServer.window_set_position(Vector2i(-6000, -6000))
	var args := OS.get_cmdline_user_args()
	out = args[0]
	only = args.slice(1)
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
	box(Vector3(0, -1, 0), Vector3(200, 2, 200), Color(0.3, 0.32, 0.34))
	# The wall to be boosted up, and another just like it far enough off to try alone
	box(Vector3(0, WALL_TOP * 0.5, 23), Vector3(12, WALL_TOP, 6), Color(0.42, 0.44, 0.47))
	box(Vector3(40, WALL_TOP * 0.5, 23), Vector3(12, WALL_TOP, 6), Color(0.42, 0.44, 0.47))

	touch = TouchControls.new()
	touch.visible = false
	stage.add_child(touch)
	touch.set_process_input(false)
	player = load("res://player.tscn").instantiate()
	player.position = Vector3(0, 0.05, -30)
	stage.add_child(player)
	player.set_process_unhandled_input(false)
	brother = Brother.new()
	brother.position = Vector3(0, 0.02, 0)
	stage.add_child(brother)
	brother.blow_landed.connect(func(blow: StringName, hit: Array[Node3D]) -> void:
		print("BLOW ", blow, " landed on ", hit.map(func(body: Node3D) -> String: return String(body.name))))
	brother.braced.connect(func() -> void: print("BRACED at ", brother.global_position, " facing ", snappedf(brother.facing_yaw, 0.01)))
	brother.boosted.connect(func(who: Node3D) -> void: print("BOOSTED ", who.name, " upward speed ", snappedf(player.velocity.y, 0.01)))
	unbind()
	cam = Camera3D.new()
	cam.fov = 30.0
	stage.add_child(cam)
	cam.make_current()
	subject = brother
	run.call_deferred()


## A gamepad is heard whether the window has the focus or not, and someone may be
## playing: every action of the game's is left with nothing bound to it.
func unbind() -> void:
	for action: StringName in InputMap.get_actions():
		if not String(action).begins_with("ui_"):
			InputMap.action_erase_events(action)
			Input.action_release(action)


func box(at: Vector3, size: Vector3, color: Color) -> StaticBody3D:
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
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = 1.0
	visual.material_override = material
	body.add_child(visual)
	body.position = at
	stage.add_child(body)
	return body


func aim() -> void:
	var yaw: float = (pin_yaw if pin != Vector3.INF else subject.facing_yaw) + view.x
	var away := Vector3(sin(yaw) * cos(view.y), sin(view.y), cos(yaw) * cos(view.y))
	var watch: Vector3 = subject.visual_position + Vector3.UP * look_h
	if pin != Vector3.INF:
		watch = pin
	cam.global_position = watch + away * view.z
	cam.look_at(watch)


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


func snap() -> void:
	aim()
	await RenderingServer.frame_post_draw
	var image := root.get_texture().get_image()
	var side: int = mini(image.get_width(), image.get_height())
	image = image.get_region(Rect2i((image.get_width() - side) / 2, (image.get_height() - side) / 2, side, side))
	image.resize(CELL, CELL, Image.INTERPOLATE_LANCZOS)
	cells.append(image)


func sheet(name: String, columns := 6) -> void:
	var rows := ceili(cells.size() / float(columns))
	var page := Image.create(CELL * columns, CELL * rows, false, cells[0].get_format())
	page.fill(Color(0.2, 0.2, 0.2))
	for i in cells.size():
		page.blit_rect(cells[i], Rect2i(0, 0, CELL, CELL), Vector2i((i % columns) * CELL, (i / columns) * CELL))
	page.save_png(out.path_join(name + ".png"))
	cells.clear()
	print("SHEET ", name)


func put_player(at: Vector3, yaw: float) -> void:
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


## Stands the brother somewhere, doing nothing, following nobody.
func put_brother(at: Vector3, yaw: float) -> void:
	brother.follow(null)
	brother.stand()
	brother._set_back(false)
	brother.doing = Brother.Doing.FOLLOWING
	brother._blow = -1
	brother._patience = 0.0
	brother.place(at, yaw)


func wants(name: String) -> bool:
	return only.is_empty() or name in only


func run() -> void:
	unbind()
	await frames(5)
	for name: String in ["guard", "hook_l", "hook_r", "uppercut", "kick", "combo", "hits", "brace", "heights", "boost", "duck", "plain"]:
		if wants(name):
			await call(name)
	quit()


func guard() -> void:
	subject = brother
	put_brother(Vector3.ZERO, 0.0)
	await frames(40)
	brother._throw(0)
	await frames(50)
	for yaw: float in [0.0, 0.7, PI * 0.5, PI - 0.6, -PI * 0.5, -0.7]:
		brother._rested = 0.0
		view = Vector3(yaw, 0.08, 4.0)
		await frames(2)
		await snap()
	sheet("guard", 6)


## One blow, every `every` frames, from his side and from three quarters in front.
func blow(name: String, index: int, every: int, side: float) -> void:
	subject = brother
	for round in 2:
		put_brother(Vector3.ZERO, 0.0)
		view = Vector3(side, 0.05, 3.5) if round == 0 else Vector3(0.65 * signf(side), 0.12, 3.5)
		# (from his guard, as it is in a combo)
		brother._throw(0)
		await frames(70)
		brother._throw(index)
		var count := ceili(BrotherRig.TAKES[index] * 60.0 / every) + 1
		for i in count:
			await snap()
			await frames(every)
		sheet(name + ("_side" if round == 0 else "_front"), 6)
		await frames(70)


func hook_l() -> void:
	await blow("hook_l", 0, 2, PI * 0.5)


func hook_r() -> void:
	await blow("hook_r", 1, 2, -PI * 0.5)


func uppercut() -> void:
	await blow("uppercut", 2, 2, PI * 0.5)


func kick() -> void:
	await blow("kick", 3, 3, -PI * 0.5)


func combo() -> void:
	subject = brother
	for round in 2:
		put_brother(Vector3.ZERO, 0.0)
		view = Vector3(PI * 0.5, 0.05, 4.4) if round == 0 else Vector3(0.65, 0.12, 4.4)
		await frames(60)
		# From standing, as it would be in play: punch, and punch again as each lands.
		brother.punch()
		var thrown := 1
		var was := 0
		for i in 48:
			await snap()
			await frames(3)
			if brother._blow != was and brother._blow >= 0:
				was = brother._blow
			if thrown < 4 and brother._blow == thrown - 1 and brother._landed:
				brother.punch()
				thrown += 1
		sheet("combo_side" if round == 0 else "combo_front", 8)
		await frames(80)


## Something loose and something that answers, in front of him: what each blow does to them.
func hits() -> void:
	subject = brother
	put_brother(Vector3(0, 0.02, -60), 0.0)
	var answering := GDScript.new()
	answering.source_code = "extends StaticBody3D\nfunc struck(by: Node3D, impulse: Vector3) -> void:\n\tprint(\"STRUCK \", name, \" by \", by.name, \" impulse \", impulse.snapped(Vector3.ONE * 0.1))\n"
	answering.reload()
	var post := box(Vector3(0.25, 0.7, -59.25), Vector3(0.2, 1.4, 0.2), Color(0.5, 0.3, 0.2))
	post.name = "Post"
	post.set_script(answering)
	post.add_to_group(&"pursuers")
	view = Vector3(-0.9, 0.15, 5.0)
	var thrown := 0
	for round in 2:
		var crate := RigidBody3D.new()
		crate.name = "Crate"
		crate.mass = 4.0
		var shape := BoxShape3D.new()
		shape.size = Vector3.ONE * 0.3
		var collider := CollisionShape3D.new()
		collider.shape = shape
		crate.add_child(collider)
		var mesh := BoxMesh.new()
		mesh.size = shape.size
		var visual := MeshInstance3D.new()
		visual.mesh = mesh
		crate.add_child(visual)
		var stand := box(Vector3(-0.2, 0.4 if round == 0 else 0.2, -59.3), Vector3(0.3, 0.8 if round == 0 else 0.4, 0.3), Color(0.35, 0.35, 0.38))
		crate.position = Vector3(-0.2, 0.96 if round == 0 else 0.56, -59.3)
		stage.add_child(crate)
		await frames(40)
		var from := crate.global_position
		if round == 0:
			brother.punch()
		else:
			brother.kick()
		for i in 6:
			await frames(8)
			await snap()
		print("HITS ", "punch" if round == 0 else "kick", ": crate went ", (crate.global_position - from).snapped(Vector3.ONE * 0.01), " and is moving at ", crate.linear_velocity.snapped(Vector3.ONE * 0.01))
		await frames(60)
		crate.queue_free()
		stand.queue_free()
		thrown += 1
	sheet("hits", 6)
	post.queue_free()


func brace() -> void:
	subject = brother
	put_brother(Vector3.ZERO, 0.0)
	put_player(Vector3(0, 0.05, -30), 0.0)
	await frames(30)
	brother.brace()
	look_h = 0.6
	view = Vector3(PI * 0.5, 0.05, 4.0)
	for i in 6:
		await snap()
		await frames(5)
	await frames(40)
	for v: Vector3 in [Vector3(PI * 0.5, 0.05, 4.0), Vector3(0.0, 0.1, 4.0), Vector3(PI, 0.1, 4.0), Vector3(0.6, 0.3, 4.0), Vector3(PI - 0.5, 0.45, 4.6)]:
		view = v
		await frames(2)
		await snap()
	print("BRACE braced=", brother.is_braced(), " rig back at ", snappedf((brother.rig as BrotherRig).back_height(), 0.001), " m, collider top at ", brother.back_height,
		"; hips ", brother.rig._hips.global_position.snapped(Vector3.ONE * 0.001), " chest ", brother.rig._chest.global_position.snapped(Vector3.ONE * 0.001),
		" head ", brother.rig._head.global_position.snapped(Vector3.ONE * 0.001))
	# With the boy on it
	brother.follow(player)
	put_player(Vector3(0, brother.back_height + 0.02, Brother.BACK_AHEAD), 0.0)
	await frames(40)
	for v: Vector3 in [Vector3(PI * 0.5, 0.05, 5.0), Vector3(0.6, 0.2, 5.0), Vector3(PI - 0.5, 0.45, 5.4)]:
		view = v
		look_h = 0.9
		await frames(2)
		await snap()
	print("BRACE boy on his back at ", player.global_position.snapped(Vector3.ONE * 0.001), " on floor=", player.is_on_floor(), " burdened=", (brother.rig as BrotherRig).burdened)
	sheet("brace", 6)
	look_h = 0.85
	brother.stand()
	put_player(Vector3(0, 0.05, -30), 0.0)
	await frames(60)


## Jumps the Player where he stands, the jump held, and returns how high his feet got above `ground`.
func jump_up(ground: float, count := 80) -> float:
	var top := 0.0
	touch.jump_held = true
	player._queue_jump()
	for i in count:
		await frames(1)
		top = maxf(top, player.global_position.y - ground)
	touch.jump_held = false
	return top


## How high he gets: off the ground, off the brother's back with no heave, and with it.
func heights() -> void:
	subject = brother
	put_brother(Vector3.ZERO, 0.0)
	put_player(Vector3(6, 0.05, 0), 0.0)
	await frames(30)
	var plain := await jump_up(0.0)
	var results := [plain]
	for boost: float in [0.0, 1.2]:
		put_brother(Vector3.ZERO, 0.0)
		put_player(Vector3(6, 0.05, 0), 0.0)
		brother.boost_height = boost
		brother.follow(player)
		brother.brace()
		await frames(50)
		put_player(Vector3(0, brother.back_height + 0.02, Brother.BACK_AHEAD), 0.0)
		await frames(30)
		results.append(await jump_up(0.0))
		await frames(60)
	brother.boost_height = 1.2
	print("HEIGHTS feet got to: plain jump from the ground ", snappedf(results[0], 0.01), " m; from his back without the heave ", snappedf(results[1], 0.01),
		" m; from his back with it ", snappedf(results[2], 0.01), " m (", snappedf(results[2] - results[0], 0.01), " m more than a plain jump)")
	put_player(Vector3(0, 0.05, -30), 0.0)


## The whole of it, unasked: the boy stands in front of a wall too high for him, the
## brother comes and braces at the foot of it, and the boy is driven onto his back and up.
func boost() -> void:
	await up_the_wall("boost", 0.0, false)


## The same, but called over by ducking, out in the open; then up from there.
func duck() -> void:
	subject = brother
	put_brother(Vector3(-2.5, 0.02, -2.0), 0.0)
	put_player(Vector3(0, 0.05, 0), 0.0)
	brother.follow(player)
	view = Vector3(0.7, 0.25, 7.0)
	pin = Vector3(0, 0.8, 0.5)
	await frames(60)
	touch.duck_held = true
	for i in 12:
		await frames(12)
		await snap()
	print("DUCK brother doing=", Brother.Doing.keys()[brother.doing], " braced=", brother.is_braced(), " at ", brother.global_position.snapped(Vector3.ONE * 0.01), " facing ", snappedf(brother.facing_yaw, 0.01))
	touch.duck_held = false
	sheet("duck", 6)
	pin = Vector3.INF
	put_player(Vector3(0, 0.05, -30), 0.0)
	await frames(30)


## A plain jump at the same wall with nobody to help: he should not get up it.
func plain() -> void:
	put_brother(Vector3(0, 0.02, -60), 0.0)
	put_player(Vector3(40, 0.05, 18.6), 0.0)
	await frames(20)
	var top := 0.0
	touch.jump_held = true
	player._queue_jump()
	for i in 90:
		await frames(1, Vector3(0, 0, 1))
		top = maxf(top, player.global_position.y)
	touch.jump_held = false
	touch.move = Vector2.ZERO
	print("PLAIN at a ", WALL_TOP, " m wall alone: feet got to ", snappedf(top, 0.01), " m, state ", Player.State.keys()[player.state], " (HANG would mean he caught it)")
	put_player(Vector3(0, 0.05, -30), 0.0)


func up_the_wall(name: String, x: float, _unused: bool) -> void:
	subject = player
	put_brother(Vector3(x - 2.5, 0.02, 15.5), 0.0)
	put_player(Vector3(x, 0.05, 18.3), 0.0)
	brother.follow(player)
	pin = Vector3(x, 1.7, 19.2)
	pin_yaw = 0.0
	view = Vector3(-PI * 0.5 - 0.45, 0.12, 11.0)
	# He stands and looks at it; the brother comes over.
	var waited := 0
	while waited < 420 and not brother.is_braced():
		await frames(1)
		if waited % 14 == 0 and cells.size() < 12:
			await snap()
		waited += 1
	print("BOOST brother ", "braced" if brother.is_braced() else "NOT braced", " after ", waited, " frames, at ", brother.global_position.snapped(Vector3.ONE * 0.01), " facing ", snappedf(brother.facing_yaw, 0.01), " doing ", Brother.Doing.keys()[brother.doing])
	await frames(20)
	await snap()
	sheet(name + "_come", 6)
	# Onto his back: a jump at him, and a climb if he catches the edge of it.
	touch.jump_held = true
	player._queue_jump()
	var on_back := false
	for i in 200:
		await frames(1, Vector3(0, 0, 1))
		if player.state == Player.State.HANG and i % 20 == 10:
			player._queue_jump()
		if i % 6 == 0 and cells.size() < 11:
			await snap()
		if player.state == Player.State.FREE and player.is_on_floor() and player.global_position.y > brother.back_height - 0.1:
			on_back = true
			break
	touch.jump_held = false
	touch.move = Vector2.ZERO
	await frames(25)
	await snap()
	print("BOOST boy ", "is on his back" if on_back else "did NOT get onto his back", " at ", player.global_position.snapped(Vector3.ONE * 0.01), " state ", Player.State.keys()[player.state])
	sheet(name + "_mount", 6)
	# And up.
	var top := 0.0
	touch.jump_held = true
	player._queue_jump()
	var caught := -1
	for i in 150:
		await frames(1, Vector3(0, 0, 1))
		top = maxf(top, player.global_position.y)
		if player.state == Player.State.HANG and caught < 0:
			caught = i
			touch.jump_held = false
		if caught >= 0 and i == caught + 20:
			player._queue_jump()
		if i % 4 == 0 and cells.size() < 30:
			await snap()
	touch.jump_held = false
	touch.move = Vector2.ZERO
	await frames(10)
	print("BOOST feet got to ", snappedf(top, 0.01), " m; ", "caught the top of the wall after %d frames" % caught if caught >= 0 else "did NOT catch the wall",
		"; he ends at ", player.global_position.snapped(Vector3.ONE * 0.01), " (wall top ", WALL_TOP, ") state ", Player.State.keys()[player.state],
		"; brother doing ", Brother.Doing.keys()[brother.doing], " facing ", snappedf(brother.facing_yaw, 0.01))
	sheet(name + "_up", 6)
	# The brother, close, through the heave
	subject = brother
	pin = Vector3.INF
	put_player(Vector3(x, 0.05, 18.3), 0.0)
	put_brother(Vector3(x, 0.02, 19.52), PI)
	brother.follow(player)
	brother.brace()
	await frames(50)
	put_player(Vector3(x, brother.back_height + 0.02, 19.52 - Brother.BACK_AHEAD), 0.0)
	await frames(30)
	pin = Vector3(x, 1.2, 19.4)
	view = Vector3(-PI * 0.5 - 0.5, 0.1, 6.0)
	touch.jump_held = true
	player._queue_jump()
	for i in 24:
		await snap()
		await frames(3, Vector3(0, 0, 1))
		if player.state == Player.State.HANG:
			touch.jump_held = false
	touch.jump_held = false
	touch.move = Vector2.ZERO
	sheet(name + "_heave", 6)
	pin = Vector3.INF
	put_player(Vector3(0, 0.05, -30), 0.0)
	put_brother(Vector3.ZERO, 0.0)
	await frames(30)
