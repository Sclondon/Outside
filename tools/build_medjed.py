"""Builds Medjed and exports him for Godot.

Run from the project root:
    blender --background --python tools/build_medjed.py
then, so that Godot takes up the new model:
    godot --headless --path . --import

Writes models/medjed.glb, and tools/medjed.blend to look at and to change by hand.

Medjed is drawn in the Greenfield papyrus as a shroud with two eyes looking
out of it and two bare feet under the hem, and that is all this is: a sheet
over a post, 0.8 m across at the hem and 1.5 m tall, standing on the ground at
the origin and facing the game's +Z (Blender's -Y: he looks at you in Front
view, and his own left is on your right).

He has no bones. He is separate things, each named for what it is, which
scripts/medjed.gd reads from the model and moves:

    shroud             the sheet. Its origin is the ground under him: the game
                       bobs and rocks it about there as he shuffles, and bends
                       the lower part of it (the swing of the hem) by itself,
                       from the lowest point of the mesh upwards.
      eye_left         his left eye (on +X) and its brow, lying just off the
      eye_right        cloth; the other. Each has four shape keys:
                         shut        the lids closed: a dark bar, the brow down
                         wide        as he stares: the lids apart, the brow up
                         look_left   the pupil moved to his left (+X)
                         look_right  the pupil moved to his right
                       The game sets them from 0 to 1 and mixes them (half
                       shut is "shut" at 0.5). As he usually has them is the
                       Basis.
    foot_left          a bare foot and the ankle over it. Its origin is the
    foot_right         ground under the middle of him, and it is turned a
                       little toe out: the game lifts it, slides it and tips
                       it about that origin as he shuffles.

The colours are materials, named plainly: linen (the shroud), skin (the
feet), eye_dark (the line round the eye, the pupil, the brow) and eye_white.
The game takes each one's colour from here, so changing a material's Base
Color and exporting again changes him. What is painted eye_white is what
lights up as he makes ready to strike. (To export by hand: File, Export,
glTF 2.0, to models/medjed.glb, with +Y up and shape keys on.)

His gaze (the fan on the floor and the line from each eye) is not here: the
game draws it from what he can see at that moment.

Everything below is written in the game's own directions (x to his left, y
up, z the way he faces, in metres) and turned to Blender's as it is made.
"""

import bpy
import bmesh
import math
import os

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))

# The colours, as they are seen (sRGB).
COLOURS = {
    # (a warm off-white: unbleached linen, which the sun does not burn out to white)
    "linen": (0.80, 0.735, 0.60),
    "skin": (0.66, 0.42, 0.3),
    "eye_dark": (0.07, 0.06, 0.07),
    "eye_white": (0.97, 0.95, 0.88),
}
NAMES = list(COLOURS)

TALL = 1.5
# The shroud from the hem up: (height, radius).
PROFILE = [
    (0.16, 0.41), (0.23, 0.395), (0.45, 0.365), (0.7, 0.335), (0.92, 0.305), (1.1, 0.275),
    (1.24, 0.24), (1.35, 0.195), (1.43, 0.14), (1.48, 0.08), (1.5, 0.0),
]
SIDES = 24
# How many folds hang in it, and how deep they are at the hem.
FOLDS = 5
FOLD_DEPTH = 0.024

# The eyes: how high the middle of them is, how far round from the front each starts (radians) and how far
# out from the middle of the eye that is (metres along the cloth), and how far each layer stands off the cloth.
EYE_HEIGHT = 1.04
EYE_START = 0.035
EYE_OUT = 0.1
HALF_WIDE = 0.078
LID = 0.037
RIM = 0.011
PUPIL = 0.027
LOOK = 0.03
OFF_DARK = 0.007
OFF_WHITE = 0.0105
OFF_PUPIL = 0.014

# The feet: how far each is from the middle of him, and how far it is turned toe out (radians).
FOOT_APART = 0.12
FOOT_TURN = 0.14


def to_blender(p):
    return (p[0], -p[2], p[1])


def radius_at(height):
    """How wide the shroud is at a height."""
    for (low, wide), (high, narrow) in zip(PROFILE, PROFILE[1:]):
        if height <= high:
            t = min(max((height - low) / (high - low), 0.0), 1.0)
            return wide + (narrow - wide) * t
    return 0.0


class Shape:
    """Faces being gathered for one thing: each a list of points, a material and whether it is rounded."""

    def __init__(self):
        self.faces = []

    def face(self, points, material, smooth=True):
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
                    self.face([at(0, 0), at(1, k), at(1, k + 1)], material)
                elif row == rows - 1:
                    self.face([at(row, k), at(rows, 0), at(row, k + 1)], material)
                else:
                    self.face([at(row, k), at(row + 1, k), at(row + 1, k + 1), at(row, k + 1)], material)


# --- The things ---

def shroud():
    """The profile turned round, with a few soft folds that deepen towards the hem, and a hem that rises and falls."""
    s = Shape()

    def at(i, j):
        height, wide = PROFILE[i]
        turn = math.tau * j / SIDES
        low = min(max(1.0 - (height - PROFILE[0][0]) / 1.0, 0.0), 1.0) ** 2
        wide += math.sin(turn * FOLDS + 1.0) * FOLD_DEPTH * low if wide > 0.0 else 0.0
        if i == 0:
            height += math.sin(turn * FOLDS + 2.2) * 0.02
        return (math.sin(turn) * wide, height, math.cos(turn) * wide)
    for i in range(len(PROFILE) - 1):
        for j in range(SIDES):
            if i == len(PROFILE) - 2:
                s.face([at(i, j), at(i, j + 1), at(i + 1, 0)], "linen")
            else:
                s.face([at(i, j), at(i, j + 1), at(i + 1, j + 1), at(i + 1, j)], "linen")
    return s


def foot(side):
    """A bare foot, toes forward, and the ankle and shin over it, going up under the hem. `side`: 1 his left, -1
    his right (the great toe is on the inside)."""
    s = Shape()
    inner = -side
    # The foot from heel to the roots of the toes: (how far forward, half its width, its height, how far its
    # middle is to the inside).
    rings = [(0.238, 0.02, 0.03, 0.0), (0.255, 0.035, 0.058, 0.0), (0.288, 0.04, 0.072, 0.0), (0.335, 0.043, 0.064, 0.002),
             (0.39, 0.05, 0.046, 0.004), (0.435, 0.055, 0.034, 0.006), (0.462, 0.054, 0.026, 0.006)]
    around = 8

    def at(i, k):
        forward, wide, high, aside = rings[i]
        turn = math.tau * (k + 0.5) / around
        up = math.sin(turn)
        # (flat underneath, rounded over the top)
        up = math.copysign(abs(up) ** 0.55, up)
        return (inner * aside + math.cos(turn) * wide * side, high * 0.5 * (1.0 + up), forward)
    for i in range(len(rings) - 1):
        for k in range(around):
            s.face([at(i, k), at(i + 1, k), at(i + 1, k + 1), at(i, k + 1)], "skin")
    s.face([at(0, k) for k in range(around)], "skin")
    s.face([at(len(rings) - 1, k) for k in reversed(range(around))], "skin")
    # The toes: the great toe on the inside, and four that grow smaller and sit further back
    s.blob((inner * 0.036, 0.016, 0.474), (0.0175, 0.016, 0.026), "skin", 5, 3)
    for k in range(4):
        out = -0.01 + 0.0185 * k
        s.blob((side * out, 0.0125 - 0.001 * k, 0.471 - 0.0065 * k), (0.0105 - 0.0006 * k, 0.012 - 0.001 * k, 0.02 - 0.0015 * k), "skin", 5, 3)
    # The ankle and the shin
    shin = [(0.03, 0.03), (0.085, 0.031), (0.16, 0.036), (0.3, 0.04)]
    sides = 7
    for i in range(len(shin) - 1):
        for k in range(sides):
            one = math.tau * k / sides
            two = math.tau * (k + 1) / sides
            low, low_wide = shin[i]
            high, high_wide = shin[i + 1]
            s.face([(math.sin(one) * low_wide, low, 0.283 + math.cos(one) * low_wide), (math.sin(two) * low_wide, low, 0.283 + math.cos(two) * low_wide),
                    (math.sin(two) * high_wide, high, 0.283 + math.cos(two) * high_wide), (math.sin(one) * high_wide, high, 0.283 + math.cos(one) * high_wide)], "skin")
    return s


def on_cloth(side, across, up, off):
    """A point of an eye: `across` metres outwards from the middle of the eye along the cloth, `up` metres above
    it, and standing `off` the cloth."""
    turn = side * (EYE_START + (across + EYE_OUT) / radius_at(EYE_HEIGHT + 0.01))
    height = EYE_HEIGHT + up
    wide = radius_at(height) + off
    return (math.sin(turn) * wide, height, math.cos(turn) * wide)


def eye(side, open=1.0, look=0.0):
    """An eye as it is drawn: an almond with a dark line round it, a round pupil, and a heavy brow over it.
    `open`: 0 shut, 1 as he usually has them, 1.5 wide. `look`: how far the pupil is moved to his left, metres.
    Gives its points, and its faces as (points by number, material): the same number of each however it is open,
    which is what lets the shape keys be made of them."""
    points = []
    faces = []

    def lid(across):
        return LID * open * max(0.0, 1.0 - across * across / (HALF_WIDE * HALF_WIDE))

    def strip(columns, top, bottom, off, material):
        """A band across the eye: for each place across it, a point above and a point below."""
        start = len(points)
        for across in columns:
            points.append(on_cloth(side, across, top(across), off))
            points.append(on_cloth(side, across, bottom(across), off))
        for k in range(len(columns) - 1):
            a = start + k * 2
            faces.append(([a + 1, a + 3, a + 2, a], material))

    # The dark line round it: the almond and a little more, squared off at its corners
    strip([-0.094, -0.078, -0.068, -0.052, -0.032, -0.011, 0.011, 0.032, 0.052, 0.068, 0.078, 0.094],
          lambda x: lid(x) + RIM, lambda x: -lid(x) - RIM, OFF_DARK, "eye_dark")
    # The white of it
    strip([-0.078, -0.068, -0.052, -0.032, -0.011, 0.011, 0.032, 0.052, 0.068, 0.078],
          lid, lambda x: -lid(x), OFF_WHITE, "eye_white")
    # The pupil (the lids close over it)
    start = len(points)
    around = 16
    squash = min(open, 1.0)
    aside = look * side
    points.append(on_cloth(side, aside, 0.0, OFF_PUPIL))
    for k in range(around):
        turn = math.tau * k / around
        points.append(on_cloth(side, aside + math.cos(turn) * PUPIL, math.sin(turn) * PUPIL * squash, OFF_PUPIL))
    for k in range(around):
        faces.append(([start, start + 1 + k, start + 1 + (k + 1) % around], "eye_dark"))
    # The brow: it follows the lid, lower at its ends, and goes up and down with it
    def arch(across):
        return 0.06 + 0.015 * max(0.0, 1.0 - across * across / (HALF_WIDE * HALF_WIDE)) + 0.014 * (open - 1.0)
    strip([-0.09, -0.078, -0.06, -0.035, -0.012, 0.012, 0.035, 0.06, 0.078, 0.09],
          lambda x: arch(x) + 0.013, lambda x: arch(x) - 0.013, OFF_DARK, "eye_dark")
    return points, faces


# --- Putting it together ---

def linear(c):
    return ((c + 0.055) / 1.055) ** 2.4 if c > 0.04045 else c / 12.92


def mesh_of(name, shape, materials, wrapped=False):
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
    bmesh.ops.recalc_face_normals(made, faces=made.faces)
    if wrapped:
        # (texture coordinates: round him, and up him)
        layer = made.loops.layers.uv.new("UVMap")
        for face in made.faces:
            turns = [math.atan2(loop.vert.co.x, -loop.vert.co.y) / math.tau % 1.0 for loop in face.loops]
            for loop, turn in zip(face.loops, turns):
                if max(turns) - min(turns) > 0.5 and turn < 0.5:
                    turn += 1.0
                loop[layer].uv = (turn, loop.vert.co.z / TALL)
    mesh = bpy.data.meshes.new(name)
    made.to_mesh(mesh)
    made.free()
    keep(mesh, materials)
    return mesh


def keep(mesh, materials):
    """Gives a mesh only the materials it uses."""
    used = sorted({polygon.material_index for polygon in mesh.polygons})
    for polygon in mesh.polygons:
        polygon.material_index = used.index(polygon.material_index)
    for index in used:
        mesh.materials.append(materials[index])


def thing(name, mesh, at, parent=None, turn=0.0):
    made = bpy.data.objects.new(name, mesh)
    bpy.context.collection.objects.link(made)
    made.location = to_blender(at)
    made.rotation_euler = (0.0, 0.0, turn)
    made.parent = parent
    return made


def eye_thing(name, side, materials, parent):
    """An eye, with its shape keys. Its origin is the middle of it, on the cloth."""
    middle = on_cloth(side, 0.0, 0.0, 0.0)

    def local(points):
        return [to_blender((p[0] - middle[0], p[1] - middle[1], p[2] - middle[2])) for p in points]
    points, faces = eye(side)
    # (every face is turned to look outwards)
    turned = []
    for order, material in faces:
        a, b, c = (points[k] for k in order[:3])
        u = (b[0] - a[0], b[1] - a[1], b[2] - a[2])
        v = (c[0] - a[0], c[1] - a[1], c[2] - a[2])
        normal = (u[1] * v[2] - u[2] * v[1], u[2] * v[0] - u[0] * v[2], u[0] * v[1] - u[1] * v[0])
        turned.append(order if normal[0] * a[0] + normal[2] * a[2] > 0.0 else list(reversed(order)))
    mesh = bpy.data.meshes.new(name)
    mesh.from_pydata(local(points), [], turned)
    for polygon, (order, material) in zip(mesh.polygons, faces):
        polygon.material_index = NAMES.index(material)
    keep(mesh, materials)
    mesh.update()
    made = thing(name, mesh, middle, parent)
    made.shape_key_add(name="Basis")
    for label, open, look in (("shut", 0.0, 0.0), ("wide", 1.5, 0.0), ("look_left", 1.0, LOOK), ("look_right", 1.0, -LOOK)):
        key = made.shape_key_add(name=label)
        for k, p in enumerate(local(eye(side, open, look)[0])):
            key.data[k].co = p
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
        materials.append(material)
    sheet = thing("shroud", mesh_of("shroud", shroud(), materials, True), (0.0, 0.0, 0.0))
    eye_thing("eye_left", 1.0, materials, sheet)
    eye_thing("eye_right", -1.0, materials, sheet)
    thing("foot_left", mesh_of("foot_left", foot(1.0), materials), (FOOT_APART, 0.0, 0.0), None, FOOT_TURN)
    thing("foot_right", mesh_of("foot_right", foot(-1.0), materials), (-FOOT_APART, 0.0, 0.0), None, -FOOT_TURN)
    counts = []
    for made in bpy.data.objects:
        made.data.calc_loop_triangles()
        counts.append("%s=%d" % (made.name, len(made.data.loop_triangles)))
    os.makedirs(os.path.join(ROOT, "models"), exist_ok=True)
    bpy.ops.wm.save_as_mainfile(filepath=os.path.join(ROOT, "tools", "medjed.blend"))
    bpy.ops.export_scene.gltf(
        filepath=os.path.join(ROOT, "models", "medjed.glb"),
        export_format="GLB",
        export_yup=True,
        export_animations=False,
        export_morph=True,
        export_morph_normal=False,
    )
    print("BUILT medjed tris: " + " ".join(counts))


build()
