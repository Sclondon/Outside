"""Builds the sphinx and exports it for Godot.

Run from the project root:
    blender --background --python tools/build_sphinx.py
then, so that Godot takes up the new model:
    godot --headless --path . --import

Writes models/sphinx.glb, and tools/sphinx.blend to look at and to change by hand.

A lion of sandstone lying on a low base, its forelegs out in front, its hind
legs folded and its tail brought round the right haunch; and three heads to
put on its shoulders: a king's in the striped headcloth (the nemes, with the
cobra at the brow and the false beard), a ram's with its curled horns, and a
falcon's in a long wig.

It is modelled ONE METRE LONG, lying on the ground (the top of its base is
the ground), facing the game's +Z. The game makes it as long as a level asks
(`Sphinx.size`), and makes the base, the slab and the stele as thick as suits
that size. It has no bones: it is separate things, each named for what it is,
and scripts/sphinx_mesh.gd puts together the ones a sphinx wants:

    base                the block it lies on; 0.1 thick here, top at the ground
    body                the lion: trunk, haunches, hind paws, tail; and the way
                        through it from chest to rump, which is always there
    chest_plug, rump_plug
                        the stone that shuts each end of that way in a sphinx
                        that does not open
    passage_frames      the frame round each end of it in one that does
    foreleg             the right foreleg (the one that sweeps the slab). Its
                        origin is the elbow, where the game turns it. The left
                        is the same turned over (foreleg_mirror is only to look at).
    king_head           neck, ears and headcloth. Its origin is where the neck turns,
                        and so is the origin of everything else of a head.
    king_face           the face;  king_face_worn  the same with the nose broken off
    king_uraeus         the cobra at the brow (gone from a sphinx worn past a third)
    king_beard          the false beard (gone past a half)
    king_eye_l, king_eye_r
                        the eyes: each its own thing so that it can open and glow.
                        Its origin is its middle and its own +Z (Blender's -Y) is
                        the way it looks; the game squeezes it shut along its own Y.
    ram_head, ram_eye_l, ram_eye_r
    falcon_head         skull and wig;  falcon_beak;  falcon_beak_broken (worn past 0.7)
    falcon_eye_l, falcon_eye_r
    slab                the offering slab between the paws; origin its foot
    stele               the stele against the chest; origin its foot

Its colours are materials, named plainly. `stone`, `hollow` (the dark of the
way through) and `broken` (where something has broken off) are always stone.
The rest are paint: a painted sphinx shows each in the colour it has here, so
changing a material's Base Color and exporting again repaints it; a bare one
draws them as stone a little lighter or darker (how much is `TONE` in
sphinx_mesh.gd). `lapis` and `ochre` are the stripes of the cloth, cut into
it; `skin` the face; `kohl` the brows and the lines of the eyes; `horn` the
ram's horns and the falcon's beak. The slab's and stele's stone follow the
sphinx's own stone in the game, and `gold` is the game's gold.

(To export by hand: File, Export, glTF 2.0, to models/sphinx.glb, with +Y up,
everything, hidden things too. The other heads and the worn pieces are hidden
in the file so that the king can be seen; the eye in the outliner shows them.)

What is solid is NOT here: scripts/sphinx_mesh.gd works that out from the
numbers at the top of it (the same ones as below), so a lion made much fatter
or taller here would want those changed to match.

Everything below is written in the game's own directions (x across, y up, z
the way it faces, in metres) and turned to Blender's as it is made.
"""

import bpy
import bmesh
import math
import os
from mathutils import Matrix

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))

# The colours, as they are seen (sRGB).
COLOURS = {
    "stone": (0.66, 0.57, 0.43),
    "hollow": (0.2, 0.17, 0.13),
    "broken": (0.49, 0.42, 0.32),
    "lapis": (0.13, 0.25, 0.52),
    "ochre": (0.86, 0.64, 0.2),
    "skin": (0.62, 0.3, 0.2),
    "kohl": (0.09, 0.08, 0.08),
    "horn": (0.42, 0.31, 0.2),
    "eye": (0.3, 0.26, 0.19),
    "slab_stone": (0.54, 0.47, 0.35),
    "slab_mat": (0.3, 0.26, 0.19),
    "stele_stone": (0.68, 0.6, 0.46),
    "gold": (0.96, 0.7, 0.2),
}
NAMES = list(COLOURS)

# The same numbers as scripts/sphinx_mesh.gd, which makes what is solid from them.
PAW_OUT = 0.11
BASE = (0.235, 0.53)
BASE_DEEP = 0.1
BODY = [(-0.47, 0.105, 0.2), (-0.445, 0.135, 0.235), (-0.36, 0.15, 0.25), (-0.25, 0.145, 0.245), (-0.14, 0.125, 0.235),
        (-0.03, 0.13, 0.25), (0.05, 0.15, 0.28), (0.1, 0.152, 0.305), (0.13, 0.145, 0.31)]
HIND_OUT = 0.185
HAUNCH = (0.15, 0.0, -0.33)
HAUNCH_SIZE = (0.06, 0.2, 0.135)
CHEST = 0.13
RUMP = -0.47
WAY = (0.05, 0.16)
H = 0.17                    # how tall a head is, chin to crown
M = (0.0, 0.378, 0.098)     # the middle of a head
NECK = (0.0, 0.3, 0.08)     # where the neck turns
SLAB = 0.33
SLAB_HALF = (0.05, 0.06)
SLAB_TALL = 0.03
STELE = (0.104, 0.165, 0.02)
BEAST = H / 0.15            # the beasts' heads are set out for a head 0.15 tall, and made to the size of the king's


# --- Sums ---

def add(a, b):
    return (a[0] + b[0], a[1] + b[1], a[2] + b[2])


def sub(a, b):
    return (a[0] - b[0], a[1] - b[1], a[2] - b[2])


def mul(a, by):
    return (a[0] * by, a[1] * by, a[2] * by)


def mix(a, b, t):
    return tuple(a[i] + (b[i] - a[i]) * t for i in range(len(a)))


def dot(a, b):
    return a[0] * b[0] + a[1] * b[1] + a[2] * b[2]


def cross(a, b):
    return (a[1] * b[2] - a[2] * b[1], a[2] * b[0] - a[0] * b[2], a[0] * b[1] - a[1] * b[0])


def norm(a):
    long = math.sqrt(dot(a, a))
    return (a[0] / long, a[1] / long, a[2] / long) if long > 1e-12 else (0.0, 1.0, 0.0)


def lerp(a, b, t):
    return a + (b - a) * t


def smooth(a, b, x):
    """0 at `a`, 1 at `b` (either way round), eased."""
    t = min(max((x - a) / (b - a), 0.0), 1.0)
    return t * t * (3.0 - 2.0 * t)


def bump(value, at, wide):
    """A soft hill: 1 at `at`, nothing `wide` away."""
    off = abs(value - at) / wide
    return 0.0 if off >= 1.0 else (1.0 - off * off) ** 2


def curve(points, at):
    """Straight lines through (where, how much) pairs."""
    if at <= points[0][0]:
        return points[0][1]
    for a, b in zip(points, points[1:]):
        if at <= b[0]:
            return lerp(a[1], b[1], (at - a[0]) / (b[0] - a[0]))
    return points[-1][1]


def through(rows, t):
    """A smooth line through rows of numbers: `t` runs from 0 at the first to len-1 at the last."""
    last = len(rows) - 1
    i = min(max(int(math.floor(t)), 0), last - 1)
    f = t - i
    p0, p1, p2, p3 = rows[max(i - 1, 0)], rows[i], rows[i + 1], rows[min(i + 2, last)]
    return tuple(0.5 * (2.0 * p1[k] + (p2[k] - p0[k]) * f + (2.0 * p0[k] - 5.0 * p1[k] + 4.0 * p2[k] - p3[k]) * f * f
                        + (3.0 * p1[k] - p0[k] - 3.0 * p2[k] + p3[k]) * f * f * f) for k in range(len(p1)))


def at_first(rows, x):
    """The same, asked for by the first number of each row (which must rise)."""
    if x <= rows[0][0]:
        return rows[0]
    for i in range(len(rows) - 1):
        if x <= rows[i + 1][0]:
            made = through(rows, i + (x - rows[i][0]) / (rows[i + 1][0] - rows[i][0]))
            return (x,) + made[1:]
    return rows[-1]


def drawn(rows, count):
    """`count` rows spaced evenly along a smooth line through `rows`."""
    return [through(rows, (len(rows) - 1) * i / (count - 1.0)) for i in range(count)]


# --- Gathering faces ---

class Shape:
    """Faces being gathered for one thing: each a list of points, a material, and a skin.
    Skin 0 is flat. Faces of one skin are rounded into each other; where two skins meet there is an edge."""

    def __init__(self):
        self.faces = []

    def face(self, points, material, skin=0, out=None, middle=None):
        """A face that looks along `out`, or away from `middle` (a point, or what gives one for the face's own middle)."""
        kept = []
        for p in points:
            if not kept or max(abs(p[i] - kept[-1][i]) for i in range(3)) > 1e-7:
                kept.append(p)
        if len(kept) > 1 and max(abs(kept[0][i] - kept[-1][i]) for i in range(3)) <= 1e-7:
            kept.pop()
        if len(kept) < 3:
            return
        way = (0.0, 0.0, 0.0)
        for i in range(len(kept)):
            a, b = kept[i], kept[(i + 1) % len(kept)]
            way = add(way, ((a[1] - b[1]) * (a[2] + b[2]), (a[2] - b[2]) * (a[0] + b[0]), (a[0] - b[0]) * (a[1] + b[1])))
        if dot(way, way) < 1e-20:
            return
        centre = mul((sum(p[0] for p in kept), sum(p[1] for p in kept), sum(p[2] for p in kept)), 1.0 / len(kept))
        if middle is not None:
            out = sub(centre, middle(centre) if callable(middle) else middle)
        if out is not None and dot(way, out) < 0.0:
            kept.reverse()
        self.faces.append((kept, material, skin))

    def grid(self, rows, material, skin, out=None, middle=None):
        """Skin over rows of as many points each. `material` may be what gives one for (row, column)."""
        for i in range(len(rows) - 1):
            for j in range(len(rows[i]) - 1):
                paint = material(i, j) if callable(material) else material
                self.face([rows[i][j], rows[i][j + 1], rows[i + 1][j + 1], rows[i + 1][j]], paint, skin, out, middle)

    def fan(self, ring, material, skin, out, tip=None):
        """A ring filled in from its middle (or from `tip`)."""
        if tip is None:
            tip = mul((sum(p[0] for p in ring), sum(p[1] for p in ring), sum(p[2] for p in ring)), 1.0 / len(ring))
        for i in range(len(ring)):
            self.face([tip, ring[i], ring[(i + 1) % len(ring)]], material, skin, out)

    def box(self, low, high, material, lid=True, floor=False):
        c = [(high[0] if i & 1 else low[0], high[1] if i & 2 else low[1], high[2] if i & 4 else low[2]) for i in range(8)]
        self.face([c[0], c[2], c[6], c[4]], material, 0, (-1, 0, 0))
        self.face([c[1], c[3], c[7], c[5]], material, 0, (1, 0, 0))
        self.face([c[0], c[1], c[3], c[2]], material, 0, (0, 0, -1))
        self.face([c[4], c[5], c[7], c[6]], material, 0, (0, 0, 1))
        if lid:
            self.face([c[2], c[3], c[7], c[6]], material, 0, (0, 1, 0))
        if floor:
            self.face([c[0], c[1], c[5], c[4]], material, 0, (0, -1, 0))

    def tube(self, line, radii, sides, material, skin, squash=(1.0, 1.0), ends=(True, True), end_material=None):
        """A tube along a line of points, as thick at each as `radii` says. `material` may be what gives one for a stretch of it."""
        rings = []
        across = None
        for k in range(len(line)):
            along = norm(sub(line[min(k + 1, len(line) - 1)], line[max(k - 1, 0)]))
            if across is None:
                across = norm(cross(along, (0.0, 1.0, 0.0) if abs(along[1]) < 0.9 else (1.0, 0.0, 0.0)))
            else:
                # (carried along from the ring before, so the tube does not twist)
                across = norm(sub(across, mul(along, dot(across, along))))
            other = cross(along, across)
            ring = []
            for i in range(sides + 1):
                turn = math.tau * i / sides
                ring.append(add(line[k], add(mul(across, math.cos(turn) * radii[k] * squash[0]), mul(other, math.sin(turn) * radii[k] * squash[1]))))
            rings.append(ring)
        for k in range(len(rings) - 1):
            paint = material(k) if callable(material) else material
            self.grid([rings[k], rings[k + 1]], paint, skin, middle=mix(line[k], line[k + 1], 0.5))
        last = len(line) - 1
        if ends[0]:
            self.fan(rings[0][:-1], end_material or (material(0) if callable(material) else material), skin if end_material is None else 0, sub(line[0], line[1]), line[0])
        if ends[1]:
            self.fan(rings[last][:-1], end_material or (material(last - 1) if callable(material) else material), skin if end_material is None else 0, sub(line[last], line[last - 1]), line[last])

    def grow(self, about, by):
        self.faces = [([add(about, mul(sub(p, about), by)) for p in points], material, skin) for points, material, skin in self.faces]

    def take(self, other):
        self.faces += other.faces


def to_blender(p):
    return (p[0], -p[2], p[1])


TURN = Matrix(((1.0, 0.0, 0.0), (0.0, 0.0, -1.0), (0.0, 1.0, 0.0)))


def mesh_of(name, shape, origin, materials):
    made = bmesh.new()
    skins = made.faces.layers.int.new("skin")
    for points, material, skin in shape.faces:
        verts = [made.verts.new(to_blender(sub(p, origin))) for p in points]
        try:
            face = made.faces.new(verts)
        except ValueError:
            continue
        face.material_index = NAMES.index(material)
        face.smooth = skin != 0
        face[skins] = skin
    # (points that lie together are one point: what is rounded is rounded across them)
    bmesh.ops.remove_doubles(made, verts=made.verts, dist=0.00002)
    for edge in made.edges:
        around = edge.link_faces
        if len(around) == 2 and (around[0][skins] != around[1][skins] or around[0][skins] == 0):
            edge.smooth = False
    mesh = bpy.data.meshes.new(name)
    made.to_mesh(mesh)
    made.free()
    # (only the materials it uses, in the order of the list)
    used = sorted({polygon.material_index for polygon in mesh.polygons})
    for polygon in mesh.polygons:
        polygon.material_index = used.index(polygon.material_index)
    for index in used:
        mesh.materials.append(materials[index])
    return mesh


THINGS = []


def thing(name, shape, origin, materials, group, basis=None, hidden=False, mesh=None, mirrored=False, own=False):
    """A thing of the model. Its shape is set out where it stands, unless it is `own`: then it is set out about its own origin."""
    if mesh is None:
        mesh = mesh_of(name, shape, (0.0, 0.0, 0.0) if own or basis is not None else origin, materials)
    made = bpy.data.objects.new(name, mesh)
    group.objects.link(made)
    made.location = to_blender(origin)
    if basis is not None:
        # (its own x, y and z in the game's directions, turned to Blender's)
        own = Matrix([[basis[c][r] for c in range(3)] for r in range(3)])
        made.rotation_euler = (TURN @ own @ TURN.inverted()).to_euler()
    if mirrored:
        made.scale = (-1.0, 1.0, 1.0)
    THINGS.append((made, hidden))
    return made


# --- The lion ---

def section(x, z, half, tall, us, square=2.6):
    """A ring across something that lies on the ground: up one side, over the top and down the other.
    `us` are how far across each point of the top is, -1 to 1."""
    ring = [(x - half, 0.0, z)]
    for u in us:
        ring.append((x + half * u, tall * 0.5 * (1.0 + max(1.0 - abs(u) ** square, 0.0) ** (1.0 / square)), z))
    ring.append((x + half, 0.0, z))
    return ring


def trunk_ring(z, half, tall):
    """A ring across the trunk: two points up each side, and thirteen over the top."""
    ring = [(-half, tall * 0.5 * f, z) for f in (0.0, 0.5)]
    for i in range(13):
        turn = math.pi * (1.0 - i / 12.0)
        out = math.copysign(abs(math.cos(turn)) ** (2.0 / 2.6), math.cos(turn))
        ring.append((half * out, tall * 0.5 * (1.0 + abs(math.sin(turn)) ** (2.0 / 2.6)), z))
    ring += [(half, tall * 0.5 * f, z) for f in (0.5, 0.0)]
    return ring


def muscled(p, half, tall):
    """The lion under the skin of the trunk: shoulders, ribs, the hollow of the flank, the line of the spine."""
    x, y, z = p
    side = min(abs(x) / half, 1.0)
    way = math.copysign(1.0, x) if abs(x) > 1e-9 else 0.0
    top = smooth(tall * 0.7, tall * 0.95, y)
    # The shoulder: a mass standing out of the flank over the elbow, and the blade of it lifting the back.
    x += way * 0.017 * bump(z, 0.055, 0.1) * bump(y, 0.15, 0.14) * side
    y += 0.008 * bump(abs(x), 0.075, 0.06) * bump(z, 0.045, 0.07) * top
    # The ribs: four soft ridges behind the shoulder, leaning back as they go up.
    zz = z + 0.3 * (y - 0.12)
    where = smooth(-0.225, -0.19, zz) * (1.0 - smooth(-0.035, -0.005, zz))
    ribs = 0.5 - 0.5 * math.cos(math.tau * (zz + 0.2175) / 0.0535)
    x -= way * 0.0055 * where * ribs * bump(y, 0.125, 0.105) * side
    # The flank drawn in before the thigh, low down.
    x -= way * 0.009 * bump(z, -0.2, 0.075) * bump(y, 0.045, 0.09) * side
    # The hips, high at the back.
    x += way * 0.006 * bump(z, -0.37, 0.09) * bump(y, 0.17, 0.09) * side
    # The spine: a shallow line along the back between the muscles each side of it.
    y -= 0.005 * bump(x, 0.0, 0.035) * smooth(-0.45, -0.38, z) * (1.0 - smooth(-0.01, 0.06, z)) * top
    return (x, y, z)


def toed(ring, us, toes, start, front, pull):
    """Cuts toes into the rings of a paw: grooves between them that deepen towards the front, each toe rounded off at its end."""
    made = [ring[0]]
    for u, p in zip(us, ring[1:-1]):
        groove = max(bump(u, -1.0 + 2.0 * k / toes, 0.75 / toes) for k in range(1, toes))
        g = smooth(start, front, p[2])
        made.append((p[0], p[1] * (1.0 - 0.26 * g * groove), p[2] - pull * g * g * (0.9 * groove + 0.6 * u * u)))
    made.append(ring[-1])
    return made


FORE_US = [-1.0, -0.96, -0.875, -0.75, -0.625, -0.5, -0.375, -0.25, -0.125, 0.0, 0.125, 0.25, 0.375, 0.5, 0.625, 0.75, 0.875, 0.96, 1.0]
HIND_US = [-1.0, -0.95, -0.833, -0.667, -0.5, -0.333, -0.167, 0.0, 0.167, 0.333, 0.5, 0.667, 0.833, 0.95, 1.0]


def foreleg():
    """A foreleg from the elbow out to the toes: the elbow high against the flank, the long forearm, the wrist, and the paw with four toes."""
    s = Shape()
    # (where along it, half its width, its height)
    table = [(-0.056, 0.01, 0.04), (-0.052, 0.024, 0.085), (-0.042, 0.037, 0.125), (-0.02, 0.047, 0.15), (0.03, 0.051, 0.138), (0.085, 0.048, 0.112), (0.14, 0.044, 0.09),
             (0.21, 0.041, 0.079), (0.31, 0.039, 0.074), (0.393, 0.0395, 0.074), (0.42, 0.045, 0.079), (0.447, 0.051, 0.084),
             (0.468, 0.053, 0.08), (0.484, 0.051, 0.066), (0.494, 0.047, 0.046), (0.5, 0.042, 0.022)]
    rings = []
    for z, half, tall in table:
        ring = section(PAW_OUT, z, half, tall, FORE_US, 2.4)
        rings.append(toed(ring, FORE_US, 4, 0.405, 0.5, 0.017))
    s.grid(rings, "stone", 1, middle=lambda c: (PAW_OUT, 0.02, c[2]))
    s.fan(rings[-1], "stone", 1, (0.0, 0.0, 1.0))
    s.fan(rings[0], "stone", 1, (0.0, 0.0, -1.0))
    return s


def body():
    s = Shape()
    # The trunk: a skin over rings from the rump to the chest.
    stations = [RUMP, -0.458, -0.44, -0.41, -0.375, -0.34, -0.305, -0.27, -0.24] + [-0.215 + 0.0135 * i for i in range(16)] + [0.012, 0.04, 0.065, 0.09, 0.11, 0.123, CHEST]
    rings = []
    for z in stations:
        _, half, tall = at_first(BODY, z)
        if z >= CHEST:
            # (the edge of the chest rounded off)
            half *= 0.95
            tall *= 0.985
        rings.append([muscled(p, half, tall) for p in trunk_ring(z, half, tall)])
    s.grid(rings, "stone", 1, middle=lambda c: (0.0, 0.08, c[2]))
    # Its two ends, flat, each with the mouth of the way through it; and the way: two walls and a roof, dark.
    door = [(WAY[0], 0.0), (WAY[0], WAY[1]), (-WAY[0], WAY[1]), (-WAY[0], 0.0)]
    for ring, way in ((rings[0], -1.0), (rings[-1], 1.0)):
        z = ring[0][2]
        s.face(ring + [(x, y, z) for x, y in door], "stone", 0, (0.0, 0.0, way))
    for a, b in zip(door, door[1:]):
        s.face([(a[0], a[1], RUMP), (b[0], b[1], RUMP), (b[0], b[1], CHEST), (a[0], a[1], CHEST)], "hollow", 0, middle=lambda c: (c[0] * 3.0, c[1] + 0.1 if c[1] > 0.15 else c[1], c[2]))
    for side in (-1.0, 1.0):
        # A haunch: the thigh, a great round of muscle, its hip high and behind and its knee low and before.
        s.grid([[thigh(side, math.pi * 0.5 * k / 7.0, math.tau * i / 16.0) for i in range(17)] for k in range(8)], "stone", 2, middle=(side * HAUNCH[0], 0.02, HAUNCH[2]))
        # The hind foot, from the hock under the thigh forward along the flank to its toes.
        table = [(-0.37, 0.024, 0.036), (-0.3, 0.028, 0.048), (-0.21, 0.03, 0.049), (-0.157, 0.032, 0.05), (-0.134, 0.036, 0.055),
                 (-0.119, 0.036, 0.05), (-0.109, 0.034, 0.038), (-0.103, 0.03, 0.018)]
        hind = [toed(section(side * HIND_OUT, z, half, tall, HIND_US, 2.2), HIND_US, 3, -0.165, -0.103, 0.012) for z, half, tall in table]
        s.grid(hind, "stone", 3, middle=lambda c, side=side: (side * HIND_OUT, 0.015, c[2]))
        s.fan(hind[-1], "stone", 3, (0.0, 0.0, 1.0))
    # The tail: from the top of the rump down beside the way out, round behind the right haunch, and up over the thigh, lying on it, to its tuft.
    line = [(0.0, 0.2, -0.462), (0.045, 0.196, -0.476), (0.082, 0.168, -0.481), (0.098, 0.115, -0.484), (0.118, 0.055, -0.489), (0.155, 0.022, -0.488)]
    line += [thigh(1.0, math.radians(up), math.radians(turn), 0.011) for up, turn in ((7.0, -74.0), (15.0, -48.0), (27.0, -22.0), (40.0, 4.0), (53.0, 28.0), (63.0, 50.0))]
    line = drawn(line, 22)
    thick = [0.0155] * 17 + [0.017, 0.021, 0.0225, 0.018, 0.007]
    s.tube(line, thick, 6, "stone", 4)
    return s


def thigh(side, up, turn, proud=0.0):
    """A point on a thigh: `up` from the ground to its top, `turn` round it from straight out. `proud` is how far off it."""
    out = math.cos(up) ** 0.8
    y = math.sin(up) ** 0.92 * HAUNCH_SIZE[1]
    lean = 0.036 * (0.45 - y / HAUNCH_SIZE[1])
    at = (side * (HAUNCH[0] + math.cos(turn) * out * HAUNCH_SIZE[0]), y, HAUNCH[2] + math.sin(turn) * out * HAUNCH_SIZE[2] * (1.0 + 0.06 * math.sin(turn)) + lean)
    away = norm((side * math.cos(turn) * math.cos(up) / HAUNCH_SIZE[0], math.sin(up) / HAUNCH_SIZE[1], math.sin(turn) * math.cos(up) / HAUNCH_SIZE[2]))
    return add(at, mul(away, proud))


def plug(z, way):
    s = Shape()
    s.face([(-WAY[0], 0.0, z), (WAY[0], 0.0, z), (WAY[0], WAY[1], z), (-WAY[0], WAY[1], z)], "stone", 0, (0.0, 0.0, way))
    return s


def passage_frames():
    """A frame round each end of the way through, standing a little proud."""
    s = Shape()
    for front, proud in ((CHEST, 0.006), (RUMP, -0.006)):
        near, far = min(front, front + proud), max(front, front + proud)
        for side in (-1.0, 1.0):
            s.box((min(side * WAY[0], side * (WAY[0] + 0.012)), 0.0, near), (max(side * WAY[0], side * (WAY[0] + 0.012)), WAY[1] + 0.012, far), "lapis")
        s.box((-WAY[0], WAY[1], near), (WAY[0], WAY[1] + 0.012, far), "lapis", True, True)
    return s


def base():
    s = Shape()
    s.box((-BASE[0], -BASE_DEEP, -BASE[1]), (BASE[0], 0.0, BASE[1]), "stone")
    return s


# --- The heads ---

def neck(s, wide, material):
    """The neck: from the shoulders up into the head."""
    rings = []
    for middle, across, along in (((0.0, 0.235, 0.075), 0.095 * wide, 0.075 * wide), ((0.0, 0.265, 0.081), 0.076 * wide, 0.065 * wide), ((0.0, 0.29, 0.086), 0.064 * wide, 0.058 * wide),
                                  ((0.0, M[1] - 0.035, M[2] - 0.008), 0.05 * wide, 0.05)):
        rings.append([add(middle, (math.sin(math.tau * i / 12.0) * across, 0.0, math.cos(math.tau * i / 12.0) * along)) for i in range(13)])
    s.grid(rings, material, 6, middle=lambda c: (0.0, c[1], 0.08))


def face(across, up, nose=1.0, lift=0.0):
    """A point on the king's face: `across` degrees round from straight ahead, `up` degrees above level."""
    a = abs(across)
    lon = math.radians(across)
    lat = math.radians(up)
    # The skull, and the jaw drawn in under it.
    jaw = 1.0 - 0.17 * smooth(-10.0, -68.0, up)
    out = 1.0 + lift
    # The brow: a ridge over each eye, and the hollow of the eye under it.
    out += 0.03 * bump(up, 21.0, 5.5) * smooth(3.0, 11.0, a) * (1.0 - smooth(46.0, 60.0, a))
    out -= 0.052 * bump(up, 11.0, 9.0) * bump(a, 24.5, 16.0)
    # The nose: narrow between the eyes, broad at the nostrils, straight down its ridge to the tip and cut back under it.
    half = curve([(-12.0, 7.0), (-9.5, 12.5), (-5.0, 12.5), (0.0, 9.0), (8.0, 6.5), (18.0, 7.0), (25.0, 10.0)], up)
    ridge = 1.0 - smooth(half * 0.3, half, a)
    tip = curve([(-12.0, 0.03), (-10.2, 0.1), (-8.0, 0.225), (-5.5, 0.245), (-2.0, 0.205), (4.0, 0.14), (11.0, 0.08), (18.0, 0.035), (25.0, 0.0)], up)
    out += ridge * tip * nose
    out += 0.04 * nose * bump(up, -6.8, 3.4) * bump(a, 9.5, 4.5)
    if nose < 0.5:
        # (broken off: a rough scar where it was)
        out -= ridge * 0.022 * smooth(-11.0, -8.0, up) * (1.0 - smooth(9.0, 13.0, up)) * (0.7 + 0.3 * math.sin(across * 1.9 + up * 2.3))
    # Cheekbones, and the cheek full beside the nose and mouth.
    out += 0.04 * bump(up, -3.0, 15.0) * bump(a, 41.0, 22.0)
    out += 0.012 * bump(up, -12.0, 9.0) * bump(a, 22.0, 11.0)
    # The mouth: full lips, a line between them, its corners tucked in and a little lifted.
    m = across / 18.5
    mouth = max(0.0, 1.0 - m * m)
    lip = up - 0.5 * m * m
    out += mouth ** 0.7 * (0.088 * bump(lip, -17.2, 2.9) + 0.08 * bump(lip, -23.4, 3.3) - 0.05 * bump(lip, -20.2, 1.4))
    out -= 0.012 * bump(up, -20.0, 4.5) * bump(a, 22.5, 5.0)
    out -= 0.012 * bump(up, -13.4, 3.0) * bump(a, 0.0, 3.5)
    # The hollow under the lip, and the chin.
    out -= 0.022 * bump(up, -29.5, 4.0) * bump(a, 0.0, 17.0)
    out += 0.075 * bump(up, -43.0, 15.0) * (1.0 - smooth(16.0, 44.0, a))
    # The corners of the jaw.
    out += 0.05 * bump(up, -40.0, 20.0) * bump(a, 62.0, 30.0)
    return add(M, mul((math.sin(lon) * math.cos(lat) * 0.4 * jaw, math.sin(lat) * 0.52, math.cos(lon) * math.cos(lat) * 0.42), H * out))


FACE_ACROSS = [125.0, 98.0, 76.0, 60.0, 52.0, 44.0, 37.0, 31.0, 26.0, 21.0, 16.5, 12.5, 8.5, 5.5, 2.5]
FACE_ACROSS = [-a for a in FACE_ACROSS] + [0.0] + FACE_ACROSS[::-1]
FACE_UP = [40.0, 32.0, 26.0, 22.5, 19.5, 16.5, 13.5, 11.0, 8.5, 5.5, 2.0, -2.0, -5.5, -8.0, -10.0, -12.0, -14.5, -16.3, -18.0, -19.5, -20.3, -21.2, -23.0, -25.0,
           -27.5, -31.0, -36.0, -42.0, -50.0, -60.0, -72.0]


def eye_facing(side):
    at = sub(face(side * 24.0, 11.0), M)
    return norm((at[0] / (0.4 * 0.4), at[1] / (0.52 * 0.52), at[2] / (0.42 * 0.42)))


def king_face(nose):
    s = Shape()
    rows = [[face(across, up, nose) for across in FACE_ACROSS] for up in FACE_UP]

    def paint(i, j):
        across = abs(FACE_ACROSS[j] + FACE_ACROSS[j + 1]) * 0.5
        up = (FACE_UP[i] + FACE_UP[i + 1]) * 0.5
        # The brows, in black; and where the nose was, broken stone.
        if 19.5 < up < 22.5 and 8.5 < across < 52.0:
            return "kohl"
        if nose < 0.5 and across < 8.5 and -10.0 < up < 8.5:
            return "broken"
        return "skin"
    s.grid(rows, paint, 7, middle=M)
    for side in (-1.0, 1.0):
        # The line of paint round each eye, drawn out towards the temple.
        facing = eye_facing(side)
        at = face(side * 24.0, 11.0, nose, 0.03)
        across = norm(cross((0.0, 1.0, 0.0), facing))
        up = cross(facing, across)
        rim = []
        for i in range(14):
            turn = math.tau * i / 14.0
            wide = math.cos(turn)
            high = math.sin(turn) * (1.0 - 0.42 * wide * wide)
            rim.append(add(at, mul(add(mul(across, wide * 0.122), mul(up, high * 0.058 + wide * side * 0.014)), H)))
        s.fan(rim, "kohl", 0, facing, at)
        line = [(31.0, 12.6, 9.4), (38.0, 13.2, 10.3), (45.0, 13.9, 11.4), (53.0, 14.4, 12.6)]
        s.grid([[face(side * a, top, nose, 0.03) for a, top, low in line], [face(side * a, low, nose, 0.03) for a, top, low in line]], "kohl", 0, facing)
    return s


def headcloth(s, flare, band):
    """The headcloth: a cap over the skull, a band across the brow, and the cloth falling from it behind the ears to a
    wing at each shoulder, drawn in behind to its tail; with a lappet hanging from each wing down the chest. Striped.
    `flare` is how far the wings stand out (the king's nemes stands out wide; a god's wig hangs close)."""
    stripes = ("lapis", "ochre")
    brow = M[1] + 0.27 * H
    crown = M[1] + 0.57 * H
    hem = M[1] - 0.72 * H
    hub = M[2] - 0.05 * H
    # The cap: rings from the brow up to the crown.
    around, rise = 20, 6
    rings = []
    for k in range(rise + 1):
        up = math.pi * 0.5 * k / rise
        out = math.cos(up) ** 0.66
        rings.append([(math.sin(math.tau * i / around) * 0.43 * H * out, lerp(brow, crown, math.sin(up)), hub + math.cos(math.tau * i / around) * 0.45 * H * out) for i in range(around + 1)])
    s.grid(rings, lambda i, j: stripes[i % 2], 8, middle=(0.0, brow, hub))
    if not band:
        # (closed underneath, where a head smaller than the wig would show the sky through it)
        s.fan(rings[0][:-1], "kohl", 0, (0.0, -1.0, 0.0), (0.0, brow, hub))
    if band:
        # The band across the brow, from ear to ear.
        rows = [[], [], [], [], []]
        for i in range(17):
            turn = lerp(-math.pi * 0.5, math.pi * 0.5, i / 16.0)
            x, z = math.sin(turn) * H, math.cos(turn) * H
            rows[0].append((x * 0.43, brow + 0.02 * H, hub + z * 0.45))
            rows[1].append((x * 0.452, brow + 0.012 * H, hub + z * 0.474))
            rows[2].append((x * 0.452, brow - 0.04 * H, hub + z * 0.474))
            rows[3].append((x * 0.43, brow - 0.05 * H, hub + z * 0.45))
            rows[4].append((x * 0.33, brow - 0.05 * H, hub + z * 0.35))
        s.grid(rows, "ochre", 9, middle=(0.0, brow - 0.03 * H, hub))
    # The cloth behind: from the brow down to the hem, round the back from one side to the other.
    down, back = 10, 14
    falls = []
    inner = []
    for k in range(down + 1):
        t = k / float(down)
        y = lerp(brow, hem, t)
        wide = lerp(0.43, flare, t ** 1.15) * H
        deep = lerp(0.45, 0.6, t) * H
        point = lerp(1.0, 1.45, t)
        falls.append([(math.sin(lerp(-math.pi * 0.5, math.pi * 0.5, i / float(back))) * wide, y,
                       hub - math.cos(lerp(-math.pi * 0.5, math.pi * 0.5, i / float(back))) ** point * deep) for i in range(back + 1)])
        # (and where the front of each wing meets the side of the face)
        inner.append((lerp(0.3, 0.18, t) * H, y, M[2] - 0.03 * H))
    s.grid(falls, lambda i, j: stripes[i % 2], 10, middle=lambda c: (0.0, c[1], hub))
    for k in range(down):
        # The front of each wing: flat, facing forward, between the face and the edge of the cloth.
        for side, edge in ((-1.0, 0), (1.0, back)):
            s.face([(inner[k][0] * side, inner[k][1], inner[k][2]), falls[k][edge], falls[k + 1][edge], (inner[k + 1][0] * side, inner[k + 1][1], inner[k + 1][2])],
                   stripes[k % 2], 0, (0.0, 0.0, 1.0))
    # Under the hem, closed.
    s.fan(falls[down], "kohl", 0, (0.0, -1.0, 0.0), (0.0, hem, hub))
    # The lappets: a striped tongue of cloth from each wing down onto the chest, rounded at its foot.
    end = M[1] - 0.378 + 0.185
    front = CHEST + 0.02
    behind = CHEST - 0.01
    top_out = min(0.6, flare * 0.66)
    count = 7
    for side in (-1.0, 1.0):
        rows = []
        for k in range(count + 1):
            t = k / float(count)
            y = lerp(hem, end, t)
            # (drawn in at the last, for the rounded foot)
            foot = 0.05 * H * smooth(0.86, 1.0, t)
            x0 = lerp(0.2, 0.22, t) * H + foot
            x1 = lerp(top_out, 0.5, t) * H - foot
            soft = 0.045 * H
            rows.append([(side * x0, y, behind), (side * x0, y, front - soft * 0.6), (side * (x0 + soft), y, front), (side * (x1 - soft), y, front),
                         (side * x1, y, front - soft * 0.6), (side * x1, y, behind)])
        s.grid(rows, lambda i, j: stripes[(i + 1) % 2], 11 if side < 0.0 else 12, middle=lambda c, side=side: (side * 0.35 * H, c[1], behind))
        s.face(rows[count], stripes[count % 2], 0, (0.0, -1.0, 0.0))
        s.face([(side * 0.2 * H, hem, front), (side * top_out * H, hem, front), (side * top_out * H, hem, M[2]), (side * 0.2 * H, hem, M[2])], "ochre", 0, (0.0, 1.0, 0.0))
    # The tail of the cloth, bound and lying down the back.
    line = drawn([(0.0, hem + 0.1 * H, hub - 0.5 * H), (0.0, hem - 0.1 * H, hub - 0.55 * H), (0.0, hem - 0.25 * H, hub - 0.62 * H), (0.0, hem - 0.4 * H, hub - 0.78 * H),
                  (0.0, hem - 0.5 * H, hub - 0.95 * H)], 7)
    s.tube(line, [0.16 * H, 0.15 * H, 0.135 * H, 0.12 * H, 0.105 * H, 0.088 * H, 0.07 * H], 8, lambda k: stripes[k % 2], 13)


def king_head():
    s = Shape()
    neck(s, 1.0, "skin")
    for side in (-1.0, 1.0):
        # An ear, standing out in front of the cloth: a rim, and the hollow within it.
        middle = add(M, mul((side * 0.385, 0.035, 0.015), H))
        out = norm((side * 0.72, 0.0, 0.69))
        along = cross((0.0, 1.0, 0.0), out)
        rings = []
        for reach, proud in ((1.0, -0.03), (0.86, 0.055), (0.55, 0.03), (0.0, 0.022)):
            rings.append([add(middle, mul(add(add(mul(along, math.cos(math.tau * i / 12.0) * reach * 0.085), (0.0, math.sin(math.tau * i / 12.0) * reach * 0.155, 0.0)), mul(out, proud)), H))
                          for i in range(13)])
        s.grid(rings, "skin", 14 if side < 0.0 else 15, out)
    headcloth(s, 0.95, True)
    return s


def uraeus():
    """The cobra reared at the brow: its body risen from the band, its hood spread, its head; and its tail lying back over the cap."""
    s = Shape()
    brow = M[1] + 0.27 * H
    hub = M[2] - 0.05 * H
    foot = (0.0, brow - 0.06 * H, hub + 0.468 * H)
    # (how high, how far forward, half its width, half its depth)
    table = [(0.0, 0.0, 0.03, 0.022), (0.05, 0.012, 0.036, 0.022), (0.1, 0.03, 0.07, 0.02), (0.145, 0.045, 0.088, 0.018), (0.185, 0.058, 0.07, 0.018), (0.215, 0.068, 0.034, 0.024),
             (0.235, 0.085, 0.03, 0.026), (0.238, 0.112, 0.016, 0.014)]
    rings = []
    for up, forward, wide, deep in table:
        rings.append([add(foot, mul((math.sin(math.tau * i / 8.0) * wide, up + math.cos(math.tau * i / 8.0) * deep * 0.25, forward + math.cos(math.tau * i / 8.0) * deep), H)) for i in range(9)])
    s.grid(rings, "ochre", 1, middle=lambda c: (0.0, c[1], foot[2] + (c[1] - foot[1]) * 0.3))
    s.fan(rings[-1][:-1], "ochre", 1, (0.0, 0.2, 1.0))
    line = [add(foot, mul(p, H)) for p in ((0.0, 0.07, -0.01), (0.02, 0.15, -0.05), (-0.02, 0.23, -0.14), (0.015, 0.285, -0.27), (0.0, 0.31, -0.4))]
    s.tube(drawn(line, 7), [0.022 * H] * 5 + [0.017 * H, 0.008 * H], 5, "ochre", 2)
    return s


def beard():
    """The false beard, strapped under the chin: plaited, a little wider at its foot, and turned forward there."""
    s = Shape()
    chin = add(M, mul((0.0, -0.5, 0.27), H))
    rings = []
    for k, (down, forward, wide, deep) in enumerate(((0.0, 0.0, 0.07, 0.056), (0.07, 0.0, 0.078, 0.062), (0.14, 0.0, 0.074, 0.06), (0.21, 0.004, 0.086, 0.068), (0.28, 0.012, 0.084, 0.068),
                                                     (0.33, 0.024, 0.098, 0.076), (0.365, 0.04, 0.09, 0.07))):
        rings.append([add(chin, mul((math.sin(math.tau * i / 8.0) * wide, -down, forward + math.cos(math.tau * i / 8.0) * deep), H)) for i in range(9)])
    s.grid(rings, "lapis", 1, middle=lambda c: (0.0, c[1], chin[2]))
    s.fan(rings[-1][:-1], "lapis", 0, (0.0, -1.0, 0.2))
    return s


def eye(half_wide, half_high, lift):
    """An eye: an almond, drawn to a point at each corner, a little rounded forward. In its own directions (z is the way it looks)."""
    s = Shape()
    rim = []
    for i in range(12):
        turn = math.tau * i / 12.0
        wide = math.cos(turn)
        high = math.sin(turn) * (1.0 - 0.45 * wide * wide)
        rim.append((wide * half_wide, high * half_high + wide * lift, 0.0))
    s.fan(rim, "eye", 1, (0.0, 0.0, 1.0), (0.0, 0.0, half_high * 0.3))
    return s


def looking(facing):
    """An eye's own x, y and z, for one that looks along `facing`."""
    across = norm(cross((0.0, 1.0, 0.0), facing))
    return (across, cross(facing, across), facing)


def beast(p):
    return add(M, mul(sub(p, M), BEAST))


RAM_SKULL = add(M, (0.0, 0.0, -0.005))
RAM_ALONG = norm((0.0, -0.42, 0.91))
RAM_OVER = norm((0.0, 0.91, 0.42))
# The ram's head from the back of its skull to its muzzle: where along it, half its width, half its height, how far it is lifted.
RAM = [(-0.07, 0.012, 0.014, 0.0), (-0.062, 0.032, 0.035, 0.0), (-0.045, 0.05, 0.055, 0.0), (-0.01, 0.06, 0.066, 0.0), (0.035, 0.055, 0.058, 0.005), (0.075, 0.041, 0.044, 0.01),
       (0.105, 0.033, 0.035, 0.009), (0.126, 0.029, 0.029, 0.004), (0.137, 0.023, 0.021, -0.001), (0.1435, 0.011, 0.01, -0.004)]


def ram_skin(along, turn, proud=1.0):
    """A point on the ram's head: how far along it, and how far round from the top of it."""
    _, wide, high, lift = at_first(RAM, along)
    # (broad across the forehead, narrower in the jaw)
    under = max(-math.cos(turn), 0.0)
    middle = add(RAM_SKULL, add(mul(RAM_ALONG, along), mul(RAM_OVER, lift)))
    return add(middle, add((math.sin(turn) * wide * (1.0 - 0.2 * under) * proud, 0.0, 0.0), mul(RAM_OVER, math.cos(turn) * high * proud)))


def ram_eye(side):
    facing = norm((side * 0.72, 0.22, 0.66))
    return add(ram_skin(0.035, side * math.radians(51.0)), mul(facing, 0.004)), facing


def ram_head():
    s = Shape()
    alongs = [-0.07, -0.062, -0.045, -0.028, -0.01, 0.012, 0.035, 0.055, 0.075, 0.09, 0.105, 0.116, 0.126, 0.137, 0.1435]
    s.grid([[ram_skin(along, math.tau * i / 14.0) for i in range(15)] for along in alongs], "stone", 1, middle=lambda c: add(RAM_SKULL, mul(RAM_ALONG, dot(sub(c, RAM_SKULL), RAM_ALONG))))
    # (the end of its muzzle is its nose, dark)
    s.fan([ram_skin(alongs[-1], math.tau * i / 14.0) for i in range(14)], "kohl", 0, RAM_ALONG)
    s.fan([ram_skin(alongs[0], math.tau * i / 14.0) for i in range(14)], "stone", 1, mul(RAM_ALONG, -1.0))
    for side in (-1.0, 1.0):
        # The line of its mouth.
        low, high = side * math.radians(118.0), side * math.radians(107.0)
        mouth = [0.09, 0.105, 0.116, 0.126, 0.137, 0.1425]
        s.grid([[ram_skin(a, high, 1.04) for a in mouth], [ram_skin(a, low, 1.04) for a in mouth]], "kohl", 0, (side, -0.2, 0.3))
        # A horn: from the top of the skull back, down, forward under the ear and up again, drawing in and thinning as it goes. Ridged.
        line = []
        girth = []
        turns = 27
        for k in range(turns):
            f = k / (turns - 1.0)
            round_ = math.radians(lerp(-15.0, 335.0, f))
            reach = lerp(0.064, 0.036, f)
            line.append(add(RAM_SKULL, (side * (0.05 + 0.07 * f), -0.014 + reach * math.cos(round_), -0.012 - reach * math.sin(round_))))
            girth.append(lerp(0.034, 0.006, f ** 1.25) * (1.05 if k % 2 else 0.95))
        s.tube(line, girth, 8, lambda k: ("ochre", "horn")[k % 2], 2 if side < 0.0 else 3)
        # An ear, in the curl of the horn.
        root = add(RAM_SKULL, (side * 0.045, -0.006, -0.02))
        s.tube([root, add(root, (side * 0.022, -0.012, -0.002)), add(root, (side * 0.042, -0.025, -0.004)), add(root, (side * 0.054, -0.033, -0.005))], [0.011, 0.015, 0.011, 0.002], 6, "stone",
               4 if side < 0.0 else 5, (1.0, 0.45))
    s.grow(M, BEAST)
    neck(s, 1.25, "stone")
    return s


FALCON_SKULL = add(M, (0.0, -0.004, 0.034))
FALCON_SIZE = (0.06, 0.066, 0.068)


def falcon_eye(side):
    facing = norm((side * 0.56, 0.08, 0.82))
    at = add(FALCON_SKULL, mul((facing[0] * FALCON_SIZE[0], facing[1] * FALCON_SIZE[1], facing[2] * FALCON_SIZE[2]), 1.03))
    return at, facing


def falcon_head():
    s = Shape()
    # The skull: a ball, a little flat on top, with a brow jutting over each eye and the face drawn in towards the beak.
    rows = []
    for k in range(11):
        up = lerp(-math.pi * 0.5, math.pi * 0.5, k / 10.0)
        row = []
        for i in range(17):
            turn = math.tau * i / 16.0 - math.pi
            across = abs(math.degrees(turn))
            high = math.degrees(up)
            out = 1.0 + 0.085 * bump(high, 24.0, 15.0) * bump(across, 36.0, 26.0) - 0.035 * bump(high, 2.0, 14.0) * bump(across, 36.0, 18.0) - 0.05 * bump(high, -28.0, 26.0) * bump(across, 24.0, 16.0)
            row.append(add(FALCON_SKULL, (math.sin(turn) * math.cos(up) * FALCON_SIZE[0] * out, math.sin(up) * FALCON_SIZE[1] * (0.92 if up > 0.0 else 1.0) * out,
                                           math.cos(turn) * math.cos(up) * FALCON_SIZE[2] * out)))
        rows.append(row)
    s.grid(rows, "stone", 1, middle=FALCON_SKULL)
    for side in (-1.0, 1.0):
        # The ring round a falcon's eye, and the mark that runs down its cheek and back.
        at, facing = falcon_eye(side)
        across, up, _ = looking(facing)
        s.fan([add(at, add(mul(across, math.cos(math.tau * i / 12.0) * 0.026), mul(up, math.sin(math.tau * i / 12.0) * 0.023))) for i in range(12)], "kohl", 0, facing, at)
        start = add(add(at, mul(up, -0.02)), mul(across, side * 0.004))
        mark = drawn([start, add(FALCON_SKULL, mul((side * 0.047, -0.028, 0.047), 1.04)), add(FALCON_SKULL, mul((side * 0.05, -0.04, 0.036), 1.04)), add(FALCON_SKULL, mul((side * 0.055, -0.05, 0.016), 1.04)),
                      add(FALCON_SKULL, mul((side * 0.054, -0.05, -0.004), 1.04))], 7)
        wide = [0.0075, 0.007, 0.0065, 0.006, 0.0055, 0.004, 0.001]
        way = norm((side * 0.25, 0.0, -1.0))
        s.grid([[add(p, mul(norm(cross(sub(p, FALCON_SKULL), (0.0, 1.0, 0.0))), w)) for p, w in zip(mark, wide)], [add(p, mul(norm(cross(sub(p, FALCON_SKULL), (0.0, 1.0, 0.0))), -w)) for p, w in zip(mark, wide)]],
               "kohl", 0, middle=FALCON_SKULL)
    s.grow(M, BEAST)
    neck(s, 1.0, "stone")
    headcloth(s, 0.66, False)
    return s


def falcon_beak(broken):
    """The beak: out from the face, and hooked down to a point; yellow where it meets the face. And the lower half of it, under."""
    s = Shape()
    line = drawn([add(FALCON_SKULL, p) for p in ((0.0, 0.004, 0.04), (0.0, 0.0, 0.074), (0.0, -0.011, 0.094), (0.0, -0.03, 0.101), (0.0, -0.05, 0.093))], 9)
    girth = [g[0] for g in drawn([(0.036,), (0.028,), (0.021,), (0.012,), (0.002,)], 9)]
    if broken:
        # (the tip of it broken off)
        line, girth = line[:5], girth[:5]
    s.tube(line, girth, 8, lambda k: "ochre" if k == 0 else "horn", 1, (0.78, 1.0), (False, True), "broken" if broken else None)
    s.tube([add(FALCON_SKULL, p) for p in ((0.0, -0.022, 0.045), (0.0, -0.026, 0.066), (0.0, -0.031, 0.082))], [0.018, 0.013, 0.003], 6, "horn", 2, (0.8, 0.6), (False, True))
    s.grow(M, BEAST)
    return s


# --- The slab and the stele ---

def slab():
    """The offering slab: low, its top edge taken off, with the mat and the loaf of the sign for an offering cut in the top of it."""
    s = Shape()
    x, z, tall, off = SLAB_HALF[0], SLAB_HALF[1], SLAB_TALL, 0.003
    s.box((-x, 0.0, -z), (x, tall - off, z), "slab_stone", False)
    low = [(-x, tall - off, -z), (x, tall - off, -z), (x, tall - off, z), (-x, tall - off, z)]
    high = [(-x + off, tall, -z + off), (x - off, tall, -z + off), (x - off, tall, z - off), (-x + off, tall, z - off)]
    for i in range(4):
        s.face([low[i], low[(i + 1) % 4], high[(i + 1) % 4], high[i]], "slab_stone", 0, middle=(0.0, 0.0, 0.0))
    s.face(high, "slab_stone", 0, (0.0, 1.0, 0.0))
    # The mat, before; and the loaf on it, behind: a low round.
    s.box((-x * 0.62, tall, z * 0.48 - z * 0.2), (x * 0.62, tall + 0.001, z * 0.48 + z * 0.2), "slab_mat")
    middle = (0.0, tall, -z * 0.24)
    rings = [[add(middle, (math.sin(math.tau * i / 14.0) * 0.02 * reach, up, math.cos(math.tau * i / 14.0) * 0.02 * reach)) for i in range(15)]
             for reach, up in ((1.0, 0.0), (0.92, 0.0011), (0.6, 0.0017), (0.0, 0.002))]
    s.grid(rings, "gold", 1, (0.0, 1.0, 0.0))
    return s


def stele():
    """The stele: a slab with a round top, and the sun's disc in the round. Its front is left flat for the riddle, which the game writes on it."""
    s = Shape()
    wide, tall, thick = STELE[0] * 0.5, STELE[1], STELE[2] * 0.5
    outline = [(-wide, 0.0), (-wide, tall)] + [(-math.cos(math.pi * i / 16.0) * wide, tall + math.sin(math.pi * i / 16.0) * wide) for i in range(1, 16)] + [(wide, tall), (wide, 0.0)]
    s.face([(x, y, thick) for x, y in outline], "stele_stone", 0, (0.0, 0.0, 1.0))
    s.face([(x, y, -thick) for x, y in outline], "stele_stone", 0, (0.0, 0.0, -1.0))
    s.grid([[(x, y, thick) for x, y in outline], [(x, y, -thick) for x, y in outline]], "stele_stone", 0, middle=lambda c: (0.0, min(c[1], tall), 0.0))
    middle = (0.0, tall + STELE[0] * 0.17, thick)
    radius = STELE[0] * 0.13
    rings = [[add(middle, (math.sin(math.tau * i / 14.0) * radius * reach, math.cos(math.tau * i / 14.0) * radius * reach, proud)) for i in range(15)]
             for reach, proud in ((1.0, 0.0), (1.0, 0.0014), (0.8, 0.0019), (0.0, 0.0021))]
    s.grid(rings, "gold", 1, (0.0, 0.0, 1.0))
    return s


def linear(c):
    return c / 12.92 if c <= 0.04045 else ((c + 0.055) / 1.055) ** 2.4


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
    groups = {}
    for label in ("lion", "king", "ram", "falcon", "offering"):
        groups[label] = bpy.data.collections.new(label)
        bpy.context.scene.collection.children.link(groups[label])
    zero = (0.0, 0.0, 0.0)

    lion = groups["lion"]
    thing("base", base(), zero, materials, lion)
    thing("body", body(), zero, materials, lion)
    thing("chest_plug", plug(CHEST, 1.0), zero, materials, lion)
    thing("rump_plug", plug(RUMP, -1.0), zero, materials, lion)
    thing("passage_frames", passage_frames(), zero, materials, lion, hidden=True)
    elbow = (PAW_OUT, 0.0, 0.0)
    leg = thing("foreleg", foreleg(), elbow, materials, lion)
    thing("foreleg_mirror", None, (-PAW_OUT, 0.0, 0.0), materials, lion, mesh=leg.data, mirrored=True)

    king = groups["king"]
    thing("king_head", king_head(), NECK, materials, king)
    thing("king_face", king_face(1.0), NECK, materials, king)
    thing("king_face_worn", king_face(0.0), NECK, materials, king, hidden=True)
    thing("king_uraeus", uraeus(), NECK, materials, king)
    thing("king_beard", beard(), NECK, materials, king)
    for side, label in ((1.0, "king_eye_l"), (-1.0, "king_eye_r")):
        facing = eye_facing(side)
        at = add(face(side * 24.0, 11.0, 1.0, 0.035), mul(facing, 0.012 * H))
        thing(label, eye(0.085 * H, 0.04 * H, side * 0.012 * H), at, materials, king, looking(facing))

    ram = groups["ram"]
    thing("ram_head", ram_head(), NECK, materials, ram, hidden=True)
    for side, label in ((1.0, "ram_eye_l"), (-1.0, "ram_eye_r")):
        at, facing = ram_eye(side)
        thing(label, eye(0.017 * BEAST, 0.011 * BEAST, 0.0), beast(at), materials, ram, looking(facing), hidden=True)

    falcon = groups["falcon"]
    thing("falcon_head", falcon_head(), NECK, materials, falcon, hidden=True)
    thing("falcon_beak", falcon_beak(False), NECK, materials, falcon, hidden=True)
    thing("falcon_beak_broken", falcon_beak(True), NECK, materials, falcon, hidden=True)
    for side, label in ((1.0, "falcon_eye_l"), (-1.0, "falcon_eye_r")):
        at, facing = falcon_eye(side)
        thing(label, eye(0.019 * BEAST, 0.0165 * BEAST, 0.0), beast(add(at, mul(facing, 0.006))), materials, falcon, looking(facing), hidden=True)

    offering = groups["offering"]
    thing("slab", slab(), (0.0, 0.0, SLAB), materials, offering, own=True)
    thing("stele", stele(), (0.0, 0.0, CHEST + 0.023 + STELE[2] * 0.5), materials, offering, own=True)

    bpy.context.view_layer.update()
    for made, hidden in THINGS:
        made.data.calc_loop_triangles()
        print("  %-20s %5d triangles" % (made.name, len(made.data.loop_triangles)))
        made.hide_set(hidden)
    os.makedirs(os.path.join(ROOT, "models"), exist_ok=True)
    bpy.ops.wm.save_as_mainfile(filepath=os.path.join(ROOT, "tools", "sphinx.blend"))
    bpy.ops.export_scene.gltf(
        filepath=os.path.join(ROOT, "models", "sphinx.glb"),
        export_format="GLB",
        export_yup=True,
        export_animations=False,
        use_visible=False,
    )
    print("BUILT sphinx")


build()
