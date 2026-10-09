class_name Hound
extends CharacterBody3D
## A hound that runs the player down, baying as it comes.
##
## It heads straight for its target, hops steps, leaps obstacles and gaps it can
## clear, and holds at the edge of one it cannot. When it cannot get at him at
## all it drops onto braced forepaws under him and barks. Left alone it plays
## with another hound for a while, and then sits, and lies down, and sleeps,
## until it is set on him again. Everything it needs (collider, model, voice)
## is made here, so `Hound.new()` is a complete hound.
##
## Its voice is recordings of dogs (audio/hounds/, and CREDITS.md there for
## where they came from): several of each kind of sound, never the same one
## twice running, pitched a little differently every time, and lower for the
## bloodhound than for the pharaoh hound. If the recordings are missing it
## falls back on a voice made up in code (`_make_voice`).

signal caught
## It gave tongue: a short bark, or else a long bay.
signal bayed(bark: bool)
## It has been shot at more than it can stand, and has broken off.
signal broke

## How it is holding itself. The rig (HoundRig) works out the rest.
enum Posture { UP, BOW, SIT, LIE }
## ANY takes turns: the first hound in a scene is a bloodhound, the next a pharaoh hound, and so on.
enum Breed { ANY, BLOODHOUND, PHARAOH }
enum Game { NONE, CLOSE, BOW, DART, CIRCLE, LUNGE, STRETCH }

## Which kind of hound: the bloodhound, heavy, with long hanging ears, or the
## pharaoh hound, lean, with ears that stand. Set before it enters the tree.
@export var breed := Breed.ANY
@export var run_speed := 5.4
@export var trot_speed := 2.4
@export var acceleration := 16.0
@export var turn_rate := 9.0
@export var jump_height := 1.3
@export var gravity := 24.0
## Touching distance: closer than this and the chase is over.
@export var catch_distance := 0.8
## The widest gap it will throw itself across.
@export var leap_distance := 2.8
## Left to itself it plays with another hound for about this long (seconds; 0: it does not)...
@export var play_time := 11.0
## ...then stands about for this long before it sits, and sits for this long before it lies down.
@export var settle_after := 4.0
@export var sleep_after := 6.0
## How far it will stray from where it was put, while nothing is asked of it.
@export var roam := 2.5
## How much gunfire it will take (the sum of the `damage` of what hits it) before
## its nerve goes and it breaks off and runs; how long it then keeps away
## (seconds) before it comes again, with half of that still on its mind; and how
## long after any blow it keeps its distance and circles.
@export var nerve := 60.0
@export var cowed_time := 9.0
@export var wary_time := 3.5
## It will not go nearer than this to a burning flare (m).
@export var flare_fear := 4.5

var target: Player
var chasing := false
## Use the demade, low-poly model. Set before the hound enters the tree.
var low_poly := false
## Heading of the model, radians around Y. Zero faces +Z.
var facing_yaw := PI * 0.5
## Render-rate position; the rig follows this.
var visual_position := Vector3.ZERO
var posture := Posture.UP
## How pleased with itself it is, 0..1: what its tail says.
var playful := 0.0
## How far down a bow goes, 0..1: right down in play, a brace when it is baffled.
var bow_depth := 1.0
## How much faster than it was recorded its voice is being played, how long what
## it is saying lasts (s, as recorded), and how loud that is sixty times a
## second, 0..1 (empty: not known). Its jaw keeps time with these.
var voice_rate := 1.0
var voice_length := 0.2
var voice_envelope := PackedFloat32Array()
## Somewhere to go, and how fast, instead of thinking for itself (the test
## stage uses this). Vector3.INF: nowhere.
var bidden := Vector3.INF
var bidden_speed := 1.0

var _spawn := Transform3D.IDENTITY
var _prev_pos := Vector3.ZERO
var _curr_pos := Vector3.ZERO
var _jump_cooldown := 0.0
var _bay_timer := 0.0
var _held := false
var _voice: AudioStreamPlayer3D
## What it says under its breath: growls, whines, panting.
var _murmur: AudioStreamPlayer3D
var _murmur_timer := 2.0
## How its voice is pitched beside the next hound's.
var _voice_pitch := 1.0
var _rig: HoundRig
## Which way to stand facing while it is not going anywhere.
var _face := Vector3.ZERO
## Getting up off the ground takes a moment.
var _rise := 0.0
## Baffled: how much longer it stays braced and barking, how long before it can
## be again, and what it measures its progress from.
var _brace := 0.0
var _brace_rest := 0.0
var _brace_mark := Vector3.ZERO
var _baffled := false
var _backing := false
var _progress_timer := 0.0
var _progress_from := Vector3.ZERO
var _progress_gap := 0.0
## At a loose end: how long it has been, how much play is left in it, what it
## is doing in the game and for how much longer, and which way it is going.
var _was_chasing := false
var _pleased := 0.0
var _idle_time := 0.0
var _play_left := 0.0
var _game := Game.NONE
var _game_timer := 0.0
var _game_side := 1.0
var _nap := 30.0
## Hurt: how much gunfire it has taken, how much longer it is reeling from the
## last blow, keeping its distance, and keeping away altogether, and who did it.
var _harm := 0.0
var _flinch := 0.0
var _wary := 0.0
var _cowed_for := 0.0
var _scared_of: Node3D
## How frightened it is, 0..1: running from gunfire, or shying from a flare. What its tail and ears say.
var afraid := 0.0

static var _voices: Array[AudioStreamWAV] = []
## The recordings, by kind (bark_deep, bark_sharp, yap, bay, whine, growl, pant,
## snap); which of each kind was played last; how loud each is through its
## length; and when any hound last gave tongue (ms).
static var _bank := {}
static var _last_said := {}
static var _envelopes := {}
static var _pack_spoke := 0

## How loud its voice is, dB: well under full, so that it carries without hurting close to.
const VOICE_LEVEL := -11.0
const MURMUR_LEVEL := -17.0
const KINDS: Array[String] = ["bark_deep", "bark_sharp", "yap", "bay", "whine", "growl", "pant", "snap"]


func _ready() -> void:
	add_to_group(&"hounds")
	add_to_group(&"pursuers")
	# Hounds and the player pass through each other; only the world stops them.
	collision_layer = 4
	collision_mask = 1
	floor_snap_length = 0.25
	floor_max_angle = deg_to_rad(50.0)

	var shape := SphereShape3D.new()
	shape.radius = 0.26
	var collider := CollisionShape3D.new()
	collider.shape = shape
	collider.position.y = shape.radius
	add_child(collider)

	_load_voices()
	_voice = AudioStreamPlayer3D.new()
	_voice.unit_size = 7.0
	_voice.max_distance = 70.0
	_voice.volume_db = VOICE_LEVEL
	_voice.max_db = 0.0
	_voice.position.y = 0.6
	add_child(_voice)
	_murmur = AudioStreamPlayer3D.new()
	_murmur.unit_size = 4.0
	_murmur.max_distance = 30.0
	_murmur.volume_db = MURMUR_LEVEL
	_murmur.max_db = 0.0
	_murmur.position.y = 0.6
	add_child(_murmur)

	if breed == Breed.ANY:
		breed = Breed.BLOODHOUND if get_tree().get_nodes_in_group(&"hounds").size() % 2 == 1 else Breed.PHARAOH
	# The bloodhound's voice is the deeper.
	_voice_pitch = 0.9 if breed == Breed.BLOODHOUND else 1.08
	_rig = HoundRig.new()
	_rig.breed = 0 if breed == Breed.BLOODHOUND else 1
	_rig.low_poly = low_poly
	add_child(_rig)
	_rig.top_level = true

	_spawn = global_transform
	reset()


## Back to where it started, waiting to be let loose again.
func reset() -> void:
	global_transform = _spawn
	velocity = Vector3.ZERO
	chasing = false
	facing_yaw = PI * 0.5
	_bay_timer = randf_range(0.0, 0.6)
	_prev_pos = global_position
	_curr_pos = global_position
	visual_position = global_position
	posture = Posture.UP
	_brace = 0.0
	_rise = 0.0
	_pleased = 0.0
	_was_chasing = false
	_harm = 0.0
	_flinch = 0.0
	_wary = 0.0
	_cowed_for = 0.0
	afraid = 0.0
	_loose_end()


func _physics_process(delta: float) -> void:
	var grounded := is_on_floor()
	# Where it wants to be going, and how fast.
	var want := Vector3.ZERO
	_held = false
	_face = Vector3.ZERO
	_jump_cooldown -= delta
	if bidden != Vector3.INF:
		var to := bidden - global_position
		to.y = 0.0
		posture = Posture.UP
		playful = 0.0
		want = to.normalized() * bidden_speed if to.length() > 0.2 else Vector3.ZERO
	elif chasing and target:
		var to := target.global_position - global_position
		var flat := Vector3(to.x, 0.0, to.z)
		if flat.length() < catch_distance and absf(to.y) < 0.9 and _flinch <= 0.0 and _wary <= 0.0 and afraid <= 0.0:
			if _pleased <= 0.0:
				_say("snap", 0.95, 1.1, _voice)
			_pleased = 4.0
			caught.emit()
			return
		if not _was_chasing:
			_progress_timer = 0.0
			_progress_from = global_position
			_progress_gap = to.length()
		_was_chasing = true
		playful = 0.0
		if posture == Posture.SIT or posture == Posture.LIE:
			_rise = 0.3 if posture == Posture.SIT else 0.5
			# Woken and set on him: it is up with a growl.
			_say("growl", 0.9, 1.1, _murmur)
		_rise -= delta
		if _rise <= 0.0:
			want = _hunt(delta, to, flat, grounded)
		posture = Posture.BOW if _brace > 0.0 and not _backing and grounded else Posture.UP
		bow_depth = 0.6
	else:
		want = _idle(delta)

	want = _react(delta, want)
	var current := Vector3(velocity.x, 0.0, velocity.z).move_toward(want, acceleration * (0.3 if _flinch > 0.0 else 1.0) * delta)
	velocity.x = current.x
	velocity.z = current.z
	if not grounded:
		velocity.y -= gravity * delta
	move_and_slide()

	_mutter(delta)
	_bay_timer -= delta
	if _bay_timer <= 0.0 and Time.get_ticks_msec() - _pack_spoke < 170:
		# Another of the pack has this moment opened its mouth: this one waits its turn.
		_bay_timer = randf_range(0.12, 0.3)
	if _bay_timer <= 0.0:
		if chasing and _rise <= 0.0 and afraid <= 0.0 and _flinch <= 0.0:
			_bay()
		elif _game == Game.BOW:
			_yap()
	if global_position.y < -15.0:
		reset()
	_prev_pos = _curr_pos
	_curr_pos = global_position


func _process(delta: float) -> void:
	visual_position = _prev_pos.lerp(_curr_pos, Engine.get_physics_interpolation_fraction())
	var heading := Vector3(velocity.x, 0.0, velocity.z)
	var rate := turn_rate
	if heading.length_squared() <= 0.2 and _face != Vector3.ZERO:
		# Standing, it turns to face what it is barking at, not so sharply.
		heading = _face
		rate = turn_rate * 0.6
	# (knocked back, it does not turn to face the way it is thrown)
	if heading.length_squared() > 0.2 and _flinch <= 0.0:
		facing_yaw = lerp_angle(facing_yaw, atan2(heading.x, heading.z), 1.0 - exp(-rate * delta))
	_rig.global_position = visual_position
	_rig.rotation = Vector3(0.0, facing_yaw, 0.0)


## Hit with a fist, a boot or anything swung (the brother calls this, and so
## does a gun on whatever has no `shot`): it yelps, is knocked the way the blow
## went, and for a while afterwards keeps its distance and circles.
func struck(by: Node3D, impulse: Vector3) -> void:
	_hurt(by, impulse / 12.0, 0.45, false)


## Hit by a gun: it staggers, its hindquarters giving under it. Past `nerve`
## in all, its nerve goes: it breaks off and runs from whoever shot it, tail
## between its legs, and keeps away for `cowed_time`. It is never killed.
func shot(by: Node3D, _at: Vector3, direction: Vector3, damage: float) -> void:
	_harm += damage
	_hurt(by, direction.normalized() * 3.0, 0.7, true)
	if _harm >= nerve and _cowed_for <= 0.0:
		_cowed_for = cowed_time
		broke.emit()


func _hurt(by: Node3D, push: Vector3, time: float, hard: bool) -> void:
	_scared_of = by
	push.y = 0.0
	push = push.limit_length(5.0)
	velocity.x += push.x
	velocity.z += push.z
	if is_on_floor():
		velocity.y = 1.2 if hard else 2.0
	_flinch = time
	_wary = wary_time
	_brace = 0.0
	_pleased = 0.0
	# (if it was asleep, it is not now)
	_idle_time = 0.0
	posture = Posture.UP
	if not _bank.is_empty():
		_say("yap", 1.25, 1.45, _voice)
		_bay_timer = voice_length / voice_rate + randf_range(0.8, 1.5)
		bayed.emit(true)
	if _rig:
		_rig.flinch(Basis(Vector3.UP, -facing_yaw) * push, hard)


## What being hurt or frightened does to where it is going. Reeling from a
## blow it goes nowhere of its own will; its nerve gone, it runs from whoever
## broke it; it will not go near a burning flare; and wary, it circles him out
## of reach instead of closing.
func _react(delta: float, want: Vector3) -> Vector3:
	_flinch -= delta
	_wary -= delta
	if _cowed_for > 0.0:
		_cowed_for -= delta
		if _cowed_for <= 0.0:
			# It comes again, with less heart for it.
			_harm *= 0.5
	var shy := Vector3.ZERO
	for flare: Node3D in get_tree().get_nodes_in_group(&"flares"):
		var off := global_position - flare.global_position
		off.y = 0.0
		var distance := off.length()
		if distance < flare_fear and distance > 0.01:
			shy += off / distance * (1.0 - distance / flare_fear)
	afraid = move_toward(afraid, 1.0 if _cowed_for > 0.0 or shy != Vector3.ZERO else 0.0, delta * 4.0)
	var run := want
	if _flinch > 0.0:
		run = Vector3.ZERO
	elif _cowed_for > 0.0:
		var from: Node3D = _scared_of if is_instance_valid(_scared_of) else target
		var away := global_position - from.global_position if from else Vector3.ZERO
		away.y = 0.0
		run = away.normalized() * run_speed if away.length() < 14.0 else Vector3.ZERO
		_face = -away
	elif shy != Vector3.ZERO:
		run = shy.normalized() * run_speed * clampf(shy.length() * 2.5, 0.4, 1.0)
		_face = -shy
	elif _wary > 0.0 and chasing and target and bidden == Vector3.INF:
		var to := target.global_position - global_position
		to.y = 0.0
		if to.length() > 3.0:
			return want
		_face = to
		var round := Vector3(to.z, 0.0, -to.x).normalized() * _game_side
		run = (round * 0.7 - to.normalized() * (3.0 - to.length())).normalized() * trot_speed
	else:
		return want
	posture = Posture.UP
	_brace = 0.0
	_held = false
	if run != Vector3.ZERO and not _ground_under(global_position + run.normalized() * 0.8):
		run = Vector3.ZERO
	return run


## After him. Returns where to run; braces instead when it is getting nowhere.
func _hunt(delta: float, to: Vector3, flat: Vector3, grounded: bool) -> Vector3:
	# Is it getting anywhere? Neither covering ground nor closing on him, for a
	# second: he is up on something, or behind something.
	_brace_rest -= delta
	_progress_timer += delta
	if _progress_timer > 1.0:
		var gone := global_position - _progress_from
		gone.y = 0.0
		_baffled = gone.length() < 1.2 and _progress_gap - to.length() < 0.3 and flat.length() < 7.0
		_progress_timer = 0.0
		_progress_from = global_position
		_progress_gap = to.length()
	if _baffled and _brace <= 0.0 and _brace_rest <= 0.0 and grounded:
		_baffled = false
		_brace = randf_range(1.6, 2.8)
		_brace_mark = target.global_position
	if _brace > 0.0:
		_held = true
		_face = flat
		# It wants room in front of it first.
		_backing = grounded and test_move(global_transform, flat.normalized() * 0.8)
		if _backing:
			return -flat.normalized() * trot_speed
		# Down on its forepaws, rump in the air, telling the world.
		_brace -= delta
		# It is up again when it has had its say, or as soon as he moves off.
		if target.global_position.distance_to(_brace_mark) > 1.5:
			_brace = 0.0
		if _brace <= 0.0:
			_brace_rest = randf_range(1.5, 2.5)
			_progress_timer = 0.0
			_progress_from = global_position
			# As often as not it comes up out of it with a spring at him.
			if to.y > 0.7 and randf() < 0.6:
				_jump(jump_height)
		return Vector3.ZERO

	var wish := (flat.normalized() + _spread() * 0.6).normalized()
	if grounded:
		wish = _negotiate(wish, to)
	if _held:
		_face = flat
		if _brace_rest <= 0.0:
			_brace = randf_range(1.2, 2.2)
			_brace_mark = target.global_position
	return wish * run_speed


## Nothing asked of it. Returns where to go.
func _idle(delta: float) -> Vector3:
	if _was_chasing:
		_was_chasing = false
		_loose_end()
	_idle_time += delta
	_pleased -= delta
	_brace = 0.0
	var want := Vector3.ZERO
	var mate := _playmate()
	if _game == Game.STRETCH:
		# Just woken: a long stretch, forepaws out, before anything else.
		posture = Posture.BOW
		bow_depth = 1.0
		playful = 0.0
		_game_timer -= delta
		if _game_timer <= 0.0:
			_loose_end()
	elif mate and _play_left > 0.0 and _pleased <= 0.0:
		_play_left -= delta
		playful = 1.0
		_idle_time = 0.0
		want = _play(delta, mate)
	else:
		_game = Game.NONE
		playful = 1.0 if _pleased > 0.0 else 0.0
		# He is near: it is not going to sleep with him standing there.
		var watched := target != null and target.global_position.distance_to(global_position) < 4.0
		if _pleased > 0.0 or _idle_time < settle_after:
			posture = Posture.UP
		elif _idle_time < settle_after + sleep_after or watched:
			posture = Posture.SIT
			_idle_time = minf(_idle_time, settle_after + sleep_after)
		elif _idle_time < settle_after + sleep_after + _nap:
			posture = Posture.LIE
		else:
			_game = Game.STRETCH
			_game_timer = 1.6

	# Not off the edge of anything, and not far from where it was put.
	var home := _spawn.origin - global_position
	home.y = 0.0
	if home.length() > roam:
		want = want * 0.4 + home.normalized() * trot_speed
	if want != Vector3.ZERO and not _ground_under(global_position + want.normalized() * 0.8):
		want = Vector3.ZERO
	return want


## Starts it off idle: with some play in it, if it has any.
func _loose_end() -> void:
	_idle_time = 0.0
	_play_left = play_time * randf_range(0.7, 1.3)
	_game = Game.NONE
	_game_timer = randf_range(0.3, 1.2)
	_nap = randf_range(25.0, 45.0)


## The other hound, if it is near and in the mood.
func _playmate() -> Hound:
	if not is_inside_tree():
		return null
	var nearest := 8.0
	var mate: Hound = null
	for other: Hound in get_tree().get_nodes_in_group(&"hounds"):
		var distance := other.global_position.distance_to(global_position)
		if other != self and not other.chasing and other._play_left > 0.0 and other.bidden == Vector3.INF and distance < nearest:
			nearest = distance
			mate = other
	return mate


## A game with another hound: bows, barks, sudden jumps aside, a run round it,
## a rush at it. Each lasts a second or so, and then it thinks of another.
func _play(delta: float, mate: Hound) -> Vector3:
	var to := mate.global_position - global_position
	to.y = 0.0
	var distance := to.length()
	var towards := to.normalized() if distance > 0.01 else Vector3.FORWARD
	var across := Vector3(towards.z, 0.0, -towards.x) * _game_side
	_face = to
	_game_timer -= delta
	if _game_timer <= 0.0:
		_game_side = 1.0 if randf() < 0.5 else -1.0
		var pick := randf()
		if distance > 2.4:
			_game = Game.CLOSE
			_game_timer = 1.5
		elif pick < 0.42:
			_game = Game.BOW
			_game_timer = randf_range(0.9, 1.7)
			_bay_timer = randf_range(0.15, 0.5)
		elif pick < 0.65 and is_on_floor():
			# A jump aside, all four feet off the ground.
			_game = Game.DART
			_game_timer = 0.45
			var away := across * 3.2 - towards * 1.2
			velocity = Vector3(away.x, sqrt(2.0 * gravity * 0.16), away.z)
		elif pick < 0.85:
			_game = Game.CIRCLE
			_game_timer = randf_range(0.9, 1.6)
		else:
			_game = Game.LUNGE
			_game_timer = 0.5

	posture = Posture.BOW if _game == Game.BOW else Posture.UP
	bow_depth = 1.0
	var want := Vector3.ZERO
	match _game:
		Game.CLOSE:
			if distance > 1.6:
				want = towards * trot_speed
			else:
				_game_timer = 0.0
		Game.DART:
			want = across * 2.0 - towards * 0.8
		Game.CIRCLE:
			want = (across + towards * (distance - 1.7)).normalized() * trot_speed * 1.5
		Game.LUNGE:
			want = towards * run_speed * 0.8 if distance > 1.1 else -towards * trot_speed
	return want + _spread() * 2.0


## Deals with whatever lies between here and there. Returns the direction to run.
func _negotiate(wish: Vector3, to: Vector3) -> Vector3:
	var here := global_position
	if not _ground_under(here + wish * 0.8):
		for reach: float in [1.7, leap_distance]:
			if _ground_under(here + wish * reach):
				_jump(jump_height * 0.6)
				return wish
		# Too far to leap: stand at the edge and give tongue.
		_held = true
		return Vector3.ZERO

	var hit := KinematicCollision3D.new()
	# Something it could never get over: it does not throw itself at it, but
	# stops short, where it has room to tell the world about it.
	var too_tall := test_move(global_transform.translated(Vector3.UP * (jump_height - 0.1)), wish)
	if too_tall and test_move(global_transform, wish * 0.8, hit) and hit.get_normal().y < 0.6:
		_held = true
		return Vector3.ZERO
	if test_move(global_transform, wish * 0.3, hit) and hit.get_normal().y < 0.6:
		# A step gets a hop, anything taller the full leap.
		var over_it := not test_move(global_transform.translated(Vector3.UP * 0.4), wish * 0.4)
		_jump(0.35 if over_it else jump_height)
	elif to.y > 0.7 and Vector2(to.x, to.z).length() < 1.6:
		# He is just overhead: a snap at his heels if they are in reach, and if not it stays down.
		if to.y < jump_height + 0.6:
			_jump(jump_height)
		else:
			_held = true
			return Vector3.ZERO
	return wish


func _jump(height: float) -> void:
	if _jump_cooldown > 0.0:
		return
	_jump_cooldown = 0.3
	velocity.y = sqrt(2.0 * gravity * height)


func _ground_under(point: Vector3) -> bool:
	var query := PhysicsRayQueryParameters3D.create(point + Vector3.UP * 0.6, point + Vector3.DOWN * 1.2, 1)
	return not get_world_3d().direct_space_state.intersect_ray(query).is_empty()


## Keeps the pack from running as one dog.
func _spread() -> Vector3:
	var push := Vector3.ZERO
	for other: Hound in get_tree().get_nodes_in_group(&"hounds"):
		if other == self:
			continue
		var away := global_position - other.global_position
		away.y = 0.0
		var distance := away.length()
		if distance < 1.0 and distance > 0.001:
			push += away / distance * (1.0 - distance)
	return push


func _bay() -> void:
	# The bloodhound mostly bays, long; the pharaoh hound mostly barks. Either
	# barks when it is held up or closing in.
	var close := target != null and global_position.distance_to(target.global_position) < 4.0
	var barky := 0.25 if breed == Breed.BLOODHOUND else 0.6
	var bark := _held or (close and randf() < 0.7) or randf() < barky
	if _bank.is_empty():
		_voice.stream = _voices[1 if bark else 0]
		voice_rate = randf_range(0.88, 1.12) * _voice_pitch
		voice_length = 0.2 if bark else 0.75
		voice_envelope = PackedFloat32Array()
		_voice.pitch_scale = voice_rate
		_voice.play()
	elif bark:
		_say("bark_deep" if breed == Breed.BLOODHOUND else "bark_sharp", 0.93, 1.07, _voice)
	else:
		_say("bay", 0.92, 1.06, _voice)
	# It draws breath before the next: longer after a bay, and never a steady beat.
	var spoken := voice_length / voice_rate
	_bay_timer = spoken + (randf_range(0.3, 1.0) if bark else randf_range(1.2, 3.0))
	if bark and randf() < 0.35:
		# (now and then two together)
		_bay_timer = spoken + 0.08
	bayed.emit(bark)


## The bark it plays with: a smaller dog's, or the same one, higher.
func _yap() -> void:
	if _bank.is_empty():
		_voice.stream = _voices[1]
		voice_rate = randf_range(1.15, 1.35) * _voice_pitch
		voice_length = 0.2
		voice_envelope = PackedFloat32Array()
		_voice.pitch_scale = voice_rate
		_voice.play()
	else:
		_say("yap", 0.8, 0.95, _voice)
	_bay_timer = voice_length / voice_rate + randf_range(0.4, 1.1)
	bayed.emit(true)


## What it says under its breath, when it is not giving tongue: a growl when it
## is baffled, a whine when it is kept waiting, and its panting after a run.
func _mutter(delta: float) -> void:
	_murmur_timer -= delta
	if _murmur_timer > 0.0 or _murmur.playing or _bank.is_empty():
		return
	_murmur_timer = randf_range(1.5, 3.5)
	if _cowed_for > 0.0:
		_say("whine", 1.0, 1.2, _murmur)
	elif chasing and (_brace > 0.0 or _wary > 0.0):
		if randf() < 0.5:
			_say("growl", 0.85, 1.05, _murmur)
	elif not chasing and posture == Posture.SIT and target != null and target.global_position.distance_to(global_position) < 4.0:
		if randf() < 0.3:
			_say("whine", 0.95, 1.15, _murmur)
	elif _rig and _rig.puffed() > 0.5 and not _voice.playing:
		_say("pant", 0.95, 1.08, _murmur)
		_murmur_timer = 0.1


## Plays one of the recordings of a kind, not the one that was played last,
## at a pitch somewhere between `low` and `high` times this hound's own.
func _say(kind: String, low: float, high: float, through: AudioStreamPlayer3D) -> void:
	var takes: Array = _bank.get(kind, [])
	if takes.is_empty():
		return
	var pick := randi() % takes.size()
	if takes.size() > 1 and pick == _last_said.get(kind, -1):
		pick = (pick + 1 + randi() % (takes.size() - 1)) % takes.size()
	_last_said[kind] = pick
	var stream: AudioStream = takes[pick]
	var rate := randf_range(low, high) * _voice_pitch
	through.stream = stream
	through.pitch_scale = rate
	through.volume_db = (VOICE_LEVEL if through == _voice else MURMUR_LEVEL) + randf_range(-2.0, 1.0)
	through.play()
	if through == _voice:
		voice_rate = rate
		voice_length = stream.get_length()
		voice_envelope = _envelopes.get(stream, PackedFloat32Array())
		_pack_spoke = Time.get_ticks_msec()


## Finds the recordings (audio/hounds/<kind>_<number>.wav), and measures how
## loud each is through its length. Without them, makes the voice up instead.
static func _load_voices() -> void:
	if not _bank.is_empty() or not _voices.is_empty():
		return
	for kind in KINDS:
		var takes: Array = []
		for number in range(1, 20):
			var path := "res://audio/hounds/%s_%d.wav" % [kind, number]
			if not ResourceLoader.exists(path):
				break
			var stream := load(path) as AudioStream
			if stream == null:
				break
			takes.append(stream)
			_envelopes[stream] = _loudness(stream as AudioStreamWAV)
		if not takes.is_empty():
			_bank[kind] = takes
	if not (_bank.has("bark_deep") and _bank.has("bark_sharp") and _bank.has("bay")):
		_bank.clear()
		_voices = [_make_voice(true), _make_voice(false)]
	elif not _bank.has("yap"):
		_bank["yap"] = _bank["bark_sharp"]


## How loud a recording is, sixty times a second through its length, 0..1.
## Empty if it is not kept as plain 16-bit samples.
static func _loudness(stream: AudioStreamWAV) -> PackedFloat32Array:
	var levels := PackedFloat32Array()
	if stream == null or stream.format != AudioStreamWAV.FORMAT_16_BITS:
		return levels
	var step := (2 if stream.stereo else 1) * 2
	var hop := maxi(stream.mix_rate / 60, 1)
	var count := stream.data.size() / step
	var top := 0.001
	for from in range(0, count, hop):
		var peak := 0.0
		# (every fourth sample is enough to find how loud it is)
		for i in range(from, mini(from + hop, count), 4):
			peak = maxf(peak, absf(stream.data.decode_s16(i * step) / 32768.0))
		levels.append(peak)
		top = maxf(top, peak)
	for i in levels.size():
		levels[i] /= top
	return levels


## Synthesises a hound's voice: a harmonic tone pushed through two throat
## resonances, with a rasp under it. `long` is a bay, otherwise a bark.
static func _make_voice(long: bool) -> AudioStreamWAV:
	const RATE := 22050
	var count := int((0.75 if long else 0.2) * RATE)
	var data := PackedByteArray()
	data.resize(count * 2)
	var noise := RandomNumberGenerator.new()
	noise.seed = 3
	var phase := 0.0
	for i in count:
		var t := float(i) / count
		# A bay swells up and falls away slowly; a bark just drops.
		var pitch := 230.0 + 210.0 * sin(PI * pow(t, 0.55)) if long else lerpf(520.0, 240.0, pow(t, 0.6))
		phase += TAU * pitch / RATE
		var sample := 0.0
		for harmonic in range(1, 9):
			var frequency := pitch * harmonic
			var throat := 0.25 + exp(-pow((frequency - 750.0) / 300.0, 2.0)) + 0.6 * exp(-pow((frequency - 1500.0) / 400.0, 2.0))
			sample += sin(phase * harmonic) * throat / harmonic
		sample *= 1.0 + 0.35 * sin(phase * 0.5)
		sample += noise.randf_range(-1.0, 1.0) * 0.08
		var envelope := smoothstep(0.0, 0.06, t) * (1.0 - smoothstep(0.6 if long else 0.3, 1.0, t))
		data.encode_s16(i * 2, int(clampf(sample * envelope * 0.45, -1.0, 1.0) * 32767.0))
	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = RATE
	stream.data = data
	return stream
