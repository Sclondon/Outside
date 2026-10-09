extends SceneTree
## Not part of the game. Runs a swarm of scarabs with nothing drawn and says whether each thing happened:
## they come out of the nest, go for the boy, are held off by a torch, catch him when he stands without
## one, cannot get at him up on a block or across water and go home, go over a low step, and the harmless
## ones wander. Then it runs a tunnel of cobwebs: one tears when he goes through it and one burns.
## godot --headless --path . --fixed-fps 60 --script tools/scarab_test.gd
## Ends with PASSED or FAILED (and exits 0 or 1).

var stage: Node3D
var failed := 0
var boy: Player
var caught := 0
var home := 0


func _initialize() -> void:
	stage = Node3D.new()
	root.add_child(stage)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-48.0, -35.0, 0.0)
	stage.add_child(sun)
	box(Vector3(0, -1, 0), Vector3(80, 2, 80))
	# Something to get up onto, too high for them
	box(Vector3(7, 0.75, 6), Vector3(2, 1.5, 2))
	# A step they go over, right across their way
	box(Vector3(-4, 0.2, 0), Vector3(1.0, 0.4, 30))
	run.call_deferred()


func box(at: Vector3, size: Vector3) -> StaticBody3D:
	var body := StaticBody3D.new()
	var shape := BoxShape3D.new()
	shape.size = size
	var collider := CollisionShape3D.new()
	collider.shape = shape
	body.add_child(collider)
	body.position = at
	stage.add_child(body)
	return body


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


func put(at: Vector3) -> void:
	boy.global_position = at
	boy.velocity = Vector3.ZERO


func swarm_at(at: Vector3, count := 100) -> ScarabSwarm:
	var swarm := ScarabSwarm.new()
	swarm.count = count
	swarm.voice = false
	swarm.position = at
	stage.add_child(swarm)
	swarm.target = boy
	swarm.caught.connect(func() -> void: caught += 1)
	swarm.went_home.connect(func() -> void: home += 1)
	return swarm


## The nearest any beetle on the ground is to a place, over the ground.
func nearest(swarm: ScarabSwarm, to: Vector3) -> float:
	var least := INF
	for i in swarm.count:
		if swarm._state[i] == ScarabSwarm.OUT:
			least = minf(least, Vector2(swarm._x[i] - to.x, swarm._z[i] - to.z).length())
	return least


func run() -> void:
	for action: StringName in InputMap.get_actions():
		if not String(action).begins_with("ui_"):
			InputMap.action_erase_events(action)
	var touch := TouchControls.new()
	touch.visible = false
	stage.add_child(touch)
	touch.set_process_input(false)
	boy = load("res://player.tscn").instantiate()
	boy.position = Vector3(8, 0.05, 0)
	boy.rest_enabled = false
	stage.add_child(boy)
	boy.set_process_unhandled_input(false)
	await wait(0.5)

	# A torch stuck in the ground beside him.
	var torch := HandTorch.new()
	torch.position = boy.position + Vector3(0.3, 0.0, 0.0)
	torch.freeze = true
	stage.add_child(torch)
	var swarm := swarm_at(Vector3(0, 0.0, 0))
	await wait(0.3)
	check("they stay in the nest until they are let out", swarm.out == 0 and not swarm.chasing)
	swarm.chasing = true
	var all_out := await wait(5.0, func() -> bool: return swarm.out == swarm.count)
	check("they come out", all_out, "%d of %d" % [swarm.out, swarm.count])
	check("their front is a pursuer", swarm.front.is_in_group(&"pursuers") and swarm.front.chasing)
	var came := await wait(6.0, func() -> bool: return nearest(swarm, boy.global_position) < 4.0)
	check("they go for him", came, "nearest %.1f m" % nearest(swarm, boy.global_position))

	# Held off: none on him, none near the flame, for as long as it burns.
	var worst := [INF, 0, 0]
	await wait(8.0, func() -> bool:
		worst[0] = minf(worst[0], nearest(swarm, torch.global_position))
		worst[1] = maxi(worst[1], swarm.on_him)
		worst[2] = maxi(worst[2], swarm.held_off)
		return false)
	check("a torch holds them off", worst[1] == 0 and caught == 0 and worst[0] > swarm.fire_reach * 0.6 and worst[2] > 20,
			"nearest to the flame %.2f m, most on him %d, most held off %d, caught %d" % [worst[0], worst[1], worst[2], caught])
	check("and they do not tire of it", swarm.chasing)

	# The torch goes out: they have him.
	torch.lit = false
	var got := await wait(8.0, func() -> bool: return caught > 0)
	check("without it they catch him", got and caught == 1, "on him %d" % swarm.on_him)
	swarm.reset()
	check("put back, none are out", swarm.out == 0 and not swarm.front.is_in_group(&"pursuers"))

	# Up on a block: they mill about under him, give up and go home.
	caught = 0
	home = 0
	put(Vector3(7, 1.6, 6))
	await wait(0.6)
	swarm.give_up_after = 3.0
	swarm.chasing = true
	var gone := await wait(25.0, func() -> bool: return home > 0)
	check("up out of reach they give up and go home", gone and caught == 0 and swarm.out == 0, "home %d, caught %d, out %d, he is at %s" % [home, caught, swarm.out, boy.global_position])

	# Over a step.
	put(Vector3(-8, 0.05, 0))
	await wait(0.4)
	var highest := [0.0]
	swarm.chasing = true
	got = await wait(12.0, func() -> bool:
		for i in swarm.count:
			if swarm._state[i] == ScarabSwarm.OUT:
				highest[0] = maxf(highest[0], swarm._y[i])
		return caught > 0)
	check("they go up and over a step to him", got and highest[0] > 0.35, "highest %.2f m, nearest %.1f, on him %d, mode %d" % [highest[0], nearest(swarm, boy.global_position), swarm.on_him, swarm._mode])
	swarm.reset()

	# Across water.
	var pool := Pool.new()
	pool.size = Vector3(6, 1, 6)
	pool.position = Vector3(0, 0.4, -9)
	stage.add_child(pool)
	swarm.queue_free()
	await wait(0.2)
	swarm = swarm_at(Vector3(0, 0, 0))
	swarm.give_up_after = 3.0
	caught = 0
	home = 0
	boy.set_physics_process(false)
	put(Vector3(0, 0.05, -9))
	swarm.chasing = true
	gone = await wait(25.0, func() -> bool: return home > 0)
	check("water stops them", gone and caught == 0, "home %d, caught %d" % [home, caught])
	boy.set_physics_process(true)

	# Too far: they turn back.
	swarm.chase_distance = 10.0
	home = 0
	put(Vector3(0, 0.05, 14))
	swarm._rest = 0.0
	swarm.chasing = true
	await wait(0.5)
	put(Vector3(0, 0.05, 30))
	gone = await wait(15.0, func() -> bool: return home > 0)
	check("they turn back when he is too far from the nest", gone and caught == 0)

	# They come out by themselves when he comes near, if they are set to.
	swarm.alert_distance = 6.0
	swarm._rest = 0.0
	put(Vector3(3, 0.05, 3))
	var woke := await wait(3.0, func() -> bool: return swarm.chasing)
	check("they come out when he comes near", woke)
	swarm.queue_free()
	put(Vector3(20, 0.05, 20))

	# The harmless ones.
	var few := ScarabSwarm.new()
	few.harmless = true
	few.dung_ball = true
	few.count = 6
	few.position = Vector3(20, 0, 16)
	stage.add_child(few)
	var start := Vector2(few._x[1], few._z[1])
	await wait(12.0)
	var went := 0.0
	var sound := true
	for i in few.count:
		sound = sound and is_finite(few._x[i]) and is_finite(few._y[i]) and absf(few._y[i]) < 0.1
		went = maxf(went, Vector2(few._x[i] - few.position.x, few._z[i] - few.position.z).length())
	check("the harmless ones wander, and do nothing else", sound and went > 0.3 and went < few.roam + 1.5 and caught == 0 and not few.front.is_in_group(&"pursuers"),
			"furthest %.1f m from where they were put, started %s" % [went, start])
	few.queue_free()

	# What a frame of it costs.
	for count: int in [50, 100, 200]:
		put(Vector3(8, 0.05, 0))
		var timed := swarm_at(Vector3(0, 0, 0), count)
		timed.chasing = true
		await wait(4.0)
		var began := Time.get_ticks_usec()
		for i in 240:
			timed._physics_process(1.0 / 60.0)
		print("COST %d beetles: %.3f ms a frame" % [count, (Time.get_ticks_usec() - began) / 240000.0])
		timed.queue_free()
		await wait(0.2)

	await webs()
	print("PASSED" if failed == 0 else "FAILED (%d)" % failed)
	quit(1 if failed > 0 else 0)


func webs() -> void:
	if not ResourceLoader.exists("res://scripts/cobweb.gd"):
		return
	put(Vector3(-20, 0.05, 20))
	await wait(0.3)
	var sheet := Cobweb.new()
	sheet.kind = Cobweb.Kind.SHEET
	sheet.position = Vector3(-20, 0, 17)
	stage.add_child(sheet)
	var torn := [0]
	sheet.torn.connect(func() -> void: torn[0] += 1)
	await wait(0.5)
	check("a web across a passage is whole until he comes", not sheet.is_torn())
	# He is walked through it.
	for i in 90:
		boy.global_position.z -= 0.06
		await physics_frame
		await process_frame
	check("it tears when he goes through it", sheet.is_torn() and torn[0] == 1)
	# And one burns when a flame is held to it.
	var corner := Cobweb.new()
	corner.kind = Cobweb.Kind.CORNER
	corner.position = Vector3(-26, 2, 20)
	stage.add_child(corner)
	var burnt := [0]
	corner.burnt.connect(func() -> void: burnt[0] += 1)
	await wait(1.0)
	check("a web is left alone by nothing", not corner.is_burning() and burnt[0] == 0)
	var torch := HandTorch.new()
	torch.freeze = true
	torch.position = Vector3(-26.3, 1.1, 20)
	stage.add_child(torch)
	var gone := await wait(4.0, func() -> bool: return burnt[0] > 0)
	check("a torch held to one burns it away", gone and not is_instance_valid(corner) or (gone and not corner.visible))
