extends SceneTree
## Not part of the game. Pictures of what a tomb that branches adds to the screen, to be looked at:
## godot --path . --fixed-fps 60 --resolution 1280x720 --script tools/tomb_branch_shots.gd -- <folder> [seed:difficulty] [name=<prefix>]
##
##   <prefix>card.png        the card that comes up first, with "Branching" chosen
##   <prefix>hud_start.png   the HUD as he starts: the map in its corner with the court alone on it
##   <prefix>hud_some.png    the same when he has been through about half the rooms on the way to the falcon
##   <prefix>hud_large.png   the map made large by a touch
##   <prefix>fork_<n>.png    what he sees at the far end of each room that has more than one way on (up to four)
##   <prefix>loop.png        what he sees where a second way comes into a room, if the tomb has one
##   <prefix>editor_*.png    the tomb editor's floor plan: all of a tomb, a room chosen with the places a new room
##                           could go, the places it could be moved to, the rooms it could be joined to, and the
##                           tomb a new one starts as
## (The tomb is 3:2 unless another is named. Its window is kept off the screen; the player's own files are not
## touched: what is kept of a day is read from a file of the tool's own, and the editor keeps nothing.)

var out := ""
var seed_value := 3
var difficulty := 2
var prefix := ""
var scene: Node
var level: TombLevel
var player: Player
var camera: FollowCamera


func _initialize() -> void:
	DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_NO_FOCUS, true)
	DisplayServer.window_set_position(Vector2i(-6000, -6000))
	var args := OS.get_cmdline_user_args()
	out = args[0] if not args.is_empty() else "."
	for arg: String in args.slice(1):
		if arg.begins_with("name="):
			prefix = arg.trim_prefix("name=")
		else:
			var said := arg.split(":")
			seed_value = int(said[0])
			difficulty = int(said[1]) if said.size() > 1 else 1
	DirAccess.make_dir_recursive_absolute(out)
	run.call_deferred()


func snap(name: String, frames := 12) -> void:
	for i in frames:
		await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(out.path_join(prefix + name + ".png"))
	print("SHOT ", prefix + name)


func _open(chosen: Dictionary) -> void:
	TombLevel.play = chosen
	scene = load("res://tomb.tscn").instantiate()
	root.add_child(scene)
	for i in 10:
		await process_frame
	level = scene.get_node("Level")
	player = scene.get_node("Player")
	camera = scene.get_node("Camera")
	player.sleep_after = 0.0
	(scene.get_node("HUD/TouchControls") as Control).set_process_input(false)
	player.set_process_unhandled_input(false)


func _close() -> void:
	scene.queue_free()
	for i in 4:
		await process_frame


# Stands him at a place, having come `along`, and lets the level see him there.
func _stand(spot: Vector3, along: Vector3, frames := 40) -> void:
	player.global_position = spot + Vector3.UP * 0.05
	player.velocity = Vector3.ZERO
	player.facing_yaw = atan2(along.x, along.z)
	player.set_spawn(player.global_position)
	camera.look_along(along)
	camera._pitch = 0.3
	camera.snap()
	for i in frames:
		await physics_frame


func run() -> void:
	TombDaily.path = "user://tombs_shots.json"
	TombEditor.keeps = false

	# The card: today's tomb that branches behind it.
	TombLevel.bare = false
	TombLevel.last_view = "3d"
	TombLevel.last_shape = "branching"
	await _open({})
	await snap("card", 20)
	await _close()

	# The HUD and its map.
	await _open({"mode": "random", "seed": seed_value, "difficulty": difficulty, "shape": "branching"})
	var layout := level.layout as TombLayout3D
	var plan := level.plan
	await snap("hud_start", 30)
	# (the rooms of the solver's way in, as far as the falcon; he is stood in the first half of them)
	var way: Array = []
	for step: Array in plan.solution:
		if step[0] == "do" and plan.triggers[step[1]].kind == TombPlan.Switch.TREASURE:
			break
		if step[0] == "go" and not step[3] in way:
			way.append(step[3])
	for n in maxi(way.size() / 2, 2):
		var info := layout.rooms[way[n]]
		if info.has("west"):
			await _stand(info["west"], Vector3(TombLayout3D.TURNS[int(info["turn"])]), 14)
			if info.has("east"):
				await _stand(info["east"], Vector3(TombLayout3D.TURNS[int(info["turn"])]), 14)
	await snap("hud_some", 20)
	level._map.toggle()
	await snap("hud_large", 10)
	level._map.toggle()

	# Forks: the far end of each room with more than one way on. And a loop: where a second way comes in.
	var forks := 0
	var loop := false
	var entered := {}
	(scene.get_node("HUD") as CanvasLayer).visible = false
	for link in plan.links:
		if TombLayout3D.is_side(plan.rooms[link.a]) or TombLayout3D.is_side(plan.rooms[link.b]):
			continue
		if entered.has(link.b) and not loop:
			# (a second way into this room: seen from the bay it comes into, looking back along it)
			var info := layout.rooms[link.b]
			var into := Vector3(TombLayout3D.TURNS[int(layout.ways[link.id]["turn"])])
			await _stand((info["centre"] as Vector3) + into * 0.8, -into)
			await snap("loop", 30)
			loop = true
		entered[link.b] = true
	for room in layout.placed():
		var ways_on := 0
		for link in plan.links:
			if link.a == room.id and not TombLayout3D.is_side(plan.rooms[link.b]):
				ways_on += 1
		if ways_on < 2 or forks >= 4 or room.id == plan.entrance():
			continue
		var info := layout.rooms[room.id]
		var along := Vector3(TombLayout3D.TURNS[int(info["turn"])])
		# (from a little before the bay, so that the ways off it to either side are in the picture)
		await _stand((info["east"] as Vector3) - along * 4.5, along)
		forks += 1
		await snap("fork_%d" % forks, 30)
	await _close()

	# The editor's floor plan.
	var editor := (load("res://tomb_editor.tscn") as PackedScene).instantiate() as TombEditor
	root.add_child(editor)
	await process_frame
	editor.take(TombFloorSpec.from_seed(seed_value, difficulty))
	editor.rebuild()
	editor.look_at_all()
	await snap("editor_1_all")
	# (a room with a free side, and another beside it to join to if there is one)
	var pick := 1
	for i in range(1, editor.rooms().size()):
		if not TombFloorSpec.free_sides(editor.spec, i).is_empty() and TombFloorSpec.fixed_because(editor.spec, i) == "":
			pick = i
	editor.choose(pick)
	editor.look_at_room(pick)
	await snap("editor_2_room")
	editor.start("move")
	editor.look_at_all()
	await snap("editor_3_move")
	editor.start("join")
	await snap("editor_4_join")
	editor.start("")
	editor.show_way()
	await snap("editor_5_way")
	editor._close_sheet()
	editor.take(TombFloorSpec.fresh())
	editor.rebuild()
	editor.look_at_all()
	editor.choose(4)
	await snap("editor_6_new")
	editor.show_tombs(true)
	await snap("editor_7_tombs")
	DirAccess.remove_absolute(TombDaily.path)
	quit()
