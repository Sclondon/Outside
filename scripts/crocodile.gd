class_name Crocodile
extends CharacterBody3D
## A Nile crocodile. It lives in a body of water: the `Pool` it is put in, or
## the nearest to where it is put. (With no water near, it lies about on land
## round `home`, and is as dangerous there as on any bank.) Everything it needs
## (collider, model, voice) is made here, so `Crocodile.new()` is a complete one.
##
## Left alone it floats like a log, only its eyes and its nostrils out of the
## water, and now and then hauls itself out to bask on the bank, on its belly
## with its mouth open, and after a while slides back in. It watches the boy
## whenever he is near.
##
## When he comes to the water's edge, or into the water, it sinks out of sight
## and comes at him under water. What gives it away is the line of rings its
## back draws on the surface as it comes (`Water.ripple`), and in the shallows
## its back itself. A few metres off it stops, and its eyes come up, and there
## is a ring and a splash: that is all the warning there is. Then it lunges, up
## the bank if it has to, jaws wide, and snaps; and if it has him, `caught` is
## sent (the level knocks him down and starts him again, as with a hound).
## It is faster in the water than he can swim, so the water is not safe while
## it is in it. On land it is not: it scuttles after him for a few metres
## (`reach`, and not for longer than `stamina`), gives up, and goes back.
##
## It is shy of fire (a burning flare, a lit torch), of being shot or hit
## (`shot`, `struck`, as the hounds have), and of anything thrown that lands
## near it: each sends it under, and keeps it there for a while. It is never
## killed.
##
## `docile` makes it scenery: it floats and basks and watches, hisses if he
## comes right up to it and slides away, and never hunts.
##
## It is in the group `crocodiles`, and in `pursuers` only while it is hunting.
##
## Its voice is made up in code (`_make_voices`): a hiss, a low bellow, and the
## clap of its jaws. No recording of a crocodile was to hand.

signal caught

enum State {
	FLOAT,     ## at rest in the water
	HAUL_OUT,  ## going up the bank to bask
	BASK,      ## lying on the bank
	RETURN,    ## going back to the water
	HIDE,      ## under water, frightened
	STALK,     ## after him, under water (or over the ground, if it started on the bank)
	WIND_UP,   ## stopped short of him, eyes up, about to lunge
	LUNGE,
	CHASE,     ## after him on land, having missed
	HOLD,      ## it has him
}

## Never hunts: scenery.
@export var docile := false
## How far from the water (or from `home`) it will come after him, metres.
@export var reach := 5.0
## Where it lives when there is no water near. Vector3.INF: where it was put.
@export var home := Vector3.INF
## How far off it finds its water, and how near the boy must be to be watched.
@export var water_within := 30.0
@export var notice := 18.0
## He is "at the water's edge" within this of it (m).
@export var edge := 2.4
@export_group("How it goes")
@export var crawl_speed := 0.34
@export var walk_speed := 0.6
@export var run_speed := 3.0
## Swimming: at its ease, stalking him while he is on the bank, and after him when he is in the water.
@export var swim_speed := 1.1
@export var stalk_speed := 2.4
@export var chase_speed := 3.7
@export var lunge_speed := 7.5
@export var gravity := 24.0
@export_group("The hunt")
## How near (snout to him) before it lunges, how long it holds still first, and how long the lunge lasts.
@export var lunge_range := 3.3
@export var wind_up := 0.45
@export var lunge_time := 0.55
## Touching distance, from the tip of its snout.
@export var catch_distance := 0.75
## How long it will run after him on land (s), and how long it rests after giving up.
@export var stamina := 3.5
@export var rest := 6.0
@export_group("What frightens it")
@export var flare_fear := 7.0
@export var torch_fear := 3.5
## How long it stays under after a shot, a blow, and something thrown (s).
@export var shot_time := 14.0
@export var blow_time := 6.0
@export var stone_time := 5.0
@export_group("")
## How long it floats before it hauls out, and basks before it goes back (s, least and most).
@export var float_for := Vector2(35.0, 70.0)
@export var bask_for := Vector2(45.0, 90.0)
@export var voice := true

## How deep its feet hang under the surface: floating still, swimming at the surface, and as far down as it will go.
const FLOAT_DRAFT := 0.535
const SWIM_DRAFT := 0.47
const DIVE_DRAFT := 1.25
## How far ahead of its middle, and behind it, it feels for the ground it lies on.
const HALF := 0.95
const HISS := 0
const BELLOW := 1
const CLAP := 2

var target: Player
var pool: Pool
var state := State.FLOAT
## Use the demade, low-poly model. Set before it enters the tree.
var low_poly := false
## Heading of the model, radians around Y. Zero faces +Z.
var facing_yaw := 0.0
## Render-rate position, and how it is tipped to the ground it lies on; the rig follows these.
var visual_position := Vector3.ZERO
var slope := 0.0
## What the rig is told. How high it carries itself on land: 0 on its belly, 1 the high walk.
var lift := 0.0
## How far the water has it, 0..1: deep enough to swim in.
var afloat := 0.0
var submerged := false
## How far open its mouth is to be, 0..1, and how fast it opens.
var jaws := 0.0
var jaw_rate := 1.0
var lunging := false
var gaze: Node3D
var dozing := false
## Somewhere to go, and how fast, instead of thinking for itself (the test stage uses this).
## Vector3.INF: nowhere. With `thinking` off it does nothing of its own accord at all.
var bidden := Vector3.INF
var bidden_speed := 0.5
var thinking := true

var _rig: CrocodileRig
var _hitbox: StaticBody3D
var _voice: AudioStreamPlayer3D
var _prev_pos := Vector3.ZERO
var _curr_pos := Vector3.ZERO
var _spawn := Transform3D.IDENTITY
## The ground under its middle, its front and its back; the surface of its water there (or far below, where
## there is none); and how deep the water is over the ground under its middle.
var _ground := Vector3.ZERO
var _surface := -1000.0
var _water := 0.0
var _buoyant := false
var _fore := 0.0
var _aft := 0.0
var _height := 0.0
var _settled := false
## Where it floats, where it basks, and where it was last in the water.
var _float_spot := Vector3.INF
var _bask_spot := Vector3.INF
var _wet_spot := Vector3.INF
var _timer := 0.0
var _state_time := 0.0
var _aim := Vector3.FORWARD
var _face := Vector3.ZERO
## Tired: it will not hunt until this has run out. Frightened: it stays under until this has.
var _tired := 0.0
var _cowed := 0.0
var _fear_from := Vector3.INF
var _lunge_rest := 0.0
var _lost := 0.0
var _hurry := false
var _edge_timer := 0.0
var _at_edge := false
var _stone_timer := 0.0
var _ripple_timer := 0.0
var _say_timer := 20.0
var _was_afloat := false
var _look_for_water := 0.0
var _look_for_him := 0.0

static var _voices: Array[AudioStreamWAV] = []


func _ready() -> void:
	add_to_group(&"crocodiles")
	# Crocodiles and the player pass through each other; only the world stops them.
	collision_layer = 0
	collision_mask = 1
	floor_snap_length = 0.3
	floor_max_angle = deg_to_rad(55.0)
	var shape := SphereShape3D.new()
	shape.radius = 0.22
	var collider := CollisionShape3D.new()
	collider.shape = shape
	collider.position.y = shape.radius
	add_child(collider)
	# What a shot hits: the length of its body. It stops nothing.
	_hitbox = StaticBody3D.new()
	_hitbox.collision_layer = 4
	_hitbox.collision_mask = 0
	var long := CapsuleShape3D.new()
	long.radius = 0.26
	long.height = 2.3
	var hide := CollisionShape3D.new()
	hide.shape = long
	hide.rotation.x = PI * 0.5
	hide.position = Vector3(0.0, 0.3, 0.1)
	_hitbox.add_child(hide)
	add_child(_hitbox)
	_hitbox.top_level = true

	if voice:
		_make_voices()
		_voice = AudioStreamPlayer3D.new()
		_voice.unit_size = 6.0
		_voice.max_distance = 45.0
		_voice.volume_db = -9.0
		_voice.max_db = 0.0
		_voice.position = Vector3(0.0, 0.3, 0.9)
		add_child(_voice)

	_rig = CrocodileRig.new()
	_rig.low_poly = low_poly
	add_child(_rig)
	_rig.top_level = true
	_spawn = global_transform
	facing_yaw = global_rotation.y
	rotation = Vector3.ZERO
	_curr_pos = global_position
	_prev_pos = global_position
	visual_position = global_position
	_height = global_position.y
	_fore = _height
	_aft = _height
	if home == Vector3.INF:
		home = global_position
	_timer = randf_range(float_for.x, float_for.y)


## Back to where it started.
func reset() -> void:
	global_position = _spawn.origin
	velocity = Vector3.ZERO
	facing_yaw = _spawn.basis.get_euler().y
	_curr_pos = global_position
	_prev_pos = global_position
	_tired = 0.0
	_cowed = 0.0
	_settled = false
	_enter(State.FLOAT)


## Hit with anything swung: it hisses, and makes for the water and stays under it for a while.
func struck(by: Node3D, _impulse: Vector3) -> void:
	_frighten(by.global_position if by else global_position, blow_time)
	_say(HISS)


## Hit by a gun: the same, for longer. It is never killed.
func shot(by: Node3D, _at: Vector3, _direction: Vector3, _damage: float) -> void:
	_frighten(by.global_position if by else global_position, shot_time)
	_say(HISS)


## Whether it is after him just now.
func is_hunting() -> bool:
	return state == State.STALK or state == State.WIND_UP or state == State.LUNGE or state == State.CHASE


func _physics_process(delta: float) -> void:
	_feel()
	if not _settled:
		_settle()
	var want := Vector3.ZERO
	var turn := 2.2
	_face = Vector3.ZERO
	if not thinking or bidden != Vector3.INF:
		if bidden != Vector3.INF:
			var to := bidden - global_position
			to.y = 0.0
			want = to.normalized() * bidden_speed if to.length() > 0.25 else Vector3.ZERO
	else:
		_state_time += delta
		_tired -= delta
		_lunge_rest -= delta
		_notice(delta)
		want = _think(delta)
		if state == State.LUNGE or state == State.WIND_UP:
			turn = 9.0
		elif is_hunting():
			turn = 4.0
		_speak(delta)
	if is_hunting() != is_in_group(&"pursuers"):
		if is_hunting():
			add_to_group(&"pursuers")
		else:
			remove_from_group(&"pursuers")

	# It goes the way it is pointing: it turns first, and gets under way as it comes round.
	var heading := want if want.length_squared() > 0.0004 else _face
	var off := 0.0
	if heading.length_squared() > 0.0004:
		var to_yaw := atan2(heading.x, heading.z)
		off = angle_difference(facing_yaw, to_yaw)
		facing_yaw += clampf(off, -turn * delta, turn * delta)
	var ahead := Vector3(sin(facing_yaw), 0.0, cos(facing_yaw))
	var go := ahead * want.length() * clampf(cos(off) * 1.4 - 0.4, 0.0, 1.0)
	var quick := 26.0 if state == State.LUNGE else (5.0 if afloat > 0.5 else 9.0)
	var current := Vector3(velocity.x, 0.0, velocity.z).move_toward(go, quick * delta)
	velocity.x = current.x
	velocity.z = current.z

	# The water carries it, where there is enough: it lies at the depth it means to, or as deep as there is.
	var speed := current.length()
	var draft := DIVE_DRAFT if submerged else lerpf(FLOAT_DRAFT, SWIM_DRAFT, smoothstep(0.2, 1.0, speed))
	_buoyant = _water > draft - 0.1 or (_water > 0.3 and global_position.y > _ground.y + 0.06 and global_position.y < _surface)
	if state == State.LUNGE:
		# (it comes up out of the water as it goes)
		draft = 0.32
	if _buoyant:
		velocity.y = clampf((_surface - draft - global_position.y) * 5.0, -1.6, 2.4 if state == State.LUNGE else 1.6)
	else:
		velocity.y -= gravity * delta
	move_and_slide()
	afloat = smoothstep(0.22, 0.48, _water)
	if _water > 0.25:
		_wet_spot = global_position
	_wake(delta, speed)
	if global_position.y < -40.0:
		reset()
	_prev_pos = _curr_pos
	_curr_pos = global_position


func _process(delta: float) -> void:
	var at := _prev_pos.lerp(_curr_pos, Engine.get_physics_interpolation_fraction())
	# It lies along the ground, or the water: its two ends are each held up by whichever is the higher there.
	var level := global_position.y if _buoyant else _surface - FLOAT_DRAFT
	var ahead := Vector3(sin(facing_yaw), 0.0, cos(facing_yaw))
	var fore := maxf(_ground_at(at + ahead * HALF), level)
	var aft := maxf(_ground_at(at - ahead * HALF), level)
	var ease := 1.0 - exp(-12.0 * delta)
	_fore = lerpf(_fore, fore, ease)
	_aft = lerpf(_aft, aft, ease)
	_height = lerpf(_height, maxf((_fore + _aft) * 0.5, at.y - 0.05), 1.0 - exp(-18.0 * delta))
	slope = atan2(_fore - _aft, HALF * 2.0)
	visual_position = Vector3(at.x, _height, at.z)
	_rig.global_position = visual_position
	_rig.global_basis = Basis(Vector3.UP, facing_yaw) * Basis(Vector3.RIGHT, -slope)
	_hitbox.global_transform = Transform3D(_rig.global_basis, visual_position)


# --- What it knows of where it is ---

## How high the ground is under `point` (far below, where there is none).
func _ground_at(point: Vector3) -> float:
	var from := Vector3(point.x, maxf(point.y, _surface) + 2.5, point.z)
	var query := PhysicsRayQueryParameters3D.create(from, from + Vector3.DOWN * 12.0, 1)
	var hit := get_world_3d().direct_space_state.intersect_ray(query)
	return hit.position.y if not hit.is_empty() else from.y - 12.0


## How deep the water of its pool is over the ground at `point` (0: none).
func _depth_at(point: Vector3) -> float:
	if not is_instance_valid(pool) or pool.depth_at(Vector3(point.x, pool.surface_y() - 0.01, point.z)) < 0.0:
		return 0.0
	return maxf(pool.surface_y() - _ground_at(point), 0.0)


func _feel() -> void:
	if not is_instance_valid(pool):
		if _settled:
			# (its water has been made again, or taken away: it finds out where it lives afresh)
			_settled = false
			_float_spot = Vector3.INF
			_look_for_water = 0.0
		pool = null
	_surface = -1000.0
	if pool and pool.depth_at(Vector3(global_position.x, pool.surface_y() - 0.01, global_position.z)) >= 0.0:
		_surface = pool.surface_y()
	_ground = Vector3(global_position.x, _ground_at(global_position), global_position.z)
	_water = maxf(_surface - _ground.y, 0.0)


## Finds its water, and where in it it floats and beside it it basks. Put in the water, it floats
## where it was put; put on the bank, that is where it basks.
func _settle() -> void:
	_look_for_water -= get_physics_process_delta_time()
	if pool == null and _look_for_water <= 0.0:
		_look_for_water = 2.0
		var nearest := water_within
		for other: Node in get_tree().get_nodes_in_group(&"water"):
			var water := other as Pool
			if water == null:
				continue
			var off := (global_position - water.global_position).abs() - water.size * 0.5
			var distance := Vector2(maxf(off.x, 0.0), maxf(off.z, 0.0)).length()
			if distance < nearest:
				nearest = distance
				pool = water
		if pool:
			_feel()
	if pool == null:
		# No water: it lies where it lives.
		if _float_spot == Vector3.INF:
			_float_spot = home
			_bask_spot = home
			_wet_spot = home
			_enter(State.BASK)
		return
	_settled = true
	var here := global_position
	if _depth_at(here) > 0.35:
		_float_spot = here
		_bask_spot = _find_bank(here)
		_enter(State.FLOAT)
	else:
		_bask_spot = here
		_float_spot = _find_water(here)
		# (where the water begins, on the way to it)
		_wet_spot = _float_spot
		for i in 40:
			var at := here.lerp(_float_spot, i / 40.0)
			if _depth_at(at) > 0.25:
				_wet_spot = at
				break
		_face = _float_spot - here
		_enter(State.BASK)
	_timer *= randf_range(0.3, 1.0)


## The nearest place on the bank to bask, from `spot` in the water: just clear of it. INF if there is none.
func _find_bank(spot: Vector3) -> Vector3:
	var best := Vector3.INF
	var nearest := 40.0
	for k in 16:
		var way := Vector3(sin(TAU * k / 16.0), 0.0, cos(TAU * k / 16.0))
		var out := 0.5
		while out < nearest:
			var at := spot + way * out
			var ground := _ground_at(at)
			if ground > pool.surface_y() + 0.1 or pool.depth_at(Vector3(at.x, pool.surface_y() - 0.01, at.z)) < 0.0:
				# (far enough up that its body is out, and its tail still trails in the water)
				var up := spot + way * (out + 0.9)
				if absf(_ground_at(up) - pool.surface_y()) < 1.2:
					nearest = out
					best = Vector3(up.x, _ground_at(up), up.z)
				break
			out += 0.5
	return best


## Somewhere to float, from `spot` on the bank: the first water deep enough, going towards the middle of it.
func _find_water(spot: Vector3) -> Vector3:
	var middle := pool.global_position
	var to := Vector3(middle.x - spot.x, 0.0, middle.z - spot.z)
	var steps := int(to.length() / 0.5)
	var best := Vector3(middle.x, pool.surface_y(), middle.z)
	var deepest := 0.0
	for i in steps + 1:
		var at := spot + to * (float(i) / maxf(steps, 1.0))
		var depth := _depth_at(at)
		if depth > deepest:
			deepest = depth
			best = Vector3(at.x, pool.surface_y(), at.z)
		if depth > 0.75:
			# (a length further in, so that the whole of it is afloat)
			var further := at + to.normalized() * 1.2
			return Vector3(further.x, pool.surface_y(), further.z) if _depth_at(further) > 0.6 else best
	return best


## Whether he is in its water, or within `edge` of it.
func _boy_at_water() -> bool:
	if target == null or pool == null:
		return false
	var at := target.global_position
	if pool.depth_at(at) > 0.05:
		return true
	for k in 8:
		var near := at + Vector3(sin(TAU * k / 8.0), 0.0, cos(TAU * k / 8.0)) * edge
		if _depth_at(near) > 0.15:
			return true
	return false


func _boy_wet() -> bool:
	return target != null and pool != null and pool.depth_at(target.global_position) > 0.3


## How far it is from the water (or from home).
func _strayed() -> float:
	var from := _wet_spot if _wet_spot != Vector3.INF else home
	return Vector2(global_position.x - from.x, global_position.z - from.z).length()


# --- What it does ---

func _enter(next: State) -> void:
	state = next
	_state_time = 0.0
	lunging = false
	_hurry = false
	match next:
		State.FLOAT:
			_timer = randf_range(float_for.x, float_for.y)
		State.BASK:
			_timer = randf_range(bask_for.x, bask_for.y)
		State.WIND_UP:
			# Its eyes come up: a ring on the water, and a splash.
			if pool and afloat > 0.3:
				pool.water.splash(_rig.snout() if _rig else global_position, 0.35)
		State.LUNGE:
			_say(CLAP if afloat < 0.3 else HISS)
			if pool and _water > 0.1:
				pool.water.splash(global_position, 1.0)


## Notices him, and whatever frightens it.
func _notice(delta: float) -> void:
	if target == null or not is_instance_valid(target):
		target = null
		# (no one has said who he is: it looks for him itself, now and then)
		_look_for_him -= delta
		if _look_for_him <= 0.0:
			_look_for_him = 2.0
			var found := get_tree().root.find_children("*", "Player", true, false)
			target = found[0] as Player if not found.is_empty() else null
	_edge_timer -= delta
	if _edge_timer <= 0.0:
		_edge_timer = 0.25
		_at_edge = _boy_at_water()
	var near := target != null and target.global_position.distance_to(global_position) < notice
	gaze = target if near and state != State.HIDE else null

	# Fire: a burning flare, or a torch that is alight.
	var fire := Vector3.INF
	for flare: Node3D in get_tree().get_nodes_in_group(&"flares"):
		if flare.global_position.distance_to(global_position) < flare_fear:
			fire = flare.global_position
	for torch: Node3D in get_tree().get_nodes_in_group(&"torches"):
		if torch.get(&"lit") == true and torch.global_position.distance_to(global_position) < torch_fear:
			fire = torch.global_position
	if fire != Vector3.INF:
		_frighten(fire, 3.0)
	# Something thrown, coming down near it.
	_stone_timer -= delta
	if _stone_timer <= 0.0:
		_stone_timer = 0.12
		for thing: Node in get_tree().get_nodes_in_group(&"throwable"):
			var stone := thing as RigidBody3D
			if stone == null or stone.freeze or stone.linear_velocity.length() < 2.5 or (target and target.carried == stone):
				continue
			var off := stone.global_position - (global_position + Vector3(sin(facing_yaw), 0.0, cos(facing_yaw)) * 0.4)
			if Vector2(off.x, off.z).length() < 3.0 and absf(off.y) < 2.0:
				_frighten(stone.global_position, stone_time)


## Something has frightened it, at `from`: it goes under, and stays there for `time`.
func _frighten(from: Vector3, time: float) -> void:
	_fear_from = from
	_cowed = maxf(_cowed, time)
	jaws = 0.0
	if state != State.HIDE:
		_enter(State.HIDE)
	_state_time = 0.0


func _think(delta: float) -> Vector3:
	var here := global_position
	var boy := target if target and is_instance_valid(target) and not target.is_limp else null
	var to_boy := boy.global_position - here if boy else Vector3.ZERO
	to_boy.y = 0.0
	var hunts := not docile and boy != null and _tired <= 0.0
	dozing = false
	match state:
		State.FLOAT:
			submerged = false
			lift = 0.0
			jaws = 0.0
			if hunts and _hunt_starts(to_boy):
				_enter(State.STALK)
				return Vector3.ZERO
			_timer -= delta
			if _timer <= 0.0:
				if _bask_spot != Vector3.INF and pool != null:
					_enter(State.HAUL_OUT)
				else:
					_timer = 20.0
			# It keeps its place, and turns to keep him in view.
			var back := _float_spot - here
			back.y = 0.0
			if boy and to_boy.length() < notice:
				_face = to_boy
			return back.normalized() * swim_speed * 0.6 if back.length() > 1.2 else Vector3.ZERO

		State.HAUL_OUT:
			submerged = false
			jaws = 0.0
			# Out of the water it lifts itself clear of the ground, and walks.
			lift = 1.0 if afloat < 0.5 else 0.0
			if hunts and _hunt_starts(to_boy):
				_enter(State.STALK)
				return Vector3.ZERO
			var to := _bask_spot - here
			to.y = 0.0
			if to.length() < 0.35 or _state_time > 40.0:
				_face = _float_spot - here
				_enter(State.BASK)
				return Vector3.ZERO
			return to.normalized() * (swim_speed if afloat > 0.5 else walk_speed)

		State.BASK:
			submerged = false
			lift = 0.0
			_face = _float_spot - here if _state_time < 6.0 and _float_spot.distance_to(here) > 1.0 else Vector3.ZERO
			# Its mouth open, most of the time; shut when he is close, and it hisses.
			var close := boy != null and to_boy.length() < 3.5 and absf(boy.global_position.y - here.y) < 2.0
			jaw_rate = 0.8
			jaws = 0.5 if _state_time > 5.0 and fmod(_state_time, 50.0) < 36.0 else 0.0
			dozing = _state_time > 25.0 and (boy == null or to_boy.length() > notice * 0.7)
			if close:
				jaws = 0.34
				jaw_rate = 6.0
				if _state_time > 1.0 and _say_timer > 2.5:
					_say(HISS)
			if hunts and (_hunt_starts(to_boy) or (close and to_boy.length() < lunge_range + 1.0)):
				_enter(State.STALK)
				return Vector3.ZERO
			if docile and close and to_boy.length() < 2.2 and pool != null:
				# Too near: it slides away into the water.
				_enter(State.RETURN)
				_hurry = true
				return Vector3.ZERO
			_timer -= delta
			if _timer <= 0.0 and pool != null:
				_enter(State.RETURN)
			return Vector3.ZERO

		State.RETURN:
			submerged = false
			jaws = 0.0
			var to := _float_spot - here
			to.y = 0.0
			# It walks back, high, and goes down the last of the bank on its belly.
			lift = 1.0 if not _hurry and _water < 0.02 and _strayed() > 1.6 else 0.0
			if hunts and _hunt_starts(to_boy) and (afloat > 0.5 or _strayed() < reach * 0.5):
				_enter(State.STALK)
				return Vector3.ZERO
			if to.length() < (1.0 if pool else 0.4) or _state_time > 40.0:
				_enter(State.FLOAT if pool else State.BASK)
				return Vector3.ZERO
			if afloat > 0.5:
				return to.normalized() * swim_speed
			# (the last of the bank it takes at a slide)
			if _hurry:
				return to.normalized() * run_speed
			return to.normalized() * (walk_speed if lift > 0.5 else lerpf(crawl_speed, 1.3, smoothstep(0.05, 0.3, _water)))

		State.HIDE:
			submerged = true
			lift = 0.0
			jaws = 0.0
			_cowed -= delta
			if _cowed <= 0.0:
				_tired = maxf(_tired, 2.0)
				_enter(State.FLOAT if afloat > 0.5 else State.RETURN)
				return Vector3.ZERO
			if pool == null:
				# (nowhere to hide: it backs off)
				var off := here - _fear_from
				off.y = 0.0
				return off.normalized() * run_speed if off.length() < 8.0 else Vector3.ZERO
			if afloat < 0.6:
				var to := _float_spot - here
				to.y = 0.0
				return to.normalized() * run_speed
			# Under, and away from it, as far as there is water to go in.
			var away := here - _fear_from
			away.y = 0.0
			if away.length() < 9.0 and away.length() > 0.01 and _depth_at(here + away.normalized() * 1.6) > 0.55:
				return away.normalized() * stalk_speed
			return Vector3.ZERO

		State.STALK:
			if boy == null or docile:
				_give_up(0.0)
				return Vector3.ZERO
			submerged = true
			lift = 0.0
			jaws = 0.0
			var wet := _boy_wet()
			# He has left the water's edge: it waits a moment, and then lets him go.
			_lost = 0.0 if _at_edge or to_boy.length() < lunge_range + 1.5 else _lost + delta
			if _lost > 2.5:
				_give_up(0.0)
				return Vector3.ZERO
			if afloat < 0.3 and _strayed() > reach:
				_give_up(rest)
				return Vector3.ZERO
			var snout := _rig.snout()
			var gap := Vector2(boy.global_position.x - snout.x, boy.global_position.z - snout.z).length()
			if gap < lunge_range and _lunge_rest <= 0.0 and absf(angle_difference(facing_yaw, atan2(to_boy.x, to_boy.z))) < 0.5:
				_enter(State.WIND_UP)
				return Vector3.ZERO
			_face = to_boy
			if gap < lunge_range * 0.6:
				return Vector3.ZERO
			# It does not come out onto the bank until it means to lunge.
			if afloat > 0.3 and not wet and _depth_at(here + to_boy.normalized() * 1.5) < 0.3 and gap > lunge_range:
				return Vector3.ZERO
			return to_boy.normalized() * (run_speed if afloat < 0.3 else (chase_speed if wet else stalk_speed))

		State.WIND_UP:
			submerged = false
			_face = to_boy
			jaws = 0.12
			jaw_rate = 8.0
			if boy == null:
				_give_up(0.0)
			elif _state_time >= wind_up:
				_aim = to_boy.normalized() if to_boy.length() > 0.01 else Vector3(sin(facing_yaw), 0.0, cos(facing_yaw))
				_enter(State.LUNGE)
			return Vector3.ZERO

		State.LUNGE:
			submerged = false
			lunging = true
			lift = 0.3
			jaws = 1.0
			jaw_rate = 22.0
			if boy:
				# (it can follow him a little as it comes, not much)
				_aim = _aim.slerp(to_boy.normalized(), 1.0 - exp(-2.5 * delta)) if to_boy.length() > 0.3 else _aim
				if _has_him(boy):
					return Vector3.ZERO
			if _state_time >= lunge_time or (afloat < 0.2 and _strayed() > reach + 1.0):
				# Missed: its jaws come together on nothing.
				jaws = 0.0
				_say(CLAP)
				_lunge_rest = 1.4
				if boy and (afloat > 0.3 or _boy_wet()):
					_enter(State.STALK)
				elif boy and _strayed() < reach:
					_enter(State.CHASE)
				else:
					_give_up(rest * 0.5)
				return Vector3.ZERO
			return _aim * lunge_speed

		State.CHASE:
			submerged = false
			lift = 0.0
			jaws = 0.3
			jaw_rate = 6.0
			if boy == null:
				_give_up(0.0)
				return Vector3.ZERO
			if _has_him(boy):
				return Vector3.ZERO
			# On land it is soon done: a few metres, and it turns back.
			if _strayed() > reach or _state_time > stamina:
				_give_up(rest)
				return Vector3.ZERO
			if _boy_wet() and afloat > 0.3:
				_enter(State.STALK)
				return Vector3.ZERO
			return to_boy.normalized() * run_speed

		State.HOLD:
			submerged = false
			jaws = 0.12
			lift = 0.0
			if _state_time > 2.6:
				_give_up(rest * 0.7)
			return Vector3.ZERO
	return Vector3.ZERO


## Whether to go after him: he is at its water, or in it, and near enough to be worth it.
func _hunt_starts(to_boy: Vector3) -> bool:
	if _cowed > 0.0:
		return false
	if pool == null:
		return to_boy.length() < lunge_range + 1.0
	return _at_edge and to_boy.length() < maxf(pool.size.x, pool.size.z) + notice


## Its jaws have closed on him.
func _has_him(boy: Player) -> bool:
	var snout := _rig.snout()
	var him := boy.global_position + Vector3.UP * 0.5
	# (anywhere along its jaws will do, not only the tip)
	var back := snout - Vector3(sin(facing_yaw), 0.0, cos(facing_yaw)) * 0.3
	if minf(snout.distance_to(him), back.distance_to(him)) > catch_distance:
		return false
	jaws = 0.0
	_say(CLAP)
	velocity.x *= 0.2
	velocity.z *= 0.2
	_enter(State.HOLD)
	caught.emit()
	return true


## It breaks off, and goes back to the water; it will not hunt again for `tired` seconds.
func _give_up(tired: float) -> void:
	_tired = maxf(_tired, tired)
	_lost = 0.0
	jaws = 0.0
	_enter(State.FLOAT if afloat > 0.5 else State.RETURN)
	# (it goes back at its own pace, on its belly)


## What its going does to the water: rings where it swims, and a line of them over it when it is under,
## which is all there is to see of it then; a splash where it goes in off the bank.
func _wake(delta: float, speed: float) -> void:
	if pool == null or _rig == null:
		return
	var is_afloat := afloat > 0.5
	if is_afloat and not _was_afloat and speed > 1.0:
		pool.water.splash(global_position, clampf(speed / 4.0, 0.3, 1.0))
	_was_afloat = is_afloat
	if _water < 0.12 or speed < 0.25:
		return
	_ripple_timer -= delta * (0.6 + speed * 0.45)
	if _ripple_timer <= 0.0:
		_ripple_timer = 0.42
		# (under water it draws less of a line than it does swimming with its back out, but it draws one)
		pool.water.ripple(_rig.snout() - Vector3(sin(facing_yaw), 0.0, cos(facing_yaw)) * 0.5, 0.42 if submerged and afloat > 0.5 else 0.55)


# --- Its voice ---

## Now and then, with nothing else to do, it bellows.
func _speak(delta: float) -> void:
	_say_timer += delta
	if (state == State.FLOAT or state == State.BASK) and not dozing and _say_timer > 45.0 and randf() < delta / 30.0:
		_say(BELLOW)
		if state == State.FLOAT and pool:
			# (the water dances over its back)
			pool.water.ripple(global_position, 0.7)


func _say(which: int) -> void:
	_say_timer = 0.0
	if _voice == null or _voices.is_empty():
		return
	_voice.stream = _voices[which]
	_voice.pitch_scale = randf_range(0.9, 1.1)
	_voice.play()


## Makes its voice up: a hiss (breath through a narrow throat: noise, with the low end taken out), a
## bellow (a very low rough note that swells and dies), and the clap of its jaws shutting.
static func _make_voices() -> void:
	if not _voices.is_empty():
		return
	const RATE := 22050
	var noise := RandomNumberGenerator.new()
	noise.seed = 7
	for which in 3:
		var length: float = [1.1, 1.7, 0.16][which]
		var count := int(length * RATE)
		var data := PackedByteArray()
		data.resize(count * 2)
		var last := 0.0
		var low := 0.0
		var phase := 0.0
		for i in count:
			var t := float(i) / count
			var raw := noise.randf_range(-1.0, 1.0)
			var sample := 0.0
			match which:
				HISS:
					# (the difference of one sample from the last is noise with its low end gone)
					sample = (raw - last) * 0.5 * smoothstep(0.0, 0.12, t) * (1.0 - smoothstep(0.55, 1.0, t)) * (0.8 + 0.2 * sin(t * 60.0))
				BELLOW:
					phase += TAU * lerpf(62.0, 44.0, t) / RATE
					low = lerpf(low, raw, 0.04)
					var note := 0.0
					for harmonic in range(1, 7):
						note += sin(phase * harmonic) / harmonic
					# (it is not a steady note: it flutters, twenty times a second or so)
					sample = (note * 0.5 + low * 1.6) * (0.6 + 0.4 * sin(t * length * TAU * 19.0)) * smoothstep(0.0, 0.2, t) * (1.0 - smoothstep(0.6, 1.0, t))
				CLAP:
					low = lerpf(low, raw, 0.25)
					sample = (low * 1.5 + sin(t * 220.0) * 0.5) * exp(-t * 9.0)
			last = raw
			data.encode_s16(i * 2, int(clampf(sample * 0.6, -1.0, 1.0) * 32767.0))
		var stream := AudioStreamWAV.new()
		stream.format = AudioStreamWAV.FORMAT_16_BITS
		stream.mix_rate = RATE
		stream.data = data
		_voices.append(stream)
