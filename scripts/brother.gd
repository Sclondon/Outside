class_name Brother
extends Figure
## The boy's older brother: sixteen or seventeen, a head taller, in long
## trousers and braces. He goes where the boy goes, a few paces behind: walking
## while the boy is near, running to catch up when he is left behind, and
## standing to watch him when he has come close enough.
##
## Like any Figure he builds everything he needs, so in a level:
##     var brother := Brother.new()
##     brother.position = Vector3(-2, 0, 0)
##     add_child(brother)
##     brother.follow(player)
## With nobody to follow he is a plain Figure, and can be sent about with go_to().
## His model is made by tools/build_brother.py, and his own moves are drawn in
## scripts/brother_rig.gd.
##
## He fights. `punch()` throws a left hook; called again before it is over, or
## within `combo_window` of its ending, it goes on to a right hook, then an
## uppercut, then a kick. `kick()` is the kick by itself. Each emits
## `blow_landed` as it lands, with whatever it hit.
##
## And he gives the boy a leg up. `brace()` has him bend over where he stands,
## hands on his knees and his back flat; `brace_at()` sends him somewhere to do
## it; `stand()` gets him up again. His back is then something to stand on, and
## when whoever he follows jumps from it he heaves, and they go `boost_height`
## higher than a jump from the ground would have taken them. Left to himself he
## does this unasked: see `brace_at_walls` and `brace_on_duck`.

## A blow has landed: which (one of BrotherRig.BLOWS), and the bodies it met,
## which may be none at all.
signal blow_landed(blow: StringName, hit: Array[Node3D])
## He is down and set, and his back can be stood on.
signal braced
## He has thrown `who` up off his back.
signal boosted(who: Node3D)

enum Doing {
	FOLLOWING, ## As a Figure: following, standing by, or going where he was sent.
	FIGHTING, ## Throwing a blow, or with his guard up after one.
	GOING_TO_BRACE, ## On his way to where he will brace.
	BRACED, ## Bent over, to be climbed on.
	HEAVING, ## Throwing the boy up, and then watching him go.
}

const MODEL := preload("res://models/brother.glb")
const MODEL_LOW := preload("res://models/brother_lo.glb")
## Where each blow lands, from his feet: how far in front of him, how high, and
## how near to that a body has to be to be hit.
const REACH: Array[Vector3] = [Vector3(0.6, 1.2, 0.5), Vector3(0.6, 1.2, 0.5), Vector3(0.55, 1.2, 0.5), Vector3(0.85, 0.7, 0.55)]
## The size of his back as something to stand on, across and along, and where
## its middle is ahead of his feet.
const BACK := Vector3(0.52, 0.0, 0.62)
const BACK_AHEAD := -0.14

## Nearer to whoever he follows than this, he stands and faces him.
@export var near := 2.2
## Having stopped, he does not set off again until he is this far behind, so
## that he is not forever starting and stopping at the boy's heels.
@export var slack := 3.2
## Further behind than this, he runs.
@export var far := 6.0
## How quickly he turns to face him while standing.
@export var watch_rate := 4.0
## He does not try to walk to someone this far above or below him.
@export var out_of_reach := 1.4

@export_group("Fighting")
## How long after a blow `punch()` still goes on to the next, rather than starting again.
@export var combo_window := 0.45
## How long he keeps his guard up after his last blow.
@export var guard_time := 0.9
## How fast a punch, and a kick, send a loose thing flying, m/s.
@export var punch_power := 5.0
@export var kick_power := 8.5
## Nothing is knocked about as if it weighed more than this, kg: a punch does
## not send a stone block across the room.
@export var heaviest := 12.0

@export_group("Bracing")
## How much higher than a jump from the ground a jump from his back goes, m.
@export var boost_height := 1.2
## How high his back is to stand on, m.
@export var back_height := 0.9
## When whoever he follows stands still for `brace_delay` facing a wall whose
## top is too high for a jump to catch but not for a boost, he goes and braces at the foot of it.
@export var brace_at_walls := true
## When whoever he follows stands still and ducks, within `summon_range` of
## him, he comes and braces in front of them.
@export var brace_on_duck := true
@export var brace_delay := 0.6
@export var summon_range := 8.0
## Braced unasked, he gets up again when they have gone this far off.
@export var give_up_distance := 3.5

## Whoever he follows: the Player, or any Node3D. Null, and he stays where he is put.
var target: Node3D
## Whether he is on his way to him just now, rather than standing by.
var following := false
var doing := Doing.FOLLOWING

var _running := false
## The blow he is throwing (an index into BrotherRig.BLOWS; -1 for none), how
## long he has been at it, whether it has landed yet, and which comes next if
## asked for (-1: none has been).
var _blow := -1
var _blow_time := 0.0
var _landed := false
var _queued := -1
## The blow a punch would go on to, and how long since the last one ended.
var _next := 0
var _rested := 0.0
## What he is fighting, if he knows: he turns to it.
var _foe: Node3D
## Bracing: which way he faces to do it, how long he has been down, whether it
## was his own idea, and the body that is his back.
var _brace_yaw := 0.0
var _brace_time := 0.0
var _unasked := false
var _back: StaticBody3D
var _back_shape: CollisionShape3D
var _back_solid := false
var _heave_time := 0.0
## How long whoever he follows has stood still, where they were when he set off
## to brace for them, and how long until he will think of it again.
var _waited := 0.0
var _asked_from := Vector3.ZERO
var _going_time := 0.0
var _patience := 0.0
var _look_in := 0.0


func _init() -> void:
	super()
	model = MODEL
	model_low = MODEL_LOW
	# He is modelled, as every figure is, about as tall as the boy, and stands 1.6 m in his cap.
	size = 1.25
	height = 1.6
	radius = 0.24
	# A longer stride than the boy's (who walks at 1.6 and sprints at 5.6), so
	# that he gains on him at either pace.
	walk_speed = 1.8
	run_speed = 5.8
	acceleration = 9.0
	turn_rate = 7.0
	# Older, and holds himself together better than the boy does.
	looseness = 0.7


func _new_rig() -> CharacterRig:
	return BrotherRig.new()


func _ready() -> void:
	super()
	# His back, while he is braced: a block the world's own layer, so that the
	# Player stands on it (and catches the edge of it, and climbs onto it) as
	# on anything else. It is there only while he is down.
	_back = StaticBody3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(BACK.x, back_height, BACK.z)
	_back_shape = CollisionShape3D.new()
	_back_shape.shape = box
	_back_shape.position = Vector3(0.0, back_height * 0.5, BACK_AHEAD)
	_back_shape.disabled = true
	_back.add_child(_back_shape)
	_back.collision_layer = 1
	_back.collision_mask = 0
	add_child(_back)
	add_collision_exception_with(_back)


## Sets him following `who` (null: he stops where he is).
func follow(who: Node3D) -> void:
	if is_instance_valid(target) and target.has_signal(&"jumped") and target.is_connected(&"jumped", _on_target_jumped):
		target.disconnect(&"jumped", _on_target_jumped)
	target = who
	if who == null:
		following = false
		_running = false
		stop()
	elif who.has_signal(&"jumped"):
		who.connect(&"jumped", _on_target_jumped)


# --- Fighting ---

## Throws a punch: a left hook, or, called again while that is being thrown or
## just after, the next of left hook, right hook, uppercut, kick. With `at`, he
## turns to it as he does; without, to the nearest of the group `pursuers` that
## is close.
func punch(at: Node3D = null) -> void:
	if _blow >= 0:
		_queued = (_blow + 1) % BrotherRig.BLOWS.size()
		_foe = at if at else _foe
	else:
		_throw(_next if doing == Doing.FIGHTING and _rested <= combo_window else 0, at)


## Kicks: straight out in front of him, with the flat of his boot.
func kick(at: Node3D = null) -> void:
	if _blow >= 0:
		_queued = 3
		_foe = at if at else _foe
	else:
		_throw(3, at)


## Whether he is in the middle of a blow.
func is_striking() -> bool:
	return _blow >= 0


func _throw(blow: int, at: Node3D = null) -> void:
	if doing == Doing.GOING_TO_BRACE or doing == Doing.BRACED or doing == Doing.HEAVING:
		_set_back(false)
	doing = Doing.FIGHTING
	stop()
	following = false
	_blow = blow
	_blow_time = 0.0
	_landed = false
	_queued = -1
	if at:
		_foe = at
	elif not is_instance_valid(_foe) or _foe.global_position.distance_to(global_position) > 3.0:
		_foe = null
		var nearest := 3.0
		for pursuer: Node in get_tree().get_nodes_in_group(&"pursuers"):
			var body := pursuer as Node3D
			if body and body != self and body.global_position.distance_to(global_position) < nearest:
				nearest = body.global_position.distance_to(global_position)
				_foe = body


func _fight(delta: float) -> void:
	if _blow < 0:
		_rested += delta
		if _rested > guard_time:
			doing = Doing.FOLLOWING
			_foe = null
		return
	var takes := BrotherRig.TAKES[_blow]
	_blow_time += delta
	var through := _blow_time / takes
	if not _landed and through >= BrotherRig.CONTACT[_blow]:
		_landed = true
		_strike(_blow)
	if _queued >= 0 and through >= BrotherRig.CHAIN[_blow]:
		_throw(_queued)
	elif through >= 1.0:
		_next = (_blow + 1) % BrotherRig.BLOWS.size()
		_blow = -1
		_rested = 0.0


## The blow lands: whatever is within reach in front of him is hit.
func _strike(blow: int) -> void:
	var forward := Vector3(sin(facing_yaw), 0.0, cos(facing_yaw))
	var left := Vector3(forward.z, 0.0, -forward.x)
	var reach := REACH[blow]
	# Which way it sends things: a hook across him, an uppercut up, a kick away.
	var way: Vector3
	match blow:
		0: way = forward * 0.6 - left * 0.75 + Vector3.UP * 0.25
		1: way = forward * 0.6 + left * 0.75 + Vector3.UP * 0.25
		2: way = forward * 0.45 + Vector3.UP * 0.9
		_: way = forward + Vector3.UP * 0.3
	way = way.normalized()
	var power := kick_power if blow == 3 else punch_power * (1.2 if blow == 2 else 1.0)

	var ball := SphereShape3D.new()
	ball.radius = reach.z
	var query := PhysicsShapeQueryParameters3D.new()
	query.shape = ball
	query.transform = Transform3D(Basis.IDENTITY, global_position + forward * reach.x + Vector3.UP * reach.y)
	query.collision_mask = 0xFFFFFFFF
	query.exclude = [get_rid(), _back.get_rid()]
	var hit: Array[Node3D] = []
	for found: Dictionary in get_world_3d().direct_space_state.intersect_shape(query, 16):
		var body := found.collider as Node3D
		# (not the boy, nor any part of him)
		if body == null or body in hit or (is_instance_valid(target) and (body == target or target.is_ancestor_of(body))):
			continue
		var loose := body as RigidBody3D
		if loose and not loose.freeze:
			loose.sleeping = false
			loose.apply_central_impulse(way * power * minf(loose.mass, heaviest))
			loose.apply_torque_impulse(Vector3(randf_range(-1.0, 1.0), randf_range(-1.0, 1.0), randf_range(-1.0, 1.0)) * minf(loose.mass, heaviest) * 0.3)
			hit.append(body)
		elif body.has_method(&"struck"):
			# (the impulse is what a body of five kilos would have been given)
			body.call(&"struck", self, way * power * 5.0)
			hit.append(body)
		elif body.is_in_group(&"pursuers"):
			hit.append(body)
	blow_landed.emit(BrotherRig.BLOWS[blow], hit)


# --- Bracing ---

## Bends over where he stands, to be climbed on, facing `yaw` (as he is, if not given).
func brace(yaw := NAN) -> void:
	stop()
	following = false
	_brace_yaw = facing_yaw if is_nan(yaw) else yaw
	_brace_time = 0.0
	_unasked = false
	_blow = -1
	doing = Doing.BRACED


## Goes to `spot` and braces there, facing `yaw`.
func brace_at(spot: Vector3, yaw: float) -> void:
	_blow = -1
	_set_back(false)
	_brace_yaw = yaw
	_unasked = false
	_going_time = 0.0
	_asked_from = target.global_position if is_instance_valid(target) else global_position
	doing = Doing.GOING_TO_BRACE
	go_to(spot, global_position.distance_to(spot) > far * 0.6)


## Gets up, from bracing or from going to.
func stand() -> void:
	if doing == Doing.GOING_TO_BRACE or doing == Doing.BRACED:
		_set_back(false)
		stop()
		doing = Doing.FOLLOWING
		_patience = 2.5


## Whether he is down with his back ready to be stood on.
func is_braced() -> bool:
	return doing == Doing.BRACED and _back_solid


func _set_back(solid: bool) -> void:
	if solid == _back_solid:
		return
	_back_solid = solid
	_back_shape.set_deferred(&"disabled", not solid)
	rig.set(&"burdened", false)
	if solid:
		braced.emit()


## Where `body` is over his back: across and along it from its middle, and
## above the top of it.
func _over_back(body: Node3D) -> Vector3:
	var to := body.global_position - global_position
	var forward := Vector3(sin(facing_yaw), 0.0, cos(facing_yaw))
	return Vector3(to.dot(Vector3(forward.z, 0.0, -forward.x)), to.y - back_height, to.dot(forward) - BACK_AHEAD)


func _is_on_back(body: Node3D) -> bool:
	var over := _over_back(body)
	return absf(over.x) < BACK.x * 0.5 + 0.2 and absf(over.z) < BACK.z * 0.5 + 0.2 and absf(over.y) < 0.12


func _on_the_way(delta: float) -> void:
	_going_time += delta
	var gone := is_instance_valid(target) and Vector2(target.global_position.x - _asked_from.x, target.global_position.z - _asked_from.z).length() > 1.2
	if _unasked and (gone or _going_time > 6.0):
		stand()
	elif not is_going():
		# He has got there. (Figure.go_to stops him on the spot.)
		_brace_time = 0.0
		doing = Doing.BRACED


func _hold(delta: float) -> void:
	_brace_time += delta
	var there := is_instance_valid(target) and target.is_inside_tree()
	if not _back_solid and _brace_time > 0.45:
		# His back is something to stand on once he is down, and once nobody is
		# standing where it will be.
		var clear := true
		if there:
			var over := _over_back(target)
			clear = over.y > -0.05 or absf(over.x) > BACK.x * 0.5 + 0.3 or absf(over.z) > BACK.z * 0.5 + 0.3
		if clear:
			_set_back(true)
	var on_it := there and _back_solid and _is_on_back(target)
	rig.set(&"burdened", on_it)
	if _unasked and there and not on_it:
		var to := target.global_position - global_position
		if Vector2(to.x, to.z).length() > give_up_distance or absf(to.y) > back_height + out_of_reach:
			stand()


## Whoever he follows has jumped. If it was from his back, he throws them up.
func _on_target_jumped() -> void:
	if doing != Doing.BRACED or not _back_solid or not _is_on_back(target):
		return
	var body := target as CharacterBody3D
	if body == null:
		return
	# Fast enough to carry them `boost_height` higher than a jump from the
	# ground goes, less what his back has already raised them.
	var jump: float = body.get(&"jump_height") if body.get(&"jump_height") != null else 1.15
	var apex: float = body.get(&"time_to_apex") if body.get(&"time_to_apex") != null else 0.36
	var gravity := 2.0 * jump / (apex * apex)
	var rise := jump + boost_height - (body.global_position.y - global_position.y)
	body.velocity.y = maxf(body.velocity.y, sqrt(2.0 * gravity * maxf(rise, jump)))
	_set_back(false)
	_heave_time = 0.0
	doing = Doing.HEAVING
	boosted.emit(target)


func _heave(delta: float) -> void:
	_heave_time += delta
	# (he stands and watches for a moment after)
	if _heave_time > BrotherRig.HEAVE_TAKES + 1.4:
		doing = Doing.FOLLOWING
		_patience = 2.5


## Whether to brace unasked: for someone standing still in front of a wall that
## wants a boost, or standing still and ducking near him.
func _consider_bracing(delta: float) -> void:
	_patience -= delta
	var body := target as CharacterBody3D
	if body == null or _patience > 0.0 or not (brace_at_walls or brace_on_duck):
		_waited = 0.0
		return
	var to := body.global_position - global_position
	if not body.is_on_floor() or Vector2(body.velocity.x, body.velocity.z).length() > 0.3 or to.length() > summon_range or absf(to.y) > out_of_reach:
		_waited = 0.0
		return
	_waited += delta
	var ducking: bool = brace_on_duck and body.get(&"is_ducking") == true
	if _waited < (0.35 if ducking else brace_delay):
		return
	# (looked for a few times a second, not every step)
	_look_in -= delta
	if _look_in > 0.0:
		return
	_look_in = 0.2
	var yaw: float = body.get(&"facing_yaw") if body.get(&"facing_yaw") != null else body.global_rotation.y
	var ahead := Vector3(sin(yaw), 0.0, cos(yaw))
	var feet := body.global_position
	var space := get_world_3d().direct_space_state
	var wall := space.intersect_ray(PhysicsRayQueryParameters3D.create(feet + Vector3.UP * 0.6, feet + Vector3.UP * 0.6 + ahead * 1.8, 1))
	var spot: Vector3
	var facing: float
	if not wall.is_empty() and absf((wall.normal as Vector3).y) < 0.3:
		var out := Vector3(wall.normal.x, 0.0, wall.normal.z).normalized()
		if not ducking:
			if not brace_at_walls:
				return
			# How high is it? Too high to catch from a jump, and not too high to catch from his back.
			var jump: float = body.get(&"jump_height") if body.get(&"jump_height") != null else 1.15
			var grasp: float = (body.get(&"ledge_reach") as Vector2).y if body.get(&"ledge_reach") != null else 1.6
			var over: Vector3 = wall.position - out * 0.2
			var top := space.intersect_ray(PhysicsRayQueryParameters3D.create(
				Vector3(over.x, feet.y + jump + boost_height + grasp - 0.1, over.z), Vector3(over.x, feet.y + jump + grasp - 0.15, over.z), 1))
			if top.is_empty() or (top.normal as Vector3).y < 0.7:
				return
		# At the foot of it, his back to it. If they are standing too near it
		# to leave him room, a step along it, on the side he is coming from.
		spot = Vector3(wall.position.x, feet.y, wall.position.z) + out * 0.48
		if (feet - wall.position).dot(out) < 1.3:
			var along := Vector3(out.z, 0.0, -out.x)
			spot += along * (0.85 if (global_position - feet).dot(along) >= 0.0 else -0.85)
		facing = atan2(out.x, out.z)
	elif ducking:
		# In the open: a pace in front of them, facing them.
		spot = feet + ahead * 1.1
		facing = atan2(-ahead.x, -ahead.z)
	else:
		return
	brace_at(spot, facing)
	_unasked = true
	_waited = 0.0


func _physics_process(delta: float) -> void:
	match doing:
		Doing.FIGHTING:
			_fight(delta)
		Doing.GOING_TO_BRACE:
			_on_the_way(delta)
		Doing.BRACED:
			_hold(delta)
		Doing.HEAVING:
			_heave(delta)
		_:
			_follow()
			_consider_bracing(delta)
	super(delta)


func _follow() -> void:
	if not is_instance_valid(target) or not target.is_inside_tree():
		return
	var to := target.global_position - global_position
	# Up where he cannot walk to, he is not walked at: he stands and watches.
	var beyond := absf(to.y) > out_of_reach
	to.y = 0.0
	var apart := to.length()
	# (each line is crossed at one distance going out and another coming back)
	if following:
		following = apart > near and not beyond
	else:
		following = apart > slack and not beyond
	if _running:
		_running = apart > far * 0.6
	else:
		_running = apart > far
	if following:
		# He makes for a place just short of him, and so slows as he comes up.
		go_to(target.global_position - to / apart * (near - 0.2), _running)
	elif is_going():
		stop()


func _process(delta: float) -> void:
	super(delta)
	var turning := 1.0 - exp(-watch_rate * delta)
	var watched: Node3D = null
	var move := &""
	var through := 0.0
	# (what is seen of a move is carried on between one physics step and the next)
	var ahead := Engine.get_physics_interpolation_fraction() / Engine.physics_ticks_per_second
	match doing:
		Doing.FIGHTING:
			move = &"guard"
			if _blow >= 0:
				move = BrotherRig.BLOWS[_blow]
				through = clampf((_blow_time + ahead) / BrotherRig.TAKES[_blow], 0.0, 1.0)
			if is_instance_valid(_foe):
				watched = _foe
				_turn_to(_foe.global_position, 1.0 - exp(-9.0 * delta))
		Doing.BRACED:
			move = &"brace"
			watched = target
			facing_yaw = lerp_angle(facing_yaw, _brace_yaw, 1.0 - exp(-8.0 * delta))
		Doing.HEAVING:
			watched = target
			if _heave_time < BrotherRig.HEAVE_TAKES:
				move = &"heave"
				through = clampf((_heave_time + ahead) / BrotherRig.HEAVE_TAKES, 0.0, 1.0)
			# He turns round after him as he comes up.
			if _heave_time > 0.3 and is_instance_valid(target):
				_turn_to(target.global_position, 1.0 - exp(-3.0 * delta))
		Doing.FOLLOWING:
			# Standing by, he turns to watch him. (On the move, a Figure faces the way it goes.)
			if not following and is_instance_valid(target) and Vector2(velocity.x, velocity.z).length_squared() < 0.04:
				_turn_to(target.global_position, turning)
	var own := rig as BrotherRig
	if own:
		own.move = move
		own.move_at = through
		own.watch = watched if is_instance_valid(watched) else null
	_show()


func _turn_to(point: Vector3, share: float) -> void:
	var to := point - global_position
	if Vector2(to.x, to.z).length_squared() > 0.01:
		facing_yaw = lerp_angle(facing_yaw, atan2(to.x, to.z), share)
