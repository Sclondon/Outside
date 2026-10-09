extends SceneTree
## Not part of the game. Runs a crocodile through what it does of its own accord, with nothing drawn, and
## says whether each thing happened: it floats with only its eyes and nostrils out; it notices him; when he
## comes to the water's edge it goes under and comes at him, drawing rings on the water; it lunges and has
## him; when he gets away up the bank it follows a few metres, gives up and goes back to the water; a shot,
## a stone and a flare each send it under; a docile one never hunts; put on the bank it basks with its
## mouth open; and with no water at all it lies where it is put and is as dangerous there.
## godot --headless --path . --fixed-fps 60 --script tools/crocodile_test.gd
## Ends with PASSED or FAILED (and exits 0 or 1).

## Where he stands at the water's edge, and well back from it.
const EDGE := Vector3(-0.6, 0.2, 0.0)
const AWAY := Vector3(-30.0, 0.2, 20.0)

var stage: Node3D
var pond: Pool
var boy: Player
var failed := 0


func _initialize() -> void:
	stage = Node3D.new()
	root.add_child(stage)
	# The same pond as tools/crocodile_sheets.gd has: dry land to the west, a bank sloping down into it,
	# and its floor a metre and a half down; and level ground a long way off, with no water near it.
	box(Vector3(0, -1, 90), Vector3(200, 2, 40))
	box(Vector3(-20, -0.925, 0), Vector3(40, 2.15, 30))
	var fall := atan2(1.65, 6.0)
	box(Vector3(3.0 - sin(fall) * 0.5, -0.675 - cos(fall) * 0.5, 0), Vector3(6.3, 1.0, 30), -fall)
	box(Vector3(19, -2.5, 0), Vector3(26.5, 2, 30))
	pond = Pool.new()
	pond.size = Vector3(30, 2.0, 30)
	pond.position = Vector3(15, 0, 0)
	stage.add_child(pond)
	run.call_deferred()


func box(at: Vector3, size: Vector3, tilt := 0.0) -> void:
	var body := StaticBody3D.new()
	var shape := BoxShape3D.new()
	shape.size = size
	var collider := CollisionShape3D.new()
	collider.shape = shape
	body.add_child(collider)
	body.position = at
	body.rotation.z = tilt
	stage.add_child(body)


func check(what: String, passed: bool, detail := "") -> void:
	print("PASS " if passed else "FAIL ", what, "  ", detail)
	if not passed:
		failed += 1


## Lets `seconds` go by, or fewer if `until` comes true first. Returns whether it did.
func wait(seconds: float, until := Callable()) -> bool:
	for i in int(seconds * 60.0):
		await physics_frame
		await process_frame
		if until.is_valid() and until.call():
			return true
	return not until.is_valid()


func croc(at: Vector3, yaw := PI * 0.5, docile := false) -> Crocodile:
	var made := Crocodile.new()
	made.position = at
	made.rotation.y = yaw
	made.voice = false
	made.docile = docile
	stage.add_child(made)
	made.target = boy
	return made


func run() -> void:
	for action: StringName in InputMap.get_actions():
		if not String(action).begins_with("ui_"):
			InputMap.action_erase_events(action)
	var touch := TouchControls.new()
	touch.visible = false
	stage.add_child(touch)
	touch.set_process_input(false)
	boy = load("res://player.tscn").instantiate()
	boy.position = AWAY
	stage.add_child(boy)
	boy.set_process_unhandled_input(false)
	boy.set_physics_process(false)

	# Floating: left alone in the water it lies still, with its eyes and its nostrils out and the rest of it under.
	var beast := croc(Vector3(12, -0.5, 1.0), -PI * 0.5)
	await wait(6.0)
	var eyes := beast._rig.eyes().y
	var nose := (beast._rig._head.global_transform * Vector3(0.0, 0.045, 0.465)).y
	var back := (beast._rig._body.global_transform * Vector3(0.0, 0.20, -0.1)).y
	check("floats", beast.state == Crocodile.State.FLOAT and beast.afloat > 0.95 and beast.velocity.length() < 0.1, "state %d, afloat %.2f, going %.2f m/s" % [beast.state, beast.afloat, beast.velocity.length()])
	check("only its eyes and its nostrils are out of the water", eyes > 0.0 and eyes < 0.09 and nose > 0.0 and nose < 0.09 and back < -0.01,
			"eyes %.3f m and nostrils %.3f m above it, the top of its back %.3f" % [eyes, nose, back])
	check("is not after him", not beast.is_in_group(&"pursuers") and not beast.is_hunting())

	# He comes in sight, well back from the water: it watches him and does no more.
	boy.global_position = Vector3(-4.0, 0.2, 0.0)
	await wait(4.0)
	check("notices him", beast.gaze == boy and beast.state == Crocodile.State.FLOAT, "state %d" % beast.state)
	var turned := absf(angle_difference(beast.facing_yaw, atan2(boy.global_position.x - beast.global_position.x, boy.global_position.z - beast.global_position.z)))
	check("turns to keep him in view", turned < 0.5 or absf(beast._rig._look.x) > 0.2, "%.2f radians off him, its head turned %.2f" % [turned, beast._rig._look.x])

	# He comes to the water's edge: it goes under and comes at him, and the water shows where.
	boy.global_position = EDGE
	var stalked := await wait(3.0, func() -> bool: return beast.state == Crocodile.State.STALK and beast.submerged)
	check("stalks him when he comes to the water's edge", stalked and beast.submerged and beast.is_in_group(&"pursuers"), "state %d, under %s" % [beast.state, beast.submerged])
	var seen := {}
	var rings := [0]
	var deepest := [0.0]
	var hit := [false]
	beast.caught.connect(func() -> void: hit[0] = true)
	var had := await wait(15.0, func() -> bool:
		seen[beast.state] = true
		rings[0] = maxi(rings[0], pond.water._rings.size())
		deepest[0] = maxf(deepest[0], -beast.global_position.y)
		return hit[0])
	check("comes under water", deepest[0] > 0.9, "its feet were %.2f m under" % deepest[0])
	check("draws rings on the water as it comes", rings[0] >= 3, "%d rings at once" % rings[0])
	check("stops short and lunges", seen.has(Crocodile.State.WIND_UP) and seen.has(Crocodile.State.LUNGE), "states seen %s" % str(seen.keys()))
	check("has him at the water's edge", had, "state %d, its snout %.2f m from him" % [beast.state, beast._rig.snout().distance_to(boy.global_position)])
	check("is faster in the water than he can swim", beast.chase_speed > boy.swim_speeds.y + 0.5 and beast.chase_speed > boy.dive_speeds.y + 0.5 and beast.run_speed < boy.run_speed,
			"it swims at %.1f and runs at %.1f; he swims at %.1f and runs at %.1f" % [beast.chase_speed, beast.run_speed, boy.swim_speeds.y, boy.run_speed])
	# Afterwards it goes back to the water, and is not after anyone.
	boy.global_position = AWAY
	var home := await wait(40.0, func() -> bool: return beast.state == Crocodile.State.FLOAT and beast.afloat > 0.9)
	check("goes back to the water afterwards", home and not beast.is_in_group(&"pursuers"), "state %d at %s" % [beast.state, beast.global_position])
	beast.queue_free()

	# He gets away up the bank as it lunges: it comes after him a few metres, no more, and goes back.
	beast = croc(Vector3(9, -0.5, -1.0), -PI * 0.5)
	boy.global_position = EDGE
	await wait(20.0, func() -> bool: return beast.state == Crocodile.State.LUNGE)
	seen.clear()
	var furthest := [0.0]
	hit[0] = false
	beast.caught.connect(func() -> void: hit[0] = true)
	var back_in := await wait(60.0, func() -> bool:
		# (he runs from it, straight up the bank, a little faster than it can)
		if boy.global_position.x > -24.0:
			boy.global_position.x -= 4.4 / 60.0
		seen[beast.state] = true
		if beast.afloat < 0.1:
			furthest[0] = maxf(furthest[0], 0.6 - beast.global_position.x)
		return beast.state == Crocodile.State.FLOAT and beast.afloat > 0.9)
	check("comes up the bank after him", furthest[0] > 1.0 and seen.has(Crocodile.State.CHASE), "%.1f m from the water; states seen %s" % [furthest[0], str(seen.keys())])
	check("gives up after a few metres", furthest[0] < beast.reach + 2.0 and not hit[0], "%.1f m from the water, of %.1f; caught him: %s" % [furthest[0], beast.reach, hit[0]])
	check("returns to the water", back_in and seen.has(Crocodile.State.RETURN), "state %d at %s" % [beast.state, beast.global_position])

	# A shot: it goes under and stays there, though he is standing at the edge.
	boy.global_position = AWAY
	await wait(8.0)
	beast.shot(boy, beast.global_position, Vector3.RIGHT, 20.0)
	boy.global_position = EDGE
	await wait(4.0)
	check("goes under when it is shot", beast.state == Crocodile.State.HIDE and beast.submerged and not beast.is_in_group(&"pursuers") and beast.global_position.y < -0.9,
			"state %d, its feet %.2f m under" % [beast.state, -beast.global_position.y])
	var again := await wait(beast.shot_time + 12.0, func() -> bool: return beast.is_hunting())
	check("comes again when it has got over it", again, "state %d" % beast.state)
	# A stone thrown in beside it.
	boy.global_position = AWAY
	await wait(20.0, func() -> bool: return beast.state == Crocodile.State.FLOAT)
	await wait(beast.rest + 1.0)
	var stone := RigidBody3D.new()
	stone.add_to_group(&"throwable")
	var round := SphereShape3D.new()
	round.radius = 0.08
	var collider := CollisionShape3D.new()
	collider.shape = round
	stone.add_child(collider)
	stone.position = beast.global_position + Vector3(-1.0, 3.0, 1.2)
	stone.linear_velocity = Vector3(2.0, -1.0, -1.0)
	stage.add_child(stone)
	var dived := await wait(3.0, func() -> bool: return beast.state == Crocodile.State.HIDE)
	check("a stone thrown near it sends it under", dived, "state %d" % beast.state)
	stone.queue_free()
	# A flare.
	await wait(20.0, func() -> bool: return beast.state == Crocodile.State.FLOAT)
	var flare := Node3D.new()
	flare.add_to_group(&"flares")
	flare.position = beast.global_position + Vector3(-2.0, 0.5, 0.0)
	stage.add_child(flare)
	var from := beast.global_position
	await wait(4.0)
	check("is shy of fire", beast.state == Crocodile.State.HIDE and beast.global_position.distance_to(flare.global_position) > 3.0,
			"state %d, %.1f m from it (it began 2 m off)" % [beast.state, beast.global_position.distance_to(flare.global_position)])
	flare.queue_free()
	beast.queue_free()

	# A docile one: he stands at the edge, and wades in, and nothing happens.
	beast = croc(Vector3(8, -0.5, 0.0), -PI * 0.5, true)
	boy.global_position = EDGE
	hit[0] = false
	var hunted := [false]
	beast.caught.connect(func() -> void: hit[0] = true)
	await wait(8.0, func() -> bool:
		hunted[0] = hunted[0] or beast.is_hunting() or beast.is_in_group(&"pursuers")
		return false)
	boy.global_position = Vector3(4.5, -1.2, 0.0)
	await wait(8.0, func() -> bool:
		hunted[0] = hunted[0] or beast.is_hunting() or beast.is_in_group(&"pursuers")
		return false)
	check("a docile one never hunts", not hunted[0] and not hit[0] and beast.gaze == boy, "state %d" % beast.state)
	beast.queue_free()

	# Put on the bank, it basks: on its belly, its mouth open; and in time it slides back into the water.
	boy.global_position = AWAY
	beast = croc(Vector3(-1.4, 0.3, -3.0), 0.0, true)
	beast.bask_for = Vector2(14.0, 14.0)
	await wait(1.0)
	beast._timer = 14.0
	await wait(9.0)
	check("basks on the bank with its mouth open", beast.state == Crocodile.State.BASK and beast.afloat < 0.1 and beast.jaws > 0.3 and beast._rig._mouth > 0.3 and beast.lift < 0.1,
			"state %d, jaws %.2f, at %s" % [beast.state, beast._rig._mouth, beast.global_position])
	check("lies facing the water", absf(angle_difference(beast.facing_yaw, PI * 0.5)) < 0.5, "facing %.2f" % beast.facing_yaw)
	var slid := await wait(60.0, func() -> bool: return beast.state == Crocodile.State.FLOAT and beast.afloat > 0.9)
	check("slides back into the water", slid, "state %d at %s" % [beast.state, beast.global_position])
	# And out again, when it has floated long enough.
	beast._timer = 0.5
	var out := await wait(60.0, func() -> bool: return beast.state == Crocodile.State.BASK)
	check("hauls out to bask again", out and beast.afloat < 0.3, "state %d at %s, afloat %.2f" % [beast.state, beast.global_position, beast.afloat])
	beast.queue_free()

	# No water anywhere near: it lies where it is put, and lunges at him if he comes close.
	beast = croc(Vector3(0, 0.1, 90), 0.0)
	await wait(3.0)
	check("with no water it lies where it is put", beast.pool == null and beast.state == Crocodile.State.BASK and beast.global_position.distance_to(Vector3(0, 0, 90)) < 0.5, "state %d" % beast.state)
	hit[0] = false
	beast.caught.connect(func() -> void: hit[0] = true)
	boy.global_position = Vector3(0.5, 0.05, 93.6)
	var bitten := await wait(8.0, func() -> bool: return hit[0])
	check("and is as dangerous there", bitten, "state %d" % beast.state)
	boy.global_position = AWAY
	var settled := await wait(40.0, func() -> bool: return beast.state == Crocodile.State.BASK)
	check("and goes back to where it lives", settled and beast.global_position.distance_to(Vector3(0, 0, 90)) < 1.0, "state %d, %.1f m from home" % [beast.state, beast.global_position.distance_to(Vector3(0, 0, 90))])

	print("PASSED" if failed == 0 else "FAILED (%d)" % failed)
	quit(1 if failed > 0 else 0)
