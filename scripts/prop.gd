class_name Prop
extends Node3D
## A prop: one of the scenes in `props/`, each a model from `models/props/`
## (built by `tools/build_props.py`) with its collision. This script is on the
## root of every one. It reshades the model so that it is lit as the rest of
## the world is, banded or smooth as the menu says, and draws the plants with
## their own shader, which paints them and moves them in the wind. See PROPS.md.

## How far off it is still drawn, in metres (0: always). Small things have one,
## so that a wide level does not draw every pot in it.
@export var draw_distance := 0.0
## Whether it casts a shadow. The smallest things do not: each shadow is one more
## thing to draw.
@export var casts_shadow := true

## Plants: palms, reeds, shrubs and grass, trunk and leaf alike. One material
## draws every plant in a level. What differs is carried by the points of the
## mesh, as `tools/build_props.py` says under "plants":
##
## - the colour of a point, and in its alpha how much it is leaf;
## - the first texture coordinate: from the root of a leaf to its tip, and
##   across it (0.5 on the midrib, 0 and 1 at the tips of the leaflets);
## - the second: how far the point is along its part from where that is
##   rooted, in metres, and a number that part has to itself;
## - a normal that leans out from the heart of the crown, so that a crown is
##   lit as one round mass.
##
## What it does with them:
##
## - Paint. A leaf is darker and cooler at its root and paler and warmer at
##   its tip, in three flat tones with edges like brush strokes rather than a
##   smooth fade, and has a pale midrib. Each plant is a little greener or
##   yellower than its neighbour.
## - Light, in two tones with a hard edge when the world is banded and smoothly
##   when it is not; a rim of light round the lit side of a crown; and the sun
##   through the leaves: seen against the sun, or from underneath, a leaf is
##   not dark but lit yellow-green from behind.
## - Wind (`wind`, which `Breeze` below keeps to the level's own). A trunk
##   leans with it by its height; each leaf bends from its root, further the
##   further along it is; gusts come through on the wind, so that the near side
##   of a crown gives before the far side does; each leaf nods in its own time
##   besides; and the tips of the leaflets flutter.
const PLANT_SHADER := """
shader_type spatial;
render_mode cull_disabled, world_vertex_coords;

uniform float banded = 0.0;
// The wind: which way it blows over the ground (x, z), how hard (0..1), and
// how far it has carried things, in metres.
uniform vec4 wind = vec4(1.0, 0.0, 0.2, 0.0);
// How far things move in it (1: as made).
uniform float sway = 1.0;
uniform float flutter = 1.0;
// What a colour is multiplied by at the root of a leaf, and at its tip.
uniform vec3 root_tone = vec3(0.44, 0.58, 0.7);
uniform vec3 tip_tone = vec3(1.2, 1.17, 0.84);
uniform float wrap = 0.45;
// The sun through a leaf: how strong, and what colour it comes out.
uniform float through = 0.75;
uniform vec3 through_tone = vec3(1.25, 1.2, 0.35);
// How much of the sky's light reaches the underside of a crown.
uniform float under = 0.5;
uniform float rim = 0.3;
uniform float rim_width = 0.3;

varying vec3 lit_by;
varying float differs;
varying float leafy;

void vertex() {
	vec3 foot = MODEL_MATRIX[3].xyz;
	float size = length(MODEL_MATRIX[1].xyz);
	float reach = UV2.x * size;
	float own = UV2.y * TAU;
	float tip = abs(UV.y - 0.5) * 2.0 * COLOR.a;
	vec3 way = vec3(wind.x, 0.0, wind.y);
	vec3 across = vec3(-wind.y, 0.0, wind.x);
	// Gusts: a long swell and a shorter one inside it, going by on the wind.
	float along = dot(VERTEX, way) - wind.w;
	float gust = 0.5 + 0.5 * sin(along * 0.11 + 2.0 * sin(along * 0.031));
	float ripple = sin(along * 0.5 + own);
	float force = wind.z * (0.35 + 1.1 * gust);
	// The whole plant leans by its height.
	float high = max(VERTEX.y - foot.y, 0.0) / size;
	float lean = high * high * (0.0032 * force + 0.0006 * wind.z * ripple) * size;
	// Each part bends from its root, and nods in its own time.
	float bend = min(reach * reach * (0.045 * force + 0.012 * wind.z * ripple), reach * 0.7);
	vec3 push = way * (lean + bend);
	push.y -= 0.5 * bend * bend / max(reach, 0.3);
	float nod = sin(TIME * (0.9 + 0.7 * fract(UV2.y * 7.0)) + own);
	push.y += nod * reach * reach * 0.004 * (0.5 + 2.0 * wind.z);
	push += across * nod * reach * reach * 0.002 * (0.5 + 2.0 * wind.z);
	// The tips of the leaflets shake.
	float quick = TIME * (4.0 + 7.0 * wind.z) + own * 3.0 + UV.x * 13.0 + UV.y * 5.0;
	push += (across * sin(quick) + vec3(0.0, 1.0, 0.0) * cos(quick * 1.3)) * tip * smoothstep(0.0, 1.0, reach)
			* (0.006 + 0.05 * force) * size * flutter;
	VERTEX += push * sway;
	lit_by = NORMAL;
	differs = fract(foot.x * 0.173 + foot.z * 0.117);
}

void fragment() {
	leafy = COLOR.a;
	float edge = abs(UV.y - 0.5) * 2.0;
	// How far from root to tip: along the leaf, and out along its leaflets.
	float far = mix(UV.x, UV.x * 0.72 + edge * 0.38, leafy);
	// (the edge between two tones wanders, as a brush does)
	float wander = 0.035 * sin(UV.y * 17.0 + UV.x * 9.0);
	float soft = mix(0.07, max(fwidth(far), 0.002), banded);
	float low = smoothstep(0.3 - soft, 0.3 + soft, far + wander);
	float top = smoothstep(0.74 - soft, 0.74 + soft, far - wander);
	vec3 colour = COLOR.rgb;
#if CURRENT_RENDERER == RENDERER_COMPATIBILITY
	// (the web's renderer takes what a shader gives as a colour to be as the screen has
	// it, where the others take it to be as light: the mesh's colours are as light)
	colour = pow(colour, vec3(1.0 / 2.2));
#endif
	colour *= mix(vec3(0.94, 1.03, 0.92), vec3(1.07, 1.0, 0.86), differs);
	colour *= mix(root_tone, vec3(1.0), low);
	colour *= mix(vec3(1.0), tip_tone, top);
	float rib = (1.0 - smoothstep(0.03, 0.1, edge)) * leafy;
	colour = mix(colour, colour * vec3(1.4, 1.35, 1.0) + 0.02, rib * 0.55);
	ALBEDO = colour;
	ROUGHNESS = 1.0;
	SPECULAR = 0.0;
	// (the same from both sides: it is the crown's roundness, not the leaf's)
	vec3 turned = normalize(lit_by);
	NORMAL = normalize((VIEW_MATRIX * vec4(turned, 0.0)).xyz);
	// What is turned to the ground gets less of the sky's light.
	AO = mix(under, 1.0, smoothstep(-0.7, 0.5, turned.y));
}

float cut(float value, float edge) {
	float pixel = max(fwidth(value), 0.0005);
	return smoothstep(edge - pixel, edge + pixel, value);
}

void light() {
	float reach = clamp(ATTENUATION, 0.0, 1.0);
	float turned = dot(NORMAL, LIGHT);
	float facing = (turned + wrap) / (1.0 + wrap);
	float hard = cut(facing * smoothstep(0.15, 0.6, reach), 0.04) * reach;
	float lit = mix(clamp(facing, 0.0, 1.0) * reach, hard, banded);
	DIFFUSE_LIGHT += lit * LIGHT_COLOR / PI;
	// The sun through the leaves: looking towards it, and on the side turned from it.
	float against = max(dot(-VIEW, LIGHT), 0.0);
	float shone = max(against * against * against, 0.45 * clamp(0.3 - turned, 0.0, 1.0));
	shone = mix(shone, 0.55 * cut(shone, 0.12) + 0.45 * cut(shone, 0.5), banded);
	float edge = 1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0);
	float lip = mix(smoothstep(1.0 - rim_width * 1.6, 1.0, edge), cut(edge, 1.0 - rim_width), banded) * lit;
	SPECULAR_LIGHT += ALBEDO * (through_tone * shone * through * leafy * (0.4 + 0.6 * reach) * (1.0 - lit) + lip * rim) * LIGHT_COLOR / PI;
}
"""

## A breeze for a level that has no `SandWind`: the way it blows and how hard.
const BREEZE_WAY := Vector2(0.8, 0.6)
const BREEZE_FORCE := 0.22

# One material for each colour, shared by every prop that uses it.
static var _made := {}
static var _plant_shader: Shader
# The plants' materials, which are told of the wind, and what tells them.
static var _plants: Array[ShaderMaterial] = []
static var _breeze: Breeze


func _ready() -> void:
	var model := get_node_or_null(^"Model")
	if model:
		dress(model, draw_distance, casts_shadow)
	if not _plants.is_empty() and not is_instance_valid(_breeze):
		_breeze = Breeze.new()
		_breeze.name = "PlantBreeze"
		get_tree().root.add_child.call_deferred(_breeze)


## Reshades every mesh under `model` by the colours it was made in.
static func dress(model: Node, far := 0.0, shadow := true) -> void:
	for part: MeshInstance3D in model.find_children("*", "MeshInstance3D", true, false):
		if part.mesh == null:
			continue
		for surface in part.mesh.get_surface_count():
			var original := part.mesh.surface_get_material(surface) as StandardMaterial3D
			if original:
				part.set_surface_override_material(surface, material(original.resource_name, original.albedo_color))
		if not shadow:
			part.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		if far > 0.0:
			part.visibility_range_end = far
			part.visibility_range_end_margin = far * 0.1


## The material for a colour. `label` is the name the model gave it: those
## beginning `plant` are plants, whose colours are in their meshes.
static func material(label: String, colour: Color) -> Material:
	var key := "%s %s %s" % [label, colour.to_html(), Settings.world_banded]
	if _made.has(key):
		return _made[key]
	var made: Material
	if label.begins_with("plant"):
		if _plant_shader == null:
			_plant_shader = Shader.new()
			_plant_shader.code = PLANT_SHADER
		var plant := ShaderMaterial.new()
		plant.shader = _plant_shader
		plant.set_shader_parameter(&"banded", 1.0 if Settings.world_banded else 0.0)
		_plants.append(plant)
		made = plant
	else:
		made = Toon.surface(colour)
	_made[key] = made
	return made


## Tells the plants of the wind, each frame: the level's own, if it has a
## `SandWind` (which says what it is doing through `Sand.blow`), and a light
## breeze if it has not. There is one, under the root, made by the first prop
## that is a plant.
class Breeze extends Node:
	var _travel := 0.0
	var _heard := 0.0
	var _blown := 0.0

	func _process(delta: float) -> void:
		# (a wind that is blowing carries things further every frame)
		if Sand.wind_travel != _heard:
			_heard = Sand.wind_travel
			_blown = 0.5
		_blown -= delta
		var way := Prop.BREEZE_WAY.normalized()
		var force := Prop.BREEZE_FORCE
		if _blown > 0.0:
			way = Sand.wind_way
			# (the air is never quite still)
			force = maxf(Sand.wind_force, 0.04)
		_travel += (1.5 + 9.0 * force) * delta
		var value := Vector4(way.x, way.y, force, _travel)
		for plant: ShaderMaterial in Prop._plants:
			plant.set_shader_parameter(&"wind", value)
