extends SceneTree
## Not part of the game. Pictures of the level editor in every state it has, and with each a measure of what there
## is to touch in it: how many things, the smallest, how many are under 88 pixels either way, stand nearer than 12
## to the next, or are in the margins at the ends of the screen and its foot, and the smallest writing.
## For a phone (the usual), it fails if anything in any state is too small, too near or in a margin.
## With `desk` it takes the same pictures of the panels for a desk, and only reports.
## godot --path . --resolution 1560x720 --script tools/level_editor_shots.gd -- <outdir> [desk]

const Audit := preload("res://tools/touch_audit.gd")

var out := ""
var editor: LevelEditor
var level: Desert
var states := 0
var wrong := 0
var least := 1.0e9
var least_name := ""
var least_text := 999


func _initialize() -> void:
	DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_NO_FOCUS, true)
	DisplayServer.window_set_position(Vector2i(-6000, -6000))
	out = OS.get_cmdline_user_args()[0]
	DirAccess.make_dir_recursive_absolute(out)
	run.call_deferred()


func snap(name: String) -> void:
	for i in 8:
		await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(out.path_join(name + ".png"))
	var result := Audit.measure(editor, editor.phone)
	print(Audit.line(name, result))
	states += 1
	if result["count"] > 0 and result["area"] < least:
		least = result["area"]
		least_name = "%s (in %s)" % [result["smallest"], name]
	least_text = mini(least_text, result["text"])
	if editor.phone and (result["small"] > 0 or result["close"] > 0 or result["edge"] > 0 or result["text"] < Audit.TEXT):
		wrong += 1
		for line: String in result["lines"]:
			print("      ", line)


func entry(page: String, name: String) -> Array:
	for found: Array in LevelLayout.PALETTE[page]:
		if found[0] == name:
			return found
	return []


func put(page: String, name: String, at: Vector2) -> Dictionary:
	editor._arm(entry(page, name))
	editor._tapped(at)
	return editor.chosen


func run() -> void:
	# (what is made here is kept apart from whatever has been made in the game)
	LevelLayout.saved_at = "user://level_editor_shots.json"
	LevelLayout.forget_saved()
	var scene: Node = load("res://desert.tscn").instantiate()
	root.add_child(scene)
	for i in 30:
		await physics_frame
	level = scene.get_node("Level")
	editor = LevelEditor.new()
	editor.phone = not OS.get_cmdline_user_args().has("desk")
	scene.get_node("HUD").add_child(editor)
	editor.open()
	print("SCREEN ", root.get_visible_rect().size, " in a window of ", DisplayServer.window_get_size(), ", ", "for a phone" if editor.phone else "for a desk")
	if editor.phone:
		await phone()
	else:
		await desk()
	LevelLayout.forget_saved()
	print("smallest thing to touch: %s; smallest writing: %d" % [least_name, least_text])
	if editor.phone:
		print("PHONE LAYOUT: %d states, %s" % [states, "all pass" if wrong == 0 else "%d FAILED" % wrong])
	paused = false
	quit(1 if wrong > 0 else 0)


# A page, and its far end if it is longer than the screen.
func page(name: String) -> void:
	await snap(name)
	var body := editor._phone._page_body
	if body.most() > 0.0:
		body.scroll = body.most()
		body.arrange()
		await snap(name + "_end")


func phone() -> void:
	var ui := editor._phone
	var middle := root.get_visible_rect().size * 0.5
	await snap("01_world")
	ui.show_panel("add")
	await page("02_add")
	for kind: String in LevelLayout.PALETTE:
		ui._kind = kind
		ui.show_panel("kind")
		await page("03_kind_%s" % kind.to_lower())
	editor._arm(entry("Puzzle", "Door"))
	ui.show_panel("place")
	await snap("04_placing")
	editor._tapped(middle)
	var door: Dictionary = editor.chosen
	await snap("05_door_chosen")
	ui.show_panel("move")
	await snap("06_move")
	ui._open_change(false)
	await page("07_change_door")
	ui._number = ui._spec("Width", door, "wide", 0.6, 12.0, 0.1)
	ui.show_panel("number")
	await snap("08_number")
	var plate := put("Puzzle", "Pressure plate", middle + Vector2(110, 70))
	editor._choose(door)
	ui.show_panel("link")
	editor._tapped(editor.cam.unproject_position(level.place_of(plate)))
	await snap("09_linking")
	editor._choose(plate)
	await snap("10_plate_chosen")
	ui.show_panel("link_from")
	await snap("11_linking_from")
	ui._open_change(false)
	await page("12_change_plate")
	var mover := put("Puzzle", "Bridge or lift", middle + Vector2(-150, 60))
	ui._open_change(false)
	await page("13_change_bridge")
	ui._choice = {"title": "Which way", "options": ["Forward", "Up", "Sideways"], "holder": mover, "key": "way", "usual": 0}
	ui.show_panel("choice")
	await page("14_choice")
	var sign := put("Puzzle", "Sign", middle + Vector2(-120, -60))
	await snap("15_sign_chosen")
	ui._open_change(false)
	await page("16_change_sign")
	ui._words = {"title": "Says", "holder": sign, "key": "text"}
	ui.show_panel("words")
	await snap("17_words")
	ui.show_panel("")
	var birds := put("People", "Birds", middle + Vector2(200, -90))
	ui._choice = {"title": "Kind", "options": LevelLayout.fields(birds)[0][3], "holder": birds, "key": "bird", "usual": 1}
	ui.show_panel("choice")
	await page("18_choice_long")
	put("Stone", "Inscription", middle + Vector2(60, -110))
	ui._open_change(false)
	await page("19_change_inscription")
	put("Railway", "Train", middle + Vector2(-260, 120))
	await snap("20_train_chosen")
	put("Puzzle", "Sun lens", middle + Vector2(260, 120))
	await snap("21_lens_chosen")
	put("Water", "River", middle + Vector2(-220, -110))
	await snap("22_river_chosen")
	ui.show_panel("points")
	await snap("23_river_points")
	editor._choose(editor.chosen)
	ui.show_panel("move")
	await snap("24_river_move")
	put("Ground", "Level ground", middle + Vector2(240, 0))
	ui.show_panel("move")
	await snap("25_ground_move")
	editor._choose({})
	ui.show_panel("view")
	await snap("26_view")
	ui._open_change(true)
	await page("27_level")
	ui._choice = {"title": "Weather", "options": ["Calm", "A breeze", "A storm"], "holder": editor.layout, "key": "weather", "usual": 1}
	ui.show_panel("choice")
	await page("28_weather")
	ui.show_panel("more")
	await page("29_more")
	ui.show_panel("text")
	await page("30_level_as_text")
	ui.show_panel("original")
	await page("31_original")
	ui.show_panel("help")
	await page("32_help")
	ui.show_panel("")
	editor._say("Taken away. Undo brings it back.")
	await snap("33_said")
	editor._save_in = -1.0


func desk() -> void:
	var middle := root.get_visible_rect().size * 0.5
	await snap("01_opened_level")
	for kind: String in LevelLayout.PALETTE:
		editor._show_page(kind)
		await snap("02_page_%s" % kind.to_lower())
	editor._show_page("Puzzle")
	editor._arm(entry("Puzzle", "Door"))
	await snap("03_placing")
	editor._tapped(middle)
	var door: Dictionary = editor.chosen
	await snap("04_door_chosen")
	put("Puzzle", "Pressure plate", middle + Vector2(90, 60))
	editor._choose(door)
	editor._next = "link"
	await snap("05_linking")
	editor._next = ""
	put("Puzzle", "Sign", middle + Vector2(-120, 40))
	await snap("06_sign_text")
	put("Stone", "Inscription", middle + Vector2(-60, -80))
	await snap("07_inscription")
	put("Water", "River", middle + Vector2(-200, -100))
	await snap("08_river")
	editor._show_share(true)
	await snap("09_more")
	editor._show_share(false)
	editor._show_side(false)
	await snap("10_panel_away")
	editor._save_in = -1.0
