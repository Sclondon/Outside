class_name TrainScenery
extends Node3D
## What goes by a train that is standing still: the other way of staging a
## ride (see `Train.world_moves`). Everything that is a child of this node
## (lengths of track, telegraph poles, a bridge, a platform, rocks and bushes)
## is drawn back past the train as it "goes", and when it has gone `span`
## metres comes round again in front: so a few things make a line of any
## length. Put this node about the middle of the train, and make `span` a
## whole number of lengths of track, so that the rails never show a join.
##
## Children are moved, not their meshes: what is solid among them stays solid
## where it is seen. A child with the metadata `strikes` (an AABB in its own
## space: the girder of `bridge_low`, the bar of `loading_gauge`) knocks down
## whoever it meets (`strikes`), which is how he is swept off a roof he did not
## duck on. A child with the metadata `rest_only` (a buffer stop) is there only
## while nothing has moved.
##
## This is the simple version. The sand itself does not move (its grain is
## drawn from where it is in the world), and things come round again with a
## pop at half a `span` from the middle: keep that further off than the eye
## reaches, or in haze.

## How far the world goes before it comes round again, metres.
@export var span := 90.0

## How far it has gone.
var gone := 0.0

var _homes := {}
var _way := Vector3.BACK


## The world goes back by `step` metres past a train pointing along `forward` (in the world).
func scroll(step: float, forward: Vector3) -> void:
	if step == 0.0:
		return
	if _homes.is_empty():
		for child in get_children():
			if child is Node3D:
				_homes[child] = (child as Node3D).position
				if child.has_meta(&"rest_only"):
					_rest(child, false)
	_way = (global_basis.inverse() * forward).normalized()
	gone = fposmod(gone + step, span)
	for child: Node3D in _homes:
		if not is_instance_valid(child):
			continue
		var home: Vector3 = _homes[child]
		var along := home.dot(_way)
		child.position = home + _way * (wrapf(along - gone, -span * 0.5, span * 0.5) - along)


## Puts everything back where it was made.
func settle() -> void:
	for child: Node3D in _homes:
		if is_instance_valid(child):
			child.position = _homes[child]
			if child.has_meta(&"rest_only"):
				_rest(child, true)
	_homes.clear()
	gone = 0.0


# Something that is only there while nothing moves: drawn and solid, or neither.
func _rest(thing: Node3D, there: bool) -> void:
	thing.visible = there
	if thing is CollisionObject3D:
		var body := thing as CollisionObject3D
		if not there:
			thing.set_meta(&"layer", body.collision_layer)
			body.collision_layer = 0
		elif thing.has_meta(&"layer"):
			body.collision_layer = thing.get_meta(&"layer")


## What `who` is about to be struck by, if anything, as the world comes at him by `step`: a child whose `strikes` box
## his body is in. Ducked or sat down, he is shorter.
func strikes(who: Player, step: float) -> Node3D:
	var tall := who.stand_height
	if who.state == Player.State.SLIDE or who.is_crawling:
		tall = who.slide_height
	elif who.is_ducking or who.rest != Player.Rest.UP:
		tall = who.crouch_height
	for child in get_children():
		if not child.has_meta(&"strikes") or not (child is Node3D):
			continue
		var box: AABB = child.get_meta(&"strikes")
		var at := (child as Node3D).global_transform.affine_inverse() * who.global_position
		var reach := 0.22 + step
		if at.x > box.position.x - reach and at.x < box.end.x + reach and at.z > box.position.z - reach and at.z < box.end.z + reach \
				and at.y + tall > box.position.y and at.y < box.end.y:
			return child
	return null
