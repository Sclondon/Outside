"""Builds the camel and exports it for Godot.

Run from the project root:
    blender --background --python tools/build_camel.py
    blender --background --python tools/build_camel.py -- <preview folder>

Writes models/camel.glb (a dromedary, the one-humped camel of Egypt) and a
demade models/camel_lo.glb, with editable copies in tools/.

It is built the way the hounds and the cats are (tools/build_hound.py, whose
`Breed` and joint tools this uses, on the kit in tools/build_character.py),
from one list of measurements (`DROMEDARY` below), and its bones have the
hound's names wherever a camel has the same part, so that scripts/camel_rig.gd
can use the hound rig's leg solver, springs and helpers:

    body, chest, pelvis, neck, neck_1, head, jaw, ear_*/ear_tip_*/ear_end_*,
    tail, tail_1..3, tail_end, and for each leg upper, lower, hock, paw.

Each leg is three bones and a foot, as a hound's is, though they are not the
same lengths at all:

    fore: `upper` (shoulder to elbow, up against the ribs), `lower` (the forearm,
          down to the "knee", which is its wrist), `hock` (the cannon), `paw`
    hind: `upper` (thigh, hip to stifle), `lower` (shank), `hock` (the cannon), `paw`

The `paw` is at the fetlock; the pastern and the broad two-toed pad hang from it.

What a camel has that a hound has not:

- A neck in four pieces (`neck`, `neck_1`, `neck_2`, `neck_3`), which leaves the
  chest low, dips, and then rises: the S it is carried in.
- `lid_l`, `lid_r`: the heavy upper eyelids, each turned down over its eye.
- `seat`: nothing hangs from it. It marks where a rider sits, on top of the hump.

Its tack is separate meshes on the same skeleton, which the rig shows or hides:
`camel_saddle` (a blanket with tassels, and a riding saddle on a wooden frame
over the hump, with its girths), `camel_halter` (a rope headstall), `camel_lead`
(the lead rope, looped up round the neck) and `camel_packs` (saddlebags, a
bedroll and a waterskin).

The hide is thick and bare where it kneels: `pads` are the callus on the chest
(the pedestal it rests on when it is couched), the knees, the elbows and the
stifles, and the soles of its feet.

Everything is in Godot space (metres, Y up, facing +Z, +X its left). No mesh
object is named for a bone: they are `camel`, `camel_saddle` and so on.
"""

import math
import os
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
COAT, HIDE, PAD, EYE, DARK, MOUTH, TEETH, BLANKET, TRIM, LEATHER, WOOD, ROPE, CANVAS = range(13)
NECK_BONES = ["neck", "neck_1", "neck_2", "neck_3"]
TAIL_BONES = ["tail", "tail_1", "tail_2", "tail_3"]
TACK = ("saddle", "halter", "lead", "packs")


def V(x, y, z):
    return Vector((x, y, z))


DROMEDARY = dog.Breed(
    name="camel",
    materials=[("coat", (0.74, 0.58, 0.38)), ("hide", (0.63, 0.49, 0.33)), ("pad", (0.34, 0.28, 0.23)),
               ("eye", (0.09, 0.06, 0.045)), ("dark", (0.07, 0.055, 0.05)), ("mouth", (0.50, 0.24, 0.24)), ("teeth", (0.86, 0.80, 0.62)),
               ("blanket", (0.56, 0.13, 0.11)), ("trim", (0.86, 0.66, 0.22)), ("leather", (0.36, 0.22, 0.13)),
               ("wood", (0.44, 0.31, 0.19)), ("rope", (0.76, 0.69, 0.52)), ("canvas", (0.63, 0.58, 0.46))],
    body=V(0.0, 1.42, 0.0), chest=V(0.0, 1.42, 0.42), pelvis=V(0.0, 1.50, -0.50),
    # (along the body, centre height, half width, half height): a deep chest between the forelegs, the belly
    # drawn up to the flank, a narrow sloping rump. It stands about 1.7 m at the withers.
    trunk=[(-0.83, 1.50, 0.10, 0.12), (-0.75, 1.47, 0.19, 0.21), (-0.60, 1.44, 0.25, 0.28), (-0.40, 1.42, 0.27, 0.27),
           (-0.15, 1.38, 0.29, 0.31), (0.10, 1.33, 0.30, 0.33), (0.35, 1.29, 0.29, 0.32), (0.55, 1.30, 0.26, 0.29),
           (0.70, 1.34, 0.20, 0.22), (0.78, 1.36, 0.13, 0.14)],
    # The hump: where its middle is, and how far it reaches across, up and along
    hump=(V(0.0, 1.68, -0.08), V(0.21, 0.31, 0.47)),
    # Shoulder, elbow, knee, fetlock; hip, stifle, hock, fetlock (the left legs: the right are their mirror)
    fore=[V(0.18, 1.36, 0.60), V(0.18, 1.06, 0.34), V(0.18, 0.56, 0.44), V(0.18, 0.12, 0.46)],
    hind=[V(0.17, 1.42, -0.62), V(0.17, 1.02, -0.46), V(0.17, 0.62, -0.74), V(0.17, 0.12, -0.68)],
    # (how far down the leg, counted in joints; half width; half depth; forward offset)
    fore_shape=[(-0.3, 0.080, 0.130, 0.0), (0.0, 0.092, 0.150, 0.0), (0.5, 0.086, 0.125, 0.0), (1.0, 0.070, 0.098, -0.012),
                (1.3, 0.062, 0.082, 0.0), (1.7, 0.050, 0.060, 0.0), (2.0, 0.058, 0.068, 0.008), (2.3, 0.041, 0.046, 0.0),
                (2.7, 0.038, 0.043, 0.0), (3.0, 0.047, 0.052, 0.0)],
    hind_shape=[(-0.25, 0.088, 0.170, 0.0), (0.0, 0.104, 0.200, 0.0), (0.45, 0.100, 0.172, 0.0), (0.85, 0.080, 0.118, 0.006),
                (1.0, 0.072, 0.102, 0.006), (1.3, 0.062, 0.088, -0.006), (1.7, 0.046, 0.058, 0.0), (2.0, 0.050, 0.066, -0.012),
                (2.3, 0.039, 0.047, 0.0), (2.7, 0.036, 0.043, 0.0), (3.0, 0.045, 0.050, 0.0)],
    # The foot: half its width, and its length forward of the fetlock (about 19 cm across and 18 long)
    paw=(0.095, 0.19),
    # The neck, joint by joint, and then the head at the top of it
    neck=V(0.0, 1.36, 0.72), neck_line=[V(0.0, 1.29, 1.01), V(0.0, 1.50, 1.26), V(0.0, 1.83, 1.36)], head=V(0.0, 2.12, 1.37),
    # (how far up the neck, counted in joints; half width; half depth; offset towards its upper side): deep, and flat-sided
    neck_shape=[(-0.45, 0.150, 0.200, 0.0), (0.0, 0.138, 0.188, 0.0), (0.5, 0.118, 0.162, -0.008), (1.0, 0.102, 0.142, -0.010),
                (1.5, 0.094, 0.124, -0.006), (2.0, 0.087, 0.112, 0.0), (2.5, 0.081, 0.102, 0.0), (3.0, 0.077, 0.096, 0.0),
                (3.5, 0.073, 0.092, 0.0), (4.0, 0.070, 0.088, 0.0), (4.2, 0.058, 0.070, 0.0)],
    skull_at=V(0.0, 0.035, 0.085), skull_size=V(0.084, 0.082, 0.118),
    # (along the muzzle from the skull, height, half width, half height): long, narrow in the middle, heavy at the lips
    muzzle=[(0.10, -0.008, 0.074, 0.074), (0.19, -0.026, 0.060, 0.064), (0.28, -0.040, 0.054, 0.056), (0.36, -0.048, 0.056, 0.052)],
    jaw_at=V(0.0, -0.062, 0.010),
    jaw_shape=[(-0.03, -0.084, 0.056, 0.034), (0.10, -0.098, 0.046, 0.027), (0.24, -0.106, 0.039, 0.023), (0.345, -0.104, 0.038, 0.022)],
    # The line the teeth meet on, the length of the mouth, and its half width at the front and at the back
    mouth=(-0.086, 0.36, 0.026, 0.036),
    eye=(V(0.071, 0.030, 0.098), 0.026),
    # Each ear: where it roots, the joint part way along it, and its end. Small and round.
    ear_at=[V(0.064, 0.060, -0.062), V(0.090, 0.104, -0.088), V(0.108, 0.140, -0.104)],
    tail_root=V(0.0, 1.50, -0.85),
    tail_at=[(0.0, 0.0, 0.0), (0.0, -0.13, -0.05), (0.0, -0.27, -0.07), (0.0, -0.41, -0.07), (0.0, -0.56, -0.06)],
    tail_shape=[0.038, 0.034, 0.026, 0.020, 0.026, 0.012],
)
DROMEDARY.neck_chain = [DROMEDARY.neck] + DROMEDARY.neck_line + [DROMEDARY.head]
DROMEDARY.seat = V(0.0, DROMEDARY.hump[0].y + DROMEDARY.hump[1].y + 0.05, DROMEDARY.hump[0].z)


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


def hull(breed, z, angle, off=0.0):
    """A point on the outside of the body and the hump together, at `z` along it and `angle` round it from
    the top of the back (towards its left), stood `off` clear of it. What lies on its back is laid on this."""
    cy, rx, ry = trunk_at(breed, z)
    s, c = math.sin(angle), math.cos(angle)
    r = 1.0 / math.sqrt((s / rx) ** 2 + (c / ry) ** 2)
    centre, size = breed.hump
    k = 1.0 - ((z - centre.z) / size.z) ** 2
    if k > 0.0:
        ex, ey = size.x * math.sqrt(k), size.y * math.sqrt(k)
        a = (s / ex) ** 2 + (c / ey) ** 2
        b = 2.0 * c * (cy - centre.y) / ey ** 2
        d = b * b - 4.0 * a * (((cy - centre.y) / ey) ** 2 - 1.0)
        if d >= 0.0:
            r = max(r, (-b + math.sqrt(d)) / (2.0 * a))
    return V((r + off) * s, cy + (r + off) * c, z)


def neck_length(breed, along):
    """How far up the neck `along` is (counted in joints), in metres."""
    chain = breed.neck_chain
    whole = min(int(along), len(chain) - 2)
    return sum((b - a).length for a, b in zip(chain[:whole], chain[1:])) + (chain[whole + 1] - chain[whole]).length * (along - whole)


def neck_share(breed, p):
    """How much of a point belongs to the neck and the head rather than the chest, how far up the neck it is
    (counted in joints), and how much of it is head."""
    chain = breed.neck_chain
    off, along = dog.chain_param(V(0.0, p.y, p.z), chain)
    past = blend(0.0, 0.6, along) * blend(breed.neck.z - 0.12, breed.neck.z - 0.02, p.z)
    last = len(chain) - 1
    head = max(blend(last - 0.45, last - 0.05, along), blend(breed.head.z + 0.05, breed.head.z + 0.13, p.z) * blend(breed.head.y - 0.26, breed.head.y - 0.16, p.y))
    return past, along, head


def leg_share(breed, p):
    """Which leg a point is nearest, and how much of it hangs from that leg rather than the trunk."""
    suffix = ("_f" if p.z > 0.0 else "_r") + ("l" if p.x >= 0.0 else "r")
    joints = breed.legs[suffix]
    top = joints[0]
    off = dog.chain_param(V(top.x, p.y, p.z), joints)[0]
    if p.y < joints[3].y + 0.10:
        # (a foot is all leg, however broad it is)
        return suffix, 1.0
    # Only what lies along the leg belongs to it, not the belly beside it
    return suffix, blend(top.y + 0.10, top.y - 0.24, p.y) * blend(0.23, 0.15, math.hypot(p.x - top.x, off / 1.8))


def lay_fur(breed, bm, ears=False):
    """Gives the coat the texture coordinates the fur shader (scripts/fur.gd) reads: (how far along the lie
    of the hair, how far across it), in metres. As the hounds': back along the body from the nose to the tail
    and down each leg and ear; but a camel's neck stands up, so along it the hair is measured down the neck
    itself and not along the ground."""
    uv = bm.loops.layers.uv.verify()
    whole = neck_length(breed, len(breed.neck_chain) - 1)

    def around(x, y, near_x, near_y, radius):
        near = math.atan2(near_x, near_y)
        return (near + (math.atan2(x, y) - near + math.pi) % math.tau - math.pi) * radius

    def lie(p):
        """How far forward along the lie of the coat a point is, and the middle it is measured round."""
        past, along, head = neck_share(breed, p)
        at = breed.neck_chain[min(int(along), len(breed.neck_chain) - 2)]
        to = breed.neck_chain[min(int(along), len(breed.neck_chain) - 2) + 1]
        centre = at.lerp(to, along - min(int(along), len(breed.neck_chain) - 2))
        up_neck = breed.neck.z + neck_length(breed, along) + (p.z - breed.head.z) * head
        forward = p.z + (up_neck - p.z) * past
        return forward, V(0.0, breed.body.y + 0.02 + (centre.y - breed.body.y - 0.02) * past, 0.0), past

    for face in bm.faces:
        near = kit.from_blender(face.calc_center_median())
        suffix, _ = leg_share(breed, near)
        joints = breed.legs[suffix]
        hip = joints[0]
        out = 1.0 if hip.x > 0.0 else -1.0
        _, near_axis, near_past = lie(near)
        for loop in face.loops:
            p = kit.from_blender(loop.vert.co)
            if ears:
                root = breed.ear[0]
                # (far forward along the lie of the coat, where the fur shader keeps the hair short)
                loop[uv].uv = ((p - V(root.x * (1.0 if p.x >= 0.0 else -1.0), root.y, root.z)).length - 9.0, p.z)
                continue
            leg = leg_share(breed, p)[1]
            forward, axis, past = lie(p)
            # (round the neck it is measured from its upper side, which is behind it where it stands up)
            turn = (p.y - axis.y) * (1.0 - past) + (breed.neck_chain[2].z - p.z) * past
            near_turn = (near.y - near_axis.y) * (1.0 - near_past) + (breed.neck_chain[2].z - near.z) * near_past
            trunk = (-forward, around(p.x, turn, near.x, near_turn, 0.25 - 0.14 * past))
            limb_uv = (hip.y - p.y - hip.z, around(p.z - dog.leg_axis(joints, p.y), (p.x - hip.x) * out,
                                                   near.z - dog.leg_axis(joints, near.y), (near.x - hip.x) * out, 0.07))
            loop[uv].uv = (trunk[0] + (limb_uv[0] - trunk[0]) * leg, trunk[1] + (limb_uv[1] - trunk[1]) * leg)


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


def limb(b, joints, stations, cap, segments=12):
    """A leg, or the neck: a tube that follows the joints, its rings square to the bone at each."""
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
    b.tube(dome(rings[0], -directions[0], cap)[::-1] + rings, segments)


def sheet(b, rows):
    """Cloth: a surface through rows of points, seen from both sides (it is made twice, once facing each way)."""
    for flip in (False, True):
        made = [[b.bm.verts.new(kit.to_blender(p)) for p in row] for row in rows]
        for upper, lower in zip(made, made[1:]):
            for i in range(len(upper) - 1):
                corners = (upper[i], upper[i + 1], lower[i + 1], lower[i])
                b.bm.faces.new(corners[::-1] if flip else corners)


def toe_at(joints, side):
    """Where the pad of a foot lies: forward of the fetlock and under it."""
    return joints[3] + V(0.0, 0.0, 0.085)


def coat(breed):
    def shapes(b):
        low = kit.LOW
        rings = [kit.lengthwise(*ring) for ring in breed.trunk]
        b.tube(dome(rings[0], -Z, 0.04)[::-1] + rings + dome(rings[-1], Z, 0.05), 18)
        # The hump, leaning back a little
        centre, size = breed.hump
        b.ellipsoid(centre, size, Matrix.Rotation(0.10, 3, "X"), 14, 8)
        # The breast, low between the forelegs, and the muscle over each shoulder and haunch
        b.ellipsoid(V(0.0, 1.22, 0.66), V(0.15, 0.20, 0.13))
        for side in (() if low else (1.0, -1.0)):
            arm = breed.fore[0].lerp(breed.fore[1], 0.35)
            b.ellipsoid(V(side * (arm.x + 0.02), arm.y + 0.08, arm.z + 0.0), V(0.085, 0.26, 0.17), Matrix.Rotation(0.42, 3, "X"))
            thigh = breed.hind[0].lerp(breed.hind[1], 0.35)
            b.ellipsoid(V(side * (thigh.x + 0.005), thigh.y + 0.05, thigh.z + 0.0), V(0.105, 0.28, 0.22), Matrix.Rotation(-0.40, 3, "X"))

        limb(b, breed.neck_chain, breed.neck_shape, 0.05, 14)

        # The head: small for the beast, a domed brow over deep eye sockets, a long muzzle
        skull = breed.skull
        size = breed.skull_size
        b.ellipsoid(skull, size, None, 16, 9)
        b.ellipsoid(skull + V(0.0, size.y * 0.55, size.z * 0.30), V(size.x * 0.72, size.y * 0.42, size.z * 0.62))  # brow
        muzzle = [(skull + V(0.0, y, z), X * rx, Y * ry) for z, y, rx, ry in breed.muzzle]
        b.tube([(skull, X * size.x * 0.86, Y * size.y * 0.84)] + muzzle + dome(muzzle[-1], Z, 0.040, 3), 14)
        at, radius = breed.eye
        for side in (1.0, -1.0):
            # The ridge of bone over each eye, and the cheek under it
            b.ellipsoid(skull + V(side * (at.x - 0.012), at.y + 0.026, at.z + 0.004), V(0.022, 0.014, 0.040), None, 8, 5)
            b.ellipsoid(skull + V(side * 0.052, -0.040, 0.050), V(0.036, 0.046, 0.070), None, 8, 5)
            if not low:
                # The nostril's rim, standing a little proud at each side of the nose
                b.ellipsoid(skull + V(side * 0.030, -0.014, 0.372), V(0.022, 0.020, 0.030), None, 8, 5)

        b.strand([breed.tail_root + V(0.0, 0.03, 0.07)] + breed.tail, breed.tail_shape, 8)

        for suffix, joints in breed.legs.items():
            fore = suffix[1] == "f"
            limb(b, joints, breed.fore_shape if fore else breed.hind_shape, 0.08)
            width, length = breed.paw
            foot = joints[3]
            if not low:
                # The point of the elbow, or of the hock, standing out behind
                knob = joints[1] + V(0.0, 0.02, -0.07) if fore else joints[2] + V(0.0, 0.04, -0.05)
                b.ellipsoid(knob, V(0.045, 0.060, 0.050), None, 8, 5)
            # The pastern, sloping forward to the foot; and the foot, two broad toes on one pad
            b.ellipsoid(foot + V(0.0, -0.035, 0.035), V(0.046, 0.070, 0.066), Matrix.Rotation(-0.6, 3, "X"), 8, 5)
            pad = toe_at(joints, 1.0)
            b.ellipsoid(V(pad.x, 0.042, pad.z - 0.01), V(width * 0.90, 0.042, length * 0.50), None, 12, 6)
            for toe in (() if low else (-1.0, 1.0)):
                b.ellipsoid(V(pad.x + toe * width * 0.47, 0.044, pad.z + length * 0.20), V(width * 0.50, 0.044, length * 0.40), None, 10, 6)
        return furred(breed, b, (0.008, 4, 15000))
    return shapes


def jaw(breed):
    def shapes(b):
        # The lower jaw, not fused to the head, so that it can drop open and go from side to side
        rings = [(breed.skull + V(0.0, y, z), X * rx, Y * ry) for z, y, rx, ry in breed.jaw_shape]
        b.tube(dome(rings[0], -Z, 0.020, 2)[::-1] + rings + dome(rings[-1], Z, 0.022, 3), 12)
        return furred(breed, b, (0.005, 2, 600))
    return shapes


def lips(breed):
    def shapes(b):
        # The upper lip, split down the middle into two lobes that hang over the lower; and the lower, which droops
        skull = breed.skull
        for side in (1.0, -1.0):
            b.ellipsoid(skull + V(side * 0.027, -0.070, 0.378), V(0.027, 0.030, 0.034), Matrix.Rotation(side * 0.18, 3, "Z"), 10, 6)
    return shapes


def lower_lip(breed):
    def shapes(b):
        b.ellipsoid(breed.skull + V(0.0, -0.112, 0.352), V(0.036, 0.022, 0.036), Matrix.Rotation(0.25, 3, "X"), 10, 5)
    return shapes


def nostrils(breed):
    def shapes(b):
        # Slits, which it can shut against blown sand
        for side in (1.0, -1.0):
            b.ellipsoid(breed.skull + V(side * 0.034, -0.012, 0.392), V(0.007, 0.006, 0.020), Matrix.Rotation(-side * 0.5, 3, "Y"), 8, 4)
    return shapes


def eyes(breed):
    def shapes(b):
        at, radius = breed.eye
        for side in (1.0, -1.0):
            b.ellipsoid(breed.skull + V(side * at.x, at.y, at.z), V(radius * 0.8, radius, radius), None, 10, 6)
    return shapes


def lid_at(breed, side):
    at, _ = breed.eye
    return breed.skull + V(side * at.x, at.y, at.z)


def lids(breed):
    def shapes(b):
        # The upper lid: heavy, and half down over the eye as it stands. The rig turns it about the eye.
        _, radius = breed.eye
        for side in (1.0, -1.0):
            centre = lid_at(breed, side)
            rings = []
            for k in range(5):
                rise = 0.20 + k * 0.30
                c, s = math.cos(rise), math.sin(rise)
                rings.append((centre + V(side * radius * 0.30 * c, radius * 1.16 * s, 0.0), X * (side * radius * 0.86 * c), Z * (radius * 1.22 * c)))
            b.tube(rings, 10)
    return shapes


def lashes(breed):
    def shapes(b):
        # Long lashes, two rows of them: a dark fringe along the edge of the lid
        _, radius = breed.eye
        for side in (1.0, -1.0):
            centre = lid_at(breed, side)
            points = []
            for k in range(5):
                a = -1.0 + k * 0.5
                points.append(centre + V(side * radius * 1.02 * math.cos(a * 0.9), radius * 0.26, radius * 1.26 * math.sin(a * 0.9)))
            b.strand(points, [0.003, 0.0055, 0.0065, 0.0055, 0.003], 5)
    return shapes


def ear_frame(side):
    return V(side * 0.80, 0.0, -0.60).normalized(), V(side * 0.60, 0.0, 0.80).normalized()


def ears(breed):
    def shapes(b):
        for side in (1.0, -1.0):
            # Small, round and thick with hair, the open side to the front and out
            wide, face = ear_frame(side)
            rings = []
            for t, half, thick in ((0.0, 0.026, 0.016), (0.15, 0.034, 0.014), (0.40, 0.037, 0.011), (0.65, 0.033, 0.009),
                                   (0.85, 0.024, 0.007), (1.0, 0.012, 0.006)):
                rings.append((dog.ear_curve(breed, t, side), wide * half, face * thick))
            b.tube(dome(rings[0], -Y, 0.010, 2)[::-1] + rings + dome(rings[-1], Y, 0.008, 2), 10)
        lay_fur(breed, b.bm, True)
    return shapes


def ear_linings(breed):
    def shapes(b):
        for side in (1.0, -1.0):
            wide, face = ear_frame(side)
            rings = []
            for t, half in ((0.14, 0.012), (0.30, 0.024), (0.50, 0.026), (0.70, 0.020), (0.88, 0.009)):
                rings.append((dog.ear_curve(breed, t, side) + face * 0.008, wide * half, face * 0.005))
            b.tube(rings, 8)
    return shapes


def palate(breed):
    def shapes(b):
        y, length, _, width = breed.mouth
        b.ellipsoid(breed.skull + V(0.0, y + 0.004, length * 0.45), V(width * 0.9, 0.008, length * 0.42), None, 8, 5)
    return shapes


def tongue(breed):
    def shapes(b):
        y, length, _, width = breed.mouth
        b.ellipsoid(breed.skull + V(0.0, y - 0.004, length * 0.44), V(width * 0.7, 0.008, length * 0.42), None, 8, 5)
    return shapes


def teeth(breed):
    def shapes(b):
        # The lower front teeth, long and yellow, which show when it opens its mouth to complain
        y, length, front, _ = breed.mouth
        for k in (-1.5, -0.5, 0.5, 1.5):
            base = breed.skull + V(k * front * 0.42, y - 0.016, length * 0.90 - abs(k) * 0.004)
            b.tube([(base + V(0.0, t * 0.018, t * 0.006), X * 0.0058, Z * 0.0040) for t in (0.0, 0.5, 1.0)], 5)
    return shapes


def pads(breed):
    def shapes(b):
        # Callus, wherever it bears on the ground when it is couched: the pedestal under its chest,
        # each knee and elbow, each stifle; and the sole of each foot, with a nail at the end of each toe
        b.ellipsoid(V(0.0, 0.985, 0.34), V(0.12, 0.045, 0.16))
        for suffix, joints in breed.legs.items():
            fore = suffix[1] == "f"
            width, length = breed.paw
            if fore:
                b.ellipsoid(joints[2] + V(0.0, 0.0, 0.050), V(0.040, 0.062, 0.030), None, 8, 5)
                b.ellipsoid(joints[1] + V(0.0, 0.0, -0.105), V(0.030, 0.040, 0.024), None, 8, 5)
            else:
                b.ellipsoid(joints[1] + V(0.0, -0.01, 0.092), V(0.040, 0.056, 0.030), None, 8, 5)
            pad = toe_at(joints, 1.0)
            b.ellipsoid(V(pad.x, 0.012, pad.z + 0.01), V(width * 0.98, 0.016, length * 0.60), None, 12, 4)
            for toe in (-1.0, 1.0):
                b.ellipsoid(V(pad.x + toe * width * 0.47, 0.052, pad.z + length * 0.55), V(0.022, 0.020, 0.024), Matrix.Rotation(-0.5, 3, "X"), 6, 4)
    return shapes


# --- Its tack: each a mesh of its own, which the rig shows or hides. ---

SADDLE_FROM, SADDLE_TO = -0.56, 0.40


def blanket(breed):
    def shapes(b):
        # A woven blanket over the hump and down each side
        steps = 6 if kit.LOW else 14
        turns = 8 if kit.LOW else 18
        rows = []
        for i in range(steps + 1):
            z = SADDLE_FROM + (SADDLE_TO - SADDLE_FROM) * i / steps
            rows.append([hull(breed, z, -1.70 + 3.40 * k / turns, 0.016) for k in range(turns + 1)])
        sheet(b, rows)
    return shapes


def blanket_trim(breed):
    def shapes(b):
        # A band along each of its edges, and a row of tassels hanging from the lower ones
        steps = 6 if kit.LOW else 14
        for side in (1.0, -1.0):
            rows = []
            for i in range(steps + 1):
                z = SADDLE_FROM + (SADDLE_TO - SADDLE_FROM) * i / steps
                rows.append([hull(breed, z, side * a, 0.021) for a in (1.52, 1.62, 1.72)])
            sheet(b, rows)
            for i in range(0 if kit.LOW else 9):
                z = SADDLE_FROM + 0.03 + (SADDLE_TO - SADDLE_FROM - 0.06) * i / 8
                top = hull(breed, z, side * 1.72, 0.024)
                b.strand([top, top + V(side * 0.004, -0.05, 0.0), top + V(side * 0.006, -0.11, 0.0)], [0.006, 0.013, 0.008], 5)
        for z in (SADDLE_FROM, SADDLE_TO):
            inner = z + (0.04 if z < 0.0 else -0.04)
            sheet(b, [[hull(breed, z, -1.70 + 3.40 * k / 12, 0.021) for k in range(13)], [hull(breed, inner, -1.70 + 3.40 * k / 12, 0.021) for k in range(13)]])
    return shapes


def saddle_frame(breed):
    def shapes(b):
        # The riding saddle: two forks of wood, one in front of the hump and one behind, each with a
        # horn standing up from it, joined by a bar along each side
        centre, size = breed.hump
        for z in (centre.z + 0.33, centre.z - 0.36):
            b.strand([hull(breed, z, a, 0.035) for a in (-1.15, -0.75, -0.38, 0.0, 0.38, 0.75, 1.15)], [0.020, 0.022, 0.024, 0.026, 0.024, 0.022, 0.020], 6)
            top = hull(breed, z, 0.0, 0.04)
            lean = 0.05 if z > centre.z else -0.05
            b.strand([top, top + V(0.0, 0.10, lean), top + V(0.0, 0.20, lean * 1.6)], [0.024, 0.019, 0.023], 6)
        for side in (1.0, -1.0):
            b.strand([hull(breed, centre.z - 0.36 + 0.69 * k / 5, side * 0.95, 0.04) for k in range(6)], [0.016] * 6, 5)
    return shapes


def saddle_seat(breed):
    def shapes(b):
        # A leather cushion on top, between the horns, and a girth under the chest and another under the belly
        centre, size = breed.hump
        top = hull(breed, centre.z - 0.01, 0.0, 0.0)
        b.ellipsoid(top + V(0.0, 0.012, 0.0), V(0.17, 0.055, 0.26), None, 12, 5)
        for z in (0.16, -0.40):
            b.strand([hull(breed, z, -3.0 + 6.0 * k / 16, 0.012) for k in range(17)], [0.013] * 17, 5)
    return shapes


def halter(breed):
    def shapes(b):
        # A rope headstall: a band round the nose, and a cord from each side of it up over the poll behind the ears
        skull = breed.skull
        ring = []
        for k in range(13):
            a = math.tau * k / 12
            ring.append(skull + V(0.068 * math.sin(a), -0.060 + 0.088 * math.cos(a), 0.225))
        b.strand(ring, [0.008] * 13, 5)
        over = [V(0.070, -0.040, 0.220), V(0.090, 0.000, 0.090), V(0.086, 0.052, -0.020), V(0.050, 0.098, -0.100)]
        line = [skull + p for p in over] + [skull + V(0.0, 0.106, -0.112)] + [skull + V(-p.x, p.y, p.z) for p in over[::-1]]
        b.strand(line, [0.007] * len(line), 5)
        # (and the knot under its chin that the lead is tied to)
        b.ellipsoid(skull + V(0.0, -0.156, 0.225), V(0.016, 0.016, 0.016), None, 6, 4)
    return shapes


def lead_line(breed):
    """The lead rope where it hangs when no one has hold of it: from the chin down, and back up to the neck."""
    chin = breed.skull + V(0.0, -0.156, 0.225)
    tie = breed.neck_chain[1].lerp(breed.neck_chain[2], 0.45)
    points = []
    for k in range(9):
        t = k / 8.0
        sag = math.sin(math.pi * t) * 0.34
        points.append(chin.lerp(tie + V(0.0, -0.13, 0.11), t) - Y * sag)
    return points, tie


def lead(breed):
    def shapes(b):
        points, tie = lead_line(breed)
        b.strand(points, [0.008] * len(points), 5)
        # (a turn of it round the neck)
        along = (breed.neck_chain[2] - breed.neck_chain[1]).normalized()
        across = along.cross(X).normalized()
        b.strand([tie + X * (0.118 * math.sin(a)) + across * (0.158 * math.cos(a)) for a in [math.tau * k / 14 for k in range(15)]], [0.008] * 15, 5)
    return shapes


def pack_bags(breed):
    def shapes(b):
        # A bag hung on each side, a roll of bedding across behind the hump
        for side in (1.0, -1.0):
            at = hull(breed, -0.10, side * 1.80, 0.105)
            b.tube([(at + V(0.0, y, 0.0), X * (0.105 * w), Z * (0.30 * w)) for y, w in ((-0.25, 0.55), (-0.21, 0.92), (-0.08, 1.0), (0.08, 0.96), (0.19, 0.80), (0.235, 0.45))], 12)
    return shapes


def pack_roll(breed):
    def shapes(b):
        centre, size = breed.hump
        top = hull(breed, centre.z - 0.47, 0.0, 0.10)
        b.tube([(top + V(x, -abs(x) * 0.25, 0.0), Y * r, Z * r) for x, r in ((-0.34, 0.05), (-0.32, 0.088), (0.0, 0.092), (0.32, 0.088), (0.34, 0.05))], 10)
    return shapes


def pack_straps(breed):
    def shapes(b):
        # The straps the bags hang by, over its back in front of the hump and behind it; and a waterskin on the near side
        for z in (0.13, -0.33):
            b.strand([hull(breed, z + (-0.10 - z) * (abs(a) / 1.75) ** 3, a, 0.030) for a in (-1.75, -1.3, -0.85, -0.4, 0.0, 0.4, 0.85, 1.3, 1.75)], [0.012] * 9, 5)
        for z in (-0.44, -0.50):
            b.strand([hull(breed, z, a, 0.022) for a in (-0.5, 0.0, 0.5)], [0.010] * 3, 5)
        skin = hull(breed, -0.44, 1.85, 0.07)
        b.ellipsoid(skin + V(0.0, -0.10, 0.0), V(0.070, 0.150, 0.085), Matrix.Rotation(0.2, 3, "X"), 10, 6)
        b.strand([skin + V(0.0, 0.03, 0.0), hull(breed, -0.44, 1.5, 0.03), hull(breed, -0.44, 1.0, 0.03)], [0.008] * 3, 5)
    return shapes


def weights(breed):
    tail = breed.tail
    tail_names = ["pelvis"] + TAIL_BONES
    neck_names = ["chest"] + NECK_BONES + ["head"]

    def up_neck(p, made, always=False):
        """Shares a point out along the neck: what is not neck is left as `made` has it."""
        past, along, head = neck_share(breed, p)
        if always:
            past = 1.0
        beyond = [past] + [blend(k - 0.32, k + 0.32, along) for k in (1, 2, 3)] + [head, 0.0]
        shared = {bone: weight * (1.0 - past) for bone, weight in made.items()}
        run = 1.0
        for i, name in enumerate(neck_names[1:]):
            run *= beyond[i]
            shared[name] = shared.get(name, 0.0) + run * (1.0 - beyond[i + 1])
        return shared

    def weigh(part, p):
        suffix = "_l" if p.x >= 0.0 else "_r"
        side = 1.0 if p.x >= 0.0 else -1.0
        if part in ("jaw", "tongue", "teeth", "lower_lip"):
            return {"jaw": 1.0}
        if part in ("palate", "eyes", "lips", "nostrils", "halter"):
            return {"head": 1.0}
        if part in ("lids", "lashes"):
            return {"lid" + suffix: 1.0}
        if part == "lead":
            return up_neck(p, {"chest": 1.0}, True)
        if part in ("ears", "linings"):
            root, mid, end = (V(j.x * side, j.y, j.z) for j in breed.ear)
            along = (p - root).dot((end - root).normalized())
            joint = (mid - root).dot((end - root).normalized())
            hung = blend(0.0, 0.03, along)
            tip = blend(joint - 0.02, joint + 0.02, along)
            return {"head": 1.0 - hung, "ear" + suffix: hung * (1.0 - tip), "ear_tip" + suffix: hung * tip}
        front = blend(-0.35, 0.25, p.z)
        trunk = {"chest": front, "pelvis": 1.0 - front}
        if part in TACK:
            return trunk
        if part == "pads" and p.y > 0.9 and abs(p.x) < 0.13:
            # (the pedestal is under its chest, between its forelegs, and does not go with either)
            return {"chest": 1.0}
        off, along = dog.chain_param(p, tail)
        if p.z < tail[0].z + 0.01 and off < 0.07 and part == "coat":
            # How far past each joint of the tail: the pelvis, and then each bone in turn
            past = [1.0, blend(0.0, 0.6, along)] + [blend(k - 0.3, k + 0.3, along) for k in (1, 2, 3)] + [0.0]
            return {name: past[i] - past[i + 1] for i, name in enumerate(tail_names)}
        leg_suffix, leg = leg_share(breed, p)
        joints = breed.legs[leg_suffix]
        along = dog.chain_param(V(joints[0].x, p.y, p.z), joints)[1]
        spans = [(b - a).length for a, b in zip(joints, joints[1:])]
        low = blend(1.0 - 0.09 / spans[0], 1.0 + 0.09 / spans[1], along)
        hock = blend(2.0 - 0.07 / spans[1], 2.0 + 0.07 / spans[2], along)
        foot = blend(joints[3].y + 0.07, joints[3].y + 0.0, p.y)
        made = {bone: weight * (1.0 - leg) for bone, weight in trunk.items()}
        made["upper" + leg_suffix] = leg * (1.0 - low)
        made["lower" + leg_suffix] = leg * low * (1.0 - hock)
        made["hock" + leg_suffix] = leg * low * hock * (1.0 - foot)
        made["paw" + leg_suffix] = leg * low * hock * foot
        return up_neck(p, made)
    return weigh


def bones(breed):
    listed = [("body", breed.body, None), ("chest", breed.chest, "body"), ("pelvis", breed.pelvis, "body"), ("seat", breed.seat, "body")]
    chain = ["chest"] + NECK_BONES + ["head"]
    for i, joint in enumerate(breed.neck_chain):
        listed.append((chain[i + 1], joint, chain[i]))
    listed.append(("jaw", breed.jaw, "head"))
    for side, suffix in ((1.0, "_l"), (-1.0, "_r")):
        root, mid, end = (V(j.x * side, j.y, j.z) for j in breed.ear)
        listed.append(("ear" + suffix, root, "head"))
        listed.append(("ear_tip" + suffix, mid, "ear" + suffix))
        # (carries nothing: it marks where the ear ends, for the rig)
        listed.append(("ear_end" + suffix, end, "ear_tip" + suffix))
        listed.append(("lid" + suffix, lid_at(breed, side), "head"))
    chain = ["pelvis"] + TAIL_BONES + ["tail_end"]
    for i, joint in enumerate(breed.tail):
        listed.append((chain[i + 1], joint, chain[i]))
    for suffix, joints in breed.legs.items():
        for bone, joint in zip(("upper", "lower", "hock", "paw"), joints):
            listed.append((bone + suffix, joint, "body"))
    return listed


def parts(breed):
    # The coat and the jaw fuse themselves (see `furred`), so nothing here asks for it.
    return [
        ("coat", COAT, coat(breed), None), ("jaw", COAT, jaw(breed), None), ("ears", COAT, ears(breed), None),
        ("lips", HIDE, lips(breed), None), ("lower_lip", HIDE, lower_lip(breed), None), ("linings", HIDE, ear_linings(breed), None),
        ("lids", HIDE, lids(breed), None), ("lashes", DARK, lashes(breed), None), ("nostrils", DARK, nostrils(breed), None),
        ("eyes", EYE, eyes(breed), None), ("palate", MOUTH, palate(breed), None), ("tongue", MOUTH, tongue(breed), None),
        ("teeth", TEETH, teeth(breed), None), ("pads", PAD, pads(breed), None),
        ("saddle", BLANKET, blanket(breed), None), ("saddle", TRIM, blanket_trim(breed), None),
        ("saddle", WOOD, saddle_frame(breed), None), ("saddle", LEATHER, saddle_seat(breed), None),
        ("halter", ROPE, halter(breed), None), ("lead", ROPE, lead(breed), None),
        ("packs", CANVAS, pack_bags(breed), None), ("packs", BLANKET, pack_roll(breed), None), ("packs", LEATHER, pack_straps(breed), None),
    ]


def preview(folder, name):
    """Pictures of it framed for something a camel's size (the kit's own are framed for a boy)."""
    scene = bpy.context.scene
    camera = scene.camera
    for view, direction, target, frame in (("near_side", (1, 0, 0), (0.0, -0.2, 1.15), 3.4), ("near_quarter", (0.7, -0.7, 0.3), (0.0, -0.2, 1.15), 3.4),
                                           ("near_front", (0.15, -1, 0.1), (0.0, 0.0, 1.2), 2.8), ("near_back", (-0.5, 1, 0.3), (0.0, 0.0, 1.2), 3.2),
                                           ("near_head", (0.6, -0.8, 0.1), (0.0, -1.45, 2.12), 0.9), ("near_foot", (0.7, -0.7, 0.4), (0.18, -0.55, 0.2), 0.8)):
        offset = Vector(direction).normalized() * 8.0
        camera.data.ortho_scale = frame
        camera.location = Vector(target) + offset
        camera.rotation_euler = (-offset).to_track_quat("-Z", "Y").to_euler()
        scene.render.filepath = os.path.join(folder, "%s_%s.png" % (name, view))
        bpy.ops.render.render(write_still=True)


if __name__ == "__main__":
    for low in (False, True):
        kit.LOW = low
        breed = DROMEDARY
        name = breed.name + ("_lo" if low else "")
        if kit.ONLY and name not in kit.ONLY:
            continue
        kit.export(name, bones(breed), parts(breed), weights(breed), breed.materials, apart=TACK)
        if kit.PREVIEW_DIR:
            preview(kit.PREVIEW_DIR, name)
