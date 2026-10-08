class_name Toon
## Cel shading for the figures: each light falls on them in flat bands with hard
## edges (shadow, lit, and a brighter core) plus a thin rim of light at grazing
## angles, rather than a smooth gradient.

const SHADER := """
shader_type spatial;

uniform vec3 albedo : source_color = vec3(1.0);
// How far round from the light the lit band reaches (0 is exactly side-on).
uniform float lit_edge = 0.05;
// Where the brighter inner band starts, and how much it adds.
uniform float core_edge = 0.62;
uniform float core_gain = 0.3;
uniform float rim_gain = 0.35;
// Softness of each edge. Small, so the bands read as flat steps.
uniform float feather = 0.012;

void fragment() {
	ALBEDO = albedo;
	ROUGHNESS = 1.0;
	SPECULAR = 0.0;
}

void light() {
	float facing = dot(NORMAL, LIGHT);
	float lit = smoothstep(lit_edge, lit_edge + feather, facing);
	float core = smoothstep(core_edge, core_edge + feather, facing);
	// A rim where the surface turns away from the eye, on the lit side only.
	float graze = 1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0);
	float rim = smoothstep(0.72, 0.72 + feather * 2.0, graze) * lit;
	float band = lit * (1.0 - core_gain) + core * core_gain + rim * rim_gain;
	// Shadows cut in with a hard edge too.
	float shade = smoothstep(0.45, 0.55, ATTENUATION / max(ATTENUATION, 0.0001)) * ATTENUATION;
	DIFFUSE_LIGHT += band * shade * LIGHT_COLOR / PI;
}
"""

static var _shader: Shader


## Reshades every mesh under `model`. Its own materials are left untouched.
static func apply(model: Node) -> void:
	if _shader == null:
		_shader = Shader.new()
		_shader.code = SHADER
	for part: MeshInstance3D in model.find_children("*", "MeshInstance3D", true, false):
		for surface in part.mesh.get_surface_count():
			var original := part.mesh.surface_get_material(surface) as StandardMaterial3D
			if original == null:
				continue
			var banded := ShaderMaterial.new()
			banded.shader = _shader
			banded.set_shader_parameter(&"albedo", original.albedo_color)
			part.set_surface_override_material(surface, banded)
