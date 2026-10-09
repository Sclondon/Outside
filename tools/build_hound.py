"""Builds the hounds and exports them for Godot.

Run from the project root:
    blender --background --python tools/build_hound.py
    blender --background --python tools/build_hound.py -- <preview folder> hound_pharaoh   # just one

Writes models/hound.glb (the bloodhound), models/hound_pharaoh.glb (the
prick-eared hound) and a demade `_lo` version of each, with editable copies
in tools/.

There are two breeds, built by the same code from two lists of measurements
(`BLOODHOUND` and `PHARAOH` below):

- The bloodhound: heavy in the head and the bone, a long deep square muzzle
  with hanging lips, loose skin (a dewlap under the throat, folds over the
  brow and down the cheeks), and long low-set ears of thin leather.
- The pharaoh hound, which is the jackal of the tomb paintings: lean and
  leggy, a deep narrow chest tucked up hard to the loin, a long arched neck,
  a long fine wedge of a head, and tall pointed ears that stand.

Both have the same bones, with the same names, so scripts/hound_rig.gd
animates either; it reads every joint from the skeleton, so nothing here needs
copying anywhere else. Each leg is three bones and a paw, as a dog's is:

    fore: `upper` (shoulder to elbow), `lower` (forearm), `hock` (pastern), `paw`
    hind: `upper` (thigh, hip to stifle), `lower` (shank), `hock` (hock to paw), `paw`

They are siblings under `body`: the rig places each directly with IK.

Everything is in Godot space (metres, Y up, facing +Z, +X its left).
"""

import math
import os
import sys

import bmesh
import bpy  # noqa: F401  (Blender must be running this)
from mathutils import Matrix, Vector

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import build_character as kit  # noqa: E402  (shared shape-building and export tools)

X, Y, Z = kit.X, kit.Y, kit.Z
blend = kit.blend
dome = kit.dome
SUFFIXES = ("_fl", "_fr", "_rl", "_rr")


def V(x, y, z):
    return Vector((x, y, z))


class Breed:
    def __init__(self, **spec):
        self.__dict__.update(spec)
        self.skull = self.head + self.skull_at
        self.jaw = self.skull + self.jaw_at
        self.ear = [self.skull + offset for offset in self.ear_at]
        self.tail = [self.tail_root + V(*offset) for offset in self.tail_at]
        self.neck_1 = self.neck.lerp(self.head, 0.5)
        self.legs = {}
        for suffix in SUFFIXES:
            side = 1.0 if suffix[2] == "l" else -1.0
            self.legs[suffix] = [V(j.x * side, j.y, j.z) for j in (self.fore if suffix[1] == "f" else self.hind)]


BLOODHOUND = Breed(
    name="hound",
    heavy=True,
    materials=[("coat", (0.046, 0.046, 0.050)), ("mouth", (0.42, 0.07, 0.08)), ("teeth", (0.86, 0.82, 0.68)),
               ("eye", (0.60, 0.34, 0.08)), ("ear", (0.10, 0.07, 0.065))],
    body=V(0.0, 0.54, 0.0), chest=V(0.0, 0.56, 0.20), pelvis=V(0.0, 0.55, -0.22),
    # (along the body, centre height, half width, half height): deep ribs, a loin only a little tucked, broad hips
    trunk=[(-0.36, 0.585, 0.054, 0.062), (-0.31, 0.570, 0.092, 0.098), (-0.22, 0.556, 0.108, 0.114),
           (-0.12, 0.552, 0.102, 0.110), (-0.03, 0.545, 0.106, 0.120), (0.06, 0.526, 0.116, 0.144),
           (0.16, 0.502, 0.126, 0.172), (0.25, 0.510, 0.122, 0.164), (0.31, 0.538, 0.104, 0.132),
           (0.35, 0.568, 0.078, 0.098)],
    # Shoulder, elbow, wrist, paw; hip, stifle, hock, paw (the left legs: the right are their mirror)
    fore=[V(0.090, 0.50, 0.270), V(0.090, 0.345, 0.195), V(0.090, 0.135, 0.215), V(0.090, 0.032, 0.235)],
    hind=[V(0.082, 0.52, -0.260), V(0.082, 0.36, -0.180), V(0.082, 0.175, -0.345), V(0.082, 0.032, -0.335)],
    # (how far down the leg, counted in joints; half width; half depth; forward offset)
    fore_shape=[(-0.3, 0.040, 0.064, 0.0), (0.0, 0.046, 0.074, 0.0), (0.5, 0.044, 0.064, 0.0), (1.0, 0.040, 0.054, -0.004),
                (1.25, 0.039, 0.050, 0.0), (1.6, 0.036, 0.043, 0.0), (2.0, 0.035, 0.039, 0.0), (2.5, 0.033, 0.036, 0.0),
                (3.0, 0.034, 0.037, 0.003)],
    hind_shape=[(-0.25, 0.044, 0.090, 0.0), (0.0, 0.052, 0.106, 0.0), (0.45, 0.052, 0.096, 0.0), (0.85, 0.045, 0.068, 0.004),
                (1.0, 0.041, 0.058, 0.004), (1.3, 0.037, 0.054, -0.004), (1.7, 0.031, 0.040, 0.0), (2.0, 0.031, 0.040, -0.004),
                (2.3, 0.029, 0.034, 0.0), (2.7, 0.029, 0.033, 0.0), (3.0, 0.032, 0.036, 0.004)],
    paw=(0.041, 0.058),
    muscle=1.0,
    neck=V(0.0, 0.60, 0.30), head=V(0.0, 0.725, 0.465),
    # (how far up the neck, radius, how far the throat hangs under it)
    neck_shape=[(-0.3, 0.094, 0.0), (0.0, 0.090, 0.008), (0.35, 0.081, 0.012), (0.7, 0.073, 0.010), (1.0, 0.067, 0.0), (1.15, 0.056, 0.0)],
    skull_at=V(0.0, 0.034, 0.044), skull_size=V(0.072, 0.072, 0.092),
    # (along the muzzle from the skull, height, half width, half height)
    muzzle=[(0.05, -0.006, 0.054, 0.050), (0.11, -0.016, 0.048, 0.047), (0.19, -0.022, 0.045, 0.046), (0.262, -0.024, 0.042, 0.044)],
    nose=(V(0.0, -0.002, 0.290), V(0.027, 0.023, 0.020)),
    jaw_at=V(0.0, -0.036, 0.000),
    jaw_shape=[(-0.01, -0.050, 0.044, 0.024), (0.10, -0.064, 0.037, 0.019), (0.215, -0.068, 0.030, 0.016)],
    # The line the teeth meet on, the length of the mouth, and its half width at the fangs and at the back
    mouth=(-0.064, 0.250, 0.029, 0.033),
    eye=(V(0.045, 0.014, 0.066), 0.011),
    # Each ear: where it roots, the joint part way along it, and its end
    ear_at=[V(0.066, -0.012, -0.030), V(0.088, -0.135, -0.012), V(0.082, -0.290, 0.030)],
    tail_root=V(0.0, 0.60, -0.37),
    tail_at=[(0.0, 0.0, 0.0), (0.0, -0.05, -0.10), (0.0, -0.11, -0.19), (0.0, -0.14, -0.28), (0.0, -0.125, -0.36)],
    tail_shape=[0.034, 0.032, 0.027, 0.022, 0.017, 0.012],
)

PHARAOH = Breed(
    name="hound_pharaoh",
    heavy=False,
    materials=[("coat", (0.036, 0.038, 0.046)), ("mouth", (0.42, 0.07, 0.08)), ("teeth", (0.86, 0.82, 0.68)),
               ("eye", (0.86, 0.60, 0.14)), ("ear", (0.33, 0.20, 0.16))],
    body=V(0.0, 0.60, 0.0), chest=V(0.0, 0.62, 0.20), pelvis=V(0.0, 0.61, -0.22),
    # A deep narrow chest, the belly tucked up hard behind it, a slight arch over the loin
    trunk=[(-0.35, 0.648, 0.038, 0.048), (-0.30, 0.636, 0.064, 0.078), (-0.22, 0.626, 0.074, 0.090),
           (-0.12, 0.644, 0.060, 0.068), (-0.03, 0.628, 0.064, 0.084), (0.06, 0.592, 0.076, 0.122),
           (0.16, 0.562, 0.084, 0.158), (0.25, 0.574, 0.082, 0.146), (0.31, 0.602, 0.068, 0.112),
           (0.35, 0.632, 0.050, 0.078)],
    fore=[V(0.068, 0.565, 0.265), V(0.068, 0.400, 0.195), V(0.068, 0.150, 0.210), V(0.068, 0.028, 0.226)],
    hind=[V(0.064, 0.585, -0.260), V(0.064, 0.410, -0.165), V(0.064, 0.190, -0.350), V(0.064, 0.028, -0.345)],
    fore_shape=[(-0.3, 0.028, 0.048, 0.0), (0.0, 0.031, 0.054, 0.0), (0.5, 0.029, 0.045, 0.0), (1.0, 0.025, 0.035, -0.003),
                (1.25, 0.023, 0.031, 0.0), (1.6, 0.020, 0.025, 0.0), (2.0, 0.019, 0.022, 0.0), (2.5, 0.017, 0.019, 0.0),
                (3.0, 0.019, 0.021, 0.002)],
    hind_shape=[(-0.25, 0.030, 0.066, 0.0), (0.0, 0.036, 0.084, 0.0), (0.45, 0.036, 0.076, 0.0), (0.85, 0.030, 0.049, 0.003),
                (1.0, 0.027, 0.040, 0.003), (1.3, 0.024, 0.036, -0.003), (1.7, 0.018, 0.024, 0.0), (2.0, 0.018, 0.025, -0.003),
                (2.3, 0.015, 0.019, 0.0), (2.7, 0.015, 0.018, 0.0), (3.0, 0.018, 0.021, 0.003)],
    paw=(0.025, 0.044),
    muscle=0.8,
    neck=V(0.0, 0.675, 0.30), head=V(0.0, 0.895, 0.415),
    neck_shape=[(-0.3, 0.064, 0.0), (0.0, 0.058, 0.003), (0.35, 0.047, 0.002), (0.7, 0.041, 0.0), (1.0, 0.038, 0.0), (1.15, 0.032, 0.0)],
    skull_at=V(0.0, 0.018, 0.030), skull_size=V(0.046, 0.043, 0.066),
    # A long clean wedge, tapering all the way to the nose
    muzzle=[(0.03, -0.002, 0.037, 0.034), (0.09, -0.007, 0.030, 0.027), (0.15, -0.011, 0.025, 0.023), (0.198, -0.014, 0.021, 0.020)],
    nose=(V(0.0, -0.008, 0.212), V(0.015, 0.013, 0.012)),
    jaw_at=V(0.0, -0.022, 0.000),
    jaw_shape=[(-0.01, -0.030, 0.029, 0.014), (0.08, -0.037, 0.024, 0.012), (0.17, -0.040, 0.018, 0.010)],
    mouth=(-0.036, 0.190, 0.010, 0.020),
    eye=(V(0.027, 0.010, 0.047), 0.009),
    ear_at=[V(0.033, 0.028, -0.028), V(0.054, 0.100, -0.038), V(0.074, 0.180, -0.042)],
    tail_root=V(0.0, 0.655, -0.36),
    tail_at=[(0.0, 0.0, 0.0), (0.0, -0.08, -0.08), (0.0, -0.18, -0.14), (0.0, -0.28, -0.17), (0.0, -0.35, -0.155)],
    tail_shape=[0.024, 0.022, 0.018, 0.014, 0.010, 0.007],
)


def chain_param(p, joints):
    """The nearest point to `p` on a line of joints: (how far off it, how far along it counted in joints)."""
    best = (1e9, 0.0)
    for i in range(len(joints) - 1):
        a, b = joints[i], joints[i + 1]
        ab = b - a
        t = min(max((p - a).dot(ab) / ab.length_squared, 0.0), 1.0)
        d = (p - (a + ab * t)).length
        if d < best[0]:
            best = (d, i + t)
    return best


def leg_share(breed, p):
    """Which leg a point is nearest, and how much of it hangs from that leg rather than the trunk."""
    suffix = ("_f" if p.z > 0.0 else "_r") + ("l" if p.x >= 0.0 else "r")
    joints = breed.legs[suffix]
    top = joints[0]
    off = chain_param(V(top.x, p.y, p.z), joints)[0]
    # Only what lies along the leg belongs to it, not the belly beside it
    return suffix, blend(top.y + 0.03, top.y - 0.09, p.y) * blend(0.085, 0.05, math.hypot(p.x - top.x, off / 1.8))


def leg_axis(joints, y):
    """How far forward the leg is at height `y`."""
    for a, b in zip(joints, joints[1:]):
        if y >= b.y:
            return a.z + (b.z - a.z) * min(max((a.y - y) / (a.y - b.y), 0.0), 1.0)
    return joints[-1].z


def lay_fur(breed, bm, ears=False):
    """Gives the coat the texture coordinates the fur shader (scripts/fur.gd) reads:
    (how far along the lie of the hair, how far across it), in metres. The hair
    lies back along the body from the nose to the tail, and down each leg and
    ear. Fusing a part throws its own coordinates away, so this runs after it.
    """
    uv = bm.loops.layers.uv.verify()

    def around(x, y, near_x, near_y, radius):
        # (measured next to the middle of the face it belongs to, so no face is
        # stretched right round the body where the angle starts again)
        near = math.atan2(near_x, near_y)
        return (near + (math.atan2(x, y) - near + math.pi) % math.tau - math.pi) * radius

    def axis(z):
        return breed.body.y + 0.01 + (breed.head.y + 0.02 - breed.body.y) * blend(breed.neck.z - 0.02, breed.head.z, z)

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
                # (set far forward along the lie of the coat, where the fur shader keeps the hair short, as it is on the face)
                loop[uv].uv = ((p - V(root.x * (1.0 if p.x >= 0.0 else -1.0), root.y, root.z)).length - 2.0, p.z)
                continue
            leg = leg_share(breed, p)[1]
            trunk = (-p.z, around(p.x, p.y - axis(p.z), near.x, near.y - axis(near.z), 0.10))
            # (down the leg, and round it from its outer side)
            limb = (hip.y - p.y - hip.z, around(p.z - leg_axis(joints, p.y), (p.x - hip.x) * out,
                                                near.z - leg_axis(joints, near.y), (near.x - hip.x) * out, 0.035))
            loop[uv].uv = (trunk[0] + (limb[0] - trunk[0]) * leg, trunk[1] + (limb[1] - trunk[1]) * leg)


def furred(breed, b, fuse):
    """Finishes a part of the coat: fused like any other, and then given its fur coordinates."""
    for vert in b.bm.verts:
        vert.co.z = max(vert.co.z, 0.0)  # nothing goes through the ground
    mesh = kit.fused(b, None if kit.LOW else fuse)
    bm = bmesh.new()
    bm.from_mesh(mesh)
    lay_fur(breed, bm)
    bm.to_mesh(mesh)
    bm.free()
    return mesh


def limb(b, joints, stations, segments=12):
    """A leg: a tube that follows the joints, its rings square to the bone at each."""
    directions = [(q - p).normalized() for p, q in zip(joints, joints[1:])]
    last = len(directions) - 1
    rings = []
    for s, rx, rd, shift in stations:
        i = min(max(int(math.floor(s)), 0), last)
        t = s - i
        point = joints[i] + (joints[i + 1] - joints[i]) * t
        # (at a joint, halfway between the bone above and the bone below)
        if t < 0.5:
            ahead = directions[max(i - 1, 0)].lerp(directions[i], min(0.5 + t, 1.0))
        else:
            ahead = directions[i].lerp(directions[min(i + 1, last)], t - 0.5)
        across = ahead.normalized().cross(X).normalized()
        rings.append((point + across * shift, X * rx, across * rd))
    b.tube(dome(rings[0], -directions[0], 0.04)[::-1] + rings, segments)


def coat(breed):
    def shapes(b):
        low = kit.LOW
        heavy = breed.heavy
        m = breed.muscle
        rings = [kit.lengthwise(*ring) for ring in breed.trunk]
        b.tube(dome(rings[0], -Z, 0.04)[::-1] + rings + dome(rings[-1], Z, 0.04), 18)
        # Withers, the point of the chest, and the muscle over each shoulder and haunch
        top = breed.trunk[6][1] + breed.trunk[6][3]
        b.ellipsoid(V(0.0, top - 0.026, 0.19), V(0.050 * m, 0.030, 0.110))
        b.ellipsoid(V(0.0, breed.fore[0].y + 0.02, 0.335), V(0.060 * m, 0.075, 0.055))
        for side in (() if low else (1.0, -1.0)):
            arm = breed.fore[0].lerp(breed.fore[1], 0.3)
            b.ellipsoid(V(side * (arm.x + 0.004), arm.y + 0.03, arm.z - 0.01), V(0.034 * m, 0.105, 0.070 * m), Matrix.Rotation(0.40, 3, "X"))
            thigh = breed.hind[0].lerp(breed.hind[1], 0.3)
            b.ellipsoid(V(side * thigh.x, thigh.y + 0.02, thigh.z + 0.01), V(0.046 * m, 0.115, 0.100 * m), Matrix.Rotation(-0.45, 3, "X"))

        # Neck, rising forward out of the chest, with a throat under it
        base, top = breed.neck, breed.head + V(0.0, -0.01, -0.01)
        along = (top - base).normalized()
        across = along.cross(X).normalized()
        b.tube([(base.lerp(top, t) - across * sag, X * r, across * (r * 1.2)) for t, r, sag in breed.neck_shape], 14)
        if heavy:
            # The dewlap: loose skin hanging in a fold from the jaw down the front of the neck
            for t, drop, size in ((0.92, 0.050, V(0.030, 0.034, 0.050)), (0.55, 0.066, V(0.034, 0.040, 0.058)), (0.18, 0.074, V(0.036, 0.036, 0.052))):
                b.ellipsoid(base.lerp(top, t) - across * drop, size, Matrix.Rotation(-0.75, 3, "X"))

        skull = breed.skull
        size = breed.skull_size
        b.ellipsoid(skull, size, None, 16, 9)
        b.ellipsoid(skull + V(0.0, size.y * 0.5, size.z * 0.55), V(size.x * 0.78, size.y * 0.36, size.z * 0.4))  # brow
        if heavy:
            b.ellipsoid(skull + V(0.0, 0.050, -0.056), V(0.032, 0.032, 0.044))  # the peak at the back of the skull
        # The muzzle. The lower jaw is a part of its own (`jaw`).
        muzzle = [(skull + V(0.0, y, z), X * rx, Y * ry) for z, y, rx, ry in breed.muzzle]
        b.tube([(skull + V(0.0, 0.0, 0.0), X * size.x * 0.8, Y * size.y * 0.8)] + muzzle + dome(muzzle[-1], Z, muzzle[-1][1].x * 0.55, 3), 14)
        b.ellipsoid(skull + breed.nose[0], breed.nose[1], None, 8, 5)
        if heavy:
            for side in (1.0, -1.0):
                # The hanging lips, deepest at the corner of the mouth
                b.ellipsoid(skull + V(side * 0.034, -0.064, 0.165), V(0.019, 0.040, 0.085), None, 8, 5)
                b.ellipsoid(skull + V(side * 0.044, -0.066, 0.070), V(0.021, 0.050, 0.046), None, 8, 5)
                if low:
                    continue
                # A fold from the corner of each eye down the cheek
                b.strand([skull + V(side * x, y, z) for x, y, z in ((0.056, 0.012, 0.040), (0.066, -0.022, 0.046), (0.058, -0.056, 0.064))],
                         [0.009, 0.011, 0.010])
            # Its brow, in folds that sag in the middle
            for rise, radius in (() if low else ((0.50, 0.010), (0.82, 0.010), (1.14, 0.009))):
                points = []
                for a in (-0.95, -0.5, 0.0, 0.5, 0.95):
                    e = rise - 0.13 * math.cos(a * 1.4)
                    points.append(skull + V(size.x * math.sin(a), size.y * math.sin(e) * math.cos(a) + 0.006, size.z * math.cos(e) * math.cos(a) + 0.004))
                b.strand(points, [radius * 0.8, radius, radius, radius, radius * 0.8])
        else:
            for side in (1.0, -1.0):
                b.ellipsoid(skull + V(side * 0.016, -0.022, 0.105), V(0.010, 0.014, 0.062), None, 8, 5)  # thin lips
                b.ellipsoid(skull + V(side * 0.030, -0.006, 0.030), V(0.016, 0.022, 0.034), None, 8, 5)  # cheek

        b.strand([breed.tail_root + V(0.0, 0.03, 0.05)] + breed.tail, breed.tail_shape, 10)

        for suffix, joints in breed.legs.items():
            fore = suffix[1] == "f"
            limb(b, joints, breed.fore_shape if fore else breed.hind_shape)
            side = 1.0 if joints[0].x > 0.0 else -1.0
            width, length = breed.paw
            paw = joints[3]
            if not low:
                # The point of the elbow, or of the hock, standing out behind
                knob = joints[1] + V(0.0, 0.012, -0.030) if fore else joints[2] + V(0.0, 0.020, -0.022)
                b.ellipsoid(knob, V(width * 0.62, 0.026, 0.022), None, 8, 5)
            b.ellipsoid(paw + V(0.0, -0.008, length * 0.5), V(width, 0.026, length), None, 10, 6)
            for toe in (() if low else (-1.5, -0.5, 0.5, 1.5)):
                b.ellipsoid(paw + V(toe * width * 0.42, -0.014, length * 1.22 - abs(toe) * length * 0.16), V(width * 0.27, 0.017, 0.022), None, 8, 5)
        return furred(breed, b, (0.004, 5, 12000 if heavy else 10000))
    return shapes


def jaw(breed):
    def shapes(b):
        # The lower jaw, lighter than the muzzle and shut up inside its lips. It is
        # not fused to the head, so that it can drop open.
        rings = [(breed.skull + V(0.0, y, z), X * rx, Y * ry) for z, y, rx, ry in breed.jaw_shape]
        b.tube(dome(rings[0], -Z, 0.012, 2)[::-1] + rings + dome(rings[-1], Z, 0.018, 3), 12)
        return furred(breed, b, (0.003, 2, 500))
    return shapes


def ear_curve(breed, t, side):
    root, mid, end = breed.ear
    bend = mid * 2.0 - (root + end) * 0.5
    at = root.lerp(bend, t).lerp(bend.lerp(end, t), t)
    return V(at.x * side, at.y, at.z)


def ears(breed):
    def shapes(b):
        for side in (1.0, -1.0):
            rings = []
            if breed.heavy:
                # Long, low-set, hanging past the jaw: leather, thin and wide, curling in on itself towards the end
                for t, half, thick, curl in ((0.0, 0.026, 0.011, 0.0), (0.10, 0.042, 0.010, 0.0), (0.30, 0.058, 0.009, 0.1), (0.55, 0.066, 0.008, 0.25),
                                             (0.78, 0.060, 0.007, 0.45), (0.93, 0.044, 0.006, 0.6), (1.0, 0.026, 0.005, 0.7)):
                    turn = Matrix.Rotation(-side * curl, 3, "Y")
                    rings.append((ear_curve(breed, t, side), turn @ Z * half, turn @ X * thick))
                b.tube(dome(rings[0], Y, 0.008, 2)[::-1] + rings + dome(rings[-1], -Y, 0.012, 2), 10)
            else:
                # Tall and pointed, broad at the base, the open side to the front and a little out
                wide = V(side * 0.90, 0.0, -0.42).normalized()
                face = V(side * 0.42, 0.0, 0.90).normalized()
                for t, half, thick in ((0.0, 0.028, 0.014), (0.12, 0.040, 0.011), (0.35, 0.042, 0.008), (0.60, 0.034, 0.006),
                                       (0.82, 0.019, 0.005), (0.95, 0.009, 0.004), (1.0, 0.004, 0.003)):
                    rings.append((ear_curve(breed, t, side), wide * half, face * thick))
                b.tube(dome(rings[0], -Y, 0.008, 2)[::-1] + rings, 10)
        lay_fur(breed, b.bm, True)
    return shapes


def ear_linings(breed):
    def shapes(b):
        # The bare inside of a standing ear
        for side in (1.0, -1.0):
            wide = V(side * 0.90, 0.0, -0.42).normalized()
            face = V(side * 0.42, 0.0, 0.90).normalized()
            rings = []
            for t, half in ((0.10, 0.014), (0.22, 0.029), (0.40, 0.031), (0.60, 0.024), (0.80, 0.013), (0.92, 0.004)):
                rings.append((ear_curve(breed, t, side) + face * 0.0045, wide * half, face * 0.0035))
            b.tube(rings, 8)
    return shapes


def palate(breed):
    def shapes(b):
        # The roof of the mouth, standing just proud of the underside of the muzzle: inside the jaw until it opens
        y, length, _, width = breed.mouth
        b.ellipsoid(breed.skull + V(0.0, y, length * 0.42), V(width * 0.8, 0.006, length * 0.36), None, 8, 5)
    return shapes


def tongue(breed):
    def shapes(b):
        y, length, _, width = breed.mouth
        b.ellipsoid(breed.skull + V(0.0, y + 0.012, length * 0.42), V(width * 0.62, 0.006, length * 0.40), None, 8, 5)
    return shapes


def fangs(breed):
    def shapes(b):
        # The upper teeth: a fang at each front corner, which shows under the lip, and the cheek teeth behind it
        y, length, front, back = breed.mouth
        scale = 1.0 if breed.heavy else 0.75
        for side in (1.0, -1.0):
            for share, tall, radius in ((0.82, 0.024, 0.0055), (0.66, 0.010, 0.0040), (0.54, 0.010, 0.0045), (0.42, 0.011, 0.0050), (0.30, 0.010, 0.0050)):
                x = back + (front - back) * share
                base = breed.skull + V(side * x, y + 0.004, length * share)
                kit.spike(b, base, base - Y * tall * scale, radius * scale, 5)
    return shapes


def teeth(breed):
    def shapes(b):
        # The lower teeth, which go up inside the muzzle when the mouth shuts
        y, length, front, back = breed.mouth
        scale = 1.0 if breed.heavy else 0.75
        for side in (1.0, -1.0):
            for share, tall, radius in ((0.72, 0.022, 0.0055), (0.57, 0.009, 0.0040), (0.45, 0.009, 0.0045), (0.33, 0.010, 0.0050)):
                x = (back + (front - back) * share) * 0.8
                base = breed.skull + V(side * x, y + 0.008, length * share)
                kit.spike(b, base, base + Y * tall * scale, radius * scale, 5)
    return shapes


def eyes(breed):
    def shapes(b):
        at, radius = breed.eye
        for side in (1.0, -1.0):
            b.ellipsoid(breed.skull + V(side * at.x, at.y, at.z), V(radius, radius * (1.0 if breed.heavy else 0.8), radius), None, 8, 5)
    return shapes


def weights(breed):
    tail = breed.tail
    tail_names = ["pelvis", "tail", "tail_1", "tail_2", "tail_3"]

    def weigh(part, p):
        if part in ("jaw", "tongue", "teeth"):
            return {"jaw": 1.0}
        if part in ("palate", "fangs", "eyes"):
            return {"head": 1.0}
        if part in ("ears", "linings"):
            suffix = "_l" if p.x >= 0.0 else "_r"
            side = 1.0 if p.x >= 0.0 else -1.0
            root, mid, end = (V(j.x * side, j.y, j.z) for j in breed.ear)
            along = (p - root).dot((end - root).normalized())
            joint = (mid - root).dot((end - root).normalized())
            hung = blend(0.0, 0.03, along)
            tip = blend(joint - 0.02, joint + 0.02, along)
            return {"head": 1.0 - hung, "ear" + suffix: hung * (1.0 - tip), "ear_tip" + suffix: hung * tip}
        off, along = chain_param(p, tail)
        if p.z < tail[0].z and off < 0.05:
            # How far past each joint of the tail: the pelvis, and then each bone in turn
            past = [1.0, blend(0.0, 0.6, along)] + [blend(k - 0.3, k + 0.3, along) for k in (1, 2, 3)] + [0.0]
            return {name: past[i] - past[i + 1] for i, name in enumerate(tail_names)}
        front = blend(-0.12, 0.08, p.z)
        trunk = {"chest": front, "pelvis": 1.0 - front}
        base, top = breed.neck, breed.head
        reach = (p - base).dot((top - base).normalized()) / (top - base).length
        if reach > 0.0 and p.z > base.z - 0.04:
            neck = blend(0.02, 0.36, reach)
            upper = blend(0.36, 0.70, reach)
            head = blend(0.74, 1.04, reach)
            return {"chest": 1.0 - neck, "neck": neck * (1.0 - upper), "neck_1": neck * upper * (1.0 - head), "head": neck * upper * head}
        suffix, leg = leg_share(breed, p)
        joints = breed.legs[suffix]
        along = chain_param(V(joints[0].x, p.y, p.z), joints)[1]
        spans = [(b - a).length for a, b in zip(joints, joints[1:])]
        low = blend(1.0 - 0.045 / spans[0], 1.0 + 0.045 / spans[1], along)
        hock = blend(2.0 - 0.035 / spans[1], 2.0 + 0.035 / spans[2], along)
        paw = blend(joints[3].y + 0.05, joints[3].y + 0.012, p.y)
        made = {bone: weight * (1.0 - leg) for bone, weight in trunk.items()}
        made["upper" + suffix] = leg * (1.0 - low)
        made["lower" + suffix] = leg * low * (1.0 - hock)
        made["hock" + suffix] = leg * low * hock * (1.0 - paw)
        made["paw" + suffix] = leg * low * hock * paw
        return made
    return weigh


def bones(breed):
    listed = [
        ("body", breed.body, None), ("chest", breed.chest, "body"), ("pelvis", breed.pelvis, "body"),
        ("neck", breed.neck, "chest"), ("neck_1", breed.neck_1, "neck"), ("head", breed.head, "neck_1"), ("jaw", breed.jaw, "head"),
    ]
    for side, suffix in ((1.0, "_l"), (-1.0, "_r")):
        root, mid, end = (V(j.x * side, j.y, j.z) for j in breed.ear)
        listed.append(("ear" + suffix, root, "head"))
        listed.append(("ear_tip" + suffix, mid, "ear" + suffix))
        # (carries nothing: it marks where the ear ends, for the rig)
        listed.append(("ear_end" + suffix, end, "ear_tip" + suffix))
    # The tail is a chain, each bone hanging from the one before; the last marks its tip
    chain = ["pelvis", "tail", "tail_1", "tail_2", "tail_3", "tail_end"]
    for i, joint in enumerate(breed.tail):
        listed.append((chain[i + 1], joint, chain[i]))
    for suffix, joints in breed.legs.items():
        for bone, joint in zip(("upper", "lower", "hock", "paw"), joints):
            listed.append((bone + suffix, joint, "body"))
    return listed


def parts(breed):
    # The coat and the jaw fuse themselves (see `furred`), so nothing here asks for it.
    # The same list builds the demade hound.
    listed = [
        ("coat", 0, coat(breed), None), ("jaw", 0, jaw(breed), None), ("ears", 0, ears(breed), None),
        ("palate", 1, palate(breed), None), ("tongue", 1, tongue(breed), None),
        ("fangs", 2, fangs(breed), None), ("teeth", 2, teeth(breed), None), ("eyes", 3, eyes(breed), None),
    ]
    if not breed.heavy:
        listed.append(("linings", 4, ear_linings(breed), None))
    return listed


if __name__ == "__main__":
    for low in (False, True):
        kit.LOW = low
        for breed in (BLOODHOUND, PHARAOH):
            kit.export(breed.name + ("_lo" if low else ""), bones(breed), parts(breed), weights(breed), breed.materials)
