extends SceneTree
## Not part of the game. Pictures of Abu Simbel (scripts/abu_simbel.gd) and of its carved figures.
## godot --path . --resolution 1280x960 --script tools/abu_simbel_sheets.gd -- <outdir> [figures] [whole] [inside] [drift] [banded] [small=<scale>]
## Each picture is a file of its own in <outdir>. It prints what the whole costs: triangles, draw calls, build time.
## Add `--rendering-method gl_compatibility` before `--script` for the web's renderer.

var out := ""
var names: Array[String] = []
var stage: Node3D
var cam: Camera3D
var sun: DirectionalLight3D
var env: Environment
var size := 1.0
var temple: AbuSimbel
var player: Player


func _initialize() -> void:
	DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_NO_FOCUS, true)
	DisplayServer.window_set_position(Vector2i(-6000, -6000))
	var args := OS.get_cmdline_user_args()
	out = args[0]
	for i in range(1, args.size()):
		if args[i] == "banded":
			Settings.world_banded = true
		elif args[i].begins_with("small="):
			size = float(args[i].trim_prefix("small="))
		else:
			names.append(args[i])
	DirAccess.make_dir_recursive_absolute(out)
	stage = Node3D.new()
	root.add_child(stage)
	env = Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.5, 0.66, 0.86)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.7, 0.73, 0.8)
	env.ambient_light_energy = 0.75
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	var world := WorldEnvironment.new()
	world.environment = env
	stage.add_child(world)
	sun = DirectionalLight3D.new()
	sun.light_color = Color(1.0, 0.93, 0.8)
	sun.light_energy = 1.3 * (Desert.WEB_SUN if RenderingServer.get_current_rendering_method() == "gl_compatibility" else 1.0)
	sun.shadow_enabled = true
	sun.directional_shadow_max_distance = 400.0
	sun.shadow_normal_bias = 3.0
	stage.add_child(sun)
	morning()
	cam = Camera3D.new()
	cam.far = 4000.0
	stage.add_child(cam)
	cam.make_current()
	run.call_deferred()


## The sun low in the east (+Z is the river side), a little to the south.
func morning(high := 24.0, round := -28.0) -> void:
	sun.rotation_degrees = Vector3(-high, round, 0.0)


func wanted(name: String) -> bool:
	return names.is_empty() or names.has(name)


func shoot(name: String, from: Vector3, to: Vector3, fov := 45.0) -> void:
	cam.global_position = from
	cam.look_at(to)
	cam.fov = fov
	for i in 3:
		await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(out.path_join(name + ".png"))
	print("PICTURE ", name)


func ground() -> void:
	var floor := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(3000, 3000)
	floor.mesh = plane
	floor.material_override = Sand.surface()
	stage.add_child(floor)
	var body := StaticBody3D.new()
	var shape := WorldBoundaryShape3D.new()
	var collider := CollisionShape3D.new()
	collider.shape = shape
	body.add_child(collider)
	stage.add_child(body)


func run() -> void:
	ground()
	if names.has("figures"):
		await figures()
	await site()
	quit()


## Each figure by itself, from the front and three-quarters on.
func figures() -> void:
	var stone := Sandstone.surface(Color(0.74, 0.55, 0.38), 1.35, 2.3, 0.4, 0.3)
	var shots: Array = []
	for entry: Array in [["colossus", 1.0, 20.0], ["colossus_broken", 1.0, 10.0], ["colossus_fallen", 1.0, 20.0], ["king_standing", 8.0, 10.0], ["queen_standing", 8.0, 10.0],
			["osiride_pillar", 1.0, 10.5], ["ra_horakhty", 6.0, 7.5], ["god_ptah", 0.15, 3.0], ["god_amun", 0.15, 3.6], ["god_ra", 0.15, 3.6], ["hathor_pillar", 1.0, 4.4], ["baboon", 2.5, 2.6],
			["falcon", 2.0, 2.2], ["cow", 2.0, 2.8], ["small_figure", 5.0, 5.2]]:
		var began := Time.get_ticks_usec()
		var mesh := AbuSimbel.part(entry[0])
		print("FIGURE %-16s %5d triangles, made in %.1f ms" % [entry[0], mesh.get_faces().size() / 3, (Time.get_ticks_usec() - began) / 1000.0])
		var shown := MeshInstance3D.new()
		shown.mesh = mesh
		shown.material_override = stone
		shown.scale = Vector3.ONE * float(entry[1])
		stage.add_child(shown)
		var high: float = entry[2]
		await shoot("figure_%s_front" % entry[0], Vector3(0, high * 0.55, high * 2.2), Vector3(0, high * 0.5, 0), 34.0)
		await shoot("figure_%s_side" % entry[0], Vector3(high * 1.4, high * 0.6, high * 1.6), Vector3(0, high * 0.5, 0), 34.0)
		if entry[0] == "colossus":
			await shoot("figure_colossus_face", Vector3(1.5, 14.6, 16.0), Vector3(0, 15.6, 2.5), 30.0)
			await shoot("figure_colossus_face_side", Vector3(9.0, 15.0, 11.0), Vector3(0, 15.6, 2.5), 30.0)
			await shoot("figure_colossus_below", Vector3(3.0, 1.4, 17.0), Vector3(0, 12.0, 2.0), 50.0)
		shown.queue_free()
		shots.append("figure_%s_front" % entry[0])
		shots.append("figure_%s_side" % entry[0])
	sheet("figures", shots, 6, 330)


## Several pictures already taken, side by side in one (each made smaller).
func sheet(name: String, of: Array, columns := 4, wide := 400) -> void:
	var cells: Array[Image] = []
	for part: String in of:
		var image := Image.load_from_file(out.path_join(part + ".png"))
		if image:
			image.resize(wide, wide * image.get_height() / image.get_width(), Image.INTERPOLATE_LANCZOS)
			cells.append(image)
	if cells.is_empty():
		return
	var tall := cells[0].get_height()
	var page := Image.create(wide * columns, tall * ceili(cells.size() / float(columns)), false, cells[0].get_format())
	for i in cells.size():
		page.blit_rect(cells[i], Rect2i(0, 0, wide, tall), Vector2i((i % columns) * wide, (i / columns) * tall))
	page.save_png(out.path_join(name + ".png"))
	print("SHEET ", name)


## Stands the temples on the ground with these numbers, in place of the last.
func stand(numbers: Dictionary) -> AbuSimbel:
	if temple:
		temple.queue_free()
		await process_frame
	numbers["scale"] = size
	temple = AbuSimbel.from_item(numbers)
	stage.add_child(temple)
	await physics_frame
	await process_frame
	print("ABU SIMBEL %s: %d triangles (%d of them inside), %d draw calls, %d shapes, made in %.0f ms" % [numbers, temple.triangles, temple.inside_triangles, temple.draw_calls, temple.shapes, temple.build_ms])
	return temple


func boy(at: Vector3, turn := 0.0) -> void:
	if player == null:
		var touch := TouchControls.new()
		touch.visible = false
		stage.add_child(touch)
		touch.set_process_input(false)
		player = load("res://player.tscn").instantiate()
		player.rest_enabled = false
		stage.add_child(player)
		player.set_process_unhandled_input(false)
		for action: StringName in InputMap.get_actions():
			if not String(action).begins_with("ui_"):
				InputMap.action_erase_events(action)
	player.global_position = at
	player.velocity = Vector3.ZERO
	player.rotation.y = turn
	for i in 20:
		await physics_frame


## Night outside or day: inside, the temple makes its own dark.
func site() -> void:
	var s := size
	if wanted("whole"):
		await stand({"drift": 0.35})
		await boy(Vector3(3.0, 1.3, 14.0) * s)
		morning()
		await shoot("whole_from_the_river", Vector3(70, 14, 150) * s, Vector3(40, 16, 0) * s, 42.0)
		await shoot("whole_from_the_south", Vector3(-70, 22, 110) * s, Vector3(30, 14, -10) * s, 46.0)
		await shoot("great_facade", Vector3(0, 16, 78) * s, Vector3(0, 17, 0) * s, 40.0)
		await shoot("great_facade_boy", Vector3(-8, 3.0, 34) * s, Vector3(2, 9.0, 0) * s, 50.0)
		await shoot("colossus_from_below", Vector3(9.5, 2.8, 15.0) * s, Vector3(13.4, 15.5, 2.0) * s, 48.0)
		await shoot("colossus_face", Vector3(10.0, 13.5, 20.0) * s, Vector3(13.4, 16.6, 3.0) * s, 30.0)
		await shoot("fallen_head", Vector3(-12.0, 3.2, 24.0) * s, Vector3(-6.0, 3.0, 12.0) * s, 50.0)
		await shoot("fallen_head_above", Vector3(-2.0, 12.0, 22.0) * s, Vector3(-6.0, 2.0, 12.0) * s, 50.0)
		await shoot("terrace", Vector3(22.0, 5.0, 26.0) * s, Vector3(0.0, 4.0, 10.0) * s, 50.0)
		var north := Transform3D(Basis(Vector3.UP, deg_to_rad(AbuSimbel.NORTH_TURN)), AbuSimbel.NORTH * s)
		await boy(north * (Vector3(2.0, 0.7, 6.0) * s))
		await shoot("small_facade", north * (Vector3(0, 7, 36) * s), north * (Vector3(0, 7, 0) * s), 40.0)
		await shoot("small_facade_near", north * (Vector3(-9, 2.2, 13) * s), north * (Vector3(-3, 6, 0) * s), 50.0)
		await shoot("hill_from_behind", Vector3(-90, 40, -150) * s, Vector3(30, 14, -40) * s, 46.0)
		await stand({"drift": 0.35, "which": 1})
		await shoot("great_alone", Vector3(40, 14, 110) * s, Vector3(0, 16, 0) * s, 42.0)
		await stand({"drift": 0.35, "which": 2})
		await shoot("small_alone", Vector3(20, 8, 70) * s, Vector3(0, 9, 0) * s, 42.0)
	if wanted("inside"):
		await stand({"drift": 0.0, "sun": false})
		await boy(Vector3(1.0, 1.3, -8.0) * s, PI)
		await shoot("hall_looking_in", Vector3(0.0, 3.0, -4.5) * s, Vector3(0.0, 4.0, -40.0) * s, 62.0)
		await shoot("hall_pillars", Vector3(-1.8, 2.2, -5.0) * s, Vector3(3.5, 6.0, -14.0) * s, 62.0)
		await shoot("hall_looking_out", Vector3(0.6, 2.6, -20.0) * s, Vector3(0.0, 3.6, 0.0) * s, 62.0)
		await shoot("hall_relief", Vector3(-7.6, 2.4, -4.6) * s, Vector3(-8.2, 4.6, -15.0) * s, 62.0)
		await shoot("second_hall", Vector3(0.0, 2.4, -23.5) * s, Vector3(0.0, 2.6, -50.0) * s, 62.0)
		await boy(Vector3(-1.3, 1.3, -39.6) * s, PI)
		await shoot("sanctuary_dark", Vector3(0.0, 2.1, -37.4) * s, Vector3(0.0, 1.9, -44.0) * s, 60.0)
		await stand({"drift": 0.0, "sun": true})
		for i in 20:
			await physics_frame
		print("  with the sun on the axis the sanctuary is on: ", temple.on, " (the light ends at ", temple.to_local(temple.beam.path[temple.beam.path.size() - 1]) if temple.beam.path.size() > 0 else Vector3.ZERO, " on ", temple.beam.ends_on, ")")
		await shoot("sanctuary_sun", Vector3(0.0, 2.1, -37.4) * s, Vector3(0.0, 1.9, -44.0) * s, 60.0)
		await shoot("sanctuary_sun_near", Vector3(-0.9, 2.4, -40.0) * s, Vector3(0.3, 2.2, -44.0) * s, 60.0)
		await shoot("hall_sun", Vector3(-2.2, 3.2, -5.0) * s, Vector3(0.6, 3.0, -40.0) * s, 62.0)
		var north := Transform3D(Basis(Vector3.UP, deg_to_rad(AbuSimbel.NORTH_TURN)), AbuSimbel.NORTH * s)
		await boy(north * (Vector3(1.0, 0.7, -6.0) * s), PI)
		await shoot("small_hall", north * (Vector3(0.0, 1.9, -2.8) * s), north * (Vector3(0.0, 2.0, -20.0) * s), 66.0)
		await shoot("small_hall_out", north * (Vector3(0.5, 1.8, -12.5) * s), north * (Vector3(0.0, 2.0, 0.0) * s), 66.0)
		await shoot("small_sanctuary", north * (Vector3(0.0, 1.7, -17.2) * s), north * (Vector3(0.0, 1.5, -22.0) * s), 62.0)
		sheet("inside", ["hall_looking_in", "hall_pillars", "hall_looking_out", "hall_relief", "second_hall", "sanctuary_dark", "sanctuary_sun", "sanctuary_sun_near", "hall_sun", "small_hall", "small_hall_out", "small_sanctuary"], 3, 640)
	if wanted("drift"):
		for amount: float in [0.0, 0.5, 1.0]:
			await stand({"drift": amount})
			await boy(Vector3(-4.0, 1.3, 15.0) * s)
			await shoot("drift_%.1f" % amount, Vector3(20, 22, 120) * s, Vector3(34, 12, 0) * s, 44.0)
			await shoot("drift_%.1f_facade" % amount, Vector3(-18, 9, 62) * s, Vector3(6, 12, 0) * s, 44.0)
		await shoot("drift_1.0_door", Vector3(-6.0, 9.0, 12.0) * s, Vector3(0.0, 6.5, 0.0) * s, 50.0)
		sheet("drift", ["drift_0.0", "drift_0.5", "drift_1.0", "drift_0.0_facade", "drift_0.5_facade", "drift_1.0_facade"], 3, 640)
