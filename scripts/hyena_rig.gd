class_name HyenaRig
extends CanineRig
## Drives the striped hyena (models/hyena*.glb) in code.
##
## It stands on the hound's rig (through CanineRig: see there for what is used
## from it unchanged), and also uses the hound's breathing (`_breathe`), its
## ears that turn to listen and lie back (`_carry_ears`) and its voice opening
## its mouth (`_voice_open`). Everything that makes it a hyena is here:
##
## - Its build does half of it: the forelegs are longer than the hind legs, so
##   its back slopes, and every gait is carried on high shoulders over low
##   hindquarters.
## - It walks as a dog walks (each hind paw landing a quarter of a stride
##   before the fore paw of its own side), but shuffling: its paws are hardly
##   lifted, its head is low and nods, and it swings from side to side.
## - Faster, it does not trot. It LOPES: a slow, rolling canter of three beats
##   (one hind paw; then the other hind paw and the fore paw across from it,
##   together; then the last fore paw, which leads), and one moment in the air
##   after the leading fore paw. Its body rocks through every stride like a
##   rocking horse, nose down onto the forelegs and up again over the hind,
##   with its rump tucked under it. That it can keep up for hours.
## - Flat out (it only does it to get away) the lope opens into a gallop.
## - The mane: three bones (`crest_neck`, `crest_chest`, `crest_pelvis`) carry
##   the tips of its locks. Raised (`bristle`), they are lifted up and forward,
##   which stands the whole mane on end and makes it half as tall again; and
##   its tail goes up with it.
## - Frightened (`afraid`), it goes low behind, its tail is clamped down and
##   its ears lie back.
##
## The Hyena says which of these (`bristle`, `afraid`, `gaze`, `sniffing`); how
## each is done is all here.
##
## What it follows:
## - Its build, its mane and that it is raised: en.wikipedia.org/wiki/Striped_hyena
##   (hind legs "significantly shorter" than the fore, the back sloping; the
##   mane, of hairs 15 to 22 cm long, erected when it is roused).
## - The lope: hyenas "lope", a slow canter kept up over long distances; the
##   spotted hyena's is given as about 10 km/h (en.wikipedia.org/wiki/Spotted_hyena).
##   3.2 m/s here is 11.5 km/h. The order of the feet in a canter (hind, the
##   diagonal pair, the leading fore, a suspension) is the ordinary one of any
##   cantering animal (en.wikipedia.org/wiki/Canter_and_gallop).
## - Where the walk gives way to the lope is put, as the hound's changes are,
##   by the Froude number (about 0.5): for a leg of 0.6 m, about 1.7 m/s.
##
## What is NOT measured, and is only chosen to look right: how long each paw is
## down, how far it rocks, and everything about its head, mane and tail.

const HYENA_MODELS: Array = [preload("res://models/hyena.glb"), preload("res://models/hyena_lo.glb")]

## Where in the stride each paw lands (fore left, fore right, hind left, hind right).
## Walk: left hind, left fore, right hind, right fore, a quarter apart.
const SHUFFLE: Array[float] = [0.25, 0.75, 0.0, 0.5]
## Lope: the right hind; the left hind and the right fore together; the left fore, which leads.
const LOPE: Array[float] = [0.47, 0.25, 0.25, 0.0]
## Flat out: the hound's gallop.
const BOLT: Array[float] = [0.6, 0.5, 0.0, 0.1]
## The share of the stride a paw is down, fore and hind, walking, loping and flat out.
const DOWN_FORE := Vector3(0.64, 0.36, 0.22)
const DOWN_HIND := Vector3(0.62, 0.34, 0.20)
## Speeds (m/s) over which the walk gives way to the lope, and the lope to the gallop.
const LOPE_AT := Vector2(1.4, 2.0)
const BOLT_AT := Vector2(5.0, 6.2)
## Length of a stride (m) against speed (m/s).
const PACES := [0.0, 0.5, 1.0, 0.82, 2.2, 1.3, 3.2, 1.55, 5.0, 2.0, 7.0, 2.6, 9.0, 3.0]
## The furthest a planted paw travels under the body (m, at `_size` 1). No
## stride is longer than lets its paws stay where they are put.
const PAW_REACH := 0.56
## The middle of the lope's one moment in the air, as a share of the stride,
## how high it throws it (m), and how far it rocks (radians).
const ALOFT := 0.91
const SPRING := 0.035
const ROCK := 0.085
## How far its rump is tucked under it as it lopes (radians).
const TUCK := 0.10
## How far the bones of the mane are lifted to stand it up (m: up, and forward along the back).
const CREST_RISE := Vector3(0.0, 0.085, 0.075)
## How far down its neck is turned to put its nose to the ground (radians).
const NECK_DOWN := 0.95

## How far its mane is to be raised, 0..1.
var bristle := 0.0
## How frightened it is, 0..1.
var afraid := 0.0
## What its head is turned to.
var gaze: Node3D
## Its nose is down, at something on the ground.
var sniffing := false
## How fast it goes flat out (m/s): what it measures being out of breath by.
var top_speed := 7.0

var _crests: Array[Node3D] = []
var _crest_rest: Array[Vector3] = []
var _crest := 0.0
var _sniff := 0.0
var _lean := 0.0
## How far into the lope it is from the walk, and into the gallop from the lope, 0..1.
var _loping := 0.0
var _bolting := 0.0


func _ready() -> void:
	_build()
	_beast = get_parent() as CharacterBody3D
	_time = randf() * 10.0
	_mirrored = randf() < 0.5
	_last_yaw = rotation.y


## It has opened its mouth: the jaw keeps time with what it says, as a hound's does.
func speak(rate: float, length: float, envelope: PackedFloat32Array) -> void:
	_voiced = 0.0
	_voice_rate = rate
	_voice_length = length
	_envelope = envelope
	_barked = true


## How far its mane is up, 0..1.
func crest() -> float:
	return _crest


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
	_air = _approach(_air, 0.0 if grounded else 1.0, 12.0, delta)
	_voiced += delta * _voice_rate
	_snapped += delta
	_flinched = _approach(_flinched, 0.0, 3.2, delta)
	_staggered = _approach(_staggered, 0.0, 2.0, delta)
	_cowed = _approach(_cowed, afraid, 5.0, delta)
	_alert = _approach(_alert, 1.0 if is_instance_valid(gaze) else 0.0, 3.0, delta)
	# (its mane is up in a moment, and goes down slowly)
	_crest = _approach(_crest, bristle, 9.0 if bristle > _crest else 1.6, delta)
	_sniff = _approach(_sniff, 1.0 if sniffing else 0.0, 2.6, delta)
	_puffed = clampf(_puffed + (speed / top_speed * 0.3 - 0.07) * delta, 0.0, 1.0)

	# --- The gait. Turning on the spot it steps round, without going anywhere. ---
	_pace = _approach(_pace, maxf(speed, absf(_turn) * 0.25), 9.0, delta)
	# (it changes from one gait to the next over a stride or so, however suddenly it changes its speed:
	# the order of its feet cannot be changed in an instant)
	_loping = move_toward(_loping, smoothstep(LOPE_AT.x, LOPE_AT.y, _pace), delta * 2.6)
	_bolting = move_toward(_bolting, smoothstep(BOLT_AT.x, BOLT_AT.y, _pace), delta * 2.6)
	var lope := _loping
	var bolt := _bolting
	var duty := Vector2(lerpf(lerpf(DOWN_FORE.x, DOWN_FORE.y, lope), DOWN_FORE.z, bolt), lerpf(lerpf(DOWN_HIND.x, DOWN_HIND.y, lope), DOWN_HIND.z, bolt))
	var stride := minf(_keyed(PACES, _pace), PAW_REACH * _size / duty.x)
	if grounded:
		_phase = fposmod(_phase + _pace / stride * delta, 1.0)
	var gait := smoothstep(0.05, 0.45, _pace) * (1.0 - _air)
	var travel := clampf(speed / maxf(_pace, 0.05), 0.0, 1.0)
	var phases: Array[float] = []
	for i in 4:
		phases.append(lerpf(lerpf(SHUFFLE[i], LOPE[i], lope), BOLT[i], bolt))
	# Shuffling, its paws hardly leave the ground; loping they are picked up, the hind ones less.
	var lift := lerpf(lerpf(0.035, 0.09, lope), 0.16, bolt) * _size
	# The lope throws it clear of the ground once a stride, after the leading foreleg; the gallop twice.
	var loping := lope * (1.0 - bolt) * gait
	var flying := bolt * gait
	var rise := maxf(cos(TAU * (_phase - ALOFT)), -0.3) * SPRING * _size * loping + (0.25 + cos(2.0 * TAU * (_phase - FLIGHT))) * BOUND * _size * flying
	# (its hind paws come down well forward under it, which is what keeps its rump low)
	var step := _stride_of(phases, duty, stride, Vector2(lift, lift * 0.7), Vector2(lerpf(-0.03, 0.03, lope), lerpf(-0.01, 0.06, lope)) * _size, gait, travel,
			lerpf(1.0, 0.78, lope * gait), rise, PAW_REACH)
	var targets := step.targets
	var pitches := step.pitches
	_drop = _approach(_drop, step.drop + 0.004, 9.0, delta)

	# Walking, each end of it rides up over its legs as they pass under it, and it
	# swings over onto the side that is carrying it.
	var vault := 0.016 * (1.0 - lope) * _size
	var high_fore := (step.load_fore - 0.7) * vault * gait
	var high_hind := (step.load_hind - 0.7) * vault * gait
	_lean = _approach(_lean, clampf(step.load_side * 0.5, -1.0, 1.0), 10.0, delta)
	var sway := _lean * 0.016 * _size * gait * (1.0 - lope)
	var roll := _lean * 0.03 * gait * (1.0 - lope)
	# Loping, it rocks: nose up as the hind legs come under it, down onto the forelegs.
	var rock := (high_hind - high_fore) / 0.6 - cos(TAU * (_phase - 0.1)) * ROCK * loping + sin(TAU * (_phase - FLIGHT)) * 0.07 * flying
	var gather := cos(TAU * (_phase - FLIGHT - 0.5)) * flying + cos(TAU * (_phase - ALOFT)) * 0.45 * loping
	var bend := clampf(_turn * 0.06, -0.3, 0.3)
	var swing_fore := (targets[1].z - targets[0].z) * 0.2 * (1.0 - bolt)
	var swing_hind := (targets[3].z - targets[2].z) * 0.26 * (1.0 - bolt)
	var bank := clampf(-_turn * speed * 0.012, -0.22, 0.22)

	var air_pitch := _air * clampf(-velocity.y * 0.04, -0.4, 0.4)
	var body_at := _body_rest + Vector3(sway, -_drop + (high_fore + high_hind) * 0.5 + rise, 0.0)
	var body_turn := Vector3(air_pitch + rock - 0.03 * loping, 0.0, bank + roll)
	var chest_turn := Vector3(gather * 0.12, bend + swing_fore, (targets[0].y - targets[1].y) * 0.4)
	var pelvis_turn := Vector3(-gather * 0.3 - TUCK * (loping + flying * 0.5), -bend * 0.7 + swing_hind, (targets[2].y - targets[3].y) * 0.5)
	var poles: Array[Vector3] = [BEHIND, BEHIND, AHEAD, AHEAD]
	var flat: Array[float] = [0.0, 0.0, 0.0, 0.0]

	# --- Standing about: its weight goes from one side to the other. ---
	var idle := 1.0 - smoothstep(0.02, 0.3, _pace)
	body_at.x += sin(_time * 0.43) * 0.012 * _size * idle
	body_turn.z += sin(_time * 0.43 + 0.6) * 0.014 * idle
	# Roused, it stands tall in front; frightened, it goes low behind with its rump under it.
	body_at.y += (0.012 * _crest - 0.045 * _cowed) * _size
	body_turn.x -= 0.03 * _crest + 0.07 * _cowed
	pelvis_turn.x -= 0.2 * _cowed
	# Hit, it cringes over the way the blow went; shot, its hindquarters give under it.
	body_at += Vector3(_flinch_way.x * 0.05, -0.05, _flinch_way.z * 0.03) * _flinched * _size
	body_at.y -= 0.09 * _staggered * _size
	body_turn.z -= _flinch_way.x * 0.3 * _flinched
	body_turn.x -= 0.2 * _staggered
	chest_turn.y += _flinch_way.x * 0.35 * _flinched
	pelvis_turn.x -= 0.3 * _staggered
	_body.position = body_at
	_body.rotation = body_turn
	_chest.rotation = chest_turn
	_pelvis.rotation = pelvis_turn
	_breathe(delta, 0.0)
	_watch(delta)
	_pose_neck(body_turn.x + chest_turn.x, lope, loping, flying, gait)
	_mouth = lerpf(_mouth, jaw_open(), 0.5)
	_jaw.rotation.x = _mouth * GAPE
	_place_legs(targets, pitches, poles, flat, velocity.y)
	_raise_crest()
	_carry_brush(bolt)
	_carry_ears(delta, bolt)
	for i in _joints.size():
		_skeleton.set_bone_pose(_bones[i], _joints[i].transform)
	_swing(delta)


## Where it is looking: at what the Hyena says, or else about it.
func _watch(delta: float) -> void:
	var target := Vector2.ZERO
	if is_instance_valid(gaze):
		# (from where its head is carried, not from where it is this moment: or it would chase its own turning)
		var to := gaze.global_position + Vector3.UP * (0.9 if gaze is Player else 0.3) - (global_position + Vector3.UP * 0.75 * _size)
		if Vector2(to.x, to.z).length() < 0.5:
			to = global_basis.z
		target.x = clampf(angle_difference(rotation.y, atan2(to.x, to.z)), -1.7, 1.7)
		target.y = clampf(-atan2(to.y, Vector2(to.x, to.z).length()), -0.6, 0.5)
	else:
		target.x = sin(_time * 0.37) * 0.35 + sin(_time * 0.83 + 1.0) * 0.12
		target.y = sin(_time * 0.29 + 2.0) * 0.05
	_look = _look.lerp(target * (1.0 - _sniff * 0.8), 1.0 - exp(-6.0 * delta))


## Its neck and its head. The neck is thick and does not bend much: it is
## carried low, lower still going anywhere, nods as it walks, pumps as it
## lopes, comes up when it is roused, and goes right down to put its nose to
## the ground. Most of a turn of its head is a turn of its whole neck.
func _pose_neck(upstream: float, lope: float, loping: float, flying: float, gait: float) -> void:
	var low := 0.12 + (0.16 - 0.06 * lope) * gait + 0.3 * flying - 0.22 * _crest * (1.0 - flying) + 0.25 * _cowed + 0.4 * maxf(_flinched, _staggered)
	low = lerpf(low, NECK_DOWN, smoothstep(0.0, 1.0, _sniff))
	# The nod: down as each foreleg takes its weight, walking; once a stride, with the rock of it, loping.
	var nod := sin(2.0 * TAU * (_phase - 0.3)) * 0.035 * gait * (1.0 - lope) + cos(TAU * (_phase - 0.2)) * 0.05 * loping
	var yaw := _look.x * (1.0 - _flinched) + _flinch_way.x * 0.6 * _flinched
	_neck.rotation = Vector3(low * 0.6 - upstream * 0.55 + nod, yaw * 0.34, 0.0)
	_neck_1.rotation = Vector3(low * 0.4, yaw * 0.3, 0.0)
	# (its nose is kept nearly level whatever its neck is doing, and points down the slope of its neck when it sniffs)
	_head.rotation = Vector3(-low * 0.7 - upstream * 0.45 + _look.y * 0.9 - nod * 0.5 + 0.45 * _sniff + 0.1 * _cowed, yaw * 0.36, -_body.rotation.z * 0.5 + _look.x * 0.12 * _cowed)
	_chest.rotation.y += yaw * 0.08


## The mane: the bones that carry the tips of its locks are lifted, up and
## forward along its back, and quiver a little while they are up.
func _raise_crest() -> void:
	var raised := smoothstep(0.0, 1.0, _crest)
	for i in _crests.size():
		var quiver := sin(_time * 31.0 + i * 2.0) * 0.004 * raised
		# (the locks over its shoulders are the longest, and stand the highest)
		var share := 1.0 if i == 1 else 0.8
		_crests[i].position = _crest_rest[i] + (CREST_RISE * share + Vector3(quiver, 0.0, 0.0)) * raised


## Its tail: hanging; up, and bushed out, when it is roused; clamped down between its legs when it is frightened.
func _carry_brush(bolt: float) -> void:
	var carried := 0.08 + 1.5 * _crest + 0.5 * bolt - 0.9 * maxf(_cowed, maxf(_flinched, _staggered))
	for i in _tail.size():
		var link := _tail[i]
		var curl := carried - _pelvis.rotation.x * 0.8 if i == 0 else 0.12 * _crest
		link.aim = Basis(Vector3.RIGHT, curl) * link.rest
		link.limit = lerpf(0.6, 0.2, bolt)


func _build() -> void:
	var low := low_poly or Settings.low_poly
	_build_on(HYENA_MODELS[1 if low else 0])
	Toon.apply(_model)
	var head_at := _body_rest + _rest(&"chest") + _rest(&"neck") + _rest(&"neck_1") + _rest(&"head")
	# A rough coat, shorter on its face: everything forward of its ears, along the lie of the hair.
	Fur.apply(_model, &"coat", 0 if low else fur_shells, 0.02, 0.0 - head_at.z)
	for part: MeshInstance3D in _model.find_children("*", "MeshInstance3D", true, false):
		for surface in part.mesh.get_surface_count():
			var original := part.mesh.surface_get_material(surface) as StandardMaterial3D
			if original and original.resource_name == "eye":
				_eyes = part.get_surface_override_material(surface) as ShaderMaterial
				_eye_colour = original.albedo_color
			elif original and original.resource_name == "coat":
				_coat_colour = original.albedo_color
				# Its markings: bars down its flanks and bands round its legs, nearly black, and a paler belly.
				Fur.tune(part.get_surface_override_material(surface) as ShaderMaterial, {
					&"marks": Color(0.09, 0.075, 0.065), &"pale": original.albedo_color.lightened(0.18), &"mark_gain": 0.82, &"mark_spacing": 0.105, &"mark_bars": 1.0,
					&"strands": 380.0, &"run": 0.05, &"tufts": 520.0, &"patch": 0.2, &"streak": 0.4, &"droop": 0.5, &"sheen_gain": 0.03, &"rim_gain": 0.3,
				})
	for bone: StringName in [&"crest_neck", &"crest_chest", &"crest_pelvis"]:
		var crest := _joint({&"crest_neck": _neck, &"crest_chest": _chest, &"crest_pelvis": _pelvis}[bone], bone)
		_crests.append(crest)
		_crest_rest.append(crest.position)
	# The tail: a short heavy brush. The ears stand, and are turned and laid back as a hound's that stand are.
	_hang_tail(Vector2(900.0, 420.0), Vector2(34.0, 20.0), 4.0, 0.6)
	_stand_ears()
