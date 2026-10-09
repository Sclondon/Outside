extends SceneTree
## Not part of the game. A test stage for the guns: draws each from several sides, fires
## each and saves the frames one after another (flash, smoke, case, what the shot does to
## a wall), breaks each open or works its bolt, shoots the targets, and fires a flare in
## a dark room. Nobody holds the guns: a stand-in here keeps one at a fixed place, as
## the Player will (frozen, with no collision), and calls `fire`.
## godot --path . --fixed-fps 60 --resolution 960x960 --script tools/gun_sheets.gd -- <outdir> [banded] [looks fire reload targets flare rounds] [revolver rifle ...]
## Its window is kept off the screen and takes no input.

const CELL := 480
const GUNS: Array[String] = ["revolver", "rifle", "shotgun", "flare_pistol"]

var out := ""
var only: Array = []
var stage: Node3D
var cam: Camera3D
var sun: DirectionalLight3D
var env: Environment
var cells: Array[Image] = []
var made: Array[Node] = []


## Whoever holds the gun: it is kept at `hold`, and aimed along the hold's -Z.
class Holder extends Node3D:
	var gun: Gun
	var hold := Transform3D.IDENTITY

	func take(what: Gun) -> void:
		gun = what
		gun.freeze = true
		gun.collision_layer = 0
		gun.collision_mask = 0

	func _process(_delta: float) -> void:
		if gun:
			gun.global_transform = hold

	func pull() -> bool:
		return gun.fire(self, -hold.basis.z)


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
	env = Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	var world := WorldEnvironment.new()
	world.environment = env
	stage.add_child(world)
	sun = DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-46.0, 150.0, 0.0)
	sun.light_color = Color(1.0, 0.95, 0.86)
	sun.shadow_enabled = true
	sun.directional_shadow_max_distance = 40.0
	stage.add_child(sun)
	daylight(true)
	cam = Camera3D.new()
	stage.add_child(cam)
	cam.make_current()
	run.call_deferred()


func daylight(on: bool) -> void:
	sun.visible = on
	sun.light_energy = 1.25
	env.background_color = Color(0.56, 0.7, 0.86) if on else Color(0.004, 0.004, 0.006)
	env.ambient_light_color = Color(0.7, 0.74, 0.8) if on else Color(0.3, 0.34, 0.5)
	env.ambient_light_energy = 0.7 if on else 0.05


func wants(name: String) -> bool:
	var kinds := only.filter(func(word: String) -> bool: return word not in GUNS)
	return kinds.is_empty() or name in kinds


func guns() -> Array:
	var named := only.filter(func(word: String) -> bool: return word in GUNS)
	return GUNS if named.is_empty() else named


func run() -> void:
	if wants("looks"):
		for name: String in guns():
			await looks(name)
		await things()
	if wants("fire"):
		for name: String in guns():
			await fire(name)
	if wants("reload"):
		for name: String in guns():
			await reload(name)
	if wants("rounds"):
		await rounds()
	if wants("targets"):
		await targets()
	if wants("flare"):
		await flare()
	quit()


# --- the sheets ---

## Each gun alone, from four sides.
func looks(name: String) -> void:
	box(Vector3(0, -0.5, 0), Vector3(40, 1, 40), Color(0.74, 0.66, 0.53))
	var gun := spawn("res://guns/%s.tscn" % name, Vector3(0, 1.0, 0)) as Gun
	gun.freeze = true
	gun.show_rounds = false
	var bounds := bounds_of(gun)
	var middle := bounds.get_center()
	var reach := bounds.size.length() * 0.5 / tan(deg_to_rad(15.0)) * 1.08
	# From his right, from in front and to the right, from behind and to the left, and from above.
	for view: Vector3 in [Vector3(1, 0.12, 0), Vector3(0.7, 0.35, -0.75), Vector3(-0.8, 0.3, 0.6), Vector3(0.25, 1.0, 0.1)]:
		cam.fov = 30.0
		cam.global_position = middle + view.normalized() * reach
		cam.look_at(middle, Vector3.UP if view.y < 0.9 else Vector3.FORWARD)
		await frames(3)
		await snap()
	sheet("looks_" + name, 2)
	await clear()


## The other things, from two sides each.
func things() -> void:
	box(Vector3(0, -0.5, 0), Vector3(40, 1, 40), Color(0.74, 0.66, 0.53))
	for name: String in ["ammo_box", "target_board", "target_gong", "bottle", "tin_can", "target_pot"]:
		var thing := spawn("res://guns/%s.tscn" % name, Vector3(0, 0.0, 0))
		if thing is RigidBody3D:
			(thing as RigidBody3D).freeze = true
			thing.position.y = 0.2
		var bounds := bounds_of(thing)
		var middle := bounds.get_center()
		var reach := bounds.size.length() * 0.5 / tan(deg_to_rad(15.0)) * 1.1
		for yaw: float in [0.6, PI + 0.9]:
			cam.fov = 30.0
			cam.global_position = middle + Vector3(sin(yaw) * cos(0.3), sin(0.3), cos(yaw) * cos(0.3)) * reach
			cam.look_at(middle)
			await frames(3)
			await snap()
		made.erase(thing)
		thing.free()
	sheet("looks_things", 4)
	await clear()


## A range: the gun fires along +X at a stone wall four metres off.
func range_stage(name: String, far := 4.0) -> Holder:
	box(Vector3(0, -0.5, 0), Vector3(40, 1, 40), Color(0.74, 0.66, 0.53))
	box(Vector3(far + 0.5, 1.5, 0), Vector3(1, 3, 8), Color(0.69, 0.61, 0.49))
	var holder := Holder.new()
	stage.add_child(holder)
	made.append(holder)
	holder.hold = Transform3D(Basis(Vector3.UP, -PI * 0.5), Vector3(0, 1.2, 0))
	var gun := spawn("res://guns/%s.tscn" % name, Vector3(0, 1.2, 0)) as Gun
	holder.take(gun)
	return holder


## A shot, frame by frame: the frame before it, the six after, then every fourth.
func fire(name: String) -> void:
	var holder := await range_stage(name)
	holder.gun.show_rounds = false
	var muzzle := Vector3(-(holder.gun.get_node(^"Muzzle") as Node3D).position.z, 1.2, 0.0)
	# Near: the gun and what comes out of it.
	cam.fov = 34.0
	cam.global_position = Vector3(muzzle.x + 0.2, 1.4, 1.7)
	cam.look_at(Vector3(muzzle.x + 0.2, 1.2, 0))
	await frames(4)
	await snap()
	holder.pull()
	for i in 6:
		await frames(1)
		await snap()
	for i in 9:
		await frames(5)
		await snap()
	sheet("fire_%s" % name, 4)
	# Far: the whole of it, and the wall.
	await frames(90)
	cam.fov = 40.0
	cam.global_position = Vector3(1.6, 1.8, 5.2)
	cam.look_at(Vector3(2.0, 1.1, 0))
	await frames(2)
	await snap()
	holder.pull()
	for i in 4:
		await frames(1)
		await snap()
	for i in 3:
		await frames(6)
		await snap()
	# And the wall, close.
	cam.fov = 30.0
	cam.global_position = Vector3(2.4, 1.3, 1.4)
	cam.look_at(Vector3(4.0, 1.2, 0))
	await frames(2)
	await snap()
	if not holder.gun.can_fire():
		await frames(int(holder.gun.cycle_time * 60.0) + 2)
	holder.pull()
	for i in 3:
		await frames(1 if i < 2 else 6)
		await snap()
	sheet("fire_%s_far" % name, 4)
	await clear()


## Loading it: eight frames through `reload()`.
func reload(name: String) -> void:
	var holder := await range_stage(name)
	holder.gun.show_rounds = false
	var bounds := bounds_of(holder.gun)
	cam.fov = 30.0
	cam.global_position = bounds.get_center() + Vector3(-0.15, 0.25, 1.0).normalized() * bounds.size.length() * 2.1
	cam.look_at(bounds.get_center())
	# (empty it first, without the show)
	holder.gun.rounds = 0
	holder.gun._spent = holder.gun.capacity
	await frames(3)
	await snap()
	holder.gun.reload()
	var wait := int(holder.gun.reload_time * 60.0 / 7.0)
	for i in 7:
		await frames(wait)
		await snap()
	sheet("reload_%s" % name, 4)
	if name == "rifle":
		# The bolt worked after a shot, every sixth frame.
		holder.gun.rounds = 5
		await frames(30)
		await snap()
		holder.pull()
		for i in 11:
			await frames(6)
			await snap()
		sheet("cycle_rifle", 4)
	await clear()


## What is left in it, shown over it.
func rounds() -> void:
	var holder := await range_stage("revolver")
	cam.fov = 30.0
	cam.global_position = Vector3(0.1, 1.5, 1.6)
	cam.look_at(Vector3(0.1, 1.35, 0))
	for i in 4:
		holder.pull()
		await frames(28)
		await snap()
	sheet("rounds", 4)
	await clear()


## The targets: a board knocked down and getting up, a gong swinging, a pot and a bottle smashed.
func targets() -> void:
	var holder := await range_stage("rifle", 9.0)
	holder.gun.show_rounds = false
	holder.gun.spread = 0.0
	# Each stands on the line of fire in turn, three and a half metres off, facing the gun.
	for name: String in ["target_board", "target_gong", "target_pot", "target_jackal", "bottle", "tin_can"]:
		var loose := name not in ["target_board", "target_gong"]
		if loose:
			box(Vector3(3.5, 0.5, 0), Vector3(0.5, 1.0, 0.5), Color(0.52, 0.39, 0.25))
		var target := spawn("res://guns/%s.tscn" % name, Vector3(3.5, 1.2 if loose else 0.0, 0))
		target.rotation.y = -PI * 0.5
		var aim_at: Vector3 = Vector3(3.5, 1.2, 0)
		if target.has_node(^"Hinge/Middle"):
			aim_at = target.get_node(^"Hinge/Middle").global_position
		await frames(20)
		holder.hold = Transform3D(Basis(Vector3.UP, -PI * 0.5), Vector3(0, aim_at.y - 0.047, 0))
		cam.fov = 30.0
		cam.global_position = Vector3(2.2, 1.5, 3.6)
		cam.look_at(Vector3(3.5, 1.0, 0))
		await frames(3)
		await snap()
		holder.gun.rounds = 5
		holder.pull()
		for wait: int in ([2, 4, 6, 10, 20, 150, 40] if name == "target_board" else [2, 4, 6, 10, 20, 30, 40]):
			await frames(wait)
			await snap()
		sheet("target_" + name.trim_prefix("target_"), 4)
		# (the stand goes too)
		if loose:
			made.pop_at(made.size() - 2).free()
		made.erase(target)
		if is_instance_valid(target):
			target.free()
		await frames(2)
	# The shotgun at a row of pots: the spread of it.
	await clear()
	holder = await range_stage("shotgun", 9.0)
	holder.gun.show_rounds = false
	box(Vector3(4.0, 0.5, 0), Vector3(0.5, 1.0, 2.4), Color(0.52, 0.39, 0.25))
	for i in 5:
		spawn("res://guns/%s.tscn" % ["target_pot", "bottle", "target_jar", "tin_can", "target_pot"][i], Vector3(4.0, 1.25, -0.8 + i * 0.4))
	cam.fov = 34.0
	cam.global_position = Vector3(1.6, 1.9, 3.4)
	cam.look_at(Vector3(3.6, 1.1, 0))
	await frames(30)
	await snap()
	holder.pull()
	for wait: int in [1, 1, 2, 4, 8, 16, 30]:
		await frames(wait)
		await snap()
	sheet("target_row", 4)
	await clear()


## A flare in a dark room: before, as it goes, and as it lies burning.
func flare() -> void:
	daylight(false)
	# A chamber twelve metres by eight, four high, with things standing in it.
	box(Vector3(0, -0.5, 0), Vector3(14, 1, 10), Color(0.69, 0.61, 0.49))
	box(Vector3(0, 4.5, 0), Vector3(14, 1, 10), Color(0.57, 0.49, 0.39))
	for side: float in [-1.0, 1.0]:
		box(Vector3(side * 6.5, 2, 0), Vector3(1, 4, 10), Color(0.69, 0.61, 0.49))
		box(Vector3(0, 2, side * 4.5), Vector3(14, 4, 1), Color(0.69, 0.61, 0.49))
	for at: Vector3 in [Vector3(2.5, 0, -2.0), Vector3(-1.5, 0, -2.6), Vector3(3.6, 0, 1.6)]:
		var column := spawn("res://props/column_stump.tscn", at)
		column.scale = Vector3.ONE * 0.8
	spawn("res://props/sarcophagus.tscn", Vector3(0.6, 0, -1.2))
	spawn("res://props/pot_large.tscn", Vector3(4.6, 0, -2.8))
	spawn("res://props/statue_anubis.tscn", Vector3(4.2, 0, -0.4)).scale = Vector3.ONE * 0.5
	var holder := Holder.new()
	stage.add_child(holder)
	made.append(holder)
	# (aimed a little up, as one is)
	holder.hold = Transform3D(Basis(Vector3.UP, -PI * 0.5) * Basis(Vector3.RIGHT, 0.14), Vector3(-5.0, 1.2, 1.0))
	var gun := spawn("res://guns/flare_pistol.tscn", Vector3(-5.0, 1.2, 1.0)) as Gun
	gun.show_rounds = false
	holder.take(gun)
	cam.fov = 60.0
	cam.global_position = Vector3(-5.6, 2.4, 3.6)
	cam.look_at(Vector3(0.5, 0.8, -0.6))
	await frames(5)
	await snap()
	holder.pull()
	for wait: int in [1, 2, 5, 10, 14, 20, 40, 120, 240, 150, 40]:
		await frames(wait)
		await snap()
	sheet("flare", 4)
	daylight(true)
	await clear()


# --- the stage ---

func spawn(path: String, at: Vector3) -> Node3D:
	var thing: Node3D = load(path).instantiate()
	thing.position = at
	stage.add_child(thing)
	made.append(thing)
	return thing


func box(at: Vector3, size: Vector3, color: Color) -> void:
	var body := StaticBody3D.new()
	var shape := BoxShape3D.new()
	shape.size = size
	var collider := CollisionShape3D.new()
	collider.shape = shape
	body.add_child(collider)
	var mesh := BoxMesh.new()
	mesh.size = size
	var visual := MeshInstance3D.new()
	visual.mesh = mesh
	visual.material_override = Toon.surface(color)
	body.add_child(visual)
	body.position = at
	stage.add_child(body)
	made.append(body)


## Takes everything off the stage, and the marks and smoke with it.
func clear() -> void:
	for thing in made:
		if is_instance_valid(thing):
			thing.queue_free()
	made.clear()
	for fx in get_nodes_in_group(&"gun_fx") + get_nodes_in_group(&"flares"):
		fx.queue_free()
	for loose in stage.get_children():
		if loose is RigidBody3D:
			loose.queue_free()
	await frames(2)


func frames(count: int) -> void:
	for i in count:
		await physics_frame
		await process_frame


func snap() -> void:
	await RenderingServer.frame_post_draw
	var image := root.get_texture().get_image()
	var side: int = mini(image.get_width(), image.get_height())
	image = image.get_region(Rect2i((image.get_width() - side) / 2, (image.get_height() - side) / 2, side, side))
	image.resize(CELL, CELL, Image.INTERPOLATE_LANCZOS)
	cells.append(image)


func sheet(name: String, columns := 4) -> void:
	var rows := ceili(cells.size() / float(columns))
	var page := Image.create(CELL * columns, CELL * rows, false, cells[0].get_format())
	for i in cells.size():
		page.blit_rect(cells[i], Rect2i(0, 0, CELL, CELL), Vector2i((i % columns) * CELL, (i / columns) * CELL))
	page.save_png(out.path_join(name + ".png"))
	cells.clear()
	print("SHEET ", name)


func bounds_of(thing: Node3D) -> AABB:
	var bounds := AABB()
	var first := true
	for part: MeshInstance3D in thing.find_children("*", "MeshInstance3D", true, false):
		var area := part.global_transform * part.get_aabb()
		bounds = area if first else bounds.merge(area)
		first = false
	return bounds
