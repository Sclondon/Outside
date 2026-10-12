class_name SphinxMesh
## The stone of a `Sphinx`, carved from numbers: a lion lying on a low base,
## forelegs out in front, hind legs folded, the tail brought round the right
## haunch; and on its shoulders a king's head in the striped headcloth (the
## nemes, with the cobra at the brow and the false beard), a ram's with its
## curled horns, or a falcon's in a long wig.
##
## Everything is worked out for a sphinx one metre long, facing +Z with the
## middle of its foot at the origin, and made `size` times bigger at the end.
## `carve` gives back the pieces a `Sphinx` puts together: the body, the right
## foreleg (which it moves), the head (which it turns), the two eyes (which it
## opens and lights), and what is solid.
##
## A piece is lofted: rings of points with skin between them, shaded smoothly
## across the skin and sharply at an edge. About 3000 triangles for a king,
## in one surface of stone (`Toon.sandstone`); painted, a few more surfaces of
## flat colour.

## The heads, in the order of `Sphinx.Head`.
enum { KING, RAM, FALCON }

## What a triangle is made of. Bare, all of them are stone, lighter or darker;
## painted, each but the first and last is a colour of its own.
enum { STONE, SHADE, LIGHT, SKIN, KOHL, HOLLOW, HORN, SLOTS }
## How light the stone of each is when it is bare.
const TONE: Array[float] = [1.0, 0.74, 1.05, 1.0, 0.56, 0.3, 0.76]
## The paint: lapis blue, yellow ochre, red ochre for the skin, black; and brown for horn and beak.
const PAINT: Array[Color] = [Color.WHITE, Color(0.13, 0.25, 0.52), Color(0.86, 0.64, 0.2), Color(0.62, 0.3, 0.2), Color(0.09, 0.08, 0.08), Color.WHITE, Color(0.42, 0.31, 0.2)]

## Half the width of the way between the forelegs, and of a foreleg; and how far out the middle of a foreleg is.
const GAP := 0.065
const PAW := 0.045
const PAW_OUT := 0.11
## Half the width of the base, and how far it runs fore and aft of the middle.
const BASE := Vector2(0.235, 0.53)
## The body from rump to chest: where along it, half its width, its height.
const BODY: Array[Vector3] = [Vector3(-0.47, 0.105, 0.2), Vector3(-0.445, 0.135, 0.235), Vector3(-0.36, 0.15, 0.25), Vector3(-0.25, 0.145, 0.245),
		Vector3(-0.14, 0.125, 0.235), Vector3(-0.03, 0.13, 0.25), Vector3(0.05, 0.15, 0.28), Vector3(0.1, 0.152, 0.305), Vector3(0.13, 0.145, 0.31)]
## A foreleg from elbow to toes, the same.
const FORE: Array[Vector3] = [Vector3(-0.02, 0.045, 0.15), Vector3(0.05, 0.046, 0.125), Vector3(0.13, 0.043, 0.09), Vector3(0.28, 0.04, 0.075),
		Vector3(0.4, 0.042, 0.075), Vector3(0.445, 0.05, 0.082), Vector3(0.485, 0.05, 0.07), Vector3(0.5, 0.043, 0.045)]
## A hind paw, lying along the flank.
const HIND: Array[Vector3] = [Vector3(-0.3, 0.03, 0.05), Vector3(-0.2, 0.032, 0.052), Vector3(-0.13, 0.034, 0.05), Vector3(-0.105, 0.03, 0.035)]
const HIND_OUT := 0.185
## A haunch: where the middle of its foot is, and how far it reaches out, up and along.
const HAUNCH := Vector3(0.15, 0.0, -0.33)
const HAUNCH_SIZE := Vector3(0.058, 0.2, 0.135)
## Where the chest is, and the way through it (half its width, its height) when the sphinx opens.
const CHEST := 0.13
const WAY := Vector2(0.05, 0.16)
## How tall a head is, chin to crown, and where the middle of it is above the base.
const HEAD := 0.17
const HEAD_AT := Vector3(0.0, 0.378, 0.098)
## Where the neck turns.
const NECK := Vector3(0.0, 0.3, 0.08)
## Where the offering slab lies between the forelegs (its middle along the sphinx), and half its size across and along.
const SLAB := 0.33
const SLAB_HALF := Vector2(0.05, 0.06)
## Where the top of everything is.
const TOP := 0.475


## How thick the base is for a sphinx of a size, in metres: low enough to walk onto.
static func base_height(size: float) -> float:
	return clampf(size * 0.05, 0.1, 0.22)


## Triangles as they are gathered, before they are a mesh.
class Carver:
	var at: Array[PackedVector3Array] = []
	var smooth: Array[PackedInt32Array] = []

	func _init() -> void:
		for i in SLOTS:
			at.append(PackedVector3Array())
			smooth.append(PackedInt32Array())

	## A triangle that looks along `out`, more or less. `group` 0 is flat; faces of any other group are shaded as one skin.
	func tri(a: Vector3, b: Vector3, c: Vector3, slot: int, group: int, out: Vector3) -> void:
		var across := (b - a).cross(c - a)
		if across.length_squared() < 1e-14:
			return
		if across.dot(out) < 0.0:
			var swap := b
			b = c
			c = swap
		at[slot].append(a)
		at[slot].append(b)
		at[slot].append(c)
		for i in 3:
			smooth[slot].append(group)

	func quad(a: Vector3, b: Vector3, c: Vector3, d: Vector3, slot: int, group: int, out: Vector3) -> void:
		tri(a, b, c, slot, group, out)
		tri(a, c, d, slot, group, out)

	## The same, looking away from a point (or, `inward`, towards it).
	func tri_from(a: Vector3, b: Vector3, c: Vector3, slot: int, group: int, middle: Vector3, inward := false) -> void:
		var out := (a + b + c) / 3.0 - middle
		tri(a, b, c, slot, group, -out if inward else out)

	func quad_from(a: Vector3, b: Vector3, c: Vector3, d: Vector3, slot: int, group: int, middle: Vector3, inward := false) -> void:
		tri_from(a, b, c, slot, group, middle, inward)
		tri_from(a, c, d, slot, group, middle, inward)

	## Skin between two rings of as many points each, from point `first` to point `last` of them.
	func band(one: PackedVector3Array, other: PackedVector3Array, slot: int, group: int, first := 0, last := -1, inward := false) -> void:
		if last < 0:
			last = one.size() - 1
		var middle := (SphinxMesh.middle_of(one) + SphinxMesh.middle_of(other)) * 0.5
		for i in range(first, last):
			quad_from(one[i], one[i + 1], other[i + 1], other[i], slot, group, middle, inward)

	## A flat end: a ring filled in, looking along `out`.
	func cap(ring: PackedVector3Array, slot: int, out: Vector3) -> void:
		# (flattened along whichever way it looks, to cut it into triangles)
		var flat := PackedVector2Array()
		var side := Vector3.UP.cross(out).normalized() if absf(out.y) < 0.9 else Vector3.RIGHT
		var up := out.cross(side).normalized()
		for point in ring:
			flat.append(Vector2(point.dot(side), point.dot(up)))
		var corners := Geometry2D.triangulate_polygon(flat)
		for i in range(0, corners.size(), 3):
			tri(ring[corners[i]], ring[corners[i + 1]], ring[corners[i + 2]], slot, 0, out)

	## A box, flat on every side.
	func box(low: Vector3, high: Vector3, slot: int, lid := true, floor := false) -> void:
		var c: Array[Vector3] = []
		for i in 8:
			c.append(Vector3(high.x if i & 1 else low.x, high.y if i & 2 else low.y, high.z if i & 4 else low.z))
		quad(c[0], c[2], c[6], c[4], slot, 0, Vector3.LEFT)
		quad(c[1], c[3], c[7], c[5], slot, 0, Vector3.RIGHT)
		quad(c[0], c[1], c[3], c[2], slot, 0, Vector3.FORWARD)
		quad(c[4], c[5], c[7], c[6], slot, 0, Vector3.BACK)
		if lid:
			quad(c[2], c[3], c[7], c[6], slot, 0, Vector3.UP)
		if floor:
			quad(c[0], c[1], c[5], c[4], slot, 0, Vector3.DOWN)

	## A tube along a line of points, `sides` round, as thick at each as `radii` says. `slots` are taken turn about along it.
	func tube(line: Array[Vector3], radii: Array[float], sides: int, slots: Array[int], group: int) -> void:
		var rings: Array[PackedVector3Array] = []
		var across := Vector3.ZERO
		for k in line.size():
			var along := (line[mini(k + 1, line.size() - 1)] - line[maxi(k - 1, 0)]).normalized()
			if k == 0:
				across = along.cross(Vector3.UP if absf(along.y) < 0.9 else Vector3.RIGHT).normalized()
			else:
				# (carried along from the ring before, so the tube does not twist)
				across = (across - along * across.dot(along)).normalized()
			var other := along.cross(across)
			var ring := PackedVector3Array()
			for i in sides + 1:
				var angle := TAU * i / sides
				ring.append(line[k] + (across * cos(angle) + other * sin(angle)) * radii[k])
			rings.append(ring)
		for k in rings.size() - 1:
			band(rings[k], rings[k + 1], slots[k % slots.size()], group)
		var last := rings.size() - 1
		for i in sides:
			tri_from(rings[last][i], rings[last][i + 1], line[last], slots[(last - 1) % slots.size()], group, line[last - 1])
			tri_from(rings[0][i], rings[0][i + 1], line[0], slots[0], group, line[1])

	## Half a ball stood on a flat foot: the top half of an egg `size` out, up and along from `foot`.
	func dome(foot: Vector3, size: Vector3, slot: int, group: int, round := 10, rise := 5) -> void:
		var rings: Array[PackedVector3Array] = []
		for k in rise + 1:
			var up := PI * 0.5 * k / rise
			var ring := PackedVector3Array()
			for i in round + 1:
				var angle := TAU * i / round
				ring.append(foot + Vector3(cos(angle) * cos(up) * size.x, sin(up) * size.y, sin(angle) * cos(up) * size.z))
			rings.append(ring)
		for k in rise:
			band(rings[k], rings[k + 1], slot, group)

	## Makes all of it bigger or smaller about a point.
	func grow(about: Vector3, by: float) -> void:
		for slot in SLOTS:
			for i in at[slot].size():
				at[slot][i] = about + (at[slot][i] - about) * by

	## Takes in everything another has.
	func take(other: Carver) -> void:
		for slot in SLOTS:
			at[slot].append_array(other.at[slot])
			smooth[slot].append_array(other.smooth[slot])

	## Makes a mesh of it: `size` times bigger, about `origin`, worn by `wear`.
	## Bare, it is one surface of `stone`; `painted`, each slot that is a colour is a surface of its own.
	func mesh(size: float, origin: Vector3, wear: float, stone: Material, laid: float, painted: bool, paints: Array[Color]) -> ArrayMesh:
		var made := ArrayMesh.new()
		# Where every corner ends up, and which way the skin faces at each.
		var normals := {}
		var placed: Array[PackedVector3Array] = []
		for slot in SLOTS:
			var points := PackedVector3Array()
			points.resize(at[slot].size())
			for i in points.size():
				points[i] = (SphinxMesh.worn(at[slot][i], wear * 0.004) - origin) * size
			placed.append(points)
			for i in range(0, points.size(), 3):
				var face := (points[i + 1] - points[i]).cross(points[i + 2] - points[i])
				for j in 3:
					if smooth[slot][i + j] != 0:
						var key := SphinxMesh.key_of(at[slot][i + j], smooth[slot][i + j])
						normals[key] = normals.get(key, Vector3.ZERO) + face
		# The surfaces: bare, one of stone that has every slot in it; painted, the stone and the hollows, and one for each colour.
		var surfaces: Array = [[[STONE, HOLLOW], stone]] if painted else [[range(SLOTS), stone]]
		if painted:
			for slot: int in [SHADE, LIGHT, SKIN, KOHL, HORN]:
				surfaces.append([[slot], Toon.surface(paints[slot])])
		for surface: Array in surfaces:
			var tool_points := PackedVector3Array()
			var tool_normals := PackedVector3Array()
			var tool_colours := PackedColorArray()
			for slot: int in surface[0]:
				var points := placed[slot]
				for i in range(0, points.size(), 3):
					var face := (points[i + 1] - points[i]).cross(points[i + 2] - points[i]).normalized()
					# (Godot's front is clockwise: the second and third corners change places)
					for j: int in [0, 2, 1]:
						tool_points.append(points[i + j])
						var group := smooth[slot][i + j]
						tool_normals.append(face if group == 0 else (normals[SphinxMesh.key_of(at[slot][i + j], group)] as Vector3).normalized())
						tool_colours.append(Color(TONE[slot], laid, 1.0))
			if not tool_points.is_empty():
				SphinxMesh.add_surface(made, tool_points, tool_normals, tool_colours if surface[1] == stone else PackedColorArray(), surface[1])
		return made


static func add_surface(mesh: ArrayMesh, points: PackedVector3Array, normals: PackedVector3Array, colours: PackedColorArray, material: Material) -> void:
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = points
	arrays[Mesh.ARRAY_NORMAL] = normals
	if not colours.is_empty():
		arrays[Mesh.ARRAY_COLOR] = colours
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	mesh.surface_set_material(mesh.get_surface_count() - 1, material)


static func key_of(point: Vector3, group: int) -> Vector4i:
	return Vector4i(roundi(point.x * 8192.0), roundi(point.y * 8192.0), roundi(point.z * 8192.0), group)


static func middle_of(ring: PackedVector3Array) -> Vector3:
	var sum := Vector3.ZERO
	for point in ring:
		sum += point
	return sum / maxf(ring.size(), 1.0)


## Weathering: every point is moved a little, the same way wherever it is asked about, so the stone is lumpy and not torn.
static func worn(point: Vector3, by: float) -> Vector3:
	if by <= 0.0:
		return point
	const F := 31.0
	return point + Vector3(sin(point.y * F * 1.3 + point.z * F * 0.7), sin(point.z * F * 1.1 + point.x * F * 0.9 + 1.7), sin(point.x * F * 1.2 + point.y * F * 0.8 + 4.1)) * by


## A ring across something that lies on the base: up one side, round over the
## top and down the other, `over` points in the rounding. `x` is its middle,
## `half` half its width, `tall` its height above `foot`.
static func arch(x: float, z: float, half: float, foot: float, tall: float, over: int, square := 2.6) -> PackedVector3Array:
	var ring := PackedVector3Array()
	ring.append(Vector3(x - half, foot, z))
	for i in over:
		var angle := PI * (1.0 - float(i) / (over - 1))
		var out := signf(cos(angle)) * pow(absf(cos(angle)), 2.0 / square)
		ring.append(Vector3(x + half * out, foot + tall * 0.5 * (1.0 + pow(absf(sin(angle)), 2.0 / square)), z))
	ring.append(Vector3(x + half, foot, z))
	return ring


## How far out the side of such a ring is at a height.
static func arch_half(half: float, tall: float, at: float, square := 2.6) -> float:
	if at <= tall * 0.5:
		return half
	var up := clampf((at - tall * 0.5) / (tall * 0.5), 0.0, 1.0)
	return half * pow(maxf(1.0 - pow(up, square), 0.0), 1.0 / square)


## Carves a sphinx. Gives back:
##     body      the mesh of everything that does not move
##     paw       the right foreleg, about `paw_at` (its elbow, on the base)
##     head      the head, about `head_at` (its neck)
##     eyes      for each eye, [where it is from the neck, which way it faces (a Basis), its mesh]
##     solids    what is solid: [a shape, where it is]
##     foot      how thick the base is, metres
static func carve(size: float, head: int, wear: float, painted: bool, colour: Color, opens: bool) -> Dictionary:
	var foot := base_height(size) / size
	var stone := Sandstone.surface(colour, clampf(size * 0.11, 0.5, 1.5), clampf(size * 0.19, 0.8, 2.6), lerpf(0.15, 1.0, wear), lerpf(0.1, 0.9, wear))
	# A great one is built of blocks, as the paws of the one at Giza are; a small one is one stone.
	var laid := 1.0 if size >= 9.0 else 0.0
	var paints: Array[Color] = []
	for paint in PAINT:
		paints.append(paint.lerp(colour, wear * 0.55))
	var solids: Array = []

	var body := Carver.new()
	# The base.
	body.box(Vector3(-BASE.x, -0.04, -BASE.y), Vector3(BASE.x, foot, BASE.y), STONE)
	solids.append(_solid_box(Vector3(-BASE.x, -0.04, -BASE.y), Vector3(BASE.x, foot, BASE.y), size))
	_body(body, foot, opens, solids, size)
	_foreleg(body, -1.0, foot, Vector3.ZERO)
	for side: float in [-1.0, 1.0]:
		solids.append(_solid_box(Vector3(side * PAW_OUT - PAW, foot, CHEST), Vector3(side * PAW_OUT + PAW, foot + 0.075, 0.5), size))
		solids.append(_solid_box(Vector3(side * PAW_OUT - PAW, foot, -0.02), Vector3(side * PAW_OUT + PAW, foot + 0.12, CHEST), size))
		# A haunch, and the hind paw lying forward along the flank.
		body.dome(Vector3(side * HAUNCH.x, foot, HAUNCH.z), HAUNCH_SIZE, STONE, 2)
		solids.append(_solid_box(Vector3(side * (HAUNCH.x - 0.05), foot, HAUNCH.z - 0.1), Vector3(side * (HAUNCH.x + HAUNCH_SIZE.x * 0.8), foot + HAUNCH_SIZE.y * 0.93, HAUNCH.z + 0.1), size))
		var rings: Array[PackedVector3Array] = []
		for ring in HIND:
			rings.append(arch(side * HIND_OUT, ring.x, ring.y, foot, ring.z, 7, 2.2))
		for k in rings.size() - 1:
			body.band(rings[k], rings[k + 1], STONE, 3)
		body.cap(rings[rings.size() - 1], STONE, Vector3.BACK)
		solids.append(_solid_box(Vector3(side * HIND_OUT - 0.032, foot, -0.3), Vector3(side * HIND_OUT + 0.032, foot + 0.05, -0.105), size))
	# The tail: from under the rump, round the right haunch, and up over it, ending in its tuft.
	var tail: Array[Vector3] = [Vector3(0.0, 0.03, -0.49), Vector3(0.09, 0.02, -0.5), Vector3(0.17, 0.02, -0.485), Vector3(0.214, 0.02, -0.43), Vector3(0.22, 0.02, -0.33),
			Vector3(0.214, 0.045, -0.26), Vector3(0.2, 0.1, -0.245), Vector3(0.186, 0.15, -0.27), Vector3(0.178, 0.175, -0.3)]
	var thick: Array[float] = [0.016, 0.016, 0.015, 0.015, 0.014, 0.014, 0.014, 0.019, 0.012]
	for k in tail.size():
		tail[k].y += foot
	body.tube(tail, thick, 6, [STONE], 4)

	var paw := Carver.new()
	var paw_at := Vector3(PAW_OUT, foot, 0.0)
	_foreleg(paw, 1.0, foot, Vector3.ZERO)

	var top := Carver.new()
	var middle := HEAD_AT + Vector3(0.0, foot, 0.0)
	var eyes: Array = []
	_neck(top, foot, middle, head)
	if head == KING:
		_king(top, middle, eyes, wear)
	else:
		# (the beasts' heads are set out for a head 0.15 tall, and made to the size of the king's)
		var beast := Carver.new()
		var by := HEAD / 0.15
		if head == RAM:
			_ram(beast, middle, eyes)
		else:
			_falcon(beast, middle, eyes, wear)
		beast.grow(middle, by)
		top.take(beast)
		for eye: Array in eyes:
			eye[0] = middle + ((eye[0] as Vector3) - middle) * by
			eye[2] = float(eye[2]) * by
			eye[3] = float(eye[3]) * by
		if head == FALCON:
			_headcloth(top, middle, 0.66, false, false)
	var head_at := NECK + Vector3(0.0, foot, 0.0)
	solids.append(_solid_box(middle - Vector3(0.42, 0.62, 0.48) * HEAD, middle + Vector3(0.42, 0.56, 0.42) * HEAD, size))

	var eye_meshes: Array = []
	for eye: Array in eyes:
		# [where, which way it looks, half its width, half its height, how far its outer corner is lifted]
		var facing: Vector3 = (eye[1] as Vector3).normalized()
		var across := Vector3.UP.cross(facing).normalized()
		var up := facing.cross(across).normalized()
		var lid := Carver.new()
		var rim := PackedVector3Array()
		var outer := signf((eye[0] as Vector3).x - middle.x)
		for i in 12:
			var angle := TAU * i / 12.0
			# (an almond: drawn to a point at each corner, the outer one a little higher)
			var wide := cos(angle)
			var high := sin(angle) * (1.0 - 0.45 * absf(wide) * absf(wide))
			rim.append(Vector3(wide * float(eye[2]), high * float(eye[3]) + wide * outer * float(eye[4]), 0.0))
		for i in 12:
			lid.tri(Vector3.ZERO, rim[i], rim[(i + 1) % 12], STONE, 0, Vector3.BACK)
		var eye_mesh := ArrayMesh.new()
		var points := PackedVector3Array()
		var facings := PackedVector3Array()
		for i in range(0, lid.at[STONE].size(), 3):
			for j: int in [0, 2, 1]:
				points.append(lid.at[STONE][i + j] * size)
				facings.append(Vector3.BACK)
		add_surface(eye_mesh, points, facings, PackedColorArray(), null)
		eye_meshes.append([(worn(eye[0], wear * 0.4 * 0.004) - head_at) * size, Basis(across, up, facing), eye_mesh])

	return {
		"body": body.mesh(size, Vector3.ZERO, wear, stone, laid, painted, paints),
		"paw": paw.mesh(size, paw_at, wear, stone, laid, painted, paints),
		"paw_at": paw_at * size,
		"head": top.mesh(size, head_at, wear * 0.4, stone, 0.0, painted, paints),
		"head_at": head_at * size,
		"eyes": eye_meshes,
		"solids": solids,
		"foot": foot * size,
	}


static func _solid_box(low: Vector3, high: Vector3, size: float) -> Array:
	var shape := BoxShape3D.new()
	shape.size = (high - low).abs() * size
	return [shape, (low + high) * 0.5 * size]


# The body: a skin over rings from the rump to the chest, flat at both ends; with a way through it from the chest to
# the rump, if it opens. What is solid follows the same rings.
static func _body(into: Carver, foot: float, opens: bool, solids: Array, size: float) -> void:
	const OVER := 11
	var rings: Array[PackedVector3Array] = []
	for ring in BODY:
		var points := arch(0.0, ring.x, ring.y, foot, ring.z, OVER)
		if opens:
			for corner: Vector2 in [Vector2(WAY.x, 0.0), Vector2(WAY.x, WAY.y), Vector2(-WAY.x, WAY.y), Vector2(-WAY.x, 0.0)]:
				points.append(Vector3(corner.x, foot + corner.y, ring.x))
		rings.append(points)
	var outside := OVER + 1
	for k in rings.size() - 1:
		into.band(rings[k], rings[k + 1], STONE, 1, 0, outside)
		if opens:
			# (the walls and the roof of the way through, dark)
			into.band(rings[k], rings[k + 1], HOLLOW, 0, outside + 1, outside + 4, true)
		# What is solid between these two rings: the whole of it, or the roof of the way through.
		var hull := PackedVector3Array()
		for ring: Vector3 in [BODY[k], BODY[k + 1]]:
			var low := WAY.y if opens else 0.0
			for point in arch(0.0, ring.x, ring.y, foot, ring.z, 7):
				if point.y >= foot + low - 0.0001:
					hull.append(point * size)
			if opens:
				var out := arch_half(ring.y, ring.z, low)
				hull.append(Vector3(-out, foot + low, ring.x) * size)
				hull.append(Vector3(out, foot + low, ring.x) * size)
		var shape := ConvexPolygonShape3D.new()
		shape.points = hull
		solids.append([shape, Vector3.ZERO])
	into.cap(rings[0], STONE, Vector3.FORWARD)
	into.cap(rings[rings.size() - 1], STONE, Vector3.BACK)
	if opens:
		for side: float in [-1.0, 1.0]:
			solids.append(_solid_box(Vector3(side * WAY.x, foot, BODY[0].x), Vector3(side * 0.105, foot + WAY.y, CHEST), size))
		# A frame round each end of it, standing a little proud.
		for z: Array in [[CHEST, 0.006], [BODY[0].x, -0.006]]:
			var front: float = z[0]
			var proud: float = z[1]
			for side: float in [-1.0, 1.0]:
				into.box(Vector3(minf(side * WAY.x, side * (WAY.x + 0.012)), foot, minf(front, front + proud)),
						Vector3(maxf(side * WAY.x, side * (WAY.x + 0.012)), foot + WAY.y + 0.012, maxf(front, front + proud)), SHADE)
			into.box(Vector3(-WAY.x, foot + WAY.y, minf(front, front + proud)), Vector3(WAY.x, foot + WAY.y + 0.012, maxf(front, front + proud)), SHADE)


# A foreleg, from the elbow out to the toes: `side` is -1 for the left. The toes are three grooves in the end of it.
static func _foreleg(into: Carver, side: float, foot: float, _about: Vector3) -> void:
	const OVER := 9
	var rings: Array[PackedVector3Array] = []
	for k in FORE.size():
		var ring := FORE[k]
		var points := arch(side * PAW_OUT, ring.x, ring.y, foot, ring.z, OVER, 2.4)
		if k >= 5:
			for groove: int in [3, 5, 7]:
				points[groove].y = foot + (points[groove].y - foot) * 0.78
				points[groove].z -= 0.012
		rings.append(points)
	for k in rings.size() - 1:
		into.band(rings[k], rings[k + 1], STONE, 5)
	into.cap(rings[rings.size() - 1], STONE, Vector3.BACK)
	into.cap(rings[0], STONE, Vector3.FORWARD)


# The neck: from the shoulders up into the head.
static func _neck(into: Carver, foot: float, middle: Vector3, head: int) -> void:
	var wide := 1.25 if head == RAM else 1.0
	var rings: Array[PackedVector3Array] = []
	for ring: Array in [[Vector3(0.0, foot + 0.235, 0.075), 0.095 * wide, 0.075 * wide], [Vector3(0.0, foot + 0.29, 0.086), 0.066 * wide, 0.06 * wide],
			[Vector3(0.0, middle.y - 0.035, middle.z - 0.008), 0.05 * wide, 0.05]]:
		var points := PackedVector3Array()
		for i in 9:
			var angle := TAU * i / 8.0
			points.append((ring[0] as Vector3) + Vector3(sin(angle) * float(ring[1]), 0.0, cos(angle) * float(ring[2])))
		rings.append(points)
	for k in rings.size() - 1:
		into.band(rings[k], rings[k + 1], SKIN if head == KING else STONE, 6)


# --- The king

# A point on the king's face: `across` degrees round from straight ahead (to his left is more), `up` degrees above level.
static func _face(middle: Vector3, across: float, up: float, nose: float, lift := 0.0) -> Vector3:
	var lon := deg_to_rad(across)
	var lat := deg_to_rad(up)
	# The skull, and the jaw drawn in under it.
	var jaw := 1.0 - 0.3 * smoothstep(0.0, -70.0, up)
	var out := 1.0 + lift
	# The nose: a ridge down the middle that stands out most at its tip. Worn, it is a scar.
	var ridge := maxf(0.0, 1.0 - absf(across) / (9.0 if up > 0.0 else 12.5))
	var tip := 0.0
	if up > -10.0 and up < 19.0:
		tip = _curve([Vector2(-10.0, 0.03), Vector2(-6.5, 0.23), Vector2(-3.0, 0.2), Vector2(3.0, 0.13), Vector2(10.0, 0.07), Vector2(19.0, 0.0)], up)
	out += ridge * tip * nose - ridge * 0.03 * (1.0 - nose) * float(up > -10.0 and up < 12.0)
	# The brow, and the hollow of each eye under it.
	out += 0.04 * _bump(up, 21.0, 5.0) * smoothstep(5.0, 12.0, absf(across)) * (1.0 - smoothstep(42.0, 56.0, absf(across)))
	out -= 0.045 * _bump(up, 11.0, 7.0) * _bump(absf(across), 24.0, 13.0)
	# Cheekbones, lips with a line between them, and the chin.
	out += 0.035 * _bump(up, -3.0, 13.0) * _bump(absf(across), 42.0, 20.0)
	var mouth := maxf(0.0, 1.0 - pow(absf(across) / 21.0, 2.0))
	out += mouth * (0.065 * _bump(up, -17.5, 3.4) + 0.06 * _bump(up, -23.5, 3.6) - 0.035 * _bump(up, -20.5, 1.6))
	out += 0.07 * _bump(up, -40.0, 13.0) * _bump(across, 0.0, 26.0)
	return middle + Vector3(sin(lon) * cos(lat) * 0.4 * jaw, sin(lat) * 0.52, cos(lon) * cos(lat) * 0.42) * HEAD * out


static func _bump(value: float, at: float, wide: float) -> float:
	var off := absf(value - at) / wide
	return 0.0 if off >= 1.0 else (1.0 - off * off) * (1.0 - off * off)


static func _curve(points: Array, at: float) -> float:
	for i in points.size() - 1:
		var a: Vector2 = points[i]
		var b: Vector2 = points[i + 1]
		if at >= a.x and at <= b.x:
			return lerpf(a.y, b.y, (at - a.x) / (b.x - a.x))
	return 0.0


static func _king(into: Carver, middle: Vector3, eyes: Array, wear: float) -> void:
	const ACROSS: Array[float] = [-125.0, -100.0, -78.0, -60.0, -46.0, -35.0, -26.0, -18.0, -12.0, -8.0, -4.0, 0.0, 4.0, 8.0, 12.0, 18.0, 26.0, 35.0, 46.0, 60.0, 78.0, 100.0, 125.0]
	const UP: Array[float] = [40.0, 30.0, 24.0, 19.0, 15.0, 11.0, 7.0, 3.0, -3.0, -6.5, -10.0, -14.0, -17.5, -20.5, -23.5, -28.0, -34.0, -40.0, -48.0, -58.0, -72.0]
	var nose := 1.0 - smoothstep(0.55, 0.65, wear)
	var rows: Array[PackedVector3Array] = []
	for up in UP:
		var row := PackedVector3Array()
		for across in ACROSS:
			row.append(_face(middle, across, up, nose))
		rows.append(row)
	for k in rows.size() - 1:
		for i in ACROSS.size() - 1:
			# (where the nose was, the stone is broken and dark)
			var scar := nose < 0.5 and absf(ACROSS[i] + ACROSS[i + 1]) < 9.0 and UP[k] <= 7.0 and UP[k + 1] >= -10.0
			into.quad_from(rows[k][i], rows[k][i + 1], rows[k + 1][i + 1], rows[k + 1][i], SHADE if scar else SKIN, 0 if scar else 7, middle)
	for side: float in [-1.0, 1.0]:
		# The eye, the line of paint round it and out towards the temple, and the brow over it.
		var facing := (_face(middle, side * 24.0, 11.0, nose) - middle) / Vector3(0.4 * 0.4, 0.52 * 0.52, 0.42 * 0.42)
		facing = facing.normalized()
		var at := _face(middle, side * 24.0, 11.0, nose, 0.035)
		eyes.append([at + facing * 0.012 * HEAD, facing, 0.085 * HEAD, 0.04 * HEAD, 0.012 * HEAD])
		var socket := PackedVector3Array()
		var across := Vector3.UP.cross(facing).normalized()
		var up := facing.cross(across).normalized()
		for i in 12:
			var angle := TAU * i / 12.0
			var wide := cos(angle)
			var high := sin(angle) * (1.0 - 0.4 * wide * wide)
			socket.append(at + (across * wide * 0.118 + up * (high * 0.064 + wide * side * 0.014)) * HEAD)
		for i in 12:
			into.tri(at, socket[i], socket[(i + 1) % 12], KOHL, 0, facing)
		into.quad(_face(middle, side * 33.0, 12.4, nose, 0.03), _face(middle, side * 52.0, 14.5, nose, 0.03), _face(middle, side * 52.0, 11.5, nose, 0.03),
				_face(middle, side * 33.0, 9.6, nose, 0.03), KOHL, 0, facing)
		for i in 4:
			var a := side * lerpf(9.0, 50.0, i / 4.0)
			var b := side * lerpf(9.0, 50.0, (i + 1) / 4.0)
			into.quad(_face(middle, a, 26.5, nose, 0.03), _face(middle, b, 26.5 - (1.5 if i == 3 else 0.0), nose, 0.03), _face(middle, b, 22.5 - (1.5 if i == 3 else 0.0), nose, 0.03),
					_face(middle, a, 22.5, nose, 0.03), KOHL, 0, facing)
		# The ear, standing out in front of the cloth.
		var root := middle + Vector3(side * 0.38, 0.03, 0.03) * HEAD
		var edge := PackedVector3Array()
		for i in 6:
			var angle := lerpf(-PI * 0.5, PI * 0.5, i / 5.0)
			edge.append(root + Vector3(side * 0.17 * cos(angle), 0.17 * sin(angle), 0.09 * cos(angle)) * HEAD)
		for i in 5:
			into.tri(root, edge[i], edge[i + 1], SKIN, 0, Vector3(side * 0.4, 0.0, 1.0))
			into.tri(root, edge[i], edge[i + 1], SKIN, 0, Vector3(-side * 0.4, 0.0, -1.0))
	# The false beard, strapped under the chin: the first thing to break off.
	if wear < 0.5:
		var chin := middle + Vector3(0.0, -0.5, 0.27) * HEAD
		var tip := chin + Vector3(0.0, -0.36, 0.0) * HEAD
		var rings: Array[PackedVector3Array] = []
		for end: Array in [[chin, 0.075, 0.06], [tip, 0.1, 0.075]]:
			var ring := PackedVector3Array()
			for corner: Vector2 in [Vector2(-1, -1), Vector2(1, -1), Vector2(1, 1), Vector2(-1, 1), Vector2(-1, -1)]:
				ring.append((end[0] as Vector3) + Vector3(corner.x * float(end[1]), 0.0, corner.y * float(end[2])) * HEAD)
			rings.append(ring)
		into.band(rings[0], rings[1], SHADE, 0)
		into.quad(rings[1][0], rings[1][1], rings[1][2], rings[1][3], SHADE, 0, Vector3.DOWN)
	_headcloth(into, middle, 0.95, true, wear < 0.38)


# The headcloth: a cap over the skull, a band across the brow, and the cloth falling from it behind the ears to a wing
# at each shoulder, with a lappet hanging from each wing down the chest. Striped. `flare` is how far the wings stand
# out (the king's nemes stands out wide; a god's wig hangs close).
static func _headcloth(into: Carver, middle: Vector3, flare: float, band: bool, cobra: bool) -> void:
	const STRIPES: Array[int] = [SHADE, LIGHT]
	var brow := middle.y + 0.27 * HEAD
	var crown := middle.y + 0.57 * HEAD
	var hem := middle.y - 0.72 * HEAD
	var hub := Vector3(0.0, 0.0, middle.z - 0.05 * HEAD)
	# The cap: rings from the brow up to the crown.
	const ROUND := 16
	var rings: Array[PackedVector3Array] = []
	for k in 5:
		var up := PI * 0.5 * k / 4.0
		var ring := PackedVector3Array()
		for i in ROUND + 1:
			var angle := TAU * i / ROUND
			var out := pow(cos(up), 0.72)
			ring.append(Vector3(sin(angle) * 0.43 * HEAD * out, lerpf(brow, crown, sin(up)), hub.z + cos(angle) * 0.45 * HEAD * out))
		rings.append(ring)
	for k in 4:
		into.band(rings[k], rings[k + 1], STRIPES[k % 2], 8)
	if band:
		# The band across the brow, from ear to ear.
		var low := PackedVector3Array()
		var high := PackedVector3Array()
		for i in 9:
			var angle := lerpf(-PI * 0.5, PI * 0.5, i / 8.0)
			var out := Vector3(sin(angle) * 0.44 * HEAD, 0.0, cos(angle) * 0.46 * HEAD)
			high.append(Vector3(out.x, brow + 0.012 * HEAD, hub.z + out.z))
			low.append(Vector3(out.x * 0.99, brow - 0.075 * HEAD, hub.z + out.z * 0.985))
		for i in 8:
			into.quad_from(high[i], high[i + 1], low[i + 1], low[i], LIGHT, 9, Vector3(0.0, brow, hub.z))
	if cobra:
		# The cobra reared at the brow: its hood, and its body lying back over the cap.
		var foot := Vector3(0.0, brow - 0.03 * HEAD, hub.z + 0.47 * HEAD)
		var hood: Array[Vector3] = [foot, foot + Vector3(-0.07, 0.11, 0.035) * HEAD, foot + Vector3(0.0, 0.2, 0.06) * HEAD, foot + Vector3(0.07, 0.11, 0.035) * HEAD]
		var back := foot + Vector3(0.0, 0.09, -0.02) * HEAD
		for i in 4:
			into.tri_from(hood[i], hood[(i + 1) % 4], foot + Vector3(0.0, 0.11, 0.075) * HEAD, LIGHT, 0, back)
			into.tri_from(hood[i], hood[(i + 1) % 4], back, LIGHT, 0, foot + Vector3(0.0, 0.11, 0.075) * HEAD)
	# The cloth behind: from the brow down to the hem, round the back from one side to the other.
	const DOWN := 9
	const BACK := 8
	var falls: Array[PackedVector3Array] = []
	var inner: Array[Vector3] = []
	for k in DOWN + 1:
		var t := float(k) / DOWN
		var y := lerpf(brow, hem, t)
		var wide := lerpf(0.43, flare, pow(t, 0.9)) * HEAD
		var deep := lerpf(0.45, 0.58, t) * HEAD
		var ring := PackedVector3Array()
		for i in BACK + 1:
			var angle := lerpf(-PI * 0.5, PI * 0.5, float(i) / BACK)
			ring.append(Vector3(sin(angle) * wide, y, hub.z - cos(angle) * deep))
		falls.append(ring)
		# (and where the front of each wing meets the side of the face)
		inner.append(Vector3(lerpf(0.3, 0.18, t) * HEAD, y, middle.z - 0.03 * HEAD))
	for k in DOWN:
		var stripe := STRIPES[k % 2]
		into.band(falls[k], falls[k + 1], stripe, 10)
		# The front of each wing: flat, facing forward, between the face and the edge of the cloth.
		for side: float in [-1.0, 1.0]:
			var edge := 0 if side < 0.0 else BACK
			var a := Vector3(inner[k].x * side, inner[k].y, inner[k].z)
			var b := Vector3(inner[k + 1].x * side, inner[k + 1].y, inner[k + 1].z)
			into.quad(a, falls[k][edge], falls[k + 1][edge], b, stripe, 0, Vector3.BACK)
	# Under the hem, closed.
	for i in BACK:
		into.tri(falls[DOWN][i], falls[DOWN][i + 1], Vector3(0.0, hem, hub.z), KOHL, 0, Vector3.DOWN)
	# The lappets: a striped tongue of cloth from each wing down onto the chest.
	var end := middle.y - HEAD_AT.y + 0.185
	var front := CHEST + 0.02
	for side: float in [-1.0, 1.0]:
		const ROWS := 5
		for k in ROWS:
			var t0 := float(k) / ROWS
			var t1 := float(k + 1) / ROWS
			var y0 := lerpf(hem, end, t0)
			var y1 := lerpf(hem, end, t1)
			var in0 := lerpf(0.2, 0.22, t0) * HEAD
			var in1 := lerpf(0.2, 0.22, t1) * HEAD
			var out0 := lerpf(minf(0.6, flare * 0.66), 0.5, t0) * HEAD
			var out1 := lerpf(minf(0.6, flare * 0.66), 0.5, t1) * HEAD
			var stripe := STRIPES[(k + 1) % 2]
			into.quad(Vector3(side * in0, y0, front), Vector3(side * out0, y0, front), Vector3(side * out1, y1, front), Vector3(side * in1, y1, front), stripe, 0, Vector3.BACK)
			into.quad(Vector3(side * out0, y0, front), Vector3(side * out0, y0, CHEST - 0.01), Vector3(side * out1, y1, CHEST - 0.01), Vector3(side * out1, y1, front), stripe, 0, Vector3(side, 0.0, 0.0))
			into.quad(Vector3(side * in0, y0, front), Vector3(side * in0, y0, CHEST - 0.01), Vector3(side * in1, y1, CHEST - 0.01), Vector3(side * in1, y1, front), stripe, 0, Vector3(-side, 0.0, 0.0))
		var low_in := 0.22 * HEAD
		var low_out := 0.5 * HEAD
		into.quad(Vector3(side * low_in, end, front), Vector3(side * low_out, end, front), Vector3(side * low_out, end, CHEST - 0.01), Vector3(side * low_in, end, CHEST - 0.01), KOHL, 0, Vector3.DOWN)
		var top_out := minf(0.6, flare * 0.66) * HEAD
		into.quad(Vector3(side * 0.2 * HEAD, hem, front), Vector3(side * top_out, hem, front), Vector3(side * top_out, hem, middle.z), Vector3(side * 0.2 * HEAD, hem, middle.z), STRIPES[1], 0, Vector3.UP)
	# The tail of the cloth, bound and lying down the back.
	var queue: Array[Vector3] = [Vector3(0.0, hem + 0.1 * HEAD, hub.z - 0.5 * HEAD), Vector3(0.0, hem - 0.25 * HEAD, hub.z - 0.62 * HEAD), Vector3(0.0, hem - 0.5 * HEAD, hub.z - 0.95 * HEAD)]
	var girth: Array[float] = [0.16 * HEAD, 0.12 * HEAD, 0.07 * HEAD]
	into.tube(queue, girth, 6, [SHADE], 11)


# --- The ram

static func _ram(into: Carver, middle: Vector3, eyes: Array) -> void:
	var skull := middle + Vector3(0.0, 0.0, -0.005)
	# Its head runs forward and down from the skull to the muzzle.
	var along := Vector3(0.0, -0.42, 0.91).normalized()
	var over := Vector3(0.0, 0.91, 0.42).normalized()
	var rings: Array[PackedVector3Array] = []
	var ends: Array[Vector3] = []
	for ring: Array in [[-0.066, 0.02, 0.022, 0.0], [-0.05, 0.046, 0.05, 0.0], [-0.01, 0.06, 0.066, 0.0], [0.035, 0.055, 0.058, 0.004], [0.075, 0.04, 0.043, 0.007],
			[0.105, 0.032, 0.035, 0.006], [0.126, 0.028, 0.029, 0.002], [0.137, 0.017, 0.016, -0.002]]:
		var at := skull + along * float(ring[0]) + over * float(ring[3])
		var points := PackedVector3Array()
		for i in 11:
			var angle := TAU * i / 10.0
			points.append(at + Vector3(sin(angle) * float(ring[1]), 0.0, 0.0) + over * cos(angle) * float(ring[2]))
		rings.append(points)
		ends.append(at)
	for k in rings.size() - 1:
		into.band(rings[k], rings[k + 1], STONE, 12)
	into.cap(rings[rings.size() - 1], KOHL, along)
	into.cap(rings[0], STONE, -along)
	# The line of its mouth, and its nostrils.
	for side: float in [-1.0, 1.0]:
		var a := ends[5] + Vector3(side * 0.0335, 0.0, 0.0) - over * 0.012
		var b := ends[6] + Vector3(side * 0.0295, 0.0, 0.0) - over * 0.011
		var c := ends[7] + Vector3(side * 0.017, 0.0, 0.0) - over * 0.007
		into.quad(a - over * 0.004, a + over * 0.003, b + over * 0.003, b - over * 0.004, KOHL, 0, Vector3(side, 0.0, 0.2))
		into.quad(b - over * 0.004, b + over * 0.003, c + over * 0.003, c - over * 0.004, KOHL, 0, Vector3(side, 0.0, 0.6))
		# A horn: from the top of the skull back, down, forward under the ear and up again, drawing in and thinning as it goes.
		var line: Array[Vector3] = []
		var girth: Array[float] = []
		const TURNS := 17
		for k in TURNS:
			var f := float(k) / (TURNS - 1)
			var round := deg_to_rad(lerpf(-15.0, 335.0, f))
			var reach := lerpf(0.064, 0.036, f)
			line.append(skull + Vector3(side * (0.05 + 0.07 * f), -0.014 + reach * cos(round), -0.012 - reach * sin(round)))
			girth.append(lerpf(0.034, 0.006, pow(f, 1.25)))
		into.tube(line, girth, 6, [LIGHT, HORN], 13 if side < 0.0 else 14)
		# An ear, in the curl of the horn.
		var root := skull + Vector3(side * 0.05, -0.004, -0.02)
		var tip := root + Vector3(side * 0.05, -0.03, -0.004)
		for way: float in [-1.0, 1.0]:
			into.tri(root + Vector3(0.0, 0.014, 0.0), root + Vector3(0.0, -0.014, 0.01), tip, STONE, 0, Vector3(0.0, 0.3, 1.0) * way)
		var facing := Vector3(side * 0.72, 0.22, 0.66).normalized()
		var at := skull + along * 0.035 + over * 0.034 + Vector3(side * 0.043, 0.0, 0.0)
		eyes.append([at + facing * 0.008, facing, 0.017, 0.011, 0.0])


# --- The falcon

static func _falcon(into: Carver, middle: Vector3, eyes: Array, wear: float) -> void:
	var skull := middle + Vector3(0.0, -0.004, 0.034)
	var size := Vector3(0.06, 0.066, 0.068)
	# The skull: a ball, a little flat on top.
	var rings: Array[PackedVector3Array] = []
	for k in 9:
		var up := lerpf(-PI * 0.5, PI * 0.5, k / 8.0)
		var ring := PackedVector3Array()
		for i in 13:
			var angle := TAU * i / 12.0
			ring.append(skull + Vector3(sin(angle) * cos(up) * size.x, sin(up) * size.y * (0.92 if up > 0.0 else 1.0), cos(angle) * cos(up) * size.z))
		rings.append(ring)
	for k in 8:
		into.band(rings[k], rings[k + 1], STONE, 15)
	# The beak: out from the face, and hooked down to a point.
	var line: Array[Vector3] = [skull + Vector3(0.0, 0.002, 0.045), skull + Vector3(0.0, -0.004, 0.076), skull + Vector3(0.0, -0.016, 0.094), skull + Vector3(0.0, -0.034, 0.099),
			skull + Vector3(0.0, -0.05, 0.092)]
	var girth: Array[float] = [0.033, 0.026, 0.02, 0.011, 0.002]
	if wear > 0.7:
		# (the tip of it broken off)
		line.resize(3)
		girth.resize(3)
	into.tube(line, girth, 7, [HORN], 16)
	for side: float in [-1.0, 1.0]:
		var facing := Vector3(side * 0.56, 0.08, 0.82).normalized()
		var at := skull + Vector3(facing.x * size.x, facing.y * size.y, facing.z * size.z) * 1.03
		var across := Vector3.UP.cross(facing).normalized()
		var up := facing.cross(across).normalized()
		eyes.append([at + facing * 0.006, facing, 0.019, 0.0165, 0.0])
		# The ring round a falcon's eye, the brow jutting over it, and the mark that runs down its cheek.
		var ring := PackedVector3Array()
		for i in 10:
			var angle := TAU * i / 10.0
			ring.append(at + (across * cos(angle) * 0.026 + up * sin(angle) * 0.023))
		for i in 10:
			into.tri(at, ring[i], ring[(i + 1) % 10], KOHL, 0, facing)
		var from := at - up * 0.02 + across * side * 0.004
		var mid := skull + Vector3(side * 0.05, -0.04, 0.036) * 1.03
		var end := skull + Vector3(side * 0.052, -0.052, 0.012) * 1.03
		into.quad(from - across * 0.007, from + across * 0.007, mid + across * 0.006, mid - across * 0.006, KOHL, 0, facing)
		into.quad(mid + Vector3(0.0, 0.0, 0.007), mid - Vector3(0.0, 0.0, 0.007), end - Vector3(0.0, 0.0, 0.006), end + Vector3(0.0, 0.0, 0.006), KOHL, 0, Vector3(side, -0.2, 0.3))
