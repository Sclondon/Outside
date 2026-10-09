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
## The dunes are `SandDunes` (crescents and ridges shaped by `wind`): see
## `dunes_at`. In the game the ground is drawn by a `SandGround` (the `ground`
## here), which takes footprints and follows the player with a fine mesh; it
## is given these heights and this node keeps the collider. In the editor,
## where only tool scripts run, it is drawn as plain pieces of mesh instead:
## the same shape, without the prints.

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
## The ground rises to this height at its edges, over `rim_width`, to close the
## level in. Beyond the edge a flat apron at that height runs to the horizon.
@export var rim_height := 9.0:
	set(value):
		rim_height = value
		queue_rebuild()
@export var rim_width := 45.0:
	set(value):
		rim_width = value
		queue_rebuild()
## How far in from the edge the wall nothing can see stands.
@export var wall_inset := 16.0
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
@export_tool_button("Rebuild") var _rebuild_button := rebuild

## In the game: what draws the ground (see `SandGround`). None in the editor.
var ground: Node3D

## How many squares a side each piece of the mesh is: what is behind the camera
## is then not drawn.
const CHUNK := 20
## Far pieces are drawn with one square for every FAR_STRIDE each way, and a skirt
## this deep round them.
const FAR_STRIDE := 4
const FAR_SKIRT := 2.5
const FAR_MARGIN := 12.0

# Each pad: [world-to-pad Transform3D, half size, round, ease, height]
var _pads: Array = []
var _dunes: SandDunes
var _made: Array[Node] = []
var _wait := -1.0


func _ready() -> void:
	add_to_group(&"terrain")
	rebuild()
	set_process(Engine.is_editor_hint())


func _process(delta: float) -> void:
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

## How high the ground stands at a place (in this node's own space).
func height_at(x: float, z: float) -> float:
	var height := _open_at(x, z)
	for pad: Array in _pads:
		height = _pressed(height, pad, x, z)
	return height


## Tells the ground where its pads are without it being in a scene: each is
## [the pad's transform, half size, round, ease]. For tools that lay a level out.
func use_pads(pads: Array) -> void:
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
	var scale := dune_height / 4.5
	var reach := size * 0.5 - rim_width * 0.5
	all.scatter(Rect2(-reach, -reach, reach * 2.0, reach * 2.0), int(size * size / 5200.0), Vector2(2.2, 7.5) * scale, Callable(), 0.25)
	var pads := _pads
	_dunes = all.without(func(bounds: Rect2) -> bool:
		for pad: Array in pads:
			var middle: Vector3 = (pad[0] as Transform3D).affine_inverse().origin
			var room: float = (pad[1] as Vector2).length() + pad[3] * 0.5
			if bounds.grow(room - minf(bounds.size.x, bounds.size.y) * 0.22).has_point(Vector2(middle.x, middle.z)):
				return true
		return false)


# Dunes and the rim, before any pad.
func _open_at(x: float, z: float) -> float:
	var rim := smoothstep(size * 0.5 - rim_width, size * 0.5, maxf(absf(x), absf(z)))
	return dunes_at(x, z) * (1.0 - rim * rim) + rim_height * rim


func _pressed(height: float, pad: Array, x: float, z: float) -> float:
	var local: Vector3 = (pad[0] as Transform3D) * Vector3(x, 0.0, z)
	var half: Vector2 = pad[1]
	var away: float
	if pad[2]:
		away = maxf(Vector2(local.x / half.x, local.z / half.y).length() - 1.0, 0.0) * minf(half.x, half.y)
	else:
		away = Vector2(maxf(absf(local.x) - half.x, 0.0), maxf(absf(local.z) - half.y, 0.0)).length()
	if away >= pad[3]:
		return height
	return lerpf(pad[4], height, smoothstep(0.0, pad[3], away))


func _gather_pads() -> void:
	if not is_inside_tree():
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

## Makes the ground again: mesh, collider, the wall round it and the apron.
func rebuild() -> void:
	_wait = -1.0
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
	var heights := PackedFloat32Array()
	heights.resize(side * side)
	for row in side:
		for column in side:
			heights[row * side + column] = _open_at(column * step - half, row * step - half)
	for pad: Array in _pads:
		var middle: Vector3 = (pad[0] as Transform3D).affine_inverse().origin
		var reach: float = (pad[1] as Vector2).length() + pad[3] + step
		for row in range(maxi(int((middle.z - reach + half) / step), 0), mini(int((middle.z + reach + half) / step) + 2, side)):
			for column in range(maxi(int((middle.x - reach + half) / step), 0), mini(int((middle.x + reach + half) / step) + 2, side)):
				heights[row * side + column] = _pressed(heights[row * side + column], pad, column * step - half, row * step - half)
	if Engine.is_editor_hint():
		var material := sand_material()
		for chunk_row in range(0, count, CHUNK):
			for chunk_column in range(0, count, CHUNK):
				_add_chunk(heights, side, step, chunk_column, chunk_row, mini(CHUNK, count - chunk_column), mini(CHUNK, count - chunk_row), material)
		_add_apron(material)
		return
	# In the game a `SandGround` draws it, from the same heights. (By name, and
	# untyped: it is not a tool script, and this one is.)
	ground = (load("res://scripts/sand_ground.gd") as GDScript).new()
	ground.set(&"half", Vector2(half, half))
	ground.set(&"cell", step)
	ground.set(&"solid", false)
	ground.set(&"apron", rim_height)
	# (dunes this gentle throw no shadows worth what drawing them again costs)
	ground.set(&"casts_shadow", false)
	_keep(ground)
	ground.call(&"build", heights)
	# Where a pad is the sand is trodden: harder, and it takes less of a print.
	for pad: Array in _pads:
		var middle: Vector3 = global_transform * (pad[0] as Transform3D).affine_inverse().origin
		var across: Vector2 = pad[1]
		ground.call(&"paint", Sand.Kind.PACKED, Vector2(middle.x, middle.z), minf(across.x, across.y) * 0.8, 0.55, 4.0)
	_add_collider(heights, side, step)


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


# Level ground from the edge to the horizon, so that the level does not end in air.
func _add_apron(material: Material) -> void:
	var half := size * 0.5
	var far := 2500.0
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
			faces[next] = a
			faces[next + 1] = b
			faces[next + 2] = c
			faces[next + 3] = a
			faces[next + 4] = c
			faces[next + 5] = d
			next += 6
	var shape := ConcavePolygonShape3D.new()
	shape.set_faces(faces)
	var collider := CollisionShape3D.new()
	collider.shape = shape
	_keep(collider)
	# A wall nothing can see, short of the edge.
	var edge := half - wall_inset
	for way: Vector3 in [Vector3(1, 0, 0), Vector3(-1, 0, 0), Vector3(0, 0, 1), Vector3(0, 0, -1)]:
		var along := Vector3(absf(way.z), 0.0, absf(way.x))
		var box := BoxShape3D.new()
		box.size = along * edge * 2.0 + (Vector3.ONE - along) * Vector3(1.0, 80.0, 1.0)
		var wall := CollisionShape3D.new()
		wall.shape = box
		wall.position = way * (edge + 0.5) + Vector3.UP * 30.0
		_keep(wall)
