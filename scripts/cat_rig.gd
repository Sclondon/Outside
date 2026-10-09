class_name CatRig
extends HoundRig
## Drives a cat model (models/cat*.glb) in code.
##
## It is built on the hound's rig and uses what a cat and a hound have in
## common from it unchanged: the three-bone leg solver (`_solve_leg`), the path
## of a paw through a stride (`_foot_cycle`), the springs that the tail and the
## ears hang on (`Link`, `_swing`), the breathing, the reading of joints from
## the skeleton (`_joint`, `_link`, `_rest`) and the curve and easing helpers.
## Everything that makes it a cat and not a small dog is here, and replaces the
## hound's `_ready`, `_process` and `_build` outright:
##
## - A back in six pieces (see tools/build_cat.py), bent as one curve. It
##   rounds and hollows far more than a hound's: at a gallop, when it stretches,
##   when it sits, and right round on itself when it sleeps.
## - The walk. A cat puts each hind paw down where the fore paw of that side
##   has just been, which fixes how long after the fore paw the hind one lands:
##   the distance between them over the length of the stride. So the timing is
##   worked out from the stride instead of being a list, and the walk runs into
##   the trot (where that share is a half) of its own accord. Its paws come in
##   under it onto one line, its head is carried low and does not move, and
##   the shoulder blade over whichever foreleg is carrying it stands up
##   through its coat.
## - The bound: hind paws together and well ahead of where the fore paws were,
##   the back rounding right up and then thrown out straight.
## - Stalking (`Cat.creep`): belly to the ground, elbows above its back, each
##   paw held and then placed; and the wiggle of its hindquarters before it
##   springs.
## - Springing: up onto things, down off them, and onto things it is hunting.
##   In the air it lies along the way it is going; its forelegs leave the
##   ground first and its hind legs last, and it lands on its forepaws and
##   brings its hind feet in under it afterwards.
## - Sitting upright with its tail round its feet, the loaf, lying flat on its
##   side, and asleep curled up; the two stretches on waking; washing a paw
##   and its face with it; rubbing against someone's leg.
## - A tail of seven bones that says what it thinks: straight up with a hook
##   at the tip, lashing, or stood up and bristling.
## - Ears that each turn to what they hear, eyes that narrow in the slow blink
##   and pupils that open, whiskers that come forward, toes that spread.
##
## The Cat says which of these (`posture`, `act`, `mood`, `creep`, `rub`,
## `gaze`); how each is done is all here.
##
## What it follows (the pictures are in inspirationArt/reference/cat/):
## - Muybridge, Animal Locomotion (1887), plates 717 to 720, a cat trotting and
##   galloping: at a trot the head is carried level with the back or under it,
##   the rump stands higher than the shoulders, and the tail trails low. At a
##   gallop the hind feet come down together ahead of where the fore feet
##   stood, the back hunched almost into a ball, the tail thrown up; then the
##   whole cat goes out into one line, forelegs straight ahead, and it is in
##   the air stretched out for about a sixth of the stride. Plate 730, a
##   tigress walking at the camera: the paws are placed on one line, even
##   crossing, the shoulder blades stand above the spine, and the head does not
##   turn with the body.
## - Speeds and timing, as dogs' are in HoundRig, by the Froude number: with
##   legs of 0.2 m the walk gives way to the trot at about 1 m/s and the trot
##   to the gallop at about 2.5. A walking cat's paws are down about 0.6 to
##   0.65 of the stride.

const CAT_MODELS: Array[Array] = [
	[preload("res://models/cat.glb"), preload("res://models/cat_lo.glb")],
	[preload("res://models/cat_tabby.glb"), preload("res://models/cat_tabby_lo.glb")],
]
## The coats: the colour of the coat, of its markings and of its belly, how
## strongly it is marked, and its eyes.
const COATS := {
	&"bronze": [Color(0.60, 0.44, 0.27), Color(0.13, 0.08, 0.05), Color(0.80, 0.69, 0.52), 1.0, Color(0.50, 0.66, 0.20)],
	&"silver": [Color(0.63, 0.63, 0.61), Color(0.09, 0.09, 0.10), Color(0.86, 0.86, 0.84), 1.0, Color(0.46, 0.68, 0.30)],
	&"black": [Color(0.035, 0.035, 0.042), Color(0.02, 0.02, 0.025), Color(0.045, 0.045, 0.05), 0.0, Color(0.86, 0.62, 0.12)],
	&"ruddy": [Color(0.62, 0.36, 0.17), Color(0.36, 0.19, 0.09), Color(0.76, 0.56, 0.36), 0.45, Color(0.80, 0.58, 0.16)],
	&"tabby": [Color(0.46, 0.39, 0.30), Color(0.10, 0.08, 0.06), Color(0.78, 0.72, 0.62), 1.0, Color(0.62, 0.66, 0.24)],
	&"ginger": [Color(0.78, 0.47, 0.18), Color(0.55, 0.27, 0.08), Color(0.90, 0.80, 0.66), 0.9, Color(0.78, 0.60, 0.18)],
}

## Speeds (m/s) over which the walk gives way to the trot, and the trot to the bound.
const PACE_TROT := Vector2(0.95, 1.35)
const PACE_BOUND := Vector2(2.3, 3.0)
## Length of a stride (m) against speed (m/s).
const PACES := [0.0, 0.26, 0.3, 0.30, 0.7, 0.445, 1.5, 0.62, 2.4, 0.80, 4.0, 1.10, 6.0, 1.45, 8.0, 1.75]
## The share of the stride a paw is down, fore and hind, at a walk, a trot and a bound.
const DOWN_FORE := Vector3(0.64, 0.46, 0.26)
const DOWN_HIND := Vector3(0.62, 0.42, 0.24)
## Where in the stride each paw lands at a bound: the hind pair all but together.
const BOUND_ORDER: Array[float] = [0.58, 0.47, 0.0, 0.08]
## The middle of the flight in which it is stretched out, as a share of the stride.
const STRETCHED := 0.40
## How high the bound throws it (m).
const SPRING := 0.03
## The furthest a planted paw travels under the body (m).
const PAW_REACH := 0.30
## How far a shoulder or a hip goes with its leg. More than a hound's: a cat's
## shoulder blade is free, and swings with the leg.
const SLIDE := 0.36

## How long each thing it does lasts (s). The Cat keeps its `act` for this long.
const ACT_TIMES := {
	Cat.Act.NONE: 0.0, Cat.Act.WIGGLE: 1.1, Cat.Act.GATHER: 0.55, Cat.Act.REACH: 0.7, Cat.Act.STRETCH_BOW: 3.0,
	Cat.Act.STRETCH_ARCH: 2.2, Cat.Act.GROOM: 7.0, Cat.Act.YAWN: 1.8,
}

## Which model: 0 the temple cat, 1 the heavier house cat. Set before entering the tree.
var build := 0
## Which coat, one of COATS. Set before entering the tree, or call `dress()` after changing it.
var coat: StringName = &"bronze"


## Somewhere it puts itself: where its body is and how it is turned, how its
## back is bent (in front of the middle, and behind it), and where its paws go.
class Stance:
	var body := Vector3.ZERO
	var turn := Vector3.ZERO
	var front := Vector3.ZERO
	var rear := Vector3.ZERO
	## Its paws: on the ground, in the rig's space; or, with `local`, from the
	## hip of each in the space of its chest or its hindquarters (lying on its
	## side, its legs go with it).
	var paws: Array[Vector3] = [Vector3.ZERO, Vector3.ZERO, Vector3.ZERO, Vector3.ZERO]
	var local := false
	var poles: Array[Vector3] = [Vector3(0, 0, -1), Vector3(0, 0, -1), Vector3(0, 0, 1), Vector3(0, 0, 1)]
	var flat: Array[float] = [0.0, 0.0, 0.0, 0.0]


var _cat: Cat
var _spine_1: Node3D
var _loin: Node3D
var _loin_1: Node3D
var _blades: Array[Node3D] = []
var _toes: Array[Node3D] = []
var _eye_joints: Array[Node3D] = []
var _pupils: Array[Node3D] = []
var _whiskers: Array[Node3D] = []
var _coats: Array[ShaderMaterial] = []
var _tail_coat: ShaderMaterial
var _pupil_material: ShaderMaterial
## Each hip (or shoulder) from the joint of the back it hangs on, and the line each bone of the tail lies along.
var _hip_local: Array[Vector3] = []
var _tail_rest: Array[Vector3] = []
## How far the fore paws stand ahead of the hind.
var _between := 0.33

var _sitting := Stance.new()
var _loafing := Stance.new()
var _on_side := Stance.new()
var _curled := Stance.new()
var _arched := Stance.new()

## What it is being put into this frame (see `_lay`).
var p_body := Vector3.ZERO
var p_turn := Vector3.ZERO
var p_front := Vector3.ZERO
var p_rear := Vector3.ZERO
var p_targets: Array[Vector3] = [Vector3.ZERO, Vector3.ZERO, Vector3.ZERO, Vector3.ZERO]
var p_locals: Array[Vector3] = [Vector3.ZERO, Vector3.ZERO, Vector3.ZERO, Vector3.ZERO]
var p_local: Array[float] = [0.0, 0.0, 0.0, 0.0]
var p_poles: Array[Vector3] = [Vector3.ZERO, Vector3.ZERO, Vector3.ZERO, Vector3.ZERO]
var p_lpoles: Array[Vector3] = [Vector3.ZERO, Vector3.ZERO, Vector3.ZERO, Vector3.ZERO]
var p_flat: Array[float] = [0.0, 0.0, 0.0, 0.0]
var p_pitch: Array[float] = [0.0, 0.0, 0.0, 0.0]
var p_lift: Array[float] = [0.0, 0.0, 0.0, 0.0]
var p_neck := Vector3.ZERO
var p_head := Vector3.ZERO

## How far into each way of resting it is, 0..1.
var _w_sit := 0.0
var _w_loaf := 0.0
var _w_side := 0.0
var _w_curl := 0.0
## And into each thing it does.
var _creep := 0.0
var _wiggle := 0.0
var _gather := 0.0
var _reach := 0.0
var _arch := 0.0
var _groom := 0.0
var _yawn := 0.0
var _rub := 0.0
var _rub_side := 1.0
var _act := 0
var _act_time := 0.0
## What it feels, each 0..1.
var _friendly := 0.0
var _annoyed := 0.0
var _fright := 0.0
var _hunting := 0.0
var _puff := -1.0
## In the air: its forelegs leave first and land first.
var _air_fore := 0.0
var _air_hind := 0.0
var _launch: Array[Vector3] = [Vector3.ZERO, Vector3.ZERO]
var _launched := false
var _fall := 0.0
var _lash := 0.0
var _lid := 1.0
var _blink := 9.0
var _blink_length := 0.15
var _blink_timer := 3.0
var _glance := Vector2.ZERO
var _glance_timer := 1.0
var _wide := 0.0
var _groom_paw := 0
var _blade_lift := Vector2.ZERO
var _spread := 0.0
var _tail_twitch := 1.0
var _wrap := 1.0
var _mouth_at := Vector3.ZERO
var _tail_high := 0.0
## How far its shoulders and hips go with its legs: only while it is on its feet.
var _sliding := 1.0


func _ready() -> void:
	_build()
	_cat = get_parent() as Cat
	if _cat:
		_cat.voiced.connect(_on_voiced)
	_time = randf() * 10.0
	_mirrored = randf() < 0.5
	_side = 1.0 if randf() < 0.5 else -1.0
	_wrap = 1.0 if randf() < 0.5 else -1.0
	_groom_paw = randi() % 2
	_last_yaw = rotation.y


## It has opened its mouth to say something: the jaw keeps time with it, as a hound's does.
func _on_voiced() -> void:
	_voiced = 0.0
	_voice_rate = _cat.voice_rate
	_voice_length = _cat.voice_length
	_envelope = _cat.voice_envelope
	_barked = true


func _process(delta: float) -> void:
	if _cat == null:
		return
	delta = minf(delta, 1.0 / 30.0)
	_time += delta
	var velocity := _cat.velocity
	var speed := Vector2(velocity.x, velocity.z).length()
	var grounded := _cat.grounded
	_turn = _approach(_turn, angle_difference(_last_yaw, rotation.y) / delta, 8.0, delta)
	_last_yaw = rotation.y
	_voiced += delta * _voice_rate
	_feel(delta, grounded)

	# --- Off the ground. Its forelegs leave first; coming down, they land first. ---
	if grounded:
		_air_fore = _approach(_air_fore, 0.0, 34.0, delta)
		_air_hind = _approach(_air_hind, 0.0, 13.0, delta)
		_launched = false
	else:
		if not _launched:
			_launched = true
			for i in 2:
				_launch[i] = (_legs[i + 2][3] as Node3D).global_position
		_air_fore = _approach(_air_fore, 1.0, 26.0, delta)
		_air_hind = _approach(_air_hind, 1.0, 16.0, delta)
		_fall = _approach(_fall, smoothstep(-2.2, 2.2, -velocity.y), 14.0, delta)
	_air = maxf(_air_fore, _air_hind)
	if grounded and not _was_grounded:
		_crouch_velocity += clampf(-velocity.y * 0.16 + 0.35, 0.35, 1.5)
		_spread = 1.0
	_was_grounded = grounded
	_crouch_velocity += (-_crouch * 210.0 - _crouch_velocity * 24.0) * delta
	_crouch = clampf(_crouch + _crouch_velocity * delta, -0.012, 0.075)
	_spread = _approach(_spread, 0.0, 3.0, delta)

	var sit := smoothstep(0.0, 1.0, _w_sit)
	var loaf := smoothstep(0.0, 1.0, _w_loaf)
	var side := smoothstep(0.0, 1.0, _w_side)
	var curl := smoothstep(0.0, 1.0, _w_curl)
	var down := maxf(maxf(sit, loaf), maxf(side, curl))
	var low := maxf(loaf, maxf(side, curl))
	var bow := clampf(_bow, 0.0, 1.0) * (1.0 - _air)

	# --- The gait. ---
	_pace = _approach(_pace, maxf(speed, absf(_turn) * 0.1), 10.0, delta)
	var trot := smoothstep(PACE_TROT.x, PACE_TROT.y, _pace)
	var bound := smoothstep(PACE_BOUND.x, PACE_BOUND.y, _pace)
	var stride := _keyed(PACES, _pace) * lerpf(1.0, 0.72, _creep)
	if grounded:
		_phase = fposmod(_phase + _pace / stride * delta, 1.0)
	# (stalking, it stops with a paw in the air and does not put it down)
	var gait := maxf(smoothstep(0.03, 0.22, _pace), _creep * (1.0 - _wiggle)) * (1.0 - _air) * (1.0 - down) * (1.0 - bow)
	var travel := clampf(speed / maxf(_pace, 0.05), 0.0, 1.0)
	var lift := lerpf(lerpf(lerpf(0.026, 0.036, trot), 0.07, bound), 0.034, _creep)
	# The hind paw comes down in the print of the fore paw of its own side:
	# that far round the stride after it.
	var lag := clampf(1.0 - _between / stride, 0.25, 0.5)
	var order: Array[float] = [lag, 0.5 + lag, 0.0, 0.5]
	var flying := bound * gait
	var rise := (0.25 + cos(2.0 * TAU * (_phase - STRETCHED))) * SPRING * flying
	var load_fore := 0.0
	var load_hind := 0.0
	var bearing := Vector2.ZERO
	var drop := 0.0
	var narrow := lerpf(lerpf(lerpf(0.42, 0.6, trot), 0.95, bound), 0.7, _creep)
	for i in 4:
		var fore := i < 2
		var duties := DOWN_FORE if fore else DOWN_HIND
		var duty := lerpf(lerpf(lerpf(duties.x, duties.y, trot), duties.z, bound), 0.74, _creep)
		var span := minf(duty * stride, PAW_REACH) * travel
		var middle := lerpf(-0.012 if fore else 0.004, 0.035 if fore else 0.085, bound) * travel
		var other := i ^ 1 if _mirrored else i
		var at := fposmod(_phase - lerpf(order[i], BOUND_ORDER[other], bound), 1.0)
		var cycle := _foot_cycle(at, duty, span * 0.5, lift * (1.0 if fore else 0.85))
		var rest := _paws[i]
		var carried := 0.0
		if at >= duty:
			var swing := (at - duty) / (1.0 - duty)
			carried = clampf(minf(swing, 1.0 - swing) * 6.0, 0.0, 1.0) * maxf(rise, 0.0)
		p_targets[i] = Vector3(rest.x * lerpf(1.0, narrow, gait), _paw_height + (cycle.y + carried) * gait, rest.z + (middle + cycle.z) * gait)
		# (a cat's paw hangs from the wrist as it comes through, and is put down toes first)
		p_pitch[i] = cycle.x * gait * (1.25 if fore else 1.0)
		p_lift[i] = clampf(cycle.y * gait / 0.02, 0.0, 1.0)
		p_poles[i] = BEHIND if fore else AHEAD
		p_flat[i] = 0.0
		p_local[i] = 0.0
		if at < duty:
			var weight := sin(PI * at / duty)
			if fore:
				load_fore += weight
				bearing[i] = weight
			else:
				load_hind += weight
		var from_hip := rest.z - _hips[i].z + middle * gait
		var furthest := (absf(from_hip) + span * 0.5 * gait) * (1.0 - SLIDE)
		var total := _lengths[i].x + _lengths[i].y + _lengths[i].z - 0.006
		drop = maxf(drop, _hips[i].y - _paw_height - sqrt(maxf(total * total - furthest * furthest, 0.004)))
	_drop = _approach(_drop, drop + 0.003, 9.0, delta)

	# A walking cat's back hardly rises or falls: its shoulder blades do instead.
	var sprung := 0.007 * trot * (1.0 - bound)
	var high_fore := -(load_fore - 0.5) * sprung * gait
	var high_hind := -(load_hind - 0.5) * sprung * gait
	var gathered := cos(TAU * (_phase - STRETCHED - 0.5)) * flying
	var rock := (high_hind - high_fore) / _between + sin(TAU * (_phase - STRETCHED)) * 0.09 * flying
	var bend := clampf(_turn * 0.07, -0.45, 0.45) * (1.0 - down)
	var swing_fore := (p_targets[1].z - p_targets[0].z) * 0.75 * (1.0 - bound)
	var swing_hind := (p_targets[3].z - p_targets[2].z) * 0.95 * (1.0 - bound)
	var bank := clampf(-_turn * speed * 0.014, -0.25, 0.25)

	# Stalking: right down, and lower still the moment before it springs.
	var crouched := _creep * (0.074 + 0.012 * _wiggle) + _gather * 0.062
	p_body = _body_rest + Vector3(0.0, -_drop * (1.0 - _creep * 0.6) - _crouch - crouched + (high_fore + high_hind) * 0.5 + rise, 0.0)
	p_turn = Vector3(rock + _creep * 0.03, 0.0, bank)
	# Rounded up as the hind feet come through under it, thrown out flat as they drive.
	var round_up := maxf(gathered, 0.0)
	var hollow := minf(gathered, 0.0)
	p_front = Vector3(round_up * 0.46 + hollow * 0.14, bend + swing_fore, (p_targets[0].y - p_targets[1].y) * 0.8)
	p_rear = Vector3(-round_up * 0.80 - hollow * 0.20, -bend * 0.8 + swing_hind, (p_targets[2].y - p_targets[3].y) * 1.0)
	p_neck = Vector3.ZERO
	p_head = Vector3.ZERO

	# --- Before it springs: gathered under itself to go up, or treading and wiggling to go at something. ---
	if _gather > 0.001:
		var dip := sin(PI * clampf(_act_time / 0.55, 0.0, 1.0))
		p_turn.x -= _gather * 0.34
		p_front.x += _gather * 0.1
		p_rear.x -= _gather * 0.5
		p_body.y -= _gather * dip * 0.012
		for i in 4:
			p_targets[i] = p_targets[i].lerp(_paws[i] + Vector3(0.0, 0.0, -0.035 if i < 2 else 0.06), _gather)
			if i >= 2:
				p_poles[i] = AHEAD.lerp(Vector3(signf(_hips[i].x) * 0.4, 0.3, 1.0), _gather).normalized()
	if _wiggle > 0.001:
		var beat := _act_time * TAU * 4.6
		var swell := smoothstep(0.0, 0.8, _act_time)
		p_rear.y += sin(beat) * 0.20 * _wiggle * swell
		p_rear.z += sin(beat) * 0.10 * _wiggle * swell
		p_rear.x += 0.14 * _wiggle
		p_turn.x += 0.05 * _wiggle
		for i: int in [2, 3]:
			# (its hind feet tread, to find their grip)
			var tread := maxf(sin(beat + (0.0 if i == 2 else PI)), 0.0)
			p_targets[i] = p_targets[i].lerp(_paws[i] + Vector3(signf(_paws[i].x) * 0.012, tread * 0.012, 0.05), _wiggle)
			p_lift[i] = tread * _wiggle
		for i in 2:
			p_targets[i] = p_targets[i].lerp(_paws[i] + Vector3(0.0, 0.0, 0.03), _wiggle)
	if _reach > 0.001:
		# Going down off something: forepaws down the face of it, hindquarters still on top.
		var out := smoothstep(0.0, 0.6, _act_time) * _reach
		p_turn.x += out * 0.82
		p_body += Vector3(0.0, -0.085, 0.085) * out
		p_front.x -= out * 0.1
		p_rear.x -= out * 0.55
		for i in 2:
			p_targets[i] = p_targets[i].lerp(_paws[i] + Vector3(0.0, -0.17, 0.115), out)
			p_poles[i] = BEHIND.lerp(Vector3(0.0, 0.4, -1.0), out).normalized()
		for i: int in [2, 3]:
			p_targets[i] = p_targets[i].lerp(_paws[i] + Vector3(0.0, 0.0, 0.07), out)
			p_poles[i] = AHEAD.lerp(Vector3(signf(_hips[i].x) * 0.5, 0.4, 1.0), out).normalized()

	# --- Sitting, the loaf, on its side, curled up: each laid over what came before. ---
	_lay(_sitting, sit, _w_sit)
	_lay(_loafing, loaf, _w_loaf)
	_lay(_on_side, side, _w_side)
	_lay(_curled, curl, _w_curl)
	for i in 2:
		# (its forepaws are turned in under its chest)
		p_lift[i] = maxf(p_lift[i], loaf)
	if _arch > 0.001:
		_lay(_arched, smoothstep(0.0, 1.0, _arch) * (1.0 - low), _arch)
	if absf(_bow) > 0.001:
		_stretch_out(bow)
	if _rub > 0.001:
		# Against someone's leg: leaning on it, up on its toes, its back pushed up under the hand.
		var lean := _rub * _rub_side
		p_turn.z -= lean * 0.16
		p_body += Vector3(lean * 0.022, 0.006 * _rub, 0.0)
		p_front.x += 0.10 * _rub
		p_rear.x -= 0.14 * _rub
		p_front.y += lean * 0.12
	if _fright > 0.001 and down < 0.5:
		_lay(_arched, _fright * 0.62 * (1.0 - down), _fright)

	# --- In the air it lies along the way it is going. ---
	var flight := Vector3.ZERO
	if _air > 0.001:
		var climb := atan2(velocity.y, maxf(speed, 0.6))
		p_turn.x = lerpf(p_turn.x, clampf(-climb * 0.85, -1.15, 1.0), _air)
		# Stretched out as it leaves, folding as it comes down to bring its hind feet under it.
		flight = Vector3(lerpf(-0.16, 0.34, _fall), 0.0, 0.0)
		p_front = p_front.lerp(Vector3(flight.x * 0.6, 0.0, 0.0), _air)
		p_rear = p_rear.lerp(Vector3(-flight.x * 1.5, 0.0, 0.0), _air)
		p_body.y = lerpf(p_body.y, _body_rest.y, _air)

	_sliding = (1.0 - down) * (1.0 - _air) * (1.0 - bow) * (1.0 - _reach)
	_pose_back()
	_breathe(delta, sit)
	_stare(delta, sit, low)
	_pose_head(delta, p_turn.x + p_front.x, 1.0, sit, low, flying)
	_mouth_at = global_transform.affine_inverse() * (_head.global_transform * Vector3(0.0, -0.012, 0.085))
	if _groom > 0.001:
		_wash(delta)
	_fly(delta, velocity)
	_place_legs()
	_blade_lift = _blade_lift.lerp(bearing * gait * (1.0 - bound * 0.6) * 0.013 + Vector2.ONE * (0.002 + _creep * 0.016 + bow * 0.012 + loaf * 0.01), 1.0 - exp(-16.0 * delta))
	for i in 2:
		_blades[i].position.y = _rest_of(_blades[i]).y + _blade_lift[i]
		# (and it goes back and forward a little with its leg)
		_blades[i].position.z = _rest_of(_blades[i]).z + clampf((p_targets[i].z - _paws[i].z) * 0.12, -0.012, 0.012) * gait
	var splay := 1.0 + 0.42 * maxf(_spread, bow) + 0.25 * _hunting * _air
	for toe in _toes:
		toe.scale = Vector3(splay, 1.0, 1.0)
	_carry_tail_cat(delta, trot, bound, round_up, sit, loaf, side, curl)
	_carry_ears_cat(delta, bound)
	_face(delta)
	for i in _joints.size():
		_skeleton.set_bone_pose(_bones[i], _joints[i].transform)
	_swing(delta)


## What it is doing and what it feels, eased in and out.
func _feel(delta: float, grounded: bool) -> void:
	var posture := _cat.posture if grounded else Cat.Posture.UP
	var act := _cat.act if grounded else Cat.Act.NONE
	if act != _act:
		_act = act
		_act_time = 0.0
	_act_time += delta
	_w_sit = move_toward(_w_sit, 1.0 if posture == Cat.Posture.SIT else 0.0, delta / (0.65 if posture == Cat.Posture.SIT else 0.4))
	_w_loaf = move_toward(_w_loaf, 1.0 if posture == Cat.Posture.LOAF else 0.0, delta / (0.9 if posture == Cat.Posture.LOAF else 0.5))
	_w_side = move_toward(_w_side, 1.0 if posture == Cat.Posture.SIDE else 0.0, delta / (1.3 if posture == Cat.Posture.SIDE else 0.7))
	_w_curl = move_toward(_w_curl, 1.0 if posture == Cat.Posture.CURL else 0.0, delta / (1.5 if posture == Cat.Posture.CURL else 0.8))
	var lying := maxf(_w_loaf, maxf(_w_side, _w_curl))
	_lain = _lain + delta if lying >= 1.0 else 0.0
	_doze = _approach(_doze, 1.0 if _cat.asleep and lying > 0.9 else 0.0, 1.2 if _cat.asleep else 6.0, delta)
	_creep = _approach(_creep, 1.0 if _cat.creep and grounded else 0.0, 5.0, delta)
	_wiggle = _approach(_wiggle, 1.0 if act == Cat.Act.WIGGLE else 0.0, 9.0, delta)
	_gather = _approach(_gather, 1.0 if act == Cat.Act.GATHER else 0.0, 11.0 if act == Cat.Act.GATHER else 30.0, delta)
	_reach = _approach(_reach, 1.0 if act == Cat.Act.REACH else 0.0, 9.0 if act == Cat.Act.REACH else 30.0, delta)
	_groom = _approach(_groom, 1.0 if act == Cat.Act.GROOM and _act_time < 6.5 else 0.0, 5.0, delta)
	_yawn = _keyed([0.0, 0.0, 0.5, 1.0, 1.1, 1.0, 1.7, 0.0], _act_time) if act == Cat.Act.YAWN else _approach(_yawn, 0.0, 8.0, delta)
	# The stretches go into it slowly, hold, and come out.
	var bowing := _keyed([0.0, 0.0, 0.9, 1.0, 2.2, 1.06, 3.0, 0.0], _act_time) if act == Cat.Act.STRETCH_BOW else 0.0
	_bow = _approach(_bow, bowing, 14.0, delta)
	var arching := _keyed([0.0, 0.0, 0.7, 1.0, 1.6, 1.0, 2.2, 0.0], _act_time) if act == Cat.Act.STRETCH_ARCH else 0.0
	_arch = _approach(_arch, arching, 14.0, delta)
	_rub = _approach(_rub, absf(_cat.rub), 5.0, delta)
	if absf(_cat.rub) > 0.01:
		_rub_side = signf(_cat.rub)
	_friendly = _approach(_friendly, 1.0 if _cat.mood == Cat.Mood.FRIENDLY else 0.0, 4.0, delta)
	_annoyed = _approach(_annoyed, 1.0 if _cat.mood == Cat.Mood.ANNOYED else 0.0, 3.0, delta)
	_fright = _approach(_fright, 1.0 if _cat.mood == Cat.Mood.FRIGHTENED else 0.0, 9.0 if _cat.mood == Cat.Mood.FRIGHTENED else 1.2, delta)
	_hunting = _approach(_hunting, 1.0 if _cat.mood == Cat.Mood.HUNTING or _cat.creep else 0.0, 5.0, delta)
	_alert = _hunting
	_puffed = clampf(_puffed + (Vector2(_cat.velocity.x, _cat.velocity.z).length() / _cat.run_speed * 0.2 - 0.07) * delta, 0.0, 0.45)
	# Frightened, its fur stands on end, and its tail most of all.
	var puff := snappedf(_fright, 0.05)
	if puff != _puff and not _coats.is_empty():
		_puff = puff
		for layer in _coats:
			Fur.tune(layer, {&"fur_length": lerpf(0.0048, 0.0095, puff)})
		Fur.tune(_tail_coat, {&"fur_length": lerpf(0.0052, 0.026, puff), &"droop": lerpf(0.35, 0.0, puff), &"comb": lerpf(0.9, 0.25, puff)})


## Lays a stance over whatever it is in, by `w`; each paw is picked up and put
## where it goes in its turn (`raw` is how far through the change it is).
func _lay(stance: Stance, w: float, raw: float) -> void:
	if w <= 0.0:
		return
	p_body = p_body.lerp(stance.body, w)
	p_turn = p_turn.lerp(stance.turn, w)
	p_front = p_front.lerp(stance.front, w)
	p_rear = p_rear.lerp(stance.rear, w)
	for i in 4:
		var step := smoothstep(0.0, 1.0, clampf(raw * 1.7 - (0.0 if i == 0 or i == 3 else 0.7), 0.0, 1.0)) * (w / maxf(smoothstep(0.0, 1.0, raw), 0.001))
		step = clampf(step, 0.0, 1.0)
		if stance.local:
			p_locals[i] = stance.paws[i] if p_local[i] < 0.001 else p_locals[i].lerp(stance.paws[i], step)
			p_lpoles[i] = stance.poles[i] if p_local[i] < 0.001 else p_lpoles[i].lerp(stance.poles[i], step)
			p_local[i] = lerpf(p_local[i], 1.0, step)
		else:
			p_targets[i] = p_targets[i].lerp(stance.paws[i], step) + Vector3.UP * sin(PI * step) * 0.016
			p_poles[i] = p_poles[i].lerp(stance.poles[i], step).normalized()
			p_local[i] *= 1.0 - step
		p_flat[i] = lerpf(p_flat[i], stance.flat[i], step)
		p_pitch[i] *= 1.0 - step
		p_lift[i] *= 1.0 - step


## The long stretch on waking: forepaws walked out in front, chest to the
## ground, rump in the air, the back hollowed and the toes spread.
func _stretch_out(bow: float) -> void:
	var pitch := 0.46 * _bow
	var pelvis_rest := _rest(&"loin") + _rest(&"loin_1") + _rest(&"pelvis")
	var keep := _body_rest + pelvis_rest + Vector3(0.0, 0.004, -0.018)
	p_body = p_body.lerp(keep - Basis(Vector3.RIGHT, pitch) * pelvis_rest, bow)
	p_turn.x += pitch
	p_front.x -= 0.34 * _bow
	p_rear.x += 0.20 * _bow
	p_neck.x -= 0.5 * bow
	for i in 2:
		var braced := _paws[i] + Vector3(signf(_paws[i].x) * 0.012, 0.0, 0.105 if i == 0 else 0.09)
		p_targets[i] = p_targets[i].lerp(braced, bow)
		p_pitch[i] *= 1.0 - bow
		p_poles[i] = BEHIND.lerp(Vector3(signf(_hips[i].x) * 0.25, -0.5, -1.0), bow).normalized()
		p_flat[i] = maxf(p_flat[i], smoothstep(0.7, 1.0, bow) * 0.9)


## Washing: a forepaw brought up and licked, then drawn over its face from
## behind the ear to the nose, again and again, its head turned into it.
func _wash(delta: float) -> void:
	var i := _groom_paw
	var out := 1.0 if i == 0 else -1.0
	# (lick, three wipes, lick, two wipes)
	var t := _act_time
	var wiping := (t > 1.7 and t < 3.9) or (t > 4.9 and t < 6.3)
	var stroke := fposmod((t - 1.7) / 0.72, 1.0) if wiping else 0.0
	var lick := sin(t * TAU * 3.2)
	var at := _mouth_at + Vector3(out * 0.006, -0.012 + lick * 0.006, 0.006)
	if wiping:
		var head_at := global_transform.affine_inverse() * _head.global_position
		var from := head_at + Vector3(out * 0.046, 0.034, 0.030)
		var to := _mouth_at + Vector3(out * 0.018, 0.010, 0.012)
		# (down over the face, and back up clear of it)
		var down := smoothstep(0.0, 0.62, stroke)
		var back := smoothstep(0.62, 1.0, stroke)
		at = from.lerp(to, down - back) + Vector3(out * 0.022, 0.0, 0.014) * sin(PI * back)
	p_targets[i] = p_targets[i].lerp(at, _groom)
	p_pitch[i] = lerpf(p_pitch[i], 1.3, _groom)
	p_lift[i] = _groom
	p_poles[i] = p_poles[i].lerp(Vector3(out * 0.9, -0.5, -0.6), _groom).normalized()
	# Its weight goes onto the other foreleg, which comes in under it.
	var other := 1 - i
	p_targets[other].x = lerpf(p_targets[other].x, p_targets[other].x * 0.35, _groom)
	_body.position.x -= out * 0.006 * _groom
	var into := _groom * (1.0 if wiping else 0.0)
	var bowed := 0.2 - 0.1 * into
	_neck.rotation += Vector3(bowed + lick * 0.02 * (0.0 if wiping else 1.0), out * 0.10, 0.0) * _groom
	_neck_1.rotation += Vector3(bowed, out * 0.10, 0.0) * _groom
	_head.rotation += Vector3(0.25 * _groom + lick * 0.035 * (_groom - into), out * 0.16 * _groom, -out * 0.45 * into * (0.5 + 0.5 * sin(PI * stroke)))


## Off the ground: where its legs go. Forelegs folded as it goes up and reaching
## for the ground as it comes down; hind legs left behind it, driving, then
## trailing, then brought through under it.
func _fly(_delta: float, _velocity: Vector3) -> void:
	if _air <= 0.001:
		return
	var reaching := 1.0 if _cat.pouncing else 0.0
	for i in 4:
		var fore := i < 2
		var w := _air_fore if fore else _air_hind
		var out := signf(_hips[i].x)
		var to: Vector3
		if fore:
			to = Vector3(0.0, -0.085, 0.07).lerp(Vector3(0.0, -0.165, 0.10), smoothstep(0.25, 0.85, _fall))
			# (going at something, they are out in front of it the whole way, toes spread)
			to = to.lerp(Vector3(-out * 0.008, -0.07, 0.175), reaching * (1.0 - smoothstep(0.6, 1.0, _fall)))
			p_lpoles[i] = BEHIND
		else:
			to = Vector3(0.0, -0.13, -0.215).lerp(Vector3(0.0, -0.17, 0.075), smoothstep(0.35, 0.95, _fall))
			p_lpoles[i] = AHEAD
			if _launched:
				# Its hind paws stay where they pushed off from until its legs are at their full length.
				var planted := global_transform.affine_inverse() * _launch[i - 2]
				var hip := global_transform.affine_inverse() * (_pelvis.global_transform * _hip_local[i])
				var total := _lengths[i].x + _lengths[i].y + _lengths[i].z
				var gone := smoothstep(0.9, 1.08, hip.distance_to(planted) / total)
				w = maxf(w * gone, smoothstep(0.75, 1.0, _air_hind))
				p_targets[i] = planted
		p_locals[i] = to
		p_local[i] = w
		p_pitch[i] = lerpf(p_pitch[i], 0.4 if fore else 0.9, w)
		p_lift[i] = maxf(p_lift[i], w)
		p_flat[i] *= 1.0 - w


func _pose_back() -> void:
	_body.position = p_body
	_body.rotation = p_turn
	_spine_1.rotation = p_front * 0.45
	_chest.rotation = p_front * 0.55
	_loin.rotation = p_rear * 0.35
	_loin_1.rotation = p_rear * 0.35
	_pelvis.rotation = p_rear * 0.30


## Its chest (or its hindquarters), in the space of its body.
func _girdle(fore: bool) -> Transform3D:
	if fore:
		return _spine_1.transform * _chest.transform
	return _loin.transform * _loin_1.transform * _pelvis.transform


func _place_legs() -> void:
	var to_body := _body.transform.affine_inverse()
	var chest := _girdle(true)
	var pelvis := _girdle(false)
	for i in 4:
		var fore := i < 2
		var girdle := chest if fore else pelvis
		var rest := _paws[i]
		var hip := girdle * _hip_local[i]
		var target := to_body * p_targets[i]
		var pole := to_body.basis * p_poles[i]
		var paw_basis := to_body.basis * Basis(Vector3.RIGHT, p_pitch[i])
		var w := p_local[i]
		# The shoulder blade slides over the ribs, and the hip swings, with the leg.
		var under := hip.z + rest.z - _hips[i].z
		hip.z += clampf((target.z - under) * SLIDE, -0.055, 0.055) * (1.0 - w) * _sliding
		if w > 0.0:
			var held := girdle * (_hip_local[i] + p_locals[i])
			# (nothing goes through the ground)
			var height := (_body.transform * held).y
			if height < _paw_height:
				held += to_body.basis * Vector3.UP * (_paw_height - height)
			target = target.lerp(held, w)
			pole = pole.lerp(girdle.basis * p_lpoles[i], w).normalized()
			paw_basis = Basis(paw_basis.get_rotation_quaternion().slerp((girdle.basis * Basis(Vector3.RIGHT, p_pitch[i])).get_rotation_quaternion(), w))
		_solve_leg(i, hip, target, paw_basis, pole, to_body.basis * AHEAD, p_flat[i], p_lift[i])


## Where it is looking. A cat's head goes to a thing in one quick movement and
## then does not move at all; with nothing to watch it looks at one thing after
## another, and holds each.
func _stare(delta: float, _sit: float, _low: float) -> void:
	var target := _glance
	var at := Vector3.INF
	if is_instance_valid(_cat.gaze):
		at = _cat.gaze.global_position + Vector3.UP * _eye_height(_cat.gaze)
	elif _cat.gaze_at != Vector3.INF:
		at = _cat.gaze_at
	if at != Vector3.INF:
		var to := at - _head.global_position
		target.x = clampf(angle_difference(rotation.y, atan2(to.x, to.z)), -2.3, 2.3)
		target.y = clampf(-atan2(to.y, Vector2(to.x, to.z).length()), -1.1, 0.7)
	else:
		_glance_timer -= delta
		if _glance_timer <= 0.0:
			_glance_timer = randf_range(1.4, 4.5)
			_glance = Vector2(randf_range(-1.0, 1.0) * (0.3 if _pace > 0.3 else 1.0), randf_range(-0.05, 0.2))
	_look = _look.lerp(target, 1.0 - exp(-15.0 * delta))


## Head and neck. Whatever its body does under it, its head stays where it was
## and level: walking, sitting up, and through every stride of a gallop.
func _pose_head(delta: float, upstream: float, _level: float, sit: float, low: float, flying: float) -> void:
	var awake := 1.0 - _doze
	var curl := smoothstep(0.0, 1.0, _w_curl)
	var side := smoothstep(0.0, 1.0, _w_side)
	var keep := 1.0 - maxf(curl, side * 0.6)
	_tilt = _approach(_tilt, 0.0, 5.0, delta)
	var yaw := _look.x * awake
	var pitch := _look.y * awake
	# Going anywhere it carries its head low, level with its back; lower still stalking.
	var carried := smoothstep(0.1, 0.6, _pace) * 0.22 * (1.0 - _air) + _creep * 0.34 + flying * 0.12 + _fright * 0.2 - sit * 0.16 + _wiggle * 0.05
	carried += _yawn * -0.3 + low * awake * -0.12
	# (its back swings from side to side under it as it walks, and its head does not)
	var swung := p_front.y
	var rubbing := _rub * _rub_side
	var nod := sin(_time * 5.0) * 0.5 + 0.5
	var neck := Vector3(-upstream * 0.55 * keep + pitch * 0.5 + carried, yaw * 0.5 - swung * 0.6 + rubbing * 0.3, -p_turn.z * 0.5 * keep) + p_neck
	# Curled up, its nose goes down to its hind feet; on its side, its head lies on the ground.
	neck += Vector3(curl * 0.95, _side * (side * 0.22 + curl * 0.1), 0.0)
	_chest.rotation.y += yaw * 0.08 * (1.0 - sit)
	_neck.rotation = neck * 0.5
	_neck_1.rotation = neck * 0.5
	_head.rotation = Vector3(-upstream * 0.45 * keep + pitch * 0.5 + carried * 0.3 + curl * 0.55, yaw * 0.5 - swung * 0.4 + rubbing * 0.35, -p_turn.z * 0.5 * keep - rubbing * (0.35 + 0.3 * nod)) + p_head


## Its face: the jaw, the eyes, the whiskers.
func _face(delta: float) -> void:
	_mouth = lerpf(_mouth, maxf(_voice_open() * 0.55, maxf(_yawn, smoothstep(0.3, 0.45, _puffed) * 0.12 * (1.0 - _doze))), 0.5)
	_jaw.rotation.x = _mouth * 0.85
	# Blinking: quick, now and then; and the slow one, eyes all but shut and held so.
	_blink_timer -= delta
	if _blink_timer <= 0.0:
		_blink_timer = randf_range(2.5, 7.0)
		_blink = 0.0
		_blink_length = 0.16
		if _cat.content > 0.5 and randf() < 0.6:
			_blink_length = 1.5
	_blink += delta
	var shut := sin(PI * clampf(_blink / _blink_length, 0.0, 1.0))
	shut = smoothstep(0.0, 0.7, shut) if _blink_length > 1.0 else shut
	var open := (1.0 - maxf(shut, maxf(_doze, _yawn))) * (1.0 - 0.3 * _cat.content * (1.0 - _hunting)) * (1.0 - 0.25 * _annoyed)
	_lid = lerpf(_lid, clampf(open, 0.0, 1.0), 0.5)
	_wide = _approach(_wide, maxf(_hunting, _fright), 6.0, delta)
	for i in 2:
		_eye_joints[i].scale = Vector3(1.0, lerpf(0.07, 1.0, _lid) * (1.0 + 0.1 * _wide), 1.0)
		_pupils[i].scale = Vector3(lerpf(1.0, 3.6, _wide), 1.0, 1.0)
		# Forward when it is after something, back along its cheeks when it is afraid.
		_whiskers[i].rotation.y = (1.0 if i == 0 else -1.0) * (-0.5 * _hunting + 0.45 * _fright - 0.3 * _yawn)
		_whiskers[i].rotation.z = (1.0 if i == 0 else -1.0) * 0.12 * _doze


## The tail. Where it is carried is worked out in the world (straight up is
## straight up, however the cat is sitting), and from its root each bone
## carries on from the one before, curling up or down and round to one side.
func _carry_tail_cat(delta: float, trot: float, bound: float, round_up: float, sit: float, loaf: float, side: float, curl: float) -> void:
	var down := maxf(sit, loaf)
	var lying := maxf(side, curl)
	# How high its root is carried (radians above level, behind it), how each
	# bone curls on from the last, how the last few do, and round to one side.
	var high := -0.30 + 0.08 * trot + bound * (0.12 + 0.42 * round_up) + _creep * 0.12
	var bent := 0.05 - 0.035 * bound - 0.03 * _creep
	var hook := 0.12
	var wrapped := 0.0
	var aside := 0.0
	high = lerpf(high, -0.2, _annoyed)
	high = lerpf(high, 1.42, maxf(_friendly, _rub))
	bent = lerpf(bent, 0.01, maxf(_friendly, _rub))
	hook = lerpf(hook, 0.62, maxf(_friendly, _rub))
	high = lerpf(high, 1.0 + _arch * 0.2, maxf(_fright, _arch))
	bent = lerpf(bent, -0.2, _fright)
	hook = lerpf(hook, -0.1, _fright)
	high = lerpf(high, 0.9, clampf(_bow, 0.0, 1.0))
	high = lerpf(high, 0.3, _air)
	bent = lerpf(bent, 0.06, _air)
	high = lerpf(high, 0.35, _wiggle)
	# Sitting, it is laid round its feet.
	high = lerpf(high, -0.14, down)
	bent = lerpf(bent, 0.0, down)
	hook = lerpf(hook, 0.0, down)
	aside = lerpf(aside, _wrap * 0.9, down)
	wrapped = lerpf(wrapped, _wrap * lerpf(0.40, 0.46, loaf), down)
	# Against a leg, the end of it goes round the leg.
	wrapped += _rub * _rub_side * 0.16

	# Lashing: the whole of it, from the root, when it is cross; the end of it only, when it is watching something.
	_lash += delta * TAU * lerpf(0.9, 1.7, _annoyed)
	var lash := _annoyed * 0.34
	var tip := maxf(_hunting * 0.3 * (1.0 - _wiggle * 0.5), down * _cat.content * 0.0) + _annoyed * 0.2
	_tail_twitch -= delta
	if _tail_twitch <= 0.0:
		_tail_twitch = randf_range(0.35, 1.6) if _hunting > 0.5 else randf_range(1.5, 5.0)
		if _hunting > 0.5 or (down > 0.5 and _doze < 0.5 and randf() < 0.6) or (_doze > 0.6 and randf() < 0.3):
			var flick := global_basis.x * (1.0 if randf() < 0.5 else -1.0) * randf_range(1.2, 2.6) + Vector3.UP * randf_range(0.0, 1.2)
			_tail[-1].velocity += flick
			_tail[-2].velocity += flick * 0.6
	var quiver := sin(_time * 62.0) * 0.05 * _rub

	_tail_high = _approach(_tail_high, high, 9.0, delta)
	# Each bone is aimed in the world: so far up from level, so far round from
	# straight behind, each a little further than the one before it.
	var count := _tail.size()
	var world := global_basis.orthonormalized()
	var up := _tail_high
	var held_in := _pelvis.global_basis.orthonormalized()
	var about := aside
	for i in count:
		var link := _tail[i]
		var along := float(i) / (count - 1)
		var wave := sin(_lash - i * 0.75)
		# (where the bone before it is being held, not where its spring has it: that is a frame behind)
		var parent := held_in
		# (lying on its side or curled up, it goes with its body instead, and round towards its nose)
		var laid := Basis(Vector3.RIGHT, lerpf(-0.1, -0.55, curl)) * _tail_rest[0]
		if i == 0:
			about += wave * lash
		else:
			up += bent + hook * smoothstep(0.55, 1.0, along)
			about += wrapped + wave * lash * 0.5 + sin(_lash * 1.9 - i * 0.9) * tip * smoothstep(0.5, 1.0, along) + quiver
			laid = Basis(Vector3.RIGHT, lerpf(0.06, -0.44, curl)) * _tail_rest[i - 1]
		var carried := world * Vector3(sin(about) * cos(up), sin(up), -cos(about) * cos(up))
		link.aim = (parent.inverse() * carried).lerp(laid, lying).normalized()
		held_in = parent * Basis(Quaternion(link.rest, link.aim))
		link.limit = lerpf(lerpf(0.5, 0.9, along), 0.2, bound)


## Its ears. Each turns by itself to what it hears; both come forward when it
## is after something, turn back when it is cross, and go down flat and out to
## the sides when it is afraid.
func _carry_ears_cat(delta: float, bound: float) -> void:
	var flat := maxf(maxf(_fright * 0.95, bound * 0.35), maxf(_doze * 0.25, _yawn * 0.5 + _rub * 0.3))
	_ear_flat = _approach(_ear_flat, clampf(flat, 0.0, 1.0), 12.0 if flat > _ear_flat else 4.0, delta)
	_ear_timer -= delta
	if _ear_timer <= 0.0:
		_ear_timer = randf_range(0.5, 2.4)
		var pick := randi() % 5
		_ear_turn_to = Vector2(randf_range(0.5, 1.2) if pick == 0 else 0.0, randf_range(0.5, 1.2) if pick == 1 else 0.0)
	var turn := _ear_turn_to * (1.0 - _hunting)
	if _cat.heard != Vector3.INF:
		# A sound: the ear on that side goes to it, and the other after it if it is behind.
		var to := _cat.heard - _head.global_position
		var bearing := angle_difference(_head.global_rotation.y, atan2(to.x, to.z))
		var behind := smoothstep(1.2, 2.6, absf(bearing))
		turn = Vector2(clampf(bearing, 0.0, 1.5) + behind * 0.9, clampf(-bearing, 0.0, 1.5) + behind * 0.9)
	_ear_turn = _ear_turn.lerp(turn * (1.0 - _ear_flat), 1.0 - exp(-14.0 * delta))
	for which in 2:
		var out := 1.0 if which == 0 else -1.0
		var turned: float = _ear_turn[which] + _annoyed * 1.0
		var root: Link = _ears[which][0]
		var flap: Link = _ears[which][1]
		var lean := Basis(Vector3.RIGHT, -_ear_flat * 0.5 - turned * 0.12 + _hunting * 0.12) * Basis(BEHIND, out * (_ear_flat * 1.0 + turned * 0.25 - _hunting * 0.06))
		root.aim = lean * root.rest
		root.twist = out * (turned + _ear_flat * 0.3)
		flap.aim = Basis(BEHIND, out * _ear_flat * 0.25) * flap.rest


func _rest_of(joint: Node3D) -> Vector3:
	return _skeleton.get_bone_rest(_skeleton.find_bone(joint.name)).origin


## Gives it its coat (see COATS): call again after changing `coat`.
func dress() -> void:
	var colours: Array = COATS.get(coat, COATS[&"bronze"])
	var bars := 1.0 if build == 1 else 0.0
	var values := {
		&"albedo": colours[0], &"marks": colours[1], &"pale": colours[2], &"mark_gain": colours[3], &"mark_bars": bars,
		&"mark_spacing": 0.036 if build == 1 else 0.042, &"strands": 950.0, &"run": 0.02, &"tufts": 1500.0, &"patch": 0.14, &"streak": 0.4,
	}
	for layer in _coats:
		Fur.tune(layer, values)
	if _eyes:
		_eyes.set_shader_parameter(&"albedo", colours[4])
		_eyes.set_shader_parameter(&"highlight", 0.5)
	_puff = -1.0


func _build() -> void:
	var low := low_poly or Settings.low_poly
	var model: Node = CAT_MODELS[clampi(build, 0, CAT_MODELS.size() - 1)][1 if low else 0].instantiate()
	add_child(model)
	_skeleton = model.find_children("*", "Skeleton3D", true, false)[0]
	Toon.apply(model)
	_body_rest = _rest(&"body")
	var head_at := _body_rest + _rest(&"spine_1") + _rest(&"chest") + _rest(&"neck") + _rest(&"neck_1") + _rest(&"head")
	var shells := 0 if low else fur_shells
	Fur.apply(model, &"coat", shells, 0.0048, 0.01 - head_at.z)
	Fur.apply(model, &"tail", shells, 0.0052, 0.01 - head_at.z)
	for part: MeshInstance3D in model.find_children("*", "MeshInstance3D", true, false):
		for surface in part.mesh.get_surface_count():
			var original := part.mesh.surface_get_material(surface) as StandardMaterial3D
			if original == null:
				continue
			var made := part.get_surface_override_material(surface) as ShaderMaterial
			match original.resource_name:
				"eye":
					_eyes = made
				"pupil":
					_pupil_material = made
				"coat":
					_coats.append(made)
				"tail":
					_coats.append(made)
					_tail_coat = made
	dress()

	_body = _joint(self, &"body")
	_spine_1 = _joint(_body, &"spine_1")
	_chest = _joint(_spine_1, &"chest")
	_loin = _joint(_body, &"loin")
	_loin_1 = _joint(_loin, &"loin_1")
	_pelvis = _joint(_loin_1, &"pelvis")
	_neck = _joint(_chest, &"neck")
	_neck_1 = _joint(_neck, &"neck_1")
	_head = _joint(_neck_1, &"head")
	_jaw = _joint(_head, &"jaw")
	for suffix: String in ["_l", "_r"]:
		_blades.append(_joint(_chest, "blade" + suffix))
		var eye := _joint(_head, "eye" + suffix)
		_eye_joints.append(eye)
		_pupils.append(_joint(eye, "pupil" + suffix))
		_whiskers.append(_joint(_head, "whiskers" + suffix))
	var chest_rest := _body_rest + _rest(&"spine_1") + _rest(&"chest")
	var pelvis_rest := _body_rest + _rest(&"loin") + _rest(&"loin_1") + _rest(&"pelvis")
	for i in 4:
		var fore := i < 2
		var bones: Array = []
		var at: Array[Vector3] = []
		for bone: String in ["upper", "lower", "hock", "paw"]:
			bones.append(_joint(_body, bone + SUFFIXES[i]))
			at.append(_body_rest + _rest(bone + SUFFIXES[i]))
		_toes.append(_joint(bones[3], "toes" + SUFFIXES[i]))
		_legs.append(bones)
		_hips.append(at[0])
		_paws.append(at[3])
		_hip_local.append(at[0] - (chest_rest if fore else pelvis_rest))
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
	_between = _paws[0].z - _paws[2].z

	# The tail: held where it is put, a little whippy towards the end.
	var from := _pelvis
	var names: Array[String] = ["tail", "tail_1", "tail_2", "tail_3", "tail_4", "tail_5", "tail_6", "tail_end"]
	for i in names.size() - 1:
		var link := _link(from, names[i], _rest(names[i + 1]))
		var along := i / float(names.size() - 2)
		link.stiffness = lerpf(1500.0, 420.0, along)
		link.damping = lerpf(60.0, 30.0, along)
		link.gravity = 1.5
		link.drag = 1.2
		link.limit = lerpf(0.5, 0.9, along)
		_tail.append(link)
		_tail_rest.append(link.rest)
		from = link.joint
	_pricked = true
	for which in 2:
		var suffix := "_l" if which == 0 else "_r"
		var root := _link(_head, "ear" + suffix, _rest("ear_tip" + suffix))
		var flap := _link(root.joint, "ear_tip" + suffix, _rest("ear_end" + suffix))
		for link: Link in [root, flap]:
			link.stiffness = 1300.0 if link == root else 800.0
			link.damping = 30.0 if link == root else 16.0
			link.gravity = 0.0
			link.drag = 0.5
			link.limit = 0.35
		_ears[which] = [root, flap]
	_measure_cat()


## Where its shoulders and its hips come, in the rig's space, with its body at
## `at`, turned by `turn`, and its back bent by `front` and `rear`.
func _try(at: Vector3, turn: Vector3, front: Vector3, rear: Vector3) -> Array[Vector3]:
	p_body = at
	p_turn = turn
	p_front = front
	p_rear = rear
	_pose_back()
	var shoulder := _body.transform * (_girdle(true) * Vector3(0.0, _hip_local[0].y, _hip_local[0].z))
	var hip := _body.transform * (_girdle(false) * Vector3(0.0, _hip_local[2].y, _hip_local[2].z))
	return [shoulder, hip]


## Works out, from how it is built, where it puts itself to sit, to loaf, to lie and to arch its back.
func _measure_cat() -> void:
	# Sitting: upright, its hips on the ground under it, its forelegs straight
	# and close together. Find the slope of its back that does both.
	var sit_hip := 0.054
	var front := Vector3(0.20, 0.0, 0.0)
	var rear := Vector3(-0.50, 0.0, 0.0)
	var want := _hips[0].y * 0.99 - sit_hip
	var lowest := -1.5
	var highest := 0.0
	var pitch := 0.0
	var found: Array[Vector3] = []
	for step in 24:
		pitch = (lowest + highest) * 0.5
		found = _try(Vector3.ZERO, Vector3(pitch, 0.0, 0.0), front, rear)
		if found[0].y - found[1].y < want:
			highest = pitch
		else:
			lowest = pitch
	_sitting.turn = Vector3(pitch, 0.0, 0.0)
	_sitting.front = front
	_sitting.rear = rear
	_sitting.body = Vector3(0.0, sit_hip - found[1].y, _paws[2].z + 0.035 - found[1].z)
	var shoulder := _sitting.body + found[0]
	var hip := _sitting.body + found[1]
	for i in 4:
		var out := signf(_paws[i].x)
		if i < 2:
			_sitting.paws[i] = Vector3(_paws[i].x * 0.62, _paw_height, shoulder.z + 0.012 + (0.004 if i == 0 else -0.004))
		else:
			_sitting.paws[i] = Vector3(_paws[i].x + out * 0.022, _paw_height, hip.z + 0.024 + _lengths[i].z)
			_sitting.poles[i] = Vector3(out * 0.55, 0.6, 1.0).normalized()
			_sitting.flat[i] = 1.0

	# The loaf: down on its chest, every paw folded away under it.
	_loafing.body = Vector3(0.0, _body_rest.y - 0.140, _body_rest.z - 0.01)
	_loafing.turn = Vector3(-0.04, 0.0, 0.0)
	_loafing.front = Vector3(0.10, 0.0, 0.0)
	_loafing.rear = Vector3(-0.22, 0.0, 0.0)
	found = _try(_loafing.body, _loafing.turn, _loafing.front, _loafing.rear)
	for i in 4:
		var out := signf(_paws[i].x)
		if i < 2:
			_loafing.paws[i] = Vector3(out * 0.022, _paw_height, found[0].z + 0.004)
			_loafing.poles[i] = Vector3(out * 0.5, 0.25, -1.0).normalized()
			_loafing.flat[i] = 0.0
		else:
			_loafing.paws[i] = Vector3(_paws[i].x + out * 0.016, _paw_height, found[1].z + 0.070)
			_loafing.poles[i] = Vector3(out * 0.7, 0.45, 1.0).normalized()
			_loafing.flat[i] = 1.0

	# Flat on its side, legs out; and curled up, its back bent right round and its legs folded in.
	for stance: Stance in [_on_side, _curled]:
		var curled := stance == _curled
		stance.local = true
		stance.body = Vector3(0.0, 0.056 if curled else 0.05, _body_rest.z)
		stance.turn = Vector3(0.0, 0.0, -_side * (1.22 if curled else 1.46))
		stance.front = Vector3(0.80 if curled else 0.08, 0.0, 0.0)
		stance.rear = Vector3(-1.05 if curled else -0.16, 0.0, 0.0)
		for i in 4:
			var under := signf(_hips[i].x) == _side
			if curled:
				stance.paws[i] = Vector3(0.0, -0.085, 0.055) if i < 2 else Vector3(0.0, -0.10, 0.085)
			elif i < 2:
				stance.paws[i] = Vector3(0.0, -0.165, 0.075) if under else Vector3(0.0, -0.150, 0.025)
			else:
				stance.paws[i] = Vector3(0.0, -0.215, -0.045) if under else Vector3(0.0, -0.200, 0.04)
			stance.poles[i] = BEHIND if i < 2 else AHEAD

	# Its back arched right up: on its toes, feet together under it, as high as it will go.
	front = Vector3(0.66, 0.0, 0.0)
	rear = Vector3(-0.78, 0.0, 0.0)
	var at := _body_rest
	pitch = 0.0
	for step in 8:
		found = _try(at, Vector3(pitch, 0.0, 0.0), front, rear)
		at.y += _hips[0].y + 0.004 - found[0].y
		pitch -= clampf((found[1].y - found[0].y - (_hips[2].y - _hips[0].y) - 0.004) / _between, -0.2, 0.2)
	_arched.body = at
	_arched.turn = Vector3(pitch, 0.0, 0.0)
	_arched.front = front
	_arched.rear = rear
	for i in 4:
		_arched.paws[i] = _paws[i] + Vector3(-signf(_paws[i].x) * 0.006, 0.0, -0.045 if i < 2 else 0.06)
