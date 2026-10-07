class_name HoundRig
extends Node3D
## Drives the hound model (models/hound.glb) in code, the same way as the boy:
## paws follow a gait cycle and are placed with IK, and the spine, head and tail
## are layered on top. A trot at low speed becomes a gallop, where the back
## flexes and the hind legs land just ahead of the fore.
##
## The joint positions must match tools/build_character.py.

const MODEL := preload("res://models/hound.glb")
const BODY := Vector3(0.0, 0.54, 0.0)
const CHEST := Vector3(0.0, 0.02, 0.2)
const PELVIS := Vector3(0.0, 0.01, -0.22)
const HEAD := Vector3(0.0, 0.18, 0.24)
const TAIL := Vector3(0.0, 0.05, -0.14)
const LEG := 0.24
## Height of a planted paw's joint above the ground.
const PAW := 0.02
## Fore left, fore right, hind left, hind right.
const SUFFIXES: Array[String] = ["_fl", "_fr", "_rl", "_rr"]
const HIPS: Array[Vector3] = [
	Vector3(0.075, 0.5, 0.24), Vector3(-0.075, 0.5, 0.24),
	Vector3(0.065, 0.5, -0.26), Vector3(-0.065, 0.5, -0.26),
]
## Where in the cycle each leg lands.
const TROT: Array[float] = [0.0, 0.5, 0.5, 0.0]
const GALLOP: Array[float] = [0.5, 0.62, 0.0, 0.12]

var _hound: Hound
var _skeleton: Skeleton3D
var _joints: Array[Node3D] = []
var _bones: Array[int] = []
var _body: Node3D
var _chest: Node3D
var _pelvis: Node3D
var _head: Node3D
var _tail: Node3D
var _uppers: Array[Node3D] = []
var _lowers: Array[Node3D] = []
var _paws: Array[Node3D] = []

var _time := 0.0
var _phase := 0.0
var _run := 0.0
var _air := 0.0
var _crouch := 0.0
var _crouch_velocity := 0.0
var _bay := 0.0
var _was_grounded := true


func _ready() -> void:
	_build()
	_hound = get_parent() as Hound
	if _hound:
		_hound.bayed.connect(func() -> void: _bay = 1.0)
	_time = randf() * 10.0


func _process(delta: float) -> void:
	if _hound == null:
		return
	delta = minf(delta, 1.0 / 30.0)
	_time += delta
	var velocity := _hound.velocity
	var speed := Vector2(velocity.x, velocity.z).length()
	var grounded := _hound.is_on_floor()

	_run = _approach(_run, clampf(speed / _hound.run_speed, 0.0, 1.0), 8.0, delta)
	_air = _approach(_air, 0.0 if grounded else 1.0, 12.0, delta)
	_bay = _approach(_bay, 0.0, 4.0, delta)
	if grounded and not _was_grounded:
		_crouch_velocity += clampf(-velocity.y * 0.3 + 1.0, 1.0, 3.0)
	_was_grounded = grounded
	_crouch_velocity += (-_crouch * 240.0 - _crouch_velocity * 22.0) * delta
	_crouch = clampf(_crouch + _crouch_velocity * delta, -0.02, 0.16)

	var gallop := smoothstep(0.45, 0.75, _run)
	var stride := lerpf(0.6, 2.0, _run)
	var stance := lerpf(0.55, 0.32, _run)
	if grounded:
		_phase = fposmod(_phase + speed / stride * delta, 1.0)
	var gait := clampf(speed, 0.0, 1.0) * (1.0 - _air)

	# The back gathers and stretches once per gallop stride.
	var flex := sin(TAU * _phase) * gallop * gait
	var bob := -cos(TAU * 2.0 * _phase) * 0.012 * gait * (1.0 - gallop) + sin(TAU * _phase + 0.6) * 0.035 * gallop * gait
	var pitch := _air * clampf(-velocity.y * 0.04, -0.4, 0.4)
	_body.position = BODY + Vector3(0.0, -0.03 - 0.04 * _run - _crouch + bob, 0.0)
	_body.rotation = Vector3(pitch, 0.0, 0.0)
	_chest.rotation = Vector3(flex * 0.16, 0.0, 0.0)
	_pelvis.rotation = Vector3(-flex * 0.22, 0.0, 0.0)

	# Head stays on the quarry, and goes up to bay.
	var look := 0.0
	if _hound.target:
		var to := _hound.target.global_position - global_position
		look = clampf(angle_difference(rotation.y, atan2(to.x, to.z)), -0.7, 0.7)
	_head.rotation = Vector3(-flex * 0.16 - pitch * 0.6 - _bay * 0.75 + 0.1 * _run, look, 0.0)
	_tail.rotation = Vector3(0.25 + 0.5 * _run + _bay * 0.3, sin(_time * 9.0) * 0.22 * (0.4 + _run), 0.0)

	_pose_legs(velocity.y, stride, stance, gallop, gait)
	for i in _joints.size():
		_skeleton.set_bone_pose(_bones[i], _joints[i].transform)


func _pose_legs(vertical_speed: float, stride: float, stance: float, gallop: float, gait: float) -> void:
	var to_body := _body.transform.affine_inverse()
	var half_step := minf(stance * stride * 0.5, 0.2)
	var lift := lerpf(0.04, 0.13, _run)
	var rising := clampf(vertical_speed / 5.0, -1.0, 1.0) * 0.5 + 0.5
	for i in 4:
		var fore := i < 2
		var rest := HIPS[i]
		var cycle := _foot_cycle(fposmod(_phase + lerpf(TROT[i], GALLOP[i], gallop), 1.0), stance, half_step, lift)
		var target := Vector3(rest.x, PAW + cycle.y * gait, rest.z + cycle.z * gait)

		# In the air: stretched out going up, forelegs reaching for the landing coming down.
		var stretched := rest + Vector3(0.0, -0.34, 0.22 if fore else -0.24)
		var landing := rest + Vector3(0.0, -0.4 if fore else -0.3, 0.14 if fore else -0.06)
		target = target.lerp(landing.lerp(stretched, rising), _air)

		var spine := _chest if fore else _pelvis
		var hip := spine.transform * (rest - BODY - spine.position)
		_solve_leg(i, hip, to_body * target, to_body.basis * Basis(Vector3.RIGHT, lerpf(cycle.x * gait, 0.5, _air)))


## Paw path over a gait cycle. Returns (toe pitch, height, forward).
func _foot_cycle(phase: float, stance: float, half_step: float, lift: float) -> Vector3:
	if phase < stance:
		var planted := phase / stance
		return Vector3(smoothstep(0.6, 1.0, planted) * 0.6, 0.0, lerpf(half_step, -half_step, planted))
	var swing := (phase - stance) / (1.0 - stance)
	return Vector3(lerpf(0.7, -0.2, swing), sin(PI * pow(swing, 0.8)) * lift, lerpf(-half_step, half_step, smoothstep(0.0, 1.0, swing)))


## Two-bone IK in body space. Both pairs fold backwards: elbows and hocks.
func _solve_leg(index: int, hip: Vector3, target: Vector3, paw_basis: Basis) -> void:
	var to_target := target - hip
	var reach := clampf(to_target.length(), 0.1, LEG * 2.0 - 0.003)
	var direction := to_target.normalized() if to_target.length_squared() > 0.0001 else Vector3.DOWN
	var bend_axis := direction.cross(Vector3.FORWARD)
	bend_axis = bend_axis.normalized() if bend_axis.length_squared() > 0.0001 else Vector3.RIGHT
	var upper_direction := direction.rotated(bend_axis, acos(clampf(reach / (2.0 * LEG), -1.0, 1.0)))
	var knee := hip + upper_direction * LEG
	var wrist := hip + direction * reach
	_uppers[index].transform = Transform3D(_aim_down(upper_direction), hip)
	_lowers[index].transform = Transform3D(_aim_down((wrist - knee).normalized()), knee)
	_paws[index].transform = Transform3D(paw_basis, wrist)


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
	_body = _joint(self, &"body", BODY)
	_chest = _joint(_body, &"chest", CHEST)
	_pelvis = _joint(_body, &"pelvis", PELVIS)
	_head = _joint(_chest, &"head", HEAD)
	_tail = _joint(_pelvis, &"tail", TAIL)
	for i in 4:
		var hip := HIPS[i] - BODY
		_uppers.append(_joint(_body, "upper" + SUFFIXES[i], hip))
		_lowers.append(_joint(_body, "lower" + SUFFIXES[i], hip + Vector3.DOWN * LEG))
		_paws.append(_joint(_body, "paw" + SUFFIXES[i], hip + Vector3.DOWN * LEG * 2.0))


## Adds a pose node for a bone; its transform is copied to the skeleton each frame.
func _joint(parent: Node3D, bone: StringName, at: Vector3) -> Node3D:
	var joint := Node3D.new()
	joint.position = at
	parent.add_child(joint)
	_joints.append(joint)
	_bones.append(_skeleton.find_bone(bone))
	return joint
