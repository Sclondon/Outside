class_name DoorKey
extends RigidBody3D
## A key as long as his forearm, of iron, bronze or gold: a ring to hold it by,
## a shank, and a bit with two wards. It is a loose thing like a rock (in the
## groups `throwable` and `interest`), and also in `keys`, which is how a
## `KeyLock` knows it: brought to the lock of its own metal (`which`), it is
## taken out of his hand, turned, and stays there. Its origin is its middle and
## its bit is towards +Z. `DoorKey.new()` is a whole one.

enum Metal { IRON, BRONZE, GOLD }

## What it is made of: it opens the lock of the same.
@export var which := Metal.IRON
## How long it is, in metres.
@export var length := 0.3

## Where it was put (it goes back there when its lock is put back as it was).
var home := Transform3D.IDENTITY
## The lock that has it, if one has.
var held_by: Node3D

var _layers := Vector2i.ZERO


## What a key and the plate of its lock are made of.
static func metal(of: Metal) -> Material:
	match of:
		Metal.BRONZE:
			return PuzzleKit.bronze()
		Metal.GOLD:
			return Toon.gold()
	return PuzzleKit.iron()


func _ready() -> void:
	add_to_group(&"throwable")
	add_to_group(&"interest")
	add_to_group(&"keys")
	mass = 0.6
	# Falls briskly, as everything he throws does, and lies where it is put down.
	gravity_scale = 2.0
	angular_damp = 4.0
	home = global_transform
	PuzzleKit.shape(self, Vector3.ZERO, Vector3(0.36, 0.14, 1.0) * length)
	var made_of := metal(which)
	var shank := PuzzleKit.rod(self, Vector3(0.0, 0.0, 0.08) * length, 0.035 * length, 0.72 * length, made_of, -1.0, 6)
	shank.rotation.x = PI * 0.5
	# The ring it is held by, and a collar where the shank meets it.
	PuzzleKit.ring(self, Vector3(0.0, 0.0, -0.36) * length, 0.13 * length, 0.05 * length, made_of)
	var collar := PuzzleKit.rod(self, Vector3(0.0, 0.0, -0.2) * length, 0.055 * length, 0.06 * length, made_of, -1.0, 6)
	collar.rotation.x = PI * 0.5
	# The bit: two wards with a gap between.
	for z: float in [0.26, 0.4]:
		PuzzleKit.box(self, Vector3(0.09, 0.0, z) * length, Vector3(0.16, 0.035, 0.09) * length, made_of)


## Taken by a lock (or, with nothing, let go of by one): while it is held it
## cannot be picked up, and nothing knocks it.
func taken_into(lock: Node3D) -> void:
	if lock and held_by == null:
		_layers = Vector2i(collision_layer, collision_mask)
		remove_from_group(&"throwable")
		remove_from_group(&"interest")
		freeze = true
		collision_layer = 0
		collision_mask = 0
	elif lock == null and held_by:
		add_to_group(&"throwable")
		add_to_group(&"interest")
		collision_layer = _layers.x
		collision_mask = _layers.y
		freeze = false
	held_by = lock


## Back where it was put.
func go_home() -> void:
	linear_velocity = Vector3.ZERO
	angular_velocity = Vector3.ZERO
	global_transform = home
