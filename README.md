# Outside

A touch-first 3D adventure in the spirit of Inside: a boy of the 1910s, flat cap and faded blue overalls, in a desert
of dunes, ruins and pyramids. Godot 4.7, built for phones and the web (the Scareathon arcade).

There are two levels: the desert (`desert.tscn`, where the game opens), which is laid out with the level editor
inside the game, and the test yard (`test_yard.tscn`), where every mechanic has a station.

## Controls

- Touch: drag anywhere on the left half to move (a gentle push walks, a full push runs, and held there he sprints); two small buttons bottom right
  duck and act (pick up / throw); tap anywhere else on the right
  to jump, hold for a higher jump.
- Keyboard: WASD or arrows, Space to jump, C or Ctrl to duck, E or F to act, Shift to walk, R to drop him as a ragdoll
  and stand him back up. Gamepads work too.

## What he can do

`test_yard.tscn` is a yard among dunes with a station for each of these set out round it, a sign over each. The camera
orbits there: drag the upper right of the screen, hold the right mouse button, or use a right stick.

- **Sprint** by keeping up a full run for a moment (`sprint_delay`, `sprint_speed` on the Player): he throws himself
  forward and claps a hand to his cap to keep it on: whichever hand is towards the camera. Sprint for long and he is
  winded: when he stops he bends over, hands on his knees, and pants until he has his breath back.
- **Push** a block by walking into it: he leans his chest in behind flat, spread hands and drives it with long slow steps.
- **Sneak** by holding duck: low, on his toes, hands out in front of him. It gets him under what is too low to walk
  under, and he stays down until there is room to stand.
- **Slide** by ducking out of a run, which gets him under things lower still: down on the seat of his trousers, one
  heel out in front, a hand on the ground behind and the other (the one the camera sees) on his cap.
- **Crawl** by sneaking on into something too low to sneak under: he goes down on his hands and knees.
- **Kick off a wall** by jumping again in the air against one (`wall_kick`): he springs away from it, and can go
  from wall to wall.
- **Catch a ledge** by jumping at a wall whose top is within reach. He hangs by his fingers with a foot against the
  wall (sometimes the left, sometimes the right: `favoured_leg` on the rig fixes it); left and right shimmy him along
  it, his feet walking the wall under him; jump clambers up, and pulling back or duck drops him.
- **Land** according to how hard he comes down (`landing_speeds` on the Player): on his feet from a jump; from about
  1.5 m, on one knee and a fist, held a moment; from about 2.3 m he goes on over them, flat on his front, and pushes
  himself up (or, if he is still being steered, scrambles up off his hands at a run); from about 3 m, in a stumble that
  his legs cannot catch up with and that goes over in a roll almost at once; straight over in a roll from 4 m and more.
- **Climb a rope** (`scripts/rope.gd`) by jumping into it; up and down climb, left and right set it swinging, jump
  leaps off with whatever swing it has. The rope is a simulated chain: it bends and swings under him.
- **Climb a ladder** (`scripts/ladder.gd`) by walking or jumping into it; he steps off at the top, jump leaps off backwards.
  Walking out over the top of one from above, he turns round and gets onto it. Left alone on it a moment he hangs
  out from it by one hand to look about.
- **Swim** (`scripts/pool.gd`) when he is in over his chest: a gentle push is breast stroke and a full one a crawl;
  duck dives, where it is a frog kick and a flutter kick; jump comes up, and at the surface heaves him out, or at the
  side takes hold of it to climb out. He walks out up steps, and the first time he stands still afterwards he shakes
  himself dry.
- **Throw**: act stoops for any RigidBody3D in the group `throwable`, act again throws it, with a ball player's
  wind-up, stride and follow-through (`pickup_time`, `throw_time`).
- **Swing a bat**: anything also in the group `bats` is held in both hands and swung instead, and sends flying
  whatever loose thing is in front of him; duck and act puts it down.
- **Shoot**: anything also in the group `guns` (`scripts/gun.gd`, the scenes in `guns/`) is carried as a gun: a pistol
  low at his side, muzzle down; a rifle or shotgun across his body in both hands. Act brings it up and fires it (the
  pistol at the end of a straight arm, his other fist on his hip; a long gun from the shoulder, his off hand at the
  gun's `support_point()`), and he takes the kick in his hands, shoulders and back and is shoved a step backwards
  by it, in proportion to the gun's `kick`. He aims where he faces, helped towards the nearest thing in the groups
  `pursuers` or `interest` within `gun_cone`. Duck and act puts it down; he drops it when he has to swim.
- **Dive roll** by pressing duck just after jumping out of a run (`dive_window`): he throws himself out flat, comes
  down on his hands, goes over a shoulder and is up and running with his speed kept. He is as low as a slide
  through it, so it gets him under things; a dive off a height is still a roll; a dive into water goes in head first.
- **Back tuck** by jumping out of a duck, where there is the height for it: up, over once backwards, and down
  where he started, pleased with himself. (Under anything too low to stand in he still cannot jump.)
- **Spin** by whipping the stick right round (a full turn in about half a second): arms flung out, one leg trailing,
  his cap all but off. He staggers coming out of it, and kept at it long enough he gets so giddy he sits down.
- **Sit and sleep**: left alone for `sleep_after` seconds he yawns and stretches, sits down, and lies down curled on
  his side with his cap over his face; holding duck while standing still does the same sooner (sat after `sit_hold`,
  asleep after as long again). Anything pressed wakes him: he sits up, rubs his eyes and gets up; anything in the
  group `pursuers` giving chase wakes him with a start. Levels can call `Player.sit()`, `sleep()`, `wake()`.
- **Wade**: in water that is not yet over his chest he is slowed, stepping high in the shallows and pushing through
  with his arms up when it is to his waist.

Each of the newer moves has a switch on the Player (`dive_enabled`, `flip_enabled`, `spin_enabled`, `rest_enabled`,
`gun_handling`), all on.

The yard also has everything sand does (footprints, sand running down steep faces, wind and its weather plate, sand
pouring into heaps, two lumps of wet sand), water as a tank and as a pond lying in the sand, a fire, the guns on a
bench with things to shoot, his brother, a cat, and a pen each for the hounds and the mummy, with a plate that lets
them loose and calls them off. North of the start the kinds of ground are laid side by side in a row to walk along.

## Sand, and the other kinds of ground

The ground of a level is a `SandGround` (`scripts/sand_ground.gd`), drawn by the one sand shader (`scripts/sand.gd`).

- **Footprints** in sand are soft, shallow, rounded dents with nothing of the boot in them, and in loose sand a
  collar of it is pushed out round the foot and slumps there.
- **Snow mode**: the crisp print (heel, sole, and the lip round them) is kept for snow. `ground.snow = true` makes the
  whole ground snow: pale (`Sand.SNOW`, unless `colour` is set), crisp prints, nothing runs or is pushed out. Set it
  before or after the ground is built. `ground.crisp_prints = true` alone gives sand that holds the print of a boot;
  `Sand.Kind.SNOW` can be painted where snow lies on other ground; `Sand.snow_surface()` is the material for any
  other mesh.
- **Sand on a steep face** lets go when it is trodden on and oozes downhill as lava does: thick rounded lobes that
  creep, spread, slow and slump, each leaving a low tongue behind it (`SandGround.ooze`; `disturb` sets it off). It is
  the ground itself that swells and moves, not something drawn over it.
- **Kinds of ground**, painted with `ground.paint(kind, at, radius, amount, feather)` or `paint_line`, each fading
  into the next. `Sand.Kind`: `COARSE`, `DAMP`, `PACKED`, `PALE` (as before); `DIRT` (hard dirt, mottled and
  cracked: no prints, no sinking, does not run, and he raises dust on it, not sand); `SANDSTONE` (rock in bands of
  colour: nothing marks it); `WHITE`, `RED`, `BLACK` (sand of another colour, and sand in every other way); `SNOW`.
  `ground.give_at(x, z)` is how soft the ground is at a place (1 loose sand, 0 hard), and `share_at(kind, x, z)` how
  much of a kind has been painted there.
- **Sand thrown up** by feet (`SandSpray`) is many fine grains that are flung out and come straight back down in
  arcs, drifting a little in the wind.

`tools/sand_sheets.gd` walks and runs him over all of it in the test yard and saves pictures (see the top of the file).

## The level editor

In the desert, Menu, then "Edit this level". The game stands still and the view goes up over him.

- **Looking about**: one finger drags the ground; two pinch to come nearer and turn to turn; the slider at the left
  tips the view. (Mouse: drag, wheel, right button.)
- **Putting things in**: the pages down the left (Ground, Water, Stone, Camp, People, Puzzle, Guns) fill the strip
  along the bottom. Touch one, then touch the ground.
- **Changing them**: touch a thing to choose it; its sliders come up at the right, with Move to, Copy, Remove. Drag it
  by its mark to move it.
- **The ground**: "Level" has the desert's size, the height and number of its dunes, the wind and the weather.
  Level ground, dunes and ridges placed by hand, ponds and rivers are things like any other: a river is a line of
  points to drag and add to, and the ground is cut away under water and made again a moment after any change.
- **Pyramids**: on the Stone page, "Stepped pyramid", "Finished pyramid" and "Fallen pyramid" are one thing made from
  numbers (`scripts/pyramid.gd`), set out three ways: its width, steepness and the height of a course, how much of
  its smooth casing is left, a gold cap, how ruined it is and which ruin, a doorway, and its stone. Move a slider and
  it is built again. (The Great and Ruined pyramids beside them are fixed models.)
- **Heat**: "Level" also has the heat mirage: how much the distance swims, and whether pools of sky lie on the far
  sand. 0 is none.
- **People**: townspeople (who, and how far they wander), his brother, a cat, hounds (which give chase when he comes
  within their distance, or when something sets them on) and the mummy.
- **Puzzles**: pressure plates, targets and things that smash are either on or off; a door, a bridge or lift, a sand
  fall, a hound or the mummy has "Choose what works it": touch the plates and targets that should, and lines show
  what is joined to what. Also ropes, ladders, blocks to push, checkpoints, signs, and where he starts.
- **Keeping it**: every change is saved on the device as it is made (`user://desert_layout.json`) and is what the
  game plays from then on. "More" shows the whole level as text, to copy off the phone or paste one in, and has
  "Back to the original level". Pasted into `levels/desert.json`, a level becomes the one the game ships with.
- Undo and Redo go back and forward through the last forty changes. "Play" starts from the start; "Play here"
  from the middle of the view.

The layout is plain data (`scripts/level_layout.gd` says what is in it); `scripts/desert.gd` makes the level from
it, and `scripts/level_editor.gd` is the editor. To check the editor without a phone:

```
godot --path . --resolution 1280x720 --script tools/editor_test.gd -- <folder>
```

## How he moves

Nothing is a clip; `scripts/character_rig.gd` poses him every frame.

- **His back** is three joints and his neck two, and every lean, twist and curl is shared along them.
- **Standing** he has two ways of being: at ease, weight on one leg and shifting to the other every so often, or
  wary (feet apart, knees bent, hands half closed) while anything in the group `pursuers` is after him.
- **He looks at things**: whatever is chasing him first, otherwise the nearest node in the group `interest` that is
  close and not behind him, for a few seconds at a time. Blocks, crates, rocks and pressure plates are in it; add
  anything else worth a glance.
- **His hands** close to fists when he runs, open when he falls, and lie flat with the fingers spread on anything
  he leans on or pushes. The Player says which way that surface faces in `hand_normal`.
- **His feet** roll: heel first on the outer edge, in across the sole, then up onto the ball. They are turned out, land
  nearer the line he is walking than his hips are wide, and never quite where they did last time. Off the ground the
  ankle is slack: the foot hangs from it on a spring, trailing the leg and swinging a little past, toes after it.
- **Nothing moves all at once**: shoulders answer the hips late, the forearm the upper arm, the hand the forearm, and
  the head nods to each footfall, which jolts him. His right arm swings the freer. `looseness` on the rig scales all
  of this; the mummy is given very little.
- **He runs like a boy who is growing**: long legs, long strides, thrown forward into it and banking into his turns.
- **Getting onto a ledge** is drawn by hand as curves (the `CLIMB_` constants in the rig) and placed from the ledge
  itself, not from wherever the body under him is.
- **On stairs** his feet go on the treads. The Player looks along his way for a flight (two risers or more: a kerb
  or a ramp is not one) and says so in `on_stairs`, `stair_rise`, `stair_run`; the rig then steps one tread at a walk
  and two at a run, knee high going up, toes first coming down.
- **A jump has a take-off, a top and a landing.** The leg that drives him off the ground is left stretched out behind,
  reaching for where it stood, toes last; from a standstill that is both legs, and he goes up stretched out. Over the
  top he gathers: knees up from a standstill; out of a run the front leg swings out ahead and the back one folds up
  behind. Coming down he reaches for the ground, lands on the leg he is reaching with (his stride is taken up again
  from there), and gives at the knees, coming up out of it more slowly than he went down (`LAND_GIVE` in the rig).
  Which of the three he is in goes with how fast he is rising or falling, so a short hop and a long drop both work.
- **In the air his arms are thrown, not posed**: each follows where it is wanted on a spring, forearm after upper arm.
- **Rolled up in a ball** (a hard landing, a dive, a back tuck) his legs are placed from his hips and go round with
  him: knees apart either side of his chest, heels under his seat. They are the last of him to be drawn in: off his
  feet they are still on the ground for a moment, and out of a dive they come over the top after him.
- **His cap** is an object of its own on a bone of its own (`cap`), and rides on his head on a spring: it lifts and
  tips with every jolt, unless he has a hand on it.
- **Dust** (`scripts/dust.gd`) puffs up where his feet come down, where he lands, and along the ground as he slides,
  skids or rolls: pale discs that swell and thin out into rings. `dusty` on the rig turns it off.
- **His curls** hang from bones of their own and swing on springs (`Dangle` in the rig; a figure with bones named
  `hem_0`... gets a swinging hem the same way). This stands in for cloth: a real cloth simulation was not used,
  because it is costly and unreliable on a skinned figure in a web build.

## Menu

The Menu button (top right, or Esc) swaps every figure between its full and demade model, switches the world between
smooth and banded light, dresses the boy (his face, hair, skin, eyes and clothes, a colour for each thing he wears,
and his cap on or off), changes level,
and restarts. Colours last until the game is closed.

## Layout

| File | What it does |
| --- | --- |
| `scripts/player.gd` | The controller: movement, jumping, stairs, pushing crates, respawn |
| `scripts/character_rig.gd` | Animates the model in code: gait, leg IK, a jointed back, hands, looking about, and the swing of hair and hem |
| `scripts/touch_controls.gd` | Floating stick and jump area |
| `scripts/follow_camera.gd` | The camera: a fixed side view (the tomb) or a third-person orbit (the yard) |
| `scripts/desert.gd` | The desert (`desert.tscn`): makes the level from its layout, and runs its puzzles, checkpoints and people |
| `scripts/level_layout.gd`, `scripts/level_editor.gd` | What a level is made of, as data; and the editor inside the game that changes it |
| `scripts/desert_terrain.gd` | The desert's ground: dunes, level ground, and water cut into it |
| `scripts/pyramid.gd` | A pyramid made from numbers: stepped core, smooth casing, gold cap, ruin (fallen corners, rubble, missing and slipped blocks), a doorway; its mesh and what is solid |
| `scripts/sandstone.gd` | Stone drawn by a shader: blocks in courses, strata, weathering, cracks, rubble; and gold (`Toon.sandstone`, `Toon.gold`) |
| `scripts/heat_mirage.gd` | Heat over the desert: far things near the level of the eye swim, and pools of sky lie on the far sand |
| `scripts/tomb_parts.gd` | Torches, pressure plates and stone doors |
| `scripts/test_yard.gd` | The test yard (`test_yard.tscn`) |
| `scripts/rope.gd` | A rope to climb and swing on, simulated as a chain |
| `scripts/ladder.gd`, `scripts/pool.gd` | A ladder; a box of water to swim in |
| `scripts/dust.gd` | Puffs of dust, drawn all at once as one MultiMesh |
| `scripts/toon.gd` | Cel shading: two flat tones for the figures, and optionally the world; a shader for hair; the pinstripe in his shirt |
| `scripts/menu.gd`, `scripts/settings.gd` | The in-game menu and what it remembers |
| `scripts/mummy.gd` | The mummy: dormant until disturbed, then lurches after the player; within reach it rears back and swipes an arm at him, and catches him only if the arm finds him |
| `scripts/mummy_rig.gd` | Its own way of moving, laid over the boy's rig: a step and a dragged leg, the swipe, and its loose bandages swinging as chains |
| `tools/build_mummy.py` | Builds the mummy in Blender: its proportions, the face under its wrappings, and a chain of bones down each loose end |
| `tools/mummy_sheets.gd` | Not part of the game: drives the mummy through each thing it does and saves pictures of it |
| `scripts/hound.gd` | A hound, of either breed: chases the player, leaps obstacles and gaps, bays and barks (recordings of dogs, in `audio/hounds/`), braces and barks under what it cannot reach, and plays, sits and sleeps when left alone |
| `scripts/hound_rig.gd` | Animates a hound in code: walk, trot and rotary gallop on three-jointed legs, spine flex, a jaw that keeps time with its voice, a head that watches things, sitting, lying and the bow, a tail on springs, and ears that hang and swing or stand and turn |
| `scripts/fur.gd` | The hound's coat: streaked along the lie of the hair, with a few shells stood off it |
| `scripts/cat.gd` | A cat: wanders, watches the boy, follows him, rubs round his legs, stalks, sleeps in the sun, and goes up out of reach of anything in the group `pursuers` (recordings of cats, in `audio/cat/`) |
| `scripts/cat_rig.gd` | Animates a cat in code, on the hound's rig: the walk that puts each hind paw in the fore paw's print, trot and bound, stalking and springing, jumping up and down, sitting, lying, curled asleep, stretching, washing, and a tail, ears, eyes and whiskers that say what it feels |
| `tools/hound_sheets.gd` | Not part of the game: drives the hounds through each thing they do and saves pictures of it |
| `tools/cat_sheets.gd` | Not part of the game: the same for the cat |
| `tools/cat_test.gd` | Not part of the game: runs a cat with nothing drawn and checks that it wanders, watches, flees a hound up onto something and comes down |
| `tools/build_boy.py` | Builds the boy in Blender: one continuous body, modelled in a T-pose, in shirt, patched overalls and curls, and his cap as a separate object |
| `tools/pose_sheets.gd` | Not part of the game: drives the Player through each thing he does and saves pictures of it |
| `tools/build_hound.py` | Builds the two hounds in Blender from two lists of measurements |
| `tools/cut_hound_audio.py` | Not needed to run the game: cuts the hounds' voices out of the recordings they come from |
| `tools/build_cat.py` | Builds the two cats in Blender, the way the hounds are built |
| `tools/cut_cat_audio.py` | Not needed to run the game: cuts the cat's voice out of the recordings it comes from |
| `tools/build_character.py` | Holds the tools `build_boy.py`, `build_hound.py` and `build_mummy.py` use |

Tuning values are exported properties on the Player, Camera and TouchControls nodes.
Set `move_mode` to `SIDE_SCROLL` on the Player to lock movement to a line.

## The models

`models/boy.glb`, `models/hound.glb`, `models/hound_pharaoh.glb` and `models/mummy.glb` are generated by Blender scripts (editable copies are saved to `tools/*.blend`):

```
blender --background --python tools/build_boy.py
blender --background --python tools/build_hound.py
blender --background --python tools/build_mummy.py
```

`scripts/character_rig.gd` reads each figure's proportions from its skeleton, so the boy and the mummy can differ freely.
It also uses whichever of the optional bones a figure has (chest, neck, fingers, hem, hair). The mummy has a back, a neck and fingers, and bones of its own (`drape_...`) that only `scripts/mummy_rig.gd` knows about.

The boy's colours are the `MATERIALS` list at the top of `tools/build_boy.py`. A material named `hair` is given the
hair shader (`Toon.HAIR_SHADER`): strands of differing tone, darker roots, and a broken band of light across the curls.
One named `hairwavy` is given the other (`Toon.WAVY_HAIR_SHADER`), in the same colour: the strands swing from side to
side in long S-curves, the surface is shaded as if it rose and fell with them, and each crest carries one broad band
of light. Which a cut of hair has is decided where it is built (`CUTS` in `tools/build_boy.py`).

The boy and the townspeople are one model, and what can be chosen for it is in `scripts/character_look.gd`: faces,
cuts of hair, clothes and colours (`tools/build_boy.py` builds an object for each choice, under "Other turn-outs").

- **Hair.** His own curls are ringlets. Every other cut is one surface over the head, modelled in locks, growing from
  a whorl at the back of the crown, or falling from a parting, or drawn back to where it is tied; the crown is filled
  out above the temples so that it is round, not an egg. There are sixteen: mullet, long curls, cropped, pudding
  basin, side parting, combed back, centre parting, pompadour and big curls; bob, waved bob, plaits, ponytail, low
  knot, pompadour and knot, and long waves with a bow.
- **Faces.** `sculpt` is a head of its own with the face modelled into it (brow ridge, eye sockets, a nose with a
  bridge and a tip, cheeks, lips, chin and a flat jaw), kept to a few broad forms. Its eyes are balls set in the
  sockets, white with a ring of colour (`iris`, which the dresser and `CharacterLook.random` choose) and a dark
  middle, each on a bone (`eye_l`, `eye_r`): the rig turns them to what he looks at before his head follows, and
  brings them back to the middle as it catches up. The other faces are features set on a plain egg.

`tools/look_sheets.gd` draws all of it (`faces`, `eyes`, `hair`, `outfits`, `skin`, `random`, `crowd`, `menu`; see its
header).

To see what a change to the model or the rig has done, without playing through it:

```
godot --path . --fixed-fps 60 --resolution 960x960 --script tools/pose_sheets.gd -- <folder> [hang climb sneak ...]
```

writes a sheet of pictures for each (see the list in the script's `run`); with no names, all of them. Add `lo` to
the names for the demade model. Its window is kept off the screen and takes no input, so it can run while you work.
`stairs` among the names prints how fast he gets up a flight and draws him going up and down two flights (one
shallow, one steep) at a walk and a run; `jump` also draws every other frame of a jump; and `rope`, `kick`, `swim`,
`ladder`, `bat`, `crawl`, `tired`, `throw`, `sprawl`, `scramble` and `hatless` draw what their names say, most of them
as several sheets (`swim_in`, `swim_out`, `ladder_top`, `rope_climb` and so on). `dive`, `dive_edges`, `flip`, `spin`,
`sit`, `sleep`, `gun` (add `revolver`, `rifle`, `shotgun` or `flare_pistol` for just that one), `wade` and
`stairs_sprint` draw the newer moves as strips a few frames apart, and print the edge cases they test.
A picture cannot show a joint that shakes, so the same run also watches every bone on every frame and prints, under
each sheet, a line `SHAKE <sheet>` and the bones that turned back on themselves from one frame to the next (`shakes`),
or whose turning changed by more than a few degrees in one frame (`jump`, a flip if it is near 180), and the frame it
was worst on. `SHAKE_TRACE=<bone>` in the environment prints that bone's turn on every frame. `jump` also draws
`jump_close` and `jump_round`: the knee coming up, from close and from all round. `roll` draws the two rolls from
close to, every other frame (`roll_land`, `roll_dive`, and each again from three quarters), and prints a line `LEGS`
for every frame: how high each knee, ankle and toe is off the ground, how far each is from his chest and his head,
and whether his ankles have crossed (`LEGS_WHERE=1` adds where his head and knees are from his hips). Whatever he
does by chance (which knee goes down, how his arms fly) he does the same way each time a sheet is drawn, so two runs
can be compared.
The hounds' rig reads their joints from their skeletons too, so the two breeds can differ in any measurement.

## The hounds

There are two breeds (`breed` on the Hound; left at `ANY`, the hounds of a scene take turns, so a pair is one of each):

- the **bloodhound** (`models/hound.glb`): heavy in the head and the bone, hanging lips, a dewlap, a folded brow, and long
  ears that hang and swing; it mostly bays, and its voice is the deeper;
- the **pharaoh hound** (`models/hound_pharaoh.glb`), the jackal of the tomb paintings: lean and leggy, with tall pointed
  ears that stand, come forward when it is after something, turn aside to listen, and lie back flat when it runs; it mostly barks.

They are separate models built by one script from two lists of measurements (`tools/build_hound.py`), on the same bones.
Their legs are three bones and a paw (upper arm, forearm, pastern; thigh, shank, hock), and at a gallop they are clear of
the ground twice a stride. Their voices are recordings of dogs (`audio/hounds/`, credited in `CREDITS.md` there).
They are a little faster than the player; being caught knocks him down as a ragdoll, and that, or falling, restarts the chase.

Until they are let loose they play (bows, barks, jumps aside, a run round each other), then sit, then lie down and
sleep; `play_time`, `settle_after` and `sleep_after` on the Hound set how long each lasts. Hunting, a hound that is
getting nowhere (he is up on something) drops onto braced forepaws under him and barks. They watch the player first,
otherwise each other or anything in the group `interest`.

Their gaits follow measurements of dogs (the sources are in the comments at the top of `scripts/hound_rig.gd`). To see them:

```
godot --path . --fixed-fps 60 --resolution 960x960 --script tools/hound_sheets.gd -- <folder> [walk trot gallop bay bow play sit sleep look fur ...]
```

Add `pharaoh` for the prick-eared hound, `lo` for the demade models, `pale` for a light coat that shows the shape; the
names beginning `m_` (`m_wag m_ears m_breath m_bark m_gallop m_stop`) are strips of consecutive frames, for watching how a thing moves.

## The cat

`Cat.new()` is a whole cat (`scripts/cat.gd`). None is placed in a level yet; to put one in:

```gdscript
var cat := Cat.new()
cat.coat = Cat.Coat.BRONZE   # SILVER, BLACK, RUDDY: the lean temple cat. TABBY, GINGER: the heavier house cat
cat.tame = 0.6               # over a half, it comes and rubs round the boy's legs when he stands still or crouches; under a quarter, it will not be come up to
cat.curiosity = 0.6          # over a half, it follows him about at a distance
cat.position = Vector3(x, y, z)
add_child(cat)
```

Left alone it wanders within `roam` of where it was put, sits and watches the boy, washes, now and then stalks something
in the group `prey` or `interest` and springs on it, and after `nap_after` seconds finds a place the sun reaches and
sleeps for `nap_length`, waking with a yawn and two stretches. Anything in the group `pursuers` that comes within
`fear_distance` sends it up onto the nearest flat thing that is higher than the pursuer can jump and no higher than its
own `jump_height` (it looks for one itself; a `Marker3D` in the group `perches` points one out), where it stays, bristling
and then merely cross, until they have been gone a while. With nothing to get up on it runs. `cat.hear(place)` turns its
ears to a sound. `voice = false` makes it silent.

There are two models built by one script (`tools/build_cat.py`: `models/cat.glb` and `models/cat_tabby.glb`, and a demade
`_lo` of each), on the hound's bones plus a back in six pieces, a tail of seven, shoulder blades, toes, eyelids, pupils and
whiskers. Their markings are not a texture: the fur shader draws spots, bars, rings and a pale belly from the lie of the
hair, where the model says each goes. `CatRig` (`scripts/cat_rig.gd`) extends `HoundRig` and uses its leg solver, paw
path, springs and breathing unchanged; the gaits, the back, the postures and everything about its face and tail are its
own. The sources it follows are in the comments at the top of that file. To see it:

```
godot --path . --fixed-fps 60 --resolution 960x960 --script tools/cat_sheets.gd -- <folder> [walk trot bound stalk sit loaf side curl wake groom tails look rub fur flee m_walk m_bound m_pounce m_up m_down m_lash m_blink m_ears ...]
godot --headless --path . --fixed-fps 60 --script tools/cat_test.gd
```

Add a coat's name (`silver`, `black`, `tabby`...) or `lo` to the first. Under each gait it prints how far ahead of the
fore paw's print the hind paw of that side came down.

## The camels

`Camel.new()` is a whole camel (`scripts/camel.gd`): a dromedary, about 1.7 m at the withers and 2 m at the top of its
hump. The level editor places one ("Camel" on the People page: saddled, carrying packs, tethered, couched, and how far it
roams), and there are two in the test yard. To put one in by hand:

```gdscript
var camel := Camel.new()
camel.saddled = true                     # a riding saddle on a blanket; `packed` for saddlebags, `haltered` for a rope halter
camel.couched = true                     # it starts couched, and stays so for `rest_for` seconds
camel.tether = Vector3(x, y, z)          # tied to a peg there, on `tether_length` of rope (and so haltered)
camel.position = Vector3(x, y, z)
add_child(camel)
camel.follow(someone)                    # led on its rope at a walk; `follow(another_camel)` puts it in a string behind that one
```

Left alone it stands, shifting its weight and resting one hind leg and then the other, chews the cud (the jaw goes round
sideways), wanders within `roam` of where it was put, puts its head down to browse (on anything in the group `fodder`
that is in reach, or else at its feet), and after `rest_after` seconds on its feet kneels and couches for `rest_for`,
dozing if no one is near. It turns its head to the boy within `notice_distance`, and shies from anything in the group
`pursuers` within `fear_distance`: up, groaning, and away. A caravan is a string: lead the first, and have each of the
others `follow` the one in front.

It walks and it paces: both legs of one side go forward together, so it rolls from side to side as it goes, and its
neck pumps. Flat out it gallops. It gets down forelegs first (onto its knees, rump in the air, then its hind legs fold,
then it settles onto its chest) and gets up hindquarters first. The sources for all this, and what is measured and what
is only chosen to look right, are in the comments at the top of `scripts/camel_rig.gd`; `CamelRig` extends `HoundRig`
and uses its leg solver, foot path, springs and ears unchanged. The model is built by `tools/build_camel.py`
(`models/camel.glb` and a demade `camel_lo.glb`) on the hound's bones plus a neck in four pieces and eyelids; its tack
is separate meshes on the same skeleton. Its voice is two recordings of a camel groaning (`audio/camels/`, credited in
`CREDITS.md` there); `voice = false` makes it silent.

It is not ridden yet. `camel.seat()` is where a rider would sit, and `mount()` / `dismount()` are there to be written.
Like the hounds and the cat, it and the player pass through each other.

```
godot --path . --fixed-fps 60 --resolution 960x960 --script tools/camel_sheets.gd -- <folder> [turnaround tack walk pace gallop couch browse look led tethered shy fur m_walk m_pace m_gallop m_kneel m_rise m_chew m_idle m_turn ...]
godot --headless --path . --fixed-fps 60 --script tools/camel_test.gd
```

Add `lo` for the demade model or `bare` for no tack. Under each gait it prints when each foot came down in the stride
(at a pace the fore foot lands 0.02 to 0.05 of a stride after the hind foot of its own side, and the two sides half a
stride apart), how far a planted foot slid, and how far it rolled; and after each `m_` strip, any bone that shook or jumped.

## Demade models

The same scripts also build low-poly, flat-shaded versions (`models/boy_lo.glb`, `models/hound_lo.glb`,
`models/hound_pharaoh_lo.glb`) on the same skeletons. Switch to them from the menu.

## Ragdoll

`Player.ragdoll(impulse)` drops the body as jointed rigid bodies from whatever pose it is in; `Player.recover()` stands
it back up where it lies, and `respawn()` also ends it.

## Guns

Four guns of the 1910s, each a scene in `guns/` to drag into a level or instance in code, and each a `Gun`
(`scripts/gun.gd`): a RigidBody3D in the groups `throwable`, `interest` and `guns`, its origin at the grip, its
barrel along -Z. Whoever holds one calls `gun.fire(self, aim)`; the gun does the rest (works its own action,
reloads from its spare rounds when the trigger is pulled on nothing, and says so with the signals `fired`, `cycled`,
`reload_started`, `reloaded`, `dry_fired`).

| Scene | What it is | Holds / spare | Between shots | Reload | Damage | Kick |
| --- | --- | --- | --- | --- | --- | --- |
| `revolver` | A break-top service revolver | 6 / 18 | 0.45 s | 2.6 s | 35 | 0.5 |
| `rifle` | A bolt-action magazine rifle (two hands) | 10 / 30 | 1.1 s | 3.2 s | 80 | 1.0 |
| `shotgun` | A double-barrelled hammer gun (two hands) | 2 / 12 | 0.35 s | 2.4 s | 8 pellets of 12 | 1.4 |
| `flare_pistol` | A brass signal pistol: fires a `Flare` that flies, bounces, and burns for nine seconds, lighting a room | 1 / 6 | 0.4 s | 1.8 s | 15 | 0.35 |

- **What is hit** is told: a method `shot(by, at, direction, damage)` on the collider or a node above it is called
  (or `struck(by, impulse)`, as for a punch); loose bodies are pushed. The top of `scripts/gun.gd` has the details,
  and how a surface says what it is made of (the metadata `surface`).
- **What it looks and sounds like** is `scripts/gun_fx.gd`, one node for the whole scene: flash and its light, smoke,
  sparks, chips, bullet marks, tracers, spent cases, and a row of cartridges over the gun that shows what is left in
  it (there is no other display; `show_rounds` on the gun turns it off). The sounds are recordings (`audio/guns/`,
  credited in `CREDITS.md` there, cut by `tools/cut_gun_audio.py`); a kind with no recording is made up from noise.
- **Things to shoot** (`guns/`): `target_board` falls over and stands up again, `target_gong` rings and swings
  (`scripts/shoot_target.gd`); `target_pot`, `target_jar`, `target_jackal` and `bottle` smash into pieces cut from
  their own models, and `tin_can` jumps (`scripts/breakable.gd`; set `comes_back` for a range). `ammo_box` fills the
  gun of whoever walks up to it.

They are modelled by `tools/build_guns.py` and made into scenes by `tools/build_gun_scenes.gd`, which also holds each
gun's numbers:

```
blender --background --python tools/build_guns.py [-- name ...]
godot --headless --path . --import
godot --headless --path . --script tools/build_gun_scenes.gd
godot --path . --fixed-fps 60 --resolution 960x960 --script tools/gun_sheets.gd -- <folder> [looks fire reload rounds targets flare] [revolver ...]
godot --headless --path . --fixed-fps 60 --script tools/gun_test.gd      # every gun fires, runs dry, reloads, hits things
godot --headless --path . --script tools/gun_audio_check.gd              # length, peak and level of every recording
```

## Web build

```
godot --headless --path . --export-release Web build/index.html
```

`build/` is committed and served by GitHub Pages at https://sclondon.github.io/Outside/build/index.html
