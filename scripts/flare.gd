class_name Flare
extends Node3D
## A flare in flight, as a signal pistol throws it: a ball of red fire that
## arcs across a room, bounces off what it hits, comes to rest and burns for a
## few seconds, lighting everything round it, with smoke and dropping sparks.
## A `Gun` whose `fires_flare` is set makes these; one can also be made alone:
##
##     var flare := Flare.new()
##     flare.velocity = direction * flare.speed
##     add_child(flare)
##     flare.global_position = from
##
## It is in the groups `flares` and `interest` (the boy looks at it). What it
## strikes is told as a bullet's target is (see `scripts/gun.gd`), once.

signal burnt_out

## How fast it leaves the pistol, in metres a second.
@export var speed := 24.0
## How long it burns, and how long it takes to die at the end, in seconds.
@export var burn_time := 9.0
@export var fade_time := 1.2
@export var colour := Color(1.0, 0.36, 0.24)
@export var light_energy := 5.0
## How far its light reaches, in metres.
@export var light_range := 18.0
## Its light casts shadows. They are dear on a phone, and they swing as it flies.
@export var shadows := false
@export var damage := 15.0
@export var force := 3.0
@export_flags_3d_physics var hit_mask := 0xFFFFFFFF
## No more than this many burn at once: the oldest goes out.
const MOST := 3
const FALL := 5.5

var velocity := Vector3.ZERO
var shooter: Node3D
var gun: Node3D

var _age := 0.0
var _resting := false
var _light: OmniLight3D
var _hiss: AudioStreamPlayer3D
var _trail := 0.0
var _struck := false
var _spared: Array[RID] = []


func _ready() -> void:
	add_to_group(&"flares")
	add_to_group(&"interest")
	var burning := get_tree().get_nodes_in_group(&"flares")
	if burning.size() > MOST:
		(burning[0] as Flare).put_out()
	_light = OmniLight3D.new()
	_light.light_color = colour.lerp(Color(1.0, 0.9, 0.8), 0.4)
	_light.light_energy = light_energy
	_light.omni_range = light_range
	_light.omni_attenuation = 1.2
	_light.shadow_enabled = shadows
	# (it lies on the floor: the light is lifted a little, so that the floor is lit)
	_light.position.y = 0.25
	add_child(_light)
	_hiss = AudioStreamPlayer3D.new()
	_hiss.stream = GunFX.takes(&"flare_burn")[0]
	_hiss.unit_size = 5.0
	_hiss.volume_db = -8.0
	_hiss.max_db = 0.0
	add_child(_hiss)
	_hiss.play()
	# (a recording with no loop of its own goes round again)
	_hiss.finished.connect(_hiss.play)
	for holder: Node3D in [shooter, gun]:
		if holder is CollisionObject3D:
			_spared.append((holder as CollisionObject3D).get_rid())
		if holder:
			for part: CollisionObject3D in holder.find_children("*", "CollisionObject3D", true, false):
				_spared.append(part.get_rid())


## Puts it out now (it dies away over `fade_time`).
func put_out() -> void:
	_age = maxf(_age, burn_time)


func _physics_process(delta: float) -> void:
	if _resting:
		return
	velocity += Vector3.DOWN * FALL * delta
	var step := velocity * delta
	# (whoever fired it is in its way only at first)
	var query := PhysicsRayQueryParameters3D.create(global_position, global_position + step + step.normalized() * 0.05, hit_mask,
			_spared if _age < 0.3 else ([] as Array[RID]))
	var found := get_world_3d().direct_space_state.intersect_ray(query)
	if found.is_empty():
		global_position += step
		return
	var fx := GunFX.of(self)
	var what := found.collider as Node3D
	var way := velocity.normalized()
	if not _struck:
		_struck = true
		var loose := what as RigidBody3D
		if loose and not loose.freeze:
			loose.sleeping = false
			loose.apply_impulse(way * force, found.position - loose.global_position)
		Gun.tell(Gun.recipient(what), shooter, found.position, way, damage, way * force)
	fx.sparks(found.position, found.normal, 6, colour.lerp(Color.WHITE, 0.3), 4.0)
	global_position = found.position + found.normal * 0.06
	velocity = velocity.bounce(found.normal) * 0.28
	if velocity.length() < 1.6:
		if found.normal.y > 0.5:
			_resting = true
			velocity = Vector3.ZERO
		else:
			# (it drops from a wall)
			velocity = found.normal * 0.6


func _process(delta: float) -> void:
	_age += delta
	var left := 1.0 - clampf((_age - burn_time) / fade_time, 0.0, 1.0)
	if left <= 0.0:
		burnt_out.emit()
		queue_free()
		return
	# It sputters: never still, and never the same twice.
	var waver := 0.82 + 0.1 * sin(_age * 31.0) + 0.08 * sin(_age * 47.3 + 1.7) + randf_range(-0.06, 0.06)
	_light.light_energy = light_energy * waver * left
	_hiss.volume_db = -8.0 + linear_to_db(maxf(left, 0.01))
	var fx := GunFX.of(self)
	var at := global_position
	fx.glow(at, 0.5 * waver * left, Color(colour.r * 0.55, colour.g * 0.55, colour.b * 0.55), 0.018)
	fx.glow(at, 0.16 * left, colour.lerp(Color.WHITE, 0.7), 0.018)
	_trail -= delta
	if _trail <= 0.0:
		_trail = 0.07 if not _resting else 0.16
		fx.smoke(at + Vector3.UP * 0.05, Vector3.UP * 0.5 - velocity * 0.03, 0.22 if not _resting else 0.3, 1,
				Color(0.9, 0.78, 0.74, 0.3 * left), 1.6)
		fx.ember(at, GunFX._any() * 1.2 + Vector3.UP * 1.2 - velocity * 0.1, colour.lerp(Color(1.0, 0.8, 0.5), 0.5), randf_range(0.3, 0.6))
