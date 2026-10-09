extends SceneTree
## Not part of the game. A test stage for the cat: drives one through each thing it does and saves
## contact sheets of what the rig makes of it, as hound_sheets.gd does for the hounds.
## godot --path . --fixed-fps 60 --resolution 960x960 --script tools/cat_sheets.gd -- <outdir> [scenario ...]
## Among the names: a coat (`bronze` `silver` `black` `ruddy` `tabby` `ginger`; the last two are the
## heavier cat), `lo` for the demade models.
## The scenarios whose names begin `m_` are strips of consecutive frames, for watching how a thing moves.

const CELL := 480
const COATS: Array[String] = ["bronze", "silver", "black", "ruddy", "tabby", "ginger"]
var out := ""
var only: Array = []
var stage: Node3D
var cam: Camera3D
var cells: Array[Image] = []
var cats: Array[Cat] = []
var extras: Array[Node] = []
var player: Player
var coat := Cat.Coat.BRONZE
var tag := ""
## What the camera watches, from where: (yaw round it, pitch, distance), and how high up it.
var watch: Cat
var view := Vector3(PI * 0.5, 0.05, 1.7)
var look_h := 0.2
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
		tag += "_lo"
	for i in COATS.size():
		if COATS[i] in only:
			only.erase(COATS[i])
			coat = i as Cat.Coat
			tag = "_" + COATS[i] + tag
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
	# Something to get up onto: its top at 1.2, and a higher one at 1.5
	box(Vector3(0, 0.6, -20), Vector3(2, 1.2, 2), Color(0.36, 0.38, 0.41))
	box(Vector3(20, 0.75, -20), Vector3(2, 1.5, 2), Color(0.36, 0.38, 0.41))
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


## A fresh cat, standing where it is put and doing nothing of its own accord.
func cat(at: Vector3, yaw := PI * 0.5, manual := true, which := -1) -> Cat:
	var made := Cat.new()
	made.coat = coat if which < 0 else which as Cat.Coat
	made.position = at
	made.rotation.y = yaw
	made.manual = manual
	made.voice = false
	stage.add_child(made)
	made.facing_yaw = yaw
	cats.append(made)
	watch = made
	return made


func clear() -> void:
	for old in cats:
		old.queue_free()
	cats.clear()
	for old in extras:
		old.queue_free()
	extras.clear()
	if player:
		player.queue_free()
		player = null
	pin = Vector3.INF
	look_h = 0.2


## The boy himself, standing exactly where he is put.
func boy(at: Vector3) -> void:
	var touch := TouchControls.new()
	touch.visible = false
	stage.add_child(touch)
	extras.append(touch)
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
		at = watch.visual_position + Vector3.UP * look_h
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
	page.save_png(out.path_join(name + tag + ".png"))
	cells.clear()
	print("SHEET ", name + tag)


func wants(name: String) -> bool:
	return only.is_empty() or name in only


func run() -> void:
	deafen()
	await frames(5)
	for name: String in ["turnaround", "coats", "walk", "trot", "bound", "stalk", "sit", "loaf", "side", "curl", "wake", "groom", "tails", "look",
			"rub", "fur", "flee", "m_walk", "m_bound", "m_pounce", "m_up", "m_down", "m_lash", "m_blink", "m_ears"]:
		if wants(name):
			await call(name)
			clear()
			await frames(2)
	quit()


func turnaround() -> void:
	cat(Vector3(0, 0.02, 0), 0.0)
	await frames(60)
	for yaw: float in [0.0, 0.7, PI * 0.5, PI - 0.6, PI, -0.7, -PI * 0.5, 0.4]:
		view = Vector3(yaw, 0.5 if yaw == 0.4 else 0.08, 1.7)
		await frames(2)
		await snap()
	sheet("turnaround")
	var head: Vector3 = cats[0]._rig._head.global_position
	for yaw: float in [0.0, 0.8, PI * 0.5, -PI * 0.5]:
		pin = head + Vector3(0, 0.02, 0.03)
		view = Vector3(yaw, 0.1, 0.6)
		await frames(2)
		await snap()
	sheet("head")


## Every coat, from the side and from in front and above.
func coats() -> void:
	for i in COATS.size():
		cat(Vector3(0, 0.02, 0), PI * 0.5, true, i)
		await frames(30)
		view = Vector3(0.5, 0.3, 1.6)
		await snap()
		clear()
		await frames(2)
	sheet("coats", 3)


## A side view of one stride, `count` pictures `every` frames apart, with the phase of the stride under each.
func strip(name: String, speed: float, every: int, count: int, distance := 1.7, also_front := true, creep := false) -> void:
	var puss := cat(Vector3(-150, 0.02, 0))
	puss.bidden = Vector3(190, 0, 0)
	puss.bidden_speed = speed
	puss.creep = creep
	if creep:
		puss.mood = Cat.Mood.HUNTING
	view = Vector3(0.0, 0.04, distance)
	await frames(60)
	var rig: CatRig = puss._rig
	var line := ""
	var low := 9.0
	var high := 0.0
	# Where each paw last came down, to see whether the hind goes into the print of the fore.
	var prints: Array[float] = [0.0, 0.0, 0.0, 0.0]
	var was_up: Array[bool] = [false, false, false, false]
	var misses := ""
	for i in 90 + count * every:
		await frames(1)
		for leg in 4:
			var paw: Vector3 = (rig._legs[leg][3] as Node3D).global_position
			var up := paw.y - puss.visual_position.y > rig._paw_height + 0.003
			if was_up[leg] and not up:
				prints[leg] = paw.x
				if leg >= 2 and prints[leg - 2] != 0.0:
					misses += " %.3f" % (paw.x - prints[leg - 2])
			was_up[leg] = up
		if i >= 90 and (i - 90) % every == every - 1:
			await snap()
			line += " %.2f" % rig._phase
			var lowest := 9.0
			for leg: Array in rig._legs:
				lowest = minf(lowest, (leg[3] as Node3D).global_position.y - rig._paw_height - puss.visual_position.y)
			low = minf(low, lowest)
			high = maxf(high, lowest)
	print("GAIT ", name, " speed=", snappedf(Vector2(puss.velocity.x, puss.velocity.z).length(), 0.01), " stride=", snappedf(CatRig._keyed(CatRig.PACES, rig._pace), 0.01),
			" lowest paw from ", snappedf(low, 0.001), " to ", snappedf(high, 0.001), " phases:", line)
	print("PRINTS ", name, " hind paw lands ahead of the last fore print of its side by (m):", misses)
	sheet(name, 4 if count <= 8 else 5 if count <= 20 else 6)
	if also_front:
		view = Vector3(PI * 0.5 - 0.45, 0.2, distance)
		for i in 4:
			await frames(every * 2)
			await snap()
		view = Vector3(-PI * 0.5 + 0.5, 0.5, distance)
		for i in 4:
			await frames(every * 2)
			await snap()
		sheet(name + "_round")


func walk() -> void:
	await strip("walk", 0.7, 5, 8)


func trot() -> void:
	await strip("trot", 1.7, 3, 8)


func bound() -> void:
	await strip("bound", 6.2, 2, 10, 2.1)


func stalk() -> void:
	await strip("stalk", 0.3, 8, 8, 1.5, true, true)


## Every other frame of a walking stride and a bit.
func m_walk() -> void:
	await strip("m_walk", 0.7, 2, 24, 1.6, false)


## Every frame of a bounding stride and a bit.
func m_bound() -> void:
	await strip("m_bound", 6.2, 1, 18, 2.0, false)


## Sets a cat doing something, from the stage.
func bid(puss: Cat, act: Cat.Act) -> void:
	puss.act = act


func sit() -> void:
	var puss := cat(Vector3(0, 0.02, 0))
	view = Vector3(0.0, 0.06, 1.6)
	await frames(40)
	puss.posture = Cat.Posture.SIT
	for i in 8:
		await frames(6)
		await snap()
	sheet("sit_down")
	await frames(90)
	for yaw: float in [0.0, PI * 0.5 - 0.6, PI * 0.5, PI, -PI * 0.5 + 0.5, -0.6]:
		view = Vector3(yaw, 0.12, 1.6)
		await frames(2)
		await snap()
	sheet("sit", 3)


func resting(name: String, posture: Cat.Posture, asleep := false) -> void:
	var puss := cat(Vector3(0, 0.02, 0))
	view = Vector3(0.0, 0.1, 1.6)
	look_h = 0.12
	await frames(40)
	puss.posture = posture
	puss.asleep = asleep
	for i in 6:
		await frames(15)
		await snap()
	await frames(120)
	for yaw: float in [0.0, PI * 0.5 - 0.6, PI * 0.5, PI, -PI * 0.5 + 0.5, 0.5]:
		view = Vector3(yaw, 0.9 if yaw == 0.5 else 0.16, 1.5)
		await frames(2)
		await snap()
	sheet(name, 6)


func loaf() -> void:
	await resting("loaf", Cat.Posture.LOAF)


func side() -> void:
	await resting("side", Cat.Posture.SIDE, true)


func curl() -> void:
	await resting("curl", Cat.Posture.CURL, true)


## Asleep, and then up: the yawn, the long stretch, the arched back.
func wake() -> void:
	var puss := cat(Vector3(0, 0.02, 0))
	view = Vector3(0.25, 0.1, 1.7)
	puss.posture = Cat.Posture.CURL
	puss.asleep = true
	await frames(200)
	puss.posture = Cat.Posture.UP
	puss.asleep = false
	for i in 4:
		await frames(12)
		await snap()
	for act: Cat.Act in [Cat.Act.YAWN, Cat.Act.STRETCH_BOW, Cat.Act.STRETCH_ARCH]:
		puss.act = act
		var length: float = CatRig.ACT_TIMES[act]
		for i in 4:
			await frames(int(length * 60.0 / 4.0))
			await snap()
		puss.act = Cat.Act.NONE
		await frames(20)
	sheet("wake")
	# The two stretches held, from round it
	for act: Cat.Act in [Cat.Act.STRETCH_BOW, Cat.Act.STRETCH_ARCH]:
		puss.act = act
		await frames(70)
		for yaw: float in [0.0, 0.8, PI * 0.5, PI - 0.7]:
			view = Vector3(yaw, 0.12, 1.7)
			await frames(1)
			await snap()
		puss.act = Cat.Act.NONE
		await frames(60)
	sheet("stretches")


func groom() -> void:
	var puss := cat(Vector3(0, 0.02, 0))
	view = Vector3(PI * 0.5 - 0.7, 0.12, 1.3)
	look_h = 0.24
	puss.posture = Cat.Posture.SIT
	await frames(90)
	puss.act = Cat.Act.GROOM
	for i in 20:
		await frames(20)
		await snap()
	sheet("groom", 5)


## What its tail says: at ease, friendly, cross, afraid; standing and sitting.
func tails() -> void:
	var puss := cat(Vector3(0, 0.02, 0))
	for sitting: bool in [false, true]:
		puss.posture = Cat.Posture.SIT if sitting else Cat.Posture.UP
		for mood: Cat.Mood in [Cat.Mood.CALM, Cat.Mood.FRIENDLY, Cat.Mood.ANNOYED, Cat.Mood.FRIGHTENED]:
			puss.mood = mood
			await frames(110)
			view = Vector3(-0.5, 0.15, 1.9)
			await snap()
			view = Vector3(-PI * 0.5 + 0.5, 0.3, 1.9)
			await frames(1)
			await snap()
	sheet("tails", 4)


## The lash of a cross cat's tail, every third frame, from behind and above.
func m_lash() -> void:
	var puss := cat(Vector3(0, 0.02, 0))
	puss.mood = Cat.Mood.ANNOYED
	view = Vector3(-PI * 0.5 + 0.4, 0.6, 1.9)
	await frames(120)
	for i in 20:
		await frames(3)
		await snap()
	sheet("m_lash", 5)


## Something carried round it: its head should go to it and stay on it.
func look() -> void:
	var puss := cat(Vector3(0, 0.02, 0), 0.0)
	var thing := MeshInstance3D.new()
	var ball := SphereMesh.new()
	ball.radius = 0.05
	ball.height = 0.1
	thing.mesh = ball
	stage.add_child(thing)
	extras.append(thing)
	puss.gaze = thing
	puss.posture = Cat.Posture.SIT
	view = Vector3(0.0, 0.4, 2.2)
	pin = Vector3(0, 0.25, 0)
	for i in 12:
		var angle := -1.6 + i * 0.4
		for step in 30:
			var now := angle - 0.4 + 0.4 * (step + 1) / 30.0
			thing.position = Vector3(sin(now) * 0.9, 0.1 + 0.6 * maxf(sin(now * 1.3), 0.0), cos(now) * 0.9)
			await frames(1)
		await snap()
	sheet("look")


## Close on its face: the slow blink, every fifth frame; then its pupils and whiskers, hunting and afraid.
func m_blink() -> void:
	var puss := cat(Vector3(0, 0.02, 0), 0.0)
	puss.posture = Cat.Posture.SIT
	puss.content = 1.0
	await frames(90)
	var rig: CatRig = puss._rig
	pin = rig._head.global_position + Vector3(0, 0.02, 0.03)
	view = Vector3(0.35, 0.05, 0.5)
	rig._blink = 0.0
	rig._blink_length = 1.5
	rig._blink_timer = 9.0
	for i in 12:
		await frames(8)
		await snap()
	puss.content = 0.0
	for mood: Cat.Mood in [Cat.Mood.CALM, Cat.Mood.HUNTING, Cat.Mood.ANNOYED, Cat.Mood.FRIGHTENED]:
		puss.mood = mood
		rig._blink_timer = 9.0
		await frames(70)
		await snap()
	sheet("m_blink", 4)


## A sound carried round behind it: its ears go to it, its head does not.
func m_ears() -> void:
	var puss := cat(Vector3(0, 0.02, 0), 0.0)
	puss.posture = Cat.Posture.SIT
	await frames(90)
	var rig: CatRig = puss._rig
	pin = rig._head.global_position + Vector3(0, 0.03, 0.0)
	view = Vector3(0.0, 0.35, 0.7)
	for i in 12:
		var angle := i * TAU / 12.0
		for step in 20:
			puss.hear(Vector3(sin(angle) * 3.0, 0.3, cos(angle) * 3.0))
			await frames(1)
		await snap()
	sheet("m_ears")


## Belly down, the wiggle, and the spring: every third frame.
func m_pounce() -> void:
	var puss := cat(Vector3(0, 0.02, 0))
	puss.creep = true
	puss.mood = Cat.Mood.HUNTING
	puss.gaze_at = Vector3(1.3, 0.0, 0.0)
	view = Vector3(0.0, 0.06, 3.3)
	pin = Vector3(0.6, 0.25, 0.0)
	await frames(60)
	puss.act = Cat.Act.WIGGLE
	for i in 10:
		await frames(6)
		await snap()
	puss.leap(Vector3(1.2, 0.02, 0.0), 0.16, true)
	for i in 14:
		await frames(2)
		await snap()
	sheet("m_pounce", 6)


## Up onto something 1.2 m high: gathering itself, the spring, and landing. Every third frame.
func m_up() -> void:
	var puss := cat(Vector3(-0.3, 0.02, -18.45), PI)
	view = Vector3(PI * 0.5, 0.05, 3.6)
	pin = Vector3(0, 0.85, -18.9)
	puss.gaze_at = Vector3(-0.3, 1.2, -19.3)
	await frames(60)
	puss.act = Cat.Act.GATHER
	for i in 6:
		await frames(5)
		await snap()
	await frames(3)
	puss.leap(Vector3(-0.3, 1.2, -19.32), 0.14)
	for i in 18:
		await frames(2)
		await snap()
	sheet("m_up", 6)
	print("UP at ", puss.global_position, " grounded=", puss.grounded)


## And down off it again: reaching down the face of it, off, and landing fore feet first.
func m_down() -> void:
	var puss := cat(Vector3(-0.3, 1.22, -19.14), 0.0)
	view = Vector3(PI * 0.5, 0.05, 3.6)
	pin = Vector3(0, 0.75, -18.7)
	puss.gaze_at = Vector3(-0.3, 0.0, -18.2)
	await frames(60)
	puss.act = Cat.Act.REACH
	for i in 6:
		await frames(7)
		await snap()
	puss.leap(Vector3(-0.3, 0.0, -18.2), 0.03)
	for i in 18:
		await frames(2)
		await snap()
	sheet("m_down", 6)


## Round the boy's legs.
func rub() -> void:
	boy(Vector3(0, 0.05, 0))
	var puss := cat(Vector3(-2.0, 0.02, 0.3), PI * 0.5, false)
	puss.target = player
	puss.tame = 1.0
	puss.nap_after = 10000.0
	puss._set_state(Cat.State.RUB)
	puss._still = 10.0
	view = Vector3(0.5, 0.25, 3.4)
	pin = Vector3(0, 0.35, 0)
	await frames(60)
	for i in 20:
		await frames(24)
		puss._still = 10.0
		await snap()
	print("RUB state=", puss.state, " step=", puss._step, " rub=", snappedf(puss.rub, 0.01), " at ", puss.global_position)
	sheet("rub", 5)


## The coat close to.
func fur() -> void:
	var puss := cat(Vector3(0, 0.02, 0))
	await frames(40)
	var head: Vector3 = puss._rig._head.global_position
	for shot: Array in [[Vector3(0.0, 0.2, 0.0), Vector3(0.3, 0.1, 1.2)], [Vector3(0.0, 0.24, 0.0), Vector3(0.2, 0.2, 0.5)],
			[head, Vector3(0.6, 0.1, 0.4)], [Vector3(-0.3, 0.2, 0.0), Vector3(-2.4, 0.4, 0.6)]]:
		pin = shot[0]
		view = shot[1]
		await frames(2)
		await snap()
	puss.mood = Cat.Mood.FRIGHTENED
	await frames(60)
	for shot: Array in [[Vector3(0.0, 0.25, 0.0), Vector3(0.3, 0.1, 1.5)], [Vector3(0.0, 0.25, 0.0), Vector3(PI * 0.5 - 0.3, 0.2, 1.5)],
			[Vector3(-0.3, 0.35, 0.0), Vector3(-0.4, 0.2, 0.7)], [puss._rig._head.global_position, Vector3(0.9, 0.1, 0.45)]]:
		pin = shot[0]
		view = shot[1]
		await frames(2)
		await snap()
	sheet("fur")


## A hound walked at it: it should bolt for the block, go up it, and sit there.
func flee() -> void:
	var puss := cat(Vector3(23.5, 0.02, -15.5), 0.0, false)
	puss.nap_after = 10000.0
	var dog := Hound.new()
	dog.position = Vector3(32, 0.05, -14)
	dog.play_time = 0.0
	dog.settle_after = 100000.0
	stage.add_child(dog)
	extras.append(dog)
	dog.bidden = Vector3(22.5, 0, -17.2)
	dog.bidden_speed = 2.4
	view = Vector3(0.5, 0.3, 11.0)
	pin = Vector3(22.5, 0.7, -17.5)
	await frames(30)
	for i in 20:
		await frames(18)
		await snap()
	print("FLEE state=", puss.state, " at ", puss.global_position, " perch=", puss._perch, " posture=", puss.posture)
	sheet("flee", 5)
