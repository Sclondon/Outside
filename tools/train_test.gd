extends SceneTree
## Not part of the game. Rides a train with nothing drawn, and says what happened.
## godot --headless --path . --fixed-fps 60 --script tools/train_test.gd
##
## A train of six stands by a platform on level ground. The Player walks from the
## platform onto the brake van, goes up its ladder to the roof, and the train
## starts. He runs forward along the roofs, jumping each gap, to the middle of
## the first carriage; ducks while a bridge goes over; stands there (does he
## slide?); jumps on the spot (does he come down where he went up?); goes on to
## the front of the carriage and down its ladder; across to the tender's
## ladder, up, over the coal and into the cab. Then, put back on the roof, he
## stands up under the next bridge, to be knocked off. Then all of the riding
## again with the train standing still and the world going by; then he stands
## on a roof round a curve. It ends PASSED or FAILED.
##
## Where he is, is given as the train sees it: metres to the right of its
## middle, above the ground, and ahead of its front buffers (so everything on
## it is behind: a minus number).

const AHEAD := Vector3(0.0, 0.0, 1.0)

var train: Train
var scenery: TrainScenery
var player: Player
var touch: TouchControls
var stage: Node3D
var bridges: Array[Node3D] = []
var failed := 0
# How low he got, as the train sees it, and the furthest he was from the middle of the train sideways.
var lowest := 100.0
var widest := 0.0


func _initialize() -> void:
	run.call_deferred()


func check(what: String, good: bool, note := "") -> void:
	print("%s  %s%s" % ["ok   " if good else "FAIL ", what, "   (%s)" % note if note != "" else ""])
	if not good:
		failed += 1


func build(world_moves: bool) -> void:
	if stage:
		stage.queue_free()
		await physics_frame
	stage = Node3D.new()
	root.add_child(stage)
	var ground := StaticBody3D.new()
	var slab := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(400.0, 2.0, 4000.0)
	slab.shape = shape
	ground.add_child(slab)
	ground.position = Vector3(0.0, -1.0, 1000.0)
	stage.add_child(ground)
	scenery = TrainScenery.new()
	scenery.span = 240.0
	scenery.position = Vector3(0.0, 0.0, -25.0)
	stage.add_child(scenery)
	train = Train.new()
	train.consist = PackedStringArray(["loco", "tender", "carriage", "carriage_third", "van_goods", "van_brake"])
	train.speed = 8.0
	train.distance = 1500.0
	train.world_moves = world_moves
	train.scenery = scenery
	stage.add_child(train)
	# A platform beside the brake van, and bridges over the line (when the world moves, one that comes round again)
	var van := -train._behind[5]
	lay("halt_platform", Vector3(-4.62, 0.0, van - 2.8), stage)
	bridges.clear()
	if world_moves:
		bridges.append(lay("bridge_low", Vector3(0.0, 0.0, 100.0), scenery))
	else:
		for z: float in [150.0, 330.0, 520.0]:
			bridges.append(lay("bridge_low", Vector3(0.0, 0.0, z), stage))
	var layer := CanvasLayer.new()
	stage.add_child(layer)
	touch = TouchControls.new()
	layer.add_child(touch)
	player = (load("res://player.tscn") as PackedScene).instantiate() as Player
	player.position = Vector3(-3.2, 1.35, van - 2.8)
	stage.add_child(player)
	touch.set_process_input(false)
	player.set_process_unhandled_input(false)
	for action: StringName in InputMap.get_actions():
		if not String(action).begins_with("ui_"):
			InputMap.action_erase_events(action)
			Input.action_release(action)
	await frames(30)


func lay(what: String, at: Vector3, under: Node) -> Node3D:
	var made := (load("res://props/%s.tscn" % what) as PackedScene).instantiate() as Node3D
	made.position = at
	under.add_child(made)
	return made


## Where he is, as the train sees it.
func seen() -> Vector3:
	var at := player.global_position
	return Vector3(at.x, at.y, at.z - train.travelled)


func steer(world: Vector3) -> void:
	# (there is no camera: the stick is the world's own x and z)
	touch.move = Vector2(world.x, world.z)


func frames(count: int, heading := Vector3.INF) -> void:
	for i in count:
		if heading != Vector3.INF:
			steer(heading)
		await physics_frame
		if train.ridden:
			lowest = minf(lowest, player.global_position.y)
			widest = maxf(widest, absf(player.global_position.x))


func rest() -> void:
	touch.move = Vector2.ZERO
	touch.jump_held = false
	touch.duck_held = false


func place(at: Vector3) -> void:
	rest()
	if player.is_limp:
		player.recover()
	player.state = Player.State.FREE
	player.global_position = at
	player.velocity = Vector3.ZERO
	player._reset_visuals()


## Whether there is something to stand on a little way ahead of him, not far below his feet.
func floor_ahead(far: float) -> bool:
	var from := player.global_position + AHEAD * far + Vector3.UP * 0.6
	var query := PhysicsRayQueryParameters3D.create(from, from + Vector3.DOWN * 1.3, 1)
	return not player.get_world_3d().direct_space_state.intersect_ray(query).is_empty()


## Walks or runs to a place on the train (x, and how far ahead of its front), jumping whatever gap is in the way.
## Says whether he got there.
func go(x: float, ahead: float, strength := 1.0, jumps := true, limit := 1200) -> bool:
	for i in limit:
		var at := seen()
		var to := Vector3(x - at.x, 0.0, ahead - at.z)
		if to.length() < 0.25:
			rest()
			return true
		var heading := to.normalized() * strength
		# (the roof ends ahead: jump, and hold it for the whole height)
		if jumps and player.is_on_floor() and absf(to.z) > 1.0 and not floor_ahead(0.55 * signf(to.z)):
			player._queue_jump()
			touch.jump_held = true
		elif player.is_on_floor():
			touch.jump_held = false
		if player.state == Player.State.HANG:
			player._queue_jump()
		await frames(1, heading)
		if OS.has_environment("TRACE") and i % 6 == 0:
			print("   ", seen(), " state ", player.state, " floor ", player.is_on_floor())
		if player.is_limp:
			break
	rest()
	return false


func ride(world_moves: bool) -> void:
	var how := "THE WORLD MOVES" if world_moves else "THE TRAIN MOVES"
	print("\n== %s ==" % how)
	await build(world_moves)
	lowest = 100.0
	widest = 0.0
	var carriage := -train._behind[2]
	var tender := -train._behind[1]
	var loco := -train._behind[0]
	var van := -train._behind[5]
	print("train: %d vehicles, %.1f m long; he starts on the platform at %s" % [train.vehicles.size(), train.length(), seen()])
	# Onto the brake van's platform, to the foot of its ladder, and up
	check("from the platform onto the brake van", await go(0.85, van - 2.9, 0.6), str(seen()))
	for i in 90:
		await frames(1, AHEAD)
		if player.state == Player.State.LADDER:
			break
	check("takes the ladder", player.state == Player.State.LADDER)
	for i in 400:
		touch.move = Vector2(0.0, -1.0)
		await frames(1)
		if player.state != Player.State.LADDER:
			break
	rest()
	await frames(20)
	check("up the ladder onto the roof", player.is_on_floor() and seen().y > 3.2, str(seen()))
	check("the train knows he is aboard", train.ridden == train.vehicles[5])
	# The train starts. Along the roofs to the middle of the first carriage
	train.start()
	await frames(120)
	check("to the middle of the brake van's roof", await go(0.0, van + 1.0), str(seen()))
	var got := await go(0.0, carriage)
	check("along three roofs and over three gaps, at %.1f m/s" % train.pace, got and train.ridden == train.vehicles[2], "%s on %s" % [seen(), train.ridden.name if train.ridden else "nothing"])
	# Ducks under the bridge
	var bridge := _next_bridge()
	touch.duck_held = true
	var under := false
	for i in 3000:
		await frames(1)
		var off := _bridge_ahead(bridge)
		if absf(off) < 1.0:
			under = true
		if off < -4.0 or player.is_limp:
			break
	touch.duck_held = false
	# (kept down that long without moving he has sat down: up again)
	player.stand_up()
	await frames(150)
	check("ducks, and the bridge goes over him", under and not player.is_limp and train.ridden == train.vehicles[2], str(seen()))
	# Standing still: does he slide?
	await frames(30)
	var stood := seen()
	await frames(120)
	var slid := (seen() - stood).length()
	check("stands still on it for two seconds", slid < 0.05, "moved %.3f m as the train sees it, while it went %.1f m" % [slid, train.pace * 2.0])
	# A jump on the spot: does he come down where he went up?
	var from := seen()
	player._queue_jump()
	touch.jump_held = true
	await frames(5)
	var highest := 0.0
	for i in 120:
		await frames(1)
		highest = maxf(highest, seen().y - from.y)
		if player.is_on_floor():
			break
	rest()
	await frames(10)
	var drift := Vector2(seen().x - from.x, seen().z - from.z).length()
	check("jumps on the spot and comes down on it", drift < 0.15 and highest > 0.8, "%.2f m up, came down %.3f m away" % [highest, drift])
	# To the front of the carriage, onto its ladder from above, and down to the platform at its end
	await go(0.95, carriage + 3.2, 0.6)
	for i in 240:
		await frames(1, AHEAD * 0.5)
		if player.state == Player.State.LADDER:
			break
	check("onto the ladder from the roof", player.state == Player.State.LADDER, str(seen()))
	await frames(70)
	for i in 400:
		touch.move = Vector2(0.0, 1.0)
		await frames(1)
		if player.state != Player.State.LADDER:
			break
	rest()
	await frames(20)
	check("down the ladder to the end platform", player.is_on_floor() and absf(seen().y - 1.3) < 0.1 and train.ridden == train.vehicles[2], str(seen()))
	# Across the couplings to the tender's ladder, up, over the coal and into the cab
	await go(0.25, carriage + 6.2, 0.6)
	for i in 120:
		await frames(1, (AHEAD + Vector3(0.05, 0.0, 0.0)).normalized())
		if player.state == Player.State.LADDER:
			break
	check("across the gap onto the tender's ladder", player.state == Player.State.LADDER, str(seen()))
	for i in 400:
		touch.move = Vector2(0.0, -1.0)
		await frames(1)
		if player.state != Player.State.LADDER:
			break
	rest()
	await frames(20)
	check("up onto the tender", player.is_on_floor() and train.ridden == train.vehicles[1], str(seen()))
	# (at a walk: run off the front of the coal and he catches the edge of the cab roof, which is in front of his face)
	got = await go(0.0, tender + 0.6) and await go(0.0, loco - 3.6, 0.45, false)
	await frames(30)
	check("over the coal and into the cab", got and train.ridden == train.vehicles[0] and absf(seen().y - 1.8) < 0.1, str(seen()))
	check("never fell through or off", lowest > 1.2 and widest < 1.5, "lowest %.2f m above the ground, furthest %.2f m from the middle" % [lowest, widest])
	print("ENDS at %s (as the train sees it) on %s, the train %.0f m along at %.1f m/s" % [seen(), train.ridden.name if train.ridden else "nothing", train.travelled, train.pace])
	# Back on the roof, and standing up this time
	place(Vector3(0.0, 3.9, carriage + train.travelled))
	await frames(40)
	bridge = _next_bridge()
	for i in 3600:
		if _bridge_ahead(bridge) > 10.0:
			break
		await frames(1)
	var was_aboard := train.ridden != null
	var lost := [false]
	train.lost.connect(func(_who: Player) -> void: lost[0] = true)
	for i in 3600:
		await frames(1)
		if _bridge_ahead(bridge) < -6.0 or player.is_limp:
			break
	check("standing, the bridge knocks him down", was_aboard and player.is_limp and lost[0], "limp %s, told %s" % [player.is_limp, lost[0]])
	await frames(90)
	print("  he lies at %s" % (player._rig.limp_position() - Vector3(0.0, 0.0, train.travelled)))
	train.stop()
	for i in 900:
		await frames(1)
		if train.pace == 0.0:
			break
	check("the train stops", train.pace == 0.0)


func _next_bridge() -> Node3D:
	var best: Node3D = null
	for bridge in bridges:
		if bridge.global_position.z > player.global_position.z + 12.0 and (best == null or bridge.global_position.z < best.global_position.z):
			best = bridge
	return best if best else bridges[0]


# How far ahead of him the bridge is (behind, less than nothing).
func _bridge_ahead(bridge: Node3D) -> float:
	return bridge.global_position.z - player.global_position.z


## Round a curve (a Path3D: a quarter of a circle of 90 m), and a train made from an item of a level's layout.
func curve() -> void:
	print("
== ROUND A CURVE ==")
	await build(false)
	var path := Path3D.new()
	path.curve = Curve3D.new()
	for i in 19:
		var a := PI * 0.5 * i / 18.0
		path.curve.add_point(Vector3(90.0 - 90.0 * cos(a), 0.0, 90.0 * sin(a)))
	stage.add_child(path)
	train.path = path
	train.distance = 0.0
	var carriage := train.vehicles[2]
	train.start()
	await frames(200)
	place(carriage.global_transform * Vector3(0.0, 3.9, 0.0))
	await frames(60)
	var stood := carriage.global_transform.affine_inverse() * player.global_position
	var turned := carriage.global_basis.z
	await frames(360)
	var now := carriage.global_transform.affine_inverse() * player.global_position
	check("stands on a carriage roof round the curve", (now - stood).length() < 0.25 and train.ridden == carriage,
			"moved %.3f m on it while it turned %.0f degrees at %.1f m/s" % [(now - stood).length(), rad_to_deg(turned.angle_to(carriage.global_basis.z)), train.pace])
	for i in 1200:
		await frames(1)
		if not train.running:
			break
	check("the train stops at the end of the path", not train.running and train.pace == 0.0 and absf(train.travelled - path.curve.get_baked_length()) < 0.1,
			"%.1f m along a path of %.1f m" % [train.travelled, path.curve.get_baked_length()])
	var made := Train.from_item({"engine": true, "carriages": 2, "wagons": 3, "brake": true, "speed": 5.0, "run": 30.0, "round": 2, "staging": 0, "running": true})
	stage.add_child(made)
	made.position = Vector3(40.0, 0.0, 0.0)
	await frames(600)
	check("a train from a level's layout runs its 30 m and stops", made.vehicles.size() == 8 and absf(made.travelled - 30.0) < 0.05 and not made.running,
			"%d vehicles (%s), %.1f m along" % [made.vehicles.size(), ", ".join(made.consist), made.travelled])
	made.start()
	await frames(600)
	check("started again, it goes back", absf(made.travelled) < 0.05, "%.1f m along" % made.travelled)


func run() -> void:
	await ride(false)
	await ride(true)
	await curve()
	print("\n%s" % ("PASSED" if failed == 0 else "FAILED: %d" % failed))
	quit(0 if failed == 0 else 1)
