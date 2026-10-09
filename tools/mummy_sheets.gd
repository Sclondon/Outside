extends SceneTree
## Not part of the game. Puts a mummy (scripts/mummy.gd) on a bare floor with the
## boy to go after, drives it through each thing it does, and saves contact sheets.
##
## godot --path . --fixed-fps 60 --resolution 960x960 --script tools/mummy_sheets.gd -- <outdir> [turnaround face wake walk swipe dodge drapes stop m_walk m_swipe ...] [priest brute crawler child royal] [lo]
##
## With no names, all of them. A kind's name among them (`priest`, `brute`,
## `crawler`, `child`, `royal`) draws that kind and puts its name on the front
## of each sheet's; with none it is the first mummy. `lo` uses the demade model.
## `m_walk` and `m_swipe` are strips for watching how it moves: every frame of
## a walk, one after the other, and every second or third frame of a blow.
##
## It also prints lines starting CHECK: whether a swipe at a boy who stands
## still has him, how high the arm passed, and whether one at a boy who runs
## does not. And, as a picture cannot show a joint that shakes, it watches every
## bone on every frame and prints, under each sheet, a line `SHAKE <sheet>` and
## the bones that turned back on themselves from one frame to the next
## (`shakes`), or whose turning changed by more than a few degrees in one frame
## (`jump`: a flip if it is near 180), and the frame it was worst on
## (`SHAKE_TRACE=<bone>` in the environment prints that bone's turn on every
## frame); and a line `SLIDE`: how far the place on the ground where a foot was
## standing (for the crawler, a hand) moved in one frame at the worst, and over
## the whole of one stand, and how far the bone was from where the rig meant it
## to be (which is what a leg too short to reach its foot shows up as).
## Its window is kept off the screen and takes no input.

const CELL := 480
## A bone has shaken if it turned back on itself by more than this, degrees a frame; and jumped by more than this.
const SHAKE := 1.5
const JUMP := 14.0
## For each kind: how much further off than the first mummy it is looked at from, and how much higher up it.
const FRAMING := {"": Vector2(1.0, 1.0), "priest": Vector2(1.25, 1.2), "brute": Vector2(1.15, 0.9), "crawler": Vector2(0.85, 0.3), "child": Vector2(0.72, 0.6), "royal": Vector2(1.25, 1.15)}
var out := ""
var only: Array = []
var kind := ""
var stage: Node3D
var mummy: Mummy
var player: Player
var touch: TouchControls
var cam: Camera3D
var cells: Array[Image] = []
## Yaw round it, pitch, distance. The yaw is from straight in front of it, or
## (with `fixed`) a compass bearing that does not turn when it does.
var view := Vector3(0.6, 0.1, 5.0)
var fixed := false
var look_h := 0.95
var pin := Vector3.INF
var hits := 0
## Where every bone was on each frame since the last sheet (see `record`), and
## where each foot was while it stood: [which, the frame, where].
var track: Array = []
var stood: Array = []
## The lowest and highest the striking arm has been while it struck.
var arm_span := Vector2(INF, -INF)


func _initialize() -> void:
	DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_NO_FOCUS, true)
	DisplayServer.window_set_position(Vector2i(-6000, -6000))
	var args := OS.get_cmdline_user_args()
	out = args[0]
	only = args.slice(1)
	if "lo" in only:
		only.erase("lo")
		Settings.low_poly = true
	for name: String in FRAMING:
		if name in only:
			only.erase(name)
			kind = name
	DirAccess.make_dir_recursive_absolute(out)
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
	var ground := StaticBody3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(400, 2, 400)
	var collider := CollisionShape3D.new()
	collider.shape = shape
	ground.add_child(collider)
	var mesh := BoxMesh.new()
	mesh.size = shape.size
	var visual := MeshInstance3D.new()
	visual.mesh = mesh
	var material := StandardMaterial3D.new()
	material.albedo_color = Color(0.3, 0.32, 0.34)
	material.roughness = 1.0
	visual.material_override = material
	ground.add_child(visual)
	ground.position = Vector3(0, -1, 0)
	stage.add_child(ground)

	touch = TouchControls.new()
	touch.visible = false
	stage.add_child(touch)
	touch.set_process_input(false)
	player = load("res://player.tscn").instantiate()
	player.position = Vector3(0, 0.05, 60)
	stage.add_child(player)
	player.set_process_unhandled_input(false)
	mummy = Mummy.new()
	mummy.kind = ["", "priest", "brute", "crawler", "child", "royal"].find(kind) as Mummy.Kind
	mummy.position = Vector3(0, 0.05, 0)
	stage.add_child(mummy)
	mummy.target = player
	mummy.caught.connect(func() -> void: hits += 1)
	cam = Camera3D.new()
	cam.fov = 30.0
	stage.add_child(cam)
	cam.make_current()
	run.call_deferred()


func aim() -> void:
	var framing: Vector2 = FRAMING[kind]
	var yaw: float = view.x if fixed else mummy.facing_yaw + view.x
	var away := Vector3(sin(yaw) * cos(view.y), sin(view.y), cos(yaw) * cos(view.y))
	var watch: Vector3 = mummy.visual_position + Vector3.UP * look_h * framing.y
	if pin != Vector3.INF:
		watch = pin
	cam.global_position = watch + away * view.z * (framing.x if pin == Vector3.INF else 1.0)
	cam.look_at(watch)


## Runs the game on. `hold`: where the boy is kept standing. `flee`: or the way he goes, and how fast.
func frames(count: int, hold := Vector3.INF, flee := Vector3.ZERO) -> void:
	for i in count:
		aim()
		if hold != Vector3.INF:
			player.global_position = hold
			player.velocity = Vector3.ZERO
		if flee != Vector3.ZERO:
			player.global_position += flee / 60.0
			player.velocity = Vector3.ZERO
		await physics_frame
		await process_frame
		record()


func snap() -> void:
	aim()
	await RenderingServer.frame_post_draw
	var image := root.get_texture().get_image()
	var side: int = mini(image.get_width(), image.get_height())
	image = image.get_region(Rect2i((image.get_width() - side) / 2, (image.get_height() - side) / 2, side, side))
	image.resize(CELL, CELL, Image.INTERPOLATE_LANCZOS)
	cells.append(image)


## Notes where every bone is this frame, where each foot that is standing is, and how high a striking arm.
func record() -> void:
	var rig := mummy._rig
	var skeleton: Skeleton3D = rig._skeleton
	var row: Array[Transform3D] = []
	for bone in skeleton.get_bone_count():
		row.append(skeleton.get_bone_global_pose(bone))
	track.append(row)
	# (the crawler goes on its hands, and the first mummy keeps its own note of which foot is moving)
	var going: bool = mummy.chasing and rig._move > 0.3 and rig.stage() == MummyRig.Stage.NONE
	for i in 2:
		var bone := skeleton.find_bone(("hand" if kind == "crawler" else "foot") + ("_l" if i == 0 else "_r"))
		var standing: bool = going and not rig._foot_moving[i]
		if kind == "" and i == MummyRig.BAD:
			# (its dragged foot is on the ground all the while, and is meant to be drawn along it)
			standing = false
		if standing:
			# Where on the ground the rig has it standing, and how far the bone is from where the rig meant it to be.
			var ground: Vector3 = rig.to_global(Vector3(rig._foot_at[i].x, 0.0, rig._foot_at[i].z + (MummyCrawlerRig.REACH if kind == "crawler" else 0.0)))
			var meant: Vector3 = rig.to_global(Vector3(rig._foot_at[i].x, rig._foot_lift[i], rig._foot_at[i].z) + rig._ankle_offset(rig._foot_toes[i]))
			if kind == "crawler":
				meant = rig.to_global(rig._hand_at[i])
			stood.append([i, track.size(), ground, meant.distance_to(skeleton.global_transform * row[bone].origin)])
	for arm in rig.claws():
		arm_span = Vector2(minf(arm_span.x, minf(arm[0].y, arm[1].y)), maxf(arm_span.y, maxf(arm[0].y, arm[1].y)))


## Marks a break in what `record` has noted: it has been put somewhere else.
func cut() -> void:
	track.append(null)


## Prints which bones shook or jumped since the last sheet, and how badly, and on which frame of it; and how far its feet slid.
func shake(name: String) -> void:
	var skeleton: Skeleton3D = mummy._rig._skeleton
	var found: Array = []
	var since_cut := 0
	var turns: Array = []  # each bone's turn over the last frame, as an axis times degrees
	var steps: Array = []
	for i in track.size():
		if track[i] == null or (i > 0 and track[i - 1] != null and track[i].size() != track[i - 1].size()):
			since_cut = 0
			turns.clear()
			continue
		since_cut += 1
		# (the first frames after it is put down are it settling)
		if since_cut < 8 or track[i - 1] == null:
			turns.clear()
			continue
		var now: Array = []
		var moved: Array = []
		for bone in track[i].size():
			var q := Quaternion(track[i][bone].basis.orthonormalized()) * Quaternion(track[i - 1][bone].basis.orthonormalized()).inverse()
			var angle := q.get_angle()
			if angle > PI:
				angle -= TAU
			now.append(q.get_axis() * rad_to_deg(angle))
			moved.append(track[i][bone].origin - track[i - 1][bone].origin)
		if not turns.is_empty():
			if found.is_empty():
				for bone in now.size():
					found.append({"bone": skeleton.get_bone_name(bone), "shakes": 0, "worst": 0.0, "at": 0, "jump": 0.0, "jump_at": 0, "slips": 0, "slip": 0.0})
			for bone in mini(now.size(), found.size()):
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
				var c: Vector3 = steps[bone]
				var d: Vector3 = moved[bone]
				if c.dot(d) < 0.0 and minf(c.length(), d.length()) > 0.006:
					found[bone].slips += 1
					found[bone].slip = maxf(found[bone].slip, minf(c.length(), d.length()))
		# (SHAKE_TRACE=<bone> in the environment prints that bone's turn on every frame, degrees about x, y and z)
		var traced := skeleton.find_bone(OS.get_environment("SHAKE_TRACE"))
		if traced >= 0 and traced < now.size():
			print("TRACE %s %d  %6.1f %6.1f %6.1f" % [name, i, now[traced].x, now[traced].y, now[traced].z])
		turns = now
		steps = moved
	# (what hangs loose is thrown about, and is meant to be)
	var bad := found.filter(func(entry: Dictionary) -> bool: return (entry.shakes >= 2 or entry.jump > JUMP or entry.slips >= 2) and not String(entry.bone).begins_with("drape_"))
	bad.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return a.shakes * 100 + a.jump > b.shakes * 100 + b.jump)
	print("SHAKE ", name, " frames=", track.size(), " bones=", bad.size())
	for entry: Dictionary in bad.slice(0, 14):
		print("  %-14s shakes=%d worst=%.1f at %d | jump=%.1f at %d | slips=%d %.3f" % [entry.bone, entry.shakes, entry.worst, entry.at, entry.jump, entry.jump_at, entry.slips, entry.slip])
	track.clear()

	# A foot that stood: how far it went along the ground from one frame to the next, and from where it was first put.
	var worst := 0.0
	var drift := 0.0
	var off := 0.0
	var count := 0
	var first := {}
	var last := {}
	for entry: Array in stood:
		var i: int = entry[0]
		var at: Vector3 = entry[2]
		at.y = 0.0
		off = maxf(off, entry[3])
		if last.has(i) and last[i][0] == entry[1] - 1:
			worst = maxf(worst, at.distance_to(last[i][1]))
			drift = maxf(drift, at.distance_to(first[i]))
			count += 1
		else:
			first[i] = at
		last[i] = [entry[1], at]
	if count > 0:
		print("SLIDE %s: the place a %s stood on moved %.1f mm in a frame at the worst and %.1f mm in all while it stood there, and the %s was never more than %.1f mm from where it was meant to be (%d frames)" % [name, "hand" if kind == "crawler" else "foot", worst * 1000.0, drift * 1000.0, "hand" if kind == "crawler" else "ankle", off * 1000.0, count])
	stood.clear()


func sheet(name: String, columns := 4) -> void:
	shake(name)
	var rows := ceili(cells.size() / float(columns))
	var page := Image.create(CELL * columns, CELL * rows, false, cells[0].get_format())
	for i in cells.size():
		page.blit_rect(cells[i], Rect2i(0, 0, CELL, CELL), Vector2i((i % columns) * CELL, (i / columns) * CELL))
	var file := out.path_join(("lo_" if Settings.low_poly else "") + (kind + "_" if kind != "" else "") + name + ".png")
	page.save_png(file)
	cells.clear()
	print("SHEET ", file)


## Puts the mummy back at the middle of the floor, dormant, facing +Z, and the boy at `boy`.
func place(boy: Vector3) -> void:
	mummy._spawn = Transform3D(Basis.IDENTITY, Vector3(0, 0.05, 0))
	mummy.reset()
	touch.move = Vector2.ZERO
	player.state = Player.State.FREE
	player.global_position = boy
	player.velocity = Vector3.ZERO
	player._spawn = Transform3D(Basis.IDENTITY, boy)
	player.respawn()
	player._reset_visuals()
	fixed = false
	look_h = 0.95
	cut()
	stood.clear()


## Wakes it and lets it get going after the boy, who is kept at `boy`.
func rouse(boy: Vector3, lead: int) -> void:
	place(boy)
	mummy.wake()
	await frames(int(mummy.wake_time * 60.0) + lead, boy)


func wants(name: String) -> bool:
	return only.is_empty() or name in only


func run() -> void:
	# A gamepad is heard whether the window has the focus or not, and someone may be playing.
	for action: StringName in InputMap.get_actions():
		if not String(action).begins_with("ui_"):
			InputMap.action_erase_events(action)
			Input.action_release(action)
	await frames(5)
	for name: String in ["turnaround", "face", "wake", "walk", "swipe", "dodge", "drapes", "stop", "m_walk", "m_swipe"]:
		if wants(name):
			await call(name)
	quit()


## All round it: as it stands dormant, and awake with nobody to go after.
func turnaround() -> void:
	place(Vector3(0, 0.05, 60))
	await frames(40)
	for yaw: float in [0.0, 0.7, PI * 0.5, PI - 0.6, PI, -0.7]:
		view = Vector3(yaw, 0.08, 5.6)
		await frames(2)
		await snap()
	sheet("dormant", 3)
	mummy.target = null
	mummy.wake()
	await frames(240)
	for yaw: float in [0.0, 0.7, PI * 0.5, PI - 0.6, PI, -0.7]:
		view = Vector3(yaw, 0.08, 5.6)
		await frames(2)
		await snap()
	sheet("turnaround", 3)
	# A hand, and its feet
	look_h = 0.55
	for yaw: float in [0.9, -0.9]:
		view = Vector3(yaw, 0.1, 2.0)
		await frames(2)
		await snap()
	look_h = 0.2
	for yaw: float in [0.7, PI - 0.7]:
		view = Vector3(yaw, 0.2, 2.2)
		await frames(2)
		await snap()
	sheet("closeups", 2)
	mummy.target = player


## Its face, close to, from several sides and from the boy's height.
func face() -> void:
	# (it is after the boy, so its head is up, but is held where it stands)
	place(Vector3(0, 0.05, 6))
	var speed := mummy.walk_speed
	mummy.walk_speed = 0.001
	mummy.wake()
	await frames(240, Vector3(0, 0.05, 6))
	var head: Node3D = mummy._rig._head
	for angle: Vector2 in [Vector2(0.0, 0.0), Vector2(0.45, 0.0), Vector2(0.9, 0.05), Vector2(PI * 0.5, 0.0), Vector2(-0.6, 0.1), Vector2(0.0, -0.45), Vector2(0.5, -0.4), Vector2(2.4, 0.1)]:
		pin = head.global_position + Vector3.UP * 0.09
		view = Vector3(angle.x, angle.y, 1.15)
		await frames(2)
		await snap()
	sheet("face", 4)
	pin = Vector3.INF
	mummy.walk_speed = speed


## Woken: from standing dead to coming on.
func wake() -> void:
	place(Vector3(0, 0.05, 30))
	await frames(30)
	view = Vector3(0.55, 0.08, 5.6)
	mummy.wake()
	for i in 12:
		await snap()
		await frames(int(mummy.wake_time * 60.0 / 8.0) + 1, Vector3(0, 0.05, 30))
	sheet("wake", 4)


## The walk: side on at every fourth frame, then coming at the camera, then going away.
func walk() -> void:
	await rouse(Vector3(200, 0.05, 0), 150)
	var from := mummy.global_position.x
	fixed = true
	view = Vector3(0.0, 0.04, 6.2)
	for i in 20:
		await frames(4, Vector3(200, 0.05, 0))
		await snap()
	sheet("walk_side", 5)
	view = Vector3(PI * 0.5 - 0.35, 0.1, 6.2)
	for i in 8:
		await frames(7, Vector3(200, 0.05, 0))
		await snap()
	sheet("walk_front", 4)
	view = Vector3(-PI * 0.5 + 0.4, 0.14, 6.2)
	for i in 8:
		await frames(7, Vector3(200, 0.05, 0))
		await snap()
	sheet("walk_back", 4)
	print("CHECK walk: going ", snappedf(Vector2(mummy.velocity.x, mummy.velocity.z).length(), 0.01), " m/s just now, ", snappedf((mummy.global_position.x - from) / ((80 + 56 + 56) / 60.0), 0.01), " m/s over the three sheets")


## Every frame of the walk, one after the other, from the side; and from in front.
func m_walk() -> void:
	await rouse(Vector3(200, 0.05, 0), 150)
	fixed = true
	view = Vector3(0.0, 0.04, 5.4)
	for i in 30:
		await frames(1, Vector3(200, 0.05, 0))
		await snap()
	sheet("m_walk", 6)
	view = Vector3(PI * 0.5 - 0.3, 0.1, 5.4)
	for i in 30:
		await frames(1, Vector3(200, 0.05, 0))
		await snap()
	sheet("m_walk_front", 6)


## Runs it up to the boy and waits for it to begin its next swipe. False if it never does.
func closes(boy: Vector3) -> bool:
	var before := mummy._swipes
	arm_span = Vector2(INF, -INF)
	for i in 900:
		if mummy._swipes > before:
			return true
		await frames(1, boy)
	print("CHECK swipe: it never began one")
	return false


## A blow from when it begins, every second frame (or third, for the slow ones), from the side and a little in front.
func m_swipe() -> void:
	var boy := Vector3(4.0, 0.05, 0)
	await rouse(boy, 0)
	if not await closes(boy):
		return
	var rig := mummy._rig
	var every := ceili((rig.swipe_wind_up + rig.swipe_strike + rig.swipe_hold * 0.6) * 60.0 / 36.0)
	fixed = true
	view = Vector3(0.35, 0.1, 6.4)
	look_h = 0.9
	hits = 0
	for i in 36:
		await snap()
		await frames(every, boy)
	sheet("m_swipe", 6)
	print("CHECK m_swipe: every ", every, " frames; it ", "had him" if hits > 0 else "MISSED him")


## Three swipes at a boy who stands where he is: the right arm, the left, and both.
func swipe() -> void:
	var boy := Vector3(4.0, 0.05, 0)
	await rouse(boy, 0)
	for which: String in ["right", "left", "both"]:
		hits = 0
		if not await closes(boy):
			return
		fixed = true
		view = Vector3(0.5, 0.12, 7.0)
		look_h = 0.9
		var rig := mummy._rig
		var every := ceili((rig.swipe_wind_up + rig.swipe_strike + rig.swipe_hold + rig.swipe_recover) * 60.0 / 20.0)
		for i in 20:
			await snap()
			await frames(every, boy)
		sheet("swipe_" + which, 5)
		print("CHECK swipe ", which, ": the boy stood still ", snappedf(mummy.global_position.distance_to(boy), 0.01), " m off and it ", "had him" if hits > 0 else "MISSED him", " (", hits, "); its arm passed between ", snappedf(arm_span.x, 0.01), " and ", snappedf(arm_span.y, 0.01), " m up")
	# And one from in front, as he sees it
	if await closes(boy):
		view = Vector3(PI * 0.5 - 0.15, 0.05, 6.0)
		for i in 15:
			await snap()
			await frames(5, boy)
		sheet("swipe_front", 5)


## The same, at a boy who makes off as soon as it rears: at a run, at a walk, and sideways.
func dodge() -> void:
	for way: Array in [["runs away", Vector3(4.4, 0, 0)], ["walks away", Vector3(1.6, 0, 0)], ["runs across", Vector3(0, 0, 4.4)], ["walks across", Vector3(0, 0, 1.6)]]:
		var boy := Vector3(4.0, 0.05, 0)
		await rouse(boy, 0)
		hits = 0
		if not await closes(boy):
			return
		# (he takes a moment to see it)
		await frames(9, boy)
		await frames(110, Vector3.INF, way[1])
		print("CHECK dodge: the boy ", way[0], " and it ", "HAD him" if hits > 0 else "missed him")
	track.clear()
	stood.clear()


## What hangs from it, as it turns hard about: from behind and to one side.
func drapes() -> void:
	await rouse(Vector3(200, 0.05, 0), 120)
	fixed = true
	view = Vector3(-PI * 0.5 - 0.6, 0.12, 5.6)
	# (the boy is suddenly behind it and to one side)
	var boy := mummy.global_position + Vector3(-6, 0, 5)
	for i in 20:
		await snap()
		await frames(5, boy)
	sheet("drapes_turn", 5)


## And as it stops dead.
func stop() -> void:
	await rouse(Vector3(200, 0.05, 0), 120)
	fixed = true
	view = Vector3(0.5, 0.1, 5.0)
	mummy.target = null
	for i in 15:
		await snap()
		await frames(5)
	sheet("drapes_stop", 5)
	mummy.target = player
