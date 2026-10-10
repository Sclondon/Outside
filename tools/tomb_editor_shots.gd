extends SceneTree
## Not part of the game. Pictures of the tomb editor, to see that it can be read and used.
## godot --path . --fixed-fps 60 --resolution 1280x720 --script tools/tomb_editor_shots.gd -- <outdir>

var out := ""


func _initialize() -> void:
	DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_NO_FOCUS, true)
	DisplayServer.window_set_position(Vector2i(-6000, -6000))
	out = OS.get_cmdline_user_args()[0]
	DirAccess.make_dir_recursive_absolute(out)
	run.call_deferred()


func snap(name: String) -> void:
	for i in 12:
		await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(out.path_join(name + ".png"))
	print("SHOT ", name)


func run() -> void:
	TombEditor.keeps = false
	var editor := (load("res://tomb_editor.tscn") as PackedScene).instantiate() as TombEditor
	root.add_child(editor)
	await process_frame
	editor.take(TombSpec.fresh())
	editor.rebuild()
	editor.look_at_room(1)
	await snap("1_new")
	editor.take(TombSpec.from_seed(3, 2))
	editor.rebuild()
	editor.choose(3)
	editor.look_at_room(3)
	await snap("2_room")
	editor.look_at_all()
	await snap("3_all")
	editor.choose(5)
	editor.look_at_room(5)
	editor.set_value("way", "crawl")
	editor.set_value("lock", "work")
	editor.rebuild()
	await snap("4_wrong")
	editor.undo()
	editor.undo()
	editor.show_way()
	await snap("5_way")
	editor.show_tombs(true)
	await snap("6_tombs")
	quit()
