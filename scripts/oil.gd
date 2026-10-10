class_name Oil
extends Node3D
## Lamp oil that has been spilt: it lies where it was poured, dark and
## shining, in puddles and trails that run together where they touch, and it
## burns. There is one of these to a level, and everything that spills oil or
## asks about it goes through it:
##
##     var oil := Oil.of(self)
##     oil.pour(mouth_of_the_jar)             # a little, straight down from there
##     oil.spill(here, 40, going)             # a jar's worth, thrown down
##     oil.lay(from, to)                      # a trail
##     oil.ignite(here)                       # set light to what lies there
##
## IT CATCHES from any flame brought to it: a `Fire` (a torch held low or
## thrown down in it, a brazier or a campfire it has been poured up to), a
## flare, and oil that is burning beside it. Fire goes along it at
## `spread_speed`, a metre a second, so a trail is a fuse; each part of it
## burns for `burn_time` and is then a scorch on the ground. A gap in a trail
## stops it. It will not burn under water, and water that rises over it puts
## it out.
##
## WHAT BURNING OIL DOES. It lights a cold torch that is in it (group
## `torches`), and tells anything in the group `kindling` that is in it:
## `kindle(by)` is called on it (an `OilJar` bursts; a brazier that can be lit
## would light). It kills the boy if he stands in it for `burn_after` (he smokes
## first, and a flame that has only just caught does not count), and not if
## he runs through. A `Fire` stands on it wherever it burns (a few of
## them, moved to where the burning is), so that whatever minds a `Fire` minds
## this: scarabs keep off it and cobwebs are burnt by it. Mummies will not walk
## into it (`scripts/mummy.gd`).
##
## TO ASK whether there is flame at a place, from anywhere:
##
##     Oil.is_burning_at(point, 0.5)          # burning oil there
##     Oil.is_flame_at(tree, point, 0.5)      # that, or a fire of any kind
##
## It is also in the group `flames`, and its `burning` says whether any of it
## is alight.
##
## It is drawn as five things in all, however much there is: the stain round
## it, the oil, and the deep of the oil (flat cards hugging the ground, one
## MultiMesh, drawn three times, each in one tone so that patches lying over
## one another are one puddle), the flames (cards, with the shader of `Fire`), and no more than
## `FIRES` whole fires for the sparks, the glow and the light.

## Fire has caught in it, there.
signal caught(at: Vector3)
## Someone has stood in it too long.
signal burned(who: Node3D)

## How many patches of it there can be. When there is no room, the oldest scorch goes.
const MOST := 320
## How wide one patch can be (its radius), in metres. A puddle is many of them.
const WIDEST := 0.42
## How many whole fires stand on it at once, and how many of them cast light.
const FIRES := 6
const LIGHTS := 3
## How far apart they stand.
const APART := 1.3

const WET := 0
const BURNING := 1
const SCORCH := 2
const GONE := 3

const CELL := 0.9
const LIFT := 0.02
const MARGIN := 1.9
const SPREADS_IN := 0.5
## How long a flame takes to leap up once it has caught: until then it burns nobody.
const CATCHING := 0.45

## How fast fire goes along it, in metres a second.
@export var spread_speed := 1.0
## How long each part of it burns, in seconds.
@export var burn_time := 7.0
## How long he can stand in the flames (0: they do him no harm).
@export var burn_after := 0.5

## Whether any of it is alight.
var burning: bool:
	get:
		return not _alight.is_empty()

const BLOB := """
shader_type spatial;
render_mode blend_mix, depth_draw_never, cull_back, shadows_disabled, world_vertex_coords;

// 0: the stain it leaves in the ground round it. 1: the oil, thin at its edge. 2: the oil where it is deep.
uniform float layer = 2.0;
uniform float margin = 1.9;
uniform vec3 oil : source_color = vec3(0.045, 0.034, 0.028);
uniform vec3 thin : source_color = vec3(0.2, 0.115, 0.05);
uniform vec3 sheen : source_color = vec3(0.3, 0.33, 0.4);
uniform vec3 dull : source_color = vec3(0.1, 0.105, 0.125);
uniform vec3 crust : source_color = vec3(0.12, 0.095, 0.08);
uniform vec3 stain : source_color = vec3(0.2, 0.13, 0.08);
uniform vec3 soot : source_color = vec3(0.07, 0.062, 0.058);
uniform vec3 ash : source_color = vec3(0.21, 0.19, 0.17);
uniform vec3 ember : source_color = vec3(1.0, 0.42, 0.08);

varying vec3 place;
varying vec3 up;
varying float phase;
varying float seed;

// (worked out in whole numbers: the same on every renderer, and no seams)
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

void vertex() {
	phase = INSTANCE_CUSTOM.x;
	seed = INSTANCE_CUSTOM.y;
	place = VERTEX;
	up = normalize(NORMAL);
	// It lies on the ground, and is drawn a little nearer the eye than it lies,
	// so that the ground does not show through it (the oil nearer than its stain).
	vec3 to_eye = CAMERA_POSITION_WORLD - VERTEX;
	float far = length(to_eye);
	VERTEX += to_eye / max(far, 0.001) * min(0.015 + far * 0.004, far * 0.5) * (0.4 + 0.3 * layer);
}

void fragment() {
	// Everything about it is worked out from where on the ground it is, not
	// from which patch this is: patches that overlap are one puddle.
	float out_from = length(UV * 2.0 - 1.0) * margin;
	float n = vnoise(place.xz * 4.5) * 0.65 + vnoise(place.xz * 12.0 + 7.0) * 0.35;
	// How far it has burnt: 0 while it is oil, 1 once it is a scorch.
	float burnt = phase > 2.5 ? 1.0 : clamp(phase - 1.0, 0.0, 1.0);
	float alight = step(0.5, phase) * (1.0 - step(2.5, phase));
	float body = 1.0 - out_from + (n - 0.5) * mix(0.7, 1.0, burnt);
	ROUGHNESS = 1.0;
	SPECULAR = 0.0;
	if (layer < 0.5) {
		// (soaked in, with no edge to it: where two patches' stains lie over one another nothing shows)
		ALBEDO = mix(stain, soot, burnt);
		ALPHA = smoothstep(-0.42, 0.02, body) * mix(0.4, 0.34, burnt);
		NORMAL = normalize((VIEW_MATRIX * vec4(up, 0.0)).xyz);
	} else if (layer < 1.5) {
		// Thin and brown at its edge; burnt, a brown-black crust. All one tone,
		// so that where patches lie over one another there is nothing to see.
		ALBEDO = mix(thin, crust, smoothstep(0.0, 0.6, burnt));
		EMISSION = ember * alight * 0.45 * (1.0 - burnt);
		ALPHA = cut(body, 0.0);
		NORMAL = normalize((VIEW_MATRIX * vec4(up, 0.0)).xyz);
	} else {
		vec3 eye = normalize(CAMERA_POSITION_WORLD - place);
		// Black where it is deep. What it shines with is the sky lying in it,
		// broken up: streaks that slide over it as the eye moves, and more of
		// them the flatter it is looked along. Two tones of it, a dull one round a bright.
		vec3 back = reflect(-eye, up);
		float lying = vnoise(place.xz * 3.2 + back.xz * 2.5 + 3.0) * 0.65 + vnoise(place.xz * 9.0 - back.xz * 4.0) * 0.35;
		float graze = 1.0 - clamp(dot(eye, up), 0.0, 1.0);
		float edge = mix(0.74, 0.6, graze);
		vec3 wet = mix(mix(oil, dull, cut(lying, edge - 0.07)), sheen, cut(lying, edge));
		vec3 dry = mix(soot, ash, cut(vnoise(place.xz * 8.0 + 31.0), 0.64) * 0.5);
		ALBEDO = mix(wet, dry, smoothstep(0.0, 0.6, burnt));
		// While it burns it glows, in patches that come and go.
		float hot = cut(vnoise(place.xz * 7.0 + vec2(TIME * 0.9, -TIME * 1.4)), 0.56);
		EMISSION = ember * alight * (0.1 + 0.9 * hot) * (1.0 - burnt * 0.8);
		ALPHA = cut(body, 0.17);
		// (its surface is not quite level: the light that glints on it is broken)
		vec3 rippled = up + vec3(vnoise(place.xz * 6.0) - 0.5, 0.0, vnoise(place.xz * 6.0 + 19.0) - 0.5) * 0.3 * (1.0 - burnt);
		NORMAL = normalize((VIEW_MATRIX * vec4(normalize(rippled), 0.0)).xyz);
	}
}

void light() {
	float reach = clamp(ATTENUATION, 0.0, 1.0);
	float facing = clamp(dot(NORMAL, LIGHT) * 0.6 + 0.4, 0.0, 1.0);
	DIFFUSE_LIGHT += facing * reach * LIGHT_COLOR / PI;
	// A hard glint where a light lies in it.
	float wet = (phase < 0.5 ? 1.0 : 0.0) * step(1.5, layer);
	float glint = cut(pow(max(dot(NORMAL, normalize(LIGHT + VIEW)), 0.0), 70.0), 0.5);
	SPECULAR_LIGHT += glint * wet * reach * LIGHT_COLOR * 0.3;
}
"""

static var _here: Oil
static var _blob_shader: Shader
static var _flame_shader: Shader

# Each patch: where it lies and which way is up there, how wide it is, what
# state it is in, when it was poured, when it is due to catch (INF: it is
# not), when it caught, how long it burns, a number of its own, and who laid it.
var _at := PackedVector3Array()
var _up := PackedVector3Array()
var _wide := PackedFloat32Array()
var _state := PackedByteArray()
var _born := PackedFloat32Array()
var _due := PackedFloat32Array()
var _lit := PackedFloat32Array()
var _lasts := PackedFloat32Array()
var _seed := PackedFloat32Array()
var _source := PackedInt64Array()
var _count := 0
var _spare := PackedInt32Array()
# Which patches are in each square of the ground.
var _squares := {}
# Those alight, those still spreading out, and how many are wet or about to catch.
var _alight := PackedInt32Array()
var _spreading := PackedInt32Array()
var _wet := 0
var _fused := 0
var _now := 0.0
var _tick := 0
var _heat := 0.0
var _boy: Player
var _random := RandomNumberGenerator.new()

var _blobs: MultiMesh
var _flames: MultiMesh
var _flame_material: ShaderMaterial
var _clock := 0.0
# The whole fires: each, and the patch it stands on (-1: it is put away).
var _fires: Array[Fire] = []
var _fire_on := PackedInt32Array()
var _fire_since := PackedFloat32Array()


## The one for the scene `node` is in.
static func of(node: Node) -> Oil:
	var tree := node.get_tree()
	var found := tree.get_first_node_in_group(&"oil") as Oil
	if found and not found.is_queued_for_deletion():
		return found
	var made := Oil.new()
	(tree.current_scene if tree.current_scene else tree.root).add_child(made)
	return made


## Whether oil is burning within `radius` of `point` (over the ground: the
## flames stand a metre high). False where there is no oil at all.
static func is_burning_at(point: Vector3, radius := 0.3) -> bool:
	return is_instance_valid(_here) and _here.is_inside_tree() and _here.is_burning(point, radius)


## Whether there is a flame of any kind within `radius` of `point`: burning
## oil, a `Fire` (a torch, a brazier, a campfire) or a flare.
static func is_flame_at(tree: SceneTree, point: Vector3, radius := 0.5) -> bool:
	if is_burning_at(point, radius):
		return true
	for fire in Nearby.fires(tree):
		if not is_instance_valid(fire) or not fire.is_inside_tree():
			continue
		var flame := fire.global_position
		if fire is Fire:
			flame += fire.global_basis.y * (fire as Fire).size * 0.5
		if flame.distance_to(point) < radius:
			return true
	return false


func _init() -> void:
	add_to_group(&"oil")
	add_to_group(&"flames")
	name = "Oil"


func _enter_tree() -> void:
	_here = self


func _exit_tree() -> void:
	if _here == self:
		_here = null


func _notification(what: int) -> void:
	# (the fires that are put away are nobody's children)
	if what == NOTIFICATION_PREDELETE:
		for fire in _fires:
			if is_instance_valid(fire) and fire.get_parent() == null:
				fire.free()


func _ready() -> void:
	top_level = true
	global_transform = Transform3D.IDENTITY
	_random.randomize()
	_at.resize(MOST)
	_up.resize(MOST)
	_wide.resize(MOST)
	_state.resize(MOST)
	_born.resize(MOST)
	_due.resize(MOST)
	_lit.resize(MOST)
	_lasts.resize(MOST)
	_seed.resize(MOST)
	_source.resize(MOST)
	_state.fill(GONE)
	if _blob_shader == null:
		_blob_shader = Shader.new()
		_blob_shader.code = BLOB
		_flame_shader = Shader.new()
		_flame_shader.code = Fire.FLAME

	# The stain, the oil, and the deep of the oil: the same cards, drawn three times.
	var card := PlaneMesh.new()
	card.size = Vector2(2.0, 2.0)
	_blobs = MultiMesh.new()
	_blobs.transform_format = MultiMesh.TRANSFORM_3D
	_blobs.use_custom_data = true
	_blobs.mesh = card
	_blobs.instance_count = MOST
	for i in MOST:
		_blobs.set_instance_transform(i, Transform3D(Basis.from_scale(Vector3.ZERO), Vector3.ZERO))
	for layer in 3:
		var material := ShaderMaterial.new()
		material.shader = _blob_shader
		material.set_shader_parameter(&"layer", float(layer))
		material.set_shader_parameter(&"margin", MARGIN)
		# (before the flames, and before anything else that is seen through)
		material.render_priority = -3 + layer
		var drawn := MultiMeshInstance3D.new()
		drawn.multimesh = _blobs
		drawn.material_override = material
		drawn.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		drawn.extra_cull_margin = 16384.0
		add_child(drawn)

	# The flames: a tongue or two to each patch that is alight.
	_flame_material = ShaderMaterial.new()
	_flame_material.shader = _flame_shader
	var tongue := QuadMesh.new()
	tongue.center_offset = Vector3(0.0, 0.5, 0.0)
	tongue.material = _flame_material
	_flames = MultiMesh.new()
	_flames.transform_format = MultiMesh.TRANSFORM_3D
	_flames.use_custom_data = true
	_flames.mesh = tongue
	_flames.instance_count = MOST
	_flames.visible_instance_count = 0
	var flames := MultiMeshInstance3D.new()
	flames.multimesh = _flames
	flames.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	flames.extra_cull_margin = 16384.0
	add_child(flames)

	# The whole fires, put away until there is something burning.
	for k in FIRES:
		var fire := Fire.new()
		fire.size = 0.6
		fire.spread = 0.9
		fire.light = k < LIGHTS
		fire.light_energy = 2.6
		fire.light_range = 8.0
		fire.sparks = 1.4
		fire.spits = 0.6
		_fires.append(fire)
		_fire_on.append(-1)
		_fire_since.append(0.0)


# --- Spilling it ---

## A little oil let fall from `from`: it lands on the ground straight below,
## as a patch `wide` across (its radius) or as more of the patch already there.
## A puddle grows where it goes on falling in one place. Says whether there was
## room for it (there is only so much oil in a level at once).
func pour(from: Vector3, wide := 0.2, source := 0) -> bool:
	var ground := _ground(from)
	if ground.is_empty() or _under_water(ground[0]):
		# (it falls away, or into the water, and is gone)
		return true
	var where: Vector3 = ground[0]
	var up: Vector3 = ground[1]
	var near := _middle_near(where, wide * 0.6)
	if near >= 0:
		if _wide[near] < WIDEST - 0.005:
			# (the patch that is there swells: as much again as was poured, by its area)
			_wide[near] = minf(sqrt(_wide[near] * _wide[near] + wide * wide * 0.6), WIDEST)
			_draw(near)
			_catch_from_beside(near)
			return true
		# It is as wide as a patch gets: the puddle runs out sideways.
		for tries in 4:
			var out := Vector2.from_angle(_random.randf() * TAU) * WIDEST * _random.randf_range(0.8, 1.5)
			var beside := _ground(Vector3(where.x + out.x, where.y + 0.3, where.z + out.y))
			if beside.is_empty() or absf((beside[0] as Vector3).y - where.y) > 0.4:
				continue
			where = beside[0]
			up = beside[1]
			if _middle_near(where, WIDEST * 0.5) < 0:
				break
	return _add(where, up, wide, source) >= 0


## A lot of oil thrown down at once, as when a jar breaks: a ragged puddle of
## `measures` patches' worth round `at`, thrown on a little the way it was
## `going`. `alight`, it is burning as it lands.
func spill(at: Vector3, measures: int, going := Vector3.ZERO, alight := false, source := 0) -> void:
	var ground := _ground(at + Vector3.UP * 0.3)
	if ground.is_empty():
		return
	var middle: Vector3 = ground[0]
	var count := clampi(ceili(measures * 0.6), 2, 40)
	var reach := 0.28 * sqrt(float(count))
	var on := Vector3(going.x, 0.0, going.z)
	on = on.normalized() * minf(on.length() * 0.12, 1.0) if on.length() > 0.5 else Vector3.ZERO
	for n in count:
		var share := (n + 0.5) / count
		var out := Vector2.from_angle(_random.randf() * TAU) * reach * sqrt(share) * _random.randf_range(0.8, 1.1)
		var to := middle + Vector3(out.x, 0.5, out.y) + on * reach * share
		var landed := _ground(to)
		if landed.is_empty() or absf((landed[0] as Vector3).y - middle.y) > 0.8 or _under_water(landed[0]):
			continue
		var made := _add(landed[0], landed[1], lerpf(WIDEST, 0.26, share * _random.randf()), source)
		if made >= 0 and alight:
			# (the flame runs out through it from the middle, much faster than along a trail)
			_fuse(made, _now + out.length() / (spread_speed * 5.0))
	if alight:
		_fuse_within(middle, reach + 0.5, 1.2, 0.05)


## A trail of oil over the ground from `from` to `to`, `wide` across (its
## radius). What is laid by one `source` can be taken up again (`clear`).
func lay(from: Vector3, to: Vector3, wide := 0.2, source := 0) -> void:
	var steps := maxi(ceili(from.distance_to(to) / (wide * 1.1)), 1)
	for n in steps + 1:
		var landed := _ground(from.lerp(to, float(n) / steps) + Vector3.UP * 0.5)
		if landed.is_empty() or _under_water(landed[0]):
			continue
		if _middle_near(landed[0], wide * 0.4) < 0:
			_add(landed[0], landed[1], wide * _random.randf_range(0.92, 1.1), source)


## Takes up everything laid by `source`, burning or not (0: what was poured
## and spilt by hand; -1: all of it).
func clear(source := -1) -> void:
	for i in _count:
		if _state[i] != GONE and (source == -1 or _source[i] == source):
			_remove(i)


## Whether there is oil that could burn within `radius` of `point`.
func is_oil(point: Vector3, radius := 0.3) -> bool:
	return _nearest(point, radius, WET) >= 0


## Whether oil is burning within `radius` of `point`.
func is_burning(point: Vector3, radius := 0.3) -> bool:
	return not _alight.is_empty() and _nearest(point, radius, BURNING, 1.3) >= 0


## Whether oil has burnt out within `radius` of `point`.
func is_scorched(point: Vector3, radius := 0.3) -> bool:
	return _nearest(point, radius, SCORCH) >= 0


## How many patches there are of each sort: wet, alight, burnt out. Of what
## `source` laid, or (-1) of all of it.
func amounts(source := -1) -> Vector3i:
	var found := Vector3i.ZERO
	for i in _count:
		if _state[i] < GONE and (source == -1 or _source[i] == source):
			found[_state[i]] += 1
	return found


# --- Fire ---

## Sets light to whatever oil lies within `radius` of `point`. Says whether there was any.
func ignite(point: Vector3, radius := 0.3) -> bool:
	return _fuse_within(point, radius, 1.2, 0.0)


## Puts out whatever is burning within `radius` of `point`, and stops what was
## about to catch there. What is left of it is oil still.
func douse(point: Vector3, radius := 0.5) -> void:
	for i in _within(point, radius, 2.0):
		_put_out(i)


func _physics_process(delta: float) -> void:
	_now += delta
	_tick += 1
	if _fused > 0:
		for i in _count:
			if _state[i] == WET and _due[i] <= _now:
				_catch(i)
	for n in range(_alight.size() - 1, -1, -1):
		var i := _alight[n]
		if _now - _lit[i] >= _lasts[i]:
			_state[i] = SCORCH
			_alight.remove_at(n)
			_draw(i)
	if _tick % 6 == 0:
		if _wet > 0:
			_catch_from_fires()
		if not _alight.is_empty():
			_light_what_is_in_it()
			# (water that has come up over it puts it out)
			if _tick % 12 == 0:
				for n in range(_alight.size() - 1, -1, -1):
					if _under_water(_at[_alight[n]]):
						_put_out(_alight[n])
		_tend_fires()
	_mind_the_boy(delta)


# Fire has reached a patch.
func _catch(i: int) -> void:
	_due[i] = INF
	_fused -= 1
	if _under_water(_at[i]):
		return
	_state[i] = BURNING
	_wet -= 1
	_lit[i] = _now
	_lasts[i] = burn_time * _random.randf_range(0.85, 1.15) * lerpf(0.8, 1.1, _wide[i] / WIDEST)
	_alight.append(i)
	_draw(i)
	# It goes on into every patch this one touches, in the time fire takes to cross to it.
	for j in _within(_at[i], _wide[i] * 0.95, 0.5):
		if _state[j] == WET:
			_fuse(j, _now + Vector2(_at[j].x - _at[i].x, _at[j].z - _at[i].z).length() / maxf(spread_speed, 0.05))
	caught.emit(_at[i])


# A patch is to catch at `when`, if it was not going to sooner.
func _fuse(i: int, when: float) -> void:
	if _state[i] != WET or when >= _due[i]:
		return
	if _due[i] == INF:
		_fused += 1
	_due[i] = when


func _fuse_within(point: Vector3, radius: float, above: float, after: float) -> bool:
	var any := false
	for i in _within(point, radius, above):
		if _state[i] == WET and not _under_water(_at[i]):
			_fuse(i, _now + after)
			any = true
	return any


# New oil, or oil that has spread: if what it now touches is burning, so will it.
func _catch_from_beside(i: int) -> void:
	for j in _within(_at[i], _wide[i] * 0.95, 0.5):
		if _state[j] == BURNING:
			_fuse(i, _now + Vector2(_at[j].x - _at[i].x, _at[j].z - _at[i].z).length() / maxf(spread_speed, 0.05))


func _put_out(i: int) -> void:
	if _state[i] == BURNING:
		_state[i] = WET
		_wet += 1
		_due[i] = INF
		_alight.remove_at(_alight.find(i))
		_draw(i)
	elif _state[i] == WET and _due[i] != INF:
		_due[i] = INF
		_fused -= 1


# Any fire that is not this oil's own, and any flare, lights the oil under it:
# a flame on the ground, or one held or standing a little over it.
func _catch_from_fires() -> void:
	for fire in Nearby.fires(get_tree()):
		if not is_instance_valid(fire) or not fire.is_inside_tree() or fire.get_parent() == self:
			continue
		var reach := 0.5
		var above := 0.6
		if fire is Fire:
			reach = 0.25 + (fire as Fire).size * 0.5
			above = 0.8 + (fire as Fire).size
		_fuse_within(fire.global_position, reach, above, 0.0)


# A cold torch in the flames is lit, and whatever else can be kindled is told.
func _light_what_is_in_it() -> void:
	for torch: Node in get_tree().get_nodes_in_group(&"torches"):
		var stick := torch as Node3D
		if stick == null or stick.get(&"lit"):
			continue
		var long: float = stick.get(&"length") if stick.get(&"length") != null else 0.6
		if is_burning(stick.global_position, 0.25) or is_burning(stick.global_position + stick.global_basis.y * long, 0.25):
			stick.set(&"lit", true)
	for thing: Node in get_tree().get_nodes_in_group(&"kindling"):
		var body := thing as Node3D
		if body and body.has_method(&"kindle") and is_burning(body.global_position, 0.3):
			body.call(&"kindle", self)


# The whole fires are stood where the burning is, apart from one another: the
# newest of it first, since that is where it is going.
func _tend_fires() -> void:
	for k in FIRES:
		var on := _fire_on[k]
		if on >= 0 and (_state[on] != BURNING or _left(on) < 0.15):
			_fire_on[k] = -1
			var next := _site()
			if next >= 0:
				_stand_fire(k, next)
			else:
				remove_child(_fires[k])
	if _alight.is_empty():
		return
	var site := _site()
	if site < 0:
		return
	var free := _fire_on.find(-1)
	if free < 0:
		# (none to spare: the one with least left to burn is moved up, if this has much more)
		var least := 0
		for k in FIRES:
			if _left(_fire_on[k]) < _left(_fire_on[least]):
				least = k
		if _left(site) < _left(_fire_on[least]) + burn_time * 0.3:
			return
		free = least
	_stand_fire(free, site)


func _stand_fire(k: int, on: int) -> void:
	var fire := _fires[k]
	_fire_on[k] = on
	_fire_since[k] = _now
	fire.position = _at[on]
	fire.scale = Vector3.ONE * 0.05
	if fire.get_parent() == null:
		add_child(fire)


# The burning patch with the most left to burn that has no fire near it.
func _site() -> int:
	var best := -1
	for i in _alight:
		if _left(i) < 1.0 or (best >= 0 and _left(i) <= _left(best)):
			continue
		var clear_of := true
		for k in FIRES:
			if _fire_on[k] >= 0 and _at[_fire_on[k]].distance_to(_at[i]) < APART:
				clear_of = false
				break
		if clear_of:
			best = i
	return best


# How long a burning patch has left.
func _left(i: int) -> float:
	return _lasts[i] - (_now - _lit[i]) if _state[i] == BURNING else 0.0


# He is burnt if he stands in it: not at once, and not for running through.
func _mind_the_boy(delta: float) -> void:
	if burn_after <= 0.0 or (_alight.is_empty() and _heat <= 0.0):
		return
	if not is_instance_valid(_boy):
		_boy = Nearby.player(get_tree())
		if _boy == null:
			return
		_boy.respawned.connect(func() -> void: _heat = 0.0)
	var feet := _boy.global_position
	# (a flame that has only just caught is not yet a flame to be burnt by: he has a moment to step out of what he lights)
	var in_it := false
	var hot := false
	if not _boy.is_limp:
		for i in _within(feet, 0.12, 0.7):
			if _state[i] == BURNING:
				in_it = true
				hot = hot or _now - _lit[i] > CATCHING
	_heat = _heat + delta if hot else maxf(_heat - delta * 2.0, 0.0)
	if in_it and _tick % 4 == 0:
		# (fair warning: he smokes)
		GunFX.of(self).smoke(feet + Vector3.UP * 0.5, Vector3.UP * 1.2, 0.35, 1, Color(0.2, 0.18, 0.17, 0.5), 0.7)
	if _heat >= burn_after and not _boy.is_limp:
		_heat = 0.0
		var away := Vector3(_boy.velocity.x, 0.0, _boy.velocity.z)
		away = away.normalized() if away.length() > 0.5 else Vector3(sin(_boy.facing_yaw), 0.0, cos(_boy.facing_yaw)) * -1.0
		_boy.ragdoll(away * 20.0 + Vector3.UP * 14.0)
		burned.emit(_boy)
		await get_tree().create_timer(2.2).timeout
		if is_instance_valid(_boy) and _boy.is_limp:
			_boy.respawn()


# --- What is drawn ---

func _process(delta: float) -> void:
	# Fresh oil spreads out to its width.
	for n in range(_spreading.size() - 1, -1, -1):
		var i := _spreading[n]
		_draw(i)
		if _state[i] != WET or _now - _born[i] >= SPREADS_IN:
			_spreading.remove_at(n)
	if _alight.is_empty():
		if _flames.visible_instance_count != 0:
			_flames.visible_instance_count = 0
		return
	_clock += delta * 1.5
	_flame_material.set_shader_parameter(&"clock", _clock)
	_flame_material.set_shader_parameter(&"flare", Fire._wander(_clock * 2.3) * 2.0 - 1.0)
	var shown := 0
	for i in _alight:
		var since := _now - _lit[i]
		var left := _lasts[i] - since
		# (how far through its burning it is, for what the ground shows under the flames)
		_blobs.set_instance_custom_data(i, Color(1.0 + clampf(since / _lasts[i], 0.0, 0.999), _seed[i], 0.0, 0.0))
		# A flame leaps up as it catches, and sinks away at the end.
		var life := smoothstep(0.0, 0.35, since) * (0.25 + 0.75 * smoothstep(0.0, 1.8, left)) * smoothstep(0.0, 0.3, left)
		var tall := (0.42 + _wide[i] * 1.5) * life
		for part in (2 if _wide[i] > 0.3 else 1):
			if shown >= MOST:
				break
			var own := fposmod(_seed[i] * (7.0 + part * 3.0), 1.0)
			var out := Vector2.from_angle(own * TAU) * _wide[i] * (0.25 + 0.45 * part)
			var high := tall * (0.75 + 0.5 * own) * (1.0 if part == 0 else 0.7)
			_flames.set_instance_transform(shown, Transform3D(Basis.from_scale(Vector3(high * 0.8, high, 1.0)), _at[i] + Vector3(out.x, 0.0, out.y)))
			_flames.set_instance_custom_data(shown, Color(own, 1.0, 0.0, 0.0))
			shown += 1
	_flames.visible_instance_count = shown
	for k in FIRES:
		var on := _fire_on[k]
		if on >= 0:
			_fires[k].scale = Vector3.ONE * maxf(smoothstep(0.0, 0.4, _now - _fire_since[k]) * smoothstep(0.0, 1.2, _left(on)), 0.05)


func _draw(i: int) -> void:
	if _state[i] == GONE:
		_blobs.set_instance_transform(i, Transform3D(Basis.from_scale(Vector3.ZERO), _at[i]))
		return
	var up := _up[i]
	var across := Vector3.BACK.cross(up).normalized()
	var grown := 1.0
	if _state[i] == WET:
		var spread := clampf((_now - _born[i]) / SPREADS_IN, 0.0, 1.0)
		grown = 0.4 + 0.6 * (1.0 - (1.0 - spread) * (1.0 - spread))
	var big := _wide[i] * MARGIN * grown
	_blobs.set_instance_transform(i, Transform3D(Basis(across * big, up * big, across.cross(up) * big), _at[i] + up * LIFT))
	var phase := 0.0
	if _state[i] == BURNING:
		phase = 1.0 + clampf((_now - _lit[i]) / _lasts[i], 0.0, 0.999)
	elif _state[i] == SCORCH:
		phase = 3.0
	_blobs.set_instance_custom_data(i, Color(phase, _seed[i], 0.0, 0.0))


# --- Where it is ---

func _add(where: Vector3, up: Vector3, wide: float, source: int) -> int:
	var i := -1
	if not _spare.is_empty():
		i = _spare[_spare.size() - 1]
		_spare.remove_at(_spare.size() - 1)
	elif _count < MOST:
		i = _count
		_count += 1
	else:
		# No room: the oldest scorch is given up.
		for j in _count:
			if _state[j] == SCORCH and (i < 0 or _lit[j] < _lit[i]):
				i = j
		if i < 0:
			return -1
		_remove(i)
		_spare.remove_at(_spare.find(i))
	_at[i] = where
	_up[i] = up
	_wide[i] = clampf(wide, 0.08, WIDEST)
	_state[i] = WET
	_born[i] = _now
	_due[i] = INF
	_lit[i] = 0.0
	_seed[i] = _random.randf()
	_source[i] = source
	_wet += 1
	var square := _square(where)
	var there: PackedInt32Array = _squares.get(square, PackedInt32Array())
	there.append(i)
	_squares[square] = there
	_spreading.append(i)
	_draw(i)
	_catch_from_beside(i)
	return i


func _remove(i: int) -> void:
	if _state[i] == GONE:
		return
	if _state[i] == BURNING:
		_alight.remove_at(_alight.find(i))
	elif _state[i] == WET:
		_wet -= 1
		if _due[i] != INF:
			_fused -= 1
	var square := _square(_at[i])
	var there: PackedInt32Array = _squares.get(square, PackedInt32Array())
	var found := there.find(i)
	if found >= 0:
		there.remove_at(found)
		_squares[square] = there
	_state[i] = GONE
	_due[i] = INF
	_spare.append(i)
	_draw(i)


func _square(where: Vector3) -> Vector2i:
	return Vector2i(floori(where.x / CELL), floori(where.z / CELL))


# Every patch that reaches within `radius` of `point` over the ground, and is
# no more than `above` under it (or a little over it).
func _within(point: Vector3, radius: float, above: float) -> PackedInt32Array:
	var found := PackedInt32Array()
	var span := ceili((radius + WIDEST) / CELL)
	var middle := _square(point)
	for x in range(middle.x - span, middle.x + span + 1):
		for z in range(middle.y - span, middle.y + span + 1):
			var there: Variant = _squares.get(Vector2i(x, z))
			if there == null:
				continue
			for i: int in there:
				var over := point.y - _at[i].y
				if over > above or over < -0.5:
					continue
				var off := Vector2(_at[i].x - point.x, _at[i].z - point.z).length()
				if off < radius + _wide[i]:
					found.append(i)
	return found


# The nearest patch in a given state that reaches within `radius` of `point`, or -1.
func _nearest(point: Vector3, radius: float, state: int, above := 0.6) -> int:
	var best := -1
	var least := INF
	for i in _within(point, radius, above):
		if _state[i] != state:
			continue
		var off := Vector2(_at[i].x - point.x, _at[i].z - point.z).length() - _wide[i]
		if off < least:
			least = off
			best = i
	return best


# The wet patch whose middle is nearest `point`, if one is within `radius` of it, or -1.
func _middle_near(point: Vector3, radius: float) -> int:
	var best := -1
	var least := radius
	for i in _within(point, 0.0, 0.6):
		var off := Vector2(_at[i].x - point.x, _at[i].z - point.z).length()
		if _state[i] == WET and off < least:
			least = off
			best = i
	return best


# The ground straight below `from`: [where, which way is up there], or nothing
# if there is none, or it is too steep for oil to lie on. Loose things and
# people are not ground.
func _ground(from: Vector3) -> Array:
	var space := get_world_3d().direct_space_state
	var spared: Array[RID] = []
	for tries in 4:
		var query := PhysicsRayQueryParameters3D.create(from + Vector3.UP * 0.05, from + Vector3.DOWN * 8.0, 1, spared)
		var found := space.intersect_ray(query)
		if found.is_empty():
			return []
		if found.collider is RigidBody3D or found.collider is CharacterBody3D:
			spared.append(found.rid)
			continue
		var up: Vector3 = found.normal
		if up.y < 0.5:
			return []
		return [found.position, up]
	return []


func _under_water(point: Vector3) -> bool:
	for pool: Node in get_tree().get_nodes_in_group(&"water"):
		if pool.has_method(&"depth_at") and pool.call(&"depth_at", point) > 0.02:
			return true
	return false
