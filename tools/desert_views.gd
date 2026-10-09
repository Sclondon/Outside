extends SceneTree
## Not part of the game. Opens desert.tscn and saves pictures of it from a set of
## viewpoints (an overview, each landmark, some at the boy's eye level), four to a
## sheet, and prints what each costs to draw.
## godot --path . --resolution 960x960 --script tools/desert_views.gd -- <outdir> [banded] [name ...]

const CELL := 640
const VIEWS := [
	["overview", Vector3(40, 150, 300), Vector3(0, 0, -20), 50.0],
	["above", Vector3(0, 520, 1), Vector3(0, 0, 0), 50.0],
	["start", Vector3(0, 1.5, 173), Vector3(0, 4, 100), 55.0],
	["camp", Vector3(-38, 9, 133), Vector3(-62, 1, 104), 55.0],
	["camp_eye", Vector3(-62, 1.9, 121), Vector3(-62, 2, 100), 55.0],
	["oasis", Vector3(30, 9, 108), Vector3(62, -1, 78), 55.0],
	["oasis_eye", Vector3(42, 0.8, 84), Vector3(62, 1.5, 76), 55.0],
	["colonnade_eye", Vector3(0, 2.4, 75), Vector3(0, 5, 20), 55.0],
	["colonnade", Vector3(32, 16, 78), Vector3(0, 2, 34), 55.0],
	["sphinx_eye", Vector3(1.5, 3.4, -4), Vector3(0, 7, -30), 55.0],
	["sphinx", Vector3(22, 9, -2), Vector3(0, 5, -27), 55.0],
	["sphinx_side", Vector3(32, 6, -32), Vector3(0, 5, -30), 55.0],
	["sphinx_head", Vector3(5, 7, -14), Vector3(0, 8.4, -28), 40.0],
	["pyramid", Vector3(6, 9, -52), Vector3(0, 16, -105), 60.0],
	["entrance_eye", Vector3(4, 5.4, -60), Vector3(0, 7.5, -78), 55.0],
	["ruined", Vector3(92, 9, -12), Vector3(118, 4, -38), 55.0],
	["shrine", Vector3(-105, 4, -9), Vector3(-112, 2.5, -34), 55.0],
	["outpost", Vector3(120, 5, 168), Vector3(105, 2, 148), 55.0],
	["obelisk", Vector3(-93, 6, 64), Vector3(-105, 1, 50), 55.0],
	["from_pyramid", Vector3(0, 33, -97), Vector3(0, 0, 60), 60.0],
]

var out := ""
var only: Array = []
var cam: Camera3D
var cells: Array[Image] = []
var names: Array = []


func _initialize() -> void:
	DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_NO_FOCUS, true)
	DisplayServer.window_set_position(Vector2i(-6000, -6000))
	var args := OS.get_cmdline_user_args()
	out = args[0]
	only = args.slice(1)
	if "banded" in only:
		only.erase("banded")
		Settings.world_banded = true
	var scene: Node = load("res://desert.tscn").instantiate()
	root.add_child(scene)
	cam = Camera3D.new()
	root.add_child(cam)
	run.call_deferred()


func run() -> void:
	# Someone may be playing with a gamepad, which is heard without the focus.
	for action: StringName in InputMap.get_actions():
		if not String(action).begins_with("ui_"):
			InputMap.action_erase_events(action)
			Input.action_release(action)
	for i in 20:
		await physics_frame
	var page := 0
	for view: Array in VIEWS:
		if not only.is_empty() and not view[0] in only:
			continue
		cam.global_position = view[1]
		cam.look_at(view[2])
		cam.fov = view[3]
		cam.far = 3000.0
		for i in 4:
			cam.make_current()
			await process_frame
		await RenderingServer.frame_post_draw
		var image := root.get_texture().get_image()
		var side: int = mini(image.get_width(), image.get_height())
		image = image.get_region(Rect2i((image.get_width() - side) / 2, (image.get_height() - side) / 2, side, side))
		image.resize(CELL, CELL, Image.INTERPOLATE_LANCZOS)
		cells.append(image)
		names.append(view[0])
		print("VIEW %-14s draw calls %4d  triangles %7d  objects %4d" % [view[0],
			Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME),
			Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME),
			Performance.get_monitor(Performance.RENDER_TOTAL_OBJECTS_IN_FRAME)])
		if cells.size() == 4:
			sheet(page)
			page += 1
	if not cells.is_empty():
		sheet(page)
	quit()


func sheet(page: int) -> void:
	var whole := Image.create(CELL * 2, CELL * 2, false, cells[0].get_format())
	for i in cells.size():
		whole.blit_rect(cells[i], Rect2i(0, 0, CELL, CELL), Vector2i((i % 2) * CELL, (i / 2) * CELL))
	whole.save_png(out.path_join("desert_%02d.png" % page))
	print("SHEET %d: %s" % [page, ", ".join(names)])
	cells.clear()
	names.clear()
