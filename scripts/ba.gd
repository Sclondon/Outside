class_name Ba
extends Node3D
## The Ba: the part of a dead man that flies out of his tomb by day, a bird with
## his own head (`BaMesh`), pale, and shining a little. Here it is a friend: the
## spirit of whoever lies in the tomb, which shows the boy the way.
##
## It sits and watches him. Given places to lead him through (`route`, or
## Marker3D children, or one thing with `lead_to`), it waits until he is within
## `near` of it, then takes off and flies ahead, no further than `hop` and no
## further than he can see, lands, turns to look back at him, and waits again.
## If he hangs back or goes the wrong way it calls to him, and after `patience`
## seconds it flies back, lands by him, calls, and goes ahead again. At the
## last place it stays (or, with `leaves_at_end`, goes).
##
## With no route it is only there: it sits where it is put and watches him, or
## with `shy` it sits on what is high within `roam` of there and flits to
## another perch when he comes within `near`.
##
## It is there while `on` is true. Turned on, it flies in from nowhere, growing
## out of the air; turned off, it flies off and is gone.
##
## `show_way(points)` is for a hint: from wherever it is (from beside him, if
## it is not there) it flies those places once, lands at the last, looks back,
## and comes back again.
##
## It is a real flight: a crouch and a spring, hard beats to get up, beats and
## glides, a bank in every turn, and a flare to land. Before it goes anywhere it
## finds a way with rays that touches nothing: straight, or over, or round. If
## there is none, it goes as a spirit can: it fades where it is and comes back
## where it is going. It is not a body: nothing can touch it, catch it or be
## stopped by it, and its light is not a fire. `Ba.new()` is a whole one.

## It has landed somewhere it was leading him to, or at the end of a way it was showing.
signal arrived(at: Vector3)
## He has come to the last place with it.
signal finished
## It has called to him.
signal called
## It is back from showing a way.
signal came_back

enum State { AWAY, PERCHED, FLYING }
enum Errand { NONE, COME, AHEAD, FETCH, FLIT, SHOW, BACK, LEAVE }

## How high its body is carried over its feet, and how far it rises before it goes anywhere.
const BODY := 0.25
const LIFT := 0.45
## How much room it wants round the middle of it as it flies.
const ROOM := 0.28
## How it holds its body on a perch (tipped up), radians.
const UPRIGHT := -0.87

## The places to lead him through, in order, in the world. (Empty: any Marker3D children are the places.)
@export var route: Array[Vector3] = []
## With no route: it flits to another perch when he comes near.
@export var shy := false
## How near he must come before it flies on (or, shy, flits away).
@export var near := 4.0
## How far ahead of him it will fly at one go.
@export var hop := 10.0
## How long he may hang back before it comes for him, seconds. It calls before that.
@export var patience := 14.0
## At the last place, once he has come to it, it goes.
@export var leaves_at_end := false
## Whether it is there. Turned on it flies in; turned off it flies off.
@export var on := true
## How fast it flies, metres a second.
@export var speed := 6.5
## Shy: how far from where it was put it looks for perches.
@export var roam := 9.0
## How much it shines (0: not at all), and how far its light reaches.
@export_range(0.0, 1.0) var glow := 0.5
@export var light_reach := 2.6
## Whether it is heard.
@export var voice := true

## Whom it watches and leads. (Found by itself if not given.)
var target: Player
## How many times it has had to go as a spirit, there being no way to fly.
var spirited := 0
## How many times it has gone back for him.
var fetched := 0

var _state := State.PERCHED
var _errand := Errand.NONE
var _started := 0
var _space: PhysicsDirectSpaceState3D
var _ball: PhysicsShapeQueryParameters3D
var _ray: PhysicsRayQueryParameters3D
var _dice := RandomNumberGenerator.new()
var _home := Vector3.ZERO
# Where its feet are, or will be when it lands.
var _stand := Vector3.ZERO
# The way it leads: where it started and then each place; how far along that each is; how far along it now waits; and where that is.
var _line := PackedVector3Array()
var _marks := PackedFloat32Array()
var _at := 0.0
var _stop := Vector3.ZERO
var _goal: Node3D
var _relay := false
var _ended := false
var _done := false
var _told := true
# Waiting for him: the nearest he has been, how long he has come no nearer, when it may next call, how often it has gone back.
var _best := INF
var _idle := 0.0
var _call_in := 0.0
var _fetches := 0
var _linger := 0.0
# Perches, for a shy one.
var _perches: Array[Vector3] = []
# A way to show: asked for, and the way back from it.
var _show := PackedVector3Array()
var _show_back := PackedVector3Array()
var _show_hides := false
# The flight in hand.
var _curve: Curve3D
var _along := 0.0
var _length := 0.0
var _cruise := 6.5
var _crouch := 0.0
var _blink_to := Vector3.INF
var _blinked := false
var _fade := 1.0
var _fade_to := 1.0
# How it is held.
var _time := 0.0
var _heading := 0.0
var _pitch := UPRIGHT
var _roll := 0.0
var _spread := 0.0
var _beat := 0.0
var _phase := 0.0
var _legs_out := 1.0
var _arms_up := 0.0
var _calling := 0.0
var _ruffle := 0.0
var _ruffle_in := 5.0
var _gaze := Vector2.ZERO
var _glance := Vector2.ZERO
var _glance_in := 2.0
var _climb := 0.0

var _material: ShaderMaterial
var _pivot: Node3D
var _neck: Node3D
var _arms: MeshInstance3D
var _legs: MeshInstance3D
var _roots: Array[Node3D] = []
var _wings: Array[MeshInstance3D] = []
var _tips: Array[MeshInstance3D] = []
var _halo: MeshInstance3D
var _halo_material: ShaderMaterial
var _lamp: OmniLight3D
var _sound: AudioStreamPlayer3D
var _wing_sound: AudioStreamPlayer3D
# Where a wing is hinged to the body, and its outer half to its inner (from the model).
var _shoulder := Vector3.ZERO
var _wrist := Vector3.ZERO

# Its sounds, made once for every Ba.
static var _sounds := {}



func _ready() -> void:
	add_to_group(&"interest")
	add_to_group(&"spirits")
	_home = global_position
	_stand = _home
	_heading = global_rotation.y
	_dice.seed = hash(Vector3i(_home * 10.0))
	_build()
	_fade = 1.0 if on else 0.0
	_fade_to = _fade
	_state = State.PERCHED if on else State.AWAY
	_pose(0.0)


# --- What a level asks of it ---

## A Ba from an item of a level's layout (`LevelLayout`): its line of points is its way, the first of them where
## it sits. `ground` says how high the ground is at (x, z); every point is the item's `lift` over that. With
## anything linked to it, it is not there until that is on.
static func from_item(item: Dictionary, ground: Callable) -> Ba:
	var ba := Ba.new()
	ba.shy = item.get("shy", false)
	ba.near = item.get("near", 4.0)
	ba.hop = item.get("hop", 10.0)
	ba.patience = item.get("patience", 14.0)
	ba.leaves_at_end = item.get("leaves", false)
	ba.on = (item.get("links", []) as Array).is_empty()
	var points: Array = item.get("points", [])
	for i in range(1, points.size()):
		var x: float = points[i][0]
		var z: float = points[i][1]
		ba.route.append(Vector3(x, float(ground.call(x, z)) + float(item.get("lift", 0.0)), z))
	return ba

## Leads him to one thing (a Node3D, followed if it moves) or one place (a Vector3), from wherever it is now.
func lead_to(what: Variant) -> void:
	_goal = what as Node3D if what is Node3D else null
	route = [(what as Node3D).global_position if what is Node3D else what as Vector3]
	_relay = true


## Flies these places once, ahead of him, lands at the last and comes back: a hint, for when he is stuck.
## (`arrived` when it is at the last of them, `came_back` when it is back.)
func show_way(points: PackedVector3Array) -> void:
	_show = points


## As it was when the level began: where it was put, at the start of its way.
func reset() -> void:
	_started = 0
	_curve = null
	_blink_to = Vector3.INF
	_show = PackedVector3Array()
	_linger = 0.0
	_errand = Errand.NONE
	global_position = _home
	_stand = _home
	_state = State.PERCHED if on else State.AWAY
	_fade = 1.0 if on else 0.0
	_fade_to = _fade


func is_perched() -> bool:
	return _state == State.PERCHED


func is_flying() -> bool:
	return _state == State.FLYING


## Whether it is not there at all.
func is_away() -> bool:
	return _state == State.AWAY


## Whether it has brought him to the last place.
func is_finished() -> bool:
	return _done


## Which of the places it has got to: 0 for where it began, 1 for the first of `route`, and so on.
func place() -> int:
	var reached := 0
	for i in _marks.size():
		if _at >= _marks[i] - 0.05:
			reached = i
	return reached


## What it is about: one of `Errand`.
func errand() -> Errand:
	return _errand


# --- Every step: what it decides ---

func _physics_process(delta: float) -> void:
	_space = get_world_3d().direct_space_state
	if target == null or not is_instance_valid(target):
		target = Nearby.player(get_tree())
	# (a moment for whatever is solid in the level to be there)
	if _started < 3:
		_started += 1
		if _started == 3:
			_begin()
		return
	if _relay:
		_relay = false
		_lay_line()
	match _state:
		State.AWAY:
			if not _show.is_empty():
				_start_show()
			elif on:
				_come()
		State.PERCHED:
			_wait(delta)


# Finds its feet, its way, and (shy) its perches.
func _begin() -> void:
	if route.is_empty():
		for child in get_children():
			if child is Marker3D:
				route.append((child as Marker3D).global_position)
	var down := _stand_at(_home)
	_stand = down if down != Vector3.INF else _home
	if route.is_empty() and shy:
		_scan()
		if not _perches.is_empty():
			_stand = _perches[0]
	_lay_line()
	if _state == State.PERCHED:
		global_position = _stand


# The way it leads, from where it stands now.
func _lay_line() -> void:
	_line = PackedVector3Array([_stand])
	for point in route:
		_line.append(point)
	_measure()
	_at = 0.0
	_stop = _stand
	_ended = false
	_done = false
	_told = true
	_fetches = 0
	_reset_wait()


func _measure() -> void:
	_marks = PackedFloat32Array([0.0])
	for i in range(1, _line.size()):
		_marks.append(_marks[i - 1] + _line[i - 1].distance_to(_line[i]))


# The place a distance along its way.
func _point_at(far: float) -> Vector3:
	for i in range(1, _line.size()):
		if far <= _marks[i]:
			var long := _marks[i] - _marks[i - 1]
			return _line[i - 1].lerp(_line[i], (far - _marks[i - 1]) / long if long > 0.001 else 1.0)
	return _line[_line.size() - 1]


func _reset_wait() -> void:
	_best = INF
	_idle = 0.0
	_call_in = 0.0


# On a perch: what it does about him.
func _wait(delta: float) -> void:
	if _errand == Errand.LEAVE:
		# (going where it stands, there being no way to fly off)
		if _fade <= 0.01:
			_gone()
		return
	if not on and not _show_hides:
		_leave()
		return
	if _linger > 0.0:
		_linger -= delta
		if _linger <= 0.0:
			_after_linger()
		return
	if not _show.is_empty():
		_start_show()
		return
	if target == null:
		return
	var him := target.global_position
	var far := Vector2(him.x - _stand.x, him.z - _stand.z).length() + maxf(absf(him.y - _stand.y) - 2.5, 0.0)
	if _line.size() < 2:
		if shy and far < near:
			_flit(him)
		return
	if _ended:
		# (at the last place it waits for him as at any other, until he has come)
		if _done:
			return
		if far < near:
			_done = true
			finished.emit()
			if leaves_at_end:
				on = false
			return
	else:
		# He has come: on it goes. (And if he has gone on ahead of it.)
		var next := _next_place()
		if far < near or him.distance_to(next) + 1.0 < _stand.distance_to(next):
			_go_on(him)
			return
	# He has not: it calls, and in the end goes back for him.
	if far < _best - 0.5:
		_best = far
		_idle = 0.0
	else:
		_idle += delta
	var strays := far > _best + 4.0
	_call_in -= delta
	if (strays or _idle > patience * 0.45) and _call_in <= 0.0:
		_call()
		_call_in = 4.5 + _fetches * 2.0
	if _idle > patience * (1.0 + _fetches) or far > _best + 9.0 * (1.0 + _fetches):
		_fetch(him)


# The next of the places it is leading him to.
func _next_place() -> Vector3:
	for i in range(1, _line.size()):
		if _marks[i] > _at + 0.05:
			return _line[i]
	return _line[_line.size() - 1]


# Flies ahead: to the next place, or as far towards it as `hop`, or short of that if he could not see it there.
func _go_on(him: Vector3) -> void:
	if is_instance_valid(_goal):
		_line[_line.size() - 1] = _goal.global_position
		_measure()
	var total := _marks[_marks.size() - 1]
	var want := minf(_at + hop, total)
	for mark in _marks:
		if mark > _at + 0.05:
			want = minf(want, mark)
			break
	var eye := him + Vector3.UP * 1.3
	var far := want
	var to := Vector3.INF
	var first := Vector3.INF
	var first_far := want
	while far > _at + 2.0 or far == want:
		var spot := _stand_at(_point_at(far))
		if spot != Vector3.INF:
			if first == Vector3.INF:
				first = spot
				first_far = far
			if _sees(eye, spot + Vector3.UP * 0.4):
				to = spot
				break
		far -= 1.0
	if to == Vector3.INF:
		# (nowhere he can see: where it meant to go, then, and he saw it leave)
		to = first
		far = first_far
	if to == Vector3.INF:
		return
	_at = far
	_stop = to
	_told = false
	_fetches = 0
	_fly(to, Errand.AHEAD)


# Goes back to him: lands by him, on the side it wants him to go.
func _fetch(him: Vector3) -> void:
	var spot := _beside(him, _stop)
	_idle = 0.0
	_best = INF
	if spot == Vector3.INF:
		_call()
		return
	_fetches += 1
	fetched += 1
	_fly(spot, Errand.FETCH, clampf(spot.distance_to(_stand) / 14.0, 1.0, 3.0))


# Somewhere to land about 2.5 m from him that he can see, towards `towards` if it can be.
func _beside(him: Vector3, towards: Vector3) -> Vector3:
	var way := Vector3(towards.x - him.x, 0.0, towards.z - him.z)
	way = way.normalized() if way.length() > 0.1 else Vector3.BACK
	var eye := him + Vector3.UP * 1.3
	for reach: float in [2.6, 1.8]:
		for turn: float in [0.0, 0.6, -0.6, 1.2, -1.2, 2.0, -2.0, PI]:
			var spot := _stand_at(him + way.rotated(Vector3.UP, turn) * reach + Vector3.UP * 0.3)
			if spot != Vector3.INF and absf(spot.y - him.y) < 1.5 and _sees(eye, spot + Vector3.UP * 0.4):
				return spot
	return Vector3.INF


# Shy: off to the perch furthest from him.
func _flit(him: Vector3) -> void:
	var to := Vector3.INF
	var most := near + 1.0
	for perch in _perches:
		var off := perch.distance_to(him)
		if off > most and perch.distance_to(_stand) > 1.0:
			most = off
			to = perch
	if to == Vector3.INF:
		return
	_fly(to, Errand.FLIT)


# What is high and flat within `roam` of where it was put, to sit on: found with rays straight down, once.
func _scan() -> void:
	_perches.clear()
	var top := _home.y + 12.0
	var roof := _hit(_home + Vector3.UP * 0.5, Vector3(_home.x, top, _home.z))
	if not roof.is_empty():
		top = (roof["position"] as Vector3).y - 0.3
	var high: Array[Vector3] = []
	var low: Array[Vector3] = []
	for k in 56:
		var out := roam * sqrt((k + 0.5) / 56.0)
		var turn := k * 2.39996
		var over := Vector3(_home.x + cos(turn) * out, top, _home.z + sin(turn) * out)
		var found := _hit(over, over + Vector3.DOWN * (top - _home.y + 6.0))
		if found.is_empty() or (found["normal"] as Vector3).y < 0.85:
			continue
		var spot: Vector3 = found["position"]
		if not _free(spot + Vector3.UP * (ROOM + 0.1)):
			continue
		if spot.y > _home.y + 0.5:
			high.append(spot)
		else:
			low.append(spot)
	# (rays may miss what is narrow: the top of each solid thing near is looked at too)
	var about := PhysicsShapeQueryParameters3D.new()
	var reach := SphereShape3D.new()
	reach.radius = roam
	about.shape = reach
	about.transform = Transform3D(Basis.IDENTITY, _home)
	about.collision_mask = 1
	var seen := {}
	for found: Dictionary in _space.intersect_shape(about, 64):
		var body := found["collider"] as CollisionObject3D
		if body == null or seen.has(body):
			continue
		seen[body] = true
		for child in body.get_children():
			var solid := child as CollisionShape3D
			if solid == null or solid.disabled or solid.shape == null:
				continue
			var box := solid.global_transform * _bounds(solid.shape)
			# (not the ground, nor a wall of the place itself)
			if box.size == Vector3.ZERO or maxf(box.size.x, box.size.z) > 12.0:
				continue
			var middle := Vector3(box.get_center().x, box.end.y, box.get_center().z)
			var on_it := _hit(middle + Vector3.UP * 0.5, middle + Vector3.DOWN * 0.7)
			if on_it.is_empty() or (on_it["normal"] as Vector3).y < 0.7:
				continue
			var spot: Vector3 = on_it["position"]
			if spot.y > _home.y + 0.5 and spot.y < top and spot.distance_to(_home) < roam and _free(spot + Vector3.UP * (ROOM + 0.1)):
				high.append(spot)
	for group: StringName in [&"perches", &"bird_perches"]:
		for mark in get_tree().get_nodes_in_group(group):
			if mark is Node3D and (mark as Node3D).global_position.distance_to(_home) < roam:
				high.append((mark as Node3D).global_position)
	# (the nearest high thing first: that is where it starts)
	high.sort_custom(func(a: Vector3, b: Vector3) -> bool: return a.distance_squared_to(_home) < b.distance_squared_to(_home))
	_perches = []
	for spot in high:
		var fresh := true
		for other in _perches:
			if other.distance_to(spot) < 0.7:
				fresh = false
		if fresh:
			_perches.append(spot)
	if _perches.size() < 3:
		for k in range(0, low.size(), 4):
			_perches.append(low[k])


# The box a shape fits in, in its own space (nothing, for the shapes the ground is made of).
func _bounds(shape: Shape3D) -> AABB:
	if shape is BoxShape3D:
		var size := (shape as BoxShape3D).size
		return AABB(-size * 0.5, size)
	if shape is CylinderShape3D or shape is CapsuleShape3D:
		var wide: float = shape.get(&"radius")
		var tall: float = shape.get(&"height")
		return AABB(Vector3(-wide, -tall * 0.5, -wide), Vector3(wide * 2.0, tall, wide * 2.0))
	if shape is SphereShape3D:
		var wide := (shape as SphereShape3D).radius
		return AABB(Vector3.ONE * -wide, Vector3.ONE * wide * 2.0)
	if shape is ConvexPolygonShape3D:
		var points := (shape as ConvexPolygonShape3D).points
		if points.is_empty():
			return AABB()
		var box := AABB(points[0], Vector3.ZERO)
		for point in points:
			box = box.expand(point)
		return box
	return AABB()


# Flies a way it has been asked to show.
func _start_show() -> void:
	var points := _show
	_show = PackedVector3Array()
	_show_hides = _state == State.AWAY
	if _show_hides:
		# (it was not there: it comes out of the air beside him)
		var beside := _beside(target.global_position, points[0]) if target else Vector3.INF
		if beside == Vector3.INF:
			beside = _stand_at(points[0])
		if beside == Vector3.INF:
			return
		_stand = beside
		global_position = beside
		_state = State.PERCHED
		_fade_to = 1.0
	var end := _stand_at(points[points.size() - 1])
	if end == Vector3.INF:
		return
	var way := PackedVector3Array()
	var from := _stand
	var from_air := false
	for i in points.size():
		var last := i == points.size() - 1
		var to := end if last else points[i] + Vector3.UP * 0.9
		if not last and not _free(to):
			continue
		var part := _plan(from, to, from_air, not last)
		if part.is_empty():
			way = PackedVector3Array()
			break
		for k in range(1 if not way.is_empty() else 0, part.size()):
			way.append(part[k])
		from = to
		from_air = true
	_show_back = way.duplicate()
	_show_back.reverse()
	if way.is_empty():
		# (no way to fly it: there and back as a spirit)
		_show_back = PackedVector3Array([end, _stand])
		_spirit(end, Errand.SHOW)
		return
	_fly_along(way, Errand.SHOW)


func _after_linger() -> void:
	match _errand:
		Errand.FETCH:
			_fly(_stop, Errand.AHEAD)
		Errand.SHOW:
			var back := _show_back
			if back.size() == 2 and back[0].distance_to(_stand) < 0.01 and _plan(back[0], back[1]).is_empty():
				_spirit(back[1], Errand.BACK)
			else:
				_fly_along(back, Errand.BACK)


# Comes into the level: in from the air a little way off, growing out of nothing.
func _come() -> void:
	var perch := _stop if _line.size() > 1 else _stand
	_stand = perch
	_fade = 0.0
	_fade_to = 1.0
	for from in _air_about(perch):
		var way := _plan(from, perch, true, false)
		if not way.is_empty():
			global_position = from
			_fly_along(way, Errand.COME)
			return
	global_position = perch
	_state = State.PERCHED
	_errand = Errand.NONE
	_reset_wait()


# Goes: up and off, thinning away.
func _leave() -> void:
	for to in _air_about(_stand):
		var way := _plan(_stand, to, false, true)
		if not way.is_empty():
			_fly_along(way, Errand.LEAVE)
			return
	_errand = Errand.LEAVE
	_fade_to = 0.0


func _gone() -> void:
	_state = State.AWAY
	_errand = Errand.NONE
	_fade = 0.0
	_fade_to = 0.0
	visible = false


# Places in the air round a perch, to come from or go to: away from him first.
func _air_about(perch: Vector3) -> Array[Vector3]:
	var away := Vector3.BACK
	if target:
		var off := perch - target.global_position
		off.y = 0.0
		if off.length() > 0.5:
			away = off.normalized()
	var found: Array[Vector3] = []
	for turn: float in [0.0, 0.8, -0.8, 1.6, -1.6, 2.4, -2.4, PI]:
		for reach: Vector2 in [Vector2(5.0, 3.5), Vector2(3.0, 1.6)]:
			var at := perch + away.rotated(Vector3.UP, turn) * reach.x + Vector3.UP * reach.y
			if _free(at):
				found.append(at)
	return found


func _call() -> void:
	_calling = 1.7
	called.emit()
	if voice and _sound:
		_sound.pitch_scale = _dice.randf_range(0.94, 1.06)
		_sound.play()


# --- Finding a way ---

# Where it would stand at a place: on whatever is under it, with room for it there. INF if there is nowhere.
func _stand_at(place: Vector3) -> Vector3:
	var under := _hit(place + Vector3.UP * 0.6, place + Vector3.DOWN * 4.0)
	var spot: Vector3 = under["position"] if not under.is_empty() else place
	if _free(spot + Vector3.UP * (ROOM + 0.1)) and not under.is_empty():
		return spot
	# (the place is inside something: on top of it, then, if there is room)
	var over := _hit(place + Vector3.UP * 3.0, place)
	if not over.is_empty():
		spot = over["position"]
		if _free(spot + Vector3.UP * (ROOM + 0.1)):
			return spot
	if under.is_empty() and _free(place + Vector3.UP * (ROOM + 0.1)):
		return place
	return Vector3.INF


# A way from one place to another that touches nothing, as a line of points: straight if it can be,
# or higher, or round one side. Either end may be in the air already. Empty if there is none.
func _plan(a: Vector3, b: Vector3, a_air := false, b_air := false) -> PackedVector3Array:
	var from := a if a_air else a + Vector3.UP * LIFT
	var to := b if b_air else b + Vector3.UP * LIFT
	var flat := Vector3(to.x - from.x, 0.0, to.z - from.z)
	var far := flat.length()
	var way := flat / far if far > 0.01 else Vector3.BACK
	var side := way.cross(Vector3.UP)
	var lean := minf(far * 0.25, 1.4)
	var ends := PackedVector3Array()
	if not a_air:
		ends.append(a)
	var roof_a := _roof(from)
	var roof_b := _roof(to)
	for over: float in [clampf(far * 0.16, 0.4, 1.8), 2.8, 4.5, 7.0, 11.0, 18.0]:
		var top := (maxf(from.y, to.y) if a_air == b_air else (to.y if a_air else from.y)) + over
		var up_a := from if a_air else Vector3(from.x, clampf(top, from.y, maxf(roof_a, from.y)), from.z) + way * lean
		var up_b := to if b_air else Vector3(to.x, clampf(top, to.y, maxf(roof_b, to.y)), to.z) - way * lean
		for off: float in ([0.0, 1.6, -1.6, 3.2, -3.2, 5.5, -5.5] if over < 2.9 else [0.0]):
			var points := PackedVector3Array([from, up_a])
			if off != 0.0:
				points.append(up_a.lerp(up_b, 0.5) + side * off)
			points.append(up_b)
			points.append(to)
			var good := true
			for i in points.size() - 1:
				if not _clear(points[i], points[i + 1]):
					good = false
					break
			if good:
				var found := ends.duplicate()
				found.append_array(points)
				if not b_air:
					found.append(b)
				return found
	return PackedVector3Array()


# How high it may go over a place: to the roof, if there is one, less its own room.
func _roof(over: Vector3) -> float:
	var found := _hit(over, over + Vector3.UP * 20.0)
	return INF if found.is_empty() else (found["position"] as Vector3).y - ROOM - 0.15


func _hit(from: Vector3, to: Vector3) -> Dictionary:
	if _ray == null:
		_ray = PhysicsRayQueryParameters3D.new()
		_ray.collision_mask = 1
	_ray.from = from
	_ray.to = to
	return _space.intersect_ray(_ray)


func _probe() -> PhysicsShapeQueryParameters3D:
	if _ball == null:
		var round := SphereShape3D.new()
		round.radius = ROOM
		_ball = PhysicsShapeQueryParameters3D.new()
		_ball.shape = round
		_ball.collision_mask = 1
	return _ball


# Whether there is room for it with its middle at a place.
func _free(at: Vector3) -> bool:
	var ball := _probe()
	ball.transform = Transform3D(Basis.IDENTITY, at)
	ball.motion = Vector3.ZERO
	return _space.intersect_shape(ball, 1).is_empty()


# Whether it can go from one place straight to another and touch nothing.
func _clear(from: Vector3, to: Vector3) -> bool:
	if from.distance_squared_to(to) < 0.0001:
		return _free(from)
	var ball := _probe()
	ball.transform = Transform3D(Basis.IDENTITY, from)
	ball.motion = to - from
	return _space.cast_motion(ball)[0] >= 0.999


# Whether nothing stands between an eye and a place.
func _sees(eye: Vector3, place: Vector3) -> bool:
	var found := _hit(eye, place)
	return found.is_empty() or (found["position"] as Vector3).distance_to(place) < 0.3


# --- Flying ---

# Flies to somewhere to stand, by whatever way there is; as a spirit, if there is none.
func _fly(to: Vector3, errand: Errand, haste := 1.0) -> void:
	var way := _plan(_stand, to)
	if way.is_empty():
		_spirit(to, errand)
		return
	_fly_along(way, errand, haste)


# Flies a line of points that has been found clear. The last is where it will stand (or, leaving, where it is gone).
func _fly_along(line: PackedVector3Array, errand: Errand, haste := 1.0) -> void:
	_errand = errand
	_state = State.FLYING
	_stand = line[line.size() - 1]
	# (no point twice running: a curve cannot be drawn through that)
	var points := PackedVector3Array()
	for point in line:
		if points.is_empty() or points[points.size() - 1].distance_to(point) > 0.03:
			points.append(point)
	if points.size() < 2:
		points.append(_stand + Vector3.UP * 0.05)
		points.append(_stand)
	_curve = _curve_through(points, 0.3)
	if not _curve_clear(_curve):
		_curve = _curve_through(points, 0.0)
	_length = _curve.get_baked_length()
	_along = 0.0
	_cruise = speed * haste
	_crouch = 0.0 if errand == Errand.COME else 0.16
	_calling = 0.0
	if voice and _wing_sound and errand != Errand.COME:
		_wing_sound.play()


# Goes as a spirit: fades where it is, and comes back where it is going.
func _spirit(to: Vector3, errand: Errand) -> void:
	spirited += 1
	_errand = errand
	_state = State.FLYING
	_curve = null
	_blink_to = to
	_blinked = false
	_fade_to = 0.0


# A curve through points, rounded at each by `round` of the way to its neighbours.
func _curve_through(points: PackedVector3Array, round: float) -> Curve3D:
	var curve := Curve3D.new()
	curve.bake_interval = 0.1
	for i in points.size():
		var before := Vector3.ZERO
		var after := Vector3.ZERO
		if round > 0.0 and i > 0 and i < points.size() - 1:
			var along := (points[i + 1] - points[i - 1]).normalized()
			before = -along * points[i].distance_to(points[i - 1]) * round
			after = along * points[i].distance_to(points[i + 1]) * round
		curve.add_point(points[i], before, after)
	return curve


# Whether a curve touches nothing: looked at with a ray from each half metre of it to the next (its ends are on the ground: not those).
func _curve_clear(curve: Curve3D) -> bool:
	var long := curve.get_baked_length()
	var from := curve.sample_baked(minf(0.5, long))
	var far := 0.5
	while far < long - 0.5:
		far = minf(far + 0.5, long - 0.5)
		var to := curve.sample_baked(far)
		if not _hit(from, to).is_empty():
			return false
		from = to
	return true


func _process(delta: float) -> void:
	_time += delta
	_fade = move_toward(_fade, _fade_to, delta * 1.8)
	if _state == State.AWAY and _fade <= 0.0:
		if visible:
			_pose(delta)
			visible = false
		return
	visible = true
	if _state == State.FLYING:
		_advance(delta)
	_pose(delta)


# Moves it along its way.
func _advance(delta: float) -> void:
	if _blink_to != Vector3.INF:
		if not _blinked:
			_fade_to = 0.0
			if _fade <= 0.02:
				global_position = _blink_to
				_stand = _blink_to
				_blinked = true
				_fade_to = 0.0 if _errand == Errand.LEAVE else 1.0
		elif _fade >= 0.98 or _errand == Errand.LEAVE:
			_blink_to = Vector3.INF
			_land()
		return
	if _curve == null:
		return
	if _crouch > 0.0:
		_crouch -= delta
		return
	var left := _length - _along
	var pace := minf(_cruise, minf(sqrt(1.5 + 18.0 * _along), sqrt(0.5 + 14.0 * left)))
	_along = minf(_along + pace * delta, _length)
	left = _length - _along
	var at := _curve.sample_baked(_along, true)
	var way := _curve.sample_baked(minf(_along + 0.25, _length), true) - _curve.sample_baked(maxf(_along - 0.1, 0.0), true)
	var turned := 0.0
	if Vector2(way.x, way.z).length() > 0.05:
		turned = angle_difference(_heading, atan2(way.x, way.z)) * minf(delta * 9.0, 1.0)
		_heading += turned
	# It leans into its turns, noses up as it climbs, and rears back to land.
	var bank := clampf(-turned / maxf(delta, 0.001) * pace / 9.8 * 0.8, -0.95, 0.95)
	_roll = lerpf(_roll, bank, minf(delta * 6.0, 1.0))
	_climb = way.normalized().y if way.length() > 0.001 else 0.0
	var flare := 1.0 - smoothstep(0.0, 1.3, left) if _errand != Errand.LEAVE else 0.0
	_pitch = lerpf(_pitch, -asin(clampf(_climb, -1.0, 1.0)) * 0.75 - flare * 0.75, minf(delta * 8.0, 1.0))
	var settle := minf(smoothstep(0.0, 0.5, _along), smoothstep(0.0, 0.5, left))
	global_position = at - Vector3.UP * BODY * settle
	if _errand == Errand.LEAVE:
		_fade_to = 1.0 - smoothstep(0.25, 0.9, _along / maxf(_length, 0.01))
	if left <= 0.001:
		_land()


# Down: and what follows from having got there.
func _land() -> void:
	_curve = null
	_state = State.PERCHED
	global_position = _stand
	_reset_wait()
	match _errand:
		Errand.AHEAD:
			if _marks.size() > 1 and _at >= _marks[_marks.size() - 1] - 0.05:
				_ended = true
			if not _told:
				_told = true
				arrived.emit(_stand)
		Errand.FETCH:
			_linger = 1.3
			_call()
		Errand.SHOW:
			_linger = 1.8
			arrived.emit(_stand)
			_call()
		Errand.BACK:
			came_back.emit()
			if _show_hides:
				_show_hides = false
				_errand = Errand.LEAVE
				_fade_to = 0.0
				return
		Errand.LEAVE:
			_gone()
			return
	if _errand != Errand.FETCH and _errand != Errand.SHOW:
		_errand = Errand.NONE


# --- How it is held and drawn ---

func _pose(delta: float) -> void:
	var flying := _state == State.FLYING and _blink_to == Vector3.INF
	var left := _length - _along
	# Wings: shut on a perch; open to fly, beating hard to get up and to land, beating and gliding by turns between.
	var spread_to := 0.0
	var beat_to := 0.0
	var rate := 4.6
	if flying:
		spread_to = 1.0
		if _crouch > 0.0:
			beat_to = 0.0
		elif _along < 1.6 or left < 1.4:
			beat_to = 1.0
			rate = 7.0
		elif _climb < -0.12 or fmod(_along, 6.5) > 4.2:
			beat_to = 0.0
		else:
			beat_to = 0.62
	else:
		_pitch = lerpf(_pitch, UPRIGHT, minf(delta * 7.0, 1.0))
		_roll = lerpf(_roll, 0.0, minf(delta * 7.0, 1.0))
		if _calling > 0.0:
			_calling -= delta
			spread_to = 0.8
			beat_to = 0.45
			rate = 5.0
		# (now and then it shakes out its wings)
		_ruffle_in -= delta
		if _ruffle_in <= 0.0:
			_ruffle_in = _dice.randf_range(5.0, 11.0)
			_ruffle = 0.7
		if _ruffle > 0.0:
			_ruffle -= delta
			spread_to = maxf(spread_to, 0.4 * sin(clampf(_ruffle / 0.7, 0.0, 1.0) * PI))
	_spread = lerpf(_spread, spread_to, minf(delta * (11.0 if spread_to > _spread else 6.0), 1.0))
	_beat = lerpf(_beat, beat_to, minf(delta * 7.0, 1.0))
	_phase += delta * rate * TAU
	_legs_out = lerpf(_legs_out, 0.0 if flying and left > 1.2 and _along > 0.3 else 1.0, minf(delta * 9.0, 1.0))
	_arms_up = move_toward(_arms_up, 1.0 if _calling > 0.0 and not flying else 0.0, delta * 4.5)

	# On a perch it turns to face him, when he is well round to one side of it.
	var look := Vector3.INF
	if target and is_instance_valid(target):
		look = target.global_position + Vector3.UP * 1.1
	if not flying and look != Vector3.INF and delta > 0.0:
		var bearing := atan2(look.x - global_position.x, look.z - global_position.z)
		var off := angle_difference(_heading, bearing)
		if absf(off) > 0.9 or (_linger > 0.0 and absf(off) > 0.2):
			_heading += signf(off) * minf(absf(off), delta * 5.0)

	global_rotation = Vector3(0.0, _heading, 0.0)
	var crouch := 0.05 * sin(clampf(_crouch / 0.16, 0.0, 1.0) * PI) if flying else 0.0
	var bob := -sin(_phase) * 0.022 * _beat * _spread + sin(_time * 1.7) * 0.004
	_pivot.position = Vector3(0.0, BODY + bob - crouch, 0.0)
	_pivot.basis = Basis(Vector3.RIGHT, _pitch) * Basis(Vector3.BACK, _roll)

	var fold := 1.0 - _spread
	var swing := 0.14 + (0.35 + 0.6 * _beat) * _beat * sin(_phase)
	var tip := 0.75 * _beat * sin(_phase - 1.1) - 0.2 * _beat
	for i in 2:
		var side := 1.0 if i == 0 else -1.0
		_roots[i].position = Vector3(side * (_shoulder.x - 0.004 * fold), _shoulder.y + 0.025 * fold, _shoulder.z)
		_wings[i].basis = (Basis(Vector3.BACK, -fold * 1.45) * Basis(Vector3.UP, fold * 0.55) * Basis(Vector3.BACK, swing * _spread)).scaled(Vector3.ONE * (1.0 - 0.2 * fold))
		_tips[i].basis = Basis(Vector3.UP, fold * 1.1) * Basis(Vector3.BACK, tip * _spread)
		_tips[i].position = Vector3(_wrist.x, 0.006 * fold, 0.0)

	# Its head is its own: level whatever the body does, and turned to him.
	var gaze_to := Vector2.ZERO
	if look != Vector3.INF and look.distance_to(global_position) < 40.0:
		var from := _neck.global_position + Vector3.UP * 0.09
		var to := look - from
		gaze_to.x = clampf(angle_difference(_heading, atan2(to.x, to.z)), -1.9, 1.9)
		gaze_to.y = clampf(-atan2(to.y, Vector2(to.x, to.z).length()), -0.6, 0.6)
	if flying:
		gaze_to = Vector2(0.0, -_climb * 0.4)
	else:
		# (and it is never quite still)
		_glance_in -= delta
		if _glance_in <= 0.0:
			_glance_in = _dice.randf_range(1.2, 3.8)
			var wide := 0.12 if look != Vector3.INF else 1.2
			_glance = Vector2(_dice.randf_range(-wide, wide), _dice.randf_range(-0.08, 0.08))
		gaze_to += _glance
	_gaze = _gaze.lerp(gaze_to, minf(delta * 7.0, 1.0))
	_neck.global_basis = (Basis(Vector3.UP, _heading + _gaze.x) * Basis(Vector3.RIGHT, _gaze.y))

	_legs.position = Vector3(0.0, 0.0, 0.0).lerp(Vector3(0.0, 0.17, -0.05), 1.0 - _legs_out)
	_legs.basis = Basis(Vector3.RIGHT, (1.0 - _legs_out) * 1.25).scaled(Vector3.ONE * lerpf(0.75, 1.0, _legs_out))
	_arms.visible = _arms_up > 0.02
	if _arms.visible:
		_arms.global_basis = (Basis(Vector3.UP, _heading) * Basis(Vector3.RIGHT, sin(_time * 9.0) * 0.16 * _arms_up)).scaled(Vector3.ONE * _arms_up)

	_material.set_shader_parameter(&"fade", _fade)
	_material.set_shader_parameter(&"glow", glow)
	var breath := 1.0 + 0.12 * sin(_time * 2.3)
	_halo.visible = glow > 0.0 and _fade > 0.01
	_halo_material.set_shader_parameter(&"power", glow * 0.3 * _fade * breath)
	_lamp.visible = glow > 0.0 and _fade > 0.01
	_lamp.light_energy = glow * 1.0 * _fade * breath


func _build() -> void:
	_material = BaMesh.material()
	_shoulder = BaMesh.at("wing_arm")
	_wrist = BaMesh.at("wing_hand")
	_pivot = Node3D.new()
	add_child(_pivot)
	_part(_pivot, "body")
	_neck = Node3D.new()
	_neck.position = BaMesh.at("head")
	_pivot.add_child(_neck)
	_part(_neck, "head")
	for side: float in [1.0, -1.0]:
		# (the other wing is the same one, turned over)
		var root := Node3D.new()
		root.scale = Vector3(side, 1.0, 1.0)
		_pivot.add_child(root)
		var wing := _part(root, "wing_arm")
		var tip := _part(wing, "wing_hand")
		tip.position = Vector3(_wrist.x, 0.0, 0.0)
		_roots.append(root)
		_wings.append(wing)
		_tips.append(tip)
	_arms = _part(_pivot, "arms")
	_arms.position = BaMesh.at("arms")
	_legs = _part(self, "legs")
	# The light round it, and the light it sheds: pale, and not a fire.
	_halo_material = BaMesh.halo()
	var card := QuadMesh.new()
	card.size = Vector2.ONE
	card.material = _halo_material
	_halo = MeshInstance3D.new()
	_halo.mesh = card
	_halo.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_halo.scale = Vector3.ONE * 1.25
	_halo.extra_cull_margin = 1.5
	_pivot.add_child(_halo)
	_lamp = OmniLight3D.new()
	_lamp.light_color = Color(0.78, 0.9, 1.0)
	_lamp.omni_range = light_reach
	_lamp.omni_attenuation = 1.3
	_lamp.shadow_enabled = false
	_lamp.position = Vector3(0.0, 0.12, 0.0)
	_pivot.add_child(_lamp)
	if voice:
		_sound = _speaker(_voice_of_it(), -7.0)
		_wing_sound = _speaker(_flutter(), -16.0)


func _part(under: Node3D, which: String) -> MeshInstance3D:
	var part := MeshInstance3D.new()
	part.mesh = BaMesh.piece(which)
	part.material_override = _material
	part.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	part.extra_cull_margin = 0.5
	under.add_child(part)
	return part


func _speaker(stream: AudioStream, loud: float) -> AudioStreamPlayer3D:
	var speaker := AudioStreamPlayer3D.new()
	speaker.stream = stream
	speaker.volume_db = loud
	speaker.unit_size = 7.0
	speaker.max_distance = 45.0
	add_child(speaker)
	return speaker


# Its call: two soft notes, the second higher, like a breath across a reed. Made here.
static func _voice_of_it() -> AudioStreamWAV:
	if _sounds.has("call"):
		return _sounds["call"]
	const RATE := 22050
	var count := int(0.62 * RATE)
	var data := PackedByteArray()
	data.resize(count * 2)
	var noise := RandomNumberGenerator.new()
	noise.seed = 11
	var phase := 0.0
	var hiss := 0.0
	for i in count:
		var t := float(i) / count
		var second := t > 0.42
		var pitch := (880.0 if second else 660.0) * (1.0 + 0.012 * sin(t * 62.0))
		phase += TAU * pitch / RATE
		var into := (t - 0.42) / 0.58 if second else t / 0.42
		var swell := smoothstep(0.0, 0.18, into) * (1.0 - smoothstep(0.45 if second else 0.6, 1.0, into))
		hiss = lerpf(hiss, noise.randf_range(-1.0, 1.0), 0.3)
		var sample := sin(phase) + 0.22 * sin(phase * 2.0) + 0.07 * sin(phase * 3.0) + hiss * 0.12
		data.encode_s16(i * 2, int(clampf(sample * swell * 0.4, -1.0, 1.0) * 32767.0))
	var stream := AudioStreamWAV.new()
	_sounds["call"] = stream
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = RATE
	stream.data = data
	return stream


# Its wings as it gets up: a few soft beats of air.
static func _flutter() -> AudioStreamWAV:
	if _sounds.has("flutter"):
		return _sounds["flutter"]
	const RATE := 22050
	var count := int(0.7 * RATE)
	var data := PackedByteArray()
	data.resize(count * 2)
	var noise := RandomNumberGenerator.new()
	noise.seed = 5
	var soft := 0.0
	for i in count:
		var t := float(i) / RATE
		soft = lerpf(soft, noise.randf_range(-1.0, 1.0), 0.08)
		var beat := pow(maxf(sin(t * 7.0 * TAU), 0.0), 3.0)
		var whole := 1.0 - smoothstep(0.3, 0.7, t)
		data.encode_s16(i * 2, int(clampf(soft * beat * whole * 1.6, -1.0, 1.0) * 32767.0))
	var stream := AudioStreamWAV.new()
	_sounds["flutter"] = stream
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = RATE
	stream.data = data
	return stream
