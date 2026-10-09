class_name CamelRig
extends HoundRig
## Drives the camel model (models/camel*.glb) in code.
##
## It is built on the hound's rig, as the cat's is, and uses what a camel and a
## hound have in common from it unchanged: the three-bone leg solver
## (`_solve_leg`), the path of a foot through a stride (`_foot_cycle`), the
## springs that the tail and the ears hang on (`Link`, `_swing`), the ears that
## turn to listen (`_carry_ears`), the reading of joints from the skeleton
## (`_joint`, `_link`, `_rest`) and the curve and easing helpers. Everything
## that makes it a camel is here, and replaces the hound's `_ready`, `_process`
## and `_build` outright:
##
## - The gaits. A camel does not trot. It walks and it PACES: both legs of one
##   side swing forward together and then both of the other, where a hound's
##   trot pairs each fore leg with the hind leg opposite. So for half of every
##   stride it stands on the legs of one side only, and its body rolls over
##   them and sways from side to side; its neck pumps twice a stride. Flat out
##   it gallops, without much grace. Which it uses goes by its speed.
## - A neck in four pieces (see tools/build_camel.py), carried in an S, which
##   reaches down to browse, turns its head to what it is watching, stretches
##   out when it runs and is thrown up when it complains.
## - Getting down and getting up. It kneels: down onto its knees, forelegs
##   first, with its rump still in the air; then its hind legs fold under it;
##   then it settles forward onto its chest, "couched", every leg folded away.
##   It gets up the other way about: hindquarters first, until it is on its
##   knees with its rump in the air, and then its forelegs, one after the
##   other. The one number that says how far down it is (`_couch`) is run
##   forwards for the one and backwards for the other.
## - Chewing the cud: the lower jaw goes round sideways, not up and down.
## - Standing about: it shifts its weight from side to side, and rests one hind
##   leg at a time on the point of its toes.
## - Heavy eyelids that half close, close in a blink, and shut when it dozes;
##   small ears that flick; a thin tail that switches.
## - Its tack (a saddle and blanket, a halter and its lead rope, packs): each a
##   mesh of its own, shown or hidden by `dress()`.
##
## The Camel says which of these (`posture`, `browsing`, `chewing`, `gaze`);
## how each is done is all here.
##
## What it follows:
## - Sizes: en.wikipedia.org/wiki/Dromedary. 1.7 to 2.4 m at the shoulder, a
##   hump of 20 cm or more, feet about 19 cm across and 18 long, on two toes and
##   one broad pad. The same page for its speeds: it walks at about 4 km/h
##   (1.1 m/s), goes mostly at a "jog" of 8 to 12 km/h (2.2 to 3.3 m/s), runs
##   fast at 14 to 19 (3.9 to 5.3 m/s), and gallops only for short bursts; and
##   for the gait itself: "it moves both legs on one side of the body at the
##   same time".
## - That it has three gaits, walk, pace and gallop: Iglesias Pastrana et al.
##   2023, Front. Vet. Sci. 10:1297430 (gait in Canarian dromedaries).
## - The walk of camelids, from the chapter at cdn.intechopen.com/pdfs/83285.pdf
##   as a web search quotes it (the chapter itself was not read): 0.9 to
##   2.1 m/s, a stride of 1.3 to 1.9 m lasting 1.0 to 1.5 s, the hind foot on
##   the ground for 55 to 75% of it. The walk here is 1.2 m/s, 1.4 m, 1.16 s, 64%.
## - That the pace is a rolling gait, and that the broad splayed feet are
##   thought to be what steadies it from side to side: Theodor, Janis and
##   Boisvert, "Camelid foot morphology and the evolution of the pacing gait"
##   (sicb.org/?p=37597); Janis, Theodor and Boisvert 2002, J. Vert. Paleontol.
##   22:110. The classic account is Dagg 1974, "The locomotion of the camel",
##   J. Zool. 174:67 (not read: no free copy was found).
## - Where the walk gives way to the pace and the pace to the gallop is put, as
##   the hound's changes are, by the Froude number (speed squared over g times
##   leg length; about 0.5 and 3): for a leg of 1.3 m, about 2.5 and 6 m/s,
##   which agrees with the speeds above.
## - Kneeling and rising, forelegs down first and hindquarters up first, is
##   common knowledge to anyone who has ridden one (the rider is thrown forward,
##   then back, then forward again) and no measurement of it was found: the
##   timing here is by eye.
##
## What is NOT measured, and is only chosen to look right: how long after the
## hind foot the fore foot of the same side lands (0.14 of a stride walking,
## 0.04 pacing: a walk in "lateral couplets", and a pace that is very nearly
## two beats), how far the body rolls and sways, and the order of the feet at
## a gallop (taken as the hound's).

const CAMEL_MODELS: Array = [preload("res://models/camel.glb"), preload("res://models/camel_lo.glb")]

## Where in the stride each foot lands (fore left, fore right, hind left, hind right).
## Walk: left hind, left fore, right hind, right fore, the two of a side close together.
const AMBLE: Array[float] = [0.14, 0.64, 0.0, 0.5]
## Pace: the two of a side all but together, the hind a moment first.
const PACING: Array[float] = [0.04, 0.54, 0.0, 0.5]
## Gallop: the hind pair, then the fore pair.
const RUN: Array[float] = [0.62, 0.50, 0.0, 0.12]
## The share of the stride a foot is down, fore and hind, at a walk, a pace and a gallop.
const ON_FORE := Vector3(0.66, 0.42, 0.27)
const ON_HIND := Vector3(0.64, 0.40, 0.25)
## Speeds (m/s) over which the walk gives way to the pace, and the pace to the gallop.
const PACE_AT := Vector2(1.8, 2.4)
const RUN_AT := Vector2(5.0, 5.8)
## Length of a stride (m) against speed (m/s).
const STRIDES := [0.0, 1.1, 1.2, 1.5, 2.2, 1.9, 3.2, 2.2, 5.0, 3.0, 6.5, 4.0, 9.0, 4.8]
## The furthest a planted foot travels under the body (m). No stride is longer
## than lets its feet stay where they are put.
const STEP_REACH := 0.92
## How far a shoulder or a hip goes with its leg.
const SHOULDER_GLIDE := 0.25
## The middle of the first of the two flights of a gallop stride, and how high they throw it (m).
const AIRBORNE := 0.41
const LEAP := 0.06

## How far each joint of the neck is turned down (radians) to bring the head
## right down in front of it: `_neck_low` of 1. Less than 0 lifts it higher than it stands.
const NECK_DOWN: Array[float] = [0.50, 0.80, 0.50, 0.10]
## How much of a turn of the head each joint of the neck takes; the head takes the rest.
const NECK_TURN: Array[float] = [0.12, 0.20, 0.22, 0.18]
## How far the jaw drops, wide open (radians), and how far it goes to each side chewing.
const CAMEL_GAPE := 0.5
const CHEW_SIDE := 0.2
## How many times a second it chews.
const CHEW_RATE := 1.25
## How far an eyelid turns to shut (radians).
const LID_SHUT := 1.0

## How long it takes to get down, and to get up (s).
const DOWN_TIME := 4.6
const UP_TIME := 3.6
## The three parts of getting down, as shares of `_couch`: onto its knees, its
## hind legs folding, and settling onto its chest.
const KNEEL := Vector2(0.0, 0.38)
const SQUAT := Vector2(0.34, 0.76)
const SETTLE := Vector2(0.72, 1.0)
## Couched: how high its shoulders and its hips lie (m), for a camel of this
## model's size; on its knees, how high its shoulders are, as a share of the
## length of its upper arm and forearm together.
const COUCH_SHOULDER := 0.42
const COUCH_HIP := 0.42
const KNEEL_SHOULDER := 0.84
const SQUAT_SHOULDER := 0.72

## Whether it wears each piece of its tack. Call `dress()` after changing any.
var saddled := false
var haltered := false
var packed := false
## Whether the lead rope hangs looped up round its neck (no one has hold of it).
var lead_stowed := true


## Somewhere it puts its body: where, and how its back slopes.
class Lie:
	var body := Vector3.ZERO
	var pitch := 0.0


var _camel: Camel
var _necks: Array[Node3D] = []
var _lids: Array[Node3D] = []
var _seat: Node3D
var _tack := {}
## The line each bone of the neck lies along as it stands, and how long each is.
var _neck_rest: Array[Vector3] = []
## How far the fore feet stand ahead of the hind.
var _between := 1.15

## How far down it is, 0 standing to 1 couched.
var _couch := 0.0
var _kneeling := Lie.new()
var _squatting := Lie.new()
var _couched := Lie.new()
var _fold_fore: Array[Vector3] = [Vector3.ZERO, Vector3.ZERO]
var _fold_hind: Array[Vector3] = [Vector3.ZERO, Vector3.ZERO]
## Which knee goes down first.
var _first_knee := 0
## Which side it is standing over, -1..1, eased.
var _lean := 0.0
## Standing about: which hind leg it is resting, how far, and when it will change.
var _cock := 0.0
var _cock_leg := 2
var _cocked := false
var _cock_timer := 4.0
## Its neck: how far down it is being carried (see NECK_DOWN), and how far its head is tipped down to feed.
var _neck_low := 0.0
var _feeding := 0.0
var _chew := 0.0
var _chew_phase := 0.0
var _lid := 0.0
var _blink := 9.0
var _blink_timer := 3.0
var _switch_timer := 3.0
var _complaint := 0.0
var _gliding := 1.0


func _ready() -> void:
	_build()
	_camel = get_parent() as Camel
	if _camel:
		_camel.voiced.connect(_on_voiced)
		if _camel.posture == Camel.Posture.COUCH:
			_couch = 1.0
	_time = randf() * 10.0
	_mirrored = randf() < 0.5
	_first_knee = randi() % 2
	_cock_leg = 2 + randi() % 2
	_last_yaw = rotation.y


## It has opened its mouth to complain: the jaw keeps time with it, as a hound's does.
func _on_voiced() -> void:
	_voiced = 0.0
	_voice_rate = _camel.voice_rate
	_voice_length = _camel.voice_length
	_envelope = _camel.voice_envelope
	_barked = true


## How far down it is: 0 on its feet, 1 couched.
func couch() -> float:
	return _couch


## Where a rider sits, in the world: on top of the hump, facing the way it faces.
func seat() -> Transform3D:
	return _seat.global_transform


## Where a lead rope is tied to it, in the world: under its chin.
func halter_point() -> Vector3:
	return _head.global_transform * Vector3(0.0, -0.12, 0.31)


## Where the camel behind it in a string is tied on, in the world: at its croup, over its tail.
func hitch_point() -> Vector3:
	return _pelvis.global_transform * (_tail[0].joint.position + Vector3(0.0, 0.06, 0.06))


## Shows the tack it is wearing, and hides the rest.
func dress() -> void:
	for piece: String in _tack:
		var worn: bool = {"saddle": saddled, "halter": haltered, "lead": haltered and lead_stowed, "packs": packed}[piece]
		(_tack[piece] as Node3D).visible = worn


func _process(delta: float) -> void:
	if _camel == null:
		return
	delta = minf(delta, 1.0 / 30.0)
	_time += delta
	var velocity := _camel.velocity
	var speed := Vector2(velocity.x, velocity.z).length()
	var grounded := _camel.is_on_floor()
	_turn = _approach(_turn, angle_difference(_last_yaw, rotation.y) / delta, 6.0, delta)
	_last_yaw = rotation.y
	_voiced += delta * _voice_rate
	_feel(delta, speed)
	var kneel := smoothstep(KNEEL.x, KNEEL.y, _couch)
	var squat := smoothstep(SQUAT.x, SQUAT.y, _couch)
	var settle := smoothstep(SETTLE.x, SETTLE.y, _couch)
	var down := smoothstep(0.0, 0.12, _couch)

	# --- The gait. Turning on the spot it steps round, without going anywhere. ---
	_pace = _approach(_pace, maxf(speed, absf(_turn) * 0.5), 8.0, delta)
	var pacing := smoothstep(PACE_AT.x, PACE_AT.y, _pace)
	var run := smoothstep(RUN_AT.x, RUN_AT.y, _pace)
	var longest := lerpf(lerpf(ON_FORE.x, ON_FORE.y, pacing), ON_FORE.z, run)
	var stride := minf(_keyed(STRIDES, _pace), STEP_REACH * _size / longest)
	if grounded:
		_phase = fposmod(_phase + _pace / stride * delta, 1.0)
	var gait := smoothstep(0.05, 0.5, _pace) * (1.0 - down)
	var travel := clampf(speed / maxf(_pace, 0.05), 0.0, 1.0)
	var lift := lerpf(lerpf(0.11, 0.17, pacing), 0.30, run) * _size
	# At a gallop it is thrown clear of the ground twice a stride.
	var flying := run * gait
	var rise := (0.25 + cos(2.0 * TAU * (_phase - AIRBORNE))) * LEAP * _size * flying
	var targets: Array[Vector3] = []
	var pitches: Array[float] = []
	var load_fore := 0.0
	var load_hind := 0.0
	var load_side := 0.0
	var drop := 0.0
	for i in 4:
		var fore := i < 2
		var duties := ON_FORE if fore else ON_HIND
		var duty := lerpf(lerpf(duties.x, duties.y, pacing), duties.z, run)
		var span := minf(duty * stride, STEP_REACH * _size) * travel
		# (its feet stand a little behind its shoulders and its hips: their ground is brought forward under them)
		var middle := lerpf(0.07 if fore else 0.03, 0.14 if fore else 0.18, run) * _size * travel
		var other := i ^ 1 if _mirrored else i
		var at := fposmod(_phase - lerpf(lerpf(AMBLE[i], PACING[i], pacing), RUN[other], run), 1.0)
		var cycle := _foot_cycle(at, duty, span * 0.5, lift * (1.0 if fore else 0.9))
		var rest := _paws[i]
		var carried := 0.0
		if at >= duty:
			var swing := (at - duty) / (1.0 - duty)
			carried = clampf(minf(swing, 1.0 - swing) * 6.0, 0.0, 1.0) * maxf(rise, 0.0)
		# Going anywhere, its feet come in under it, nearer one line.
		targets.append(Vector3(rest.x * lerpf(1.0, 0.8, gait), _paw_height + (cycle.y + carried) * gait, rest.z + (middle + cycle.z) * gait))
		pitches.append(cycle.x * gait * 0.8)
		if at < duty:
			var bearing := sin(PI * at / duty)
			if fore:
				load_fore += bearing
			else:
				load_hind += bearing
			load_side += bearing * signf(rest.x)
		var from_hip := rest.z - _hips[i].z + middle * gait
		var furthest := (absf(from_hip) + span * 0.5 * gait) * (1.0 - SHOULDER_GLIDE)
		var total := _lengths[i].x + _lengths[i].y + _lengths[i].z - 0.02
		drop = maxf(drop, _hips[i].y - _paw_height - sqrt(maxf(total * total - furthest * furthest, 0.01)))
	_drop = _approach(_drop, drop + 0.006, 9.0, delta)

	# Walking, each end of it rides up over its legs as they pass under it;
	# pacing it sinks onto them and is thrown up off them.
	var sprung := 0.035 * pacing * (1.0 - run) * _size
	var vault := 0.028 * (1.0 - pacing) * _size
	var high_fore := ((load_fore - 0.7) * vault - (load_fore - 0.5) * sprung) * gait
	var high_hind := ((load_hind - 0.7) * vault - (load_hind - 0.5) * sprung) * gait
	# The roll: with the legs of one side under it and the others in the air it
	# goes over onto the side it stands on, and that side rides up.
	_lean = _approach(_lean, clampf(load_side * 0.5, -1.0, 1.0), 12.0, delta)
	var rolling := gait * (1.0 - run)
	var sway := _lean * lerpf(0.035, 0.055, pacing) * _size * rolling
	var roll := _lean * lerpf(0.030, 0.052, pacing) * rolling
	var rock := (high_hind - high_fore) / _between + sin(TAU * (_phase - AIRBORNE)) * 0.075 * flying
	var gather := cos(TAU * (_phase - AIRBORNE - 0.5)) * flying
	var bend := clampf(_turn * 0.05, -0.22, 0.22) * (1.0 - down)
	var swing_fore := (targets[1].z - targets[0].z) * 0.05 * (1.0 - run)
	var swing_hind := (targets[3].z - targets[2].z) * 0.07 * (1.0 - run)
	var bank := clampf(-_turn * speed * 0.01, -0.14, 0.14)

	var body_at := _body_rest + Vector3(sway, -_drop + (high_fore + high_hind) * 0.5 + rise, 0.0)
	var body_turn := Vector3(rock, 0.0, bank + roll)
	var chest_turn := Vector3(gather * 0.08, bend + swing_fore, (targets[0].y - targets[1].y) * 0.12)
	var pelvis_turn := Vector3(-gather * 0.16, -bend * 0.7 + swing_hind, (targets[2].y - targets[3].y) * 0.15)
	var poles: Array[Vector3] = [BEHIND, BEHIND, AHEAD, AHEAD]
	var flat: Array[float] = [0.0, 0.0, 0.0, 0.0]

	# --- Standing about: its weight goes from side to side, and one hind leg is rested on its toe. ---
	var idle := (1.0 - smoothstep(0.02, 0.3, _pace)) * (1.0 - down)
	body_at.x += sin(_time * 0.37) * 0.018 * _size * idle
	body_turn.z += sin(_time * 0.37 + 0.6) * 0.012 * idle
	if _cock > 0.001:
		var out := signf(_paws[_cock_leg].x)
		targets[_cock_leg] += Vector3(0.0, 0.05, 0.13) * _size * _cock
		pitches[_cock_leg] += 0.85 * _cock
		pelvis_turn.z -= out * 0.045 * _cock
		body_at.x -= out * 0.03 * _size * _cock

	# --- Getting down and getting up: onto its knees, then its hind legs, then its chest. ---
	if _couch > 0.0:
		body_at = body_at.lerp(_kneeling.body, kneel).lerp(_squatting.body, squat).lerp(_couched.body, settle)
		body_turn = body_turn.lerp(Vector3(_kneeling.pitch, 0.0, 0.0), kneel).lerp(Vector3(_squatting.pitch, 0.0, 0.0), squat).lerp(Vector3(_couched.pitch, 0.0, 0.0), settle)
		chest_turn *= 1.0 - kneel
		pelvis_turn *= 1.0 - kneel
		for i in 4:
			var fore := i < 2
			# Each leg is folded in its turn: one knee and then the other, one hind leg and then the other.
			var raw := clampf(inverse_lerp(KNEEL.x, KNEEL.y, _couch) if fore else inverse_lerp(SQUAT.x, SQUAT.y, _couch), 0.0, 1.0)
			var late := (i % 2 == _first_knee) != fore
			var step := smoothstep(0.0, 1.0, clampf(raw * 1.4 - (0.4 if late else 0.0), 0.0, 1.0))
			var folded: Vector3 = _fold_fore[i] if fore else _fold_hind[i - 2]
			# (the foot is picked up and tucked back under it)
			targets[i] = targets[i].lerp(folded, step) + Vector3.UP * sin(PI * step) * (0.16 if fore else 0.07) * _size
			flat[i] = smoothstep(0.35, 0.95, step)
			if fore:
				# The cannon is doubled back under the forearm, and the foot lies sole up behind it.
				pitches[i] = lerpf(pitches[i], 2.7, smoothstep(0.2, 0.9, step))
			else:
				pitches[i] *= 1.0 - step
				poles[i] = AHEAD.slerp(Vector3(signf(_hips[i].x) * 0.22, 0.1, 1.0).normalized(), step)

	_gliding = 1.0 - down
	_body.position = body_at
	_body.rotation = body_turn
	_chest.rotation = chest_turn
	_pelvis.rotation = pelvis_turn
	_breathe_slow()
	_watch(delta)
	_pose_neck(delta, body_turn.x + chest_turn.x, pacing, run, flying, gait, kneel * (1.0 - squat))
	_pose_face(delta)
	_place_legs(targets, pitches, poles, flat)
	_carry(delta, pacing, run)
	_alert = _approach(_alert, 1.0 if is_instance_valid(_camel.gaze) else 0.0, 3.0, delta)
	_cowed = _camel.afraid
	_carry_ears(delta, run)
	for i in _joints.size():
		_skeleton.set_bone_pose(_bones[i], _joints[i].transform)
	_swing(delta)


## What it is doing, eased in and out.
func _feel(delta: float, speed: float) -> void:
	# It does not start to get down until it has stopped, and takes its time over it.
	var want := 1.0 if _camel.posture == Camel.Posture.COUCH and (speed < 0.15 or _couch > 0.0) else 0.0
	_couch = move_toward(_couch, want, delta / (DOWN_TIME if want > 0.5 else UP_TIME))
	_lain = _lain + delta if _couch >= 1.0 else 0.0
	_doze = _approach(_doze, 1.0 if _camel.dozing and _couch >= 1.0 else 0.0, 0.7 if _camel.dozing else 4.0, delta)
	_chew = _approach(_chew, 1.0 if _camel.chewing else 0.0, 3.0, delta)
	_chew_phase += delta * TAU * CHEW_RATE
	_feeding = _approach(_feeding, 1.0 if _camel.browsing else 0.0, 2.2, delta)
	_complaint = _approach(_complaint, 1.0 if _voice_open() > 0.15 else 0.0, 5.0 if _voice_open() > 0.15 else 2.0, delta)
	# Resting a hind leg: now one, now the other, now neither.
	_cock_timer -= delta
	var still := speed < 0.05 and _couch <= 0.0 and absf(_turn) < 0.1
	if _cock_timer <= 0.0:
		_cock_timer = randf_range(6.0, 14.0)
		_cocked = randf() < 0.7
		if _cocked and _cock < 0.05:
			_cock_leg = 2 + randi() % 2
	_cock = _approach(_cock, 1.0 if _cocked and still else 0.0, 1.6 if still else 7.0, delta)
	_blink_timer -= delta
	if _blink_timer <= 0.0:
		_blink_timer = randf_range(2.5, 7.0)
		_blink = 0.0
	_blink += delta


## Its ribs: slowly.
func _breathe_slow() -> void:
	_breath += get_process_delta_time() * TAU * lerpf(0.24, 0.16, _doze)
	var swell := sin(_breath) * 0.012
	_chest.scale = Vector3(1.0 + swell, 1.0 + swell, 1.0)
	_necks[0].scale = Vector3.ONE / _chest.scale


## Where it is looking: at what the Camel says, or else slowly about it.
func _watch(delta: float) -> void:
	var target := Vector2.ZERO
	var at := Vector3.INF
	if is_instance_valid(_camel.gaze):
		at = _camel.gaze.global_position + Vector3.UP * _height_of(_camel.gaze)
	elif _camel.gaze_at != Vector3.INF:
		at = _camel.gaze_at
	if at != Vector3.INF:
		var to := at - _head.global_position
		target.x = clampf(angle_difference(rotation.y, atan2(to.x, to.z)), -2.0, 2.0)
		target.y = clampf(-atan2(to.y, Vector2(to.x, to.z).length()), -0.6, 0.8)
	else:
		target.x = (sin(_time * 0.23) * 0.5 + sin(_time * 0.61 + 1.0) * 0.15) * (1.0 - smoothstep(0.3, 1.5, _pace) * 0.7)
		target.y = sin(_time * 0.17 + 2.0) * 0.05
	# (it turns its head as it does everything: in its own time)
	_look = _look.lerp(target * (1.0 - _doze), 1.0 - exp(-3.2 * delta))


static func _height_of(thing: Node3D) -> float:
	if thing is Player:
		return 0.95
	return 1.9 if thing is Camel else 0.4


## Where the top of the neck comes, from its root, with the neck carried `low`: (how far up, how far forward).
func _neck_reach(low: float) -> Vector2:
	var at := Vector2.ZERO
	var turned := 0.0
	for i in 4:
		turned += NECK_DOWN[i] * low
		var along := _neck_rest[i]
		at += Vector2(along.y * cos(turned) - along.z * sin(turned), along.y * sin(turned) + along.z * cos(turned))
	return at


## How low the neck must be carried to bring the top of it `height` above the ground it stands on.
func _low_for(height: float) -> float:
	var root := _body_rest.y + _chest.position.y + _necks[0].position.y
	var least := -0.3
	var most := 1.4
	for step in 12:
		var middle := (least + most) * 0.5
		if root + _neck_reach(middle).x > height:
			least = middle
		else:
			most = middle
	return (least + most) * 0.5


## The neck and the head. The head is kept level whatever is under it, and is
## turned to what it is watching; the neck is carried higher or lower, pumps as
## it walks, goes down to feed, and takes most of any turn of the head.
func _pose_neck(delta: float, upstream: float, pacing: float, run: float, flying: float, gait: float, lurch: float) -> void:
	var feeding := smoothstep(0.0, 1.0, _feeding)
	# How it is carried: a little lower and further forward going anywhere,
	# stretched right out at a gallop, up when it is wary, sunk when it dozes.
	var low := (0.06 + 0.06 * pacing) * gait + 0.34 * flying - 0.10 * _alert - 0.22 * _camel.afraid + 0.22 * _doze - 0.14 * _complaint
	# (kneeling, its neck goes out and down in front as its chest drops, and comes back)
	low += 0.30 * lurch
	if feeding > 0.0:
		low = lerpf(low, _low_for(_camel.browse_height + 0.25 * _size), feeding)
	_neck_low = _approach(_neck_low, low, 3.0, delta)
	# The pump: back as the legs of each side take its weight, forward as they leave the ground.
	var pump := sin(2.0 * TAU * (_phase - 0.12)) * lerpf(0.035, 0.055, pacing) * gait * (1.0 - run)
	pump += sin(TAU * (_phase - AIRBORNE)) * 0.09 * flying
	var yaw := _look.x
	var pitch := _look.y * (1.0 - feeding)
	var turned := 0.0
	for i in 4:
		var bent := NECK_DOWN[i] * _neck_low + (pump - upstream * 0.5 if i == 0 else 0.0) + (pitch * 0.2 if i == 3 else 0.0)
		turned += bent
		_necks[i].rotation = Vector3(bent, yaw * NECK_TURN[i], 0.0)
	# Its nose is level as it stands; down to what it is eating, and up to complain.
	var nose := pitch * 0.8 + feeding * 0.95 - _complaint * 0.4 + 0.25 * _doze - 0.12 * flying
	_head.rotation = Vector3(nose - turned - upstream + pump * 0.4, yaw * (1.0 - NECK_TURN[0] - NECK_TURN[1] - NECK_TURN[2] - NECK_TURN[3]), -_body.rotation.z * 0.6)
	_chest.rotation.y += yaw * 0.04 * (1.0 - smoothstep(0.0, 0.2, _couch))


## Its face: the jaw, which chews from side to side and opens to complain, and its eyelids.
func _pose_face(_delta: float) -> void:
	var chewing := _chew * (1.0 - smoothstep(0.1, 0.3, _voice_open()))
	# The jaw drops on one side, is carried across, and is ground shut on the other.
	var open := maxf(_voice_open(), chewing * (0.13 + 0.09 * cos(_chew_phase)))
	_mouth = lerpf(_mouth, open, 0.4)
	_jaw.rotation = Vector3(_mouth * CAMEL_GAPE, sin(_chew_phase) * CHEW_SIDE * chewing, 0.0)
	_jaw.position.x = sin(_chew_phase) * 0.008 * _size * chewing
	# Half shut as they are; shut in a blink, and when it dozes; wide when it is afraid.
	var blink := sin(PI * clampf(_blink / 0.22, 0.0, 1.0))
	var shut := maxf(maxf(blink, _doze), 0.3 * _chew * (1.0 - _alert)) - 0.3 * _camel.afraid * (1.0 - blink)
	_lid = lerpf(_lid, shut, 0.5)
	for i in 2:
		_lids[i].rotation.z = (-1.0 if i == 0 else 1.0) * _lid * LID_SHUT


func _place_legs(targets: Array[Vector3], pitches: Array[float], poles: Array[Vector3], flat: Array[float]) -> void:
	var to_body := _body.transform.affine_inverse()
	for i in 4:
		var fore := i < 2
		var rest := _paws[i]
		var spine := _chest if fore else _pelvis
		var hip := spine.transform * (_hips[i] - _body_rest - spine.position)
		var paw := to_body * targets[i]
		# The shoulder slides over the ribs, and the hip swings, with the leg.
		var under := hip.z + rest.z - _hips[i].z
		hip.z += clampf((paw.z - under) * SHOULDER_GLIDE, -0.11, 0.11) * _size * _gliding
		var lifted := clampf((targets[i].y - _paw_height) / (0.1 * _size), 0.0, 1.0) * (1.0 - flat[i])
		# (laid on the ground, a cannon points back from the knee in front, and forward from the hock behind)
		_solve_leg(i, hip, paw, to_body.basis * Basis(Vector3.RIGHT, pitches[i]), to_body.basis * poles[i], to_body.basis * (BEHIND if fore else AHEAD), flat[i], lifted)


## Its tail: hanging, carried out behind when it runs or is afraid, and switched now and then.
func _carry(delta: float, pacing: float, run: float) -> void:
	var carried := 0.08 + 0.22 * pacing + 0.6 * run + 0.5 * _camel.afraid
	for i in _tail.size():
		var link := _tail[i]
		link.aim = Basis(Vector3.RIGHT, carried if i == 0 else carried * 0.25) * link.rest
	_switch_timer -= delta
	if _switch_timer <= 0.0:
		_switch_timer = randf_range(2.0, 7.0)
		if _doze < 0.5:
			var flick := global_basis.x * (1.0 if randf() < 0.5 else -1.0) * randf_range(2.0, 4.0)
			_tail[-1].velocity += flick
			_tail[-2].velocity += flick * 0.7
			_tail[-3].velocity += flick * 0.3
		if randf() < 0.5:
			# (and an ear, at a fly)
			var which := randi() % 2
			_flick(which, Vector3(0.5 if which == 0 else -0.5, 0.0, -0.4))


func _build() -> void:
	var low := low_poly or Settings.low_poly
	var model: Node = CAMEL_MODELS[1 if low else 0].instantiate()
	add_child(model)
	_skeleton = model.find_children("*", "Skeleton3D", true, false)[0]
	Toon.apply(model)
	for part: MeshInstance3D in model.find_children("*", "MeshInstance3D", true, false):
		for piece: String in ["saddle", "halter", "lead", "packs"]:
			if String(part.name).ends_with("_" + piece):
				_tack[piece] = part
	_body_rest = _rest(&"body")
	_body = _joint(self, &"body")
	_chest = _joint(_body, &"chest")
	_pelvis = _joint(_body, &"pelvis")
	_seat = _joint(_body, &"seat")
	var from := _chest
	var root := _body_rest + _rest(&"chest")
	var length := 0.0
	var names: Array[String] = ["neck", "neck_1", "neck_2", "neck_3", "head"]
	for i in 4:
		from = _joint(from, names[i])
		_necks.append(from)
		_neck_rest.append(_rest(names[i + 1]))
		length += _neck_rest[i].length()
	root += _rest(&"neck")
	_neck = _necks[0]
	_neck_1 = _necks[1]
	_head = _joint(from, &"head")
	_jaw = _joint(_head, &"jaw")
	for suffix: String in ["_l", "_r"]:
		_lids.append(_joint(_head, "lid" + suffix))
	# A short coat, shorter still on its face: everything forward of the top of its neck, along the lie of the hair.
	var shells := 0 if low else fur_shells
	Fur.apply(model, &"coat", shells, 0.012, 0.04 - root.z - length)
	for part: MeshInstance3D in model.find_children("*", "MeshInstance3D", true, false):
		for surface in part.mesh.get_surface_count():
			var original := part.mesh.surface_get_material(surface) as StandardMaterial3D
			if original and original.resource_name == "coat":
				_coat_colour = original.albedo_color
				Fur.tune(part.get_surface_override_material(surface) as ShaderMaterial, {
					&"strands": 420.0, &"run": 0.05, &"tufts": 640.0, &"patch": 0.16, &"streak": 0.22, &"root_shade": 0.3, &"droop": 0.5, &"face_length": 0.4,
					&"sheen_gain": 0.04, &"rim_gain": 0.35,
				})

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
	_size = _hips[2].y / 1.42
	_between = _paws[0].z - _paws[2].z
	_measure_camel()

	# The tail: thin, hanging straight down, and whippy.
	from = _pelvis
	names = ["tail", "tail_1", "tail_2", "tail_3", "tail_end"]
	for i in 4:
		var link := _link(from, names[i], _rest(names[i + 1]))
		link.stiffness = lerpf(700.0, 160.0, i / 3.0)
		link.damping = lerpf(30.0, 12.0, i / 3.0)
		link.gravity = 6.0
		link.drag = 1.5
		link.limit = lerpf(0.5, 1.0, i / 3.0)
		_tail.append(link)
		from = link.joint
	# The ears stand, and are turned and laid back as a hound's that stand are.
	_pricked = true
	for side in 2:
		var suffix := "_l" if side == 0 else "_r"
		var ear := _link(_head, "ear" + suffix, _rest("ear_tip" + suffix))
		var flap := _link(ear.joint, "ear_tip" + suffix, _rest("ear_end" + suffix))
		for link: Link in [ear, flap]:
			link.stiffness = 900.0 if link == ear else 520.0
			link.damping = 20.0 if link == ear else 11.0
			link.gravity = 0.0
			link.drag = 0.5
			link.limit = 0.5
		_ears[side] = [ear, flap]
	dress()


## Where its body goes to bring its shoulders `shoulder` above the ground and
## its hips `hip` above it, with its shoulders `forward` along it.
func _lie_for(shoulder: float, hip: float, forward: float) -> Lie:
	var front := _hips[0] - _body_rest
	var back := _hips[2] - _body_rest
	front.x = 0.0
	back.x = 0.0
	var apart := front - back
	var made := Lie.new()
	made.pitch = acos(clampf((shoulder - hip) / Vector2(apart.y, apart.z).length(), -1.0, 1.0)) - atan2(apart.z, apart.y)
	var turned := Basis(Vector3.RIGHT, made.pitch) * front
	made.body = Vector3(0.0, shoulder - turned.y, forward - turned.z)
	return made


## Works out, from how it is built, where it puts itself on its knees, with its
## hind legs folded, and couched, and where its folded feet lie.
func _measure_camel() -> void:
	var arm := _lengths[0].x + _lengths[0].y
	# Its knees come down a little ahead of where its fore feet stood, and stay there.
	var knee := _paws[0].z + 0.10 * _size
	_kneeling = _lie_for(_paw_height + arm * KNEEL_SHOULDER, _hips[2].y - 0.05 * _size, knee + 0.02 * _size)
	_squatting = _lie_for(_paw_height + arm * SQUAT_SHOULDER, COUCH_HIP * _size, knee - 0.12 * _size)
	_couched = _lie_for(COUCH_SHOULDER * _size, COUCH_HIP * _size, knee - 0.17 * _size)
	var hip := _couched.body + Basis(Vector3.RIGHT, _couched.pitch) * (_hips[2] - _body_rest)
	for i in 2:
		# Each fore foot a cannon's length behind its knee; each hind foot forward under its flank, its hock out behind
		_fold_fore[i] = Vector3(_paws[i].x * 0.9, _paw_height, knee - _lengths[i].z)
		_fold_hind[i] = Vector3(_paws[i + 2].x * 1.12, _paw_height, hip.z + 0.31 * _size)
