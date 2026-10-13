extends SceneTree
## Not part of the game. Pictures of the three temples that stand in the shipped desert (Edfu, Kom Ombo and Abu
## Simbel), of the river they stand by, and of the small thing there is to do at each; and what each picture
## costs to draw.
## godot --path . --resolution 1280x720 --script tools/desert_temples_sheets.gd -- <outdir> [what ...] [q0|q1|q2] [layout=<file>]
##
## `what` is any of (with none, all of them):
##   map        the whole level from straight above, north at the top
##   skyline    from where he starts, looking each way, and towards each temple
##   edfu       the way up to Edfu from 150 m, from 50 m and at the gate; its court, hall and sanctuary
##   kom_ombo   the same for Kom Ombo
##   abu        the same for Abu Simbel: the great hall, the sanctuary, the small temple
##   river      the bank, looking up and down the water
##   puzzles    the keeper and the leaf at Edfu and at Kom Ombo; the slab, the lever, the sun and the store-room at Abu Simbel
##   old        the old places, from where the standard views were taken: what they cost now
## `layout=<file>` opens that level and not the shipped one (for a map of the level as it was).
## Each picture is saved by itself (<what>_<name>.png). Add `--rendering-method gl_compatibility --rendering-driver
## opengl3` before `--script` for the web's renderer. The level it opens is kept in a file of its own
## (`LevelLayout.saved_at`): the one made in the game is left alone.

const KEPT := "user://desert_temples_sheets.json"

var out := ""
var only: Array = []
var scene: Node
var level: Desert
var player: Player
var cam: Camera3D
var prefix := ""
var file := ""


func _initialize() -> void:
	DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_NO_FOCUS, true)
	DisplayServer.window_set_position(Vector2i(-6000, -6000))
	# (a gamepad may be plugged in and in use: it is not listened to here)
	Gamepad.device = 99
	var args := OS.get_cmdline_user_args()
	out = args[0]
	only = args.slice(1)
	for quality in 3:
		if "q%d" % quality in only:
			only.erase("q%d" % quality)
			Sand.quality = quality
	for word: String in only.duplicate():
		if word.begins_with("layout="):
			file = word.trim_prefix("layout=")
			only.erase(word)
	LevelLayout.saved_at = KEPT
	run.call_deferred()


func wanted(what: String) -> bool:
	return only.is_empty() or what in only


func run() -> void:
	for action: StringName in InputMap.get_actions():
		if not String(action).begins_with("ui_"):
			InputMap.action_erase_events(action)
			Input.action_release(action)
	var layout := LevelLayout.built_in()
	if file != "":
		layout = LevelLayout.from_text(FileAccess.get_file_as_string(file))
	layout["weather"] = 0
	await open(layout)
	for what: String in ["map", "skyline", "old", "edfu", "kom_ombo", "abu", "river", "puzzles"]:
		if wanted(what):
			prefix = what
			await call(what)
	if FileAccess.file_exists(KEPT):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(KEPT))
	quit()


# --- The pictures ---

func map() -> void:
	var size := level.terrain.size
	level.heat(0.0)
	cam.projection = Camera3D.PROJECTION_ORTHOGONAL
	cam.size = size + 40.0
	cam.near = 1.0
	cam.far = 2000.0
	cam.look_at_from_position(Vector3(0.0, 700.0, 0.0), Vector3.ZERO, Vector3(0.0, 0.0, -1.0))
	player.global_position = Vector3(0.0, level.height_at(0.0, 0.0) + 0.1, 0.0)
	await snap("%d" % int(size))
	cam.projection = Camera3D.PROJECTION_PERSPECTIVE
	cam.near = 0.05
	cam.far = 3000.0
	await shoot("from the south-west", Vector3(-size * 0.5, 260.0, size * 0.62), Vector3(size * 0.1, 0.0, 0.0), 50.0)
	await shoot("from the south-east", Vector3(size * 0.55, 200.0, size * 0.6), Vector3(size * 0.1, 0.0, 0.0), 50.0)
	level.heat(float(level.layout.get("mirage", 0.5)))


func skyline() -> void:
	var from := start()
	await boy("north, as he starts", from, 180.0)
	for yaw: float in [90.0, 0.0, 270.0]:
		await boy("facing %d" % int(yaw), from, yaw)
	for named: String in ["Edfu", "KomOmbo", "AbuSimbel"]:
		var to := place(named)
		if to != Vector2.INF:
			await boy("towards %s" % named, from, toward(from, to))
			# (and from the top of the first dune that way, a minute's walk on)
			var on := from + (to - from).normalized() * 70.0
			await boy("70 m on towards %s" % named, on, toward(on, to))


## The old places, from where `tools/desert_views.gd` looks at them, wherever they are now.
func old() -> void:
	var moved := start() - Vector2(0.0, 165.0)
	var shift := Vector3(moved.x, 0.0, moved.y)
	for view: Array in [["start", Vector3(0, 1.5, 173), Vector3(0, 4, 100)], ["camp_eye", Vector3(-62, 1.9, 121), Vector3(-62, 2, 100)],
			["colonnade", Vector3(32, 16, 78), Vector3(0, 2, 34)], ["outpost", Vector3(120, 5, 168), Vector3(105, 2, 148)],
			["from_pyramid", Vector3(0, 33, -97), Vector3(0, 0, 60)], ["oasis_eye", Vector3(42, 0.8, 84), Vector3(62, 1.5, 76)],
			["ruined", Vector3(92, 9, -12), Vector3(118, 4, -38)]]:
		player.global_position = (view[2] as Vector3) + shift
		await shoot(view[0], (view[1] as Vector3) + shift, (view[2] as Vector3) + shift, 55.0)
	# (and looking east and south-east over the old level to the temples, from the ground and from the great pyramid)
	await boy("east from the oasis", Vector2(84.0, 78.0) + moved, 90.0)
	await boy("south-east from the outpost", Vector2(105.0, 143.0) + moved, 60.0)
	await shoot("east from the great pyramid", Vector3(0, 33, -97) + shift, Vector3(300, 0, -40) + shift, 60.0)
	await shoot("south-east from the great pyramid", Vector3(0, 33, -97) + shift, Vector3(200, 0, 260) + shift, 60.0)


func edfu() -> void:
	var temple := named("Edfu") as Temple
	if temple == null:
		return
	await approach(temple, Vector3(0.0, 0.0, temple.length * 0.5 + 6.0), Vector3.BACK)
	await inside(temple, "court", marker(temple, &"temple_court", 0) + Vector3(0.0, 0.0, 12.0), Vector3.FORWARD, 9.0, 3.2)
	await inside(temple, "court, looking back at the pylon", marker(temple, &"temple_court", 0) + Vector3(4.0, 0.0, -14.0), Vector3.BACK, 7.0, 3.0)
	var doors := markers(temple, &"temple_doorways")
	await inside(temple, "the great hall", (doors[1] + doors[2]) * 0.5 + Vector3(0.0, 0.0, 4.0), Vector3.FORWARD, 5.0, 2.4)
	await inside(temple, "the second hall", (doors[2] + doors[3]) * 0.5 + Vector3(0.0, 0.0, 3.0), Vector3.FORWARD, 4.0, 2.2)
	await inside(temple, "the sanctuary", marker(temple, &"temple_sanctuary", 0) + Vector3(0.0, 0.0, 0.5), Vector3.FORWARD, 2.6, 2.0)
	await inside(temple, "the walk inside the wall", Vector3(-temple.breadth * 0.5 + 4.6, 0.15, 0.0), Vector3.FORWARD, 6.0, 2.6)
	await inside(temple, "the well behind", marker(temple, &"temple_well", 0) + Vector3(6.0, 0.0, 1.0), Vector3.LEFT, 5.0, 2.4)


func kom_ombo() -> void:
	var temple := named("KomOmbo") as Temple
	if temple == null:
		return
	await approach(temple, Vector3(-3.8, 0.0, temple.length * 0.5 + 6.0), Vector3.BACK)
	await inside(temple, "court", marker(temple, &"temple_court", 0) + Vector3(0.0, 0.0, 6.0), Vector3.FORWARD, 8.0, 3.0)
	var doors := markers(temple, &"temple_doorways")
	await inside(temple, "the hall", (doors[2] + doors[4]) * 0.5 + Vector3(3.8, 0.0, 3.0), Vector3.FORWARD, 5.0, 2.4)
	await inside(temple, "the inner hall", (doors[4] + doors[6]) * 0.5 + Vector3(3.8, 0.0, 2.0), Vector3.FORWARD, 4.0, 2.2)
	await inside(temple, "the sanctuaries", marker(temple, &"temple_sanctuary", 0) + Vector3(3.8, 0.0, 5.0), Vector3.FORWARD, 4.0, 2.6)
	await inside(temple, "the lake and the river", marker(temple, &"temple_lake", 0) + Vector3(-12.0, 0.0, 6.0), Vector3.RIGHT, 6.0, 3.0)
	await inside(temple, "the well", marker(temple, &"temple_well", 0) + Vector3(5.0, 0.0, 6.0), Vector3(-0.6, 0.0, -0.8), 5.0, 2.4)
	var at := temple.global_transform * Vector3(0.0, 0.0, temple.length * 0.5 + 40.0)
	await shoot("from above", at + Vector3(60.0, 70.0, 40.0), temple.global_position, 50.0)


func abu() -> void:
	var temple := named("AbuSimbel") as AbuSimbel
	if temple == null:
		return
	var front := temple.global_transform * Vector3(0.0, 0.0, 24.0)
	# (the river is before it: he comes to it along the bank, from the south)
	var along := temple.global_transform.basis * Vector3.LEFT
	for far: float in [150.0, 50.0]:
		var from := Vector2(front.x, front.z) + Vector2(along.x, along.z) * far + Vector2(4.0, 0.0)
		await boy("from %d m" % int(far), from, toward(from, Vector2(temple.global_position.x, temple.global_position.z)))
	await inside(temple, "at the terrace", Vector3(3.0, 0.0, 30.0), Vector3.FORWARD, 9.0, 3.0, true)
	await inside(temple, "at the door", Vector3(0.6, 1.2, 12.0), Vector3.FORWARD, 6.0, 2.4)
	await inside(temple, "the great hall", marker(temple, &"abu_simbel_hall", 0) + Vector3(0.0, 0.0, 7.0), Vector3.FORWARD, 3.5, 2.2)
	await inside(temple, "the great hall, looking out", marker(temple, &"abu_simbel_hall", 0) + Vector3(0.0, 0.0, -6.0), Vector3.BACK, 3.0, 2.2)
	await inside(temple, "the small temple", Vector3(100.0, 0.0, 34.0), Vector3(0.1, 0.0, -1.0), 9.0, 3.0, true)
	await inside(temple, "the small hall", marker(temple, &"abu_simbel_hall", 1) + Vector3(-0.6, 0.0, 4.5), Vector3(0.24, 0.0, -0.97), 2.5, 2.0)
	await shoot("from the river", temple.global_transform * Vector3(40.0, 14.0, 110.0), temple.global_transform * Vector3(45.0, 12.0, 0.0), 55.0)
	await shoot("from above", temple.global_transform * Vector3(40.0, 150.0, 150.0), temple.global_transform * Vector3(40.0, 0.0, -30.0), 55.0)
	await shoot("its back, from the old level", temple.global_transform * Vector3(-60.0, 6.0, -200.0), temple.global_transform * Vector3(30.0, 18.0, -40.0), 55.0)


func river() -> void:
	var middle := Vector2(214.0, 110.0)
	for water: Dictionary in level.terrain.waters():
		var points: PackedVector2Array = water["points"]
		if points.size() > 2:
			# (a place on its west bank, about half way along)
			var best := points[0]
			for point in points:
				if absf(point.y - 110.0) < absf(best.y - 110.0):
					best = point
			middle = best - Vector2(float(water["half"]) + 12.0, 0.0)
	await boy("up the river, north", middle, 172.0)
	await boy("down the river, south", middle, 8.0)
	await boy("across it", middle + Vector2(6.0, 0.0), 90.0)
	await shoot("the bank from above", Vector3(middle.x - 60.0, 60.0, middle.y + 90.0), Vector3(middle.x + 10.0, 0.0, middle.y - 40.0), 55.0)
	await boy("where it leaves, south", Vector2(middle.x, 262.0), 20.0)
	await boy("where it comes in, north", Vector2(middle.x + 10.0, -262.0), 160.0)
	var temple := named("KomOmbo")
	if temple:
		await boy("Kom Ombo from the bank", Vector2(temple.global_position.x + 58.0, temple.global_position.z + 78.0), 200.0)
	temple = named("Edfu")
	if temple:
		var landing := temple.global_transform * Vector3(0.0, 0.0, 150.0)
		await boy("the way up to Edfu from the water", Vector2(landing.x, landing.z), toward(Vector2(landing.x, landing.z), Vector2(temple.global_position.x, temple.global_position.z)), 7.0, 2.6)


func puzzles() -> void:
	var temple: Node3D = named("Edfu")
	var keeper: Node3D = named("EdfuKeeper")
	if temple and keeper:
		await inside(temple, "Edfu, the keeper", temple.to_local(keeper.global_position) + Vector3(2.6, 0.0, 1.5), Vector3(-0.3, 0.0, -1.0), 2.6, 2.0)
		await inside(temple, "Edfu, the leaf", temple.to_local(named("EdfuLeaf").global_position) + Vector3(3.5, 0.0, 0.5), Vector3.LEFT, 3.0, 2.0)
		(keeper as GateGuardian).on = true
		for i in 60:
			await physics_frame
		await inside(temple, "Edfu, the keeper named", temple.to_local(keeper.global_position) + Vector3(2.6, 0.0, 1.5), Vector3(-0.3, 0.0, -1.0), 2.6, 2.0)
		await inside(temple, "Edfu, the naos", marker(temple, &"temple_sanctuary", 0) + Vector3(-1.0, 0.0, -1.0), Vector3(0.2, 0.0, -1.0), 2.8, 2.0)
	temple = named("KomOmbo")
	keeper = named("KomOmboKeeper")
	if temple and keeper:
		await inside(temple, "Kom Ombo, the keeper", temple.to_local(keeper.global_position) + Vector3(2.2, 0.0, 1.2), Vector3(-0.35, 0.0, -1.0), 2.6, 2.0)
		await inside(temple, "Kom Ombo, the leaf", temple.to_local(named("KomOmboLeaf").global_position) + Vector3(3.0, 0.0, 3.0), Vector3(-0.7, 0.0, -0.7), 3.0, 2.0)
		await shoot("Kom Ombo, the sanctuaries from above", temple.global_transform * Vector3(4.0, 16.0, -8.0), temple.global_transform * Vector3(-3.0, 1.75, -28.0), 55.0)
	temple = named("AbuSimbel")
	var lever := named("AbuLever") as Lever
	if temple and lever:
		await inside(temple, "Abu Simbel, the slab", Vector3(0.0, 1.2, -15.0), Vector3.FORWARD, 3.0, 2.2)
		await inside(temple, "Abu Simbel, the store-room", Vector3(-9.2, 1.2, -8.7), Vector3.LEFT, 2.0, 1.9)
		await inside(temple, "Abu Simbel, the lever", temple.to_local(lever.global_position) + Vector3(3.6, 0.0, 0.2), Vector3.LEFT, 2.4, 1.9)
		await inside(temple, "Abu Simbel, the sanctuary dark", Vector3(-0.8, 1.2, -38.4), Vector3(0.15, 0.0, -1.0), 2.4, 1.9)
		lever.work()
		for i in 300:
			await physics_frame
		print("ABU on=%s after the lever" % (temple as AbuSimbel).on)
		await inside(temple, "Abu Simbel, the slab up", Vector3(-1.2, 1.2, -15.0), Vector3.FORWARD, 3.0, 2.2)
		await inside(temple, "Abu Simbel, the sun on the gods", Vector3(-0.8, 1.2, -38.4), Vector3(0.15, 0.0, -1.0), 2.4, 1.9)
		await inside(temple, "Abu Simbel, the sun down the second hall", Vector3(-0.9, 1.2, -26.0), Vector3.FORWARD, 2.6, 2.0)
		await inside(temple, "Abu Simbel, the store-room that opens", Vector3(6.6, 1.2, -8.45), Vector3.RIGHT, 2.8, 1.9)
		await inside(temple, "Abu Simbel, what is in it", Vector3(15.5, 1.2, -8.7), Vector3.RIGHT, 2.4, 1.9)


# --- Finding things ---

## Where he starts.
func start() -> Vector2:
	for item: Dictionary in level.layout["items"]:
		if item["kind"] == "start":
			return Vector2(item["at"][0], item["at"][1])
	return Vector2.ZERO


## The node of the item with a name.
func named(called: String) -> Node3D:
	for item: Dictionary in level.layout["items"]:
		if item.get("name", "") == called:
			return level.nodes.get(item["id"])
	return null


func place(called: String) -> Vector2:
	var node := named(called)
	return Vector2(node.global_position.x, node.global_position.z) if node else Vector2.INF


## Which way to face (degrees, as `boy` takes it) to look from one place at another.
func toward(from: Vector2, to: Vector2) -> float:
	return rad_to_deg(atan2(to.x - from.x, to.y - from.y))


## The places a temple marks, in its own space.
func markers(temple: Node3D, group: StringName) -> Array[Vector3]:
	var found: Array[Vector3] = []
	for mark in root.get_tree().get_nodes_in_group(group):
		if temple.is_ancestor_of(mark):
			found.append((mark as Node3D).position)
	return found


func marker(temple: Node3D, group: StringName, which: int) -> Vector3:
	var all := markers(temple, group)
	return all[which] if which < all.size() else Vector3.ZERO


## The way up to a temple: from 150 m and 50 m before its gate, and at the gate. `gate` and `out` are in its own space.
func approach(temple: Node3D, gate: Vector3, out_way: Vector3) -> void:
	var way := temple.global_transform.basis * out_way
	var at := temple.global_transform * gate
	for far: float in [150.0, 50.0, 0.0]:
		var from := Vector2(at.x, at.z) + Vector2(way.x, way.z) * far
		await boy("from %d m" % int(far) if far > 0.0 else "at the gate", from, toward(from, Vector2(temple.global_position.x, temple.global_position.z)), 6.0 if far > 0.0 else 9.0, 2.3 if far > 0.0 else 3.0)


## A picture with him standing at a place in a temple's own space, the camera behind him looking the way given.
## (`on_ground`: he is stood on whatever is under him there, and not at the height given.)
func inside(temple: Node3D, name: String, local: Vector3, way_local: Vector3, back: float, up: float, on_ground := false) -> void:
	var at := temple.global_transform * local
	var way := (temple.global_transform.basis * way_local).normalized()
	if on_ground:
		var probe := PhysicsRayQueryParameters3D.create(at + Vector3.UP * 60.0, at + Vector3.DOWN * 10.0, 1)
		var hit := level.get_world_3d().direct_space_state.intersect_ray(probe)
		if not hit.is_empty():
			at.y = (hit["position"] as Vector3).y
	else:
		# (down onto the floor that is under him)
		var probe := PhysicsRayQueryParameters3D.create(at + Vector3.UP * 1.2, at + Vector3.DOWN * 6.0, 1)
		var hit := level.get_world_3d().direct_space_state.intersect_ray(probe)
		if not hit.is_empty():
			at.y = (hit["position"] as Vector3).y
	player.global_position = at + Vector3.UP * 0.05
	player.velocity = Vector3.ZERO
	player.facing_yaw = atan2(way.x, way.z)
	await shoot(name, at - way * back + Vector3.UP * up, at + Vector3.UP * 1.1 + way * 2.0, 55.0, 14)


# --- Making the desert, and taking pictures of it (as `tools/terrain_sheets.gd` does) ---

func open(layout: Dictionary) -> void:
	var kept := FileAccess.open(KEPT, FileAccess.WRITE)
	kept.store_string(LevelLayout.to_text(layout))
	kept.close()
	var began := Time.get_ticks_msec()
	scene = (load("res://desert.tscn") as PackedScene).instantiate()
	root.add_child(scene)
	level = scene.get_node("Level") as Desert
	player = scene.get_node("Player") as Player
	player.set_process_unhandled_input(false)
	(scene.get_node("HUD/TouchControls") as Control).set_process_input(false)
	(scene.get_node("HUD") as CanvasLayer).visible = false
	var own := scene.get_node("Camera") as Camera3D
	own.set_process(false)
	own.set_physics_process(false)
	cam = Camera3D.new()
	cam.far = 3000.0
	scene.add_child(cam)
	cam.make_current()
	print("OPENED in %d ms (the ground in %.0f ms), %d m across" % [Time.get_ticks_msec() - began, level.terrain.made_in, int(level.terrain.size)])
	for i in 20:
		await physics_frame
	for child in level.get_node("Items").get_children():
		if child is Brother or child is Cat:
			child.queue_free()


func stand(at: Vector2, yaw_degrees: float) -> Vector3:
	var where := Vector3(at.x, level.height_at(at.x, at.y) + 0.05, at.y)
	var probe := PhysicsRayQueryParameters3D.create(where + Vector3.UP * 60.0, where + Vector3.DOWN * 5.0, 1)
	var hit := level.get_world_3d().direct_space_state.intersect_ray(probe)
	if not hit.is_empty():
		where.y = (hit["position"] as Vector3).y + 0.05
	player.global_position = where
	player.velocity = Vector3.ZERO
	player.facing_yaw = deg_to_rad(yaw_degrees)
	return where


## A picture from where the game's camera would be: behind him, a little above.
func boy(name: String, at: Vector2, yaw_degrees: float, back := 6.0, up := 2.3) -> void:
	var where := stand(at, yaw_degrees)
	var way := Vector3(sin(deg_to_rad(yaw_degrees)), 0.0, cos(deg_to_rad(yaw_degrees)))
	await shoot(name, where - way * back + Vector3.UP * up, where + Vector3.UP * 1.0 + way * 2.0, 55.0, 14)


func shoot(name: String, from: Vector3, to: Vector3, fov: float, frames := 8) -> void:
	cam.global_position = from
	cam.look_at(to)
	cam.fov = fov
	await snap(name, frames)


func snap(name: String, frames := 8) -> void:
	for i in frames:
		cam.make_current()
		await physics_frame
		await process_frame
	await RenderingServer.frame_post_draw
	var path := out.path_join("%s_%s.png" % [prefix, name.replace(",", "").replace(" ", "_")])
	root.get_texture().get_image().save_png(path)
	print("VIEW %-9s %-38s draw calls %4d  triangles %7d" % [prefix, name,
		Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME),
		Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME)])
