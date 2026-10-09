extends SceneTree
## Not part of the game. A test stage for the camel: drives one through each thing it does and saves
## contact sheets of what the rig makes of it, as hound_sheets.gd does for the hounds.
## godot --path . --fixed-fps 60 --resolution 960x960 --script tools/camel_sheets.gd -- <outdir> [scenario ...]
## Among the names: `lo` for the demade model, `bare` for no tack at all (otherwise it is saddled and haltered).
## The scenarios whose names begin `m_` are strips of consecutive frames, for watching how a thing moves.
## After each of those it prints which bones shook or jumped (SHAKE), as pose_sheets.gd does for the boy;
## and under each gait, when each foot came down in the stride and how far any planted foot slid.

const CELL := 480
## A bone that turns back on itself by more than this (degrees) from one frame to the next has shaken;
## one whose turn changes by more than JUMP in a frame has jumped.
const SHAKE := 1.5
const JUMP := 14.0
var out := ""
var only: Array = []
var stage: Node3D
var cam: Camera3D
var cells: Array[Image] = []
var camels: Array[Camel] = []
var player: Player
var bare := false
## What the camera watches, from where: (yaw round it, pitch, distance), and how high up it.
var watch: Node3D
var view := Vector3(PI * 0.5, 0.05, 7.5)
var look_h := 1.15
var pin := Vector3.INF
var track: Array = []


func _initialize() -> void:
	# It needs a real window to draw in, but not one that gets in the way: this one is kept
	# off the screen and takes no focus.
	DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_NO_FOCUS, true)
	DisplayServer.window_set_position(Vector2i(-6000, -6000))
	var args := OS.get_cmdline_user_args()
	out = args[0]
	only = args.slice(1)
	if "lo" in only:
		only.erase("lo")
		Settings.low_poly = true
	if "bare" in only:
		only.erase("bare")
		bare = true
	stage = Node3D.new()
	root.add_child(stage)
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.5, 0.56, 0.62)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.62, 0.66, 0.74)
	env.ambient_light_energy = 0.7
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	var world := WorldEnvironment.new()
	world.environment = env
	stage.add_child(world)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-48.0, -35.0, 0.0)
	sun.light_color = Color(1.0, 0.96, 0.9)
	sun.light_energy = 1.2
	sun.shadow_enabled = true
	stage.add_child(sun)
	box(Vector3(0, -1, 0), Vector3(600, 2, 80), Color(0.42, 0.44, 0.46))
	cam = Camera3D.new()
	cam.fov = 30.0
	stage.add_child(cam)
	cam.make_current()
	process_frame.connect(record)
	run.call_deferred()


## Nothing here is to be steered: a gamepad reaches even a window that has no focus.
func deafen() -> void:
	for action: StringName in InputMap.get_actions():
		if not String(action).begins_with("ui_"):
			InputMap.action_erase_events(action)
			Input.action_release(action)


func box(at: Vector3, size: Vector3, color: Color) -> void:
	var body := StaticBody3D.new()
	var shape := BoxShape3D.new()
	shape.size = size
	var collider := CollisionShape3D.new()
	collider.shape = shape
	body.add_child(collider)
	var mesh := BoxMesh.new()
	mesh.size = size
	var visual := MeshInstance3D.new()
	visual.mesh = mesh
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = 1.0
	visual.material_override = material
	body.add_child(visual)
	body.position = at
	stage.add_child(body)


## A fresh camel, standing where it is put and doing nothing of its own accord.
func camel(at: Vector3, yaw := PI * 0.5, calm := true) -> Camel:
	var made := Camel.new()
	made.position = at
	made.rotation.y = yaw
	made.saddled = not bare
	made.haltered = not bare
	made.voice = false
	if calm:
		made.rest_after = 100000.0
		made.roam = 0.0
	stage.add_child(made)
	if calm:
		made._timer = 100000.0
	camels.append(made)
	watch = made
	track.clear()
	return made


func clear() -> void:
	for old in camels:
		old.queue_free()
	camels.clear()
	if player:
		player.queue_free()
		player = null
	pin = Vector3.INF
	look_h = 1.15
	track.clear()


## The boy himself, for it to look at and to be led by.
func boy(at: Vector3) -> void:
	var touch := TouchControls.new()
	touch.visible = false
	stage.add_child(touch)
	touch.set_process_input(false)
	player = load("res://player.tscn").instantiate()
	player.position = at
	stage.add_child(player)
	player.set_process_unhandled_input(false)
	# (he stays exactly where he is put)
	player.set_physics_process(false)
	deafen()


func aim() -> void:
	var at := pin
	if at == Vector3.INF:
		if not is_instance_valid(watch):
			return
		at = (watch as Camel).visual_position + Vector3.UP * look_h
	var away := Vector3(sin(view.x) * cos(view.y), sin(view.y), cos(view.x) * cos(view.y))
	cam.global_position = at + away * view.z
	cam.look_at(at)


func frames(count: int) -> void:
	for i in count:
		aim()
		await physics_frame
		await process_frame


func snap() -> void:
	aim()
	await RenderingServer.frame_post_draw
	var image := root.get_texture().get_image()
	var side: int = mini(image.get_width(), image.get_height())
	image = image.get_region(Rect2i((image.get_width() - side) / 2, (image.get_height() - side) / 2, side, side))
	image.resize(CELL, CELL, Image.INTERPOLATE_LANCZOS)
	cells.append(image)


func sheet(name: String, columns := 4) -> void:
	var rows := ceili(cells.size() / float(columns))
	var page := Image.create(CELL * columns, CELL * rows, false, cells[0].get_format())
	for i in cells.size():
		page.blit_rect(cells[i], Rect2i(0, 0, CELL, CELL), Vector2i((i % columns) * CELL, (i / columns) * CELL))
	var suffix := "_lo" if Settings.low_poly else ""
	page.save_png(out.path_join(name + suffix + ".png"))
	cells.clear()
	print("SHEET ", name + suffix)


## Notes where every bone of the camel being watched is this frame.
func record() -> void:
	if camels.is_empty() or not is_instance_valid(camels[0]) or camels[0]._rig == null:
		return
	var skeleton: Skeleton3D = camels[0]._rig._skeleton
	var row: Array[Transform3D] = []
	for bone in skeleton.get_bone_count():
		row.append(skeleton.get_bone_global_pose(bone))
	track.append(row)


## Prints which bones shook or jumped since the track was last cleared, and how badly, and on which frame.
## The springs (ears, tail) are left out: they are meant to quiver.
func shake(name: String) -> void:
	var skeleton: Skeleton3D = camels[0]._rig._skeleton
	var found: Array = []
	var turns: Array = []
	for i in range(1, track.size()):
		var now: Array = []
		for bone in track[i].size():
			var q := Quaternion(track[i][bone].basis.orthonormalized()) * Quaternion(track[i - 1][bone].basis.orthonormalized()).inverse()
			var angle := q.get_angle()
			if angle > PI:
				angle -= TAU
			now.append(q.get_axis() * rad_to_deg(angle))
		if not turns.is_empty():
			if found.is_empty():
				for bone in now.size():
					found.append({"bone": skeleton.get_bone_name(bone), "shakes": 0, "worst": 0.0, "at": 0, "jump": 0.0, "jump_at": 0})
			for bone in now.size():
				var a: Vector3 = turns[bone]
				var b: Vector3 = now[bone]
				var back := -a.dot(b) / maxf(a.length(), 0.0001)
				if a.dot(b) < 0.0 and minf(back, a.length()) > SHAKE:
					found[bone].shakes += 1
					if minf(back, a.length()) > found[bone].worst:
						found[bone].worst = minf(back, a.length())
						found[bone].at = i
				if (b - a).length() > found[bone].jump:
					found[bone].jump = (b - a).length()
					found[bone].jump_at = i
		turns = now
	var bad := found.filter(func(entry: Dictionary) -> bool:
		return (entry.shakes >= 2 or entry.jump > JUMP) and not (String(entry.bone).begins_with("ear") or String(entry.bone).begins_with("tail")))
	bad.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return a.shakes * 100 + a.jump > b.shakes * 100 + b.jump)
	print("SHAKE ", name, " frames=", track.size(), " bones=", bad.size())
	for entry: Dictionary in bad.slice(0, 14):
		print("  %-12s shakes=%d worst=%.1f at %d | jump=%.1f at %d" % [entry.bone, entry.shakes, entry.worst, entry.at, entry.jump, entry.jump_at])
	track.clear()


func wants(name: String) -> bool:
	return only.is_empty() or name in only


func run() -> void:
	deafen()
	await frames(5)
	for name: String in ["turnaround", "tack", "walk", "pace", "gallop", "couch", "browse", "look", "led", "tethered", "shy", "fur",
			"m_walk", "m_pace", "m_gallop", "m_kneel", "m_rise", "m_chew", "m_idle", "m_turn"]:
		if wants(name):
			await call(name)
			clear()
			await frames(2)
	quit()


func turnaround() -> void:
	camel(Vector3(0, 0.05, 0), 0.0)
	await frames(60)
	for yaw: float in [0.0, 0.7, PI * 0.5, PI - 0.6, PI, -0.7, -PI * 0.5, 0.4]:
		view = Vector3(yaw, 0.35 if yaw == 0.4 else 0.06, 8.0)
		await frames(2)
		await snap()
	sheet("turnaround")
	# Close on the head, and on a foot
	var head: Vector3 = camels[0]._rig._head.global_position
	for yaw: float in [0.0, 0.8, PI * 0.5, -PI * 0.5]:
		pin = head + Vector3(0, -0.02, 0.2)
		view = Vector3(yaw, 0.08, 2.2)
		await frames(2)
		await snap()
	sheet("head")
	for shot: Vector3 in [Vector3(PI * 0.5, 0.1, 2.4), Vector3(0.6, 0.3, 2.0), Vector3(0.0, 0.05, 2.4), Vector3(-0.7, 0.6, 2.4)]:
		pin = (camels[0]._rig._legs[0][3] as Node3D).global_position + Vector3(0.0, 0.1, 0.0)
		view = shot
		await frames(2)
		await snap()
	sheet("foot")


## What it can wear: nothing; a halter; saddled; packed; and everything.
func tack() -> void:
	var beast := camel(Vector3(0, 0.05, 0))
	await frames(40)
	view = Vector3(0.5, 0.12, 8.0)
	for wear: Array in [[false, false, false], [false, true, false], [true, true, false], [false, true, true], [true, true, true]]:
		beast.saddled = wear[0]
		beast.haltered = wear[1]
		beast.packed = wear[2]
		beast.dress()
		await frames(2)
		await snap()
	view = Vector3(-PI * 0.5 - 0.6, 0.3, 8.0)
	await frames(2)
	await snap()
	sheet("tack", 3)


## A side view of one stride, `count` pictures `every` frames apart; then from in front and behind.
func strip(name: String, speed: float, every: int, count: int, distance := 8.0, also_round := true) -> void:
	var beast := camel(Vector3(-250, 0.05, 0))
	beast.bidden = Vector3(290, 0, 0)
	beast.bidden_speed = speed
	view = Vector3(0.0, 0.03, distance)
	await frames(360)
	track.clear()
	var rig: CamelRig = beast._rig
	var line := ""
	var landed: Array[float] = [-1.0, -1.0, -1.0, -1.0]
	var was_up: Array[bool] = [false, false, false, false]
	var held: Array[Vector3] = [Vector3.ZERO, Vector3.ZERO, Vector3.ZERO, Vector3.ZERO]
	var slid := 0.0
	var low := 9.0
	var high := 0.0
	var roll := 0.0
	var sway := 0.0
	for i in count * every:
		await frames(1)
		var lowest := 9.0
		for leg in 4:
			var at: Vector3 = (rig._legs[leg][3] as Node3D).global_position
			var height := at.y - rig._paw_height - beast.visual_position.y
			lowest = minf(lowest, height)
			var up := height > 0.004
			if not up and was_up[leg]:
				landed[leg] = rig._phase
				held[leg] = at
			elif not up and landed[leg] >= 0.0:
				# (how far it has crept from where it came down)
				slid = maxf(slid, Vector2(at.x - held[leg].x, at.z - held[leg].z).length())
			was_up[leg] = up
		low = minf(low, lowest)
		high = maxf(high, lowest)
		roll = maxf(roll, absf(rig._body.rotation.z))
		sway = maxf(sway, absf(rig._body.position.x))
		if i % every == every - 1:
			await snap()
			line += " %.2f" % rig._phase
	print("GAIT ", name, " speed=", snappedf(Vector2(beast.velocity.x, beast.velocity.z).length(), 0.01), " stride=", snappedf(beast.velocity.length() / maxf(rig._pace, 0.01) * CamelRig._keyed(CamelRig.STRIDES, rig._pace), 0.01),
			" lowest foot from ", snappedf(low, 0.001), " to ", snappedf(high, 0.001), " phases:", line)
	print("  feet came down at (fore left, fore right, hind left, hind right): ", landed.map(func(at: float) -> float: return snappedf(at, 0.01)),
			"  fore after hind of its side: left ", snappedf(fposmod(landed[0] - landed[2], 1.0), 0.01), " right ", snappedf(fposmod(landed[1] - landed[3], 1.0), 0.01),
			"  left after right: ", snappedf(fposmod(landed[2] - landed[3], 1.0), 0.01))
	print("  a planted foot slid at most ", snappedf(slid, 0.001), " m; rolled ", snappedf(rad_to_deg(roll), 0.1), " degrees, swayed ", snappedf(sway, 0.001), " m")
	sheet(name, 4 if count <= 8 else 6)
	shake(name)
	if also_round:
		view = Vector3(PI * 0.5 - 0.35, 0.12, distance)
		for i in 4:
			await frames(every * 2)
			await snap()
		view = Vector3(-PI * 0.5 + 0.02, 0.1, distance)
		for i in 4:
			await frames(every * 2)
			await snap()
		sheet(name + "_round")


func walk() -> void:
	await strip("walk", 1.2, 9, 8)


func pace() -> void:
	await strip("pace", 3.2, 5, 8)


func gallop() -> void:
	await strip("gallop", 6.2, 3, 12, 9.0)


## Two strides of each, every third (or second) frame.
func m_walk() -> void:
	await strip("m_walk", 1.2, 5, 24, 7.5, false)


func m_pace() -> void:
	await strip("m_pace", 3.2, 3, 24, 7.5, false)


func m_gallop() -> void:
	await strip("m_gallop", 6.2, 1, 24, 8.5, false)


## Couched, from all round.
func couch() -> void:
	var beast := camel(Vector3(0, 0.05, 0), PI * 0.5, false)
	beast.couched = true
	beast.posture = Camel.Posture.COUCH
	beast.state = Camel.State.REST
	beast.rest_for = 100000.0
	beast._rig._couch = 1.0
	look_h = 0.8
	await frames(90)
	for yaw: float in [0.0, PI * 0.5 - 0.6, PI * 0.5, PI, -PI * 0.5 + 0.5, 0.5]:
		view = Vector3(yaw, 0.5 if yaw == 0.5 else 0.1, 7.0)
		await frames(2)
		await snap()
	sheet("couch", 3)


## Getting down, every sixth frame, from the side; and then from the quarter.
func m_kneel() -> void:
	var beast := camel(Vector3(0, 0.05, 0))
	look_h = 1.0
	view = Vector3(0.0, 0.05, 8.0)
	await frames(60)
	track.clear()
	beast.posture = Camel.Posture.COUCH
	beast.state = Camel.State.REST
	beast.rest_for = 100000.0
	var line := ""
	for i in 30:
		await frames(10)
		await snap()
		line += " %.2f" % beast._rig._couch
	print("KNEEL how far down, every 10 frames:", line)
	sheet("m_kneel", 6)
	shake("m_kneel")


## Getting up again, the same way.
func m_rise() -> void:
	var beast := camel(Vector3(0, 0.05, 0), PI * 0.5, false)
	beast.posture = Camel.Posture.COUCH
	beast.state = Camel.State.REST
	beast.rest_for = 100000.0
	beast._rig._couch = 1.0
	look_h = 1.0
	view = Vector3(0.0, 0.05, 8.0)
	await frames(60)
	track.clear()
	beast.rest_after = 100000.0
	beast._stand()
	beast._timer = 100000.0
	var line := ""
	for i in 24:
		await frames(10)
		await snap()
		line += " %.2f" % beast._rig._couch
	print("RISE how far down, every 10 frames:", line)
	sheet("m_rise", 6)
	shake("m_rise")
	# And the same from the front quarter, every 20 frames, down and up
	beast.posture = Camel.Posture.COUCH
	beast.state = Camel.State.REST
	view = Vector3(PI * 0.5 - 0.7, 0.15, 8.0)
	for i in 12:
		await frames(24)
		await snap()
	beast._stand()
	beast._timer = 100000.0
	for i in 12:
		await frames(20)
		await snap()
	sheet("kneel_rise_quarter", 6)


## Chewing the cud, close on the head from in front: every fourth frame, about a chew and a half.
func m_chew() -> void:
	var beast := camel(Vector3(0, 0.05, 0))
	await frames(60)
	var rig: CamelRig = beast._rig
	track.clear()
	var line := ""
	for i in 18:
		for step in 4:
			beast._chew_left = 10.0
			pin = rig._head.global_position + Vector3(0.22, -0.04, 0.0)
			view = Vector3(PI * 0.5 - 0.25, -0.05, 1.7)
			await frames(1)
		await snap()
		line += " %.2f/%.2f" % [rig._jaw.rotation.y, rig._jaw.rotation.x]
	print("CHEW jaw aside/open (radians), every 4 frames:", line)
	sheet("m_chew", 6)
	shake("m_chew")


## Standing about for half a minute: its weight shifting, a hind leg rested. Every 1.5 s from behind and the side.
func m_idle() -> void:
	var beast := camel(Vector3(0, 0.05, 0))
	beast._rig._cock_timer = 1.0
	view = Vector3(-PI * 0.5 + 0.5, 0.12, 8.0)
	await frames(30)
	track.clear()
	var line := ""
	for i in 18:
		await frames(90)
		await snap()
		line += " %.2f" % beast._rig._cock
	print("IDLE how far a hind leg is rested, every 1.5 s:", line)
	sheet("m_idle", 6)
	shake("m_idle")


## Turning on the spot: it steps round.
func m_turn() -> void:
	var beast := camel(Vector3(0, 0.05, 0))
	view = Vector3(0.4, 0.5, 9.0)
	pin = Vector3(0, 1.0, 0)
	await frames(30)
	track.clear()
	beast.bidden = Vector3(-30, 0, 0.5)
	for i in 18:
		await frames(8)
		await snap()
	sheet("m_turn", 6)
	shake("m_turn")


## Its head down to feed: at its feet, and at something higher.
func browse() -> void:
	var beast := camel(Vector3(0, 0.05, 0))
	view = Vector3(0.0, 0.05, 8.0)
	await frames(40)
	for height: float in [0.1, 0.9]:
		beast.state = Camel.State.BROWSE
		beast.browsing = true
		beast._bites = 5
		beast._timer = 100.0
		beast.browse_height = height
		for i in 4:
			await frames(30)
			await snap()
		print("BROWSE at ", height, ": its mouth is ", snappedf(beast._rig.halter_point().y - beast.visual_position.y, 0.01), " m off the ground")
		beast.browsing = false
		beast._timer = 100.0
		await frames(100)
	sheet("browse")


## Something carried round it: its head should follow.
func look() -> void:
	var beast := camel(Vector3(0, 0.05, 0), 0.0)
	var thing := MeshInstance3D.new()
	var ball := SphereMesh.new()
	ball.radius = 0.15
	ball.height = 0.3
	thing.mesh = ball
	stage.add_child(thing)
	view = Vector3(0.0, 0.35, 9.5)
	pin = Vector3(0, 1.2, 0)
	for i in 12:
		var angle := -1.6 + i * 0.4
		for step in 60:
			var now := angle - 0.4 + 0.4 * (step + 1) / 60.0
			thing.position = Vector3(sin(now) * 3.5, 0.4 + 2.0 * maxf(sin(now * 1.3), 0.0), cos(now) * 3.5)
			beast.gaze_at = thing.position
			await frames(1)
			beast.gaze_at = thing.position
		await snap()
	print("LOOK ", beast._rig._look)
	sheet("look")
	thing.queue_free()


## Led by the boy, and a second one in a string behind it. (He is moved by hand here, so his figure is not
## drawn where he is: the rope shows where that is.)
func led() -> void:
	boy(Vector3(6, 0.05, 0))
	var first := camel(Vector3(0, 0.05, 0), PI * 0.5, false)
	var second := camel(Vector3(-4, 0.05, 0.6), PI * 0.5, false)
	second.packed = true
	second.saddled = false
	second.dress()
	first.follow(player)
	second.follow(first)
	watch = first
	view = Vector3(0.25, 0.2, 14.0)
	await frames(30)
	for i in 12:
		for step in 30:
			# (he is walked along by hand: he is not being played)
			player.global_position.x += 1.1 / 60.0
			await frames(1)
		await snap()
	print("LED boy at ", player.global_position, " first ", first.global_position, " second ", second.global_position)
	sheet("led")


## On a tether: left to wander for a while, with where it got to.
func tethered() -> void:
	var beast := Camel.new()
	beast.position = Vector3(0, 0.05, 0)
	beast.tether = Vector3(0.5, 0, 0.5)
	beast.tether_length = 3.5
	beast.roam = 12.0
	beast.rest_after = 100000.0
	beast.voice = false
	stage.add_child(beast)
	camels.append(beast)
	watch = beast
	pin = Vector3(0.5, 0.9, 0.5)
	view = Vector3(0.4, 0.45, 15.0)
	var furthest := 0.0
	for i in 12:
		for step in 150:
			await frames(1)
			beast._timer = minf(beast._timer, 1.0)
			furthest = maxf(furthest, Vector2(beast.global_position.x - 0.5, beast.global_position.z - 0.5).length())
		await snap()
	print("TETHER furthest from its peg ", snappedf(furthest, 0.01), " m of ", beast.tether_length)
	sheet("tethered")


## A hound coming at it while it is couched: it gets up and makes off.
func shy() -> void:
	var beast := camel(Vector3(0, 0.05, 0), PI * 0.5, false)
	beast.posture = Camel.Posture.COUCH
	beast.state = Camel.State.REST
	beast._rig._couch = 1.0
	var dog := Hound.new()
	dog.position = Vector3(-12, 0.05, 1)
	dog.play_time = 0.0
	dog.settle_after = 100000.0
	stage.add_child(dog)
	dog.bidden = Vector3(-3, 0, 0)
	dog.bidden_speed = 2.4
	view = Vector3(0.2, 0.25, 15.0)
	pin = Vector3(1, 1.0, 0)
	await frames(30)
	for i in 12:
		await frames(36)
		await snap()
	print("SHY camel at ", beast.global_position, " afraid ", snappedf(beast.afraid, 0.01), " hound at ", dog.global_position)
	sheet("shy")
	dog.queue_free()


## The coat close to, with its shells and without.
func fur() -> void:
	for shells: int in [-1, 0]:
		var beast := camel(Vector3(0, 0.05, 0))
		if shells == 0:
			beast._rig.fur_shells = 0
			Fur.apply(beast._rig, &"coat", 0, 0.016)
		await frames(40)
		var head: Vector3 = beast._rig._head.global_position - beast.visual_position
		for shot: Array in [[Vector3(0.0, 1.3, 0.0), Vector3(0.3, 0.1, 7.0)], [Vector3(0.5, 1.4, 0.0), Vector3(0.2, 0.15, 2.4)],
				[head + Vector3(0.1, -0.05, 0.0), Vector3(0.5, 0.1, 2.0)], [Vector3(-0.6, 1.2, 0.0), Vector3(-2.6, 0.3, 2.6)]]:
			pin = beast.visual_position + shot[0]
			view = shot[1]
			await frames(2)
			await snap()
		beast.queue_free()
		camels.erase(beast)
		await frames(2)
	sheet("fur")
