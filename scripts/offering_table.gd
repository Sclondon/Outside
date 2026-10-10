class_name OfferingTable
extends StaticBody3D
## An offering table: a slab of stone on two legs, with the mat and the loaf
## of the sign for an offering cut in the top of it. A jar put down at it, or
## thrown onto it, is set on it (a canopic jar: any loose thing in the group
## `offerings` or `tomb_jars`, or made from a prop called `jar_...`), and then
## the table is on (`changed`): so it works a door, or anything else a
## pressure plate works. With `latches` it stays on whatever becomes of the
## jar; without, it is on only while the jar stands there. Its foot is at this
## node. `OfferingTable.new()` is a whole one.
##
## A tomb's offering table (`TombLevel`) is only a place in its stone; what the
## two share is how a jar is set down (`set_on`).

signal changed(on: bool)

## How near the table a jar must be put down to be set on it, over the ground.
const WITHIN := 1.3
## How high the top of it is.
const TOP := 0.8
## How far above what it stands on the middle of a canopic jar is.
const JAR := 0.23

## Once a jar has been given, it stays on.
@export var latches := true
## Whether it has what it wants.
@export var on := false

## The jar that stands on it, if one does.
var jar: RigidBody3D

var _starts_on := false


## Whether something is a thing to give.
static func is_offering(thing: Node) -> bool:
	return thing is RigidBody3D and (thing.is_in_group(&"offerings") or thing.is_in_group(&"tomb_jars") or thing.scene_file_path.get_file().begins_with("jar_"))


## Stands a jar at a place (the middle of the jar), given: it stays there.
static func set_on(given: RigidBody3D, at: Vector3) -> void:
	given.freeze = true
	given.global_transform = Transform3D(Basis.IDENTITY, at)
	given.set_meta(&"offered", true)


func _ready() -> void:
	add_to_group(&"interest")
	set_meta(&"surface", "stone")
	_starts_on = on
	PuzzleKit.shape(self, Vector3(0.0, TOP * 0.5, 0.0), Vector3(1.3, TOP, 0.7))
	PuzzleKit.box(self, Vector3(0.0, TOP - 0.07, 0.0), Vector3(1.4, 0.14, 0.8), PuzzleKit.stone())
	for x: float in [-0.45, 0.45]:
		PuzzleKit.box(self, Vector3(x, (TOP - 0.14) * 0.5, 0.0), Vector3(0.22, TOP - 0.14, 0.6), PuzzleKit.stone(PuzzleKit.STONE.darkened(0.12)))
	PuzzleKit.box(self, Vector3(0.0, 0.04, 0.0), Vector3(1.3, 0.08, 0.7), PuzzleKit.stone(PuzzleKit.DARK))
	# The sign cut in the top: a mat, and a loaf standing on it, where the jar goes.
	PuzzleKit.box(self, Vector3(0.0, TOP + 0.004, 0.12), Vector3(0.62, 0.008, 0.16), PuzzleKit.stone(PuzzleKit.DARK))
	PuzzleKit.rod(self, Vector3(0.0, TOP + 0.004, -0.1), 0.15, 0.008, Toon.gold(), -1.0, 16)


## Where the middle of a jar set on it is, in the world.
func place() -> Vector3:
	return global_transform * Vector3(0.0, TOP + JAR, -0.1)


## As it was when it was made, and the jar let go of.
func reset() -> void:
	_let_go()
	_switch(_starts_on)


func _exit_tree() -> void:
	# (taken out of the level with a jar on it: the jar is let fall)
	_let_go()


func _let_go() -> void:
	if jar and is_instance_valid(jar):
		jar.remove_meta(&"offered")
		var player := Nearby.player(get_tree()) if is_inside_tree() else null
		if player == null or player.carried != jar:
			jar.freeze = false
	jar = null


func _switch(to: bool) -> void:
	if to == on:
		return
	on = to
	changed.emit(on)


func _physics_process(_delta: float) -> void:
	var player := Nearby.player(get_tree())
	if jar:
		# Taken up again (or taken away), it is not on the table.
		if not is_instance_valid(jar) or (player and player.carried == jar) or jar.global_position.distance_to(place()) > 0.3:
			if is_instance_valid(jar):
				jar.remove_meta(&"offered")
			jar = null
	if jar == null:
		var top := global_transform * Vector3(0.0, TOP, 0.0)
		for found: Node in get_tree().get_nodes_in_group(&"throwable"):
			if not is_offering(found) or found.has_meta(&"offered") or (player and player.carried == found):
				continue
			var given := found as RigidBody3D
			var from := given.global_position - top
			if Vector2(from.x, from.z).length() < WITHIN and absf(from.y) < 1.2 and given.linear_velocity.length() < 1.5:
				set_on(given, place())
				jar = given
				break
	_switch(jar != null or (latches and on))
