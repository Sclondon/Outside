extends SceneTree
## Not part of the game. Pictures of the desert's ground and rock: dunes, wind
## ripples, rock formations, cliffs, the Valley of the Kings and the far horizon.
## godot --path . --resolution 960x960 --script tools/terrain_sheets.gd -- <outdir> [what ...] [banded] [q0|q1|q2]
##
## `what` is any of (with none, all of them):
##   dunes      the shipped desert's dunes from behind the boy, at noon and with the sun low
##   kinds      each kind of dune field on ground of its own, from a rise and from above
##   ripples    wind ripples at his feet, a little way off and far off
##   rocks      each rock formation, with him beside it; and each stone it comes in
##   field      a field of rocks, from among them and from above
##   cliff      a cliff with him at its foot, on its ledges and on its top; a mesa
##   valley     the Valley of the Kings from its mouth, from inside, a doorway, and from above
##   horizon    the far hills, from the ground and from a height
##   level      the shipped desert where the new things are
##   crests     the shipped desert's highest crests: close, along the crest, far off, at noon and low sun
##   start      the shipped desert from where he starts
##   relief     the shape of the ground alone as a map: the shipped desert and each kind of field
##   looks      each look the sand's ripples have: close, a little way off, and where two meet
## A word like `sharp=0.8` (or dune_height=, scatter=, flat=, seed=, dunes=, ripples=) gives every level that number.
## `full` saves every picture by itself as well, at the size it was drawn (<what>_<name>.png).
## Each is the desert (desert.tscn) made from a layout of the tool's own, kept in a
## file of its own (`LevelLayout.saved_at`): the level made in the game is left alone.
## Prints what each picture costs to draw. Four pictures to a sheet (<what>_NN.png).
## Add `--rendering-method gl_compatibility` before `--script` for the web's renderer.

const CELL := 640
const KEPT := "user://terrain_sheets_layout.json"

var out := ""
var only: Array = []
var scene: Node
var level: Desert
var player: Player
var cam: Camera3D
var cells: Array[Image] = []
var names: Array = []
var prefix := ""
var page := 0
var full := false


func _initialize() -> void:
	DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_NO_FOCUS, true)
	DisplayServer.window_set_position(Vector2i(-6000, -6000))
	var args := OS.get_cmdline_user_args()
	out = args[0]
	only = args.slice(1)
	for quality in 3:
		if "q%d" % quality in only:
			only.erase("q%d" % quality)
			Sand.quality = quality
	if "full" in only:
		only.erase("full")
		full = true
	if "banded" in only:
		only.erase("banded")
		Settings.world_banded = true
	LevelLayout.saved_at = KEPT
	run.call_deferred()


func wanted(what: String) -> bool:
	return only.filter(func(word: String) -> bool: return not "=" in word).is_empty() or what in only


func run() -> void:
	for action: StringName in InputMap.get_actions():
		if not String(action).begins_with("ui_"):
			InputMap.action_erase_events(action)
			Input.action_release(action)
	if wanted("dunes"):
		await dunes()
	for what: String in ["kinds", "ripples", "rocks", "field", "cliff", "valley", "horizon", "crests", "start", "looks", "relief"]:
		if wanted(what) and has_method(what):
			await call(what)
	if wanted("level"):
		await level_views()
	if FileAccess.file_exists(KEPT):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(KEPT))
	quit()


# --- The pictures ---

## The shipped desert's dunes, as he sees them.
func dunes() -> void:
	begin("dunes")
	var layout := LevelLayout.built_in()
	layout["weather"] = 0
	await open(layout)
	for low: bool in [false, true]:
		sun(14.0 if low else 50.0, 118.0 if low else 148.0)
		var when := "low sun" if low else "noon"
		await boy("open dunes, %s" % when, Vector2(-70, 30), -70.0)
		await boy("to the north, %s" % when, Vector2(40, -140), 150.0)
		await boy("east, %s" % when, Vector2(150, 110), 200.0)
		await from_rise("from a rise, %s" % when, Vector2(-160, 150), Vector2(40, -40), 14.0)
	finish()


## Each kind of dune field, on ground with nothing else on it.
func kinds() -> void:
	begin("kinds")
	var names_of := ["scattered, as they were", "crescents", "ridges across the wind", "linked crescents", "star dunes", "all kinds"]
	for kind: int in [1, 2, 3, 4, 5, 0]:
		if "k%d" % kind not in only and only.any(func(word: String) -> bool: return word.begins_with("k") and word.length() == 2):
			continue
		await open(bare_level({"dunes": kind, "sharp": 0.0 if kind == 0 else 0.3}))
		print("GROUND %-24s made in %.0f ms" % [names_of[kind], level.terrain.made_in])
		await from_rise("%s, noon" % names_of[kind], Vector2(-60, 170), Vector2(20, -60), 16.0)
		await shoot("%s, from above" % names_of[kind], Vector3(0, 400, 90), Vector3(0, 0, 0), 50.0)
		sun(15.0, 60.0)
		await from_rise("%s, low sun" % names_of[kind], Vector2(-60, 170), Vector2(20, -60), 16.0)
		await boy("%s, among them" % names_of[kind], Vector2(-20, 60), 200.0)
	finish()


## Wind ripples: at his feet, a little way off, and far off (where there should be none).
func ripples() -> void:
	begin("ripples")
	await open(bare_level({"dunes": 1, "scatter": 0.5}))
	for low: bool in [false, true]:
		if low:
			sun(15.0, 60.0)
		var when := "low sun" if low else "noon"
		var place := stand(Vector2(8, 30), 200.0)
		await shoot("at his feet, %s" % when, place + Vector3(0.5, 1.5, 2.4), place + Vector3(0, 0, -1.5), 55.0, 14)
		await boy("behind him, %s" % when, Vector2(8, 30), 200.0)
		await shoot("a little way off, %s" % when, place + Vector3(0, 2.2, 4), place + Vector3(-6, 0, -16), 55.0)
		await shoot("far off, %s" % when, place + Vector3(0, 3.0, 4), place + Vector3(-30, 0, -90), 30.0)
	finish()


## Each rock formation with him beside it, each model of each kind, and each rock it comes in.
func rocks() -> void:
	begin("rocks")
	var items: Array = []
	var kinds := RockFormation.KINDS
	var widths := [5.0, 7.0, 5.0, 4.5, 9.0, 8.0]
	for k in kinds.size():
		for which in 4:
			items.append({"kind": "rock", "what": kinds[k], "at": [k * 26.0 - 65.0, which * 22.0 - 40.0], "size": widths[k], "seed": which, "stone": 3 if kinds[k] == "outcrop" else 0})
	for stone in 4:
		items.append({"kind": "rock", "what": "haystack", "at": [stone * 14.0 - 21.0, 70.0], "size": 6.0, "seed": 2, "stone": stone})
		items.append({"kind": "rock", "what": "mushroom", "at": [stone * 14.0 - 21.0, 84.0], "size": 4.0, "seed": 1, "stone": stone})
	await open(bare_level({"scatter": 0.0}, items, Vector2(0, 100)))
	for k in kinds.size():
		var node := level.nodes[2 + k * 4] as RockFormation
		print("ROCK %-9s %-12s %4d triangles  %d shapes  %.1f m high" % [kinds[k], node.model, node.triangles, node.shapes, node.height])
		await boy(kinds[k], Vector2(k * 26.0 - 65.0 + 1.0, -40.0 + widths[k] * 0.5 + 2.6), 180.0, 7.5, 2.6)
		await shoot("%ss" % kinds[k], Vector3(k * 26.0 - 65.0 + 22.0, 13.0, -7.0), Vector3(k * 26.0 - 65.0, 1.0, -7.0), 62.0)
	stand(Vector2(0, 92), 180.0)
	await shoot("chalk, limestone, sandstone, basalt", Vector3(0, 7.0, 104.0), Vector3(0, 2.0, 76.0), 55.0)
	sun(15.0, 60.0)
	await boy("mushroom, low sun", Vector2(-65.0 + 1.0, -40.0 + 5.2), 180.0, 7.5, 2.6)
	await shoot("domes, low sun", Vector3(-39.0 + 22.0, 13.0, -7.0), Vector3(-39.0, 1.0, -7.0), 62.0)
	finish()


## A field of rocks: from among them, from a rise, and from above; and a field of dark rubble.
func field() -> void:
	begin("field")
	await open(bare_level({"scatter": 0.25, "dunes": 1}, [
		{"kind": "rocks", "at": [0.0, 0.0], "count": 60, "radius": 70.0, "from": 1.0, "to": 12.0, "mix": 0, "seed": 3, "stone": 0},
		{"kind": "rocks", "at": [120.0, 60.0], "count": 25, "radius": 30.0, "from": 1.5, "to": 8.0, "mix": 4, "seed": 5, "stone": 3},
	], Vector2(0, 80)))
	var all := level.nodes[2] as RockField
	print("FIELD %d rocks  %d triangles  %d shapes" % [all.rocks.size(), all.triangles, all.shapes])
	await boy("among them", Vector2(4, 30), 190.0)
	await from_rise("from a rise", Vector2(-30, 95), Vector2(10, -10), 14.0)
	await shoot("from above", Vector3(0, 150, 60), Vector3(0, 0, 0), 50.0)
	await boy("dark rubble", Vector2(112, 96), 170.0)
	sun(15.0, 60.0)
	await boy("among them, low sun", Vector2(4, 30), 190.0)
	await from_rise("from a rise, low sun", Vector2(-30, 95), Vector2(10, -10), 14.0)
	finish()


## A cliff: with him at its foot, on its ledges and on its top; a bent one; and a mesa.
func cliff() -> void:
	begin("cliff")
	await open(bare_level({"scatter": 0.3, "dunes": 1}, [
		{"kind": "cliff", "at": [0.0, 0.0], "length": 110.0, "bend": 40.0, "height": 14.0, "depth": 16.0, "scree": 0.3, "rough": 2.0, "ways": 2, "seed": 1, "stone": 1},
		{"kind": "cliff", "what": "mesa", "at": [110.0, 30.0], "width": 44.0, "height": 16.0, "scree": 0.35, "rough": 2.0, "ways": 1, "seed": 4, "stone": 2},
		{"kind": "cliff", "what": "mesa", "at": [-110.0, 50.0], "width": 16.0, "height": 11.0, "scree": 0.4, "rough": 1.0, "ways": 0, "seed": 2, "stone": 0},
	], Vector2(0, 60)))
	var made := level.nodes[2] as Cliff
	print("CLIFF %d triangles  %d shapes  ways up at %s" % [made.triangles, made.shapes, made.ways_up])
	await boy("at its foot", Vector2(0, 34), 180.0, 9.0, 3.0)
	await from_rise("all of it", Vector2(-30, 95), Vector2(0, 0), 16.0)
	var way := made.global_transform * made.ways_up[0]
	stand(Vector2(way.x, way.z), 180.0)
	await shoot("a way up", way + Vector3(9, 4, 12), way + Vector3(3, 5, 0), 55.0)
	var up := made.global_transform * Vector3(0.0, made.height, made.top[0].y)
	player.global_position = Vector3(up.x, up.y + 0.1, up.z - 3.0)
	await shoot("on its top", player.global_position + Vector3(8, 5, 10), player.global_position + Vector3(0, 0.5, 0), 55.0)
	await from_rise("a mesa", Vector2(60, 95), Vector2(110, 30), 10.0)
	await from_rise("a butte of chalk", Vector2(-90, 95), Vector2(-110, 50), 4.0)
	sun(15.0, 60.0)
	await from_rise("all of it, low sun", Vector2(-30, 95), Vector2(0, 0), 16.0)
	await from_rise("a mesa, low sun", Vector2(60, 95), Vector2(110, 30), 10.0)
	finish()


## The Valley of the Kings: from its mouth, inside it, a doorway, and from above.
func valley() -> void:
	begin("valley")
	await open(bare_level({"scatter": 0.6, "dunes": 5, "hills": 0.6}, [
		{"kind": "valley", "at": [0.0, -60.0], "y": 0.0, "size": 1.0, "height": 16.0, "tombs": 6, "open": 2, "leads": 1, "seed": 1},
	], Vector2(0, 80)))
	var made := level.nodes[2] as KingsValley
	print("VALLEY %d triangles  %d shapes in its cliffs  %d doorways" % [made.triangles, made.cliff.shapes, made.doors.size()])
	await boy("from its mouth", Vector2(0, 40), 180.0, 8.0, 3.0)
	await boy("inside", Vector2(1, -18), 180.0, 7.0, 2.6)
	var door := made.doors[1].global_transform
	var before := door * Vector3(0.5, 0.0, 9.0)
	stand(Vector2(before.x, before.z), 0.0)
	await shoot("an open doorway", door * Vector3(4.0, 2.6, 15.0), door * Vector3(0.0, 1.6, 0.0), 50.0)
	var shut := made.doors[0].global_transform
	before = shut * Vector3(-0.5, 0.0, 8.0)
	stand(Vector2(before.x, before.z), 0.0)
	await shoot("a shut one", shut * Vector3(-5.0, 2.2, 13.0), shut * Vector3(0.0, 1.6, 0.0), 50.0)
	await shoot("from above", Vector3(0, 190, 60), Vector3(0, 0, -60), 50.0)
	await shoot("from the south-east", Vector3(120, 60, 120), Vector3(0, 8, -60), 50.0)
	sun(15.0, 60.0)
	await boy("from its mouth, low sun", Vector2(0, 40), 180.0, 8.0, 3.0)
	await shoot("the peak, low sun", Vector3(-70, 30, 70), Vector3(-5, 22, -110), 50.0)
	finish()


## The far hills.
func horizon() -> void:
	begin("horizon")
	await open(bare_level({"hills": 0.6}))
	await boy("from the ground", Vector2(0, 0), 180.0)
	await boy("the other way", Vector2(0, 0), 60.0)
	await from_rise("from a height", Vector2(0, 100), Vector2(0, -200), 30.0)
	level.heat(0.0)
	level.mirage.force = 0.0
	await boy("without the heat", Vector2(0, 0), 180.0)
	finish()


## The shipped desert's highest crests.
func crests() -> void:
	begin("crests")
	var layout := LevelLayout.built_in()
	layout["weather"] = 0
	await open(layout)
	# (the highest places on open sand, no two near each other)
	var tops: Array[Vector3] = []
	for pass_no in 3:
		var best := Vector3(0, -100, 0)
		for row in range(-150, 151, 5):
			for column in range(-150, 151, 5):
				var here := Vector3(column, level.height_at(column, row), row)
				var near := false
				for top in tops:
					near = near or Vector2(top.x - here.x, top.z - here.z).length() < 90.0
				for item: Dictionary in layout["items"]:
					if item["kind"] in ["pyramid", "valley", "cliff", "rocks"]:
						near = near or Vector2(float(item["at"][0]) - here.x, float(item["at"][1]) - here.z).length() < 50.0
				if not near and here.y > best.y:
					best = here
		tops.append(best)
		print("CREST %d at %s" % [pass_no, best])
	var blows := level.terrain.wind.normalized()
	var across := Vector2(-blows.y, blows.x)
	for low: bool in [false, true]:
		sun(14.0 if low else 50.0, 118.0 if low else 148.0)
		var when := "low" if low else "noon"
		for i in tops.size():
			var top := Vector2(tops[i].x, tops[i].z)
			# on its back just short of the crest, looking along it; below its slip face looking up; and from far off, both sides
			await boy("c%d along, %s" % [i, when], top - blows * 3.0 - across * 6.0, rad_to_deg(atan2(across.x, across.y)))
			await boy("c%d up the face, %s" % [i, when], top + blows * 16.0, rad_to_deg(atan2(-blows.x, -blows.y)) + 25.0)
			await from_rise("c%d from 60 m, %s" % [i, when], top + blows * 45.0 + across * 40.0, top, 5.0, 40.0)
			await from_rise("c%d from 130 m, %s" % [i, when], top - blows * 60.0 + across * 115.0, top, 8.0, 30.0)
	finish()


## Each look the sand's ripples have (`Sand.Ripples`): at his feet, behind him and
## a little way off, at noon and with the sun low; and, mixed, places where two
## looks meet.
func looks() -> void:
	begin("looks")
	var names_of := ["soft", "mixed", "fine"]
	for look: int in [0, 2, 1]:
		await open(bare_level({"dunes": 1, "scatter": 0.5, "ripples": look}))
		for low: bool in [false, true]:
			sun(15.0 if low else 50.0, 60.0 if low else 148.0)
			var when := "low sun" if low else "noon"
			var place := stand(Vector2(8, 30), 200.0)
			await shoot("%s at his feet, %s" % [names_of[look], when], place + Vector3(0.5, 1.5, 2.4), place + Vector3(0, 0, -1.5), 55.0, 14)
			await boy("%s behind him, %s" % [names_of[look], when], Vector2(8, 30), 200.0)
			await shoot("%s a little way off, %s" % [names_of[look], when], place + Vector3(0, 2.2, 4), place + Vector3(-6, 0, -16), 55.0)
			await boy("%s on a dune, %s" % [names_of[look], when], Vector2(-52, 62), 250.0)
	# (still the mixed one) Where fine lines give way to soft waves, and soft waves to bare sand.
	for edge: float in [0.65, 0.3]:
		var found := Vector2.ZERO
		var best := 1.0
		for row in range(-120, 121, 3):
			for column in range(-120, 121, 3):
				var at := Vector2(column, row)
				var slope := absf(level.height_at(at.x + 2.0, at.y) - level.height_at(at.x - 2.0, at.y)) + absf(level.height_at(at.x, at.y + 2.0) - level.height_at(at.x, at.y - 2.0))
				var off := absf(lay(at) - edge) + slope * 0.5 + at.length() * 0.0005
				if off < best:
					best = off
					found = at
		for low: bool in [false, true]:
			sun(15.0 if low else 50.0, 60.0 if low else 148.0)
			var what := "lines meet waves" if edge > 0.5 else "waves meet bare sand"
			await boy("%s, %s" % [what, "low sun" if low else "noon"], found + Vector2(0, 3), 180.0)
			await from_rise("%s from 5 m, %s" % [what, "low sun" if low else "noon"], found + Vector2(0, 9), found + Vector2(0, -4), 5.0, 55.0)
	finish()


# What the sand shader's `lay` comes to at a place: which look the ripples have there when they are mixed.
func lay(at: Vector2) -> float:
	return shader_patches(at / 29.0 + Vector2(17.0, 17.0)) + (shader_patches(at / 15.0 - Vector2(9.1, 9.1)) - 0.5) * 0.2


func shader_patches(p: Vector2) -> float:
	var whole := p.floor()
	var part := p - whole
	part = part * part * (Vector2(3.0, 3.0) - 2.0 * part)
	return lerpf(lerpf(shader_hash(whole), shader_hash(whole + Vector2(1, 0)), part.x), lerpf(shader_hash(whole + Vector2(0, 1)), shader_hash(whole + Vector2(1, 1)), part.x), part.y)


func shader_hash(p: Vector2) -> float:
	var q := Vector3(fposmod(p.x * 0.1031, 1.0), fposmod(p.y * 0.1031, 1.0), fposmod(p.x * 0.1031, 1.0))
	var add := q.dot(Vector3(q.y, q.z, q.x) + Vector3.ONE * 33.33)
	q += Vector3.ONE * add
	return fposmod((q.x + q.y) * q.z, 1.0)


## The shape of the ground alone, as a map lit from low in the east (north at the
## top, 4 dots to a square of the grid; ground that dunes keep off is tinted
## blue): the shipped desert, and each kind of field on bare ground.
func relief() -> void:
	begin("relief")
	var shipped := LevelLayout.built_in()
	var tried := ""
	for word: String in only:
		if "=" in word:
			tried += "_" + word.replace("=", "")
	await open(shipped)
	relief_map("shipped" + tried)
	if tried != "":
		return
	for kind: int in [1, 2, 3, 4, 5]:
		await open(bare_level({"dunes": kind}))
		relief_map("kind%d" % kind)


func relief_map(name: String) -> void:
	var ground := level.terrain
	var side := ground._grid_side
	var claimed := ground._claimed()
	var image := Image.create(side * 4, side * 4, false, Image.FORMAT_RGB8)
	var light := Vector3(-0.8, 0.45, 0.3).normalized()
	var steepest := 0.0
	for y in side * 4:
		for x in side * 4:
			var at := Vector2(x * 0.25 * ground._grid_step - ground.size * 0.5, y * 0.25 * ground._grid_step - ground.size * 0.5)
			var here := ground.height_at(at.x, at.y)
			var facing := Vector3(here - ground.height_at(at.x + 0.6, at.y), 0.6, here - ground.height_at(at.x, at.y + 0.6)).normalized()
			steepest = maxf(steepest, rad_to_deg(acos(facing.y)))
			var lit := clampf(0.55 + (facing.dot(light) - light.y) * 1.3, 0.0, 1.0)
			var spoken: float = claimed[clampi(int((at.y + ground.size * 0.5) / ground.size * 128.0), 0, 127) * 128 + clampi(int((at.x + ground.size * 0.5) / ground.size * 128.0), 0, 127)]
			image.set_pixel(x, y, Color(lit, lit, lit).lerp(Color(lit * 0.6, lit * 0.7, lit), spoken * 0.6))
	image.save_png(out.path_join("relief_%s.png" % name))
	print("RELIEF %s: steepest %.1f degrees" % [name, steepest])


## The shipped desert from where he starts, looking each way.
func start() -> void:
	begin("start")
	var layout := LevelLayout.built_in()
	layout["weather"] = 0
	await open(layout)
	var from := Vector2(0, 165)
	for item: Dictionary in layout["items"]:
		if item["kind"] == "start":
			from = Vector2(item["at"][0], item["at"][1])
	for low: bool in [false, true]:
		if low:
			sun(14.0, 118.0)
		for yaw: float in [180.0, 120.0, 240.0, 0.0]:
			await boy("start, facing %d%s" % [int(yaw), ", low" if low else ""], from, yaw)
	finish()


## The shipped desert, where the new things are.
func level_views() -> void:
	begin("level")
	var layout := LevelLayout.built_in()
	layout["weather"] = 0
	await open(layout)
	await boy("from the start", Vector2(0, 165), 180.0)
	await boy("to the valley", Vector2(-92, -18), 205.0, 8.0, 3.0)
	await boy("in the valley", Vector2(-128, -92), 180.0, 7.0, 2.6)
	await boy("the chalk rocks", Vector2(-112, 96), 262.0)
	await boy("among the chalk rocks", Vector2(-150, 100), 200.0)
	await boy("the cliff behind the pyramid", Vector2(52, -128), 180.0, 8.0, 3.0)
	await boy("the mesa", Vector2(150, -84), 150.0, 8.0, 3.0)
	await shoot("from above", Vector3(0, 420, 120), Vector3(0, 0, -10), 50.0)
	await shoot("the north-west from above", Vector3(-60, 150, 40), Vector3(-120, 0, -110), 50.0)
	await from_rise("from the great pyramid", Vector2(0, -97), Vector2(0, 60), 33.0, 60.0)
	await from_rise("over the dunes to the west", Vector2(-30, 60), Vector2(-160, 40), 12.0)
	await from_rise("to the far hills", Vector2(60, 150), Vector2(170, -120), 6.0, 40.0)
	finish()


## A level with nothing in it but what is given: the ground's numbers (over the
## shipped desert's) and a list of items (each is given an id).
func bare_level(terrain := {}, items: Array = [], start := Vector2.ZERO) -> Dictionary:
	var own := {"size": 400.0, "cell": 2.5, "dune_height": 7.0, "seed": 7, "scatter": 1.0, "rim_height": 9.0, "rim_width": 45.0,
		"wind": [-0.96, -0.28], "dunes": 5, "sharp": 0.3, "flat": 0.35}
	own.merge(terrain, true)
	var all: Array = [{"id": 1, "kind": "start", "at": [start.x, start.y], "lift": 0.0, "yaw": 0.0}]
	for item: Dictionary in items:
		var made := item.duplicate(true)
		made["id"] = all.size() + 1
		if not made.has("lift") and not made.has("y"):
			made["lift"] = 0.0
		if not made.has("yaw"):
			made["yaw"] = 0.0
		all.append(made)
	return {"version": 1, "terrain": own, "weather": 0, "mirage": 0.5, "items": all}


# --- Making a desert, and taking pictures of it ---

func begin(what: String) -> void:
	prefix = what
	page = 0
	cells.clear()
	names.clear()


func finish() -> void:
	if not cells.is_empty():
		sheet()


## Opens the desert made from a layout.
func open(layout: Dictionary) -> void:
	if scene:
		scene.queue_free()
		await process_frame
		await process_frame
	# (for trying numbers out: any of dune_height=, scatter=, flat=, seed=, dunes=, sharp=, ripples= given as words)
	for word: String in only:
		if "=" in word:
			layout["terrain"][word.get_slice("=", 0)] = float(word.get_slice("=", 1))
	var file := FileAccess.open(KEPT, FileAccess.WRITE)
	file.store_string(LevelLayout.to_text(layout))
	file.close()
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
	print("OPENED %s in %d ms" % [prefix, Time.get_ticks_msec() - began])
	for i in 20:
		await physics_frame
	for child in level.get_node("Items").get_children():
		if child is Brother or child is Cat:
			child.queue_free()


## Turns the sun: how high it stands and which way it shines from, in degrees.
func sun(high: float, bearing: float) -> void:
	var light := level.get_node("Sun") as DirectionalLight3D
	light.rotation_degrees = Vector3(-high, bearing, 0.0)


func stand(at: Vector2, yaw_degrees: float) -> Vector3:
	var place := Vector3(at.x, 0.0, at.y)
	place.y = level.height_at(at.x, at.y) + 0.05
	var probe := PhysicsRayQueryParameters3D.create(place + Vector3.UP * 60.0, place + Vector3.DOWN * 5.0, 1)
	var hit := level.get_world_3d().direct_space_state.intersect_ray(probe)
	if not hit.is_empty():
		place.y = (hit["position"] as Vector3).y + 0.05
	player.global_position = place
	player.velocity = Vector3.ZERO
	player.facing_yaw = deg_to_rad(yaw_degrees)
	return place


## A picture from where the game's camera would be: behind him, a little above.
## `yaw` is the way he and the camera face, in degrees (0: towards +z).
func boy(name: String, at: Vector2, yaw_degrees: float, back := 6.0, up := 2.3) -> void:
	var place := stand(at, yaw_degrees)
	var way := Vector3(sin(deg_to_rad(yaw_degrees)), 0.0, cos(deg_to_rad(yaw_degrees)))
	await shoot(name, place - way * back + Vector3.UP * up, place + Vector3.UP * 1.0 + way * 2.0, 55.0, 14)


## A picture from so far above the ground at a place, looking at another.
func from_rise(name: String, at: Vector2, to: Vector2, up: float, fov := 50.0) -> void:
	var from := Vector3(at.x, level.height_at(at.x, at.y) + up, at.y)
	await shoot(name, from, Vector3(to.x, level.height_at(to.x, to.y), to.y), fov)


func shoot(name: String, from: Vector3, to: Vector3, fov: float, frames := 8) -> void:
	cam.global_position = from
	cam.look_at(to)
	cam.fov = fov
	# (the ground draws itself finely round whatever it follows: here, the camera's subject)
	for i in frames:
		cam.make_current()
		await physics_frame
		await process_frame
	await RenderingServer.frame_post_draw
	var image := root.get_texture().get_image()
	var side: int = mini(image.get_width(), image.get_height())
	image = image.get_region(Rect2i((image.get_width() - side) / 2, (image.get_height() - side) / 2, side, side))
	image.resize(CELL, CELL, Image.INTERPOLATE_LANCZOS)
	if full:
		root.get_texture().get_image().save_png(out.path_join("%s_%s.png" % [prefix, name.replace(",", "").replace(" ", "_")]))
	cells.append(image)
	names.append(name)
	print("VIEW %-9s %-28s draw calls %4d  triangles %7d  frame %5.2f ms" % [prefix, name,
		Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME),
		Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME),
		Performance.get_monitor(Performance.TIME_PROCESS) * 1000.0])
	if cells.size() == 4:
		sheet()


func sheet() -> void:
	var whole := Image.create(CELL * 2, CELL * 2, false, cells[0].get_format())
	for i in cells.size():
		whole.blit_rect(cells[i], Rect2i(0, 0, CELL, CELL), Vector2i((i % 2) * CELL, (i / 2) * CELL))
	var path := out.path_join("%s_%02d.png" % [prefix, page])
	whole.save_png(path)
	print("SHEET %s: %s" % [path, ", ".join(names)])
	page += 1
	cells.clear()
	names.clear()
