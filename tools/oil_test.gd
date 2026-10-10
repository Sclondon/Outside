extends SceneTree
## Not part of the game. Runs oil with nothing drawn and says whether each thing happened: the boy takes up
## a jar, ducks and pours a trail that is all one; a puddle grows where oil goes on falling; a torch lights
## a trail and the fire goes along six metres of it in about six seconds, reaches a jar at the far end and
## bursts it; it burns out to a scorch; a gap stops it, water stops it and water puts it out; a spill's
## trigger and a fire dish turn on; burning oil lights a cold torch and burns him if he stands in it; a
## thrown jar breaks into a puddle; a spent jar is full again when he starts again; a mummy will not
## walk into the flames, and scarabs keep off them.
## godot --headless --path . --fixed-fps 60 --script tools/oil_test.gd
## Ends with PASSED or FAILED (and exits 0 or 1).

var stage: Node3D
var failed := 0
var boy: Player
var touch: TouchControls
var oil: Oil


func _initialize() -> void:
	stage = Node3D.new()
	root.add_child(stage)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-48.0, -35.0, 0.0)
	stage.add_child(sun)
	box(Vector3(0, -1, 0), Vector3(400, 2, 400))
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


func torch_at(at: Vector3, lit := true) -> HandTorch:
	var torch := HandTorch.new()
	torch.lit = lit
	torch.position = at
	torch.freeze = true
	stage.add_child(torch)
	return torch


func run() -> void:
	for action: StringName in InputMap.get_actions():
		if not String(action).begins_with("ui_"):
			InputMap.action_erase_events(action)
	touch = TouchControls.new()
	touch.visible = false
	stage.add_child(touch)
	touch.set_process_input(false)
	boy = load("res://player.tscn").instantiate()
	boy.position = Vector3(0, 0.05, 0)
	boy.rest_enabled = false
	stage.add_child(boy)
	boy.set_process_unhandled_input(false)
	await wait(0.5)
	oil = Oil.of(stage)
	await wait(0.1)

	# --- He takes up a jar, ducks, and walks: a trail. ---
	var jar := OilJar.new()
	jar.position = Vector3(0.4, 0.02, 0.3)
	stage.add_child(jar)
	await wait(0.4)
	check("a jar is a loose thing, full", jar.is_in_group(&"throwable") and jar.left == jar.measures, "holds %d" % jar.left)
	boy._act()
	await wait(1.2)
	check("he takes it up", boy.carried == jar and jar.holder == boy)
	await wait(1.0)
	check("carried upright, nothing runs from it", jar.left == jar.measures and oil.amounts().x == 0 and jar.global_basis.y.y > 0.95)
	var from := boy.global_position
	touch.duck_held = true
	await wait(0.8)
	check("ducked, it tips and pours", jar.is_pouring() and jar.left < jar.measures, "tipped %.2f, left %d" % [jar._tip, jar.left])
	touch.move = Vector2(1.0, 0.0)
	await wait(3.0)
	touch.move = Vector2.ZERO
	touch.duck_held = false
	await wait(0.6)
	var went := boy.global_position.distance_to(from)
	var wet := oil.amounts().x
	var spent := jar.measures - jar.left
	check("he lays a trail as he goes", went > 2.0 and wet >= int(went / 0.3) and not jar.is_pouring(), "%.1f m, %d patches, %d measures spent" % [went, wet, spent])
	# (all one: fire set to one end reaches the other)
	var way := (boy.global_position - from).normalized()
	var mouth_end := boy.global_position + way * 0.3
	var whole := true
	for n in 20:
		var at := (from + way * 0.5).lerp(mouth_end - way * 0.3, n / 19.0)
		whole = whole and oil.is_oil(Vector3(at.x, 0.0, at.z), 0.25)
	check("and it is all one", whole)
	var stopped := jar.left
	await wait(1.0)
	check("standing up stops it", jar.left == stopped)
	# Put down (duck and act), it is not broken.
	touch.duck_held = true
	await wait(0.15)
	boy._act()
	touch.duck_held = false
	await wait(1.0)
	check("put down gently it does not break", boy.carried == null and not jar.is_broken, "left %d" % jar.left)
	oil.clear()
	await wait(0.2)

	# --- A puddle grows where it goes on falling. ---
	for n in 14:
		oil.pour(Vector3(20, 0.6, 0))
	await wait(0.7)
	var puddle := oil.amounts().x
	check("oil poured in one place is a puddle that grows", puddle >= 3 and puddle < 14 and oil.is_oil(Vector3(20, 0, 0)) and not oil.is_oil(Vector3(20, 0, 3.0)), "%d patches" % puddle)
	oil.clear()

	# --- A fuse: six metres, a torch at one end, a jar at the other. ---
	put(Vector3(40, 0.05, 10))
	oil.lay(Vector3(40, 0, 0), Vector3(46, 0, 0))
	var second := OilJar.new()
	second.position = Vector3(46.1, 0.02, 0.0)
	stage.add_child(second)
	await wait(1.0)
	check("oil lies there and does not burn by itself", oil.amounts().x > 20 and not oil.burning and not Oil.is_burning_at(Vector3(40, 0, 0)), "%d patches" % oil.amounts().x)
	var caught := [0]
	oil.caught.connect(func(_at: Vector3) -> void: caught[0] += 1)
	var torch := torch_at(Vector3(39.9, 0.02, 0.0))
	torch.rotation.z = -1.3
	var lit := await wait(2.0, func() -> bool: return oil.is_burning(Vector3(40, 0, 0)))
	check("a torch laid in it lights it", lit and caught[0] > 0)
	check("and anyone can ask", Oil.is_burning_at(Vector3(40, 0, 0), 0.4) and Oil.is_flame_at(self, Vector3(40, 0.3, 0), 0.6) and not Oil.is_burning_at(Vector3(45.5, 0, 0), 0.2) and oil.is_in_group(&"flames"))
	# (timed over the five metres from one metre along it to its end)
	var ticks := [0, 0]
	var reached := await wait(12.0, func() -> bool:
		ticks[0] += 1
		if ticks[1] == 0 and oil.is_burning(Vector3(41, 0, 0), 0.05):
			ticks[1] = ticks[0]
		return oil.is_burning(Vector3(46, 0, 0), 0.05))
	var took: float = (ticks[0] - ticks[1]) / 60.0 * 6.0 / 5.0
	check("fire goes along six metres of it in about six seconds", reached and ticks[1] > 0 and took > 5.3 and took < 6.7, "%.2f s" % took)
	check("it is all alight behind it, and a fire or two stands on it", oil.is_burning(Vector3(43, 0, 0)) and oil.amounts().y > 15 and Nearby.fires(self).any(func(fire: Node3D) -> bool: return fire.get_parent() == oil),
			"%d alight" % oil.amounts().y)
	var burst := await wait(4.0, func() -> bool: return second.is_broken)
	await wait(0.5)
	check("it reaches the jar at the end, which bursts, burning", burst and oil.is_burning(Vector3(46.4, 0, 0.4), 0.5), "alight now %d" % oil.amounts().y)
	var out := await wait(oil.burn_time * 1.3 + 6.0, func() -> bool: return not oil.burning)
	var marks := oil.amounts()
	check("it burns out, and leaves a scorch", out and marks.x == 0 and marks.y == 0 and marks.z > 20 and oil.is_scorched(Vector3(43, 0, 0)), "%s" % marks)
	await wait(0.5)
	check("and its fires are put away", not Nearby.fires(self).any(func(fire: Node3D) -> bool: return is_instance_valid(fire) and fire.is_inside_tree() and fire.get_parent() == oil))
	check("a scorch does not burn again", not oil.ignite(Vector3(43, 0, 0)))
	torch.queue_free()
	oil.clear()

	# --- A gap stops it. ---
	oil.lay(Vector3(40, 0, 20), Vector3(42, 0, 20))
	oil.lay(Vector3(43, 0, 20), Vector3(45, 0, 20))
	await wait(0.6)
	oil.ignite(Vector3(40, 0, 20))
	await wait(4.5)
	check("a gap in a trail stops the fire", oil.is_burning(Vector3(41.9, 0, 20)) and not oil.is_burning(Vector3(43.5, 0, 20)) and oil.is_oil(Vector3(44, 0, 20)))
	# (and oil poured into the gap carries it over)
	for n in 5:
		oil.pour(Vector3(42.2 + n * 0.2, 0.5, 20))
	var over := await wait(4.0, func() -> bool: return oil.is_burning(Vector3(44.5, 0, 20)))
	check("oil poured into the gap carries it over", over)
	oil.clear()

	# --- Water. ---
	var pool := Pool.new()
	pool.size = Vector3(2, 1, 4)
	pool.position = Vector3(63, 0.3, 0)
	stage.add_child(pool)
	await wait(0.3)
	oil.lay(Vector3(60, 0, 0), Vector3(66, 0, 0))
	await wait(0.6)
	check("oil does not lie under water", oil.is_oil(Vector3(61, 0, 0)) and not oil.is_oil(Vector3(63, 0, 0), 0.2) and oil.is_oil(Vector3(65, 0, 0)))
	oil.ignite(Vector3(60, 0, 0))
	await wait(7.0)
	check("water stops the fire", oil.is_burning(Vector3(61.5, 0, 0)) and not oil.is_burning(Vector3(65, 0, 0)) and oil.is_oil(Vector3(65, 0, 0)))
	# Water that comes up over it.
	oil.clear()
	oil.lay(Vector3(60, 0, 10), Vector3(64, 0, 10))
	await wait(0.6)
	oil.ignite(Vector3(60, 0, 10))
	await wait(1.5)
	var was := oil.amounts().y
	var flood := Pool.new()
	flood.size = Vector3(10, 1, 4)
	flood.position = Vector3(62, 0.3, 10)
	stage.add_child(flood)
	var doused := await wait(2.0, func() -> bool: return not oil.burning)
	await wait(4.0)
	check("water that rises over it puts it out, and it does not go on", was > 0 and doused and not oil.burning and oil.amounts().x > 10, "was alight %d, now %s" % [was, oil.amounts()])
	flood.queue_free()
	pool.queue_free()
	oil.clear()
	await wait(0.2)

	# --- The triggers. ---
	var spill := OilSpill.new()
	spill.length = 3.0
	spill.position = Vector3(80, 0, 0)
	stage.add_child(spill)
	var dish := OilMark.new()
	dish.position = Vector3(80, 0, 3.6)
	stage.add_child(dish)
	var fired := [0, 0]
	spill.burnt.connect(func() -> void: fired[0] += 1)
	dish.changed.connect(func(_on: bool) -> void: fired[1] += 1)
	await wait(0.5)
	check("a spill lays itself along its own +Z", oil.is_oil(Vector3(80, 0, 0)) and oil.is_oil(Vector3(80, 0, 2.9)) and not oil.is_oil(Vector3(80, 0, 4.2)), "%d patches, far end %s" % [oil.amounts().x, spill.far_end()])
	# (oil is poured on from its end into the dish)
	for n in 4:
		oil.pour(Vector3(80, 0.5, 3.15 + n * 0.2))
	await wait(0.6)
	oil.ignite(Vector3(80, 0, 0))
	await wait(1.5)
	check("a trigger waits for the fire to come", fired[0] == 0 and fired[1] == 0 and not spill.is_burnt and not dish.pressed)
	ticks[0] = 0
	var sprung := await wait(5.0, func() -> bool:
		ticks[0] += 1
		return fired[0] > 0)
	check("the spill's trigger turns on when its far end burns", sprung and spill.is_burnt and ticks[0] / 60.0 > 0.3 and ticks[0] / 60.0 < 1.5, "%.1f s after" % (1.5 + ticks[0] / 60.0))
	var dished := await wait(3.0, func() -> bool: return fired[1] > 0)
	check("and the fire dish when oil burns in it", dished and dish.pressed)
	await wait(oil.burn_time * 1.3 + 2.0, func() -> bool: return not oil.burning)
	# He starts again: the spill is oil again, the dish stays on.
	boy.respawn()
	boy.respawned.emit()
	await wait(0.6)
	check("burnt, the spill is laid afresh when he starts again", oil.amounts(spill.get_instance_id()).x > 8 and oil.is_oil(Vector3(80, 0, 1.5)) and fired[0] == 1 and dish.pressed, "%s" % oil.amounts(spill.get_instance_id()))
	spill.position = Vector3(84, 0, 0)
	await wait(0.4)
	check("moved, it lies where it now is", oil.is_oil(Vector3(84, 0, 1.5)) and not oil.is_oil(Vector3(80, 0, 1.5)))
	spill.queue_free()
	dish.queue_free()
	await wait(0.3)
	check("taken out of the level, its oil goes with it", not oil.is_oil(Vector3(84, 0, 1.5)), "%s" % oil.amounts())
	oil.clear()

	# --- What burning oil does. ---
	oil.lay(Vector3(100, 0, 0), Vector3(103, 0, 0))
	var cold := torch_at(Vector3(102.0, 0.02, 0.0), false)
	cold.rotation.z = 0.12
	await wait(0.6)
	check("a torch that is out lights nothing", not cold.lit and not oil.burning)
	oil.ignite(Vector3(100, 0, 0))
	var relit := await wait(5.0, func() -> bool: return cold.lit)
	check("burning oil lights a cold torch that stands in it", relit)
	cold.queue_free()
	# He runs through it and lives; he stands in it and does not.
	var hurt := [0]
	oil.burned.connect(func(_who: Node3D) -> void: hurt[0] += 1)
	put(Vector3(101.5, 0.05, -3.0))
	await wait(0.3)
	for n in 30:
		boy.global_position.z += 0.2
		await physics_frame
		await process_frame
	check("he can run through the flames", hurt[0] == 0 and not boy.is_limp)
	put(Vector3(101.5, 0.05, 0.0))
	var down := await wait(2.0, func() -> bool: return boy.is_limp)
	check("standing in them, he is burnt", down and hurt[0] == 1)
	await wait(3.0)
	check("and starts again", not boy.is_limp)
	await wait(oil.burn_time * 1.3 + 2.0, func() -> bool: return not oil.burning)
	oil.clear()

	# --- A torch in his hand: over oil it does nothing while he stands, and lights it when he ducks. ---
	oil.lay(Vector3(120, 0, 2.0), Vector3(120, 0, 4.5))
	var held := torch_at(Vector3(120.3, 0.02, 0.0))
	put(Vector3(120, 0.05, -0.2))
	await wait(0.5)
	boy._act()
	await wait(1.5)
	check("he has the torch", boy.carried == held, "flame at %.2f m" % (held.fire.global_position.y if held.fire else -1.0))
	put(Vector3(120, 0.05, 2.1))
	await wait(1.5)
	var standing := oil.burning
	var flame_high := held.fire.global_position.y
	touch.duck_held = true
	var low := await wait(2.5, func() -> bool: return oil.burning)
	check("a torch held over oil lights it when he ducks to it, not as he stands", low and not standing, "flame at %.2f m standing, %.2f m ducked" % [flame_high, held.fire.global_position.y])
	touch.duck_held = false
	put(Vector3(120, 0.05, -6.0))
	await wait(0.2)
	boy._act()
	await wait(oil.burn_time * 1.3 + 3.0, func() -> bool: return not oil.burning)
	held.queue_free()
	oil.clear()

	# --- A jar thrown breaks into a puddle; and a spent one is made good when he starts again. ---
	put(Vector3(0, 0.05, 30))
	var thrown := OilJar.new()
	thrown.measures = 30
	thrown.position = Vector3(0.3, 0.02, 30.3)
	stage.add_child(thrown)
	await wait(0.5)
	boy._act()
	await wait(1.2)
	var facing := Vector3(sin(boy.facing_yaw), 0.0, cos(boy.facing_yaw))
	boy._act()
	var broke := await wait(3.0, func() -> bool: return thrown.is_broken)
	await wait(0.8)
	var splash := oil.amounts().x
	var landed := boy.global_position + facing * 5.0
	check("a thrown jar breaks, and what was in it is a puddle", broke and splash >= 10 and not oil.burning, "%d patches" % splash)
	await wait(8.0)
	check("broken, it waits", is_instance_valid(thrown) and thrown.is_broken)
	boy.respawn()
	boy.respawned.emit()
	await wait(0.5)
	check("and is whole and full where it began when he starts again", is_instance_valid(thrown) and not thrown.is_broken and thrown.left == 30 and thrown.global_position.distance_to(Vector3(0.3, 0.02, 30.3)) < 0.5, "%s" % landed)
	# Shot, it spills; lit where it stands, it bursts.
	oil.clear()
	thrown.shot(null, thrown.global_position, Vector3.FORWARD, 10.0)
	await wait(0.5)
	check("shot, it breaks and spills and does not burn", thrown.is_broken and oil.amounts().x >= 10 and not oil.burning)
	thrown.queue_free()
	oil.clear()

	# --- A flare. ---
	var target := OilJar.new()
	target.position = Vector3(0.0, 0.02, 60.0)
	stage.add_child(target)
	await wait(0.5)
	var flare := Flare.new()
	flare.velocity = Vector3(0.0, 0.0, flare.speed)
	stage.add_child(flare)
	flare.global_position = Vector3(0.0, 0.3, 56.0)
	var flared := await wait(3.0, func() -> bool: return target.is_broken and oil.burning)
	check("shot with a flare, a jar bursts into flame", flared, "alight %d" % oil.amounts().y)
	flare.queue_free()
	target.queue_free()
	oil.clear()
	await wait(0.3)

	# --- A mummy will not walk into it; and scarabs keep off it. ---
	oil.burn_time = 12.0
	put(Vector3(140, 0.05, 4))
	boy.set_physics_process(false)
	oil.lay(Vector3(134, 0, 0), Vector3(146, 0, 0))
	var mummy := Mummy.new()
	mummy.position = Vector3(140, 0.05, -5)
	stage.add_child(mummy)
	mummy.target = boy
	var grabbed := [0]
	mummy.caught.connect(func() -> void: grabbed[0] += 1)
	await wait(0.6)
	oil.ignite(Vector3(140, 0, 0), 7.0)
	await wait(1.0)
	mummy.wake()
	var nearest := [INF]
	await wait(9.0, func() -> bool:
		nearest[0] = minf(nearest[0], absf(mummy.global_position.z))
		return false)
	check("a mummy will not walk into burning oil", mummy.chasing and oil.burning and mummy.global_position.z < -0.3 and nearest[0] < 2.0 and grabbed[0] == 0,
			"came within %.2f m of it, and is at %.2f" % [nearest[0], mummy.global_position.z])
	var crossed := await wait(25.0, func() -> bool: return mummy.global_position.z > 0.5)
	check("and comes on when it has burnt out", crossed and not oil.burning)
	mummy.queue_free()
	oil.clear()
	oil.burn_time = 30.0
	for n in 20:
		oil.pour(Vector3(170, 0.6, 0))
	put(Vector3(170, 0.05, 1.5))
	await wait(0.6)
	oil.ignite(Vector3(170, 0, 0), 2.0)
	var swarm := ScarabSwarm.new()
	swarm.count = 80
	swarm.voice = false
	swarm.position = Vector3(162, 0, 1.5)
	stage.add_child(swarm)
	swarm.target = boy
	var bitten := [0]
	swarm.caught.connect(func() -> void: bitten[0] += 1)
	await wait(0.5)
	swarm.chasing = true
	var most := [0, 0]
	await wait(14.0, func() -> bool:
		most[0] = maxi(most[0], swarm.on_him)
		most[1] = maxi(most[1], swarm.held_off)
		return false)
	check("burning oil holds scarabs off, as a fire does", bitten[0] == 0 and most[0] == 0 and most[1] > 10 and swarm.out > 40, "most on him %d, most held off %d, out %d" % [most[0], most[1], swarm.out])
	swarm.queue_free()
	boy.set_physics_process(true)
	oil.clear()
	oil.burn_time = 7.0
	await wait(0.3)

	# --- There is only so much of it. ---
	for n in Oil.MOST + 40:
		oil.pour(Vector3(-40 + (n % 40) * 0.5, 0.5, -40 + (n / 40) * 0.5), 0.2)
	check("there is only so much of it at once", oil.amounts().x == Oil.MOST, "%s" % oil.amounts())
	# What a frame of it costs: all of it alight.
	oil.burn_after = 0.0
	oil.ignite(Vector3(-30, 0, -38), 60.0)
	await wait(1.0)
	var alight := oil.amounts().y
	var start := Time.get_ticks_usec()
	for i in 240:
		oil._physics_process(1.0 / 60.0)
	var think := (Time.get_ticks_usec() - start) / 240000.0
	start = Time.get_ticks_usec()
	for i in 240:
		oil._process(1.0 / 60.0)
	print("COST %d patches alight: %.3f ms a frame to work out, %.3f ms to draw" % [alight, think, (Time.get_ticks_usec() - start) / 240000.0])

	print("PASSED" if failed == 0 else "FAILED (%d)" % failed)
	quit(1 if failed > 0 else 0)
