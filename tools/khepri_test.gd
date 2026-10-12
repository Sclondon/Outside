extends SceneTree
## Not part of the game. Runs Khepri and the sun with nothing drawn and says whether each thing happened. On a bare
## floor: it rolls straight, a square a second, and the ball turns as far as it travels; it stops when it is held and
## the beetle gets up; it turns right at a wall (and left, if that is its side), the other way when its side is shut,
## back from a dead end, and waits when it is shut in all round; it is turned by the act button; the boy standing in
## its way turns it and walking into it does not move it; it rolls over a low kerb and not a high one, and does not go
## off a drop or into water; it presses a plate; it lights a sun disc it passes, but not through a wall; scarabs fear
## it and it is no fire. Then in its court (`KhepriCourt`, the test yard's station): left alone it goes round by the
## walls and never comes to the horizon; with the blocks pushed (one of them by the boy) it does, the sun rises, the
## horizon is on and its door opens; and it goes the same way, square for square, every time. Then in the desert,
## made from items as the level editor makes them, and let go by a lever.
## godot --headless --path . --fixed-fps 60 --script tools/khepri_test.gd
## Ends with PASSED or FAILED (and exits 0 or 1).

var stage: Node3D
var failed := 0
var boy: Player
var touch: TouchControls
var level: Desert


func _initialize() -> void:
	stage = Node3D.new()
	root.add_child(stage)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-48.0, -35.0, 0.0)
	stage.add_child(sun)
	box(Vector3(150, -1, 0), Vector3(400, 2, 80))
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


func put(at: Vector3, facing := 0.0) -> void:
	touch.move = Vector2.ZERO
	boy.global_position = at
	boy.velocity = Vector3.ZERO
	boy.facing_yaw = facing


## A sun at a place, going along +Z from there; its right is -X.
func sun_at(at: Vector3, go := true) -> Khepri:
	var khepri := Khepri.new()
	khepri.voice = false
	khepri.position = at
	stage.add_child(khepri)
	khepri.running = go
	return khepri


## Where a square of a sun at `from` is: x to its right, y ahead.
func sq(from: Vector3, x: float, y: float) -> Vector3:
	return from + Vector3(-x, 0.0, y)


## A block of wall filling a square.
func wall(from: Vector3, x: float, y: float, high := 1.2) -> StaticBody3D:
	return box(sq(from, x, y) + Vector3.UP * high * 0.5, Vector3(1.0, high, 1.0))


func said(path: Array) -> String:
	var words := PackedStringArray()
	for one: Vector2i in path:
		words.append("%d,%d" % [one.x, one.y])
	return " ".join(words)


func same(path: Array[Vector2i], wanted: Array) -> bool:
	if path.size() < wanted.size():
		return false
	for i in wanted.size():
		if path[i] != wanted[i]:
			return false
	return true


func run() -> void:
	for action: StringName in InputMap.get_actions():
		if not String(action).begins_with("ui_"):
			InputMap.action_erase_events(action)
	touch = TouchControls.new()
	touch.visible = false
	stage.add_child(touch)
	touch.set_process_input(false)
	boy = load("res://player.tscn").instantiate()
	boy.position = Vector3(-20, 0.05, 20)
	boy.rest_enabled = false
	stage.add_child(boy)
	boy.set_process_unhandled_input(false)
	await wait(0.5)

	await straight()
	await turning()
	await by_hand()
	await in_its_way()
	await kerbs_drops_and_water()
	await a_plate()
	await as_a_light()
	await in_its_court()
	boy.set_physics_process(false)
	stage.queue_free()
	await wait(0.2)
	await in_the_desert()
	print("PASSED" if failed == 0 else "FAILED (%d)" % failed)
	quit(1 if failed > 0 else 0)


func straight() -> void:
	var from := Vector3(0, 0, 0)
	var khepri := sun_at(from, false)
	await wait(0.5)
	check("it does not go until it is let go", khepri.state == Khepri.State.REST and khepri.path.is_empty() and khepri.global_position.is_equal_approx(from))
	check("stopped, the beetle is up on the ball", khepri._beetle.global_position.y > Khepri.SUN - 0.1, "%.2f" % khepri._beetle.global_position.y)
	check("it is a light, and it cannot be picked up", khepri._lamp.visible and khepri._lamp.light_energy > 1.0 and not khepri.is_in_group(&"throwable") and khepri is CharacterBody3D)
	# How long a square takes, in steps of the game.
	var ticks := [0]
	var took: Array[int] = []
	khepri.came_to.connect(func(_square: Vector2i) -> void:
		took.append(ticks[0])
		ticks[0] = 0)
	khepri.running = true
	await wait(Khepri.GET_DOWN + 0.2)
	check("the beetle gets down behind it to push, head down", khepri._beetle.global_position.y < 0.3 and khepri._beetle.global_position.z < from.z + khepri.global_position.z - 0.3 and khepri._beetle.global_basis.z.y < -0.4,
			"at %s, nose %.2f" % [khepri._beetle.global_position, khepri._beetle.global_basis.z.y])
	var turned := [0.0, Vector3.ZERO]
	await wait(6.0, func() -> bool:
		ticks[0] += 1
		if khepri.path.size() == 1 and turned[0] == 0.0:
			turned[0] = khepri._ball.basis.get_rotation_quaternion().get_angle()
			turned[1] = khepri._ball.basis.get_rotation_quaternion().get_axis()
		return khepri.path.size() >= 4)
	check("let go, it rolls straight, square by square", same(khepri.path, [Vector2i(0, 1), Vector2i(0, 2), Vector2i(0, 3), Vector2i(0, 4)]) and absf(khepri.global_position.x) < 0.001, said(khepri.path))
	check("at a metre a second", took.size() >= 4 and took[1] == 60 and took[2] == 60 and took[3] == 60, str(took))
	check("and the ball turns as far as it travels", absf(turned[0] - 1.0 / Khepri.R) < 0.02 and (turned[1] as Vector3).x > 0.99, "%.3f rad in a metre round %s, wanted %.3f" % [turned[0], turned[1], 1.0 / Khepri.R])
	check("it presses on nothing and is on the ground", absf(khepri.global_position.y) < 0.01 and khepri.square == Vector2i(0, 4))
	# Held: it finishes its square and stops there.
	await wait(0.4)
	khepri.running = false
	await wait(2.0)
	var stopped := khepri.global_position
	await wait(1.0)
	check("held, it finishes its square and stops in the middle of it", khepri.state == Khepri.State.REST and khepri.global_position == stopped and stopped.is_equal_approx(sq(from, 0, 5)) and khepri.path.size() == 5, "%s" % stopped)
	check("and the beetle climbs back up", khepri._beetle.global_position.y > Khepri.SUN - 0.1)
	khepri.reset()
	await wait(0.2)
	check("put back, it is where it started", khepri.global_position.is_equal_approx(from) and khepri.path.is_empty() and khepri.heading == 0 and khepri.square == Vector2i.ZERO and not khepri.running)
	khepri.queue_free()
	# One that starts itself.
	var keen := Khepri.new()
	keen.voice = false
	keen.starts_itself = true
	keen.position = from
	stage.add_child(keen)
	var went := await wait(4.0, func() -> bool: return keen.path.size() >= 1)
	check("one that starts itself goes without being let go", went and keen.running)
	keen.queue_free()
	await wait(0.1)


func turning() -> void:
	# A wall four squares on.
	var from := Vector3(20, 0, 0)
	var block := wall(from, 0, 4)
	var khepri := sun_at(from)
	await wait(12.0, func() -> bool: return khepri.path.size() >= 5)
	check("at a wall it turns right", same(khepri.path, [Vector2i(0, 1), Vector2i(0, 2), Vector2i(0, 3), Vector2i(1, 3), Vector2i(2, 3)]), said(khepri.path))
	check("and has not touched the wall", khepri.global_position.z < from.z + 3.01)
	khepri.queue_free()
	var left := Khepri.new()
	left.voice = false
	left.turns = Khepri.Turns.LEFT
	left.position = from
	stage.add_child(left)
	left.running = true
	await wait(12.0, func() -> bool: return left.path.size() >= 5)
	check("one that turns left turns left", same(left.path, [Vector2i(0, 1), Vector2i(0, 2), Vector2i(0, 3), Vector2i(-1, 3), Vector2i(-2, 3)]), said(left.path))
	left.queue_free()
	# Its side shut too.
	var side := wall(from, 1, 3)
	khepri = sun_at(from)
	await wait(12.0, func() -> bool: return khepri.path.size() >= 5)
	check("with its side shut too it turns the other way", same(khepri.path, [Vector2i(0, 1), Vector2i(0, 2), Vector2i(0, 3), Vector2i(-1, 3), Vector2i(-2, 3)]), said(khepri.path))
	khepri.queue_free()
	# A dead end.
	var other := wall(from, -1, 3)
	khepri = sun_at(from)
	await wait(14.0, func() -> bool: return khepri.path.size() >= 5)
	check("from a dead end it comes back the way it went", same(khepri.path, [Vector2i(0, 1), Vector2i(0, 2), Vector2i(0, 3), Vector2i(0, 2), Vector2i(0, 1)]), said(khepri.path))
	khepri.queue_free()
	khepri = sun_at(from)
	khepri.turns_back = false
	await wait(9.0)
	check("or waits there, if it is not to turn back", same(khepri.path, [Vector2i(0, 1), Vector2i(0, 2), Vector2i(0, 3)]) and khepri.path.size() == 3 and khepri.state == Khepri.State.WAIT, said(khepri.path))
	khepri.queue_free()
	for one: Node in [block, side, other]:
		one.queue_free()
	# Shut in all round.
	from = Vector3(40, 0, 0)
	var round_it: Array[StaticBody3D] = [wall(from, 0, 1), wall(from, 1, 0), wall(from, -1, 0), wall(from, 0, -1)]
	khepri = sun_at(from)
	await wait(5.0)
	check("shut in all round it waits", khepri.state == Khepri.State.WAIT and khepri.path.is_empty() and khepri.global_position.is_equal_approx(from))
	round_it[3].queue_free()
	var out := await wait(4.0, func() -> bool: return khepri.path.size() >= 1)
	check("and goes when a way is opened", out and khepri.path[0] == Vector2i(0, -1), said(khepri.path))
	khepri.queue_free()
	for i in 3:
		round_it[i].queue_free()
	await wait(0.1)


func by_hand() -> void:
	var from := Vector3(60, 0, 0)
	var khepri := sun_at(from, false)
	put(from + Vector3(0.9, 0.05, 0.0), -PI * 0.5)
	await wait(0.5)
	check("it is something to work", khepri.is_in_group(&"workable") and boy._workable(INF) == khepri)
	boy._act()
	await wait(1.0)
	check("the act button beside it turns it a quarter turn", khepri.heading == 1 and khepri.state == Khepri.State.REST and khepri.global_position.is_equal_approx(from), "heading %d" % khepri.heading)
	put(from + Vector3(0.0, 0.05, -6.0))
	khepri.running = true
	await wait(5.0, func() -> bool: return khepri.path.size() >= 2)
	check("and it goes the way it was turned", same(khepri.path, [Vector2i(1, 0), Vector2i(2, 0)]), said(khepri.path))
	# Turned while it rolls: it turns at the next square.
	khepri.work()
	await wait(6.0, func() -> bool: return khepri.path.size() >= 5)
	check("turned while it rolls, it turns at the next square", same(khepri.path, [Vector2i(1, 0), Vector2i(2, 0), Vector2i(3, 0), Vector2i(3, -1), Vector2i(3, -2)]), said(khepri.path))
	khepri.queue_free()
	await wait(0.1)


func in_its_way() -> void:
	var from := Vector3(80, 0, 0)
	var khepri := sun_at(from, false)
	# He stands two squares on.
	put(sq(from, 0, 2) + Vector3.UP * 0.05)
	await wait(0.4)
	khepri.running = true
	await wait(8.0, func() -> bool: return khepri.path.size() >= 3)
	check("the boy standing in its way turns it", same(khepri.path, [Vector2i(0, 1), Vector2i(1, 1), Vector2i(2, 1)]), said(khepri.path))
	check("and he has not been moved", boy.global_position.distance_to(sq(from, 0, 2)) < 0.15, "%s" % boy.global_position)
	khepri.running = false
	await wait(2.5)
	# He walks into it: he stops against it and it does not move.
	var rests := khepri.global_position
	put(rests + Vector3(0.0, 0.05, -2.0))
	await wait(0.3)
	touch.move = Vector2(0, 1)
	await wait(2.5)
	var reached := boy.global_position
	touch.move = Vector2.ZERO
	await wait(0.3)
	check("walking into it, he stops against it", reached.z < rests.z - 0.45 and reached.z > rests.z - 0.75 and absf(reached.x - rests.x) < 0.2, "he is at %s, it is at %s" % [reached, rests])
	check("and it is not pushed", khepri.global_position == rests and not boy.is_pushing)
	# He steps in front of it as it rolls: it goes back to the square it left, and turns.
	khepri.reset()
	put(from + Vector3(3.0, 0.05, 0.0))
	await wait(0.3)
	khepri.running = true
	await wait(6.0, func() -> bool: return khepri.path.size() >= 1 and khepri.state == Khepri.State.ROLL and khepri._along > 0.2)
	put(sq(from, 0, 2) + Vector3.UP * 0.05)
	await wait(8.0, func() -> bool: return khepri.path.size() >= 3)
	check("stepped in front of as it rolls, it goes back a square and turns", same(khepri.path, [Vector2i(0, 1), Vector2i(1, 1), Vector2i(2, 1)]), said(khepri.path))
	# He stands on top of it: it waits.
	khepri.reset()
	await wait(0.2)
	put(from + Vector3(0.0, Khepri.SUN + 0.05, 0.0))
	await wait(0.6)
	var on_it := boy.global_position.y > Khepri.SUN - 0.15 and Vector2(boy.global_position.x - from.x, boy.global_position.z - from.z).length() < 0.4
	khepri.running = true
	await wait(3.0)
	check("with him standing on it, it waits", not on_it or (khepri.path.is_empty() and khepri.state == Khepri.State.WAIT), "on it: %s, he is at %s" % [on_it, boy.global_position])
	khepri.queue_free()
	put(Vector3(-20, 0.05, 20))
	await wait(0.1)


func kerbs_drops_and_water() -> void:
	# A kerb it goes over, and one it does not.
	var from := Vector3(100, 0, 0)
	box(sq(from, 0, 2) + Vector3.UP * 0.1, Vector3(3.0, 0.2, 1.0))
	box(sq(from, 0, 5) + Vector3.UP * 0.2, Vector3(3.0, 0.4, 1.0))
	var khepri := sun_at(from)
	var highest := [0.0]
	await wait(12.0, func() -> bool:
		if khepri.square == Vector2i(0, 2):
			highest[0] = maxf(highest[0], khepri.global_position.y)
		return khepri.path.size() >= 6)
	check("it rolls up over a low kerb and down again", same(khepri.path, [Vector2i(0, 1), Vector2i(0, 2), Vector2i(0, 3), Vector2i(0, 4)]) and absf(highest[0] - 0.2) < 0.01, "%s, up to %.2f" % [said(khepri.path), highest[0]])
	check("and turns at one that is too high", same(khepri.path, [Vector2i(0, 1), Vector2i(0, 2), Vector2i(0, 3), Vector2i(0, 4), Vector2i(1, 4), Vector2i(2, 4)]), said(khepri.path))
	khepri.queue_free()
	# A table three squares by two, a metre up: it never leaves it.
	from = Vector3(120, 1.0, 0)
	box(from + Vector3(-0.5, -0.5, 1.0), Vector3(2.0, 1.0, 3.0))
	khepri = sun_at(from)
	var worst := [1.0, 0]
	await wait(26.0, func() -> bool:
		worst[0] = minf(worst[0], khepri.global_position.y)
		if khepri.square.x < 0 or khepri.square.x > 1 or khepri.square.y < 0 or khepri.square.y > 2:
			worst[1] += 1
		return khepri.path.size() >= 12)
	check("it does not go off a drop", khepri.path.size() >= 12 and worst[1] == 0 and worst[0] > 0.99, "%s, lowest %.2f" % [said(khepri.path), worst[0]])
	check("it goes round the edge of the table", same(khepri.path, [Vector2i(0, 1), Vector2i(0, 2), Vector2i(1, 2), Vector2i(1, 1), Vector2i(1, 0), Vector2i(0, 0), Vector2i(0, 1)]), said(khepri.path))
	khepri.queue_free()
	# Water lying on the floor three squares on.
	from = Vector3(140, 0, 0)
	var pool := Pool.new()
	pool.size = Vector3(6.0, 1.0, 2.0)
	pool.position = sq(from, 0, 3.5) + Vector3.UP * 0.1
	stage.add_child(pool)
	khepri = sun_at(from)
	await wait(10.0, func() -> bool: return khepri.path.size() >= 4)
	check("it does not go into water", same(khepri.path, [Vector2i(0, 1), Vector2i(0, 2), Vector2i(1, 2), Vector2i(2, 2)]), said(khepri.path))
	khepri.queue_free()
	pool.queue_free()
	await wait(0.1)


func a_plate() -> void:
	var from := Vector3(160, 0, 0)
	var plate := TombParts.Plate.new()
	plate.span = Vector3(1.0, 0.5, 1.0)
	plate.position = sq(from, 0, 2)
	stage.add_child(plate)
	var presses := [0, 0]
	plate.changed.connect(func(pressed: bool) -> void: presses[0 if pressed else 1] += 1)
	var khepri := sun_at(from)
	var on_it := [false, false]
	await wait(8.0, func() -> bool:
		if khepri.global_position.distance_to(plate.global_position) < 0.05:
			on_it[0] = plate.pressed
		return khepri.path.size() >= 4)
	check("it presses a plate it rolls onto", on_it[0] and presses[0] == 1, "pressed %d times" % presses[0])
	check("and the plate comes up when it has gone", not plate.pressed and presses[1] == 1)
	khepri.queue_free()
	plate.queue_free()
	await wait(0.1)


func as_a_light() -> void:
	var from := Vector3(180, 0, 0)
	# A sun disc a square and a half to the side of its way, and another behind a wall.
	var disc := SunDisc.new()
	disc.position = sq(from, -1.5, 3)
	stage.add_child(disc)
	var hidden := SunDisc.new()
	hidden.position = sq(from, 1.5, 3)
	stage.add_child(hidden)
	var screen := box(sq(from, 0.8, 3) + Vector3.UP, Vector3(0.2, 2.0, 5.0))
	var khepri := sun_at(from, false)
	await wait(0.4)
	check("a sun disc far from it is not lit", not disc.on and not hidden.on)
	khepri.running = true
	var lit := [false, false]
	await wait(12.0, func() -> bool:
		lit[0] = lit[0] or disc.on
		lit[1] = lit[1] or hidden.on
		return khepri.path.size() >= 8)
	check("it lights a sun disc it passes", lit[0])
	check("but not one behind a wall", not lit[1])
	check("and the disc goes out when it has gone by", not disc.on, "it is %.1f m off" % khepri.global_position.distance_to(disc.global_position))
	check("what fears fire fears it", Nearby.feared(self).has(khepri) and khepri.is_in_group(&"sunlight"))
	check("but it is not a fire: it burns nothing", not Nearby.fires(self).has(khepri))
	# Scarabs let out beside it do not come near it.
	khepri.running = false
	# (with nothing else about: they run along a wall they meet, light or no light)
	disc.queue_free()
	hidden.queue_free()
	screen.queue_free()
	await wait(1.5)
	var rests := khepri.global_position
	var swarm := ScarabSwarm.new()
	swarm.count = 60
	swarm.voice = false
	swarm.position = rests + Vector3(5.0, 0.0, 0.0)
	stage.add_child(swarm)
	put(rests + Vector3(-0.8, 0.05, 0.0))
	swarm.target = boy
	var caught := [0]
	swarm.caught.connect(func() -> void: caught[0] += 1)
	await wait(0.3)
	swarm.chasing = true
	var nearest := [INF]
	await wait(9.0, func() -> bool:
		for i in swarm.count:
			if swarm._state[i] == ScarabSwarm.OUT:
				nearest[0] = minf(nearest[0], Vector2(swarm._x[i] - rests.x, swarm._z[i] - rests.z).length())
		return false)
	check("scarabs keep off it, and off him beside it", swarm.out > 20 and nearest[0] > 1.5 and caught[0] == 0 and swarm.on_him == 0, "out %d, nearest %.2f m, on him %d" % [swarm.out, nearest[0], swarm.on_him])
	swarm.queue_free()
	khepri.queue_free()
	put(Vector3(-20, 0.05, 20))
	await wait(0.1)


## Lets the sun of a court go and gives it time: the squares it came to, up to `most` of them or until the sun has risen.
func round_of(court: KhepriCourt, most: int) -> Array[Vector2i]:
	court.lever.work()
	await wait(most * 1.7 + 10.0, func() -> bool: return court.khepri.path.size() >= most or court.khepri.is_risen())
	var went: Array[Vector2i] = court.khepri.path.duplicate()
	return went


func in_its_court() -> void:
	var court := KhepriCourt.new()
	court.signed = false
	court.position = Vector3(260, 0, 0)
	stage.add_child(court)
	court.khepri.voice = false
	await wait(0.6)
	var khepri := court.khepri
	check("the court's sun starts in its corner, held", khepri.global_position.is_equal_approx(court.square(0, 0)) and not khepri.running and not court.akhet.on and not court.door.is_open)
	# Left alone: round by the walls, for ever.
	var loop := await round_of(court, 40)
	var edge := true
	for one in loop:
		edge = edge and (one.x == 0 or one.x == 8 or one.y == 0 or one.y == 8)
	check("left alone it goes round by the walls", loop.size() >= 40 and edge and loop[31] == Vector2i(0, 0) and loop[39] == Vector2i(0, 8), said(loop))
	check("and never comes to the horizon", not court.akhet.on and not khepri.is_risen() and not court.door.is_open)
	court.reset()
	await wait(0.5)
	check("put back, the court is as it was", khepri.global_position.is_equal_approx(court.square(0, 0)) and khepri.path.is_empty() and not court.lever.on and not khepri.running)

	# The side gate and the disc, as it goes round.
	var seen := [false, false, false]
	court.lever.work()
	await wait(40.0, func() -> bool:
		seen[0] = seen[0] or court.disc.on
		seen[1] = seen[1] or court.side_gate.is_open
		seen[2] = seen[2] or (court.plate.pressed and khepri.square == Vector2i(8, 2))
		return khepri.path.size() >= 32)
	check("going round, it lights the court's disc, presses its plate and so holds the side gate up", seen[0] and seen[1] and seen[2] and not court.side_gate.is_open, str(seen))
	court.reset()
	await wait(0.5)

	# One block pushed: it crosses the court, but still does not come to the horizon.
	court.blocks[0].global_position = court.square(0, 5) + Vector3.UP * 0.45
	await wait(0.5)
	var crossed := await round_of(court, 34)
	check("with only the first block pushed it crosses the court and goes round again", crossed.has(Vector2i(4, 4)) and crossed.has(Vector2i(8, 4)) and not crossed.has(Vector2i(0, 5)) and not court.akhet.on, said(crossed))
	court.reset()
	await wait(0.5)

	# Both, put exactly: it comes to the horizon. Twice, and the same way both times.
	var ways: Array = []
	for go in 2:
		court.blocks[0].global_position = court.square(0, 5) + Vector3.UP * 0.45
		court.blocks[1].global_position = court.square(5, 4) + Vector3.UP * 0.45
		await wait(0.5)
		var went := await round_of(court, 60)
		ways.append(went)
		if go == 0:
			check("with both blocks pushed it comes to the horizon", went.size() == 10 and same(went, [Vector2i(0, 1), Vector2i(0, 2), Vector2i(0, 3), Vector2i(0, 4), Vector2i(1, 4), Vector2i(2, 4), Vector2i(3, 4), Vector2i(4, 4), Vector2i(4, 3), Vector2i(4, 2)]), said(went))
			check("the sun has risen between the hills", khepri.is_risen() and khepri.global_position.is_equal_approx(court.akhet.risen()) and khepri.akhet() == court.akhet, "%s, wanted %s" % [khepri.global_position, court.akhet.risen()])
			check("the horizon is on", court.akhet.on)
			await wait(1.5)
			check("and its door opens", court.door.is_open and court.door.position.y > 2.0, "%.2f" % court.door.position.y)
			check("the beetle sits on a hill with its wings out", khepri._beetle.global_position.distance_to(court.akhet.perch()) < 0.05 and khepri._open > 0.99, "%.2f m from it" % khepri._beetle.global_position.distance_to(court.akhet.perch()))
			check("and the room is lit for good", khepri._lamp.light_energy > khepri.light_energy * 1.5 and khepri._lamp.omni_range > khepri.light_reach * 1.5)
			# It stays: the lever does nothing to it now, and nor does the act button.
			court.lever.work()
			khepri.work()
			await wait(2.0)
			check("it stays there whatever is done", khepri.is_risen() and court.akhet.on and khepri.path.size() == 10)
		court.reset()
		await wait(0.5)
		if go == 0:
			check("put back, the sun is in its corner, the horizon off and the door shut", khepri.global_position.is_equal_approx(court.square(0, 0)) and not court.akhet.on and not court.door.is_open and not khepri.is_risen() and khepri._open < 0.01)
	check("it goes the same way every time, square for square", ways[0] == ways[1] and (ways[0] as Array).size() == 10, "%s | %s" % [said(ways[0]), said(ways[1])])

	# And played: he pushes each block himself, walking into it until it will go no further.
	put(court.square(3, 5) + Vector3.UP * 0.1)
	await wait(0.4)
	# (the sun's right is -X: a block at x = 2 is pushed toward x = 0, which is +X)
	touch.move = Vector2(1, 0)
	await wait(6.0, func() -> bool: return court.blocks[0].global_position.distance_to(court.square(0, 5) + Vector3.UP * 0.45) < 0.12 and court.blocks[0].linear_velocity.length() < 0.05)
	await wait(0.5)
	touch.move = Vector2.ZERO
	var first := court.blocks[0].global_position - court.square(0, 5)
	check("he pushes the first block along to the wall", Vector2(first.x, first.z).length() < 0.2, "it is %.2f, %.2f from the middle of its square" % [first.x, first.z])
	put(court.square(5, 7) + Vector3.UP * 0.1)
	await wait(0.4)
	touch.move = Vector2(0, -1)
	await wait(6.0, func() -> bool: return court.blocks[1].global_position.distance_to(court.square(5, 4) + Vector3.UP * 0.45) < 0.12 and court.blocks[1].linear_velocity.length() < 0.05)
	await wait(0.5)
	touch.move = Vector2.ZERO
	var second := court.blocks[1].global_position - court.square(5, 4)
	check("and the second down against the pillar", Vector2(second.x, second.z).length() < 0.2, "it is %.2f, %.2f from the middle of its square" % [second.x, second.z])
	# He goes to the lever and pulls it.
	put(court.lever.global_position + Vector3(0.0, 0.05, -0.9))
	await wait(0.5)
	boy._act()
	await wait(0.3)
	check("he pulls the lever and the sun is let go", court.lever.on and khepri.running)
	await wait(30.0, func() -> bool: return khepri.is_risen())
	await wait(1.0)
	check("played so, the sun comes to the horizon the same way and the door opens", khepri.is_risen() and court.akhet.on and court.door.is_open and khepri.path.size() == 10 and same(khepri.path, ways[0]), said(khepri.path))
	court.queue_free()
	put(Vector3(-20, 0.05, 20))
	await wait(0.1)


# --- In the desert, made from items ---

func add(kind: String, what: String, at: Vector2, more := {}) -> Dictionary:
	var item := LevelLayout.new_item(level.layout, kind, what, at)
	item.merge(more, true)
	level.layout["items"].append(item)
	level.make(item)
	return item


func node(item: Dictionary) -> Node3D:
	return level.nodes.get(item["id"])


func in_the_desert() -> void:
	# (nothing here saves a level; but if it did, it would not be the player's)
	LevelLayout.saved_at = "user://khepri_test.json"
	var scene: Node = load("res://desert.tscn").instantiate()
	root.add_child(scene)
	await wait(0.6)
	level = scene.get_node("Level")
	var him := scene.get_node("Player") as Player
	him.set_physics_process(false)
	var found := 0
	for entry: Array in LevelLayout.PALETTE["Puzzle"]:
		if entry[1] in ["khepri", "akhet"]:
			found += 1
	check("both are on the editor's Puzzle page", found == 2)
	# A floor of our own, well above the dunes, and everything stood on it.
	var high := 80.0
	var floor_at := Vector3(300.0, high, 300.0)
	var slab := StaticBody3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(30, 1, 30)
	var collider := CollisionShape3D.new()
	collider.shape = shape
	slab.add_child(collider)
	slab.position = floor_at + Vector3.DOWN * 0.5
	scene.add_child(slab)
	var lift := func(at: Vector2) -> float: return high - level.height_at(at.x, at.y)
	var here := Vector2(floor_at.x, floor_at.z)
	var lever := add("lever", "", here + Vector2(3, -3), {"lift": lift.call(here + Vector2(3, -3))})
	# (turned a quarter turn: it sets off along +X, and its right is +Z)
	var sun := add("khepri", "", here, {"lift": lift.call(here), "yaw": 90.0, "links": [lever["id"]], "turns": 1, "pace": 2.0})
	var horizon := add("akhet", "", here + Vector2(3, -2), {"lift": lift.call(here + Vector2(3, -2)), "yaw": 0.0})
	var door := node(add("door", "", here + Vector2(0, 8), {"lift": lift.call(here + Vector2(0, 8)) + 1.3, "links": [horizon["id"]]})) as TombParts.Door
	var stop := add("prop", "block_push", here + Vector2(4, 0), {"lift": lift.call(here + Vector2(4, 0)) + 0.45})
	await wait(0.5)
	var khepri := node(sun) as Khepri
	var akhet := node(horizon) as Akhet
	check("the items make a Khepri and an Akhet, named as the editor names them", khepri != null and akhet != null and LevelLayout.label(sun) == "Khepri and the sun" and LevelLayout.label(horizon) == "Horizon (akhet)")
	check("with its settings", khepri != null and khepri.turns == Khepri.Turns.LEFT and is_equal_approx(khepri.pace, 2.0) and is_equal_approx(khepri.step, 1.0) and not khepri.starts_itself and khepri.turns_back)
	check("a block to push from the editor stands in its way", node(stop) is RigidBody3D)
	check("it waits for its lever, and the door for the horizon", not khepri.running and khepri.path.is_empty() and not door.is_open)
	(node(lever) as Lever).work()
	await wait(12.0, func() -> bool: return khepri.is_risen())
	# Along +X three squares; the block at the fourth turns it left (-Z) and two squares on is the cradle.
	check("let go by the lever it rolls, turns left at the block and comes to the horizon", khepri.is_risen() and khepri.path.size() == 5 and same(khepri.path, [Vector2i(0, 1), Vector2i(0, 2), Vector2i(0, 3), Vector2i(-1, 3), Vector2i(-2, 3)]), said(khepri.path))
	await wait(0.5)
	check("and the door linked to the horizon opens", akhet.on and door.is_open)
	# Kept and read back as a level is.
	var again := LevelLayout.from_text(LevelLayout.to_text(level.layout))
	var kept := 0
	for item: Dictionary in again["items"]:
		if item["id"] == sun["id"] and item["kind"] == "khepri" and item["links"] == [lever["id"]] and int(item["turns"]) == 1 and is_equal_approx(item["pace"], 2.0):
			kept += 1
		if item["id"] == horizon["id"] and item["kind"] == "akhet" and is_equal_approx(item["rise"], 0.55):
			kept += 1
	check("both are kept with the level and read back", kept == 2)
	# Moved in the editor, it starts from where it is put.
	sun["at"] = [here.x + 6.0, here.y + 6.0]
	level.put(sun)
	await wait(0.3)
	check("moved by the editor, it starts again from where it is put", not khepri.is_risen() and khepri.path.is_empty() and khepri.global_position.distance_to(Vector3(here.x + 6.0, high, here.y + 6.0)) < 0.01 and khepri.square == Vector2i.ZERO, "%s" % khepri.global_position)
	level.forget(sun["id"])
	level.forget(horizon["id"])
	await wait(0.2)
	check("and both can be taken out", not level.nodes.has(sun["id"]) and not level.nodes.has(horizon["id"]))
