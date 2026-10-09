extends SceneTree
## Not part of the game. Draws the railway: each vehicle, the whole train by day and at
## dusk, the train moving (frames one after another: wheels, rods, smoke), the boy
## riding it, and the halt in the test yard.
## godot --path . --fixed-fps 60 --resolution 960x960 --script tools/train_sheets.gd -- <outdir> [vehicles train dusk moving rods ride world yard lineside] [banded]
## With no names, all of them. Its window is kept off the screen.
##
##   vehicles   each vehicle from in front and from behind, and the triangles in each
##   train      a train of six on a length of line, from four places
##   dusk       the same with the sun down, sparks from the chimney
##   moving     the train getting away and at speed: six frames, four apart
##   rods       close on the engine's wheels and rods: eight frames one after another
##   ride       the boy on it as it really moves: platform, ladder, roof, the gaps, the bridge
##   world      the same with the train standing and the world going by
##   yard       the halt in the test yard, and the train leaving it
##   lineside   track, points, signal (at danger and clear) and the rest, set out as a scene

const CELL := 480

var out := ""
var only: Array = []
var stage: Node3D
var cam: Camera3D
var sun: DirectionalLight3D
var env: Environment
var cells: Array[Image] = []
var train: Train
var scenery: TrainScenery
var player: Player
var touch: TouchControls
# What the camera looks at, and from where (relative to it): set, then `aim` keeps to it.
var look_at_node: Node3D
var look_from := Vector3(8.0, 3.0, 8.0)
var look_lift := 1.0


func _initialize() -> void:
	DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_NO_FOCUS, true)
	DisplayServer.window_set_position(Vector2i(-6000, -6000))
	var args := OS.get_cmdline_user_args()
	out = args[0]
	only = args.slice(1)
	if "banded" in only:
		only.erase("banded")
		Settings.world_banded = true
	DirAccess.make_dir_recursive_absolute(out)
	run.call_deferred()


func wanted(name: String) -> bool:
	return only.is_empty() or name in only


func run() -> void:
	if wanted("vehicles"):
		await vehicles()
	if wanted("train"):
		await whole(false)
	if wanted("dusk"):
		await whole(true)
	if wanted("moving"):
		await moving()
	if wanted("rods"):
		await rods()
	if wanted("ride"):
		await ride(false)
	if wanted("world"):
		await ride(true)
	if wanted("lineside"):
		await lineside()
	if wanted("yard"):
		await yard()
	quit()


# --- the stage ---

func fresh(dusk := false) -> void:
	if stage:
		stage.queue_free()
		await process_frame
	train = null
	player = null
	look_at_node = null
	stage = Node3D.new()
	root.add_child(stage)
	env = Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.56, 0.7, 0.86) if not dusk else Color(0.2, 0.17, 0.26)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.7, 0.74, 0.8) if not dusk else Color(0.3, 0.3, 0.45)
	env.ambient_light_energy = 0.7 if not dusk else 0.5
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	var world := WorldEnvironment.new()
	world.environment = env
	stage.add_child(world)
	sun = DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-46.0, 150.0, 0.0) if not dusk else Vector3(-9.0, 118.0, 0.0)
	sun.light_color = Color(1.0, 0.95, 0.86) if not dusk else Color(1.0, 0.55, 0.3)
	sun.light_energy = 1.25 if not dusk else 0.8
	sun.shadow_enabled = true
	sun.directional_shadow_max_distance = 200.0
	stage.add_child(sun)
	var ground := StaticBody3D.new()
	var slab := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(600.0, 2.0, 3000.0)
	slab.shape = shape
	slab.position.y = -1.0
	ground.add_child(slab)
	var sand := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(1200.0, 3000.0)
	sand.mesh = plane
	sand.material_override = Sand.surface()
	ground.add_child(sand)
	ground.position.z = 600.0
	stage.add_child(ground)
	cam = Camera3D.new()
	cam.fov = 34.0
	cam.far = 900.0
	stage.add_child(cam)
	cam.make_current()


func lay(what: String, at: Vector3, yaw := 0.0, under: Node = null) -> Node3D:
	var made := (load("res://props/%s.tscn" % what) as PackedScene).instantiate() as Node3D
	made.position = at
	made.rotation.y = yaw
	(under if under else stage).add_child(made)
	return made


## A line along Z from `from` to `to` with poles beside it, and a train on it with its front at z = 0.
func line(consist: Array, from := -70.0, to := 250.0, world_moves := false) -> void:
	scenery = TrainScenery.new()
	scenery.span = snappedf(to - from, 10.0)
	scenery.position.z = (from + to) * 0.5
	stage.add_child(scenery)
	var z := from + 5.0
	while z < to:
		lay("track_straight", Vector3(0.0, 0.0, z - scenery.position.z), 0.0, scenery)
		z += 10.0
	z = from
	while z < to:
		lay("telegraph_pole", Vector3(-4.6, 0.0, z - scenery.position.z), 0.0, scenery)
		z += 30.0
	train = Train.new()
	train.consist = PackedStringArray(consist)
	train.distance = to - 5.0
	train.world_moves = world_moves
	train.scenery = scenery
	stage.add_child(train)


func aim() -> void:
	if look_at_node and is_instance_valid(look_at_node):
		var at := look_at_node.global_position
		if look_at_node is Player:
			at = (look_at_node as Player).visual_position if not (look_at_node as Player).is_limp else (look_at_node as Player)._rig.limp_position()
		at.y += look_lift
		cam.global_position = at + look_from
		cam.look_at(at)


func view(from: Vector3, to: Vector3, fov := 34.0) -> void:
	look_at_node = null
	cam.fov = fov
	cam.global_position = from
	cam.look_at(to)


func frames(count: int, heading := Vector3.INF) -> void:
	for i in count:
		aim()
		if heading != Vector3.INF:
			steer(heading)
		await physics_frame
		await process_frame


func steer(world: Vector3) -> void:
	var basis := cam.global_basis
	var right := Vector3(basis.x.x, 0, basis.x.z).normalized()
	var forward := Vector3(-basis.z.x, 0, -basis.z.z).normalized()
	touch.move = Vector2(world.dot(right), -world.dot(forward))


func snap(wide := false) -> void:
	aim()
	await RenderingServer.frame_post_draw
	var image := root.get_texture().get_image()
	if not wide:
		var side: int = mini(image.get_width(), image.get_height())
		image = image.get_region(Rect2i((image.get_width() - side) / 2, (image.get_height() - side) / 2, side, side))
		image.resize(CELL, CELL, Image.INTERPOLATE_LANCZOS)
	cells.append(image)


func sheet(name: String, columns := 2) -> void:
	var wide := cells[0].get_width()
	var high := cells[0].get_height()
	var rows := ceili(cells.size() / float(columns))
	var page := Image.create(wide * columns, high * rows, false, cells[0].get_format())
	for i in cells.size():
		page.blit_rect(cells[i], Rect2i(0, 0, wide, high), Vector2i((i % columns) * wide, (i / columns) * high))
	page.save_png(out.path_join(name + ".png"))
	cells.clear()
	print("SHEET ", name)


func triangles(of: Node) -> int:
	var count := 0
	for part: MeshInstance3D in of.find_children("*", "MeshInstance3D", true, false):
		if part.mesh == null or part.get_parent() is Ladder:
			continue
		for surface in part.mesh.get_surface_count():
			var arrays := part.mesh.surface_get_arrays(surface)
			var index: Variant = arrays[Mesh.ARRAY_INDEX]
			count += (index as PackedInt32Array).size() / 3 if index != null else (arrays[Mesh.ARRAY_VERTEX] as PackedVector3Array).size() / 3
	return count


# --- what is drawn ---

func vehicles() -> void:
	var names := ["loco", "tender", "carriage", "carriage_third", "van_goods", "wagon_open", "wagon_finds", "wagon_flat", "wagon_tank", "van_brake"]
	var total := 0
	for i in names.size():
		await fresh()
		lay("track_straight", Vector3(0, 0, -5))
		lay("track_straight", Vector3(0, 0, 5))
		var vehicle := lay(names[i], Vector3.ZERO) as TrainVehicle
		var count := triangles(vehicle)
		total += count
		print("TRIANGLES %-16s %5d   length over buffers %.2f m   pieces that turn %d" % [names[i], count, vehicle.front + vehicle.rear, vehicle.wheels.size()])
		var reach := (vehicle.front + vehicle.rear) * 1.25 + 3.0
		var middle := Vector3(0.0, 1.9, (vehicle.front - vehicle.rear) * 0.5)
		for from: Vector3 in [Vector3(0.75, 0.32, 0.75), Vector3(-0.8, 0.5, -0.6), Vector3(1.0, 0.05, 0.02), Vector3(0.02, 0.2, 1.0)]:
			view(middle + from.normalized() * reach, middle, 34.0)
			await frames(3)
			await snap()
		sheet("vehicle_%s" % names[i], 2)
	print("TRIANGLES all ten vehicles: %d" % total)


func whole(dusk: bool) -> void:
	await fresh(dusk)
	line(["loco", "tender", "carriage", "wagon_open", "van_goods", "van_brake"])
	lay("water_column", Vector3(-2.9, 0.0, -9.5))
	lay("signal_semaphore", Vector3(-3.0, 0.0, 12.0), PI)
	if dusk:
		train.sparks = 1.0
	await frames(10)
	var count := 0
	for vehicle in train.vehicles:
		count += triangles(vehicle)
	print("TRIANGLES the train of six (%s): %d, %.1f m long" % [", ".join(train.consist), count, train.length()])
	train.speed = 9.0
	if dusk:
		train.start()
		await frames(420)
	var front := train.vehicles[0].global_position.z + 5.0
	for shot: Array in [[Vector3(14.0, 5.0, 12.0), Vector3(0.0, 1.8, -14.0)], [Vector3(-9.0, 2.2, 7.0), Vector3(0.0, 2.0, -6.0)],
			[Vector3(30.0, 9.0, -26.0), Vector3(0.0, 1.5, -27.0)], [Vector3(-12.0, 6.5, -62.0), Vector3(0.0, 1.5, -40.0)]]:
		view((shot[0] as Vector3) + Vector3(0, 0, front), (shot[1] as Vector3) + Vector3(0, 0, front), 40.0)
		await frames(3)
		await snap(true)
		front = train.vehicles[0].global_position.z + 5.0
	sheet("train_dusk" if dusk else "train_day", 2)


func moving() -> void:
	await fresh()
	line(["loco", "tender", "carriage", "wagon_open", "van_goods", "van_brake"])
	await frames(10)
	train.speed = 10.0
	train.start()
	# Getting away: steam from the cylinders, the first beats
	view(Vector3(9.0, 3.0, 12.0), Vector3(0.0, 2.2, -2.0), 40.0)
	for i in 6:
		await frames(22)
		await snap(true)
	sheet("moving_away", 3)
	# At speed, seen from beside the line as it goes by
	await frames(360)
	var front := train.vehicles[0].global_position.z + 5.0
	view(Vector3(16.0, 3.4, front + 46.0), Vector3(0.0, 2.6, front + 26.0), 44.0)
	for i in 6:
		await frames(24)
		await snap(true)
	sheet("moving_speed", 3)
	print("MOVING at %.1f m/s, %.0f m along" % [train.pace, train.travelled])


func rods() -> void:
	await fresh()
	line(["loco", "tender"])
	await frames(10)
	train.speed = 3.0
	train.acceleration = 3.0
	train.start()
	await frames(90)
	look_at_node = train.vehicles[0]
	look_from = Vector3(14.0, 0.5, -0.5)
	look_lift = 1.3
	cam.fov = 30.0
	var engine := train.vehicles[0]
	for i in 8:
		await frames(5)
		await snap(true)
		print("RODS frame %d: wheels turned %.0f degrees, rolled %.2f m" % [i, rad_to_deg(fposmod(engine.rolled / 0.72, TAU)), engine.rolled])
	sheet("rods", 2)


func add_player(at: Vector3) -> void:
	var layer := CanvasLayer.new()
	stage.add_child(layer)
	touch = TouchControls.new()
	layer.add_child(touch)
	touch.visible = false
	player = (load("res://player.tscn") as PackedScene).instantiate() as Player
	player.position = at
	stage.add_child(player)
	touch.set_process_input(false)
	player.set_process_unhandled_input(false)
	for action: StringName in InputMap.get_actions():
		if not String(action).begins_with("ui_"):
			InputMap.action_erase_events(action)
			Input.action_release(action)


func rest() -> void:
	touch.move = Vector2.ZERO
	touch.jump_held = false
	touch.duck_held = false


func seen() -> Vector3:
	var at := player.global_position
	return Vector3(at.x, at.y, at.z - train.travelled)


func floor_ahead(far: float) -> bool:
	var from := player.global_position + Vector3(0, 0.6, far)
	return not player.get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(from, from + Vector3.DOWN * 1.3, 1)).is_empty()


## Runs him to a place on the train, jumping the gaps, and takes a picture every `every` frames.
func go(x: float, ahead: float, strength := 1.0, every := 0, limit := 900) -> void:
	for i in limit:
		var at := seen()
		var to := Vector3(x - at.x, 0.0, ahead - at.z)
		if to.length() < 0.25 or player.is_limp:
			break
		if player.is_on_floor() and absf(to.z) > 1.0 and not floor_ahead(0.55 * signf(to.z)):
			player._queue_jump()
			touch.jump_held = true
		elif player.is_on_floor():
			touch.jump_held = false
		await frames(1, to.normalized() * strength)
		if every > 0 and i % every == every - 1:
			await snap(true)
	rest()


func ride(world_moves: bool) -> void:
	await fresh()
	line(["loco", "tender", "carriage", "carriage_third", "van_goods", "van_brake"], -70.0, 290.0, world_moves)
	train.speed = 8.0
	var van := -train._behind[5]
	var carriage := -train._behind[2]
	lay("halt_platform", Vector3(-4.62, 0.0, van - 2.8))
	lay("halt_shelter", Vector3(-6.0, 1.3, van - 8.5))
	if world_moves:
		lay("bridge_low", Vector3(0.0, 0.0, 170.0 - scenery.position.z), 0.0, scenery)
	else:
		lay("bridge_low", Vector3(0.0, 0.0, 170.0))
	add_player(Vector3(-3.2, 1.35, van - 2.8))
	var tag := "world" if world_moves else "ride"
	look_at_node = player
	look_from = Vector3(7.0, 2.6, -6.0)
	look_lift = 0.8
	cam.fov = 40.0
	await frames(30)
	await snap(true)
	# Onto the van, up the ladder
	await go(0.85, van - 2.9, 0.6)
	for i in 90:
		await frames(1, Vector3(0, 0, 1))
		if player.state == Player.State.LADDER:
			break
	for i in 400:
		touch.move = Vector2(0.0, -1.0)
		await frames(1)
		if i == 45:
			await snap(true)
		if player.state != Player.State.LADDER:
			break
	rest()
	await frames(25)
	await snap(true)
	sheet(tag + "_boarding", 3)
	# The train starts; along the roofs and over the gaps
	train.start()
	await frames(150)
	look_from = Vector3(9.0, 3.0, 5.0)
	await go(0.0, carriage, 1.0, 22)
	while cells.size() > 12:
		cells.remove_at(cells.size() - 1)
	sheet(tag + "_roofs", 3)
	# The bridge: ducked, it goes over him
	look_from = Vector3(7.0, 1.6, 6.5)
	touch.duck_held = true
	await _bridge(6)
	touch.duck_held = false
	player.stand_up()
	await frames(120)
	await snap(true)
	sheet(tag + "_bridge_ducked", 3)
	# And standing: it knocks him down
	if world_moves:
		# (left alone so long he would sit down, and be under it)
		player.rest_enabled = false
		await _bridge(6)
		await frames(40)
		await snap(true)
		sheet(tag + "_bridge_standing", 3)
	print("RIDE (%s): ends %s, limp %s, the train %.0f m along at %.1f m/s" % [tag, seen(), player.is_limp, train.travelled, train.pace])


# Waits for the bridge and takes `count` pictures as it passes him.
func _bridge(count: int) -> void:
	var bridge := stage.find_child("BridgeLow*", true, false) as Node3D
	var taken := 0
	var was := bridge.global_position.z - player.global_position.z
	for i in 4000:
		await frames(1)
		var off := bridge.global_position.z - player.global_position.z
		if off > 0.0 and off < 14.0 and i % 5 == 0 and taken < count - 1:
			await snap(true)
			taken += 1
		if (off < -3.0 and was >= -3.0) or player.is_limp:
			await snap(true)
			break
		was = off


func lineside() -> void:
	await fresh()
	# A line along Z with a turnout, a crossing, a signal each way, and the rest beside it
	for z: float in [-45.0, -35.0, -25.0, 5.0, 15.0, 25.0, 35.0]:
		lay("track_straight", Vector3(0, 0, z))
	lay("track_points", Vector3(0, 0, -10.0))
	var branch := Vector3(40.0 - 40.0 * cos(asin(18.0 / 40.0)), 0.0, 0.0)
	var curve := lay("track_curve", branch, asin(18.0 / 40.0))
	lay("buffer_stop", curve.to_global(Vector3(0.6, 0.0, 12.0)) , asin(18.0 / 40.0) + deg_to_rad(15.0))
	lay("buffer_stop", Vector3(0, 0, 40.2))
	lay("level_crossing", Vector3(0, 0, -30.0))
	var danger := lay("signal_semaphore", Vector3(-3.0, 0, -4.0), PI) as TrainSignal
	var clear := lay("signal_semaphore", Vector3(-3.0, 0, -22.0), PI) as TrainSignal
	clear.clear = true
	lay("water_tower", Vector3(-6.0, 0, 12.0))
	lay("water_column", Vector3(-2.9, 0, 18.0))
	lay("loading_gauge", Vector3(0, 0, 26.0))
	lay("bridge_low", Vector3(0, 0, -44.0))
	for z: float in [-40.0, -10.0, 20.0]:
		lay("telegraph_pole", Vector3(-5.0, 0, z))
	lay("wagon_tank", Vector3(0, 0, 33.0))
	lay("wagon_finds", Vector3(0, 0, 18.0))
	await frames(40)
	for shot: Array in [[Vector3(26, 16, 30), Vector3(0, 1, 2)], [Vector3(16, 5, -24), Vector3(2, 1, -6)], [Vector3(9, 4, -15), Vector3(-3, 4.5, -13)],
			[Vector3(12, 6, 30), Vector3(-2, 3, 16)], [Vector3(-14, 5, -22), Vector3(0, 2, -40)], [Vector3(9, 3.5, 44), Vector3(0, 2, 26)]]:
		view(shot[0], shot[1], 42.0)
		await frames(3)
		await snap(true)
	sheet("lineside", 2)
	print("SIGNALS: at danger the arm is turned %.0f degrees, clear %.0f" % [rad_to_deg(-(danger.get_node("Model/Arm") as Node3D).rotation.z), rad_to_deg(-(clear.get_node("Model/Arm") as Node3D).rotation.z)])


func yard() -> void:
	if stage:
		stage.queue_free()
		await process_frame
	stage = (load("res://test_yard.tscn") as PackedScene).instantiate() as Node3D
	root.add_child(stage)
	player = stage.get_node("Player")
	touch = stage.get_node("HUD/TouchControls")
	touch.visible = false
	(stage.get_node("HUD/Menu") as CanvasItem).visible = false
	touch.set_process_input(false)
	player.set_process_unhandled_input(false)
	cam = Camera3D.new()
	cam.far = 900.0
	stage.add_child(cam)
	cam.make_current()
	train = stage.find_child("Train", true, false) as Train
	await frames(30)
	# He is put on the platform, out of the way
	player.global_position = Vector3(-14.0, 1.4, 53.0)
	player._reset_visuals()
	for shot: Array in [[Vector3(-22, 12, 28), Vector3(-6, 1, 58)], [Vector3(34, 9, 38), Vector3(6, 2, 58.5)], [Vector3(-27, 3.2, 55.5), Vector3(-6, 2.2, 57.5)],
			[Vector3(10, 30, 86), Vector3(10, 0, 58)], [Vector3(60, 7, 67), Vector3(28, 3, 58.5)], [Vector3(-2, 3.0, 50.5), Vector3(-12, 2.2, 56)]]:
		view(shot[0], shot[1], 46.0)
		await frames(4)
		await snap(true)
	sheet("yard_halt", 2)
	# The train leaves: the signal drops, it goes under the bridge to the end of the line
	view(Vector3(40, 8, 44), Vector3(22, 2.5, 58.5), 50.0)
	train.start()
	for i in 6:
		await frames(100)
		await snap(true)
	sheet("yard_leaving", 3)
	print("YARD: the train is %.1f m along its %.0f m, going %.1f m/s, running %s" % [train.travelled, train.distance, train.pace, train.running])
	# And the other staging: back at the halt, the world goes by
	train.start()
	await frames(900)
	var line_node := stage.find_child("Railway", true, false) as TrainScenery
	line_node.settle()
	train.world_moves = true
	train.start()
	view(Vector3(-2, 7, 44), Vector3(-2, 2.5, 58.5), 55.0)
	for i in 6:
		await frames(60)
		await snap(true)
	sheet("yard_world_goes_by", 3)
	print("YARD, the world going by: train %.1f m along (it does not move), the line has gone %.1f m" % [train.travelled, line_node.gone])
