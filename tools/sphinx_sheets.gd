extends SceneTree
## Not part of the game. Pictures of the sphinx: each head from all round and close to; every size beside the boy,
## from where the game's camera sees it; weathered and painted; what it does, as strips of consecutive moments (it
## wakes when he comes between its paws, it is given the right thing, it is given a wrong one, it opens, it strikes,
## the sand goes down from it); by torchlight in the dark; and its station in the test yard.
## godot --path . --fixed-fps 60 --resolution 960x960 --script tools/sphinx_sheets.gd -- <outdir> [heads faces sizes wear wake right wrong opens wrath buried night yard] [banded]
## `banded` lights the world in hard bands, as the menu can. Add `--rendering-method gl_compatibility` to see it as the web draws it.

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
var tag := ""


func _initialize() -> void:
	DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_NO_FOCUS, true)
	DisplayServer.window_set_position(Vector2i(-6000, -6000))
	var args := OS.get_cmdline_user_args()
	out = args[0]
	for i in range(1, args.size()):
		names.append(args[i])
	if names.has("banded"):
		names.erase("banded")
		Settings.world_banded = true
	tag = "%s%s" % ["_banded" if Settings.world_banded else "", "_web" if RenderingServer.get_current_rendering_method() == "gl_compatibility" else ""]
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
	page.save_png(out.path_join(name + tag + ".png"))
	cells.clear()
	print("SHEET ", name + tag)


func frames(count: int) -> void:
	for i in count:
		await physics_frame
		await process_frame


func light(day: bool) -> void:
	world.environment.background_color = Color(0.56, 0.68, 0.82) if day else Color(0.015, 0.017, 0.025)
	world.environment.ambient_light_energy = 0.7 if day else 0.05
	# (the web's renderer makes a sun that casts shadows much too bright: the levels turn it down, and so does this)
	sun.light_energy = (1.2 if day else 0.0) * (0.3 if RenderingServer.get_current_rendering_method() == "gl_compatibility" else 1.0)


func look(from: Vector3, at: Vector3, fov := 45.0) -> void:
	cam.global_position = from
	cam.look_at(at)
	cam.fov = fov


func box(at: Vector3, size: Vector3, colour: Color) -> Node3D:
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


func put(at: Vector3, facing := 0.0) -> void:
	touch.move = Vector2.ZERO
	if player.carried:
		player._let_go()
	player.global_position = at
	player.velocity = Vector3.ZERO
	player.facing_yaw = facing


func sphinx_at(at: Vector3, size := 6.0, head := Sphinx.Head.KING, more := {}) -> Sphinx:
	var made := Sphinx.new()
	made.size = size
	made.head = head
	made.voice = false
	for key: String in more:
		made.set(key, more[key])
	made.position = at
	stage.add_child(made)
	return made


## Something to give it, lying at a place.
func thing(what: String, at: Vector3) -> RigidBody3D:
	var made: RigidBody3D
	match what:
		"torch":
			made = HandTorch.new()
		"cold_torch":
			made = HandTorch.new()
			(made as HandTorch).lit = false
		"amulet":
			made = ScarabAmulet.new()
		"key":
			made = DoorKey.new()
			(made as DoorKey).which = DoorKey.Metal.GOLD
		_:
			made = (load("res://props/%s.tscn" % what) as PackedScene).instantiate() as RigidBody3D
	made.position = at
	stage.add_child(made)
	return made


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
	sun.rotation_degrees = Vector3(-40.0, 38.0, 0.0)
	sun.shadow_enabled = true
	stage.add_child(sun)
	box(Vector3(0, -1, 0), Vector3(400, 2, 400), Color(0.78, 0.68, 0.48))
	cam = Camera3D.new()
	stage.add_child(cam)
	cam.make_current()
	light(true)
	touch = TouchControls.new()
	touch.visible = false
	stage.add_child(touch)
	touch.set_process_input(false)
	player = load("res://player.tscn").instantiate()
	player.position = Vector3(150.0, 0.05, 150.0)
	player.rest_enabled = false
	stage.add_child(player)
	player.set_process_unhandled_input(false)
	for action: StringName in InputMap.get_actions():
		if not String(action).begins_with("ui_"):
			InputMap.action_erase_events(action)
	await frames(20)

	if wanted("heads"):
		await heads()
	if wanted("faces"):
		await faces()
	if wanted("sizes"):
		await sizes()
	if wanted("wear"):
		await worn()
	if wanted("wake"):
		await wake()
	if wanted("right"):
		await right()
	if wanted("wrong"):
		await wrong()
	if wanted("opens"):
		await opens()
	if wanted("wrath"):
		await wrath()
	if wanted("buried"):
		await sand()
	if wanted("night"):
		await night()
	if wanted("yard"):
		await yard()
	quit()


## Each head from all round: front, three quarters, side, behind, the other three quarters, and from above.
func heads() -> void:
	for head: int in [Sphinx.Head.KING, Sphinx.Head.RAM, Sphinx.Head.FALCON]:
		var one := sphinx_at(Vector3(-100, 0, -100), 6.0, head, {"wear": 0.15})
		await frames(4)
		var middle := Vector3(-100, 1.3, -100)
		for view: Vector3 in [Vector3(0, 0.4, 8.0), Vector3(5.6, 1.6, 5.6), Vector3(8.0, 0.5, 0.3), Vector3(-5.0, 2.0, -6.0), Vector3(-6.0, 0.9, 5.0), Vector3(1.5, 9.0, 3.0)]:
			look(middle + view, middle)
			await frames(2)
			await snap()
		one.queue_free()
		await frames(2)
	sheet("heads", 6)


## Each head close to, from the front and from the side; asleep, and with its eyes open.
func faces() -> void:
	for head: int in [Sphinx.Head.KING, Sphinx.Head.RAM, Sphinx.Head.FALCON]:
		var one := sphinx_at(Vector3(-100, 0, -60), 6.0, head, {"wear": 0.15})
		await frames(4)
		var face := Vector3(-100, 2.5, -59.3)
		for open: bool in [false, true]:
			one.awake = open
			one._awake_for = 100.0 if open else 0.0
			await frames(60)
			for view: Vector3 in [Vector3(0, 0.1, 3.4), Vector3(2.4, 0.5, 2.6), Vector3(3.6, 0.2, 0.0)]:
				look(face + view, face, 40.0)
				await frames(2)
				await snap()
		one.queue_free()
		await frames(2)
	sheet("faces", 6)


## Every size, the boy beside its paws, seen from where the camera that follows him is.
func sizes() -> void:
	for size: float in [2.5, 4.0, 6.0, 9.0, 12.0, 18.0]:
		var one := sphinx_at(Vector3(-100, 0, 0), size, Sphinx.Head.KING, {"wear": 0.3})
		put(Vector3(-100 + size * 0.3 + 0.8, 0.05, size * 0.5 + 1.2), PI)
		await frames(30)
		# (the orbit camera stands 6 m behind him and looks from a little above)
		look(player.global_position + Vector3(2.2, 2.6, 5.4), player.global_position + Vector3(-0.6, 0.9, -1.0), 55.0)
		await frames(2)
		await snap()
		one.queue_free()
		await frames(2)
	for head: int in [Sphinx.Head.RAM, Sphinx.Head.FALCON]:
		for size: float in [2.5, 6.0, 12.0]:
			var one := sphinx_at(Vector3(-100, 0, 0), size, head, {"wear": 0.3})
			put(Vector3(-100 + size * 0.3 + 0.8, 0.05, size * 0.5 + 1.2), PI)
			await frames(30)
			look(player.global_position + Vector3(2.2, 2.6, 5.4), player.global_position + Vector3(-0.6, 0.9, -1.0), 55.0)
			await frames(2)
			await snap()
			one.queue_free()
			await frames(2)
	put(Vector3(150.0, 0.05, 150.0))
	sheet("sizes", 6)


## Crisp to weathered, bare and painted; and the stones.
func worn() -> void:
	for painted: bool in [false, true]:
		for wear: float in [0.0, 0.3, 0.6, 1.0]:
			var one := sphinx_at(Vector3(-100, 0, 60), 6.0, Sphinx.Head.KING, {"wear": wear, "painted": painted})
			await frames(4)
			look(Vector3(-100 + 4.6, 2.9, 60 + 7.4), Vector3(-100, 1.5, 60.6))
			await frames(2)
			await snap()
			one.queue_free()
			await frames(2)
	for head: int in [Sphinx.Head.RAM, Sphinx.Head.FALCON]:
		for painted: bool in [false, true]:
			var one := sphinx_at(Vector3(-100, 0, 60), 6.0, head, {"wear": 0.1, "painted": painted})
			await frames(4)
			look(Vector3(-100 + 4.6, 2.9, 60 + 7.4), Vector3(-100, 1.5, 60.6))
			await frames(2)
			await snap()
			one.queue_free()
			await frames(2)
	sheet("wear", 4)


## He walks in between its paws: its eyes open, its head comes round and down to him, dust falls from its neck, and its riddle is put up.
func wake() -> void:
	var one := sphinx_at(Vector3(0, 0, -100), 9.0, Sphinx.Head.KING, {"wants": 0})
	put(Vector3(0.6, 0.05, -100 + 9.5), PI)
	await frames(20)
	look(Vector3(4.2, 2.3, -100 + 11.5), Vector3(0, 2.2, -100 + 2.5), 50.0)
	await snap()
	for i in 7:
		if i < 3:
			# (he comes in between the paws)
			player.global_position = Vector3(0.1, 0.3, -100 + [7.0, 5.2, 3.9][i])
			player.velocity = Vector3.ZERO
		await frames(16)
		await snap()
	one.queue_free()
	put(Vector3(150.0, 0.05, 150.0))
	await frames(2)
	sheet("wake", 4)


## The right thing put down between its paws: it is taken onto the slab, the eyes blaze, and it stays there.
func right() -> void:
	var one := sphinx_at(Vector3(40, 0, -100), 6.0, Sphinx.Head.KING, {"wants": 2})
	var amulet := thing("amulet", Vector3(40.2, 0.4, -100 + 4.2))
	put(Vector3(40.5, 0.05, -100 + 4.6), PI)
	look(Vector3(43.4, 2.2, -100 + 7.4), Vector3(40, 1.3, -100 + 1.6), 50.0)
	await frames(30)
	await snap()
	player._take(amulet)
	put_holding(Vector3(40.0, 0.05, -100 + 3.5), PI)
	await frames(40)
	await snap()
	player._let_go()
	for i in 6:
		await frames(12 if i < 4 else 30)
		await snap()
	print("right: on %s kept %s" % [one.on, one.kept == amulet])
	one.queue_free()
	amulet.queue_free()
	put(Vector3(150.0, 0.05, 150.0))
	await frames(2)
	sheet("right", 4)


## A wrong thing: the eyes go red, the head shakes, and the paw comes across and knocks it out onto the sand.
func wrong() -> void:
	var one := sphinx_at(Vector3(80, 0, -100), 6.0, Sphinx.Head.KING, {"wants": 2})
	var jar := thing("jar_canopic", Vector3(80.0, 0.6, -100 + 3.4))
	put(Vector3(80.6, 0.05, -100 + 4.4), PI)
	look(Vector3(83.6, 2.4, -100 + 8.0), Vector3(79.4, 1.2, -100 + 2.0), 50.0)
	await frames(8)
	for i in 12:
		await frames(9)
		await snap()
	print("wrong: strikes %d, the jar is %.1f m from the slab" % [one.strikes, jar.global_position.distance_to(one.slab_place())])
	one.queue_free()
	jar.queue_free()
	put(Vector3(150.0, 0.05, 150.0))
	await frames(2)
	sheet("wrong", 4)


## One that opens itself: the stele goes down into the ground, and there is a way in through its chest.
func opens() -> void:
	var one := sphinx_at(Vector3(120, 0, -100), 12.0, Sphinx.Head.KING, {"wants": 5, "opens_itself": true})
	var key := thing("key", Vector3(120.0, 0.8, -100 + 4.0))
	put(Vector3(120.4, 0.3, -100 + 5.4), PI)
	look(Vector3(122.6, 2.2, -100 + 9.4), Vector3(120, 1.6, -100 + 2.0), 55.0)
	await frames(8)
	for i in 7:
		await frames(40)
		await snap()
	# And through it: from behind, him coming out under the tail.
	look(Vector3(123.0, 2.6, -100 - 11.0), Vector3(120, 1.2, -100 - 5.0), 55.0)
	put(Vector3(120.0, 0.3, -100 + 0.5), PI)
	touch.move = Vector2(0, 0)
	player.global_position = Vector3(120.0, 0.3, -100 - 4.0)
	await frames(30)
	await snap()
	one.queue_free()
	key.queue_free()
	put(Vector3(150.0, 0.05, 150.0))
	await frames(2)
	sheet("opens", 4)


## Wrathful, and given a third wrong thing: the paw is lifted and comes down.
func wrath() -> void:
	var one := sphinx_at(Vector3(160, 0, -100), 6.0, Sphinx.Head.RAM, {"wants": 2, "wrathful": true})
	one.strikes = 2
	var said := [0]
	one.caught.connect(func() -> void: said[0] += 1)
	var jar := thing("jar_canopic", Vector3(160.0, 0.6, -100 + 3.4))
	put(Vector3(160.8, 0.05, -100 + 4.6), PI)
	look(Vector3(164.0, 2.4, -100 + 8.4), Vector3(159.6, 1.3, -100 + 2.0), 50.0)
	await frames(100)
	for i in 8:
		await frames(8)
		await snap()
	print("wrath: caught %d" % said[0])
	one.queue_free()
	jar.queue_free()
	put(Vector3(150.0, 0.05, 150.0))
	await frames(2)
	sheet("wrath", 4)


## Buried to the neck, and the sand going down from it.
func sand() -> void:
	var one := sphinx_at(Vector3(0, 0, 100), 9.0, Sphinx.Head.KING, {"buried": 1.0, "wear": 0.6})
	put(Vector3(5.5, 0.05, 100 + 9.0), PI)
	await frames(30)
	look(Vector3(9.0, 4.2, 100 + 14.0), Vector3(0, 1.8, 100 + 1.0), 50.0)
	await snap()
	one.uncovering = true
	for i in 7:
		await frames(70)
		await snap()
	one.queue_free()
	put(Vector3(150.0, 0.05, 150.0))
	await frames(2)
	sheet("buried", 4)


## In the dark, by the torch in his hand: asleep, and awake.
func night() -> void:
	light(false)
	for head: int in [Sphinx.Head.KING, Sphinx.Head.RAM, Sphinx.Head.FALCON]:
		var one := sphinx_at(Vector3(60, 0, 100), 6.0, head, {"wants": 2})
		var torch := thing("torch", Vector3(64.0, 0.3, 100 + 6.0))
		put(Vector3(63.6, 0.05, 100 + 6.0), PI * 0.5)
		await frames(30)
		player._act()
		await frames(50)
		put(Vector3(62.2, 0.05, 100 + 4.6), PI)
		player._take(torch)
		await frames(40)
		look(Vector3(63.5, 2.0, 100 + 8.4), Vector3(60, 1.5, 100 + 1.4), 50.0)
		await snap()
		put(Vector3(60.2, 0.05, 100 + 3.9), PI)
		player._take(torch)
		await frames(80)
		await snap()
		look(Vector3(61.4, 1.5, 100 + 6.2), Vector3(60, 2.2, 100 + 1.0), 45.0)
		await frames(4)
		await snap()
		player._let_go()
		one.queue_free()
		torch.queue_free()
		put(Vector3(150.0, 0.05, 150.0))
		await frames(4)
	light(true)
	sheet("night", 3)


## Its station in the test yard, with the game's own camera.
func yard() -> void:
	stage.queue_free()
	await frames(4)
	var scene: Node = load("res://test_yard.tscn").instantiate()
	root.add_child(scene)
	await frames(30)
	var boy := scene.get_node("Player") as Player
	var yard_touch := scene.get_node_or_null("TouchControls") as TouchControls
	var found: Array[Sphinx] = []
	for node: Node in scene.find_children("*", "StaticBody3D", true, false):
		if node is Sphinx:
			found.append(node)
	print("yard: %d sphinxes" % found.size())
	if found.is_empty():
		return
	var follow := scene.get_node_or_null("Camera") as FollowCamera
	for one in found:
		# From in front and to one side, looking at it; and from between its paws (or at them).
		var front := one.global_basis.z.normalized()
		var side := one.global_basis.x.normalized()
		for spot: Vector3 in [front * (one.size * 0.5 + 5.0) + side * (one.size * 0.25 + 1.5), front * (one.size * 0.5 + 0.3)]:
			boy.global_position = one.global_position + spot + Vector3.UP * 0.4
			boy.velocity = Vector3.ZERO
			boy.facing_yaw = atan2(-front.x, -front.z)
			await frames(5)
			if follow:
				follow.look_along(-front)
				follow.snap()
			await frames(70)
			await snap()
	if yard_touch:
		yard_touch.move = Vector2.ZERO
	sheet("yard", 4)


## Moves him with what he has in his hands.
func put_holding(at: Vector3, facing := 0.0) -> void:
	touch.move = Vector2.ZERO
	player.global_position = at
	player.velocity = Vector3.ZERO
	player.facing_yaw = facing
