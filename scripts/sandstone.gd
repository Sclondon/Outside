class_name Sandstone
## Stone, drawn by a shader: courses of blocks with joints between them, the
## strata in the stone, edges worn pale by the wind, chips out of the joints,
## stains run down from them, and cracks. And gold, for a capstone.
##
## Nothing here is a picture: all of it is worked out from where on the model a
## point is (in the model's own space, so it stays put when the thing is moved
## or turned), and each part fades away as it gets too small to draw, so that a
## pyramid far off is plain stone in courses and does not shimmer.
##
## It is lit as the rest of the world is (`Toon.surface`): in hard bands when
## the menu says so, smoothly otherwise.
##
## `Sandstone.surface(colour)` is for anything of stone; `Pyramid` uses it, and
## tells it more through the colour of each corner of its mesh:
##     red     how light the stone is there (1: as it comes; less: darker)
##     green   1 where it is laid in courses, 0 for a loose block, a half for a heap of rubble
##     blue    1 for rough core stone, 0 for smooth casing
## A mesh with no colours is all ones: rough stone laid in courses.

const COLOUR := Color(0.66, 0.57, 0.43)
const CASING := Color(0.83, 0.76, 0.62)
const GOLD := Color(0.96, 0.7, 0.2)

const SHADER := """
shader_type spatial;

uniform vec3 albedo : source_color = vec3(0.66, 0.57, 0.43);
// The colour of smooth casing stone.
uniform vec3 casing : source_color = vec3(0.83, 0.76, 0.62);
// 1: lit in two hard tones; 0: smoothly.
uniform float banded = 0.0;
uniform float wrap = 0.15;
// How high a course of blocks is and about how long a block, in metres.
uniform float course = 1.35;
uniform float block = 2.3;
// How weathered, 0..1, and how cracked, 0..1.
uniform float wear = 0.5;
uniform float cracks = 0.5;

varying vec3 place;
varying vec3 lie;
varying vec3 kind;

float hash(vec2 p) {
	vec3 q = fract(vec3(p.xyx) * 0.1031);
	q += dot(q, q.yzx + 33.33);
	return fract((q.x + q.y) * q.z);
}

float patches(vec2 p) {
	vec2 whole = floor(p);
	vec2 part = fract(p);
	part = part * part * (3.0 - 2.0 * part);
	return mix(mix(hash(whole), hash(whole + vec2(1.0, 0.0)), part.x),
			mix(hash(whole + vec2(0.0, 1.0)), hash(whole + vec2(1.0, 1.0)), part.x), part.y);
}

void vertex() {
	place = VERTEX;
	lie = NORMAL;
	kind = COLOR.rgb;
}

// How much of a thing `size` metres across can still be drawn, 0..1, where a
// pixel covers `pixel` metres: it is gone before it is small enough to flicker.
float seen(float size, float pixel) {
	return clamp(size * 0.4 / pixel - 0.2, 0.0, 1.0);
}

void fragment() {
	vec3 facing = abs(normalize(lie));
	bool flat_top = facing.y > 0.92;
	// Across the face and up it (or, on top, across and along).
	vec2 at = flat_top ? place.xz : vec2(facing.x > facing.z ? place.z : place.x, place.y);
	float pixel = max(length(fwidth(place)), 0.0001);
	float laid = step(0.75, kind.g);
	float heaped = step(0.25, kind.g) * (1.0 - laid);
	float rough = kind.b;

	// The blocks: a row to each course, every row with blocks of its own length, set off from the next.
	float row = floor(at.y / course);
	float span = block * (0.75 + 0.6 * hash(vec2(row, 3.7)));
	float along = at.x / span + hash(vec2(row, 9.1));
	float column = floor(along);
	vec2 within = vec2(fract(along) * span, fract(at.y / course) * course);
	vec2 to_joint = min(within, vec2(span, course) - within);
	float joint = min(to_joint.x, to_joint.y);

	float tone = 1.0;
	// Each course a little lighter or darker than the next, and each block within it.
	tone += (hash(vec2(row, 1.3)) - 0.5) * 0.1 * laid * seen(course, pixel);
	tone += (hash(vec2(row, column)) - 0.5) * mix(0.05, 0.13, rough) * laid * seen(course, pixel * 1.5);
	// Strata: thin beds of harder and softer stone, lying level.
	if (!flat_top) {
		float beds = patches(vec2(at.x * 0.11 + hash(vec2(row, column)) * 20.0 * laid, at.y * 6.5));
		float fine = seen(0.15, pixel);
		tone -= (smoothstep(0.55, 0.6, beds) * 0.055 + smoothstep(0.8, 0.84, beds) * 0.05) * rough * fine;
	}
	// Stains run down the face, the more the older it is.
	float runs = patches(vec2(at.x * 1.6, at.y * 0.22 + 3.0)) * patches(at * 0.31 + 11.0);
	tone -= smoothstep(0.28, 0.5, runs) * 0.12 * wear * (flat_top ? 0.4 : 1.0) * seen(0.6, pixel);
	// Edges worn by blown sand: the corners of each block are rubbed pale and round.
	float rubbed = wear * rough * laid * (0.03 + 0.2 * patches(at * 0.9 + row * 7.3));
	float pale = (1.0 - smoothstep(rubbed - pixel, rubbed + pixel, joint)) * seen(0.25, pixel);
	tone += pale * 0.09;
	// The top edge of a block catches the light and the bottom one is in its own shadow.
	if (!flat_top) {
		float lip = seen(0.08, pixel) * laid * rough;
		tone += (1.0 - smoothstep(0.05, 0.05 + pixel, course - within.y)) * 0.07 * lip;
		tone -= (1.0 - smoothstep(0.07, 0.07 + pixel, within.y)) * 0.1 * lip;
	}

	// The joints: thin and dark, wider where the stone has chipped away.
	float chip = patches(at * vec2(1.3, 2.1) + 5.0);
	float gap = mix(0.007, 0.016 + wear * 0.1 * chip * chip * chip, rough);
	float line = (1.0 - smoothstep(gap - pixel, gap + pixel, joint)) * clamp(gap * 1.6 / pixel, 0.0, 1.0) * laid;

	// Cracks: thin lines wandering through the stone, in patches, across block after block.
	// (a crack is where a slow unevenness passes through its middle value: a long
	// wandering line, made jagged by a quicker one, and shown only in stretches)
	float wander = patches(at * 0.27 + 23.0) + 0.2 * patches(at * 1.3 + 7.0) + 0.05 * patches(at * 5.3);
	float stretch = smoothstep(0.45, 0.7, patches(at * 0.5 + 90.0));
	float where_cracked = stretch * smoothstep(1.0 - cracks * 0.8, 1.1 - cracks * 0.8, patches(at * 0.13 + 40.0) + 0.25 * rough);
	float from_crack = abs(wander - 0.62) / max(fwidth(wander), 0.00001);
	float thick = (0.004 + 0.016 * stretch) / pixel;
	float crack = (1.0 - smoothstep(max(thick - 0.5, 0.0), thick + 0.5, from_crack)) * clamp(thick * 2.0, 0.0, 1.0) * where_cracked;

	// A heap of rubble: stones of all tones lying against each other, seen from above, with dark between them.
	if (heaped > 0.5) {
		vec2 among = place.xz / 0.8;
		vec2 whole = floor(among);
		vec2 part = fract(among);
		float nearest = 8.0;
		float next = 8.0;
		float which = 0.0;
		for (int j = -1; j <= 1; j++) {
			for (int i = -1; i <= 1; i++) {
				vec2 cell = whole + vec2(float(i), float(j));
				// (squarish: they were blocks once)
				vec2 to_stone = abs(vec2(float(i), float(j)) + vec2(hash(cell), hash(cell + 57.0)) - part);
				float off = max(to_stone.x, to_stone.y) * 0.8 + min(to_stone.x, to_stone.y) * 0.35;
				if (off < nearest) {
					next = nearest;
					nearest = off;
					which = hash(cell + 13.0);
				} else if (off < next) {
					next = off;
				}
			}
		}
		float stones = seen(0.8, pixel * 1.5);
		tone += ((which - 0.5) * 0.34 + (0.5 - nearest) * 0.16) * stones;
		float between = 0.02 + 0.1 * hash(whole + 3.0);
		line = (1.0 - smoothstep(between, between + pixel * 2.5, next - nearest)) * 0.7 * seen(0.25, pixel);
		crack *= 0.3;
	}

	vec3 stone = mix(casing, albedo, rough);
	ALBEDO = stone * kind.r * tone * (1.0 - 0.5 * line) * (1.0 - 0.55 * crack);
	ROUGHNESS = 1.0;
	SPECULAR = 0.0;
}

float cut(float value, float edge) {
	float pixel = max(fwidth(value), 0.0005);
	return smoothstep(edge - pixel, edge + pixel, value);
}

void light() {
	float reach = clamp(ATTENUATION, 0.0, 1.0);
	float towards = dot(NORMAL, LIGHT);
	float hard = cut((towards + wrap) / (1.0 + wrap) * smoothstep(0.15, 0.6, reach), 0.04) * reach;
	float soft = clamp(towards, 0.0, 1.0) * reach;
	DIFFUSE_LIGHT += mix(soft, hard, banded) * LIGHT_COLOR / PI;
}
"""

## Gold: lit as the stone is, and then it shines. A flat face of it catches the
## sun all at once, so the highlight is cut into steps rather than a spot, and
## it keeps a glow of its own in shadow.
const GOLD_SHADER := """
shader_type spatial;

uniform vec3 albedo : source_color = vec3(0.96, 0.7, 0.2);
uniform float banded = 0.0;
uniform float wrap = 0.15;
// How broad the shine is (less is broader), how bright, and how much it glows unlit.
uniform float gloss = 5.0;
uniform float shine = 0.8;
uniform float glow = 0.22;

float cut(float value, float edge) {
	float pixel = max(fwidth(value), 0.0005);
	return smoothstep(edge - pixel, edge + pixel, value);
}

void fragment() {
	ALBEDO = albedo;
	ROUGHNESS = 1.0;
	SPECULAR = 0.0;
	// A bright edge where it is seen side-on, as polished metal has.
	float graze = 1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0);
	EMISSION = albedo * (glow + 0.3 * mix(smoothstep(0.55, 0.95, graze), cut(graze, 0.78), banded));
}

void light() {
	float reach = clamp(ATTENUATION, 0.0, 1.0);
	float towards = dot(NORMAL, LIGHT);
	float hard = cut((towards + wrap) / (1.0 + wrap) * smoothstep(0.15, 0.6, reach), 0.04) * reach;
	float soft = clamp(towards, 0.0, 1.0) * reach;
	float lit = mix(soft, hard, banded);
	DIFFUSE_LIGHT += lit * LIGHT_COLOR / PI;
	float caught = pow(max(dot(NORMAL, normalize(LIGHT + VIEW)), 0.0), gloss);
	float stepped = cut(caught, 0.3) * 0.45 + cut(caught, 0.62) * 0.55;
	SPECULAR_LIGHT += mix(caught, stepped, banded) * shine * step(0.0, towards) * reach * LIGHT_COLOR / PI * vec3(1.0, 0.86, 0.5);
}
"""

static var _shader: Shader
static var _gold_shader: Shader


## A material for stone of a colour, laid in courses `course` metres high of
## blocks about `block` long. `wear` (0..1) is how weathered it is and `cracks`
## (0..1) how cracked.
static func surface(colour := COLOUR, course := 1.35, block := 2.3, wear := 0.5, cracks := 0.5) -> ShaderMaterial:
	if _shader == null:
		_shader = Shader.new()
		_shader.code = SHADER
	var material := ShaderMaterial.new()
	material.shader = _shader
	material.set_shader_parameter(&"albedo", colour)
	material.set_shader_parameter(&"casing", CASING.lerp(colour, 0.25))
	material.set_shader_parameter(&"banded", 1.0 if Settings.world_banded else 0.0)
	material.set_shader_parameter(&"course", course)
	material.set_shader_parameter(&"block", block)
	material.set_shader_parameter(&"wear", wear)
	material.set_shader_parameter(&"cracks", cracks)
	return material


## A material for gold.
static func gold(colour := GOLD) -> ShaderMaterial:
	if _gold_shader == null:
		_gold_shader = Shader.new()
		_gold_shader.code = GOLD_SHADER
	var material := ShaderMaterial.new()
	material.shader = _gold_shader
	material.set_shader_parameter(&"albedo", colour)
	material.set_shader_parameter(&"banded", 1.0 if Settings.world_banded else 0.0)
	return material
