"""Builds Khepri, the sun, the horizon (akhet), the small scarab of the swarms and
the scarab amulet, and exports them for Godot.

Run from the project root:
    blender --background --python tools/build_khepri.py
then, so that Godot takes up the new model:
    godot --headless --path . --import

Writes models/khepri.glb, and tools/khepri.blend to look at and to change by hand.
(To export by hand: File, Export, glTF 2.0, to models/khepri.glb, with +Y up.)

What is in it, each thing named for what it is:

    khepri                 (an empty) the big beetle, 0.45 m long, standing on the
                           ground and facing the game's +Z, as it sits on a hill of
                           the horizon when the sun has risen: wing cases open and
                           wings out. scripts/khepri.gd reads everything under it.
      body                 the gold shield over the thorax, the dark back under the
                           wing cases, the belly
      head                 the head shield, its front edge cut into six teeth, and
                           two eyes of lapis
      wing_case_left       a wing case of lapis, with its seam, a line and its rim
                           in gold. Its origin is its hinge; how it is turned here
                           is how far it opens (shut, it is not turned at all).
      wing_case_right      the same mesh turned over
      wing_left            a wing: a fan of feathers in bands, lying out to its
                           left. Its origin is its root; how it is turned here is
                           how it is held when it is out.
      wing_right           the same mesh turned over
      leg_fore_left, leg_mid_left, leg_hind_left, leg_fore_right, ...
                           the six legs (the right ones are the left ones' meshes
                           turned over). A leg's origin is its hip, which is what
                           the game swings it about; its lowest point is its foot.
    sun                    the ball of sun, 0.7 m across. Its colours and the
                           tongues of fire on it are drawn by the game.
    akhet                  (an empty) the horizon. scripts/akhet.gd reads everything
                           under it.
      ground               the slab it stands on, and a strip of gold along each edge
      hill_east, hill_west the two hills (one mesh), each with a band of gold at its foot
      cradle               the dish of gold the sun is brought to, and the ring round it
    scarab                 the small black beetle of the swarms, ONE UNIT long (the
                           game makes it the size it wants). See below before
                           changing it.
    scarab_amulet          the amulet of gold and blue stone, one unit long

The game's left is +X here (it faces +Z); in Blender that is +X, and it faces -Y.

Colours are materials, named plainly. For the big beetle the game takes each
material's Base Color; how much a part glints is taken from its Roughness (1:
not at all), and a material with Emission is drawn bright of itself and not lit
(the wings: so near the sun, light would bleach them). The horizon's stone and
gold are the game's own stone and gold, in the colours given here (hill_stone,
ground_stone, horizon_gold, cradle_bronze). The amulet's gold is `amulet_gold`;
its stone (`amulet_stone`) is whatever colour the game's amulet is set to.

The small scarab is drawn a hundred or two at a time and its legs are moved by a
shader, which is told what to move by the mesh's UV map: U is how far down a leg
a point is (0 at the hip, 1 at the foot: the body is all 0), and V says which
three legs it steps with (1, or 0.5 for the other three; in Godot that is 0 and
0.5). Moving points about keeps this; points added to a leg take it from the
points they were made from. It is all one colour (the game's black, with a
sheen); its materials (scarab_shell, scarab_thorax, scarab_head, scarab_leg)
only say how much each part shines, by their Roughness (0: wholly; 1: not).
Keep it to about 130 triangles: there are a great many of them.

Everything below is written in the game's own directions (x to its left, y up,
z the way it faces) and turned to Blender's as it is made.
"""

import bpy
import bmesh
import math
import os
from mathutils import Matrix, Vector

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))

# How long the big beetle is, metres. Its shapes below are in lengths of a beetle.
LONG = 0.45
# How big across the sun is.
SUN = 0.7
# The horizon: how far from the cradle the middle of each hill is, and how wide, high and deep a hill is.
HILL_OUT = 0.94
HILL = (0.84, 0.62, 1.0)

# The colours as they are seen (sRGB), how rough each is (1: it does not glint), and whether it is bright of itself.
COLOURS = {
    "lapis": ((0.04, 0.15, 0.62), 0.4, False),
    "gold": ((0.96, 0.7, 0.2), 0.4, False),
    "gold_dark": ((0.5, 0.33, 0.08), 1.0, False),
    "sun": ((1.0, 0.78, 0.25), 1.0, True),
    "hill_stone": ((0.66, 0.57, 0.43), 1.0, False),
    "ground_stone": ((0.515, 0.445, 0.335), 1.0, False),
    "horizon_gold": ((0.96, 0.7, 0.2), 0.4, False),
    "cradle_bronze": ((0.74, 0.5, 0.24), 0.4, False),
    "scarab_shell": ((0.035, 0.04, 0.05), 0.0, False),
    "scarab_thorax": ((0.035, 0.04, 0.05), 0.6, False),
    "scarab_head": ((0.035, 0.04, 0.05), 0.3, False),
    "scarab_leg": ((0.035, 0.04, 0.05), 1.0, False),
    "amulet_gold": ((0.96, 0.7, 0.2), 0.4, False),
    "amulet_stone": ((0.1, 0.22, 0.6), 0.4, False),
}
# The paints of the wings, as light (not as seen: these go to the model as they are), and each a shade darker for
# every other feather.
WING_PAINTS = {
    "wing_gold": (0.96, 0.7, 0.2),
    "wing_lapis": (0.05, 0.17, 0.62),
    "wing_turquoise": (0.1, 0.62, 0.6),
    "wing_red": (0.75, 0.16, 0.08),
}
# Along a feather: where each band starts (in lengths of the beetle), and its paint.
WING_BANDS = [(0.2, "wing_gold"), (0.34, "wing_lapis"), (0.74, "wing_gold"), (0.84, "wing_turquoise"),
              (1.16, "wing_gold"), (1.26, "wing_red"), (1.5, "wing_red")]

# Where the big beetle's parts are hinged (in lengths of the beetle), and how the ones that open are turned when
# they are open (as Godot turns things: about Y, then X, then Z, radians; for its left side).
NECK = (0.0, 0.06, 0.3)
CASE_HINGE = (0.05, 0.2, 0.1)
CASE_OPEN = (0.5, -0.85, -0.35)
WING_ROOT = (0.16, 0.2, 0.08)
WING_OUT = (-0.55, 0.0, 0.42)
# The legs, fore to hind: where the hip is along the body, the knee and the foot from there, and how thick.
LEGS = {
    "fore": (0.2, (0.15, 0.07, 0.1), (0.18, -0.08, 0.24), 0.05),
    "mid": (0.02, (0.15, 0.07, -0.02), (0.25, -0.08, -0.06), 0.036),
    "hind": (-0.16, (0.15, 0.07, -0.12), (0.2, -0.08, -0.34), 0.04),
}
HIP = (0.22, 0.08)


def to_blender(p):
    return (p[0], -p[2], p[1])


def add(a, b):
    return (a[0] + b[0], a[1] + b[1], a[2] + b[2])


def sub(a, b):
    return (a[0] - b[0], a[1] - b[1], a[2] - b[2])


def times(a, by):
    return (a[0] * by, a[1] * by, a[2] * by)


def mix(a, b, t):
    return (a[0] + (b[0] - a[0]) * t, a[1] + (b[1] - a[1]) * t, a[2] + (b[2] - a[2]) * t)


def cross(a, b):
    return (a[1] * b[2] - a[2] * b[1], a[2] * b[0] - a[0] * b[2], a[0] * b[1] - a[1] * b[0])


def unit(a):
    size = math.sqrt(sum(c * c for c in a))
    return tuple(c / size for c in a)


def lerp(a, b, t):
    return a + (b - a) * t


class Shape:
    """Faces being gathered for one thing: each a list of points, a material and whether it is rounded. A face may
    also say what each of its corners' normals and UVs are to be (the small scarab's do)."""

    def __init__(self):
        self.faces = []

    def face(self, points, material, smooth=False, normals=None, uvs=None):
        self.faces.append((points, material, smooth, normals, uvs))

    def moved(self, by=(0.0, 0.0, 0.0), size=1.0):
        """The same, moved and then made bigger."""
        made = Shape()
        made.faces = [([times(add(p, by), size) for p in points], material, smooth, normals, uvs)
                      for points, material, smooth, normals, uvs in self.faces]
        return made

    def dome(self, middle, radii, material, around, rings, exact=False, uv=(0.0, 1.0)):
        """Half of an egg, standing on its cut face."""
        def at(ring, k):
            high = math.pi * 0.5 * ring / rings
            turn = math.tau * k / around
            return (math.cos(turn) * math.cos(high), math.sin(high), math.sin(turn) * math.cos(high))

        def put(corners):
            points = [(middle[0] + c[0] * radii[0], middle[1] + c[1] * radii[1], middle[2] + c[2] * radii[2]) for c in corners]
            normals = [unit((c[0] / radii[0], c[1] / radii[1], c[2] / radii[2])) for c in corners] if exact else None
            self.face(points, material, True, normals, [uv] * len(points) if exact else None)
        for ring in range(rings):
            for k in range(around):
                if ring == rings - 1:
                    put([at(ring, k), at(rings, 0), at(ring, k + 1)])
                else:
                    put([at(ring, k), at(ring + 1, k), at(ring + 1, k + 1), at(ring, k + 1)])

    def blob(self, middle, radii, material, around, rows):
        """A ball, squashed to `radii`."""
        def at(row, k):
            high = math.pi * 0.5 - math.pi * row / rows
            turn = math.tau * k / around
            c = (math.sin(turn) * math.cos(high), math.sin(high), math.cos(turn) * math.cos(high))
            return (middle[0] + c[0] * radii[0], middle[1] + c[1] * radii[1], middle[2] + c[2] * radii[2])
        for row in range(rows):
            for k in range(around):
                if row == 0:
                    self.face([at(0, 0), at(1, k), at(1, k + 1)], material, True)
                elif row == rows - 1:
                    self.face([at(row, k), at(rows, 0), at(row, k + 1)], material, True)
                else:
                    self.face([at(row, k), at(row + 1, k), at(row + 1, k + 1), at(row, k + 1)], material, True)

    def ring(self, middle, radius, thick, material, squash=(1.0, 1.0), around=16, sides=6):
        """A ring lying flat: `radius` to the middle of it, `thick` through."""
        def at(k, j):
            turn = math.tau * k / around
            roll = math.tau * j / sides
            out = radius + math.cos(roll) * thick * 0.5
            return (middle[0] + math.cos(turn) * out * squash[0], middle[1] + math.sin(roll) * thick * 0.5, middle[2] + math.sin(turn) * out * squash[1])
        for k in range(around):
            for j in range(sides):
                self.face([at(k, j), at(k, j + 1), at(k + 1, j + 1), at(k + 1, j)], material, True)

    def box(self, middle, size, material):
        x, y, z = size[0] * 0.5, size[1] * 0.5, size[2] * 0.5
        c = [add(middle, (sx * x, sy * y, sz * z)) for sx in (-1, 1) for sy in (-1, 1) for sz in (-1, 1)]
        for a, b, d, e in ((0, 1, 3, 2), (4, 6, 7, 5), (0, 4, 5, 1), (2, 3, 7, 6), (0, 2, 6, 4), (1, 5, 7, 3)):
            self.face([c[a], c[b], c[d], c[e]], material)

    def spar(self, start, end, wide, narrow, material, flat=0.6):
        """A piece of a leg: four-sided, tapering, wider across than it is deep."""
        along = unit(sub(end, start))
        across = unit(cross(along, (0.0, 1.0, 0.0)))
        over = cross(across, along)

        def round_it(at, size):
            return [add(at, times(across, size)), add(at, times(over, size * flat)), add(at, times(across, -size)), add(at, times(over, -size * flat))]
        a = round_it(start, wide)
        b = round_it(end, narrow)
        for k in range(4):
            self.face([a[k], a[(k + 1) % 4], b[(k + 1) % 4], b[k]], material)
        self.face(list(reversed(a)), material)
        self.face(b, material)


# --- The big beetle ---

def khepri_body():
    """The shield over the thorax, in gold; the back that the wing cases cover, dark; and the belly."""
    s = Shape()
    s.dome((0.0, 0.06, 0.2), (0.31, 0.2, 0.16), "gold", 12, 4)
    s.dome((0.0, 0.06, -0.19), (0.28, 0.2, 0.3), "gold_dark", 10, 3)
    # (the belly: flat, under all of it)
    for middle, radii, around in (((0.0, 0.06, 0.2), (0.31, 0.16), 12), ((0.0, 0.06, -0.19), (0.31, 0.32), 10)):
        s.face([(middle[0] + math.cos(math.tau * k / around) * radii[0], middle[1], middle[2] + math.sin(math.tau * k / around) * radii[1])
                for k in range(around)], "gold_dark")
    return s.moved(size=LONG)


def khepri_head():
    """The head shield: a plate sloping down to a front edge cut into six teeth. And two eyes."""
    s = Shape()
    edge = []
    for k in range(13):
        turn = lerp(-math.pi * 0.5, math.pi * 0.5, k / 12.0)
        far = 0.2 if k % 2 == 1 else 0.14
        edge.append((math.sin(turn) * far * 1.15, 0.05, 0.31 + math.cos(turn) * far))
    for k in range(12):
        s.face([(0.0, 0.13, 0.3), edge[k], edge[k + 1]], "gold", True)
    for side in (-1.0, 1.0):
        s.blob((side * 0.125, 0.1, 0.345), (0.034, 0.03, 0.034), "lapis", 6, 4)
    return s.moved(times(NECK, -1.0), LONG)


def khepri_wing_case():
    """The wing case of its left side: half of a dome, split along the back. Lapis, with gold along the seam, a
    line of gold down the middle of it, and a rim of gold."""
    s = Shape()
    middle = (0.004, 0.06, -0.19)
    radii = (0.33, 0.27, 0.33)
    # (round from the seam on top to the rim at the side, and which strips are gold)
    rounds = [0.0, 0.06, 0.28, 0.5, 0.56, 0.86, 1.15, 1.42, math.pi * 0.5]
    golden = (0, 3, 7)
    along = 8

    def at(i, j):
        down = rounds[i]
        back = math.pi * j / along
        return (middle[0] + radii[0] * math.sin(back) * math.sin(down), middle[1] + radii[1] * math.sin(back) * math.cos(down), middle[2] + radii[2] * math.cos(back))
    for i in range(len(rounds) - 1):
        paint = "gold" if i in golden else "lapis"
        for j in range(along):
            if j == 0:
                s.face([at(i, 0), at(i, 1), at(i + 1, 1)], paint, True)
            elif j == along - 1:
                s.face([at(i, j), at(i, along), at(i + 1, j)], paint, True)
            else:
                s.face([at(i, j), at(i, j + 1), at(i + 1, j + 1), at(i + 1, j)], paint, True)
    return s.moved(times(CASE_HINGE, -1.0), LONG)


def khepri_wing():
    """One wing, lying out to its left and sweeping forward: a fan of seven feathers in bands of gold, lapis,
    turquoise and red, as the winged scarab of a pectoral has. Every other feather is a shade darker."""
    s = Shape()
    feathers = 7
    for feather in range(feathers):
        # (from a little behind straight out, round to well forward; the foremost feathers are the longest)
        one = lerp(-0.35, 1.05, feather / feathers)
        two = lerp(-0.35, 1.05, (feather + 0.9) / feathers)
        long = lerp(0.72, 1.0, feather / (feathers - 1))
        for band in range(len(WING_BANDS) - 1):
            near = WING_BANDS[band][0] * long if band > 0 else 0.2
            far = WING_BANDS[band + 1][0] * long
            # (it is cupped a little: the tips are higher than the roots)
            corners = [(math.cos(turn) * out, out * out * 0.12, math.sin(turn) * out) for turn, out in ((one, near), (two, near), (two, far), (one, far))]
            s.face(corners, WING_BANDS[band][1] + ("" if feather % 2 == 0 else "_shade"))
    return s.moved(size=LONG)


def khepri_leg(which):
    """A leg of its left side: out and up to a knee, then down to a foot. The fore legs reach forward and are
    broad, with teeth (they dig); the hind legs are long and trail."""
    s = Shape()
    along, knee, foot, thick = LEGS[which]
    hip = (0.0, 0.0, 0.0)
    s.spar(hip, knee, thick * 1.2, thick * 1.0, "gold_dark")
    s.spar(knee, foot, thick * (1.4 if which == "fore" else 1.0), thick * 0.5, "gold_dark", 0.35 if which == "fore" else 0.6)
    # (a knob of gold at the knee)
    s.blob(knee, (thick * 0.8, thick * 0.8, thick * 0.8), "gold", 5, 3)
    if which == "fore":
        # (the teeth of the fore leg: with those of the head they are the rays of the rising sun)
        out = unit(cross((0.0, 1.0, 0.0), sub(foot, knee)))
        for k in range(3):
            a = mix(knee, foot, 0.3 + k * 0.22)
            b = mix(knee, foot, 0.5 + k * 0.22)
            s.face([a, b, add(mix(a, b, 0.6), times(out, -thick * 1.5))], "gold")
    return s.moved(size=LONG)


def sun():
    s = Shape()
    s.blob((0.0, 0.0, 0.0), (SUN * 0.5, SUN * 0.5, SUN * 0.5), "sun", 20, 11)
    return s


# --- The horizon ---

def akhet_ground():
    s = Shape()
    s.box((0.0, 0.012, 0.0), (HILL_OUT * 2.0 + HILL[0] + 0.16, 0.024, HILL[2] + 0.16), "ground_stone")
    for z in (-1.0, 1.0):
        s.box((0.0, 0.016, z * (HILL[2] * 0.5 + 0.03)), (HILL_OUT * 2.0 + HILL[0] + 0.06, 0.03, 0.05), "horizon_gold")
    return s


def akhet_hill():
    s = Shape()
    s.dome((0.0, 0.0, 0.0), (HILL[0] * 0.5, HILL[1], HILL[2] * 0.5), "hill_stone", 14, 5)
    s.ring((0.0, 0.05, 0.0), 0.47, 0.07, "horizon_gold", (HILL[0], HILL[2]))
    return s


def akhet_cradle():
    s = Shape()
    around = 16
    rim = [(math.cos(math.tau * k / around) * 0.36, math.sin(math.tau * k / around) * 0.36) for k in range(around)]
    s.face([(x, 0.035, z) for x, z in reversed(rim)], "horizon_gold")
    for k in range(around):
        a = rim[k]
        b = rim[(k + 1) % around]
        s.face([(a[0], 0.005, a[1]), (a[0], 0.035, a[1]), (b[0], 0.035, b[1]), (b[0], 0.005, b[1])], "horizon_gold")
    s.ring((0.0, 0.035, 0.0), 0.4, 0.07, "cradle_bronze")
    return s


# --- The small scarab, and the amulet: a unit long, and each point as the game's shaders want it ---

def scarab_head(s, material):
    edge = []
    for k in range(13):
        turn = lerp(-math.pi * 0.5, math.pi * 0.5, k / 12.0)
        far = 0.2 if k % 2 == 1 else 0.14
        edge.append((math.sin(turn) * far * 1.15, 0.05, 0.31 + math.cos(turn) * far))
    lie = unit((0.0, 0.94, 0.34))
    for k in range(12):
        s.face([(0.0, 0.13, 0.3), edge[k], edge[k + 1]], material, True, [lie] * 3, [(0.0, 1.0)] * 3)


def scarab():
    """The sacred scarab: domed wing cases, the shield over the thorax, the toothed head shield, and six legs, each
    two pieces, each piece two flat strips crossed."""
    s = Shape()
    s.dome((0.0, 0.06, -0.19), (0.33, 0.27, 0.33), "scarab_shell", 8, 3, True)
    s.dome((0.0, 0.06, 0.2), (0.31, 0.2, 0.16), "scarab_thorax", 8, 2, True)
    scarab_head(s, "scarab_head")
    for side in (-1.0, 1.0):
        for pair in range(3):
            along = (0.2, 0.02, -0.16)[pair]
            hip = (side * 0.22, 0.08, along)
            knee = (side * 0.37, 0.15, along + (0.1, -0.02, -0.12)[pair])
            foot = (side * (0.4, 0.47, 0.42)[pair], 0.0, along + (0.24, -0.06, -0.34)[pair])
            # (the legs of one side step in turn, and each with its opposite of the next pair)
            step = 0.5 if (pair % 2 == 0) == (side > 0.0) else 0.0
            thick = (0.06, 0.04, 0.045)[pair]
            leans = SCARAB_LEANS[(0 if side < 0.0 else 3) + pair]
            scarab_limb(s, hip, knee, thick, 0.0, 0.45, step, leans[0])
            scarab_limb(s, knee, foot, thick * 0.8, 0.45, 1.0, step, leans[1])
    return s


# Each piece of a leg is two flat strips crossed, one lying and one standing on edge. The one on edge is lit as if
# it leant a little to one side: which side (+1: the game's +X), for the upper and the lower piece of each leg, the
# right legs fore to hind and then the left. (They are as the beetle was first made, when it was made in code.)
SCARAB_LEANS = ((1, -1), (-1, -1), (-1, 1), (1, 1), (-1, -1), (-1, -1))


def scarab_limb(s, start, end, thick, low, high, step, leans):
    along = unit(sub(end, start))
    across = unit(cross(along, (0.0, 1.0, 0.0)))
    over = cross(across, along)
    for way in (across, over):
        lie = unit(cross(way, along))
        if (lie[1] < 0.0) if way is across else (lie[0] * leans < 0.0):
            lie = times(lie, -1.0)
        lie = unit(mix(lie, (0.0, 1.0, 0.0), 0.5))
        points = [sub(start, times(way, thick)), add(start, times(way, thick)), add(end, times(way, thick * 0.6)), sub(end, times(way, thick * 0.6))]
        # (V is turned over on the way out of Blender: 1 - step here is step in the game)
        s.face(points, "scarab_leg", True, [lie] * 4, [(low, 1.0 - step), (low, 1.0 - step), (high, 1.0 - step), (high, 1.0 - step)])


def scarab_amulet():
    """A scarab as a jewel: the thorax, the head and a flat oval base in gold, the wing cases in blue stone."""
    s = Shape()
    s.dome((0.0, 0.05, 0.19), (0.29, 0.21, 0.15), "amulet_gold", 8, 2, True)
    scarab_head(s, "amulet_gold")
    # (the base stands a little proud of the beetle all round: what a seal is cut into)
    rim = 12
    edge = [(math.cos(math.tau * k / rim) * 0.36, math.sin(math.tau * k / rim) * 0.56) for k in range(rim)]
    s.face([(x, 0.05, z) for x, z in reversed(edge)], "amulet_gold")
    s.face([(x, 0.0, z) for x, z in edge], "amulet_gold")
    for k in range(rim):
        a = edge[k]
        b = edge[(k + 1) % rim]
        s.face([(a[0], 0.0, a[1]), (a[0], 0.05, a[1]), (b[0], 0.05, b[1]), (b[0], 0.0, b[1])], "amulet_gold")
    s.dome((0.0, 0.05, -0.2), (0.31, 0.27, 0.3), "amulet_stone", 8, 3, True)
    return s


# --- Putting it together ---

def linear(c):
    return ((c + 0.055) / 1.055) ** 2.4 if c > 0.04045 else c / 12.92


def material_of(label, colour, rough, bright):
    material = bpy.data.materials.new(label)
    material.use_nodes = True
    shader = material.node_tree.nodes["Principled BSDF"]
    shader.inputs["Base Color"].default_value = colour
    shader.inputs["Roughness"].default_value = rough
    if bright:
        shader.inputs["Emission Color"].default_value = colour
        shader.inputs["Emission Strength"].default_value = 1.0
    material.diffuse_color = colour
    material.roughness = rough
    # (wings, legs and plates are flat, and seen from both sides)
    material.use_backface_culling = False
    return material


def mesh_of(name, shape, materials):
    """A mesh of a shape, with only the materials it uses."""
    used = []
    for face in shape.faces:
        if face[1] not in used:
            used.append(face[1])
    exact = any(face[3] is not None for face in shape.faces)
    if exact:
        mesh = exact_mesh(name, shape, used)
    else:
        made = bmesh.new()
        for points, material, smooth, _normals, _uvs in shape.faces:
            verts = [made.verts.new(to_blender(p)) for p in points]
            try:
                face = made.faces.new(verts)
            except ValueError:
                continue
            face.material_index = used.index(material)
            face.smooth = smooth
        # (points that lie together are one point: what is rounded is rounded across them)
        bmesh.ops.remove_doubles(made, verts=made.verts, dist=0.00002)
        # (and every face is turned to face out of the thing it is part of)
        bmesh.ops.recalc_face_normals(made, faces=made.faces)
        mesh = bpy.data.meshes.new(name)
        made.to_mesh(mesh)
        made.free()
    for label in used:
        mesh.materials.append(materials[label])
    return mesh


def exact_mesh(name, shape, used):
    """A mesh every corner of which has the normal and the UV it was given (or, given none, the face's own normal
    and a UV of nothing). Points that lie together are one point."""
    points = []
    found = {}
    faces = []
    normals = []
    uvs = []
    for corners, _material, _smooth, face_normals, face_uvs in shape.faces:
        face = []
        if face_normals is None:
            flat = unit(cross(sub(corners[1], corners[0]), sub(corners[2], corners[0])))
            face_normals = [flat] * len(corners)
        if face_uvs is None:
            face_uvs = [(0.0, 1.0)] * len(corners)
        for k, corner in enumerate(corners):
            key = tuple(round(c, 5) for c in corner)
            if key not in found:
                found[key] = len(points)
                points.append(to_blender(corner))
            face.append(found[key])
            normals.append(to_blender(face_normals[k]))
            uvs.append(face_uvs[k])
        faces.append(face)
    mesh = bpy.data.meshes.new(name)
    mesh.from_pydata(points, [], faces)
    mesh.update()
    if len(mesh.loops) != len(normals):
        raise RuntimeError("%s: a face was not made as it was given" % name)
    layer = mesh.uv_layers.new(name="legs")
    for k, uv in enumerate(uvs):
        layer.data[k].uv = uv
    for k, (_corners, material, _smooth, _n, _u) in enumerate(shape.faces):
        mesh.polygons[k].material_index = used.index(material)
        mesh.polygons[k].use_smooth = True
    mesh.normals_split_custom_set(normals)
    return mesh


def turned(euler, mirrored=False):
    """A turn given as Godot gives it (about Y, then X, then Z, in the game's directions), as Blender's; and the
    same seen in a mirror across the middle of the beetle."""
    x, y, z = euler
    if mirrored:
        y, z = -y, -z
    game = Matrix.Rotation(y, 3, "Y") @ Matrix.Rotation(x, 3, "X") @ Matrix.Rotation(z, 3, "Z")
    swap = Matrix(((1.0, 0.0, 0.0), (0.0, 0.0, -1.0), (0.0, 1.0, 0.0)))
    return (swap @ game @ swap.inverted()).to_euler()


def thing(name, mesh, at=(0.0, 0.0, 0.0), parent=None, mirrored=False, euler=None):
    made = bpy.data.objects.new(name, mesh)
    bpy.context.collection.objects.link(made)
    if mirrored:
        at = (-at[0], at[1], at[2])
        made.scale = (-1.0, 1.0, 1.0)
    made.location = to_blender(at)
    if euler is not None:
        made.rotation_euler = turned(euler, mirrored)
    made.parent = parent
    if mesh is None:
        made.empty_display_size = 0.1
    return made


def build():
    bpy.ops.wm.read_factory_settings(use_empty=True)
    materials = {}
    for label, (srgb, rough, bright) in COLOURS.items():
        materials[label] = material_of(label, tuple(linear(c) for c in srgb) + (1.0,), rough, bright)
    for label, paint in WING_PAINTS.items():
        # (the wings are painted a little under full, and are bright of themselves)
        materials[label] = material_of(label, tuple(c * 0.92 for c in paint) + (1.0,), 1.0, True)
        materials[label + "_shade"] = material_of(label + "_shade", tuple(c * 0.92 * 0.82 for c in paint) + (1.0,), 1.0, True)

    # The big beetle, beside its sun.
    beetle = thing("khepri", None, (0.0, 0.0, -0.75))
    thing("body", mesh_of("body", khepri_body(), materials), parent=beetle)
    thing("head", mesh_of("head", khepri_head(), materials), times(NECK, LONG), beetle)
    case = mesh_of("wing_case", khepri_wing_case(), materials)
    wing = mesh_of("wing", khepri_wing(), materials)
    for side, mirrored in (("left", False), ("right", True)):
        thing("wing_case_" + side, case, times(CASE_HINGE, LONG), beetle, mirrored, CASE_OPEN)
        thing("wing_" + side, wing, times(WING_ROOT, LONG), beetle, mirrored, WING_OUT)
    for which in LEGS:
        leg = mesh_of("leg_" + which, khepri_leg(which), materials)
        for side, mirrored in (("left", False), ("right", True)):
            thing("leg_%s_%s" % (which, side), leg, times((HIP[0], HIP[1], LEGS[which][0]), LONG), beetle, mirrored)
    thing("sun", mesh_of("sun", sun(), materials), (0.0, SUN * 0.5, 0.0))

    # The horizon, off to one side.
    horizon = thing("akhet", None, (3.0, 0.0, 0.0))
    thing("ground", mesh_of("ground", akhet_ground(), materials), parent=horizon)
    hill = mesh_of("hill", akhet_hill(), materials)
    thing("hill_east", hill, (HILL_OUT, 0.0, 0.0), horizon)
    thing("hill_west", hill, (-HILL_OUT, 0.0, 0.0), horizon)
    thing("cradle", mesh_of("cradle", akhet_cradle(), materials), parent=horizon)

    # The small scarab and the amulet, off to the other: a unit long, each.
    thing("scarab", mesh_of("scarab", scarab(), materials), (-2.0, 0.0, 0.0))
    thing("scarab_amulet", mesh_of("scarab_amulet", scarab_amulet(), materials), (-3.5, 0.0, 0.0))

    counts = {}
    for made in bpy.data.objects:
        if made.data is None:
            continue
        made.data.calc_loop_triangles()
        counts[made.name] = len(made.data.loop_triangles)
    os.makedirs(os.path.join(ROOT, "models"), exist_ok=True)
    bpy.ops.wm.save_as_mainfile(filepath=os.path.join(ROOT, "tools", "khepri.blend"))
    bpy.ops.export_scene.gltf(
        filepath=os.path.join(ROOT, "models", "khepri.glb"),
        export_format="GLB",
        export_yup=True,
        export_animations=False,
    )
    under = [made.name for made in bpy.data.objects if made.parent is not None and made.parent.name == "khepri"]
    print("BUILT khepri: the beetle %d triangles, the sun %d, the horizon %d, the small scarab %d, the amulet %d" % (
        sum(counts[n] for n in under), counts["sun"],
        sum(counts[n] for n in ("ground", "hill_east", "hill_west", "cradle")), counts["scarab"], counts["scarab_amulet"]))


build()
