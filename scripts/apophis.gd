class_name Apophis
extends CharacterBody3D
## Apophis (Apep), the great serpent who lies in wait each night for the sun's
## boat. Here he is the chase: a very big snake that lies coiled, or down a
## hole, until he is let out, and then comes after the boy and does not give up.
##
## - HE IS ONE BODY. This node is his head, and what the world stops. Behind it
##   is kept the path the head has taken, and the body is laid along that path:
##   every part of him passes where the head passed, round the same corners and
##   over the same kerbs, with a side-to-side wave laid over it that stands
##   still on the ground as he slides through it. What he looks like is a
##   model (models/apophis.glb): his head, and one length of his body, which
##   is laid end to end into one tube and bent along `POINTS` places on that
##   path by its shader. Nothing is built each frame but those places. At rest the path is a coil, so he leaves it as a
##   snake does, sliding out along himself.
## - THE CHASE. His speed is between the boy's walk and his run, a little more
##   on the straight and less in a turn, so a clean run keeps ahead of him and
##   a stumble does not. He steers straight for the boy while he can see him.
##   When he cannot, he follows the trail the boy left (a place every half
##   metre), which is always a way through. He goes over anything up to
##   `step_over` high at once (he rears over it), swims, and goes through a
##   crawl. Under a high ledge he rears against it and sways under the boy for
##   `ledge_wait` seconds, then goes round if there is a way up to one side,
##   and otherwise goes slowly up the face.
## - THE STRIKE. Only his head catches. Within `strike_distance` he stops,
##   rears back with his mouth open for `strike_warning` seconds, and throws
##   his head at where the boy is; `caught` is emitted only if it finds him. A
##   step to one side in that moment and he misses. His body pushes the boy
##   aside but does not hurt him.
## - LIGHT. He will not bring his head nearer a `Fire` or a flare than
##   `light_reach` (for a torch; more for a brazier): with the boy inside it he
##   rears and circles at its edge, and strikes when the light goes out or the
##   boy leaves it. A beam of sunlight (`SunBeam`) is a wall to him, and he
##   recoils if it falls on his head. `fears_light` off, he fears neither.
## - WHAT STOPS HIM. `loose` set false sends him home, to coil up or go down
##   his hole again. A door shut in front of his head stops him: he batters at
##   it and waits. A pit, water and a ledge only slow him.
##
## `Apophis.new()` is a whole one. He finds the boy himself if `target` is not set.

signal caught
## He is back where he rests, after being out.
signal went_home

enum Rest { COILED, HOLE }
enum State { DORMANT, WAKING, HUNT, HELD, LEDGE, CLIMB, STRIKE, BATTER, HOMING, SETTLING }

## How many places along him the body is bent through.
const POINTS := 80
## How far the head goes between one remembered place on its path and the next.
const STEP := 0.15
## The ball his head is to the world.
const RADIUS := 0.24
## How long the side-to-side wave is, and how far it is from a beam of sunlight that he stops.
const WAVE := 3.4
## What he looks like: his head, one length of his body, and a knife (made by tools/build_apophis.py; tools/apophis.blend is the same to open and change).
const MODEL := preload("res://models/apophis.glb")
const BEAM_REACH := 0.95

const BODY_SHADER := """
shader_type spatial;
render_mode cull_back;

const int POINTS = 80;
uniform vec3 spine[POINTS];
uniform vec3 lift[POINTS];
void vertex() {
	// The mesh is a straight tube: x and y are across him, UV2.x is how far along. It is bent here.
	float at = clamp(UV2.x, 0.0, 1.0) * float(POINTS - 1);
	int i = int(min(floor(at), float(POINTS - 2)));
	float f = at - float(i);
	vec3 p0 = spine[max(i - 1, 0)];
	vec3 p1 = spine[i];
	vec3 p2 = spine[i + 1];
	vec3 p3 = spine[min(i + 2, POINTS - 1)];
	vec3 a = 2.0 * p0 - 5.0 * p1 + 4.0 * p2 - p3;
	vec3 b = -p0 + 3.0 * p1 - 3.0 * p2 + p3;
	vec3 centre = 0.5 * (2.0 * p1 + (p2 - p0) * f + a * f * f + b * f * f * f);
	vec3 going = 0.5 * ((p2 - p0) + 2.0 * a * f + 3.0 * b * f * f);
	vec3 along = length(going) > 0.0001 ? normalize(going) : vec3(0.0, 0.0, 1.0);
	vec3 up = normalize(mix(lift[i], lift[i + 1], f));
	vec3 side = cross(up, along);
	side = length(side) > 0.01 ? normalize(side) : normalize(cross(vec3(0.3, 0.2, 0.9), along));
	up = cross(along, side);
	VERTEX = centre + side * VERTEX.x + up * VERTEX.y;
	NORMAL = normalize(side * NORMAL.x + up * NORMAL.y);
}

void fragment() {
	// (his colours are the model's materials, a face at a time)
	ALBEDO = COLOR.rgb;
	ROUGHNESS = 1.0;
	SPECULAR = 0.0;
}
"""

const HEAD_SHADER := """
shader_type spatial;
render_mode cull_disabled;

// How far his jaw is dropped (radians), how far his tongue is out (0..1), and where they hinge.
uniform float gape = 0.0;
uniform float tongue = 0.0;
uniform float flick = 0.0;
uniform vec2 hinge = vec2(0.0, 0.08);
uniform float root = 0.4;
uniform float roof = 0.0;
uniform float glow = 1.0;

void vertex() {
	// UV2.x says which part a point is of: 0 his skull, 1 his jaw, 2 his tongue. UV2.y, how far it goes with the jaw.
	vec3 p = VERTEX;
	if (UV2.x > 2.5) {
		// (a fang: it is drawn out of the roof of his mouth as his jaw drops)
		p.y = roof + (p.y - roof) * clamp(gape * 2.2, 0.1, 1.0);
	} else if (UV2.x > 0.5) {
		if (UV2.x > 1.5) {
			float out_by = p.z - root;
			p.z = root + out_by * tongue;
			p.y += sin(flick + out_by * 14.0) * 0.07 * out_by * tongue;
		}
		float turn = gape * UV2.y;
		float c = cos(turn);
		float s = sin(turn);
		vec2 from = vec2(p.y - hinge.x, p.z - hinge.y);
		p.y = hinge.x + from.x * c - from.y * s;
		p.z = hinge.y + from.x * s + from.y * c;
		NORMAL = vec3(NORMAL.x, NORMAL.y * c - NORMAL.z * s, NORMAL.y * s + NORMAL.z * c);
	}
	VERTEX = p;
}

void fragment() {
	// UV.x is how much a part shines by itself: his eyes.
	ALBEDO = COLOR.rgb * (1.0 - UV.x);
	EMISSION = COLOR.rgb * UV.x * (UV.x > 0.5 ? glow : 1.0);
	ROUGHNESS = 1.0;
	SPECULAR = 0.0;
}
"""

## Lit as the figures are (see `Toon`): two flat tones with a hard edge, and a rim of light.
const LIGHT := """
float cut(float value, float edge) {
	float pixel = max(fwidth(value), 0.0005);
	return smoothstep(edge - pixel, edge + pixel, value);
}

void light() {
	float reach = clamp(ATTENUATION, 0.0, 1.0);
	float facing = (dot(NORMAL, LIGHT) + 0.12) / 1.12;
	float amount = facing * smoothstep(0.15, 0.6, reach);
	float lit = cut(amount, 0.04);
	float strength = mix(reach, 1.0, 0.45);
	DIFFUSE_LIGHT += lit * strength * LIGHT_COLOR / PI;
	float graze = 1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0);
	SPECULAR_LIGHT += cut(graze, 0.8) * lit * 0.22 * ALBEDO * strength * LIGHT_COLOR / PI;
}
"""

## How long he is, metres (12 to 30), and how thick at the middle.
@export_range(12.0, 30.0) var length := 18.0
@export var thickness := 0.5
## His speed, m/s: between the boy's walk (1.6) and his run (4.4). He goes a
## little faster than this on the straight and a good deal slower in a turn.
@export var speed := 3.6
## How fast he can turn, radians a second.
@export var turn_rate := 2.4
## He wakes by himself when the boy comes this near where he rests (0: only when he is let out).
@export var alert_distance := 0.0
## Where he rests: coiled on the ground, or out of sight down a hole.
@export var rest := Rest.COILED
## Seconds between being let out and coming on.
@export var wake_time := 1.6
## Whether fire and sunlight hold him off, and how near a torch he will bring his head.
@export var fears_light := true
@export var light_reach := 2.5
## How near the boy his head must be to strike, how long he rears first, and
## how near the boy his head must pass to have him.
@export var strike_distance := 2.3
@export var strike_warning := 0.6
@export var catch_distance := 0.45
## The highest thing he goes over without stopping.
@export var step_over := 1.0
## How long he sways under a ledge before he goes round or up, how fast he
## goes up the face of one, and the highest he will go up.
@export var ledge_wait := 3.0
@export var climb_speed := 0.6
@export var climb_limit := 8.0
## How far his body swings from side to side as he goes.
@export var wave := 0.22
## How many knives are stuck in him: the tomb paintings show him cut and speared.
@export_range(0, 6) var knives := 3
## Whether he hisses.
@export var voice := true

## Who he is after. Left unset, he finds the boy himself.
var target: Player:
	set(value):
		if target and target.respawned.is_connected(reset):
			target.respawned.disconnect(reset)
		target = value
		# (he is put back when the boy starts again)
		if target and not target.respawned.is_connected(reset):
			target.respawned.connect(reset)
## Whether he is out. While it is true he hunts; set false, he goes home.
var loose := false:
	set(value):
		if loose and not value:
			_roused = false
			if state != State.DORMANT and state != State.SETTLING:
				_turn_home()
		loose = value
## What he is doing.
var state := State.DORMANT
## Whether he is out and after the boy (what the boy's own wariness looks at).
var chasing := false
## Where his head is drawn, the way it looks, and how far along his strike he is (0..1, 1 when not striking).
var head_at := Vector3.ZERO
var head_way := Vector3.BACK
## The middle of his body at each of `POINTS` places from head to tail, and how thick he is there.
var spine := PackedVector3Array()
var girth := PackedFloat32Array()

var _home := Transform3D.IDENTITY
var _placing := false
var _roused := false
var _grace := 0.0
var _time := 0.0
var _clock := 0.0
var _yaw := 0.0
var _prev := Vector3.ZERO
var _travel := 0.0
var _homing := false
# The path his head has taken, newest first: where, which way is up off the
# surface there, the height of the ground (or -INF where there is none), and
# how much room there is to swing.
var _path_at := PackedVector3Array()
var _path_up := PackedVector3Array()
var _path_floor := PackedFloat32Array()
var _path_room := PackedFloat32Array()
var _up_now := Vector3.UP
var _floor_now := 0.0
var _room_now := 1.0
var _lift := PackedVector3Array()
# The boy's trail, oldest first, and which place on it he is making for; and his own, to go home by.
var _crumbs := PackedVector3Array()
var _crumb := 0
var _own := PackedVector3Array()
var _look_rest := 0.0
var _sees_him := false
var _distrust := 0.0
var _round: Array[Vector3] = []
var _tried_round := 0.0
var _detour := Vector3.ZERO
var _detour_time := 0.0
var _flip := 1.0
var _stuck_at := Vector3.ZERO
var _stuck_time := 0.0
var _stuck := 0
var _probe_rest := 0.0
var _swimming := false
# Light: whether the boy is in it, whether it is holding him now, which way he circles.
var _boy_lit := false
var _held := false
var _circle := 1.0
var _circle_time := 0.0
var _recoil := Vector3.ZERO
var _recoil_time := 0.0
# The ledge and the climb.
var _into := Vector3.FORWARD
var _top := 0.0
var _quick := false
var _over := 0.0
var _base := 0.0
# The strike.
var _aim := Vector3.ZERO
var _strike_from := Vector3.ZERO
var _lunge := Vector3.ZERO
var _tip := Vector3.ZERO
var _has_him := false
var _strike_rest := 0.0
var _door: Node3D
var _batter := 0.0
# A line his head is drawn along without regard to anything: out of his hole, down it, into his coil.
var _rail := PackedVector3Array()
var _rail_speed := 2.0
# How he holds himself: how high his head is reared, how far it sways, how wide his jaw is.
var _rear := 0.0
var _rear_to := 0.0
var _headroom := 3.0
var _gape := 0.0
var _gape_to := 0.0
var _tongue := 0.0
var _head_long := 1.0
var _body: MeshInstance3D
var _skull: MeshInstance3D
var _blades: MultiMeshInstance3D
var _pit: MeshInstance3D
var _body_material: ShaderMaterial
var _head_material: ShaderMaterial
var _hiss: AudioStreamPlayer3D
var _scrape: AudioStreamPlayer3D
var _knock: AudioStreamPlayer3D
var _loud := 0.0
var _spit := 0.0
var _own_rid: Array[RID] = []
var _body_shader: Shader
var _head_shader: Shader
var _hiss_stream: AudioStreamWAV
var _scrape_stream: AudioStreamWAV
var _knock_stream: AudioStreamWAV


func _ready() -> void:
	# The boy passes through his head; the world, blocks and doors stop it.
	collision_layer = 4
	collision_mask = 1
	floor_snap_length = 0.3
	floor_max_angle = deg_to_rad(50.0)
	var ball := SphereShape3D.new()
	ball.radius = RADIUS
	var collider := CollisionShape3D.new()
	collider.shape = ball
	collider.position.y = RADIUS
	add_child(collider)
	_own_rid = [get_rid()]
	length = clampf(length, 6.0, 40.0)
	spine.resize(POINTS)
	_lift.resize(POINTS)
	girth.resize(POINTS)
	for i in POINTS:
		girth[i] = girth_at(i / float(POINTS - 1))
	_build()
	_come_to_rest()
	set_notify_transform(true)
	reset()


## How thick he is (half of it) at `along`, 0 at his head and 1 at the tip of his tail.
func girth_at(along: float) -> float:
	var neck := lerpf(0.78, 1.0, smoothstep(0.0, 0.1, along))
	var tail := pow(1.0 - smoothstep(0.5, 1.0, along), 0.8)
	return thickness * 0.5 * neck * lerpf(0.06, 1.0, tail)


## One as the level editor describes him (`LevelLayout.FIELDS`, "person:apophis").
static func from_item(item: Dictionary) -> Apophis:
	var made := Apophis.new()
	made.length = item.get("length", 18.0)
	made.speed = item.get("speed", 3.6)
	made.alert_distance = item.get("alert", 0.0)
	made.rest = int(item.get("rest", 0)) as Rest
	made.fears_light = item.get("light", true)
	return made


## Lets him out, as setting `loose` does.
func wake() -> void:
	loose = true


func is_awake() -> bool:
	return state != State.DORMANT


## Back where he rests, at once, and dormant. (He comes out again if he is still let out.)
func reset() -> void:
	_placing = true
	global_transform = _home
	_placing = false
	velocity = Vector3.ZERO
	_set_state(State.DORMANT)
	chasing = false
	remove_from_group(&"pursuers")
	_roused = false
	_grace = 1.5
	_homing = false
	_rear = 0.0
	_rear_to = 0.0
	_gape = 0.0
	_lunge = Vector3.ZERO
	_crumbs.clear()
	_own.clear()
	_round.clear()
	_rail.clear()
	_lay_rest(-_home.basis.get_euler().y)
	_prev = _path_at[0]
	_draw(0.0)


func _notification(what: int) -> void:
	# (moved by the level editor while he rests: that is where he rests now)
	if what == NOTIFICATION_TRANSFORM_CHANGED and not _placing and state == State.DORMANT and is_inside_tree() and _body:
		_come_to_rest()
		_lay_rest(-_home.basis.get_euler().y)
		_draw(0.0)


# Where he is put is where he rests: on the ground under it, if there is ground near under it.
func _come_to_rest() -> void:
	_home = global_transform
	var ground := _ray(_home.origin + Vector3.UP * 0.6, _home.origin + Vector3.DOWN * 2.0)
	if not ground.is_empty():
		_home.origin.y = (ground["position"] as Vector3).y
	if _pit:
		_pit.global_position = _home.origin + Vector3.UP * 0.03


func _set_state(to: State) -> void:
	state = to
	_time = 0.0


func _him() -> Player:
	if target == null and is_inside_tree():
		target = Nearby.player(get_tree())
	return target if is_instance_valid(target) else null


func _forward() -> Vector3:
	return Vector3(sin(_yaw), 0.0, cos(_yaw))


func _ray(from: Vector3, to: Vector3) -> Dictionary:
	var query := PhysicsRayQueryParameters3D.create(from, to, 1)
	query.exclude = _own_rid
	return get_world_3d().direct_space_state.intersect_ray(query)


# --- What he does ---

func _physics_process(delta: float) -> void:
	_time += delta
	_clock += delta
	_strike_rest -= delta
	_tried_round -= delta
	var boy := _him()
	var before := global_position
	_up_now = Vector3.UP
	_floor_now = global_position.y
	_held = false
	match state:
		State.DORMANT:
			_rest(delta, boy)
		State.WAKING:
			_waking(delta, boy)
		State.HUNT, State.HELD:
			_hunt(delta, boy)
		State.HOMING:
			_go_home(delta, boy)
		State.LEDGE:
			_ledge(delta, boy)
		State.CLIMB:
			_climb(delta)
		State.STRIKE:
			_strike(delta, boy)
		State.BATTER:
			_batter_door(delta, boy)
		State.SETTLING:
			if _along_rail(delta):
				_lay_rest(_settled_turn)
				_set_state(State.DORMANT)
				_rear = 0.0
				_gape = 0.0
				_draw(0.0)
				chasing = false
				remove_from_group(&"pursuers")
				_grace = 1.0
				_placing = true
				global_transform = _home
				_placing = false
				went_home.emit()
	if state == State.DORMANT:
		if rest == Rest.COILED:
			_push_aside(boy)
		return
	# How high he can rear here.
	_roof_rest -= delta
	if _roof_rest <= 0.0:
		_roof_rest = 0.25
		var roof := _ray(global_position + Vector3.UP * 0.3, global_position + Vector3.UP * 3.2)
		_headroom = 3.0 if roof.is_empty() else maxf((roof["position"] as Vector3).y - global_position.y - 0.8, 0.0)
	_travel += before.distance_to(global_position)
	if boy and not boy.is_limp and (_crumbs.is_empty() or _crumbs[_crumbs.size() - 1].distance_to(boy.global_position) > 0.6):
		_crumbs.append(boy.global_position)
		if _crumbs.size() > 400:
			_crumbs = _crumbs.slice(100)
			_crumb = maxi(_crumb - 100, 0)
	_remember(before)
	_push_aside(boy)
	# Fallen out of the world: he is back where he rests, and comes again.
	if global_position.y < _home.origin.y - 60.0:
		var was := loose
		reset()
		loose = was


var _settled_turn := 0.0
var _roof_rest := 0.0
var _found_ground := false


func _rest(delta: float, boy: Player) -> void:
	if not _found_ground:
		# (the ground may not have been there to find when he was made)
		_found_ground = true
		var was := _home.origin
		_come_to_rest()
		if not was.is_equal_approx(_home.origin):
			_lay_rest(-_home.basis.get_euler().y)
			_draw(0.0)
	_grace -= delta
	if _grace > 0.0 or boy == null or boy.is_limp:
		return
	if alert_distance > 0.0 and not _roused and boy.global_position.distance_to(_home.origin) < alert_distance:
		_roused = true
	if not (loose or _roused):
		return
	_set_state(State.WAKING)
	chasing = true
	add_to_group(&"pursuers")
	_homing = false
	_crumbs.clear()
	_crumb = 0
	_own.clear()
	_own.append(_home.origin)
	_distrust = 0.0
	_stuck = 0
	_stuck_time = 0.0
	_strike_rest = 0.6
	_placing = true
	global_position = _path_at[0]
	_placing = false
	_prev = global_position
	var to := boy.global_position - global_position
	if rest == Rest.HOLE:
		_rail = PackedVector3Array([_home.origin + Vector3.UP * 0.05])
		_rail_speed = 3.0
		_yaw = atan2(to.x, to.z)
	else:
		var lies := _path_at[0] - _path_at[2]
		_yaw = atan2(lies.x, lies.z)
	_spit = 1.0


func _waking(delta: float, boy: Player) -> void:
	velocity = Vector3.ZERO
	_rear_to = 1.1
	_gape_to = 0.7
	if rest == Rest.HOLE and not _rail.is_empty():
		_rear_to = 0.0
		_up_now = Vector3(sin(_yaw), 0.0, cos(_yaw)) * -1.0
		_floor_now = -INF
		_room_now = 0.0
		if _along_rail(delta):
			_time = 0.0
		return
	if boy:
		_face(boy.global_position, delta * 0.6)
	if _time >= wake_time:
		_set_state(State.HUNT)
		_stuck_at = global_position


func _hunt(delta: float, boy: Player) -> void:
	if not (loose or _roused):
		_turn_home()
		return
	if boy == null or boy.is_limp:
		# He has him, or there is no one: he stands over the place.
		_rear_to = 0.7
		_gape_to = 0.2
		_stand(delta)
		return
	_see_light(boy)
	var here := global_position
	var to := boy.global_position - here
	var away := Vector2(to.x, to.z).length()
	# Where he is making for: the boy, if he can see him; or the furthest place on the boy's trail that he can.
	_look_rest -= delta
	_distrust -= delta
	if _look_rest <= 0.0:
		_look_rest = 0.15
		_sees_him = _distrust <= 0.0 and _sees(here, boy.global_position, 0.9)
		if _sees_him:
			_crumb = maxi(_crumbs.size() - 1, 0)
		elif _distrust <= 0.0:
			var last := _crumbs.size() - 1
			var stride := maxi((last - _crumb) / 8, 1)
			var i := last
			while i > _crumb:
				if _sees(here, _crumbs[i], 0.3):
					_crumb = i
					break
				i -= stride
	var goal := boy.global_position
	if not _round.is_empty():
		goal = _round[0]
		if Vector2(goal.x - here.x, goal.z - here.z).length() < 0.8:
			_round.remove_at(0)
	elif not _sees_him and not _crumbs.is_empty():
		while _crumb < _crumbs.size() - 1 and Vector2(_crumbs[_crumb].x - here.x, _crumbs[_crumb].z - here.z).length() < 0.7 and absf(_crumbs[_crumb].y - here.y) < 1.2:
			_crumb += 1
		if _crumb < _crumbs.size() - 1 or _crumbs[_crumb].distance_to(boy.global_position) > 1.0:
			goal = _crumbs[_crumb]
	# The strike.
	if _sees_him and _round.is_empty() and not _boy_lit and _strike_rest <= 0.0 and away < strike_distance and absf(to.y) < 1.3 and _recoil_time <= 0.0 \
			and (is_on_floor() or _swimming) and (away < 0.9 or _forward().dot(Vector3(to.x, 0.0, to.z).normalized()) > 0.55):
		_set_state(State.STRIKE)
		_has_him = false
		_spit = 1.0
		return
	# How he carries himself: head up off the ground, jaw wider the nearer he is.
	_rear_to = lerpf(0.5, 0.25, clampf((away - 4.0) / 6.0, 0.0, 1.0))
	_gape_to = lerpf(0.62, 0.08, clampf((away - 4.0) / 6.0, 0.0, 1.0))
	_go(delta, goal, 1.0, boy)
	if state == State.HUNT or state == State.HELD:
		state = State.HELD if _held else State.HUNT
		if _held:
			_rear_to = 1.0
			_gape_to = 0.55 + 0.25 * sin(_clock * 2.3)
			_face_head(boy.global_position)


func _go_home(delta: float, boy: Player) -> void:
	if loose or _roused:
		_homing = false
		_set_state(State.HUNT)
		return
	_rear_to = 0.08
	_gape_to = 0.0
	_boy_lit = false
	var here := global_position
	var home := _home.origin
	var away := Vector2(home.x - here.x, home.z - here.z).length()
	var outer := _coil_radius() if rest == Rest.COILED else 0.0
	if away < outer + 1.0 and absf(home.y - here.y) < 1.5:
		_settle()
		return
	# Back the way he came, a place at a time, or straight there once he can see it.
	var goal := home
	_look_rest -= delta
	if _look_rest <= 0.0:
		_look_rest = 0.3
		_sees_him = _sees(here, home, 0.3)
	if not _sees_him:
		while _own.size() > 1 and Vector2(_own[_own.size() - 1].x - here.x, _own[_own.size() - 1].z - here.z).length() < 0.9 and absf(_own[_own.size() - 1].y - here.y) < 1.2:
			_own.remove_at(_own.size() - 1)
		goal = _own[_own.size() - 1]
	_see_light(null)
	_go(delta, goal, 0.8, boy)


func _turn_home() -> void:
	_homing = true
	_round.clear()
	_lunge = Vector3.ZERO
	_look_rest = 0.0
	_stuck = 0
	_stuck_time = 0.0
	_stuck_at = global_position
	if state == State.WAKING:
		_rail.clear()
	if state != State.CLIMB:
		_set_state(State.HOMING)


# At his resting place: he winds himself into his coil, or goes down his hole.
func _settle() -> void:
	_set_state(State.SETTLING)
	velocity = Vector3.ZERO
	var home := _home.origin
	_rail.clear()
	if rest == Rest.HOLE:
		_rail.append(home + Vector3.UP * 0.05)
		_rail.append(home + Vector3.DOWN * (length + 1.5))
		_settled_turn = 0.0
	else:
		# The coil is turned so that its outer end is where a line from his head touches it.
		var here := global_position
		var from := atan2(here.z - home.z, here.x - home.x)
		var outer := _coil_radius()
		var away := Vector2(here.x - home.x, here.z - home.z).length()
		var touch := from - (acos(clampf(outer / maxf(away, 0.01), 0.0, 1.0)))
		var plain := _coil(0.0)
		var end := plain[plain.size() - 1] - home
		_settled_turn = touch - atan2(end.z, end.x)
		var coil := _coil(_settled_turn)
		for i in range(coil.size() - 1, -1, -1):
			_rail.append(coil[i])
	_rail_speed = speed * 0.7


func _along_rail(delta: float) -> bool:
	var left := _rail_speed * delta
	_placing = true
	while left > 0.0 and not _rail.is_empty():
		var to := _rail[0] - global_position
		if state == State.SETTLING:
			if rest == Rest.HOLE and _rail.size() == 1:
				_up_now = _forward() * -1.0
				_floor_now = -INF
				_room_now = 0.0
			else:
				_floor_now = _home.origin.y
				_room_now = 0.0
				if Vector2(to.x, to.z).length() > 0.01:
					_yaw = atan2(to.x, to.z)
		if to.length() <= left:
			left -= to.length()
			global_position = _rail[0]
			_rail.remove_at(0)
		else:
			global_position += to.normalized() * left
			left = 0.0
	_placing = false
	_rear_to = 0.0
	_gape_to = 0.0
	return _rail.is_empty()


# Stands where he is (falling, if there is nothing under him).
func _stand(delta: float) -> void:
	velocity.x = 0.0
	velocity.z = 0.0
	if _swimming or is_on_floor():
		velocity.y = 0.0
	else:
		velocity.y -= 24.0 * delta
	move_and_slide()


# Turns his body towards a place.
func _face(at: Vector3, by: float) -> void:
	var to := at - global_position
	if Vector2(to.x, to.z).length() > 0.05:
		_yaw = rotate_toward(_yaw, atan2(to.x, to.z), by * turn_rate)


var _gaze := Vector3.INF


# Turns only his head towards a place (while it is reared).
func _face_head(at: Vector3) -> void:
	_gaze = at


# Whether there is a clear line from where his head is to a place: low along
# the ground, or failing that at the height he can rear over things.
func _sees(here: Vector3, at: Vector3, high: float) -> bool:
	if _ray(here + Vector3.UP * 0.3, at + Vector3.UP * high).is_empty():
		return true
	if not _ray(here + Vector3.UP * 0.3, here + Vector3.UP * (step_over + 0.2)).is_empty():
		return false
	return _ray(here + Vector3.UP * (step_over + 0.15), at + Vector3.UP * maxf(high, step_over + 0.15)).is_empty()


# Goes towards a place: turns, goes forward, and deals with what is in the way.
func _go(delta: float, goal: Vector3, pace: float, boy: Player) -> void:
	var here := global_position
	var to := goal - here
	var flat := Vector3(to.x, 0.0, to.z)
	var wish := flat.normalized() if flat.length() > 0.05 else _forward()
	_swimming = _depth(here) > 0.25
	if _recoil_time > 0.0:
		# Sunlight on his head: he throws himself back from it.
		_recoil_time -= delta
		velocity = Vector3(_recoil.x * 4.5, velocity.y - 24.0 * delta if not is_on_floor() else 0.0, _recoil.z * 4.5)
		_rear_to = 0.9
		_gape_to = 1.0
		_held = true
		move_and_slide()
		return
	wish = _shy(wish, here, boy)
	_detour_time -= delta
	if _detour_time > 0.0 and not _held:
		wish = (wish * 0.45 + _detour).normalized()
	var want := atan2(wish.x, wish.z)
	var off := absf(angle_difference(_yaw, want))
	# A little faster on the straight, slower in a turn; and right up to a place he pivots, so as not to go round and round it.
	var near := flat.length() < 1.2 and off > 0.8
	_yaw = rotate_toward(_yaw, want, turn_rate * (1.0 + (off if near else minf(off, 0.6))) * delta)
	var forward := _forward()
	var factor := lerpf(1.12, 0.6, clampf(off / 0.9, 0.0, 1.0))
	if near:
		factor = 0.25
	if _held and _boy_lit:
		factor *= 0.4
	if _swimming:
		factor *= 0.85
	var grounded := is_on_floor() or _swimming
	if grounded and not _held:
		var hit := KinematicCollision3D.new()
		if test_move(global_transform, forward * 0.3, hit) and hit.get_normal().y < 0.6:
			if _obstacle(forward, wish, hit, goal):
				return
	var going := _held_back(forward * speed * pace * factor, here)
	velocity.x = going.x
	velocity.z = going.z
	if _swimming:
		# He floats, his head just under the surface.
		velocity.y = clampf((_depth(here) - 0.3) * 4.0, -2.0, 2.5)
	elif not is_on_floor():
		velocity.y -= 24.0 * delta
	else:
		velocity.y = 0.0
	move_and_slide()
	if is_on_floor() and _own.size() < 400 and _own[_own.size() - 1].distance_to(global_position) > 1.0 and not _homing:
		_own.append(global_position)
	# Getting nowhere: first the other way round and by the trail; then up, whatever it is.
	_stuck_time += delta
	if _stuck_time >= 1.0:
		if _stuck_at.distance_to(global_position) < 0.35 and not _held and flat.length() > 0.9:
			_stuck += 1
			_flip = -_flip
			_detour_time = 0.0
			_distrust = 5.0
			_look_rest = 0.0
			_round.clear()
			if _stuck >= 3:
				var top := _top_ahead(wish, climb_limit)
				if top != INF and top > global_position.y + 0.1:
					_stuck = 0
					_begin_climb(wish, top, false)
		else:
			_stuck = 0
		_stuck_time = 0.0
		_stuck_at = global_position


# Something is in his way. Says whether he has stopped going for now (to go up it, to wait under it, to batter at it).
func _obstacle(forward: Vector3, wish: Vector3, hit: KinematicCollision3D, goal: Vector3) -> bool:
	var feet := global_position
	var into := -Vector3(hit.get_normal().x, 0.0, hit.get_normal().z)
	into = into.normalized() if into.length() > 0.2 else forward
	# Low enough to go over: he rears over it.
	var top := _top_ahead(into, step_over + 0.05)
	if top != INF:
		if top - feet.y > 0.04:
			_begin_climb(into, top, true)
			return true
		return false
	# What he is after is up on it: he waits under it, then finds a way.
	_probe_rest -= 1.0
	if goal.y > feet.y + 0.8 and Vector2(goal.x - feet.x, goal.z - feet.z).length() < 6.0 and _probe_rest <= 0.0:
		_probe_rest = 12.0
		top = _top_ahead(into, climb_limit)
		if top != INF and top <= goal.y + 1.2:
			_into = into
			_top = top
			if _homing or ledge_wait <= 0.0:
				_begin_climb(into, top, false)
			else:
				_set_state(State.LEDGE)
			return true
	# A door: he batters at it.
	var what := hit.get_collider() as Node3D
	if what is TombParts.Door and wish.dot(into) > 0.5:
		_door = what
		_into = into
		_batter = 0.8
		_set_state(State.BATTER)
		return true
	# Anything else: round it, to one side, and keep to that side for a moment.
	if _detour_time <= 0.0:
		_detour = Vector3(-into.z, 0.0, into.x)
		var lean := _detour.dot(wish)
		if absf(lean) > 0.15:
			_detour *= signf(lean)
		elif what and _detour.dot(feet - what.global_position) < 0.0:
			_detour = -_detour
		_detour *= _flip
	_detour_time = 0.7
	return false


# How high the top of what is in front of him is, if it is no more than `limit` above where he is: INF if it is higher, or roofed over.
func _top_ahead(into: Vector3, limit: float) -> float:
	var feet := global_position
	var rise := 0.3
	# (how far off its face is: he may not be right up against it yet)
	var face := RADIUS
	while rise <= limit + 0.06:
		var from := feet + Vector3.UP * rise
		if not _ray(feet + Vector3.UP * 0.3, from).is_empty():
			return INF
		var wall := _ray(from, from + into * (face + 0.45))
		if wall.is_empty():
			var down := _ray(from + into * (face + 0.12), from + into * (face + 0.12) + Vector3.DOWN * (rise + 0.2))
			if down.is_empty():
				return feet.y
			return (down["position"] as Vector3).y
		face = from.distance_to(wall["position"])
		rise += 0.25
	return INF


func _begin_climb(into: Vector3, top: float, quick: bool) -> void:
	_into = into
	_top = top
	_quick = quick
	_over = 0.0
	_base = global_position.y
	_set_state(State.CLIMB)


# Up the face of something and onto it: at once if it is low, slowly if it is a ledge.
func _climb(delta: float) -> void:
	_yaw = rotate_toward(_yaw, atan2(_into.x, _into.z), turn_rate * 2.0 * delta)
	_rear_to = 0.25 if _quick else 0.5
	_gape_to = 0.2
	if global_position.y < _top + 0.04 and _over <= 0.0:
		_up_now = -_into
		_floor_now = _base
		var up := 3.6 if _quick else climb_speed
		velocity = Vector3.UP * up + _into * 0.5
		move_and_slide()
		if is_on_ceiling() or _time > (_top - _base) / up * 2.0 + 1.5:
			_resume()
			_distrust = 4.0
			_flip = -_flip
		return
	velocity = _into * 2.4
	move_and_slide()
	_over += 2.4 * delta
	if _over > 0.62:
		_tried_round = 0.0
		_resume()


func _resume() -> void:
	_stuck_time = 0.0
	_stuck_at = global_position
	_look_rest = 0.0
	_set_state(State.HOMING if _homing else State.HUNT)


# Under a ledge the boy is up on: he rears against it and sways under him, then goes round, or up.
func _ledge(delta: float, boy: Player) -> void:
	if not (loose or _roused):
		_turn_home()
		return
	_stand(delta)
	_yaw = rotate_toward(_yaw, atan2(_into.x, _into.z), turn_rate * delta)
	var rise := _top - global_position.y
	_rear_to = clampf(rise - 0.35, 0.5, 1.9)
	_gape_to = 0.45 + 0.2 * sin(_clock * 2.0)
	if boy == null or boy.is_limp or boy.global_position.y < global_position.y + 0.8:
		_resume()
		return
	_face_head(boy.global_position)
	# (he has come down off it somewhere else, or gone on)
	var to := boy.global_position - global_position
	if Vector2(to.x, to.z).length() > 7.0:
		_resume()
		return
	if _time < ledge_wait:
		return
	if _tried_round <= 0.0:
		var way := _way_round()
		if not way.is_empty():
			_round = way
			_tried_round = 20.0
			_resume()
			return
	_begin_climb(_into, _top, false)


# Looks along the face to either side for a place where the way up is in
# steps he can go over: the end of the ledge, a ramp, a stair. Gives the place
# at the foot of it and the place at the top, or nothing.
func _way_round() -> Array[Vector3]:
	var feet := global_position
	var along := Vector3(-_into.z, 0.0, _into.x)
	var found: Array[Vector3] = []
	for side: float in [1.0, -1.0]:
		for k in range(1, 11):
			var foot := feet + along * side * float(k)
			if not _ray(feet + Vector3.UP * 0.3, foot + Vector3.UP * 0.3).is_empty():
				break
			var level := feet.y
			var at := foot
			for step in 10:
				var next := at + _into * 0.6
				var high := level + step_over + 0.2
				if not _ray(Vector3(at.x, high, at.z), Vector3(next.x, high, next.z)).is_empty():
					break
				var down := _ray(Vector3(next.x, high, next.z), Vector3(next.x, level - 0.6, next.z))
				if down.is_empty() or (down["position"] as Vector3).y > level + step_over + 0.05:
					break
				level = (down["position"] as Vector3).y
				at = next
				if level >= _top - 0.6:
					found = [foot, Vector3(at.x, level, at.z)]
					break
			if not found.is_empty():
				break
		if not found.is_empty():
			break
	return found


# He stops, rears back with his mouth open, and throws his head at where the boy is.
func _strike(delta: float, boy: Player) -> void:
	_stand(delta)
	var hold := 0.2
	var fling := 0.16
	var from := global_position + Vector3.UP * (girth[0] * 0.62 + _rear)
	if _time < strike_warning:
		# He follows the boy round as he rears, but not to the last: then he is committed.
		_rear_to = 1.3
		_gape_to = 1.0
		if boy and _time < strike_warning - hold:
			_face(boy.global_position, delta * 2.5)
			_aim = boy.global_position + Vector3.UP * (0.45 if boy.is_ducking or boy.is_crawling else 0.75)
			_face_head(_aim)
		_strike_from = from
		_tip = from
		return
	var reach := _aim - _strike_from
	reach = reach.normalized() * minf(reach.length() + 0.35, 3.4) - head_way_of(reach) * _head_long * 0.52
	var since := _time - strike_warning
	if since < fling:
		var by := since / fling
		_lunge = reach * by
		_gape_to = 1.0
		# (his mouth, a little in front of where his head is drawn from)
		var tip := _strike_from + _lunge + head_way_of(reach) * _head_long * 0.47
		if boy and not boy.is_limp and not _has_him and (loose or _roused):
			var feet := boy.global_position
			var top := feet + Vector3.UP * (0.65 if boy.is_ducking or boy.is_crawling else 1.15)
			var nearest := Geometry3D.get_closest_points_between_segments(_tip, tip, feet + Vector3.UP * 0.1, top)
			if nearest[0].distance_to(nearest[1]) < catch_distance + 0.2:
				_has_him = true
				caught.emit()
		_tip = tip
	elif since < fling + 0.3:
		_lunge = reach
		_gape_to = 0.0
		_gape = minf(_gape, 0.15)
	elif since < fling + 1.0:
		_lunge = reach * (1.0 - smoothstep(0.0, 1.0, (since - fling - 0.3) / 0.7))
		_rear_to = 0.3
	else:
		_lunge = Vector3.ZERO
		_strike_rest = 0.35
		_gaze = Vector3.INF
		_resume()


func head_way_of(reach: Vector3) -> Vector3:
	return reach.normalized() if reach.length() > 0.01 else _forward()


# A door is shut in his face: he batters at it, and waits.
func _batter_door(delta: float, boy: Player) -> void:
	if not (loose or _roused):
		_turn_home()
		return
	_stand(delta)
	_rear_to = 0.5
	_gape_to = 0.3
	_batter -= delta
	_lunge = Vector3.ZERO
	if _batter < 0.3 and _batter > 0.0:
		# (his head, thrown at it and drawn back)
		_lunge = _into * 0.32 * sin((0.3 - _batter) / 0.3 * PI) + Vector3.DOWN * 0.2 * sin((0.3 - _batter) / 0.3 * PI)
	if _batter <= 0.0:
		_batter = 2.2
		_sound_knock()
	_look_rest -= delta
	if _look_rest > 0.0:
		return
	_look_rest = 0.25
	var gone := not is_instance_valid(_door)
	if not gone:
		var hit := _ray(global_position + Vector3.UP * 0.3, global_position + Vector3.UP * 0.3 + _into * 1.2)
		gone = hit.is_empty() or hit["collider"] != _door
	if gone or (boy and not boy.is_limp and _sees(global_position, boy.global_position, 0.9)):
		_lunge = Vector3.ZERO
		_distrust = 0.0 if not gone else 3.0
		_resume()


# --- Light ---

# Whether the boy is in the light of a fire, and so not to be struck at.
func _see_light(boy: Player) -> void:
	_boy_lit = false
	if not fears_light or boy == null:
		return
	for fire in Nearby.fires(get_tree()):
		if not is_instance_valid(fire) or not fire.is_inside_tree() or not fire.is_visible_in_tree():
			continue
		var out := boy.global_position - fire.global_position
		if Vector2(out.x, out.z).length() < Nearby.reach_of(fire, light_reach) and absf(out.y) < 3.0:
			_boy_lit = true
			return


# Which way to go, given the way he would: round a fire that is in the way,
# and round and round one that the boy is standing in the light of.
func _shy(wish: Vector3, here: Vector3, boy: Player) -> Vector3:
	if not fears_light:
		return wish
	for fire in Nearby.fires(get_tree()):
		if not is_instance_valid(fire) or not fire.is_inside_tree() or not fire.is_visible_in_tree():
			continue
		var out := here - fire.global_position
		if absf(out.y) > 3.5:
			continue
		out.y = 0.0
		var reach := Nearby.reach_of(fire, light_reach)
		var away := out.length()
		if away > reach + 1.3:
			continue
		var from := out / away if away > 0.01 else -_forward()
		if wish.dot(-from) < 0.2 and away > reach:
			continue
		var about := Vector3(-from.z, 0.0, from.x)
		if _boy_lit and boy:
			# He keeps to the edge of it, going round, and now and then turns and goes the other way.
			_held = true
			_circle_time -= get_physics_process_delta_time()
			if _circle_time <= 0.0 or test_move(global_transform, about * _circle * 0.4):
				_circle_time = 3.0 + fmod(_clock * 7.3, 4.0)
				_circle = -_circle
			return (about * _circle + from * clampf((reach + 0.35 - away) * 2.0, -1.0, 1.0)).normalized()
		if about.dot(wish) < 0.0:
			about = -about
		wish = (wish + about * 1.6 + from * clampf((reach + 0.3 - away) * 2.0, 0.0, 1.0)).normalized()
	return wish


# What is left of the way he is going, once light has had its say: he will
# not go further into it, and backs out of it if it comes over him.
func _held_back(going: Vector3, here: Vector3) -> Vector3:
	if not fears_light:
		return going
	for fire in Nearby.fires(get_tree()):
		if not is_instance_valid(fire) or not fire.is_inside_tree() or not fire.is_visible_in_tree():
			continue
		var out := here - fire.global_position
		if absf(out.y) > 3.5:
			continue
		out.y = 0.0
		var reach := Nearby.reach_of(fire, light_reach)
		var away := out.length()
		if away > reach + 0.15:
			continue
		var from := out / away if away > 0.01 else -_forward()
		var inward := going.dot(-from)
		if inward > 0.0:
			going += from * inward
		if away < reach - 0.1:
			going += from * speed * 1.3 * clampf((reach - away) * 3.0, 0.3, 1.0)
			_held = true
	for beam: Node in get_tree().get_nodes_in_group(&"sun_beams"):
		var light := beam as SunBeam
		if light == null:
			continue
		for i in light.path.size() - 1:
			var a := light.path[i]
			var b := light.path[i + 1]
			if maxf(a.y, b.y) < here.y - 0.4 or minf(a.y, b.y) > here.y + 2.6:
				continue
			var near := Geometry2D.get_closest_point_to_segment(Vector2(here.x, here.z), Vector2(a.x, a.z), Vector2(b.x, b.z))
			var out := Vector3(here.x - near.x, 0.0, here.z - near.y)
			var away := out.length()
			if away > BEAM_REACH:
				continue
			var from := out / away if away > 0.01 else -_forward()
			var inward := going.dot(-from)
			if inward > 0.0:
				going += from * inward
				_held = true
			if away < 0.5:
				_recoil = from
				_recoil_time = 0.5
				_spit = 1.0
	return going


# How far under water a place is.
func _depth(at: Vector3) -> float:
	var deep := -1000.0
	for water: Node in get_tree().get_nodes_in_group(&"water"):
		if water is Pool:
			deep = maxf(deep, (water as Pool).depth_at(at))
	return deep


# --- His body ---

# Keeps the place his head has just left, on the path his body lies along.
func _remember(at: Vector3) -> void:
	_prev = at
	if at.distance_to(_path_at[0]) < STEP:
		return
	var room := _room_now
	if _floor_now != -INF and state != State.SETTLING:
		# How much room there is to either side of him here, for his body to swing in.
		var side := Vector3(cos(_yaw), 0.0, -sin(_yaw))
		var low := at + Vector3.UP * 0.3
		room = 1.0
		for way: float in [1.0, -1.0]:
			var hit := _ray(low, low + side * way * 0.85)
			if not hit.is_empty():
				room = minf(room, clampf((low.distance_to(hit["position"]) - thickness * 0.55) / wave, 0.0, 1.0))
	_path_at.insert(0, at)
	_path_up.insert(0, _up_now)
	_path_floor.insert(0, _floor_now)
	_path_room.insert(0, room)
	_room_now = 1.0
	var most := int(length / STEP) + 24
	if _path_at.size() > most:
		_path_at.resize(most)
		_path_up.resize(most)
		_path_floor.resize(most)
		_path_room.resize(most)


func _coil_radius() -> float:
	var end := _coil(0.0)
	return Vector2(end[end.size() - 1].x - _home.origin.x, end[end.size() - 1].z - _home.origin.z).length()


# The coil he lies in, from his head outwards: one turn lying on top, and the rest wound flat round under it.
func _coil(turn: float) -> PackedVector3Array:
	var places := PackedVector3Array()
	var home := _home.origin
	var radius := thickness * 1.2
	var crown := TAU * radius
	var angle := turn
	var along := 0.0
	while along < length + 0.6:
		var high := thickness * 0.82 * (1.0 - smoothstep(crown - 1.4, crown, along))
		places.append(home + Vector3(cos(angle) * radius, high, sin(angle) * radius))
		angle += STEP / radius
		along += STEP
		if along > crown:
			radius += thickness * 1.1 * (STEP / radius) / TAU
	return places


# Lays him as he rests: coiled, or straight down his hole.
func _lay_rest(turn: float) -> void:
	_path_at.clear()
	_path_up.clear()
	_path_floor.clear()
	_path_room.clear()
	if rest == Rest.HOLE:
		for i in int(length / STEP) + 8:
			_path_at.append(_home.origin + Vector3.DOWN * (1.3 + i * STEP))
			_path_up.append(Vector3.RIGHT)
			_path_floor.append(-INF)
			_path_room.append(0.0)
	else:
		_path_at = _coil(turn)
		for i in _path_at.size():
			_path_up.append(Vector3.UP)
			_path_floor.append(_home.origin.y)
			_path_room.append(0.0)
	_travel = 0.0
	_up_now = Vector3.UP
	_room_now = 1.0


# His body is in the boy's way: the boy is put out of it.
func _push_aside(boy: Player) -> void:
	if boy == null or boy.is_limp or state == State.STRIKE:
		return
	var feet := boy.global_position
	if absf(feet.x - global_position.x) > length or absf(feet.z - global_position.z) > length:
		return
	for i in range(3, POINTS, 2):
		var at := spine[i]
		if at.y < feet.y - 0.4 or at.y > feet.y + 1.0:
			continue
		var out := Vector3(feet.x - at.x, 0.0, feet.z - at.z)
		var near := girth[i] + 0.2
		var away := out.length()
		if away < near and away > 0.001:
			boy.move_and_collide(out / away * (near - away))
			return


func _process(delta: float) -> void:
	if state != State.DORMANT:
		_draw(delta)
	_voice(delta)


# Lays his body along its path and tells the shader where it is; and puts his head on the end of it.
func _draw(delta: float) -> void:
	_rear = lerpf(_rear, minf(_rear_to, _headroom), 1.0 - exp(-5.0 * delta))
	_gape = lerpf(_gape, _gape_to, 1.0 - exp(-9.0 * delta))
	var resting := state == State.DORMANT
	var head := _path_at[0] if resting else _prev.lerp(global_position, Engine.get_physics_interpolation_fraction())
	var spacing := length / float(POINTS - 1)
	var count := _path_at.size()
	var a := head
	var a_up := _path_up[0] if resting else _up_now
	var a_floor := _path_floor[0] if resting else _floor_now
	var a_room := 0.0
	var j := 0
	var b := _path_at[0]
	var part := a.distance_to(b)
	var walked := 0.0
	var low := Vector3.INF
	var high := -Vector3.INF
	var wavelength := TAU / WAVE
	for i in POINTS:
		var along := i * spacing
		while along > walked + part and j < count - 1:
			walked += part
			a = b
			a_up = _path_up[j]
			a_floor = _path_floor[j]
			a_room = _path_room[j]
			j += 1
			b = _path_at[j]
			part = a.distance_to(b)
		var share := clampf((along - walked) / maxf(part, 0.0001), 0.0, 1.0)
		var at := a.lerp(b, share)
		var up := a_up.lerp(_path_up[j], share).normalized()
		var radius := girth[i]
		var run := (a - b) / part if part > 0.0001 else Vector3.FORWARD
		var side := up.cross(run)
		# The wave: it stands still on the ground, and he slides through it.
		var swing := wave * smoothstep(0.3, 2.6, along) * lerpf(a_room, _path_room[j], share) * sin(wavelength * (_travel - along))
		if side.length_squared() > 0.001:
			at += side.normalized() * swing
		at += up * radius * 0.62
		var ground := maxf(a_floor, _path_floor[j])
		if ground != -INF and a_floor != -INF:
			at.y = maxf(at.y, ground + radius * 0.62)
		spine[i] = at
		_lift[i] = up
	# His head reared: the first of him comes up off the ground in a curve, sways, and is thrown out in a strike.
	var reach := 1.4 + 1.3 * _rear + _lunge.length() * 0.8
	var forward := _forward()
	var across := Vector3(forward.z, 0.0, -forward.x)
	var sway := sin(_clock * 1.9) * 0.3 * clampf(_rear, 0.0, 1.0) * (0.3 + 0.7 * _path_room[0]) if state != State.STRIKE else 0.0
	for i in POINTS:
		var along := i * spacing
		if along >= reach:
			break
		var share := 1.0 - along / reach
		var eased := share * share * (3.0 - 2.0 * share)
		spine[i] += Vector3.UP * _rear * eased - forward * 0.42 * _rear * sin(PI * share) + across * sway * eased + _lunge * eased * eased
	for i in POINTS:
		low = low.min(spine[i])
		high = high.max(spine[i])
	_body_material.set_shader_parameter(&"spine", spine)
	_body_material.set_shader_parameter(&"lift", _lift)
	_body.custom_aabb = AABB(low, high - low).grow(thickness + 0.3)
	# His head: it looks the way his neck runs, or at the boy when it is reared.
	head_at = spine[0]
	var way := (spine[0] - spine[2])
	way = way.normalized() if way.length() > 0.001 else forward
	if state != State.DORMANT and _lunge == Vector3.ZERO:
		way = (way + forward * 0.8 + across * 0.12 * sin(wavelength * _travel)).normalized()
	if _gaze != Vector3.INF and _rear > 0.3 and (state == State.HELD or state == State.LEDGE or state == State.STRIKE or state == State.WAKING):
		var to := _gaze - head_at
		if to.length() > 0.2:
			way = way.lerp(to.normalized(), clampf(_rear * 1.6, 0.0, 1.0)).normalized()
	if _lunge.length() > 0.2:
		way = way.lerp(_lunge.normalized(), 0.9).normalized()
	head_way = head_way.lerp(way, 1.0 - exp(-14.0 * delta)).normalized() if delta > 0.0 else way
	var x := Vector3.UP.cross(head_way)
	x = x.normalized() if x.length() > 0.01 else across
	_skull.global_transform = Transform3D(Basis(x, head_way.cross(x), head_way).scaled_local(Vector3.ONE * thickness / 0.5), head_at - head_way * 0.06)
	# His tongue flicks when his mouth is nearly shut.
	_tongue = maxf(0.0, sin(_clock * 4.2) * 2.0 - 1.0) * (1.0 if fmod(_clock, 3.0) < 1.5 else 0.0) if _gape < 0.3 and state != State.DORMANT else 0.0
	_head_material.set_shader_parameter(&"gape", _gape * 0.95)
	_head_material.set_shader_parameter(&"tongue", _tongue)
	_head_material.set_shader_parameter(&"flick", _clock * 31.0)
	_head_material.set_shader_parameter(&"glow", 0.5 if state == State.DORMANT else 1.5 + 0.4 * sin(_clock * 5.0))
	if _blades:
		var many := _blades.multimesh
		for k in many.instance_count:
			var i := int((0.2 + 0.5 * k / maxf(many.instance_count - 1, 1.0)) * (POINTS - 1))
			var run := (spine[i - 1] - spine[i + 1]).normalized()
			var up := _lift[i]
			var side := up.cross(run).normalized() if absf(up.dot(run)) < 0.95 else Vector3.RIGHT
			up = run.cross(side)
			var tip := Basis(side, up, run) * Basis.from_euler(Vector3(0.5 - 0.35 * k, 0.0, 0.55 * (1.0 if k % 2 == 0 else -1.0)))
			many.set_instance_transform(k, Transform3D(tip, spine[i] + up * girth[i] * 0.55))


# --- What he is made of ---

func _build() -> void:
	if _body_shader == null:
		_body_shader = Shader.new()
		_body_shader.code = BODY_SHADER + LIGHT
		_head_shader = Shader.new()
		_head_shader.code = HEAD_SHADER + LIGHT
	# The model (tools/build_apophis.py): his head, one length of his body, and a knife. It is read, and put away.
	var model := MODEL.instantiate()
	var parts := {}
	for part: MeshInstance3D in model.find_children("*", "MeshInstance3D", true, false):
		for part_name: String in ["head", "body", "knife"]:
			if String(part.name).contains(part_name):
				parts[part_name] = part
	_body_material = ShaderMaterial.new()
	_body_material.shader = _body_shader
	_body = MeshInstance3D.new()
	_body.mesh = _body_mesh((parts["body"] as MeshInstance3D).mesh)
	_body.material_override = _body_material
	_body.top_level = true
	add_child(_body)
	_body.global_transform = Transform3D.IDENTITY
	_head_material = ShaderMaterial.new()
	_head_material.shader = _head_shader
	_skull = MeshInstance3D.new()
	_skull.mesh = _head_mesh(parts["head"])
	_skull.material_override = _head_material
	_skull.top_level = true
	_skull.extra_cull_margin = 1.0
	add_child(_skull)
	if knives > 0:
		var many := MultiMesh.new()
		many.transform_format = MultiMesh.TRANSFORM_3D
		many.mesh = _knife_mesh((parts["knife"] as MeshInstance3D).mesh)
		many.instance_count = knives
		_blades = MultiMeshInstance3D.new()
		_blades.multimesh = many
		_blades.top_level = true
		_blades.custom_aabb = AABB(Vector3.ONE * -4000.0, Vector3.ONE * 8000.0)
		add_child(_blades)
		_blades.global_transform = Transform3D.IDENTITY
	model.free()
	if rest == Rest.HOLE:
		_pit = MeshInstance3D.new()
		_pit.mesh = _pit_mesh()
		_pit.position.y = 0.03
		_pit.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(_pit)
		_pit.top_level = true
		_pit.global_position = global_position + Vector3.UP * 0.03
	if voice:
		_sounds()
		_hiss = _player(_hiss_stream)
		_scrape = _player(_scrape_stream)
		_knock = _player(_knock_stream)


# A mesh of the model's, all its surfaces as one: each point's place, the way it faces, the colour of its
# material (so that the whole is one thing to draw), the name of that material, and the corners of its triangles.
func _read(mesh: Mesh) -> Dictionary:
	var places := PackedVector3Array()
	var normals := PackedVector3Array()
	var tints := PackedColorArray()
	var labels := PackedStringArray()
	var corners := PackedInt32Array()
	var hung: Array[PackedInt32Array] = []
	var weights: Array[PackedFloat32Array] = []
	for surface in mesh.get_surface_count():
		var arrays := mesh.surface_get_arrays(surface)
		var material := mesh.surface_get_material(surface) as BaseMaterial3D
		var first := places.size()
		var points: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		places.append_array(points)
		normals.append_array(arrays[Mesh.ARRAY_NORMAL])
		for k in points.size():
			tints.append(material.albedo_color.srgb_to_linear() if material else Color.WHITE)
			labels.append(material.resource_name if material else "")
		for corner: int in (arrays[Mesh.ARRAY_INDEX] as PackedInt32Array):
			corners.append(first + corner)
		if arrays[Mesh.ARRAY_BONES] != null:
			var bones: PackedInt32Array = arrays[Mesh.ARRAY_BONES]
			var shares: PackedFloat32Array = arrays[Mesh.ARRAY_WEIGHTS]
			var each := bones.size() / points.size()
			for k in points.size():
				hung.append(bones.slice(k * each, (k + 1) * each))
				weights.append(shares.slice(k * each, (k + 1) * each))
	return {"places": places, "normals": normals, "tints": tints, "labels": labels, "corners": corners, "hung": hung, "weights": weights}


# His body: the model's one length of it laid end to end for as long as he is, thinned at his neck and down his
# tail (`girth_at`), as a straight tube for the shader to bend: x and y across him, and UV2.x how far along.
func _body_mesh(source: Mesh) -> ArrayMesh:
	var one := _read(source)
	var from: PackedVector3Array = one["places"]
	var period := 0.0
	var half := 0.0
	for at in from:
		period = maxf(period, -at.z)
		half = maxf(half, absf(at.x) / 1.08)
	var places := PackedVector3Array()
	var normals := PackedVector3Array()
	var tints := PackedColorArray()
	var along := PackedVector2Array()
	var corners := PackedInt32Array()
	for copy in ceili(length / period):
		var first := places.size()
		for k in from.size():
			var share := minf(copy * period - from[k].z, length) / length
			var size := girth_at(share) / half
			var faces: Vector3 = one["normals"][k]
			# (the model runs back from his head along -Z and the shader's tube forward along its own length: it is turned about, not mirrored)
			places.append(Vector3(-from[k].x * size, from[k].y * size, 0.0))
			normals.append(Vector3(-faces.x, faces.y, 0.0).normalized())
			tints.append(one["tints"][k])
			along.append(Vector2(share, 0.0))
		for corner: int in one["corners"]:
			corners.append(first + corner)
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = places
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_COLOR] = tints
	arrays[Mesh.ARRAY_TEX_UV2] = along
	arrays[Mesh.ARRAY_INDEX] = corners
	var made := ArrayMesh.new()
	made.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return made


# His head: the model's, as one thing to draw. The model hangs it from bones (`jaw`, `tongue`, `fangs`); here
# each point is told which of them it goes with and how much (UV2), and the shader works them. What is of the
# materials `eye` and `pupil` shines by itself, and the inside of his mouth a little (UV.x).
func _head_mesh(part: MeshInstance3D) -> ArrayMesh:
	var one := _read(part.mesh)
	var skeleton := part.get_node_or_null(part.skeleton) as Skeleton3D
	var bone_of := PackedStringArray()
	for bind in part.skin.get_bind_count():
		var bind_name := String(part.skin.get_bind_name(bind))
		bone_of.append(bind_name if bind_name != "" else skeleton.get_bone_name(part.skin.get_bind_bone(bind)))
	var size := thickness / 0.5
	var hinge := skeleton.get_bone_global_rest(skeleton.find_bone("jaw")).origin
	_head_material.set_shader_parameter(&"hinge", Vector2(hinge.y, hinge.z))
	_head_material.set_shader_parameter(&"root", skeleton.get_bone_global_rest(skeleton.find_bone("tongue")).origin.z)
	_head_material.set_shader_parameter(&"roof", skeleton.get_bone_global_rest(skeleton.find_bone("fangs")).origin.y)
	var places: PackedVector3Array = one["places"]
	var shines := PackedVector2Array()
	var goes := PackedVector2Array()
	_head_long = 0.0
	for k in places.size():
		var with := {"jaw": 0.0, "tongue": 0.0, "fangs": 0.0}
		for n in (one["hung"][k] as PackedInt32Array).size():
			var bone := bone_of[one["hung"][k][n]]
			if with.has(bone):
				with[bone] += one["weights"][k][n]
		if with["fangs"] > 0.5:
			goes.append(Vector2(3.0, 0.0))
		elif with["tongue"] > 0.5:
			goes.append(Vector2(2.0, 0.8))
		elif with["jaw"] > 0.01:
			goes.append(Vector2(1.0, with["jaw"]))
		else:
			goes.append(Vector2.ZERO)
			_head_long = maxf(_head_long, places[k].z * size)
		var label: String = one["labels"][k]
		shines.append(Vector2(1.0 if label == "eye" or label == "pupil" else 0.3 if label == "mouth" else 0.0, 0.0))
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = places
	arrays[Mesh.ARRAY_NORMAL] = one["normals"]
	arrays[Mesh.ARRAY_COLOR] = one["tints"]
	arrays[Mesh.ARRAY_TEX_UV] = shines
	arrays[Mesh.ARRAY_TEX_UV2] = goes
	arrays[Mesh.ARRAY_INDEX] = one["corners"]
	var made := ArrayMesh.new()
	made.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return made


# A knife, stuck in him point first: the model's, as one thing to draw.
func _knife_mesh(source: Mesh) -> ArrayMesh:
	var one := _read(source)
	var size := thickness / 0.5
	var places: PackedVector3Array = one["places"]
	for k in places.size():
		places[k] *= size
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = places
	arrays[Mesh.ARRAY_NORMAL] = one["normals"]
	arrays[Mesh.ARRAY_COLOR] = one["tints"]
	arrays[Mesh.ARRAY_INDEX] = one["corners"]
	var made := ArrayMesh.new()
	made.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	var metal := StandardMaterial3D.new()
	metal.vertex_color_use_as_albedo = true
	metal.roughness = 0.6
	made.surface_set_material(0, metal)
	return made


# His hole: a ragged dark place in the ground.
func _pit_mesh() -> ArrayMesh:
	var tool := SurfaceTool.new()
	tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	var rim: Array[Vector3] = []
	for k in 14:
		var far := thickness * (1.5 + 0.28 * sin(k * 2.7) + 0.16 * sin(k * 5.1))
		rim.append(Vector3(cos(TAU * k / 14.0) * far, 0.0, sin(TAU * k / 14.0) * far))
	for k in 14:
		tool.add_vertex(Vector3.ZERO)
		tool.add_vertex(rim[(k + 1) % 14])
		tool.add_vertex(rim[k])
	var made := tool.commit()
	var dark := StandardMaterial3D.new()
	dark.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	dark.albedo_color = Color(0.015, 0.012, 0.01)
	dark.cull_mode = BaseMaterial3D.CULL_DISABLED
	made.surface_set_material(0, dark)
	return made


## How many triangles he is, and how many things are drawn for him.
func cost() -> Dictionary:
	var triangles := 0
	var draws := 0
	for part: GeometryInstance3D in [_body, _skull, _blades, _pit]:
		if part == null:
			continue
		draws += 1
		var mesh: Mesh = (part as MultiMeshInstance3D).multimesh.mesh if part is MultiMeshInstance3D else (part as MeshInstance3D).mesh
		var count: int = mesh.surface_get_array_index_len(0) / 3 if mesh.surface_get_array_index_len(0) > 0 else mesh.surface_get_array_len(0) / 3
		triangles += count * ((part as MultiMeshInstance3D).multimesh.instance_count if part is MultiMeshInstance3D else 1)
	return {"triangles": triangles, "draws": draws}


# --- His voice: a long dry hiss, and the scrape of his scales, both made here from noise ---

func _player(stream: AudioStream) -> AudioStreamPlayer3D:
	var player := AudioStreamPlayer3D.new()
	player.stream = stream
	# (how loud he is says how near he is to the boy, wherever the camera is)
	player.attenuation_model = AudioStreamPlayer3D.ATTENUATION_DISABLED
	player.volume_db = -60.0
	player.position.y = 0.4
	add_child(player)
	return player


func _voice(delta: float) -> void:
	if _hiss == null:
		return
	var boy := _him()
	if state == State.DORMANT or boy == null:
		_loud = move_toward(_loud, 0.0, delta * 2.0)
	else:
		# Louder as he nears: nothing at forty metres, all of it at three.
		var away := head_at.distance_to(boy.global_position)
		_loud = move_toward(_loud, pow(1.0 - clampf((away - 3.0) / 37.0, 0.0, 1.0), 2.2), delta * 1.5)
	_spit = move_toward(_spit, 0.0, delta * 1.4)
	if _loud <= 0.001 and _spit <= 0.001:
		if _hiss.playing:
			_hiss.stop()
			_scrape.stop()
		return
	if not _hiss.playing:
		_hiss.play()
		_scrape.play()
	var breath := 0.75 + 0.25 * sin(_clock * 1.3)
	var hiss := _loud * (0.35 + 0.65 * _gape) * breath + _spit * 0.9
	_hiss.volume_db = linear_to_db(clampf(hiss, 0.0001, 1.2))
	_hiss.pitch_scale = 0.9 + 0.25 * _gape + 0.3 * _spit
	var slide := clampf(Vector2(velocity.x, velocity.z).length() / maxf(speed, 0.1), 0.0, 1.2)
	_scrape.volume_db = linear_to_db(clampf(_loud * slide * 0.8, 0.0001, 1.0))
	_scrape.pitch_scale = 0.8 + 0.3 * slide


func _sound_knock() -> void:
	if _knock:
		_knock.volume_db = linear_to_db(clampf(0.25 + _loud, 0.0, 1.0))
		_knock.play()


func _sounds() -> void:
	if _hiss_stream:
		return
	var rate := 22050
	var chance := RandomNumberGenerator.new()
	chance.seed = 39
	# The hiss: the top of the noise, with the breath in it rising and falling.
	var samples := PackedFloat32Array()
	samples.resize(rate * 2)
	var last := 0.0
	var smooth := 0.0
	for k in samples.size():
		var noise := chance.randf_range(-1.0, 1.0)
		var sharp := noise - last
		last = noise
		smooth = lerpf(smooth, sharp, 0.55)
		samples[k] = (sharp * 0.5 + smooth * 0.5) * 0.42 * (0.8 + 0.2 * sin(TAU * k / float(samples.size()) * 3.0))
	_hiss_stream = _wave(samples, rate, true)
	# The scrape: lower, and in rasps, as each length of him takes hold of the ground and lets go.
	samples = PackedFloat32Array()
	samples.resize(int(rate * 1.6))
	var low := 0.0
	for k in samples.size():
		var noise := chance.randf_range(-1.0, 1.0)
		low = lerpf(low, noise, 0.18)
		var along := float(k) / samples.size()
		var rasp := pow(absf(sin(PI * along * 5.0)), 2.5) * (0.6 + 0.4 * sin(TAU * along * 2.0 + 1.0))
		var grit := 0.5 + 0.5 * signf(sin(TAU * along * 5.0 * 37.0 + sin(along * 90.0)))
		samples[k] = (low * 1.3 + (noise - low) * 0.25) * rasp * (0.55 + 0.45 * grit) * 0.6
	_scrape_stream = _wave(samples, rate, true)
	# His head against a door.
	samples = PackedFloat32Array()
	samples.resize(int(rate * 0.4))
	low = 0.0
	for k in samples.size():
		var along := float(k) / rate
		low = lerpf(low, chance.randf_range(-1.0, 1.0), 0.06)
		samples[k] = (sin(TAU * 62.0 * along) * 0.7 + low * 1.5) * exp(-along * 14.0)
	_knock_stream = _wave(samples, rate, false)


static func _wave(samples: PackedFloat32Array, rate: int, loops: bool) -> AudioStreamWAV:
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
