class_name SandGround
extends StaticBody3D
## Sand to walk on: ground made from a height function, that takes the print
## of whatever presses into it.
##
##     var ground := SandGround.new()
##     ground.half = Vector2(128.0, 128.0)             # how far it runs each way from this node
##     ground.height = func(x: float, z: float) -> float: return dunes.height_at(x, z)
##     add_child(ground)                               # (it is made as it enters the scene)
##
## What it is made of:
## - A grid of heights, one every `cell` metres, asked of `height` once. The
##   collider is that grid and nothing finer. `height_at` reads it back.
## - A mesh that follows whoever is `focus` (the player, found by itself):
##   rings of squares, each ring twice as coarse as the one inside it, a few
##   centimetres across under his feet and metres across at the far dunes. It
##   takes its shape from the heights in its shader, so it costs nothing to
##   move, and it is one draw call.
## - Dents: a patch of fine squares round the focus, each remembering how far
##   it has been pressed down or heaped up. Boots, paws, bodies, rocks and
##   slides are stamped into it (`footprint`, `press`, ...); the shader pushes
##   the mesh down by it and lights its slopes. It softens and fills by itself,
##   slowly in still air and quickly in wind, and is forgotten beyond the patch.
## - Paint: damp sand, packed paths, coarse and pale patches (`paint`).
##
## And what it does for whoever walks on it. Every figure on a `CharacterRig`
## (the group "figures") is watched: on this ground its own dust is silenced
## and sand is thrown up from its feet instead (`spray`), each footfall leaves
## a boot print, a slide or a roll a trough, a sprawl the shape of a body;
## standing still it sinks a little; and on a steep face the sand under it
## gives way and runs downhill, and carries it a little. Hounds leave paw
## prints. Anything in the group "throwable" or "sand_denting" dents it where
## it lands and furrows it where it rolls.
##
## `cost_usec` is what a frame of all that takes here.

signal built

## The dents are kept as whole numbers: this one is "not pressed", and each
## step up or down from it is `UNIT` metres.
const NEUTRAL := 170
const UNIT := 0.0005
## Steeper than this, sand that is trodden on starts to run (a slope, as rise over run).
const RUNS_AT := 0.3

## How far it runs each way from this node, along x and along z, metres.
@export var half := Vector2(60.0, 60.0)
## How far apart its heights are, metres. The collider is this coarse.
@export var cell := 1.0
@export var colour := Sand.COLOUR
## Whether it can be stood on. (Off: it is only drawn, over a collider the level made itself.)
@export var solid := true
## How long a footprint takes to fill in still air, and in a storm, seconds.
@export var fill_seconds := Vector2(150.0, 9.0)
## How far a figure standing still sinks in, metres, and how long it takes.
@export var sink_depth := 0.04
@export var sink_time := 1.1
## How fast a steep face carries whoever is on it downhill, metres a second
## at the angle sand lies at. 0: not at all.
@export var slope_carry := 0.6
## How far the desert is drawn past the edge of the ground (nothing can be
## stood on there), and how high that plain lies above this node: left at
## INF, as high as the edge is on the whole.
@export var beyond := 160.0
@export var apron := INF
## Whether the dunes throw shadows (never on a phone: see `Sand.quality`).
@export var casts_shadow := true
## Turns `Sand.quality` down if frames are coming slowly.
@export var auto_quality := true

## How high the sand stands at (x, z), measured from this node: a function of
## two floats. Set it before the ground enters the scene, or call `build`.
var height: Callable
## What the fine part of the mesh and the dents follow. Left empty, the Player's figure.
var focus: Node3D
## The sand it throws up.
var spray: SandSpray
var cost_usec := 0.0

var _columns := 0
var _rows := 0
var _heights := PackedFloat32Array()
var _kinds := PackedByteArray()
var _kinds_stale := false
var _kind_image: Image
var _kind_map: ImageTexture
var _height_map: ImageTexture
var _form_map: ImageTexture
var _material: ShaderMaterial
var _drawn: MeshInstance3D
var _collider: CollisionShape3D
var _origin := Vector3.ZERO
var _quality := -1
var _slow := 0.0
var _clock := 0.0

# The dents: `_span` squares a side, each `_fine` metres across, kept as a
# torus (a place's square is its place, wrapped), in tiles of `_tile` squares.
var _span := 0
var _fine := 0.015
var _tile := 32
var _dent := PackedByteArray()
var _dent_image: Image
var _dent_map: ImageTexture
var _dent_stale := false
var _middle := Vector2i(1 << 20, 0)
# The tiles with anything in them, and how far each has been filled.
var _live := {}
var _live_list: Array[Vector2i] = []
var _cursor := 0
var _filled := 0.0

var _figures := {}
var _bodies := {}
var _hounds := {}
var _later: Array = []
var _census := 0.0

static var _boot: Array
static var _paw: Array
static var _bowl: Array
static var _heap: Array
static var _lying: Array


func _ready() -> void:
	add_to_group(&"sand_grounds")
	process_priority = 20
	process_physics_priority = 20
	spray = SandSpray.new()
	add_child(spray)
	if height.is_valid() and not is_built():
		build()


func is_built() -> bool:
	return _height_map != null


# --- Making it ---

## Makes the ground: heights, collider, mesh. `heights`, if given, is the
## grid already worked out (as `SandDunes.bake` gives it: row by row, one more
## each way than there are squares); otherwise `height` is asked.
func build(heights := PackedFloat32Array()) -> void:
	_origin = global_position if is_inside_tree() else position
	_columns = maxi(int(round(half.x * 2.0 / cell)), 2)
	_rows = maxi(int(round(half.y * 2.0 / cell)), 2)
	var wide := _columns + 1
	var long := _rows + 1
	if heights.size() == wide * long:
		_heights = heights
	else:
		_heights.resize(wide * long)
		for row in long:
			for column in wide:
				_heights[row * wide + column] = height.call(column * cell - half.x, row * cell - half.y)
	_height_map = ImageTexture.create_from_image(Image.create_from_data(wide, long, false, Image.FORMAT_RF, _heights.to_byte_array()))
	_make_form()
	if _kinds.size() != wide * long * 4:
		_kinds.resize(wide * long * 4)
		_kinds.fill(0)
	_kind_image = Image.create_from_data(wide, long, false, Image.FORMAT_RGBA8, _kinds)
	_kind_map = ImageTexture.create_from_image(_kind_image)
	_material = Sand.ground_surface(colour)
	lend(_material)
	_material.set_shader_parameter(&"form_map", _form_map)
	_material.set_shader_parameter(&"kind_map", _kind_map)
	var plain := apron
	if plain == INF:
		plain = 0.0
		for column in wide:
			plain += (_heights[column] + _heights[(long - 1) * wide + column]) / (2.0 * wide)
	_material.set_shader_parameter(&"apron", Vector2(plain, 6.0))
	if solid:
		_make_collider()
	if _drawn == null:
		_drawn = MeshInstance3D.new()
		_drawn.top_level = true
		# (its shader puts it where it is)
		_drawn.custom_aabb = AABB(Vector3.ONE * -8000.0, Vector3.ONE * 16000.0)
		add_child(_drawn)
		_drawn.global_transform = Transform3D.IDENTITY
	_make_brushes()
	_fit_quality()
	built.emit()


## Gives another material what it needs to read this ground's heights (as
## `SandWind` does, to lay its streamers along the dunes): `height_map`,
## `field` and `field_cells`, as the sand shader has them.
func lend(material: ShaderMaterial) -> void:
	material.set_shader_parameter(&"height_map", _height_map)
	material.set_shader_parameter(&"field", Vector4(_origin.x - half.x, _origin.z - half.y, cell, _origin.y))
	material.set_shader_parameter(&"field_cells", Vector2(_columns, _rows))


## The material it is drawn with.
func material() -> ShaderMaterial:
	return _material


# Which way each corner faces, how sharply the ground bends there (a crest
# is more than nothing, a crease less), and how far it lies below the ground
# round about (a hollow).
func _make_form() -> void:
	var wide := _columns + 1
	var long := _rows + 1
	# The ground round about: the mean over a square some way each side.
	var round_about := _smoothed(_heights, wide, long, maxi(int(7.0 / cell), 2))
	var form := PackedFloat32Array()
	form.resize(wide * long * 4)
	var far := maxi(int(round(2.0 / cell)), 1)
	for row in long:
		var north := maxi(row - 1, 0) * wide
		var south := mini(row + 1, long - 1) * wide
		var far_north := maxi(row - far, 0) * wide
		var far_south := mini(row + far, long - 1) * wide
		for column in wide:
			var here := _heights[row * wide + column]
			var west := maxi(column - 1, 0)
			var east := mini(column + 1, wide - 1)
			var facing := Vector3((_heights[row * wide + west] - _heights[row * wide + east]) / (cell * (east - west)), 1.0,
					(_heights[north + column] - _heights[south + column]) / (cell * (south - north) / wide)).normalized()
			var bend := (_heights[row * wide + maxi(column - far, 0)] + _heights[row * wide + mini(column + far, wide - 1)]
					+ _heights[far_north + column] + _heights[far_south + column] - 4.0 * here) / (far * cell * far * cell)
			var at := (row * wide + column) * 4
			form[at] = facing.x
			form[at + 1] = facing.z
			form[at + 2] = clampf(-bend * 2.2, -1.0, 1.0)
			form[at + 3] = clampf((round_about[row * wide + column] - here) / 2.5, -1.0, 1.0)
	var image := Image.create_from_data(wide, long, false, Image.FORMAT_RGBAF, form.to_byte_array())
	image.convert(Image.FORMAT_RGBAH)
	_form_map = ImageTexture.create_from_image(image)


# Each value the mean of those within `reach` of it, along and then across.
static func _smoothed(values: PackedFloat32Array, wide: int, long: int, reach: int) -> PackedFloat32Array:
	var along := PackedFloat32Array()
	along.resize(values.size())
	for row in long:
		var sum := 0.0
		var count := 0
		for column in range(-reach, wide):
			var enters := column + reach
			if enters < wide:
				sum += values[row * wide + enters]
				count += 1
			var leaves := column - reach - 1
			if leaves >= 0:
				sum -= values[row * wide + leaves]
				count -= 1
			if column >= 0:
				along[row * wide + column] = sum / count
	var both := PackedFloat32Array()
	both.resize(values.size())
	for column in wide:
		var sum := 0.0
		var count := 0
		for row in range(-reach, long):
			var enters := row + reach
			if enters < long:
				sum += along[enters * wide + column]
				count += 1
			var leaves := row - reach - 1
			if leaves >= 0:
				sum -= along[leaves * wide + column]
				count -= 1
			if row >= 0:
				both[row * wide + column] = sum / count
	return both


func _make_collider() -> void:
	var wide := _columns + 1
	var faces := PackedVector3Array()
	faces.resize(_columns * _rows * 6)
	var next := 0
	for row in _rows:
		var z := row * cell - half.y
		for column in _columns:
			var x := column * cell - half.x
			var corner := row * wide + column
			var a := Vector3(x, _heights[corner], z)
			var b := Vector3(x + cell, _heights[corner + 1], z)
			var c := Vector3(x + cell, _heights[corner + wide + 1], z + cell)
			var d := Vector3(x, _heights[corner + wide], z + cell)
			faces[next] = a
			faces[next + 1] = b
			faces[next + 2] = c
			faces[next + 3] = a
			faces[next + 4] = c
			faces[next + 5] = d
			next += 6
	var shape := ConcavePolygonShape3D.new()
	shape.set_faces(faces)
	if _collider == null:
		_collider = CollisionShape3D.new()
		add_child(_collider)
	_collider.shape = shape


# The mesh and the dents, as fine as `Sand.quality` allows.
func _fit_quality() -> void:
	_quality = Sand.quality
	var first: float = [0.125, 0.0625, 0.015625][_quality]
	var across: int = [48, 64, 96][_quality]
	_drawn.mesh = _make_mesh(first, across)
	_drawn.mesh.surface_set_material(0, _material)
	Sand.refresh()
	# (on a phone the ground casts no shadows: it would be drawn again for each of the sun's)
	_drawn.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON if _quality >= 2 and casts_shadow else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	spray.thrift = [0.5, 0.75, 1.0][_quality]
	_span = [256, 512, 1024][_quality]
	_fine = [0.04, 0.025, 0.015][_quality]
	_tile = _span / 32
	_dent.resize(_span * _span)
	_dent.fill(NEUTRAL)
	_live.clear()
	_live_list.clear()
	_dent_image = Image.create_from_data(_span, _span, false, Image.FORMAT_R8, _dent)
	_dent_map = ImageTexture.create_from_image(_dent_image)
	_material.set_shader_parameter(&"dent_map", _dent_map)
	_material.set_shader_parameter(&"dent", Vector4(_fine, _span, 255.0 * UNIT, NEUTRAL / 255.0))


# Rings of squares: the first a whole grid `across` squares a side, each
# `first` metres; every one after it twice as coarse, the same number across,
# with a hole in the middle where the last one is, and a band of triangles
# joining it to the last one's edge. Each corner carries the side of its
# ring's squares, and whether it is one of those that sit on the ring inside.
func _make_mesh(first: float, across: int) -> ArrayMesh:
	var points := PackedVector3Array()
	var marks := PackedVector2Array()
	var corners := PackedInt32Array()
	var need := maxf(half.x, half.y) * 2.0 + beyond
	var square := first
	@warning_ignore("integer_division")
	var mid := across / 2
	var ring := 0
	while true:
		@warning_ignore("integer_division")
		var hole := 0 if ring == 0 else across / 4 + 1
		var index := {}
		for j in range(-mid, mid + 1):
			for i in range(-mid, mid + 1):
				if maxi(absi(i), absi(j)) >= hole:
					index[Vector2i(i, j)] = points.size()
					points.append(Vector3(i * square, 0.0, j * square))
					marks.append(Vector2(square, 0.0))
		for j in range(-mid, mid):
			for i in range(-mid, mid):
				if i >= -hole and i < hole and j >= -hole and j < hole:
					continue
				var a: int = index[Vector2i(i, j)]
				var c: int = index[Vector2i(i + 1, j + 1)]
				corners.append_array([a, index[Vector2i(i + 1, j)], c, a, c, index[Vector2i(i, j + 1)]])
		if ring > 0:
			# The band: the last ring's edge (in its squares, half the size of
			# these) on one side, this ring's innermost corners on the other.
			var edge := {}
			for side in 4:
				var inner: Array[int] = []
				var outer: Array[int] = []
				for k in across + 1:
					var on: Vector2i = [Vector2i(-mid + k, -mid), Vector2i(mid, -mid + k), Vector2i(mid - k, mid), Vector2i(-mid, mid - k)][side]
					if not edge.has(on):
						edge[on] = points.size()
						points.append(Vector3(on.x * square * 0.5, 0.0, on.y * square * 0.5))
						marks.append(Vector2(square, 1.0))
					inner.append(edge[on])
				for k in hole * 2 + 1:
					outer.append(index[[Vector2i(-hole + k, -hole), Vector2i(hole, -hole + k), Vector2i(hole - k, hole), Vector2i(-hole, hole - k)][side]])
				var i := 0
				var o := 0
				while i < inner.size() - 1 or o < outer.size() - 1:
					var take_inner := o >= outer.size() - 1 or (i < inner.size() - 1 and float(i + 1) / (inner.size() - 1) <= float(o + 1) / (outer.size() - 1))
					var third := inner[i + 1] if take_inner else outer[o + 1]
					var one := points[outer[o]] - points[inner[i]]
					var other := points[third] - points[inner[i]]
					# (wound the way the squares are)
					if one.z * other.x - one.x * other.z < 0.0:
						corners.append_array([inner[i], outer[o], third])
					else:
						corners.append_array([inner[i], third, outer[o]])
					if take_inner:
						i += 1
					else:
						o += 1
		if square * mid >= need:
			break
		square *= 2.0
		ring += 1
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = points
	arrays[Mesh.ARRAY_TEX_UV] = marks
	arrays[Mesh.ARRAY_INDEX] = corners
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return mesh


# --- Asking it things ---

## How high the sand stands at a place in the world (as the collider has it;
## dents are not counted).
func height_at(x: float, z: float) -> float:
	if _heights.is_empty():
		return _origin.y
	var across := clampf((x - _origin.x + half.x) / cell, 0.0, _columns - 0.0001)
	var along := clampf((z - _origin.z + half.y) / cell, 0.0, _rows - 0.0001)
	var column := int(across)
	var row := int(along)
	across -= column
	along -= row
	var corner := row * (_columns + 1) + column
	var a := _heights[corner]
	var d := _heights[corner + _columns + 2]
	if across > along:
		var b := _heights[corner + 1]
		return a + across * (b - a) + along * (d - b) + _origin.y
	var c := _heights[corner + _columns + 1]
	return a + along * (c - a) + across * (d - c) + _origin.y


## Which way the sand faces at a place in the world.
func normal_at(x: float, z: float) -> Vector3:
	var reach := cell * 0.5
	return Vector3(height_at(x - reach, z) - height_at(x + reach, z), cell, height_at(x, z - reach) - height_at(x, z + reach)).normalized()


## Whether a point in the world is on this sand, or within `slack` above or below it.
func covers(point: Vector3, slack := 0.15) -> bool:
	if _heights.is_empty() or absf(point.x - _origin.x) > half.x or absf(point.z - _origin.z) > half.y:
		return false
	return absf(point.y - height_at(point.x, point.z)) <= slack


## What has been painted at a place: a share of each `Sand.Kind`, in that
## order, as r, g, b, a.
func kind_at(x: float, z: float) -> Color:
	if _kinds.is_empty() or _heights.is_empty():
		return Color(0.0, 0.0, 0.0, 0.0)
	var column := clampi(int(round((x - _origin.x + half.x) / cell)), 0, _columns)
	var row := clampi(int(round((z - _origin.z + half.y) / cell)), 0, _rows)
	var at := (row * (_columns + 1) + column) * 4
	return Color(_kinds[at] / 255.0, _kinds[at + 1] / 255.0, _kinds[at + 2] / 255.0, _kinds[at + 3] / 255.0)


## About the colour of the sand at a place, for whatever is thrown up from it.
func colour_at(x: float, z: float) -> Color:
	var kind := kind_at(x, z)
	return colour.lerp(colour * Color(0.8, 0.755, 0.71), kind.r).lerp(colour * Color(0.6, 0.57, 0.53), kind.g)


## Paints a kind of sand (`Sand.Kind`) round a place in the world (x, z): all
## of `amount` within `radius`, falling away to nothing over `feather` beyond.
## May be called before or after it is built.
func paint(kind: int, at: Vector2, radius: float, amount := 1.0, feather := 2.0) -> void:
	paint_line(kind, at, at, radius, amount, feather)


## The same along a line: `width` is how far to each side of it.
func paint_line(kind: int, from: Vector2, to: Vector2, width: float, amount := 1.0, feather := 2.0) -> void:
	_columns = maxi(int(round(half.x * 2.0 / cell)), 2) if _columns == 0 else _columns
	_rows = maxi(int(round(half.y * 2.0 / cell)), 2) if _rows == 0 else _rows
	var wide := _columns + 1
	if _kinds.size() != wide * (_rows + 1) * 4:
		_kinds.resize(wide * (_rows + 1) * 4)
		_kinds.fill(0)
	var corner := Vector2(position.x - half.x, position.z - half.y) if not is_built() else Vector2(_origin.x - half.x, _origin.z - half.y)
	var reach := width + feather
	var low := (from.min(to) - Vector2.ONE * reach - corner) / cell
	var high := (from.max(to) + Vector2.ONE * reach - corner) / cell
	for row in range(maxi(floori(low.y), 0), mini(ceili(high.y), _rows) + 1):
		for column in range(maxi(floori(low.x), 0), mini(ceili(high.x), _columns) + 1):
			var place := corner + Vector2(column, row) * cell
			var along := to - from
			var share := clampf((place - from).dot(along) / maxf(along.length_squared(), 0.0001), 0.0, 1.0)
			var far := place.distance_to(from + along * share)
			var value := int(255.0 * amount * (1.0 - smoothstep(width, reach, far)))
			var at := (row * wide + column) * 4 + kind
			if value > _kinds[at]:
				_kinds[at] = value
	_kinds_stale = true


# --- Pressing into it ---

## A boot print at a point in the world: `yaw` is which way the toe points
## (as `rotation.y`), `depth` how deep the heel goes, metres.
func footprint(at: Vector3, yaw: float, depth: float, left: bool) -> void:
	_stamp(_boot, Vector2(at.x, at.z), yaw, depth, 1.0, not left)


## A paw print.
func pawprint(at: Vector3, yaw: float, depth: float) -> void:
	_stamp(_paw, Vector2(at.x, at.z), yaw, depth)


## A round dent with a lip round it, `radius` across its hollow: what a rock
## makes where it lands. Stamped again and again along a line it is a trough.
func press(at: Vector3, radius: float, depth: float) -> void:
	_stamp(_bowl, Vector2(at.x, at.z), 0.0, depth, radius)


## A low heap, `radius` to its foot and `tall` high: where running sand comes to rest.
func heap(at: Vector3, radius: float, tall: float) -> void:
	_stamp(_heap, Vector2(at.x, at.z), 0.0, tall, radius)


## The print of someone lying full length, head towards `yaw`, `at` their middle.
func body_print(at: Vector3, yaw: float, depth: float) -> void:
	_stamp(_lying, Vector2(at.x, at.z), yaw, depth)


## Sets the sand at a place running downhill, if it lies steeply enough:
## sheets of it slide away, and more trickles after. `amount` is how hard it
## was disturbed (a walking step is about half, a slide 1 or more).
func disturb(at: Vector3, amount: float) -> void:
	var facing := normal_at(at.x, at.z)
	var steep := sqrt(maxf(1.0 - facing.y * facing.y, 0.0)) / maxf(facing.y, 0.01)
	if steep < RUNS_AT:
		return
	var much := smoothstep(RUNS_AT, 0.62, steep) * clampf(amount, 0.2, 2.0)
	var downhill := Vector3(facing.x, 0.0, facing.z).normalized()
	downhill = (downhill - facing * downhill.dot(facing)).normalized()
	var across := facing.cross(downhill)
	var pale := colour_at(at.x, at.z).lightened(0.12).srgb_to_linear()
	var ground_at := Vector3(at.x, height_at(at.x, at.z), at.z)
	# One sheet away at once, and one or two that let go a moment later.
	for k in 1 + int(much * 2.0 + randf()):
		var delay := 0.0 if k == 0 else randf_range(0.25, 1.4) * (0.6 + much)
		var from := ground_at + across * randf_range(-0.22, 0.22) * (1.0 if k > 0 else 0.3) + downhill * randf_range(0.0, 0.25)
		from.y = height_at(from.x, from.z)
		var length := randf_range(0.5, 0.9) + much * 0.9
		var pace := 0.9 + much * 1.5
		var life := randf_range(1.3, 1.9) + much * 0.6
		spray.run(from, downhill, facing, length, randf_range(0.2, 0.32) + 0.2 * much, pace, life, pale, delay)
		# Where it comes to rest it leaves a little heap; where it left, a scoop.
		var rests := from + downhill * (pace * life * 0.5 + length * 0.3)
		_later.append([_clock + delay + life * 0.8, rests, 0.16 + 0.1 * much, 0.008 + 0.008 * much])
		if k == 0:
			press(from + downhill * 0.12, 0.1 + 0.05 * much, 0.008 + 0.006 * much)


# Presses a brush into the dents: a small picture of a shape, -1 where it is
# deepest, more than nothing where sand is pushed up round it. `size` scales
# the picture, `depth` is how far -1 goes down, metres.
func _stamp(brush: Array, at: Vector2, yaw: float, depth: float, size := 1.0, mirrored := false) -> void:
	if _span == 0:
		return
	var picture: PackedFloat32Array = brush[0]
	var wide: int = brush[1]
	var long: int = brush[2]
	var grain: float = brush[3] * size
	var half_wide := wide * grain * 0.5
	var half_long := long * grain * 0.5
	var reach := sqrt(half_wide * half_wide + half_long * half_long)
	var sine := sin(yaw)
	var cosine := cos(yaw)
	# (only inside the patch that is kept)
	var room := (_span >> 1) - _tile
	var first_x := maxi(floori((at.x - reach) / _fine), _middle.x - room)
	var last_x := mini(ceili((at.x + reach) / _fine), _middle.x + room - 1)
	var first_z := maxi(floori((at.y - reach) / _fine), _middle.y - room)
	var last_z := mini(ceili((at.y + reach) / _fine), _middle.y + room - 1)
	if first_x > last_x or first_z > last_z:
		return
	var levels := depth / UNIT
	var mask := _span - 1
	var flip := -1.0 if mirrored else 1.0
	for z in range(first_z, last_z + 1):
		var off_z := (z + 0.5) * _fine - at.y
		var row := (z & mask) * _span
		for x in range(first_x, last_x + 1):
			var off_x := (x + 0.5) * _fine - at.x
			var across := (off_x * cosine - off_z * sine) * flip + half_wide
			var along := off_x * sine + off_z * cosine + half_long
			if across < 0.0 or along < 0.0:
				continue
			var column := int(across / grain)
			var line := int(along / grain)
			if column >= wide or line >= long:
				continue
			var value := picture[line * wide + column]
			if value == 0.0:
				continue
			var index := row + (x & mask)
			var now := _dent[index] - NEUTRAL
			var wanted := int(value * levels)
			if value < 0.0:
				if wanted < now:
					_dent[index] = maxi(wanted + NEUTRAL, 0)
			elif now > -3 and wanted > now:
				_dent[index] = mini(wanted + NEUTRAL, 255)
	for tile_z in range(floori(float(first_z) / _tile), floori(float(last_z) / _tile) + 1):
		for tile_x in range(floori(float(first_x) / _tile), floori(float(last_x) / _tile) + 1):
			var tile := Vector2i(tile_x, tile_z)
			if not _live.has(tile):
				_live[tile] = _filled
				_live_list.append(tile)
	_dent_stale = true


# Moves the patch of dents to keep the focus in the middle of it, a tile at a
# time, forgetting whatever is left behind.
func _follow(to: Vector3) -> void:
	var middle := Vector2i(roundi(to.x / (_fine * _tile)), roundi(to.z / (_fine * _tile))) * _tile
	if middle == _middle:
		return
	_middle = middle
	_material.set_shader_parameter(&"dent_at", Vector2(middle) * _fine)
	var room := (_span >> 1) - _tile
	var i := 0
	while i < _live_list.size():
		var tile := _live_list[i]
		var from_middle := tile * _tile - middle
		if from_middle.x < -room or from_middle.x >= room or from_middle.y < -room or from_middle.y >= room:
			_smooth_over(tile, 0, true)
			_live.erase(tile)
			_live_list[i] = _live_list[-1]
			_live_list.pop_back()
			_dent_stale = true
		else:
			i += 1


# The wind's work: a few tiles a frame, each softened and filled by as much
# as is due to it since it was last seen to.
func _fill(delta: float) -> void:
	var seconds := lerpf(fill_seconds.x, fill_seconds.y, clampf(Sand.wind_force, 0.0, 1.0))
	_filled += delta * (0.02 / UNIT) / maxf(seconds, 0.1)
	var budget := 2
	for look in mini(_live_list.size(), 8):
		_cursor = (_cursor + 1) % _live_list.size()
		var tile := _live_list[_cursor]
		var due := int(_filled - _live[tile])
		if due < 1:
			continue
		_live[tile] += due
		_dent_stale = true
		if not _smooth_over(tile, due, false):
			_live.erase(tile)
			_live_list[_cursor] = _live_list[-1]
			_live_list.pop_back()
			if _live_list.is_empty():
				break
		budget -= 1
		if budget == 0:
			break


# Softens one tile (each square a quarter of the way to the mean of those
# round it) and brings it `levels` nearer to flat; or just flattens it. Says
# whether anything is left in it.
func _smooth_over(tile: Vector2i, levels: int, flatten: bool) -> bool:
	var mask := _span - 1
	var from_x := tile.x * _tile
	var from_z := tile.y * _tile
	var any := false
	for j in _tile:
		var row := ((from_z + j) & mask) * _span
		if flatten:
			for i in _tile:
				_dent[row + ((from_x + i) & mask)] = NEUTRAL
			continue
		var north := ((from_z + j - 1) & mask) * _span
		var south := ((from_z + j + 1) & mask) * _span
		for i in _tile:
			var x := (from_x + i) & mask
			var here := _dent[row + x]
			var around := _dent[row + ((x + 1) & mask)] + _dent[row + ((x - 1) & mask)] + _dent[north + x] + _dent[south + x]
			if here == NEUTRAL and around == NEUTRAL * 4:
				continue
			var soft := (here * 12 + around + 8) >> 4
			if soft > NEUTRAL:
				soft = maxi(soft - levels, NEUTRAL)
			elif soft < NEUTRAL:
				soft = mini(soft + levels, NEUTRAL)
			_dent[row + x] = soft
			if soft != NEUTRAL:
				any = true
	return any


# The shapes that are pressed in: each [picture, squares wide, squares long, metres a square].
static func _make_brushes() -> void:
	if not _boot.is_empty():
		return
	# A left boot, toe towards +z, 27 cm long: a round heel, a waist, the ball
	# of the foot and a round toe; deepest under the heel and the ball, with
	# the front edge of the heel standing across it; and a lip pushed up round it.
	var grain := 0.01
	var wide := 18
	var long := 35
	var picture := PackedFloat32Array()
	picture.resize(wide * long)
	for line in long:
		var along := ((line + 0.5) * grain - long * grain * 0.5 + 0.135) / 0.27
		var half_wide := 0.0
		if along >= 0.0 and along <= 1.0:
			if along < 0.14:
				half_wide = 0.037 * sqrt(1.0 - pow((0.14 - along) / 0.14, 2.0))
			elif along < 0.3:
				half_wide = 0.037
			elif along < 0.44:
				half_wide = lerpf(0.037, 0.032, smoothstep(0.3, 0.44, along))
			elif along < 0.68:
				half_wide = lerpf(0.032, 0.05, smoothstep(0.44, 0.68, along))
			else:
				half_wide = 0.05 * sqrt(maxf(1.0 - pow((along - 0.68) / 0.32, 2.0), 0.0))
		# (the outside of the foot bows out; the inside is nearly straight)
		var middle := 0.008 * sin(clampf(along, 0.0, 1.0) * PI)
		var beyond_ends := maxf(maxf(-along, along - 1.0), 0.0) * 0.27
		for column in wide:
			var across := (column + 0.5) * grain - wide * grain * 0.5
			var outside := absf(across - middle) - half_wide
			if beyond_ends > 0.0:
				outside = sqrt(pow(maxf(absf(across - middle) - 0.02, 0.0), 2.0) + beyond_ends * beyond_ends)
			var value := 0.0
			if outside < 0.0:
				var deep := 0.6
				if along < 0.31:
					deep = 1.0
				elif along < 0.35:
					deep = 0.45
				elif along > 0.5:
					deep = lerpf(0.6, 0.92, smoothstep(0.5, 0.66, along)) * (1.0 - 0.25 * smoothstep(0.85, 1.0, along))
				value = -deep * smoothstep(0.0, 0.009, -outside)
			elif outside < 0.022:
				value = 0.16 * sin(PI * outside / 0.022)
			picture[line * wide + column] = value
	_boot = [picture, wide, long, grain]

	# A paw: a pad, and four toes in front of it.
	grain = 0.006
	wide = 16
	long = 18
	picture = PackedFloat32Array()
	picture.resize(wide * long)
	var pads: Array[Vector3] = [Vector3(0.0, -0.014, 0.021), Vector3(-0.026, 0.012, 0.011), Vector3(-0.01, 0.03, 0.011), Vector3(0.01, 0.03, 0.011), Vector3(0.026, 0.012, 0.011)]
	for line in long:
		for column in wide:
			var place := Vector2((column + 0.5) * grain - wide * grain * 0.5, (line + 0.5) * grain - long * grain * 0.5)
			var value := 0.0
			for pad in pads:
				value = minf(value, -smoothstep(0.0, 0.006, pad.z - place.distance_to(Vector2(pad.x, pad.y))))
			picture[line * wide + column] = value
	_paw = [picture, wide, long, grain]

	# A bowl one metre in radius (it is scaled to fit), and a lip round it; and a heap.
	wide = 34
	grain = 2.9 / wide
	picture = PackedFloat32Array()
	picture.resize(wide * wide)
	var mound := PackedFloat32Array()
	mound.resize(wide * wide)
	for line in wide:
		for column in wide:
			var out := Vector2((column + 0.5) * grain - 1.45, (line + 0.5) * grain - 1.45).length()
			if out < 1.0:
				picture[line * wide + column] = -pow(cos(out * PI * 0.5), 0.7)
			elif out < 1.42:
				picture[line * wide + column] = 0.32 * sin(PI * (out - 1.0) / 0.42)
			mound[line * wide + column] = pow(maxf(cos(minf(out, 1.0) * PI * 0.5), 0.0), 1.3)
	_bowl = [picture, wide, wide, grain]
	_heap = [mound, wide, wide, grain]

	# Someone lying full length, head towards +z: head, shoulders and arms, trunk, legs.
	grain = 0.015
	wide = 60
	long = 106
	picture = PackedFloat32Array()
	picture.resize(wide * long)
	for line in long:
		for column in wide:
			var place := Vector2((column + 0.5) * grain - wide * grain * 0.5, (line + 0.5) * grain - long * grain * 0.5)
			# (how far inside each part, the deepest of them)
			var inside := 0.105 - place.distance_to(Vector2(0.0, 0.6))
			# (the trunk, wider at the shoulders, with the arms lying along it)
			var wide_here := lerpf(0.15, 0.25, smoothstep(0.0, 0.42, place.y))
			inside = maxf(inside, 0.07 - Vector2(maxf(absf(place.x) - wide_here + 0.07, 0.0), maxf(absf(place.y - 0.22) - 0.2, 0.0)).length())
			inside = maxf(inside, 0.075 - Vector2(absf(absf(place.x) - 0.095), maxf(absf(place.y + 0.36) - 0.36, 0.0)).length())
			# (soft at the edges: a body is round, and does not press evenly)
			var value := -smoothstep(-0.03, 0.07, inside) * (0.8 + 0.2 * sin(place.y * 7.0 + 1.0))
			picture[line * wide + column] = value
	_lying = [picture, wide, long, grain]


# --- Each frame ---

func _process(delta: float) -> void:
	if not is_built():
		return
	var began := Time.get_ticks_usec()
	_clock += delta
	if _quality != Sand.quality:
		_fit_quality()
		_middle = Vector2i(1 << 20, 0)
	if focus == null or not is_instance_valid(focus):
		focus = null
		for figure: Node3D in get_tree().get_nodes_in_group(&"figures"):
			if figure.get_parent() is Player:
				focus = figure
				break
	var middle := Vector3.ZERO
	if focus:
		middle = focus.global_position
	elif get_viewport().get_camera_3d():
		middle = get_viewport().get_camera_3d().global_position
	_material.set_shader_parameter(&"focus", middle)
	_follow(middle)

	for figure: Node3D in get_tree().get_nodes_in_group(&"figures"):
		_watch(figure, delta)
	_census -= delta
	if _census <= 0.0:
		_census = 0.5
		_count_heads()
		_watch_frames()
	for hound: Variant in _hounds:
		if is_instance_valid(hound):
			_watch_hound(hound)

	# What was set going a while ago and comes to rest now.
	var i := 0
	while i < _later.size():
		if _later[i][0] <= _clock:
			heap(_later[i][1], _later[i][2], _later[i][3])
			_later[i] = _later[-1]
			_later.pop_back()
		else:
			i += 1
	if not _live_list.is_empty():
		_fill(delta)
	if _dent_stale:
		_dent_stale = false
		_dent_image.set_data(_span, _span, false, Image.FORMAT_R8, _dent)
		_dent_map.update(_dent_image)
	if _kinds_stale:
		_kinds_stale = false
		_kind_image.set_data(_columns + 1, _rows + 1, false, Image.FORMAT_RGBA8, _kinds)
		_kind_map.update(_kind_image)
	cost_usec = lerpf(cost_usec, float(Time.get_ticks_usec() - began), 0.1)


func _physics_process(delta: float) -> void:
	if not is_built():
		return
	for body: Variant in _bodies:
		if is_instance_valid(body) and (body as Node).is_inside_tree():
			_watch_body(body, _bodies[body])
	if slope_carry > 0.0:
		for figure: Variant in _figures:
			if is_instance_valid(figure) and (figure as Node).is_inside_tree() and _figures[figure].on:
				_carry(figure, _figures[figure], delta)


# Who and what is about: looked for twice a second, not every frame.
func _count_heads() -> void:
	for group: StringName in [&"throwable", &"sand_denting"]:
		for body: Node in get_tree().get_nodes_in_group(group):
			if body is RigidBody3D and not _bodies.has(body):
				# How big it is, and how far its middle rides above what it lies on.
				var radius := 0.15
				var rise := 0.15
				for child in body.get_children():
					if child is CollisionShape3D and child.shape is SphereShape3D:
						radius = (child.shape as SphereShape3D).radius
						rise = radius
					elif child is CollisionShape3D and child.shape is BoxShape3D:
						var box := (child.shape as BoxShape3D).size
						radius = minf(minf(box.x, box.z), maxf(box.x, box.z) * 0.6) * 0.55
						rise = minf(box.x, minf(box.y, box.z)) * 0.5 if box.y > maxf(box.x, box.z) * 1.5 else box.y * 0.5
				_bodies[body] = {radius = radius, rise = rise, touching = false, last = Vector3.INF, speed = 0.0}
	for hound: Node in get_tree().get_nodes_in_group(&"hounds"):
		if hound is Node3D and not _hounds.has(hound):
			_hounds[hound] = {last = (hound as Node3D).global_position, step = 0}
	for known: Dictionary in [_bodies, _hounds, _figures]:
		for node: Variant in known.keys():
			if not is_instance_valid(node):
				known.erase(node)


# Turns the quality down a step if frames have been slow for some seconds.
func _watch_frames() -> void:
	if not auto_quality or _clock < 6.0:
		return
	_slow = _slow + 0.5 if Performance.get_monitor(Performance.TIME_FPS) < 38.0 else 0.0
	if _slow >= 5.0 and Sand.quality > 0:
		_slow = 0.0
		Sand.quality -= 1


# --- Figures ---

func _watch(figure: Node3D, delta: float) -> void:
	var body := figure.get_parent() as CharacterBody3D
	if body == null:
		return
	var known: Dictionary = _figures.get(figure, {})
	if known.is_empty():
		known = {on = false, sink = 0.0, pressed = 0.0, scrape = 0.0, run = 0.0, phase = [0.0, 0.5], hooked = figure.has_signal(&"footfall"),
				sprawl = -1.0, dust = null}
		_figures[figure] = known
		if known.hooked:
			figure.connect(&"footfall", _on_footfall.bind(figure))
		if figure.has_signal(&"scraped"):
			figure.connect(&"scraped", _on_scraped.bind(figure))
		if body.has_signal(&"landed"):
			body.connect(&"landed", _on_landed.bind(figure))
		if not (&"dust_scale" in figure):
			for child in figure.get_children():
				if child is Dust:
					known.dust = child
	var at := body.global_position
	var limp: bool = body.get(&"is_limp") == true
	var on := body.is_on_floor() and not limp and covers(at, 0.14 + known.sink)
	var lump := _lump_under(at) if not limp else false
	known.on = on
	# On sand it raises sand, not dust (nor as it comes down onto it).
	var sandy := on or lump or (not body.is_on_floor() and covers(at + Vector3.DOWN * 0.35, 0.5))
	if &"dust_scale" in figure:
		figure.set(&"dust_scale", 0.0 if sandy else 1.0)
	elif known.dust:
		(known.dust as Node3D).visible = not sandy

	# Standing still he settles into it, and comes out as he moves off.
	var speed := Vector3(body.velocity.x, 0.0, body.velocity.z).length()
	var still := speed < 0.25 and (on or lump) and body.is_on_floor()
	var packed := kind_at(at.x, at.z).b
	var want := 0.0
	if still:
		want = sink_depth * 3.0 if lump else sink_depth * (1.0 - 0.8 * packed)
	if want > known.sink:
		known.sink = lerpf(known.sink, want, 1.0 - exp(-3.0 * delta / sink_time))
	else:
		known.sink = move_toward(known.sink, want, delta * (0.25 if speed > 0.25 else 0.08))
	if &"sink" in figure:
		figure.set(&"sink", known.sink)
	# The dent to match, under each foot, as he goes down.
	if still and on and not lump and known.sink > known.pressed + 0.004:
		known.pressed = known.sink
		for foot in 2:
			footprint(_foot(figure, foot), _foot_yaw(figure, foot), known.sink + 0.008, foot == 0)
	elif not still:
		known.pressed = 0.0

	known.scrape = maxf(known.scrape - delta, 0.0)
	known.run = maxf(known.run - delta, 0.0)
	if known.sprawl >= 0.0:
		known.sprawl -= delta
		if known.sprawl < 0.0 and covers(at, 0.3):
			var facing := figure.global_basis.z
			body_print(at + Vector3(facing.x, 0.0, facing.z).normalized() * 0.5, atan2(facing.x, facing.z), 0.03)
	if not known.hooked:
		_guess_steps(figure, body, known, on, speed)


func _foot(figure: Node3D, foot: int) -> Vector3:
	if figure.has_method(&"foot_position"):
		return figure.call(&"foot_position", foot)
	return figure.global_position + figure.global_basis * Vector3(0.09 if foot == 0 else -0.09, 0.0, 0.03)


# Which way a foot points: the way he faces, turned out a little.
func _foot_yaw(figure: Node3D, foot: int) -> float:
	var facing := figure.global_basis.z
	return atan2(facing.x, facing.z) + (0.16 if foot == 0 else -0.16)


func _lump_under(at: Vector3) -> bool:
	for blob: Node in get_tree().get_nodes_in_group(&"sand_blobs"):
		if blob.has_method(&"covers") and blob.call(&"covers", at):
			return true
	return false


# A foot has come down at `at`: `weight` is about 0.3 sneaking, 0.5 walking,
# 1 running, and up to 3 for a landing.
func _on_footfall(at: Vector3, foot: int, weight: float, figure: Node3D) -> void:
	if not covers(at, 0.3):
		return
	var body := figure.get_parent() as CharacterBody3D
	var kind := kind_at(at.x, at.z)
	var loose := (1.0 - 0.75 * kind.b)
	if body and body.get(&"is_crawling") == true:
		# (a knee or a hand)
		press(at, 0.05, 0.014 * loose)
		return
	footprint(at, _foot_yaw(figure, foot), clampf(0.009 + 0.015 * weight, 0.01, 0.05) * loose * (1.0 + 0.4 * kind.g), foot == 0)
	var ground_at := Vector3(at.x, height_at(at.x, at.z), at.z)
	var tint := colour_at(at.x, at.z).srgb_to_linear()
	var going := Vector3(body.velocity.x, 0.0, body.velocity.z) if body else Vector3.ZERO
	var dry := loose * (1.0 - 0.5 * kind.g)
	if weight > 1.5:
		# A landing: a ring of it.
		spray.ring(ground_at, 1.2 + 0.6 * weight, int((8.0 + 6.0 * weight) * dry), tint, 0.22 + 0.06 * weight)
	elif weight > 0.4:
		# A step throws it back and up: a run more than a walk.
		var back := -going.normalized() if going.length() > 0.3 else Vector3.ZERO
		spray.kick(ground_at, back * (0.35 + 0.3 * going.length()) + Vector3.UP * (0.6 + 0.9 * weight), int((2.0 + 9.0 * (weight - 0.3)) * dry), 0.4, tint, 0.16 + 0.1 * weight)
	elif dry > 0.5:
		spray.kick(ground_at, Vector3.UP * 0.4, 1, 0.6, tint, 0.08)
	disturb(at, weight)


# He is scraping over the ground at `at`: sliding, skidding, rolling, or down on it.
func _on_scraped(at: Vector3, velocity: Vector3, amount: float, figure: Node3D) -> void:
	var known: Dictionary = _figures.get(figure, {})
	if known.is_empty() or known.scrape > 0.0 or not covers(at, 0.4):
		return
	known.scrape = 0.05
	var ground_at := Vector3(at.x, height_at(at.x, at.z), at.z)
	var kind := kind_at(at.x, at.z)
	var loose := (1.0 - 0.75 * kind.b)
	press(ground_at, 0.15 + 0.07 * amount, (0.016 + 0.014 * amount) * loose)
	var tint := colour_at(at.x, at.z).srgb_to_linear()
	var pace := Vector3(velocity.x, 0.0, velocity.z).length()
	if pace > 0.6:
		# A sheet of it, thrown out ahead and to the sides.
		spray.kick(ground_at, velocity * 0.45 + Vector3.UP * (0.5 + 0.25 * pace * amount), int(1.0 + 2.0 * amount * loose), 0.55, tint, 0.2)
	if known.run <= 0.0:
		known.run = 0.14
		disturb(at, 0.6 + amount)


# He has landed. The feet say so themselves (see `_on_footfall`); this is for
# the sprawl, which leaves the print of all of him a moment later.
func _on_landed(impact_speed: float, figure: Node3D) -> void:
	var body := figure.get_parent()
	var known: Dictionary = _figures.get(figure, {})
	if known.is_empty():
		return
	if &"landing" in body and body.get(&"landing") == Player.Landing.SPRAWL:
		known.sprawl = 0.42
	if not known.hooked and covers(figure.global_position, 0.4):
		for foot in 2:
			_on_footfall(_foot(figure, foot), foot, clampf(impact_speed / 5.0, 1.0, 3.0), figure)


# For a rig that does not yet say when its feet come down: watches its gait
# go round, as it does itself, and its slides.
func _guess_steps(figure: Node3D, body: CharacterBody3D, known: Dictionary, on: bool, speed: float) -> void:
	var phases: Variant = figure.get(&"_foot_phase")
	if phases is Array and (phases as Array).size() == 2:
		for foot in 2:
			var before: float = known.phase[foot]
			known.phase[foot] = phases[foot]
			if on and speed > 0.4 and phases[foot] < before - 0.5:
				var weight := 0.3 if body.get(&"is_ducking") == true else clampf(remap(speed, 1.6, 4.4, 0.5, 1.0), 0.4, 1.2)
				_on_footfall(_foot(figure, foot), foot, weight, figure)
	if on and not figure.has_signal(&"scraped") and body.get(&"state") == Player.State.SLIDE:
		_on_scraped(body.global_position, body.velocity, 1.0, figure)


# A steep face gives under him: it carries him downhill a little, and goes
# on running while he stands on it.
func _carry(figure: Node3D, known: Dictionary, delta: float) -> void:
	var body := figure.get_parent() as CharacterBody3D
	var at := body.global_position
	var facing := normal_at(at.x, at.z)
	var steep := sqrt(maxf(1.0 - facing.y * facing.y, 0.0)) / maxf(facing.y, 0.01)
	var gives := smoothstep(0.47, 0.62, steep) * (1.0 - kind_at(at.x, at.z).b)
	if gives <= 0.01:
		return
	var downhill := Vector3(facing.x, 0.0, facing.z).normalized()
	body.move_and_collide(downhill * slope_carry * gives * delta)
	if known.run <= 0.0:
		known.run = randf_range(0.25, 0.5)
		disturb(at + Vector3(randf_range(-0.2, 0.2), 0.0, randf_range(-0.2, 0.2)), 0.5 + gives)


# --- Hounds, and whatever is thrown ---

# A hound leaves prints by where it has got to: a pair for every stretch it covers.
func _watch_hound(hound: Node3D) -> void:
	var known: Dictionary = _hounds[hound]
	var at := hound.global_position
	var moved: Vector3 = at - known.last
	moved.y = 0.0
	if moved.length() < 0.3:
		return
	known.last = at
	known.step += 1
	if not covers(at, 0.2):
		return
	var way := moved.normalized()
	var side := Vector3(way.z, 0.0, -way.x) * (0.07 if known.step % 2 == 0 else -0.07)
	var yaw := atan2(way.x, way.z)
	# (fore and hind on that side, the hind one coming down just short of the fore)
	pawprint(at + side + way * 0.28, yaw, 0.014)
	pawprint(at + side - way * 0.2, yaw, 0.012)
	if moved.length() > 0.08 and hound is CharacterBody3D and (hound as CharacterBody3D).velocity.length() > 3.0:
		var ground_at := Vector3(at.x, height_at(at.x, at.z), at.z)
		spray.kick(ground_at, -way * 1.2 + Vector3.UP * 1.0, 2, 0.5, colour_at(at.x, at.z).srgb_to_linear(), 0.12)


# A loose thing: it dents the sand where it lands and furrows it where it rolls.
func _watch_body(body: RigidBody3D, known: Dictionary) -> void:
	var at := body.global_position
	var under: float = at.y - known.rise
	var falling: float = known.speed
	known.speed = body.linear_velocity.y
	if body.freeze or absf(at.x - _origin.x) > half.x or absf(at.z - _origin.z) > half.y:
		known.touching = false
		return
	var ground_y := height_at(at.x, at.z)
	var touching := absf(under - ground_y) < 0.05
	var ground_at := Vector3(at.x, ground_y, at.z)
	var radius: float = known.radius
	if touching and not known.touching:
		var hard := clampf(-falling * 0.12, 0.0, 1.0)
		press(ground_at, radius * (0.75 + 0.3 * hard), minf(0.008 + 0.03 * hard, radius * 0.5))
		known.last = at
		if hard > 0.15:
			spray.ring(ground_at, 0.8 + 2.0 * hard, int(4.0 + 12.0 * hard * minf(radius / 0.12, 2.0)), colour_at(at.x, at.z).srgb_to_linear(), 0.12 + 0.1 * hard)
			disturb(ground_at, hard * 1.5)
	elif touching and at.distance_to(known.last) > radius * 0.6:
		known.last = at
		press(ground_at, radius * 0.7, minf(0.012, radius * 0.2))
		disturb(ground_at, 0.3)
	known.touching = touching
