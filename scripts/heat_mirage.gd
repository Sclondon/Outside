class_name HeatMirage
extends MeshInstance3D
## Heat over the desert. Add one to a level and set `strength` (0: none).
##
## - Shimmer: whatever is seen through a long stretch of hot air swims. Hot air
##   lies low, so it is what is far off and near the level of the eye that
##   does: the foot of a far dune or pyramid, the line where the sand meets the
##   sky. Nothing near the camera moves, nor what stands in front of the
##   distance, and what is in shadow far off swims less than what is in the sun.
## - The mirage: far ground just below the level of the eye shows what is above
##   it upside down, tinted with the sky: pools of what looks like water lying
##   on the sand, which are not there when he gets to them.
##
## It is strongest with the sun high, and less in a wind, which stirs the air
## (`wind`, if the level has a `SandWind`). Under a roof it is gone: `subject`
## is whoever has to be out of doors to see it (the player; with none, the
## camera).
##
## How: one strip of the screen, drawn after everything solid, which reads the
## picture so far (and how far off each point of it is) and puts it back a
## little out of place. The strip is only as high as the part of the screen
## within `BAND` degrees of the level of the eye, and there is none at all when
## the camera looks well up or down, as the level editor's does. What it costs
## is a copy of the screen once a frame (which water does not ask for: it reads
## only the depth), and three or four texture reads for each pixel of the
## strip. It does not touch the sky or the fog, which belong to `SandWind`.
## It is the same in the phone's renderer and the web's.

## What a level has when it does not say.
const USUAL := 0.5
## How far above and below the level of the eye the strip reaches, in degrees.
const BAND := 7.0

const SHADER := """
shader_type spatial;
render_mode unshaded, blend_mix, depth_draw_never, depth_test_disabled, cull_disabled, shadows_disabled, fog_disabled, skip_vertex_transform;

uniform sampler2D screen : hint_screen_texture, filter_linear, repeat_disable;
uniform sampler2D depth : hint_depth_texture, filter_nearest, repeat_disable;
// How strong, 0..1, all told; and the time.
uniform float amount = 0.0;
uniform float clock = 0.0;
// The colour the mirage takes from the sky.
uniform vec3 sky : source_color = vec3(0.7, 0.8, 0.9);
// How far off the air begins to swim, and where it does so fully, in metres.
uniform vec2 reach = vec2(30.0, 240.0);
// Half the height of the strip, as the tangent of an angle.
uniform float band = 0.12;

void vertex() {
	// The strip lies along the level of the eye: where a point far ahead, as high as the camera, is on the screen.
	vec3 ahead = -INV_VIEW_MATRIX[2].xyz;
	vec3 level = normalize(vec3(ahead.x, 0.0, ahead.z) + vec3(0.00001, 0.0, 0.0));
	vec4 far_ahead = PROJECTION_MATRIX * (VIEW_MATRIX * vec4(level, 0.0));
	float middle = far_ahead.w > 0.001 ? far_ahead.y / far_ahead.w : 5.0;
	float half_high = band * abs(PROJECTION_MATRIX[1][1]);
	POSITION = vec4(VERTEX.x, clamp(middle + VERTEX.y * half_high, -1.0, 1.0), 0.5, 1.0);
}

// Where in the camera's space the thing drawn at a point of the screen is.
vec3 unproject(vec2 screen_uv, float deep, mat4 inv_projection) {
#if CURRENT_RENDERER == RENDERER_COMPATIBILITY
	vec3 ndc = vec3(screen_uv, deep) * 2.0 - 1.0;
#else
	vec3 ndc = vec3(screen_uv * 2.0 - 1.0, deep);
#endif
	vec4 view = inv_projection * vec4(ndc, 1.0);
	return view.xyz / view.w;
}

void fragment() {
	vec3 seen = unproject(SCREEN_UV, texture(depth, SCREEN_UV).r, INV_PROJECTION_MATRIX);
	float far = length(seen);
	vec3 way = (INV_VIEW_MATRIX * vec4(seen / far, 0.0)).xyz;
	// How far above the level of the eye this is looked at (the sine of the angle), and which way round the compass.
	float up = way.y;
	float round_about = atan(way.x, way.z);
	// Which way on the screen is up in the world, and how far it is to one unit of `up`.
	vec2 slope = vec2(dFdx(up), dFdy(up));
	vec2 upward = slope / max(dot(slope, slope), 0.0000001) / VIEWPORT_SIZE;

	// Hot air: thick where the look is long and low.
	float through = smoothstep(reach.x, reach.y, far);
	float low = 1.0 - smoothstep(0.012, 0.085, abs(up + 0.005));
	float heat = amount * through * low;

	// It rises in ripples, each bending the light a little to one side and up or down.
	vec2 ripple = vec2(round_about * 150.0, up * 420.0 - clock * 1.7);
	float one = sin(ripple.x + clock * 2.1 + 2.0 * sin(ripple.y * 0.9 + clock * 1.3));
	float two = sin(ripple.x * 2.7 - clock * 2.9 + 1.7 * sin(ripple.y * 2.3 - clock * 2.2));
	vec2 shift = vec2((one * 0.6 + two * 0.4) * 0.0012, (two * 0.7 - one * 0.3) * 0.0032) * heat;
	vec2 from = SCREEN_UV + shift;
	// (what stands near, in front of the distance, is not smeared into it)
	float there = length(unproject(from, texture(depth, from).r, INV_PROJECTION_MATRIX));
	if (there < reach.x) {
		from = SCREEN_UV;
	}
	vec3 colour = texture(screen, from).rgb;
	// What is in shadow swims less.
	float bright = dot(colour, vec3(0.3, 0.6, 0.1));
	float sunlit = smoothstep(0.12, 0.4, bright);

	// The mirage: far ground a little below the level of the eye, broken into
	// pools, showing what is as far above that level and further, upside down.
	float under = -up;
	float lying = smoothstep(0.0006, 0.0022, under) * (1.0 - smoothstep(0.009, 0.02, under));
	lying *= smoothstep(90.0, 200.0, far) * (1.0 - smoothstep(1500.0, 2500.0, far));
	float broken = 0.5 + 0.5 * sin(round_about * 37.0 + 1.6 * sin(round_about * 93.0 + clock * 0.21) + clock * 0.13);
	float pool = smoothstep(0.5, 0.6, lying * (0.25 + 0.75 * broken) * (0.65 + 0.35 * amount) + 0.08 * one * lying) * clamp(amount * 2.5, 0.0, 1.0) * sunlit;
	if (pool > 0.001) {
		vec2 above = SCREEN_UV + upward * (0.004 + under * 3.5) + shift * 2.5;
		vec3 mirrored = texture(screen, above).rgb;
		colour = mix(colour, mix(mirrored, sky, 0.4), pool);
	}

	ALBEDO = colour;
	ALPHA = clamp(max(heat * (0.4 + 0.6 * sunlit) * 6.0, pool), 0.0, 1.0);
}
"""

static var _shader: Shader

## How much the distance swims, 0..1. At 0 nothing is drawn.
@export_range(0.0, 1.0) var strength := USUAL
## Whoever has to be out of doors to see it. With none, the camera.
var subject: Node3D
## The level's wind, if it has one: the harder it blows the less the air swims.
var wind: SandWind

## How strong it is this moment, sun, wind and roof all told.
var force := 0.0

var _material: ShaderMaterial
var _clock := 0.0
var _open := 1.0
var _look_in := 0.0
var _sun: DirectionalLight3D
var _looked := false


func _ready() -> void:
	top_level = true
	global_transform = Transform3D.IDENTITY
	cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	custom_aabb = AABB(Vector3.ONE * -8000.0, Vector3.ONE * 16000.0)
	if _shader == null:
		_shader = Shader.new()
		_shader.code = SHADER
	_material = ShaderMaterial.new()
	_material.shader = _shader
	# (before anything else that is seen through: water, dust and blown sand are drawn over it, and do not swim)
	_material.render_priority = -100
	_material.set_shader_parameter(&"band", tan(deg_to_rad(BAND)))
	var strip := QuadMesh.new()
	strip.size = Vector2(2.0, 2.0)
	mesh = strip
	material_override = _material
	visible = false


func _process(delta: float) -> void:
	if not _looked:
		_look_round()
	_clock += delta
	# Under a roof? Looked for a few times a second.
	_look_in -= delta
	if _look_in <= 0.0:
		_look_in = 0.3
		var from := subject if is_instance_valid(subject) else get_viewport().get_camera_3d()
		if from:
			var at := from.global_position + Vector3.UP * 1.2
			var roof := get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(at, at + Vector3.UP * 40.0, 1))
			_open = move_toward(_open, 0.0 if not roof.is_empty() else 1.0, 0.35)
	var sun_high := 1.0
	if is_instance_valid(_sun):
		sun_high = smoothstep(0.05, 0.5, _sun.global_basis.z.y) if _sun.visible else 0.0
	var stirred := 1.0 - 0.6 * wind.force if is_instance_valid(wind) else 1.0
	force = lerpf(force, strength * _open * sun_high * stirred, minf(delta * 2.0, 1.0))
	visible = force > 0.01
	_material.set_shader_parameter(&"amount", force)
	_material.set_shader_parameter(&"clock", _clock)


# Finds the sun and the colour of the sky.
func _look_round() -> void:
	_looked = true
	var top := get_tree().current_scene if get_tree().current_scene else get_tree().root
	for found: DirectionalLight3D in top.find_children("*", "DirectionalLight3D", true, false):
		_sun = found
		break
	for found: WorldEnvironment in top.find_children("*", "WorldEnvironment", true, false):
		if found.environment == null:
			continue
		var above := found.environment.background_color
		if found.environment.sky and found.environment.sky.sky_material is ProceduralSkyMaterial:
			var made := found.environment.sky.sky_material as ProceduralSkyMaterial
			above = made.sky_horizon_color.lerp(made.sky_top_color, 0.45)
		_material.set_shader_parameter(&"sky", above)
		break
