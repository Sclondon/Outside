"""Builds the Egyptian props: one models/props/<name>.glb each, and models/props/props.json,
which says what is solid in each (boxes, cylinders, hulls), what kind of body it is, and
where its markers are. tools/build_prop_scenes.gd turns those into props/<name>.tscn.

Run from the project root:
    blender --background --python tools/build_props.py
    blender --background --python tools/build_props.py -- sphinx palm_a      # just these
then
    godot --headless --path . --import
    godot --headless --path . --script tools/build_prop_scenes.gd

Everything is written in Godot's space: metres, Y up, a prop faces +Z, and stands with
its foot at the origin (things that are picked up have the origin at their middle).
A prop is a function that fills a `Prop`: p.box, p.tube, p.lathe, p.ellipsoid, p.strand,
p.poly, and p.solid_box / p.solid_cyl / p.solid_hull for what can be stood on or run into.
`with p.at(position, yaw, scale):` places whatever is made inside it.

Keep them cheap: the game runs in phone browsers. The count of triangles is printed.
"""

import json
import math
import os
import random
import sys

import bmesh
import bpy
from mathutils import Matrix, Vector

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUT = os.path.join(ROOT, "models", "props")
ONLY = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []

X, Y, Z = Vector((1, 0, 0)), Vector((0, 1, 0)), Vector((0, 0, 1))
TAU = math.tau

# Colours (sRGB), by material name. scripts/prop.gd reshades each by its colour, so the
# names matter only for `frond` and `frond_dry`, which sway.
PALETTE = {
    "stone": (0.74, 0.66, 0.53),
    "stone_b": (0.69, 0.61, 0.49),
    "stone_dark": (0.57, 0.49, 0.39),
    "shade": (0.40, 0.34, 0.28),
    "casing": (0.90, 0.86, 0.76),
    "black": (0.07, 0.06, 0.06),
    "granite": (0.60, 0.41, 0.35),
    "basalt": (0.17, 0.16, 0.18),
    "gold": (0.86, 0.66, 0.24),
    "wood": (0.52, 0.39, 0.25),
    "wood_dark": (0.36, 0.26, 0.17),
    "cloth": (0.87, 0.81, 0.67),
    "cloth_red": (0.66, 0.27, 0.20),
    "cloth_blue": (0.22, 0.38, 0.52),
    "cloth_shade": (0.52, 0.47, 0.38),
    "trunk": (0.47, 0.37, 0.26),
    "trunk_dark": (0.36, 0.28, 0.20),
    "frond": (0.32, 0.46, 0.21),
    "frond_dry": (0.63, 0.55, 0.30),
    "date": (0.72, 0.40, 0.14),
    "clay": (0.72, 0.45, 0.30),
    "clay_dark": (0.50, 0.30, 0.20),
    "alabaster": (0.88, 0.84, 0.73),
    "rope": (0.70, 0.60, 0.42),
    "iron": (0.22, 0.21, 0.22),
    "bronze": (0.50, 0.36, 0.20),
    "water": (0.13, 0.27, 0.33),
    "rock": (0.62, 0.52, 0.40),
}
DOUBLE_SIDED = ("frond", "frond_dry")


def linear(c):
    return ((c + 0.055) / 1.055) ** 2.4 if c > 0.04045 else c / 12.92


class Placed:
    def __init__(self, prop, matrix):
        self.prop = prop
        self.matrix = matrix

    def __enter__(self):
        self.prop.stack.append(self.prop.m)
        self.prop.m = self.prop.m @ self.matrix

    def __exit__(self, *_):
        self.prop.m = self.prop.stack.pop()


class Prop:
    """What one prop is made of. `body`: "static", "throw" (a RigidBody3D he can pick up),
    "push" (a block he can push) or "none"."""

    def __init__(self, name, body="static"):
        self.name = name
        self.body = body
        self.mass = 2.0
        self.verts = []
        self.faces = []  # (indices, material, smooth, uvs or None)
        self.solids = []
        self.markers = {}
        self.ladders = []
        self.far = 0.0  # how far off it is still drawn (0: always)
        self.shadow = True  # whether it casts one
        self.m = Matrix.Identity(4)
        self.stack = []

    # --- placing ---

    def at(self, position=(0, 0, 0), yaw=0.0, scale=1.0, pitch=0.0, roll=0.0):
        matrix = Matrix.Translation(Vector(position)) @ Matrix.Rotation(yaw, 4, "Y") @ Matrix.Rotation(pitch, 4, "X") \
            @ Matrix.Rotation(roll, 4, "Z") @ Matrix.Scale(scale, 4)
        return Placed(self, matrix)

    def v(self, point):
        point = tuple(point)
        self.verts.append(self.m @ Vector(point if len(point) == 3 else point + (0.0,)))
        return len(self.verts) - 1

    def face(self, indices, material, smooth=False, uvs=None):
        self.faces.append((tuple(indices), material, smooth, uvs))

    # --- shapes ---

    def box(self, centre, size, material, solid=False, top=(1.0, 1.0), shift=(0.0, 0.0), yaw=0.0, pitch=0.0, roll=0.0, sides=None):
        """A box. `top` narrows its top (x, z) and `shift` slides it, for battered walls.
        `sides`: another material for its four sides."""
        with self.at(centre, yaw, 1.0, pitch, roll):
            hx, hy, hz = size[0] * 0.5, size[1] * 0.5, size[2] * 0.5
            corners = ((-1, -1), (1, -1), (1, 1), (-1, 1))
            low = [self.v((x * hx, -hy, z * hz)) for x, z in corners]
            high = [self.v((x * hx * top[0] + shift[0], hy, z * hz * top[1] + shift[1])) for x, z in corners]
            self.face(low, material)
            self.face(high[::-1], material)
            for i in range(4):
                j = (i + 1) % 4
                self.face((low[i], high[i], high[j], low[j]), sides or material)
            if solid:
                if top == (1.0, 1.0) and shift == (0.0, 0.0):
                    self.solid_box((0, 0, 0), size)
                else:
                    self.solids.append({"type": "hull", "points": [list(self.verts[i]) for i in low + high]})

    def tube(self, rings, material, segments=12, power=2.0, caps=True, smooth=True, tip0=None, tip1=None, bands=None, split=False):
        """A skin over rings, each (centre, u, v): its points are centre + u cos + v sin,
        squared off as `power` rises above 2. `bands`: a material for each gap between
        rings, instead of `material`. `split`: a hard edge at every ring.
        Returns the indices of its points."""
        if split and len(rings) > 2:
            used = []
            for j in range(len(rings) - 1):
                which = bands[j % len(bands)] if bands else material
                used += self.tube(rings[j:j + 2], which, segments, power, False, smooth)
            return used
        def bend(c):
            return math.copysign(abs(c) ** (2.0 / power), c)
        made = []
        for centre, u, v in rings:
            centre, u, v = Vector(centre), Vector(u), Vector(v)
            made.append([self.v(centre + u * bend(math.cos(TAU * k / segments)) + v * bend(math.sin(TAU * k / segments))) for k in range(segments)])
        (c0, u0, v0), (c1, _, _) = rings[0], rings[1]
        outward = Vector(u0).cross(Vector(v0)).dot(Vector(c1) - Vector(c0)) > 0.0
        used = [i for ring in made for i in ring]
        for j in range(len(made) - 1):
            which = bands[j % len(bands)] if bands else material
            for k in range(segments):
                n = (k + 1) % segments
                quad = (made[j][k], made[j][n], made[j + 1][n], made[j + 1][k])
                self.face(quad if outward else quad[::-1], which, smooth)
        first = bands[0] if bands else material
        last = bands[(len(made) - 2) % len(bands)] if bands else material
        if tip0 is not None:
            tip = self.v(tip0)
            used.append(tip)
            for k in range(segments):
                tri = (tip, made[0][(k + 1) % segments], made[0][k])
                self.face(tri if outward else tri[::-1], first, smooth)
        elif caps:
            self.face(made[0][::-1] if outward else made[0], first)
        if tip1 is not None:
            tip = self.v(tip1)
            used.append(tip)
            for k in range(segments):
                tri = (tip, made[-1][k], made[-1][(k + 1) % segments])
                self.face(tri if outward else tri[::-1], last, smooth)
        elif caps:
            self.face(made[-1] if outward else made[-1][::-1], last)
        return used

    def lathe(self, profile, material, segments=10, centre=(0, 0, 0), power=2.0, caps=True, smooth=True, bands=None, split=False):
        """Turned on a lathe: `profile` is (radius, height) pairs, going up."""
        c = Vector(centre)
        return self.tube([(c + Y * y, X * r, Z * r) for r, y in profile], material, segments, power, caps, smooth, bands=bands, split=split)

    def long(self, x, rings, material, segments=12, power=4.0, smooth=True, bands=None, caps=True):
        """A shape lying along Z: `rings` are (z, half width, bottom, top)."""
        return self.tube([((x, (y0 + y1) * 0.5, z), X * hw, Y * (y1 - y0) * 0.5) for z, hw, y0, y1 in rings], material, segments, power, caps, smooth, bands=bands)

    def ellipsoid(self, centre, radii, material, segments=10, rings=6, smooth=True):
        c, r = Vector(centre), Vector(radii)
        made = []
        for j in range(1, rings):
            lat = -math.pi * 0.5 + math.pi * j / rings
            made.append((c + Y * (r.y * math.sin(lat)), X * (r.x * math.cos(lat)), Z * (r.z * math.cos(lat))))
        return self.tube(made, material, segments, 2.0, False, smooth, c - Y * r.y, c + Y * r.y)

    def strand(self, points, radii, material, segments=6, caps=True, smooth=True, tip=False):
        """A round rod through `points`, as thick at each as `radii` says."""
        points = [Vector(p) for p in points]
        if not isinstance(radii, (list, tuple)):
            radii = [radii] * len(points)
        rings = []
        u = None
        for i, p in enumerate(points):
            ahead = (points[min(i + 1, len(points) - 1)] - points[max(i - 1, 0)]).normalized()
            if u is None:
                ref = X if abs(ahead.dot(Y)) > 0.9 else Y
                u = ref.cross(ahead).normalized()
            else:
                u = (u - ahead * u.dot(ahead)).normalized()
            rings.append((p, u * radii[i], ahead.cross(u) * radii[i]))
        if tip:
            return self.tube(rings[:-1], material, segments, 2.0, caps, smooth, tip1=points[-1])
        return self.tube(rings, material, segments, 2.0, caps, smooth)

    def poly(self, points, material, smooth=False, uvs=None):
        """A flat face: counter-clockwise seen from the side it faces."""
        self.face([self.v(p) for p in points], material, smooth, uvs)

    # --- what is solid ---

    def _frame(self, centre, yaw=0.0):
        m = self.m @ Matrix.Translation(Vector(centre)) @ Matrix.Rotation(yaw, 4, "Y")
        scale = m.to_scale().x
        basis = [list(m.col[i].xyz.normalized()) for i in range(3)]
        return {"basis": basis, "origin": list(m.col[3].xyz)}, scale

    def solid_box(self, centre, size, yaw=0.0):
        frame, scale = self._frame(centre, yaw)
        self.solids.append({"type": "box", "size": [s * scale for s in size], **frame})

    def solid_cyl(self, centre, radius, height):
        """A cylinder standing on end (along the Y of wherever it is placed)."""
        frame, scale = self._frame(centre)
        self.solids.append({"type": "cylinder", "radius": radius * scale, "height": height * scale, **frame})

    def solid_hull(self, points):
        self.solids.append({"type": "hull", "points": [list(self.m @ Vector(p)) for p in points]})

    def solid_points(self, indices):
        self.solids.append({"type": "hull", "points": [list(self.verts[i]) for i in indices]})

    def marker(self, name, point):
        self.markers[name] = list(self.m @ Vector(point))

    def ladder(self, point, height, yaw=0.0):
        self.ladders.append({"at": list(self.m @ Vector(point)), "height": height, "yaw": yaw})

    def jitter(self, indices, amount, rng):
        for i in indices:
            self.verts[i] = self.verts[i] + Vector((rng.uniform(-1, 1), rng.uniform(-1, 1), rng.uniform(-1, 1))) * amount


# ---------------------------------------------------------------- shared pieces

def disc(p, cx, cy, rx, ry, material, n=8, z=0.0):
    p.poly([(cx + rx * math.cos(TAU * k / n), cy + ry * math.sin(TAU * k / n), z) for k in range(n)], material)


def rect(p, cx, cy, w, h, material, z=0.0):
    p.poly([(cx - w / 2, cy - h / 2, z), (cx + w / 2, cy - h / 2, z), (cx + w / 2, cy + h / 2, z), (cx - w / 2, cy + h / 2, z)], material)


def stroke(p, points, thick, material, z=0.0):
    for (x0, y0), (x1, y1) in zip(points, points[1:]):
        d = Vector((x1 - x0, y1 - y0, 0.0)).normalized() * thick * 0.5
        n = Vector((-d.y, d.x, 0.0))
        a, b = Vector((x0, y0, z)) - d, Vector((x1, y1, z)) + d
        p.poly([a - n, b - n, b + n, a + n], material)


GLYPHS = ("sun", "eye", "water", "ankh", "bird", "reed", "snake", "house", "loaf", "feather", "bars", "staff", "owl", "basket")


def glyph(p, kind, cx, cy, s, material):
    """A hieroglyph, flat, in a square `s` across on the X-Y plane, facing +Z."""
    t = s * 0.09
    if kind == "sun":
        disc(p, cx, cy, s * 0.3, s * 0.3, material, 10)
    elif kind == "eye":
        disc(p, cx, cy + s * 0.08, s * 0.4, s * 0.16, material, 8)
        stroke(p, [(cx - s * 0.05, cy - s * 0.08), (cx - s * 0.05, cy - s * 0.36)], t, material)
        stroke(p, [(cx + s * 0.1, cy - s * 0.08), (cx + s * 0.34, cy - s * 0.3)], t, material)
    elif kind == "water":
        for row in (0.2, 0.0, -0.2):
            stroke(p, [(cx + s * (-0.4 + 0.2 * i), cy + s * (row + (0.07 if i % 2 else -0.07))) for i in range(5)], t, material)
    elif kind == "ankh":
        disc(p, cx, cy + s * 0.22, s * 0.15, s * 0.2, material, 8)
        stroke(p, [(cx, cy + s * 0.04), (cx, cy - s * 0.42)], t * 1.3, material)
        stroke(p, [(cx - s * 0.26, cy), (cx + s * 0.26, cy)], t * 1.3, material)
    elif kind == "bird":
        disc(p, cx - s * 0.05, cy - s * 0.02, s * 0.3, s * 0.17, material, 8)
        disc(p, cx + s * 0.2, cy + s * 0.24, s * 0.11, s * 0.11, material, 6)
        p.poly([(cx + s * 0.28, cy + s * 0.2), (cx + s * 0.45, cy + s * 0.22), (cx + s * 0.28, cy + s * 0.3)], material)
        stroke(p, [(cx, cy - s * 0.15), (cx, cy - s * 0.42), (cx + s * 0.15, cy - s * 0.42)], t, material)
    elif kind == "owl":
        disc(p, cx, cy - s * 0.05, s * 0.2, s * 0.3, material, 8)
        disc(p, cx, cy + s * 0.3, s * 0.17, s * 0.13, material, 6)
        stroke(p, [(cx - s * 0.1, cy - s * 0.42), (cx + s * 0.1, cy - s * 0.42)], t, material)
    elif kind == "reed":
        stroke(p, [(cx, cy - s * 0.42), (cx, cy + s * 0.2)], t, material)
        p.poly([(cx, cy + s * 0.05), (cx + s * 0.2, cy + s * 0.3), (cx, cy + s * 0.45)], material)
    elif kind == "snake":
        stroke(p, [(cx - s * 0.4, cy - s * 0.1), (cx - s * 0.2, cy + s * 0.08), (cx, cy - s * 0.1), (cx + s * 0.2, cy + s * 0.08), (cx + s * 0.32, cy + s * 0.2)], t * 1.2, material)
        disc(p, cx + s * 0.36, cy + s * 0.24, s * 0.08, s * 0.06, material, 6)
    elif kind == "house":
        stroke(p, [(cx - s * 0.3, cy - s * 0.3), (cx - s * 0.3, cy + s * 0.3), (cx + s * 0.3, cy + s * 0.3), (cx + s * 0.3, cy - s * 0.3)], t, material)
        stroke(p, [(cx - s * 0.3, cy - s * 0.3), (cx - s * 0.08, cy - s * 0.3)], t, material)
    elif kind == "loaf":
        n = 6
        p.poly([(cx + s * 0.32 * math.cos(math.pi * k / n), cy - s * 0.15 + s * 0.36 * math.sin(math.pi * k / n), 0.0) for k in range(n + 1)], material)
    elif kind == "feather":
        disc(p, cx, cy + s * 0.05, s * 0.13, s * 0.38, material, 8)
        stroke(p, [(cx, cy - s * 0.3), (cx, cy - s * 0.44)], t, material)
    elif kind == "bars":
        for row in (0.22, 0.0, -0.22):
            stroke(p, [(cx - s * 0.3, cy + s * row), (cx + s * 0.3, cy + s * row)], t * 1.2, material)
    elif kind == "staff":
        stroke(p, [(cx, cy - s * 0.44), (cx, cy + s * 0.3), (cx + s * 0.2, cy + s * 0.42)], t, material)
    elif kind == "basket":
        n = 6
        p.poly([(cx + s * 0.36 * math.cos(-math.pi * k / n), cy + s * 0.12 + s * 0.3 * math.sin(-math.pi * k / n), 0.0) for k in range(n + 1)][::-1], material)


def glyph_grid(p, columns, rows, cell, material, rng, lines=True):
    """Rows of glyphs on the X-Y plane, the grid centred on the origin."""
    w, h = columns * cell, rows * cell
    for r in range(rows):
        for c in range(columns):
            glyph(p, rng.choice(GLYPHS), -w / 2 + (c + 0.5) * cell, h / 2 - (r + 0.5) * cell, cell * 0.86, material)
    if lines:
        for r in range(rows + 1):
            rect(p, 0.0, h / 2 - r * cell, w, cell * 0.05, material)


def nemes_head(p, a="stone", b="stone_dark", nose=True, beard=False, lappet_z=0.1):
    """A king's head in the striped headcloth. The chin is at the origin, the face is
    1 high and looks along +Z."""
    p.tube([((0, -0.36, -0.08), X * 0.25, Z * 0.25), ((0, 0.12, -0.05), X * 0.22, Z * 0.22)], a, 8)
    p.ellipsoid((0, 0.50, 0.02), (0.36, 0.52, 0.40), a, 12, 7)
    profile = [(1.14, 0.30, 0.32, -0.05), (1.04, 0.42, 0.43, -0.06), (0.92, 0.49, 0.46, -0.08), (0.80, 0.56, 0.44, -0.10),
               (0.68, 0.65, 0.41, -0.13), (0.56, 0.74, 0.38, -0.15), (0.44, 0.83, 0.35, -0.17), (0.32, 0.91, 0.32, -0.19),
               (0.20, 0.98, 0.30, -0.21), (0.08, 1.04, 0.28, -0.22), (-0.04, 1.08, 0.26, -0.23), (-0.10, 1.00, 0.22, -0.23)]
    p.tube([((0, y, cz), X * hw, Z * hd) for y, hw, hd, cz in profile][::-1], a, 14, 2.6, True, True, tip1=(0, 1.22, -0.05), bands=(b, a))
    # The band across the brow, and the cobra on it
    p.box((0, 0.90, 0.33), (0.62, 0.08, 0.14), a)
    p.ellipsoid((0, 0.99, 0.40), (0.05, 0.11, 0.06), a, 6, 4)
    # The lappets down onto the chest
    for side in (1.0, -1.0):
        for i in range(5):
            p.box((side * (0.56 - i * 0.012), 0.05 - i * 0.145, lappet_z), (0.32 - i * 0.012, 0.145, 0.13), a if i % 2 else b)
        p.ellipsoid((side * 0.375, 0.55, 0.16), (0.045, 0.13, 0.075), a, 6, 4)
        p.ellipsoid((side * 0.145, 0.61, 0.345), (0.09, 0.036, 0.05), b, 8, 4)
    p.ellipsoid((0, 0.27, 0.34), (0.13, 0.03, 0.05), b, 8, 4)
    if nose:
        p.box((0, 0.46, 0.43), (0.12, 0.24, 0.13), a, top=(0.5, 0.4), shift=(0.0, -0.03))
    else:
        p.box((0, 0.42, 0.40), (0.12, 0.10, 0.08), a)
    if beard:
        p.box((0, -0.24, 0.30), (0.10, 0.44, 0.10), b, top=(1.5, 1.5))


# ---------------------------------------------------------------- the props

def sphinx(p):
    g = 0.3
    a, b = "stone", "stone_b"
    # The plinth it lies on
    p.box((0, g * 0.5, 0.5), (9.6, g, 25.6), "stone_dark", True)
    # Body, rump to chest
    p.long(0.0, [(-10.4, 1.0, g, g + 2.0), (-10.1, 1.8, g, g + 3.0), (-9.3, 2.25, g, g + 3.6), (-8.0, 2.4, g, g + 3.8),
                 (-5.5, 2.3, g, g + 3.8), (-3.0, 2.25, g, g + 3.8), (-0.5, 2.28, g, g + 3.8), (0.4, 1.6, g, g + 3.8),
                 (2.5, 1.55, g, g + 3.9), (3.0, 1.35, g, g + 3.75)], a, 14, 4.0, bands=(a, a, b, a, b, a, a, a, a))
    # (the chest is narrower than the body: the shoulders either side of it are a step up)
    p.solid_box((0, g + 1.9, -5.3), (4.8, 3.8, 9.8))
    p.solid_box((0, g + 1.9, 1.3), (3.0, 3.8, 3.4))
    p.solid_box((0, g + 1.2, -10.3), (3.0, 2.4, 0.6))
    for side in (1.0, -1.0):
        # Forelegs, out in front, and the paws
        p.long(side * 1.6, [(0.5, 0.8, g, g + 2.0), (3.0, 0.85, g, g + 1.6), (4.4, 0.85, g, g + 1.3), (8.0, 0.85, g, g + 1.3),
                            (11.3, 0.85, g, g + 1.3), (12.0, 0.95, g, g + 1.28), (12.5, 0.9, g, g + 1.05)], a, 12, 4.0)
        for toe in (-0.62, -0.21, 0.21, 0.62):
            p.ellipsoid((side * 1.6 + toe, g + 0.5, 12.45), (0.21, 0.5, 0.62), a, 6, 4)
        p.solid_box((side * 1.6, g + 0.65, 7.85), (1.7, 1.3, 9.9))
        # The shoulder, a step up to the back
        p.long(side * 2.3, [(-0.6, 0.6, g, g + 2.2), (0.3, 0.95, g, g + 2.6), (2.4, 0.95, g, g + 2.6), (3.1, 0.75, g, g + 2.2)], a, 12, 4.0)
        p.solid_box((side * 2.35, g + 1.3, 1.3), (1.7, 2.6, 3.4))
        # Haunch and hind paw
        p.ellipsoid((side * 2.55, g + 1.25, -7.4), (1.05, 1.55, 2.3), a, 10, 6)
        p.long(side * 3.05, [(-7.0, 0.5, g, g + 0.8), (-6.0, 0.55, g, g + 0.9), (-3.6, 0.55, g, g + 0.9), (-3.1, 0.5, g, g + 0.7)], a, 10, 4.0)
        p.solid_box((side * 2.8, g + 1.1, -7.4), (1.4, 2.2, 3.0))
        p.solid_box((side * 3.05, g + 0.45, -4.6), (1.1, 0.9, 3.2))
    # The tail, round the right haunch
    p.strand([(1.0, g + 1.2, -10.2), (2.6, g + 0.5, -10.2), (3.75, g + 0.35, -9.0), (3.95, g + 0.35, -7.0), (3.8, g + 0.4, -5.6)],
             [0.2, 0.2, 0.19, 0.2, 0.28], a, 6)
    # The back of the headcloth, down onto the shoulders
    p.tube([((0, g + 3.4, 1.75), X * 1.5, Z * 1.05), ((0, g + 4.3, 1.75), X * 1.5, Z * 1.05), ((0, g + 4.9, 1.8), X * 1.2, Z * 0.9)], a, 12, 3.0)
    # Head
    with p.at((0, g + 4.1, 2.25), 0.0, 2.7):
        nemes_head(p, a, "stone_dark", nose=False, lappet_z=0.36)
    p.solid_box((0, g + 5.75, 2.1), (4.8, 3.3, 2.6))
    # The stone between the paws
    p.box((0, g + 1.0, 3.2), (1.1, 2.0, 0.34), "granite", True, top=(0.9, 1.0))
    with p.at((0, g + 1.05, 3.39)):
        glyph_grid(p, 3, 5, 0.3, "shade", random.Random(4))
    p.far = 0.0


def pyramid_great(p):
    half, rise, tread = 30.0, 1.35, 0.9
    courses = int(half / tread)
    cased = 24
    for i in range(cased):
        h = half - tread * i
        p.box((0, rise * (i + 0.5), 0), (h * 2, rise, h * 2), "stone" if i % 2 else "stone_b", True)
    # What is left of the smooth casing, at the top
    y0 = rise * cased
    h0 = half - tread * (cased - 1) + 0.05
    apex = y0 + h0 * rise / tread
    points = [(-h0, y0, -h0), (h0, y0, -h0), (h0, y0, h0), (-h0, y0, h0)]
    tip = p.v((0, apex, 0))
    made = [p.v(q) for q in points]
    for i in range(4):
        p.face((made[i], tip, made[(i + 1) % 4]), "casing")
    p.solid_hull(points + [(0, apex, 0)])
    # A few casing stones still in place lower down
    rng = random.Random(11)
    for i in range(14):
        course = rng.randint(14, cased - 1)
        h = half - tread * course
        along = rng.uniform(-h * 0.8, h * 0.8)
        with p.at((0, 0, 0), rng.choice((0, 1, 2, 3)) * math.pi * 0.5):
            p.box((along, rise * (course + 0.5), h + tread * 0.5 - 0.02), (rng.uniform(1.5, 4.0), rise, tread), "casing", top=(1.0, 0.02), shift=(0, -tread * 0.49))
    del courses


def pyramid_ruined(p):
    rng = random.Random(3)
    half, rise, tread = 10.0, 1.2, 0.85
    for i in range(7):
        h = half - tread * i
        material = "stone" if i % 2 else "stone_b"
        notch = 0.0 if i == 0 else 1.6 * i
        y = rise * (i + 0.5)
        if notch == 0.0:
            p.box((0, y, 0), (h * 2, rise, h * 2), material, True)
        else:
            # (the corner towards +x +z has fallen away)
            p.box((-notch * 0.5, y, 0), (h * 2 - notch, rise, h * 2), material, True)
            p.box((h - notch * 0.5, y, -notch * 0.5), (notch, rise, h * 2 - notch), material, True)
    # The broken top
    for i in range(7):
        s = rng.uniform(0.9, 1.6)
        p.box((rng.uniform(-3.0, 1.0), rise * 7 + s * 0.3, rng.uniform(-3.0, 1.0)), (s * 1.3, s * 0.6, s), "stone_dark", True, yaw=rng.uniform(0, 3))
    # What fell, in the broken corner and out from it
    for i in range(16):
        d = rng.uniform(0.0, 1.0)
        s = rng.uniform(0.8, 1.5)
        x = z = 0.0
        while not (x > 1.0 and z > 1.0):
            x, z = (half + 2.5) * (1.0 - d * 0.75) + rng.uniform(-2.5, 1.0), (half + 2.5) * (1.0 - d * 0.75) + rng.uniform(-2.5, 1.0)
        y = max(0.0, d * 7.0 - 0.6) + s * 0.25
        p.box((x, y, z), (s * 1.3, s * 0.7, s), "stone_dark" if i % 3 else "stone", True, yaw=rng.uniform(0, 3), pitch=rng.uniform(-0.25, 0.25), roll=rng.uniform(-0.25, 0.25))


def pyramid_entrance(p):
    a, b = "stone", "stone_dark"
    deep = 6.0
    for side in (1.0, -1.0):
        # (battered: the outer wall leans in)
        p.box((side * 3.0, 2.4, 0), (3.2, 4.8, deep), a, True, top=(0.92, 1.0), shift=(-side * 0.13, 0.0))
        with p.at((side * 2.9, 2.6, deep * 0.5 + 0.02)):
            glyph_grid(p, 2, 6, 0.55, "shade", random.Random(7 + int(side)), lines=False)
    # Lintel, the roll under the cornice, and the cornice, which flares
    p.box((0, 5.5, 0), (8.6, 1.4, deep), a, True)
    p.box((0, 6.3, 0), (8.9, 0.22, deep + 0.3), b)
    p.box((0, 6.85, 0), (8.6, 0.9, deep), a, True, top=(1.09, 1.08))
    p.box((0, 7.37, 0), (9.4, 0.14, deep + 0.5), b)
    # The winged sun over the door
    with p.at((0, 5.5, deep * 0.5 + 0.02)):
        disc(p, 0, 0, 0.42, 0.42, "gold", 10)
        for side in (1.0, -1.0):
            wing = [(side * 0.45, 0.2), (side * 3.4, 0.38), (side * 3.5, 0.1), (side * 2.6, -0.3), (side * 0.45, -0.22)]
            p.poly([(x, y, 0) for x, y in (wing if side > 0 else wing[::-1])][::-1], "gold")
    # The way in: dark, and shut a little way back
    p.box((0, 2.4, -deep * 0.5 + 0.35), (3.0, 4.8, 0.5), "black", True)
    p.box((0, 0.04, 0), (2.9, 0.08, deep - 0.4), "shade")
    p.box((0, 4.82, 0), (2.9, 0.08, deep - 0.4), "black")
    for side in (1.0, -1.0):
        p.box((side * 1.35, 2.4, -0.4), (0.06, 4.8, deep - 1.2), "black")
    # A step up to it
    p.box((0, 0.1, deep * 0.5 + 0.6), (5.0, 0.2, 1.2), b, True)


def palm(p, height, lean, bend, fronds, seed, frond_length=3.3):
    rng = random.Random(seed)
    # The trunk: a curve from the foot, out along +X and back up
    def trunk(t):
        return Vector((lean * t + bend * math.sin(math.pi * t) , height * t, 0.25 * bend * math.sin(TAU * t)))
    steps = 10
    points, radii = [], []
    for i in range(steps + 1):
        t = i / steps
        points.append(trunk(t))
        radii.append((0.4 if i == 0 else 0.28 - 0.09 * t) + (0.022 if i % 2 else 0.0))
    p.strand(points, radii, "trunk", 7, caps=False)
    # (solid up to where he could reach)
    for t0, t1 in ((0.0, 0.2), (0.2, 0.42), (0.42, 0.7)):
        low, high = trunk(t0), trunk(t1)
        p.solid_box(((low + high) * 0.5), (0.4, (high - low).length, 0.4))
    top = trunk(1.0)
    # (few materials: there are many palms, and each material is drawn separately)
    p.ellipsoid(top + Y * 0.1, (0.3, 0.42, 0.3), "trunk", 7, 4)
    for i in range(3):
        angle = rng.uniform(0, TAU)
        p.ellipsoid(top + Vector((math.cos(angle) * 0.3, -0.25, math.sin(angle) * 0.3)), (0.13, 0.26, 0.13), "frond_dry", 5, 3)
    for i in range(fronds):
        upper = i % 2 == 0
        yaw = TAU * i / fronds + rng.uniform(-0.2, 0.2)
        rise = rng.uniform(0.8, 1.2) if upper else rng.uniform(0.1, 0.5)
        frond(p, top + Y * 0.3, yaw, frond_length * rng.uniform(0.85, 1.1), rise, rng.uniform(0.8, 1.15), 0.4, "frond", 10)
    for i in range(3):
        frond(p, top + Y * 0.1, rng.uniform(0, TAU), frond_length * 0.75, -0.5, 0.9, 0.3, "frond_dry", 6)


def frond(p, base, yaw, length, rise, droop, width, material, segments=8):
    """One leaf: a rib that arches up and over, and a toothed blade folded along it.
    Its first texture coordinate runs from the stem to the tip: the leaf sways by it."""
    with p.at(base, yaw):
        ribs, lefts, rights = [], [], []
        at = Vector((0, 0, 0.15))
        for i in range(segments + 1):
            t = i / segments
            angle = rise - (rise + droop) * t ** 1.3
            if i:
                at = at + Vector((0, math.sin(angle), math.cos(angle))) * (length / segments)
            w = width * math.sin(math.pi * (0.06 + 0.9 * t)) ** 0.6 * (1.0 if i % 2 else 0.4)
            up = Vector((0, math.cos(angle), -math.sin(angle)))
            ribs.append(p.v(at))
            lefts.append(p.v(at + X * w - up * w * 0.45))
            rights.append(p.v(at - X * w - up * w * 0.45))
        for i in range(segments):
            t0, t1 = i / segments, (i + 1) / segments
            p.face((ribs[i], ribs[i + 1], lefts[i + 1], lefts[i]), material, True, ((t0, 0.5), (t1, 0.5), (t1, 1.0), (t0, 1.0)))
            p.face((ribs[i], rights[i], rights[i + 1], ribs[i + 1]), material, True, ((t0, 0.5), (t0, 0.0), (t1, 0.0), (t1, 0.5)))


def palm_a(p):
    palm(p, 8.0, 1.2, 0.5, 16, 1, 3.7)


def palm_b(p):
    palm(p, 10.5, 2.6, 1.3, 18, 2, 4.0)


def palm_c(p):
    palm(p, 4.8, 0.3, 0.25, 14, 3, 3.2)


def obelisk(p):
    p.box((0, 0.2, 0), (3.2, 0.4, 3.2), "stone_dark", True)
    p.box((0, 0.8, 0), (2.3, 0.8, 2.3), "granite", True)
    base, tall, top = 0.8, 12.0, 0.52
    p.box((0, 1.2 + tall * 0.5, 0), (base * 2, tall, base * 2), "granite", True, top=(top / base, top / base))
    p.box((0, 1.2 + tall + 0.6, 0), (top * 2, 1.2, top * 2), "gold", True, top=(0.02, 0.02))
    rng = random.Random(5)
    for face in range(4):
        with p.at((0, 0, 0), face * math.pi * 0.5):
            for i in range(11):
                y = 2.2 + i * 0.95
                hw = base - (base - top) * (y - 1.2) / tall
                with p.at((0, y, hw + 0.03 + 0.008 * i), 0.0, 1.0, -math.atan2(base - top, tall)):
                    glyph(p, rng.choice(GLYPHS), 0, 0, 0.72, "shade")


COLUMN_SHAFT = 0.55


def column_drums(p, top, material="stone", joints=1.0):
    """The shaft up to `top`: its radius dips at each joint between drums."""
    profile = [(0.78, 0.0), (0.78, 0.22), (0.66, 0.34)]
    y = 0.34
    while y < top - 0.01:
        up = min(y + joints, top)
        r = COLUMN_SHAFT - 0.05 * (y / 5.0)
        profile += [(r, y + 0.035), (r - 0.012, up - 0.035), (r - 0.045, up)]
        y = up
    return profile


def column(p):
    profile = column_drums(p, 4.7)
    p.lathe(profile, "stone", 12, split=True)
    # Bands at the neck, and the bell of the capital opening like a papyrus head
    p.lathe([(0.5, 4.7), (0.54, 4.74), (0.54, 4.95), (0.5, 4.99)], "stone_dark", 12, bands=("stone", "stone_dark", "stone"))
    p.lathe([(0.5, 4.99), (0.56, 5.2), (0.74, 5.5), (1.0, 5.7), (0.96, 5.74)], "stone", 12)
    p.box((0, 5.87, 0), (1.3, 0.26, 1.3), "stone_dark")
    p.solid_cyl((0, 0.17, 0), 0.78, 0.34)
    p.solid_cyl((0, 3.0, 0), 0.56, 6.0)
    p.solid_box((0, 5.75, 0), (1.3, 0.5, 1.3))


def broken_top(p, y, rng, drop=0.5):
    """The snapped end of a shaft: a ragged ring, lower in the middle."""
    r = COLUMN_SHAFT - 0.05 * (y / 5.0)
    lean = rng.uniform(0, TAU)
    ring = [p.v((r * math.cos(TAU * k / 12), y - drop * (0.5 + 0.5 * math.cos(TAU * k / 12 - lean)) * rng.uniform(0.7, 1.0), r * math.sin(TAU * k / 12))) for k in range(12)]
    below = [p.v((r * math.cos(TAU * k / 12), y - drop - 0.05, r * math.sin(TAU * k / 12))) for k in range(12)]
    middle = p.v((rng.uniform(-0.1, 0.1), y - drop * 0.6, rng.uniform(-0.1, 0.1)))
    for k in range(12):
        n = (k + 1) % 12
        p.face((below[k], ring[k], ring[n], below[n]), "stone")
        p.face((ring[k], middle, ring[n]), "stone_dark")


def column_broken(p):
    rng = random.Random(8)
    p.lathe(column_drums(p, 3.0), "stone", 12, split=True)
    broken_top(p, 3.6, rng)
    p.solid_cyl((0, 0.17, 0), 0.78, 0.34)
    p.solid_cyl((0, 1.6, 0), 0.55, 3.2)


def column_stump(p):
    rng = random.Random(9)
    p.lathe(column_drums(p, 1.2), "stone", 12, split=True)
    broken_top(p, 1.42, rng, 0.14)
    p.solid_cyl((0, 0.17, 0), 0.78, 0.34)
    p.solid_cyl((0, 0.67, 0), 0.55, 1.34)


def column_fallen(p):
    rng = random.Random(10)
    z = -3.4
    for i in range(4):
        long = rng.uniform(1.3, 1.9)
        r = 0.55 - 0.012 * i
        with p.at((rng.uniform(-0.12, 0.12), r - 0.14, z + long * 0.5), rng.uniform(-0.09, 0.09), 1.0, math.pi * 0.5):
            p.lathe([(r - 0.04, -long * 0.5), (r, -long * 0.5 + 0.04), (r, long * 0.5 - 0.04), (r - 0.04, long * 0.5)], "stone" if i % 2 else "stone_b", 12)
            p.solid_cyl((0, 0, 0), r, long)
        z += long + rng.uniform(0.08, 0.3)
    # Its capital, tipped over at the end
    with p.at((0.25, 0.62, z + 0.75), 0.3, 1.0, math.pi * 0.5 - 0.35):
        p.lathe([(0.5, -0.6), (0.56, -0.35), (0.74, 0.0), (1.0, 0.22), (0.96, 0.28)], "stone", 12)
        p.box((0, 0.42, 0), (1.3, 0.26, 1.3), "stone_dark")
        p.solid_cyl((0, -0.05, 0), 0.8, 1.1)


def lintel(p):
    p.box((0, 0.42, 0), (5.2, 0.84, 1.1), "stone_b", True)
    p.box((0, 0.9, 0), (5.3, 0.12, 1.2), "stone_dark", True)
    with p.at((0, 0.42, 0.56)):
        glyph_grid(p, 9, 1, 0.5, "stone_dark", random.Random(12), lines=False)


def statue_pharaoh(p):
    a, b = "stone", "stone_dark"
    with p.at((0, 0, 0), 0.0, 3.4):
        p.box((0, 0.06, 0.1), (0.74, 0.12, 1.16), b)
        p.box((0, 0.36, -0.16), (0.62, 0.48, 0.52), a)
        p.box((0, 0.78, -0.42), (0.62, 0.72, 0.12), a, top=(0.9, 1.0))
        # Legs, kilt, feet
        for side in (1.0, -1.0):
            p.tube([((side * 0.115, 0.12, 0.2), X * 0.075, Z * 0.085), ((side * 0.115, 0.64, 0.21), X * 0.085, Z * 0.09)], a, 8, 3.0)
            p.box((side * 0.115, 0.155, 0.33), (0.13, 0.07, 0.26), a)
        p.long(0.0, [(-0.2, 0.22, 0.6, 0.77), (0.2, 0.22, 0.6, 0.775), (0.3, 0.2, 0.61, 0.76)], a, 10, 4.0)
        # Body
        p.tube([((0, y, -0.12), X * hw, Z * hd) for y, hw, hd in ((0.6, 0.2, 0.14), (0.8, 0.165, 0.12), (1.0, 0.22, 0.13), (1.1, 0.25, 0.125), (1.16, 0.15, 0.1))], a, 10, 2.6)
        for side in (1.0, -1.0):
            p.strand([(side * 0.27, 1.09, -0.12), (side * 0.275, 0.84, -0.09), (side * 0.16, 0.8, 0.17)], [0.06, 0.052, 0.045], a, 6)
            p.ellipsoid((side * 0.16, 0.8, 0.2), (0.05, 0.04, 0.06), a, 6, 3)
        with p.at((0, 1.17, -0.11), 0.0, 0.3):
            nemes_head(p, a, b, nose=True, beard=True)
        with p.at((0, 0.36, 0.105)):
            pass
    p.solid_box((0, 0.2, 0.34), (2.5, 0.4, 3.9))
    p.solid_box((0, 1.4, -0.05), (2.1, 2.2, 2.9))
    p.solid_box((0, 3.8, -0.5), (2.0, 2.8, 1.7))


def statue_anubis(p):
    s = 1.25
    with p.at((0, 0, 0), 0.0, s):
        # The shrine he lies on
        p.box((0, 0.05, 0), (1.3, 0.1, 2.6), "gold")
        p.box((0, 0.59, 0), (1.14, 0.98, 2.4), "stone_dark", top=(0.92, 0.96))
        p.box((0, 1.14, 0), (1.26, 0.12, 2.56), "gold", top=(1.05, 1.03))
        for side in (1.0, -1.0):
            with p.at((side * 0.556, 0.6, 0), side * math.pi * 0.5, 1.0, -0.045):
                glyph_grid(p, 6, 2, 0.34, "gold", random.Random(20 + int(side)), lines=False)
        y = 1.2
        k = "basalt"
        p.long(0.0, [(-1.0, 0.09, y, y + 0.2), (-0.85, 0.19, y, y + 0.36), (-0.3, 0.17, y + 0.02, y + 0.36), (0.3, 0.19, y, y + 0.4), (0.55, 0.15, y, y + 0.42)], k, 10, 2.6)
        for side in (1.0, -1.0):
            p.ellipsoid((side * 0.19, y + 0.19, -0.66), (0.11, 0.2, 0.3), k, 8, 4)
            p.long(side * 0.24, [(-0.6, 0.05, y, y + 0.1), (-0.2, 0.05, y, y + 0.1)], k, 6, 3.0)
            p.long(side * 0.13, [(0.3, 0.06, y, y + 0.14), (1.1, 0.055, y, y + 0.11), (1.2, 0.05, y, y + 0.09)], k, 6, 3.0)
            # Tall ears
            p.tube([((side * 0.075, y + 0.86, 0.6), X * 0.055, Z * 0.035), ((side * 0.09, y + 1.0, 0.59), X * 0.045, Z * 0.03)], k, 6, tip1=(side * 0.1, y + 1.22, 0.58))
        p.strand([(0, y + 0.3, 0.42), (0, y + 0.55, 0.56), (0, y + 0.76, 0.64)], [0.15, 0.115, 0.1], k, 8)
        p.strand([(0, y + 0.36, 0.44), (0, y + 0.44, 0.5)], [0.165, 0.15], "gold", 8)
        p.ellipsoid((0, y + 0.8, 0.68), (0.105, 0.105, 0.15), k, 8, 5)
        p.strand([(0, y + 0.79, 0.76), (0, y + 0.765, 0.98), (0, y + 0.75, 1.14)], [0.075, 0.05, 0.034], k, 6)
        # The tail, hanging down the back of the shrine
        p.strand([(0, y + 0.2, -0.95), (0, y + 0.05, -1.26), (0, y - 0.35, -1.31), (0, y - 0.75, -1.3)], [0.05, 0.055, 0.065, 0.05], k, 6)
    p.solid_box((0, 0.75, 0), (1.6, 1.5, 3.2))
    p.solid_box((0, 1.75, -0.2), (0.5, 0.5, 2.1))
    p.solid_box((0, 2.3, 0.8), (0.4, 1.0, 0.7))


def sarcophagus(p):
    p.box((0, 0.09, 0), (1.5, 0.18, 2.9), "stone_dark", True)
    p.box((0, 0.6, 0), (1.24, 0.86, 2.64), "granite", True)
    p.box((0, 1.035, 0), (1.04, 0.02, 2.44), "black")
    with p.at((0.63, 0.62, 0), math.pi * 0.5):
        glyph_grid(p, 8, 2, 0.3, "gold", random.Random(31))
    with p.at((-0.63, 0.62, 0), -math.pi * 0.5):
        glyph_grid(p, 8, 2, 0.3, "gold", random.Random(32))
    # The lid, pushed askew
    with p.at((0.3, 1.04, 0.12), 0.16):
        p.long(0.0, [(-1.36, 0.62, 0.0, 0.2), (-1.3, 0.66, 0.0, 0.42), (1.3, 0.66, 0.0, 0.42), (1.36, 0.62, 0.0, 0.2)], "granite", 10, 2.6)
        p.box((0, 0.22, -1.27), (1.34, 0.5, 0.16), "granite")
        p.box((0, 0.22, 1.27), (1.34, 0.5, 0.16), "granite")
        p.solid_box((0, 0.2, 0), (1.3, 0.4, 2.7))


def jar_canopic(p, jackal=False):
    """Stands 0.42 high; the origin is at its middle, where he holds it."""
    with p.at((0, -0.21, 0)):
        p.lathe([(0.07, 0.0), (0.1, 0.03), (0.125, 0.14), (0.12, 0.2), (0.118, 0.23), (0.09, 0.28), (0.085, 0.3)], "alabaster", 8,
                bands=("alabaster", "alabaster", "gold", "alabaster", "alabaster", "alabaster"))
        if jackal:
            p.ellipsoid((0, 0.345, 0), (0.07, 0.065, 0.075), "basalt", 8, 4)
            p.strand([(0, 0.35, 0.05), (0, 0.335, 0.15)], [0.045, 0.022], "basalt", 6)
            for side in (1.0, -1.0):
                p.tube([((side * 0.04, 0.39, -0.01), X * 0.025, Z * 0.018), ((side * 0.045, 0.42, -0.012), X * 0.02, Z * 0.014)], "basalt", 4, tip1=(side * 0.05, 0.47, -0.015))
        else:
            p.ellipsoid((0, 0.35, 0), (0.085, 0.07, 0.085), "alabaster", 8, 4)
            p.ellipsoid((0, 0.345, 0.03), (0.055, 0.055, 0.065), "clay", 8, 4)
    p.body = "throw"
    p.mass = 2.0
    p.solid_cyl((0, 0, 0), 0.115, 0.42)
    p.far = 70.0


def jar_canopic_jackal(p):
    jar_canopic(p, True)


def pot(p):
    with p.at((0, -0.16, 0)):
        p.lathe([(0.07, 0.0), (0.14, 0.05), (0.17, 0.14), (0.15, 0.23), (0.09, 0.28), (0.1, 0.32)], "clay", 8,
                bands=("clay", "clay", "clay_dark", "clay", "clay"))
        for side in (1.0, -1.0):
            p.strand([(side * 0.15, 0.22, 0), (side * 0.2, 0.27, 0), (side * 0.11, 0.31, 0)], 0.018, "clay", 4)
    p.body = "throw"
    p.mass = 2.0
    p.solid_cyl((0, 0, 0), 0.15, 0.32)
    p.far = 70.0


def pot_large(p):
    p.lathe([(0.14, 0.0), (0.26, 0.12), (0.36, 0.45), (0.34, 0.7), (0.2, 0.88), (0.17, 0.95), (0.21, 1.0)], "clay", 10,
            bands=("clay", "clay", "clay_dark", "clay", "clay", "clay"))
    p.poly([(0.17 * math.cos(-TAU * k / 8), 0.97, 0.17 * math.sin(-TAU * k / 8)) for k in range(8)], "black")
    p.solid_cyl((0, 0.5, 0), 0.33, 1.0)
    p.far = 110.0


def rock_small(p):
    rng = random.Random(40)
    made = p.ellipsoid((0, 0, 0), (0.14, 0.1, 0.12), "rock", 6, 4, smooth=False)
    p.jitter(made, 0.018, rng)
    p.body = "throw"
    p.mass = 2.0
    p.solids.append({"type": "sphere", "radius": 0.11, "basis": [[1, 0, 0], [0, 1, 0], [0, 0, 1]], "origin": [0, 0, 0]})
    p.far = 60.0


def boulder(p, radii, seed, material="rock"):
    rng = random.Random(seed)
    made = p.ellipsoid((0, radii[1] * 0.55, 0), radii, material, 8, 5, smooth=False)
    p.jitter(made, min(radii) * 0.2, rng)
    p.solid_points(made)


def rock_a(p):
    boulder(p, (1.5, 1.0, 1.2), 41)
    p.far = 160.0


def rock_b(p):
    boulder(p, (0.75, 0.5, 0.6), 42, "stone_dark")
    p.far = 110.0


def block(p):
    p.box((0, 0.45, 0), (1.5, 0.9, 0.95), "stone", True, top=(0.985, 0.98))
    p.far = 140.0


def block_stack(p):
    p.box((-0.8, 0.45, 0), (1.5, 0.9, 0.95), "stone", True, yaw=0.05)
    p.box((0.78, 0.45, 0.06), (1.5, 0.9, 0.95), "stone_b", True, yaw=-0.04)
    p.box((0.1, 1.35, 0.0), (1.5, 0.9, 0.95), "stone", True, yaw=0.14)
    p.box((0.3, 0.3, 1.25), (1.1, 0.6, 0.8), "stone_dark", True, yaw=0.5)
    p.far = 160.0


def rubble(p):
    rng = random.Random(44)
    for i in range(11):
        s = rng.uniform(0.25, 0.7)
        r = rng.uniform(0.0, 1.5)
        angle = rng.uniform(0, TAU)
        p.box((math.cos(angle) * r, s * 0.22, math.sin(angle) * r), (s * 1.4, s * 0.62, s), ("stone", "stone_dark")[i % 2], True,
              yaw=rng.uniform(0, 3), pitch=rng.uniform(-0.3, 0.3), roll=rng.uniform(-0.2, 0.2))
    p.far = 110.0


def brazier(p):
    for i in range(3):
        angle = TAU * i / 3 + 0.5
        p.strand([(math.cos(angle) * 0.4, 0.0, math.sin(angle) * 0.4), (math.cos(angle) * 0.12, 0.62, math.sin(angle) * 0.12), (math.cos(angle) * 0.2, 0.86, math.sin(angle) * 0.2)],
                 0.03, "iron", 5)
    p.lathe([(0.08, 0.78), (0.26, 0.86), (0.37, 1.0), (0.39, 1.08), (0.35, 1.09)], "bronze", 10)
    p.poly([(0.34 * math.cos(-TAU * k / 10), 1.06, 0.34 * math.sin(-TAU * k / 10)) for k in range(10)], "black")
    p.marker("Flame", (0, 1.08, 0))
    p.solid_cyl((0, 0.55, 0), 0.32, 1.1)
    p.far = 120.0


def torch_stand(p):
    p.box((0, 0.2, 0), (0.5, 0.4, 0.5), "stone_dark", True, top=(0.8, 0.8))
    p.strand([(0, 0.4, 0), (0, 1.85, 0)], 0.045, "wood_dark", 6)
    p.lathe([(0.05, 1.8), (0.13, 1.9), (0.15, 2.02), (0.13, 2.03)], "bronze", 8)
    p.poly([(0.12 * math.cos(-TAU * k / 8), 2.0, 0.12 * math.sin(-TAU * k / 8)) for k in range(8)], "black")
    p.marker("Flame", (0, 2.02, 0))
    p.solid_box((0, 1.0, 0), (0.16, 2.0, 0.16))
    p.far = 120.0


def campfire(p):
    rng = random.Random(46)
    for i in range(8):
        angle = TAU * i / 8
        made = p.ellipsoid((math.cos(angle) * 0.5, 0.07, math.sin(angle) * 0.5), (0.16, 0.12, 0.14), "rock", 5, 3, smooth=False)
        p.jitter(made, 0.02, rng)
    for i in range(4):
        angle = TAU * i / 4 + 0.4
        p.strand([(math.cos(angle) * 0.4, 0.05, math.sin(angle) * 0.4), (-math.cos(angle) * 0.08, 0.3, -math.sin(angle) * 0.08)], 0.05, "wood_dark", 5)
    disc_points = [(0.42 * math.cos(-TAU * k / 8), 0.02, 0.42 * math.sin(-TAU * k / 8)) for k in range(8)]
    p.poly(disc_points, "black")
    p.marker("Flame", (0, 0.22, 0))
    p.solid_cyl((0, 0.1, 0), 0.6, 0.2)
    p.far = 110.0


def well(p):
    p.lathe([(1.2, 0.0), (1.2, 0.72), (1.12, 0.8), (0.82, 0.8), (0.8, 0.35)], "stone", 12, caps=False, smooth=False, bands=("stone", "stone", "stone", "stone_dark"))
    p.poly([(0.8 * math.cos(-TAU * k / 12), 0.38, 0.8 * math.sin(-TAU * k / 12)) for k in range(12)], "water")
    for k in range(8):
        angle = TAU * (k + 0.5) / 8
        with p.at((math.cos(angle) * 1.0, 0.4, math.sin(angle) * 1.0), -angle):
            p.solid_box((0, 0, 0), (0.4, 0.8, 0.86))
    p.solid_cyl((0, 0.19, 0), 0.9, 0.38)
    # The frame over it, and the bucket
    for side in (1.0, -1.0):
        p.box((side * 1.3, 1.25, 0), (0.16, 2.5, 0.16), "wood", True)
        p.strand([(side * 1.3, 1.7, 0), (side * 0.85, 2.42, 0)], 0.045, "wood_dark", 4)
    p.box((0, 2.5, 0), (3.0, 0.16, 0.16), "wood")
    p.strand([(0, 2.45, 0), (0, 1.45, 0)], 0.018, "wood_dark", 4)
    p.lathe([(0.13, 1.2), (0.17, 1.45)], "wood_dark", 8)
    p.far = 150.0


def scaffold(p):
    high = 3.5
    for x in (-1.3, 1.3):
        for z in (-1.0, 1.0):
            p.box((x, (high + 1.0) * 0.5 if z < 0 else high * 0.5, z), (0.14, high + 1.0 if z < 0 else high, 0.14), "wood", True)
    p.box((0, high - 0.06, 0), (2.9, 0.12, 2.3), "wood", True, sides="wood_dark")
    for z in (-1.0, 1.0):
        p.box((0, 1.2, z), (2.6, 0.1, 0.08), "wood_dark")
    for x in (-1.3, 1.3):
        p.box((x, 2.2, 0), (0.08, 0.1, 2.0), "wood_dark")
        p.strand([(x, 0.2, -1.0), (x, high - 0.3, 1.0)], 0.04, "wood_dark", 4)
    p.strand([(-1.3, 0.2, -1.0), (1.3, high - 0.3, -1.0)], 0.04, "wood_dark", 4)
    # A rail along the back and the sides, none at the front where the ladder comes up
    p.box((0, high + 0.95, -1.0), (2.74, 0.08, 0.08), "wood_dark")
    p.box((0, high + 0.5, -1.0), (2.74, 0.06, 0.06), "wood_dark")
    p.solid_box((0, high + 0.5, -1.06), (2.8, 1.0, 0.06))
    p.ladder((-0.8, 0, 1.21), high, 0.0)
    p.far = 170.0


def crate(p):
    s = 0.9
    p.box((0, s * 0.5, 0), (s - 0.06, s - 0.06, s - 0.06), "wood")
    t = 0.1
    for a in (-1.0, 1.0):
        for b in (-1.0, 1.0):
            p.box((a * (s - t) * 0.5, s * 0.5, b * (s - t) * 0.5), (t, s, t), "wood_dark")
            p.box((0, s * 0.5 + a * (s - t) * 0.5, b * (s - t) * 0.5), (s - t * 2, t, t), "wood_dark")
            p.box((a * (s - t) * 0.5, s * 0.5 + b * (s - t) * 0.5, 0), (t, t, s - t * 2), "wood_dark")
    p.solid_box((0, s * 0.5, 0), (s, s, s))
    p.far = 120.0


def block_push(p):
    """A block he can push. The origin is at its middle."""
    s = 0.9
    p.box((0, 0, 0), (s, s, s), "stone_b")
    for face in range(4):
        with p.at((0, 0, 0), face * math.pi * 0.5):
            with p.at((0, 0, s * 0.5 + 0.004)):
                stroke(p, [(-0.33, -0.33), (-0.33, 0.33), (0.33, 0.33), (0.33, -0.33), (-0.33, -0.33)], 0.05, "shade")
                glyph(p, ("ankh", "eye", "sun", "bird")[face], 0, 0, 0.5, "shade")
    p.body = "push"
    p.mass = 20.0
    p.solid_box((0, 0, 0), (s, s, s))


def sheet(p, grid, materials):
    """Cloth: `grid` is rows of points. Both sides are drawn."""
    for r in range(len(grid) - 1):
        for c in range(len(grid[0]) - 1):
            quad = (grid[r][c], grid[r + 1][c], grid[r + 1][c + 1], grid[r][c + 1])
            material = materials[c % len(materials)]
            p.poly(quad, material, True)
            p.poly(quad[::-1], material, True)


def awning(p):
    # Posts: taller at the front
    for x in (-1.6, 1.6):
        p.box((x, 1.25, 1.1), (0.1, 2.5, 0.1), "wood", True)
        p.box((x, 1.05, -1.1), (0.1, 2.1, 0.1), "wood", True)
    grid = []
    for r in range(4):
        z = -1.3 + 2.6 * r / 3
        y = 2.1 + 0.4 * r / 3
        grid.append([(-1.8 + 3.6 * c / 6, y - 0.16 * math.sin(math.pi * c / 6) - 0.06 * math.sin(math.pi * r / 3), z) for c in range(7)])
    sheet(p, grid, ("cloth_red", "cloth"))
    # A fringe hanging at the front
    sheet(p, [[(x, y, z + 0.02) for x, y, z in grid[-1]], [(x, y - 0.28, z + 0.06) for x, y, z in grid[-1]]], ("cloth_red", "cloth"))
    # The table, and what is for sale
    p.box((0, 0.74, -0.3), (2.4, 0.08, 1.0), "wood", True)
    for x in (-1.1, 1.1):
        for z in (-0.7, 0.1):
            p.box((x, 0.35, z), (0.08, 0.7, 0.08), "wood_dark")
    p.solid_box((0, 0.37, -0.3), (2.4, 0.74, 1.0))
    for x, r, material in ((-0.8, 0.14, "clay"), (-0.4, 0.1, "clay"), (0.2, 0.16, "date"), (0.55, 0.15, "date"), (0.9, 0.11, "clay")):
        p.ellipsoid((x, 0.78 + r * 0.9, -0.3), (r, r * 0.9, r), material, 6, 4)
    p.far = 150.0


def tent(p):
    """A ridge tent of the kind an expedition lived in, its front open."""
    hw, wall, ridge, half = 1.5, 0.55, 2.1, 1.7
    for side in (1.0, -1.0):
        a, b = (side * hw, 0.0), (side * hw, wall)
        roof = [(side * hw, wall, -half), (0.0, ridge, -half), (0.0, ridge, half), (side * hw, wall, half)]
        walls = [(a[0], 0.0, -half), (b[0], wall, -half), (b[0], wall, half), (a[0], 0.0, half)]
        for quad in (roof, walls):
            p.poly(quad if side > 0 else quad[::-1], "cloth", True)
            p.poly(quad[::-1] if side > 0 else quad, "cloth_shade")
        # The flaps at the front, tied back
        flap = [(side * hw, 0.0, half), (side * hw, wall, half), (side * 0.25, ridge - 0.35, half), (side * 0.75, 0.0, half + 0.12)]
        p.poly(flap[::-1] if side > 0 else flap, "cloth")
        p.poly(flap if side > 0 else flap[::-1], "cloth_shade")
    back = [(-hw, 0.0, -half), (-hw, wall, -half), (0.0, ridge, -half), (hw, wall, -half), (hw, 0.0, -half)]
    p.poly(back, "cloth")
    p.poly(back[::-1], "cloth_shade")
    for z in (-half, half):
        p.box((0, (ridge + 0.25) * 0.5, z), (0.07, ridge + 0.25, 0.07), "wood")
    p.box((0, ridge + 0.02, 0), (0.06, 0.06, half * 2 + 0.3), "wood")
    for side in (1.0, -1.0):
        for z in (-half, half):
            p.strand([(side * hw, wall, z), (side * (hw + 0.9), 0.0, z * 1.25)], 0.012, "rope", 3)
    # A bedroll and a box inside
    p.box((-0.75, 0.09, -0.2), (0.7, 0.18, 1.9), "cloth_red")
    p.box((0.8, 0.22, -0.9), (0.6, 0.44, 0.9), "wood_dark")
    p.solid_hull([(-hw, 0, -half), (hw, 0, -half), (-hw, wall, -half), (hw, wall, -half), (0, ridge, -half),
                  (-hw, 0, -half + 0.5), (hw, 0, -half + 0.5), (0, ridge, -half + 0.5)])
    for side in (1.0, -1.0):
        p.solid_hull([(side * hw, 0, -half), (side * hw, 0, half), (side * hw, wall, -half), (side * hw, wall, half),
                      (side * (hw - 0.5), wall + 0.3, -half), (side * (hw - 0.5), wall + 0.3, half), (side * (hw - 0.3), 0, -half), (side * (hw - 0.3), 0, half)])
    p.far = 170.0


def wall_glyphs(p):
    w, h, d = 4.4, 3.2, 0.7
    p.box((0, 0.2, 0), (w + 0.3, 0.4, d + 0.3), "stone_dark", True)
    p.box((0, 0.4 + (h - 0.4) * 0.5, 0), (w, h - 0.4, d), "stone", True)
    p.box((0, h + 0.09, 0), (w + 0.16, 0.18, d + 0.16), "stone_dark")
    p.box((0, h + 0.43, 0), (w, 0.5, d), "stone_b", True, top=(1.06, 1.3))
    rng = random.Random(50)
    with p.at((0, 1.85, d * 0.5 + 0.015)):
        glyph_grid(p, 8, 5, 0.5, "shade", rng)
    with p.at((0, 1.85, -d * 0.5 - 0.015), math.pi):
        glyph_grid(p, 8, 5, 0.5, "shade", rng)
    p.far = 200.0


def wall_ruin(p):
    """What is left of a wall: it steps down, and can be climbed a step at a time."""
    d = 0.95
    x = -3.0
    for i, (long, high) in enumerate(((1.6, 3.3), (1.3, 2.4), (1.5, 1.4), (1.6, 0.7))):
        p.box((x + long * 0.5, high * 0.5, 0), (long, high, d), "stone" if i % 2 else "stone_b", True)
        x += long
    p.box((3.4, 0.2, 0.5), (0.9, 0.4, 0.7), "stone_dark", True, yaw=0.5)
    with p.at((-2.2, 1.9, d * 0.5 + 0.015)):
        glyph_grid(p, 2, 4, 0.5, "shade", random.Random(52), lines=False)
    p.far = 200.0


def oasis_rim(p):
    """A curved kerb of worn stones, a quarter of a ring 6 m across, to set round water."""
    rng = random.Random(54)
    for i in range(6):
        angle = (i + 0.5) / 6 * math.pi * 0.5
        s = rng.uniform(0.8, 1.05)
        p.box((math.cos(angle) * 6.0, 0.14, math.sin(angle) * 6.0), (0.7, rng.uniform(0.3, 0.42), 1.45 * s), "stone" if i % 2 else "stone_b", True,
              yaw=-angle + rng.uniform(-0.06, 0.06), top=(0.9, 0.95))
    p.far = 150.0


PROPS = [sphinx, pyramid_great, pyramid_ruined, pyramid_entrance, palm_a, palm_b, palm_c, obelisk, column, column_broken, column_stump,
         column_fallen, lintel, statue_pharaoh, statue_anubis, sarcophagus, jar_canopic, jar_canopic_jackal, pot, pot_large, rock_small,
         rock_a, rock_b, block, block_stack, rubble, brazier, torch_stand, campfire, well, oasis_rim, scaffold, crate, block_push, awning,
         tent, wall_glyphs, wall_ruin]


# ---------------------------------------------------------------- writing them out

# How far off each of these is still drawn, in metres (others say so themselves, or are
# always drawn). Any one placed in a level can be given another `draw_distance` there.
# Too small for a shadow to be worth drawing.
NO_SHADOW = ("jar_canopic", "jar_canopic_jackal", "pot", "rock_small", "rubble", "campfire", "oasis_rim")
FAR = {"column": 190.0, "column_broken": 190.0, "column_stump": 150.0, "column_fallen": 190.0, "lintel": 190.0, "statue_pharaoh": 230.0,
       "statue_anubis": 200.0, "sarcophagus": 130.0, "palm_a": 210.0, "palm_b": 210.0, "palm_c": 210.0}

MADE_MATERIALS = {}


def material_for(name):
    if name not in MADE_MATERIALS:
        material = bpy.data.materials.new(name)
        material.use_nodes = True
        colour = tuple(linear(c) for c in PALETTE[name]) + (1.0,)
        shader = material.node_tree.nodes["Principled BSDF"]
        shader.inputs["Base Color"].default_value = colour
        shader.inputs["Roughness"].default_value = 1.0
        material.diffuse_color = colour
        material.use_backface_culling = name not in DOUBLE_SIDED
        MADE_MATERIALS[name] = material
    return MADE_MATERIALS[name]


def export(p):
    mesh = bpy.data.meshes.new(p.name)
    made = bmesh.new()
    layer = made.loops.layers.uv.verify()
    points = [made.verts.new((v.x, -v.z, v.y)) for v in p.verts]
    slots = []
    triangles = 0
    for indices, material, smooth, uvs in p.faces:
        if len(set(indices)) < 3:
            continue
        try:
            face = made.faces.new([points[i] for i in indices])
        except ValueError:
            continue
        if material not in slots:
            slots.append(material)
        face.material_index = slots.index(material)
        face.smooth = smooth
        if uvs:
            for loop, uv in zip(face.loops, uvs):
                loop[layer].uv = uv
        triangles += len(indices) - 2
    for vert in [v for v in made.verts if not v.link_faces]:
        made.verts.remove(vert)
    made.to_mesh(mesh)
    made.free()
    for name in slots:
        mesh.materials.append(material_for(name))
    thing = bpy.data.objects.new(p.name, mesh)
    bpy.context.collection.objects.link(thing)
    bpy.ops.object.select_all(action="DESELECT")
    thing.select_set(True)
    bpy.context.view_layer.objects.active = thing
    bpy.ops.export_scene.gltf(
        filepath=os.path.join(OUT, p.name + ".glb"),
        export_format="GLB",
        export_yup=True,
        export_animations=False,
        use_selection=True,
    )
    bpy.data.objects.remove(thing)
    bpy.data.meshes.remove(mesh)
    low = [min(v[i] for v in p.verts) for i in range(3)]
    high = [max(v[i] for v in p.verts) for i in range(3)]
    print("BUILT %-20s tris=%5d materials=%d size=%.1f x %.1f x %.1f" % (p.name, triangles, len(slots), high[0] - low[0], high[1] - low[1], high[2] - low[2]))
    return {"body": p.body, "mass": p.mass, "solids": p.solids, "markers": p.markers, "ladders": p.ladders, "far": p.far, "shadow": p.shadow,
            "triangles": triangles, "materials": len(slots)}


def main():
    os.makedirs(OUT, exist_ok=True)
    bpy.ops.wm.read_factory_settings(use_empty=True)
    listing = os.path.join(OUT, "props.json")
    known = {}
    if ONLY and os.path.exists(listing):
        with open(listing) as file:
            known = json.load(file)
    total = 0
    for make in PROPS:
        if ONLY and make.__name__ not in ONLY:
            continue
        p = Prop(make.__name__)
        make(p)
        p.far = p.far or FAR.get(p.name, 0.0)
        p.shadow = p.name not in NO_SHADOW
        known[p.name] = export(p)
        total += known[p.name]["triangles"]
    with open(listing, "w") as file:
        json.dump(known, file, indent=1)
    print("BUILT: %d triangles in what was built; %d props listed" % (total, len(known)))


main()
