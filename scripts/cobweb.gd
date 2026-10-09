class_name Cobweb
extends Node3D
## Old cobweb, for tomb tunnels. `Cobweb.new()` with a `kind` is a whole one:
##
## - `CORNER`: a quarter fan in the corner between a wall and the ceiling. The
##   corner is at this node (`height` above it), one edge runs along the
##   ceiling towards +X and the other down the wall towards -Y; `size` is how
##   long those edges are. Tipped on its back it fills the corner between two
##   walls.
## - `SHEET`: a web across a passage, `wide` by `tall`, standing on this node
##   and facing along Z, made fast to the walls and the roof, its foot ragged.
##   He walks or runs through it: it tears from top to bottom where he went
##   (`torn`), the edges of the tear draw back and the rest of it is thrown
##   forward and swings; shreds are left hanging at the tear, a little dust
##   comes off it, and some of it clings to him for a few seconds.
## - `HANGING`: strands and tatters hanging from this node (`height` above it),
##   `size` long, over a width of `wide`, swaying in the draught.
## - `DRAPE`: thick old webbing draped over something `over` in size (a jar, a
##   coffin, a heap), standing on this node.
##
## Fire burns them: a `Fire` (a torch held to one, a brazier) or a flare within
## `catch_distance`, and it burns away from that point in a moment, a glowing
## edge running out across it, and sets light to any web touching it (`burnt`).
##
## There is nothing to load. Each is a few dozen triangles and one draw call,
## and its threads are drawn by the shader: spokes running out from a hub, with
## finer threads sagging from spoke to spoke round it, or (for what hangs)
## threads running down with cross threads between; a veil of dust over them
## with holes in it; and a ragged edge. A thread narrower than a dot of the
## screen is drawn fainter, not thinner, and when the threads are too close to
## tell apart the web is the even grey they would average to: so it does not
## shimmer far off. It is lit from both sides by whatever light there is, a
## torch going past as much as the sun, and by nothing else but a faint
## `glimmer` that lets it be made out against dark stone.

signal torn
signal burnt

enum Kind { CORNER, SHEET, HANGING, DRAPE }

## Which sort of web. Set before it goes into the scene, like the rest.
@export var kind := Kind.CORNER
## Corner: the length of its two edges. Hanging: how far the longest strand hangs. Metres.
@export var size := 1.0
## Sheet: how wide and tall the passage is. Hanging: over what width the strands hang.
@export var wide := 2.4
@export var tall := 2.4
## Corner and hanging: how far above this node the corner, or what they hang from, is.
@export var height := 0.0
## Drape: the size of what it lies over.
@export var over := Vector3(0.8, 0.9, 0.8)
## How thick with dust it is, 0 (bare threads) to 1 (a grey sheet).
@export_range(0.0, 1.0) var dust := 0.45
## How many strands hang (hanging only).
@export var strands := 6
## Which web: another number, another web of the same sort.
@export var seed := 0
## Fire burns it, and how near a flame has to come (m).
@export var burns := true
@export var catch_distance := 0.4
## A sheet tears when he goes through it.
@export var tears := true
@export var colour := Color(0.86, 0.84, 0.78)

const SHADER := """
shader_type spatial;
render_mode blend_mix, depth_draw_never, cull_disabled, shadows_disabled, specular_disabled;

uniform vec3 tint : source_color = vec3(0.86, 0.84, 0.78);
// 0: threads run out from a hub and round it. 1: they hang straight down.
uniform float form = 0.0;
// How many spokes in a full turn (or, hanging, in a metre), and how far apart the threads between them are.
uniform float spokes = 26.0;
uniform float ring_gap = 0.085;
// How thick a spoke and a thread are, in metres.
uniform float spoke = 0.007;
uniform float thread = 0.003;
uniform float veil = 0.3;
uniform float holes = 0.45;
uniform float seed = 0.0;
// How far the draught moves it, and a shove given it from the script, both in its own space.
uniform float sway = 0.03;
uniform vec3 push = vec3(0.0);
// Torn: where across it, how far the tear has opened (0..1), and how high it goes.
uniform float tear_x = 0.0;
uniform float tear = 0.0;
uniform float tear_top = 1.8;
// Burning: from where, and how far the fire has eaten (under 0: not burning).
uniform vec3 burn_at = vec3(0.0);
uniform float burn = -1.0;
uniform float fade = 1.0;
uniform float glimmer = 0.035;

varying vec3 spot;

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

float vnoise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1.0, 0.0)), f.x),
			mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0, 1.0)), f.x), f.y);
}

float cut(float value, float edge) {
	float pixel = max(fwidth(value), 0.0005);
	return smoothstep(edge - pixel, edge + pixel, value);
}

// How much of a dot of the screen a thread covers: `off` from its middle,
// `width` across, a dot being `dot_size`. Narrower than a dot, it is fainter.
float strand(float off, float width, float dot_size) {
	return clamp((width * 0.5 - off) / dot_size + 0.5, 0.0, 1.0) * min(1.0, 1.7 * width / dot_size);
}

void vertex() {
	spot = VERTEX;
	float loose = COLOR.r;
	float t = TIME * 1.1 + seed * 3.7;
	vec3 draught = NORMAL * sin(t + VERTEX.x * 1.7 + VERTEX.y * 2.3) + vec3(0.5, 0.0, 0.0) * sin(t * 0.73 + VERTEX.y * 3.1 + VERTEX.x);
	VERTEX += (draught * sway + push) * loose;
	// (the edges of a tear draw back from it)
	float from_tear = VERTEX.x - tear_x;
	VERTEX.x += sign(from_tear) * 0.13 * tear * exp(-from_tear * from_tear * 3.0) * loose;
}

void fragment() {
	vec2 web = UV;
	float dot_size = max(max(fwidth(web.x), fwidth(web.y)), 0.0002);
	float along;
	float out_from;
	float arc;
	if (form < 0.5) {
		float turn = atan(web.y, web.x);
		out_from = length(web);
		// (the spokes are not evenly spaced)
		along = turn / TAU * spokes + 0.33 * sin(turn * 5.0 + seed);
		arc = TAU * out_from / spokes;
	} else {
		out_from = -web.y;
		along = web.x * spokes + 0.33 * sin(web.x * spokes * 1.7 + seed) + 0.7 * sin(web.y * 7.0 + seed * 2.0);
		arc = 1.0 / spokes;
	}
	float nearest = floor(along + 0.5);
	float spoke_line = strand(abs(along - nearest) * arc, spoke * mix(0.3, 1.0, smoothstep(0.0, 0.3, out_from)), dot_size);
	// The threads between: each hangs in towards the hub from the two spokes
	// it is fast to, and no two spans of them are at quite the same places.
	float span = floor(along);
	float sag = sin(fract(along) * PI);
	float round_it = out_from / ring_gap + sag * 0.42 + hash(vec2(span, seed * 17.0)) * 0.8;
	float which = floor(round_it);
	float kept = step(holes * 0.5, hash(vec2(which + seed * 5.0, span)));
	float ring_line = strand(abs(fract(round_it) - 0.5) * ring_gap, thread, dot_size) * kept;
	float lines = max(spoke_line, ring_line);
	// Too far off to tell the threads apart: the grey they come to.
	float mean = clamp(thread / ring_gap + spoke / max(arc, 0.001), 0.0, 0.6);
	lines = mix(mean, lines, 1.0 - smoothstep(0.22, 0.55, dot_size / min(ring_gap, max(arc, 0.004))));

	// Dust lying on it in a veil, thicker here and thinner there, with holes.
	float coarse = vnoise(web * 4.0 + seed * 3.1);
	float fine = vnoise(web * 15.0 - seed);
	float whole = smoothstep(holes * 0.6 - 0.08, holes * 0.6 + 0.16, coarse * 0.7 + fine * 0.3);
	float dusty = veil * COLOR.g * (0.3 + 0.7 * coarse) * whole;
	lines *= mix(0.4, 1.0, whole);
	// Its edge: ragged, the spokes running on past the rest to where they are made fast.
	float edge = COLOR.a;
	float ragged = cut(edge + (fine - 0.5) * 0.45 + (coarse - 0.5) * 0.3, 0.16);
	float alpha = (dusty + max(ring_line, lines * 0.6) * (1.0 - dusty)) * ragged;
	alpha = max(alpha, spoke_line * mix(0.4, 1.0, whole) * cut(edge, 0.03) * 0.95);

	vec3 shade = tint * mix(0.78, 1.06, lines);
	vec3 glow = tint * glimmer;
	if (tear > 0.0) {
		float gap = (0.3 + 0.24 * vnoise(vec2(spot.y * 6.0, seed)) + 0.12 * fine) * tear;
		gap *= 1.0 - smoothstep(tear_top - 0.35, tear_top + 0.25, spot.y);
		alpha *= cut(abs(spot.x - tear_x) - gap, 0.0);
	}
	if (burn >= 0.0) {
		float reached = distance(spot, burn_at) + (coarse - 0.5) * 0.3 + (fine - 0.5) * 0.08 - burn;
		alpha *= cut(reached, 0.0);
		float ember = 1.0 - smoothstep(0.0, 0.11, reached);
		shade = mix(shade, vec3(0.04, 0.03, 0.03), smoothstep(0.0, 0.5, ember));
		glow += vec3(1.0, 0.42, 0.08) * ember * ember * 4.0;
		alpha = max(alpha, ember * cut(reached, 0.0) * 0.7 * ragged);
	}
	ALBEDO = shade;
	EMISSION = glow;
	ALPHA = clamp(alpha, 0.0, 1.0) * fade;
}

void light() {
	// Lit as much from behind as in front: it is gauze.
	DIFFUSE_LIGHT += clamp(ATTENUATION, 0.0, 1.0) * LIGHT_COLOR / PI * 0.9;
}
"""

static var _shader: Shader

var _drawn: MeshInstance3D
var _material: ShaderMaterial
# The box it fills, in its own space: what a flame has to come near.
var _bounds := AABB()
var _chance := RandomNumberGenerator.new()
var _torn := false
var _tear := 0.0
var _shove := 0.0
var _shove_way := 1.0
var _shove_time := 0.0
var _burning := false
var _burn := 0.0
var _spread := false
var _side := 0.0
var _tick := 0
# A shred that has caught on someone: who, and how much longer it lasts.
var _clings_to: Node3D
var _life := 0.0
var _dust: Dust


func _ready() -> void:
	add_to_group(&"cobwebs")
	_chance.seed = hash([seed, kind, 1911])
	_tick = randi() % 8
	if _shader == null:
		_shader = Shader.new()
		_shader.code = SHADER
	_material = ShaderMaterial.new()
	_material.shader = _shader
	_material.set_shader_parameter(&"tint", colour)
	_material.set_shader_parameter(&"seed", float(seed % 97) + float(kind) * 13.0)
	_material.set_shader_parameter(&"veil", lerpf(0.03, 0.6, dust))
	_material.set_shader_parameter(&"holes", lerpf(0.75, 0.3, dust))
	_drawn = MeshInstance3D.new()
	_drawn.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_drawn.material_override = _material
	add_child(_drawn)
	var tool := SurfaceTool.new()
	tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	match kind:
		Kind.CORNER:
			_corner(tool)
		Kind.SHEET:
			_sheet(tool)
		Kind.HANGING:
			_hanging(tool)
		Kind.DRAPE:
			_drape(tool)
	_drawn.mesh = tool.commit()
	_bounds = _drawn.mesh.get_aabb()
	set_process(_clings_to != null)
	set_physics_process(burns or (tears and kind == Kind.SHEET))


func is_torn() -> bool:
	return _torn


func is_burning() -> bool:
	return _burning


## Tears it (a sheet) from top to bottom at `across` (metres from its middle),
## as by something going through it the way `way` (+1: towards its +Z).
func tear_at(across: float, way := 1.0, by: Node3D = null) -> void:
	if _torn or kind != Kind.SHEET or _burning:
		return
	_torn = true
	_shove_way = way
	_shove_time = 0.0
	_material.set_shader_parameter(&"tear_x", across)
	_material.set_shader_parameter(&"tear_top", minf(tall, 1.85))
	set_process(true)
	# Shreds left hanging either side of the tear,
	for side: float in [-1.0, 1.0]:
		var shred := Cobweb.new()
		shred.kind = Kind.HANGING
		shred.size = minf(tall, 1.9) * _chance.randf_range(0.3, 0.55)
		shred.wide = 0.3
		shred.strands = 3
		shred.seed = seed + int(side) + 5
		shred.dust = dust
		shred.colour = colour
		shred.position = Vector3(clampf(across + side * 0.45, -wide * 0.5 + 0.1, wide * 0.5 - 0.1), minf(tall, 1.9), way * 0.04)
		add_child(shred)
	# a little dust,
	if _dust == null:
		_dust = Dust.new()
		add_child(_dust)
	var middle := to_global(Vector3(across, minf(tall * 0.5, 1.0), 0.0))
	_dust.puff(middle, global_basis.z * way * 0.6, 0.45, 4, 1.2)
	# and some of it goes with him.
	if by:
		var caught_on := Cobweb.new()
		caught_on.kind = Kind.HANGING
		caught_on.size = 0.55
		caught_on.wide = 0.42
		caught_on.strands = 5
		caught_on.seed = seed + 9
		caught_on.dust = dust
		caught_on.colour = colour
		caught_on.burns = false
		caught_on._clings_to = by
		caught_on._life = 3.5
		caught_on.top_level = true
		add_child(caught_on)
	torn.emit()


## Sets light to it at a place (in the world).
func burn_from(at: Vector3) -> void:
	if _burning or not burns:
		return
	_burning = true
	_burn = 0.0
	_material.set_shader_parameter(&"burn_at", to_local(at))
	_material.set_shader_parameter(&"burn", 0.0)
	set_process(true)


func _physics_process(_delta: float) -> void:
	if _burning or _clings_to:
		return
	# Does he go through it?
	if tears and kind == Kind.SHEET and not _torn:
		var boy := Nearby.player(get_tree())
		if boy:
			var at := boy.global_position
			var here := global_position
			if absf(at.x - here.x) + absf(at.z - here.z) < wide + 2.0:
				var local := to_local(at + Vector3.UP * 0.6)
				var inside := absf(local.x) < wide * 0.5 + 0.15 and local.y > -0.3 and local.y < tall + 0.3
				if inside and _side != 0.0 and (signf(local.z) != _side or absf(local.z) < 0.1):
					tear_at(clampf(local.x, -wide * 0.5 + 0.3, wide * 0.5 - 0.3), -_side, boy)
				_side = signf(local.z) if inside and absf(local.z) < 1.5 else 0.0
	# Is there a flame at it?
	_tick += 1
	if burns and _tick % 8 == 0:
		for fire in Nearby.fires(get_tree()):
			if not is_instance_valid(fire) or not fire.is_inside_tree():
				continue
			var flame := fire.global_position
			if fire is Fire:
				flame += fire.global_basis.y * (fire as Fire).size * 0.5
			var local := to_local(flame)
			var nearest := local.clamp(_bounds.position, _bounds.end)
			if nearest.distance_to(local) < catch_distance:
				burn_from(to_global(nearest))
				break


func _process(delta: float) -> void:
	if _clings_to:
		# Caught on him: it trails from his chest, and is gone in a few seconds.
		_life -= delta
		if _life <= 0.0 or not is_instance_valid(_clings_to):
			queue_free()
			return
		var at: Vector3 = _clings_to.get(&"visual_position") if &"visual_position" in _clings_to else _clings_to.global_position
		var going: Vector3 = _clings_to.get(&"velocity") if &"velocity" in _clings_to else Vector3.ZERO
		global_transform = Transform3D(Basis(Vector3.UP, atan2(going.x, going.z) if going.length() > 0.3 else global_rotation.y), at + Vector3.UP * 1.2)
		_material.set_shader_parameter(&"push", Vector3(0.0, 0.0, -minf(going.length() * 0.09, 0.45)))
		_material.set_shader_parameter(&"fade", clampf(_life / 1.5, 0.0, 1.0))
		return
	var busy := false
	if _torn and _shove_time < 3.0:
		# The tear opens at once; what is left is thrown the way he went and swings back and forth till it hangs still.
		_shove_time += delta
		_tear = minf(_tear + delta * 7.0, 1.0)
		_shove = _shove_way * 0.42 * exp(-_shove_time * 1.8) * cos(_shove_time * 7.5)
		_material.set_shader_parameter(&"tear", _tear)
		_material.set_shader_parameter(&"push", Vector3(0.0, -absf(_shove) * 0.2, _shove))
		busy = true
	if _burning:
		_burn += delta * (1.6 + _burn * 2.5)
		_material.set_shader_parameter(&"burn", _burn)
		busy = true
		# What touches it catches from it.
		if _burn > 0.25 and not _spread:
			_spread = true
			for other: Node in get_tree().get_nodes_in_group(&"cobwebs"):
				var web := other as Cobweb
				if web and web != self and not web._burning and web.burns:
					var middle := to_global(_bounds.get_center())
					var local := web.to_local(middle)
					var nearest := local.clamp(web._bounds.position, web._bounds.end)
					if nearest.distance_to(local) < _bounds.size.length() * 0.5 + 0.15:
						web.burn_from(web.to_global(nearest))
		if _burn > _bounds.size.length() + 0.5:
			burnt.emit()
			queue_free()
			return
	set_process(busy)


# One point of the mesh: where, where it is in the web (metres from the hub),
# how loose it is, how thick with dust, and how far inside the edge.
func _point(tool: SurfaceTool, at: Vector3, web: Vector2, loose: float, edge: float, normal := Vector3(0.0, 0.0, 1.0), thick := 1.0) -> void:
	tool.set_normal(normal)
	tool.set_uv(web)
	tool.set_color(Color(loose, thick, 0.0, edge))
	tool.add_vertex(at)


func _quad(tool: SurfaceTool, points: Array) -> void:
	for k: int in [0, 1, 2, 0, 2, 3]:
		var p: Array = points[k]
		_point(tool, p[0], p[1], p[2], p[3], p[4] if p.size() > 4 else Vector3(0.0, 0.0, 1.0))


func _corner(tool: SurfaceTool) -> void:
	_material.set_shader_parameter(&"spokes", 28.0)
	_material.set_shader_parameter(&"ring_gap", clampf(size * 0.085, 0.05, 0.14))
	_material.set_shader_parameter(&"sway", 0.012 * size)
	var around := 8
	var rings := 4
	var rows: Array = []
	for a in around + 1:
		var turn := PI * 0.5 * a / around
		# (its free edge hangs in a curve from the ceiling to the wall)
		var reach := size * (1.0 - 0.36 * pow(sin(turn * 2.0), 0.8)) * (1.0 if a == 0 or a == around else _chance.randf_range(0.92, 1.06))
		var row: Array = []
		for ring in rings + 1:
			var part := float(ring) / rings
			var flat := Vector2(cos(turn), -sin(turn)) * reach * part
			var belly := sin(PI * a / around) * part
			var fast := a == 0 or a == around
			var edge := 1.0 if ring < rings else (0.6 if fast else 0.0)
			row.append([Vector3(flat.x, height + flat.y, belly * size * 0.1), flat, belly, edge])
		rows.append(row)
	for a in around:
		for ring in rings:
			_quad(tool, [rows[a][ring], rows[a][ring + 1], rows[a + 1][ring + 1], rows[a + 1][ring]])


func _sheet(tool: SurfaceTool) -> void:
	_material.set_shader_parameter(&"spokes", 24.0)
	_material.set_shader_parameter(&"ring_gap", clampf(minf(wide, tall) * 0.045, 0.07, 0.16))
	_material.set_shader_parameter(&"sway", 0.035)
	_material.set_shader_parameter(&"spoke", 0.009)
	var hub := Vector2(_chance.randf_range(-0.15, 0.15) * wide, tall * _chance.randf_range(0.55, 0.68))
	var across := 12
	var up := 10
	var rows: Array = []
	for i in across + 1:
		var u := float(i) / across
		var row: Array = []
		for j in up + 1:
			var v := float(j) / up
			var at := Vector3((u - 0.5) * wide, v * tall, 0.0)
			# Fast to the walls and the roof; its foot hangs free, well clear of the floor in the middle.
			var foot := 0.1 + 0.16 * sin(u * PI) + 0.05 * sin(u * 17.0 + seed)
			var edge := smoothstep(foot - 0.08, foot + 0.12, v)
			var loose := sin(u * PI) * (1.0 - v * v)
			row.append([at + Vector3(0.0, 0.0, sin(u * PI) * sin(v * PI) * 0.06), Vector2(at.x, at.y) - hub, loose, edge])
		rows.append(row)
	for i in across:
		for j in up:
			_quad(tool, [rows[i][j], rows[i][j + 1], rows[i + 1][j + 1], rows[i + 1][j]])


func _hanging(tool: SurfaceTool) -> void:
	_material.set_shader_parameter(&"form", 1.0)
	_material.set_shader_parameter(&"spokes", 24.0)
	_material.set_shader_parameter(&"ring_gap", 0.07)
	_material.set_shader_parameter(&"spoke", 0.005)
	_material.set_shader_parameter(&"sway", 0.05 * clampf(size, 0.4, 2.0))
	var pieces := 6
	for strand in strands:
		var along := (float(strand) + _chance.randf_range(0.15, 0.85)) / strands - 0.5
		var top := Vector3(along * wide, height, _chance.randf_range(-0.08, 0.08))
		var long := size * (_chance.randf_range(0.3, 1.0) if strand > 0 else 1.0)
		# (most are wisps; one in three is a tatter, a rag of web)
		var broad := _chance.randf_range(0.03, 0.07) if strand % 3 != 1 else _chance.randf_range(0.1, 0.2)
		var turned := Vector3(cos(_chance.randf_range(-0.8, 0.8)), 0.0, 0.0)
		turned.z = sqrt(1.0 - turned.x * turned.x) * (1.0 if strand % 2 == 0 else -1.0)
		var shift := _chance.randf_range(0.0, 5.0)
		var rows: Array = []
		for piece in pieces + 1:
			var part := float(piece) / pieces
			var half := broad * pow(1.0 - part, 0.6) + 0.003
			var loose := part * part
			var row: Array = []
			for column: float in [-1.0, 0.0, 1.0]:
				var at := top + turned * column * half + Vector3.DOWN * long * part
				var edge := (1.0 if column == 0.0 else 0.0) * (1.0 if piece < pieces else 0.0)
				row.append([at, Vector2(column * half + shift, -long * part), loose, edge, turned.cross(Vector3.UP)])
			rows.append(row)
		for piece in pieces:
			for column in 2:
				_quad(tool, [rows[piece][column], rows[piece + 1][column], rows[piece + 1][column + 1], rows[piece][column + 1]])


func _drape(tool: SurfaceTool) -> void:
	_material.set_shader_parameter(&"spokes", 22.0)
	_material.set_shader_parameter(&"ring_gap", 0.1)
	_material.set_shader_parameter(&"sway", 0.006)
	_material.set_shader_parameter(&"veil", lerpf(0.3, 0.9, dust))
	var half := over * 0.5
	var around := 16
	var rings := 7
	var mean := (half.x + half.y + half.z) / 3.0
	var rows: Array = []
	for a in around + 1:
		var turn := TAU * a / around
		var hang := _chance.randf_range(0.8, 1.15) if a < around else 1.0
		var row: Array = []
		for ring in rings + 1:
			var down := deg_to_rad(118.0) * ring / rings
			var way := Vector3(sin(down) * cos(turn), cos(down), sin(down) * sin(turn))
			# Stretched tight over its corners and sagging between them: between the thing's own shape and a tent over it.
			var boxed := way / maxf(maxf(absf(way.x) / half.x, absf(way.y) / half.y), absf(way.z) / half.z)
			var at := boxed.lerp(way * half * 1.25, 0.72) * 1.04 + Vector3.UP * half.y
			if ring == rings:
				at.y *= 1.0 - 0.6 * (hang - 0.8)
			at.y = maxf(at.y, 0.02)
			var arc := down * mean * 1.25
			row.append([at, Vector2(cos(turn), sin(turn)) * arc, 0.25 * ring / rings, 1.0 if ring < rings else 0.0, way])
		rows.append(row)
	# (the last meridian is the first again, so that it closes)
	rows[around] = rows[0]
	for a in around:
		for ring in rings:
			_quad(tool, [rows[a][ring], rows[a][ring + 1], rows[a + 1][ring + 1], rows[a + 1][ring]])


