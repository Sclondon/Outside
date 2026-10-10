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
| `wall_glyphs`, `wall_ruin` | A wall carved with hieroglyphs on both faces (real ones: an offering formula on the front, a tomb owner's curse on the back; see "Hieroglyphs" in README.md); a broken wall that steps down and can be climbed. |
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

## The railway

A railway of about 1910, after the Egyptian State Railways on the line up the Nile: British-built tender engines, carriages
with clerestories or double "tropical" roofs and louvred shutters, four-wheeled goods stock with side buffers. Everything
is a scene in `props/` like any other prop, and is on the level editor's Railway page. The liveries (a green engine with a
black smokebox, red beams and a brass dome; a white first-class carriage; teak third class; grey wagons; an oxide-red brake
van) are a guess: no source for the colours of the time was found. The engine is given outside cylinders so that its rods
are seen working; most of the State Railways' engines of those years had them inside.

A vehicle lies along its own Z, its front towards +Z, with the ground at its origin: its wheels stand on rails whose tops
are 0.3 m up, so set it on a length of track. Its root is an AnimatableBody3D with `scripts/train_vehicle.gd` on it. Put
down by itself it stands still; a `Train` runs several (below). Floors are 1.3 m up (a platform's height), an engine's
footplate 1.8 m, carriage roofs 3.5 m. Buffers touch, which leaves about 1.1 m between two floors and 1 to 1.5 m between
two roofs: gaps he has to jump.

| Scene | What it is, and how he gets about on it | Triangles |
| --- | --- | --- |
| `loco` | A 2-6-0 tender engine, 9.9 m over its buffers. Six coupled wheels and a pony truck, each pair a piece that turns; coupling rods, connecting rods and crossheads that work. He can walk the running plate each side of the boiler, along the top of the boiler, and stand in the cab (open at the back and sides, a way through its front each side of the firebox, steps up to it from the ground). Markers: `Chimney`, `Whistle`, `Lamp`, `SteamL`, `SteamR`. | 3602 |
| `tender` | Six wheels, 6.5 m. Coal heaped in the front of the tank: he walks up and over it from the cab to the tank top, and a ladder goes down the back. | 1166 |
| `carriage` | First class, on two bogies, 14.1 m: a saloon with a clerestory, an open platform with railings and steps at each end. He goes in at either end door and through between the seats (the roof is not drawn while he is inside); a ladder on each end wall goes up through a gap in the canopy to the roof, where the clerestory is a step up along the middle. | 3044 |
| `carriage_third` | Third class, six wheels, 10.5 m: teak, a double roof (flat on top), benches down the sides. Otherwise as the other. | 2156 |
| `van_goods` | A covered van, 7.5 m: doors slid open on both sides, cases and sacks inside, a ladder up the back to its roof. | 1492 |
| `wagon_open` | An open wagon, sides 0.85 m: cases, casks and sacks to climb on. | 1676 |
| `wagon_finds` | The same from the dig: a load roped under a tarpaulin, and a gilded coffin in a crate. | 1472 |
| `wagon_flat` | A flat wagon, 8.1 m: a bare deck, a few baulks of timber. | 1000 |
| `wagon_tank` | A tank wagon: the tank is round, and he keeps his feet only along the top of it. | 1140 |
| `van_brake` | A brake van, 7.9 m: a cabin with look-outs, a platform at the back with the brake wheel, tail lamps, and a ladder to the roof. | 1418 |

A train of six (engine, tender, carriage, open wagon, van, brake van) is 12,400 triangles and about 120 surfaces.

| Scene | What it is |
| --- | --- |
| `track_straight` | Ten metres of line along Z, its middle at the origin: rails, sleepers, ballast. He walks over it. |
| `track_curve` | 15 degrees of a 40 m circle (10.5 m). It starts at the origin going along +Z and bears right; the marker `End` is where the next length starts, turned 15 degrees. Turn it over (scale x by -1) for a left-hand one. |
| `track_points` | A turnout, 20 m: straight on along Z, and a road bearing right (marker `Branch`). It does not move; a `Train` follows its own path. |
| `buffer_stop` | The end of a line. It faces -Z. |
| `level_crossing` | A boarded road across the line with two gates. Lay it over a length of track, the line along Z. |
| `bridge_low` | An iron girder on stone abutments with a road over it, the line along Z through the origin. The underside is 4.63 m up: a train passes, and he on a carriage roof passes only if he ducks. |
| `loading_gauge` | A post and an arm with a bar hung over the line at the same height, to the same end. |
| `signal_semaphore` | A semaphore signal (`scripts/train_signal.gd`): set `clear` and its arm drops. It faces +Z. |
| `telegraph_pole` | A pole with its four wires as far as the next, 30 m along +Z: stand them 30 m apart. |
| `water_tower`, `water_column` | An iron tank on a stone base, with a ladder; a standpipe with its arm out over the line towards +X. |
| `halt_platform` | A platform 18 m by 6 m and 1.3 m high, a ramp at each end. Its edge towards the line is the one at +X: set that 1.62 m from the middle of the track. |
| `halt_shelter` | The halt's building, with an awning towards +X and its name over the door (the Label3D `Name1`: change its `text`). Stand it on the platform. |
| `station_nameboard` | The name on a board on posts (`Name1`, `Name2`). |
| `halt_lamp`, `halt_bench`, `luggage` | A lamp (marker `Flame`), a bench, trunks and a hat box. |

### Making or changing them

They are built by a builder of their own, with the props' tools and in the props' way (one function a thing), which also
says what is solid, where the ladders are and what turns:

```
blender --background --python tools/build_train.py [-- name ...]            # models/train/*.glb and train.json
godot --headless --path . --import
godot --headless --path . --script tools/build_train_scenes.gd [-- name ...]   # props/*.tscn
godot --path . --fixed-fps 60 --resolution 960x960 --script tools/train_sheets.gd -- <folder> [vehicles train dusk moving rods ride world lineside yard]
godot --headless --path . --fixed-fps 60 --script tools/train_test.gd       # he rides it: ends PASSED or FAILED
```

### A train

`Train` (`scripts/train.gd`) couples vehicles and runs them. In the editor it is "Train" on the Railway page (how many
carriages and wagons, its speed, how far it runs, what it does at the end, which way the ride is staged, and the plates
that start and stop it). In code:

```gdscript
var train := Train.new()
train.consist = PackedStringArray(["loco", "tender", "carriage", "wagon_open", "van_goods", "van_brake"])
train.speed = 8.0                       # metres a second; `acceleration` is how quickly it gets there and stops
train.distance = 80.0                   # how far it runs along its own +Z; or give it `path`, a Path3D to follow
train.run = Train.Run.THERE_AND_BACK    # or ONCE, or ROUND (put back at the start: only while nobody is on it)
train.position = where_its_front_buffers_are
add_child(train)
train.start()                           # `stop()`, `toggle()`; signals `started`, `stopped`, `arrived`, `lost(who)`
```

Its wheels turn at the rate for its speed, the engine's rods work, each body rocks a little on its springs (the model
only: what he stands on does not), and the chimney beats smoke four times to a turn of the driving wheels
(`scripts/train_smoke.gd`), with steam from the cylinders as it gets away and sparks if `sparks` is set. It makes no sound.

A ride on it can be staged in two ways.

- **The train moves** (`world_moves` off). He is carried by the vehicle he stands on. While he is off his feet (a jump, a
  fall, hanging from an edge, getting on or off the top of a ladder) the train carries him itself, a step at a time, by as
  far as the vehicle he left has gone: so a jump keeps the train's speed and comes down where it would on a train standing
  still. Whatever stands by the line and is too low stops him while the train goes on, and he is knocked down; if he comes
  down on the ground he is thrown along it.
- **The world moves** (`world_moves` on): the train stands still, its wheels turning and its smoke streaming back, and a
  `TrainScenery` (`scripts/train_scenery.gd`, the train's `scenery`) goes by. Everything that is a child of that node is
  drawn back past the train and comes round again after `span` metres. A child with the metadata `strikes` (the bridge and
  the loading gauge have it) knocks down whoever it meets standing; one with `rest_only` is there only while nothing moves.

For a sequence, the second is the one to use. A ride of two minutes at 10 m/s is more than a kilometre of line, in levels a
few hundred metres across with ground in squares a metre wide; with the train standing still it needs none. Everything he
does (ledges, ladders, ropes, throwing, being chased, the ragdoll) works without knowing about the train, because he is on
something that is not moving; the first way has to move him and what he holds each step from outside the Player, and
anything else that comes aboard (a hound, a thrown pot) would need the same. And a low bridge, a signal or a tunnel mouth
can be sent at him exactly when the sequence wants it. The first way is for a train that arrives, leaves, or is ridden a
short way in a level, as at the halt in the test yard (which has both). What the simple version of the second does not
do: the sand itself does not move (its grain is drawn from where it is in the world), and things come round again with a
pop at half a `span` from the node.

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

## Scarabs and cobwebs

Not scenes in `props/`: each is made whole in code, and placed by the level editor (see "Scarabs" and "Cobwebs" in README.md).

| Class | What it is |
| --- | --- |
| `ScarabSwarm` | A nest of scarabs: this node is the hole they come out of. `harmless` for a few that only wander; `dung_ball` and one rolls a ball. |
| `ScarabAmulet` | RigidBody3D, in the groups `throwable`, `interest` and `scarab_amulets`: a gold and lapis scarab, 14 cm, its origin its middle and its head towards +Z. |
| `ScarabSocket` | A stone 0.5 by 0.3 by 0.6 m with a hollow for the amulet, its foot at the origin. A `TombParts.Plate` that only the amulet presses (`changed`). |
| `Cobweb` | `kind` `CORNER` (the corner is at the origin, `height` above it; one edge runs towards +X along the roof and the other down the wall), `SHEET` (stands on the origin, across X, facing along Z), `HANGING` (hangs from `height` above the origin, spread along X), `DRAPE` (stands on the origin, over something `over` in size). In the group `cobwebs`. |

## Puzzle parts

Not scenes in `props/` either: made whole in code, and placed by the level editor (see "Puzzle parts" in README.md). Each has its foot at its origin unless it says otherwise.

| Class | What it is |
| --- | --- |
| `Lever` | A lever in a stone block 0.5 by 0.32 by 0.6 m, pulled over towards +Z. In the groups `interest` and `workable`. `on`, `returns`, `changed(on)`. |
| `DoorKey` | RigidBody3D, in the groups `throwable`, `interest` and `keys`: a key 30 cm long, its origin its middle and its bit towards +Z. `which` is its metal (`DoorKey.Metal`: iron, bronze, gold). |
| `KeyLock` | A stone post 1.3 m high with a lock plate of its key's metal, the keyhole 0.95 m up, facing +Z. `on`, `changed(on)`. |
| `TimedPlate` | A `TombParts.Plate` that stays down for `seconds`; a sand-glass on a post at its +X edge. |
| `SealStone` | A `TombParts.Plate` with a square of gold in it, that only he presses and that latches. |
| `SunBeam` | The light: from `height` above the origin, along +Z, tipped up by `pitch`. With `stand`, a lens on a stone stand. `path`, `ends_on`, `bounces`. |
| `Mirror` | A bronze disc 0.7 m across on a stand, its middle `height` up; turns about Y by `step` degrees a press. In the groups `mirrors` and (unless `fixed`) `workable`. |
| `SunDisc` | A gold sun between horns on a post, its middle `height` up. `on`, `latches`, `changed(on)`. |
| `Sluice` | A gate of boards in a stone frame 1.5 m wide and 1.85 m high, facing along Z. `open`, `drop`, `speed`; `pool` is the water it works. |
| `OfferingTable` | A stone table 1.4 by 0.8 by 0.8 m. `on`, `latches`, `changed(on)`; `jar` is what stands on it. |
| `ColdBrazier` | `props/brazier.tscn`, not burning until a torch is brought. `on`, `changed(on)`. |

## Inscriptions

Writing in hieroglyphs is not a prop but a thing made in code (`scripts/inscription.gd`, and "Hieroglyphs" in README.md):
"Inscription" on the editor's Stone page is a slab with a text carved in it, or the bare carving to stand against a wall.
The `wall_glyphs` prop, being a model, has its signs as flat shapes instead: `tools/glyph_sheets.gd` with `prop` sets
its two texts out and writes them to `tools/wall_glyphs_signs.json`, which `tools/build_props.py` reads.
