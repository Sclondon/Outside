extends SceneTree
## Not part of the game. Draws generated tombs, to be looked at.
## godot --path . --fixed-fps 60 --resolution 1280x720 --script tools/tomb_sheets.gd -- <folder> [seed:difficulty ...] [daily] [rooms=0]
##
## For each tomb (by default 1:0 2:1 3:2 and today's):
##   <name>_plan.png      the plan as a map: the rooms in section with what is in each, every door with what
##                        opens it and a line to where that is, and the way through that the solver found
##   <name>_overview.png  the whole tomb as built, lit evenly, in strips
##   <name>_rooms.png     each room as he sees it, by its own torches, six to a sheet
##   <name>_room<n>.png   the same, one by one at full size
## Its window is kept off the screen and takes no input.

const STRIP := 44.0
const CELL := Vector2i(640, 360)

var out := ""
var tombs: Array = []
var with_rooms := true


class Map extends Control:
	var layout: TombLayout

	func _draw() -> void:
		var plan := layout.plan
		var font := ThemeDB.fallback_font
		draw_rect(Rect2(Vector2.ZERO, size), Color(0.93, 0.9, 0.82))
		var title := "Tomb seed %d, %s (try %d): plan %s, stone %s.  %d rooms, %d locks, %.0f m long, %.0f m deep.  Checked: %d positions, none dead." % [
			plan.seed_value, TombGenerator.DIFFICULTY_NAMES[plan.difficulty], plan.sub_seed + 1, plan.fingerprint(), layout.fingerprint(),
			plan.rooms.size(), _locks(), layout.length, layout.depth, plan.proof["positions"]]
		draw_string(font, Vector2(16, 26), title, HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color.BLACK)
		# The section, to scale along and twice over up and down.
		var scale_x := (size.x - 80.0) / maxf(layout.length, 1.0)
		var scale_y := minf(scale_x * 2.0, 300.0 / maxf(layout.depth + 10.0, 1.0))
		var origin := Vector2(40.0, 60.0 + 9.0 * scale_y)
		var to_map := func(x: float, y: float) -> Vector2: return origin + Vector2(x * scale_x, -y * scale_y)
		for span in layout.spans:
			var top: Vector2 = to_map.call(span.xa, minf(span.ceil, span.floor + 9.0))
			var low: Vector2 = to_map.call(span.xb, span.floor)
			var colour := Color(0.99, 0.97, 0.9)
			if plan.rooms[span.room].dark:
				colour = Color(0.6, 0.58, 0.62)
			if span.sky:
				colour = Color(0.78, 0.84, 0.95)
			if span.deadly:
				colour = Color(0.2, 0.1, 0.1)
			if span.solid:
				continue
			draw_rect(Rect2(top, low - top), colour)
			draw_line(Vector2(top.x, low.y), low, Color(0.3, 0.25, 0.2), 2.0)
		for box: Array in layout.boxes:
			if box[2] == "loft":
				var at: Vector3 = box[0]
				var extent: Vector3 = box[1]
				var a: Vector2 = to_map.call(at.x - extent.x * 0.5, at.y + extent.y * 0.5)
				var b: Vector2 = to_map.call(at.x + extent.x * 0.5, at.y - extent.y * 0.5)
				draw_rect(Rect2(a, b - a), Color(0.45, 0.38, 0.28))
		for room in plan.rooms:
			var info := layout.rooms[room.id]
			if info.is_empty():
				continue
			var at: Vector2 = to_map.call(float(info["x0"]), float(info["floor"]))
			var name := "%d %s" % [room.id, TombPlan.ROLE_NAMES[room.role]]
			if room.spine >= 0:
				draw_string(font, Vector2(at.x + 2.0, origin.y - 9.0 * scale_y - 6.0 + (room.spine % 2) * 13.0), name, HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color(0.2, 0.2, 0.2))
			else:
				draw_string(font, at + Vector2(2.0, 14.0 if room.role == TombPlan.Role.CRYPT else -30.0), name, HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color(0.3, 0.2, 0.5))
		# Parts: what each is, in a letter.
		for part in layout.parts:
			var place: Vector3 = part["at"]
			var at: Vector2 = to_map.call(place.x, place.y)
			match part["kind"]:
				"door":
					var tall: float = (part["size"] as Vector3).y
					draw_line(to_map.call(place.x, place.y - tall * 0.5), to_map.call(place.x, place.y + tall * 0.5), Color(0.75, 0.1, 0.1), 4.0)
				"item":
					_mark(at, ["T", "H", "J"][int(part["what"])], Color(0.1, 0.45, 0.1))
				"block":
					_mark(at, "B", Color(0.45, 0.3, 0.1))
				"plate":
					_mark(at + Vector2(0, 8), "p", Color(0.75, 0.1, 0.1))
				"lever":
					_mark(at + Vector2(0, 8), "S", Color(0.75, 0.1, 0.1))
				"offering":
					_mark(at + Vector2(0, 8), "o", Color(0.75, 0.1, 0.1))
				"brazier":
					_mark(at, "F", Color(0.75, 0.1, 0.1))
				"treasure":
					_mark(at, "*", Color(0.7, 0.55, 0.0))
				"mummy":
					_mark(at, "M%d" % int(part["what"]), Color(0.4, 0.0, 0.4))
				"ladder":
					draw_line(at, to_map.call(place.x, place.y + float(part["high"])), Color(0.45, 0.3, 0.1), 2.0)
				"pool":
					var extent: Vector3 = part["size"]
					var a: Vector2 = to_map.call(place.x - extent.x * 0.5, place.y)
					var b: Vector2 = to_map.call(place.x + extent.x * 0.5, place.y - extent.y)
					draw_rect(Rect2(a, b - a), Color(0.2, 0.45, 0.7, 0.7))
				"ring":
					draw_arc(at, 4.0, 0.0, TAU, 12, Color.BLACK, 1.5)
				"rope":
					draw_line(at, to_map.call(place.x, place.y - float(part["long"])), Color(0.45, 0.3, 0.1), 1.5)
				"sand":
					# (the heap as it will be when it is full, against its face)
					var cap: float = part["cap"]
					var face := place.x + TombLayout.SAND_OUT
					var foot := layout.door_at[part["link"]].y - TombLayout.SAND_RISE
					draw_colored_polygon(PackedVector2Array([to_map.call(place.x - cap, foot), to_map.call(face, foot + cap * tan(SandPile.SLOPE) * SandPile.PROFILE[0].y), to_map.call(face, foot)]), Color(0.85, 0.7, 0.4, 0.8))
					draw_line(at, to_map.call(place.x, foot), Color(0.85, 0.7, 0.4), 1.5)
		# A line from every door to each thing that opens it.
		for link in plan.links:
			var door := layout.door_at[link.id]
			if door == Vector3.INF:
				continue
			for id in link.switches:
				var from := layout.switch_at[id]
				draw_dashed_line(to_map.call(from.x, from.y), to_map.call(door.x, door.y + 1.0), Color(0.75, 0.1, 0.1, 0.8), 1.5, 6.0)
			draw_string(font, to_map.call(door.x, door.y + 1.0) + Vector2(-20, -16), link.hint, HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color(0.6, 0.0, 0.0))
		# Things that are carried: a line from where each lies to where it is wanted.
		for thing in plan.things:
			var from := layout.thing_at[thing.id]
			for trigger in plan.triggers:
				var wants := -1
				match trigger.kind:
					TombPlan.Switch.BRAZIER:
						wants = TombPlan.Item.TORCH
					TombPlan.Switch.OFFERING:
						wants = TombPlan.Item.JAR
					TombPlan.Switch.PLATE:
						wants = TombPlan.Item.BLOCK
				if wants == thing.kind and absi(plan.rooms[trigger.room].spine - plan.rooms[thing.room].spine) <= 3 and plan.rooms[trigger.room].spine >= plan.rooms[thing.room].spine:
					var to := layout.switch_at[trigger.id]
					draw_dashed_line(to_map.call(from.x, from.y + 0.6), to_map.call(to.x, to.y + 0.6), Color(0.1, 0.45, 0.1, 0.8), 1.5, 3.0)
		# The key, and the way through.
		var y := origin.y + (layout.depth + 3.0) * scale_y + 40.0
		draw_string(font, Vector2(16, y), "T torch  H hook  J jar  B block  p plate  S seal stone  o offering table  F brazier  * the falcon  M mummy (kind)   red: a door (or the sand) and what opens it   green: what is carried, and to where   grey room: dark",
				HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color(0.2, 0.2, 0.2))
		y += 22.0
		var line := "The way through (%d steps): " % plan.solution.size()
		var column := 16.0
		for step: Array in plan.solution:
			var word := TombSolver.words(plan, step) + ";  "
			if font.get_string_size(line + word, HORIZONTAL_ALIGNMENT_LEFT, -1, 12).x > size.x - 32.0:
				draw_string(font, Vector2(column, y), line, HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color.BLACK)
				y += 16.0
				line = "    "
			line += word
		draw_string(font, Vector2(column, y), line, HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color.BLACK)

	func _mark(at: Vector2, letter: String, colour: Color) -> void:
		draw_circle(at + Vector2(0, -8), 8.0, Color(1, 1, 1, 0.85))
		draw_string(ThemeDB.fallback_font, at + Vector2(-5 if letter.length() == 1 else -8, -3), letter, HORIZONTAL_ALIGNMENT_LEFT, -1, 13, colour)

	func _locks() -> int:
		var count := 0
		for link in layout.plan.links:
			if not link.switches.is_empty() or link.pass_kind == TombPlan.Pass.GAP:
				count += 1
		return count


func _initialize() -> void:
	DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_NO_FOCUS, true)
	DisplayServer.window_set_position(Vector2i(-6000, -6000))
	var args := OS.get_cmdline_user_args()
	out = args[0] if not args.is_empty() else "."
	for arg: String in args.slice(1):
		if arg == "daily":
			tombs.append({"mode": "daily"})
		elif arg.begins_with("rooms="):
			with_rooms = arg != "rooms=0"
		else:
			var parts := arg.split(":")
			tombs.append({"mode": "random", "seed": int(parts[0]), "difficulty": int(parts[1]) if parts.size() > 1 else 1})
	if tombs.is_empty():
		tombs = [{"mode": "random", "seed": 1, "difficulty": 0}, {"mode": "random", "seed": 2, "difficulty": 1},
				{"mode": "random", "seed": 3, "difficulty": 2}, {"mode": "daily"}]
	DirAccess.make_dir_recursive_absolute(out)
	run.call_deferred()


func run() -> void:
	TombLevel.bare = true
	for chosen: Dictionary in tombs:
		await _draw_tomb(chosen)
	quit()


func _draw_tomb(chosen: Dictionary) -> void:
	TombLevel.play = chosen
	var scene: Node = load("res://tomb.tscn").instantiate()
	root.add_child(scene)
	await _frames(8)
	var level: TombLevel = scene.get_node("Level")
	var player: Player = scene.get_node("Player")
	var camera: FollowCamera = scene.get_node("Camera")
	var hud: CanvasLayer = scene.get_node("HUD")
	var name := "daily" if chosen["mode"] == "daily" else "tomb_%d_%d" % [chosen["seed"], chosen["difficulty"]]
	print("%s: %s" % [name, level.plan.describe().replace("\n", " | ")])

	# --- The plan
	hud.visible = false
	var layer := CanvasLayer.new()
	root.add_child(layer)
	var map := Map.new()
	map.layout = level.layout
	map.size = Vector2(root.size)
	layer.add_child(map)
	await _frames(3)
	_save(await _shot(), name + "_plan")
	layer.queue_free()

	# --- The whole of it, lit evenly, in strips
	level.set_physics_process(false)
	for node in level.built.room_nodes:
		node.visible = true
	var flood := DirectionalLight3D.new()
	flood.rotation_degrees = Vector3(-25.0, 15.0, 0.0)
	flood.light_energy = 1.1
	root.add_child(flood)
	var eye := Camera3D.new()
	eye.projection = Camera3D.PROJECTION_ORTHOGONAL
	root.add_child(eye)
	eye.current = true
	var strips := int(ceil(level.layout.length / STRIP))
	var tall := level.layout.depth / maxf(float(strips), 1.0) + 14.0
	eye.size = maxf(STRIP * float(root.size.y) / float(root.size.x), 14.0)
	var rows: Array[Image] = []
	for strip in strips:
		var x := (strip + 0.5) * STRIP
		var floor_here := 0.0
		for span in level.layout.spans:
			if span.xa <= x and span.xb > x and not span.deadly:
				floor_here = span.floor
		eye.position = Vector3(x, floor_here + 2.5, 40.0)
		eye.rotation = Vector3.ZERO
		await _frames(4)
		rows.append(await _shot())
	var whole := Image.create(root.size.x, root.size.y * rows.size(), false, Image.FORMAT_RGB8)
	for i in rows.size():
		rows[i].convert(Image.FORMAT_RGB8)
		whole.blit_rect(rows[i], Rect2i(Vector2i.ZERO, root.size), Vector2i(0, i * root.size.y))
	if tall > 0.0:
		_save(whole, name + "_overview")
	flood.queue_free()
	eye.queue_free()
	camera.current = true
	level.set_physics_process(true)

	# --- Each room as he sees it
	if with_rooms:
		var cells: Array[Image] = []
		var number := 0
		for room in level.plan.rooms:
			var info := level.layout.rooms[room.id]
			if info.is_empty():
				continue
			var spots: Array = [info["west"]]
			if float(info["x1"]) - float(info["x0"]) > 12.0 and info.has("east"):
				spots.append(((info["west"] as Vector3) + (info["east"] as Vector3)) * 0.5)
			if info.has("east") and float(info["x1"]) - float(info["x0"]) > 7.0:
				spots.append(info["east"])
			for spot: Vector3 in spots:
				# (wherever he is put, on whatever floor is under it)
				var stand := spot
				if room.spine >= 0:
					for span in level.layout.spans:
						if span.xa <= spot.x and span.xb > spot.x and not span.deadly:
							stand.y = span.floor
				player.global_position = stand + Vector3.UP * 0.05
				player.velocity = Vector3.ZERO
				player.set_spawn(player.global_position)
				player.respawn()
				camera.snap()
				await _frames(40)
				var image := await _shot()
				_save(image, "%s_room%02d_%s" % [name, number, TombPlan.ROLE_NAMES[room.role]])
				image.resize(CELL.x, CELL.y, Image.INTERPOLATE_LANCZOS)
				image.convert(Image.FORMAT_RGB8)
				cells.append(image)
				number += 1
		var sheets := int(ceil(cells.size() / 6.0))
		for sheet in sheets:
			var page := Image.create(CELL.x * 2, CELL.y * 3, false, Image.FORMAT_RGB8)
			for i in 6:
				var k := sheet * 6 + i
				if k < cells.size():
					page.blit_rect(cells[k], Rect2i(Vector2i.ZERO, CELL), Vector2i((i % 2) * CELL.x, (i / 2) * CELL.y))
			_save(page, "%s_rooms%d" % [name, sheet + 1])
	scene.queue_free()
	await _frames(4)


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
