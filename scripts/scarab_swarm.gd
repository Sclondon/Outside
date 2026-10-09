class_name ScarabSwarm
extends Node3D
## A swarm of scarabs: a black carpet of beetles that pours out of a hole (this
## node is the hole: the `nest`), runs over the ground and up and over whatever
## is low enough, and goes for the boy. `ScarabSwarm.new()` is a whole one.
##
##     var swarm := ScarabSwarm.new()
##     swarm.count = 150
##     swarm.position = the_crack_in_the_wall
##     add_child(swarm)
##     swarm.target = player          # (it finds him itself if it is not told)
##     swarm.caught.connect(...)      # as for a Hound or a Mummy
##     swarm.chasing = true           # out they come; `false` calls them home; `reset()` puts them back at once
##
## They are staged as such swarms are in the films and games they come from
## (the flesh-eating scarabs of The Mummy; the beetles of Tomb Raider: The Last
## Revelation, which pour out of a hole, cannot be killed, and are got away
## from by getting up onto something; the spiders of Uncharted 3, which a
## torch holds in a ring round whoever carries it):
##
## - He outruns them (`speed` is between his walk and his run), jumps over the
##   front of them, or gets up onto anything higher than `climb`.
## - FIRE HOLDS THEM OFF. They will not come nearer a `Fire` than `fire_reach`
##   (for a torch; more for a brazier, a bonfire or a flare), whether it stands
##   or he carries it: they part round it and run round the edge of its light,
##   and with a torch in his hand he walks through them. `fears_fire` off, they
##   take no notice.
## - Water stops them: they will not go into a `Pool`.
## - Those that reach him run up his legs. A few can be shaken off by running
##   or jumping, and a fire drives them off; `catch_count` of them on him for
##   `catch_time` and he is `caught`.
## - When they have got no nearer to him for `give_up_after` seconds (he is up
##   on something, or across water, or gone), or he is further than
##   `chase_distance` from the nest, they stream home and go back down the hole.
##
## The cost is flat. There is no body to a beetle: all of them are one
## MultiMesh, moved here in one loop and written to it in one piece. What the
## ground is like is found with a ray straight down, once for each square of
## a grid (`CELL` across) round the nest as a beetle first comes to it, and
## remembered: a square is its height, or cannot be entered (water; a face
## higher than they climb). They keep apart by counting themselves into the
## same squares and moving away from the fuller ones. `tools/scarab_sheets.gd`
## prints what a frame of it costs.
##
## `harmless` makes a few beetles that wander about where they are put, run
## from his feet, and do nothing else: dressing for a tomb or a dune. With
## `dung_ball` the first of them rolls a ball of dung about, backwards, as
## they do.
##
## While they are out, a node at the front of them is in the group `pursuers`
## (`front`): the boy watches it, and the cat and the camel keep away from it.

## They have reached him and brought him down.
signal caught
signal came_out
signal went_home

## How many beetles.
@export_range(1, 400) var count := 150
## How long a beetle is, in metres. (The real one is 0.03; these are film scarabs.)
@export var beetle_size := 0.1
## How fast they run, metres a second: faster than he walks, slower than he runs.
@export var speed := 3.3
## How far from the nest they will follow him.
@export var chase_distance := 22.0
## Whether fire holds them off, and how near a torch they will come (m).
@export var fears_fire := true
@export var fire_reach := 2.0
## They come out by themselves when he is within this of the nest (0: only when they are let out).
@export var alert_distance := 0.0
## How many come out of the nest a second.
@export var pour_rate := 150.0
## The highest face they will go up, and the furthest they will drop (m).
@export var climb := 0.7
@export var drop := 2.5
## How many on him bring him down (never more than a third of them), and how long they need.
@export var catch_count := 12
@export var catch_time := 0.8
## How long they go on trying when they are getting no nearer, seconds.
@export var give_up_after := 6.0
## After giving up, how long before they will come out again by themselves.
@export var rest_time := 5.0
## Wandering beetles that do no harm.
@export var harmless := false
## How far the harmless ones wander from where they are put.
@export var roam := 2.5
## The first of the harmless ones rolls a ball of dung.
@export var dung_ball := false
## A dark hole drawn on the ground under the nest for them to come out of.
@export var hole := true
## The dry rustle of them.
@export var voice := true

## Who they go for. Left empty, the player.
var target: Player: set = _set_target
## Whether they are out after him. Setting it lets them out or calls them home.
var chasing: bool:
	get:
		return _mode == Mode.HUNT
	set(value):
		if value:
			release()
		else:
			recall()
## The front of the swarm: in the group `pursuers` while they are out.
var front: Front
## How many are out of the nest, and how many of those are on him.
var out := 0
var on_him := 0
## How many were kept back by a fire in the last frame.
var held_off := 0

enum Mode { DORMANT, HUNT, HOME, MILL }
const HIDDEN := 0
const OUT := 1
const ON_HIM := 2
const FLUNG := 3

## The side of a square of the ground they remember, metres.
const CELL := 0.2
## A square that cannot be entered.
const BLOCKED := 1000000.0
## How many squares of ground are looked at afresh in one frame, at most.
const RAYS := 28
## How many beetles to a square before they push apart.
const CROWD := 3


## The front of a swarm, as the things that fear pursuers see it.
class Front extends Node3D:
	var chasing := false


var _mode := Mode.DORMANT
var _time := 0.0
var _rest := 0.0
var _fed := false
var _meter := 0.0
var _pour := 0.0
var _next_out := 0
var _best_seen := INF
var _gap := 0.0
var _stuck_for := 0.0
var _refresh := 0
var _rays := 0

# Each beetle.
var _state := PackedByteArray()
var _x := PackedFloat32Array()
var _y := PackedFloat32Array()
var _z := PackedFloat32Array()
var _hx := PackedFloat32Array()
var _hz := PackedFloat32Array()
var _ground := PackedFloat32Array()
var _pitch := PackedFloat32Array()
var _seed := PackedFloat32Array()
var _pace := PackedFloat32Array()
var _stride := PackedFloat32Array()
var _grown := PackedFloat32Array()
var _detour := PackedFloat32Array()
var _side_of := PackedFloat32Array()
# (on him: how far round him and how far up; thrown off: how fast it is going; wandering: where to, and how long it waits)
var _a := PackedFloat32Array()
var _b := PackedFloat32Array()
var _c := PackedFloat32Array()
var _wait := PackedFloat32Array()

# The ground round the nest, square by square (NAN: not looked at yet), and how many beetles stand in each.
var _nest := Vector3.ZERO
var _width := 0
var _corner := Vector2.ZERO
var _heights := PackedFloat32Array()
var _crowd := PackedByteArray()
var _crowded := PackedInt32Array()
var _crowd_next := PackedByteArray()
var _crowded_next := PackedInt32Array()
var _waters: Array[Pool] = []

# The fires near enough to matter this frame.
var _fire_x := PackedFloat32Array()
var _fire_y := PackedFloat32Array()
var _fire_z := PackedFloat32Array()
var _fire_r := PackedFloat32Array()

var _drawn: MultiMeshInstance3D
var _buffer := PackedFloat32Array()
var _ball: MeshInstance3D
var _ball_turn := 0.0
var _hole: MeshInstance3D
var _rustle: AudioStreamPlayer3D
var _query: PhysicsRayQueryParameters3D

static var _rustle_stream: AudioStreamWAV


func _ready() -> void:
	_nest = global_position
	front = Front.new()
	front.top_level = true
	add_child(front)
	front.global_position = _nest

	var reach := (roam if harmless else chase_distance) + 3.0
	_width = clampi(ceili(reach * 2.0 / CELL) + 1, 8, 420)
	_corner = Vector2(_nest.x, _nest.z) - Vector2.ONE * _width * CELL * 0.5
	_heights.resize(_width * _width)
	_heights.fill(NAN)
	_crowd.resize(_width * _width)
	_crowd_next.resize(_width * _width)
	_query = PhysicsRayQueryParameters3D.new()
	_query.collision_mask = 1
	_query.hit_from_inside = true

	for list: PackedFloat32Array in [_x, _y, _z, _hx, _hz, _ground, _pitch, _seed, _pace, _stride, _grown, _detour, _side_of, _a, _b, _c, _wait]:
		list.resize(count)
	_x.fill(_nest.x)
	_y.fill(_nest.y)
	_z.fill(_nest.z)
	_state.resize(count)
	for i in count:
		_seed[i] = randf()
		_pace[i] = randf_range(0.88, 1.12)
		_side_of[i] = 1.0 if randf() < 0.5 else -1.0
		_hx[i] = 0.0
		_hz[i] = 1.0

	_drawn = MultiMeshInstance3D.new()
	_drawn.top_level = true
	_drawn.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var many := MultiMesh.new()
	many.transform_format = MultiMesh.TRANSFORM_3D
	many.use_custom_data = true
	many.mesh = Scarab.mesh()
	many.instance_count = count
	_drawn.multimesh = many
	add_child(_drawn)
	_drawn.global_transform = Transform3D.IDENTITY
	_drawn.custom_aabb = AABB(_nest - Vector3(reach, 6.0, reach), Vector3(reach, 8.0, reach) * 2.0)
	_buffer.resize(count * 16)
	many.buffer = _buffer

	if hole and not harmless:
		_hole = MeshInstance3D.new()
		_hole.mesh = _hole_mesh()
		_hole.top_level = true
		_hole.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(_hole)
		_hole.visible = false
	if voice and not harmless:
		_rustle = AudioStreamPlayer3D.new()
		_rustle.stream = _rustling()
		_rustle.unit_size = 4.0
		_rustle.max_distance = 40.0
		_rustle.max_db = 0.0
		front.add_child(_rustle)

	if harmless:
		_mode = Mode.MILL
		for i in count:
			var at := Vector2.from_angle(randf() * TAU) * roam * sqrt(randf())
			_state[i] = OUT
			_x[i] = _nest.x + at.x
			_z[i] = _nest.z + at.y
			_ground[i] = NAN
			_grown[i] = 1.0
			_wait[i] = randf_range(0.0, 3.0)
			_a[i] = _x[i]
			_b[i] = _z[i]
		out = count
		if dung_ball:
			_ball = MeshInstance3D.new()
			var round_it := SphereMesh.new()
			round_it.radius = beetle_size * 0.5
			round_it.height = beetle_size
			round_it.radial_segments = 8
			round_it.rings = 4
			_ball.mesh = round_it
			_ball.material_override = Toon.surface(Color(0.3, 0.24, 0.16))
			_ball.top_level = true
			add_child(_ball)


## Lets them out after him.
func release() -> void:
	if harmless or _mode == Mode.HUNT:
		return
	if target == null:
		target = Nearby.player(get_tree())
	_mode = Mode.HUNT
	_fed = false
	_meter = 0.0
	_best_seen = INF
	_stuck_for = 0.0
	front.chasing = true
	front.add_to_group(&"pursuers")
	# (those already on their way home turn round)
	came_out.emit()


## Calls them home: they run back to the nest and go down it.
func recall() -> void:
	if _mode != Mode.HUNT:
		return
	_mode = Mode.HOME
	front.chasing = false
	for i in count:
		if _state[i] == ON_HIM:
			_let_go(i, Vector3.ZERO)


## Puts them all back in the nest at once, as they were to begin with.
func reset() -> void:
	if harmless:
		return
	_mode = Mode.DORMANT
	_rest = rest_time
	_fed = false
	_meter = 0.0
	front.chasing = false
	if front.is_in_group(&"pursuers"):
		front.remove_from_group(&"pursuers")
	front.global_position = _nest
	_state.fill(HIDDEN)
	_buffer.fill(0.0)
	_drawn.multimesh.buffer = _buffer
	out = 0
	on_him = 0
	held_off = 0


func _set_target(value: Player) -> void:
	if target and is_instance_valid(target) and target.respawned.is_connected(reset):
		target.respawned.disconnect(reset)
	target = value
	if target and not harmless:
		target.respawned.connect(reset)


func _physics_process(delta: float) -> void:
	_time += delta
	_rest = maxf(_rest - delta, 0.0)
	if (_mode == Mode.DORMANT or harmless) and global_position.distance_squared_to(_nest) > 0.0025:
		_move_nest()
	if target == null or not is_instance_valid(target):
		target = Nearby.player(get_tree())
	var him := Vector3(INF, INF, INF)
	var limp := false
	var shaking := false
	if target:
		him = target.global_position
		limp = target.is_limp
		if limp:
			him = target.visual_position
		var going := target.velocity
		shaking = not limp and (not target.is_on_floor() or Vector2(going.x, going.z).length() > 3.4)

	match _mode:
		Mode.DORMANT:
			if alert_distance > 0.0 and _rest <= 0.0 and target and not limp and him.distance_to(_nest) < alert_distance:
				release()
			if _mode == Mode.DORMANT:
				return
		Mode.HUNT:
			if target == null or (Vector2(him.x - _nest.x, him.z - _nest.z).length() > chase_distance and on_him == 0):
				_rest = rest_time
				recall()
		Mode.HOME:
			if out == 0:
				_mode = Mode.DORMANT
				if front.is_in_group(&"pursuers"):
					front.remove_from_group(&"pursuers")
				went_home.emit()
				return
	if _waters.is_empty() or Engine.get_physics_frames() % 120 == 0:
		_waters.clear()
		for water: Node in get_tree().get_nodes_in_group(&"water"):
			if water is Pool:
				_waters.append(water)
	if _hole and not _hole.visible:
		_hole.visible = true
		var under := _probe(_nest.x, _nest.z, _nest.y)
		_hole.global_position = Vector3(_nest.x, (under if under < BLOCKED else _nest.y) + 0.012, _nest.z)
	_gather_fires()

	# Out of the nest, so many a second.
	if _mode == Mode.HUNT and out < count:
		_pour += pour_rate * delta
		while _pour >= 1.0 and out < count:
			_pour -= 1.0
			for tries in count:
				_next_out = (_next_out + 1) % count
				if _state[_next_out] == HIDDEN:
					break
			_come_out(_next_out)

	# (they are counted into one set of squares while they read the last frame's count from the other)
	var spare := _crowd
	_crowd = _crowd_next
	_crowd_next = spare
	var spare_list := _crowded
	_crowded = _crowded_next
	_crowded_next = spare_list
	for index in _crowded_next:
		_crowd_next[index] = 0
	_crowded_next.clear()
	_rays = RAYS
	_refresh = (_refresh + 1) % count

	var hunting := _mode == Mode.HUNT and target != null
	var homing := _mode == Mode.HOME
	var milling := _mode == Mode.MILL
	var fires := _fire_x.size()
	var width := _width
	var inverse := 1.0 / CELL
	var corner_x := _corner.x
	var corner_z := _corner.y
	var size := beetle_size
	var best := INF
	var best_at := _nest
	var latched := 0
	var lit_count := 0
	var active := 0
	# How many strides a second their legs can be seen to take.
	var stride_rate := minf(speed / (size * 2.2), 9.0)
	var in_light := false
	if fears_fire and target:
		for f in fires:
			var away := Vector2(him.x - _fire_x[f], him.z - _fire_z[f]).length()
			if away < _fire_r[f] and absf(him.y + 0.8 - _fire_y[f]) < 2.5:
				in_light = true

	for i in count:
		var state := _state[i]
		if state == HIDDEN:
			continue
		active += 1
		var x := _x[i]
		var y := _y[i]
		var z := _z[i]
		var seed := _seed[i]
		var at := i * 16
		var big := size * (0.8 + 0.45 * seed)

		if state == ON_HIM:
			# Up his legs and round him; over him, once he is down.
			latched += 1
			var up := _b[i]
			var top := (0.06 + seed * 0.26) if limp else (0.35 + seed * 1.05)
			up = minf(up + delta * 0.9, top) if up < top else maxf(up - delta * 1.5, top)
			_b[i] = up
			var round_him := _a[i] + delta * (seed - 0.5) * 5.0
			_a[i] = round_him
			var wide := (0.12 + 2.2 * absf(_pace[i] - 1.0) + 0.3 * seed) if limp else (0.11 + 0.07 * sin(up * 4.0 + seed * 9.0))
			if not limp:
				_wait[i] -= delta * (1.0 if shaking else 0.0)
			if (in_light or _wait[i] <= 0.0) and not (limp and not in_light):
				_let_go(i, target.velocity)
				continue
			var cos_a := cos(round_him)
			var sin_a := sin(round_him)
			_stride[i] += delta * 5.0
			# (head up, its back to the outside)
			_buffer[at] = -sin_a * big
			_buffer[at + 1] = cos_a * big
			_buffer[at + 2] = 0.0
			_buffer[at + 3] = him.x + cos_a * wide
			_buffer[at + 4] = 0.0
			_buffer[at + 5] = 0.0
			_buffer[at + 6] = big
			_buffer[at + 7] = him.y + up
			_buffer[at + 8] = cos_a * big
			_buffer[at + 9] = sin_a * big
			_buffer[at + 10] = 0.0
			_buffer[at + 11] = him.z + sin_a * wide
			_buffer[at + 12] = _stride[i]
			_x[i] = _buffer[at + 3]
			_y[i] = _buffer[at + 7]
			_z[i] = _buffer[at + 11]
			continue

		if state == FLUNG:
			# Thrown off: it falls, and lies a moment before it is on its feet.
			_c[i] -= 20.0 * delta
			x += _a[i] * delta
			y += _c[i] * delta
			z += _b[i] * delta
			var under := _height(x, z, y)
			if under >= BLOCKED:
				_state[i] = HIDDEN
				out -= 1
				for k in 12:
					_buffer[at + k] = 0.0
				continue
			if y <= under:
				y = under
				_state[i] = OUT
				_ground[i] = under
				_wait[i] = 0.35 + seed * 0.4
			_x[i] = x
			_y[i] = y
			_z[i] = z
			_pitch[i] += delta * 14.0
			_write(at, x, y + big * 0.3, z, _hx[i], _hz[i], _pitch[i], big, _stride[i])
			continue

		# On the ground. Where it wants to go:
		var ground := _ground[i]
		if ground != ground:
			ground = _height(x, z, y)
			if ground >= BLOCKED:
				ground = y
			y = ground
		var want_x := 0.0
		var want_z := 0.0
		var quick := 1.0
		var still := false
		# (at the nest and at his feet they do not stand on ceremony)
		var apart_kept := true
		if _wait[i] > 0.0 and not milling:
			# (dazed)
			_wait[i] -= delta
			still = true
		elif hunting:
			want_x = him.x + (seed - 0.5) * 0.3 - x
			want_z = him.z + (_pace[i] - 0.98) * 0.7 - z
			var off := want_x * want_x + want_z * want_z
			var apart := off + (him.y - y) * (him.y - y)
			if apart < best:
				best = apart
				best_at = Vector3(x, y, z)
			apart_kept = off > 0.5
			# (those behind hurry and those in front do not run away from the rest: so they come as a carpet, not a string)
			quick = clampf(1.0 + (sqrt(off) - _gap - 0.8) * 0.3, 0.92, 1.35)
			if limp and off < 0.3:
				quick = 0.4
		elif homing:
			want_x = _nest.x - x
			want_z = _nest.z - z
			var off := want_x * want_x + want_z * want_z
			apart_kept = off > 1.5
			if off < 1.0:
				quick = 0.45
			_grown[i] = minf(_grown[i], off * 9.0 + 0.2)
			if off < 0.09:
				_state[i] = HIDDEN
				out -= 1
				for k in 12:
					_buffer[at + k] = 0.0
				continue
		else:
			# Wandering: to somewhere near, a wait there, and on; and away from his feet.
			var from_x := x - him.x
			var from_z := z - him.z
			var near := from_x * from_x + from_z * from_z
			if near < 1.0 and absf(him.y - y) < 1.0:
				want_x = from_x
				want_z = from_z
				quick = 0.9
				_wait[i] = 0.0
				_a[i] = x + from_x * 1.5
				_b[i] = z + from_z * 1.5
			else:
				quick = 0.14 if not (_ball and i == 0) else 0.06
				want_x = _a[i] - x
				want_z = _b[i] - z
				_c[i] -= delta
				if want_x * want_x + want_z * want_z < 0.02 or _c[i] < 0.0:
					_wait[i] -= delta
					still = true
					if _wait[i] <= 0.0:
						# (and if it cannot get there in a while, it thinks of somewhere else)
						_c[i] = 9.0
						var to := Vector2.from_angle(randf() * TAU) * roam * sqrt(randf())
						_a[i] = _nest.x + to.x
						_b[i] = _nest.z + to.y
						_wait[i] = randf_range(0.5, 4.0) if not (_ball and i == 0) else 0.3
						_detour[i] = 0.0
		var far := sqrt(want_x * want_x + want_z * want_z) + 0.0001
		want_x /= far
		want_z /= far

		# Not on top of one another: away from the fuller squares.
		var cell_x := int((x - corner_x) * inverse)
		var cell_z := int((z - corner_z) * inverse)
		if cell_x > 0 and cell_z > 0 and cell_x < width - 1 and cell_z < width - 1:
			var index := cell_z * width + cell_x
			var here := _crowd[index]
			if here >= CROWD and apart_kept:
				var push := 0.22 * (here - CROWD + 1)
				want_x += (_crowd[index - 1] - _crowd[index + 1]) * 0.2 + cos(seed * 40.0 + i) * push
				want_z += (_crowd[index - width] - _crowd[index + width]) * 0.2 + sin(seed * 40.0 + i) * push
			var counted := _crowd_next[index]
			if counted < 250:
				_crowd_next[index] = counted + 1
				if counted == 0:
					_crowded_next.append(index)

		# Fire: out of its light, and round the edge of it.
		var lit := false
		# (in the light itself it does not turn away by degrees: it is off)
		var startled := false
		for f in fires:
			var from_y := y - _fire_y[f]
			if from_y > 1.2 or from_y < -3.5:
				continue
			var out_x := x - _fire_x[f]
			var out_z := z - _fire_z[f]
			var reach := _fire_r[f] * (0.9 + 0.25 * seed)
			var edge := reach + 0.8
			var off := out_x * out_x + out_z * out_z
			if off > edge * edge:
				continue
			off = sqrt(off) + 0.0001
			out_x /= off
			out_z /= off
			lit = true
			still = false
			var side := _side_of[i]
			if off < reach:
				want_x = out_x + -out_z * side * 0.35
				want_z = out_z + out_x * side * 0.35
				quick = 1.6
				startled = true
			else:
				var inward := -(want_x * out_x + want_z * out_z)
				if inward > 0.0:
					want_x += out_x * inward
					want_z += out_z * inward
					var across := want_x * -out_z + want_z * out_x
					if absf(across) > 0.55:
						side = signf(across)
					want_x += -out_z * side * (0.25 + inward * 0.6)
					want_z += out_x * side * (0.25 + inward * 0.6)
					quick = 0.75
		if lit:
			lit_count += 1

		# A weave in its way of going, so that they scurry.
		var weave := sin(_time * (5.0 + seed * 6.0) + seed * 50.0) * (0.35 if apart_kept else 0.0)
		var wish_x := want_x - want_z * weave
		var wish_z := want_z + want_x * weave
		var head_x := _hx[i]
		var head_z := _hz[i]
		if _detour[i] > 0.0:
			# (going round whatever was in the way: it keeps on as it is for a moment)
			_detour[i] -= delta
			wish_x = head_x
			wish_z = head_z
		var turn := 1.0 if startled else minf(delta * 11.0, 1.0)
		head_x += (wish_x - head_x) * turn
		head_z += (wish_z - head_z) * turn
		var length := sqrt(head_x * head_x + head_z * head_z)
		if length > 0.001:
			head_x /= length
			head_z /= length
		else:
			head_x = wish_x
			head_z = wish_z
		_hx[i] = head_x
		_hz[i] = head_z

		var pace := 0.0 if still else speed * _pace[i] * quick
		var tip := 0.0
		if pace > 0.0:
			var step := pace * delta
			var next_x := x + head_x * (step + 0.03)
			var next_z := z + head_z * (step + 0.03)
			var ahead := _height(next_x, next_z, ground)
			if i == _refresh:
				_forget(next_x, next_z)
			if ahead >= BLOCKED or ahead - ground > climb or ground - ahead > drop:
				# A wall, or water, or a drop: along it, one way or the other.
				# It turns along it, the way it favours if that way is open, and holds to that for a moment.
				for attempt in 6:
					var turned: float = [PI * 0.5, 2.3, 3.0][attempt / 2] * (_side_of[i] if attempt % 2 == 0 else -_side_of[i])
					var try_x := head_x * cos(turned) - head_z * sin(turned)
					var try_z := head_x * sin(turned) + head_z * cos(turned)
					var there := _height(x + try_x * 0.22, z + try_z * 0.22, ground)
					if there < BLOCKED and there - ground <= climb and ground - there <= drop:
						_hx[i] = try_x
						_hz[i] = try_z
						_detour[i] = 0.25 + seed * 0.45
						if attempt % 2 == 1:
							_side_of[i] = -_side_of[i]
						break
			elif ahead > y + 0.13:
				# Up the face of it.
				y = minf(y + step * 0.8, ahead)
				tip = 1.35
			else:
				x += head_x * step
				z += head_z * step
				ground = ahead
				if y > ground + 0.13:
					# (and down the other side)
					y = maxf(y - step * 1.2, ground)
					tip = -1.2
				else:
					# (a slope: it keeps to the lie of the ground)
					tip = clampf((ground - y) * 8.0, -0.7, 0.7)
					y = move_toward(y, ground, step)
			_stride[i] += stride_rate * _pace[i] * quick * delta
		elif y > ground:
			y = maxf(y - delta * 3.0, ground)
		_x[i] = x
		_y[i] = y
		_z[i] = z
		_ground[i] = ground
		var pitch := _pitch[i]
		pitch += (tip - pitch) * minf(delta * 16.0, 1.0)
		_pitch[i] = pitch
		if _grown[i] < 1.0 and not homing:
			_grown[i] = minf(_grown[i] + delta * 5.0, 1.0)
		big *= _grown[i]

		# Onto him, if he is there to be got onto and no fire forbids it.
		if hunting and not lit and not in_light and not _fed or (hunting and limp):
			var to_x := him.x - x
			var to_z := him.z - z
			if to_x * to_x + to_z * to_z < (0.4 if limp else 0.09) and absf(him.y - y) < 0.35:
				_state[i] = ON_HIM
				_a[i] = atan2(-to_z, -to_x) + (seed - 0.5) * 4.0
				_b[i] = 0.02
				_wait[i] = 0.25 + seed * 0.5
				latched += 1
				continue

		if _ball and i == 0:
			# It walks backwards, head down, its hind feet on the ball, and the ball rolls ahead of it.
			var ball_at := Vector3(x, y + size * 0.5, z)
			_ball_turn += pace * delta / (size * 0.5)
			_ball.global_transform = Transform3D(Basis(Vector3(head_z, 0.0, -head_x), _ball_turn), ball_at)
			_write(at, x - head_x * size * 0.95, y + size * 0.12, z - head_z * size * 0.95, -head_x, -head_z, -0.75, big, _stride[i])
		else:
			_write(at, x, y, z, head_x, head_z, pitch, big, _stride[i])

	_drawn.multimesh.buffer = _buffer
	out = active
	on_him = latched
	held_off = lit_count
	if harmless:
		return

	# The front of them: what he looks at and the cat runs from.
	if best < INF:
		front.global_position = front.global_position.lerp(best_at, minf(delta * 8.0, 1.0))
	if _rustle:
		var loud := clampf(active / 40.0, 0.0, 1.0)
		if loud > 0.0 and not _rustle.playing:
			_rustle.play()
		elif loud <= 0.0 and _rustle.playing:
			_rustle.stop()
		_rustle.volume_db = linear_to_db(maxf(loud, 0.01)) - 9.0

	if hunting:
		# Enough of them on him for long enough, and he is down.
		var needed := mini(catch_count, maxi(count / 3, 1))
		if latched >= needed and not limp and not _fed:
			_meter += delta
			if _meter >= catch_time:
				_fed = true
				caught.emit()
		else:
			_meter = maxf(_meter - delta * 0.5, 0.0)
		# Getting no nearer, with nothing to show for it: they give up. (A fire that holds them off does not tire them.)
		var gap := sqrt(best)
		_gap = gap if best < INF else 0.0
		if latched > 0 or lit_count > 0 or limp or out < count:
			_best_seen = gap
			_stuck_for = 0.0
		elif gap < _best_seen - 0.3:
			_best_seen = gap
			_stuck_for = 0.0
		else:
			_best_seen = maxf(_best_seen, gap - 2.0)
			_stuck_for += delta
			if _stuck_for > give_up_after:
				_rest = rest_time
				recall()


# The nest has been moved (the level editor does this): everything it knew of the ground is forgotten.
func _move_nest() -> void:
	var by := global_position - _nest
	_nest = global_position
	_corner = Vector2(_nest.x, _nest.z) - Vector2.ONE * _width * CELL * 0.5
	_heights.fill(NAN)
	_crowd.fill(0)
	_crowd_next.fill(0)
	_crowded.clear()
	_crowded_next.clear()
	var reach := _width * CELL * 0.5
	_drawn.custom_aabb = AABB(_nest - Vector3(reach, 6.0, reach), Vector3(reach, 8.0, reach) * 2.0)
	front.global_position = _nest
	if _hole:
		_hole.visible = false
	if harmless:
		for i in count:
			_x[i] += by.x
			_y[i] = _nest.y
			_z[i] += by.z
			_a[i] += by.x
			_b[i] += by.z
			_ground[i] = NAN


# Writes one beetle into the MultiMesh: where it is, which way it heads, how it is tipped up, how big.
func _write(at: int, x: float, y: float, z: float, head_x: float, head_z: float, pitch: float, big: float, stride: float) -> void:
	var level := cos(pitch) * big
	var rise := sin(pitch) * big
	# (across; up, leaning back as its head comes up; forward)
	_buffer[at] = head_z * big
	_buffer[at + 1] = -head_x * rise
	_buffer[at + 2] = head_x * level
	_buffer[at + 3] = x
	_buffer[at + 4] = 0.0
	_buffer[at + 5] = level
	_buffer[at + 6] = rise
	_buffer[at + 7] = y
	_buffer[at + 8] = -head_x * big
	_buffer[at + 9] = -head_z * rise
	_buffer[at + 10] = head_z * level
	_buffer[at + 11] = z
	_buffer[at + 12] = stride


func _come_out(i: int) -> void:
	var way := randf() * TAU
	_state[i] = OUT
	_x[i] = _nest.x + cos(way) * 0.1
	_z[i] = _nest.z + sin(way) * 0.1
	_y[i] = _nest.y
	_hx[i] = cos(way)
	_hz[i] = sin(way)
	_ground[i] = NAN
	_grown[i] = 0.0
	_pitch[i] = 0.0
	_wait[i] = 0.0
	_detour[i] = 0.0
	out += 1


# Off him: flung the way he was going, and out.
func _let_go(i: int, going: Vector3) -> void:
	var way := _a[i]
	_state[i] = FLUNG
	_a[i] = going.x * 0.5 + cos(way) * 1.6
	_b[i] = going.z * 0.5 + sin(way) * 1.6
	_c[i] = 1.5 + going.y * 0.3


# How high the ground is at a place, for a beetle at the height `from`: remembered, or looked for now.
func _height(x: float, z: float, from: float) -> float:
	var cell_x := int((x - _corner.x) / CELL)
	var cell_z := int((z - _corner.y) / CELL)
	if cell_x < 0 or cell_z < 0 or cell_x >= _width or cell_z >= _width:
		return BLOCKED
	var index := cell_z * _width + cell_x
	var known := _heights[index]
	if known == known:
		return known
	if _rays <= 0:
		# (enough looking for one frame: it goes on as if the ground were level, and looks next time)
		return from
	_rays -= 1
	known = _probe(_corner.x + (cell_x + 0.5) * CELL, _corner.y + (cell_z + 0.5) * CELL, from)
	_heights[index] = known
	return known


# Forgets a square, so that it is looked at again: doors open, and blocks are pushed.
func _forget(x: float, z: float) -> void:
	var cell_x := int((x - _corner.x) / CELL)
	var cell_z := int((z - _corner.y) / CELL)
	if cell_x >= 0 and cell_z >= 0 and cell_x < _width and cell_z < _width:
		_heights[cell_z * _width + cell_x] = NAN


# Looks straight down for the ground.
func _probe(x: float, z: float, from: float) -> float:
	_query.from = Vector3(x, from + climb + 0.45, z)
	_query.to = Vector3(x, from - drop - 0.6, z)
	var found := get_world_3d().direct_space_state.intersect_ray(_query)
	if found.is_empty():
		return BLOCKED
	var high: float = found.position.y
	if high - from > climb:
		# (too high to go up: but it may be something to go under)
		_query.from = Vector3(x, from + 0.3, z)
		var under := get_world_3d().direct_space_state.intersect_ray(_query)
		if not under.is_empty() and under.normal != Vector3.ZERO:
			high = under.position.y
	for water in _waters:
		if is_instance_valid(water) and water.depth_at(Vector3(x, high + 0.01, z)) > 0.03:
			return BLOCKED
	return high


func _gather_fires() -> void:
	_fire_x.clear()
	_fire_y.clear()
	_fire_z.clear()
	_fire_r.clear()
	if not fears_fire or harmless:
		return
	var limit := chase_distance + 8.0
	for fire in Nearby.fires(get_tree()):
		if not is_instance_valid(fire) or not fire.is_inside_tree():
			continue
		var at := fire.global_position
		if absf(at.x - _nest.x) > limit or absf(at.z - _nest.z) > limit:
			continue
		_fire_x.append(at.x)
		_fire_y.append(at.y)
		_fire_z.append(at.z)
		_fire_r.append(Nearby.reach_of(fire, fire_reach))


# The hole: a ragged dark patch with cracks running out of it.
func _hole_mesh() -> ArrayMesh:
	var tool := SurfaceTool.new()
	tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	var rim: Array[Vector3] = []
	for k in 11:
		var turn := TAU * k / 11.0
		var far := 0.2 + 0.05 * sin(k * 2.7)
		rim.append(Vector3(cos(turn) * far, 0.0, sin(turn) * far))
	for k in 11:
		tool.add_vertex(Vector3.ZERO)
		tool.add_vertex(rim[k])
		tool.add_vertex(rim[(k + 1) % 11])
	var made := tool.commit()
	var dark := StandardMaterial3D.new()
	dark.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	dark.albedo_color = Color(0.02, 0.015, 0.01)
	dark.cull_mode = BaseMaterial3D.CULL_DISABLED
	made.surface_set_material(0, dark)
	return made


# The sound of them: a great many small dry ticks, made here from noise.
static func _rustling() -> AudioStreamWAV:
	if _rustle_stream:
		return _rustle_stream
	var rate := 22050
	var samples := PackedFloat32Array()
	samples.resize(rate * 2)
	var chance := RandomNumberGenerator.new()
	chance.seed = 7
	for tick in 520:
		var start := chance.randi_range(0, samples.size() - 1)
		var long := chance.randi_range(30, 110)
		var loud := chance.randf_range(0.15, 0.6)
		var last := 0.0
		for k in long:
			var noise := chance.randf_range(-1.0, 1.0)
			# (only the top of the noise: a tick, not a thump)
			var sharp := noise - last
			last = noise
			var where := (start + k) % samples.size()
			samples[where] += sharp * loud * (1.0 - float(k) / long) * 0.5
	var data := PackedByteArray()
	data.resize(samples.size() * 2)
	for k in samples.size():
		data.encode_s16(k * 2, int(clampf(samples[k], -1.0, 1.0) * 32000.0))
	_rustle_stream = AudioStreamWAV.new()
	_rustle_stream.format = AudioStreamWAV.FORMAT_16_BITS
	_rustle_stream.mix_rate = rate
	_rustle_stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
	_rustle_stream.loop_end = samples.size()
	_rustle_stream.data = data
	return _rustle_stream
