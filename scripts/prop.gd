class_name Prop
extends Node3D
## A prop: one of the scenes in `props/`, each a model from `models/props/`
## (built by `tools/build_props.py`) with its collision. This script is on the
## root of every one. It reshades the model so that it is lit as the rest of
## the world is, banded or smooth as the menu says, and makes the palms' leaves
## sway. See PROPS.md.

## How far off it is still drawn, in metres (0: always). Small things have one,
## so that a wide level does not draw every pot in it.
@export var draw_distance := 0.0
## Whether it casts a shadow. The smallest things do not: each shadow is one more
## thing to draw.
@export var casts_shadow := true

## Leaves: lit like `Toon.surface`, from both sides, and swaying. A leaf's
## first texture coordinate runs from its stem (0) to its tip (1).
const FROND_SHADER := """
shader_type spatial;
render_mode cull_disabled;

uniform vec3 albedo : source_color = vec3(0.32, 0.46, 0.21);
uniform float banded = 0.0;
uniform float wrap = 0.35;
// How far the tip of a leaf moves, in metres, and how fast.
uniform float sway = 0.14;
uniform float sway_speed = 1.3;

void vertex() {
	float reach = UV.x * UV.x;
	vec3 place = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	float phase = TIME * sway_speed + place.x * 0.31 + place.z * 0.27;
	VERTEX.y += sin(phase) * reach * sway;
	VERTEX.x += sin(phase * 0.7 + 1.3) * reach * sway * 0.6;
}

void fragment() {
	ALBEDO = albedo * (0.8 + 0.3 * UV.x);
	ROUGHNESS = 1.0;
	SPECULAR = 0.0;
}

float cut(float value, float edge) {
	float pixel = max(fwidth(value), 0.0005);
	return smoothstep(edge - pixel, edge + pixel, value);
}

void light() {
	float reach = clamp(ATTENUATION, 0.0, 1.0);
	float facing = (dot(NORMAL, LIGHT) + wrap) / (1.0 + wrap);
	float hard = cut(facing * smoothstep(0.15, 0.6, reach), 0.04) * reach;
	float smooth_lit = clamp(facing, 0.0, 1.0) * reach;
	DIFFUSE_LIGHT += mix(smooth_lit, hard, banded) * LIGHT_COLOR / PI;
}
"""

# One material for each colour, shared by every prop that uses it.
static var _made := {}
static var _frond_shader: Shader


func _ready() -> void:
	var model := get_node_or_null(^"Model")
	if model:
		dress(model, draw_distance, casts_shadow)


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
## beginning `frond` are leaves.
static func material(label: String, colour: Color) -> Material:
	var key := "%s %s %s" % [label, colour.to_html(), Settings.world_banded]
	if _made.has(key):
		return _made[key]
	var made: Material
	if label.begins_with("frond"):
		if _frond_shader == null:
			_frond_shader = Shader.new()
			_frond_shader.code = FROND_SHADER
		var leaf := ShaderMaterial.new()
		leaf.shader = _frond_shader
		leaf.set_shader_parameter(&"albedo", colour)
		leaf.set_shader_parameter(&"banded", 1.0 if Settings.world_banded else 0.0)
		made = leaf
	else:
		made = Toon.surface(colour)
	_made[key] = made
	return made
