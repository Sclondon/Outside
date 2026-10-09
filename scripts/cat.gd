class_name Cat
extends CharacterBody3D
## A cat. `Cat.new()` is a whole one: collider, model, voice.
##
## It keeps to itself. It wanders about where it was put, sits and watches the
## boy, follows him at a distance if it is curious, and comes and rubs itself
## round his legs if it is tame and he stands still or crouches near it. Now
## and then it stalks something and springs on it. When it has been up long
## enough it finds a place in the sun and sleeps, and wakes with a yawn and two
## stretches. Anything in the group `pursuers` (the hounds, the mummy) sends it
## up onto the nearest thing too high for them, where it sits and glares until
## they have gone, and then comes down again.
##
## How it moves is all in CatRig; this says what it is doing (`posture`, `act`,
## `mood`, `creep`, `rub`, `gaze`).
##
## Its voice is recordings of cats (audio/cat/, and CREDITS.md there). With
## those missing, or `voice` off, it is silent.

## It opened its mouth to say something.
signal voiced

enum Posture { UP, SIT, LOAF, SIDE, CURL }
## Things it does standing where it is: the wiggle before it springs at
## something, gathering itself to jump up, reaching down off an edge, the two
## stretches, washing, a yawn.
enum Act { NONE, WIGGLE, GATHER, REACH, STRETCH_BOW, STRETCH_ARCH, GROOM, YAWN }
enum Mood { CALM, FRIENDLY, ANNOYED, FRIGHTENED, HUNTING }
enum Coat { BRONZE, SILVER, BLACK, RUDDY, TABBY, GINGER }
enum State { WANDER, WATCH, FOLLOW, RUB, NAP, WAKE, STALK, FLEE, PERCHED, RETURN, AWAY }

const COAT_NAMES: Array[StringName] = [&"bronze", &"silver", &"black", &"ruddy", &"tabby", &"ginger"]
const KINDS: Array[String] = ["meow", "purr", "hiss", "trill", "growl"]
const VOICE_LEVEL := -14.0

## Its coat. The tabby and the ginger are the heavier house cat; the others the lean temple cat.
@export var coat := Coat.BRONZE
## How willing it is to come to the boy, 0..1: under a quarter it keeps out of
## his reach; over a half it comes to rub against him when he is still.
@export_range(0.0, 1.0) var tame := 0.6
## How much it wants to know what he is doing, 0..1: over a half, it follows him about at a distance.
@export_range(0.0, 1.0) var curiosity := 0.6
@export var walk_speed := 0.7
@export var trot_speed := 1.7
@export var run_speed := 6.2
## The highest thing it will jump onto (m).
@export var jump_height := 1.6
## How far it strays from where it was put.
@export var roam := 6.0
## How long it stays awake between sleeps, and how long it sleeps (s).
@export var nap_after := 50.0
@export var nap_length := 30.0
## How near a pursuer comes before it bolts (m).
@export var fear_distance := 9.0
@export var gravity := 24.0
## Whether it makes any sound.
@export var voice := true

## The boy. Found by itself if it is not given.
var target: Player
## Use the demade, low-poly model. Set before the cat enters the tree.
var low_poly := false
## Heading of the model, radians around Y. Zero faces +Z.
var facing_yaw := 0.0
## Render-rate position; the rig follows this.
var visual_position := Vector3.ZERO

## What the rig reads.
var posture := Posture.UP
var act := Act.NONE
var mood := Mood.CALM
## Stalking: belly to the ground.
var creep := false
## Rubbing against something: which side it is on (+ its left), and how hard, -1..1.
var rub := 0.0
## What it is watching: a thing, or else a place (Vector3.INF: nothing).
var gaze: Node3D
var gaze_at := Vector3.INF
## Where a sound it has just heard came from (Vector3.INF: none): its ears turn to it.
var heard := Vector3.INF
var asleep := false
## At its ease, 0..1: its eyes half shut, the slow blink.
var content := 0.0
## On the ground. Not while it is in the air in a spring.
var grounded := true
## Springing at something, forepaws out.
var pouncing := false
var voice_rate := 1.0
var voice_length := 0.5
var voice_envelope := PackedFloat32Array()

## Thinks for itself. The test stage turns this off and sets the things above itself.
var manual := false
## Somewhere to go, and how fast, instead of thinking for itself. Vector3.INF: nowhere.
var bidden := Vector3.INF
var bidden_speed := 1.0
var state := State.WANDER

var _rig: CatRig
var _spawn := Transform3D.IDENTITY
var _prev_pos := Vector3.ZERO
var _curr_pos := Vector3.ZERO
var _face := Vector3.ZERO
var _voice: AudioStreamPlayer3D
var _purr: AudioStreamPlayer3D
var _find_timer := 0.0
var _state_time := 0.0
var _step := 0
var _timer := 0.0
var _goal := Vector3.INF
var _awake := 0.0
var _act_left := 0.0
var _still := 0.0
var _threat: Node3D
var _calm := 0.0
var _perch := Vector3.INF
var _takeoff := Vector3.INF
var _blocked := false
var _heard_left := 0.0
var _say_timer := 4.0
var _rub_axis := Vector3.FORWARD
var _rub_side := 1.0
var _prey: Node3D
var _sun: DirectionalLight3D
var _land_grace := 0.0
## A spring: from, to, how long it takes, how far into it, and how fast it leaves the ground.
var _leaping := false
var _leap_from := Vector3.ZERO
var _leap_to := Vector3.ZERO
var _leap_length := 0.5
var _leap_time := 0.0
var _leap_up := 0.0

static var _bank := {}
static var _envelopes := {}
static var _last_said := {}
static var _looked := false


func _ready() -> void:
	add_to_group(&"cats")
	# Cats, hounds and the boy pass through each other; only the world stops them.
	collision_layer = 4
	collision_mask = 1
	floor_snap_length = 0.15
	floor_max_angle = deg_to_rad(50.0)
	var shape := SphereShape3D.new()
	shape.radius = 0.11
	var collider := CollisionShape3D.new()
	collider.shape = shape
	collider.position.y = shape.radius
	add_child(collider)

	_load_voices()
	_voice = AudioStreamPlayer3D.new()
	_voice.unit_size = 4.0
	_voice.max_distance = 30.0
	_voice.volume_db = VOICE_LEVEL
	_voice.max_db = 0.0
	_voice.position.y = 0.3
	add_child(_voice)
	_purr = AudioStreamPlayer3D.new()
	_purr.unit_size = 1.5
	_purr.max_distance = 8.0
	_purr.volume_db = -16.0
	_purr.max_db = 0.0
	_purr.position.y = 0.2
	add_child(_purr)

	_rig = CatRig.new()
	_rig.build = 1 if coat == Coat.TABBY or coat == Coat.GINGER else 0
	_rig.coat = COAT_NAMES[coat]
	_rig.low_poly = low_poly
	add_child(_rig)
	_rig.top_level = true

	_spawn = global_transform
	facing_yaw = global_rotation.y
	_prev_pos = global_position
	_curr_pos = global_position
	visual_position = global_position
	_awake = randf_range(0.0, nap_after * 0.5)
	_set_state(State.WANDER)


func _physics_process(delta: float) -> void:
	_land_grace -= delta
	if _leaping:
		_fly(delta)
		_prev_pos = _curr_pos
		_curr_pos = global_position
		return
	grounded = is_on_floor() or _land_grace > 0.0
	_face = Vector3.ZERO
	_blocked = false
	_heard_left -= delta
	if _heard_left <= 0.0:
		heard = Vector3.INF
	var want := Vector3.ZERO
	if bidden != Vector3.INF:
		var to := bidden - global_position
		to.y = 0.0
		want = to.normalized() * bidden_speed if to.length() > 0.15 else Vector3.ZERO
	elif not manual:
		want = _think(delta)
	if act != Act.NONE or posture != Posture.UP:
		want = Vector3.ZERO
	# (it is quick off the mark, and stops dead)
	var quick := 30.0 if want.length() > trot_speed * 1.5 or want == Vector3.ZERO else 9.0
	var current := Vector3(velocity.x, 0.0, velocity.z).move_toward(want, quick * delta)
	velocity.x = current.x
	velocity.z = current.z
	if not is_on_floor():
		velocity.y -= gravity * delta
	move_and_slide()
	if global_position.y < -15.0:
		global_transform = _spawn
		velocity = Vector3.ZERO
	_prev_pos = _curr_pos
	_curr_pos = global_position


func _process(delta: float) -> void:
	visual_position = _prev_pos.lerp(_curr_pos, Engine.get_physics_interpolation_fraction())
	var heading := Vector3(velocity.x, 0.0, velocity.z)
	var rate := 10.0
	if heading.length_squared() <= 0.01 and _face != Vector3.ZERO:
		heading = _face
		rate = 5.0
	if heading.length_squared() > 0.01:
		facing_yaw = lerp_angle(facing_yaw, atan2(heading.x, heading.z), 1.0 - exp(-rate * delta))
	_rig.global_position = visual_position
	_rig.rotation = Vector3(0.0, facing_yaw, 0.0)


## Springs to `to`, clearing the higher end of the jump by `rise`.
func leap(to: Vector3, rise := 0.16, pounce := false) -> void:
	_leaping = true
	grounded = false
	pouncing = pounce
	act = Act.NONE
	posture = Posture.UP
	_leap_from = global_position
	_leap_to = to
	_leap_time = 0.0
	var top := maxf(_leap_from.y, to.y) + rise
	_leap_up = sqrt(2.0 * gravity * (top - _leap_from.y))
	_leap_length = _leap_up / gravity + sqrt(2.0 * (top - to.y) / gravity)
	var flat := Vector3(to.x - _leap_from.x, 0.0, to.z - _leap_from.z)
	if flat.length() > 0.05:
		facing_yaw = atan2(flat.x, flat.z)


## In a spring it goes where it meant to: nothing in the world moves it.
func _fly(delta: float) -> void:
	_leap_time += delta
	var t := minf(_leap_time, _leap_length)
	var at := _leap_from.lerp(_leap_to, t / _leap_length)
	at.y = _leap_from.y + _leap_up * t - 0.5 * gravity * t * t
	var across := (_leap_to - _leap_from) / _leap_length
	velocity = Vector3(across.x, _leap_up - gravity * t, across.z)
	global_position = at
	if _leap_time >= _leap_length:
		_leaping = false
		pouncing = false
		grounded = true
		_land_grace = 0.15
		global_position = _leap_to
		velocity = Vector3(across.x * 0.25, velocity.y, across.z * 0.25)


func is_leaping() -> bool:
	return _leaping


## Does something on the spot (see Act), for as long as it takes.
func perform(what: Act) -> void:
	act = what
	_act_left = CatRig.ACT_TIMES[what]


## What it is about. Returns where it wants to go.
func _think(delta: float) -> Vector3:
	_state_time += delta
	_timer -= delta
	_awake += delta
	_find_timer -= delta
	if target == null and _find_timer <= 0.0:
		_find_timer = 2.0
		var found := get_tree().root.find_children("*", "Player", true, false)
		if not found.is_empty():
			target = found[0]
	if act != Act.NONE:
		_act_left -= delta
		if _act_left <= 0.0:
			act = Act.NONE
	_still = _still + delta if target and target.velocity.length() < 0.4 else 0.0
	_mutter(delta)

	# Anything that hunts sends it up out of reach.
	var threat := _nearest_threat()
	if threat and state != State.FLEE and state != State.PERCHED:
		_threat = threat
		_set_state(State.FLEE)
	match state:
		State.FLEE:
			return _flee(delta)
		State.PERCHED:
			return _sit_it_out(delta)
		State.RETURN:
			return _come_down()
		State.NAP:
			return _nap()
		State.WAKE:
			return _wake()
		State.RUB:
			return _rub_round(delta)
		State.STALK:
			return _stalk()
		State.FOLLOW:
			return _follow()
		State.WATCH:
			return _watch()
		State.AWAY:
			return _keep_away()
	return _wander()


func _set_state(to: State) -> void:
	state = to
	_state_time = 0.0
	_step = 0
	_timer = 0.0
	_goal = Vector3.INF
	creep = false
	rub = 0.0
	asleep = false
	content = 0.0
	gaze = null
	gaze_at = Vector3.INF
	mood = Mood.CALM
	if to != State.NAP:
		posture = Posture.UP


## At a loose end: from one place to another, with a stop at each; and whatever takes its fancy on the way.
func _wander() -> Vector3:
	var boy := _boy_distance()
	if tame < 0.25 and boy < 2.5:
		_set_state(State.AWAY)
		return Vector3.ZERO
	if _awake > nap_after:
		_set_state(State.NAP)
		return Vector3.ZERO
	if _goal == Vector3.INF:
		if _timer > 0.0:
			return Vector3.ZERO
		# What next?
		var pick := randf()
		if tame > 0.5 and boy < 6.0 and (_still > 2.0 or target.is_ducking) and pick < 0.7:
			_set_state(State.RUB)
		elif boy < 12.0 and pick < 0.35:
			_set_state(State.WATCH)
		elif curiosity > 0.5 and boy > 5.0 and boy < 25.0 and pick < 0.75:
			_set_state(State.FOLLOW)
		elif pick > 0.86 and _pick_prey():
			_set_state(State.STALK)
		else:
			_goal = _somewhere(_spawn.origin, roam)
		return Vector3.ZERO
	var want := _go(_goal, walk_speed)
	if want == Vector3.ZERO or _state_time > 20.0:
		_goal = Vector3.INF
		_timer = randf_range(1.0, 3.5)
		_state_time = 0.0
	return want


## Sitting, watching him. Washes if he does nothing worth watching.
func _watch() -> Vector3:
	if _step == 0:
		_face = _to_boy()
		if _state_time > 0.5:
			posture = Posture.SIT
			_step = 1
			_timer = randf_range(6.0, 12.0)
		return Vector3.ZERO
	gaze = target
	content = tame
	mood = Mood.FRIENDLY if tame > 0.7 and _boy_distance() < 3.0 else Mood.CALM
	if act == Act.NONE and _state_time > 3.0 and randf() < 0.004 and (_still > 3.0 or target == null):
		perform(Act.GROOM)
	if act == Act.GROOM:
		gaze = null
	if tame > 0.5 and _boy_distance() < 6.0 and _still > 3.0 and act == Act.NONE and randf() < 0.01:
		_set_state(State.RUB)
	elif _timer <= 0.0 and act == Act.NONE:
		_set_state(State.FOLLOW if curiosity > 0.5 and _boy_distance() > 6.0 else State.WANDER)
		_timer = 0.6
	return Vector3.ZERO


## After him, but not close: it stops when he does, and sits to see what he will do.
func _follow() -> Vector3:
	var distance := _boy_distance()
	if target == null or distance > 30.0:
		_set_state(State.WANDER)
		return Vector3.ZERO
	gaze = target
	if distance < 3.6:
		_set_state(State.WATCH)
		return Vector3.ZERO
	var want := _go(target.global_position, trot_speed if distance > 7.0 else walk_speed)
	if _blocked or _state_time > 25.0:
		_set_state(State.WATCH)
	return want


## Not tame: it will not be come up to.
func _keep_away() -> Vector3:
	var distance := _boy_distance()
	gaze = target
	if distance > 5.0 or target == null:
		_set_state(State.WATCH)
		return Vector3.ZERO
	var away := -_to_boy().normalized()
	var want := _go(global_position + away * 2.0, trot_speed)
	if _blocked:
		# (cornered: round him instead)
		want = _go(global_position + Vector3(away.z, 0.0, -away.x) * 2.0, trot_speed)
	return want


## Round his legs: up to him with its tail in the air, along one side of him
## and back along the other, pushing its head and its flank against him.
func _rub_round(delta: float) -> Vector3:
	if target == null or _boy_distance() > 9.0 or (_still < 0.2 and not target.is_ducking and _step > 0):
		_set_state(State.WATCH)
		return Vector3.ZERO
	mood = Mood.FRIENDLY
	content = 1.0
	var boy := target.global_position
	if _step == 0:
		gaze = target
		if _state_time < 0.1:
			_say("trill", 0.95, 1.1)
		_rub_axis = _to_boy().normalized()
		_rub_side = 1.0
		if _boy_distance() < 0.7:
			_step = 1
		return _go(boy - _rub_axis * 0.5, walk_speed * 1.2)
	# Passes: along him on one side, turn, and back on the other.
	var across := Vector3(_rub_axis.z, 0.0, -_rub_axis.x)
	var forward := 1.0 if _step % 2 == 1 else -1.0
	var goal := boy + across * 0.21 * _rub_side * forward + _rub_axis * 0.5 * forward
	var from_him := global_position - boy
	from_him.y = 0.0
	# (he is on its left when `across` from it to him points that way)
	var beside := clampf(1.0 - absf(from_him.dot(_rub_axis)) / 0.4, 0.0, 1.0)
	var side := signf((-from_him).dot(Vector3(cos(facing_yaw), 0.0, -sin(facing_yaw))))
	rub = move_toward(rub, side * beside, delta * 4.0)
	var want := _go(goal, walk_speed * 0.8)
	if want == Vector3.ZERO:
		_step += 1
		if _step > 5:
			_set_state(State.WATCH)
			_step = 1
			posture = Posture.SIT
			_timer = randf_range(8.0, 14.0)
	return want


## Something to go after: belly down, a few steps and a stop, a few more; then the wiggle, and the spring.
func _stalk() -> Vector3:
	if not is_instance_valid(_prey):
		_set_state(State.WANDER)
		return Vector3.ZERO
	var at := _prey.global_position
	var to := at - global_position
	to.y = 0.0
	gaze_at = at
	mood = Mood.HUNTING
	match _step:
		0:
			creep = true
			_face = to
			if to.length() < 1.25:
				_step = 1
				perform(Act.WIGGLE)
				return Vector3.ZERO
			if _state_time > 20.0 or _blocked:
				_set_state(State.WANDER)
				return Vector3.ZERO
			# (it freezes, and goes on)
			var going := fmod(_state_time, 2.6) < 1.7
			return _go(at, 0.3) if going else Vector3.ZERO
		1:
			creep = true
			_face = to
			if act == Act.NONE:
				_step = 2
				leap(global_position + to.normalized() * maxf(to.length() - 0.12, 0.3), 0.16, true)
		2:
			if _state_time > 0.0 and not _leaping:
				_step = 3
				_timer = 1.2
		3:
			if _timer <= 0.0:
				_set_state(State.WATCH)
	return Vector3.ZERO


## To a place in the sun, down into a loaf, and then asleep: curled up, or flat out on its side.
func _nap() -> Vector3:
	match _step:
		0:
			if _goal == Vector3.INF:
				_goal = _spawn.origin
				for attempt in 10:
					var spot := _somewhere(_spawn.origin, roam)
					if _sunlit(spot):
						_goal = spot
						break
			var want := _go(_goal, walk_speed)
			if want == Vector3.ZERO or _state_time > 20.0:
				_step = 1
				_timer = 1.0
			return want
		1:
			if _timer <= 0.0:
				posture = Posture.LOAF
				content = 1.0
				_step = 2
				_timer = randf_range(5.0, 9.0)
		2:
			content = 1.0
			if _timer <= 0.0:
				posture = Posture.CURL if randf() < 0.6 else Posture.SIDE
				_step = 3
				_timer = nap_length * randf_range(0.8, 1.2)
		3:
			asleep = _state_time > 3.0
			if _timer <= 0.0 or (_boy_distance() < 1.0 and tame < 0.5):
				asleep = false
				_awake = 0.0
				_set_state(State.WAKE)
	return Vector3.ZERO


## Awake: up, a yawn, and the two stretches.
func _wake() -> Vector3:
	if act != Act.NONE or _state_time < 0.9:
		return Vector3.ZERO
	match _step:
		0:
			perform(Act.YAWN)
		1:
			perform(Act.STRETCH_BOW)
		2:
			perform(Act.STRETCH_ARCH)
		_:
			_set_state(State.WANDER)
			return Vector3.ZERO
	_step += 1
	return Vector3.ZERO


## Bolting: to the foot of something high, a moment to gather itself, and up.
func _flee(delta: float) -> Vector3:
	mood = Mood.FRIGHTENED
	if not is_instance_valid(_threat):
		_set_state(State.WANDER)
		return Vector3.ZERO
	var from := _threat.global_position
	match _step:
		0:
			_say("hiss", 0.95, 1.1)
			_step = 1 if _find_perch(from) else 3
			_timer = 6.0
		1:
			gaze_at = _perch
			if _timer <= 0.0:
				_step = 3
			var want := _go(_takeoff, run_speed)
			if want == Vector3.ZERO:
				_step = 2
				_face = _perch - global_position
				perform(Act.GATHER)
			return want
		2:
			gaze_at = _perch
			_face = _perch - global_position
			if act == Act.NONE:
				leap(_perch, 0.14)
				_set_state(State.PERCHED)
				mood = Mood.FRIGHTENED
		3:
			# Nothing to get up on: away from it, as far as it can go.
			var away := global_position - from
			away.y = 0.0
			if away.length() > fear_distance * 1.6:
				_calm += delta
				if _calm > 3.0:
					_set_state(State.WANDER)
				return Vector3.ZERO
			_calm = 0.0
			var want := _go(global_position + away.normalized() * 3.0, run_speed)
			if _blocked:
				want = _go(global_position + Vector3(away.z, 0.0, -away.x).normalized() * 3.0, run_speed)
			return want
	return Vector3.ZERO


## Up out of reach: bristling while they are under it, cross when they are not; down again when they have been gone a while.
func _sit_it_out(delta: float) -> Vector3:
	var threat := _nearest_threat(fear_distance * 1.4)
	if threat:
		_threat = threat
		_calm = 0.0
		var near := threat.global_position.distance_to(global_position) < 4.5
		mood = Mood.FRIGHTENED if near else Mood.ANNOYED
		gaze = threat
		_face = threat.global_position - global_position
		_face.y = 0.0
		if _state_time > 1.2:
			posture = Posture.UP if near else Posture.SIT
	else:
		_calm += delta
		mood = Mood.ANNOYED if _calm < 3.0 else Mood.CALM
		posture = Posture.SIT if _state_time > 1.2 else Posture.UP
		gaze = null
		if _calm > 6.0:
			_set_state(State.RETURN)
	return Vector3.ZERO


## Down again: to the edge it came up over, forepaws down the face of it, and off.
func _come_down() -> Vector3:
	if _takeoff == Vector3.INF:
		_set_state(State.WANDER)
		return Vector3.ZERO
	var out := _takeoff - _perch
	out.y = 0.0
	match _step:
		0:
			_face = out
			if _state_time > 0.9:
				_step = 1
				perform(Act.REACH)
		1:
			_face = out
			gaze_at = _takeoff
			if act == Act.NONE:
				leap(_takeoff + out.normalized() * 0.25, 0.03)
				_step = 2
		2:
			if not _leaping:
				_takeoff = Vector3.INF
				_set_state(State.WANDER)
				_timer = 1.0
	return Vector3.ZERO


## The nearest thing that hunts, if it is near enough to matter.
func _nearest_threat(within := -1.0) -> Node3D:
	var nearest := fear_distance if within < 0.0 else within
	var found: Node3D = null
	for thing: Node in get_tree().get_nodes_in_group(&"pursuers"):
		var other := thing as Node3D
		if other == null:
			continue
		var distance := other.global_position.distance_to(global_position)
		if distance < nearest:
			nearest = distance
			found = other
	return found


## Somewhere to get up onto: flat, between what a hunter can reach and what it
## can jump, with room on it. Sets `_perch` (where it lands) and `_takeoff`
## (where it jumps from). Looks first at anything in the group `perches`.
func _find_perch(from: Vector3) -> bool:
	var here := global_position
	var least := 0.7
	if is_instance_valid(_threat) and &"jump_height" in _threat:
		least = float(_threat.get(&"jump_height")) + 0.08
	var spots: Array[Vector3] = []
	for mark: Node in get_tree().get_nodes_in_group(&"perches"):
		if mark is Node3D and (mark as Node3D).global_position.distance_to(here) < 14.0:
			spots.append((mark as Node3D).global_position)
	for step in 16:
		var ring := 1.0 + step * 0.75
		var count := int(maxf(10.0, ring * 5.0))
		for k in count:
			var angle := TAU * k / count + ring
			spots.append(here + Vector3(sin(angle), 0.0, cos(angle)) * ring)
	var best := -INF
	_perch = Vector3.INF
	for spot in spots:
		var top := _surface(Vector3(spot.x, here.y + jump_height + 0.5, spot.z), jump_height + 0.3)
		if top == Vector3.INF or top.y - here.y < least or top.y - here.y > jump_height:
			continue
		# Which way it would come at it, and where the edge is on that side.
		var out := here - top
		out.y = 0.0
		if out.length() < 0.3:
			continue
		out = out.normalized()
		var edge := -1.0
		var foot := Vector3.INF
		for k in range(1, 30):
			var below := _surface(top + out * (k * 0.1) + Vector3.UP * 0.3, top.y - here.y + 1.0)
			if below == Vector3.INF or below.y < top.y - 0.4:
				edge = k * 0.1
				foot = _surface(top + out * (edge + 0.5) + Vector3.UP * 0.3, top.y - here.y + 1.0)
				break
			if absf(below.y - top.y) > 0.06:
				break
		if edge < 0.0 or foot == Vector3.INF or absf(foot.y - here.y) > 0.35:
			continue
		var landing := top + out * maxf(edge - 0.3, 0.0)
		# (room for a cat on it)
		var room := true
		for offset: Vector3 in [Vector3(0.16, 0, 0), Vector3(-0.16, 0, 0), Vector3(0, 0, 0.16), Vector3(0, 0, -0.16)]:
			var beside := _surface(landing + offset + Vector3.UP * 0.4, 0.8)
			room = room and beside != Vector3.INF and absf(beside.y - top.y) < 0.06
		if not room:
			continue
		var score := (top.y - here.y) * 2.0 - foot.distance_to(here) + landing.distance_to(from) * 0.5 - (3.0 if foot.distance_to(from) < 1.5 else 0.0)
		if score > best:
			best = score
			_perch = landing
			_takeoff = foot
	return _perch != Vector3.INF


## The ground under a point: straight down from it, as far as `reach`.
func _surface(from: Vector3, reach: float) -> Vector3:
	var query := PhysicsRayQueryParameters3D.create(from, from + Vector3.DOWN * reach, 1)
	var hit := get_world_3d().direct_space_state.intersect_ray(query)
	if hit.is_empty() or (hit.normal as Vector3).y < 0.8:
		return Vector3.INF
	return hit.position


## Towards a place. Returns the way to go, or nothing when it is there; `_blocked` if it cannot get on.
func _go(to: Vector3, speed: float) -> Vector3:
	var way := to - global_position
	way.y = 0.0
	if way.length() < 0.16:
		return Vector3.ZERO
	var along := way.normalized()
	# Not off the edge of anything high, and not into a wall.
	var ahead := _surface(global_position + along * 0.3 + Vector3.UP * 0.4, 1.0)
	if ahead == Vector3.INF or test_move(global_transform.translated(Vector3.UP * 0.1), along * 0.25):
		_blocked = true
		_goal = Vector3.INF
		return Vector3.ZERO
	return along * minf(speed, maxf(way.length() * 6.0, 0.3))


## A place to walk to, near `about`, with ground under it.
func _somewhere(about: Vector3, within: float) -> Vector3:
	for attempt in 8:
		var angle := randf() * TAU
		var spot := about + Vector3(sin(angle), 0.0, cos(angle)) * randf_range(1.0, within)
		var ground := _surface(spot + Vector3.UP * 0.5, 1.2)
		if ground != Vector3.INF and absf(ground.y - global_position.y) < 0.3:
			return ground
	return global_position


## Whether the sun reaches a place.
func _sunlit(spot: Vector3) -> bool:
	if _sun == null:
		var lights := get_tree().root.find_children("*", "DirectionalLight3D", true, false)
		if lights.is_empty():
			return false
		_sun = lights[0]
	var from := spot + Vector3.UP * 0.2
	var query := PhysicsRayQueryParameters3D.create(from, from + _sun.global_basis.z * 60.0, 1)
	return get_world_3d().direct_space_state.intersect_ray(query).is_empty()


func _pick_prey() -> bool:
	_prey = null
	var nearest := 7.0
	for kind: StringName in [&"prey", &"interest"]:
		for thing: Node in get_tree().get_nodes_in_group(kind):
			var other := thing as Node3D
			if other == null or other is Player:
				continue
			var distance := other.global_position.distance_to(global_position)
			if distance > 1.8 and distance < nearest and absf(other.global_position.y - global_position.y) < 0.4:
				nearest = distance
				_prey = other
	return _prey != null


func _boy_distance() -> float:
	return target.global_position.distance_to(global_position) if target else INF


func _to_boy() -> Vector3:
	if target == null:
		return Vector3.ZERO
	var to := target.global_position - global_position
	to.y = 0.0
	return to


## Tells it of a sound, so that its ears go to it (and, asleep, one ear only).
func hear(from: Vector3) -> void:
	heard = from
	_heard_left = 1.5


## What it says: a meow at him when it wants something of him, a purr when it
## is pleased, a growl from up out of reach.
func _mutter(delta: float) -> void:
	_say_timer -= delta
	var pleased := content > 0.8 and (state == State.RUB or (_boy_distance() < 2.5 and not asleep))
	if voice and pleased and not _purr.playing and _bank.has("purr"):
		var takes: Array = _bank["purr"]
		_purr.stream = takes.pick_random()
		_purr.play()
	elif not pleased and _purr.playing:
		_purr.stop()
	if _say_timer > 0.0 or _voice.playing:
		return
	_say_timer = randf_range(5.0, 12.0)
	if state == State.PERCHED and mood == Mood.FRIGHTENED:
		_say("growl" if randf() < 0.6 else "hiss", 0.95, 1.08)
		_say_timer = randf_range(2.5, 5.0)
	elif (state == State.WATCH or state == State.FOLLOW) and tame > 0.3 and _boy_distance() < 7.0 and randf() < 0.5:
		_say("meow", 0.94, 1.08)


## Plays one of the recordings of a kind, not the one that was played last.
func _say(kind: String, low: float, high: float) -> void:
	var takes: Array = _bank.get(kind, [])
	if takes.is_empty() or not voice:
		return
	var pick := randi() % takes.size()
	if takes.size() > 1 and pick == _last_said.get(kind, -1):
		pick = (pick + 1 + randi() % (takes.size() - 1)) % takes.size()
	_last_said[kind] = pick
	var stream: AudioStream = takes[pick]
	voice_rate = randf_range(low, high)
	voice_length = stream.get_length()
	voice_envelope = _envelopes.get(stream, PackedFloat32Array())
	_voice.stream = stream
	_voice.pitch_scale = voice_rate
	_voice.play()
	voiced.emit()


## Finds the recordings (audio/cat/<kind>_<number>.wav), and measures how loud
## each is through its length, for its jaw to keep time with.
static func _load_voices() -> void:
	if _looked:
		return
	_looked = true
	for kind in KINDS:
		var takes: Array = []
		for number in range(1, 20):
			var path := "res://audio/cat/%s_%d.wav" % [kind, number]
			if not ResourceLoader.exists(path):
				break
			var stream := load(path) as AudioStream
			if stream == null:
				break
			takes.append(stream)
			_envelopes[stream] = Hound._loudness(stream as AudioStreamWAV)
		if not takes.is_empty():
			_bank[kind] = takes
