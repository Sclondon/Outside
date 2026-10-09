extends SceneTree
## Not part of the game. Draws each prop in props/ alone, from two sides (or from four,
## with `four` among the names), four props to a sheet, to see what a change to
## tools/build_props.py has done.
## godot --path . --resolution 960x960 --script tools/prop_sheets.gd -- <outdir> [banded] [four] [sky] [backlit] [sway] [name ...]
## For the plants: `sky` looks up at it from the ground, `backlit` puts the sun behind
## it, and `sway` draws one side of it at four moments a quarter of a second apart, in
## a stiff wind. `crown` looks closely at the top of it.

const CELL := 480
var out := ""
var only: Array = []
var stage: Node3D
var cam: Camera3D
var cells: Array[Image] = []
var views := 2
var sky := false
var backlit := false
var sway := false
var crown := false
var sun: DirectionalLight3D
var blown := 0.0


func _initialize() -> void:
	DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_NO_FOCUS, true)
	DisplayServer.window_set_position(Vector2i(-6000, -6000))
	var args := OS.get_cmdline_user_args()
	out = args[0]
	only = args.slice(1)
	if "banded" in only:
		only.erase("banded")
		Settings.world_banded = true
	if "four" in only:
		only.erase("four")
		views = 4
	for word: String in ["sky", "backlit", "sway", "crown"]:
		if word in only:
			only.erase(word)
			set(word, true)
	stage = Node3D.new()
	root.add_child(stage)
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.56, 0.7, 0.86)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.7, 0.74, 0.8)
	env.ambient_light_energy = 0.7
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	var world := WorldEnvironment.new()
	world.environment = env
	stage.add_child(world)
	sun = DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-46.0, 150.0, 0.0)
	sun.light_color = Color(1.0, 0.95, 0.86)
	sun.light_energy = 1.25
	sun.shadow_enabled = true
	sun.directional_shadow_max_distance = 200.0
	# (on the web a sun that casts shadows is turned down, and the sand is told: see
	# `Sand.sky`. The same here, so that `--rendering-method gl_compatibility` shows a
	# prop as a level on the web does)
	if RenderingServer.get_current_rendering_method() == "gl_compatibility":
		sun.light_energy *= 0.3
		Sand.sun_gain = 1.0 / 0.3
		Sand.sky = env.ambient_light_color.srgb_to_linear() * env.ambient_light_energy
	stage.add_child(sun)
	var ground := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(600, 600)
	ground.mesh = plane
	ground.material_override = Sand.surface()
	stage.add_child(ground)
	cam = Camera3D.new()
	cam.fov = 30.0
	stage.add_child(cam)
	cam.make_current()
	run.call_deferred()


func run() -> void:
	var names: Array = []
	for file in DirAccess.get_files_at("res://props"):
		if file.ends_with(".tscn") and (only.is_empty() or file.get_basename() in only):
			names.append(file.get_basename())
	names.sort()
	var page := 0
	var on_page: Array = []
	for name: String in names:
		var prop: Node3D = load("res://props/%s.tscn" % name).instantiate()
		# (loose things would fall through the ground, which is only a picture)
		if prop is RigidBody3D:
			(prop as RigidBody3D).freeze = true
		stage.add_child(prop)
		var bounds := bounds_of(prop)
		var middle := bounds.get_center()
		var reach := bounds.size.length() * 0.5 / tan(deg_to_rad(15.0)) * 1.05
		var yaws: Array = [0.6, PI + 0.9] if views == 2 else [0.0, 0.75, PI * 0.5, PI + 0.6]
		if sway:
			yaws.fill(0.6)
		if crown:
			# (the top third of it, close)
			middle.y = bounds.end.y - bounds.size.y * 0.2
			reach *= 0.45
		for yaw: float in yaws:
			var pitch := -0.1 if sky else 0.3
			cam.global_position = middle + Vector3(sin(yaw) * cos(pitch), sin(pitch), cos(yaw) * cos(pitch)) * reach
			cam.global_position.y = maxf(cam.global_position.y, 0.5)
			cam.look_at(middle)
			cam.far = reach * 4.0 + 200.0
			if backlit:
				sun.rotation = Vector3(deg_to_rad(-24.0), yaw + PI + 0.25, 0.0)
			for i in 3:
				await process_frame
			if sway:
				# (as a `SandWind` would tell it: a quarter of a second of a stiff wind)
				var until := Time.get_ticks_msec() + 250
				while Time.get_ticks_msec() < until:
					blown += 8.0 * root.get_process_delta_time()
					Sand.blow(Vector2(1.0, 0.0), 0.75, blown, Color(0.0, 0.0, 0.0, 0.0))
					await process_frame
			await RenderingServer.frame_post_draw
			var image := root.get_texture().get_image()
			var side: int = mini(image.get_width(), image.get_height())
			image = image.get_region(Rect2i((image.get_width() - side) / 2, (image.get_height() - side) / 2, side, side))
			image.resize(CELL, CELL, Image.INTERPOLATE_LANCZOS)
			cells.append(image)
		on_page.append(name)
		prop.queue_free()
		await process_frame
		if on_page.size() == (4 if views == 2 else 2):
			sheet(page, on_page)
			page += 1
			on_page = []
	if not on_page.is_empty():
		sheet(page, on_page)
	quit()


func bounds_of(prop: Node3D) -> AABB:
	var bounds := AABB()
	var first := true
	for part: MeshInstance3D in prop.find_children("*", "MeshInstance3D", true, false):
		var box := part.global_transform * part.get_aabb()
		bounds = box if first else bounds.merge(box)
		first = false
	return bounds


func sheet(page: int, names: Array) -> void:
	var columns := views
	var rows := ceili(cells.size() / float(columns))
	var whole := Image.create(CELL * columns, CELL * rows, false, cells[0].get_format())
	for i in cells.size():
		whole.blit_rect(cells[i], Rect2i(0, 0, CELL, CELL), Vector2i((i % columns) * CELL, (i / columns) * CELL))
	whole.save_png(out.path_join("props_%02d.png" % page))
	cells.clear()
	print("SHEET %d: %s" % [page, ", ".join(names)])
