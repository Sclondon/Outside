class_name Medjed
extends CharacterBody3D
## Medjed, "the smiter", from spell 17 of the Book of the Dead: "I know the
## name of that smiter among them who belongs to the House of Osiris, who
## shoots with his eye, yet is unseen." The Greenfield papyrus draws him as a
## shroud with two eyes looking out of it and two bare feet under the hem, and
## that is all he is here: a sheet over a post, 0.8 m across at the
## hem and 1.5 m tall.
##
## He stands at his post and looks. His gaze is drawn on the floor as a pale
## fan of light, as far as `reach` and `cone` degrees wide, with a thin line
## from each eye down the middle of it; the fan stops at whatever stops his
## sight, so the shadow of a block is drawn too. He turns his whole body slowly
## from side to side through `sweep` degrees (360: round and round), waits
## `pause` at each end, and shuffles his feet as he turns.
##
## When the boy is in the gaze (within `reach`, inside the cone, and nothing
## solid between the eyes and both his chest and his head) the eyes go wide and
## bright, he stops and turns to follow him, the fan closes onto him and a
## sound rises, for `warning` seconds; if he is in sight at the end of them he
## is smitten: a flash, and `caught`. Out of sight in time, it dies down again.
## Anything solid hides him that covers his chest or his head: a wall, a pillar,
## a pushed block; something lower, if he ducks behind it.
##
## `unseen`: the shroud is not drawn until he fires, only the eyes, the feet and
## the gaze. `follows`: when he loses the boy he shuffles slowly to where he
## last saw him (no further than `roam` from his post, and no kerb or edge is
## crossed), looks, and shuffles home.
##
## He is on or off as a door is open or shut: set `worked` (the desert does,
## from what he is linked to) and he shuts his eyes and stands, or, with
## `wakes_when_worked`, opens them only then. A `Mirror` turned to face him
## sends his gaze back: he shuts his eyes for `dazzle` seconds and sweeps on
## blind. He cannot be hurt.
##
## It costs two rays a step of the game at most: one to the boy's chest and one
## to his head while he is in the cone, and otherwise one spoke of the fan,
## each in its turn. `Medjed.new()` is a whole one, facing along its own +Z.

signal caught

enum State { SWEEP, STARE, FIRED, SEEK, LOOK, HOME }

const TALL := 1.5
## How high his eyes are.
const EYES := 1.05
## How many spokes the fan on the floor has: each is felt out once in this many steps of the game.
const SPOKES := 11
## The shroud from the hem up: (height, radius).
const PROFILE: Array[Vector2] = [
	Vector2(0.16, 0.41), Vector2(0.23, 0.395), Vector2(0.45, 0.365), Vector2(0.7, 0.335), Vector2(0.92, 0.305), Vector2(1.1, 0.275),
	Vector2(1.24, 0.24), Vector2(1.35, 0.195), Vector2(1.43, 0.14), Vector2(1.48, 0.08), Vector2(1.5, 0.0),
]
const CLOTH := Color(0.86, 0.83, 0.75)
const SKIN := Color(0.66, 0.42, 0.3)
const PALE := Color(0.6, 0.84, 1.0)
const HOT := Color(1.0, 0.8, 0.45)

## The hem of the shroud swings: this is added to the figures' shader (`Toon.SHADER`).
const SWAY := """
// How far the hem is pushed aside (metres, in his own x and z), how far it is wound round him (radians), and the time.
uniform vec2 sway = vec2(0.0);
uniform float twist = 0.0;
uniform float flutter = 0.0;

void vertex() {
	float low = clamp(1.0 - (VERTEX.y - 0.16) / 0.8, 0.0, 1.0);
	low *= low;
	float about = atan(VERTEX.x, VERTEX.z);
	float wound = twist * low;
	VERTEX.xz = vec2(VERTEX.x * cos(wound) + VERTEX.z * sin(wound), VERTEX.z * cos(wound) - VERTEX.x * sin(wound));
	VERTEX.xz += sway * low + normalize(VERTEX.xz + vec2(0.0001)) * sin(about * 3.0 + flutter) * 0.018 * low;
	VERTEX.y += sin(about * 2.0 - flutter * 0.7) * 0.012 * low;
}
"""

## The eyes: an almond with a dark line round it, a dark pupil, and a heavy brow, drawn on a patch of the shroud.
const EYE_SHADER := """
shader_type spatial;
render_mode cull_back;

// 0: shut. 1: as he usually has them. More: wide.
uniform float open = 1.0;
uniform float glow = 0.2;
// Where he is looking, -1..1 to his left and up.
uniform vec2 look = vec2(0.0);
uniform vec3 pale : source_color = vec3(0.97, 0.95, 0.88);
uniform vec3 dark : source_color = vec3(0.07, 0.06, 0.07);
uniform vec3 shine : source_color = vec3(1.0, 0.9, 0.65);

void fragment() {
	// (metres on the cloth, from the middle of the eye; x runs outwards)
	vec2 p = vec2((UV.x - 0.5) * 0.2, (UV.y - 0.42) * 0.2);
	float half_wide = 0.078;
	float along = clamp(1.0 - (p.x * p.x) / (half_wide * half_wide), 0.0, 1.0);
	float lid = 0.037 * open * along;
	float pixel = max(fwidth(p.y), 0.0004);
	float inside = (1.0 - smoothstep(-pixel, pixel, abs(p.y) - lid)) * step(abs(p.x), half_wide) * smoothstep(0.001, 0.005, lid);
	float rim = 1.0 - smoothstep(-pixel, pixel, abs(p.y) - lid - 0.011);
	rim *= 1.0 - smoothstep(-pixel, pixel, abs(p.x) - half_wide - 0.016);
	float arch = 0.06 + 0.015 * along + 0.014 * (open - 1.0);
	float brow = 1.0 - smoothstep(-pixel, pixel, abs(p.y - arch) - 0.013);
	brow *= 1.0 - smoothstep(-pixel, pixel, abs(p.x) - half_wide - 0.012);
	if (max(rim, brow) < 0.5) {
		discard;
	}
	vec2 middle = vec2(look.x * UV2.x * 0.03, look.y * 0.008);
	float pupil = 1.0 - smoothstep(-pixel, pixel, length(p - middle) - 0.027);
	float white = inside * (1.0 - pupil);
	ALBEDO = mix(dark, pale, white);
	EMISSION = shine * glow * white;
	ROUGHNESS = 1.0;
	SPECULAR = 0.0;
}
"""

## The gaze on the floor: laid over what is there, so it shows on pale sand as well as in the dark.
const FLOOR_SHADER := """
shader_type spatial;
render_mode unshaded, blend_mix, depth_draw_never, cull_disabled, shadows_disabled, fog_disabled;

uniform vec4 colour : source_color = vec4(0.72, 0.9, 1.0, 1.0);
uniform float strength = 0.3;
uniform float clock = 0.0;

void fragment() {
	// Soft at its sides and where it starts, and rings of it run outwards.
	float across = 1.0 - abs(UV.x * 2.0 - 1.0);
	float side = smoothstep(0.0, 0.05, across);
	float edge = 1.0 - smoothstep(0.05, 0.14, across);
	float start = smoothstep(0.04, 0.14, UV.y);
	float rings = 0.8 + 0.2 * sin(UV.y * 46.0 - clock * 4.0);
	ALBEDO = colour.rgb;
	ALPHA = clamp(strength * start * side * (rings + edge * 0.9), 0.0, 1.0);
}
"""

## The two lines from his eyes: light added to what is behind it, as a `SunBeam` is.
const LINE_SHADER := """
shader_type spatial;
render_mode unshaded, blend_add, depth_draw_never, cull_disabled, shadows_disabled, fog_disabled;

uniform vec4 colour : source_color = vec4(0.72, 0.9, 1.0, 1.0);
uniform float strength = 0.2;
// 0: it fades away along its length. 1: it is as bright at the far end.
uniform float held = 0.0;

void fragment() {
	float across = 1.0 - abs(UV.x * 2.0 - 1.0);
	float soft = across * across * (3.0 - 2.0 * across);
	ALBEDO = colour.rgb;
	ALPHA = clamp((soft * 0.6 + pow(across, 8.0) * 0.6) * strength * mix(1.0 - UV.y * 0.85, 1.0, held), 0.0, 1.0);
}
"""

## How far he turns from side to side, degrees, about the way he is put. 360: he turns round and round.
@export var sweep := 90.0
## How fast he turns, degrees a second.
@export var turn_speed := 30.0
## How long he waits at each end of the sweep, seconds.
@export var pause := 1.0
## How far he sees, metres.
@export var reach := 9.0
## How wide his gaze is, degrees.
@export var cone := 30.0
## How long the boy has to get out of sight, seconds.
@export var warning := 0.6
## The shroud is not drawn until he fires: only the eyes, the feet and the gaze.
@export var unseen := false
## When he loses sight of the boy he goes a little way to where he last saw him, and then home.
@export var follows := false
## How far from his post he will go, metres.
@export var roam := 3.0
## How fast he shuffles, metres a second. Never fast.
@export var shuffle_speed := 0.5
## How fast he turns to follow the boy once he has seen him, degrees a second.
@export var tracks := 70.0
## Which way round being worked goes: as it is, what he is linked to shuts his eyes; with this, it opens them.
@export var wakes_when_worked := false
## How long a mirror that sends his gaze back shuts his eyes, seconds. 0: mirrors do nothing to him.
@export var dazzle := 4.0
## Whether he makes any sound.
@export var voice := true
@export var gravity := 24.0

## Whether what he is linked to is on. (See `wakes_when_worked`.)
var worked := false
## Whom he looks for. Left empty, he finds the player himself (`Nearby.player`).
var target: Player
var state := State.SWEEP
## How near to firing he is, 0..1.
var charge := 0.0
## Whether he can see the boy at this moment.
var sees := false
## Which way he faces, radians round Y, in the world. Zero is +Z.
var facing_yaw := 0.0
## How many times he has smitten the boy.
var smitten := 0
## How many rays he cast in the last step of the game.
var rays_cast := 0

var _figure: Node3D
var _shroud: MeshInstance3D
var _cloth: ShaderMaterial
var _eyes: ShaderMaterial
var _feet: Array[MeshInstance3D] = []
var _floor: MeshInstance3D
var _floor_material: ShaderMaterial
var _lines: MeshInstance3D
var _line_material: ShaderMaterial
var _flash_light: OmniLight3D
var _hum: AudioStreamPlayer3D
var _sound: AudioStreamPlayer3D

var _post := Vector3.ZERO
var _home_yaw := 0.0
var _way := 1.0
var _hold := 0.0
var _rest := 0.0
var _dazzled := 0.0
var _proof := 0.0
var _last_seen := Vector3.ZERO
var _goal := Vector3.ZERO
var _seeking := 0.0
var _stuck := 0.0
var _grounded := false
var _tick := 0
var _rays := 0
var _spokes := PackedFloat32Array()
var _spoke := 0
var _watched := true
# What is only for the eye: the lids, the light of the eyes, the flash, the shroud of one that is unseen, and the swing of the hem.
var _lid := 1.0
var _flash := 0.0
var _shown := 0.0
var _step := 0.0
var _turned := 0.0
var _spin := 0.0
var _twist := 0.0
var _twist_speed := 0.0
var _lean := Vector2.ZERO
var _lean_speed := Vector2.ZERO
var _clock := 0.0
var _foot_down := 0

static var _shroud_mesh: ArrayMesh
static var _eye_mesh: ArrayMesh
static var _foot_mesh: ArrayMesh
static var _shaders := {}
static var _streams := {}


func _ready() -> void:
	add_to_group(&"medjeds")
	# The boy walks through him; the world stops him.
	collision_layer = 4
	collision_mask = 1
	floor_snap_length = 0.2
	set_meta(&"surface", &"soft")
	# (flat underneath, so that any kerb stops him)
	var shape := CylinderShape3D.new()
	shape.radius = 0.28
	shape.height = TALL
	var collider := CollisionShape3D.new()
	collider.shape = shape
	collider.position.y = TALL * 0.5
	add_child(collider)

	_figure = Node3D.new()
	add_child(_figure)
	_cloth = ShaderMaterial.new()
	_cloth.shader = _shader(&"cloth", Toon.SHADER + SWAY)
	_cloth.set_shader_parameter(&"albedo", CLOTH)
	_cloth.set_shader_parameter(&"wrap", 0.25)
	_shroud = MeshInstance3D.new()
	_shroud.mesh = _shroud_shape()
	_shroud.material_override = _cloth
	_figure.add_child(_shroud)
	_eyes = ShaderMaterial.new()
	_eyes.shader = _shader(&"eyes", EYE_SHADER)
	var eyes := MeshInstance3D.new()
	eyes.mesh = _eye_shape()
	eyes.material_override = _eyes
	eyes.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_figure.add_child(eyes)
	for side: float in [-1.0, 1.0]:
		var foot := MeshInstance3D.new()
		foot.mesh = _foot_shape()
		foot.material_override = Toon.surface(SKIN)
		foot.position = Vector3(side * 0.12, 0.0, 0.0)
		foot.rotation.y = side * 0.14
		_figure.add_child(foot)
		_feet.append(foot)

	_floor_material = ShaderMaterial.new()
	_floor_material.shader = _shader(&"floor", FLOOR_SHADER)
	_floor = MeshInstance3D.new()
	_floor.mesh = ImmediateMesh.new()
	_floor.material_override = _floor_material
	_floor.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_floor)
	_line_material = ShaderMaterial.new()
	_line_material.shader = _shader(&"lines", LINE_SHADER)
	_lines = MeshInstance3D.new()
	_lines.mesh = ImmediateMesh.new()
	_lines.material_override = _line_material
	_lines.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_figure.add_child(_lines)
	_flash_light = OmniLight3D.new()
	_flash_light.position = Vector3(0.0, EYES, 0.5)
	_flash_light.omni_range = 9.0
	_flash_light.light_color = HOT
	_flash_light.visible = false
	_figure.add_child(_flash_light)
	if voice:
		_hum = AudioStreamPlayer3D.new()
		_hum.stream = _stream(&"hum")
		_hum.unit_size = 5.0
		_hum.max_distance = 40.0
		_hum.position.y = EYES
		add_child(_hum)
		_sound = AudioStreamPlayer3D.new()
		_sound.unit_size = 7.0
		_sound.max_distance = 50.0
		_sound.position.y = EYES
		add_child(_sound)

	_spokes.resize(SPOKES)
	_post = global_position
	_home_yaw = global_basis.get_euler().y
	reset()


## Whether his eyes are shut: by what works him, or by his own gaze in a mirror.
func is_shut() -> bool:
	return worked != wakes_when_worked or _dazzled > 0.0


## Where his eyes are, in the world.
func eye_point() -> Vector3:
	return global_position + Vector3(sin(facing_yaw) * 0.3, EYES, cos(facing_yaw) * 0.3)


## Which way he is looking, over the ground.
func forward() -> Vector3:
	return Vector3(sin(facing_yaw), 0.0, cos(facing_yaw))


## Where he stands when he is not after anyone.
func post() -> Vector3:
	return _post


## Back at his post, looking the way he was put, as if he had seen nothing.
func reset() -> void:
	global_position = _post
	velocity = Vector3.ZERO
	state = State.SWEEP
	facing_yaw = _home_yaw
	charge = 0.0
	sees = false
	_way = 1.0
	_hold = 0.0
	_rest = 0.0
	_dazzled = 0.0
	_proof = 0.0
	_seeking = 0.0
	_flash = 0.0
	_shown = 0.0
	_grounded = false
	_spokes.fill(reach)


func _physics_process(delta: float) -> void:
	_tick += 1
	_rays = 2
	var boy := target if target else Nearby.player(get_tree())
	_watched = boy == null or boy.global_position.distance_squared_to(global_position) < (reach + 45.0) * (reach + 45.0)
	_dazzled = maxf(_dazzled - delta, 0.0)
	_proof = maxf(_proof - delta, 0.0)
	var before := facing_yaw
	var asleep := worked != wakes_when_worked
	var shut := asleep or _dazzled > 0.0
	sees = not shut and boy != null and _watched and _in_sight(boy)
	if sees:
		_last_seen = boy.global_position

	var moving := false
	if shut:
		# Blind: the charge goes, and he gives up whatever he was about. Dazzled, he sweeps on; asleep, he stands.
		charge = move_toward(charge, 0.0, delta * 3.0)
		if state != State.SWEEP and state != State.HOME:
			state = State.SWEEP if _at_post() else State.HOME
		if not asleep and state == State.SWEEP:
			_sweep(delta)
	else:
		match state:
			State.SWEEP:
				# (he stood here, or was put here: this is his post)
				_post = global_position
				_home_yaw = global_basis.get_euler().y
				if sees:
					state = State.STARE
				else:
					charge = move_toward(charge, 0.0, delta / maxf(warning * 2.0, 0.05))
					_sweep(delta)
			State.STARE:
				if sees:
					_turn_to(boy.global_position, deg_to_rad(tracks) * delta)
					charge += delta / maxf(warning, 0.02)
					if charge >= 1.0:
						_smite()
				else:
					charge -= delta / maxf(warning * 2.0, 0.05)
					if charge <= 0.0:
						charge = 0.0
						if follows:
							state = State.SEEK
							_seeking = 0.0
							_stuck = 0.0
							var out := _last_seen - _post
							out.y = 0.0
							_goal = _post + out.limit_length(roam)
						else:
							state = State.SWEEP if _at_post() else State.HOME
			State.FIRED:
				_rest -= delta
				if _rest <= 0.0:
					state = State.SWEEP if _at_post() else State.HOME
			State.SEEK:
				charge = move_toward(charge, 0.0, delta / maxf(warning * 2.0, 0.05))
				_seeking += delta
				moving = true
				if sees:
					state = State.STARE
				elif _shuffle(_goal, delta) or _seeking > 20.0:
					state = State.LOOK
					_rest = 1.6
			State.LOOK:
				_rest -= delta
				if sees:
					state = State.STARE
				elif _rest <= 0.0:
					state = State.HOME
					_stuck = 0.0
			State.HOME:
				charge = move_toward(charge, 0.0, delta / maxf(warning * 2.0, 0.05))
				moving = true
				if sees:
					state = State.STARE
				elif _shuffle(_post, delta):
					if Vector2(global_position.x - _post.x, global_position.z - _post.z).length() < 0.02:
						global_position = Vector3(_post.x, global_position.y, _post.z)
					else:
						# (something is in his way home: where he has got to is his post now)
						_post = global_position
					state = State.SWEEP

	# He stands on the ground: he falls to it when he is put in, and is looked at again now and then.
	if not moving:
		velocity.x = 0.0
		velocity.z = 0.0
		if not _grounded or _tick % 90 == 0:
			velocity.y -= gravity * delta
			move_and_slide()
			_grounded = is_on_floor()
			if _grounded:
				velocity.y = 0.0
				if state == State.SWEEP:
					_post = global_position
	if _rays > 0 and not shut and _watched:
		_feel()
	rays_cast = 2 - _rays
	_turned = angle_difference(before, facing_yaw) / maxf(delta, 0.0001)


func _at_post() -> bool:
	return Vector2(global_position.x - _post.x, global_position.z - _post.z).length() < 0.1


# From side to side about the way he was put, waiting at each end; or round and round.
func _sweep(delta: float) -> void:
	var rate := deg_to_rad(turn_speed) * delta
	if sweep >= 359.0:
		facing_yaw = wrapf(facing_yaw + rate * _way, -PI, PI)
		return
	var half := deg_to_rad(sweep) * 0.5
	var swing := angle_difference(_home_yaw, facing_yaw)
	if absf(swing) > half + 0.001:
		# (he has been looking at something off to one side: he comes back to his own ground first)
		swing = move_toward(swing, clampf(swing, -half, half), rate)
	elif _hold > 0.0:
		_hold -= delta
	else:
		swing += rate * _way
		if absf(swing) >= half:
			swing = half * _way
			_way = -_way
			_hold = pause
	facing_yaw = wrapf(_home_yaw + swing, -PI, PI)


func _turn_to(point: Vector3, by: float) -> void:
	var to := point - global_position
	if Vector2(to.x, to.z).length_squared() < 0.01:
		return
	var want := atan2(to.x, to.z)
	facing_yaw = wrapf(facing_yaw + clampf(angle_difference(facing_yaw, want), -by, by), -PI, PI)


# Whether the boy is in the gaze: near enough, inside the cone, and nothing solid between the eyes and his chest and his head.
func _in_sight(boy: Player) -> bool:
	if boy.is_limp:
		return false
	var to := boy.global_position - global_position
	var flat := Vector2(to.x, to.z)
	var far := flat.length()
	if far > reach or absf(to.y) > 3.0:
		return false
	# (once he has him, he does not lose him at the very edge of the cone)
	var half := deg_to_rad(cone) * 0.5 + (0.14 if state == State.STARE else 0.0)
	if far > 0.6 and absf(angle_difference(facing_yaw, atan2(to.x, to.z))) > half:
		return false
	var tall := 0.5 if boy.is_crawling else (boy.crouch_height if boy.is_ducking else boy.stand_height)
	var from := eye_point()
	var hidden: Array[RID] = [get_rid()]
	if boy.carried:
		hidden.append(boy.carried.get_rid())
	var space := get_world_3d().direct_space_state
	for share: float in [0.6, 0.9]:
		var query := PhysicsRayQueryParameters3D.create(from, boy.global_position + Vector3.UP * tall * share, 1, hidden)
		_rays -= 1
		if not space.intersect_ray(query).is_empty():
			return false
	return true


# One spoke of the fan on the floor is felt out: how far along it a boy's chest would be seen. And if what stops
# it is a mirror turned to face him, his own gaze comes back at him.
func _feel() -> void:
	_spoke = (_spoke + 1) % SPOKES
	var round := facing_yaw + (float(_spoke) / (SPOKES - 1) - 0.5) * deg_to_rad(cone)
	var out := Vector3(sin(round), 0.0, cos(round))
	var from := eye_point()
	var query := PhysicsRayQueryParameters3D.create(from, global_position + out * reach + Vector3.UP * 0.75, 1, [get_rid()])
	_rays -= 1
	var hit := get_world_3d().direct_space_state.intersect_ray(query)
	if hit.is_empty():
		_spokes[_spoke] = reach
		return
	var at: Vector3 = hit["position"]
	_spokes[_spoke] = Vector2(at.x - global_position.x, at.z - global_position.z).length()
	var mirror := Mirror.of(hit["collider"])
	if mirror and dazzle > 0.0 and _proof <= 0.0 and absf(mirror.normal().dot((from - at).normalized())) > 0.93:
		_dazzled = dazzle
		# (and when he opens them he has a moment before it can happen again)
		_proof = dazzle + 0.4


# He shuffles to a place: turns to it first, then goes, slowly. Says when he has got there, or can get no nearer.
func _shuffle(point: Vector3, delta: float) -> bool:
	var to := point - global_position
	to.y = 0.0
	var far := to.length()
	if far < 0.01:
		return true
	var way := to / far
	_turn_to(point, deg_to_rad(tracks) * delta)
	velocity.x = 0.0
	velocity.z = 0.0
	var stopped := false
	if absf(angle_difference(facing_yaw, atan2(way.x, way.z))) < 0.3:
		# No kerb is stepped up, and no edge stepped off.
		var hit := KinematicCollision3D.new()
		if test_move(global_transform.translated(Vector3.UP * 0.02), way * 0.12, hit) and hit.get_normal().y < 0.7:
			stopped = true
		elif _rays > 0 and _tick % 3 == 0:
			var ahead := global_position + way * 0.5
			_rays -= 1
			stopped = get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(ahead + Vector3.UP * 0.4, ahead + Vector3.DOWN * 0.4, 1, [get_rid()])).is_empty()
		if not stopped:
			var pace := minf(shuffle_speed, far / maxf(delta, 0.0001))
			velocity.x = way.x * pace
			velocity.z = way.z * pace
	if not is_on_floor():
		velocity.y -= gravity * delta
	var was := global_position
	move_and_slide()
	_grounded = is_on_floor()
	if velocity.x != 0.0 or velocity.z != 0.0 or stopped:
		_stuck = _stuck + delta if stopped or was.distance_to(global_position) < shuffle_speed * delta * 0.3 else 0.0
	return _stuck > 0.4


func _smite() -> void:
	charge = 0.0
	state = State.FIRED
	_rest = 2.6
	_flash = 1.0
	_shown = 3.0
	smitten += 1
	if _sound:
		_sound.stream = _stream(&"smite")
		_sound.play()
	caught.emit()


func _process(delta: float) -> void:
	_clock += delta
	var shut := is_shut()
	var staring := state == State.STARE or state == State.FIRED
	_lid = move_toward(_lid, 0.0 if shut else (1.5 if staring else 1.0), delta * 7.0)
	_flash = maxf(_flash - delta * 2.6, 0.0)
	_shown = maxf(_shown - delta, 0.0)
	var boy := target if target else Nearby.player(get_tree())

	_figure.global_basis = Basis(Vector3.UP, facing_yaw)
	# The hem is left behind as he turns and goes, and swings on after he stops.
	var flat_speed := Vector2(velocity.x, velocity.z).rotated(facing_yaw)
	_twist_speed += ((-_turned * 0.22 - _twist) * 60.0 - _twist_speed * 5.0) * delta
	_twist = clampf(_twist + _twist_speed * delta, -0.6, 0.6)
	_lean_speed += ((-flat_speed * 0.12 - _lean) * 50.0 - _lean_speed * 4.5) * delta
	_lean = (_lean + _lean_speed * delta).limit_length(0.12)
	_cloth.set_shader_parameter(&"twist", _twist)
	_cloth.set_shader_parameter(&"sway", _lean)
	_cloth.set_shader_parameter(&"flutter", _clock * 1.7)
	_shroud.visible = not unseen or _shown > 0.0

	# His feet: one and then the other, a little way, as he turns or goes.
	var busy := absf(_turned) * 0.25 + Vector2(velocity.x, velocity.z).length()
	_step += busy * delta * 5.0
	var settle := clampf(busy * 6.0, 0.0, 1.0)
	for i in 2:
		var beat := sin(_step * PI + i * PI)
		var foot := _feet[i]
		foot.position.y = maxf(beat, 0.0) * 0.045 * settle
		foot.position.z = cos(_step * PI + i * PI) * 0.035 * settle
		foot.rotation.x = -maxf(beat, 0.0) * 0.25 * settle
	var down := int(floorf(_step))
	if down != _foot_down:
		_foot_down = down
		if _sound and not _sound.playing and _watched:
			_sound.stream = _stream(&"pat")
			_sound.play()
	_shroud.position.y = absf(sin(_step * PI)) * 0.012 * settle
	_shroud.rotation.z = sin(_step * PI) * 0.025 * settle

	# His eyes: where they look, how wide, how bright.
	var aim := Vector3.ZERO
	var look := Vector2(clampf(_turned * 0.8, -1.0, 1.0), 0.0)
	if boy and staring:
		aim = boy.global_position + Vector3.UP * (boy.crouch_height if boy.is_ducking else boy.stand_height) * 0.6
		var side := angle_difference(facing_yaw, atan2(aim.x - global_position.x, aim.z - global_position.z))
		look = Vector2(clampf(side * 4.0, -1.0, 1.0), -0.5)
	_eyes.set_shader_parameter(&"open", _lid)
	_eyes.set_shader_parameter(&"look", look)
	_eyes.set_shader_parameter(&"glow", (0.5 + charge * 2.2 + _flash * 4.0) * clampf(_lid, 0.0, 1.0))
	_flash_light.visible = _flash > 0.01
	_flash_light.light_energy = _flash * 8.0

	if _hum:
		if charge > 0.02 and not _hum.playing:
			_hum.play()
		elif charge <= 0.02 and _hum.playing:
			_hum.stop()
		_hum.pitch_scale = 0.7 + charge * 1.5
		_hum.volume_db = linear_to_db(clampf(0.25 + charge, 0.0, 1.0))

	_draw_gaze(clampf(_lid, 0.0, 1.0) if _watched else 0.0, aim if staring and aim != Vector3.ZERO else Vector3.INF)


# The fan on the floor, and the line from each eye. `aim`: what he stares at, if anything.
func _draw_gaze(open: float, aim: Vector3) -> void:
	var fan := _floor.mesh as ImmediateMesh
	var lines := _lines.mesh as ImmediateMesh
	fan.clear_surfaces()
	lines.clear_surfaces()
	if open <= 0.02:
		return
	var heat := clampf(maxf(charge, _flash), 0.0, 1.0)
	var colour := PALE.lerp(HOT, heat).lerp(Color.WHITE, _flash)
	_floor_material.set_shader_parameter(&"colour", colour)
	_floor_material.set_shader_parameter(&"strength", open * (0.34 + heat * 0.4))
	_floor_material.set_shader_parameter(&"clock", _clock)
	_line_material.set_shader_parameter(&"colour", colour)
	_line_material.set_shader_parameter(&"strength", open * (0.3 + heat * 1.2 + _flash * 2.0))
	_line_material.set_shader_parameter(&"held", heat)

	# The fan lies on the floor he stands on, tipped as it is, and closes onto what he stares at.
	var ground := get_floor_normal() if _grounded and get_floor_normal().y > 0.5 else Vector3.UP
	_floor.global_basis = Basis(Quaternion(Vector3.UP, ground)) * Basis(Vector3.UP, facing_yaw)
	var bearing := 0.0
	var cap := reach
	var close := 0.0
	if aim != Vector3.INF:
		var to := aim - global_position
		bearing = angle_difference(facing_yaw, atan2(to.x, to.z))
		cap = minf(Vector2(to.x, to.z).length() + 0.5, reach)
		close = heat
	var wide := deg_to_rad(cone) * lerpf(1.0, 0.2, close)
	fan.surface_begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in SPOKES - 1:
		for k: int in [-1, 0, 1]:
			if k < 0:
				fan.surface_set_uv(Vector2((i + 0.5) / (SPOKES - 1), 0.0))
				fan.surface_add_vertex(Vector3(0.0, 0.04, 0.0))
				continue
			var share := float(i + k) / (SPOKES - 1)
			var round := bearing * close + (share - 0.5) * wide
			var long := lerpf(_spokes[i + k], cap, close)
			fan.surface_set_uv(Vector2(share, long / maxf(reach, 0.1)))
			fan.surface_add_vertex(Vector3(sin(round) * long, 0.04, cos(round) * long))
	fan.surface_end()

	# The lines: from each eye to the middle of the far end of the fan, or to him.
	var far := _spokes[SPOKES / 2]
	var to_point := Vector3(0.0, 0.75, far)
	if aim != Vector3.INF:
		to_point = to_point.lerp(_figure.to_local(aim), clampf(close * 3.0, 0.0, 1.0))
	var width := 0.035 + _flash * 0.1
	lines.surface_begin(Mesh.PRIMITIVE_TRIANGLES)
	for x: float in [-0.1, 0.1]:
		var a := Vector3(x, EYES - 0.01, 0.3)
		var run := to_point - a
		if run.length() < 0.05:
			continue
		var along := run.normalized()
		var side := along.cross(Vector3.UP).normalized()
		for turn in 2:
			var out := side.rotated(along, turn * PI * 0.5) * width * 0.5
			var corners := [[a - out, Vector2(0.0, 0.0)], [a + out, Vector2(1.0, 0.0)], [to_point + out, Vector2(1.0, 1.0)], [to_point - out, Vector2(0.0, 1.0)]]
			for corner: int in [0, 1, 2, 0, 2, 3]:
				lines.surface_set_uv(corners[corner][1])
				lines.surface_add_vertex(corners[corner][0])
	lines.surface_end()


static func _shader(named: StringName, code: String) -> Shader:
	if not _shaders.has(named):
		var made := Shader.new()
		made.code = code
		_shaders[named] = made
	return _shaders[named]


## How wide the shroud is at a height.
static func radius_at(height: float) -> float:
	for i in PROFILE.size() - 1:
		if height <= PROFILE[i + 1].x:
			return lerpf(PROFILE[i].y, PROFILE[i + 1].y, clampf(inverse_lerp(PROFILE[i].x, PROFILE[i + 1].x, height), 0.0, 1.0))
	return 0.0


# The shroud: the profile turned round, with a few soft folds that deepen towards the hem.
static func _shroud_shape() -> ArrayMesh:
	if _shroud_mesh:
		return _shroud_mesh
	const SIDES := 20
	var tool := SurfaceTool.new()
	tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	var rings := PROFILE.size()
	for i in rings:
		var here := PROFILE[i]
		var below := PROFILE[maxi(i - 1, 0)]
		var above := PROFILE[mini(i + 1, rings - 1)]
		var slope := Vector2(above.x - below.x, below.y - above.y).normalized()
		var low := pow(clampf(1.0 - (here.x - 0.16) / 1.0, 0.0, 1.0), 2.0)
		for j in SIDES + 1:
			var round := TAU * j / SIDES
			var out := Vector3(sin(round), 0.0, cos(round))
			var fold := sin(round * 5.0 + 1.0) * 0.024 * low
			tool.set_normal(Vector3(out.x * slope.x, slope.y, out.z * slope.x).normalized())
			tool.set_uv(Vector2(float(j) / SIDES, here.x / TALL))
			tool.add_vertex(out * (here.y + fold) + Vector3.UP * (here.x + (sin(round * 5.0 + 2.2) * 0.02 if i == 0 else 0.0)))
	for i in rings - 1:
		for j in SIDES:
			var a := i * (SIDES + 1) + j
			var c := a + SIDES + 1
			for index: int in [a, c, c + 1, a, c + 1, a + 1]:
				tool.add_index(index)
	_shroud_mesh = tool.commit()
	return _shroud_mesh


# The two patches of cloth the eyes are drawn on, a little off the shroud.
static func _eye_shape() -> ArrayMesh:
	if _eye_mesh:
		return _eye_mesh
	const ACROSS := 5
	const ROWS := 3
	var tool := SurfaceTool.new()
	tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	var start := 0
	for side: float in [-1.0, 1.0]:
		for v in ROWS + 1:
			var height := lerpf(EYES - 0.094, EYES + 0.106, float(v) / ROWS)
			var wide := radius_at(height) + 0.007
			for u in ACROSS + 1:
				var round := side * (0.035 + 0.2 / radius_at(EYES) * float(u) / ACROSS)
				var out := Vector3(sin(round), 0.0, cos(round))
				tool.set_normal((out + Vector3.UP * 0.17).normalized())
				tool.set_uv(Vector2(float(u) / ACROSS, float(v) / ROWS))
				tool.set_uv2(Vector2(side, 0.0))
				tool.add_vertex(out * wide + Vector3.UP * height)
		for v in ROWS:
			for u in ACROSS:
				var a := start + v * (ACROSS + 1) + u
				var c := a + ACROSS + 1
				var order: Array[int] = [a, c, c + 1, a, c + 1, a + 1]
				if side < 0.0:
					order.reverse()
				for index in order:
					tool.add_index(index)
		start += (ACROSS + 1) * (ROWS + 1)
	_eye_mesh = tool.commit()
	return _eye_mesh


# A bare foot and the ankle over it, toes forward (+Z), out from under the hem.
static func _foot_shape() -> ArrayMesh:
	if _foot_mesh:
		return _foot_mesh
	var tool := SurfaceTool.new()
	var ball := SphereMesh.new()
	ball.radius = 0.5
	ball.height = 1.0
	ball.radial_segments = 8
	ball.rings = 4
	# (the foot, and a rounder ball for the toes)
	tool.append_from(ball, 0, Transform3D(Basis.from_scale(Vector3(0.1, 0.07, 0.25)), Vector3(0.0, 0.035, 0.36)))
	tool.append_from(ball, 0, Transform3D(Basis.from_scale(Vector3(0.118, 0.045, 0.09)), Vector3(0.0, 0.024, 0.45)))
	var shin := CylinderMesh.new()
	shin.top_radius = 0.034
	shin.bottom_radius = 0.032
	shin.height = 0.2
	shin.radial_segments = 7
	shin.rings = 1
	tool.append_from(shin, 0, Transform3D(Basis.IDENTITY, Vector3(0.0, 0.14, 0.28)))
	_foot_mesh = tool.commit()
	return _foot_mesh


# His sounds, made here: a hum that rises as he makes ready, the stroke, and the pat of a bare foot.
static func _stream(named: StringName) -> AudioStreamWAV:
	if _streams.has(named):
		return _streams[named]
	var rate := 22050
	var samples := PackedFloat32Array()
	var chance := RandomNumberGenerator.new()
	chance.seed = 17
	match named:
		&"hum":
			samples.resize(rate)
			for k in rate:
				var t := float(k) / rate
				samples[k] = (sin(TAU * 196.0 * t) * 0.3 + sin(TAU * 294.0 * t) * 0.18 + sin(TAU * 589.0 * t) * 0.07) * (0.8 + 0.2 * sin(TAU * 7.0 * t))
		&"smite":
			samples.resize(int(rate * 0.7))
			var phase := 0.0
			var last := 0.0
			for k in samples.size():
				var t := float(k) / rate
				phase += TAU * (90.0 + 1100.0 * exp(-t * 9.0)) / rate
				last = lerpf(last, chance.randf_range(-1.0, 1.0), 0.35)
				samples[k] = (sin(phase) * 0.6 + last * 0.5 * exp(-t * 14.0)) * exp(-t * 5.0) * minf(t * 400.0, 1.0)
		_:
			samples.resize(int(rate * 0.08))
			var soft := 0.0
			for k in samples.size():
				var t := float(k) / samples.size()
				soft = lerpf(soft, chance.randf_range(-1.0, 1.0), 0.12)
				samples[k] = soft * 0.5 * (1.0 - t) * (1.0 - t)
	var data := PackedByteArray()
	data.resize(samples.size() * 2)
	for k in samples.size():
		data.encode_s16(k * 2, int(clampf(samples[k], -1.0, 1.0) * 32000.0))
	var made := AudioStreamWAV.new()
	made.format = AudioStreamWAV.FORMAT_16_BITS
	made.mix_rate = rate
	if named == &"hum":
		made.loop_mode = AudioStreamWAV.LOOP_FORWARD
		made.loop_end = samples.size()
	made.data = data
	_streams[named] = made
	return made
