class_name Pyramid
extends StaticBody3D
## A pyramid, made from a few numbers: its mesh and what is solid are worked out
## here when it enters the level (or when `build` is called), and the same
## numbers always make the same pyramid. Its foot is at the origin and its door,
## if it has one, is in the face towards +Z.
##
## It is built as the real ones were. A core of stone in courses, each a step
## (`rise` high) that he can catch and climb, as Khufu's is now; over that a
## smooth casing, of which `casing` says how much is left, measured down from
## the top: none, a cap of it as on Khafre's, or all of it (a finished pyramid,
## too steep and smooth to climb); and at the very top a capstone, gilded if
## `gold_cap`.
##
## `ruin` takes it apart again, the more the nearer 1: the capstone and the top
## courses go, the top is left ragged with loose blocks lying on it, casing
## falls off in runs, blocks are missing from the faces and others have slipped
## out of place, and corners fall in (one from 0.2, two from 0.5, three from
## 0.75, all four at 0.95: the tower on a heap that is left at Meidum). A fallen
## corner is a bite out of the courses with a slope of rubble and blocks lying
## in it and spilling out past the foot: that slope can be walked up.
##
## What it costs: every course is one box (more where it is broken), drawn and
## solid alike; casing that is whole is four faces and one hull however tall;
## and the rubble, the loose blocks and broken casing are one mesh of triangles
## to collide with. A 60 m pyramid is 20 triangles finished, about 290 stepped,
## and 1500 to 4700 ruined. There is one mesh, of one surface of stone
## (`Sandstone`) and, with a gold cap, one of gold.

## The stone it can be built of (the layout keeps which, by its place here).
const STONES: Array[Color] = [Color(0.66, 0.57, 0.43), Color(0.78, 0.72, 0.6), Color(0.66, 0.44, 0.33), Color(0.4, 0.38, 0.36)]
## How far below its foot it goes on, for ground that is not quite level.
const FOOT := 4.0
const ROOT2 := 1.41421356

## How far across its foot is, in metres.
@export var base := 40.0
## How steep its faces are, in degrees (Khufu's are 52, the Red Pyramid's 43).
@export_range(35.0, 70.0) var slope := 54.0
## How high a course is, in metres: he can catch one of up to 1.6.
@export_range(0.5, 2.0) var rise := 1.35
## How much of the smooth casing is left, down from the top: 0 none, 1 all of it.
@export_range(0.0, 1.0) var casing := 0.0
## A gilded capstone.
@export var gold_cap := false
## How ruined, 0..1.
@export_range(0.0, 1.0) var ruin := 0.0
## Which ruin: another number breaks it differently.
@export var seed := 1
## A way in, in the face towards +Z: a cutting through the bottom courses to a
## doorway, and a short dark passage behind it.
@export var door := false
## The colour of its stone.
@export var colour := STONES[0]

## How high it stands as built, in metres.
var height := 0.0
## How many triangles it is drawn with, and how many shapes it collides with.
var triangles := 0
var shapes := 0
## Which corners have fallen in, each as the signs of its x and z.
var fallen_corners: Array[Vector2] = []

var _half := 0.0
var _tread := 0.0
var _points := PackedVector3Array()
var _normals := PackedVector3Array()
var _colours := PackedColorArray()
var _gold_points := PackedVector3Array()
var _gold_normals := PackedVector3Array()
# Whatever is solid and not a box or a hull, as triangles.
var _loose := PackedVector3Array()


## A pyramid as an item of a level's layout says (see `LevelLayout.FIELDS`).
static func from_item(item: Dictionary) -> Pyramid:
	var made := Pyramid.new()
	made.base = item.get("base", 40.0)
	made.slope = item.get("slope", 54.0)
	made.rise = item.get("rise", 1.35)
	made.casing = item.get("casing", 0.0)
	made.gold_cap = item.get("cap", false)
	made.ruin = item.get("ruin", 0.0)
	made.seed = int(item.get("seed", 1))
	made.door = item.get("door", false)
	made.colour = STONES[clampi(int(item.get("stone", 0)), 0, STONES.size() - 1)]
	return made


func _ready() -> void:
	build()


## Makes it (again) from its numbers.
func build() -> void:
	for child in get_children():
		remove_child(child)
		child.queue_free()
	_points.clear()
	_normals.clear()
	_colours.clear()
	_gold_points.clear()
	_gold_normals.clear()
	_loose.clear()
	fallen_corners.clear()
	shapes = 0
	var random := RandomNumberGenerator.new()
	random.seed = hash([seed, 17])
	_half = maxf(base, 4.0) * 0.5
	_tread = rise / tan(deg_to_rad(clampf(slope, 20.0, 80.0)))
	var apex := _half * rise / _tread
	# How many courses the core has, and the one the capstone stands on.
	var courses := maxi(int(_half / _tread) - 1, 1)
	var cap_from := clampi(ceili((apex - maxf(2.2 * rise, 0.12 * apex)) / rise), 1, courses)
	var whole := cap_from if gold_cap else courses
	# Ruin takes the top off.
	var top := whole
	if ruin > 0.03:
		top = maxi(whole - maxi(1, roundi(whole * 0.55 * pow(ruin, 1.2) * random.randf_range(0.85, 1.1))), mini(2, whole))
	var cut := ruin > 0.03
	var cased_from := roundi(whole * (1.0 - casing)) if casing > 0.0 else whole + 1

	# The way in: how many courses high, how wide, how far it goes.
	var door_courses := ceili(3.3 / rise)
	var has_door := door and top > door_courses + 1 and _half > 6.0
	var door_half := 1.5
	var door_deep := minf(_tread * (door_courses + 1) + 4.0, _half * 0.8)

	# Corners that have fallen in. Each is a square bitten out of every course
	# from some course up; `inner` is how near the middle it reaches at each
	# (never further out than at the course below, so nothing is left hanging).
	var bites: Array = []
	var fallen := 0 if ruin < 0.2 else (1 if ruin < 0.5 else (2 if ruin < 0.75 else (3 if ruin < 0.95 else 4)))
	var corners := [0, 1, 2, 3]
	for i in 3:
		var other := random.randi_range(i, 3)
		var swapped: int = corners[i]
		corners[i] = corners[other]
		corners[other] = swapped
	for b in fallen:
		var from := random.randi_range(0, int(top * 0.25))
		var grow := random.randf_range(0.9, 1.7) * (0.6 + ruin)
		var least := maxf(0.6, 0.45 * _edge(top - 1)) if fallen > 1 else -0.5 * _edge(top - 1)
		var inner := PackedFloat32Array()
		var last := INF
		for i in top:
			if i >= from:
				last = minf(last, _edge(i) - maxf((i - from + 1) * grow * _tread + random.randf_range(-0.6, 0.6) * rise, 0.5))
				last = maxf(last, least)
			inner.append(last)
		bites.append({"x": [1.0, -1.0, -1.0, 1.0][corners[b]], "z": [1.0, 1.0, -1.0, -1.0][corners[b]], "inner": inner})
		fallen_corners.append(Vector2(bites[-1]["x"], bites[-1]["z"]))

	# Blocks gone from the faces, and the ragged top: more holes, by course.
	var holes := {}
	var gone := RandomNumberGenerator.new()
	gone.seed = hash([seed, 29])
	for b in int(ruin * 20.0):
		var i := gone.randi_range(0, top - 1)
		var long := rise * gone.randf_range(1.2, 2.4)
		var reach := _edge(i) - long
		if reach > 0.5:
			var a := gone.randf_range(-reach, reach)
			holes[i] = holes.get(i, []) + [_on_face(gone.randi_range(0, 3), a - long * 0.5, a + long * 0.5, _edge(i) - _tread, _edge(i) + 1.0)]
	if cut and ruin > 0.1:
		for b in 1 + int(ruin * 3.0):
			var h := _edge(top - 1)
			var a := gone.randf_range(-h, h)
			var wide := h * gone.randf_range(0.3, 0.9)
			holes[top - 1] = holes.get(top - 1, []) + [_on_face(gone.randi_range(0, 3), a - wide, a + wide, h * gone.randf_range(0.2, 0.7), h + 1.0)]

	# What is left of each course, as rectangles; which stretches of its four
	# sides are outer face; and what casing lies on them.
	var skin := RandomNumberGenerator.new()
	skin.seed = hash([seed, 43])
	var regions: Array = []
	var faces: Array = []
	var runs: Array = []
	var full: Array[bool] = []
	for i in top:
		var h := _edge(i)
		var square := Rect2(-h, -h, h * 2.0, h * 2.0)
		var rects: Array[Rect2] = [square]
		for bite: Dictionary in bites:
			var inner: float = bite["inner"][i]
			if inner < h - 0.01:
				rects = _minus(rects, Rect2(inner if bite["x"] > 0.0 else -h - 1.0, inner if bite["z"] > 0.0 else -h - 1.0, h + 1.0 - inner, h + 1.0 - inner))
		for hole: Rect2 in holes.get(i, []):
			var less := _minus(rects, hole)
			if not less.is_empty():
				rects = less
		if has_door and i < door_courses:
			rects = _minus(rects, Rect2(-door_half, _half - door_deep, door_half * 2.0, door_deep + 1.0))
		var untouched := rects.size() == 1 and rects[0].is_equal_approx(square)
		var sides: Array = []
		var cased: Array = []
		for f in 4:
			var shown := _outer(rects, f, h)
			var wanted := _casing_wanted(i, h, cased_from, skin)
			untouched = untouched and wanted.size() == 1 and wanted[0][0] <= -h and wanted[0][1] >= h
			sides.append(shown)
			cased.append(_both(wanted, shown))
		regions.append(rects)
		faces.append(sides)
		runs.append(cased)
		full.append(untouched)
	# Casing that is whole all the way up from some course is drawn, and is solid, as one piece.
	var smooth_from := top
	while smooth_from > 0 and full[smooth_from - 1]:
		smooth_from -= 1

	# The courses.
	var core := Color(1.0, 1.0, 1.0)
	for i in smooth_from:
		for rect: Rect2 in regions[i]:
			_box(Vector3(rect.position.x, -FOOT if i == 0 else i * rise, rect.position.y), Vector3(rect.end.x, (i + 1) * rise, rect.end.y), core)
		for f in 4:
			for run: Array in runs[i][f]:
				_wedge(i, f, run[0], run[1])
	# The smooth part, and the capstone.
	var pale := Color(1.0, 1.0, 0.0)
	var low := _ring(smooth_from)
	var high := _ring(top)
	var tip := Vector3(0.0, apex, 0.0)
	var pointed := not cut and (gold_cap or smooth_from < top)
	height = apex if pointed else top * rise
	for f in 4:
		var out := Vector3([1.0, 0.0, -1.0, 0.0][f], 0.5, [0.0, 1.0, 0.0, -1.0][f])
		var g := (f + 3) % 4
		if smooth_from < top:
			_quad(low[g], low[f], high[f], high[g], out, pale)
			if smooth_from == 0:
				_quad(low[g] + Vector3.DOWN * FOOT, low[f] + Vector3.DOWN * FOOT, low[f], low[g], out, pale)
		if pointed and gold_cap:
			_gold_tri(high[g], high[f], tip, out)
		elif pointed:
			_tri(high[g], high[f], tip, out, pale)
	if smooth_from < top and not pointed:
		_quad(high[0], high[1], high[2], high[3], Vector3.UP, core)
	if smooth_from < top or pointed:
		var hull := PackedVector3Array(low)
		if smooth_from == 0:
			for corner: Vector3 in low:
				hull.append(corner + Vector3.DOWN * FOOT)
		if pointed:
			hull.append(tip)
		else:
			hull.append_array(high)
		var shape := ConvexPolygonShape3D.new()
		shape.points = hull
		_solid(shape, Vector3.ZERO)

	# The doorway at the head of the cutting: two jambs and a lintel, the roof of the passage and the dark at its end.
	if has_door:
		var mouth := _edge(door_courses)
		var lintel := door_courses * rise
		for side: float in [-1.0, 1.0]:
			_box(Vector3(minf(side * door_half, side * (door_half - 0.45)), 0.0, mouth - 0.3), Vector3(maxf(side * door_half, side * (door_half - 0.45)), lintel, mouth + 0.45), Color(0.9, 1.0, 1.0))
		_box(Vector3(-door_half - 0.7, lintel, mouth - 0.3), Vector3(door_half + 0.7, lintel + 0.7, mouth + 0.5), Color(1.08, 1.0, 1.0))
		var back := _half - door_deep + 0.03
		var dark := Color(0.06, 0.0, 1.0)
		_quad(Vector3(-door_half, -FOOT, back), Vector3(door_half, -FOOT, back), Vector3(door_half, lintel, back), Vector3(-door_half, lintel, back), Vector3.BACK, dark)
		_quad(Vector3(-door_half, lintel - 0.02, back), Vector3(door_half, lintel - 0.02, back), Vector3(door_half, lintel - 0.02, mouth), Vector3(-door_half, lintel - 0.02, mouth), Vector3.DOWN, Color(0.3, 0.0, 1.0))

	# What has fallen.
	var spill := RandomNumberGenerator.new()
	spill.seed = hash([seed, 59])
	for bite: Dictionary in bites:
		_fan(bite, top, spill)
	# Blocks slipped out of their course onto the step below.
	for b in int(ruin * 24.0):
		var i := spill.randi_range(1, top - 1)
		var f := spill.randi_range(0, 3)
		var long := rise * spill.randf_range(1.1, 1.9)
		var turn := spill.randf_range(-0.4, 0.4)
		var tone := spill.randf_range(0.82, 1.0)
		var stretches: Array = faces[i][f]
		if stretches.is_empty() or not runs[i][f].is_empty() or i >= smooth_from:
			continue
		var stretch: Array = stretches[spill.randi_range(0, stretches.size() - 1)]
		if stretch[1] - stretch[0] < long * 2.0:
			continue
		var a := spill.randf_range(stretch[0] + long, stretch[1] - long)
		var under := false
		for below: Array in faces[i - 1][f]:
			under = under or (below[0] < a - long and below[1] > a + long)
		if not under:
			continue
		var at := _on(f, a, _edge(i) + _tread * 0.6, i * rise + rise * 0.46)
		var facing := Basis(Vector3.UP, [PI * 0.5, 0.0, PI * 0.5, 0.0][f] + turn) * Basis(Vector3.RIGHT, spill.randf_range(-0.08, 0.08))
		_block(Transform3D(facing, at), Vector3(long, rise * 0.92, _tread * 0.85), tone)
	# And loose ones left lying on the broken top.
	if cut:
		for b in 2 + int(ruin * 7.0):
			var rects: Array[Rect2] = regions[top - 1]
			var rect := rects[spill.randi_range(0, rects.size() - 1)]
			var size := Vector3(spill.randf_range(1.0, 1.8), spill.randf_range(0.5, 0.9), spill.randf_range(0.8, 1.3)) * rise
			var turned := Basis(Vector3.UP, spill.randf_range(0.0, TAU)) * Basis(Vector3.RIGHT, spill.randf_range(-0.2, 0.2))
			if rect.size.x < size.x * 1.5 or rect.size.y < size.x * 1.5:
				continue
			var at := Vector3(spill.randf_range(rect.position.x + size.x * 0.7, rect.end.x - size.x * 0.7), top * rise + size.y * 0.42, spill.randf_range(rect.position.y + size.x * 0.7, rect.end.y - size.x * 0.7))
			_block(Transform3D(turned, at), size, spill.randf_range(0.8, 0.98))

	if not _loose.is_empty():
		var faces_shape := ConcavePolygonShape3D.new()
		faces_shape.set_faces(_loose)
		_solid(faces_shape, Vector3.ZERO)

	var mesh := ArrayMesh.new()
	if not _points.is_empty():
		var arrays := []
		arrays.resize(Mesh.ARRAY_MAX)
		arrays[Mesh.ARRAY_VERTEX] = _points
		arrays[Mesh.ARRAY_NORMAL] = _normals
		arrays[Mesh.ARRAY_COLOR] = _colours
		mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
		mesh.surface_set_material(mesh.get_surface_count() - 1, Sandstone.surface(colour, rise, rise * 1.7, 0.25 + 0.65 * ruin, 0.3 + 0.6 * ruin))
	if not _gold_points.is_empty():
		var arrays := []
		arrays.resize(Mesh.ARRAY_MAX)
		arrays[Mesh.ARRAY_VERTEX] = _gold_points
		arrays[Mesh.ARRAY_NORMAL] = _gold_normals
		mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
		mesh.surface_set_material(mesh.get_surface_count() - 1, Sandstone.gold())
	var model := MeshInstance3D.new()
	model.name = "Model"
	model.mesh = mesh
	add_child(model)
	triangles = (_points.size() + _gold_points.size()) / 3


# How far from the middle the core of a course reaches, and the casing over it at a level.
func _edge(course: int) -> float:
	return _half - _tread * (course + 1)


# The four corners of the casing at a level, by the face that follows each (+X, +Z, -X, -Z).
func _ring(level: int) -> Array[Vector3]:
	var h := _half - _tread * level
	var y := level * rise
	return [Vector3(h, y, h), Vector3(-h, y, h), Vector3(-h, y, -h), Vector3(h, y, -h)]


# A point on a face (0 +X, 1 +Z, 2 -X, 3 -Z): `a` along it, `out` from the middle, `y` up.
func _on(face: int, a: float, out: float, y: float) -> Vector3:
	match face:
		0:
			return Vector3(out, y, a)
		1:
			return Vector3(a, y, out)
		2:
			return Vector3(-out, y, a)
	return Vector3(a, y, -out)


# A rectangle of ground against a face: from `a0` to `a1` along it and `out0` to `out1` from the middle.
func _on_face(face: int, a0: float, a1: float, out0: float, out1: float) -> Rect2:
	match face:
		0:
			return Rect2(out0, a0, out1 - out0, a1 - a0)
		1:
			return Rect2(a0, out0, a1 - a0, out1 - out0)
		2:
			return Rect2(-out1, a0, out1 - out0, a1 - a0)
	return Rect2(a0, -out1, a1 - a0, out1 - out0)


# Rectangles with a hole cut out of them.
func _minus(rects: Array[Rect2], hole: Rect2) -> Array[Rect2]:
	var left: Array[Rect2] = []
	for rect in rects:
		var lost := rect.intersection(hole)
		if lost.size.x < 0.01 or lost.size.y < 0.01:
			left.append(rect)
			continue
		if lost.position.x - rect.position.x > 0.01:
			left.append(Rect2(rect.position.x, rect.position.y, lost.position.x - rect.position.x, rect.size.y))
		if rect.end.x - lost.end.x > 0.01:
			left.append(Rect2(lost.end.x, rect.position.y, rect.end.x - lost.end.x, rect.size.y))
		if lost.position.y - rect.position.y > 0.01:
			left.append(Rect2(lost.position.x, rect.position.y, lost.size.x, lost.position.y - rect.position.y))
		if rect.end.y - lost.end.y > 0.01:
			left.append(Rect2(lost.position.x, lost.end.y, lost.size.x, rect.end.y - lost.end.y))
	return left


# The stretches of a course's side `face` that are still its outer face, each [from, to] along it.
func _outer(rects: Array[Rect2], face: int, h: float) -> Array:
	var found: Array = []
	for rect in rects:
		match face:
			0:
				if absf(rect.end.x - h) < 0.01:
					found.append([rect.position.y, rect.end.y])
			1:
				if absf(rect.end.y - h) < 0.01:
					found.append([rect.position.x, rect.end.x])
			2:
				if absf(rect.position.x + h) < 0.01:
					found.append([rect.position.y, rect.end.y])
			3:
				if absf(rect.position.y + h) < 0.01:
					found.append([rect.position.x, rect.end.x])
	found.sort_custom(func(a: Array, b: Array) -> bool: return a[0] < b[0])
	var joined: Array = []
	for stretch: Array in found:
		if not joined.is_empty() and stretch[0] <= joined[-1][1] + 0.01:
			joined[-1][1] = maxf(joined[-1][1], stretch[1])
		else:
			joined.append(stretch)
	return joined


# What two lists of stretches have in common.
func _both(some: Array, others: Array) -> Array:
	var shared: Array = []
	for a: Array in some:
		for b: Array in others:
			var from := maxf(a[0], b[0])
			var to := minf(a[1], b[1])
			if to - from > 0.3:
				shared.append([from, to])
	return shared


# The casing one side of a course should have, before what has fallen is taken off.
func _casing_wanted(course: int, h: float, cased_from: int, random: RandomNumberGenerator) -> Array:
	if casing <= 0.0:
		return []
	var share := 1.0
	if course < cased_from:
		# Below the cap of casing its edge is ragged: three courses with less and less on them.
		if casing >= 1.0 or course < cased_from - 3:
			return []
		share = [0.62, 0.38, 0.16][cased_from - 1 - course] * (1.0 - ruin)
	elif ruin > 0.0:
		var fell := random.randf()
		var how := random.randf()
		if how < ruin * ruin:
			return []
		if fell < ruin * 0.9:
			share = lerpf(0.75, 0.2, ruin) * random.randf_range(0.6, 1.2)
	if share >= 1.0:
		return [[-h, h]]
	var wanted: Array = []
	var pieces := 1 + (random.randi() % 2)
	for p in pieces:
		var long := share * h * 2.0 / pieces * random.randf_range(0.7, 1.3)
		var from := random.randf_range(-h, h - long)
		wanted.append([from, from + long])
	return wanted


# A box of the core: drawn (all but its underside) and solid.
func _box(low: Vector3, high: Vector3, tint: Color) -> void:
	var a := Vector3(low.x, low.y, low.z)
	var b := Vector3(high.x, low.y, low.z)
	var c := Vector3(high.x, low.y, high.z)
	var d := Vector3(low.x, low.y, high.z)
	var up := Vector3(0.0, high.y - low.y, 0.0)
	_quad(d, c, c + up, d + up, Vector3.BACK, tint)
	_quad(b, a, a + up, b + up, Vector3.FORWARD, tint)
	_quad(c, b, b + up, c + up, Vector3.RIGHT, tint)
	_quad(a, d, d + up, a + up, Vector3.LEFT, tint)
	_quad(a + up, b + up, c + up, d + up, Vector3.UP, tint)
	var shape := BoxShape3D.new()
	shape.size = high - low
	_solid(shape, (low + high) * 0.5)


# A loose block, lying anyhow: drawn, and solid as triangles.
func _block(place: Transform3D, size: Vector3, tone: float) -> void:
	var tint := Color(tone, 0.0, 1.0)
	var half := size * 0.5
	for face: Array in [[Vector3.RIGHT, Vector3.UP, Vector3.BACK], [Vector3.LEFT, Vector3.UP, Vector3.FORWARD], [Vector3.BACK, Vector3.UP, Vector3.LEFT],
			[Vector3.FORWARD, Vector3.UP, Vector3.RIGHT], [Vector3.UP, Vector3.RIGHT, Vector3.FORWARD]]:
		var out: Vector3 = face[0] * half
		var one: Vector3 = face[1] * half
		var two: Vector3 = face[2] * half
		_quad(place * (out - one - two), place * (out - one + two), place * (out + one + two), place * (out + one - two), place.basis * face[0], tint, true)


# A run of casing stones on a course: a slope from the step below up to the top of this one.
func _wedge(course: int, face: int, from: float, to: float) -> void:
	var h := _edge(course)
	var y := course * rise
	var pale := Color(1.0, 1.0, 0.0)
	# (where it reaches a corner it runs on to meet the casing of the next face)
	var low_from := from - _tread if from <= -h + 0.01 else from
	var low_to := to + _tread if to >= h - 0.01 else to
	var out := _on(face, 0.0, 1.0, 0.0)
	var along := _on(face, 1.0, 0.0, 0.0)
	_quad(_on(face, low_from, h + _tread, y), _on(face, low_to, h + _tread, y), _on(face, to, h, y + rise), _on(face, from, h, y + rise), out + Vector3.UP, pale, true)
	_tri(_on(face, from, h, y), _on(face, low_from, h + _tread, y), _on(face, from, h, y + rise), -along, pale, true)
	_tri(_on(face, to, h, y), _on(face, low_to, h + _tread, y), _on(face, to, h, y + rise), along, pale, true)


# The rubble under a fallen corner. Fallen stone lies no steeper than it will
# stand (`repose`): it fills the bite from as high as that lets it reach, level
# from wall to wall, and runs down and out past the foot as a ridge that falls
# away to either side, with blocks lying on it. It is a sheet of squares laid
# along the corner; those that would be wholly inside standing stone or under
# the ground are left out.
func _fan(bite: Dictionary, top: int, random: RandomNumberGenerator) -> void:
	var way := Vector2(bite["x"], bite["z"]).normalized()
	var across := Vector2(-way.y, way.x)
	var inner: PackedFloat32Array = bite["inner"]
	var repose := random.randf_range(0.5, 0.62)
	var corner := _edge(0) * ROOT2
	var spill := base * (0.05 + 0.12 * ruin)
	var foot := _half * ROOT2 + spill
	var upto := -1
	for i in top:
		if inner[i] < _edge(i) - 0.01 and i * rise <= repose * (foot - inner[i] * ROOT2):
			upto = i
	if upto < 0:
		return
	var heap := {"way": way, "across": across, "inner": inner, "repose": repose, "corner": corner, "spill": spill, "foot": foot,
		"crest": upto * rise + 0.1, "head": inner[upto] * ROOT2 - 1.0, "widest": maxf(2.0, (_edge(upto) - inner[upto]) * 0.6)}
	var head: float = heap["head"]
	var cell := clampf(base / 28.0, 1.3, 2.4)
	var reach: float = maxf(heap["widest"], spill * 1.8 + 2.5) + cell
	var rows := maxi(ceili((foot - head) / cell), 3)
	var columns := maxi(ceili(reach * 2.0 / cell), 4)
	var grid: Array[Vector3] = []
	var hidden: Array[bool] = []
	for r in rows + 1:
		for c in columns + 1:
			var s := lerpf(head, foot, float(r) / rows)
			var t := lerpf(-reach, reach, float(c) / columns)
			var edge := r == rows or c == 0 or c == columns
			if not edge:
				s += random.randf_range(-0.3, 0.3) * cell * (0.0 if r == 0 else 1.0)
				t += random.randf_range(-0.3, 0.3) * cell
			var found := _fan_height(heap, s, t)
			var y: float = found[0] + random.randf_range(-0.4, 0.4)
			if edge and r > 0:
				y = minf(y, -0.3)
			grid.append(Vector3(way.x * s + across.x * t, y, way.y * s + across.y * t))
			hidden.append(found[1] or y < -0.25)
	for r in rows:
		for c in columns:
			var i := r * (columns + 1) + c
			if hidden[i] and hidden[i + 1] and hidden[i + columns + 1] and hidden[i + columns + 2]:
				continue
			var tone := random.randf_range(0.72, 0.9)
			_tri(grid[i], grid[i + 1], grid[i + columns + 2], Vector3.UP, Color(tone, 0.5, 1.0), true)
			_tri(grid[i], grid[i + columns + 2], grid[i + columns + 1], Vector3.UP, Color(tone * random.randf_range(0.9, 1.06), 0.5, 1.0), true)
	for b in 8 + int(ruin * 18.0):
		var s := random.randf_range(head + 1.0, foot + 2.0)
		var t := random.randf_range(-1.0, 1.0) * (_fan_width(heap, s) + spill * 0.8)
		var size := Vector3(random.randf_range(0.9, 1.5), random.randf_range(0.6, 1.0), random.randf_range(0.8, 1.2)) * rise * random.randf_range(0.5, 1.0)
		var turned := Basis.from_euler(Vector3(random.randf_range(-0.35, 0.35), random.randf_range(0.0, TAU), random.randf_range(-0.35, 0.35)))
		var found := _fan_height(heap, s, t)
		if found[1]:
			continue
		_block(Transform3D(turned, Vector3(way.x * s + across.x * t, maxf(found[0], 0.0) + size.y * random.randf_range(0.0, 0.3), way.y * s + across.y * t)), size, random.randf_range(0.75, 0.98))


# How high the rubble of a fallen corner lies, `s` out along the corner and `t`
# across it, and whether it is out of sight there, inside stone that still stands.
func _fan_height(heap: Dictionary, s: float, t: float) -> Array:
	var repose: float = heap["repose"]
	var spill: float = heap["spill"]
	var wide := _fan_width(heap, s)
	# As it would lie with nothing in its way: level across the middle, falling away at the sides.
	var free := maxf(minf(heap["crest"], repose * (heap["foot"] - s)), 0.0) - repose * maxf(absf(t) - wide, 0.0)
	# But it lies under where the steps were before they fell, save for a bank of
	# it against the foot, as deep as what has spilled out past the corner.
	var at: Vector2 = heap["way"] * s + heap["across"] * t
	var out := maxf(absf(at.x), absf(at.y))
	var stood := (_half - out) * rise / _tread - rise * 2.0 - 0.3
	var bank := minf(minf((_half + spill / ROOT2 + 0.5 - out) * rise / _tread, spill * repose), repose * (wide + spill * 1.8 - absf(t)))
	var high := minf(free, maxf(stood, bank))
	# (in the bite itself it shows; beside it, under the steps, it does not)
	var inner: PackedFloat32Array = heap["inner"]
	var course := clampi(int(maxf(high, 0.0) / rise), 0, inner.size() - 1)
	var in_bite: bool = at.x * heap["way"].x * ROOT2 > inner[course] and at.y * heap["way"].y * ROOT2 > inner[course]
	return [high, free > stood and stood >= bank and not in_bite]


# How wide the level middle of the rubble is, `s` out along the corner: as
# wide as the bite it lies in, and narrowing to a ridge once it is out past the foot.
func _fan_width(heap: Dictionary, s: float) -> float:
	var head: float = heap["head"]
	var corner: float = heap["corner"]
	var widest: float = heap["widest"]
	if s < corner:
		return clampf((s - head) * 0.8 + 1.5, 1.5, widest)
	return lerpf(clampf((corner - head) * 0.8 + 1.5, 1.5, widest), 1.0, clampf((s - corner) / maxf(heap["foot"] - corner, 0.1), 0.0, 1.0))


func _solid(shape: Shape3D, at: Vector3) -> void:
	var collider := CollisionShape3D.new()
	collider.shape = shape
	collider.position = at
	add_child(collider)
	shapes += 1


# A flat face of stone with four corners, seen from the side `out` points to.
func _quad(a: Vector3, b: Vector3, c: Vector3, d: Vector3, out: Vector3, tint: Color, solid := false) -> void:
	_tri(a, b, c, out, tint, solid)
	_tri(a, c, d, out, tint, solid)


func _tri(a: Vector3, b: Vector3, c: Vector3, out: Vector3, tint: Color, solid := false) -> void:
	var normal := (b - a).cross(c - a)
	if normal.dot(out) < 0.0:
		var swapped := b
		b = c
		c = swapped
		normal = -normal
	normal = normal.normalized()
	# (the side a face is seen from is the one its corners go clockwise round)
	for point: Vector3 in [a, c, b]:
		_points.append(point)
		_normals.append(normal)
		_colours.append(tint)
		if solid:
			_loose.append(point)


func _gold_tri(a: Vector3, b: Vector3, c: Vector3, out: Vector3) -> void:
	var normal := (b - a).cross(c - a)
	if normal.dot(out) < 0.0:
		var swapped := b
		b = c
		c = swapped
		normal = -normal
	normal = normal.normalized()
	for point: Vector3 in [a, c, b]:
		_gold_points.append(point)
		_gold_normals.append(normal)
