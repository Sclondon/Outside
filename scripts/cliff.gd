class_name Cliff
extends StaticBody3D
## A length of cliff, made from a line of points and a few numbers: its mesh
## and what is solid are worked out here when it enters the level (or when
## `build` is called), and the same numbers always make the same cliff.
##
## It is a body of rock with a flat top, `height` above its own origin, that
## he can walk on. All round it is a cliff band, nearly upright, set back in
## two ledges where harder beds stand out; and under the band an apron of
## scree, broken rock lying at the angle it comes to rest at, which he can walk
## up to the foot of the band. The line of the face goes in and out in
## buttresses and gullies (`rough`). Sand is drifted along the foot of the scree.
##
## What its plan is: `points` is a line over the ground (x, z), and the rock
## lies along it, `depth` across: an escarpment. With `closed` the points are a
## ring, and it is a mesa (or, small, a butte). Or `outline` gives the edge of
## its top directly, any shape at all: that is how `KingsValley` cuts a wadi
## into one.
##
## Ways up: at `ways` places a rake of ledges climbs the band from the top of
## the scree, each a step he can catch and pull up onto (as he does a course
## of a pyramid), the last onto the top. `ways_up` says where each starts.
##
## Cuttings: at each of `cuts` the scree is cleared away and the band comes
## down to the ground, as it was dug away from the mouth of a tomb.
## `cut_places` says where the foot of the face is there and which way it looks.
##
## It stands on the ground as it finds it: `ground` says how high the ground
## is at a place in its own space (the desert gives it its terrain), and the
## scree runs out to that. With none the ground is level, at its origin.
##
## What it costs: one mesh of two surfaces (rock, and the sand against it), a
## dozen triangles to every `STEP` metres of its edge. What is solid is hulls:
## the body in as few as its plan allows, a wedge of scree to every stretch of
## edge, and a block for every ledge. There is no inside to fall into.

## How far below its origin it goes on.
const FOOT := 4.0
## How far apart, in metres, the places along its edge are that it is built from.
const STEP := 4.0
## The angle scree lies at.
const REPOSE := deg_to_rad(36.0)
## How high a ledge of a way up is at most, and how long along the face.
const LEDGE_RISE := 1.3
const LEDGE_LONG := 2.5
## The face of the band, from its top down: [how far down (0..1), how far out, metres].
const FACE := [[0.0, 0.0], [0.2, 0.05], [0.2, 0.22], [0.58, 0.34], [0.58, 0.5], [1.0, 0.62]]

## The line it lies along (x, z), or with `closed` the ring it fills.
@export var points := PackedVector2Array([Vector2(-40.0, 0.0), Vector2(40.0, 0.0)])
@export var closed := false
## The edge of its top, given directly (then `points` and `depth` are not used).
@export var outline := PackedVector2Array()
## How high its top is, in metres.
@export var height := 14.0
## How far across its top is, for a line of points.
@export var depth := 12.0
## How much of its height is scree, 0..0.7.
@export_range(0.0, 0.7) var scree := 0.3
## How far its buttresses stand out and its gullies go in, in metres.
@export var rough := 2.0
## How many ways up it has.
@export var ways := 1
## Which cliff: another number gives other buttresses, other ledges.
@export var seed := 1
@export var colour := Rock.LIMESTONE
## The way the wind blows over the ground (x, z), in its own space: sand lies deepest in its lee.
@export var wind := Vector2(1.0, 0.0)

## How high the ground is at a place (x, z) in its own space, measured from
## its origin: a function of two floats. Left empty, level.
var ground: Callable
## Where the scree is cleared away: each [a place near its edge (x, z), how far to each side].
var cuts: Array = []

## The edge of its top as built, going round with the rock on the left.
var top := PackedVector2Array()
## For each of `cuts`: the foot of the face there, with +z pointing out of the rock.
var cut_places: Array[Transform3D] = []
## Where each way up starts: the top of the scree under its first ledge.
var ways_up: Array[Vector3] = []
## The ledges of each way up, from the bottom: for each way, the middle of the top of each ledge, and
## last a place on the top of the cliff itself, where the way comes out.
var ledges: Array = []
## How many triangles it is drawn with, and how many shapes it collides with.
var triangles := 0
var shapes := 0

var _made: Array[Node] = []


## A cliff as an item of a level's layout says (see `LevelLayout.FIELDS`): a
## line `length` long, bent round by `bend` degrees; or, as a "mesa", a ring.
static func from_item(item: Dictionary) -> Cliff:
	var made := Cliff.new()
	made.height = item.get("height", 14.0)
	made.scree = item.get("scree", 0.3)
	made.rough = item.get("rough", 2.0)
	made.ways = int(item.get("ways", 1))
	made.seed = int(item.get("seed", 1))
	made.colour = Rock.stone(int(item.get("stone", 1)))
	var line := PackedVector2Array()
	if item.get("what", "") == "mesa":
		made.closed = true
		var half: float = float(item.get("width", 40.0)) * 0.5
		for i in 14:
			var angle := TAU * i / 14.0
			line.append(Vector2(cos(angle), sin(angle)) * half * lerpf(0.78, 1.12, Rock.chance(made.seed, 300 + i)))
	elif item.has("points"):
		# (a line of points of its own, measured from where it stands)
		for point: Array in item["points"]:
			line.append(Vector2(point[0], point[1]))
	else:
		made.depth = item.get("depth", 12.0)
		var length: float = item.get("length", 80.0)
		var bend := deg_to_rad(item.get("bend", 0.0))
		var parts := maxi(int(ceil(length / 8.0)), 2)
		for i in parts + 1:
			var share := float(i) / parts - 0.5
			if absf(bend) < 0.02:
				line.append(Vector2(share * length, 0.0))
			else:
				var round_by := length / bend
				line.append(Vector2(sin(share * bend) * round_by, (cos(share * bend) - cos(bend * 0.5)) * round_by))
	made.points = line
	return made


func _ready() -> void:
	build()


## Makes it (again) from its numbers.
func build() -> void:
	for old in _made:
		old.queue_free()
	_made.clear()
	cut_places.clear()
	ways_up.clear()
	ledges.clear()
	shapes = 0
	var edge := _edge()
	var count := edge.size()
	if count < 3:
		return
	# Round its edge: where each place is, how far round, and which way is out.
	var around := PackedFloat32Array()
	var whole := 0.0
	for i in count:
		around.append(whole)
		whole += edge[i].distance_to(edge[(i + 1) % count])
	# Where the scree is cleared away.
	var cleared := PackedFloat32Array()
	cleared.resize(count)
	var cut_at: Array[int] = []
	for cut: Array in cuts:
		var nearest := 0
		for i in count:
			if edge[i].distance_squared_to(cut[0]) < edge[nearest].distance_squared_to(cut[0]):
				nearest = i
		cut_at.append(nearest)
		for i in count:
			var off := absf(around[i] - around[nearest])
			off = minf(off, whole - off)
			cleared[i] = maxf(cleared[i], 1.0 - smoothstep(float(cut[1]), float(cut[1]) + STEP * 0.75, off))
	# Buttresses and gullies: the edge goes out and in. (Not where a cutting is: the face is straight there.)
	var turn := whole / TAU
	var outs := _outs(edge)
	for i in count:
		var angle := around[i] / whole * TAU
		var bulge := (Rock.rough(cos(angle) * turn / 11.0 + seed * 1.7, sin(angle) * turn / 11.0 + seed * 0.3) - 0.5) * 1.7
		bulge -= 1.2 * smoothstep(0.7, 0.86, Rock.rough(cos(angle) * turn / 6.0 + 50.0, sin(angle) * turn / 6.0 + seed * 2.1))
		edge[i] += outs[i] * bulge * rough * (1.0 - cleared[i])
	outs = _outs(edge)
	top = edge
	# How high the scree stands at each place, and the ground there and at its foot.
	var band_out: float = FACE[FACE.size() - 1][1]
	var scree_top := PackedFloat32Array()
	var feet := PackedVector3Array()
	var band_feet := PackedVector3Array()
	for i in count:
		var angle := around[i] / whole * TAU
		var at := edge[i] + outs[i] * band_out
		var floor := _ground(at)
		var high := height * scree * lerpf(0.65, 1.3, Rock.rough(cos(angle) * turn / 15.0 + seed * 0.9, sin(angle) * turn / 15.0 + 7.0)) * (1.0 - cleared[i])
		high = minf(maxf(high, floor - 0.4), height - 1.0)
		scree_top.append(high)
		band_feet.append(Vector3(at.x, high, at.y))
		var run := maxf(high - floor, 0.0) / tan(REPOSE)
		var foot := at + outs[i] * run
		# (the ground may fall away from the cliff or rise to it: the scree runs out to where it meets it)
		for again in 2:
			run = maxf(high - _ground(foot), 0.0) / tan(REPOSE)
			foot = at + outs[i] * run
		feet.append(Vector3(foot.x, minf(_ground(foot), high) - 0.3, foot.y))

	var builder := Rock.Builder.new()
	for i in count:
		var next := (i + 1) % count
		var out := Vector3(outs[i].x + outs[next].x, 0.0, outs[i].y + outs[next].y)
		# The band, from its top down.
		for part in FACE.size() - 1:
			var corners: Array[Vector3] = []
			for corner: Array in [[i, part], [next, part], [next, part + 1], [i, part + 1]]:
				var which: int = corner[0]
				var face: Array = FACE[corner[1]]
				var at := edge[which] + outs[which] * float(face[1])
				corners.append(Vector3(at.x, lerpf(height, scree_top[which], face[0]), at.y))
			var ledge: bool = FACE[part][0] == FACE[part + 1][0]
			var tone := 0.9 + 0.2 * Rock.chance(seed * 7 + i, part)
			builder.quad(corners[0], corners[1], corners[2], corners[3], Vector3.UP if ledge else out, Color(tone, 0.5 if ledge else 0.0, 0.0))
		# The scree under it.
		if maxf(scree_top[i] - feet[i].y, scree_top[next] - feet[next].y) > 0.5:
			var tone := 0.88 + 0.12 * Rock.chance(seed * 11 + i, 3)
			builder.quad(band_feet[i], band_feet[next], feet[next], feet[i], out + Vector3.UP, Color(tone, 0.22, 1.0))
			_solid(PackedVector3Array([band_feet[i], band_feet[next], feet[i], feet[next],
				Vector3(edge[i].x, scree_top[i], edge[i].y), Vector3(edge[next].x, scree_top[next], edge[next].y),
				Vector3(edge[i].x, -FOOT, edge[i].y), Vector3(edge[next].x, -FOOT, edge[next].y),
				Vector3(feet[i].x, -FOOT, feet[i].z), Vector3(feet[next].x, -FOOT, feet[next].z)]))
			# And sand drifted along its foot, deepest in the lee.
			var drift: Array[Vector3] = []
			for which: int in [i, next]:
				var angle := around[which] / whole * TAU
				var lee := maxf(outs[which].dot(wind.normalized()), 0.0)
				var much := Rock.rough(cos(angle) * turn / 9.0 + 3.0, sin(angle) * turn / 9.0 + seed * 1.3)
				var rise := minf((0.2 + 0.55 * much) * (0.6 + 0.9 * lee), maxf(scree_top[which] - feet[which].y - 0.3, 0.0))
				var up := feet[which].lerp(band_feet[which], rise / maxf(scree_top[which] - feet[which].y, 0.01))
				var away := Vector3(outs[which].x, 0.0, outs[which].y) * (1.2 + 3.0 * much + 2.0 * lee)
				drift.append(up + Vector3.UP * 0.04)
				drift.append(feet[which] + away + Vector3.DOWN * 0.1)
			builder.sand_quad(drift[0], drift[2], drift[3], drift[1], out + Vector3.UP)
	# Its top.
	var corners_of := Geometry2D.triangulate_polygon(edge)
	for i in range(0, corners_of.size(), 3):
		var a := edge[corners_of[i]]
		var b := edge[corners_of[i + 1]]
		var c := edge[corners_of[i + 2]]
		builder.tri(Vector3(a.x, height, a.y), Vector3(b.x, height, b.y), Vector3(c.x, height, c.y), Vector3.UP, Color(1.0, 0.32, 0.0))
	# What is solid: the body, in pieces that have no hollows.
	var pieces := Geometry2D.decompose_polygon_in_convex(edge)
	if pieces.is_empty():
		for i in range(0, corners_of.size(), 3):
			pieces.append(PackedVector2Array([edge[corners_of[i]], edge[corners_of[i + 1]], edge[corners_of[i + 2]]]))
	if pieces.is_empty():
		pieces.append(edge)
	for piece: PackedVector2Array in pieces:
		var hull := PackedVector3Array()
		for at in piece:
			hull.append(Vector3(at.x, -FOOT, at.y))
			hull.append(Vector3(at.x, height, at.y))
		_solid(hull)
	# The cuttings.
	for index in cut_at:
		var out := Vector3(outs[index].x, 0.0, outs[index].y)
		var at := edge[index] + outs[index] * band_out
		cut_places.append(Transform3D(Basis(Vector3.UP.cross(out).normalized(), Vector3.UP, out), Vector3(at.x, _ground(at), at.y)))
	# The ways up: a rake of ledges along the face, each a step higher than the last.
	for way in ways:
		var start := int((way + 0.25 + 0.5 * Rock.chance(seed, 500 + way)) * count / maxi(ways, 1)) % count
		for again in count:
			# (not where the scree is cleared, nor up into a cutting)
			var clear := true
			for along in int(height / LEDGE_RISE * LEDGE_LONG / STEP) + 2:
				if cleared[(start + along) % count] > 0.0:
					clear = false
			if clear:
				break
			start = (start + 1) % count
		var from := scree_top[start]
		var steps := maxi(int(ceil((height - from) / LEDGE_RISE)), 1)
		var rise := (height - from) / steps
		ways_up.append(band_feet[start] + Vector3(outs[start].x, 0.0, outs[start].y) * 0.6)
		var tops: Array[Vector3] = []
		ledges.append(tops)
		for step in steps - 1:
			var along := around[start] + step * (LEDGE_LONG - 0.15)
			var index := start
			while around[(index + 1) % count] <= along and (index + 1) % count != 0 and index - start < count:
				index += 1
			index %= count
			var next := (index + 1) % count
			var share := clampf((along - around[index]) / maxf(edge[index].distance_to(edge[next]), 0.01), 0.0, 1.0)
			var at := edge[index].lerp(edge[next], share)
			var out := outs[index].lerp(outs[next], share).normalized()
			var high := from + (step + 1) * rise
			var low := minf(scree_top[index], scree_top[next]) - 1.2
			var deep := 2.6
			tops.append(Vector3(at.x + out.x * (band_out + 0.75), high, at.y + out.y * (band_out + 0.75)))
			if step == steps - 2:
				# (and from the last of them, the top itself: a little way in from its edge)
				tops.append(Vector3(at.x - out.x * 2.2, height, at.y - out.y * 2.2))
			var where := Transform3D(Basis(Vector3(out.y, 0.0, -out.x), Vector3.UP, Vector3(out.x, 0.0, out.y)),
					Vector3(at.x + out.x * (band_out + 1.45 - deep * 0.5), (high + low) * 0.5, at.y + out.y * (band_out + 1.45 - deep * 0.5)))
			_solid(builder.block(where, Vector3(LEDGE_LONG, high - low, deep), Color(0.95 + 0.12 * Rock.chance(seed * 3 + way, step), 0.0, 0.0), 0.1, seed * 41 + way * 17 + step))
	triangles = builder.triangles()
	var visual := MeshInstance3D.new()
	visual.mesh = builder.mesh(Rock.material(colour, seed, clampf(height * 0.06, 0.6, 1.4)))
	_keep(visual)


# The edge of its top, before it is roughened: places `STEP` apart all round
# it, going round with the rock on the left (so that out is to the right).
func _edge() -> PackedVector2Array:
	var plan := outline
	if plan.size() < 3:
		if closed and points.size() >= 3:
			plan = points
		elif points.size() >= 2:
			var around: Array = Geometry2D.offset_polyline(points, maxf(depth, 2.0) * 0.5, Geometry2D.JOIN_ROUND, Geometry2D.END_ROUND)
			plan = PackedVector2Array()
			for found: PackedVector2Array in around:
				if not Geometry2D.is_polygon_clockwise(found) and found.size() > plan.size():
					plan = found
			if plan.is_empty() and not around.is_empty():
				plan = around[0]
	if plan.size() < 3:
		return PackedVector2Array()
	var area := 0.0
	for i in plan.size():
		var next := plan[(i + 1) % plan.size()]
		area += plan[i].x * next.y - next.x * plan[i].y
	if area < 0.0:
		plan = plan.duplicate()
		plan.reverse()
	var whole := 0.0
	for i in plan.size():
		whole += plan[i].distance_to(plan[(i + 1) % plan.size()])
	var count := maxi(int(round(whole / STEP)), 6)
	var gap := whole / count
	var edge := PackedVector2Array()
	var side := 0
	var passed := 0.0
	for i in count:
		var along := i * gap
		while side < plan.size() - 1 and passed + plan[side].distance_to(plan[(side + 1) % plan.size()]) < along:
			passed += plan[side].distance_to(plan[(side + 1) % plan.size()])
			side += 1
		var long := plan[side].distance_to(plan[(side + 1) % plan.size()])
		edge.append(plan[side].lerp(plan[(side + 1) % plan.size()], clampf((along - passed) / maxf(long, 0.001), 0.0, 1.0)))
	return edge


# Which way is out at each place round an edge.
func _outs(edge: PackedVector2Array) -> PackedVector2Array:
	var outs := PackedVector2Array()
	var count := edge.size()
	for i in count:
		var along := (edge[(i + 1) % count] - edge[(i + count - 1) % count]).normalized()
		outs.append(Vector2(along.y, -along.x))
	return outs


func _ground(at: Vector2) -> float:
	return float(ground.call(at.x, at.y)) if ground.is_valid() else 0.0


func _solid(hull: PackedVector3Array) -> void:
	var shape := ConvexPolygonShape3D.new()
	shape.points = hull
	var collider := CollisionShape3D.new()
	collider.shape = shape
	_keep(collider)
	shapes += 1


func _keep(node: Node) -> void:
	add_child(node)
	_made.append(node)
