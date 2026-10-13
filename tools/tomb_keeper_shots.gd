extends SceneTree
## Not part of the game. Pictures of the creatures in a tomb as he meets them,
## through the game's own camera: he is stood before each leaf of the Book,
## gate guardian, sphinx and Medjed of a tomb in turn, a little way off and
## then close to.
## godot --path . --fixed-fps 60 --resolution 1280x720 --script tools/tomb_keeper_shots.gd -- <folder> [side|3d|branching] [<seed>:<difficulty> | keepers] [name=<prefix>]
## (add `--rendering-method gl_compatibility --rendering-driver opengl3` for the web's renderer)

const Shapes := preload("res://tools/tomb_shapes.gd")

var folder := ""
var view := "side"
var shape := "line"
var tomb := "keepers"
var prefix := ""


func _initialize() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg in ["side", "3d"]:
			view = arg
		elif arg == "branching":
			view = "3d"
			shape = "branching"
		elif arg.begins_with("name="):
			prefix = arg.trim_prefix("name=")
		elif folder == "":
			folder = arg
		else:
			tomb = arg
	if folder == "":
		print("say where to put the pictures")
		quit(1)
		return
	DirAccess.make_dir_recursive_absolute(folder)
	DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_NO_FOCUS, true)
	DisplayServer.window_set_position(Vector2i(-6000, -6000))
	if prefix == "":
		prefix = "%s_%s" % ["branching" if shape == "branching" else view, tomb.replace(":", "_")]
	_run.call_deferred()


func _run() -> void:
	TombLevel.bare = true
	if tomb.contains(":"):
		var parts := tomb.split(":")
		TombLevel.play = {"mode": "random", "seed": int(parts[0]), "difficulty": int(parts[1]), "view": view, "shape": shape}
	else:
		TombLevel.play = {"mode": "custom", "spec": Shapes.keepers(), "view": view}
	var scene: Node = load("res://tomb.tscn").instantiate()
	root.add_child(scene)
	var player: Player = scene.get_node("Player")
	var level: TombLevel = scene.get_node("Level")
	var camera := scene.get_node_or_null("Camera") as FollowCamera
	player.set_process_unhandled_input(false)
	await _wait(40)
	var layout := level.layout
	var count := 0
	for part in layout.parts:
		var kind: String = part["kind"]
		if not kind in ["leaf", "guardian", "sphinx", "medjed"]:
			continue
		# Where he stands to meet it: where the layout says its switch is worked,
		# or for Medjed at the door he looks at; and from which way he comes to it.
		var at: Vector3 = part["at"]
		var stand := at
		if part.has("trigger"):
			stand = layout.switch_at[part["trigger"]]
		elif part.has("stand"):
			stand = part["stand"]
		var back := Vector3.LEFT
		if layout is TombLayout3D:
			var room: Dictionary = layout.rooms[layout.plan_room_at(stand)]
			if part.has("link"):
				back = -Vector3(TombLayout3D.TURNS[int((layout as TombLayout3D).ways[part["link"]]["turn"])])
			elif room.has("turn"):
				back = -Vector3(TombLayout3D.TURNS[int(room["turn"])])
		for far: float in ([3.2, 1.3, 0.0] if kind == "sphinx" else [3.2, 1.3]):
			var spot := stand + back * far
			if kind == "leaf":
				spot = stand + back * (far + 0.4)
			player.global_position = spot + Vector3.UP * 0.1
			player.velocity = Vector3.ZERO
			if camera and layout is TombLayout3D:
				camera.look_along(-back)
				camera.snap()
			await _wait(70)
			# (he does not ask, and is not asked: the picture is of what he sees)
			if is_instance_valid(GuardianPanel.current):
				await _shot("%s_%02d_%s_asked" % [prefix, count, kind])
				GuardianPanel.current.choose(-1)
				await _wait(20)
				continue
			await _shot("%s_%02d_%s_%s" % [prefix, count, kind, "far" if far > 2.0 else ("near" if far > 0.5 else "at")])
		count += 1
	print("%d of them in %s" % [count, prefix])
	quit()


func _wait(frames: int) -> void:
	for i in frames:
		await physics_frame


func _shot(name: String) -> void:
	await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(folder.path_join(name + ".png"))
	print("  saved ", name)
