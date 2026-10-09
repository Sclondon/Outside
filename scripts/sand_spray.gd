class_name SandSpray
extends MultiMeshInstance3D
## Loose sand on the move, all of it drawn at once as one MultiMesh:
##
## - `kick`: a spray of grains thrown up from a point, as a foot throws it:
##   each little card is a handful of grains, flung out, falling back and
##   lying a moment where it lands.
## - `ring`: the same, thrown out all round, for a landing.
## - `run`: a sheet of sand sliding down a slope: a tongue of streaming grains
##   that lies on the ground, runs downhill, widens, slows and fades.
##
## Nothing is moved from here. Each card is given where it starts, how fast,
## and when; the shader works out where it has got to. All this does each
## frame is tell it the time. `SandGround` keeps one and uses it for feet,
## slides and whatever is thrown; add another anywhere and call it yourself.

const COUNT := 448
const FALL := 11.0

const SHADER := """
shader_type spatial;
render_mode world_vertex_coords, blend_mix, depth_draw_never, cull_disabled, shadows_disabled, unshaded;

uniform float clock = 0.0;
uniform float fall = 11.0;
uniform vec3 glint : source_color = vec3(1.0, 0.95, 0.82);
// The wind over the ground (x, z) and how hard: it carries off what is thrown up.
uniform vec3 wind = vec3(1.0, 0.0, 0.0);
// The light on it: it is lit as much from one side as another (it is loose
// grains, not a card), so this is worked out once for all of it, from the
// sun and the sky, and not by the renderer: the two renderers would differ.
uniform vec3 shine = vec3(1.0);

varying vec2 where;
varying float sheet;
varying float seed;
varying float fade;
varying vec3 span;
varying vec3 tint;

float hash2(vec2 p) {
	vec3 q = fract(vec3(p.xyx) * 0.1031);
	q += dot(q, q.yzx + 33.33);
	return fract((q.x + q.y) * q.z);
}

float patches(vec2 p) {
	vec2 whole = floor(p);
	vec2 part = fract(p);
	part = part * part * (3.0 - 2.0 * part);
	return mix(mix(hash2(whole), hash2(whole + vec2(1.0, 0.0)), part.x),
			mix(hash2(whole + vec2(0.0, 1.0)), hash2(whole + vec2(1.0, 1.0)), part.x), part.y);
}

void vertex() {
	vec3 start = MODEL_MATRIX[3].xyz;
	vec3 speed = MODEL_MATRIX[0].xyz;
	float size = MODEL_MATRIX[1].x;
	float life = MODEL_MATRIX[1].y;
	float age = clock - MODEL_MATRIX[1].z;
	vec3 other = MODEL_MATRIX[2].xyz;
	// (its colour comes with it here, not as a colour: the two renderers read those differently)
	sheet = step(1.5, INSTANCE_CUSTOM.x);
	seed = fract(INSTANCE_CUSTOM.x * 0.5) * 2.0;
	tint = INSTANCE_CUSTOM.yzw;
	where = UV;
	float shown = step(0.0, age) * step(age, life);
	float through = clamp(age / life, 0.0, 1.0);
	vec2 corner = UV - 0.5;
	if (sheet > 0.5) {
		// A sheet: it lies on the slope (`other` is which way the slope
		// faces), runs down it and slows; it is narrow at first and spreads.
		float pace = length(speed);
		vec3 downhill = speed / max(pace, 0.0001);
		vec3 sideways = normalize(cross(other, downhill));
		float gone = pace * life * (1.0 - (1.0 - through) * (1.0 - through)) * 0.5;
		float wide = length(other) * (0.45 + 1.5 * through);
		other = normalize(other);
		float long = size * (0.5 + 1.3 * through);
		span = vec3(wide, long, gone);
		VERTEX = start + other * 0.02 + (downhill * (gone - corner.y * long) + sideways * corner.x * wide) * shown;
		fade = smoothstep(0.0, 0.12, through) * (1.0 - smoothstep(0.45, 1.0, through));
		NORMAL = other;
	} else {
		// A handful of grains: thrown, slowed by the air, pulled down, and
		// left lying where it comes back to the height it left from.
		float lands = max(2.0 * speed.y / fall, 0.02);
		float flown = min(age, lands);
		vec3 middle = start + speed * flown / (1.0 + 0.5 * flown);
		middle.xz += wind.xy * wind.z * 5.0 * flown * flown;
		float grown = size * (0.45 + other.x * through);
		// (the card stands on the ground, not half in it)
		middle.y = start.y + max(speed.y * flown - 0.5 * fall * flown * flown, 0.0) + 0.01 + grown * 0.42;
		vec3 side = INV_VIEW_MATRIX[0].xyz;
		vec3 tall = INV_VIEW_MATRIX[1].xyz;
		VERTEX = middle + (side * corner.x - tall * corner.y) * grown * shown;
		fade = 1.0 - smoothstep(0.55, 1.0, through);
		span = vec3(grown, grown, age);
		NORMAL = INV_VIEW_MATRIX[2].xyz;
	}
}

void fragment() {
	vec3 colour = tint;
	float alpha;
	if (sheet > 0.5) {
		// A tongue: round at its head, drawn out to nothing behind, and made
		// of threads of grains that stream down it faster than it moves.
		vec2 on = vec2((where.x - 0.5) * 2.0, where.y);
		float head = sqrt(max(1.0 - pow(1.0 - min(on.y / 0.3, 1.0), 2.0), 0.0));
		float half_wide = max(head * (1.0 - 0.75 * smoothstep(0.3, 1.0, on.y)), 0.04);
		float outline = (1.0 - smoothstep(0.45, 1.0, abs(on.x) / half_wide)) * (1.0 - smoothstep(0.65, 1.0, on.y));
		vec2 lie = vec2(where.x * span.x, where.y * span.y + span.z * 1.7);
		float threads = patches(vec2(lie.x * 34.0 + seed * 50.0, lie.y * 5.0));
		float grains = patches(vec2(lie.x * 90.0, lie.y * 22.0 + seed * 9.0));
		alpha = outline * fade * (0.25 + 0.75 * smoothstep(0.3, 0.75, threads * 0.6 + grains * 0.4));
		colour *= 0.9 + 0.3 * grains;
	} else {
		// Grains scattered over the card, thicker in the middle, in a faint haze of finer ones.
		vec2 square = where * 5.0;
		vec2 which = floor(square);
		float chance = hash2(which + seed * 57.0);
		vec2 off = fract(square) - 0.5 - (vec2(hash2(which + seed * 13.0 + 1.3), hash2(which - seed * 31.0 + 7.1)) - 0.5) * 0.6;
		float out_from = length(where * 2.0 - 1.0);
		float speck = (1.0 - smoothstep(0.13, 0.3, length(off))) * step(0.3 + 0.5 * out_from, chance);
		float cloud = (1.0 - smoothstep(0.2, 1.0, out_from));
		float haze = cloud * cloud * 0.45;
		alpha = (speck * 0.95 + haze * (1.0 - speck)) * fade * (1.0 - smoothstep(0.85, 1.0, out_from));
		// (the grains are seen dark against the dust they are thrown up in)
		colour = mix(mix(colour, vec3(1.0), 0.22), colour * (0.58 + 0.3 * chance), speck);
		// Now and then one catches the light.
		float flash = step(0.9, hash2(which + floor(span.z * 14.0 + seed * 7.0))) * speck;
		colour = mix(colour, glint * 1.6, flash);
	}
	ALBEDO = colour * shine;
	ALPHA = alpha;
}
"""

static var _shader: Shader

var _material: ShaderMaterial
var _clock := 0.0
var _next := 0
## How many cards are spent of each kick, as a share: turned down with `Sand.quality`.
var thrift := 1.0
var _look := 0.0


func _ready() -> void:
	top_level = true
	global_transform = Transform3D.IDENTITY
	cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	# (they are wherever the sand was last kicked)
	custom_aabb = AABB(Vector3.ONE * -8000.0, Vector3.ONE * 16000.0)
	if _shader == null:
		_shader = Shader.new()
		_shader.code = SHADER
	_material = ShaderMaterial.new()
	_material.shader = _shader
	_material.set_shader_parameter(&"fall", FALL)
	var card := QuadMesh.new()
	card.size = Vector2.ONE
	card.material = _material
	multimesh = MultiMesh.new()
	multimesh.transform_format = MultiMesh.TRANSFORM_3D
	multimesh.use_custom_data = true
	multimesh.mesh = card
	multimesh.instance_count = COUNT
	for i in COUNT:
		# (born long ago: not shown)
		multimesh.set_instance_transform(i, Transform3D(Basis(Vector3.ZERO, Vector3(0.0, 1.0, -1000.0), Vector3.ZERO), Vector3.ZERO))
		multimesh.set_instance_custom_data(i, Color(0.0, 0.0, 0.0, 0.0))


func _process(delta: float) -> void:
	_clock += delta
	_look -= delta
	if _look <= 0.0:
		_look = 1.0
		_find_light()
	_material.set_shader_parameter(&"clock", _clock)
	_material.set_shader_parameter(&"wind", Vector3(Sand.wind_way.x, Sand.wind_way.y, Sand.wind_force))


## Throws `count` handfuls of grains from `at` (a point on the ground) at
## about `velocity`, each a little differently: `spread` is how far, as a
## share of the speed. `size` is how big a handful gets across, metres.
func kick(at: Vector3, velocity: Vector3, count: int, spread := 0.5, colour := Sand.COLOUR, size := 0.16, delay := 0.0) -> void:
	count = maxi(int(round(count * thrift)), 1)
	var pace := velocity.length()
	for k in count:
		var stray := Vector3(randf_range(-1.0, 1.0), randf_range(-0.5, 1.0), randf_range(-1.0, 1.0)) * spread * pace
		var speed := velocity * randf_range(0.55, 1.15) + stray
		speed.y = maxf(speed.y, 0.25)
		var life := 2.0 * speed.y / FALL + randf_range(0.25, 0.5)
		_put(at + Vector3(randf_range(-0.04, 0.04), 0.0, randf_range(-0.04, 0.04)), speed,
				Vector3(size * randf_range(0.7, 1.25), life, _clock + delay + randf_range(0.0, 0.05)), Vector3(randf_range(1.2, 2.2), 0.0, 0.0), 0.0, 0.0, colour)


## Throws grains out all round `at`, low and fast: what a landing raises.
func ring(at: Vector3, speed: float, count: int, colour := Sand.COLOUR, size := 0.2) -> void:
	count = maxi(int(round(count * thrift)), 3)
	var turn := randf() * TAU
	for k in count:
		var angle := turn + TAU * (k + randf_range(-0.3, 0.3)) / count
		var out := Vector3(cos(angle), 0.0, sin(angle))
		var each := speed * randf_range(0.6, 1.1)
		var up := each * randf_range(0.35, 0.8)
		_put(at + out * 0.08, out * each + Vector3.UP * up,
				Vector3(size * randf_range(0.7, 1.3), 2.0 * up / FALL + randf_range(0.3, 0.55), _clock + randf_range(0.0, 0.04)), Vector3(randf_range(1.4, 2.4), 0.0, 0.0), 0.0, 0.0, colour)


## Sets a sheet of sand running from `at` down a slope that faces `normal`:
## `downhill` is the way it runs, `length` how long a tongue it is, `width`
## how wide it starts (it ends about twice that), `speed` how fast it sets
## off, metres a second, and `life` how long it lasts. `delay` holds it back:
## for the sand that goes on trickling after whatever started it has passed.
func run(at: Vector3, downhill: Vector3, normal: Vector3, length: float, width: float, speed: float, life: float, colour := Sand.COLOUR, delay := 0.0) -> void:
	_put(at, downhill.normalized() * speed, Vector3(length, life, _clock + delay), normal, 1.0, width, colour)


func _put(at: Vector3, speed: Vector3, how: Vector3, other: Vector3, sheet: float, wide: float, colour: Color) -> void:
	var i := _next
	_next = (_next + 1) % COUNT
	multimesh.set_instance_transform(i, Transform3D(Basis(speed, how, other), at))
	if sheet > 0.5:
		other = other.normalized() * wide
	multimesh.set_instance_custom_data(i, Color(randf() * 0.98 + sheet * 2.0, colour.r, colour.g, colour.b))


# How bright sand in the open is here: the sun's light, as much of it as falls
# on a heap of loose grains, and the sky's.
func _find_light() -> void:
	var top := get_tree().current_scene if get_tree().current_scene else get_tree().root
	var shine := Color(0.0, 0.0, 0.0)
	for sun: DirectionalLight3D in top.find_children("*", "DirectionalLight3D", true, false):
		if sun.visible:
			shine += sun.light_color.srgb_to_linear() * sun.light_energy * Sand.sun_gain * 0.62
			break
	var sky := Color(0.5, 0.5, 0.5)
	for world: WorldEnvironment in top.find_children("*", "WorldEnvironment", true, false):
		if world.environment and world.environment.ambient_light_source == Environment.AMBIENT_SOURCE_COLOR:
			sky = world.environment.ambient_light_color.srgb_to_linear() * world.environment.ambient_light_energy
		break
	shine += sky
	# (the web's renderer draws lit things brighter than this sum: found by eye)
	if RenderingServer.get_current_rendering_method() == "gl_compatibility":
		shine *= 1.4
	_material.set_shader_parameter(&"shine", Vector3(shine.r, shine.g, shine.b))
