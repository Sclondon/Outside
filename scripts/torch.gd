class_name HandTorch
extends RigidBody3D
## A burning torch to carry: a stick with its head wrapped and alight. It is a
## loose thing like a rock (in the groups `throwable` and `interest`), and also
## in `torches`, which is how whoever picks it up knows to hold it upright by
## its handle. Its origin is at the foot of the handle and it stands along its
## own Y. It lights where he goes; thrown, it goes on burning where it lands.
## `HandTorch.new()` is a whole one.

## How long the stick is, in metres.
@export var length := 0.62
## Whether it is burning.
@export var lit := true: set = _set_lit

## Its fire (none while it is out).
var fire: Fire


func _ready() -> void:
	add_to_group(&"throwable")
	add_to_group(&"interest")
	add_to_group(&"torches")
	mass = 0.8
	# Falls briskly, as everything he throws does, and lies where it is put down.
	gravity_scale = 2.0
	angular_damp = 6.0
	var shape := CapsuleShape3D.new()
	shape.radius = 0.035
	shape.height = length
	var collider := CollisionShape3D.new()
	collider.shape = shape
	collider.position.y = length * 0.5
	add_child(collider)
	var stick := CylinderMesh.new()
	stick.top_radius = 0.024
	stick.bottom_radius = 0.017
	stick.height = length
	stick.radial_segments = 7
	stick.rings = 1
	var handle := MeshInstance3D.new()
	handle.mesh = stick
	handle.position.y = length * 0.5
	handle.material_override = Toon.surface(Color(0.36, 0.25, 0.15))
	add_child(handle)
	# The head: rags bound round the end, charred.
	var wrap := CylinderMesh.new()
	wrap.top_radius = 0.04
	wrap.bottom_radius = 0.034
	wrap.height = 0.13
	wrap.radial_segments = 7
	wrap.rings = 1
	var head := MeshInstance3D.new()
	head.mesh = wrap
	head.position.y = length - 0.05
	head.material_override = Toon.surface(Color(0.15, 0.12, 0.1))
	add_child(head)
	_set_lit(lit)


func _set_lit(value: bool) -> void:
	lit = value
	if not is_inside_tree():
		return
	if fire and not lit:
		fire.queue_free()
		fire = null
	elif lit and fire == null:
		fire = Fire.torch()
		fire.position.y = length
		add_child(fire)
