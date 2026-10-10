class_name Breakable
extends RigidBody3D
## Something that smashes when it is shot or hit hard: a pot, a jar, a bottle.
## It is a loose thing like any other until then (he can pick it up and throw
## it: it is in `throwable` and `interest`). The scenes `guns/target_pot`,
## `target_jar`, `target_jackal`, `bottle` and `tin_can` are these; the first
## three wear the models of the props `pot`, `jar_canopic` and
## `jar_canopic_jackal`.
##
## The pieces are cut out of the model itself, whatever it is: its triangles
## are dealt into a few wedges round its middle, upper and lower, and each
## wedge becomes a loose shard that lies about for a few seconds. Nothing has
## to be modelled broken.

signal shattered(by: Node3D)

## How much it takes (see `shot` in `scripts/gun.gd`): 1 is anything at all.
@export var toughness := 1.0
## About how many pieces it breaks into.
@export_range(2, 8) var pieces := 6
## It also breaks if it hits something at this speed, in metres a second (0: only when shot).
@export var break_speed := 0.0
## What it is made of: the sound it makes (`break_<this>`) and the colour of its dust.
@export var made_of: StringName = &"pot"
## How long the pieces lie there, in seconds.
@export var pieces_last := 6.0
## It is back, whole, where it began after this long (0: it is gone for good;
## under 0: it stays as it is, broken, until something calls `mend`).
@export var comes_back := 0.0
## It only dents and jumps (a tin can).
@export var unbreakable := false

var is_broken := false

var _harm := 0.0
var _home := Transform3D.IDENTITY
var _layers := Vector2i.ZERO
var _speed := 0.0


func _ready() -> void:
	add_to_group(&"throwable")
	add_to_group(&"interest")
	set_meta(&"surface", &"metal" if unbreakable else (&"glass" if made_of == &"glass" else &"clay"))
	_home = global_transform
	var model := get_node_or_null(^"Model")
	if model:
		Prop.dress(model, 70.0, false)
	if break_speed > 0.0:
		contact_monitor = true
		max_contacts_reported = 2
		body_entered.connect(_on_knock)


func _physics_process(_delta: float) -> void:
	# (how fast it was going before whatever it has just hit stopped it)
	_speed = linear_velocity.length()


## It has been shot (the contract in `scripts/gun.gd`).
func shot(by: Node3D, at: Vector3, direction: Vector3, damage: float) -> void:
	_harm += damage
	if unbreakable or _harm < toughness:
		return
	shatter(direction * clampf(damage * 0.08, 1.5, 6.0), at, by)


## It has been punched or kicked.
func struck(by: Node3D, impulse: Vector3) -> void:
	if not unbreakable:
		shatter(impulse / maxf(mass, 0.5) * 0.4, global_position, by)


func _on_knock(_other: Node) -> void:
	if not is_broken and not unbreakable and not freeze and _speed >= break_speed:
		shatter(linear_velocity * 0.4, global_position, null)


## Breaks it. `push` is the speed the pieces are sent off at, over their own scatter.
func shatter(push := Vector3.ZERO, at := Vector3.INF, by: Node3D = null) -> void:
	if is_broken:
		return
	is_broken = true
	var fx := GunFX.of(self)
	var middle := global_position
	fx.play(StringName("break_%s" % made_of), middle, -2.0, 0.92, 1.1, 8.0)
	var dust := Color(0.3, 0.5, 0.36) if made_of == &"glass" else Color(0.72, 0.45, 0.3)
	fx.chips(middle, Vector3.UP, dust, 8, 0.035, 3.5)
	if made_of != &"glass":
		fx.smoke(middle, Vector3.UP * 0.6, 0.35, 2, Color(0.8, 0.66, 0.52, 0.4), 0.8)
	var model := get_node_or_null(^"Model") as Node3D
	if model:
		for shard in _shards(model):
			get_parent().add_child(shard)
			shard.global_transform = global_transform * shard.transform
			var out := shard.global_position - middle
			out = out.normalized() if out.length() > 0.001 else Vector3.UP
			shard.linear_velocity = linear_velocity + push * randf_range(0.5, 1.0) + out * randf_range(1.2, 2.6) + Vector3.UP * randf_range(0.5, 2.0)
			shard.angular_velocity = GunFX._any() * 9.0
			_fade(shard)
		model.visible = false
	_layers = Vector2i(collision_layer, collision_mask)
	collision_layer = 0
	collision_mask = 0
	freeze = true
	remove_from_group(&"throwable")
	remove_from_group(&"interest")
	shattered.emit(by)
	if comes_back > 0.0:
		await get_tree().create_timer(comes_back).timeout
		mend()
	elif comes_back == 0.0:
		# (whoever may be holding it lets go of nothing: it is only hidden until its pieces are gone)
		await get_tree().create_timer(pieces_last + 1.0).timeout
		queue_free()


## Whole again, where it began.
func mend() -> void:
	if not is_broken:
		return
	is_broken = false
	_harm = 0.0
	add_to_group(&"throwable")
	add_to_group(&"interest")
	collision_layer = _layers.x
	collision_mask = _layers.y
	global_transform = _home
	linear_velocity = Vector3.ZERO
	angular_velocity = Vector3.ZERO
	freeze = false
	var model := get_node_or_null(^"Model") as Node3D
	if model:
		model.visible = true
	GunFX.of(self)._dust.puff(_home.origin, Vector3.UP * 0.4, 0.4, 2, 0.5)


func _fade(shard: RigidBody3D) -> void:
	var tween := shard.create_tween()
	tween.tween_interval(pieces_last * randf_range(0.8, 1.0))
	tween.tween_property(shard.get_child(0), ^"scale", Vector3.ONE * 0.01, 0.5)
	tween.tween_callback(shard.queue_free)


## Cuts the model into loose shards, each placed in this body's own space.
func _shards(model: Node3D) -> Array[RigidBody3D]:
	var wedges := maxi(ceili(pieces / 2.0), 1)
	var turned := randf() * TAU
	# Every triangle of the model, in this body's space, with its material.
	var corners: Array[PackedVector3Array] = []
	var materials: Array[Material] = []
	var low := INF
	var high := -INF
	for part: MeshInstance3D in model.find_children("*", "MeshInstance3D", true, false):
		if part.mesh == null:
			continue
		var place := global_transform.affine_inverse() * part.global_transform
		for surface in part.mesh.get_surface_count():
			var arrays := part.mesh.surface_get_arrays(surface)
			var points: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
			var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX] if arrays[Mesh.ARRAY_INDEX] != null else PackedInt32Array()
			var material := part.get_surface_override_material(surface)
			if material == null:
				material = part.mesh.surface_get_material(surface)
			var count := indices.size() if not indices.is_empty() else points.size()
			for i in range(0, count - 2, 3):
				var triangle := PackedVector3Array()
				for k in 3:
					triangle.append(place * points[indices[i + k] if not indices.is_empty() else i + k])
					low = minf(low, triangle[k].y)
					high = maxf(high, triangle[k].y)
				corners.append(triangle)
				materials.append(material)
	# Dealt out by where each lies: which wedge round the middle, and upper or lower.
	var split := lerpf(low, high, randf_range(0.4, 0.6))
	var wedge_of := PackedInt32Array()
	var middles := {}
	for i in corners.size():
		var centre := (corners[i][0] + corners[i][1] + corners[i][2]) / 3.0
		var wedge := int(fposmod(atan2(centre.x, centre.z) + turned, TAU) / TAU * wedges) + (wedges if centre.y > split else 0)
		wedge_of.append(wedge)
		if not middles.has(wedge):
			middles[wedge] = [Vector3.ZERO, 0]
		middles[wedge][0] += centre
		middles[wedge][1] += 1
	var shards: Array[RigidBody3D] = []
	for wedge: int in middles:
		var centre: Vector3 = middles[wedge][0] / middles[wedge][1]
		# One surface for each material in it.
		var tools := {}
		for i in corners.size():
			if wedge_of[i] != wedge:
				continue
			if not tools.has(materials[i]):
				var fresh := SurfaceTool.new()
				fresh.begin(Mesh.PRIMITIVE_TRIANGLES)
				fresh.set_material(materials[i])
				tools[materials[i]] = fresh
			var tool: SurfaceTool = tools[materials[i]]
			var normal := (corners[i][2] - corners[i][0]).cross(corners[i][1] - corners[i][0]).normalized()
			# (both faces, so that the inside of a shard is not seen through)
			for corner: int in [0, 1, 2]:
				tool.set_normal(normal)
				tool.add_vertex(corners[i][corner] - centre)
			for corner: int in [0, 2, 1]:
				tool.set_normal(-normal)
				tool.add_vertex(corners[i][corner] - centre - normal * 0.002)
		var mesh := ArrayMesh.new()
		for material: Variant in tools:
			(tools[material] as SurfaceTool).commit(mesh)
		var visual := MeshInstance3D.new()
		visual.mesh = mesh
		visual.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		var bounds := mesh.get_aabb()
		var box := BoxShape3D.new()
		box.size = (bounds.size * 0.7).max(Vector3.ONE * 0.03)
		var collider := CollisionShape3D.new()
		collider.shape = box
		collider.position = bounds.get_center()
		var shard := RigidBody3D.new()
		shard.mass = 0.2
		shard.gravity_scale = 2.0
		# (the pieces lie on the world, and nothing else minds them: bullets pass, and so does he)
		shard.collision_layer = 0
		shard.collision_mask = 1
		shard.add_child(visual)
		shard.add_child(collider)
		shard.position = centre
		shards.append(shard)
	return shards
