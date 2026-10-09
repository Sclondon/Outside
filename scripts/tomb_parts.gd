class_name TombParts
## The working parts of the tomb: torches, pressure plates and stone doors.


## A wall torch: a bracket, a flame, and a warm light that gutters.
class Torch extends Node3D:
	const FLAME := Color(1.0, 0.58, 0.24)
	## The flame as it used to be drawn, a plain glowing tongue, for every torch
	## made after this is set, in place of a `Fire`.
	static var plain := false
	var energy := 2.4
	var reach := 9.0
	var casts_shadows := false
	## The fire on it (none on a plain torch).
	var fire: Fire
	var _light: OmniLight3D
	var _flame: MeshInstance3D
	var _time := 0.0

	func _ready() -> void:
		_time = randf() * 20.0
		var bracket := MeshInstance3D.new()
		var stick := BoxMesh.new()
		stick.size = Vector3(0.07, 0.45, 0.07)
		bracket.mesh = stick
		bracket.rotation.x = -0.35
		var wood := StandardMaterial3D.new()
		wood.albedo_color = Color(0.12, 0.09, 0.07)
		bracket.material_override = wood
		add_child(bracket)

		if not plain:
			# The flame stands on the head of the stick; its light is out from the
			# wall, where the old one was, so that the wall behind is not burnt out.
			fire = Fire.torch()
			fire.light_energy = energy * 0.86
			fire.light_range = reach
			fire.light_shadows = casts_shadows
			fire.position = Vector3(0.0, 0.2, 0.09)
			fire.light_offset = Vector3(0.0, 0.4, 0.5) - fire.position - Vector3(0.0, fire.size * 0.55, 0.0)
			add_child(fire)
			set_process(false)
			return

		_flame = MeshInstance3D.new()
		var tongue := SphereMesh.new()
		tongue.radius = 0.07
		tongue.height = 0.24
		tongue.radial_segments = 8
		tongue.rings = 4
		_flame.mesh = tongue
		var glow := StandardMaterial3D.new()
		glow.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		glow.albedo_color = Color(1.0, 0.78, 0.42)
		glow.disable_fog = true
		_flame.material_override = glow
		_flame.position = Vector3(0.0, 0.34, 0.12)
		_flame.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(_flame)

		_light = OmniLight3D.new()
		_light.light_color = FLAME
		_light.omni_range = reach
		_light.omni_attenuation = 1.3
		_light.shadow_enabled = casts_shadows
		_light.position = Vector3(0.0, 0.4, 0.5)
		add_child(_light)

	func _process(delta: float) -> void:
		_time += delta
		# Two slow wavers and a fast one never quite line up, like a real flame.
		var gutter := 0.86 + 0.08 * sin(_time * 7.3) + 0.05 * sin(_time * 12.7 + 1.0) + 0.04 * sin(_time * 31.0)
		_light.light_energy = energy * gutter
		_flame.scale = Vector3(1.0, 0.85 + gutter * 0.25, 1.0)
		_flame.position.x = sin(_time * 9.0) * 0.012


## A slab in the floor that sinks under anything with weight: the player, a
## pushed block, or the mummy. It spans the walkable depth.
class Plate extends Area3D:
	signal changed(pressed: bool)
	var pressed := false
	## Once pressed it stays down: a target to hit rather than a weight to hold.
	var latches := false
	var span := Vector3(1.5, 0.5, 7.0)
	var _slab: MeshInstance3D

	func _ready() -> void:
		add_to_group(&"interest")
		# Player, blocks and pursuers
		collision_mask = 1 | 2 | 4
		var shape := BoxShape3D.new()
		shape.size = span
		var collider := CollisionShape3D.new()
		collider.shape = shape
		collider.position.y = span.y * 0.5
		add_child(collider)

		_slab = MeshInstance3D.new()
		var mesh := BoxMesh.new()
		mesh.size = Vector3(span.x, 0.1, span.z)
		_slab.mesh = mesh
		var material := StandardMaterial3D.new()
		material.albedo_color = Color(0.5, 0.4, 0.24)
		material.roughness = 1.0
		material.metallic_specular = 0.0
		_slab.material_override = material
		# Flush with the floor so a block slides straight onto it.
		_slab.position.y = -0.035
		add_child(_slab)

	func _physics_process(delta: float) -> void:
		var weight := latches and pressed
		for body in get_overlapping_bodies():
			if body is RigidBody3D or body is CharacterBody3D:
				weight = true
				break
		if weight != pressed:
			pressed = weight
			changed.emit(pressed)
		_slab.position.y = move_toward(_slab.position.y, -0.075 if pressed else -0.035, delta * 0.3)


## A stone slab that fills a doorway and lifts into the lintel when opened.
class Door extends AnimatableBody3D:
	var is_open := false
	var height := 2.4
	var speed := 1.5
	var _closed_y := 0.0

	func _init(size: Vector3, color: Color) -> void:
		height = size.y
		var shape := BoxShape3D.new()
		shape.size = size
		var collider := CollisionShape3D.new()
		collider.shape = shape
		add_child(collider)
		var mesh := BoxMesh.new()
		mesh.size = size
		var slab := MeshInstance3D.new()
		slab.mesh = mesh
		var material := StandardMaterial3D.new()
		material.albedo_color = color
		material.roughness = 1.0
		material.metallic_specular = 0.0
		slab.material_override = material
		add_child(slab)

	func _ready() -> void:
		_closed_y = position.y

	func _physics_process(delta: float) -> void:
		position.y = move_toward(position.y, _closed_y + (height if is_open else 0.0), speed * delta)
