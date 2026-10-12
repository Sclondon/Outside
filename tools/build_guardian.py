"""Builds the gate guardians and the leaf of the Book of the Dead, and exports them for Godot.

Run from the project root:
    blender --background --python tools/build_guardian.py
then, so that Godot takes up the new model:
    godot --headless --path . --import

Writes models/guardian.glb, and tools/guardian.blend to look at and to change by hand.

A guardian is a keeper of a gate of the underworld: a demon seated on a block on a plinth,
wrapped like a mummy or in a kilt, with the head of a beast and a long knife upright in each
fist. It has no bones. It is separate things, each named for what it is, which
scripts/gate_guardian.gd moves (scripts/guardian_mesh.gd reads them from the model):

    guardian_wrapped       (nothing to see: it holds the figure in wrappings together)
      plinth               the slab of stone under it
      seat                 the block it sits on, the back of it, and the line of gold
      feet_wrapped         its feet, which stay where they are
      thighs_wrapped       both thighs, lying along the thigh from the hip (its origin)
      shins_wrapped        both shins, lying along the shin from the knee (its origin)
      trunk_wrapped        from the hips (its origin) up: chest, shoulders, neck, collar
        wig                the cloth down its back and on its shoulders (not every head has it)
        neck               (nothing to see: where a head is put)
        arm_wrapped_left   an arm bent at the elbow; its origin is the shoulder
          knife_left       the knife; its origin is the fist it turns in
        arm_wrapped_right, knife_right
    guardian_kilt          the same figure in a kilt, standing beside the first:
      feet_kilt, thighs_kilt, shins_kilt, trunk_kilt, arm_kilt_left, arm_kilt_right
      (and plinth_again, seat_again, wig_again, neck_again, knife_left_again,
      knife_right_again: the first figure's, shown a second time. The game does not read
      anything whose name ends in _again.)
    head_crocodile, head_snake, head_vulture, head_hippopotamus, head_ram, head_jackal,
    head_hare, head_lion, head_bull
                           the nine heads, each facing forward with the top of the neck at
                           its origin, a little over life size. The jackal's is on the first
                           figure and the bull's on the second; the rest stand in a row.
    great_knife            one of the two great knives that bar a gateway; its origin is the
                           foot of the gateway's side, where it turns. (great_knife_again is
                           the other, crossed over it.) The game makes it as long as its
                           gateway needs by making all of it bigger or smaller.
    leaf_open, leaf_rolled the leaf of papyrus, lying open and rolled up and tied

Where each thing's origin is put is where the game hinges it, so moving an origin moves the
joint. The colours are materials, named plainly; the game takes each one's colour from here,
so changing a material's Base Color and exporting again changes the guardian. Some names
mean something to the game:

    stone      the plinth: drawn as the game's sandstone, in this colour
    gold       shines as gold does            blade     shines the same, in bronze
    eye        is lit from within (it shows in the dark)
    hide       the neck, and the fists of the wrapped figure: the game paints these in the
               colour of the head's own hide (the material of the head whose name ends in
               _hide), whatever colour this is here
    wig        a head with anything painted in this gets the wig down its back
    papyrus    the leaf: the game writes on it       tie    the cord round the rolled leaf

(To export by hand: File, Export, glTF 2.0, to models/guardian.glb, with +Y up.)

Everything below is written in the game's own directions (x to its left, y up, z the way it
faces, in metres) and turned to Blender's as it is made.
"""

import bpy
import bmesh
import math
import os
from mathutils import Matrix, Vector

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))

# The colours, as they are seen (sRGB).
COLOURS = {
    "stone": (0.462, 0.399, 0.301),
    "seat": (0.16, 0.34, 0.32),
    "gold": (0.96, 0.7, 0.2),
    "blade": (0.78, 0.6, 0.34),
    "hilt": (0.14, 0.1, 0.08),
    "linen": (0.9, 0.86, 0.74),
    "linen_band": (0.63, 0.602, 0.518),
    "skin": (0.62, 0.34, 0.2),
    "hide": (0.1, 0.1, 0.12),
    "wig": (0.13, 0.22, 0.5),
    "eye": (1.0, 0.78, 0.2),
    "eye_rim": (0.06, 0.05, 0.05),
    "tooth": (0.93, 0.9, 0.8),
    "papyrus": (0.86, 0.77, 0.55),
    "tie": (0.62, 0.16, 0.1),
    # The heads: each has its hide, and what else it is painted in.
    "crocodile_hide": (0.27, 0.42, 0.24),
    "crocodile_belly": (0.66, 0.66, 0.38),
    "crocodile_scale": (0.17, 0.28, 0.16),
    "snake_hide": (0.52, 0.5, 0.2),
    "snake_belly": (0.86, 0.78, 0.44),
    "snake_band": (0.29, 0.27, 0.11),
    "snake_tongue": (0.7, 0.12, 0.1),
    "vulture_hide": (0.86, 0.74, 0.62),
    "vulture_ruff": (0.93, 0.9, 0.8),
    "vulture_face": (0.84, 0.64, 0.26),
    "vulture_beak": (0.24, 0.21, 0.19),
    "hippopotamus_hide": (0.42, 0.4, 0.5),
    "hippopotamus_jowl": (0.64, 0.5, 0.54),
    "hippopotamus_mouth": (0.5, 0.15, 0.14),
    "hippopotamus_nostril": (0.2, 0.18, 0.24),
    "ram_hide": (0.82, 0.74, 0.58),
    "ram_horn": (0.56, 0.45, 0.28),
    "ram_horn_ridge": (0.4, 0.31, 0.19),
    "ram_nose": (0.4, 0.34, 0.28),
    "jackal_hide": (0.1, 0.1, 0.12),
    "jackal_ear": (0.55, 0.4, 0.16),
    "jackal_nose": (0.03, 0.03, 0.035),
    "hare_hide": (0.72, 0.58, 0.38),
    "hare_ear": (0.86, 0.66, 0.58),
    "hare_cheek": (0.88, 0.79, 0.62),
    "hare_nose": (0.42, 0.28, 0.26),
    "lion_hide": (0.78, 0.58, 0.26),
    "lion_mane": (0.43, 0.32, 0.14),
    "lion_muzzle": (0.92, 0.82, 0.6),
    "lion_nose": (0.2, 0.13, 0.1),
    "bull_hide": (0.2, 0.14, 0.12),
    "bull_horn": (0.93, 0.9, 0.8),
    "bull_muzzle": (0.9, 0.86, 0.78),
    "bull_nostril": (0.1, 0.07, 0.06),
    "bull_ear": (0.5, 0.36, 0.32),
}

HEADS = ["crocodile", "snake", "vulture", "hippopotamus", "ram", "jackal", "hare", "lion", "bull"]

# Where the things are (in the game's directions; each within the thing it hangs from).
HIP = Vector((0.0, 0.87, -0.15))     # seated (the game lifts it as it rises)
ANKLE = Vector((0.0, 0.33, 0.36))
THIGH = 0.48
SHIN = 0.54
NECK = (0.0, 0.68, 0.0)
SHOULDER = (0.275, 0.49, 0.0)
FIST = (0.0, -0.36, 0.43)
HEAD_SIZE = 1.2
# The gateway the great knives are modelled for: how wide and tall, and where it is from the figure.
GATE_WIDE = 2.2
GATE_TALL = 2.6
GATE_AT = (1.9, 0.0, -0.75)
KILT_AT = (-2.2, 0.0, 0.0)

TO_BLENDER = Matrix(((1.0, 0.0, 0.0), (0.0, 0.0, -1.0), (0.0, 1.0, 0.0)))


def to_blender(p):
    return (p[0], -p[2], p[1])


def about_y(angle):
    c, s = math.cos(angle), math.sin(angle)
    return Matrix(((c, 0.0, s), (0.0, 1.0, 0.0), (-s, 0.0, c)))


def about_x(angle):
    c, s = math.cos(angle), math.sin(angle)
    return Matrix(((1.0, 0.0, 0.0), (0.0, c, -s), (0.0, s, c)))


def about_z(angle):
    c, s = math.cos(angle), math.sin(angle)
    return Matrix(((c, -s, 0.0), (s, c, 0.0), (0.0, 0.0, 1.0)))


class Shape:
    """One thing being modelled: its points, and its faces (each a list of points, a material and whether it is rounded)."""

    def __init__(self):
        self.points = []
        self.faces = []

    def point(self, p):
        self.points.append(Vector(p))
        return len(self.points) - 1

    def face(self, corners, material, smooth=False, uvs=None):
        if len(set(corners)) >= 3:
            self.faces.append((corners, material, smooth, uvs))

    def tube(self, material, a, b, ra, rb, sides=7, flat=1.0, smooth=True):
        """A round limb from a to b, ra thick at one end and rb at the other (0 for a point), flat times as wide as deep."""
        a, b = Vector(a), Vector(b)
        along = (b - a).normalized()
        across = Vector((1.0, 0.0, 0.0)) if abs(along.x) < 0.9 else Vector((0.0, 0.0, 1.0))
        side = (across - along * along.dot(across)).normalized()
        other = along.cross(side).normalized()
        side = side * flat
        ends = []
        for at, r in ((a, ra), (b, rb)):
            if r > 0.0:
                ends.append([self.point(at + (side * math.cos(math.tau * n / sides) + other * math.sin(math.tau * n / sides)) * r) for n in range(sides)])
            else:
                ends.append([self.point(at)] * sides)
        for n in range(sides):
            m = (n + 1) % sides
            self.face([ends[0][n], ends[1][n], ends[1][m], ends[0][m]] if ra > 0.0 and rb > 0.0 else
                      ([ends[0][n], ends[1][n], ends[0][m]] if rb <= 0.0 else [ends[0][n], ends[1][n], ends[1][m]]), material, smooth)
        if ra > 0.0:
            self.face(ends[0], material)
        if rb > 0.0:
            self.face(ends[1], material)

    def ball(self, material, at, radii, turn=None, sides=8, rings=5):
        """A ball, or an egg: radii each way, turned by turn."""
        at = Vector(at)
        if isinstance(radii, (int, float)):
            radii = (radii, radii, radii)

        def put(unit):
            p = Vector((unit[0] * radii[0], unit[1] * radii[1], unit[2] * radii[2]))
            return self.point(at + (turn @ p if turn else p))
        rows = [[put((0.0, 1.0, 0.0))] * sides]
        for ring in range(1, rings):
            down = math.pi * ring / rings
            rows.append([put((math.sin(down) * math.cos(math.tau * n / sides), math.cos(down), math.sin(down) * math.sin(math.tau * n / sides))) for n in range(sides)])
        rows.append([put((0.0, -1.0, 0.0))] * sides)
        for ring in range(rings):
            for n in range(sides):
                m = (n + 1) % sides
                self.face([rows[ring][n], rows[ring][m], rows[ring + 1][m], rows[ring + 1][n]], material, True)

    def box(self, material, at, size, turn=None):
        """A box, size each way, its middle at at."""
        at = Vector(at)
        corners = {}
        for x in (-1, 1):
            for y in (-1, 1):
                for z in (-1, 1):
                    p = Vector((x * size[0] * 0.5, y * size[1] * 0.5, z * size[2] * 0.5))
                    corners[(x, y, z)] = self.point(at + (turn @ p if turn else p))
        for axis in range(3):
            for way in (-1, 1):
                ring = []
                for u, v in ((-1, -1), (1, -1), (1, 1), (-1, 1)):
                    key = [0, 0, 0]
                    key[axis] = way
                    key[(axis + 1) % 3] = u
                    key[(axis + 2) % 3] = v
                    ring.append(corners[tuple(key)])
                self.face(ring, material)

    def slab(self, material, outline, thick, turn=None, at=(0.0, 0.0, 0.0)):
        """A flat piece cut to an outline (drawn in x and y), thick through (along z), then turned and put at at."""
        at = Vector(at)
        sides = []
        for z in (thick * 0.5, -thick * 0.5):
            ring = []
            for x, y in outline:
                p = Vector((x, y, z))
                ring.append(self.point(at + (turn @ p if turn else p)))
            sides.append(ring)
        self.face(sides[0], material)
        self.face(sides[1], material)
        for n in range(len(outline)):
            m = (n + 1) % len(outline)
            self.face([sides[0][n], sides[0][m], sides[1][m], sides[1][n]], material)

    def path(self, material, points, radii, sides=6, smooth=True):
        """Something long that bends (a horn, a neck, an ear): through points, radii thick at each (a number, or
        (across, deep); 0 for a point). material is a name, or a function of which stretch of it."""
        points = [Vector(p) for p in points]
        rings = []
        side = None
        for i, here in enumerate(points):
            along = (points[min(i + 1, len(points) - 1)] - points[max(i - 1, 0)]).normalized()
            if side is None:
                across = Vector((1.0, 0.0, 0.0)) if abs(along.x) < 0.9 else Vector((0.0, 0.0, 1.0))
                side = across
            side = (side - along * along.dot(side)).normalized()
            other = along.cross(side).normalized()
            r = radii[i]
            wide, deep = r if isinstance(r, tuple) else (r, r)
            if wide <= 0.0:
                rings.append([self.point(here)] * sides)
            else:
                rings.append([self.point(here + side * math.cos(math.tau * n / sides) * wide + other * math.sin(math.tau * n / sides) * deep) for n in range(sides)])
        for i in range(len(points) - 1):
            name = material(i) if callable(material) else material
            for n in range(sides):
                m = (n + 1) % sides
                self.face([rings[i][n], rings[i + 1][n], rings[i + 1][m], rings[i][m]], name, smooth)
        for ring, i in ((rings[0], 0), (rings[-1], len(points) - 2)):
            if len(set(ring)) > 2:
                self.face(ring, material(i) if callable(material) else material, False)

    def loft(self, material, sections, around=12, upright=False, squash=1.0):
        """A rounded body drawn as a row of sections along z: each (z, height of its middle, half its width, how far
        it rises above the middle, how far it hangs below it[, how square: 2 is round]). upright: the row runs
        up y instead, and "above" is forward. material is a name, or a function of (which stretch, which face
        round it, how many round): faces are counted from its left side, over the top."""
        rings = []
        for section in sections:
            along, off, wide, up, down = section[:5]
            power = section[5] if len(section) > 5 else 2.0
            ring = []
            for k in range(around):
                turn = math.tau * k / around
                c, s = math.cos(turn), math.sin(turn)
                a = wide * squash * math.copysign(abs(c) ** (2.0 / power), c)
                b = off + (up if s >= 0.0 else down) * math.copysign(abs(s) ** (2.0 / power), s)
                ring.append(self.point((a, along, b) if upright else (a, b, along)))
            rings.append(ring)
        for i in range(len(sections) - 1):
            for k in range(around):
                m = (k + 1) % around
                name = material(i, k, around) if callable(material) else material
                self.face([rings[i][k], rings[i + 1][k], rings[i + 1][m], rings[i][m]], name, True)
        for ring, i in ((rings[0], 0), (rings[-1], len(sections) - 2)):
            middle = sum((self.points[p] for p in ring), Vector()) / around
            hub = self.point(middle)
            for k in range(around):
                name = material(i, k, around) if callable(material) else material
                self.face([ring[k], ring[(k + 1) % around], hub], name, True)

    def scaled(self, by):
        self.points = [p * by for p in self.points]
        return self


def on_loft(sections, z, degrees):
    """A point on the outside of a loft: z along it, and how far round from its left side towards the top."""
    for i in range(len(sections) - 1):
        one, two = sections[i], sections[i + 1]
        if one[0] <= z <= two[0]:
            t = (z - one[0]) / (two[0] - one[0])
            off, wide, up, down = (one[n] + (two[n] - one[n]) * t for n in range(1, 5))
            turn = math.radians(degrees)
            s = math.sin(turn)
            return Vector((wide * math.cos(turn), off + (up if s >= 0.0 else down) * s, z))
    raise ValueError("no such place on the loft")


def finer(sections, parts):
    """The same sections with more between them, so that it can be painted in narrower bands."""
    made = []
    for i in range(len(sections) - 1):
        for n in range(parts):
            t = n / parts
            # (eased, so that what bulges still bulges)
            made.append(tuple(sections[i][k] + (sections[i + 1][k] - sections[i][k]) * t for k in range(5)))
    made.append(tuple(sections[-1][:5]))
    return made


def below(top, under, cut=-0.4):
    """Paints a loft in two: under below, top above."""
    return lambda i, k, around: under if math.sin(math.tau * (k + 0.5) / around) < cut else top


def flip(p, side):
    return Vector((p[0] * side, p[1], p[2]))


def eyes(s, at, size):
    """Its two eyes, lit, each in a dark rim: at is the one on its left."""
    for side in (1.0, -1.0):
        here = flip(at, side)
        s.ball("eye_rim", here + Vector((-side * size * 0.55, 0.0, -size * 0.25)), size * 1.45, None, 8, 4)
        s.ball("eye", here, size, None, 8, 4)


def wig(s, wide=0.15, high=0.16, at=(0.0, 0.12, -0.07)):
    """The cloth of the wig, over the back of the head."""
    s.ball("wig", at, (wide, high, 0.13), None, 10, 6)


# --- The heads: each faces +z, with the top of the neck at its origin ---

def head_jackal():
    """A jackal's, as Anubis has: a long fine muzzle, and tall ears standing straight up."""
    s = Shape()
    skull = [(-0.135, 0.13, 0.03, 0.03, 0.03), (-0.09, 0.135, 0.095, 0.1, 0.1), (-0.01, 0.14, 0.118, 0.118, 0.12), (0.07, 0.14, 0.105, 0.1, 0.115),
             (0.13, 0.125, 0.074, 0.066, 0.085), (0.21, 0.105, 0.052, 0.042, 0.056), (0.32, 0.086, 0.041, 0.033, 0.04), (0.41, 0.071, 0.032, 0.027, 0.03),
             (0.445, 0.066, 0.014, 0.012, 0.012)]
    s.loft("jackal_hide", skull)
    s.ball("jackal_nose", (0.0, 0.076, 0.447), (0.025, 0.021, 0.02), None, 6, 4)
    for side in (1.0, -1.0):
        # (an ear: narrow where it grows, widest a third of the way up, and a point)
        back = [(0.07, 0.19, -0.03), (0.082, 0.3, -0.042), (0.094, 0.42, -0.054), (0.105, 0.58, -0.07)]
        s.path("jackal_hide", [flip(p, side) for p in back], [(0.042, 0.03), (0.06, 0.03), (0.046, 0.022), 0.0], 6)
        front = [(0.072, 0.23, -0.02), (0.083, 0.31, -0.026), (0.093, 0.41, -0.04), (0.102, 0.52, -0.056)]
        s.path("jackal_ear", [flip(p, side) for p in front], [(0.02, 0.012), (0.036, 0.014), (0.027, 0.01), 0.0], 5)
    eyes(s, on_loft(skull, 0.1, 36.0), 0.024)
    wig(s)
    return s


def head_crocodile():
    """A crocodile's, as Sobek has: a long flat snout swelling at its end, its eyes carried high, its teeth showing."""
    s = Shape()
    skull = [(-0.14, 0.11, 0.03, 0.03, 0.03), (-0.09, 0.11, 0.12, 0.09, 0.09), (0.0, 0.115, 0.145, 0.1, 0.105), (0.08, 0.11, 0.13, 0.085, 0.1),
             (0.16, 0.095, 0.098, 0.05, 0.085), (0.3, 0.085, 0.08, 0.038, 0.07), (0.44, 0.08, 0.072, 0.034, 0.06), (0.53, 0.08, 0.086, 0.04, 0.055),
             (0.6, 0.078, 0.074, 0.034, 0.045), (0.635, 0.075, 0.03, 0.015, 0.02)]
    s.loft(below("crocodile_hide", "crocodile_belly", -0.55), skull)
    for side in (1.0, -1.0):
        s.ball("crocodile_hide", (0.078 * side, 0.2, 0.055), (0.046, 0.052, 0.058), None, 7, 4)
        s.ball("crocodile_hide", (0.032 * side, 0.118, 0.585), (0.024, 0.017, 0.027), None, 6, 3)
        # (teeth, down each side of the jaw, and smaller ones up between them)
        for n in range(7):
            z = 0.2 + n * 0.062
            root = on_loft(skull, z, -18.0)
            s.tube("tooth", flip(root + Vector((-0.004, 0.012, 0.0)), side), flip(root + Vector((0.004, -0.05, 0.0)), side), 0.015, 0.0, 4)
            if n < 6:
                low = on_loft(skull, z + 0.031, -52.0)
                s.tube("tooth", flip(low + Vector((0.0, -0.01, 0.0)), side), flip(low + Vector((0.012, 0.034, 0.0)), side), 0.011, 0.0, 4)
        # (and a row of scales down the snout)
        for n in range(4):
            s.ball("crocodile_scale", (0.03 * side, 0.128 - n * 0.003, 0.2 + n * 0.085), (0.02, 0.011, 0.03), None, 5, 3)
    eyes(s, Vector((0.102, 0.218, 0.085)), 0.024)
    wig(s, 0.165, 0.17)
    return s


def head_snake():
    """A cobra risen to strike, as the uraeus is drawn: the hood spread wide and banded down its front, the head small at the top of it."""
    s = Shape()
    s.path("snake_hide", [(0.0, -0.03, 0.0), (0.0, 0.12, -0.012), (0.0, 0.26, -0.02), (0.0, 0.36, 0.0), (0.0, 0.42, 0.05)], [0.07, 0.066, 0.062, 0.058, 0.05], 8)
    hood = finer([(0.01, -0.012, 0.07, 0.05, 0.05), (0.09, -0.02, 0.16, 0.052, 0.042), (0.2, -0.03, 0.235, 0.048, 0.036), (0.29, -0.03, 0.225, 0.044, 0.036),
                  (0.36, -0.02, 0.15, 0.042, 0.04), (0.425, 0.0, 0.06, 0.04, 0.04)], 2)

    def painted(i, k, around):
        turn = math.tau * (k + 0.5) / around
        if math.sin(turn) > 0.3 and abs(math.cos(turn)) < 0.75 and 0 < i < len(hood) - 2:
            return "snake_band" if i % 2 else "snake_belly"
        return "snake_hide"
    s.loft(painted, hood, 12, True)
    skull = [(-0.02, 0.42, 0.03, 0.03, 0.03), (0.035, 0.425, 0.062, 0.046, 0.04), (0.1, 0.42, 0.078, 0.046, 0.04), (0.17, 0.405, 0.062, 0.035, 0.032),
             (0.228, 0.392, 0.042, 0.024, 0.022), (0.25, 0.388, 0.016, 0.01, 0.01)]
    s.loft(below("snake_hide", "snake_belly", -0.3), skull, 10)
    s.path("snake_tongue", [(0.0, 0.383, 0.235), (0.0, 0.372, 0.3)], [0.011, 0.007], 4)
    for side in (1.0, -1.0):
        s.path("snake_tongue", [(0.0, 0.372, 0.296), (0.024 * side, 0.366, 0.35)], [0.007, 0.0], 4)
    eyes(s, on_loft(skull, 0.15, 30.0), 0.02)
    return s


def head_vulture():
    """A vulture's, as Nekhbet has: a bare head on a long bare neck out of a ruff of feathers, and a heavy hooked beak."""
    s = Shape()
    s.path("vulture_hide", [(0.0, -0.03, 0.0), (0.0, 0.1, -0.008), (0.0, 0.2, 0.015), (0.0, 0.275, 0.04)], [0.06, 0.052, 0.05, 0.05], 8)
    s.ball("vulture_ruff", (0.0, 0.04, 0.0), (0.165, 0.075, 0.155), None, 10, 5)
    for n in range(10):
        turn = math.tau * (n + 0.5) / 10
        out = Vector((math.cos(turn), 0.0, math.sin(turn)))
        s.tube("vulture_ruff", out * 0.11 + Vector((0.0, 0.035, 0.0)), out * 0.215 + Vector((0.0, -0.03, 0.0)), 0.05, 0.0, 4)
    skull = [(-0.09, 0.29, 0.03, 0.03, 0.03), (-0.05, 0.29, 0.085, 0.085, 0.08), (0.03, 0.295, 0.108, 0.1, 0.095), (0.1, 0.29, 0.095, 0.08, 0.085),
             (0.16, 0.28, 0.06, 0.055, 0.058)]
    s.loft("vulture_hide", skull)
    beak = [(0.0, 0.282, 0.13), (0.0, 0.283, 0.22), (0.0, 0.272, 0.3), (0.0, 0.238, 0.35), (0.0, 0.188, 0.362), (0.0, 0.148, 0.338)]
    s.path(lambda i: "vulture_face" if i < 1 else "vulture_beak", beak, [(0.05, 0.056), (0.042, 0.05), (0.036, 0.044), (0.029, 0.036), (0.017, 0.022), 0.0], 8)
    s.path("vulture_beak", [(0.0, 0.245, 0.15), (0.0, 0.232, 0.27), (0.0, 0.222, 0.318)], [(0.036, 0.024), (0.024, 0.014), 0.0], 6)
    at = on_loft(skull, 0.09, 24.0)
    for side in (1.0, -1.0):
        s.ball("vulture_beak", flip(at + Vector((-0.012, 0.03, 0.0)), side), (0.034, 0.012, 0.05), about_z(-0.35 * side), 6, 3)
    eyes(s, at, 0.02)
    return s


def head_hippopotamus():
    """A hippopotamus's, as Taweret has and the Devourer: a great square muzzle wider than the skull behind it, the
    nostrils and the eyes carried high, small round ears, and the mouth open on its tusks."""
    s = Shape()
    skull = [(-0.17, 0.15, 0.03, 0.03, 0.03), (-0.11, 0.155, 0.13, 0.12, 0.11), (-0.01, 0.16, 0.165, 0.135, 0.12, 2.2), (0.09, 0.15, 0.16, 0.115, 0.1, 2.4),
             (0.18, 0.135, 0.155, 0.08, 0.075, 2.6), (0.28, 0.13, 0.18, 0.082, 0.07, 3.0), (0.37, 0.13, 0.2, 0.095, 0.07, 3.0), (0.44, 0.125, 0.19, 0.09, 0.065, 3.0),
             (0.475, 0.12, 0.11, 0.05, 0.04)]
    s.loft("hippopotamus_hide", skull, 12)
    # (the lower jaw, dropped: it is a paler, pinker thing, and the mouth between is red)
    jaw = [(-0.03, 0.0, 0.05, 0.03, 0.03), (0.05, -0.005, 0.14, 0.045, 0.07, 2.4), (0.2, -0.025, 0.152, 0.04, 0.075, 2.6), (0.34, -0.055, 0.178, 0.04, 0.07, 3.0),
           (0.42, -0.07, 0.172, 0.04, 0.06, 3.0), (0.455, -0.072, 0.1, 0.025, 0.035)]
    s.loft("hippopotamus_jowl", jaw, 12)
    s.loft("hippopotamus_mouth", [(0.02, 0.03, 0.08, 0.03, 0.03), (0.2, 0.03, 0.13, 0.04, 0.04, 3.0), (0.4, 0.015, 0.155, 0.055, 0.06, 3.0), (0.425, 0.015, 0.1, 0.04, 0.04)], 8)
    for side in (1.0, -1.0):
        # (the tusks of the lower jaw, the teeth of the upper)
        s.path("tooth", [(0.125 * side, -0.05, 0.395), (0.138 * side, 0.02, 0.418), (0.14 * side, 0.072, 0.41)], [0.03, 0.022, 0.0], 6)
        s.tube("tooth", (0.045 * side, -0.04, 0.435), (0.045 * side, 0.008, 0.468), 0.02, 0.008, 5)
        s.tube("tooth", (0.05 * side, 0.075, 0.445), (0.05 * side, 0.028, 0.452), 0.02, 0.012, 5)
        s.tube("tooth", (0.15 * side, 0.075, 0.33), (0.15 * side, 0.03, 0.335), 0.018, 0.008, 5)
        # (nostrils, raised at the end of the muzzle; eyes, raised on the brow; ears)
        s.ball("hippopotamus_hide", (0.09 * side, 0.212, 0.4), (0.05, 0.032, 0.05), None, 7, 4)
        s.ball("hippopotamus_nostril", (0.092 * side, 0.228, 0.428), (0.022, 0.014, 0.02), None, 6, 3)
        s.ball("hippopotamus_hide", (0.112 * side, 0.272, 0.06), (0.048, 0.046, 0.054), None, 7, 4)
        s.ball("hippopotamus_hide", (0.13 * side, 0.315, -0.075), (0.042, 0.052, 0.028), about_z(-0.3 * side), 7, 4)
        s.ball("hippopotamus_jowl", (0.132 * side, 0.315, -0.06), (0.024, 0.034, 0.02), about_z(-0.3 * side), 6, 3)
    eyes(s, Vector((0.14, 0.29, 0.088)), 0.022)
    wig(s, 0.18, 0.17, (0.0, 0.13, -0.095))
    return s


def head_ram():
    """A ram's, as Khnum has and Amun: a long bowed nose, and a ridged horn curled round each ear."""
    s = Shape()
    skull = [(-0.13, 0.13, 0.03, 0.03, 0.03), (-0.08, 0.135, 0.095, 0.1, 0.1), (0.0, 0.14, 0.116, 0.12, 0.12), (0.1, 0.138, 0.096, 0.1, 0.11),
             (0.2, 0.115, 0.076, 0.08, 0.086), (0.28, 0.08, 0.06, 0.06, 0.062), (0.335, 0.052, 0.046, 0.04, 0.042), (0.358, 0.042, 0.02, 0.02, 0.02)]
    s.loft("ram_hide", skull)
    s.ball("ram_nose", (0.0, 0.038, 0.345), (0.036, 0.026, 0.026), None, 6, 4)
    for side in (1.0, -1.0):
        # (each horn curls back, down and forward again round the ear, and out to a point)
        curl = []
        thick = []
        count = 13
        for n in range(count):
            t = n / (count - 1)
            turn = math.radians(75.0 + 420.0 * t)
            r = 0.125 - 0.05 * t
            curl.append(((0.085 + 0.14 * t * t + 0.03 * t) * side, 0.135 + math.sin(turn) * r, -0.035 + math.cos(turn) * r))
            thick.append(0.052 * (1.0 - t) ** 0.8 + 0.004 if n < count - 1 else 0.0)
        s.path(lambda i: "ram_horn_ridge" if i % 2 else "ram_horn", curl, thick, 6)
        s.ball("ram_hide", (0.15 * side, 0.115, -0.035), (0.06, 0.024, 0.036), about_z(-0.4 * side), 6, 3)
    eyes(s, on_loft(skull, 0.12, 32.0), 0.024)
    wig(s)
    return s


def head_hare():
    """A hare's, as the hare of the desert is drawn: ears as long as the rest of it, a short blunt face, a big eye."""
    s = Shape()
    skull = [(-0.125, 0.125, 0.03, 0.03, 0.03), (-0.07, 0.13, 0.095, 0.105, 0.105), (0.02, 0.135, 0.11, 0.11, 0.115), (0.11, 0.122, 0.09, 0.086, 0.1),
             (0.18, 0.105, 0.07, 0.062, 0.076), (0.235, 0.094, 0.052, 0.042, 0.05), (0.258, 0.09, 0.02, 0.018, 0.02)]
    s.loft("hare_hide", skull)
    s.ball("hare_nose", (0.0, 0.103, 0.256), (0.022, 0.016, 0.014), None, 6, 3)
    s.box("tooth", (0.0, 0.045, 0.238), (0.026, 0.03, 0.012))
    for side in (1.0, -1.0):
        s.ball("hare_cheek", (0.036 * side, 0.074, 0.212), (0.04, 0.034, 0.042), None, 7, 4)
        back = [(0.05, 0.2, -0.03), (0.056, 0.32, -0.045), (0.064, 0.47, -0.068), (0.072, 0.62, -0.095), (0.077, 0.71, -0.112), (0.079, 0.75, -0.12)]
        s.path("hare_hide", [flip(p, side) for p in back], [(0.03, 0.026), (0.042, 0.026), (0.05, 0.024), (0.046, 0.02), (0.03, 0.016), 0.0], 7)
        front = [(0.052, 0.27, -0.022), (0.058, 0.36, -0.035), (0.065, 0.47, -0.052), (0.072, 0.6, -0.076), (0.077, 0.7, -0.097)]
        s.path("hare_ear", [flip(p, side) for p in front], [(0.014, 0.01), (0.026, 0.012), (0.032, 0.012), (0.027, 0.01), 0.0], 6)
    eyes(s, on_loft(skull, 0.08, 30.0), 0.028)
    wig(s)
    return s


def head_lion():
    """A lion's: a broad face with a square muzzle, round ears, and the mane standing out all round it."""
    s = Shape()
    s.ball("lion_mane", (0.0, 0.12, -0.06), (0.21, 0.23, 0.17), None, 10, 6)
    for n in range(12):
        turn = math.tau * (n + 0.5) / 12
        out = Vector((math.cos(turn), math.sin(turn), 0.0))
        far = 0.285 if math.sin(turn) > -0.5 else 0.25
        s.tube("lion_mane", Vector((0.0, 0.125, -0.03)) + out * 0.15, Vector((0.0, 0.125, -0.085)) + out * far, 0.075, 0.0, 5)
    skull = [(-0.08, 0.14, 0.05, 0.05, 0.05), (-0.03, 0.145, 0.115, 0.118, 0.118), (0.05, 0.15, 0.13, 0.124, 0.13), (0.12, 0.135, 0.112, 0.1, 0.12),
             (0.18, 0.112, 0.088, 0.07, 0.096, 2.4), (0.245, 0.1, 0.078, 0.055, 0.086, 2.6), (0.275, 0.096, 0.045, 0.03, 0.05)]
    s.loft("lion_hide", skull)
    s.ball("lion_nose", (0.0, 0.132, 0.268), (0.032, 0.022, 0.02), None, 6, 3)
    s.ball("lion_muzzle", (0.0, 0.03, 0.2), (0.045, 0.034, 0.05), None, 7, 4)
    for side in (1.0, -1.0):
        s.ball("lion_muzzle", (0.036 * side, 0.088, 0.24), (0.046, 0.04, 0.042), None, 7, 4)
        s.ball("lion_hide", (0.125 * side, 0.305, -0.005), (0.05, 0.05, 0.026), None, 7, 4)
        s.ball("lion_mane", (0.125 * side, 0.3, 0.008), (0.03, 0.03, 0.018), None, 6, 3)
    eyes(s, on_loft(skull, 0.125, 38.0), 0.024)
    return s


def head_bull():
    """A bull's, as Apis has: long horns standing up in a lyre, ears held out under them, a broad pale muzzle."""
    s = Shape()
    skull = [(-0.13, 0.14, 0.03, 0.03, 0.03), (-0.07, 0.145, 0.105, 0.115, 0.115), (0.02, 0.15, 0.13, 0.13, 0.135), (0.12, 0.125, 0.105, 0.1, 0.12),
             (0.2, 0.092, 0.086, 0.076, 0.094), (0.27, 0.062, 0.086, 0.066, 0.074, 2.5), (0.318, 0.046, 0.082, 0.056, 0.06, 2.5), (0.34, 0.04, 0.045, 0.03, 0.035)]
    s.loft(lambda i, k, around: "bull_muzzle" if i >= 6 else "bull_hide", skull)
    for side in (1.0, -1.0):
        s.ball("bull_nostril", (0.04 * side, 0.05, 0.338), (0.013, 0.009, 0.008), None, 5, 3)
        horn = [(0.07, 0.235, -0.02), (0.17, 0.275, -0.02), (0.27, 0.335, -0.018), (0.325, 0.44, -0.012), (0.33, 0.55, 0.0), (0.305, 0.67, 0.02)]
        s.path("bull_horn", [flip(p, side) for p in horn], [0.042, 0.038, 0.033, 0.027, 0.019, 0.0], 6)
        ear = [(0.11, 0.185, -0.04), (0.18, 0.175, -0.045), (0.24, 0.165, -0.05), (0.275, 0.158, -0.052)]
        s.path("bull_hide", [flip(p, side) for p in ear], [(0.03, 0.03), (0.022, 0.045), (0.016, 0.036), 0.0], 6)
        s.path("bull_ear", [flip(p + Vector((0.0, 0.0, 0.016)), side) for p in map(Vector, ear[1:])], [(0.01, 0.026), (0.008, 0.02), 0.0], 5)
    eyes(s, on_loft(skull, 0.1, 34.0), 0.024)
    wig(s)
    return s


# --- The figure ---

def plinth():
    s = Shape()
    s.box("stone", (0.0, 0.125, 0.1), (1.0, 0.25, 1.2))
    return s


def seat():
    s = Shape()
    s.box("seat", (0.0, 0.5, -0.2), (0.6, 0.5, 0.62))
    s.box("seat", (0.0, 0.9, -0.47), (0.6, 0.34, 0.1))
    s.box("gold", (0.0, 0.74, -0.2), (0.62, 0.03, 0.64))
    return s


def feet(flesh):
    s = Shape()
    for x in (-0.1, 0.1):
        s.box(flesh, (x, 0.29, 0.43), (0.12, 0.08, 0.26))
    return s


def thighs(wrapped):
    """Both thighs, lying along +z from the hip; and what is over them."""
    s = Shape()
    flesh = "linen" if wrapped else "skin"
    for x in (-0.1, 0.1):
        s.tube(flesh, (x, 0.0, -0.02), (x, 0.0, THIGH), 0.115, 0.095, 8)
        s.ball(flesh, (x, 0.0, THIGH), 0.097, None, 8, 4)
    if wrapped:
        s.tube("linen_band", (0.0, 0.0, 0.22), (0.0, 0.0, 0.27), 0.124, 0.122, 10, 1.75)
    else:
        # (a kilt over his lap, and its apron hanging between his knees)
        s.box("linen", (0.0, 0.01, 0.17), (0.46, 0.25, 0.42))
        s.box("gold", (0.0, -0.02, 0.4), (0.12, 0.24, 0.04))
    return s


def shins(wrapped):
    """Both shins, lying along +z from the knee."""
    s = Shape()
    for x in (-0.1, 0.1):
        s.tube("linen" if wrapped else "skin", (x, 0.0, 0.0), (x, 0.0, SHIN), 0.09, 0.065, 8)
    if wrapped:
        s.tube("linen_band", (0.0, 0.0, 0.2), (0.0, 0.0, 0.25), 0.092, 0.088, 10, 2.05)
        s.tube("linen_band", (0.0, 0.0, 0.4), (0.0, 0.0, 0.44), 0.08, 0.078, 10, 2.3)
    return s


def trunk(wrapped):
    """From the hips up: the body, the shoulders, the neck and the collar of gold."""
    s = Shape()
    flesh = "linen" if wrapped else "skin"
    s.tube(flesh, (0.0, -0.1, 0.0), (0.0, 0.5, 0.0), 0.15, 0.16, 10, 1.3)
    s.ball(flesh, (0.0, 0.5, 0.0), (0.29, 0.1, 0.15), None, 10, 5)
    s.tube("hide", (0.0, 0.5, 0.0), (0.0, 0.7, 0.0), 0.075, 0.07, 8)
    s.ball("gold", (0.0, 0.555, 0.02), (0.2, 0.055, 0.17), None, 10, 5)
    if wrapped:
        for y in (0.1, 0.3):
            s.tube("linen_band", (0.0, y, 0.0), (0.0, y + 0.05, 0.0), 0.165, 0.166, 10, 1.3)
    else:
        s.tube("gold", (0.0, -0.02, 0.0), (0.0, 0.04, 0.0), 0.165, 0.165, 10, 1.3)
    return s


def wig_cloth():
    """The wig: down his back, and a lappet on each shoulder."""
    s = Shape()
    s.box("wig", (0.0, 0.58, -0.13), (0.3, 0.36, 0.08))
    for x in (-0.12, 0.12):
        s.box("wig", (x, 0.5, 0.135), (0.09, 0.26, 0.05))
    return s


def arm(wrapped):
    """An arm, hung from the shoulder and bent at the elbow, and its fist."""
    s = Shape()
    flesh = "linen" if wrapped else "skin"
    s.tube(flesh, (0.0, 0.0, 0.0), (0.0, -0.3, 0.06), 0.068, 0.056, 7)
    s.tube(flesh, (0.0, -0.3, 0.06), (0.0, -0.36, 0.4), 0.056, 0.046, 7)
    s.ball(flesh, (0.0, -0.3, 0.06), 0.057, None, 7, 4)
    s.ball("hide" if wrapped else "skin", FIST, 0.062, None, 7, 4)
    if wrapped:
        s.tube("linen_band", (0.0, -0.345, 0.3), (0.0, -0.352, 0.34), 0.054, 0.052, 7)
    else:
        s.tube("gold", (0.0, -0.12, 0.024), (0.0, -0.17, 0.034), 0.068, 0.066, 7)
    return s


def knife(side):
    """The knife in a fist: its grip, its guard of gold, and the blade, turned a little outwards."""
    s = Shape()
    s.tube("hilt", (0.0, -0.09, 0.0), (0.0, 0.1, 0.0), 0.024, 0.024, 6)
    s.box("gold", (0.0, 0.1, 0.0), (0.1, 0.025, 0.05), about_y(0.75 * side))
    s.slab("blade", [(-0.045, 0.1), (-0.1, 0.32), (-0.085, 0.54), (0.0, 0.72), (0.05, 0.5), (0.04, 0.1)], 0.022, about_y(0.75 * side))
    return s


def great_knife():
    """One of the two knives that bar a gateway: it stands on its hilt at the foot of one side and leans across."""
    s = Shape()
    long = math.hypot(GATE_WIDE, GATE_TALL) * 0.98
    s.tube("hilt", (0.0, -0.05, 0.0), (0.0, 0.3, 0.0), 0.05, 0.05, 6)
    s.box("gold", (0.0, 0.3, 0.0), (0.3, 0.06, 0.1))
    s.slab("blade", [(-0.1, 0.3), (-0.17, long * 0.45), (-0.12, long * 0.8), (0.0, long), (0.1, long * 0.75), (0.09, 0.3)], 0.05)
    return s


# --- The leaf of papyrus ---

def leaf_open():
    """A sheet lying open, its ends curled up a little. What is written on it the game draws: it is laid on by
    the sheet's texture coordinates, the writing running along it."""
    s = Shape()
    strips = 8
    for n in range(strips):
        corners = []
        uvs = []
        for along, across in ((n, 0), (n, 1), (n + 1, 1), (n + 1, 0)):
            t = along / strips
            corners.append(s.point((t * 0.62 - 0.31, (abs(t - 0.5) * 2.0) ** 3 * 0.07, across * 0.44 - 0.22)))
            uvs.append((t, across))
        s.face(corners, "papyrus", True, uvs)
    return s


def leaf_rolled():
    """A roll: the sheet wound round, a hand's breadth through, and tied with a red cord."""
    s = Shape()
    sides = 10
    for n in range(sides):
        corners = []
        uvs = []
        for turn, end in ((n, 0), (n + 1, 0), (n + 1, 1), (n, 1)):
            angle = math.tau * turn / sides
            corners.append(s.point((end * 0.5 - 0.25, math.cos(angle) * 0.06, math.sin(angle) * 0.06)))
            uvs.append((end, turn / sides * 2.0))
        s.face(corners, "papyrus", True, uvs)
    s.tube("tie", (-0.025, 0.0, 0.0), (0.025, 0.0, 0.0), 0.063, 0.063, 10)
    return s


# --- Putting it together ---

def linear(c):
    return ((c + 0.055) / 1.055) ** 2.4 if c > 0.04045 else c / 12.92


MATERIALS = {}


def material(label):
    if label not in MATERIALS:
        made = bpy.data.materials.new(label)
        made.use_nodes = True
        colour = tuple(linear(c) for c in COLOURS[label]) + (1.0,)
        shader = made.node_tree.nodes["Principled BSDF"]
        shader.inputs["Base Color"].default_value = colour
        shader.inputs["Roughness"].default_value = 1.0
        if label == "eye":
            shader.inputs["Emission Color"].default_value = colour
            shader.inputs["Emission Strength"].default_value = 1.0
        if label in ("gold", "blade"):
            shader.inputs["Metallic"].default_value = 0.6
            shader.inputs["Roughness"].default_value = 0.45
        made.diffuse_color = colour
        made.use_backface_culling = label != "papyrus"
        MATERIALS[label] = made
    return MATERIALS[label]


def mesh_of(name, shape):
    used = []
    for _, label, _, _ in shape.faces:
        if label not in used:
            used.append(label)
    made = bmesh.new()
    verts = [made.verts.new(to_blender(p)) for p in shape.points]
    layer = made.loops.layers.uv.new("UVMap") if any(uvs for _, _, _, uvs in shape.faces) else None
    sheet = set()
    for corners, label, smooth, uvs in shape.faces:
        ring = []
        for c in corners:
            if verts[c] not in ring:
                ring.append(verts[c])
        if len(ring) < 3:
            continue
        try:
            face = made.faces.new(ring)
        except ValueError:
            continue
        face.material_index = used.index(label)
        face.smooth = smooth
        if layer and uvs:
            sheet.add(face)
            for loop, uv in zip(face.loops, uvs):
                # (the game counts down a picture from its top; Blender up from its foot)
                loop[layer].uv = (uv[0], 1.0 - uv[1])
    # (points nothing uses are dropped; every closed lump of it is turned to face outwards)
    bmesh.ops.delete(made, geom=[v for v in made.verts if not v.link_faces], context="VERTS")
    # (the sheet of the leaf is left as it was drawn: it has no inside)
    bmesh.ops.recalc_face_normals(made, faces=[f for f in made.faces if f not in sheet])
    mesh = bpy.data.meshes.new(name)
    made.to_mesh(mesh)
    made.free()
    for label in used:
        mesh.materials.append(material(label))
    return mesh


def thing(name, mesh, at=(0.0, 0.0, 0.0), parent=None, turn=None):
    """Puts a thing in the scene: at is where its origin is within its parent, turn how it is turned there."""
    made = bpy.data.objects.new(name, mesh)
    bpy.context.collection.objects.link(made)
    if mesh is None:
        made.empty_display_type = "PLAIN_AXES"
        made.empty_display_size = 0.12
    basis = TO_BLENDER @ (turn if turn else Matrix.Identity(3)) @ TO_BLENDER.transposed()
    made.matrix_basis = Matrix.Translation(to_blender(at)) @ basis.to_4x4()
    made.parent = parent
    return made


def along(way):
    """How a limb modelled along +z is turned to lie along way (as the game turns it)."""
    way = Vector(way).normalized()
    right = Vector((1.0, 0.0, 0.0))
    up = way.cross(right).normalized()
    return Matrix((right, up, way)).transposed()


def build():
    bpy.ops.wm.read_factory_settings(use_empty=True)
    meshes = {}
    for name, shape in (("plinth", plinth()), ("seat", seat()), ("wig", wig_cloth()), ("knife_left", knife(1.0)), ("knife_right", knife(-1.0)),
                        ("great_knife", great_knife()), ("leaf_open", leaf_open()), ("leaf_rolled", leaf_rolled())):
        meshes[name] = mesh_of(name, shape)
    for dress, wrapped in (("wrapped", True), ("kilt", False)):
        meshes["feet_" + dress] = mesh_of("feet_" + dress, feet("linen" if wrapped else "skin"))
        meshes["thighs_" + dress] = mesh_of("thighs_" + dress, thighs(wrapped))
        meshes["shins_" + dress] = mesh_of("shins_" + dress, shins(wrapped))
        meshes["trunk_" + dress] = mesh_of("trunk_" + dress, trunk(wrapped))
        meshes["arm_" + dress] = mesh_of("arm_" + dress, arm(wrapped))
    makers = {"crocodile": head_crocodile, "snake": head_snake, "vulture": head_vulture, "hippopotamus": head_hippopotamus, "ram": head_ram,
              "jackal": head_jackal, "hare": head_hare, "lion": head_lion, "bull": head_bull}
    for beast in HEADS:
        # (a little over life size: it is by its head that he is known, across a room)
        meshes["head_" + beast] = mesh_of("head_" + beast, makers[beast]().scaled(HEAD_SIZE))

    # As it sits: the knee is found from where the hip is and where the foot stays, as the game finds it.
    to = ANKLE - HIP
    span = min(to.length, THIGH + SHIN - 0.001)
    way = to.normalized()
    bend = math.acos(max(-1.0, min(1.0, (THIGH * THIGH + span * span - SHIN * SHIN) / (2.0 * THIGH * span))))
    forward = Vector((0.0, way.z, -way.y))
    knee = HIP + (way * math.cos(bend) + forward * math.sin(bend)) * THIGH

    necks = {}
    for dress, at, again in (("wrapped", (0.0, 0.0, 0.0), ""), ("kilt", KILT_AT, "_again")):
        whole = thing("guardian_" + dress, None, at)
        thing("plinth" + again, meshes["plinth"], parent=whole)
        thing("seat" + again, meshes["seat"], parent=whole)
        thing("feet_" + dress, meshes["feet_" + dress], parent=whole)
        thing("thighs_" + dress, meshes["thighs_" + dress], HIP, whole, along(knee - HIP))
        thing("shins_" + dress, meshes["shins_" + dress], knee, whole, along(ANKLE - knee))
        body = thing("trunk_" + dress, meshes["trunk_" + dress], HIP, whole)
        thing("wig" + again, meshes["wig"], parent=body)
        necks[dress] = thing("neck" + again, None, NECK, body)
        for label, side in (("left", 1.0), ("right", -1.0)):
            hung = thing("arm_%s_%s" % (dress, label), meshes["arm_" + dress], (SHOULDER[0] * side, SHOULDER[1], SHOULDER[2]), body)
            thing("knife_%s%s" % (label, again), meshes["knife_" + label], FIST, hung)
    # The heads: the jackal's on the first figure, the bull's on the second, the rest in a row behind.
    place = 0
    for beast in HEADS:
        if beast == "jackal":
            thing("head_" + beast, meshes["head_" + beast], parent=necks["wrapped"])
        elif beast == "bull":
            thing("head_" + beast, meshes["head_" + beast], parent=necks["kilt"])
        else:
            thing("head_" + beast, meshes["head_" + beast], (-3.4 + place * 0.9, 1.0, -2.2))
            place += 1
    # The great knives, crossed in the gateway beside the first figure.
    crossed = math.atan2(GATE_WIDE, GATE_TALL) * 0.92
    for label, side in (("", 1.0), ("_again", -1.0)):
        thing("great_knife" + label, meshes["great_knife"], (GATE_AT[0] - side * GATE_WIDE * 0.5, 0.0, GATE_AT[2] + 0.03 * side), None, about_z(-side * crossed))
    thing("leaf_open", meshes["leaf_open"], (0.6, 0.02, 1.4))
    thing("leaf_rolled", meshes["leaf_rolled"], (1.5, 0.06, 1.4))

    for made in bpy.data.meshes:
        made.calc_loop_triangles()
        print("  %-22s %4d triangles, %d colours" % (made.name, len(made.loop_triangles), len(made.materials)))
    os.makedirs(os.path.join(ROOT, "models"), exist_ok=True)
    bpy.ops.wm.save_as_mainfile(filepath=os.path.join(ROOT, "tools", "guardian.blend"))
    bpy.ops.export_scene.gltf(
        filepath=os.path.join(ROOT, "models", "guardian.glb"),
        export_format="GLB",
        export_yup=True,
        export_animations=False,
    )
    print("BUILT guardian")


build()
