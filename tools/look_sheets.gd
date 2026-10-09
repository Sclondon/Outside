extends SceneTree
## Not part of the game. Shows every way the boy's model can be turned out
## (scripts/character_look.gd) and saves contact sheets of it, to check a new
## face, cut of hair or set of clothes without playing.
##
## godot --path . --fixed-fps 60 --resolution 1280x720 --script tools/look_sheets.gd -- <outdir> [faces hair outfits skin random crowd menu] [lo]
##
## With no names, all of them; `lo` among the names uses the demade model.
##   faces    every face close up, from in front, three-quarters and the side
##   hair     every cut from four sides, bareheaded and under a cap
##   outfits  every set of clothes standing (front and back) and at a run
##   skin     the skins and hair colours
##   random   twenty-four people made up at random, each as a Townsperson
##   crowd    a dozen of them left to stroll about for a while
##   menu     the game's menu with the dresser open
## Its window is kept off the screen and takes no input.

const CELL := 360

var out := ""
var only: Array = []
var stage: Node3D
var figure: Figure
var cam: Camera3D
var cells: Array[Image] = []
## Yaw round the figure (0: from straight in front), pitch, distance, and the height looked at.
var view := Vector4(0.0, 0.08, 3.6, 0.65)
var watched: Node3D


func _initialize() -> void:
	DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_NO_FOCUS, true)
	DisplayServer.window_set_position(Vector2i(-6000, -6000))
	# (nothing here is steered, and a gamepad in use elsewhere must not reach it)
	for action: StringName in InputMap.get_actions():
		if not String(action).begins_with("ui_"):
			InputMap.action_erase_events(action)
	var args := OS.get_cmdline_user_args()
	if args.is_empty():
		printerr("usage: -- <outdir> [faces hair outfits skin random crowd menu] [lo]")
		quit(1)
		return
	out = args[0]
	only = Array(args.slice(1))
	if only.has("lo"):
		only.erase("lo")
		Settings.low_poly = true
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
	sun.rotation_degrees = Vector3(-42.0, -32.0, 0.0)
	sun.light_color = Color(1.0, 0.96, 0.9)
	sun.light_energy = 1.2
	sun.shadow_enabled = true
	stage.add_child(sun)
	var ground := StaticBody3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(600, 2, 600)
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

	figure = Figure.new()
	figure.position = Vector3(0, 0.02, 0)
	stage.add_child(figure)
	watched = figure
	cam = Camera3D.new()
	cam.fov = 30.0
	stage.add_child(cam)
	cam.make_current()
	run.call_deferred()


func wants(name: String) -> bool:
	return only.is_empty() or only.has(name)


func aim() -> void:
	var at: Vector3 = watched.get("visual_position") if watched is Figure else watched.global_position
	var yaw: float = (watched.get("facing_yaw") if watched is Figure else 0.0) + view.x
	var away := Vector3(sin(yaw) * cos(view.y), sin(view.y), cos(yaw) * cos(view.y))
	var watch := at + Vector3.UP * view.w
	cam.global_position = watch + away * view.z
	cam.look_at(watch)


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


func sheet(name: String, columns: int) -> void:
	var rows := ceili(cells.size() / float(columns))
	var page := Image.create(CELL * columns, CELL * rows, false, cells[0].get_format())
	for i in cells.size():
		page.blit_rect(cells[i], Rect2i(0, 0, CELL, CELL), Vector2i((i % columns) * CELL, (i / columns) * CELL))
	var file := out.path_join("%s%s.png" % [name, "_lo" if Settings.low_poly else ""])
	page.save_png(file)
	cells.clear()
	print("SHEET ", file)


func wear(look: Dictionary) -> void:
	CharacterLook.apply(figure.rig, look)


func run() -> void:
	await frames(40)
	for name: String in ["faces", "hair", "outfits", "skin", "random", "crowd", "menu"]:
		if wants(name):
			await call(name)
	quit()


func faces() -> void:
	var rows: Array = CharacterLook.FACES.map(func(entry: Array) -> Dictionary: return {"face": entry[0], "hair": "crop", "cap": false})
	# (and as he will most often be seen: under his cap and his own curls)
	rows.append({"face": "full", "hair": "mullet", "cap": true})
	rows.append({"face": "dots", "hair": "mullet", "cap": true})
	for look: Dictionary in rows:
		wear(look)
		for yaw: float in [0.0, 0.75, PI * 0.5]:
			view = Vector4(yaw, 0.04, 1.0, 1.1)
			await frames(2)
			await snap()
	sheet("faces", 6)


func hair() -> void:
	var count := 0
	for cut: Dictionary in CharacterLook.HAIRS:
		for capped: bool in [false, true]:
			wear({"face": "full", "hair": cut["name"], "cap": capped, "outfit": "dress" if cut["sex"] == CharacterLook.Sex.FEMALE else "overalls"})
			for yaw: float in [0.5, PI * 0.5, PI, -2.3]:
				view = Vector4(yaw, 0.1, 1.45, 1.06)
				await frames(2)
				await snap()
		count += 1
		if count % 2 == 0:
			sheet("hair_%d" % (count / 2), 4)


func outfits() -> void:
	var count := 0
	var cuts := ["mullet", "crop", "parting", "curls", "long", "parting", "bob", "plaits", "ponytail"]
	for worn: Dictionary in CharacterLook.OUTFITS:
		wear({"face": "full", "hair": cuts[count % cuts.size()], "cap": count % 3 == 0, "outfit": worn["name"]})
		figure.place(Vector3(0, 0.02, 0), 0.0)
		await frames(30)
		for yaw: float in [0.4, PI - 0.5]:
			view = Vector4(yaw, 0.08, 3.4, 0.62)
			await frames(2)
			await snap()
		# At a run: from the side, and a stride later from in front
		figure.place(Vector3(0, 0.02, 0), PI * 0.5)
		figure.go_to(Vector3(500, 0, 0), true)
		view = Vector4(PI * 0.5, 0.05, 3.4, 0.62)
		await frames(90)
		await snap()
		view = Vector4(0.55, 0.1, 3.4, 0.62)
		await frames(9)
		await snap()
		view = Vector4(PI - 0.6, 0.12, 3.4, 0.62)
		await frames(7)
		await snap()
		figure.stop()
		count += 1
		if count % 3 == 0:
			sheet("outfits_%d" % (count / 3), 5)
	figure.place(Vector3(0, 0.02, 0), 0.0)


func skin() -> void:
	var cuts := ["crop", "curls", "parting", "bob", "plaits", "long", "ponytail", "mullet", "curls", "bob"]
	for i in 10:
		var tone: Color = CharacterLook.SKINS[i % CharacterLook.SKINS.size()]
		wear({"face": "full", "hair": cuts[i], "cap": false, "outfit": "skirt" if i % 2 == 1 else "trousers", "colours": {"skin": tone, "hair": CharacterLook.HAIR_COLOURS[i]}})
		view = Vector4(0.45, 0.05, 1.7, 0.98)
		await frames(3)
		await snap()
	sheet("skin", 5)


func random() -> void:
	figure.visible = false
	figure.rig.visible = false
	for i in 24:
		var someone := Townsperson.new()
		someone.seed = i + 1
		someone.wander = 0.0
		someone.position = Vector3(20, 0.02, 0)
		stage.add_child(someone)
		watched = someone
		view = Vector4(0.45, 0.06, 4.3, 0.92)
		await frames(40)
		await snap()
		print("RANDOM ", i + 1, ": ", someone.look["outfit"], ", ", someone.look["hair"], ", face ", someone.look["face"], ", cap " if someone.look["cap"] else ", bare", ", size ", snappedf(someone.look["size"], 0.01))
		watched = figure
		someone.queue_free()
		await frames(1)
	sheet("random", 6)
	figure.visible = true
	figure.rig.visible = true


func crowd() -> void:
	figure.rig.visible = false
	var people: Array[Townsperson] = []
	var starts: Array[Vector3] = []
	for i in 12:
		var someone := Townsperson.new()
		someone.seed = 100 + i
		someone.linger = Vector2(0.5, 3.0)
		someone.position = Vector3(40 + (i % 4) * 2.2 - 3.3, 0.02, (i / 4) * 2.4 - 2.4)
		stage.add_child(someone)
		people.append(someone)
		starts.append(someone.position)
	var middle := Node3D.new()
	middle.position = Vector3(40, 0, 0)
	stage.add_child(middle)
	watched = middle
	for i in 3:
		view = Vector4(0.5, 0.3, 15.0, 0.8)
		await frames(200)
		await snap()
	var moved := 0
	for i in people.size():
		if people[i].position.distance_to(starts[i]) > 0.3:
			moved += 1
		people[i].queue_free()
	print("CROWD ", moved, " of ", people.size(), " have strolled off from where they were put")
	sheet("crowd", 3)
	watched = figure
	figure.rig.visible = true


## The menu as the game has it, opened at the dresser: the whole window, not a cell.
func menu() -> void:
	Settings.undress()
	figure.rig.look = {}
	figure.rig.restyle()
	figure.place(Vector3(0, 0.02, 0), 0.0)
	var layer := CanvasLayer.new()
	root.add_child(layer)
	var made := GameMenu.new()
	made.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	layer.add_child(made)
	# (he stands to the right of the panel, as he does in the game's side view)
	var aside := Node3D.new()
	aside.position = Vector3(-0.45, 0, 0)
	stage.add_child(aside)
	watched = aside
	view = Vector4(0.35, 0.08, 3.3, 0.65)
	await frames(3)
	made.open_dresser()
	for shot: String in ["menu", "menu_random", "menu_main"]:
		if shot == "menu_random":
			seed(4)
			made._random()
		elif shot == "menu_main":
			made._show_page(false)
		for i in 4:
			aim()
			await process_frame
		await RenderingServer.frame_post_draw
		var file := out.path_join(shot + ".png")
		root.get_texture().get_image().save_png(file)
		print("SHEET ", file, "  panel ", made._panel.size, " of window ", root.size, ", scrolls: ", made._scroll.get_v_scroll_bar().visible)
	paused = false
	Settings.undress()
	layer.queue_free()
	watched = figure
