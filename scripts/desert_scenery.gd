class_name DesertScenery
## The desert's rock, as a level has it: what `Desert` and the level editor
## ask to have a cliff, a rock, a field of rocks, the Valley of the Kings or a
## tomb doorway made from an item of the layout; to have the ground painted
## round them and the far hills put up; and to have the rows for the dunes
## and the hills put on the editor's "Level" page.
##
## It is here, and not in `scripts/desert.gd` and the editors, so that those
## have a line each for it and no more.


# Gives those numbers of the ground that a level may not have what they stand at when it does not say.
static func _usual(own: Dictionary) -> void:
	if not own.has("dunes"):
		own["dunes"] = 0
	if not own.has("sharp"):
		own["sharp"] = 0.0 if int(own["dunes"]) == 0 else 0.8
	if not own.has("flat"):
		own["flat"] = 0.35
	if not own.has("hills"):
		own["hills"] = 0.0

## The kinds of item that are made here.
const KINDS: Array[String] = ["cliff", "rock", "rocks", "valley", "tomb_door"]
## How the dunes can be set out, as the editor names them, in the order of `SandDunes.Field`.
const DUNES: Array[String] = ["Scattered, as they were", "Crescents", "Ridges across the wind", "Linked crescents", "Star dunes", "A sea of all kinds"]


## The node for an item of one of `KINDS`.
static func made(item: Dictionary, level: Desert) -> Node3D:
	# Each stands on the ground as it finds it, and has the wind as it blows where it stands.
	var place := Transform3D(level.turn_of(item), level.place_of(item))
	var ground := func(x: float, z: float) -> float:
		var at := place * Vector3(x, 0.0, z)
		return level.height_at(at.x, at.z) - place.origin.y
	var blows := place.basis.inverse() * Vector3(level.terrain.wind.x, 0.0, level.terrain.wind.y)
	var wind := Vector2(blows.x, blows.z)
	match item["kind"]:
		"cliff":
			var cliff := Cliff.from_item(item)
			cliff.ground = ground
			cliff.wind = wind
			return cliff
		"rock":
			var rock := RockFormation.from_item(item)
			rock.wind = wind
			return rock
		"rocks":
			var field := RockField.from_item(item)
			field.ground = ground
			field.wind = wind
			return field
		"valley":
			var valley := KingsValley.from_item(item)
			valley.wind = wind
			return valley
		"tomb_door":
			return TombDoor.from_item(item)
	return null


## Does what the level's rock asks of the ground and the sky: paints the sand
## round it (a beaten path up the valley, pale dust on its floor, bare white
## ground among chalk rocks), and puts the far hills up. Called whenever the
## ground has been made.
static func dress(level: Desert) -> void:
	var old := level.get_node_or_null(^"Horizon")
	if old:
		level.remove_child(old)
		old.queue_free()
	var own: Dictionary = level.layout.get("terrain", {})
	var hills: float = own.get("hills", 0.0)
	if hills > 0.0:
		var horizon := DesertHorizon.new()
		horizon.name = "Horizon"
		horizon.hills = hills
		horizon.distance = level.terrain.size * 0.5 + 170.0
		horizon.seed = level.terrain.seed
		horizon.position.y = level.terrain.rim_height - 1.5
		var sky := level.get_node_or_null(^"Sky") as WorldEnvironment
		if sky and sky.environment and sky.environment.sky and sky.environment.sky.sky_material is ProceduralSkyMaterial:
			horizon.air = (sky.environment.sky.sky_material as ProceduralSkyMaterial).sky_horizon_color
		level.add_child(horizon)
	var sand := level.terrain.ground as SandGround
	if sand == null:
		return
	for item: Dictionary in level.layout["items"]:
		var node: Node3D = level.nodes.get(item["id"])
		if node is KingsValley:
			var valley := node as KingsValley
			for i in valley.paths.size():
				var line := valley.paths[i]
				for at in line.size() - 1:
					var from := valley.global_transform * Vector3(line[at].x, 0.0, line[at].y)
					var to := valley.global_transform * Vector3(line[at + 1].x, 0.0, line[at + 1].y)
					# (the floor of the wadi is pale dust and chippings; down the middle of it feet have beaten a path)
					sand.paint_line(Sand.Kind.WHITE, Vector2(from.x, from.z), Vector2(to.x, to.z), 6.0 * valley.size, 0.55, 5.0)
					sand.paint_line(Sand.Kind.PACKED, Vector2(from.x, from.z), Vector2(to.x, to.z), 1.6 if i == 0 else 1.1, 0.9, 1.6)
					sand.paint_line(Sand.Kind.PALE, Vector2(from.x, from.z), Vector2(to.x, to.z), 1.6 if i == 0 else 1.1, 1.0, 1.6)
			for door in valley.doors:
				# (and from the path to each doorway)
				var out := door.global_transform * Vector3(0.0, 0.0, 5.0)
				var far := door.global_transform * Vector3(0.0, 0.0, 10.0)
				sand.paint_line(Sand.Kind.PACKED, Vector2(out.x, out.z), Vector2(far.x, far.z), 1.0, 0.8, 1.5)
		elif node is RockField:
			var field := node as RockField
			if field.colour.v < 0.7:
				continue
			# Bare white ground between chalk rocks: round the biggest of them, in ragged patches.
			for i in mini(field.rocks.size(), 14):
				var rock: Array = field.rocks[i]
				var at := field.global_transform * (rock[0] as Vector3)
				sand.paint(Sand.Kind.WHITE, Vector2(at.x, at.z) + Vector2(Rock.chance(i, 5) - 0.5, Rock.chance(i, 6) - 0.5) * float(rock[1]) * 2.0,
						float(rock[1]) * lerpf(0.8, 1.6, Rock.chance(i, 7)), 0.85, 3.0)
				sand.paint(Sand.Kind.PACKED, Vector2(at.x, at.z), float(rock[1]) * 1.1, 0.5, 3.0)
		elif node is RockFormation and (node as RockFormation).colour.v > 0.7 and (node as RockFormation).size > 3.0:
			sand.paint(Sand.Kind.WHITE, Vector2(node.global_position.x, node.global_position.z), (node as RockFormation).size * 1.1, 0.7, 3.0)


## The rows of the "Level" page that are about the dunes and the far hills,
## for the editor's panels for a desk. (`editor` is the `LevelEditor`.)
static func desk_rows(editor: Object, own: Dictionary) -> void:
	_usual(own)
	var inspector: Control = editor.get(&"_inspector")
	inspector.add_child(editor.call(&"_caption", "Kind of dunes"))
	var kind := OptionButton.new()
	kind.focus_mode = Control.FOCUS_NONE
	kind.custom_minimum_size.y = 50.0
	for named in DUNES:
		kind.add_item(named)
	kind.selected = int(own.get("dunes", 0))
	kind.item_selected.connect(func(index: int) -> void:
		editor.call(&"_remember")
		editor.call(&"_put_number", own, "dunes", index, "terrain"))
	inspector.add_child(kind)
	editor.call(&"_number", "How sharp their crests are", own, "sharp", 0.0, 1.0, 0.05, "terrain")
	editor.call(&"_number", "Flat ground between them", own, "flat", 0.0, 1.0, 0.05, "terrain")
	editor.call(&"_number", "Far hills (0: none)", own, "hills", 0.0, 1.0, 0.05, "terrain")


## The same rows for the editor's screen for a phone. (`phone` is the `LevelEditorPhone`.)
static func phone_rows(phone: Object, own: Dictionary) -> void:
	_usual(own)
	var rows: Control = phone.get(&"_rows")
	rows.add_child(phone.call(&"_row", "Kind of dunes: %s" % DUNES[clampi(int(own.get("dunes", 0)), 0, DUNES.size() - 1)], func() -> void:
		phone.set(&"_choice", {"title": "Kind of dunes", "options": DUNES, "holder": own, "key": "dunes", "usual": 0})
		phone.call(&"_show", "choice"), "next"))
	for spec: Array in [["How sharp their crests are", "sharp"], ["Flat ground between them", "flat"], ["Far hills (0: none)", "hills"]]:
		phone.call(&"_number_row", phone.call(&"_spec", spec[0], own, spec[1], 0.0, 1.0, 0.05, "terrain"))
