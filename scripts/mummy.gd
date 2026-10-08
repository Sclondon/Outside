class_name Mummy
extends CharacterBody3D
## The thing in the sarcophagus. It stands dormant until woken, then walks
## after its target, arms out, never hurrying and never stopping. It steps
## round blocks and over low kerbs but cannot jump, so a pit holds it.
##
## Like the hound, it builds everything it needs: `Mummy.new()` is a whole mummy.
## It is animated by the same rig as the boy, on a skeleton of its own.

signal caught

const MODEL := preload("res://models/mummy.glb")
const MODEL_LOW := preload("res://models/mummy_lo.glb")
## How much taller than the boy it stands.
const SIZE := 1.3

@export var walk_speed := 1.35
@export var acceleration := 6.0
@export var turn_rate := 4.0
## Seconds between being disturbed and starting to walk.
@export var wake_time := 1.8
@export var catch_distance := 0.75
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
var _rig: CharacterRig


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

	_rig = CharacterRig.new()
	_rig.model = MODEL_LOW if Settings.low_poly else MODEL
	_rig.stoop = 0.12
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
	_prev_pos = global_position
	_curr_pos = global_position
	visual_position = global_position


func _physics_process(delta: float) -> void:
	if _waking > 0.0:
		_waking -= delta
		chasing = _waking <= 0.0

	var grounded := is_on_floor()
	_detour_time -= delta
	var wish := Vector3.ZERO
	if chasing and target and not target.is_limp:
		var to := target.global_position - global_position
		var flat := Vector3(to.x, 0.0, to.z)
		if flat.length() < catch_distance and absf(to.y) < 1.2:
			caught.emit()
		else:
			wish = flat.normalized()
			if grounded:
				wish = _negotiate(wish)

	var current := Vector3(velocity.x, 0.0, velocity.z).move_toward(wish * walk_speed, acceleration * delta)
	velocity.x = current.x
	velocity.z = current.z
	if not grounded:
		velocity.y -= gravity * delta
	move_and_slide()
	_prev_pos = _curr_pos
	_curr_pos = global_position


func _process(delta: float) -> void:
	visual_position = _prev_pos.lerp(_curr_pos, Engine.get_physics_interpolation_fraction())
	var heading := Vector3(velocity.x, 0.0, velocity.z)
	if chasing and target and heading.length_squared() < 0.05:
		# Held up: it still turns to face him.
		heading = target.global_position - global_position
		heading.y = 0.0
	if chasing and heading.length_squared() > 0.01:
		facing_yaw = lerp_angle(facing_yaw, atan2(heading.x, heading.z), 1.0 - exp(-turn_rate * delta))
	_rig.arms_reach = lerpf(_rig.arms_reach, 1.0 if is_awake() else 0.0, 1.0 - exp(-2.5 * delta))
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
