extends Node3D
## The tomb: a moonlit approach to a step pyramid, a torch-lit passage, and
## three chambers.
##
##  1. A plate holds the door open only while something stands on it: push the
##     block onto it.
##  2. A ledge too high to jump: push the block against it and climb.
##  3. The burial chamber. Moving the block wakes what is in the sarcophagus;
##     get the door open and get out. A pit beyond stops it following.
##
## Built in code, like the test course, so it is easy to retune. The side
## nearest the camera is left open, as a cutaway.

const Torch := TombParts.Torch
const Plate := TombParts.Plate
const Door := TombParts.Door

const DEPTH := 7.0
const CEILING := 4.4
const DOORWAY := 2.4
const SAND := Color(0.36, 0.31, 0.24)
const STONE := Color(0.3, 0.26, 0.2)
const DARK_STONE := Color(0.17, 0.15, 0.12)
const NIGHT := Color(0.035, 0.045, 0.07)
## Where the tomb's floor, walls and roof are cut, so no one piece is lit by
## more torches than a renderer will take.
const BAYS: Array[float] = [6.0, 18.0, 33.0, 46.0, 54.0, 70.0, 76.0, 78.2, 93.0]
const PIT := Vector2(76.0, 78.2)
## Passing each of these makes it the place to come back to.
const CHECKPOINTS: Array[float] = [19.5, 34.5, 55.0]

var _player: Player
var _mummy: Mummy
var _blocks: Array[RigidBody3D] = []
var _block_starts: Array[Transform3D] = []
var _burial_block: RigidBody3D
var _checkpoint := 0


func _ready() -> void:
	_build_night()
	_build_approach()
	_build_shell()
	_build_chambers()
	_settle_in.call_deferred()


func _build_night() -> void:
	var environment := Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = NIGHT
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color(0.3, 0.36, 0.5)
	environment.ambient_light_energy = 0.22
	environment.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	environment.fog_enabled = true
	environment.fog_light_color = NIGHT
	environment.fog_density = 0.02
	var world := WorldEnvironment.new()
	world.environment = environment
	add_child(world)

	# The moon, low and behind: it rims the figures outside and the pyramid
	# above shuts it out of the chambers.
	var moon := DirectionalLight3D.new()
	moon.rotation_degrees = Vector3(-36.0, 150.0, 0.0)
	moon.light_color = Color(0.62, 0.72, 1.0)
	moon.light_energy = 0.6
	moon.shadow_enabled = true
	moon.directional_shadow_mode = DirectionalLight3D.SHADOW_ORTHOGONAL
	moon.directional_shadow_max_distance = 50.0
	add_child(moon)

	# A faint fill from the camera's side; without it, figures lit only from
	# behind are bare silhouettes and the red shirt is lost.
	var fill := DirectionalLight3D.new()
	fill.rotation_degrees = Vector3(-16.0, 10.0, 0.0)
	fill.light_color = Color(0.9, 0.8, 0.7)
	fill.light_energy = 0.3
	add_child(fill)

	var disc := MeshInstance3D.new()
	var ball := SphereMesh.new()
	ball.radius = 2.6
	ball.height = 5.2
	disc.mesh = ball
	var glow := StandardMaterial3D.new()
	glow.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	glow.albedo_color = Color(0.75, 0.82, 0.95)
	glow.disable_fog = true
	disc.material_override = glow
	disc.position = Vector3(-13.0, 17.0, -70.0)
	add_child(disc)

	# A far wall of pure fog, so the sky matches the fog on every renderer.
	var sky := MeshInstance3D.new()
	var sheet := QuadMesh.new()
	sheet.size = Vector2(1200.0, 500.0)
	sky.mesh = sheet
	sky.material_override = _material(NIGHT)
	sky.position = Vector3(39.0, 120.0, -220.0)
	sky.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(sky)


## The desert outside the door.
func _build_approach() -> void:
	_box(StaticBody3D.new(), Vector3(-4.0, -2.0, -19.0), Vector3(20.0, 4.0, 62.0), SAND)
	_wall(Vector3(-14.5, 6.0, 0.0), Vector3(1.0, 14.0, DEPTH + 2.0))
	_wall(Vector3(-4.0, 6.0, DEPTH * 0.5 + 0.5), Vector3(20.0, 14.0, 1.0))
	_wall(Vector3(-4.0, 6.0, -DEPTH * 0.5 - 0.5), Vector3(20.0, 14.0, 1.0))
	# Dunes
	var random := RandomNumberGenerator.new()
	random.seed = 11
	for i in 7:
		var dune := MeshInstance3D.new()
		var mound := SphereMesh.new()
		mound.radius = random.randf_range(7.0, 16.0)
		mound.height = random.randf_range(2.0, 5.0)
		mound.radial_segments = 16
		mound.rings = 6
		dune.mesh = mound
		dune.material_override = _material(SAND.darkened(0.15))
		dune.position = Vector3(random.randf_range(-40.0, 4.0), -0.4, random.randf_range(-45.0, -9.0))
		add_child(dune)
	# A brazier each side of the way in
	for z: float in [-2.7, 2.7]:
		_prop(Vector3(4.9, 0.55, z), Vector3(0.34, 1.1, 0.34), DARK_STONE)
		_torch(Vector3(4.9, 1.05, z - 0.1), 2.0, z < 0.0)


## The pyramid itself: three tiers over the chambers, their back wall and floor.
func _build_shell() -> void:
	for i in BAYS.size() - 1:
		var from := BAYS[i]
		var to := BAYS[i + 1]
		var middle := (from + to) * 0.5
		var length := to - from
		if from != PIT.x:
			# Floor, running out towards the camera to fill the frame
			_box(StaticBody3D.new(), Vector3(middle, -2.0, -19.0), Vector3(length, 4.0, 62.0), STONE)
		_box(StaticBody3D.new(), Vector3(middle, CEILING * 0.5, -DEPTH * 0.5 - 0.5), Vector3(length, CEILING, 1.0), STONE)
		_box(StaticBody3D.new(), Vector3(middle, CEILING + 1.5, -13.25), Vector3(length, 3.0, 33.5), STONE)
		_glyphs(from + 0.6, to - 0.6)
	# The two tiers above only ever catch the moon.
	_prop(Vector3(51.0, 9.0, -13.25), Vector3(84.0, 3.2, 33.5), STONE)
	_prop(Vector3(52.5, 12.2, -13.25), Vector3(81.0, 3.2, 33.5), STONE)
	# The face it shows the desert, either side of and over the way in
	_prop(Vector3(6.5, CEILING * 0.5, -17.0), Vector3(1.0, CEILING, 26.0), STONE)
	_lintel(6.0, 7.0)
	_wall(Vector3(50.0, 6.0, DEPTH * 0.5 + 0.5), Vector3(88.0, 14.0, 1.0))
	_wall(Vector3(93.5, 6.0, 0.0), Vector3(1.0, 14.0, DEPTH + 2.0))
	# The pit: sheer sides going down into the dark
	_box(StaticBody3D.new(), Vector3((PIT.x + PIT.y) * 0.5, -9.0, -19.0), Vector3(PIT.y - PIT.x, 2.0, 62.0), Color.BLACK)


func _build_chambers() -> void:
	# --- The passage in
	_torch(Vector3(10.5, 2.3, -3.3), 2.4)
	_torch(Vector3(15.5, 2.3, -3.3), 2.4)
	_lintel(18.0, 19.0)
	_pillar(8.0)
	_pillar(13.0)

	# --- 1. The plate and the door
	_torch(Vector3(21.5, 2.3, -3.3), 2.4)
	_torch(Vector3(26.5, 2.3, -3.3), 2.6, true)
	_torch(Vector3(31.0, 2.3, -3.3), 2.4)
	_pillar(24.0)
	_pillar(29.0)
	_block(Vector3(22.5, 0.45, 0.0))
	var first_door := _door(33.0)
	_plate(28.5).changed.connect(func(pressed: bool) -> void: first_door.is_open = pressed)
	_kerb(29.6)
	_urn(Vector3(20.2, 0.0, -2.9), 0.9)
	_urn(Vector3(20.9, 0.0, -3.0), 0.6)

	# --- 2. The high ledge
	_torch(Vector3(36.5, 2.3, -3.3), 2.4)
	_torch(Vector3(42.0, 2.3, -3.3), 2.6, true)
	_torch(Vector3(50.0, 3.5, -3.3), 2.2)
	_pillar(39.5)
	_block(Vector3(37.5, 0.45, 0.0))
	_box(StaticBody3D.new(), Vector3(50.0, 0.95, 0.0), Vector3(8.0, 1.9, DEPTH), STONE.lightened(0.04))
	_urn(Vector3(44.6, 0.0, -2.9), 0.8)

	# --- 3. The burial chamber
	_torch(Vector3(56.2, 2.3, -3.3), 2.2)
	_torch(Vector3(63.5, 2.3, -3.3), 2.8, true)
	_torch(Vector3(68.5, 2.3, -3.3), 2.2)
	_pillar(60.5)
	_pillar(67.0)
	# The sarcophagus stands open against the wall, its lid leaning beside it
	_prop(Vector3(58.3, 1.2, -3.25), Vector3(1.15, 2.4, 0.5), DARK_STONE)
	_prop(Vector3(57.3, 1.15, -3.0), Vector3(0.14, 2.3, 0.9), Color(0.42, 0.33, 0.16)).rotation.z = 0.12
	_mummy = Mummy.new()
	_mummy.position = Vector3(58.3, 0.05, -2.6)
	add_child(_mummy)
	_burial_block = _block(Vector3(61.5, 0.45, 0.0))
	var last_door := _door(70.0)
	_plate(65.5).changed.connect(func(pressed: bool) -> void: last_door.is_open = pressed)
	_kerb(66.6)

	# --- The way out: the pit, then a doorway with the night beyond it
	_torch(Vector3(73.0, 2.3, -3.3), 2.4)
	_torch(Vector3(82.0, 2.3, -3.3), 2.4)
	var beyond := MeshInstance3D.new()
	var opening := QuadMesh.new()
	opening.size = Vector2(2.2, 3.0)
	beyond.mesh = opening
	var dawn := StandardMaterial3D.new()
	dawn.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	dawn.albedo_color = Color(0.55, 0.66, 0.85)
	dawn.disable_fog = true
	beyond.material_override = dawn
	beyond.position = Vector3(88.0, 1.5, -3.48)
	add_child(beyond)
	var spill := OmniLight3D.new()
	spill.light_color = Color(0.6, 0.72, 1.0)
	spill.light_energy = 2.6
	spill.omni_range = 9.0
	spill.position = Vector3(88.0, 1.6, -2.6)
	add_child(spill)


func _settle_in() -> void:
	_player = get_parent().get_node_or_null("Player") as Player
	if _player == null:
		return
	_player.kill_height = -5.0
	_player.respawned.connect(_restore)
	_mummy.target = _player
	_mummy.caught.connect(_on_caught)
	for block in _blocks:
		_block_starts.append(block.global_transform)


func _physics_process(_delta: float) -> void:
	if _player == null:
		return
	var at := _player.global_position
	if _checkpoint < CHECKPOINTS.size() and at.x > CHECKPOINTS[_checkpoint] and _player.is_on_floor():
		_player.set_spawn(Vector3(CHECKPOINTS[_checkpoint] + 0.3, at.y + 0.05, 0.0))
		_checkpoint += 1
	# It wakes when its block is shifted, or when he walks past it.
	var shifted := _burial_block.global_position.distance_to(_block_starts[_blocks.find(_burial_block)].origin) > 0.25
	if shifted or at.x > 60.5:
		_mummy.wake()


## It has him: he goes down, and the chamber is put back as it was.
func _on_caught() -> void:
	if _player.is_limp:
		return
	var shove := (_player.global_position - _mummy.global_position).normalized() * 22.0 + Vector3.UP * 10.0
	_player.ragdoll(shove)
	await get_tree().create_timer(2.4).timeout
	if _player.is_limp:
		_player.respawn()


func _restore() -> void:
	_mummy.reset()
	for i in _blocks.size():
		_blocks[i].linear_velocity = Vector3.ZERO
		_blocks[i].global_transform = _block_starts[i]


func _torch(at: Vector3, energy: float, shadows := false) -> void:
	var torch := Torch.new()
	torch.energy = energy
	torch.casts_shadows = shadows
	torch.position = at
	add_child(torch)


func _plate(x: float) -> Plate:
	var plate := Plate.new()
	plate.span = Vector3(1.5, 0.5, DEPTH)
	plate.position = Vector3(x, 0.0, 0.0)
	add_child(plate)
	return plate


## A doorway through a cross wall at `x`, and the slab that closes it.
func _door(x: float) -> Door:
	_lintel(x, x + 0.6)
	var door := Door.new(Vector3(0.5, DOORWAY, DEPTH), DARK_STONE.lightened(0.06))
	door.position = Vector3(x + 0.3, DOORWAY * 0.5, 0.0)
	add_child(door)
	return door


func _lintel(from_x: float, to_x: float) -> void:
	var size := Vector3(to_x - from_x, CEILING - DOORWAY, DEPTH)
	_box(StaticBody3D.new(), Vector3((from_x + to_x) * 0.5, DOORWAY + size.y * 0.5, 0.0), size, STONE.darkened(0.1))


## A low stop just past a plate: the player steps over it, a pushed block
## cannot, so the block always ends up on the plate and never beyond reach.
func _kerb(x: float) -> void:
	_box(StaticBody3D.new(), Vector3(x + 0.12, 0.125, 0.0), Vector3(0.24, 0.25, DEPTH), STONE.darkened(0.15))


func _block(at: Vector3) -> RigidBody3D:
	var block := RigidBody3D.new()
	block.mass = 20.0
	# Blocks slide rather than tumble, so they stay usable as steps.
	block.lock_rotation = true
	var surface := PhysicsMaterial.new()
	surface.friction = 0.6
	block.physics_material_override = surface
	_box(block, at, Vector3(0.9, 0.9, 0.9), Color(0.44, 0.37, 0.26))
	_blocks.append(block)
	return block


func _pillar(x: float) -> void:
	_prop(Vector3(x, CEILING * 0.5, -3.15), Vector3(0.6, CEILING, 0.6), STONE.lightened(0.05))
	_prop(Vector3(x, CEILING - 0.2, -3.15), Vector3(0.85, 0.4, 0.85), STONE.lightened(0.05))
	_prop(Vector3(x, 0.15, -3.15), Vector3(0.85, 0.3, 0.85), STONE.lightened(0.05))


func _urn(at: Vector3, height: float) -> void:
	var urn := MeshInstance3D.new()
	var pot := CylinderMesh.new()
	pot.top_radius = height * 0.16
	pot.bottom_radius = height * 0.24
	pot.height = height
	pot.radial_segments = 10
	urn.mesh = pot
	urn.material_override = _material(Color(0.36, 0.24, 0.15))
	urn.position = at + Vector3.UP * height * 0.5
	add_child(urn)


## A band of carved signs along the back wall between two points.
func _glyphs(from_x: float, to_x: float) -> void:
	var random := RandomNumberGenerator.new()
	random.seed = int(from_x * 31.0)
	var signs := MultiMesh.new()
	signs.transform_format = MultiMesh.TRANSFORM_3D
	signs.mesh = BoxMesh.new()
	var columns := int((to_x - from_x) / 0.42)
	signs.instance_count = columns * 3
	for column in columns:
		for row in 3:
			var size := Vector3(random.randf_range(0.08, 0.3), random.randf_range(0.1, 0.26), 0.04)
			var at := Vector3(from_x + column * 0.42 + random.randf_range(-0.05, 0.05), 2.75 + row * 0.36, -DEPTH * 0.5 + 0.01)
			signs.set_instance_transform(column * 3 + row, Transform3D(Basis.from_scale(size), at))
	var band := MultiMeshInstance3D.new()
	band.multimesh = signs
	band.material_override = _material(STONE.darkened(0.45))
	band.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(band)


## Scenery with no collision.
func _prop(at: Vector3, size: Vector3, color: Color) -> MeshInstance3D:
	var mesh := BoxMesh.new()
	mesh.size = size
	var visual := MeshInstance3D.new()
	visual.mesh = mesh
	visual.material_override = _material(color)
	visual.position = at
	add_child(visual)
	return visual


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
	# Torches and a low moon would turn any specular into glare.
	material.metallic_specular = 0.0
	return material
