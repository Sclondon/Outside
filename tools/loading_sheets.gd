extends SceneTree
## Not part of the game. Pictures of the notebook's page that covers a change of level (`Loading`): for
## each change a strip of moments from the page coming across until it has gone, left to right and top
## to bottom, about a fourteenth of a second apart; the last two are the first frame with no page, and
## one a third of a second later. The page full size (`<name>_page.png`) and that first frame
## (`<name>_after.png`) are saved as well. It prints when each moment was, and how long the change took.
## godot --path . --resolution 1560x720 --script tools/loading_sheets.gd -- <outdir> [start yard tombs door outside desert again]
## (add `--rendering-method gl_compatibility --rendering-driver opengl3` for what the web build draws)

const WIDE := 520
const COLUMNS := 4
var out := ""
var names: Array[String] = []
var cells: Array[Image] = []
var times: PackedInt32Array = []


func _initialize() -> void:
	DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_NO_FOCUS, true)
	DisplayServer.window_set_position(Vector2i(-6000, -6000))
	var args := OS.get_cmdline_user_args()
	out = args[0]
	for i in range(1, args.size()):
		names.append(args[i])
	DirAccess.make_dir_recursive_absolute(out)
	run.call_deferred()


func wanted(name: String) -> bool:
	return names.is_empty() or names.has(name)


func grab() -> Image:
	return root.get_texture().get_image()


## Does `start`, which changes the level, and keeps pictures of it until the page has gone.
func record(name: String, start: Callable) -> void:
	cells.clear()
	times.clear()
	var full: Array[Image] = []
	await RenderingServer.frame_post_draw
	full.append(grab())
	times.append(0)
	var began := Time.get_ticks_msec()
	start.call()
	var last := 0
	var guard := 0
	while guard < 100000:
		guard += 1
		await RenderingServer.frame_post_draw
		var now := Time.get_ticks_msec() - began
		if not Loading.busy:
			# (the first frame drawn with no page over it)
			full.append(grab())
			times.append(now)
			break
		if now - last >= 70:
			full.append(grab())
			times.append(now)
			last = now
	var gone := Time.get_ticks_msec()
	while Time.get_ticks_msec() - gone < 330:
		await process_frame
	await RenderingServer.frame_post_draw
	full.append(grab())
	times.append(Time.get_ticks_msec() - began)
	# The page full size, from the middle of the wait; and the first frame after
	full[full.size() / 2].save_png(out.path_join(name + "_page.png"))
	full[-2].save_png(out.path_join(name + "_after.png"))
	# Not more of them than can be looked at: the start and the end, and the middle thinned out
	var keep: Array[int] = []
	if full.size() <= 28:
		for i in full.size():
			keep.append(i)
	else:
		for i in 6:
			keep.append(i)
		for i in 14:
			keep.append(6 + int((full.size() - 14) * i / 14.0))
		for i in range(full.size() - 8, full.size()):
			keep.append(i)
	var said := ""
	for i in keep:
		var cell := full[i]
		cell.resize(WIDE, WIDE * cell.get_height() / cell.get_width(), Image.INTERPOLATE_LANCZOS)
		cells.append(cell)
		said += "%d " % times[i]
	var rows := ceili(cells.size() / float(COLUMNS))
	var tall := cells[0].get_height()
	var page := Image.create(WIDE * COLUMNS, tall * rows, false, cells[0].get_format())
	for i in cells.size():
		page.blit_rect(cells[i], Rect2i(0, 0, WIDE, tall), Vector2i((i % COLUMNS) * WIDE, (i / COLUMNS) * tall))
	page.save_png(out.path_join(name + ".png"))
	print("SHEET %s  took %d ms in all, the page fully up %d ms, longest still %d ms  moments at (ms): %s" % [name, Loading.took.get("all", 0), Loading.took.get("up", 0), Loading.took.get("longest", 0), said])
	cells.clear()


func menu() -> GameMenu:
	return current_scene.get_node("HUD/Menu") as GameMenu


func wait(seconds: float) -> void:
	var until := Time.get_ticks_msec() + int(seconds * 1000.0)
	while Time.get_ticks_msec() < until:
		await process_frame


func run() -> void:
	Loading.instant = false
	# (the desert the game came with, and nothing of the player's is written)
	LevelLayout.saved_at = "user://loading_sheets_none.json"
	TombDaily.path = "user://loading_sheets_tombs.json"
	# The game starting: the page is there from the first frame, and the desert builds behind it.
	if wanted("start"):
		await record("start", func() -> void: change_scene_to_file("res://start.tscn"))
	else:
		Loading.go("res://desert.tscn", "", true)
		await Loading.page().finished
	await wait(0.5)
	if wanted("yard"):
		await record("desert_to_yard", func() -> void: menu()._go_to("res://test_yard.tscn"))
		await wait(0.5)
	if wanted("tombs"):
		await record("to_tombs", func() -> void: menu()._go_to("res://tomb.tscn"))
		await wait(0.5)
	if wanted("desert"):
		await record("to_desert", func() -> void: menu()._go_to("res://desert.tscn"))
		await wait(0.5)
	elif current_scene.scene_file_path != "res://desert.tscn":
		Loading.go("res://desert.tscn")
		await Loading.page().finished
	if wanted("door"):
		# In at a doorway of the Valley of the Kings, and back out of it.
		var door: TombDoor
		for node in current_scene.find_children("*", "Node3D", true, false):
			if node is TombDoor and not (node as TombDoor).tomb().is_empty():
				door = node
				break
		if door:
			await record("door_to_tomb", func() -> void: door.enter())
			await wait(0.5)
			if wanted("outside"):
				await record("tomb_to_outside", func() -> void:
					Desert.play_from = TombLevel.back_at
					Loading.go(TombLevel.back_to))
				await wait(0.5)
		else:
			print("no doorway that leads to a tomb in this desert")
	if wanted("again"):
		await record("again", func() -> void: menu()._restart())
	quit()
