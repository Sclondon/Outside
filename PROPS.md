# Props and the desert level

## The props

Each prop is a scene in `props/`, to drag into a level. Its root is the body (a StaticBody3D unless it says otherwise) with
`scripts/prop.gd` on it; under that are `Model` (the mesh, from `models/props/<name>.glb`) and its collision shapes
(`Solid1`...). All face +Z and stand with their foot at the origin, except the things he picks up or pushes, whose origin is
their middle.

| Scene | What it is |
| --- | --- |
| `sphinx` | The great sphinx, 25 m long. Solid all over: onto a paw from the side (1.3 m), from there the shoulder, from there the back. |
| `pyramid_great` | 60 m across, 46 high, in steps of 1.35 m, each one he can catch and climb, up to the smooth casing at the top. (For any other pyramid see "Pyramids made from numbers" below.) |
| `pyramid_ruined` | 20 m across, its top gone and one corner fallen in (towards +X +Z) as a slope of blocks. |
| `pyramid_entrance` | A doorway with a cornice and a short dark passage, shut at the back. Stand its back against a pyramid's face. |
| `palm_a`, `palm_b`, `palm_c` | Date palms: 8 m; 10.5 m and well bent; 5 m. A trunk in the diamonds of its old leaf bases, a crown of feather leaves with a dry skirt under it, bunches of dates. The trunk is solid as far up as he can reach. |
| `palm_doum` | A doum palm, 8 m: a ringed trunk that forks, and three heads of fan leaves. The trunk is solid up to the fork. |
| `palm_sucker`, `reeds`, `shrub_dry`, `grass_tuft` | Plants he walks through: a chest-high bush of date palm leaves on a stump; a clump of papyrus, 2.5 m, for the edge of water; a dry grey-green shrub, 1.2 m; a tuft of straw grass (no shadow). |
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
| `pickaxe`, `shovel`, `turia`, `khopesh` | RigidBody3D in the groups `throwable`, `interest` and `bats`: he picks one up and swings it in both hands, as he does the bat. A navvy's pick, a round-mouthed shovel with a D grip, the broad Egyptian hoe a dig was worked with, and the bronze sickle sword (0.6 m: a hilt, a straight shank, the blade curving out with its edge on the outside, a hooked tip). The origin is the end he holds and the thing lies along its own Y, so one put into a level stands on end and falls over: tip it on its side. |
| `trowel`, `brush`, `tape_measure`, `lantern`, `dig_basket` | RigidBody3D, `throwable`: a pointing trowel, a hand brush, a tape in its leather case, a hurricane lantern (it gives no light), a palm-leaf basket of spoil. |
| `brushes`, `dig_baskets`, `dig_tools` | Fixed: a tin of brushes with a hand brush and a trowel on a cloth; a stack of empty baskets, a full one and one tipped over; a pick, a shovel and a turia stood against a box, with a basket and a coil of rope. |
| `sieve`, `wheelbarrow` | A screen on legs with the heaps under and below it, and a round hand sieve; a wooden barrow loaded with spoil, its wheel towards +Z. |
| `surveyor_level`, `plumb_tripod`, `ranging_pole`, `measuring_staff` | A brass dumpy level on its tripod, looking along +Z; three poles with a plumb line hung over a peg; a 2 m pole in red and white; a 2.5 m levelling staff, its marked face towards +Z. |
| `crate_finds`, `camp_table` | A packing case of finds in straw, its lid leaning on it; the table a dig is run from (a map, notebooks, ink, a lens, a lantern) with a folding stool. |
| `backpack`, `bedroll` | A canvas rucksack with leather straps and a blanket rolled on top, set down; a rolled blanket lying by itself. (Worn, the backpack is another model: see "What is worn".) |
| `khopesh_stand` | A khopesh on a rack, to stand on the ground or against a wall. |
| `helmet_anubis`, `helmet_horus`, `helmet_sobek`, `helmet_bastet`, `helmet_thoth`, `helmet_khnum` | A god's head to wear (jackal, falcon, crocodile, cat, ibis, ram), shown on a post with a wooden head, at the height of the boy's. |

On the root of each: `draw_distance` (metres beyond which it is not drawn; 0 is always) and `casts_shadow`. Change them
on any one you have placed.

A prop with gold, bronze or brass in it (the materials `gilt`, `bronze_bright`, `brass`) has `scripts/gear_prop.gd` on its root
instead, which is `prop.gd` and makes those shine as a pyramid's gold cap does.

`prop.gd` gives every surface the world's material for its colour (`Toon.surface`), so props follow the menu's banded or smooth
light. In the editor you see the model's own plain materials instead, and a `Ladder` or `Pool` shows nothing: those draw
themselves only when the game runs.

### What is worn

The backpack and the six helmets are also models of their own in `models/worn/`, with no scene: `scripts/worn.gd` puts one
on a figure, following a bone of its skeleton (`chest` for the pack, `head` for a helmet).

```gdscript
Worn.put_on(figure, &"helmet_anubis")   # a CharacterRig, a Figure, the Player, or a Skeleton3D
Worn.put_on(figure, &"backpack")
Worn.take_off(figure, &"head")          # a thing by name, a slot (&"head", &"back"), or nothing for all of it
```

A helmet is a striped headcloth open at the face, from chin to brow, with the animal's head on top of it: the face shows
under the muzzle. While one is on, the figure's cap and hair are not drawn. They are modelled to fit the boy; `Worn.FITS`
says how each is fitted to a figure built otherwise (the brother, the mummy), by the name of its model, and `put_on` takes
a fit of its own (`{"scale": ..., "offset": ...}`). What the boy has on is `Settings.helmet` and `Settings.backpack`, set in
the dresser. They are built with the props (`WORN` in `tools/build_props.py`), each in the space of the bone it follows.

```
godot --path . --fixed-fps 60 --resolution 960x960 --script tools/worn_sheets.gd -- <folder> [heads figures moves swing] [anubis ...] [nopack]
```

draws them on the boy, his brother, townspeople and the mummy, the boy doing what he does in them, and the swing of the
khopesh, the pick and the shovel.

### Plants

A plant is one mesh in one material, `plant`, and every plant in a level is drawn with the same shader (`PLANT_SHADER` in
`scripts/prop.gd`). Its leaves are cut out of triangles, not drawn on cards. The points of the mesh carry what the shader
goes by: their colour (and in its alpha, how much they are leaf), where they are on their leaf, how far along their part
they are from where it is rooted, and a normal that leans out from the heart of the crown, so that a crown is lit as one
round mass. The shader paints a leaf darker at its root and paler at its tip in flat tones, lights it in bands or smoothly
as the menu says, lets the sun through it when the sun is behind, and moves it in the wind: the level's `SandWind` if it has
one, a light breeze if not. In `tools/build_props.py` a plant is put together from `frond` (a feather leaf), `fan` (a fan
leaf), `blade` (a strap), `stem` and `bark`.

`prop_sheets.gd` has words for looking at them: `sky` (from the ground, against the sky), `backlit` (the sun behind),
`crown` (the top, close) and `sway` (four moments of a stiff wind).

### Making or changing one

They are made in Blender from code, in `tools/build_props.py`: one function per prop, out of boxes, lathed shapes, tubes and flat
glyphs, and it says there what is solid. Then:

```
blender --background --python tools/build_props.py [-- name ...]     # models/props/*.glb and props.json, and models/worn/*.glb
godot --headless --path . --import
godot --headless --path . --script tools/build_prop_scenes.gd [-- name ...]   # props/*.tscn
godot --path . --resolution 960x960 --script tools/prop_sheets.gd -- <folder> [four] [banded] [sky] [backlit] [crown] [sway] [name ...]   # pictures of them
```

`build_prop_scenes.gd` writes a prop's scene afresh, so make changes in the Python, not in `props/*.tscn`. Props placed in a level
are instances and pick the change up.

## The desert (`desert.tscn`)

The desert is not laid out in the Godot editor any more. It is made from a layout (`levels/desert.json`, or the one saved on
the device) by `scripts/desert.gd`, and changed with the level editor inside the game: see "The level editor" in README.md.
The scene holds only `Sky` and `Sun` (ordinary nodes: change the light there), the `Terrain`, the player, the camera and the
controls. Every prop below is on the editor's Stone and Camp pages, and the dig's are on its Dig page.

A new prop is offered by the editor once it is added to `PALETTE` in `scripts/level_layout.gd`.

### The ground

`Terrain` (`scripts/desert_terrain.gd`) makes its mesh and collider from a height function when the scene opens, in the editor
too (there it reads `layout_file`, so the Godot editor shows the same ground as the game). The game gives it its shape from the
layout: its own numbers, the pads, dunes placed by hand, and ponds and rivers, which are cut into it (`shape_from`). In the inspector: `size`, `cell` (the side of one square of the mesh), `dune_height`, `seed`, `rim_height` and `rim_width`
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

### Pyramids made from numbers

`Pyramid` (`scripts/pyramid.gd`) is a StaticBody3D that makes its own mesh and collision when it enters the level, the
same every time from the same numbers. In a layout it is the kind `pyramid` (the editor's "Stepped pyramid", "Finished
pyramid" and "Fallen pyramid" are the same thing starting from different numbers); in a scene, add a node with the
script and set it in the inspector. Its foot is at the origin; its door, if any, is in the face towards +Z.

| Number | In the layout | What it is |
| --- | --- | --- |
| `base` | `base` | Width of the foot, metres (the foot of the casing: the stepped core is one tread in from it). |
| `slope` | `slope` | Steepness of the faces, degrees. With `base` this gives the height: 60 m at 54 degrees is 41 m to the tip. |
| `rise` | `rise` | Height of a course. He can catch and climb one of up to 1.6 m; the fixed great pyramid's are 1.35. |
| `casing` | `casing` | How much smooth casing is left, down from the top: 0 none (all steps), about 0.25 a cap of it with a ragged lower edge, 1 all of it. Casing cannot be climbed. |
| `gold_cap` | `cap` | A gilded capstone, the top eighth or so. On a stepped pyramid it stands on the top course. |
| `ruin` | `ruin` | 0..1. From 0.03 the cap and the top courses go and loose blocks lie on the top; casing falls off in runs; blocks go missing and slip out; corners fall in (one from 0.2, two from 0.5, three from 0.75, four from 0.95), each a bite out of the courses with rubble and blocks lying in it and spilled past the foot. |
| `seed` | `seed` | Which ruin: which corners, which blocks. |
| `door` | `door` | A cutting through the bottom courses to a doorway with jambs and a lintel, and a few metres of dark passage, shut at the back. |
| `colour` | `stone` | The stone: sandstone, pale limestone, red sandstone, dark stone (`Pyramid.STONES`). |

What is solid: one box to a course (two or three where it is bitten or cut), so every step can be caught and climbed;
one hull for casing that is whole from some course up, which he slides off; and one mesh of triangles for rubble, loose
blocks and odd runs of casing, which he can walk up where it lies gently. It goes on 4 m below its foot, so it need not
stand on ground that is quite level. After it is built, `triangles`, `shapes`, `height` and `fallen_corners` say what
was made. A 60 m pyramid: finished, 20 triangles and 1 shape (with a door 196 and 14); stepped, 290 and 29; ruined
(0.45), about 1450 and 62; ruined right down (1.0), about 4650 and 80.

It is drawn with `Sandstone.surface` (`scripts/sandstone.gd`, also `Toon.sandstone(colour)`): a shader that draws the
blocks and their joints, strata, worn edges, chips, stains and cracks from where each point is on the model, with
nothing to load, each fading out before it is too small to draw. Anything else of stone can use it: give a mesh the
material, and `course` and `block` (the height of a course and the length of a block) to suit. `Toon.gold()` is the
capstone's gold.

```
godot --path . --resolution 960x960 --script tools/pyramid_sheets.gd -- <folder> [banded] [name ...]   # each sort, near and far
godot --path . --resolution 960x960 --script tools/pyramid_sheets.gd -- <folder> level                 # those in the desert
godot --headless --path . --fixed-fps 60 --script tools/pyramid_walk.gd                                # can he climb them
```

### The heat

`HeatMirage` (`scripts/heat_mirage.gd`) is made by the desert, as strong as the layout's `mirage` says (0..1; 0 is
none, and then nothing is drawn; the editor's Level page has it). What is far off and near the level of the eye swims,
most where it is in the sun; nothing near does. Far ground a little below the level of the eye shows what is above it
upside down, tinted with the sky: pools that are not there. It is less in a wind and with the sun low, and gone while
he is under a roof. It is one strip drawn across the screen at the height of the horizon after everything solid,
reading the picture so far: the same in both renderers.

```
godot --path . --resolution 1280x720 --script tools/pyramid_sheets.gd -- <folder> mirage   # with it, and without
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
