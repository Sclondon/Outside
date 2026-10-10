class_name OilJar
extends Breakable
## A jar of lamp oil: a clay jar with two ears and a rag stopper, dark where
## the oil has run down it. It is a loose thing like any pot (he picks it up
## with act and throws it with act; duck and act puts it down), and it is a
## `Breakable`: thrown, dropped from a height, shot or kicked, it smashes, and
## what was in it is a puddle (`Oil.spill`). `OilJar.new()` is a whole one, its
## origin at its foot.
##
## TO POUR, he ducks with it in his hands: it tips over, and oil runs from it
## for as long as he stays down, in a trail if he moves (sneaking) and a
## growing puddle if he does not. It holds `measures`, about a metre of trail
## to every four or five; what is left is shown over it while he pours. An
## empty jar is only a jar.
##
## IT BURSTS if the oil it stands in burns (it is in the group `kindling`, and
## `Oil` tells it: `kindle`): after `cooks_for` it breaks and everything in it
## is alight at once. Shot with a flare it does the same. A jar that is broken
## or empty is whole and full again where it began when he starts again.

## Oil has run out of it (`left` is what it still holds).
signal poured(left: int)

## How much it holds: each measure is one patch of oil.
@export var measures := 40
## How long burning oil has to be at it before it bursts, in seconds.
@export var cooks_for := 0.9
## How far he has to move, pouring, for each measure (m), and how long each
## takes to run out where he stands still (s).
@export var pour_every := 0.22
@export var pour_takes := 0.28

const CLAY := Color(0.7, 0.44, 0.28)
const STAIN := Color(0.22, 0.14, 0.085)
const RAG := Color(0.76, 0.69, 0.54)
const TALL := 0.46
## How far it tips to pour, and how long it takes to.
const TIPS := 1.85
const TIP_TIME := 0.35
## The side of it, from its foot up: how far out, how high.
const SIDE: Array[Vector2] = [
	Vector2(0.06, 0.0), Vector2(0.085, 0.015), Vector2(0.125, 0.1), Vector2(0.15, 0.2), Vector2(0.148, 0.27),
	Vector2(0.12, 0.335), Vector2(0.075, 0.375), Vector2(0.055, 0.395), Vector2(0.052, 0.425), Vector2(0.07, 0.445),
	Vector2(0.07, 0.458), Vector2(0.045, 0.458),
]
const ROUND := 12

const GAUGE := """
shader_type spatial;
render_mode unshaded, blend_mix, depth_draw_never, depth_test_disabled, cull_disabled, shadows_disabled, fog_disabled;

// How full, 0..1, and how much of it shows.
uniform float level = 1.0;
uniform float shown = 1.0;
uniform vec3 full : source_color = vec3(0.93, 0.66, 0.16);
uniform vec3 line : source_color = vec3(1.0, 0.97, 0.9);

void vertex() {
	float big = length(MODEL_MATRIX[0].xyz);
	MODELVIEW_MATRIX = VIEW_MATRIX * mat4(INV_VIEW_MATRIX[0] * big, INV_VIEW_MATRIX[1] * big, INV_VIEW_MATRIX[2] * big, MODEL_MATRIX[3]);
}

float cut(float value, float edge) {
	float pixel = max(fwidth(value), 0.0005);
	return smoothstep(edge - pixel, edge + pixel, value);
}

void fragment() {
	// A drop: round below, drawn up to a point.
	vec2 at = vec2(UV.x * 2.0 - 1.0, 1.0 - UV.y * 2.0);
	float narrow = mix(1.0, 0.0, smoothstep(-0.25, 0.92, at.y));
	float inside = 0.62 * (at.y < -0.25 ? 1.0 : narrow) - length(vec2(at.x, min(at.y + 0.25, 0.0)));
	float drop = cut(inside, 0.0);
	float rim = drop - cut(inside, 0.11);
	float filled = cut(mix(-0.9, 0.92, level), at.y) * step(0.001, level);
	ALBEDO = mix(mix(vec3(0.08, 0.06, 0.05), full, filled), line, rim);
	ALPHA = drop * mix(0.55, 1.0, max(filled, rim)) * shown;
}
"""

## What it still holds.
var left := 0
## Who has it in his hands, if anyone.
var holder: Node3D

var _model: Node3D
var _tip := 0.0
var _last_drop := Vector3.INF
var _since_drop := 0.0
var _cooking := -1.0
var _afire := false
var _gauge: MeshInstance3D
var _gauge_material: ShaderMaterial
var _gauge_shown := 0.0
var _gauge_time := 0.0
var _stream: MeshInstance3D
var _boy: Player

static var _mesh: ArrayMesh
static var _gauge_shader: Shader


func _init() -> void:
	mass = 2.0
	gravity_scale = 2.0
	angular_damp = 2.0
	break_speed = 6.5
	pieces = 6
	# (broken, it waits to be made whole when he starts again: see `_renew`)
	comes_back = -1.0


func _ready() -> void:
	left = measures
	add_to_group(&"kindling")
	_model = Node3D.new()
	_model.name = "Model"
	var jar := MeshInstance3D.new()
	jar.mesh = _jar()
	_model.add_child(jar)
	add_child(_model)
	var shape := CylinderShape3D.new()
	shape.radius = 0.14
	shape.height = TALL
	var collider := CollisionShape3D.new()
	collider.shape = shape
	collider.position.y = TALL * 0.5
	add_child(collider)
	super._ready()

	# What is left in it, over it; and the oil running from it.
	if _gauge_shader == null:
		_gauge_shader = Shader.new()
		_gauge_shader.code = GAUGE
	_gauge_material = ShaderMaterial.new()
	_gauge_material.shader = _gauge_shader
	_gauge_material.render_priority = 4
	var card := QuadMesh.new()
	card.size = Vector2(2.0, 2.0)
	_gauge = MeshInstance3D.new()
	_gauge.mesh = card
	_gauge.material_override = _gauge_material
	_gauge.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_gauge.top_level = true
	_gauge.visible = false
	add_child(_gauge)
	var thread := CylinderMesh.new()
	thread.top_radius = 0.011
	thread.bottom_radius = 0.016
	thread.height = 1.0
	thread.radial_segments = 5
	thread.rings = 1
	_stream = MeshInstance3D.new()
	_stream.mesh = thread
	_stream.material_override = Toon.surface(STAIN.darkened(0.45))
	_stream.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_stream.top_level = true
	_stream.visible = false
	add_child(_stream)
	_meet_the_boy.call_deferred()


## Whoever picks it up says so (see `Player._take`), and again, with nobody, on letting go.
func taken_by(who: Node3D) -> void:
	holder = who
	_last_drop = Vector3.INF
	if who:
		_gauge_time = 2.5


## Whether oil is running from it now.
func is_pouring() -> bool:
	return holder != null and left > 0 and _tip > 0.85


## Burning oil is at it (`Oil` says so): if there is oil in it, it will burst.
func kindle(_by: Node3D = null) -> void:
	if left > 0 and not is_broken and _cooking < 0.0:
		_cooking = cooks_for


func shot(by: Node3D, at: Vector3, direction: Vector3, damage: float) -> void:
	# (a flare that hits it sets light to what comes out)
	for flare: Node in get_tree().get_nodes_in_group(&"flares"):
		if flare is Node3D and (flare as Node3D).global_position.distance_to(at) < 1.0:
			_afire = true
	super.shot(by, at, direction, damage)


## Breaks it: what it held is a puddle where it broke, and burning if it burst.
func shatter(push := Vector3.ZERO, at := Vector3.INF, by: Node3D = null) -> void:
	if is_broken:
		return
	var held := left
	left = 0
	_cooking = -1.0
	_stream.visible = false
	_gauge.visible = false
	if held > 0:
		Oil.of(self).spill(global_position + Vector3.UP * 0.1, held, linear_velocity + push, _afire)
		if _afire:
			var fx := GunFX.of(self)
			var middle := global_position + Vector3.UP * 0.3
			fx.light(middle, Color(1.0, 0.62, 0.25), 6.0, 12.0, 8)
			fx.glow(middle, 1.6, Color(1.0, 0.55, 0.15), 0.16)
			fx.glow(middle, 0.7, Color(1.0, 0.9, 0.6), 0.12)
			fx.sparks(middle, Vector3.UP, 26, Color(1.0, 0.7, 0.3), 8.0)
			fx.smoke(middle, Vector3.UP * 1.6, 0.9, 4, Color(0.16, 0.14, 0.13, 0.55), 1.8)
			fx.play(&"shot_flare", middle, -6.0, 0.55, 0.7, 10.0)
	_afire = false
	super.shatter(push, at, by)


## Whole again where it began, and full.
func mend() -> void:
	left = measures
	_cooking = -1.0
	_afire = false
	_tip = 0.0
	super.mend()


func _physics_process(delta: float) -> void:
	super._physics_process(delta)
	if is_broken:
		return
	if _cooking >= 0.0:
		# It smokes, and then it goes.
		_cooking -= delta
		if Engine.get_physics_frames() % 5 == 0:
			GunFX.of(self).smoke(global_position + Vector3.UP * TALL, Vector3.UP * 0.9, 0.3, 1, Color(0.2, 0.18, 0.17, 0.5), 0.8)
		if _cooking < 0.0:
			_afire = true
			shatter(Vector3.UP * 2.5)
			return
	var tipping := holder != null and left > 0 and bool(holder.get(&"is_ducking")) and not bool(holder.get(&"is_limp"))
	_tip = move_toward(_tip, 1.0 if tipping else 0.0, delta / TIP_TIME)
	if not is_pouring():
		_last_drop = Vector3.INF
		_since_drop = 0.0
		return
	# Oil runs from its mouth: a measure for every so far he moves, or every so often where he stays.
	var mouth := _mouth()
	_since_drop += delta
	var moved := INF if _last_drop == Vector3.INF else Vector2(mouth.x - _last_drop.x, mouth.z - _last_drop.z).length()
	if moved < pour_every and _since_drop < pour_takes:
		return
	# (and the faster he goes the thinner it is laid)
	if Oil.of(self).pour(mouth, 0.2):
		left -= 1
		poured.emit(left)
	_last_drop = mouth
	_since_drop = 0.0
	_gauge_time = 1.6


func _process(delta: float) -> void:
	if is_broken:
		return
	var carried := holder != null
	# In his hands it is held by its neck, upright, turned the way he faces,
	# and tipped forward to pour. (Where it is, is his doing: see `Player._place_carried`.)
	_model.position.y = move_toward(_model.position.y, -0.3 if carried else 0.0, delta * 1.5)
	if carried:
		var yaw: float = holder.get(&"facing_yaw") if holder.get(&"facing_yaw") != null else holder.global_rotation.y
		var eased := _tip * _tip * (3.0 - 2.0 * _tip)
		global_basis = Basis(Vector3.UP, yaw) * Basis(Vector3.RIGHT, eased * TIPS)
	# The thread of oil from its mouth to the ground.
	var running := is_pouring()
	if running:
		var mouth := _mouth()
		var long := 0.9
		var spared: Array[RID] = [get_rid()]
		var found := get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(mouth, mouth + Vector3.DOWN * 3.0, 1, spared))
		if not found.is_empty():
			long = mouth.y - (found.position as Vector3).y
		var sway := Vector3(sin(Time.get_ticks_msec() * 0.011), 0.0, cos(Time.get_ticks_msec() * 0.013)) * 0.012
		_stream.global_transform = Transform3D(Basis.from_scale(Vector3(1.0, maxf(long, 0.05), 1.0)), mouth + Vector3.DOWN * long * 0.5 + sway)
	_stream.visible = running
	# What is left, shown while he pours and for a moment after he takes it up.
	_gauge_time -= delta
	_gauge_shown = move_toward(_gauge_shown, 1.0 if carried and _gauge_time > 0.0 else 0.0, delta * 4.0)
	_gauge.visible = _gauge_shown > 0.01
	if _gauge.visible:
		_gauge.global_transform = Transform3D(Basis.from_scale(Vector3.ONE * 0.11), global_position + Vector3.UP * 0.62)
		_gauge_material.set_shader_parameter(&"level", float(left) / maxf(measures, 1.0))
		_gauge_material.set_shader_parameter(&"shown", _gauge_shown)


# Where its mouth is.
func _mouth() -> Vector3:
	return _model.global_transform * Vector3(0.0, TALL, 0.0)


# When he starts again, a jar that is broken or spent is whole and full where it began.
func _meet_the_boy() -> void:
	if not is_inside_tree():
		return
	_boy = Nearby.player(get_tree())
	if _boy:
		_boy.respawned.connect(_renew)
	else:
		get_tree().node_added.connect(_notice)


func _notice(node: Node) -> void:
	if node is Player and _boy == null:
		_boy = node
		_boy.respawned.connect(_renew)
		get_tree().node_added.disconnect(_notice)


func _renew() -> void:
	if is_broken:
		mend()
	elif left < measures and holder == null:
		left = measures
		global_transform = _home
		linear_velocity = Vector3.ZERO
		angular_velocity = Vector3.ZERO


# The jar itself: turned on a wheel, with two ears, a rag in its mouth, and
# the oil that has run down from its lip. Made once.
static func _jar() -> ArrayMesh:
	if _mesh:
		return _mesh
	var tools := {}
	for label: String in ["clay", "stain", "rag"]:
		var tool := SurfaceTool.new()
		tool.begin(Mesh.PRIMITIVE_TRIANGLES)
		tools[label] = tool
	var random := RandomNumberGenerator.new()
	random.seed = 7
	# How far down each side of it the oil has run (in rings of its side, from the lip).
	var runs := PackedInt32Array()
	for s in ROUND:
		runs.append(3 + (random.randi() % 4 if s % 3 != 1 else 0))
	var last := SIDE.size() - 1
	for j in last:
		for s in ROUND:
			var label := "stain" if j >= last - runs[s] else "clay"
			var tool: SurfaceTool = tools[label]
			var corners := [_on_side(j, s), _on_side(j, s + 1), _on_side(j + 1, s + 1), _on_side(j + 1, s)]
			if j == last - runs[s] - 1:
				# (each run of it ends in a point: the facet below is cut in three, the middle one dark)
				var low: Vector3 = ((corners[0][0] as Vector3) + (corners[1][0] as Vector3)) * 0.5
				var faces: Vector3 = ((corners[0][1] as Vector3) + (corners[1][1] as Vector3)).normalized()
				low = low.lerp(((corners[2][0] as Vector3) + (corners[3][0] as Vector3)) * 0.5, 0.25)
				corners.append([low, faces])
				for corner: int in [4, 2, 3]:
					(tools["stain"] as SurfaceTool).set_normal(corners[corner][1])
					(tools["stain"] as SurfaceTool).add_vertex(corners[corner][0])
				for corner: int in [0, 4, 3, 0, 1, 4, 4, 1, 2]:
					tool.set_normal(corners[corner][1])
					tool.add_vertex(corners[corner][0])
				continue
			for corner: int in [0, 1, 2, 0, 2, 3]:
				tool.set_normal(corners[corner][1])
				tool.add_vertex(corners[corner][0])
	# Its foot, and the rag in its mouth.
	for s in ROUND:
		var a := TAU * s / ROUND
		var b := TAU * (s + 1) / ROUND
		var foot: SurfaceTool = tools["clay"]
		for corner: Vector3 in [Vector3.ZERO, Vector3(cos(b), 0.0, sin(b)) * SIDE[0].x, Vector3(cos(a), 0.0, sin(a)) * SIDE[0].x]:
			foot.set_normal(Vector3.DOWN)
			foot.add_vertex(corner)
		var rag: SurfaceTool = tools["rag"]
		var rim := SIDE[last]
		var low := [Vector3(cos(a) * rim.x, rim.y, sin(a) * rim.x), Vector3(cos(b) * rim.x, rim.y, sin(b) * rim.x)]
		var high := [Vector3(cos(a) * 0.036, rim.y + 0.035, sin(a) * 0.036), Vector3(cos(b) * 0.036, rim.y + 0.035, sin(b) * 0.036)]
		var top := Vector3(0.0, rim.y + 0.045, 0.0)
		for corner: Vector3 in [low[0], low[1], high[1], low[0], high[1], high[0], high[0], high[1], top]:
			rag.set_normal((Vector3(corner.x, 0.0, corner.z).normalized() + Vector3.UP * (0.4 if corner.y < rim.y + 0.03 else 1.6)).normalized())
			rag.add_vertex(corner)
	# Its ears: a loop of clay each side, from the shoulder to the neck.
	for side: float in [-1.0, 1.0]:
		var path: Array[Vector3] = []
		for point: Vector2 in [Vector2(0.118, 0.325), Vector2(0.158, 0.36), Vector2(0.162, 0.4), Vector2(0.125, 0.432), Vector2(0.06, 0.428)]:
			path.append(Vector3(point.x * side, point.y, 0.0))
		for n in path.size() - 1:
			var along := (path[n + 1] - path[n]).normalized()
			var before := along if n == 0 else (path[n + 1] - path[n - 1]).normalized()
			var after := along if n == path.size() - 2 else (path[n + 2] - path[n]).normalized()
			for k in 5:
				var rings := []
				for end: Array in [[path[n], before, k], [path[n], before, k + 1], [path[n + 1], after, k + 1], [path[n + 1], after, k]]:
					var way: Vector3 = end[1]
					var out := (Vector3.BACK * cos(TAU * end[2] / 5.0) + way.cross(Vector3.BACK).normalized() * sin(TAU * end[2] / 5.0))
					rings.append([end[0] + out * 0.015, out])
				var ear: SurfaceTool = tools["clay"]
				for corner: int in ([0, 1, 2, 0, 2, 3] if side > 0.0 else [0, 2, 1, 0, 3, 2]):
					ear.set_normal(rings[corner][1])
					ear.add_vertex(rings[corner][0])
	_mesh = ArrayMesh.new()
	for label: String in tools:
		# (named and coloured as a model's materials are, for `Prop.dress` to reshade)
		var material := StandardMaterial3D.new()
		material.resource_name = label
		material.albedo_color = {"clay": CLAY, "stain": STAIN, "rag": RAG}[label]
		(tools[label] as SurfaceTool).set_material(material)
		(tools[label] as SurfaceTool).commit(_mesh)
	return _mesh


# A point on its side and which way the clay faces there: ring `j` of `SIDE`, and `s` of `ROUND` round it.
static func _on_side(j: int, s: int) -> Array:
	var a := TAU * (s % ROUND) / ROUND
	var here := SIDE[j]
	var slope := SIDE[mini(j + 1, SIDE.size() - 1)] - SIDE[maxi(j - 1, 0)]
	var out := Vector2(slope.y, -slope.x).normalized()
	return [Vector3(cos(a) * here.x, here.y, sin(a) * here.x), Vector3(cos(a) * out.x, out.y, sin(a) * out.x)]
