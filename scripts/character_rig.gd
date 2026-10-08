class_name CharacterRig
extends Node3D
## Drives the character model (models/boy.glb) entirely in code.
##
## There are no clips: the gait is driven by distance travelled so feet do not
## slide, legs are placed with two-bone IK, and everything else (lean, twist,
## arm swing, landing crouch) is layered on with springs. The model faces +Z,
## and its bones all rest unrotated (see tools/build_character.py), so a bone's
## pose is simply its transform relative to its parent bone.

## Height of a planted foot's ankle joint above the ground.
const ANKLE := 0.05

## The figure's proportions. These are read from its skeleton when it is built
## (see _measure), so the boy and the mummy each move to their own measure.
var _hip_height := 0.585
var _hip_width := 0.075
## How far below the hips bone the hip joints sit (negative).
var _hip_drop := -0.02
var _thigh := 0.27
var _shin := 0.27
var _upper_arm := 0.2
var _forearm := 0.2
## How far out the model's arms are held at rest, radians.
var _arm_rest := 0.22
## Where the foot bends, from the ankle.
var _toe := Vector3(0.0, -0.035, 0.075)
## Leg length against the boy's, for scaling strides.
var _leg_scale := 1.0
## How far a limp elbow and knee may turn, radians (lower, upper).
const ELBOW_LIMITS := Vector2(-2.4, 0.0)
const KNEE_LIMITS := Vector2(0.0, 2.4)
const MODELS: Array[PackedScene] = [preload("res://models/boy.glb"), preload("res://models/boy_lo.glb")]

## Use the demade, low-poly model (models/boy_lo.glb).
@export var low_poly := false
## A different figure on the same skeleton (the mummy). Overrides `low_poly`.
@export var model: PackedScene
## Arms held out ahead, 0..1, for something that walks with its hands reaching.
@export_range(0.0, 1.0) var arms_reach := 0.0
## Extra forward hunch, radians.
@export var stoop := 0.0
## Flat bands of light and a dark outline, instead of smooth shading.
@export var cel_shaded := true


## Whoever this figure is: the Player, or any body with the same shape (velocity,
## is_on_floor(), walk_speed, run_speed, is_pushing). Its jumped, landed and
## respawned signals are used if it has them.
var _player
var _hips: Node3D
var _spine: Node3D
var _head: Node3D
var _thighs: Array[Node3D] = []
var _shins: Array[Node3D] = []
var _feet: Array[Node3D] = []
var _toes: Array[Node3D] = []
var _shoulders: Array[Node3D] = []
var _elbows: Array[Node3D] = []
var _skeleton: Skeleton3D
var _joints: Array[Node3D] = []
var _bones: Array[int] = []

var _time := 0.0
var _phase := 0.0
var _move := 0.0
var _run := 0.0
var _air := 0.0
var _push := 0.0
var _crouch := 0.0
var _crouch_velocity := 0.0
var _lean := Vector2.ZERO
var _accel := Vector3.ZERO
var _yaw_rate := 0.0
var _prev_velocity := Vector3.ZERO
var _prev_yaw := 0.0
var _lead_leg := 0
## Pulses to 1 at take-off and at touch-down, then fades.
var _launch := 0.0
var _land := 0.0
## Braking against his own momentum, 0..1.
var _skid := 0.0
## Head turn towards a hound on his heels, radians.
var _glance := 0.0
## Blends towards each of the poses a Player can be in, 0..1.
var _duck := 0.0
var _slide := 0.0
var _hang := 0.0
var _climb := 0.0
var _rope := 0.0
var _rope_phase := 0.0
var _carry := 0.0
var _throw := 0.0
## How firmly the hands are held to the points the body gives them, 0..1.
var _reach := 0.0
## The ragdoll, while limp: its container and each (pose node, rigid body) pair, parents first.
var _ragdoll: Node3D
var _limbs: Array[Array] = []


func _ready() -> void:
	_build()
	_player = get_parent()
	if _player and _player.has_signal(&"jumped"):
		_player.jumped.connect(_on_jumped)
		_player.landed.connect(_on_landed)
		_player.respawned.connect(_on_respawned)
	if _player and _player.has_signal(&"threw"):
		_player.threw.connect(func() -> void: _throw = 1.0)
	_prev_yaw = rotation.y


func _process(delta: float) -> void:
	if _player == null:
		return
	if _ragdoll:
		_follow_ragdoll()
		_apply_pose()
		return
	delta = minf(delta, 1.0 / 30.0)
	_time += delta

	var velocity: Vector3 = _player.velocity
	var flat := Vector3(velocity.x, 0.0, velocity.z)
	var speed := flat.length()
	var grounded: bool = _player.is_on_floor()

	# What the body is up to beyond walking and jumping. Only a Player does any
	# of it; the mummy, on the same rig, has none of these.
	var doing: int = _player.state if &"state" in _player else 0
	var ducking: bool = _player.is_ducking if &"is_ducking" in _player else false
	var holding: bool = &"carried" in _player and _player.carried != null
	var hanging := doing == Player.State.HANG or doing == Player.State.CLIMB
	_duck = _approach(_duck, 1.0 if ducking and doing == Player.State.FREE else 0.0, 12.0, delta)
	_slide = _approach(_slide, 1.0 if doing == Player.State.SLIDE else 0.0, 14.0, delta)
	_hang = _approach(_hang, 1.0 if hanging else 0.0, 16.0, delta)
	_climb = _player.climb_progress if doing == Player.State.CLIMB else 0.0
	_rope = _approach(_rope, 1.0 if doing == Player.State.ROPE else 0.0, 14.0, delta)
	if doing == Player.State.ROPE:
		_rope_phase = _player.rope_travel
	_carry = _approach(_carry, 1.0 if holding else 0.0, 10.0, delta)
	_throw = _approach(_throw, 0.0, 7.0, delta)
	_reach = _approach(_reach, _player.hand_reach if &"hand_reach" in _player else 0.0, 14.0, delta)
	if doing != Player.State.FREE:
		grounded = true

	_move = _approach(_move, clampf(speed / _player.walk_speed, 0.0, 1.0), 10.0, delta)
	_run = _approach(_run, clampf(inverse_lerp(_player.walk_speed, _player.run_speed, speed), 0.0, 1.0), 8.0, delta)
	_air = _approach(_air, 0.0 if grounded else 1.0, 16.0 if grounded else 10.0, delta)
	_push = _approach(_push, 1.0 if _player.is_pushing else 0.0, 8.0, delta)
	_launch = _approach(_launch, 0.0, 11.0, delta)
	_land = _approach(_land, 0.0, 5.0, delta)

	_accel = _accel.lerp((flat - _prev_velocity) / delta, 1.0 - exp(-8.0 * delta))
	_yaw_rate = lerpf(_yaw_rate, angle_difference(_prev_yaw, rotation.y) / delta, 1.0 - exp(-10.0 * delta))
	_prev_velocity = flat
	_prev_yaw = rotation.y

	# Landing and take-off kick this spring; it settles back on its own.
	_crouch_velocity += ((_push * 0.05 - _crouch) * 220.0 - _crouch_velocity * 22.0) * delta
	_crouch = clampf(_crouch + _crouch_velocity * delta, -0.03, 0.3)

	# One cycle is two steps. Advancing by distance keeps planted feet planted.
	var stride := lerpf(0.74, 1.8, _run) * (1.0 - 0.3 * _duck) * _leg_scale
	var stance := lerpf(0.6, 0.34, _run)
	if grounded:
		# (a figure scaled up covers more ground per stride)
		_phase = fposmod(_phase + speed / (stride * global_basis.get_scale().y) * delta, 1.0)
	# Braking hard against his own momentum, as when the stick is thrown the other way.
	var against := -flat.dot(global_basis.z) / maxf(_player.run_speed, 0.01)
	_skid = _approach(_skid, clampf(against * 1.6, 0.0, 1.0) if grounded else 0.0, 12.0, delta)
	_glance = _approach(_glance, _threat_bearing(), 6.0, delta)
	var gait := _move * (1.0 - _air) * (1.0 - _skid) * (1.0 - _slide) * (1.0 - maxf(_hang, _rope))

	_pose_body(speed, velocity.y, stance, gait)
	_pose_legs(velocity.y, stride, stance, gait)
	_pose_arms(velocity.y, gait)
	_reach_arms()
	_apply_pose()


func _pose_body(speed: float, vertical_speed: float, stance: float, gait: float) -> void:
	var forward := global_basis.z
	var pitch := _run * 0.2 + _move * 0.03 + clampf(_accel.dot(forward) * 0.012, -0.2, 0.2)
	pitch += _duck * 0.95 - _slide * 1.1 + sin(PI * _climb) * 0.45
	pitch += stoop + _push * 0.36 + _air * clampf(-vertical_speed * 0.02, -0.08, 0.16) + _skid * 0.3
	var roll := clampf(-_yaw_rate * speed * 0.012, -0.22, 0.22)
	_lean = _lean.lerp(Vector2(pitch, roll), 1.0 - exp(-9.0 * get_process_delta_time()))

	# Twice per cycle. Walking vaults over a straight leg, so the body is highest
	# at mid-stance; running sinks into the leg there and is highest in flight.
	var bob := cos(TAU * 2.0 * (_phase - stance * 0.5)) * lerpf(0.02, -0.03, _run) * gait
	var breath := sin(_time * 1.7)
	var sway := cos(TAU * (_phase - stance * 0.5)) * 0.014 * gait * (1.0 - _run * 0.5)
	var twist := -cos(TAU * _phase) * lerpf(0.1, 0.17, _run) * gait

	# Standing still he shifts his weight and looks about.
	var idle := 1.0 - _move
	sway += sin(_time * 0.55) * 0.014 * idle
	var look := (sin(_time * 0.37) * 0.28 + sin(_time * 0.83 + 1.0) * 0.1) * idle + _glance
	_hips.position = Vector3(sway, _hip_height - _run * 0.02 - _crouch - _skid * 0.08 - _duck * 0.3 - _slide * 0.34 + bob + breath * 0.003 * (1.0 - _move), 0.0)
	_hips.rotation = Vector3(_lean.x * 0.5 + _crouch * 0.8, twist, _lean.y)
	_spine.rotation = Vector3(_lean.x * 0.5 + breath * 0.012 + _crouch * 0.9, -twist * 1.8 + look * 0.25, _lean.y * 0.5)
	# The head stays level and looks where the body is going.
	_head.rotation = Vector3(-_lean.x * 0.7 - _crouch * 1.2, twist * 0.8 + clampf(_yaw_rate * 0.04, -0.4, 0.4) + look * 0.75, -_lean.y * 0.9)


func _pose_legs(vertical_speed: float, stride: float, stance: float, gait: float) -> void:
	var to_hips := _hips.transform.affine_inverse()
	var half_step := stance * stride * 0.5
	var lift := lerpf(0.06, 0.26, _run) * _leg_scale
	var rising := clampf(vertical_speed / 5.0, -1.0, 1.0) * 0.5 + 0.5
	for i in 2:
		var side := 1.0 if i == 0 else -1.0
		var cycle := _foot_cycle(fposmod(_phase + 0.5 * i, 1.0), stance, half_step, lift)
		var pitch := cycle.x * gait
		# Up on the toes (or back on the heel) the ankle rides higher, which is
		# what lets the leg stay long at each end of a stride.
		var ankle := ANKLE + sin(maxf(pitch, 0.0)) * 0.1 + sin(maxf(-pitch, 0.0)) * 0.04
		var target := Vector3(side * _hip_width, ankle + cycle.y * gait, cycle.z * gait)

		# Airborne: knees tuck on the way up, legs reach for the ground on the way down.
		var lead := i == _lead_leg
		var tucked := Vector3(side * _hip_width, 0.36 if lead else 0.2, 0.22 if lead else -0.28)
		var reaching := Vector3(side * (_hip_width + 0.02), 0.06 if lead else 0.03, 0.17 if lead else 0.02)
		reaching.z += sin(_time * 9.0 + i * PI) * 0.03
		target = target.lerp(reaching.lerp(tucked, rising), _air)
		pitch = lerpf(pitch, 0.45, _air)
		# Skidding: feet planted apart, the back one braking.
		target = target.lerp(Vector3(side * (_hip_width + 0.03), ANKLE, -0.3 if i == 0 else 0.12), _skid)
		pitch = lerpf(pitch, 0.0, _skid)
		# Sliding: one leg out in front, the other folded under.
		target = target.lerp(Vector3(side * _hip_width, ANKLE + 0.05, 0.5 if i == 0 else 0.2), _slide)
		# Hanging: legs loose below; climbing brings a knee up onto the ledge.
		var heave := sin(PI * _climb)
		var dangle := Vector3(side * _hip_width, ANKLE + 0.03 + heave * (0.4 if i == 0 else 0.12), 0.04 + sin(_time * 2.0 + i) * 0.03 + heave * 0.22)
		target = target.lerp(dangle, _hang)
		# On a rope: knees up, feet gripping, shifting as the hands do.
		target = target.lerp(Vector3(side * 0.04, ANKLE + 0.26 + sin(_rope_phase * 5.0 + i * PI) * 0.07, 0.14), _rope)
		pitch = lerpf(pitch, 0.5, maxf(_hang, _rope))
		# Take-off: both legs drive down off the toes before the knees come up.
		target = target.lerp(Vector3(side * _hip_width, ANKLE + 0.06, -0.04 if lead else -0.15), _launch)
		pitch = lerpf(pitch, 0.95, _launch)

		# Planted on the ball of the foot, the toes stay flat while the heel comes up.
		_toes[i].rotation.x = -maxf(cycle.x * gait, 0.0) * (1.0 - clampf(cycle.y / 0.05, 0.0, 1.0)) * (1.0 - _air)
		_solve_leg(i, side, to_hips * target, to_hips.basis * Basis(Vector3.RIGHT, pitch))


## Foot path for one leg over a gait cycle. Returns (toe pitch, height, forward).
func _foot_cycle(phase: float, stance: float, half_step: float, lift: float) -> Vector3:
	# Running, the foot lands nearly under the body and pushes off well behind it.
	var trail := 0.09 * _run
	if phase < stance:
		# Planted: carried backwards under the body, rolling heel to toe.
		var t := phase / stance
		var roll := smoothstep(0.55, 1.0, t) * lerpf(0.55, 0.95, _run) - (1.0 - smoothstep(0.0, 0.2, t)) * lerpf(0.25, 0.1, _run)
		return Vector3(roll, 0.0, lerpf(half_step, -half_step, t) - trail)
	# Swinging forward. The heel kicks up behind first, then the knee drives
	# through and the foot reaches out late.
	var t := (phase - stance) / (1.0 - stance)
	var height := sin(PI * pow(t, 0.62)) * lift
	var toe := lerpf(lerpf(0.55, 0.95, _run), -0.2, smoothstep(0.2, 1.0, t)) + sin(PI * t) * 0.3 * _run
	var carry := lerpf(smoothstep(0.0, 1.0, t), smoothstep(0.12, 0.95, t), _run)
	return Vector3(toe, height, lerpf(-half_step, half_step, carry) - trail)


## Two-bone IK in hip space, knee bending forward.
func _solve_leg(index: int, side: float, target: Vector3, foot_basis: Basis) -> void:
	var hip := Vector3(side * _hip_width, _hip_drop, 0.0)
	var to_target := target - hip
	var reach := clampf(to_target.length(), 0.1, _thigh + _shin - 0.004)
	var direction := to_target.normalized() if to_target.length_squared() > 0.0001 else Vector3.DOWN
	var bend_axis := direction.cross(Vector3.BACK)
	bend_axis = bend_axis.normalized() if bend_axis.length_squared() > 0.0001 else Vector3.LEFT
	var hip_angle := acos(clampf((_thigh * _thigh + reach * reach - _shin * _shin) / (2.0 * _thigh * reach), -1.0, 1.0))
	var thigh_direction := direction.rotated(bend_axis, hip_angle)
	var knee := hip + thigh_direction * _thigh
	var ankle := hip + direction * reach
	_thighs[index].transform = Transform3D(_aim_down(thigh_direction), hip)
	_shins[index].transform = Transform3D(_aim_down((ankle - knee).normalized()), knee)
	_feet[index].transform = Transform3D(foot_basis, ankle)


func _pose_arms(vertical_speed: float, gait: float) -> void:
	var rising := clampf(vertical_speed / 5.0, -1.0, 1.0) * 0.5 + 0.5
	for i in 2:
		var side := 1.0 if i == 0 else -1.0
		# Opposite to the leg on the same side. Negative pitch is forward.
		var swing := side * cos(TAU * _phase) * lerpf(0.5, 0.9, _run) * gait
		var pitch := swing + 0.05
		var roll := side * 0.09
		var elbow := -(0.14 + lerpf(0.12, 1.3, _run) * gait + maxf(-swing, 0.0) * 0.4)

		var flail := sin(_time * 10.0 + i * 2.1) * 0.14
		# Rising, the arm opposite the leading knee drives forward, as in a stride.
		var air_pitch := lerpf(-0.35 + flail, 0.75 if i == _lead_leg else -1.15, rising)
		var air_roll := side * lerpf(1.05 + flail, 0.3, rising)
		pitch = lerpf(pitch, air_pitch, _air)
		roll = lerpf(roll, air_roll, _air)
		elbow = lerpf(elbow, lerpf(-0.45, -0.7 if i == _lead_leg else -1.35, rising), _air)

		# Take-off throws the arms up and forward; landing spreads them for balance.
		pitch = lerpf(pitch, -1.9, _launch * _launch)
		elbow = lerpf(elbow, -0.6, _launch * _launch)
		pitch = lerpf(pitch, 0.35, _land * (1.0 - _air))
		roll = lerpf(roll, side * 0.7, _land * (1.0 - _air))
		elbow = lerpf(elbow, -0.7, _land * (1.0 - _air))

		roll = lerpf(roll, side * 0.75, _skid)
		elbow = lerpf(elbow, -0.5, _skid)

		pitch = lerpf(pitch, -1.3, _push)
		roll = lerpf(roll, -side * 0.06, _push)
		elbow = lerpf(elbow, -0.4, _push)

		# Sliding: the trailing hand skims the ground behind.
		pitch = lerpf(pitch, 0.9 if i == 1 else -0.5, _slide)
		elbow = lerpf(elbow, -0.3, _slide)
		# Hanging by the hands; pulling up, they end beside the hips pushing down.
		pitch = lerpf(pitch, lerpf(-2.95, -0.25, smoothstep(0.15, 0.75, _climb)), _hang)
		roll = lerpf(roll, side * 0.12, _hang)
		elbow = lerpf(elbow, -0.12 - sin(PI * _climb) * 1.5, _hang)
		# Hand over hand up a rope.
		var haul := sin(_rope_phase * 5.0 + i * PI)
		pitch = lerpf(pitch, -2.55 + haul * 0.3, _rope)
		roll = lerpf(roll, -side * 0.2, _rope)
		elbow = lerpf(elbow, -0.9 + haul * 0.45, _rope)
		# Carrying in the right hand, up by the shoulder; a throw whips it forward.
		if i == 1:
			pitch = lerpf(lerpf(pitch, -0.9, _carry), -2.0, _throw)
			elbow = lerpf(lerpf(elbow, -1.7, _carry), -0.25, _throw)

		pitch = lerpf(pitch, -1.35 + sin(_time * 1.3 + i * 1.7) * 0.08, arms_reach)
		roll = lerpf(roll, -side * 0.05, arms_reach)
		elbow = lerpf(elbow, -0.25, arms_reach)

		_shoulders[i].rotation = Vector3(pitch, 0.0, roll)
		_elbows[i].rotation = Vector3(elbow, 0.0, 0.0)


func _on_jumped() -> void:
	_crouch_velocity -= 1.2
	_launch = 1.0
	# Tuck whichever leg is already swinging forward.
	_lead_leg = 1 if _phase < 0.5 else 0


func _on_landed(impact_speed: float) -> void:
	_crouch_velocity += clampf(impact_speed * 0.5, 0.6, 7.0)
	_land = clampf(impact_speed / 9.0, 0.3, 1.0)


func _on_respawned() -> void:
	_prev_velocity = Vector3.ZERO
	_prev_yaw = rotation.y
	_accel = Vector3.ZERO
	_yaw_rate = 0.0
	_crouch = 0.0
	_crouch_velocity = 0.0


static func _approach(from: float, to: float, rate: float, delta: float) -> float:
	return lerpf(from, to, 1.0 - exp(-rate * delta))


## Basis whose -Y axis points along `direction`, keeping +Z as forward as possible.
static func _aim_down(direction: Vector3) -> Basis:
	var y := -direction
	var x := y.cross(Vector3.BACK)
	x = x.normalized() if x.length_squared() > 0.0001 else Vector3.RIGHT
	return Basis(x, y, x.cross(y))


func _build() -> void:
	var figure := (model if model else MODELS[1 if low_poly or Settings.low_poly else 0]).instantiate()
	add_child(figure)
	if cel_shaded:
		Toon.apply(figure)
	_skeleton = figure.find_children("*", "Skeleton3D", true, false)[0]

	_measure()
	_hips = _joint(self, &"hips", Vector3(0.0, _hip_height, 0.0))
	_spine = _joint(_hips, &"spine", _rest(&"spine"))
	_head = _joint(_spine, &"head", _rest(&"head"))
	for suffix: String in ["_l", "_r"]:
		var side := 1.0 if suffix == "_l" else -1.0
		var shoulder := _joint(_spine, "upper_arm" + suffix, _rest("upper_arm" + suffix))
		_shoulders.append(shoulder)
		_elbows.append(_joint(shoulder, "forearm" + suffix, Vector3(0.0, -_upper_arm, 0.0)))
		var hip := Vector3(side * _hip_width, _hip_drop, 0.0)
		_thighs.append(_joint(_hips, "thigh" + suffix, hip))
		_shins.append(_joint(_hips, "shin" + suffix, hip + Vector3.DOWN * _thigh))
		_feet.append(_joint(_hips, "foot" + suffix, hip + Vector3.DOWN * (_thigh + _shin)))
		_toes.append(_joint(_feet[-1], "toe" + suffix, _toe))


## Adds a pose node for a bone. The animation moves these like ordinary nodes
## and _apply_pose copies them onto the skeleton.
func _joint(parent: Node3D, bone: StringName, at: Vector3) -> Node3D:
	var joint := Node3D.new()
	joint.position = at
	parent.add_child(joint)
	_joints.append(joint)
	_bones.append(_skeleton.find_bone(bone))
	return joint


func _apply_pose() -> void:
	for i in _joints.size():
		_skeleton.set_bone_pose(_bones[i], _joints[i].transform)
	# The arms are modelled held away from the body so the sleeves stay clear of
	# the shirt; turn that back out so an unposed arm hangs straight.
	for i in 2:
		var rest := Basis(Vector3.BACK, (1.0 if i == 0 else -1.0) * _arm_rest)
		var shoulder := _shoulders[i].transform
		var elbow := _elbows[i].transform
		_skeleton.set_bone_pose(_bones[_joints.find(_shoulders[i])], Transform3D(shoulder.basis * rest.inverse(), shoulder.origin))
		_skeleton.set_bone_pose(_bones[_joints.find(_elbows[i])], Transform3D(rest * elbow.basis * rest.inverse(), rest * elbow.origin))


func is_limp() -> bool:
	return _ragdoll != null


## Where the body is lying (its hips), while limp.
func limp_position() -> Vector3:
	return (_limbs[0][1] as RigidBody3D).global_position if _ragdoll else global_position


## Lets go of the pose: the figure becomes jointed rigid bodies that start from
## exactly where it is, moving at `velocity`, with `impulse` landing on the chest.
## The pose nodes then follow the bodies, so the model goes on being drawn the
## same way. `recover` hands control back to the animation.
func go_limp(velocity: Vector3, impulse := Vector3.ZERO) -> void:
	if _ragdoll:
		return
	_ragdoll = Node3D.new()
	_ragdoll.top_level = true
	add_child(_ragdoll)
	_ragdoll.global_transform = Transform3D.IDENTITY

	var hips := _limb(_hips, 6.0, 0.1, 0.0)
	var spine := _limb(_spine, 9.0, 0.095, 0.32)
	var head := _limb(_head, 3.0, 0.11, 0.27)
	_socket(hips, spine, 0.45, 0.35)
	_socket(spine, head, 0.6, 0.5)
	for i in 2:
		var upper := _limb(_shoulders[i], 1.2, 0.04, -_upper_arm)
		var fore := _limb(_elbows[i], 1.0, 0.035, -_forearm - 0.07)
		var thigh := _limb(_thighs[i], 3.5, 0.06, -_thigh)
		var shin := _limb(_shins[i], 2.5, 0.05, -_shin - 0.05)
		_socket(spine, upper, 1.7, 0.6)
		_hinge(upper, fore, ELBOW_LIMITS)
		_socket(hips, thigh, 1.0, 0.25)
		_hinge(thigh, shin, KNEE_LIMITS)
	for limb in _limbs:
		(limb[1] as RigidBody3D).linear_velocity = velocity
	spine.apply_central_impulse(impulse)


func recover() -> void:
	if _ragdoll == null:
		return
	_ragdoll.queue_free()
	_ragdoll = null
	_limbs.clear()
	_on_respawned()


func _follow_ragdoll() -> void:
	for limb in _limbs:
		(limb[0] as Node3D).global_transform = (limb[1] as RigidBody3D).global_transform
	for i in 2:
		# Feet have no body of their own; they ride on the shins.
		_feet[i].global_transform = _shins[i].global_transform * Transform3D(Basis.IDENTITY, Vector3.DOWN * _shin)
		_toes[i].rotation = Vector3.ZERO


## A rigid body standing in for the bone `joint` drives: a capsule reaching
## `extent` along the bone (negative hangs below the joint), or a ball if zero.
func _limb(joint: Node3D, mass: float, radius: float, extent: float) -> RigidBody3D:
	var body := RigidBody3D.new()
	body.mass = mass
	body.angular_damp = 3.0
	# Its own layer: the world stops it, nothing else notices it.
	body.collision_layer = 8
	body.collision_mask = 1
	var collider := CollisionShape3D.new()
	if is_zero_approx(extent):
		var ball := SphereShape3D.new()
		ball.radius = radius
		collider.shape = ball
	else:
		var capsule := CapsuleShape3D.new()
		capsule.radius = radius
		capsule.height = maxf(absf(extent), radius * 2.0)
		collider.shape = capsule
		collider.position.y = extent * 0.5
	body.add_child(collider)
	_ragdoll.add_child(body)
	body.global_transform = joint.global_transform.orthonormalized()
	_limbs.append([joint, body])
	return body


## Ball-and-socket between two limbs at the child's joint, limited to a cone.
func _socket(parent: RigidBody3D, child: RigidBody3D, swing: float, twist: float) -> void:
	var joint := ConeTwistJoint3D.new()
	joint.swing_span = swing
	joint.twist_span = twist
	_attach(joint, parent, child)


## Elbows and knees: one axis, and only the way they really bend.
func _hinge(parent: RigidBody3D, child: RigidBody3D, limits: Vector2) -> void:
	var joint := HingeJoint3D.new()
	# The engine measures a hinge from the pose it is made in, and in the opposite
	# sense to a turn about the limb's X axis, so restate the limits that way.
	var relative := parent.global_basis.inverse() * child.global_basis
	var bend := clampf(atan2(relative.y.z, relative.y.y), limits.x, limits.y)
	joint.set_flag(HingeJoint3D.FLAG_USE_LIMIT, true)
	joint.set_param(HingeJoint3D.PARAM_LIMIT_LOWER, bend - limits.y)
	joint.set_param(HingeJoint3D.PARAM_LIMIT_UPPER, bend - limits.x)
	_attach(joint, parent, child)


func _attach(joint: Joint3D, parent: RigidBody3D, child: RigidBody3D) -> void:
	_ragdoll.add_child(joint)
	# A cone twists about the joint's X and a hinge turns about its Z: point X
	# along the limb and Z along the limb's own side-to-side axis.
	var limb := child.global_basis
	joint.global_transform = Transform3D(Basis(limb.y, limb.z, limb.x), child.global_position)
	joint.node_a = joint.get_path_to(parent)
	joint.node_b = joint.get_path_to(child)


## Which way to turn the head to look at a hound that is close and coming, or 0.
## He only glances, a second or so at a time.
func _threat_bearing() -> float:
	if sin(_time * 1.9) < 0.2:
		return 0.0
	var nearest := 9.0
	var bearing := 0.0
	for hound in get_tree().get_nodes_in_group(&"pursuers"):
		var to: Vector3 = hound.global_position - global_position
		if hound.chasing and to.length() < nearest:
			nearest = to.length()
			bearing = clampf(angle_difference(rotation.y, atan2(to.x, to.z)), -1.3, 1.3)
	return bearing


## Where the right hand is, for whatever it is holding.
func hand_position() -> Vector3:
	return _elbows[1].global_transform * Vector3(0.0, -_forearm - 0.07, 0.0)


## Takes the figure's proportions from its skeleton's rest pose.
func _measure() -> void:
	_hip_height = _rest(&"hips").y
	var thigh := _rest(&"thigh_l")
	var shin := _rest(&"shin_l")
	_hip_width = absf(thigh.x)
	_hip_drop = thigh.y
	_thigh = thigh.distance_to(shin)
	_shin = shin.distance_to(_rest(&"foot_l"))
	_toe = _rest(&"toe_l")
	var elbow := _rest(&"forearm_l")
	_upper_arm = elbow.length()
	_forearm = _upper_arm
	_arm_rest = atan2(elbow.x, -elbow.y)
	_leg_scale = (_thigh + _shin) / 0.54


## Where a bone rests, relative to its parent bone.
func _rest(bone: StringName) -> Vector3:
	return _skeleton.get_bone_rest(_skeleton.find_bone(bone)).origin


## Puts the hands where the body says they belong (a ledge, a rope, a wall)
## by solving each arm as two bones, over whatever the arms were doing.
func _reach_arms() -> void:
	if _reach < 0.01:
		return
	var points: PackedVector3Array = _player.hand_points
	var forward := global_basis.z.normalized()
	var fore_length := _forearm + 0.06
	for i in 2:
		var side := 1.0 if i == 0 else -1.0
		# The right hand keeps hold of anything it is carrying.
		var weight := _reach * (1.0 - _carry if i == 1 else 1.0)
		var shoulder := _shoulders[i]
		var from := shoulder.global_position
		var to := points[i] - from
		var reach := clampf(to.length(), 0.08, _upper_arm + fore_length - 0.005)
		var direction := to.normalized()
		# Elbows hang down and a little out.
		var pole := Vector3.DOWN + global_basis.x.normalized() * side * 0.6 - forward * 0.3
		var bend_axis := direction.cross(pole)
		bend_axis = bend_axis.normalized() if bend_axis.length_squared() > 0.0001 else global_basis.x.normalized()
		var angle := acos(clampf((_upper_arm * _upper_arm + reach * reach - fore_length * fore_length) / (2.0 * _upper_arm * reach), -1.0, 1.0))
		var upper_direction := direction.rotated(bend_axis, angle)
		var elbow_at := from + upper_direction * _upper_arm
		var fore_direction := (from + direction * reach - elbow_at).normalized()

		var parent := (shoulder.get_parent() as Node3D).global_basis.orthonormalized()
		shoulder.basis = shoulder.basis.orthonormalized().slerp(parent.inverse() * _aim(upper_direction, forward), weight)
		var elbow := _elbows[i]
		var upper := shoulder.global_basis.orthonormalized()
		elbow.basis = elbow.basis.orthonormalized().slerp(upper.inverse() * _aim(fore_direction, forward), weight)


## Basis whose -Y axis points along `direction`, with +Z as near `ahead` as it can be.
static func _aim(direction: Vector3, ahead: Vector3) -> Basis:
	var y := -direction
	var x := y.cross(ahead)
	x = x.normalized() if x.length_squared() > 0.0001 else y.cross(Vector3.UP).normalized()
	return Basis(x, y, x.cross(y))
