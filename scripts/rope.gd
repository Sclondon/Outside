class_name Rope
extends Node3D
## A rope hanging straight down from where this node is placed. The player
## catches it by jumping into it, climbs with up and down, and leaps off with
## jump. It does not swing.

@export var length := 5.0

func _ready() -> void:
	add_to_group(&"ropes")
	var cord := MeshInstance3D.new()
	var mesh := CylinderMesh.new()
	mesh.top_radius = 0.025
	mesh.bottom_radius = 0.025
	mesh.height = length
	mesh.radial_segments = 6
	cord.mesh = mesh
	var hemp := StandardMaterial3D.new()
	hemp.albedo_color = Color(0.45, 0.38, 0.26)
	hemp.roughness = 1.0
	hemp.metallic_specular = 0.0
	cord.material_override = hemp
	cord.position.y = -length * 0.5
	add_child(cord)
	# A knot at the end, so the bottom reads
	var knot := MeshInstance3D.new()
	var ball := SphereMesh.new()
	ball.radius = 0.05
	ball.height = 0.1
	ball.radial_segments = 8
	ball.rings = 4
	knot.mesh = ball
	knot.material_override = hemp
	knot.position.y = -length
	add_child(knot)


func top_y() -> float:
	return global_position.y


func bottom_y() -> float:
	return global_position.y - length


## How far `point` is from the rope, measured level.
func distance_to(point: Vector3) -> float:
	return Vector2(point.x - global_position.x, point.z - global_position.z).length()
