"""Builds the Nile crocodile and exports it for Godot.

Run from the project root:
    blender --background --python tools/build_crocodile.py
    blender --background --python tools/build_crocodile.py -- <preview folder>

Writes models/crocodile.glb (Crocodylus niloticus, a grown one of about 3.4 m)
and a demade models/crocodile_lo.glb, with editable copies in tools/.

It is built on the kit in tools/build_character.py, as the hounds and the camel
are, from one list of measurements (`NILE` below). Its legs have the hound's
bones and names, so that scripts/crocodile_rig.gd can use the hound rig's leg
solver:

    for each leg (_fl, _fr, _rl, _rr): upper, lower, hock, paw

    fore: `upper` (the upper arm, shoulder to elbow), `lower` (the forearm),
          `hock` (the hand, wrist to knuckles, which lies on the ground), `paw` (the toes)
    hind: `upper` (thigh), `lower` (shank), `hock` (the foot, heel to the root of
          the toes), `paw` (the toes, and the web between them)

They are siblings under `body`: the rig places each directly with IK. It is
modelled standing as it does in the "high walk": its belly clear of the ground
and its legs half under it, the elbows out and back and the knees out and forward.

What a crocodile has that a hound has not:

- A back in three pieces (`chest`, `body`, `pelvis`) and a tail in eight
  (`tail`, `tail_1` .. `tail_7`, and `tail_end`, which carries nothing): enough
  to bend the whole of it in an S, as it does to walk and to swim.
- One bone of neck (`neck`): it has very little.
- `jaw`, hinged right at the back of the head, so that it opens very wide.
- `lid_l`, `lid_r`: the upper eyelids, each turned down over its eye.

Nothing is fused: the hide is one long skin from the neck to the tip of the
tail, with its rings and the faces round them set out by hand, so that the pale
belly, the lighter flanks and the dark bands across the tail are cut cleanly
along its own edges, in materials of their own (there is no picture on it). The
scutes are geometry: keeled plates in rows down the back, the outer rows
standing up into the double crest of the tail, which runs into a single one
half way down it.

Everything is in Godot space (metres, Y up, facing +Z, +X its left). The one
mesh object is named `crocodile`, which is no bone's name.

What it follows: en.wikipedia.org/wiki/Nile_crocodile (grown males 3.5 to 5 m;
dark bronze above with blackish spots and bands, the flanks yellowish green
with dark patches in oblique stripes, the belly a dingy yellow; the snout 1.6
to 2 times as long as it is wide at the eyes; 64 to 68 teeth, five in each
premaxilla, 13 or 14 more in each side of the upper jaw and 14 or 15 in the
lower; the fourth lower tooth in a notch of the upper jaw, in sight with the
mouth shut; eyes, ears and nostrils on top of the head). The tail is about
half its length, and the head about a seventh.
"""

import math
import os
import sys

import bmesh
import bpy  # noqa: F401  (Blender must be running this)
from mathutils import Matrix, Vector

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import build_character as kit  # noqa: E402  (shared shape-building and export tools)
import build_hound as dog  # noqa: E402  (chain_param, and the names of the legs)

X, Y, Z = kit.X, kit.Y, kit.Z
blend = kit.blend
SUFFIXES = dog.SUFFIXES
BACK, FLANK, BELLY, BAND, SCUTE, MOUTH, TEETH, IRIS, PUPIL, CLAW = range(10)
TAIL_BONES = ["tail", "tail_1", "tail_2", "tail_3", "tail_4", "tail_5", "tail_6", "tail_7"]


def V(x, y, z):
    return Vector((x, y, z))


class Measurements:
    def __init__(self, **spec):
        self.__dict__.update(spec)
        self.legs = {}
        for suffix in SUFFIXES:
            side = 1.0 if suffix[2] == "l" else -1.0
            self.legs[suffix] = [V(j.x * side, j.y, j.z) for j in (self.fore if suffix[1] == "f" else self.hind)]


NILE = Measurements(
    name="crocodile",
    materials=[("back", (0.175, 0.18, 0.105)), ("flank", (0.31, 0.30, 0.165)), ("belly", (0.76, 0.71, 0.49)), ("band", (0.075, 0.082, 0.058)),
               ("scute", (0.135, 0.14, 0.085)), ("mouth", (0.84, 0.68, 0.50)), ("teeth", (0.93, 0.90, 0.78)),
               ("iris", (0.62, 0.66, 0.20)), ("pupil", (0.03, 0.03, 0.025)), ("claw", (0.10, 0.09, 0.075))],
    # Where the back bends: the middle of it, and the joints ahead of that and behind it
    body=V(0.0, 0.29, 0.0), chest=V(0.0, 0.29, 0.22), neck=V(0.0, 0.30, 0.52), head=V(0.0, 0.31, 0.70),
    pelvis=V(0.0, 0.295, -0.25), tail_root=V(0.0, 0.305, -0.58), tail_piece=0.20, tail_tip=V(0.0, 0.255, -2.19),
    # (along it, centre height, half width, half height): a thick neck, a broad flat body, and a tail that
    # is as deep as the body where it leaves it and flattens from side to side to a blade
    trunk=[(0.76, 0.310, 0.105, 0.066), (0.68, 0.305, 0.128, 0.085), (0.60, 0.298, 0.150, 0.110), (0.50, 0.292, 0.185, 0.134),
           (0.40, 0.290, 0.225, 0.156), (0.25, 0.290, 0.268, 0.172), (0.05, 0.292, 0.292, 0.180), (-0.15, 0.294, 0.284, 0.178),
           (-0.32, 0.298, 0.250, 0.166), (-0.45, 0.304, 0.205, 0.154), (-0.58, 0.310, 0.158, 0.142), (-0.80, 0.306, 0.116, 0.130),
           (-1.05, 0.298, 0.084, 0.118), (-1.30, 0.290, 0.060, 0.106), (-1.55, 0.282, 0.041, 0.091), (-1.80, 0.272, 0.026, 0.072),
           (-2.02, 0.262, 0.016, 0.052), (-2.19, 0.255, 0.008, 0.028)],
    # The head above the line of the mouth (along it, underside, top, half width): the flat table of the skull,
    # the eyes standing up out of it, the long flat snout, the notch, and the swelling at the tip
    skull=[(0.66, 0.300, 0.372, 0.120), (0.72, 0.296, 0.384, 0.140), (0.78, 0.296, 0.387, 0.142), (0.84, 0.296, 0.382, 0.128),
           (0.90, 0.296, 0.358, 0.105), (0.96, 0.297, 0.343, 0.088), (1.03, 0.298, 0.336, 0.075), (1.09, 0.300, 0.333, 0.055),
           (1.14, 0.298, 0.338, 0.069), (1.185, 0.300, 0.337, 0.056)],
    # The lower jaw (along it, underside, top, half width), and where it hinges: right at the back
    jaw_shape=[(0.64, 0.246, 0.294, 0.116), (0.72, 0.232, 0.293, 0.134), (0.80, 0.232, 0.293, 0.131), (0.88, 0.240, 0.293, 0.107),
               (0.96, 0.250, 0.294, 0.083), (1.03, 0.256, 0.295, 0.070), (1.09, 0.258, 0.296, 0.059), (1.14, 0.260, 0.296, 0.061),
               (1.175, 0.264, 0.296, 0.048)],
    jaw=V(0.0, 0.295, 0.675),
    eye=(V(0.086, 0.392, 0.845), 0.021),
    # Shoulder, elbow, wrist, knuckles; hip, knee, heel, the root of the toes (the left legs: the right are their mirror)
    fore=[V(0.150, 0.275, 0.420), V(0.285, 0.185, 0.335), V(0.290, 0.050, 0.400), V(0.305, 0.030, 0.515)],
    hind=[V(0.135, 0.320, -0.450), V(0.310, 0.215, -0.365), V(0.305, 0.055, -0.470), V(0.335, 0.030, -0.285)],
    # How thick each leg is, at its joints and half way between them
    fore_shape=[0.070, 0.064, 0.050, 0.046, 0.036, 0.034, 0.030],
    hind_shape=[0.090, 0.082, 0.060, 0.054, 0.040, 0.040, 0.034],
)


def spline(table, z):
    """A row of `table` at `z` (its first column, which runs one way or the other), smoothly between its rows."""
    if table[0][0] > table[-1][0]:
        table = table[::-1]
    if z <= table[0][0]:
        return table[0][1:]
    if z >= table[-1][0]:
        return table[-1][1:]
    for i in range(len(table) - 1):
        a, b = table[i], table[i + 1]
        if z <= b[0]:
            before = table[max(i - 1, 0)]
            after = table[min(i + 2, len(table) - 1)]
            t = (z - a[0]) / (b[0] - a[0])
            out = []
            for k in range(1, len(a)):
                # (Catmull-Rom, the slope at each row that of the line between its neighbours)
                m0 = (b[k] - before[k]) / (b[0] - before[0]) * (b[0] - a[0])
                m1 = (after[k] - a[k]) / (after[0] - a[0]) * (b[0] - a[0])
                t2, t3 = t * t, t * t * t
                out.append((2 * t3 - 3 * t2 + 1) * a[k] + (t3 - 2 * t2 + t) * m0 + (-2 * t3 + 3 * t2) * b[k] + (t3 - t2) * m1)
            return tuple(out)
    return table[-1][1:]


def section(angle, rx, ry, power):
    """A point of a cross-section, `angle` round it from the top towards its left: squarer than an ellipse
    the higher `power` is (2 is an ellipse), and flatter underneath than on top."""
    s, c = math.sin(angle), math.cos(angle)
    under = power * 1.35 if c < 0.0 else power
    return math.copysign(abs(s) ** (2.0 / power), s) * rx, math.copysign(abs(c) ** (2.0 / under), c) * ry


def squareness(z):
    """The body is broad and flat; the tail is a blade."""
    return 2.7 - 0.7 * blend(-0.5, -1.2, z)


def hull(spec, z, angle, off=0.0):
    """A point on the hide of the body and the tail, at `z` along it and `angle` round it from the middle
    of the back (towards its left), stood `off` clear of it. The scutes are laid on this."""
    cy, rx, ry = spline(spec.trunk, z)
    x, y = section(angle, rx, ry, squareness(z))
    out = V(x / rx / rx, y / ry / ry, 0.0)
    out = out.normalized() if out.length > 0.0 else Y
    return V(x, cy + y, z) + out * off


def loft(b, rings, paint, close=(True, True)):
    """A skin over rings of points (each a list, going round the same way), its ends shut with a fan.
    `paint(ring, place)` says which material the face after that ring, at that place round it, is given."""
    made = [[b.bm.verts.new(kit.to_blender(p)) for p in ring] for ring in rings]
    count = len(rings[0])
    faces = []
    for r, (a, c) in enumerate(zip(made, made[1:])):
        for i in range(count):
            j = (i + 1) % count
            face = b.bm.faces.new((a[i], a[j], c[j], c[i]))
            face.material_index = paint(r, i)
            faces.append(face)
    for end, r in ((0, 0), (-1, len(rings) - 2)):
        if not close[end]:
            continue
        middle = sum(rings[end], Vector((0.0, 0.0, 0.0))) / count
        pole = b.bm.verts.new(kit.to_blender(middle))
        for i in range(count):
            face = b.bm.faces.new((made[end][i], made[end][(i + 1) % count], pole))
            face.material_index = paint(r, i)
            faces.append(face)
    bmesh.ops.recalc_face_normals(b.bm, faces=faces)


def finished(b):
    """What a part has built, as a mesh, each face keeping the material it was given."""
    mesh = bpy.data.meshes.new("part")
    b.bm.to_mesh(mesh)
    b.bm.free()
    return mesh


def painted(b, choose):
    """Gives every face a material by where it is and which way it faces: `choose(middle, normal)`, in Godot space."""
    b.bm.normal_update()
    for face in b.bm.faces:
        face.material_index = choose(kit.from_blender(face.calc_center_median()), kit.from_blender(face.normal))
    return finished(b)


def banded(z):
    """Whether a dark band crosses the tail at `z`: broad ones, closer together towards the tip."""
    if z > -0.66:
        return False
    return ((-0.66 - z) / 0.25) % 1.0 < 0.44


def blotched(z, place):
    """Whether a dark patch lies on the flank at `z`, `place` of the way from the back round to the belly:
    a row of them low on the flank, and a second row above, between those."""
    if z > 0.50 or z < -0.66:
        return False
    upper = place < 0.44
    return ((z + (0.12 if upper else 0.0)) / 0.24) % 1.0 < (0.26 if upper else 0.40)


def hide(spec):
    def shapes(b):
        low = kit.LOW
        round_it = 10 if low else 22
        step = 0.13 if low else 0.052
        front, back = spec.trunk[0][0], spec.trunk[-1][0]
        count = int(round((front - back) / step))
        stations = [front + (back - front) * i / count for i in range(count + 1)]
        rings = [[hull(spec, z, math.tau * (k + 0.5) / round_it) for k in range(round_it)] for z in stations]

        def paint(r, i):
            z = (stations[r] + stations[min(r + 1, count)]) * 0.5
            # (how far round from the middle of the back to the middle of the belly, 0..1)
            place = abs(((i + 1.0) / round_it + 0.5) % 1.0 - 0.5) * 2.0
            # The belly's pale hide comes less far up the sides of the tail
            belly = 0.60 + 0.16 * blend(-0.5, -1.4, z)
            if place > belly:
                return BELLY
            if banded(z):
                return BAND
            if place > 0.30:
                return BAND if blotched(z, place) and not low else FLANK
            return BACK
        loft(b, rings, paint)
        return finished(b)
    return shapes


def scutes(spec):
    def shapes(b):
        low = kit.LOW

        def keel(z, angle, length, width, height):
            """A keeled plate lying on the hide: a ridge along it, sloping down to each side and each end."""
            turn = width / max(spline(spec.trunk, z)[1], 0.03)
            corners = [hull(spec, z + dz, angle + da, -0.004) for dz, da in
                       ((-length, -turn), (-length, turn), (length, turn), (length, -turn))]
            ridge = [hull(spec, z - length * 0.75, angle, height * 0.8), hull(spec, z + length * 0.45, angle, height)]
            made = [b.bm.verts.new(kit.to_blender(p)) for p in corners + ridge]
            for face in ((0, 1, 4), (1, 2, 5, 4), (2, 3, 5), (3, 0, 4, 5)):
                b.bm.faces.new([made[i] for i in face])

        def blade(z, angle, length, thick, height):
            """A scute of the tail's crest: an upright plate, leaning back to a point."""
            turn = thick / max(spline(spec.trunk, z)[1], 0.006)
            corners = [hull(spec, z + dz, angle + da, -0.004) for dz, da in
                       ((-length, -turn), (-length, turn), (length, turn), (length, -turn))]
            top = hull(spec, z - length * 0.55, angle, height)
            made = [b.bm.verts.new(kit.to_blender(p)) for p in corners + [top]]
            for face in ((0, 1, 4), (1, 2, 4), (2, 3, 4), (3, 0, 4), (3, 2, 1, 0)):
                b.bm.faces.new([made[i] for i in face])

        # Behind the head, a cluster of four big ones and two; then rows of six across the back, the keels
        # of the two outer rows the tallest
        if not low:
            for z, across in ((0.640, (-0.5, 0.5)), (0.585, (-1.5, -0.5, 0.5, 1.5))):
                for k in across:
                    keel(z, k * 0.36, 0.024, 0.030, 0.015)
        row = 0.125 if low else 0.064
        z = 0.50
        while z > -0.60:
            _, rx, _ = spline(spec.trunk, z)
            across = (-1.5, 0.0, 1.5) if low else (-2.5, -1.5, -0.5, 0.5, 1.5, 2.5)
            for k in across:
                outer = abs(k) > 2.0 or (low and k != 0.0)
                keel(z, k * 0.235, row * 0.42, min(0.036, rx * 0.16), 0.022 if outer else 0.014)
            z -= row
        # The tail: two crests, drawing together, which become one half way down it
        meet = -1.36
        row = 0.14 if low else 0.076
        z = -0.63
        while z > -2.12:
            _, rx, ry = spline(spec.trunk, z)
            high = 0.045 + 0.035 * math.sin(math.pi * blend(-0.6, -2.3, z))
            if z > meet:
                apart = 0.50 * blend(meet - 0.05, -0.62, z) + 0.10
                for side in (1.0, -1.0):
                    blade(z, side * apart, row * 0.48, 0.011, high * 0.8)
                if not low:
                    # (and the low rows between them, which die out)
                    keel(z, 0.0, row * 0.4, 0.020, 0.008)
            else:
                blade(z, 0.0, row * 0.50, min(0.010, rx * 0.5), high)
            z -= row
        bmesh.ops.recalc_face_normals(b.bm, faces=b.bm.faces[:])
    return shapes


def head_ring(z, under, top, rx, round_it, scale=1.0):
    cy, ry = (under + top) * 0.5, (top - under) * 0.5
    ring = []
    for k in range(round_it):
        x, y = section(math.tau * (k + 0.5) / round_it, rx * scale, ry * scale, 3.4)
        ring.append(V(x, cy + y, z))
    return ring


def head_rings(table, round_it):
    """The rings of the head or of the lower jaw, with its tip rounded off."""
    step = 2 if kit.LOW else 1
    rows = table[::step] if (len(table) - 1) % step == 0 else table[::step] + [table[-1]]
    rings = [head_ring(z, under, top, rx, round_it) for z, under, top, rx in rows]
    z, under, top, rx = table[-1]
    for ahead, scale in ((0.016, 0.80),) if kit.LOW else ((0.012, 0.90), (0.022, 0.66), (0.027, 0.36)):
        rings.append(head_ring(z + ahead, under, top, rx, round_it, scale))
    return rings


def skull(spec):
    def shapes(b):
        round_it = 8 if kit.LOW else 18

        def paint(_r, i):
            place = abs(((i + 1.0) / round_it + 0.5) % 1.0 - 0.5) * 2.0
            # Dark on top, lighter down the sides of the jaw, and the roof of the mouth underneath
            return BACK if place < 0.36 else FLANK if place < 0.77 else MOUTH
        loft(b, head_rings(spec.skull, round_it), paint)
        at, radius = spec.eye
        for side in (1.0, -1.0):
            # The eye stands up out of the table of the skull in a socket of bone, with a brow over it
            b.ellipsoid(V(side * (at.x - 0.014), at.y - 0.012, at.z - 0.004), V(0.034, 0.024, 0.048), None, 10, 5)
            b.ellipsoid(V(side * (at.x - 0.022), at.y + 0.010, at.z - 0.012), V(0.022, 0.012, 0.040), Matrix.Rotation(-side * 0.35, 3, "Z"), 8, 4)
            # The flap over the ear, behind the eye, at the edge of the table
            b.ellipsoid(V(side * 0.118, 0.378, 0.752), V(0.018, 0.012, 0.040), None, 8, 4)
        # The nostrils, on a low mound of their own at the tip
        b.ellipsoid(V(0.0, 0.338, 1.166), V(0.036, 0.013, 0.030), None, 10, 4)
        mesh = finished(b)
        return mesh
    return shapes


def lower_jaw(spec):
    def shapes(b):
        round_it = 8 if kit.LOW else 18

        def paint(_r, i):
            place = abs(((i + 1.0) / round_it + 0.5) % 1.0 - 0.5) * 2.0
            # The floor of the mouth on top, and pale under the chin
            return MOUTH if place < 0.23 else FLANK if place < 0.52 else BELLY
        loft(b, head_rings(spec.jaw_shape, round_it), paint)
        return finished(b)
    return shapes


def gullet(spec):
    def shapes(b):
        # The back of the mouth, so that nothing is seen through when it gapes, and its tongue, which is
        # fixed to the floor of it
        b.ellipsoid(V(0.0, 0.292, 0.700), V(0.110, 0.034, 0.050), None, 10, 5)
        b.ellipsoid(V(0.0, 0.292, 0.900), V(0.050, 0.012, 0.170), None, 10, 4)
    return shapes


def tooth(b, base, tip, radius):
    ahead = (tip - base).normalized()
    u = ahead.cross(Z if abs(ahead.z) < 0.9 else X).normalized()
    v = ahead.cross(u)
    b.tube([(base.lerp(tip, t), u * radius * (1.0 - t * 0.9), v * radius * (1.0 - t * 0.9)) for t in (0.0, 0.6, 1.0)], 5)


def edge_of(table, z):
    under, top, rx = spline(table, z)
    return under, top, rx


def upper_teeth(spec):
    def shapes(b):
        # Down the edge of the upper jaw, outside the lower: they show with the mouth shut. Bigger where
        # the jaw swells, at the tip and half way back.
        count = 9 if kit.LOW else 17
        for side in (1.0, -1.0):
            for i in range(count):
                z = 0.800 + (1.180 - 0.800) * i / (count - 1)
                under, _, rx = edge_of(spec.skull, z)
                big = 0.6 + 0.5 * max(math.exp(-((z - 1.14) / 0.035) ** 2), math.exp(-((z - 0.955) / 0.05) ** 2))
                if abs(z - 1.09) < 0.016:
                    continue  # (the notch)
                base = V(side * rx * 0.92, under + 0.004, z)
                tooth(b, base, base + V(side * 0.003, -0.026 * big, 0.002), 0.0062 * (0.7 + 0.4 * big))
            # (the front ones, round the tip)
            for x, z in ((0.040, 1.193),) if kit.LOW else ((0.046, 1.188), (0.030, 1.202), (0.011, 1.207)):
                base = V(side * x, 0.303, z)
                tooth(b, base, base + V(0.0, -0.022, 0.003), 0.0058)
    return shapes


def lower_teeth(spec):
    def shapes(b):
        # Up from the lower jaw, between the upper teeth; and the fourth, the big one, which stands up
        # outside the upper jaw in its notch
        count = 7 if kit.LOW else 14
        for side in (1.0, -1.0):
            for i in range(count):
                z = 0.812 + (1.165 - 0.812) * i / (count - 1)
                _, top, rx = edge_of(spec.jaw_shape, z)
                base = V(side * rx * 0.84, top - 0.004, z)
                tooth(b, base, base + V(side * 0.002, 0.020, 0.0), 0.0052)
            _, top, rx = edge_of(spec.jaw_shape, 1.092)
            base = V(side * (rx + 0.002), top - 0.008, 1.092)
            tooth(b, base, base + V(side * 0.003, 0.046, 0.002), 0.0082)
    return shapes


def eyes(spec):
    def shapes(b):
        at, radius = spec.eye
        for side in (1.0, -1.0):
            b.ellipsoid(V(side * at.x, at.y, at.z), V(radius * 0.9, radius, radius * 1.15), None, 10, 6)
    return shapes


def pupils(spec):
    def shapes(b):
        # A slit, upright, looking out to the side and a little forward
        at, radius = spec.eye
        for side in (1.0, -1.0):
            b.ellipsoid(V(side * (at.x + radius * 0.78), at.y + 0.002, at.z + 0.004), V(0.0045, radius * 0.62, 0.0050), Matrix.Rotation(-side * 0.25, 3, "Z"), 6, 4)
    return shapes


def lids(spec):
    def shapes(b):
        # The upper lid, a shell over the top of the eye. The rig turns it down about the eye to shut it.
        at, radius = spec.eye
        for side in (1.0, -1.0):
            centre = V(side * at.x, at.y, at.z)
            rings = []
            for k in range(4):
                rise = 0.45 + k * 0.32
                c, s = math.cos(rise), math.sin(rise)
                rings.append((centre + V(side * radius * 0.40 * c, radius * 1.12 * s, 0.0), X * (side * radius * 0.82 * c), Z * (radius * 1.30 * c)))
            b.tube(rings, 8)
    return shapes


def dark_bits(spec):
    def shapes(b):
        # The nostrils, two slits on their mound, and the slit of each ear under its flap
        for side in (1.0, -1.0):
            b.ellipsoid(V(side * 0.014, 0.350, 1.170), V(0.007, 0.004, 0.011), Matrix.Rotation(side * 0.4, 3, "Y"), 6, 3)
            b.ellipsoid(V(side * 0.134, 0.372, 0.752), V(0.005, 0.005, 0.030), None, 6, 3)
    return shapes


def leg_points(joints, thick):
    """The line of a leg and how thick it is along it: at each joint and half way between."""
    points, radii = [], []
    for i in range(3):
        points += [joints[i], joints[i].lerp(joints[i + 1], 0.5)]
    points.append(joints[3])
    # (the muscle of the upper arm and the thigh, and of the forearm and the calf, stands out behind the bone)
    points[1] = points[1] + V(0.0, 0.012, 0.0)
    return points, list(thick)


def legs(spec):
    def shapes(b):
        for suffix, joints in spec.legs.items():
            fore = suffix[1] == "f"
            points, radii = leg_points(joints, spec.fore_shape if fore else spec.hind_shape)
            b.strand(points, radii, 10)
            # The hand or the foot: a flat pad under the last of it
            pad = joints[2].lerp(joints[3], 0.6)
            b.ellipsoid(V(pad.x, 0.022, pad.z), V(0.040 if fore else 0.048, 0.022, 0.060 if fore else 0.090), None, 8, 4)

        def choose(middle, normal):
            # Dark on top, and pale underneath, as its belly is
            return BELLY if normal.y < -0.45 else BACK if normal.y > 0.35 else FLANK
        return painted(b, choose)
    return shapes


def toe_lines(spec, suffix):
    """Each toe of a foot: where it starts, where it ends, and how thick. Five on a fore foot, spread wide;
    four on a hind foot, long, with a web between them."""
    joints = spec.legs[suffix]
    fore = suffix[1] == "f"
    side = 1.0 if suffix[2] == "l" else -1.0
    root = joints[3]
    toes = []
    spread = (-0.85, -0.38, 0.05, 0.50, 1.00) if fore else (-0.42, -0.06, 0.32, 0.72)
    lengths = (0.060, 0.082, 0.090, 0.080, 0.058) if fore else (0.105, 0.130, 0.125, 0.095)
    if kit.LOW:
        spread, lengths = spread[::2], lengths[::2]
    for angle, length in zip(spread, lengths):
        # (measured outwards from straight ahead: the outer toes point away from the body)
        way = V(side * math.sin(angle), 0.0, math.cos(angle))
        start = V(root.x, 0.020, root.z) + way * 0.012
        toes.append((start, start + way * length, 0.013 if fore else 0.015))
    return toes


def toes(spec):
    def shapes(b):
        for suffix in SUFFIXES:
            lines = toe_lines(spec, suffix)
            for start, end, radius in lines:
                b.strand([start, start.lerp(end, 0.55) + V(0.0, 0.004, 0.0), end + V(0.0, -0.006, 0.0)], [radius, radius * 0.85, radius * 0.6], 6)
            if suffix[1] == "r" and not kit.LOW:
                # The web: a thin skin from toe to toe
                for (a0, a1, _), (c0, c1, _) in zip(lines, lines[1:]):
                    corners = [a0, a0.lerp(a1, 0.8), c0.lerp(c1, 0.8), c0]
                    for flip in (False, True):
                        made = [b.bm.verts.new(kit.to_blender(V(p.x, 0.014 if flip else 0.018, p.z))) for p in corners]
                        b.bm.faces.new(made[::-1] if flip else made)

        def choose(middle, normal):
            return BELLY if normal.y < -0.45 else BACK if normal.y > 0.35 else FLANK
        return painted(b, choose)
    return shapes


def claws(spec):
    def shapes(b):
        for suffix in SUFFIXES:
            fore = suffix[1] == "f"
            lines = toe_lines(spec, suffix)
            # (the two outer toes of a fore foot, and the outer one of a hind foot, have none)
            for start, end, radius in (lines[:3] if not kit.LOW else lines[:2]):
                way = (end - start).normalized()
                tip = end + way * (0.026 if fore else 0.030) + V(0.0, -0.008, 0.0)
                tooth(b, end + V(0.0, -0.004, 0.0) - way * 0.006, tip, radius * 0.55)
    return shapes


def weights(spec):
    tail_at = [spec.tail_root.z - spec.tail_piece * k for k in range(len(TAIL_BONES))]
    # The joints going forward from the middle of the back, and those going back from it: where each is, and
    # over how long a piece of the hide the bend at it is shared
    ahead = [("chest", spec.chest.z, 0.13), ("neck", spec.neck.z, 0.07), ("head", spec.head.z - 0.02, 0.05)]
    behind = [("pelvis", spec.pelvis.z, 0.13), ("tail", tail_at[0], 0.09)] + [(name, at, 0.07) for name, at in zip(TAIL_BONES[1:], tail_at[1:])]

    def along_back(z):
        chain = ahead if z >= 0.0 else behind
        way = 1.0 if z >= 0.0 else -1.0
        past = [1.0] + [blend(at - way * width, at + way * width, z) for _, at, width in chain] + [0.0]
        names = ["body"] + [name for name, _, _ in chain]
        made = {}
        run = 1.0
        for i, name in enumerate(names):
            run *= past[i]
            made[name] = run * (1.0 - past[i + 1])
        return made

    def weigh(part, p):
        suffix = "_l" if p.x >= 0.0 else "_r"
        if part in ("lower_jaw", "lower_teeth", "gullet"):
            return {"jaw": 1.0}
        if part in ("skull", "upper_teeth", "eyes", "pupils", "dark"):
            return {"head": 1.0}
        if part == "lids":
            return {"lid" + suffix: 1.0}
        if part in ("legs", "toes", "claws"):
            leg = ("_f" if p.z > 0.0 else "_r") + ("l" if p.x >= 0.0 else "r")
            if part != "legs":
                return {"paw" + leg: 1.0}
            joints = spec.legs[leg]
            place = dog.chain_param(p, joints)[1]
            spans = [(b - a).length for a, b in zip(joints, joints[1:])]
            low = blend(1.0 - 0.035 / spans[0], 1.0 + 0.035 / spans[1], place)
            hock = blend(2.0 - 0.03 / spans[1], 2.0 + 0.03 / spans[2], place)
            return {"upper" + leg: 1.0 - low, "lower" + leg: low * (1.0 - hock), "hock" + leg: low * hock}
        return along_back(p.z)
    return weigh


def bones(spec):
    listed = [("body", spec.body, None), ("chest", spec.chest, "body"), ("neck", spec.neck, "chest"), ("head", spec.head, "neck"),
              ("jaw", spec.jaw, "head"), ("pelvis", spec.pelvis, "body")]
    at, _ = spec.eye
    for side, suffix in ((1.0, "_l"), (-1.0, "_r")):
        listed.append(("lid" + suffix, V(side * at.x, at.y, at.z), "head"))
    chain = ["pelvis"] + TAIL_BONES + ["tail_end"]
    for i in range(len(TAIL_BONES)):
        z = spec.tail_root.z - spec.tail_piece * i
        listed.append((chain[i + 1], V(0.0, spline(spec.trunk, z)[0], z), chain[i]))
    # (carries nothing: it marks where the tail ends, for the rig)
    listed.append(("tail_end", spec.tail_tip, TAIL_BONES[-1]))
    for suffix, joints in spec.legs.items():
        for bone, joint in zip(("upper", "lower", "hock", "paw"), joints):
            listed.append((bone + suffix, joint, "body"))
    return listed


def parts(spec):
    # (the hide, the head, the jaw, the legs and the toes paint their own faces: see `loft` and `painted`)
    return [
        ("hide", None, hide(spec), None), ("scutes", SCUTE, scutes(spec), None),
        ("skull", None, skull(spec), None), ("lower_jaw", None, lower_jaw(spec), None), ("gullet", MOUTH, gullet(spec), None),
        ("upper_teeth", TEETH, upper_teeth(spec), None), ("lower_teeth", TEETH, lower_teeth(spec), None),
        ("eyes", IRIS, eyes(spec), None), ("pupils", PUPIL, pupils(spec), None), ("lids", BACK, lids(spec), None),
        ("dark", PUPIL, dark_bits(spec), None),
        ("legs", None, legs(spec), None), ("toes", None, toes(spec), None), ("claws", CLAW, claws(spec), None),
    ]


def preview(folder, name):
    """Pictures of it framed for something a crocodile's shape (the kit's own are framed for a boy)."""
    scene = bpy.context.scene
    camera = scene.camera
    for view, direction, target, frame in (("near_side", (1, 0, 0), (0.0, 0.5, 0.3), 3.8), ("near_quarter", (0.7, -0.7, 0.35), (0.0, 0.5, 0.3), 3.8),
                                           ("near_top", (0.02, -0.05, 1), (0.0, 0.5, 0.3), 3.8), ("near_front", (0.2, -1, 0.25), (0.0, 0.0, 0.3), 1.6),
                                           ("near_head", (0.75, -0.6, 0.25), (0.0, -0.9, 0.32), 0.8), ("near_under", (0.5, -0.3, -0.8), (0.0, 0.0, 0.3), 3.2)):
        offset = Vector(direction).normalized() * 8.0
        camera.data.ortho_scale = frame
        camera.location = Vector(target) + offset
        camera.rotation_euler = (-offset).to_track_quat("-Z", "Y").to_euler()
        scene.render.filepath = os.path.join(folder, "%s_%s.png" % (name, view))
        bpy.ops.render.render(write_still=True)


if __name__ == "__main__":
    for low in (False, True):
        kit.LOW = low
        name = NILE.name + ("_lo" if low else "")
        if kit.ONLY and name not in kit.ONLY:
            continue
        kit.export(name, bones(NILE), parts(NILE), weights(NILE), NILE.materials)
        if kit.PREVIEW_DIR:
            preview(kit.PREVIEW_DIR, name)
