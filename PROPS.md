# Props and the desert level

## The props

Each prop is a scene in `props/`, to drag into a level. Its root is the body (a StaticBody3D unless it says otherwise) with
`scripts/prop.gd` on it; under that are `Model` (the mesh, from `models/props/<name>.glb`) and its collision shapes
(`Solid1`...). All face +Z and stand with their foot at the origin, except the things he picks up or pushes, whose origin is
their middle.

| Scene | What it is |
| --- | --- |
| `sphinx` | The great sphinx, 25 m long. Solid all over: onto a paw from the side (1.3 m), from there the shoulder, from there the back. |
| `pyramid_great` | 60 m across, 46 high, in steps of 1.35 m, each one he can catch and climb, up to the smooth casing at the top. |
| `pyramid_ruined` | 20 m across, its top gone and one corner fallen in (towards +X +Z) as a slope of blocks. |
| `pyramid_entrance` | A doorway with a cornice and a short dark passage, shut at the back. Stand its back against a pyramid's face. |
| `palm_a`, `palm_b`, `palm_c` | Palms: 8 m; 10.5 m and well bent; 5 m. The leaves sway. |
| `obelisk` | 14 m, on a plinth. Tipped over it makes a fallen one. |
| `column`, `column_broken`, `column_stump`, `column_fallen` | 6 m whole; snapped at 3.6 m; a stump he can get onto (1.4 m); drums and capital lying along Z. |
| `lintel` | A beam 5.2 m long: across two columns 4.6 m apart, at a height of 6 m, or on the ground. |
| `statue_pharaoh`, `statue_anubis` | A seated king, 5.2 m; a jackal lying on a shrine (its top is 1.5 m up: he can catch it). |
| `sarcophagus` | A stone coffin with its lid pushed askew. |
| `jar_canopic`, `jar_canopic_jackal`, `pot`, `rock_small` | RigidBody3D, in the groups `throwable` and `interest`: he picks them up, throws them, hits them with the bat. |
| `pot_large` | A storage jar a metre high. Fixed. |
| `brazier`, `torch_stand`, `campfire` | Each has an empty Marker3D named `Flame` where the fire goes. |
| `block`, `block_stack`, `rubble`, `rock_a`, `rock_b` | Dressed stone, a heap of three (two steps to climb), broken stone, a big boulder and a small one. |
| `block_push` | RigidBody3D, mass 20, rotation locked: a block to push. |
| `crate` | A fixed wooden crate, 0.9 m. |
| `well`, `oasis_rim` | A well with its frame and bucket; a quarter-ring of kerb stones, 6 m in radius, to set round water (scale it to fit). |
| `scaffold` | A wooden scaffold with a deck 3.5 m up, open at both ends, and a `Ladder` up one side. |
| `awning`, `tent` | A market stall under striped cloth; an expedition's ridge tent. |
| `wall_glyphs`, `wall_ruin` | A wall carved with hieroglyphs on both faces; a broken wall that steps down and can be climbed. |

On the root of each: `draw_distance` (metres beyond which it is not drawn; 0 is always) and `casts_shadow`. Change them
on any one you have placed.

`prop.gd` gives every surface the world's material for its colour (`Toon.surface`), so props follow the menu's banded or smooth
light. In the editor you see the model's own plain materials instead, and a `Ladder` or `Pool` shows nothing: those draw
themselves only when the game runs.

### Making or changing one

They are made in Blender from code, in `tools/build_props.py`: one function per prop, out of boxes, lathed shapes, tubes and flat
glyphs, and it says there what is solid. Then:

```
blender --background --python tools/build_props.py [-- name ...]     # models/props/*.glb and props.json
godot --headless --path . --import
godot --headless --path . --script tools/build_prop_scenes.gd [-- name ...]   # props/*.tscn
godot --path . --resolution 960x960 --script tools/prop_sheets.gd -- <folder> [four] [banded] [name ...]   # pictures of them
```

`build_prop_scenes.gd` writes a prop's scene afresh, so make changes in the Python, not in `props/*.tscn`. Props placed in a level
are instances and pick the change up.

## The desert (`desert.tscn`)

A scene to edit in the editor. Under `Level`:

- `Sky`, `Sun`: the light. Ordinary nodes.
- `Terrain`: the ground (below).
- `Approach`, `Camp`, `Oasis`, `Colonnade`, `Sphinx`, `Pyramid`, `RuinedPyramid`, `Shrine`, `Outpost`, `FallenObelisk`: one node
  for each place, holding its props and a `Ground` pad. Move the node and the whole place moves, ground and all.
- `Scatter`: lone rocks, palms and stones out in the dunes.
- `Checkpoints`: Marker3Ds in the group `checkpoints`. He comes back to the last one he came within 5 m of. Copy one to add one.

To place more: drag a scene from `props/` into the viewport, or copy one that is there (Ctrl+D). On a pad the ground is level, at
the height of the pad; out on the dunes, set the height by eye and sink things a little.

`tools/build_desert.gd` laid the scene out the first time. It will not write over `desert.tscn` again unless run with `-- force`,
which throws away whatever has been done by hand.

### The ground

`Terrain` (`scripts/desert_terrain.gd`) makes its mesh and collider from a height function when the scene opens, in the editor
too. In the inspector: `size`, `cell` (the side of one square of the mesh), `dune_height`, `seed`, `rim_height` and `rim_width`
(the ground rises at its edges to close the level in), `far_from` (beyond this the ground is drawn coarsely), and a `Rebuild`
button.

Level ground is a `TerrainPad` (`scripts/desert_pad.gd`): a Marker3D with `half_size`, `round` and `ease` (how far the dunes take
to rise back round it). The ground is pressed flat to the pad's own height. Add one anywhere in the scene (Add Node, TerrainPad),
move it, and the ground follows a moment later. A pad set lower inside another makes a hollow: the oasis water is a `Pool` lying
in the hollow made by `Oasis/Basin`, and shows wherever the ground is below its surface.

Two functions in `desert_terrain.gd` are there to be replaced: `dunes_at(x, z)`, the height of the open sand, and
`sand_material()`, what the ground is drawn with.

To look at the level without playing it, and to check he can still get about:

```
godot --path . --resolution 960x960 --script tools/desert_views.gd -- <folder> [banded] [view ...]
godot --headless --path . --fixed-fps 60 --script tools/desert_walk.gd
```

## Guns, targets and ammunition (`guns/`)

Scenes to drag into a level, like the props, but with scripts of their own (see "Guns" in README.md). They are built by
`tools/build_guns.py` and `tools/build_gun_scenes.gd`, not by the props' tools; change them there, not in `guns/*.tscn`.

| Scene | What it is |
| --- | --- |
| `revolver`, `rifle`, `shotgun`, `flare_pistol` | Guns (`scripts/gun.gd`): RigidBody3D, picked up like a rock. Origin at the grip, barrel along -Z. Rounds, timing and damage are properties on the root. |
| `ammo_box` | An open cartridge box (Area3D). Fills the gun of whoever comes within 0.9 m carrying one. `ammo` limits it to one kind of gun; `uses` to so many visits. |
| `target_board` | A painted board on a hinged post, 1.1 m to its middle, facing +Z. Shot, it falls and stands up after `stays_down` seconds. |
| `target_gong` | An iron plate hung in a frame, 1.25 m to its middle, facing +Z. Shot, it swings. |
| `target_pot`, `target_jar`, `target_jackal` | The props `pot`, `jar_canopic` and `jar_canopic_jackal` again, as things that smash when shot (`scripts/breakable.gd`). Set `comes_back` (seconds) for one that returns. |
| `bottle`, `tin_can` | A wine bottle that smashes (also when thrown hard: `break_speed`); a tin that only jumps. |

Give a wall or a prop the metadata `surface` (`stone`, `sand`, `wood`, `metal`, `clay`, `glass`, `soft`) to choose what a bullet
does to it; without it, the terrain is sand, creatures are soft, loose things are wood and the rest is stone.
