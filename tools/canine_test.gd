extends SceneTree
## Not part of the game. Runs a mummified jackal and a hyena through what each does of its own accord, with
## nothing drawn, and says whether each thing happened.
## The jackal: it lies dormant, wakes when he comes near and when it is told to, takes its time getting up, comes
## after him no faster than he can run, gathers itself and springs, has him if he stands still and misses him if he
## steps aside, cannot get at him up on a block, goes down under gunfire and gets up again, goes back where it was
## put; and two of them come at him from different sides.
## The hyena: it wanders when no one is about, keeps its distance from him, rushes him and breaks off short, has
## more nerve when he is down and less when he is by a fire, gives way to a shot, a gun going off, a torch and a
## stone, and only a very bold one brings him down.
## godot --headless --path . --fixed-fps 60 --script tools/canine_test.gd
## Ends with PASSED or FAILED (and exits 0 or 1).

var stage: Node3D
var boy: Player
var failed := 0


func _initialize() -> void:
	stage = Node3D.new()
	root.add_child(stage)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-48.0, -35.0, 0.0)
	stage.add_child(sun)
	box(Vector3(0, -1, 0), Vector3(400, 2, 400))
	# Somewhere out of reach: its top is 2.1 m up
	box(Vector3(60, 1.05, 60), Vector3(3, 2.1, 3))
	run.call_deferred()


func box(at: Vector3, size: Vector3) -> void:
	var body := StaticBody3D.new()
	var shape := BoxShape3D.new()
	shape.size = size
	var collider := CollisionShape3D.new()
	collider.shape = shape
	body.add_child(collider)
	body.position = at
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


func jackal(at: Vector3, wake_within := 0.0) -> JackalMummy:
	var made := JackalMummy.new()
	made.position = at
	made.wake_within = wake_within
	stage.add_child(made)
	made.target = boy
	return made


func hyena(at: Vector3, bold := 0.4) -> Hyena:
	var made := Hyena.new()
	made.position = at
	made.bold = bold
	made.voice = false
	stage.add_child(made)
	made.target = boy
	return made


func flat(from: Vector3, to: Vector3) -> float:
	return Vector2(from.x - to.x, from.z - to.z).length()


func run() -> void:
	for action: StringName in InputMap.get_actions():
		if not String(action).begins_with("ui_"):
			InputMap.action_erase_events(action)
	var touch := TouchControls.new()
	touch.visible = false
	stage.add_child(touch)
	touch.set_process_input(false)
	boy = load("res://player.tscn").instantiate()
	boy.position = Vector3(0, 0.05, 0)
	stage.add_child(boy)
	boy.set_process_unhandled_input(false)
	boy.set_physics_process(false)
	await jackals()
	await hyenas()
	print("PASSED" if failed == 0 else "FAILED (%d)" % failed)
	quit(1 if failed > 0 else 0)


func jackals() -> void:
	# Dormant: it does not stir for anyone until it is told to, or until he is as near as it was told to mind.
	var guard := jackal(Vector3(-12, 0.05, 0))
	check("is one of the pursuers", guard.is_in_group(&"pursuers") and not guard.chasing)
	await wait(3.0)
	check("lies dormant", not guard.is_awake() and guard.global_position.distance_to(Vector3(-12, 0, 0)) < 0.1 and guard._rig.risen() <= 0.0, "state %d" % guard.state)
	guard.wake_within = 6.0
	boy.global_position = Vector3(-6.5, 0.05, 0)
	var woke := await wait(2.0, func() -> bool: return guard.is_awake())
	check("wakes when he comes near", woke)
	# It takes its time getting up, and goes nowhere until it is up.
	var began := guard.global_position
	await wait(guard.wake_time * 0.8)
	check("gets up before it goes anywhere", flat(guard.global_position, began) < 0.1 and guard._rig.risen() > 0.5 and guard._rig.risen() < 1.0, "%.2f of the way up" % guard._rig.risen())
	boy.global_position = Vector3(40, 0.05, 0)
	var fastest := [0.0]
	var chased := await wait(8.0, func() -> bool:
		fastest[0] = maxf(fastest[0], Vector2(guard.velocity.x, guard.velocity.z).length())
		return guard.global_position.x > 5.0)
	check("comes after him", chased and guard.chasing, "at %s" % guard.global_position)
	check("is slower than he runs", fastest[0] < boy.run_speed and fastest[0] > 2.5, "%.2f m/s, to his %.2f" % [fastest[0], boy.run_speed])

	# He stands still: it gathers itself, springs, and has him.
	var caught := [0]
	guard.caught.connect(func() -> void:
		caught[0] += 1
		print("     (had him in state %d, %.2f m from him)" % [guard.state, flat(guard.global_position, boy.global_position)]))
	var seen := {}
	await wait(20.0, func() -> bool:
		seen[guard.state] = true
		return caught[0] > 0)
	check("gathers itself and springs", seen.has(JackalMummy.State.CROUCH) and seen.has(JackalMummy.State.LUNGE), "states seen %s" % str(seen.keys()))
	check("has him if he stands still", caught[0] == 1, "caught %d times" % caught[0])

	# He steps aside while it gathers itself: it springs at where he was, and misses.
	guard.reset()
	guard.wake_within = 0.0
	boy.global_position = Vector3(0, 0.05, 0)
	caught[0] = 0
	guard.wake()
	var stepped := [false]
	var sprang := await wait(20.0, func() -> bool:
		if guard.state == JackalMummy.State.CROUCH and guard._timer < 0.1 and not stepped[0]:
			stepped[0] = true
			var way := (boy.global_position - guard.global_position).normalized()
			boy.global_position += Vector3(way.z, 0.0, -way.x) * 1.8
		return guard.state == JackalMummy.State.RECOVER)
	check("misses him if he steps aside", sprang and stepped[0] and caught[0] == 0, "sprang %s, caught %d times" % [sprang, caught[0]])

	# Up on a block he is out of its reach: it does not get up there, and does not have him.
	boy.global_position = Vector3(60, 2.15, 60)
	guard.global_position = Vector3(50, 0.05, 59)
	caught[0] = 0
	var highest := [0.0]
	var prowled := [false]
	await wait(25.0, func() -> bool:
		highest[0] = maxf(highest[0], guard.global_position.y)
		prowled[0] = prowled[0] or guard._prowl > 0.0
		return false)
	check("cannot get at him up on a block", caught[0] == 0 and highest[0] < 1.2 and flat(guard.global_position, boy.global_position) < 8.0,
			"got %.2f m up, %.1f m from him" % [highest[0], flat(guard.global_position, boy.global_position)])
	check("prowls beneath him", prowled[0])

	# Gunfire: enough of it knocks it down; it lies; it gets up again.
	guard.down_time = 2.0
	guard.shot(boy, guard.global_position, Vector3(1, 0, 0), guard.toughness * 0.5)
	check("staggers, and comes on", guard.state != JackalMummy.State.FELLED)
	guard.shot(boy, guard.global_position, Vector3(1, 0, 0), guard.toughness * 0.6)
	check("goes down under enough gunfire", guard.state == JackalMummy.State.FELLED and not guard.chasing)
	await wait(1.2)
	check("lies where it fell", guard._rig.risen() <= 0.0 and guard.velocity.length() < 0.5)
	var again := await wait(8.0, func() -> bool: return guard.state == JackalMummy.State.HUNT)
	check("gets up again", again, "state %d" % guard.state)
	guard.reset()
	check("goes back where it was put", not guard.is_awake() and guard.global_position.distance_to(Vector3(-12, 0.05, 0)) < 0.2 and guard._rig.risen() <= 0.0)
	guard.queue_free()

	# Two of them: they come at him from different sides.
	boy.global_position = Vector3(0, 0.05, -60)
	var first := jackal(Vector3(-14, 0.05, -60.8))
	var second := jackal(Vector3(-14, 0.05, -59.2))
	for beast: JackalMummy in [first, second]:
		beast.lunge_distance = 0.0
		beast.wake()
	var widest := [0.0]
	await wait(9.0, func() -> bool:
		var a := first.global_position - boy.global_position
		var b := second.global_position - boy.global_position
		if a.length() < 7.0 and b.length() < 7.0:
			widest[0] = maxf(widest[0], absf(angle_difference(atan2(a.x, a.z), atan2(b.x, b.z))))
		return false)
	check("two come at him from different sides", widest[0] > deg_to_rad(60.0), "%.0f degrees apart" % rad_to_deg(widest[0]))
	check("and keep apart", flat(first.global_position, second.global_position) > 0.5, "%.2f m" % flat(first.global_position, second.global_position))
	first.queue_free()
	second.queue_free()
	await wait(0.2)


func hyenas() -> void:
	# No one about: it wanders near where it was put.
	boy.global_position = Vector3(150, 0.05, 150)
	var loner := hyena(Vector3(0, 0.05, 100))
	loner.roam = 8.0
	var furthest := [0.0]
	await wait(40.0, func() -> bool:
		furthest[0] = maxf(furthest[0], flat(loner.global_position, Vector3(0, 0, 100)))
		return false)
	check("wanders when no one is about", furthest[0] > 1.0 and furthest[0] < 10.0 and loner.state == Hyena.State.ROAM, "went %.1f m of 8" % furthest[0])
	loner.queue_free()

	# A wary one: it takes notice of him, comes no nearer than it dares, and never rushes him.
	boy.global_position = Vector3(0, 0.05, 0)
	var wary := hyena(Vector3(-20, 0.05, 2), 0.05)
	var nearest := [99.0]
	var states := {}
	var caught := [0]
	wary.caught.connect(func() -> void: caught[0] += 1)
	await wait(45.0, func() -> bool:
		nearest[0] = minf(nearest[0], flat(wary.global_position, boy.global_position))
		states[wary.state] = true
		return false)
	check("a wary one keeps its distance", nearest[0] > 7.0 and nearest[0] < 16.0 and not states.has(Hyena.State.DART), "nearest %.1f m; states seen %s" % [nearest[0], str(states.keys())])
	check("it watches him, and goes round him", states.has(Hyena.State.WATCH) and states.has(Hyena.State.CIRCLE))
	check("is called a pursuer only while it is rushing him", wary.is_in_group(&"pursuers") and not wary.chasing)
	var plain := wary._nerve()
	boy.is_ducking = true
	var down := wary._nerve()
	boy.is_ducking = false
	check("has more nerve when he is down", down > plain + 0.2, "%.2f against %.2f" % [down, plain])
	var torch := HandTorch.new()
	torch.freeze = true
	torch.position = boy.global_position + Vector3(1.0, 0.1, 0.0)
	stage.add_child(torch)
	Hyena._fires_at = -100000
	var lit := wary._nerve()
	check("has less nerve when he is by a fire", lit < plain - 0.2 or (plain <= 0.2 and lit <= 0.0), "%.2f against %.2f" % [lit, plain])
	torch.queue_free()
	wary.queue_free()
	await wait(0.2)
	Hyena._fires_at = -100000

	# One of ordinary boldness: it rushes him, with its mane up, breaks off short, and makes away.
	var bolder := hyena(Vector3(-9, 0.05, 0), 0.5)
	caught[0] = 0
	bolder.caught.connect(func() -> void: caught[0] += 1)
	await wait(1.0)
	bolder.dart()
	nearest[0] = 99.0
	var crest := [0.0]
	states.clear()
	var away := await wait(12.0, func() -> bool:
		nearest[0] = minf(nearest[0], flat(bolder.global_position, boy.global_position))
		crest[0] = maxf(crest[0], bolder._rig.crest())
		states[bolder.state] = true
		return states.has(Hyena.State.RETREAT) and bolder.state != Hyena.State.RETREAT)
	check("rushes him and breaks off short", states.has(Hyena.State.DART) and states.has(Hyena.State.RETREAT) and nearest[0] < 3.5 and nearest[0] > 0.6 and caught[0] == 0,
			"nearest %.2f m; caught %d times" % [nearest[0], caught[0]])
	check("makes away again", away and flat(bolder.global_position, boy.global_position) > 3.5, "%.1f m off" % flat(bolder.global_position, boy.global_position))
	check("raises its mane to do it", crest[0] > 0.8, "%.2f" % crest[0])

	# It gives way: to a shot,
	var gave := [0]
	bolder.gave_way.connect(func() -> void: gave[0] += 1)
	bolder.shot(boy, bolder.global_position, (bolder.global_position - boy.global_position).normalized(), 10.0)
	var off := await wait(6.0, func() -> bool: return flat(bolder.global_position, boy.global_position) > 14.0)
	check("gives way to a shot", off and gave[0] == 1 and bolder.afraid > 0.5, "%.1f m off" % flat(bolder.global_position, boy.global_position))
	await wait(6.0)
	check("keeps well away afterwards", bolder._shy > 0.0 and bolder._nerve() < 0.2 and flat(bolder.global_position, boy.global_position) > 11.0,
			"nerve %.2f, %.1f m off" % [bolder._nerve(), flat(bolder.global_position, boy.global_position)])
	# ...to a gun going off,
	bolder.queue_free()
	var second := hyena(Vector3(-8, 0.05, 20), 0.5)
	boy.global_position = Vector3(0, 0.05, 20)
	await wait(1.0)
	var gun := Node3D.new()
	gun.position = boy.global_position
	stage.add_child(gun)
	second._heard(gun)
	off = await wait(6.0, func() -> bool: return flat(second.global_position, boy.global_position) > 14.0)
	check("gives way to a gun going off", off and second.state == Hyena.State.FLEE or off)
	gun.queue_free()
	second.queue_free()
	# ...to a torch brought up to it,
	var third := hyena(Vector3(-8, 0.05, 40), 0.5)
	boy.global_position = Vector3(0, 0.05, 40)
	await wait(1.0)
	var brand := HandTorch.new()
	brand.freeze = true
	brand.position = third.global_position + Vector3(2.0, 0.1, 0.0)
	stage.add_child(brand)
	Hyena._fires_at = -100000
	var from := third.global_position
	off = await wait(6.0, func() -> bool: return flat(third.global_position, from) > 8.0)
	check("gives way to a torch", off, "moved %.1f m" % flat(third.global_position, from))
	brand.queue_free()
	third.queue_free()
	await wait(0.2)
	Hyena._fires_at = -100000
	# ...and to a stone.
	var fourth := hyena(Vector3(-8, 0.05, 80), 0.5)
	boy.global_position = Vector3(0, 0.05, 80)
	await wait(1.0)
	var stone := RigidBody3D.new()
	var round := SphereShape3D.new()
	round.radius = 0.08
	var collider := CollisionShape3D.new()
	collider.shape = round
	stone.add_child(collider)
	stone.add_to_group(&"throwable")
	stone.position = boy.global_position + Vector3(-0.5, 1.0, 0.0)
	stage.add_child(stone)
	var throw := fourth.global_position + Vector3(0.6, 0.3, 0.0) - stone.global_position
	stone.linear_velocity = throw.normalized() * 13.0 + Vector3.UP * 2.0
	from = fourth.global_position
	off = await wait(6.0, func() -> bool: return flat(fourth.global_position, from) > 8.0)
	check("gives way to a stone", off, "moved %.1f m" % flat(fourth.global_position, from))
	stone.queue_free()
	fourth.queue_free()
	await wait(0.2)

	# Only a very bold one carries a rush through.
	boy.global_position = Vector3(0, 0.05, 120)
	var killer := hyena(Vector3(-8, 0.05, 120), 0.95)
	caught[0] = 0
	killer.caught.connect(func() -> void: caught[0] += 1)
	await wait(1.0)
	killer.dart()
	var had := await wait(8.0, func() -> bool: return caught[0] > 0)
	check("a very bold one brings him down", had, "nerve %.2f" % killer._nerve())
	killer.reset()
	check("goes back where it was put", flat(killer.global_position, Vector3(-8, 0, 120)) < 0.2 and killer.state == Hyena.State.ROAM)
	killer.queue_free()
	await wait(0.2)
