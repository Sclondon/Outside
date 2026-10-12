class_name TempleParts
extends RefCounted
## What a `Temple` is put together with. There are two sorts of thing in a
## temple, and this keeps both as it is set out.
##
## Its PARTS are models, made in Blender (`tools/build_temple.py` builds them,
## `tools/temple.blend` holds them to be looked at and changed, and they come to
## the game as `models/temple/temple.glb`): each kind of column, the beam and
## the roof slab, the towers and the gateway of the pylon, the cornice, the
## screen wall, the naos, the obelisk, the kings and the falcon, the mosque.
## `place` stands one somewhere, turned and stretched as wanted; `fit`
## stretches one to a size. All that are placed of one kind are drawn together
## (`Temple` makes a MultiMesh of each).
##
## Its plain WALLS and FLOORS are built here from numbers: `box`, `wall` (which
## has doorways, and comes down in ruin), `quad`. So are light (`light`) and
## sand (`sand`, `drift`).
##
## And what is SOLID is kept here as a list of boxes, cylinders and hulls,
## never as triangles, so it can be trusted: there are no thin faces to slip
## through. A model's solid shape is worked out from how big the model is
## (`SOLID`), so one that is changed in Blender is still solid where it is seen.
##
## Everything is in the temple's own space as it is set out: X across it, Y up
## from its floor, Z along its axis, the front towards +Z. `shift` is added to
## all of it as it is kept.

## The capitals a column can have: the closed papyrus bud on a bundle of stems
## (the courts of Luxor), the open papyrus or bell (Luxor's great colonnade),
## the composite of leaves and flowers (Edfu, Kom Ombo), and Hathor's head.
enum Capital { BUD, OPEN, COMPOSITE, HATHOR }

const S := preload("res://scripts/temple_stone.gd")
const MODELS := "res://models/temple/temple.glb"
## The models of the columns, by capital. Each is 10 m high with a shaft 1 m in
## radius, on a base `COLUMN_FOOT` high and 1.3 m in radius.
const COLUMNS: Array[String] = ["column_bud", "column_open", "column_composite", "column_hathor"]
const COLUMN_HEIGHT := 10.0
const COLUMN_FOOT := 0.3
## The tower of a pylon as it is modelled (`TOWER` in tools/build_temple.py):
## how wide, high (to the foot of its cornice) and deep, and how far its inner
## side, its outer side and its front and back lean in at the top. These say
## what is solid of it; if the model's shape is changed, change them to match.
const TOWER := Vector3(34.0, 36.0, 11.0)
const TOWER_LEAN := Vector3(1.0, 3.0, 3.0)
const TOWER_CORNICE := 1.9
## Where the slots for its flagstaffs are, across it (the great figures are cut between them).
const TOWER_NICHES := Vector2(0.30, 0.74)
## How high each sixth of a ruined tower stands, as a share of its highest (`tower_ruin` in the same).
const TOWER_RUIN: Array[float] = [1.0, 0.72, 0.86, 0.55, 0.78, 0.6]
## The gateway as it is modelled: its opening's width and height, and the whole's width, height and depth; and how high its cornice is.
const GATE_OPEN := Vector2(5.6, 15.4)
const GATE := Vector3(9.0, 22.0, 11.0)
const GATE_CORNICE := 2.2
## What is solid of each model that is not simply all of the box it fills:
## boxes, as shares of that box (from its low corner to its high one).
const SOLID := {
	"colossus_seated": [[0.0, 0.0, 0.0, 1.0, 0.08, 1.0], [0.0, 0.08, 0.0, 1.0, 0.44, 0.81], [0.0, 0.44, 0.0, 1.0, 0.72, 0.47]],
	"colossus_standing": [[0.0, 0.0, 0.0, 1.0, 0.74, 1.0]],
	"falcon": [[0.0, 0.0, 0.0, 1.0, 0.76, 1.0]],
	"obelisk": [[0.0, 0.0, 0.0, 1.0, 0.07, 1.0], [0.18, 0.07, 0.18, 0.82, 0.97, 0.82]],
	"naos": [[0.0, 0.0, 0.0, 1.0, 0.82, 1.0]],
	"mosque": [[0.0, 0.0, 0.0, 1.0, 0.58, 1.0]],
	"screen_wall": [[0.0, 0.0, 0.19, 1.0, 0.95, 0.81]],
}

## Added to every point as it is kept.
var shift := Vector3.ZERO
## What is solid: [shape, where], in the temple's space.
var solids: Array = []
## What stands on the floor, as rectangles of it (x, z): for keeping fallen stone clear of.
var standing: Array[Rect2] = []
## The models placed: for each kind (and, of columns, each part of the temple),
## {"model", "far" (a coarser model for far off, or ""), "at" (transforms), "shade"}.
var placed := {}

var points := PackedVector3Array()
var normals := PackedVector3Array()
var colours := PackedColorArray()
var uvs := PackedVector2Array()
var sand_points := PackedVector3Array()
var sand_normals := PackedVector3Array()
var beam_points := PackedVector3Array()
var beam_colours := PackedColorArray()
var beam_uvs := PackedVector2Array()

static var _meshes := {}
static var _bounds := {}


## The colour of a corner: how light, how dressed, which paint, and of what (see `TempleStone`).
static func tint(shade := 1.0, dress := S.COURSED, paint := 0, what := S.SANDSTONE) -> Color:
	return Color(shade, dress, paint / 8.0, what)


# ---- The models. ----

## What a material's name says a face is, as the colour `TempleStone` reads
## (tools/build_temple.py says how the names are made up).
static func read(material: String) -> Color:
	var words := material.split("_")
	var what: float = {"stone": S.SANDSTONE, "redgranite": S.RED_GRANITE, "greygranite": S.GREY_GRANITE, "whitewash": S.WHITEWASH, "dark": S.DARK}.get(words[0], S.SANDSTONE)
	var dress := S.SMOOTH
	var shade := 1.0
	var paint := 0
	if "coursed" in words:
		dress = S.COURSED
	if "relief" in words:
		dress = S.RELIEF
	if "shaded" in words:
		dress = S.COURSED if what == S.SANDSTONE else S.SMOOTH
		shade = 0.45
	var at := words.find("painted")
	if at >= 0 and at + 1 < words.size():
		paint = ["none", "red", "blue", "green", "yellow", "white", "black", "stripes"].find(words[at + 1])
	return tint(shade, dress, maxi(paint, 0), what)


# Reads every model out of the file, once: each as one mesh of one surface,
# with what its materials said written into the colour of its corners, and
# with where on the stone each corner is worked out from its place.
static func _load() -> void:
	if not _meshes.is_empty():
		return
	var scene := (load(MODELS) as PackedScene).instantiate()
	for found: Node in scene.find_children("*", "MeshInstance3D", true, false):
		var from := (found as MeshInstance3D).mesh
		var round := String(found.name).begins_with("column")
		var vertices := PackedVector3Array()
		var facing := PackedVector3Array()
		var tints := PackedColorArray()
		var places := PackedVector2Array()
		for surface in from.get_surface_count():
			var arrays := from.surface_get_arrays(surface)
			var own: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
			var own_normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
			var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX] if arrays[Mesh.ARRAY_INDEX] != null else PackedInt32Array(range(own.size()))
			var material := from.surface_get_material(surface)
			var colour := read(material.resource_name if material else "stone")
			for t in range(0, indices.size(), 3):
				var a := own[indices[t]]
				var b := own[indices[t + 1]]
				var c := own[indices[t + 2]]
				var flat := (c - a).cross(b - a).normalized()
				var level := absf(flat.y) > 0.9
				var across := Vector3.RIGHT if level else Vector3(flat.z, 0.0, -flat.x).normalized()
				# (round a column the faces follow on from each other, so that what is carved on it goes round it unbroken)
				var turn := 0.0
				if round and not level:
					var middle := (a + b + c) / 3.0
					turn = atan2(flat.x, flat.z) * Vector2(middle.x, middle.z).length()
				for k in 3:
					var point := own[indices[t + k]]
					vertices.append(point)
					facing.append(own_normals[indices[t + k]])
					tints.append(colour)
					places.append(Vector2(point.x, point.z) if level else Vector2(point.dot(across) + turn, point.y))
		var arrays := []
		arrays.resize(Mesh.ARRAY_MAX)
		arrays[Mesh.ARRAY_VERTEX] = vertices
		arrays[Mesh.ARRAY_NORMAL] = facing
		arrays[Mesh.ARRAY_COLOR] = tints
		arrays[Mesh.ARRAY_TEX_UV] = places
		var made := ArrayMesh.new()
		made.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
		_meshes[String(found.name)] = made
		_bounds[String(found.name)] = made.get_aabb()
	scene.free()


## The mesh of a model, by the name of its object in the Blender file.
static func model(named: String) -> ArrayMesh:
	_load()
	return _meshes.get(named)


## The box a model fills, as it was made.
static func bounds(named: String) -> AABB:
	_load()
	return _bounds.get(named, AABB(Vector3(-0.5, 0.0, -0.5), Vector3.ONE))


## Stands a model somewhere. `group` keeps it apart from others of its kind, to
## be drawn (and left out when far off) by itself; `far` is a coarser model to
## draw in its place from far off. `is_solid`: solid, as `SOLID` says.
func place(named: String, where: Transform3D, shade := 1.0, is_solid := true, group := "", far := "") -> void:
	var key := named + "|" + group
	if not placed.has(key):
		placed[key] = {"model": named, "far": far, "at": [], "shade": []}
	placed[key]["at"].append(where)
	placed[key]["shade"].append(shade)
	if not is_solid:
		return
	var box := bounds(named)
	for part: Array in SOLID.get(named, [[0.0, 0.0, 0.0, 1.0, 1.0, 1.0]]):
		var low := box.position + box.size * Vector3(part[0], part[1], part[2])
		var high := box.position + box.size * Vector3(part[3], part[4], part[5])
		var size := where.basis.get_scale()
		var shape := BoxShape3D.new()
		shape.size = (high - low) * size
		var middle := where * ((low + high) * 0.5)
		solid(shape, Transform3D(where.basis.orthonormalized(), middle))
		if middle.y - shape.size.y * 0.5 < 0.6:
			var reach := Vector2(shape.size.x, shape.size.z).length() * 0.5 if absf(where.basis.x.z) > 0.01 else 0.0
			var half := Vector2(maxf(shape.size.x * 0.5, reach), maxf(shape.size.z * 0.5, reach))
			standing.append(Rect2(middle.x - half.x, middle.z - half.y, half.x * 2.0, half.y * 2.0))


## Stands a model with its foot at `at`, stretched to be `size` in all (a part
## of `size` that is 0 is stretched as its height is), and turned `yaw` about.
func fit(named: String, at: Vector3, size: Vector3, shade := 1.0, is_solid := true, yaw := 0.0) -> void:
	var box := bounds(named)
	var by := Vector3(size.x / box.size.x, size.y / box.size.y, size.z / box.size.z)
	if size.x <= 0.0:
		by.x = by.y
	if size.z <= 0.0:
		by.z = by.y
	place(named, Transform3D(Basis(Vector3.UP, yaw) * Basis.from_scale(by), at), shade, is_solid)


## The cornice of every Egyptian wall, round the top of the rectangle `around`
## (x, z) from `y` up `height`: four lengths of it and four corners. It stands
## up from the edge like a low wall, and its top can be stood on.
func cornice(around: Rect2, y: float, height: float, shade := 1.0) -> void:
	var x0 := around.position.x
	var x1 := around.end.x
	var z0 := around.position.y
	var z1 := around.end.y
	var by := Vector3(height, height, height)
	# [the middle of the side, how long it is, which way it faces]
	for side: Array in [[Vector3((x0 + x1) * 0.5, y, z1), x1 - x0, 0.0], [Vector3(x1, y, (z0 + z1) * 0.5), z1 - z0, PI * 0.5],
			[Vector3((x0 + x1) * 0.5, y, z0), x1 - x0, PI], [Vector3(x0, y, (z0 + z1) * 0.5), z1 - z0, -PI * 0.5]]:
		place("cornice", Transform3D(Basis(Vector3.UP, side[2]) * Basis.from_scale(Vector3(side[1], height, height)), side[0]), shade, false)
	for at: Array in [[Vector3(x1, y, z1), 0.0], [Vector3(x1, y, z0), PI * 0.5], [Vector3(x0, y, z0), PI], [Vector3(x0, y, z1), -PI * 0.5]]:
		place("cornice_corner", Transform3D(Basis(Vector3.UP, at[1]) * Basis.from_scale(by), at[0]), shade, false)
	var inside := height * 0.4
	var out := height * 0.2
	solid_box(Vector3(x0 - out, y, z1 - inside), Vector3(x1 + out, y + height, z1 + out))
	solid_box(Vector3(x0 - out, y, z0 - out), Vector3(x1 + out, y + height, z0 + inside))
	solid_box(Vector3(x0 - out, y, z0 + inside), Vector3(x0 + inside, y + height, z1 - inside))
	solid_box(Vector3(x1 - inside, y, z0 + inside), Vector3(x1 + out, y + height, z1 - inside))


# ---- Plain faces. ----

func corner(point: Vector3, normal: Vector3, colour: Color, uv: Vector2) -> void:
	points.append(point + shift)
	normals.append(normal)
	colours.append(colour)
	uvs.append(uv)


## A flat face with three corners, seen from the side `out` points to.
func tri(a: Vector3, b: Vector3, c: Vector3, out: Vector3, colour: Color) -> void:
	var normal := (b - a).cross(c - a)
	if normal.dot(out) < 0.0:
		var swapped := b
		b = c
		c = swapped
		normal = -normal
	normal = normal.normalized()
	# Across the face and up it, in metres (or, on top, across and along).
	var level := absf(normal.y) > 0.9
	var across := Vector3.RIGHT if level else Vector3(normal.z, 0.0, -normal.x).normalized()
	for point: Vector3 in [a, c, b]:
		corner(point, normal, colour, Vector2(point.x, point.z) if level else Vector2(point.dot(across), point.y))


func quad(a: Vector3, b: Vector3, c: Vector3, d: Vector3, out: Vector3, colour: Color) -> void:
	tri(a, b, c, out, colour)
	tri(a, c, d, out, colour)


func solid(shape: Shape3D, at: Transform3D) -> void:
	solids.append([shape, Transform3D(at.basis, at.origin + shift)])


func solid_box(low: Vector3, high: Vector3) -> void:
	var shape := BoxShape3D.new()
	shape.size = high - low
	solid(shape, Transform3D(Basis.IDENTITY, (low + high) * 0.5))
	if low.y < 0.6:
		standing.append(Rect2(low.x, low.z, high.x - low.x, high.z - low.z))


## A cylinder standing on `foot`, solid.
func solid_cylinder(foot: Vector3, radius: float, height: float) -> void:
	var shape := CylinderShape3D.new()
	shape.radius = radius
	shape.height = height
	solid(shape, Transform3D(Basis.IDENTITY, foot + Vector3.UP * height * 0.5))
	if foot.y < 0.6:
		standing.append(Rect2(foot.x - radius, foot.z - radius, radius * 2.0, radius * 2.0))


## A hull round some points, solid.
func solid_hull(corners: PackedVector3Array) -> void:
	var hull := ConvexPolygonShape3D.new()
	hull.points = corners
	solid(hull, Transform3D.IDENTITY)


## A box. `colours_in` is one colour for all of it, or six: the faces towards +X,
## -X, +Z, -Z, the top, and the underside (which is drawn only if it is given).
func box(low: Vector3, high: Vector3, colours_in: Variant, is_solid := true) -> void:
	if high.x - low.x < 0.001 or high.y - low.y < 0.001 or high.z - low.z < 0.001:
		return
	var faces: Array = colours_in if colours_in is Array else [colours_in, colours_in, colours_in, colours_in, colours_in]
	var a := Vector3(low.x, low.y, low.z)
	var b := Vector3(high.x, low.y, low.z)
	var c := Vector3(high.x, low.y, high.z)
	var d := Vector3(low.x, low.y, high.z)
	var up := Vector3(0.0, high.y - low.y, 0.0)
	quad(c, b, b + up, c + up, Vector3.RIGHT, faces[0])
	quad(a, d, d + up, a + up, Vector3.LEFT, faces[1])
	quad(d, c, c + up, d + up, Vector3.BACK, faces[2])
	quad(b, a, a + up, b + up, Vector3.FORWARD, faces[3])
	quad(a + up, b + up, c + up, d + up, Vector3.UP, faces[4])
	if faces.size() > 5:
		quad(a, b, c, d, Vector3.DOWN, faces[5])
	if is_solid:
		solid_box(low, high)


## A block lying anyhow: `where` is its middle and which way it is turned. Solid as a box.
func block(where: Transform3D, size: Vector3, colour: Color) -> void:
	var half := size * 0.5
	for face: Array in [[Vector3.RIGHT, Vector3.UP, Vector3.BACK], [Vector3.LEFT, Vector3.UP, Vector3.FORWARD], [Vector3.BACK, Vector3.UP, Vector3.LEFT],
			[Vector3.FORWARD, Vector3.UP, Vector3.RIGHT], [Vector3.UP, Vector3.RIGHT, Vector3.FORWARD]]:
		var out: Vector3 = face[0] * half
		var one: Vector3 = face[1] * half
		var two: Vector3 = face[2] * half
		quad(where * (out - one - two), where * (out - one + two), where * (out + one + two), where * (out + one - two), where.basis * face[0], colour)
	var shape := BoxShape3D.new()
	shape.size = size
	solid(shape, where)
	var reach := maxf(size.x, size.z) * 0.75
	standing.append(Rect2(where.origin.x - reach, where.origin.z - reach, reach * 2.0, reach * 2.0))


## A wall with doorways in it. It runs from `from` to `to` along X (or along Z
## if not `along_x`) and is as thick as from `near` to `far` the other way, and
## `height` high. `options`:
##     doors      a list of [where along it, how wide, how high]
##     front      the colour of its face towards + (Z, or X), and `back` of the other
##     standing   how much of its height was ever built or is left, 0..1 (1)
##     ruin       how ruined, 0..1 (0), with `random` to say where
##     course     how high a course of its blocks is (0.9)
## A ruined wall is down to different heights along its length, a whole number
## of courses each; the lintel of a doorway goes when the wall beside it has.
func wall(from: float, to: float, near: float, far: float, height: float, along_x: bool, options := {}) -> void:
	var front: Color = options.get("front", tint())
	var back: Color = options.get("back", front)
	var whole: float = options.get("standing", 1.0)
	var ruin: float = options.get("ruin", 0.0)
	var course: float = options.get("course", 0.9)
	var random: RandomNumberGenerator = options.get("random")
	var doors: Array = options.get("doors", []).duplicate()
	doors.sort_custom(func(a: Array, b: Array) -> bool: return a[0] < b[0])
	var top := tint(1.0, S.COURSED)
	var under := tint(minf(front.r, back.r) * 0.8, S.COURSED)
	var faces := [front, front, front, back, top, under] if along_x else [front, back, front, front, top, under]
	# The stretches of wall between its doorways, and over each doorway.
	var at := from
	var edges: Array = []
	for door: Array in doors:
		edges.append([at, door[0] - door[1] * 0.5, 0.0])
		edges.append([door[0] - door[1] * 0.5, door[0] + door[1] * 0.5, door[2]])
		at = door[0] + door[1] * 0.5
	edges.append([at, to, 0.0])
	var broken := ruin > 0.04 or whole < 0.999
	var last_height := height
	for edge: Array in edges:
		var long: float = edge[1] - edge[0]
		if long < 0.01:
			continue
		if edge[2] > 0.0:
			# Over a doorway: what is above it, if the wall beside it still stands that high.
			if last_height > edge[2] + course * 0.9 and edge[2] < height - 0.05:
				_wall_box(edge[0], edge[1], near, far, edge[2], minf(last_height, height), along_x, faces, true)
			continue
		var pieces := maxi(ceili(long / (course * 4.5)), 1) if broken else 1
		var run_from: float = edge[0]
		var run_height := -1.0
		for piece in pieces:
			var high := height
			if broken:
				var left := clampf(1.25 - ruin * (0.25 + 1.1 * random.randf()), 0.08, 1.0) if ruin > 0.04 else 1.0
				high = maxf(roundf(height * whole * left / course) * course, course)
				high = minf(high, height)
			if run_height >= 0.0 and absf(high - run_height) > 0.01:
				_wall_box(run_from, edge[0] + long * piece / pieces, near, far, 0.0, run_height, along_x, faces, false)
				run_from = edge[0] + long * piece / pieces
			run_height = high
		_wall_box(run_from, edge[1], near, far, 0.0, run_height, along_x, faces, false)
		last_height = run_height


func _wall_box(from: float, to: float, near: float, far: float, low: float, high: float, along_x: bool, faces: Array, over: bool) -> void:
	var colours_of := faces if over else faces.slice(0, 5)
	if along_x:
		box(Vector3(from, low, near), Vector3(to, high, far), colours_of)
	else:
		box(Vector3(near, low, from), Vector3(far, high, to), colours_of)


## A sheet of light from an opening in a roof (`a` to `b`) down to the floor (`c` to `d`, under `b` and `a`).
func light(a: Vector3, b: Vector3, c: Vector3, d: Vector3, strength := 1.0) -> void:
	var corners := [a, b, c, d]
	var uv := [Vector2(0.0, 0.0), Vector2(1.0, 0.0), Vector2(1.0, 1.0), Vector2(0.0, 1.0)]
	for i: int in [0, 1, 2, 0, 2, 3]:
		beam_points.append(corners[i] + shift)
		beam_colours.append(Color(1.0, 1.0, 1.0, strength))
		beam_uvs.append(uv[i])


## A face of sand with three corners, seen from above.
func sand(a: Vector3, b: Vector3, c: Vector3) -> void:
	var normal := (b - a).cross(c - a)
	if normal.y < 0.0:
		var swapped := b
		b = c
		c = swapped
		normal = -normal
	normal = normal.normalized()
	for point: Vector3 in [a, c, b]:
		sand_points.append(point + shift)
		sand_normals.append(normal)


## A drift of sand: a low heap `radius` across its foot and `height` high in
## the middle, which can be walked over. Solid as a hull.
func drift(at: Vector3, radius: Vector2, height: float) -> void:
	var rim: Array[Vector3] = []
	var crown: Array[Vector3] = []
	for side in 8:
		var angle := TAU * side / 8.0
		rim.append(at + Vector3(cos(angle) * radius.x, -0.05, sin(angle) * radius.y))
		crown.append(at + Vector3(cos(angle) * radius.x * 0.35, height, sin(angle) * radius.y * 0.35))
	var hull := PackedVector3Array()
	for side in 8:
		var next := (side + 1) % 8
		sand(rim[side], rim[next], crown[next])
		sand(rim[side], crown[next], crown[side])
		sand(crown[side], crown[next], at + Vector3.UP * height)
		hull.append(rim[side])
		hull.append(crown[side])
	solid_hull(hull)


## Everything drawn so far that is plain stone, as the arrays of a mesh.
func stone_arrays() -> Array:
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = points
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_COLOR] = colours
	arrays[Mesh.ARRAY_TEX_UV] = uvs
	return arrays
