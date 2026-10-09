class_name BrotherRig
extends CharacterRig
## The brother's own moves, laid over what CharacterRig makes of him: a guard,
## a left hook, a right hook, an uppercut and a kick; and bracing, bent over
## with his hands on his knees and his back flat, to be climbed on, with the
## heave that throws whoever is on it upwards.
##
## Like the rest of the rig, nothing is a clip. Each move is drawn by hand as a
## few whole poses at moments through it (see the keys below); between them
## every part follows a smooth curve (CharacterRig._keyed). A pose is a set of
## named parts, each a number or a Vector3, in the rig's own space and the
## model's own units (he faces +Z, his left is +X):
##   hips   where his hips are: across, up from where they are when he stands, forward
##   turn   which way his chest is turned, his left positive (his hips less so)
##   lean   forward lean shared along his back; bow: bent forward at the hips alone
##   tilt   leant to his right (positive) or left
##   chin   head tipped down (positive), when he has nothing to watch
##   lh rh  where his left and right fists are; le re: how far that elbow is
##          raised, 0 hanging to 1 level with the shoulder
##   arms   how far his arms are put there at all; knees: his hands on his knees instead
##   curl   how closed his hands are (1.4 a fist)
##   lf rf  each foot: across, how high off the ground, forward; lfy rfy: turned
##          out (left positive); lfp rfp: heel raised (toes up if negative);
##          lk rk: which way the knee points, round from straight ahead
##
## Brother (scripts/brother.gd) says which move he is in and how far through it.

const BLOWS: Array[StringName] = [&"left_hook", &"right_hook", &"uppercut", &"kick"]
## How long each blow takes, seconds; how far through it lands (when Brother
## looks for what it hit); and how far through the next may start, cutting its
## recovery short.
const TAKES: Array[float] = [0.56, 0.56, 0.68, 0.9]
const CONTACT: Array[float] = [0.45, 0.45, 0.46, 0.44]
const CHAIN: Array[float] = [0.7, 0.7, 0.76, 0.94]
## How long the heave takes, from the moment the boy jumps.
const HEAVE_TAKES := 1.15

## A brawler's guard, not a boxer's: square on, hands low and wide, chin down.
const GUARD := {
	"hips": Vector3(0.0, -0.07, 0.0), "turn": -0.4, "lean": 0.2, "bow": 0.0, "tilt": 0.0, "chin": 0.1,
	"lh": Vector3(0.1, 0.94, 0.26), "rh": Vector3(-0.12, 0.92, 0.15), "le": 0.2, "re": 0.25, "arms": 1.0, "knees": 0.0, "curl": 1.4,
	"lf": Vector3(0.11, 0.0, 0.14), "lfy": 0.1, "lfp": 0.0, "lk": 0.15,
	"rf": Vector3(-0.14, 0.0, -0.15), "rfy": -0.6, "rfp": 0.3, "rk": -0.5,
}
## Braced: feet wide, knees bent, bent right over at the hips with his back flat
## and his hands on his knees.
const BRACE := {
	"hips": Vector3(0.0, -0.04, -0.16), "turn": 0.0, "lean": 0.12, "bow": 1.5, "tilt": 0.0, "chin": -0.8,
	"lh": Vector3(0.2, 0.3, 0.1), "rh": Vector3(-0.2, 0.3, 0.1), "le": 0.55, "re": 0.55, "arms": 1.0, "knees": 1.0, "curl": 0.8,
	"lf": Vector3(0.18, 0.0, 0.0), "lfy": 0.3, "lfp": 0.0, "lk": 0.3,
	"rf": Vector3(-0.18, 0.0, 0.0), "rfy": -0.3, "rfp": 0.0, "rk": -0.3,
}

## A left hook, thrown wide. He winds up over his front foot, the fist drawn
## back and out; swings it round level, hips first, pivoting on the ball of
## that foot; it lands in front of him and goes on across, taking him with it;
## and he gathers himself.
const LEFT_HOOK := [
	[0.0, {}],
	[0.3, {"hips": Vector3(0.05, -0.15, -0.06), "turn": 0.35, "lean": 0.27, "tilt": -0.08, "lh": Vector3(0.31, 0.76, -0.14), "le": 0.5, "rh": Vector3(-0.07, 0.97, 0.2), "re": 0.0,
		"lf": Vector3(0.11, 0.05, 0.17), "lfy": 0.25}],
	[0.4, {"hips": Vector3(0.02, -0.11, 0.05), "turn": -0.2, "lean": 0.26, "lh": Vector3(0.36, 0.93, 0.17), "le": 1.0, "rh": Vector3(-0.1, 0.97, 0.14), "re": 0.0,
		"lf": Vector3(0.1, 0.0, 0.23), "lfy": 0.0, "rfp": 0.5}],
	[0.45, {"hips": Vector3(-0.02, -0.1, 0.12), "turn": -0.7, "lean": 0.28, "tilt": 0.05, "lh": Vector3(0.0, 0.98, 0.43), "le": 1.0, "rh": Vector3(-0.12, 0.98, 0.1),
		"lf": Vector3(0.1, 0.0, 0.23), "lfy": -0.4, "lfp": 0.3, "lk": -0.3, "rf": Vector3(-0.14, 0.0, -0.12), "rfp": 0.7}],
	[0.56, {"hips": Vector3(-0.05, -0.16, 0.14), "turn": -1.1, "lean": 0.4, "tilt": 0.1, "lh": Vector3(-0.27, 0.9, 0.2), "le": 0.9, "rh": Vector3(-0.16, 0.95, 0.02),
		"lf": Vector3(0.1, 0.0, 0.23), "lfy": -0.55, "lfp": 0.4, "lk": -0.4, "rf": Vector3(-0.14, 0.0, -0.1), "rfp": 0.8}],
	[0.74, {"hips": Vector3(-0.03, -0.12, 0.08), "turn": -0.9, "lean": 0.3, "lh": Vector3(-0.08, 0.94, 0.24), "le": 0.5, "rh": Vector3(-0.16, 0.92, 0.06),
		"lf": Vector3(0.1, 0.0, 0.23), "lfy": -0.3, "lfp": 0.15, "rf": Vector3(-0.14, 0.0, -0.11), "rfp": 0.6}],
	[0.88, {"hips": Vector3(-0.01, -0.09, 0.03), "turn": -0.6, "lf": Vector3(0.11, 0.035, 0.18), "lfy": -0.05}],
	[1.0, {}],
]
## The right, from further back and with more of him behind it: his weight
## goes from his back foot to his front, and the back heel comes round after it.
const RIGHT_HOOK := [
	[0.0, {}],
	[0.28, {"hips": Vector3(-0.06, -0.16, -0.07), "turn": -1.0, "lean": 0.28, "tilt": 0.08, "rh": Vector3(-0.32, 0.75, -0.2), "re": 0.5, "lh": Vector3(0.06, 0.97, 0.22), "le": 0.0, "rfp": 0.05, "rk": -0.7}],
	[0.39, {"hips": Vector3(-0.01, -0.11, 0.05), "turn": -0.2, "lean": 0.26, "rh": Vector3(-0.37, 0.93, 0.15), "re": 1.0, "lh": Vector3(0.1, 0.97, 0.15), "le": 0.0, "rfp": 0.55, "rfy": -0.3, "rk": -0.2}],
	[0.45, {"hips": Vector3(0.03, -0.1, 0.13), "turn": 0.65, "lean": 0.29, "tilt": -0.05, "rh": Vector3(0.0, 0.98, 0.45), "re": 1.0, "lh": Vector3(0.13, 0.98, 0.08),
		"rf": Vector3(-0.13, 0.0, -0.1), "rfp": 0.8, "rfy": 0.05, "rk": 0.1, "lfy": 0.3}],
	[0.56, {"hips": Vector3(0.06, -0.16, 0.16), "turn": 1.1, "lean": 0.42, "tilt": -0.1, "rh": Vector3(0.29, 0.9, 0.22), "re": 0.9, "lh": Vector3(0.17, 0.95, 0.0),
		"rf": Vector3(-0.13, 0.0, -0.04), "rfp": 0.9, "rfy": 0.25, "rk": 0.3, "lfy": 0.35}],
	[0.74, {"hips": Vector3(0.04, -0.12, 0.09), "turn": 0.85, "lean": 0.3, "rh": Vector3(0.1, 0.93, 0.25), "re": 0.5, "lh": Vector3(0.16, 0.92, 0.05),
		"rf": Vector3(-0.13, 0.0, -0.06), "rfp": 0.6, "rfy": 0.1, "rk": 0.1}],
	[0.88, {"hips": Vector3(0.01, -0.09, 0.03), "turn": 0.2, "rf": Vector3(-0.14, 0.03, -0.11), "rfy": -0.3, "rfp": 0.4}],
	[1.0, {}],
]
## An uppercut with the left. He drops under it, that shoulder down and the fist
## by his hip; and drives up off both legs, the fist up through where a chin
## would be and on past his own head, until he is up on his toes.
const UPPERCUT := [
	[0.0, {}],
	[0.32, {"hips": Vector3(0.05, -0.23, -0.02), "turn": 0.5, "lean": 0.42, "tilt": -0.2, "chin": -0.15, "lh": Vector3(0.22, 0.52, 0.08), "le": 0.0, "rh": Vector3(-0.06, 0.92, 0.2), "lk": 0.4, "rk": -0.6}],
	[0.41, {"hips": Vector3(0.03, -0.14, 0.04), "turn": 0.05, "lean": 0.22, "tilt": -0.1, "lh": Vector3(0.12, 0.74, 0.3), "le": 0.0, "rh": Vector3(-0.1, 0.96, 0.14), "lfp": 0.2, "rfp": 0.5}],
	[0.46, {"hips": Vector3(0.0, -0.04, 0.08), "turn": -0.4, "lean": 0.02, "lh": Vector3(0.02, 1.02, 0.37), "le": 0.05, "rh": Vector3(-0.13, 0.95, 0.08), "lfp": 0.5, "rfp": 0.75}],
	[0.57, {"hips": Vector3(-0.01, 0.035, 0.1), "turn": -0.7, "lean": -0.18, "tilt": 0.06, "chin": -0.25, "lh": Vector3(-0.03, 1.27, 0.26), "le": 0.2, "rh": Vector3(-0.17, 0.88, 0.0), "lfp": 0.85, "rfp": 0.9, "lfy": -0.2}],
	[0.78, {"hips": Vector3(0.0, -0.1, 0.05), "turn": -0.6, "lean": 0.16, "lh": Vector3(0.04, 1.0, 0.24), "le": 0.3, "rh": Vector3(-0.15, 0.9, 0.08), "lfp": 0.15, "rfp": 0.4}],
	[1.0, {}],
]
## A kick: the flat of his boot, straight out in front. His weight goes onto
## his front foot; the back knee comes up to his chest; the leg is driven out
## from the hip, his body going back as it goes forward and his arms out to
## keep him on his feet; and it is snatched back and put down behind him again.
const KICK := [
	[0.0, {}],
	[0.2, {"hips": Vector3(0.05, -0.12, 0.04), "turn": -0.55, "lean": 0.3, "lh": Vector3(0.14, 0.92, 0.22), "rh": Vector3(-0.2, 0.84, 0.04), "rfp": 0.6, "lfy": 0.3}],
	[0.34, {"hips": Vector3(0.07, -0.04, 0.07), "turn": 0.1, "lean": -0.02, "tilt": 0.08, "lh": Vector3(0.22, 0.9, 0.16), "le": 0.5, "rh": Vector3(-0.3, 0.8, -0.1), "re": 0.5, "curl": 1.2,
		"rf": Vector3(-0.07, 0.4, 0.14), "rfy": -0.1, "rfp": 0.35, "rk": -0.1, "lfy": 0.5, "lk": 0.4}],
	[0.44, {"hips": Vector3(0.07, -0.045, 0.13), "turn": 0.4, "lean": -0.46, "tilt": 0.1, "chin": 0.3, "lh": Vector3(0.28, 0.9, -0.04), "le": 0.55, "rh": Vector3(-0.34, 0.68, -0.2), "re": 0.4, "curl": 1.0,
		"rf": Vector3(-0.03, 0.57, 0.7), "rfy": -0.15, "rfp": -0.95, "rk": 0.0, "lfy": 0.7, "lfp": 0.2, "lk": 0.6}],
	[0.52, {"hips": Vector3(0.07, -0.05, 0.12), "turn": 0.35, "lean": -0.4, "tilt": 0.1, "chin": 0.3, "lh": Vector3(0.28, 0.9, -0.02), "le": 0.55, "rh": Vector3(-0.33, 0.7, -0.18), "re": 0.4, "curl": 1.0,
		"rf": Vector3(-0.04, 0.53, 0.6), "rfy": -0.15, "rfp": -0.8, "rk": 0.0, "lfy": 0.7, "lfp": 0.1, "lk": 0.6}],
	[0.68, {"hips": Vector3(0.06, -0.05, 0.07), "turn": 0.0, "lean": 0.0, "lh": Vector3(0.2, 0.92, 0.14), "rh": Vector3(-0.25, 0.82, -0.02),
		"rf": Vector3(-0.09, 0.3, 0.1), "rfy": -0.2, "rfp": 0.4, "rk": -0.2, "lfy": 0.45, "lk": 0.35}],
	[0.86, {"hips": Vector3(0.01, -0.12, 0.0), "turn": -0.45, "lean": 0.26, "rf": Vector3(-0.14, 0.01, -0.13), "rfy": -0.55, "rfp": 0.2, "lfy": 0.15}],
	[1.0, {}],
]
## The heave, from braced. He drives up under the boy's feet as they leave his
## back, straightening his legs and then his back, up onto his toes with his
## arms flung up after him; comes down off them; and stands, looking up.
const HEAVE := [
	[0.0, {"hips": Vector3(0.0, -0.07, -0.16)}],
	[0.1, {"hips": Vector3(0.0, 0.0, -0.14), "bow": 0.95, "lean": -0.12, "knees": 0.3, "lh": Vector3(0.22, 0.62, 0.3), "rh": Vector3(-0.22, 0.62, 0.3), "curl": 0.2, "lfp": 0.45, "rfp": 0.45}],
	[0.22, {"hips": Vector3(0.0, 0.035, -0.04), "bow": 0.3, "lean": -0.3, "knees": 0.0, "chin": -0.4, "lh": Vector3(0.2, 1.22, 0.28), "rh": Vector3(-0.2, 1.22, 0.28), "le": 0.3, "re": 0.3, "curl": 0.1, "lfp": 0.8, "rfp": 0.8}],
	[0.36, {"hips": Vector3(0.0, 0.02, 0.0), "bow": 0.02, "lean": -0.26, "knees": 0.0, "chin": -0.5, "lh": Vector3(0.22, 1.3, 0.2), "rh": Vector3(-0.22, 1.3, 0.2), "le": 0.3, "re": 0.3, "curl": 0.1, "lfp": 0.55, "rfp": 0.55}],
	[0.58, {"hips": Vector3(0.0, -0.06, 0.0), "bow": 0.0, "lean": -0.06, "knees": 0.0, "chin": -0.5, "lh": Vector3(0.24, 0.95, 0.16), "rh": Vector3(-0.24, 0.95, 0.16), "le": 0.2, "re": 0.2, "arms": 0.8, "curl": 0.3,
		"lf": Vector3(0.16, 0.0, 0.0), "rf": Vector3(-0.16, 0.0, 0.0)}],
	[0.8, {"hips": Vector3(0.0, -0.01, 0.0), "bow": 0.0, "lean": -0.1, "knees": 0.0, "chin": -0.5, "lh": Vector3(0.22, 0.62, 0.06), "rh": Vector3(-0.22, 0.62, 0.06), "le": 0.1, "re": 0.1, "arms": 0.3, "curl": 0.4,
		"lf": Vector3(0.14, 0.0, 0.0), "rf": Vector3(-0.14, 0.0, 0.0), "lfy": 0.2, "rfy": -0.2, "lk": 0.15, "rk": -0.15}],
	[1.0, {"hips": Vector3(0.0, 0.0, 0.0), "bow": 0.0, "lean": -0.1, "knees": 0.0, "chin": -0.5, "lh": Vector3(0.2, 0.55, 0.03), "rh": Vector3(-0.2, 0.55, 0.03), "le": 0.0, "re": 0.0, "arms": 0.0, "curl": 0.4,
		"lf": Vector3(0.12, 0.0, 0.0), "rf": Vector3(-0.12, 0.0, 0.0), "lfy": 0.2, "rfy": -0.2, "lk": 0.15, "rk": -0.15}],
]

## The parts of a pose, in the order they are kept, and how many numbers each is.
const PARTS := [["hips", 3], ["turn", 1], ["lean", 1], ["bow", 1], ["tilt", 1], ["chin", 1], ["lh", 3], ["rh", 3], ["le", 1], ["re", 1],
	["arms", 1], ["knees", 1], ["curl", 1], ["lf", 3], ["lfy", 1], ["lfp", 1], ["lk", 1], ["rf", 3], ["rfy", 1], ["rfp", 1], ["rk", 1]]
const HIPS := 0
const TURN := 3
const LEAN := 4
const BOW := 5
const TILT := 6
const CHIN := 7
const HAND := 8  # (left; the right is three on)
const ELBOW := 14
const ARMS := 16
const KNEES := 17
const CURL := 18
const FOOT := 19  # (left: across, up, forward, yaw, pitch, knee; the right is six on)
const SIZE := 31

## Which move he is in: one of BLOWS, &"guard", &"brace", &"heave", or none
## (&""), when he is as CharacterRig has him. And how far through it, 0..1.
var move := &""
var move_at := 0.0
## Something he keeps his eyes on, whatever the rest of him is doing. Null: nothing.
var watch: Node3D
## How far above its origin he looks at it.
var watch_height := 0.9
## Somebody is standing on his back.
var burdened := false

## Each move as one curve for each number of a pose, and each pose that is held.
var _moves := {}
var _poses := {}
## The pose he is in, the one he was leaving when the move last changed, and
## how long ago that was: one move runs into the next over a moment, not at once.
var _pose_now := PackedFloat32Array()
var _pose_from := PackedFloat32Array()
var _pose_age := 1.0
var _blend_time := 0.1
var _move_shown := &""
var _move_was := &""
## How far all this is laid over what he would otherwise be doing, 0..1.
var _laid := 0.0
var _gazing := 0.0
var _eyes := Vector2.ZERO
var _burden := 0.0
var _burden_speed := 0.0


func _ready() -> void:
	super()
	_poses[&"guard"] = _whole(GUARD, {})
	_poses[&"brace"] = _whole(BRACE, {})
	for blow: Array in [[&"left_hook", LEFT_HOOK], [&"right_hook", RIGHT_HOOK], [&"uppercut", UPPERCUT], [&"kick", KICK]]:
		_moves[blow[0]] = _drawn(blow[1], GUARD)
	_moves[&"heave"] = _drawn(HEAVE, BRACE)
	_pose_now = _poses[&"guard"].duplicate()
	_pose_from = _pose_now.duplicate()


## A pose as its numbers, in order: `base` with whatever `changes` names put in place of its own.
func _whole(base: Dictionary, changes: Dictionary) -> PackedFloat32Array:
	var pose := PackedFloat32Array()
	for part: Array in PARTS:
		var value: Variant = changes.get(part[0], base[part[0]])
		if part[1] == 3:
			pose.append_array([value.x, value.y, value.z])
		else:
			pose.append(value)
	return pose


## A move's poses turned into a curve for each number, as _keyed reads them.
func _drawn(keys: Array, base: Dictionary) -> Array:
	var curves: Array = []
	for index in SIZE:
		curves.append([])
	for key: Array in keys:
		var pose := _whole(base, key[1])
		for index in SIZE:
			curves[index].append(key[0])
			curves[index].append(pose[index])
	return curves


func _pose_extra(delta: float) -> void:
	if move != _move_was:
		# A new move starts from wherever the last one had got him to.
		_blend_time = 0.3 if move == &"brace" or move == &"guard" else 0.09
		if _laid < 0.05 and move != &"":
			_pose_from = _pose_of(move, move_at)
			_pose_age = _blend_time
		else:
			_pose_from = _pose_now.duplicate()
			_pose_age = 0.0
		_move_was = move
		if move != &"":
			_move_shown = move
	_laid = _approach(_laid, 1.0 if move != &"" else 0.0, 16.0 if move != &"" else 5.0, delta)
	# A weight on his back sinks him a little, and he comes up again as it goes.
	_burden_speed += ((1.0 if burdened else 0.0) - _burden) * 260.0 * delta - _burden_speed * 16.0 * delta
	_burden += _burden_speed * delta
	if _laid > 0.002:
		var to := _pose_of(_move_shown, move_at)
		_pose_age += delta
		var along := smoothstep(0.0, 1.0, _pose_age / _blend_time)
		for index in SIZE:
			_pose_now[index] = lerpf(_pose_from[index], to[index], along)
		_lay_pose(_pose_now, _laid)
	_keep_watch(delta)


func _pose_of(which: StringName, at: float) -> PackedFloat32Array:
	if _poses.has(which):
		return _poses[which]
	var curves: Array = _moves[which]
	var pose := PackedFloat32Array()
	pose.resize(SIZE)
	for index in SIZE:
		pose[index] = _keyed(curves[index], at)
	return pose


## Puts him in `pose`, as far as `weight`, over whatever he was in.
func _lay_pose(pose: PackedFloat32Array, weight: float) -> void:
	# Where his feet were, in the rig's own space, before his hips are moved.
	var hips_were := _hips.transform
	var feet_were: Array[Transform3D] = []
	for i in 2:
		feet_were.append(hips_were * _feet[i].transform.orthonormalized())

	var turn := pose[TURN]
	var lean := pose[LEAN]
	var tilt := pose[TILT]
	# (in his guard he is never quite still)
	var bob := sin(_time * 5.2) * 0.005 * (1.0 - pose[KNEES])
	var at := Vector3(pose[HIPS], _hip_height + pose[HIPS + 1] + bob - 0.03 * _burden * pose[KNEES], pose[HIPS + 2])
	_hips.position = _hips.position.lerp(at, weight)
	_turn_joint(_hips, Vector3(lean * 0.4 + pose[BOW], turn * 0.45, tilt * 0.5), weight)
	if _chest:
		_turn_joint(_spine, Vector3(lean * 0.3, turn * 0.25, tilt * 0.25), weight)
		_turn_joint(_chest, Vector3(lean * 0.3, turn * 0.3, tilt * 0.25), weight)
	else:
		_turn_joint(_spine, Vector3(lean * 0.6, turn * 0.55, tilt * 0.5), weight)

	var to_hips := _hips.transform.affine_inverse()
	for i in 2:
		var side := 1.0 if i == 0 else -1.0
		var from := FOOT + 6 * i
		var yaw := pose[from + 3]
		var pitch := pose[from + 4]
		var planted := 1.0 - smoothstep(0.0, 0.05, pose[from + 1])
		var about := Basis(Vector3.UP, yaw)
		var goal := Transform3D(about * Basis(Vector3.RIGHT, pitch), Vector3(pose[from], pose[from + 1], pose[from + 2]) + about * _ankle_over(pitch))
		var foot := feet_were[i].interpolate_with(goal, weight)
		# (on the ball of a foot that is down, the toes stay flat on the ground)
		_toes[i].rotation.x = lerpf(_toes[i].rotation.x, -maxf(pitch, 0.0) * planted, weight)
		_solve_leg(i, side, to_hips * foot.origin, (to_hips.basis * foot.basis).orthonormalized(), pose[from + 5] * weight)

	for i in 2:
		var side := 1.0 if i == 0 else -1.0
		var hand := Vector3(pose[HAND + 3 * i], pose[HAND + 3 * i + 1], pose[HAND + 3 * i + 2])
		# On his knees, his hands are wherever his knees are.
		var knee := to_local(_shins[i].global_position) + Vector3(side * 0.01, 0.045, 0.04)
		hand = hand.lerp(knee, pose[KNEES])
		var raised := pose[ELBOW + i]
		var pole := Vector3(side * (0.45 + 0.75 * raised), -1.0 + 1.2 * raised, -0.35)
		var held := weight * pose[ARMS]
		_arm_to(i, side, hand, _forearm + 0.05, held, pole)
		_hands[i].basis = _hands[i].basis.orthonormalized().slerp(Basis.IDENTITY, held)
		_curl[i] = lerpf(_curl[i], pose[CURL], held)
		_splay[i] = lerpf(_splay[i], lerpf(0.3, 0.9, pose[KNEES]), held)
		if has_method(&"_pose_fingers"):
			call(&"_pose_fingers", i, side)


## Turns a joint to `angles`, as far as `weight`.
func _turn_joint(joint: Node3D, angles: Vector3, weight: float) -> void:
	joint.basis = joint.basis.orthonormalized().slerp(Basis.from_euler(angles), weight)


## Where the ankle is over a foot standing at the origin and pitched: up on the
## ball of it (positive) the ankle rides up and forward, back on the heel, up and back.
func _ankle_over(pitch: float) -> Vector3:
	if pitch >= 0.0:
		var up := -_toe.y
		return Vector3(0.0, SOLE + up * cos(pitch) + _toe.z * sin(pitch), _toe.z * (1.0 - cos(pitch)) + up * sin(pitch))
	return Vector3(0.0, ANKLE * cos(pitch) + 0.045 * sin(-pitch), -ANKLE * sin(-pitch) + 0.045 * (1.0 - cos(pitch)))


## Puts a hand at `at` (in the rig's own space), the elbow towards `pole`.
func _arm_to(i: int, side: float, at: Vector3, fore_length: float, weight: float, pole: Vector3) -> void:
	if weight < 0.002:
		return
	# (_solve_arm measures the reach in the world but the arm in the model's own
	# units, which on a figure that is scaled up are not the same: so the point
	# is brought in towards the shoulder by as much as he is scaled)
	var shoulder := _shoulders[i].global_position
	var point := shoulder + (to_global(at) - shoulder) / global_basis.get_scale().y
	_solve_arm(i, side, point, fore_length, weight, (global_basis.orthonormalized() * pole).normalized())


## Keeps his head towards what he is watching, as far as his neck will turn; or,
## in one of his own moves with nothing to watch, level and straight ahead.
func _keep_watch(delta: float) -> void:
	var watching := is_instance_valid(watch) and watch.is_inside_tree()
	_gazing = _approach(_gazing, 1.0 if watching else 0.0, 6.0, delta)
	var weight := maxf(_laid, _gazing)
	if weight < 0.002:
		return
	var want := Vector2(0.0, _pose_now[CHIN])
	if watching:
		var to := to_local(watch.global_position + Vector3.UP * watch_height) - to_local(_head.global_position) - Vector3(0.0, 0.08, 0.0)
		want = Vector2(atan2(to.x, to.z), -atan2(to.y, Vector2(to.x, to.z).length()))
		# (what is behind him he looks at over the nearer shoulder, as far as he can)
		want.x = clampf(want.x, -1.9, 1.9)
	_eyes = _eyes.lerp(want, 1.0 - exp(-9.0 * delta))
	var upright := global_basis.orthonormalized()
	var back := (_chest if _chest else _spine).global_basis.orthonormalized()
	var wanted := upright * Basis(Vector3.UP, _eyes.x) * Basis(Vector3.RIGHT, _eyes.y)
	var off := back.get_rotation_quaternion().angle_to(wanted.get_rotation_quaternion())
	if off > 1.15:
		wanted = back.slerp(wanted, 1.15 / off)
	if _neck:
		var neck := back.slerp(wanted, 0.5)
		_neck.basis = _neck.basis.orthonormalized().slerp((back.inverse() * neck).orthonormalized(), weight)
		_head.basis = _head.basis.orthonormalized().slerp((_neck.global_basis.orthonormalized().inverse() * wanted).orthonormalized(), weight)
	else:
		_head.basis = _head.basis.orthonormalized().slerp((back.inverse() * wanted).orthonormalized(), weight)


## How high his back is off the ground while he is braced, in the world: where
## whoever climbs onto it stands.
func back_height() -> float:
	var back := _chest if _chest else _spine
	return maxf(_hips.global_position.y, back.global_position.y) - global_position.y + 0.1 * global_basis.get_scale().y
