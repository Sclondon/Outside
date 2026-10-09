class_name Gun
extends RigidBody3D
## A gun: something to pick up (it is in the groups `throwable`, `interest` and
## `guns`) that shoots when whoever holds it calls `fire`. The scenes in
## `guns/` are these: `revolver`, `rifle`, `shotgun`, `flare_pistol`.
##
## The body's origin is at the grip; the barrel points along its -Z and its top
## is +Y. Held, it is frozen and has no collision, and whoever holds it sets
## its transform every frame; nothing here depends on its own physics then.
##
##     if gun.fire(self, aim):        # aim: a direction in the world
##         ...                        # it went off (and `fired` was emitted)
##
## `fire` is refused (false) while the gun is cycling or being reloaded, and
## when it is empty, which clicks instead and, with `auto_reload`, starts the
## reload. A gun works its own action: `cycled` is emitted when it is ready
## again after a shot, `reloaded` when it has been filled from `reserve`.
##
## WHAT IS HIT. A shot is a ray from the muzzle (a flare is a thing that flies:
## `scripts/flare.gd`). Whatever it finds:
##
## - a RigidBody3D that is not frozen is given an impulse where it was hit;
## - the collider, or the nearest node above it (up to four) that has one of
##   these methods, has it called, once for each pull of the trigger however
##   many pellets found it:
##
##       func shot(by: Node3D, at: Vector3, direction: Vector3, damage: float) -> void
##
##   `by` is whoever fired (it may be null), `at` where the first of it struck,
##   in the world, `direction` the way the shot was travelling (a unit
##   vector), and `damage` the sum of what struck: a revolver's bullet is 35, a
##   rifle's 80, each of a shotgun's eight pellets 12, a flare 15. Failing
##   that, `struck(by: Node3D, impulse: Vector3)`, which is what a punch or a
##   kick calls too (`scripts/brother.gd`), with the impulse of the shot;
## - the surface is marked, chipped and dusted by `GunFX`, according to what it
##   is: the metadata `surface` on the collider or the node that took the shot
##   (&"stone", &"sand", &"wood", &"metal", &"clay", &"glass", &"soft"), or else a
##   guess: sand for the terrain, soft for a creature, wood for anything loose,
##   stone for the rest.

## It went off. (`kick` says how hard it kicks.)
signal fired
## The action has been worked and it is ready to fire again.
signal cycled
signal reload_started
## It has been filled.
signal reloaded
## The trigger was pulled on nothing.
signal dry_fired
## Something was hit: the collider, and where.
signal hit(what: Node3D, at: Vector3)

enum State { READY, CYCLING, RELOADING }
enum Eject { NEVER, ON_CYCLE, ON_RELOAD }

## Which gun this is: it picks the sound of its shot (`shot_<kind>`).
@export var kind: StringName = &"revolver"
## Held in both hands (the off hand at `support_point`), or in one.
@export var two_handed := false
## How hard it kicks: about 0.3 for a small pistol, 1 for a rifle, more for a big bore.
@export var kick := 0.5

@export_group("Ammunition")
## What is in it now, and what it holds.
@export var rounds := 6
@export var capacity := 6
## Spare rounds that come with it (-1: without end). `reload` fills from these.
@export var reserve := 18
## What it takes: an `AmmoBox` fills only guns of its own kind (or any, if it has none).
@export var ammo: StringName = &"pistol"
## Pulling the trigger on an empty gun starts the reload.
@export var auto_reload := true

@export_group("Shooting")
## Seconds from one shot to the next: the action being worked.
@export var cycle_time := 0.45
## The gun works its own action after a shot. Off, it waits for `cycle()`.
@export var auto_cycle := true
## Seconds to reload.
@export var reload_time := 2.6
## What each bullet or pellet does to what it hits (see `shot` above).
@export var damage := 35.0
## How far it reaches, in metres.
@warning_ignore("shadowed_global_identifier")
@export var range := 60.0
## How far a shot may stray from where it is aimed, in degrees.
@export var spread := 1.5
## How many it throws at once (a shotgun).
@export var pellets := 1
## The push each gives a loose thing, in newton seconds.
@export var force := 5.0
## It fires a flare (a `Flare`, which flies and burns) and not a bullet.
@export var fires_flare := false
## What a shot can hit.
@export_flags_3d_physics var hit_mask := 0xFFFFFFFF

@export_group("Looks")
## How big the flash is (1: a rifle's) and how much smoke it makes.
@export var flash := 1.0
@export var smoke := 1.0
## Draw the path of the shot for two frames.
@export var tracer := true
## When the spent cases come out.
@export var eject := Eject.NEVER
## A case's radius and length, in metres, and its colour.
@export var shell_size := Vector2(0.006, 0.02)
@export var shell_colour := Color(0.82, 0.62, 0.25)
## How far it breaks open to be loaded, in degrees (0: it does not).
@export var break_angle := 0.0
## How far apart its barrels are, if it has two.
@export var barrel_gap := 0.0
## Show what is left in it, as a row of cartridges over it, when it is picked up, fired or filled.
@export var show_rounds := true

const METALS: PackedStringArray = ["gunmetal", "steel", "steel_bright", "brass", "iron", "tin"]
## How far back the bolt is drawn, in metres, and how far it is turned up.
const BOLT_TRAVEL := 0.075
const BOLT_LIFT := 1.05

var state := State.READY
## How far through working the action it is, and through reloading: 0 to 1 (1 when it is not).
var cycle_progress := 1.0
var reload_progress := 1.0

static var _materials := {}

var _timer := 0.0
var _events: Array = []
var _spent := 0
var _full_reserve := 0
var _smoking := 0.0
var _puff := 0.0
var _dry_wait := 0.0
var _was_held := false
var _waiting := false
var _barrel: Node3D
var _bolt: Node3D
var _barrel_rest := Transform3D.IDENTITY
var _bolt_rest := Transform3D.IDENTITY
var _muzzle: Node3D
var _support: Node3D
var _eject: Node3D


func _ready() -> void:
	for group: StringName in [&"throwable", &"interest", &"guns"]:
		add_to_group(group)
	_full_reserve = reserve
	_muzzle = get_node_or_null(^"Muzzle")
	_support = get_node_or_null(^"Support")
	_eject = get_node_or_null(^"Eject")
	var model := get_node_or_null(^"Model")
	if model:
		dress(model)
		_barrel = model.get_node_or_null(^"Barrel")
		_bolt = model.get_node_or_null(^"Bolt")
		if _barrel:
			_barrel_rest = _barrel.transform
		if _bolt:
			_bolt_rest = _bolt.transform


# --- for whoever holds it ---

## Where the muzzle is, in the world, looking out of the barrel along its -Z.
func muzzle() -> Transform3D:
	var place := _muzzle.global_transform if _muzzle else global_transform.translated_local(Vector3(0.0, 0.05, -0.2))
	if barrel_gap > 0.0:
		# (the right barrel first, then the left)
		place = place.translated_local(Vector3((0.5 if rounds % 2 == 0 else -0.5) * barrel_gap, 0.0, 0.0))
	return place


## Where the off hand holds a two-handed gun: the fore-end, in the world.
func support_point() -> Vector3:
	return _support.global_position if _support else global_transform * Vector3(0.0, 0.0, -0.3)


func can_fire() -> bool:
	return state == State.READY and rounds > 0


## Pulls the trigger. `shooter` is whoever holds it (not hit by the shot, and
## passed on to whatever is); `aim` is the way to shoot, in the world. False if
## nothing went off.
func fire(shooter: Node3D, aim: Vector3) -> bool:
	if state != State.READY:
		return false
	if rounds <= 0:
		_click()
		return false
	var out := muzzle()
	aim = aim.normalized() if aim.length_squared() > 0.000001 else -out.basis.z.normalized()
	rounds -= 1
	_spent += 1
	var fx := GunFX.of(self)
	var along := -out.basis.z.normalized()
	# (the flash comes out of the barrel, unless that is pointing nowhere near)
	var shown := out if along.dot(aim) > 0.8 else Transform3D(Basis.looking_at(aim, Vector3.UP if absf(aim.y) < 0.99 else Vector3.RIGHT), out.origin)
	if fires_flare:
		fx.flash(shown, flash, Color(1.0, 0.5, 0.35))
		_launch_flare(shooter, out.origin, aim)
	else:
		fx.flash(shown, flash)
		_shoot(shooter, out.origin, aim, fx)
	fx.smoke(out.origin, aim * 2.2 * smoke, 0.3 * smoke, int(3.0 * smoke) + 1)
	fx.play(StringName("shot_%s" % kind), out.origin, 0.0, 0.96, 1.05, 30.0)
	_smoking = 0.9
	if not freeze:
		# Nobody has hold of it: it jumps.
		apply_impulse(-aim * kick * 1.2 * mass + Vector3.UP * kick * 0.6 * mass, out.origin - global_position)
	if show_rounds:
		fx.show_rounds(self)
	state = State.CYCLING
	cycle_progress = 0.0
	_events.clear()
	if _bolt:
		_events.append([0.22, &"sound", &"cycle_bolt"])
	if eject == Eject.ON_CYCLE:
		_events.append([0.45, &"eject", 1])
	fired.emit()
	_waiting = not auto_cycle
	return true


## Works the action after a shot, for a gun whose `auto_cycle` is off.
func cycle() -> void:
	_waiting = false


## Fills it from `reserve`. False if there is no need, or nothing to fill it with.
func reload() -> bool:
	if state == State.RELOADING or rounds >= capacity or reserve == 0:
		return false
	state = State.RELOADING
	cycle_progress = 1.0
	reload_progress = 0.0
	_waiting = false
	var going_in := capacity - rounds if reserve < 0 else mini(capacity - rounds, reserve)
	var pitch := 1.0
	_events.clear()
	if _bolt:
		_events.append([0.0, &"sound", &"cycle_bolt"])
		# (in chargers of five)
		going_in = ceili(going_in / 5.0)
	else:
		_events.append([0.02, &"sound", &"break_open"])
	if eject == Eject.ON_RELOAD and _spent > 0:
		_events.append([0.2, &"eject", _spent])
	for i in mini(going_in, 6):
		_events.append([lerpf(0.36, 0.78, i / maxf(mini(going_in, 6) - 1.0, 1.0)) if going_in > 1 else 0.55, &"sound", &"round_in", pitch])
		pitch += 0.03
	_events.append([0.88, &"sound", &"break_close"])
	_events.sort_custom(func(a: Array, b: Array) -> bool: return a[0] < b[0])
	reload_started.emit()
	return true


## Gives it `count` spare rounds (0: as many as it came with), and loads it if
## it is empty. Returns how many it took. An `AmmoBox` calls this.
func take_ammo(count := 0) -> int:
	var taken := 0
	if reserve >= 0:
		var to := _full_reserve + (capacity - rounds) if count <= 0 else reserve + count
		taken = maxi(to - reserve, 0)
		reserve += taken
	if show_rounds and taken > 0:
		GunFX.of(self).show_rounds(self)
	if rounds <= 0 and state == State.READY:
		reload()
	return taken


## Whether somebody has hold of it.
func is_held() -> bool:
	return freeze and collision_layer == 0


# --- its own workings ---

func _process(delta: float) -> void:
	_dry_wait = maxf(_dry_wait - delta, 0.0)
	if show_rounds and is_held() != _was_held:
		_was_held = is_held()
		if _was_held:
			GunFX.of(self).show_rounds(self, 2.2)
	if _smoking > 0.0:
		# Smoke goes on curling out of the barrel for a moment.
		_smoking -= delta
		_puff -= delta
		if _puff <= 0.0 and smoke > 0.0:
			_puff = 0.09
			var out := muzzle()
			GunFX.of(self).smoke(out.origin, -out.basis.z.normalized() * 0.25, 0.1 * smoke * (0.5 + _smoking), 1, Color(0.86, 0.85, 0.82, 0.32 * minf(_smoking * 2.0, 1.0)), 1.1)
	match state:
		State.CYCLING:
			if not _waiting:
				cycle_progress = minf(cycle_progress + delta / maxf(cycle_time, 0.01), 1.0)
			_run_events(cycle_progress)
			_pose_bolt(_bolt_curve(cycle_progress))
			if cycle_progress >= 1.0:
				state = State.READY
				cycled.emit()
		State.RELOADING:
			reload_progress = minf(reload_progress + delta / maxf(reload_time, 0.01), 1.0)
			_run_events(reload_progress)
			var open := smoothstep(0.0, 0.16, reload_progress) * (1.0 - smoothstep(0.86, 0.97, reload_progress))
			if _barrel and break_angle > 0.0:
				_barrel.transform = _barrel_rest * Transform3D(Basis(Vector3.RIGHT, -deg_to_rad(break_angle) * open), Vector3.ZERO)
			_pose_bolt(Vector2(minf(open * 2.0, 1.0), clampf(open * 2.0 - 1.0, 0.0, 1.0)))
			if reload_progress >= 1.0:
				var going_in := capacity - rounds if reserve < 0 else mini(capacity - rounds, reserve)
				rounds += going_in
				if reserve > 0:
					reserve -= going_in
				_spent = 0
				state = State.READY
				if show_rounds:
					GunFX.of(self).show_rounds(self)
				reloaded.emit()


## The trigger pulled on nothing.
func _click() -> void:
	if _dry_wait > 0.0:
		return
	_dry_wait = 0.3
	GunFX.of(self).play(&"dry", global_position, -6.0, 0.95, 1.08, 3.0)
	if show_rounds:
		GunFX.of(self).show_rounds(self, 1.0)
	dry_fired.emit()
	if auto_reload:
		reload()


func _run_events(progress: float) -> void:
	while not _events.is_empty() and _events[0][0] <= progress:
		var event: Array = _events.pop_front()
		var fx := GunFX.of(self)
		match event[1]:
			&"sound":
				var pitch: float = event[3] if event.size() > 3 else 1.0
				fx.play(event[2], global_position, -6.0, 0.96 * pitch, 1.04 * pitch, 3.5)
			&"eject":
				var from := _eject.global_transform if _eject else global_transform
				for i in int(event[2]):
					# Out to the right and up from a bolt; back over the hand from a gun broken open.
					var way := (global_basis.x * 1.6 + global_basis.y * 1.4 + global_basis.z * 0.4) if eject == Eject.ON_CYCLE \
							else (global_basis.z * 0.7 + global_basis.y * 0.3 + global_basis.x * randf_range(-0.6, 0.6))
					fx.case(from, way * randf_range(0.8, 1.2) + linear_velocity, shell_size, shell_colour)


## How far the bolt is turned up and drawn back (each 0 to 1) through a shot:
## nothing while the gun kicks, then up, back, forward and down.
func _bolt_curve(progress: float) -> Vector2:
	var up := smoothstep(0.2, 0.34, progress) * (1.0 - smoothstep(0.84, 0.98, progress))
	var back := smoothstep(0.32, 0.52, progress) * (1.0 - smoothstep(0.6, 0.84, progress))
	return Vector2(up, back)


func _pose_bolt(how: Vector2) -> void:
	if _bolt:
		_bolt.transform = _bolt_rest * Transform3D(Basis(Vector3.BACK, BOLT_LIFT * how.x), Vector3.BACK * BOLT_TRAVEL * how.y)


func _shoot(shooter: Node3D, from: Vector3, aim: Vector3, fx: GunFX) -> void:
	var space := get_world_3d().direct_space_state
	var spared: Array[RID] = [get_rid()]
	if shooter:
		if shooter is CollisionObject3D:
			spared.append((shooter as CollisionObject3D).get_rid())
		for part: CollisionObject3D in shooter.find_children("*", "CollisionObject3D", true, false):
			spared.append(part.get_rid())
	# A barrel poked through a wall shoots the wall.
	var query := PhysicsRayQueryParameters3D.create(global_position, from, hit_mask, spared)
	var blocked := space.intersect_ray(query)
	# What was hit, and how much of the shot found it: the node that will be told is the key.
	var told := {}
	var across := aim.cross(Vector3.UP if absf(aim.y) < 0.95 else Vector3.RIGHT).normalized()
	var over := across.cross(aim)
	for pellet in pellets:
		var stray := tan(deg_to_rad(spread)) * sqrt(randf())
		var turn := randf() * TAU
		var way := (aim + (across * cos(turn) + over * sin(turn)) * stray).normalized()
		var found := blocked
		if found.is_empty():
			query = PhysicsRayQueryParameters3D.create(from, from + way * range, hit_mask, spared)
			found = space.intersect_ray(query)
		if found.is_empty():
			if tracer:
				fx.tracer(from, from + way * minf(range, 40.0))
			continue
		if tracer:
			fx.tracer(from, found.position)
		var what := found.collider as Node3D
		var loose := what as RigidBody3D
		if loose and not loose.freeze:
			loose.sleeping = false
			loose.apply_impulse(way * force, found.position - loose.global_position)
		var listener := recipient(what)
		var key: Node = listener if listener else what
		if told.has(key):
			told[key].damage += damage
			told[key].impulse += way * force
		else:
			told[key] = {"listener": listener, "at": found.position, "way": way, "damage": damage, "impulse": way * force}
		# (a shotgun's pattern is seen and marked pellet by pellet, but heard once)
		var surface := surface_of(what, listener)
		fx.impact(found.position, found.normal, way, surface, what is StaticBody3D, told[key].damage == damage)
		hit.emit(what, found.position)
	for key: Node in told:
		tell(told[key].listener, shooter, told[key].at, told[key].way, told[key].damage, told[key].impulse)


## Tells `listener` it has been shot (see the top of this file).
static func tell(listener: Node, by: Node3D, at: Vector3, way: Vector3, harm: float, impulse: Vector3) -> void:
	if listener == null:
		return
	if listener.has_method(&"shot"):
		listener.call(&"shot", by, at, way, harm)
	elif listener.has_method(&"struck"):
		listener.call(&"struck", by, impulse)


## The node that is told when `what` is hit: itself, or the nearest above it
## (up to four) with a `shot` or a `struck`.
static func recipient(what: Node) -> Node:
	var node := what
	for i in 5:
		if node == null:
			break
		if node.has_method(&"shot") or node.has_method(&"struck"):
			return node
		node = node.get_parent()
	return null


## What `what` is made of, for the look and sound of hitting it.
static func surface_of(what: Node, listener: Node = null) -> StringName:
	if what.has_meta(&"surface"):
		return what.get_meta(&"surface")
	if listener and listener.has_meta(&"surface"):
		return listener.get_meta(&"surface")
	if what.is_in_group(&"terrain") or what.is_in_group(&"sand_grounds"):
		return &"sand"
	if what is CharacterBody3D or what.is_in_group(&"pursuers"):
		return &"soft"
	if what is RigidBody3D:
		return &"wood"
	return &"stone"


func _launch_flare(shooter: Node3D, from: Vector3, aim: Vector3) -> void:
	var flare := Flare.new()
	flare.shooter = shooter
	flare.gun = self
	flare.velocity = aim * flare.speed
	flare.damage = damage
	flare.force = force
	flare.hit_mask = hit_mask
	GunFX.of(self).get_parent().add_child(flare)
	flare.global_position = from


## Shades a gun's model: its metal with a little shine, the rest as the props are.
static func dress(model: Node) -> void:
	for part: MeshInstance3D in model.find_children("*", "MeshInstance3D", true, false):
		if part.mesh == null:
			continue
		for surface in part.mesh.get_surface_count():
			var original := part.mesh.surface_get_material(surface) as StandardMaterial3D
			if original == null:
				continue
			var label := original.resource_name
			if label not in METALS:
				part.set_surface_override_material(surface, Prop.material(label, original.albedo_color))
				continue
			var key := "%s %s" % [label, Settings.world_banded]
			if not _materials.has(key):
				var made := Toon.surface(original.albedo_color)
				if made is ShaderMaterial:
					made.set_shader_parameter(&"highlight", 0.3)
					made.set_shader_parameter(&"gloss", 14.0)
				elif made is StandardMaterial3D:
					made.roughness = 0.42
					made.metallic_specular = 0.7
				_materials[key] = made
			part.set_surface_override_material(surface, _materials[key])
