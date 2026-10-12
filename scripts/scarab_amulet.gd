class_name ScarabAmulet
extends RigidBody3D
## A scarab the size of a hand, of gold with wing cases of lapis: the amulet
## laid over a mummy's heart. It is a loose thing like a rock (in the groups
## `throwable` and `interest`), and also in `scarab_amulets`, which is how a
## `ScarabSocket` knows it: laid in one, it works whatever the socket works.
## Its origin is its middle and its head is towards +Z. `ScarabAmulet.new()`
## is a whole one.

## How long it is, in metres.
@export var length := 0.14
@export var stone := Color(0.1, 0.22, 0.6)


func _ready() -> void:
	add_to_group(&"throwable")
	add_to_group(&"interest")
	add_to_group(&"scarab_amulets")
	mass = 0.5
	# Falls briskly, as everything he throws does, and lies where it is put down.
	gravity_scale = 2.0
	angular_damp = 4.0
	var shape := BoxShape3D.new()
	shape.size = Vector3(0.7, 0.3, 1.1) * length
	var collider := CollisionShape3D.new()
	collider.shape = shape
	add_child(collider)
	# The model's amulet (`scarab_amulet` in `models/khepri.glb`): its stone in this one's colour, the rest gold.
	var jewel := Scarab.amulet()
	var part := MeshInstance3D.new()
	part.mesh = jewel
	for surface in jewel.get_surface_count():
		var paint := jewel.surface_get_material(surface) as BaseMaterial3D
		var is_stone := paint != null and paint.resource_name.contains("stone")
		part.set_surface_override_material(surface, Toon.surface(stone) if is_stone else Toon.gold(paint.albedo_color if paint else Sandstone.GOLD))
	part.scale = Vector3.ONE * length
	part.position.y = -0.15 * length
	add_child(part)
