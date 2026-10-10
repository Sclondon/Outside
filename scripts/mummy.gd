class_name Mummy
extends CharacterBody3D
## The thing in the sarcophagus. It stands dormant, arms crossed, until woken;
## then it comes after its target at a lurching, dragging walk, never hurrying
## and never stopping. It steps round blocks and over low kerbs but cannot
## jump, so a pit holds it.
##
## It does not catch him by being near him. When he is within reach it stops,
## rears back with an arm raised (he has that long to get away), and throws the
## arm down and across where he stands; `caught` is emitted only if the arm
## finds him. Then it hangs there a moment, overbalanced, before it comes on.
##
## Like the hound, it builds everything it needs: `Mummy.new()` is a whole mummy.
## It is animated by MummyRig (scripts/mummy_rig.gd), on a skeleton of its own.
##
## That is the first kind, and what `Mummy.new()` makes. `kind` picks another
## (set it before the mummy goes into the scene): each has a model of its own,
## a rig of its own that extends MummyRig and walks and strikes its own way,
## and its own numbers below (see KINDS), so that each has to be got away from
## differently:
##
## - SHAMBLER: as above.
## - PRIEST: tall and gaunt. It walks stiff and upright on straight legs, arms
##   crossed, at an even pace, and unfolds them as it nears him. It strikes by
##   bowing from the hips and bringing both hands down on him from a long way
##   off, but only straight in front of it, and it is slow to turn. Its knees do
##   not bend: a kerb stops it, and it will not step down off anything.
## - BRUTE: squat and very heavy, knuckles at the ground. It waddles, slowly,
##   and sweeps one long arm round level at the height of his chest (duck, and
##   it passes over him); every third time it brings both down from over its
##   head instead. It is too wide for a narrow gap.
## - CRAWLER: what is left of one from the thighs up. It hauls itself along on
##   its arms, fast, in surges, and throws itself at his ankles (jump, and it
##   goes under him). It is low enough to follow him under things and goes over
##   any edge after him, but it cannot get up a kerb, let alone out of a pit.
## - CHILD: small. It scuttles in quick bursts with stops between them, when it
##   stands and looks; it turns in an instant, springs at him from close to, gets
##   up onto things half its own height and jumps down from twice it.
## - ROYAL: masked in gold, in the striped headcloth and broad collar, crook and
##   flail crossed on its chest. It glides at a slow, even walk and never hurries
##   or stops: it strikes as it comes, with the crook, further than any of the
##   others can reach, and stays that far off.

signal caught

enum Kind { SHAMBLER, PRIEST, BRUTE, CRAWLER, CHILD, ROYAL }

const MODEL := preload("res://models/mummy.glb")
const MODEL_LOW := preload("res://models/mummy_lo.glb")
## How much bigger than it is modelled it stands.
const SIZE := 1.3
## What each kind has of its own. `model`: its model, in models/ (and the same
## name with `_lo`). `size`: as SIZE. `radius`, `height`: the capsule it is to
## the world. The rest are the properties below of the same names.
const KINDS := {
	Kind.SHAMBLER: {"model": "mummy", "size": SIZE, "radius": 0.26, "height": 1.7, "walk_speed": 1.3, "acceleration": 9.0, "turn_rate": 3.2, "wake_time": 1.8,
		"reach_distance": 1.4, "catch_distance": 0.4, "lunge_speed": 2.4, "lunge_to": 0.8, "step_up": 0.3, "drop": 1.0, "stand_off": 0.5, "presses_on": false},
	Kind.PRIEST: {"model": "mummy_priest", "size": 1.4, "radius": 0.24, "height": 2.0, "walk_speed": 1.35, "acceleration": 6.0, "turn_rate": 1.5, "wake_time": 2.4,
		"reach_distance": 1.8, "catch_distance": 0.4, "lunge_speed": 3.2, "lunge_to": 1.15, "step_up": 0.0, "drop": 0.5, "stand_off": 0.5, "presses_on": false},
	Kind.BRUTE: {"model": "mummy_brute", "size": 1.45, "radius": 0.42, "height": 1.6, "walk_speed": 0.95, "acceleration": 5.0, "turn_rate": 2.2, "wake_time": 2.6,
		"reach_distance": 1.75, "catch_distance": 0.34, "lunge_speed": 3.0, "lunge_to": 0.85, "step_up": 0.3, "drop": 1.0, "stand_off": 0.6, "presses_on": false},
	Kind.CRAWLER: {"model": "mummy_crawler", "size": 1.3, "radius": 0.3, "height": 0.7, "walk_speed": 2.3, "acceleration": 14.0, "turn_rate": 4.5, "wake_time": 1.2,
		"reach_distance": 1.6, "catch_distance": 0.34, "lunge_speed": 4.5, "lunge_to": 0.75, "step_up": 0.0, "drop": 100.0, "stand_off": 0.6, "presses_on": false},
	Kind.CHILD: {"model": "mummy_child", "size": 1.0, "radius": 0.2, "height": 0.95, "walk_speed": 2.9, "acceleration": 40.0, "turn_rate": 9.0, "wake_time": 1.0,
		"reach_distance": 1.0, "catch_distance": 0.34, "lunge_speed": 3.2, "lunge_to": 0.35, "step_up": 0.5, "drop": 2.0, "stand_off": 0.4, "presses_on": false},
	Kind.ROYAL: {"model": "mummy_royal", "size": 1.4, "radius": 0.26, "height": 1.95, "walk_speed": 0.8, "acceleration": 4.0, "turn_rate": 1.3, "wake_time": 3.0,
		"reach_distance": 2.3, "catch_distance": 0.4, "lunge_speed": 0.0, "lunge_to": 0.8, "step_up": 0.3, "drop": 0.6, "stand_off": 1.2, "presses_on": true},
}

## Which kind of mummy it is. Setting it gives every number below that kind's
## own value, so change any of them after it, and set it before the mummy is
## put into the scene (that is when its model and its rig are made).
@export var kind := Kind.SHAMBLER:
	set(value):
		kind = value
		for key: String in KINDS[kind]:
			if key not in ["model", "size", "radius", "height"]:
				set(key, KINDS[kind][key])

## Its speed taken over a whole step: it goes faster and slower than this as it lurches.
@export var walk_speed := 1.3
@export var acceleration := 9.0
@export var turn_rate := 3.2
## Seconds between being disturbed and starting to walk.
@export var wake_time := 1.8
## How near he must be for it to swipe at him.
@export var reach_distance := 1.4
## How near to him the sweeping arm must pass to have him.
@export var catch_distance := 0.4
## How fast it throws itself forward as the arm comes down, and how near to him that may bring it.
@export var lunge_speed := 2.4
@export var lunge_to := 0.8
## The highest thing it can step up onto, and the furthest it will step down. (None of them can jump.)
@export var step_up := 0.3
@export var drop := 1.0
## How near to him it comes before it stands and waits to strike.
@export var stand_off := 0.5
## Whether it goes on walking while it strikes.
@export var presses_on := false
@export var gravity := 24.0

var target: Player
var chasing := false
## Heading of the model, radians around Y. Zero faces +Z, out of its niche.
var facing_yaw := 0.0
var visual_position := Vector3.ZERO
## Only here so the shared rig can tell a walk from a run; it never runs.
var run_speed := 5.0
var is_pushing := false

var _spawn := Transform3D.IDENTITY
var _prev_pos := Vector3.ZERO
var _curr_pos := Vector3.ZERO
var _waking := 0.0
var _detour := Vector3.ZERO
var _detour_time := 0.0
var _rig: MummyRig
## How many times it has swiped (which decides the arm), whether this swipe has
## found him, and whether it may still turn to follow him.
var _swipes := 0
var _has_him := false
var _turning := true


func _ready() -> void:
	add_to_group(&"pursuers")
	# Passes through the player; the world, blocks and doors stop it.
	collision_layer = 4
	collision_mask = 1
	floor_snap_length = 0.3

	var own: Dictionary = KINDS[kind]
	var shape := CapsuleShape3D.new()
	shape.radius = own["radius"]
	shape.height = own["height"]
	var collider := CollisionShape3D.new()
	collider.shape = shape
	collider.position.y = shape.height * 0.5
	add_child(collider)

	match kind:
		Kind.PRIEST:
			_rig = MummyPriestRig.new()
		Kind.BRUTE:
			_rig = MummyBruteRig.new()
		Kind.CRAWLER:
			_rig = MummyCrawlerRig.new()
		Kind.CHILD:
			_rig = MummyChildRig.new()
		Kind.ROYAL:
			_rig = MummyRoyalRig.new()
		_:
			_rig = MummyRig.new()
	if kind == Kind.SHAMBLER:
		_rig.model = MODEL_LOW if Settings.low_poly else MODEL
	else:
		_rig.model = load("res://models/%s%s.glb" % [own["model"], "_lo" if Settings.low_poly else ""])
	add_child(_rig)
	_rig.top_level = true
	_rig.scale = Vector3.ONE * own["size"]

	_spawn = global_transform
	reset()


## Disturbs it. Nothing happens for `wake_time`, then it comes.
func wake() -> void:
	if not chasing and _waking <= 0.0:
		_waking = wake_time


func is_awake() -> bool:
	return chasing or _waking > 0.0


## Back in its niche, dormant.
func reset() -> void:
	global_transform = _spawn
	velocity = Vector3.ZERO
	chasing = false
	_waking = 0.0
	facing_yaw = 0.0
	_turning = true
	_prev_pos = global_position
	_curr_pos = global_position
	visual_position = global_position
	_rig.awake = 0.0
	_rig.arms_reach = 0.0
	_rig.aim = Vector3.INF
	_rig.global_position = visual_position
	_rig.rotation = Vector3.ZERO
	_rig.settle()


func _physics_process(delta: float) -> void:
	if _waking > 0.0:
		_waking -= delta
		chasing = _waking <= 0.0

	var grounded := is_on_floor()
	_detour_time -= delta
	var wish := Vector3.ZERO
	var forward := Vector3(sin(facing_yaw), 0.0, cos(facing_yaw))
	var hunting := chasing and target != null and not target.is_limp
	var lunging := false
	_turning = true
	match _rig.stage():
		MummyRig.Stage.NONE:
			if hunting:
				var to := target.global_position - global_position
				var flat := Vector3(to.x, 0.0, to.z)
				if grounded and flat.length() < reach_distance and absf(to.y) < 1.2 and (forward.dot(flat.normalized()) > 0.8 or flat.length() < 0.6):
					# Left, right, and every third time both.
					_swipes += 1
					_has_him = false
					_rig.swipe(2 if _swipes % 3 == 0 else _swipes % 2)
				elif flat.length() > stand_off:
					wish = flat.normalized()
					if grounded:
						wish = _negotiate(wish)
		MummyRig.Stage.WIND_UP:
			# It follows him round as it rears back, but not to the last: once
			# the arm is about to come down it is committed.
			_turning = _rig.strikes_in() > 0.2
		MummyRig.Stage.STRIKE:
			_turning = false
			# (it will not throw itself into a pit)
			lunging = grounded and lunge_speed > 0.0 and _negotiate(forward) != Vector3.ZERO
			if hunting and not _has_him and _finds_him():
				_has_him = true
				caught.emit()
		_:
			_turning = false
	if presses_on and hunting and grounded and _rig.stage() != MummyRig.Stage.NONE:
		# (the one that does not stop to strike: it comes on all the while, as far as its reach)
		var to_him := target.global_position - global_position
		to_him.y = 0.0
		if to_him.length() > stand_off:
			wish = _negotiate(to_him.normalized())

	var current := Vector3(velocity.x, 0.0, velocity.z).move_toward(wish * walk_speed * _rig.pace(), acceleration * delta)
	if lunging:
		# (as far as will bring its arm to him, and no further: it does not walk through him)
		var gap := lunge_speed * _rig.swipe_strike
		if hunting:
			gap = clampf((target.global_position - global_position).dot(forward) - lunge_to, 0.0, gap)
		current = forward * gap / _rig.swipe_strike
	velocity.x = current.x
	velocity.z = current.z
	if not grounded:
		velocity.y -= gravity * delta
	move_and_slide()
	_prev_pos = _curr_pos
	_curr_pos = global_position


## Whether an arm that is sweeping now passes through him.
func _finds_him() -> bool:
	var feet := target.global_position
	var top := feet + Vector3.UP * (0.65 if target.is_ducking or target.is_crawling else 1.1)
	for arm in _rig.claws():
		var nearest := Geometry3D.get_closest_points_between_segments(arm[0], arm[1], feet + Vector3.UP * 0.1, top)
		if nearest[0].distance_to(nearest[1]) < catch_distance:
			return true
	return false


func _process(delta: float) -> void:
	visual_position = _prev_pos.lerp(_curr_pos, Engine.get_physics_interpolation_fraction())
	var hunting := chasing and target != null
	var heading := Vector3(velocity.x, 0.0, velocity.z)
	if hunting and (heading.length_squared() < 0.05 or _rig.stage() != MummyRig.Stage.NONE):
		# Held up, or about to strike: it still turns to face him.
		heading = target.global_position - global_position
		heading.y = 0.0
	if chasing and _turning and heading.length_squared() > 0.01:
		facing_yaw = lerp_angle(facing_yaw, atan2(heading.x, heading.z), 1.0 - exp(-turn_rate * delta))
	_rig.awake = 1.0 if is_awake() else 0.0
	_rig.arms_reach = lerpf(_rig.arms_reach, 1.0 if hunting and not target.is_limp else 0.0, 1.0 - exp(-2.5 * delta))
	_rig.aim = target.global_position + Vector3.UP * 0.8 if hunting and not target.is_limp else Vector3.INF
	_rig.global_position = visual_position
	_rig.rotation = Vector3(0.0, facing_yaw, 0.0)


## Deals with what is in the way. Returns the direction to walk.
func _negotiate(wish: Vector3) -> Vector3:
	# It will not walk into burning oil: it stands at the edge of it until it has
	# burnt out. (One that is in it already walks on out.)
	if Oil.is_burning_at(global_position + wish * 0.7, 0.35) and not Oil.is_burning_at(global_position, 0.1):
		return Vector3.ZERO
	# It will not step into a drop (unless it is one that goes over anything).
	var ahead := global_position + wish * 0.7
	var query := PhysicsRayQueryParameters3D.create(ahead + Vector3.UP * 0.6, ahead + Vector3.DOWN * drop, 1)
	if drop < 50.0 and get_world_3d().direct_space_state.intersect_ray(query).is_empty():
		return Vector3.ZERO

	var hit := KinematicCollision3D.new()
	if not test_move(global_transform, wish * 0.25, hit) or hit.get_normal().y > 0.6:
		# Clear ahead; finish any detour it is in the middle of.
		if _detour_time > 0.0:
			return (wish * 0.5 + _detour).normalized()
		return wish
	# A kerb: step up onto it, if it can step that high (it tries the least height first).
	var rise := minf(step_up, 0.3)
	while rise > 0.0 and rise <= step_up + 0.001:
		var raised := global_transform.translated(Vector3.UP * (rise + 0.02))
		if not test_move(global_transform, Vector3.UP * (rise + 0.02)) and not test_move(raised, wish * 0.3):
			global_position += Vector3.UP * rise + wish * 0.12
			return wish
		rise += 0.2
	# Anything taller: pick a side and keep to it for a moment, so it walks
	# clean round a corner instead of dithering against it.
	if _detour_time <= 0.0:
		_detour = Vector3(-wish.z, 0.0, wish.x)
		var obstacle := hit.get_collider() as Node3D
		if obstacle and _detour.dot(global_position - obstacle.global_position) < 0.0:
			_detour = -_detour
	_detour_time = 0.9
	return (wish * 0.5 + _detour).normalized()
