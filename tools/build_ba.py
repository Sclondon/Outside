"""Builds the Ba and exports it for Godot.

Run from the project root:
    blender --background --python tools/build_ba.py
then, so that Godot takes up the new model:
    godot --headless --path . --import

Writes models/ba.glb, and tools/ba.blend to look at and to change by hand.

The Ba is the part of a dead man that flies out of his tomb by day: a bird
with his own head. This is a falcon's body, pale, half a metre high as it
stands; painted wings (small feathers of turquoise over the arm, a line of
gold, long pale feathers tipped with dark blue); a man's head in the striped
headcloth of blue and gold, his eyes drawn long in black; a bird's legs; and
two small arms that it holds up.

It has no bones. It is separate things, each named for what it is, which
scripts/ba.gd moves (scripts/ba_mesh.gd reads them from the model):

    body               the body and its tail, lying along the way it flies
      head             the head and the headcloth; its origin is the neck
      wing_arm         the inner half of the wing on its left; origin the shoulder
        wing_hand      the outer half; its origin is the wrist
      wing_arm_mirror, wing_hand_mirror
                       the other wing: the same two meshes turned over, there
                       to be looked at. The game draws the first pair twice.
      arms             the two small arms; their origin is between the shoulders
    legs               both legs; their origin is the ground between the feet

It is modelled as it flies: body level, wings out flat, legs hanging. Where
each thing's origin is put is where the game hinges it, so moving an origin
moves the joint. The colours are materials, named plainly (feather, breast,
turquoise, gold, feather_tip, skin, skin_shade, eye_white, ink, lips, leg,
cloth_gold, cloth_blue); the game takes each one's colour from here, so
changing a material's Base Color and exporting again changes the Ba. (To
export by hand: File, Export, glTF 2.0, to models/ba.glb, with +Y up.)

Everything below is written in the game's own directions (x to its left, y
up, z the way it faces, in metres) and turned to Blender's as it is made.
"""

import bpy
import bmesh
import math
import os

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))

# The colours, as they are seen (sRGB).
COLOURS = {
    "feather": (0.9, 0.86, 0.72),
    "breast": (0.97, 0.95, 0.88),
    "turquoise": (0.26, 0.64, 0.62),
    "gold": (0.88, 0.62, 0.14),
    "feather_tip": (0.164, 0.328, 0.604),
    "skin": (0.78, 0.5, 0.32),
    "skin_shade": (0.69, 0.44, 0.28),
    "eye_white": (0.97, 0.96, 0.92),
    "ink": (0.05, 0.04, 0.05),
    "lips": (0.55, 0.22, 0.16),
    "leg": (0.86, 0.62, 0.22),
    "cloth_gold": (0.88, 0.62, 0.14),
    "cloth_blue": (0.14, 0.25, 0.6),
}
NAMES = list(COLOURS)

# Where the things are hinged (in the game's directions; each within the thing it hangs from).
BODY = (0.0, 0.25, 0.0)
NECK = (0.0, 0.045, 0.125)
SHOULDER = (0.07, 0.05, 0.055)
CHEST = (0.0, -0.02, 0.12)
ARM = 0.2    # how long the inner half of a wing is
HAND = 0.26  # and how far the outer half reaches along it
HEAD_SIZE = 1.2


def to_blender(p):
    return (p[0], -p[2], p[1])


def add(a, b):
    return (a[0] + b[0], a[1] + b[1], a[2] + b[2])


def mix(a, b, t):
    return (a[0] + (b[0] - a[0]) * t, a[1] + (b[1] - a[1]) * t, a[2] + (b[2] - a[2]) * t)


class Shape:
    """Faces being gathered for one thing: each a list of points, a material and whether it is rounded."""

    def __init__(self):
        self.faces = []

    def face(self, points, material, smooth=False):
        self.faces.append((points, NAMES.index(material), smooth))

    def blob(self, middle, radii, material, around, rows):
        """A ball, squashed to `radii`."""
        def at(row, k):
            high = math.pi * 0.5 - math.pi * row / rows
            turn = math.tau * k / around
            unit = (math.sin(turn) * math.cos(high), math.sin(high), math.cos(turn) * math.cos(high))
            return (middle[0] + unit[0] * radii[0], middle[1] + unit[1] * radii[1], middle[2] + unit[2] * radii[2])
        for row in range(rows):
            for k in range(around):
                if row == 0:
                    self.face([at(0, 0), at(1, k), at(1, k + 1)], material, True)
                elif row == rows - 1:
                    self.face([at(row, k), at(rows, 0), at(row, k + 1)], material, True)
                else:
                    self.face([at(row, k), at(row + 1, k), at(row + 1, k + 1), at(row, k + 1)], material, True)

    def limb(self, start, end, thick, material):
        """A thin limb: two flat strips crossed, tapering a little."""
        along = (end[0] - start[0], end[1] - start[1], end[2] - start[2])
        long = math.sqrt(sum(c * c for c in along))
        along = tuple(c / long for c in along)
        other = (0.0, 0.0, -1.0) if abs(along[2]) < 0.8 else (1.0, 0.0, 0.0)
        across = cross(along, other)
        size = math.sqrt(sum(c * c for c in across))
        across = tuple(c / size for c in across)
        over = cross(across, along)
        for way in (across, over):
            a = tuple(start[i] - way[i] * thick for i in range(3))
            b = tuple(start[i] + way[i] * thick for i in range(3))
            c = tuple(end[i] + way[i] * thick * 0.8 for i in range(3))
            d = tuple(end[i] - way[i] * thick * 0.8 for i in range(3))
            self.face([a, b, c, d], material)

    def striped(self, points, gap):
        """A flat piece of the headcloth, cut across into stripes of gold and blue, each `gap` high."""
        low = min(p[1] for p in points)
        high = max(p[1] for p in points)
        band = math.floor(low / gap)
        while band * gap < high:
            piece = clipped(clipped(points, band * gap, True), (band + 1) * gap, False)
            if len(piece) >= 3:
                self.face(piece, "cloth_blue" if band % 2 else "cloth_gold")
            band += 1


def cross(a, b):
    return (a[1] * b[2] - a[2] * b[1], a[2] * b[0] - a[0] * b[2], a[0] * b[1] - a[1] * b[0])


def clipped(points, height, above):
    """What is left of a flat piece above (or below) a height."""
    kept = []
    for i, here in enumerate(points):
        there = points[(i + 1) % len(points)]
        here_in = (here[1] >= height) if above else (here[1] <= height)
        there_in = (there[1] >= height) if above else (there[1] <= height)
        if here_in:
            kept.append(here)
        if here_in != there_in and abs(there[1] - here[1]) > 1e-9:
            kept.append(mix(here, there, (height - here[1]) / (there[1] - here[1])))
    return kept


# --- The things ---

def body():
    """A falcon's body, deep in the chest and drawn out behind; a collar of gold; and its tail, a fan of five feathers."""
    s = Shape()
    # (rings from the tail end to the breast: where along it, how wide, how deep, how far the middle is dropped)
    rings = [(-0.17, 0.012, 0.012, 0.0), (-0.12, 0.05, 0.045, 0.0), (-0.04, 0.08, 0.074, -0.004), (0.05, 0.09, 0.088, -0.01),
             (0.115, 0.068, 0.072, -0.004), (0.155, 0.022, 0.03, 0.012)]
    around = 8

    def at(i, k):
        along, wide, deep, drop = rings[i]
        turn = math.tau * k / around
        return (math.cos(turn) * wide, math.sin(turn) * deep + drop, along)
    for i in range(len(rings) - 1):
        for k in range(around):
            # (pale underneath and on the breast, cream above)
            turn = math.tau * (k + 0.5) / around
            pale = 0.5 - math.sin(turn) * 0.9 + (rings[i][0] + rings[i + 1][0]) * 1.5
            s.face([at(i, k), at(i + 1, k), at(i + 1, k + 1), at(i, k + 1)], "breast" if pale > 0.5 else "feather", True)
    s.blob(add(NECK, (0.0, -0.012, 0.0)), (0.05, 0.026, 0.05), "gold", 8, 3)
    root = (0.0, 0.0, -0.13)
    for k in range(5):
        one = -0.6 + 1.2 * k / 5.0
        two = -0.6 + 1.2 * (k + 1) / 5.0
        far = 0.2 - abs(k - 2.0) * 0.012
        a = add(root, (math.sin(one) * 0.045, 0.004, -math.cos(one) * 0.02))
        b = add(root, (math.sin(two) * 0.045, 0.004, -math.cos(two) * 0.02))
        c = add(root, (math.sin(two) * far, -0.006, -math.cos(two) * far))
        d = add(root, (math.sin(one) * far, -0.006, -math.cos(one) * far))
        s.face([a, b, mix(b, c, 0.72), mix(a, d, 0.72)], "feather")
        s.face([mix(a, d, 0.72), mix(b, c, 0.72), mix(c, d, 0.2), mix(d, c, 0.2)], "feather_tip")
    return s


def head():
    """A man's head, and the headcloth: a cap of it over his brow, the wings of it standing out behind his ears,
    and a lappet hanging down each side of his face. Its stripes are cut into it."""
    s = Shape()
    face = (0.0, 0.088, 0.006)
    s.blob((0.0, 0.02, 0.0), (0.03, 0.04, 0.03), "skin", 6, 3)
    s.blob(face, (0.056, 0.068, 0.062), "skin", 10, 6)
    # His nose, his ears
    s.face([add(face, (0.0, 0.012, 0.06)), add(face, (-0.011, -0.016, 0.057)), add(face, (0.0, -0.02, 0.076))], "skin_shade")
    s.face([add(face, (0.0, 0.012, 0.06)), add(face, (0.0, -0.02, 0.076)), add(face, (0.011, -0.016, 0.057))], "skin")
    for side in (-1.0, 1.0):
        s.blob(add(face, (side * 0.056, -0.004, 0.0)), (0.01, 0.02, 0.014), "skin_shade", 5, 3)
        # An eye, drawn long, and the brow over it
        eye = add(face, (side * 0.024, 0.01, 0.0562))
        s.face([add(eye, (-0.013, 0.0, 0.002)), add(eye, (0.0, -0.007, 0.004)), add(eye, (0.013, 0.0, -0.001)), add(eye, (0.0, 0.008, 0.003))], "eye_white")
        s.face([add(eye, (-0.005, 0.0, 0.006)), add(eye, (0.0, -0.006, 0.006)), add(eye, (0.005, 0.0, 0.005)), add(eye, (0.0, 0.007, 0.006))], "ink")
        s.face([add(eye, (side * 0.011, 0.002, 0.0)), add(eye, (side * 0.011, -0.003, 0.0)), add(eye, (side * 0.03, -0.001, -0.02))], "ink")
        s.face([add(eye, (-side * 0.014, 0.012, 0.002)), add(eye, (-side * 0.014, 0.017, 0.001)), add(eye, (side * 0.02, 0.019, -0.008)), add(eye, (side * 0.02, 0.014, -0.006))], "ink")
    # His mouth
    s.face([add(face, (-0.014, -0.034, 0.05)), add(face, (0.0, -0.039, 0.054)), add(face, (0.014, -0.034, 0.05)), add(face, (0.0, -0.031, 0.055))], "lips")
    # The cap: part of a ball a little bigger than his head, from his brow back over the crown and down to the
    # nape, in bands that run from ear to ear, gold and blue by turns.
    cap = (0.063, 0.076, 0.07)
    middle = add(face, (0.0, 0.004, -0.004))
    across = 8

    def on_cap(over, aside):
        unit = (math.sin(aside), math.cos(aside) * math.sin(over), math.cos(aside) * math.cos(over))
        return (middle[0] + unit[0] * cap[0], middle[1] + unit[1] * cap[1], middle[2] + unit[2] * cap[2])
    bands = 18
    first = 0.42
    last = math.pi + 1.15
    for band in range(bands):
        over_a = first + (last - first) * band / bands
        over_b = first + (last - first) * (band + 1) / bands
        for k in range(across):
            aside_a = math.radians(-68.0 + 136.0 * k / across)
            aside_b = math.radians(-68.0 + 136.0 * (k + 1) / across)
            s.face([on_cap(over_a, aside_a), on_cap(over_a, aside_b), on_cap(over_b, aside_b), on_cap(over_b, aside_a)], "cloth_blue" if band % 2 else "cloth_gold", True)
    # Its wings, standing out behind the ears: one flat piece, wide at the shoulders
    top = 0.15
    foot = 0.012
    s.striped([(-0.05, top, -0.012), (0.05, top, -0.012), (0.118, foot, -0.004), (-0.118, foot, -0.004)], 0.015)
    for side in (-1.0, 1.0):
        # and the lappets, down onto the breast
        s.striped([(side * 0.04, 0.05, 0.05), (side * 0.1, 0.045, 0.012), (side * 0.085, -0.055, 0.03), (side * 0.04, -0.06, 0.056)], 0.015)
        # (and the side of the cloth between them and the wing behind)
        s.striped([(side * 0.1, 0.045, 0.012), (side * 0.118, foot, -0.004), (side * 0.085, -0.055, 0.03)], 0.015)
    # (bigger than life, as it is drawn: it has to be known for a man's head from a way off)
    s.faces = [([tuple(c * HEAD_SIZE for c in p) for p in points], material, smooth) for points, material, smooth in s.faces]
    return s


def feather(s, a, b, c, d):
    """One feather's width of wing, from the front edge (a, b) back to the tips (c, d)."""
    s.face([a, b, mix(b, d, 0.36), mix(a, c, 0.36)], "turquoise")
    s.face([mix(a, c, 0.36), mix(b, d, 0.36), mix(b, d, 0.46), mix(a, c, 0.46)], "gold")
    s.face([mix(a, c, 0.46), mix(b, d, 0.46), mix(b, d, 0.8), mix(a, c, 0.8)], "feather")
    # (the tip is rounded off, and stands a little apart from the next)
    back = (c[0] - a[0], c[1] - a[1], c[2] - a[2])
    long = math.sqrt(sum(v * v for v in back))
    point = add(mix(c, d, 0.5), tuple(v / long * 0.012 for v in back))
    s.face([mix(a, c, 0.8), mix(b, d, 0.8), mix(d, c, 0.12), point, mix(c, d, 0.12)], "feather_tip")


def wing_arm():
    """The inner half of a wing, from the shoulder out along +x."""
    s = Shape()
    count = 4
    for k in range(count):
        one = ARM * k / count
        two = ARM * (k + 1) / count
        feather(s, (one, 0.0, 0.05), (two, 0.0, 0.055), (one + 0.008, -0.012, -0.135 - 0.006 * k), (two, -0.012, -0.14 - 0.006 * k))
    return s


def wing_hand():
    """The outer half: five long feathers fanned out to its tip."""
    s = Shape()
    count = 5
    for k in range(count):
        one = k / count
        two = (k + 1) / count
        # (the front edge runs out to the tip; the feathers are swept further back the further out they grow)
        lead_one = (HAND * 0.62 * one, 0.0, 0.055 - 0.03 * one * one)
        lead_two = (HAND * 0.62 * two, 0.0, 0.055 - 0.03 * two * two)
        sweep_one = 1.05 * one
        sweep_two = 1.05 * two
        long_one = 0.2 - 0.01 * one
        long_two = 0.2 - 0.01 * two
        tip_one = add(lead_one, (math.sin(sweep_one) * long_one, -0.014, -math.cos(sweep_one) * long_one))
        tip_two = add(lead_two, (math.sin(sweep_two) * long_two, -0.014, -math.cos(sweep_two) * long_two))
        feather(s, lead_one, lead_two, tip_one, tip_two)
    return s


def legs():
    """A bird's legs: thigh feathers, a shank, three toes forward and one back. The feet are at the ground."""
    s = Shape()
    for side in (-1.0, 1.0):
        hip = (side * 0.036, 0.2, -0.005)
        knee = (side * 0.038, 0.115, 0.012)
        foot = (side * 0.04, 0.008, 0.0)
        s.blob(mix(hip, knee, 0.35), (0.026, 0.06, 0.03), "feather", 6, 3)
        s.limb(knee, foot, 0.0085, "leg")
        for toe in ((side * 0.03, 0.0, 0.05), (0.0, 0.0, 0.058), (-side * 0.026, 0.0, 0.046), (0.0, 0.0, -0.032)):
            end = add(add(foot, toe), (0.0, -0.006, 0.0))
            long = math.sqrt(toe[0] * toe[0] + toe[2] * toe[2])
            wide = (-toe[2] / long * 0.007, 0.0, toe[0] / long * 0.007)
            s.face([add(foot, (-wide[0], 0.0, -wide[2])), add(foot, wide), end], "leg")
    return s


def arms():
    """Two small arms, held up before it with the hands open, as a man's are who greets the sun."""
    s = Shape()
    for side in (-1.0, 1.0):
        shoulder = (side * 0.05, 0.0, 0.0)
        elbow = (side * 0.068, -0.03, 0.06)
        wrist = (side * 0.062, 0.05, 0.1)
        s.limb(shoulder, elbow, 0.011, "skin")
        s.limb(elbow, wrist, 0.009, "skin")
        s.blob(add(wrist, (0.0, 0.016, 0.004)), (0.011, 0.02, 0.008), "skin", 5, 3)
        # (a band of gold at the wrist)
        s.blob(wrist, (0.012, 0.007, 0.012), "gold", 5, 2)
    return s


# --- Putting it together ---

def linear(c):
    return ((c + 0.055) / 1.055) ** 2.4 if c > 0.04045 else c / 12.92


def mesh_of(name, shape, materials):
    made = bmesh.new()
    for points, material, smooth in shape.faces:
        verts = [made.verts.new(to_blender(p)) for p in points]
        try:
            face = made.faces.new(verts)
        except ValueError:
            continue
        face.material_index = material
        face.smooth = smooth
    # (points that lie together are one point: what is rounded is rounded across them)
    bmesh.ops.remove_doubles(made, verts=made.verts, dist=0.00002)
    bmesh.ops.recalc_face_normals(made, faces=[f for f in made.faces if f.smooth])
    mesh = bpy.data.meshes.new(name)
    made.to_mesh(mesh)
    made.free()
    for material in materials:
        mesh.materials.append(material)
    return mesh


def thing(name, mesh, at, parent=None, mirrored=False):
    made = bpy.data.objects.new(name, mesh)
    bpy.context.collection.objects.link(made)
    made.location = to_blender(at)
    if mirrored:
        made.scale = (-1.0, 1.0, 1.0)
    made.parent = parent
    return made


def build():
    bpy.ops.wm.read_factory_settings(use_empty=True)
    materials = []
    for label, srgb in COLOURS.items():
        material = bpy.data.materials.new(label)
        material.use_nodes = True
        colour = tuple(linear(c) for c in srgb) + (1.0,)
        shader = material.node_tree.nodes["Principled BSDF"]
        shader.inputs["Base Color"].default_value = colour
        shader.inputs["Roughness"].default_value = 1.0
        material.diffuse_color = colour
        # (the wings are flat, and seen from both sides)
        material.use_backface_culling = False
        materials.append(material)
    whole = thing("body", mesh_of("body", body(), materials), BODY)
    thing("head", mesh_of("head", head(), materials), NECK, whole)
    arm_mesh = mesh_of("wing_arm", wing_arm(), materials)
    hand_mesh = mesh_of("wing_hand", wing_hand(), materials)
    arm = thing("wing_arm", arm_mesh, SHOULDER, whole)
    thing("wing_hand", hand_mesh, (ARM, 0.0, 0.0), arm)
    other = thing("wing_arm_mirror", arm_mesh, (-SHOULDER[0], SHOULDER[1], SHOULDER[2]), whole, True)
    thing("wing_hand_mirror", hand_mesh, (ARM, 0.0, 0.0), other)
    thing("arms", mesh_of("arms", arms(), materials), CHEST, whole)
    thing("legs", mesh_of("legs", legs(), materials), (0.0, 0.0, 0.0))
    triangles = 0
    for made in bpy.data.objects:
        made.data.calc_loop_triangles()
        triangles += len(made.data.loop_triangles)
    os.makedirs(os.path.join(ROOT, "models"), exist_ok=True)
    bpy.ops.wm.save_as_mainfile(filepath=os.path.join(ROOT, "tools", "ba.blend"))
    bpy.ops.export_scene.gltf(
        filepath=os.path.join(ROOT, "models", "ba.glb"),
        export_format="GLB",
        export_yup=True,
        export_animations=False,
    )
    print("BUILT ba tris=%d (both wings)" % triangles)


build()
