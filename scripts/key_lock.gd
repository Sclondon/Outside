class_name KeyLock
extends StaticBody3D
## A lock, on a post of stone: a plate of iron, bronze or gold with a keyhole
## in it. When the `DoorKey` of the same metal (`which`) is brought to it (in
## his hand, or put down or thrown at its foot) the key goes into it and is
## turned, and from then on the lock is on (`changed`): so it works a door, or
## anything else a pressure plate works, and that is a locked door. It stays
## open for good. Its foot is at this node and its keyhole faces +Z.
## `KeyLock.new()` is a whole one.

signal changed(on: bool)

## How near the keyhole its key must be brought.
const WITHIN := 1.1
## How high the keyhole is.
const HOLE := 0.95

## Which key opens it.
@export var which := DoorKey.Metal.IRON
## Whether it has been opened.
@export var on := false

## The key that is in it, if one is.
var key: DoorKey

var _turn := 0.0
var _from := Transform3D.IDENTITY
var _starts_on := false


func _ready() -> void:
	add_to_group(&"interest")
	set_meta(&"surface", "stone")
	_starts_on = on
	PuzzleKit.shape(self, Vector3(0.0, 0.65, 0.0), Vector3(0.44, 1.3, 0.34))
	PuzzleKit.box(self, Vector3(0.0, 0.6, 0.0), Vector3(0.4, 1.2, 0.3), PuzzleKit.stone())
	PuzzleKit.box(self, Vector3(0.0, 0.05, 0.0), Vector3(0.52, 0.1, 0.42), PuzzleKit.stone(PuzzleKit.DARK))
	PuzzleKit.box(self, Vector3(0.0, 1.25, 0.0), Vector3(0.48, 0.1, 0.38), PuzzleKit.stone(PuzzleKit.DARK))
	# The plate, four studs, and the keyhole: round, with a slot under it.
	var made_of := DoorKey.metal(which)
	PuzzleKit.box(self, Vector3(0.0, HOLE, 0.155), Vector3(0.28, 0.36, 0.03), made_of)
	for corner: Vector2 in [Vector2(-1, -1), Vector2(1, -1), Vector2(1, 1), Vector2(-1, 1)]:
		PuzzleKit.ball(self, Vector3(corner.x * 0.105, HOLE + corner.y * 0.145, 0.17), 0.018, made_of)
	var hole := PuzzleKit.rod(self, Vector3(0.0, HOLE + 0.02, 0.171), 0.032, 0.004, PuzzleKit.stone(PuzzleKit.HOLLOW), -1.0, 10)
	hole.rotation.x = PI * 0.5
	PuzzleKit.box(self, Vector3(0.0, HOLE - 0.04, 0.171), Vector3(0.026, 0.09, 0.004), PuzzleKit.stone(PuzzleKit.HOLLOW))


## Where the keyhole is, in the world.
func hole() -> Vector3:
	return global_transform * Vector3(0.0, HOLE + 0.02, 0.16)


## As it was when it was made: shut, and its key back where that was put.
func reset() -> void:
	if key and is_instance_valid(key):
		key.taken_into(null)
		key.go_home()
	key = null
	_turn = 0.0
	if on != _starts_on:
		on = _starts_on
		changed.emit(on)


func _exit_tree() -> void:
	# (taken out of the level with a key in it: the key is let fall)
	if key and is_instance_valid(key):
		key.taken_into(null)
	key = null


func _physics_process(delta: float) -> void:
	if key and not is_instance_valid(key):
		key = null
	if key == null and not on:
		_look_for_key()
	if key == null or _turn >= 1.0:
		return
	# It goes into the hole, and is turned a quarter.
	_turn = minf(_turn + delta / 0.7, 1.0)
	var come := smoothstep(0.0, 0.5, _turn)
	var turned := smoothstep(0.5, 1.0, _turn)
	var seat := Transform3D(global_basis.orthonormalized() * Basis(Vector3.UP, PI) * Basis(Vector3.BACK, turned * PI * 0.5), hole())
	key.global_transform = _from.interpolate_with(seat, come)
	if _turn >= 1.0 and not on:
		on = true
		changed.emit(true)


func _look_for_key() -> void:
	var player := Nearby.player(get_tree())
	for found: Node in get_tree().get_nodes_in_group(&"keys"):
		var near := found as DoorKey
		if near == null or near.which != which or near.held_by or near.global_position.distance_to(hole()) > WITHIN:
			continue
		if player and player.carried == near:
			# (it is taken out of his hand)
			player.let_go()
		elif near.linear_velocity.length() > 1.5:
			continue
		near.taken_into(self)
		key = near
		_from = near.global_transform
		_turn = 0.0
		return
