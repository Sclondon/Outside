extends SceneTree
## Not part of the game. Pictures of pyramids made by scripts/pyramid.gd, and of the
## heat mirage (scripts/heat_mirage.gd).
## godot --path . --resolution 960x960 --script tools/pyramid_sheets.gd -- <outdir> [banded] [mirage | level] [name ...]
##
## With neither: each sort of pyramid, 60 m across, on bare ground: all of it,
## from 400 m off, close to at the height of his eye, and its door, its fallen
## corner or its top; four pictures to a sheet (pyramids_NN.png). Prints how
## many triangles and shapes each is.
## With `level`: the pyramids of this kind that the desert (desert.tscn) has, as
## they stand in it (level_NN.png).
## With `mirage` (best at --resolution 1280x720): the desert from his eye height,
## looking out over the sand: the strip of the picture about the level of the
## eye, as it is drawn, twice with the mirage at its full, once as the level has
## it and once without (mirage_NN.png).
## Add `--rendering-method gl_compatibility` before `--script` for the web's renderer.

const CELL := 640
## How high a strip of the picture is kept, for the mirage.
const STRIP := 300
## [name, numbers]
const SORTS := [
	["stepped", {"base": 60.0}],
	["finished", {"base": 60.0, "casing": 1.0, "cap": true, "door": true, "stone": 1}],
	["capped", {"base": 60.0, "casing": 0.28, "door": true}],
	["gold_stepped", {"base": 60.0, "cap": true, "slope": 48.0}],
	["ruined", {"base": 60.0, "ruin": 0.45, "seed": 3}],
	["ruined_cased", {"base": 60.0, "ruin": 0.3, "casing": 1.0, "seed": 5, "stone": 1}],
	["fallen", {"base": 60.0, "ruin": 0.7, "seed": 2, "casing": 0.4}],
	["meidum", {"base": 60.0, "ruin": 1.0, "seed": 4, "stone": 2}],
]

var out := ""
var only: Array = []
var stage: Node3D
var cam: Camera3D
var cells: Array[Image] = []
var names: Array = []
var page := 0
var prefix := "pyramids"


func _initialize() -> void:
	DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_NO_FOCUS, true)
	DisplayServer.window_set_position(Vector2i(-6000, -6000))
	var args := OS.get_cmdline_user_args()
	out = args[0]
	only = args.slice(1)
	if "banded" in only:
		only.erase("banded")
		Settings.world_banded = true
	for mode: String in ["mirage", "level"]:
		if mode in only:
			only.erase(mode)
			prefix = mode
			mirage.call_deferred()
			return
	stage = Node3D.new()
	root.add_child(stage)
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.5, 0.66, 0.86)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.7, 0.73, 0.8)
	env.ambient_light_energy = 0.75
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	var world := WorldEnvironment.new()
	world.environment = env
	stage.add_child(world)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-42.0, 140.0, 0.0)
	sun.light_color = Color(1.0, 0.95, 0.85)
	sun.light_energy = 1.3 * (Desert.WEB_SUN if RenderingServer.get_current_rendering_method() == "gl_compatibility" else 1.0)
	sun.shadow_enabled = true
	sun.directional_shadow_max_distance = 260.0
	stage.add_child(sun)
	var ground := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(3000, 3000)
	ground.mesh = plane
	var sand := StandardMaterial3D.new()
	sand.albedo_color = Color(0.82, 0.7, 0.5)
	sand.roughness = 1.0
	sand.metallic_specular = 0.0
	ground.material_override = sand
	stage.add_child(ground)
	cam = Camera3D.new()
	cam.fov = 40.0
	cam.far = 4000.0
	stage.add_child(cam)
	cam.make_current()
	run.call_deferred()


func run() -> void:
	for sort: Array in SORTS:
		if not only.is_empty() and not sort[0] in only:
			continue
		var began := Time.get_ticks_usec()
		var pyramid := Pyramid.from_item(sort[1])
		stage.add_child(pyramid)
		print("PYRAMID %-13s %5d triangles  %3d shapes  %4.1f m high  made in %.1f ms" % [sort[0], pyramid.triangles, pyramid.shapes, pyramid.height, (Time.get_ticks_usec() - began) / 1000.0])
		var high := maxf(pyramid.height, 20.0)
		# All of it; from far off; close to, along a face; and at a corner from his height.
		await shoot(sort[0], Vector3(62, 26, 78), Vector3(0, high * 0.42, 0), 40.0)
		await shoot(sort[0] + " far", Vector3(-250, 1.6, 320), Vector3(0, high * 0.45, 0), 14.0)
		await shoot(sort[0] + " near", Vector3(9, 2.6, 36.5), Vector3(0, 7.0, 26), 55.0)
		if not pyramid.fallen_corners.is_empty():
			# (the corner that fell, and the rubble in it from where he would start up it)
			var fell := pyramid.fallen_corners[0]
			await shoot(sort[0] + " fallen corner", Vector3(fell.x * 64, 24, fell.y * 64) + Vector3(fell.y, 0, -fell.x) * 26.0, Vector3(fell.x * 22, high * 0.3, fell.y * 22), 50.0)
			await shoot(sort[0] + " rubble", Vector3(fell.x * 42, 3.0, fell.y * 42) + Vector3(fell.y, 0, -fell.x) * 5.0, Vector3(fell.x * 20, 11.0, fell.y * 20), 60.0)
		elif pyramid.door:
			await shoot(sort[0] + " door", Vector3(5, 1.7, 44), Vector3(0, 3.0, 27), 55.0)
			await shoot(sort[0] + " corner", Vector3(40, 9.0, 40), Vector3(22, 6.5, 22), 55.0)
		else:
			await shoot(sort[0] + " corner", Vector3(40, 9.0, 40), Vector3(22, 6.5, 22), 55.0)
			await shoot(sort[0] + " above", Vector3(8, high + 16.0, 30), Vector3(0, high - 4.0, 0), 50.0)
		pyramid.queue_free()
		await process_frame
	if not cells.is_empty():
		sheet()
	quit()


## The desert in the heat.
func mirage() -> void:
	var scene: Node = load("res://desert.tscn").instantiate()
	root.add_child(scene)
	cam = Camera3D.new()
	cam.far = 3000.0
	root.add_child(cam)
	for action: StringName in InputMap.get_actions():
		if not String(action).begins_with("ui_"):
			InputMap.action_erase_events(action)
			Input.action_release(action)
	for i in 30:
		await physics_frame
	var level := scene.get_node("Level") as Desert
	if prefix == "level":
		# The pyramids that the level has of this kind. [name, from, to, field of view; the height of `from` is above the ground there]
		for view: Array in [
				["finished", Vector3(96, 1.6, 34), Vector3(146, 10, 26), 40.0],
				["its door", Vector3(116, 1.6, 31), Vector3(128, 2.2, 26), 50.0],
				["fallen", Vector3(84, 1.6, 80), Vector3(128, 5, 66), 40.0],
				["fallen, behind", Vector3(160, 6, 104), Vector3(128, 4, 66), 50.0],
				["stepped", Vector3(64, 1.6, -52), Vector3(86, 7, -90), 50.0],
				["stepped and great", Vector3(64, 5, -18), Vector3(44, 12, -100), 55.0],
				["from the oasis", Vector3(40, 3, 70), Vector3(138, 6, 44), 50.0],
				["from the start", Vector3(0, 1.6, 165), Vector3(80, 8, 0), 55.0]]:
			if not only.is_empty() and not view[0] in only:
				continue
			var from: Vector3 = view[1]
			from.y += level.height_at(from.x, from.z)
			await shoot(view[0], from, view[2], view[3], 6)
			print("VIEW %-18s draw calls %4d  triangles %7d" % [view[0], Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME), Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME)])
		if not cells.is_empty():
			sheet()
		quit()
		return
	# [name, from, to, field of view]
	var views := [
		["dunes", Vector3(-150, 0, 150), Vector3(60, 0, -60), 30.0],
		["to the pyramid", Vector3(0, 0, 120), Vector3(0, 6, -110), 30.0],
		["plain", Vector3(100, 0, 10), Vector3(-150, 0, -40), 30.0],
		["to the new pyramids", Vector3(-40, 0, 20), Vector3(140, 4, 46), 30.0],
	]
	for view: Array in views:
		if not only.is_empty() and not view[0] in only:
			continue
		var from: Vector3 = view[1]
		from.y = level.height_at(from.x, from.z) + 1.5
		var to: Vector3 = view[2]
		to.y += from.y - 1.5
		# Two frames with it at its full, one as the level has it, and one without.
		for frame in 4:
			var strength: float = [1.0, 1.0, HeatMirage.USUAL, 0.0][frame]
			level.heat(strength)
			level.mirage.force = strength
			await shoot("%s %s" % [view[0], ["full", "full again", "usual", "off"][frame]], from, to, view[3], 6)
		print("VIEW %-16s draw calls %4d  triangles %7d" % [view[0], Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME), Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME)])
	if not cells.is_empty():
		sheet()
	quit()


func shoot(name: String, from: Vector3, to: Vector3, fov: float, frames := 4) -> void:
	cam.global_position = from
	cam.look_at(to)
	cam.fov = fov
	for i in frames:
		cam.make_current()
		await process_frame
	await RenderingServer.frame_post_draw
	var image := root.get_texture().get_image()
	if prefix == "mirage":
		# (as it is drawn, not made smaller: the strip of the picture about the level of the eye)
		image = image.get_region(Rect2i(0, image.get_height() / 2 - STRIP / 2, image.get_width(), STRIP))
	else:
		var side: int = mini(image.get_width(), image.get_height())
		image = image.get_region(Rect2i((image.get_width() - side) / 2, (image.get_height() - side) / 2, side, side))
		image.resize(CELL, CELL, Image.INTERPOLATE_LANCZOS)
	cells.append(image)
	names.append(name)
	if cells.size() == 4:
		sheet()


func sheet() -> void:
	var wide := cells[0].get_width()
	var high := cells[0].get_height()
	var columns := 1 if prefix == "mirage" else 2
	var whole := Image.create(wide * columns, high * (4 / columns), false, cells[0].get_format())
	for i in cells.size():
		whole.blit_rect(cells[i], Rect2i(0, 0, wide, high), Vector2i((i % columns) * wide, (i / columns) * high))
	whole.save_png(out.path_join("%s_%02d.png" % [prefix, page]))
	print("SHEET %d: %s" % [page, ", ".join(names)])
	page += 1
	cells.clear()
	names.clear()
