class_name ScarabSocket
extends TombParts.Plate
## A stone with a hollow the shape of a scarab cut in it. It is a pressure
## plate that nothing presses but a `ScarabAmulet` laid on it (thrown onto it,
## or put down on it): so it works a door, a bridge, or anything else a plate
## works, and a level wires it up as it does a plate (`changed`).
## `ScarabSocket.new()` is a whole one; its foot is at this node.

## How big the stone is.
@export var block := Vector3(0.5, 0.3, 0.6)


func _ready() -> void:
	span = Vector3(block.x, block.y + 0.4, block.z)
	super()
	# (the plate's own slab is the top of the stone: it does not sink)
	_slab.position.y = block.y - 0.05
	set_meta(&"surface", "stone")
	var body := StaticBody3D.new()
	var shape := BoxShape3D.new()
	shape.size = block
	var collider := CollisionShape3D.new()
	collider.shape = shape
	collider.position.y = block.y * 0.5
	body.add_child(collider)
	var mesh := BoxMesh.new()
	mesh.size = block - Vector3(0.0, 0.02, 0.0)
	var stone := MeshInstance3D.new()
	stone.mesh = mesh
	stone.position.y = block.y * 0.5 - 0.01
	stone.material_override = Toon.surface(Color(0.5, 0.45, 0.37))
	body.add_child(stone)
	add_child(body)
	# The hollow: the shape of the wing cases and the head, dark.
	var hollow := MeshInstance3D.new()
	var oval := CylinderMesh.new()
	oval.top_radius = 0.5
	oval.bottom_radius = 0.5
	oval.height = 0.004
	oval.radial_segments = 12
	oval.rings = 1
	hollow.mesh = oval
	hollow.scale = Vector3(0.13, 1.0, 0.19)
	hollow.position.y = block.y + 0.004
	var dark := StandardMaterial3D.new()
	dark.albedo_color = Color(0.1, 0.08, 0.06)
	dark.roughness = 1.0
	hollow.material_override = dark
	add_child(hollow)


func _physics_process(_delta: float) -> void:
	var filled := latches and pressed
	for body in get_overlapping_bodies():
		if body.is_in_group(&"scarab_amulets"):
			filled = true
			break
	if filled != pressed:
		pressed = filled
		changed.emit(pressed)
