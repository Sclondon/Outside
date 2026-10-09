class_name CrocodileRig
extends HoundRig
## Drives the crocodile model (models/crocodile*.glb) in code.
##
## It is built on the hound's rig, as the cat's and the camel's are, and uses
## from it unchanged the three-bone leg solver (`_solve_leg`), the path of a
## foot through a stride (`_foot_cycle`), the reading of joints from the
## skeleton (`_joint`, `_rest`) and the curve and easing helpers. Everything
## that makes it a crocodile is here, and replaces the hound's `_ready`,
## `_process` and `_build` outright:
##
## - Sprawled legs. A hound's legs fold fore and aft under it; a crocodile's
##   stick out sideways, the elbows out and back and the knees out and forward,
##   and its hands and feet lie flat on the ground. The same solver does it,
##   told to fold each leg towards a point out to the side (`POLES`) and to lay
##   the last bone along the ground.
## - Three ways of going on land, which run into one another. The BELLY CRAWL:
##   flat on the ground, its legs right out beside it, one foot moved at a
##   time, its body and tail bending from side to side as it goes. The HIGH
##   WALK: its body lifted clear on legs half under it, going in diagonal
##   pairs, nearly a trot. And the BELLY RUN, the short fast scuttle that takes
##   it back to the water or up the bank after something: low, legs going like
##   paddles. The Crocodile says how high it means to carry itself (`lift`);
##   how fast it is going does the rest.
## - Swimming: legs folded back along its sides, and a wave running down its
##   body that grows as it goes, so that the tail does the work. Floating
##   still it hangs at a slant, its tail down and its nose up, which is what
##   leaves only its eyes and its nostrils out of the water.
## - A tail in eight pieces. On land it is laid on the ground behind it,
##   wherever its hips happen to be, and dragged; it swings against the hips at
##   every step and is left behind in a turn. None of it is on springs: each
##   piece is put where it goes.
## - A jaw that opens very wide: the head goes up as the jaw goes down, since
##   as often as not its chin is on the ground. Held open to bask; thrown open
##   for a lunge and snapped shut.
## - After it has hold of something: the head shaken from side to side, and in
##   the water the roll, twice right over.
## - Eyelids that blink, and shut when it dozes; a head that turns to what it
##   is watching, as far as so short a neck will let it.
##
## The Crocodile (scripts/crocodile.gd) says which of these (`lift`, `afloat`,
## `submerged`, `jaws`, `lunging`, `gaze`); how each is done is all here. It
## also stands the whole rig on the slope of the bank: here the ground is flat.
##
## What it follows:
## - en.wikipedia.org/wiki/Nile_crocodile: it "normally crawls on its belly,
##   but can high walk with its body raised off the ground"; it swims "by
##   moving its body and tail in a sinuous motion"; more than half of those
##   watched basked with their jaws open.
## - That the high walk is the trunk "suspended between symmetrically moving
##   limbs", a lateral-sequence walk close to a walking trot, and that the
##   sprawl is the same walk done lower: Reilly and Elias 1998 (J. Exp. Biol.
##   201:2559, alligators on a treadmill), as web searches quote it; the paper
##   itself was not read. Nile crocodiles were measured walking at 0.1 to
##   0.7 m/s, low and high, the share of the stride a foot is down falling
##   with speed (sicb.org/?p=10720, an abstract).
## - Everything else is by eye, from film of them: how far each foot reaches,
##   how much the back bends, the slant it floats at, how the tail lies. None
##   of the numbers below is a measurement.

const CROCODILE_MODELS: Array = [preload("res://models/crocodile.glb"), preload("res://models/crocodile_lo.glb")]

## Where in the stride each foot lands (fore left, fore right, hind left, hind right).
## Crawling: one at a time, left hind, left fore, right hind, right fore.
const CRAWL: Array[float] = [0.25, 0.75, 0.0, 0.5]
## The high walk: each fore foot nearly with the hind foot opposite.
const HIGH_WALK: Array[float] = [0.40, 0.90, 0.0, 0.5]
## The belly run: diagonal pairs together.
const SCUTTLE: Array[float] = [0.5, 1.0, 0.0, 0.5]
## The share of the stride a foot is down: crawling, walking high, and running.
const ON_GROUND := Vector3(0.76, 0.68, 0.46)
## Speeds (m/s) over which either walk gives way to the belly run.
const SCUTTLE_AT := Vector2(1.0, 2.0)
## Length of a stride (m) against speed (m/s).
const STRIDES := [0.0, 0.32, 0.3, 0.44, 0.6, 0.56, 1.2, 0.66, 2.6, 0.80, 6.0, 1.05]
## How far a shoulder or a hip goes with its leg.
const GIRDLE_GLIDE := 0.3
## Which way each leg folds, in the body's own space: elbows out, up and back, knees out, up and forward.
const POLES: Array[Vector3] = [Vector3(0.8, 0.45, -0.75), Vector3(-0.8, 0.45, -0.75), Vector3(0.8, 0.45, 0.75), Vector3(-0.8, 0.45, 0.75)]
## How far it comes down to lie on its belly (m), and how much further out its feet are then.
const BELLY := 0.106
const SPRAWL := 0.07
## How far the jaw opens, wide (radians), and how much of that is the head going up.
const CROCODILE_GAPE := 0.95
const HEAD_SHARE := 0.5
## The slant it floats at, still (radians, nose up).
const FLOAT_SLANT := 0.2
## How far an eyelid turns to shut (radians).
const LID_DOWN := 1.15
## The roll: how many times over, and how long it takes (s).
const ROLLS := 2.0
const ROLL_TIME := 1.5

var _croc: Crocodile
var _lids: Array[Node3D] = []
var _tails: Array[Node3D] = []
## What each piece of the tail reaches to (in its own space), and how deep the tail is at its far end.
var _tail_reach: Array[Vector3] = []
var _tail_deep: Array[float] = []
## How far each piece of the tail is left behind in a turn.
var _tail_lag: Array[float] = []

## Eased: how high it is carrying itself, how far it is afloat, and under.
var _lift := 0.0
var _afloat := 0.0
var _sunk := 0.0
var _swim_phase := 0.0
var _lunge := 0.0
## Lying still: how far its hind legs have slid out behind it.
var _laze := 0.0
## How long since it took hold of something (s), and whether it was in the water at the time.
var _thrash := 9.0
var _rolled := false
var _lid := 0.0
var _blink := 9.0
var _blink_timer := 3.0


func _ready() -> void:
	_build()
	_croc = get_parent() as Crocodile
	if _croc:
		_croc.caught.connect(thrash)
		_lift = _croc.lift
		_afloat = _croc.afloat
		_last_yaw = _croc.facing_yaw
	_time = randf() * 10.0
	_phase = randf()


## It has hold of something: it shakes it, and in the water it rolls.
func thrash() -> void:
	if _thrash < ROLL_TIME:
		return
	_thrash = 0.0
	_rolled = _afloat > 0.6


## The tip of its snout, in the world.
func snout() -> Vector3:
	return _head.global_transform * Vector3(0.0, 0.0, 0.47)


## Its eyes, in the world.
func eyes() -> Vector3:
	return _head.global_transform * Vector3(0.0, 0.09, 0.145)


func _process(delta: float) -> void:
	if _croc == null:
		return
	delta = minf(delta, 1.0 / 30.0)
	_time += delta
	var velocity := _croc.velocity
	var speed := Vector2(velocity.x, velocity.z).length() / _size
	_turn = _approach(_turn, angle_difference(_last_yaw, _croc.facing_yaw) / delta, 6.0, delta)
	_last_yaw = _croc.facing_yaw
	_afloat = _approach(_afloat, _croc.afloat, 5.0, delta)
	_lift = _approach(_lift, _croc.lift, 2.2, delta)
	_sunk = _approach(_sunk, 1.0 if _croc.submerged else 0.0, 2.5, delta)
	_lunge = _approach(_lunge, 1.0 if _croc.lunging else 0.0, 14.0 if _croc.lunging else 5.0, delta)
	_alert = _approach(_alert, 1.0 if is_instance_valid(_croc.gaze) else 0.0, 2.0, delta)
	_doze = _approach(_doze, 1.0 if _croc.dozing else 0.0, 0.6 if _croc.dozing else 5.0, delta)
	_thrash += delta
	var land := 1.0 - _afloat

	# --- The gait. Turning on the spot it steps round, without going anywhere. ---
	_pace = _approach(_pace, maxf(speed, absf(_turn) * 0.3 * land), 8.0, delta)
	var scuttle := smoothstep(SCUTTLE_AT.x, SCUTTLE_AT.y, _pace)
	var gait := smoothstep(0.03, 0.22, _pace) * land
	# How far up off its belly it is: right up for the high walk, a little for the run, and for the lunge.
	var raised := maxf(lerpf(_lift, 0.3, scuttle), 0.45 * _lunge) * land
	var high := raised * (1.0 - scuttle)
	var duty := lerpf(lerpf(ON_GROUND.x, ON_GROUND.y, high), ON_GROUND.z, scuttle)
	var body_y := _body_rest.y - BELLY * _size * (1.0 - raised) * land
	var sprawl := 1.0 - raised
	# No stride is longer than lets a foot stay where it is put: a leg that is out sideways reaches less far.
	var reach := 9.0
	for i in 4:
		var arm := _lengths[i].x + _lengths[i].y - 0.01
		var up := _hips[i].y - _body_rest.y + body_y - 0.05 * _size
		var out := absf(_paws[i].x - _hips[i].x) + SPRAWL * _size * sprawl
		reach = minf(reach, 2.0 * sqrt(maxf(arm * arm - up * up - out * out, 0.003)) * 0.8 / (1.0 - GIRDLE_GLIDE))
	var stride := minf(_keyed(STRIDES, _pace) * _size, reach / duty)
	_phase = fposmod(_phase + _pace * _size / stride * delta, 1.0)
	var travel := clampf(speed / maxf(_pace, 0.05), 0.0, 1.0)
	var step_height := lerpf(lerpf(0.028, 0.055, high), 0.07, scuttle) * _size
	# Lying still for a while, its hind legs slide out behind it.
	_laze = _approach(_laze, 1.0 if _pace < 0.05 and _croc.lift < 0.1 and land > 0.9 and not _croc.lunging else 0.0, 0.5 if _pace < 0.05 else 6.0, delta)
	var targets: Array[Vector3] = []
	var pitches: Array[float] = []
	var flats: Array[float] = []
	var lifts: Array[float] = []
	for i in 4:
		var fore := i < 2
		var side := signf(_paws[i].x)
		var at := fposmod(_phase - lerpf(lerpf(CRAWL[i], HIGH_WALK[i], high), SCUTTLE[i], scuttle), 1.0)
		var cycle := _foot_cycle(at, duty, duty * stride * travel * 0.5, step_height)
		var rest := _paws[i] + Vector3(side * SPRAWL * _size * sprawl, 0.0, 0.0)
		if fore:
			# (thrown forward to take it as it comes down from a lunge)
			rest.z += 0.08 * _size * _lunge
		else:
			rest += Vector3(side * 0.03, 0.0, -0.20) * _size * _laze
		targets.append(Vector3(rest.x, _paw_height + cycle.y * gait, rest.z + cycle.z * gait))
		# (how far through being carried it is: none at either end)
		var up := sin(PI * (at - duty) / (1.0 - duty)) * gait if at > duty else 0.0
		# (a hand is peeled off the ground from the wrist as it leaves it, and hangs while it is carried)
		pitches.append(cycle.x * gait * 0.7)
		flats.append(1.0 - 0.45 * up)
		lifts.append(up)

	# The back bends with the legs: each girdle swings towards whichever of its feet is forward, the
	# shoulders one way and the hips the other, and far more crawling than walking high.
	var supple := lerpf(0.85, 0.5, raised) / _size
	var swing_fore := (targets[1].z - targets[0].z) * supple
	var swing_hind := (targets[3].z - targets[2].z) * supple * 1.1
	var bend := clampf(_turn * 0.09, -0.3, 0.3)
	# Each end of it rides up a little over the foot that is under it, and it rolls towards the feet that are down.
	var bob := sin(2.0 * TAU * _phase) * 0.006 * _size * gait
	var body_at := Vector3(0.0, body_y + bob, _body_rest.z)
	var body_turn := Vector3(0.0, 0.0, (targets[0].y - targets[1].y + targets[2].y - targets[3].y) * 0.25 / _size)
	var chest_turn := Vector3(0.0, swing_fore + bend, 0.0)
	var pelvis_turn := Vector3(0.0, swing_hind - bend, 0.0)

	# --- Afloat. A wave runs down it, growing as it goes; still, it hangs at a slant. ---
	var effort := clampf(speed / 3.5, 0.0, 1.0)
	_swim_phase = fposmod(_swim_phase + delta * TAU * lerpf(0.35, 2.3, effort), TAU)
	var stroke := _afloat * smoothstep(0.0, 0.25, effort + 0.04)
	var still := _afloat * (1.0 - smoothstep(0.15, 1.0, speed))
	body_turn.x -= (FLOAT_SLANT * still * (1.0 - _sunk) + 0.05 * _afloat * (1.0 - still))
	# (coming up the bank out of the water after something, its chest is thrown up)
	chest_turn.x -= 0.2 * _lunge
	chest_turn.y += sin(_swim_phase + 1.6) * 0.035 * stroke
	pelvis_turn.y += sin(_swim_phase + 0.8) * lerpf(0.05, 0.11, effort) * stroke
	body_at.x += sin(_swim_phase + 2.4) * 0.02 * _size * stroke

	# It has hold of something: in the water, right over and over again.
	var held := 1.0 - smoothstep(0.7, 1.3, _thrash)
	if _rolled and _thrash < ROLL_TIME:
		body_turn.z += TAU * ROLLS * smoothstep(0.0, 1.0, _thrash / ROLL_TIME)

	_body.position = body_at
	_body.rotation = body_turn
	_chest.rotation = chest_turn
	_pelvis.rotation = pelvis_turn
	_breath += delta * TAU * lerpf(0.2, 0.12, _doze)
	var swell := sin(_breath) * 0.012
	_chest.scale = Vector3(1.0 + swell, 1.0 + swell, 1.0)
	_neck.scale = Vector3.ONE / _chest.scale
	_watch_out(delta)
	_pose_head_and_jaw(delta, chest_turn, raised, gait, land, held)
	_place_legs(targets, pitches, flats, lifts)
	_lay_tail(delta, swing_hind, gait, stroke, effort, land, held)
	for i in _joints.size():
		_skeleton.set_bone_pose(_bones[i], _joints[i].transform)


## Where it is looking: at what the Crocodile says, or else nowhere much.
func _watch_out(delta: float) -> void:
	var target := Vector2.ZERO
	if is_instance_valid(_croc.gaze):
		var to := _croc.gaze.global_position + Vector3.UP * (0.9 if _croc.gaze is Player else 0.2) - _head.global_position
		target.x = clampf(angle_difference(_croc.facing_yaw, atan2(to.x, to.z)), -1.0, 1.0)
		target.y = clampf(-atan2(to.y, Vector2(to.x, to.z).length()), -0.35, 0.2)
	# (it turns its head as it does most things: slowly, until it does not)
	_look = _look.lerp(target * (1.0 - _doze), 1.0 - exp(-(9.0 if _croc.lunging else 2.4) * delta))
	_blink_timer -= delta
	if _blink_timer <= 0.0:
		_blink_timer = randf_range(3.0, 9.0)
		_blink = 0.0
	_blink += delta


## The neck, the head and the jaw. Its shoulders swing as it walks and its head does not: the neck
## takes that out. Lying, its chin is on the ground, unless it is watching something. To open its
## mouth the head goes up as much as the jaw goes down.
func _pose_head_and_jaw(delta: float, chest_turn: Vector3, raised: float, gait: float, land: float, held: float) -> void:
	# (opened slowly to bask, thrown open to lunge; and always shut fast)
	var rate := _croc.jaw_rate if _croc.jaws > _mouth else 34.0
	_mouth = _approach(_mouth, _croc.jaws, rate, delta)
	var open := _mouth * CROCODILE_GAPE
	var lying := (1.0 - raised) * land
	var chin := 0.27 * lying * (1.0 - 0.6 * _alert) * (1.0 - 0.5 * gait)
	# (with its chin on the ground it is all but all the head that goes up)
	var share := lerpf(HEAD_SHARE, 0.94, chin / 0.27)
	var shake := sin(_thrash * 21.0) * 0.4 * held
	var yaw := _look.x + shake
	_neck.rotation = Vector3(chin - 0.14 * _lunge + _look.y * 0.4 - chest_turn.x * 0.5, yaw * 0.45 - chest_turn.y * 0.55, 0.0)
	_head.rotation = Vector3(-open * share - chin * 0.15 + _look.y * 0.6 - chest_turn.x * 0.5, yaw * 0.55 - chest_turn.y * 0.35, shake * 0.3)
	_jaw.rotation.x = open
	var blink := sin(PI * clampf(_blink / 0.25, 0.0, 1.0))
	_lid = lerpf(_lid, maxf(blink, _doze), 0.5)
	for i in 2:
		_lids[i].rotation.z = (-1.0 if i == 0 else 1.0) * _lid * LID_DOWN


## The legs: on land, each to where its foot is on the ground; afloat, folded back along its sides.
func _place_legs(targets: Array[Vector3], pitches: Array[float], flats: Array[float], lifts: Array[float]) -> void:
	var to_body := _body.transform.affine_inverse()
	var turned := to_body.basis.orthonormalized()
	for i in 4:
		var fore := i < 2
		var side := signf(_hips[i].x)
		var spine := _chest if fore else _pelvis
		var hip := spine.transform * (_hips[i] - _body_rest - spine.position)
		var tucked := hip + (Vector3(side * 0.05, -0.045, -0.42) if fore else Vector3(side * 0.05, -0.02, -0.57)) * _size
		var paw := (to_body * targets[i]).lerp(tucked, _afloat)
		# The shoulder slides over the ribs, and the hip swings, with the leg.
		var under := hip.z + _paws[i].z - _hips[i].z
		hip.z += clampf((paw.z - under) * GIRDLE_GLIDE, -0.07, 0.07) * _size * (1.0 - _afloat)
		# A hand lies on the ground pointing forward and a little out; folded away, it trails back.
		var toes := turned.slerp(Basis.IDENTITY, _afloat) * Basis(Vector3.UP, side * 2.75 * _afloat) * Basis(Vector3.RIGHT, pitches[i] * (1.0 - _afloat))
		var along := (turned * Vector3(side * 0.25, 0.0, 1.0).normalized()).slerp(Vector3(side * 0.22, -0.1, -1.0).normalized(), _afloat)
		# (the wrist is never asked to be further off than the arm is long: the solver would turn the hand to
		# make up the difference, a step at a time)
		var wrist := paw - along * _lengths[i].z
		var most := (_lengths[i].x + _lengths[i].y) * 0.975
		if wrist.distance_to(hip) > most:
			paw = hip + (wrist - hip).normalized() * most + along * _lengths[i].z
		_solve_leg(i, hip, paw, toes, turned.slerp(Basis.IDENTITY, _afloat) * POLES[i], along, lerpf(flats[i], 1.0, _afloat), lifts[i] * 0.3 * (1.0 - _afloat))


## The tail. On land it lies on the ground behind it and is dragged: each piece is turned down, or
## up, to bring its far end to the ground. It swings against the hips at each step. Afloat, the wave
## that runs down the body runs on down it and grows. And whatever it is doing, a turn leaves it behind.
func _lay_tail(delta: float, swing_hind: float, gait: float, stroke: float, effort: float, land: float, held: float) -> void:
	var root := _body.transform * (_pelvis.transform * _tails[0].position)
	var height := root.y
	# (how each piece lies, turned up from level, counted from the level of the ground)
	var above := _body.rotation.x + _pelvis.rotation.x
	var count := _tails.size()
	for i in count:
		var reach := _tail_reach[i]
		var long := absf(reach.z)
		# (it cannot be bent sharply: what one piece cannot do the next takes up)
		var want := asin(clampf((_tail_deep[i] * _size - height - reach.y) / long, -0.7, 0.7))
		var turn := clampf(want - above, -0.42, 0.42)
		# Afloat it trails behind it, and hangs a little when it is still.
		turn = lerpf(turn, -0.035 * (1.0 - effort), _afloat)
		var along := float(i) / (count - 1)
		_tail_lag[i] = _approach(_tail_lag[i], clampf(-_turn * (0.035 + 0.05 * along), -0.3, 0.3), lerpf(7.0, 2.5, along), delta)
		var wave := sin(TAU * (_phase - 0.11 * i) + 0.5) * lerpf(0.05, 0.11, along) * gait
		if i == 0:
			wave -= swing_hind * 0.6
		wave += sin(_swim_phase - 0.72 * i) * lerpf(0.10, 0.27, along) * lerpf(0.5, 1.0, effort) * stroke
		wave += sin(_thrash * 21.0 + 2.0 + i) * 0.16 * held
		_tails[i].rotation = Vector3(turn, _tail_lag[i] + wave, 0.0)
		above += turn
		height += reach.y * cos(above) + long * sin(above)


func _build() -> void:
	var low := low_poly or Settings.low_poly
	var model: Node = CROCODILE_MODELS[1 if low else 0].instantiate()
	add_child(model)
	_skeleton = model.find_children("*", "Skeleton3D", true, false)[0]
	Toon.apply(model)
	_body_rest = _rest(&"body")
	_body = _joint(self, &"body")
	_chest = _joint(_body, &"chest")
	_pelvis = _joint(_body, &"pelvis")
	_neck = _joint(_chest, &"neck")
	_head = _joint(_neck, &"head")
	_jaw = _joint(_head, &"jaw")
	for suffix: String in ["_l", "_r"]:
		_lids.append(_joint(_head, "lid" + suffix))
	for i in 4:
		var bones: Array = []
		var at: Array[Vector3] = []
		for bone: String in ["upper", "lower", "hock", "paw"]:
			bones.append(_joint(_body, bone + SUFFIXES[i]))
			at.append(_body_rest + _rest(bone + SUFFIXES[i]))
		_legs.append(bones)
		_hips.append(at[0])
		_paws.append(at[3])
		_lengths.append(Vector3(at[0].distance_to(at[1]), at[1].distance_to(at[2]), at[2].distance_to(at[3])))
		# How it stands, measured the way `_solve_leg` builds a leg: but folding out to the side.
		var line := (at[3] - at[0]).normalized()
		var aside := (POLES[i] - line * POLES[i].dot(line)).normalized()
		var normal := aside.cross(line).normalized()
		var last := (at[3] - at[2]).normalized()
		_spans.append(at[0].distance_to(at[3]))
		_bends.append(atan2(last.dot(aside), last.dot(line)))
		_frames.append([
			_frame(normal, (at[1] - at[0]).normalized()).inverse(), _frame(normal, (at[2] - at[1]).normalized()).inverse(),
			_frame(normal, last).inverse(),
		])
	_paw_height = _paws[0].y
	_size = 1.0

	# The tail, piece by piece, and how deep it is at the far end of each (it is a blade: deep, and thin).
	var from := _pelvis
	var names: Array[String] = ["tail", "tail_1", "tail_2", "tail_3", "tail_4", "tail_5", "tail_6", "tail_7", "tail_end"]
	var deep: Array[float] = [0.130, 0.118, 0.110, 0.098, 0.084, 0.066, 0.046, 0.026]
	for i in 8:
		from = _joint(from, names[i])
		_tails.append(from)
		_tail_reach.append(_rest(names[i + 1]))
		_tail_deep.append(deep[i])
		_tail_lag.append(0.0)
