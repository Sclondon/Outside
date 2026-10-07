class_name Player
extends CharacterBody3D
## Character controller tuned for touch.
##
## Simulation runs in the physics step; the visible rig is detached and follows an
## interpolated position, so motion stays smooth on any refresh rate.

signal jumped
signal landed(impact_speed: float)
signal respawned

enum MoveMode {
	FREE, ## Camera-relative movement on the whole ground plane.
	SIDE_SCROLL, ## Movement along world X only, like Inside.
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

@export_group("Feel")
## Landing faster than this makes the character stumble.
@export var hard_landing_speed := 11.0
@export var hard_landing_time := 0.4
@export var push_force := 500.0
@export var kill_height := -15.0

## Heading of the model, radians around Y. Zero faces +Z.
var facing_yaw := PI * 0.5
var is_pushing := false
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

@onready var _rig: Node3D = $Rig
@onready var _radius: float = ($Collision.shape as CapsuleShape3D).radius


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
	_reset_visuals()
	_connect_touch.call_deferred()


func _connect_touch() -> void:
	_touch = get_tree().get_first_node_in_group(&"touch_controls") as TouchControls
	if _touch:
		_touch.jump_pressed.connect(_queue_jump)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed(&"jump"):
		_queue_jump()


func _queue_jump() -> void:
	_jump_buffer = jump_buffer_time


func _physics_process(delta: float) -> void:
	var input := _read_move_input()
	var strength := minf(input.length(), 1.0)
	_wish = _to_world(input)

	var grounded := is_on_floor()
	_coyote = coyote_time if grounded else _coyote - delta
	_jump_buffer -= delta
	_stun -= delta
	_push_timer -= delta
	is_pushing = _push_timer > 0.0

	_move_horizontal(strength, grounded, delta)
	_move_vertical(grounded, delta)

	var fall_speed := -velocity.y
	var before := global_position
	var stepped := grounded and velocity.y <= 0.0 and _try_step_up(delta)
	move_and_slide()
	_push_bodies(delta)

	var now_grounded := is_on_floor()
	if now_grounded and not _was_grounded:
		_jumping = false
		landed.emit(maxf(fall_speed, 0.0))
		if fall_speed > hard_landing_speed:
			_stun = hard_landing_time
	elif now_grounded and _was_grounded and not stepped:
		_smooth_step_down(global_position.y - before.y, delta)
	_was_grounded = now_grounded

	if global_position.y < kill_height:
		respawn()
	_prev_pos = _curr_pos
	_curr_pos = global_position


func _process(delta: float) -> void:
	_visual_offset = _visual_offset.lerp(Vector3.ZERO, 1.0 - exp(-16.0 * delta))
	visual_position = _prev_pos.lerp(_curr_pos, Engine.get_physics_interpolation_fraction()) + _visual_offset

	var heading := _wish
	if heading.length_squared() < 0.01:
		heading = Vector3(velocity.x, 0.0, velocity.z)
		if heading.length_squared() < 0.25:
			heading = Vector3.ZERO
	if heading != Vector3.ZERO:
		facing_yaw = lerp_angle(facing_yaw, atan2(heading.x, heading.z), 1.0 - exp(-turn_rate * delta))

	_rig.global_position = visual_position
	_rig.rotation = Vector3(0.0, facing_yaw, 0.0)


func respawn() -> void:
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
	if _jump_buffer > 0.0 and _coyote > 0.0 and _stun <= 0.0:
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
	_add_action(&"jump", [KEY_SPACE])
	if not InputMap.action_get_events(&"jump").any(func(e: InputEvent) -> bool: return e is InputEventJoypadButton):
		var button := InputEventJoypadButton.new()
		button.button_index = JOY_BUTTON_A
		InputMap.action_add_event(&"jump", button)


static func _add_action(action: StringName, keys: Array[Key], axis := JOY_AXIS_INVALID, axis_value := 0.0) -> void:
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
