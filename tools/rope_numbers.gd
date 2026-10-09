extends SceneTree
## Not part of the game. Puts the boy on a rope with nothing drawn and prints numbers for how it
## swings: how reliably he catches it, how the swing grows when he pumps in time with it and dies
## when he stops, what he carries off it when he lets go at each point of the swing, and what
## climbing does to it.
## godot --headless --path . --fixed-fps 60 --script tools/rope_numbers.gd

var stage: Node3D
var boy: Player
var touch: TouchControls
var line: Rope
const TOP := Vector3(0, 6.6, 0)


func _initialize() -> void:
	stage = Node3D.new()
	root.add_child(stage)
	box(Vector3(0, -1, 0), Vector3(120, 2, 120))
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


func step(count := 1) -> void:
	for i in count:
		await physics_frame
		await process_frame


func place(at: Vector3, yaw: float) -> void:
	touch.move = Vector2.ZERO
	touch.duck_held = false
	touch.jump_held = false
	boy.state = Player.State.FREE
	boy.global_position = at
	boy._spawn = Transform3D(Basis.IDENTITY, at)
	boy.respawn()
	boy.facing_yaw = yaw
	boy._reset_visuals()


## A fresh rope, hanging still.
func hang(length := 5.5) -> void:
	if line:
		# (he is not left holding the old one)
		boy.respawn()
		line.free()
	line = Rope.new()
	line.length = length
	line.position = TOP
	stage.add_child(line)


## How far round from straight down he is, degrees, positive towards +x.
func angle() -> float:
	var hold := line.point_at(boy._rope_at) - TOP
	return rad_to_deg(atan2(hold.x, -hold.y))


## Puts him on the rope `down` it, at rest.
func mount(down := 4.2, length := 5.5) -> void:
	hang(length)
	await step(30)
	place(Vector3(-0.25, TOP.y - down - 1.1, 0), PI * 0.5)
	boy.velocity = Vector3(1.0, 0, 0)
	await step(8)
	if boy.state != Player.State.ROPE:
		print("  (not on the rope: state ", boy.state, " at ", boy.global_position, ")")
	# (and lets it come to rest)
	for i in 600:
		await step()
		if boy.state != Player.State.ROPE:
			break
		if absf(angle()) < 1.0 and boy.velocity.length() < 0.15:
			break


## Swings for `seconds`, the stick held as `how` says, and returns the widest it
## got each half swing, degrees.
func swing(seconds: float, how: String) -> Array:
	var peaks: Array = []
	var widest := 0.0
	var side := 0.0
	for i in int(seconds * 60.0):
		var a := angle()
		var way := signf(boy.velocity.x) if absf(boy.velocity.x) > 0.15 else 1.0
		match how:
			"time":
				touch.move = Vector2(way, 0)
			"hold":
				touch.move = Vector2(1, 0)
			"against":
				touch.move = Vector2(-way, 0)
			_:
				touch.move = Vector2.ZERO
		await step()
		if boy.state != Player.State.ROPE:
			break
		if signf(a) != side and absf(a) > 0.5:
			if side != 0.0:
				peaks.append(snappedf(widest, 0.1))
			side = signf(a)
			widest = 0.0
		widest = maxf(widest, absf(a))
	touch.move = Vector2.ZERO
	return peaks


func run() -> void:
	for action: StringName in InputMap.get_actions():
		if not String(action).begins_with("ui_"):
			InputMap.action_erase_events(action)
	touch = TouchControls.new()
	touch.visible = false
	stage.add_child(touch)
	touch.set_process_input(false)
	boy = load("res://player.tscn").instantiate()
	boy.position = Vector3(-6, 0.05, 3)
	stage.add_child(boy)
	boy.set_process_unhandled_input(false)
	boy.sleep_after = 0.0
	await step(10)

	# --- Catching it: run at it and jump, passing it at different distances to the side.
	print("CATCH run and jump at a rope whose end is 1.1 m off the ground (z = how far to the side he passes)")
	for speed: float in [0.0, 1.0]:
		var row := ""
		for z: float in [0.0, 0.2, 0.35, 0.5, 0.7, 0.9]:
			hang()
			await step(20)
			place(Vector3(-3.0 if speed > 0.0 else -0.5, 0.05, z), PI * 0.5)
			await step(5)
			var took := -1.0
			var jumped := -1
			for i in 150:
				touch.move = Vector2(1, 0) * speed
				if jumped < 0 and boy.global_position.x > (-1.3 if speed > 0.0 else -10.0):
					jumped = i
					touch.jump_held = true
					boy._queue_jump()
				await step()
				if boy.state == Player.State.ROPE:
					took = (i - jumped) / 60.0
					break
			row += "  z=%.2f %s" % [z, ("caught %.2fs" % took) if took >= 0.0 else "MISSED"]
		print("  ", "at a run:  " if speed > 0.0 else "standing: ", row)

	# --- The first swing a running jump gives him.
	hang()
	await step(20)
	place(Vector3(-3.0, 0.05, 0), PI * 0.5)
	await step(5)
	var leapt := false
	for i in 150:
		touch.move = Vector2(1, 0)
		if not leapt and boy.global_position.x > -1.3:
			leapt = true
			touch.jump_held = true
			boy._queue_jump()
		await step()
		if boy.state == Player.State.ROPE:
			break
	touch.jump_held = false
	if boy.state == Player.State.ROPE:
		print("RUN-IN caught at ", snappedf(boy._rope_at, 0.01), " m down; swings with no more help: ", await swing(6.0, "none"))

	# --- Pumping.
	for how: String in ["time", "hold", "against"]:
		await mount()
		var grown := await swing(12.0, how)
		print("PUMP ", how, " from rest, 12 s: ", grown)
		if how == "time":
			print("  then left alone, 12 s: ", await swing(12.0, "none"))

	# --- Letting go at each point of the swing.
	print("RELEASE pumped in time for 8 s, then jump at a chosen point (stick held the way he is going)")
	for point: String in ["bottom going forward", "halfway up forward", "top forward", "bottom going back", "top back", "at rest"]:
		await mount()
		if point != "at rest":
			await swing(8.0, "time")
		var before := angle()
		var widest := 0.0
		for i in 400:
			var a := angle()
			var v := boy.velocity.x
			widest = maxf(widest, absf(a))
			touch.move = Vector2(signf(v) if absf(v) > 0.15 else 1.0, 0)
			var now := false
			match point:
				"bottom going forward":
					now = before < 0.0 and a >= 0.0
				"halfway up forward":
					now = v > 0.0 and a > 22.0 and a < 32.0
				"top forward":
					now = a > 3.0 and v <= 0.0 and i > 60
				"bottom going back":
					now = before > 0.0 and a <= 0.0
				"top back":
					now = a < -3.0 and v >= 0.0 and i > 60
				_:
					now = true
			before = a
			if now and (i > 60 or point == "at rest"):
				break
			await step()
		if point == "at rest":
			touch.move = Vector2(1, 0)
			await step(20)
		var from := boy.global_position
		var was := boy.velocity
		var at := angle()
		# (and leaps the way that part of the swing is going)
		touch.move = Vector2(-1 if point.ends_with("back") else 1, 0)
		touch.jump_held = true
		boy._queue_jump()
		await step()
		var off := boy.velocity
		var top := from.y
		for i in 300:
			await step()
			top = maxf(top, boy.global_position.y)
			if boy.is_on_floor():
				break
		touch.jump_held = false
		var went := boy.global_position - from
		print("  %-22s at %5.1f deg, rope speed (%.1f, %.1f) -> leaves at (%.1f, %.1f) = %.1f m/s; lands %.1f m on, rose %.1f m" % [point, at, was.x, was.y, off.x, off.y, Vector2(off.x, off.y).length(), went.x, top - from.y])
		touch.move = Vector2.ZERO

	# --- Climbing while it swings.
	await mount()
	await swing(8.0, "time")
	var times: Array = []
	var last := 0
	var before2 := angle()
	for i in 900:
		touch.act_held = i > 200 and i < 300
		await step()
		if boy.state != Player.State.ROPE:
			break
		var a := angle()
		if before2 < 0.0 and a >= 0.0:
			if last > 0:
				times.append(snappedf((i - last) / 60.0, 0.01))
			last = i
		before2 = a
		if i == 199 or i == 300:
			print("CLIMB ", "before" if i == 199 else "after", " going up 1.7 s: hands ", snappedf(boy._rope_at, 0.01), " m down")
	print("  time of each whole swing: ", times)

	# --- Getting off at the top.
	await mount(1.0)
	touch.act_held = true
	await step(120)
	touch.act_held = false
	print("TOP climbed as high as he can: hands ", snappedf(boy._rope_at, 0.01), " m down, feet at y ", snappedf(boy.global_position.y, 0.01), " (the rope hangs from y ", TOP.y, ")")
	quit()
