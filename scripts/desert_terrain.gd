@tool
class_name DesertTerrain
extends StaticBody3D
## The ground of the desert level: dunes, made here from a height function,
## with a collider to match. Nothing of it is saved in the scene; it is made
## again whenever the scene opens, in the editor as in the game.
##
## The dunes are pressed level wherever a `TerrainPad` is (see
## `scripts/desert_pad.gd`): move a pad in the editor and the ground follows.
## The "Rebuild" button in the inspector makes it again by hand.
##
## It can also be given its whole shape as a layout (`shape_from`, and see
## `LevelLayout`): pads, dunes placed by hand, and water (ponds and rivers,
## which are cut into it). That is how the game makes it, from the layout the
## level editor saves; `layout_file` has the editor here do the same.
##
## The dunes are `SandDunes` (crescents and ridges shaped by `wind`): see
## `dunes_at`. `dunes` says how they are set out: scattered by chance, as they
## always were (0, and what a level has that does not say), or as a field in
## rows across the wind, of one kind or of all (`SandDunes.Field`); `sharp` is
## how much of a crease their crests are, and `flat` how much level ground
## lies between the rows. In a field the flat ground between dunes is harder
## and paler (it is painted so), and a dune runs out to nothing where it would
## stand on a pad, a pond, a cliff or a field of rocks. In the game the ground is drawn by a `SandGround` (the `ground`
## here), which takes footprints and follows the player with a fine mesh; it
## is given these heights and this node keeps the collider. In the editor,
## where only tool scripts run, it is drawn as plain pieces of mesh instead:
## the same shape, without the prints.
##
## It has no edge. Past its own square (`size` across) the dune sea goes on
## for as far as anyone walks: the square's own open sand, as it is before any
## pad or water, over and over in every direction. The dunes are made so that
## the square meets itself (`SandDunes.wrap`), and whatever a level puts
## within `JOIN` metres of the square's edge runs out into that open sand, so
## there is nothing to see or to trip on where the one becomes the other.
## `height_at` answers out there as it does within, the `SandGround` draws it,
## and it is solid a piece at a time, round whoever is out there (`_tread`).

## How far the ground runs, edge to edge, in metres.
@export var size := 400.0:
	set(value):
		size = value
		queue_rebuild()
## The side of one square of the mesh, in metres. Smaller is smoother and
## costs more: the ground has 2 * (size / cell)^2 triangles.
@export var cell := 2.5:
	set(value):
		cell = maxf(value, 0.5)
		queue_rebuild()
## How high the big dunes stand above the hollows between them, roughly half
## of it each way.
@export var dune_height := 7.0:
	set(value):
		dune_height = value
		queue_rebuild()
## A different number gives different dunes.
@export var seed := 7:
	set(value):
		seed = value
		queue_rebuild()
## Beyond this many metres from the camera a piece of ground is drawn coarsely
## (0: never).
@export var far_from := 130.0:
	set(value):
		far_from = value
		queue_rebuild()
## The way the wind blows, over the ground (x, z): the dunes lie across it.
@export var wind := Vector2(0.96, 0.28):
	set(value):
		wind = value
		queue_rebuild()
## How thickly dunes are scattered over it by chance: 1 is as many as its size
## calls for, 0 none (only those placed by hand are left).
@export var scatter := 1.0:
	set(value):
		scatter = maxf(value, 0.0)
		queue_rebuild()
## How the dunes are set out (`SandDunes.Field`): 0 scattered by chance, 1
## crescents, 2 long ridges across the wind, 3 ridges of linked crescents, 4
## star dunes, 5 all of them, each where it belongs.
@export_range(0, 5) var dunes := 0:
	set(value):
		dunes = clampi(value, 0, 5)
		queue_rebuild()
## How sharp the crests are, 0..1 (see `SandDunes.sharp`).
@export_range(0.0, 1.0) var sharp := 0.0:
	set(value):
		sharp = clampf(value, 0.0, 1.0)
		queue_rebuild()
## In a field of dunes: how much level ground lies between one row and the next, 0..1.
@export_range(0.0, 1.0) var flat := 0.35:
	set(value):
		flat = clampf(value, 0.0, 1.0)
		queue_rebuild()
## A layout to take its shape from when the scene opens (the game gives it
## one itself: see `scripts/desert.gd`).
@export_file("*.json") var layout_file := ""
@export_tool_button("Rebuild") var _rebuild_button := rebuild

## Sent when the ground has been made, if it was made a part at a time (see `rebuild`).
signal laid

## In the game: what draws the ground (see `SandGround`). None in the editor.
var ground: Node3D
## Whether it is being made just now, a part at a time: until `laid`, there is no ground to stand anything on.
var laying := false
## How long the ground last took to make, in thousandths of a second.
var made_in := 0.0

## How many squares a side each piece of the mesh is: what is behind the camera
## is then not drawn.
const CHUNK := 20
## Far pieces are drawn with one square for every FAR_STRIDE each way, and a skirt
## this deep round them.
const FAR_STRIDE := 4
const FAR_SKIRT := 2.5
const FAR_MARGIN := 12.0
## Ground that is spoken for (see `_claimed`) is kept on a grid this many squares a side, and dunes run out to
## nothing over this many metres as they come to it.
const CLAIM_SIDE := 128
const CLAIM_FADE := 9.0
## Dunes set out by the level stand no nearer its edge than this (those past
## the edge are its own, come round again).
const KEEP_IN := 22.5
## Over this many metres inside the edge, whatever the level has made of the
## ground (a pad, a river's bed) runs out into the open sand that lies beyond.
const JOIN := 30.0
## Past the edge the ground is made solid in pieces this many squares a side,
## those within `TREAD_REACH` pieces of whoever is out there.
const TREAD := 32
const TREAD_REACH := 2

# Each pad: [world-to-pad Transform3D, half size, round, ease, height]
var _pads: Array = []
# Whether the pads were given (`shape_from`, `use_pads`) and not to be looked for in the scene.
var _given := false
# Dunes placed by hand: ["dune", at, width, height, horns] or ["ridge", from, to, height].
var _extra: Array = []
# Water cut into the ground. Each: [points, half width, depth, level asked for
# (from the ground at its first point), bank, bounds, level (worked out), id].
var _carves: Array = []
var _dunes: SandDunes
# Ground that dunes keep off besides the pads and ponds: [middle, how far round it].
var _clear: Array = []
# And where things stand, which a field of dunes leaves room for: the same.
var _stand: Array = []
# The heights as last made, corner by corner, and how the grid lies: what `height_at` reads.
var _grid := PackedFloat32Array()
var _grid_side := 0
var _grid_step := 1.0
# In a field of dunes: which way each square of the grid is split into its two
# triangles (`SandDunes.splits`). Empty: all one way, as they always were.
var _splits := PackedByteArray()
# The open sand that lies past the edge, over and over: a grid like `_grid`.
var _far := PackedFloat32Array()
# The pieces of it that are solid just now, by which piece each is (Vector2i),
# and their shapes, kept by which part of the square each is.
var _trodden := {}
var _tread_shapes := {}
## How long the last new piece of ground past the edge took to make solid, in thousandths of a second.
var tread_ms := 0.0
var _made: Array[Node] = []
var _wait := -1.0


func _ready() -> void:
	add_to_group(&"terrain")
	if not _given and layout_file != "" and FileAccess.file_exists(layout_file):
		var read: Variant = JSON.parse_string(FileAccess.get_file_as_string(layout_file))
		if read is Dictionary:
			shape_from(read)
	rebuild(true)


func _process(delta: float) -> void:
	if not Engine.is_editor_hint():
		_tread()
		return
	if _wait >= 0.0:
		_wait -= delta
		if _wait < 0.0:
			rebuild()


## Asks for the ground to be made again shortly (in the editor: pads call this
## as they are moved).
func queue_rebuild() -> void:
	if is_inside_tree() and Engine.is_editor_hint():
		_wait = 0.3


# --- The two seams ---

## How high the open sand stands at a place, before pads and the rim: a field
## of dunes from `SandDunes`, a little below nought between them. Replace this
## to change the dunes.
func dunes_at(x: float, z: float) -> float:
	if _dunes == null:
		_make_dunes()
	return _dunes.height_at(x, z) - 0.2 * dune_height


## What the ground is drawn with.
func sand_material() -> Material:
	if Engine.is_editor_hint():
		# (in the editor only tool scripts run, so `Sand.surface` cannot be called)
		var shader := Shader.new()
		shader.code = Sand.SHADER
		var shown := ShaderMaterial.new()
		shown.shader = shader
		return shown
	return Sand.surface()


# --- Height ---

## How high the ground stands at a place (in this node's own space): once it
## has been made, exactly what is stood on there.
func height_at(x: float, z: float) -> float:
	if _grid_side > 1:
		var across := (x + size * 0.5) / _grid_step
		var down := (z + size * 0.5) / _grid_step
		var grid := _grid
		var last := _grid_side - 1.0
		if across < 0.0 or down < 0.0 or across > last or down > last:
			# (past the edge: the open sand, over and over)
			grid = _far
			across = fposmod(across, last)
			down = fposmod(down, last)
		across = clampf(across, 0.0, last - 0.0001)
		down = clampf(down, 0.0, last - 0.0001)
		var corner := int(down) * _grid_side + int(across)
		var part := Vector2(across - int(across), down - int(down))
		var a := grid[corner]
		var d := grid[corner + _grid_side + 1]
		var b := grid[corner + 1]
		var c := grid[corner + _grid_side]
		# (each square is two triangles, split the way the collider splits it: see `_splits`)
		if _splits.size() > 0 and _splits[int(down) * (_grid_side - 1) + int(across)] == 1:
			if part.x + part.y < 1.0:
				return a + part.x * (b - a) + part.y * (c - a)
			return d + (1.0 - part.x) * (c - d) + (1.0 - part.y) * (b - d)
		if part.x > part.y:
			return a + part.x * (b - a) + part.y * (d - b)
		return a + part.y * (c - a) + part.x * (d - c)
	var height := _dry_at(x, z)
	for carve: Array in _carves:
		if (carve[5] as Rect2).has_point(Vector2(x, z)):
			height = _carved(height, carve, x, z)
	return height


# The ground before any water is cut into it.
func _dry_at(x: float, z: float) -> float:
	var height := _open_at(x, z)
	for pad: Array in _pads:
		height = _pressed(height, pad, x, z)
	return height


## Takes its whole shape from a layout (see `LevelLayout`): its own numbers
## from `terrain`, and from `items` the pads, the dunes placed by hand, and
## the ponds and rivers. Call `rebuild` afterwards.
func shape_from(layout: Dictionary) -> void:
	var own: Dictionary = layout.get("terrain", {})
	size = own.get("size", size)
	cell = own.get("cell", cell)
	dune_height = own.get("dune_height", dune_height)
	seed = int(own.get("seed", seed))
	# (a level from before the desert went on for ever may say how high its rim was: there is none now)
	scatter = own.get("scatter", scatter)
	# (a level from before there were kinds of dune has them as they were: scattered, and round at the crest)
	dunes = int(own.get("dunes", 0))
	sharp = own.get("sharp", 0.0 if dunes == 0 else 0.3)
	flat = own.get("flat", 0.35)
	var blows: Array = own.get("wind", [wind.x, wind.y])
	wind = Vector2(blows[0], blows[1])
	var pads: Array = []
	_extra.clear()
	_carves.clear()
	_clear.clear()
	_stand.clear()
	_grid_side = 0
	for item: Dictionary in layout.get("items", []):
		var at := Vector2(item["at"][0], item["at"][1])
		var yaw := deg_to_rad(item.get("yaw", 0.0))
		match item.get("kind", ""):
			"pad":
				pads.append([Transform3D(Basis(Vector3.UP, yaw), Vector3(at.x, item.get("y", 0.0), at.y)),
						Vector2(item.get("half_x", 10.0), item.get("half_z", 10.0)), item.get("round", false), item.get("ease", 10.0)])
			"dune" when item.get("what", "") == "star":
				_extra.append(["star", at, item.get("width", 60.0), item.get("height", 8.0), int(item.get("arms", 3)), int(item.get("id", 0))])
			"dune" when item.get("what", "") == "linked":
				var lie: Vector2 = Vector2(sin(yaw), cos(yaw)) * float(item.get("length", 120.0)) * 0.5
				_extra.append(["linked", at - lie, at + lie, item.get("height", 6.0), int(item.get("id", 0))])
			# Rock (see `scripts/desert_scenery.gd`): the valley stands on level ground of its own, and dunes keep off all of it.
			"valley":
				var reach: float = item.get("size", 1.0)
				pads.append([Transform3D(Basis(Vector3.UP, yaw), Vector3(at.x, item.get("y", 0.0), at.y)), Vector2(62.0, 82.0) * reach, false, 14.0])
			"cliff":
				var long: float = item.get("length", 80.0)
				if item.get("what", "") == "mesa":
					_clear.append([at, float(item.get("width", 40.0)) * 0.6 + 10.0])
				else:
					for part in 5:
						_clear.append([at + Vector2(cos(yaw), -sin(yaw)) * long * (part / 4.0 - 0.5), float(item.get("depth", 10.0)) + 8.0])
			"rocks":
				_clear.append([at, float(item.get("radius", 40.0)) * 0.9])
			"rock":
				_clear.append([at, float(item.get("size", 4.0)) * 1.5])
			# And whatever else stands in the level: a field of dunes leaves it room (dunes scattered by chance never did).
			"pyramid":
				_stand.append([at, float(item.get("base", 40.0)) * 0.72 + 3.0])
			"pool":
				_stand.append([at, maxf(item.get("size_x", 6.0), item.get("size_z", 6.0)) * 0.7 + 2.0])
			# (but not for a palm, a stone or any other prop: those stand on a dune as they find it)
			"thing", "person", "door", "mover", "plate", "train", "start", "checkpoint", "ladder", "inscription":
				_stand.append([at, 2.0 * float(item.get("scale", 1.0))])
			"dune":
				_extra.append(["dune", at, item.get("width", 40.0), item.get("height", 5.0), item.get("horns", 0.55)])
			"ridge":
				var along: Vector2 = Vector2(sin(yaw), cos(yaw)) * float(item.get("length", 80.0)) * 0.5
				_extra.append(["ridge", at - along, at + along, item.get("height", 6.0)])
			"pond":
				_add_carve(PackedVector2Array([at]), item.get("radius", 8.0), item)
			"river":
				var points := PackedVector2Array()
				for point: Array in item.get("points", [item["at"]]):
					points.append(Vector2(point[0], point[1]))
				_add_carve(points, item.get("width", 8.0) * 0.5, item)
	use_pads(pads)


func _add_carve(points: PackedVector2Array, half: float, item: Dictionary) -> void:
	var bank: float = item.get("bank", 5.0)
	var bounds := Rect2(points[0], Vector2.ZERO)
	for point in points:
		bounds = bounds.expand(point)
	_carves.append([points, half, item.get("depth", 1.2), item.get("level", -0.4), bank, bounds.grow(half + bank), 0.0, int(item.get("id", 0))])


## The water cut into the ground, once it has been made: for each, `id` (the
## item it came from), `level` (how high its surface is, in this node's own
## space), `depth`, `rect` (the ground it lies in), `points` and `half` (its
## line, and how far it reaches each side of it).
func waters() -> Array:
	var all: Array = []
	for carve: Array in _carves:
		all.append({"id": carve[7], "level": carve[6], "depth": carve[2], "rect": (carve[5] as Rect2).grow(-carve[4]), "points": carve[0], "half": carve[1]})
	return all


# What a pond or a river makes of the ground at a place: its bed, a dish
# under the water; and beside it the bank, which comes up from the water's
# edge to the ground as it was.
func _carved(height: float, carve: Array, x: float, z: float) -> float:
	var points: PackedVector2Array = carve[0]
	var at := Vector2(x, z)
	var away := at.distance_to(points[0])
	for i in points.size() - 1:
		away = minf(away, at.distance_to(Geometry2D.get_closest_point_to_segment(at, points[i], points[i + 1])))
	var half: float = carve[1]
	if away >= half + carve[4]:
		return height
	if away < half:
		return carve[6] - carve[2] * (1.0 - away * away / (half * half))
	return lerpf(carve[6], height, smoothstep(0.0, carve[4], away - half))


## Tells the ground where its pads are without it being in a scene: each is
## [the pad's transform, half size, round, ease]. For tools that lay a level out.
func use_pads(pads: Array) -> void:
	_given = true
	_grid_side = 0
	_pads.clear()
	for pad: Array in pads:
		var place: Transform3D = pad[0]
		_pads.append([place.affine_inverse(), pad[1], pad[2], pad[3], place.origin.y])


# The dunes: a fixed scatter of them for this `seed`, less any that would
# stand on a pad (so that moving a pad moves no dune, only removes or brings
# back those near it).
func _make_dunes() -> void:
	var all := SandDunes.new()
	all.wind = wind
	all.seed = seed
	all.sharp = sharp
	all.long_backs = dunes != SandDunes.Field.SCATTERED
	all.soft_below = cell * 1.3 if dunes != SandDunes.Field.SCATTERED else 0.0
	var scale := dune_height / 4.5
	var reach := size * 0.5 - KEEP_IN
	var pads := _pads
	var carves := _carves
	var clear := _clear
	if dunes != SandDunes.Field.SCATTERED:
		# A field of them, in rows across the wind. Where one would stand on ground
		# that has to stay clear it runs out to nothing, and the rest of it stays.
		if scatter > 0.0 and dune_height > 0.0:
			all.field(Rect2(-reach, -reach, reach * 2.0, reach * 2.0), dunes, Vector2(3.6, 6.2) * scale, flat, scatter)
		var blows := all.wind
		var claimed := _claimed()
		var across := CLAIM_SIDE
		var square := size / across
		var edge := size * 0.5
		_dunes = all.lowered(func(point: Vector2, back: float, front: float) -> float:
			var most := 0.0
			var from := point - blows * back * 0.3
			var to := point + blows * front
			for part in 5:
				var at := from.lerp(to, part / 4.0)
				var column := clampi(int((at.x + edge) / square), 0, across - 1)
				var row := clampi(int((at.y + edge) / square), 0, across - 1)
				most = maxf(most, claimed[row * across + column])
			return 1.0 - most)
		_add_extra()
		_dunes.wrap(Rect2(-edge, -edge, size, size))
		return
	var count := int(size * size / 5200.0 * scatter)
	if count > 0:
		all.scatter(Rect2(-reach, -reach, reach * 2.0, reach * 2.0), count, Vector2(2.2, 7.5) * scale, Callable(), 0.25)
	_dunes = all.without(func(bounds: Rect2) -> bool:
		# (nor on rock)
		for zone: Array in clear:
			if bounds.grow(zone[1] - minf(bounds.size.x, bounds.size.y) * 0.22).has_point(zone[0]):
				return true
		for pad: Array in pads:
			var middle: Vector3 = (pad[0] as Transform3D).affine_inverse().origin
			var room: float = (pad[1] as Vector2).length() + pad[3] * 0.5
			if bounds.grow(room - minf(bounds.size.x, bounds.size.y) * 0.22).has_point(Vector2(middle.x, middle.z)):
				return true
		# (nor on a pond)
		for carve: Array in carves:
			if (carve[0] as PackedVector2Array).size() == 1 and bounds.grow(carve[1] - minf(bounds.size.x, bounds.size.y) * 0.22).has_point(carve[0][0]):
				return true
		return false)
	_add_extra()
	_dunes.wrap(Rect2(-size * 0.5, -size * 0.5, size, size))


# How much of the ground is spoken for, 0..1, over a coarse grid of the whole
# of it: 1 on a pad, a pond or rock, falling to nothing a little way off.
# Dunes of a field run out to nothing where it is 1.
func _claimed() -> PackedFloat32Array:
	var claimed := PackedFloat32Array()
	claimed.resize(CLAIM_SIDE * CLAIM_SIDE)
	var square := size / CLAIM_SIDE
	var edge := size * 0.5
	# Each: [middle, how far round it is spoken for, the pad if it is one]
	var zones: Array = []
	for pad: Array in _pads:
		var middle: Vector3 = (pad[0] as Transform3D).affine_inverse().origin
		zones.append([Vector2(middle.x, middle.z), (pad[1] as Vector2).length() + pad[3] * 0.4, pad])
	for carve: Array in _carves:
		for point: Vector2 in carve[0]:
			zones.append([point, carve[1] + carve[4], null])
	for zone: Array in _clear + _stand:
		zones.append([zone[0], zone[1], null])
	for zone: Array in zones:
		var middle: Vector2 = zone[0]
		var reach: float = zone[1] + CLAIM_FADE
		for row in range(maxi(int((middle.y - reach + edge) / square), 0), mini(int((middle.y + reach + edge) / square) + 1, CLAIM_SIDE)):
			for column in range(maxi(int((middle.x - reach + edge) / square), 0), mini(int((middle.x + reach + edge) / square) + 1, CLAIM_SIDE)):
				var x := (column + 0.5) * square - edge
				var z := (row + 0.5) * square - edge
				var off: float
				if zone[2] != null:
					off = _away(zone[2], x, z) - (zone[2] as Array)[3] * 0.4
				else:
					off = Vector2(x, z).distance_to(middle) - zone[1]
				var share := 1.0 - smoothstep(0.0, CLAIM_FADE, off)
				if share > claimed[row * CLAIM_SIDE + column]:
					claimed[row * CLAIM_SIDE + column] = share
	return claimed


# Those placed by hand stand wherever they were put.
func _add_extra() -> void:
	for dune: Array in _extra:
		match dune[0]:
			"dune":
				_dunes.add_barchan(dune[1], dune[2], dune[3], dune[4])
			"star":
				_dunes.add_star(dune[1], dune[2] * 0.5, dune[3], dune[4], dune[5])
			"linked":
				_dunes.add_barchanoid(dune[1], dune[2], dune[3], 0.4, dune[4])
			_:
				_dunes.add_ridge(dune[1], dune[2], dune[3], 0.05, int(absf(dune[1].x * 3.0 + dune[1].y)))


# The open sand, before any pad. (The roll of the floor between the dunes dies
# away towards the edge of the square, so that the square meets itself there.)
func _open_at(x: float, z: float) -> float:
	return dunes_at(x, z) - _dunes.floor_at(x, z) * (1.0 - _inside(x, z))


# How far inside the edge of the square a place is: nothing at the edge (and
# for two squares of the grid in from it), 1 from `JOIN` metres in.
func _inside(x: float, z: float) -> float:
	return smoothstep(cell * 2.0, JOIN, size * 0.5 - maxf(absf(x), absf(z)))


# How far outside a pad a place is.
func _away(pad: Array, x: float, z: float) -> float:
	var local: Vector3 = (pad[0] as Transform3D) * Vector3(x, 0.0, z)
	var half: Vector2 = pad[1]
	if pad[2]:
		return maxf(Vector2(local.x / half.x, local.z / half.y).length() - 1.0, 0.0) * minf(half.x, half.y)
	return Vector2(maxf(absf(local.x) - half.x, 0.0), maxf(absf(local.z) - half.y, 0.0)).length()


func _pressed(height: float, pad: Array, x: float, z: float) -> float:
	var away := _away(pad, x, z)
	if away >= pad[3]:
		return height
	return lerpf(pad[4], height, smoothstep(0.0, pad[3], away))


func _gather_pads() -> void:
	if not is_inside_tree() or _given:
		return
	var found: Array = []
	var scene := get_tree().edited_scene_root if Engine.is_editor_hint() else null
	var here := global_transform.affine_inverse()
	for pad: Node in get_tree().get_nodes_in_group(&"terrain_pads"):
		if scene and pad != scene and not scene.is_ancestor_of(pad):
			continue
		var entry: Array = pad.call(&"entry")
		entry[0] = here * (entry[0] as Transform3D)
		found.append(entry)
	use_pads(found)


# --- Making it ---

## Makes the ground again: mesh and collider.
##
## It is the longest single piece of work in opening the desert, and longer the bigger the desert. With `in_parts`
## (as it is made when the scene opens) and the notebook's page up (see `Loading`), it is made in five parts with a
## frame let go by between them, so that the page is seen to move: `laying` is true meanwhile, and `laid` is sent
## at the end. Any other way it is made all at once, and is there when this returns.
func rebuild(in_parts := false) -> void:
	_wait = -1.0
	laying = in_parts
	var began := Time.get_ticks_usec()
	for old in _made:
		old.queue_free()
	_made.clear()
	ground = null
	_gather_pads()
	_make_dunes()
	var count := maxi(int(size / cell), 2)
	var side := count + 1
	var step := size / count
	var half := size * 0.5
	# Heights: the open sand everywhere, then each pad over the part it reaches.
	# (the dunes all at once, which is much quicker than asking `dunes_at` corner by
	# corner; then the floor between them and the rim, as `_open_at` has them)
	var bare := _dunes.bake(Vector2(-half, -half), step, side, side, false)
	# (it meets itself at its edges, as near as numbers go: now exactly)
	for along in side:
		bare[along * side + side - 1] = bare[along * side]
	for along in side:
		bare[(side - 1) * side + along] = bare[along]
	if dunes != SandDunes.Field.SCATTERED:
		# A field of dunes has every crest, horn and join rounded over, more or less as
		# `sharp` says: nothing in it is a crease, which a grid of squares can only
		# draw as teeth. (Dunes scattered as they were are left as they were.)
		bare = SandDunes.rounded(bare, side, side, 3 if sharp < 0.34 else (2 if sharp < 0.67 else 1), true)
	began += await _breath(in_parts, "Pressing the ground level", 0.16)
	var heights := PackedFloat32Array()
	heights.resize(side * side)
	var sunk := 0.2 * dune_height
	# How far inside the edge each row or column is (`_inside`).
	var inside := PackedFloat32Array()
	inside.resize(side)
	for along in side:
		inside[along] = smoothstep(cell * 2.0, JOIN, half - absf(along * step - half))
	var band := mini(int(JOIN / step) + 1, side)
	for row in side:
		var z := row * step - half
		for column in side:
			var x := column * step - half
			var floor := _dunes.floor_at(x, z)
			if row < band or column < band or row >= side - band or column >= side - band:
				floor *= minf(inside[row], inside[column])
			heights[row * side + column] = bare[row * side + column] + floor - sunk
	# That is the open sand, and what lies past the edge for ever.
	_far = heights.duplicate()
	_clear_tread()
	for pad: Array in _pads:
		var middle: Vector3 = (pad[0] as Transform3D).affine_inverse().origin
		var reach: float = (pad[1] as Vector2).length() + pad[3] + step
		for row in range(maxi(int((middle.z - reach + half) / step), 0), mini(int((middle.z + reach + half) / step) + 2, side)):
			for column in range(maxi(int((middle.x - reach + half) / step), 0), mini(int((middle.x + reach + half) / step) + 2, side)):
				heights[row * side + column] = _pressed(heights[row * side + column], pad, column * step - half, row * step - half)
	# Then the water: each lies as high as the ground at its first point, give or take.
	for carve: Array in _carves:
		var first: Vector2 = carve[0][0]
		carve[6] = _dry_at(first.x, first.y) + carve[3]
		var bounds: Rect2 = carve[5]
		for row in range(maxi(int((bounds.position.y + half) / step), 0), mini(int((bounds.end.y + half) / step) + 2, side)):
			for column in range(maxi(int((bounds.position.x + half) / step), 0), mini(int((bounds.end.x + half) / step) + 2, side)):
				heights[row * side + column] = _carved(heights[row * side + column], carve, column * step - half, row * step - half)
	# And whatever that made of the ground near the edge runs out into the open sand.
	for row in side:
		var whole_row := row < band or row >= side - band
		for column: int in (range(side) if whole_row else range(band) + range(side - band, side)):
			var at := row * side + column
			if heights[at] != _far[at]:
				heights[at] = lerpf(_far[at], heights[at], minf(inside[row], inside[column]))
	_grid = heights
	_grid_side = side
	_grid_step = step
	_splits = SandDunes.splits(heights, side, side) if dunes != SandDunes.Field.SCATTERED else PackedByteArray()
	if Engine.is_editor_hint():
		laying = false
		var material := sand_material()
		for chunk_row in range(0, count, CHUNK):
			for chunk_column in range(0, count, CHUNK):
				_add_chunk(heights, side, step, chunk_column, chunk_row, mini(CHUNK, count - chunk_column), mini(CHUNK, count - chunk_row), material)
		_add_apron(material)
		return
	began += await _breath(in_parts, "Spreading the sand", 0.2)
	# In the game a `SandGround` draws it, from the same heights. (By name, and
	# untyped: it is not a tool script, and this one is.)
	ground = (load("res://scripts/sand_ground.gd") as GDScript).new()
	ground.set(&"half", Vector2(half, half))
	ground.set(&"cell", step)
	ground.set(&"solid", false)
	ground.set(&"far_heights", _far)
	# (dunes this gentle throw no shadows worth what drawing them again costs)
	ground.set(&"casts_shadow", false)
	# (a field of dunes is rounded everywhere, and can be drawn as a curved surface)
	ground.set(&"curved", dunes != SandDunes.Field.SCATTERED)
	ground.set(&"splits", _splits)
	_keep(ground)
	ground.call(&"build", heights)
	began += await _breath(in_parts, "Sweeping between the dunes", 0.23)
	if dunes != SandDunes.Field.SCATTERED:
		# In a field of dunes the flat ground between them is swept bare: harder
		# and paler than the dunes, a little more here and a little less there.
		var packed := PackedByteArray()
		packed.resize(side * side)
		var pale := PackedByteArray()
		pale.resize(side * side)
		for row in side:
			var z := row * step - half
			for column in side:
				var at := row * side + column
				if bare[at] > 0.7:
					continue
				var x := column * step - half
				var more := smoothstep(0.25, 0.75, SandDunes._noise(x / 9.0 + seed, z / 9.0) * 0.25 + SandDunes._noise(x / 47.0, z / 47.0 - seed) * 0.75)
				# (evened out towards the edge, as the floor is, so that the square meets itself)
				if row < band or column < band or row >= side - band or column >= side - band:
					more = lerpf(0.5, more, minf(inside[row], inside[column]))
				var pan := (1.0 - smoothstep(0.05, 0.7, bare[at])) * (0.72 + 0.28 * more)
				packed[at] = int(pan * 80.0)
				pale[at] = int(pan * 190.0)
		ground.call(&"paint_all", Sand.Kind.PACKED, packed)
		ground.call(&"paint_all", Sand.Kind.PALE, pale)
		for at in packed.size():
			packed[at] = packed[at] * 3 / 4
		ground.call(&"paint_all", Sand.Kind.WHITE, packed)
		# (and the same past the edge as within)
		ground.call(&"paint_far")
	# Where a pad is the sand is trodden: harder, and it takes less of a print.
	for pad: Array in _pads:
		var middle: Vector3 = global_transform * (pad[0] as Transform3D).affine_inverse().origin
		var across: Vector2 = pad[1]
		ground.call(&"paint", Sand.Kind.PACKED, Vector2(middle.x, middle.z), minf(across.x, across.y) * 0.8, 0.55, 4.0)
	began += await _breath(in_parts, "Making it firm underfoot", 0.26)
	_add_collider(heights, side, step)
	made_in = (Time.get_ticks_usec() - began) / 1000.0
	if laying:
		laying = false
		laid.emit()


# Between two parts of the work: lets the notebook's page say what is being made and show a frame, if the level is
# being opened behind it (`Loading.stage`: nothing, and no wait, with no page up). Says how long it waited, in
# millionths of a second, which is not time spent making the ground.
func _breath(wanted: bool, words: String, fraction: float) -> int:
	if not wanted or Engine.is_editor_hint():
		return 0
	var from := Time.get_ticks_usec()
	await Loading.stage(words, fraction)
	return Time.get_ticks_usec() - from


func _keep(node: Node) -> void:
	add_child(node, false, Node.INTERNAL_MODE_BACK)
	_made.append(node)


func _add_chunk(heights: PackedFloat32Array, side: int, step: float, first_column: int, first_row: int, columns: int, rows: int, material: Material) -> void:
	var half := size * 0.5
	var middle := Vector3((first_column + columns * 0.5) * step - half, 0.0, (first_row + rows * 0.5) * step - half)
	# Each piece twice: as it is, for near by, and with a quarter as many
	# squares each way, for far off.
	var coarse := FAR_STRIDE if columns % FAR_STRIDE == 0 and rows % FAR_STRIDE == 0 and far_from > 0.0 else 0
	for stride: int in [1, coarse]:
		if stride == 0:
			continue
		var wide := columns / stride + 1
		var deep := rows / stride + 1
		var points := PackedVector3Array()
		var normals := PackedVector3Array()
		var corners := PackedInt32Array()
		for r in deep:
			for c in wide:
				var row := first_row + r * stride
				var column := first_column + c * stride
				points.append(Vector3(column * step - half, heights[row * side + column], row * step - half) - middle)
				var west := heights[row * side + maxi(column - 1, 0)]
				var east := heights[row * side + mini(column + 1, side - 1)]
				var north := heights[maxi(row - 1, 0) * side + column]
				var south := heights[mini(row + 1, side - 1) * side + column]
				normals.append(Vector3(west - east, 2.0 * step, north - south).normalized())
		for r in deep - 1:
			for c in wide - 1:
				var corner := r * wide + c
				corners.append_array([corner, corner + 1, corner + wide + 1, corner, corner + wide + 1, corner + wide])
		if stride > 1:
			# A skirt hanging from its edge, to cover where it does not quite
			# meet the finer piece next to it.
			var edge: Array[int] = []
			for c in wide:
				edge.append(c)
			for r in range(1, deep):
				edge.append(r * wide + wide - 1)
			for c in range(wide - 2, -1, -1):
				edge.append((deep - 1) * wide + c)
			for r in range(deep - 2, 0, -1):
				edge.append(r * wide)
			var first := points.size()
			for index in edge:
				points.append(points[index] + Vector3.DOWN * FAR_SKIRT)
				normals.append(normals[index])
			for i in edge.size():
				var next := (i + 1) % edge.size()
				corners.append_array([edge[i], first + i, first + next, edge[i], first + next, edge[next]])
		var arrays := []
		arrays.resize(Mesh.ARRAY_MAX)
		arrays[Mesh.ARRAY_VERTEX] = points
		arrays[Mesh.ARRAY_NORMAL] = normals
		arrays[Mesh.ARRAY_INDEX] = corners
		var mesh := ArrayMesh.new()
		mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
		mesh.surface_set_material(0, material)
		var visual := MeshInstance3D.new()
		visual.mesh = mesh
		visual.position = middle
		# (dunes this gentle throw no shadows worth what drawing them twice costs)
		visual.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		if coarse > 0:
			if stride == 1:
				visual.visibility_range_end = far_from
				visual.visibility_range_end_margin = FAR_MARGIN
			else:
				visual.visibility_range_begin = far_from
				visual.visibility_range_begin_margin = FAR_MARGIN
		_keep(visual)


# In the editor, where the dunes past the edge are not drawn: level ground from
# the edge to the horizon, so that the level does not end in air.
func _add_apron(material: Material) -> void:
	var half := size * 0.5
	var far := 2500.0
	var rim_height := -0.2 * dune_height
	for strip: Array in [
		[Vector2(0.0, (half + far) * 0.5), Vector2(far * 2.0, far - half)], [Vector2(0.0, -(half + far) * 0.5), Vector2(far * 2.0, far - half)],
		[Vector2((half + far) * 0.5, 0.0), Vector2(far - half, size)], [Vector2(-(half + far) * 0.5, 0.0), Vector2(far - half, size)],
	]:
		var plane := PlaneMesh.new()
		plane.size = strip[1]
		plane.material = material
		var visual := MeshInstance3D.new()
		visual.mesh = plane
		visual.position = Vector3(strip[0].x, rim_height, strip[0].y)
		_keep(visual)


func _add_collider(heights: PackedFloat32Array, side: int, step: float) -> void:
	var half := size * 0.5
	var faces := PackedVector3Array()
	faces.resize((side - 1) * (side - 1) * 6)
	var next := 0
	for row in side - 1:
		for column in side - 1:
			var a := Vector3(column * step - half, heights[row * side + column], row * step - half)
			var b := Vector3(a.x + step, heights[row * side + column + 1], a.z)
			var c := Vector3(a.x + step, heights[(row + 1) * side + column + 1], a.z + step)
			var d := Vector3(a.x, heights[(row + 1) * side + column], a.z + step)
			# (split as `height_at` has it)
			var turned := _splits.size() > 0 and _splits[row * (side - 1) + column] == 1
			faces[next] = a
			faces[next + 1] = b
			faces[next + 2] = d if turned else c
			faces[next + 3] = b if turned else a
			faces[next + 4] = c
			faces[next + 5] = d
			next += 6
	var shape := ConcavePolygonShape3D.new()
	shape.set_faces(faces)
	var collider := CollisionShape3D.new()
	collider.shape = shape
	_keep(collider)


# --- Past the edge ---

# Makes the ground past the edge solid round whoever is out there, or near it:
# the boy, and whatever has come after him. It is cut into pieces `TREAD`
# squares a side; those within `TREAD_REACH` pieces of him are solid, and the
# rest are let go. One piece is made in a frame, the nearest first (a few
# thousandths of a second: `tread_ms`), and since the sand out there is one
# square over and over, a piece's shape is made once and used wherever that
# part of the square comes round again.
func _tread() -> void:
	if _far.is_empty() or laying or not is_inside_tree():
		return
	var piece := TREAD * _grid_step
	var half := size * 0.5
	# (how many pieces across the square: the last may be a narrow one)
	var across := ceili((_grid_side - 1) / float(TREAD))
	var here := global_transform.affine_inverse()
	var wanted := {}
	var nearest := Vector2i.ZERO
	var nearest_far := INF
	for body: Node in get_tree().get_nodes_in_group(&"figures") + get_tree().get_nodes_in_group(&"hounds"):
		if not body is Node3D:
			continue
		var at := here * (body as Node3D).global_position
		if maxf(absf(at.x), absf(at.z)) < half - piece * (TREAD_REACH + 1):
			continue
		# (which square of the sea he is in, and which piece of it)
		var square := Vector2i(floori((at.x + half) / size), floori((at.z + half) / size))
		var within := Vector2(at.x + half, at.z + half) - Vector2(square) * size
		var middle := square * across + Vector2i(mini(int(within.x / piece), across - 1), mini(int(within.y / piece), across - 1))
		for down in range(-TREAD_REACH, TREAD_REACH + 1):
			for along in range(-TREAD_REACH, TREAD_REACH + 1):
				var which := middle + Vector2i(along, down)
				# (not the level's own square, which is solid already)
				if which.x >= 0 and which.y >= 0 and which.x < across and which.y < across:
					continue
				wanted[which] = true
				var far := (_tread_corner(which, across) + Vector2(piece, piece) * 0.5).distance_to(Vector2(at.x, at.z))
				if not _trodden.has(which) and far < nearest_far:
					nearest_far = far
					nearest = which
	for which: Vector2i in _trodden.keys():
		if not wanted.has(which):
			(_trodden[which] as Node).queue_free()
			_trodden.erase(which)
	if nearest_far == INF:
		return
	var began := Time.get_ticks_usec()
	var part := Vector2i(posmod(nearest.x, across), posmod(nearest.y, across))
	if not _tread_shapes.has(part):
		var side := _grid_side
		var step := _grid_step
		var faces := PackedVector3Array()
		faces.resize(TREAD * TREAD * 6)
		var next := 0
		for r in TREAD:
			var row := part.y * TREAD + r
			for c in TREAD:
				var column := part.x * TREAD + c
				if row >= side - 1 or column >= side - 1:
					continue
				var a := Vector3(c * step, _far[row * side + column], r * step)
				var b := Vector3(a.x + step, _far[row * side + column + 1], a.z)
				var d := Vector3(a.x + step, _far[(row + 1) * side + column + 1], a.z + step)
				var e := Vector3(a.x, _far[(row + 1) * side + column], a.z + step)
				# (split as `height_at` has it)
				var turned := _splits.size() > 0 and _splits[row * (side - 1) + column] == 1
				faces[next] = a
				faces[next + 1] = b
				faces[next + 2] = e if turned else d
				faces[next + 3] = b if turned else a
				faces[next + 4] = d
				faces[next + 5] = e
				next += 6
		faces.resize(next)
		var shape := ConcavePolygonShape3D.new()
		shape.set_faces(faces)
		_tread_shapes[part] = shape
		tread_ms = (Time.get_ticks_usec() - began) / 1000.0
	var collider := CollisionShape3D.new()
	collider.shape = _tread_shapes[part]
	var corner := _tread_corner(nearest, across)
	collider.position = Vector3(corner.x, 0.0, corner.y)
	add_child(collider, false, Node.INTERNAL_MODE_BACK)
	_trodden[nearest] = collider


# Where the first corner of a piece of the ground past the edge is.
func _tread_corner(which: Vector2i, across: int) -> Vector2:
	var part := Vector2i(posmod(which.x, across), posmod(which.y, across))
	@warning_ignore("integer_division")
	var square := (which - part) / across
	return Vector2(square) * size + Vector2(part) * TREAD * _grid_step - Vector2(size, size) * 0.5


func _clear_tread() -> void:
	for which: Vector2i in _trodden:
		(_trodden[which] as Node).queue_free()
	_trodden.clear()
	_tread_shapes.clear()
