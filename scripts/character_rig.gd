class_name CharacterRig
extends Node3D
## Drives the character model (models/boy.glb) entirely in code.
##
## There are no clips: the gait is driven by distance travelled so feet do not
## slide, legs are placed with two-bone IK, and everything else (lean, twist,
## arm swing, landing crouch) is layered on with springs. The model faces +Z,
## and its bones all rest unrotated (see tools/build_character.py), so a bone's
## pose is simply its transform relative to its parent bone.

const HIP_HEIGHT := 0.685
const HIP_HALF_WIDTH := 0.075
const THIGH := 0.32
const SHIN := 0.32
const ANKLE := 0.05
const UPPER_ARM := 0.2
const FOREARM := 0.2
## How far out the model's arms are held at rest (tools/build_character.py).
const ARM_REST := 0.22
const MODEL := preload("res://models/boy.glb")


var _player: Player
var _hips: Node3D
var _spine: Node3D
var _head: Node3D
var _thighs: Array[Node3D] = []
var _shins: Array[Node3D] = []
var _feet: Array[Node3D] = []
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


func _ready() -> void:
	_build()
	_player = get_parent() as Player
	if _player:
		_player.jumped.connect(_on_jumped)
		_player.landed.connect(_on_landed)
		_player.respawned.connect(_on_respawned)
	_prev_yaw = rotation.y


func _process(delta: float) -> void:
	if _player == null:
		return
	delta = minf(delta, 1.0 / 30.0)
	_time += delta

	var velocity := _player.velocity
	var flat := Vector3(velocity.x, 0.0, velocity.z)
	var speed := flat.length()
	var grounded := _player.is_on_floor()

	_move = _approach(_move, clampf(speed / _player.walk_speed, 0.0, 1.0), 10.0, delta)
	_run = _approach(_run, clampf(inverse_lerp(_player.walk_speed, _player.run_speed, speed), 0.0, 1.0), 8.0, delta)
	_air = _approach(_air, 0.0 if grounded else 1.0, 16.0 if grounded else 10.0, delta)
	_push = _approach(_push, 1.0 if _player.is_pushing else 0.0, 8.0, delta)

	_accel = _accel.lerp((flat - _prev_velocity) / delta, 1.0 - exp(-8.0 * delta))
	_yaw_rate = lerpf(_yaw_rate, angle_difference(_prev_yaw, rotation.y) / delta, 1.0 - exp(-10.0 * delta))
	_prev_velocity = flat
	_prev_yaw = rotation.y

	# Landing and take-off kick this spring; it settles back on its own.
	_crouch_velocity += ((_push * 0.05 - _crouch) * 220.0 - _crouch_velocity * 22.0) * delta
	_crouch = clampf(_crouch + _crouch_velocity * delta, -0.03, 0.3)

	# One cycle is two steps. Advancing by distance keeps planted feet planted.
	var stride := lerpf(0.95, 2.1, _run)
	var stance := lerpf(0.6, 0.36, _run)
	if grounded:
		_phase = fposmod(_phase + speed / stride * delta, 1.0)
	var gait := _move * (1.0 - _air)

	_pose_body(speed, velocity.y, stance, gait)
	_pose_legs(velocity.y, stride, stance, gait)
	_pose_arms(velocity.y, gait)
	_apply_pose()


func _pose_body(speed: float, vertical_speed: float, stance: float, gait: float) -> void:
	var forward := global_basis.z
	var pitch := _run * 0.2 + _move * 0.03 + clampf(_accel.dot(forward) * 0.012, -0.2, 0.2)
	pitch += _push * 0.36 + _air * clampf(-vertical_speed * 0.02, -0.08, 0.16)
	var roll := clampf(-_yaw_rate * speed * 0.012, -0.22, 0.22)
	_lean = _lean.lerp(Vector2(pitch, roll), 1.0 - exp(-9.0 * get_process_delta_time()))

	# Lowest at mid-stance, twice per cycle.
	var bob := -cos(TAU * 2.0 * (_phase - stance * 0.5)) * lerpf(0.012, 0.035, _run) * gait
	var breath := sin(_time * 1.7)
	var sway := cos(TAU * (_phase - stance * 0.5)) * 0.014 * gait * (1.0 - _run * 0.5)
	var twist := -cos(TAU * _phase) * lerpf(0.1, 0.17, _run) * gait

	_hips.position = Vector3(sway, HIP_HEIGHT - _run * 0.07 - _crouch + bob + breath * 0.003 * (1.0 - _move), 0.0)
	_hips.rotation = Vector3(_lean.x * 0.35 + _crouch * 0.8, twist, _lean.y)
	_spine.rotation = Vector3(_lean.x * 0.65 + breath * 0.012 + _crouch * 0.9, -twist * 1.8, _lean.y * 0.5)
	# The head stays level and looks where the body is going.
	_head.rotation = Vector3(-_lean.x * 0.7 - _crouch * 1.2, twist * 0.8 + clampf(_yaw_rate * 0.04, -0.4, 0.4), -_lean.y * 0.9)


func _pose_legs(vertical_speed: float, stride: float, stance: float, gait: float) -> void:
	var to_hips := _hips.transform.affine_inverse()
	var half_step := stance * stride * 0.5
	var lift := lerpf(0.07, 0.2, _run)
	var rising := clampf(vertical_speed / 5.0, -1.0, 1.0) * 0.5 + 0.5
	for i in 2:
		var side := 1.0 if i == 0 else -1.0
		var cycle := _foot_cycle(fposmod(_phase + 0.5 * i, 1.0), stance, half_step, lift)
		var target := Vector3(side * HIP_HALF_WIDTH, ANKLE + cycle.y * gait, cycle.z * gait)
		var pitch := cycle.x * gait

		# Airborne: knees tuck on the way up, legs reach for the ground on the way down.
		var lead := i == _lead_leg
		var tucked := Vector3(side * HIP_HALF_WIDTH, 0.3 if lead else 0.14, 0.17 if lead else -0.15)
		var reaching := Vector3(side * (HIP_HALF_WIDTH + 0.02), 0.09 if lead else 0.04, 0.1 if lead else -0.07)
		reaching.z += sin(_time * 9.0 + i * PI) * 0.03
		target = target.lerp(reaching.lerp(tucked, rising), _air)
		pitch = lerpf(pitch, 0.45, _air)

		_solve_leg(i, side, to_hips * target, to_hips.basis * Basis(Vector3.RIGHT, pitch))


## Foot path for one leg over a gait cycle. Returns (toe pitch, height, forward).
func _foot_cycle(phase: float, stance: float, half_step: float, lift: float) -> Vector3:
	if phase < stance:
		# Planted: carried backwards under the body, rolling heel to toe.
		var t := phase / stance
		var roll := smoothstep(0.65, 1.0, t) * 0.55 - (1.0 - smoothstep(0.0, 0.2, t)) * 0.25
		return Vector3(roll, 0.0, lerpf(half_step, -half_step, t))
	# Swinging forward. Peaking early gives the heel a kick behind the body.
	var t := (phase - stance) / (1.0 - stance)
	var height := sin(PI * pow(t, 0.75)) * lift
	var toe := lerpf(0.55, -0.25, t) + sin(PI * t) * 0.5 * _run
	return Vector3(toe, height, lerpf(-half_step, half_step, smoothstep(0.0, 1.0, t)))


## Two-bone IK in hip space, knee bending forward.
func _solve_leg(index: int, side: float, target: Vector3, foot_basis: Basis) -> void:
	var hip := Vector3(side * HIP_HALF_WIDTH, -0.02, 0.0)
	var to_target := target - hip
	var reach := clampf(to_target.length(), 0.1, THIGH + SHIN - 0.004)
	var direction := to_target.normalized() if to_target.length_squared() > 0.0001 else Vector3.DOWN
	var bend_axis := direction.cross(Vector3.BACK)
	bend_axis = bend_axis.normalized() if bend_axis.length_squared() > 0.0001 else Vector3.LEFT
	var hip_angle := acos(clampf((THIGH * THIGH + reach * reach - SHIN * SHIN) / (2.0 * THIGH * reach), -1.0, 1.0))
	var thigh_direction := direction.rotated(bend_axis, hip_angle)
	var knee := hip + thigh_direction * THIGH
	var ankle := hip + direction * reach
	_thighs[index].transform = Transform3D(_aim_down(thigh_direction), hip)
	_shins[index].transform = Transform3D(_aim_down((ankle - knee).normalized()), knee)
	_feet[index].transform = Transform3D(foot_basis, ankle)


func _pose_arms(vertical_speed: float, gait: float) -> void:
	var rising := clampf(vertical_speed / 5.0, -1.0, 1.0) * 0.5 + 0.5
	for i in 2:
		var side := 1.0 if i == 0 else -1.0
		# Opposite to the leg on the same side. Negative pitch is forward.
		var swing := side * cos(TAU * _phase) * lerpf(0.35, 0.9, _run) * gait
		var pitch := swing + 0.05
		var roll := side * 0.09
		var elbow := -(0.14 + lerpf(0.12, 1.3, _run) * gait + maxf(-swing, 0.0) * 0.4)

		var flail := sin(_time * 10.0 + i * 2.1) * 0.14
		var air_pitch := lerpf(-0.35 + flail, -0.7 if i == _lead_leg else 0.5, rising)
		var air_roll := side * lerpf(1.05 + flail, 0.3, rising)
		pitch = lerpf(pitch, air_pitch, _air)
		roll = lerpf(roll, air_roll, _air)
		elbow = lerpf(elbow, lerpf(-0.45, -1.0, rising), _air)

		pitch = lerpf(pitch, -1.3, _push)
		roll = lerpf(roll, -side * 0.06, _push)
		elbow = lerpf(elbow, -0.4, _push)

		_shoulders[i].rotation = Vector3(pitch, 0.0, roll)
		_elbows[i].rotation = Vector3(elbow, 0.0, 0.0)


func _on_jumped() -> void:
	_crouch_velocity -= 1.2
	# Tuck whichever leg is already swinging forward.
	_lead_leg = 1 if _phase < 0.5 else 0


func _on_landed(impact_speed: float) -> void:
	_crouch_velocity += clampf(impact_speed * 0.5, 0.6, 7.0)


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
	var model := MODEL.instantiate()
	add_child(model)
	_skeleton = model.find_children("*", "Skeleton3D", true, false)[0]

	_hips = _joint(self, &"hips", Vector3(0.0, HIP_HEIGHT, 0.0))
	_spine = _joint(_hips, &"spine", Vector3(0.0, 0.03, 0.0))
	_head = _joint(_spine, &"head", Vector3(0.0, 0.35, 0.0))
	for suffix: String in ["_l", "_r"]:
		var side := 1.0 if suffix == "_l" else -1.0
		var shoulder := _joint(_spine, "upper_arm" + suffix, Vector3(side * 0.14, 0.28, 0.0))
		_shoulders.append(shoulder)
		_elbows.append(_joint(shoulder, "forearm" + suffix, Vector3(0.0, -UPPER_ARM, 0.0)))
		var hip := Vector3(side * HIP_HALF_WIDTH, -0.02, 0.0)
		_thighs.append(_joint(_hips, "thigh" + suffix, hip))
		_shins.append(_joint(_hips, "shin" + suffix, hip + Vector3.DOWN * THIGH))
		_feet.append(_joint(_hips, "foot" + suffix, hip + Vector3.DOWN * (THIGH + SHIN)))


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
		var rest := Basis(Vector3.BACK, (1.0 if i == 0 else -1.0) * ARM_REST)
		var shoulder := _shoulders[i].transform
		var elbow := _elbows[i].transform
		_skeleton.set_bone_pose(_bones[_joints.find(_shoulders[i])], Transform3D(shoulder.basis * rest.inverse(), shoulder.origin))
		_skeleton.set_bone_pose(_bones[_joints.find(_elbows[i])], Transform3D(rest * elbow.basis * rest.inverse(), rest * elbow.origin))
