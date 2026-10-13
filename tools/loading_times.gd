extends SceneTree
## Not part of the game. Says where the time goes when a level is opened.
## One level to a run, so that nothing is already in memory:
## godot --headless --path . --script tools/loading_times.gd -- res://desert.tscn [through] [tomb=12:1 view=3d shape=branching]
##
## With nothing more said the level is opened as it was before there was a notebook page for it (and as
## the tools still open it): its file read, its nodes made, its `_ready` (the level building itself in
## code, all in one go), and each of the first frames after. With `through` it is opened by `Loading`
## behind the page: how long that took in all (the page coming and going is in it), how long the
## page was fully up, the longest the page stood still, and each stage. Windowed (leave out
## --headless) the times include the first drawing of everything, which is most of what a phone waits for.
## The desert is the one the game came with, not the one kept on this device.


func _initialize() -> void:
	if DisplayServer.get_name() != "headless":
		DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_NO_FOCUS, true)
		DisplayServer.window_set_position(Vector2i(-6000, -6000))
	run.call_deferred()


func run() -> void:
	var path := OS.get_cmdline_user_args()[0]
	TombLevel.bare = true
	LevelLayout.saved_at = "user://loading_times_none.json"
	for i in 3:
		await process_frame
	if OS.get_cmdline_user_args().has("through"):
		Loading.instant = false
		Loading.go(path, "", true)
		await Loading.page().finished
		print("THROUGH %s  all %d ms  page up %d ms  longest still %d ms  frames let go by while building %d ms" % [path, Loading.took["all"], Loading.took["up"], Loading.took["longest"], Loading.took["frames"]])
		for stage: String in Loading.stages:
			print("  STAGE %-28s %5d ms" % [stage, Loading.stages[stage]])
		quit()
		return
	Loading.stages.clear()
	var t0 := Time.get_ticks_usec()
	var packed := ResourceLoader.load(path) as PackedScene
	var t1 := Time.get_ticks_usec()
	var scene := packed.instantiate()
	var t2 := Time.get_ticks_usec()
	root.add_child(scene)
	current_scene = scene
	var t3 := Time.get_ticks_usec()
	var after := PackedFloat32Array()
	var last := t3
	# (until three frames in a row have been quick, as `Loading` waits)
	var quiet := 0
	var settled := 0
	while after.size() < 90 and settled == 0:
		await process_frame
		var now := Time.get_ticks_usec()
		after.append((now - last) / 1000.0)
		quiet = quiet + 1 if now - last < Loading.QUIET * 1000 else 0
		last = now
		if after.size() >= 5 and quiet >= 3:
			settled = now
	var text := ""
	for ms in after:
		text += "%d " % roundi(ms)
	print("TIMES %s  file %d ms  nodes %d ms  ready %d ms  frames after: %s  all %d ms" % [path, (t1 - t0) / 1000, (t2 - t1) / 1000, (t3 - t2) / 1000, text, (settled - t0) / 1000])
	for stage: String in Loading.stages:
		print("  STAGE %-28s %5d ms" % [stage, Loading.stages[stage]])
	quit()
