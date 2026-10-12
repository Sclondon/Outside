"""Builds Apophis, the great serpent, and exports him for Godot.

Run from the project root:
    blender --background --python tools/build_apophis.py
    godot --headless --path . --import

Writes models/apophis.glb, and tools/apophis.blend to open, look at and change.
There are three things in it, and scripts/apophis.gd makes the snake from them:

- `apophis_head`: his head, on bones. `head` carries the skull; `jaw` is hinged
  at the back of it and carries the lower jaw and its teeth; `tongue` (a child
  of `jaw`) carries the forked tongue, and is where it comes out from;
  `fangs` carries the two long teeth in the roof of his mouth, and is where
  they are drawn back to. Turn `jaw` about its X in Pose Mode to see him gape.
  The game does not use the bones as bones: it reads which bone each point
  hangs from and how much, and works the jaw, tongue and fangs in its shader.
- `apophis_body`: ONE LENGTH of his body, `PERIOD` long, at his full thickness.
  The game lays copies of it end to end for as long as he is to be, thins them
  at his neck and down his tail, and bends the whole along his path. So the
  pattern on it must meet itself end to end. (In the .blend it has an Array
  modifier, to show a good length of him; only the one length is exported.)
- `apophis_knife`: one of the knives stuck in him, point down at its origin.

There is no picture on him. His colours are materials, a face at a time, so
that the dark saddles down his back are cut cleanly along the mesh's own
edges: `back`, `mark` (the saddles, the mask along his head, his brows),
`edge` (the pale teeth along each saddle), `belly` and `belly_shade` (the
plates under him, turn about), `mouth`, `tooth`, `tongue`, `eye` and `pupil`
(which shine by themselves in the game), `nostril`; and the knife's `bronze`,
`wood` and `grip`. Change a material's colour, or which faces have it, and
that is how he looks in the game.

Everything below is written in Godot's space (metres, Y up, his head looking
along +Z, his body trailing off along -Z) and turned into Blender's as it is
made. He is painted in tombs as a very long snake in many coils, yellow or
dark, often with knives in him.
"""

import math
import os
import sys

import bmesh
import bpy
from mathutils import Vector

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))

# How thick his body is, how long one length of the pattern is, and how many rings and sides that length has.
THICK = 0.5
RINGS = 8
PERIOD = 1.152
SIDES = 12
# How big his head is for his body.
HEAD = 1.45

MATERIALS = [
    ("back", (0.90, 0.76, 0.38)),
    ("mark", (0.40, 0.27, 0.17)),
    ("edge", (0.97, 0.93, 0.78)),
    ("belly", (0.96, 0.92, 0.78)),
    ("belly_shade", (0.86, 0.79, 0.60)),
    ("mouth", (0.86, 0.30, 0.30)),
    ("tooth", (0.98, 0.96, 0.90)),
    ("tongue", (0.62, 0.15, 0.25)),
    ("eye", (1.0, 0.93, 0.38)),
    ("pupil", (0.0, 0.0, 0.0)),
    ("nostril", (0.08, 0.05, 0.04)),
    ("bronze", (0.82, 0.58, 0.26)),
    ("wood", (0.50, 0.33, 0.14)),
    ("grip", (0.16, 0.11, 0.08)),
]
INDEX = {name: i for i, (name, _) in enumerate(MATERIALS)}


def to_blender(x, y, z):
    return Vector((x, -z, y))


def linear(c):
    return ((c + 0.055) / 1.055) ** 2.4 if c > 0.04045 else c / 12.92


def smoothstep(a, b, x):
    t = min(max((x - a) / (b - a), 0.0), 1.0)
    return t * t * (3.0 - 2.0 * t)


class Shape:
    """A mesh being made: points in Godot's space, each hung from bones, and faces each of one material."""

    def __init__(self):
        self.bm = bmesh.new()
        self.layer = self.bm.verts.layers.deform.verify()
        self.hung = []

    def point(self, x, y, z, bones=None):
        vert = self.bm.verts.new(to_blender(x, y, z))
        self.hung.append(bones or {"head": 1.0})
        return vert

    def face(self, verts, material):
        try:
            made = self.bm.faces.new(verts)
        except ValueError:
            return
        made.material_index = INDEX[material]
        made.smooth = True

    def ball(self, at, radii, material, bones=None, rows=5, columns=8):
        grid = []
        for row in range(rows + 1):
            tilt = math.pi * row / rows
            grid.append([self.point(at[0] + math.sin(tilt) * math.cos(math.tau * c / columns) * radii[0], at[1] + math.cos(tilt) * radii[1],
                                    at[2] + math.sin(tilt) * math.sin(math.tau * c / columns) * radii[2], bones) for c in range(columns)])
        for row in range(rows):
            for c in range(columns):
                d = (c + 1) % columns
                if row == 0:
                    self.face((grid[0][0], grid[1][d], grid[1][c]), material)
                elif row == rows - 1:
                    self.face((grid[row][c], grid[row][d], grid[rows][0]), material)
                else:
                    self.face((grid[row][c], grid[row][d], grid[row + 1][d], grid[row + 1][c]), material)

    def spike(self, foot, tip, radius, material, bones):
        axis = (Vector(tip) - Vector(foot)).normalized()
        one = axis.cross(Vector((0, 0, 1))).normalized()
        other = axis.cross(one)
        point = self.point(tip[0], tip[1], tip[2], bones)
        ring = []
        for k in range(5):
            out = Vector(foot) + (one * math.cos(math.tau * k / 5) + other * math.sin(math.tau * k / 5)) * radius
            ring.append(self.point(out.x, out.y, out.z, bones))
        for k in range(5):
            self.face((ring[k], ring[(k + 1) % 5], point), material)
        self.face(ring, material)

    def box(self, middle, size, material):
        corners = {}
        for sx in (-1, 1):
            for sy in (-1, 1):
                for sz in (-1, 1):
                    corners[(sx, sy, sz)] = self.point(middle[0] + sx * size[0] / 2, middle[1] + sy * size[1] / 2, middle[2] + sz * size[2] / 2)
        for axis in range(3):
            for way in (-1, 1):
                ring = []
                for a, b in ((-1, -1), (1, -1), (1, 1), (-1, 1)):
                    key = [0, 0, 0]
                    key[axis] = way
                    key[(axis + 1) % 3] = a
                    key[(axis + 2) % 3] = b
                    ring.append(corners[tuple(key)])
                made = self.bm.faces.new(ring)
                made.material_index = INDEX[material]

    def finish(self, name, materials, armature=None):
        self.bm.normal_update()
        bmesh.ops.recalc_face_normals(self.bm, faces=self.bm.faces[:])
        mesh = bpy.data.meshes.new(name)
        made = bpy.data.objects.new(name, mesh)
        bpy.context.collection.objects.link(made)
        for material in materials:
            mesh.materials.append(material)
        if armature:
            groups = {bone.name: made.vertex_groups.new(name=bone.name).index for bone in armature.data.bones}
            for vert, bones in zip(self.bm.verts, self.hung):
                for bone, weight in bones.items():
                    if weight > 0.001:
                        vert[self.layer][groups[bone]] = weight
        self.bm.to_mesh(mesh)
        self.bm.free()
        if armature:
            made.parent = armature
            made.modifiers.new("Armature", "ARMATURE").object = armature
        print("BUILT %s verts=%d tris=%d" % (name, len(mesh.vertices), sum(len(p.vertices) - 2 for p in mesh.polygons)))
        return made


def across(angle, radius):
    """A place on the outline of his body: rounder over his back than under his belly."""
    c, s = math.cos(angle), math.sin(angle)
    return c * radius * 1.08, s * radius * (0.62 if s < 0.0 else 0.95)


def body():
    """One length of his body: the saddle down his back, the blotch low on each flank between saddles, and the plates under him."""
    shape = Shape()
    lines = []
    for line in range(RINGS + 1):
        ring = []
        for k in range(SIDES):
            x, y = across(math.tau * k / SIDES - math.pi / 2, THICK / 2)
            ring.append(shape.point(x, y, -PERIOD * line / RINGS))
        lines.append(ring)
    top = SIDES // 2
    for r in range(RINGS):
        # How many ring-lengths this one is from the middle of the saddle (none: it is between two saddles),
        # and which of its two lines is the nearer the middle.
        middle = RINGS // 2
        gap = r == 0 or r == RINGS - 1
        nearer, further = (r + 1, r) if r < middle else (r, r + 1)
        away = middle - 1 - r if r < middle else r - middle
        for side in (1, -1):
            for j in range(top):
                # (j counts columns down from the ridge of his back; the lowest two are his belly)
                def at(line, t):
                    return lines[line][(top + side * t) % SIDES]
                corners = (at(nearer, j), at(nearer, j + 1), at(further, j + 1), at(further, j))
                if j >= top - 2:
                    shape.face(corners, "belly" if r % 2 == 0 else "belly_shade")
                elif gap:
                    shape.face(corners, "mark" if j == top - 3 else "back")
                elif j < 2 - away:
                    shape.face(corners, "mark")
                elif j == 2 - away:
                    # The saddle's edge runs corner to corner across this one: dark inside it, a pale tooth outside.
                    shape.face((corners[0], corners[1], corners[3]), "mark")
                    shape.face((corners[1], corners[2], corners[3]), "edge")
                else:
                    shape.face(corners, "back")
    return shape


def head(size):
    """His head, looking along +Z from where it joins his neck, its mouth along y = 0."""
    shape = Shape()
    # How far along, how wide (half), how high above the line of the mouth; and the same for the jaw, downwards.
    skull = [[0.0, 0.15, 0.13], [0.1, 0.24, 0.17], [0.24, 0.29, 0.175], [0.4, 0.25, 0.15], [0.54, 0.19, 0.115], [0.66, 0.135, 0.085], [0.74, 0.075, 0.05]]
    jaw = [[0.0, 0.145, 0.09], [0.1, 0.23, 0.105], [0.24, 0.275, 0.095], [0.4, 0.235, 0.078], [0.54, 0.175, 0.06], [0.66, 0.12, 0.045], [0.72, 0.06, 0.03]]
    segments = 10
    for half, stations in enumerate((skull, jaw)):
        way = 1.0 if half == 0 else -1.0

        def bones(z):
            if half == 0:
                return {"head": 1.0}
            goes = smoothstep(0.05, 0.3, z)
            return {"jaw": goes, "head": 1.0 - goes}
        grid = []
        for z, wide, tall in stations:
            grid.append([shape.point(math.cos(math.pi * k / segments) * wide * size, way * math.sin(math.pi * k / segments) ** 0.75 * tall * size, z * size, bones(z))
                         for k in range(segments + 1)])
        for i in range(len(stations) - 1):
            for k in range(segments):
                material = "belly"
                if half == 0:
                    lower = min(k, segments - 1 - k)
                    # (a pale lip, a dark mask along each side for his eye to shine out of, and his back's colour over the top)
                    material = "belly" if lower == 0 else "mark" if lower <= 2 and 1 <= i <= 4 else "back"
                shape.face((grid[i][k], grid[i][k + 1], grid[i + 1][k + 1], grid[i + 1][k]), material)
            # The inside of the mouth: its roof, and the floor of the jaw.
            shape.face((grid[i][0], grid[i + 1][0], grid[i + 1][segments], grid[i][segments]), "mouth")
        # (closed at the snout and at the back)
        last = stations[-1]
        tip = shape.point(0.0, way * last[2] * size * 0.4, (last[0] + 0.035) * size, bones(last[0]))
        nape = shape.point(0.0, way * stations[0][2] * size * 0.4, -0.02 * size, bones(0.0))
        for k in range(segments):
            shape.face((grid[-1][k], grid[-1][k + 1], tip), "back" if half == 0 else "belly")
            shape.face((grid[0][k + 1], grid[0][k], nape), "back" if half == 0 else "belly")
        shape.face((grid[-1][segments], grid[-1][0], tip), "mouth")
        shape.face((grid[0][0], grid[0][segments], nape), "mouth")
    for side in (1.0, -1.0):
        # Two long fangs in the roof of his mouth, and short teeth in his jaw.
        shape.spike((side * 0.095 * size, 0.0, 0.6 * size), (side * 0.085 * size, -0.19 * size, 0.56 * size), 0.027 * size, "tooth", {"fangs": 1.0})
        shape.spike((side * 0.12 * size, 0.0, 0.5 * size), (side * 0.12 * size, 0.06 * size, 0.5 * size), 0.016 * size, "tooth", {"jaw": 1.0})
        shape.spike((side * 0.085 * size, 0.0, 0.62 * size), (side * 0.085 * size, 0.05 * size, 0.62 * size), 0.014 * size, "tooth", {"jaw": 1.0})
        shape.spike((side * 0.16 * size, 0.0, 0.36 * size), (side * 0.16 * size, 0.05 * size, 0.36 * size), 0.014 * size, "tooth", {"jaw": 1.0})
        # An eye, with a slit down it; and a heavy dark lid over the top of it, lower towards the snout, which is what makes him scowl.
        eye = Vector((side * 0.205, 0.092, 0.4)) * size
        shape.ball(eye, (0.055 * size, 0.068 * size, 0.09 * size), "eye")
        out = Vector((side, 0.5, 0.22)).normalized()
        along = Vector((0, 1, 0)).cross(out).normalized()
        upward = out.cross(along).normalized()
        slit = eye + out * 0.064 * size
        corners = [slit + upward * 0.06 * size, slit + along * 0.016 * size, slit - upward * 0.06 * size, slit - along * 0.016 * size]
        shape.face([shape.point(c.x, c.y, c.z) for c in corners], "pupil")
        shape.ball(eye + Vector((side * -0.012, 0.05, -0.03)) * size, (0.05 * size, 0.03 * size, 0.08 * size), "mark")
        shape.ball(eye + Vector((side * -0.004, 0.036, 0.055)) * size, (0.042 * size, 0.026 * size, 0.055 * size), "mark")
        shape.ball((side * 0.045 * size, 0.045 * size, 0.74 * size), (0.014 * size, 0.012 * size, 0.018 * size), "nostril")
    # His tongue: a dark ribbon that forks. It lies in his mouth, all the way out, and the game draws it in.
    start, fork, end, wide, lies = 0.38 * size, 0.74 * size, 1.0 * size, 0.026 * size, 0.012 * size
    hangs = {"tongue": 1.0}
    root_l, root_r = shape.point(wide, lies, start, hangs), shape.point(-wide, lies, start, hangs)
    fork_l, fork_m, fork_r = shape.point(wide, lies, fork, hangs), shape.point(0.0, lies, fork, hangs), shape.point(-wide, lies, fork, hangs)
    shape.face((root_l, root_r, fork_r, fork_m, fork_l), "tongue")
    shape.face((fork_l, fork_m, shape.point(wide * 3.4, lies, end, hangs)), "tongue")
    shape.face((fork_m, fork_r, shape.point(-wide * 3.4, lies, end, hangs)), "tongue")
    return shape


def knife():
    """A knife of bronze with a dark handle: its point is at its origin and it stands along +Y."""
    shape = Shape()
    shape.box((0.0, 0.14, 0.0), (0.075, 0.34, 0.012), "bronze")
    shape.box((0.0, 0.31, 0.0), (0.15, 0.03, 0.035), "wood")
    shape.box((0.0, 0.4, 0.0), (0.04, 0.16, 0.04), "grip")
    return shape


def rig(size):
    data = bpy.data.armatures.new("rig")
    armature = bpy.data.objects.new("rig", data)
    bpy.context.collection.objects.link(armature)
    bpy.context.view_layer.objects.active = armature
    bpy.ops.object.mode_set(mode="EDIT")
    # (a bone, where it starts, where it ends, what it hangs from)
    for name, at, to, parent in [("head", (0, 0, 0), (0, 0.2, 0), None), ("jaw", (0, 0, 0.08), (0, 0, 0.7), "head"), ("tongue", (0, 0.012, 0.38), (0, 0.012, 1.0), "jaw"),
                                 ("fangs", (0, 0, 0.6), (0, -0.19, 0.56), "head")]:
        bone = data.edit_bones.new(name)
        bone.head = to_blender(at[0] * size, at[1] * size, at[2] * size)
        bone.tail = to_blender(to[0] * size, to[1] * size, to[2] * size)
        bone.roll = 0.0
        if parent:
            bone.parent = data.edit_bones[parent]
    bpy.ops.object.mode_set(mode="OBJECT")
    return armature


def build():
    bpy.ops.wm.read_factory_settings(use_empty=True)
    materials = []
    for label, srgb in MATERIALS:
        material = bpy.data.materials.new(label)
        material.use_nodes = True
        colour = tuple(linear(c) for c in srgb) + (1.0,)
        shader = material.node_tree.nodes["Principled BSDF"]
        shader.inputs["Base Color"].default_value = colour
        shader.inputs["Roughness"].default_value = 1.0
        if label == "eye":
            shader.inputs["Emission Color"].default_value = colour
            shader.inputs["Emission Strength"].default_value = 1.0
        material.diffuse_color = colour
        materials.append(material)
    size = THICK / 0.5 * HEAD
    armature = rig(size)
    head(size).finish("apophis_head", materials, armature)
    length = body().finish("apophis_body", materials)
    # (a good length of him to look at; only the one is exported)
    shown = length.modifiers.new("Array", "ARRAY")
    shown.count = 14
    shown.use_relative_offset = False
    shown.use_constant_offset = True
    shown.constant_offset_displace = (0.0, PERIOD, 0.0)
    stuck = knife().finish("apophis_knife", materials)
    stuck.location = (0.0, PERIOD * 2.5, THICK * 0.4)
    os.makedirs(os.path.join(ROOT, "models"), exist_ok=True)
    bpy.ops.wm.save_as_mainfile(filepath=os.path.join(ROOT, "tools", "apophis.blend"))
    bpy.ops.export_scene.gltf(filepath=os.path.join(ROOT, "models", "apophis.glb"), export_format="GLB", export_yup=True, export_animations=False, export_skins=True, export_apply=False)
    if "--" in sys.argv and len(sys.argv) > sys.argv.index("--") + 1:
        preview(sys.argv[sys.argv.index("--") + 1])


def preview(folder):
    """Pictures of the model as Blender has it, to check it without opening it."""
    scene = bpy.context.scene
    scene.render.engine = "BLENDER_WORKBENCH"
    scene.display.shading.light = "STUDIO"
    scene.display.shading.color_type = "MATERIAL"
    scene.render.resolution_x, scene.render.resolution_y = 900, 900
    scene.world = bpy.data.worlds.new("World")
    scene.world.color = (0.35, 0.38, 0.42)
    camera = bpy.data.objects.new("Camera", bpy.data.cameras.new("Camera"))
    camera.data.type = "ORTHO"
    scene.collection.objects.link(camera)
    scene.camera = camera
    for view, direction, target, frame in [("side", (1, -0.25, 0.15), (0.0, 0.3, 0.0), 2.6), ("front", (0.45, -1, 0.3), (0.0, -0.4, 0.0), 1.6), ("above", (0.1, 0.1, 1), (0.0, 1.5, 0.0), 5.0)]:
        offset = Vector(direction).normalized() * 12.0
        camera.data.ortho_scale = frame
        camera.location = Vector(target) + offset
        camera.rotation_euler = (-offset).to_track_quat("-Z", "Y").to_euler()
        scene.render.filepath = os.path.join(folder, "apophis_%s.png" % view)
        bpy.ops.render.render(write_still=True)


if __name__ == "__main__":
    build()
