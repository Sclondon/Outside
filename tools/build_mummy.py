"""Builds the mummy and exports it for Godot.

Run from the project root:
    blender --background --python tools/build_mummy.py [-- <folder for preview renders>]

Writes models/mummy.glb and models/mummy_lo.glb, with editable copies in tools/.

It is a man's shape got wrong. The arms are far too long: the wrists hang at
the knees and the fingers well below them. The body is long and pinched in at
the waist, with a hump between shoulders that sit up by the neck; the head is
small, on a long neck; the shanks are sticks under knobs of knees; the hands
are bone, with fingers twice the length they should be.

Under the wrappings it has a face, but only as the cloth lies over it: a brow,
two hollows where the eyes were, the bridge of a nose that has fallen in,
cheekbones over sunken cheeks, a jaw. Nothing is drawn on it.

Loose ends of bandage hang from the wrists, the elbows, the shoulders and the
waist, and one trails from a shin. Each has a chain of bones of its own
(`drape_<name>_0`, `_1`..., the last of them only marking where it ends), which
scripts/mummy_rig.gd swings as a chain of weights.

It is modelled with its arms held out from its sides (ARM_REST), in Godot space
(metres, Y up, facing +Z, +X its left). The rig reads its proportions from the
bones, so nothing here needs copying anywhere else.
"""

import math
import os
import sys

import bmesh
import bpy
from mathutils import Matrix, Vector
from mathutils.bvhtree import BVHTree

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import build_character as kit  # noqa: E402  (shared shape-building and export tools)

X, Y, Z = kit.X, kit.Y, kit.Z
blend = kit.blend

# --- Joints ---

ANKLE_Y = 0.05
THIGH = 0.275
SHIN = 0.335
HIP_X = 0.058
HIP_Y = ANKLE_Y + THIGH + SHIN
KNEE_Y = HIP_Y - THIGH
HIPS = Vector((0.0, HIP_Y + 0.02, 0.0))
SPINE = Vector((0.0, 0.75, 0.0))
CHEST = Vector((0.0, 0.95, 0.0))
NECK = Vector((0.0, 1.135, 0.012))
HEAD = Vector((0.0, 1.245, 0.036))
SHOULDER = Vector((0.118, 1.10, 0.01))
UPPER_ARM = 0.33
FOREARM = 0.35
# How far out from hanging the arms are modelled, radians. The rig measures it.
ARM_REST = 0.6
TOE = Vector((0.0, -0.035, 0.085))
HEAD_CENTRE = HEAD + Vector((0.0, 0.058, 0.016))
HEAD_RADII = Vector((0.064, 0.086, 0.076))

LINEN, OLD_LINEN, WITHERED = range(3)
MATERIALS = [
    ("linen", (0.52, 0.47, 0.37)),
    ("old_linen", (0.40, 0.35, 0.26)),
    ("withered", (0.20, 0.16, 0.12)),
]

# Fingers, index to little: (offset across the palm, length, thickness, how far it fans out).
FINGERS = [(0.0205, 0.088, 0.0064, 0.26), (0.0068, 0.100, 0.0066, 0.08), (-0.0068, 0.092, 0.0064, -0.08), (-0.0205, 0.072, 0.0058, -0.26)]
KNUCKLES = (0.0, 0.42, 0.74)
PALM = 0.07
THUMB_LENGTH = 0.062

# The finished torso and skull, to lay strips of bandage on.
TORSO_SURFACE = None
HEAD_SURFACE = None


def shoulder_of(side):
    return Vector((side * SHOULDER.x, SHOULDER.y, SHOULDER.z))


def arm_out(side):
    """Moves a point modelled on an arm hanging straight down out to the rest pose."""
    shoulder = shoulder_of(side)
    turn = Matrix.Rotation(side * ARM_REST, 3, "Z")
    return lambda p: shoulder + turn @ (p - shoulder)


def arm_in(side, p):
    """And back: where a point of the rest pose is on the hanging arm."""
    shoulder = shoulder_of(side)
    return shoulder + Matrix.Rotation(-side * ARM_REST, 3, "Z") @ (p - shoulder)


def hand_wrist(side):
    return shoulder_of(side) + Vector((0.0, -UPPER_ARM - FOREARM, 0.002))


def finger_line(side, index):
    """A finger's knuckle and the way it points, on the hanging arm."""
    z, _length, _radius, fan = FINGERS[index]
    return hand_wrist(side) + Vector((0.0, -PALM, z)), Vector((0.0, -math.cos(fan), math.sin(fan)))


def thumb_line(side):
    inward = -side
    return hand_wrist(side) + Vector((inward * 0.004, -0.02, 0.02)), Vector((inward * 0.22, -0.72, 0.66)).normalized()


# --- Strips of bandage laid on a surface ---

def onto(surface, point):
    """The place on `surface` nearest `point` (which is outside it), and which way it faces there."""
    location, normal, _index, _distance = surface.find_nearest(kit.to_blender(point))
    at, facing = kit.from_blender(location), kit.from_blender(normal).normalized()
    return at, (facing if facing.dot(point - at) >= 0.0 else -facing)


def rounded(guides, widths, passes=2):
    """Cuts the corners off a line of points (and the widths that go with them)."""
    for _ in range(passes):
        points, wide = [guides[0]], [widths[0]]
        for i in range(len(guides) - 1):
            for t in (0.25, 0.75):
                points.append(guides[i].lerp(guides[i + 1], t))
                wide.append(widths[i] + (widths[i + 1] - widths[i]) * t)
        guides, widths = points + [guides[-1]], wide + [widths[-1]]
    return guides, widths


def ribbon(b, surface, guides, widths, lift, steps, columns=3, passes=2):
    """A strip of cloth lying on `surface`: it follows `guides` (points just outside
    it), is as wide as `widths` says at each, stands `lift` off it, and its edges
    are turned under so it has a thickness."""
    if kit.LOW:
        steps, columns = max(steps // 3, 3), 1
    guides, widths = rounded([Vector(guide) for guide in guides], list(widths), passes)
    lengths = [0.0]
    for a, c in zip(guides, guides[1:]):
        lengths.append(lengths[-1] + (c - a).length)
    centres = []
    for k in range(steps + 1):
        distance = lengths[-1] * k / steps
        i = max(j for j in range(len(guides) - 1) if lengths[j] <= distance + 1e-9)
        t = (distance - lengths[i]) / max(lengths[i + 1] - lengths[i], 1e-9)
        at, facing = onto(surface, guides[i].lerp(guides[i + 1], t))
        centres.append((at, facing, widths[i] + (widths[i + 1] - widths[i]) * t))
    top, under = [], []
    for k, (at, facing, width) in enumerate(centres):
        along = (centres[min(k + 1, steps)][0] - centres[max(k - 1, 0)][0]).normalized()
        across = facing.cross(along).normalized()
        row, below = [], []
        for m in range(columns + 1):
            p, n = onto(surface, at + facing * 0.012 + across * width * (m / columns - 0.5))
            row.append(b._vert(p + n * lift, None))
            below.append(p - n * 0.004)
        top.append(row)
        under.append(below)
    faces = []
    for k in range(steps):
        for m in range(columns):
            faces.append(b.bm.faces.new((top[k][m], top[k][m + 1], top[k + 1][m + 1], top[k + 1][m])))
    rim = ([(k, 0) for k in range(steps + 1)] + [(steps, m) for m in range(1, columns + 1)]
           + [(k, columns) for k in range(steps - 1, -1, -1)] + [(0, m) for m in range(columns - 1, 0, -1)])
    turned = {at: b._vert(under[at[0]][at[1]], None) for at in rim}
    for a, c in zip(rim, rim[1:] + rim[:1]):
        faces.append(b.bm.faces.new((top[a[0]][a[1]], top[c[0]][c[1]], turned[c], turned[a])))
    bmesh.ops.recalc_face_normals(b.bm, faces=faces)
    faces[0].normal_update()
    if faces[0].normal.dot(kit.to_blender(centres[0][1])) < 0.0:
        bmesh.ops.reverse_faces(b.bm, faces=faces)


def winding(centre, radii, height, tilt, start=0.0, sweep=math.tau + 0.4, count=28):
    """Guide points for a turn of bandage round something: a ring `height` up from
    `centre`, tipped over by `tilt` (a rotation), standing off it."""
    points = []
    for k in range(count + 1):
        angle = start + sweep * k / count
        points.append(centre + tilt @ Vector((math.sin(angle) * radii.x, height, math.cos(angle) * radii.z)))
    return points


# --- Shapes ---

TORSO_FUSE = (0.004, 3, 6000)


def torso(_builder):
    """Pelvis, a pinched waist, a narrow cage of ribs, a hump, and the neck: one surface."""
    global TORSO_SURFACE
    b = kit.Builder()
    # (height, half width, half depth, how far forward)
    profile = [(0.585, 0.040, 0.040, 0.0), (0.63, 0.080, 0.064, 0.0), (0.70, 0.084, 0.066, 0.0), (0.76, 0.062, 0.050, 0.0),
               (0.84, 0.058, 0.048, 0.002), (0.92, 0.076, 0.064, 0.006), (1.00, 0.094, 0.076, 0.010), (1.06, 0.110, 0.072, 0.012),
               (1.10, 0.114, 0.062, 0.012), (1.135, 0.084, 0.050, 0.014), (1.16, 0.040, 0.038, 0.018)]
    b.tube(kit.lapped(0.0, 0.0, profile, 0.032, 0.005), 20)
    # The hump, and the knobs of the shoulders up beside the neck
    b.ellipsoid(Vector((0.0, 1.045, -0.05)), Vector((0.088, 0.08, 0.052)), None, 16, 7)
    for side in (1.0, -1.0):
        b.ellipsoid(Vector((side * 0.104, 1.104, 0.008)), Vector((0.04, 0.034, 0.04)), None, 12, 6)
    # A long neck, thrust forward
    neck = [(1.12, 0.036, 0.036, 0.010), (1.17, 0.029, 0.029, 0.020), (1.22, 0.026, 0.027, 0.031), (1.27, 0.026, 0.027, 0.042), (1.30, 0.025, 0.026, 0.048)]
    b.tube(kit.lapped(0.0, 0.0, neck, 0.021, 0.003), 12)
    mesh = kit.fused(b, None if kit.LOW else TORSO_FUSE)
    TORSO_SURFACE = BVHTree.FromPolygons([vertex.co.copy() for vertex in mesh.vertices], [tuple(face.vertices) for face in mesh.polygons])
    return mesh


def sashes(b):
    """Turns of bandage that cross the chest and the belly at a slant, over the level ones."""
    stand = Vector((0.16, 0.0, 0.12))
    for height, lean, twist, width, lift in ((0.98, 0.5, 0.1, 0.034, 0.005), (0.93, -0.42, -0.12, 0.03, 0.0045), (0.74, 0.22, 0.2, 0.036, 0.005)):
        tilt = Matrix.Rotation(lean, 3, "Z") @ Matrix.Rotation(twist, 3, "X")
        centre = Vector((0.0, height, 0.004))
        ribbon(b, TORSO_SURFACE, winding(centre, stand, 0.0, tilt, 0.6), [width] * 29, lift, 44, 3)


def legs(b):
    for side in (1.0, -1.0):
        # A stick of a shank, a knob of a knee, a wasted thigh
        leg = [(0.045, 0.021, 0.023, 0.0), (0.07, 0.019, 0.021, 0.0), (0.16, 0.021, 0.023, -0.004), (0.29, 0.029, 0.031, -0.006),
               (0.355, 0.027, 0.029, 0.0), (0.385, 0.034, 0.036, 0.006), (0.415, 0.030, 0.032, 0.004), (0.52, 0.035, 0.037, 0.0),
               (0.64, 0.042, 0.044, 0.0), (0.70, 0.038, 0.040, 0.0)]
        b.tube(kit.lapped(side * HIP_X, 0.0, leg, 0.03, 0.0045), 14)


def feet(b):
    for side in (1.0, -1.0):
        ankle = Vector((side * HIP_X, ANKLE_Y, 0.0))

        def across(z, y, rx, ry, ankle=ankle):
            return (ankle + Vector((0.0, y, z)), X * rx, Y * ry)

        # Long, narrow and bound: a heel, a high bony instep, toes drawn to a point
        upper = [across(-0.042, -0.020, 0.020, 0.026), across(-0.02, -0.010, 0.025, 0.038), across(0.01, -0.012, 0.027, 0.036),
                 across(0.045, -0.024, 0.029, 0.025), across(0.085, -0.032, 0.031, 0.018), across(0.125, -0.037, 0.028, 0.013),
                 across(0.155, -0.040, 0.020, 0.010)]
        b.tube(kit.dome(upper[0], -Z, 0.012, 3)[::-1] + upper + kit.dome(upper[-1], Z, 0.014, 3), 14, 0.0)


def arms(b):
    for side in (1.0, -1.0):
        b.place = arm_out(side)
        # (height from the shoulder, half thickness, half width, forward)
        arm = [(-0.70, 0.016, 0.018, 0.0), (-0.675, 0.019, 0.021, 0.0), (-0.64, 0.015, 0.017, 0.0), (-0.50, 0.018, 0.020, 0.0),
               (-0.38, 0.020, 0.022, 0.0), (-0.335, 0.027, 0.028, -0.003), (-0.30, 0.021, 0.023, 0.0), (-0.18, 0.023, 0.025, 0.0),
               (-0.06, 0.027, 0.029, 0.0), (0.0, 0.035, 0.037, 0.0), (0.028, 0.026, 0.03, 0.0)]
        b.tube(kit.lapped(side * SHOULDER.x, SHOULDER.z, [(SHOULDER.y + y, rx, rz, z) for y, rx, rz, z in arm], 0.026, 0.004), 12)
    b.place = None


def hands(b):
    """The palms: bound, thin, and too long."""
    for side in (1.0, -1.0):
        b.place = arm_out(side)
        wrist = hand_wrist(side)
        palm = [(0.02, 0.014, 0.016), (0.0, 0.0125, 0.018), (-0.03, 0.0105, 0.024), (-0.058, 0.0092, 0.0285), (-PALM - 0.002, 0.0082, 0.027)]
        rings = [(wrist + Y * dy, X * rx, Z * rz) for dy, rx, rz in palm]
        b.tube(rings + kit.dome(rings[-1], -Y, 0.006, 2), 12)
        if kit.LOW:
            # Demade: the fingers are one long blade
            inward = -side
            mitt = [(-PALM, 0.0, 0.007, 0.027), (-PALM - 0.05, 0.004, 0.006, 0.026), (-PALM - 0.095, 0.012, 0.004, 0.016)]
            b.tube([(wrist + Vector((inward * x, dy, 0.0)), X * rx, Z * rz) for dy, x, rx, rz in mitt], 12)
    b.place = None


def fingers(b):
    """Bare bone and dried skin: straight and spread, swollen at each joint."""
    if kit.LOW:
        return
    spans = (-0.1, 0.0, 0.06, 0.2, 0.36, 0.42, 0.48, 0.6, 0.69, 0.74, 0.79, 0.9, 1.0)
    knobs = (0.9, 1.25, 1.05, 0.72, 0.9, 1.12, 0.9, 0.66, 0.84, 1.0, 0.8, 0.6, 0.42)
    for side in (1.0, -1.0):
        b.place = arm_out(side)
        for index, (_z, length, radius, _fan) in enumerate(FINGERS):
            knuckle, along = finger_line(side, index)
            b.strand([knuckle + along * length * t for t in spans], [radius * knob for knob in knobs], 6)
        root, along = thumb_line(side)
        b.strand([root + along * THUMB_LENGTH * t for t in (-0.2, 0.0, 0.25, 0.5, 0.62, 0.8, 1.0)], [0.0085, 0.0095, 0.007, 0.0085, 0.0068, 0.006, 0.0042], 6)
    b.place = None


def skull_point(angle, phi):
    """A point of the head: `angle` round from the front (towards its left), `phi` up from its middle."""
    c, s = math.cos(phi), math.sin(phi)
    jaw = max(0.0, -s)
    front = math.cos(angle)
    x = math.sin(angle) * HEAD_RADII.x * c * (1.0 - 0.17 * jaw ** 1.6)
    y = HEAD_RADII.y * s
    # (long behind, and the jaw set a little forward)
    z = front * HEAD_RADII.z * c * (1.0 + (0.14 * max(s, -0.2) + 0.1 if front < 0.0 else 0.0)) + 0.008 * jaw
    p = Vector((x, y, z))
    out = Vector((x / HEAD_RADII.x ** 2, y / HEAD_RADII.y ** 2, z / HEAD_RADII.z ** 2)).normalized()
    facing = blend(0.05, 0.5, front * c)
    ax = abs(x)

    def bump(u, v, cu, cv, su, sv):
        return math.exp(-((u - cu) / su) ** 2 - ((v - cv) / sv) ** 2)

    d = 0.0
    # The brow: a ridge across, heaviest over each eye
    d += 0.0125 * math.exp(-((y - 0.024) / 0.0085) ** 2) * blend(0.058, 0.034, ax) * (0.7 + 0.3 * bump(ax, 0.0, 0.026, 0.0, 0.016, 1.0))
    # The hollows of the eyes
    d -= 0.021 * bump(ax, y, 0.0235, 0.004, 0.0125, 0.0095)
    # The bridge of the nose, which stops short: below it the nose has fallen in
    d += 0.012 * math.exp(-(x / 0.0075) ** 2) * blend(-0.014, -0.004, y) * blend(0.034, 0.016, y)
    d -= 0.005 * bump(x, y, 0.0, -0.023, 0.0095, 0.0085)
    # Cheekbones, and the cheeks sunk in under them
    d += 0.0095 * bump(ax, y, 0.041, -0.014, 0.014, 0.0095)
    d -= 0.014 * bump(ax, y, 0.033, -0.044, 0.016, 0.019)
    # The chin (and nothing where a mouth would be)
    d += 0.006 * bump(x, y, 0.0, -0.074, 0.017, 0.011)
    d *= facing
    # The temples, fallen in
    d -= 0.006 * bump(z, y, 0.028, 0.026, 0.022, 0.018) * blend(0.5, 0.9, abs(math.sin(angle)) * c)
    return HEAD_CENTRE + p + out * d


def head(b):
    """The skull, its face shaped into the surface, and the turns of bandage that cross it."""
    global HEAD_SURFACE
    # It is wound from the chin to the crown, each turn lapping the one below,
    # and the turns lie over the face as cloth does: down into its hollows. So
    # the surface is built in rows that follow the winding (which is not quite
    # level), a few to each turn, and each turn is thickest at its lower edge.
    segments, turns, per = (12, 5, 2) if kit.LOW else (64, 11, 5)
    wound = Matrix.Rotation(0.17, 3, "Z") @ Matrix.Rotation(-0.1, 3, "X")

    def wrapped(t, phi, lap):
        g = wound @ Vector((math.sin(t) * math.cos(phi), math.sin(phi), math.cos(t) * math.cos(phi)))
        p = skull_point(math.atan2(g.x, g.z), math.asin(min(max(g.y, -1.0), 1.0)))
        return p + (p - HEAD_CENTRE).normalized() * lap

    grid = []
    for turn_index in range(turns):
        low = -math.pi / 2 + math.pi * turn_index / turns
        lap = 0.0 if kit.LOW else 0.0024 + 0.0009 * math.sin(turn_index * 2.4)
        for m in range(per):
            share = m / (per - 1)
            phi = low + math.pi / turns * (0.03 + 0.96 * share)
            row = []
            for j in range(segments):
                t = math.tau * j / segments - math.pi
                # (points crowd towards the front, where the face is)
                row.append(b._vert(wrapped(t - (0.0 if kit.LOW else 0.5) * math.sin(t), phi, lap * (1.0 - share)), None))
            grid.append(row)
    faces = []
    for lower, upper in zip(grid, grid[1:]):
        for j in range(segments):
            n = (j + 1) % segments
            faces.append(b.bm.faces.new((lower[j], lower[n], upper[n], upper[j])))
    for row, phi in ((grid[0], -math.pi / 2), (grid[-1], math.pi / 2)):
        pole = b._vert(wrapped(0.0, phi, 0.0), None)
        for j in range(segments):
            faces.append(b.bm.faces.new((row[j], row[(j + 1) % segments], pole)))
    bmesh.ops.recalc_face_normals(b.bm, faces=faces)
    # (the loose turns are laid on the head as it is without those laps, or they would catch on every edge)
    plain = bmesh.new()
    rows = [[plain.verts.new(kit.to_blender(wrapped(math.tau * j / 32, -math.pi / 2 + math.pi * k / 25, 0.0))) for j in range(32)] for k in range(1, 25)]
    for lower, upper in zip(rows, rows[1:]):
        for j in range(32):
            plain.faces.new((lower[j], lower[(j + 1) % 32], upper[(j + 1) % 32], upper[j]))
    plain.normal_update()
    HEAD_SURFACE = BVHTree.FromBMesh(plain)
    plain.free()

    stand = Vector((HEAD_RADII.x * 1.5, 0.0, HEAD_RADII.z * 1.5))
    turn = Matrix.Rotation
    # Over those, a few turns that go their own way, kept clear of the face:
    # round the forehead above the brow, aslant over the crown...
    ribbon(b, HEAD_SURFACE, winding(HEAD_CENTRE, stand, 0.054, turn(-0.1, 3, "Z") @ turn(-0.16, 3, "X"), 2.4), [0.024] * 29, 0.006, 60, 3)
    ribbon(b, HEAD_SURFACE, winding(HEAD_CENTRE, stand * 0.8, 0.07, turn(0.3, 3, "Z") @ turn(-0.42, 3, "X"), 1.0), [0.024] * 29, 0.0065, 48, 3)
    # ...and under the chin and up over the top of the head, behind the cheekbones.
    strap = turn(0.1, 3, "Y") @ turn(math.pi / 2 - 0.12, 3, "X")
    ribbon(b, HEAD_SURFACE, winding(HEAD_CENTRE + Vector((0.0, 0.0, -0.006)), Vector((HEAD_RADII.x * 1.5, 0.0, HEAD_RADII.y * 1.5)), 0.0, strap, 0.5), [0.024] * 29, 0.007, 60, 3)


# --- What hangs loose ---

def hung(root, lengths, drift=(0.0, 0.0)):
    """The joints of a strip hanging from `root`: straight down, or drifting a little as it goes."""
    joints = [Vector(root)]
    for length in lengths:
        joints.append(joints[-1] + Vector((drift[0], -1.0, drift[1])).normalized() * length)
    return joints


def drapes():
    """Each loose end: (name, the bone it hangs from, its joints from root to tip,
    half width, which way is out from the body there, material)."""
    listed = []
    for side, suffix in ((1.0, "_l"), (-1.0, "_r")):
        out = arm_out(side)
        shoulder = shoulder_of(side)
        left = side > 0.0
        # From the wrist, from behind the elbow, and from the back of the shoulder
        wrist = out(shoulder + Vector((side * 0.012, -UPPER_ARM - FOREARM + 0.05, -0.012)))
        listed.append(("wrist" + suffix, "forearm" + suffix, hung(wrist, (0.12, 0.12, 0.11) if left else (0.09, 0.09, 0.08)), 0.024, Vector((side, 0.0, -0.3)), OLD_LINEN if left else LINEN))
        elbow = out(shoulder + Vector((side * 0.006, -UPPER_ARM + 0.03, -0.022)))
        listed.append(("elbow" + suffix, "upper_arm" + suffix, hung(elbow, (0.09, 0.085) if left else (0.12, 0.115)), 0.021, Vector((side * 0.4, 0.0, -1.0)), LINEN if left else OLD_LINEN))
        back = Vector((side * 0.088, 1.115, -0.052))
        listed.append(("shoulder" + suffix, "chest", hung(back, (0.12, 0.115, 0.11) if left else (0.1, 0.09), (0.0, -0.12)), 0.027, Vector((side * 0.3, 0.0, -1.0)), OLD_LINEN))
    # Round the waist: the ragged ends of what was wound there
    for name, angle, lengths, width, material in (("waist_f", 0.5, (0.13, 0.13, 0.12), 0.036, OLD_LINEN), ("waist_r", -1.75, (0.12, 0.11), 0.032, LINEN),
                                                  ("waist_b", 3.0, (0.14, 0.14, 0.13), 0.038, LINEN), ("waist_l", 1.9, (0.1, 0.095), 0.028, OLD_LINEN)):
        away = Vector((math.sin(angle), 0.0, math.cos(angle)))
        root = Vector((away.x * 0.086, 0.69, away.z * 0.068))
        listed.append((name, "hips", hung(root, lengths, (away.x * 0.08, away.z * 0.08)), width, away, material))
    # And one come loose from the right shin, long enough to trail on the ground behind it
    shin = Vector((-HIP_X - 0.004, 0.2, -0.024))
    listed.append(("shin_r", "shin_r", [shin, shin + Vector((0.0, -0.1, -0.03)), shin + Vector((0.0, -0.188, -0.09)), shin + Vector((0.0, -0.19, -0.23))], 0.022, Vector((0.0, 0.0, -1.0)), OLD_LINEN))
    return listed


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
    def shapes(b):
        lengths = [0.0]
        for a, c in zip(joints, joints[1:]):
            lengths.append(lengths[-1] + (c - a).length)
        total = lengths[-1]
        count = max(int(total / (0.045 if kit.LOW else 0.016)), 3)
        rings = []
        for k in range(count + 1):
            s = total * k / count
            i = max(j for j in range(len(joints) - 1) if lengths[j] <= s + 1e-9)
            direction = (joints[i + 1] - joints[i]).normalized()
            at = joints[i] + direction * (s - lengths[i])
            flat = (out - direction * out.dot(direction)).normalized()
            across = flat.cross(direction).normalized()
            share = s / total
            # It frays as it goes: narrower, and not straight
            wide = width * (1.0 - 0.3 * share) * (0.82 + 0.18 * math.sin(s * 70.0 + seed * 2.1))
            if k == count:
                wide *= 0.35
            at = at + across * 0.004 * math.sin(s * 33.0 + seed) * share
            rings.append((at, flat * 0.0022, across * wide))
        # (it starts wound round whatever it hangs from)
        first = rings[0]
        rings.insert(0, (first[0] - (joints[1] - joints[0]).normalized() * 0.012 - first[1].normalized() * 0.006, first[1], first[2] * 0.8))
        b.tube(rings, 6)
    return shapes


DRAPES = drapes()
DRAPE_JOINTS = {"drape_" + name: joints for name, _parent, joints, _width, _out, _material in DRAPES}


# --- Bones and weights ---

def weights(part, p):
    suffix = "_l" if p.x >= 0.0 else "_r"
    side = 1.0 if p.x >= 0.0 else -1.0
    if part in DRAPE_JOINTS:
        # Each link of the chain carries its own length of the strip, shared across the joint.
        joints = DRAPE_JOINTS[part]
        s = along_drape(joints, p)
        result = {}
        travelled = 0.0
        shares = []
        for a, c in zip(joints, joints[1:]):
            shares.append(blend(travelled - 0.018, travelled + 0.018, s) if travelled > 0.0 else 1.0)
            travelled += (c - a).length
        for k, share in enumerate(shares):
            result["%s_%d" % (part, k)] = share - (shares[k + 1] if k + 1 < len(shares) else 0.0)
        return result
    if part == "head":
        return {"head": 1.0}
    if part == "feet":
        shin = blend(0.062, 0.1, p.y) * blend(0.03, 0.0, p.z)
        toe = blend(TOE.z - 0.022, TOE.z + 0.022, p.z)
        return {"shin" + suffix: shin, "foot" + suffix: (1.0 - shin) * (1.0 - toe), "toe" + suffix: (1.0 - shin) * toe}
    if part == "legs":
        leg = blend(HIP_Y + 0.045, HIP_Y - 0.05, p.y)
        shin = blend(KNEE_Y + 0.04, KNEE_Y - 0.04, p.y)
        foot = blend(0.085, 0.05, p.y)
        return {"hips": 1.0 - leg, "thigh" + suffix: leg * (1.0 - shin), "shin" + suffix: leg * shin * (1.0 - foot), "foot" + suffix: leg * shin * foot}
    if part in ("arms", "hands"):
        down = SHOULDER.y - arm_in(side, p).y
        fore = blend(UPPER_ARM - 0.04, UPPER_ARM + 0.04, down)
        hand = blend(UPPER_ARM + FOREARM - 0.022, UPPER_ARM + FOREARM + 0.012, down)
        return {"upper_arm" + suffix: 1.0 - fore, "forearm" + suffix: fore * (1.0 - hand), "hand" + suffix: fore * hand}
    if part == "fingers":
        # Back on the hanging arm, find the finger this point is on and how far along it.
        q = arm_in(side, p)
        lines = [("finger%d" % index, finger_line(side, index), FINGERS[index][1], KNUCKLES) for index in range(len(FINGERS))]
        lines.append(("thumb", thumb_line(side), THUMB_LENGTH, (0.0, 0.5)))
        best = None
        for name, (root, along), length, joints in lines:
            t = (q - root).dot(along)
            away = (q - root - along * min(max(t, 0.0), length)).length
            if best is None or away < best[0]:
                best = (away, name, t / length, joints, length)
        _away, name, t, joints, length = best
        soft = 0.005 / length
        shares = [blend(joint - soft, joint + soft, t) for joint in joints]
        result = {"hand" + suffix: 1.0 - shares[0]}
        for k, letter in enumerate("abc"[:len(joints)]):
            result[name + letter + suffix] = shares[k] - (shares[k + 1] if k + 1 < len(shares) else 0.0)
        return result

    # The torso and what is wound on it: decided by height alone.
    low = blend(0.80, 0.70, p.y)
    high = blend(0.88, 1.0, p.y)
    neck = blend(1.12, 1.165, p.y) if abs(p.x) < 0.07 else 0.0
    skull = blend(1.215, 1.265, p.y) if abs(p.x) < 0.07 else 0.0
    return {
        "hips": low,
        "spine": (1.0 - low) * (1.0 - high),
        "chest": (1.0 - low) * high * (1.0 - neck),
        "neck": neck * (1.0 - skull),
        "head": neck * skull,
    }


def bones():
    listed = [("hips", HIPS, None), ("spine", SPINE, "hips"), ("chest", CHEST, "spine"), ("neck", NECK, "chest"), ("head", HEAD, "neck")]
    for side, suffix in ((1.0, "_l"), (-1.0, "_r")):
        shoulder = shoulder_of(side)
        out = arm_out(side)
        listed.append(("upper_arm" + suffix, shoulder, "chest"))
        listed.append(("forearm" + suffix, out(shoulder - Y * UPPER_ARM), "upper_arm" + suffix))
        listed.append(("hand" + suffix, out(shoulder - Y * (UPPER_ARM + FOREARM)), "forearm" + suffix))
        for index in range(len(FINGERS)):
            knuckle, along = finger_line(side, index)
            parent = "hand" + suffix
            for letter, share in zip("abc", KNUCKLES):
                listed.append(("finger%d%s%s" % (index, letter, suffix), out(knuckle + along * FINGERS[index][1] * share), parent))
                parent = listed[-1][0]
        root, along = thumb_line(side)
        listed.append(("thumba" + suffix, out(root), "hand" + suffix))
        listed.append(("thumbb" + suffix, out(root + along * THUMB_LENGTH * 0.5), "thumba" + suffix))
        # Leg bones are siblings: the rig places each one directly with IK.
        hip = Vector((side * HIP_X, HIP_Y, 0.0))
        listed.append(("thigh" + suffix, hip, "hips"))
        listed.append(("shin" + suffix, hip - Y * THIGH, "hips"))
        listed.append(("foot" + suffix, hip - Y * (THIGH + SHIN), "hips"))
        listed.append(("toe" + suffix, hip - Y * (THIGH + SHIN) + TOE, "foot" + suffix))
    # A chain down each loose end. The last bone of each carries nothing: it marks the tip.
    for name, parent, joints, _width, _out, _material in DRAPES:
        for k, joint in enumerate(joints):
            listed.append(("drape_%s_%d" % (name, k), joint, parent))
            parent = listed[-1][0]
    return listed


# (part, material, shapes, how to fuse them). The torso and the head come before what is laid on them.
PARTS = [
    ("torso", LINEN, torso, None),
    ("sashes", OLD_LINEN, sashes, None),
    ("legs", LINEN, legs, (0.004, 3, 3600)),
    ("feet", LINEN, feet, (0.003, 3, 1400)),
    ("arms", LINEN, arms, (0.0035, 3, 4200)),
    ("hands", LINEN, hands, None),
    ("fingers", WITHERED, fingers, None),
    ("head", LINEN, head, None),
]
for index, (name, _parent, joints, width, out, material) in enumerate(DRAPES):
    PARTS.append(("drape_" + name, material, drape_shape(joints, width, out, index * 1.7), None))


def previews(folder, name):
    """More renders of the rest pose than the kit makes: all round it, and the face close to."""
    scene = bpy.context.scene
    camera = scene.camera
    middle = kit.to_blender(HEAD_CENTRE)
    views = [("front", (0, -1, 0.05), (0.0, 0.0, 0.7), 1.6), ("back", (0.25, 1, 0.15), (0.0, 0.0, 0.7), 1.6),
             ("face", (0, -1, 0.0), middle, 0.26), ("face_quarter", (0.7, -0.7, 0.1), middle, 0.26),
             ("face_side", (1, -0.05, 0.0), middle, 0.26), ("face_low", (0.3, -1, -0.5), middle, 0.26),
             ("mitt", (-0.3, -1, 0.2), kit.to_blender(arm_out(1.0)(hand_wrist(1.0) - Y * 0.08)), 0.3)]
    for view, direction, target, frame in views:
        offset = Vector(direction).normalized() * 4.0
        camera.data.ortho_scale = frame
        camera.location = Vector(target) + offset
        camera.rotation_euler = (-offset).to_track_quat("-Z", "Y").to_euler()
        scene.render.filepath = os.path.join(folder, "%s_%s.png" % (name, view))
        bpy.ops.render.render(write_still=True)


if __name__ == "__main__":
    kit.export("mummy", bones(), PARTS, weights, MATERIALS)
    if kit.PREVIEW_DIR:
        previews(kit.PREVIEW_DIR, "mummy")
    kit.LOW = True
    kit.export("mummy_lo", bones(), [(part, material, shapes, None) for part, material, shapes, _fuse in PARTS], weights, MATERIALS)
    if kit.PREVIEW_DIR:
        previews(kit.PREVIEW_DIR, "mummy_lo")
