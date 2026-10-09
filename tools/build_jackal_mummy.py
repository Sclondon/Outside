"""Builds the mummified jackal and exports it for Godot.

Run from the project root:
    blender --background --python tools/build_jackal_mummy.py [-- <preview folder>]

Writes models/jackal_mummy.glb and a demade models/jackal_mummy_lo.glb, with
editable copies in tools/.

It is one of the dogs and jackals given to Anubis: bred, killed, dried, bound in
linen and stacked in the catacombs under his temple at Saqqara by the million
(Nicholson, Ikram and Mills, "The Catacombs of Anubis at North Saqqara",
Antiquity 89, 2015). The animal under the cloth is the Egyptian jackal, which is
now counted a wolf (Canis lupaster: en.wikipedia.org/wiki/African_wolf): lean,
long in the leg, a long pointed muzzle, long ears. A real one stands 40 cm at
the shoulder. This one is made the size of the hounds (60 cm), as the black
jackals that lie on the shrines are larger than life.

What is modelled:

- A body dried onto its bones: a deep keel of a chest, flanks fallen in behind
  it, a spine that stands up along the loin, legs that are sticks with knobs
  at the joints.
- The wrappings. The trunk is bound in strips that cross one another at a
  slant, in two tones of linen, which leaves the pattern of lozenges that the
  embalmers of the Late Period and the Roman years put on their animals; dark
  resin shows in the gaps. The neck, the legs, the muzzle and the tail are
  wound round and round, each turn lapping the last.
- A head that is a skull under cloth: two hollows for eyes, each with a point
  of light at the bottom of it (the material `glow`, which the rig lights), a
  lower jaw of bare bone with its teeth, and tall ears.
- Loose ends of bandage, each with a chain of bones of its own
  (`drape_<name>_0`, `_1`..., the last only marking where it ends), which
  scripts/jackal_mummy_rig.gd swings as a chain of weights.
- A gilded mask with painted eyes and a broad collar, each a mesh of its own
  (`jackal_mummy_mask`, `jackal_mummy_collar`) that the rig shows or hides.

It is built with the hounds' tools (tools/build_hound.py) on the hounds' bones,
so the rig that moves it reuses the hounds' leg solver. Everything is in Godot
space (metres, Y up, facing +Z, +X its left).
"""

import math
import os
import sys

import bpy  # noqa: F401  (Blender must be running this)
from mathutils import Matrix, Vector

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import build_character as kit  # noqa: E402  (shared shape-building and export tools)
import build_hound as dog  # noqa: E402  (the hounds' legs, ears, jaw, teeth, bones and weights)

X, Y, Z = kit.X, kit.Y, kit.Z
V = dog.V
blend = kit.blend
dome = kit.dome

LINEN, OLD_LINEN, RESIN, HOLLOW, BONE, GLOW, GOLD, LAPIS = range(8)
MATERIALS = [
    ("linen", (0.60, 0.53, 0.40)), ("old_linen", (0.42, 0.35, 0.24)), ("resin", (0.20, 0.155, 0.11)),
    ("hollow", (0.025, 0.02, 0.015)), ("teeth", (0.74, 0.68, 0.52)), ("glow", (0.55, 0.85, 0.45)),
    ("gold", (0.86, 0.66, 0.22)), ("lapis", (0.10, 0.16, 0.42)),
]

JACKAL = dog.Breed(
    name="jackal_mummy",
    heavy=False,
    materials=MATERIALS,
    body=V(0.0, 0.60, 0.0), chest=V(0.0, 0.62, 0.20), pelvis=V(0.0, 0.61, -0.22),
    # (along the body, centre height, half width, half height): a keel of a chest, and nothing behind it
    trunk=[(-0.35, 0.652, 0.028, 0.038), (-0.30, 0.642, 0.048, 0.060), (-0.22, 0.640, 0.052, 0.060),
           (-0.12, 0.656, 0.036, 0.040), (-0.03, 0.640, 0.046, 0.062), (0.06, 0.600, 0.064, 0.108),
           (0.16, 0.570, 0.072, 0.148), (0.25, 0.582, 0.068, 0.136), (0.31, 0.608, 0.056, 0.100),
           (0.35, 0.634, 0.040, 0.066)],
    fore=[V(0.062, 0.565, 0.265), V(0.062, 0.395, 0.190), V(0.062, 0.150, 0.208), V(0.062, 0.028, 0.224)],
    hind=[V(0.058, 0.585, -0.260), V(0.058, 0.405, -0.160), V(0.058, 0.190, -0.352), V(0.058, 0.028, -0.345)],
    # (how far down the leg, counted in joints; half width; half depth; forward offset): bone, with a knob at each joint
    fore_shape=[(-0.3, 0.020, 0.034, 0.0), (0.0, 0.024, 0.040, 0.0), (0.5, 0.017, 0.024, 0.0), (0.9, 0.018, 0.024, -0.002),
                (1.0, 0.021, 0.028, -0.003), (1.15, 0.016, 0.020, 0.0), (1.6, 0.013, 0.015, 0.0), (1.92, 0.015, 0.017, 0.0),
                (2.0, 0.017, 0.019, 0.0), (2.12, 0.013, 0.015, 0.0), (2.6, 0.012, 0.013, 0.0), (3.0, 0.015, 0.017, 0.002)],
    hind_shape=[(-0.25, 0.020, 0.036, 0.0), (0.0, 0.024, 0.046, 0.0), (0.45, 0.020, 0.036, 0.0), (0.85, 0.020, 0.030, 0.003),
                (1.0, 0.022, 0.031, 0.003), (1.2, 0.016, 0.024, -0.003), (1.7, 0.013, 0.016, 0.0), (1.9, 0.015, 0.020, -0.002),
                (2.0, 0.017, 0.023, -0.003), (2.15, 0.012, 0.015, 0.0), (2.7, 0.011, 0.013, 0.0), (3.0, 0.014, 0.017, 0.003)],
    paw=(0.021, 0.040),
    muscle=0.5,
    neck=V(0.0, 0.675, 0.30), head=V(0.0, 0.885, 0.425),
    # (how far up the neck, radius, how far the throat hangs under it)
    neck_shape=[(-0.3, 0.052, 0.0), (0.0, 0.046, 0.0), (0.35, 0.036, 0.0), (0.7, 0.031, 0.0), (1.0, 0.030, 0.0), (1.15, 0.026, 0.0)],
    skull_at=V(0.0, 0.018, 0.030), skull_size=V(0.043, 0.040, 0.064),
    # (along the muzzle from the skull, height, half width, half height): long, and fine at the end
    muzzle=[(0.03, -0.002, 0.033, 0.031), (0.09, -0.008, 0.025, 0.023), (0.16, -0.012, 0.019, 0.018), (0.218, -0.015, 0.015, 0.015)],
    nose=(V(0.0, -0.010, 0.230), V(0.012, 0.010, 0.010)),
    jaw_at=V(0.0, -0.022, 0.000),
    jaw_shape=[(-0.01, -0.030, 0.025, 0.010), (0.08, -0.037, 0.019, 0.008), (0.185, -0.041, 0.012, 0.007)],
    # The line the teeth meet on, the length of the mouth, and its half width at the fangs and at the back
    mouth=(-0.034, 0.205, 0.009, 0.018),
    eye=(V(0.031, 0.012, 0.046), 0.0135),
    # Each ear: where it roots, the joint part way along it, and its end. Longer than any hound's.
    ear_at=[V(0.030, 0.026, -0.024), V(0.047, 0.125, -0.032), V(0.060, 0.245, -0.030)],
    tail_root=V(0.0, 0.655, -0.36),
    tail_at=[(0.0, 0.0, 0.0), (0.0, -0.09, -0.06), (0.0, -0.20, -0.09), (0.0, -0.31, -0.10), (0.0, -0.40, -0.09)],
    tail_shape=[0.018, 0.017, 0.015, 0.013, 0.010, 0.006],
)

# How long one turn of bandage is along a limb (m), and how far each stands proud of the next.
TURN = 0.026
LAP = 0.0035
# How many strips cross the trunk each way, how far round it each goes in a metre (radians), and how wide each is.
STRIPS = 7
SLANT = 9.0
STRIP_WIDTH = 0.046


def trunk_at(breed, z):
    """The trunk at `z` along it: (centre height, half width, half height)."""
    rings = breed.trunk
    if z <= rings[0][0]:
        return rings[0][1:]
    for (z0, y0, rx0, ry0), (z1, y1, rx1, ry1) in zip(rings, rings[1:]):
        if z <= z1:
            t = (z - z0) / (z1 - z0)
            return (y0 + (y1 - y0) * t, rx0 + (rx1 - rx0) * t, ry0 + (ry1 - ry0) * t)
    return rings[-1][1:]


def hull(breed, z, angle):
    """A place on the skin of the trunk, and which way the skin faces there."""
    y, rx, ry = trunk_at(breed, z)
    return V(rx * math.sin(angle), y + ry * math.cos(angle), z), V(math.sin(angle) / rx, math.cos(angle) / ry, 0.0).normalized()


def wound(stations, total, lap=LAP, turn=TURN):
    """A profile of (how far along, ...radii..., offset) cut into turns of bandage:
    each starts standing proud of the one before and tapers to the skin. `total`
    is how long the thing is for one unit of "how far along" (m)."""
    if kit.LOW:
        return stations
    made = []
    s = stations[0][0]
    step = turn / total
    while s < stations[-1][0] - step * 0.3:
        for at, proud in ((s, lap), (min(s + step, stations[-1][0]) - step * 0.04, 0.0)):
            for a, c in zip(stations, stations[1:]):
                if a[0] <= at <= c[0]:
                    t = (at - a[0]) / (c[0] - a[0])
                    row = [a[i] + (c[i] - a[i]) * t for i in range(1, len(a))]
                    made.append((at, row[0] + proud, row[1] + proud) + tuple(row[2:]))
                    break
        s += step
    return made


def body(breed):
    def shapes(b):
        # The trunk, dark with resin: what shows between the strips
        rings = [kit.lengthwise(*ring) for ring in breed.trunk]
        b.tube(dome(rings[0], -Z, 0.03)[::-1] + rings + dome(rings[-1], Z, 0.03), 16)
        # The spine standing up along the loin
        b.strand([V(0.0, trunk_at(breed, z)[0] + trunk_at(breed, z)[2] - 0.004, z) for z in (-0.30, -0.20, -0.10, 0.0, 0.10)], [0.012, 0.013, 0.013, 0.013, 0.011], 6)
    return shapes


def strips(breed, way):
    def shapes(b):
        # Strips crossing the trunk at a slant: these `way` round, the other part the other way
        count = 30
        for n in range(STRIPS):
            rings = []
            for k in range(count + 1):
                z = -0.325 + 0.655 * k / count
                angle = math.tau * (n + (0.5 if way < 0.0 else 0.0)) / STRIPS + way * SLANT * z

                def at(dz, angle=angle, z=z):
                    point, facing = hull(breed, z + dz, angle + way * SLANT * dz)
                    return point + facing * 0.0035, facing
                here, facing = at(0.0)
                along = (at(0.004)[0] - at(-0.004)[0]).normalized()
                across = facing.cross(along).normalized()
                # (they narrow where the body does, so that they do not ride up over one another at its ends)
                wide = STRIP_WIDTH * 0.5 * min(1.0, trunk_at(breed, z)[1] / 0.05)
                rings.append((here, across * wide, facing * 0.0035))
            b.tube(rings, 4)
    return shapes


def limbs(breed):
    def shapes(b):
        low = kit.LOW
        for suffix, joints in breed.legs.items():
            fore = suffix[1] == "f"
            spans = [(c - a).length for a, c in zip(joints, joints[1:])]
            dog.limb(b, joints, wound(breed.fore_shape if fore else breed.hind_shape, sum(spans) / 3.0), 6 if low else 9)
            width, length = breed.paw
            paw = joints[3]
            b.ellipsoid(paw + V(0.0, -0.008, length * 0.5), V(width, 0.022, length), None, 8, 5)
        # The neck, wound from the chest to the skull
        base, top = breed.neck, breed.head + V(0.0, -0.01, -0.01)
        along = (top - base).normalized()
        across = along.cross(X).normalized()
        neck = wound([(t, r, r * 1.15, 0.0) for t, r, _sag in breed.neck_shape], (top - base).length, 0.004, 0.03)
        b.tube([(base.lerp(top, t), X * r, across * rd) for t, r, rd, _ in neck], 10)
        # The ends of the trunk, where the strips are gathered: bound over, at the breast and under the tail
        b.ellipsoid(V(0.0, 0.622, 0.338), V(0.047, 0.082, 0.046), None, 10, 6)
        b.ellipsoid(V(0.0, 0.650, -0.338), V(0.032, 0.042, 0.040), None, 8, 5)
        # The tail, hanging straight
        tail = [breed.tail_root + V(0.0, 0.02, 0.04)] + breed.tail
        b.strand(tail, breed.tail_shape, 6)
        for vert in b.bm.verts:
            vert.co.z = max(vert.co.z, 0.0)  # nothing goes through the ground
    return shapes


def knots(breed):
    def shapes(b):
        # The points of the hips and the shoulders and the knobs of the joints, in older cloth; and the turns that bind the tail
        for side in (1.0, -1.0):
            b.ellipsoid(V(side * 0.044, 0.668, -0.245), V(0.014, 0.020, 0.032), None, 8, 5)
            b.ellipsoid(V(side * 0.056, 0.640, 0.225), V(0.014, 0.048, 0.028), None, 8, 5)
        for suffix, joints in breed.legs.items():
            fore = suffix[1] == "f"
            width = breed.paw[0]
            knob = joints[1] + V(0.0, 0.008, -0.022) if fore else joints[2] + V(0.0, 0.016, -0.018)
            b.ellipsoid(knob, V(width * 0.8, 0.022, 0.020), None, 8, 5)
        if kit.LOW:
            return
        for k in (1, 2, 3):
            b.ellipsoid(breed.tail[k], V(0.019 - k * 0.002, 0.012, 0.019 - k * 0.002), None, 8, 3)
    return shapes


def skull(breed):
    def shapes(b):
        at = breed.skull
        size = breed.skull_size
        b.ellipsoid(at, size, None, 14, 8)
        b.ellipsoid(at + V(0.0, size.y * 0.5, size.z * 0.5), V(size.x * 0.8, size.y * 0.34, size.z * 0.4))  # brow
        # The muzzle, wound to the nose. The lower jaw is a part of its own (`jaw`).
        profile = [(0.0, size.x * 0.8, size.y * 0.8, 0.0)] + [(z, rx, ry, y) for z, y, rx, ry in breed.muzzle]
        rings = [(at + V(0.0, y, z), X * rx, Y * ry) for z, rx, ry, y in wound(profile, 1.0, 0.003, 0.024)]
        b.tube(rings + dome(rings[-1], Z, rings[-1][1].x * 0.5, 2), 10)
    return shapes


def head_bands(breed):
    def shapes(b):
        # Turns of older bandage that cross the skull: over the brow and under the jaw's hinge, and round behind the ears
        at = breed.skull
        size = breed.skull_size
        for lean, forward, scale in ((0.5, 0.012, 1.0), (-0.45, -0.014, 0.98)):
            turn = Matrix.Rotation(lean, 3, "X")
            ring = [(at + V(0.0, 0.0, forward) + turn @ (Z * dz), turn @ (X * (size.x * scale + 0.004)), turn @ (Y * (size.y * scale + 0.005))) for dz in (-0.012, 0.012)]
            b.tube(ring, 12)
    return shapes


def nose(breed):
    def shapes(b):
        b.ellipsoid(breed.skull + breed.nose[0], breed.nose[1], None, 8, 5)
    return shapes


def ear_frame(side):
    """Across an ear, and through it: the open side is to the front and a little out."""
    return V(side * 0.90, 0.0, -0.42).normalized(), V(side * 0.42, 0.0, 0.90).normalized()


def ears(breed):
    def shapes(b):
        # Tall and pointed, and narrower than a hound's: the ears of the jackal on the shrine
        for side in (1.0, -1.0):
            wide, face = ear_frame(side)
            rings = []
            for t, half, thick in ((0.0, 0.020, 0.012), (0.10, 0.029, 0.010), (0.30, 0.032, 0.007), (0.55, 0.027, 0.006),
                                   (0.80, 0.016, 0.005), (0.94, 0.008, 0.004), (1.0, 0.004, 0.003)):
                rings.append((dog.ear_curve(breed, t, side), wide * half, face * thick))
            b.tube(dome(rings[0], -Y, 0.008, 2)[::-1] + rings, 8)
    return shapes


def ear_linings(breed):
    def shapes(b):
        # The dark inside of each
        for side in (1.0, -1.0):
            wide, face = ear_frame(side)
            rings = []
            for t, half in ((0.10, 0.010), (0.22, 0.021), (0.40, 0.023), (0.60, 0.018), (0.80, 0.009), (0.92, 0.003)):
                rings.append((dog.ear_curve(breed, t, side) + face * 0.004, wide * half, face * 0.003))
            b.tube(rings, 6)
    return shapes


def eye_at(breed, side):
    at, _radius = breed.eye
    return breed.skull + V(side * at.x, at.y, at.z)


def sockets(breed):
    def shapes(b):
        # Where its eyes were: two hollows
        radius = breed.eye[1]
        for side in (1.0, -1.0):
            b.ellipsoid(eye_at(breed, side), V(radius * 0.8, radius * 0.85, radius), None, 8, 5)
    return shapes


def glows(breed):
    def shapes(b):
        # ...and a point of light at the bottom of each
        radius = breed.eye[1]
        for side in (1.0, -1.0):
            b.ellipsoid(eye_at(breed, side) + V(side * radius * 0.52, 0.001, radius * 0.42), V(1.0, 1.0, 1.0) * radius * 0.42, None, 8, 4)
    return shapes


def mask(breed):
    def shapes(b):
        # A face of gilded plaster tied over its own: the brow, the cheeks and the top of the muzzle
        at = breed.skull
        size = breed.skull_size
        b.ellipsoid(at + V(0.0, 0.002, 0.006), V(size.x + 0.008, size.y + 0.008, size.z * 0.9), None, 14, 8)
        rings = [(at + V(0.0, y + 0.003, z), X * (rx + 0.0035), Y * (ry + 0.002)) for z, y, rx, ry in breed.muzzle]
        b.tube([(at + V(0.0, 0.002, 0.0), X * size.x * 0.84, Y * size.y * 0.84)] + rings + dome(rings[-1], Z, rings[-1][1].x * 0.5, 2), 12)
    return shapes


def mask_paint(breed):
    def shapes(b):
        # Painted on it in blue: the line round each eye, drawn out towards the ear, and a band across the brow
        radius = breed.eye[1]
        for side in (1.0, -1.0):
            b.ellipsoid(eye_at(breed, side) + V(side * 0.001, 0.0, -0.004), V(radius * 0.86, radius * 1.25, radius * 1.9), None, 10, 5)
        at = breed.skull
        size = breed.skull_size
        b.tube([(at + V(0.0, 0.004, dz), X * (size.x + 0.0095), Y * (size.y + 0.0095)) for dz in (-0.020, -0.008)], 14)
    return shapes


def collar_bands(breed, which):
    def shapes(b):
        # The broad collar: rows of beads round the root of the neck, gold and blue in turn
        base, top = breed.neck, breed.head + V(0.0, -0.01, -0.01)
        along = (top - base).normalized()
        across = along.cross(X).normalized()
        for row in range(5):
            if row % 2 != which:
                continue
            t0 = -0.06 + row * 0.085
            rings = []
            for t in (t0, t0 + 0.04, t0 + 0.08):
                r = 0.0
                for (ta, ra, _), (tc, rc, _) in zip(breed.neck_shape, breed.neck_shape[1:]):
                    if ta <= t <= tc:
                        r = ra + (rc - ra) * (t - ta) / (tc - ta)
                bulge = 0.011 if t == t0 + 0.04 else 0.007
                rings.append((base.lerp(top, t), X * (r + bulge), across * (r * 1.15 + bulge)))
            b.tube(rings, 12)
    return shapes


# --- What hangs loose ---

def hung(root, lengths, drift=(0.0, 0.0)):
    """The joints of a strip hanging from `root`: straight down, or drifting a little as it goes."""
    joints = [Vector(root)]
    for length in lengths:
        joints.append(joints[-1] + Vector((drift[0], -1.0, drift[1])).normalized() * length)
    return joints


def drapes(breed):
    """Each loose end: (name, the bone it hangs from, its joints from root to tip,
    half width, which way is out from the body there, material)."""
    keel = trunk_at(breed, 0.14)
    loin = trunk_at(breed, -0.14)
    elbow = breed.legs["_fr"][1]
    hock = breed.legs["_rl"][2]
    return [
        # Under the throat, from the last turn round the neck
        ("throat", "neck", hung(breed.neck.lerp(breed.head, 0.45) + V(0.0, -0.036, 0.012), (0.085, 0.08)), 0.012, V(0.0, 0.0, 1.0), OLD_LINEN),
        # Off the ribs on its left, and from under the keel
        ("ribs", "chest", hung(V(keel[1] * 0.92, keel[0] - keel[2] * 0.25, 0.14), (0.11, 0.105, 0.10), (0.05, -0.05)), 0.014, V(1.0, 0.0, 0.0), OLD_LINEN),
        ("keel", "chest", hung(V(-0.012, keel[0] - keel[2] + 0.004, 0.10), (0.085, 0.08)), 0.012, V(0.0, 0.0, -1.0), LINEN),
        # Off the loin on its right: the longest, and it trails
        ("loin", "pelvis", hung(V(-loin[1] * 0.9, loin[0] + loin[2] * 0.2, -0.14), (0.12, 0.12, 0.115, 0.11), (-0.04, -0.06)), 0.015, V(-1.0, 0.0, 0.0), OLD_LINEN),
        # From behind the right elbow and off the left hock
        ("elbow", "upper_fr", hung(elbow + V(-0.008, 0.01, -0.03), (0.08, 0.075)), 0.011, V(-0.4, 0.0, -1.0), LINEN),
        ("hock", "lower_rl", hung(hock + V(0.006, 0.02, -0.026), (0.075, 0.07)), 0.011, V(0.4, 0.0, -1.0), OLD_LINEN),
    ]


def along_drape(joints, p):
    """How far along a strip (from its root, in metres) the point of it nearest `p` is."""
    best, travelled = None, 0.0
    for a, c in zip(joints, joints[1:]):
        span = c - a
        t = (p - a).dot(span) / span.length_squared
        if a is joints[0]:
            t = min(t, 1.0)
        elif c is joints[-1]:
            t = max(t, 0.0)
        else:
            t = min(max(t, 0.0), 1.0)
        away = (p - a - span * min(max(t, 0.0), 1.0)).length
        if best is None or away < best[0]:
            best = (away, travelled + t * span.length)
        travelled += span.length
    return best[1]


def drape_shape(joints, width, out, seed):
    """A loose end as a shape: a frayed strip, narrower and less straight as it goes."""
    def shapes(b):
        lengths = [0.0]
        for a, c in zip(joints, joints[1:]):
            lengths.append(lengths[-1] + (c - a).length)
        total = lengths[-1]
        count = max(int(total / (0.045 if kit.LOW else 0.018)), 3)
        rings = []
        for k in range(count + 1):
            s = total * k / count
            i = max(j for j in range(len(joints) - 1) if lengths[j] <= s + 1e-9)
            direction = (joints[i + 1] - joints[i]).normalized()
            at = joints[i] + direction * (s - lengths[i])
            flat = (out - direction * out.dot(direction)).normalized()
            across = flat.cross(direction).normalized()
            share = s / total
            wide = width * (1.0 - 0.3 * share) * (0.82 + 0.18 * math.sin(s * 70.0 + seed * 2.1))
            if k == count:
                wide *= 0.35
            at = at + across * 0.004 * math.sin(s * 33.0 + seed) * share
            rings.append((at, flat * 0.002, across * wide))
        # (it starts wound into whatever it hangs from)
        first = rings[0]
        rings.insert(0, (first[0] - (joints[1] - joints[0]).normalized() * 0.012 - first[1].normalized() * 0.006, first[1], first[2] * 0.8))
        b.tube(rings, 4)
    return shapes


DRAPES = drapes(JACKAL)
DRAPE_JOINTS = {"drape_" + name: joints for name, _parent, joints, _width, _out, _material in DRAPES}
# Parts that go with the head whatever the neck is doing.
ON_HEAD = ("skull", "head_bands", "nose", "sockets", "glows", "mask", "mask_paint")


def weights(breed):
    of_hound = dog.weights(breed)

    def weigh(part, p):
        if part in DRAPE_JOINTS:
            # Each link of the chain carries its own length of the strip, shared across the joint.
            joints = DRAPE_JOINTS[part]
            s = along_drape(joints, p)
            travelled = 0.0
            shares = []
            for a, c in zip(joints, joints[1:]):
                shares.append(blend(travelled - 0.018, travelled + 0.018, s) if travelled > 0.0 else 1.0)
                travelled += (c - a).length
            return {"%s_%d" % (part, k): share - (shares[k + 1] if k + 1 < len(shares) else 0.0) for k, share in enumerate(shares)}
        if part in ON_HEAD:
            return {"head": 1.0}
        return of_hound("collar" if part.startswith("collar") else part, p)
    return weigh


def bones(breed):
    listed = dog.bones(breed)
    # A chain down each loose end. The last bone of each carries nothing: it marks the tip.
    for name, parent, joints, _width, _out, _material in DRAPES:
        for k, joint in enumerate(joints):
            listed.append(("drape_%s_%d" % (name, k), joint, parent))
            parent = listed[-1][0]
    return listed


def parts(breed):
    listed = [
        ("body", RESIN, body(breed), None), ("strips", LINEN, strips(breed, 1.0), None), ("strips_back", OLD_LINEN, strips(breed, -1.0), None),
        ("limbs", LINEN, limbs(breed), None), ("knots", OLD_LINEN, knots(breed), None),
        ("skull", LINEN, skull(breed), None), ("head_bands", OLD_LINEN, head_bands(breed), None), ("nose", RESIN, nose(breed), None),
        ("sockets", HOLLOW, sockets(breed), None), ("glows", GLOW, glows(breed), None),
        # (the hounds' own: a jaw that drops, the teeth in it and over it, and ears on two bones each)
        ("jaw", BONE, dog.jaw(breed), None), ("palate", HOLLOW, dog.palate(breed), None),
        ("fangs", BONE, dog.fangs(breed), None), ("teeth", BONE, dog.teeth(breed), None),
        ("ears", OLD_LINEN, ears(breed), None), ("linings", RESIN, ear_linings(breed), None),
        ("mask", GOLD, mask(breed), None), ("mask_paint", LAPIS, mask_paint(breed), None),
        ("collar", GOLD, collar_bands(breed, 0), None), ("collar_beads", LAPIS, collar_bands(breed, 1), None),
    ]
    for index, (name, _parent, joints, width, out, material) in enumerate(DRAPES):
        listed.append(("drape_" + name, material, drape_shape(joints, width, out, index * 1.7), None))
    return listed


# Each of these is made an object of its own, so that the rig can show it or not.
# (the paint goes with the mask, and the beads with the collar: see `named`)
APART = ("mask", "collar")


def named(listed):
    """The parts with the paint made part of the mask's object, and the beads of the collar's."""
    return [({"mask_paint": "mask", "collar_beads": "collar"}.get(part, part), material, shapes, fuse) for part, material, shapes, fuse in listed]


def previews(folder, name):
    """More renders of the rest pose than the kit makes: from in front and above, and the head close to."""
    scene = bpy.context.scene
    camera = scene.camera
    head = kit.to_blender(JACKAL.skull + V(0.0, 0.03, 0.08))
    for view, direction, target, frame in (("front", (0.25, -1, 0.1), (0.0, 0.0, 0.6), 1.3), ("top", (0.2, -0.2, 1), (0.0, 0.0, 0.5), 1.3),
                                           ("head", (0.8, -0.6, 0.15), head, 0.5), ("head_front", (0.2, -1, 0.1), head, 0.5)):
        offset = Vector(direction).normalized() * 4.0
        camera.data.ortho_scale = frame
        camera.location = Vector(target) + offset
        camera.rotation_euler = (-offset).to_track_quat("-Z", "Y").to_euler()
        scene.render.filepath = os.path.join(folder, "%s_%s.png" % (name, view))
        bpy.ops.render.render(write_still=True)


if __name__ == "__main__":
    for low in (False, True):
        kit.LOW = low
        name = JACKAL.name + ("_lo" if low else "")
        weigh = weights(JACKAL)
        kit.export(name, bones(JACKAL), named(parts(JACKAL)), weigh, MATERIALS, False, APART)
        if kit.PREVIEW_DIR and (not kit.ONLY or name in kit.ONLY):
            previews(kit.PREVIEW_DIR, name)
