class_name Rope
extends Node3D
## A rope hanging from where this node is placed, and it is a real one: a chain
## of points held a fixed distance apart, that swings, and hangs straight only
## when it is left alone. The player catches it by jumping into it, climbs with
## up and down, sets it swinging with left and right, and leaps off with jump,
## taking its swing with him.
##
## Whoever is on it says where (`load_at`, a distance down from the top), and
## weighs it down there, so it swings from that point like a pendulum.

## How many pieces it is made of.
const PIECES := 16

@export var length := 5.0
## How quickly a swing dies away, per second.
@export var drag := 0.35
## How much heavier than a piece of rope whoever hangs on it is.
@export var rider_weight := 14.0

## How far down from the top someone is hanging, or negative for nobody.
var load_at := -1.0

var _points := PackedVector3Array()
var _before := PackedVector3Array()
var _links: Array[MeshInstance3D] = []
var _knot: MeshInstance3D


func _ready() -> void:
	add_to_group(&"ropes")
	var hemp := StandardMaterial3D.new()
	hemp.albedo_color = Color(0.45, 0.38, 0.26)
	hemp.roughness = 1.0
	hemp.metallic_specular = 0.0
	var piece := length / PIECES
	for i in PIECES + 1:
		_points.append(global_position + Vector3.DOWN * piece * i)
	_before = _points.duplicate()
	for i in PIECES:
		var link := MeshInstance3D.new()
		var mesh := CylinderMesh.new()
		mesh.top_radius = 0.025
		mesh.bottom_radius = 0.025
		mesh.height = piece * 1.04
		mesh.radial_segments = 6
		mesh.rings = 1
		link.mesh = mesh
		link.material_override = hemp
		link.top_level = true
		add_child(link)
		_links.append(link)
	# A knot at the end, so the bottom reads
	_knot = MeshInstance3D.new()
	var ball := SphereMesh.new()
	ball.radius = 0.05
	ball.height = 0.1
	ball.radial_segments = 8
	ball.rings = 4
	_knot.mesh = ball
	_knot.material_override = hemp
	_knot.top_level = true
	add_child(_knot)
	_draw()


func _physics_process(delta: float) -> void:
	var piece := length / PIECES
	var gravity := Vector3.DOWN * 24.0 * delta * delta
	var keep := exp(-drag * delta)
	for i in range(1, PIECES + 1):
		var at := _points[i]
		_points[i] = at + (at - _before[i]) * keep + gravity
		_before[i] = at
	# Each piece is pulled back to its length, the heavier end moving the less.
	var loaded := int(round(load_at / piece)) if load_at >= 0.0 else -1
	for pass_ in 12:
		_points[0] = global_position
		for i in PIECES:
			var a := _points[i]
			var b := _points[i + 1]
			var apart := b - a
			var stretch := apart.length() - piece
			if absf(stretch) < 0.00001:
				continue
			var along := apart.normalized()
			var light_a := 0.0 if i == 0 else (1.0 / rider_weight if i == loaded else 1.0)
			var light_b := 1.0 / rider_weight if i + 1 == loaded else 1.0
			_points[i] = a + along * stretch * light_a / (light_a + light_b)
			_points[i + 1] = b - along * stretch * light_b / (light_a + light_b)
	_draw()


func _draw() -> void:
	for i in PIECES:
		var a := _points[i]
		var b := _points[i + 1]
		var along := (b - a).normalized()
		var across := along.cross(Vector3.RIGHT)
		across = across.normalized() if across.length_squared() > 0.001 else Vector3.BACK
		_links[i].global_transform = Transform3D(Basis(across.cross(along), -along, across), (a + b) * 0.5)
	_knot.global_position = _points[PIECES]


func top_y() -> float:
	return global_position.y


func bottom_y() -> float:
	return _points[PIECES].y if not _points.is_empty() else global_position.y - length


## Where the rope is, `distance` down it from the top.
func point_at(distance: float) -> Vector3:
	var along := clampf(distance / length, 0.0, 1.0) * PIECES
	var i := mini(int(along), PIECES - 1)
	return _points[i].lerp(_points[i + 1], along - i)


## How fast that part of it is moving.
func velocity_at(distance: float) -> Vector3:
	var i := clampi(int(round(distance / length * PIECES)), 1, PIECES)
	return (_points[i] - _before[i]) * Engine.physics_ticks_per_second


## How far down the rope the part of it nearest `point` is.
func nearest(point: Vector3) -> float:
	var best := 0
	for i in PIECES + 1:
		if _points[i].distance_squared_to(point) < _points[best].distance_squared_to(point):
			best = i
	return length * best / PIECES


## How far `point` is from the rope.
func distance_to(point: Vector3) -> float:
	return point_at(nearest(point)).distance_to(point)


## Shoves the rope at `distance` down it, and less so the rope either side: a
## change of speed, m/s.
func push(distance: float, shove: Vector3) -> void:
	var middle := distance / length * PIECES
	for i in range(1, PIECES + 1):
		var share := clampf(1.0 - absf(i - middle) / 3.0, 0.0, 1.0)
		_before[i] -= shove * share / Engine.physics_ticks_per_second
