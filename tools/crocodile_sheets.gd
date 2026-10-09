extends SceneTree
## Not part of the game. A test stage for the crocodile: a pond with a sloping bank, and a stretch of level
## ground. Drives one through each thing it does and saves contact sheets of what the rig makes of it, as
## camel_sheets.gd does for the camel.
## godot --path . --fixed-fps 60 --resolution 960x960 --script tools/crocodile_sheets.gd -- <outdir> [scenario ...]
## Among the names: `lo` for the demade model.
## The scenarios whose names begin `m_` are strips of consecutive frames, for watching how a thing moves.
## After each of those it prints which bones shook or jumped (SHAKE), as pose_sheets.gd does for the boy;
## and under each gait, when each foot came down in the stride and how far any planted foot slid.

const CELL := 480
## A bone that turns back on itself by more than this (degrees) from one frame to the next has shaken;
## one whose turn changes by more than JUMP in a frame has jumped.
const SHAKE := 1.5
const JUMP := 14.0
## The level ground is off to one side of the pond, at this z.
const FLAT := 60.0
var out := ""
var only: Array = []
var stage: Node3D
var cam: Camera3D
var cells: Array[Image] = []
var crocs: Array[Crocodile] = []
var player: Player
var pond: Pool
## What the camera watches, from where: (yaw round it, pitch, distance), and how high up it.
var watch: Node3D
var view := Vector3(PI * 0.5, 0.05, 9.0)
var look_h := 0.3
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
	var sand := Color(0.66, 0.58, 0.42)
	# Level ground, for the walks
	box(Vector3(0, -1, FLAT), Vector3(600, 2, 30), sand)
	# The pond: dry land to the west of it, a bank sloping down into it, and its floor a metre and a half down
	box(Vector3(-20, -0.925, 0), Vector3(40, 2.15, 30), sand)
	var fall := atan2(1.65, 6.0)
	box(Vector3(3.0 - sin(fall) * 0.5, -0.675 - cos(fall) * 0.5, 0), Vector3(6.3, 1.0, 30), sand.darkened(0.08), -fall)
	box(Vector3(19, -2.5, 0), Vector3(26.5, 2, 30), sand.darkened(0.2))
	pond = Pool.new()
	pond.size = Vector3(30, 2.0, 30)
	pond.position = Vector3(15, 0, 0)
	stage.add_child(pond)
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


func box(at: Vector3, size: Vector3, color: Color, tilt := 0.0) -> void:
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
	body.rotation.z = tilt
	stage.add_child(body)


## A fresh crocodile. With `thinking` off it does nothing of its own accord: it goes where it is bidden.
func croc(at: Vector3, yaw := PI * 0.5, thinking := false, docile := true) -> Crocodile:
	var made := Crocodile.new()
	made.position = at
	made.rotation.y = yaw
	made.voice = false
	made.thinking = thinking
	made.docile = docile
	stage.add_child(made)
	crocs.append(made)
	watch = made
	track.clear()
	return made


func clear() -> void:
	for old in crocs:
		old.queue_free()
	crocs.clear()
	if player:
		player.queue_free()
		player = null
	pin = Vector3.INF
	look_h = 0.3
	track.clear()


## The boy himself, for it to look at and to go after. He stays exactly where he is put.
func boy(at: Vector3) -> void:
	var touch := TouchControls.new()
	touch.visible = false
	stage.add_child(touch)
	touch.set_process_input(false)
	player = load("res://player.tscn").instantiate()
	player.position = at
	stage.add_child(player)
	player.set_process_unhandled_input(false)
	player.set_physics_process(false)
	deafen()


func aim() -> void:
	var at := pin
	if at == Vector3.INF:
		if not is_instance_valid(watch):
			return
		at = (watch as Crocodile).visual_position + Vector3.UP * look_h
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


## Notes where every bone of the crocodile being watched is this frame.
func record() -> void:
	if crocs.is_empty() or not is_instance_valid(crocs[0]) or crocs[0]._rig == null:
		return
	var skeleton: Skeleton3D = crocs[0]._rig._skeleton
	var row: Array[Transform3D] = []
	for bone in skeleton.get_bone_count():
		row.append(skeleton.get_bone_global_pose(bone))
	track.append(row)


## Prints which bones shook or jumped since the track was last cleared, and how badly, and on which frame.
## Nothing is left out: no part of a crocodile is on a spring. `fast` is for what is meant to be violent
## (a lunge, a head shaken): only a bone that turns right back on itself counts there.
func shake(name: String, fast := false) -> void:
	var skeleton: Skeleton3D = crocs[0]._rig._skeleton
	var found: Array = []
	var turns: Array = []
	var most := 0.0
	for i in range(1, track.size()):
		var now: Array = []
		for bone in track[i].size():
			var q := Quaternion(track[i][bone].basis.orthonormalized()) * Quaternion(track[i - 1][bone].basis.orthonormalized()).inverse()
			var angle := q.get_angle()
			if angle > PI:
				angle -= TAU
			now.append(q.get_axis() * rad_to_deg(angle))
			most = maxf(most, absf(rad_to_deg(angle)))
		if not turns.is_empty():
			if found.is_empty():
				for bone in now.size():
					found.append({"bone": skeleton.get_bone_name(bone), "shakes": 0, "worst": 0.0, "at": 0, "jump": 0.0, "jump_at": 0})
			for bone in now.size():
				var a: Vector3 = turns[bone]
				var b: Vector3 = now[bone]
				var back := -a.dot(b) / maxf(a.length(), 0.0001)
				if a.dot(b) < 0.0 and minf(back, a.length()) > (6.0 if fast else SHAKE):
					found[bone].shakes += 1
					if minf(back, a.length()) > found[bone].worst:
						found[bone].worst = minf(back, a.length())
						found[bone].at = i
				if (b - a).length() > found[bone].jump:
					found[bone].jump = (b - a).length()
					found[bone].jump_at = i
		turns = now
	var bad := found.filter(func(entry: Dictionary) -> bool: return entry.shakes >= 2 or entry.jump > (40.0 if fast else JUMP))
	bad.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return a.shakes * 100 + a.jump > b.shakes * 100 + b.jump)
	print("SHAKE ", name, " frames=", track.size(), " bones=", bad.size(), "  (the most any bone turned in one frame: ", snappedf(most, 0.1), " degrees)")
	for entry: Dictionary in bad.slice(0, 14):
		print("  %-12s shakes=%d worst=%.1f at %d | jump=%.1f at %d" % [entry.bone, entry.shakes, entry.worst, entry.at, entry.jump, entry.jump_at])
	track.clear()


func wants(name: String) -> bool:
	return only.is_empty() or name in only


func run() -> void:
	deafen()
	await frames(5)
	pond.water.sides = false
	for name: String in ["turnaround", "floating", "bask", "look", "hunt",
			"m_crawl", "m_high", "m_run", "m_turn", "m_swim", "m_dive", "m_slide", "m_return", "m_haul", "m_lunge", "m_gape", "m_thrash", "m_roll"]:
		if wants(name):
			await call(name)
			clear()
			await frames(2)
	quit()


## Standing as it does in the high walk, from all round; lying on its belly; and close on its head.
func turnaround() -> void:
	var beast := croc(Vector3(0, 0.05, FLAT), 0.0)
	beast.lift = 1.0
	await frames(90)
	for yaw: float in [0.0, 0.7, PI * 0.5, PI - 0.6, PI, -0.7, -PI * 0.5, 0.4]:
		view = Vector3(yaw, 0.6 if yaw == 0.4 else 0.08, 10.0)
		await frames(2)
		await snap()
	sheet("turnaround")
	beast.lift = 0.0
	await frames(240)
	for shot: Vector3 in [Vector3(PI * 0.5, 0.06, 10.0), Vector3(0.7, 0.25, 10.0), Vector3(0.0, 0.12, 6.0), Vector3(0.3, 1.35, 11.0)]:
		view = shot
		await frames(2)
		await snap()
	sheet("belly")
	for open: float in [0.0, 0.55, 1.0]:
		beast.jaws = open
		beast.jaw_rate = 20.0
		await frames(30)
		for yaw: float in [PI * 0.5, 0.7]:
			pin = beast._rig._head.global_position + Vector3(0, 0.0, 0.25)
			view = Vector3(yaw, 0.12, 2.6)
			await frames(2)
			await snap()
	sheet("head", 2)
	pin = Vector3.INF
	for shot: Array in [[beast._rig._legs[0][3], Vector3(0.9, 0.5, 1.8)], [beast._rig._legs[2][3], Vector3(2.2, 0.5, 2.0)],
			[beast._rig._tails[3], Vector3(PI * 0.5, 0.25, 4.0)], [beast._rig._head, Vector3(0.0, 0.2, 2.2)]]:
		pin = (shot[0] as Node3D).global_position
		view = shot[1]
		await frames(2)
		await snap()
	sheet("details")


## Floating like a log, left to itself: from the side at the level of the water, from above, and from in front.
func floating() -> void:
	var beast := croc(Vector3(12, -0.5, 0), PI * 0.5, true)
	await frames(240)
	look_h = 0.5
	for shot: Vector3 in [Vector3(0.0, 0.03, 9.0), Vector3(0.6, 0.25, 9.0), Vector3(PI * 0.5 - 0.3, 0.12, 6.0), Vector3(0.0, 1.2, 11.0),
			Vector3(0.0, -0.12, 9.0), Vector3(PI + 0.6, 0.3, 9.0)]:
		view = shot
		await frames(2)
		await snap()
	print("FLOAT state ", beast.state, " afloat ", snappedf(beast.afloat, 0.01), " its feet ", snappedf(-beast.visual_position.y, 0.01), " m under; eyes ",
			snappedf(beast._rig.eyes().y, 0.01), " m and the tip of its snout ", snappedf(beast._rig.snout().y, 0.01), " m above the water")
	sheet("float", 3)


## Left to itself on the bank: on its belly, its mouth open.
func bask() -> void:
	var beast := croc(Vector3(-1.2, 0.3, 0), -PI * 0.5, true)
	await frames(600)
	look_h = 0.2
	for shot: Vector3 in [Vector3(0.0, 0.08, 9.0), Vector3(-0.9, 0.25, 9.0), Vector3(PI * 0.5, 0.15, 7.0), Vector3(0.3, 1.2, 11.0),
			Vector3(PI + 0.5, 0.2, 9.0), Vector3(PI * 0.5 + 0.5, 0.1, 5.0)]:
		view = shot
		await frames(2)
		await snap()
	print("BASK state ", beast.state, " jaws ", beast.jaws, " at ", beast.global_position, " slope ", snappedf(beast.slope, 0.01))
	sheet("bask", 3)


## Something carried round it: its head should follow, as far as it can.
func look() -> void:
	var beast := croc(Vector3(0, 0.05, FLAT), 0.0)
	var thing := Node3D.new()
	stage.add_child(thing)
	var ball := MeshInstance3D.new()
	var sphere := SphereMesh.new()
	sphere.radius = 0.15
	sphere.height = 0.3
	ball.mesh = sphere
	thing.add_child(ball)
	beast.gaze = thing
	view = Vector3(0.0, 0.7, 11.0)
	for i in 8:
		var angle := -1.6 + i * 0.45
		for step in 60:
			var now := angle - 0.45 + 0.45 * (step + 1) / 60.0
			thing.position = Vector3(sin(now) * 3.0, 0.2, FLAT + cos(now) * 3.0)
			await frames(1)
		await snap()
	print("LOOK ", beast._rig._look)
	sheet("look")
	thing.queue_free()


## A side view of a gait on level ground, `count` pictures `every` frames apart, and what the feet did.
func strip(name: String, speed: float, lift: float, every: int, count: int) -> void:
	var beast := croc(Vector3(-40, 0.05, FLAT))
	beast.bidden = Vector3(290, 0, FLAT)
	beast.bidden_speed = speed
	beast.lift = lift
	view = Vector3(0.0, 0.1, 6.6)
	await frames(300)
	track.clear()
	var rig: CrocodileRig = beast._rig
	var line := ""
	var landed: Array[float] = [-1.0, -1.0, -1.0, -1.0]
	var was_up: Array[bool] = [false, false, false, false]
	var held: Array[Vector3] = [Vector3.ZERO, Vector3.ZERO, Vector3.ZERO, Vector3.ZERO]
	var slid := 0.0
	var belly := 9.0
	var short := 0.0
	for i in count * every:
		await frames(1)
		for leg in 4:
			var at: Vector3 = (rig._legs[leg][3] as Node3D).global_position
			var up := at.y - rig._paw_height - beast.visual_position.y > 0.004
			if not up and was_up[leg]:
				landed[leg] = rig._phase
				held[leg] = at
			elif not up and landed[leg] >= 0.0:
				# (how far it has crept from where it came down)
				slid = maxf(slid, Vector2(at.x - held[leg].x, at.z - held[leg].z).length())
			was_up[leg] = up
			# (and how far short of where it was meant to be the solver left it)
			var meant: Vector3 = rig._body.global_transform * (rig._legs[leg][3] as Node3D).position
			short = maxf(short, meant.distance_to(at))
		belly = minf(belly, rig._body.global_position.y - beast.visual_position.y)
		if i % every == every - 1:
			await snap()
			line += " %.2f" % rig._phase
	print("GAIT ", name, " speed=", snappedf(Vector2(beast.velocity.x, beast.velocity.z).length(), 0.01), " its middle at least ", snappedf(belly, 0.001), " m up; phases:", line)
	print("  feet came down at (fore left, fore right, hind left, hind right): ", landed.map(func(at: float) -> float: return snappedf(at, 0.01)),
			"  fore after hind of its side: left ", snappedf(fposmod(landed[0] - landed[2], 1.0), 0.01), " right ", snappedf(fposmod(landed[1] - landed[3], 1.0), 0.01))
	print("  a planted foot slid at most ", snappedf(slid, 0.001), " m")
	sheet(name, 4)
	shake(name)
	# And from above, where the bending of it shows, and from in front
	view = Vector3(0.0, 1.4, 8.0)
	for i in 8:
		await frames(every * 3)
		await snap()
	view = Vector3(PI * 0.5 - 0.3, 0.2, 8.0)
	for i in 4:
		await frames(every * 3)
		await snap()
	sheet(name + "_round", 4)


func m_crawl() -> void:
	await strip("m_crawl", 0.34, 0.0, 9, 16)


func m_high() -> void:
	await strip("m_high", 0.6, 1.0, 6, 16)


func m_run() -> void:
	await strip("m_run", 3.0, 0.0, 1, 16)


## Turning on the spot: it steps round, and its tail is left behind.
func m_turn() -> void:
	var beast := croc(Vector3(0, 0.05, FLAT))
	beast.lift = 1.0
	view = Vector3(0.4, 0.9, 11.0)
	pin = Vector3(0, 0.3, FLAT)
	await frames(60)
	track.clear()
	beast.bidden = Vector3(-30, 0, FLAT + 0.5)
	for i in 18:
		await frames(8)
		await snap()
	sheet("m_turn", 6)
	shake("m_turn")


## Swimming at the surface: from above, every fourth frame; then from the side.
func swim(name: String, speed: float, under: bool) -> void:
	var beast := croc(Vector3(3.5, -0.5, -8), 0.0)
	beast.bidden = Vector3(27, 0, 60)
	beast.bidden_speed = speed
	beast.submerged = under
	view = Vector3(0.0, 1.35, 11.0)
	look_h = 0.4
	await frames(150)
	track.clear()
	for i in 18:
		await frames(4)
		await snap()
	shake(name)
	view = Vector3(PI * 0.5 + 0.7, 0.12, 9.0)
	for i in 6:
		await frames(8)
		await snap()
	print("SWIM ", name, " speed ", snappedf(Vector2(beast.velocity.x, beast.velocity.z).length(), 0.01), " afloat ", snappedf(beast.afloat, 0.01),
			" its feet ", snappedf(-beast.visual_position.y, 0.01), " m under the surface")
	sheet(name, 6)


func m_swim() -> void:
	await swim("m_swim", 1.6, false)


func m_dive() -> void:
	await swim("m_dive", 2.4, true)


## Off the bank in a hurry: the belly run, and into the water.
func m_slide() -> void:
	var beast := croc(Vector3(-2.2, 0.3, 0), -PI * 0.5, true)
	await frames(300)
	view = Vector3(0.5, 0.3, 12.0)
	pin = Vector3(1.5, 0.0, 0.0)
	track.clear()
	beast._enter(Crocodile.State.RETURN)
	beast._hurry = true
	var line := ""
	for i in 24:
		await frames(5)
		await snap()
		line += " %.1f/%.2f" % [beast.global_position.x, beast.afloat]
	print("SLIDE where it was and how far afloat, every 5 frames:", line)
	sheet("m_slide", 6)
	shake("m_slide")


## The same in its own time: it turns, crawls to the water and slides in.
func m_return() -> void:
	var beast := croc(Vector3(-2.2, 0.3, 0), -PI * 0.5, true)
	await frames(300)
	view = Vector3(0.5, 0.3, 12.0)
	pin = Vector3(1.5, 0.0, 0.0)
	track.clear()
	beast._enter(Crocodile.State.RETURN)
	var line := ""
	for i in 24:
		await frames(22)
		await snap()
		line += " %.1f/%.2f" % [beast.global_position.x, beast.afloat]
	print("RETURN where it was and how far afloat, every 22 frames:", line)
	sheet("m_return", 6)
	shake("m_return")


## Out of the water and up the bank to bask.
func m_haul() -> void:
	var beast := croc(Vector3(8, -0.5, 0), -PI * 0.5, true)
	await frames(200)
	view = Vector3(0.5, 0.3, 12.0)
	pin = Vector3(1.5, 0.0, 0.0)
	track.clear()
	beast._enter(Crocodile.State.HAUL_OUT)
	var line := ""
	for i in 24:
		await frames(22)
		await snap()
		line += " %.1f/%d" % [beast.global_position.x, beast.state]
	print("HAUL where it was and its state, every 22 frames:", line)
	sheet("m_haul", 6)
	shake("m_haul")


## He stands at the water's edge. From the moment it stops short of him: every other frame.
func m_lunge() -> void:
	boy(Vector3(-0.6, 0.2, 0))
	var beast := croc(Vector3(10, -0.5, 1.0), -PI * 0.5, true, false)
	beast.target = player
	var hit := [false]
	beast.caught.connect(func() -> void: hit[0] = true)
	view = Vector3(0.6, 0.22, 11.0)
	pin = Vector3(1.0, 0.2, 0.0)
	var waited := 0
	while beast.state != Crocodile.State.WIND_UP and waited < 900:
		await frames(1)
		waited += 1
	track.clear()
	var line := ""
	for i in 30:
		await frames(2)
		await snap()
		line += " %d" % beast.state
	print("LUNGE it stopped short after ", waited, " frames; its state every other frame after that:", line, "; caught him: ", hit[0])
	sheet("m_lunge", 6)
	shake("m_lunge", true)


## The whole of it, from above: he is at the edge, and it comes. A picture every third of a second.
func hunt() -> void:
	boy(Vector3(-0.6, 0.2, 0))
	var beast := croc(Vector3(16, -0.5, 4.0), 0.0, true, false)
	beast.target = player
	view = Vector3(0.25, 0.75, 26.0)
	pin = Vector3(7.0, 0.0, 1.0)
	await frames(30)
	var line := ""
	for i in 24:
		await frames(20)
		await snap()
		line += " %d" % beast.state
	print("HUNT its state every 20 frames:", line)
	sheet("hunt", 6)


## Its mouth: opened slowly, as it does to bask; shut; thrown open and snapped.
func m_gape() -> void:
	var beast := croc(Vector3(0, 0.05, FLAT))
	await frames(200)
	track.clear()
	for i in 18:
		beast.jaws = 0.5 if i < 8 else (0.0 if i < 10 else (1.0 if i < 14 else 0.0))
		beast.jaw_rate = 2.5 if i < 10 else 22.0
		pin = beast._rig._head.global_position + Vector3(0.25, 0.0, 0.0)
		view = Vector3(0.35, 0.12, 3.2)
		await frames(6 if i < 10 else 2)
		await snap()
	sheet("m_gape", 6)
	shake("m_gape", true)


## It has hold of something, on land: its head shaken from side to side.
func m_thrash() -> void:
	var beast := croc(Vector3(0, 0.05, FLAT))
	view = Vector3(0.5, 0.9, 10.0)
	await frames(200)
	track.clear()
	beast._rig.thrash()
	for i in 18:
		await frames(3)
		await snap()
	sheet("m_thrash", 6)
	shake("m_thrash", true)


## And in the water: over and over.
func m_roll() -> void:
	var beast := croc(Vector3(12, -0.5, 0), PI * 0.5, true)
	await frames(200)
	look_h = 0.5
	view = Vector3(0.4, 0.3, 9.0)
	track.clear()
	beast._rig.thrash()
	for i in 24:
		await frames(4)
		await snap()
	sheet("m_roll", 6)
	shake("m_roll", true)
