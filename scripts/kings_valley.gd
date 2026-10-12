class_name KingsValley
extends Node3D
## The Valley of the Kings, as a set piece: a wadi cut into a block of
## limestone hills, with side branches, scree at the foot of its cliffs, the
## pyramid-shaped peak el-Qurn standing over its head, a beaten path along its
## floor, and the mouths of rock-cut tombs in the cliff foot, with the walls
## and spoil heaps of the dig round them. It is made from a few numbers and a
## seed, and the same numbers always make the same valley.
##
## Its mouth is towards its own +z, and its floor is level, at its origin: the
## desert presses a pad of level ground for it (`DesertTerrain`), 124 by 164
## metres at `size` 1.
##
## What it is made of: the hills are one `Cliff`, whose top is a block with the
## wadi and its branches cut out of it; each doorway is a `TombDoor`, set where
## the cliff has cleared its scree away for it (`doors`); the peak, the
## doorways, the walls, the heaps and the boards are models (`RockModels`) put
## into one mesh. All told it is drawn in about eight calls.
##
## Doorways are numbered as the real ones are (`NUMBERS`), and one of them may
## be open (`open_tomb`: which, counting from 1) and lead to a tomb
## (`leads_to`, as `TombDoor.leads_to`).
##
## What is true to the place, and what is not, is in the README.

## The numbers on the boards, in the order doorways are made: tombs that had been found by 1910, and one that had not.
const NUMBERS: Array[int] = [9, 17, 11, 35, 6, 8, 34, 62]

## How big the whole of it is: 1 is about 120 m across and 160 long.
@export var size := 1.0
## How high its cliffs stand over its floor, in metres.
@export var height := 16.0
## How many tomb doorways, up to eight.
@export_range(0, 8) var tombs := 4
## Which of them is open, counting from 1 (0: none).
@export var open_tomb := 1
## What the open one leads to (see `TombDoor.leads_to`), and which tomb.
@export var leads_to := 1
@export var tomb_seed := 1
@export var difficulty := 1
## Which valley: another number bends the wadi otherwise and roughens the cliffs otherwise.
@export var seed := 1
@export var colour := Rock.LIMESTONE
## The way the wind blows over the ground (x, z), in its own space.
@export var wind := Vector2(1.0, 0.0)

## Its hills.
var cliff: Cliff
## Its doorways, in the order of their numbers.
var doors: Array[TombDoor] = []
## The path along its floor, and those up its branches: each a line of points (x, z) in its own space.
var paths: Array[PackedVector2Array] = []
## How many triangles it is drawn with.
var triangles := 0

var _made: Array[Node] = []


## A valley as an item of a level's layout says (see `LevelLayout.FIELDS`).
static func from_item(item: Dictionary) -> KingsValley:
	var made := KingsValley.new()
	made.size = item.get("size", 1.0)
	made.height = item.get("height", 16.0)
	made.tombs = int(item.get("tombs", 4))
	made.open_tomb = int(item.get("open", 1))
	made.leads_to = int(item.get("leads", 1))
	made.tomb_seed = int(item.get("tomb_seed", 1))
	made.difficulty = int(item.get("difficulty", 1))
	made.seed = int(item.get("seed", 1))
	return made


func _ready() -> void:
	build()


## Makes it (again) from its numbers.
func build() -> void:
	for old in _made:
		old.queue_free()
	_made.clear()
	doors.clear()
	paths.clear()
	# The block of hills, before the wadi is cut: its corners rounded and its sides not quite straight.
	var block := PackedVector2Array()
	for i in 20:
		var angle := TAU * i / 20.0
		var way := Vector2(cos(angle), sin(angle))
		var square := 1.0 / pow(pow(absf(way.x), 4.0) + pow(absf(way.y), 4.0), 0.25)
		block.append((Vector2(way.x * 50.0, way.y * 66.0 - 6.0) * square * lerpf(0.93, 1.0, Rock.chance(seed, 600 + i))) * size)
	# The wadi: in at the mouth, bending as it goes, to its head under the peak; and a branch off to each side.
	var bend := func(point: Vector2, key: int) -> Vector2:
		return (point + Vector2(Rock.chance(seed, key) - 0.5, Rock.chance(seed, key + 1) - 0.5) * 7.0) * size
	var main := PackedVector2Array([Vector2(0.0, 80.0) * size, bend.call(Vector2(2.0, 38.0), 610), bend.call(Vector2(-6.0, 12.0), 612), bend.call(Vector2(3.0, -12.0), 614), bend.call(Vector2(-3.0, -31.0), 616)])
	var west := PackedVector2Array([main[2], bend.call(Vector2(-22.0, 5.0), 620), bend.call(Vector2(-35.0, -3.0), 622)])
	var east := PackedVector2Array([main[3], bend.call(Vector2(18.0, -19.0), 630), bend.call(Vector2(31.0, -16.0), 632)])
	paths = [main, west, east]
	var wide := 12.5 * size
	var cut: Array = Geometry2D.offset_polyline(main, wide, Geometry2D.JOIN_ROUND, Geometry2D.END_ROUND)
	for branch: PackedVector2Array in [west, east]:
		for more: PackedVector2Array in Geometry2D.offset_polyline(branch, wide * 0.78, Geometry2D.JOIN_ROUND, Geometry2D.END_ROUND):
			var joined: Array = []
			for part: PackedVector2Array in cut:
				joined.append_array(Geometry2D.merge_polygons(part, more))
			# (what is left of the two is one outline, and perhaps a hole or two, which are let go)
			cut = joined.filter(func(part: PackedVector2Array) -> bool: return not Geometry2D.is_polygon_clockwise(part))
			cut.sort_custom(func(a: PackedVector2Array, b: PackedVector2Array) -> bool: return a.size() > b.size())
			cut = cut.slice(0, 1)
	var hills := block
	if not cut.is_empty():
		var left: Array = Geometry2D.clip_polygons(block, cut[0])
		left = left.filter(func(part: PackedVector2Array) -> bool: return not Geometry2D.is_polygon_clockwise(part))
		left.sort_custom(func(a: PackedVector2Array, b: PackedVector2Array) -> bool: return a.size() > b.size())
		if not left.is_empty():
			hills = left[0]
	# Where the doorways are: at the heads of the branches and of the wadi, and along its sides turn and turn about.
	var places: Array[Vector2] = []
	places.append(west[2] + (west[2] - west[1]).normalized() * wide)
	places.append(_beside(main, 1, 0.5, wide))
	places.append(east[2] + (east[2] - east[1]).normalized() * wide)
	places.append(_beside(main, 2, 0.55, -wide))
	places.append(main[4] + (main[4] - main[3]).normalized() * wide)
	places.append(_beside(main, 1, 0.45, -wide))
	places.append(_beside(main, 3, 0.5, wide))
	places.append(_beside(main, 0, 0.72, wide))
	var count := clampi(tombs, 0, places.size())
	cliff = Cliff.new()
	cliff.outline = hills
	cliff.height = height
	cliff.scree = 0.28
	cliff.rough = 1.1 * size
	cliff.ways = 1
	cliff.seed = seed
	cliff.colour = colour
	cliff.wind = wind
	for i in count:
		cliff.cuts.append([places[i], 3.4])
	_keep(cliff)
	# The doorways, and the dig round each: a heap of spoil tipped to one side and a wall to hold it.
	var builder := Rock.Builder.new()
	var solid: Array = []
	for i in mini(count, cliff.cut_places.size()):
		var at := cliff.cut_places[i]
		var door := TombDoor.new()
		door.number = NUMBERS[i]
		door.open = i + 1 == open_tomb
		door.leads_to = leads_to
		door.tomb_seed = tomb_seed
		door.difficulty = difficulty
		door.colour = colour
		door.drawn = false
		door.transform = at
		_keep(door)
		doors.append(door)
		builder.place = at
		TombDoor.add_to(builder, door.open, true)
		var side := 1.0 if Rock.chance(seed, 650 + i) < 0.5 else -1.0
		var heap := lerpf(4.0, 6.5, Rock.chance(seed, 660 + i))
		builder.place = at * Transform3D(Basis(Vector3.UP, Rock.chance(seed, 670 + i) * TAU).scaled_local(Vector3(heap, heap * 0.9, heap)), Vector3(side * -5.6, 0.0, 7.6))
		solid.append_array(builder.add(RockModels.pick("spoil_heap", seed + i)))
		if Rock.chance(seed, 680 + i) < 0.7:
			builder.place = at * Transform3D(Basis(Vector3.UP, side * 0.5 + PI * 0.5), Vector3(side * 5.2, 0.0, 9.5))
			solid.append_array(builder.add("rubble_wall"))
	# The peak, standing on the hills over the head of the wadi.
	var foot := 21.0 * size
	builder.place = Transform3D(Basis(Vector3.UP, 0.4).scaled_local(Vector3(foot, height * 1.5, foot)), Vector3(main[4].x - 4.0 * size, height - 0.5, main[4].y - 21.0 * size))
	solid.append_array(builder.add("el_qurn"))
	triangles = builder.triangles() + cliff.triangles
	var dig := StaticBody3D.new()
	var visual := MeshInstance3D.new()
	visual.mesh = builder.mesh(Rock.material(colour, seed, clampf(height * 0.06, 0.6, 1.4)), null, TombDoor.materials(colour))
	dig.add_child(visual)
	for hull: PackedVector3Array in solid:
		var shape := ConvexPolygonShape3D.new()
		shape.points = hull
		var collider := CollisionShape3D.new()
		collider.shape = shape
		dig.add_child(collider)
	_keep(dig)


func _keep(node: Node) -> void:
	add_child(node)
	_made.append(node)


# A place beside a line: so far along one of its stretches, and so far to one side.
func _beside(line: PackedVector2Array, stretch: int, share: float, off: float) -> Vector2:
	var along := line[stretch + 1] - line[stretch]
	return line[stretch].lerp(line[stretch + 1], share) + Vector2(along.y, -along.x).normalized() * off
