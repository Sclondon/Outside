class_name RockFormation
extends StaticBody3D
## A rock the wind has left standing. Its foot is at the origin, and it goes
## on a little way below, for ground that is not level.
##
## They are the shapes of the White Desert, where the wind has cut a chalk bed
## down into hundreds of them:
## - a mushroom: a thin stalk cut away at the foot, with a broad cap over it
##   (he can stand under the cap, and a hook will hold on the rim of a big one);
## - a dome, a haystack and a cone: lumps ringed with the ledges of their beds
##   and undercut at the foot;
## - a shelf: a low slab of bare rock breaking through the sand, to walk on;
## - an outcrop: dark broken blocks standing out of their own rubble, half
##   drowned in sand, as a ridge of harder rock shows through dunes.
## Sand is banked up round the foot of each, deepest in its lee (`wind`).
##
## The shapes themselves are models, made in Blender (`tools/build_rocks.py`,
## `tools/rocks.blend`; `RockModels` reads them): a few of each kind. What is
## done here is to pick one of the kind by `seed`, turn it so that its bank of
## sand lies downwind, make it `size` metres across (and a little taller or
## squatter, wider or narrower, by `seed`, so that two of one model are not
## alike), and make solid what the model says is solid: a hull or two for the
## rock and one for the bank of sand, which is walked up. The same numbers
## always make the same rock.
##
## It is drawn with `Rock` and, for the sand, `Sand`: two draw calls.
## `RockFormation.shape` is the same thing for anyone building many at once
## (`RockField`): it adds one to a `Rock.Builder`.

enum Kind { MUSHROOM, DOME, HAYSTACK, CONE, SHELF, OUTCROP }
## What each kind is called: in a level's layout, and (with `_a`, `_b`... after it) among the models.
const KINDS: Array[String] = ["mushroom", "dome", "haystack", "cone", "shelf", "outcrop"]
## How high each kind stands, as a share of how far across it is.
const TALL: Array[float] = [1.25, 0.5, 0.95, 0.8, 0.16, 0.42]

## Which shape it is.
@export var kind := Kind.DOME
## How far across, in metres.
@export var size := 6.0
## Which rock of its kind, and how it is turned and stretched: another number gives another.
@export var seed := 1
## The colour of its rock (`Rock.CHALK`, `LIMESTONE`, `SANDSTONE`, `BASALT`).
@export var colour := Rock.CHALK
## The way the wind blows over the ground (x, z), in its own space: sand lies deepest in its lee.
@export var wind := Vector2(1.0, 0.0)

## How high it stands as built, in metres.
var height := 0.0
## Which model it was made from.
var model := ""
## How many triangles it is drawn with, and how many shapes it collides with.
var triangles := 0
var shapes := 0

var _made: Array[Node] = []


## A rock as an item of a level's layout says (see `LevelLayout.FIELDS`).
static func from_item(item: Dictionary) -> RockFormation:
	var made := RockFormation.new()
	made.kind = maxi(KINDS.find(item.get("what", "dome")), 0) as Kind
	made.size = item.get("size", 6.0)
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
	var builder := Rock.Builder.new()
	var found := shape(builder, kind, size, seed, wind)
	height = found["height"]
	model = found["model"]
	triangles = builder.triangles()
	var visual := MeshInstance3D.new()
	visual.mesh = builder.mesh(Rock.material(colour, seed, clampf(size * 0.09, 0.3, 1.0)))
	_keep(visual)
	shapes = 0
	for hull: PackedVector3Array in found["hulls"]:
		var solid := ConvexPolygonShape3D.new()
		solid.points = hull
		var collider := CollisionShape3D.new()
		collider.shape = solid
		_keep(collider)
		shapes += 1
	if found["grapple"] != Vector3.INF:
		_keep(GrapplePoint.mark(self, found["grapple"]))


func _keep(node: Node) -> void:
	if node.get_parent() == null:
		add_child(node)
	_made.append(node)


## Adds one rock to a builder, where the builder's `place` is. Says what came
## of it: `model` (which one), `height`, `radius` (how far its foot reaches),
## `hulls` (what is solid, each a set of points in the builder's own space)
## and `grapple` (where a hook would hold, or Vector3.INF).
static func shape(builder: Rock.Builder, kind: int, size: float, seed: int, wind := Vector2(1.0, 0.0)) -> Dictionary:
	var found := {"model": RockModels.pick(KINDS[kind], seed), "height": size * TALL[kind], "radius": size * 0.75, "hulls": [], "grapple": Vector3.INF}
	# Its bank of sand is deepest on the model's +x side: that is turned downwind, give or take.
	var turn := atan2(-wind.y, wind.x) + (Rock.chance(seed, 61) - 0.5) * 1.2
	var taller := lerpf(0.82, 1.2, Rock.chance(seed, 62))
	var stretch := Vector3(size, size * taller, size * lerpf(0.85, 1.15, Rock.chance(seed, 63)))
	var was := builder.place
	builder.place = was * Transform3D(Basis(Vector3.UP, turn).scaled_local(stretch), Vector3.ZERO)
	found["hulls"] = builder.add(found["model"], lerpf(0.9, 1.0, Rock.chance(seed, 64)))
	found["height"] = size * TALL[kind] * taller
	if kind == Kind.MUSHROOM and size >= 3.0 and (found["hulls"] as Array).size() > 1:
		# (a hook holds on the rim of its cap, where it hangs furthest out)
		var middle: Vector3 = was.origin
		var furthest := Vector3.INF
		for point: Vector3 in found["hulls"][1]:
			if furthest == Vector3.INF or Vector2(point.x - middle.x, point.z - middle.z).length() > Vector2(furthest.x - middle.x, furthest.z - middle.z).length():
				furthest = point
		found["grapple"] = furthest
	builder.place = was
	return found
