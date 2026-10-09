extends SceneTree
## Not part of the game. Runs the boy through the grappling hook with nothing drawn, and says
## whether each thing happened: he picks it up, it marks what it will catch, he throws it and is
## carried onto its rope, swings across a gap on it and lets go on the far side, and the hook comes
## back to his hand; thrown with nothing in reach it falls short and is wound in; and an ordinary
## rope still does what it did: caught at a jump, swung, climbed and leapt from.
## godot --headless --path . --fixed-fps 60 --script tools/grapple_test.gd
## Ends with PASSED or FAILED (and exits 0 or 1).

var stage: Node3D
var boy: Player
var touch: TouchControls
var failed := 0


func _initialize() -> void:
	stage = Node3D.new()
	root.add_child(stage)
	# Ground, a gap in it six metres across (from x = 5 to x = 11) with a floor far below, and more ground.
	box(Vector3(-17.5, -1, 0), Vector3(45, 2, 40))
	box(Vector3(41, -1, 0), Vector3(60, 2, 40))
	box(Vector3(8, -9, 0), Vector3(6, 2, 40))
	# A beam over the middle of the gap, with somewhere on it for a hook to catch
	box(Vector3(8, 6.3, 0), Vector3(0.4, 0.4, 3.0))
	GrapplePoint.mark(stage, Vector3(8, 6.05, 0))
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


func place(at: Vector3) -> void:
	touch.move = Vector2.ZERO
	touch.duck_held = false
	touch.jump_held = false
	touch.act_held = false
	boy.global_position = at
	boy.velocity = Vector3.ZERO
	boy._reset_visuals()


## How far round from straight down the rope he is on has swung, degrees, positive towards +x.
func angle() -> float:
	if not is_instance_valid(boy._rope):
		return 0.0
	var hold: Vector3 = boy._rope.point_at(boy._rope_at) - boy._rope.global_position
	return rad_to_deg(atan2(hold.x, -hold.y))


func run() -> void:
	for action: StringName in InputMap.get_actions():
		if not String(action).begins_with("ui_"):
			InputMap.action_erase_events(action)
	touch = TouchControls.new()
	touch.visible = false
	stage.add_child(touch)
	touch.set_process_input(false)
	boy = load("res://player.tscn").instantiate()
	boy.position = Vector3(1.4, 0.05, 0)
	stage.add_child(boy)
	boy.set_process_unhandled_input(false)
	boy.sleep_after = 0.0
	boy.facing_yaw = PI * 0.5
	var hook := GrappleHook.new()
	hook.position = Vector3(1.9, 0.3, 0)
	stage.add_child(hook)
	await wait(0.6)

	# --- Picking it up, and what it marks.
	boy._act()
	await wait(1.0)
	check("picks the hook up", boy.carried == hook, "carried %s" % boy.carried)
	touch.move = Vector2(1, 0)
	await wait(3.0, func() -> bool: return boy.global_position.x > 3.4)
	touch.move = Vector2.ZERO
	await wait(0.5)
	var point: Node3D = get_first_node_in_group(&"grapple_points")
	check("marks the point it will catch", hook.target == point and hook._mark.visible, "target %s, from x = %.2f" % [hook.target, boy.global_position.x])

	# --- Thrown at it: carried onto its rope.
	var from := boy.global_position
	boy._act()
	var frames := [0]
	var on := await wait(2.0, func() -> bool:
		frames[0] += 1
		return boy.state == Player.State.ROPE)
	check("the hook bites and he is on its rope", on and hook.state == GrappleHook.State.BITTEN and is_instance_valid(hook.rope), "%.2f s after act, the rope %.1f m long" % [frames[0] / 60.0, hook.rope.length if is_instance_valid(hook.rope) else 0.0])
	# Left to it: the rope takes him off his feet and out over the gap.
	var lowest := [100.0]
	var fastest := [0.0]
	var furthest := [0.0]
	await wait(1.6, func() -> bool:
		lowest[0] = minf(lowest[0], boy.global_position.y)
		fastest[0] = maxf(fastest[0], boy.velocity.length())
		furthest[0] = maxf(furthest[0], boy.global_position.x)
		return false)
	check("it lifts him off the ground and swings him out", boy.state == Player.State.ROPE and lowest[0] > -0.05 and furthest[0] > 8.5, "feet never below %.2f, swung to x = %.1f, fastest %.1f m/s" % [lowest[0], furthest[0], fastest[0]])

	# --- Pumped, and off at the front of the swing: over the gap.
	var peaks: Array = []
	var widest := 0.0
	var side := 0.0
	var before := angle()
	for i in 900:
		var a := angle()
		touch.move = Vector2(signf(boy.velocity.x) if absf(boy.velocity.x) > 0.2 else 1.0, 0)
		if signf(a) != side and absf(a) > 0.5:
			if side != 0.0:
				peaks.append(snappedf(widest, 0.1))
			side = signf(a)
			widest = 0.0
		widest = maxf(widest, absf(a))
		if peaks.size() >= 4 and boy.velocity.x > 0.0 and a > 22.0 and before <= 22.0:
			break
		before = a
		await wait(1.0 / 60.0)
	var let_go := boy.global_position
	var swing := boy.velocity
	touch.move = Vector2(1, 0)
	touch.jump_held = true
	boy._queue_jump()
	await wait(0.05)
	var off := boy.velocity
	var down := await wait(4.0, func() -> bool: return boy.is_on_floor())
	touch.jump_held = false
	touch.move = Vector2.ZERO
	check("pumping it builds the swing", peaks.size() >= 4 and peaks[-1] > 30.0, "widest each half swing: %s" % str(peaks))
	check("let go at the front, he lands across the gap", down and boy.global_position.x > 11.0 and absf(boy.global_position.y) < 0.3, "let go at x = %.1f going %s, left at %s, landed at %s" % [let_go.x, swing, off, boy.global_position])
	var home := await wait(3.0, func() -> bool: return hook.state == GrappleHook.State.HOME and boy.reel_progress >= 1.0)
	check("the hook comes away and is wound back to his hand", home and boy.carried == hook and not boy.hook_out and not is_instance_valid(hook.rope), "hook state %d, %d ropes left" % [hook.state, get_nodes_in_group(&"ropes").size()])

	# --- Thrown with nothing in reach.
	place(Vector3(24, 0.05, 0))
	await wait(0.6)
	check("marks nothing when nothing is in reach", hook.target == null and not hook._mark.visible)
	# (he has come down hard off that swing, and is a moment getting up)
	await wait(3.0, func() -> bool: return boy.landing_progress >= 1.0)
	boy._act()
	var states := {}
	await wait(0.2)
	var back := await wait(3.0, func() -> bool:
		states[hook.state] = true
		return hook.state == GrappleHook.State.HOME and boy.cast_progress >= 1.0 and boy.reel_progress >= 1.0)
	check("a throw at nothing falls short and is wound in", back and states.has(GrappleHook.State.SPENT) and states.has(GrappleHook.State.RETURNING) and boy.state == Player.State.FREE and boy.carried == hook, "hook states seen %s" % str(states.keys()))
	boy._act()
	var again := await wait(1.5, func() -> bool: return hook.state == GrappleHook.State.FLYING)
	check("and he can throw it again", again)
	await wait(2.0)

	# --- Put down; and an ordinary rope.
	touch.duck_held = true
	await wait(0.4)
	boy._act()
	await wait(0.2)
	touch.duck_held = false
	await wait(0.6)
	check("duck and act puts it down", boy.carried == null and hook.holder == null and hook.state == GrappleHook.State.HOME)
	var line := Rope.new()
	line.length = 5.5
	line.position = Vector3(34, 6.6, 0)
	stage.add_child(line)
	place(Vector3(31, 0.05, 0.25))
	await wait(0.4)
	touch.move = Vector2(1, 0)
	var jumped := [false]
	var caught := await wait(3.0, func() -> bool:
		if not jumped[0] and boy.global_position.x > 32.7:
			jumped[0] = true
			touch.jump_held = true
			boy._queue_jump()
		return boy.state == Player.State.ROPE)
	touch.jump_held = false
	check("an ordinary rope is caught at a running jump", caught and boy._rope == line, "state %d at %s" % [boy.state, boy.global_position])
	peaks.clear()
	widest = 0.0
	side = 0.0
	for i in 480:
		var a := angle()
		touch.move = Vector2(signf(boy.velocity.x) if absf(boy.velocity.x) > 0.2 else 1.0, 0)
		if signf(a) != side and absf(a) > 0.5:
			if side != 0.0:
				peaks.append(snappedf(widest, 0.1))
			side = signf(a)
			widest = 0.0
		widest = maxf(widest, absf(a))
		await wait(1.0 / 60.0)
	touch.move = Vector2.ZERO
	check("and pumped in time it swings wider", peaks.size() >= 4 and peaks[-1] > peaks[0] + 8.0 and peaks[-1] > 35.0, "widest each half swing: %s" % str(peaks))
	var hands := boy._rope_at
	touch.act_held = true
	await wait(1.0)
	touch.act_held = false
	check("act held climbs it", boy.state == Player.State.ROPE and boy._rope_at < hands - 1.0, "hands from %.2f to %.2f m down" % [hands, boy._rope_at])
	hands = boy._rope_at
	touch.duck_held = true
	await wait(0.4)
	touch.duck_held = false
	check("duck lets him down it", boy.state == Player.State.ROPE and boy._rope_at > hands + 0.8, "hands from %.2f to %.2f m down" % [hands, boy._rope_at])
	boy._queue_jump()
	var landed := await wait(4.0, func() -> bool: return boy.is_on_floor())
	check("and jump leaps off it", landed and boy.state == Player.State.FREE and line.load_at < 0.0, "at %s" % boy.global_position)

	print("PASSED" if failed == 0 else "FAILED (%d)" % failed)
	quit(1 if failed > 0 else 0)
