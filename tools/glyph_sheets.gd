extends SceneTree
## Not part of the game. Pictures of the hieroglyphs: a chart of every sign with
## its Gardiner number, how it is typed and what it stands for (which is also
## the documentation: docs/hieroglyph_signs.png is this chart), and inscriptions
## on stone, near and far, in raking sunlight, painted and worn, and in the dark
## with a torch going past.
## godot --path . --resolution 1280x720 --script tools/glyph_sheets.gd -- <outdir> [chart] [stone] [torch] [yard] [prop] [banded]
## With none of chart, stone and torch: all three. `yard` is the station in the test yard. `prop` writes out the signs for the `wall_glyphs` prop (see `prop_signs`). `banded` lights the world in hard
## bands, as the menu can. Add `--rendering-method gl_compatibility` to see it as the web does;
## the pictures are named for the light and the renderer.

const STONE := Color(0.66, 0.57, 0.43)
## The chart: how big a cell is, and how many to a row.
const CELL := Vector2i(150, 176)
const PER_ROW := 10

## Shows a sign's picture (see `Hieroglyphs.texture`) as the plain shape it is.
const FLAT := """
shader_type canvas_item;

void fragment() {
	float inside = texture(TEXTURE, UV).a;
	float edge = max(fwidth(inside), 0.01);
	COLOR = vec4(0.16, 0.12, 0.09, smoothstep(0.5 - edge, 0.5 + edge, inside));
}
"""

var out := ""
var words: Array = []
var stage: Node3D
var cam: Camera3D
var world: WorldEnvironment
var sun: DirectionalLight3D
var tag := ""


func _initialize() -> void:
	DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_NO_FOCUS, true)
	DisplayServer.window_set_position(Vector2i(-6000, -6000))
	var args := OS.get_cmdline_user_args()
	out = args[0]
	words = args.slice(1)
	if "banded" in words:
		words.erase("banded")
		Settings.world_banded = true
	if words.is_empty():
		words = ["chart", "stone", "torch"]
	tag = "%s_%s" % ["banded" if Settings.world_banded else "smooth", "web" if RenderingServer.get_current_rendering_method() == "gl_compatibility" else "mobile"]
	run.call_deferred()


func run() -> void:
	if "chart" in words:
		await chart()
	if "stone" in words or "torch" in words:
		build_stage()
	if "stone" in words:
		await stone()
	if "torch" in words:
		await torch()
	if "yard" in words:
		await yard()
	if "prop" in words:
		prop_signs()
	quit()


func frames(count: int) -> void:
	for i in count:
		await process_frame


func snap(name: String) -> void:
	await frames(4)
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(out.path_join("%s_%s.png" % [name, tag]))
	print("SAVED ", name, "_", tag)


## Every sign, group by group.
func chart() -> void:
	var before := Time.get_ticks_usec()
	for code: String in HieroglyphSigns.SIGNS:
		Hieroglyphs.cell(code)
	print("CHART %d signs drawn in %.1f ms" % [HieroglyphSigns.SIGNS.size(), (Time.get_ticks_usec() - before) / 1000.0])
	var flat := Shader.new()
	flat.code = FLAT
	var material := ShaderMaterial.new()
	material.shader = flat
	var page := Control.new()
	# (a font of the machine's that has the letters Egyptian is written out in)
	var font := SystemFont.new()
	font.font_names = PackedStringArray(["Segoe UI", "Noto Sans", "DejaVu Sans"])
	var y := 12
	for group: Array in HieroglyphSigns.GROUPS:
		var codes: Array = []
		for code: String in HieroglyphSigns.SIGNS:
			if String(HieroglyphSigns.SIGNS[code][3]) in String(group[1]):
				codes.append(code)
		var heading := Label.new()
		heading.text = "%s (%d)" % [group[0], codes.size()]
		heading.add_theme_font_size_override(&"font_size", 26)
		heading.add_theme_color_override(&"font_color", Color(0.2, 0.14, 0.1))
		heading.position = Vector2(16, y)
		page.add_child(heading)
		y += 44
		for i in codes.size():
			var code: String = codes[i]
			var sign: Array = HieroglyphSigns.SIGNS[code]
			var at := Vector2i((i % PER_ROW) * CELL.x + 8, y + (i / PER_ROW) * CELL.y)
			var box := ColorRect.new()
			box.color = Color(0.86, 0.79, 0.66)
			box.position = at + Vector2i(3, 3)
			box.size = CELL - Vector2i(6, 6)
			page.add_child(box)
			var picture := ImageTexture.create_from_image(Hieroglyphs.cell(code))
			var drawn := TextureRect.new()
			drawn.texture = picture
			drawn.material = material
			drawn.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
			# (a square of writing is 100 dots across here)
			var scale := 100.0 / Hieroglyphs.DOTS
			drawn.size = Vector2(picture.get_size()) * scale
			drawn.stretch_mode = TextureRect.STRETCH_SCALE
			drawn.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			drawn.position = Vector2(at) + Vector2(CELL.x * 0.5, 62.0) - drawn.size * 0.5
			page.add_child(drawn)
			for line: Array in [[code + "   " + String(sign[1]) if sign[1] != code else code, 17, 118, Color(0.45, 0.1, 0.05)], [sign[2], 14, 138, Color(0.1, 0.1, 0.1)], [sign[0], 11, 156, Color(0.3, 0.26, 0.2)]]:
				var label := Label.new()
				label.text = line[0]
				label.add_theme_font_size_override(&"font_size", line[1])
				label.add_theme_font_override(&"font", font)
				label.add_theme_color_override(&"font_color", line[3])
				label.position = Vector2(at) + Vector2(6, line[2])
				label.size = Vector2(CELL.x - 12, 18)
				label.clip_text = true
				label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
				page.add_child(label)
		y += ceili(codes.size() / float(PER_ROW)) * CELL.y + 14
	var view := SubViewport.new()
	view.size = Vector2i(PER_ROW * CELL.x + 16, y + 8)
	view.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	view.transparent_bg = false
	var back := ColorRect.new()
	back.color = Color(0.93, 0.89, 0.8)
	back.size = view.size
	view.add_child(back)
	view.add_child(page)
	root.add_child(view)
	await frames(4)
	await RenderingServer.frame_post_draw
	view.get_texture().get_image().save_png(out.path_join("hieroglyph_signs.png"))
	print("SAVED hieroglyph_signs ", view.size)
	view.queue_free()
	await process_frame


func build_stage() -> void:
	stage = Node3D.new()
	root.add_child(stage)
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.56, 0.7, 0.86)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.7, 0.74, 0.8)
	env.ambient_light_energy = 0.7
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	world = WorldEnvironment.new()
	world.environment = env
	stage.add_child(world)
	sun = DirectionalLight3D.new()
	sun.light_color = Color(1.0, 0.95, 0.86)
	sun.shadow_enabled = true
	sun.directional_shadow_max_distance = 120.0
	stage.add_child(sun)
	var ground := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(400, 400)
	ground.mesh = plane
	ground.material_override = Toon.surface(Color(0.74, 0.64, 0.46))
	stage.add_child(ground)
	cam = Camera3D.new()
	cam.fov = 40.0
	stage.add_child(cam)
	cam.make_current()
	light(true)


## Day, with the sun coming from `yaw` degrees round and `pitch` up; or the dark.
func light(day: bool, yaw := -35.0, pitch := -46.0) -> void:
	world.environment.background_color = Color(0.56, 0.7, 0.86) if day else Color(0.02, 0.025, 0.04)
	world.environment.ambient_light_energy = 0.7 if day else 0.06
	sun.rotation_degrees = Vector3(pitch, yaw, 0.0)
	sun.light_energy = 1.25 if day else 0.0
	# (on the web a sun that casts shadows is turned down: see `Sand.sky`)
	if RenderingServer.get_current_rendering_method() == "gl_compatibility":
		sun.light_energy *= 0.3


func look(from: Vector3, at: Vector3, fov := 40.0) -> void:
	cam.global_position = from
	cam.look_at(at)
	cam.fov = fov


## Slabs in the sun.
func stone() -> void:
	var before := Time.get_ticks_usec()
	# Rows, plain: the offering formula.
	var plain := Inscription.slab("@offering", Vector2(3.6, 2.0), 0.3, {"wear": 0.15})
	stage.add_child(plain)
	# A king's titles, painted.
	var painted := Inscription.slab("@king", Vector2(3.6, 1.1), 0.3, {"painted": true, "wear": 0.1, "colour": Color(0.78, 0.72, 0.6)})
	painted.position = Vector3(4.4, 0.0, 0.0)
	stage.add_child(painted)
	# Columns, read from the right: the curse.
	var columns := Inscription.slab("@curse", Vector2(2.4, 2.4), 0.3, {"columns": true, "right_to_left": true, "wear": 0.3})
	columns.position = Vector3(-4.0, 0.0, 0.0)
	stage.add_child(columns)
	# Raised, painted only, and badly worn.
	var raised := Inscription.slab("@hymn", Vector2(3.0, 1.0), 0.3, {"raised": true, "wear": 0.1, "colour": Color(0.78, 0.72, 0.6)})
	raised.position = Vector3(4.4, 1.3, 0.0)
	stage.add_child(raised)
	var inked := Inscription.slab("The door opens to <Tut> who gives light", Vector2(3.0, 0.8), 0.3, {"carved": false, "painted": true, "wear": 0.25, "colour": Color(0.8, 0.75, 0.64)})
	inked.position = Vector3(4.4, 2.5, 0.0)
	stage.add_child(inked)
	var worn := Inscription.slab("@filler", Vector2(7.5, 0.9), 0.3, {"sign_size": 0.3, "fill": true, "wear": 0.75})
	worn.position = Vector3(-1.2, 2.2, 0.0)
	stage.add_child(worn)
	await frames(3)
	print("STONE six slabs made in %.1f ms" % [(Time.get_ticks_usec() - before) / 1000.0])
	for slab: Node in [plain, painted, columns, raised, inked, worn]:
		var carved := slab.get_node(^"Stone/Front") as Inscription
		print("   ", carved.text.left(30), ": ", carved.layout["signs"].size(), " signs in ", carved.layout["lines"], " lines, a square ", snappedf(carved.layout["square"], 0.001), " m, picture ", Hieroglyphs.texture(carved.layout).get_size(), "\n      reads: ", carved.translation())
	light(true)
	look(Vector3(0.6, 1.5, 9.5), Vector3(0.6, 1.5, 0.0), 52.0)
	await snap("stone_all")
	look(Vector3(0.3, 1.1, 3.3), Vector3(0.0, 1.0, 0.0))
	await snap("stone_near")
	look(Vector3(-0.9, 1.4, 0.9), Vector3(-1.0, 1.4, 0.0))
	await snap("stone_close")
	look(Vector3(4.4, 1.6, 4.6), Vector3(4.4, 1.6, 0.0))
	await snap("stone_painted")
	look(Vector3(-4.0, 1.25, 3.4), Vector3(-4.0, 1.25, 0.0))
	await snap("stone_columns")
	look(Vector3(-1.2, 2.65, 5.6), Vector3(-1.2, 2.65, 0.0), 44.0)
	await snap("stone_worn")
	look(Vector3(3.0, 1.7, 24.0), Vector3(0.0, 1.4, 0.0), 55.0)
	await snap("stone_far")
	look(Vector3(8.0, 1.7, 60.0), Vector3(0.0, 1.4, 0.0), 55.0)
	await snap("stone_very_far")
	# Seen along the wall.
	look(Vector3(-7.5, 1.4, 1.6), Vector3(0.0, 1.2, 0.0), 45.0)
	await snap("stone_along")
	# The sun low and nearly along the face, from the left and from above.
	light(true, -84.0, -20.0)
	look(Vector3(0.3, 1.1, 3.3), Vector3(0.0, 1.0, 0.0))
	await snap("stone_raking_side")
	light(true, -8.0, -80.0)
	await snap("stone_raking_top")
	# The sun behind the wall: the face is in shadow.
	light(true, 170.0, -40.0)
	await snap("stone_shade")
	for slab: Node in [plain, painted, columns, raised, inked, worn]:
		slab.queue_free()
	await frames(2)


## A wall in the dark, and a torch carried past it.
func torch() -> void:
	light(false)
	var wall := Inscription.slab("@curse", Vector2(5.0, 2.4), 0.4, {"wear": 0.2, "painted": true})
	stage.add_child(wall)
	var flame := Fire.torch()
	stage.add_child(flame)
	look(Vector3(0.0, 1.3, 4.6), Vector3(0.0, 1.2, 0.0), 50.0)
	for step: Array in [[-1.9, "left"], [0.0, "middle"], [1.9, "right"]]:
		flame.position = Vector3(step[0], 1.5, 0.7)
		await frames(20)
		await snap("torch_" + String(step[1]))
	wall.queue_free()
	flame.queue_free()
	await frames(2)


## The station in the test yard.
func yard() -> void:
	var level: Node = (load("res://test_yard.tscn") as PackedScene).instantiate()
	root.add_child(level)
	await frames(30)
	cam = Camera3D.new()
	root.add_child(cam)
	for view: Array in [["yard_all", Vector3(44, 5.5, -30.5), Vector3(44, 1.4, -46), 60.0], ["yard_wall", Vector3(44, 1.6, -41.5), Vector3(44, 1.4, -48), 60.0],
			["yard_columns", Vector3(42.4, 1.5, -44.5), Vector3(38.8, 1.3, -45), 55.0], ["yard_king", Vector3(44.6, 1.3, -44.6), Vector3(49.2, 0.9, -45), 60.0],
			["yard_hint", Vector3(42.4, 1.0, -43.2), Vector3(40.6, 0.6, -40.6), 50.0], ["yard_name", Vector3(45.6, 1.0, -43.4), Vector3(47.4, 0.7, -40.6), 50.0]]:
		cam.make_current()
		look(view[1], view[2], view[3])
		await snap(view[0])
	level.queue_free()
	await frames(2)


## The writing on the `wall_glyphs` prop, which is a model made in Blender
## (tools/build_props.py) and so cannot carry an `Inscription`: its two faces
## set out here and written to tools/wall_glyphs_signs.json as flat triangles,
## in metres from the middle of the face, for the Python to put on the wall.
func prop_signs() -> void:
	var faces := {}
	var count := 0
	for face: Array in [["front", "@offering"], ["back", "@curse"]]:
		var setter := Inscription.new()
		setter.text = face[1]
		setter.size = Vector2(4.0, 2.5)
		var layout := setter._fitted()
		setter.free()
		var square: float = layout["square"] / 100.0
		var middle: Vector2 = layout["size"] * 0.5
		var triangles: Array = []
		for sign: Array in layout["signs"]:
			var shrink := float(sign[3]) / float(HieroglyphSigns.SIGNS[sign[0]][5])
			for corner: Vector2 in flat(HieroglyphSigns.SIGNS[sign[0]][7]):
				var at := (Vector2(sign[1], sign[2]) + corner * shrink - middle) * square
				triangles.append_array([snappedf(at.x, 0.001), snappedf(-at.y, 0.001)])
		for frame: Array in layout["frames"]:
			if String(frame[0]).begins_with("rule"):
				var box := Rect2((Vector2(frame[1], frame[2]) - middle) * square, Vector2(frame[3], frame[4]) * square)
				for corner: Vector2 in [box.position, Vector2(box.end.x, box.position.y), box.end, box.position, box.end, Vector2(box.position.x, box.end.y)]:
					triangles.append_array([snappedf(corner.x, 0.001), snappedf(-corner.y, 0.001)])
		faces[face[0]] = triangles
		count += triangles.size() / 6
	var file := FileAccess.open("res://tools/wall_glyphs_signs.json", FileAccess.WRITE)
	file.store_string(JSON.stringify(faces))
	file.close()
	print("PROP wall_glyphs_signs.json: %d triangles" % count)


## The strokes of a sign as flat triangles (three corners after three), in the sign's own box.
func flat(strokes: Array) -> PackedVector2Array:
	var pieces: Array = []
	var cuts: Array = []
	for stroke: String in strokes:
		var drawn := Hieroglyphs._drawn([stroke])
		cuts.append_array(drawn[1])
		# (a ring comes as its outside and, turning the other way, its inside)
		var solid: Array = []
		var holes: Array = []
		for shape: PackedVector2Array in drawn[0]:
			(holes if Geometry2D.is_polygon_clockwise(shape) else solid).append(thinned(shape, 0.7))
		for hole: PackedVector2Array in holes:
			solid = without(solid, hole)
		pieces.append_array(solid)
	for cut: PackedVector2Array in cuts:
		if Geometry2D.is_polygon_clockwise(cut):
			cut.reverse()
		pieces = without(pieces, thinned(cut, 0.7))
	var corners := PackedVector2Array()
	for piece: PackedVector2Array in pieces:
		var order := Geometry2D.triangulate_polygon(piece)
		for index in order:
			corners.append(piece[index])
	return corners


## Shapes with a hole taken out of them. Each is first cut in two through the
## middle of the hole, so that what is left never has a hole inside it.
func without(shapes: Array, hole: PackedVector2Array) -> Array:
	var bounds := Rect2(hole[0], Vector2.ZERO)
	for point in hole:
		bounds = bounds.expand(point)
	var out: Array = []
	for shape: PackedVector2Array in shapes:
		var box := Rect2(shape[0], Vector2.ZERO)
		for point in shape:
			box = box.expand(point)
		if not box.intersects(bounds):
			out.append(shape)
			continue
		var split := bounds.get_center().x
		for half: Rect2 in [Rect2(-1000.0, -1000.0, 1000.0 + split, 2000.0), Rect2(split, -1000.0, 1000.0, 2000.0)]:
			var side := PackedVector2Array([half.position, Vector2(half.end.x, half.position.y), half.end, Vector2(half.position.x, half.end.y)])
			for part: PackedVector2Array in Geometry2D.intersect_polygons(shape, side):
				if Geometry2D.is_polygon_clockwise(part):
					continue
				for left: PackedVector2Array in Geometry2D.clip_polygons(part, hole):
					if not Geometry2D.is_polygon_clockwise(left):
						out.append(left)
	return out


## A shape with the points left out that it hardly needs (those nearer than
## `slack` to the line between their neighbours).
func thinned(shape: PackedVector2Array, slack: float) -> PackedVector2Array:
	var kept := PackedVector2Array()
	var count := shape.size()
	for i in count:
		var before := kept[kept.size() - 1] if not kept.is_empty() else shape[count - 1]
		var after := shape[(i + 1) % count]
		var along := (after - before).normalized()
		if absf((shape[i] - before).cross(along)) > slack or (after - before).length() < 0.01:
			kept.append(shape[i])
	return kept if kept.size() >= 3 else shape
