extends SceneTree
## Not part of the game. Pictures of temples made by scripts/temple.gd, each on bare
## ground of its own, and what each costs.
## godot --path . --resolution 1280x960 --script tools/temple_sheets.gd -- <outdir> [banded] [name ...]
##
## The names: `edfu`, `luxor`, `kom_ombo`, `custom` (each plan: from the air, straight
## down as a plan, the way up to it at the height of his eye with him standing there
## for scale, the face of the pylon, in the court, in the hall of columns, the
## sanctuary); `capitals` (each capital close to); `ruin` and `buried` (Edfu and Luxor
## at several values of each); `painted`; `small` (each plan at half size). With no
## name, all of them. Two pictures to a row, four to a sheet (temple_NN.png).
## Prints for each temple its triangles, shapes and how long it took to build, and for
## each picture how many draw calls and triangles the frame had.
## Add `--rendering-method gl_compatibility` before `--script` for the web's renderer.

const CELL := Vector2i(800, 600)

var out := ""
var only: Array = []
var stage: Node3D
var cam: Camera3D
var sun: DirectionalLight3D
var boy: Node3D
var cells: Array[Image] = []
var names: Array = []
var page := 0


func _initialize() -> void:
	DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_NO_FOCUS, true)
	DisplayServer.window_set_position(Vector2i(-6000, -6000))
	var args := OS.get_cmdline_user_args()
	out = args[0]
	only = args.slice(1)
	if "banded" in only:
		only.erase("banded")
		Settings.world_banded = true
	DirAccess.make_dir_recursive_absolute(out)
	stage = Node3D.new()
	root.add_child(stage)
	var env := Environment.new()
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
	sun.rotation_degrees = Vector3(-46.0, 150.0, 0.0)
	sun.light_color = Color(1.0, 0.95, 0.85)
	sun.light_energy = 1.3 * (Desert.WEB_SUN if RenderingServer.get_current_rendering_method() == "gl_compatibility" else 1.0)
	sun.shadow_enabled = true
	sun.directional_shadow_max_distance = 260.0
	sun.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_2_SPLITS
	stage.add_child(sun)
	var ground := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(4000, 4000)
	ground.mesh = plane
	var sand := StandardMaterial3D.new()
	sand.albedo_color = Color(0.82, 0.7, 0.5)
	sand.roughness = 1.0
	sand.metallic_specular = 0.0
	ground.material_override = sand
	stage.add_child(ground)
	cam = Camera3D.new()
	cam.fov = 40.0
	cam.far = 4000.0
	stage.add_child(cam)
	cam.make_current()
	# Him, for scale: the model the Player wears, standing still.
	var player := (load("res://player.tscn") as PackedScene).instantiate()
	player.set_script(null)
	player.process_mode = Node.PROCESS_MODE_DISABLED
	boy = player
	stage.add_child(boy)
	run.call_deferred()


func wanted(name: String) -> bool:
	return only.is_empty() or name in only


func stand(numbers: Dictionary) -> Temple:
	var temple := Temple.from_item(numbers)
	stage.add_child(temple)
	var first := temple.build_ms
	temple.build()
	print("TEMPLE %-9s size %.2f ruin %.2f buried %.2f: %.0f x %.0f m, %.0f m high; %d columns; %6d triangles near, %6d far; %4d shapes; built in %.0f ms (again in %.0f ms); open=%s %s" % [
		numbers.get("what", "custom"), temple.size, temple.ruin, temple.buried, temple.length, temple.breadth, temple.height, temple.columns, temple.triangles, temple.triangles_far, temple.shapes, first, temple.build_ms, temple.open, temple.shut_by])
	return temple


func run() -> void:
	# What a frame costs with no temple in it: him, the ground and their shadows.
	place_boy(Vector3(0.0, 0.0, 0.0))
	cam.global_position = Vector3(0.0, 1.5, 6.0)
	cam.look_at(Vector3(0.0, 1.0, 0.0))
	for i in 4:
		await process_frame
	await RenderingServer.frame_post_draw
	print("EMPTY: draw calls %d  triangles %d (%s)" % [Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME), Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME), RenderingServer.get_current_rendering_method()])
	for what: String in ["edfu", "luxor", "kom_ombo", "custom"]:
		if wanted(what):
			await plan({"what": what} if what != "custom" else {"what": "custom", "nave": 5.0, "capital": 0, "obelisks": 2, "colossi": 2, "lake": true}, what)
	if wanted("small"):
		for what: String in ["edfu", "luxor", "kom_ombo"]:
			await plan({"what": what, "size": 0.5}, what + " half size", true)
	if wanted("capitals"):
		await capitals()
	if wanted("ruin"):
		for what: String in ["edfu", "luxor", "kom_ombo"]:
			for ruin: float in [0.3, 0.6, 0.9]:
				var temple := stand({"what": what, "ruin": ruin, "seed": 3})
				await air("%s ruin %.1f" % [what, ruin], temple)
				await inside("%s ruin %.1f, in the hall" % [what, ruin], temple, 2)
				temple.queue_free()
				await process_frame
	if wanted("buried"):
		for what: String in ["edfu", "luxor"]:
			for buried: float in [0.25, 0.5, 0.8]:
				var temple := stand({"what": what, "buried": buried, "ruin": 0.15})
				await air("%s buried %.2f" % [what, buried], temple)
				await approach("%s buried %.2f" % [what, buried], temple)
				temple.queue_free()
				await process_frame
	if wanted("painted"):
		for painted: float in [0.0, 0.5, 1.0]:
			var temple := stand({"what": "edfu", "painted": painted})
			await face("edfu painted %.1f" % painted, temple)
			await inside("edfu painted %.1f, the court" % painted, temple, 1, true)
			temple.queue_free()
			await process_frame
	if not cells.is_empty():
		sheet()
	quit()


## One plan, from everywhere.
func plan(numbers: Dictionary, name: String, few := false) -> void:
	var temple := stand(numbers)
	await air(name, temple)
	if not few:
		await above(name, temple)
	await approach(name, temple)
	await face(name, temple)
	if not few:
		var doorways := temple.get_tree().get_nodes_in_group(&"temple_doorways").filter(func(node: Node) -> bool: return node.get_parent() == temple)
		await inside(name + ", the court", temple, 1, true)
		await inside(name + ", the court, looking back", temple, 1, true, true)
		for i in range(1, mini(doorways.size(), 9)):
			await inside("%s, inside doorway %d" % [name, i], temple, i)
		for marker: Node in temple.get_tree().get_nodes_in_group(&"temple_sanctuary"):
			if marker.get_parent() == temple:
				var at: Vector3 = marker.global_position
				place_boy(at + Vector3(0.9, 0.0, -0.6))
				await shoot(name + ", the sanctuary", at + Vector3(0.0, 1.25, 3.2), at + Vector3(0.0, 1.6, -4.0), 62.0)
		for marker: Node in temple.get_tree().get_nodes_in_group(&"temple_pylon_top"):
			if marker.get_parent() == temple:
				var at: Vector3 = marker.global_position
				await shoot(name + ", from the pylon", at + Vector3(0.0, 1.3, 0.0), Vector3(0.0, 4.0, -temple.length * 0.3), 70.0)
				break
	temple.queue_free()
	await process_frame


func place_boy(at: Vector3, facing := 0.0) -> void:
	boy.global_position = at
	boy.rotation.y = facing


func air(name: String, temple: Temple) -> void:
	place_boy(Vector3(3.0, 0.0, temple.length * 0.5 + 12.0))
	var reach := maxf(temple.length, temple.breadth)
	await shoot(name + ", from the air", Vector3(reach * 0.62, reach * 0.5, temple.length * 0.5 + reach * 0.52), Vector3(0.0, temple.height * 0.2, -temple.length * 0.05), 40.0)


## Straight down, the front at the bottom: to lay beside a plan of the real one.
func above(name: String, temple: Temple) -> void:
	var reach := maxf(temple.length + 50.0, temple.breadth * 1.4)
	cam.global_position = Vector3(0.0, reach * 2.6, 5.0)
	cam.global_transform.basis = Basis(Vector3.RIGHT, Vector3.FORWARD, Vector3.UP)
	await shoot(name + ", plan", Vector3.INF, Vector3.INF, 22.0)


func approach(name: String, temple: Temple) -> void:
	var from := Vector3(-4.0, 1.2, temple.length * 0.5 + maxf(temple.height * 1.6, 30.0))
	place_boy(Vector3(-2.2, 0.0, from.z - 5.0), PI)
	await shoot(name + ", the way up to it, from his eye", from, Vector3(0.0, temple.height * 0.42, temple.length * 0.5), 62.0)


func face(name: String, temple: Temple) -> void:
	place_boy(Vector3(2.5, Temple.PAVE, temple.length * 0.5 + 3.0))
	await shoot(name + ", the pylon", Vector3(0.0, temple.height * 0.45, temple.length * 0.5 + maxf(temple.breadth * 0.75, 30.0)), Vector3(0.0, temple.height * 0.42, temple.length * 0.5), 50.0)


## From just inside a doorway, at his eye, looking on down the axis (or, `back`, the way he came).
func inside(name: String, temple: Temple, doorway: int, wide := false, back := false) -> void:
	var doorways := temple.get_tree().get_nodes_in_group(&"temple_doorways").filter(func(node: Node) -> bool: return node.get_parent() == temple)
	if doorway >= doorways.size():
		return
	var at: Vector3 = doorways[doorway].global_position
	var thick: float = doorways[doorway].get_meta(&"thick", 1.0)
	if wide:
		at = (doorways[doorway - 1].global_position + at) * 0.5
		at.x = doorways[doorway].global_position.x + 3.0
	else:
		at.z -= thick * 0.5 + 1.5
	place_boy(at + Vector3(1.0, 0.0, 4.0 if back else -4.0))
	await shoot(name, at + Vector3(0.0, 1.25, 0.0), at + Vector3(-0.8, 3.0 if back else 2.2, 14.0 if back else -14.0), 68.0)


## Each capital close to, and then every other model, as it comes from Blender.
func capitals() -> void:
	var holder := Node3D.new()
	stage.add_child(holder)
	var stone := TempleStone.surface(Sandstone.COLOUR, 0.9, 3.0, 0.3, 0.6)
	var show := func(named: String, at: Vector3, by := 1.0) -> void:
		var model := MeshInstance3D.new()
		model.mesh = TempleParts.model(named)
		model.material_override = stone
		model.position = at
		model.scale = Vector3.ONE * by
		holder.add_child(model)
		print("MODEL %-22s %5d triangles, %s" % [named, model.mesh.surface_get_array_len(0) / 3, TempleParts.bounds(named).size])
	for kind in 4:
		show.call(TempleParts.COLUMNS[kind], Vector3(kind * 5.0 - 7.5, 0.0, 0.0))
		show.call(TempleParts.COLUMNS[kind] + "_far", Vector3(kind * 5.0 - 7.5, 0.0, -6.0))
	place_boy(Vector3(-10.0, 0.0, 0.5))
	await shoot("capitals: bud, open, composite, Hathor (behind: far off)", Vector3(-2.0, 5.0, 26.0), Vector3(0.0, 5.0, 0.0), 44.0)
	await shoot("capitals: bud, open", Vector3(-5.0, 6.5, 9.0), Vector3(-5.0, 8.4, 0.0), 44.0)
	await shoot("capitals: composite, Hathor", Vector3(5.0, 6.5, 9.0), Vector3(5.0, 8.4, 0.0), 44.0)
	await shoot("capitals from below", Vector3(0.0, 1.2, 7.0), Vector3(0.0, 8.5, 0.0), 75.0)
	for child in holder.get_children():
		child.queue_free()
	show.call("colossus_seated", Vector3(-12.0, 0.0, 0.0))
	show.call("colossus_standing", Vector3(-4.0, 0.0, 0.0))
	show.call("falcon", Vector3(2.0, 0.0, 0.0))
	show.call("naos", Vector3(6.0, 0.0, 0.0))
	show.call("obelisk", Vector3(11.0, 0.0, 0.0), 0.6)
	show.call("barque_stand", Vector3(2.0, 0.0, 5.0))
	show.call("well", Vector3(7.0, 0.0, 6.0))
	show.call("altar", Vector3(-3.0, 0.0, 7.0))
	place_boy(Vector3(-0.5, 0.0, 3.0))
	await shoot("a seated king, a standing king, the falcon, the naos, an obelisk", Vector3(-2.0, 5.0, 34.0), Vector3(0.0, 6.0, 0.0), 44.0)
	await shoot("the falcon and the naos", Vector3(3.0, 2.0, 11.0), Vector3(4.0, 2.0, 0.0), 44.0)
	await shoot("the seated king", Vector3(-6.0, 6.0, 22.0), Vector3(-12.0, 7.0, 0.0), 44.0)
	await shoot("the kings from the side", Vector3(-34.0, 5.0, 8.0), Vector3(-8.0, 6.0, 0.0), 40.0)
	for child in holder.get_children():
		child.queue_free()
	show.call("pylon_tower_left", Vector3(-6.0, 0.0, 0.0))
	show.call("pylon_tower", Vector3(6.0, 0.0, 0.0))
	show.call("pylon_gateway", Vector3(0.0, 0.0, 0.0))
	show.call("pylon_tower_ruin", Vector3(46.0, 0.0, 0.0), 0.3)
	show.call("screen_wall", Vector3(-4.0, 0.0, 12.0))
	show.call("cornice", Vector3(2.0, 0.0, 12.0), 2.0)
	show.call("cornice_corner", Vector3(3.0, 0.0, 12.0), 2.0)
	show.call("column_broken", Vector3(8.0, 0.0, 12.0))
	show.call("column_drum", Vector3(11.0, 0.5, 12.0))
	show.call("architrave", Vector3(-9.0, 0.0, 12.0))
	show.call("mosque", Vector3(-30.0, 0.0, 22.0))
	show.call("minaret", Vector3(-20.0, 0.0, 16.0))
	place_boy(Vector3(0.0, 0.0, 16.0))
	await shoot("the pylon's models: two towers and the gateway", Vector3(10.0, 12.0, 80.0), Vector3(0.0, 17.0, 0.0), 44.0)
	await shoot("the gateway and its winged disc", Vector3(0.0, 8.0, 24.0), Vector3(0.0, 15.0, 0.0), 50.0)
	await shoot("the lengths: a beam, a screen wall, cornice, a broken column, a drum", Vector3(1.0, 3.0, 26.0), Vector3(1.0, 2.5, 12.0), 50.0)
	await shoot("the mosque and its minaret", Vector3(0.0, 8.0, 44.0), Vector3(-26.0, 6.0, 20.0), 44.0)
	holder.queue_free()
	await process_frame


func shoot(name: String, from: Vector3, to: Vector3, fov: float, frames := 4) -> void:
	if from != Vector3.INF:
		cam.global_position = from
		cam.look_at(to)
	cam.fov = fov
	# (the sun's shadows reach as far as there is to see)
	sun.directional_shadow_max_distance = clampf(cam.global_position.length() * 1.6, 120.0, 900.0)
	for i in frames:
		cam.make_current()
		await process_frame
	await RenderingServer.frame_post_draw
	print("  VIEW %-52s draw calls %4d  triangles %7d" % [name, Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME), Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME)])
	var image := root.get_texture().get_image()
	image.resize(CELL.x, CELL.y, Image.INTERPOLATE_LANCZOS)
	cells.append(image)
	names.append(name)
	if cells.size() == 4:
		sheet()


func sheet() -> void:
	var whole := Image.create(CELL.x * 2, CELL.y * 2, false, cells[0].get_format())
	for i in cells.size():
		whole.blit_rect(cells[i], Rect2i(Vector2i.ZERO, CELL), Vector2i((i % 2) * CELL.x, (i / 2) * CELL.y))
	whole.save_png(out.path_join("temple_%02d.png" % page))
	print("SHEET %d: %s" % [page, " | ".join(names)])
	page += 1
	cells.clear()
	names.clear()
