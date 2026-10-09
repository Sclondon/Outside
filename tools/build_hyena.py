"""Builds the striped hyena and exports it for Godot.

Run from the project root:
    blender --background --python tools/build_hyena.py [-- <preview folder>]

Writes models/hyena.glb and a demade models/hyena_lo.glb, with editable copies
in tools/.

The striped hyena (Hyaena hyaena) is the hyena of Egypt and of the whole north
of Africa. What is modelled follows en.wikipedia.org/wiki/Striped_hyena:

- 60 to 80 cm at the shoulder and 85 to 130 cm long without its tail: this one
  is 77 cm at the withers and a little over a metre.
- "The hind legs are significantly shorter than the forelimbs, thus causing the
  back to slope downwards": high shoulders on long forelegs, a short heavy
  body, and low, crouched hindquarters.
- A thick neck, long but carried low; a massive head with a short blunt muzzle;
  small eyes; very large, broad, pointed ears set high.
- A mane of long hair down the whole of its back from the back of the skull to
  the root of its tail, which it raises when it is roused. It is a mesh of its
  own (`hyena_mane`), in locks: the root of each lock goes with the body, and
  its tip with one of three bones (`crest_neck`, `crest_chest`,
  `crest_pelvis`), which the rig lifts to stand the mane up.
- A short bushy tail that does not reach below its hocks.
- Its coat: a dirty brownish grey, with dark upright stripes down its flanks,
  dark bands across its legs, a black patch on its throat, a dark muzzle and
  ears that are almost black. None of that is a texture. As on the cat, the
  model says where each kind of marking goes in a second set of texture
  coordinates (`lay_marks`) and the fur shader (scripts/fur.gd) draws them
  from the lie of the hair.

It is built as the hounds are, with their tools (tools/build_hound.py), on
their bones, so the rig that moves it reuses their leg solver. Everything is in
Godot space (metres, Y up, facing +Z, +X its left).
"""

import math
import os
import sys

import bmesh
import bpy  # noqa: F401  (Blender must be running this)
from mathutils import Matrix, Vector

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import build_character as kit  # noqa: E402  (shared shape-building and export tools)
import build_hound as dog  # noqa: E402  (the hounds' legs, jaw, teeth, bones, weights and fur)

X, Y, Z = kit.X, kit.Y, kit.Z
V = dog.V
blend = kit.blend
dome = kit.dome

COAT, MOUTH, TEETH, EYE, DARK, MANE = range(6)

HYENA = dog.Breed(
    name="hyena",
    heavy=False,
    materials=[("coat", (0.50, 0.45, 0.36)), ("mouth", (0.36, 0.08, 0.08)), ("teeth", (0.86, 0.82, 0.68)),
               ("eye", (0.16, 0.10, 0.04)), ("ear", (0.07, 0.06, 0.055)), ("mane", (0.10, 0.09, 0.08))],
    body=V(0.0, 0.66, 0.0), chest=V(0.0, 0.70, 0.22), pelvis=V(0.0, 0.60, -0.24),
    # (along the body, centre height, half width, half height): a deep chest under high withers, and a back that falls away to a low rump
    trunk=[(-0.40, 0.575, 0.050, 0.060), (-0.34, 0.560, 0.090, 0.100), (-0.24, 0.560, 0.108, 0.118),
           (-0.12, 0.580, 0.106, 0.118), (0.00, 0.590, 0.112, 0.135), (0.10, 0.590, 0.122, 0.165),
           (0.20, 0.590, 0.128, 0.195), (0.29, 0.610, 0.122, 0.185), (0.35, 0.640, 0.102, 0.150),
           (0.40, 0.670, 0.075, 0.110)],
    # Shoulder, elbow, wrist, paw; hip, stifle, hock, paw (the left legs: the right are their mirror).
    # The forelegs are long and nearly straight; the hind legs shorter, and bent under it.
    fore=[V(0.105, 0.630, 0.300), V(0.105, 0.455, 0.215), V(0.105, 0.175, 0.235), V(0.105, 0.035, 0.255)],
    hind=[V(0.095, 0.545, -0.300), V(0.095, 0.385, -0.210), V(0.095, 0.190, -0.375), V(0.095, 0.035, -0.360)],
    # (how far down the leg, counted in joints; half width; half depth; forward offset)
    fore_shape=[(-0.3, 0.040, 0.068, 0.0), (0.0, 0.046, 0.078, 0.0), (0.5, 0.042, 0.062, 0.0), (1.0, 0.036, 0.048, -0.004),
                (1.25, 0.033, 0.042, 0.0), (1.6, 0.029, 0.035, 0.0), (2.0, 0.029, 0.033, 0.0), (2.5, 0.027, 0.030, 0.0),
                (3.0, 0.030, 0.033, 0.003)],
    hind_shape=[(-0.25, 0.044, 0.085, 0.0), (0.0, 0.050, 0.098, 0.0), (0.45, 0.048, 0.085, 0.0), (0.85, 0.040, 0.058, 0.004),
                (1.0, 0.036, 0.050, 0.004), (1.3, 0.032, 0.045, -0.004), (1.7, 0.026, 0.033, 0.0), (2.0, 0.026, 0.034, -0.004),
                (2.3, 0.024, 0.029, 0.0), (2.7, 0.024, 0.028, 0.0), (3.0, 0.028, 0.032, 0.004)],
    paw=(0.040, 0.055),
    muscle=1.0,
    neck=V(0.0, 0.70, 0.36), head=V(0.0, 0.815, 0.600),
    # (how far up the neck, radius, how far the throat hangs under it)
    neck_shape=[(-0.3, 0.125, 0.0), (0.0, 0.118, 0.006), (0.35, 0.106, 0.008), (0.7, 0.096, 0.006), (1.0, 0.088, 0.0), (1.15, 0.074, 0.0)],
    skull_at=V(0.0, 0.032, 0.052), skull_size=V(0.096, 0.088, 0.112),
    # (along the muzzle from the skull, height, half width, half height): short, deep and blunt
    muzzle=[(0.06, -0.010, 0.070, 0.062), (0.12, -0.020, 0.062, 0.058), (0.19, -0.026, 0.056, 0.053), (0.235, -0.028, 0.051, 0.048)],
    nose=(V(0.0, -0.010, 0.258), V(0.030, 0.025, 0.020)),
    jaw_at=V(0.0, -0.040, 0.000),
    jaw_shape=[(-0.01, -0.064, 0.058, 0.026), (0.10, -0.074, 0.051, 0.022), (0.205, -0.078, 0.041, 0.018)],
    # The line the teeth meet on, the length of the mouth, and its half width at the fangs and at the back
    mouth=(-0.074, 0.228, 0.033, 0.044),
    eye=(V(0.058, 0.026, 0.084), 0.010),
    # Each ear: where it roots, the joint part way along it, and its end
    ear_at=[V(0.066, 0.050, -0.034), V(0.096, 0.140, -0.046), V(0.114, 0.232, -0.044)],
    tail_root=V(0.0, 0.625, -0.415),
    tail_at=[(0.0, 0.0, 0.0), (0.0, -0.07, -0.065), (0.0, -0.15, -0.105), (0.0, -0.23, -0.125), (0.0, -0.30, -0.12)],
    tail_shape=[0.034, 0.040, 0.050, 0.052, 0.044, 0.022],
)

# How much broader its ears are than the pharaoh hound's, whose shape they are.
EAR_SCALE = 1.5
# The mane: how far apart its locks are along the back (m), how long they are at the withers, and how far up from lying flat they lie.
LOCK_GAP = 0.026
LOCK_LENGTH = 0.14
LOCK_LEAN = 0.42


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


def neck_frame(breed):
    """The neck: where it starts and ends, and which way is up off the top of it."""
    base, top = breed.neck, breed.head + V(0.0, -0.01, -0.01)
    along = (top - base).normalized()
    up = along.cross(X).normalized()
    return base, top, (up if up.y > 0.0 else -up)


def neck_radius(breed, t):
    shape = breed.neck_shape
    for (ta, ra, _), (tc, rc, _) in zip(shape, shape[1:]):
        if t <= tc:
            return ra + (rc - ra) * min(max((t - ta) / (tc - ta), 0.0), 1.0)
    return shape[-1][1]


# Where the neck's top line gives way to the back's.
WITHERS_Z = 0.37


def top_line(breed, z):
    """The top of its neck and its back at `z` along it: the place, and which way is out of it there."""
    base, top, up = neck_frame(breed)
    if z > WITHERS_Z:
        t = (z - base.z) / (top.z - base.z)
        # (as far up the neck as the back of the skull, and no further)
        t = min(t, 1.12)
        return base.lerp(top, t) + up * neck_radius(breed, t) * 1.2, up
    y, _rx, ry = trunk_at(breed, z)
    return V(0.0, y + ry, z), Y.copy()


def on_tail(breed, p):
    off, along = dog.chain_param(p, breed.tail)
    return p.z < breed.tail[0].z + 0.01 and off < 0.075, along


def lay_marks(breed, bm, plain=None):
    """Says where the coat is marked, in a second set of texture coordinates which
    the fur shader reads: x is what kind of marking (-1 none, 0 the upright bars
    of its flanks, 1 the bands across its legs, 2 all dark), y how far it is
    belly, which is paler. `plain` gives the whole part one value instead."""
    layer = bm.loops.layers.uv.get("marks") or bm.loops.layers.uv.new("marks")
    base, top, _up = neck_frame(breed)
    last = len(breed.tail) - 1
    for face in bm.faces:
        for loop in face.loops:
            if plain is not None:
                loop[layer].uv = plain
                continue
            p = kit.from_blender(loop.vert.co)
            tail, along = on_tail(breed, p)
            if tail:
                # Barred like the body where it leaves it, and dark at the end
                loop[layer].uv = (2.0 * blend(last - 2.2, last - 1.2, along), 0.0)
                continue
            leg = dog.leg_share(breed, p)[1]
            cy, rx, ry = trunk_at(breed, p.z)
            angle = abs(math.atan2(p.x / max(rx, 0.001), (p.y - cy) / max(ry, 0.001)))
            belly = blend(2.3, 2.8, angle) * (1.0 - leg)
            # Bars on its flanks, bands on its legs, nothing on its paws or under it
            kind = leg - (1.0 + leg) * max(belly, blend(0.07, 0.04, p.y))
            if p.z > base.z - 0.03:
                t = (p - base).dot((top - base).normalized()) / (top - base).length
                centre = base.lerp(top, min(max(t, 0.0), 1.3))
                # The bars fade out up its neck; its face is plain
                kind = min(kind, -blend(0.25, 0.7, t))
                belly *= blend(0.4, 0.0, t)
                # The black patch on its throat, with a pale band between it and its chin
                throat = blend(centre.y - 0.03, centre.y - 0.06, p.y) * blend(0.38, 0.52, t) * blend(0.95, 0.80, t) * blend(0.085, 0.06, abs(p.x))
                kind = kind + (2.0 - kind) * throat
                # Its muzzle, dark to the eyes
                muzzle = blend(breed.skull.z + 0.07, breed.skull.z + 0.12, p.z)
                kind = kind + (2.0 - kind) * muzzle
            loop[layer].uv = (kind, belly)


def marked(mesh, breed, plain=None):
    bm = bmesh.new()
    bm.from_mesh(mesh)
    lay_marks(breed, bm, plain)
    bm.to_mesh(mesh)
    bm.free()
    return mesh


def coat(breed):
    def shapes(b):
        low = kit.LOW
        rings = [kit.lengthwise(*ring) for ring in breed.trunk]
        b.tube(dome(rings[0], -Z, 0.05)[::-1] + rings + dome(rings[-1], Z, 0.05), 18)
        # The withers, standing up over the shoulders; the point of the chest; the muscle over each shoulder and haunch
        b.ellipsoid(V(0.0, 0.755, 0.25), V(0.075, 0.050, 0.150))
        b.ellipsoid(V(0.0, breed.fore[0].y + 0.02, 0.385), V(0.085, 0.105, 0.070))
        for side in (() if low else (1.0, -1.0)):
            arm = breed.fore[0].lerp(breed.fore[1], 0.3)
            b.ellipsoid(V(side * (arm.x + 0.004), arm.y + 0.04, arm.z - 0.01), V(0.040, 0.130, 0.085), Matrix.Rotation(0.40, 3, "X"))
            thigh = breed.hind[0].lerp(breed.hind[1], 0.3)
            b.ellipsoid(V(side * thigh.x, thigh.y + 0.02, thigh.z + 0.01), V(0.050, 0.115, 0.105), Matrix.Rotation(-0.45, 3, "X"))

        # The neck: as thick as its head, and thicker where it leaves the shoulders
        base, top, up = neck_frame(breed)
        b.tube([(base.lerp(top, t) - up * sag, X * r, up * (r * 1.2)) for t, r, sag in breed.neck_shape], 14)

        skull = breed.skull
        size = breed.skull_size
        b.ellipsoid(skull, size, None, 16, 9)
        b.ellipsoid(skull + V(0.0, size.y * 0.5, size.z * 0.5), V(size.x * 0.74, size.y * 0.40, size.z * 0.42))  # a high forehead
        b.ellipsoid(skull + V(0.0, size.y * 0.78, -size.z * 0.45), V(0.030, 0.030, 0.060))  # the crest of bone its jaw muscles hang from
        for side in (1.0, -1.0):
            # Those muscles, and the cheekbones they pass under: what makes its head so broad
            b.ellipsoid(skull + V(side * size.x * 0.66, -0.026, 0.014), V(0.036, 0.052, 0.066), None, 10, 6)
            b.ellipsoid(skull + V(side * 0.044, -0.034, 0.160), V(0.022, 0.032, 0.075), None, 8, 5)  # the lips
        # The muzzle. The lower jaw is a part of its own (`jaw`).
        muzzle = [(skull + V(0.0, y, z), X * rx, Y * ry) for z, y, rx, ry in breed.muzzle]
        b.tube([(skull + V(0.0, 0.0, 0.0), X * size.x * 0.8, Y * size.y * 0.8)] + muzzle + dome(muzzle[-1], Z, muzzle[-1][1].x * 0.5, 3), 14)
        b.ellipsoid(skull + breed.nose[0], breed.nose[1], None, 8, 5)

        b.strand([breed.tail_root + V(0.0, 0.03, 0.06)] + breed.tail, breed.tail_shape, 10)

        for suffix, joints in breed.legs.items():
            fore = suffix[1] == "f"
            dog.limb(b, joints, breed.fore_shape if fore else breed.hind_shape)
            width, length = breed.paw
            paw = joints[3]
            if not low:
                # The point of the elbow, or of the hock, standing out behind
                knob = joints[1] + V(0.0, 0.014, -0.036) if fore else joints[2] + V(0.0, 0.022, -0.026)
                b.ellipsoid(knob, V(width * 0.62, 0.030, 0.026), None, 8, 5)
            b.ellipsoid(paw + V(0.0, -0.010, length * 0.5), V(width, 0.030, length), None, 10, 6)
            for toe in (() if low else (-1.5, -0.5, 0.5, 1.5)):
                b.ellipsoid(paw + V(toe * width * 0.42, -0.016, length * 1.22 - abs(toe) * length * 0.16), V(width * 0.27, 0.019, 0.024), None, 8, 5)
        return marked(dog.furred(breed, b, (0.005, 5, 12000)), breed)
    return shapes


def jaw(breed):
    def shapes(b):
        # (dark, as its muzzle is)
        return marked(dog.jaw(breed)(b), breed, (2.0, 0.0))
    return shapes


def ear_frame(side):
    """Across an ear, and through it: the open side is to the front and a little out."""
    return V(side * 0.90, 0.0, -0.42).normalized(), V(side * 0.42, 0.0, 0.90).normalized()


def ears(breed):
    def shapes(b):
        # Very large, broad at the base and pointed
        for side in (1.0, -1.0):
            wide, face = ear_frame(side)
            rings = []
            for t, half, thick in ((0.0, 0.028, 0.014), (0.12, 0.040, 0.011), (0.35, 0.043, 0.008), (0.60, 0.037, 0.006),
                                   (0.82, 0.023, 0.005), (0.95, 0.011, 0.004), (1.0, 0.005, 0.003)):
                rings.append((dog.ear_curve(breed, t, side), wide * half * EAR_SCALE, face * thick))
            b.tube(dome(rings[0], -Y, 0.008, 2)[::-1] + rings, 10)
        dog.lay_fur(breed, b.bm, True)
        # (almost black)
        lay_marks(breed, b.bm, (2.0, 0.0))
    return shapes


def ear_linings(breed):
    def shapes(b):
        # The bare inside of each
        for side in (1.0, -1.0):
            wide, face = ear_frame(side)
            rings = []
            for t, half in ((0.10, 0.014), (0.22, 0.029), (0.40, 0.032), (0.60, 0.027), (0.80, 0.016), (0.92, 0.005)):
                rings.append((dog.ear_curve(breed, t, side) + face * 0.0045, wide * half * EAR_SCALE, face * 0.0035))
            b.tube(rings, 8)
    return shapes


def locks(breed):
    """Each lock of the mane: (its root, which way is out of the body there, which way it lies, how long it is)."""
    base, top, _up = neck_frame(breed)
    listed = []
    z = top.z + 0.02
    index = 0
    while z > breed.tail_root.z + 0.03:
        root, out = top_line(breed, z)
        behind, _ = top_line(breed, z - 0.02)
        back = (behind - root).normalized()
        # Longest over the shoulders, shorter towards the skull and towards the tail
        length = LOCK_LENGTH * (0.55 + 0.45 * blend(top.z + 0.02, top.z - 0.14, z)) * (0.6 + 0.4 * blend(breed.tail_root.z, -0.05, z))
        lean = LOCK_LEAN + 0.10 * math.sin(index * 2.4)
        aside = 0.011 * (1.0 if index % 2 == 0 else -1.0)
        listed.append((root + X * aside, out, back, (back * math.cos(lean) + out * math.sin(lean) + X * aside * 1.2).normalized(), length * (1.0 + 0.15 * math.sin(index * 1.7))))
        z -= LOCK_GAP * (2.0 if kit.LOW else 1.0)
        index += 1
    return listed


def mane(breed):
    def shapes(b):
        # Each lock is a blade: thin across the back, broad along it, so that one overlaps the next and the row of them is a crest
        for root, out, back, lies, length in locks(breed):
            foot = root - out * 0.025
            tip = root + lies * length
            broad = 0.050 if kit.LOW else 0.036
            b.tube([(foot.lerp(tip, t), X * 0.013 * (1.0 - t * 0.9), back * broad * (1.0 - t) ** 0.8) for t in (0.0, 0.3, 0.62, 0.86, 0.98)], 6)
    return shapes


def weights(breed):
    of_hound = dog.weights(breed)
    base, top, up = neck_frame(breed)

    def weigh(part, p):
        if part != "mane":
            return of_hound(part, p)
        # A lock's root goes with the body under it, and its tip with the bone that raises it.
        root, out = top_line(breed, p.z)
        tip = blend(0.012, 0.055, (p - root).dot(out))
        made = {bone: weight * (1.0 - tip) for bone, weight in of_hound("coat", root - out * 0.02).items()}
        fore = blend(-0.10, 0.02, p.z)
        neck = blend(WITHERS_Z - 0.06, WITHERS_Z + 0.06, p.z)
        made["crest_pelvis"] = tip * (1.0 - fore)
        made["crest_chest"] = tip * fore * (1.0 - neck)
        made["crest_neck"] = tip * fore * neck
        return made
    return weigh


def bones(breed):
    listed = dog.bones(breed)
    # What raises the mane: one over the neck, one over the withers, one over the loin
    listed.append(("crest_neck", top_line(breed, 0.50)[0], "neck"))
    listed.append(("crest_chest", top_line(breed, 0.20)[0], "chest"))
    listed.append(("crest_pelvis", top_line(breed, -0.22)[0], "pelvis"))
    return listed


def parts(breed):
    # The coat and the jaw fuse themselves (see `dog.furred`), so nothing here asks for it.
    # The same list builds the demade hyena.
    return [
        ("coat", COAT, coat(breed), None), ("jaw", COAT, jaw(breed), None), ("ears", COAT, ears(breed), None),
        ("palate", MOUTH, dog.palate(breed), None), ("tongue", MOUTH, dog.tongue(breed), None),
        ("fangs", TEETH, dog.fangs(breed), None), ("teeth", TEETH, dog.teeth(breed), None), ("eyes", EYE, dog.eyes(breed), None),
        ("linings", DARK, ear_linings(breed), None), ("mane", MANE, mane(breed), None),
    ]


def previews(folder, name):
    """More renders of the rest pose than the kit makes: from in front and above, and the head close to."""
    scene = bpy.context.scene
    camera = scene.camera
    head = kit.to_blender(HYENA.skull + V(0.0, 0.03, 0.08))
    for view, direction, target, frame in (("front", (0.25, -1, 0.1), (0.0, 0.0, 0.6), 1.5), ("top", (0.2, -0.2, 1), (0.0, 0.0, 0.5), 1.5),
                                           ("head", (0.8, -0.6, 0.15), head, 0.7), ("back", (0.4, 1, 0.3), (0.0, 0.0, 0.6), 1.5)):
        offset = Vector(direction).normalized() * 4.0
        camera.data.ortho_scale = frame
        camera.location = Vector(target) + offset
        camera.rotation_euler = (-offset).to_track_quat("-Z", "Y").to_euler()
        scene.render.filepath = os.path.join(folder, "%s_%s.png" % (name, view))
        bpy.ops.render.render(write_still=True)


if __name__ == "__main__":
    for low in (False, True):
        kit.LOW = low
        name = HYENA.name + ("_lo" if low else "")
        kit.export(name, bones(HYENA), parts(HYENA), weights(HYENA), HYENA.materials, False, ("mane",))
        if kit.PREVIEW_DIR and (not kit.ONLY or name in kit.ONLY):
            previews(kit.PREVIEW_DIR, name)
