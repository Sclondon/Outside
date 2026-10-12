class_name RockModels
## The desert's rock that has a fixed shape, as it was modelled: the formations
## of the White Desert, loose stones, the tomb doorway and the dig round it,
## the peak el-Qurn and the far hills. They are all in one file,
## `models/rocks/rocks.glb`, made by `tools/build_rocks.py` (which also saves
## `tools/rocks.blend`, to look at them and change them in Blender), and are
## known by the names of their objects there.
##
##     var mesh := RockModels.mesh("dome_b")
##     var solid := RockModels.hulls("dome_b")        # each a set of points to put a hull round
##     var all := RockModels.variants("dome")         # ["dome_a", "dome_b", ...]
##
## A mesh is as it was modelled, whatever its object's place or size in the
## .blend. The names of its materials say what each surface is to be drawn
## with (`rock`, `sand`, `dressed`, `dark`, `wood`); `Rock.Builder.add` goes by
## them. What is solid of a thing is the objects named after it with `_hull1`,
## `_hull2`... on the end.

const FILE := "res://models/rocks/rocks.glb"

static var _meshes := {}
static var _hulls := {}
static var _read := false


## The mesh of a thing, or null if there is none of that name.
static func mesh(name: String) -> ArrayMesh:
	_load()
	return _meshes.get(name)


## What is solid of a thing: each a set of points, in the mesh's own space.
static func hulls(name: String) -> Array:
	_load()
	return _hulls.get(name, [])


## The things of a kind: every one named `kind` with `_a`, `_b`... after it, in order.
static func variants(kind: String) -> Array[String]:
	_load()
	var found: Array[String] = []
	for name: String in _meshes:
		if name.begins_with(kind + "_") and name.length() == kind.length() + 2:
			found.append(name)
	found.sort()
	return found


## One of a kind, chosen by a number: the same one every time for the same number.
static func pick(kind: String, seed: int) -> String:
	var all := variants(kind)
	return all[posmod(seed, all.size())] if not all.is_empty() else ""


static func _load() -> void:
	if _read:
		return
	_read = true
	var packed := load(FILE) as PackedScene
	if packed == null:
		push_error("RockModels: %s is missing. Make it with tools/build_rocks.py and import it." % FILE)
		return
	var scene := packed.instantiate()
	for found: MeshInstance3D in scene.find_children("*", "MeshInstance3D", true, false):
		var name := String(found.name)
		var at := name.find("_hull")
		if at < 0:
			_meshes[name] = found.mesh
			continue
		var points := PackedVector3Array()
		for surface in found.mesh.get_surface_count():
			for point: Vector3 in found.mesh.surface_get_arrays(surface)[Mesh.ARRAY_VERTEX]:
				if not points.has(point):
					points.append(point)
		var of := name.substr(0, at)
		if not _hulls.has(of):
			_hulls[of] = []
		(_hulls[of] as Array).append([name, points])
	scene.free()
	# (in the order of their names: `_hull1` first)
	for of: String in _hulls:
		var named: Array = _hulls[of]
		named.sort_custom(func(a: Array, b: Array) -> bool: return String(a[0]).naturalnocasecmp_to(String(b[0])) < 0)
		_hulls[of] = named.map(func(entry: Array) -> PackedVector3Array: return entry[1])
