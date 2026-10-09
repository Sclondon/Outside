extends SceneTree
## Not part of the game. A test stage for the mummified jackal and the hyena: drives one (or more) through
## each thing it does and saves contact sheets of what its rig makes of it, as hound_sheets.gd does for the hounds.
## godot --path . --fixed-fps 60 --resolution 960x960 --script tools/canine_sheets.gd -- <outdir> [scenario ...]
## Among the names: `lo` for the demade models.
## The jackal's: turnaround finery dormant stalk trot pack prowl felled m_rise m_stand m_trot m_stalk m_lunge m_strips
## The hyena's: h_turnaround h_coat h_walk h_lope h_run h_loiter h_crest h_flee m_h_walk m_h_lope m_h_run m_h_crest m_h_dart m_h_idle
## The scenarios whose names begin `m_` are strips of consecutive frames, for watching how a thing moves. After
## each of those it prints which bones shook or jumped (SHAKE), as pose_sheets.gd does for the boy; and under each
## gait, when each paw came down in the stride and how far any planted paw slid (SLIDE).

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
var beasts: Array[CharacterBody3D] = []
var player: Player
## What the camera watches, from where: (yaw round it, pitch, distance), and how high up it.
var watch: Node3D
var view := Vector3(PI * 0.5, 0.05, 3.2)
var look_h := 0.45
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
	box(Vector3(0, -1, 0), Vector3(400, 2, 120), Color(0.42, 0.44, 0.46))
	# Somewhere out of reach (top at 2.1, like the block in the yard)
	box(Vector3(0, 1.05, -20), Vector3(3, 2.1, 3), Color(0.36, 0.38, 0.41))
	cam = Camera3D.new()
	cam.fov = 30.0
	stage.add_child(cam)
	cam.make_current()
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


## A fresh jackal, dormant where it is put, and waking for nothing but being told to.
func jackal(at: Vector3, yaw := PI * 0.5, finery := JackalMummy.Finery.PLAIN, rest := JackalMummy.Rest.SPHINX) -> JackalMummy:
	var made := JackalMummy.new()
	made.finery = finery
	made.rest = rest
	made.wake_within = 0.0
	made.voice = false
	made.position = at
	made.rotation.y = yaw
	stage.add_child(made)
	beasts.append(made)
	watch = made
	return made


## A fresh hyena, standing where it is put and doing nothing of its own accord.
func hyena(at: Vector3, yaw := PI * 0.5, calm := true) -> Hyena:
	var made := Hyena.new()
	made.voice = false
	made.position = at
	made.rotation.y = yaw
	stage.add_child(made)
	if calm:
		made.bidden = at
	beasts.append(made)
	watch = made
	return made


func clear() -> void:
	for old in beasts:
		old.queue_free()
	beasts.clear()
	if player:
		player.queue_free()
		player = null
	pin = Vector3.INF
	look_h = 0.45
	track.clear()


## The boy himself, for them to hunt, or to hang about.
func boy(at: Vector3) -> void:
	var touch := TouchControls.new()
	touch.visible = false
	stage.add_child(touch)
	touch.set_process_input(false)
	player = load("res://player.tscn").instantiate()
	player.position = at
	stage.add_child(player)
	player.set_process_unhandled_input(false)
	# (he is only here to be hunted: he stays exactly where he is put)
	player.set_physics_process(false)
	deafen()


func aim() -> void:
	var at := pin
	if at == Vector3.INF:
		if not is_instance_valid(watch):
			return
		at = watch.get(&"visual_position") + Vector3.UP * look_h
	var away := Vector3(sin(view.x) * cos(view.y), sin(view.y), cos(view.x) * cos(view.y))
	cam.global_position = at + away * view.z
	cam.look_at(at)


func frames(count: int, noting := false) -> void:
	for i in count:
		aim()
		await physics_frame
		await process_frame
		if noting:
			record()


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


func rig_of(beast: Node) -> CanineRig:
	return beast.get(&"_rig") as CanineRig


## Notes where every bone of the one being watched is this frame.
func record() -> void:
	if beasts.is_empty() or not is_instance_valid(beasts[0]) or rig_of(beasts[0]) == null:
		return
	var skeleton: Skeleton3D = rig_of(beasts[0])._skeleton
	var row: Array[Transform3D] = []
	for bone in skeleton.get_bone_count():
		row.append(skeleton.get_bone_global_pose(bone))
	track.append(row)


## Prints which bones shook or jumped since the track was last cleared, and how badly, and on which frame.
## What hangs on springs or as a chain of weights (ears, tail, loose bandage) is left out: it is meant to
## quiver. So is whatever is named in `but`, with the reason given where it is.
func shake(name: String, but: Array[String] = []) -> void:
	var skeleton: Skeleton3D = rig_of(beasts[0])._skeleton
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
		var bone := String(entry.bone)
		if bone.begins_with("ear") or bone.begins_with("tail") or bone.begins_with("drape") or bone in but:
			return false
		return entry.shakes >= 2 or entry.jump > JUMP)
	bad.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return a.shakes * 100 + a.jump > b.shakes * 100 + b.jump)
	# (and the fastest any bone turned, so that a bone that flips right over cannot hide)
	var fastest := 0.0
	var fastest_bone := ""
	for i in range(1, track.size()):
		for bone in track[i].size():
			var called := skeleton.get_bone_name(bone)
			if called.begins_with("ear") or called.begins_with("tail") or called.begins_with("drape"):
				continue
			var turned := rad_to_deg(track[i][bone].basis.orthonormalized().get_rotation_quaternion().angle_to(track[i - 1][bone].basis.orthonormalized().get_rotation_quaternion()))
			if turned > fastest:
				fastest = turned
				fastest_bone = "%s at %d" % [called, i]
	print("SHAKE ", name, " frames=", track.size(), " bones=", bad.size(), "  fastest turn in a frame: %.1f degrees (%s)" % [fastest, fastest_bone])
	for entry: Dictionary in bad.slice(0, 14):
		print("  %-12s shakes=%d worst=%.1f at %d | jump=%.1f at %d" % [entry.bone, entry.shakes, entry.worst, entry.at, entry.jump, entry.jump_at])
	track.clear()


func wants(name: String) -> bool:
	return only.is_empty() or name in only


func run() -> void:
	deafen()
	await frames(5)
	for name: String in ["turnaround", "finery", "dormant", "stalk", "trot", "pack", "prowl", "felled", "m_rise", "m_stand", "m_trot", "m_stalk", "m_lunge", "m_strips",
			"h_turnaround", "h_coat", "h_walk", "h_lope", "h_run", "h_loiter", "h_crest", "h_flee", "m_h_walk", "m_h_lope", "m_h_run", "m_h_crest", "m_h_dart", "m_h_idle"]:
		if wants(name):
			await call(name)
			clear()
			await frames(2)
	quit()


# --- The jackal ---

## All round it, on its feet; and its head close to.
func turnaround() -> void:
	var beast := jackal(Vector3(0, 0.05, 0), 0.0)
	beast.bidden = beast.position
	await frames(150)
	look_h = 0.5
	for yaw: float in [0.0, 0.7, PI * 0.5, PI - 0.6, PI, -0.7, -PI * 0.5, 0.4]:
		view = Vector3(yaw, 0.35 if yaw == 0.4 else 0.08, 3.1)
		await frames(2)
		await snap()
	sheet("turnaround")
	var head: Vector3 = rig_of(beast)._head.global_position
	for yaw: float in [0.0, 0.8, PI * 0.5, -PI * 0.5]:
		pin = head + Vector3(0, 0.02, 0.08)
		view = Vector3(yaw, 0.1, 1.1)
		await frames(2)
		await snap()
	sheet("head")


## What it can wear: nothing, the collar, and the mask and the collar; each lying dormant and on its feet.
func finery() -> void:
	for wear: JackalMummy.Finery in [JackalMummy.Finery.PLAIN, JackalMummy.Finery.COLLAR, JackalMummy.Finery.MASK]:
		var beast := jackal(Vector3(0, 0.05, 0), 0.0, wear)
		await frames(20)
		look_h = 0.35
		view = Vector3(0.75, 0.12, 2.6)
		await frames(2)
		await snap()
		beast.bidden = beast.position
		await frames(150)
		look_h = 0.5
		view = Vector3(0.75, 0.1, 2.9)
		await frames(2)
		await snap()
		pin = rig_of(beast)._head.global_position + Vector3(0, 0.02, 0.06)
		view = Vector3(0.6, 0.1, 1.0)
		await frames(2)
		await snap()
		clear()
		await frames(2)
	sheet("finery", 3)


## Dormant: lying like a sphinx, from the side, the front, a quarter and above; and standing.
func dormant() -> void:
	jackal(Vector3(0, 0.05, 0), 0.0)
	await frames(30)
	look_h = 0.35
	for shot: Vector3 in [Vector3(PI * 0.5, 0.05, 2.8), Vector3(0.0, 0.08, 2.8), Vector3(0.8, 0.15, 2.8), Vector3(-2.3, 0.5, 2.8)]:
		view = shot
		await frames(2)
		await snap()
	clear()
	await frames(2)
	jackal(Vector3(0, 0.05, 0), 0.0, JackalMummy.Finery.COLLAR, JackalMummy.Rest.STANDING)
	await frames(30)
	look_h = 0.5
	for shot: Vector3 in [Vector3(PI * 0.5, 0.05, 3.0), Vector3(0.0, 0.08, 3.0), Vector3(0.8, 0.15, 3.0), Vector3(-2.3, 0.5, 3.0)]:
		view = shot
		await frames(2)
		await snap()
	sheet("dormant")


## Sets a beast going along the stage at a speed, and waits for it to be up and at it.
func going(beast: CharacterBody3D, speed: float, wait := 240) -> void:
	beast.set(&"bidden", Vector3(190, 0, beast.position.z))
	beast.set(&"bidden_speed", speed)
	await frames(wait)


## A side view of a stride, `count` pictures `every` frames apart, then from in front and behind. Under it:
## when each paw came down in the stride, how far any planted paw slid over the ground, and how far the body rose and fell.
func strip(name: String, beast: CharacterBody3D, speed: float, every: int, count: int, distance := 3.2, also_round := true, noting := false) -> void:
	await going(beast, speed)
	view = Vector3(0.0, 0.03, distance)
	var rig := rig_of(beast)
	var line := ""
	var low := 9.0
	var high := 0.0
	var slid := 0.0
	var held: Array = [null, null, null, null]
	var landed: Array[String] = ["-", "-", "-", "-"]
	var was_down: Array[bool] = [true, true, true, true]
	track.clear()
	for i in count * every:
		await frames(1, noting)
		var lowest := 9.0
		for leg in 4:
			var paw: Vector3 = (rig._legs[leg][3] as Node3D).global_position
			var off: float = paw.y - rig._paw_height - (beast.get(&"visual_position") as Vector3).y
			lowest = minf(lowest, off)
			# (a paw that is on the ground should stay where it was put)
			var planted: bool = off < 0.004
			if planted and held[leg] != null:
				slid = maxf(slid, Vector2(paw.x - held[leg].x, paw.z - held[leg].z).length())
			elif planted:
				held[leg] = paw
			else:
				held[leg] = null
			if planted and not was_down[leg]:
				landed[leg] = "%.2f" % rig._phase
			was_down[leg] = planted
		low = minf(low, lowest)
		high = maxf(high, lowest)
		if i % every == every - 1:
			await snap()
			line += " %.2f" % rig._phase
	print("GAIT ", name, " speed=", snappedf(Vector2(beast.velocity.x, beast.velocity.z).length(), 0.01), " lowest paw from ", snappedf(low, 0.001), " to ", snappedf(high, 0.001),
			"  landed (fl fr rl rr) at ", " ".join(landed), "  phases:", line)
	print("SLIDE ", name, " furthest a planted paw moved over the ground: %.3f m" % slid)
	sheet(name, 4 if count <= 8 else 6)
	if noting:
		shake(name)
	if also_round:
		view = Vector3(PI * 0.5 - 0.5, 0.15, distance)
		for i in 4:
			await frames(every * 2)
			await snap()
		view = Vector3(-PI * 0.5 + 0.6, 0.2, distance)
		for i in 4:
			await frames(every * 2)
			await snap()
		sheet(name + "_round")


func stalk() -> void:
	await strip("stalk", jackal(Vector3(-150, 0.05, 0)), 1.0, 5, 8)


func trot() -> void:
	await strip("trot", jackal(Vector3(-150, 0.05, 0)), 3.9, 2, 8)


## Every frame of a stride and a bit of its trot, and of its stalk.
func m_trot() -> void:
	await strip("m_trot", jackal(Vector3(-150, 0.05, 0)), 3.9, 1, 24, 3.0, false, true)


func m_stalk() -> void:
	await strip("m_stalk", jackal(Vector3(-150, 0.05, 0)), 1.0, 2, 24, 3.0, false, true)


## Getting up from lying, start to finish, every fifth frame; and again from in front.
func m_rise() -> void:
	for shot: Vector3 in [Vector3(0.0, 0.05, 3.0), Vector3(1.0, 0.15, 3.0)]:
		var beast := jackal(Vector3(0, 0.05, 0))
		await frames(30)
		view = shot
		look_h = 0.42
		beast.wake()
		track.clear()
		for i in 24:
			await frames(5, true)
			await snap()
		sheet("m_rise" if shot.x == 0.0 else "m_rise_front", 6)
		if shot.x == 0.0:
			shake("m_rise")
		clear()
		await frames(2)


## Waking where it stands.
func m_stand() -> void:
	var beast := jackal(Vector3(0, 0.05, 0), PI * 0.5, JackalMummy.Finery.MASK, JackalMummy.Rest.STANDING)
	await frames(30)
	view = Vector3(0.6, 0.08, 3.0)
	look_h = 0.5
	beast.wake()
	track.clear()
	for i in 18:
		await frames(6, true)
		await snap()
	sheet("m_stand", 6)
	shake("m_stand")


## It comes at the boy, gathers itself, springs and lands: every third frame from when it gathers.
func m_lunge() -> void:
	boy(Vector3(4.2, 0.05, 0))
	var beast := jackal(Vector3(-4, 0.05, 0))
	beast.target = player
	beast.wake()
	var crouched := false
	for i in 600:
		await frames(1)
		if beast.state == JackalMummy.State.CROUCH:
			crouched = true
			break
	print("LUNGE gathered itself: ", crouched, " at ", snappedf(beast.global_position.distance_to(player.global_position), 0.01), " m from him")
	pin = (beast.global_position + player.global_position) * 0.5 + Vector3.UP * 0.5
	view = Vector3(0.0, 0.06, 5.2)
	var caught := [false]
	beast.caught.connect(func() -> void: caught[0] = true)
	track.clear()
	for i in 30:
		await snap()
		await frames(3, true)
	print("LUNGE found him: ", caught[0], "; came down ", snappedf(beast.global_position.x - player.global_position.x, 0.01), " m past him; state ", beast.state)
	sheet("m_lunge", 6)
	# (its jaw is meant to snap)
	shake("m_lunge", ["jaw"])


## Two of them after the boy: from above, every half second. They should come at him from two sides.
func pack() -> void:
	boy(Vector3(0, 0.05, 0))
	var first := jackal(Vector3(-11, 0.05, -0.8))
	var second := jackal(Vector3(-11, 0.05, 0.8))
	for beast: JackalMummy in [first, second]:
		beast.target = player
		beast.lunge_distance = 0.0
		beast.wake()
	pin = Vector3(-4, 0.3, 0)
	view = Vector3(0.0, 1.25, 17.0)
	var widest := 0.0
	for i in 12:
		await frames(30)
		await snap()
		var a := first.global_position - player.global_position
		var b := second.global_position - player.global_position
		widest = maxf(widest, absf(angle_difference(atan2(a.x, a.z), atan2(b.x, b.z))))
	print("PACK the widest they came at him from: ", snappedf(rad_to_deg(widest), 1.0), " degrees apart")
	sheet("pack", 6)


## The boy up on something: it cannot get at him, and prowls beneath.
func prowl() -> void:
	boy(Vector3(0, 2.15, -19.5))
	var beast := jackal(Vector3(-7, 0.05, -16))
	beast.target = player
	beast.wake()
	pin = Vector3(0, 0.9, -19)
	view = Vector3(0.5, 0.35, 11.0)
	for i in 8:
		await frames(75)
		await snap()
	print("PROWL state ", beast.state, " prowling ", beast._prowl > 0.0, " at ", beast.global_position)
	sheet("prowl")


## Shot down, lying, and getting up again.
func felled() -> void:
	boy(Vector3(30, 0.05, 0))
	var beast := jackal(Vector3(0, 0.05, 0))
	beast.target = player
	beast.down_time = 2.0
	beast.wake()
	await frames(200)
	view = Vector3(0.3, 0.1, 3.4)
	beast.shot(player, beast.global_position, Vector3(-1, 0, 0), 20.0)
	for i in 3:
		await frames(8)
		await snap()
	beast.shot(player, beast.global_position, Vector3(-1, 0, 0), 30.0)
	for i in 9:
		await frames(22)
		await snap()
	print("FELLED state at the end ", beast.state)
	sheet("felled", 6)


## Its loose ends as it turns and stops: every fourth frame.
func m_strips() -> void:
	var beast := jackal(Vector3(-20, 0.05, 0))
	await going(beast, 3.9, 300)
	beast.bidden = beast.global_position + Vector3(0.4, 0, 6)
	view = Vector3(0.9, 0.12, 3.4)
	for i in 18:
		await frames(4)
		await snap()
	sheet("m_strips", 6)


# --- The hyena ---

func h_turnaround() -> void:
	var beast := hyena(Vector3(0, 0.05, 0), 0.0)
	await frames(60)
	look_h = 0.55
	for yaw: float in [0.0, 0.7, PI * 0.5, PI - 0.6, PI, -0.7, -PI * 0.5, 0.4]:
		view = Vector3(yaw, 0.35 if yaw == 0.4 else 0.08, 3.8)
		await frames(2)
		await snap()
	sheet("h_turnaround")
	var head: Vector3 = rig_of(beast)._head.global_position
	for yaw: float in [0.0, 0.8, PI * 0.5, -PI * 0.5]:
		pin = head + Vector3(0, 0.0, 0.1)
		view = Vector3(yaw, 0.1, 1.5)
		await frames(2)
		await snap()
	sheet("h_head")


## Its coat close to: the flank, the legs, the throat and the mane.
func h_coat() -> void:
	var beast := hyena(Vector3(0, 0.05, 0), 0.0)
	await frames(60)
	var body: Vector3 = beast.global_position + Vector3.UP * 0.55
	for shot: Array in [[Vector3(0, 0.02, 0), Vector3(PI * 0.5, 0.1, 2.0)], [Vector3(0, -0.3, 0.25), Vector3(0.9, 0.05, 1.4)], [Vector3(0, 0.1, 0.45), Vector3(0.35, -0.1, 1.5)],
			[Vector3(0, 0.15, 0.0), Vector3(2.4, 0.55, 1.9)]]:
		pin = body + shot[0]
		view = shot[1]
		await frames(2)
		await snap()
	sheet("h_coat")


func h_walk() -> void:
	await strip("h_walk", hyena(Vector3(-150, 0.05, 0), PI * 0.5, false), 1.0, 5, 8, 4.0)


func h_lope() -> void:
	await strip("h_lope", hyena(Vector3(-150, 0.05, 0), PI * 0.5, false), 3.2, 3, 8, 4.0)


func h_run() -> void:
	await strip("h_run", hyena(Vector3(-150, 0.05, 0), PI * 0.5, false), 7.0, 2, 8, 4.4)


func m_h_walk() -> void:
	await strip("m_h_walk", hyena(Vector3(-150, 0.05, 0), PI * 0.5, false), 1.0, 2, 24, 3.8, false, true)


func m_h_lope() -> void:
	await strip("m_h_lope", hyena(Vector3(-150, 0.05, 0), PI * 0.5, false), 3.2, 1, 30, 3.8, false, true)


func m_h_run() -> void:
	await strip("m_h_run", hyena(Vector3(-150, 0.05, 0), PI * 0.5, false), 7.0, 1, 24, 4.2, false, true)


## Standing about: every eighth frame for a while.
func m_h_idle() -> void:
	hyena(Vector3(0, 0.05, 0))
	await frames(60)
	view = Vector3(0.5, 0.08, 3.8)
	look_h = 0.55
	track.clear()
	for i in 18:
		await frames(8, true)
		await snap()
	sheet("m_h_idle", 6)
	shake("m_h_idle")


## Its mane lying, and raised; and going up, every other frame.
func h_crest() -> void:
	var beast := hyena(Vector3(0, 0.05, 0))
	await frames(60)
	look_h = 0.6
	for raised: bool in [false, true]:
		beast.bristle = 1.0 if raised else 0.0
		await frames(50)
		for shot: Vector3 in [Vector3(0.0, 0.05, 3.8), Vector3(1.0, 0.2, 3.8), Vector3(PI * 0.5, 0.1, 3.8)]:
			view = shot
			await frames(2)
			await snap()
	sheet("h_crest", 3)


func m_h_crest() -> void:
	var beast := hyena(Vector3(0, 0.05, 0))
	await frames(60)
	look_h = 0.6
	view = Vector3(0.3, 0.1, 3.6)
	beast.bristle = 1.0
	track.clear()
	for i in 12:
		await snap()
		await frames(2, true)
	sheet("m_h_crest", 6)
	shake("m_h_crest")


## Two of them and the boy, from above, every second: they keep off, and go round him.
func h_loiter() -> void:
	boy(Vector3(0, 0.05, 0))
	var first := hyena(Vector3(-13, 0.05, -2), PI * 0.5, false)
	var second := hyena(Vector3(-14, 0.05, 2), PI * 0.5, false)
	for beast: Hyena in [first, second]:
		beast.target = player
		beast.bold = 0.3
	pin = Vector3(0, 0.3, 0)
	view = Vector3(0.0, 1.2, 36.0)
	var nearest := 99.0
	var states := {}
	for i in 18:
		for f in 60:
			await frames(1)
			nearest = minf(nearest, minf(first.global_position.distance_to(player.global_position), second.global_position.distance_to(player.global_position)))
			states[first.state] = true
			states[second.state] = true
		await snap()
	print("LOITER the nearest either came to him: ", snappedf(nearest, 0.1), " m; states seen ", states.keys())
	sheet("h_loiter", 6)


## A dart at him and away again, every fifth frame from when it starts in.
func m_h_dart() -> void:
	boy(Vector3(0, 0.05, 0))
	var beast := hyena(Vector3(-9, 0.05, 0), PI * 0.5, false)
	beast.target = player
	beast.bold = 0.6
	await frames(60)
	beast.dart()
	pin = Vector3(-4.0, 0.5, 0)
	view = Vector3(0.0, 0.1, 13.0)
	var nearest := 99.0
	track.clear()
	for i in 30:
		await snap()
		for f in 5:
			await frames(1, true)
			nearest = minf(nearest, beast.global_position.distance_to(player.global_position))
	print("DART the nearest it came to him: ", snappedf(nearest, 0.01), " m; state at the end ", beast.state, ", ", snappedf(beast.global_position.distance_to(player.global_position), 0.1), " m off")
	sheet("m_h_dart", 6)
	shake("m_h_dart")


## A flare lands by it: it gives way.
func h_flee() -> void:
	boy(Vector3(0, 0.05, 0))
	var beast := hyena(Vector3(-7, 0.05, 0), PI * 0.5, false)
	beast.target = player
	await frames(90)
	pin = Vector3(-10, 0.5, 0)
	view = Vector3(0.0, 0.25, 22.0)
	beast.shot(player, beast.global_position, Vector3(-1, 0, 0), 10.0)
	for i in 8:
		await snap()
		await frames(20)
	print("FLEE ", snappedf(beast.global_position.distance_to(player.global_position), 0.1), " m from him at the end; state ", beast.state)
	sheet("h_flee")
