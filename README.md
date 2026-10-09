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
- **Swing on a rope** (`scripts/rope.gd`) by jumping into it (he catches one at arm's length if he is going its way).
  The stick throws his weight about, whichever way it is pushed as the camera sees it: with the swing it builds it,
  against it checks it, and left alone it dies away (`rope_pump`, `rope_brake`, `rope_swing_limit` on the Player).
  Act, held, climbs; duck lets him down it, and off the end; climbing on at the top takes him onto a ledge there if
  there is one. A shorter rope swings quicker. Jump lets go, and he keeps what the swing gave him: let go as it
  rises ahead of him, it throws him forward and up (`rope_leap`). His legs go with it, kicked out ahead on the way
  forward and folded back behind on the way back. While he is on it he is a weight on a line (`load_at`), the rope
  above him pulled straight and the rest trailing; nobody on it, it is a chain that hangs and swings.
- **Throw a grappling hook** (`scripts/grapple.gd`): anything in the group `grapples`. Carrying it, the nearest thing
  in front of him that a hook will hold on (a `GrapplePoint`, `scripts/grapple_point.gd`, or anything in the group
  `grapple_points`), within its `reach`, above him and in plain sight, has a ring drawn over it. Act throws the hook
  there; it bites, its rope takes him off his feet and he is swinging on it as on any rope. When he lets go the hook
  comes away and he winds it in. With nothing in reach the throw falls short. Duck and act puts it down.
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
  The pickaxe, the shovel, the turia and the khopesh (`props/`) are swung the same way; there is no one-handed
  cut for the khopesh yet.
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
bench with things to shoot, a dig (tools to pick up, the helmets on stands, someone wearing one), his brother, a cat, and a pen each for the hounds and the mummy, with a plate that lets
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

In the desert, the notebook (top right), Places, then "Edit this level". The game stands still and the view goes up over him.

- **Looking about**: one finger drags the ground; two pinch to come nearer, turn to turn, and slid up or down together
  tip the view. For one hand there are + and - and a slider at the left. (Mouse: drag, wheel, right button.)
- **On a phone**: everything is sized for a thumb and kept clear of the ends of the screen. "Panel" puts the panel at
  the right away to see more of the level (choosing a thing brings it back); a thing is dragged by its ring and moves as
  far as the finger does, or a step at a time with the arrows in its panel (the step is beside them); the pages down
  the left scroll; "?" says all this again. Text (a sign, a level pasted in) brings up the phone's keyboard.
- **Putting things in**: the pages down the left (Ground, Water, Stone, Camp, Dig, People, Puzzle, Guns) fill the strip
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
  within their distance, or when something sets them on) and the mummy, of whichever kind ("Kind": see The mummies).
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

The menu is the boy's field notebook. It lies in the top right corner of the screen: touch it (or Esc, or Start on a
gamepad) and the book comes up over the stopped game, its cover swings open, and its pages are the menu. Touching
anywhere off the book, the corner again, the "Put away" strap or Esc puts it away. Tabs down its edge turn to each
part (a finger drawn across the pages, Page Up and Page Down, or a gamepad's shoulder buttons turn too); the arrow
keys or a stick move a red mark from one thing to the next, and Enter or the jump button works it.

- **Journal**: what the game has written in it. Anything new puts a red mark on the notebook in the corner, and is
  what the book then opens at.
- **Me**: dresses the boy: his face, hair and clothes from lists, his cap and a backpack as boxes to tick, a helmet,
  paints for his skin, hair and eyes, and a scrap of each thing he wears (touch a scrap, then one of the thirty
  paints). "Any old how" is all of it at random; "As he was" puts him back. A photograph stuck in the page is him
  as he stands, so every change is seen as it is made.
- **Places**: the levels, on a map and as a list; "Start this place again"; and, in the desert, "Edit this level".
- **Notes**: figures in full or demade, the world's light smooth or in bands (either starts the level again), and
  how he is moved about.

What is chosen lasts until the game is closed.

The game writes in the journal through `Notebook` (`scripts/notebook.gd`), from anywhere:

```
Notebook.note("The door in the east wall will not move.", "Wednesday")   # a paragraph, under a heading if given
Notebook.task("Find what works the east door", "east_door")              # a box to tick...
Notebook.done("east_door")                                               # ...and ticking it
Notebook.find("Pot, red ware", "By the fallen column. 7 in. high.", "pot")  # numbered as it comes, drawn small beside
Notebook.sketch("eye", "Cut over the door.")                             # a drawing with a line under it
Notebook.translation(signs, "An offering which the king gives...", "North wall")
```

A drawing (and the signs of a translation) is the name of one of `NotebookInk.SKETCHES`, a `Texture2D`, or a
`Callable(on: CanvasItem, rect: Rect2)` that draws it: so whatever reads real hieroglyphs can hand over a picture of
the signs, or a function that draws them, with what they say. The five entries in a new game are placeholders
(`Notebook.placeholders`).

Everything in the book is drawn in code (`scripts/notebook_ink.gd`: paper, ruling, stains, pencil lines that waver,
paint and cloth). The writing is Patrick Hand, by Patrick Wagesreiter, under the SIL Open Font Licence
(`fonts/PatrickHand-Regular.ttf`, licence in `fonts/OFL.txt`). To check the notebook without a phone:

```
godot --path . --resolution 1280x720 --script tools/notebook_test.gd -- <folder>
```

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
| `scripts/rope.gd` | A rope to swing on and climb: a pendulum under whoever is on it, a chain otherwise |
| `scripts/grapple.gd` | A grappling hook on a coil of rope: finds what it will catch, flies there, hangs a rope from it, is wound back in |
| `scripts/grapple_point.gd` | Somewhere a hook will catch; marks them on props of its own accord |
| `scripts/ladder.gd`, `scripts/pool.gd` | A ladder; a box of water to swim in |
| `scripts/dust.gd` | Puffs of dust, drawn all at once as one MultiMesh |
| `scripts/toon.gd` | Cel shading: two flat tones for the figures, and optionally the world; a shader for hair; the pinstripe in his shirt |
| `scripts/menu.gd`, `scripts/settings.gd` | The in-game menu, which is his notebook, and what it remembers |
| `scripts/notebook.gd`, `scripts/notebook_ink.gd` | What the game has written in the notebook's journal (`Notebook.note(...)`); and the pencil, ink and paper its pages are drawn with |
| `tools/notebook_test.gd` | Not part of the game: takes the notebook out, works every page of it with touches and keys in both levels, checks each took effect, and saves pictures |
| `scripts/worn.gd` | What a figure wears that is not part of its model: the backpack and the helmets (`Worn.put_on(figure, &"helmet_anubis")`) |
| `scripts/gear_prop.gd` | A prop whose gold, bronze and brass shine |
| `tools/worn_sheets.gd` | Not part of the game: draws what is worn on everyone who can wear it, and the boy moving in it |
| `scripts/mummy.gd` | The mummy: dormant until disturbed, then lurches after the player; within reach it rears back and swipes an arm at him, and catches him only if the arm finds him |
| `scripts/mummy_rig.gd` | Its own way of moving, laid over the boy's rig: a step and a dragged leg, the swipe, and its loose bandages swinging as chains; and what the other kinds' rigs share |
| `scripts/mummy_priest_rig.gd`, `mummy_brute_rig.gd`, `mummy_crawler_rig.gd`, `mummy_child_rig.gd`, `mummy_royal_rig.gd` | How each of the other kinds of mummy walks and strikes |
| `tools/build_mummy.py` | Builds the mummies in Blender: their proportions, the face under the wrappings, a chain of bones down each loose end, and what each kind has of its own |
| `tools/mummy_sheets.gd` | Not part of the game: drives a mummy of any kind through each thing it does, saves pictures of it, and says which bones shook and whether its feet slid |
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

`models/boy.glb`, `models/hound.glb`, `models/hound_pharaoh.glb`, `models/mummy.glb` and the other mummies (`models/mummy_priest.glb`, `mummy_brute`, `mummy_crawler`, `mummy_child`, `mummy_royal`) are generated by Blender scripts (editable copies are saved to `tools/*.blend`):

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

## The mummies

`Mummy.new()` is the first mummy. Setting `kind` before it goes into the scene makes one of the others
(`mummy.kind = Mummy.Kind.PRIEST`); the level editor has it as "Kind" on a mummy, and the test yard has one of each in a
row, woken and put back by the one plate. Each has its own model (and a demade `_lo`), its own rig, and its own numbers
(`KINDS` in `scripts/mummy.gd`, which sets the mummy's properties of the same names):

| Kind | What it is | How it walks | How it strikes | Speed | Reach | What stops it |
| --- | --- | --- | --- | --- | --- | --- |
| `SHAMBLER` | The first: long arms, a hump, loose bandages | A falling step and a dragged leg, in lurches | Rears, and swipes one arm (every third time both) | 1.3 m/s | 1.4 m | A pit; steps up 0.3 m |
| `PRIEST` | 2 m tall and gaunt, a long skull, a kilt apron and a red stole | Stiff and upright on straight legs, arms crossed, even | Bows from the hips and brings both hands down, far in front but only straight ahead; slow to turn | 1.35 | 1.8 | Any kerb; will not step down more than 0.5 m |
| `BRUTE` | Squat and very heavy, knuckles near the ground | Waddles: rolls over each foot in turn, stamps | Sweeps one arm round level at chest height, so ducking gets under it; every third time both down from overhead | 0.95 | 1.75 | Narrow gaps (it is 0.84 m wide) |
| `CRAWLER` | What is left from the thighs up, trailing its wrappings | Hauls itself along on its hands, in surges | Throws itself at his ankles: jump over it | 2.3 | 1.6 | Any kerb; but it is 0.7 m high and goes under things, and over any edge |
| `CHILD` | 1 m, a big head, a sidelock | Scuttles on its toes in bursts, and stops dead to look | Springs at him from close to | 2.9 in a burst, about 1.8 over all | 1.0 | Little: up 0.5 m, down 2 m |
| `ROYAL` | A gold mask, striped headcloth, broad collar, crook and flail crossed on its chest | Glides: slow, level, pointed steps; never hurries | With the crook, without stopping; stands off at its length | 0.8 | 2.3 | A pit; steps up 0.3 m |

```
blender --background --python tools/build_mummy.py [-- <folder for renders> [mummy_royal mummy_royal_lo ...]]
godot --path . --fixed-fps 60 --resolution 960x960 --script tools/mummy_sheets.gd -- <folder> [turnaround face wake walk swipe dodge drapes stop m_walk m_swipe] [priest brute crawler child royal] [lo]
```

`m_walk` and `m_swipe` are strips of consecutive frames. Under each sheet it prints `SHAKE` (bones that turned back on
themselves or jumped from one frame to the next, as `tools/pose_sheets.gd` does) and `SLIDE` (how far the place a foot
stood on moved, and how far the ankle was from where it was meant to be).

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

## The mummified jackals

`JackalMummy.new()` is a whole one (`scripts/jackal_mummy.gd`): one of the dogs and jackals that were given to Anubis,
dried, bound in linen and stacked in his catacombs at Saqqara, set to guard a tomb. The level editor places one
("Mummified jackal" on the People page: how it waits, what it wears, how near he may come, and what wakes it), and two
lie on plinths in the test yard. To put one in by hand:

```gdscript
var jackal := JackalMummy.new()
jackal.rest = JackalMummy.Rest.SPHINX        # lying like the jackal on a shrine; STANDING, as it was propped in a niche
jackal.finery = JackalMummy.Finery.MASK      # a gilded mask and a broad collar; COLLAR; PLAIN
jackal.wake_within = 5.0                     # it wakes when he comes this near (0: only when `wake()` is called)
jackal.position = Vector3(x, y, z)
add_child(jackal)
jackal.caught.connect(...)                   # as a hound's
```

It lies dormant until then, its eyes dark. Woken, it gets up forequarters first, in jerks, its eyes come alight, and it
comes after him. It is not a hound and does not move like one:

| | A hound | A mummified jackal |
| --- | --- | --- |
| Speed | 5.4 m/s, faster than he runs | 3.8 m/s, slower than he runs (4.4), and it never tires or gives up |
| Gait | Walk, trot, and a gallop with its back gathering and stretching | A stalk and a short, quick, stilted trot on legs that hardly bend; its back is a plank; no gallop |
| Head | Up, watching him | Low, on a neck stretched out in front, weaving from side to side in starts, jaw hanging and clacking |
| Catches him | By reaching him | Only by springing: it sinks back with its jaw wide for 0.4 s (the warning), and springs straight at where he was. Step aside |
| Obstacles | Jumps 1.3 m, leaps 2.8 m | Hops a kerb of 0.5 m, crosses a gap of 1.5 m, will not enter water. Up on something he is safe, and it prowls beneath |
| Hurt | Yelps, circles, loses its nerve and runs | A blow knocks it aside; enough gunfire (`toughness`) knocks it down for `down_time`, and it gets up again |
| Left alone | Plays, sits, sleeps | Nothing: it lies where it was put |
| Voice | Barks and bays | None (see below) |

Several together come at him from different sides, keep apart, and spring in turn.

The model is built by `tools/build_jackal_mummy.py` (`models/jackal_mummy.glb`, and a demade `jackal_mummy_lo.glb`) with
the hounds' tools on the hounds' bones: a body dried onto its bones, bound in strips that cross at a slant in two tones
of linen (the lozenge pattern the embalmers put on animals), its limbs wound round and round, hollow eyes with a point of
light in each, a bare jaw, and loose ends of bandage, each on a chain of bones. `JackalMummyRig`
(`scripts/jackal_mummy_rig.gd`) extends `CanineRig` (`scripts/canine_rig.gd`), which extends `HoundRig` and uses its leg
solver, springs and the places it works out for a dog to sit and lie; the loose ends swing as the human mummies' do.

It is silent. `voice = true` gives it a dry rasp made from the recordings of hounds panting played at half their pitch,
which was made without being heard and is off until someone has listened to it.

## The hyenas

`Hyena.new()` is a whole striped hyena (`scripts/hyena.gd`): the hyena of Egypt, a scavenger of the dusk. The level
editor places one ("Hyena" on the People page: how bold it is, and how far it roams), and a pair hang about in the dunes
beyond the jackals in the test yard. To put one in by hand:

```gdscript
var hyena := Hyena.new()
hyena.bold = 0.4                 # 0..1: under a quarter it never rushes him; a very bold one may bring him down
hyena.roam = 12.0                # how far it wanders from where it was put while no one is about
hyena.position = Vector3(x, y, z)
add_child(hyena)
```

It does not hunt him. It hangs about him at a distance (`keep_distance` at its most wary, `near_distance` at its
boldest), standing and watching, then going round him at a walk or a lope. Now and then it makes a rush at him with its
mane up, breaks off short, and makes away. How near, how often and how close all go by its nerve: its own `bold`, more
when he is down (limp, crawling or crouched) or alone, less when he is near a fire, a lit torch or a flare. It gives
ground to anyone who runs at it. A thrown stone that lands by it, a blow, a gunshot it hears, or fire brought up to it
sends it off at a gallop, and it keeps well away for `shy_time`. Only one whose nerve is very high carries a rush
through and emits `caught`. With no one about it wanders and noses at the ground. Put two or three together: they keep
apart, go round him different ways, and do not rush at once. There is no clock in the game, so "at dusk" is where and
when the level puts them.

The model is built by `tools/build_hyena.py` (`models/hyena.glb` and a demade `hyena_lo.glb`) as the hounds are: 77 cm
at the withers on long forelegs, a back that slopes to low hindquarters, a heavy neck and a big blunt head, large
pointed ears, a short brush. Its stripes are not a texture: as on the cat, the fur shader draws the bars on its flanks,
the bands on its legs and its dark muzzle and throat where the model says each goes. Its mane is a mesh of its own in
locks, whose tips three bones lift to stand it on end. `HyenaRig` (`scripts/hyena_rig.gd`) extends `CanineRig`: it
walks shuffling, with its head low, and faster it does not trot but lopes, a rolling three-beat canter that rocks it
like a rocking horse with its rump tucked under; flat out the lope opens into a gallop. What that follows is in the
comments at the top of the file.

Its voice is recordings (`audio/hyenas/`, credited in `CREDITS.md` there, which must be kept: they are CC BY). They are
of the spotted hyena, no free recording of a striped one having been found: giggles when it rushes and breaks off,
and a whoop from a way off. `voice = false` makes it silent.

To see both animals:

```
blender --background --python tools/build_jackal_mummy.py [-- <folder for renders>]
blender --background --python tools/build_hyena.py [-- <folder for renders>]
godot --path . --fixed-fps 60 --resolution 960x960 --script tools/canine_sheets.gd -- <folder> [turnaround finery dormant stalk trot pack prowl felled m_rise m_stand m_trot m_stalk m_lunge m_strips h_turnaround h_coat h_walk h_lope h_run h_loiter h_crest h_flee m_h_walk m_h_lope m_h_run m_h_crest m_h_dart m_h_idle] [lo]
godot --headless --path . --fixed-fps 60 --script tools/canine_test.gd
```

The names beginning `m_` are strips of consecutive frames. Under each gait it prints when each paw came down in the
stride and how far a planted paw slid (`SLIDE`), and after each `m_` strip any bone that shook or jumped (`SHAKE`) and
the fastest any bone turned in one frame. In the fast gaits the leg bones are listed: they swing back and forth four
or five times a second, which is what it counts; none turns more than about 35 degrees in a frame.

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

## Fire and the torch

`Fire` (`scripts/fire.gd`) is restless: each tongue leaps and sinks in its own time and throws off licks that go up alone;
sparks stream up and wink, and now and then it spits a handful of embers that fall (`sparks`, `spits`); it glows (`glow`,
`glow_reach`: a soft light drawn in the air round it); and the light it casts gutters (`flicker`) and reaches now further
and now less far (`breathing`). `tools/fire_sheets.gd -- <folder>` draws each kind by day and in the dark, a few frames apart.

A `HandTorch` (`scripts/torch.gd`) is a burning torch to carry: act picks it up, and he holds it up in front of him as he
goes; act throws it, duck and act puts it down, and it goes on burning where it lies. There is one by the fire in the test
yard, and "Torch to carry" is on the level editor's Puzzle page.

## The dig, the backpack and the helmets

The tools and furniture of an excavation of the 1910s are props (PROPS.md lists them; the level editor's Dig page places
them): a pick, a shovel, a turia and a khopesh to swing, a trowel, brush, tape, lantern and basket to pick up, and a
sieve, barrow, level, plumb line, poles, crates and a camp table to dress a site.

A backpack with a bedroll, and six helmets (Anubis the jackal, Horus the falcon, Sobek the crocodile, Bastet the cat,
Thoth the ibis, Khnum the ram), are worn: `Worn` (`scripts/worn.gd`) puts one on anything that stands on the boy's rig,
in one line, `Worn.put_on(figure, &"helmet_sobek")`, and the dresser has a row for each on the boy. See "What is worn"
in PROPS.md.

A `GrappleHook` (`scripts/grapple.gd`) is a grappling hook to carry; its station in the test yard has a gap between two
decks to swing across and two gallows to swing from. A level says what a hook will catch in any of these ways:

```gdscript
add_child(GrapplePoint.new())                      # a node where the hook is to bite (`ring` shows an iron ring there)
GrapplePoint.mark(beam, Vector3(2.4, 0.9, 0.0))    # the same, on something, in its own space
GrapplePoint.auto(prop, "lintel")                  # wherever that kind of prop holds one (`GrapplePoint.HOLDS`)
anything.add_to_group(&"grapple_points")           # or any Node3D at all
```

Levels made in the editor get the third for nothing: every lintel, scaffold and awning holds a hook at both ends,
every column, obelisk, statue and palm at its top, and any Marker3D named `Grapple...` in a prop's scene is one. "Grappling
hook" and "Grapple point" are on the editor's Puzzle page. `tools/grapple_test.gd` runs the whole of it with nothing
drawn (ends PASSED or FAILED); `tools/rope_numbers.gd` prints how a rope swings: how surely it is caught, how the swing
grows when pumped and dies when left, what he carries off it at each point of the swing, and what climbing does to it.
`rope` and `grapple` among the names given to `tools/pose_sheets.gd` draw both.

## Scarabs

`ScarabSwarm.new()` is a whole swarm (`scripts/scarab_swarm.gd`): a hundred or two beetles that pour out of a hole (the
node is the hole), run over the ground as a carpet, up and over anything lower than `climb` (0.7 m), and go for the boy.
They are film scarabs, 10 cm long (`beetle_size`), modelled on the sacred scarab (`scripts/scarab.gd`: domed wing cases,
the shield over the thorax, the toothed head shield, six legs that scurry), black with a blue-green sheen.

- **He gets away** by running (`speed`, 3.3 m/s, is between his walk and his run), by jumping over the front of them, or
  by getting up onto something. When they have got no nearer for `give_up_after` seconds, or he is `chase_distance`
  from the nest, they stream home and go back down the hole.
- **Fire holds them off.** They will not come within `fire_reach` (2 m) of a `Fire`: a torch in his hand, a brazier
  (which holds off more ground), a flare. They part round it and run round the edge of its light, so with a torch he
  stands in a ring of them, or walks through them. They do not tire of waiting. `fears_fire = false` and they do not care.
- **Water stops them**: they will not go into a `Pool`.
- **Caught**: those that reach him run up his legs. A few are shaken off by running or jumping, and firelight drives
  them off; `catch_count` (12) of them on him for `catch_time` and the swarm emits `caught`, as a Hound or a Mummy does.
  When he starts again they are back in the nest.

```gdscript
var swarm := ScarabSwarm.new()
swarm.count = 150
swarm.alert_distance = 8.0      # they come out by themselves when he is this near (0: only when let out)
swarm.position = the_hole
add_child(swarm)
swarm.caught.connect(...)
swarm.chasing = true            # out; `false` calls them home; `reset()` puts them back at once
```

While they are out, `swarm.front` (the nearest of them to him) is in the group `pursuers`: the boy watches it and the
cat and the camels keep away. With `harmless = true` it is a few beetles (`count`) that wander within `roam` of where
they are put and run from his feet, and with `dung_ball` one of them rolls a ball backwards, head down.

There is no body to a beetle. All of them are one MultiMesh (140 triangles each), moved in one loop and written to it
in one piece; their legs are moved by the shader. The ground is found with a ray straight down, once for each 0.2 m
square round the nest as a beetle first comes to it (28 a frame at most), and remembered; they keep apart by counting
themselves into the same squares. Two hundred of them held in a ring by a torch cost about 0.5 ms a frame on a desk
machine (50: 0.13 ms; 100: 0.26 ms; much the same running over new ground), and it is one draw call.

A `ScarabAmulet` (`scripts/scarab_amulet.gd`) is a scarab of gold and lapis the size of a hand, picked up and thrown
like a rock; a `ScarabSocket` (`scripts/scarab_socket.gd`) is a stone with a hollow for it, and is a pressure plate
that only the amulet presses, so it opens whatever a plate opens.

The level editor has "Scarab swarm" (how many, how far they chase, whether fire holds them off, how near he comes
before they come out, and what lets them out) and "Scarabs (harmless)" on its People page, and "Scarab amulet" and
"Scarab socket" on its Puzzle page. The test yard has a station for them, north-west of the grappling hook.

`scripts/nearby.gd` (`Nearby.fires(tree)`, `Nearby.player(tree)`) is how the scarabs and the cobwebs find every fire
that is burning, and the boy, without either having to say it is there.

```
godot --path . --fixed-fps 60 --resolution 960x960 --script tools/scarab_sheets.gd -- <folder> [beetle pour step chase torch fire caught harmless webs far tear burn cost yard]
godot --headless --path . --fixed-fps 60 --script tools/scarab_test.gd
```

The first draws all of it (strips are consecutive moments) and, with `cost`, prints what a frame of the swarm costs for
50, 100 and 200 beetles. The second runs it with nothing drawn and ends PASSED or FAILED: they come out, go for him, are
held off by a torch, catch him without one, give up when he is up on a block or across water or too far, go over a
step, and come out when he comes near; and a web tears and a web burns.

## Cobwebs

`Cobweb` (`scripts/cobweb.gd`) is old web for tomb tunnels, in four sorts (`kind`):

- `CORNER`: a quarter fan in the angle of a wall and the roof (tipped over, of two walls); `size` is the length of its edges.
- `SHEET`: a web right across a passage, `wide` by `tall`. He walks or runs through it and it tears from top to bottom
  where he went: the edges draw back, what is left is thrown forward and swings, shreds are left hanging either side, a
  little dust comes off it, and some of it trails from him for a few seconds.
- `HANGING`: strands and tatters hanging from the roof, swaying in the draught.
- `DRAPE`: thick webbing over something `over` in size: a jar, a coffin.

Fire burns them: a torch held within `catch_distance` (0.4 m), a brazier or a flare sets one alight where it touched,
and it burns away from there in under a second behind a glowing edge, and sets light to any web that touches it.

Each is a few dozen triangles and one draw call, with nothing to load: the threads (spokes out from a hub, finer
threads sagging between them; for what hangs, threads running down) are drawn by the shader, with a veil of dust over
them. A thread narrower than a dot of the screen is drawn fainter instead of thinner, and far enough off the threads
give way to the even grey they average to, so a web does not shimmer in the distance. It is lit from both sides by
whatever light there is, so a torch carried past picks it out.

The level editor has "Cobweb: corner", "Cobweb: across a passage", "Cobweb: hanging" and "Cobweb: draped" on its Stone
page, each sized by sliders. The test yard has a short stone passage hung with them at the scarabs' station.

## Hieroglyphs

The writing on the walls is real. `scripts/hieroglyph_signs.gd` has 97 signs, each drawn in code as an outline (nothing
comes from a font): the 28 of the Egyptian "alphabet" (one consonant each: the vulture, the reed, the owl, the ripple of
water...), 44 that are two or three consonants or a whole word (the ankh, the scarab, the eye of Horus, the sedge and bee
of the king's title), 21 determinatives (the seated man, woman and god, the walking legs, the pyramid) and the numerals,
each with its number in Gardiner's sign list, how it is typed and what it stands for. `docs/hieroglyph_signs.png` is a
chart of them all.

`Hieroglyphs.write(text)` (`scripts/hieroglyphs.gd`) sets a text out in signs, and `Hieroglyphs.read(text)` gives back
what it says in plain words, for a translation:

- **English**, or anything in Latin letters. A word in its dictionary (king, god, life, sun, water, house, gold, death,
  door, tomb, Anubis, Osiris, Ra, Horus, Isis, Thoth... about 170) is written as the Egyptians wrote it, with its
  determinative. Any other is spelled out sound by sound with the alphabet, as a name is in a museum shop: sh, ch, kh,
  th, ph and qu are one sound, a doubled letter is written once, a silent final e is dropped, "the" and "a" are not
  written. Figures become numerals (1912 is a lotus, nine coils of rope, a hobble and two strokes).
- `<Tut>` is a king's name in a cartouche (Tut, Khufu, Ramesses, Cleopatra and a dozen more are spelled as they were;
  any other name is spelled out). `[Name]` stands it in a serekh, and `(Name)` puts the seated man after it.
- `{...}` is signs given outright, in the Manuel de Codage: Gardiner numbers or the usual letters and names, `-` or a
  space between one square and the next, `:` to put a sign over another, `*` to put them side by side, and after a `|`
  what it means: `{Htp:t*p-nb|every offering}`. A text that is all Gardiner numbers (`G17 D21 N35`) needs no braces.
- `@name` is one of the texts in `scripts/inscription_texts.gd`: `offering` (the offering formula), `curse` (the threat
  Old Kingdom tomb owners carved at their doors), `king` and `khufu` (titles, the names in cartouches), `hymn` and
  `praise` (to the sun), `door_light`, `follow_water`, `dead_live`, `sun_pyramid` (plain statements to hang a puzzle
  on) and `filler` (the stock phrases of every temple wall, for dressing long ones). Each has its translation.

The signs are packed as the Egyptians packed them, into squares: flat ones over each other, small ones together, tall
ones alone; in rows or in columns; read from the left, or from the right with every sign turned to face the other way;
with ruled lines between. The same text always comes out the same.

An `Inscription` (`scripts/inscription.gd`) is a panel carrying a text, carved: sunk into the stone (or `raised` out
of it), `painted` in the old colours or bare, as `wear`-worn as you like. It is one flat rectangle and one small
picture, made once: the picture holds how far each point is from the edge of a sign, and the shader reads the slope of
the cut from it, so the sun and a passing torch light the side of each cut that faces them. See the top of the file.

```gdscript
Inscription.on_box(wall, Vector3(4, 3, 0.6), Vector3.BACK, "@offering")          # on the front of a box-shaped wall
add_child(Inscription.slab("<Khufu> lives forever", Vector2(2.4, 1.2)))           # a slab of its own
for carved: Inscription in get_tree().get_nodes_in_group(&"inscriptions"):       # what each one says
	print(carved.translation())
```

In the level editor it is "Inscription" on the Stone page: type what it should say, or pick one of the texts; its width
and height, rows or columns, carved, painted, weathered, and whether it is a slab of its own or bare writing to stand
against a wall that is already there. The test yard has a station of them (east of the grappling hook), and the
"Carved wall" prop now carries the offering formula on its front and the curse on its back.

```
godot --path . --resolution 1280x720 --script tools/glyph_sheets.gd -- <folder> [chart] [stone] [torch] [yard] [prop] [banded]
```

draws the chart and the pictures: slabs near and far, in raking light, in shade, painted, worn, and by torchlight.

How true it is: the signs, their sounds, the dictionary words, the formulas and the way they are packed are real, and
someone who reads hieroglyphs can read the named texts. English spelled out letter by letter is the modern game of
writing a name in hieroglyphs, not Egyptian. The hints are composed for the game, in Egyptian words and word order.
