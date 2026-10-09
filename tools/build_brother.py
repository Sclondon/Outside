"""Builds the boy's older brother and exports him for Godot.

Run from the project root:
    blender --background --python tools/build_brother.py
    blender --background --python tools/build_brother.py -- <folder>   # also renders previews there

Writes models/brother.glb and models/brother_lo.glb, with editable copies in tools/.

He is sixteen or seventeen to the boy's ten, and made by the same hand: this
script builds nothing from scratch. It takes tools/build_boy.py, gives it other
measurements and another stick figure to skin (see `body_graph`), and reuses its
head, hair, cap, hands, fingers and boots as they are. So he is the same
construction: one continuous body with his clothes as steps in it, straps laid
on its surface, and the same curls under the same sort of cap.

How he differs. He is longer in the leg and arm, broader in the shoulder and
narrower in the body, with a neck, and a head that is small for him where the
boy's is big. He has left off overalls for long trousers with a turn-up, held up
by braces over a collarless shirt with the sleeves rolled to the elbow, a
knotted neckerchief, and heavier boots. His hair is cut short behind where the
boy's is left long, and his cap is pushed back off his forehead.

Like every figure he is modelled about as tall as the boy (1.25 m) and brought
to his height in Godot: scripts/brother.gd stands him at 1.25 times that.

Everything is in Godot space (metres, Y up, facing +Z, +X his left).
"""

import math
import os
import sys

import bpy
from mathutils import Vector

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import build_character as kit  # noqa: E402  (shared shape-building and export tools)
import build_boy as boy  # noqa: E402  (the shapes he is made of; it does not build the boy when imported)

X, Y, Z = kit.X, kit.Y, kit.Z
blend = kit.blend

NAME = "brother"

# --- Joints. Set on build_boy, whose shapes and bones are all worked out from them. ---

boy.THIGH = boy.SHIN = 0.30
boy.HIP_X = 0.07
boy.HIP_Y = boy.ANKLE_Y + boy.THIGH + boy.SHIN
boy.KNEE_Y = boy.HIP_Y - boy.THIGH
boy.HIPS = Vector((0.0, boy.HIP_Y + 0.02, 0.0))
boy.SPINE = Vector((0.0, 0.735, 0.0))
boy.CHEST = Vector((0.0, 0.84, 0.0))
boy.NECK = Vector((0.0, 0.97, 0.0))
boy.HEAD = Vector((0.0, 1.045, 0.0))
boy.SHOULDER = Vector((0.15, 0.915, 0.0))
boy.UPPER_ARM = 0.21
boy.FOREARM = 0.19
boy.ELBOW_X = boy.SHOULDER.x + boy.UPPER_ARM
boy.WRIST_X = boy.ELBOW_X + boy.FOREARM
boy.TOE = Vector((0.0, -0.035, 0.082))
# His head is built the size of the boy's, about this point, and then brought
# down to his own (see `shrunk`): it is the boy's head, hair and cap, smaller on him.
boy.HEAD_CENTRE = Vector((0.0, 1.129, 0.006))
HEAD_SCALE = Vector((0.83, 0.87, 0.85))

# Where one garment ends and the next begins on the body.
boy.WAIST_Y = 0.756
boy.BAND_Y = -1.0  # (no socks to be seen: his trousers come down over his boots)
boy.COLLAR_Y = 0.973
boy.NECK_RADIUS = 0.036
boy.SLEEVE_X = boy.ELBOW_X + 0.05
boy.FLAT = (0.13, 0.19, 0.55, 0.70)
# More forearm shows below his sleeve than below the boy's.
boy.FOREARM_SHAPE = [(0.168, 0.0262, 0.0268), (0.125, 0.0270, 0.0277), (0.085, 0.0246, 0.0262), (0.048, 0.0200, 0.0235),
                     (0.018, 0.0160, 0.0214)] + boy.FOREARM_SHAPE[5:]

# His cap is pushed back, and his hair is cut: short behind, nothing left over his collar.
boy.CAP_TILT = -0.24
boy.HAIR_ROWS = ((0.97, 17, 0.028), (0.66, 17, 0.028), (0.36, 16, 0.025), (0.06, 14, 0.021))
boy.MULLET = 0.0
boy.NAPE = ()
# (what the cap, pushed back, leaves to be seen over his forehead: shares over 1 root a curl as high as the cap lets it)
boy.FORELOCK = ((-0.66, 0.6, 0.036), (-0.40, 1.6, 0.040), (-0.14, 2.2, 0.040), (0.14, 2.4, 0.036), (0.42, 1.8, 0.034), (-0.90, 0.5, 0.034),
                (0.70, 0.9, 0.032), (-0.25, 0.7, 0.036), (0.05, 0.9, 0.034), (0.30, 0.6, 0.032), (-0.52, 2.4, 0.034), (0.60, 2.6, 0.030))

SHIRT, TROUSERS, SKIN, HAIR, SOCKS, LEATHER, BUTTON, KERCHIEF, TWEED, BRACES = range(10)
# (the first nine in build_boy's order, since its body colours itself by number)
MATERIALS = [
    ("shirt", (0.90, 0.88, 0.80)),
    ("trousers", (0.33, 0.27, 0.22)),
    ("skin", (0.82, 0.66, 0.55)),
    ("hair", (0.23, 0.165, 0.12)),
    ("socks", (0.60, 0.56, 0.50)),
    ("boots", (0.17, 0.11, 0.075)),
    ("buttons", (0.20, 0.16, 0.13)),
    ("kerchief", (0.62, 0.20, 0.16)),
    ("cap", (0.37, 0.32, 0.26)),
    ("braces", (0.56, 0.40, 0.25)),
]

ANKLE_X = 0.078


def body_graph():
    """His stick figure, in place of the boy's: points (position, thickness) and the lines joining them."""
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

    # Up the middle: narrow hips, trousers worn high, the shirt tucked into them,
    # a chest that widens to the shoulder, a neckband and no collar, and a neck
    chain(None, [((0.0, 0.665, 0.0), 0.093)])
    hips = 0
    chain(hips, [((0.0, 0.71, 0.0), 0.093), ((0.0, 0.742, 0.0), 0.090), ((0.0, 0.754, 0.0), 0.089),
                 ((0.0, 0.763, 0.0), 0.081), ((0.0, 0.80, 0.0), 0.084), ((0.0, 0.86, 0.0), 0.094)])
    chest = chain(len(points) - 1, [((0.0, 0.908, 0.0), 0.092)])
    chain(chest, [((0.0, 0.953, 0.0), 0.058), ((0.0, 0.966, 0.0), 0.048), ((0.0, 0.974, 0.0), 0.0415),
                  ((0.0, 0.982, 0.0), boy.NECK_RADIUS), ((0.0, 1.02, 0.0), boy.NECK_RADIUS - 0.002), ((0.0, 1.079, 0.0), boy.NECK_RADIUS - 0.002)])
    elbow, sleeve = boy.ELBOW_X, boy.SLEEVE_X
    for side in (1.0, -1.0):
        # Arm: a sleeve turned back in one thick even roll below the elbow
        chain(chest, [((side * 0.128, 0.913, 0.0), 0.058), ((side * 0.19, 0.915, 0.0), 0.046),
                      ((side * 0.27, 0.913, 0.0), 0.041), ((side * elbow, 0.914, -0.004), 0.039),
                      ((side * (sleeve - 0.024), 0.915, -0.003), 0.038), ((side * (sleeve - 0.014), 0.915, -0.003), 0.047),
                      ((side * (sleeve - 0.002), 0.915, -0.003), 0.049), ((side * (sleeve + 0.010), 0.915, -0.003), 0.047),
                      ((side * (sleeve + 0.018), 0.915, -0.003), 0.031)])
        # Leg: long trousers, straight from the knee, with a turn-up that sits on
        # the boot; what is below that is inside the boot
        chain(hips, [((side * boy.HIP_X, 0.635, 0.0), 0.071), ((side * 0.073, 0.53, 0.002), 0.062),
                     ((side * 0.075, 0.42, 0.004), 0.054), ((side * 0.076, 0.35, 0.006), 0.050),
                     ((side * ANKLE_X, 0.25, 0.003), 0.047), ((side * ANKLE_X, 0.15, 0.0), 0.045),
                     ((side * ANKLE_X, 0.104, 0.0), 0.045), ((side * ANKLE_X, 0.094, 0.0), 0.055),
                     ((side * ANKLE_X, 0.068, 0.0), 0.055), ((side * ANKLE_X, 0.060, 0.0), 0.034),
                     ((side * ANKLE_X, 0.035, 0.0), 0.028)])
    return points, lines


boy.body_graph = body_graph


def braces(b):
    """Over each shoulder from the front of his waistband, and crossed behind."""
    out = 0.105
    top = boy.WAIST_Y - 0.016
    for side in (1.0, -1.0):
        # (over the middle of the shoulder, clear of his neckband and neckerchief)
        boy.ribbon(b, [(side * 0.054, top, out), (side * 0.066, 0.87, 0.10), (side * 0.098, 0.955, 0.07), (side * 0.110, 1.01, 0.0),
                       (side * 0.098, 0.955, -0.08), (side * 0.066, 0.885, -out), (side * 0.028, 0.83, -out), (-side * 0.018, 0.785, -out), (-side * 0.05, top, -out)],
                   [0.027] * 9, 0.0085 if side > 0.0 else 0.006, 32, 3)


def kerchief(b):
    """A neckerchief: a soft roll of cloth round the base of his neck, knotted in front with two ends hanging."""
    # (the roll is a ring lying on his shoulders, a little lower in front, its two ends under the knot)
    rings = []
    count = 20
    for k in range(count + 1):
        angle = 0.1 + (math.tau - 0.2) * k / count
        out = Vector((math.sin(angle), 0.0, math.cos(angle)))
        centre = Vector((out.x * 0.054, 0.974 - 0.008 * math.cos(angle), out.z * 0.047))
        rings.append((centre, out * 0.016, Y * 0.013))
    b.tube(rings, 8)
    knot, facing = boy.onto_body(Vector((0.0, 0.952, 0.09)))
    b.ellipsoid(knot + facing * 0.012, Vector((0.019, 0.015, 0.013)), None, 10, 5)
    for side, drop in ((1.0, 0.070), (-1.0, 0.058)):
        boy.ribbon(b, [(side * 0.006, 0.948, 0.1), (side * 0.020, 0.948 - drop * 0.5, 0.11), (side * 0.036, 0.948 - drop, 0.11)],
                   [0.020, 0.030, 0.034], 0.0125 if side > 0.0 else 0.009, 6, 3)


def buttons(b):
    out = 0.105
    spots = [((0.0, y, out), 0.0035, 0.006) for y in (0.795, 0.845, 0.895)]  # down the front of his shirt
    for side in (1.0, -1.0):
        spots.append(((side * 0.054, boy.WAIST_Y - 0.012, out), 0.0105, 0.008))
        spots.append(((-side * 0.05, boy.WAIST_Y - 0.012, -out), 0.0095, 0.008))
    for point, lift, size in spots:
        at, facing = boy.onto_body(Vector(point))
        b.ellipsoid(at + facing * lift, Vector((size, size, size * 0.55)), None, 8, 3)


def shrunk(shapes):
    """Something built on the boy's head, brought down to the size of his."""
    def made(b):
        shapes(b)
        centre = boy.HEAD_CENTRE
        for vertex in b.bm.verts:
            p = kit.from_blender(vertex.co) - centre
            vertex.co = kit.to_blender(centre + Vector((p.x * HEAD_SCALE.x, p.y * HEAD_SCALE.y, p.z * HEAD_SCALE.z)))
    return made


def on_his_head(p):
    centre = boy.HEAD_CENTRE
    return centre + Vector(((p.x - centre.x) * HEAD_SCALE.x, (p.y - centre.y) * HEAD_SCALE.y, (p.z - centre.z) * HEAD_SCALE.z))


def off_his_head(p):
    centre = boy.HEAD_CENTRE
    return centre + Vector(((p.x - centre.x) / HEAD_SCALE.x, (p.y - centre.y) / HEAD_SCALE.y, (p.z - centre.z) / HEAD_SCALE.z))


BOOT_SCALE = Vector((1.14, 1.12, 1.10))


def boots(b):
    """The boy's boots, a size or two up and heavier in the sole, under his trousers."""
    boy.boots(b)
    for vertex in b.bm.verts:
        p = kit.from_blender(vertex.co)
        side = 1.0 if p.x >= 0.0 else -1.0
        # (the top of the boot is drawn in, so that it stays inside the trouser leg)
        inside = 1.0 - 0.32 * blend(0.055, 0.085, p.y)
        vertex.co = kit.to_blender(Vector((side * ANKLE_X + (p.x - side * 0.08) * BOOT_SCALE.x * inside, p.y * BOOT_SCALE.y, p.z * BOOT_SCALE.z * inside)))


def weights(part, p):
    if part == "hair":
        return boy.weights(part, off_his_head(p))
    if part in ("head", "crown", "cap", "hands", "fingers"):
        return boy.weights(part, p)
    suffix = "_l" if p.x >= 0.0 else "_r"
    if part == "boots":
        # The top of the boot goes with the shin, as the trouser leg over it does.
        shin = 1.0 - blend(0.115, 0.065, p.y)
        toe = blend(boy.TOE.z - 0.024, boy.TOE.z + 0.024, p.z) * (1.0 - shin)
        return {"shin" + suffix: shin, "foot" + suffix: 1.0 - shin - toe, "toe" + suffix: toe}

    # The body, and what is laid on it. As the boy's are, but to his measure: every
    # line between two bones is drawn at the joint between them.
    reach = abs(p.x)
    shoulder, hip_y, knee_y = boy.SHOULDER, boy.HIP_Y, boy.KNEE_Y
    arm = blend(shoulder.x - 0.022, shoulder.x + 0.055, reach) if p.y > shoulder.y - 0.145 else 0.0
    fore = blend(boy.ELBOW_X - 0.035, boy.ELBOW_X + 0.035, reach)
    # (his seat stays with his hips, as the boy's does: see `weights` in build_boy)
    behind = boy.seat_share(p)
    leg = blend(hip_y + 0.035 - boy.SEAT[0] * behind, hip_y - 0.05 - boy.SEAT[1] * behind, p.y)
    left = blend(-0.012, 0.012, p.x)
    shin = blend(knee_y + 0.045, knee_y - 0.045, p.y)
    low = blend(boy.SPINE.y + 0.05, boy.SPINE.y - 0.05, p.y)
    high = blend(boy.CHEST.y - 0.055, boy.CHEST.y + 0.055, p.y)
    central = reach < 0.09
    neck = blend(boy.NECK.y - 0.02, boy.NECK.y + 0.02, p.y) if central else 0.0
    skull = blend(boy.HEAD.y - 0.022, boy.HEAD.y + 0.023, p.y) if central else 0.0
    trunk = (1.0 - arm) * (1.0 - leg)
    result = {
        "hips": trunk * low,
        "spine": trunk * (1.0 - low) * (1.0 - high),
        "chest": trunk * (1.0 - low) * high * (1.0 - neck),
        "neck": trunk * (1.0 - low) * high * neck * (1.0 - skull),
        "head": trunk * (1.0 - low) * high * neck * skull,
        "upper_arm" + suffix: arm * (1.0 - fore),
        "forearm" + suffix: arm * fore,
    }
    # (his trousers hang from the shin right down to the turn-up; the foot moves inside them)
    for name, share in (("_l", left), ("_r", 1.0 - left)):
        result["thigh" + name] = leg * share * (1.0 - shin)
        result["shin" + name] = leg * share * shin
    return result


def bones():
    """The boy's bones, at his joints; those on his head come in with it."""
    return [(name, on_his_head(at) if name == "cap" or name.startswith("hair_") else at, parent) for name, at, parent in boy.bones()]


def more_previews(name):
    """Further views than the kit renders for a figure it does not know."""
    if not kit.PREVIEW_DIR:
        return
    scene = bpy.context.scene
    camera = scene.camera
    for view, direction, target, frame in (("front", (0, -1, 0.05), (0.0, 0.0, 0.67), 1.5), ("back", (0.25, 1, 0.15), (0.0, 0.0, 0.67), 1.5),
                                           ("head", (0.6, -0.8, 0.15), (0.0, 0.0, 1.12), 0.5), ("headback", (-0.5, 0.85, 0.2), (0.0, 0.0, 1.12), 0.5),
                                           ("chest", (0.5, -0.8, 0.2), (0.0, 0.0, 0.92), 0.6), ("foot", (0.75, -0.6, 0.3), (0.075, -0.04, 0.06), 0.4)):
        offset = Vector(direction).normalized() * 4.0
        camera.data.ortho_scale = frame
        camera.location = Vector(target) + offset
        camera.rotation_euler = (-offset).to_track_quat("-Z", "Y").to_euler()
        scene.render.filepath = os.path.join(kit.PREVIEW_DIR, "%s_%s.png" % (name, view))
        bpy.ops.render.render(write_still=True)


# (part, material or None if the part colours itself, shapes, how to fuse them)
# The body comes first: the braces, the neckerchief and the buttons are laid on it.
PARTS = [
    ("body", None, boy.body, None),
    ("braces", BRACES, braces, None),
    ("kerchief", KERCHIEF, kerchief, None),
    ("buttons", BUTTON, buttons, None),
    ("head", SKIN, shrunk(boy.head), (0.004, 4, 2000)),
    ("hair", HAIR, shrunk(boy.hair), None),
    ("cap", TWEED, shrunk(boy.cap), None),
    ("crown", HAIR, shrunk(boy.hair_crown), None),
    ("hands", SKIN, boy.hands, None),
    ("fingers", SKIN, boy.fingers, None),
    ("boots", LEATHER, boots, (0.003, 3, 3000)),
]

if __name__ == "__main__":
    kit.export(NAME, bones(), PARTS, weights, MATERIALS, apart=("cap", "crown"))
    more_previews(NAME)
    kit.LOW = True
    kit.export(NAME + "_lo", bones(), [(part, material, shapes, None) for part, material, shapes, _fuse in PARTS], weights, MATERIALS, apart=("cap", "crown"))
    more_previews(NAME + "_lo")
