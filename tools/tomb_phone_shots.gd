extends SceneTree
## Not part of the game. Pictures of the tomb editor as it is on a phone
## (`TombPhoneUI`), every state of both views, and each one measured against
## what a thumb needs (`tools/tomb_phone_probe.gd`).
## godot --path . --fixed-fps 60 --resolution 1560x720 --script tools/tomb_phone_shots.gd -- <folder> [only=<part of a name>]
##
##   line_*   a tomb down one axis, seen from the side: the tomb with a room chosen, all of it, a room's page from
##            top to bottom, each list a room's page opens, Rooms, Tombs and what it opens (a name, the generator's,
##            the tomb as text, forgetting one), More, how it works, whether it works, and a tomb with something wrong
##   floor_*  a tomb that branches, seen from overhead: all of it, a room with its "+" marks, from far off, Move and
##            its list, Join and its list, Add's list, a room's page, and the lists that are its own
## Ends with OK, or with WRONG and what was (and quits with 1). The window is kept off the screen, and the tombs
## it keeps are in a file of its own (`user://shots_my_tombs.json`), not the player's.

const Probe := preload("res://tools/tomb_phone_probe.gd")

var out := ""
var only := ""
var editor: TombEditor
var phone: TombPhoneUI
var failed := 0
var states := 0
var smallest := Vector2(INF, INF)
var nearest := INF
var margin := INF
var foot := INF
var text := 9999
var mark := INF
var mark_gap := INF


func _initialize() -> void:
	DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_NO_FOCUS, true)
	DisplayServer.window_set_position(Vector2i(-6000, -6000))
	var args := OS.get_cmdline_user_args()
	out = args[0] if not args.is_empty() else "."
	for arg: String in args.slice(1):
		if arg.begins_with("only="):
			only = arg.trim_prefix("only=")
	DirAccess.make_dir_recursive_absolute(out)
	run.call_deferred()


func snap(name: String) -> void:
	if only != "" and not only in name:
		return
	for i in 14:
		await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(out.path_join(name + ".png"))
	var said := Probe.measure(editor)
	states += 1
	if int(said["count"]) > 0:
		var size: Vector2 = said["smallest"]
		if size.x * size.y < smallest.x * smallest.y:
			smallest = size
		nearest = minf(nearest, said["nearest"])
		margin = minf(margin, said["margin"])
		foot = minf(foot, said["foot"])
	text = mini(text, said["text"])
	mark = minf(mark, said["mark"])
	mark_gap = minf(mark_gap, said["mark_gap"])
	print("SHOT %-26s %s" % [name, Probe.line(said)])
	for line: String in said["wrong"]:
		failed += 1
		print("    WRONG: ", line)


func down(by: float) -> void:
	await process_frame
	await process_frame
	await process_frame
	phone.scroller().offset = by
	phone.scroller().settle()


func page(which: String, with := {}, over := false) -> void:
	phone.open(which, with, over)
	await process_frame
	await process_frame


# Opens the list a row of the page opens, by pressing it as a finger would.
func press(key: String) -> void:
	await process_frame
	await process_frame
	var touch := phone.find(key)
	if touch == null:
		failed += 1
		print("    WRONG: there is no ", key)
		return
	touch.action.call()
	await process_frame
	await process_frame


func run() -> void:
	TombSpec.path = "user://shots_my_tombs.json"
	DirAccess.remove_absolute(ProjectSettings.globalize_path(TombSpec.path))
	TombEditor.layout = "phone"
	TombEditor.keeps = true
	for kept: Dictionary in [TombSpec.from_seed(5, 1), TombFloorSpec.from_seed(8, 1), TombSpec.fresh("The short one")]:
		TombSpec.keep(kept)
	editor = (load("res://tomb_editor.tscn") as PackedScene).instantiate() as TombEditor
	root.add_child(editor)
	await process_frame
	phone = editor._phone
	print("the screen is ", root.get_visible_rect().size)

	# A tomb down one axis.
	editor.take(TombSpec.fresh("My tomb"))
	editor.rebuild()
	editor.look_at_room(1)
	editor._hint_until = 0.0
	await snap("line_01_new")
	editor.take(TombSpec.from_seed(3, 2))
	editor.rebuild()
	editor.choose(3)
	editor.look_at_room(3)
	await snap("line_02_room")
	editor.look_at_all()
	await snap("line_03_all")
	editor.look_at_room(3)
	await page("room")
	await snap("line_04_page")
	await down(420.0)
	await snap("line_05_page_down")
	await down(9999.0)
	await snap("line_06_page_end")
	for key: String in ["role", "mummy", "way", "lock"]:
		await press("row:" + key)
		await snap("line_07_choice_%s" % key)
		if phone.scroller().most() > 0.0:
			await down(9999.0)
			await snap("line_07_choice_%s_end" % key)
		phone.back()
	editor.set_value("mummy", 1)
	await press("row:barrier")
	await snap("line_07_choice_barrier")
	phone.back()
	editor.set_value("lock", "lever_above")
	await press("row:stone_in")
	await snap("line_07_choice_stone")
	phone.back()
	await down(9999.0)
	await snap("line_08_page_stone")
	editor.undo()
	editor.undo()
	editor.choose(0)
	await snap("line_09_page_entrance")
	editor.choose(editor.rooms().size() - 1)
	await snap("line_09_page_burial")
	phone.close()
	editor.choose(3)
	await page("rooms")
	await snap("line_10_rooms")
	await page("tombs")
	await snap("line_11_tombs")
	await down(9999.0)
	await snap("line_11_tombs_end")
	await page("name", {}, true)
	await snap("line_12_name")
	phone.back()
	await page("generator", {}, true)
	await snap("line_13_generator")
	await down(9999.0)
	await snap("line_13_generator_end")
	phone.back()
	await page("share", {}, true)
	await snap("line_14_share")
	phone.back()
	await press("tomb:The short one:forget")
	await snap("line_15_forget")
	phone.close()
	await page("more")
	await snap("line_16_more")
	await page("help", {}, true)
	await snap("line_17_help")
	await page("works")
	await snap("line_18_works")
	phone.close()
	# Something wrong with it: said on the strip, and listed.
	editor.choose(5)
	editor.look_at_room(5)
	editor.set_value("way", "crawl")
	editor.set_value("lock", "work")
	editor.choose(2)
	editor.set_value("lock", "lever_below")
	editor.rebuild()
	editor._hint_until = 0.0
	await snap("line_19_wrong")
	await page("works")
	await snap("line_20_wrong_list")
	await page("room")
	await snap("line_21_wrong_page")
	phone.close()
	editor.undo()
	editor.undo()
	editor.undo()
	editor.remove()
	await snap("line_22_removed")

	# A tomb that branches.
	editor.take(TombFloorSpec.from_seed(3, 2))
	editor.rebuild()
	editor.look_at_all()
	editor._hint_until = 0.0
	await snap("floor_01_all")
	var pick := 1
	for i in range(1, editor.rooms().size()):
		if TombFloorSpec.free_sides(editor.spec, i).size() >= 2 and TombFloorSpec.fixed_because(editor.spec, i) == "":
			pick = i
	editor.choose(pick)
	editor.look_at_room(pick)
	await snap("floor_02_room")
	editor.look_at_all()
	await snap("floor_03_room_far")
	editor.zoom(2.2)
	await snap("floor_04_room_further")
	editor.start("move")
	editor.look_at_all()
	editor._hint_until = 0.0
	await snap("floor_05_move")
	editor.zoom(2.2)
	await snap("floor_06_move_far")
	await page("places")
	await snap("floor_07_places")
	phone.close()
	editor.look_at_room(pick)
	editor.start("join")
	editor._hint_until = 0.0
	await snap("floor_08_join")
	await page("joins")
	await snap("floor_09_joins")
	phone.close()
	editor.start("")
	await page("sides")
	await snap("floor_10_sides")
	phone.close()
	# (a room with a second way, and a lock that stands in another room)
	for pair: Array in editor.joinable():
		if not pair[1]:
			editor.join_with(pair[0])
			break
	editor.set_value("lock", "work")
	editor.rebuild()
	editor._hint_until = 0.0
	await page("room")
	await snap("floor_11_page")
	await down(520.0)
	await snap("floor_12_page_down")
	await down(9999.0)
	await snap("floor_13_page_end")
	for key: String in ["way", "lock", "lock_in"]:
		await press("row:" + key)
		await snap("floor_14_choice_%s" % key)
		if phone.scroller().most() > 0.0:
			await down(9999.0)
			await snap("floor_14_choice_%s_end" % key)
		phone.back()
	if phone.find("row:join0:door"):
		await press("row:join0:door")
		await snap("floor_14_choice_door")
		phone.back()
	phone.close()
	await page("rooms")
	await snap("floor_15_rooms")
	await page("works")
	await snap("floor_16_works")
	await page("more")
	await snap("floor_17_more")
	await page("help", {}, true)
	await snap("floor_18_help")
	phone.close()
	editor.take(TombFloorSpec.fresh("My branching tomb"))
	editor.rebuild()
	editor.look_at_all()
	editor.choose(4)
	editor._hint_until = 0.0
	await snap("floor_19_new")

	print("MEASURED over %d states: smallest thing to touch %.0f x %.0f, nearest two %.0f apart, %.0f from the sides, %.0f from the bottom, smallest words %d; marks on the plan at least %.0f across and %.0f apart" % [
		states, smallest.x, smallest.y, nearest, margin, foot, text, mark, mark_gap])
	print("OK" if failed == 0 else "WRONG: %d things" % failed)
	editor.queue_free()
	await process_frame
	DirAccess.remove_absolute(ProjectSettings.globalize_path(TombSpec.path))
	quit(0 if failed == 0 else 1)
