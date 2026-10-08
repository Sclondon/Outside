"""Builds the boy and exports him for Godot.

Run from the project root:
    blender --background --python tools/build_boy.py

Writes models/boy.glb and models/boy_lo.glb, with editable copies in tools/.

He is modelled in a T-pose. His body (torso, arms to the wrist, legs to the
ankle, and neck) is ONE continuous surface: a stick figure of points, each
with a thickness, is skinned and then smoothed, so shoulders and hips are
real joins rather than parts pushed together. The hem of the jumper, the
rolled sleeves, the trouser cuffs and the collar are steps in that one
surface, where a thick point sits right beside a thin one. Head, hair, hands
and shoes are separate shapes joined on.

Everything is in Godot space (metres, Y up, facing +Z, +X his left). The rig
(scripts/character_rig.gd) reads his proportions from the bones, so nothing
here needs copying anywhere else.
"""

import math
import os
import sys

import bpy
from mathutils import Matrix, Vector

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import build_character as kit  # noqa: E402  (shared shape-building and export tools)

X, Y, Z = kit.X, kit.Y, kit.Z
blend = kit.blend

# --- Joints ---

ANKLE_Y = 0.05
THIGH = SHIN = 0.25
HIP_X = 0.072
HIP_Y = ANKLE_Y + THIGH + SHIN
HIPS = Vector((0.0, HIP_Y + 0.02, 0.0))
SPINE = Vector((0.0, 0.60, 0.0))
HEAD = Vector((0.0, 0.955, 0.0))
SHOULDER = Vector((0.135, 0.895, 0.0))
UPPER_ARM = 0.185
FOREARM = 0.165
ELBOW_X = SHOULDER.x + UPPER_ARM
WRIST_X = ELBOW_X + FOREARM
KNEE_Y = HIP_Y - THIGH
TOE = Vector((0.0, -0.035, 0.075))
HEAD_CENTRE = HEAD + Vector((0.0, 0.130, 0.006))
HEAD_RADII = Vector((0.103, 0.136, 0.113))

JUMPER, TROUSERS, SKIN, DARK, SOCKS = range(5)
MATERIALS = [
    ("jumper", (0.44, 0.12, 0.13)),
    ("trousers", (0.05, 0.05, 0.06)),
    ("skin", (0.76, 0.66, 0.56)),
    ("hair", (0.05, 0.045, 0.04)),
    ("socks", (0.86, 0.86, 0.83)),
]

# Where one garment ends and the next begins on the body.
HEM_Y = 0.602
COLLAR_Y = 0.952
SLEEVE_X = ELBOW_X + 0.046
SOCK_Y = 0.074


def body_graph():
    """The stick figure: points (position, thickness) and the lines joining them.

    A thick point right beside a thin one makes a step in the surface: that is
    how the hem, the sleeve rolls, the cuffs and the collar are made.
    """
    points = []
    lines = []

    def chain(start, steps):
        last = start
        for position, thickness in steps:
            points.append((Vector(position), thickness))
            if last is not None:
                lines.append((last, len(points) - 1))
            last = len(points) - 1
        return last

    # Up the middle: seat, the jumper's hem hanging over it, chest, collar, neck
    chain(None, [((0.0, 0.565, 0.0), 0.100)])
    hips = 0
    chain(hips, [((0.0, 0.598, 0.0), 0.099), ((0.0, 0.606, 0.0), 0.121), ((0.0, 0.64, 0.0), 0.119),
                 ((0.0, 0.72, 0.0), 0.112), ((0.0, 0.81, 0.0), 0.112)])
    chest = chain(len(points) - 1, [((0.0, 0.888, 0.0), 0.104)])
    chain(chest, [((0.0, 0.940, 0.0), 0.062), ((0.0, 0.950, 0.0), 0.058), ((0.0, 0.956, 0.0), 0.035), ((0.0, 1.01, 0.0), 0.034)])
    for side in (1.0, -1.0):
        # Arm: shoulder, elbow, the sleeve pushed up into a roll, bare forearm, wrist
        chain(chest, [((side * 0.118, 0.893, 0.0), 0.062), ((side * 0.175, 0.895, 0.0), 0.050),
                      ((side * 0.25, 0.895, 0.0), 0.045), ((side * ELBOW_X, 0.895, -0.004), 0.043),
                      ((side * (SLEEVE_X - 0.012), 0.895, -0.003), 0.049), ((side * (SLEEVE_X - 0.002), 0.895, -0.003), 0.048),
                      ((side * (SLEEVE_X + 0.006), 0.895, -0.003), 0.030), ((side * (ELBOW_X + 0.10), 0.895, -0.002), 0.026),
                      ((side * (WRIST_X - 0.012), 0.895, 0.0), 0.020)])
        # Leg: loose down the thigh and round the knee, gathered at the ankle, a sock
        chain(hips, [((side * HIP_X, 0.535, 0.0), 0.074), ((side * 0.076, 0.42, 0.003), 0.065),
                     ((side * 0.078, KNEE_Y, 0.008), 0.059), ((side * 0.08, 0.19, -0.004), 0.055),
                     ((side * 0.08, 0.11, -0.002), 0.047), ((side * 0.08, 0.084, 0.0), 0.037),
                     ((side * 0.08, 0.078, 0.0), 0.036), ((side * 0.08, 0.070, 0.0), 0.026), ((side * 0.08, 0.02, 0.0), 0.026)])
    return points, lines


def body(_builder):
    """Skins the stick figure into one surface, smooths it, and colours its regions."""
    points, lines = body_graph()
    mesh = bpy.data.meshes.new("body")
    mesh.from_pydata([kit.to_blender(position) for position, _ in points], lines, [])
    figure = bpy.data.objects.new("body", mesh)
    bpy.context.collection.objects.link(figure)
    skin = figure.modifiers.new("skin", "SKIN")
    skin.use_smooth_shade = True
    # Smoothing afterwards draws the surface in a little; start slightly thick.
    swell = 1.0 if kit.LOW else 1.12
    for index, (_, thickness) in enumerate(points):
        vertex = mesh.skin_vertices[0].data[index]
        vertex.radius = (thickness * swell, thickness * swell)
        vertex.use_root = index == 0
    smooth = figure.modifiers.new("smooth", "SUBSURF")
    smooth.levels = 1 if kit.LOW else 2
    bpy.context.view_layer.update()
    skinned = bpy.data.meshes.new_from_object(figure.evaluated_get(bpy.context.evaluated_depsgraph_get()))
    bpy.data.objects.remove(figure)

    for vertex in skinned.vertices:
        p = kit.from_blender(vertex.co)
        # A chest is wider than it is deep; arms and legs stay round.
        flatten = 0.82 + 0.18 * blend(0.12, 0.17, abs(p.x)) if p.y > 0.5 else 1.0
        vertex.co = kit.to_blender(Vector((p.x, p.y, p.z * flatten)))
    for face in skinned.polygons:
        p = kit.from_blender(face.center)
        if abs(p.x) > SLEEVE_X + 0.002 or (p.y > COLLAR_Y + 0.003 and abs(p.x) < 0.09):
            face.material_index = SKIN
        elif p.y < SOCK_Y:
            face.material_index = SOCKS
        elif p.y < HEM_Y and abs(p.x) < 0.2:
            face.material_index = TROUSERS
        else:
            face.material_index = JUMPER
    return skinned


def head(b):
    # An egg, narrowing to the chin. No face.
    rings = []
    for k in range(1, 14):
        phi = -math.pi / 2 + math.pi * k / 14
        c, s = math.cos(phi), math.sin(phi)
        jaw = max(0.0, -s)
        rings.append(kit.upright(0.0, HEAD_CENTRE.y + HEAD_RADII.y * s, HEAD_CENTRE.z + 0.012 * jaw,
                                 HEAD_RADII.x * c * (1.0 - 0.2 * jaw ** 1.5), HEAD_RADII.z * c))
    b.tube(rings, 24)
    for side in (1.0, -1.0):
        b.ellipsoid(HEAD_CENTRE + Vector((side * 0.099, -0.016, -0.012)), Vector((0.012, 0.027, 0.018)), None, 8, 5)


def on_head(angle, height, lift=0.0):
    """A point on the head's surface: `angle` round from the front, `height` above its middle."""
    across = math.sqrt(max(0.0, 1.0 - (height / HEAD_RADII.y) ** 2)) + lift
    return HEAD_CENTRE + Vector((math.sin(angle) * HEAD_RADII.x * across, height, math.cos(angle) * HEAD_RADII.z * across))


def lock(b, root, tip, width):
    """A lock of hair: a flat blade from `root` to a point at `tip`, lying against the head."""
    along = (tip - root).normalized()
    out = (root - HEAD_CENTRE).normalized()
    across = along.cross(out).normalized()
    b.tube([(root.lerp(tip, t), across * width * (1.0 - t) ** 0.8, out * 0.015 * (1.0 - t * 0.6)) for t in (0.0, 0.3, 0.6, 0.85, 0.98)], 8)


def hair(b):
    # A cap tilted back, so it sits high on the brow and comes right down to the
    # nape, covering the back of the head...
    tilt = Matrix.Rotation(-0.55, 3, "X")
    crown = HEAD_CENTRE + Vector((0.0, 0.010, -0.004))
    grown = HEAD_RADII + Vector((0.006, 0.008, 0.008))
    rim = -0.30

    def on_cap(angle, phi):
        c, s = math.cos(phi), math.sin(phi)
        return crown + tilt @ Vector((math.sin(angle) * grown.x * c, grown.y * s, math.cos(angle) * grown.z * c))

    cap = []
    for k in range(10):
        phi = rim + (math.pi / 2 - rim) * k / 10
        c, s = math.cos(phi), math.sin(phi)
        cap.append((crown + tilt @ (Y * grown.y * s), tilt @ (X * grown.x * c), tilt @ (Z * grown.z * c)))
    b.tube(cap, 24)
    if kit.LOW:
        return
    # ...with a ragged edge of locks hanging from its rim all the way round:
    # a fringe across the brow, each lock a different length and swept a little
    # to one side, and longer ones down the sides and the nape.
    count = 18
    for k in range(count):
        angle = math.tau * k / count + 0.09
        front = math.cos(angle) > 0.35
        root = on_cap(angle, rim + 0.34)
        length = (0.050 + 0.040 * math.sin(k * 2.4) ** 2) if front else (0.040 + 0.030 * math.sin(k * 1.7) ** 2)
        tip = on_head(angle + (0.14 if front else 0.07), root.y - HEAD_CENTRE.y - length, 0.075)
        lock(b, root, tip, 0.040)


def arm_out(side):
    """Moves a point modelled on an arm hanging at his side out to the T-pose."""
    shoulder = Vector((side * SHOULDER.x, SHOULDER.y, 0.0))
    turn = Matrix.Rotation(side * math.pi / 2, 3, "Z")
    return lambda p: shoulder + turn @ (p - shoulder)


def hands(b):
    for side in (1.0, -1.0):
        b.place = arm_out(side)
        wrist = Vector((side * SHOULDER.x, SHOULDER.y - UPPER_ARM - FOREARM, 0.003))
        inward = -side  # hanging, the palm faces the body; held out, it faces down
        palm = [(0.022, 0.015, 0.018), (0.0, 0.0135, 0.022), (-0.022, 0.0125, 0.029), (-0.045, 0.0115, 0.033), (-0.058, 0.0105, 0.032)]
        rings = [(wrist + Y * dy, X * rx, Z * rz) for dy, rx, rz in palm]
        b.tube(rings + kit.dome(rings[-1], -Y, 0.008, 2), 12)
        if kit.LOW:
            # Demade: the fingers are a single curled mitt
            mitt = [(-0.058, 0.0, 0.0105, 0.030), (-0.082, 0.006, 0.0095, 0.028), (-0.100, 0.016, 0.008, 0.022)]
            b.tube([(wrist + Vector((inward * x, dy, 0.0)), X * rx, Z * rz) for dy, x, rx, rz in mitt], 12)
        else:
            # Fingers, little (back) to index (front), loosely curled towards the palm
            for z, length, radius in ((-0.0245, 0.034, 0.0080), (-0.0082, 0.043, 0.0088), (0.0082, 0.046, 0.0090), (0.0245, 0.042, 0.0088)):
                point = wrist + Vector((0.0, -0.058, z))
                points = [point]
                for curl, share in ((0.12, 0.42), (0.45, 0.33), (0.85, 0.25)):
                    point = point + Vector((inward * math.sin(curl), -math.cos(curl), 0.0)) * (length * share)
                    points.append(point)
                b.strand(points, [radius, radius * 0.97, radius * 0.9, radius * 0.8])
        root = wrist + Vector((inward * 0.003, -0.012, 0.018))
        b.strand([root, root + Vector((inward * 0.004, -0.018, 0.016)), root + Vector((inward * 0.011, -0.036, 0.022)),
                  root + Vector((inward * 0.018, -0.050, 0.022))], [0.0115, 0.0108, 0.0096, 0.0084])
    b.place = None


def shoes(b):
    for side in (1.0, -1.0):
        ankle = Vector((side * 0.08, ANKLE_Y, 0.0))
        floor = 0.0

        def across(z, y, rx, ry, ankle=ankle):
            return (ankle + Vector((0.0, y, z)), X * rx, Y * ry)

        # Chunky: a heel cup, sides up round the ankle, a blunt toe, on a thick sole
        upper = [
            across(-0.044, -0.018, 0.034, 0.034), across(-0.020, -0.004, 0.041, 0.050), across(0.012, -0.010, 0.043, 0.044),
            across(0.044, -0.022, 0.046, 0.031), across(0.078, -0.028, 0.047, 0.025), across(0.110, -0.031, 0.045, 0.022),
            across(0.132, -0.033, 0.038, 0.018),
        ]
        b.tube(kit.dome(upper[0], -Z, 0.016, 3)[::-1] + upper + kit.dome(upper[-1], Z, 0.02, 3), 16, floor)
        b.tube([(Vector((ankle.x, y, 0.047)), X * 0.050, Z * 0.104) for y in (floor, floor + 0.008, floor + 0.016)], 24)
    for vertex in b.bm.verts:
        vertex.co.z = max(vertex.co.z, 0.0)


def weights(part, p):
    suffix = "_l" if p.x >= 0.0 else "_r"
    if part in ("head", "hair"):
        return {"head": 1.0}
    if part == "hands":
        return {"hand" + suffix: 1.0}
    if part == "shoes":
        toe = blend(TOE.z - 0.015, TOE.z + 0.015, p.z)
        return {"foot" + suffix: 1.0 - toe, "toe" + suffix: toe}

    # The body: everything is decided by where the point sits in the T-pose.
    reach = abs(p.x)
    arm = blend(0.115, 0.19, reach) if p.y > 0.75 else 0.0
    fore = blend(ELBOW_X - 0.035, ELBOW_X + 0.035, reach)
    leg = blend(0.585, 0.50, p.y)
    left = blend(-0.012, 0.012, p.x)
    shin = blend(KNEE_Y + 0.04, KNEE_Y - 0.04, p.y)
    foot = blend(0.09, 0.055, p.y)
    low = blend(0.68, 0.57, p.y)
    neck = blend(0.948, 0.992, p.y) if reach < 0.09 else 0.0
    trunk = (1.0 - arm) * (1.0 - leg)
    result = {
        "hips": trunk * low,
        "spine": trunk * (1.0 - low) * (1.0 - neck),
        "head": trunk * (1.0 - low) * neck,
        "upper_arm" + suffix: arm * (1.0 - fore),
        "forearm" + suffix: arm * fore,
    }
    for name, share in (("_l", left), ("_r", 1.0 - left)):
        result["thigh" + name] = leg * share * (1.0 - shin)
        result["shin" + name] = leg * share * shin * (1.0 - foot)
        result["foot" + name] = leg * share * shin * foot
    return result


def bones():
    listed = [("hips", HIPS, None), ("spine", SPINE, "hips"), ("head", HEAD, "spine")]
    for side, suffix in ((1.0, "_l"), (-1.0, "_r")):
        shoulder = Vector((side * SHOULDER.x, SHOULDER.y, 0.0))
        listed.append(("upper_arm" + suffix, shoulder, "spine"))
        listed.append(("forearm" + suffix, shoulder + X * side * UPPER_ARM, "upper_arm" + suffix))
        listed.append(("hand" + suffix, shoulder + X * side * (UPPER_ARM + FOREARM), "forearm" + suffix))
        # Leg bones are siblings: the rig places each one directly with IK.
        hip = Vector((side * HIP_X, HIP_Y, 0.0))
        listed.append(("thigh" + suffix, hip, "hips"))
        listed.append(("shin" + suffix, hip - Y * THIGH, "hips"))
        listed.append(("foot" + suffix, hip - Y * (THIGH + SHIN), "hips"))
        listed.append(("toe" + suffix, hip - Y * (THIGH + SHIN) + TOE, "foot" + suffix))
    return listed


# (part, material or None if the part colours itself, shapes, how to fuse them)
PARTS = [
    ("body", None, body, None),
    ("head", SKIN, head, (0.004, 4, 2000)),
    ("hair", DARK, hair, (0.004, 2, 2200)),
    ("hands", SKIN, hands, (0.0016, 2, 2400)),
    ("shoes", DARK, shoes, (0.003, 3, 2400)),
]

kit.export("boy", bones(), PARTS, weights, MATERIALS)
kit.LOW = True
kit.export("boy_lo", bones(), [(part, material, shapes, None) for part, material, shapes, _fuse in PARTS], weights, MATERIALS)
