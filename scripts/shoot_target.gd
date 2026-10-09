class_name ShootTarget
extends StaticBody3D
## A target for a range. Two kinds, both scenes in `guns/`:
##
## - `target_board` (`FALLS`): a painted board on a post hinged at its foot.
##   Shot, it goes over, away from the shot, lies there, and stands up again;
## - `target_gong` (`SWINGS`): an iron plate hung from a frame. Shot, it rings
##   and swings, and swings the harder the more it is hit with.
##
## The part that moves is the model's `Board`, which turns about the X of the
## node `Hinge` (a body of its own, carrying the board's collision). It takes
## `shot` and `struck` as anything shot does (`scripts/gun.gd`).

## It was hit. `score` is 0 at the edge of the board to 1 in the middle.
signal hit(by: Node3D, at: Vector3, score: float)
## A falling board went down; it is up again.
signal fell
signal rose

enum Kind { FALLS, SWINGS }

@export var kind := Kind.FALLS
## How much it takes to knock a falling board over (see `shot` in `scripts/gun.gd`).
@export var toughness := 10.0
## How long it lies there before it stands up, in seconds (0: until `stand()`).
@export var stays_down := 3.0
## How far out from the `Middle` marker still counts, in metres.
@export var radius := 0.25
## What it is made of, for the look and the sound of hitting it.
@export var made_of: StringName = &"wood"

var is_down := false
## How many times it has been hit.
var hits := 0

var _hinge: AnimatableBody3D
var _board: Node3D
var _board_rest := Transform3D.IDENTITY
var _angle := 0.0
var _speed := 0.0
var _down_for := 0.0
var _side := 1.0


func _ready() -> void:
	add_to_group(&"interest")
	add_to_group(&"targets")
	set_meta(&"surface", made_of)
	_hinge = get_node_or_null(^"Hinge") as AnimatableBody3D
	if _hinge:
		_hinge.sync_to_physics = false
		_hinge.set_meta(&"surface", made_of)
	var model := get_node_or_null(^"Model")
	if model:
		Gun.dress(model)
		_board = model.get_node_or_null(^"Board")
		if _board:
			_board_rest = _board.transform


## It has been shot (the contract in `scripts/gun.gd`).
func shot(by: Node3D, at: Vector3, direction: Vector3, damage: float) -> void:
	_take(by, at, direction, damage)


## It has been punched or kicked.
func struck(by: Node3D, impulse: Vector3) -> void:
	_take(by, global_position + Vector3.UP, impulse.normalized(), impulse.length() * 4.0)


## Stands a fallen board up again.
func stand() -> void:
	if is_down:
		is_down = false
		_down_for = 0.0
		rose.emit()


func _take(by: Node3D, at: Vector3, direction: Vector3, damage: float) -> void:
	hits += 1
	var middle := get_node_or_null(^"Hinge/Middle") as Node3D
	var score := clampf(1.0 - at.distance_to(middle.global_position) / radius, 0.0, 1.0) if middle else 0.0
	# Which way it is pushed: about the hinge's X, by what comes along the hinge's Z.
	var push := direction.dot(global_basis.z)
	hit.emit(by, at, score)
	if kind == Kind.SWINGS:
		_speed = clampf(_speed - clampf(push * damage * 0.05, -3.0, 3.0), -4.2, 4.2)
	elif not is_down and damage >= toughness:
		is_down = true
		_side = 1.0 if push >= 0.0 else -1.0
		_speed = _side * 5.0
		_down_for = 0.0
		fell.emit()


func _physics_process(delta: float) -> void:
	if _hinge == null:
		return
	if kind == Kind.SWINGS:
		# A pendulum, about half a metre long, that loses its swing slowly.
		_speed += (-18.0 * sin(_angle) - 0.9 * _speed) * delta
		_angle += _speed * delta
	elif is_down:
		# Over it goes, and bounces once on the ground.
		var flat := _side * deg_to_rad(84.0)
		_speed += _side * 26.0 * delta
		_angle += _speed * delta
		if _angle * _side > absf(flat):
			_angle = flat
			_speed = -_speed * 0.3 if absf(_speed) > 2.0 else 0.0
		_down_for += delta
		if stays_down > 0.0 and _down_for >= stays_down:
			stand()
	else:
		_angle = move_toward(_angle, 0.0, delta * 2.4)
		_speed = 0.0
	if absf(_hinge.rotation.x - _angle) > 0.00001:
		_hinge.rotation.x = _angle
		if _board:
			_board.transform = _board_rest * Transform3D(Basis(Vector3.RIGHT, _angle), Vector3.ZERO)
