class_name Lever
extends StaticBody3D
## A lever in a block of stone: he pulls it over with the act button, standing
## at it with his hands empty (it is in the group `workable`, which is how he
## knows: see `Player._act`). It is either on or off (`changed`), and so works
## a door, a bridge, or anything else a pressure plate works. Pulled again it
## goes back; or, with `returns`, it creeps back by itself and is off again
## after that many seconds. Its foot is at this node and it is pulled over
## towards the node's +Z. `Lever.new()` is a whole one.

signal changed(on: bool)

## How far over the arm leans, either way (radians).
const LEAN := 0.62

## Whether it is pulled over.
@export var on := false
## Springs back after this many seconds (0: it stays where it is put).
@export var returns := 0.0

## How long until it is off again, seconds (while it is springing back).
var left := 0.0

var _arm: Node3D
var _starts_on := false


func _ready() -> void:
	add_to_group(&"interest")
	add_to_group(&"workable")
	set_meta(&"surface", "stone")
	_starts_on = on
	PuzzleKit.shape(self, Vector3(0.0, 0.16, 0.0), Vector3(0.5, 0.32, 0.6))
	PuzzleKit.box(self, Vector3(0.0, 0.16, 0.0), Vector3(0.5, 0.32, 0.6), PuzzleKit.stone())
	PuzzleKit.box(self, Vector3(0.0, 0.03, 0.0), Vector3(0.62, 0.06, 0.72), PuzzleKit.stone(PuzzleKit.DARK))
	# The slot the arm moves in, and the pin it turns on between two cheeks of bronze.
	PuzzleKit.box(self, Vector3(0.0, 0.322, 0.0), Vector3(0.09, 0.01, 0.46), PuzzleKit.stone(PuzzleKit.HOLLOW))
	for x: float in [-0.085, 0.085]:
		PuzzleKit.box(self, Vector3(x, 0.38, 0.0), Vector3(0.035, 0.14, 0.16), PuzzleKit.bronze())
	var pin := PuzzleKit.rod(self, Vector3(0.0, 0.4, 0.0), 0.025, 0.24, PuzzleKit.iron(), -1.0, 6)
	pin.rotation.z = PI * 0.5
	_arm = Node3D.new()
	_arm.position.y = 0.4
	add_child(_arm)
	PuzzleKit.rod(_arm, Vector3(0.0, 0.34, 0.0), 0.026, 0.72, PuzzleKit.wood(), 0.02, 7)
	PuzzleKit.rod(_arm, Vector3(0.0, 0.62, 0.0), 0.034, 0.05, PuzzleKit.bronze(), -1.0, 8)
	PuzzleKit.ball(_arm, Vector3(0.0, 0.72, 0.0), 0.055, PuzzleKit.bronze())
	left = returns if on and returns > 0.0 else 0.0
	_arm.rotation.x = _lean()


## Pulled: by him, with the act button.
func work(_by: Node3D = null) -> void:
	if returns > 0.0:
		# (pulled again while it creeps back, it has its whole time again)
		left = returns
		_switch(true)
	else:
		_switch(not on)


## Where his hand goes to pull it.
func work_point() -> Vector3:
	return _arm.global_transform * Vector3(0.0, 0.72, 0.0)


## As it was when it was made.
func reset() -> void:
	left = returns if _starts_on and returns > 0.0 else 0.0
	_switch(_starts_on)


func _switch(to: bool) -> void:
	if to == on:
		return
	on = to
	changed.emit(on)


func _physics_process(delta: float) -> void:
	if on and returns > 0.0:
		left = maxf(left - delta, 0.0)
		if left <= 0.0:
			_switch(false)
	# It is thrown over smartly, and creeps back as its time runs out.
	_arm.rotation.x = move_toward(_arm.rotation.x, _lean(), delta * 5.0)


func _lean() -> float:
	if on and returns > 0.0:
		return lerpf(-LEAN, LEAN, left / returns)
	return LEAN if on else -LEAN
