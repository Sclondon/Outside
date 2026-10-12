"""Builds the desert's rock: the formations of the White Desert (mushrooms, domes, haystacks,
cones, shelves, dark outcrops, loose stones), the tomb doorway of the Valley of the Kings with
its rubble walls, spoil heaps and number board, the peak el-Qurn, and the mesas of the far
horizon. It saves them all as tools/rocks.blend, to look at and to change by hand, and exports
models/rocks/rocks.glb, which is what the game reads (scripts/rock_models.gd).

Run from the project root:
    blender --background --python tools/build_rocks.py
then
    godot --headless --path . --import

Or change tools/rocks.blend by hand and export it yourself: File, Export, glTF 2.0, to
models/rocks/rocks.glb, format "glTF Binary", +Y up, and under Data, Mesh, Vertex Colour
"Active". (Running this script again makes the .blend afresh and loses what was changed by hand.)

What the game goes by is the names of the objects:
    mushroom_a ... outcrop_c    a rock formation: the game picks one of a kind by its seed, turns
                                it and makes it the size asked for. Each is built 1 across (its
                                object is scaled up in the .blend only to be looked at: the game
                                takes the mesh as it is and not the object's place or scale).
                                Sand is banked deepest on its +X side: the game turns that downwind.
    stone_a ... stone_d         a loose stone, for scattering among them
    <name>_hull1, _hull2 ...    what is solid of the thing named: the game takes the points of
                                each and makes a hull round them. A thing with none is not solid.
    tomb_door, tomb_door_shut, tomb_door_open, number_board, rubble_wall, spoil_heap_a, _b
                                the doorway (which looks out along +Z, the cliff at its back), what
                                fills it shut or open, and the dig round it
    el_qurn                     the peak, 1 from its middle to its foot
    horizon_mesas               the far hills: a ring 100 from its middle
Materials say what a face is drawn with: `rock` (scripts/rock.gd, which takes the rock's own colour
from the level), `sand` (the sand shader), `dressed` (cut stone), `dark`, `wood`.
The colour of each point of a `rock` face tells the rock shader more: red is how light the rock is
there, green how much sand lies over it, blue is 1 for scree and rubble.

Everything is written in Godot's space: metres, Y up, the front towards +Z.
"""

import math
import os

import bmesh
import bpy

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUT = os.path.join(ROOT, "models", "rocks")
TAU = math.tau

MATERIALS = {
    "rock": (0.80, 0.69, 0.51),
    "sand": (0.83, 0.68, 0.45),
    "dressed": (0.86, 0.79, 0.64),
    "dark": (0.03, 0.03, 0.035),
    "wood": (0.45, 0.33, 0.20),
}

# How high each kind of formation stands, as a share of how far across it is, and its
# outline from the foot up: (how far up, how far out).
TALL = {"mushroom": 1.25, "dome": 0.5, "haystack": 0.95, "cone": 0.8, "shelf": 0.16}
OUTLINES = {
    "mushroom": [(0.0, 0.5), (0.07, 0.36), (0.26, 0.25), (0.44, 0.3), (0.54, 0.5), (0.6, 0.96), (0.68, 1.0), (0.8, 0.9), (0.92, 0.58), (1.0, 0.0)],
    "dome": [(0.0, 0.9), (0.06, 0.83), (0.13, 1.0), (0.34, 0.97), (0.56, 0.84), (0.76, 0.62), (0.91, 0.36), (1.0, 0.0)],
    "haystack": [(0.0, 0.84), (0.04, 0.76), (0.09, 0.97), (0.36, 1.0), (0.62, 0.9), (0.81, 0.68), (0.94, 0.38), (1.0, 0.0)],
    "cone": [(0.0, 0.98), (0.05, 0.9), (0.1, 1.0), (0.5, 0.56), (0.86, 0.2), (1.0, 0.0)],
    "shelf": [(0.0, 0.94), (0.3, 0.9), (0.4, 1.0), (0.93, 0.97), (1.0, 0.9)],
}
# How big each is shown in the .blend (the game makes them whatever size is asked for).
SHOWN = {"mushroom": 5.0, "dome": 7.0, "haystack": 5.0, "cone": 4.0, "shelf": 8.0, "outcrop": 7.0, "stone": 0.6}


def chance(a, b):
    """A number from 0 to 1 made from two whole numbers: the same every time."""
    n = (a * 374761393 + b * 668265263) & 0x7FFFFFFF
    n = ((n ^ (n >> 13)) * 1274126177) & 0x7FFFFFFF
    return ((n ^ (n >> 16)) & 0xFFFF) / 65535.0


def rough(x, z):
    """Smooth unevenness, 0..1, over a plane."""
    wx, wz = math.floor(x), math.floor(z)
    px, pz = x - wx, z - wz
    px, pz = px * px * (3 - 2 * px), pz * pz * (3 - 2 * pz)
    a = chance(wx, wz) + (chance(wx + 1, wz) - chance(wx, wz)) * px
    b = chance(wx, wz + 1) + (chance(wx + 1, wz + 1) - chance(wx, wz + 1)) * px
    return a + (b - a) * pz


class Model:
    """One thing: its points (each with the colour the rock shader reads), its faces, and what is solid of it."""

    def __init__(self, name, shown=1.0):
        self.name = name
        self.shown = shown
        self.points = []
        self.colours = []
        self.faces = []  # (indices, material, smooth)
        self.sharp = set()
        self.hulls = []

    def point(self, x, y, z, light=1.0, sandy=0.0, rubble=0.0):
        self.points.append((x, y, z))
        self.colours.append((light, sandy, rubble, 1.0))
        return len(self.points) - 1

    def face(self, indices, material="rock", smooth=False):
        self.faces.append((list(indices), material, smooth))

    def skin(self, rings, material="rock", edged=True):
        """A skin over rings of points, one above the next, each going from +x towards +z: smooth
        round each ring, and (with `edged`) with an edge where one band meets the next. A ring
        of one point closes the top."""
        for low, high in zip(rings, rings[1:]):
            count = len(low)
            for j in range(count):
                k = (j + 1) % count
                if len(high) == 1:
                    self.face([low[k], low[j], high[0]], material, True)
                else:
                    self.face([low[k], low[j], high[j], high[k]], material, True)
                if edged:
                    self.sharp.add(frozenset((low[j], low[k])))
                    if len(high) > 1:
                        self.sharp.add(frozenset((high[j], high[k])))

    def block(self, middle, size, key, wobble=0.3, turn=0.0, tip=(0.0, 0.0), light=1.0, sandy=0.0, rubble=0.0, material="rock"):
        """A block, each corner moved a little so that no two are alike. Says where its corners are."""
        corners = []
        for i in range(8):
            c = [(-0.5 if i & 1 == 0 else 0.5), (-0.5 if i & 2 == 0 else 0.5), (-0.5 if i & 4 == 0 else 0.5)]
            for axis in range(3):
                c[axis] = (c[axis] + (chance(key, i * 3 + axis) - 0.5) * wobble) * size[axis]
            # tipped about x and z, then turned about y
            x, y, z = c
            y, z = y * math.cos(tip[0]) - z * math.sin(tip[0]), y * math.sin(tip[0]) + z * math.cos(tip[0])
            x, y = x * math.cos(tip[1]) - y * math.sin(tip[1]), x * math.sin(tip[1]) + y * math.cos(tip[1])
            x, z = x * math.cos(turn) + z * math.sin(turn), -x * math.sin(turn) + z * math.cos(turn)
            corners.append((middle[0] + x, middle[1] + y, middle[2] + z))
        for order in ([0, 2, 3, 1], [4, 5, 7, 6], [0, 1, 5, 4], [2, 6, 7, 3], [0, 4, 6, 2], [1, 3, 7, 5]):
            # (the top a little lighter, and dusted)
            top = order == [2, 6, 7, 3]
            self.face([self.point(*corners[i], light=min(light * (1.06 if top else 1.0), 1.0), sandy=max(sandy, 0.3 if top else 0.0), rubble=rubble) for i in order], material)
        return corners

    def box(self, low, high, material="rock", light=1.0, sandy=0.0, rubble=0.0):
        """A plain box from one corner to the other."""
        middle = [(low[i] + high[i]) * 0.5 for i in range(3)]
        size = [high[i] - low[i] for i in range(3)]
        return self.block(middle, size, 0, 0.0, light=light, sandy=sandy, rubble=rubble, material=material)

    def hull(self, points):
        self.hulls.append(list(points))


def formation(m, kind, seed):
    """A lump of rock 1 across with its foot at the origin: see scripts/rock_formation.gd."""
    half = 0.5
    tall = TALL[kind]
    sunk = 0.3
    segments = 10
    long_way = chance(seed, 11) * TAU
    stretch = (0.3 if kind == "shelf" else 0.16) * chance(seed, 12)
    lumps = 0.42 if kind == "shelf" else 0.26
    lean_way = chance(seed, 13) * TAU
    lean = half * (0.3 if kind == "mushroom" else 0.1) * chance(seed, 14)

    def out_at(angle, up, far):
        lump = rough(math.cos(angle) * 1.5 + seed * 3.17 + up * 1.3, math.sin(angle) * 1.5 + seed * 1.31) - 0.5
        return half * far * (1.0 + stretch * math.cos(2.0 * (angle - long_way))) * (1.0 + lump * lumps * 2.0)

    # The outline, with a ledge wherever one bed ends and the next begins.
    plan = OUTLINES[kind]
    beds = 2 + int(chance(seed, 15) * 2.99)
    outline = [(-sunk / tall, plan[0][1], False)]
    for i, (up, far) in enumerate(plan):
        outline.append((up, far, False))
        if i + 1 < len(plan) and kind != "shelf" and up >= 0.09 and plan[i + 1][1] > 0.0:
            parts = int(round((plan[i + 1][0] - up) * beds))
            for part in range(1, parts):
                share = part / parts
                outline.append((up + (plan[i + 1][0] - up) * share, far + (plan[i + 1][1] - far) * share, True))
    rings = []
    heights = []
    for up, far, bed in outline:
        for ledge in range(2 if bed else 1):
            reach = far * ((1.04 if ledge == 0 else 0.94) if bed else 1.0)
            off = lean * max(up, 0.0) ** 2
            mx, mz = math.cos(lean_way) * off, math.sin(lean_way) * off
            light = 0.84 + 0.16 * chance(seed, 40 + len(rings))
            if reach <= 0.0:
                ring = [m.point(mx, up * tall, mz, light, 0.3)]
            else:
                ring = []
                for j in range(segments):
                    angle = TAU * j / segments
                    r = out_at(angle, up * 2.0, reach)
                    ring.append(m.point(mx + math.cos(angle) * r, up * tall + ledge * 0.012 * tall, mz + math.sin(angle) * r, light, 0.45 if up < 0.03 else 0.0))
            rings.append(ring)
            heights.append(up)
    if kind == "shelf":
        # (its top is closed, and nearly flat: it is walked on)
        rings.append([m.point(0.0, tall * 1.03, 0.0, 1.0, 0.25)])
        heights.append(1.0)
    m.skin(rings)
    # What is solid: a hull round every other point of its rings. A mushroom is two, its stalk
    # and its cap, so that he can stand under the cap.
    for low, high in ([(-1.0, 0.5), (0.5, 2.0)] if kind == "mushroom" else [(-1.0, 2.0)]):
        m.hull([m.points[i] for ring, up in zip(rings, heights) if low <= up < high for i in (ring[::2] if len(ring) > 1 else ring)])
    bank(m, lambda angle: out_at(angle, 0.0, 0.5 if kind == "mushroom" else plan[0][1]), segments)


def bank(m, reach_at, segments, high=0.085):
    """Sand banked up round a foot: a low slope, higher and longer on the +X side (the lee)."""
    foot, mid, against = [], [], []
    for j in range(segments):
        angle = TAU * j / segments
        lee = max(math.cos(angle), 0.0)
        reach = reach_at(angle)
        up = high * (0.5 + 1.0 * lee) * (0.8 + 0.4 * chance(j, 17))
        run = up * 4.5 + reach * 0.45 * lee
        against.append(m.point(math.cos(angle) * reach * 0.98, up, math.sin(angle) * reach * 0.98))
        # (hollow, as a drift is: steep against the rock and running out thin)
        mid.append(m.point(math.cos(angle) * (reach + run * 0.4), up * 0.36, math.sin(angle) * (reach + run * 0.4)))
        foot.append(m.point(math.cos(angle) * (reach + run), -0.03, math.sin(angle) * (reach + run)))
    m.skin([foot, mid, against], "sand", False)
    m.hull([m.points[i] for i in foot + against])


def outcrop(m, seed):
    """Broken blocks of hard rock standing out of a low heap of their own rubble, 1 across."""
    half, tall = 0.5, 0.42
    # A few big blocks about the middle, and smaller ones tumbled round them.
    count = 11 + int(chance(seed, 21) * 5.99)
    for i in range(count):
        big = i < 3
        angle = TAU * (i * 0.382 + 0.2 * chance(seed, 30 + i))
        out = half * (0.3 * chance(seed, 50 + i) if big else 0.3 + 0.62 * chance(seed, 50 + i))
        wide = half * ((0.36 + 0.3 * chance(seed, 70 + i)) if big else (0.12 + 0.2 * chance(seed, 70 + i)))
        high = tall * (0.55 + 0.45 * chance(seed, 90 + i)) if big else wide * (0.5 + 0.6 * chance(seed, 90 + i))
        down = high * 0.4 + 0.04
        lift = 0.0 if big else tall * 0.22 * max(1.0 - out / half, 0.0)
        corners = m.block((math.cos(angle) * out, (high - down) * 0.5 + lift, math.sin(angle) * out),
                          (wide, high + down, wide * (0.55 + 0.45 * chance(seed, 190 + i))), seed * 31 + i, 0.38,
                          chance(seed, 130 + i) * TAU, ((chance(seed, 110 + i) - 0.5) * 0.9, (chance(seed, 150 + i) - 0.5) * 0.9),
                          light=0.72 + 0.28 * chance(seed, 170 + i))
        if big or wide > half * 0.2:
            m.hull(corners)
    heap(m, 0.0, 0.0, half * 1.08, tall * 0.34, seed, 11)
    bank(m, lambda angle: half * 1.04, 10, 0.05)


def heap(m, x, z, reach, high, seed, segments=10, light=0.86, sandy=0.18):
    """A low heap of rubble."""
    low, mid = [], []
    for j in range(segments):
        angle = TAU * j / segments
        r = reach * (0.86 + 0.28 * chance(seed, 210 + j))
        low.append(m.point(x + math.cos(angle) * r, -0.06, z + math.sin(angle) * r, light, sandy, 1.0))
        mid.append(m.point(x + math.cos(angle) * r * 0.5, high * (0.6 + 0.25 * chance(seed, 230 + j)), z + math.sin(angle) * r * 0.5, light, sandy, 1.0))
    top = [m.point(x, high, z, light, sandy, 1.0)]
    m.skin([low, mid, top], "rock", False)
    m.hull([m.points[i] for i in low + mid + top])


def tomb_door(m):
    """A rock-cut doorway: a square-cut entrance under a lintel, a ramp of chippings up to its
    sill and a stair of three steps down inside to the door itself, and a dry-stone wall each
    side of the ramp, holding the spoil back. It looks out along +Z; the cliff is at its back (z = 0)."""
    sill = 0.6
    # The living rock each side of it and over it, left rough.
    for side in (-1, 1):
        m.hull(m.block((side * 1.95, 1.35, 0.7), (1.2, 3.9, 1.5), 7 + side, 0.12, light=0.93))
        # the jamb, cut square
        m.hull(m.box((side * 0.85 if side > 0 else -1.4, -0.6, 0.0), (1.4 if side > 0 else -0.85, sill + 2.25, 1.55), "dressed"))
    m.hull(m.box((-1.65, sill + 2.2, 0.0), (1.65, sill + 2.85, 1.7), "dressed"))
    m.hull(m.block((0.0, sill + 3.2, 0.65), (4.6, 0.9, 1.5), 12, 0.14, light=0.9))
    # The stair down inside, to the door.
    for step in range(3):
        m.box((-0.85, -0.6, 1.5 - (step + 1) * 0.46), (0.85, sill - step * 0.2, 1.5 - step * 0.46), "dressed", light=0.9 - step * 0.12)
    m.hull([(-0.85, -0.6, 0.1), (0.85, -0.6, 0.1), (-0.85, sill - 0.42, 0.1), (0.85, sill - 0.42, 0.1), (-0.85, sill, 1.5), (0.85, sill, 1.5), (-0.85, -0.6, 1.5), (0.85, -0.6, 1.5)])
    # The ramp of chippings up to the sill.
    ramp = [m.point(x, y, z, 0.9, 0.3, 1.0) for x, y, z in ((-1.25, sill, 1.5), (1.25, sill, 1.5), (1.5, -0.12, 4.6), (-1.5, -0.12, 4.6))]
    m.face([ramp[3], ramp[2], ramp[1], ramp[0]])
    m.hull([(-1.25, sill, 1.5), (1.25, sill, 1.5), (1.5, -0.12, 4.6), (-1.5, -0.12, 4.6), (-1.25, -0.6, 1.5), (1.25, -0.6, 1.5), (1.5, -0.6, 4.6), (-1.5, -0.6, 4.6)])
    # A dry-stone wall each side: courses of rough blocks, lower as it runs out.
    for side in (-1, 1):
        for course in range(4):
            long = 4.4 - course * 0.95
            stones = max(int(long / 0.8), 1)
            for i in range(stones):
                key = 300 + (side + 1) * 50 + course * 10 + i
                m.block((side * (1.85 + 0.06 * (chance(key, 1) - 0.5)), course * 0.36 + 0.14, 1.75 + (i + 0.5) * long / stones),
                        (0.6, 0.38, long / stones * 0.98), key, 0.2, light=0.8 + 0.2 * chance(key, 2), rubble=0.0)
        m.hull([(side * 1.55, -0.4, 1.5), (side * 2.15, -0.4, 1.5), (side * 1.55, 1.45, 1.5), (side * 2.15, 1.45, 1.5),
                (side * 1.55, -0.4, 5.9), (side * 2.15, -0.4, 5.9), (side * 1.55, 0.36, 5.9), (side * 2.15, 0.36, 5.9), (side * 1.55, 1.45, 3.0), (side * 2.15, 1.45, 3.0)])


def tomb_door_shut(m):
    """What fills a doorway that has not been opened: rough stones laid dry, plastered over above."""
    for row in range(6):
        for i in range(3):
            key = 500 + row * 7 + i
            offset = 0.28 if row % 2 else 0.0
            m.block((-0.57 + i * 0.57 + offset - 0.14, 0.2 + row * 0.38 + 0.19, 0.2), (0.6, 0.4, 0.3), key, 0.16, light=0.78 + 0.22 * chance(key, 1))
    m.box((-0.85, 2.3, 0.1), (0.85, 2.82, 0.24), "dressed", light=0.96)
    m.hull([(-0.85, 0.0, 0.05), (0.85, 0.0, 0.05), (-0.85, 2.82, 0.05), (0.85, 2.82, 0.05), (-0.85, 0.0, 0.36), (0.85, 0.0, 0.36), (-0.85, 2.82, 0.36), (0.85, 2.82, 0.36)])


def tomb_door_open(m):
    """What is seen through a doorway that has been opened: the dark, and the top of a stair going down into it."""
    back = [m.point(x, y, 0.06) for x, y in ((-0.85, 0.0), (0.85, 0.0), (0.85, 2.82), (-0.85, 2.82))]
    m.face(back, "dark")
    for step in range(2):
        m.box((-0.85, 0.0, 0.06), (0.85, 0.2 - step * 0.12, 0.1 + (1 - step) * 0.02 + 0.05), "dressed", light=0.3 - step * 0.12)


def number_board(m):
    """A post with a board on it, for a tomb's number. The board looks along +Z; its middle is at (0, 0.95, 0.03)."""
    m.box((-0.035, -0.3, -0.035), (0.035, 1.12, 0.035), "wood")
    m.box((-0.3, 0.78, 0.02), (0.3, 1.12, 0.05), "wood", light=0.95)


def rubble_wall(m):
    """A length of dry-stone wall such as the diggers built to hold their spoil back: 4 long, along X."""
    for course in range(3):
        long = 4.0 - course * 0.7
        stones = int(long / 0.75)
        for i in range(stones):
            key = 700 + course * 10 + i
            m.block((-long * 0.5 + (i + 0.5) * long / stones, course * 0.36 + 0.14, 0.06 * (chance(key, 1) - 0.5)),
                    (long / stones * 0.98, 0.38, 0.62), key, 0.2, light=0.8 + 0.2 * chance(key, 2))
    m.hull([(-2.0, -0.4, -0.32), (2.0, -0.4, -0.32), (-2.0, -0.4, 0.32), (2.0, -0.4, 0.32), (-1.5, 1.05, -0.32), (1.5, 1.05, -0.32), (-1.5, 1.05, 0.32), (1.5, 1.05, 0.32)])


def spoil_heap(m, seed):
    """A heap of chippings tipped out of a tomb: two or three cones run together, 1 across."""
    for i in range(2 + seed % 2):
        angle = chance(seed, i) * TAU
        out = 0.22 * (i > 0)
        heap(m, math.cos(angle) * out, math.sin(angle) * out, 0.5 - 0.12 * i, 0.3 - 0.07 * i, seed * 13 + i, 10, 0.92, 0.12)


def el_qurn(m):
    """The peak over the valley: a pyramid of rock in ledges, 1 from its middle to its foot, 0.95 high."""
    plan = [(-0.12, 1.06), (0.0, 1.0), (0.1, 0.9), (0.2, 0.8), (0.34, 0.6), (0.48, 0.5), (0.62, 0.33), (0.76, 0.24), (0.9, 0.1), (1.0, 0.0)]
    segments = 16
    rings = []
    for index, (up, far) in enumerate(plan):
        # (a ledge at every other bed: the harder ones)
        bed = 0 < index < len(plan) - 1 and index % 2 == 0
        for ledge in range(2 if bed else 1):
            reach = far * (1.04 if ledge == 0 else 0.9) if bed else far
            light = 0.84 + 0.16 * chance(77, index * 2 + ledge)
            if reach <= 0.0:
                rings.append([m.point(0.03, up * 0.95, -0.02, light)])
                continue
            ring = []
            for j in range(segments):
                angle = TAU * j / segments
                # (four-sided, with its corners rounded: the shape that made them call it a pyramid)
                square = 1.0 / (abs(math.cos(angle + 0.5)) ** 1.5 + abs(math.sin(angle + 0.5)) ** 1.5) ** (1.0 / 1.5)
                lump = rough(math.cos(angle) * 2.0 + up * 3.0, math.sin(angle) * 2.0 + 9.0) - 0.5
                r = reach * square * (1.0 + lump * 0.5)
                # (its beds do not lie quite level, and it leans a little to one side)
                dip = (rough(math.cos(angle) * 1.3 + 4.0, math.sin(angle) * 1.3 + up * 2.0) - 0.5) * 0.07 * (1.0 - up)
                ring.append(m.point(math.cos(angle) * r + 0.1 * up * up, max(up + dip, -0.12) * 0.95 + ledge * 0.01, math.sin(angle) * r - 0.06 * up * up, light,
                                    0.5 if up < 0.02 else 0.0, 1.0 if up < 0.11 else 0.0))
            rings.append(ring)
    m.skin(rings)
    m.hull([m.points[i] for ring in rings for i in (ring[::2] if len(ring) > 1 else ring)])


def plateau(m, edge, high, scree, key):
    """A flat-topped hill: `edge` is the edge of its top (x, z), going round with the rock on the left."""
    count = len(edge)
    outs = []
    for i in range(count):
        ax, az = edge[(i + 1) % count][0] - edge[i - 1][0], edge[(i + 1) % count][1] - edge[i - 1][1]
        long = math.hypot(ax, az) or 1.0
        outs.append((az / long, -ax / long))
    tops, mids, feet = [], [], []
    for i, ((x, z), (ox, oz)) in enumerate(zip(edge, outs)):
        light = 0.82 + 0.18 * chance(key, i)
        band = high * scree * (0.8 + 0.4 * chance(key, 100 + i))
        tops.append(m.point(x, high, z, light))
        mids.append(m.point(x + ox * high * 0.06, band, z + oz * high * 0.06, light))
        feet.append(m.point(x + ox * (high * 0.06 + band * 1.5), -0.5, z + oz * (high * 0.06 + band * 1.5), 0.86, 0.3, 1.0))
    for i in range(count):
        k = (i + 1) % count
        m.face([tops[k], tops[i], mids[i], mids[k]])
        m.face([mids[k], mids[i], feet[i], feet[k]])
    m.face(list(reversed([m.point(x, high, z, 1.0, 0.3) for x, z in edge])))


def horizon_mesas(m):
    """The far hills: mesas and buttes standing round the level, and a low escarpment behind them. A ring 100 from its middle."""
    hills = 11
    for i in range(hills):
        middle = TAU * (i + 0.7 * chance(i, 900)) / hills
        wide = 0.05 + 0.2 * chance(i, 901) ** 2
        near = 92.0 + 26.0 * chance(i, 902)
        deep = 5.0 + 60.0 * wide
        high = 4.0 + 5.5 * chance(i, 904)
        steps = 5 if wide < 0.12 else 9
        front, back = [], []
        for s in range(steps + 1):
            angle = middle + wide * (s / steps * 2.0 - 1.0)
            wobble = (rough(angle * 9.0, i * 3.1) - 0.5) * 6.0
            # (its ends are rounded off)
            ends = 1.0 - (abs(s / steps * 2.0 - 1.0) ** 3) * 0.5
            front.append((math.cos(angle) * (near + wobble + deep * (1 - ends)), math.sin(angle) * (near + wobble + deep * (1 - ends))))
            back.append((math.cos(angle) * (near + wobble + deep * ends), math.sin(angle) * (near + wobble + deep * ends)))
        plateau(m, front + list(reversed(back)), high, 0.5, 1000 + i * 37)
    # The escarpment behind: the edge of the high desert, all the way round.
    ring = 72
    tops, mids, feet = [], [], []
    for s in range(ring):
        angle = TAU * s / ring
        near = 138.0 + (rough(math.cos(angle) * 3.0 + 5.0, math.sin(angle) * 3.0) - 0.5) * 22.0
        high = 3.0 + 4.0 * rough(math.cos(angle) * 5.0, math.sin(angle) * 5.0 + 3.0)
        light = 0.82 + 0.18 * chance(s, 950)
        tops.append(m.point(math.cos(angle) * near, high, math.sin(angle) * near, light))
        mids.append(m.point(math.cos(angle) * (near - 0.4), high * 0.45, math.sin(angle) * (near - 0.4), light))
        feet.append(m.point(math.cos(angle) * (near - high * 0.8), -0.5, math.sin(angle) * (near - high * 0.8), 0.86, 0.3, 1.0))
    back = [m.point(math.cos(TAU * s / ring) * 190.0, 3.0, math.sin(TAU * s / ring) * 190.0, 1.0, 0.4) for s in range(ring)]
    for s in range(ring):
        k = (s + 1) % ring
        m.face([tops[k], tops[s], mids[s], mids[k]])
        m.face([mids[k], mids[s], feet[s], feet[k]])
        m.face([tops[k], tops[s], back[s], back[k]])


# --- Into Blender, and out ---

MADE_MATERIALS = {}


def linear(c):
    return ((c + 0.055) / 1.055) ** 2.4 if c > 0.04045 else c / 12.92


def material_for(name):
    if name not in MADE_MATERIALS:
        material = bpy.data.materials.new(name)
        material.use_nodes = True
        colour = tuple(linear(c) for c in MATERIALS[name]) + (1.0,)
        shader = material.node_tree.nodes["Principled BSDF"]
        shader.inputs["Base Color"].default_value = colour
        shader.inputs["Roughness"].default_value = 1.0
        material.diffuse_color = colour
        MADE_MATERIALS[name] = material
    return MADE_MATERIALS[name]


def swap(point):
    # Godot's space (Y up, front towards +Z) into Blender's (Z up, front towards -Y)
    return (point[0], -point[2], point[1])


def put(m, column, row):
    """Makes a model's objects: the thing itself, and a wire hull for each piece of it that is solid."""
    mesh = bpy.data.meshes.new(m.name)
    made = bmesh.new()
    colours = made.loops.layers.float_color.new("kind")
    points = [made.verts.new(swap(p)) for p in m.points]
    slots = []
    triangles = 0
    for indices, material, smooth in m.faces:
        try:
            face = made.faces.new([points[i] for i in indices])
        except ValueError:
            continue
        if material not in slots:
            slots.append(material)
        face.material_index = slots.index(material)
        face.smooth = smooth
        for loop, i in zip(face.loops, indices):
            loop[colours] = m.colours[i]
        triangles += len(indices) - 2
    for pair in m.sharp:
        a, b = tuple(pair)
        edge = made.edges.get((points[a], points[b]))
        if edge:
            edge.smooth = False
    made.normal_update()
    made.to_mesh(mesh)
    made.free()
    mesh.color_attributes.active_color = mesh.color_attributes["kind"]
    mesh.color_attributes.render_color_index = 0
    for name in slots:
        mesh.materials.append(material_for(name))
    thing = bpy.data.objects.new(m.name, mesh)
    bpy.context.collection.objects.link(thing)
    place = (column * 12.0, row * 14.0, 0.0)
    thing.location = place
    thing.scale = (m.shown, m.shown, m.shown)
    for index, hull in enumerate(m.hulls):
        solid = bmesh.new()
        for point in hull:
            solid.verts.new(swap(point))
        bmesh.ops.convex_hull(solid, input=solid.verts)
        hull_mesh = bpy.data.meshes.new("%s_hull%d" % (m.name, index + 1))
        solid.to_mesh(hull_mesh)
        solid.free()
        shown = bpy.data.objects.new(hull_mesh.name, hull_mesh)
        bpy.context.collection.objects.link(shown)
        shown.location = place
        shown.scale = thing.scale
        shown.display_type = "WIRE"
        shown.hide_render = True
    print("BUILT %-16s tris=%5d hulls=%d" % (m.name, triangles, len(m.hulls)))
    return triangles


def main():
    os.makedirs(OUT, exist_ok=True)
    bpy.ops.wm.read_factory_settings(use_empty=True)
    total = 0
    row = 0
    for kind, seeds in (("mushroom", (3, 8, 21)), ("dome", (1, 5, 9, 14)), ("haystack", (2, 6, 17)), ("cone", (4, 11)), ("shelf", (7, 12, 19))):
        for column, seed in enumerate(seeds):
            m = Model("%s_%s" % (kind, "abcdef"[column]), SHOWN[kind])
            formation(m, kind, seed)
            total += put(m, column, row)
        row += 1
    for column, seed in enumerate((5, 13, 22)):
        m = Model("outcrop_%s" % "abc"[column], SHOWN["outcrop"])
        outcrop(m, seed)
        total += put(m, column, row)
    row += 1
    for column, seed in enumerate((31, 32, 33, 34)):
        m = Model("stone_%s" % "abcd"[column], SHOWN["stone"])
        m.block((0.0, 0.2, 0.0), (1.0, 0.55, 0.6 + 0.4 * chance(seed, 9)), seed, 0.4, light=0.92)
        total += put(m, column * 0.25, row)
    row += 1
    for column, (name, make) in enumerate((("tomb_door", tomb_door), ("tomb_door_shut", tomb_door_shut), ("tomb_door_open", tomb_door_open),
                                           ("number_board", number_board), ("rubble_wall", rubble_wall))):
        m = Model(name)
        make(m)
        total += put(m, column, row)
    for column, seed in enumerate((41, 42)):
        m = Model("spoil_heap_%s" % "ab"[column], 5.0)
        spoil_heap(m, seed)
        total += put(m, 5 + column, row)
    row += 1
    m = Model("el_qurn", 22.0)
    el_qurn(m)
    total += put(m, 2, row + 2)
    m = Model("horizon_mesas")
    horizon_mesas(m)
    total += put(m, 2, row + 22)
    bpy.ops.wm.save_as_mainfile(filepath=os.path.join(ROOT, "tools", "rocks.blend"))
    bpy.ops.export_scene.gltf(
        filepath=os.path.join(OUT, "rocks.glb"),
        export_format="GLB",
        export_yup=True,
        export_animations=False,
        export_vertex_color="ACTIVE",
    )
    print("BUILT: %d triangles in all" % total)


main()
