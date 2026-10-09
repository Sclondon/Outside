class_name JackalMummy
extends CharacterBody3D
## A mummified jackal: one of the dogs and jackals that were given to Anubis,
## dried, bound in linen and laid up in his catacombs, set to guard a tomb.
##
## It lies dormant, like the black jackal on a shrine (or stands as it was
## propped in a niche: `rest`), until it is woken (`wake()`) or until its
## target comes within `wake_within`. Then it gets up, stiffly and in jerks
## (`wake_time`), and comes after him at a dry, stilted trot with its head down
## and weaving. It does not catch him by reaching him. When it is within
## `lunge_distance` it sinks back onto its haunches with its jaw wide (he has
## `crouch_time` to get out of the way), and springs, straight, at where he
## was: `caught` is emitted only if the spring finds him. Then it stands a
## moment (`recover_time`) before it comes on.
##
## What it is NOT is a hound. It is slower than he runs (`trot_speed`) but it
## never tires, slows or loses interest; it does not bark, play, sit or sleep;
## it cannot jump onto anything much (`step_up`), nor far (`leap_distance`),
## and it will not go into water, being dry linen and unable to swim: out of
## its reach he is safe, and it prowls beneath him. Hitting it knocks it
## aside, and shooting it enough (`toughness`) knocks it down, for `down_time`.
## Then it gets up again. Nothing kills it.
##
## Several hunt together a little: they come at him from different sides
## (`_flank`), keep apart, and spring in turn, not all at once.
##
## Everything it needs (collider, model, voice) is made here, so
## `JackalMummy.new()` is a whole one. It is animated by JackalMummyRig.
##
## It is silent, unless `voice` is set. Then it has a dry rasp, as it wakes,
## before it springs and now and then as it comes: the recordings of hounds
## panting (audio/hounds/, credited there), which have breath in them and no
## bark, played at half their pitch. That is off until someone has listened to
## it and judged it good enough: it was made without being heard.

signal caught
## It has begun to get up.
signal woke

## How it waits: lying like a sphinx, or standing.
enum Rest { SPHINX, STANDING }
## What it wears over its wrappings: nothing; a broad collar; a gilded mask and the collar.
enum Finery { PLAIN, COLLAR, MASK }
enum State { DORMANT, RISING, HUNT, CROUCH, LUNGE, RECOVER, FELLED }

@export var rest := Rest.SPHINX
@export var finery := Finery.PLAIN
## It wakes of its own accord when its target is nearer than this (m). 0: only when it is woken.
@export var wake_within := 5.0
## Seconds between being disturbed and being on its feet.
@export var wake_time := 1.7
## How fast it prowls when it cannot get at him, and how fast it comes on.
@export var stalk_speed := 1.0
@export var trot_speed := 3.8
@export var acceleration := 14.0
@export var turn_rate := 5.0
@export var gravity := 24.0
## How near he must be for it to spring, how long it gathers itself first (s),
## how high the spring goes (m), and how long it stands after it (s).
@export var lunge_distance := 2.7
@export var crouch_time := 0.42
@export var lunge_height := 0.42
@export var recover_time := 0.9
## How near to him the spring must bring it to have him.
@export var catch_distance := 0.7
## The highest thing it can hop up onto, and the widest gap it will cross (m).
@export var step_up := 0.5
@export var leap_distance := 1.5
## How much gunfire (the sum of the `damage` of what hits it) knocks it down, and for how long (s).
@export var toughness := 45.0
@export var down_time := 6.0
@export var voice := false

var target: Player
## Whether it is after him (anything in the group `pursuers` says so with this).
var chasing := false
var state := State.DORMANT
## Use the demade, low-poly model. Set before it enters the tree.
var low_poly := false
## Heading of the model, radians around Y. Zero faces +Z.
var facing_yaw := 0.0
## Render-rate position; the rig follows this.
var visual_position := Vector3.ZERO
## Somewhere to go, and how fast, instead of thinking for itself (the test
## stage uses this). Vector3.INF: nowhere.
var bidden := Vector3.INF
var bidden_speed := 1.0

var _spawn := Transform3D.IDENTITY
var _prev_pos := Vector3.ZERO
var _curr_pos := Vector3.ZERO
var _rig: JackalMummyRig
var _voice: AudioStreamPlayer3D
var _timer := 0.0
var _harm := 0.0
var _flinch := 0.0
var _has_him := false
var _lunge_way := Vector3.ZERO
var _jump_cooldown := 0.0
var _detour := Vector3.ZERO
var _detour_time := 0.0
## Baffled: it is getting nowhere (he is up on something), and prowls.
var _prowl := 0.0
var _prowl_side := 1.0
var _progress_timer := 0.0
var _progress_from := Vector3.ZERO
var _progress_gap := 0.0
var _baffled := 0
var _rasp_timer := 4.0
var _find_timer := 0.0

## The recordings its rasp is made from, and which was played last; and when any of a pack last sprang (in physics frames).
static var _takes: Array[AudioStream] = []
static var _searched := false
static var _last_take := -1
static var _pack_sprang := -100000

const VOICE_LEVEL := -15.0
## How far below their own pitch the recordings are played.
const RASP_PITCH := Vector2(0.42, 0.58)


func _ready() -> void:
	add_to_group(&"jackal_mummies")
	add_to_group(&"pursuers")
	# It and the player pass through each other; only the world stops it.
	collision_layer = 4
	collision_mask = 1
	floor_snap_length = 0.25
	floor_max_angle = deg_to_rad(50.0)

	var shape := SphereShape3D.new()
	shape.radius = 0.24
	var collider := CollisionShape3D.new()
	collider.shape = shape
	collider.position.y = shape.radius
	add_child(collider)

	_load_voice()
	_voice = AudioStreamPlayer3D.new()
	_voice.unit_size = 5.0
	_voice.max_distance = 40.0
	_voice.volume_db = VOICE_LEVEL
	_voice.max_db = 0.0
	_voice.position.y = 0.5
	add_child(_voice)

	_rig = JackalMummyRig.new()
	_rig.low_poly = low_poly
	_rig.sphinx = rest == Rest.SPHINX
	_rig.rise_time = wake_time
	_rig.mask = finery == Finery.MASK
	_rig.collar = finery != Finery.PLAIN
	add_child(_rig)
	_rig.top_level = true

	facing_yaw = global_rotation.y
	_spawn = global_transform
	reset()


## Disturbs it: it gets up, and then it comes.
func wake() -> void:
	if state == State.DORMANT:
		state = State.RISING
		_rig.up = true
		_say()
		woke.emit()


func is_awake() -> bool:
	return state != State.DORMANT


## Back where it was put, dormant.
func reset() -> void:
	global_transform = _spawn
	velocity = Vector3.ZERO
	state = State.DORMANT
	chasing = false
	facing_yaw = _spawn.basis.get_euler().y
	_harm = 0.0
	_flinch = 0.0
	_prowl = 0.0
	_detour_time = 0.0
	_prev_pos = global_position
	_curr_pos = global_position
	visual_position = global_position
	_rig.up = false
	_rig.hunting = 0.0
	_rig.crouched = false
	_rig.aim = null
	_rig.global_position = visual_position
	_rig.rotation = Vector3(0.0, facing_yaw, 0.0)
	_rig.settle()


func _physics_process(delta: float) -> void:
	var grounded := is_on_floor()
	var want := Vector3.ZERO
	_jump_cooldown -= delta
	_detour_time -= delta
	_flinch -= delta
	_timer -= delta
	_find_timer -= delta
	if target == null and _find_timer <= 0.0:
		# (no one has said who it guards against: it is whoever the player is)
		_find_timer = 2.0
		var found := get_tree().root.find_children("*", "Player", true, false)
		if not found.is_empty():
			target = found[0]
	var to := target.global_position - global_position if target else Vector3.ZERO
	var flat := Vector3(to.x, 0.0, to.z)
	var hunting := target != null and not target.is_limp
	if bidden != Vector3.INF:
		# (led about by the test stage: up, and going where it is told)
		var there := bidden - global_position
		there.y = 0.0
		state = State.HUNT
		_rig.up = true
		want = there.normalized() * bidden_speed if there.length() > 0.2 and _rig.risen() >= 1.0 else Vector3.ZERO
	else:
		match state:
			State.DORMANT:
				if hunting and wake_within > 0.0 and to.length() < wake_within:
					wake()
			State.RISING:
				if _rig.risen() >= 1.0:
					state = State.HUNT
					_progress_timer = 0.0
					_progress_from = global_position
					_progress_gap = to.length()
			State.HUNT:
				if hunting and grounded and _flinch <= 0.0:
					want = _hunt(delta, to, flat)
			State.CROUCH:
				# It follows him round as it gathers itself, but not to the last.
				if _timer > 0.12 and hunting:
					_lunge_way = flat.normalized()
				if _timer <= 0.0 and grounded:
					_spring(flat.length() if hunting else lunge_distance)
			State.LUNGE:
				if hunting and not _has_him and flat.length() < catch_distance and absf(to.y) < 0.9:
					_has_him = true
					caught.emit()
				if grounded and _timer <= 0.0:
					state = State.RECOVER
					_timer = recover_time
			State.RECOVER:
				if _timer <= 0.0:
					state = State.HUNT
			State.FELLED:
				if _timer <= 0.0:
					state = State.RISING
					_rig.up = true
					_say()
	chasing = state in [State.HUNT, State.CROUCH, State.LUNGE, State.RECOVER] and hunting
	_rig.hunting = 1.0 if chasing or (bidden != Vector3.INF and bidden_speed > 2.0) else 0.0
	_rig.crouched = state == State.CROUCH
	_rig.aim = target if chasing else null

	if _flinch > 0.0:
		want = Vector3.ZERO
	# (thrown, it goes where it was aimed)
	if state != State.LUNGE:
		# (it comes down stiff-legged, and stops where it lands)
		var grip := 3.0 if state == State.RECOVER else 0.3 if _flinch > 0.0 else 1.0
		var current := Vector3(velocity.x, 0.0, velocity.z).move_toward(want, acceleration * grip * delta)
		velocity.x = current.x
		velocity.z = current.z
	if not grounded:
		velocity.y -= gravity * delta
	move_and_slide()
	_mutter(delta)
	if global_position.y < -15.0:
		reset()
	elif state != State.DORMANT and state != State.FELLED and _depth(global_position) > 0.45:
		# In over its back: it cannot swim, and that is the end of it until it is put back.
		_fall(100000.0)
	_prev_pos = _curr_pos
	_curr_pos = global_position


func _process(delta: float) -> void:
	visual_position = _prev_pos.lerp(_curr_pos, Engine.get_physics_interpolation_fraction())
	var heading := Vector3(velocity.x, 0.0, velocity.z)
	if state == State.CROUCH:
		heading = _lunge_way
	elif heading.length_squared() < 0.2 and chasing and state != State.LUNGE:
		# Held up: it still turns to face him.
		heading = target.global_position - global_position
		heading.y = 0.0
	if heading.length_squared() > 0.05 and _flinch <= 0.0 and state != State.DORMANT and state != State.FELLED and _rig.risen() > 0.6:
		facing_yaw = lerp_angle(facing_yaw, atan2(heading.x, heading.z), 1.0 - exp(-turn_rate * delta))
	_rig.global_position = visual_position
	_rig.rotation = Vector3(0.0, facing_yaw, 0.0)


## Hit with a fist, a boot or anything swung or thrown: it is knocked the way the blow went, and comes on again.
func struck(_by: Node3D, impulse: Vector3) -> void:
	_hurt(impulse / 10.0, 0.4, false)


## Hit by a gun: it staggers. Past `toughness` in all it goes down, and lies for `down_time`.
func shot(_by: Node3D, _at: Vector3, direction: Vector3, damage: float) -> void:
	_harm += damage
	_hurt(direction.normalized() * 3.0, 0.6, true)
	if _harm >= toughness and state != State.DORMANT and state != State.FELLED:
		_fall(down_time)


func _hurt(push: Vector3, time: float, hard: bool) -> void:
	if state == State.DORMANT:
		wake()
	push.y = 0.0
	push = push.limit_length(5.0)
	velocity.x += push.x
	velocity.z += push.z
	_flinch = time
	if state == State.CROUCH:
		# (it has to gather itself all over again)
		state = State.HUNT
	_rig.flinch(Basis(Vector3.UP, -facing_yaw) * push, hard)


## Down, in a heap, for `time`.
func _fall(time: float) -> void:
	state = State.FELLED
	chasing = false
	_timer = time
	_harm = 0.0
	_rig.up = false


## After him. Returns where to go, and how fast.
func _hunt(delta: float, to: Vector3, flat: Vector3) -> Vector3:
	var distance := flat.length()
	var towards := flat.normalized() if distance > 0.01 else Vector3(sin(facing_yaw), 0.0, cos(facing_yaw))
	if distance < 0.45 and absf(to.y) < 0.7:
		# He has walked into it.
		caught.emit()
		state = State.RECOVER
		_timer = recover_time
		_rig.snap()
		return Vector3.ZERO
	# Near enough, and facing him, and no other of the pack this moment in the air: it gathers itself.
	var facing := Vector3(sin(facing_yaw), 0.0, cos(facing_yaw)).dot(towards)
	if distance < lunge_distance and absf(to.y) < 0.8 and facing > 0.8 and Engine.get_physics_frames() - _pack_sprang > 40 and _clear_to(towards, distance):
		state = State.CROUCH
		_timer = crouch_time
		_lunge_way = towards
		_pack_sprang = Engine.get_physics_frames()
		_say()
		return Vector3.ZERO

	# Is it getting anywhere? Neither covering ground nor closing on him: he is up on something.
	_progress_timer += delta
	if _progress_timer > 1.2:
		var gone := global_position - _progress_from
		gone.y = 0.0
		# (twice running: once may only be a corner it is going round)
		_baffled = _baffled + 1 if _progress_gap - to.length() < 0.3 and distance < 6.0 and (gone.length() < 1.0 or absf(to.y) > 0.8) else 0
		if _baffled >= 2 and _prowl <= 0.0:
			_baffled = 0
			_prowl = randf_range(3.0, 5.0)
			_prowl_side = 1.0 if randf() < 0.5 else -1.0
		_progress_timer = 0.0
		_progress_from = global_position
		_progress_gap = to.length()
	if _prowl > 0.0:
		# It goes round under him, slowly, looking up; and then tries again.
		_prowl -= delta
		if absf(to.y) < 0.6 and distance > lunge_distance:
			_prowl = 0.0
		var round := Vector3(towards.z, 0.0, -towards.x) * _prowl_side
		var wish := (round + towards * clampf(distance - 2.2, -1.0, 1.0)).normalized()
		return _negotiate(wish, false) * stalk_speed

	var wish := (_flank(towards, distance) + _apart() * 1.6).normalized()
	return _negotiate(wish, true) * trot_speed


## Which way to go to come at him from its own side. Each of a pack takes a
## bearing on him of its own, spread out round the side the pack is on, makes
## for a place that far round him, and turns in when it is there or he is near.
func _flank(towards: Vector3, distance: float) -> Vector3:
	var pack: Array[JackalMummy] = []
	for other: JackalMummy in get_tree().get_nodes_in_group(&"jackal_mummies"):
		if other.chasing and other.target == target and other.global_position.distance_to(global_position) < 25.0:
			pack.append(other)
	if pack.size() < 2 or distance < lunge_distance * 1.25:
		return towards
	pack.sort_custom(func(a: JackalMummy, b: JackalMummy) -> bool: return a.get_instance_id() < b.get_instance_id())
	var middle := Vector3.ZERO
	for other in pack:
		middle += other.global_position
	var from := middle / pack.size() - target.global_position
	from.y = 0.0
	if from.length() < 0.5:
		return towards
	# (two are a little over a quarter of the way round him from each other; more share out a wider arc)
	var spread := minf(1.9, TAU * 0.8 / pack.size())
	var bearing := atan2(from.x, from.z) + (pack.find(self) - (pack.size() - 1) * 0.5) * spread
	var ring := clampf(distance * 0.7, lunge_distance * 0.9, 6.0)
	var place := target.global_position + Vector3(sin(bearing), 0.0, cos(bearing)) * ring - global_position
	place.y = 0.0
	return place.normalized() if place.length() > 1.0 else towards


## Keeps the pack from running as one.
func _apart() -> Vector3:
	var push := Vector3.ZERO
	for other: Node3D in get_tree().get_nodes_in_group(&"jackal_mummies"):
		if other == self:
			continue
		var away := global_position - other.global_position
		away.y = 0.0
		var distance := away.length()
		if distance < 1.2 and distance > 0.001:
			push += away / distance * (1.2 - distance)
	return push


## Whether there is ground all the way to him, and nothing in between: it does not spring into a wall, a pit or a pool.
func _clear_to(way: Vector3, distance: float) -> bool:
	if test_move(global_transform.translated(Vector3.UP * 0.3), way * maxf(distance - 0.4, 0.1)):
		return false
	return _ground_under(global_position + way * (distance + 0.3)) and _ground_under(global_position + way * distance * 0.5)


## The spring: thrown at where he is, so as to come down on him.
func _spring(distance: float) -> void:
	state = State.LUNGE
	_has_him = false
	var rise := sqrt(2.0 * gravity * lunge_height)
	var aloft := 2.0 * rise / gravity
	var speed := clampf((distance + 0.1) / aloft, 3.5, 9.0)
	velocity = _lunge_way * speed + Vector3.UP * rise
	_timer = 0.2
	_pack_sprang = Engine.get_physics_frames()
	_rig.snap()


## Deals with whatever lies between here and there. Returns the direction to go, or nothing if it is held.
func _negotiate(wish: Vector3, eager: bool) -> Vector3:
	var here := global_position
	if not _ground_under(here + wish * 0.7):
		# A gap: over it, if it is narrow. Otherwise it stands at the edge.
		if eager and _ground_under(here + wish * leap_distance):
			_jump(0.3)
			return wish
		return Vector3.ZERO
	var hit := KinematicCollision3D.new()
	if not test_move(global_transform, wish * 0.3, hit) or hit.get_normal().y > 0.6:
		if _detour_time > 0.0:
			return (wish * 0.5 + _detour).normalized()
		return wish
	# Something in the way. A kerb gets a stiff hop; anything taller it goes round,
	# keeping to one side of it for a moment so that it does not dither.
	if step_up > 0.0 and not test_move(global_transform.translated(Vector3.UP * (step_up + 0.05)), wish * 0.4):
		_jump(step_up + 0.1)
		return wish
	if _detour_time <= 0.0:
		_detour = Vector3(-wish.z, 0.0, wish.x)
		var obstacle := hit.get_collider() as Node3D
		if obstacle and _detour.dot(global_position - obstacle.global_position) < 0.0:
			_detour = -_detour
	_detour_time = 0.9
	return (wish * 0.5 + _detour).normalized()


func _jump(height: float) -> void:
	if _jump_cooldown > 0.0 or not is_on_floor():
		return
	_jump_cooldown = 0.4
	velocity.y = sqrt(2.0 * gravity * height)


## Whether there is ground to stand on at `point` (within `down` of its own height), and it is not under water.
func _ground_under(point: Vector3, down := 1.2) -> bool:
	var query := PhysicsRayQueryParameters3D.create(point + Vector3.UP * 0.6, point + Vector3.DOWN * down, 1)
	var found := get_world_3d().direct_space_state.intersect_ray(query)
	if found.is_empty():
		return false
	return _depth(found.position) < 0.25


## How far under water a place is (m; less than 0: it is dry).
func _depth(point: Vector3) -> float:
	var deepest := -1000.0
	for pool: Node in get_tree().get_nodes_in_group(&"water"):
		if pool is Pool:
			deepest = maxf(deepest, (pool as Pool).depth_at(point))
	return deepest


## Now and then as it comes, the rasp.
func _mutter(delta: float) -> void:
	_rasp_timer -= delta
	if _rasp_timer > 0.0:
		return
	_rasp_timer = randf_range(3.5, 8.0)
	if chasing and state == State.HUNT:
		_say()


## The rasp: one of the recordings, not the one that was played last, far below its own pitch.
func _say() -> void:
	if not voice or _takes.is_empty() or _voice == null or _voice.playing:
		return
	var pick := randi() % _takes.size()
	if _takes.size() > 1 and pick == _last_take:
		pick = (pick + 1 + randi() % (_takes.size() - 1)) % _takes.size()
	_last_take = pick
	_voice.stream = _takes[pick]
	_voice.pitch_scale = randf_range(RASP_PITCH.x, RASP_PITCH.y)
	_voice.volume_db = VOICE_LEVEL + randf_range(-2.0, 1.0)
	_voice.play()


## Finds the recordings its rasp is made from: the hounds' panting, which has no voice in it.
static func _load_voice() -> void:
	if _searched:
		return
	_searched = true
	for number in range(1, 20):
		var path := "res://audio/hounds/pant_%d.wav" % number
		if not ResourceLoader.exists(path):
			break
		var stream := load(path) as AudioStream
		if stream:
			_takes.append(stream)
