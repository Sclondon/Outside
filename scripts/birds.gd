class_name Birds
extends Node3D
## Birds: `count` of one `kind`, living within `roam` metres of where this node
## is put. `Birds.new()` with those set is the whole of it.
##
## The kinds are the birds of the Nile and its desert (`BirdKinds`; README.md says where they come from):
## sparrows and doves about the camp and the ruins in flocks, a hoopoe walking
## the ground, swallows skimming the water, the sacred ibis, the grey heron and
## the cattle egret wading at its edge, Egyptian geese on it, a kestrel and a
## pied kingfisher that hang in the air over one spot and drop, and the
## Egyptian vulture, the griffon and the black kite wheeling high up.
##
## They find for themselves where to be. When it has been in the level a
## moment a flock looks round it (`rescan`): for the flat tops of whatever is
## solid (a column, a wall, the crown of a palm, a block), for any Marker3D in
## the groups `bird_perches` or `perches`, for open ground, and, in whatever is
## in the group `water`, for shallows to wade in and water to swim on.
##
## They mind the boy. Walk up to them and they stop feeding and watch; come
## closer, or run at them, and they are up: a flock all together, to wheel
## about and come down on the nearest high things, and back to the ground when
## it has been quiet a while; a heron or a goose off round in a wide circle and
## down somewhere further from him. A gun going off (anything in the group
## `guns` that emits `fired`) puts up every bird that hears it. Vultures come
## down in narrowing circles over anything in the group `carrion`, and over the
## boy if he lies knocked down for long, and land round it.
##
## There are no bodies and no bones. Each bird is a few numbers; all of one
## kind here are drawn at once by a MultiMesh, their wings beaten, necks bent
## and legs swung by the shader (`BirdMesh`), and one far off is drawn from a
## mesh of a couple of dozen triangles. What it costs is in `cost`.

## It went up in alarm: how many of them.
signal flushed(how_many: int)

enum Kind { SPARROW, DOVE, HOOPOE, SWALLOW, IBIS, HERON, EGRET, GOOSE, KESTREL, KINGFISHER, VULTURE, GRIFFON, KITE }
## STAND: on its feet, or afloat. WALK: or hopping, or swimming. SOAR: circling
## high up. HOVER: hanging over one spot. STOOP: dropping from there.
enum State { STAND, WALK, TAKEOFF, FLY, LAND, SOAR, HOVER, STOOP }
## What it does where it stands.
enum Act { NONE, PECK, PREEN, ONE_LEG, ALERT }
## What a flight ends in: down at `goal`; round and round; hanging over `goal`; on to somewhere else; back up to soar.
enum Then { LAND, WHEEL, HOVER, ROAM, SOAR }
## A place to be: open ground, the top of something, shallows, open water.
enum Where { GROUND, TOP, WADE, WATER }

const Habit := BirdKinds.Habit
const GRAVITY := 9.8
## How far off a shot is heard.
const EARSHOT := 90.0

@export var kind := Kind.DOVE
@export_range(1, 60) var count := 8
## How far from here they go.
@export var roam := 30.0

## The boy. Found by itself if it is not given.
var target: Player
## They do nothing of themselves: whoever set this poses each bird (see `Bird`).
var manual := false
## What the birds here cost each frame, in microseconds (thinking, moving and handing them to be drawn), smoothed.
var cost := 0.0
var birds: Array[Bird] = []
var spots: Array[Spot] = []

var _k: Dictionary
var _habit: int
var _frame: Dictionary
var _home := Vector3.ZERO
var _near: MultiMeshInstance3D
var _far: MultiMeshInstance3D
var _near_data := PackedFloat32Array()
var _far_data := PackedFloat32Array()
var _scan_in := 4
var _scanned := false
var _pools: Array[Pool] = []
var _highest := -INF
var _tick := 0
var _find := 0.0
# The flock: the patch of ground it feeds on, the circle it wheels round, and how long it has been left in peace.
var _area := Vector3.ZERO
var _wheel_at := Vector3.ZERO
var _wheel_left := 0.0
var _wheel_turn := 0.0
var _wheel_angle := 0.0
var _quiet := 100.0
# What the soarers circle over; and what lies dead there (Vector3.INF: nothing), and for how long.
var _over := Vector3.ZERO
var _dead := Vector3.INF
var _dead_for := 0.0
var _limp_for := 0.0
var _spent := 0
var _flat := false
var _placed := false
var _tries := 0
var _checked := 0
var _frames := 0
var _owed := 0.0
# What `1 - exp(-rate * delta)` is this frame, for each whole rate: how far a thing eases towards where it is wanted.
var _blend := PackedFloat32Array()
var _blend_for := -1.0
# The numbers of the kind that are wanted every frame.
var _n_speed := 0.0
var _n_turn := 0.0
var _n_beat := 0.0
var _n_depth := 0.0
var _n_dihedral := 0.0
var _n_droop := 0.0
var _n_glide := 0.0
var _n_bound := 0.0
var _n_bound_rise := 0.0
var _n_cruise := 0.0
var _n_size := 0.0
var _n_stance := 0.0
var _n_crest := 0.0
var _n_walk := 0.0
var _n_reach := 0.0

var _heard := {}


## One bird. Where it is and what it is doing, and how it is posed. With
## `manual` set on the flock, set `at`, `yaw`, `pitch`, `roll` and the pose
## (`wing_in`, `wing_out`, `fold`, `legs`, `neck_low`, `neck_high`, `head`,
## `extra`: see `BirdMesh`) yourself.
class Bird:
	var at := Vector3.ZERO
	var going := Vector3.ZERO
	var yaw := 0.0
	var pitch := 0.0
	var roll := 0.0
	var state := State.STAND
	var act := Act.NONE
	var then := Then.LAND
	## How long it has been in this state; how long until it thinks again; how long its act has run and is to run.
	var time := 0.0
	var pause := 0.0
	var act_time := 0.0
	var act_length := 0.0
	var goal := Vector3.ZERO
	var from := Vector3.ZERO
	var from_going := Vector3.ZERO
	var length := 1.0
	var spot: Spot
	var afloat: Pool
	## Alarmed: how long until it goes up (under 0: it is not), and what at.
	var startle := -1.0
	var fear := Vector3.INF
	var wary := 0.0
	## Wants the flock to say what it does next.
	var ask := false
	var beat := 0.0
	var flap := 0.0
	var effort := 1.0
	var bout := 0.0
	var wing_in := 0.0
	var wing_out := 0.0
	var fold := 1.0
	var legs := 1.0
	var neck_low := 0.0
	var neck_high := 0.0
	var head := 0.0
	var extra := 0.0
	var stride := 0.0
	var lift := 0.0
	var size := 1.0
	var slot := Vector3.ZERO
	var number := 0
	## The ground under where it is flying to, and when it last looked.
	var ground := -INF
	var looked := 0.0
	var dodge := Vector3.ZERO
	var dodge_left := 0.0
	var hidden := 0.0
	## Circling: what round, how far out, how high, which way, and how far round it is.
	var about := Vector3.ZERO
	var wide := 10.0
	var high := 5.0
	var turn := 1.0
	var angle := 0.0
	var wheel_left := 0.0
	var rippled := 0.0
	var rounds := 0
	var push := Vector3.ZERO
	## Nearly down: the ground may be come to.
	var close := false
	## It has not stirred since it was last drawn; and which mesh it was drawn from (0: neither, 1: near, 2: far; -1: not yet).
	var still := false
	var shown := -1
	var sunk := 0.0


## Somewhere a bird can be.
class Spot:
	var at := Vector3.ZERO
	var where := Where.GROUND
	## A top: how far above the ground round it. Ground: whether it is at the water's edge.
	var high := 0.0
	var shore := false
	var pool: Pool
	var user: Bird


func _ready() -> void:
	add_to_group(&"birds")
	_k = BirdKinds.of(kind)
	_habit = _k["habit"]
	_frame = BirdMesh.frame(kind)
	_n_speed = _k["speed"]
	_n_turn = _k["turn"]
	_n_beat = _k["beat"]
	_n_depth = _k["depth"]
	_n_dihedral = _k["dihedral"]
	_n_droop = _k["droop"]
	_n_glide = _k["glide"]
	_n_bound = _k["bound"]
	_n_bound_rise = _k["bound_rise"]
	_n_cruise = _k["cruise"]
	_n_size = _k["size"]
	_n_stance = _k["stance"]
	_n_crest = _k["crest"]
	_n_walk = _k["walk"]
	_n_reach = _frame["reach"]
	_blend.resize(32)
	_set_blend(1.0 / 60.0)
	_home = global_position
	_over = _home
	_near = _drawn(BirdMesh.near(kind), true)
	_far = _drawn(BirdMesh.far(kind), false)
	for i in count:
		var b := Bird.new()
		b.number = i
		b.size = randf_range(0.92, 1.08)
		b.at = _home
		b.beat = randf() * TAU
		b.bout = randf() * 3.0
		birds.append(b)
	_near_data.resize(count * 20)
	_far_data.resize(count * 20)
	_near_data.fill(0.0)
	_far_data.fill(0.0)
	_near.multimesh.buffer = _near_data
	_far.multimesh.buffer = _far_data
	_stand_in()


func _drawn(mesh: Mesh, shadow: bool) -> MultiMeshInstance3D:
	var made := MultiMeshInstance3D.new()
	made.multimesh = MultiMesh.new()
	made.multimesh.transform_format = MultiMesh.TRANSFORM_3D
	made.multimesh.use_colors = true
	made.multimesh.use_custom_data = true
	made.multimesh.mesh = mesh
	made.multimesh.instance_count = count
	made.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON if shadow else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	# (they are wherever they have flown to)
	made.extra_cull_margin = 16384.0
	add_child(made)
	made.top_level = true
	made.global_transform = Transform3D.IDENTITY
	return made


func _exit_tree() -> void:
	# (a bird and its place know each other: left so, neither would ever be let go)
	for b in birds:
		b.spot = null
	for spot in spots:
		spot.user = null


func _set_blend(delta: float) -> void:
	if delta == _blend_for:
		return
	_blend_for = delta
	for rate in 32:
		_blend[rate] = 1.0 - exp(-rate * delta)


## Until they have looked round them (and in the level's editor, where nothing runs, for as long as it is
## open) they are shown standing about where they were put, and the soarers on their circles over it.
func _stand_in() -> void:
	var stand: Array = _k["stand"]
	for b in birds:
		b.hidden = 0.0
		b.yaw = randf() * TAU
		var way := randf() * TAU
		b.at = _home + Vector3(cos(way), 0.0, sin(way)) * sqrt(randf()) * minf(_patch() + 1.0, roam)
		b.neck_low = stand[0]
		b.neck_high = stand[1]
		b.head = stand[2] - _n_stance - b.neck_low - b.neck_high
		if _habit == Habit.SOARER or _habit == Habit.SKIMMER:
			var fly: Array = _k["fly"]
			b.about = _home
			b.wide = _soar_wide() * randf_range(0.7, 1.1) if _habit == Habit.SOARER else randf_range(2.0, 6.0)
			b.high = _home.y + (_k["soar_height"] * randf_range(0.75, 1.3) if _habit == Habit.SOARER else randf_range(0.6, 2.5))
			b.angle = way
			b.at = _on_circle(b)
			b.yaw = atan2(_circle_way(b).x, _circle_way(b).z)
			b.fold = 0.0
			b.legs = 0.0
			b.wing_in = _n_dihedral
			b.wing_out = _n_dihedral * 1.5 - _n_droop
			b.neck_low = fly[0]
			b.neck_high = fly[1]
			b.head = fly[2] - b.neck_low - b.neck_high
	_draw.call_deferred()


## Looks round again for places to be, and puts every bird at one. A level that changes under them can call this.
func rescan(put_back := true) -> void:
	_scan_in = 2
	_scanned = false
	if put_back:
		_placed = false


## Alarms every bird within `within` metres of `from` (all of them, if it is not given).
func flush(from: Vector3, within := INF) -> void:
	var up := 0
	for b in birds:
		if (b.state == State.STAND or b.state == State.WALK or b.state == State.HOVER) and b.startle == -1.0 and b.at.distance_to(from) < within:
			b.startle = randf_range(0.0, 0.35)
			b.fear = from
			up += 1
	if up > 0:
		_quiet = 0.0
		flushed.emit(up)


## How many of them are on the ground, on a perch or on the water.
func settled() -> int:
	var down := 0
	for b in birds:
		if b.state == State.STAND or b.state == State.WALK:
			down += 1
	return down


func _physics_process(delta: float) -> void:
	var began := Time.get_ticks_usec()
	_tick += 1
	if not _scanned:
		_scan_in -= 1
		if _scan_in <= 0:
			_scan()
		if not _placed:
			return
	if manual:
		return
	if global_position.distance_to(_home) > 0.5:
		# (it has been moved: the level's editor does that)
		_home = global_position
		_over = _home
		rescan()
		return
	_find -= delta
	if _find <= 0.0:
		_find = 2.0
		_look_about()
	if _tick % 6 == 0:
		_mind(delta * 6.0)
	_quiet += delta
	for b in birds:
		if b.ask:
			b.ask = false
			_decide(b)
		elif b.state == State.STAND and b.pause <= 0.0 and b.startle == -1.0:
			_idle(b)
		if b.state == State.WALK and not b.afloat and (_tick + b.number) % 4 == 0 and not _flat:
			var under := _ground_at(b.at.x, b.at.z, b.at.y, 2.0)
			b.ground = under if not is_nan(under) else b.at.y
		if b.state == State.FLY or b.state == State.TAKEOFF:
			b.looked -= delta
			if b.looked <= 0.0:
				b.looked = 0.2 + 0.02 * (b.number % 5)
				_look_ahead(b)
	if _habit == Habit.SOARER and _tick % 30 == 0:
		_carrion(delta * 30.0)
	_spent += Time.get_ticks_usec() - began


func _process(delta: float) -> void:
	var began := Time.get_ticks_usec()
	if _placed and not manual:
		# A long way from whoever is looking, and they are seen to one frame in four.
		var camera := get_viewport().get_camera_3d()
		_owed += delta
		if camera and _habit != Habit.SOARER and camera.global_position.distance_squared_to(_home) > (roam + 90.0) * (roam + 90.0) and (Engine.get_process_frames() + count) % 4 != 0:
			_spent += Time.get_ticks_usec() - began
			cost = lerpf(cost, float(_spent), 0.05)
			_spent = 0
			return
		delta = _owed
		_owed = 0.0
		_frames += 1
		_flock(delta)
		# (a bird on its feet is seen to every other frame, half of them each; one in the air every frame)
		var odd := _frames % 2
		for b in birds:
			if b.state > State.WALK:
				_set_blend(delta)
				_live(b, delta)
			elif b.number % 2 == odd:
				_set_blend(delta * 2.0)
				_live(b, delta * 2.0)
			else:
				b.still = true
	_draw()
	_spent += Time.get_ticks_usec() - began
	cost = lerpf(cost, float(_spent), 0.05)
	_spent = 0


# ---------------------------------------------------------------- finding places

## Looks for places to be within reach of home, and puts the birds at them.
func _scan() -> void:
	_scanned = true
	spots.clear()
	_pools.clear()
	_highest = _home.y
	var space := get_world_3d().direct_space_state
	for node: Node in get_tree().get_nodes_in_group(&"water"):
		var pool := node as Pool
		if pool and Vector2(pool.global_position.x - _home.x, pool.global_position.z - _home.z).length() < roam + maxf(pool.size.x, pool.size.z):
			_pools.append(pool)
	# What the level has marked.
	for group: StringName in [&"bird_perches", &"perches"]:
		for node: Node in get_tree().get_nodes_in_group(group):
			var mark := node as Node3D
			if mark and mark.global_position.distance_to(_home) < roam:
				var under := _ground_at(mark.global_position.x + 1.5, mark.global_position.z, mark.global_position.y)
				_add_spot(mark.global_position, Where.TOP, 2.0 if is_nan(under) else mark.global_position.y - under)
	# The tops of solid things.
	var ball := SphereShape3D.new()
	ball.radius = maxf(roam, 20.0)
	var query := PhysicsShapeQueryParameters3D.new()
	query.shape = ball
	query.transform = Transform3D(Basis.IDENTITY, _home)
	query.collision_mask = 1
	var seen := {}
	for found: Dictionary in space.intersect_shape(query, 160):
		var body := found["collider"] as CollisionObject3D
		if body == null or seen.has(body):
			continue
		seen[body] = true
		for child in body.get_children():
			var solid := child as CollisionShape3D
			if solid == null or solid.disabled or solid.shape == null or _is_ground(solid):
				continue
			var box := solid.global_transform * _bounds(solid.shape)
			if box.size == Vector3.ZERO:
				continue
			_highest = maxf(_highest, box.end.y)
			var middle := box.get_center()
			_try_top(Vector3(middle.x, box.end.y, middle.z), body, maxf(box.size.x, box.size.z) * 0.5)
			if maxf(box.size.x, box.size.z) > 2.0:
				for extra in 3:
					_try_top(Vector3(middle.x + box.size.x * randf_range(-0.38, 0.38), box.end.y, middle.z + box.size.z * randf_range(-0.38, 0.38)), body, 0.6)
	# Ground, the water's edge, and water: here and there all round, and closely round each pool.
	var places: Array[Vector2] = []
	for i in 44:
		var out := sqrt(randf()) * roam if i >= 14 else randf_range(0.5, minf(roam, 7.0))
		var way := randf() * TAU
		places.append(Vector2(_home.x + cos(way) * out, _home.z + sin(way) * out))
	for pool in _pools:
		for i in 48:
			places.append(Vector2(pool.global_position.x + (pool.size.x * 0.5 + 2.0) * randf_range(-1.0, 1.0), pool.global_position.z + (pool.size.z * 0.5 + 2.0) * randf_range(-1.0, 1.0)))
	for place in places:
		if Vector2(place.x - _home.x, place.y - _home.z).length() > roam:
			continue
		var ray := PhysicsRayQueryParameters3D.create(Vector3(place.x, _home.y + 60.0, place.y), Vector3(place.x, _home.y - 40.0, place.y), 1)
		var hit := space.intersect_ray(ray)
		if hit.is_empty():
			continue
		var at: Vector3 = hit["position"]
		var pool := _pool_over(at)
		var deep := pool.surface_y() - at.y if pool else -1.0
		if deep > 0.02:
			if deep < maxf(_k["wade"], 0.12):
				_add_spot(at, Where.WADE, 0.0, pool)
			if deep > 0.25:
				_add_spot(Vector3(at.x, pool.surface_y(), at.z), Where.WATER, 0.0, pool)
		elif (hit["normal"] as Vector3).y > 0.85:
			var body := hit["collider"] as CollisionObject3D
			var solid := body.shape_owner_get_owner(body.shape_find_owner(hit["shape"])) as CollisionShape3D if body else null
			if solid == null or _is_ground(solid):
				var spot := _add_spot(at, Where.GROUND)
				for near in _pools:
					var off := at - near.global_position
					if absf(off.x) < near.size.x * 0.5 + 2.0 and absf(off.z) < near.size.z * 0.5 + 2.0 and absf(off.y) < 0.6:
						spot.shore = true
			elif _clear_over(at):
				_add_spot(at, Where.TOP, maxf(at.y - _home.y, 0.5))
	_flat = spots.is_empty()
	if spots.is_empty() or not _has(Where.GROUND):
		# Nothing solid anywhere (an empty stage): the level of home will do for ground.
		for i in 12:
			var way := TAU * i / 12.0
			_add_spot(_home + Vector3(cos(way), 0.0, sin(way)) * minf(roam * 0.5, 2.0 + i), Where.GROUND)
	if _flat and _tries < 8:
		# (the ground may not be made yet: another look in a moment)
		_tries += 1
		_scan_in = 45
		_scanned = false
	elif _placed:
		# The birds stay where they are; those whose places are gone will find others.
		for b in birds:
			b.spot = null
	else:
		_place_all()
		_placed = true


func _add_spot(at: Vector3, where: Where, high := 0.0, pool: Pool = null) -> Spot:
	var spot := Spot.new()
	spot.at = at
	spot.where = where
	spot.high = high
	spot.pool = pool
	spots.append(spot)
	return spot


func _has(where: Where) -> bool:
	for spot in spots:
		if spot.where == where:
			return true
	return false


## Whether a solid is the ground itself (and not something standing on it).
func _is_ground(solid: CollisionShape3D) -> bool:
	var shape := solid.shape
	if shape is ConcavePolygonShape3D or shape is HeightMapShape3D or shape is WorldBoundaryShape3D:
		return true
	if shape is BoxShape3D:
		var size := (shape as BoxShape3D).size * solid.global_basis.get_scale()
		return maxf(size.x, size.z) >= 16.0
	return false


## The box a shape fits in, in its own space.
func _bounds(shape: Shape3D) -> AABB:
	if shape is BoxShape3D:
		var size := (shape as BoxShape3D).size
		return AABB(-size * 0.5, size)
	if shape is CylinderShape3D:
		var r := (shape as CylinderShape3D).radius
		var h := (shape as CylinderShape3D).height
		return AABB(Vector3(-r, -h * 0.5, -r), Vector3(r * 2.0, h, r * 2.0))
	if shape is CapsuleShape3D:
		var r := (shape as CapsuleShape3D).radius
		var h := (shape as CapsuleShape3D).height
		return AABB(Vector3(-r, -h * 0.5, -r), Vector3(r * 2.0, h, r * 2.0))
	if shape is SphereShape3D:
		var r := (shape as SphereShape3D).radius
		return AABB(Vector3(-r, -r, -r), Vector3.ONE * r * 2.0)
	if shape is ConvexPolygonShape3D:
		var points := (shape as ConvexPolygonShape3D).points
		if points.is_empty():
			return AABB()
		var box := AABB(points[0], Vector3.ZERO)
		for point in points:
			box = box.expand(point)
		return box
	return AABB()


## A perch on top of something, if there is a flat place there with air over it, well off the ground.
func _try_top(at: Vector3, body: CollisionObject3D, half: float) -> void:
	var space := get_world_3d().direct_space_state
	var hit := space.intersect_ray(PhysicsRayQueryParameters3D.create(at + Vector3.UP * 0.5, at + Vector3.DOWN * 0.7, 1))
	if hit.is_empty() or (hit["normal"] as Vector3).y < 0.7 or hit["collider"] != body:
		return
	var top: Vector3 = hit["position"]
	if not _clear_over(top) or _pool_over(top) != null and _pool_over(top).surface_y() > top.y:
		return
	# How far up it is: over the ground a little way out from it on each side.
	var lowest := INF
	for way: Vector3 in [Vector3.RIGHT, Vector3.LEFT, Vector3.BACK, Vector3.FORWARD]:
		var from := top + way * (half + 0.7) + Vector3.UP * 0.2
		var ray := PhysicsRayQueryParameters3D.create(from, from + Vector3.DOWN * 40.0, 1)
		ray.exclude = [body.get_rid()]
		var under := space.intersect_ray(ray)
		lowest = minf(lowest, (under["position"] as Vector3).y if not under.is_empty() else top.y - 40.0)
	_highest = maxf(_highest, top.y)
	if top.y - lowest > 0.45:
		_add_spot(top, Where.TOP, top.y - lowest)


## Whether there is air over a point and round it: room for a bird to stand there.
func _clear_over(at: Vector3) -> bool:
	var space := get_world_3d().direct_space_state
	var query := PhysicsPointQueryParameters3D.new()
	query.collision_mask = 1
	var room := clampf(_n_reach * 0.35, 0.1, 0.3)
	for off: Vector3 in [Vector3.ZERO, Vector3(room, -0.12, 0.0), Vector3(-room, -0.12, 0.0), Vector3(0.0, -0.12, room), Vector3(0.0, -0.12, -room)]:
		query.position = at + Vector3.UP * 0.3 + off
		if not space.intersect_point(query, 1).is_empty():
			return false
	return true


## The water a point is in or over, if any.
func _pool_over(at: Vector3) -> Pool:
	for pool in _pools:
		if is_instance_valid(pool):
			var off := at - pool.global_position
			if absf(off.x) < pool.size.x * 0.5 and absf(off.z) < pool.size.z * 0.5:
				return pool
	return null


## The height of the ground (or whatever is solid) under a place, looking down from a little over `about`. NAN: none.
func _ground_at(x: float, z: float, about: float, reach := 8.0) -> float:
	var ray := PhysicsRayQueryParameters3D.create(Vector3(x, about + 3.0, z), Vector3(x, about - reach, z), 1)
	var hit := get_world_3d().direct_space_state.intersect_ray(ray)
	if hit.is_empty():
		return _home.y if _flat else NAN
	return (hit["position"] as Vector3).y


## A free place of one of `wheres`, the best by: near `about`, at least `clear` from `away` (if that is given), and, with `tall`, as high as may be.
func _pick(wheres: Array, about: Vector3, away := Vector3.INF, clear := 0.0, tall := 0.0, scatter := 4.0) -> Spot:
	var best: Spot = null
	var most := -INF
	for spot in spots:
		if spot.user != null or not spot.where in wheres:
			continue
		if away != Vector3.INF and spot.at.distance_to(away) < clear:
			continue
		var score := -spot.at.distance_to(about) + spot.high * tall + randf() * scatter
		if score > most:
			most = score
			best = spot
	return best


func _take(b: Bird, spot: Spot) -> void:
	_leave(b)
	b.spot = spot
	if spot:
		spot.user = b


func _leave(b: Bird) -> void:
	if b.spot and b.spot.user == b:
		b.spot.user = null
	b.spot = null


## How much a perch being high counts for: a kestrel wants the top of the tallest thing there is; a kingfisher anything over the water.
func _tall() -> float:
	return 2.5 if kind == Kind.KESTREL else 0.3


## Where the kind likes to be, best first.
func _likes() -> Array:
	match _habit:
		Habit.WADER:
			return [[Where.WADE], [Where.GROUND]]
		Habit.WATERFOWL:
			return [[Where.WATER], [Where.GROUND]]
		Habit.HOVERER:
			return [[Where.TOP], [Where.GROUND]]
	return [[Where.GROUND]]


## Puts every bird where it would be if it had been here all day.
func _place_all() -> void:
	for spot in spots:
		spot.user = null
	var ground := _pick([Where.GROUND], _home, Vector3.INF, 0.0, 0.0, 1.0)
	_area = ground.at if ground else _home
	_wheel_left = 0.0
	for b in birds:
		b.hidden = 0.0
		b.startle = -1.0
		b.ask = false
		b.afloat = null
		b.yaw = randf() * TAU
		b.pitch = 0.0
		b.roll = 0.0
		b.going = Vector3.ZERO
		b.pause = randf_range(0.2, 3.0)
		_enter(b, State.STAND)
		match _habit:
			Habit.SOARER:
				_enter(b, State.SOAR)
				b.about = _over
				b.wide = _soar_wide() * randf_range(0.7, 1.1)
				b.high = maxf(_highest, _home.y) + _k["soar_height"] * randf_range(0.75, 1.3)
				b.turn = 1.0 if b.number % 3 != 0 else -1.0
				b.angle = randf() * TAU
				b.at = _on_circle(b)
			Habit.SKIMMER:
				_enter(b, State.FLY)
				b.then = Then.ROAM
				b.at = _home + Vector3(randf_range(-4.0, 4.0), randf_range(2.0, 5.0), randf_range(-4.0, 4.0))
				b.going = Vector3(sin(b.yaw), 0.0, cos(b.yaw)) * _n_speed
				b.goal = b.at
				b.ask = true
			Habit.FLOCK:
				_put_down(b, _near_area(b))
			_:
				var spot: Spot = null
				for wheres: Array in _likes():
					spot = _pick(wheres, _home, Vector3.INF, 0.0, _tall() if _habit == Habit.HOVERER else 0.0, 6.0)
					if spot:
						break
				_take(b, spot)
				_put_down(b, spot.at if spot else _home)


## Stands a bird at a place (on the water, if it is a place on it).
func _put_down(b: Bird, at: Vector3) -> void:
	b.at = at
	b.going = Vector3.ZERO
	b.pitch = 0.0
	b.roll = 0.0
	b.afloat = b.spot.pool if b.spot and b.spot.where == Where.WATER else null
	_enter(b, State.STAND)


## A place on the flock's patch of ground for one of it.
func _near_area(b: Bird) -> Vector3:
	var wide := _patch()
	for attempt in 6:
		var way := randf() * TAU
		var out := sqrt(randf()) * wide
		var at := _area + Vector3(cos(way) * out, 0.0, sin(way) * out)
		var y := _ground_at(at.x, at.z, _area.y, 3.0)
		if not is_nan(y) and absf(y - _area.y) < 0.6 and _pool_over(at) == null:
			return Vector3(at.x, y, at.z)
	return _area


# ---------------------------------------------------------------- what they mind

## Finds the boy, and any gun not yet listened to.
func _look_about() -> void:
	if target == null or not is_instance_valid(target):
		var found := get_tree().root.find_children("*", "Player", true, false)
		target = found[0] if not found.is_empty() else null
	for gun: Node in get_tree().get_nodes_in_group(&"guns"):
		if gun.has_signal(&"fired") and not _heard.has(gun.get_instance_id()):
			_heard[gun.get_instance_id()] = true
			gun.connect(&"fired", _on_shot.bind(gun))


## A shot: everything that hears it goes up, the nearest first.
func _on_shot(gun: Node) -> void:
	var from := (gun as Node3D).global_position if gun is Node3D else _home
	var up := 0
	for b in birds:
		var off := b.at.distance_to(from)
		if off > EARSHOT:
			continue
		if (b.state == State.STAND or b.state == State.WALK or b.state == State.HOVER) and b.startle == -1.0:
			b.startle = off / 340.0 + randf_range(0.0, 0.3)
			b.fear = from
			up += 1
		elif b.state == State.FLY and b.then == Then.LAND and _habit != Habit.HOVERER:
			# (and what was coming in to land thinks better of it)
			_circle(b, from)
	if _wheel_left > 0.0:
		_wheel_left += 4.0
	if up > 0:
		_quiet = 0.0
		flushed.emit(up)


## The boy, and whatever hunts: how near, and how fast. Each bird on the ground
## is easy until one is inside the distance it will bear, and that is less for
## someone creeping than for someone running at it.
func _mind(_delta: float) -> void:
	var threats: Array[Node3D] = []
	if target and is_instance_valid(target):
		threats.append(target)
	for node: Node in get_tree().get_nodes_in_group(&"pursuers"):
		if node is Node3D:
			threats.append(node)
	var up := 0
	for threat in threats:
		var from := threat.global_position
		if from.distance_to(_home) > roam + 60.0:
			continue
		var going: Vector3 = threat.get(&"velocity") if &"velocity" in threat else Vector3.ZERO
		var fast := Vector2(going.x, going.z).length()
		var bold := clampf(0.7 + fast * 0.13, 0.7, 1.6)
		if threat is Player and (threat as Player).is_ducking:
			bold *= 0.65
		if threat is Player and (threat as Player).is_limp:
			bold = 0.22
		for b in birds:
			if (b.state != State.STAND and b.state != State.WALK) or b.startle != -1.0:
				continue
			var off := b.at.distance_to(from)
			var bears: float = _k["wary"] * bold
			if off < bears:
				b.startle = randf_range(0.0, 0.12)
				b.fear = from
				up += 1
				if _habit == Habit.FLOCK or _habit == Habit.WATERFOWL:
					# (one going up takes the rest with it)
					for other in birds:
						if other.startle == -1.0 and (other.state == State.STAND or other.state == State.WALK) and other.at.distance_to(b.at) < 6.0:
							other.startle = randf_range(0.05, 0.45)
							other.fear = from
							up += 1
			elif off < bears * 1.8:
				b.wary = 1.5
				b.fear = from
	if up > 0:
		_quiet = 0.0
		flushed.emit(up)


## What the soarers circle over: home, or something dead (the boy, if he has lain knocked down long enough).
func _carrion(delta: float) -> void:
	var dead := Vector3.INF
	for node: Node in get_tree().get_nodes_in_group(&"carrion"):
		if node is Node3D and (node as Node3D).global_position.distance_to(_home) < roam + 80.0:
			dead = (node as Node3D).global_position
	if target and is_instance_valid(target) and target.is_limp:
		_limp_for += delta
		if _limp_for > 6.0 and target.global_position.distance_to(_home) < roam + 120.0:
			dead = target.visual_position
	else:
		_limp_for = 0.0
	if dead == Vector3.INF:
		if _dead != Vector3.INF:
			# It is gone, or up: those on the ground leave it.
			for b in birds:
				if b.state == State.STAND or b.state == State.WALK:
					b.startle = randf_range(0.5, 3.0)
					b.fear = _dead
		_dead = Vector3.INF
		_dead_for = 0.0
		return
	_dead = dead
	_dead_for += delta
	# After a while of circling low over it, down they come, one at a time.
	if _dead_for > 12.0:
		for b in birds:
			if b.state == State.SOAR and b.high - _dead.y < 22.0 and randf() < 0.3:
				var way := randf() * TAU
				var at := _dead + Vector3(cos(way), 0.0, sin(way)) * randf_range(2.5, 6.0)
				var y := _ground_at(at.x, at.z, _dead.y + 2.0)
				if not is_nan(y):
					_enter(b, State.FLY)
					b.then = Then.LAND
					b.goal = Vector3(at.x, y, at.z)
					b.going = _circle_way(b) * _n_speed
					break


# ---------------------------------------------------------------- what they do

func _enter(b: Bird, state: State) -> void:
	b.state = state
	b.time = 0.0
	b.act = Act.NONE
	b.act_time = 0.0


func _do(b: Bird, act: Act, length: float) -> void:
	if act == Act.NONE:
		# (standing as it is)
		b.pause = length
		return
	b.act = act
	b.act_time = 0.0
	b.act_length = length
	b.pause = length + randf_range(0.2, 1.2)


## A bird standing with nothing to do: what next.
func _idle(b: Bird) -> void:
	var pick := randf()
	var perched := b.spot != null and b.spot.where == Where.TOP
	if not b.afloat and not _flat:
		# (the level may have been changed under it)
		var under := _ground_at(b.at.x, b.at.z, b.at.y, 4.0)
		if is_nan(under) or absf(under - b.at.y) > 0.3:
			if _tick - _checked > 300:
				_checked = _tick
				rescan(false)
			_leave(b)
			b.startle = 0.0
			b.fear = Vector3.INF
			return
	if b.wary > 0.0 and not perched and b.fear != Vector3.INF and _habit != Habit.WATERFOWL and pick < 0.6:
		# Someone is too near for comfort: a few steps away from him.
		var away := b.at - b.fear
		away.y = 0.0
		if _walk_to(b, b.at + away.normalized().rotated(Vector3.UP, randf_range(-0.6, 0.6)) * randf_range(0.5, 1.2) * _stride()):
			return
	if b.wary > 0.0:
		_do(b, Act.ALERT, randf_range(0.8, 1.6))
		return
	match _habit:
		Habit.FLOCK:
			if perched or _wheel_left > 0.0:
				# Up out of the way. When it has been quiet long enough, and nobody is where they feed, down again.
				var clear: bool = target == null or not is_instance_valid(target) or target.global_position.distance_to(_area) > _k["wary"] * 2.2
				if b.time > 6.0 and _quiet > 18.0 + (b.number % 7) * 1.5 and _wheel_left <= 0.0 and clear:
					_fly_to(b, _near_area(b), null)
				elif pick < 0.3:
					_do(b, Act.PREEN, randf_range(1.5, 3.5))
				else:
					_do(b, Act.ALERT if pick < 0.5 else Act.NONE, randf_range(1.0, 3.0))
				return
			if b.at.distance_to(_area) > _patch() + 3.0:
				# (it has got left behind: after the others)
				_fly_to(b, _near_area(b), null)
			elif pick < 0.5:
				_do(b, Act.PECK, randf_range(0.5, 1.6))
			elif pick < 0.85:
				var to := b.at + Vector3(randf_range(-1.0, 1.0), 0.0, randf_range(-1.0, 1.0)) * _stride()
				if to.distance_to(_area) > _patch():
					to = b.at.move_toward(_area, _stride())
				_walk_to(b, to)
			else:
				_do(b, Act.ALERT if pick < 0.93 else Act.PREEN, randf_range(0.8, 2.0))
		Habit.FORAGER:
			if pick < 0.45:
				_do(b, Act.PECK, randf_range(0.6, 1.8))
			elif pick < 0.85:
				var to := b.at + Vector3(randf_range(-1.0, 1.0), 0.0, randf_range(-1.0, 1.0)) * 1.4
				if to.distance_to(_home) > roam * 0.8:
					to = b.at.move_toward(_home, 1.5)
				_walk_to(b, to)
			elif pick < 0.97 or b.time < 20.0:
				_do(b, Act.ALERT, randf_range(0.8, 2.0))
			else:
				# (and now and then off to another bit of ground)
				var spot := _pick([Where.GROUND], b.at, b.at, 6.0, 0.0, 12.0)
				if spot:
					_fly_to(b, spot.at, spot)
		Habit.WADER:
			if pick < 0.3:
				_walk_to(b, b.at + Vector3(randf_range(-1.0, 1.0), 0.0, randf_range(-1.0, 1.0)) * 1.2)
			elif pick < 0.58:
				_do(b, Act.PECK, randf_range(0.5, 1.4))
			elif pick < 0.72:
				_do(b, Act.ONE_LEG, randf_range(6.0, 14.0))
			elif pick < 0.84:
				_do(b, Act.PREEN, randf_range(2.0, 4.0))
			else:
				_do(b, Act.NONE if pick < 0.94 else Act.ALERT, randf_range(2.0, 6.0))
		Habit.WATERFOWL:
			if pick < 0.5:
				var to := b.at + Vector3(randf_range(-1.0, 1.0), 0.0, randf_range(-1.0, 1.0)) * 2.2
				# (they go in pairs: the second of each keeps by the first)
				if b.number % 2 == 1 and birds[b.number - 1].at.distance_to(b.at) < 12.0:
					to = birds[b.number - 1].at + Vector3(randf_range(-1.0, 1.0), 0.0, randf_range(-1.0, 1.0)) * 1.1
				_walk_to(b, to)
			elif pick < 0.7:
				_do(b, Act.PECK, randf_range(0.8, 1.8))
			elif pick < 0.82:
				_do(b, Act.PREEN, randf_range(2.0, 4.0))
			else:
				_do(b, Act.NONE, randf_range(1.5, 5.0))
		Habit.HOVERER:
			if not perched and b.time > 2.5:
				# (on the ground with what it caught: back up to its perch)
				var spot := _pick([Where.TOP], b.at, Vector3.INF, 0.0, _tall(), 3.0)
				if spot:
					_fly_to(b, spot.at, spot)
					return
			if b.time > 6.0 and pick < 0.35 and _quiet > 6.0:
				_hunt(b)
			elif pick < 0.6:
				_do(b, Act.ALERT, randf_range(1.0, 2.5))
			elif pick < 0.75:
				_do(b, Act.PREEN, randf_range(1.5, 3.0))
			else:
				_do(b, Act.PECK if not perched else Act.NONE, randf_range(1.0, 2.5))
		Habit.SOARER:
			# On the ground, at something dead: a hop nearer, a tear at it, a look round.
			if _dead == Vector3.INF:
				b.startle = randf_range(0.5, 2.0)
				b.fear = b.at + Vector3(randf_range(-1.0, 1.0), 0.0, randf_range(-1.0, 1.0))
			elif b.at.distance_to(_dead) > 3.4 and pick < 0.5:
				_walk_to(b, b.at.move_toward(_dead, randf_range(0.4, 1.0)))
			elif pick < 0.75 and b.at.distance_to(_dead) < 4.6:
				_do(b, Act.PECK, randf_range(0.8, 2.0))
			else:
				_do(b, Act.ALERT, randf_range(1.0, 3.0))
		_:
			b.pause = 1.0


## How far out from its middle the flock's patch of ground reaches.
func _patch() -> float:
	return 0.5 + 0.38 * sqrt(float(count)) * _n_size


func _stride() -> float:
	return clampf((_frame["body"] as Vector3).z * 4.0, 0.35, 1.2)


## Sets it walking (hopping, swimming) to a place, if it can be got to. Says whether it could.
func _walk_to(b: Bird, to: Vector3) -> bool:
	var y := _ground_at(to.x, to.z, b.at.y + 0.5, 3.5)
	b.pause = randf_range(0.2, 0.8)
	if is_nan(y):
		return false
	var pool := _pool_over(to)
	var deep := pool.surface_y() - y if pool else -1.0
	if b.afloat:
		if pool != b.afloat or deep < 0.2:
			return false
		y = pool.surface_y()
	else:
		# (not off the edge of what it is on, not up a step, and no deeper in than its legs are long)
		if absf(y - b.at.y) > 0.3 * maxf(to.distance_to(b.at), 0.5) + 0.05 or deep > maxf(_k["wade"], 0.01):
			return false
		if _habit == Habit.WADER and b.spot and b.spot.where == Where.WADE and deep < -0.15:
			return false
	b.from = b.at
	b.goal = Vector3(to.x, y, to.z)
	b.ground = b.at.y
	_enter(b, State.WALK)
	return true


## Sends it off through the air to come down at `to`.
func _fly_to(b: Bird, to: Vector3, spot: Spot, from := Vector3.INF) -> void:
	_take(b, spot)
	b.goal = to
	b.then = Then.LAND
	b.fear = from
	_go_up(b)


## Off its feet and into the air.
func _go_up(b: Bird) -> void:
	if b.state == State.HOVER or b.state == State.FLY or b.state == State.SOAR:
		_enter(b, State.FLY)
		return
	var away := b.at - b.fear if b.fear != Vector3.INF else b.goal - b.at
	away.y = 0.0
	if b.fear == Vector3.INF and b.then != Then.LAND:
		away = Vector3(sin(b.yaw), 0.0, cos(b.yaw))
	away = away.normalized() if away.length() > 0.05 else Vector3(sin(b.yaw), 0.0, cos(b.yaw))
	if b.fear != Vector3.INF:
		away = away.rotated(Vector3.UP, randf_range(-0.5, 0.5))
	var quick: float = _n_speed
	if b.afloat:
		# Off water it runs along the top of it, wings going, before it is clear.
		b.going = away * quick * 0.3 + Vector3.UP * 0.2
		b.afloat.water.splash(b.at, 0.3)
	else:
		b.going = away * quick * 0.3 + Vector3.UP * (1.6 + quick * 0.22)
	b.from = b.at
	b.yaw = atan2(away.x, away.z)
	b.ground = b.at.y
	b.looked = 0.0
	_enter(b, State.TAKEOFF)


## A bird that has been startled goes up; and one that has finished something asks what next.
func _decide(b: Bird) -> void:
	if b.startle == -2.0:
		# Alarmed.
		b.startle = -1.0
		var from := b.fear if b.fear != Vector3.INF else b.at + Vector3(randf_range(-1.0, 1.0), 0.0, randf_range(-1.0, 1.0))
		b.wary = 0.0
		var hovering := b.state == State.HOVER
		match _habit:
			Habit.FLOCK:
				_leave(b)
				b.then = Then.WHEEL
				if _wheel_left <= 0.0:
					var away := _area - from
					away.y = 0.0
					_wheel_at = _keep_in(_area + away.normalized() * 6.0, 8.0 + 0.12 * count + _patch())
					_wheel_turn = 1.0 if randf() < 0.5 else -1.0
					_wheel_angle = atan2(_area.z - _wheel_at.z, _area.x - _wheel_at.x) + _wheel_turn * 0.5
				_wheel_left = maxf(_wheel_left, randf_range(5.0, 8.0))
				b.wheel_left = 100.0
				b.angle = atan2(b.at.z - _wheel_at.z, b.at.x - _wheel_at.x)
				_go_up(b)
			Habit.SOARER:
				_leave(b)
				b.then = Then.SOAR
				b.high = maxf(_highest, _home.y) + _k["soar_height"] * randf_range(0.75, 1.3)
				b.wide = _soar_wide() * randf_range(0.7, 1.1)
				_go_up(b)
			Habit.FORAGER:
				var ground := _pick([Where.GROUND], b.at, from, 11.0, 0.0, 6.0)
				if ground:
					_fly_to(b, ground.at, ground, from)
				else:
					_leave(b)
					_circle(b, from)
			Habit.HOVERER:
				var spot := _pick([Where.TOP], b.at, from, maxf(_k["wary"] * 1.6, 10.0), _tall(), 6.0)
				if spot == null:
					spot = _pick([Where.TOP, Where.GROUND], b.at, from, _k["wary"] * 1.6, 0.3, 8.0)
				if spot:
					_fly_to(b, spot.at, spot, Vector3.INF if hovering else from)
				else:
					_circle(b, from)
			_:
				# The big ones go off round in a wide circle before they choose where to come down.
				_leave(b)
				_circle(b, from)
		return
	match b.then:
		Then.WHEEL:
			_come_down(b)
		Then.HOVER:
			# Hanging there, it has seen something, or it has not.
			var pick := randf()
			if pick < 0.55:
				_enter(b, State.STOOP)
				var pool := _pool_over(b.at)
				var y := _ground_at(b.at.x, b.at.z, b.at.y, 40.0)
				b.goal = Vector3(b.at.x, pool.surface_y() if pool else (b.at.y - 8.0 if is_nan(y) else y), b.at.z)
				b.afloat = null
			elif pick < 0.8:
				_hunt(b)
			else:
				var spot := _pick([Where.TOP], b.at, Vector3.INF, 0.0, _tall(), 4.0)
				_fly_to(b, spot.at if spot else _area, spot)
		Then.ROAM:
			_wander(b)
		_:
			pass


## Round in a circle over where it was, for a while (see `_come_down` for what ends it).
func _circle(b: Bird, from: Vector3) -> void:
	b.then = Then.WHEEL
	b.fear = from
	var away := b.at - from
	away.y = 0.0
	b.wide = clampf(_n_reach * 9.0, 5.0, 14.0)
	b.wide = minf(b.wide, maxf(roam * 0.4, 3.0))
	b.about = _keep_in(b.at + away.normalized() * b.wide, b.wide + 2.0)
	b.turn = 1.0 if randf() < 0.5 else -1.0
	b.angle = atan2(b.at.z - b.about.z, b.at.x - b.about.x)
	b.wheel_left = randf_range(6.0, 10.0)
	_go_up(b)


## A point brought back to be at least `margin` inside the range.
func _keep_in(at: Vector3, margin: float) -> Vector3:
	var out := at - _home
	out.y = 0.0
	var most := maxf(roam - margin, 0.0)
	if out.length() > most:
		out = out.normalized() * most
	return Vector3(_home.x + out.x, at.y, _home.z + out.z)


## It has wheeled about long enough: somewhere to land, away from whatever put it up.
func _come_down(b: Bird) -> void:
	var from := target.global_position if target and is_instance_valid(target) else Vector3.INF
	var clear: float = _k["wary"] * 2.0
	match _habit:
		Habit.FLOCK:
			# Up onto things, if there are any; otherwise back to the ground, if he has left it, or to ground somewhere else.
			var spot := _pick([Where.TOP], _wheel_at, from, clear * 0.55, 0.15, 3.0)
			if spot:
				_fly_to(b, spot.at, spot)
				return
			if from != Vector3.INF and from.distance_to(_area) < clear * 1.3:
				var ground := _pick([Where.GROUND], _wheel_at, from, clear * 2.0, 0.0, 6.0)
				if ground:
					_area = ground.at
				else:
					# (nowhere to go: round again)
					b.ask = false
					_wheel_left = 4.0
					return
			_fly_to(b, _near_area(b), null)
		_:
			var spot: Spot = null
			for wheres: Array in _likes():
				spot = _pick(wheres, b.at, from, clear, 0.0, 8.0)
				if spot:
					break
			if spot == null and b.rounds < 3:
				# (nowhere far enough from him: round again)
				b.rounds += 1
				b.wheel_left = 5.0
				return
			b.rounds = 0
			if spot == null:
				spot = _pick([Where.GROUND, Where.WADE, Where.WATER, Where.TOP], b.at, from, 0.0, 0.0, 8.0)
			var down := spot.at if spot else Vector3(b.about.x, _home.y, b.about.z)
			_fly_to(b, down, spot)


## Out to hang in the air over a likely spot: open ground for the kestrel, water for the kingfisher.
func _hunt(b: Bird) -> void:
	var over := _pick([Where.WATER] if kind == Kind.KINGFISHER else [Where.GROUND], _home, target.global_position if target else Vector3.INF, 7.0, 0.0, roam)
	if over == null:
		over = _pick([Where.GROUND, Where.WATER], _home, Vector3.INF, 0.0, 0.0, roam)
	if over == null:
		b.pause = 3.0
		return
	_leave(b)
	b.goal = over.at + Vector3.UP * (randf_range(3.2, 5.0) if kind == Kind.KINGFISHER else randf_range(8.0, 12.0))
	b.then = Then.HOVER
	b.fear = Vector3.INF
	b.length = randf_range(2.5, 5.0)
	_go_up(b)


## A swallow's next place to be: low over water if there is any, low over the ground, and now and then up high.
func _wander(b: Bird) -> void:
	var spot := _pick([Where.WATER], b.at, b.at, 3.0, 0.0, 30.0) if randf() < 0.7 else null
	if spot == null:
		spot = _pick([Where.GROUND, Where.WATER], b.at, b.at, 5.0, 0.0, roam * 2.0)
	var to := spot.at if spot else _home + Vector3(randf_range(-1.0, 1.0), 0.0, randf_range(-1.0, 1.0)) * roam * 0.6
	var up := randf_range(0.25, 0.5) if spot and spot.where == Where.WATER else randf_range(0.6, 2.2)
	if randf() < 0.15:
		up = randf_range(4.0, 9.0)
	b.goal = to + Vector3.UP * up
	b.then = Then.ROAM


## Looks down and ahead of a bird in the air, so that it does not fly into the ground or a wall.
func _look_ahead(b: Bird) -> void:
	var space := get_world_3d().direct_space_state
	var ahead := b.at + b.going * 0.45
	var down := space.intersect_ray(PhysicsRayQueryParameters3D.create(ahead + Vector3.UP * 2.0, ahead + Vector3.DOWN * 40.0, 1))
	b.ground = (down["position"] as Vector3).y if not down.is_empty() else (_home.y if _flat else -INF)
	var pool := _pool_over(ahead)
	if pool:
		b.ground = maxf(b.ground, pool.surface_y())
	if b.going.length() > 1.0:
		var front := space.intersect_ray(PhysicsRayQueryParameters3D.create(b.at + Vector3.UP * 0.15, b.at + Vector3.UP * 0.15 + b.going * 0.7, 1))
		if not front.is_empty() and (front["position"] as Vector3).distance_to(b.goal) > 1.5:
			var normal: Vector3 = front["normal"]
			b.dodge = (Vector3(normal.x, 0.0, normal.z) * 0.8 + Vector3.UP).normalized()
			b.dodge_left = 0.5


# ---------------------------------------------------------------- moving

## What the whole flock does together: the circle it wheels round turns, and its time runs down.
func _flock(delta: float) -> void:
	if _wheel_left > 0.0:
		# (the place they are all making for goes round the circle a little slower than they fly, so that they keep up with it in a bunch)
		_wheel_angle = wrapf(_wheel_angle + _wheel_turn * _n_speed * 0.8 / (5.0 + 0.12 * count) * delta, -PI, PI)
		_wheel_left -= delta
		if _wheel_left <= 0.0:
			for b in birds:
				if b.state == State.FLY and b.then == Then.WHEEL:
					b.ask = true
	if _habit == Habit.SOARER:
		# Over what is dead, if anything is; otherwise wherever, slowly, about home.
		var to := _dead if _dead != Vector3.INF else _home + Vector3(sin(_tick * 0.0011), 0.0, cos(_tick * 0.0007)) * maxf(roam - _soar_wide() * 1.2, 0.0) * 0.7
		_over = _over.move_toward(Vector3(to.x, _home.y, to.z), delta * (3.0 if _dead != Vector3.INF else 1.5))


## How wide the soarers' circles are: as their kind likes, if the range has room for it.
func _soar_wide() -> float:
	return clampf(_k["soar_wide"], 8.0, maxf(roam * 0.75, 8.0))


func _on_circle(b: Bird) -> Vector3:
	return Vector3(b.about.x + cos(b.angle) * b.wide, b.high, b.about.z + sin(b.angle) * b.wide)


## The way a bird on a circle is going.
func _circle_way(b: Bird) -> Vector3:
	return Vector3(-sin(b.angle), 0.0, cos(b.angle)) * b.turn


## One bird, one frame.
func _live(b: Bird, delta: float) -> void:
	b.time += delta
	b.pause -= delta
	b.wary -= delta
	if b.hidden > 0.0:
		b.hidden -= delta
	b.sunk = move_toward(b.sunk, 1.0 if b.afloat and (b.state == State.STAND or b.state == State.WALK) else 0.0, delta * 4.0)
	if b.state != State.STAND:
		b.still = false
	if b.startle >= 0.0:
		b.startle -= delta
		if b.startle < 0.0:
			b.startle = -2.0
			b.ask = true
	match b.state:
		State.STAND:
			# (one that has stood doing nothing for a moment is as it will stay: it is left alone)
			if b.act == Act.NONE and b.time > 1.6 and b.wary <= 0.0 and b.act_time > 1.0 and not b.afloat:
				b.still = true
				return
			b.act_time += delta if b.act == Act.NONE else 0.0
			b.still = false
			_stand(b, delta)
		State.WALK:
			_walk(b, delta)
		State.TAKEOFF:
			_take_off(b, delta)
		State.FLY:
			_fly(b, delta)
		State.LAND:
			_land(b, delta)
		State.SOAR:
			_soar(b, delta)
		State.HOVER:
			_hover(b, delta)
		State.STOOP:
			_stoop(b, delta)


func _ease(from: float, to: float, rate: float, delta: float) -> float:
	return lerpf(from, to, 1.0 - exp(-rate * delta))


## Holds its neck one way: bend of the lower half, of the upper, and where the bill points.
func _hold(b: Bird, how: Array, rate: float, _delta: float, nod := 0.0) -> void:
	var blend := _blend[mini(int(rate), 31)]
	b.neck_low = lerpf(b.neck_low, how[0] + nod, blend)
	b.neck_high = lerpf(b.neck_high, how[1], blend)
	# (the head is told how far to turn on the neck; what is wanted is where the bill points)
	var carried: float = _n_stance * minf(b.legs, 1.0) + b.neck_low + b.neck_high
	b.head = lerpf(b.head, how[2] - carried, blend)


func _stand(b: Bird, delta: float) -> void:
	b.going = Vector3.ZERO
	b.roll = lerpf(b.roll, 0.0, _blend[10])
	b.fold = lerpf(b.fold, 1.0, _blend[9])
	b.lift = 0.0
	b.flap = 0.0
	b.wing_in = lerpf(b.wing_in, 0.0, _blend[10])
	b.wing_out = lerpf(b.wing_out, 0.0, _blend[10])
	var legs := 1.0
	var tip := 0.0
	var how: Array = _k["stand"]
	var rate := 9.0
	var crest := 0.0
	if b.afloat:
		legs = 0.0
		b.at.y = b.afloat.surface_y()
	if b.act != Act.NONE:
		b.act_time += delta
		if b.act_time >= b.act_length:
			b.act = Act.NONE
			b.act_time = 0.0
	if b.wary > 0.0 and b.act == Act.PECK:
		b.act = Act.ALERT
	match b.act:
		Act.PECK:
			# Down, a jab or two, and up.
			var dabs := maxf(roundf(b.act_length / 0.55), 1.0)
			var pulse := pow(0.5 - 0.5 * cos(TAU * b.act_time / b.act_length * dabs), 0.7)
			tip = -pulse * (_k["peck_tip"] as float) * (0.4 if b.afloat else 1.0)
			var peck: Array = _k["peck"]
			var stand: Array = _k["stand"]
			how = [lerpf(stand[0], peck[0], pulse), lerpf(stand[1], peck[1], pulse), lerpf(stand[2], peck[2], pulse)]
			rate = 22.0
		Act.PREEN:
			# Its bill down in its breast feathers, working at them.
			var rest: Array = _k["rest"]
			how = [rest[0] + 0.25, rest[1] - 0.7, -1.5 + 0.2 * sin(b.act_time * 9.0)]
			b.fold = lerpf(b.fold, 0.93, _blend[9])
		Act.ONE_LEG:
			legs = 2.0 if not b.afloat else 0.0
			how = _k["rest"]
			rate = 3.0
		Act.ALERT:
			var stand: Array = _k["stand"]
			how = [stand[0] + 0.22, stand[1] + 0.12, 0.08]
			crest = 1.0
			tip = 0.08
		_:
			if b.time < 1.2:
				crest = 1.0
	b.pitch = lerpf(b.pitch, tip, _blend[16])
	b.legs = _ease(b.legs, legs, 5.0 if legs > 1.0 or b.legs > 1.05 else 12.0, delta)
	_hold(b, how, rate, delta)
	if _n_crest > 0.0:
		b.extra = lerpf(b.extra, crest, _blend[7])
	else:
		b.extra = lerpf(b.extra, 0.0, _blend[8])
	if b.fear != Vector3.INF and b.wary > 0.0:
		# (it keeps an eye on him)
		var to := b.fear - b.at
		b.yaw = lerp_angle(b.yaw, atan2(to.x, to.z) + 1.2, 1.0 - exp(-3.0 * delta))


func _walk(b: Bird, delta: float) -> void:
	var to := b.goal - b.at
	var flat := Vector3(to.x, 0.0, to.z)
	var far := flat.length()
	var whole := maxf(Vector3(b.goal.x - b.from.x, 0.0, b.goal.z - b.from.z).length(), 0.01)
	var speed: float = _n_walk * (2.0 if b.wary > 0.0 else 1.0)
	b.roll = 0.0
	b.fold = lerpf(b.fold, 1.0, _blend[9])
	b.wing_in = lerpf(b.wing_in, 0.0, _blend[10])
	b.wing_out = lerpf(b.wing_out, 0.0, _blend[10])
	if far < 0.03 or b.time > 12.0:
		b.at = b.goal if far < 0.03 else b.at
		b.lift = 0.0
		_enter(b, State.STAND)
		return
	b.yaw = lerp_angle(b.yaw, atan2(flat.x, flat.z), 1.0 - exp(-9.0 * delta))
	var step := minf(speed * delta, far)
	var hops: bool = _k["hops"]
	b.stride += delta * speed / maxf(_stride() * 0.16, 0.04)
	if b.afloat:
		# Paddling: a ring opens at its breast every so often.
		b.legs = lerpf(b.legs, 0.0, _blend[10])
		b.rippled -= delta
		if b.rippled <= 0.0:
			b.rippled = 0.55
			b.afloat.water.ripple(b.at + Vector3(sin(b.yaw), 0.0, cos(b.yaw)) * 0.2, 0.3)
		b.pitch = lerpf(b.pitch, 0.0, _blend[8])
		_hold(b, _k["stand"], 8.0, delta)
	elif hops:
		# Both feet together: it goes in little bounds, and is still between them.
		var bound := fmod(b.time, 0.3) / 0.3
		step = minf(speed * 2.0 * delta, far) if bound < 0.5 else 0.0
		b.lift = sin(clampf(bound * 2.0, 0.0, 1.0) * PI) * 0.035 * _n_size * (1.0 + (_k["leg"] as float) * 6.0)
		b.legs = lerpf(b.legs, 1.0, _blend[12])
		_hold(b, _k["stand"], 8.0, delta)
	else:
		# One foot and then the other, and its head goes forward and back with them, as a dove's does.
		b.legs = lerpf(b.legs, 1.0, _blend[12])
		b.extra = sin(b.stride) if _n_crest <= 0.0 else lerpf(b.extra, 0.0, _blend[6])
		_hold(b, _k["stand"], 14.0, delta, -0.16 * (0.5 + 0.5 * sin(b.stride * 2.0)))
		b.pitch = lerpf(b.pitch, 0.0, _blend[8])
	b.at += flat / far * step
	if not b.afloat:
		# (up a rise at once, down a fall gently)
		var along := lerpf(b.from.y, b.goal.y, clampf(1.0 - (far - step) / whole, 0.0, 1.0))
		b.at.y = maxf(move_toward(b.at.y, minf(along, b.ground), delta * 1.2), b.ground) if not _flat else along
		var pool := _pool_over(b.at)
		if pool and pool.surface_y() > b.at.y + 0.02 and fmod(b.stride, PI) < delta * speed / maxf(_stride() * 0.16, 0.04):
			pool.water.ripple(b.at, 0.22)


## Beats its wings: how hard (0: held out, gliding), and how much faster and deeper than in level flight.
func _beat(b: Bird, hard: float, effort: float, delta: float, raised := 0.0, shallow := 1.0) -> void:
	b.flap = lerpf(b.flap, hard, _blend[7])
	b.effort = lerpf(b.effort, effort, _blend[6])
	# (no faster than can be seen: past that it is only a blur)
	b.beat = fmod(b.beat + TAU * minf(_n_beat * (0.6 + 0.4 * b.effort), 14.0) * delta, TAU)
	var deep: float = _n_depth * (0.7 + 0.3 * b.effort) * shallow
	var dihedral: float = _n_dihedral
	var droop: float = _n_droop
	var stroke := sin(b.beat)
	var inner := 0.1 + raised + deep * stroke
	# (the outer half follows the inner late, and is bent down as the wing comes up)
	var outer := inner + deep * 0.6 * sin(b.beat - 1.0)
	b.wing_in = lerpf(dihedral, inner, b.flap)
	b.wing_out = lerpf(dihedral * 1.5 - droop, outer, b.flap)


func _take_off(b: Bird, delta: float) -> void:
	var quick: float = _n_speed
	var long: float = 0.35 + _n_reach * 0.5
	b.fold = lerpf(b.fold, 0.0, _blend[18])
	_beat(b, 1.0, 1.7, delta, 0.15)
	_hold(b, _k["stand"] if b.time < long * 0.5 else _k["fly"], 6.0, delta)
	if _n_crest > 0.0:
		b.extra = lerpf(b.extra, 0.6, _blend[8])
	else:
		b.extra = lerpf(b.extra, 0.0, _blend[8])
	# (long legs hang a while before they are drawn up)
	b.legs = _ease(b.legs, 0.0, 3.2 / long, delta) if b.time > 0.06 else b.legs
	b.lift = 0.0
	var way := Vector3(sin(b.yaw), 0.0, cos(b.yaw))
	if b.afloat:
		# Running on the water.
		var run := clampf(b.time / (long * 1.6), 0.0, 1.0)
		b.going = way * quick * lerpf(0.3, 0.8, run) + Vector3.UP * lerpf(0.0, 2.0, run * run)
		b.rippled -= delta
		if b.rippled <= 0.0 and b.at.y < b.afloat.surface_y() + 0.25:
			b.rippled = 0.11
			b.afloat.water.splash(b.at, 0.22)
		b.pitch = lerpf(b.pitch, 0.25, _blend[6])
		if run >= 1.0:
			b.afloat = null
			_enter(b, State.FLY)
	else:
		b.going = b.going.lerp(way * quick * 0.75 + Vector3.UP * (1.2 + quick * 0.2), 1.0 - exp(-2.5 * delta))
		b.pitch = lerpf(b.pitch, 0.4, _blend[8])
		if b.time >= long:
			_enter(b, State.FLY)
	b.at += b.going * delta
	b.at.y = maxf(b.at.y, b.from.y)


## Where a flying bird is making for, and how fast.
func _aim(b: Bird) -> Vector3:
	match b.then:
		Then.WHEEL:
			if _habit == Habit.FLOCK:
				# All round one circle, each in its own place in the flock.
				var out := 5.0 + 0.12 * count
				var along := b.angle
				return _wheel_at + Vector3(cos(along) * out, _n_cruise + 1.5 * sin(along * 2.0), sin(along) * out) + b.slot
			return Vector3(b.about.x + cos(b.angle) * b.wide, b.about.y + _n_cruise, b.about.z + sin(b.angle) * b.wide)
		Then.SOAR:
			return _on_circle(b)
		Then.LAND:
			# Down a slope to it: never lower than that until it is nearly there.
			var off := Vector3(b.goal.x - b.at.x, 0.0, b.goal.z - b.at.z).length()
			var up := clampf((off - 1.0) * 0.4, 0.5 if b.spot and b.spot.where == Where.TOP else 0.25, _n_cruise)
			return b.goal + Vector3.UP * up
	return b.goal


func _fly(b: Bird, delta: float) -> void:
	var quick: float = _n_speed
	# Which way to push is thought about every other frame (half the flock each); where that takes it, every frame.
	if (_frames + b.number) % 2 == 0 or b.time <= delta * 1.5:
		_steer(b, delta * 2.0)
		if b.state != State.FLY:
			return
	var push := b.push
	b.going += push * delta
	var speed := b.going.length()
	if speed > quick * 1.3:
		b.going *= quick * 1.3 / speed
	b.at += b.going * delta
	if b.ground > -INF and b.at.y < b.ground + 0.12 and not b.close:
		b.at.y = b.ground + 0.12
		b.going.y = maxf(b.going.y, 0.5)

	# How it lies in the air: along its way, banked into its turns.
	var level := Vector2(b.going.x, b.going.z).length()
	if level > 0.3:
		b.yaw = atan2(b.going.x, b.going.z)
	var right := Vector3(-cos(b.yaw), 0.0, sin(b.yaw))
	b.roll = lerpf(b.roll, clampf(atan(push.dot(right) / GRAVITY * 1.4), -1.1, 1.1), _blend[5])
	b.pitch = lerpf(b.pitch, clampf(atan2(b.going.y, maxf(level, 0.5)) * 0.8, -0.9, 0.9), _blend[6])

	# How it works its wings: beating, or held out; and the small ones shut them altogether between bursts.
	b.bout += delta
	var gliding := b.going.y < -1.2 or (fmod(b.bout, 2.6) < 2.6 * _n_glide and b.going.y < 0.4)
	var shut := 0.0
	b.lift = 0.0
	if _n_bound > 0.0:
		var u := fmod(b.bout, _n_bound) / _n_bound
		var beating := 0.58
		shut = 0.0 if u < beating else 0.82
		b.lift = _n_bound_rise * 0.5 * (-cos(PI * u / beating) if u < beating else cos(PI * (u - beating) / (1.0 - beating)))
		gliding = false
	b.fold = lerpf(b.fold, shut, _blend[16])
	_beat(b, 0.0 if gliding else 1.0, 1.25 if b.going.y > 1.0 else 1.0, delta)
	b.legs = lerpf(b.legs, 0.0, _blend[5])
	_hold(b, _k["fly"], 5.0, delta)
	b.extra = lerpf(b.extra, 0.0, _blend[6])


## Which way a flying bird should push to get where it is going (`push`), and whether it has got there.
func _steer(b: Bird, delta: float) -> void:
	var quick: float = _n_speed
	if b.then == Then.WHEEL or b.then == Then.SOAR:
		var together := _habit == Habit.FLOCK and b.then == Then.WHEEL
		var out := 5.0 + 0.12 * count if together else b.wide
		var turn := _wheel_turn if together else b.turn
		# (its place on the circle keeps a little ahead of it, so that it is always turning in)
		var centre := _wheel_at if together else b.about
		var here := atan2(b.at.z - centre.z, b.at.x - centre.x)
		b.angle = here + turn * clampf(quick * 0.9 / out, 0.3, 1.2)
		if together:
			b.angle = _wheel_angle
			# Its place in the flock drifts about.
			var wide := 0.5 + 0.22 * sqrt(float(count)) * _n_size
			var n := float(b.number)
			b.slot = Vector3(sin(n * 2.4 + b.time * 0.7) * wide, sin(n * 1.7 + b.time * 0.9) * wide * 0.45, cos(n * 3.1 + b.time * 0.6) * wide)
		elif b.then == Then.WHEEL:
			b.wheel_left -= delta
			if b.wheel_left <= 0.0:
				b.wheel_left = 3.0
				b.ask = true
	var to := _aim(b) - b.at
	var off := to.length()
	var flat_off := Vector3(b.goal.x - b.at.x, 0.0, b.goal.z - b.at.z).length()
	var want := to / maxf(off, 0.001) * quick
	if b.then == Then.HOVER or b.then == Then.LAND:
		# (slowing as it comes up to it)
		want *= clampf(flat_off / 4.0 + 0.45, 0.45, 1.0)
	# Not into the ground, nor into what is in front of it.
	var clear := 0.3 if _habit == Habit.SKIMMER else clampf(_n_reach * 2.5, 0.8, 2.5)
	if b.then == Then.LAND and flat_off < 6.0:
		clear = minf(clear, 0.15 + flat_off * 0.15)
	b.close = b.then == Then.LAND and flat_off < 1.5
	if b.ground > -INF and b.at.y < b.ground + clear + 1.0:
		want.y = maxf(want.y, (b.ground + clear - b.at.y) * 4.0)
	if b.dodge_left > 0.0:
		b.dodge_left -= delta
		want += b.dodge * quick
	# It keeps off the two next to it in the flock.
	if _habit == Habit.FLOCK and count > 1:
		var room := 0.5 * _n_size + _n_reach
		for step: int in [1, 5]:
			var apart := b.at - birds[(b.number + step) % count].at
			var near := apart.length_squared()
			if near < room * room and near > 0.0001:
				want += apart / sqrt(near) * quick * 0.5
	var push := want - b.going
	var hard := push.length()
	if hard > _n_turn:
		push = push / hard * _n_turn
	b.push = push

	# And whether it has got there.
	match b.then:
		Then.LAND:
			var near := 1.0 + quick * 0.16
			var above := b.spot == null or b.spot.where != Where.TOP or b.at.y > b.goal.y - 0.25
			if flat_off < near and absf(b.at.y - b.goal.y) < near * 1.2 and above:
				b.from = b.at
				b.from_going = b.going
				b.length = clampf(b.at.distance_to(b.goal) / maxf(b.going.length() * 0.55, 1.0), 0.3, 1.1)
				_enter(b, State.LAND)
		Then.HOVER:
			if off < 1.2:
				_enter(b, State.HOVER)
		Then.ROAM:
			if off < 1.5 or b.time > 8.0:
				b.time = 0.0
				b.ask = true
			var pool := _pool_over(b.at)
			b.rippled -= delta
			if pool and b.at.y < pool.surface_y() + 0.32 and b.rippled <= 0.0:
				# (a swallow dips its bill as it goes over)
				b.rippled = 1.5
				pool.water.ripple(b.at, 0.3)
		Then.SOAR:
			if off < 4.0:
				b.about = _over
				b.angle = atan2(b.at.z - b.about.z, b.at.x - b.about.x)
				_enter(b, State.SOAR)


## The last of a flight: wings spread and thrown back against the air, tail fanned, legs down and reaching.
func _land(b: Bird, delta: float) -> void:
	var u := clampf(b.time / b.length, 0.0, 1.0)
	var u2 := u * u
	var u3 := u2 * u
	# (from where it was, going as it was going, to a stop at its place)
	var at := b.from * (2.0 * u3 - 3.0 * u2 + 1.0) + b.from_going * b.length * (u3 - 2.0 * u2 + u) + b.goal * (-2.0 * u3 + 3.0 * u2)
	at.y = maxf(at.y, minf(b.from.y, b.goal.y))
	if u > 0.5:
		at.y = maxf(at.y, b.goal.y)
	b.going = (at - b.at) / maxf(delta, 0.0001)
	b.at = at
	var flare := sin(clampf(u * 1.25, 0.0, 1.0) * PI)
	b.pitch = lerpf(b.pitch, 0.25 + 0.6 * flare, _blend[12])
	b.roll = lerpf(b.roll, 0.0, _blend[8])
	b.fold = lerpf(b.fold, 0.0, _blend[12])
	b.lift = 0.0
	_beat(b, 1.0, 1.6, delta, 0.45 * flare)
	var onto_water := b.spot != null and b.spot.where == Where.WATER
	b.legs = lerpf(b.legs, 1.0 if u > 0.15 else 0.0, _blend[9])
	_hold(b, _k["stand"], 6.0, delta)
	if _n_crest > 0.0:
		b.extra = lerpf(b.extra, 1.0, _blend[8])
	else:
		b.extra = lerpf(b.extra, 0.0, _blend[8])
	if u >= 1.0:
		b.at = b.goal
		if onto_water:
			b.spot.pool.water.splash(b.at, 0.3)
		elif _pool_over(b.at) and _pool_over(b.at).surface_y() > b.at.y:
			_pool_over(b.at).water.ripple(b.at, 0.4)
		_put_down(b, b.goal)
		b.pause = randf_range(0.6, 2.0)
		b.fear = Vector3.INF


## Round and round on still wings, high up; lower and tighter over something dead.
func _soar(b: Bird, delta: float) -> void:
	var quick: float = _n_speed
	var low := _dead != Vector3.INF
	var high := (_dead.y + 14.0 + (b.number % 4) * 3.0) if low and _dead_for > 3.0 else maxf(_highest, _home.y) + (_k["soar_height"] as float) * (0.8 + 0.12 * (b.number % 5))
	var wide := (9.0 + (b.number % 3) * 3.0) if low and _dead_for > 3.0 else _soar_wide() * (0.62 + 0.09 * (b.number % 5))
	b.high = move_toward(b.high, high + 4.0 * sin(b.time * 0.07 + b.number), delta * 2.2)
	b.wide = move_toward(b.wide, wide * (1.0 + 0.1 * sin(b.time * 0.05 + b.number * 2.0)), delta * 1.5)
	b.about = b.about.move_toward(_over, delta * 4.0)
	b.angle = wrapf(b.angle + b.turn * quick / b.wide * delta, -PI, PI)
	var at := _on_circle(b)
	at = b.at.move_toward(at, quick * 1.6 * delta) if b.time > delta * 1.5 else at
	b.going = (at - b.at) / maxf(delta, 0.0001) if b.time > delta * 1.5 else _circle_way(b) * quick
	b.at = at
	var way := _circle_way(b)
	b.yaw = atan2(way.x, way.z)
	# (banked for the turn, and rocking a little on the air)
	b.roll = lerpf(b.roll, b.turn * atan(quick * quick / (b.wide * GRAVITY)) * -1.0 + 0.05 * sin(b.time * 0.9 + b.number), _blend[2])
	b.pitch = lerpf(b.pitch, 0.0, _blend[2])
	b.fold = lerpf(b.fold, 0.0, _blend[6])
	b.legs = lerpf(b.legs, 0.0, _blend[4])
	b.lift = 0.0
	# A few slow beats now and then; a griffon hardly ever.
	b.bout += delta
	var glides: float = _n_glide
	_beat(b, 1.0 if fmod(b.bout + b.number * 3.7, 14.0) < 14.0 * (1.0 - glides) else 0.0, 1.0, delta)
	_hold(b, _k["fly"], 3.0, delta)
	b.extra = 0.0


## Hanging in the air over one spot: wings going fast and shallow, tail spread and pressed down, head quite still, looking down.
func _hover(b: Bird, delta: float) -> void:
	var wind := Vector3(Sand.wind_way.x, 0.0, Sand.wind_way.y)
	if wind.length() > 0.1:
		b.yaw = lerp_angle(b.yaw, atan2(-wind.x, -wind.z), 1.0 - exp(-3.0 * delta))
	var sway := Vector3(sin(b.time * 1.7), 0.35 * sin(b.time * 2.9), cos(b.time * 1.3)) * 0.12
	b.going = (b.goal + sway - b.at) * 3.0
	b.at += b.going * delta
	var kingfisher := kind == Kind.KINGFISHER
	b.pitch = lerpf(b.pitch, 0.9 if kingfisher else 0.45, _blend[5])
	b.roll = lerpf(b.roll, 0.0, _blend[6])
	b.fold = lerpf(b.fold, 0.0, _blend[12])
	b.legs = lerpf(b.legs, 0.0, _blend[6])
	b.lift = 0.0
	_beat(b, 1.0, 1.8, delta, 0.1, 0.55)
	var fly: Array = _k["fly"]
	_hold(b, [fly[0], fly[1], -1.2 if kingfisher else -0.8], 6.0, delta)
	if b.time > b.length:
		b.time = 0.0
		b.length = 100.0
		b.ask = true


## Down on it: wings half shut, faster and faster. A kingfisher goes into the water and comes out again; a kestrel lands on what it has caught.
func _stoop(b: Bird, delta: float) -> void:
	b.going = b.going.lerp(Vector3.DOWN * 13.0, 1.0 - exp(-3.5 * delta))
	b.at += b.going * delta
	b.pitch = lerpf(b.pitch, -1.25, _blend[9])
	b.fold = lerpf(b.fold, 0.7, _blend[9])
	b.wing_in = lerpf(b.wing_in, 0.25, _blend[9])
	b.wing_out = lerpf(b.wing_out, 0.1, _blend[9])
	b.legs = lerpf(b.legs, 0.0, _blend[6])
	var fly: Array = _k["fly"]
	_hold(b, [fly[0], fly[1], -1.3], 8.0, delta)
	var pool := _pool_over(b.at)
	if pool and b.at.y <= pool.surface_y() + 0.05:
		# In, with a splash; a moment under; and up out of it for its perch.
		pool.water.splash(b.at, 0.4)
		b.hidden = 0.45
		b.at.y = pool.surface_y()
		var spot := _pick([Where.TOP], b.at, Vector3.INF, 0.0, 0.2, 4.0)
		if spot == null:
			spot = _pick([Where.GROUND], b.at, Vector3.INF, 0.0, 0.0, 4.0)
		b.then = Then.LAND
		_take(b, spot)
		b.goal = spot.at if spot else _area
		b.fear = Vector3.INF
		b.from = b.at
		b.yaw = atan2(b.goal.x - b.at.x, b.goal.z - b.at.z)
		b.going = Vector3(sin(b.yaw), 0.0, cos(b.yaw)) * 2.0 + Vector3.UP * 3.5
		b.ground = b.at.y
		_enter(b, State.TAKEOFF)
	elif pool == null and b.at.y <= b.goal.y + 1.4:
		b.from = b.at
		b.from_going = b.going * 0.5
		b.length = 0.4
		b.spot = null
		_enter(b, State.LAND)
	elif b.time > 4.0:
		_enter(b, State.FLY)
		b.then = Then.WHEEL
		b.ask = true


# ---------------------------------------------------------------- drawing

## Hands every bird to be drawn: those near as the whole bird, those far off as the few triangles. Each
## has its own place in both, and is nothing at all (no size) in the one it is not drawn from; and one
## that has not stirred since it was last handed over is not handed over again.
func _draw() -> void:
	var camera := get_viewport().get_camera_3d() if is_inside_tree() else null
	var eye := camera.global_position if camera else _home
	var far: float = _k["far"]
	far *= far
	var hips: float = (_frame["hips"] as Vector3).y
	var sink: float = _frame["leg"] + (_frame["body"] as Vector3).y * 0.3
	var near_changed := false
	var far_changed := false
	for b in birds:
		var shown := 0 if b.hidden > 0.0 else (2 if b.at.distance_squared_to(eye) > far else 1)
		if b.still and shown == b.shown and not manual:
			continue
		var i := b.number * 20
		if shown != b.shown:
			# (out of the one it was in)
			for data: PackedFloat32Array in [_near_data, _far_data]:
				for j in 12:
					data[i + j] = 0.0
			near_changed = true
			far_changed = true
			b.shown = shown
		if shown == 0:
			continue
		var turned := Basis.from_euler(Vector3(-b.pitch, b.yaw, b.roll))
		# (in the air it turns about its middle; on its feet, about them)
		var pivot := hips * b.size * (1.0 - minf(b.legs, 1.0))
		var at := b.at + Vector3(0.0, pivot + b.lift, 0.0) - turned.y * pivot
		if b.sunk > 0.0:
			at.y -= (sink * b.size - 0.006 * sin(b.time * 2.0 + b.number)) * b.sunk
		var data := _near_data
		if shown == 2:
			data = _far_data
			far_changed = true
		else:
			near_changed = true
		var x := turned.x * b.size
		var y := turned.y * b.size
		var z := turned.z * b.size
		data[i] = x.x
		data[i + 1] = y.x
		data[i + 2] = z.x
		data[i + 3] = at.x
		data[i + 4] = x.y
		data[i + 5] = y.y
		data[i + 6] = z.y
		data[i + 7] = at.y
		data[i + 8] = x.z
		data[i + 9] = y.z
		data[i + 10] = z.z
		data[i + 11] = at.z
		data[i + 12] = b.neck_low
		data[i + 13] = b.neck_high
		data[i + 14] = b.head
		data[i + 15] = b.extra
		data[i + 16] = b.wing_in
		data[i + 17] = b.wing_out
		data[i + 18] = b.fold
		data[i + 19] = b.legs
	if near_changed:
		_near.multimesh.buffer = _near_data
	if far_changed:
		_far.multimesh.buffer = _far_data
