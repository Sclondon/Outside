class_name GunFX
extends Node3D
## Everything a shot leaves behind, for every gun in the scene at once: the
## flash at the muzzle and its light, powder smoke, sparks, chips of stone, the
## marks bullets leave, tracers, spent cases, and the sounds. There is one of
## these to a scene, made the first time it is asked for:
##
##     GunFX.of(self).impact(at, normal, direction, &"stone")
##
## It is four draw calls however much is going on (what glows; what does not;
## the marks; the cases), after `scripts/dust.gd`: each is one MultiMesh of
## flat cards (the cases are little cylinders) moved here and shaped in a shader.
## The sounds are recordings (`audio/guns/`, credited in CREDITS.md there); any
## kind with no recording is made up from noise instead, so nothing is silent.

const GLOWS := 72
const MOTES := 96
const MARKS := 40
const CASES := 20
## The cartridges shown over a gun to say what is left in it.
const PIPS := 12
const SOUNDS := 8
## How long a bullet mark lasts, in seconds, and a spent case.
const MARK_LIFE := 40.0
const CASE_LIFE := 7.0

const GLOW := """
shader_type spatial;
render_mode unshaded, blend_add, depth_draw_never, cull_disabled, shadows_disabled, fog_disabled;

varying float age;
varying float seed;
varying float kind;
varying float shape;
varying vec3 tint;
varying vec2 at;

void vertex() {
	age = INSTANCE_CUSTOM.x;
	seed = INSTANCE_CUSTOM.y;
	kind = INSTANCE_CUSTOM.z;
	shape = INSTANCE_CUSTOM.w;
	tint = COLOR.rgb;
	at = VERTEX.xy * 2.0;
	vec3 centre = MODEL_MATRIX[3].xyz;
	float width = length(MODEL_MATRIX[0].xyz);
	if (kind > 0.5 && kind < 1.5) {
		// A streak: it lies along its own length, and is turned about that to face the camera.
		vec3 axis = MODEL_MATRIX[2].xyz;
		vec3 to_eye = normalize(INV_VIEW_MATRIX[3].xyz - centre);
		vec3 side = cross(axis, to_eye);
		side = dot(side, side) > 0.0000001 ? normalize(side) * width : INV_VIEW_MATRIX[0].xyz * width;
		MODELVIEW_MATRIX = VIEW_MATRIX * mat4(vec4(side, 0.0), vec4(axis, 0.0), vec4(to_eye * width, 0.0), vec4(centre, 1.0));
	} else {
		MODELVIEW_MATRIX = VIEW_MATRIX * mat4(INV_VIEW_MATRIX[0] * width, INV_VIEW_MATRIX[1] * width, INV_VIEW_MATRIX[2] * width, MODEL_MATRIX[3]);
	}
	MODELVIEW_NORMAL_MATRIX = mat3(MODELVIEW_MATRIX);
}

float cut(float value, float edge) {
	float pixel = max(fwidth(value), 0.0005);
	return smoothstep(edge - pixel, edge + pixel, value);
}

void fragment() {
	float from_middle;
	if (kind < 0.5) {
		// The flash, seen from anywhere: a ragged star.
		float around = atan(at.y, at.x);
		float spikes = pow(abs(sin(around * 2.5 + seed * 6.283)), 2.5) * (0.6 + 0.4 * sin(around * 3.0 + seed * 17.0));
		from_middle = length(at) / mix(0.24, 1.0, clamp(spikes, 0.0, 1.0));
	} else if (kind < 1.5) {
		// A streak: pointed at both ends, or (a tongue of flame) blunt where it starts.
		float along = at.y * 0.5 + 0.5;
		float wide = shape > 0.5 ? sqrt(clamp(along * 6.0, 0.0, 1.0)) * (1.0 - pow(along, 1.6)) : 1.0 - abs(at.y);
		wide *= shape > 0.5 ? 0.85 + 0.15 * sin(along * 19.0 + seed * 40.0) : 1.0;
		from_middle = abs(at.x) / max(wide, 0.0001);
	} else {
		from_middle = length(at);
	}
	float body = cut(1.0 - from_middle, 0.0);
	float core = cut((kind < 0.5 ? 0.3 : 0.45) - from_middle, 0.0);
	float soft = kind > 1.5 ? pow(clamp(1.0 - from_middle, 0.0, 1.0), 1.6) : body;
	ALBEDO = mix(tint, mix(tint, vec3(1.0), 0.75), core) * soft * (1.0 - smoothstep(0.55, 1.0, age));
}
"""

const MATTER := """
shader_type spatial;
render_mode blend_mix, depth_draw_never, cull_disabled, shadows_disabled, specular_disabled;

varying float age;
varying float seed;
varying float kind;
varying vec4 tint;
varying vec2 at;

void vertex() {
	age = INSTANCE_CUSTOM.x;
	seed = INSTANCE_CUSTOM.y;
	kind = INSTANCE_CUSTOM.z;
	tint = COLOR;
	at = VERTEX.xy * 2.0;
	if (kind < 1.5) {
		// Smoke and chips face the camera; chips tumble.
		float size = length(MODEL_MATRIX[0].xyz);
		float turn = kind > 0.5 ? seed * 40.0 + age * 14.0 * (seed - 0.5) : seed * 6.283 + age * (seed - 0.5) * 1.6;
		at = vec2(at.x * cos(turn) - at.y * sin(turn), at.x * sin(turn) + at.y * cos(turn));
		MODELVIEW_MATRIX = VIEW_MATRIX * mat4(INV_VIEW_MATRIX[0] * size, INV_VIEW_MATRIX[1] * size, INV_VIEW_MATRIX[2] * size, MODEL_MATRIX[3]);
		MODELVIEW_NORMAL_MATRIX = mat3(MODELVIEW_MATRIX);
	}
}

float cut(float value, float edge) {
	float pixel = max(fwidth(value), 0.0005);
	return smoothstep(edge - pixel, edge + pixel, value);
}

void fragment() {
	float around = atan(at.y, at.x);
	if (kind < 0.5) {
		// Smoke: a cloud with a bumpy edge, which thins from the middle as it goes.
		float rim = 0.86 + 0.08 * sin(around * 3.0 + seed * 40.0) + 0.05 * sin(around * 5.0 - seed * 23.0);
		float from_middle = length(at) / rim;
		float hole = smoothstep(0.45, 1.0, age) * 1.05;
		float body = cut(1.0 - from_middle, 0.0) * cut(from_middle, hole);
		float shade = cut(at.y - at.x * 0.4 + 0.2, 0.0);
		ALBEDO = tint.rgb * mix(0.78, 1.0, shade);
		ALPHA = body * tint.a * (1.0 - smoothstep(0.6, 1.0, age));
	} else if (kind < 1.5) {
		// A chip: a splinter with three or four corners.
		float corners = 3.0 + floor(seed * 2.0);
		float edge = cos(3.14159 / corners) / cos(mod(around + seed * 9.0, 6.28318 / corners) - 3.14159 / corners);
		ALBEDO = tint.rgb * (0.8 + 0.3 * step(0.5, fract(seed * 7.0)));
		ALPHA = cut(edge * 0.9 - length(at), 0.0) * (1.0 - smoothstep(0.8, 1.0, age));
	} else {
		// A bullet mark: a dark hole in a paler, chipped scar.
		float rim = 0.8 + 0.1 * sin(around * 5.0 + seed * 40.0) + 0.07 * sin(around * 8.0 - seed * 23.0);
		float from_middle = length(at) / rim;
		float hole = cut(0.58 - from_middle, 0.0);
		ALBEDO = mix(tint.rgb, vec3(0.03), hole);
		ALPHA = cut(1.0 - from_middle, 0.0) * mix(tint.a, 0.95, hole) * (1.0 - smoothstep(0.92, 1.0, age));
	}
}

void light() {
	DIFFUSE_LIGHT += clamp(ATTENUATION, 0.0, 1.0) * LIGHT_COLOR / PI * 0.7;
}
"""

## A flock of cards drawn as one MultiMesh. `mode`: 0 faces the camera, 1 a
## streak lying along `axis` (or along the way it is going), 2 lies flat on a
## surface whose normal is `axis`.
class Flock:
	var mesh := MultiMesh.new()
	var count := 0
	var live := 0
	var _next := 0
	var _pos := PackedVector3Array()
	var _vel := PackedVector3Array()
	var _axis := PackedVector3Array()
	var _size := PackedVector2Array()
	var _age := PackedFloat32Array()
	var _life := PackedFloat32Array()
	var _kind := PackedFloat32Array()
	var _seed := PackedFloat32Array()
	var _shape := PackedFloat32Array()
	var _fall := PackedFloat32Array()
	var _drag := PackedFloat32Array()
	var _mode := PackedByteArray()

	func _init(many: int, material: Material) -> void:
		count = many
		var card := QuadMesh.new()
		card.size = Vector2.ONE
		card.material = material
		mesh.transform_format = MultiMesh.TRANSFORM_3D
		mesh.use_custom_data = true
		mesh.use_colors = true
		mesh.mesh = card
		mesh.instance_count = many
		for list: Variant in [_pos, _vel, _axis, _size, _age, _life, _kind, _seed, _shape, _fall, _drag, _mode]:
			list.resize(many)
		_age.fill(1.0)
		for i in many:
			mesh.set_instance_transform(i, Transform3D(Basis.from_scale(Vector3.ZERO), Vector3.ZERO))

	## One more card. `size` is how big it starts and how big it ends.
	func emit(mode: int, kind: float, at: Vector3, going: Vector3, size: Vector2, life: float, colour: Color,
			axis := Vector3.ZERO, fall := 0.0, drag := 0.0, shape := 0.0, delay := 0.0) -> void:
		var i := _next
		_next = (_next + 1) % count
		if _age[i] >= 1.0:
			live += 1
		_pos[i] = at
		_vel[i] = going
		_axis[i] = axis
		_size[i] = size
		_age[i] = -delay / maxf(life, 0.001)
		_life[i] = maxf(life, 0.001)
		_kind[i] = kind
		_seed[i] = randf()
		_shape[i] = shape
		_fall[i] = fall
		_drag[i] = drag
		_mode[i] = mode
		mesh.set_instance_color(i, colour)
		if delay <= 0.0:
			_place(i)

	func step(delta: float) -> void:
		if live == 0:
			return
		for i in count:
			if _age[i] >= 1.0:
				continue
			var was := _age[i]
			_age[i] = minf(was + delta / _life[i], 1.0)
			if _age[i] >= 1.0:
				live -= 1
				mesh.set_instance_transform(i, Transform3D(Basis.from_scale(Vector3.ZERO), _pos[i]))
				continue
			if _age[i] < 0.0:
				continue
			if was >= 0.0:
				_vel[i] += Vector3.DOWN * _fall[i] * delta
				_vel[i] *= exp(-_drag[i] * delta)
				_pos[i] += _vel[i] * delta
			_place(i)

	func _place(i: int) -> void:
		var age := maxf(_age[i], 0.0)
		var size := lerpf(_size[i].x, _size[i].y, 1.0 - (1.0 - age) * (1.0 - age))
		var basis: Basis
		match _mode[i]:
			1:
				var axis := _axis[i]
				if axis == Vector3.ZERO:
					# (a spark is as long as it travels in a fortieth of a second)
					axis = _vel[i] * 0.025
					if axis.length() < size:
						axis = (axis.normalized() if axis.length() > 0.0001 else Vector3.UP) * size
				basis = Basis(Vector3.RIGHT * size, Vector3.UP * size, axis)
			2:
				var normal := _axis[i]
				var across := normal.cross(Vector3.UP if absf(normal.y) < 0.9 else Vector3.RIGHT).normalized()
				basis = Basis(across * size, normal.cross(across) * size, normal * size)
			_:
				basis = Basis.from_scale(Vector3.ONE * size)
		mesh.set_instance_transform(i, Transform3D(basis, _pos[i]))
		mesh.set_instance_custom_data(i, Color(age, _seed[i], _kind[i], _shape[i]))


static var _glow_shader: Shader
static var _matter_shader: Shader
static var _bank := {}

var _glow: Flock
var _matter: Flock
var _marks: Flock
var _dust: Dust
var _cases := MultiMesh.new()
var _case_at := PackedVector3Array()
var _case_vel := PackedVector3Array()
var _case_spin := PackedVector3Array()
var _case_turn: Array[Basis] = []
var _case_size := PackedVector2Array()
var _case_floor := PackedFloat32Array()
var _case_age := PackedFloat32Array()
var _case_bounces := PackedByteArray()
var _case_next := 0
var _cases_live := 0
var _lights: Array[OmniLight3D] = []
var _light_frames := PackedInt32Array()
var _light_next := 0
var _voices: Array[AudioStreamPlayer3D] = []
var _voice_next := 0
var _pips_of: Gun
var _pips_time := 0.0
var _pips_shown := false


## The one for the scene `node` is in.
static func of(node: Node) -> GunFX:
	var tree := node.get_tree()
	var found := tree.get_first_node_in_group(&"gun_fx") as GunFX
	if found and not found.is_queued_for_deletion():
		return found
	var made := GunFX.new()
	(tree.current_scene if tree.current_scene else tree.root).add_child(made)
	return made


func _init() -> void:
	add_to_group(&"gun_fx")
	name = "GunFX"


func _ready() -> void:
	top_level = true
	global_transform = Transform3D.IDENTITY
	if _glow_shader == null:
		_glow_shader = Shader.new()
		_glow_shader.code = GLOW
		_matter_shader = Shader.new()
		_matter_shader.code = MATTER
	var glowing := ShaderMaterial.new()
	glowing.shader = _glow_shader
	var matter := ShaderMaterial.new()
	matter.shader = _matter_shader
	_glow = Flock.new(GLOWS, glowing)
	_matter = Flock.new(MOTES, matter)
	_marks = Flock.new(MARKS, matter)
	# (marks first, so that smoke is drawn over them)
	for flock: Flock in [_marks, _matter, _glow]:
		var drawn := MultiMeshInstance3D.new()
		drawn.multimesh = flock.mesh
		drawn.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		drawn.extra_cull_margin = 16384.0
		add_child(drawn)
	_dust = Dust.new()
	add_child(_dust)

	var brass := StandardMaterial3D.new()
	brass.vertex_color_use_as_albedo = true
	brass.roughness = 0.45
	brass.metallic_specular = 0.6
	var tube := CylinderMesh.new()
	tube.top_radius = 0.5
	tube.bottom_radius = 0.5
	tube.height = 1.0
	tube.radial_segments = 6
	tube.rings = 0
	tube.material = brass
	_cases.transform_format = MultiMesh.TRANSFORM_3D
	_cases.use_colors = true
	_cases.mesh = tube
	_cases.instance_count = CASES + PIPS
	for list: Variant in [_case_at, _case_vel, _case_spin, _case_size, _case_floor, _case_age, _case_bounces]:
		list.resize(CASES)
	_case_turn.resize(CASES)
	_case_age.fill(CASE_LIFE)
	for i in CASES + PIPS:
		_cases.set_instance_transform(i, Transform3D(Basis.from_scale(Vector3.ZERO), Vector3.ZERO))
	var cases := MultiMeshInstance3D.new()
	cases.multimesh = _cases
	cases.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	cases.extra_cull_margin = 16384.0
	add_child(cases)

	for i in 2:
		var light := OmniLight3D.new()
		light.visible = false
		light.shadow_enabled = false
		light.omni_attenuation = 1.4
		add_child(light)
		_lights.append(light)
		_light_frames.append(0)
	for i in SOUNDS:
		var voice := AudioStreamPlayer3D.new()
		voice.max_db = 3.0
		voice.attenuation_filter_cutoff_hz = 20500.0
		add_child(voice)
		_voices.append(voice)


func _process(delta: float) -> void:
	_glow.step(delta)
	_matter.step(delta)
	_marks.step(delta)
	_move_cases(delta)
	_show_pips(delta)
	for i in _lights.size():
		if _lights[i].visible:
			_light_frames[i] -= 1
			if _light_frames[i] <= 0:
				_lights[i].visible = false


# --- what a gun asks for ---

## The flash at a muzzle: `muzzle` looks along -Z out of the barrel. `size` is
## 1 for a rifle. It lasts three frames, and its light two.
func flash(muzzle: Transform3D, size: float, colour := Color(1.0, 0.72, 0.3)) -> void:
	var out := -muzzle.basis.z.normalized()
	var at := muzzle.origin
	var long := 0.42 * size
	_glow.emit(0, 0.0, at + out * 0.05 * size, Vector3.ZERO, Vector2(0.34, 0.2) * size, 0.055, colour)
	_glow.emit(1, 1.0, at + out * long * 0.5, Vector3.ZERO, Vector2(0.15, 0.1) * size, 0.06, colour, out * long, 0.0, 0.0, 1.0)
	_glow.emit(0, 2.0, at + out * 0.08 * size, Vector3.ZERO, Vector2(0.5, 0.35) * size, 0.07, Color(colour.r * 0.2, colour.g * 0.17, colour.b * 0.14))
	# A few sparks of burning powder go on ahead.
	for i in int(3.0 * size) + 1:
		_glow.emit(1, 1.0, at, (out + _any() * 0.35) * randf_range(5.0, 12.0), Vector2(0.012, 0.004), randf_range(0.08, 0.2), colour, Vector3.ZERO, 6.0, 5.0)
	light(at + out * 0.25, colour, 2.0 * size, 3.5 + 3.0 * size)


## A light for a frame or two.
func light(at: Vector3, colour: Color, energy: float, reach: float, frames := 3) -> void:
	var lamp := _lights[_light_next]
	_light_frames[_light_next] = frames
	_light_next = (_light_next + 1) % _lights.size()
	lamp.global_position = at
	lamp.light_color = colour
	lamp.light_energy = energy
	lamp.omni_range = reach
	lamp.visible = true


## Smoke: `count` clouds from `at`, thrown along `going` and then drifting up.
func smoke(at: Vector3, going: Vector3, size: float, count := 1, colour := Color(0.86, 0.85, 0.82, 0.42), life := 1.4) -> void:
	for i in count:
		var share := (i + 1.0) / count
		_matter.emit(0, 0.0, at + going.normalized() * size * 0.3 * share, going * share * randf_range(0.7, 1.1) + _any() * 0.25 + Vector3.UP * 0.35,
				Vector2(size * 0.35, size * randf_range(0.6, 1.15)), life * randf_range(0.8, 1.2), colour, Vector3.ZERO, -0.25, 3.2, 0.0, i * 0.012)


## Sparks struck off something hard, thrown about `normal`.
func sparks(at: Vector3, normal: Vector3, count: int, colour := Color(1.0, 0.75, 0.35), speed := 7.0) -> void:
	for i in count:
		_glow.emit(1, 1.0, at + normal * 0.01, (normal * 0.7 + _any()).normalized() * randf_range(0.4, 1.0) * speed, Vector2(0.014, 0.004),
				randf_range(0.12, 0.34), colour, Vector3.ZERO, 14.0, 2.0)
	_glow.emit(0, 2.0, at + normal * 0.03, Vector3.ZERO, Vector2(0.22, 0.05), 0.06, colour)


## Chips knocked out of a surface.
func chips(at: Vector3, normal: Vector3, colour: Color, count: int, size := 0.03, speed := 3.2) -> void:
	for i in count:
		_matter.emit(0, 1.0, at + normal * 0.02, (normal * 0.8 + _any()).normalized() * randf_range(0.4, 1.0) * speed,
				Vector2.ONE * size * randf_range(0.6, 1.3), randf_range(0.35, 0.7), colour, Vector3.ZERO, 12.0, 1.0)


## The mark a bullet leaves in a wall. Only for things that do not move.
func mark(at: Vector3, normal: Vector3, size := 0.07, colour := Color(0.66, 0.61, 0.53, 0.6)) -> void:
	_marks.emit(2, 2.0, at + normal * 0.006, Vector3.ZERO, Vector2(size, size), MARK_LIFE, colour, normal)


## A bullet's path, drawn for two frames.
func tracer(from: Vector3, to: Vector3, colour := Color(1.0, 0.86, 0.55)) -> void:
	var path := to - from
	if path.length() < 0.6:
		return
	# (not from the muzzle itself, where the flash is, nor all the way along)
	var length := minf(path.length() - 0.4, 14.0)
	var start := from + path.normalized() * 0.4
	_glow.emit(1, 1.0, start + path.normalized() * length * 0.5, Vector3.ZERO, Vector2(0.012, 0.008), 0.04, Color(colour.r * 0.6, colour.g * 0.6, colour.b * 0.6), path.normalized() * length)


## A glowing ball: `life` seconds of it at `at`.
func glow(at: Vector3, size: float, colour: Color, life := 0.05) -> void:
	_glow.emit(0, 2.0, at, Vector3.ZERO, Vector2(size, size * 0.8), life, colour)


## A spark that drops and dies, as off a burning flare.
func ember(at: Vector3, going: Vector3, colour: Color, life := 0.5) -> void:
	_glow.emit(1, 1.0, at, going, Vector2(0.012, 0.003), life, colour, Vector3.ZERO, 7.0, 1.5)


## A spent case thrown out along `going`. `size` is its radius and its length.
func case(from: Transform3D, going: Vector3, size: Vector2, colour := Color(0.82, 0.62, 0.25)) -> void:
	var i := _case_next
	_case_next = (_case_next + 1) % CASES
	if _case_age[i] >= CASE_LIFE:
		_cases_live += 1
	_case_at[i] = from.origin
	_case_vel[i] = going
	_case_spin[i] = _any() * randf_range(8.0, 22.0)
	_case_turn[i] = from.basis.orthonormalized() * Basis(Vector3.RIGHT, PI * 0.5)
	_case_size[i] = size
	_case_age[i] = 0.0
	_case_bounces[i] = 0
	_cases.set_instance_color(i, colour)
	# Where the ground is under it, found once.
	var query := PhysicsRayQueryParameters3D.create(from.origin, from.origin + Vector3.DOWN * 6.0, 1)
	var under := get_world_3d().direct_space_state.intersect_ray(query)
	_case_floor[i] = (under.position.y if under else from.origin.y - 6.0) + size.x


## What hitting a surface looks and sounds like. `surface`: &"stone", &"sand",
## &"wood", &"metal", &"clay", &"glass" or &"soft". `marked`: leave a mark.
func impact(at: Vector3, normal: Vector3, direction: Vector3, surface: StringName, marked := true, loud := true) -> void:
	var graze := 1.0 - absf(direction.dot(normal))
	var back := (normal - direction * 0.3).normalized()
	match surface:
		&"sand":
			_dust.puff(at, normal * 1.2, 0.45, 3, 0.5)
			chips(at, normal, Color(0.86, 0.76, 0.56), 5, 0.022, 3.6)
			if loud:
				play(&"impact_stone", at, -10.0, 0.7, 0.85, 6.0)
		&"wood":
			chips(at, back, Color(0.66, 0.5, 0.32), 5, 0.03, 2.6)
			smoke(at, normal * 0.4, 0.12, 1, Color(0.8, 0.72, 0.6, 0.4), 0.5)
			if marked:
				mark(at, normal, 0.045, Color(0.74, 0.6, 0.4, 0.8))
			if loud:
				play(&"impact_wood", at, -4.0, 0.9, 1.15, 7.0)
		&"metal":
			sparks(at, back, 7)
			if loud:
				play(&"impact_metal", at, -3.0, 0.92, 1.08, 10.0)
		&"clay", &"glass":
			chips(at, back, Color(0.72, 0.45, 0.3) if surface == &"clay" else Color(0.3, 0.5, 0.36), 4, 0.03, 3.0)
		&"soft":
			_dust.puff(at, normal * 0.6, 0.22, 2, 0.4)
		_:
			_dust.puff(at, normal * 0.9, 0.3, 2, 0.4)
			chips(at, back, Color(0.6, 0.54, 0.44), 5, 0.028, 3.4)
			if marked:
				mark(at, normal, randf_range(0.06, 0.09))
			# A glancing shot strikes sparks and sings off; a square one only sometimes.
			var sings := randf() < 0.2 + graze * 0.8
			if sings:
				sparks(at, direction.bounce(normal).lerp(normal, 0.3).normalized(), 5)
			if loud:
				if sings and randf() < 0.75:
					play(&"ricochet", at, -5.0, 0.9, 1.15, 9.0)
				else:
					play(&"impact_stone", at, -5.0, 0.9, 1.12, 8.0)


## Shows what is left in `gun` for a moment: a row of cartridges over it, the
## spent ones dark and small.
func show_rounds(gun: Gun, time := 1.6) -> void:
	_pips_of = gun
	_pips_time = time


# --- sound ---

## Plays one of the takes of `kind` at `at`. `reach` is how far off it is still
## as loud as it was recorded (a shot's is long); the pitch is varied a little.
func play(kind: StringName, at: Vector3, volume_db := 0.0, pitch_low := 0.95, pitch_high := 1.05, reach := 6.0) -> AudioStreamPlayer3D:
	var found := takes(kind)
	if found.is_empty():
		return null
	var voice := _voices[_voice_next]
	_voice_next = (_voice_next + 1) % SOUNDS
	voice.stream = found[randi() % found.size()]
	voice.global_position = at
	voice.volume_db = volume_db
	voice.pitch_scale = randf_range(pitch_low, pitch_high)
	voice.unit_size = reach
	voice.play()
	return voice


## The recordings of `kind`: audio/guns/<kind>_<number>.wav, or (there being
## none) one sound made up from noise.
static func takes(kind: StringName) -> Array:
	if _bank.has(kind):
		return _bank[kind]
	var found := []
	for number in range(1, 9):
		var path := "res://audio/guns/%s_%d.wav" % [kind, number]
		if not ResourceLoader.exists(path):
			break
		var stream := load(path) as AudioStream
		if stream:
			found.append(stream)
	if found.is_empty():
		found.append(synthesised(kind))
	_bank[kind] = found
	return found


## Whether `kind` has a recording, or is made up.
static func is_recorded(kind: StringName) -> bool:
	return ResourceLoader.exists("res://audio/guns/%s_1.wav" % kind)


## A stand-in for a recording: bursts of noise and ringing tones.
static func synthesised(kind: String) -> AudioStreamWAV:
	const RATE := 22050
	var random := RandomNumberGenerator.new()
	random.seed = hash(kind)
	var length := 0.12
	# Each layer: [starts at, cutoff of its noise (0: a tone), pitch of its tone, dies away in, how loud, pitch it slides to]
	var layers: Array = []
	if kind.begins_with("shot_"):
		var deep: float = {"shot_revolver": 0.45, "shot_rifle": 0.3, "shot_shotgun": 0.8, "shot_flare": 1.0}.get(kind, 0.5)
		length = 0.9
		layers = [[0.0, lerpf(9000.0, 2200.0, deep), 0.0, 0.03 + 0.05 * deep, 1.0], [0.0, 0.0, 95.0 - 35.0 * deep, 0.09, 0.9],
				[0.012, 800.0, 0.0, 0.28, 0.3]]
		if kind == "shot_flare":
			layers.append([0.03, 6000.0, 0.0, 0.35, 0.25])
	else:
		match kind:
			"dry":
				layers = [[0.0, 6000.0, 0.0, 0.004, 1.0], [0.0, 0.0, 2600.0, 0.012, 0.5]]
			"cock":
				length = 0.16
				layers = [[0.0, 5000.0, 0.0, 0.004, 0.7], [0.0, 0.0, 1900.0, 0.01, 0.4], [0.07, 6000.0, 0.0, 0.004, 1.0], [0.07, 0.0, 2400.0, 0.012, 0.5]]
			"round_in":
				layers = [[0.0, 4000.0, 0.0, 0.006, 1.0], [0.0, 0.0, 900.0, 0.02, 0.6]]
			"break_open":
				length = 0.25
				layers = [[0.0, 5000.0, 0.0, 0.005, 0.8], [0.0, 0.0, 1400.0, 0.015, 0.5], [0.09, 3000.0, 0.0, 0.01, 1.0], [0.09, 0.0, 600.0, 0.03, 0.5]]
			"break_close":
				length = 0.2
				layers = [[0.0, 3200.0, 0.0, 0.01, 1.0], [0.0, 0.0, 480.0, 0.035, 0.8], [0.0, 0.0, 2100.0, 0.012, 0.3]]
			"cycle_bolt":
				length = 0.7
				for start: float in [0.0, 0.13, 0.4, 0.52]:
					layers.append([start, 5200.0, 0.0, 0.006, 1.0])
					layers.append([start, 0.0, 1500.0 + start * 900.0, 0.016, 0.5])
				layers.append([0.03, 2400.0, 0.0, 0.07, 0.22])
				layers.append([0.3, 2400.0, 0.0, 0.07, 0.22])
			"shell":
				length = 0.4
				layers = [[0.0, 0.0, 5200.0, 0.05, 1.0], [0.0, 0.0, 6900.0, 0.04, 0.6], [0.13, 0.0, 5350.0, 0.04, 0.5], [0.21, 0.0, 5300.0, 0.03, 0.25]]
			"ricochet":
				length = 0.7
				layers = [[0.0, 5000.0, 0.0, 0.01, 1.0], [0.0, 0.0, 3400.0, 0.2, 0.7, 1300.0], [0.0, 0.0, 5150.0, 0.12, 0.25, 2000.0]]
			"impact_stone":
				length = 0.3
				layers = [[0.0, 3500.0, 0.0, 0.025, 1.0], [0.0, 800.0, 0.0, 0.08, 0.6]]
			"impact_wood":
				length = 0.25
				layers = [[0.0, 0.0, 240.0, 0.04, 1.0], [0.0, 2000.0, 0.0, 0.012, 0.6]]
			"impact_metal":
				length = 1.0
				layers = [[0.0, 0.0, 640.0, 0.4, 0.8], [0.0, 0.0, 1490.0, 0.3, 0.6], [0.0, 0.0, 2410.0, 0.2, 0.4], [0.0, 0.0, 3530.0, 0.12, 0.3], [0.0, 6000.0, 0.0, 0.004, 0.8]]
			"break_pot", "break_glass":
				length = 0.7
				var glass := kind == "break_glass"
				layers = [[0.0, 2500.0 if not glass else 7000.0, 0.0, 0.05, 1.0]]
				for i in 8:
					var start := random.randf_range(0.0, 0.3)
					layers.append([start, 0.0, random.randf_range(4000.0, 8000.0) if glass else random.randf_range(1500.0, 3200.0), 0.025, 0.5])
					layers.append([start, 6000.0, 0.0, 0.004, 0.5])
			"flare_burn":
				length = 2.0
				layers = [[0.0, 6500.0, 0.0, 1000.0, 1.0], [0.0, 900.0, 0.0, 1000.0, 0.5]]
			"pickup":
				length = 0.3
				for start: float in [0.0, 0.06, 0.15]:
					layers.append([start, 4000.0, 0.0, 0.006, 0.8])
					layers.append([start, 0.0, 1500.0, 0.015, 0.5])
			_:
				layers = [[0.0, 5000.0, 0.0, 0.005, 1.0]]
	var count := int(length * RATE)
	var wave := PackedFloat32Array()
	wave.resize(count)
	for layer: Array in layers:
		var begin := int(layer[0] * RATE)
		var cutoff: float = layer[1]
		var keep := 1.0 - exp(-TAU * cutoff / RATE)
		var held := 0.0
		var phase := 0.0
		var slide_to: float = layer[5] if layer.size() > 5 else layer[2]
		for n in range(begin, count):
			var t := float(n - begin) / RATE
			var loud: float = layer[4] * exp(-t / layer[3])
			if loud < 0.0005:
				break
			if cutoff > 0.0:
				held += (random.randf_range(-1.0, 1.0) - held) * keep
				wave[n] += held * loud
			else:
				phase += TAU * lerpf(layer[2], slide_to, minf(t / (layer[3] * 2.0), 1.0)) / RATE
				wave[n] += sin(phase) * loud
	var peak := 0.001
	for value in wave:
		peak = maxf(peak, absf(value))
	var fade := mini(int(0.02 * RATE), count / 4)
	var data := PackedByteArray()
	data.resize(count * 2)
	for n in count:
		var value := wave[n] / peak * 0.8 * minf(float(count - n) / fade, 1.0)
		data.encode_s16(n * 2, int(clampf(value, -1.0, 1.0) * 32767.0))
	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = RATE
	stream.data = data
	if kind == "flare_burn":
		stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
		stream.loop_end = count
	return stream


# --- the cases ---

func _move_cases(delta: float) -> void:
	if _cases_live == 0:
		return
	for i in CASES:
		if _case_age[i] >= CASE_LIFE:
			continue
		_case_age[i] += delta
		if _case_age[i] >= CASE_LIFE:
			_cases_live -= 1
			_cases.set_instance_transform(i, Transform3D(Basis.from_scale(Vector3.ZERO), _case_at[i]))
			continue
		if _case_bounces[i] < 3:
			_case_vel[i] += Vector3.DOWN * 16.0 * delta
			_case_at[i] += _case_vel[i] * delta
			var spin := _case_spin[i]
			if spin.length() > 0.01:
				_case_turn[i] = Basis(spin.normalized(), spin.length() * delta) * _case_turn[i]
			if _case_at[i].y < _case_floor[i] and _case_vel[i].y < 0.0:
				_case_at[i].y = _case_floor[i]
				_case_bounces[i] += 1
				if _case_bounces[i] == 1:
					play(&"shell", _case_at[i], -8.0, 0.9, 1.15, 4.0)
				_case_vel[i] = Vector3(_case_vel[i].x * 0.5, -_case_vel[i].y * 0.36, _case_vel[i].z * 0.5)
				_case_spin[i] *= 0.5
				if _case_bounces[i] >= 3 or absf(_case_vel[i].y) < 0.5:
					# It lies on its side.
					_case_bounces[i] = 3
					var along := _case_turn[i].y
					along = Vector3(along.x, 0.0, along.z)
					along = along.normalized() if along.length() > 0.01 else Vector3.RIGHT
					_case_turn[i] = Basis(along.cross(Vector3.UP), along, Vector3.UP)
		# (it shrinks away at the last)
		var size := _case_size[i] * minf((CASE_LIFE - _case_age[i]) * 2.0, 1.0)
		_cases.set_instance_transform(i, Transform3D(_case_turn[i] * Basis.from_scale(Vector3(size.x * 2.0, size.y, size.x * 2.0)), _case_at[i]))


func _show_pips(delta: float) -> void:
	if _pips_time <= 0.0 or not is_instance_valid(_pips_of):
		if _pips_shown:
			_pips_shown = false
			for i in PIPS:
				_cases.set_instance_transform(CASES + i, Transform3D(Basis.from_scale(Vector3.ZERO), Vector3.ZERO))
		return
	_pips_time -= delta
	_pips_shown = true
	var gun := _pips_of
	var camera := get_viewport().get_camera_3d()
	var across := camera.global_basis.x if camera else Vector3.RIGHT
	var shown := mini(gun.capacity, PIPS)
	var size := Vector2(0.009, 0.03)
	var gap := size.x * 3.2
	# (they rise into place, and sink away)
	var up := 0.34 + 0.05 * minf(_pips_time * 5.0, 1.0)
	var grown := clampf(_pips_time * 6.0, 0.0, 1.0)
	for i in PIPS:
		if i >= shown:
			_cases.set_instance_transform(CASES + i, Transform3D(Basis.from_scale(Vector3.ZERO), Vector3.ZERO))
			continue
		var left := i < gun.rounds
		var at := gun.global_position + Vector3.UP * up + across * (i - (shown - 1) * 0.5) * gap
		var each := grown * (1.0 if left else 0.55)
		_cases.set_instance_transform(CASES + i, Transform3D(Basis.from_scale(Vector3(size.x * 2.0, size.y, size.x * 2.0) * each), at))
		_cases.set_instance_color(CASES + i, gun.shell_colour if left else Color(0.12, 0.11, 0.1))


static func _any() -> Vector3:
	return Vector3(randf_range(-1.0, 1.0), randf_range(-1.0, 1.0), randf_range(-1.0, 1.0))
