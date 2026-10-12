class_name SphinxMesh
## The stone of a `Sphinx`: a lion lying on a low base, forelegs out in front,
## hind legs folded, the tail brought round the right haunch; and on its
## shoulders a king's head in the striped headcloth (the nemes, with the cobra
## at the brow and the false beard), a ram's with its curled horns, or a
## falcon's in a long wig.
##
## The model is `models/sphinx.glb`, built in Blender by
## `tools/build_sphinx.py` (which also keeps `tools/sphinx.blend`, to look at
## and change by hand). It is one metre long, facing +Z, lying on the ground,
## and has no bones: it is separate things, each named for what it is (`base`,
## `body`, `foreleg`, `king_head`, `king_face`, `king_eye_l`, `ram_head`,
## `falcon_beak`, `slab`, `stele`... the list is at the top of the build
## script), and a thing that turns has its origin where it is hinged.
##
## `carve` puts together the things one sphinx wants and makes them `size`
## times bigger: the body (with the left foreleg, which is the right one turned
## over), the right foreleg (which a `Sphinx` moves), the head (which it
## turns), and the two eyes (which it opens and lights). The size is put into
## the meshes, not onto the nodes, because the stone is drawn by a shader that
## works in metres (`Sandstone`). What `wear` does is done here too: every
## point is moved a little, and the pieces that break off are left out.
##
## The model's materials say what each part is. Bare, all of them are one
## surface of stone, lighter or darker (`TONE`); painted, each that is a paint
## is a surface of its own in the colour the model gives it.
##
## What is solid is not in the model: it is worked out from the numbers below,
## which the model was built round.

## The heads, in the order of `Sphinx.Head`.
enum { KING, RAM, FALCON }

const MODEL := "res://models/sphinx.glb"
## What the things of each head are called in the model.
const HEADS: Array[String] = ["king", "ram", "falcon"]
## How light the stone of each material is when it is bare.
const TONE := {"stone": 1.0, "lapis": 0.74, "ochre": 1.05, "skin": 1.0, "kohl": 0.56, "hollow": 0.3, "horn": 0.76, "broken": 0.74}
## The materials that are stone even on a painted sphinx.
const UNPAINTED: Array[String] = ["stone", "hollow", "broken"]
## How thick the base is in the model, and how tall the slab and how thick the stele.
const BASE_DEEP := 0.1
const SLAB_TALL := 0.03
const STELE_THICK := 0.02

## Half the width of the way between the forelegs, and of a foreleg; and how far out the middle of a foreleg is.
const GAP := 0.065
const PAW := 0.045
const PAW_OUT := 0.11
## Half the width of the base, and how far it runs fore and aft of the middle.
const BASE := Vector2(0.235, 0.53)
## The body from rump to chest: where along it, half its width, its height.
const BODY: Array[Vector3] = [Vector3(-0.47, 0.105, 0.2), Vector3(-0.445, 0.135, 0.235), Vector3(-0.36, 0.15, 0.25), Vector3(-0.25, 0.145, 0.245),
		Vector3(-0.14, 0.125, 0.235), Vector3(-0.03, 0.13, 0.25), Vector3(0.05, 0.15, 0.28), Vector3(0.1, 0.152, 0.305), Vector3(0.13, 0.145, 0.31)]
## How far out a hind paw lies.
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
## Where the offering slab lies between the forelegs (its middle along the sphinx), and half its size across and along.
const SLAB := 0.33
const SLAB_HALF := Vector2(0.05, 0.06)

# The things of the model, by name: [its mesh, where it is].
static var _things := {}
# What has been carved and is still in use, by what was asked for.
static var _carved := {}


## What `carve` gives back. A sphinx keeps hold of it; another that is the same shares it.
class Carved extends RefCounted:
	## The mesh of everything that does not move.
	var body: ArrayMesh
	## The right foreleg, about `paw_at` (its elbow, on the base).
	var paw: ArrayMesh
	var paw_at := Vector3.ZERO
	## The head, about `head_at` (its neck).
	var head: ArrayMesh
	var head_at := Vector3.ZERO
	## For each eye: [where it is from the neck, which way it faces (a Basis), its mesh].
	var eyes: Array = []
	## What is solid: [a shape, where it is].
	var solids: Array = []
	## How thick the base is, metres.
	var foot := 0.1


## How thick the base is for a sphinx of a size, in metres: low enough to walk onto.
static func base_height(size: float) -> float:
	return clampf(size * 0.05, 0.1, 0.22)


## Faces of the model as they are gathered, by the material they are in, before they are a mesh.
class Gathered:
	var at := {}
	var facing := {}
	var order := {}
	## The colour the model gives each material.
	var paint := {}

	## Takes in a thing of the model, where the model has it, lifted onto a base `foot` thick. `mirrored` is turned over, left for right.
	## The base itself (`is_base`) is made as thick as `foot`.
	func take(which: String, foot: float, mirrored := false, is_base := false) -> void:
		var thing: Array = SphinxMesh.thing(which)
		if thing.is_empty():
			return
		var mesh: Mesh = thing[0]
		var place: Transform3D = thing[1]
		for surface in mesh.get_surface_count():
			var material := mesh.surface_get_material(surface) as BaseMaterial3D
			var label := material.resource_name if material else "stone"
			if not at.has(label):
				at[label] = PackedVector3Array()
				facing[label] = PackedVector3Array()
				order[label] = PackedInt32Array()
				paint[label] = material.albedo_color if material else Color.WHITE
			var arrays := mesh.surface_get_arrays(surface)
			var points: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
			var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
			var first: int = (at[label] as PackedVector3Array).size()
			for i in points.size():
				var point := place * points[i]
				var normal := (place.basis * normals[i]).normalized()
				if mirrored:
					point.x = -point.x
					normal.x = -normal.x
				if is_base:
					point.y = foot + point.y * (foot + 0.04) / BASE_DEEP
				else:
					point.y += foot
				at[label].append(point)
				facing[label].append(normal)
			var corners := PackedInt32Array()
			if arrays[Mesh.ARRAY_INDEX] != null:
				corners = arrays[Mesh.ARRAY_INDEX]
			else:
				corners = PackedInt32Array(range(points.size()))
			for i in range(0, corners.size() - 2, 3):
				order[label].append(first + corners[i])
				order[label].append(first + corners[i + (2 if mirrored else 1)])
				order[label].append(first + corners[i + (1 if mirrored else 2)])

	## Makes a mesh of it: `size` times bigger, about `origin`, worn by `wear`.
	## Bare, it is one surface of `stone`; `painted`, each material that is a paint is a surface of its own, faded towards `colour` by `fade`.
	func mesh(size: float, origin: Vector3, wear: float, stone: Material, laid: float, painted: bool, colour: Color, fade: float) -> ArrayMesh:
		var made := ArrayMesh.new()
		var placed := {}
		var faced := facing
		if wear > 0.0:
			# Worn: every point is moved a little, and the skin is turned to face the way it then lies (rounded where it was
			# rounded, and edged where it had an edge).
			var sums := {}
			faced = {}
			for label: String in at:
				var from: PackedVector3Array = at[label]
				var points := PackedVector3Array()
				points.resize(from.size())
				for i in from.size():
					points[i] = SphinxMesh.worn(from[i], wear * 0.004)
				placed[label] = points
				var corners: PackedInt32Array = order[label]
				for i in range(0, corners.size(), 3):
					var face := (points[corners[i + 1]] - points[corners[i]]).cross(points[corners[i + 2]] - points[corners[i]])
					for j in 3:
						var key := SphinxMesh.key_of(from[corners[i + j]], facing[label][corners[i + j]])
						sums[key] = (sums.get(key, Vector3.ZERO) as Vector3) + face
			for label: String in at:
				var normals := PackedVector3Array()
				normals.resize((at[label] as PackedVector3Array).size())
				for i in normals.size():
					var sum: Vector3 = sums.get(SphinxMesh.key_of(at[label][i], facing[label][i]), Vector3.ZERO)
					# (Godot's front is clockwise: a face's own way is the other way from the cross of its sides)
					normals[i] = -sum.normalized() if sum.length_squared() > 1e-20 else (facing[label][i] as Vector3)
				faced[label] = normals
		else:
			placed = at
		# The surfaces: bare, one of stone that has everything in it; painted, the stone, and one for each paint.
		var of_stone: Array = []
		var of_paint: Array = []
		for label: String in at:
			if painted and not UNPAINTED.has(label):
				of_paint.append(label)
			else:
				of_stone.append(label)
		var surfaces: Array = [[of_stone, stone]]
		for label: String in of_paint:
			surfaces.append([[label], Toon.surface((paint[label] as Color).lerp(colour, fade))])
		for surface: Array in surfaces:
			var points := PackedVector3Array()
			var normals := PackedVector3Array()
			var colours := PackedColorArray()
			var corners := PackedInt32Array()
			for label: String in surface[0]:
				var first := points.size()
				for point: Vector3 in placed[label]:
					points.append((point - origin) * size)
				normals.append_array(faced[label])
				if surface[1] == stone:
					var tone := Color(TONE.get(label, 1.0), laid, 1.0)
					for i in (placed[label] as PackedVector3Array).size():
						colours.append(tone)
				for corner: int in order[label]:
					corners.append(first + corner)
			if corners.is_empty():
				continue
			var arrays := []
			arrays.resize(Mesh.ARRAY_MAX)
			arrays[Mesh.ARRAY_VERTEX] = points
			arrays[Mesh.ARRAY_NORMAL] = normals
			arrays[Mesh.ARRAY_INDEX] = corners
			if not colours.is_empty():
				arrays[Mesh.ARRAY_COLOR] = colours
			made.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
			made.surface_set_material(made.get_surface_count() - 1, surface[1])
		return made


## A thing of the model, by its name: [its mesh, where it is (a Transform3D)]. Read from the model once.
static func thing(which: String) -> Array:
	if _things.is_empty():
		var model := (load(MODEL) as PackedScene).instantiate()
		for found: Node in model.find_children("*", "MeshInstance3D", true, false):
			var part := found as MeshInstance3D
			_things[String(part.name)] = [part.mesh, part.transform]
		model.free()
	if not _things.has(which):
		push_error("The sphinx's model has nothing in it called %s" % which)
		return []
	return _things[which]


## A thing of the model as a mesh of its own, made bigger by `by` (which need not be the same each way), about its own origin.
## `materials` is what to draw each of its materials with, by name.
static func piece(which: String, by: Vector3, materials: Dictionary) -> ArrayMesh:
	var made := ArrayMesh.new()
	var found := thing(which)
	if found.is_empty():
		return made
	var mesh: Mesh = found[0]
	for surface in mesh.get_surface_count():
		var arrays := mesh.surface_get_arrays(surface)
		var points: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
		for i in points.size():
			points[i] *= by
			normals[i] = (normals[i] / by).normalized()
		var kept := []
		kept.resize(Mesh.ARRAY_MAX)
		kept[Mesh.ARRAY_VERTEX] = points
		kept[Mesh.ARRAY_NORMAL] = normals
		kept[Mesh.ARRAY_INDEX] = arrays[Mesh.ARRAY_INDEX]
		made.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, kept)
		var material := mesh.surface_get_material(surface)
		made.surface_set_material(surface, materials.get(material.resource_name if material else "", material))
	return made


static func key_of(point: Vector3, normal: Vector3) -> Vector4i:
	return Vector4i(roundi(point.x * 8192.0), roundi(point.y * 8192.0), roundi(point.z * 8192.0),
			(roundi(normal.x * 24.0) + 32) | ((roundi(normal.y * 24.0) + 32) << 7) | ((roundi(normal.z * 24.0) + 32) << 14))


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


## Carves a sphinx: see `Carved`. Two that are the same in every way are one carving.
static func carve(size: float, head: int, wear: float, painted: bool, colour: Color, opens: bool) -> Carved:
	var asked := [size, head, wear, painted, colour, opens, Settings.world_banded]
	var kept := _carved.get(asked) as WeakRef
	if kept and kept.get_ref():
		return kept.get_ref()
	for key: Array in _carved.keys():
		if (_carved[key] as WeakRef).get_ref() == null:
			_carved.erase(key)
	var made := Carved.new()
	_carved[asked] = weakref(made)
	var foot := base_height(size) / size
	made.foot = foot * size
	var stone := Sandstone.surface(colour, clampf(size * 0.11, 0.5, 1.5), clampf(size * 0.19, 0.8, 2.6), lerpf(0.15, 1.0, wear), lerpf(0.1, 0.9, wear))
	# A great one is built of blocks, as the paws of the one at Giza are; a small one is one stone.
	var laid := 1.0 if size >= 9.0 else 0.0
	var fade := wear * 0.55
	made.solids = _solids(size, foot, opens)

	var body := Gathered.new()
	body.take("base", foot, false, true)
	body.take("body", foot)
	body.take("foreleg", foot, true)
	if opens:
		body.take("passage_frames", foot)
	else:
		body.take("chest_plug", foot)
		body.take("rump_plug", foot)
	made.body = body.mesh(size, Vector3.ZERO, wear, stone, laid, painted, colour, fade)

	var paw := Gathered.new()
	paw.take("foreleg", foot)
	var paw_at := Vector3(PAW_OUT, foot, 0.0)
	var leg := thing("foreleg")
	if not leg.is_empty():
		paw_at = (leg[1] as Transform3D).origin + Vector3(0.0, foot, 0.0)
	made.paw = paw.mesh(size, paw_at, wear, stone, laid, painted, colour, fade)
	made.paw_at = paw_at * size

	# The head, less whatever of it has broken off: the cobra first, then the beard, then the nose (or the tip of the beak).
	var whose := HEADS[clampi(head, 0, HEADS.size() - 1)]
	var top := Gathered.new()
	top.take(whose + "_head", foot)
	match head:
		KING:
			top.take("king_face" if wear <= 0.6 else "king_face_worn", foot)
			if wear < 0.38:
				top.take("king_uraeus", foot)
			if wear < 0.5:
				top.take("king_beard", foot)
		FALCON:
			top.take("falcon_beak" if wear <= 0.7 else "falcon_beak_broken", foot)
	var head_at := Vector3(0.0, 0.3 + foot, 0.08)
	var skull := thing(whose + "_head")
	if not skull.is_empty():
		head_at = (skull[1] as Transform3D).origin + Vector3(0.0, foot, 0.0)
	made.head = top.mesh(size, head_at, wear * 0.4, stone, 0.0, painted, colour, fade)
	made.head_at = head_at * size

	for side: String in ["_eye_l", "_eye_r"]:
		var eye := thing(whose + side)
		if eye.is_empty():
			continue
		var place: Transform3D = eye[1]
		made.eyes.append([(worn(place.origin + Vector3(0.0, foot, 0.0), wear * 0.4 * 0.004) - head_at) * size, place.basis.orthonormalized(),
				piece(whose + side, Vector3.ONE * size, {})])
	return made


static func _solid_box(low: Vector3, high: Vector3, size: float) -> Array:
	var shape := BoxShape3D.new()
	shape.size = (high - low).abs() * size
	return [shape, (low + high) * 0.5 * size]


# What is solid: the base, the body ring by ring (or only the roof and walls of the way through it, if it opens), the
# forelegs, the haunches and hind paws, and the head.
static func _solids(size: float, foot: float, opens: bool) -> Array:
	var solids: Array = []
	solids.append(_solid_box(Vector3(-BASE.x, -0.04, -BASE.y), Vector3(BASE.x, foot, BASE.y), size))
	for k in BODY.size() - 1:
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
	if opens:
		for side: float in [-1.0, 1.0]:
			solids.append(_solid_box(Vector3(side * WAY.x, foot, BODY[0].x), Vector3(side * 0.105, foot + WAY.y, CHEST), size))
	for side: float in [-1.0, 1.0]:
		solids.append(_solid_box(Vector3(side * PAW_OUT - PAW, foot, CHEST), Vector3(side * PAW_OUT + PAW, foot + 0.075, 0.5), size))
		solids.append(_solid_box(Vector3(side * PAW_OUT - PAW, foot, -0.02), Vector3(side * PAW_OUT + PAW, foot + 0.12, CHEST), size))
		# A haunch, and the hind paw lying forward along the flank.
		solids.append(_solid_box(Vector3(side * (HAUNCH.x - 0.05), foot, HAUNCH.z - 0.1), Vector3(side * (HAUNCH.x + HAUNCH_SIZE.x * 0.8), foot + HAUNCH_SIZE.y * 0.93, HAUNCH.z + 0.1), size))
		solids.append(_solid_box(Vector3(side * HIND_OUT - 0.032, foot, -0.3), Vector3(side * HIND_OUT + 0.032, foot + 0.05, -0.105), size))
	var middle := HEAD_AT + Vector3(0.0, foot, 0.0)
	solids.append(_solid_box(middle - Vector3(0.42, 0.62, 0.48) * HEAD, middle + Vector3(0.42, 0.56, 0.42) * HEAD, size))
	return solids
