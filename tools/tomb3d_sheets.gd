extends SceneTree
## Not part of the game. Draws tombs that are walked through (`TombLayout3D`), to be looked at.
## godot --path . --fixed-fps 60 --resolution 1280x720 --script tools/tomb3d_sheets.gd -- <folder> [seed:difficulty ...] [b<seed>:<difficulty> ...] [daily] [bdaily] [custom] [grid] [kinds] [cost] [rooms=0]
## (`b12:1` is the tomb that branches from that number, and `bdaily` the day's: `TombBranching`.)
##
## For each tomb named (by default 1:0 2:1 3:2):
##   <name>_plan.png      its floor plan as a map: every room on its square, the ways between them, what is in
##                        each, and the line he is expected to walk
##   <name>_over.png      the whole of it as built, seen from overhead with the roofs off, lit evenly
##   <name>_rooms<n>.png  each room as he sees it through the camera that follows him: just inside its way in,
##                        and at its bay looking on, six to a sheet (and each by itself, <name>_room<nn>_...png)
## `custom` is a tomb made by hand with every lock in it; `grid` one whose rooms were given cells, with a side
## chamber and a way that closes a loop (which no generator makes yet).
## `kinds` goes through tombs until it has seen every kind of way, switch and barrier, and saves a sheet of each
## as he comes to it (kinds_ways.png, kinds_switches.png, kinds_other.png): a doorway, stairs, a crawl (from
## outside it and from inside), water, the pit and its ring, a ladder shaft, a rope shaft, the sand; a seal stone,
## a plate and its block, a plate for a block from the room before, the two plates, an offering table, a
## brazier in a dark room with the torch in his hand, the falcon; a loft from below and from on it, a crypt, a
## corner, and a mummy behind each thing that holds one.
## `cost` draws nothing: for each tomb named it prints how many draws a frame takes and how many lights are lit,
## from just inside each room, seen from the side and walked through.
## Its window is kept off the screen and takes no input.

const CELL := Vector2i(640, 360)
const Shapes := preload("res://tools/tomb_shapes.gd")

var out := ""
var tombs: Array = []
var with_rooms := true
var with_kinds := false
var with_cost := false


class Map extends Control:
	var layout: TombLayout3D

	func _draw() -> void:
		var plan := layout.plan
		var font := ThemeDB.fallback_font
		draw_rect(Rect2(Vector2.ZERO, size), Color(0.93, 0.9, 0.82))
		var box := Rect2()
		var first := true
		for area in layout.areas:
			var rect := Rect2(area.x0, area.z0, area.x1 - area.x0, area.z1 - area.z0)
			box = rect if first else box.merge(rect)
			first = false
		var per := minf((size.x - 60.0) / box.size.x, (size.y - 130.0) / box.size.y)
		var origin := Vector2(30.0, 50.0) + (Vector2(size.x - 60.0, size.y - 130.0) - box.size * per) * 0.5
		var to_map := func(at: Vector3) -> Vector2: return origin + (Vector2(at.x, at.z) - box.position) * per
		draw_string(font, Vector2(16, 24), "Tomb seed %d, %s, walked through: plan %s, stone %s.  %d rooms, %.0f m of floor to walk, %.0f m deep, %d pieces of stone." % [
				plan.seed_value, TombGenerator.DIFFICULTY_NAMES[plan.difficulty], plan.fingerprint(), layout.fingerprint(), plan.rooms.size(), layout.length, layout.depth, layout.boxes.size()],
				HORIZONTAL_ALIGNMENT_LEFT, -1, 15, Color.BLACK)
		# The air, darker the deeper its floor.
		for area in layout.areas:
			var a: Vector2 = to_map.call(Vector3(area.x0, 0.0, area.z0))
			var b: Vector2 = to_map.call(Vector3(area.x1, 0.0, area.z1))
			var shade := clampf(1.0 + area.floor / maxf(layout.depth + 6.0, 1.0) * 0.55, 0.3, 1.0)
			var colour := Color(0.99, 0.97, 0.9) * shade
			if plan.rooms[area.room].dark:
				colour = Color(0.62, 0.6, 0.66) * shade
			if area.sky:
				colour = Color(0.78, 0.84, 0.95)
			if area.deadly:
				colour = Color(0.2, 0.1, 0.1)
			colour.a = 1.0
			draw_rect(Rect2(a, b - a), colour)
			if area.gate:
				draw_rect(Rect2(a, b - a), Color(0.45, 0.38, 0.28, 0.7))
		for box3: Array in layout.boxes:
			if box3[2] == "loft":
				var at: Vector3 = box3[0]
				var extent: Vector3 = box3[1]
				var a: Vector2 = to_map.call(at - extent * 0.5)
				var b: Vector2 = to_map.call(at + extent * 0.5)
				draw_rect(Rect2(a, b - a), Color(0.45, 0.38, 0.28, 0.45))
		# His line.
		for line in layout.walk_lines:
			draw_line(to_map.call(layout.walk_points[line.x]), to_map.call(layout.walk_points[line.y]), Color(0.1, 0.3, 0.8, 0.6), 1.5)
		for point in layout.walk_points:
			draw_circle(to_map.call(point), 2.0, Color(0.1, 0.3, 0.8, 0.8))
		for part in layout.parts:
			var at: Vector2 = to_map.call(part["at"])
			match part["kind"]:
				"door":
					var extent: Vector3 = part["size"]
					var a: Vector2 = to_map.call((part["at"] as Vector3) - extent * 0.5)
					var b: Vector2 = to_map.call((part["at"] as Vector3) + extent * 0.5)
					draw_rect(Rect2(a, b - a), Color(0.75, 0.1, 0.1))
				"item":
					_mark(at, ["T", "H", "J"][int(part["what"])], Color(0.1, 0.45, 0.1))
				"block":
					_mark(at, "B", Color(0.45, 0.3, 0.1))
				"plate":
					_mark(at, "p", Color(0.75, 0.1, 0.1))
				"lever":
					_mark(at, "S", Color(0.75, 0.1, 0.1))
				"offering":
					_mark(at, "o", Color(0.75, 0.1, 0.1))
				"brazier":
					_mark(at, "F", Color(0.75, 0.1, 0.1))
				"treasure":
					_mark(at, "*", Color(0.7, 0.55, 0.0))
				"mummy":
					_mark(at, "M%d" % int(part["what"]), Color(0.4, 0.0, 0.4))
				"ladder":
					_mark(at, "L", Color(0.45, 0.3, 0.1))
				"rope":
					_mark(at, "R", Color(0.45, 0.3, 0.1))
				"ring":
					draw_arc(at, 5.0, 0.0, TAU, 12, Color.BLACK, 1.5)
				"sand":
					draw_circle(at, TombLayout.SAND_PILE * per, Color(0.85, 0.7, 0.4, 0.35))
				"pool":
					var extent: Vector3 = part["size"]
					var a: Vector2 = to_map.call((part["at"] as Vector3) - extent * 0.5)
					var b: Vector2 = to_map.call((part["at"] as Vector3) + extent * 0.5)
					draw_rect(Rect2(a, b - a), Color(0.2, 0.45, 0.7, 0.7))
				"torch":
					draw_circle(at, 2.5, Color(1.0, 0.55, 0.1))
				"pillar":
					draw_rect(Rect2(at - Vector2.ONE * 0.3 * per, Vector2.ONE * 0.6 * per), Color(0.45, 0.38, 0.28))
		for room in plan.rooms:
			var info := layout.rooms[room.id]
			if info.is_empty():
				continue
			var at: Vector2 = to_map.call(info["west"])
			var cell := layout.cells[room.id]
			var name := "%d %s" % [room.id, TombPlan.ROLE_NAMES[room.role]]
			if not TombLayout3D.is_side(room):
				name += " (%d,%d) level %d" % [cell.x, cell.z, cell.y]
			draw_string(font, at + Vector2(4.0, -5.0 if TombLayout3D.is_side(room) else 12.0), name, HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color(0.3, 0.2, 0.5) if TombLayout3D.is_side(room) else Color(0.1, 0.1, 0.1))
		for link in plan.links:
			var door := layout.door_at[link.id]
			if door == Vector3.INF:
				continue
			for id in link.switches:
				draw_dashed_line(to_map.call(layout.switch_at[id]), to_map.call(door), Color(0.75, 0.1, 0.1, 0.8), 1.5, 6.0)
		var y := size.y - 64.0
		draw_string(font, Vector2(16, y), "T torch  H hook  J jar  B block  p plate  S seal stone  o offering table  F brazier  * the falcon  M mummy (kind)  L ladder  R rope  ring: the hook's   red: a door (or the sand) and what opens it   blue: the line he walks   brown: a doorway, a crawl, a loft   darker: deeper",
				HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color(0.2, 0.2, 0.2))
		y += 16.0
		var line := "The way through (%d steps): " % plan.solution.size()
		for step: Array in plan.solution:
			var word := TombSolver.words(plan, step) + ";  "
			if font.get_string_size(line + word, HORIZONTAL_ALIGNMENT_LEFT, -1, 11).x > size.x - 32.0:
				draw_string(font, Vector2(16, y), line, HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color.BLACK)
				y += 14.0
				line = "    "
			line += word
		draw_string(font, Vector2(16, y), line, HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color.BLACK)

	func _mark(at: Vector2, letter: String, colour: Color) -> void:
		draw_circle(at, 8.0, Color(1, 1, 1, 0.85))
		draw_string(ThemeDB.fallback_font, at + Vector2(-5 if letter.length() == 1 else -8, 5), letter, HORIZONTAL_ALIGNMENT_LEFT, -1, 13, colour)


func _initialize() -> void:
	DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_NO_FOCUS, true)
	DisplayServer.window_set_position(Vector2i(-6000, -6000))
	var args := OS.get_cmdline_user_args()
	out = args[0] if not args.is_empty() else "."
	for arg: String in args.slice(1):
		if arg == "bdaily":
			tombs.append({"mode": "daily", "shape": "branching"})
		elif arg.begins_with("b") and arg.substr(1, 1).is_valid_int():
			var said := arg.substr(1).split(":")
			tombs.append({"mode": "random", "seed": int(said[0]), "difficulty": int(said[1]) if said.size() > 1 else 1, "shape": "branching"})
		elif arg == "daily":
			tombs.append({"mode": "daily"})
		elif arg == "custom":
			tombs.append({"mode": "custom", "spec": Shapes.every_lock()})
		elif arg == "grid":
			tombs.append({"mode": "plan", "plan": Shapes.branching()})
		elif arg == "kinds":
			with_kinds = true
		elif arg == "cost":
			with_cost = true
		elif arg.begins_with("rooms="):
			with_rooms = arg != "rooms=0"
		else:
			var parts := arg.split(":")
			tombs.append({"mode": "random", "seed": int(parts[0]), "difficulty": int(parts[1]) if parts.size() > 1 else 1})
	if tombs.is_empty() and not with_kinds:
		tombs = [{"mode": "random", "seed": 1, "difficulty": 0}, {"mode": "random", "seed": 2, "difficulty": 1}, {"mode": "random", "seed": 3, "difficulty": 2}]
	DirAccess.make_dir_recursive_absolute(out)
	run.call_deferred()


var level: TombLevel
var player: Player
var camera: FollowCamera
var hud: CanvasLayer
var scene: Node
var touch: TouchControls
var kinds: Array[Image] = []
var kind_names: Array = []


func run() -> void:
	TombLevel.bare = true
	if with_cost:
		await _count_cost()
		quit()
		return
	for chosen: Dictionary in tombs:
		await _draw_tomb(chosen)
	if with_kinds:
		await _draw_kinds()
	quit()


func _open(chosen: Dictionary, seen := "3d") -> void:
	var asked := chosen.duplicate()
	asked["view"] = seen
	TombLevel.play = asked
	scene = load("res://tomb.tscn").instantiate()
	root.add_child(scene)
	await _frames(8)
	level = scene.get_node("Level")
	player = scene.get_node("Player")
	camera = scene.get_node("Camera")
	hud = scene.get_node("HUD")
	hud.visible = false
	player.sleep_after = 0.0
	touch = scene.get_node("HUD/TouchControls")
	touch.set_process_input(false)
	player.set_process_unhandled_input(false)


func _close() -> void:
	scene.queue_free()
	await _frames(4)


func _draw_tomb(chosen: Dictionary) -> void:
	await _open(chosen)
	var layout := level.layout as TombLayout3D
	var name := _name_of(chosen)
	print("%s: %s" % [name, level.plan.describe().replace("\n", " | ")])
	if not layout.wrong.is_empty():
		print("  CELLS REFUSED: ", layout.wrong)

	# --- The plan
	var layer := CanvasLayer.new()
	root.add_child(layer)
	var map := Map.new()
	map.layout = layout
	map.size = Vector2(root.size)
	layer.add_child(map)
	await _frames(3)
	_save(await _shot(), name + "_plan")
	layer.queue_free()

	# --- The whole of it from overhead, the roofs off, lit evenly
	level.set_physics_process(false)
	for node in level.built.room_nodes:
		node.visible = true
		var roof := node.get_node_or_null(^"Stone_rock") as Node3D
		if roof:
			roof.visible = false
	var flood := DirectionalLight3D.new()
	flood.rotation_degrees = Vector3(-62.0, 28.0, 0.0)
	flood.light_energy = 1.2
	root.add_child(flood)
	var eye := Camera3D.new()
	eye.projection = Camera3D.PROJECTION_ORTHOGONAL
	root.add_child(eye)
	var box := Rect2()
	var first := true
	for area in layout.areas:
		var rect := Rect2(area.x0, area.z0, area.x1 - area.x0, area.z1 - area.z0)
		box = rect if first else box.merge(rect)
		first = false
	box = box.grow(2.0)
	var aspect := float(root.size.x) / float(root.size.y)
	eye.size = maxf(box.size.y, box.size.x / aspect)
	eye.far = 200.0
	eye.position = Vector3(box.get_center().x, 60.0, box.get_center().y)
	eye.rotation_degrees = Vector3(-90.0, 0.0, 0.0)
	# (everything over head height is cut away, a level at a time, by where the eye's near side is)
	eye.current = true
	await _frames(6)
	_save(await _shot(), name + "_over")
	flood.queue_free()
	eye.queue_free()
	for node in level.built.room_nodes:
		var roof := node.get_node_or_null(^"Stone_rock") as Node3D
		if roof:
			roof.visible = true
	camera.current = true
	level.set_physics_process(true)

	# --- Each room as he sees it
	if with_rooms:
		var cells: Array[Image] = []
		var number := 0
		for room in level.plan.rooms:
			var info := layout.rooms[room.id]
			if info.is_empty():
				continue
			var along := Vector3(TombLayout3D.TURNS[int(info["turn"])])
			for spot: Array in [[info["west"], along], [info["east"], along]]:
				var image := await _look(spot[0], spot[1])
				_save(image, "%s_room%02d_%s" % [name, number, TombPlan.ROLE_NAMES[room.role]])
				cells.append(_small(image))
				number += 1
		_sheets(cells, name + "_rooms")
	await _close()


# A picture through his camera, of him standing at `spot` having come `along`.
func _look(spot: Vector3, along: Vector3, settle := 50, tilt := 0.32) -> Image:
	player.global_position = spot + Vector3.UP * 0.05
	player.velocity = Vector3.ZERO
	player.facing_yaw = atan2(along.x, along.z)
	player.set_spawn(player.global_position)
	player.respawn()
	player.facing_yaw = atan2(along.x, along.z)
	camera.look_along(along)
	camera._pitch = tilt
	camera.snap()
	await _frames(settle)
	return await _shot()


func _small(image: Image) -> Image:
	var copy := image.duplicate() as Image
	copy.resize(CELL.x, CELL.y, Image.INTERPOLATE_LANCZOS)
	copy.convert(Image.FORMAT_RGB8)
	return copy


func _sheets(cells: Array[Image], name: String, labels: Array = []) -> void:
	var sheets := int(ceil(cells.size() / 6.0))
	for sheet in sheets:
		var page := Image.create(CELL.x * 2, CELL.y * 3, false, Image.FORMAT_RGB8)
		for i in 6:
			var k := sheet * 6 + i
			if k < cells.size():
				page.blit_rect(cells[k], Rect2i(Vector2i.ZERO, CELL), Vector2i((i % 2) * CELL.x, (i / 2) * CELL.y))
		_save(page, "%s%d" % [name, sheet + 1])
		if not labels.is_empty():
			print("    %s%d: %s" % [name, sheet + 1, ", ".join(labels.slice(sheet * 6, sheet * 6 + 6))])


func _draw_kinds() -> void:
	# --- Every way between rooms, one after another, and a mummy behind each thing that holds one
	await _open({"mode": "custom", "spec": Shapes.every_way()})
	var layout := level.layout as TombLayout3D
	var plan := level.plan
	for link in plan.links:
		var way := layout.ways[link.id]
		if not way.has("from"):
			continue
		var along := Vector3(TombLayout3D.TURNS[int(way["turn"])])
		var from: Vector3 = way["from"]
		var to: Vector3 = way["to"]
		match link.pass_kind:
			TombPlan.Pass.STAIRS:
				if link.id == 0:
					await _snap("stairs, from the court", from - along * 3.0, along)
					await _snap("on the stairs", from + along * 2.6, along)
			TombPlan.Pass.CRAWL:
				await _snap("a crawl", from - along * 2.4, along)
				await _look(from - along * 1.0, along, 20)
				await _walk(along, 12, true, 0.0)
				await _walk(along, 80, true)
				await _hold(30, true)
				_keep("going into the crawl", await _shot())
				await _walk(along, 45, true)
				await _hold(30, true)
				_keep("in the crawl", await _shot())
				await _walk(along, 80, true)
				await _hold(30, true)
				_keep("coming out of the crawl", await _shot())
				touch.duck_held = false
			TombPlan.Pass.GAP:
				var gap: Array = way["gap"]
				await _snap("the pit, and the ring over it", (gap[0] as Vector3) - along * 0.5, along, 60, 0.02)
				await _snap("the pit, looking down into it", (gap[0] as Vector3) - along * 0.4, along, 60, 0.95)
				await _snap("the far side of the pit", (gap[1] as Vector3) + along * 0.5, -along, 60, 0.5)
			TombPlan.Pass.FLOOD:
				await _snap("water", from + along * 1.3, along)
				await _walk(along, 150)
				_keep("swimming", await _shot())
			TombPlan.Pass.SHAFT:
				await _snap("a ladder shaft, from its head", to - along * 2.9 + Vector3.UP * (from.y - to.y), along, 60, 1.0)
				await _snap("a ladder shaft, from its foot", to + along * 1.8, -along, 50, 0.05)
			TombPlan.Pass.OPEN:
				await _snap("a doorway", from - along * 2.8, along)
			TombPlan.Pass.ROPE:
				await _snap("a rope shaft, from its head", (way["upper"] as Vector3) - along * 0.6, along, 50, 0.55)
				await _snap("a rope shaft, from its foot", (way["lower"] as Vector3) + along * 2.4, -along, 50, 0.05)
				# (and on it: he runs off the lip into it)
				await _look(way["upper"], along, 20)
				await _walk(along, 55)
				await _hold(25)
				_keep("on the rope", await _shot())
			TombPlan.Pass.SAND:
				await _snap("the face, before the sand", (way["before"] as Vector3) - along * 0.4, along)
				await _look(layout.switch_at[link.switches[0]], along, 30)
				await _look((way["before"] as Vector3) - along * 0.4, along, 200)
				_keep("the sand coming in", await _shot())
				await _hold(420)
				_keep("the sand, all of it", await _shot())
				await _look((way["before"] as Vector3) - along * 0.4, along, 20)
				await _walk(along, 130)
				await _hold(40)
				_keep("going up the heap", await _shot())
	for part in layout.parts:
		if part["kind"] != "mummy" or part["guardian"]:
			continue
		var along: Vector3 = part["safe_way"]
		var held: Vector3 = part["safe_at"]
		held += Vector3(-along.z, 0.0, along.x) * TombLayout3D.WALK
		var barrier: String = TombPlan.BARRIER_NAMES[plan.rooms[part["room"]].barrier]
		# (he goes by it, which wakes it, and looks back from beyond what holds it)
		await _look(held - along * 3.2, along, 70)
		await _look(held + along * 2.2, -along, 260, 0.38)
		_keep("a mummy held by a %s" % barrier, await _shot())
	for link in plan.links:
		var way := layout.ways[link.id]
		if way.has("from") and int(way["turn"]) != layout.turns[link.a]:
			var along := Vector3(TombLayout3D.TURNS[layout.turns[link.a]])
			await _snap("a corner", (layout.rooms[link.a]["east"] as Vector3) - along * 3.4, along)
			break
	await _close()

	# --- Every lock
	await _open({"mode": "custom", "spec": Shapes.every_lock()})
	layout = level.layout as TombLayout3D
	plan = level.plan
	for room in plan.rooms:
		var info := layout.rooms[room.id]
		var along := Vector3(TombLayout3D.TURNS[int(info["turn"])])
		match room.role:
			TombPlan.Role.LOFT:
				var edge: Vector3 = info["edge"]
				await _snap("a loft, from under its lip", Vector3(edge.x, float(layout.rooms[room.parent]["floor"]), edge.z) - along * 3.0, along, 50, 0.2)
				await _snap("in a loft", info["west"], along)
			TombPlan.Role.CRYPT:
				await _snap("the well", (info["before"] as Vector3) - along * 1.6, along, 50, 0.6)
				await _snap("the crypt under it, and its seal stone", (info["east"] as Vector3) - along * 1.7, -along)
			TombPlan.Role.BURIAL:
				await _snap("the falcon", (info["east"] as Vector3) - along * 2.0, along)
	for trigger in plan.triggers:
		var stand := layout.stand_at[trigger.id]
		var info := layout.rooms[trigger.room]
		var along := Vector3(TombLayout3D.TURNS[int(info["turn"])])
		match trigger.kind:
			TombPlan.Switch.PLATE:
				await _snap("a plate for a block from the room before", stand - along * 1.0 + Vector3(-along.z, 0.0, along.x) * TombLayout3D.WALK, along, 50, 0.5)
			TombPlan.Switch.WORK_PLATE:
				await _snap("a block, and the plate it is pushed onto", stand - along * 5.6 + Vector3(-along.z, 0.0, along.x) * (TombLayout3D.WALK - TombLayout3D.LANE), along, 50, 0.45)
			TombPlan.Switch.OFFERING:
				await _snap("an offering table", stand - along * 2.2, along, 50, 0.45)
			TombPlan.Switch.LEVER:
				if plan.rooms[trigger.room].role != TombPlan.Role.CRYPT:
					await _snap("a seal stone", stand - along * 2.0, along, 50, 0.5)
	# A block for the plate of the room after, standing in the bay in line with the door.
	for block in level.built.blocks:
		if int(block["thing"]) >= 0:
			var body: RigidBody3D = block["body"]
			var info := layout.rooms[plan.things[block["thing"]].room]
			var along := Vector3(TombLayout3D.TURNS[int(info["turn"])])
			await _snap("a block for the plate in the next room", (info["east"] as Vector3) - along * 3.0, along, 50, 0.4)
	# The dark room: he takes up the torch, and goes into it.
	for trigger in plan.triggers:
		if trigger.kind != TombPlan.Switch.BRAZIER:
			continue
		var info := layout.rooms[trigger.room]
		var along := Vector3(TombLayout3D.TURNS[int(info["turn"])])
		await _snap("a dark room, with nothing in his hand", info["west"], along)
		for thing in plan.things:
			if thing.kind != TombPlan.Item.TORCH:
				continue
			var lies: Vector3 = layout.thing_at[thing.id]
			await _look(lies - Vector3(0.5, 0.0, 0.0), Vector3.RIGHT, 30)
			player._act()
			await _hold(90)
			break
		_put(info["west"], along)
		await _hold(70)
		_keep("the same room, with the torch", await _shot())
		_put((layout.stand_at[trigger.id] as Vector3) - along * 2.6, along)
		await _hold(70)
		_keep("the cold brazier, as he comes to it", await _shot())
		_put(layout.stand_at[trigger.id], along)
		await _hold(120)
		_keep("the brazier lit, and the door it opens", await _shot())
	await _close()

	# --- The two plates on one door
	await _open({"mode": "custom", "spec": Shapes.three_new()})
	layout = level.layout as TombLayout3D
	for link in level.plan.links:
		if link.hint == "two_stones":
			var info := layout.rooms[link.a]
			var along := Vector3(TombLayout3D.TURNS[int(info["turn"])])
			await _snap("two plates on one door", (info["west"] as Vector3) + along * 0.5, along, 50, 0.5)
	await _close()
	_sheets(kinds, "kinds", kind_names)


# One kind of thing, seen from `spot` looking `along`.
func _snap(what: String, spot: Vector3, along: Vector3, settle := 50, tilt := 0.32) -> void:
	_keep(what, await _look(_stood(spot), along, settle, tilt))


func _keep(what: String, image: Image) -> void:
	_save(image, "kind_%02d_%s" % [kinds.size() + 1, what.replace(" ", "_").replace(",", "")])
	kinds.append(_small(image))
	kind_names.append(what)


# The floor under a place.
func _stood(spot: Vector3) -> Vector3:
	var hit := player.get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(spot + Vector3.UP * 0.8, spot + Vector3.DOWN * 9.0, 1))
	return hit["position"] if not hit.is_empty() else spot


# Puts him somewhere as he is (with what he carries), looking `along`.
func _put(spot: Vector3, along: Vector3) -> void:
	player.global_position = _stood(spot) + Vector3.UP * 0.05
	player.velocity = Vector3.ZERO
	player.facing_yaw = atan2(along.x, along.z)
	camera.look_along(along)
	camera.snap()


# Walks him `way` for so many frames, steering by the camera as a thumb would.
func _walk(way: Vector3, frames: int, duck := false, push := 0.9) -> void:
	for i in frames:
		var view := camera.global_basis
		var right := Vector3(view.x.x, 0.0, view.x.z).normalized()
		var forward := Vector3(-view.z.x, 0.0, -view.z.z).normalized()
		touch.move = Vector2(way.dot(right), -way.dot(forward)) * push
		touch.duck_held = duck
		await physics_frame
	touch.move = Vector2.ZERO
	await process_frame


func _hold(frames: int, duck := false) -> void:
	for i in frames:
		touch.move = Vector2.ZERO
		touch.duck_held = duck
		await physics_frame
	await process_frame


func _frames(count: int) -> void:
	for i in count:
		await physics_frame
	await process_frame


func _shot() -> Image:
	await RenderingServer.frame_post_draw
	return root.get_texture().get_image()


func _save(image: Image, name: String) -> void:
	var path := out.path_join(name + ".png")
	image.save_png(path)
	print("  saved ", path)


# What each tomb costs to draw, seen each way: from just inside every room, how many draws the frame took and
# how many lights were lit.
func _count_cost() -> void:
	for chosen: Dictionary in tombs:
		for seen: String in ["side", "3d"]:
			await _open(chosen, seen)
			var draws: Array[int] = []
			var lights: Array[int] = []
			for room in level.layout.placed():
				var info := level.layout.rooms[room.id]
				player.global_position = (info["west"] as Vector3) + Vector3.UP * 0.05
				player.velocity = Vector3.ZERO
				player.set_spawn(player.global_position)
				player.respawn()
				camera.snap()
				await _frames(30)
				await RenderingServer.frame_post_draw
				draws.append(int(RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_DRAW_CALLS_IN_FRAME)))
				lights.append(_lit(scene))
			var most_draws := 0
			var sum_draws := 0
			var most_lights := 0
			for i in draws.size():
				most_draws = maxi(most_draws, draws[i])
				sum_draws += draws[i]
				most_lights = maxi(most_lights, lights[i])
			print("COST %s %s: %d rooms; draws a frame on average %d, at most %d; lights lit at most %d; %d pieces of stone in all" % [
					_name_of(chosen), "seen from the side" if seen == "side" else "walked through", draws.size(), sum_draws / maxi(draws.size(), 1), most_draws, most_lights, level.layout.boxes.size()])
			await _close()


func _lit(node: Node) -> int:
	var count := 0
	if node is Light3D and (node as Light3D).is_visible_in_tree():
		count += 1
	for child in node.get_children():
		count += _lit(child)
	return count


func _name_of(chosen: Dictionary) -> String:
	var branching: bool = chosen.get("shape", "line") == "branching"
	if chosen["mode"] == "random":
		return "%s_%d_%d" % ["branch" if branching else "tomb", chosen["seed"], chosen["difficulty"]]
	if chosen["mode"] == "daily" and branching:
		return "branch_daily"
	return "grid" if chosen["mode"] == "plan" else str(chosen["mode"])
