extends SceneTree
## Not part of the game. Runs a camel through what it does of its own accord, with nothing drawn, and says
## whether each thing happened: it wanders, it stays within reach of its tether, it follows whoever leads it
## (and a second follows the first, in a string), it couches and gets up again, and it shies from a hound.
## godot --headless --path . --fixed-fps 60 --script tools/camel_test.gd
## Ends with PASSED or FAILED (and exits 0 or 1).

var stage: Node3D
var failed := 0


func _initialize() -> void:
	stage = Node3D.new()
	root.add_child(stage)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-48.0, -35.0, 0.0)
	stage.add_child(sun)
	box(Vector3(0, -1, 0), Vector3(200, 2, 200))
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


func camel(at: Vector3) -> Camel:
	var made := Camel.new()
	made.position = at
	made.voice = false
	stage.add_child(made)
	return made


func run() -> void:
	for action: StringName in InputMap.get_actions():
		if not String(action).begins_with("ui_"):
			InputMap.action_erase_events(action)
	var touch := TouchControls.new()
	touch.visible = false
	stage.add_child(touch)
	touch.set_process_input(false)
	var boy: Player = load("res://player.tscn").instantiate()
	boy.position = Vector3(-30, 0.05, 30)
	stage.add_child(boy)
	boy.set_process_unhandled_input(false)
	boy.set_physics_process(false)

	# Wandering: left to itself it goes somewhere, no further than it may, and browses.
	var loose := camel(Vector3(0, 0.05, 0))
	loose.rest_after = 100000.0
	loose.roam = 5.0
	var furthest := [0.0]
	var states := {}
	await wait(70.0, func() -> bool:
		furthest[0] = maxf(furthest[0], loose.global_position.distance_to(Vector3.ZERO))
		states[loose.state] = true
		loose._timer = minf(loose._timer, 2.0)
		return false)
	check("wanders", furthest[0] > 1.0 and furthest[0] < 6.5 and absf(loose.global_position.y) < 0.2, "went %.1f m of 5, states seen %s" % [furthest[0], str(states.keys())])
	check("browses", states.has(Camel.State.BROWSE))

	# Couching: when it has been up long enough it gets down, all the way; and after its rest it gets up.
	loose.rest_after = 0.5
	loose.rest_for = 8.0
	var down := await wait(120.0, func() -> bool: return loose.posture == Camel.Posture.COUCH and loose.couch() >= 1.0)
	check("couches", down, "state %d, %.2f of the way down" % [loose.state, loose.couch()])
	var where := loose.global_position
	await wait(4.0)
	check("stays where it couched", loose.global_position.distance_to(where) < 0.05)
	loose.rest_after = 100000.0
	var up := await wait(30.0, func() -> bool: return loose.posture == Camel.Posture.UP and loose.couch() <= 0.0)
	check("rises again", up, "state %d, %.2f of the way down" % [loose.state, loose.couch()])
	loose.queue_free()

	# Tethered: it has the run of its rope, and no more.
	var tied := camel(Vector3(40, 0.05, 0))
	tied.tether = Vector3(41, 0, 0)
	tied.tether_length = 3.5
	tied.roam = 15.0
	tied.rest_after = 100000.0
	furthest[0] = 0.0
	var moved := [0.0]
	await wait(90.0, func() -> bool:
		furthest[0] = maxf(furthest[0], Vector2(tied.global_position.x - 41.0, tied.global_position.z).length())
		moved[0] = maxf(moved[0], tied.global_position.distance_to(Vector3(40, 0, 0)))
		tied._timer = minf(tied._timer, 1.0)
		return false)
	check("stays on its tether", furthest[0] <= 3.5 and moved[0] > 0.5, "got %.2f m from its peg, of 3.5; moved %.1f m" % [furthest[0], moved[0]])
	check("wears its halter when it is tethered", tied.haltered)
	# Bidden past the end of its rope, it is held.
	tied.bidden = Vector3(60, 0, 0)
	await wait(12.0)
	check("is held by its tether", Vector2(tied.global_position.x - 41.0, tied.global_position.z).length() <= 3.6, "%.2f m from its peg" % Vector2(tied.global_position.x - 41.0, tied.global_position.z).length())
	tied.queue_free()

	# Led: a couched camel gets up and comes after the boy, and a second after the first.
	boy.global_position = Vector3(0, 0.05, -40)
	var first := camel(Vector3(-4, 0.05, -40))
	first.couched = true
	var second := camel(Vector3(-9, 0.05, -39))
	await wait(1.0)
	first.posture = Camel.Posture.COUCH
	first.state = Camel.State.REST
	first.follow(boy)
	second.follow(first)
	var fastest := [0.0]
	await wait(40.0, func() -> bool:
		boy.global_position.x += 1.1 / 60.0
		fastest[0] = maxf(fastest[0], Vector2(first.velocity.x, first.velocity.z).length())
		return false)
	var gap := first.global_position.distance_to(boy.global_position)
	var string := second.global_position.distance_to(first.global_position)
	check("follows whoever leads it", gap < 4.5 and gap > 1.5 and first.global_position.x > 20.0, "%.1f m behind him, at %s" % [gap, first.global_position])
	check("follows another camel in a string", string < 5.5 and string > 2.2 and second.global_position.x < first.global_position.x, "%.1f m behind the first" % string)
	check("is led at a walk once it has caught up", Vector2(first.velocity.x, first.velocity.z).length() < first.walk_speed * 1.3, "going %.2f m/s (fastest %.2f)" % [Vector2(first.velocity.x, first.velocity.z).length(), fastest[0]])
	first.follow(null)
	second.follow(null)
	await wait(3.0)
	check("stops when it is let go", first.state != Camel.State.FOLLOW and first.velocity.length() < 0.3)
	second.queue_free()

	# A hound: it will not stay near it.
	var dog := Hound.new()
	dog.position = first.global_position + Vector3(-9, 0.05, 2)
	dog.play_time = 0.0
	dog.settle_after = 100000.0
	stage.add_child(dog)
	var from := first.global_position
	dog.bidden = from + Vector3(-2, 0, 0)
	dog.bidden_speed = 2.4
	var shied := await wait(20.0, func() -> bool: return first.state == Camel.State.SHY and first.global_position.distance_to(from) > 2.0)
	check("shies from a pursuer", shied, "state %d, afraid %.2f, moved %.1f m" % [first.state, first.afraid, first.global_position.distance_to(from)])
	dog.queue_free()
	var calm := await wait(15.0, func() -> bool: return first.state != Camel.State.SHY)
	check("settles when it has gone", calm)

	check("has somewhere for a rider to sit", first.seat().origin.y - first.global_position.y > 1.6, "%.2f m up" % (first.seat().origin.y - first.global_position.y))
	print("PASSED" if failed == 0 else "FAILED (%d)" % failed)
	quit(1 if failed > 0 else 0)
