extends SceneTree
## Not part of the game. Pictures of the scarabs and the cobwebs: a beetle and the gold one close to;
## the swarm pouring out of its nest, going over a step, after the boy, round a torch in his hand and
## round a brazier, and on him; the harmless ones; and a tunnel of webs by day, in the dark with a
## torch going past, far off, being run through and burning. Strips are consecutive moments, left to
## right and top to bottom. It also prints what a frame of the swarm costs (`COST`).
## godot --path . --fixed-fps 60 --resolution 960x960 --script tools/scarab_sheets.gd -- <outdir> [beetle pour step chase torch fire caught harmless webs tear burn far yard cost ...]

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


func swarm_at(at: Vector3, count := 140) -> ScarabSwarm:
	var swarm := ScarabSwarm.new()
	swarm.count = count
	swarm.voice = false
	swarm.position = at
	stage.add_child(swarm)
	swarm.target = player
	return swarm


func hand_torch(at: Vector3) -> HandTorch:
	var torch := HandTorch.new()
	torch.position = at
	torch.freeze = true
	stage.add_child(torch)
	return torch


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
	box(Vector3(0, -1, 0), Vector3(160, 2, 160), Color(0.7, 0.62, 0.46))
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

	if wanted("beetle"):
		await beetle()
	if wanted("pour"):
		await pour()
	if wanted("step"):
		await step()
	if wanted("chase"):
		await chase()
	if wanted("torch"):
		await torch()
	if wanted("fire"):
		await fire()
	if wanted("caught"):
		await caught()
	if wanted("harmless"):
		await harmless()
	if wanted("webs") or wanted("tear") or wanted("burn") or wanted("far"):
		await webs()
	if wanted("cost"):
		await cost()
	if wanted("yard"):
		await yard()
	quit()


## One beetle, large, from all round, walking; and the gold one.
func beetle() -> void:
	var one := MultiMeshInstance3D.new()
	var many := MultiMesh.new()
	many.transform_format = MultiMesh.TRANSFORM_3D
	many.use_custom_data = true
	many.mesh = Scarab.mesh()
	many.instance_count = 1
	one.multimesh = many
	one.position = Vector3(-30, 0.0, -30)
	stage.add_child(one)
	many.set_instance_transform(0, Transform3D(Basis.from_scale(Vector3.ONE * 0.5), Vector3.ZERO))
	for k in 6:
		many.set_instance_custom_data(0, Color(k / 6.0, 0, 0, 0))
		var turn := [0.6, 2.2, 3.6, 5.2, 0.0, 1.57][k] as float
		var high := [0.5, 0.5, 0.35, 0.9, 0.12, 0.2][k] as float
		look(one.position + Vector3(sin(turn), high, cos(turn)).normalized() * 1.5, one.position + Vector3.UP * 0.06, 32.0)
		await frames(2)
		await snap()
	one.queue_free()
	var amulet := ScarabAmulet.new()
	amulet.freeze = true
	amulet.position = Vector3(-30, 0.03, -26)
	stage.add_child(amulet)
	var socket := ScarabSocket.new()
	socket.position = Vector3(-29.6, 0.0, -26.2)
	stage.add_child(socket)
	for turn: float in [0.7, 3.4]:
		look(amulet.position + Vector3(sin(turn), 0.7, cos(turn)).normalized() * 0.55, amulet.position, 35.0)
		await frames(2)
		await snap()
	look(amulet.position + Vector3(0.6, 0.9, 1.4), amulet.position + Vector3(0.2, 0.1, 0.0), 35.0)
	await frames(2)
	await snap()
	amulet.queue_free()
	socket.queue_free()
	sheet("beetle", 3)


## Out of the nest: every sixth frame from the moment they are let out.
func pour() -> void:
	put(Vector3(6.0, 0.05, 0.5))
	var swarm := swarm_at(Vector3.ZERO)
	await frames(10)
	look(Vector3(1.2, 1.5, 2.6), Vector3(0.9, 0.0, 0.1), 50.0)
	swarm.chasing = true
	for k in 8:
		await frames(6)
		await snap()
	sheet("pour", 4)
	swarm.queue_free()


## Over a step 0.4 m high that lies right across their way.
func step() -> void:
	put(Vector3(9.0, 0.05, 20.0))
	var kerb := box(Vector3(3.0, 0.2, 20.0), Vector3(0.9, 0.4, 8.0), Color(0.55, 0.5, 0.42))
	var swarm := swarm_at(Vector3(0.0, 0.0, 20.0))
	await frames(10)
	look(Vector3(4.6, 1.1, 22.3), Vector3(3.0, 0.2, 20.2), 45.0)
	swarm.chasing = true
	await frames(40)
	for k in 8:
		await frames(7)
		await snap()
	sheet("step", 4)
	swarm.queue_free()
	kerb.queue_free()


## After him as he runs: he gains on them.
func chase() -> void:
	put(Vector3(-20.0, 0.05, 2.0))
	var swarm := swarm_at(Vector3(-24.0, 0.0, 2.0))
	await frames(10)
	look(Vector3(-17.0, 2.4, 8.5), Vector3(-17.0, 0.5, 2.0), 50.0)
	swarm.chasing = true
	await frames(45)
	for k in 6:
		steer(Vector3(1, 0, 0))
		await frames(18)
		look(player.visual_position + Vector3(-0.5, 2.2, 6.0), player.visual_position + Vector3(-1.6, 0.4, 0.0), 50.0)
		await snap()
	touch.move = Vector2.ZERO
	print("CHASE he is %.1f m ahead of the nearest after running, out %d, on him %d" % [player.global_position.distance_to(swarm.front.global_position), swarm.out, swarm.on_him])
	sheet("chase", 3)
	swarm.queue_free()


## A torch in his hand: they ring him, and part as he walks through them. By day, then in the dark.
func torch() -> void:
	for day: bool in [true, false]:
		light(day)
		put(Vector3(-20.0, 0.05, -20.0))
		var carried := hand_torch(Vector3(-20.0, 0.05, -19.5))
		await frames(30)
		look(Vector3(-17.0, 4.6, -13.5), Vector3(-19.0, 0.3, -20.0), 50.0)
		player._act()
		await frames(50)
		var swarm := swarm_at(Vector3(-13.0, 0.0, -20.0))
		swarm.chasing = true
		await frames(280)
		await snap()
		await frames(60)
		await snap()
		# (and now he walks at the nest, through the thick of them)
		for k in 4:
			var thick := swarm.front.global_position - player.global_position
			steer(Vector3(thick.x, 0.0, thick.z).normalized() * 0.4)
			await frames(24)
			look(player.visual_position + Vector3(1.0, 4.4, 6.0), player.visual_position + Vector3(0.6, 0.3, 0.0), 50.0)
			await snap()
		touch.move = Vector2.ZERO
		print("TORCH %s carried %s, held off %d, on him %d, nearest %.2f m" % ["day" if day else "dark", player.carried is HandTorch, swarm.held_off, swarm.on_him,
				Vector2(swarm.front.global_position.x - player.global_position.x, swarm.front.global_position.z - player.global_position.z).length()])
		sheet("torch_day" if day else "torch_dark", 3)
		swarm.queue_free()
		player._let_go()
		carried.queue_free()
		await frames(5)
	light(true)


## A brazier standing between them and him: they part round its light.
func fire() -> void:
	put(Vector3(20.0, 0.05, -20.0))
	var brazier: Node3D = (load("res://props/brazier.tscn") as PackedScene).instantiate()
	brazier.position = Vector3(15.5, 0.0, -20.0)
	stage.add_child(brazier)
	var flame := brazier.find_child("Flame*", true, false) as Node3D
	(flame if flame else brazier).add_child(Fire.brazier())
	var swarm := swarm_at(Vector3(9.0, 0.0, -20.0), 200)
	await frames(10)
	look(Vector3(15.5, 9.0, -14.0), Vector3(15.5, 0.0, -20.0), 50.0)
	swarm.chasing = true
	await frames(50)
	for k in 6:
		await frames(22)
		await snap()
	sheet("fire", 3)
	swarm.queue_free()
	brazier.queue_free()


## No torch, standing still: up his legs, and he is down.
func caught() -> void:
	put(Vector3(20.0, 0.05, 20.0))
	var swarm := swarm_at(Vector3(16.0, 0.0, 20.0))
	var down := [false]
	swarm.caught.connect(func() -> void:
		down[0] = true
		player.ragdoll(Vector3.UP * 6.0))
	await frames(10)
	look(Vector3(21.2, 1.3, 23.0), Vector3(20.0, 0.6, 20.0), 45.0)
	swarm.chasing = true
	await frames(50)
	for k in 9:
		await frames(12)
		await snap()
	print("CAUGHT ", down[0], " on him ", swarm.on_him)
	sheet("caught", 3)
	swarm.queue_free()
	player.respawn()
	await frames(10)


## The ones that do no harm, and the one with its ball.
func harmless() -> void:
	put(Vector3(40.0, 0.05, 40.0))
	var few := ScarabSwarm.new()
	few.harmless = true
	few.dung_ball = true
	few.count = 7
	few.roam = 0.9
	few.position = Vector3(-30.0, 0.0, 20.0)
	stage.add_child(few)
	await frames(200)
	for k in 6:
		await frames(20)
		if k < 3:
			look(few.position + Vector3(0.9, 1.0, 1.6), few.position, 45.0)
		else:
			var at := Vector3(few._x[0], few._y[0], few._z[0])
			look(at + Vector3(0.25, 0.14, 0.3), at + Vector3.UP * 0.03, 40.0)
		await snap()
	sheet("harmless", 3)
	few.queue_free()


## A tunnel hung with every sort of web.
func webs() -> void:
	var dark := Color(0.3, 0.27, 0.24)
	var built: Array[Node] = []
	var middle := Vector3(60.0, 0.0, 0.0)
	for x: float in [-1.2, 1.2]:
		built.append(box(middle + Vector3(x, 1.4, 0.0), Vector3(0.4, 2.8, 12.0), dark))
	built.append(box(middle + Vector3(0.0, 0.01, 0.0), Vector3(2.0, 0.02, 12.0), dark.lightened(0.08), false))
	var roof := box(middle + Vector3(0.0, 2.8, 0.0), Vector3(2.8, 0.4, 12.0), dark.darkened(0.2))
	built.append(roof)
	var hung: Array[Cobweb] = []
	var hang := func(kind: Cobweb.Kind, where: Vector3, yaw := 0.0) -> Cobweb:
		var web := Cobweb.new()
		web.kind = kind
		web.wide = 2.0
		web.tall = 2.6
		web.seed = hung.size() + 1
		web.position = middle + where
		web.rotation.y = yaw
		stage.add_child(web)
		hung.append(web)
		return web
	var dress := func() -> void:
		for web in hung:
			if is_instance_valid(web):
				web.queue_free()
		hung.clear()
		hang.call(Cobweb.Kind.SHEET, Vector3(0.0, 0.0, 0.0))
		hang.call(Cobweb.Kind.SHEET, Vector3(0.0, 0.0, -3.4))
		hang.call(Cobweb.Kind.CORNER, Vector3(-1.0, 2.6, 2.2))
		hang.call(Cobweb.Kind.CORNER, Vector3(1.0, 2.6, 1.4), PI)
		var big: Cobweb = hang.call(Cobweb.Kind.CORNER, Vector3(1.0, 2.6, 3.4), PI)
		big.size = 1.5
		var strands: Cobweb = hang.call(Cobweb.Kind.HANGING, Vector3(0.0, 2.6, 2.8))
		strands.size = 1.0
		strands.wide = 1.8
		var drape: Cobweb = hang.call(Cobweb.Kind.DRAPE, Vector3(-0.45, 0.0, 1.5))
		drape.over = Vector3(0.95, 1.15, 0.95)
		drape.dust = 0.7
	var pot: Node3D = (load("res://props/pot_large.tscn") as PackedScene).instantiate()
	pot.position = middle + Vector3(-0.45, 0.0, 1.5)
	stage.add_child(pot)
	built.append(pot)
	put(middle + Vector3(0.3, 0.05, 9.0))

	if wanted("webs"):
		# By day, the roof off: from the mouth of the tunnel, then each sort close to.
		roof.visible = false
		light(true)
		dress.call()
		await frames(20)
		var views := [[Vector3(0.1, 1.5, 5.6), Vector3(0.0, 1.35, 0.0)], [Vector3(0.0, 1.5, 2.2), Vector3(0.0, 1.4, 0.0)], [Vector3(0.2, 1.7, 4.0), Vector3(-1.0, 2.3, 2.2)],
				[Vector3(-0.5, 1.6, 5.0), Vector3(0.6, 2.0, 3.2)], [Vector3(0.6, 1.3, 3.6), Vector3(-0.45, 0.6, 1.5)], [Vector3(0.3, 1.5, 0.9), Vector3(0.0, 1.3, -3.4)]]
		for view: Array in views:
			look(middle + view[0], middle + view[1], 55.0)
			await frames(3)
			await snap()
		sheet("webs_day", 3)
		# In the dark, a torch carried past them.
		roof.visible = true
		light(false)
		var carried := hand_torch(middle + Vector3(0.3, 0.05, 6.4))
		put(middle + Vector3(0.3, 0.05, 6.8))
		look(middle + Vector3(-0.2, 1.6, 8.5), middle + Vector3(0.0, 1.3, 0.0), 55.0)
		await frames(30)
		player._act()
		await frames(40)
		for web in hung:
			web.burns = false
			web.tears = false
		for k in 6:
			steer(Vector3(0, 0, -1))
			await frames(26)
			look(player.visual_position + Vector3(-0.35, 1.5, 2.6), player.visual_position + Vector3(0.0, 1.3, -2.0), 60.0)
			await snap()
		touch.move = Vector2.ZERO
		sheet("webs_dark", 3)
		player._let_go()
		carried.queue_free()

	if wanted("far"):
		# Far off, by day and by a torch on the wall: do the threads shimmer?
		roof.visible = false
		light(true)
		dress.call()
		for far: float in [9.0, 16.0, 26.0]:
			for nudge: float in [0.0, 0.07]:
				look(middle + Vector3(0.1 + nudge, 1.5, far), middle + Vector3(0.0, 1.35, 0.0), 30.0)
				await frames(3)
				await snap()
		sheet("webs_far", 2)

	if wanted("tear"):
		# Run through, towards the eye: every fourth frame from just before he reaches it, then how it is left. Then walked through.
		roof.visible = false
		light(true)
		for run_it: bool in [true, false]:
			dress.call()
			for k in range(1, hung.size()):
				hung[k].queue_free()
			put(middle + Vector3(0.2, 0.05, 3.4 if run_it else 1.6))
			look(middle + Vector3(-0.5, 1.5, -3.0), middle + Vector3(0.0, 1.25, 0.0), 55.0)
			await frames(20)
			steer(Vector3(0, 0, -1) * (1.0 if run_it else 0.45))
			await frames(26 if run_it else 30)
			for k in 12:
				steer((Vector3(0, 0, -1) if player.global_position.z > middle.z - 1.8 else Vector3.ZERO) * (1.0 if run_it else 0.45))
				await frames(4 if k < 8 else 16)
				await snap()
			touch.move = Vector2.ZERO
			print("TEAR torn ", hung[0].is_torn())
			sheet("web_tear" if run_it else "web_tear_walk", 4)

	if wanted("burn"):
		# A torch held to one: every fifth frame from when it catches. In the dark, then by day.
		for day: bool in [false, true]:
			roof.visible = not day
			light(day)
			dress.call()
			put(middle + Vector3(0.3, 0.05, 9.0))
			look(middle + Vector3(0.3, 1.5, 3.2), middle + Vector3(0.0, 1.3, 0.0), 55.0)
			var lamp := OmniLight3D.new()
			lamp.position = middle + Vector3(0.0, 1.6, 3.0)
			lamp.light_energy = 0.0 if day else 0.6
			lamp.omni_range = 6.0
			stage.add_child(lamp)
			await frames(20)
			await snap()
			var flame := hand_torch(middle + Vector3(0.75, 0.5, 0.2))
			for k in 11:
				await frames(5)
				await snap()
			print("BURN the sheet %s, webs left %d" % ["gone" if not is_instance_valid(hung[0]) else "there", get_nodes_in_group(&"cobwebs").size()])
			sheet("web_burn_dark" if not day else "web_burn_day", 4)
			flame.queue_free()
			lamp.queue_free()
			await frames(3)

	for web in hung:
		if is_instance_valid(web):
			web.queue_free()
	for thing in built:
		thing.queue_free()
	light(true)
	await frames(3)


## What a frame of the swarm costs: its own loop, timed, with every beetle out and held in a ring by a torch
## (the dearest thing they do), and again on open ground on their way to him.
func cost() -> void:
	for count: int in [50, 100, 200]:
		put(Vector3(-40.0, 0.05, -40.0))
		var carried := hand_torch(Vector3(-39.7, 0.0, -40.0))
		var swarm := swarm_at(Vector3(-46.0, 0.0, -40.0), count)
		swarm.chasing = true
		await frames(260)
		var began := Time.get_ticks_usec()
		for i in 300:
			swarm._physics_process(1.0 / 60.0)
		var ring := (Time.get_ticks_usec() - began) / 300000.0
		var held := swarm.held_off
		swarm.reset()
		carried.queue_free()
		put(Vector3(-30.0, 0.05, -40.0))
		await frames(10)
		swarm.chasing = true
		await frames(120)
		began = Time.get_ticks_usec()
		for i in 120:
			swarm._physics_process(1.0 / 60.0)
		var run_cost := (Time.get_ticks_usec() - began) / 120000.0
		print("COST %d beetles: %.3f ms a frame held off by a torch (%d of them), %.3f ms running over new ground; %d triangles, 1 draw call" % [count, ring, held, run_cost,
				count * Scarab.mesh().get_faces().size() / 3])
		swarm.queue_free()
		await frames(5)


## The station in the test yard.
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
	var at := Vector3(-18.0, 0.0, -46.0)
	var boy := scene.get_node_or_null("Player") as Player
	if boy:
		boy.global_position = at + Vector3(3.0, 0.1, 1.2)
	for shot: Array in [[Vector3(4.0, 7.0, 11.0), Vector3(0.0, 0.5, 0.0)], [Vector3(3.2, 1.5, 3.3), Vector3(-2.5, 1.2, 3.4)], [Vector3(4.2, 1.0, 4.4), Vector3(3.8, 0.0, 2.8)]]:
		look(at + shot[0], at + shot[1], 50.0)
		await frames(20)
		await snap()
	# The plate: out they come.
	var swarm: ScarabSwarm
	for child in scene.find_children("*", "", true, false):
		if child is ScarabSwarm and not (child as ScarabSwarm).harmless:
			swarm = child
	if swarm:
		swarm.chasing = true
		look(at + Vector3(4.0, 5.0, 7.0), at + Vector3(0.0, 0.3, -1.5), 50.0)
		for k in 3:
			await frames(45)
			await snap()
		print("YARD out %d, on him %d" % [swarm.out, swarm.on_him])
	sheet("yard", 3)
