"""Builds the parts an Egyptian temple is set out from (scripts/temple.gd): every part is
an object of its own, plainly named, in tools/temple.blend, and all of them are exported
together to models/temple/temple.glb.

Run from the project root:
    blender --background --python tools/build_temple.py
then
    godot --headless --path . --import

Open tools/temple.blend to look at a part or change it by hand; export it again from
Blender (File, Export, glTF 2.0, to models/temple/temple.glb, +Y up, with nothing
selected-only) and the game uses what you made. Running this script again makes them all
afresh from the numbers below and overwrites the file.

What the game needs of a part:
  - its NAME (the object's name): scripts/temple_parts.gd asks for parts by name.
  - its ORIGIN: the middle of its foot, except where it says otherwise below.
  - its SIZE: the game measures each part and stretches it to the size the plan wants,
    so a part may be made any size, but its proportions are what will be seen. Parts
    that are a length (architrave, roof_slab, cornice, torus, screen_wall, the pylon's
    towers and gateway) are stretched one way more than another.
  - its MATERIALS, by name. The game draws all of them with one shader and reads what a
    face is from the name of its material (see MATERIALS below, and
    `TempleParts.READ` in scripts/temple_parts.gd).
The game works out for itself where on the stone a point is (so there are no UVs to
keep), and what is solid (from the part's size; see `TempleParts.SOLID`).

Everything is written in Godot's space: metres, Y up, a part faces +Z.
"""

import math
import os

import bmesh
import bpy

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUT = os.path.join(ROOT, "models", "temple")
TAU = math.tau

# The materials, and the colour each is shown in here (sRGB). What the game makes of a name:
#   stone ...            sandstone, smooth
#   ... _coursed         laid in courses of blocks
#   ... _relief          in courses, and carved with rows of figures
#   ... _shaded          in courses, and in shade (the underside of a beam, the back of a niche)
#   redgranite, greygranite, whitewash     other stuff than sandstone
#   dark                 the black of a window or a doorway
#   ... _painted_<red|blue|green|yellow|white|black|stripes>   painted, as much as the temple's "painted" says
BASES = {"stone": (0.70, 0.60, 0.46), "redgranite": (0.64, 0.44, 0.38), "greygranite": (0.38, 0.37, 0.36), "whitewash": (0.93, 0.91, 0.85), "dark": (0.03, 0.03, 0.03)}
PAINTS = {"red": (0.62, 0.24, 0.14), "blue": (0.16, 0.42, 0.56), "green": (0.26, 0.48, 0.36), "yellow": (0.82, 0.62, 0.22), "white": (0.9, 0.87, 0.78), "black": (0.12, 0.1, 0.09),
          "stripes": (0.45, 0.42, 0.4)}


def linear(c):
    return ((c + 0.055) / 1.055) ** 2.4 if c > 0.04045 else c / 12.92


def material_for(name):
    found = bpy.data.materials.get(name)
    if found:
        return found
    words = name.split("_")
    colour = BASES[words[0]]
    if "shaded" in words:
        colour = tuple(c * 0.55 for c in colour)
    if "relief" in words:
        colour = tuple(c * 0.94 for c in colour)
    if "painted" in words:
        paint = PAINTS[words[words.index("painted") + 1]]
        colour = tuple(c * 0.3 + p * 0.7 for c, p in zip(colour, paint))
    made = bpy.data.materials.new(name)
    made.use_nodes = True
    shader = made.node_tree.nodes["Principled BSDF"]
    shader.inputs["Base Color"].default_value = tuple(linear(c) for c in colour) + (1.0,)
    shader.inputs["Roughness"].default_value = 1.0
    made.diffuse_color = tuple(linear(c) for c in colour) + (1.0,)
    return made


def sub(a, b):
    return (a[0] - b[0], a[1] - b[1], a[2] - b[2])


def cross(a, b):
    return (a[1] * b[2] - a[2] * b[1], a[2] * b[0] - a[0] * b[2], a[0] * b[1] - a[1] * b[0])


def dot(a, b):
    return a[0] * b[0] + a[1] * b[1] + a[2] * b[2]


class Part:
    """One part: points and faces, in Godot's space. `sharp` is the angle (degrees) past
    which the edge between two faces is a hard one."""

    def __init__(self, name, sharp=40.0):
        self.name = name
        self.sharp = sharp
        self.verts = []
        self.faces = []
        self.shift = (0.0, 0.0, 0.0)

    def face(self, points, out, material):
        """A flat face, seen from the side `out` points to."""
        points = [(p[0] + self.shift[0], p[1] + self.shift[1], p[2] + self.shift[2]) for p in points]
        normal = (0.0, 0.0, 0.0)
        for i in range(1, len(points) - 1):
            n = cross(sub(points[i], points[0]), sub(points[i + 1], points[0]))
            normal = (normal[0] + n[0], normal[1] + n[1], normal[2] + n[2])
        if dot(normal, normal) < 1e-12:
            return
        if dot(normal, out) < 0.0:
            points = points[::-1]
        first = len(self.verts)
        self.verts += points
        self.faces.append((tuple(range(first, first + len(points))), material))

    def box(self, low, high, material, top=None, under=None, sides=None):
        """A box. `top` and `sides` are other materials for those; with `under` it has an underside."""
        x0, y0, z0 = low
        x1, y1, z1 = high
        m = sides or material
        self.face([(x1, y0, z0), (x1, y0, z1), (x1, y1, z1), (x1, y1, z0)], (1, 0, 0), m)
        self.face([(x0, y0, z0), (x0, y0, z1), (x0, y1, z1), (x0, y1, z0)], (-1, 0, 0), m)
        self.face([(x0, y0, z1), (x1, y0, z1), (x1, y1, z1), (x0, y1, z1)], (0, 0, 1), m)
        self.face([(x0, y0, z0), (x1, y0, z0), (x1, y1, z0), (x0, y1, z0)], (0, 0, -1), m)
        self.face([(x0, y1, z0), (x1, y1, z0), (x1, y1, z1), (x0, y1, z1)], (0, 1, 0), top or material)
        if under:
            self.face([(x0, y0, z0), (x1, y0, z0), (x1, y0, z1), (x0, y0, z1)], (0, -1, 0), under)

    def tapered(self, low, high, lean, material, top=None):
        """A box whose sides lean in: `lean` is how far in each is at the top (-X, +X, -Z, +Z)."""
        x0, y0, z0 = low
        x1, y1, z1 = high
        a, b, c, d = (x0, y0, z0), (x1, y0, z0), (x1, y0, z1), (x0, y0, z1)
        a1, b1, c1, d1 = (x0 + lean[0], y1, z0 + lean[2]), (x1 - lean[1], y1, z0 + lean[2]), (x1 - lean[1], y1, z1 - lean[3]), (x0 + lean[0], y1, z1 - lean[3])
        self.face([c, b, b1, c1], (1, 0.2, 0), material)
        self.face([a, d, d1, a1], (-1, 0.2, 0), material)
        self.face([d, c, c1, d1], (0, 0.2, 1), material)
        self.face([b, a, a1, b1], (0, 0.2, -1), material)
        self.face([a1, b1, c1, d1], (0, 1, 0), top or material)

    def lathe(self, at, profile, sides, squash=(1.0, 1.0), lobes=0, deep=0.0):
        """Turned on a lathe, standing at `at`: `profile` is (how far out, how high, material)
        from the foot up; the material is that of the stretch above. `squash` makes it wider
        one way than the other and `lobes` ribs it like a bundle of stems."""
        def point(k, r, y):
            angle = TAU * k / sides
            if lobes:
                r *= 1.0 - deep * (0.5 - 0.5 * math.cos(angle * lobes))
            return (at[0] + math.cos(angle) * r * squash[0], at[1] + y, at[2] + math.sin(angle) * r * squash[1])
        for i in range(len(profile) - 1):
            r0, y0, material = profile[i][:3]
            r1, y1 = profile[i + 1][:2]
            if abs(r0 - r1) < 1e-6 and abs(y0 - y1) < 1e-6:
                continue
            for k in range(sides):
                mid = TAU * (k + 0.5) / sides
                out = (math.cos(mid) * (y1 - y0), -(r1 - r0), math.sin(mid) * (y1 - y0))
                corners = [point(k, r0, y0), point(k + 1, r0, y0), point(k + 1, r1, y1), point(k, r1, y1)]
                if r0 < 1e-6:
                    corners = corners[1:]
                elif r1 < 1e-6:
                    corners = corners[:3]
                self.face(corners, out, material)

    def ellipsoid(self, centre, radii, material, sides=10, rings=6):
        profile = []
        for j in range(rings + 1):
            lat = -math.pi * 0.5 + math.pi * j / rings
            profile.append((math.cos(lat) if 0 < j < rings else 0.0, math.sin(lat) * radii[1], material))
        self.lathe(centre, [(r * radii[0], y, m) for r, y, m in profile], sides, (1.0, radii[2] / radii[0]))

    def cornice(self, x0, x1, z0, z1, y, height, back=0.0):
        """The cornice of every Egyptian wall, round the top of a rectangle: a roll, and over
        it a hollow curve that leans out to a flat band. With `back`, it is a wall that
        thick standing up from the edge, not a lid."""
        profile = [(0.0, 0.0), (0.07, 0.04), (0.07, 0.12), (0.0, 0.16), (0.03, 0.4), (0.14, 0.66), (0.32, 0.84), (0.34, 0.86), (0.34, 1.0)]
        for i in range(len(profile) - 1):
            o0, o1 = profile[i][0] * height, profile[i + 1][0] * height
            y0, y1 = y + profile[i][1] * height, y + profile[i + 1][1] * height
            material = "stone_painted_stripes" if 3 <= i < 6 else "stone"
            self.face([(x0 - o0, y0, z1 + o0), (x1 + o0, y0, z1 + o0), (x1 + o1, y1, z1 + o1), (x0 - o1, y1, z1 + o1)], (0, 0.3, 1), material)
            self.face([(x1 + o0, y0, z0 - o0), (x0 - o0, y0, z0 - o0), (x0 - o1, y1, z0 - o1), (x1 + o1, y1, z0 - o1)], (0, 0.3, -1), material)
            self.face([(x1 + o0, y0, z1 + o0), (x1 + o0, y0, z0 - o0), (x1 + o1, y1, z0 - o1), (x1 + o1, y1, z1 + o1)], (1, 0.3, 0), material)
            self.face([(x0 - o0, y0, z0 - o0), (x0 - o0, y0, z1 + o0), (x0 - o1, y1, z1 + o1), (x0 - o1, y1, z0 - o1)], (-1, 0.3, 0), material)
        over = 0.34 * height
        top = y + height
        self.face([(x0 - over, top, z0 - over), (x1 + over, top, z0 - over), (x1 + over, top, z1 + over), (x0 - over, top, z1 + over)], (0, 1, 0), "stone_coursed")

    def roll(self, a, b, radius, material="stone"):
        """A thin round bar from `a` to `b`: the roll up the corner of a wall."""
        along = sub(b, a)
        length = math.sqrt(dot(along, along))
        along = tuple(c / length for c in along)
        one = cross(along, (0, 1, 0) if abs(along[1]) < 0.9 else (1, 0, 0))
        size = math.sqrt(dot(one, one))
        one = tuple(c / size for c in one)
        two = cross(along, one)
        for k in range(6):
            f = [one[i] * math.cos(TAU * k / 6) + two[i] * math.sin(TAU * k / 6) for i in range(3)]
            t = [one[i] * math.cos(TAU * (k + 1) / 6) + two[i] * math.sin(TAU * (k + 1) / 6) for i in range(3)]
            out = tuple(f[i] + t[i] for i in range(3))
            self.face([tuple(a[i] + f[i] * radius for i in range(3)), tuple(a[i] + t[i] * radius for i in range(3)),
                       tuple(b[i] + t[i] * radius for i in range(3)), tuple(b[i] + f[i] * radius for i in range(3))], out, material)


# ---------------------------------------------------------------- columns
# Every column is 10 m high with a shaft 1 m in radius at the foot (2 m thick); the game
# stretches it to the height and thickness a plan wants. `_far` is the same seen from far off.

FOOT = 0.3


def thin(profile, far):
    """An outline with every other point left out, for a column seen from far off."""
    if not far:
        return profile
    return profile[:-1:2] + [profile[-1]]


def base(p, sides):
    p.lathe((0, 0, 0), [(1.3, 0.0, "stone"), (1.34, FOOT * 0.5, "stone"), (1.3, FOOT, "stone"), (0.9, FOOT, "stone")], sides)


def column_bud(p, far=False):
    """A bundle of eight papyrus stems, tied under the buds with five bands, the buds closed:
    the columns of the courts of Luxor."""
    base(p, 6 if far else 10)
    p.lathe((0, 0, 0), thin([(0.88, FOOT, "stone"), (1.0, 1.0, "stone"), (0.86, 7.0, "stone_painted_yellow"), (0.87, 7.55, "stone"), (0.92, 7.65, "stone_painted_green"),
                       (1.08, 8.2, "stone_painted_green"), (1.0, 8.9, "stone_painted_green"), (0.74, 9.55, "stone")], far), 6 if far else 16, lobes=0 if far else 8, deep=0.24)
    p.box((-0.84, 9.55, -0.84), (0.84, 10.0, 0.84), "stone", under="stone_shaded")


def column_open(p, far=False):
    """One great papyrus stem, drawn in at the foot, and the open flower, a bell: the
    fourteen columns of Luxor's colonnade."""
    sides = 6 if far else 12
    base(p, sides)
    p.lathe((0, 0, 0), thin([(0.9, FOOT, "stone"), (1.0, 0.9, "stone_relief"), (0.84, 7.4, "stone_painted_yellow"), (0.84, 7.9, "stone_painted_green"),
                       (0.98, 8.7, "stone_painted_green"), (1.32, 9.35, "stone_painted_blue"), (1.72, 9.72, "stone_painted_yellow"), (1.72, 9.8, "stone"), (0.7, 9.8, "stone")], far), sides)
    p.box((-0.72, 9.8, -0.72), (0.72, 10.0, 0.72), "stone", under="stone_shaded")


def column_composite(p, far=False):
    """A carved shaft and a bell of leaves and flowers in tiers, with a tall block over
    it: the columns of the Ptolemies, at Edfu and Kom Ombo."""
    sides = 6 if far else 12
    base(p, sides)
    p.lathe((0, 0, 0), [(0.9, FOOT, "stone"), (1.0, 0.8, "stone_relief"), (0.9, 7.1, "stone_painted_yellow"), (0.9, 7.55, "stone")], sides)
    p.lathe((0, 0, 0), thin([(0.92, 7.55, "stone_painted_green"), (1.14, 8.1, "stone_painted_blue"), (1.26, 8.5, "stone_painted_green"), (1.5, 8.95, "stone_painted_red"),
                       (1.68, 9.25, "stone_painted_yellow"), (1.7, 9.4, "stone"), (0.6, 9.4, "stone")], far), 6 if far else 16, lobes=0 if far else 8, deep=0.2)
    p.box((-0.64, 9.4, -0.64), (0.64, 10.0, 0.64), "stone")


def column_hathor(p, far=False):
    """Hathor's face on all four sides, between the falls of her wig, with her cow's
    ears, and the shrine she carries on her head."""
    sides = 6 if far else 12
    base(p, sides)
    p.lathe((0, 0, 0), [(0.9, FOOT, "stone"), (1.0, 0.8, "stone_relief"), (0.92, 6.6, "stone")], sides)
    wide = 1.2
    p.box((-wide, 6.6, -wide), (wide, 8.8, wide), "stone_painted_blue", under="stone_shaded")
    p.box((-0.9, 8.8, -0.9), (0.9, 10.0, 0.9), "stone_painted_stripes")
    if far:
        return
    for turn in range(4):
        c, s = math.cos(turn * TAU / 4), math.sin(turn * TAU / 4)
        def place(x, y, z):
            return (x * c + z * s, y, -x * s + z * c)
        # Her face: broad at the brow, narrow at the chin, standing out from the wig.
        out = wide + 0.18
        face = [place(-0.52, 7.0, out), place(0.52, 7.0, out), place(0.66, 8.5, out), place(-0.66, 8.5, out)]
        p.face(face, place(0, 0, 1), "stone_painted_yellow")
        p.face([place(-0.52, 7.0, wide), place(-0.52, 7.0, out), place(-0.66, 8.5, out), place(-0.66, 8.5, wide)], place(-1, 0, 0), "stone_painted_yellow")
        p.face([place(0.52, 7.0, wide), place(0.52, 7.0, out), place(0.66, 8.5, out), place(0.66, 8.5, wide)], place(1, 0, 0), "stone_painted_yellow")
        p.face([place(-0.52, 7.0, wide), place(0.52, 7.0, wide), place(0.52, 7.0, out), place(-0.52, 7.0, out)], (0, -1, 0), "stone_painted_yellow")
        for side in (-1.0, 1.0):
            p.face([place(side * 0.66, 7.9, out - 0.04), place(side * 0.98, 8.05, out - 0.04), place(side * 0.66, 8.3, out - 0.04)], place(0, 0, 1), "stone_painted_red")


def column_broken(p):
    """What is left of a snapped column: a plain shaft 1 m in radius and 1 m high, broken
    off aslant. The game stretches it to how thick the column was and how much is left."""
    sides = 10
    for k in range(sides):
        a0, a1 = TAU * k / sides, TAU * (k + 1) / sides
        t0, t1 = 0.86 + 0.14 * math.cos(a0 + 0.7), 0.86 + 0.14 * math.cos(a1 + 0.7)
        p0, p1 = (math.cos(a0), 0.0, math.sin(a0)), (math.cos(a1), 0.0, math.sin(a1))
        q0, q1 = (p0[0], t0, p0[2]), (p1[0], t1, p1[2])
        p.face([p0, p1, q1, q0], (math.cos((a0 + a1) / 2), 0, math.sin((a0 + a1) / 2)), "stone")
        p.face([q0, q1, (0.0, 0.8, 0.0)], (0, 1, 0), "stone_shaded")


def column_drum(p):
    """One drum of a fallen column, 1 m in radius and 1 m long, standing on end with its
    middle at the origin. The game lays it on its side."""
    p.lathe((0, -0.5, 0), [(0.0, 0.0, "stone_shaded"), (0.96, 0.0, "stone"), (1.0, 0.06, "stone"), (1.0, 0.94, "stone"), (0.96, 1.0, "stone_shaded"), (0.0, 1.0, "stone")], 10)


# ---------------------------------------------------------------- lengths

def architrave(p):
    """The beam that lies from column to column: 1 m each way, along X, its middle over
    the origin and its underside on it. Stretched to the length, height and width wanted."""
    p.box((-0.5, 0.0, -0.5), (0.5, 1.0, 0.5), "stone_coursed", under="stone_shaded")


def roof_slab(p):
    """A slab of the roof: 1 m each way, as the architrave is."""
    p.box((-0.5, 0.0, -0.5), (0.5, 1.0, 0.5), "stone_coursed", under="stone_shaded", sides="stone_shaded")


def cornice(p):
    """A length of cornice, 1 m long along X and 1 m high, leaning out towards +Z from a
    wall whose face is at Z = 0; behind it is 0.4 m of wall to stand it on."""
    profile = [(0.0, 0.0), (0.07, 0.04), (0.07, 0.12), (0.0, 0.16), (0.03, 0.4), (0.14, 0.66), (0.32, 0.84), (0.34, 0.86), (0.34, 1.0)]
    for i in range(len(profile) - 1):
        (o0, y0), (o1, y1) = profile[i], profile[i + 1]
        p.face([(-0.5, y0, o0), (0.5, y0, o0), (0.5, y1, o1), (-0.5, y1, o1)], (0, 0.3, 1), "stone_painted_stripes" if 3 <= i < 6 else "stone")
    p.face([(-0.5, 1.0, -0.4), (0.5, 1.0, -0.4), (0.5, 1.0, 0.34), (-0.5, 1.0, 0.34)], (0, 1, 0), "stone_coursed")
    p.face([(-0.5, 0.0, -0.4), (0.5, 0.0, -0.4), (0.5, 1.0, -0.4), (-0.5, 1.0, -0.4)], (0, 0, -1), "stone_coursed")


def cornice_corner(p):
    """Where two lengths of cornice meet at the corner of a wall: the corner of the wall is
    at the origin, and the walls run off towards -X and -Z."""
    profile = [(0.0, 0.0), (0.07, 0.04), (0.07, 0.12), (0.0, 0.16), (0.03, 0.4), (0.14, 0.66), (0.32, 0.84), (0.34, 0.86), (0.34, 1.0)]
    for i in range(len(profile) - 1):
        (o0, y0), (o1, y1) = profile[i], profile[i + 1]
        material = "stone_painted_stripes" if 3 <= i < 6 else "stone"
        p.face([(0.0, y0, o0), (o0, y0, o0), (o1, y1, o1), (0.0, y1, o1)], (0, 0.3, 1), material)
        p.face([(o0, y0, 0.0), (o0, y0, o0), (o1, y1, o1), (o1, y1, 0.0)], (1, 0.3, 0), material)
    p.face([(-0.4, 1.0, -0.4), (0.34, 1.0, -0.4), (0.34, 1.0, 0.34), (-0.4, 1.0, 0.34)], (0, 1, 0), "stone_coursed")


def torus(p):
    """A length of the roll that runs up the corners of a wall: 1 m long, standing up from the origin, 1 m in radius."""
    p.lathe((0, 0, 0), [(1.0, 0.0, "stone"), (1.0, 1.0, "stone")], 6)


def screen_wall(p):
    """One of the half-height walls that stand between the columns of a Ptolemaic
    facade: 4 m long along X and 5.5 m high, carved, with its roll and cornice. It faces +Z."""
    p.box((-2.0, 0.0, -0.35), (2.0, 4.9, 0.35), "stone_relief", top="stone")
    for z in (0.35, -0.35):
        p.roll((-2.0, 4.9, z), (2.0, 4.9, z), 0.07)
    profile = [(0.0, 4.95), (0.03, 5.1), (0.1, 5.3), (0.2, 5.42), (0.22, 5.5)]
    for i in range(len(profile) - 1):
        (o0, y0), (o1, y1) = profile[i], profile[i + 1]
        material = "stone_painted_stripes" if i < 3 else "stone"
        p.face([(-2.0, y0, 0.35 + o0), (2.0, y0, 0.35 + o0), (2.0, y1, 0.35 + o1), (-2.0, y1, 0.35 + o1)], (0, 0.3, 1), material)
        p.face([(-2.0, y0, -0.35 - o0), (2.0, y0, -0.35 - o0), (2.0, y1, -0.35 - o1), (-2.0, y1, -0.35 - o1)], (0, 0.3, -1), material)
    p.face([(-2.0, 5.5, -0.57), (2.0, 5.5, -0.57), (2.0, 5.5, 0.57), (-2.0, 5.5, 0.57)], (0, 1, 0), "stone")
    # (a row of cobras along the top, as a low band)
    p.box((-2.0, 5.5, -0.2), (2.0, 5.8, 0.2), "stone_painted_yellow")


# ---------------------------------------------------------------- the pylon
# One tower as Edfu's is: 34 m wide at the foot, 36 m to the foot of its cornice, 11 m
# through. Its inner edge (the gate's side) is at X = 0 and its front at Z = 0; `pylon_tower`
# stands on the right of the gate as he comes to it (+X), `pylon_tower_left` on the left.
# The great figures of the king are not part of it: the game cuts them into its face.

TOWER = (34.0, 36.0, 11.0)
LEAN = (1.0, 3.0, 3.0)  # how far its inner side, its outer side, and its front and back lean in at the top
NICHES = (0.30, 0.74)   # where the slots for its flagstaffs are, across it


def tower(p, side):
    wide, high, deep = TOWER
    lean_in, lean_out, lean_z = LEAN

    def at(x, y, front=True, into=0.0):
        """A point on its front (or back) face: `x` from the inner edge at the foot, `y` up; `into` sets it back into the stone."""
        z = -lean_z * y / high - into if front else -deep + lean_z * y / high + into
        return (side * x, y, z)

    def edge(y):
        return lean_in * y / high, wide - lean_out * y / high

    slot = 0.85
    columns = [None, NICHES[0] * wide - slot, NICHES[0] * wide + slot, NICHES[1] * wide - slot, NICHES[1] * wide + slot, None]
    rows = [0.0, high * 0.52, high * 0.62, high * 0.72, high * 0.77, high]
    for front in (True, False):
        out = (0, 0.1, 1) if front else (0, 0.1, -1)
        for j in range(len(rows) - 1):
            y0, y1 = rows[j], rows[j + 1]
            material = "stone_coursed" if j == 0 else "stone_relief"
            for i in range(len(columns) - 1):
                x00 = columns[i] if columns[i] is not None else edge(y0)[0]
                x01 = columns[i] if columns[i] is not None else edge(y1)[0]
                x10 = columns[i + 1] if columns[i + 1] is not None else edge(y0)[1]
                x11 = columns[i + 1] if columns[i + 1] is not None else edge(y1)[1]
                niche = front and i in (1, 3) and j < 2
                window = front and i in (1, 3) and j == 3
                if niche or window:
                    # Cut back into the face: its back, its two sides, and (a window) its sill and head.
                    back = 1.1 if niche else 0.9
                    inner = "stone_shaded" if niche else "dark"
                    p.face([at(x00, y0, front, back), at(x10, y0, front, back), at(x11, y1, front, back), at(x01, y1, front, back)], out, inner)
                    p.face([at(x00, y0, front), at(x00, y0, front, back), at(x01, y1, front, back), at(x01, y1, front)], (side, 0, 0), "stone_shaded")
                    p.face([at(x10, y0, front), at(x10, y0, front, back), at(x11, y1, front, back), at(x11, y1, front)], (-side, 0, 0), "stone_shaded")
                    if window or j == 1:
                        p.face([at(x01, y1, front), at(x11, y1, front), at(x11, y1, front, back), at(x01, y1, front, back)], (0, -1, 0), "stone_shaded")
                    if window:
                        p.face([at(x00, y0, front), at(x10, y0, front), at(x10, y0, front, back), at(x00, y0, front, back)], (0, 1, 0), "stone_shaded")
                    continue
                p.face([at(x00, y0, front), at(x10, y0, front), at(x11, y1, front), at(x01, y1, front)], out, material)
    # Its two ends.
    for x_foot, x_top, way in ((0.0, lean_in, -1.0), (wide, wide - lean_out, 1.0)):
        p.face([(side * x_foot, 0.0, 0.0), (side * x_foot, 0.0, -deep), (side * x_top, high, -deep + lean_z), (side * x_top, high, -lean_z)], (side * way, 0.1, 0), "stone_coursed")
    # The rolls up its four corners, and its cornice.
    for x_foot, x_top in ((0.0, lean_in), (wide, wide - lean_out)):
        p.roll((side * x_foot, 0.0, 0.0), (side * x_top, high, -lean_z), 0.22)
        p.roll((side * x_foot, 0.0, -deep), (side * x_top, high, -deep + lean_z), 0.22)
    x0, x1 = sorted((side * lean_in, side * (wide - lean_out)))
    p.cornice(x0, x1, -deep + lean_z, -lean_z, high, 1.9)


def pylon_tower(p):
    tower(p, 1.0)


def pylon_tower_left(p):
    tower(p, -1.0)


def tower_ruin(p, side):
    """A tower that is down to its lowest courses: the same foot, 36 m high where it is
    highest (the game makes it as high as what is left), broken off in steps."""
    wide, high, deep = TOWER
    steps = [1.0, 0.72, 0.86, 0.55, 0.78, 0.6]
    for i, share in enumerate(steps):
        x0 = wide * i / len(steps)
        x1 = wide * (i + 1) / len(steps)
        low, top = sorted((side * x0, side * x1))
        lean = [0.0, 0.0, 0.5, 0.5]
        if i == len(steps) - 1:
            lean[1 if side > 0 else 0] = 0.6
        p.tapered((low, 0.0, -deep), (top, high * share, 0.0), lean, "stone_coursed")


def pylon_tower_ruin(p):
    tower_ruin(p, 1.0)


def pylon_tower_ruin_left(p):
    tower_ruin(p, -1.0)


# The gateway between the towers, as Edfu's is: an opening 5.6 m wide and 15.4 m high in a
# block 9 m wide and 11 m through, 22 m high with its cornice. Its front is at Z = 0.
GATE = (5.6, 15.4, 9.0, 22.0, 11.0)


def pylon_gateway(p):
    """The gate of a pylon: two jambs, the lintel with the sun's winged disc on it, and the cornice."""
    open_w, open_h, wide, high, deep = GATE
    crown = 2.2
    top = high - crown
    for side in (-1.0, 1.0):
        x0, x1 = sorted((side * open_w * 0.5, side * wide * 0.5))
        p.box((x0, 0.0, -deep), (x1, top, 0.0), "stone_relief", top="stone_coursed")
        p.roll((side * wide * 0.5, 0.0, 0.0), (side * wide * 0.5, top, 0.0), 0.16)
        p.roll((side * wide * 0.5, 0.0, -deep), (side * wide * 0.5, top, -deep), 0.16)
    p.box((-open_w * 0.5, open_h, -deep), (open_w * 0.5, top, 0.0), "stone_coursed", under="stone_shaded")
    p.cornice(-wide * 0.5, wide * 0.5, -deep, 0.0, top, crown)
    # The winged disc: the sun, a cobra hanging either side of it, and two wings of three rows of feathers.
    y = (open_h + top) * 0.5
    z = 0.06
    ring = [(math.cos(TAU * k / 14) * 0.95, y + math.sin(TAU * k / 14) * 0.95) for k in range(14)]
    p.face([(x, up, 0.14) for x, up in ring], (0, 0, 1), "stone_painted_red")
    for k in range(14):
        a, b = ring[k], ring[(k + 1) % 14]
        p.face([(a[0], a[1], 0.0), (b[0], b[1], 0.0), (b[0], b[1], 0.14), (a[0], a[1], 0.14)], (a[0] + b[0], a[1] + b[1] - 2.0 * y, 0), "stone_painted_red")
    wing = [((0.9, 0.55), (3.9, 0.75), (3.9, 0.3), (0.9, 0.1), "stone_painted_green"), ((0.9, 0.1), (3.6, 0.3), (3.4, -0.15), (0.9, -0.3), "stone_painted_blue"),
            ((0.9, -0.3), (3.0, -0.15), (2.6, -0.55), (0.9, -0.62), "stone_painted_red")]
    for side in (-1.0, 1.0):
        for a, b, c, d, material in wing:
            corners = [(side * q[0], y + q[1], z + 0.05) for q in (a, b, c, d)]
            p.face(corners, (0, 0, 1), material)
            p.face([(side * a[0], y + a[1], 0.0), (side * b[0], y + b[1], 0.0), corners[1], corners[0]], (0, 1, 0), "stone")
            p.face([(side * d[0], y + d[1], 0.0), (side * c[0], y + c[1], 0.0), corners[2], corners[3]], (0, -1, 0), "stone_shaded")
            p.face([(side * b[0], y + b[1], 0.0), (side * c[0], y + c[1], 0.0), corners[2], corners[1]], (side, 0, 0), "stone")
        p.box((side * 1.0 - 0.14, y - 1.0, 0.0), (side * 1.0 + 0.14, y - 0.3, 0.1), "stone_painted_yellow")


# ---------------------------------------------------------------- statues and furniture

def king_head(p, at, h, stone, crowned=True):
    """A king's head in the striped headcloth, with the double crown over it; his chin is at `at`."""
    x, y, z = at
    p.ellipsoid((x, y + 0.062 * h, z + 0.012 * h), (0.05 * h, 0.066 * h, 0.056 * h), stone, 10, 6)
    cloth = stone + "_painted_yellow"
    # The headcloth: wide at the shoulders, and its two falls on the chest.
    p.tapered((x - 0.118 * h, y - 0.02 * h, z - 0.075 * h), (x + 0.118 * h, y + 0.135 * h, z), (0.05 * h, 0.05 * h, 0.012 * h, 0.0), cloth)
    for side in (-1.0, 1.0):
        p.box((x + side * 0.075 * h - 0.028 * h, y - 0.1 * h, z - 0.005 * h), (x + side * 0.075 * h + 0.028 * h, y, z + 0.03 * h), cloth)
        # (his ears)
        p.box((x + side * 0.052 * h - 0.008 * h, y + 0.05 * h, z - 0.005 * h), (x + side * 0.052 * h + 0.008 * h, y + 0.085 * h, z + 0.015 * h), stone)
    # His nose, and his beard.
    p.tapered((x - 0.009 * h, y + 0.045 * h, z + 0.06 * h), (x + 0.009 * h, y + 0.08 * h, z + 0.078 * h), (0.003 * h, 0.003 * h, 0.0, 0.012 * h), stone)
    p.tapered((x - 0.014 * h, y - 0.05 * h, z + 0.03 * h), (x + 0.014 * h, y + 0.005 * h, z + 0.055 * h), (0.003 * h, 0.003 * h, 0.0, 0.0), stone)
    if crowned:
        # The red crown of the north, and inside it the white crown of the south.
        p.lathe((x, y + 0.125 * h, z - 0.012 * h), [(0.058 * h, 0.0, stone + "_painted_red"), (0.074 * h, 0.07 * h, stone + "_painted_red"), (0.05 * h, 0.07 * h, stone + "_painted_white"),
                                                   (0.053 * h, 0.12 * h, stone + "_painted_white"), (0.032 * h, 0.17 * h, stone + "_painted_white"), (0.0, 0.19 * h, stone)], 10)
        p.box((x - 0.012 * h, y + 0.19 * h, z - 0.085 * h), (x + 0.012 * h, y + 0.29 * h, z - 0.06 * h), stone + "_painted_red")


def colossus_seated(p):
    """A king seated on his throne, hands on his knees: 14 m high with his crown, as the
    two of Ramesses II before the pylon of Luxor."""
    h = 14.0
    stone = "greygranite"
    p.box((-0.2 * h, 0.0, -0.3 * h), (0.2 * h, 0.08 * h, 0.34 * h), stone)
    p.box((-0.17 * h, 0.08 * h, -0.27 * h), (0.17 * h, 0.36 * h, 0.02 * h), stone + "_relief", top=stone)
    p.box((-0.17 * h, 0.36 * h, -0.27 * h), (0.17 * h, 0.52 * h, -0.2 * h), stone)
    for side in (-1.0, 1.0):
        # His shins, feet, arms and hands.
        p.tapered((side * 0.085 * h - 0.055 * h, 0.08 * h, 0.07 * h), (side * 0.085 * h + 0.055 * h, 0.4 * h, 0.21 * h), (0.006 * h, 0.006 * h, 0.0, 0.012 * h), stone)
        p.box((side * 0.085 * h - 0.045 * h, 0.08 * h, 0.2 * h), (side * 0.085 * h + 0.045 * h, 0.12 * h, 0.31 * h), stone)
        p.ellipsoid((side * 0.19 * h, 0.685 * h, -0.115 * h), (0.05 * h, 0.045 * h, 0.07 * h), stone, 8, 4)
        p.tapered((side * 0.19 * h - 0.04 * h, 0.44 * h, -0.17 * h), (side * 0.19 * h + 0.04 * h, 0.69 * h, -0.05 * h), (0.004 * h, 0.004 * h, 0.0, 0.01 * h), stone)
        p.box((side * 0.15 * h - 0.04 * h, 0.435 * h, -0.08 * h), (side * 0.15 * h + 0.04 * h, 0.49 * h, 0.17 * h), stone)
    p.box((-0.15 * h, 0.34 * h, -0.08 * h), (0.15 * h, 0.44 * h, 0.21 * h), stone + "_painted_white")
    # His body, narrowing to the waist; his chest; his neck and head.
    p.tapered((-0.13 * h, 0.44 * h, -0.2 * h), (0.13 * h, 0.7 * h, -0.03 * h), (-0.035 * h, -0.035 * h, 0.0, 0.012 * h), stone)
    p.ellipsoid((0.0, 0.63 * h, -0.07 * h), (0.14 * h, 0.07 * h, 0.06 * h), stone, 8, 4)
    king_head(p, (0.0, 0.71 * h, -0.11 * h), h, stone)


def colossus_standing(p):
    """A king standing, one foot forward, against the pillar at his back: 11 m high."""
    h = 11.0
    stone = "redgranite"
    p.box((-0.15 * h, 0.0, -0.17 * h), (0.15 * h, 0.05 * h, 0.2 * h), stone)
    p.box((-0.08 * h, 0.05 * h, -0.15 * h), (0.08 * h, 0.8 * h, -0.07 * h), stone + "_relief", top=stone)
    p.tapered((-0.1 * h, 0.05 * h, -0.07 * h), (-0.01 * h, 0.42 * h, 0.03 * h), (0.0, 0.0, 0.0, 0.0), stone)
    p.tapered((0.01 * h, 0.05 * h, 0.0), (0.1 * h, 0.42 * h, 0.12 * h), (0.0, 0.0, 0.07 * h, 0.05 * h), stone)
    p.box((-0.1 * h, 0.05 * h, -0.07 * h), (-0.01 * h, 0.075 * h, 0.08 * h), stone)
    p.box((0.01 * h, 0.05 * h, 0.0), (0.1 * h, 0.075 * h, 0.17 * h), stone)
    p.tapered((-0.11 * h, 0.36 * h, -0.08 * h), (0.11 * h, 0.5 * h, 0.09 * h), (0.01 * h, 0.01 * h, 0.0, 0.04 * h), stone + "_painted_white")
    p.tapered((-0.1 * h, 0.5 * h, -0.08 * h), (0.1 * h, 0.74 * h, 0.05 * h), (-0.04 * h, -0.04 * h, 0.0, 0.0), stone)
    p.ellipsoid((0.0, 0.68 * h, 0.02 * h), (0.13 * h, 0.06 * h, 0.05 * h), stone, 8, 4)
    for side in (-1.0, 1.0):
        p.ellipsoid((side * 0.165 * h, 0.715 * h, -0.015 * h), (0.04 * h, 0.04 * h, 0.05 * h), stone, 8, 4)
        p.box((side * 0.165 * h - 0.032 * h, 0.4 * h, -0.06 * h), (side * 0.165 * h + 0.032 * h, 0.72 * h, 0.03 * h), stone)
    king_head(p, (0.0, 0.745 * h, -0.02 * h), h, stone)


def falcon(p):
    """Horus as a falcon, wearing the double crown, as he stands in grey granite at the
    gate of Edfu: 3.4 m high with it."""
    h = 3.4
    stone = "greygranite"
    p.box((-0.17 * h, 0.0, -0.27 * h), (0.17 * h, 0.07 * h, 0.2 * h), stone)
    # His body: upright, deep in the chest; his folded wings, crossing over the tail that runs down behind to the ground.
    p.ellipsoid((0.0, 0.37 * h, 0.0), (0.145 * h, 0.27 * h, 0.17 * h), stone, 10, 6)
    for side in (-1.0, 1.0):
        x0, x1 = sorted((side * 0.03 * h, side * 0.155 * h))
        p.tapered((x0, 0.12 * h, -0.2 * h), (x1, 0.58 * h, 0.03 * h), (0.02 * h, 0.02 * h, 0.1 * h, 0.05 * h), stone)
    p.tapered((-0.075 * h, 0.07 * h, -0.26 * h), (0.075 * h, 0.4 * h, -0.1 * h), (0.02 * h, 0.02 * h, 0.1 * h, 0.0), stone)
    # His head: flat on top, with the hooked beak, and the dark mark under each eye.
    p.ellipsoid((0.0, 0.68 * h, 0.03 * h), (0.105 * h, 0.09 * h, 0.125 * h), stone, 10, 6)
    p.tapered((-0.03 * h, 0.645 * h, 0.11 * h), (0.03 * h, 0.71 * h, 0.185 * h), (0.018 * h, 0.018 * h, 0.0, 0.05 * h), stone)
    p.tapered((-0.012 * h, 0.6 * h, 0.15 * h), (0.012 * h, 0.66 * h, 0.185 * h), (0.006 * h, 0.006 * h, 0.01 * h, 0.01 * h), stone)
    for side in (-1.0, 1.0):
        p.ellipsoid((side * 0.075 * h, 0.7 * h, 0.085 * h), (0.02 * h, 0.022 * h, 0.022 * h), stone + "_painted_black", 6, 4)
        # His legs, feathered to the foot, and his feet.
        p.tapered((side * 0.07 * h - 0.045 * h, 0.07 * h, 0.03 * h), (side * 0.07 * h + 0.045 * h, 0.26 * h, 0.15 * h), (0.005 * h, 0.005 * h, 0.0, 0.03 * h), stone)
        p.box((side * 0.07 * h - 0.04 * h, 0.07 * h, 0.12 * h), (side * 0.07 * h + 0.04 * h, 0.1 * h, 0.19 * h), stone)
    p.lathe((0.0, 0.755 * h, 0.0), [(0.075 * h, 0.0, stone + "_painted_red"), (0.097 * h, 0.09 * h, stone + "_painted_red"), (0.06 * h, 0.09 * h, stone + "_painted_white"),
                                   (0.066 * h, 0.15 * h, stone + "_painted_white"), (0.036 * h, 0.22 * h, stone + "_painted_white"), (0.0, 0.245 * h, stone)], 10)
    p.box((-0.012 * h, 0.83 * h, -0.105 * h), (0.012 * h, 0.97 * h, -0.078 * h), stone + "_painted_red")


def naos(p):
    """The naos: the shrine of one block of polished granite in which the god's image
    stood, as Nectanebo's stands in the sanctuary of Edfu: 4.2 m to the point of its roof."""
    h = 4.2
    wide = 0.24 * h
    stone = "greygranite"
    p.box((-wide * 1.15, 0.0, -wide * 1.15), (wide * 1.15, 0.06 * h, wide * 1.15), stone)
    # Its body, with the niche cut into the front.
    y0, y1, y2, y3 = 0.06 * h, 0.16 * h, 0.66 * h, 0.78 * h
    nx = wide * 0.62
    back = wide * 0.1
    for x0, x1, low, high in ((-wide, -nx, y0, y3), (nx, wide, y0, y3), (-nx, nx, y0, y1), (-nx, nx, y2, y3)):
        p.face([(x0, low, wide), (x1, low, wide), (x1, high, wide), (x0, high, wide)], (0, 0, 1), stone)
    p.face([(-nx, y1, back), (nx, y1, back), (nx, y2, back), (-nx, y2, back)], (0, 0, 1), "dark")
    p.face([(-nx, y1, back), (-nx, y1, wide), (-nx, y2, wide), (-nx, y2, back)], (1, 0, 0), stone + "_shaded")
    p.face([(nx, y1, back), (nx, y1, wide), (nx, y2, wide), (nx, y2, back)], (-1, 0, 0), stone + "_shaded")
    p.face([(-nx, y1, back), (nx, y1, back), (nx, y1, wide), (-nx, y1, wide)], (0, 1, 0), stone + "_shaded")
    p.face([(-nx, y2, back), (nx, y2, back), (nx, y2, wide), (-nx, y2, wide)], (0, -1, 0), stone + "_shaded")
    p.face([(wide, y0, -wide), (wide, y0, wide), (wide, y3, wide), (wide, y3, -wide)], (1, 0, 0), stone)
    p.face([(-wide, y0, -wide), (-wide, y0, wide), (-wide, y3, wide), (-wide, y3, -wide)], (-1, 0, 0), stone)
    p.face([(-wide, y0, -wide), (wide, y0, -wide), (wide, y3, -wide), (-wide, y3, -wide)], (0, 0, -1), stone)
    # Its roof, a low pyramid, over a roll and a little cornice.
    p.box((-wide * 1.06, y3, -wide * 1.06), (wide * 1.06, y3 + 0.03 * h, wide * 1.06), stone)
    p.tapered((-wide * 1.06, y3 + 0.03 * h, -wide * 1.06), (wide * 1.06, h, wide * 1.06), (wide, wide, wide, wide), stone)
    p.box((-nx - 0.02 * h, y2, wide), (nx + 0.02 * h, y2 + 0.035 * h, wide + 0.02 * h), stone)


def barque_stand(p):
    """The stand the god's boat rested on: a carved block with a cornice, 1.6 m by 2.2 m and 1.1 m high."""
    p.box((-0.8, 0.0, -1.1), (0.8, 0.8, 1.1), "stone_relief")
    p.cornice(-0.8, 0.8, -1.1, 1.1, 0.8, 0.3)


def altar(p):
    """An altar of dark granite, as stands in the court of Kom Ombo: 3.2 m square and 1.3 m high."""
    p.box((-1.6, 0.0, -1.6), (1.6, 1.1, 1.6), "greygranite")
    p.box((-1.7, 1.1, -1.7), (1.7, 1.3, 1.7), "greygranite")


def well(p):
    """A round well with a kerb: the nilometer, by which the river's rise was read. 1.3 m
    in radius inside, the kerb 0.5 m thick and 0.9 m high, with water a little way down."""
    p.lathe((0, 0, 0), [(1.8, 0.0, "stone_coursed"), (1.8, 0.9, "stone"), (1.3, 0.9, "stone_shaded"), (1.3, 0.4, "greygranite_painted_blue"), (0.0, 0.4, "stone")], 14)


def obelisk(p):
    """An obelisk of red granite on its pedestal, 25 m high, as the one left before Luxor."""
    h = 25.0
    stone = "redgranite"
    obelisk_pedestal(p)
    lean = 0.016 * h
    p.tapered((-0.048 * h, 0.07 * h, -0.048 * h), (0.048 * h, 0.93 * h, 0.048 * h), (lean, lean, lean, lean), stone)
    top = 0.048 * h - lean
    p.tapered((-top, 0.93 * h, -top), (top, h, top), (top, top, top, top), stone + "_painted_yellow")


def obelisk_pedestal(p):
    """The pedestal of an obelisk, by itself: what is left where the one that went to Paris stood."""
    h = 25.0
    p.box((-0.075 * h, 0.0, -0.075 * h), (0.075 * h, 0.07 * h, 0.075 * h), "redgranite")


def mosque(p):
    """The mosque of Abu el-Haggag, as plainly as can be: a whitewashed hall 12 m by 16 m
    and 5.2 m high with a dome. Its door and windows are in the side towards +X."""
    p.box((-6.0, 0.0, -8.0), (6.0, 5.2, 8.0), "whitewash")
    # A low wall round the roof, a door and four windows.
    for x0, x1, z0, z1 in ((-6.0, 6.0, -8.0, -7.6), (-6.0, 6.0, 7.6, 8.0), (-6.0, -5.6, -7.6, 7.6), (5.6, 6.0, -7.6, 7.6)):
        p.box((x0, 5.2, z0), (x1, 5.8, z1), "whitewash")
    x = 6.02
    p.face([(x, 0.0, -0.8), (x, 0.0, 0.8), (x, 2.8, 0.8), (x, 2.8, -0.8)], (1, 0, 0), "dark")
    for z in (-5.6, -3.2, 3.2, 5.6):
        p.face([(x, 2.3, z - 0.45), (x, 2.3, z + 0.45), (x, 3.9, z + 0.45), (x, 3.9, z - 0.45)], (1, 0, 0), "dark")
    p.lathe((0.0, 5.2, 0.0), [(3.1, 0.0, "whitewash"), (3.1, 1.0, "whitewash"), (2.7, 2.3, "whitewash"), (1.6, 3.5, "whitewash"), (0.25, 4.0, "whitewash"), (0.0, 4.8, "whitewash")], 12)


def minaret(p):
    """Its minaret: a round tower 15 m high, with a gallery near the top and a little dome."""
    r, t = 1.25, 15.0
    p.lathe((0, 0, 0), [(r * 1.25, 0.0, "whitewash"), (r * 1.25, t * 0.2, "whitewash"), (r, t * 0.22, "whitewash"), (r * 0.8, t * 0.7, "whitewash"), (r * 1.15, t * 0.72, "whitewash"),
                       (r * 1.15, t * 0.76, "whitewash"), (r * 0.66, t * 0.76, "whitewash"), (r * 0.6, t * 0.92, "whitewash"), (r * 0.66, t * 0.94, "whitewash"), (r * 0.4, t * 0.99, "whitewash"),
                       (0.0, t, "whitewash")], 10)
    for k in range(4):
        a = TAU * k / 4 + 0.4
        c, s = math.cos(a), math.sin(a)
        rr = r * 0.74
        p.face([(c * rr - s * 0.25, t * 0.8, s * rr + c * 0.25), (c * rr + s * 0.25, t * 0.8, s * rr - c * 0.25), (c * rr + s * 0.25, t * 0.88, s * rr - c * 0.25), (c * rr - s * 0.25, t * 0.88, s * rr + c * 0.25)], (c, 0, s), "dark")


# ---------------------------------------------------------------- making them

PARTS = [column_bud, column_open, column_composite, column_hathor, column_broken, column_drum, architrave, roof_slab, cornice, cornice_corner, torus, screen_wall,
         pylon_tower, pylon_tower_left, pylon_tower_ruin, pylon_tower_ruin_left, pylon_gateway, naos, barque_stand, altar, well, obelisk, obelisk_pedestal,
         colossus_seated, colossus_standing, falcon, mosque, minaret]
FAR = [column_bud, column_open, column_composite, column_hathor]


def build(make, name, along, far=False):
    p = Part(name, 75.0 if far else 40.0)
    if far:
        make(p, True)
    else:
        make(p)
    mesh = bpy.data.meshes.new(name)
    made = bmesh.new()
    points = [made.verts.new((v[0], -v[2], v[1])) for v in p.verts]
    slots = []
    for indices, material in p.faces:
        try:
            face = made.faces.new([points[i] for i in indices])
        except ValueError:
            continue
        if material not in slots:
            slots.append(material)
        face.material_index = slots.index(material)
        face.smooth = True
    bmesh.ops.remove_doubles(made, verts=made.verts, dist=0.0005)
    limit = math.radians(p.sharp)
    for edge in made.edges:
        if len(edge.link_faces) != 2 or edge.calc_face_angle(0.0) > limit or edge.link_faces[0].material_index != edge.link_faces[1].material_index:
            edge.smooth = False
    triangles = sum(len(face.verts) - 2 for face in made.faces)
    made.to_mesh(mesh)
    made.free()
    for slot in slots:
        mesh.materials.append(material_for(slot))
    thing = bpy.data.objects.new(name, mesh)
    bpy.context.collection.objects.link(thing)
    low = [min(v[i] for v in p.verts) for i in range(3)]
    high = [max(v[i] for v in p.verts) for i in range(3)]
    # (set out in a row to be looked at; where it stands here means nothing to the game)
    thing.location = (along - low[0], 12.0 if far else 0.0, 0.0)
    print("BUILT %-22s tris=%5d materials=%d size=%.1f x %.1f x %.1f" % (name, triangles, len(slots), high[0] - low[0], high[1] - low[1], high[2] - low[2]))
    return along + (high[0] - low[0]) + 2.0, triangles


def main():
    os.makedirs(OUT, exist_ok=True)
    bpy.ops.wm.read_factory_settings(use_empty=True)
    along = 0.0
    total = 0
    for make in PARTS:
        here = along
        along, triangles = build(make, make.__name__, along)
        total += triangles
        if make in FAR:
            build(make, make.__name__ + "_far", here, True)
    bpy.ops.wm.save_as_mainfile(filepath=os.path.join(ROOT, "tools", "temple.blend"))
    bpy.ops.export_scene.gltf(filepath=os.path.join(OUT, "temple.glb"), export_format="GLB", export_yup=True, export_animations=False, use_selection=False, export_apply=True)
    print("BUILT: %d parts, %d triangles" % (len(PARTS) + len(FAR), total))


main()
