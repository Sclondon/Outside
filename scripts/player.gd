class_name Player
extends CharacterBody3D
## Character controller tuned for touch.
##
## Simulation runs in the physics step; the visible rig is detached and follows an
## interpolated position, so motion stays smooth on any refresh rate.
##
## Besides running and jumping he can push blocks, duck, slide out of a run,
## catch and climb ledges, climb ropes, and pick things up and throw them.

signal jumped
signal landed(impact_speed: float)
signal respawned
signal threw

enum MoveMode {
	FREE, ## Camera-relative movement on the whole ground plane.
	SIDE_SCROLL, ## Movement along world X only, like Inside.
}

## What the body is doing, beyond ordinary movement.
enum State {
	FREE, ## Walking, running, ducking, in the air.
	SLIDE, ## Sliding low out of a run.
	HANG, ## Hanging from a ledge by the hands.
	CLIMB, ## Pulling up onto that ledge.
	ROPE, ## On a rope.
}

@export var move_mode := MoveMode.FREE

@export_group("Ground")
@export var walk_speed := 1.6
@export var run_speed := 4.4
@export var push_speed := 1.4
## Stick deflection at which the walk starts turning into a run.
@export_range(0.0, 1.0) var run_threshold := 0.55
@export var acceleration := 20.0
@export var deceleration := 26.0
## Used while input opposes the current velocity, for snappy reversals.
@export var turn_acceleration := 36.0
## How quickly the model turns to face its heading.
@export var turn_rate := 13.0
@export var max_step_height := 0.32

@export_group("Air")
@export var jump_height := 1.15
@export var time_to_apex := 0.36
@export var fall_gravity_scale := 1.7
## Extra gravity while rising after jump is released, giving short hops.
@export var jump_cut_gravity_scale := 2.8
@export var air_acceleration := 10.0
@export var max_fall_speed := 20.0
## Grace period to still jump after walking off a ledge.
@export var coyote_time := 0.12
## A jump pressed this long before landing still fires.
@export var jump_buffer_time := 0.15

@export_group("Duck and slide")
@export var crouch_speed := 1.3
@export var stand_height := 1.25
@export var crouch_height := 0.72
@export var slide_height := 0.6
## Ducking while moving at least this fast starts a slide instead.
@export var slide_min_speed := 3.0
## How quickly a slide loses speed, m/s².
@export var slide_friction := 4.5
## A slide ends when it has slowed to this.
@export var slide_end_speed := 1.5

@export_group("Climbing")
## A ledge can be caught when its top is this far above the feet (least, most).
@export var ledge_reach := Vector2(0.55, 1.6)
## How far below the ledge the feet hang.
@export var hang_height := 1.27
@export var climb_time := 1.15
@export var rope_speed := 1.5

@export_group("Throwing")
@export var pickup_reach := 1.1
## Speed given to a thrown object: forwards, upwards.
@export var throw_speed := Vector2(9.0, 5.5)

@export_group("Feel")
## Landing faster than this makes the character stumble.
@export var hard_landing_speed := 11.0
@export var hard_landing_time := 0.4
@export var push_force := 500.0
@export var kill_height := -15.0

## Heading of the model, radians around Y. Zero faces +Z.
var facing_yaw := PI * 0.5
var is_pushing := false
## True while the body is a ragdoll and takes no input.
var is_limp := false
var state := State.FREE
var is_ducking := false
## How far through pulling up onto a ledge, 0..1.
var climb_progress := 0.0
## Distance climbed on the current rope, for the hand-over-hand.
var rope_travel := 0.0
## How long he has been off the ground, seconds.
var air_time := 0.0
## Where his hands belong when he has hold of something (left, right, in world
## space), and how firmly, 0..1: a ledge, a rope, or whatever he is leaning on.
## The rig reaches for these.
var hand_points := PackedVector3Array([Vector3.ZERO, Vector3.ZERO])
var hand_reach := 0.0
## What he is holding, if anything.
var carried: RigidBody3D
## Render-rate position of the character; follow this, not global_position.
var visual_position := Vector3.ZERO

var _touch: TouchControls
var _gravity := 0.0
var _jump_velocity := 0.0
var _coyote := 0.0
var _jump_buffer := 0.0
var _stun := 0.0
var _push_timer := 0.0
var _jumping := false
var _was_grounded := false
var _wish := Vector3.ZERO
var _spawn := Transform3D.IDENTITY
var _prev_pos := Vector3.ZERO
var _curr_pos := Vector3.ZERO
var _visual_offset := Vector3.ZERO
var _state_time := 0.0
var _grab_cooldown := 0.0
var _slide_direction := Vector3.ZERO
var _ledge_top := Vector3.ZERO
var _ledge_direction := Vector3.ZERO
var _climb_from := Vector3.ZERO
var _rope: Rope
var _rope_hand_y := 0.0
var _rope_heading := Vector3.ZERO
var _carried_layers := Vector2i.ZERO
var _lean_timer := 0.0
## How long he has been leaning without a break; a brush against a step is not a lean.
var _lean_held := 0.0
var _lean_point := Vector3.ZERO
var _lean_normal := Vector3.ZERO

@onready var _rig: CharacterRig = $Rig
@onready var _collider: CollisionShape3D = $Collision
@onready var _capsule: CapsuleShape3D = _collider.shape
@onready var _radius: float = _capsule.radius


func _ready() -> void:
	_ensure_input_actions()
	_gravity = 2.0 * jump_height / (time_to_apex * time_to_apex)
	_jump_velocity = 2.0 * jump_height / time_to_apex
	floor_snap_length = max_step_height
	floor_max_angle = deg_to_rad(46.0)
	floor_constant_speed = true
	# Its own layer, so hounds can run through the player rather than shove them.
	collision_layer = 2
	_spawn = global_transform
	_rig.top_level = true
	_set_height(stand_height)
	_reset_visuals()
	_connect_touch.call_deferred()


func _connect_touch() -> void:
	_touch = get_tree().get_first_node_in_group(&"touch_controls") as TouchControls
	if _touch:
		_touch.jump_pressed.connect(_queue_jump)
		_touch.act_pressed.connect(_act)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed(&"jump"):
		_queue_jump()
	elif event.is_action_pressed(&"act"):
		_act()
	elif event.is_action_pressed(&"ragdoll"):
		# For trying it out: R drops him, R again stands him back up.
		if is_limp:
			recover()
		else:
			ragdoll(Vector3(sin(facing_yaw), 0.6, cos(facing_yaw)) * 25.0)


func _queue_jump() -> void:
	_jump_buffer = jump_buffer_time


func _physics_process(delta: float) -> void:
	if is_limp:
		velocity = Vector3.ZERO
		return
	var input := _read_move_input()
	var strength := minf(input.length(), 1.0)
	_wish = _to_world(input)
	_jump_buffer -= delta
	_grab_cooldown -= delta
	_state_time += delta

	match state:
		State.HANG:
			_hang()
		State.CLIMB:
			_climb()
		State.ROPE:
			_climb_rope(input, delta)
		_:
			_move(strength, delta)

	_place_hands(delta)
	if global_position.y < kill_height:
		respawn()
	_prev_pos = _curr_pos
	_curr_pos = global_position


## Ordinary movement: on the ground, in the air, ducked or sliding.
func _move(strength: float, delta: float) -> void:
	var grounded := is_on_floor()
	_coyote = coyote_time if grounded else _coyote - delta
	_stun -= delta
	_push_timer -= delta
	is_pushing = _push_timer > 0.0

	_update_stance(grounded)
	if state == State.SLIDE:
		_slide(grounded, delta)
	else:
		_move_horizontal(strength, grounded, delta)
	_move_vertical(grounded, delta)

	var fall_speed := -velocity.y
	var before := global_position
	var stepped := grounded and velocity.y <= 0.0 and state == State.FREE and _try_step_up(delta)
	move_and_slide()
	_push_bodies(delta)
	_note_lean()

	var now_grounded := is_on_floor()
	if now_grounded and not _was_grounded:
		_jumping = false
		# (a step up or down leaves the ground for a frame; that is not a landing)
		if air_time > 0.1:
			landed.emit(maxf(fall_speed, 0.0))
		if fall_speed > hard_landing_speed:
			_stun = hard_landing_time
	elif now_grounded and _was_grounded and not stepped:
		_smooth_step_down(global_position.y - before.y, delta)
	_was_grounded = now_grounded
	air_time = 0.0 if now_grounded else air_time + delta

	# Hands are free and he is in the air: catch a rope, or a ledge he is falling past.
	if not now_grounded and state == State.FREE and carried == null and _grab_cooldown <= 0.0:
		if not _try_catch_rope() and velocity.y < 1.5:
			_try_catch_ledge()


func _process(delta: float) -> void:
	if is_limp:
		# The camera follows the body, wherever it tumbles.
		visual_position = _rig.limp_position() + Vector3.DOWN * 0.2
		return
	_visual_offset = _visual_offset.lerp(Vector3.ZERO, 1.0 - exp(-16.0 * delta))
	visual_position = _prev_pos.lerp(_curr_pos, Engine.get_physics_interpolation_fraction()) + _visual_offset

	var heading := _wish
	if state == State.HANG or state == State.CLIMB:
		heading = _ledge_direction
	elif state == State.SLIDE:
		heading = _slide_direction
	elif state == State.ROPE:
		# Left and right (as the camera sees them) choose which way he will leap off.
		heading = _rope_heading.normalized() if _rope_heading.length() > 0.3 else Vector3.ZERO
	elif heading.length_squared() < 0.01:
		heading = Vector3(velocity.x, 0.0, velocity.z)
		if heading.length_squared() < 0.25:
			heading = Vector3.ZERO
	if heading != Vector3.ZERO:
		facing_yaw = lerp_angle(facing_yaw, atan2(heading.x, heading.z), 1.0 - exp(-turn_rate * delta))

	_rig.global_position = visual_position
	_rig.rotation = Vector3(0.0, facing_yaw, 0.0)
	if carried:
		carried.global_position = _rig.hand_position()


func respawn() -> void:
	if is_limp:
		_rig.recover()
		is_limp = false
	_let_go()
	state = State.FREE
	is_ducking = false
	_set_height(stand_height)
	global_transform = _spawn
	velocity = Vector3.ZERO
	_stun = 0.0
	_jumping = false
	_reset_visuals()
	respawned.emit()


func _reset_visuals() -> void:
	_prev_pos = global_position
	_curr_pos = global_position
	_visual_offset = Vector3.ZERO
	visual_position = global_position
	_rig.global_position = global_position
	_rig.rotation = Vector3(0.0, facing_yaw, 0.0)


func _read_move_input() -> Vector2:
	var input := Input.get_vector(&"move_left", &"move_right", &"move_up", &"move_down")
	if Input.is_action_pressed(&"walk"):
		input *= run_threshold
	if _touch and _touch.move.length_squared() > input.length_squared():
		input = _touch.move
	return input


## Maps stick input onto the ground plane relative to the active camera.
func _to_world(input: Vector2) -> Vector3:
	var right := Vector3.RIGHT
	var forward := Vector3.FORWARD
	var camera := get_viewport().get_camera_3d()
	if camera:
		var view := camera.global_basis
		right = Vector3(view.x.x, 0.0, view.x.z).normalized()
		forward = Vector3(-view.z.x, 0.0, -view.z.z)
		# Looking straight down: the top of the screen is forward instead.
		if forward.length_squared() < 0.001:
			forward = Vector3(view.y.x, 0.0, view.y.z)
		forward = forward.normalized()
	var direction := right * input.x - forward * input.y
	if move_mode == MoveMode.SIDE_SCROLL:
		direction = Vector3(direction.x, 0.0, 0.0)
	return direction.limit_length(1.0)


func _move_horizontal(strength: float, grounded: bool, delta: float) -> void:
	var target_speed := 0.0
	if strength > 0.0:
		target_speed = lerpf(walk_speed, run_speed, smoothstep(run_threshold, run_threshold + 0.2, strength))
		if is_pushing:
			target_speed = minf(target_speed, push_speed)
		if is_ducking:
			target_speed = minf(target_speed, crouch_speed)
		if _stun > 0.0:
			target_speed *= 0.15
	var target := _wish.normalized() * target_speed

	var current := Vector3(velocity.x, 0.0, velocity.z)
	var rate := acceleration
	if not grounded:
		# Keep momentum in the air when the stick is let go.
		rate = air_acceleration if strength > 0.0 else air_acceleration * 0.25
	elif strength == 0.0 or _stun > 0.0:
		rate = deceleration
	elif current.dot(target) < 0.0:
		rate = turn_acceleration
	current = current.move_toward(target, rate * delta)
	velocity.x = current.x
	velocity.z = current.z

	if move_mode == MoveMode.SIDE_SCROLL:
		# Ease back onto the lane if something knocked us off it.
		velocity.z = (_spawn.origin.z - global_position.z) * 10.0


func _move_vertical(grounded: bool, delta: float) -> void:
	# No jumping out from under something too low to stand in.
	var can_rise := state == State.FREE and (not is_ducking or _has_headroom(stand_height))
	if _jump_buffer > 0.0 and _coyote > 0.0 and _stun <= 0.0 and can_rise:
		is_ducking = false
		_set_height(stand_height)
		velocity.y = _jump_velocity
		_jump_buffer = 0.0
		_coyote = 0.0
		_jumping = true
		jumped.emit()
	elif not grounded:
		var gravity := _gravity
		if velocity.y < 0.0:
			gravity *= fall_gravity_scale
		elif _jumping and not _is_jump_held():
			gravity *= jump_cut_gravity_scale
		velocity.y = maxf(velocity.y - gravity * delta, -max_fall_speed)


func _is_jump_held() -> bool:
	return Input.is_action_pressed(&"jump") or (_touch != null and _touch.jump_held)


func _is_duck_held() -> bool:
	return Input.is_action_pressed(&"duck") or (_touch != null and _touch.duck_held)


# --- Ducking and sliding ---

## Decides whether he is standing, ducked or starting a slide, and sizes the
## collider to match. He stays down under anything too low to stand in.
func _update_stance(grounded: bool) -> void:
	if state == State.SLIDE:
		return
	var duck := _is_duck_held()
	var speed := Vector2(velocity.x, velocity.z).length()
	if grounded and duck and not is_ducking and speed >= slide_min_speed and _stun <= 0.0:
		state = State.SLIDE
		_state_time = 0.0
		_slide_direction = Vector3(velocity.x, 0.0, velocity.z).normalized()
		_set_height(slide_height)
		return
	if is_ducking:
		is_ducking = (duck and grounded) or not _has_headroom(stand_height)
	else:
		is_ducking = duck and grounded
	if not is_ducking:
		_set_height(stand_height)
	elif _capsule.height > crouch_height or _has_headroom(crouch_height):
		_set_height(crouch_height)
	# (otherwise he is under something lower still, and stays slide-flat)


## Carried by momentum, low enough to pass under what a duck will not.
func _slide(grounded: bool, delta: float) -> void:
	var speed := Vector2(velocity.x, velocity.z).length() - slide_friction * delta
	if speed < slide_end_speed or is_on_wall() or (not grounded and _state_time > 0.15):
		state = State.FREE
		# Come up into a duck; the next step stands him if there is room.
		is_ducking = true
		return
	velocity.x = _slide_direction.x * speed
	velocity.z = _slide_direction.z * speed


func _set_height(height: float) -> void:
	if is_equal_approx(_capsule.height, height):
		return
	_capsule.height = height
	_collider.position.y = height * 0.5


## Whether the collider could be `height` tall here without hitting anything.
func _has_headroom(height: float) -> bool:
	if height <= _capsule.height:
		return true
	return not test_move(global_transform, Vector3.UP * (height - _capsule.height))


# --- Ledges ---

## Catches the top edge of whatever he is moving into, if it is within reach of
## his hands and there is room to stand on it.
func _try_catch_ledge() -> bool:
	if _wish.length_squared() < 0.04:
		return false
	var hit := KinematicCollision3D.new()
	if not test_move(global_transform, _wish.normalized() * 0.25, hit) or absf(hit.get_normal().y) > 0.3:
		return false
	var into := Vector3(-hit.get_normal().x, 0.0, -hit.get_normal().z).normalized()
	if _wish.normalized().dot(into) < 0.4:
		return false

	# Find the top, looking down from as high as he can reach just past the face.
	var at_face := global_position + hit.get_travel()
	var over := at_face + into * (_radius + 0.15)
	var query := PhysicsRayQueryParameters3D.create(
		Vector3(over.x, global_position.y + ledge_reach.y, over.z),
		Vector3(over.x, global_position.y + ledge_reach.x, over.z), 1)
	var top := get_world_3d().direct_space_state.intersect_ray(query)
	if top.is_empty() or (top.normal as Vector3).y < 0.7:
		return false
	var ledge_y: float = (top.position as Vector3).y
	var standing := Transform3D(Basis.IDENTITY, Vector3(over.x, ledge_y + 0.03, over.z))
	if test_move(standing, Vector3.UP * 0.01, null, 0.001, true):
		return false

	# Hang below it, but never lower than the ground allows.
	var drop := ledge_y - hang_height - at_face.y
	if drop < 0.0 and test_move(Transform3D(Basis.IDENTITY, at_face), Vector3(0.0, drop, 0.0), hit):
		drop = hit.get_travel().y
	var hang := at_face + Vector3(0.0, drop, 0.0)
	_visual_offset += global_position - hang
	global_position = hang
	velocity = Vector3.ZERO
	_ledge_top = Vector3(over.x, ledge_y, over.z)
	_ledge_direction = into
	_jumping = false
	_jump_buffer = 0.0
	state = State.HANG
	_state_time = 0.0
	return true


## Hanging: he stays there until jump climbs up, or pulling away (or duck) drops him.
func _hang() -> void:
	velocity = Vector3.ZERO
	var toward := _wish.dot(_ledge_direction)
	if _jump_buffer > 0.0:
		_jump_buffer = 0.0
		_climb_from = global_position
		climb_progress = 0.0
		state = State.CLIMB
		_state_time = 0.0
	elif (_is_duck_held() or toward < -0.4) and _state_time > 0.15:
		state = State.FREE
		_grab_cooldown = 0.5


## Pulling up: first straight up the face, then forward onto the top.
func _climb() -> void:
	climb_progress = clampf(_state_time / climb_time, 0.0, 1.0)
	var rise := smoothstep(0.0, 0.6, climb_progress)
	var reach := smoothstep(0.58, 1.0, climb_progress)
	global_position = Vector3(
		lerpf(_climb_from.x, _ledge_top.x, reach),
		lerpf(_climb_from.y, _ledge_top.y + 0.02, rise),
		lerpf(_climb_from.z, _ledge_top.z, reach))
	if climb_progress >= 1.0:
		velocity = Vector3.ZERO
		state = State.FREE
		_was_grounded = true
		_coyote = coyote_time


# --- Ropes ---

func _try_catch_rope() -> bool:
	var chest := global_position + Vector3.UP * 1.0
	for rope: Rope in get_tree().get_nodes_in_group(&"ropes"):
		if rope.distance_to(chest) < 0.4 and chest.y > rope.bottom_y() - 0.2 and chest.y < rope.top_y():
			_rope = rope
			_rope_hand_y = clampf(global_position.y + hang_height, rope.bottom_y() + 0.3, rope.top_y() - 0.1)
			rope_travel = 0.0
			velocity = Vector3.ZERO
			_jumping = false
			_jump_buffer = 0.0
			state = State.ROPE
			_state_time = 0.0
			return true
	return false


## On a rope: up and down climb it, jump leaps off the way he faces, duck lets go.
func _climb_rope(input: Vector2, delta: float) -> void:
	var facing := Vector3(sin(facing_yaw), 0.0, cos(facing_yaw))
	if _jump_buffer > 0.0:
		_jump_buffer = 0.0
		velocity = facing * run_speed + Vector3.UP * _jump_velocity * 0.85
		_jumping = true
		_leave_rope()
		jumped.emit()
		return
	if _is_duck_held() and _state_time > 0.15:
		_leave_rope()
		return
	_rope_heading = _to_world(Vector2(input.x, 0.0))
	var step := -input.y * rope_speed * delta
	var hand_y := clampf(_rope_hand_y + step, _rope.bottom_y() + 0.3, _rope.top_y() - 0.1)
	rope_travel += hand_y - _rope_hand_y
	_rope_hand_y = hand_y
	velocity = Vector3.ZERO
	# He hangs just behind the rope, with it in front of his chest.
	var hold := _rope.global_position - facing * 0.16
	var target := Vector3(hold.x, _rope_hand_y - hang_height, hold.z)
	_visual_offset += global_position - target
	global_position = target


func _leave_rope() -> void:
	_rope = null
	state = State.FREE
	_grab_cooldown = 0.5


# --- Carrying and throwing ---

## The act button: pick up what is at his feet, or throw what he holds.
func _act() -> void:
	if is_limp or state != State.FREE:
		return
	if carried:
		_throw()
		return
	var nearest := pickup_reach
	var found: RigidBody3D
	for body: RigidBody3D in get_tree().get_nodes_in_group(&"throwable"):
		var distance := body.global_position.distance_to(global_position + Vector3.UP * 0.4)
		if distance < nearest:
			nearest = distance
			found = body
	if found:
		carried = found
		_carried_layers = Vector2i(found.collision_layer, found.collision_mask)
		found.freeze = true
		found.collision_layer = 0
		found.collision_mask = 0


func _throw() -> void:
	var facing := Vector3(sin(facing_yaw), 0.0, cos(facing_yaw))
	var thrown := carried
	_let_go()
	thrown.linear_velocity = facing * throw_speed.x + Vector3.UP * throw_speed.y + Vector3(velocity.x, 0.0, velocity.z) * 0.5
	thrown.angular_velocity = Vector3(randf_range(-4.0, 4.0), randf_range(-4.0, 4.0), randf_range(-4.0, 4.0))
	threw.emit()


## Releases whatever is held, where it is.
func _let_go() -> void:
	if carried == null:
		return
	carried.collision_layer = _carried_layers.x
	carried.collision_mask = _carried_layers.y
	carried.freeze = false
	carried.linear_velocity = Vector3.ZERO
	carried = null


# --- Steps and pushing ---

## Lifts the body onto a low ledge it is walking into. Returns true if it moved.
func _try_step_up(delta: float) -> bool:
	if _wish.length_squared() < 0.01:
		return false
	var wish_dir := _wish.normalized()
	var speed := Vector2(velocity.x, velocity.z).length()
	var motion := wish_dir * maxf(speed * delta, 0.02)
	var hit := KinematicCollision3D.new()

	var from := global_transform
	if not test_move(from, motion, hit):
		return false
	var normal := hit.get_normal()
	if normal.y >= cos(floor_max_angle):
		# That was the floor grazing the capsule; look again from just above it.
		if not test_move(from.translated(Vector3.UP * 0.03), motion, hit):
			return false
		normal = hit.get_normal()
		if normal.y >= cos(floor_max_angle):
			return false
	var into := Vector3(-normal.x, 0.0, -normal.z).normalized()
	if wish_dir.dot(into) < 0.35:
		return false

	var up := Vector3.UP * max_step_height
	if test_move(from, up):
		return false
	# Far enough that the capsule's centre clears the edge and rests on the tread.
	var forward := into * (hit.get_travel().dot(into) + _radius + 0.03)
	var raised := from.translated(up)
	if test_move(raised, forward):
		return false
	var over := raised.translated(forward)
	if not test_move(over, -up, hit):
		return false
	if hit.get_normal().y < cos(floor_max_angle):
		return false
	var landing := over.origin + hit.get_travel()
	if landing.y - from.origin.y < 0.02:
		return false

	_visual_offset += global_position - landing
	global_position = landing
	return true


## Floor snapping drops the body instantly on stairs; hide that from the rig.
func _smooth_step_down(moved_y: float, delta: float) -> void:
	var normal := get_floor_normal()
	var slope_y := -(velocity.x * normal.x + velocity.z * normal.z) / maxf(normal.y, 0.1) * delta
	var drop := moved_y - slope_y
	if drop < -0.03:
		_visual_offset.y = minf(_visual_offset.y - drop, max_step_height)


func _push_bodies(delta: float) -> void:
	for i in get_slide_collision_count():
		var collision := get_slide_collision(i)
		var body := collision.get_collider() as RigidBody3D
		if body == null:
			continue
		var normal := collision.get_normal()
		if absf(normal.y) > 0.5:
			continue
		var direction := Vector3(-normal.x, 0.0, -normal.z).normalized()
		if _wish.dot(direction) < 0.3:
			continue
		_push_timer = 0.2
		var body_speed := body.linear_velocity.dot(direction)
		var impulse := clampf((push_speed - body_speed) * body.mass, 0.0, push_force * delta)
		body.apply_central_impulse(direction * impulse)
		# The slide zeroed our speed against the body; match it instead so we
		# stay in contact and push steadily rather than in bumps.
		var matched := clampf(body_speed + impulse / body.mass, 0.0, push_speed)
		var flat := Vector3(velocity.x, 0.0, velocity.z)
		flat += direction * (matched - flat.dot(direction))
		velocity.x = flat.x
		velocity.z = flat.z
		return


static func _ensure_input_actions() -> void:
	_add_action(&"move_left", [KEY_A, KEY_LEFT], JOY_AXIS_LEFT_X, -1.0)
	_add_action(&"move_right", [KEY_D, KEY_RIGHT], JOY_AXIS_LEFT_X, 1.0)
	_add_action(&"move_up", [KEY_W, KEY_UP], JOY_AXIS_LEFT_Y, -1.0)
	_add_action(&"move_down", [KEY_S, KEY_DOWN], JOY_AXIS_LEFT_Y, 1.0)
	_add_action(&"walk", [KEY_SHIFT])
	_add_action(&"jump", [KEY_SPACE], JOY_AXIS_INVALID, 0.0, JOY_BUTTON_A)
	_add_action(&"duck", [KEY_C, KEY_CTRL], JOY_AXIS_INVALID, 0.0, JOY_BUTTON_B)
	_add_action(&"act", [KEY_E, KEY_F], JOY_AXIS_INVALID, 0.0, JOY_BUTTON_X)
	_add_action(&"ragdoll", [KEY_R])


static func _add_action(action: StringName, keys: Array[Key], axis := JOY_AXIS_INVALID, axis_value := 0.0, button := JOY_BUTTON_INVALID) -> void:
	if InputMap.has_action(action):
		return
	InputMap.add_action(action, 0.2)
	for key in keys:
		var event := InputEventKey.new()
		event.physical_keycode = key
		InputMap.action_add_event(action, event)
	if axis != JOY_AXIS_INVALID:
		var motion := InputEventJoypadMotion.new()
		motion.axis = axis
		motion.axis_value = axis_value
		InputMap.action_add_event(action, motion)
	if button != JOY_BUTTON_INVALID:
		var press := InputEventJoypadButton.new()
		press.button_index = button
		InputMap.action_add_event(action, press)


# --- Ragdoll and checkpoints ---

## Drops the body as a ragdoll, carrying its current motion plus `impulse`
## (newton-seconds, applied to the chest). Input is ignored until `recover`
## or `respawn`.
func ragdoll(impulse := Vector3.ZERO) -> void:
	if is_limp:
		return
	_let_go()
	state = State.FREE
	_rope = null
	is_limp = true
	_rig.go_limp(velocity, impulse)
	velocity = Vector3.ZERO


## Stands the body back up where it came to rest.
func recover() -> void:
	if not is_limp:
		return
	global_position = _rig.limp_position() + Vector3.UP * 0.05
	_rig.recover()
	is_limp = false
	_was_grounded = false
	_reset_visuals()


## Makes `at` the place `respawn` returns to (a checkpoint).
func set_spawn(at: Vector3) -> void:
	_spawn = Transform3D(Basis.IDENTITY, at)


# --- Hands ---

## Remembers the upright surface he is pressing into, if any: a wall he has
## walked up to, or a block he is pushing.
func _note_lean() -> void:
	if not is_on_floor() or is_ducking or state != State.FREE or _wish.length_squared() < 0.04:
		return
	for i in get_slide_collision_count():
		var collision := get_slide_collision(i)
		var normal := collision.get_normal()
		if absf(normal.y) < 0.3 and _wish.normalized().dot(-normal) > 0.5:
			_lean_point = collision.get_position()
			_lean_normal = normal
			_lean_timer = 0.15
			return


## Works out where his hands go: on the ledge he hangs from, the rope he is on,
## or flat against what he is leaning into.
func _place_hands(delta: float) -> void:
	_lean_timer -= delta
	_lean_held = _lean_held + delta if _lean_timer > 0.0 else 0.0
	hand_reach = 0.0
	var facing := Vector3(sin(facing_yaw), 0.0, cos(facing_yaw))
	if state == State.HANG or (state == State.CLIMB and climb_progress < 0.86):
		# Over the lip, a shoulder's width apart
		var lip := _ledge_top - _ledge_direction * (_radius + 0.09) + Vector3.UP * 0.02
		var along := Vector3(_ledge_direction.z, 0.0, -_ledge_direction.x)
		hand_points[0] = lip + along * 0.14
		hand_points[1] = lip - along * 0.14
		hand_reach = 1.0
	elif state == State.ROPE:
		# One above the other, swapping as he climbs
		var shift := sin(rope_travel * 5.0) * 0.1
		hand_points[0] = Vector3(_rope.global_position.x, _rope_hand_y + shift, _rope.global_position.z)
		hand_points[1] = Vector3(_rope.global_position.x, _rope_hand_y - shift, _rope.global_position.z)
		hand_reach = 1.0
	elif state == State.FREE and _lean_held > 0.15:
		# Each hand goes where a line straight ahead from the shoulder meets the
		# surface. Anything too low for both hands (a step, a kerb) is not leant on.
		var left := Vector3(facing.z, 0.0, -facing.x)
		var space := get_world_3d().direct_space_state
		var found := PackedVector3Array()
		for i in 2:
			var from := global_position + Vector3.UP * (stand_height * 0.6) + left * (0.13 if i == 0 else -0.13)
			var hit := space.intersect_ray(PhysicsRayQueryParameters3D.create(from, from - _lean_normal * 0.65, 1))
			if hit.is_empty():
				return
			found.append((hit.position as Vector3) + (hit.normal as Vector3) * 0.015)
		hand_points = found
		hand_reach = 1.0
