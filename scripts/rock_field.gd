class_name RockField
extends StaticBody3D
## A field of rocks: so many of them over so wide a round of ground, of sizes
## from one to another, no two alike, and the same every time from the same
## numbers. It is the White Desert's hundreds of chalk lumps, or a spread of
## dark rubble, or whatever `mix` says.
##
## It is cheap: every rock in it (`RockFormation.shape`: a model from
## `RockModels`, turned and made its own size) is put into one mesh, so the
## whole field is four draw calls (rock, and the sand banked against it, for
## the big rocks that throw shadows and again for the small ones and the
## stones scattered between, which do not). The stones are not solid. Each rock is solid, as a hull or two and one for its bank of sand.
##
## Where they stand: big ones first and far apart, small ones in the gaps,
## none touching. Each stands on the ground as it finds it: `ground` says how
## high the ground is at a place in its own space (the desert gives it its
## terrain); with none it is level.

## What is in it: [the kinds, as shares of the whole, in the order of `RockFormation.Kind`].
const MIXES := [
	[0.1, 0.34, 0.24, 0.14, 0.18, 0.0],
	[0.0, 0.55, 0.45, 0.0, 0.0, 0.0],
	[0.6, 0.15, 0.1, 0.05, 0.1, 0.0],
	[0.0, 0.1, 0.0, 0.0, 0.9, 0.0],
	[0.0, 0.0, 0.0, 0.0, 0.1, 0.9],
]
const MIX_NAMES: Array[String] = ["White Desert", "Domes and haystacks", "Mushrooms", "Shelves of bare rock", "Dark rubble"]

## How many rocks, and how far from its middle they reach, in metres.
@export var count := 40
@export var radius := 45.0
## The smallest and the biggest, in metres across.
@export var smallest := 1.0
@export var biggest := 7.0
## Which mix of shapes (`MIXES`).
@export var mix := 0
## Small stones lying between them: how many for each rock.
@export var stones := 2.0
## Which field: another number gives another.
@export var seed := 1
@export var colour := Rock.CHALK
## The way the wind blows over the ground (x, z), in its own space.
@export var wind := Vector2(1.0, 0.0)

## How high the ground is at a place (x, z) in the field's own space,
## measured from the field itself: a function of two floats. Left empty, level.
var ground: Callable

## Where each rock stands and how big it is: [place (in its own space), how far across, kind].
var rocks: Array = []
## How many triangles it is drawn with, and how many shapes it collides with.
var triangles := 0
var shapes := 0

var _made: Array[Node] = []


## A field as an item of a level's layout says (see `LevelLayout.FIELDS`).
static func from_item(item: Dictionary) -> RockField:
	var made := RockField.new()
	made.count = int(item.get("count", 40))
	made.radius = item.get("radius", 45.0)
	made.smallest = item.get("from", 1.0)
	made.biggest = maxf(item.get("to", 7.0), made.smallest)
	made.mix = clampi(int(item.get("mix", 0)), 0, MIXES.size() - 1)
	made.seed = int(item.get("seed", 1))
	made.colour = Rock.stone(int(item.get("stone", 0)))
	return made


func _ready() -> void:
	build()


## Makes it (again) from its numbers.
func build() -> void:
	for old in _made:
		old.queue_free()
	_made.clear()
	rocks.clear()
	shapes = 0
	var shares: Array = MIXES[clampi(mix, 0, MIXES.size() - 1)]
	# Where they stand. They are tried in order of size, biggest first, at
	# places made from `seed`, and one that would touch another is left out.
	# They are two meshes: the big rocks, which throw shadows, and the small ones and the stones, which do not
	# (whatever throws a shadow is drawn again for each of the sun's, and a small rock's is hardly seen).
	var builder := Rock.Builder.new()
	var small := Rock.Builder.new()
	var tall_enough := maxf(lerpf(smallest, biggest, 0.45), 2.5)
	var tries := count * 6
	var placed := 0
	for attempt in tries:
		if placed >= count:
			break
		var key := seed * 9176 + attempt * 131
		# (most are small)
		var share := float(placed) / maxf(count - 1.0, 1.0)
		var size := lerpf(biggest, smallest, pow(share, 0.45)) * lerpf(0.85, 1.15, Rock.chance(key, 1))
		var out := radius * sqrt(Rock.chance(key, 2)) * 0.96
		var angle := Rock.chance(key, 3) * TAU
		var at := Vector2(cos(angle), sin(angle)) * out
		var kind := _pick(shares, Rock.chance(key, 4))
		var room := size * (0.75 if kind != RockFormation.Kind.SHELF else 0.62)
		var crowded := false
		for other: Array in rocks:
			if at.distance_to(Vector2(other[0].x, other[0].z)) < room + float(other[1]) * 0.75:
				crowded = true
				break
		if crowded:
			continue
		# It stands as low as the lowest ground under it.
		var floor := _ground(at)
		for way: Vector2 in [Vector2.RIGHT, Vector2.UP, Vector2.LEFT, Vector2.DOWN]:
			floor = minf(floor, _ground(at + way * size * 0.4))
		var where := Vector3(at.x, floor, at.y)
		# (only the big ones throw shadows: see below)
		var into := builder if size >= tall_enough else small
		into.place = Transform3D(Basis.IDENTITY, where)
		var found := RockFormation.shape(into, kind, size, key & 0xffff, wind)
		rocks.append([where, size, kind])
		placed += 1
		for hull: PackedVector3Array in found["hulls"]:
			var solid := ConvexPolygonShape3D.new()
			solid.points = hull
			var collider := CollisionShape3D.new()
			collider.shape = solid
			_keep(collider)
			shapes += 1
	# Small stones between them: bits of the same rock, too small to be in anyone's way.
	for i in int(count * stones):
		var key := seed * 5519 + i * 977
		var out := radius * sqrt(Rock.chance(key, 2))
		var angle := Rock.chance(key, 3) * TAU
		var at := Vector2(cos(angle), sin(angle)) * out
		var size := lerpf(0.25, 0.7, Rock.chance(key, 1) * Rock.chance(key, 6))
		var inside := false
		for other: Array in rocks:
			if at.distance_to(Vector2(other[0].x, other[0].z)) < float(other[1]) * 0.55:
				inside = true
				break
		if inside:
			continue
		small.place = Transform3D(Basis.from_euler(Vector3(Rock.chance(key, 7) - 0.5, Rock.chance(key, 5) * TAU, Rock.chance(key, 8) - 0.5) * Vector3(0.6, 1.0, 0.6)).scaled_local(Vector3.ONE * size),
				Vector3(at.x, _ground(at) - size * 0.08, at.y))
		small.add(RockModels.pick("stone", key), lerpf(0.85, 1.0, Rock.chance(key, 10)))
	triangles = builder.triangles() + small.triangles()
	var visual := MeshInstance3D.new()
	visual.mesh = builder.mesh(Rock.material(colour, seed, 0.55))
	_keep(visual)
	var lesser := MeshInstance3D.new()
	lesser.mesh = small.mesh(Rock.material(colour, seed, 0.55))
	lesser.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_keep(lesser)


func _keep(node: Node) -> void:
	add_child(node)
	_made.append(node)


func _ground(at: Vector2) -> float:
	return float(ground.call(at.x, at.y)) if ground.is_valid() else 0.0


static func _pick(shares: Array, chance: float) -> int:
	var sum := 0.0
	for share: float in shares:
		sum += share
	var upto := 0.0
	for kind in shares.size():
		upto += float(shares[kind]) / sum
		if chance < upto:
			return kind
	return shares.size() - 1
