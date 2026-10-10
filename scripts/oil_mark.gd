class_name OilMark
extends Node3D
## A fire dish: a shallow dish of stone let into the floor, black with old
## soot, that knows when oil burns in it. It is a trigger, as a pressure plate
## is: `changed` is given out and `pressed` is true from the moment fire is in
## it, and it stays so. Oil has to be brought to it (poured into it from a jar,
## or a trail laid to it) and lit; which is how a fuse opens a door.
##
## It does not hold him up or stand in his way: it is a mark on the floor.

## Fire is in it.
signal changed(pressed: bool)

## How far across it is, in metres.
@export var radius := 0.5

var pressed := false

var _tick := 0


func _ready() -> void:
	# A low rim round a dark hollow, drawn as two rings and a floor.
	var tool := SurfaceTool.new()
	tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	var soot := SurfaceTool.new()
	soot.begin(Mesh.PRIMITIVE_TRIANGLES)
	const ROUND := 14
	# (out, up): the outside of the rim, its top, its inside, and the floor of the dish
	var side: Array[Vector2] = [Vector2(1.12, 0.0), Vector2(1.06, 0.05), Vector2(0.94, 0.05), Vector2(0.86, 0.012), Vector2(0.0, 0.012)]
	for j in side.size() - 1:
		for s in ROUND:
			var corners: Array[Vector3] = []
			for corner: Array in [[j, s], [j, s + 1], [j + 1, s + 1], [j + 1, s]]:
				var round: float = TAU * (int(corner[1]) % ROUND) / ROUND
				var here: Vector2 = side[corner[0]]
				corners.append(Vector3(cos(round) * here.x * radius, here.y, sin(round) * here.x * radius))
			var slope := side[j + 1] - side[j]
			var out := Vector2(slope.y, -slope.x).normalized()
			var a := TAU * (s + 0.5) / ROUND
			var into: SurfaceTool = soot if j >= 2 else tool
			var normal := Vector3(cos(a) * out.x, out.y, sin(a) * out.x)
			for corner: int in [0, 1, 2, 0, 2, 3]:
				into.set_normal(normal)
				into.add_vertex(corners[corner])
	var mesh := ArrayMesh.new()
	tool.set_material(Toon.surface(Color(0.5, 0.45, 0.37)))
	tool.commit(mesh)
	soot.set_material(Toon.surface(Color(0.16, 0.14, 0.125)))
	soot.commit(mesh)
	var dish := MeshInstance3D.new()
	dish.mesh = mesh
	dish.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(dish)


func _physics_process(_delta: float) -> void:
	_tick += 1
	if pressed or _tick % 6 != 0:
		return
	if Oil.is_burning_at(global_position, radius * 0.5):
		pressed = true
		changed.emit(true)
