extends SceneTree
## Not part of the game. A test stage for the hounds: drives one (or two) through each thing
## they do and saves contact sheets of what the rig makes of it, like pose_sheets.gd does for the boy.
## godot --path . --fixed-fps 60 --resolution 960x960 --script tools/hound_sheets.gd -- <outdir> [scenario ...]
## Among the names: `pharaoh` for the prick-eared hound (otherwise the bloodhound), `lo` for the
## demade models, `pale` to give it a light coat so its shape can be seen.
## The scenarios whose names begin `m_` are strips of consecutive frames, for watching how a thing moves.

const CELL := 480
var out := ""
var only: Array = []
var stage: Node3D
var cam: Camera3D
var cells: Array[Image] = []
var hounds: Array[Hound] = []
var player: Player
var breed := Hound.Breed.BLOODHOUND
var pale := false
## What the camera watches, from where: (yaw round it, pitch, distance), and how high up it.
var watch: Node3D
var view := Vector3(PI * 0.5, 0.05, 3.0)
var look_h := 0.45
var pin := Vector3.INF


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
	if "pharaoh" in only:
		only.erase("pharaoh")
		breed = Hound.Breed.PHARAOH
	if "pale" in only:
		only.erase("pale")
		pale = true
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
	box(Vector3(0, -1, 0), Vector3(400, 2, 80), Color(0.42, 0.44, 0.46))
	# Somewhere out of a hound's reach (top at 2.1, like the block in the yard)
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


## A fresh hound, standing where it is put and doing nothing of its own accord.
func hound(at: Vector3, yaw := PI * 0.5, calm := true, which := Hound.Breed.ANY) -> Hound:
	var made := Hound.new()
	made.breed = breed if which == Hound.Breed.ANY else which
	made.position = at
	if calm:
		made.play_time = 0.0
		made.settle_after = 100000.0
	stage.add_child(made)
	made.facing_yaw = yaw
	hounds.append(made)
	watch = made
	if pale:
		paint(made, Color(0.62, 0.5, 0.38))
	return made


## Gives a hound a coat of another colour.
func paint(dog: Hound, colour: Color) -> void:
	for part: MeshInstance3D in dog._rig.find_children("*", "MeshInstance3D", true, false):
		for surface in part.mesh.get_surface_count():
			var original := part.mesh.surface_get_material(surface) as StandardMaterial3D
			if original and original.resource_name == "coat":
				var layer := part.get_surface_override_material(surface) as ShaderMaterial
				while layer:
					layer.set_shader_parameter(&"albedo", colour)
					layer = layer.next_pass as ShaderMaterial


func clear() -> void:
	for old in hounds:
		old.queue_free()
	hounds.clear()
	if player:
		player.queue_free()
		player = null
	pin = Vector3.INF
	look_h = 0.45


## The boy himself, for the hounds to hunt.
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
		at = (watch as Hound).visual_position + Vector3.UP * look_h
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
	var suffix := ("_ph" if breed == Hound.Breed.PHARAOH else "") + ("_lo" if Settings.low_poly else "")
	page.save_png(out.path_join(name + suffix + ".png"))
	cells.clear()
	print("SHEET ", name + suffix)


func wants(name: String) -> bool:
	return only.is_empty() or name in only


func run() -> void:
	deafen()
	await frames(5)
	for name: String in ["turnaround", "pair", "walk", "trot", "gallop", "bay", "bow", "play", "sit", "sleep", "look", "fur", "wake", "leap",
			"m_wag", "m_ears", "m_breath", "m_bark", "m_gallop", "m_stop", "m_struck", "m_shot", "m_flare"]:
		if wants(name):
			await call(name)
			clear()
			await frames(2)
	quit()


func turnaround() -> void:
	hound(Vector3(0, 0.05, 0), 0.0)
	await frames(60)
	look_h = 0.5
	for yaw: float in [0.0, 0.7, PI * 0.5, PI - 0.6, PI, -0.7, -PI * 0.5, 0.4]:
		view = Vector3(yaw, 0.35 if yaw == 0.4 else 0.08, 3.1)
		await frames(2)
		await snap()
	sheet("turnaround")
	# Close on the head
	var head: Vector3 = hounds[0]._rig._head.global_position
	for yaw: float in [0.0, 0.8, PI * 0.5, -PI * 0.5]:
		pin = head + Vector3(0, 0.0, 0.08)
		view = Vector3(yaw, 0.1, 1.25)
		await frames(2)
		await snap()
	sheet("head")


## The two breeds side by side.
func pair() -> void:
	var first := hound(Vector3(0, 0.05, 0.5), PI * 0.5, true, Hound.Breed.BLOODHOUND)
	hound(Vector3(0, 0.05, -0.5), PI * 0.5, true, Hound.Breed.PHARAOH)
	watch = first
	await frames(60)
	pin = Vector3(0, 0.5, 0)
	for shot: Vector3 in [Vector3(0.0, 0.06, 4.6), Vector3(0.7, 0.12, 4.6), Vector3(PI * 0.5, 0.1, 4.0), Vector3(PI - 0.7, 0.2, 4.6)]:
		view = shot
		await frames(2)
		await snap()
	sheet("pair")


## A side view of one stride, `count` pictures `every` frames apart, with the phase of the stride under each.
func strip(name: String, speed: float, every: int, count: int, distance := 3.0, also_front := true) -> void:
	var dog := hound(Vector3(-150, 0.05, 0))
	dog.bidden = Vector3(190, 0, 0)
	dog.bidden_speed = speed
	view = Vector3(0.0, 0.03, distance)
	await frames(150)
	var rig: HoundRig = dog._rig
	var line := ""
	var low := 9.0
	var high := 0.0
	for i in count:
		await frames(every)
		await snap()
		line += " %.2f" % rig._phase
		# (how far off the ground its lowest paw is)
		var lowest := 9.0
		for leg: Array in rig._legs:
			lowest = minf(lowest, (leg[3] as Node3D).global_position.y - rig._paw_height - dog.visual_position.y)
		low = minf(low, lowest)
		high = maxf(high, lowest)
	print("GAIT ", name, " speed=", snappedf(Vector2(dog.velocity.x, dog.velocity.z).length(), 0.01), " stride=", snappedf(HoundRig._keyed(HoundRig.STRIDE, rig._pace), 0.01),
			" lowest paw from ", snappedf(low, 0.001), " to ", snappedf(high, 0.001), " phases:", line)
	sheet(name, 4 if count <= 8 else 5)
	if also_front:
		view = Vector3(PI * 0.5 - 0.5, 0.15, distance)
		for i in 4:
			await frames(every * 2)
			await snap()
		view = Vector3(-PI * 0.5 + 0.6, 0.2, distance)
		for i in 4:
			await frames(every * 2)
			await snap()
		sheet(name + "_round")


func walk() -> void:
	await strip("walk", 1.0, 5, 8)


func trot() -> void:
	await strip("trot", 2.4, 3, 8)


func gallop() -> void:
	await strip("gallop", 5.4, 2, 10, 3.6)


## Every frame of a gallop stride and a bit.
func m_gallop() -> void:
	await strip("m_gallop", 5.4, 1, 24, 3.4, false)


## Close on the head while it bays, barks and snaps.
func bay() -> void:
	var dog := hound(Vector3(0, 0.05, 0))
	await frames(40)
	var rig: HoundRig = dog._rig
	pin = rig._head.global_position + Vector3(0.12, 0.0, 0.0)
	view = Vector3(0.5, 0.05, 1.3)
	for round in 3:
		if round == 0:
			rig._on_bayed(false)
		elif round == 1:
			rig._on_bayed(true)
		else:
			rig._snapped = 0.0
		for i in 8:
			await frames(6 if round == 0 else 2 if round == 1 else 3)
			await snap()
		await frames(30)
	sheet("bay", 8)
	# And from in front, mouth open
	rig._on_bayed(false)
	await frames(18)
	for yaw: float in [PI * 0.5, PI * 0.5 - 0.7, 0.9, -0.3]:
		view = Vector3(yaw, -0.12, 1.0)
		rig._voiced = 0.3
		await frames(1)
		rig._voiced = 0.3
		await snap()
	sheet("mouth")


## The boy up on something it cannot get onto: it braces under him and barks.
func bow() -> void:
	boy(Vector3(0, 2.15, -19.2))
	var dog := hound(Vector3(-7, 0.05, -15.5), 0.0, false)
	dog.target = player
	dog.chasing = true
	view = Vector3(0.9, 0.12, 4.2)
	look_h = 0.5
	var shots := 0
	var braced := 0
	var leaps := 0
	var arrived := -1
	var first := -1
	var was_up := false
	for i in 720:
		await frames(1)
		var up := not dog.is_on_floor()
		if up and not was_up:
			leaps += 1
		was_up = up
		if arrived < 0 and dog.global_position.distance_to(player.global_position) < 3.6:
			arrived = i
			leaps = 0
		if dog.posture == Hound.Posture.BOW:
			if first < 0:
				first = i
				print("BOW reached him at frame ", arrived, ", braced at frame ", first, " after ", leaps, " leaps")
			# The drop into it, and then the barking
			if braced % (3 if braced < 24 else 8) == 0 and shots < 16:
				await snap()
				shots += 1
			braced += 1
		if shots >= 16:
			break
	print("BOW shots=", shots, " hound at ", dog.global_position, " posture=", dog.posture, " boy at ", player.global_position)
	if not cells.is_empty():
		sheet("bow")
	# Held in it, from all round
	for i in 400:
		await frames(1)
		if dog.posture == Hound.Posture.BOW and absf(dog._rig._bow - dog.bow_depth) < 0.05 and dog._brace > 0.8:
			break
	print("BRACE pitch of its back ", snappedf(rad_to_deg(dog._rig._body.rotation.x), 0.1), " head ", snappedf(rad_to_deg(-asin(dog._rig._head.global_basis.z.y)), 0.1), " up")
	for yaw: float in [dog.facing_yaw + PI * 0.5, dog.facing_yaw + 0.6, dog.facing_yaw, dog.facing_yaw + PI - 0.7]:
		view = Vector3(yaw, 0.1, 3.0)
		await frames(1)
		await snap()
	sheet("brace_round")
	# And the bow it plays with, right down
	dog.chasing = false
	dog.target = null
	dog.bidden = Vector3.INF
	for i in 30:
		dog.posture = Hound.Posture.UP
		dog.set_physics_process(false)
		await frames(1)
	for i in 50:
		dog.posture = Hound.Posture.BOW
		dog.bow_depth = 1.0
		dog.playful = 1.0
		await frames(1)
	print("BOW pitch of its back ", snappedf(rad_to_deg(dog._rig._body.rotation.x), 0.1))
	for yaw: float in [dog.facing_yaw + PI * 0.5, dog.facing_yaw + 0.6, dog.facing_yaw, dog.facing_yaw + PI - 0.7]:
		view = Vector3(yaw, 0.1, 3.0)
		dog.posture = Hound.Posture.BOW
		await frames(1)
		await snap()
	sheet("bow_round")


## Two left to themselves.
func play() -> void:
	var first := hound(Vector3(-1.2, 0.05, 0), PI * 0.5, false, Hound.Breed.BLOODHOUND)
	hound(Vector3(1.2, 0.05, 0.4), -PI * 0.5, false, Hound.Breed.PHARAOH)
	watch = first
	pin = Vector3(0, 0.4, 0.2)
	view = Vector3(0.3, 0.3, 9.0)
	await frames(30)
	for i in 20:
		await frames(18)
		await snap()
	print("PLAY games: ", hounds[0]._game, " ", hounds[1]._game, " at ", hounds[0].global_position, " ", hounds[1].global_position)
	sheet("play", 5)


func sit() -> void:
	var dog := hound(Vector3(0, 0.05, 0), PI * 0.5, false)
	dog.play_time = 0.0
	dog._play_left = 0.0
	dog.settle_after = 0.5
	dog.sleep_after = 100000.0
	view = Vector3(0.0, 0.06, 2.9)
	await frames(26)
	# Going down
	for i in 8:
		await frames(6)
		await snap()
	sheet("sit_down")
	await frames(60)
	for yaw: float in [0.0, PI * 0.5 - 0.6, PI * 0.5, PI, -PI * 0.5 + 0.5, -0.6]:
		view = Vector3(yaw, 0.1, 2.9)
		await frames(2)
		await snap()
	sheet("sit", 3)


func sleep() -> void:
	var dog := hound(Vector3(0, 0.05, 0), PI * 0.5, false)
	dog.play_time = 0.0
	dog._play_left = 0.0
	dog.settle_after = 0.3
	dog.sleep_after = 1.6
	view = Vector3(0.0, 0.1, 2.9)
	look_h = 0.3
	await frames(110)
	# From sitting down onto its chest, and then its head goes down
	for i in 12:
		await frames(10)
		await snap()
	sheet("lie_down")
	await frames(200)
	for yaw: float in [0.0, PI * 0.5 - 0.6, PI * 0.5, PI, -PI * 0.5 + 0.5, 0.5]:
		view = Vector3(yaw, 0.55 if yaw == 0.5 else 0.14, 2.6)
		await frames(2)
		await snap()
	sheet("asleep", 3)


## Asleep, and then set on him.
func wake() -> void:
	boy(Vector3(9, 0.05, 0))
	var dog := hound(Vector3(0, 0.05, 0), PI * 0.5, false)
	dog.play_time = 0.0
	dog._play_left = 0.0
	dog.settle_after = 0.2
	dog.sleep_after = 0.4
	view = Vector3(0.3, 0.12, 4.5)
	await frames(330)
	dog.target = player
	dog.chasing = true
	for i in 12:
		await frames(3)
		await snap()
	sheet("wake")


## Something carried round it: its head should follow.
func look() -> void:
	var dog := hound(Vector3(0, 0.05, 0), 0.0)
	var thing := MeshInstance3D.new()
	var ball := SphereMesh.new()
	ball.radius = 0.1
	ball.height = 0.2
	thing.mesh = ball
	thing.add_to_group(&"interest")
	stage.add_child(thing)
	view = Vector3(0.0, 0.35, 4.0)
	pin = Vector3(0, 0.5, 0)
	for i in 12:
		var angle := -1.6 + i * 0.4
		for step in 30:
			var now := angle - 0.4 + 0.4 * (step + 1) / 30.0
			thing.position = Vector3(sin(now) * 1.8, 0.2 + 1.2 * maxf(sin(now * 1.3), 0.0), cos(now) * 1.8)
			await frames(1)
		await snap()
	print("LOOK ", dog._rig._look, " interest=", dog._rig._interest)
	sheet("look")
	thing.queue_free()


## The coat close to, with its shells and without.
func fur() -> void:
	for shells: int in [-1, 0]:
		var dog := hound(Vector3(0, 0.05, 0))
		if shells == 0:
			# (the rig is built by now: give it its coat again, bare)
			Fur.apply(dog._rig, &"coat", 0)
		await frames(40)
		var head: Vector3 = dog._rig._head.global_position - dog.visual_position
		for shot: Array in [[Vector3(0.0, 0.55, 0.0), Vector3(0.3, 0.1, 2.6)], [Vector3(0.05, 0.57, 0.0), Vector3(0.2, 0.15, 0.9)],
				[head + Vector3(0.0, -0.02, 0.0), Vector3(0.5, 0.1, 0.8)], [Vector3(-0.3, 0.65, 0.0), Vector3(-2.6, 0.5, 0.9)]]:
			pin = dog.visual_position + shot[0]
			view = shot[1]
			await frames(2)
			await snap()
		dog.queue_free()
		hounds.erase(dog)
		await frames(2)
	sheet("fur")


## Over a gap and up a step: the jump.
func leap() -> void:
	var dog := hound(Vector3(0, 0.05, 6))
	box(Vector3(6, 0.2, 6), Vector3(3, 0.4, 3), Color(0.36, 0.38, 0.41))
	boy(Vector3(14, 0.05, 6))
	dog.target = player
	dog.chasing = true
	view = Vector3(0.0, 0.08, 4.2)
	await frames(30)
	for i in 12:
		await frames(4)
		await snap()
	sheet("leap")


## The wag, every other frame, from behind and above.
func m_wag() -> void:
	var dog := hound(Vector3(0, 0.05, 0), PI * 0.5, false)
	dog.play_time = 0.0
	dog._play_left = 0.0
	dog.settle_after = 100000.0
	dog._pleased = 30.0
	view = Vector3(-PI * 0.5 + 0.45, 0.5, 2.6)
	look_h = 0.5
	await frames(90)
	var line := ""
	for i in 20:
		await frames(2)
		await snap()
		line += " %.2f" % (dog._rig._tail[3].tip - dog._rig._tail[0].joint.global_position).dot(dog._rig.global_basis.x)
	print("WAG tip off the middle (m), every 2 frames:", line)
	sheet("m_wag", 5)


## The ears. Hanging ones: a run, a dead stop, and a shake of the head, every other frame.
## Standing ones: at ease and listening, set on him, running flat out, and giving tongue.
func m_ears() -> void:
	if breed == Hound.Breed.PHARAOH:
		boy(Vector3(60, 0.05, 0))
		var dog := hound(Vector3(0, 0.05, 0), PI * 0.5, false)
		dog.play_time = 0.0
		dog._play_left = 0.0
		dog.settle_after = 100000.0
		var rig: HoundRig = dog._rig
		look_h = 0.8
		view = Vector3(PI * 0.5 - 0.5, 0.12, 1.6)
		await frames(40)
		# Listening: every 6 frames over three seconds
		for i in 10:
			await frames(18)
			await snap()
		# Set on him: the ears come up and forward, then go back as it gets into its run
		dog.target = player
		dog.chasing = true
		for i in 10:
			await frames(4)
			await snap()
		sheet("m_ears", 5)
		print("EARS flat=", snappedf(rig._ear_flat, 0.01), " alert=", snappedf(rig._alert, 0.01))
		return
	var dog := hound(Vector3(-20, 0.05, 0))
	dog.bidden = Vector3(0, 0, 0)
	dog.bidden_speed = 5.4
	look_h = 0.6
	view = Vector3(0.5, 0.1, 3.0)
	for i in 400:
		await frames(1)
		if dog.global_position.x > -1.6:
			break
	for i in 20:
		await frames(2)
		await snap()
	sheet("m_ears", 5)


## Breathing: asleep, every quarter of a second over one breath; and panting, every other frame.
func m_breath() -> void:
	var dog := hound(Vector3(0, 0.05, 0), PI * 0.5, false)
	dog.play_time = 0.0
	dog._play_left = 0.0
	dog.settle_after = 0.1
	dog.sleep_after = 0.3
	await frames(420)
	view = Vector3(0.5, 0.75, 2.0)
	look_h = 0.2
	var line := ""
	for i in 10:
		await frames(24)
		await snap()
		line += " %.3f" % dog._rig._chest.scale.x
	print("BREATH asleep, chest every 0.4 s:", line)
	sheet("m_breath_asleep", 5)
	clear()
	await frames(2)
	dog = hound(Vector3(0, 0.05, 0))
	dog._rig._puffed = 1.0
	view = Vector3(0.7, 0.1, 1.9)
	look_h = 0.55
	await frames(30)
	line = ""
	for i in 10:
		dog._rig._puffed = 1.0
		await frames(2)
		await snap()
		line += " %.3f/%.2f" % [dog._rig._chest.scale.x, dog._rig.jaw_open()]
	print("BREATH panting, chest/jaw every 2 frames:", line)
	sheet("m_breath_panting", 5)


## How loud a hound's voice is `at` seconds into it, 0..1.
func loudness(stream: AudioStreamWAV, at: float) -> float:
	var from := int(at * stream.mix_rate)
	var peak := 0.0
	for i in range(from, mini(from + stream.mix_rate / 60, stream.data.size() / 2)):
		peak = maxf(peak, absf(stream.data.decode_s16(i * 2) / 32767.0))
	return peak


## A bark and a bay, every frame, with how loud the voice is and how far open the jaw under each.
func m_bark() -> void:
	var dog := hound(Vector3(0, 0.05, 0))
	await frames(40)
	var rig: HoundRig = dog._rig
	pin = rig._head.global_position + Vector3(0.0, -0.02, 0.1)
	view = Vector3(0.25, 0.02, 1.15)
	for bark: bool in [true, false]:
		dog._held = bark
		if bark:
			dog._yap()
		else:
			dog.target = null
			dog._bay()
		dog._bay_timer = 100.0
		var stream := dog._voice.stream as AudioStreamWAV
		var line := ""
		var worst := 0.0
		for i in (14 if bark else 20):
			await frames(1 if bark else 3)
			await snap()
			var played := dog._voice.get_playback_position() if dog._voice.playing else 9.0
			var since := (i + 1) * (1 if bark else 3) / 60.0
			var loud := loudness(stream, since * dog.voice_rate)
			line += " %.2f:%.2f" % [loud, rig.jaw_open()]
			# (open with no sound, or sound through a shut mouth)
			if (loud > 0.25 and rig.jaw_open() < 0.15) or (loud < 0.02 and rig.jaw_open() > 0.5):
				worst = maxf(worst, since)
			if i == 2:
				print("VOICE playing=", dog._voice.playing, " at ", snappedf(played, 0.001), " s by the player's clock, ", snappedf(since, 0.001), " by the frames, rate ", snappedf(dog.voice_rate, 0.01))
		print("VOICE ", "bark" if bark else "bay", " loudness:jaw each ", 1 if bark else 3, " frame(s):", line, "  out of step at ", worst)
		sheet("m_bark" if bark else "m_bay", 7 if bark else 5)
		await frames(40)


## Flat out and then a dead stop: what the tail, the ears and the loose skin do, every other frame.
func m_stop() -> void:
	var dog := hound(Vector3(-20, 0.05, 0))
	dog.bidden = Vector3(0, 0, 0)
	dog.bidden_speed = 5.4
	look_h = 0.5
	view = Vector3(0.0, 0.06, 3.4)
	for i in 400:
		await frames(1)
		if dog.global_position.x > -1.9:
			break
	for i in 20:
		await frames(2)
		await snap()
	sheet("m_stop", 5)


## Something for a hound to be hit by, standing where the blow comes from.
func attacker(at: Vector3) -> Node3D:
	var made := Node3D.new()
	stage.add_child(made)
	made.position = at
	return made


## Punched from its left while it stands: every other frame through the yelp, the cringe and the recovery.
func m_struck() -> void:
	var dog := hound(Vector3(0, 0.05, 0))
	var by := attacker(Vector3(0, 0.5, 1.5))
	view = Vector3(0.5, 0.12, 3.6)
	await frames(60)
	dog.struck(by, Vector3(0, 0, -25.0))
	for i in 15:
		await frames(1 if i < 5 else 3)
		await snap()
	print("STRUCK flinch left ", snappedf(dog._flinch, 0.01), " wary ", snappedf(dog._wary, 0.01), " moved to ", dog.global_position)
	sheet("m_struck", 5)
	by.queue_free()


## Chasing him, shot three times: the stagger each time, and then its nerve goes and it runs.
func m_shot() -> void:
	boy(Vector3(9, 0.05, 0))
	var dog := hound(Vector3(0, 0.05, 0), PI * 0.5, false)
	dog.target = player
	dog.chasing = true
	dog.nerve = 60.0
	view = Vector3(0.25, 0.12, 5.2)
	await frames(40)
	for round in 3:
		dog.shot(player, dog.global_position + Vector3.UP * 0.5, Vector3(-1, 0, 0), 25.0)
		print("SHOT ", round + 1, " harm ", dog._harm, " cowed for ", snappedf(dog._cowed_for, 0.1))
		for i in 5:
			await frames(2 if i < 3 else 6)
			await snap()
		await frames(20 if round < 2 else 0)
	for i in 5:
		await frames(12)
		await snap()
	print("SHOT fled to ", dog.global_position, " afraid ", snappedf(dog.afraid, 0.01), " boy at ", player.global_position)
	sheet("m_shot", 5)


## A flare burning between it and him: it will not come past.
func m_flare() -> void:
	boy(Vector3(8, 0.05, 0))
	var dog := hound(Vector3(-6, 0.05, 0), PI * 0.5, false)
	var flare := MeshInstance3D.new()
	var ball := SphereMesh.new()
	ball.radius = 0.08
	ball.height = 0.16
	flare.mesh = ball
	var glow := StandardMaterial3D.new()
	glow.albedo_color = Color(1.0, 0.3, 0.2)
	glow.emission_enabled = true
	glow.emission = Color(1.0, 0.3, 0.2)
	flare.material_override = glow
	flare.add_to_group(&"flares")
	stage.add_child(flare)
	flare.position = Vector3(2.5, 0.1, 0.3)
	dog.target = player
	dog.chasing = true
	pin = Vector3(0.5, 0.4, 0)
	view = Vector3(0.0, 0.25, 11.0)
	var nearest := 99.0
	for i in 15:
		await frames(10)
		await snap()
		nearest = minf(nearest, dog.global_position.distance_to(flare.position))
	print("FLARE nearest it came ", snappedf(nearest, 0.01), " m; ended at ", dog.global_position, " afraid ", snappedf(dog.afraid, 0.01))
	sheet("m_flare", 5)
	flare.queue_free()
