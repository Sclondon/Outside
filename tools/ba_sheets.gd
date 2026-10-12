extends SceneTree
## Not part of the game. Pictures of the Ba: the model from all round, on its perch and with its wings out;
## at the distance the game sees it from, beside the boy; a flight, moment by moment; leading him round a
## wall; calling, and coming back for him; coming out of the air; sitting about shyly; in the dark, by its
## own light and by a torch; and its station in the test yard. Strips are consecutive moments, left to
## right and top to bottom.
## godot --path . --fixed-fps 60 --resolution 960x960 --script tools/ba_sheets.gd -- <outdir> [model wings far flight lead fetch appear shy dark show yard]

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
	world.environment.background_color = Color(0.5, 0.56, 0.62) if day else Color(0.015, 0.017, 0.025)
	world.environment.ambient_light_energy = 0.7 if day else 0.05
	sun.light_energy = 1.2 if day else 0.0


func look(from: Vector3, at: Vector3, fov := 45.0) -> void:
	cam.global_position = from
	cam.look_at(at)
	cam.fov = fov


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
	return body


func put(at: Vector3) -> void:
	touch.move = Vector2.ZERO
	player.global_position = at
	player.velocity = Vector3.ZERO
	if player.carried:
		player._let_go()


func ba_at(at: Vector3, route: Array[Vector3] = []) -> Ba:
	var ba := Ba.new()
	ba.voice = false
	ba.route = route
	ba.position = at
	stage.add_child(ba)
	ba.target = player
	return ba


## Holds a Ba still in a pose of the sheet's choosing: how far its wings are out, where in a beat, how it is tipped.
func hold(ba: Ba, spread: float, phase: float, beat: float, pitch: float, legs := 1.0) -> void:
	ba.set_process(false)
	ba.set_physics_process(false)
	ba._spread = spread
	ba._phase = phase
	ba._beat = beat
	ba._pitch = pitch
	ba._legs_out = legs
	ba._pose(0.0)


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
	box(Vector3(0, -1, 0), Vector3(200, 2, 200), Color(0.7, 0.62, 0.46))
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
	print("BA %d triangles" % BaMesh.triangles())

	if wanted("model"):
		await model()
	if wanted("wings"):
		await wings()
	if wanted("far"):
		await far()
	if wanted("flight"):
		await flight()
	if wanted("lead"):
		await lead()
	if wanted("fetch"):
		await fetch()
	if wanted("appear"):
		await appear()
	if wanted("shy"):
		await shy()
	if wanted("show"):
		await show()
	if wanted("dark"):
		await dark()
	if wanted("yard"):
		await yard()
	quit()


## On its perch, from all round, close to; and its face.
func model() -> void:
	put(Vector3(-40.0, 0.05, -33.0))
	var ba := ba_at(Vector3(-40.0, 0.0, -40.0))
	await frames(12)
	ba._heading = 0.0
	hold(ba, 0.0, 0.0, 0.0, Ba.UPRIGHT)
	var middle := ba.position + Vector3.UP * 0.28
	for turn: float in [0.0, 0.8, 1.57, 2.4, 3.14, 4.4]:
		look(middle + Vector3(sin(turn), 0.25, cos(turn)).normalized() * 1.25, middle, 32.0)
		await frames(2)
		await snap()
	look(middle + Vector3(0.25, 0.22, 0.6), middle + Vector3.UP * 0.17, 30.0)
	await frames(2)
	await snap()
	look(middle + Vector3(0.3, 1.1, 0.6), middle, 32.0)
	await frames(2)
	await snap()
	# (calling: wings half out, arms up)
	ba._arms_up = 1.0
	ba._calling = 1.0
	hold(ba, 0.8, 1.2, 0.45, Ba.UPRIGHT)
	ba._arms.visible = true
	ba._arms.global_basis = Basis.IDENTITY
	look(middle + Vector3(0.5, 0.3, 1.1), middle + Vector3.UP * 0.05, 32.0)
	await frames(2)
	await snap()
	sheet("model", 3)
	ba.queue_free()


## Its wings out, as it flies: from in front, above, the side and behind, at the top and the bottom of a beat, and gliding.
func wings() -> void:
	put(Vector3(-40.0, 0.05, -33.0))
	var ba := ba_at(Vector3(-40.0, 1.5, -40.0))
	await frames(12)
	ba._heading = 0.0
	var middle := ba.position + Vector3.UP * 0.25
	var shots := [[Vector3(0.0, 0.3, 1.6), PI * 0.5, 1.0], [Vector3(0.0, 0.3, 1.6), -PI * 0.5, 1.0], [Vector3(0.0, 0.2, 1.6), 0.0, 0.0],
			[Vector3(0.1, 1.7, 0.3), 0.0, 0.0], [Vector3(1.5, 0.5, 0.6), PI * 0.5, 0.62], [Vector3(1.5, 0.5, 0.6), -PI * 0.5, 0.62],
			[Vector3(1.6, 0.1, 0.0), 0.3, 0.62], [Vector3(-0.8, 0.6, -1.4), 0.0, 0.0], [Vector3(1.0, -0.5, 1.2), 0.9, 0.62]]
	for shot: Array in shots:
		hold(ba, 1.0, shot[1], shot[2], 0.0, 0.0)
		look(middle + shot[0], middle, 34.0)
		await frames(2)
		await snap()
	sheet("wings", 3)
	ba.queue_free()


## As the game sees it: beside the boy, from where the camera follows him, on the ground and on a block and in the air.
func far() -> void:
	put(Vector3(-20.0, 0.05, -40.0))
	var block := box(Vector3(-17.0, 0.5, -41.0), Vector3(1.0, 1.0, 1.0), Color(0.6, 0.54, 0.46))
	var ba := ba_at(Vector3(-18.6, 0.0, -40.0))
	var high := ba_at(Vector3(-17.0, 1.0, -41.0))
	var up := ba_at(Vector3(-21.5, 1.6, -40.5))
	await frames(30)
	hold(up, 1.0, 1.2, 0.62, 0.0, 0.0)
	for shot: Array in [[Vector3(0.0, 3.2, 11.0), 30.0], [Vector3(0.0, 2.0, 7.0), 30.0], [Vector3(5.0, 4.0, 14.0), 30.0]]:
		look(player.global_position + shot[0], player.global_position + Vector3(0.5, 0.8, 0.0), shot[1])
		await frames(3)
		await snap()
	sheet("far", 3)
	for thing: Node in [block, ba, high, up]:
		thing.queue_free()


## One flight, from a perch to a perch nine metres off: every sixth frame, from the side.
func flight() -> void:
	put(Vector3(0.0, 0.05, -37.5))
	var ba := ba_at(Vector3(0.0, 0.0, -40.0), [Vector3(9.0, 0.0, -40.0)])
	await frames(8)
	look(Vector3(4.5, 1.6, -30.5), Vector3(4.5, 0.9, -40.0), 50.0)
	for k in 16:
		await frames(6)
		await snap()
	print("FLIGHT ended at %s, perched %s, spirited %d" % [ba.global_position, ba.is_perched(), ba.spirited])
	sheet("flight", 4)
	# (and close to, keeping up with it)
	put(Vector3(60.0, 0.05, 60.0))
	ba.queue_free()
	ba = ba_at(Vector3(0.0, 0.0, -40.0), [Vector3(9.0, 0.0, -40.0), Vector3(15.0, 0.0, -34.0)])
	ba.hop = 20.0
	await frames(8)
	put(Vector3(0.0, 0.05, -37.5))
	for k in 12:
		await frames(5)
		look(ba.global_position + Vector3(0.6, 0.7, 2.6), ba.global_position + Vector3(0.0, 0.2, 0.0), 40.0)
		await snap()
	put(Vector3(9.0, 0.05, -38.0))
	for k in 8:
		await frames(5)
		look(ba.global_position + Vector3(-1.2, 1.3, 2.4), ba.global_position + Vector3(0.0, 0.2, 0.0), 40.0)
		await snap()
	sheet("flight_close", 4)
	ba.queue_free()


## Leading him: round the end of a wall, with the game's own sort of view. He walks after it.
func lead() -> void:
	var wall := box(Vector3(26.0, 1.5, -40.0), Vector3(0.6, 3.0, 10.0), Color(0.55, 0.5, 0.42))
	put(Vector3(20.0, 0.05, -44.0))
	var places: Array[Vector3] = [Vector3(24.0, 0.0, -33.5), Vector3(29.0, 0.0, -34.0), Vector3(31.0, 0.0, -44.0)]
	var ba := ba_at(Vector3(23.0, 0.0, -42.0), places)
	var landed := [0]
	ba.arrived.connect(func(_at: Vector3) -> void: landed[0] += 1)
	await frames(20)
	for k in 16:
		for step in 24:
			var to := ba.global_position - player.global_position
			to.y = 0.0
			steer(to.normalized() if to.length() > 1.5 else Vector3.ZERO)
			await frames(1)
		look(Vector3(26.0, 9.0, -27.0), Vector3(26.0, 0.5, -39.0), 50.0)
		await snap()
	touch.move = Vector2.ZERO
	print("LEAD landed %d times, at place %d, finished %s, spirited %d" % [landed[0], ba.place(), ba.is_finished(), ba.spirited])
	sheet("lead", 4)
	ba.queue_free()
	wall.queue_free()


## He goes the wrong way: it calls, comes back for him, lands by him and goes ahead again.
func fetch() -> void:
	put(Vector3(40.0, 0.05, -40.0))
	var ba := ba_at(Vector3(42.0, 0.0, -40.0), [Vector3(52.0, 0.0, -40.0)] as Array[Vector3])
	ba.patience = 4.0
	await frames(70)
	# (it has flown on; he turns his back and walks off)
	for k in 16:
		for step in 40:
			steer(Vector3(-1, 0, 0) * 0.5 if player.global_position.x > 33.0 else Vector3.ZERO)
			await frames(1)
		look(Vector3(43.0, 9.0, -20.0), Vector3(43.0, 0.5, -40.0), 60.0)
		await snap()
	touch.move = Vector2.ZERO
	print("FETCH went back %d times" % ba.fetched)
	sheet("fetch", 4)
	# (the call, close to)
	ba.queue_free()
	put(Vector3(40.0, 0.05, -34.0))
	ba = ba_at(Vector3(40.0, 0.0, -40.0))
	await frames(30)
	ba._call()
	for k in 6:
		await frames(8)
		look(ba.global_position + Vector3(0.5, 0.45, 1.3), ba.global_position + Vector3.UP * 0.3, 34.0)
		await snap()
	sheet("call", 3)
	ba.queue_free()


## Turned on: it comes in out of the air. Turned off: it goes.
func appear() -> void:
	put(Vector3(-60.0, 0.05, -34.0))
	var ba := Ba.new()
	ba.voice = false
	ba.on = false
	ba.position = Vector3(-60.0, 0.0, -40.0)
	stage.add_child(ba)
	ba.target = player
	await frames(20)
	look(Vector3(-57.0, 2.2, -32.0), Vector3(-60.0, 1.3, -41.0), 50.0)
	await snap()
	ba.on = true
	for k in 7:
		await frames(9)
		await snap()
	await frames(40)
	ba.on = false
	for k in 4:
		await frames(12)
		await snap()
	sheet("appear", 4)
	ba.queue_free()


## Shy: it sits on what is high, and goes to another perch when he comes near.
func shy() -> void:
	var things: Array[Node] = []
	for at: Vector3 in [Vector3(-60.0, 1.2, -10.0), Vector3(-55.0, 0.8, -6.0), Vector3(-64.0, 1.6, -5.0)]:
		things.append(box(Vector3(at.x, at.y * 0.5, at.z), Vector3(0.8, at.y, 0.8), Color(0.6, 0.54, 0.46)))
	put(Vector3(-60.0, 0.05, -2.0))
	var ba := Ba.new()
	ba.voice = false
	ba.shy = true
	ba.position = Vector3(-60.0, 0.0, -9.0)
	stage.add_child(ba)
	ba.target = player
	await frames(30)
	for k in 12:
		for step in 22:
			var to := ba.global_position - player.global_position
			to.y = 0.0
			steer(to.normalized() * 0.6)
			await frames(1)
		look(Vector3(-59.0, 6.5, 6.0), Vector3(-60.0, 0.6, -7.0), 50.0)
		await snap()
	touch.move = Vector2.ZERO
	print("SHY perches %d, it is at %s" % [ba._perches.size(), ba.global_position])
	sheet("shy", 4)
	ba.queue_free()
	for thing in things:
		thing.queue_free()


## A hint: it was not there; it comes out of the air beside him, flies the way, looks back, comes back, and goes.
func show() -> void:
	var wall := box(Vector3(26.0, 1.5, 0.0), Vector3(0.6, 3.0, 8.0), Color(0.55, 0.5, 0.42))
	put(Vector3(21.0, 0.05, 0.0))
	var ba := Ba.new()
	ba.voice = false
	ba.on = false
	ba.position = Vector3(10.0, 0.0, 10.0)
	stage.add_child(ba)
	ba.target = player
	await frames(20)
	ba.show_way(PackedVector3Array([Vector3(24.0, 0.0, 5.5), Vector3(28.5, 0.0, 5.5), Vector3(30.0, 0.0, 0.0)]))
	look(Vector3(25.0, 10.0, 12.0), Vector3(25.5, 0.5, 1.0), 50.0)
	for k in 16:
		await frames(34)
		await snap()
	print("SHOW away again %s, spirited %d" % [ba.is_away(), ba.spirited])
	sheet("show", 4)
	ba.queue_free()
	wall.queue_free()


## In the dark: by its own light, alone; with the boy by it; flying; and beside a torch.
func dark() -> void:
	light(false)
	var built: Array[Node] = []
	var middle := Vector3(60.0, 0.0, 0.0)
	var stone := Color(0.42, 0.38, 0.33)
	for x: float in [-2.2, 2.2]:
		built.append(box(middle + Vector3(x, 1.5, 0.0), Vector3(0.4, 3.0, 16.0), stone))
	built.append(box(middle + Vector3(0.0, 3.2, 0.0), Vector3(4.8, 0.4, 16.0), stone.darkened(0.2)))
	built.append(box(middle + Vector3(0.0, 0.01, 0.0), Vector3(4.0, 0.02, 16.0), stone.lightened(0.1), false))
	put(middle + Vector3(0.6, 0.05, 5.0))
	var ba := ba_at(middle + Vector3(-0.4, 0.0, 2.6), [middle + Vector3(0.0, 0.0, -5.0)] as Array[Vector3])
	ba.near = 1.2
	await frames(30)
	look(middle + Vector3(0.9, 1.5, 7.6), middle + Vector3(-0.1, 0.7, 2.6), 50.0)
	await snap()
	look(ba.global_position + Vector3(0.4, 0.4, 1.3), ba.global_position + Vector3.UP * 0.3, 34.0)
	await frames(3)
	await snap()
	# (he walks up to it, and it goes on down the passage)
	look(middle + Vector3(0.9, 1.7, 7.6), middle + Vector3(-0.1, 0.8, 0.0), 55.0)
	for k in 7:
		for step in 14:
			steer(Vector3(0, 0, -1) * 0.5 if player.global_position.z > middle.z - 2.0 else Vector3.ZERO)
			await frames(1)
		await snap()
	touch.move = Vector2.ZERO
	sheet("dark", 3)
	# (and with a torch standing by)
	var torch := HandTorch.new()
	torch.position = middle + Vector3(1.2, 0.02, 3.2)
	torch.freeze = true
	stage.add_child(torch)
	ba.queue_free()
	ba = ba_at(middle + Vector3(-0.2, 0.0, 2.6))
	put(middle + Vector3(0.9, 0.05, 4.4))
	await frames(40)
	look(middle + Vector3(0.6, 1.5, 7.2), middle + Vector3(0.2, 0.7, 2.8), 50.0)
	await snap()
	look(ba.global_position + Vector3(0.5, 0.4, 1.3), ba.global_position + Vector3.UP * 0.3, 34.0)
	await frames(3)
	await snap()
	print("DARK fires %d (the Ba is not one)" % Nearby.fires(root.get_tree()).size())
	sheet("dark_torch", 2)
	torch.queue_free()
	ba.queue_free()
	for thing in built:
		thing.queue_free()
	light(true)
	await frames(3)


## The station in the test yard.
func yard() -> void:
	stage.queue_free()
	await frames(2)
	var scene: Node = load("res://test_yard.tscn").instantiate()
	root.add_child(scene)
	await frames(40)
	var view := Camera3D.new()
	root.add_child(view)
	view.make_current()
	cam = view
	var at := Vector3(-4.0, 0.0, -76.0)
	var boy := scene.get_node_or_null("Player") as Player
	if boy:
		boy.global_position = at + Vector3(-9.0, 0.1, 4.0)
	look(at + Vector3(-2.0, 14.0, 22.0), at + Vector3(0.0, 0.5, 0.0), 50.0)
	await frames(30)
	await snap()
	look(at + Vector3(-12.0, 3.0, 9.0), at + Vector3(-6.0, 0.6, 1.0), 50.0)
	await frames(10)
	await snap()
	if boy:
		boy.global_position = at + Vector3(-8.0, 0.1, 3.0)
	for k in 4:
		await frames(40)
		await snap()
	sheet("yard", 3)
