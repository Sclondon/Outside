class_name Toon
## Cel shading, after the usual recipe for the Breath of the Wild look:
##
## - Each light splits a surface into two flat tones, with an optional brighter
##   core. Shadow and distance are folded into the same cut as the angle to the
##   light, so a cast shadow has the same hard edge as the terminator.
## - Edges are softened by exactly one pixel (from screen-space derivatives), so
##   they stay crisp at any distance without crawling.
## - A rim of light at grazing angles, and an optional stepped highlight, both
##   only on the side the light reaches.
##
## Figures get the full treatment; the world gets a gentler version (see
## `surface`), so the two sit together.

const SHADER := """
shader_type spatial;

uniform vec3 albedo : source_color = vec3(1.0);
// How far past side-on the lit tone wraps, 0..1.
uniform float wrap = 0.0;
// Where the brighter core starts (as a share of full light), and what it adds.
uniform float core_cut = 0.6;
uniform float core_gain = 0.25;
// 1: light inside its reach is flat, like a spotlight on a cut-out.
// 0: it still fades with distance.
uniform float flatness = 0.65;
uniform float rim_gain = 0.6;
uniform float rim_width = 0.22;
uniform float highlight = 0.0;
uniform float gloss = 24.0;

void fragment() {
	ALBEDO = albedo;
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
	// One number for "how lit", so shadows and falloff cut as cleanly as the terminator.
	float amount = facing * smoothstep(0.15, 0.6, reach);
	float lit = cut(amount, 0.04);
	float core = cut(amount, core_cut);
	float strength = mix(reach, 1.0, flatness);
	DIFFUSE_LIGHT += (lit * (1.0 - core_gain) + core * core_gain) * strength * LIGHT_COLOR / PI;

	float graze = 1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0);
	float rim = cut(graze, 1.0 - rim_width) * lit;
	float shine = cut(pow(max(dot(NORMAL, normalize(LIGHT + VIEW)), 0.0), gloss), 0.5) * lit;
	// The rim is a brighter shade of the surface itself, so dark hair gets a dark rim.
	SPECULAR_LIGHT += (rim * rim_gain * albedo + shine * highlight) * strength * LIGHT_COLOR / PI;
}
"""

static var _shader: Shader


## Reshades every mesh under `model` as a figure. Its own materials are left untouched.
static func apply(model: Node) -> void:
	for part: MeshInstance3D in model.find_children("*", "MeshInstance3D", true, false):
		for surface in part.mesh.get_surface_count():
			var original := part.mesh.surface_get_material(surface) as StandardMaterial3D
			if original:
				part.set_surface_override_material(surface, _material(original.albedo_color))


## A material for the world: the same hard edge between light and shadow, but
## it keeps its fall-off with distance and has no rim, so walls and floors read
## as lit space rather than as cut-outs. Falls back to smooth shading when the
## menu's world shading is off.
static func surface(color: Color) -> Material:
	if not Settings.world_banded:
		var smooth := StandardMaterial3D.new()
		smooth.albedo_color = color
		smooth.roughness = 1.0
		smooth.metallic_specular = 0.0
		return smooth
	var banded := _material(color)
	banded.set_shader_parameter(&"flatness", 0.0)
	banded.set_shader_parameter(&"core_gain", 0.0)
	banded.set_shader_parameter(&"rim_gain", 0.0)
	banded.set_shader_parameter(&"wrap", 0.15)
	return banded


static func _material(color: Color) -> ShaderMaterial:
	if _shader == null:
		_shader = Shader.new()
		_shader.code = SHADER
	var material := ShaderMaterial.new()
	material.shader = _shader
	material.set_shader_parameter(&"albedo", color)
	return material
