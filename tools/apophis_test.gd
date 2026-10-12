extends SceneTree
## Not part of the game. Runs Apophis with nothing drawn and says whether each thing happened: he lies
## still until he is let out; catches a boy who stands; does not catch one who runs straight, and does
## when that one stops; is held off by a torch and by a brazier, and has him when the torch goes out;
## gets past a pillar and a block and over a kerb; is delayed by a ledge and then goes up it, and goes
## round by steps where there are some; is stopped by a shut door and by a beam of sunlight; goes home
## when he is called off; comes up out of a hole; wakes by himself when the boy comes near; and is let
## out and sent home by a plate in the desert, as the level editor wires him. All the while no part of
## his body may be under the ground, nor his head through a wall. It ends with what a frame of him costs.
## godot --headless --path . --fixed-fps 60 --script tools/apophis_test.gd
## Ends with PASSED or FAILED (and exits 0 or 1).

var stage: Node3D
var failed := 0
var boy: Player
var touch: TouchControls
var caught := 0
var home := 0
# The one being watched, and the worst seen of it: how far any part was under the ground, how often its head was through something.
var watched: Apophis
var under := 0.0
var through := 0
var seen := {}
# (with `trace` after `--`, it says each thing he turns to doing, and when)
var trace := false
var last := -1


func _initialize() -> void:
	stage = Node3D.new()
	root.add_child(stage)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-48.0, -35.0, 0.0)
	stage.add_child(sun)
	box(Vector3(0, -1, 150), Vector3(200, 2, 500))
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
		watch()
		if until.is_valid() and until.call():
			return true
	return not until.is_valid()


# Looks at the one being watched: is any of him under the ground, is his head through anything.
func watch() -> void:
	if not is_instance_valid(watched) or watched.state == Apophis.State.DORMANT:
		return
	if trace and not seen.has(watched.state) or (trace and watched.state != last):
		print("      %.2f s: %s at %s" % [watched._clock, Apophis.State.keys()[watched.state], watched.global_position])
	last = watched.state
	seen[watched.state] = true
	var space := watched.get_world_3d().direct_space_state
	for i in Apophis.POINTS:
		var at := watched.spine[i]
		var belly := at.y - watched.girth[i] * 0.62
		var hit := space.intersect_ray(PhysicsRayQueryParameters3D.create(at + Vector3.UP * 1.5, Vector3(at.x, belly + 0.02, at.z), 1))
		if not hit.is_empty():
			under = maxf(under, (hit["position"] as Vector3).y - belly)
	var query := PhysicsRayQueryParameters3D.create(watched.global_position + Vector3.UP * 0.3, watched.head_at, 1)
	query.exclude = [watched.get_rid()]
	if not space.intersect_ray(query).is_empty():
		through += 1


func put(at: Vector3) -> void:
	touch.move = Vector2.ZERO
	boy.global_position = at
	boy.velocity = Vector3.ZERO


func snake_at(at: Vector3, long := 14.0) -> Apophis:
	var snake := Apophis.new()
	snake.length = long
	snake.voice = false
	snake.position = at
	stage.add_child(snake)
	snake.target = boy
	snake.caught.connect(func() -> void: caught += 1)
	snake.went_home.connect(func() -> void: home += 1)
	caught = 0
	home = 0
	watched = snake
	seen = {}
	return snake


func done(snake: Apophis) -> void:
	watched = null
	snake.queue_free()
	await wait(0.2)


func away(snake: Apophis) -> float:
	return snake.head_at.distance_to(boy.global_position)


func run() -> void:
	LevelLayout.saved_at = "user://apophis_test.json"
	trace = OS.get_cmdline_user_args().has("trace")
	for action: StringName in InputMap.get_actions():
		if not String(action).begins_with("ui_"):
			InputMap.action_erase_events(action)
	touch = TouchControls.new()
	touch.visible = false
	stage.add_child(touch)
	touch.set_process_input(false)
	boy = load("res://player.tscn").instantiate()
	boy.position = Vector3(9, 0.05, 0)
	boy.rest_enabled = false
	stage.add_child(boy)
	boy.set_process_unhandled_input(false)
	await wait(0.5)

	# He lies coiled until he is let out; then he comes, and has a boy who stands.
	var snake := snake_at(Vector3(0, 0, 0))
	await wait(1.0)
	var coil := 0.0
	for at in snake.spine:
		coil = maxf(coil, Vector2(at.x, at.z).length())
	check("he lies coiled until he is let out", snake.state == Apophis.State.DORMANT and not snake.chasing and not snake.is_in_group(&"pursuers") and coil < 2.6, "coil %.2f m across" % (coil * 2.0))
	snake.loose = true
	var woke := await wait(1.0, func() -> bool: return snake.is_awake())
	check("he wakes when he is let out", woke and snake.chasing and snake.is_in_group(&"pursuers"))
	var began := snake._clock
	var got := await wait(15.0, func() -> bool: return caught > 0)
	check("he catches a boy who stands still", got and seen.has(Apophis.State.STRIKE), "after %.1f s" % (snake._clock - began))
	# His body is all behind his head, where his head went.
	var long := 0.0
	for i in Apophis.POINTS - 1:
		long += snake.spine[i].distance_to(snake.spine[i + 1])
	check("he is one body of his own length", absf(long - snake.length) < snake.length * 0.12, "%.1f m of %.1f" % [long, snake.length])
	await done(snake)

	# A boy who runs straight keeps ahead; when he stops, he is caught.
	put(Vector3(6, 0.05, 30))
	snake = snake_at(Vector3(0, 0, 30))
	await wait(0.5)
	snake.loose = true
	touch.move = Vector2(1, 0)
	var nearest := [INF]
	await wait(12.0, func() -> bool:
		nearest[0] = minf(nearest[0], away(snake))
		return false)
	var fast := Vector2(snake.velocity.x, snake.velocity.z).length()
	check("he does not catch a boy who runs a straight course", caught == 0 and nearest[0] > 3.0, "nearest %.1f m, he is going %.2f m/s, the boy %.2f" % [nearest[0], fast, boy.velocity.length()])
	check("his speed is between the boy's walk and his run", fast > boy.walk_speed + 0.5 and fast < boy.run_speed, "%.2f m/s" % fast)
	touch.move = Vector2.ZERO
	began = snake._clock
	got = await wait(30.0, func() -> bool: return caught > 0)
	check("and has him when he stops", got, "after %.1f s" % (snake._clock - began))
	await done(snake)

	# A torch stuck in the ground beside the boy holds him off; when it goes out, he strikes.
	put(Vector3(9, 0.05, 60))
	var torch := HandTorch.new()
	torch.position = Vector3(9.3, 0.0, 60)
	torch.freeze = true
	stage.add_child(torch)
	snake = snake_at(Vector3(0, 0, 60))
	await wait(0.5)
	snake.loose = true
	var came := await wait(10.0, func() -> bool: return snake.state == Apophis.State.HELD)
	var least := [INF]
	var went := [0.0, snake.global_position]
	await wait(12.0, func() -> bool:
		least[0] = minf(least[0], Vector2(snake.global_position.x - torch.global_position.x, snake.global_position.z - torch.global_position.z).length())
		went[0] += (snake.global_position - (went[1] as Vector3)).length()
		went[1] = snake.global_position
		return false)
	check("a torch holds him off", came and caught == 0 and least[0] > snake.light_reach - 0.35 and snake.state == Apophis.State.HELD, "his head came within %.2f m of it, caught %d" % [least[0], caught])
	check("he circles at the edge of the light", went[0] > 3.0 and away(snake) < snake.light_reach + 2.5, "went %.1f m round it, is %.1f m off" % [went[0], away(snake)])
	torch.lit = false
	got = await wait(8.0, func() -> bool: return caught > 0)
	check("when the light goes he has him", got)
	torch.queue_free()
	await done(snake)

	# A brazier is a safe place.
	put(Vector3(9, 0.05, 90))
	var fire := Fire.brazier()
	fire.position = Vector3(9.8, 0.9, 90)
	stage.add_child(fire)
	snake = snake_at(Vector3(0, 0, 90))
	await wait(0.5)
	snake.loose = true
	least[0] = INF
	await wait(16.0, func() -> bool:
		least[0] = minf(least[0], Vector2(snake.global_position.x - fire.global_position.x, snake.global_position.z - fire.global_position.z).length())
		return false)
	check("a brazier holds him off", caught == 0 and least[0] > Nearby.reach_of(fire, snake.light_reach) - 0.35 and seen.has(Apophis.State.HELD), "his head came within %.2f m of it, which holds off %.2f" % [least[0], Nearby.reach_of(fire, snake.light_reach)])
	# One that does not fear light takes no notice.
	snake.fears_light = false
	got = await wait(8.0, func() -> bool: return caught > 0)
	check("one that does not fear light is not held off", got)
	fire.queue_free()
	await done(snake)

	# A pillar dead in his way, a block that can be pushed, and a kerb right across.
	box(Vector3(5, 1.5, 120), Vector3(0.8, 3.0, 0.8))
	var block := RigidBody3D.new()
	block.mass = 20.0
	block.lock_rotation = true
	PuzzleKit.shape(block, Vector3.ZERO, Vector3.ONE * 0.9)
	block.position = Vector3(9, 0.45, 120)
	stage.add_child(block)
	box(Vector3(13, 0.25, 120), Vector3(0.4, 0.5, 14))
	put(Vector3(18, 0.05, 120))
	snake = snake_at(Vector3(0, 0, 120))
	await wait(0.5)
	snake.loose = true
	var highest := [0.0]
	began = snake._clock
	got = await wait(25.0, func() -> bool:
		highest[0] = maxf(highest[0], snake.global_position.y)
		return caught > 0)
	check("he gets past a pillar and a block, and over a kerb", got and highest[0] > 0.45, "after %.1f s, his head went %.2f m up" % [snake._clock - began, highest[0]])
	block.queue_free()
	await done(snake)

	# A ledge 2.5 m high buys time, not safety.
	box(Vector3(14, 1.25, 150), Vector3(6, 2.5, 6))
	put(Vector3(13, 2.55, 150))
	snake = snake_at(Vector3(0, 0, 150))
	await wait(0.5)
	snake.loose = true
	var reached := await wait(12.0, func() -> bool: return snake.state == Apophis.State.LEDGE)
	began = snake._clock
	got = await wait(30.0, func() -> bool: return caught > 0)
	var took := snake._clock - began
	check("a ledge holds him up", reached and took > snake.ledge_wait + 2.0, "he waited under it and went up in %.1f s" % took)
	check("and then he goes up it", got and seen.has(Apophis.State.CLIMB) and snake.global_position.y > 2.3, "his head is %.2f m up" % snake.global_position.y)
	await done(snake)
	# With steps up at one side of it, he goes round by them.
	box(Vector3(11.4, 0.425, 154), Vector3(0.8, 0.85, 2))
	box(Vector3(12.2, 0.85, 154), Vector3(0.8, 1.7, 2))
	box(Vector3(14.8, 1.25, 154), Vector3(4.4, 2.5, 2))
	put(Vector3(13, 2.55, 150))
	snake = snake_at(Vector3(0, 0, 150))
	await wait(0.5)
	snake.loose = true
	var slow := [false]
	got = await wait(40.0, func() -> bool:
		slow[0] = slow[0] or (snake.state == Apophis.State.CLIMB and not snake._quick)
		return caught > 0)
	check("where there are steps at one side he goes round by them", got and seen.has(Apophis.State.LEDGE) and not slow[0], "caught %d, went up the face %s" % [caught, slow[0]])
	await done(snake)

	# A door shut in a passage stops him; opened, it does not.
	for z: float in [-1.2, 1.2]:
		box(Vector3(7, 1.5, 190 + z), Vector3(6, 3.0, 0.4))
	box(Vector3(7, 2.75, 190), Vector3(6, 0.5, 2.8))
	var door := TombParts.Door.new(Vector3(0.4, 2.4, 2.0), Color.GRAY)
	door.position = Vector3(7, 1.2, 190)
	stage.add_child(door)
	put(Vector3(13, 0.05, 190))
	snake = snake_at(Vector3(-4, 0, 190))
	await wait(0.5)
	snake.loose = true
	came = await wait(12.0, func() -> bool: return snake.state == Apophis.State.BATTER)
	var furthest := [-INF]
	await wait(10.0, func() -> bool:
		furthest[0] = maxf(furthest[0], snake.global_position.x)
		return false)
	check("a shut door stops him: he batters at it and waits", came and caught == 0 and furthest[0] < 6.8 and snake.state == Apophis.State.BATTER, "his head got to x %.2f; the door is at 7" % furthest[0])
	door.is_open = true
	got = await wait(15.0, func() -> bool: return caught > 0)
	check("opened, it lets him through", got)
	door.queue_free()
	await done(snake)

	# A beam of sunlight across his way.
	var beam := SunBeam.new()
	beam.position = Vector3(6, 0, 213)
	stage.add_child(beam)
	put(Vector3(12, 0.05, 220))
	snake = snake_at(Vector3(-2, 0, 220))
	await wait(0.5)
	snake.loose = true
	furthest[0] = -INF
	await wait(12.0, func() -> bool:
		furthest[0] = maxf(furthest[0], snake.global_position.x)
		return false)
	check("a beam of sunlight across his way stops him", caught == 0 and furthest[0] < 6.0 - 0.4 and furthest[0] > 3.0, "his head got to x %.2f; the beam is at 6" % furthest[0])
	beam.shining = false
	got = await wait(12.0, func() -> bool: return caught > 0)
	check("and when it is covered he comes on", got)
	beam.queue_free()
	await done(snake)

	# Called off, he goes home and coils up again.
	put(Vector3(30, 0.05, 250))
	snake = snake_at(Vector3(0, 0, 250))
	await wait(0.5)
	snake.loose = true
	await wait(6.0)
	var out := snake.global_position.length()
	var far := Vector2(snake.global_position.x, snake.global_position.z - 250.0).length()
	snake.loose = false
	var back := await wait(25.0, func() -> bool: return home > 0)
	coil = 0.0
	for at in snake.spine:
		coil = maxf(coil, Vector2(at.x, at.z - 250.0).length())
	check("going off sends him home, to coil up again", back and far > 6.0 and snake.state == Apophis.State.DORMANT and not snake.chasing and not snake.is_in_group(&"pursuers") and coil < 2.6 and caught == 0,
			"he was %.1f m out; home %d; coil %.2f m across" % [far, home, coil * 2.0])
	snake.loose = true
	got = await wait(20.0, func() -> bool: return caught > 0)
	check("and he comes again when he is let out again", got)
	await done(snake)

	# One that waits down a hole is not to be seen until he is let out.
	put(Vector3(8, 0.05, 280))
	snake = Apophis.new()
	snake.rest = Apophis.Rest.HOLE
	snake.length = 14.0
	snake.voice = false
	snake.position = Vector3(0, 0, 280)
	stage.add_child(snake)
	snake.target = boy
	snake.caught.connect(func() -> void: caught += 1)
	snake.went_home.connect(func() -> void: home += 1)
	caught = 0
	home = 0
	await wait(0.5)
	var top := -INF
	for at in snake.spine:
		top = maxf(top, at.y)
	check("one down a hole is out of sight", top < -0.5, "the highest of him is at %.2f" % top)
	snake.loose = true
	got = await wait(15.0, func() -> bool: return caught > 0)
	check("he comes up out of it and has the boy", got)
	put(Vector3(40, 0.05, 280))
	snake.loose = false
	back = await wait(30.0, func() -> bool: return home > 0)
	top = -INF
	for at in snake.spine:
		top = maxf(top, at.y)
	check("and goes back down it", back and top < -0.5, "the highest of him is at %.2f" % top)
	snake.queue_free()
	await wait(0.2)

	# He wakes by himself when the boy comes near, if he is set to.
	put(Vector3(30, 0.05, 310))
	snake = snake_at(Vector3(0, 0, 310))
	snake.alert_distance = 6.0
	await wait(2.5)
	var slept := snake.state == Apophis.State.DORMANT
	put(Vector3(5, 0.05, 310))
	woke = await wait(3.0, func() -> bool: return snake.is_awake())
	check("he wakes when the boy comes near", slept and woke)
	await done(snake)

	# What a frame of him costs.
	for long_now: float in [12.0, 18.0, 30.0]:
		put(Vector3(60, 0.05, 340))
		var timed := snake_at(Vector3(0, 0, 340), long_now)
		watched = null
		await wait(0.3)
		timed.loose = true
		await wait(5.0)
		var started := Time.get_ticks_usec()
		for i in 240:
			timed._physics_process(1.0 / 60.0)
		var moving := (Time.get_ticks_usec() - started) / 240000.0
		started = Time.get_ticks_usec()
		for i in 240:
			timed._draw(1.0 / 60.0)
		var laying := (Time.get_ticks_usec() - started) / 240000.0
		var costs := timed.cost()
		print("COST %d m: %.3f ms a frame to move, %.3f ms to lay his body; %d triangles in %d draws" % [int(long_now), moving, laying, costs["triangles"], costs["draws"]])
		timed.queue_free()
		await wait(0.2)

	check("no part of him was ever under the ground", under < 0.06, "the worst was %.3f m" % under)
	check("his head was never through a wall", through == 0, "%d frames" % through)
	await in_the_desert()
	print("PASSED" if failed == 0 else "FAILED (%d)" % failed)
	quit(1 if failed > 0 else 0)


# In the desert, made from an item as the level editor makes him: a plate lets him out and sends him home.
func in_the_desert() -> void:
	stage.queue_free()
	var scene: Node = load("res://desert.tscn").instantiate()
	root.add_child(scene)
	await wait(0.6)
	var level: Desert = scene.get_node("Level")
	var him := scene.get_node("Player") as Player
	var on_palette := false
	for entry: Array in LevelLayout.PALETTE["People"]:
		on_palette = on_palette or (entry[0] == "Apophis" and entry[1] == "person" and entry[2] == "apophis")
	var plate := LevelLayout.new_item(level.layout, "plate", "", Vector2(60, 100))
	level.layout["items"].append(plate)
	level.make(plate)
	var item := LevelLayout.new_item(level.layout, "person", "apophis", Vector2(70, 100))
	item["links"] = [plate["id"]]
	item["length"] = 13.0
	item["speed"] = 3.0
	level.layout["items"].append(item)
	var snake := level.make(item) as Apophis
	check("he is on the People page and is made from what it says", on_palette and snake != null and LevelLayout.label(item) == "Apophis" and LevelLayout.fields(item).size() == 6
			and is_equal_approx(snake.length, 13.0) and is_equal_approx(snake.speed, 3.0), LevelLayout.label(item))
	if snake == null:
		return
	snake.voice = false
	him.global_position = Vector3(84, level.height_at(84, 100) + 0.1, 100)
	him.velocity = Vector3.ZERO
	await wait(1.0)
	check("in the desert he rests on the ground, and waits", snake.state == Apophis.State.DORMANT and snake.target == him and absf(snake._home.origin.y - level.height_at(70, 100)) < 0.1,
			"he rests at %.2f, the ground is at %.2f" % [snake._home.origin.y, level.height_at(70, 100)])
	level._on[plate["id"]] = true
	var woke := await wait(2.0, func() -> bool: return snake.is_awake())
	await wait(4.0)
	check("a plate linked to him lets him out", woke and snake.chasing)
	level._on[plate["id"]] = false
	var back := await wait(30.0, func() -> bool: return snake.state == Apophis.State.DORMANT)
	check("and when it goes off he goes home", back)
	level._on[plate["id"]] = true
	var hits := [0]
	snake.caught.connect(func() -> void: hits[0] += 1)
	var got := await wait(30.0, func() -> bool: return him.is_limp)
	check("he catches the boy there, who goes down", got and hits[0] > 0)
	level.forget(item["id"])
	level.forget(plate["id"])
