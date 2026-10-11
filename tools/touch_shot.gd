extends SceneTree
## Not part of the game. A picture of the touch controls over a level, as a
## phone shows them: before the camera has been turned, and while it is.
## godot --path . --fixed-fps 60 --resolution 1280x720 --script tools/touch_shot.gd -- <folder> [scene]


func _initialize() -> void:
	DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_NO_FOCUS, true)
	DisplayServer.window_set_position(Vector2i(-6000, -6000))
	run.call_deferred()


func run() -> void:
	var args := OS.get_cmdline_user_args()
	var scene := args[1] if args.size() > 1 else "res://test_yard.tscn"
	# (a third word: a branching tomb, straight in, to see its map beside the controls)
	if args.size() > 2:
		TombLevel.play = {"mode": "random", "seed": 3, "difficulty": 2, "shape": "branching"}
		TombLevel.bare = true
	change_scene_to_file(scene)
	for i in 90:
		await process_frame
	var touch := root.get_tree().get_first_node_in_group(&"touch_controls") as TouchControls
	touch._hint_alpha = 1.0
	TouchControls._look_known = false
	for i in 5:
		await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(args[0].path_join("touch_before.png"))
	# A finger comes down on the right and drags: the camera turns.
	var from := Vector2(900.0, 300.0)
	var down := InputEventScreenTouch.new()
	down.index = 3
	down.position = from
	down.pressed = true
	Input.parse_input_event(down)
	for i in 20:
		var drag := InputEventScreenDrag.new()
		drag.index = 3
		drag.position = from + Vector2(8.0 * (i + 1), 0.0)
		drag.relative = Vector2(8.0, 0.0)
		Input.parse_input_event(drag)
		await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(args[0].path_join("touch_looking.png"))
	var camera := root.get_camera_3d() as FollowCamera
	print("LOOK known=", TouchControls._look_known, " jump=", touch.jump_held, " yaw=", camera._yaw if camera else 0.0)
	quit()
