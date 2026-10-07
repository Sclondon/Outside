class_name FollowCamera
extends Camera3D
## Fixed-angle side camera. It leads the player slightly and ignores the
## vertical bounce of a jump, so nothing needs steering with a second thumb.

@export var target: Player
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

var _focus := Vector3.ZERO
var _ahead := Vector3.ZERO
var _lane_z := 0.0


func _ready() -> void:
	# Run after the player has updated its visual position for this frame.
	process_priority = 100
	if target:
		_lane_z = target.global_position.z
		target.respawned.connect(snap)
		snap()


func snap() -> void:
	_focus = target.global_position
	_ahead = Vector3.ZERO
	_apply()


func _process(delta: float) -> void:
	if target == null:
		return
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
	_apply()


func _apply() -> void:
	global_position = _focus + offset
	look_at(_focus + Vector3.UP * look_height)
