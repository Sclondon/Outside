class_name FollowCamera
extends Camera3D
## The game camera, in one of two modes.
##
## SIDE: a fixed-angle side view, as in Inside. It leads the player slightly
## and ignores the vertical bounce of a jump; nothing needs steering.
##
## ORBIT: a third-person camera for open areas. Drag (the upper right of the
## screen, the right mouse button, or a right stick) turns it; left alone it
## drifts round behind the way he is going, and it pulls in rather than pass
## through a wall.

enum Mode { SIDE, ORBIT }

@export var target: Player
@export var mode := Mode.SIDE

@export_group("Side")
## Camera position relative to the point it is watching.
@export var offset := Vector3(0.0, 1.7, 11.0)
@export var look_height := 0.85
## How far ahead of a running player the camera looks, in metres.
@export var look_ahead := 1.3
@export var follow_speed := 5.0
@export var vertical_speed := 3.0
## While airborne the camera only moves vertically beyond this distance.
@export var vertical_dead_zone := 0.9
## How much of the player's movement towards or away from the camera is followed.
@export_range(0.0, 1.0) var depth_follow := 0.5

@export_group("Orbit")
@export var distance := 6.0
@export var orbit_fov := 55.0
## Radians turned per pixel dragged, and per second at full stick.
@export var drag_sensitivity := 0.006
@export var stick_speed := 2.4
@export var pitch_limits := Vector2(-0.25, 1.2)
## How quickly it drifts round behind him when left alone, 0 for never.
@export var settle_speed := 0.9

var _focus := Vector3.ZERO
var _ahead := Vector3.ZERO
var _lane_z := 0.0
var _yaw := -PI * 0.5 + 0.6
var _pitch := 0.4
var _reach := 6.0
var _since_look := 10.0
var _touch: TouchControls


func _ready() -> void:
	# Run after the player has updated its visual position for this frame.
	process_priority = 100
	_add_stick_actions()
	if mode == Mode.ORBIT:
		fov = orbit_fov
		_reach = distance
	if target:
		_lane_z = target.global_position.z
		target.respawned.connect(snap)
		snap()
	_find_touch.call_deferred()


func _find_touch() -> void:
	_touch = get_tree().get_first_node_in_group(&"touch_controls") as TouchControls
	if _touch:
		_touch.look_enabled = mode == Mode.ORBIT


func snap() -> void:
	_focus = target.global_position
	_ahead = Vector3.ZERO
	_apply()


func _unhandled_input(event: InputEvent) -> void:
	if mode == Mode.ORBIT and event is InputEventMouseMotion and event.button_mask & MOUSE_BUTTON_MASK_RIGHT:
		_turn(event.relative * drag_sensitivity)


func _process(delta: float) -> void:
	if target == null:
		return
	if mode == Mode.ORBIT:
		_orbit(delta)
	else:
		_follow_side(delta)
	_apply()


func _follow_side(delta: float) -> void:
	var player := target.visual_position
	var flat := Vector3(target.velocity.x, 0.0, target.velocity.z)
	_ahead = _ahead.lerp(flat / maxf(target.run_speed, 0.01) * look_ahead, 1.0 - exp(-1.6 * delta))

	var blend := 1.0 - exp(-follow_speed * delta)
	_focus.x = lerpf(_focus.x, player.x + _ahead.x, blend)
	_focus.z = lerpf(_focus.z, _lane_z + (player.z - _lane_z) * depth_follow, blend)

	var rise := player.y - _focus.y
	if target.is_on_floor():
		_focus.y = lerpf(_focus.y, player.y, 1.0 - exp(-vertical_speed * delta))
	elif absf(rise) > vertical_dead_zone:
		_focus.y = lerpf(_focus.y, player.y - signf(rise) * vertical_dead_zone, blend)


func _orbit(delta: float) -> void:
	if _touch:
		_turn(_touch.take_look() * drag_sensitivity)
	var stick := Input.get_vector(&"look_left", &"look_right", &"look_up", &"look_down")
	if stick.length_squared() > 0.0:
		_turn(stick * stick_speed * delta)
	_since_look += delta

	# Left alone while he is on the move, drift round behind him.
	var flat := Vector3(target.velocity.x, 0.0, target.velocity.z)
	if settle_speed > 0.0 and _since_look > 1.5 and flat.length() > 1.0:
		var behind := atan2(-flat.x, -flat.z)
		_yaw = lerp_angle(_yaw, behind, 1.0 - exp(-settle_speed * delta))

	var player := target.visual_position
	_focus = _focus.lerp(player, 1.0 - exp(-10.0 * delta))


func _turn(by: Vector2) -> void:
	if by == Vector2.ZERO:
		return
	_yaw -= by.x
	_pitch = clampf(_pitch + by.y, pitch_limits.x, pitch_limits.y)
	_since_look = 0.0


func _apply() -> void:
	if mode == Mode.SIDE:
		global_position = _focus + offset
		look_at(_focus + Vector3.UP * look_height)
		return
	var watch := _focus + Vector3.UP * 0.9
	var away := Vector3(sin(_yaw) * cos(_pitch), sin(_pitch), cos(_yaw) * cos(_pitch))
	# Come in close rather than sit behind a wall.
	var wanted := distance
	var hit := get_world_3d().direct_space_state.intersect_ray(
		PhysicsRayQueryParameters3D.create(watch, watch + away * (distance + 0.3), 1))
	if not hit.is_empty():
		wanted = maxf(watch.distance_to(hit.position) - 0.3, 0.8)
	# In at once, back out gently.
	_reach = wanted if wanted < _reach else lerpf(_reach, wanted, 1.0 - exp(-4.0 * get_process_delta_time()))
	global_position = watch + away * _reach
	look_at(watch)


static func _add_stick_actions() -> void:
	for entry: Array in [[&"look_left", JOY_AXIS_RIGHT_X, -1.0], [&"look_right", JOY_AXIS_RIGHT_X, 1.0],
			[&"look_up", JOY_AXIS_RIGHT_Y, -1.0], [&"look_down", JOY_AXIS_RIGHT_Y, 1.0]]:
		if InputMap.has_action(entry[0]):
			continue
		InputMap.add_action(entry[0], 0.2)
		var motion := InputEventJoypadMotion.new()
		motion.axis = entry[1]
		motion.axis_value = entry[2]
		InputMap.action_add_event(entry[0], motion)
