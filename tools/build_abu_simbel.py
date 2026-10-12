"""Builds the models of Abu Simbel: tools/abu_simbel.blend, to look at and to change by hand,
and models/abu_simbel/abu_simbel.glb, which is what the game loads (scripts/abu_simbel.gd finds
each part in it by the name of its object, and sets them out).

Run from the project root:
    blender --background --python tools/build_abu_simbel.py              # make everything again from the numbers here
    blender --background tools/abu_simbel.blend --python tools/build_abu_simbel.py -- export
                                                                         # only write the .glb again from the .blend as it is (after changing it by hand)
then
    godot --headless --path . --import

Everything is written in Godot's space: metres, true size, Y up. A figure faces +Z and stands
on y = 0; a seated one has its back to the plane z = 0. A temple's parts are made about the
foot of its own door, the facade looking along +Z. Each point carries a colour that the stone
shader reads (scripts/sandstone.gd): red is how light the stone is there, green 1 where it is
laid in courses (or, inside, where the battle is carved), blue 1 for rough rock (a half, inside,
is a ceiling).

The objects:
    colossus            a seated colossus of Ramesses II, 20 m, with the three small figures at his legs
    colossus_broken     the same from the waist down: the second from the left
    colossus_fallen     his body and head, as they lie before him (made upright; the game lays them down)
    crown_fallen        the double crown that came off them
    small_figure        one of the family, one unit high: the princesses between the colossi, the kings on the balustrade
    baboon, falcon      one unit high: the row along the top of the facade, and the terrace
    ra_horakhty         the falcon-headed god of the niche, one unit high to the top of the head
    king_standing, queen_standing     the colossi of the small temple, one unit high to the top of the head
    osiride_pillar      a pillar of the great hall with the king as Osiris on its front (+Z)
    square_pillar       a pillar of the second hall
    hathor_pillar       a pillar of the small temple with the head of Hathor on its front (+Z)
    god_ptah, god_amun, god_king, god_ra    the four of the sanctuary, made 20 m high (the game draws them small)
    cow                 the cow of Hathor coming out of the rock, one unit high
    great_hill, small_hill, ridge     the rock: each temple's hill with the cut for its facade, and the ridge that joins them
    great_facade, small_facade        the carved front of each, its terrace and steps
    great_inside, small_inside        the halls, passages and rooms cut into each hill, seen from within
In the .blend the parts of each temple lie where they belong, and the figures stand in rows in front.
What is solid is not in here: scripts/abu_simbel.gd makes it, from boxes.
"""

import math
import os
import random
import sys

import bpy
from mathutils import Matrix, Vector

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUT = os.path.join(ROOT, "models", "abu_simbel")
BLEND = os.path.join(ROOT, "tools", "abu_simbel.blend")
ARGS = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []

TAU = math.tau
RIGHT, UP, BACK = Vector((1, 0, 0)), Vector((0, 1, 0)), Vector((0, 0, 1))
LEFT, DOWN, FORWARD = -RIGHT, -UP, -BACK
# Where the small temple stands from the great one (the game puts it there too).
NORTH = Matrix.Translation((100.0, 0.0, 6.0)) @ Matrix.Rotation(math.radians(-14.0), 4, "Y")

# The seated colossus, in metres (scripts/abu_simbel.gd has the same numbers, for what is solid).
SEATED = {"base_half": 3.5, "base_top": 1.5, "base_front": 8.0, "throne_half": 3.1, "seat": 6.4, "lap": 8.1, "knee_front": 6.2, "shoulder": 13.0}


def V(x, y, z):
    return Vector((x, y, z))


def smoothstep(a, b, x):
    if a == b:
        return 0.0 if x < a else 1.0
    t = min(max((x - a) / (b - a), 0.0), 1.0)
    return t * t * (3.0 - 2.0 * t)


def lerp(a, b, t):
    return a + (b - a) * t


def sign(x):
    return -1.0 if x < 0.0 else (1.0 if x > 0.0 else 0.0)


def moved(scale, at):
    """A place: scaled the same every way, then moved."""
    return Matrix.Translation(at) @ Matrix.Scale(scale, 4)


def turned(angle, at=(0, 0, 0), scale=1.0):
    return Matrix.Translation(at) @ Matrix.Rotation(angle, 4, "Y") @ Matrix.Scale(scale, 4)


class Sculpt:
    """Stone shaped by numbers: gathers points and faces, each put through `place` as it is added."""

    def __init__(self):
        self.verts = []
        self.faces = []      # (indices, smooth, tones)
        self.place = Matrix.Identity(4)
        self.tint = (1.0, 0.0, 1.0)

    def count(self):
        return sum(len(f[0]) - 2 for f in self.faces)

    def _add(self, points):
        start = len(self.verts)
        for p in points:
            self.verts.append(self.place @ p)
        return start

    def _face(self, indices, smooth, tone=1.0):
        if self.place.determinant() < 0.0:
            indices = list(reversed(indices))
        points = [self.verts[i] for i in indices]
        keep = [i for n, i in enumerate(indices) if (points[n] - points[n - 1]).length > 1e-6]
        if len(keep) >= 3:
            self.faces.append((keep, smooth, (self.tint[0] * tone, self.tint[1], self.tint[2])))

    def quad(self, a, b, c, d):
        """A flat face, its corners anticlockwise seen from outside."""
        start = self._add([a, b, c, d])
        self._face([start, start + 1, start + 2, start + 3], False)

    def face(self, a, b, c, d, out):
        """A flat face seen from the side `out` points to."""
        if (b - a).cross(c - a).dot(out) < 0.0 or ((b - a).cross(c - a).length < 1e-9 and (c - a).cross(d - a).dot(out) < 0.0):
            self.quad(a, d, c, b)
        else:
            self.quad(a, b, c, d)

    def block(self, c, open_="b"):
        """Eight corners: four round the bottom (anticlockwise from above) and the four above them."""
        for i in range(4):
            j = (i + 1) % 4
            self.quad(c[i], c[j], c[j + 4], c[i + 4])
        if "t" not in open_:
            self.quad(c[4], c[5], c[6], c[7])
        if "b" not in open_:
            self.quad(c[3], c[2], c[1], c[0])

    def box(self, low, high, open_="b", top=(1.0, 1.0), lean=None):
        lean = lean or V(0, 0, 0)
        mid = (low + high) * 0.5
        half = (high - low) * 0.5
        hx, hz = half.x * top[0], half.z * top[1]
        self.block([V(low.x, low.y, high.z), V(high.x, low.y, high.z), V(high.x, low.y, low.z), V(low.x, low.y, low.z),
                    V(mid.x - hx, high.y, mid.z + hz) + lean, V(mid.x + hx, high.y, mid.z + hz) + lean,
                    V(mid.x + hx, high.y, mid.z - hz) + lean, V(mid.x - hx, high.y, mid.z - hz) + lean], open_)

    def skin(self, rows, closed=True, ends=3, out=None, tones=None):
        """A sheet of points, rows[i][j], joined into a smooth skin; `closed` makes each row a ring."""
        n, m = len(rows), len(rows[0])
        middle = V(0, 0, 0)
        for row in rows:
            for p in row:
                middle += p
        middle /= n * m
        agree = 0.0
        for i in range(n):
            for j in range(m):
                nxt = (j + 1) % m if closed else min(j + 1, m - 1)
                lst = (j - 1) % m if closed else max(j - 1, 0)
                normal = (rows[i][nxt] - rows[i][lst]).cross(rows[min(i + 1, n - 1)][j] - rows[max(i - 1, 0)][j])
                if normal.length > 1e-9:
                    agree += normal.normalized().dot(out if out is not None else rows[i][j] - middle)
        start = self._add([p for row in rows for p in row])
        for i in range(n - 1):
            for j in range(m if closed else m - 1):
                k = (j + 1) % m
                a, b, c, d = start + i * m + j, start + i * m + k, start + (i + 1) * m + k, start + (i + 1) * m + j
                tone = 1.0 if tones is None else (tones[i][j] + tones[i][k] + tones[i + 1][j] + tones[i + 1][k]) * 0.25
                self._face([a, b, c, d] if agree >= 0.0 else [b, a, d, c], True, tone)
        if closed:
            for end in range(2):
                if not ends & (1 << end):
                    continue
                row = rows[0 if end == 0 else n - 1]
                other = rows[1 if end == 0 else n - 2]
                centre = sum(row, V(0, 0, 0)) / m
                away = centre - sum(other, V(0, 0, 0)) / m
                ring = self._add(row)
                order = list(range(ring, ring + m))
                normal = (row[0] - centre).cross(row[1] - centre)
                self._face(order if normal.dot(away) >= 0.0 else list(reversed(order)), False)

    @staticmethod
    def ring(centre, across, along, sides, power=2.0):
        made = []
        for j in range(sides):
            angle = TAU * (j + 0.5) / sides
            c, s = math.cos(angle), math.sin(angle)
            made.append(centre + across * sign(c) * abs(c) ** (2.0 / power) + along * sign(s) * abs(s) ** (2.0 / power))
        return made

    def stack(self, levels, sides=10, power=2.0, ends=3):
        """Rings stacked into a body: each level is [height, half width, half depth, how far forward, how far aside]."""
        rows = []
        for level in levels:
            centre = V(level[4] if len(level) > 4 else 0.0, level[0], level[3] if len(level) > 3 else 0.0)
            rows.append(self.ring(centre, V(level[1], 0, 0), V(0, 0, level[2]), sides, power))
        self.skin(rows, True, ends)

    def limb(self, path, side=RIGHT, sides=8, power=2.0, ends=3):
        """A limb along a line of points: each of `path` is [where, half width, half thickness]."""
        rows = []
        for i in range(len(path)):
            at = path[i][0]
            way = (path[min(i + 1, len(path) - 1)][0] - path[max(i - 1, 0)][0]).normalized()
            across = (side - way * side.dot(way)).normalized()
            thick = way.cross(across).normalized()
            rows.append(self.ring(at, across * path[i][1], thick * path[i][2], sides, power))
        self.skin(rows, True, ends)

    def take(self, other):
        start = len(self.verts)
        for p in other.verts:
            self.verts.append(self.place @ p)
        flip = self.place.determinant() < 0.0
        for indices, smooth, tone in other.faces:
            moved_ = [start + i for i in indices]
            self.faces.append((list(reversed(moved_)) if flip else moved_, smooth, tone))


# --- The figures ------------------------------------------------------------------

FACE_ACROSS = [0.0, 3.5, 7.0, 10.5, 14.0, 18.0, 22.0, 26.5, 31.0, 37.0, 46.0, 58.0, 74.0, 98.0]
FACE_UP = [-1.0, -0.92, -0.82, -0.7, -0.63, -0.585, -0.552, -0.53, -0.508, -0.47, -0.43, -0.385, -0.345, -0.305, -0.25,
           -0.16, -0.06, 0.01, 0.035, 0.06, 0.085, 0.11, 0.135, 0.16, 0.2, 0.25, 0.3, 0.4, 0.6]
FACE_ACROSS_FAR = [0.0, 6.0, 13.0, 22.0, 34.0, 50.0, 72.0, 98.0]
FACE_UP_FAR = [-1.0, -0.86, -0.72, -0.6, -0.53, -0.47, -0.385, -0.305, -0.18, -0.03, 0.035, 0.085, 0.15, 0.25, 0.38, 0.6]
FACE_ACROSS_TINY = [0.0, 10.0, 24.0, 48.0, 98.0]
FACE_UP_TINY = [-1.0, -0.8, -0.6, -0.5, -0.33, -0.18, 0.0, 0.1, 0.25, 0.6]


def through(knots, x):
    """A smooth line through points (x rising), read at x."""
    n = len(knots)
    if x <= knots[0][0]:
        return knots[0][1]
    if x >= knots[-1][0]:
        return knots[-1][1]
    i = 0
    while x > knots[i + 1][0]:
        i += 1
    t = (x - knots[i][0]) / (knots[i + 1][0] - knots[i][0])
    p0, p1, p2, p3 = knots[max(i - 1, 0)][1], knots[i][1], knots[i + 1][1], knots[min(i + 2, n - 1)][1]
    return 0.5 * ((2.0 * p1) + (-p0 + p2) * t + (2.0 * p0 - 5.0 * p1 + 4.0 * p2 - p3) * t * t + (-p0 + 3.0 * p1 - 3.0 * p2 + p3) * t * t * t)


def bump(u, y, at, radius):
    return math.exp(-((u - at[0]) ** 2 + (y - at[1]) ** 2) / (radius * radius))


def face_point(angle, y):
    """A point of the king's face: `angle` round from straight ahead, y from the chin (-1) up (the brow band is at 0.5).
    The head is two units high, about its middle. Also how dark the stone is there."""
    wide = through([[-1.0, 0.34], [-0.86, 0.5], [-0.6, 0.68], [-0.3, 0.78], [0.1, 0.81], [0.6, 0.79]], y)
    deep = through([[-1.0, 0.56], [-0.9, 0.7], [-0.75, 0.71], [-0.55, 0.75], [-0.3, 0.76], [0.0, 0.75], [0.25, 0.79], [0.6, 0.78]], y)
    c, sn = math.cos(angle), math.sin(angle)
    base = V(wide * sign(sn) * abs(sn) ** 0.85, y, deep * sign(c) * abs(c) ** 0.85)
    u = abs(base.x)
    out = 0.0
    dark = 0.0
    # The nose: a wedge that widens and stands further out to its tip, and is cut off under it.
    down = min(max((0.08 - y) / 0.38, 0.0), 1.0)
    ridge = 0.04 + 0.2 * down
    if y < -0.3:
        ridge *= 1.0 - smoothstep(0.3, 0.36, -y)
        dark += 0.2 * smoothstep(0.3, 0.34, -y) * (1.0 - smoothstep(0.36, 0.4, -y)) * (1.0 - smoothstep(0.08, 0.16, u))
    if y > 0.08:
        ridge *= 1.0 - smoothstep(0.08, 0.2, y)
    breadth = 0.06 + 0.06 * down
    out += ridge * (1.0 - smoothstep(0.4 * breadth, 1.45 * breadth, u))
    out += 0.055 * bump(u, y, (0.11, -0.3), 0.05)
    # The brow, a raised band in an easy arch over each eye, and the hollow of the eye under it.
    arch = 0.255 - 0.3 * (u - 0.27) * (u - 0.27)
    out += 0.05 * math.exp(-((y - arch) / 0.04) ** 2) * smoothstep(0.07, 0.15, u) * (1.0 - smoothstep(0.56, 0.7, u))
    hollow = ((u - 0.335) / 0.27) ** 2 + ((y - 0.075) / 0.13) ** 2
    out -= 0.09 * max(0.0, 1.0 - hollow)
    # The eye: long, pointed at both ends, between two lids that stand up from it.
    t = (u - 0.335) / 0.2
    if abs(t) < 1.15:
        open_ = max(0.0, 1.0 - t * t)
        upper = 0.07 + 0.07 * open_
        lower = 0.07 - 0.04 * open_
        if lower < y < upper:
            out += 0.045 * math.sqrt(open_) * (1.0 - abs((y - (upper + lower) * 0.5) / max((upper - lower) * 0.5, 0.001)) ** 2) + 0.01
            dark += 0.5 * open_
        out += 0.04 * math.exp(-((y - upper - 0.012) / 0.02) ** 2) * smoothstep(1.15, 0.9, abs(t))
        out += 0.022 * math.exp(-((y - lower + 0.01) / 0.018) ** 2) * smoothstep(1.15, 0.9, abs(t))
        dark += 0.3 * math.exp(-((y - upper + 0.004) / 0.012) ** 2) * smoothstep(1.1, 0.8, abs(t))
    # Full cheeks.
    out += 0.045 * bump(u, y, (0.42, -0.22), 0.28)
    # The mouth: two full lips with a cut between them, the corners turned up a little.
    along = max(0.0, 1.0 - (u / 0.28) ** 2)
    lift = 0.03 * (u / 0.28) ** 2
    out += 0.06 * along ** 0.6 * math.exp(-((y + 0.475 - lift) / 0.038) ** 2)
    out += 0.065 * along ** 0.6 * math.exp(-((y + 0.59 - lift) / 0.044) ** 2)
    cut = along ** 0.4 * math.exp(-((y + 0.53 - lift) / 0.016) ** 2)
    out -= 0.055 * cut
    dark += 0.5 * cut
    out -= 0.03 * math.exp(-((y + 0.7) / 0.05) ** 2) * max(0.0, 1.0 - (u / 0.35) ** 2)
    # The chin.
    out += 0.06 * bump(u, y, (0.0, -0.86), 0.22)
    return base + V(sn * 0.5, 0.0, max(c, 0.0) + 0.3).normalized() * out, 1.0 - 0.3 * min(max(dark, 0.0), 1.0)


def face(s, near, tiny=False):
    across = FACE_ACROSS_TINY if tiny else (FACE_ACROSS if near else FACE_ACROSS_FAR)
    up = FACE_UP_TINY if tiny else (FACE_UP if near else FACE_UP_FAR)
    angles = [-math.radians(a) for a in reversed(across[1:])] + [math.radians(a) for a in across]
    rows, tones = [], []
    for y in up:
        found = [face_point(angle, y) for angle in angles]
        rows.append([f[0] for f in found])
        tones.append([f[1] for f in found])
    s.skin(rows, False, 0, BACK, tones)


def head(s, wears, near, tiny=False):
    """The king's head, two units high about its own middle: the face, the ears, and what he wears on it."""
    if wears == "falcon":
        falcon_head(s)
        return
    face(s, near, tiny)
    whole = s.place
    for side in (-1.0, 1.0):
        s.place = whole @ Matrix.Diagonal((side, 1.0, 1.0, 1.0))
        s.block([V(0.76, -0.16, 0.16), V(0.9, -0.1, 0.06), V(0.88, -0.1, -0.08), V(0.74, -0.16, -0.05),
                 V(0.78, 0.26, 0.14), V(0.95, 0.3, 0.02), V(0.92, 0.3, -0.12), V(0.76, 0.26, -0.06)], "")
    s.place = whole
    if wears == "cap":
        # Ptah: a close cap, and a straight beard.
        s.stack([[0.42, 0.84, 0.86, -0.04], [0.7, 0.8, 0.84, -0.06], [0.95, 0.55, 0.6, -0.08], [1.05, 0.2, 0.25, -0.08]], 12, 2.2)
        s.stack([[-0.5, 0.86, 0.6, -0.3], [0.44, 0.86, 0.7, -0.22]], 12, 2.2)
        beard(s)
    elif wears == "plumes":
        # Amun: a flat-topped cap with two tall feathers.
        s.stack([[0.42, 0.86, 0.88, -0.04], [0.5, 0.9, 0.9, -0.06], [1.15, 0.98, 0.95, -0.08]], 12, 2.4)
        s.stack([[-0.5, 0.86, 0.6, -0.3], [0.44, 0.86, 0.7, -0.22]], 12, 2.2)
        for side in (-1.0, 1.0):
            s.box(V(side * 0.42 - 0.36, 1.15, -0.3), V(side * 0.42 + 0.36, 3.3, 0.02), "b", (0.7, 1.0))
        beard(s)
    else:
        nemes(s)
        beard(s)
        if wears == "double":
            double_crown(s)


def nemes(s):
    """The striped headcloth: a band over the brow, wings standing out behind the ears, and a lappet on either side of the chest."""
    s.stack([[-0.72, 1.3, 0.5, -0.5], [-0.3, 1.26, 0.56, -0.45], [0.1, 1.14, 0.62, -0.4], [0.4, 1.02, 0.7, -0.34], [0.43, 0.9, 1.0, -0.14],
             [0.62, 0.88, 1.0, -0.14], [0.86, 0.74, 0.86, -0.16], [1.0, 0.45, 0.55, -0.18], [1.04, 0.1, 0.15, -0.18]], 14, 2.5)
    for side in (-1.0, 1.0):
        s.box(V(side * 0.74 - 0.27, -1.75, 0.0), V(side * 0.74 + 0.27, -0.6, 0.4), "", (1.15, 1.0))
    # The cobra on his brow.
    s.box(V(-0.09, 0.5, 0.82), V(0.09, 0.92, 0.98), "b", (0.6, 0.6), V(0.0, 0.0, -0.1))


def wig(s):
    """A heavy wig in three parts, as a queen or a goddess wears."""
    s.stack([[-0.9, 1.12, 0.62, -0.42], [-0.3, 1.14, 0.66, -0.4], [0.3, 1.08, 0.72, -0.34], [0.42, 0.96, 1.0, -0.12],
             [0.7, 0.92, 0.98, -0.14], [0.94, 0.66, 0.74, -0.16], [1.04, 0.2, 0.25, -0.18]], 12, 2.3)
    for side in (-1.0, 1.0):
        s.box(V(side * 0.74 - 0.3, -1.8, 0.0), V(side * 0.74 + 0.3, -0.5, 0.5), "b")


def beard(s):
    s.block([V(-0.2, -1.62, 0.6), V(0.2, -1.62, 0.6), V(0.2, -1.62, 0.24), V(-0.2, -1.62, 0.24),
             V(-0.15, -0.93, 0.64), V(0.15, -0.93, 0.64), V(0.15, -0.93, 0.3), V(-0.15, -0.93, 0.3)], "t")


def double_crown(s):
    """The red crown of the north, a drum that rises behind, and the tall white crown of the south standing in it."""
    s.stack([[0.9, 0.84, 0.86, -0.16], [1.5, 0.96, 0.96, -0.16], [1.55, 0.9, 0.9, -0.16]], 14)
    s.stack([[1.5, 0.74, 0.74, -0.14], [1.8, 0.7, 0.7, -0.14], [2.08, 0.56, 0.56, -0.14], [2.26, 0.4, 0.4, -0.14], [2.38, 0.24, 0.24, -0.14], [2.42, 0.08, 0.08, -0.14]], 12)
    s.box(V(-0.45, 1.5, -1.1), V(0.45, 2.3, -0.84), "b", (0.5, 1.0))


def falcon_head(s):
    """A falcon's head on a man's shoulders: the heavy wig, the hooked beak, and the disc of the sun on top."""
    wig(s)
    s.stack([[-0.9, 0.5, 0.5, 0.1], [-0.4, 0.66, 0.74, 0.1], [0.2, 0.7, 0.8, 0.1], [0.7, 0.55, 0.62, 0.05], [0.95, 0.2, 0.25, 0.0]], 10)
    s.block([V(-0.2, -0.5, 0.8), V(0.2, -0.5, 0.8), V(0.26, -0.2, 0.6), V(-0.26, -0.2, 0.6),
             V(-0.07, -0.62, 1.22), V(0.07, -0.62, 1.22), V(0.1, 0.12, 0.84), V(-0.1, 0.12, 0.84)], "")
    for side in (-1.0, 1.0):
        s.box(V(side * 0.4 - 0.2, 0.1, 0.5), V(side * 0.4 + 0.2, 0.22, 0.84), "")
    disc(s, V(0.0, 1.9, -0.1), 0.95)


def disc(s, at, radius):
    """The disc of the sun, upright and facing forward."""
    s.skin([Sculpt.ring(at + V(0, 0, z), V(radius, 0, 0), V(0, radius, 0), 14) for z in (-0.16, 0.16)], True, 3)


def seated(s, lower, upper, wears, family):
    """A seated figure 20 m high: the colossus (`family`: with the small figures at his legs), or a god of the sanctuary."""
    sides = 10 if family else 6
    if lower:
        s.tint = (0.93, 0.0, 1.0)
        s.box(V(-3.5, 0.0, 0.0), V(3.5, 1.5, 8.0), "b", (0.985, 0.99))
        # The throne: a block with a low back.
        s.tint = (0.97, 0.0, 1.0)
        s.box(V(-3.1, 1.5, 0.0), V(3.1, 6.4, 4.9), "b")
        s.box(V(-3.1, 6.4, 0.0), V(3.1, 7.6, 1.1), "b")
        s.tint = (1.0, 0.0, 1.0)
        for side in (-1.0, 1.0):
            # A leg: the thigh along the seat, the knee, the shin straight down, and the foot.
            s.limb([[V(side * 1.25, 7.15, 1.2), 1.12, 0.95], [V(side * 1.28, 7.1, 3.4), 1.08, 0.95], [V(side * 1.3, 7.05, 5.1), 0.98, 0.92],
                    [V(side * 1.3, 6.5, 5.55), 0.95, 0.74], [V(side * 1.3, 4.9, 5.45), 0.98, 0.9], [V(side * 1.3, 3.2, 5.4), 0.78, 0.76],
                    [V(side * 1.3, 2.0, 5.4), 0.62, 0.66], [V(side * 1.3, 1.5, 5.4), 0.66, 0.7]], RIGHT, sides, 2.3)
            s.limb([[V(side * 1.3, 1.95, 5.0), 0.66, 0.48], [V(side * 1.32, 1.92, 5.9), 0.72, 0.44], [V(side * 1.36, 1.8, 6.9), 0.8, 0.32],
                    [V(side * 1.38, 1.72, 7.6), 0.78, 0.22], [V(side * 1.38, 1.7, 7.75), 0.6, 0.16]], RIGHT, 8 if family else 6, 3.0)
            # A forearm along the thigh and a hand laid flat on the knee.
            s.limb([[V(side * 2.8, 8.9, 1.5), 0.62, 0.62], [V(side * 2.3, 8.55, 3.3), 0.56, 0.5], [V(side * 1.75, 8.3, 4.5), 0.52, 0.32],
                    [V(side * 1.5, 8.2, 5.5), 0.56, 0.2], [V(side * 1.45, 8.1, 5.95), 0.5, 0.14]], RIGHT, 8 if family else 6, 2.6)
        # The kilt, stretched between the thighs.
        s.box(V(-1.3, 6.4, 1.0), V(1.3, 7.75, 5.2), "b", (1.0, 0.97))
        # The hips, and where it broke.
        s.stack([[7.2, 2.5, 1.4, 1.45], [7.9, 2.3, 1.38, 1.45], [8.8, 1.95, 1.2, 1.4], [9.3, 1.92, 1.2, 1.4]], sides, 2.6, 0 if upper else 2)
        if family:
            was = s.place
            small = Sculpt()
            standing(small, "small")
            for x, z, high in ((-2.75, 5.5, 5.4), (2.75, 5.5, 5.4), (0.0, 5.75, 3.7)):
                s.place = was @ moved(high, (x, 1.5, z))
                s.take(small)
            s.place = was
    if upper:
        s.tint = (1.0, 0.0, 1.0)
        # The body: narrow at the waist, a broad chest, and square shoulders running in to the neck.
        s.stack([[9.3, 1.92, 1.2, 1.4], [10.6, 2.3, 1.36, 1.45], [11.9, 2.7, 1.52, 1.5], [12.7, 3.0, 1.4, 1.5], [13.1, 2.9, 1.22, 1.5],
                 [13.35, 1.4, 1.0, 1.55], [13.9, 0.95, 0.95, 1.6]], sides, 2.6, 2 if lower else 3)
        for side in (-1.0, 1.0):
            s.limb([[V(side * 2.7, 13.0, 1.5), 0.6, 0.7], [V(side * 2.8, 12.3, 1.5), 0.78, 0.86], [V(side * 2.85, 10.6, 1.6), 0.7, 0.78],
                    [V(side * 2.8, 9.0, 1.7), 0.62, 0.66], [V(side * 2.8, 8.6, 1.8), 0.5, 0.5]], RIGHT, 8 if family else 6, 2.0)
        # What holds him to the rock behind.
        s.tint = (0.95, 0.0, 1.0)
        s.box(V(-2.4, 9.3, -2.2), V(2.4, 13.2, 1.0), "b")
        s.box(V(-1.5, 13.2, -2.6), V(1.5, 17.0, 1.2), "b")
        s.tint = (1.0, 0.0, 1.0)
        was = s.place
        s.place = was @ moved(2.0, (0.0, 15.4, 1.95))
        head(s, wears, family, not family)
        s.place = was


def standing(s, who):
    """A standing figure one unit high to the top of its head."""
    near = who in ("king", "queen", "osiris")
    sides = 10 if near else 5
    hd = 0.078 if who != "small" else 0.085
    neck = 1.0 - hd * 2.0
    s.tint = (1.0, 0.0, 1.0)
    if who == "king":
        # Striding: the left leg forward. Arms straight down, fists closed.
        for side in (-1.0, 1.0):
            fore = 0.07 if side < 0.0 else -0.02
            s.limb([[V(side * 0.07, 0.5, 0.0), 0.068, 0.075], [V(side * 0.072, 0.3, fore * 0.6), 0.054, 0.06], [V(side * 0.072, 0.2, fore * 0.85), 0.05, 0.058],
                    [V(side * 0.072, 0.07, fore), 0.034, 0.04], [V(side * 0.072, 0.0, fore), 0.038, 0.044]], RIGHT, 8, 2.3)
            s.box(V(side * 0.072 - 0.04, 0.0, fore), V(side * 0.072 + 0.04, 0.045, fore + 0.16), "b")
            s.limb([[V(side * 0.195, 0.8, 0.0), 0.045, 0.05], [V(side * 0.205, 0.64, 0.0), 0.042, 0.046], [V(side * 0.2, 0.5, 0.02), 0.034, 0.036],
                    [V(side * 0.195, 0.43, 0.03), 0.038, 0.042]], RIGHT, 8, 2.4)
        # The kilt, with its stiff front, and the body.
        s.stack([[0.3, 0.15, 0.1, 0.03], [0.5, 0.155, 0.1, 0.01], [0.56, 0.135, 0.09, 0.0]], sides, 2.8, 1)
        s.stack([[0.56, 0.135, 0.085], [0.64, 0.118, 0.078], [0.74, 0.15, 0.092], [0.8, 0.168, 0.086], [0.825, 0.15, 0.076], [0.842, 0.07, 0.06], [neck + 0.03, 0.058, 0.056]], sides, 2.6, 2)
    elif who == "osiris":
        # Wrapped as a mummy, feet together, arms crossed on the chest with the crook and the flail.
        s.stack([[0.0, 0.11, 0.1, 0.03], [0.05, 0.1, 0.085, 0.02], [0.28, 0.115, 0.085], [0.5, 0.15, 0.095], [0.63, 0.135, 0.085], [0.74, 0.17, 0.095],
                 [0.8, 0.185, 0.088], [0.825, 0.16, 0.076], [0.842, 0.07, 0.06], [neck + 0.03, 0.058, 0.056]], 8, 2.6, 2)
        for side in (-1.0, 1.0):
            s.limb([[V(side * 0.19, 0.79, 0.0), 0.045, 0.05], [V(side * 0.21, 0.66, 0.03), 0.042, 0.046], [V(side * 0.08, 0.7, 0.1), 0.036, 0.03],
                    [V(-side * 0.07, 0.75, 0.105), 0.036, 0.03]], UP, 6, 2.4)
            s.box(V(-side * 0.1 - 0.014, 0.74, 0.1), V(-side * 0.1 + 0.014, 0.9, 0.125), "b")
    else:
        # A queen, or one of the family, or a god in a niche: a long close dress to the ankles, arms at the sides.
        broad = 1.0 if who != "small" else 1.1
        s.stack([[0.0, 0.1 * broad, 0.08, 0.03], [0.04, 0.085 * broad, 0.066, 0.02], [0.3, 0.1 * broad, 0.07], [0.5, 0.138 * broad, 0.088], [0.63, 0.105 * broad, 0.07], [0.73, 0.13 * broad, 0.085],
                 [0.8, 0.15 * broad, 0.076], [0.825, 0.135 * broad, 0.07], [0.842, 0.065, 0.056], [neck + 0.03, 0.054, 0.052]], sides, 2.5, 2)
        for side in (-1.0, 1.0):
            s.limb([[V(side * 0.15 * broad, 0.8, 0.0), 0.04, 0.044], [V(side * 0.15 * broad, 0.64, 0.0), 0.04, 0.04], [V(side * 0.15 * broad, 0.46, 0.02), 0.034, 0.034]], RIGHT, 6 if near else 4, 2.4)
    was = s.place
    s.place = was @ moved(hd, (0.0, 1.0 - hd, 0.015))
    if who == "king":
        head(s, "double", False)
    elif who == "osiris":
        head(s, "double", False)
    elif who == "falcon":
        falcon_head(s)
    elif who == "queen":
        # Nefertari as Hathor: the wig, and on it the cow's horns about the sun and two tall feathers.
        face(s, False)
        wig(s)
        s.stack([[1.0, 0.7, 0.7, -0.16], [1.35, 0.78, 0.76, -0.16]], 10)
        disc(s, V(0.0, 2.2, -0.16), 0.62)
        for side in (-1.0, 1.0):
            s.limb([[V(side * 0.3, 1.35, -0.16), 0.2, 0.14], [V(side * 0.95, 1.9, -0.16), 0.16, 0.12], [V(side * 1.0, 2.7, -0.16), 0.1, 0.08],
                    [V(side * 0.82, 3.1, -0.16), 0.04, 0.04]], RIGHT, 6)
            s.box(V(side * 0.26 - 0.26, 2.3, -0.36), V(side * 0.26 + 0.26, 4.1, -0.2), "b", (0.6, 1.0))
    else:
        face(s, False, True)
        wig(s)
    s.place = was


def hathor(s):
    """The head of Hathor for the front of a pillar, one unit wide: a woman's face with the heavy wig curling out at its
    ends, and the shrine of the sistrum above. Its back is the plane z = 0 and its chin about y = 0."""
    s.tint = (1.0, 0.0, 1.0)
    was = s.place
    s.place = was @ Matrix.Translation((0.0, 0.42, -0.02)) @ Matrix.Diagonal((0.36, 0.36, 0.2, 1.0))
    face(s, False)
    s.place = was
    for side in (-1.0, 1.0):
        s.box(V(side * 0.39 - 0.11, 0.0, 0.0), V(side * 0.39 + 0.11, 0.72, 0.12), "b")
        s.stack([[-0.0, 0.1, 0.1, 0.03, side * 0.44], [0.01, 0.13, 0.1, 0.03, side * 0.46]], 8)
        s.box(V(side * 0.5 - 0.04, 0.34, 0.0), V(side * 0.5 + 0.1, 0.52, 0.1), "")
    s.box(V(-0.5, 0.62, 0.0), V(0.5, 0.78, 0.14), "b")
    s.box(V(-0.3, 0.78, 0.0), V(0.3, 1.3, 0.1), "b", (1.12, 1.0))
    s.box(V(-0.38, 1.3, 0.0), V(0.38, 1.38, 0.13), "b")


def baboon(s):
    """A baboon squatting with its hands raised to the rising sun, one unit high."""
    s.tint = (1.0, 0.0, 1.0)
    s.stack([[0.0, 0.26, 0.22, 0.2], [0.18, 0.3, 0.26, 0.2], [0.5, 0.3, 0.24, 0.18], [0.7, 0.2, 0.18, 0.2]], 6, 2.4, 0)
    s.stack([[0.62, 0.17, 0.16, 0.22], [0.78, 0.19, 0.18, 0.24], [0.94, 0.15, 0.15, 0.24], [1.0, 0.06, 0.06, 0.24]], 6, 2.2, 2)
    # (the long muzzle)
    s.block([V(-0.07, 0.68, 0.5), V(0.07, 0.68, 0.5), V(0.09, 0.68, 0.36), V(-0.09, 0.68, 0.36),
             V(-0.06, 0.78, 0.5), V(0.06, 0.78, 0.5), V(0.09, 0.84, 0.36), V(-0.09, 0.84, 0.36)], "")
    for side in (-1.0, 1.0):
        s.box(V(side * 0.2 - 0.09, 0.0, 0.26), V(side * 0.2 + 0.09, 0.3, 0.5), "b")
        s.limb([[V(side * 0.28, 0.56, 0.26), 0.06, 0.06], [V(side * 0.34, 0.5, 0.42), 0.05, 0.05], [V(side * 0.34, 0.72, 0.48), 0.045, 0.045],
                [V(side * 0.34, 0.84, 0.47), 0.05, 0.03]], RIGHT, 4, 2.0, 2)


def falcon(s):
    """A falcon standing, one unit high: Horus, for the terrace."""
    s.tint = (1.0, 0.0, 1.0)
    s.box(V(-0.22, 0.0, -0.3), V(0.22, 0.12, 0.3), "b")
    s.limb([[V(0.0, 0.14, -0.3), 0.1, 0.04], [V(0.0, 0.3, -0.1), 0.2, 0.16], [V(0.0, 0.58, 0.06), 0.22, 0.2], [V(0.0, 0.78, 0.1), 0.15, 0.16],
            [V(0.0, 0.94, 0.1), 0.12, 0.13], [V(0.0, 1.0, 0.1), 0.05, 0.05]], RIGHT, 8)
    s.block([V(-0.05, 0.8, 0.2), V(0.05, 0.8, 0.2), V(0.07, 0.88, 0.16), V(-0.07, 0.88, 0.16),
             V(-0.02, 0.76, 0.32), V(0.02, 0.76, 0.32), V(0.04, 0.92, 0.2), V(-0.04, 0.92, 0.2)], "")
    for side in (-1.0, 1.0):
        s.box(V(side * 0.09 - 0.045, 0.1, 0.02), V(side * 0.09 + 0.045, 0.32, 0.14), "b")


def cow(s):
    """The cow of Hathor coming out of the rock: her forequarters and head, the sun between her horns. One unit high to
    the top of the head; her chest is at z = 0 and she looks along +Z."""
    s.tint = (1.0, 0.0, 1.0)
    s.limb([[V(0.0, 0.5, -0.5), 0.26, 0.3], [V(0.0, 0.5, 0.0), 0.25, 0.3], [V(0.0, 0.62, 0.3), 0.17, 0.2], [V(0.0, 0.8, 0.44), 0.14, 0.16]], RIGHT, 8, 2.3, 1)
    s.limb([[V(0.0, 0.92, 0.36), 0.15, 0.13], [V(0.0, 0.84, 0.5), 0.14, 0.14], [V(0.0, 0.7, 0.68), 0.1, 0.1], [V(0.0, 0.62, 0.76), 0.085, 0.07]], RIGHT, 8, 2.4)
    for side in (-1.0, 1.0):
        s.box(V(side * 0.15 - 0.065, 0.0, -0.06), V(side * 0.15 + 0.065, 0.34, 0.1), "b")
        s.box(V(side * 0.24 - 0.08, 0.84, 0.36), V(side * 0.24 + 0.08, 0.9, 0.46), "")
        s.limb([[V(side * 0.1, 0.96, 0.4), 0.04, 0.04], [V(side * 0.24, 1.1, 0.4), 0.035, 0.035], [V(side * 0.22, 1.3, 0.4), 0.015, 0.015]], FORWARD, 5)
    disc(s, V(0.0, 1.16, 0.4), 0.15)


# --- The hills ----------------------------------------------------------------------

def lobe(s, rnd, at, a, b, top, around, front=None, front_y=0.0, lean=0.0, skip_half=0.0, skip_top=0.0, inner=0.0, inner_at=0.0, inner_narrows=0.0):
    """A hill of rock in beds, each a step: its middle `at` (x, z), half its width and depth, how high, how many points
    round. `front` cuts it off flat at that z (leaning back above front_y) and leaves out what is behind a facade
    (skip_half wide, to skip_top). `inner` (-1 or 1) cuts it off on the side towards x = 0 at inner_at."""
    levels = max(math.ceil(top / 2.8), 4)
    rise = top / levels
    phase = [rnd.random() * TAU for _ in range(3)]
    rings, cuts, last = [], [], None
    for level in range(levels):
        t = level / levels
        ring, flags, reach = [], [], []
        lumpy = rnd.uniform(-0.025, 0.025)
        for j in range(around):
            angle = TAU * j / around
            dx, dz = math.sin(angle), math.cos(angle)
            whole = 1.0 / (abs(dx / a) ** 2.6 + abs(dz / b) ** 2.6) ** (1.0 / 2.6)
            # (a cliff in front, that rounds over near the top; an easier slope behind)
            cliff = 1.0 - 0.2 * t - 0.3 * smoothstep(0.76, 1.0, t)
            slope = 1.0 - 0.74 * t ** 0.9
            shrink = lerp(slope, cliff, smoothstep(-0.3, 0.6, dz))
            r = whole * shrink * (1.0 + lumpy + 0.03 * math.sin(angle * 3.0 + phase[0] + level * 0.7) + 0.02 * math.sin(angle * 7.0 + phase[1] - level * 1.3)
                                  + 0.012 * math.sin(angle * 13.0 + phase[2] + level * 2.1))
            if last is not None:
                r = min(r, last[j] - 0.04)
            reach.append(r)
            px, pz = at[0] + dx * r, at[1] + dz * r
            flag = 0
            y = level * rise
            if front is not None:
                plane = front - max(y + rise - front_y, 0.0) * lean
                if pz > plane:
                    pz = plane
                    flag = 1
            if inner != 0.0:
                plane = inner_at - max(y - front_y, 0.0) * inner_narrows
                if px * inner < plane:
                    px = plane * inner
            ring.append((px, pz))
            flags.append(flag)
        last = reach
        rings.append(ring)
        cuts.append(flags)
    for level in range(levels):
        ring, flags = rings[level], cuts[level]
        y0 = level * rise if level > 0 else -4.0
        y1 = (level + 1) * rise
        nxt = rings[level + 1] if level + 1 < levels else None
        s.tint = (rnd.uniform(0.84, 1.0), 0.0, 1.0)
        crest = []
        for j in range(around):
            here = Vector(ring[j])
            towards = Vector(nxt[j]) if nxt else Vector(at)
            gap = (towards - here).length
            crest.append(here + (towards - here).normalized() * min(gap * 0.3, rise * 0.22) if gap > 1e-6 else here)
        for j in range(around):
            k = (j + 1) % around
            out = V(ring[j][0] + ring[k][0] - at[0] * 2.0, 0.0, ring[j][1] + ring[k][1] - at[1] * 2.0)
            # (what is behind the facade is left out: the facade is there)
            hidden = flags[j] == 1 and flags[k] == 1 and y1 <= skip_top + 0.01 and abs(ring[j][0]) < skip_half and abs(ring[k][0]) < skip_half
            if not hidden:
                s.face(V(ring[j][0], y0, ring[j][1]), V(ring[k][0], y0, ring[k][1]), V(crest[k].x, y1, crest[k].y), V(crest[j].x, y1, crest[j].y), out)
            if nxt:
                if not (hidden and y1 < skip_top - rise):
                    s.face(V(crest[j].x, y1, crest[j].y), V(crest[k].x, y1, crest[k].y), V(nxt[k][0], y1, nxt[k][1]), V(nxt[j][0], y1, nxt[j][1]), UP)
            else:
                s.face(V(crest[j].x, y1, crest[j].y), V(crest[k].x, y1, crest[k].y), V(at[0], y1, at[1]), V(at[0], y1, at[1]), UP)


# --- Rooms --------------------------------------------------------------------------

def room(s, low, high, doors, tone=1.0, carved=()):
    """A room cut in the rock, seen from inside. `doors` are the ways out of it, each [wall, from, to, height]: wall 0 is
    -X, 1 +X, 2 -Z (the far end), 3 +Z; from and to are along the wall. `carved`: the walls that carry the battle."""
    s.tint = (tone * 0.9, 0.0, 1.0)
    s.face(V(low.x, low.y, low.z), V(high.x, low.y, low.z), V(high.x, low.y, high.z), V(low.x, low.y, high.z), UP)
    s.tint = (tone, 0.0, 0.5)
    s.face(V(low.x, high.y, low.z), V(high.x, high.y, low.z), V(high.x, high.y, high.z), V(low.x, high.y, high.z), DOWN)
    for wall in range(4):
        along_x = wall >= 2
        a0, a1 = (low.x, high.x) if along_x else (low.z, high.z)
        fixed = [low.x, high.x, low.z, high.z][wall]
        inward = [RIGHT, LEFT, BACK, FORWARD][wall]
        holes = sorted([d for d in doors if d[0] == wall], key=lambda d: d[1])
        pieces, reached = [], a0
        for hole in holes:
            pieces.append([reached, hole[1], low.y])
            pieces.append([hole[1], hole[2], low.y + hole[3]])
            reached = hole[2]
        pieces.append([reached, a1, low.y])
        s.tint = (tone, 1.0 if wall in carved else 0.0, 1.0)
        for p0, p1, from_y in pieces:
            if p1 - p0 < 0.01:
                continue
            p = (lambda a, y: V(a, y, fixed)) if along_x else (lambda a, y: V(fixed, y, a))
            s.face(p(p0, from_y), p(p1, from_y), p(p1, high.y), p(p0, high.y), inward)


def passage(s, low, high, across):
    """A way through a wall between two rooms: `across` if it runs along X."""
    s.tint = (0.9, 0.0, 1.0)
    s.face(V(low.x, low.y, low.z), V(high.x, low.y, low.z), V(high.x, low.y, high.z), V(low.x, low.y, high.z), UP)
    s.face(V(low.x, high.y, low.z), V(high.x, high.y, low.z), V(high.x, high.y, high.z), V(low.x, high.y, high.z), DOWN)
    if across:
        s.face(V(low.x, low.y, low.z), V(high.x, low.y, low.z), V(high.x, high.y, low.z), V(low.x, high.y, low.z), BACK)
        s.face(V(low.x, low.y, high.z), V(high.x, low.y, high.z), V(high.x, high.y, high.z), V(low.x, high.y, high.z), FORWARD)
    else:
        s.face(V(low.x, low.y, low.z), V(low.x, low.y, high.z), V(low.x, high.y, high.z), V(low.x, high.y, low.z), RIGHT)
        s.face(V(high.x, low.y, low.z), V(high.x, low.y, high.z), V(high.x, high.y, high.z), V(high.x, high.y, low.z), LEFT)


# --- The Great Temple ---------------------------------------------------------------
# (scripts/abu_simbel.gd has these numbers too, under the same names, for what is solid and where things stand)

G = {"th": 1.2, "lean": 0.07, "tall": 30.0, "top": 32.8, "hw": 17.5, "narrows": 2.0 / 30.0, "dw": 1.3, "dh": 6.4, "thick": 3.5, "out": 19.0,
     "nx": 2.3, "n0": 7.8, "n1": 15.0, "niche": 1.3}


def great_hill(s, rnd):
    th = G["th"]
    lobe(s, rnd, (0.0, -37.5), 36.0, 40.5, 46.0, 34, front=-0.3, front_y=th, lean=G["lean"], skip_half=G["hw"], skip_top=th + G["top"])
    for side in (-1.0, 1.0):
        lobe(s, rnd, (side * 25.5, 2.5), 10.0, 8.5, 25.0, 16, front_y=th, inner=side, inner_at=G["hw"] + 0.2, inner_narrows=G["narrows"])


def great_facade(s):
    th, lean, tall, hw, dw, dh, out = G["th"], G["lean"], G["tall"], G["hw"], G["dw"], G["dh"], G["out"]
    nx, n0, n1, back = G["nx"], G["n0"], G["n1"], G["niche"]
    # The terrace, its steps, and the balustrade along its front.
    tw = hw + 3.0
    s.tint = (0.96, 1.0, 1.0)
    s.box(V(-tw, -1.0, -G["thick"]), V(tw, th, out), "b")
    stair = 2.6
    steps = math.ceil(th / 0.2)
    for i in range(steps):
        s.box(V(-stair, -1.0, out + i * 0.36), V(stair, th - (i + 1) * th / steps, out + (i + 1) * 0.36), "b")
    s.tint = (0.92, 1.0, 1.0)
    for side in (-1.0, 1.0):
        s.box(V(min(side * (stair + 0.4), side * tw), th, out - 0.9), V(max(side * (stair + 0.4), side * tw), th + 1.1, out), "b")

    def face_at(x, y, z=0.0):
        return V(x, th + y, z - y * lean)

    def edge(y):
        return hw - y * G["narrows"]

    # The facade: a leaning wall narrower at the top, with the door, and over it the niche. (It is the living rock: no courses.)
    s.tint = (1.0, 0.0, 1.0)
    for side in (-1.0, 1.0):
        s.face(face_at(side * nx, 0.0), face_at(side * hw, 0.0), face_at(side * edge(tall), tall), face_at(side * nx, tall), BACK)
        s.face(face_at(side * dw, 0.0), face_at(side * nx, 0.0), face_at(side * nx, dh), face_at(side * dw, dh), BACK)
        s.face(face_at(side * nx, n0), face_at(side * nx, n1), face_at(side * nx, n1, -back), face_at(side * nx, n0, -back), V(-side, 0, 0))
    s.face(face_at(-nx, dh), face_at(nx, dh), face_at(nx, n0), face_at(-nx, n0), BACK)
    s.face(face_at(-nx, n1), face_at(nx, n1), face_at(nx, tall), face_at(-nx, tall), BACK)
    s.tint = (0.86, 0.0, 1.0)
    s.face(face_at(-nx, n0, -back), face_at(nx, n0, -back), face_at(nx, n1, -back), face_at(-nx, n1, -back), BACK)
    s.face(face_at(-nx, n0), face_at(nx, n0), face_at(nx, n0, -back), face_at(-nx, n0, -back), UP)
    s.face(face_at(-nx, n1), face_at(nx, n1), face_at(nx, n1, -back), face_at(-nx, n1, -back), DOWN)
    # The roll round the edge of the facade, the hollow cornice over it, and the wall the baboons stand against.
    s.tint = (0.94, 0.0, 1.0)
    roll, under = 0.45, 27.3
    s.limb([[face_at(-edge(under), under, roll * 0.6), roll, roll], [face_at(edge(under), under, roll * 0.6), roll, roll]], UP, 6)
    for side in (-1.0, 1.0):
        s.limb([[face_at(side * (hw - roll), 0.0, roll * 0.6), roll, roll], [face_at(side * (edge(under) - roll), under, roll * 0.6), roll, roll]], BACK, 6)
    rows = []
    for y, z in ((27.9, 0.0), (28.5, 0.1), (29.1, 0.38), (29.6, 0.95), (29.62, 1.0), (30.0, 1.0)):
        half = edge(y) + z * 0.5
        rows.append([face_at(-half, y, z), face_at(-half * 0.34, y, z), face_at(half * 0.34, y, z), face_at(half, y, z)])
    s.skin(rows, False, 0, BACK)
    s.tint = (0.96, 0.0, 1.0)
    s.face(face_at(-edge(30.0), 30.0, 1.0), face_at(edge(30.0), 30.0, 1.0), face_at(edge(30.0), 30.0, 0.0), face_at(-edge(30.0), 30.0, 0.0), UP)
    s.face(face_at(-edge(30.0), 30.0), face_at(edge(30.0), 30.0), face_at(edge(32.8), 32.8), face_at(-edge(32.8), 32.8), BACK)
    # Between each pair of colossi, a block for a princess to stand on, and the rock that joins their thrones.
    inner = dw + 0.3 + SEATED["base_half"]
    outer = inner + 8.3
    s.tint = (0.95, 0.0, 1.0)
    for side in (-1.0, 1.0):
        mid = side * (inner + outer) * 0.5
        gap = (outer - inner) * 0.5 - SEATED["throne_half"]
        s.box(V(mid - 0.75, th, 0.0), V(mid + 0.75, th + SEATED["base_top"], 6.0), "b")
        s.box(V(mid - gap - 0.05, th, -2.0), V(mid + gap + 0.05, th + SEATED["seat"], 3.4), "b")
    # A few blocks of the broken one, to get up by.
    s.tint = (0.9, 0.0, 1.0)
    for i in range(3):
        low = V(-inner - 9.6 + i * 1.5, th, 8.6 + i * 1.5)
        s.box(low, low + V(1.9, 0.9 + 0.45 * i, 1.7), "b")


def great_inside(s):
    th, dw, dh, thick = G["th"], G["dw"], G["dh"], G["thick"]
    z = -thick
    high1, half1, deep, d2, h2, wall = 10.5, 8.2, 18.0, 1.1, 5.0, 1.6
    passage(s, V(-dw, th, -thick), V(dw, th + dh, 0.0), False)
    # The store-rooms off the great hall, two a side.
    side_doors = []
    for i in range(2):
        mid = z - (5.2 + 8.0 * i)
        for side in range(2):
            sg = -1.0 if side == 0 else 1.0
            side_doors.append([side, mid - 0.9, mid + 0.9, 3.4])
            a, b = sg * half1, sg * (half1 + wall)
            passage(s, V(min(a, b), th, mid - 0.9), V(max(a, b), th + 3.4, mid + 0.9), True)
            c = sg * (half1 + wall + 12.0)
            room(s, V(min(b, c), th, mid - 1.7), V(max(b, c), th + 4.0, mid + 1.7), [[1 - side, mid - 0.9, mid + 0.9, 3.4]], 0.9)
    room(s, V(-half1, th, z - deep), V(half1, th + high1, z), [[3, -dw, dw, dh], [2, -d2, d2, h2]] + side_doors, 1.0, (0, 1))
    z -= deep
    passage(s, V(-d2, th, z - wall), V(d2, th + h2, z), False)
    z -= wall
    # The second hall, the vestibule across the way, and the sanctuary with its bench and its altar.
    room(s, V(-5.5, th, z - 7.6), V(5.5, th + 7.0, z), [[3, -d2, d2, h2], [2, -1.0, 1.0, 4.2]], 0.96, (0, 1))
    z -= 7.6
    passage(s, V(-1.0, th, z - wall), V(1.0, th + 4.2, z), False)
    z -= wall
    room(s, V(-5.5, th, z - 3.2), V(5.5, th + 5.6, z), [[3, -1.0, 1.0, 4.2], [2, -0.9, 0.9, 3.8]], 0.94)
    z -= 3.2
    passage(s, V(-0.9, th, z - wall), V(0.9, th + 3.8, z), False)
    z -= wall
    room(s, V(-2.0, th, z - 7.0), V(2.0, th + 4.6, z), [[3, -0.9, 0.9, 3.8]], 0.92)
    s.tint = (0.95, 0.0, 1.0)
    s.box(V(-2.0, th, z - 7.0), V(2.0, th + 0.25, z - 7.0 + 1.2), "b")
    s.tint = (0.9, 0.0, 1.0)
    s.box(V(-0.6, th, z - 3.15 - 0.6), V(0.6, th + 0.9, z - 3.15 + 0.6), "b")


# --- The Small Temple ---------------------------------------------------------------

S = {"th": 0.6, "tall": 12.4, "top": 13.8, "niche": 3.1, "butt": 1.15, "middle": 3.4, "out": 1.6, "dw": 0.9, "dh": 3.6, "thick": 2.4}
S["hw"] = S["middle"] * 0.5 + 3.0 * (S["niche"] + S["butt"])


def small_hill(s, rnd):
    th, hw = S["th"], S["hw"]
    lobe(s, rnd, (0.0, -28.5), 27.0, 30.0, 30.0, 28, front=-0.3, front_y=th, skip_half=hw, skip_top=th + S["top"])
    for side in (-1.0, 1.0):
        lobe(s, rnd, (side * (hw + 6.0), -2.0), 6.5, 8.5, 17.0, 14, front_y=th, inner=side, inner_at=hw + 0.1)


def small_facade(s):
    th, tall, top, hw, out, dw, dh, thick = S["th"], S["tall"], S["top"], S["hw"], S["out"], S["dw"], S["dh"], S["thick"]
    # A low terrace and its steps.
    before = 8.0
    s.tint = (0.96, 1.0, 1.0)
    s.box(V(-hw - 1.5, -1.0, -thick), V(hw + 1.5, th, before), "b")
    steps = math.ceil(th / 0.2)
    for i in range(steps):
        s.box(V(-hw - 1.5, -1.0, before + i * 0.36), V(hw + 1.5, th - (i + 1) * th / steps, before + (i + 1) * 0.36), "b")
    # The wall the niches are cut back to, the buttresses that lean against it, and the band along the top.
    s.tint = (0.9, 0.0, 1.0)
    s.face(V(-hw, th, 0.0), V(-dw, th, 0.0), V(-dw, th + tall, 0.0), V(-hw, th + tall, 0.0), BACK)
    s.face(V(dw, th, 0.0), V(hw, th, 0.0), V(hw, th + tall, 0.0), V(dw, th + tall, 0.0), BACK)
    x = -hw
    for i in range(13):
        wide = S["middle"] if i == 6 else (S["butt"] if i % 2 == 0 else S["niche"])
        if i % 2 == 0:
            # A buttress: its face leans back as it rises. The middle one has the door through it.
            s.tint = (1.0, 0.0, 1.0)
            parts = [[x, x + wide, th]] if i != 6 else [[x, -dw, th], [dw, x + wide, th], [-dw, dw, th + dh]]
            for x0, x1, y in parts:
                s.block([V(x0, y, out - (y - th) * 0.1), V(x1, y, out - (y - th) * 0.1), V(x1, y, 0.0), V(x0, y, 0.0),
                         V(x0, th + tall, out - tall * 0.1), V(x1, th + tall, out - tall * 0.1), V(x1, th + tall, 0.0), V(x0, th + tall, 0.0)], "t" if y > th + 0.01 else "bt")
        else:
            # The foot of a niche, for a colossus to stand on.
            s.tint = (0.96, 0.0, 1.0)
            s.box(V(x, th, 0.0), V(x + wide, th + 0.6, out), "b")
        x += wide
    s.tint = (0.95, 0.0, 1.0)
    s.box(V(-hw, th + tall, -thick), V(hw, th + top, out - tall * 0.1 + 0.2), "b")
    s.limb([[V(-hw, th + tall, out - tall * 0.1 + 0.2), 0.3, 0.3], [V(hw, th + tall, out - tall * 0.1 + 0.2), 0.3, 0.3]], UP, 6)


def small_inside(s):
    th, out, dw, dh, thick = S["th"], S["out"], S["dw"], S["dh"], S["thick"]
    passage(s, V(-dw, th, -thick), V(dw, th + dh, out), False)
    z = -thick
    wall = 1.3
    room(s, V(-5.5, th, z - 10.8), V(5.5, th + 4.4, z), [[3, -dw, dw, dh], [2, -0.9, 0.9, 3.2]], 1.0, (0, 1))
    z -= 10.8
    passage(s, V(-0.9, th, z - wall), V(0.9, th + 3.2, z), False)
    z -= wall
    room(s, V(-5.5, th, z - 2.8), V(5.5, th + 3.8, z), [[3, -0.9, 0.9, 3.2], [2, -0.9, 0.9, 3.2]], 0.95)
    z -= 2.8
    passage(s, V(-0.9, th, z - wall), V(0.9, th + 3.2, z), False)
    z -= wall
    room(s, V(-1.5, th, z - 3.4), V(1.5, th + 3.4, z), [[3, -0.9, 0.9, 3.2]], 0.92)


# --- Pillars ------------------------------------------------------------------------

def osiride_pillar(s):
    """A pillar of the great hall, 3 m square and 10.5 high about the origin, the king as Osiris on its +Z side."""
    s.tint = (0.97, 0.0, 1.0)
    s.box(V(-1.5, 0.0, -1.5), V(1.5, 10.5, 1.5), "bt")
    figure = Sculpt()
    standing(figure, "osiris")
    s.place = moved(8.3, (0.0, 0.0, 1.5 + 0.068 * 8.3))
    s.take(figure)
    s.place = Matrix.Identity(4)


def square_pillar(s):
    """A pillar of the second hall: 1.6 m square, 7 high."""
    s.tint = (0.97, 0.0, 1.0)
    s.box(V(-0.8, 0.0, -0.8), V(0.8, 7.0, 0.8), "bt")


def hathor_pillar(s):
    """A pillar of the small temple: 1.3 m square, 4.4 high, the head of Hathor at the top of its +Z side."""
    s.tint = (0.97, 0.0, 1.0)
    s.box(V(-0.65, 0.0, -0.65), V(0.65, 4.4, 0.65), "bt")
    s.place = moved(1.3, (0.0, 4.4 - 1.3 * 1.5, 0.65))
    hathor(s)
    s.place = Matrix.Identity(4)


# --- Making the objects -------------------------------------------------------------

def to_object(name, s, where=None, collection=None):
    mesh = bpy.data.meshes.new(name)
    # (Godot's space to Blender's: Y up becomes Z up)
    mesh.from_pydata([(p.x, -p.z, p.y) for p in s.verts], [], [f[0] for f in s.faces])
    colours = mesh.color_attributes.new("Col", "FLOAT_COLOR", "CORNER")
    at = 0
    for poly, (indices, smooth, tone) in zip(mesh.polygons, s.faces):
        poly.use_smooth = smooth
        for _ in indices:
            colours.data[at].color = (tone[0], tone[1], tone[2], 1.0)
            at += 1
    mesh.color_attributes.active_color = colours
    mesh.color_attributes.render_color_index = 0
    mesh.update()
    thing = bpy.data.objects.new(name, mesh)
    (collection or bpy.context.scene.collection).objects.link(thing)
    if where is not None:
        # (a place in Godot's space, in Blender's)
        swap = Matrix(((1, 0, 0, 0), (0, 0, -1, 0), (0, 1, 0, 0), (0, 0, 0, 1)))
        thing.matrix_world = swap @ where @ swap.inverted()
    print("BUILT %-18s tris=%5d" % (name, s.count()))
    return thing


def build():
    bpy.ops.wm.read_factory_settings(use_empty=True)
    rnd = random.Random(71)
    groups = {}
    for name in ("Great Temple", "Small Temple", "Figures"):
        groups[name] = bpy.data.collections.new(name)
        bpy.context.scene.collection.children.link(groups[name])
    made = {}

    def part(name, fill, where=None, group="Figures"):
        s = Sculpt()
        fill(s)
        made[name] = to_object(name, s, where, groups[group])

    part("great_hill", lambda s: great_hill(s, rnd), None, "Great Temple")
    part("great_facade", great_facade, None, "Great Temple")
    part("great_inside", great_inside, None, "Great Temple")
    part("ridge", lambda s: lobe(s, rnd, (58.0, -62.0), 52.0, 34.0, 32.0, 28), None, "Great Temple")
    part("small_hill", lambda s: small_hill(s, rnd), NORTH, "Small Temple")
    part("small_facade", small_facade, NORTH, "Small Temple")
    part("small_inside", small_inside, NORTH, "Small Temple")
    # The figures and pillars, in rows out in front (the game sets them in their places).
    row = [
        ("colossus", lambda s: seated(s, True, True, "double", True), 1.0),
        ("colossus_broken", lambda s: seated(s, True, False, "", True), 1.0),
        ("colossus_fallen", lambda s: seated(s, False, True, "nemes", True), 1.0),
        ("crown_fallen", lambda s: (setattr(s, "place", Matrix.Scale(2.0, 4)), double_crown(s)), 1.0),
        ("god_ptah", lambda s: seated(s, True, True, "cap", False), 1.0),
        ("god_amun", lambda s: seated(s, True, True, "plumes", False), 1.0),
        ("god_king", lambda s: seated(s, True, True, "nemes", False), 1.0),
        ("god_ra", lambda s: seated(s, True, True, "falcon", False), 1.0),
        ("osiride_pillar", osiride_pillar, 1.0),
        ("square_pillar", square_pillar, 1.0),
        ("hathor_pillar", hathor_pillar, 1.0),
        ("king_standing", lambda s: standing(s, "king"), 1.0),
        ("queen_standing", lambda s: standing(s, "queen"), 1.0),
        ("ra_horakhty", lambda s: standing(s, "falcon"), 1.0),
        ("small_figure", lambda s: standing(s, "small"), 1.0),
        ("baboon", baboon, 1.0),
        ("falcon", falcon, 1.0),
        ("cow", cow, 1.0),
    ]
    x = -80.0
    for name, fill, _ in row:
        big = name.startswith(("colossus", "god_", "crown", "osiride", "square", "hathor"))
        part(name, fill, Matrix.Translation((x, 0.0, 60.0 if big else 45.0)))
        x += 10.0 if big else 3.0
        if name == "hathor_pillar":
            x = -80.0
    return made


def export():
    os.makedirs(OUT, exist_ok=True)
    bpy.ops.object.select_all(action="SELECT")
    bpy.ops.export_scene.gltf(
        filepath=os.path.join(OUT, "abu_simbel.glb"),
        export_format="GLB",
        export_yup=True,
        export_animations=False,
        export_materials="NONE",
        export_vertex_color="ACTIVE",
        export_all_vertex_colors=False,
        export_apply=False,
    )
    print("EXPORTED", os.path.join(OUT, "abu_simbel.glb"))


if "export" not in ARGS:
    build()
    bpy.ops.wm.save_as_mainfile(filepath=BLEND)
    print("SAVED", BLEND)
export()
