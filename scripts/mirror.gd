class_name Mirror
extends StaticBody3D
## A mirror of polished bronze on a stand: a disc in a fork, on a post, in a
## foot of stone. A `SunBeam` that falls on either face of it is thrown off
## again as a mirror throws it. He turns it with the act button, standing at
## it with his hands empty (it is in the group `workable`: see `Player._act`):
## each press turns it one `step` further round, always the same way. Its foot
## is at this node; the middle of the disc is `height` above it, and until it
## is turned the disc faces along the node's Z. `Mirror.new()` is a whole one.

signal turned_to(steps: int)

## How big across the disc is.
const DISC := 0.7

## How high the middle of the disc is.
@export var height := 0.7
## How far one press turns it, degrees.
@export var step := 45.0
## How many steps round it starts.
@export var turned := 0
## How far its face is tipped up, degrees (to throw the light up to something higher, or down).
@export var tilt := 0.0
## He cannot turn it.
@export var fixed := false

## How many steps round it is now.
var steps := 0

var _head: Node3D
var _dish: Node3D


## The mirror a ray has hit, if what it hit is the face of one.
static func of(collider: Object) -> Mirror:
	var node := collider as Node
	if node and node.is_in_group(&"mirror_faces"):
		return node.get_meta(&"mirror") as Mirror
	return null


func _ready() -> void:
	add_to_group(&"interest")
	add_to_group(&"mirrors")
	if not fixed:
		add_to_group(&"workable")
	set_meta(&"surface", "metal")
	steps = turned
	PuzzleKit.shape(self, Vector3(0.0, 0.11, 0.0), Vector3(0.5, 0.22, 0.5))
	PuzzleKit.box(self, Vector3(0.0, 0.11, 0.0), Vector3(0.5, 0.22, 0.5), PuzzleKit.stone())
	PuzzleKit.box(self, Vector3(0.0, 0.03, 0.0), Vector3(0.62, 0.06, 0.62), PuzzleKit.stone(PuzzleKit.DARK))
	var reach := DISC * 0.5 + 0.07
	# (the post is solid only up to the fork: the light must be able to come at the disc from any side)
	PuzzleKit.shape(self, Vector3(0.0, (height - reach) * 0.5, 0.0), Vector3(0.12, height - reach, 0.12))
	PuzzleKit.rod(self, Vector3(0.0, (height - reach) * 0.5 + 0.1, 0.0), 0.045, maxf(height - reach - 0.2, 0.02), PuzzleKit.wood(), 0.035, 8)
	# What turns: a fork of bronze, and the disc in it.
	_head = Node3D.new()
	_head.position.y = height
	_head.rotation.y = deg_to_rad(steps * step)
	add_child(_head)
	var dull := PuzzleKit.bronze(PuzzleKit.BRONZE.darkened(0.3))
	PuzzleKit.box(_head, Vector3(0.0, -reach, 0.0), Vector3(reach * 2.0 + 0.05, 0.05, 0.06), dull)
	for x: float in [-reach, reach]:
		PuzzleKit.box(_head, Vector3(x, -reach * 0.5, 0.0), Vector3(0.05, reach, 0.06), dull)
		PuzzleKit.ball(_head, Vector3(x, 0.0, 0.0), 0.04, dull)
	_dish = Node3D.new()
	_dish.rotation.x = -deg_to_rad(tilt)
	_head.add_child(_dish)
	var rim := PuzzleKit.rod(_dish, Vector3.ZERO, DISC * 0.5, 0.035, dull, -1.0, 24)
	rim.rotation.x = PI * 0.5
	var polish := PuzzleKit.rod(_dish, Vector3.ZERO, DISC * 0.5 - 0.035, 0.045, Toon.gold(Color(0.9, 0.68, 0.36)), -1.0, 24)
	polish.rotation.x = PI * 0.5
	# The face, for the light to find: a thin disc, solid.
	var face := StaticBody3D.new()
	face.add_to_group(&"mirror_faces")
	face.set_meta(&"mirror", self)
	face.set_meta(&"surface", "metal")
	var round := CylinderShape3D.new()
	round.radius = DISC * 0.5
	round.height = 0.04
	var collider := CollisionShape3D.new()
	collider.shape = round
	collider.rotation.x = PI * 0.5
	face.add_child(collider)
	_dish.add_child(face)


## Turned one step on: by him, with the act button.
func work(_by: Node3D = null) -> void:
	if fixed:
		return
	steps += 1
	turned_to.emit(steps)


## Where his hand goes to turn it.
func work_point() -> Vector3:
	return _head.global_position + Vector3.DOWN * (DISC * 0.5)


## Which way its face looks (the other face looks the other way), in the world.
func normal() -> Vector3:
	return _dish.global_basis.z.normalized()


## Whether it has come to rest where it was last turned to.
func is_still() -> bool:
	return is_equal_approx(_head.rotation.y, deg_to_rad(steps * step))


## As it was when it was made.
func reset() -> void:
	steps = turned
	_head.rotation.y = deg_to_rad(steps * step)


func _physics_process(delta: float) -> void:
	_head.rotation.y = move_toward(_head.rotation.y, deg_to_rad(steps * step), delta * 2.6)
