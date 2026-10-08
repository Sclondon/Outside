extends Node3D
## Grey-box test course: stairs, a ramp, crates to push, a ledge, a gap,
## a moving platform and a hill. Built in code so it is easy to retune.

const DEPTH := 7.0
const GROUND := Color(0.15, 0.16, 0.18)
const PROP := Color(0.21, 0.22, 0.25)
const BACKDROP := Color(0.09, 0.1, 0.12)
const SKY := Color(0.34, 0.38, 0.42)
## The hounds wait here, behind the start, until the player passes RELEASE_X.
const KENNEL: Array[Vector3] = [Vector3(-11.0, 0.1, -1.2), Vector3(-12.5, 0.1, 1.0)]
const RELEASE_X := 4.0

## Use the demade, low-poly hound model.
@export var low_poly_hounds := false

var _player: Player
var _hounds: Array[Hound] = []
var _released := false


func _ready() -> void:
	_build_atmosphere()
	_build_course()
	_build_backdrop()
	_kennel_hounds.call_deferred()


func _build_atmosphere() -> void:
	var environment := Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = SKY
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color(0.55, 0.6, 0.68)
	environment.ambient_light_energy = 0.75
	environment.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	environment.fog_enabled = true
	environment.fog_light_color = SKY
	environment.fog_density = 0.028
	var world := WorldEnvironment.new()
	world.environment = environment
	add_child(world)

	# Low light from behind, so figures read as rim-lit silhouettes.
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-48.0, 152.0, 0.0)
	sun.light_color = Color(0.86, 0.9, 1.0)
	sun.light_energy = 1.25
	sun.shadow_enabled = true
	sun.directional_shadow_mode = DirectionalLight3D.SHADOW_ORTHOGONAL
	sun.directional_shadow_max_distance = 45.0
	add_child(sun)


func _build_course() -> void:
	# Ground runs far behind and in front of the walkable strip to fill the frame.
	_ground(-14.0, 40.0)
	_ground(42.0, 60.0)
	_ground(66.0, 92.0)

	# Stairs up to a platform, ramp back down.
	for i in 4:
		_block(8.0 + 0.5 * i, 14.0, 0.2 * i, 0.2 * (i + 1))
	_ramp(Vector2(14.0, 0.8), Vector2(17.0, 0.0))

	_crate(Vector3(21.0, 0.45, 0.0))
	_crate(Vector3(23.2, 0.45, -1.2))

	# Needs a jump.
	_block(27.0, 31.0, 0.0, 1.0)

	_moving_platform(61.6, 64.4)

	# Hill.
	_ramp(Vector2(70.0, 0.0), Vector2(72.6, 1.5))
	_block(72.6, 76.0, 0.0, 1.5)
	_ramp(Vector2(76.0, 1.5), Vector2(78.6, 0.0))

	# Keep the player on the strip.
	_wall(Vector3(39.0, 6.0, DEPTH * 0.5 + 0.5), Vector3(110.0, 14.0, 1.0))
	_wall(Vector3(39.0, 6.0, -DEPTH * 0.5 - 0.5), Vector3(110.0, 14.0, 1.0))
	_wall(Vector3(-14.5, 6.0, 0.0), Vector3(1.0, 14.0, DEPTH + 2.0))
	_wall(Vector3(92.5, 6.0, 0.0), Vector3(1.0, 14.0, DEPTH + 2.0))


func _build_backdrop() -> void:
	var random := RandomNumberGenerator.new()
	random.seed = 7
	var material := _material(BACKDROP)
	# A wall far enough away to be pure fog. Renderers disagree on how the clear
	# colour compares with fog; this makes the sky fog on all of them.
	var sky := MeshInstance3D.new()
	var sheet := QuadMesh.new()
	sheet.size = Vector2(1200.0, 500.0)
	sky.mesh = sheet
	sky.material_override = material
	sky.position = Vector3(39.0, 120.0, -160.0)
	sky.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(sky)
	for i in 70:
		var trunk := MeshInstance3D.new()
		var mesh := BoxMesh.new()
		mesh.size = Vector3(random.randf_range(0.3, 1.4), random.randf_range(8.0, 22.0), random.randf_range(0.3, 1.4))
		trunk.mesh = mesh
		trunk.material_override = material
		trunk.position = Vector3(random.randf_range(-25.0, 105.0), mesh.size.y * 0.5 - 0.5, random.randf_range(-38.0, -5.5))
		trunk.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(trunk)


func _ground(from_x: float, to_x: float) -> void:
	_box(StaticBody3D.new(), Vector3((from_x + to_x) * 0.5, -2.0, -19.0), Vector3(to_x - from_x, 4.0, 62.0), GROUND)


## Box spanning the strip's depth, given by its extents in X and Y.
func _block(from_x: float, to_x: float, from_y: float, to_y: float) -> void:
	var size := Vector3(to_x - from_x, to_y - from_y, DEPTH)
	_box(StaticBody3D.new(), Vector3((from_x + to_x) * 0.5, (from_y + to_y) * 0.5, 0.0), size, PROP)


## Sloped slab whose top surface runs between two (x, y) points.
func _ramp(from: Vector2, to: Vector2) -> void:
	var thickness := 0.4
	var along := to - from
	var angle := along.angle()
	var centre := (from + to) * 0.5 - Vector2(-sin(angle), cos(angle)) * thickness * 0.5
	var body := _box(StaticBody3D.new(), Vector3(centre.x, centre.y, 0.0), Vector3(along.length(), thickness, DEPTH), PROP)
	body.rotation.z = angle


func _crate(at: Vector3) -> void:
	var crate := RigidBody3D.new()
	crate.mass = 20.0
	# Crates slide rather than tumble, so they stay usable as steps.
	crate.lock_rotation = true
	var surface := PhysicsMaterial.new()
	surface.friction = 0.6
	crate.physics_material_override = surface
	_box(crate, at, Vector3(0.9, 0.9, 0.9), PROP.lightened(0.08))


func _moving_platform(from_x: float, to_x: float) -> void:
	var platform := AnimatableBody3D.new()
	_box(platform, Vector3(from_x, -0.2, 0.0), Vector3(3.0, 0.4, DEPTH), PROP)
	var tween := create_tween().set_loops().set_process_mode(Tween.TWEEN_PROCESS_PHYSICS)
	tween.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tween.tween_property(platform, "position:x", to_x, 3.0)
	tween.tween_property(platform, "position:x", from_x, 3.0)


func _wall(at: Vector3, size: Vector3) -> void:
	var body := StaticBody3D.new()
	var collider := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = size
	collider.shape = shape
	body.add_child(collider)
	body.position = at
	add_child(body)


func _box(body: PhysicsBody3D, at: Vector3, size: Vector3, color: Color) -> PhysicsBody3D:
	var shape := BoxShape3D.new()
	shape.size = size
	var collider := CollisionShape3D.new()
	collider.shape = shape
	body.add_child(collider)
	var mesh := BoxMesh.new()
	mesh.size = size
	var visual := MeshInstance3D.new()
	visual.mesh = mesh
	visual.material_override = _material(color)
	body.add_child(visual)
	body.position = at
	add_child(body)
	return body


func _material(color: Color) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = 1.0
	# The sun is low and ahead; any specular turns the far ground into glare.
	material.metallic_specular = 0.0
	return material


func _kennel_hounds() -> void:
	_player = get_parent().get_node_or_null("Player") as Player
	if _player == null:
		return
	for start in KENNEL:
		var hound := Hound.new()
		hound.position = start
		hound.target = _player
		hound.low_poly = low_poly_hounds
		add_child(hound)
		hound.caught.connect(_on_caught.bind(hound))
		_hounds.append(hound)
	# Caught or fallen, the chase starts over.
	_player.respawned.connect(_recall_hounds)


func _physics_process(_delta: float) -> void:
	if _released or _player == null or _player.global_position.x < RELEASE_X:
		return
	_released = true
	for hound in _hounds:
		hound.chasing = true


func _recall_hounds() -> void:
	_released = false
	for hound in _hounds:
		hound.reset()


## A hound has him: he goes down, the pack stops, and the chase starts over.
func _on_caught(hound: Hound) -> void:
	if _player.is_limp:
		return
	var shove := (_player.global_position - hound.global_position).normalized() * 28.0 + Vector3.UP * 14.0
	_player.ragdoll(shove)
	for other in _hounds:
		other.chasing = false
	await get_tree().create_timer(2.2).timeout
	if _player.is_limp:
		_player.respawn()
