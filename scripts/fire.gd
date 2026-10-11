class_name Fire
extends Node3D
## A fire, made of a great many small pictures of flame: each one a lick that
## is lit low down in the fire, hot and pale, is carried up, drawn out to a
## point, cools through orange to a dark red, comes apart and is gone, while
## others are lit under it. The pictures are frames of one sheet
## (`textures/fire_sheet.res`, painted by `tools/bake_fire_sheet.gd`), each
## lick showing the frame for its age; they are soft, and run into one
## another. A fire that is carried leaves its flame streaming behind it.
## Sparks stream up from it in the hot air, wandering and winking; now and
## then it spits, and a handful of embers are thrown out and fall. It glows (a
## soft light in the air round it, drawn, since a phone has no bloom), and the
## light it casts gutters and reaches now further and now less far. Smoke goes
## up from it in soft puffs that thin as they go. This node is at its foot.
##
##     add_child(Fire.torch())        # or candle(), brazier(), bonfire()
##
## or `Fire.new()` and set `size` (the height of the flame, in metres) and the
## rest. A fire is three draw calls (its flames; its sparks and smoke; its
## glow) and one light. Where each lick of flame is and how old is worked out
## in its shader, from the clock; the sparks and smoke are moved here, a few
## dozen of them, and drawn at once.

## How tall the flame is, in metres: 0.07 a candle, 0.3 a torch, 0.7 a brazier, 2 a bonfire.
@export var size := 0.3: set = _set_size
## How wide the fire is at its foot, as a share of its height.
@export var spread := 0.5: set = _set_spread
## How many licks of flame it is made of (0: as many as suits its size and spread).
@export var tongues := 0: set = _set_tongues

@export_group("Colour")
## The colours, from the heart of the flame outwards.
@export var core := Color(1.0, 0.95, 0.68): set = _set_core
@export var body := Color(1.0, 0.56, 0.12): set = _set_body
@export var tip := Color(0.78, 0.16, 0.05): set = _set_tip
## How bright it all is: the flame, the sparks and the light together.
@export var intensity := 1.0: set = _set_intensity
## The glow in the air round the whole fire (0: none), and how far out it
## reaches, as a multiple of the height of the flame.
@export_range(0.0, 1.0) var glow := 0.5
@export var glow_reach := 2.6

@export_group("Motion")
## How fast the flame streams (1: as suits its size; a small flame is quicker).
@export var speed := 1.0: set = _set_speed
## How far it leans over (a draught), as a share of its height towards its own +X.
@export var lean := 0.0: set = _set_lean
## How torn the flame is: 1 a fire, 0.3 a candle flame, which barely stirs.
@export_range(0.0, 1.5) var ragged := 1.0: set = _set_ragged
## How far the flame streams out behind a fire that is being carried, as a
## multiple of its height (0: it does not).
@export var streams := 1.6
## Sparks going up from it, and smoke.
@export var embers := true
@export var smoke := true
## How many sparks (1: as suits its size), and how often it spits a handful of
## embers out (times a second, for a fire a metre tall; 0: never).
@export var sparks := 1.0
@export var spits := 0.35

@export_group("Light")
@export var light := true: set = _set_light
@export var light_energy := 2.4
## How far the light reaches, in metres (0: as suits its size).
@export var light_range := 0.0: set = _set_light_range
@export var light_shadows := false: set = _set_light_shadows
## Where the light is, from the foot of the flame (it is put a little above the
## middle of the flame as well). A torch on a wall wants its light out from the wall.
@export var light_offset := Vector3.ZERO: set = _set_light_offset
## How much the light gutters, as a share of its strength: quick, uneven
## shudders on top of a slower heave, and never the same twice.
@export_range(0.0, 0.6) var flicker := 0.3
## How much further and less far the light reaches as it does, as a share of its range.
@export_range(0.0, 0.5) var breathing := 0.16

const MOTES := 72
const SHEET := "res://textures/fire_sheet.res"
## The flames. Each instance is one lick: it stands at the foot of a fire (the
## instance's place), which is as wide as the instance's X scale and as tall
## as its Y scale, and its custom data holds a number of its own in x. It is
## lit, rises and goes out over and over, each time somewhere else in the foot.
const FLAME := """
shader_type spatial;
render_mode unshaded, blend_mix, depth_draw_never, cull_disabled, shadows_disabled, fog_disabled, skip_vertex_transform;

uniform sampler2D sheet : filter_linear, repeat_disable;
uniform vec3 core : source_color = vec3(1.0, 0.95, 0.68);
uniform vec3 body : source_color = vec3(1.0, 0.56, 0.12);
uniform vec3 tip : source_color = vec3(0.78, 0.16, 0.05);
uniform float intensity = 1.0;
// Seconds, from the script, already scaled by how fast this fire streams.
uniform float clock = 0.0;
uniform float lean = 0.0;
// How much the licks wander (a candle: hardly).
uniform float ragged = 1.0;
// The fire as a whole flaring up (above nought) or sinking, from the script.
uniform float flare = 0.0;
// How far behind the fire a lick has been left by the end of its life (in
// the world, in metres): a fire that is carried streams out behind.
uniform vec3 trail = vec3(0.0);

varying float age;
varying float flip;
varying float own;
varying float outer;

// (worked out in whole numbers: the same on every renderer)
float hash(vec2 p) {
	ivec2 c = ivec2(round(p));
	uint h = uint(c.x) * 668265261u ^ (uint(c.y) * 374761393u);
	h ^= h >> 15u;
	h *= 2246822519u;
	h ^= h >> 13u;
	h *= 3266489917u;
	h ^= h >> 16u;
	return float(h) / 4294967295.0;
}

void vertex() {
	float seed = INSTANCE_CUSTOM.x;
	float number = floor(seed * 4093.0);
	// Each lick lives a little longer or shorter than the next, so that they
	// never fall into step; and each life of it is its own.
	float life = mix(0.75, 1.35, hash(vec2(number, 1.0)));
	float phase = clock / life + seed * 29.0;
	float turn_of = floor(phase);
	age = phase - turn_of;
	vec2 key = vec2(number, turn_of + 2.0);
	float a = hash(key);
	float b = hash(key + vec2(11.0, 0.0));
	float c = hash(key + vec2(23.0, 0.0));
	float d = hash(key + vec2(37.0, 0.0));
	own = c;
	outer = b;
	flip = d > 0.5 ? 1.0 : -1.0;

	vec3 foot = MODEL_MATRIX[3].xyz;
	float wide = length(MODEL_MATRIX[0].xyz);
	float high = length(MODEL_MATRIX[1].xyz) * (1.0 + 0.16 * flare);
	vec3 up = normalize(MODEL_MATRIX[1].xyz);
	vec3 across = normalize(MODEL_MATRIX[0].xyz);
	vec3 along = normalize(cross(across, up));
	// It is lit somewhere in the foot of the fire, and is drawn in to the
	// middle as it goes up: a fire comes to a point.
	// (small when it is lit, soon full, and less again as it goes)
	float big = (high * 0.3 + wide * 0.22) * mix(0.5, 1.0, smoothstep(0.0, 0.25, age)) * mix(1.0, 0.55, smoothstep(0.3, 1.0, age)) * (0.8 + 0.4 * b);
	float round_it = a * 6.2832;
	float out_from = wide * 0.5 * sqrt(b) * (1.0 - 0.8 * age);
	float rise = big * 0.5 + high * (0.02 + (0.7 + 0.4 * c) * pow(age, 0.9));
	float sway = (sin(clock * 3.3 + seed * 40.0) * 0.07 + (d - 0.5) * 0.22) * ragged * high * age;
	vec3 centre = foot + (across * cos(round_it) + along * sin(round_it)) * out_from + up * rise
			+ across * (sway + lean * high * age * age) + trail * pow(age, 1.4);

	// Its card stands up along the fire and is turned about that to face the
	// camera. Looked down on, it tips back towards the eye, so that it is not
	// seen edge on; and it lies over along the way it has been left behind.
	vec3 to_eye = normalize(CAMERA_POSITION_WORLD - centre);
	vec3 stand = normalize(up * high - trail * 1.2 * age + across * lean * high * age);
	stand = normalize(mix(stand, INV_VIEW_MATRIX[1].xyz, smoothstep(0.55, 0.98, abs(dot(to_eye, stand))) * 0.85));
	vec3 side = normalize(cross(stand, to_eye) + vec3(0.00001, 0.0, 0.0));
	vec2 corner = vec2(UV.x - 0.5, 0.5 - UV.y);
	vec3 world = centre + side * corner.x * big + stand * corner.y * big * 1.3;
	VERTEX = (VIEW_MATRIX * vec4(world, 1.0)).xyz;
	NORMAL = mat3(VIEW_MATRIX) * to_eye;
}

float frame(float index, vec2 at) {
	vec2 cell = vec2(mod(index, 8.0), floor(index / 8.0));
	return texture(sheet, (cell + at) / 8.0).r;
}

void fragment() {
	vec2 at = clamp(vec2(flip > 0.0 ? UV.x : 1.0 - UV.x, UV.y), vec2(0.01), vec2(0.99));
	// The picture for its age, run into the next one.
	float along = age * 63.0;
	float first = floor(along);
	float heat = mix(frame(first, at), frame(min(first + 1.0, 63.0), at), along - first);
	// It cools as it goes up: pale where a new lick is hottest, then orange,
	// and a dark red at the last. Its edges are not drawn: it thins away to
	// nothing there, and one lick runs into the next.
	float cool = 0.12 + outer * 0.22 + age * (0.8 + 0.3 * own) + (1.0 - heat * heat) * 0.3;
	vec3 colour = mix(core, body, smoothstep(0.2, 0.55, cool));
	colour = mix(colour, tip, smoothstep(0.62, 1.05, cool));
	ALBEDO = colour * intensity;
	ALPHA = smoothstep(0.0, 0.8, heat) * smoothstep(0.0, 0.2, age) * (1.0 - smoothstep(0.78, 1.0, age)) * 0.8;
}
"""

## Sparks and smoke: flat shapes turned to the camera. A spark is a small
## bright point with a glow round it, that winks as it goes and does not need
## lighting; a puff of smoke is a frame of the sheet, soft and dark, that is
## lit by what is about and thins as it ages.
const MOTE := """
shader_type spatial;
render_mode blend_mix, depth_draw_never, cull_disabled, shadows_disabled;

uniform sampler2D sheet : filter_linear, repeat_disable;
uniform vec3 spark : source_color = vec3(1.0, 0.6, 0.15);
uniform vec3 hot : source_color = vec3(1.0, 0.94, 0.62);
uniform vec3 soot : source_color = vec3(0.2, 0.18, 0.17);
uniform float intensity = 1.0;
uniform float thickness = 0.34;

varying float age;
varying float seed;
varying float kind;

void vertex() {
	age = INSTANCE_CUSTOM.x;
	seed = INSTANCE_CUSTOM.y;
	kind = INSTANCE_CUSTOM.z;
	float big = length(MODEL_MATRIX[0].xyz);
	MODELVIEW_MATRIX = VIEW_MATRIX * mat4(INV_VIEW_MATRIX[0] * big, INV_VIEW_MATRIX[1] * big, INV_VIEW_MATRIX[2] * big, MODEL_MATRIX[3]);
	MODELVIEW_NORMAL_MATRIX = mat3(MODELVIEW_MATRIX);
}

float frame(float index, vec2 at) {
	vec2 cell = vec2(mod(index, 8.0), floor(index / 8.0));
	return texture(sheet, (cell + at) / 8.0).g;
}

void fragment() {
	vec2 at = UV * 2.0 - 1.0;
	ROUGHNESS = 1.0;
	SPECULAR = 0.0;
	if (kind < 0.5 || kind > 1.5) {
		// A spark: a bright point in the middle of its card, pale while it is
		// new, then orange, then a dull red and gone; and a glow round it. It
		// winks: brighter and dimmer many times a second, each in its own time.
		float from_middle = length(at);
		float point = 1.0 - smoothstep(0.12, 0.34, from_middle);
		float wink = 0.6 + 0.4 * sin(TIME * (17.0 + seed * 23.0) + seed * 90.0) * sin(TIME * (7.0 + seed * 11.0));
		float round_it = 1.0 - smoothstep(0.0, 1.0, from_middle);
		ALBEDO = vec3(0.0);
		vec3 colour = mix(mix(hot, spark, smoothstep(0.0, 0.35, age)), spark * vec3(0.8, 0.35, 0.2), smoothstep(0.6, 1.0, age));
		EMISSION = colour * intensity * wink * (1.0 + point);
		ALPHA = max(point, round_it * round_it * 0.45) * wink * (1.0 - smoothstep(0.7, 1.0, age));
	} else {
		// (each puff turned its own way round, so that no two look alike)
		float turn = seed * 6.2832;
		vec2 turned = vec2(at.x * cos(turn) - at.y * sin(turn), at.x * sin(turn) + at.y * cos(turn));
		vec2 on_sheet = clamp(turned * 0.5 + 0.5, vec2(0.01), vec2(0.99));
		float along = clamp(age * 1.15, 0.0, 1.0) * 63.0;
		float first = floor(along);
		float dense = mix(frame(first, on_sheet), frame(min(first + 1.0, 63.0), on_sheet), along - first);
		dense *= 1.0 - smoothstep(0.7, 1.0, length(turned));
		ALBEDO = soot * mix(0.75, 1.1, at.y * 0.5 + 0.5);
		// (lit a little from below by the fire while it is new)
		EMISSION = spark * 0.14 * intensity * (1.0 - smoothstep(0.0, 0.3, age));
		ALPHA = dense * thickness * smoothstep(0.0, 0.12, age) * (1.0 - smoothstep(0.55, 1.0, age));
	}
}

void light() {
	DIFFUSE_LIGHT += clamp(ATTENUATION, 0.0, 1.0) * LIGHT_COLOR / PI * 0.7;
}
"""

## The glow: light in the air round the fire, drawn as one soft round card
## turned to the camera and added to what is behind it.
const GLOW := """
shader_type spatial;
render_mode unshaded, blend_add, depth_draw_never, cull_disabled, shadows_disabled, fog_disabled;

uniform vec3 colour : source_color = vec3(1.0, 0.56, 0.12);
uniform float power = 0.5;

void vertex() {
	float big = length(MODEL_MATRIX[0].xyz);
	MODELVIEW_MATRIX = VIEW_MATRIX * mat4(INV_VIEW_MATRIX[0] * big, INV_VIEW_MATRIX[1] * big, INV_VIEW_MATRIX[2] * big, MODEL_MATRIX[3]);
}

void fragment() {
	float out_from = length(UV * 2.0 - 1.0);
	float soft = 1.0 - smoothstep(0.0, 1.0, out_from);
	// (bright close in to the flame, and a long faint skirt)
	ALBEDO = colour * (soft * soft * 0.55 + pow(soft, 5.0) * 0.6) * power;
}
"""

static var _flame_shader: Shader
static var _mote_shader: Shader
static var _glow_shader: Shader


## The shader the flames are drawn with, with the sheet of pictures in it:
## for anything else that burns (oil does) to draw its flames the same way.
static func flame_shader() -> Shader:
	_shaders()
	return _flame_shader


static func _shaders() -> void:
	if _flame_shader:
		return
	var sheet: Texture2D = load(SHEET)
	_flame_shader = Shader.new()
	_flame_shader.code = FLAME
	_flame_shader.set_default_texture_parameter(&"sheet", sheet)
	_mote_shader = Shader.new()
	_mote_shader.code = MOTE
	_mote_shader.set_default_texture_parameter(&"sheet", sheet)
	_glow_shader = Shader.new()
	_glow_shader.code = GLOW

var _flames: MultiMeshInstance3D
var _motes: MultiMeshInstance3D
var _lamp: OmniLight3D
var _glow: MeshInstance3D
var _glow_material: ShaderMaterial
var _reach_now := 0.0
var _spit_due := 1.0
var _flame_material: ShaderMaterial
var _mote_material: ShaderMaterial
var _time := 0.0
var _was := Vector3.ZERO
var _moving := Vector3.ZERO
var _clock := 0.0
## Each spark or puff: where, which way it is going, how big, how old (1:
## spent), a number of its own, and which it is (0: spark, 1: smoke).
var _at := PackedVector3Array()
var _going := PackedVector3Array()
var _big := PackedFloat32Array()
var _age := PackedFloat32Array()
var _life := PackedFloat32Array()
var _seed := PackedFloat32Array()
var _kind := PackedFloat32Array()
var _next := 0
var _spark_due := 0.0
var _smoke_due := 0.0


## A candle flame: no sparks, no smoke, a small light.
static func candle() -> Fire:
	var fire := _make(0.07, 0.42, 0.7, 3.0, false, false)
	fire.ragged = 0.3
	fire.flicker = 0.07
	return fire

## A torch on a wall or in a hand.
static func torch() -> Fire:
	return _make(0.3, 0.5, 2.4, 9.0, true, true)

## A bowl of fire on a stand.
static func brazier() -> Fire:
	return _make(0.7, 0.8, 3.2, 12.0, true, true)

## A big fire on the ground.
static func bonfire() -> Fire:
	return _make(2.0, 0.85, 5.0, 20.0, true, true)


static func _make(tall: float, wide: float, energy: float, reach: float, sparks: bool, smokes: bool) -> Fire:
	var fire := Fire.new()
	fire.size = tall
	fire.spread = wide
	fire.light_energy = energy
	fire.light_range = reach
	fire.embers = sparks
	fire.smoke = smokes
	return fire


func _ready() -> void:
	# (no two fires in step)
	_time = randf() * 50.0
	_clock = randf() * 50.0
	_build()
	_was = global_position


func _process(delta: float) -> void:
	_time += delta
	# (a small flame streams faster than a big one: about as the root of its height)
	_clock += delta * speed * 1.15 / pow(maxf(size, 0.02), 0.4)
	_flame_material.set_shader_parameter(&"clock", _clock)
	# It gutters: a slow heave, and on it quick shudders that come unevenly
	# and are never the same twice (noise, not waves: nothing in it comes round).
	var heave := _wander(_time * 1.3) * 2.0 - 1.0
	var shudder := (_wander(_time * 7.5 + 40.0) * 2.0 - 1.0) * 0.6 + (_wander(_time * 19.0 + 90.0) * 2.0 - 1.0) * 0.4
	var waver := clampf(0.45 * heave + 0.75 * shudder, -1.0, 1.0)
	_flame_material.set_shader_parameter(&"flare", waver)
	# Carried, its flame streams out behind: each lick is left where it was lit.
	if delta > 0.0:
		var now := global_position
		var going := (now - _was) / delta
		_was = now
		# (set down or snatched across the level, it has not flown there)
		if going.length() > 40.0:
			going = Vector3.ZERO
		_moving = _moving.lerp(going, 1.0 - exp(-9.0 * delta))
	var left := -_moving * pow(maxf(size, 0.02), 0.4) / (1.15 * maxf(speed, 0.05))
	_flame_material.set_shader_parameter(&"trail", left.limit_length(size * streams))
	if _lamp:
		_lamp.light_energy = light_energy * intensity * (1.0 + flicker * waver)
		# (and the light it throws reaches further and less far: slowly, with a little of the shudder in it)
		_lamp.omni_range = _reach_now * (1.0 + breathing * (0.75 * heave + 0.25 * shudder))
	if _glow:
		var swell := 1.0 + 0.22 * heave + 0.12 * shudder
		_glow.scale = Vector3.ONE * size * glow_reach * swell
		_glow_material.set_shader_parameter(&"power", glow * intensity * (1.0 + 0.7 * flicker * waver))
	_flames.scale = Vector3(1.0, 1.0 + 0.3 * flicker * waver, 1.0)
	_move_motes(delta)


# A number that wanders smoothly between 0 and 1 as `along` goes on.
static func _wander(along: float) -> float:
	var whole := floorf(along)
	var part := along - whole
	part = part * part * (3.0 - 2.0 * part)
	return lerpf(_chance(int(whole)), _chance(int(whole) + 1), part)


static func _chance(n: int) -> float:
	n = (n * 374761393 + 668265263) & 0x7fffffff
	n = ((n ^ (n >> 13)) * 1274126177) & 0x7fffffff
	return float((n ^ (n >> 16)) & 0xffff) / 65535.0


func _build() -> void:
	for child in [_flames, _motes, _lamp, _glow]:
		if child:
			child.queue_free()
	_lamp = null
	_glow = null
	_shaders()

	_flame_material = ShaderMaterial.new()
	_flame_material.shader = _flame_shader
	var card := QuadMesh.new()
	card.material = _flame_material
	_flames = MultiMeshInstance3D.new()
	_flames.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var mesh := MultiMesh.new()
	mesh.transform_format = MultiMesh.TRANSFORM_3D
	mesh.use_custom_data = true
	mesh.mesh = card
	var count := tongues
	if count <= 0:
		# (a candle is a few licks; a bonfire a great many)
		count = clampi(roundi(5.0 + sqrt(size) * 34.0 * (0.4 + spread)), 5, 72)
	mesh.instance_count = count
	var random := RandomNumberGenerator.new()
	random.seed = hash(get_path()) if is_inside_tree() else 1
	# (every lick is at the foot of the fire; the shader spreads them over it)
	var foot := Basis.from_scale(Vector3(maxf(size * spread, 0.001), size, 1.0))
	for i in count:
		mesh.set_instance_transform(i, Transform3D(foot, Vector3.ZERO))
		mesh.set_instance_custom_data(i, Color((i + random.randf()) / count, 1.0, 0.0, 0.0))
	_flames.multimesh = mesh
	_flames.extra_cull_margin = size * (2.0 + streams)
	add_child(_flames)

	_mote_material = ShaderMaterial.new()
	_mote_material.shader = _mote_shader
	var disc := QuadMesh.new()
	disc.material = _mote_material
	_motes = MultiMeshInstance3D.new()
	_motes.top_level = true
	_motes.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_motes.extra_cull_margin = 16384.0
	_motes.multimesh = MultiMesh.new()
	_motes.multimesh.transform_format = MultiMesh.TRANSFORM_3D
	_motes.multimesh.use_custom_data = true
	_motes.multimesh.mesh = disc
	_motes.multimesh.instance_count = MOTES
	_at.resize(MOTES)
	_going.resize(MOTES)
	_big.resize(MOTES)
	_age.resize(MOTES)
	_life.resize(MOTES)
	_seed.resize(MOTES)
	_kind.resize(MOTES)
	_age.fill(1.0)
	for i in MOTES:
		_motes.multimesh.set_instance_transform(i, Transform3D(Basis.from_scale(Vector3.ZERO), Vector3.ZERO))
	add_child(_motes)
	_motes.global_transform = Transform3D.IDENTITY

	if glow > 0.0:
		_glow_material = ShaderMaterial.new()
		_glow_material.shader = _glow_shader
		var round_card := QuadMesh.new()
		round_card.size = Vector2(2.0, 2.0)
		round_card.material = _glow_material
		_glow = MeshInstance3D.new()
		_glow.mesh = round_card
		_glow.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		_glow.extra_cull_margin = size * glow_reach * 2.0
		_glow.position = Vector3(0.0, size * 0.45, 0.0)
		add_child(_glow)

	if light:
		_lamp = OmniLight3D.new()
		_lamp.omni_attenuation = 1.3
		add_child(_lamp)
	_dress()


## Passes the settings on to what is drawn.
func _dress() -> void:
	if _flame_material == null:
		return
	for setting: StringName in [&"core", &"body", &"tip", &"intensity", &"lean", &"ragged"]:
		_flame_material.set_shader_parameter(setting, get(setting))
	_mote_material.set_shader_parameter(&"spark", body)
	_mote_material.set_shader_parameter(&"hot", core)
	_mote_material.set_shader_parameter(&"intensity", intensity)
	if _glow_material:
		_glow_material.set_shader_parameter(&"colour", body.lerp(tip, 0.25))
	if _lamp:
		# (the colour of the body of the flame, a little towards its core)
		_lamp.light_color = body.lerp(core, 0.3)
		_reach_now = light_range if light_range > 0.0 else 4.0 + 10.0 * sqrt(size)
		_lamp.omni_range = _reach_now
		_lamp.shadow_enabled = light_shadows
		_lamp.position = Vector3(0.0, size * 0.55, 0.0) + light_offset


func _move_motes(delta: float) -> void:
	var foot := size * spread
	var top := global_position + global_basis.y * size * 0.55
	if embers and size >= 0.15:
		_spark_due -= delta
		if _spark_due <= 0.0:
			# (a torch sends up five or six a second; a bonfire a stream of them)
			_spark_due = randf_range(0.3, 1.7) * 0.09 / (sqrt(size) * maxf(sparks, 0.05))
			var out := Vector3(randf_range(-1.0, 1.0), 0.0, randf_range(-1.0, 1.0))
			_emit(top + out * foot * 0.35 + Vector3.UP * randf_range(-0.3, 0.3) * size, out * 0.3 * sqrt(size) + Vector3.UP * randf_range(0.9, 2.6) * sqrt(size),
					randf_range(0.03, 0.06) * (0.6 + 0.7 * sqrt(size)), randf_range(0.6, 1.8), 0.0)
		# Now and then it spits: a handful of embers thrown out, that fall.
		if spits > 0.0:
			_spit_due -= delta
			if _spit_due <= 0.0:
				_spit_due = randf_range(0.4, 1.6) / (spits * maxf(size, 0.2))
				for i in randi_range(3, 7):
					var way := Vector3(randf_range(-1.0, 1.0), randf_range(0.6, 1.8), randf_range(-1.0, 1.0)).normalized()
					_emit(global_position + global_basis.y * size * randf_range(0.15, 0.5), way * randf_range(1.4, 3.4) * sqrt(size),
							randf_range(0.035, 0.07) * (0.6 + 0.7 * sqrt(size)), randf_range(0.5, 1.1), 2.0)
	if smoke and size >= 0.15:
		_smoke_due -= delta
		if _smoke_due <= 0.0:
			_smoke_due = randf_range(0.35, 0.6)
			var out := Vector3(randf_range(-1.0, 1.0), 0.0, randf_range(-1.0, 1.0))
			_emit(global_position + global_basis.y * size * 0.95 + out * foot * 0.15, out * 0.08 + Vector3.UP * randf_range(0.5, 0.8) * sqrt(size),
					randf_range(0.5, 0.8) * size * maxf(spread, 0.5), randf_range(1.6, 2.4), 1.0)
	var mesh := _motes.multimesh
	for i in MOTES:
		if _age[i] >= 1.0:
			continue
		_age[i] = minf(_age[i] + delta / _life[i], 1.0)
		if _age[i] >= 1.0:
			mesh.set_instance_transform(i, Transform3D(Basis.from_scale(Vector3.ZERO), _at[i]))
			continue
		var age := _age[i]
		var grown := _big[i]
		if _kind[i] < 0.5:
			# A spark is carried up in the hot air, jinking about as it goes, and slows.
			var jink := Vector3(sin(_time * 11.0 + _seed[i] * 40.0) + sin(_time * 4.3 + _seed[i] * 71.0), 0.3 * sin(_time * 9.0 + _seed[i] * 13.0), cos(_time * 9.5 + _seed[i] * 23.0) + cos(_time * 3.7 + _seed[i] * 57.0))
			_going[i] += jink * delta * 1.7 * sqrt(size)
			_going[i].x += lean * delta * 1.5
			_going[i] *= exp(-0.8 * delta)
		elif _kind[i] > 1.5:
			# An ember that was spat out falls.
			_going[i].y -= 6.5 * delta
			_going[i] *= exp(-0.6 * delta)
		else:
			# Smoke swells as it goes up, and drifts off the way the fire leans.
			_going[i].x += lean * delta * 0.6
			grown *= 0.45 + 0.9 * age
		_at[i] += _going[i] * delta
		mesh.set_instance_transform(i, Transform3D(Basis.from_scale(Vector3.ONE * grown), _at[i]))
		mesh.set_instance_custom_data(i, Color(age, _seed[i], _kind[i], 0.0))


func _emit(at: Vector3, going: Vector3, big: float, life: float, kind: float) -> void:
	var i := _next
	_next = (_next + 1) % MOTES
	_at[i] = at
	_going[i] = going
	_big[i] = big
	_age[i] = 0.0
	_life[i] = life
	_seed[i] = randf()
	_kind[i] = kind


# --- Settings ---

func _rebuild() -> void:
	if is_inside_tree():
		_build()

func _set_size(value: float) -> void:
	size = value
	_rebuild()

func _set_spread(value: float) -> void:
	spread = value
	_rebuild()

func _set_tongues(value: int) -> void:
	tongues = value
	_rebuild()

func _set_light(value: bool) -> void:
	light = value
	_rebuild()

func _set_core(value: Color) -> void:
	core = value
	_dress()

func _set_body(value: Color) -> void:
	body = value
	_dress()

func _set_tip(value: Color) -> void:
	tip = value
	_dress()

func _set_intensity(value: float) -> void:
	intensity = value
	_dress()

func _set_speed(value: float) -> void:
	speed = value

func _set_ragged(value: float) -> void:
	ragged = value
	_dress()

func _set_lean(value: float) -> void:
	lean = value
	_dress()

func _set_light_range(value: float) -> void:
	light_range = value
	_dress()

func _set_light_shadows(value: bool) -> void:
	light_shadows = value
	_dress()

func _set_light_offset(value: Vector3) -> void:
	light_offset = value
	_dress()
