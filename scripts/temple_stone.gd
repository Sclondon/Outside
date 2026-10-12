class_name TempleStone
## What a temple is drawn with (`Temple`, `TempleParts`): its stone, the light
## that comes down through its roof, and the great figures cut in its pylon.
##
## The stone is one shader for everything a temple is built of, so that all of
## it that is not a column is one mesh and one draw. Like `Sandstone` it is
## worked out from where on the stone a point is, and every part of it fades
## away before it is too small to draw, so that a wall far off is plain stone
## and does not shimmer. A mesh tells it what each face is through the colour
## of its corners:
##     red     how light it is there (1 in the open; less inside, under a roof)
##     green   how it is dressed: 0 smooth, a half laid in courses, 1 in courses
##             and carved with rows of relief (see below)
##     blue    its paint: one of `PAINTS` (its place in the list, in eighths)
##     alpha   what it is: 1 sandstone, 0.75 red granite, 0.5 grey granite,
##             0.25 whitewash, 0 the dark of a doorway
## and through its UV where on the face a point is, in metres across and up.
##
## The rows of relief are the acres of wall that nobody comes close to. Each
## row (a register) is a line of figures, a king or a god standing with an arm
## held out, with columns of small signs between them, cut into the stone and
## lit from above and the left whatever the sun is doing. None of it is real
## writing: for that there is `Inscription`, which a temple puts where he can
## come close.

## The paints, in the order blue (the corner colour) counts them: none, red,
## blue, green, yellow, white, black, and the stripes of a cornice.
enum Paint { NONE, RED, BLUE, GREEN, YELLOW, WHITE, BLACK, STRIPES }
## How a face is dressed (green).
const SMOOTH := 0.0
const COURSED := 0.5
const RELIEF := 1.0
## What it is made of (alpha).
const SANDSTONE := 1.0
const RED_GRANITE := 0.75
const GREY_GRANITE := 0.5
const WHITEWASH := 0.25
const DARK := 0.0

const SHADER := """
shader_type spatial;

uniform vec3 albedo : source_color = vec3(0.66, 0.57, 0.43);
// 1: lit in two hard tones; 0: smoothly.
uniform float banded = 0.0;
uniform float wrap = 0.15;
// How high a course of blocks is and about how long a block, in metres.
uniform float course = 0.9;
uniform float block = 1.8;
// How high a row of relief is, in metres.
uniform float register = 3.0;
// How weathered, 0..1, and how much of the old paint is left, 0..1.
uniform float wear = 0.4;
uniform float painted = 0.0;

varying vec4 kind;
varying vec3 lie;

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
	kind = COLOR;
	lie = NORMAL;
	// A part that has been stretched to fit keeps its blocks and its carving the size they should be.
	vec3 by = vec3(length(MODEL_MATRIX[0].xyz), length(MODEL_MATRIX[1].xyz), length(MODEL_MATRIX[2].xyz));
	UV *= abs(NORMAL.y) > 0.9 ? by.xz : vec2(abs(NORMAL.x) > abs(NORMAL.z) ? by.z : by.x, by.y);
}

// How much of a thing `size` metres across can still be drawn, 0..1, where a
// pixel covers `pixel` metres: it is gone before it is small enough to flicker.
float seen(float size, float pixel) {
	return clamp(size * 0.4 / pixel - 0.2, 0.0, 1.0);
}

float box(vec2 p, vec2 middle, vec2 half_size) {
	vec2 d = abs(p - middle) - half_size;
	return max(d.x, d.y);
}

// How far `p` is outside a standing figure (less than nothing: inside it). The
// figure fills a cell one wide and two high, its feet at the bottom, and looks
// to the right. `who` (0..1) picks its crown and what its arm does.
float figure(vec2 p, float who) {
	float d = box(p, vec2(0.5, 1.02), vec2(0.13 - (1.2 - p.y) * 0.1, 0.22));
	d = min(d, box(p, vec2(0.5 - 0.07 + (p.y - 0.4) * 0.05, 0.4), vec2(0.045, 0.4)));
	d = min(d, box(p, vec2(0.5 + 0.1 - (p.y - 0.4) * 0.12, 0.4), vec2(0.045, 0.4)));
	d = min(d, box(p, vec2(0.52, 0.75), vec2(0.15, 0.1 - abs(p.x - 0.52) * 0.2)));
	d = min(d, length(p - vec2(0.52, 1.36)) - 0.085);
	d = min(d, box(p, vec2(0.5, 1.27), vec2(0.04, 0.05)));
	// An arm held out before it, level or raised; the other at its side.
	float lifted = who > 0.5 ? 0.5 : 0.05;
	d = min(d, box(p, vec2(0.74, 1.12 + (p.x - 0.62) * lifted), vec2(0.14, 0.03)));
	d = min(d, box(p, vec2(0.36, 0.98), vec2(0.03, 0.2)));
	// On its head: a tall crown, a disc, or two plumes.
	float crown = fract(who * 7.0);
	if (crown < 0.4) {
		d = min(d, box(p, vec2(0.5, 1.56), vec2(0.075 - (p.y - 1.45) * 0.12, 0.13)));
	} else if (crown < 0.7) {
		d = min(d, length(p - vec2(0.52, 1.56)) - 0.1);
	} else {
		d = min(d, box(p, vec2(0.5, 1.6), vec2(0.07, 0.17 - abs(p.x - 0.5) * 0.9)));
	}
	return d;
}

// A column of small signs: blobs of a few shapes, one above the next.
float signs(vec2 p) {
	vec2 cell = floor(p * vec2(4.0, 8.0));
	vec2 within = fract(p * vec2(4.0, 8.0)) - 0.5;
	float which = hash(cell + 17.0);
	vec2 half_size = which < 0.3 ? vec2(0.36, 0.12) : (which < 0.55 ? vec2(0.12, 0.36) : vec2(0.26, 0.26));
	float d = which > 0.8 ? length(within) - 0.3 : max(abs(within.x) - half_size.x, abs(within.y) - half_size.y);
	return d * 0.125;
}

// A row of relief: figures two cells apart with signs between and a ruled line under them.
float carving(vec2 at, out float who) {
	vec2 p = at / (register * 0.5);
	float row = floor(p.y * 0.5);
	float along = p.x + hash(vec2(row, 5.0)) * 3.0;
	float cell = floor(along);
	vec2 within = vec2(fract(along), fract(p.y * 0.5) * 2.0);
	who = hash(vec2(cell, row));
	float d;
	if (mod(cell, 2.0) < 0.5) {
		// (every other figure looks the other way, towards the one it meets)
		if (mod(cell, 4.0) > 1.5) {
			within.x = 1.0 - within.x;
		}
		d = figure(within, who);
	} else {
		d = within.y > 0.18 && within.y < 1.72 && abs(within.x - 0.5) < 0.36 ? signs(within) : 1.0;
		who = -1.0;
	}
	return min(d, abs(within.y - 0.04) - 0.012);
}

vec3 paint_of(float which, vec2 at) {
	if (which < 1.5) return vec3(0.62, 0.24, 0.14);
	if (which < 2.5) return vec3(0.16, 0.42, 0.56);
	if (which < 3.5) return vec3(0.26, 0.48, 0.36);
	if (which < 4.5) return vec3(0.82, 0.62, 0.22);
	if (which < 5.5) return vec3(0.9, 0.87, 0.78);
	if (which < 6.5) return vec3(0.12, 0.1, 0.09);
	// The stripes of a cornice: red, blue, green, with the stone between.
	float stripe = floor(at.x / (course * 0.22));
	float turn = mod(stripe, 6.0);
	return turn < 0.5 ? vec3(0.62, 0.24, 0.14) : (turn < 2.5 && turn > 1.5 ? vec3(0.16, 0.42, 0.56) : (turn > 3.5 && turn < 4.5 ? vec3(0.26, 0.48, 0.36) : vec3(0.86, 0.8, 0.66)));
}

void fragment() {
	bool flat_top = abs(normalize(lie).y) > 0.92;
	vec2 at = UV;
	float pixel = max(max(length(dFdx(UV)), length(dFdy(UV))), 0.0001);
	float laid = step(0.25, kind.g);
	float carved = step(0.75, kind.g);
	float what = kind.a;

	// The blocks: a row to each course, every row with blocks of its own length.
	float row = floor(at.y / course);
	float span = block * (0.75 + 0.6 * hash(vec2(row, 3.7)));
	float along = at.x / span + hash(vec2(row, 9.1));
	float column = floor(along);
	vec2 within = vec2(fract(along) * span, fract(at.y / course) * course);
	vec2 to_joint = min(within, vec2(span, course) - within);
	float joint = min(to_joint.x, to_joint.y);

	float tone = 1.0;
	tone += (hash(vec2(row, column)) - 0.5) * 0.1 * laid * seen(course, pixel * 1.5);
	// Stains run down the face, the more the older it is.
	float runs = patches(vec2(at.x * 1.1, at.y * 0.16 + 3.0)) * patches(at * 0.23 + 11.0);
	tone -= smoothstep(0.28, 0.5, runs) * 0.14 * wear * (flat_top ? 0.4 : 1.0) * seen(0.8, pixel);
	// Beds in the stone, lying level.
	if (!flat_top) {
		float beds = patches(vec2(at.x * 0.11 + hash(vec2(row, column)) * 20.0 * laid, at.y * 6.5));
		tone -= smoothstep(0.55, 0.6, beds) * 0.045 * seen(0.15, pixel);
	}
	float gap = 0.012 + wear * 0.03 * patches(at * vec2(1.3, 2.1) + 5.0);
	float line = (1.0 - smoothstep(gap - pixel, gap + pixel, joint)) * clamp(gap * 1.6 / pixel, 0.0, 1.0) * laid;

	vec3 stone = albedo;
	// Granite: no courses, and speckled.
	if (what < 0.9) {
		float speck = hash(floor(at * 55.0)) * seen(0.03, pixel) + patches(at * 9.0) * 0.6;
		stone = what > 0.6 ? vec3(0.56, 0.38, 0.32) : (what > 0.4 ? vec3(0.34, 0.33, 0.32) : vec3(0.93, 0.91, 0.84));
		tone = 1.0 + (speck - 0.6) * (what > 0.4 ? 0.22 : 0.05) - smoothstep(0.3, 0.5, runs) * 0.1 * wear;
		line = 0.0;
	}

	// The rows of relief.
	float cut_in = 0.0;
	float lip = 0.0;
	float who = -1.0;
	if (carved > 0.5 && !flat_top) {
		float shown = seen(register * 0.12, pixel);
		if (shown > 0.0) {
			float unit = register * 0.5;
			float d = carving(at, who);
			float other;
			float d_lit = carving(at + vec2(-0.035, 0.035) * unit, other);
			float edge = pixel / unit;
			cut_in = (1.0 - smoothstep(-edge, edge, d)) * shown;
			// The side of each cut that faces up and to the left is lit; the other is in shade.
			lip = clamp((d - d_lit) * 16.0, -1.0, 1.0) * (1.0 - smoothstep(0.0, 0.05, abs(d))) * shown * seen(register * 0.03, pixel);
			line *= 1.0 - cut_in;
		}
	}

	vec3 colour = stone * tone;
	colour *= 1.0 - 0.2 * cut_in;
	colour *= 1.0 + 0.3 * lip;
	// Paint: what is left of it, in patches.
	float flaked = smoothstep(0.92 - painted * 0.9, 1.0 - painted * 0.9, patches(at * 2.3 + 31.0) * 0.7 + patches(at * 11.0) * 0.3);
	float which = floor(kind.b * 8.0 + 0.5);
	if (which > 0.5) {
		colour = mix(colour, paint_of(which, at) * tone, flaked * min(painted * 1.6, 1.0));
	} else if (cut_in > 0.0 && painted > 0.0) {
		// (the flesh of a figure red, the signs blue and green)
		vec3 pigment = who < 0.0 ? mix(vec3(0.16, 0.42, 0.56), vec3(0.26, 0.48, 0.36), step(0.5, hash(floor(at * 3.0)))) : vec3(0.62, 0.24, 0.14);
		colour = mix(colour, pigment, cut_in * flaked * min(painted * 1.4, 1.0) * 0.85);
	}
	ALBEDO = colour * kind.r * (1.0 - 0.45 * line) * step(0.1, what);
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

## Light coming down through a roof: a sheet of it, brighter in the middle than
## at its edges and fading towards the floor, with dust drifting in it. It is
## added to what is behind it, casts nothing and is lit by nothing.
const BEAM_SHADER := """
shader_type spatial;
render_mode unshaded, blend_add, depth_draw_never, cull_disabled, shadows_disabled;

uniform vec3 tint : source_color = vec3(1.0, 0.9, 0.66);
uniform float strength = 0.3;

float hash(vec2 p) {
	vec3 q = fract(vec3(p.xyx) * 0.1031);
	q += dot(q, q.yzx + 33.33);
	return fract((q.x + q.y) * q.z);
}

void fragment() {
	// Across it (0..1) and down it (0 at the roof, 1 at the floor).
	float across = 1.0 - abs(UV.x * 2.0 - 1.0);
	float down = UV.y;
	float sheet = smoothstep(0.0, 0.5, across) * mix(1.0, 0.25, down);
	// Dust: motes that drift down and across, each lit for a moment.
	vec2 among = vec2(UV.x * 9.0 + TIME * 0.03, UV.y * 40.0 - TIME * 0.11);
	vec2 mote = fract(among) - 0.5;
	float lit = step(0.86, hash(floor(among))) * (1.0 - smoothstep(0.02, 0.16, length(mote)));
	ALBEDO = tint;
	ALPHA = clamp((sheet * strength + lit * 0.25 * across) * COLOR.a, 0.0, 1.0);
}
"""

## The shapes of the figures on a pylon, as `HieroglyphSigns` draws a sign:
## in a box 100 wide and 120 high, looking to the right.
## The king smiting: he strides forward with a mace raised behind his head, and
## with his other hand holds a huddle of kneeling captives by the hair.
const SMITING: Array[String] = [
	"F 27,118 41,118 40,112 50,76 38,74", "F 58,118 76,118 74,112 66,110 58,78 46,76",
	"F 36,56 56,56 64,80 33,78", "F 39,58 55,58 61,40 33,40", "O 47,31 5.5,6",
	"F 41,27 53,27 55,10 51,5 44,14",
	"L 6 35,42 23,30 27,17", "L 3 27,18 14,7", "O 12,5 3.5,4.5",
	"L 6 59,43 72,52 79,60",
	"F 72,118 99,118 99,84 95,72 78,72 73,86", "O 80,66 4,4.5", "O 87,62 4,4.5", "O 94,67 4,4.5",
	"L 3 78,74 71,58", "L 3 93,74 99,58", "L 3 86,70 86,54",
]
## The god the king smites before: he stands still, holding out a curved sword.
const GOD: Array[String] = [
	"F 36,118 52,118 51,112 46,112 47,74 38,74", "F 50,118 66,118 65,112 60,112 56,74 47,74",
	"F 36,56 56,56 60,78 35,78", "F 39,58 55,58 60,40 34,40", "O 48,31 5.5,6", "F 52,29 60,32 53,35",
	"F 42,27 54,27 53,6 49,3 45,8", "F 40,26 44,26 43,10 40,12",
	"L 5 59,43 74,48", "C 3.5 74,48 86,44 90,34 84,28", "L 5 35,43 31,62",
]

static var _shader: Shader
static var _beam_shader: Shader
static var _figures := {}


## A material for a temple's stone: `course` is how high a block is, `register`
## how high a row of relief, `wear` how weathered and `painted` how much paint is left.
static func surface(colour := Sandstone.COLOUR, course := 0.9, register := 3.0, wear := 0.4, painted := 0.0) -> ShaderMaterial:
	if _shader == null:
		_shader = Shader.new()
		_shader.code = SHADER
	var material := ShaderMaterial.new()
	material.shader = _shader
	material.set_shader_parameter(&"albedo", colour)
	material.set_shader_parameter(&"banded", 1.0 if Settings.world_banded else 0.0)
	material.set_shader_parameter(&"course", course)
	material.set_shader_parameter(&"block", course * 2.1)
	material.set_shader_parameter(&"register", register)
	material.set_shader_parameter(&"wear", wear)
	material.set_shader_parameter(&"painted", painted)
	return material


## A material for light coming down through a roof.
static func beam(strength := 0.3) -> ShaderMaterial:
	if _beam_shader == null:
		_beam_shader = Shader.new()
		_beam_shader.code = BEAM_SHADER
	var material := ShaderMaterial.new()
	material.shader = _beam_shader
	material.set_shader_parameter(&"strength", strength)
	return material


## The picture of one of the great figures (`SMITING`, `GOD`),
## made once and kept: as `Hieroglyphs.texture` makes a sign's, how far each
## dot is from its edge. `box` is the box the strokes are drawn in.
static func figure(strokes: Array[String], box: Vector2, colour: Color) -> ImageTexture:
	var key := strokes[0] + str(strokes.size())
	if not _figures.has(key):
		var dots := 1.6 if box.x < 150.0 else 1.28
		var pad := 6
		var image := Hieroglyphs._field(Hieroglyphs._drawn(strokes), dots, Vector2(pad, pad), ceili(box.x * dots) + pad * 2, ceili(box.y * dots) + pad * 2, colour)
		image.generate_mipmaps()
		_figures[key] = ImageTexture.create_from_image(image)
	return _figures[key]


## A material that cuts one of those pictures into stone of a colour, as an
## `Inscription` is cut. `size` is how big it is on the wall, in metres.
static func carved(picture: ImageTexture, size: Vector2, stone: Color, wear: float, painted: float) -> ShaderMaterial:
	var shader := Inscription._shader
	if shader == null:
		shader = Shader.new()
		shader.code = Inscription.SHADER
		Inscription._shader = shader
	var material := ShaderMaterial.new()
	material.shader = shader
	material.set_shader_parameter(&"carving", picture)
	material.set_shader_parameter(&"dots", Vector2(picture.get_size()))
	material.set_shader_parameter(&"size", size)
	material.set_shader_parameter(&"stone", stone)
	material.set_shader_parameter(&"banded", 1.0 if Settings.world_banded else 0.0)
	material.set_shader_parameter(&"depth", 1.0)
	material.set_shader_parameter(&"raised", 0.0)
	material.set_shader_parameter(&"tint", clampf(painted * 1.5, 0.0, 1.0))
	material.set_shader_parameter(&"paint", 1.0)
	material.set_shader_parameter(&"wear", wear)
	return material
