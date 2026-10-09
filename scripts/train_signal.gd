class_name TrainSignal
extends Prop
## A semaphore signal (`props/signal_semaphore.tscn`): a prop whose arm moves.
## Level, it is at danger; `clear` drops it to show the line is clear, as the
## lower-quadrant signals of the time did, and brings the green glass in front
## of the lamp. The arm falls, and bounces once as it comes to rest.

## Whether the line is clear.
@export var clear := false
## How far the arm drops, degrees.
@export var drop := 50.0

var _arm: Node3D
var _angle := 0.0
var _rate := 0.0


func _ready() -> void:
	super._ready()
	_arm = get_node_or_null(^"Model/Arm")
	_angle = deg_to_rad(drop) if clear else 0.0
	_show()


func _process(delta: float) -> void:
	if _arm == null:
		return
	var wanted := deg_to_rad(drop) if clear else 0.0
	if is_equal_approx(_angle, wanted) and absf(_rate) < 0.01:
		return
	# (a spring, a little under-damped: it arrives, goes a touch past and settles)
	_rate += ((wanted - _angle) * 60.0 - _rate * 9.0) * delta
	_angle += _rate * delta
	if absf(wanted - _angle) < 0.002 and absf(_rate) < 0.02:
		_angle = wanted
		_rate = 0.0
	_show()


func _show() -> void:
	if _arm:
		_arm.rotation.z = -_angle
