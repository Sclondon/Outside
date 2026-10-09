"""Builds the guns and the things that go with them: one models/guns/<name>.glb each, and
models/guns/guns.json, which says where each one's muzzle and other markers are, what is
solid in it, and where its moving parts turn. tools/build_gun_scenes.gd turns those into
guns/<name>.tscn.

Run from the project root:
    blender --background --python tools/build_guns.py
    blender --background --python tools/build_guns.py -- revolver rifle      # just these
then
    godot --headless --path . --import
    godot --headless --path . --script tools/build_gun_scenes.gd

Everything is written in Godot's space, in metres. A GUN has its origin at the grip (the
middle of where the trigger hand closes), its barrel along -Z and its top at +Y; in here
a gun is drawn in (f, y): f is how far forward of the grip, so z = -f. The other things
stand with their foot at the origin and face +Z.

A model is made of parts. Each part is a mesh of its own in the .glb, with its origin at
the part's `pivot`, so that the game can turn or slide it: the rifle's `Bolt`, the
`Barrel` of everything that breaks open, the `Board` of a target.

Keep them cheap: the game runs in phone browsers. The count of triangles is printed.
"""

import json
import math
import os
import sys

import bmesh
import bpy
from mathutils import Matrix, Vector

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUT = os.path.join(ROOT, "models", "guns")
ONLY = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []

X, Y, Z = Vector((1, 0, 0)), Vector((0, 1, 0)), Vector((0, 0, 1))
TAU = math.tau

# Colours (sRGB), by material name. scripts/gun.gd gives the ones named in its METALS a
# little shine; everything else is shaded as the props are.
PALETTE = {
    "gunmetal": (0.17, 0.18, 0.21),
    "steel": (0.34, 0.35, 0.38),
    "steel_bright": (0.66, 0.67, 0.70),
    "brass": (0.80, 0.61, 0.24),
    "walnut": (0.43, 0.26, 0.15),
    "walnut_dark": (0.30, 0.18, 0.10),
    "grip": (0.20, 0.13, 0.09),
    "black": (0.05, 0.05, 0.05),
    "wood": (0.52, 0.39, 0.25),
    "wood_dark": (0.36, 0.26, 0.17),
    "rope": (0.70, 0.60, 0.42),
    "iron": (0.22, 0.21, 0.22),
    "paint_white": (0.90, 0.87, 0.78),
    "paint_red": (0.70, 0.20, 0.15),
    "paint_green": (0.27, 0.36, 0.24),
    "paper_red": (0.62, 0.16, 0.13),
    "glass": (0.15, 0.30, 0.20),
    "glass_brown": (0.33, 0.20, 0.09),
    "label": (0.86, 0.80, 0.62),
    "tin": (0.55, 0.56, 0.55),
}


def linear(c):
    return ((c + 0.055) / 1.055) ** 2.4 if c > 0.04045 else c / 12.92


class Placed:
    def __init__(self, model, matrix):
        self.model = model
        self.matrix = matrix

    def __enter__(self):
        self.model.stack.append(self.model.m)
        self.model.m = self.model.m @ self.matrix

    def __exit__(self, *_):
        self.model.m = self.model.stack.pop()


class Model:
    def __init__(self, name):
        self.name = name
        self.parts = {}    # name: {"pivot": Vector, "verts": [], "faces": []}
        self.solids = []
        self.markers = {}
        self.pivots = {}
        self.about = {}    # anything else the scene builder should know
        self.m = Matrix.Identity(4)
        self.stack = []
        self.part("Body")

    # --- parts and placing ---

    def part(self, name, pivot=(0, 0, 0)):
        """What is made from here on belongs to this part, which turns about `pivot`."""
        if name not in self.parts:
            self.parts[name] = {"pivot": Vector(pivot), "verts": [], "faces": []}
            if name != "Body":
                self.pivots[name] = list(pivot)
        self.now = self.parts[name]

    def at(self, position=(0, 0, 0), yaw=0.0, scale=1.0, pitch=0.0, roll=0.0):
        matrix = Matrix.Translation(Vector(position)) @ Matrix.Rotation(yaw, 4, "Y") @ Matrix.Rotation(pitch, 4, "X") \
            @ Matrix.Rotation(roll, 4, "Z") @ Matrix.Scale(scale, 4)
        return Placed(self, matrix)

    def v(self, point):
        self.now["verts"].append(self.m @ Vector(point))
        return len(self.now["verts"]) - 1

    def face(self, indices, material, smooth=False):
        self.now["faces"].append((tuple(indices), material, smooth))

    # --- shapes ---

    def box(self, centre, size, material, top=(1.0, 1.0), shift=(0.0, 0.0), yaw=0.0, pitch=0.0, roll=0.0):
        """A box. `top` narrows its top (x, z) and `shift` slides it."""
        with self.at(centre, yaw, 1.0, pitch, roll):
            hx, hy, hz = size[0] * 0.5, size[1] * 0.5, size[2] * 0.5
            corners = ((-1, -1), (1, -1), (1, 1), (-1, 1))
            low = [self.v((x * hx, -hy, z * hz)) for x, z in corners]
            high = [self.v((x * hx * top[0] + shift[0], hy, z * hz * top[1] + shift[1])) for x, z in corners]
            self.face(low, material)
            self.face(high[::-1], material)
            for i in range(4):
                j = (i + 1) % 4
                self.face((low[i], high[i], high[j], low[j]), material)

    def tube(self, rings, material, segments=8, power=2.0, caps=True, smooth=True, bands=None):
        """A skin over rings, each (centre, u, v): its points are centre + u cos + v sin,
        squared off as `power` rises above 2. `bands`: a material for each gap."""
        def bend(c):
            return math.copysign(abs(c) ** (2.0 / power), c)
        made = []
        for centre, u, v in rings:
            centre, u, v = Vector(centre), Vector(u), Vector(v)
            made.append([self.v(centre + u * bend(math.cos(TAU * (k + 0.5) / segments)) + v * bend(math.sin(TAU * (k + 0.5) / segments)))
                         for k in range(segments)])
        (c0, u0, v0), (c1, _, _) = rings[0], rings[1]
        outward = Vector(u0).cross(Vector(v0)).dot(Vector(c1) - Vector(c0)) > 0.0
        for j in range(len(made) - 1):
            which = bands[j % len(bands)] if bands else material
            for k in range(segments):
                n = (k + 1) % segments
                quad = (made[j][k], made[j][n], made[j + 1][n], made[j + 1][k])
                self.face(quad if outward else quad[::-1], which, smooth)
        if caps:
            self.face(made[0][::-1] if outward else made[0], bands[0] if bands else material)
            self.face(made[-1] if outward else made[-1][::-1], bands[(len(made) - 2) % len(bands)] if bands else material)

    def lathe(self, profile, material, segments=10, centre=(0, 0, 0), caps=True, smooth=True, bands=None):
        """Turned on a lathe standing up: `profile` is (radius, height) pairs, going up."""
        c = Vector(centre)
        self.tube([(c + Y * y, Z * r, X * r) for r, y in profile], material, segments, 2.0, caps, smooth, bands)

    def bore(self, profile, y, material, segments=8, x=0.0, smooth=True, bands=None, caps=True):
        """Turned on a lathe lying along the barrel: `profile` is (f, radius) pairs, going
        forward, about the line at height `y`."""
        self.tube([((x, y, -f), X * r, Y * r) for f, r in profile], material, segments, 2.0, caps, smooth, bands)

    def long(self, sections, material, segments=8, power=3.0, smooth=True, caps=True, x=0.0):
        """A shape lying along the barrel: `sections` are (f, half width, bottom, top), going forward."""
        self.tube([((x, (y0 + y1) * 0.5, -f), X * hw, Y * (y1 - y0) * 0.5) for f, hw, y0, y1 in sections], material, segments, power, caps, smooth)

    def side(self, outline, half_width, material, x=0.0, chamfer=0.0):
        """A flat plate cut to a side view: `outline` is (f, y) points, going round
        clockwise as seen from the gun's right (+X); it is `half_width` thick each way.
        With `chamfer`, its edges are cut back by that much, so it is not a slab."""
        if sum(a[0] * b[1] - b[0] * a[1] for a, b in zip(outline, outline[1:] + outline[:1])) > 0.0:
            outline = outline[::-1]
        right = [self.v((x + half_width, y, -f)) for f, y in outline]
        left = [self.v((x - half_width, y, -f)) for f, y in outline]
        count = len(outline)
        if chamfer > 0.0:
            middle_f = sum(f for f, _ in outline) / count
            middle_y = sum(y for _, y in outline) / count
            inner = []
            for f, y in outline:
                away = Vector((f - middle_f, y - middle_y))
                away = away.normalized() * min(chamfer, away.length * 0.5)
                inner.append((f - away.x, y - away.y))
            far_right = [self.v((x + half_width + chamfer, y, -f)) for f, y in inner]
            far_left = [self.v((x - half_width - chamfer, y, -f)) for f, y in inner]
            self.face(far_right[::-1], material)
            self.face(far_left, material)
            for i in range(count):
                j = (i + 1) % count
                self.face((right[i], far_right[i], far_right[j], right[j]), material)
                self.face((left[i], far_left[i], far_left[j], left[j])[::-1], material)
        else:
            self.face(right[::-1], material)
            self.face(left, material)
        for i in range(count):
            j = (i + 1) % count
            self.face((right[i], right[j], left[j], left[i]), material)

    def rod(self, points, radii, material, segments=6, caps=True, smooth=True):
        """A round rod through `points` (x, y, z), as thick at each as `radii` says."""
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
        self.tube(rings, material, segments, 2.0, caps, smooth)

    def wire(self, outline, radius, material, x=0.0, segments=4):
        """A rod bent to a side view: `outline` is (f, y) points."""
        self.rod([(x, y, -f) for f, y in outline], radius, material, segments, True, True)

    def ball(self, centre, radii, material, segments=6, rings=4):
        c = Vector(centre)
        if not isinstance(radii, (list, tuple)):
            radii = (radii, radii, radii)
        made = []
        for j in range(1, rings):
            lat = -math.pi * 0.5 + math.pi * j / rings
            made.append((c + Y * (radii[1] * math.sin(lat)), Z * (radii[2] * math.cos(lat)), X * (radii[0] * math.cos(lat))))
        first = len(self.now["verts"])
        self.tube(made, material, segments, 2.0, False, True)
        low, high = self.v(c - Y * radii[1]), self.v(c + Y * radii[1])
        for k in range(segments):
            n = (k + 1) % segments
            self.face((low, first + n, first + k), material, True)
            last = first + (rings - 2) * segments
            self.face((high, last + k, last + n), material, True)

    def disc(self, centre, normal, radius, material, segments=8, inner=0.0):
        """A flat disc (or, with `inner`, a ring) facing along `normal`."""
        c, n = Vector(centre), Vector(normal).normalized()
        u = (X if abs(n.dot(X)) < 0.9 else Y).cross(n).normalized()
        w = n.cross(u)
        rim = [self.v(c + (u * math.cos(TAU * k / segments) + w * math.sin(TAU * k / segments)) * radius) for k in range(segments)]
        if inner <= 0.0:
            self.face(rim, material)
            return
        hole = [self.v(c + (u * math.cos(TAU * k / segments) + w * math.sin(TAU * k / segments)) * inner) for k in range(segments)]
        for k in range(segments):
            j = (k + 1) % segments
            self.face((rim[k], rim[j], hole[j], hole[k]), material)

    # --- what the game needs to know ---

    def _frame(self, centre):
        m = self.m @ Matrix.Translation(Vector(centre))
        return {"basis": [list(m.col[i].xyz.normalized()) for i in range(3)], "origin": list(m.col[3].xyz)}

    def solid_box(self, centre, size, part="Body"):
        self.solids.append({"type": "box", "size": list(size), "part": part, **self._frame(centre)})

    def solid_cyl(self, centre, radius, height, part="Body"):
        self.solids.append({"type": "cylinder", "radius": radius, "height": height, "part": part, **self._frame(centre)})

    def marker(self, name, point):
        self.markers[name] = list(self.m @ Vector(point))


# ---------------------------------------------------------------- the guns

def revolver(g):
    """A service revolver of the Webley kind: break-top, six chambers, a six-inch barrel,
    a square butt with a lanyard ring. 0.28 m long."""
    bore = 0.071
    # The butt, and the frame it is part of
    g.side([(0.014, 0.036), (0.008, -0.012), (-0.006, -0.060), (-0.040, -0.064), (-0.050, -0.046), (-0.040, 0.000), (-0.032, 0.040)], 0.0125, "grip", chamfer=0.004)
    g.side([(0.010, 0.030), (0.010, 0.088), (-0.004, 0.092), (-0.026, 0.072), (-0.034, 0.036)], 0.0135, "gunmetal")
    g.side([(0.010, 0.020), (0.010, 0.037), (0.060, 0.037), (0.074, 0.030), (0.064, 0.018), (0.034, 0.018)], 0.0095, "gunmetal")
    # Hammer, trigger and guard, and the ring at the butt
    g.side([(-0.008, 0.086), (-0.016, 0.096), (-0.028, 0.099), (-0.026, 0.092), (-0.022, 0.078)], 0.0035, "steel")
    g.side([(0.026, 0.020), (0.030, 0.020), (0.026, -0.004), (0.022, -0.002)], 0.003, "steel")
    g.wire([(0.046, 0.020), (0.044, -0.006), (0.028, -0.016), (0.012, -0.010), (0.008, 0.008)], 0.0028, "gunmetal")
    g.rod([(0.0, -0.064, 0.024), (0.008, -0.072, 0.024), (0.0, -0.080, 0.024), (-0.008, -0.072, 0.024), (0.0, -0.064, 0.024)], 0.0018, "steel", 4)
    # What tips forward when it is broken open: barrel, top strap and cylinder
    g.part("Barrel", (0.0, 0.027, -0.066))
    g.bore([(0.012, 0.0195), (0.014, 0.0212), (0.036, 0.0212), (0.040, 0.0200), (0.050, 0.0200)], 0.058, "steel", 10,
           bands=("steel", "steel", "gunmetal", "steel"))
    g.bore([(0.050, 0.0098), (0.226, 0.0086)], bore, "gunmetal", 6, smooth=False)
    g.disc((0, bore, -0.2262), -Z, 0.0052, "black", 6)
    g.box((0, 0.0855, -0.060), (0.011, 0.007, 0.105), "gunmetal")
    g.box((0, 0.0835, -0.170), (0.005, 0.005, 0.112), "gunmetal")
    g.side([(0.050, 0.082), (0.090, 0.082), (0.090, 0.060), (0.078, 0.030), (0.068, 0.020), (0.058, 0.028), (0.050, 0.040)], 0.0095, "gunmetal")
    g.side([(0.206, 0.085), (0.212, 0.096), (0.222, 0.085)], 0.0016, "steel")
    g.side([(0.004, 0.089), (0.004, 0.093), (0.012, 0.089)], 0.005, "gunmetal")
    g.part("Body")
    g.marker("Muzzle", (0, bore, -0.226))
    g.marker("Eject", (0, 0.062, -0.006))
    g.solid_box((0, 0.045, -0.105), (0.03, 0.09, 0.25))
    g.solid_box((0, -0.01, 0.015), (0.03, 0.11, 0.07))


def rifle(g):
    """A short magazine rifle of the Lee-Enfield kind: wood to the muzzle, a nose cap, a
    box magazine ahead of the trigger, the bolt handle bent down at the right. 1.13 m long."""
    bore = 0.047
    # The butt, the wrist, and the fore-end with the hand guard over the barrel
    g.long([(-0.360, 0.019, -0.108, 0.020), (-0.300, 0.021, -0.096, 0.026), (-0.130, 0.020, -0.050, 0.030), (-0.050, 0.018, -0.024, 0.028),
            (0.000, 0.019, -0.018, 0.032), (0.050, 0.021, -0.004, 0.036)], "walnut")
    g.box((0, -0.044, 0.363), (0.036, 0.130, 0.006), "brass")
    g.long([(0.030, 0.021, -0.004, 0.040), (0.200, 0.022, -0.002, 0.040), (0.420, 0.020, 0.008, 0.044), (0.720, 0.019, 0.016, 0.046)], "walnut")
    g.long([(0.235, 0.019, 0.040, 0.066), (0.420, 0.018, 0.044, 0.066), (0.720, 0.017, 0.046, 0.064)], "walnut_dark", 8, 2.4)
    # The action: body, charger bridge, magazine, trigger and guard
    g.box((0, 0.050, -0.110), (0.034, 0.022, 0.250), "gunmetal")
    g.box((0, 0.067, -0.058), (0.038, 0.012, 0.014), "gunmetal")
    g.side([(0.072, -0.002), (0.168, -0.002), (0.172, -0.046), (0.086, -0.058)], 0.013, "gunmetal")
    g.wire([(0.074, -0.004), (0.062, -0.034), (0.034, -0.040), (0.008, -0.030), (0.000, -0.016)], 0.003, "gunmetal")
    g.side([(0.040, -0.004), (0.045, -0.004), (0.040, -0.028), (0.035, -0.026)], 0.003, "steel")
    # Sights, the band, and the nose cap with its ears and the boss for a bayonet
    g.box((0, 0.071, -0.262), (0.016, 0.010, 0.050), "gunmetal")
    g.box((0, 0.035, -0.440), (0.045, 0.066, 0.016), "gunmetal")
    g.box((0, 0.040, -0.738), (0.042, 0.058, 0.040), "gunmetal")
    for side in (1.0, -1.0):
        g.side([(0.722, 0.066), (0.728, 0.086), (0.748, 0.086), (0.754, 0.066)], 0.0015, "gunmetal", x=side * 0.012)
    g.bore([(0.756, 0.0088), (0.772, 0.0088)], bore, "gunmetal", 6)
    g.disc((0, bore, -0.7722), -Z, 0.0045, "black", 6)
    g.bore([(0.756, 0.007), (0.768, 0.007)], 0.022, "gunmetal", 6)
    # The sling, from the band to the butt
    g.rod([(0, -0.002, -0.440), (0, -0.016, -0.200), (0, -0.060, 0.120), (0, -0.098, 0.300)], [0.004, 0.005, 0.005, 0.004], "rope", 4, smooth=False)
    # The bolt: turned up, drawn back, pushed home, turned down
    g.part("Bolt", (0.0, 0.058, 0.0))
    g.bore([(-0.020, 0.0082), (0.115, 0.0082)], 0.058, "steel_bright", 6)
    g.bore([(-0.052, 0.0095), (-0.020, 0.0095)], 0.058, "gunmetal", 6)
    g.rod([(0.008, 0.058, -0.004), (0.030, 0.046, 0.002), (0.038, 0.022, 0.008)], 0.0042, "steel_bright", 5)
    g.ball((0.040, 0.014, 0.009), 0.0105, "steel_bright", 6, 4)
    g.part("Body")
    g.marker("Muzzle", (0, bore, -0.772))
    g.marker("Support", (0, 0.004, -0.340))
    g.marker("Eject", (0.016, 0.066, -0.070))
    g.solid_box((0, 0.030, -0.385), (0.044, 0.076, 0.775))
    g.solid_box((0, -0.040, 0.180), (0.040, 0.130, 0.360))


def shotgun(g):
    """A double-barrelled shotgun, side by side, with outside hammers and a straight
    hand: the gun of every camp and dig. 1.16 m long, 0.70 of it barrels."""
    bore = 0.041
    # The stock, and the action it is let into
    g.long([(-0.360, 0.019, -0.112, 0.014), (-0.300, 0.021, -0.100, 0.020), (-0.110, 0.019, -0.042, 0.024), (-0.040, 0.017, -0.022, 0.024),
            (0.000, 0.018, -0.018, 0.028), (0.040, 0.021, -0.016, 0.040)], "walnut")
    g.box((0, -0.049, 0.363), (0.036, 0.128, 0.006), "grip")
    g.side([(0.030, -0.018), (0.030, 0.046), (0.100, 0.056), (0.100, 0.014), (0.142, 0.014), (0.142, -0.008), (0.090, -0.020)], 0.0215, "steel", chamfer=0.002)
    for side in (1.0, -1.0):
        g.side([(0.052, 0.046), (0.046, 0.072), (0.030, 0.082), (0.036, 0.062), (0.040, 0.046)], 0.003, "gunmetal", x=side * 0.021)
    g.box((0, 0.050, -0.050), (0.008, 0.006, 0.040), "gunmetal")
    g.wire([(0.080, -0.020), (0.070, -0.044), (0.040, -0.050), (0.010, -0.040), (0.002, -0.020)], 0.003, "gunmetal")
    g.side([(0.058, -0.018), (0.063, -0.018), (0.058, -0.040), (0.054, -0.038)], 0.003, "steel", x=0.004)
    g.side([(0.036, -0.018), (0.041, -0.018), (0.036, -0.040), (0.032, -0.038)], 0.003, "steel", x=-0.004)
    # The barrels, with the rib between them and the fore-end under them
    g.part("Barrel", (0.0, 0.004, -0.136))
    for side in (1.0, -1.0):
        g.bore([(0.100, 0.0140), (0.320, 0.0128), (0.800, 0.0118)], bore, "gunmetal", 8, x=side * 0.0128)
        g.disc((side * 0.0128, bore, -0.8002), -Z, 0.0088, "black", 8)
    g.box((0, bore + 0.011, -0.450), (0.007, 0.004, 0.700), "gunmetal")
    g.box((0, bore - 0.010, -0.450), (0.007, 0.004, 0.700), "gunmetal")
    g.ball((0, bore + 0.015, -0.790), 0.0028, "brass", 5, 3)
    g.box((0, 0.019, -0.121), (0.028, 0.022, 0.042), "steel")
    g.long([(0.146, 0.022, 0.004, 0.036), (0.300, 0.021, 0.006, 0.036), (0.380, 0.017, 0.014, 0.036)], "walnut")
    g.part("Body")
    g.marker("Muzzle", (0, bore, -0.800))
    g.marker("Support", (0, 0.004, -0.260))
    g.marker("Eject", (0, 0.060, -0.085))
    g.solid_box((0, 0.028, -0.385), (0.050, 0.070, 0.830))
    g.solid_box((0, -0.045, 0.180), (0.040, 0.130, 0.360))


def flare_pistol(g):
    """A signal pistol of the Webley and Scott kind: a brass frame, a short fat barrel an
    inch across that swells at the muzzle, a wooden butt with a lanyard ring."""
    bore = 0.068
    g.side([(0.014, 0.036), (0.006, -0.014), (-0.010, -0.066), (-0.046, -0.068), (-0.054, -0.046), (-0.042, 0.000), (-0.034, 0.040)], 0.0135, "walnut", chamfer=0.005)
    g.side([(0.012, 0.030), (0.012, 0.090), (-0.008, 0.092), (-0.030, 0.072), (-0.036, 0.036)], 0.016, "brass")
    g.side([(0.012, 0.018), (0.012, 0.044), (0.052, 0.044), (0.066, 0.034), (0.060, 0.018)], 0.011, "brass")
    g.side([(-0.012, 0.088), (-0.020, 0.100), (-0.034, 0.103), (-0.031, 0.095), (-0.026, 0.080)], 0.004, "steel")
    g.side([(0.028, 0.018), (0.032, 0.018), (0.028, -0.008), (0.024, -0.006)], 0.003, "steel")
    g.wire([(0.048, 0.018), (0.046, -0.010), (0.030, -0.020), (0.012, -0.014), (0.008, 0.006)], 0.003, "brass")
    g.rod([(0.0, -0.068, 0.028), (0.009, -0.077, 0.028), (0.0, -0.086, 0.028), (-0.009, -0.077, 0.028), (0.0, -0.068, 0.028)], 0.002, "steel", 4)
    g.part("Barrel", (0.0, 0.028, -0.058))
    g.bore([(0.014, 0.0225), (0.024, 0.0200), (0.130, 0.0200), (0.146, 0.0255), (0.158, 0.0255)], bore, "brass", 8,
           bands=("brass", "brass", "brass", "brass"))
    g.disc((0, bore, -0.1582), -Z, 0.0185, "black", 8)
    g.side([(0.014, 0.050), (0.074, 0.050), (0.070, 0.030), (0.062, 0.020), (0.052, 0.022), (0.014, 0.046)], 0.010, "brass")
    g.part("Body")
    g.marker("Muzzle", (0, bore, -0.158))
    g.marker("Eject", (0, 0.070, -0.004))
    g.solid_box((0, 0.050, -0.070), (0.05, 0.09, 0.19))
    g.solid_box((0, -0.012, 0.018), (0.032, 0.11, 0.07))


# ---------------------------------------------------------------- what goes with them

def ammo_box(g):
    """A wooden cartridge box, its lid propped open and the brass showing. 0.34 m long."""
    g.box((0, 0.075, 0), (0.34, 0.15, 0.20), "wood")
    g.box((0, 0.150, 0), (0.30, 0.004, 0.16), "black")
    for i in range(5):
        for j in range(3):
            g.disc((-0.11 + i * 0.055, 0.1535, -0.05 + j * 0.05), Y, 0.018, "brass", 6)
    for z in (0.101, -0.101):
        g.box((0, 0.075, z), (0.35, 0.03, 0.006), "wood_dark")
    g.box((0, 0.085, 0.1015), (0.16, 0.05, 0.004), "paint_red")
    # Rope handles at the ends
    for side in (1.0, -1.0):
        g.rod([(side * 0.172, 0.11, -0.05), (side * 0.20, 0.07, -0.03), (side * 0.20, 0.07, 0.03), (side * 0.172, 0.11, 0.05)], 0.008, "rope", 4)
    g.part("Lid", (0.0, 0.150, -0.100))
    with g.at((0, 0.150, -0.100), pitch=-1.15):
        g.box((0, 0.008, 0.100), (0.34, 0.016, 0.20), "wood")
        g.box((0, 0.017, 0.100), (0.03, 0.004, 0.20), "wood_dark")
    g.part("Body")
    g.solid_box((0, 0.075, 0), (0.34, 0.15, 0.20))


def target_board(g):
    """A knock-down target: a round board painted in rings, on a post hinged at the foot
    of a trestle. Shot, it goes over backwards, and stands up again. The board is 0.5 m
    across, its middle 1.1 m up; it faces +Z."""
    g.box((0, 0.03, 0), (0.50, 0.06, 0.09), "wood_dark")
    g.box((0, 0.03, 0), (0.09, 0.06, 0.50), "wood_dark")
    for side in (1.0, -1.0):
        g.box((side * 0.07, 0.11, 0), (0.03, 0.14, 0.07), "wood_dark")
    g.part("Board", (0.0, 0.12, 0.0))
    g.box((0, 0.50, 0), (0.06, 0.80, 0.035), "wood")
    g.tube([((0, 1.10, -0.012), X * 0.25, Y * 0.25), ((0, 1.10, 0.012), X * 0.25, Y * 0.25)], "wood", 12, smooth=False)
    g.disc((0, 1.10, 0.0125), Z, 0.235, "paint_white", 12)
    g.disc((0, 1.10, 0.0130), Z, 0.165, "paint_red", 12, inner=0.105)
    g.disc((0, 1.10, 0.0130), Z, 0.045, "paint_red", 10)
    g.part("Body")
    g.solid_box((0, 0.05, 0), (0.50, 0.10, 0.50))
    g.solid_box((0, 0.50, 0), (0.07, 0.80, 0.05), "Board")
    g.solid_box((0, 1.10, 0), (0.46, 0.46, 0.04), "Board")
    g.marker("Middle", (0, 1.10, 0.02))


def target_gong(g):
    """A swinging target: an iron plate hung by chains from a wooden frame. Shot, it
    rings and swings. The plate is 0.4 m across, its middle 1.25 m up; it faces +Z."""
    for side in (1.0, -1.0):
        g.box((side * 0.45, 0.03, 0), (0.08, 0.06, 0.60), "wood_dark")
        g.box((side * 0.45, 0.92, 0), (0.06, 1.80, 0.06), "wood")
        g.box((side * 0.45, 0.30, 0.13), (0.04, 0.60, 0.04), "wood_dark", pitch=-0.42)
        g.box((side * 0.45, 0.30, -0.13), (0.04, 0.60, 0.04), "wood_dark", pitch=0.42)
    g.box((0, 1.82, 0), (1.04, 0.07, 0.07), "wood")
    g.part("Board", (0.0, 1.785, 0.0))
    for side in (1.0, -1.0):
        g.rod([(side * 0.13, 1.785, 0), (side * 0.13, 1.40, 0)], 0.006, "iron", 4)
    g.tube([((0, 1.25, -0.008), X * 0.20, Y * 0.20), ((0, 1.25, 0.008), X * 0.20, Y * 0.20)], "iron", 10, smooth=False)
    g.disc((0, 1.25, 0.0085), Z, 0.17, "paint_white", 10, inner=0.12)
    g.disc((0, 1.25, 0.0085), Z, 0.05, "paint_white", 8)
    g.disc((0, 1.25, -0.0085), -Z, 0.17, "paint_white", 10, inner=0.12)
    g.part("Body")
    for side in (1.0, -1.0):
        g.solid_box((side * 0.45, 0.92, 0), (0.08, 1.84, 0.30))
    g.solid_box((0, 1.82, 0), (1.04, 0.07, 0.07))
    g.solid_box((0, 1.25, 0), (0.37, 0.37, 0.03), "Board")
    g.marker("Middle", (0, 1.25, 0.02))


def bottle(g):
    """A wine bottle of dark green glass with a paper label. 0.30 m high; the origin is
    at its middle, where he holds it."""
    with g.at((0, -0.15, 0)):
        g.lathe([(0.030, 0.0), (0.038, 0.012), (0.038, 0.165), (0.026, 0.205), (0.014, 0.235), (0.013, 0.285), (0.016, 0.288), (0.016, 0.300)], "glass", 8,
                bands=("glass", "label", "glass", "glass", "glass", "glass", "glass"))
        g.disc((0, 0.3002, 0), Y, 0.010, "black", 6)
    g.solid_cyl((0, -0.03, 0), 0.038, 0.24)
    g.about = {"mass": 0.8}


def tin_can(g):
    """An empty bully-beef tin. 0.11 m high; the origin is at its middle."""
    with g.at((0, -0.055, 0)):
        g.lathe([(0.040, 0.0), (0.040, 0.030), (0.040, 0.080), (0.040, 0.110)], "tin", 8, bands=("tin", "paint_red", "tin"))
    g.solid_cyl((0, 0, 0), 0.04, 0.11)
    g.about = {"mass": 0.3}


THINGS = [revolver, rifle, shotgun, flare_pistol, ammo_box, target_board, target_gong, bottle, tin_can]


# ---------------------------------------------------------------- writing them out

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
        MADE_MATERIALS[name] = material
    return MADE_MATERIALS[name]


def export(g):
    made_objects = []
    triangles = 0
    used = set()
    low = [1e9] * 3
    high = [-1e9] * 3
    for label, part in g.parts.items():
        if not part["faces"]:
            continue
        pivot = part["pivot"]
        mesh = bpy.data.meshes.new("%s_%s" % (g.name, label.lower()))
        made = bmesh.new()
        # (Godot's x, y, z are Blender's x, -z, y)
        points = [made.verts.new((v.x - pivot.x, -(v.z - pivot.z), v.y - pivot.y)) for v in part["verts"]]
        slots = []
        for indices, material, smooth in part["faces"]:
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
            triangles += len(indices) - 2
        for vert in [v for v in made.verts if not v.link_faces]:
            made.verts.remove(vert)
        made.to_mesh(mesh)
        made.free()
        for name in slots:
            mesh.materials.append(material_for(name))
            used.add(name)
        thing = bpy.data.objects.new(label, mesh)
        thing.location = (pivot.x, -pivot.z, pivot.y)
        bpy.context.collection.objects.link(thing)
        made_objects.append(thing)
        for v in part["verts"]:
            for i in range(3):
                low[i] = min(low[i], v[i])
                high[i] = max(high[i], v[i])
    bpy.ops.object.select_all(action="DESELECT")
    for thing in made_objects:
        thing.select_set(True)
    bpy.context.view_layer.objects.active = made_objects[0]
    bpy.ops.export_scene.gltf(
        filepath=os.path.join(OUT, g.name + ".glb"),
        export_format="GLB",
        export_yup=True,
        export_animations=False,
        use_selection=True,
    )
    for thing in made_objects:
        mesh = thing.data
        bpy.data.objects.remove(thing)
        bpy.data.meshes.remove(mesh)
    print("BUILT %-14s tris=%4d parts=%d materials=%d size=%.3f x %.3f x %.3f" % (
        g.name, triangles, len(made_objects), len(used), high[0] - low[0], high[1] - low[1], high[2] - low[2]))
    return {"solids": g.solids, "markers": g.markers, "pivots": g.pivots, "about": g.about, "triangles": triangles,
            "parts": [label for label, part in g.parts.items() if part["faces"]]}


def main():
    os.makedirs(OUT, exist_ok=True)
    bpy.ops.wm.read_factory_settings(use_empty=True)
    listing = os.path.join(OUT, "guns.json")
    known = {}
    if ONLY and os.path.exists(listing):
        with open(listing) as file:
            known = json.load(file)
    for make in THINGS:
        if ONLY and make.__name__ not in ONLY:
            continue
        g = Model(make.__name__)
        make(g)
        known[g.name] = export(g)
    with open(listing, "w") as file:
        json.dump(known, file, indent=1)
    print("BUILT: %d things listed" % len(known))


main()
