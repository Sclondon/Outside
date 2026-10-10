class_name PuzzleKit
## What the puzzle parts are put together from (a `Lever`, a `KeyLock`, a
## `Mirror` on its stand, a `Sluice`...): stone, bronze, iron and wood, and
## boxes, rods and balls of them. Nothing here is solid: a part adds its own
## shapes (`shape`).

const STONE := Color(0.58, 0.52, 0.42)
const DARK := Color(0.34, 0.3, 0.25)
const BRONZE := Color(0.74, 0.5, 0.24)
const IRON := Color(0.2, 0.19, 0.2)
const WOOD := Color(0.44, 0.32, 0.2)
const HOLLOW := Color(0.08, 0.07, 0.06)


static func stone(colour := STONE) -> Material:
	return Toon.surface(colour)


## Bronze, polished: lit as gold is.
static func bronze(colour := BRONZE) -> Material:
	return Toon.gold(colour)


static func iron() -> Material:
	return Toon.surface(IRON)


static func wood(colour := WOOD) -> Material:
	return Toon.surface(colour)


## A box to look at, under `on`.
static func box(on: Node3D, at: Vector3, size: Vector3, material: Material) -> MeshInstance3D:
	var mesh := BoxMesh.new()
	mesh.size = size
	return _show(on, mesh, at, material)


## A rod standing along Y (`top`, if given, is its radius at the top: a cone, a taper).
static func rod(on: Node3D, at: Vector3, radius: float, height: float, material: Material, top := -1.0, sides := 10) -> MeshInstance3D:
	var mesh := CylinderMesh.new()
	mesh.bottom_radius = radius
	mesh.top_radius = radius if top < 0.0 else top
	mesh.height = height
	mesh.radial_segments = sides
	mesh.rings = 1
	return _show(on, mesh, at, material)


static func ball(on: Node3D, at: Vector3, radius: float, material: Material) -> MeshInstance3D:
	var mesh := SphereMesh.new()
	mesh.radius = radius
	mesh.height = radius * 2.0
	mesh.radial_segments = 12
	mesh.rings = 6
	return _show(on, mesh, at, material)


## A ring lying flat (round Y), `thick` through.
static func ring(on: Node3D, at: Vector3, radius: float, thick: float, material: Material) -> MeshInstance3D:
	var mesh := TorusMesh.new()
	mesh.inner_radius = radius - thick * 0.5
	mesh.outer_radius = radius + thick * 0.5
	mesh.rings = 16
	mesh.ring_segments = 6
	return _show(on, mesh, at, material)


## A solid box on a body.
static func shape(body: CollisionObject3D, at: Vector3, size: Vector3) -> CollisionShape3D:
	var box_shape := BoxShape3D.new()
	box_shape.size = size
	var collider := CollisionShape3D.new()
	collider.shape = box_shape
	collider.position = at
	body.add_child(collider)
	return collider


static func _show(on: Node3D, mesh: Mesh, at: Vector3, material: Material) -> MeshInstance3D:
	var visual := MeshInstance3D.new()
	visual.mesh = mesh
	visual.material_override = material
	visual.position = at
	on.add_child(visual)
	return visual
