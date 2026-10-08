class_name Hound
extends CharacterBody3D
## A hound that runs the player down, baying as it comes.
##
## It heads straight for its target, hops steps, leaps obstacles and gaps it can
## clear, and holds at the edge of one it cannot. Everything it needs (collider,
## model, voice) is made here, so `Hound.new()` is a complete hound.

signal caught
signal bayed

@export var run_speed := 5.4
@export var acceleration := 16.0
@export var turn_rate := 9.0
@export var jump_height := 1.3
@export var gravity := 24.0
## Touching distance: closer than this and the chase is over.
@export var catch_distance := 0.8
## The widest gap it will throw itself across.
@export var leap_distance := 2.8

var target: Player
var chasing := false
## Use the demade, low-poly model. Set before the hound enters the tree.
var low_poly := false
## Heading of the model, radians around Y. Zero faces +Z.
var facing_yaw := PI * 0.5
## Render-rate position; the rig follows this.
var visual_position := Vector3.ZERO

var _spawn := Transform3D.IDENTITY
var _prev_pos := Vector3.ZERO
var _curr_pos := Vector3.ZERO
var _jump_cooldown := 0.0
var _bay_timer := 0.0
var _held := false
var _voice: AudioStreamPlayer3D
var _rig: HoundRig

static var _voices: Array[AudioStreamWAV] = []


func _ready() -> void:
	add_to_group(&"hounds")
	# Hounds and the player pass through each other; only the world stops them.
	collision_layer = 4
	collision_mask = 1
	floor_snap_length = 0.25
	floor_max_angle = deg_to_rad(50.0)

	var shape := SphereShape3D.new()
	shape.radius = 0.26
	var collider := CollisionShape3D.new()
	collider.shape = shape
	collider.position.y = shape.radius
	add_child(collider)

	if _voices.is_empty():
		_voices = [_make_voice(true), _make_voice(false)]
	_voice = AudioStreamPlayer3D.new()
	_voice.unit_size = 14.0
	_voice.max_distance = 70.0
	_voice.position.y = 0.6
	add_child(_voice)

	_rig = HoundRig.new()
	_rig.low_poly = low_poly
	add_child(_rig)
	_rig.top_level = true

	_spawn = global_transform
	reset()


## Back to where it started, waiting to be let loose again.
func reset() -> void:
	global_transform = _spawn
	velocity = Vector3.ZERO
	chasing = false
	facing_yaw = PI * 0.5
	_bay_timer = randf_range(0.0, 0.6)
	_prev_pos = global_position
	_curr_pos = global_position
	visual_position = global_position


func _physics_process(delta: float) -> void:
	var grounded := is_on_floor()
	var wish := Vector3.ZERO
	_held = false
	_jump_cooldown -= delta
	if chasing and target:
		var to := target.global_position - global_position
		var flat := Vector3(to.x, 0.0, to.z)
		if flat.length() < catch_distance and absf(to.y) < 0.9:
			caught.emit()
			return
		wish = (flat.normalized() + _spread() * 0.6).normalized()
		if grounded:
			wish = _negotiate(wish, to)

	var current := Vector3(velocity.x, 0.0, velocity.z).move_toward(wish * run_speed, acceleration * delta)
	velocity.x = current.x
	velocity.z = current.z
	if not grounded:
		velocity.y -= gravity * delta
	move_and_slide()

	if chasing:
		_bay_timer -= delta
		if _bay_timer <= 0.0:
			_bay()
	if global_position.y < -15.0:
		reset()
	_prev_pos = _curr_pos
	_curr_pos = global_position


func _process(delta: float) -> void:
	visual_position = _prev_pos.lerp(_curr_pos, Engine.get_physics_interpolation_fraction())
	var heading := Vector3(velocity.x, 0.0, velocity.z)
	if _held and target:
		heading = target.global_position - global_position
		heading.y = 0.0
	if heading.length_squared() > 0.2:
		facing_yaw = lerp_angle(facing_yaw, atan2(heading.x, heading.z), 1.0 - exp(-turn_rate * delta))
	_rig.global_position = visual_position
	_rig.rotation = Vector3(0.0, facing_yaw, 0.0)


## Deals with whatever lies between here and there. Returns the direction to run.
func _negotiate(wish: Vector3, to: Vector3) -> Vector3:
	var here := global_position
	if not _ground_under(here + wish * 0.8):
		for reach: float in [1.7, leap_distance]:
			if _ground_under(here + wish * reach):
				_jump(jump_height * 0.6)
				return wish
		# Too far to leap: stand at the edge and give tongue.
		_held = true
		return Vector3.ZERO

	var hit := KinematicCollision3D.new()
	if test_move(global_transform, wish * 0.3, hit) and hit.get_normal().y < 0.6:
		# A step gets a hop, anything taller the full leap.
		var over_it := not test_move(global_transform.translated(Vector3.UP * 0.4), wish * 0.4)
		_jump(0.35 if over_it else jump_height)
	elif to.y > 0.7 and Vector2(to.x, to.z).length() < 1.6:
		_jump(jump_height)
	return wish


func _jump(height: float) -> void:
	if _jump_cooldown > 0.0:
		return
	_jump_cooldown = 0.3
	velocity.y = sqrt(2.0 * gravity * height)


func _ground_under(point: Vector3) -> bool:
	var query := PhysicsRayQueryParameters3D.create(point + Vector3.UP * 0.6, point + Vector3.DOWN * 1.2, 1)
	return not get_world_3d().direct_space_state.intersect_ray(query).is_empty()


## Keeps the pack from running as one dog.
func _spread() -> Vector3:
	var push := Vector3.ZERO
	for other: Hound in get_tree().get_nodes_in_group(&"hounds"):
		if other == self:
			continue
		var away := global_position - other.global_position
		away.y = 0.0
		var distance := away.length()
		if distance < 1.0 and distance > 0.001:
			push += away / distance * (1.0 - distance)
	return push


func _bay() -> void:
	# Mostly long bays; short barks when held up or closing in.
	var close := target != null and global_position.distance_to(target.global_position) < 4.0
	var bark := _held or (close and randf() < 0.6) or randf() < 0.2
	_voice.stream = _voices[1 if bark else 0]
	_voice.pitch_scale = randf_range(0.86, 1.12)
	_voice.play()
	_bay_timer = randf_range(0.35, 0.9) if bark else randf_range(0.9, 2.4)
	bayed.emit()


## Synthesises a hound's voice: a harmonic tone pushed through two throat
## resonances, with a rasp under it. `long` is a bay, otherwise a bark.
static func _make_voice(long: bool) -> AudioStreamWAV:
	const RATE := 22050
	var count := int((0.75 if long else 0.2) * RATE)
	var data := PackedByteArray()
	data.resize(count * 2)
	var noise := RandomNumberGenerator.new()
	noise.seed = 3
	var phase := 0.0
	for i in count:
		var t := float(i) / count
		# A bay swells up and falls away slowly; a bark just drops.
		var pitch := 230.0 + 210.0 * sin(PI * pow(t, 0.55)) if long else lerpf(520.0, 240.0, pow(t, 0.6))
		phase += TAU * pitch / RATE
		var sample := 0.0
		for harmonic in range(1, 9):
			var frequency := pitch * harmonic
			var throat := 0.25 + exp(-pow((frequency - 750.0) / 300.0, 2.0)) + 0.6 * exp(-pow((frequency - 1500.0) / 400.0, 2.0))
			sample += sin(phase * harmonic) * throat / harmonic
		sample *= 1.0 + 0.35 * sin(phase * 0.5)
		sample += noise.randf_range(-1.0, 1.0) * 0.08
		var envelope := smoothstep(0.0, 0.06, t) * (1.0 - smoothstep(0.6 if long else 0.3, 1.0, t))
		data.encode_s16(i * 2, int(clampf(sample * envelope * 0.45, -1.0, 1.0) * 32767.0))
	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = RATE
	stream.data = data
	return stream
