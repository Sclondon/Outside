---
name: make-character
description: Build a new humanoid character for Outside (Godot) that is animated by the boy's code-driven rig (scripts/character_rig.gd) - model it in Blender from a Python script, export, import, check it with contact sheets, tune it and put it in a level. Use when asked to add, make or model a new character, NPC, enemy or figure, to give something "the boy's animation", or to fix a figure whose limbs come out wrong on the rig.
---

# Make a character on the boy's rig

Nothing in this game is an animation clip. `scripts/character_rig.gd` (`CharacterRig`) poses any figure with the
right skeleton every frame, and reads its proportions from the bones. So a new character is: a Blender script that
builds a mesh on that skeleton, and a few numbers on the rig. No animating.

Files:

| File | What it is |
| --- | --- |
| `tools/build_figure_template.py` | Copy this. Builds the example `watchman` (stocky man, T-pose, tubes and ellipsoids) |
| `tools/build_character.py` | The kit it imports: `Builder` (`tube`, `ellipsoid`, `strand`), `dome`, `upright`, `blend`, `export`. Do not edit it for one figure |
| `tools/build_boy.py` | The elaborate one: fingers, hair bones, a loose cap, striped shirt. Read for those; do not start from it |
| `tools/figure_sheets.gd` | Checks any figure: skeleton report and contact sheets |
| `scripts/figure.gd` | `Figure`: a ready-made body for a non-player character |
| `scripts/mummy.gd` | A hand-written body on the rig, for behaviour `Figure` does not have |

Tools (Windows; no system Python - Blender's own runs the build scripts):

```
BLENDER="C:\Program Files\Blender Foundation\Blender 4.3\blender.exe"
GODOT="C:\Program Files (x86)\Steam\steamapps\common\Godot Engine\godot.windows.opt.tools.64.exe"
```

## 1. The skeleton contract

Space: metres, Y up, the figure faces **+Z**, **+X is its left** (`_l` bones at +X). The build scripts are written
in this space; the kit converts to Blender's.

Required bones and parents (names exact):

```
hips (root)
  spine > [chest] > [neck] > head
          chest (or spine, if no chest) > upper_arm_l > forearm_l > hand_l      (and _r)
  thigh_l, shin_l, foot_l   all three directly under hips, NOT chained          (and _r)
  foot_l > toe_l                                                                (and _r)
```

Optional, used if present: `chest`, `neck` (without a chest the figure does not shift, breathe or look about when
idle; the mummy has neither); `finger0a/b/c_l` .. `finger3a/b/c_l`, `thumba_l`, `thumbb_l` (and `_r`) under the hand;
`hem_0`, `hem_1`.. under spine (front first, round to its left) for a swinging hem; `hair_f`, `hair_l`, `hair_b`,
`hair_r` under head; `cap` under head (a hat that bounces; its mesh must be its own object, see below). Any other
bone is left at rest.

Rest pose rules:

- Every bone rests **unrotated** (identity basis). `kit.make_armature` does this; never roll or aim bones.
- Hip, knee and ankle joints are in a vertical line; the ankle joint is **0.05 above the sole**; `toe` is where the
  foot bends (about `(0, -0.035, 0.08)` from the ankle).
- The arm is straight and lies in the X-Y plane: anywhere from hanging to a full T-pose (template and boy: T-pose;
  mummy: 0.22 rad from hanging). The rig measures the angle and undoes it.
- Model every figure **about as tall as the boy (1.25 m)** whatever it is, and scale it in Godot (`Figure.size`, or
  `rig.scale` as the mummy does). Many distances in the rig are absolute and tuned to that size.

Gotcha: **a mesh object must not share a name with a bone**. `kit.export` names
the mesh after the figure, and parts listed in `apart=(...)` as `<figure>_<part>`, so the figure's name must not be
a bone name, and nothing made by hand should be called `cap`, `head`, etc.

## 2. Shape the figure

Copy `tools/build_figure_template.py` to `tools/build_<name>.py` and set `NAME`. Then, in order:

1. **Joints** (the constants at the top). These are the proportions; the rig follows them.
2. **Shapes**: one function per part filling a `kit.Builder`. A ring is `(centre, u, v)`; `kit.upright(x, y, z, rx, rz)`
   is a level one. `b.tube(rings, segments, floor)` skins rings into a closed surface.
3. **`PARTS`**: `(part, material index, function, fuse)`. `fuse=(voxel size, smoothing passes, triangle budget)` melts
   a part's shapes into one surface (good for a torso with its sleeves, a seat with its legs) but discards texture
   coordinates; `None` keeps shapes as built.
4. **`weights(part, p)`**: returns `{bone: share}` for a point in the rest pose. Use `blend(a, b, x)` across each
   joint (a few centimetres wide) so it bends rather than creases. Each part name can have its own rule.
5. **`bones()`**: only changes if you add optional bones.

The template exports the full model and then, with `kit.LOW = True`, a demade `<name>_lo` from the same shapes.
`kit.export(..., apart=("cap",))` makes a part a separate object (needed for a `cap` bone's hat, and for anything
to be hidden at run time: the rig shows `*_cap` and hides `*_crown` objects when capped).

Materials (`MATERIALS`: name, sRGB colour) are matched by **name** in `scripts/toon.gd`:

- `hair`: the hair shader. Needs texture coordinates running along each lock, which `tube`/`strand` write; so do
  not fuse hair.
- `shirt`: a pinstripe along lines of `UV.x`, which must be a distance round the body in metres (see `body` in
  `build_boy.py`). Unless you write that, call the material something else (`coat`, `tunic`).
- Anything else: flat cel shading in its colour. Names are otherwise free.

## 3. Build, import

From the project root:

```
& $BLENDER --background --python tools/build_<name>.py -- <scratch folder>
& $GODOT --headless --path . --import
```

The folder after `--` is optional: it gets `<name>_side.png` and `<name>_quarter.png` renders of the rest pose (and
of `_lo`). Look at them before going on. The build prints `BUILT <name> verts=.. tris=..` and writes
`models/<name>.glb`, `models/<name>_lo.glb` and editable `tools/<name>.blend`. The import step is required after
every rebuild, and also registers new `class_name` scripts.

## 4. Check it on the rig

```
& $GODOT --path . --fixed-fps 60 --resolution 960x960 --script tools/figure_sheets.gd -- <scratch folder> res://models/<name>.glb [scale] [looseness=0.7] [stoop=0] [arms_reach=0]
```

The window is off-screen and takes no input. It prints `CHECK` lines and writes four sheets, which you must open
and look at (Read tool):

| Sheet | What to look for |
| --- | --- |
| `<name>_turnaround.png` | Stands on the ground, arms at its sides, facing the camera in the first cell |
| `<name>_idle.png` | Six moments over 7 s: weight shifts from leg to leg (only with a chest bone) |
| `<name>_walk.png` | Six frames from the side, three from in front, three from behind |
| `<name>_run.png` | The same at a run |

Reading the `CHECK` lines, and the likely cause of what the sheets show (the first two are reported by the
script; the rest follow from how the rig reads the skeleton and are where to look first):

- `missing bones` / `is under X, not Y` / `do not rest unrotated`: fix `bones()`; the script stops there.
- `SOMETHING HAS COME APART`: a joint went further from the hips than the figure is tall, or under the floor.
- Arms stick out or cross the body: the arm is not straight in the X-Y plane at rest.
- Feet sink or float: ankle joint is not 0.05 above the modelled sole.
- Walks backwards, or arms swing with the same-side leg: the model faces -Z, or left and right are swapped.
- Mesh tears or drags at a joint: `weights` there; a blend that is too narrow creases, a missing part name falls
  through to the wrong rule. Clothing poking through clothing at a bend is a shape problem: shorten the outer part.

Run it on `res://models/mummy.glb 1.3 looseness=0.25 stoop=0.12 arms_reach=1` to see a known-good second figure.

## 5. Tune

These are exports on `CharacterRig`, passed through by `Figure`, and can be tried as arguments to `figure_sheets.gd`:

| Setting | Range | Effect |
| --- | --- | --- |
| scale (`Figure.size`) | 1.0 = as modelled | Height. Boy 1.0, mummy 1.3, watchman 1.4 (1.75 m) |
| `looseness` | 0..1 | Slack and overlap in the limbs, variation between steps. Boy 1.0, mummy 0.25 |
| `stoop` | radians | Constant forward hunch. Mummy 0.12 |
| `arms_reach` | 0..1 | Arms held out ahead |
| `walk_speed`, `run_speed` | m/s, on the body | The rig walks up to `walk_speed` and is at a full run at `run_speed` |
| `cel_shaded`, `dusty` | | Banded shading with `Toon`; puffs of dust at its feet |

Proportions are not tuned here: change the joints in the build script and rebuild.

## 6. Put it in a level

```gdscript
var man := Figure.new()
man.model = preload("res://models/watchman.glb")
man.model_low = preload("res://models/watchman_lo.glb")   # optional; used when the menu asks for demade models
man.size = 1.4
man.height = 1.75        # collision capsule
man.looseness = 0.6
man.position = Vector3(3, 0, 0)
add_child(man)           # it is built here: set the above first
man.go_to(Vector3(9, 0, 0))          # walk; go_to(point, true) runs
man.arrived.connect(func() -> void: man.face(player.global_position))
```

`Figure` gives `go_to(point, run := false)`, `stop()`, `is_going()`, `face(point)`, `place(at, yaw)`, the `arrived`
signal, `facing_yaw`, `visual_position`, and `rig` (the `CharacterRig`). It walks in a straight line with gravity
and no path-finding; it is on collision layer 4 with mask 1, so the world stops it and the player passes through.
`looseness`, `stoop` and `arms_reach` may be changed at any time.

For anything cleverer (chasing, waking, stepping round things), write a body like `scripts/mummy.gd`, or extend
`Figure`. What the rig needs of its parent: `velocity`, `is_on_floor()`, `walk_speed`, `run_speed`, `is_pushing`.
The rig must be `top_level = true` and placed by the body each frame (`global_position`, `rotation.y`), not carried
by it. Add the body to the group `pursuers` with a `chasing` property and the boy will watch it and stand wary.

## Limits

- Only standing, walking, running, pushing and falling come from a plain body. Ducking, sliding, hanging, climbing,
  throwing and the hard landings are driven by `Player` state and are not available to a `Figure`.
- `figure_sheets.gd` does not exercise jumps, turns or slopes.
- Not a route to quadrupeds: the hound has its own rig (`scripts/hound_rig.gd`).
