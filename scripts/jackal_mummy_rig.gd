class_name JackalMummyRig
extends CanineRig
## Drives the mummified jackal (models/jackal_mummy*.glb) in code.
##
## It stands on the hound's rig (through CanineRig: see there for what is used
## from it unchanged), and where a hound sits and lies (`_measure`) is where
## this lies too. Everything else is its own, because the whole point of it is
## that it does NOT move as a living dog does:
##
## - Dormant, it lies as the black jackals lie on the shrines of Anubis: on its
##   chest, forelegs straight out in front, head up and level (`sphinx`); or
##   else stands as it was propped in its niche. Nothing in it moves. It does
##   not breathe.
## - Woken (`up`), it gets up the way a dog does, forequarters first and then
##   the hind, but in jerks, a third of the way at a time with a stop between,
##   shuddering, with its head hanging until last.
## - Its legs hardly bend. A paw is not swung through as a hound's is: it is
##   snatched up, thrown forward straight, held out there, and stabbed down
##   (`_stiff_cycle`). So its stride is short and quick, and it rides up over
##   each pair of legs and drops onto the next with a jolt, twice a stride. It
##   stalks at a walk and comes on at a trot. It has no gallop: it never
##   gathers and stretches its back, which stays a plank and is rocked and
##   twisted whole by the legs under it.
## - Its head is carried low, at the end of a neck stretched out in front, and
##   weaves from side to side in starts, like a snake's, with its jaw hanging.
##   The jaw clacks shut at each footfall of the trot.
## - Before it springs it sinks back onto its haunches with its jaw wide
##   (`crouched`): that is the warning. In the air it is a hound's leap, with
##   its ears laid back, and its jaws snap as it comes down (`snap`).
## - Its tail is a dead weight, and its loose ends of bandage are chains of
##   weights (class Strip, found from the bones named `drape_<name>_<k>`, as
##   the human mummies' are): they swing behind every movement, and trail.
## - The points of light in its eye sockets are out while it lies dormant, and
##   come up as it wakes.
##
## The JackalMummy says which of these (`up`, `sphinx`, `hunting`, `crouched`,
## `aim`); how each is done is all here.
##
## None of this is measured from anything, there being no such animal. The
## order of the feet at a walk and at a trot is the hound's (see HoundRig);
## how long each paw is down is a hound's stretched towards a lame dog's, which
## keeps its feet on the ground longer and swings them through faster.

const JACKAL_MODELS: Array = [preload("res://models/jackal_mummy.glb"), preload("res://models/jackal_mummy_lo.glb")]

## Where in the stride each paw lands (fore left, fore right, hind left, hind right): stalking, and at its trot.
const STALK: Array[float] = [0.25, 0.75, 0.0, 0.5]
const RATTLE: Array[float] = [0.5, 1.0, 0.0, 0.5]
## The share of the stride a paw is down, fore and hind, stalking and trotting.
const ON_FORE := Vector2(0.68, 0.47)
const ON_HIND := Vector2(0.66, 0.45)
## Speeds (m/s) over which the stalk gives way to the trot.
const RATTLE_AT := Vector2(1.1, 1.7)
## Length of a stride (m) against speed (m/s): short and quick.
const STEPS := [0.0, 0.34, 1.0, 0.60, 2.5, 0.84, 4.0, 1.04, 6.0, 1.3]
## The furthest a planted paw travels under the body (m, at `_size` 1): much
## less than a hound's, so that its legs stay nearly straight under it.
const STEP_REACH := 0.33
## How high a paw is snatched up (m), and how little of a hound's folding of a lifted leg there is.
const SNATCH := 0.05
const LEG_FOLD := 0.22
## How far the plank of its body is twisted and rolled by the legs under it (radians), and how far it is thrown up and dropped (m).
const TWIST := 0.055
const ROLL := 0.035
const JOLT := 0.017
## How far down its neck is turned, stretched out low in front of it (radians), and how far its head weaves (radians).
const NECK_LOW := 0.95
const WEAVE := 0.34
## How far its hips are let down when it lies (m).
const HIP_SINK := 0.085
## How far its jaw hangs as it comes (0..1 of GAPE), and how far it drops when it is about to spring.
const JAW_HANG := 0.2
const JAW_WIDE := 0.9
## The colour of the lights in its eyes: out, and lit.
const EYES_OUT := Color(0.02, 0.03, 0.02)
const EYES_LIT := Color(0.62, 1.0, 0.5)


## A loose strip of bandage: joints from where it is rooted to its tip, in the world.
class Strip:
	var bones := PackedInt32Array()
	var parent: Node3D
	## Where it roots, in that bone's space; and each link, as the way to the next joint.
	var origin := Vector3.ZERO
	var links := PackedVector3Array()
	var at := PackedVector3Array()
	var was := PackedVector3Array()
	## Whether it hangs from the trunk, which it is then kept out of.
	var on_trunk := false
	var settled := false


## Whether it is to be on its feet. The body sets this, and the rig gets it up or down.
var up := false
## Dormant, it lies like a sphinx; otherwise it stands.
var sphinx := true
## How long it takes to get up (s).
var rise_time := 1.7
## How much it is after something, 0..1: its head goes down and out, and weaves.
var hunting := 0.0
## It is gathering itself to spring.
var crouched := false
## What it is watching.
var aim: Node3D
## Whether it wears its gilded mask, and its collar. Call `dress()` after changing either.
var mask := false
var collar := false

var _strips: Array[Strip] = []
var _pelvis_rest := Vector3.ZERO
var _finery := {}
var _glow: StandardMaterial3D
## How far up it is, 0 dormant to 1; how far it has sunk back to spring; and how lit its eyes are.
var _risen := 0.0
var _gather := 0.0
var _lit := 0.0
## Its head: where it is weaving to, and how far it has got; and when it next starts.
var _weave := 0.0
var _weave_to := 0.0
var _weave_timer := 0.0
var _clack := 0.0
var _beat := 0


func _ready() -> void:
	_build()
	_beast = get_parent() as CharacterBody3D
	_time = randf() * 10.0
	_mirrored = randf() < 0.5
	_side = 1.0 if randf() < 0.5 else -1.0
	_last_yaw = rotation.y
	settle()


## How far up it is: 0 dormant, 1 on its feet.
func risen() -> float:
	return _risen


## Puts it as it is to be (`up`) at once, with nothing in motion: for when it is put somewhere.
func settle() -> void:
	_risen = 1.0 if up else 0.0
	_gather = 0.0
	_lit = _risen
	_flinched = 0.0
	_staggered = 0.0
	_pace = 0.0
	_links_settled = false
	for strip in _strips:
		strip.settled = false


## Its jaws snap: when it comes down on him.
func snap() -> void:
	_snapped = 0.0


## Shows the finery it is wearing, and hides the rest.
func dress() -> void:
	for piece: String in _finery:
		(_finery[piece] as Node3D).visible = mask if piece == "mask" else collar


func _process(delta: float) -> void:
	if _beast == null:
		return
	delta = minf(delta, 1.0 / 30.0)
	_time += delta
	var velocity := _beast.velocity
	var speed := Vector2(velocity.x, velocity.z).length()
	var grounded := _beast.is_on_floor()
	_turn = _approach(_turn, angle_difference(_last_yaw, rotation.y) / delta, 8.0, delta)
	_last_yaw = rotation.y
	_air = _approach(_air, 0.0 if grounded else 1.0, 14.0, delta)
	_snapped += delta
	_flinched = _approach(_flinched, 0.0, 3.2, delta)
	_staggered = _approach(_staggered, 0.0, 2.0, delta)
	# It is down far faster than it is up.
	_risen = move_toward(_risen, 1.0 if up else 0.0, delta / (rise_time if up else 0.5))
	_alert = _approach(_alert, hunting * _risen, 5.0, delta)
	_gather = _approach(_gather, 1.0 if crouched else 0.0, 13.0 if crouched else 7.0, delta)
	_lit = _approach(_lit, smoothstep(0.1, 0.6, _risen), 4.0, delta)
	# Getting up: its forequarters first, and then its hindquarters, each in three jerks.
	var lie := 1.0 - _ratchet(clampf(_risen / 0.5, 0.0, 1.0)) if sphinx else 0.0
	var sit := 1.0 - _ratchet(clampf((_risen - 0.44) / 0.56, 0.0, 1.0)) if sphinx else 0.0
	var down := maxf(sit, lie)
	var rising := sin(PI * _risen)

	# --- The gait. Turning on the spot it steps round, without going anywhere. ---
	_pace = _approach(_pace, maxf(speed, absf(_turn) * 0.2), 12.0, delta)
	var trot := smoothstep(RATTLE_AT.x, RATTLE_AT.y, _pace)
	var duty := Vector2(lerpf(ON_FORE.x, ON_FORE.y, trot), lerpf(ON_HIND.x, ON_HIND.y, trot))
	# (no stride is longer than lets its paws stay where they are put)
	var stride := minf(_keyed(STEPS, _pace), STEP_REACH * _size / duty.x)
	var before := _phase
	if grounded:
		_phase = fposmod(_phase + _pace / stride * delta, 1.0)
	var gait := smoothstep(0.05, 0.4, _pace) * (1.0 - _air) * (1.0 - down)
	var travel := clampf(speed / maxf(_pace, 0.05), 0.0, 1.0)
	var phases: Array[float] = []
	for i in 4:
		phases.append(lerpf(STALK[i], RATTLE[i], trot))
	var step := _stride_of(phases, duty, stride,
			Vector2(SNATCH, SNATCH * 0.85) * _size, Vector2(-0.02, 0.0), gait, travel, lerpf(1.0, 0.82, trot), 0.0, STEP_REACH, _stiff_cycle)
	var targets := step.targets
	var pitches := step.pitches
	_drop = _approach(_drop, step.drop + 0.002, 9.0, delta)
	# Each pair of legs comes down straight, and it is brought up short on them:
	# at its lowest as they land, and thrown up over them as they pass under it.
	var landing := absf(cos(TAU * _phase))
	var jolt := (1.0 - 2.0 * pow(landing, 0.7)) * JOLT * _size * gait * lerpf(0.5, 1.0, trot)
	# (each footfall of the trot shuts its jaw with a clack)
	if int(_phase * 2.0) != int(before * 2.0) and gait > 0.5:
		_beat += 1
		_clack = 1.0
	_clack = _approach(_clack, 0.0, 16.0, delta)
	# Its back is a plank. The legs under it twist it and roll it, whole.
	var twist := sin(TAU * _phase) * TWIST * gait
	var roll := sin(TAU * _phase + 1.1) * ROLL * gait
	var bend := clampf(_turn * 0.03, -0.12, 0.12) * (1.0 - down)
	var gather := smoothstep(0.0, 1.0, _gather) * (1.0 - _air)

	var air_pitch := _air * clampf(-velocity.y * 0.05, -0.45, 0.35)
	var body_at := _body_rest + Vector3(0.0, -_drop + jolt, 0.0)
	var body_turn := Vector3(air_pitch + 0.05 * _alert * (1.0 - down), twist, roll)
	var chest_turn := Vector3(0.0, bend, (targets[0].y - targets[1].y) * 0.4)
	var pelvis_turn := Vector3(0.0, -bend, (targets[2].y - targets[3].y) * 0.5)
	# Which way the first joint of each leg goes: the elbows back, the stifles forward.
	var poles: Array[Vector3] = [BEHIND, BEHIND, AHEAD, AHEAD]
	# How far the last bone of each leg is laid flat along the ground.
	var flat: Array[float] = [0.0, 0.0, 0.0, 0.0]

	# --- Lying as a sphinx, and what it passes through getting up: sitting. As a hound's (see HoundRig). ---
	if sit > 0.0:
		body_at = body_at.lerp(_sit_body, sit)
		body_turn = body_turn.lerp(Vector3(_sit_pitch, 0.0, 0.0), sit)
		chest_turn = chest_turn.lerp(Vector3(SIT_CHEST, 0.0, 0.0), sit)
		pelvis_turn = pelvis_turn.lerp(Vector3(SIT_PELVIS, 0.0, 0.0), sit)
		for i in 4:
			targets[i] = targets[i].lerp(_sit_paws[i], sit)
			pitches[i] *= 1.0 - sit
			if i >= 2:
				# The knees come up beside the belly, and out; the hocks go down flat.
				poles[i] = AHEAD.slerp(Vector3(signf(_hips[i].x) * 0.5, 0.6, 1.0).normalized(), sit)
				flat[i] = smoothstep(0.35, 0.9, sit)
	if lie > 0.0:
		body_at = body_at.lerp(_lie_body, lie)
		# (dead level, and square: it was laid out so)
		body_turn = body_turn.lerp(Vector3(-0.03, 0.0, 0.0), lie)
		chest_turn = chest_turn.lerp(Vector3.ZERO, lie)
		pelvis_turn = pelvis_turn.lerp(Vector3(0.12, 0.0, 0.0), lie)
		for i in 4:
			if i >= 2:
				# (its hind legs are folded close in beside it, not sprawled as a live dog's are)
				poles[i] = poles[i].slerp(Vector3(signf(_hips[i].x) * 0.16, -0.15, 1.0).normalized(), lie)
			else:
				# Down onto its elbows, and the forearms flat out in front.
				poles[i] = poles[i].slerp(Vector3(signf(_hips[i].x) * 0.06, -0.5, -1.0).normalized(), lie)
				flat[i] = smoothstep(0.3, 0.9, lie)
			targets[i] = targets[i].lerp(_lie_paws[i], lie)
	# Getting up it shudders, and its forelegs are braced wide.
	body_turn.z += sin(_time * 53.0) * 0.016 * rising
	body_at.x += sin(_time * 41.0) * 0.003 * rising
	# About to spring: back onto its haunches, chest down, every leg bent as far as it will go.
	if gather > 0.0:
		body_at += Vector3(0.0, -0.085, -0.075) * _size * gather
		body_turn.x += 0.16 * gather
		pelvis_turn.x -= 0.22 * gather
	# Hit, it is knocked over the way the blow went; shot, its hindquarters go from under it.
	body_at += Vector3(_flinch_way.x * 0.05, -0.04, _flinch_way.z * 0.03) * _flinched * _size
	body_at.y -= 0.09 * _staggered * _size
	body_turn.z -= _flinch_way.x * 0.3 * _flinched
	body_turn.x -= 0.22 * _staggered
	chest_turn.y += _flinch_way.x * 0.3 * _flinched
	pelvis_turn.x -= 0.3 * _staggered
	_body.position = body_at
	_body.rotation = body_turn
	_chest.rotation = chest_turn
	_pelvis.rotation = pelvis_turn
	# (lying, its hips are let down between its folded legs, so that its back is level and not a ramp)
	_pelvis.position = _pelvis_rest + Vector3(0.0, -HIP_SINK * _size * lie, 0.0)
	_pose_skull(delta, body_turn.x + chest_turn.x, down, gather)
	_place_legs(targets, pitches, poles, flat, velocity.y, LEG_FOLD)
	_hold_tail(trot * gait)
	_hold_ears()
	for i in _joints.size():
		_skeleton.set_bone_pose(_bones[i], _joints[i].transform)
	_swing(delta)
	_hang_strips(delta)
	if _glow:
		# (they gutter)
		_glow.albedo_color = EYES_OUT.lerp(EYES_LIT, _lit * (0.85 + 0.15 * sin(_time * 23.0) * sin(_time * 7.1)))


## Goes a third of the way at a time, quickly, and stops between: how something moves whose joints have set.
static func _ratchet(share: float, jerks := 3) -> float:
	var at := share * jerks
	return (floorf(at) + smoothstep(0.0, 0.55, at - floorf(at))) / jerks


## The path of a paw on a leg that no longer bends as it did. Returns (toe
## pitch, height, forward), as `_foot_cycle`. On the ground it is carried back
## under the body as a hound's is. Then it is snatched up, thrown forward
## straight in the first part of its time in the air, held out there, and
## stabbed down.
func _stiff_cycle(phase: float, duty: float, half_step: float, lift: float) -> Vector3:
	if phase < duty:
		var planted := phase / duty
		return Vector3(smoothstep(0.75, 1.0, planted) * 0.3, 0.0, lerpf(half_step, -half_step, planted))
	var swing := (phase - duty) / (1.0 - duty)
	var thrown := smoothstep(0.0, 0.7, swing)
	return Vector3(lerpf(0.3, -0.28, thrown) * (1.0 - smoothstep(0.85, 1.0, swing)), smoothstep(0.0, 0.22, swing) * (1.0 - smoothstep(0.72, 1.0, swing)) * lift,
			lerpf(-half_step, half_step, thrown))


## Its neck, its head and its jaw. Dormant, the head is up and level and the jaw
## shut. After something, the neck goes down and out and the head weaves on the
## end of it, in starts; getting up, it hangs.
func _pose_skull(delta: float, upstream: float, down: float, gather: float) -> void:
	# What it is watching, if anything
	var yaw := 0.0
	var pitch := 0.0
	if is_instance_valid(aim) and _risen > 0.5:
		# (from where its head is carried, not from where it is this moment: or it would chase its own turning)
		var to := aim.global_position + Vector3.UP * (0.9 if aim is Player else 0.3) - (global_position + Vector3.UP * 0.6 * _size)
		if Vector2(to.x, to.z).length() < 0.5:
			to = global_basis.z
		yaw = clampf(angle_difference(rotation.y, atan2(to.x, to.z)), -1.3, 1.3)
		pitch = clampf(-atan2(to.y, Vector2(to.x, to.z).length()), -0.7, 0.3)
	_look = _look.lerp(Vector2(yaw, pitch) * _alert, 1.0 - exp(-9.0 * delta))
	# The weave: it goes over to one side or the other, all at once, and waits there.
	_weave_timer -= delta
	if _weave_timer <= 0.0:
		_weave_timer = randf_range(0.16, 0.5)
		_weave_to = randf_range(0.35, 1.0) * (-1.0 if _weave_to > 0.0 else 1.0)
		_tilt_to = randf_range(-0.25, 0.25)
	var loose := _alert * (1.0 - gather) * (1.0 - _air)
	_weave = _approach(_weave, _weave_to, 16.0, delta)
	_tilt = _approach(_tilt, _tilt_to * maxf(loose, sin(PI * _risen)), 12.0, delta)
	var weave := _weave * WEAVE * loose
	# How far down the neck is: out low when it is after him, lower to spring, up in the air, and hanging as it gets up.
	var hang := sin(PI * smoothstep(0.1, 0.95, _risen)) * (1.0 if sphinx else 0.5)
	var low := NECK_LOW * maxf(_alert * (1.0 - 0.45 * _air), hang * 0.8) + 0.12 * gather + 0.4 * maxf(_flinched, _staggered)
	var turn := _look.x + weave
	_neck.rotation = Vector3(low * 0.55 - upstream * 0.5, turn * 0.3, 0.0)
	_neck_1.rotation = Vector3(low * 0.45, turn * 0.3, 0.0)
	# The head is brought most of the way back up, so that it looks along the ground at him; and it goes the other way to the neck under it.
	_head.rotation = Vector3(-low * 0.72 - upstream * 0.5 + _look.y * 0.8 + 0.3 * hang - 0.2 * gather, _look.x * 0.4 - weave * 0.5, _tilt)
	_chest.rotation.y += turn * 0.06 * (1.0 - down)
	# The jaw: hanging as it comes, clacking shut at each footfall, wide before it springs and in the air, and snapping after.
	var open := JAW_HANG * _alert * (1.0 - 0.8 * _clack) + 0.12 * hang
	open = maxf(open, JAW_WIDE * maxf(gather, _air * 0.9))
	if _snapped < 1.0:
		open = _keyed(SNAP, _snapped)
	_mouth = lerpf(_mouth, open, 0.6)
	_jaw.rotation.x = _mouth * GAPE


## Its tail: a dead weight, hanging, and left behind by whatever the rest of it does.
func _hold_tail(going: float) -> void:
	for i in _tail.size():
		var link := _tail[i]
		link.aim = Basis(Vector3.RIGHT, 0.25 * going + 0.5 * _air if i == 0 else 0.0) * link.rest


## Its ears: up, and stiff; laid back when it springs or is hit.
func _hold_ears() -> void:
	var back := maxf(maxf(_air, _gather * 0.6), maxf(_flinched, _staggered))
	_ear_flat = lerpf(_ear_flat, back, 0.3)
	for side in 2:
		var out := 1.0 if side == 0 else -1.0
		var root: Link = _ears[side][0]
		var flap: Link = _ears[side][1]
		root.aim = Basis(Vector3.RIGHT, -_ear_flat * 0.9) * Basis(BEHIND, out * _ear_flat * 0.25) * root.rest
		flap.aim = Basis(Vector3.RIGHT, -_ear_flat * 0.2) * flap.rest


func _build() -> void:
	var low := low_poly or Settings.low_poly
	_build_on(JACKAL_MODELS[1 if low else 0])
	Toon.apply(_model)
	for part: MeshInstance3D in _model.find_children("*", "MeshInstance3D", true, false):
		for piece: String in ["mask", "collar"]:
			if String(part.name).ends_with("_" + piece):
				_finery[piece] = part
		for surface in part.mesh.get_surface_count():
			var original := part.mesh.surface_get_material(surface) as StandardMaterial3D
			if original and original.resource_name == "glow":
				# The lights in its eyes: not lit by anything, and the same in the dark.
				if _glow == null:
					_glow = StandardMaterial3D.new()
					_glow.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
					_glow.albedo_color = EYES_OUT
				part.set_surface_override_material(surface, _glow)
			elif original and original.resource_name == "gold":
				part.set_surface_override_material(surface, Toon.gold(original.albedo_color))
	_pelvis_rest = _pelvis.position
	_measure()
	# It lies lower and squarer than a live dog: right down on its chest, its hind paws drawn up beside its belly.
	_lie_body.y -= 0.028 * _size
	for i in [2, 3]:
		_lie_paws[i].z += 0.05 * _size
		_lie_paws[i].x = _paws[i].x * 1.25
	# The tail hangs, and swings like a rope; the ears are stiff.
	_hang_tail(Vector2(260.0, 70.0), Vector2(14.0, 7.0), 9.0, 1.1)
	_stand_ears()
	_find_strips()
	dress()


# --- Loose ends ---

func _find_strips() -> void:
	var joints := {}
	for i in _joints.size():
		joints[_bones[i]] = _joints[i]
	for bone in _skeleton.get_bone_count():
		var called := _skeleton.get_bone_name(bone)
		var parent := _skeleton.get_bone_parent(bone)
		if not called.begins_with("drape_") or not called.ends_with("_0") or not joints.has(parent):
			continue
		var strip := Strip.new()
		strip.parent = joints[parent]
		strip.on_trunk = strip.parent == _chest or strip.parent == _pelvis
		strip.origin = _skeleton.get_bone_rest(bone).origin
		# (the last bone of each only marks where it ends)
		var at := bone
		while not _skeleton.get_bone_children(at).is_empty():
			var next := _skeleton.get_bone_children(at)[0]
			strip.bones.append(at)
			strip.links.append(_skeleton.get_bone_rest(next).origin)
			at = next
		if strip.bones.is_empty():
			continue
		strip.at.resize(strip.bones.size() + 1)
		strip.was.resize(strip.bones.size() + 1)
		_strips.append(strip)


## Swings the loose ends, as MummyRig does a mummy's. Each joint keeps going
## the way it was going, is pulled down and slowed by the air; then each link
## is brought back to its length from the root down, lifted off the ground and
## pushed out of the trunk; and the bones are turned to lie along the links.
func _hang_strips(delta: float) -> void:
	var ground := global_position.y + 0.012
	var from := _pelvis.global_position
	var line := _chest.global_position - from
	var round := 0.062 * _size
	for strip in _strips:
		var frame := strip.parent.global_basis.orthonormalized()
		var root := strip.parent.global_transform * strip.origin
		var count := strip.bones.size()
		if not strip.settled or root.distance_to(strip.at[0]) > 1.5:
			# Put somewhere new: it starts as it was made, and at rest.
			var joint := root
			for k in count + 1:
				strip.at[k] = joint
				strip.was[k] = joint
				if k < count:
					joint += frame * strip.links[k]
			strip.settled = true
		strip.at[0] = root
		for k in range(1, count + 1):
			var here := strip.at[k]
			var moving := (here - strip.was[k]) * exp(-1.6 * delta)
			# (what is lying on the ground is held by it)
			if here.y <= ground + 0.002:
				moving *= exp(-9.0 * delta)
			strip.was[k] = here
			strip.at[k] = here + moving + Vector3.DOWN * 9.0 * delta * delta
		for pass_index in 3:
			for k in range(1, count + 1):
				var length := strip.links[k - 1].length()
				var along := strip.at[k] - strip.at[k - 1]
				strip.at[k] = strip.at[k - 1] + (along.normalized() if along.length_squared() > 0.000001 else Vector3.DOWN) * length
				if strip.at[k].y < ground:
					strip.at[k] = Vector3(strip.at[k].x, ground, strip.at[k].z)
				if strip.on_trunk:
					var nearest := from + line * clampf((strip.at[k] - from).dot(line) / maxf(line.length_squared(), 0.000001), 0.0, 1.0)
					var out := strip.at[k] - nearest
					if out.length_squared() < round * round:
						strip.at[k] = nearest + (out.normalized() if out.length_squared() > 0.000001 else frame.x) * round
		# Each bone is turned, from how the one above it lies, to point down its link.
		var above := frame
		for k in count:
			var rest := strip.links[k].normalized()
			var lies := (above * rest).normalized()
			var wants := (strip.at[k + 1] - strip.at[k]).normalized()
			var turn := Basis.IDENTITY
			if lies.dot(wants) < -0.9999:
				turn = Basis(above.x.normalized(), PI)
			elif lies.dot(wants) < 0.9999:
				turn = Basis(Quaternion(lies, wants))
			var now := (turn * above).orthonormalized()
			_skeleton.set_bone_pose(strip.bones[k], Transform3D(above.inverse() * now, strip.origin if k == 0 else strip.links[k - 1]))
			above = now
