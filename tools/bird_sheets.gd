extends SceneTree
## Not part of the game. Saves pictures of the birds (scripts/birds.gd), and prints what they cost.
## godot --path . --resolution 640x480 --script tools/bird_sheets.gd -- <outdir> [what ...] [kind ...]
## `what` is any of:
##     kinds     each kind standing and flying, from several sides
##     beat      each kind through one beat of its wings, eight pictures in a row
##     acts      each kind doing what it does standing: alert, pecking, preening, on one leg, walking
##     takeoff   each kind going up, and coming down again, a picture every few frames
##     flock     thirty sparrows and twenty doves put up, wheeling and settling on what is there
##     flush     the boy running at a flock of doves
##     water     waders at a pond's edge, geese on it, a kingfisher over it, swallows
##     soar      the soarers against the sky from the boy's eye height, and coming down to him lying there
##     far       each kind near and as it is drawn far off, side by side
##     yard      the birds' station in the test yard, and its pond
##     cost      what a flock costs each frame, settled and in the air
## and `kind` any of the names in `Birds.Kind` (sparrow, heron ...), to do only those. With no `what`: all of them.

const W := 640
const H := 480

var out := ""
var whats: Array = []
var only: Array = []
var stage: Node3D
var cam: Camera3D
var caption: Label
var cells: Array[Image] = []
var boy: Player
var touch: TouchControls


func _initialize() -> void:
	DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_NO_FOCUS, true)
	DisplayServer.window_set_position(Vector2i(-6000, -6000))
	var args := OS.get_cmdline_user_args()
	out = args[0]
	DirAccess.make_dir_recursive_absolute(out)
	for word: String in args.slice(1):
		if Birds.Kind.has(word.to_upper()):
			only.append(Birds.Kind[word.to_upper()])
		else:
			whats.append(word)
	run.call_deferred()


func wants(what: String) -> bool:
	return whats.is_empty() or what in whats


func kinds() -> Array:
	return only if not only.is_empty() else Birds.Kind.values()


func kind_name(kind: int) -> String:
	return String(Birds.Kind.keys()[kind]).to_lower()


## An empty stage: sky, sun, a floor of sand.
func new_stage(floor := true) -> void:
	if stage:
		stage.queue_free()
		await process_frame
	stage = Node3D.new()
	root.add_child(stage)
	var environment := Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = Color(0.62, 0.72, 0.8)
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color(0.66, 0.7, 0.78)
	environment.ambient_light_energy = 0.7
	environment.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	var world := WorldEnvironment.new()
	world.environment = environment
	stage.add_child(world)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-42.0, -35.0, 0.0)
	sun.light_color = Color(1.0, 0.95, 0.86)
	sun.light_energy = 1.25
	sun.shadow_enabled = true
	sun.directional_shadow_max_distance = 60.0
	stage.add_child(sun)
	if floor:
		box(Vector3(0, -1, 0), Vector3(300, 2, 300), Color(0.86, 0.74, 0.52))
	cam = Camera3D.new()
	cam.far = 2000.0
	stage.add_child(cam)
	var layer := CanvasLayer.new()
	stage.add_child(layer)
	caption = Label.new()
	caption.position = Vector2(8, 4)
	caption.add_theme_font_size_override(&"font_size", 20)
	caption.add_theme_color_override(&"font_color", Color.BLACK)
	layer.add_child(caption)


func box(at: Vector3, size: Vector3, colour: Color) -> StaticBody3D:
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
	visual.material_override = Toon.surface(colour)
	body.add_child(visual)
	body.position = at
	stage.add_child(body)
	return body


func prop(what: String, at: Vector3, yaw := 0.0) -> Node3D:
	var made := (load("res://props/%s.tscn" % what) as PackedScene).instantiate() as Node3D
	made.position = at
	made.rotation.y = yaw
	stage.add_child(made)
	return made


func flock(kind: int, count: int, at: Vector3, roam := 30.0, manual := false) -> Birds:
	var made := Birds.new()
	made.kind = kind as Birds.Kind
	made.count = count
	made.roam = roam
	made.manual = manual
	made.position = at
	stage.add_child(made)
	return made


func wait(frames: int) -> void:
	for i in frames:
		await physics_frame
		await process_frame


func look(from: Vector3, at: Vector3, fov := 40.0) -> void:
	cam.global_position = from
	cam.look_at(at)
	cam.fov = fov
	cam.make_current()


## Takes the picture as one cell of the sheet being made.
func shoot(text: String) -> void:
	caption.text = text
	await process_frame
	await RenderingServer.frame_post_draw
	var image := root.get_texture().get_image()
	if image.get_width() != W or image.get_height() != H:
		image.resize(W, H, Image.INTERPOLATE_LANCZOS)
	cells.append(image)


func sheet(name: String, columns: int) -> void:
	if cells.is_empty():
		return
	var rows := ceili(float(cells.size()) / columns)
	var whole := Image.create(W * columns, H * rows, false, cells[0].get_format())
	for i in cells.size():
		whole.blit_rect(cells[i], Rect2i(0, 0, W, H), Vector2i((i % columns) * W, (i / columns) * H))
	if columns > 2:
		whole.resize(whole.get_width() / 2, whole.get_height() / 2, Image.INTERPOLATE_LANCZOS)
	whole.save_png(out.path_join(name + ".png"))
	print("SHEET ", out.path_join(name + ".png"))
	cells.clear()


## How big a kind is, for standing back from it.
func span(kind: int) -> float:
	var k := BirdKinds.of(kind)
	return k["span"] * k["size"]


## Poses the one bird of a flock that does nothing of itself: standing (and doing `act`), or flying.
func pose(birds: Birds, flying: bool, phase := 0.0, glide := false, act := Birds.Act.NONE, act_at := 0.5) -> void:
	var b := birds.birds[0]
	b.hidden = 0.0
	b.size = 1.0
	if flying:
		b.state = Birds.State.FLY
		b.legs = 0.0
		b.fold = 0.0
		b.flap = 0.0 if glide else 1.0
		b.effort = 1.0
		b.beat = phase
		birds._set_blend(1.0)
		birds._beat(b, b.flap, 1.0, 0.0)
		b.flap = 0.0 if glide else 1.0
		birds._beat(b, b.flap, 1.0, 0.0)
		birds._hold(b, birds._k["fly"], 30.0, 1.0)
		b.extra = 0.0
	else:
		b.state = Birds.State.STAND
		b.time = 5.0
		b.act = act
		b.act_length = 1.1
		b.act_time = act_at * b.act_length
		birds._set_blend(0.1)
		for i in 30:
			b.act_time = act_at * b.act_length
			b.act = act
			birds._stand(b, 0.1)


func run() -> void:
	for action: StringName in InputMap.get_actions():
		if not String(action).begins_with("ui_"):
			InputMap.action_erase_events(action)
			Input.action_release(action)
	if wants("kinds"):
		await do_kinds()
	if wants("far"):
		await do_far()
	if wants("beat"):
		await do_beat()
	if wants("acts"):
		await do_acts()
	if wants("takeoff"):
		await do_takeoff()
	if wants("flock"):
		await do_flock()
	if wants("flush"):
		await do_flush()
	if wants("water"):
		await do_water()
	if wants("soar"):
		await do_soar()
	if wants("yard"):
		await do_yard()
	if wants("cost"):
		await do_cost()
	quit()


func do_kinds() -> void:
	for kind: int in kinds():
		await new_stage()
		var birds := flock(kind, 1, Vector3.ZERO, 10.0, true)
		await wait(6)
		var b := birds.birds[0]
		var s := span(kind)
		var k := BirdKinds.of(kind)
		var tall: float = (k["leg"] + k["body"].y + k["neck"]) * k["size"]
		var mid := Vector3(0, tall * 0.55, 0)
		b.at = Vector3.ZERO
		b.yaw = 0.0
		pose(birds, false)
		var back := maxf(tall, s * 0.5) * 3.2
		for view: Array in [["side", Vector3(back, tall * 0.6, 0.0)], ["front quarter", Vector3(back * 0.7, tall * 0.8, back * 0.7)], ["behind", Vector3(-back * 0.6, tall * 0.9, -back * 0.8)], ["above", Vector3(0.01, back, 0.3)]]:
			look(mid + view[1], mid, 35.0)
			await shoot("%s standing: %s" % [kind_name(kind), view[0]])
		b.at = Vector3(0, 3, 0)
		mid = b.at + Vector3(0, k["leg"] * k["size"], 0)
		back = s * 1.7
		pose(birds, true, 0.0, true)
		look(mid + Vector3(back * 0.75, s * 0.2, back * 0.7), mid, 35.0)
		await shoot("%s gliding: front quarter" % kind_name(kind))
		look(mid + Vector3(0.01, back * 1.1, 0.0), mid, 35.0)
		await shoot("%s gliding: from above" % kind_name(kind))
		look(mid + Vector3(0.3, -back * 1.1, 0.01), mid, 35.0)
		await shoot("%s gliding: from below" % kind_name(kind))
		pose(birds, true, PI * 0.5)
		look(mid + Vector3(back * 0.9, s * 0.1, back * 0.3), mid, 35.0)
		await shoot("%s wings up: side" % kind_name(kind))
		sheet("kind_%s" % kind_name(kind), 4)


## Near and far versions side by side, and how many triangles each is.
func do_far() -> void:
	await new_stage()
	for kind: int in kinds():
		var s := span(kind)
		for far: bool in [false, true]:
			var birds := flock(kind, 1, Vector3(0, 0, 0), 10.0, true)
			await wait(4)
			birds.birds[0].at = Vector3(0, 3, 0)
			birds.birds[0].yaw = 0.6
			pose(birds, true, 0.6)
			birds._k = birds._k.duplicate()
			birds._k["far"] = 0.0 if far else 1000.0
			look(Vector3(s * 1.2, 3.0 + s * 0.6, s * 1.4), Vector3(0, 3.05, 0), 35.0)
			await wait(2)
			await shoot("%s %s: %d triangles" % [kind_name(kind), "far" if far else "near", BirdMesh.triangles(BirdMesh.far(kind) if far else BirdMesh.near(kind))])
			birds.queue_free()
			await process_frame
		print("TRIANGLES %-11s near %4d  far %3d" % [kind_name(kind), BirdMesh.triangles(BirdMesh.near(kind)), BirdMesh.triangles(BirdMesh.far(kind))])
	sheet("far", 4)


func do_beat() -> void:
	for kind: int in kinds():
		await new_stage()
		var birds := flock(kind, 1, Vector3.ZERO, 10.0, true)
		await wait(6)
		var s := span(kind)
		birds.birds[0].at = Vector3(0, 3, 0)
		look(Vector3(s * 1.5, 3.0 + s * 0.35, s * 1.3), Vector3(0, 3.0 + s * 0.05, 0), 35.0)
		for i in 8:
			pose(birds, true, TAU * i / 8.0)
			await shoot("%s beat %d/8" % [kind_name(kind), i])
		sheet("beat_%s" % kind_name(kind), 4)


func do_acts() -> void:
	for kind: int in kinds():
		await new_stage()
		var birds := flock(kind, 1, Vector3.ZERO, 10.0, true)
		await wait(6)
		var b := birds.birds[0]
		var k := BirdKinds.of(kind)
		var tall: float = (k["leg"] + k["body"].y + k["neck"]) * k["size"]
		var back := maxf(tall, k["body"].z * k["size"]) * 3.4
		b.at = Vector3.ZERO
		b.yaw = 0.0
		look(Vector3(back, tall * 0.7, back * 0.35), Vector3(0, tall * 0.5, 0), 35.0)
		for act: Array in [["at ease", Birds.Act.NONE, 0.5], ["alert", Birds.Act.ALERT, 0.5], ["pecking", Birds.Act.PECK, 0.5], ["preening", Birds.Act.PREEN, 0.5], ["on one leg", Birds.Act.ONE_LEG, 0.5]]:
			b.pitch = 0.0
			pose(birds, false, 0.0, false, act[1], act[2])
			await shoot("%s %s" % [kind_name(kind), act[0]])
		# (walking: three places in a stride)
		for i in 3:
			pose(birds, false)
			b.state = Birds.State.WALK
			b.from = Vector3.ZERO
			b.goal = Vector3(0, 0, 5)
			b.time = 0.05 + i * 0.07
			b.stride = i * 1.0
			birds._set_blend(0.016)
			for step in 3:
				birds._walk(b, 0.016)
			b.at = Vector3(0, b.at.y, 0)
			await shoot("%s walking %d" % [kind_name(kind), i])
		sheet("acts_%s" % kind_name(kind), 4)


## Going up and coming down, as it does it itself: put up by a shout from one side, and watched until it is down again.
func do_takeoff() -> void:
	for kind: int in kinds():
		var k := BirdKinds.of(kind)
		if k["habit"] == BirdKinds.Habit.SKIMMER:
			continue
		await new_stage()
		var soars: bool = k["habit"] == BirdKinds.Habit.SOARER
		box(Vector3(9, 1.0, -9), Vector3(1.2, 2.0, 1.2), Color(0.7, 0.62, 0.5))
		var birds := flock(kind, 1, Vector3.ZERO, 14.0)
		await wait(12)
		var b := birds.birds[0]
		if soars:
			# (a soarer is only ever down at something dead)
			var dead := Marker3D.new()
			dead.add_to_group(&"carrion")
			stage.add_child(dead)
			birds._dead = Vector3.ZERO
			birds._put_down(b, Vector3(2.5, 0, 0))
		else:
			birds._leave(b)
			birds._put_down(b, Vector3.ZERO)
		b.yaw = 0.0
		b.pause = 100.0
		await wait(20)
		var s := span(kind)
		var back := maxf(s * 2.6, 1.6)
		b.fear = b.at + Vector3(0, 0, -3)
		b.startle = 0.0
		var shots := 0
		var every := 3 if s < 0.8 else 5
		for frame in every * 8:
			if frame % every == 0:
				look(b.at + Vector3(back, s * 0.4 + 0.2, back * 0.25), b.at + Vector3(0, s * 0.25, 0), 35.0)
				await shoot("%s up %d  state %s" % [kind_name(kind), shots, Birds.State.keys()[b.state]])
				shots += 1
			await wait(1)
		# Now keep the last eight pictures before it is standing again.
		var kept: Array[Image] = []
		var tries := 0
		if soars:
			birds._dead = Vector3.ZERO
		while b.state != Birds.State.LAND and tries < 3000:
			tries += 1
			if soars and b.state == Birds.State.FLY and b.then != Birds.Then.LAND and tries > 200:
				birds._enter(b, Birds.State.FLY)
				b.then = Birds.Then.LAND
				b.goal = Vector3(2, 0, 2)
			await wait(1)
		var landing := 0
		while b.state == Birds.State.LAND or (b.state == Birds.State.STAND and b.time < 0.25):
			if landing % 2 == 0 or s >= 0.8:
				look(b.goal + Vector3(back, s * 0.4 + 0.3, back * 0.25), b.goal + Vector3(0, s * 0.3, 0), 35.0)
				caption.text = "%s down %d  state %s" % [kind_name(kind), landing, Birds.State.keys()[b.state]]
				await process_frame
				await RenderingServer.frame_post_draw
				kept.append(root.get_texture().get_image())
				await physics_frame
			else:
				await wait(1)
			landing += 1
			if landing > 200:
				break
		# (eight of them, evenly through it)
		for i in 8:
			if kept.is_empty():
				break
			var image := kept[mini(int(float(i) * kept.size() / 8.0), kept.size() - 1)]
			if image.get_width() != W or image.get_height() != H:
				image.resize(W, H, Image.INTERPOLATE_LANCZOS)
			cells.append(image)
		print("TAKEOFF %-11s landed after %d frames, %d pictures of the landing" % [kind_name(kind), tries, kept.size()])
		sheet("takeoff_%s" % kind_name(kind), 4)


## A pond in a hollow: square frames of ground one inside another, each a little lower, and water over the inner ones.
func basin(into: Node3D) -> Pool:
	var tops: Array[float] = [0.0, -0.1, -0.16, -0.24, -0.34, -0.46, -0.6, -0.75]
	for ring in tops.size():
		var outer := 60.0 if ring == 0 else 9.0 - ring
		var inner := 8.0 - ring
		var colour := Color(0.86, 0.74, 0.52).darkened(0.04 * ring)
		if ring == tops.size() - 1:
			into.add_child(slab(Vector3(0, tops[ring] - 1.0, 0), Vector3(outer * 2.0, 2.0, outer * 2.0), colour))
			break
		var across := (outer + inner) * 0.5
		var deep := outer - inner
		for side: Array in [[Vector3(across, 0, 0), Vector3(deep, 2.0, outer * 2.0)], [Vector3(-across, 0, 0), Vector3(deep, 2.0, outer * 2.0)],
				[Vector3(0, 0, across), Vector3(inner * 2.0, 2.0, deep)], [Vector3(0, 0, -across), Vector3(inner * 2.0, 2.0, deep)]]:
			into.add_child(slab(side[0] + Vector3(0, tops[ring] - 1.0, 0), side[1], colour))
	var pond := Pool.new()
	pond.size = Vector3(16.0, 1.2, 16.0)
	pond.position = Vector3(0, -0.07, 0)
	into.add_child(pond)
	pond.water.sides = false
	return pond


func slab(at: Vector3, size: Vector3, colour: Color) -> StaticBody3D:
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
	visual.material_override = Toon.surface(colour)
	body.add_child(visual)
	body.position = at
	return body


## Something like a camp in ruins: columns, a wall, a palm.
func ruins() -> void:
	prop("column", Vector3(6, 0, -4))
	prop("column_broken", Vector3(9, 0, -1))
	prop("column_stump", Vector3(4, 0, 3))
	prop("wall_ruin", Vector3(-6, 0, -5), 0.4)
	prop("palm_a", Vector3(-8, 0, 4))
	prop("block_stack", Vector3(1, 0, -7))
	prop("crate", Vector3(-3, 0, 5))


func do_flock() -> void:
	for kind: int in [Birds.Kind.SPARROW, Birds.Kind.DOVE]:
		if not kind in kinds():
			continue
		await new_stage()
		ruins()
		var birds := flock(kind, 30 if kind == Birds.Kind.SPARROW else 20, Vector3.ZERO, 26.0)
		await wait(40)
		look(Vector3(3.2, 1.3, 4.2), Vector3(0, 0.15, 0), 40.0)
		await shoot("%s feeding" % kind_name(kind))
		look(Vector3(14, 6, 16), Vector3(1, 3, -1), 45.0)
		await shoot("%s feeding, from the wide view" % kind_name(kind))
		birds.flush(Vector3(0, 0, 6))
		for i in 8:
			await wait(12 if i < 3 else 50)
			# (from near enough to see them, wherever they have got to)
			var middle := Vector3.ZERO
			for b in birds.birds:
				middle += b.at / birds.count
			look(middle + Vector3(7, 1.5, 8) * (0.5 if i < 3 else 1.0), middle, 50.0)
			await shoot("%s %.1f s after going up: %d down" % [kind_name(kind), birds._quiet, birds.settled()])
		await wait(240)
		look(Vector3(14, 6, 16), Vector3(1, 3, -1), 45.0)
		await shoot("%s %.0f s after: %d down" % [kind_name(kind), birds._quiet, birds.settled()])
		look(Vector3(10, 7.0, 0), Vector3(6, 6.5, -4), 30.0)
		await shoot("%s on the column" % kind_name(kind))
		look(Vector3(-3, 3.2, -1), Vector3(-6, 2.6, -5), 40.0)
		await shoot("%s on the wall" % kind_name(kind))
		await wait(1200)
		look(Vector3(14, 6, 16), Vector3(1, 3, -1), 45.0)
		await shoot("%s %.0f s after: %d down" % [kind_name(kind), birds._quiet, birds.settled()])
		look(Vector3(2.6, 1.0, 3.4) + birds._area, birds._area + Vector3(0, 0.15, 0), 40.0)
		await shoot("%s back on the ground" % kind_name(kind))
		sheet("flock_%s" % kind_name(kind), 4)


## A boy to run at them: the real one, moved by hand.
func add_boy(at: Vector3) -> void:
	touch = TouchControls.new()
	touch.visible = false
	stage.add_child(touch)
	touch.set_process_input(false)
	boy = load("res://player.tscn").instantiate()
	boy.position = at
	stage.add_child(boy)
	boy.set_process_unhandled_input(false)
	for child in boy.find_children("*", "Camera3D", true, false):
		(child as Camera3D).current = false


## Pushes his stick so that he goes a way in the world (the inverse of Player._to_world for the camera as it stands). Zero: lets go of it.
func steer(world: Vector3) -> void:
	var view := cam.global_basis
	var right := Vector3(view.x.x, 0, view.x.z).normalized()
	var forward := Vector3(-view.z.x, 0, -view.z.z).normalized()
	touch.move = Vector2(world.dot(right), -world.dot(forward))


func do_flush() -> void:
	await new_stage()
	ruins()
	var birds := flock(Birds.Kind.DOVE, 16, Vector3.ZERO, 26.0)
	add_boy(Vector3(-1, 0.1, 16))
	await wait(60)
	look(Vector3(9, 2.6, 9), Vector3(0, 1.2, 2), 45.0)
	await shoot("doves feeding; the boy a long way off")
	for i in 11:
		for frame in 14:
			steer((birds._area - boy.global_position).normalized())
			await wait(1)
		await shoot("he runs in: %.1f m off, %d down" % [boy.global_position.distance_to(birds._area), birds.settled()])
	steer(Vector3.ZERO)
	sheet("flush_doves", 4)


func do_water() -> void:
	await new_stage(false)
	var pond := basin(stage)
	prop("reeds", Vector3(-8.5, 0, -8.5))
	prop("palm_a", Vector3(-10, 0, -3))
	prop("column_stump", Vector3(9.2, 0, -6))
	var ibis := flock(Birds.Kind.IBIS, 3, Vector3(-6, 0, 2), 22.0)
	var heron := flock(Birds.Kind.HERON, 1, Vector3(4, 0, -7), 22.0)
	var egret := flock(Birds.Kind.EGRET, 3, Vector3(5, 0, 7), 22.0)
	var geese := flock(Birds.Kind.GOOSE, 4, Vector3(0, 0, 0), 22.0)
	var fisher := flock(Birds.Kind.KINGFISHER, 1, Vector3(9, 0, -6), 22.0)
	var swallows := flock(Birds.Kind.SWALLOW, 6, Vector3(0, 0, 0), 22.0)
	await wait(90)
	look(Vector3(13, 5, 15), Vector3(0, 0, 0), 45.0)
	await shoot("the pond")
	for birds: Birds in [ibis, heron, egret, geese]:
		var b := birds.birds[0]
		var s := span(birds.kind)
		look(b.at + Vector3(s * 1.6, s * 0.6 + 0.3, s * 1.6), b.at + Vector3(0, 0.25, 0), 40.0)
		await shoot("%s: %s, %s" % [kind_name(birds.kind), Birds.State.keys()[b.state], "afloat" if b.afloat else "on its feet"])
		await wait(70)
		look(b.at + Vector3(s * 1.6, s * 0.6 + 0.3, s * 1.6), b.at + Vector3(0, 0.25, 0), 40.0)
		await shoot("%s a moment later: act %s" % [kind_name(birds.kind), Birds.Act.keys()[b.act]])
	# The kingfisher: out over the water, hanging there, and in.
	var f := fisher.birds[0]
	look(f.at + Vector3(1.6, 0.5, 1.8), f.at + Vector3(0, 0.1, 0), 40.0)
	await shoot("kingfisher on its perch")
	fisher._hunt(f)
	var seen := {}
	for i in 900:
		await wait(1)
		var state: int = f.state
		if (state == Birds.State.HOVER and f.time > 1.0 or state == Birds.State.STOOP and f.time > 0.2 or state == Birds.State.TAKEOFF and seen.has(Birds.State.STOOP)) and not seen.has(state):
			seen[state] = true
			look(f.at + Vector3(2.4, 0.7, 2.6), f.at + Vector3(0, -0.2, 0), 40.0)
			await shoot("kingfisher: %s" % Birds.State.keys()[state])
		if f.state == Birds.State.STAND and seen.size() >= 2:
			break
	look(Vector3(8, 1.4, 9), Vector3(0, 0.3, 0), 50.0)
	for i in 3:
		await wait(40)
		await shoot("swallows over the water")
	# And the boy walks down to the water.
	add_boy(Vector3(-16, 0.1, 6))
	look(Vector3(13, 5, 15), Vector3(0, 1, 0), 45.0)
	for i in 6:
		for frame in 40:
			steer(Vector3(1, 0, -0.3).normalized() * 0.5)
			await wait(1)
		await shoot("he comes down to the water: ibis %d, egrets %d, geese %d down" % [ibis.settled(), egret.settled(), geese.settled()])
	steer(Vector3.ZERO)
	sheet("water", 4)


func do_soar() -> void:
	await new_stage()
	ruins()
	add_boy(Vector3(0, 0.1, 0))
	var vultures := flock(Birds.Kind.VULTURE, 3, Vector3(0, 0, 0), 30.0)
	var griffons := flock(Birds.Kind.GRIFFON, 3, Vector3(10, 0, -10), 30.0)
	var kites := flock(Birds.Kind.KITE, 3, Vector3(-10, 0, 5), 30.0)
	await wait(60)
	# From his eye height, looking up at each.
	for birds: Birds in [vultures, griffons, kites]:
		var b := birds.birds[0]
		for i in 2:
			await wait(50)
			look(Vector3(0, 1.3, 0), b.at, 30.0 if i == 0 else 8.0)
			await shoot("%s from the ground, %.0f m up%s" % [kind_name(birds.kind), b.at.y, "" if i == 0 else " (through a glass)"])
	look(Vector3(0, 1.3, 0), Vector3(0, 60, -8), 75.0)
	await shoot("all of them, straight up")
	# He goes down, and stays down.
	boy.ragdoll(Vector3(0, 2, 3))
	for i in 12:
		await wait(240)
		look(Vector3(9, 3.0, 11), Vector3(0, 3.0 if i < 8 else 0.8, 0), 60.0)
		var low := 1000.0
		for b in vultures.birds:
			low = minf(low, b.at.y)
		await shoot("%d s after he fell: lowest vulture %.0f m, %d down" % [(i + 1) * 4, low, vultures.settled() + griffons.settled() + kites.settled()])
	look(Vector3(3.5, 1.2, 5.5), Vector3(0, 0.4, 0), 55.0)
	await shoot("round him")
	boy.recover()
	for i in 3:
		await wait(60)
		look(Vector3(9, 3.0, 11), Vector3(0, 2.5, 0), 60.0)
		await shoot("he gets up: %d still down" % (vultures.settled() + griffons.settled() + kites.settled()))
	sheet("soar", 4)


func do_yard() -> void:
	if stage:
		stage.queue_free()
	stage = (load("res://test_yard.tscn") as PackedScene).instantiate()
	root.add_child(stage)
	cam = Camera3D.new()
	cam.far = 3000.0
	stage.add_child(cam)
	var layer := CanvasLayer.new()
	stage.add_child(layer)
	caption = Label.new()
	caption.position = Vector2(8, 4)
	caption.add_theme_font_size_override(&"font_size", 20)
	caption.add_theme_color_override(&"font_color", Color.BLACK)
	layer.add_child(caption)
	await wait(120)
	for view: Array in [["the birds' station", Vector3(-4, 4, 55), Vector3(-12, 1, 46), 50.0], ["the flock on the ground", Vector3(-10, 1.2, 49.5), Vector3(-12, 0.2, 46), 40.0],
			["the posts", Vector3(-9, 2.5, 50), Vector3(-14, 2.2, 44), 40.0], ["the pond", Vector3(40, 4, -3), Vector3(50, 0, -12), 50.0],
			["the pond, from his height", Vector3(42, 1.3, -10), Vector3(50, 0.2, -12), 45.0], ["over the yard", Vector3(0, 1.4, 0), Vector3(10, 60, 10), 70.0]]:
		look(view[1], view[2], view[3])
		await wait(3)
		await shoot(view[0])
	sheet("yard", 3)
	var total := 0.0
	for node: Node in get_nodes_in_group(&"birds"):
		total += (node as Birds).cost
		print("YARD %-11s x%2d  %5.0f us a frame" % [kind_name((node as Birds).kind), (node as Birds).count, (node as Birds).cost])
	print("YARD all the birds: %.0f us a frame" % total)


## What a flock costs: the script's own time, measured by itself, and what it adds to a frame's drawing.
func do_cost() -> void:
	await new_stage()
	ruins()
	look(Vector3(14, 6, 16), Vector3(1, 3, -1), 45.0)
	await wait(30)
	var before_draws := Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)
	var before_tris := Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME)
	for kind: int in kinds():
		var count := 30
		var birds := flock(kind, count, Vector3.ZERO, 26.0)
		await wait(240)
		var down := birds.cost
		var draws := Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME) - before_draws
		var tris := Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME) - before_tris
		birds.flush(Vector3(0, 0, 6))
		var most := 0.0
		var sum := 0.0
		for i in 240:
			await wait(1)
			most = maxf(most, birds.cost)
			sum += birds.cost
		print("COST %-11s x%d  as they were %4.0f us a frame, put up %4.0f (most %4.0f); drawing them: %d draw calls, %d triangles" % [kind_name(kind), count, down, sum / 240.0, most, draws, tris])
		birds.queue_free()
		await wait(4)
