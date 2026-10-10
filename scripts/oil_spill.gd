class_name OilSpill
extends Node3D
## Oil that has already been poured: a trail of it over the ground from where
## this node is, `length` metres along its own +Z (a puddle, if it has no
## length), bending aside as it goes if it is told to. It is `Oil` like any
## other (`scripts/oil.gd`): it burns from one end to the other at a metre a
## second, which makes it a fuse.
##
## It is also a trigger: `burnt` is given out, once, when the fire has reached
## its far end (`is_burnt` from then on), so that a fuse can open a door. In a
## level made from a layout it turns on what is linked to it, as a pressure
## plate does.
##
## It is laid afresh when he starts again, if any of it has burnt; and taken
## up when this node leaves the scene, or laid again where this is moved to.

## The fire has reached its far end.
signal burnt

## How long the trail is, in metres (0: a puddle).
@export var length := 4.0
## How wide it is, in metres (a puddle: how far across).
@export var wide := 0.4
## How far it has turned aside by its end, in degrees.
@export var bend := 0.0

var is_burnt := false

var _laid := false
var _relaying := false
var _tick := 0
var _whole := 0
var _oil: Oil


func _ready() -> void:
	set_notify_transform(true)
	_lay_when_there_is_ground()
	var boy := Nearby.player(get_tree())
	if boy:
		boy.respawned.connect(_renew)
	else:
		get_tree().node_added.connect(_notice)


func _exit_tree() -> void:
	if is_instance_valid(_oil) and _oil.is_inside_tree():
		_oil.clear(get_instance_id())
	_laid = false
	if get_tree().node_added.is_connected(_notice):
		get_tree().node_added.disconnect(_notice)


func _notification(what: int) -> void:
	# (moved, as the level editor moves it: it is laid again where it now is)
	if what == NOTIFICATION_TRANSFORM_CHANGED and _laid:
		_lay_when_there_is_ground()


## Where its far end is, on the ground.
func far_end() -> Vector3:
	var path := _path()
	return path[path.size() - 1]


## Takes it up and lays it again, whole.
func relay() -> void:
	_oil = Oil.of(self)
	_oil.clear(get_instance_id())
	var path := _path()
	var radius := clampf(wide * 0.5, 0.1, Oil.WIDEST)
	if length <= 0.01:
		# A puddle: rings of patches out to its width.
		var across := maxf(wide * 0.5, 0.1)
		_oil.lay(path[0], path[0], minf(across, Oil.WIDEST), get_instance_id())
		var out := radius * 1.2
		while out < across - radius * 0.5:
			var round := maxi(ceili(TAU * out / (radius * 1.3)), 5)
			for n in round:
				var at := path[0] + Vector3(cos(TAU * n / round), 0.0, sin(TAU * n / round)) * out
				_oil.lay(at, at, radius, get_instance_id())
			out += radius * 1.2
	else:
		for n in path.size() - 1:
			_oil.lay(path[n], path[n + 1], radius, get_instance_id())
			# (a trail wider than one patch is laid as several, side by side)
			var beside := (path[n + 1] - path[n]).normalized().cross(Vector3.UP)
			var off := radius * 1.3
			while off < wide * 0.5:
				for side: float in [-1.0, 1.0]:
					_oil.lay(path[n] + beside * off * side, path[n + 1] + beside * off * side, radius, get_instance_id())
				off += radius * 1.3
	_laid = true
	_whole = _oil.amounts(get_instance_id()).x


func _physics_process(_delta: float) -> void:
	_tick += 1
	if is_burnt or not _laid or _tick % 6 != 0 or not is_instance_valid(_oil):
		return
	var end := far_end()
	if _oil.is_burning(end, 0.25) or _oil.is_scorched(end, 0.25):
		is_burnt = true
		burnt.emit()


# The ground is not there to be poured on until the level has stood a moment.
func _lay_when_there_is_ground() -> void:
	if _relaying:
		return
	_relaying = true
	for wait in 2:
		await get_tree().physics_frame
	_relaying = false
	if is_inside_tree():
		relay()


# The line it lies along, in the world: a few points, level with this node.
func _path() -> Array[Vector3]:
	var points: Array[Vector3] = [global_position]
	var steps := 1 if absf(bend) < 0.5 else clampi(ceili(length / 0.5), 2, 40)
	var heading := global_basis.z
	heading.y = 0.0
	heading = heading.normalized() if heading.length() > 0.01 else Vector3.BACK
	for n in steps:
		var turned := heading.rotated(Vector3.UP, deg_to_rad(bend) * (n + 0.5) / steps)
		points.append(points[n] + turned * maxf(length, 0.0) / steps)
	return points


func _notice(node: Node) -> void:
	if node is Player:
		(node as Player).respawned.connect(_renew)
		get_tree().node_added.disconnect(_notice)


# He starts again: what has burnt is oil again.
func _renew() -> void:
	if not _laid or not is_instance_valid(_oil):
		return
	if _oil.amounts(get_instance_id()).x < _whole:
		relay()
