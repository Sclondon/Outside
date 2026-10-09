extends SceneTree
## Not part of the game. Opens the desert, takes the notebook out by touching
## the corner of the screen, turns to each part of it, dresses the boy, sets
## something, opens the level editor from it, goes to the test yard by its map
## and looks at every page again there; and checks at each step that what was
## touched took effect. Saves a picture of the screen at each.
## Whatever level was saved on this device before is put back at the end.
## godot --path . --resolution 1280x720 --script tools/notebook_test.gd -- <outdir>
## (and again with --rendering-method gl_compatibility, and at --resolution 1600x720 for a long phone)

var out := ""
var menu: GameMenu
var failed := 0
var shot := 0


func _initialize() -> void:
	DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_NO_FOCUS, true)
	DisplayServer.window_set_position(Vector2i(-6000, -6000))
	out = OS.get_cmdline_user_args()[0]
	DirAccess.make_dir_recursive_absolute(out)
	# (it gives up, rather than wait for ever, if something has gone wrong)
	create_timer(240.0, true, false, true).timeout.connect(func() -> void:
		print("NOTEBOOK TEST: gave up after four minutes")
		quit(1))
	run.call_deferred()


func check(what: String, good: bool, note := "") -> void:
	print("%s  %s%s" % ["ok   " if good else "FAIL ", what, "   (%s)" % note if note != "" else ""])
	if not good:
		failed += 1


func picture(name: String) -> void:
	for i in 3:
		await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(out.path_join("%02d_%s.png" % [shot, name]))
	shot += 1


func touch(at: Vector2, down: bool) -> void:
	var event := InputEventScreenTouch.new()
	event.index = 0
	event.position = at
	event.pressed = down
	root.push_input(event)
	await process_frame


func key(code: Key) -> void:
	for down: bool in [true, false]:
		var event := InputEventKey.new()
		event.keycode = code
		event.physical_keycode = code
		event.pressed = down
		root.push_input(event)
		await process_frame


func wait(seconds: float) -> void:
	var until := Time.get_ticks_msec() + int(seconds * 1000.0)
	while Time.get_ticks_msec() < until:
		await process_frame


## Where on the screen one of the notebook's spots is, by its name.
func place(id: String) -> Vector2:
	for spot: Dictionary in menu._spots:
		if spot["id"] == id:
			return menu._middle(spot)
	check("there is somewhere to touch called " + id, false)
	return Vector2(-100, -100)


## A finger down and up on one of the notebook's spots.
func tap(id: String) -> void:
	var at := place(id)
	await touch(at, true)
	await touch(at, false)
	await process_frame


## The smallest of the things that can be touched, each way, in pixels of the 1280 x 720 screen.
func smallest() -> Vector2:
	var least := Vector2(INF, INF)
	for spot: Dictionary in menu._spots:
		var on := spot["on"] as Node2D
		var size: Vector2 = (spot["rect"] as Rect2).size * on.get_global_transform().get_scale()
		least = Vector2(minf(least.x, size.x), minf(least.y, size.y))
	return least


## Whether everything that can be touched is on the screen.
func all_on_screen() -> bool:
	var screen := Rect2(Vector2.ZERO, menu.size)
	for spot: Dictionary in menu._spots:
		var on := spot["on"] as Node2D
		var rect: Rect2 = on.get_global_transform() * (spot["rect"] as Rect2)
		if not screen.encloses(rect):
			print("      off the screen: %s %s" % [spot["id"], rect])
			return false
	return true


## A picture of a leaf half turned, or the book half out: held still for it.
func held_picture(name: String, turn: float, how_far_out: float) -> void:
	menu.set_process(false)
	menu._turn = turn
	menu._out = how_far_out
	menu._arrange()
	menu._refresh()
	await picture(name)
	menu.set_process(true)


## Waits for a level to be the one that is running, and finds its menu.
func arrive(path: String) -> void:
	var was := menu.get_instance_id() if is_instance_valid(menu) else 0
	for i in 600:
		await process_frame
		if current_scene and current_scene.scene_file_path == path and current_scene.is_node_ready() and current_scene.get_node("HUD/Menu").get_instance_id() != was:
			break
	for i in 40:
		await physics_frame
	menu = current_scene.get_node("HUD/Menu")


func turn_to(part: String) -> void:
	await tap("tab:" + part)
	await wait(0.5)


## Every page of the book, as it is in this level.
func pages(level: String) -> void:
	for part: String in ["journal", "me", "places", "notes"]:
		if menu._section != part:
			await turn_to(part)
		check("%s: turned to %s, with nothing too small to touch and nothing off the screen" % [level, part],
			menu._section == part and menu._turn >= 1.0 and smallest().x >= 44.0 and smallest().y >= 44.0 and all_on_screen(), "smallest %s" % smallest())
		await picture("%s_%s" % [level, part])
		if part == "journal" and menu._journal_spreads() > 1:
			await tap("journal:back")
			await wait(0.5)
			await picture("%s_journal_first" % level)
			await tap("journal:on")
			await wait(0.5)


func run() -> void:
	var kept := FileAccess.get_file_as_string(LevelLayout.SAVED) if LevelLayout.has_saved() else ""
	LevelLayout.forget_saved()
	Settings.undress()
	change_scene_to_file("res://desert.tscn")
	await arrive("res://desert.tscn")
	var corner := Vector2(menu.size.x - 66.0, 33.0)
	await picture("desert_shut")

	# Out it comes
	await touch(corner, true)
	await touch(corner, false)
	check("a touch in the corner takes it out, and the game stands still", menu._open and paused)
	await held_picture("desert_coming_up", 1.0, 0.3)
	await held_picture("desert_cover_swinging", 1.0, 0.62)
	await held_picture("desert_cover_over", 1.0, 0.86)
	menu._out = 0.0
	var began := Time.get_ticks_msec()
	while menu._out < 1.0 and Time.get_ticks_msec() - began < 3000:
		await process_frame
	check("it is open in well under a second", menu._out >= 1.0 and Time.get_ticks_msec() - began < 800, "%d ms" % (Time.get_ticks_msec() - began))
	check("at the journal, which has something in it", menu._section == "journal" and not Notebook.entries.is_empty())

	# Me: a leaf goes over, and he is dressed
	await tap("tab:me")
	check("touching a tab begins to turn a leaf", menu._section == "me" and menu._turn < 1.0)
	await held_picture("desert_leaf_lifting", 0.3, 1.0)
	await held_picture("desert_leaf_coming_down", 0.7, 1.0)
	await wait(0.5)
	var boy := menu._boy()
	await tap("hair:on")
	check("his hair is changed", Settings.hair == "long" and Settings.parts.get("hair", "") == "long", Settings.hair)
	await tap("helmet:on")
	await wait(0.2)
	check("a helmet is put on him", Settings.helmet == "helmet_anubis" and Worn.wearing(boy, &"head") == &"helmet_anubis", Settings.helmet)
	await picture("desert_me_helmet")
	await tap("helmet:back")
	await tap("skin:5")
	check("his skin is another colour", (Settings.colours.get("skin", Color.BLACK) as Color).is_equal_approx(CharacterLook.SKINS[5]))
	await tap("garment:1")
	await tap("paint:22")
	var overalls: String = CharacterLook.outfit(Settings.outfit)["garments"][1][1]
	check("and so are his overalls", (Settings.colours.get(overalls, Color.BLACK) as Color).is_equal_approx(menu._paints[22]), overalls)
	await tap("cap")
	await tap("backpack")
	await wait(0.2)
	check("his cap is off and his pack is on", not Settings.cap and Settings.backpack and Worn.wearing(boy, &"back") == &"backpack")
	await tap("clothes:on")
	check("he has other clothes on", Settings.outfit == "breeches", Settings.outfit)
	await picture("desert_me_dressed")
	seed(7)
	await tap("random")
	await picture("desert_me_any_old_how")
	await tap("as_he_was")
	check("and is as he was again", Settings.hair == "mullet" and Settings.cap and Settings.colours.is_empty())
	await tap("hair:on")

	# The keys
	await key(KEY_DOWN)
	check("an arrow key puts a mark on something", menu._keys and menu._focus != "", menu._focus)
	menu._focus = "face:on"
	await key(KEY_DOWN)
	check("down from the face is the hair", menu._focus == "hair:on", menu._focus)
	await key(KEY_LEFT)
	check("left of that, the other arrow", menu._focus == "hair:back", menu._focus)
	await key(KEY_ENTER)
	check("and Enter works it", Settings.hair == "mullet", Settings.hair)
	await picture("desert_me_keys")
	await key(KEY_PAGEDOWN)
	await wait(0.5)
	check("Page Down turns on", menu._section == "places", menu._section)
	await key(KEY_ESCAPE)
	check("Esc puts it away, and the game goes on", not menu._open and not paused)
	await wait(0.4)
	check("and it is gone", not menu._book.visible)

	# Something written in it while it is shut
	Notebook.note("Something is scratching behind the east wall. Not rats.", "Wednesday")
	await picture("desert_something_written")
	check("something written in it is not yet read", Notebook.unread == 1)
	await key(KEY_ESCAPE)
	await wait(0.6)
	check("Esc takes it out again, at what was written", menu._open and paused and menu._section == "journal" and Notebook.unread == 0, menu._section)
	# More of what the game may write: a find, a drawing, an inscription drawn by a function, something done and something to do
	Notebook.done("placeholder_pyramid")
	Notebook.find("Pot, red ware", "By the fallen column. Rim chipped. 7 in. high.", "pot")
	Notebook.sketch("eye", "Cut over the door. Father calls it the wedjat.", "Thursday")
	Notebook.translation(func(on: CanvasItem, rect: Rect2) -> void: NotebookInk.signs(on, rect, 5), "\"The door is opened for him who knows the name.\"", "Lintel of the east door")
	Notebook.task("Find what works the east door", "east_door")
	await wait(0.2)
	check("what is written while it is open at the journal is read", Notebook.entries.size() == 10 and Notebook.unread == 0 and menu._journal_spreads() == 2, "%d entries, %d pairs of pages" % [Notebook.entries.size(), menu._journal_spreads()])
	await tap("journal:on")
	await wait(0.5)
	await pages("desert")

	# A setting: the level starts again with it
	await tap("world:1")
	await arrive("res://desert.tscn")
	check("the world's light is banded, and the level has started again", Settings.world_banded and not paused and not menu._open)
	await touch(corner, true)
	await touch(corner, false)
	await wait(0.6)
	check("it opens where it was left", menu._section == "notes", menu._section)
	await picture("desert_banded")
	await tap("world:0")
	await arrive("res://desert.tscn")
	check("and smooth again", not Settings.world_banded)

	# The level editor
	await touch(corner, true)
	await touch(corner, false)
	await wait(0.6)
	await turn_to("places")
	await tap("edit")
	await wait(0.4)
	var editor := get_first_node_in_group(&"level_editor") as LevelEditor
	check("the level editor opens from it, over the stopped game", editor != null and editor.visible and paused and not menu._open and not menu.is_visible_in_tree())
	await picture("desert_editor")
	editor._play(false)
	await arrive("res://desert.tscn")
	check("and Play in the editor goes back to the game", not paused and menu.is_visible_in_tree() and not menu._open)

	# Another place, by the map
	menu.open_dresser()
	check("open_dresser opens it at Me", menu._open and menu._section == "me" and paused)
	await picture("desert_open_dresser")
	await tap("hair:on")
	await turn_to("places")
	await tap("map:res://test_yard.tscn")
	await arrive("res://test_yard.tscn")
	check("the map goes to the test yard, and he is still as he was dressed", current_scene.scene_file_path == "res://test_yard.tscn" and Settings.hair == "long" and not paused)
	await picture("yard_shut")
	await touch(corner, true)
	await touch(corner, false)
	await wait(0.6)
	check("the notebook comes out there too", menu._open and paused)
	check("there is no editing the yard", place("restart") != Vector2(-100, -100) and menu._spots.all(func(spot: Dictionary) -> bool: return spot["id"] != "edit"))
	await pages("yard")
	await turn_to("me")
	await tap("helmet:on")
	await tap("helmet:on")
	await wait(0.3)
	await picture("yard_me_helmet")
	await tap("helmet:back")
	await tap("helmet:back")
	# Off the book, anywhere, puts it away
	await touch(Vector2(12.0, menu.size.y - 12.0), true)
	await touch(Vector2(12.0, menu.size.y - 12.0), false)
	check("a touch off the book puts it away", not menu._open and not paused)
	await touch(corner, true)
	await touch(corner, false)
	await wait(0.6)
	await turn_to("places")
	await tap("go:res://desert.tscn")
	await arrive("res://desert.tscn")
	check("and the list goes back to the desert", current_scene.scene_file_path == "res://desert.tscn")

	Settings.undress()
	LevelLayout.forget_saved()
	if kept != "":
		var file := FileAccess.open(LevelLayout.SAVED, FileAccess.WRITE)
		file.store_string(kept)
		file.close()
	print("NOTEBOOK TEST: %s" % ("all passed" if failed == 0 else "%d FAILED" % failed))
	paused = false
	quit()
