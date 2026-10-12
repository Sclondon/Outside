class_name Khepri
extends CharacterBody3D
## Khepri and the sun: a big scarab of lapis and gold that rolls a ball of sun
## across the floor, as a dung beetle rolls its ball: backwards, head down, its
## hind legs on the ball. The ball is the thing (this node is the sun, and its
## foot is at the node); the beetle goes with it. The sun is a real light, so a
## dark room is lit as it comes.
##
## It moves like a wind-up toy on a floor of squares, and can be learned by
## watching. It rolls in a straight line at a slow steady pace (`pace`) from
## the middle of one square to the middle of the next (`step`, a metre), until
## something is in the way: a wall, a pillar, a pushed block, a shut door, a
## kerb higher than `kerb`, the edge of a drop, water, the boy. Then it turns a
## quarter turn to its `turns` side; if that way is shut too, to the other
## side; if both are, back the way it came (unless `turns_back` is off); and if
## it is shut in all round it waits, and tries again every second.
##
## The squares are its own: they are counted from where it was put, and lie as
## it was turned (it sets off along its own +Z). It never leaves them, so
## whoever makes a level can count squares; `square` is where it is, `path`
## every square it has come to. Nothing in it is left to chance.
##
## It goes while it is let go (`running`: set by whatever it is linked to, or
## from the start with `starts_itself`), and stops at the next square when it
## is not; stopped, the beetle climbs up onto the ball and looks about. He
## cannot pick the sun up or push it (he stops against it), but he can stand in
## its way, push blocks into its way, shut doors on it, and turn it by hand:
## the act button beside it turns it a quarter turn (it is in the group
## `workable`).
##
## Brought into the cradle of an `Akhet` it is let go: it rises between the two
## hills and stays there, the Akhet is on for good, and the beetle sits on a
## hill with its wings out.
##
## Being a light, it is in the group `sunlight`: a `SunDisc` it passes within
## `sun_reach` of is lit as if a beam were on it (unless something solid stands
## between), and scarab swarms keep off it as they do off fire
## (`Nearby.feared`). It burns nothing. Being heavy, it presses any pressure
## plate it is on. `reset()` puts it back where it started. `Khepri.new()` is a
## whole one.

## It has come to a square.
signal came_to(square: Vector2i)
## It has risen in an Akhet.
signal rose(akhet: Akhet)

enum Turns { RIGHT, LEFT }
enum State { REST, DOWN, ROLL, TURN, WAIT, RISE, DONE }
## What a thing of the beetle's model is, to the way it is moved.
enum Part { STILL, LEG, CASE, WING }

## How big across the sun is.
const SUN := 0.7
const R := SUN * 0.5
## The four ways it can go, as squares (x to its right, y ahead), in the order of a turn to the right.
const WAYS: Array[Vector2i] = [Vector2i(0, 1), Vector2i(1, 0), Vector2i(0, -1), Vector2i(-1, 0)]
## How long a quarter turn takes, and how long the beetle is getting down off the ball, seconds.
const TURN_TIME := 0.6
const GET_DOWN := 0.8
## How long it waits before it tries again, shut in.
const WAIT_TIME := 1.0
## How long the sun is rising in an Akhet.
const RISE_TIME := 2.6
## How far down its nose the beetle holds its head as it pushes (radians).
const NOSE_DOWN := 0.75
## The model the beetle and the ball are read from, and how long the beetle is in it, metres: `beetle_length` is
## made of that by making all of it bigger or smaller.
const MODEL := "res://models/khepri.glb"
const MODELLED := 0.45
## How far a foot swings fore and aft and how high it lifts, in lengths of the beetle.
const REACH := 0.11
const LIFT := 0.05

## Which side it turns to when its way is shut.
@export var turns := Turns.RIGHT
## How fast it rolls, metres a second.
@export var pace := 1.0
## How big a square is, metres.
@export var step := 1.0
## It goes from the start, without being let go by anything.
@export var starts_itself := false
## The highest kerb it will roll up or down, metres. Anything higher is a wall, or a drop.
@export var kerb := 0.25
## Shut in ahead and to both sides, it goes back the way it came. (Off: it waits.)
@export var turns_back := true
## How long the beetle is, metres.
@export var beetle_length := 0.45
## How far its light reaches, and how bright it is.
@export var light_reach := 7.0
@export var light_energy := 1.6
## How near a sun disc must be for the sun to light it, metres.
@export var sun_reach := 2.2
## Whether it makes a sound.
@export var voice := true

## Whether it is let go. It finishes the square it is on before it stops.
var running := false
## Which way it is going: its place in `WAYS`.
var heading := 0
## The square it is on (or last left), counted from where it was put.
var square := Vector2i.ZERO
## Every square it has come to since it was put back, in order.
var path: Array[Vector2i] = []
## What it is doing.
var state := State.REST

var _start: Transform3D
var _fore := Vector3.BACK
var _right := Vector3.LEFT
var _mine := Vector3.ZERO
var _homed := false
var _from := Vector3.ZERO
var _to := Vector3.ZERO
var _along := 0.0
var _back := false
var _timer := 0.0
var _by_hand := 0
var _akhet: Akhet
var _rise_from := Vector3.ZERO
var _rise := 0.0

var _ball: MeshInstance3D
var _halo: MeshInstance3D
var _lamp: OmniLight3D
var _beetle: Node3D
var _bones: Skeleton3D
var _body: MeshInstance3D
var _yaw := 0.0
var _mount := 1.0
var _stride := 0.0
var _clock := 0.0
var _open := 0.0
var _fly := 0.0
var _fly_from := Transform3D.IDENTITY
var _rumble: AudioStreamPlayer3D
var _chime: AudioStreamPlayer3D

static var _feeler: CylinderShape3D
static var _sun_shader: Shader
static var _halo_shader: Shader
static var _beetle_shader: Shader
static var _beetle_mesh: ArrayMesh
static var _sun_mesh: Mesh
static var _parts: Array[Dictionary] = []
static var _paints := PackedColorArray()
static var _lights := PackedVector3Array()
static var _rumble_stream: AudioStreamWAV
static var _chime_stream: AudioStreamWAV

const SUN_SHADER := """
shader_type spatial;
render_mode unshaded, fog_disabled, shadows_disabled;

uniform vec3 hot : source_color = vec3(1.0, 0.96, 0.66);
uniform vec3 warm : source_color = vec3(1.0, 0.78, 0.25);
uniform vec3 deep : source_color = vec3(0.98, 0.5, 0.1);

varying vec3 at;

void vertex() {
	at = VERTEX;
}

float cut(float value, float edge) {
	float pixel = max(fwidth(value), 0.0005);
	return smoothstep(edge - pixel, edge + pixel, value);
}

void fragment() {
	// Tongues of deeper gold that go round with it: so that it is seen to roll.
	vec3 n = normalize(at);
	float round_it = atan(n.z, n.x);
	float tongues = sin(round_it * 3.0 + n.y * 2.6 + sin(n.y * 5.0) * 0.8) * (1.0 - n.y * n.y * 0.7);
	vec3 colour = mix(warm, deep, cut(tongues, 0.45));
	colour = mix(colour, hot, cut(-tongues, 0.72));
	// Hot in the middle of what is seen of it, deeper round its edge.
	float facing = clamp(dot(normalize(NORMAL), normalize(VIEW)), 0.0, 1.0);
	colour = mix(colour, hot, cut(facing, 0.82) * 0.55);
	colour = mix(deep, colour, cut(facing, 0.3));
	ALBEDO = colour;
}
"""

const HALO_SHADER := """
shader_type spatial;
render_mode unshaded, blend_add, cull_front, depth_draw_never, fog_disabled, shadows_disabled;

uniform vec3 colour : source_color = vec3(1.0, 0.7, 0.26);
uniform float strength = 0.6;

void fragment() {
	// The far half of a ball round the sun, so that whatever is beside the sun is in front of its glow: brightest
	// against the sun's edge, and gone at its own, in two steps.
	float through = abs(dot(normalize(NORMAL), normalize(VIEW)));
	float soft = through * through;
	float ring = step(0.62, through) * 0.3 + step(0.4, through) * 0.12;
	ALBEDO = colour * (soft * 0.6 + ring) * strength;
}
"""

## The beetle is a Blender model (`models/khepri.glb`, built by
## `tools/build_khepri.py`, which keeps `tools/khepri.blend` to look at and
## change by hand): everything under `khepri` there, each thing named for what
## it is (`body`, `head`, `wing_case_left`, `wing_left`, `leg_fore_left` and so
## on) and hinged at its origin. Here they are made into one mesh on a
## skeleton of one bone to a thing, so the whole beetle is one draw, wings and
## all. Each point says which of the model's materials it had (in its second
## texture coordinate: the colours themselves are given to the shader as a
## list, `paints`, as any colour is, so that every renderer shows them as the
## model has them), how much it glints (the less rough the material, the more) and
## whether it is bright of itself and not lit (a material with emission: the
## wings, which so near the sun light would bleach).
const BEETLE_SHADER := """
shader_type spatial;
render_mode cull_disabled, shadows_disabled;

uniform float glow = 0.1;
uniform float gloss = 40.0;

// The colours of the model's materials: as seen (`paints`), and as light (`lights`: what a thing bright of itself
// gives out).
uniform vec3 paints[16] : source_color;
uniform vec3 lights[16];

varying vec3 tint;
varying float glint;
varying float own;

void vertex() {
	glint = UV.x;
	own = UV.y;
	int which = min(int(UV2.x + 0.5), 15);
	tint = mix(paints[which], lights[which], own);
}

void fragment() {
	ALBEDO = tint * (1.0 - own);
	EMISSION = tint * mix(glow, 1.0, own);
	ROUGHNESS = 1.0;
	SPECULAR = 0.0;
	// (wings, wing cases and legs are seen from both sides)
	if (dot(NORMAL, VIEW) < 0.0) {
		NORMAL = -NORMAL;
	}
}

float cut(float value, float edge) {
	float pixel = max(fwidth(value), 0.0005);
	return smoothstep(edge - pixel, edge + pixel, value);
}

void light() {
	float near = clamp(ATTENUATION, 0.0, 1.0);
	float amount = dot(NORMAL, LIGHT) * smoothstep(0.1, 0.5, near);
	float lit = cut(amount, 0.02);
	float strength = mix(near, 1.0, 0.5);
	DIFFUSE_LIGHT += lit * strength * LIGHT_COLOR / PI;
	float shine = cut(pow(max(dot(NORMAL, normalize(LIGHT + VIEW)), 0.0), gloss), 0.5);
	SPECULAR_LIGHT += shine * lit * min(glint, 0.6) * vec3(1.0, 0.92, 0.7) * strength * LIGHT_COLOR / PI;
}
"""


func _ready() -> void:
	add_to_group(&"interest")
	add_to_group(&"workable")
	add_to_group(&"sunlight")
	add_to_group(&"khepris")
	set_meta(&"surface", "metal")
	# The world's layer: he stops against it, a plate feels it, a beam of light is stopped by it. It runs into nothing itself.
	collision_layer = 1
	collision_mask = 0
	var round_it := SphereShape3D.new()
	round_it.radius = R
	var collider := CollisionShape3D.new()
	collider.shape = round_it
	collider.position.y = R
	add_child(collider)

	_read()
	_ball = MeshInstance3D.new()
	_ball.mesh = _sun_mesh
	_ball.material_override = _shaded(SUN_SHADER, 0)
	_ball.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_ball.position.y = R
	add_child(_ball)
	_halo = MeshInstance3D.new()
	var glow := SphereMesh.new()
	glow.radius = R * 1.9
	glow.height = SUN * 1.9
	glow.radial_segments = 32
	glow.rings = 16
	_halo.mesh = glow
	_halo.material_override = _shaded(HALO_SHADER, 1)
	_halo.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_halo.position.y = R
	add_child(_halo)
	_lamp = OmniLight3D.new()
	_lamp.light_color = Color(1.0, 0.84, 0.52)
	_lamp.light_energy = light_energy
	_lamp.omni_range = light_reach
	_lamp.omni_attenuation = 1.0
	# (a little over the ball, so that the floor under it is not a white spot)
	_lamp.position.y = SUN + 0.4
	add_child(_lamp)

	_beetle = Node3D.new()
	add_child(_beetle)
	# The beetle: the model's, a bone to each thing it is made of, each where the model has it.
	_bones = Skeleton3D.new()
	for part in _parts:
		var bone := _bones.add_bone(part.name)
		_bones.set_bone_rest(bone, Transform3D(part.rest, part.at))
	_bones.reset_bone_poses()
	_bones.scale = Vector3.ONE * beetle_length / MODELLED
	_beetle.add_child(_bones)
	_body = MeshInstance3D.new()
	_body.mesh = _beetle_mesh
	_body.material_override = _shaded(BEETLE_SHADER, 2)
	(_body.material_override as ShaderMaterial).set_shader_parameter(&"paints", _paints)
	(_body.material_override as ShaderMaterial).set_shader_parameter(&"lights", _lights)
	_body.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	# (wide enough for its wings when they are out)
	_body.custom_aabb = AABB(Vector3(-1.7, -0.3, -1.0) * MODELLED, Vector3(3.4, 1.6, 2.7) * MODELLED)
	_bones.add_child(_body)
	_body.skeleton = _body.get_path_to(_bones)

	if voice:
		_rumble = AudioStreamPlayer3D.new()
		_rumble.stream = _rumbling()
		_rumble.unit_size = 3.0
		_rumble.max_distance = 30.0
		_rumble.volume_db = -60.0
		add_child(_rumble)
		_chime = AudioStreamPlayer3D.new()
		_chime.stream = _chiming()
		_chime.unit_size = 8.0
		_chime.max_distance = 60.0
		add_child(_chime)

	if _feeler == null:
		_feeler = CylinderShape3D.new()
		_feeler.radius = R - 0.02
		_feeler.height = 0.4
	set_notify_transform(true)
	_home_here()
	_pose(0.0)


## Let go, or held: what it is linked to says which. (`starts_itself` turns what it says round: it goes until it is told.)
func let_go(go := true) -> void:
	running = go


## Turned by hand, a quarter turn to its `turns` side: by him, with the act button. If it is rolling, it turns when
## it comes to the next square.
func work(_by: Node3D = null) -> void:
	if state == State.RISE or state == State.DONE:
		return
	_by_hand += 1


## Where his hand goes to turn it: the beetle.
func work_point() -> Vector3:
	return _beetle.global_position + Vector3.UP * 0.1


## Whether its light falls on a place: it is within `sun_reach` of the middle of the sun, and nothing solid stands
## between (`target`, and what is part of it, does not count). What a `SunDisc` asks of everything in `sunlight`.
func shines_on(point: Vector3, target: Node = null) -> bool:
	var from := global_position + Vector3.UP * R
	if from.distance_to(point) > sun_reach:
		return false
	var query := PhysicsRayQueryParameters3D.create(from, point, 1, [get_rid()])
	var hit := get_world_3d().direct_space_state.intersect_ray(query)
	if hit.is_empty():
		return true
	var found := hit["collider"] as Node
	return target != null and found != null and (found == target or target.is_ancestor_of(found))


## Whether it has risen in an Akhet.
func is_risen() -> bool:
	return state == State.DONE


## The Akhet it has been given to, if it has.
func akhet() -> Akhet:
	return _akhet


## Where the middle of a square is, over the ground (its height is that of where it started).
func place_of(of: Vector2i) -> Vector3:
	return _start.origin + (_right * of.x + _fore * of.y) * step


## The way a heading goes, over the ground.
func way(of := -1) -> Vector3:
	var squares := WAYS[posmod(heading if of < 0 else of, 4)]
	return _right * squares.x + _fore * squares.y


## Back where it was put, as it was when it was made. (And the Akhet it rose in is off again.)
func reset() -> void:
	var had := _akhet
	_akhet = null
	if had and is_instance_valid(had):
		had.reset()
	_move(_start.origin)
	global_basis = _start.basis
	heading = 0
	square = Vector2i.ZERO
	path.clear()
	state = State.REST
	running = starts_itself
	_back = false
	_by_hand = 0
	_timer = 0.0
	_rise = 0.0
	_yaw = atan2(_fore.x, _fore.z)
	_mount = 1.0
	_open = 0.0
	_fly = 0.0
	if _ball:
		_ball.basis = Basis.IDENTITY
		_lamp.light_energy = light_energy
		_lamp.omni_range = light_reach
		_pose(0.0)


# Where it stands now is where it starts from, and its squares lie as it is turned.
func _home_here() -> void:
	_start = global_transform
	_fore = Vector3(_start.basis.z.x, 0.0, _start.basis.z.z).normalized()
	if _fore.is_zero_approx():
		_fore = Vector3.BACK
	# (seen from above, a turn to the right is a turn clockwise)
	_right = _fore.rotated(Vector3.UP, -PI * 0.5)
	_homed = true
	reset()
	running = running or starts_itself


func _notification(what: int) -> void:
	# Moved or turned by something else (the level editor, whoever is setting a level out): it starts from there.
	if what == NOTIFICATION_TRANSFORM_CHANGED and _homed and is_inside_tree():
		if global_position.distance_squared_to(_mine) > 0.000001 or not global_basis.is_equal_approx(_start.basis):
			var was := running
			_home_here()
			running = was or starts_itself


func _move(to: Vector3) -> void:
	global_position = to
	_mine = global_position


func _physics_process(delta: float) -> void:
	var before := global_position
	match state:
		State.REST:
			if _by_hand != 0:
				_turn_by_hand()
			if running:
				state = State.DOWN
				_timer = GET_DOWN
		State.DOWN, State.TURN, State.WAIT:
			_timer -= delta
			if _timer <= 0.0:
				_choose()
		State.ROLL:
			_roll(delta)
		State.RISE:
			_rise = minf(_rise + delta / RISE_TIME, 1.0)
			var eased := _rise * _rise * (3.0 - 2.0 * _rise)
			_move(_rise_from.lerp(_akhet.risen(), eased))
			if _rise >= 1.0:
				state = State.DONE
				_akhet.set_on(true)
				rose.emit(_akhet)
		State.DONE:
			pass
	# It turns as far as it travels.
	var moved := global_position - before
	moved.y = 0.0
	var far := moved.length()
	if far > 0.00001:
		_ball.basis = (Basis(Vector3.UP.cross(moved / far).normalized(), far / R) * _ball.basis).orthonormalized()
	elif state == State.RISE or state == State.DONE:
		# (and in the Akhet it turns slowly where it hangs)
		_ball.basis = (Basis(Vector3.UP, delta * 0.5) * _ball.basis).orthonormalized()


func _turn_by_hand() -> void:
	heading = posmod(heading + _by_hand * _sense(), 4)
	_by_hand = 0


func _sense() -> int:
	return 1 if turns == Turns.RIGHT else -1


# At the middle of a square: what next.
func _choose() -> void:
	if _by_hand != 0:
		_turn_by_hand()
	for found: Node in get_tree().get_nodes_in_group(&"akhets"):
		var horizon := found as Akhet
		if horizon and horizon.takes(self):
			_give(horizon)
			return
	if not running:
		state = State.REST
		return
	var tries: Array[int] = [heading, heading + _sense(), heading - _sense()]
	if turns_back:
		tries.append(heading + 2)
	for to_way in tries:
		var to := _room(global_position, to_way)
		if to == Vector3.INF:
			continue
		if posmod(to_way, 4) != heading:
			# (it turns first, and looks again when it has)
			_timer = TURN_TIME * (2.0 if posmod(to_way - heading, 4) == 2 else 1.0)
			heading = posmod(to_way, 4)
			state = State.TURN
			return
		_from = global_position
		_to = to
		_along = 0.0
		_back = false
		state = State.ROLL
		return
	state = State.WAIT
	_timer = WAIT_TIME


func _roll(delta: float) -> void:
	# Something has come into its way since it set off (he has stepped in front of it, a block has been pushed in):
	# it goes back to the square it left, and thinks again there.
	var goal := _from if _back else _to
	if _shut(global_position, goal, maxf(_from.y, _to.y)):
		if not _shut(global_position, _to if _back else _from, maxf(_from.y, _to.y)):
			_back = not _back
		return
	_along = clampf(_along + (-1.0 if _back else 1.0) * pace * delta / step, 0.0, 1.0)
	var at := _from.lerp(_to, _along)
	at.y = lerpf(_from.y, _to.y, smoothstep(0.25, 0.75, _along))
	_move(at)
	if _along >= 1.0:
		_move(_to)
		square += WAYS[heading]
		if path.size() >= 4096:
			path.pop_front()
		path.append(square)
		came_to.emit(square)
		_choose()
	elif _along <= 0.0:
		_move(_from)
		_back = false
		_choose()


func _give(horizon: Akhet) -> void:
	_akhet = horizon
	horizon.receive(self)
	state = State.RISE
	_rise = 0.0
	_rise_from = global_position
	_fly = 0.0
	_fly_from = _beetle.global_transform
	if _chime:
		_chime.play()


# Whether it can go from `from` (the middle of a square, on the ground) to the next square that way: where it would
# come to there, or `Vector3.INF` if it cannot.
func _room(from: Vector3, to_way: int) -> Vector3:
	var along := way(posmod(to_way, 4))
	var across := Vector3(along.z, 0.0, -along.x)
	var to := from + along * step
	# The ground: there, all round the middle of there, and half way. No more than a kerb up or down.
	var ground := _ground(to, from.y)
	if is_nan(ground) or is_nan(_ground(from + along * step * 0.5, from.y)):
		return Vector3.INF
	for off: Vector3 in [along * 0.25, along * -0.25, across * 0.25, across * -0.25]:
		if is_nan(_ground(to + off, ground)):
			return Vector3.INF
	to.y = ground
	# Water.
	for pool: Node in get_tree().get_nodes_in_group(&"water"):
		if pool.has_method(&"depth_at") and float(pool.call(&"depth_at", to)) > 0.02:
			return Vector3.INF
	# He is standing on it.
	var boy := Nearby.player(get_tree())
	if boy:
		var over := boy.global_position - from
		if over.y > R and over.y < SUN + 0.5 and Vector2(over.x, over.z).length() < R + 0.2:
			return Vector3.INF
	# Anything solid.
	if _shut(from, to, maxf(from.y, ground)) or _shut(to, to, ground):
		return Vector3.INF
	return to


# How high the ground is at a place, if it is within a kerb of `near`; if not, NAN.
func _ground(at: Vector3, near: float) -> float:
	var query := PhysicsRayQueryParameters3D.create(Vector3(at.x, near + kerb + 0.05, at.z), Vector3(at.x, near - kerb - 0.05, at.z), 1, [get_rid()])
	var hit := get_world_3d().direct_space_state.intersect_ray(query)
	if hit.is_empty() or absf(float(hit["position"].y) - near) > kerb:
		return NAN
	return hit["position"].y


# Whether anything solid (the world, a block, him) is in its way between two places, higher than a kerb over a
# floor at `floor_y`.
func _shut(from: Vector3, to: Vector3, floor_y: float) -> bool:
	var space := get_world_3d().direct_space_state
	var query := PhysicsShapeQueryParameters3D.new()
	query.shape = _feeler
	query.collision_mask = 1 | 2
	query.exclude = [get_rid()]
	query.transform = Transform3D(Basis.IDENTITY, Vector3(from.x, floor_y + kerb + 0.02 + _feeler.height * 0.5, from.z))
	query.motion = Vector3(to.x - from.x, 0.0, to.z - from.z)
	if query.motion.is_zero_approx():
		return not space.intersect_shape(query, 1).is_empty()
	return space.cast_motion(query)[0] < 0.999


func _process(delta: float) -> void:
	_pose(delta)


# Where the beetle is and how it holds itself, and the light, and the sound.
func _pose(delta: float) -> void:
	if _beetle == null:
		return
	_clock += delta
	var long := beetle_length
	var middle := global_position + Vector3.UP * R
	# It goes round the ball to the side it pushes from.
	var ahead := way()
	var before := _yaw
	_yaw = rotate_toward(_yaw, atan2(ahead.x, ahead.z), delta * PI * 0.5 / TURN_TIME)
	var toward := Vector3(sin(_yaw), 0.0, cos(_yaw))
	# Up onto the ball when it is stopped, and down again to push.
	var was := _mount
	_mount = move_toward(_mount, 1.0 if state == State.REST else 0.0, delta / GET_DOWN)
	# Round the ball, from low behind it to the top of it; head down until it is nearly up.
	var low := Vector2(R - 0.02 + 0.5 * long * cos(NOSE_DOWN), 0.5 * long * sin(NOSE_DOWN) + 0.02 - R)
	var angle := lerp_angle(low.angle(), PI * 0.5, _mount)
	var levelling := PI * 0.5 - NOSE_DOWN
	var out_from := lerpf(low.length(), R - 0.03, smoothstep(low.angle(), levelling, angle))
	var nose := minf(NOSE_DOWN, PI * 0.5 - angle)
	var at := middle + (-toward * cos(angle) + Vector3.UP * sin(angle)) * out_from
	# (on top, it looks about)
	var looking := smoothstep(0.9, 1.0, _mount) * (sin(_clock * 0.9) * 0.8 + sin(_clock * 0.37) * 0.5)
	var facing := (-toward).rotated(Vector3.UP, looking)
	var pushing := _facing(facing, nose)
	var here := Transform3D(pushing, at)
	# Its legs go as it goes: over the ground, round the ball, up it.
	var gone := 0.0
	if state == State.ROLL:
		gone += pace * delta
	gone += absf(angle_difference(before, _yaw)) * out_from + absf(_mount - was) * 0.9
	if state == State.WAIT:
		gone += delta * 0.12

	if state == State.RISE or state == State.DONE:
		# Let go of: it flies up onto a hill of the Akhet, and sits there with its wings out.
		_fly = minf(_fly + delta / 1.5, 1.0) if _rise > 0.15 or state == State.DONE else 0.0
		_open = move_toward(_open, 1.0 if _fly > 0.0 else 0.0, delta * 2.5)
		var eased := _fly * _fly * (3.0 - 2.0 * _fly)
		var perch := Transform3D(_facing(-way(), 0.0), _akhet.perch())
		here = _fly_from.interpolate_with(perch, eased)
		here.origin.y += sin(eased * PI) * 0.45
		if _fly > 0.0 and _fly < 1.0:
			gone += delta * 0.8
	else:
		_open = move_toward(_open, 0.0, delta * 4.0)
	_beetle.global_transform = here
	_stride += gone / (long * 0.55)
	# (its wings beat a little while it flies, and breathe when it sits)
	var beat := sin(_clock * 22.0) * 0.35 if _fly > 0.0 and _fly < 1.0 else sin(_clock * 1.3) * 0.05
	for bone in _parts.size():
		var part := _parts[bone]
		var rest: Basis = part.rest
		var side: float = part.side
		match part.kind as int:
			Part.LEG:
				# A foot swings fore and aft and lifts as it comes forward: the leg is turned about its hip.
				var turn: float = (_stride + part.step) * TAU
				var swing := Basis(Vector3.UP, -side * sin(turn) * REACH * MODELLED / part.far)
				var lifted := Basis(part.lifts, maxf(cos(turn), 0.0) * LIFT * MODELLED / part.far)
				_bones.set_bone_pose_rotation(bone, (lifted * swing * rest).get_rotation_quaternion())
			Part.CASE:
				# Shut, a wing case lies as it was made; open, as the model has it turned.
				_bones.set_bone_pose_rotation(bone, Basis.IDENTITY.slerp(rest, _open).get_rotation_quaternion())
			Part.WING:
				# A wing opens from along its back to where the model has it, and is nothing at all until it does.
				var out := rest.get_euler()
				var held := Basis.from_euler(Vector3(out.x * _open, out.y + side * (1.0 - _open) * 1.35, out.z + side * beat))
				_bones.set_bone_pose_rotation(bone, held.get_rotation_quaternion())
				_bones.set_bone_pose_scale(bone, Vector3.ONE * (lerpf(0.3, 1.0, _open) if _open > 0.01 else 0.0))

	# Risen, it lights the whole room.
	var up := _rise if state == State.RISE else (1.0 if state == State.DONE else 0.0)
	_lamp.light_energy = light_energy * (1.0 + up * 0.6)
	_lamp.omni_range = light_reach * (1.0 + up * 0.8)
	_halo.scale = Vector3.ONE * (1.0 + up * 0.35 + sin(_clock * 2.1) * 0.03)
	if _rumble:
		var loud := -14.0 if state == State.ROLL else -60.0
		_rumble.volume_db = move_toward(_rumble.volume_db, loud, delta * 120.0)
		if _rumble.volume_db > -50.0 and not _rumble.playing:
			_rumble.play()
		elif _rumble.volume_db <= -59.0 and _rumble.playing:
			_rumble.stop()


# The beetle turned to face a way over the ground, its nose held down by so much.
func _facing(toward: Vector3, nose: float) -> Basis:
	var fore := (toward * cos(nose) + Vector3.DOWN * sin(nose)).normalized()
	var over := (toward * sin(nose) + Vector3.UP * cos(nose)).normalized()
	return Basis(over.cross(fore).normalized(), over, fore)


static func _shaded(code: String, which: int) -> ShaderMaterial:
	var shader: Shader = [_sun_shader, _halo_shader, _beetle_shader][which]
	if shader == null:
		shader = Shader.new()
		shader.code = code
		match which:
			0:
				_sun_shader = shader
			1:
				_halo_shader = shader
			_:
				_beetle_shader = shader
	var made := ShaderMaterial.new()
	made.shader = shader
	return made


# The model, read once: the sun's ball; and everything under `khepri` as one mesh, each thing on a bone of its
# own (`_parts` says which, in the order of the bones).
static func _read() -> void:
	if _beetle_mesh:
		return
	var model := (load(MODEL) as PackedScene).instantiate()
	var ball := model.find_child("sun", true, false) as MeshInstance3D
	_sun_mesh = ball.mesh if ball else SphereMesh.new()
	var tool := SurfaceTool.new()
	tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	var whole := model.find_child("khepri", true, false)
	if whole == null:
		push_error("Khepri's model has nothing in it called khepri")
	for found: Node in (whole.get_children() if whole else []):
		var shown := found as MeshInstance3D
		if shown == null or shown.mesh == null:
			continue
		# (a thing of the other side is the same mesh turned over: its turn is taken without that)
		var place := shown.transform
		var mirrored := place.basis.determinant() < 0.0
		var rest := (place.basis * Basis.from_scale(Vector3(-1.0, 1.0, 1.0)) if mirrored else place.basis).orthonormalized()
		var lie := place.basis.inverse().transposed()
		var named := String(shown.name)
		var bone := _parts.size()
		var foot := Vector3.ZERO
		for surface in shown.mesh.get_surface_count():
			var paint := shown.mesh.surface_get_material(surface) as BaseMaterial3D
			var colour := (paint.albedo_color if paint else Color.WHITE).srgb_to_linear()
			var which := _paints.find(paint.albedo_color if paint else Color.WHITE)
			if which < 0:
				which = _paints.size()
				_paints.append(paint.albedo_color if paint else Color.WHITE)
				_lights.append(Vector3(colour.r, colour.g, colour.b))
			tool.set_uv2(Vector2(which, 0.0))
			tool.set_uv(Vector2(1.0 - paint.roughness if paint else 0.0, 1.0 if paint and paint.emission_enabled else 0.0))
			tool.set_bones(PackedInt32Array([bone, 0, 0, 0]))
			tool.set_weights(PackedFloat32Array([1.0, 0.0, 0.0, 0.0]))
			var arrays := shown.mesh.surface_get_arrays(surface)
			var points: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
			var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
			var order: PackedInt32Array = arrays[Mesh.ARRAY_INDEX] if arrays[Mesh.ARRAY_INDEX] != null else PackedInt32Array()
			var count := order.size() if not order.is_empty() else points.size()
			for i in range(0, count - 2, 3):
				for corner: int in ([0, 2, 1] if mirrored else [0, 1, 2]):
					var k := order[i + corner] if not order.is_empty() else i + corner
					var point := place * points[k]
					if point.y - place.origin.y < foot.y:
						foot = point - place.origin
					tool.set_normal((lie * normals[k]).normalized())
					tool.add_vertex(point)
		var part := {"name": named, "at": place.origin, "rest": rest, "side": 1.0 if place.origin.x >= 0.0 else -1.0, "kind": Part.STILL}
		if named.begins_with("leg_"):
			# (its lowest point is its foot. The legs of one side step in turn, and each with its opposite of the next pair)
			var out := Vector3(foot.x, 0.0, foot.z)
			var pair := 1 if named.contains("mid") else 0
			part.kind = Part.LEG
			part.far = maxf(out.length(), 0.02)
			part.lifts = out.normalized().cross(Vector3.UP) if out.length() > 0.001 else Vector3.BACK * part.side
			part.step = 0.5 if (pair == 0) == (part.side > 0.0) else 0.0
		elif named.begins_with("wing_case"):
			part.kind = Part.CASE
		elif named.begins_with("wing"):
			part.kind = Part.WING
		_parts.append(part)
	model.free()
	if _paints.size() > 16:
		push_error("Khepri's beetle has more than sixteen colours: the rest are drawn as the sixteenth")
	_paints.resize(16)
	_lights.resize(16)
	tool.index()
	_beetle_mesh = tool.commit()


# The sound of it rolling: a low grinding, made here from noise.
static func _rumbling() -> AudioStreamWAV:
	if _rumble_stream:
		return _rumble_stream
	var rate := 11025
	var count := rate * 2
	var samples := PackedFloat32Array()
	samples.resize(count)
	var chance := RandomNumberGenerator.new()
	chance.seed = 11
	var low := 0.0
	for k in count:
		# (noise with the top taken off it, swelling twice a second as the ball comes round)
		low += (chance.randf_range(-1.0, 1.0) - low) * 0.06
		samples[k] = low * (0.7 + 0.3 * sin(TAU * 2.0 * k / rate)) * 2.2
	# (the end is brought round to meet the start)
	for k in 600:
		var blend := k / 600.0
		samples[count - 600 + k] = lerpf(samples[count - 600 + k], samples[k], blend)
	_rumble_stream = _wav(samples, rate, true)
	return _rumble_stream


# The sound of the sun rising: three notes that swell and die away.
static func _chiming() -> AudioStreamWAV:
	if _chime_stream:
		return _chime_stream
	var rate := 22050
	var count := rate * 3
	var samples := PackedFloat32Array()
	samples.resize(count)
	for k in count:
		var time := float(k) / rate
		var swell := smoothstep(0.0, 1.6, time) * (1.0 - smoothstep(2.0, 3.0, time))
		var sound := 0.0
		for note: Array in [[220.0, 0.0], [330.0, 0.5], [440.0, 1.0], [660.0, 1.5]]:
			sound += sin(TAU * float(note[0]) * time) * smoothstep(float(note[1]), float(note[1]) + 0.4, time)
		samples[k] = sound * swell * 0.16
	_chime_stream = _wav(samples, rate, false)
	return _chime_stream


static func _wav(samples: PackedFloat32Array, rate: int, loops: bool) -> AudioStreamWAV:
	var data := PackedByteArray()
	data.resize(samples.size() * 2)
	for k in samples.size():
		data.encode_s16(k * 2, int(clampf(samples[k], -1.0, 1.0) * 32000.0))
	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = rate
	if loops:
		stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
		stream.loop_end = samples.size()
	stream.data = data
	return stream
