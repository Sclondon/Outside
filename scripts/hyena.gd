class_name Hyena
extends CharacterBody3D
## A striped hyena: the hyena of Egypt, a scavenger that comes out at dusk,
## alone or in twos and threes, and is "very timid" of people by day and bolder
## by night (en.wikipedia.org/wiki/Striped_hyena).
##
## It is not a hunter of the boy as the hounds are. It hangs about him at a
## distance, watching: standing, then going round him at a walk or a lope, then
## standing again. Now and then it makes a rush at him with its mane up, and
## breaks off short and makes away again. How near it hangs about, how often it
## rushes, and how close a rush comes all go by its nerve (`_nerve`), which is
## its own boldness (`bold`) and what is going on:
##
## - it is bolder when he is down (limp, crawling or crouched), and when he is
##   alone (no brother or townsperson by him);
## - it is less bold near fire: a camp fire, a torch that is alight, a flare;
## - it gives way to anyone who runs at it, and will not rush someone who is
##   coming for it.
##
## Anything thrown that lands by it, any blow, any gunshot it hears and any
## fire brought near it sends it off at a gallop (`FLEE`), and it keeps well
## away for `shy_time` afterwards before its nerve comes back.
##
## Only a hyena whose nerve is over `BITES` (a bold one, with him down or alone
## in the dark) carries a rush through: then `caught` is emitted, as a hound's
## is. One of ordinary boldness never touches him.
##
## With no one about it wanders within `roam` of where it was put, stops, and
## puts its nose down to the ground.
##
## Everything it needs (collider, model, voice) is made here, so `Hyena.new()`
## is a whole one. It is animated by HyenaRig. Its voice is recordings
## (audio/hyenas/, and CREDITS.md there for where they came from, and for what
## they are and are not); without them, or with `voice` off, it is silent.

signal caught
## It opened its mouth.
signal voiced
## It has been driven off.
signal gave_way

enum State { ROAM, WATCH, CIRCLE, DART, RETREAT, FLEE }

## How bold it is, 0..1: see above. Under 0.25 it never rushes him at all.
@export_range(0.0, 1.0) var bold := 0.4
## How far off it hangs about him when it is at its most wary, and at its boldest (m).
@export var keep_distance := 12.0
@export var near_distance := 4.5
@export var walk_speed := 1.0
@export var lope_speed := 3.2
@export var run_speed := 7.0
@export var acceleration := 11.0
@export var turn_rate := 6.0
@export var gravity := 24.0
## How far it will stray from where it was put, while no one is about (m).
@export var roam := 12.0
## It takes notice of him when he is nearer than this (m).
@export var notice_distance := 26.0
## It will not go nearer than this to a fire (m), and runs from a gunshot nearer than `shot_fear`.
@export var fire_fear := 6.0
@export var shot_fear := 45.0
## How long it keeps well away after it has been driven off (s).
@export var shy_time := 14.0
@export var voice := true

var target: Player
## Whether it is rushing him (anything in the group `pursuers` says so with this).
var chasing := false
var state := State.ROAM
## How far its mane is raised, 0..1, and how frightened it is, 0..1. The rig shows both.
var bristle := 0.0
var afraid := 0.0
## Use the demade, low-poly model. Set before it enters the tree.
var low_poly := false
## Heading of the model, radians around Y. Zero faces +Z.
var facing_yaw := 0.0
## Render-rate position; the rig follows this.
var visual_position := Vector3.ZERO
## Somewhere to go, and how fast, instead of thinking for itself (the test
## stage uses this). Vector3.INF: nowhere.
var bidden := Vector3.INF
var bidden_speed := 1.0

var _spawn := Transform3D.IDENTITY
var _prev_pos := Vector3.ZERO
var _curr_pos := Vector3.ZERO
var _rig: HyenaRig
var _voice: AudioStreamPlayer3D
var _timer := 2.0
var _goal := Vector3.ZERO
var _face := Vector3.ZERO
## Which way round him it goes, when the next rush is due, how near this one is to come, and how long it has been at it.
var _side := 1.0
var _dart_timer := 8.0
var _dart_to := 2.0
var _dart_time := 0.0
## What it is running from, how long it has kept away, and how much longer it will.
var _threat := Vector3.ZERO
var _shy := 0.0
var _flinch := 0.0
var _find_timer := 0.0
var _hear_timer := 0.0
## The guns it is listening for.
var _guns: Array[Node] = []
var _say_timer := 6.0

## The recordings, by kind; which of each was played last; how loud each is
## through its length; when any of them last gave tongue (in physics frames); and where the
## fires are (looked for now and then, for all of them at once).
static var _bank := {}
static var _last_said := {}
static var _envelopes := {}
static var _searched := false
static var _pack_spoke := 0
static var _fires: Array[Node3D] = []
static var _fires_at := -100000

const VOICE_LEVEL := -12.0
const KINDS: Array[String] = ["giggle", "whoop"]
## The nerve it takes to carry a rush through and bring him down.
const BITES := 0.78
## The nerve under which it does not rush at all.
const RUSHES := 0.25


func _ready() -> void:
	add_to_group(&"hyenas")
	add_to_group(&"pursuers")
	# Like the hounds, it and the player pass through each other; only the world stops it.
	collision_layer = 4
	collision_mask = 1
	floor_snap_length = 0.3
	floor_max_angle = deg_to_rad(50.0)

	var shape := SphereShape3D.new()
	shape.radius = 0.32
	var collider := CollisionShape3D.new()
	collider.shape = shape
	collider.position.y = shape.radius
	add_child(collider)

	_load_voice()
	_voice = AudioStreamPlayer3D.new()
	_voice.unit_size = 9.0
	_voice.max_distance = 80.0
	_voice.volume_db = VOICE_LEVEL
	_voice.max_db = 0.0
	_voice.position.y = 0.7
	add_child(_voice)

	_rig = HyenaRig.new()
	_rig.low_poly = low_poly
	_rig.top_speed = run_speed
	add_child(_rig)
	_rig.top_level = true

	facing_yaw = global_rotation.y
	_spawn = global_transform
	_prev_pos = global_position
	_curr_pos = global_position
	visual_position = global_position
	_goal = global_position
	_side = 1.0 if get_tree().get_nodes_in_group(&"hyenas").size() % 2 == 1 else -1.0
	_timer = randf_range(1.0, 4.0)
	_dart_timer = randf_range(6.0, 14.0)
	_say_timer = randf_range(5.0, 20.0)


## Back where it was put, with its nerve as it began.
func reset() -> void:
	global_transform = _spawn
	velocity = Vector3.ZERO
	state = State.ROAM
	chasing = false
	_shy = 0.0
	_flinch = 0.0
	afraid = 0.0
	bristle = 0.0
	facing_yaw = _spawn.basis.get_euler().y
	_prev_pos = global_position
	_curr_pos = global_position
	visual_position = global_position


## Makes a rush at him now, whatever its nerve (it still breaks off as near as its nerve lets it come).
func dart() -> void:
	if target == null:
		return
	state = State.DART
	_dart_time = 0.0
	_dart_to = lerpf(3.4, 0.5, smoothstep(RUSHES, 0.9, _nerve()))
	_say("giggle")


func _physics_process(delta: float) -> void:
	var grounded := is_on_floor()
	var want := _think(delta) if grounded else Vector3(velocity.x, 0.0, velocity.z)
	if _flinch > 0.0:
		_flinch -= delta
		want = Vector3.ZERO
	if want.length_squared() > 0.01 and not _ground_under(global_position + want.normalized() * 0.9):
		want = Vector3.ZERO
	var current := Vector3(velocity.x, 0.0, velocity.z).move_toward(want, acceleration * delta)
	velocity.x = current.x
	velocity.z = current.z
	if not grounded:
		velocity.y -= gravity * delta
	move_and_slide()
	if global_position.y < -15.0:
		reset()
	_prev_pos = _curr_pos
	_curr_pos = global_position


func _process(delta: float) -> void:
	visual_position = _prev_pos.lerp(_curr_pos, Engine.get_physics_interpolation_fraction())
	var heading := Vector3(velocity.x, 0.0, velocity.z)
	var rate := turn_rate
	if heading.length_squared() <= 0.2 and _face.length_squared() > 0.01:
		# Standing, it turns to face what it is watching, not so sharply.
		heading = _face
		rate = turn_rate * 0.5
	if heading.length_squared() > 0.2 and _flinch <= 0.0:
		facing_yaw = lerp_angle(facing_yaw, atan2(heading.x, heading.z), 1.0 - exp(-rate * delta))
	_rig.bristle = bristle
	_rig.afraid = afraid
	_rig.global_position = visual_position
	_rig.rotation = Vector3(0.0, facing_yaw, 0.0)


## Hit with a fist, a boot or anything swung or thrown: it yelps and is off.
func struck(by: Node3D, impulse: Vector3) -> void:
	_hurt(by, impulse / 12.0, false)


## Hit by a gun: it staggers, and is off. It is never killed.
func shot(by: Node3D, _at: Vector3, direction: Vector3, _damage: float) -> void:
	_hurt(by, direction.normalized() * 3.0, true)


func _hurt(by: Node3D, push: Vector3, hard: bool) -> void:
	push.y = 0.0
	push = push.limit_length(5.0)
	velocity.x += push.x
	velocity.z += push.z
	_flinch = 0.35
	_rig.flinch(Basis(Vector3.UP, -facing_yaw) * push, hard)
	_flee(by.global_position if is_instance_valid(by) else global_position - push)
	_say("giggle", true)


## Off, away from `from`, as fast as it can go.
func _flee(from: Vector3) -> void:
	if state != State.FLEE:
		gave_way.emit()
	state = State.FLEE
	_threat = from
	_timer = randf_range(2.5, 4.0)
	_shy = shy_time
	chasing = false


## What it is about. Returns where it wants to go, and how fast.
func _think(delta: float) -> Vector3:
	_timer -= delta
	_find_timer -= delta
	_shy -= delta
	_face = Vector3.ZERO
	if target == null and _find_timer <= 0.0:
		_find_timer = 2.0
		var found := get_tree().root.find_children("*", "Player", true, false)
		if not found.is_empty():
			target = found[0]
	_listen(delta)
	_mutter(delta)
	_rig.sniffing = false
	_rig.gaze = null
	if bidden != Vector3.INF:
		var there := bidden - global_position
		there.y = 0.0
		afraid = 0.0
		return there.normalized() * bidden_speed if there.length() > 0.3 else Vector3.ZERO

	afraid = move_toward(afraid, 1.0 if state == State.FLEE else 0.0, delta * (4.0 if state == State.FLEE else 0.5))
	var here := global_position
	var to := target.global_position - here if target else Vector3.ZERO
	to.y = 0.0
	var distance := to.length()
	var towards := to.normalized() if distance > 0.01 else Vector3.FORWARD
	var noticed := target != null and distance < notice_distance
	chasing = state == State.DART

	# Fire: it will not stay by it. A fire brought right up to it sends it off.
	var fire := _nearest_fire(here)
	if fire != Vector3.INF and state != State.FLEE:
		var off := here.distance_to(fire)
		if off < fire_fear * 0.55 or (off < fire_fear and state == State.DART):
			_flee(fire)
	# Something thrown has come down by it.
	if state != State.FLEE:
		for thing: Node in get_tree().get_nodes_in_group(&"throwable"):
			var body := thing as RigidBody3D
			if body and not body.freeze and body.linear_velocity.length() > 3.5 and body.global_position.distance_to(here + Vector3.UP * 0.4) < 2.6:
				_flee(body.global_position - body.linear_velocity.normalized() * 2.0)
				_say("giggle", true)
				break

	if state == State.FLEE:
		bristle = move_toward(bristle, 0.0, delta * 0.6)
		var away := here - _threat
		away.y = 0.0
		if (_timer <= 0.0 and away.length() > keep_distance * 1.2) or away.length() > 40.0:
			state = State.WATCH if noticed else State.ROAM
			_timer = randf_range(3.0, 6.0)
			return Vector3.ZERO
		return (away.normalized() + _apart() * 0.4).normalized() * run_speed

	if not noticed:
		bristle = move_toward(bristle, 0.0, delta)
		return _wander()

	_rig.gaze = target
	var nerve := _nerve()
	# How far off it means to be: nearer the bolder it is, and well off while it is still shy of what drove it away.
	var ring := lerpf(keep_distance, near_distance, nerve) * (1.5 if _shy > 0.0 else 1.0)
	# He is coming for it: his speed towards it.
	var closing := -Vector3(target.velocity.x, 0.0, target.velocity.z).dot(towards)
	var pressed := closing > 2.2 and distance < ring + 2.0
	match state:
		State.DART:
			_dart_time += delta
			bristle = 1.0
			# It breaks off as near as it dares come; or sooner, if he turns on it; or if it is taking too long.
			if nerve >= BITES and distance < 0.9 and absf(target.global_position.y - here.y) < 0.9 and not target.is_limp:
				caught.emit()
				_break_off()
			elif (nerve < BITES and (distance < _dart_to + _stopping() or (closing > 1.2 and distance < 5.0))) or _dart_time > 6.0:
				_break_off()
			else:
				return towards * run_speed * 0.9
		State.RETREAT:
			bristle = move_toward(bristle, 0.0, delta * 0.5)
			if distance > ring or _timer <= 0.0:
				state = State.WATCH
				_timer = randf_range(2.0, 4.0)
			else:
				return (-towards + _apart() * 0.5).normalized() * run_speed * 0.85 if not (nerve >= BITES and distance < 1.2) else Vector3.ZERO
		State.ROAM, State.WATCH, State.CIRCLE:
			if state == State.ROAM:
				state = State.WATCH
				_timer = randf_range(1.5, 3.5)
			# Its mane comes up when he is close, or comes at it.
			bristle = move_toward(bristle, 1.0 if pressed or distance < ring * 0.6 else 0.0, delta * (4.0 if pressed else 0.7))
			if pressed or distance < ring - 2.5:
				# Too near: it gives ground, at a lope, and faster if he presses it.
				_face = to
				return (-towards * 0.85 + Vector3(towards.z, 0.0, -towards.x) * _side * 0.5 + _apart() * 0.5).normalized() * (run_speed * 0.8 if pressed and distance < ring * 0.6 else lope_speed)
			# When it has the nerve, and has waited long enough, it makes a rush at him.
			_dart_timer -= delta
			if _dart_timer <= 0.0 and nerve > RUSHES and _shy <= 0.0 and distance < ring + 4.0 and not _mate_darting():
				_dart_timer = lerpf(20.0, 5.0, nerve) * randf_range(0.7, 1.3)
				dart()
				return towards * run_speed * 0.9
			if distance > ring + 4.0:
				# Too far off to see what he is doing: it comes in, at a lope and then a walk.
				return (towards + _apart() * 0.5).normalized() * (lope_speed if distance > ring + 9.0 else walk_speed * 1.2)
			if _timer <= 0.0:
				if state == State.WATCH:
					state = State.CIRCLE
					_timer = randf_range(3.0, 7.0)
					_side = _own_side(towards)
				else:
					state = State.WATCH
					_timer = randf_range(2.0, 5.0)
			if state == State.WATCH:
				_face = to
				return _apart() * walk_speed
			# Round him, keeping its distance: at a walk, or a lope if it is being left behind.
			var round := Vector3(towards.z, 0.0, -towards.x) * _side
			var wish := (round + towards * clampf((distance - ring) * 0.4, -0.6, 0.6) + _apart() * 0.6).normalized()
			return wish * (lope_speed if nerve > 0.5 or distance > ring + 2.0 else walk_speed * 1.15)
	return Vector3.ZERO


## How far it goes before it can stop, at the speed it is going (m).
func _stopping() -> float:
	var speed := Vector2(velocity.x, velocity.z).length()
	return speed * speed / (2.0 * acceleration)


func _break_off() -> void:
	state = State.RETREAT
	_timer = randf_range(2.5, 4.0)
	chasing = false
	_say("giggle")


## How much nerve it has just now, 0..1.
func _nerve() -> float:
	if target == null:
		return 0.0
	var nerve := bold
	if target.is_limp or target.is_crawling or target.is_ducking:
		nerve += 0.3
	# Alone, or with someone by him
	var alone := true
	for figure: Node in get_tree().get_nodes_in_group(&"figures"):
		var keeper := figure.get_parent() as Node3D
		if keeper and keeper != target and (keeper is Brother or keeper is Townsperson) and keeper.global_position.distance_to(target.global_position) < 7.0:
			alone = false
			break
	nerve += 0.1 if alone else -0.2
	# How near he is to a fire
	var fire := _nearest_fire(target.global_position)
	if fire != Vector3.INF:
		nerve -= 0.5 * (1.0 - smoothstep(3.0, 12.0, fire.distance_to(target.global_position)))
	if _shy > 0.0:
		nerve -= 0.5
	return clampf(nerve, 0.0, 1.0)


## The nearest fire to a place (Vector3.INF: there is none): a fire, a torch that is alight, or a flare.
func _nearest_fire(place: Vector3) -> Vector3:
	var now := Engine.get_physics_frames()
	if now - _fires_at > 180:
		_fires_at = now
		_fires.clear()
		for fire: Node in get_tree().root.find_children("*", "Fire", true, false):
			_fires.append(fire)
	var nearest := 1000.0
	var found := Vector3.INF
	for fire in _fires:
		if is_instance_valid(fire) and fire.is_inside_tree() and fire.is_visible_in_tree() and fire.global_position.distance_to(place) < nearest:
			nearest = fire.global_position.distance_to(place)
			found = fire.global_position
	for flare: Node3D in get_tree().get_nodes_in_group(&"flares"):
		if flare.global_position.distance_to(place) < nearest:
			nearest = flare.global_position.distance_to(place)
			found = flare.global_position
	return found


## Gunfire: it listens for every gun there is, and a shot near enough sends it off.
func _listen(delta: float) -> void:
	_hear_timer -= delta
	if _hear_timer > 0.0:
		return
	_hear_timer = 1.5
	for gun: Node in get_tree().get_nodes_in_group(&"guns"):
		if gun.has_signal(&"fired") and gun not in _guns:
			_guns.append(gun)
			gun.connect(&"fired", _heard.bind(gun))


func _heard(gun: Node) -> void:
	var from := gun as Node3D
	if from and is_inside_tree() and from.global_position.distance_to(global_position) < shot_fear:
		_flee(from.global_position)


## Nothing to watch: it wanders about where it was put, stops, and noses at the ground.
func _wander() -> Vector3:
	if state != State.ROAM:
		state = State.ROAM
		_timer = randf_range(2.0, 5.0)
		_goal = global_position
	var to := _goal - global_position
	to.y = 0.0
	if to.length() > 0.6 and _timer > 0.0:
		return (to.normalized() + _apart() * 0.5).normalized() * walk_speed
	# Arrived (or given up): it noses about a while, and then picks somewhere else.
	_rig.sniffing = _timer > -5.0 and _timer < -1.0
	if _timer < -6.0 - randf() * 3.0:
		_timer = 14.0
		var away := Vector3(randf_range(-1.0, 1.0), 0.0, randf_range(-1.0, 1.0)).normalized() * randf_range(2.0, maxf(roam, 2.0))
		_goal = _spawn.origin + away
	return Vector3.ZERO


## Which way round him to go so as not to follow another hyena round: away from the nearest.
func _own_side(towards: Vector3) -> float:
	var nearest := 9.0
	var side := 1.0 if randf() < 0.5 else -1.0
	for other: Node3D in get_tree().get_nodes_in_group(&"hyenas"):
		var off := other.global_position - global_position
		off.y = 0.0
		if other != self and off.length() < nearest:
			nearest = off.length()
			side = -signf(Vector3(towards.z, 0.0, -towards.x).dot(off))
	return side if side != 0.0 else 1.0


## Keeps them from going about as one.
func _apart() -> Vector3:
	var push := Vector3.ZERO
	for other: Node3D in get_tree().get_nodes_in_group(&"hyenas"):
		if other == self:
			continue
		var away := global_position - other.global_position
		away.y = 0.0
		var distance := away.length()
		if distance < 3.5 and distance > 0.001:
			push += away / distance * (1.0 - distance / 3.5)
	return push


func _mate_darting() -> bool:
	for other: Hyena in get_tree().get_nodes_in_group(&"hyenas"):
		if other != self and other.state == State.DART:
			return true
	return false


## Whether there is ground to stand on at `point`, and it is not deep water.
func _ground_under(point: Vector3) -> bool:
	var query := PhysicsRayQueryParameters3D.create(point + Vector3.UP * 0.8, point + Vector3.DOWN * 1.4, 1)
	var found := get_world_3d().direct_space_state.intersect_ray(query)
	if found.is_empty():
		return false
	for pool: Node in get_tree().get_nodes_in_group(&"water"):
		if pool is Pool and (pool as Pool).depth_at(found.position) > 0.35:
			return false
	return true


## Now and then, while it has him to watch: a whoop from a long way off, a cackle from near.
func _mutter(delta: float) -> void:
	_say_timer -= delta
	if _say_timer > 0.0:
		return
	_say_timer = randf_range(9.0, 24.0)
	if target == null or state == State.FLEE or state == State.ROAM:
		return
	var distance := target.global_position.distance_to(global_position)
	if distance < notice_distance:
		_say("whoop" if distance > keep_distance * 0.8 and randf() < 0.6 else "giggle")


## Plays one of the recordings of a kind, not the one that was played last.
## Another of them that has this moment opened its mouth is waited for, unless
## it is `urgent`.
func _say(kind: String, urgent := false) -> void:
	var takes: Array = _bank.get(kind, _bank.get("giggle", []))
	if takes.is_empty() or not voice or _voice == null:
		return
	if not urgent and (_voice.playing or Engine.get_physics_frames() - _pack_spoke < 30):
		return
	var pick := randi() % takes.size()
	if takes.size() > 1 and pick == _last_said.get(kind, -1):
		pick = (pick + 1 + randi() % (takes.size() - 1)) % takes.size()
	_last_said[kind] = pick
	var stream: AudioStream = takes[pick]
	var rate := randf_range(0.92, 1.06)
	_voice.stream = stream
	_voice.pitch_scale = rate
	_voice.volume_db = VOICE_LEVEL + randf_range(-2.0, 1.0)
	_voice.play()
	_pack_spoke = Engine.get_physics_frames()
	_say_timer = maxf(_say_timer, 5.0)
	_rig.speak(rate, stream.get_length(), _envelopes.get(stream, PackedFloat32Array()))
	voiced.emit()


## Finds the recordings (audio/hyenas/<kind>_<number>.wav), and measures how
## loud each is through its length. Without them it has no voice.
static func _load_voice() -> void:
	if _searched:
		return
	_searched = true
	for kind in KINDS:
		var takes: Array = []
		for number in range(1, 20):
			var path := "res://audio/hyenas/%s_%d.wav" % [kind, number]
			if not ResourceLoader.exists(path):
				break
			var stream := load(path) as AudioStream
			if stream == null:
				break
			takes.append(stream)
			_envelopes[stream] = Hound._loudness(stream as AudioStreamWAV)
		if not takes.is_empty():
			_bank[kind] = takes
