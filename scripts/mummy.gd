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

signal caught

const MODEL := preload("res://models/mummy.glb")
const MODEL_LOW := preload("res://models/mummy_lo.glb")
## How much bigger than it is modelled it stands.
const SIZE := 1.3

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
## How fast it throws itself forward as the arm comes down.
@export var lunge_speed := 2.4
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

	var shape := CapsuleShape3D.new()
	shape.radius = 0.26
	shape.height = 1.7
	var collider := CollisionShape3D.new()
	collider.shape = shape
	collider.position.y = shape.height * 0.5
	add_child(collider)

	_rig = MummyRig.new()
	_rig.model = MODEL_LOW if Settings.low_poly else MODEL
	add_child(_rig)
	_rig.top_level = true
	_rig.scale = Vector3.ONE * SIZE

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
				elif flat.length() > 0.5:
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
			lunging = grounded and _negotiate(forward) != Vector3.ZERO
			if hunting and not _has_him and _finds_him():
				_has_him = true
				caught.emit()
		_:
			_turning = false

	var current := Vector3(velocity.x, 0.0, velocity.z).move_toward(wish * walk_speed * _rig.pace(), acceleration * delta)
	if lunging:
		# (as far as will bring its arm to him, and no further: it does not walk through him)
		var gap := lunge_speed * MummyRig.STRIKE
		if hunting:
			gap = clampf((target.global_position - global_position).dot(forward) - 0.8, 0.0, gap)
		current = forward * gap / MummyRig.STRIKE
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
	# It will not step into a drop.
	var ahead := global_position + wish * 0.7
	var query := PhysicsRayQueryParameters3D.create(ahead + Vector3.UP * 0.6, ahead + Vector3.DOWN * 1.0, 1)
	if get_world_3d().direct_space_state.intersect_ray(query).is_empty():
		return Vector3.ZERO

	var hit := KinematicCollision3D.new()
	if not test_move(global_transform, wish * 0.25, hit) or hit.get_normal().y > 0.6:
		# Clear ahead; finish any detour it is in the middle of.
		if _detour_time > 0.0:
			return (wish * 0.5 + _detour).normalized()
		return wish
	# A kerb: step up onto it.
	var raised := global_transform.translated(Vector3.UP * 0.32)
	if not test_move(global_transform, Vector3.UP * 0.32) and not test_move(raised, wish * 0.3):
		global_position += Vector3.UP * 0.3 + wish * 0.12
		return wish
	# Anything taller: pick a side and keep to it for a moment, so it walks
	# clean round a corner instead of dithering against it.
	if _detour_time <= 0.0:
		_detour = Vector3(-wish.z, 0.0, wish.x)
		var obstacle := hit.get_collider() as Node3D
		if obstacle and _detour.dot(global_position - obstacle.global_position) < 0.0:
			_detour = -_detour
	_detour_time = 0.9
	return (wish * 0.5 + _detour).normalized()
