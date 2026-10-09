"""Builds the railway: a locomotive and tender, carriages and wagons, track, and what stands
beside a line. One models/train/<name>.glb each, and models/train/train.json, which says
what is solid in each, where its ladders and markers are, and what turns.
tools/build_train_scenes.gd turns those into props/<name>.tscn.

Run from the project root:
    blender --background --python tools/build_train.py
    blender --background --python tools/build_train.py -- loco tender      # just these
then
    godot --headless --path . --import
    godot --headless --path . --script tools/build_train_scenes.gd

It uses the props' own tools (`Prop` and its shapes, in tools/build_props.py) and is written
the same way: metres, Y up, one function per thing. What differs:

- A vehicle lies along Z with its front towards +Z and its middle at the origin, and stands
  on rails whose tops are `RAIL` above the ground: the ground is y = 0, as for any prop.
- A vehicle is in several pieces. `v.part(name, origin)` is a piece of its own, that the
  game can turn or move: every pair of wheels (`Wheel1`...), the rods (`RodR`, `ConR`,
  `CrossR` and the same with L), a signal's `Arm`, a carriage's `Roof` (hidden while he is
  inside). Everything else is the piece `Body`.
- `v.settings` are properties set on the root of its scene (scripts/train_vehicle.gd):
  how far its buffers are from its middle, the radius of each wheel, its crank.

The Egyptian State Railways of about 1905-1914 are what is aimed at: British-built tender
engines, carriages with clerestories and double roofs and louvred shutters, four-wheeled
goods stock with side buffers and screw couplings. The liveries are a guess (see PROPS.md).
"""

import json
import math
import os
import sys

import bmesh
import bpy
from mathutils import Vector

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.dirname(HERE)
OUT = os.path.join(ROOT, "models", "train")
ONLY = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []

# The props' tools: everything in build_props.py but its last line, which builds the props.
_source = open(os.path.join(HERE, "build_props.py")).read()
_props = {"__file__": os.path.join(HERE, "build_props.py"), "__name__": "build_props"}
exec(compile(_source[:_source.rindex("\nmain()")], "build_props.py", "exec"), _props)
Prop = _props["Prop"]
material_for = _props["material_for"]
SHINY = _props["SHINY"]
both = _props["both"]
X, Y, Z = Vector((1, 0, 0)), Vector((0, 1, 0)), Vector((0, 0, 1))
TAU = math.tau

# Colours of the railway's own, beside the props' (sRGB).
_props["PALETTE"].update({
    "loco_green": (0.13, 0.29, 0.21),
    "loco_black": (0.10, 0.10, 0.11),
    "buffer_red": (0.70, 0.17, 0.12),
    "steel": (0.56, 0.56, 0.58),
    "coal": (0.08, 0.08, 0.09),
    "teak": (0.50, 0.31, 0.18),
    "teak_dark": (0.36, 0.22, 0.13),
    "cream": (0.90, 0.86, 0.74),
    "roof_grey": (0.74, 0.73, 0.69),
    "roof_white": (0.92, 0.91, 0.86),
    "wagon": (0.55, 0.49, 0.41),
    "wagon_dark": (0.40, 0.35, 0.30),
    "wagon_red": (0.52, 0.26, 0.20),
    "louvre": (0.26, 0.40, 0.34),
    "ballast": (0.52, 0.47, 0.41),
    "sleeper": (0.31, 0.24, 0.18),
    "rail": (0.38, 0.31, 0.27),
    "tarp": (0.34, 0.39, 0.33),
    "whitewash": (0.91, 0.88, 0.80),
    "seat": (0.42, 0.17, 0.15),
    "signal_red": (0.78, 0.14, 0.10),
    "lamp_red": (0.90, 0.20, 0.12),
    "lamp_green": (0.20, 0.72, 0.45),
})

## The top of the rails above the ground, and where the middle of a wheel is from the middle of the track.
RAIL = 0.30
WHEEL_X = 0.755
## The floor of a wagon or a carriage, the middle of a buffer, and how far a buffer stands out.
DECK = 1.30
BUFFER = 1.12
BUFFER_OUT = 0.55


class Made(Prop):
    """A prop in several pieces (see the top of the file)."""

    def __init__(self, name, body="static"):
        super().__init__(name, body)
        self.parts = {}
        self.wheels = {}
        self.settings = {}
        self.script = ""
        self.labels = []

    def part(self, name, origin):
        piece = Prop(name)
        self.parts[name] = (piece, Vector(origin))
        return piece

    def label(self, at, text, size=0.3, yaw=0.0, colour=(0.12, 0.1, 0.09)):
        """Words on it, facing +Z turned by `yaw`: a name board."""
        self.labels.append({"at": list(self.m @ Vector(at)), "text": text, "size": size, "yaw": yaw, "colour": list(colour)})

    def solid_lying(self, centre, radius, length):
        """A cylinder lying along Z."""
        self.solids.append({"type": "cylinder", "radius": radius, "height": length, "basis": [[1, 0, 0], [0, 0, 1], [0, -1, 0]],
                            "origin": list(self.m @ Vector(centre))})


# ---------------------------------------------------------------- shared pieces

def xtube(p, x0, x1, r, material, segments=12, caps=True, at=(0.0, 0.0)):
    """A cylinder lying across: from x0 to x1 at (y, z)."""
    y, z = at
    return p.tube([((x0, y, z), Y * r, Z * r), ((x1, y, z), Y * r, Z * r)], material, segments, caps=caps)


def ztube(p, z0, z1, r, material, segments=12, caps=True, at=(0.0, 0.0), r1=None):
    """A cylinder lying along: from z0 to z1 at (x, y)."""
    x, y = at
    r1 = r if r1 is None else r1
    return p.tube([((x, y, z0), X * r, Y * r), ((x, y, z1), X * r1, Y * r1)], material, segments, caps=caps)


def wheelset(v, z, r, spoked=False, crank=0.0):
    """A pair of wheels on their axle, a piece of its own to be turned. A driving wheel is
    spoked and has a crank pin: forward on the right-hand wheel, and a quarter turn on
    (straight down) on the left, as a locomotive's are."""
    name = "Wheel%d" % (len(v.wheels) + 1)
    y = RAIL + r
    w = v.part(name, (0.0, y, z))
    v.wheels[name] = r
    xtube(w, -0.69, 0.69, 0.06, "iron", 6, False, (y, z))
    for s in (-1, 1):
        a, b = s * 0.69, s * 0.82
        if spoked:
            rim = r - 0.1
            w.tube([((a, y, z), Y * r, Z * r), ((b, y, z), Y * r, Z * r), ((b, y, z), Y * rim, Z * rim), ((a, y, z), Y * rim, Z * rim),
                    ((a, y, z), Y * r, Z * r)], "steel", 16, caps=False)
            for k in range(4):
                w.box((s * 0.755, y, z), (0.05, rim * 2.0, 0.075), "wagon_red", pitch=math.pi * k / 4.0)
            xtube(w, s * 0.67, s * 0.86, 0.15, "wagon_red", 8, True, (y, z))
            if crank:
                # (pin and its boss, and a weight in the rim across from it)
                py, pz = (y, z + crank) if s > 0 else (y - crank, z)
                xtube(w, s * 0.80, s * 1.08, 0.055, "steel", 6, True, (py, pz))
                xtube(w, s * 0.70, s * 0.85, 0.12, "loco_black", 6, True, (py, pz))
                w.box((s * 0.755, y, z), (0.07, 0.24, 0.62), "loco_black", pitch=0.0 if s < 0 else math.pi * 0.5)
                # (the weight, moved out to the rim)
                wy, wz = (y, z - (rim - 0.14)) if s > 0 else (y + rim - 0.14, z)
                w.box((s * 0.755, wy, wz), (0.09, 0.26, 0.7), "loco_black", pitch=math.pi * 0.5 if s > 0 else 0.0, top=(1.0, 0.55))
        else:
            xtube(w, a, b, r, "steel", 12, True, (y, z))
            face = [(b + s * 0.004, y + (r - 0.07) * math.cos(TAU * k / 10), z + s * (r - 0.07) * math.sin(TAU * k / 10)) for k in range(10)]
            w.poly(face, "loco_black")
            for k in range(2):
                w.box((b + s * 0.008, y, z), (0.02, (r - 0.09) * 2.0, 0.08), "steel", pitch=math.pi * 0.5 * k)
    return name


def couple(v, z, e, hook=True):
    """Two buffers and a hook with its links, on the end of a frame at `z`, facing `e` (1 the front)."""
    for s in (-1, 1):
        c = Vector((s * 0.87, BUFFER, z))
        v.tube([(c, X * 0.08, Y * 0.08), (c + Z * e * 0.4, X * 0.07, Y * 0.07), (c + Z * e * 0.42, X * 0.18, Y * 0.18),
                (c + Z * e * BUFFER_OUT, X * 0.18, Y * 0.18)], "iron", 8, bands=["iron", "iron", "steel"])
    if hook:
        v.box((0, BUFFER - 0.02, z + e * 0.14), (0.06, 0.16, 0.28), "iron")
        v.box((0, BUFFER - 0.2, z + e * 0.34), (0.05, 0.3, 0.09), "iron", pitch=-e * 0.5)


def underframe(v, half, axles, r=0.48, width=2.5, colour="wagon_dark", front=True, rear=True, deck=DECK):
    """The frame of a wagon: sole bars, head stocks, buffers and couplings, and its wheels in their axle boxes."""
    for s in (-1, 1):
        v.box((s * (width * 0.5 - 0.07), deck - 0.2, 0), (0.12, 0.26, half * 2.0 - 0.2), colour)
    for e, wanted in ((1, front), (-1, rear)):
        v.box((0, deck - 0.2, e * (half - 0.06)), (width, 0.34, 0.12), "buffer_red" if wanted else colour)
        if wanted:
            couple(v, e * half, e)
    for z in axles:
        wheelset(v, z, r)
        for s in (-1, 1):
            v.box((s * 0.93, RAIL + r, z), (0.13, 0.24, 0.26), "iron")
            v.box((s * 0.93, RAIL + r + 0.2, z), (0.07, 0.08, 1.0), "iron", top=(1.0, 0.6))
            v.box((s * (width * 0.5 - 0.07), RAIL + r + 0.3, z), (0.04, 0.5, 0.5), colour, top=(1.0, 2.0))
    v.settings["front"] = half + (BUFFER_OUT if front else 0.0)
    v.settings["rear"] = half + (BUFFER_OUT if rear else 0.0)


def railing(v, a, b, material="iron", high=0.95, solid=True, mid=True):
    """A hand rail on posts from `a` to `b` (points at the level of the floor)."""
    a, b = Vector(a), Vector(b)
    along = b - a
    yaw = math.atan2(along.x, along.z)
    for at in (a, b):
        v.box((at.x, at.y + high * 0.5, at.z), (0.05, high, 0.05), material)
    middle = (a + b) * 0.5
    v.box((middle.x, middle.y + high - 0.02, middle.z), (0.05, 0.05, along.length), material, yaw=yaw)
    if mid:
        v.box((middle.x, middle.y + high * 0.5, middle.z), (0.035, 0.035, along.length), material, yaw=yaw)
    if solid:
        v.solid_box((middle.x, middle.y + high * 0.5, middle.z), (0.06, high, along.length), yaw)


def case(v, centre, size, yaw=0.0, material="wood", band="wood_dark", solid=True):
    """A packing case: a box with two battens round it."""
    with v.at(centre, yaw):
        v.box((0, 0, 0), size, material)
        for z in (-0.3, 0.3):
            v.box((0, 0, z * size[2]), (size[0] + 0.04, size[1] + 0.04, 0.09), band)
        if solid:
            v.solid_box((0, 0, 0), size)


def barrel(v, at, lying=0.0, solid=True):
    """A cask, 0.9 high, stood at `at` (or lying, turned by `lying`)."""
    profile = [(0.26, 0.0), (0.34, 0.25), (0.35, 0.45), (0.34, 0.65), (0.26, 0.9)]
    v.lathe(profile, "wood", 8, centre=at, bands=["iron", "wood", "wood", "iron"])
    if solid:
        v.solid_cyl((at[0], at[1] + 0.45, at[2]), 0.33, 0.9)


def planks(v, centre, size, material, strap="wagon_dark", count=3, along="z"):
    """A boarded panel: a box, with upright straps on its outer faces."""
    v.box(centre, size, material)
    cx, cy, cz = centre
    for k in range(count):
        t = (k + 0.5) / count - 0.5
        if along == "z":
            v.box((cx, cy, cz + t * size[2]), (size[0] + 0.03, size[1], 0.07), strap)
        else:
            v.box((cx + t * size[0], cy, cz), (0.07, size[1], size[2] + 0.03), strap)


# ---------------------------------------------------------------- the locomotive

## The footplate of the engine and of its tender, above the ground.
FOOTPLATE = 1.80
## The crank of the driving wheels (half the stroke), and the length of a connecting rod.
CRANK = 0.30
ROD = 2.3


def loco(v):
    """A 2-6-0 tender engine with outside cylinders, 9.2 m over its beams: green, black
    smokebox, a red buffer beam, a brass dome and chimney cap; a cab closed only at the front."""
    fp = FOOTPLATE
    by = 2.55
    v.settings.update(front=4.6 + BUFFER_OUT, rear=4.72, crank=CRANK, rod=ROD)
    # Frames, and what fills the space between them
    for s in (-1, 1):
        v.box((s * 0.6, 1.2, 0.0), (0.06, 1.1, 9.0), "loco_black")
    v.box((0, 1.3, -0.4), (1.14, 0.7, 7.6), "loco_black")
    # The running plate, its valance, the beams
    v.box((0, fp - 0.04, 1.0), (2.6, 0.08, 7.2), "loco_black")
    for s in (-1, 1):
        v.box((s * 1.27, fp - 0.17, 1.0), (0.05, 0.2, 7.2), "loco_green")
    v.box((0, BUFFER + 0.06, 4.54), (2.6, 0.44, 0.12), "buffer_red")
    couple(v, 4.6, 1)
    v.box((0, BUFFER + 0.06, -4.54), (2.5, 0.44, 0.12), "loco_black")
    # Boiler, firebox, smokebox
    ztube(v, -1.5, 2.6, 0.64, "loco_green", 14, False, (0, by))
    for z in (-0.4, 1.5):
        ztube(v, z - 0.04, z + 0.04, 0.655, "loco_black", 14, False, (0, by))
    v.long(0, [(-2.62, 0.70, fp, 3.25), (-1.5, 0.70, fp, 3.25)], "loco_green", 12, 3.5)
    ztube(v, 2.6, 3.9, 0.69, "loco_black", 14, True, (0, by))
    v.box((0, 2.0, 3.25), (1.1, 0.5, 1.1), "loco_black", top=(0.75, 1.0))
    v.tube([((0, by, 3.9), X * 0.56, Y * 0.56), ((0, by, 3.97), X * 0.42, Y * 0.42)], "loco_black", 12, caps=False, tip1=(0, by, 4.02))
    v.box((0, by, 4.03), (0.05, 0.3, 0.04), "brass")
    for y in (-0.25, 0.25):
        v.box((-0.3, by + y, 3.95), (0.55, 0.05, 0.03), "steel")
    v.lathe([(0.27, 0.0), (0.2, 0.12), (0.17, 0.62), (0.2, 0.78), (0.26, 0.84), (0.26, 0.9)], "loco_black", 10, centre=(0, by + 0.66, 3.3),
            bands=["loco_black", "loco_black", "loco_black", "brass", "brass"])
    v.marker("Chimney", (0, by + 1.56, 3.3))
    v.lathe([(0.37, 0.0), (0.31, 0.12), (0.31, 0.4), (0.24, 0.53), (0.08, 0.6)], "brass", 10, centre=(0, by + 0.6, 0.6))
    for x in (-0.14, 0.14):
        v.lathe([(0.06, 0.0), (0.06, 0.22), (0.09, 0.3)], "brass", 6, centre=(x, 3.25, -2.0))
    v.lathe([(0.03, 0.0), (0.03, 0.2), (0.06, 0.24), (0.06, 0.36)], "brass", 6, centre=(0.45, 3.2, -2.3))
    v.marker("Whistle", (0.45, 3.56, -2.3))
    for s in (-1, 1):
        v.strand([(s * 0.71, 2.8, -2.55), (s * 0.71, 2.8, 3.85)], 0.022, "steel", 4)
    # The cab: a floor, a front with a way through on each side of the firebox, low sides, a roof on two pillars
    v.box((0, fp - 0.05, -3.55), (2.5, 0.1, 2.1), "wood_dark")
    v.box((0, 2.76, -2.6), (1.5, 1.92, 0.06), "loco_green")
    v.box((0, 3.52, -2.6), (2.5, 0.4, 0.06), "loco_green")
    for s in (-1, 1):
        v.box((s * 1.22, 2.56, -2.6), (0.06, 1.52, 0.06), "loco_green")
        v.box((s * 1.22, fp + 0.5, -3.05), (0.06, 1.0, 0.9), "loco_green")
        v.box((s * 1.22, 3.56, -3.55), (0.06, 0.32, 1.9), "loco_green")
        v.box((s * 1.22, 2.76, -4.47), (0.06, 1.92, 0.06), "loco_green")
        v.poly([(s * 1.255, fp + 0.4, -3.05 + s * 0.3), (s * 1.255, fp + 0.4, -3.05 - s * 0.3), (s * 1.255, fp + 0.62, -3.05 - s * 0.3),
                (s * 1.255, fp + 0.62, -3.05 + s * 0.3)], "brass")
        disc_z(v, (s * 0.52, 3.45, -2.56), 0.13, "glass")
        # Steps up to the cab, and a foot step at the front
        for y in (0.6, 1.2):
            v.box((s * 1.14, y, -4.05), (0.34, 0.05, 0.5), "loco_black", True)
        v.box((s * 1.28, 0.95, -4.05), (0.03, 0.8, 0.05), "loco_black")
        v.box((s * 1.14, 1.0, 4.2), (0.3, 0.05, 0.4), "loco_black", True)
        v.solid_box((s * 1.22, fp + 0.5, -3.05), (0.08, 1.0, 0.9))
        v.solid_box((s * 1.0, 3.52, -2.6), (0.5, 0.4, 0.1))
    v.box((0, 3.76, -3.5), (2.7, 0.08, 2.2), "loco_black", top=(0.86, 1.0))
    v.box((0, 3.84, -3.5), (0.7, 0.08, 0.9), "loco_black")
    # The back of the firebox, in the cab
    v.box((0, 2.5, -2.72), (1.3, 1.4, 0.18), "loco_black")
    v.box((0, 2.15, -2.83), (0.4, 0.3, 0.04), "lamp_red")
    for x in (-0.3, 0.3):
        disc_z(v, (x, 2.95, -2.82), 0.09, "brass", back=True)
    v.box((0.25, 2.6, -2.9), (0.5, 0.04, 0.04), "steel", yaw=0.4)
    # Cylinders, their valve chests and slide bars
    for s in (-1, 1):
        ztube(v, 2.75, 3.65, 0.27, "loco_black", 10, True, (s * 1.0, RAIL + 0.72))
        v.box((s * 0.95, 1.5, 3.2), (0.5, 0.5, 0.8), "loco_black")
        for y in (-0.14, 0.14):
            v.box((s * 1.0, RAIL + 0.72 + y, 2.05), (0.07, 0.04, 1.4), "steel")
        v.box((s * 0.82, RAIL + 0.72, 1.4), (0.36, 0.5, 0.06), "loco_black")
        v.marker("Steam" + ("R" if s > 0 else "L"), (s * 1.05, 0.75, 3.7))
    # Lamps: one each side on the beam, one under the chimney
    for at in ((-0.8, BUFFER + 0.4, 4.5), (0.8, BUFFER + 0.4, 4.5), (0, by + 0.82, 3.8)):
        lamp(v, at, 1)
    v.marker("Lamp", (0, by + 0.82, 4.0))
    # Wheels: three coupled pairs and a leading pony truck
    for z in (1.3, -0.5, -2.3):
        wheelset(v, z, 0.72, True, CRANK)
    wheelset(v, 3.35, 0.42)
    v.box((0, RAIL + 0.42, 3.35), (1.3, 0.2, 0.9), "loco_black")
    # Rods, each modelled with its crank pin forward: a coupling rod over the three pins, a
    # connecting rod from the middle one to the crosshead, and the crosshead on its piston rod.
    axle = RAIL + 0.72
    for s, tag in ((1, "R"), (-1, "L")):
        pin = Vector((s * 0.91, axle, -0.5 + CRANK))
        rod = v.part("Rod" + tag, pin)
        rod.box((pin.x, pin.y, pin.z), (0.05, 0.11, 3.84), "steel")
        for z in (-1.8, 0.0, 1.8):
            xtube(rod, pin.x - 0.035, pin.x + 0.035, 0.1, "steel", 8, True, (pin.y, pin.z + z))
        big = Vector((s * 1.0, axle, -0.5 + CRANK))
        con = v.part("Con" + tag, big)
        con.box((big.x, big.y, big.z + ROD * 0.5), (0.05, 0.1, ROD), "steel", top=(1.0, 1.0))
        xtube(con, big.x - 0.04, big.x + 0.04, 0.11, "steel", 8, True, (big.y, big.z))
        small = big + Z * ROD
        cross = v.part("Cross" + tag, small)
        cross.box((small.x, small.y, small.z), (0.1, 0.3, 0.24), "steel")
        ztube(cross, small.z, small.z + 1.1, 0.035, "steel", 6, False, (small.x, small.y))
    # What is solid: the running plate down to the frames, the boiler as a box he can walk along the top of,
    # chimney and dome, the cab's floor, front, sides and roof.
    v.solid_box((0, 1.3, 1.0), (2.6, 1.0, 7.2))
    v.solid_box((0, 1.3, -3.6), (2.5, 1.0, 2.0))
    v.solid_box((0, 2.5, 0.65), (1.2, 1.4, 6.5))
    v.solid_cyl((0, by + 1.1, 3.3), 0.22, 0.9)
    v.solid_cyl((0, by + 0.9, 0.6), 0.3, 0.5)
    v.solid_box((0, 2.76, -2.6), (1.5, 1.92, 0.1))
    v.solid_box((0, 3.76, -3.5), (2.6, 0.08, 2.2))


def disc_z(v, at, r, material, n=10, back=False):
    """A flat disc facing +Z (or -Z)."""
    points = [(at[0] + r * math.cos(TAU * k / n), at[1] + r * math.sin(TAU * k / n), at[2]) for k in range(n)]
    v.poly(points[::-1] if back else points, material)
    v.poly(points if back else points[::-1], material)


def lamp(v, at, e, glass="glass"):
    """An oil lamp: a black case with a lens towards `e` along Z."""
    v.box(at, (0.17, 0.22, 0.17), "loco_black")
    v.box((at[0], at[1] + 0.14, at[2]), (0.08, 0.07, 0.08), "loco_black")
    points = [(at[0] + 0.065 * math.cos(TAU * k / 8), at[1] + 0.065 * math.sin(TAU * k / 8), at[2] + e * 0.09) for k in range(8)]
    v.poly(points if e > 0 else points[::-1], glass)


def tender(v):
    """A six-wheeled tender, 5.8 m: a tank with coal heaped in the front of it, which he walks up and over."""
    fp = FOOTPLATE
    underframe(v, 2.9, [-1.9, 0.0, 1.9], 0.5, 2.5, "loco_black", front=False, deck=1.3)
    v.settings["front"] = 3.02
    v.box((0, 2.0, -0.35), (2.5, 1.5, 5.1), "loco_green")
    for s in (-1, 1):
        v.box((s * 1.22, 2.9, -0.35), (0.06, 0.3, 5.1), "loco_green", shift=(s * 0.09, 0.0))
        v.box((s * 1.26, 2.0, -0.35), (0.02, 1.1, 4.5), "loco_black")
    v.box((0, 2.9, -2.87), (2.5, 0.3, 0.06), "loco_green", shift=(0.0, -0.09))
    # The front: the plate he stands on, the coal door, a tool box and the brake column
    v.box((0, 1.55, 2.6), (2.5, 0.5, 1.0), "loco_black")
    v.box((0, 1.95, 2.17), (2.4, 0.34, 0.05), "loco_black")
    v.box((-0.95, fp + 0.2, 2.7), (0.5, 0.4, 0.6), "wood_dark", True)
    v.lathe([(0.04, 0.0), (0.04, 0.9), (0.18, 0.92), (0.18, 0.96)], "steel", 6, centre=(0.95, fp, 2.8))
    # Coal: a rough heap, low at the front and highest in the middle
    rows = [2.15, 1.5, 0.8, 0.0, -1.0, -1.7]
    high = [2.1, 2.6, 3.0, 3.06, 2.95, 2.7]
    across = [-1.18, -0.6, 0.0, 0.6, 1.18]
    grid = []
    for j, z in enumerate(rows):
        line = []
        for i, x in enumerate(across):
            edge = 0.16 if i in (0, 4) and j < 5 else 0.0
            line.append(v.v((x, high[j] - edge + 0.09 * math.sin(i * 2.3 + j * 1.7), z + 0.08 * math.sin(i * 1.3 + j))))
        grid.append(line)
    for j in range(len(rows) - 1):
        for i in range(len(across) - 1):
            v.face((grid[j][i], grid[j][i + 1], grid[j + 1][i + 1]), "coal")
            v.face((grid[j][i], grid[j + 1][i + 1], grid[j + 1][i]), "coal")
    # The tank top behind the coal: a filler, and a ladder up the back
    v.lathe([(0.26, 0.0), (0.26, 0.12), (0.2, 0.15)], "loco_black", 8, centre=(0, 2.75, -2.0))
    v.ladder((0.3, 0.2, -2.93), 2.55, math.pi)
    for at in ((-0.8, 2.3, -2.93),):
        lamp(v, at, -1, "lamp_red")
    v.solid_box((0, 1.875, -0.35), (2.5, 1.75, 5.1))
    v.solid_box((0, 1.4, 2.65), (2.5, 0.8, 0.95))
    v.solid_hull([(x, y, z) for x in (-1.2, 1.2) for y, z in ((1.9, 2.15), (2.1, 2.15), (3.0, 0.8), (3.0, -1.0), (2.74, -1.7), (1.9, -1.7))])


# ---------------------------------------------------------------- carriages

def coach(v, body, veranda, wall, low, trim, roof, clerestory, axles, bogies, bays, seats_across):
    """A carriage with an open platform at each end: `body` and `veranda` are half the length
    of the saloon and the depth of a platform. He goes in at either end door and through it
    between the seats; a ladder on each end wall goes up through a gap in the canopy to the
    roof, which he runs along. The roof is a piece of its own, hidden while he is inside."""
    half = body + veranda
    top = 3.5
    underframe(v, half, [] if bogies else axles, 0.48, 2.6, "wagon_dark")
    if bogies:
        for centre in bogies:
            for z in (-0.9, 0.9):
                wheelset(v, centre + z, 0.46)
            for s in (-1, 1):
                v.box((s * 0.95, RAIL + 0.5, centre), (0.1, 0.3, 2.6), "iron")
                for z in (-0.9, 0.9):
                    v.box((s * 0.95, RAIL + 0.46, centre + z), (0.14, 0.26, 0.3), "wagon_dark")
            v.box((0, RAIL + 0.66, centre), (1.9, 0.14, 0.4), "iron")
        # (truss rods under the frame)
        for s in (-1, 1):
            v.strand([(s * 1.1, 1.05, -body * 0.6), (s * 1.1, 0.72, -body * 0.2), (s * 1.1, 0.72, body * 0.2), (s * 1.1, 1.05, body * 0.6)], 0.025, "iron", 4)
    v.box((0, DECK - 0.04, 0), (2.6, 0.08, half * 2.0), "wood_dark")
    v.solid_box((0, DECK - 0.15, 0), (2.6, 0.3, half * 2.0))
    # Sides: a panel below the windows, a rail above them, pillars between, and a louvred shutter let down over the top of each window
    span = body * 2.0 / bays
    for s in (-1, 1):
        v.box((s * 1.26, 1.78, 0), (0.08, 0.96, body * 2.0), low)
        v.box((s * 1.26, 3.225, 0), (0.08, 0.35, body * 2.0), wall)
        v.box((s * 1.305, 2.24, 0), (0.03, 0.06, body * 2.0), trim)
        for k in range(bays + 1):
            v.box((s * 1.26, 2.65, -body + k * span), (0.08, 0.8, 0.26 if 0 < k < bays else 0.13 * 2), wall)
        for k in range(bays):
            z = -body + (k + 0.5) * span
            drop = 0.62 if (k + (0 if s > 0 else 1)) % 3 == 0 else 0.3
            v.box((s * 1.25, 3.05 - drop * 0.5, z), (0.04, drop, span - 0.26), "louvre")
            for i in range(int(drop / 0.1)):
                y = 3.0 - i * 0.1
                v.poly([(s * 1.275, y, z - s * (span * 0.5 - 0.16)), (s * 1.275, y, z + s * (span * 0.5 - 0.16)),
                        (s * 1.3, y - 0.07, z + s * (span * 0.5 - 0.16)), (s * 1.3, y - 0.07, z - s * (span * 0.5 - 0.16))], trim)
        # (a sunshade along the eave)
        v.box((s * 1.47, 3.2, 0), (0.36, 0.03, body * 2.0), trim, roll=-s * 0.45)
        v.solid_box((s * 1.26, 2.35, 0), (0.08, 2.1, body * 2.0))
        # Steps down from each platform
        for e in (-1, 1):
            for y, out in ((0.5, 1.42), (0.9, 1.34)):
                v.box((s * out, y, e * (body + veranda * 0.5)), (0.28, 0.04, 0.7), "wagon_dark", True)
    # Ends: a doorway in the middle, its door open back against the wall inside; the platform's rail, open in the middle
    for e in (-1, 1):
        z = e * body
        for s in (-1, 1):
            v.box((s * 0.875, 2.35, z), (0.85, 2.1, 0.08), wall, True)
            railing(v, (s * 1.25, DECK, e * (half - 0.05)), (s * 0.5, DECK, e * (half - 0.05)), "iron")
            v.box((s * 1.25, DECK + 1.0, e * (body + 0.06)), (0.05, 2.0, 0.05), "iron")
        v.box((0, 3.225, z), (0.9, 0.35, 0.08), wall, True)
        v.box((-e * 0.46, 2.15, z - e * 0.5), (0.05, 1.7, 0.86), trim)
        v.strand([(-0.5, DECK + 0.8, e * (half - 0.05)), (0, DECK + 0.62, e * (half - 0.05)), (0.5, DECK + 0.8, e * (half - 0.05))], 0.015, "iron", 3)
        v.ladder((e * 0.9, DECK, e * (body + 0.05)), top - DECK, 0.0 if e > 0 else math.pi)
    # Inside: seats and luggage racks
    for s in (-1, 1):
        if seats_across:
            deep = 0.82
            for k in range(bays):
                z = -body + (k + 0.5) * span
                v.box((s * (1.22 - deep * 0.5), DECK + 0.4, z), (deep, 0.1, 0.5), "seat")
                v.box((s * (1.22 - deep * 0.5), DECK + 0.2, z), (deep - 0.1, 0.4, 0.4), "teak_dark")
                v.box((s * (1.22 - deep * 0.5), DECK + 0.75, z - 0.27), (deep, 0.7, 0.07), "seat")
            v.solid_box((s * (1.22 - deep * 0.5), DECK + 0.225, 0), (deep, 0.45, body * 2.0 - 1.2))
        else:
            v.box((s * 1.0, DECK + 0.4, 0), (0.44, 0.06, body * 2.0 - 1.4), "teak")
            v.box((s * 1.0, DECK + 0.2, 0), (0.36, 0.4, body * 2.0 - 1.5), "teak_dark")
            v.solid_box((s * 1.0, DECK + 0.215, 0), (0.44, 0.43, body * 2.0 - 1.4))
        v.box((s * 1.05, 2.95, 0), (0.36, 0.03, body * 2.0 - 0.6), "brass")
    for k, at in enumerate(((0.95, 3.03, body * 0.5), (-1.0, 3.03, -body * 0.3))):
        v.box(at, (0.3, 0.2, 0.6 + 0.2 * k), "leather")
    # The roof: a piece of its own. A canopy runs out over each platform, cut away at one corner where the ladder comes up.
    r = v.part("Roof", (0, 0, 0))
    r.box((0, top - 0.06, 0), (2.9, 0.12, body * 2.0 + 0.1), roof, top=(0.93, 1.0))
    v.solid_box((0, top - 0.05, 0), (2.8, 0.1, body * 2.0))
    out = veranda - 0.2
    for e in (-1, 1):
        r.box((-e * 0.45, top - 0.06, e * (body + out * 0.5)), (1.9, 0.12, out), roof)
        v.solid_box((-e * 0.45, top - 0.05, e * (body + out * 0.5)), (1.9, 0.1, out))
        r.box((e * 0.5, 2.9, e * (half - 0.25)), (0.05, 1.1 - 0.1, 0.05), "iron")
    if clerestory:
        long = body * 2.0 - 1.0
        r.box((0, top + 0.13, 0), (1.0, 0.26, long), wall)
        r.box((0, top + 0.275, 0), (1.3, 0.05, long + 0.3), roof, top=(0.9, 1.0))
        for s in (-1, 1):
            for k in range(bays):
                z = (k + 0.5 - bays * 0.5) * (long / bays)
                r.box((s * 0.5, top + 0.13, z), (0.03, 0.14, long / bays - 0.3), "glass")
        v.solid_box((0, top + 0.15, 0), (1.3, 0.3, long + 0.3))
        v.settings["roof_top"] = top + 0.3
    else:
        # (a second skin over the first, with air between: the sun is kept off the roof)
        r.box((0, top + 0.2, 0), (3.0, 0.05, body * 2.0 + 0.3), "roof_white", top=(0.92, 1.0))
        for z in (-body + 0.3, -body * 0.33, body * 0.33, body - 0.3):
            r.box((0, top + 0.09, z), (2.4, 0.18, 0.08), "wagon_dark")
        v.solid_box((0, top + 0.11, 0), (2.9, 0.22, body * 2.0 + 0.2))
        v.settings["roof_top"] = top + 0.22
    # (where he is inside: the roof is hidden while he is here)
    v.settings["inside"] = [-1.25, DECK, -body, 2.5, top - DECK - 0.2, body * 2.0]


def carriage(v):
    """A first-class bogie carriage, 13 m: white, with a clerestory, louvred shutters and a sunshade along the eaves."""
    coach(v, 5.4, 1.1, "cream", "cream", "teak", "roof_grey", True, [], (-4.3, 4.3), 7, True)


def carriage_third(v):
    """A third-class six-wheeler, 9.4 m: teak, with a double roof and benches down the sides."""
    coach(v, 3.6, 1.1, "teak", "teak_dark", "teak_dark", "roof_grey", False, [-2.9, 0.0, 2.9], None, 5, False)


# ---------------------------------------------------------------- goods stock

def van_goods(v):
    """A covered goods van, 6.4 m: boarded, its doors slid open on both sides, cases and sacks inside. A ladder up the back."""
    half, top = 3.2, 3.3
    underframe(v, half, [-1.8, 1.8])
    v.box((0, DECK - 0.04, 0), (2.5, 0.08, half * 2.0), "wood_dark")
    v.solid_box((0, DECK - 0.15, 0), (2.5, 0.3, half * 2.0))
    for s in (-1, 1):
        for z in (-2.05, 2.05):
            planks(v, (s * 1.21, 2.25, z), (0.08, 1.9, 2.3), "wagon", count=2)
            v.solid_box((s * 1.21, 2.25, z), (0.08, 1.9, 2.3))
            v.strand([(s * 1.26, DECK + 0.05, z - 1.1), (s * 1.26, 3.15, z + 1.1)], 0.03, "wagon_dark", 4)
        v.box((s * 1.21, 3.25, 0), (0.08, 0.1, half * 2.0), "wagon_dark", True)
        # (the door, slid back along its rail)
        planks(v, (s * 1.29, 2.22, 2.0), (0.05, 1.84, 1.84), "wagon", count=2)
        v.box((s * 1.29, 3.17, 1.0), (0.04, 0.05, 4.0), "iron")
    for e in (-1, 1):
        planks(v, (0, 2.25, e * (half - 0.04)), (2.5, 1.9, 0.08), "wagon", count=3, along="x")
        v.solid_box((0, 2.25, e * (half - 0.04)), (2.5, 1.9, 0.08))
    v.box((0, top - 0.05, 0), (2.7, 0.14, half * 2.0 + 0.16), "roof_grey", top=(0.9, 1.0))
    v.solid_box((0, top - 0.05, 0), (2.7, 0.14, half * 2.0 + 0.16))
    v.settings["roof_top"] = top + 0.02
    case(v, (-0.6, DECK + 0.4, -2.3), (0.9, 0.8, 0.9), 0.1)
    case(v, (0.5, DECK + 0.3, -2.4), (0.8, 0.6, 0.7), -0.2)
    case(v, (0.5, DECK + 0.85, -2.45), (0.6, 0.5, 0.6), 0.3)
    case(v, (0.55, DECK + 0.45, 2.3), (1.0, 0.9, 1.1), 0.0)
    for at in ((-0.6, DECK + 0.16, 2.3), (-0.65, DECK + 0.45, 2.45), (-0.5, DECK + 0.16, 1.5)):
        v.ellipsoid(at, (0.32, 0.17, 0.48), "canvas", 6, 4)
    v.solid_box((-0.6, DECK + 0.3, 2.1), (0.8, 0.6, 1.7))
    v.ladder((0.3, 0.2, -half - 0.03), top + 0.02 - 0.2, math.pi)


def open_wagon(v, load):
    half, side = 3.2, 0.85
    underframe(v, half, [-1.8, 1.8])
    v.box((0, DECK - 0.04, 0), (2.5, 0.08, half * 2.0), "wood_dark")
    v.solid_box((0, DECK - 0.15, 0), (2.5, 0.3, half * 2.0))
    for s in (-1, 1):
        planks(v, (s * 1.21, DECK + side * 0.5, 0), (0.08, side, half * 2.0), "wagon", count=6)
        v.solid_box((s * 1.21, DECK + side * 0.5, 0), (0.08, side, half * 2.0))
    for e in (-1, 1):
        planks(v, (0, DECK + side * 0.5, e * (half - 0.04)), (2.5, side, 0.08), "wagon", count=3, along="x")
        v.solid_box((0, DECK + side * 0.5, e * (half - 0.04)), (2.5, side, 0.08))
    if load == "goods":
        case(v, (-0.55, DECK + 0.45, 2.3), (0.9, 0.9, 0.9), 0.15)
        case(v, (0.5, DECK + 0.4, 2.2), (0.8, 0.8, 1.2), -0.1)
        case(v, (0.0, DECK + 1.15, 2.3), (0.9, 0.6, 0.8), 0.5)
        case(v, (-0.5, DECK + 0.35, 0.9), (1.0, 0.7, 0.9), 0.0)
        for at in ((0.6, DECK, 0.5), (0.65, DECK, -0.3), (-0.1, DECK, -0.5), (-0.75, DECK, -0.2)):
            barrel(v, at)
        for k, at in enumerate(((-0.5, DECK + 0.17, -2.2), (0.3, DECK + 0.17, -2.3), (-0.1, DECK + 0.48, -2.25), (0.75, DECK + 0.17, -1.5))):
            v.ellipsoid(at, (0.3, 0.17, 0.48), "canvas", 6, 4)
        v.solid_box((-0.05, DECK + 0.32, -2.2), (1.4, 0.64, 1.0))
    else:
        # A load under a tarpaulin roped down, and a crated coffin from the dig, its gilded lid showing between the slats
        v.tube([((0, DECK + 0.02, 2.75), X * 1.1, Y * 0.02), ((0, DECK + 0.5, 2.6), X * 1.12, Y * 0.5), ((0, DECK + 0.7, 1.6), X * 1.0, Y * 0.72),
                ((0, DECK + 0.55, 0.7), X * 1.12, Y * 0.55), ((0, DECK + 0.02, 0.5), X * 1.1, Y * 0.02)], "tarp", 8, 3.0, caps=False, smooth=False)
        for z in (1.1, 2.2):
            v.tube([((0, DECK + 0.62, z), X * 1.1, Y * 0.72), ((0, DECK + 0.62, z + 0.05), X * 1.1, Y * 0.72)], "rope", 8, 3.0, caps=False)
        v.solid_box((0, DECK + 0.6, 1.65), (2.1, 1.2, 2.0))
        with v.at((0.1, DECK, -1.5), 0.06):
            v.box((0, 0.42, 0), (0.8, 0.7, 2.3), "gilt", top=(0.8, 0.92))
            v.box((0, 0.42, 0.7), (0.84, 0.74, 0.14), "lapis")
            v.box((0, 0.42, -0.2), (0.84, 0.74, 0.1), "lapis")
            for y in (0.1, 0.42, 0.74):
                for s in (-1, 1):
                    v.box((s * 0.5, y, 0), (0.05, 0.16, 2.6), "wood")
            for z in (-1.25, -0.4, 0.45, 1.25):
                v.box((0, 0.45, z), (1.1, 0.9, 0.09), "wood_dark")
                v.box((0, 0.9, z), (1.1, 0.06, 0.16), "wood")
            v.box((0, 0.04, 0), (1.1, 0.08, 2.6), "wood")
            v.solid_box((0, 0.46, 0), (1.1, 0.92, 2.6))
        barrel(v, (-0.85, DECK, -0.1))


def wagon_open(v):
    """An open wagon, 6.4 m, its sides 0.85 m high: cases, casks and sacks."""
    open_wagon(v, "goods")


def wagon_finds(v):
    """An open wagon from the dig: a load roped under a tarpaulin, and a gilded coffin in a crate."""
    open_wagon(v, "finds")


def wagon_flat(v):
    """A flat wagon, 7 m: a bare deck with stanchions, and a few baulks of timber chained down at one end."""
    half = 3.5
    underframe(v, half, [-2.0, 2.0])
    v.box((0, DECK - 0.04, 0), (2.5, 0.08, half * 2.0), "wood")
    v.solid_box((0, DECK - 0.15, 0), (2.5, 0.3, half * 2.0))
    for s in (-1, 1):
        for z in (-3.0, -1.0, 1.0, 3.0):
            v.box((s * 1.2, DECK + 0.3, z), (0.07, 0.6, 0.07), "iron")
    for k, (x, y) in enumerate(((-0.6, 0.1), (-0.2, 0.1), (0.2, 0.1), (0.6, 0.1), (-0.4, 0.3), (0.0, 0.3))):
        v.box((x, DECK + y, -2.0 + 0.05 * k), (0.34, 0.2, 2.4), "wood" if k % 2 else "trunk")
    v.box((0, DECK + 0.42, -2.0), (1.7, 0.03, 0.08), "iron")
    v.solid_box((0, DECK + 0.1, -2.0), (1.7, 0.2, 2.6))
    v.solid_box((-0.2, DECK + 0.3, -2.0), (0.8, 0.2, 2.5))


def wagon_tank(v):
    """A tank wagon, 6.4 m: a round tank he can only stand on along its top. A filler in the middle; saddles and straps."""
    half, r = 3.2, 1.02
    cy = DECK + 0.12 + r
    underframe(v, half, [-1.8, 1.8])
    v.box((0, DECK - 0.04, 0), (2.5, 0.08, half * 2.0), "wagon_dark")
    v.solid_box((0, DECK - 0.15, 0), (2.5, 0.3, half * 2.0))
    v.tube([((0, cy, -2.75), X * r * 0.8, Y * r * 0.8), ((0, cy, -2.65), X * r, Y * r), ((0, cy, 2.65), X * r, Y * r), ((0, cy, 2.75), X * r * 0.8, Y * r * 0.8)],
           "loco_black", 14, tip0=(0, cy, -2.82), tip1=(0, cy, 2.82), caps=False)
    for z in (-1.6, 0.0, 1.6):
        ztube(v, z - 0.04, z + 0.04, r + 0.015, "iron", 14, False, (0, cy))
    for z in (-1.8, 1.8):
        v.box((0, DECK + 0.25, z), (1.9, 0.5, 0.3), "wood_dark", top=(0.55, 1.0))
    v.lathe([(0.36, 0.0), (0.36, 0.26), (0.3, 0.32), (0.1, 0.34)], "loco_black", 10, centre=(0, cy + r - 0.04, 0))
    for e in (-1, 1):
        v.box((0, DECK + 0.6, e * 3.0), (2.3, 1.2, 0.08), "wagon_dark")
        v.solid_box((0, DECK + 0.6, e * 3.0), (2.3, 1.2, 0.08))
    v.solid_lying((0, cy, 0), r, 5.6)
    v.solid_cyl((0, cy + r + 0.12, 0), 0.36, 0.3)
    v.settings["roof_top"] = cy + r


def van_brake(v):
    """A brake van, 6.8 m: a cabin with look-outs, and a platform at the back with the brake wheel and a ladder to the roof."""
    half, top, back = 3.4, 3.35, -2.2
    underframe(v, half, [-2.0, 2.0])
    v.box((0, DECK - 0.04, 0), (2.5, 0.08, half * 2.0), "wood_dark")
    v.solid_box((0, DECK - 0.15, 0), (2.5, 0.3, half * 2.0))
    middle = (half + back) * 0.5
    long = half - back
    for s in (-1, 1):
        planks(v, (s * 1.21, 2.25, middle), (0.08, 1.9, long), "wagon_red", "wagon_dark", 5)
        v.solid_box((s * 1.21, 2.25, middle), (0.08, 1.9, long))
        # (a look-out standing out from the side, with a window fore and aft)
        v.box((s * 1.36, 2.6, 1.0), (0.26, 1.0, 0.8), "wagon_red")
        for e in (-1, 1):
            v.poly([(s * 1.3, 2.55, 1.0 + e * 0.405), (s * 1.46, 2.55, 1.0 + e * 0.405), (s * 1.46, 2.95, 1.0 + e * 0.405),
                    (s * 1.3, 2.95, 1.0 + e * 0.405)][::(1 if s * e > 0 else -1)], "glass")
        lamp(v, (s * 1.34, 2.6, back - 0.1), -1, "lamp_red")
    planks(v, (0, 2.25, half - 0.04), (2.5, 1.9, 0.08), "wagon_red", "wagon_dark", 3, "x")
    v.solid_box((0, 2.25, half - 0.04), (2.5, 1.9, 0.08))
    # The back wall, with its doorway onto the platform
    for s in (-1, 1):
        v.box((s * 0.85, 2.25, back), (0.8, 1.9, 0.08), "wagon_red", True)
        v.box((s * 1.2, DECK + 1.0, -half + 0.06), (0.06, 2.0, 0.06), "wagon_dark")
    v.box((0, 3.1, back), (0.9, 0.2, 0.08), "wagon_red", True)
    railing(v, (-1.2, DECK, -half + 0.05), (1.2, DECK, -half + 0.05), "iron")
    v.lathe([(0.04, 0.0), (0.04, 1.0), (0.2, 1.02), (0.2, 1.06)], "steel", 8, centre=(-0.8, DECK, back - 0.7))
    lamp(v, (0, DECK + 0.75, -half - 0.05), -1, "lamp_red")
    # Inside: a bench and a stove, whose pipe goes up through the roof
    v.box((-0.9, DECK + 0.25, 2.2), (0.5, 0.5, 1.6), "wood", True)
    v.lathe([(0.2, 0.0), (0.22, 0.5), (0.1, 0.6), (0.06, 0.62), (0.06, 2.4), (0.1, 2.42), (0.1, 2.5)], "loco_black", 6, centre=(0.85, DECK, 2.6))
    v.solid_cyl((0.85, DECK + 0.3, 2.6), 0.22, 0.6)
    v.box((0, top - 0.05, middle), (2.7, 0.14, long + 0.16), "roof_grey", top=(0.9, 1.0))
    v.solid_box((0, top - 0.05, middle), (2.7, 0.14, long + 0.16))
    # (the roof runs out over the platform, but for the corner the ladder comes up through)
    out = -half - back
    v.box((-0.45, top - 0.05, back + out * 0.5 + 0.15), (1.8, 0.14, -out - 0.3), "roof_grey")
    v.solid_box((-0.45, top - 0.05, back + out * 0.5 + 0.15), (1.8, 0.14, -out - 0.3))
    v.ladder((0.85, DECK, back - 0.05), top + 0.02 - DECK, math.pi)
    v.settings["roof_top"] = top + 0.02


# ---------------------------------------------------------------- track

## How far apart sleepers are, and the radius and the angle of a curved length.
SLEEPERS = 0.75
CURVE = 40.0
TURN = math.radians(15.0)


def sleeper(v, wide=2.5):
    v.box((0, 0.12, 0), (wide, 0.12, 0.25), "sleeper")


def track_straight(v):
    """Ten metres of line: rails on sleepers on ballast. Its middle is the origin; it runs along Z."""
    v.box((0, 0.05, 0), (3.5, 0.1, 10.0), "ballast", top=(0.78, 1.0))
    for k in range(13):
        with v.at((0, 0, -4.5 + k * SLEEPERS)):
            sleeper(v)
    for s in (-1, 1):
        v.box((s * 0.7175, 0.24, 0), (0.07, 0.12, 10.0), "rail", sides="rail")
        v.poly([(s * 0.7175 - 0.03, 0.302, 5.0), (s * 0.7175 - 0.03, 0.302, -5.0), (s * 0.7175 + 0.03, 0.302, -5.0), (s * 0.7175 + 0.03, 0.302, 5.0)][::-1], "steel")
    v.solid_hull([(x, y, z) for x, y in ((-1.75, 0.0), (1.75, 0.0), (-1.3, 0.2), (1.3, 0.2)) for z in (-5.0, 5.0)])
    v.far = 260.0
    v.shadow = False


def along_curve(a, across=0.0):
    """A point on the curved length, `a` round it and `across` to the right of its middle."""
    return Vector((CURVE - (CURVE - across) * math.cos(a), 0.0, (CURVE - across) * math.sin(a)))


def curved_rails(v, a0, a1, steps, y=0.18):
    for s in (-1, 1):
        for k in range(steps):
            b0, b1 = a0 + (a1 - a0) * k / steps, a0 + (a1 - a0) * (k + 1) / steps
            near = [along_curve(b0, s * 0.7175 - 0.035), along_curve(b0, s * 0.7175 + 0.035)]
            far = [along_curve(b1, s * 0.7175 - 0.035), along_curve(b1, s * 0.7175 + 0.035)]
            lift = Y * (y + 0.12)
            v.poly([near[0] + lift, near[1] + lift, far[1] + lift, far[0] + lift][::-1], "steel")
            v.poly([near[0] + Y * y, near[0] + lift, far[0] + lift, far[0] + Y * y][::-1], "rail")
            v.poly([near[1] + Y * y, far[1] + Y * y, far[1] + lift, near[1] + lift][::-1], "rail")


def track_curve(v):
    """A curved length: 15 degrees of a circle of 40 m, 10.5 m long. It starts at the origin going along +Z and bears right
    (towards +X); the marker `End` is where the next length begins, turned 15 degrees."""
    steps = 6
    for k in range(steps):
        a0, a1 = TURN * k / steps, TURN * (k + 1) / steps
        low = [along_curve(a0, -1.75), along_curve(a0, 1.75), along_curve(a1, 1.75), along_curve(a1, -1.75)]
        high = [along_curve(a0, -1.36) + Y * 0.1, along_curve(a0, 1.36) + Y * 0.1, along_curve(a1, 1.36) + Y * 0.1, along_curve(a1, -1.36) + Y * 0.1]
        v.poly(high[::-1], "ballast")
        v.poly([low[0], high[0], high[3], low[3]][::-1], "ballast")
        v.poly([low[1], low[2], high[2], high[1]][::-1], "ballast")
        v.solid_hull(low + [p + Y * 0.1 for p in high])
    count = int(CURVE * TURN / SLEEPERS)
    for k in range(count):
        a = TURN * (k + 0.5) / count
        with v.at(along_curve(a), a):
            sleeper(v)
    curved_rails(v, 0.0, TURN, steps)
    v.marker("End", along_curve(TURN))
    v.far = 260.0
    v.shadow = False


def track_points(v):
    """A turnout, 20 m: the straight road runs along Z through the origin, and a road bears away to the right from 8 m
    behind it (the marker `Branch` is where that one leaves, 4.3 m to the side and turned 26.7 degrees). A lever and its weight."""
    v.box((0, 0.05, 0), (3.5, 0.1, 20.0), "ballast", top=(0.78, 1.0))
    v.solid_hull([(x, y, z) for x, y in ((-1.75, 0.0), (1.75, 0.0), (-1.3, 0.2), (1.3, 0.2)) for z in (-10.0, 10.0)])
    end = math.asin(18.0 / CURVE)
    with v.at((0, 0, -8.0)):
        steps = 8
        for k in range(steps):
            a0, a1 = end * k / steps, end * (k + 1) / steps
            low = [along_curve(a0, -1.75), along_curve(a0, 1.75), along_curve(a1, 1.75), along_curve(a1, -1.75)]
            high = [p + Y * 0.098 for p in (along_curve(a0, -1.36), along_curve(a0, 1.36), along_curve(a1, 1.36), along_curve(a1, -1.36))]
            v.poly(high[::-1], "ballast")
            v.poly([low[1], low[2], high[2], high[1]][::-1], "ballast")
            if k > 2:
                v.solid_hull(low + [p + Y * 0.1 for p in high])
        curved_rails(v, 0.0, end, steps)
        count = int(CURVE * end / SLEEPERS)
        for k in range(count):
            a = end * (k + 0.5) / count
            at = along_curve(a)
            if at.x > 2.3:
                with v.at(at, a):
                    sleeper(v)
        v.marker("Branch", along_curve(end))
    for k in range(27):
        z = -9.6 + k * SLEEPERS
        # (the timbers lengthen to carry both roads, until the roads are far enough apart for sleepers of their own)
        a = math.asin(max(z + 8.0, 0.0) / CURVE)
        reach = CURVE - CURVE * math.cos(a)
        extra = reach if reach <= 2.3 else 0.0
        with v.at((extra * 0.5, 0, z)):
            sleeper(v, 2.5 + extra)
    for s in (-1, 1):
        v.box((s * 0.7175, 0.24, 0), (0.07, 0.12, 20.0), "rail")
        v.poly([(s * 0.7175 - 0.03, 0.302, 10.0), (s * 0.7175 - 0.03, 0.302, -10.0), (s * 0.7175 + 0.03, 0.302, -10.0), (s * 0.7175 + 0.03, 0.302, 10.0)][::-1], "steel")
    # The lever, beside the toe of the blades
    v.box((-1.9, 0.1, -8.0), (0.5, 0.2, 0.9), "sleeper", True)
    v.box((-1.9, 0.55, -8.0), (0.05, 0.9, 0.05), "iron", pitch=0.35)
    v.lathe([(0.14, 0.0), (0.14, 0.12)], "white", 8, centre=(-1.9, 0.7, -7.55))
    v.box((-1.0, 0.2, -8.0), (1.6, 0.04, 0.05), "iron")
    v.far = 260.0
    v.shadow = False


def buffer_stop(v):
    """The end of a line: a red beam on a frame of old rail and timber, at the height of the buffers. It faces -Z (a train comes at it from there)."""
    for s in (-1, 1):
        v.box((s * 0.72, 0.65, 0.0), (0.1, 1.3, 0.12), "rail")
        v.strand([(s * 0.72, 0.3, 1.5), (s * 0.72, 1.2, 0.05)], 0.05, "rail", 4)
        v.box((s * 0.72, 0.28, 0.8), (0.1, 0.1, 1.6), "rail")
    v.box((0, BUFFER, -0.12), (2.4, 0.3, 0.2), "buffer_red")
    for s in (-1, 1):
        v.box((s * 0.87, BUFFER, -0.23), (0.34, 0.26, 0.03), "white")
    v.box((0, 0.3, 1.6), (2.6, 0.5, 0.5), "sleeper", True)
    lamp(v, (0, BUFFER + 0.3, -0.12), -1, "lamp_red")
    v.solid_box((0, 0.7, -0.05), (2.4, 1.4, 0.3))


# ---------------------------------------------------------------- beside the line

## How far apart telegraph poles stand: each carries its wires on to the next one along +Z.
POLE_SPAN = 30.0


def telegraph_pole(v):
    """A telegraph pole, 7 m, with two arms of insulators, and its four wires as far as the next pole, 30 m along +Z."""
    v.lathe([(0.13, 0.0), (0.1, 3.5), (0.075, 7.0)], "trunk_dark", 6)
    v.solid_cyl((0, 1.5, 0), 0.12, 3.0)
    ends = []
    for y, wide in ((6.5, 1.7), (5.95, 1.3)):
        v.box((0, y, 0.09), (wide, 0.09, 0.09), "wood_dark")
        for s in (-1, 1):
            x = s * (wide * 0.5 - 0.1)
            v.lathe([(0.02, 0.0), (0.045, 0.05), (0.045, 0.13), (0.02, 0.16)], "white", 5, centre=(x, y + 0.04, 0.09))
            ends.append((x, y + 0.16, 0.09))
    for x, y, z in ends:
        # (a wire sags a little between poles)
        points = [(x, y - 0.5 * 4.0 * t * (1.0 - t), z + POLE_SPAN * t) for t in (0.0, 0.2, 0.4, 0.6, 0.8, 1.0)]
        v.strand(points, 0.014, "iron", 3, caps=False)
    v.far = 220.0
    v.shadow = False


def signal_semaphore(v):
    """A semaphore signal, 6.6 m: a tapered wooden post, a red arm with a white stripe (the piece `Arm`, which drops to
    show the line is clear), its lamp and coloured glasses, a ladder up the back and a balance weight. It faces +Z."""
    v.script = "res://scripts/train_signal.gd"
    v.box((0, 3.1, 0), (0.24, 6.2, 0.24), "white", top=(0.6, 0.6))
    v.box((0, 0.5, 0), (0.27, 1.0, 0.27), "loco_black")
    v.lathe([(0.1, 0.0), (0.04, 0.12), (0.07, 0.2), (0.0, 0.42)], "signal_red", 6, centre=(0, 6.2, 0))
    v.solid_box((0, 1.5, 0), (0.26, 3.0, 0.26))
    pivot = Vector((0.0, 5.6, 0.14))
    arm = v.part("Arm", pivot)
    arm.box((0.75, 5.6, 0.14), (1.5, 0.26, 0.03), "signal_red")
    arm.box((1.1, 5.6, 0.158), (0.14, 0.26, 0.004), "white")
    arm.box((1.1, 5.6, 0.122), (0.14, 0.26, 0.004), "loco_black")
    # (the glasses, behind the pivot: red at danger, green when the arm drops)
    arm.box((-0.24, 5.6, 0.14), (0.36, 0.46, 0.025), "loco_black")
    for y, glass in ((5.71, "lamp_red"), (5.49, "lamp_green")):
        arm.box((-0.26, y, 0.14), (0.15, 0.15, 0.04), glass)
    lamp(v, (-0.26, 5.71, 0.0), 1)
    v.box((-0.13, 5.6, 0.0), (0.2, 0.05, 0.05), "iron")
    v.marker("Lamp", (-0.26, 5.71, 0.2))
    # The weight and its rod, and a ladder (to look at: it is not climbed)
    v.box((0.25, 1.2, 0.16), (0.7, 0.05, 0.04), "iron", roll=0.25)
    v.lathe([(0.1, 0.0), (0.1, 0.12)], "iron", 6, centre=(0.52, 1.24, 0.16))
    v.strand([(0.12, 1.2, 0.16), (0.12, 5.5, 0.16)], 0.012, "iron", 3)
    for x in (-0.16, 0.16):
        v.strand([(x, 0.0, -0.5), (x, 5.3, -0.16)], 0.02, "iron", 3)
    for k in range(13):
        t = (k + 1) / 14.0
        v.box((0, 5.3 * t, -0.5 + 0.34 * t), (0.32, 0.025, 0.025), "iron")
    v.far = 220.0


def water_tower(v):
    """A water tower, 7.6 m: an iron tank on a tapering stone base, with a pipe and a hose to fill a tender on the side towards +X, and a ladder."""
    v.box((0, 2.2, 0), (3.4, 4.4, 3.4), "stone", True, top=(0.86, 0.86), sides="stone_b")
    v.box((0, 4.5, 0), (3.3, 0.2, 3.3), "stone_dark")
    v.box((0, 0.95, 1.705), (0.9, 1.9, 0.03), "wood_dark")
    v.lathe([(1.75, 0.0), (1.75, 2.3), (1.82, 2.34), (1.82, 2.42)], "loco_black", 14, centre=(0, 4.6, 0), bands=["wagon_red", "loco_black", "loco_black"])
    for y in (5.0, 6.3):
        v.lathe([(1.77, 0.0), (1.77, 0.08)], "loco_black", 14, centre=(0, y, 0), caps=False)
    v.lathe([(1.7, 0.0), (0.2, 0.5), (0.0, 0.52)], "roof_grey", 14, centre=(0, 7.0, 0))
    v.solid_cyl((0, 5.8, 0), 1.78, 2.4)
    v.strand([(1.7, 4.9, 0), (2.6, 4.9, 0), (3.0, 4.6, 0)], 0.1, "loco_black", 6)
    v.strand([(3.0, 4.6, 0), (3.02, 3.9, 0), (2.96, 3.2, 0.05)], [0.11, 0.1, 0.09], "leather", 6)
    v.strand([(2.6, 4.95, 0), (2.4, 5.6, 0), (1.75, 6.2, 0)], 0.012, "iron", 3)
    v.ladder((-0.9, 0.0, -1.76), 7.0, math.pi)
    v.far = 280.0


def water_column(v):
    """A water column, 4 m: a standpipe by the line with an arm that swings out over a tender (it is out, towards +X), and a leather bag."""
    v.lathe([(0.24, 0.0), (0.2, 0.15), (0.13, 0.3), (0.11, 3.5), (0.15, 3.56), (0.15, 3.7), (0.05, 3.85)], "loco_black", 8)
    v.solid_cyl((0, 1.8, 0), 0.14, 3.6)
    v.strand([(0, 3.6, 0), (0.9, 3.75, 0), (2.0, 3.7, 0)], 0.09, "loco_black", 6)
    v.strand([(2.0, 3.7, 0), (2.03, 3.2, 0), (1.97, 2.7, 0.04)], [0.1, 0.09, 0.08], "leather", 6)
    v.lathe([(0.03, 0.0), (0.03, 0.5), (0.14, 0.52), (0.14, 0.56)], "signal_red", 6, centre=(0.0, 1.0, 0.3))
    v.box((0, 1.0, 0.16), (0.06, 0.06, 0.3), "iron")
    v.far = 200.0


def loading_gauge(v):
    """A loading gauge: a post 2.4 m to the side (-X) and an arm over the line, with a curved bar hung from it. The bar's
    foot is 4.63 m up: under it a wagon's load passes, and anyone standing on a carriage roof does not. The origin is the middle of the track."""
    v.box((-2.4, 2.9, 0), (0.2, 5.8, 0.2), "white", True, top=(0.7, 0.7))
    v.box((-2.4, 0.5, 0), (0.22, 1.0, 0.22), "loco_black")
    v.box((-1.0, 5.6, 0), (3.2, 0.12, 0.12), "white")
    v.strand([(-2.4, 4.6, 0), (-1.2, 5.55, 0)], 0.03, "iron", 3)
    points = [(1.3 * math.sin(t), 4.63 + 0.55 * (1.0 - math.cos(t)), 0.0) for t in [-1.0 + 2.0 * k / 8 for k in range(9)]]
    v.strand(points, 0.035, "loco_black", 4)
    for x in (-0.9, 0.3):
        v.strand([(x, 5.55, 0), (x, 4.63 + 0.55 * (1.0 - math.cos(math.asin(x / 1.3))), 0)], 0.012, "iron", 3)
    v.solid_box((0, 4.73, 0), (2.2, 0.2, 0.1))
    v.settings["strikes"] = [-1.1, 4.63, -0.1, 2.2, 0.4, 0.2]
    v.far = 220.0


## The height of a platform (the floor of a carriage), and how far its edge is from the middle of the track.
PLATFORM = 1.30
PLATFORM_EDGE = 1.62


def halt_platform(v):
    """A platform, 18 m long and 6 m wide, of stone with a paved top at the height of a carriage floor (1.3 m), and a ramp down at each end.
    It lies along Z; its edge towards the line is the one at +X (set that 1.62 m from the middle of the track)."""
    v.box((0, PLATFORM * 0.5, 0), (6.0, PLATFORM, 18.0), "stone", True, sides="stone_b")
    v.box((2.85, PLATFORM + 0.015, 0), (0.3, 0.03, 18.0), "casing")
    for e in (-1, 1):
        low = [(-3.0, 0.0, e * 13.0), (3.0, 0.0, e * 13.0), (-3.0, 0.0, e * 9.0), (3.0, 0.0, e * 9.0)]
        high = [(-3.0, PLATFORM, e * 9.0), (3.0, PLATFORM, e * 9.0)]
        slope = [low[0], low[1], high[1], high[0]]
        both(v, slope, "stone_b")
        for i in (0, 1):
            both(v, [low[i], low[i + 2], high[i]], "stone_dark")
        v.solid_hull(low + high)
    v.far = 280.0


def halt_shelter(v):
    """The halt's building, 6 m by 3.4 m: whitewashed, flat-roofed, a door and a shuttered window, and an awning on posts (3.2 m out) over the
    front of it (which is towards +X, the line). Its name is on a board over the door (`Name1`: change its `text`)."""
    v.box((0, 1.6, 0), (3.4, 3.2, 6.0), "whitewash", True, sides="whitewash")
    v.box((0, 3.3, 0), (3.7, 0.2, 6.3), "stone_b")
    v.box((0, 0.2, 0), (3.5, 0.4, 6.1), "stone_dark")
    v.box((1.705, 1.05, -1.2), (0.04, 2.1, 1.0), "louvre")
    v.box((1.705, 1.7, 1.4), (0.04, 1.1, 1.3), "louvre")
    for k in range(6):
        v.box((1.73, 1.25 + k * 0.17, 1.4), (0.02, 0.05, 1.2), "teak_dark")
    v.box((1.72, 2.72, 0.0), (0.05, 0.5, 2.6), "white")
    v.box((1.715, 2.72, 0.0), (0.05, 0.6, 2.7), "loco_black")
    v.label((1.75, 2.72, 0.0), "DARAW", 0.34, math.pi * 0.5)
    # The awning: a boarded roof sloping down to four posts
    v.box((2.5, 3.0, 0), (1.9, 0.08, 6.6), "teak", roll=-0.16)
    for z in (-3.1, -1.0, 1.0, 3.1):
        v.box((3.2, 1.4, z), (0.12, 2.8, 0.12), "teak_dark")
        v.strand([(3.2, 2.3, z), (2.8, 2.8, z)], 0.035, "teak_dark", 4)
        v.solid_box((3.2, 1.4, z), (0.14, 2.8, 0.14))
    v.box((3.2, 2.8, 0), (0.1, 0.12, 6.4), "teak_dark")
    v.far = 280.0


def station_nameboard(v):
    """The name of the place on a board on two posts, to stand at the end of a platform, read from both sides (`Name1`, `Name2`)."""
    for z in (-1.2, 1.2):
        v.box((0, 1.1, z), (0.1, 2.2, 0.1), "white", True)
    v.box((0, 1.8, 0), (0.06, 0.6, 2.6), "white")
    v.box((0, 1.8, 0), (0.05, 0.7, 2.7), "loco_black")
    v.label((0.04, 1.8, 0.0), "DARAW", 0.36, math.pi * 0.5)
    v.label((-0.04, 1.8, 0.0), "DARAW", 0.36, -math.pi * 0.5)
    v.far = 200.0


def halt_lamp(v):
    """A station lamp, 3 m: an oil lantern on an iron post. `Flame` marks where its light is."""
    v.lathe([(0.12, 0.0), (0.09, 0.1), (0.05, 0.3), (0.04, 2.4), (0.07, 2.45)], "loco_black", 6)
    v.lathe([(0.1, 0.0), (0.17, 0.3)], "glass", 4, centre=(0, 2.45, 0), caps=False)
    v.lathe([(0.2, 0.0), (0.06, 0.14), (0.03, 0.22)], "loco_black", 4, centre=(0, 2.75, 0))
    v.box((0, 2.2, 0), (0.5, 0.03, 0.03), "loco_black")
    v.solid_cyl((0, 1.2, 0), 0.07, 2.4)
    v.marker("Flame", (0, 2.58, 0))
    v.far = 160.0


def halt_bench(v):
    """A platform bench, 1.8 m, facing +Z."""
    for x in (-0.8, 0.8):
        v.box((x, 0.22, 0), (0.06, 0.44, 0.45), "loco_black")
        v.box((x, 0.65, -0.2), (0.06, 0.5, 0.05), "loco_black", pitch=-0.15)
    for z in (-0.12, 0.02, 0.16):
        v.box((0, 0.46, z), (1.8, 0.04, 0.12), "teak")
    for y in (0.62, 0.78):
        v.box((0, y, -0.2 - (y - 0.46) * 0.15), (1.8, 0.1, 0.03), "teak")
    v.solid_box((0, 0.24, 0), (1.8, 0.48, 0.5))
    v.far = 140.0


def luggage(v):
    """Luggage waiting on a platform: two trunks, a suitcase on one of them, a hat box and a bundle."""
    case(v, (0, 0.3, 0), (0.6, 0.6, 1.0), 0.2, "leather", "brass")
    case(v, (0.75, 0.25, 0.15), (0.55, 0.5, 0.85), -0.3, "teak", "leather_dark")
    case(v, (0.02, 0.72, 0.0), (0.42, 0.22, 0.7), 0.6, "leather_dark", "brass", False)
    v.lathe([(0.2, 0.0), (0.2, 0.26), (0.21, 0.27), (0.21, 0.31)], "cloth_red", 8, centre=(0.5, 0.0, -0.75))
    v.ellipsoid((-0.55, 0.2, -0.5), (0.3, 0.2, 0.36), "blanket", 6, 4)
    v.far = 120.0


def bridge_low(v):
    """A bridge over the line: an iron girder on two stone abutments, a road 4 m wide across it with parapets. The underside is
    4.63 m up: a train passes under it, and so does he on a carriage roof if he ducks. The line runs along Z through the origin."""
    under, deck = 4.63, 5.4
    for s in (-1, 1):
        v.box((s * 3.9, under * 0.5, 0), (2.6, under, 4.4), "stone", True, top=(0.85, 0.95), sides="stone_b")
        v.box((s * 2.55, (under + deck) * 0.5 + 0.25, 0), (0.06, 0.02, 0.02), "iron")
        # (the bank the road comes up on, behind each abutment)
        low = [(s * 5.2, 0, -2.2), (s * 5.2, 0, 2.2), (s * 11.0, 0, 2.2), (s * 11.0, 0, -2.2)]
        high = [(s * 5.2, deck, -2.0), (s * 5.2, deck, 2.0)]
        ramp = [high[0], high[1], low[2], low[3]]
        both(v, ramp, "ballast")
        for i in (0, 1):
            both(v, [low[i], low[3 - i], high[i]], "stone_dark")
        v.solid_hull(low + high)
    v.box((0, (under + deck) * 0.5, 0), (10.6, deck - under, 4.0), "wood_dark", True, sides="loco_black")
    for e in (-1, 1):
        v.box((0, deck + 0.35, e * 2.05), (10.6, 1.0, 0.1), "loco_black", True)
        for k in range(9):
            v.box((-4.8 + k * 1.2, deck + 0.1, e * 2.11), (0.08, 1.4, 0.04), "iron")
        v.box((0, deck + 0.87, e * 2.05), (10.7, 0.06, 0.16), "iron")
    v.settings["strikes"] = [-2.6, under, -2.0, 5.2, deck - under, 4.0]
    v.far = 320.0


def level_crossing(v):
    """A level crossing: a road 4 m wide boarded across the line, and a white gate with a red disc on each side of it, open to the
    road. The line runs along Z through the origin; lay it over a length of track."""
    v.box((0, 0.26, 0), (1.3, 0.08, 4.0), "wood")
    for s in (-1, 1):
        v.box((s * 1.25, 0.26, 0), (0.9, 0.08, 4.0), "wood")
        low = [(s * 1.7, 0.3, -2.0), (s * 1.7, 0.3, 2.0), (s * 4.2, 0.0, 2.0), (s * 4.2, 0.0, -2.0)]
        both(v, low, "ballast")
        v.solid_hull(low + [(s * 1.7, 0.0, -2.0), (s * 1.7, 0.0, 2.0)])
        for e in (-1, 1):
            v.box((s * 3.0, 0.7, e * 2.3), (0.16, 1.4, 0.16), "white", True)
        # (a gate, swung back along the line)
        with v.at((s * 3.0, 0, 2.3), 0.0):
            for y in (0.4, 0.8, 1.2):
                v.box((0, y, 1.9), (0.05, 0.09, 3.6), "white")
            v.box((0, 0.8, 3.7), (0.06, 0.95, 0.08), "white")
            v.strand([(0, 0.4, 0.1), (0, 1.2, 3.7)], 0.03, "white", 4)
            for face in (-1, 1):
                points = [(face * 0.035, 0.8 + 0.3 * math.cos(TAU * k / 10), 1.9 + 0.3 * math.sin(TAU * k / 10)) for k in range(10)]
                v.poly(points[::-1] if face > 0 else points, "signal_red")
            v.solid_box((0, 0.7, 1.9), (0.08, 1.4, 3.6))
    v.solid_box((0, 0.15, 0), (3.4, 0.3, 4.0))
    v.far = 220.0


VEHICLES = [loco, tender, carriage, carriage_third, van_goods, wagon_open, wagon_finds, wagon_flat, wagon_tank, van_brake]
LINESIDE = [track_straight, track_curve, track_points, buffer_stop, telegraph_pole, signal_semaphore, water_tower, water_column,
            loading_gauge, halt_platform, halt_shelter, station_nameboard, halt_lamp, halt_bench, luggage, bridge_low, level_crossing]


# ---------------------------------------------------------------- writing them out

def mesh_of(name, p, origin):
    """One piece as a Blender object, its points taken from `origin`. Returns it and how many triangles it has."""
    mesh = bpy.data.meshes.new(name)
    made = bmesh.new()
    points = [made.verts.new((v.x - origin.x, -(v.z - origin.z), v.y - origin.y)) for v in p.verts]
    slots = []
    triangles = 0
    for indices, material, smooth, _uvs in p.faces:
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
    for slot in slots:
        mesh.materials.append(material_for(slot))
    thing = bpy.data.objects.new(name, mesh)
    thing.location = (origin.x, -origin.z, origin.y)
    bpy.context.collection.objects.link(thing)
    return thing, triangles, slots


def export(v):
    pieces = [("Body", v, Vector((0, 0, 0)))] + [(name, piece, origin) for name, (piece, origin) in v.parts.items()]
    things = []
    triangles = 0
    surfaces = 0
    shiny = False
    for name, piece, origin in pieces:
        thing, count, slots = mesh_of(name, piece, origin)
        things.append(thing)
        triangles += count
        surfaces += len(slots)
        shiny = shiny or any(slot in SHINY for slot in slots)
    bpy.ops.object.select_all(action="DESELECT")
    for thing in things:
        thing.select_set(True)
    bpy.context.view_layer.objects.active = things[0]
    bpy.ops.export_scene.gltf(filepath=os.path.join(OUT, v.name + ".glb"), export_format="GLB", export_yup=True, export_animations=False,
                              use_selection=True, export_vertex_color="MATERIAL")
    for thing in things:
        mesh = thing.data
        bpy.data.objects.remove(thing)
        bpy.data.meshes.remove(mesh)
    everything = list(v.verts) + [point for piece, _ in v.parts.values() for point in piece.verts]
    low = [min(point[i] for point in everything) for i in range(3)]
    high = [max(point[i] for point in everything) for i in range(3)]
    print("BUILT %-20s tris=%5d pieces=%2d surfaces=%2d solids=%2d size=%.1f x %.1f x %.1f" % (
        v.name, triangles, len(pieces), surfaces, len(v.solids), high[0] - low[0], high[1] - low[1], high[2] - low[2]))
    settings = dict(v.settings)
    if v.wheels:
        settings["wheels"] = v.wheels
    return {"body": v.body, "solids": v.solids, "markers": v.markers, "ladders": v.ladders, "labels": v.labels, "far": v.far, "shadow": v.shadow,
            "triangles": triangles, "surfaces": surfaces, "pieces": [name for name, _, _ in pieces], "shiny": shiny, "script": v.script,
            "settings": settings}


def main():
    os.makedirs(OUT, exist_ok=True)
    bpy.ops.wm.read_factory_settings(use_empty=True)
    listing = os.path.join(OUT, "train.json")
    known = {}
    if ONLY and os.path.exists(listing):
        with open(listing) as file:
            known = json.load(file)
    total = 0
    for make in VEHICLES + LINESIDE:
        if ONLY and make.__name__ not in ONLY:
            continue
        v = Made(make.__name__, "vehicle" if make in VEHICLES else "static")
        v.far = 320.0 if make in VEHICLES else 0.0
        make(v)
        known[v.name] = export(v)
        total += known[v.name]["triangles"]
    with open(listing, "w") as file:
        json.dump(known, file, indent=1)
    print("BUILT: %d triangles in what was built; %d things listed" % (total, len(known)))


main()
