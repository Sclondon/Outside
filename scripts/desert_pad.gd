@tool
class_name TerrainPad
extends Marker3D
## A patch of level ground in a `DesertTerrain`: the dunes are pressed flat
## to this node's height over `half_size`, and rise back to themselves over
## `ease` metres round it. Put one under anything that needs level ground, as
## a child of whatever it belongs to: moving that moves the pad, and in the
## editor the ground follows a moment later. Turning it about Y turns the patch.
## A pad inside another, set lower, makes a hollow (the oasis pool is one):
## pads lower in the scene tree are pressed in after those above them.

## How far the level ground runs each way from the middle (x, z), in metres.
@export var half_size := Vector2(10.0, 10.0):
	set(value):
		half_size = value
		_changed()
## Round (an ellipse) instead of a rectangle.
@export var round := false:
	set(value):
		round = value
		_changed()
## How far the dunes take to rise back round it.
@export var ease := 10.0:
	set(value):
		ease = maxf(value, 0.1)
		_changed()


func _enter_tree() -> void:
	add_to_group(&"terrain_pads")
	set_notify_transform(true)


func _exit_tree() -> void:
	_changed()


func _notification(what: int) -> void:
	if what == NOTIFICATION_TRANSFORM_CHANGED:
		_changed()


## What the terrain needs to know of it.
func entry() -> Array:
	return [global_transform, half_size, round, ease]


func _changed() -> void:
	if not Engine.is_editor_hint() or not is_inside_tree():
		return
	var terrain := get_tree().get_first_node_in_group(&"terrain")
	if terrain:
		terrain.call(&"queue_rebuild")
