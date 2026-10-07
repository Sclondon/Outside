"""Builds the Outside character and exports it for Godot.

Run from the project root:
    blender --background --python tools/build_character.py

Writes models/boy.glb (used by the game) and tools/boy.blend (for hand edits).
If you edit the .blend by hand, export it over models/boy.glb as glTF Binary
with +Y up; re-running this script overwrites both files.

All coordinates below are in Godot space (metres, Y up, the character faces
+Z and +X is its left) and converted on the way into Blender.

Every bone points straight up with no roll, which makes each bone's rest
orientation the identity in Godot. scripts/character_rig.gd relies on that and
on the joint positions here matching its constants.
"""

import math
import os
import sys

import bmesh
import bpy
from mathutils import Matrix, Vector

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
PREVIEW_DIR = sys.argv[sys.argv.index("--") + 1] if "--" in sys.argv else None

# Joints. Keep in step with character_rig.gd.
HIPS = Vector((0.0, 0.685, 0.0))
SPINE = HIPS + Vector((0.0, 0.03, 0.0))
HEAD = SPINE + Vector((0.0, 0.35, 0.0))
SHOULDER_X, SHOULDER_Y = 0.14, SPINE.y + 0.28
HIP_X, HIP_Y = 0.075, HIPS.y - 0.02
UPPER_ARM = FOREARM = 0.2
THIGH = SHIN = 0.32
SOLE_DROP = 0.05  # ankle joint height above the sole

SHIRT, TROUSERS, SKIN, DARK = range(4)
MATERIALS = [
    ("shirt", (0.60, 0.10, 0.08)),
    ("trousers", (0.07, 0.075, 0.09)),
    ("skin", (0.74, 0.68, 0.64)),
    ("hair", (0.05, 0.045, 0.04)),
]

X, Y, Z = Vector((1, 0, 0)), Vector((0, 1, 0)), Vector((0, 0, 1))


def to_blender(p):
    return Vector((p.x, -p.z, p.y))


def blend(edge0, edge1, x):
    """Smoothstep that also works with edge0 > edge1."""
    t = min(max((x - edge0) / (edge1 - edge0), 0.0), 1.0)
    return t * t * (3.0 - 2.0 * t)


class Builder:
    def __init__(self):
        self.bm = bmesh.new()
        self.weights = []

    def tube(self, rings, material, weigh, segments=16, floor=None):
        """Skins a closed surface over rings of (centre, u, v) and caps both ends."""
        loops = []
        for centre, u, v in rings:
            loop = []
            for i in range(segments):
                angle = math.tau * i / segments
                loop.append(self._vert(centre + u * math.cos(angle) + v * math.sin(angle), weigh, floor))
            loops.append(loop)
        faces = []
        for a, b in zip(loops, loops[1:]):
            for i in range(segments):
                j = (i + 1) % segments
                faces.append(self.bm.faces.new((a[i], a[j], b[j], b[i])))
        for loop, (centre, _, _) in ((loops[0], rings[0]), (loops[-1], rings[-1])):
            pole = self._vert(centre, weigh, floor)
            for i in range(segments):
                faces.append(self.bm.faces.new((loop[i], loop[(i + 1) % segments], pole)))
        for face in faces:
            face.material_index = material
            face.smooth = True
        bmesh.ops.recalc_face_normals(self.bm, faces=faces)

    def ellipsoid(self, centre, radii, material, weigh, tilt=None, segments=12, rings=7):
        loops = []
        for k in range(1, rings + 1):
            phi = -math.pi / 2 + math.pi * k / (rings + 1)
            c, s = math.cos(phi), math.sin(phi)
            ring = (Y * radii.y * s, X * radii.x * c, Z * radii.z * c)
            if tilt:
                ring = tuple(tilt @ part for part in ring)
            loops.append((centre + ring[0], ring[1], ring[2]))
        self.tube(loops, material, weigh, segments)

    def _vert(self, position, weigh, floor):
        if floor is not None and position.y < floor:
            position = Vector((position.x, floor, position.z))
        vert = self.bm.verts.new(to_blender(position))
        self.weights.append(weigh(position))
        return vert


def dome(ring, axis, height, steps=4):
    """Rings that round off the end of a tube, starting just past `ring`."""
    centre, u, v = ring
    out = []
    for k in range(1, steps + 1):
        angle = math.pi / 2 * k / (steps + 0.6)
        out.append((centre + axis * height * math.sin(angle), u * math.cos(angle), v * math.cos(angle)))
    return out


def upright(x, y, z, rx, rz):
    return (Vector((x, y, z)), X * rx, Z * rz)


def only(bone):
    return lambda _p: {bone: 1.0}


def build_leg(b, side, suffix):
    thigh, shin, foot = "thigh" + suffix, "shin" + suffix, "foot" + suffix
    x = side * HIP_X
    knee_y = HIP_Y - THIGH
    ankle = Vector((x, HIP_Y - THIGH - SHIN, 0.0))

    def weigh(p):
        lower = blend(knee_y + 0.05, knee_y - 0.05, p.y)
        return {thigh: 1.0 - lower, shin: lower}

    # (distance below the hip, radius, forward offset)
    profile = [
        (0.00, 0.066, 0.000), (0.08, 0.064, 0.000), (0.18, 0.058, 0.002), (0.25, 0.054, 0.004),
        (0.29, 0.052, 0.005), (0.32, 0.051, 0.006), (0.35, 0.050, 0.004), (0.39, 0.049, -0.001),
        (0.46, 0.050, -0.006), (0.54, 0.045, -0.004), (0.60, 0.042, 0.000), (0.622, 0.043, 0.000),
    ]
    rings = [upright(x, HIP_Y - d, z, r, r * 1.06) for d, r, z in profile]
    rings = dome(rings[0], Y, 0.05)[::-1] + rings
    # Tuck the hem back up inside the leg so the opening reads as cloth.
    rings.append(upright(x, HIP_Y - 0.624, 0.0, 0.035, 0.037))
    rings.append(upright(x, HIP_Y - 0.60, 0.0, 0.033, 0.035))
    b.tube(rings, TROUSERS, weigh)

    # Sock, visible when the foot flexes.
    b.tube([upright(x, ankle.y + dy, 0.0, 0.034, 0.036) for dy in (0.05, 0.0, -0.02)], DARK, only(foot), 12)

    # Shoe, built heel to toe and flattened onto the sole.
    def across(z, y, rx, ry):
        return (ankle + Vector((0.0, y, z)), X * rx, Y * ry)

    shoe = [
        across(-0.040, -0.020, 0.033, 0.028), across(-0.010, -0.016, 0.039, 0.033),
        across(0.030, -0.021, 0.042, 0.029), across(0.070, -0.027, 0.043, 0.023),
        across(0.105, -0.031, 0.040, 0.019),
    ]
    shoe = dome(shoe[0], -Z, 0.022, 3)[::-1] + shoe + dome(shoe[-1], Z, 0.03, 3)
    b.tube(shoe, DARK, only(foot), 14, floor=ankle.y - SOLE_DROP)


def build_arm(b, side, suffix):
    upper, lower = "upper_arm" + suffix, "forearm" + suffix
    x = side * SHOULDER_X
    elbow_y = SHOULDER_Y - UPPER_ARM

    def weigh(p):
        fore = blend(elbow_y + 0.04, elbow_y - 0.04, p.y)
        return {upper: 1.0 - fore, lower: fore}

    profile = [
        (0.00, 0.043), (0.06, 0.040), (0.13, 0.036), (0.17, 0.035), (0.20, 0.035),
        (0.23, 0.034), (0.30, 0.031), (0.37, 0.030), (0.392, 0.032),
    ]
    rings = [upright(x, SHOULDER_Y - d, 0.0, r, r) for d, r in profile]
    rings = dome(rings[0], Y, 0.03)[::-1] + rings
    rings.append(upright(x, SHOULDER_Y - 0.394, 0.0, 0.024, 0.024))
    rings.append(upright(x, SHOULDER_Y - 0.37, 0.0, 0.022, 0.022))
    b.tube(rings, SHIRT, weigh)

    # Mitten hand, palm towards the body.
    hand = [(0.375, 0.015, 0.019), (0.405, 0.018, 0.028), (0.435, 0.020, 0.033), (0.462, 0.018, 0.029)]
    rings = [upright(x, SHOULDER_Y - d, 0.004, rx, rz) for d, rx, rz in hand]
    rings += dome(rings[-1], -Y, 0.024)
    b.tube(rings, SKIN, only(lower), 12)
    thumb = Vector((x - side * 0.004, SHOULDER_Y - 0.425, 0.034))
    b.ellipsoid(thumb, Vector((0.011, 0.024, 0.012)), SKIN, only(lower), Matrix.Rotation(0.5, 3, "X"), 8, 5)


def build_torso(b):
    def weigh(p):
        lower = blend(0.81, 0.71, p.y)
        return {"hips": lower, "spine": 1.0 - lower}

    b.tube(
        dome(upright(0, 0.635, 0, 0.100, 0.083), -Y, 0.045)[::-1]
        + [upright(0, 0.635, 0, 0.100, 0.083), upright(0, 0.69, 0, 0.105, 0.088), upright(0, 0.74, 0, 0.100, 0.083)]
        + dome(upright(0, 0.74, 0, 0.100, 0.083), Y, 0.03),
        TROUSERS, only("hips"),
    )

    # (height, half width, half depth, forward offset)
    profile = [
        (0.716, 0.098, 0.079, 0.000), (0.692, 0.100, 0.081, 0.000),
        (0.690, 0.113, 0.094, 0.000), (0.70, 0.114, 0.095, 0.000), (0.75, 0.110, 0.091, 0.001),
        (0.82, 0.102, 0.083, 0.002), (0.89, 0.108, 0.086, 0.005), (0.945, 0.128, 0.085, 0.004),
        (0.985, 0.152, 0.079, 0.001), (1.012, 0.142, 0.072, -0.001), (1.032, 0.104, 0.064, -0.002), (1.042, 0.066, 0.056, -0.003),
        (1.052, 0.050, 0.049, -0.002), (1.064, 0.046, 0.046, 0.000), (1.068, 0.039, 0.039, 0.000),
        (1.058, 0.036, 0.036, 0.000),
    ]
    b.tube([upright(0, y, z, rx, rz) for y, rx, rz, z in profile], SHIRT, weigh, 20)


def build_head(b):
    def neck_weight(p):
        upper = blend(1.045, 1.085, p.y)
        return {"spine": 1.0 - upper, "head": upper}

    b.tube([upright(0, y, 0.0, 0.033, 0.034) for y in (1.03, 1.06, 1.10)], SKIN, neck_weight, 12)

    centre = HEAD + Vector((0.0, 0.135, 0.008))
    head = only("head")
    rings = []
    count = 13
    for k in range(1, count + 1):
        phi = -math.pi / 2 + math.pi * k / (count + 1)
        c, s = math.cos(phi), math.sin(phi)
        jaw = max(0.0, -s)
        # Narrower towards a chin that sits slightly forward.
        rings.append(upright(0.0, centre.y + 0.128 * s, centre.z + 0.016 * jaw - 0.008 * max(0.0, s),
                             0.104 * c * (1.0 - 0.16 * jaw ** 1.5), 0.116 * c))
    b.tube(rings, SKIN, head, 24)

    for side in (1.0, -1.0):
        b.ellipsoid(centre + Vector((side * 0.101, -0.012, -0.012)), Vector((0.012, 0.027, 0.018)), SKIN, head, None, 8, 5)
    b.ellipsoid(centre + Vector((0.0, -0.022, 0.114)), Vector((0.011, 0.016, 0.013)), SKIN, head, None, 8, 5)

    # Hair: a cap tilted so the hairline is high on the brow and low at the nape.
    tilt = Matrix.Rotation(-0.5, 3, "X")
    crown = centre + Vector((0.0, 0.010, -0.004))
    cap = []
    for k in range(10):
        phi = -0.30 + (math.pi / 2 + 0.30) * k / 10
        c, s = math.cos(phi), math.sin(phi)
        cap.append((crown + tilt @ (Y * 0.128 * s), tilt @ (X * 0.109 * c), tilt @ (Z * 0.122 * c)))
    b.tube(cap, DARK, head, 24)


def build_mesh():
    b = Builder()
    build_torso(b)
    build_head(b)
    for side, suffix in ((1.0, "_l"), (-1.0, "_r")):
        build_leg(b, side, suffix)
        build_arm(b, side, suffix)
    return b


def build_armature():
    data = bpy.data.armatures.new("Armature")
    armature = bpy.data.objects.new("Armature", data)
    bpy.context.collection.objects.link(armature)
    bpy.context.view_layer.objects.active = armature
    bpy.ops.object.mode_set(mode="EDIT")

    def bone(name, at, parent=None):
        b = data.edit_bones.new(name)
        b.head = to_blender(at)
        b.tail = to_blender(at + Y * 0.06)
        b.roll = 0.0
        b.parent = parent
        return b

    hips = bone("hips", HIPS)
    spine = bone("spine", SPINE, hips)
    bone("head", HEAD, spine)
    for side, suffix in ((1.0, "_l"), (-1.0, "_r")):
        shoulder = Vector((side * SHOULDER_X, SHOULDER_Y, 0.0))
        upper = bone("upper_arm" + suffix, shoulder, spine)
        bone("forearm" + suffix, shoulder - Y * UPPER_ARM, upper)
        # Leg bones are siblings: the rig places each one directly with IK.
        hip = Vector((side * HIP_X, HIP_Y, 0.0))
        bone("thigh" + suffix, hip, hips)
        bone("shin" + suffix, hip - Y * THIGH, hips)
        bone("foot" + suffix, hip - Y * (THIGH + SHIN), hips)
    bpy.ops.object.mode_set(mode="OBJECT")
    return armature


def linear(c):
    return ((c + 0.055) / 1.055) ** 2.4 if c > 0.04045 else c / 12.92


def main():
    bpy.ops.wm.read_factory_settings(use_empty=True)
    armature = build_armature()
    builder = build_mesh()

    mesh = bpy.data.meshes.new("Boy")
    body = bpy.data.objects.new("Boy", mesh)
    bpy.context.collection.objects.link(body)
    for name, srgb in MATERIALS:
        material = bpy.data.materials.new(name)
        material.use_nodes = True
        color = tuple(linear(c) for c in srgb) + (1.0,)
        shader = material.node_tree.nodes["Principled BSDF"]
        shader.inputs["Base Color"].default_value = color
        shader.inputs["Roughness"].default_value = 1.0
        material.diffuse_color = color
        mesh.materials.append(material)

    groups = {bone.name: body.vertex_groups.new(name=bone.name).index for bone in armature.data.bones}
    layer = builder.bm.verts.layers.deform.verify()
    for vert, weights in zip(builder.bm.verts, builder.weights):
        for name, weight in weights.items():
            if weight > 0.001:
                vert[layer][groups[name]] = weight
    builder.bm.to_mesh(mesh)
    builder.bm.free()

    body.parent = armature
    body.modifiers.new("Armature", "ARMATURE").object = armature

    os.makedirs(os.path.join(ROOT, "models"), exist_ok=True)
    bpy.ops.wm.save_as_mainfile(filepath=os.path.join(ROOT, "tools", "boy.blend"))
    bpy.ops.export_scene.gltf(
        filepath=os.path.join(ROOT, "models", "boy.glb"),
        export_format="GLB",
        export_yup=True,
        export_animations=False,
        export_skins=True,
    )
    print("BUILT verts=%d faces=%d" % (len(mesh.vertices), len(mesh.polygons)))
    if PREVIEW_DIR:
        render_previews(PREVIEW_DIR)


def render_previews(folder):
    scene = bpy.context.scene
    scene.render.engine = "BLENDER_WORKBENCH"
    scene.display.shading.light = "STUDIO"
    scene.display.shading.color_type = "MATERIAL"
    scene.display.shading.show_cavity = True
    scene.render.resolution_x, scene.render.resolution_y = 700, 1000
    scene.world = bpy.data.worlds.new("World")
    scene.world.color = (0.35, 0.38, 0.42)
    camera = bpy.data.objects.new("Camera", bpy.data.cameras.new("Camera"))
    camera.data.type = "ORTHO"
    camera.data.ortho_scale = 1.5
    scene.collection.objects.link(camera)
    scene.camera = camera
    target = Vector((0.0, 0.0, 0.67))
    for name, direction in (("front", (0, -1, 0)), ("side", (1, 0, 0)), ("quarter", (0.7, -0.7, 0.25)), ("back", (-0.5, 0.85, 0.2))):
        offset = Vector(direction).normalized() * 4.0
        camera.location = target + offset
        camera.rotation_euler = (-offset).to_track_quat("-Z", "Y").to_euler()
        scene.render.filepath = os.path.join(folder, "model_" + name + ".png")
        bpy.ops.render.render(write_still=True)


main()
