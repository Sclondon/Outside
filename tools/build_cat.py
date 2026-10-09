"""Builds the cats and exports them for Godot.

Run from the project root:
    blender --background --python tools/build_cat.py
    blender --background --python tools/build_cat.py -- <preview folder> cat   # just one

Writes models/cat.glb (the temple cat: an Egyptian Mau or an Abyssinian, the
cat of the Bastet bronzes), models/cat_tabby.glb (a heavier house cat) and a
demade `_lo` version of each, with editable copies in tools/.

The two are built by the same code from one list of measurements and a few
numbers that change it (`cat()` below): how broad it is, how long in the leg,
how big its ears, how thick its tail, and whether it is spotted or striped.

It is built the way the hounds are (tools/build_hound.py, whose `Breed` and
joint tools this uses, on the kit in tools/build_character.py), and its bones
have the hound's names wherever a cat has the same part, so that
scripts/cat_rig.gd can use the hound rig's leg solver, springs and helpers:

    body, chest, pelvis, neck, neck_1, head, jaw, ear_*/ear_tip_*/ear_end_*,
    tail, tail_1..3, tail_end, and for each leg upper, lower, hock, paw.

What a cat has that a hound has not:

- A back in six pieces instead of two. `body` is the middle of it; forward of
  it `spine_1` and then `chest`; behind it `loin`, `loin_1` and then `pelvis`,
  each hanging from the one before.
- A tail of seven bones (`tail` to `tail_6`, and `tail_end` marking its tip).
- `blade_l`, `blade_r`: the tops of the shoulder blades, which stand up through
  the coat over whichever foreleg is carrying it.
- `toes_*`, one to a paw, under `paw_*`: scaled across to spread the toes.
- `eye_*` and `pupil_*`: squashed to narrow the eyes (the slow blink), and
  widened to open the pupil from a slit to a round.
- `whiskers_l`, `whiskers_r`.

The coat is marked without a texture. Its spots (or bars), the rings round
its legs and tail, the line down its back and its pale belly are drawn by the
fur shader (scripts/fur.gd) from the lie of the hair; what the model gives is
where each kind of marking goes, as a second set of texture coordinates
(`lay_marks`). The tail is a material of its own (`tail`), so that the rig can
stand its fur on end by itself; `marks` is the dark rim of the eyes and the
lines on the brow. scripts/cat_rig.gd gives every coat its colours: the ones
here are only a bronze Mau's, for looking at the model in Blender.

Everything is in Godot space (metres, Y up, facing +Z, +X its left). No mesh
object is named for a bone: they are `cat`, `cat_tabby` and so on.
"""

import math
import os
import random
import sys

import bmesh
import bpy  # noqa: F401  (Blender must be running this)
from mathutils import Matrix, Vector

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import build_character as kit  # noqa: E402  (shared shape-building and export tools)
import build_hound as dog  # noqa: E402  (the quadruped's joint tools: Breed, chain_param, leg_axis, ear_curve)

X, Y, Z = kit.X, kit.Y, kit.Z
blend = kit.blend
dome = kit.dome
SUFFIXES = dog.SUFFIXES
COAT, MOUTH, TEETH, EYE, EAR, MARKS, TAIL, PUPIL, NOSE, WHISKER = range(10)
TAIL_BONES = ["tail", "tail_1", "tail_2", "tail_3", "tail_4", "tail_5", "tail_6"]
# How far each side of a joint of the back its bend is spread (m)
SPINE_BLEND = 0.03


def V(x, y, z):
    return Vector((x, y, z))


def cat(name, wide=1.0, leg=1.0, ear=1.0, tail=1.0, head=1.0, pattern="spots"):
    """The measurements of a cat. With nothing changed it is the temple cat:
    lean, long in the leg and longer behind than in front, a deep narrow chest
    tucked up to the loin, large ears, a long whip of a tail."""
    deep = 1.0 + (wide - 1.0) * 0.6
    bone = 1.0 + (wide - 1.0) * 0.7
    # Shorter legs bring everything above them down
    drop = 0.22 * (1.0 - leg)

    def up(y):
        return y - drop

    def shank(joints):
        top = joints[0].y
        made = []
        for j in joints:
            y = 0.014 + (j.y - 0.014) * (top - drop - 0.014) / (top - 0.014)
            made.append(V(j.x * wide, y, j.z))
        return made

    spec = dict(
        name=name, pattern=pattern, wide=wide,
        materials=[("coat", (0.62, 0.47, 0.30)), ("mouth", (0.55, 0.20, 0.22)), ("teeth", (0.90, 0.88, 0.78)),
                   ("eye", (0.52, 0.66, 0.22)), ("ear", (0.62, 0.40, 0.36)), ("marks", (0.15, 0.10, 0.06)),
                   ("tail", (0.62, 0.47, 0.30)),
                   ("pupil", (0.01, 0.01, 0.012)), ("nose", (0.50, 0.22, 0.20)), ("whisker", (0.92, 0.90, 0.84))],
        # The back, from the middle of it forward and back: each a joint
        body=V(0.0, up(0.236), 0.0), spine_1=V(0.0, up(0.236), 0.050), chest=V(0.0, up(0.236), 0.115),
        loin=V(0.0, up(0.240), -0.050), loin_1=V(0.0, up(0.245), -0.108), pelvis=V(0.0, up(0.248), -0.165),
        # (along the body, centre height, half width, half height)
        trunk=[(-0.228, up(0.266), 0.020 * wide, 0.026), (-0.205, up(0.258), 0.038 * wide, 0.044 * deep),
               (-0.165, up(0.250), 0.049 * wide, 0.056 * deep), (-0.108, up(0.250), 0.042 * wide, 0.046 * deep),
               (-0.050, up(0.243), 0.043 * wide, 0.050 * deep), (0.000, up(0.232), 0.049 * wide, 0.060 * deep),
               (0.060, up(0.220), 0.054 * wide, 0.071 * deep), (0.115, up(0.217), 0.053 * wide, 0.073 * deep),
               (0.160, up(0.228), 0.044 * wide, 0.060 * deep), (0.188, up(0.242), 0.032 * wide, 0.042 * deep)],
        # Shoulder, elbow, wrist, paw; hip, stifle, hock, paw (the left legs)
        fore=shank([V(0.036, 0.204, 0.150), V(0.036, 0.132, 0.112), V(0.036, 0.046, 0.122), V(0.036, 0.014, 0.132)]),
        hind=shank([V(0.034, 0.236, -0.180), V(0.034, 0.152, -0.134), V(0.034, 0.076, -0.214), V(0.034, 0.014, -0.200)]),
        # (how far down the leg, counted in joints; half width; half depth; forward offset)
        fore_shape=[(s, rx * bone, rd * bone, shift) for s, rx, rd, shift in (
            (-0.35, 0.017, 0.029, 0.0), (0.0, 0.020, 0.034, 0.0), (0.5, 0.018, 0.028, 0.0), (1.0, 0.0150, 0.0200, -0.002),
            (1.3, 0.0135, 0.0170, 0.0), (1.7, 0.0120, 0.0145, 0.0), (2.0, 0.0115, 0.0135, 0.0), (2.5, 0.0110, 0.0130, 0.0),
            (3.0, 0.0120, 0.0140, 0.001))],
        hind_shape=[(s, rx * bone, rd * bone, shift) for s, rx, rd, shift in (
            (-0.25, 0.019, 0.038, 0.0), (0.0, 0.024, 0.050, 0.0), (0.45, 0.024, 0.046, 0.0), (0.85, 0.020, 0.032, 0.002),
            (1.0, 0.018, 0.026, 0.002), (1.3, 0.016, 0.023, -0.002), (1.7, 0.0120, 0.0160, 0.0), (2.0, 0.0115, 0.0150, -0.002),
            (2.3, 0.0105, 0.0130, 0.0), (2.7, 0.0105, 0.0125, 0.0), (3.0, 0.0120, 0.0140, 0.002))],
        paw=(0.0155 * bone, 0.026),
        # The tops of the shoulder blades
        blade=V(0.027 * wide, up(0.276), 0.136),
        neck=V(0.0, up(0.264), 0.174), head=V(0.0, up(0.308), 0.216),
        # (how far up the neck, radius, how far the throat hangs under it)
        neck_shape=[(-0.35, 0.046 * deep, 0.0), (0.0, 0.043 * deep, 0.002), (0.35, 0.039 * deep, 0.003), (0.7, 0.036 * deep, 0.002),
                    (1.0, 0.034 * deep, 0.0), (1.2, 0.030, 0.0)],
        skull_at=V(0.0, 0.022, 0.030), skull_size=V(0.0445 * head, 0.039 * head, 0.046),
        # (along the muzzle from the skull, height, half width, half height): short
        muzzle=[(0.024, -0.011, 0.026 * head, 0.023), (0.045, -0.014, 0.020 * head, 0.017), (0.059, -0.016, 0.0155 * head, 0.013)],
        nose=(V(0.0, -0.0085, 0.0660), V(0.0062, 0.0042, 0.0040)),
        jaw_at=V(0.0, -0.016, 0.004),
        jaw_shape=[(-0.004, -0.028, 0.024 * head, 0.010), (0.030, -0.031, 0.019 * head, 0.009), (0.053, -0.031, 0.0135 * head, 0.008)],
        # The line the teeth meet on, the length of the mouth, and its half width at the fangs and at the back
        mouth=(-0.026, 0.059, 0.0090, 0.015),
        eye=(V(0.0200 * head, 0.007, 0.0335), 0.0108),
        # Each ear: where it roots, the joint part way along it, and its end
        ear_at=[V(0.030 * head, 0.024 * head, -0.010), V(0.039 * head, 0.024 * head + 0.032 * ear, -0.014),
                V(0.047 * head, 0.024 * head + 0.064 * ear, -0.016)],
        ear_size=ear,
        tail_root=V(0.0, up(0.268), -0.218),
        tail_at=[(0.0, y * tail, z * tail) for y, z in ((0.0, 0.0), (-0.012, -0.045), (-0.030, -0.088), (-0.050, -0.130),
                                                        (-0.068, -0.172), (-0.080, -0.215), (-0.084, -0.258), (-0.078, -0.300))],
        tail_shape=[r * (1.0 + (wide - 1.0) * 1.6) for r in (0.0165, 0.0155, 0.0140, 0.0128, 0.0118, 0.0108, 0.0100, 0.0090, 0.0075)],
    )
    return dog.Breed(**spec)


MAU = cat("cat", head=1.07)
TABBY = cat("cat_tabby", wide=1.24, leg=0.88, ear=0.78, tail=0.92, head=1.10, pattern="stripes")


def trunk_at(breed, z):
    """The middle of the body and its half width and half height, at `z` along it."""
    rings = breed.trunk
    if z <= rings[0][0]:
        return rings[0][1:]
    for a, b in zip(rings, rings[1:]):
        if z <= b[0]:
            t = (z - a[0]) / (b[0] - a[0])
            return tuple(a[i] + (b[i] - a[i]) * t for i in (1, 2, 3))
    return rings[-1][1:]


def leg_share(breed, p):
    """Which leg a point is nearest, and how much of it hangs from that leg rather than the trunk."""
    suffix = ("_f" if p.z > -0.02 else "_r") + ("l" if p.x >= 0.0 else "r")
    joints = breed.legs[suffix]
    top = joints[0]
    off = dog.chain_param(V(top.x, p.y, p.z), joints)[0]
    return suffix, blend(top.y + 0.014, top.y - 0.040, p.y) * blend(0.040, 0.024, math.hypot(p.x - top.x, off / 1.8))


def on_tail(breed, p):
    """(Whether a point is part of the tail, how far along it counted in joints)."""
    off, along = dog.chain_param(p, breed.tail)
    return p.z < breed.tail[0].z + 0.004 and off < 0.03, along


def lay_fur(breed, bm, ears=False):
    """Gives the coat the texture coordinates the fur shader (scripts/fur.gd) reads:
    (how far along the lie of the hair, how far across it), in metres. As the
    hounds': back along the body from the nose to the tail, and down each leg
    and ear."""
    uv = bm.loops.layers.uv.verify()

    def around(x, y, near_x, near_y, radius):
        near = math.atan2(near_x, near_y)
        return (near + (math.atan2(x, y) - near + math.pi) % math.tau - math.pi) * radius

    def axis(z):
        return breed.body.y + 0.004 + (breed.head.y + 0.02 - breed.body.y) * blend(breed.neck.z - 0.02, breed.head.z, z)

    for face in bm.faces:
        near = kit.from_blender(face.calc_center_median())
        suffix, _ = leg_share(breed, near)
        joints = breed.legs[suffix]
        hip = joints[0]
        out = 1.0 if hip.x > 0.0 else -1.0
        for loop in face.loops:
            p = kit.from_blender(loop.vert.co)
            if ears:
                root = breed.ear[0]
                # (far forward along the lie of the coat, where the fur shader keeps the hair short)
                loop[uv].uv = ((p - V(root.x * (1.0 if p.x >= 0.0 else -1.0), root.y, root.z)).length - 2.0, p.z)
                continue
            leg = leg_share(breed, p)[1]
            trunk = (-p.z, around(p.x, p.y - axis(p.z), near.x, near.y - axis(near.z), 0.05))
            limb_uv = (hip.y - p.y - hip.z, around(p.z - dog.leg_axis(joints, p.y), (p.x - hip.x) * out,
                                                   near.z - dog.leg_axis(joints, near.y), (near.x - hip.x) * out, 0.016))
            loop[uv].uv = (trunk[0] + (limb_uv[0] - trunk[0]) * leg, trunk[1] + (limb_uv[1] - trunk[1]) * leg)


def lay_marks(breed, bm, plain=None):
    """Says where the coat is marked, in a second set of texture coordinates which
    the fur shader reads: x is what kind of marking (-1 none, 0 the body's spots
    or bars, 1 rings, 2 all dark), y how far it is belly. `plain` gives the
    whole part one value instead."""
    layer = bm.loops.layers.uv.get("marks") or bm.loops.layers.uv.new("marks")
    last = len(breed.tail) - 1
    base, top = breed.neck, breed.head
    for face in bm.faces:
        for loop in face.loops:
            if plain is not None:
                loop[layer].uv = plain
                continue
            p = kit.from_blender(loop.vert.co)
            tail, along = on_tail(breed, p)
            if tail:
                # Ringed, and dark at the end
                loop[layer].uv = (1.0 + blend(last - 1.3, last - 0.9, along), 0.0)
                continue
            leg = leg_share(breed, p)[1]
            # Rings round the legs, and none on the paws
            kind = leg * (1.0 - 2.0 * blend(0.075, 0.045, p.y))
            cy, rx, ry = trunk_at(breed, p.z)
            angle = abs(math.atan2(p.x / max(rx, 0.001), (p.y - cy) / max(ry, 0.001)))
            belly = blend(2.05, 2.55, angle) * (1.0 - leg) * blend(-0.215, -0.195, p.z)
            if p.z > base.z - 0.02:
                # The neck and the head: plain forward of the ears, pale under the throat and the chin
                t = (p - base).dot((top - base).normalized()) / (top - base).length
                centre = base.lerp(top, min(max(t, 0.0), 1.2))
                throat = blend(centre.y - 0.004, centre.y - 0.024, p.y)
                belly = max(belly * blend(0.5, 0.0, t), throat * blend(-0.2, 0.3, t))
                kind = min(kind, -blend(0.55, 0.95, t))
            loop[layer].uv = (kind, belly)


def furred(breed, b, fuse, plain=None):
    """Finishes a part of the coat: fused, and given its fur coordinates and its markings."""
    for vert in b.bm.verts:
        vert.co.z = max(vert.co.z, 0.0)  # nothing goes through the ground
    mesh = kit.fused(b, None if kit.LOW else fuse)
    bm = bmesh.new()
    bm.from_mesh(mesh)
    lay_fur(breed, bm)
    lay_marks(breed, bm, plain)
    for face in bm.faces:
        # (the tail is a material of its own, so that its fur can stand on end by itself)
        face.material_index = TAIL if plain is None and on_tail(breed, kit.from_blender(face.calc_center_median()))[0] else COAT
    bm.to_mesh(mesh)
    bm.free()
    return mesh


def limb(b, joints, stations, cap, segments=12):
    """A leg: a tube that follows the joints, its rings square to the bone at each."""
    directions = [(q - p).normalized() for p, q in zip(joints, joints[1:])]
    last = len(directions) - 1
    rings = []
    for s, rx, rd, shift in stations:
        i = min(max(int(math.floor(s)), 0), last)
        t = s - i
        point = joints[i] + (joints[i + 1] - joints[i]) * t
        if t < 0.5:
            ahead = directions[max(i - 1, 0)].lerp(directions[i], min(0.5 + t, 1.0))
        else:
            ahead = directions[i].lerp(directions[min(i + 1, last)], t - 0.5)
        across = ahead.normalized().cross(X).normalized()
        rings.append((point + across * shift, X * rx, across * rd))
    b.tube(dome(rings[0], -directions[0], cap)[::-1] + rings, segments)


def coat(breed):
    def shapes(b):
        low = kit.LOW
        wide = breed.wide
        rings = [kit.lengthwise(*ring) for ring in breed.trunk]
        b.tube(dome(rings[0], -Z, 0.014)[::-1] + rings + dome(rings[-1], Z, 0.016), 18)
        # The point of the chest, and the shoulder blade and the haunch on each side
        b.ellipsoid(V(0.0, breed.fore[0].y + 0.014, 0.168), V(0.030 * wide, 0.036, 0.022))
        blade = breed.blade
        for side in (1.0, -1.0):
            b.ellipsoid(V(side * blade.x, blade.y - 0.036, blade.z + 0.006), V(0.016 * wide, 0.052, 0.030), Matrix.Rotation(0.30, 3, "X"))
            if low:
                continue
            thigh = breed.hind[0].lerp(breed.hind[1], 0.3)
            b.ellipsoid(V(side * thigh.x, thigh.y + 0.012, thigh.z + 0.004), V(0.022 * wide, 0.056, 0.048), Matrix.Rotation(-0.45, 3, "X"))

        # Neck: short, and thick with fur
        base, top = breed.neck, breed.head + V(0.0, -0.004, -0.004)
        along = (top - base).normalized()
        across = along.cross(X).normalized()
        b.tube([(base.lerp(top, t) - across * sag, X * r, across * (r * 1.12)) for t, r, sag in breed.neck_shape], 14)

        # The head: a round skull, broad across the cheeks, and a short muzzle
        skull = breed.skull
        size = breed.skull_size
        b.ellipsoid(skull, size, None, 16, 9)
        for side in (1.0, -1.0):
            b.ellipsoid(skull + V(side * size.x * 0.62, -0.012, 0.012), V(size.x * 0.44, 0.019, 0.024), None, 8, 5)  # cheek
            b.ellipsoid(skull + V(side * 0.0120, -0.0210, 0.0545), V(0.0120, 0.0095, 0.0115), None, 8, 5)  # whisker pad
            b.ellipsoid(skull + V(side * size.x * 0.46, size.y * 0.50, size.z * 0.50), V(0.013, 0.008, 0.012), None, 8, 5)  # brow
        muzzle = [(skull + V(0.0, y, z), X * rx, Y * ry) for z, y, rx, ry in breed.muzzle]
        b.tube([(skull, X * size.x * 0.72, Y * size.y * 0.72)] + muzzle + dome(muzzle[-1], Z, muzzle[-1][1].x * 0.55, 3), 14)

        b.strand([breed.tail_root + V(0.0, 0.006, 0.030)] + breed.tail, breed.tail_shape, 10)

        for suffix, joints in breed.legs.items():
            fore = suffix[1] == "f"
            limb(b, joints, breed.fore_shape if fore else breed.hind_shape, 0.018)
            width, length = breed.paw
            paw = joints[3]
            if not low:
                # The point of the elbow, or of the hock, standing out behind
                knob = joints[1] + V(0.0, 0.006, -0.014) if fore else joints[2] + V(0.0, 0.008, -0.010)
                b.ellipsoid(knob, V(width * 0.62, 0.012, 0.010), None, 8, 5)
            b.ellipsoid(paw + V(0.0, -0.002, length * 0.5), V(width, 0.012, length), None, 10, 6)
            for toe in (() if low else (-1.5, -0.5, 0.5, 1.5)):
                b.ellipsoid(paw + V(toe * width * 0.42, -0.005, length * 1.20 - abs(toe) * length * 0.16), V(width * 0.27, 0.0085, 0.011), None, 8, 5)
        return furred(breed, b, (0.0021, 4, 11000))
    return shapes


def jaw(breed):
    def shapes(b):
        # The lower jaw: not fused to the head, so that it can drop open
        rings = [(breed.skull + V(0.0, y, z), X * rx, Y * ry) for z, y, rx, ry in breed.jaw_shape]
        b.tube(dome(rings[0], -Z, 0.006, 2)[::-1] + rings + dome(rings[-1], Z, 0.008, 3), 12)
        return furred(breed, b, (0.0016, 2, 400), (-1.0, 1.0))
    return shapes


def nose(breed):
    def shapes(b):
        b.ellipsoid(breed.skull + breed.nose[0], breed.nose[1], None, 8, 5)
    return shapes


def ear_frame(side):
    return V(side * 0.86, 0.0, -0.50).normalized(), V(side * 0.50, 0.0, 0.86).normalized()


def ears(breed):
    def shapes(b):
        s = breed.ear_size
        for side in (1.0, -1.0):
            # Tall, broad at the base and cupped, the open side to the front and a little out
            wide, face = ear_frame(side)
            rings = []
            for t, half, thick in ((0.0, 0.0245, 0.0090), (0.12, 0.0270, 0.0075), (0.35, 0.0245, 0.0050), (0.60, 0.0185, 0.0040),
                                   (0.82, 0.0105, 0.0030), (0.95, 0.0050, 0.0025), (1.0, 0.0018, 0.0020)):
                rings.append((dog.ear_curve(breed, t, side), wide * half * (0.6 + 0.4 * s), face * thick))
            b.tube(dome(rings[0], -Y, 0.005, 2)[::-1] + rings, 10)
        lay_fur(breed, b.bm, True)
        lay_marks(breed, b.bm, (-1.0, 0.0))
    return shapes


def ear_linings(breed):
    def shapes(b):
        s = breed.ear_size
        for side in (1.0, -1.0):
            wide, face = ear_frame(side)
            rings = []
            for t, half in ((0.10, 0.010), (0.22, 0.0195), (0.40, 0.0190), (0.60, 0.0135), (0.80, 0.0068), (0.92, 0.0020)):
                rings.append((dog.ear_curve(breed, t, side) + face * 0.0032, wide * half * (0.6 + 0.4 * s), face * 0.0022))
            b.tube(rings, 8)
    return shapes


def palate(breed):
    def shapes(b):
        y, length, _, width = breed.mouth
        b.ellipsoid(breed.skull + V(0.0, y, length * 0.42), V(width * 0.8, 0.003, length * 0.36), None, 8, 5)
    return shapes


def tongue(breed):
    def shapes(b):
        y, length, _, width = breed.mouth
        b.ellipsoid(breed.skull + V(0.0, y + 0.004, length * 0.46), V(width * 0.6, 0.003, length * 0.42), None, 8, 5)
    return shapes


def fangs(breed):
    def shapes(b):
        y, length, front, back = breed.mouth
        for side in (1.0, -1.0):
            for share, tall, radius in ((0.86, 0.0090, 0.0019), (0.55, 0.0035, 0.0018), (0.38, 0.0040, 0.0020)):
                x = back + (front - back) * share
                base = breed.skull + V(side * x, y + 0.002, length * share)
                kit.spike(b, base, base - Y * tall, radius, 5)
    return shapes


def teeth(breed):
    def shapes(b):
        y, length, front, back = breed.mouth
        for side in (1.0, -1.0):
            for share, tall, radius in ((0.76, 0.0080, 0.0018), (0.46, 0.0035, 0.0018)):
                x = (back + (front - back) * share) * 0.8
                base = breed.skull + V(side * x, y + 0.003, length * share)
                kit.spike(b, base, base + Y * tall, radius, 5)
    return shapes


def eyes(breed):
    def shapes(b):
        # Large, and set to look forward
        at, radius = breed.eye
        for side in (1.0, -1.0):
            b.ellipsoid(breed.skull + V(side * at.x, at.y, at.z), V(radius, radius * 0.86, radius), Matrix.Rotation(-side * 0.25, 3, "Z"), 10, 6)
    return shapes


def liner(breed):
    def shapes(b):
        # The dark rim of the eye, drawn out at its outer corner as if with kohl: the eye sits in it
        at, radius = breed.eye
        for side in (1.0, -1.0):
            b.ellipsoid(breed.skull + V(side * (at.x + 0.0012), at.y + 0.0004, at.z - 0.0034), V(radius * 1.13, radius * 0.93, radius),
                        Matrix.Rotation(-side * 0.32, 3, "Z"), 10, 6)
        if kit.LOW:
            return
        size = breed.skull_size
        for side in (1.0, -1.0):
            # The lines on its brow
            for x in (0.0065, 0.0185):
                points = []
                across = math.sqrt(max(1.0 - (x / size.x) ** 2, 0.0))
                for k in range(4):
                    e = 0.62 + k * 0.26
                    points.append(breed.skull + V(side * x * (1.0 + k * 0.12), (size.y - 0.0002) * math.sin(e) * across, (size.z - 0.0002) * math.cos(e) * across))
                b.strand(points, [0.0008, 0.0012, 0.0012, 0.0007], 5)
    return shapes


def pupil_at(breed, side):
    at, radius = breed.eye
    return breed.skull + V(side * (at.x + radius * 0.04), at.y, at.z + radius * 0.84)


def pupils(breed):
    def shapes(b):
        # A slit, standing up: the rig widens it
        _, radius = breed.eye
        for side in (1.0, -1.0):
            b.ellipsoid(pupil_at(breed, side), V(radius * 0.20, radius * 0.66, radius * 0.30), Matrix.Rotation(-side * 0.30, 3, "Y"), 8, 5)
    return shapes


def whisker_root(breed, side):
    return breed.skull + V(side * 0.0135, -0.0205, 0.0570)


def whiskers(breed):
    def shapes(b):
        for side in (1.0, -1.0):
            root = whisker_root(breed, side)
            for k in range(-2, 3):
                out = V(side, k * 0.17 - 0.05, 0.10 - 0.05 * abs(k)).normalized()
                length = 0.062 - 0.007 * abs(k)
                start = root + V(side * 0.006, k * 0.0028, -0.002 * abs(k))
                points = [start, start + out * length * 0.5 + V(0, -0.001, 0), start + out * length + V(0, -0.005, -0.004)]
                b.strand(points, [0.0011, 0.0008, 0.0003], 3)
            # And over each eye
            for k in (0, 1):
                start = breed.skull + V(side * (0.015 + k * 0.006), breed.skull_size.y * 0.80, 0.022 - k * 0.006)
                out = V(side * (0.45 + k * 0.25), 0.8, 0.35).normalized()
                b.strand([start, start + out * 0.016, start + out * 0.030 + V(0, -0.002, 0.002)], [0.0009, 0.0007, 0.0003], 3)
    return shapes


def weights(breed):
    tail = breed.tail
    tail_names = ["pelvis"] + TAIL_BONES
    joints_back = (breed.loin.z, breed.loin_1.z, breed.pelvis.z)
    joints_front = (breed.spine_1.z, breed.chest.z)
    h = SPINE_BLEND

    def trunk_of(z):
        r1, r2, r3 = (blend(at + h, at - h, z) for at in joints_back)
        f1, f2 = (blend(at - h, at + h, z) for at in joints_front)
        return {"body": (1.0 - r1) * (1.0 - f1), "loin": r1 * (1.0 - r2), "loin_1": r1 * r2 * (1.0 - r3), "pelvis": r1 * r2 * r3,
                "spine_1": f1 * (1.0 - f2), "chest": f1 * f2}

    def weigh(part, p):
        suffix = "_l" if p.x >= 0.0 else "_r"
        side = 1.0 if p.x >= 0.0 else -1.0
        if part in ("jaw", "tongue", "teeth"):
            return {"jaw": 1.0}
        if part in ("palate", "fangs", "nose", "liner"):
            return {"head": 1.0}
        if part == "eyes":
            return {"eye" + suffix: 1.0}
        if part == "pupils":
            return {"pupil" + suffix: 1.0}
        if part == "whiskers":
            return {"whiskers" + suffix: 1.0} if p.y < breed.skull.y else {"head": 1.0}
        if part in ("ears", "linings"):
            root, mid, end = (V(j.x * side, j.y, j.z) for j in breed.ear)
            along = (p - root).dot((end - root).normalized())
            joint = (mid - root).dot((end - root).normalized())
            hung = blend(0.0, 0.016, along)
            tip = blend(joint - 0.012, joint + 0.012, along)
            return {"head": 1.0 - hung, "ear" + suffix: hung * (1.0 - tip), "ear_tip" + suffix: hung * tip}
        is_tail, along = on_tail(breed, p)
        if is_tail:
            count = len(TAIL_BONES)
            past = [1.0, blend(0.0, 0.6, along)] + [blend(k - 0.3, k + 0.3, along) for k in range(1, count)] + [0.0]
            return {name: past[i] - past[i + 1] for i, name in enumerate(tail_names)}
        trunk = trunk_of(p.z)
        base, top = breed.neck, breed.head
        reach = (p - base).dot((top - base).normalized()) / (top - base).length
        if reach > 0.0 and p.z > base.z - 0.02:
            neck = blend(0.0, 0.34, reach)
            upper = blend(0.34, 0.68, reach)
            head = blend(0.70, 1.02, reach)
            return {"chest": 1.0 - neck, "neck": neck * (1.0 - upper), "neck_1": neck * upper * (1.0 - head), "head": neck * upper * head}
        leg_suffix, leg = leg_share(breed, p)
        joints = breed.legs[leg_suffix]
        along = dog.chain_param(V(joints[0].x, p.y, p.z), joints)[1]
        spans = [(b - a).length for a, b in zip(joints, joints[1:])]
        low = blend(1.0 - 0.020 / spans[0], 1.0 + 0.020 / spans[1], along)
        hock = blend(2.0 - 0.016 / spans[1], 2.0 + 0.016 / spans[2], along)
        paw = blend(joints[3].y + 0.022, joints[3].y + 0.006, p.y)
        toes = blend(joints[3].z + breed.paw[1] * 0.45, joints[3].z + breed.paw[1] * 0.85, p.z)
        made = {bone: weight * (1.0 - leg) for bone, weight in trunk.items()}
        made["upper" + leg_suffix] = leg * (1.0 - low)
        made["lower" + leg_suffix] = leg * low * (1.0 - hock)
        made["hock" + leg_suffix] = leg * low * hock * (1.0 - paw)
        made["paw" + leg_suffix] = leg * low * hock * paw * (1.0 - toes)
        made["toes" + leg_suffix] = leg * low * hock * paw * toes
        # The top of the shoulder blade, under the coat
        top_of = V(breed.blade.x * side, breed.blade.y, breed.blade.z)
        blade = blend(0.042, 0.012, (p - top_of).length) * blend(breed.blade.y - 0.05, breed.blade.y - 0.02, p.y)
        if blade > 0.0:
            made = {bone: weight * (1.0 - blade) for bone, weight in made.items()}
            made["blade" + suffix] = blade
        return made
    return weigh


def bones(breed):
    listed = [
        ("body", breed.body, None), ("spine_1", breed.spine_1, "body"), ("chest", breed.chest, "spine_1"),
        ("loin", breed.loin, "body"), ("loin_1", breed.loin_1, "loin"), ("pelvis", breed.pelvis, "loin_1"),
        ("neck", breed.neck, "chest"), ("neck_1", breed.neck_1, "neck"), ("head", breed.head, "neck_1"), ("jaw", breed.jaw, "head"),
    ]
    for side, suffix in ((1.0, "_l"), (-1.0, "_r")):
        root, mid, end = (V(j.x * side, j.y, j.z) for j in breed.ear)
        listed.append(("ear" + suffix, root, "head"))
        listed.append(("ear_tip" + suffix, mid, "ear" + suffix))
        # (carries nothing: it marks where the ear ends, for the rig)
        listed.append(("ear_end" + suffix, end, "ear_tip" + suffix))
        at, _ = breed.eye
        listed.append(("eye" + suffix, breed.skull + V(side * at.x, at.y, at.z), "head"))
        listed.append(("pupil" + suffix, pupil_at(breed, side), "eye" + suffix))
        listed.append(("whiskers" + suffix, whisker_root(breed, side), "head"))
        listed.append(("blade" + suffix, V(breed.blade.x * side, breed.blade.y, breed.blade.z), "chest"))
    chain = ["pelvis"] + TAIL_BONES + ["tail_end"]
    for i, joint in enumerate(breed.tail):
        listed.append((chain[i + 1], joint, chain[i]))
    for suffix, joints in breed.legs.items():
        for bone, joint in zip(("upper", "lower", "hock", "paw"), joints):
            listed.append((bone + suffix, joint, "body"))
        listed.append(("toes" + suffix, joints[3] + V(0.0, 0.0, breed.paw[1] * 0.6), "paw" + suffix))
    return listed


def parts(breed):
    # The coat and the jaw fuse and mark themselves (see `furred`), so nothing here asks for it.
    return [
        ("coat", None, coat(breed), None), ("jaw", None, jaw(breed), None), ("ears", COAT, ears(breed), None),
        ("nose", NOSE, nose(breed), None), ("palate", MOUTH, palate(breed), None), ("tongue", MOUTH, tongue(breed), None),
        ("fangs", TEETH, fangs(breed), None), ("teeth", TEETH, teeth(breed), None), ("eyes", EYE, eyes(breed), None),
        ("pupils", PUPIL, pupils(breed), None), ("liner", MARKS, liner(breed), None), ("linings", EAR, ear_linings(breed), None), ("whiskers", WHISKER, whiskers(breed), None),
    ]


def preview(folder, name):
    """Pictures of it framed for something a cat's size (the kit's own are framed for a boy)."""
    scene = bpy.context.scene
    camera = scene.camera
    for view, direction, target, frame in (("near_side", (1, 0, 0), (0.0, -0.02, 0.22), 0.80), ("near_quarter", (0.7, -0.7, 0.3), (0.0, -0.02, 0.22), 0.80),
                                           ("near_front", (0.15, -1, 0.1), (0.0, 0.0, 0.25), 0.50), ("near_top", (0.0, -0.05, 1), (0.0, -0.02, 0.2), 0.80),
                                           ("near_head", (0.55, -0.8, 0.15), (0.0, -0.28, 0.35), 0.24)):
        offset = Vector(direction).normalized() * 4.0
        camera.data.ortho_scale = frame
        camera.location = Vector(target) + offset
        camera.rotation_euler = (-offset).to_track_quat("-Z", "Y").to_euler()
        scene.render.filepath = os.path.join(folder, "%s_%s.png" % (name, view))
        bpy.ops.render.render(write_still=True)


if __name__ == "__main__":
    for low in (False, True):
        kit.LOW = low
        for breed in (MAU, TABBY):
            name = breed.name + ("_lo" if low else "")
            if kit.ONLY and name not in kit.ONLY:
                continue
            kit.export(name, bones(breed), parts(breed), weights(breed), breed.materials)
            if kit.PREVIEW_DIR:
                preview(kit.PREVIEW_DIR, name)
