class_name HoundRig
extends Node3D
## Drives a hound model (models/hound*.glb) in code, the same way as the boy:
## paws follow a gait cycle and are placed with IK, and the spine, neck, head
## and jaw are layered on top. The tail and the ears are on springs.
##
## The gaits follow what is measured of dogs (sources in the comments below):
## a walk in which each hind paw lands a quarter of a stride before the fore paw
## of its own side; a trot on diagonal pairs; and a rotary gallop, hind, hind,
## fore, fore round in a circle, with the back gathering and stretching once a
## stride and the whole dog off the ground twice in it. Which it uses goes by
## its speed.
##
## Each leg is three bones and a paw, as a dog's is: upper arm, forearm and
## pastern in front; thigh, shank and hock behind. They fold in a zigzag, the
## elbow back and the stifle (the knee) forward, and the last of them lies flat
## on the ground when it sits or lies down.
##
## It also sits, lies down and sleeps, drops into a bow on braced forepaws, and
## turns its head to what it is watching. The Hound says which (`posture`,
## `playful`); how it is done is all here.
##
## There are two breeds, and every joint is read from the model's skeleton
## (tools/build_hound.py), so they may differ in any measurement. A hound whose
## ears stand is given ears that turn and flatten with its mood; one whose ears
## hang, ears that swing.

const MODELS: Array[Array] = [
	[preload("res://models/hound.glb"), preload("res://models/hound_lo.glb")],
	[preload("res://models/hound_pharaoh.glb"), preload("res://models/hound_pharaoh_lo.glb")],
]
## Fore left, fore right, hind left, hind right.
const SUFFIXES: Array[String] = ["_fl", "_fr", "_rl", "_rr"]
## The model faces +Z.
const AHEAD := Vector3(0.0, 0.0, 1.0)
const BEHIND := Vector3(0.0, 0.0, -1.0)

## Where in the stride each paw lands.
## Walk: lateral sequence, left hind, left fore, right hind, right fore, a
## quarter apart (Hildebrand's diagrams; en.wikipedia.org/wiki/Canine_gait).
const WALK: Array[float] = [0.25, 0.75, 0.0, 0.5]
## Trot: diagonal pairs together.
const TROT: Array[float] = [0.5, 1.0, 0.0, 0.5]
## Gallop: rotary, as carnivores do it: the hind pair, a flight with the body
## stretched out, the fore pair in the opposite order, a flight with it gathered
## (vanat.ahc.umn.edu/run/plate9.html).
const GALLOP: Array[float] = [0.6, 0.5, 0.0, 0.1]
## The share of the stride a paw is down, fore and hind, at a walk, a trot and a
## gallop. Walk and trot are measured (Kano et al. 2016, BMC Vet. Res. 12:2:
## 0.63 and 0.60 walking, 0.47 and 0.40 trotting); the gallop is a running
## hound's, a fifth of the stride or a little over, which leaves it in the air
## for a third of it.
const DUTY_FORE := Vector3(0.63, 0.47, 0.22)
const DUTY_HIND := Vector3(0.60, 0.42, 0.20)
## The middle of the first of the two flights of a gallop stride, as a share of
## the stride: the second is half a stride later.
const FLIGHT := 0.405
## How high the two flights throw it (m, for a hound of the bloodhound's size).
## More than a real hound rises, so that it shows.
const BOUND := 0.04
## Speeds (m/s) over which the walk gives way to the trot, and the trot to the
## gallop. Dogs change at Froude numbers (speed squared over g times leg length)
## of about 0.5 and 3; for this leg, 1.5 and 3.7 m/s.
const TROT_AT := Vector2(1.25, 1.75)
const GALLOP_AT := Vector2(3.3, 4.0)
## Length of a stride (m) against speed (m/s): 0.74 m at 1 m/s walking (Kano),
## about a metre trotting at 2.5 (the speed malinois choose to trot at: Andrada
## et al. 2023, Front. Bioeng. Biotechnol. 11:1193177), and three strides a
## second flat out.
const STRIDE := [0.0, 0.42, 1.0, 0.70, 2.5, 1.0, 3.6, 1.25, 5.4, 1.75, 9.0, 2.6]
## The furthest a planted paw travels under the body.
const REACH := 0.42
## How far a shoulder or a hip goes with its leg, as a share of how far the paw is from under it.
const GLIDE := 0.25
## How much further the last bone of a leg (pastern, hock) folds as the leg is
## shortened, radians for each share of its length it is shortened by (fore,
## hind): with the paw in the air, and with it on the ground. A foreleg's
## pastern folds back under it only when the paw is picked up.
const FOLD := Vector2(3.4, 2.2)
const FOLD_PLANTED := Vector2(-0.25, 0.9)

## How the jaw goes (time in seconds, how far open) for a bark, a bay and the
## snap when it has him. They are as long as the voice (see Hound._make_voice),
## and are played faster or slower with its pitch.
const BARK := [0.0, 0.0, 0.035, 1.0, 0.11, 0.8, 0.19, 0.0]
const BAY := [0.0, 0.0, 0.1, 0.9, 0.3, 1.0, 0.55, 0.8, 0.74, 0.0]
const SNAP := [0.0, 0.3, 0.07, 1.0, 0.12, 0.0, 0.3, 0.0, 0.37, 0.8, 0.42, 0.0]
## How far the jaw drops, wide open, radians.
const GAPE := 0.62

## Sitting: how high its hips come to rest (m, for the bloodhound), how its
## chest and its hips are turned from the line of its back, which rounds it,
## and how high its shoulders stay, as a share of standing.
const SIT_HIP := 0.125
const SIT_CHEST := -0.12
const SIT_PELVIS := 0.42
const SIT_SHOULDER := 0.985
## Lying: the hips rolled a little to one side.
const LIE_ROLL := 0.16
## The bow: how far the chest goes down (radians of the whole body), and how far
## forward of where they stood the forepaws are braced (m), and apart.
const BOW_PITCH := 0.5
const BOW_REACH := 0.2
const BOW_SPREAD := 0.045

## Which breed: 0 the bloodhound, 1 the pharaoh hound. Set before entering the tree.
var breed := 0
## Use the demade, low-poly model. Set before entering the tree.
var low_poly := false
## Layers of fur stood off the coat (see Fur). None on the demade model.
var fur_shells := 5


## One piece of something that hangs and swings behind the hound's movement: a
## bone pivoting where it roots, its far end a weight on a spring. An ear is
## two of them, the tail four, each hanging from the one before.
class Link:
	var joint: Node3D
	var bone := -1
	## Which way it lies at rest, in its parent's space, and which way it is
	## being held now (the tail is carried and wagged by moving this).
	var rest := Vector3.DOWN
	var aim := Vector3.DOWN
	## Turned about its own length, radians (an ear that swivels).
	var twist := 0.0
	var length := 0.1
	var stiffness := 120.0
	var damping := 8.0
	## How much the air holds it back.
	var drag := 1.0
	var gravity := 6.0
	## How far it may swing from where it is held, radians.
	var limit := 1.2
	## Outwards from the head, in its parent's space: an ear cannot swing in past this.
	var outward := Vector3.ZERO
	var tip := Vector3.ZERO
	var velocity := Vector3.ZERO
	var held_tip := Vector3.ZERO


var _hound: Hound
var _skeleton: Skeleton3D
var _joints: Array[Node3D] = []
var _bones: Array[int] = []
var _body: Node3D
var _chest: Node3D
var _pelvis: Node3D
var _neck: Node3D
var _neck_1: Node3D
var _head: Node3D
var _jaw: Node3D
## The legs: for each, its three bones and its paw.
var _legs: Array[Array] = []
var _tail: Array[Link] = []
## Left and right, each [root, tip].
var _ears: Array[Array] = [[], []]
var _links: Array[Link] = []
var _links_settled := false
## The eyes' material and colour: asleep, they are shut by painting them the colour of the coat.
var _eyes: ShaderMaterial
var _eye_colour := Color.BLACK
var _coat_colour := Color.BLACK

## What the skeleton says of it, standing: where its body is, and for each leg
## its hip (or shoulder) and its paw, how long its bones are, how far the paw
## is from the hip, how the last bone is turned from that line, and the frame
## each bone was modelled in.
var _body_rest := Vector3.ZERO
var _hips: Array[Vector3] = []
var _paws: Array[Vector3] = []
var _lengths: Array[Vector3] = []
var _spans: Array[float] = []
var _bends: Array[float] = []
var _frames: Array[Array] = []
## How big it is beside the bloodhound, and how high a planted paw's joint is.
var _size := 1.0
var _paw_height := 0.035
## Its ears stand (and are turned by its mood), or else hang.
var _pricked := false
## Worked out once from its build: how it sits, lies and bows.
var _sit_pitch := -0.8
var _sit_body := Vector3.ZERO
var _sit_paws: Array[Vector3] = []
var _lie_body := Vector3.ZERO
var _lie_paws: Array[Vector3] = []
var _lay_angle := 1.5
var _bow_pelvis := Vector3.ZERO

var _time := 0.0
var _phase := 0.0
var _pace := 0.0
var _air := 0.0
var _crouch := 0.0
var _crouch_velocity := 0.0
var _drop := 0.0
var _was_grounded := true
var _last_yaw := 0.0
var _turn := 0.0
## Which fore leg leads at a gallop: this hound's habit.
var _mirrored := false
## Which side it lies down on, 1 its left.
var _side := 1.0

## How far into sitting and lying it is, 0..1, how long it has lain, and how fast asleep it is.
var _sit := 0.0
var _lie := 0.0
var _lain := 0.0
var _doze := 0.0
## The bow is on a spring, so it drops into it past the mark and comes back up.
var _bow := 0.0
var _bow_velocity := 0.0

## Its voice: how long since it last gave tongue (in the time of the curves
## above), how fast it is being played, and whether that was a bark; and how
## long since it last snapped.
var _voiced := 9.0
var _voice_rate := 1.0
var _voice_length := 0.2
var _envelope := PackedFloat32Array()
var _mouth := 0.0
var _barked := false
var _snapped := 9.0
var _bay := 0.0
## How out of breath it is, 0..1: it pants.
var _puffed := 0.0
var _breath := 0.0
var _wag := 0.0
var _wag_phase := 0.0
var _alert := 0.0

## What it is watching, and where its head is turned (yaw, pitch) and cocked.
var _interest: Node3D
var _interest_time := 0.0
var _look := Vector2.ZERO
var _look_timer := 0.0
var _tilt := 0.0
var _tilt_to := 0.0
var _twitch_timer := 3.0
## Standing ears: how far each is turned aside to listen, where to, and how flat they are laid.
var _ear_turn := Vector2.ZERO
var _ear_turn_to := Vector2.ZERO
var _ear_timer := 1.0
var _ear_flat := 0.0
## Hurt: how far it is cringing from a blow (and which way the blow went, in
## its own space), how far its hindquarters have given under a shot, and how
## cowed it is. The first two pass in a second or so.
var _flinched := 0.0
var _flinch_way := Vector3.ZERO
var _staggered := 0.0
var _cowed := 0.0


func _ready() -> void:
	_build()
	_hound = get_parent() as Hound
	if _hound:
		_hound.bayed.connect(_on_bayed)
		# (it goes on saying so for as long as it has him: one snap is enough)
		_hound.caught.connect(func() -> void: _snapped = _snapped if _snapped < 0.6 else 0.0)
	_time = randf() * 10.0
	_mirrored = randf() < 0.5
	_side = 1.0 if randf() < 0.5 else -1.0
	_last_yaw = rotation.y


## It has been hit, the blow going `way` (in its own space); `hard`, by a shot.
func flinch(way: Vector3, hard: bool) -> void:
	_flinch_way = way.normalized() if way.length_squared() > 0.0001 else BEHIND
	_flinched = 1.0
	if hard:
		_staggered = 1.0


func _on_bayed(bark: bool) -> void:
	_voiced = 0.0
	# (its jaw keeps time with its voice, which is not always played at the same pitch)
	_voice_rate = _hound.voice_rate if _hound else 1.0
	_voice_length = _hound.voice_length if _hound else (0.2 if bark else 0.75)
	_envelope = _hound.voice_envelope if _hound else PackedFloat32Array()
	_barked = bark
	if bark:
		# Every bark throws it back up out of the bow a little, and it drops again.
		_bow_velocity -= 1.4
	else:
		_bay = 1.0


func _process(delta: float) -> void:
	if _hound == null:
		return
	delta = minf(delta, 1.0 / 30.0)
	_time += delta
	var velocity := _hound.velocity
	var speed := Vector2(velocity.x, velocity.z).length()
	var grounded := _hound.is_on_floor()
	_turn = _approach(_turn, angle_difference(_last_yaw, rotation.y) / delta, 8.0, delta)
	_last_yaw = rotation.y

	_air = _approach(_air, 0.0 if grounded else 1.0, 12.0, delta)
	# (its head stays thrown up for as long as the bay lasts)
	_bay = _approach(_bay, 1.0 if not _barked and _voiced < _voice_length - 0.35 else 0.0, 6.0 if not _barked and _voiced < _voice_length - 0.35 else 2.2, delta)
	_voiced += delta * _voice_rate
	_snapped += delta
	_alert = _approach(_alert, 1.0 if _hound.chasing else 0.0, 4.0, delta)
	_puffed = clampf(_puffed + (speed / _hound.run_speed * 0.22 - 0.06) * delta, 0.0, 1.0)
	if grounded and not _was_grounded:
		_crouch_velocity += clampf(-velocity.y * 0.3 + 1.0, 1.0, 3.0)
	_was_grounded = grounded
	_crouch_velocity += (-_crouch * 240.0 - _crouch_velocity * 22.0) * delta
	_crouch = clampf(_crouch + _crouch_velocity * delta, -0.02, 0.16)
	_settle(delta, grounded)
	_flinched = _approach(_flinched, 0.0, 3.2, delta)
	_staggered = _approach(_staggered, 0.0, 2.0, delta)
	_cowed = _approach(_cowed, _hound.afraid, 5.0, delta)
	var sit := smoothstep(0.0, 1.0, _sit)
	var lie := smoothstep(0.0, 1.0, _lie)
	var bow := _bow * (1.0 - _air)
	var bowed := clampf(bow, 0.0, 1.0)
	var down := maxf(sit, bowed)

	# --- The gait. Turning on the spot it steps round, without going anywhere. ---
	_pace = _approach(_pace, maxf(speed, absf(_turn) * 0.22), 10.0, delta)
	var trot := smoothstep(TROT_AT.x, TROT_AT.y, _pace)
	var gallop := smoothstep(GALLOP_AT.x, GALLOP_AT.y, _pace)
	var stride := _keyed(STRIDE, _pace)
	if grounded:
		_phase = fposmod(_phase + _pace / stride * delta, 1.0)
	var gait := smoothstep(0.05, 0.45, _pace) * (1.0 - _air) * (1.0 - down)
	var travel := clampf(speed / maxf(_pace, 0.05), 0.0, 1.0)
	var lift := lerpf(lerpf(0.045, 0.075, trot), 0.15, gallop) * _size
	# At a gallop it is thrown clear of the ground twice a stride: after the hind
	# legs drive, stretched out, and after the forelegs, gathered up.
	var flying := gallop * gait
	var bound := cos(2.0 * TAU * (_phase - FLIGHT))
	var rise := (0.25 + bound) * BOUND * _size * flying
	var targets: Array[Vector3] = []
	var pitches: Array[float] = []
	# How hard each end of it is bearing down on its legs, 0..2.
	var load_fore := 0.0
	var load_hind := 0.0
	var drop := 0.0
	for i in 4:
		var fore := i < 2
		var duties := DUTY_FORE if fore else DUTY_HIND
		var duty := lerpf(lerpf(duties.x, duties.y, trot), duties.z, gallop)
		var span := minf(duty * stride, REACH * _size) * travel
		# A paw comes down about 20 degrees ahead of its hip and leaves 25 to 30
		# behind it (Andrada et al.), so its ground is set back; at a gallop it
		# reaches further ahead instead.
		var middle := lerpf(-0.035, 0.05 if fore else 0.09, gallop) * travel
		# (the other fore leg leads in a hound that gallops the other way round)
		var other := i ^ 1 if _mirrored else i
		var at := fposmod(_phase - lerpf(lerpf(WALK[i], TROT[i], trot), GALLOP[other], gallop), 1.0)
		var cycle := _foot_cycle(at, duty, span * 0.5, lift * (1.0 if fore else 0.85))
		var rest := _paws[i]
		# Off the ground, a paw goes up with the rest of it.
		var carried := 0.0
		if at >= duty:
			var swing := (at - duty) / (1.0 - duty)
			carried = clampf(minf(swing, 1.0 - swing) * 6.0, 0.0, 1.0) * maxf(rise, 0.0)
		# At a trot the paws come in under it, towards one line.
		targets.append(Vector3(rest.x * lerpf(1.0, 0.72, trot * gait), _paw_height + (cycle.y + carried) * gait, rest.z + (middle + cycle.z) * gait))
		pitches.append(cycle.x * gait)
		if at < duty:
			var bearing := sin(PI * at / duty)
			if fore:
				load_fore += bearing
			else:
				load_hind += bearing
		# Low enough that a planted leg reaches both ends of its ground.
		var from_hip := rest.z - _hips[i].z + middle * gait
		var furthest := (absf(from_hip) + span * 0.5 * gait) * (1.0 - GLIDE)
		var total := _lengths[i].x + _lengths[i].y + _lengths[i].z - 0.012
		drop = maxf(drop, _hips[i].y - _paw_height - sqrt(maxf(total * total - furthest * furthest, 0.01)))

	_drop = _approach(_drop, drop + 0.004, 9.0, delta)
	# Walking, each end of it rides up over its legs as they pass under it;
	# trotting it sinks onto them and is thrown up off them.
	var sprung := 0.016 * trot * (1.0 - gallop)
	var vault := 0.014 * (1.0 - trot)
	var high_fore := ((load_fore - 0.7) * vault - (load_fore - 0.5) * sprung) * gait
	var high_hind := ((load_hind - 0.7) * vault - (load_hind - 0.5) * sprung) * gait
	# At a gallop the two ends take turns to be up, which rocks it: nose up over
	# the hind legs, down over the fore.
	var rock := (high_hind - high_fore) / 0.42 + sin(TAU * (_phase - FLIGHT)) * 0.085 * flying
	# The back gathers under it as the forelegs leave the ground and stretches
	# out as the hind legs do, once a stride.
	var gather := cos(TAU * (_phase - FLIGHT - 0.5)) * flying
	# The hips and the shoulders each swing with their own legs, and into a turn.
	var bend := clampf(_turn * 0.06, -0.3, 0.3) * (1.0 - down)
	var swing_fore := (targets[1].z - targets[0].z) * 0.22 * (1.0 - gallop)
	var swing_hind := (targets[3].z - targets[2].z) * 0.28 * (1.0 - gallop)
	var bank := clampf(-_turn * speed * 0.012, -0.22, 0.22)

	var air_pitch := _air * clampf(-velocity.y * 0.04, -0.4, 0.4)
	var body_at := _body_rest + Vector3(0.0, -_drop - _crouch + (high_fore + high_hind) * 0.5 + rise, 0.0)
	var body_turn := Vector3(air_pitch + rock, 0.0, bank)
	var chest_turn := Vector3(gather * 0.2, bend + swing_fore, (targets[0].y - targets[1].y) * 0.5)
	var pelvis_turn := Vector3(-gather * 0.38, -bend * 0.7 + swing_hind, (targets[2].y - targets[3].y) * 0.6)
	# Which way the first joint of each leg goes: the elbows back, the stifles forward.
	var poles: Array[Vector3] = [BEHIND, BEHIND, AHEAD, AHEAD]
	# How far the last bone of each leg is laid flat along the ground.
	var flat: Array[float] = [0.0, 0.0, 0.0, 0.0]

	# --- Sitting, lying, and the bow, each laid over what came before. ---
	if sit > 0.0:
		body_at = body_at.lerp(_sit_body, sit)
		body_turn = body_turn.lerp(Vector3(_sit_pitch, 0.0, 0.0), sit)
		chest_turn = chest_turn.lerp(Vector3(SIT_CHEST, 0.0, 0.0), sit)
		pelvis_turn = pelvis_turn.lerp(Vector3(SIT_PELVIS, 0.0, 0.0), sit)
		for i in 4:
			# Each paw is picked up and put where it sits, one after the other.
			var step := clampf(_sit * 2.0 - (0.0 if i == 0 or i == 3 else 0.9), 0.0, 1.0)
			targets[i] = targets[i].lerp(_sit_paws[i], smoothstep(0.0, 1.0, step)) + Vector3.UP * sin(PI * step) * 0.035
			pitches[i] *= 1.0 - sit
			if i >= 2:
				# The knees come up beside the belly, and out; the hocks go down flat.
				poles[i] = AHEAD.slerp(Vector3(signf(_hips[i].x) * 0.5, 0.6, 1.0).normalized(), sit)
				flat[i] = smoothstep(0.35, 0.9, sit)
	if lie > 0.0:
		body_at = body_at.lerp(_lie_body, lie)
		body_turn = body_turn.lerp(Vector3(-0.03, 0.0, -_side * 0.06), lie)
		chest_turn = chest_turn.lerp(Vector3(0.1 * _doze, 0.0, 0.0), lie)
		pelvis_turn = pelvis_turn.lerp(Vector3(0.12, 0.0, -_side * LIE_ROLL), lie)
		for i in 4:
			var step := clampf(_lie * 1.6 - (0.0 if i == 0 or i == 3 else 0.5), 0.0, 1.0)
			if i >= 2:
				poles[i] = poles[i].slerp(Vector3(signf(_hips[i].x) * 0.75, 0.25, 1.0).normalized(), lie)
			else:
				# Down onto its elbows, and the forearms flat out in front.
				poles[i] = poles[i].slerp(Vector3(signf(_hips[i].x) * 0.12, -0.5, -1.0).normalized(), lie)
				flat[i] = smoothstep(0.3, 0.9, lie)
			targets[i] = targets[i].lerp(_lie_paws[i], smoothstep(0.0, 1.0, step)) + Vector3.UP * sin(PI * step) * 0.03
	if absf(bow) > 0.001:
		# It goes down onto its forepaws with a little jump, and they land apart.
		# (the jump is over by the time it is as far down as it is going)
		var hop := sin(PI * clampf(bow / maxf(_hound.bow_depth, 0.1), 0.0, 1.0))
		var pitch := BOW_PITCH * bow
		var at := _bow_pelvis - Basis(Vector3.RIGHT, pitch) * _pelvis.position + Vector3.UP * hop * 0.03
		body_at = body_at.lerp(at, bowed)
		body_turn.x += pitch
		chest_turn.x -= 0.16 * bow
		pelvis_turn.x += 0.1 * bow
		for i in 2:
			var braced := _paws[i] + Vector3(signf(_paws[i].x) * BOW_SPREAD, 0.0, BOW_REACH * (1.0 if i == 0 else 0.9)) * _size
			targets[i] = targets[i].lerp(braced, bowed) + Vector3.UP * hop * 0.08
			pitches[i] *= 1.0 - bowed
			# The elbows go down and out; right down, the forearms are along the ground.
			poles[i] = BEHIND.slerp(Vector3(signf(_hips[i].x) * 0.3, -0.4, -1.0).normalized(), bowed)
			flat[i] = maxf(flat[i], smoothstep(0.75, 1.0, bow) * 0.85)

	# Hit, it cringes: down, over the way the blow went, its shoulders twisted
	# from it. Shot, its hindquarters give under it and it sits back on them for
	# a moment. Cowed, it goes low, with its rump tucked under.
	body_at += Vector3(_flinch_way.x * 0.05, -0.05, _flinch_way.z * 0.03) * _flinched * _size
	body_at.y -= (0.09 * _staggered + 0.035 * _cowed) * _size
	body_turn.z -= _flinch_way.x * 0.3 * _flinched
	body_turn.x -= 0.22 * _staggered
	chest_turn.y += _flinch_way.x * 0.35 * _flinched
	chest_turn.x += 0.1 * _cowed
	pelvis_turn.x -= 0.3 * _staggered + 0.18 * _cowed
	_body.position = body_at
	_body.rotation = body_turn
	_chest.rotation = chest_turn
	_pelvis.rotation = pelvis_turn
	_breathe(delta, sit)
	_look_about(delta)
	_pose_head(delta, body_turn.x + chest_turn.x, lerpf(1.0, 0.75, gallop), sit, lie, flying)
	_pose_jaw()
	_pose_legs(targets, pitches, poles, flat, velocity.y)
	_carry_tail(delta, gallop, sit, lie, bowed)
	_carry_ears(delta, gallop)
	for i in _joints.size():
		_skeleton.set_bone_pose(_bones[i], _joints[i].transform)
	_swing(delta)
	if _eyes:
		# (asleep its eyes are shut, and it screws them shut at a blow)
		_eyes.set_shader_parameter(&"albedo", _eye_colour.lerp(_coat_colour, maxf(smoothstep(0.3, 0.8, _doze), smoothstep(0.45, 0.8, _flinched))))


## Brings it into and out of sitting, lying and the bow. It sits before it lies,
## and is up off the ground far faster than it went down.
func _settle(delta: float, grounded: bool) -> void:
	var posture := _hound.posture if grounded else Hound.Posture.UP
	var resting := posture == Hound.Posture.SIT or posture == Hound.Posture.LIE
	_sit = move_toward(_sit, 1.0 if resting else 0.0, delta / (0.75 if resting else 0.32))
	var lying := posture == Hound.Posture.LIE and _sit > 0.85
	_lie = move_toward(_lie, 1.0 if lying else 0.0, delta / (1.1 if lying else 0.3))
	_lain = _lain + delta if _lie >= 1.0 else 0.0
	_doze = _approach(_doze, 1.0 if _lain > 2.0 else 0.0, 1.3 if _lain > 2.0 else 8.0, delta)
	# (hunting, it only braces: playing, it goes right down)
	var bowing := _hound.bow_depth if posture == Hound.Posture.BOW else 0.0
	_bow_velocity += ((bowing - _bow) * 190.0 - _bow_velocity * 17.0) * delta
	_bow = clampf(_bow + _bow_velocity * delta, -0.08, 1.1)


## Its ribs: slow and deep asleep, quick and shallow when it is out of breath.
func _breathe(delta: float, sit: float) -> void:
	var panting := smoothstep(0.25, 0.6, _puffed) * (1.0 - _doze)
	_breath += delta * TAU * lerpf(lerpf(0.45, 0.25, _doze), 3.4, panting)
	var swell := sin(_breath) * lerpf(lerpf(0.014, 0.034, _doze), 0.02, panting)
	_chest.scale = Vector3(1.0 + swell, 1.0 + swell, 1.0)
	_neck.scale = Vector3.ONE / _chest.scale
	# Sitting, the breath shows in the shoulders too.
	_body.position.y += swell * 0.2 * sit


## Head and neck: kept level whatever the body under them is doing, turned to
## what it is watching, thrown up to bay, and laid down on its paws to sleep.
## Whatever the neck does is shared between its two joints.
func _pose_head(delta: float, upstream: float, level: float, sit: float, lie: float, flying: float) -> void:
	var awake := 1.0 - _doze
	var bow := clampf(_bow, 0.0, 1.0)
	_tilt = _approach(_tilt, _tilt_to * awake, 5.0, delta)
	# (it ducks its head from a blow, and turns it away; cowed, it carries it low)
	var hurt := maxf(_flinched, _staggered)
	var yaw := _look.x * awake * (1.0 - _flinched) + _flinch_way.x * 0.7 * _flinched
	# (braced under him it looks up at him, but not so far that its head is on its back)
	var pitch := maxf(_look.y, -0.75 + bow * 0.3) * awake - _bay * 0.4 + 0.5 * hurt + 0.3 * _cowed
	# Lying awake it holds its head up off the ground; asleep it is flat out, nose a little to one side.
	var laid := lie * _doze
	_chest.rotation.y += yaw * 0.1 * (1.0 - sit)
	# Flat out, its neck goes out in front of it, and reaches with every stride.
	var stretch := flying * (0.2 + 0.25 * _size * _size + 0.08 * sin(TAU * (_phase - FLIGHT)))
	var neck := Vector3(-upstream * 0.55 * level + pitch * 0.5 - bow * 0.1 + laid * _lay_angle + lie * awake * 0.2 + stretch, yaw * 0.45 + laid * _side * 0.2, 0.0)
	_neck.rotation = neck * 0.5
	_neck_1.rotation = neck * 0.5
	_head.rotation = Vector3(-upstream * 0.45 * level + pitch * 0.5 - bow * 0.12 - laid * (_lay_angle - 0.25) - lie * awake * 0.2 - stretch * 0.8, yaw * 0.45 + laid * _side * 0.25, _tilt + laid * _side * 0.3)


## The jaw drops for a bark and snaps shut after it, hangs open through a bay,
## snaps twice when it has him, and hangs a little, working, while it pants.
func _pose_jaw() -> void:
	# (the jaw has weight: it cannot follow every flutter of the sound)
	_mouth = lerpf(_mouth, jaw_open(), 0.55)
	_jaw.rotation.x = _mouth * GAPE


## How far its voice opens its mouth, 0..1. With a recording, that is how
## loud the recording is just now (and is about to be: the mouth opens ahead of
## the sound); with none, a bark or a bay drawn by hand and stretched to fit.
func _voice_open() -> float:
	if _envelope.is_empty():
		var keys := BARK if _barked else BAY
		var written: float = keys[keys.size() - 2]
		return _keyed(keys, _voiced * written / maxf(_voice_length, 0.05))
	var at := _voiced * 60.0
	if at >= _envelope.size() + 2:
		return 0.0
	var loud := 0.0
	for ahead in 4:
		var index := int(at) + ahead
		if index < _envelope.size():
			loud = maxf(loud, _envelope[index])
	return clampf(pow(loud, 0.6) * 1.15, 0.0, 1.0)


func puffed() -> float:
	return _puffed


## How far open its mouth is, 0..1.
func jaw_open() -> float:
	var open := _voice_open()
	open = maxf(open, _keyed(SNAP, _snapped))
	var panting := smoothstep(0.25, 0.6, _puffed) * (1.0 - _doze)
	return maxf(open, panting * (0.2 + 0.07 * sin(_breath)))


func _pose_legs(targets: Array[Vector3], pitches: Array[float], poles: Array[Vector3], flat: Array[float], vertical_speed: float) -> void:
	var to_body := _body.transform.affine_inverse()
	var rising := clampf(vertical_speed / 5.0, -1.0, 1.0) * 0.5 + 0.5
	for i in 4:
		var fore := i < 2
		var rest := _paws[i]
		# In the air: stretched out going up, forelegs reaching for the landing coming down.
		var stretched := rest + Vector3(0.0, 0.13, 0.24 if fore else -0.26) * _size
		var landing := rest + Vector3(0.0, 0.07 if fore else 0.17, 0.16 if fore else -0.04) * _size
		var target := targets[i].lerp(landing.lerp(stretched, rising), _air)
		var spine := _chest if fore else _pelvis
		var hip := spine.transform * (_hips[i] - _body_rest - spine.position)
		var paw := to_body * target
		# The shoulder blade slides over the ribs, and the hip swings, with the leg: a
		# quarter of the way to wherever the paw is.
		var under := hip.z + rest.z - _hips[i].z
		hip.z += clampf((paw.z - under) * GLIDE, -0.07, 0.07)
		var lifted := maxf(_air, clampf((target.y - _paw_height) / (0.05 * _size), 0.0, 1.0))
		_solve_leg(i, hip, paw, to_body.basis * Basis(Vector3.RIGHT, lerpf(pitches[i], 0.5, _air)), to_body.basis * poles[i], to_body.basis * AHEAD,
				flat[i] * (1.0 - _air), lifted)


## Paw path over a gait cycle. Returns (toe pitch, height, forward). It is down
## for the first `duty` of it, carried back under the body; then it is picked
## up, toes trailing, and swung through to reach for the ground again.
func _foot_cycle(phase: float, duty: float, half_step: float, lift: float) -> Vector3:
	if phase < duty:
		var planted := phase / duty
		return Vector3(smoothstep(0.65, 1.0, planted) * 0.55, 0.0, lerpf(half_step, -half_step, planted))
	var swing := (phase - duty) / (1.0 - duty)
	# (it is at its highest early, and comes forward fastest in the middle)
	return Vector3(lerpf(0.75, -0.22, smoothstep(0.0, 0.8, swing)), sin(PI * pow(swing, 0.75)) * lift, lerpf(-half_step, half_step, smoothstep(0.0, 1.0, swing)))


## Three-bone IK in body space. The leg folds in a zigzag: its first joint goes
## off towards `pole` (back for an elbow, forward for a stifle) and its second
## the other way. How the last bone lies is chosen first: turned from the line
## from hip to paw as it was modelled, further the more the leg is drawn up
## (and further still with the paw `lifted`), less the more it is stretched
## out; or along `ground`, by `flat`, when it is laid on the floor. The other
## two bones then reach what is left.
func _solve_leg(index: int, hip: Vector3, target: Vector3, paw_basis: Basis, pole: Vector3, ground: Vector3, flat: float, lifted: float) -> void:
	var lengths := _lengths[index]
	var total := lengths.x + lengths.y + lengths.z
	var to_target := target - hip
	var reach := clampf(to_target.length(), 0.06, total - 0.004)
	var line := to_target.normalized() if to_target.length_squared() > 0.0001 else Vector3.DOWN
	var aside := pole - line * pole.dot(line)
	aside = aside.normalized() if aside.length_squared() > 0.0001 else AHEAD
	var paw := hip + line * reach

	var span := _spans[index]
	var bend := _bends[index]
	if reach > span:
		bend *= (total - reach) / (total - span)
	else:
		var fore := index < 2
		bend += (span - reach) / span * lerpf(FOLD_PLANTED.x if fore else FOLD_PLANTED.y, FOLD.x if fore else FOLD.y, lifted)
	var last := line * cos(bend) + aside * sin(bend)
	if flat > 0.0:
		last = last.slerp(ground, flat).normalized()
	# It cannot be turned so far that the rest of the leg does not reach.
	var far := lengths.x + lengths.y - 0.003
	var near := absf(lengths.x - lengths.y) + 0.01
	var second := paw - last * lengths.z
	for attempt in 8:
		if (second - hip).length() <= far:
			break
		last = last.slerp(line, 0.3).normalized()
		second = paw - last * lengths.z
	var across := second - hip
	var gap := clampf(across.length(), near, far)
	var along := across.normalized()
	second = hip + along * gap
	paw = second + last * lengths.z
	var off := aside - along * aside.dot(along)
	off = off.normalized() if off.length_squared() > 0.0001 else aside
	var fold := acos(clampf((lengths.x * lengths.x + gap * gap - lengths.y * lengths.y) / (2.0 * lengths.x * gap), -1.0, 1.0))
	var first := hip + (along * cos(fold) + off * sin(fold)) * lengths.x

	var normal := aside.cross(line).normalized()
	var bones: Array = _legs[index]
	var frames: Array = _frames[index]
	(bones[0] as Node3D).transform = Transform3D(_frame(normal, (first - hip).normalized()) * frames[0], hip)
	(bones[1] as Node3D).transform = Transform3D(_frame(normal, (second - first).normalized()) * frames[1], first)
	(bones[2] as Node3D).transform = Transform3D(_frame(normal, last) * frames[2], second)
	(bones[3] as Node3D).transform = Transform3D(paw_basis, paw)


## The frame of a leg bone lying along `along`, in a leg folding about `normal`.
static func _frame(normal: Vector3, along: Vector3) -> Basis:
	var x := (normal - along * normal.dot(along)).normalized()
	return Basis(x, -along, x.cross(-along))


## Picks what to watch, and turns the head towards it. The one it is after
## comes first, and it never takes its eyes off him while it is hunting.
## Otherwise it is the other hound, or something in the group `interest`, a few
## seconds at a time; now and then it cocks its head at it.
func _look_about(delta: float) -> void:
	_look_timer -= delta
	if _look_timer <= 0.0:
		_look_timer = 0.2
		_notice()
	var target := Vector2.ZERO
	if is_instance_valid(_interest):
		var to := _interest.global_position + Vector3.UP * _eye_height(_interest) - _head.global_position
		target.x = clampf(angle_difference(rotation.y, atan2(to.x, to.z)), -1.9, 1.9)
		target.y = clampf(-atan2(to.y, Vector2(to.x, to.z).length()), -1.0, 0.6)
	else:
		target.x = sin(_time * 0.41) * 0.3 + sin(_time * 0.9 + 1.0) * 0.1
		target.y = 0.08 + sin(_time * 0.3 + 2.0) * 0.06
	_look = _look.lerp(target, 1.0 - exp(-(10.0 if _alert > 0.5 else 7.0) * delta))


func _notice() -> void:
	var here := global_position
	var found: Node3D = null
	var quarry := _hound.target
	if quarry and (_hound.chasing or quarry.global_position.distance_to(here) < 9.0):
		found = quarry
	_interest_time += 0.2
	if found == null:
		# Keep to what it has until it has seen enough of it.
		if is_instance_valid(_interest) and _interest != quarry and _interest_time < 3.5:
			return
		var nearest := 10.0
		for other: Node3D in get_tree().get_nodes_in_group(&"hounds"):
			var distance := other.global_position.distance_to(here)
			if other != _hound and other != _interest and distance < nearest:
				nearest = distance
				found = other
		nearest = 6.0 if found == null or randf() < 0.4 else 0.0
		for thing: Node3D in get_tree().get_nodes_in_group(&"interest"):
			var distance := thing.global_position.distance_to(here)
			if thing != _interest and distance < nearest:
				nearest = distance
				found = thing
		# (with nothing else about, it goes back to gazing round for a while)
		if found == null and _interest_time < 6.0 and _interest != quarry:
			return
	if found != _interest:
		_interest = found
		_interest_time = 0.0
		# Something new: as often as not it cocks its head.
		_tilt_to = [-0.3, 0.0, 0.0, 0.3].pick_random() if found and not _hound.chasing else 0.0
	elif _interest_time > 1.6:
		_tilt_to = 0.0


static func _eye_height(thing: Node3D) -> float:
	if thing is Player:
		return 0.95
	return 0.55 if thing is Hound else 0.15


## How the tail is carried, and its wag. Up when it is on a scent or playing,
## streaming out behind at a gallop, down when it is at ease; the wag starts at
## the root and runs down it.
func _carry_tail(delta: float, gallop: float, sit: float, lie: float, bow: float) -> void:
	var playful := _hound.playful * (1.0 - _doze)
	_wag = _approach(_wag, playful, 5.0, delta)
	# (two or three beats a second at ease, twice that when it is beside itself)
	_wag_phase += delta * TAU * lerpf(2.4, 4.2, _wag)
	var carried := 0.1 + 0.4 * _alert + 0.25 * gallop + 0.35 * _bay + 0.55 * _wag + 0.6 * bow
	carried = lerpf(carried, 0.35, sit)
	carried = lerpf(carried, 0.05, lie)
	# Hurt or frightened, it goes down between its legs.
	carried -= 1.3 * maxf(maxf(_flinched, _staggered), _cowed)
	for i in _tail.size():
		var link := _tail[i]
		var swing := sin(_wag_phase - i * 0.8) * _wag * (0.3 if i == 0 else 0.2) + lie * _side * 0.3
		var curl := carried - _pelvis.rotation.x * 0.8 - _body.rotation.x * 0.5 * (1.0 - sit) if i == 0 else _wag * 0.2 + bow * 0.15 - gallop * 0.08
		link.aim = Basis(Vector3.UP, swing) * Basis(Vector3.RIGHT, curl) * link.rest
		# Flat out it is held stiff, a rudder: the rump under it is going up and down three times a second.
		link.limit = lerpf(0.7, 0.14, gallop)
	# Its hindquarters go with its tail when it is really pleased.
	_pelvis.rotation.y += sin(_wag_phase + 0.5) * 0.05 * _wag * (1.0 - lie)

	# Asleep it twitches: an ear, or the end of its tail.
	_twitch_timer -= delta
	if _twitch_timer <= 0.0:
		_twitch_timer = randf_range(2.5, 6.0)
		if _doze > 0.6:
			var which := randi() % 3
			if which < 2:
				_flick(which, Vector3(0.6 if which == 0 else -0.6, 0.4, -0.2))
			else:
				_tail[-1].velocity += Vector3.UP * 2.5
				_tail[-2].velocity += Vector3.UP * 1.5
		elif _sit < 0.1 and _alert < 0.5 and randf() < 0.4:
			# Standing about, it shakes an ear now and then.
			var which := randi() % 2
			_flick(which, Vector3(0.7 if which == 0 else -0.7, 0.3, 0.0))


func _flick(which: int, push: Vector3) -> void:
	for link: Link in _ears[which]:
		link.velocity += (link.joint.get_parent() as Node3D).global_basis * push * (2.0 if _pricked else 1.0)


## Ears that stand say what it is about: up and to the front when it is after
## something, one or other turned aside to listen when it is at ease, and laid
## back flat along its neck when it runs flat out, gives tongue, plays or sleeps.
## Ears that hang are left to their own weight (see `_swing`).
func _carry_ears(delta: float, gallop: float) -> void:
	if not _pricked:
		return
	var voiced := 1.0 if _voice_open() > 0.2 or _snapped < 0.5 else 0.0
	var flat := maxf(maxf(gallop * 0.75, _doze * 0.55), maxf(voiced * 0.3, _wag * 0.45 + clampf(_bow, 0.0, 1.0) * 0.3))
	flat = maxf(flat, maxf(maxf(_flinched, _staggered), _cowed))
	_ear_flat = _approach(_ear_flat, clampf(flat, 0.0, 1.0), 9.0 if flat > _ear_flat else 4.0, delta)
	_ear_timer -= delta
	if _ear_timer <= 0.0:
		_ear_timer = randf_range(0.7, 2.6)
		# Listening: one of them turns out and back, or both come to the front again.
		var pick := randi() % 4
		_ear_turn_to = Vector2(randf_range(0.5, 1.1) if pick == 0 else 0.0, randf_range(0.5, 1.1) if pick == 1 else 0.0)
	var listening := (1.0 - _alert) * (1.0 - _ear_flat)
	_ear_turn = _ear_turn.lerp(_ear_turn_to * listening, 1.0 - exp(-9.0 * delta))
	for side in 2:
		var out := 1.0 if side == 0 else -1.0
		var turn: float = _ear_turn[side]
		var root: Link = _ears[side][0]
		var flap: Link = _ears[side][1]
		# Laid back and a little out; pricked, they come in towards each other.
		var lean := Basis(Vector3.RIGHT, -_ear_flat * 1.0 - turn * 0.3) * Basis(BEHIND, out * (_ear_flat * 0.3 + turn * 0.45 - _alert * 0.07))
		root.aim = lean * root.rest
		root.twist = out * (turn + _ear_flat * 0.5)
		flap.aim = Basis(Vector3.RIGHT, -_ear_flat * 0.25) * flap.rest


## Swings whatever hangs from it. Each piece's far end is a weight on a spring:
## it is drawn to where it is held, pulled down, dragged at by the air, left
## behind by any sudden move, and kept off the ground; the bone is turned to
## point at it. Each is worked out after the one it hangs from.
func _swing(delta: float) -> void:
	var ground := global_position.y + 0.02
	for link in _links:
		var parent := (link.joint.get_parent() as Node3D).global_transform
		var frame := parent.basis.orthonormalized()
		var root := parent * link.joint.position
		var held_tip := root + frame * link.aim * link.length
		if not _links_settled:
			link.tip = held_tip
			link.held_tip = held_tip
			link.velocity = Vector3.ZERO
		var held_velocity := (held_tip - link.held_tip) / delta
		link.held_tip = held_tip
		var before := link.tip
		var pull := (held_tip - link.tip) * link.stiffness - (link.velocity - held_velocity) * link.damping
		link.velocity += (pull - link.velocity * link.drag + Vector3.DOWN * link.gravity) * delta
		link.tip += link.velocity * delta
		link.tip.y = maxf(link.tip.y, ground)

		var along := (link.tip - root).normalized()
		var held := (held_tip - root).normalized()
		var off := held.angle_to(along)
		if off > link.limit:
			along = held.slerp(along, link.limit / off)
		if link.outward != Vector3.ZERO:
			# An ear lies against the head, and cannot go in through it.
			var out := frame * link.outward
			var outness := along.dot(out)
			if outness < -0.02:
				along = (along + out * (-0.02 - outness)).normalized()
		link.tip = root + along * link.length
		link.velocity = (link.tip - before) / delta
		link.joint.basis = Basis(Quaternion(link.rest, (frame.inverse() * along).normalized())) * Basis(link.rest, link.twist)
		_skeleton.set_bone_pose(link.bone, link.joint.transform)
	_links_settled = true


static func _approach(from: float, to: float, rate: float, delta: float) -> float:
	return lerpf(from, to, 1.0 - exp(-rate * delta))


## Reads a curve drawn by hand: `keys` is (time, value) pairs in order, and the
## line through them is smooth, so nothing starts or stops with a jerk.
static func _keyed(keys: Array, time: float) -> float:
	var last := keys.size() / 2 - 1
	if time <= keys[0]:
		return keys[1]
	if time >= keys[last * 2]:
		return keys[last * 2 + 1]
	var k := 0
	while time > keys[k * 2 + 2]:
		k += 1
	var t0: float = keys[k * 2]
	var t1: float = keys[k * 2 + 2]
	var v0: float = keys[k * 2 + 1]
	var v1: float = keys[k * 2 + 3]
	# (the slope at each point is that of the line between its neighbours; flat at the ends)
	var m0: float = (v1 - keys[k * 2 - 1]) / (t1 - keys[k * 2 - 2]) if k > 0 else 0.0
	var m1: float = (keys[k * 2 + 5] - v0) / (keys[k * 2 + 4] - t0) if k < last - 1 else 0.0
	var span := t1 - t0
	var u := (time - t0) / span
	var u2 := u * u
	var u3 := u2 * u
	return (2.0 * u3 - 3.0 * u2 + 1.0) * v0 + (u3 - 2.0 * u2 + u) * span * m0 + (-2.0 * u3 + 3.0 * u2) * v1 + (u3 - u2) * span * m1


func _build() -> void:
	var low := low_poly or Settings.low_poly
	var model: Node = MODELS[clampi(breed, 0, MODELS.size() - 1)][1 if low else 0].instantiate()
	add_child(model)
	_skeleton = model.find_children("*", "Skeleton3D", true, false)[0]
	Toon.apply(model)
	_body_rest = _rest(&"body")
	var head_at := _body_rest + _rest(&"chest") + _rest(&"neck") + _rest(&"neck_1") + _rest(&"head")
	Fur.apply(model, &"coat", 0 if low else fur_shells, 0.009, 0.02 - head_at.z)
	for part: MeshInstance3D in model.find_children("*", "MeshInstance3D", true, false):
		for surface in part.mesh.get_surface_count():
			var original := part.mesh.surface_get_material(surface) as StandardMaterial3D
			if original and original.resource_name == "eye":
				_eyes = part.get_surface_override_material(surface) as ShaderMaterial
				_eye_colour = original.albedo_color
			elif original and original.resource_name == "coat":
				_coat_colour = original.albedo_color

	_body = _joint(self, &"body")
	_chest = _joint(_body, &"chest")
	_pelvis = _joint(_body, &"pelvis")
	_neck = _joint(_chest, &"neck")
	_neck_1 = _joint(_neck, &"neck_1")
	_head = _joint(_neck_1, &"head")
	_jaw = _joint(_head, &"jaw")
	for i in 4:
		var fore := i < 2
		var bones: Array = []
		var at: Array[Vector3] = []
		for bone: String in ["upper", "lower", "hock", "paw"]:
			bones.append(_joint(_body, bone + SUFFIXES[i]))
			at.append(_body_rest + _rest(bone + SUFFIXES[i]))
		_legs.append(bones)
		_hips.append(at[0])
		_paws.append(at[3])
		_lengths.append(Vector3(at[0].distance_to(at[1]), at[1].distance_to(at[2]), at[2].distance_to(at[3])))
		# How it stands, measured the way `_solve_leg` builds a leg.
		var line := (at[3] - at[0]).normalized()
		var pole := BEHIND if fore else AHEAD
		var aside := (pole - line * pole.dot(line)).normalized()
		var normal := aside.cross(line).normalized()
		var last := (at[3] - at[2]).normalized()
		_spans.append(at[0].distance_to(at[3]))
		_bends.append(atan2(last.dot(aside), last.dot(line)))
		_frames.append([
			_frame(normal, (at[1] - at[0]).normalized()).inverse(), _frame(normal, (at[2] - at[1]).normalized()).inverse(),
			_frame(normal, last).inverse(),
		])
	_paw_height = _paws[0].y
	_size = _hips[2].y / 0.52
	_measure()

	# The tail: stiff at the root, whippy at the end.
	var from := _pelvis
	var names: Array[String] = ["tail", "tail_1", "tail_2", "tail_3", "tail_end"]
	for i in 4:
		var link := _link(from, names[i], _rest(names[i + 1]))
		link.stiffness = lerpf(1800.0, 700.0, i / 3.0)
		link.damping = lerpf(50.0, 26.0, i / 3.0)
		link.gravity = 3.0
		link.limit = 0.7
		_tail.append(link)
		from = link.joint
	# The ears. Hanging, they are leather, with nothing in them but their own
	# weight; standing, they are held where its mood puts them, and only quiver.
	_pricked = _rest(&"ear_tip_l").y > 0.0
	for side in 2:
		var suffix := "_l" if side == 0 else "_r"
		var out := Vector3.RIGHT if side == 0 else Vector3.LEFT
		var root := _link(_head, "ear" + suffix, _rest("ear_tip" + suffix))
		var flap := _link(root.joint, "ear_tip" + suffix, _rest("ear_end" + suffix))
		for link: Link in [root, flap]:
			if _pricked:
				link.stiffness = 900.0 if link == root else 520.0
				link.damping = 20.0 if link == root else 11.0
				link.gravity = 0.0
				link.drag = 0.5
				link.limit = 0.5
			else:
				link.stiffness = 50.0 if link == root else 34.0
				link.damping = 4.2
				link.gravity = 9.0
				link.drag = 2.0
				link.limit = 1.3
				link.outward = out
		_ears[side] = [root, flap]


## Works out, from how it is built, where it puts itself to sit, to lie and to bow.
func _measure() -> void:
	var chest_at := _chest.position
	var pelvis_at := _pelvis.position
	var shoulder := _hips[0] - _body_rest - chest_at
	var hip := _hips[2] - _body_rest - pelvis_at
	shoulder.x = 0.0
	hip.x = 0.0
	# Sitting: its hips on the ground and its shoulders nearly as high as they
	# stand, so that its forelegs are straight under it. Find the slope of its
	# back that does both.
	var sit_hip := SIT_HIP * _size
	var want := _hips[0].y * SIT_SHOULDER - sit_hip
	var low := -1.45
	var high := 0.0
	var shoulder_at := Vector3.ZERO
	var hip_at := Vector3.ZERO
	for step in 24:
		_sit_pitch = (low + high) * 0.5
		var back := Basis(Vector3.RIGHT, _sit_pitch)
		shoulder_at = back * (chest_at + Basis(Vector3.RIGHT, SIT_CHEST) * shoulder)
		hip_at = back * (pelvis_at + Basis(Vector3.RIGHT, SIT_PELVIS) * hip)
		if shoulder_at.y - hip_at.y < want:
			high = _sit_pitch
		else:
			low = _sit_pitch
	# (it sits down where its hind feet were)
	_sit_body = Vector3(0.0, sit_hip - hip_at.y, _paws[2].z + 0.05 * _size - hip_at.z)
	_sit_paws.clear()
	for i in 4:
		var side := signf(_paws[i].x)
		if i < 2:
			# Under the shoulder, as far forward of it as the leg stands
			var top := _sit_body + shoulder_at
			_sit_paws.append(Vector3(_paws[i].x * 0.9, _paw_height, top.z + _paws[i].z - _hips[i].z + (0.006 if i == 0 else -0.006)))
		else:
			# Hock down just in front of the hip, and the paw a hock's length in front of that
			var top := _sit_body + hip_at
			_sit_paws.append(Vector3(_paws[i].x + side * 0.055 * _size, _paw_height, top.z + 0.035 * _size + _lengths[i].z))

	# Lying: its chest on the ground, its elbows down beside it and its forearms
	# straight out in front; behind, its hocks flat and its knees up beside its flanks.
	var elbow_height: float = _body_rest.y + (_legs[0][1] as Node3D).position.y
	_lie_body = Vector3(0.0, _body_rest.y - elbow_height + 0.012 * _size, _body_rest.z - 0.03 * _size)
	_lie_paws.clear()
	for i in 4:
		var side := signf(_paws[i].x)
		var top := _hips[i] - _body_rest + _lie_body
		if i < 2:
			var fall := clampf(top.y - 0.045 * _size, 0.0, _lengths[i].x * 0.98)
			var back := sqrt(_lengths[i].x * _lengths[i].x - fall * fall)
			_lie_paws.append(Vector3(_paws[i].x * 0.95, _paw_height, top.z - back + _lengths[i].y + _lengths[i].z - (0.012 if i == 0 else 0.03) * _size))
		else:
			_lie_paws.append(Vector3(_paws[i].x + side * 0.05 * _size, _paw_height, top.z + (0.13 if i == 2 else 0.1) * _size))
	# Asleep its chin is on the ground between its paws: how far its neck must come down for that.
	var neck_at := chest_at + _neck.position + _lie_body
	var neck_to := _neck_1.position + _head.position
	var slope := atan2(neck_to.y, neck_to.z)
	_lay_angle = slope + asin(clampf((neck_at.y - 0.1 * _size) / neck_to.length(), -1.0, 1.0)) - 0.1

	# The bow: its rump stays up where it was, a little back.
	_bow_pelvis = _body_rest + pelvis_at + Vector3(0.0, -0.02, -0.03) * _size


func _rest(bone: StringName) -> Vector3:
	return _skeleton.get_bone_rest(_skeleton.find_bone(bone)).origin


## Adds a pose node for a bone, where the skeleton has it; its transform is
## copied to the skeleton each frame.
func _joint(parent: Node3D, bone: StringName) -> Node3D:
	var joint := Node3D.new()
	var index := _skeleton.find_bone(bone)
	joint.name = bone
	joint.position = _skeleton.get_bone_rest(index).origin
	parent.add_child(joint)
	_joints.append(joint)
	_bones.append(index)
	return joint


## Adds a bone that swings, reaching from where the skeleton has it to `end` (in its own space).
func _link(parent: Node3D, bone: StringName, end: Vector3) -> Link:
	var link := Link.new()
	link.joint = Node3D.new()
	link.bone = _skeleton.find_bone(bone)
	link.joint.name = bone
	link.joint.position = _skeleton.get_bone_rest(link.bone).origin
	parent.add_child(link.joint)
	link.rest = end.normalized()
	link.aim = link.rest
	link.length = end.length()
	_links.append(link)
	return link
