class_name Fur
## A coat of short fur, shaded the way the figures are (see Toon) and then as
## fur, in three ways that add up:
##
## - The coat is streaked along the lie of the hair: fine strands of differing
##   tone, in clumps, darker in some patches than others.
## - Light catches it in a faint ragged band lying across the hair, and at the
##   edge of the body in a rim that the strands break up.
## - A few "shells": the same mesh drawn again, each time pushed a little
##   further off the skin and combed back, and each time with more of it cut
##   away, so that what is left stands up as tufts and the outline is soft.
##
## Nothing here uses a texture, transparency or the screen, so it costs the same
## in the web build as on a desktop: each shell is one more draw of the mesh
## with a cheap pixel shader. `apply(..., 0)` leaves the shells off.
##
## It needs to know which way the hair lies: the models give that as texture
## coordinates running (along the hair, across it) in metres (see `hound_fur`
## in tools/build_character.py), from which the importer works out tangents.

const SHADER := """
shader_type spatial;

uniform vec3 albedo : source_color = vec3(1.0);
// The banded light, as in Toon.
uniform float wrap = 0.3;
uniform float core_cut = 0.7;
uniform float core_gain = 0.0;
uniform float flatness = 0.65;
// How many strands show across a metre of coat, how long a run of one tone is
// along them (m), and how far their tones differ.
uniform float strands = 520.0;
uniform float run = 0.035;
uniform float streak = 0.5;
// Patches, a few centimetres across, that are darker or lighter all over.
uniform float patch = 0.22;
// How much darker the hair is at the skin, and how much lighter at its tips.
uniform float root_shade = 0.45;
uniform float tip_bleach = 0.12;
// The rim of light at the edge of the body, and how ragged the strands make it.
uniform float rim_gain = 0.5;
uniform float rim_width = 0.3;
uniform float rim_ragged = 0.35;
// The band of light across the hair.
uniform vec3 sheen : source_color = vec3(0.6, 0.66, 0.75);
uniform float sheen_gain = 0.08;
uniform float sheen_gloss = 14.0;
// Which layer this is: 0 the skin, up to 1 for the tips of the longest hair.
uniform float shell = 0.0;
// How long the hair is (m), how far it is combed back along its lie, how much
// it hangs, and how many tufts there are across a metre.
uniform float fur_length = 0.01;
uniform float comb = 0.9;
uniform float droop = 0.35;
uniform float tufts = 850.0;
// The hair is shorter on the face: everything further forward than this along
// the lie of the coat (m), and by how much.
uniform float face = -0.42;
uniform float face_length = 0.3;
// Markings, for a coat that has them (a cat's: see CatRig). None unless
// `mark_gain` is set. They are drawn from the same coordinates as the hair, and
// the model says where each kind goes in its second texture coordinates: x is
// -1 for none, 0 for the body's own (spots, or bars with `mark_bars`), 1 for
// rings (legs, tail), 2 for all dark; y is how far it is belly, which is `pale`.
uniform vec3 marks : source_color = vec3(0.0);
uniform vec3 pale : source_color = vec3(1.0);
uniform float mark_gain = 0.0;
uniform float mark_spacing = 0.04;
uniform float mark_bars = 0.0;

varying vec3 lie;
varying float strand;

// (no sines: they come out differently, and coarser, on the phone and web renderers)
float hash(vec2 p) {
	vec3 p3 = fract(vec3(p.xyx) * 0.1031);
	p3 += dot(p3, p3.yzx + 33.33);
	return fract((p3.x + p3.y) * p3.z);
}

// Smooth noise, 0..1.
float noise(vec2 p) {
	vec2 cell = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(cell), hash(cell + vec2(1.0, 0.0)), f.x), mix(hash(cell + vec2(0.0, 1.0)), hash(cell + vec2(1.0, 1.0)), f.x), f.y);
}

void vertex() {
	if (shell > 0.0) {
		// Each layer stands further off the skin, leans further back along
		// the hair, and hangs a little more.
		// (straight down, in the model's own space)
		vec3 down = (vec4(0.0, -1.0, 0.0, 0.0) * MODEL_MATRIX).xyz;
		float hair = mix(face_length, 1.0, smoothstep(face - 0.05, face + 0.03, UV.x));
		VERTEX += (NORMAL + (TANGENT * comb + down * droop) * shell) * fur_length * hair * shell;
	}
}

void fragment() {
	// (across the hair, along it)
	vec2 grain = vec2(UV.y * strands, UV.x / run);
	// Too far off to be told apart, the strands fade into the coat rather than shimmer.
	float fine = clamp(0.6 / max(fwidth(grain.x), 0.0001), 0.0, 1.0);
	strand = noise(grain);
	float tone = 1.0 + (strand - 0.5) * streak * fine + (noise(UV * vec2(23.0, 61.0)) - 0.5) * patch;
	if (shell > 0.0) {
		// What is left of this layer: a tuft wherever the hair is longer than
		// this layer is high, narrowing towards its tip.
		// Each is a lock several times longer than it is wide, lying along the
		// hair, and each row of them starts somewhere else, so that seen edge on
		// they overlap like hair and do not line up into dashes.
		float row = floor(UV.y * tufts);
		vec2 tuft = vec2(UV.y * tufts, UV.x * tufts * 0.11 + hash(vec2(row, 7.0)) * 7.0);
		float height = hash(floor(tuft)) * 0.75 + strand * 0.25;
		vec2 within = fract(tuft) - 0.5;
		float across = max(abs(within.x) * 2.0, abs(within.y) * 2.0 - 0.35);
		// At the very edge of the body, where the layers are seen from the side,
		// only the longest locks are left standing.
		float edge = 1.0 - abs(dot(normalize(NORMAL), normalize(VIEW)));
		float thin = smoothstep(0.55, 0.95, edge) * 0.45;
		if (height < shell + thin || across > 1.2 - shell * 0.75) {
			discard;
		}
	}
	vec3 base = albedo;
	if (mark_gain > 0.0) {
		// (the models come in with the second of each pair of coordinates turned over)
		vec2 lie_at = vec2(UV.x, 1.0 - UV.y);
		vec2 kind = vec2(UV2.x, 1.0 - UV2.y);
		vec2 at = lie_at / mark_spacing;
		float rough = (strand - 0.5) * 0.25;
		// Spots: one to a cell, each row of them set off from the last.
		vec2 spot = vec2(at.x, at.y * 1.2 + 0.5 * floor(at.x));
		vec2 cell = floor(spot);
		vec2 centre = vec2(0.5) + (vec2(hash(cell), hash(cell + 17.0)) - 0.5) * 0.3;
		float size = 0.2 + 0.13 * hash(cell + 5.0);
		float spots = 1.0 - smoothstep(size - 0.05, size + 0.05, length((fract(spot) - centre) * vec2(0.8, 1.0)) + rough * 0.3);
		float bars = 1.0 - smoothstep(0.32, 0.46, abs(fract(at.x * 0.85 + (noise(lie_at * vec2(22.0, 38.0)) - 0.5) * 0.7) - 0.5) * 2.0 + rough);
		// (and the line down the middle of the back)
		float body = max(mix(spots, bars, mark_bars), 1.0 - smoothstep(0.004, 0.008, abs(lie_at.y) + rough * 0.01));
		float rings = 1.0 - smoothstep(0.20, 0.34, abs(fract(at.x * 1.3) - 0.5) * 2.0 + rough);
		float mark = mix(body, rings, clamp(kind.x, 0.0, 1.0));
		mark = mix(mark, 1.0, clamp(kind.x - 1.0, 0.0, 1.0)) * clamp(kind.x + 1.0, 0.0, 1.0);
		base = mix(mix(albedo, marks, mark * mark_gain), pale, smoothstep(0.35, 0.65, kind.y));
	}
	ALBEDO = base * tone * mix(1.0 - root_shade, 1.0 + tip_bleach, shell);
	ROUGHNESS = 1.0;
	SPECULAR = 0.0;
	lie = TANGENT;
}

float cut(float value, float edge) {
	float pixel = max(fwidth(value), 0.0005);
	return smoothstep(edge - pixel, edge + pixel, value);
}

void light() {
	float reach = clamp(ATTENUATION, 0.0, 1.0);
	float facing = (dot(NORMAL, LIGHT) + wrap) / (1.0 + wrap);
	float amount = facing * smoothstep(0.15, 0.6, reach);
	// The strands carry the edge of the light a little way into the dark, so
	// the line between the two is combed rather than drawn.
	float lit = cut(amount + (strand - 0.5) * 0.12, 0.04);
	float core = cut(amount, core_cut);
	float strength = mix(reach, 1.0, flatness);
	DIFFUSE_LIGHT += (lit * (1.0 - core_gain) + core * core_gain) * strength * LIGHT_COLOR / PI;

	float graze = 1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0);
	float rim = smoothstep(1.0 - rim_width, 1.0, graze + (strand - 0.5) * rim_ragged) * lit;
	// Each strand is tipped a little differently, which is what breaks the band up.
	vec3 along = normalize(normalize(lie) + NORMAL * (strand - 0.5) * 0.8);
	float across = dot(along, normalize(LIGHT + VIEW));
	float band = pow(sqrt(max(1.0 - across * across, 0.0)), sheen_gloss) * lit * (0.4 + strand);
	SPECULAR_LIGHT += (rim * rim_gain * ALBEDO + band * sheen_gain * mix(ALBEDO, sheen, 0.5)) * strength * LIGHT_COLOR / PI;
}
"""

static var _shader: Shader


## Gives every surface under `model` whose material is named `named` a coat of
## fur in that material's colour, with `shells` layers stood off it.
static func apply(model: Node, named: StringName = &"coat", shells := 4, length := 0.01, face := -0.42) -> void:
	for part: MeshInstance3D in model.find_children("*", "MeshInstance3D", true, false):
		for surface in part.mesh.get_surface_count():
			var original := part.mesh.surface_get_material(surface) as StandardMaterial3D
			if original and original.resource_name == named:
				part.set_surface_override_material(surface, coat(original.albedo_color, shells, length, face))


## The material itself: the skin, and each shell as the next pass of the one under it.
static func coat(colour: Color, shells := 4, length := 0.01, face := -0.42) -> ShaderMaterial:
	if _shader == null:
		_shader = Shader.new()
		_shader.code = SHADER
	var skin := _layer(colour, 0.0, length, face)
	var under := skin
	for i in shells:
		var layer := _layer(colour, float(i + 1) / shells, length, face)
		under.next_pass = layer
		under = layer
	return skin


## Sets shader parameters on a coat made by `coat` or `apply`: on the skin and on
## every shell over it.
static func tune(material: ShaderMaterial, values: Dictionary) -> void:
	while material:
		for parameter: StringName in values:
			material.set_shader_parameter(parameter, values[parameter])
		material = material.next_pass as ShaderMaterial


static func _layer(colour: Color, shell: float, length: float, face: float) -> ShaderMaterial:
	var material := ShaderMaterial.new()
	material.shader = _shader
	material.set_shader_parameter(&"albedo", colour)
	material.set_shader_parameter(&"shell", shell)
	material.set_shader_parameter(&"fur_length", length)
	material.set_shader_parameter(&"face", face)
	return material
