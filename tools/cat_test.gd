extends SceneTree
## Not part of the game. Runs a cat through what it does of its own accord, with nothing drawn, and says
## whether each thing happened: it wanders, it sits and watches the boy, a hound sends it up onto
## something the hound cannot reach, and it comes down again when the hound has gone.
## godot --headless --path . --fixed-fps 60 --script tools/cat_test.gd
## Ends with PASSED or FAILED (and exits 0 or 1).

var stage: Node3D
var failed := 0


func _initialize() -> void:
	stage = Node3D.new()
	root.add_child(stage)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-48.0, -35.0, 0.0)
	stage.add_child(sun)
	box(Vector3(0, -1, 0), Vector3(80, 2, 80))
	# Too high for a hound (it jumps 1.3), not for a cat (1.6)
	box(Vector3(4, 0.75, -4), Vector3(2, 1.5, 2))
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


func run() -> void:
	for action: StringName in InputMap.get_actions():
		if not String(action).begins_with("ui_"):
			InputMap.action_erase_events(action)
	var touch := TouchControls.new()
	touch.visible = false
	stage.add_child(touch)
	touch.set_process_input(false)
	var boy: Player = load("res://player.tscn").instantiate()
	boy.position = Vector3(-6, 0.05, 3)
	stage.add_child(boy)
	boy.set_process_unhandled_input(false)
	boy.set_physics_process(false)

	var cat := Cat.new()
	cat.position = Vector3(0, 0.05, 0)
	cat.voice = false
	cat.nap_after = 100000.0
	cat.tame = 0.6
	cat.curiosity = 0.0
	stage.add_child(cat)
	cat.target = boy
	await wait(0.5)

	# Wandering: left to itself it goes somewhere, and stays on the ground.
	var furthest := [0.0]
	var states := {}
	await wait(40.0, func() -> bool:
		furthest[0] = maxf(furthest[0], cat.global_position.distance_to(Vector3.ZERO))
		states[cat.state] = true
		return false)
	check("wanders", furthest[0] > 0.8 and absf(cat.global_position.y) < 0.2, "went %.1f m, states seen %s" % [furthest[0], str(states.keys())])

	# Watching: sitting, its eyes on him.
	cat._set_state(Cat.State.WATCH)
	var watching := await wait(8.0, func() -> bool: return cat.state == Cat.State.WATCH and cat.posture == Cat.Posture.SIT and cat.gaze == boy)
	check("sits and watches the boy", watching, "posture %d, gaze %s" % [cat.posture, cat.gaze])
	var turned := absf(angle_difference(cat.facing_yaw, atan2(boy.global_position.x - cat.global_position.x, boy.global_position.z - cat.global_position.z)))
	check("is turned to him", turned < 0.6, "%.2f rad off" % turned)

	# A hound: up onto the block.
	cat._set_state(Cat.State.WANDER)
	cat.global_position = Vector3(0.5, 0.05, 0.5)
	await wait(0.3)
	var dog := Hound.new()
	dog.position = cat.global_position + Vector3(-7, 0.05, 5)
	dog.play_time = 0.0
	dog.settle_after = 100000.0
	stage.add_child(dog)
	dog.bidden = cat.global_position
	dog.bidden_speed = 2.4
	var fled := await wait(15.0, func() -> bool:
		dog.bidden = Vector3(4, 0, -2.4)
		return cat.state == Cat.State.PERCHED and not cat.is_leaping())
	check("flees a hound up onto something high", fled and cat.global_position.y > 1.4, "state %d at %s" % [cat.state, cat.global_position])
	await wait(4.0)
	check("stays up while the hound is there", cat.state == Cat.State.PERCHED and cat.global_position.y > 1.4, "mood %d posture %d" % [cat.mood, cat.posture])

	# The hound goes: down again.
	dog.queue_free()
	var down := await wait(20.0, func() -> bool: return cat.state != Cat.State.PERCHED and cat.state != Cat.State.RETURN and not cat.is_leaping())
	await wait(1.0)
	check("comes down when it has gone", down and cat.global_position.y < 0.2, "state %d at %s" % [cat.state, cat.global_position])

	# And the rest of what it does, each set going and left to run: nothing should break.
	for state: Cat.State in [Cat.State.RUB, Cat.State.NAP, Cat.State.WAKE, Cat.State.FOLLOW, Cat.State.AWAY, Cat.State.WANDER]:
		cat._set_state(state)
		cat._still = 10.0
		cat.nap_length = 3.0
		await wait(14.0)
		check("runs state %d" % state, is_instance_valid(cat) and absf(cat.global_position.y) < 0.3 and cat.global_position.is_finite(), "ended in state %d at %s" % [cat.state, cat.global_position])

	print("PASSED" if failed == 0 else "FAILED (%d)" % failed)
	quit(1 if failed > 0 else 0)
