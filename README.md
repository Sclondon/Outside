# Outside

A touch-first 3D adventure in the spirit of Inside: a boy of the 1910s, flat cap and faded blue overalls, in a desert
of dunes, ruins and pyramids. Godot 4.7, built for phones and the web (the Scareathon arcade).

There are two levels: the desert (`desert.tscn`, where the game opens), which is laid out with the level editor
inside the game, and the test yard (`test_yard.tscn`), where every mechanic has a station.

## Controls

- Touch: drag anywhere on the left half to move (a gentle push walks, a full push runs, and held there he sprints); two small buttons bottom right
  duck and act (pick up / throw); tap anywhere else on the right
  to jump, hold for a higher jump.
  The stick and buttons are drawn on a phone or a tablet, and anywhere else only once a finger has been on the screen
  (`TouchControls.wanted`): with a mouse and keys, or a gamepad, there is nothing over the picture.
- Keyboard: WASD or arrows, Space to jump, C or Ctrl to duck, E or F to act, Shift to walk, R to drop him as a ragdoll
  and stand him back up.
- Gamepad: all of it, the notebook and the editors too. See Gamepad, below.

## Gamepad

Everything can be done with a gamepad alone, from starting the game to leaving it: play, the notebook, whatever comes
up over the game, and both editors as they are laid out for a desk. Any pad Godot knows the layout of will do (Xbox,
PlayStation, Switch Pro: SDL's mappings), plugged in before the game starts or after; every action listens to every
pad. In a browser a pad is only owned up to once one of its buttons has been pressed (that is the browser's rule): press
one, and it works from then on. The touch controls are not drawn for a gamepad.

The buttons are named here as an Xbox pad names them, by where they are: A is the bottom one of the four (Cross), B the
right (Circle), X the left (Square), Y the top (Triangle). The keyboard and touch do what they did.

| | Play | The notebook | A panel over the game | The level editor | The tomb editor |
|---|---|---|---|---|---|
| Left stick | He moves: a little walks, all the way runs, held there sprints | The mark, from thing to thing; on the colour wheel, points at a hue | The mark | Moves the cross over the ground (the view goes with it) | Moves the tomb about |
| Right stick | Turns the camera | On the colour wheel: paler, stronger, lighter, darker | | Turns the view and tips it | |
| D-pad | | The mark; left and right slide a slider; on the wheel, as the right stick | The mark | Left, right: what the page offers to put in. Up, down: the pages. In the settings: the rows, and left and right change a number or a choice | The mark: buttons, the row of rooms, the panel, the marks on a floor plan |
| A | Jump (held: higher) | Works what the mark is on; takes hold of the colour wheel, and keeps its colour | Says the name; presses the button; puts a leaf away | Chooses the thing at the cross; puts in; joins. Held while the cross moves: carries the thing (or a river's point) | Presses what the mark is on |
| B | Duck, crawl | Back: out of the wheel (its colour put back), then to the tab, then away | Step back | Not now: gives up putting in, ends joining, unchooses; out of the settings | Closes a sheet; gives up moving or joining a room |
| X | His hand: pick up, throw, pull a lever, turn a mirror, fire; held, climb a rope | | | Removes what is chosen | Removes the chosen room |
| Y | | | | The settings of what is chosen (of the desert, with nothing chosen) | The mark to the chosen room's panel |
| Shoulders | | The part before, the part after | | The page before, the page after | The room before, the room after |
| Triggers | Right: his hand, as X (to fire) | | | Left nearer, right further off | Left nearer, right further off |
| Start | The notebook | Puts it away | | Every button of the editor's own (Play, Save, More...), for the d-pad and A | The mark to Play |
| Back (Select) | In a tomb: the mark on Stuck, Edit and the map | | | | |
| Left stick pressed in | Drops him as a ragdoll, and stands him up (as R) | | | Undo | Undo |
| Right stick pressed in | The camera round behind him (as two taps) | | | Redo | Redo |

- **Play.** Guns, the grappling hook, ropes, ladders and swimming are worked as they are by the keys: with the stick,
  jump, duck and his hand. The right stick turns slowly when pushed a little and has a dead zone; how fast it turns
  and whether pushing it away looks up or down are in the notebook, under Notes (`Settings.look_speed`,
  `Settings.look_invert`).
- **The notebook** keeps its own notion of what the mark is on (its pages are drawn, not made of buttons): the mark is
  a box gone round twice in red pencil. A shoulder turns to a part and puts the mark on the first thing there.
- **Panels**: a guardian's names and the leaf (`GuardianPanel`), and the cards of a tomb. The sphinx has no panel: its
  riddle is answered by bringing it the thing.
- **A tomb's cards and buttons, and both editors**, are made of real buttons and sliders, which a gamepad cannot reach
  by itself: `PadFocus` (`scripts/pad_focus.gd`) looks through them each frame, keeps a mark on one, moves it the way
  the d-pad is pushed, and works it as a touch would. A line of writing (a sign, an inscription, a tomb's name)
  brings up letters to choose (`PadKeyboard`, `scripts/pad_keyboard.gd`): the d-pad and A write, X rubs out, Y is
  capitals, Start is done, B leaves it as it was.
- **The level editor** (`LevelEditorPad`, `scripts/level_editor_pad.gd`): "Choose what works it" in a door's settings
  goes back to the cross, and A on each plate or lever joins it; B when finished.
- **What still wants a keyboard**: the level, or a tomb, as text ("More" and "Tombs": Copy and Paste are buttons and
  work, but the text itself is not typed with a gamepad). On a phone the editors are laid out for thumbs, not for a
  gamepad.
- **What says what to press** says it for whichever was used last, a gamepad, the keys or a finger (`Gamepad.using`,
  which one small node sets from the events as they come): the notebook's "Getting about", the words on a guardian's
  panel and a tomb's card, the line of words in the level editor, and a row of marks for the buttons wherever a
  gamepad's mark is. The marks are drawn in code (`Gamepad.draw`): a letter in a ring, the four shapes on a
  PlayStation pad, the letters where a Switch pad has them.

Before this a gamepad could move him (the pad numbered 0 only), jump, duck, use his hand and turn the camera; take the
notebook out with Start, move its mark and turn its tabs; and move the mark on a guardian's panel. It could not choose
anything in the notebook or say a name (A was bound to nothing there), step back, bring the camera round, or reach a
tomb's cards, its Stuck and Edit, or anything in either editor.

`scripts/gamepad.gd` (`Gamepad`) has the actions, which was used last, and the marks. To check it:

```
godot --headless --path . --fixed-fps 60 --script tools/gamepad_test.gd
godot --path . --resolution 1280x720 --script tools/gamepad_shots.gd -- <folder>
```

The first plays the game with joypad events and nothing else (walks, runs, jumps, ducks, picks up, throws, turns the
camera, answers a guardian; visits every tab of the notebook, changes a setting, paints his shirt on the wheel; puts
in, carries, changes, joins, names, removes and undoes in the level editor; goes to the tombs, works the card, and
makes a room in the tomb editor) and ends PASSED or FAILED. The second takes a picture of each thing the mark is drawn
on. Both play with a gamepad of their own number and listen to no other (`Gamepad.listen_to`): a real one on the desk
is heard whether the window has the focus or not, and somebody may be playing. The other tools that open a window
listen to none (`Gamepad.device = 99`). It has not been tried with a real pad in a browser.

### The colour wheel

Wherever a colour is chosen it is chosen on a wheel (`ColourWheel`, `scripts/colour_wheel.gd`): a ring of every hue,
and inside it a square of that hue from white across to its full strength and down to black. A finger or a mouse that
comes down on the ring turns it, and goes on turning it wherever it is dragged; one in the square moves about the
square. With a gamepad: A on the wheel takes hold of it, the left stick points at a hue, the right stick or the d-pad
moves in the square, A keeps the colour and B puts back the one it had. The only colours chosen in the game are the
boy's, in the notebook (Me): his skin, hair and eyes, and each thing he wears. (No thing in either editor has a colour
to choose; if one is given one, this is what it is to be chosen on.) The few ready-mixed paints for skin, hair and
eyes beside his photograph are still there, as a quick way to a likely colour: a touch on one paints him and turns the
wheel to that part of him.

## What he can do

`test_yard.tscn` is a yard among dunes with a station for each of these set out round it, a sign over each. The camera
orbits there: drag anywhere on the right of the screen off the buttons (an eye mark shows where; two quick taps there bring the camera back behind him; jump is its own button), hold the right mouse button, or use a right stick.

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
them loose and calls them off; and birds (a station of them to run at, more at the pond, and vultures overhead). North of the start the kinds of ground are laid side by side in a row to walk along.

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

- **Wind ripples** are drawn by the sand shader, lying across the wind, and have three looks (`Sand.Ripples`):
  - **soft waves**, the look they always had: low even waves a third of a metre apart that bend with the ground.
    They fade out on a slip face, on trodden ground, and before they are too fine to draw;
  - **fine lines**: closer together and fainter, each with a longer back than lee side. There are two sets of them in
    patches, and where one gives way to the other a line ends or becomes two, so they fork and join;
  - **none**: bare smooth sand.

  Which a level has is its "Ripples in the sand" (on the editor's Level page; `ripples` in the layout;
  `SandGround.ripples` in code):
  - **Soft waves, as they were** (0): soft waves wherever there are ripples. It is what a level has that does not say,
    and what the test yard has.
  - **Mixed, as a desert is** (1): it differs from place to place, in patches some tens of metres across, by where a
    place is and never by the clock. Soft waves on most open sand and on the backs of dunes; fine lines only in some of
    the patches where the ground is level, and on level ground painted `PACKED` (trodden sand, and the swept ground
    between dunes); bare sand in other patches, round chalk rock (ground painted `WHITE`), in the lee of a dune and
    on its slip face; fewer on `COARSE` and `DAMP` sand, none on dirt, rock or snow. One look fades into the next
    over a few metres. This is what the shipped desert has.
  - **Fine lines** (2), **None** (3): the one look everywhere.

  With the world's light in bands, the line between light and shade is drawn from the ground without its ripples, so
  it is one clean line and not a row of teeth, and the ripples are shaded on top of it. The sand costs no more to
  draw than it did (0.39 to 0.41 thousandths of a second for a picture full of it on a desk, each look, where the
  forking lines alone took 0.41).

`tools/sand_sheets.gd` walks and runs him over all of it in the test yard and saves pictures (see the top of the file).

## Dunes

The desert's dunes are made by `SandDunes` (`scripts/sand_dunes.gd`) from the wind the level has, and
`DesertTerrain` makes the ground from them. Every dune is one line on the ground, its brink. Up wind of it the back
rises gently (about 11 degrees at its steepest), and down wind the slip face falls away at the angle sand lies at,
32 degrees: he walks up the one, and on the other the sand lets go under him. There are five forms:

- a **crescent** (a barchan): its horns point down wind;
- a **ridge** across the wind, long, its crest wandering;
- **linked crescents** (a barchanoid ridge): a wavy line of them, joined horn to horn, with a low saddle at each join
  (the crest runs round each join in a curve, not to a point);
- a **star dune**: three to five crests running out from a peak, one side of each a slip face;
- and the **floor** between, which is nearly level.

How they are set out is the level's "Kind of dunes" (on the editor's Level page; `dunes` in the layout):

- **Scattered, as they were** (0): crescents and ridges dropped by chance. It is what a level has that does not say.
- **Crescents, Ridges across the wind, Linked crescents, Star dunes**: a field of the one form.
- **A sea of all kinds**: crescents where the sand is thin, linked crescents and ridges where there is more. (No
  stars: a star is a peak.)

The shipped desert has **crescents**: there is little open ground between its places, and crescents fill what there is
with a dozen big dunes.

A field is set out as the wind sets one out: in rows across it, each row a dune's length and some flat ground
behind the last ("Flat ground between them"), the dunes of a row much of a size and standing opposite the gaps of the
row before, no two alike. Everything comes from the level's seed through whole numbers: the same level is the same
ground every time, on every device. In a field the flat ground between dunes is painted harder and a little paler
(packed, pale and a little white sand). A dune runs out to nothing, over a dozen metres, where it would stand on level
ground, a pond, rock, a person, a door or a checkpoint, and one with four fifths of it gone is left out; a palm, a
stone or any other prop does not move a dune, and stands on it as it finds it. The Ground page also has a **Star
dune** and **Linked dunes** to place by hand, beside the Dune and the Ridge.

**A field of dunes is smooth everywhere.** The dunes were rough and spiky, and these were the causes and the cures:

- A crest was a crease, and so were the points of horns and the joins of linked dunes. The ground is a grid of heights
  two and a half metres apart, and a crease that runs aslant to a grid comes out as teeth. The heights of a field are
  now rounded over after they are made (`SandDunes.rounded`: each corner the mean of those round it, three times
  over, or twice or once as "How sharp their crests are" goes up), so a crest is a curve some metres across. Soft
  (0.3) is what a level has that does not say; the slip face under the crest still stands at 31 or 32 degrees.
- A dune's back was as long as the dune was high at each place along it, so at its ends, and where it ran out at a
  pad, it shrank to nothing and the end was a steep-sided wedge: a roof, or a shard. The back is now as long at the
  ends as in the middle (`long_backs`), and the ends of a ridge rise over six times its height.
- There were too many small dunes. They are now between a little over half and the whole of "Height of the dunes"
  (they went down to a quarter), ridges are shorter, and there are about half as many.
- Low horns had slip faces a metre high and under two metres long, which the grid cannot draw. Below about three
  metres the lee side is now a gentler slope, the gentler the lower (`soft_below`).
- The ground was drawn as the flat triangles it is stood on, so a rounded crest against the sky was a line of straight
  pieces. Near the eye it is now drawn as a curved surface through the same corners (`SandGround.curved`: sixteen
  heights read for each corner of the mesh, where there were three; no more triangles). Each square of the grid is
  split into its two triangles along whichever diagonal lies nearer that curve (`SandDunes.splits`), in what is stood
  on too, so a crest that runs aslant is not notched: what is drawn and what is stood on are within a hand's breadth (8 cm on open dunes).
- The forking ripples drew a dark line down every slope, and in banded light broke the edge of every shadow into
  teeth (see the ripples, above).
- The sand banked against a rock is a ring of flat pieces with a plain edge, and was paler than the ground it lay on.
  The ground round every rock is now painted the same pale drift, fading out over five metres.

What dunes look like has a great deal to do with where the sun is: a slip face that is turned from the sun is dark
and its crest is a hard line, and one turned to it is nearly lost. The shipped desert's wind was turned right round
(it blows to the west-south-west now) so that its slip faces are turned from the sun.

**A level saved before this** (one made in the editor on a phone, or pasted in) says nothing of the kind of dunes, and
so keeps them exactly as they were: scattered, round at the crest, the same dunes in the same places, nothing moved
under what was put on them, drawn as flat triangles, with soft waves for ripples. What does change in it: things stand
on the ground exactly as it is drawn and stood on, where they used to stand on the height the dunes were worked out
from, which between two corners of the ground's grid could differ by a hand's breadth. To give such a level the new
dunes, choose a kind on its Level page; the ripples and the far hills are there too.

**The desert has no edge.** The level is still a square of ground (`size` across: its pads, its water and everything
that stands in it are there), but it is no longer closed in by a rim with a wall nothing could see inside it. He can
walk out of the square any way he likes and the dune sea goes on, for as far as he cares to walk:

- What lies past the edge is the level's own open sand, as it is before any pad is pressed into it or any water cut,
  over and over in every direction. The dunes are made so that the square meets itself (`SandDunes.wrap`: a dune that
  reaches past one edge comes in again at the far one), so the same kind of dunes, from the same numbers, lie out
  there as in here, and a place out there is the same place whenever he comes back to it. Whatever a level puts
  within 30 m of the square's edge (`DesertTerrain.JOIN`) runs out into that open sand: there is no step, no crease
  and no change in the sand where the square ends. (Paint a path right up to the edge and the path does stop there.)
- It is drawn by the same `SandGround` in the same one draw call, with not a triangle more: the mesh followed him
  already, and past the edge it now reads a second set of heights (`far_heights`) where it used to draw a plain. It
  takes his prints out there as it does anywhere. `height_at`, `give_at` and the rest answer for it.
- It is solid a piece at a time (`DesertTerrain._tread`): pieces 80 m across, those within two pieces of him or of
  anything on a rig or any hound that has followed him out, one made in a frame (under 3 ms; `tread_ms`), and a piece's
  shape is kept and used again wherever that part of the square comes round. Nothing is made until somebody nears
  the edge, so opening the level costs no more for it than the second set of heights (about a thirtieth longer).
- The far hills stand still while the eye is inside the square and go with it when it is outside
  (`DesertHorizon.round_square`), so they are never walked up to, and the whole level is always inside them.
- The river no longer runs to the edge: each end comes to a pool with reeds round it, short of it.
- Nothing lives out there. The level editor's cross and view keep to the square. "Start again" in the notebook brings
  him back, as anywhere.

An old level may still say `rim_height` and `rim_width`: they are not used, and the row for them is gone from the
editor's Level page. (The test yard makes ground of its own and is as it was: it ends in a plain.) The sea is one
square repeated, 800 m on in the shipped desert: from the ground that cannot be told, from high above it could be.

The ground is made again by the editor a moment after any change: that takes about a quarter of a second for the
shipped desert on a desk (it was asked of the dunes corner by corner, and is now worked out dune by dune).

`tools/terrain_sheets.gd` takes pictures of all of this (see the top of the file): `crests`, `start`, `looks` (each
look of the ripples, and where two meet) and `relief` (the shape of the ground alone, as a map) among them.

## Rock: cliffs, the White Desert, the Valley of the Kings

All of it is drawn with one rock shader (`scripts/rock.gd`, `Rock.material(colour, seed)`): beds lying level, each a
tone of its own with a dark parting under it; streaks run down steep faces; joints; sand lying on whatever is nearly
level; and scree. It comes in chalk, limestone, sandstone and dark basalt (`Rock.STONES`). On the editor's Stone page:

- **Mushroom rock, Rock dome, Haystack rock, Rock cone, Rock shelf, Dark outcrop** (`RockFormation`): the shapes of the
  White Desert, where the wind has cut a bed of chalk down into hundreds of lumps, undercut at the foot and ringed with
  the ledges of their beds; and the dark broken rock that shows through dunes. Width, which one, and what rock. Sand is
  banked up round the foot of each, deepest in its lee. They are solid: he can stand under a mushroom's cap, climb onto
  a shelf, and a grappling hook holds on the rim of a big mushroom.
- **Field of rocks** (`RockField`): so many of them over so wide a round, from a smallest to a biggest, of a mix of
  shapes (the White Desert's; domes and haystacks; mushrooms; shelves; dark rubble), with small stones between. The
  whole field is two meshes, four draw calls (only its big rocks throw shadows). Where a field is chalk the ground between is painted white in patches.
- **Cliff** and **Mesa** (`Cliff`): a body of rock with a flat top to walk on, a cliff band all round it set back in
  two ledges, and scree under the band that he can walk up. A cliff lies along a line (its length, and how far it
  bends round); a mesa fills a ring. Height, how much of it is scree, how far its buttresses stand out and its gullies
  go in, what rock. "Ways up" is how many places a rake of ledges climbs the band, each a step he catches and pulls up
  onto, the last onto the top. It stands on the ground as it finds it: its scree runs out to the dunes.
- **Valley of the Kings** (`KingsValley`): the set piece, below.
- **Tomb doorway** (`TombDoor`): one doorway by itself, to set against any cliff.

And on the Level page, **Far hills**: mesas and a long low cliff standing all round the level in the haze
(`DesertHorizon`), so that the desert does not end at an edge. One draw call; 0 is none.

**What is a model and what is made from numbers.** The rock that has a fixed shape was modelled in Blender, by a
script, and can be looked at and changed there: `tools/rocks.blend`. The game reads `models/rocks/rocks.glb`
(`scripts/rock_models.gd`). To make them again:

```
blender --background --python tools/build_rocks.py
godot --headless --path . --import
```

(or change `tools/rocks.blend` by hand and export it: the top of `tools/build_rocks.py` says how. Running the script
again makes the .blend afresh.) The game goes by the names of the objects:

| Object | What it is |
| --- | --- |
| `mushroom_a` `_b` `_c`, `dome_a` to `_d`, `haystack_a` to `_c`, `cone_a` `_b`, `shelf_a` to `_c`, `outcrop_a` to `_c` | The rock formations. Each is modelled 1 across (and only shown bigger in the .blend); the game picks one of the kind by its seed, turns it, and makes it the width asked for, a little taller or squatter. Its bank of sand is deepest on +X, which the game turns down wind. Add a `dome_e` and fields will use it |
| `stone_a` to `_d` | Loose stones, scattered through a field |
| `tomb_door`, `tomb_door_shut`, `tomb_door_open` | The doorway with its ramp, stair and walls (it looks out along Godot's +Z, Blender's -Y; the cliff is at its back); and what fills it, shut or open |
| `number_board`, `rubble_wall`, `spoil_heap_a` `_b` | The board for a tomb's number, a length of dry-stone wall, and heaps of chippings |
| `el_qurn` | The peak, 1 from its middle to its foot |
| `horizon_mesas` | The far hills: a ring 100 from its middle |
| anything with `_hull1`, `_hull2`... after its name | What is solid of the thing named: the game puts a hull round the points of each. A thing with none is not solid |

The materials say what each face is drawn with: `rock` (the rock shader, in whatever rock the level asks for),
`sand` (the sand shader), `dressed` (cut stone), `dark`, `wood`. The colour of each point of a `rock` face tells the
shader more: red is how light the rock is there, green how much sand lies over it, blue is 1 for scree and rubble.

What is still made from numbers, in code: the dunes, the ground and the ripples; and the cliff (`scripts/cliff.gd`).
A cliff follows whatever line or outline it is given (the valley's hills are one cliff, with the wadi cut out of its
top), comes down to dunes that are a different height all along it, clears its scree away where a doorway is, and puts
ledges where a way up is asked for. Lengths of modelled face set along the line could not do those things without
their joins showing at every bend and their feet standing in the air or the sand, so it was left as it is.

**The Valley of the Kings.** `KingsValley` is a block of limestone hills with a wadi cut into it from the south
(its own +Z): it bends as it goes, a branch leaves it on each side, and at its head stands the peak. Scree lies at
the foot of the cliffs; a path is beaten along the floor (packed, pale sand on white dust) and up each branch; and in
the cliff foot are the tomb doorways, up to eight, each where the cliff has cleared its scree back for it. A doorway
is a square-cut entrance under a lintel, with a ramp of chippings up to its sill between two dry-stone walls, a short
stair down inside to the door, a heap of spoil tipped to one side, and its number on a board. Size, the height of the
cliffs, how many doorways, which valley (the seed) are on its panel. It stands on level ground of its own, which the
desert makes for it.

Each doorway is a `TombDoor`, in the group `tomb_doors`. Shut, it is walled up. One of the valley's may be **open**
("Which is open"), and "It leads to" says what walking in at it does: nothing yet; today's tomb; a tomb of its own
(from "Which tomb", at "How hard"); or one that branches. A tomb is opened as the menu opens one (`TombLevel.play`, and
`tomb.tscn`, walked through), and when it is done the card has **Back outside**, which brings him back to the desert
standing before the door he went in at (`TombLevel.back_to`, `Desert.play_from`). The desert itself starts afresh when
he comes back: nothing of it is kept while he is below. A door also sends `entered`, for whatever else a level's
maker wants of it. The shipped desert's valley is in its north-west corner, with KV 9 open and leading to today's tomb.

What is true to the place: the royal tombs are cut into the foot of limestone cliffs in a dry wadi with side
branches, west of Thebes; the pyramid-shaped peak that stands over it is el-Qurn, "the horn", which may be why the
kings chose it; the entrances are plain square-cut doorways with a stair or ramp down, and were walled up and sealed;
by 1910 the floor was a dig, with the excavators' rubble retaining walls and heaps of limestone chippings about the
doorways and beaten paths between; and the tombs are numbered KV 1 upward (Wilkinson painted the first numbers on
them in 1827). The numbers on the boards are real tombs: KV 9 (Ramesses V and VI), 17 (Seti I), 11 (Ramesses III),
35 (Amenhotep II), 6 (Ramesses IX), 8 (Merenptah), 34 (Thutmose III), all open before 1910; and KV 62, which is
Tutankhamun's, and was not found until 1922: here it is the last, and shut. What is not true: the real valley is
about a kilometre long and its cliffs many times higher, its tombs are not in this order nor in these places, the
real peak stands well back from the head of the wadi and far above it, the stair of a real tomb goes down below the
floor of the valley where this one goes up a ramp to its sill and down three steps inside, and nobody put the numbers
on boards on posts: they were painted by the doors.

`tools/terrain_test.gd` checks all of this with nothing drawn (the same seed, the same ground; an old level loads and
its ground is what it was; up a dune and over; the slip face lets go; thrown at every rock from all round, running and
jumping, he does not get inside and can walk away; the ledges of a cliff are climbed; doors), and
`tools/terrain_sheets.gd -- <folder>` takes the pictures (the top of the file lists them):

```
godot --headless --path . --fixed-fps 60 --script tools/terrain_test.gd
godot --path . --resolution 960x960 --script tools/terrain_sheets.gd -- <folder> [dunes kinds ripples rocks field cliff valley horizon level]
```

## The level editor

In the desert, the notebook (top right), Places, then "Edit this level". The game stands still and the view goes up over him.

It is laid out two ways. On a phone or a tablet, in the game or in its browser (wherever the touch controls are shown), it is
laid out for a phone held sideways: see "The level editor on a phone", below. Elsewhere it has panels for a desk, which
are what the rest of this part describes. `-- phone` on the command line asks for the first anywhere, `-- desk` for
the second. They are one editor (`scripts/level_editor.gd`) with two screens, do the same things to the same level,
and keep it in the same form.

- **Looking about**: one finger drags the ground; two pinch to come nearer, turn to turn, and slid up or down together
  tip the view. For one hand there are + and - and a slider at the left. (Mouse: drag, wheel, right button.)
- **With a finger on the panels for a desk**: "Panel" puts the panel at the right away to see more of the level
  (choosing a thing brings it back); a thing is dragged by its ring and moves as far as the finger does, or a step at a
  time with the arrows in its panel (the step is beside them); the pages down the left scroll; "?" says all this again.
  A touch on the ring that goes nowhere is a touch, not a move: it chooses whatever is nearest it.
- **Putting things in**: the pages down the left (Ground, Water, Stone, Camp, Dig, People, Puzzle, Guns) fill the strip
  along the bottom. Touch one, then touch the ground.
- **Changing them**: touch a thing to choose it; its sliders come up at the right, with Move to, Copy, Remove. Drag it
  by its mark to move it.
- **The ground**: "Level" has the desert's size, the height and number of its dunes, the wind and the weather; and the
  kind of dunes, how sharp their crests are, how much flat ground lies between them, and the far hills (see Dunes,
  and Rock, above).
  Level ground, dunes and ridges placed by hand, ponds and rivers are things like any other: a river is a line of
  points to drag and add to, and the ground is cut away under water and made again a moment after any change.
- **Pyramids**: on the Stone page, "Stepped pyramid", "Finished pyramid" and "Fallen pyramid" are one thing made from
  numbers (`scripts/pyramid.gd`), set out three ways: its width, steepness and the height of a course, how much of
  its smooth casing is left, a gold cap, how ruined it is and which ruin, a doorway, and its stone. Move a slider and
  it is built again. (The Great and Ruined pyramids beside them are fixed models.)
- **Temples**: on the Stone page too, "Temple: Edfu", "Temple: Luxor", "Temple: Kom Ombo" and "Temple (your own)" are
  one thing made from numbers (`scripts/temple.gd`): how big (1 is the size of the real one, which is very big: Edfu is
  137 m long), how ruined and which ruin, how deep in sand, how much paint is left, its stone; and for your own, every
  other number it has. See Temples, below.
- **Abu Simbel**: on the Stone page, the two temples at their true size (`scripts/abu_simbel.gd`: see Abu Simbel,
  below): which of them, how far the sand has drifted, how weathered, whether the inside is still painted, and the
  morning of the sun on its axis. It is on while that sun reaches the sanctuary, so "Choose what works it" on a door
  or a bridge can pick it. "Size" makes it smaller for anyone who wants that; 1 is the real thing.
- **Rock**: on the Stone page, the Cliff and the Mesa, the six rocks of the White Desert, a Field of rocks, the
  Valley of the Kings and a Tomb doorway (see Rock, above). Move a slider and the thing is made again.
- **Heat**: "Level" also has the heat mirage: how much the distance swims, and whether pools of sky lie on the far
  sand. 0 is none.
- **People**: townspeople (who, and how far they wander), his brother, a cat, hounds (which give chase when he comes
  within their distance, or when something sets them on) and the mummy, of whichever kind ("Kind": see The mummies).
  Birds are here too (which kind, how many, how far they range: see The birds).
  And the Ba, a spirit bird that leads him along a line of points (see The Ba).

  Birds are here too (which kind, how many, how far they range: see The birds). And Apophis, the great serpent, who
  gives chase while what he is linked to is on (see Apophis).
- **Puzzles**: pressure plates, targets and things that smash are either on or off; a door, a bridge or lift, a sand
  fall, a hound or the mummy has "Choose what works it": touch the plates and targets that should, and lines show
  what is joined to what. Also ropes, ladders, blocks to push, checkpoints, signs, and where he starts.
  Levers, locks and keys, timed plates, light and mirrors, sluices, offering tables, braziers to light and seal
  stones are there too: see Puzzle parts, below. And gate guardians with the leaves that name them: see The gate guardians.
- **Keeping it**: every change is saved on the device as it is made (`user://desert_layout.json`) and is what the
  game plays from then on. "More" shows the whole level as text, to copy off the phone or paste one in, and has
  "Back to the original level". Pasted into `levels/desert.json`, a level becomes the one the game ships with.
- **With a gamepad** (on a desk): a cross in the middle of the view is moved over the ground with the left stick, and
  the buttons do the rest (`scripts/level_editor_pad.gd`): see Gamepad, above.
- Undo and Redo go back and forward through the last forty changes. "Play" starts from the start; "Play here"
  from the middle of the view.

The layout is plain data (`scripts/level_layout.gd` says what is in it); `scripts/desert.gd` makes the level from
it, and `scripts/level_editor.gd` is the editor. To check the editor without a phone (each needs a window, and a
folder for its pictures; neither touches a level made in the game, which they keep clear of by saving to a file of
their own, `LevelLayout.saved_at`):

```
godot --path . --resolution 1280x720 --script tools/editor_test.gd -- <folder>
godot --path . --resolution 1560x720 --script tools/editor_phone_test.gd -- <folder> phone
godot --path . --resolution 1560x720 --script tools/level_editor_shots.gd -- <folder>
```

The first works the panels for a desk. The second works the layout for a phone with nothing but touches (below).
The third takes a picture of every state of the layout for a phone and measures what there is to touch in each;
with `desk` after the folder it takes the same pictures of the panels for a desk, and only reports.

### The level editor on a phone

A phone held sideways is about 1560 by 720 of the game's pixels, and 720 of them are about 65 mm: a button 45 high is
4 mm, and a thumb wants 8. So on a phone the editor has a screen of its own (`scripts/level_editor_phone.gd`,
`LevelEditorPhone`) with these rules, which the tomb editor keeps too:

- nothing to touch is under **88 by 88**, or nearer the next than **12**; no writing is under **26**; nothing is
  within **48** of the left and right ends of the screen (more, where the phone says more is cut away) or on its
  bottom edge;
- **the level has the screen**. Along the top is one bar of six buttons, always there: **Add, Level, Undo, View, Play,
  More**. Under it one line of words says what a touch will do now. Everything else is either a **sheet** (one row of
  buttons along the bottom, the level in sight over it) or a **page** (which covers the screen with big rows, dragged
  up and down by a finger anywhere on them). Only one is ever open, and its way out is always at its top right: Done;
- nothing is small, hovered over or held down to find: a number has a minus and a plus (held, they run, slowly and
  then fast) and a slider with a grip a thumb can hold; yes or no is a switch; one of a list is a page of the list;
  the keyboard comes up only for words, on a page whose line is at the top, clear of it.

What is done, by touch:

- **Looking about**: one finger drags the ground, two pinch and turn, and slid up or down together tip the view.
  **View** is a sheet with a button for each (Nearer, Further, Above, Side, and the two ways to turn), for one hand.
- **Putting a thing in**: **Add**, then the kind of thing (Ground, Water, Stone, Camp, Dig, People, Puzzle, Guns,
  Railway), then the thing: each a page of big buttons. Then touch the ground where it goes; or drag the ground until
  the cross in the middle of the screen is on the place, and touch **Put here**. It is put in and chosen. (Cancel is
  the way out; Undo takes back a thing put in the wrong place, or it is dragged to the right one.)
- **Choosing and moving**: touch a thing. A ring with four arrows is put round its mark, and its sheet comes up:
  **Move, Change**, what works it, **Copy, Remove, Find** (which brings the view over it), Done. It is dragged by the
  ring, and moves as far as the finger does. **Move** is a sheet of arrows (Left, Far, Near, Right, as the view is
  turned: a step each, held to keep going), **Step** (0.1, 0.5, 1 or 5 m), **Lower** and **Raise**, the two ways to
  **Turn** it (15 degrees), and **Here**, which brings it to the cross. A river is dragged by its points; **Points**
  adds more (a touch, or Add here at the cross) and takes the last away.
- **Changing it**: **Change** is a page of everything about it, a row each. A touch on a number's name puts the page
  away and brings up a slider instead, to change it with the thing in sight.
- **Joining**: choose the door (or bridge, sluice, hound, train...) and touch **Opened by** (the button is named for
  what the thing calls it), then touch each plate, lever, lock or target that should work it. Or the other way about:
  choose the plate, touch **Works**, then touch each door. What can be touched is ringed, the line of words says what
  to touch next and how many are joined so far, a touch on one again undoes it, and lines show what is joined.
- **Removing**: **Remove** takes it away at once, and the line says "Undo brings it back": Undo is on the bar.
- **The level itself**: **Level** is the page of the desert's size, dunes, wind, heat and weather.
- **Keeping it, and playing**: as ever, each change is saved as it is made. **Play** starts the level from its start.
  **More** has Redo, Save now, Play from here, the level as text (Copy it, Paste, Use this text), the way back to the
  level the game came with (which asks first), and all of this in words. To come back from playing: the notebook,
  Places, Edit this level.

`tools/editor_phone_test.gd` does all of that with touches sent through the game's own input, finding each button on
the screen by its word and touching its middle; `tools/touch_audit.gd` is the measure both it and the pictures use.
It has only been tried so: with touches made up by a test, in a window on a desk, with the desk's renderer and the
web's (`--rendering-method gl_compatibility`). How the keyboard of a phone's browser behaves over the page for words,
and how the pages feel under a real thumb, have still to be seen on a phone.

## Puzzle parts

More to make puzzles of, each a script of its own that is whole from `new()`, on the editor's Puzzle page, and with a
station in the test yard (west of the pool, and east of the low bars). Those that are on or off work whatever a
pressure plate works: choose the door (or bridge, sand fall, mummy...) and "Choose what works it".

- **Lever** (`scripts/lever.gd`): he pulls it over with the act button, standing at it with his hands empty, and back
  again the same way. "Springs back after" makes it creep back by itself and go off after that many seconds. Anything
  in the group `workable` with a method `work` is worked by the act button in the same way (`Player._act`).
- **Key** and **Lock** (`scripts/door_key.gd`, `scripts/key_lock.gd`): a key of iron, bronze or gold, carried and
  thrown like a rock, and a lock on a stone post. Brought to the lock of the same metal (in his hand, or thrown down
  at it) the key is taken, turned, and the lock is on for good: link a door to it and that is a locked door.
- **Timed plate** (`scripts/timed_plate.gd`): a pressure plate that stays down for a number of seconds after he steps
  off it. The sand-glass beside it is turned over when it is pressed and shows what is left; the slab rises as it runs.
- **Sun lens**, **Mirror** and **Sun disc** (`scripts/sun_beam.gd`, `scripts/mirror.gd`, `scripts/sun_disc.gd`): the
  lens throws a beam of sunlight along its own +Z (it can be tipped, stand at any height, be had without its stand, and
  be covered and uncovered by anything linked to it). The beam is followed every step by casting a ray: either face of
  a mirror sends it on (up to eight mirrors), and anything else stops it, a wall, a pushed block, the boy. A mirror is
  turned a step (45 degrees, or what it is set to) by the act button. The sun disc is on while the light is on it,
  or for good with "Stays lit". All three stand 0.7 m high unless told otherwise, so a block to push comes up into
  the light. The beam is three crossed strips, added to what is behind them: it draws in every renderer.
- **Sluice** (`scripts/sluice.gd`): stood by a "Tank of water" (it takes the nearest water), it lets the water down
  by so much while what is linked to it is on, and up again after. It is the `Pool` itself that moves, so he swims
  where it is still over his chest, wades where it is not, and walks the floor where it has gone.
- **Offering table**, **Brazier to light** and **Seal stone** (`scripts/offering_table.gd`, `scripts/cold_brazier.gd`,
  `scripts/seal_stone.gd`): what a tomb has, for a level laid out by hand. The table is on when a canopic jar is put
  down at it or thrown onto it; the brazier when a burning torch is brought to it (and a torch that is out is lit at a
  brazier that burns); the seal stone is a plate that only he presses and that stays down. The tombs share the
  setting down of a jar and the lighting of a brazier with these (`OfferingTable.set_on`, `ColdBrazier.kindle`).

```
godot --headless --path . --fixed-fps 60 --script tools/puzzle_test.gd
godot --path . --fixed-fps 60 --resolution 960x960 --script tools/puzzle_sheets.gd -- <folder> [parts light water yard]
```

The first runs every part with nothing drawn, alone and then wired to doors in the desert as the editor makes them,
and ends PASSED or FAILED. The second draws them.

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
keys, or a gamepad's d-pad or stick, move a red mark from one thing to the next, and Enter or A works it (B goes back:
see Gamepad, above).

- **Journal**: what the game has written in it. Anything new puts a red mark on the notebook in the corner, and is
  what the book then opens at.
- **Me**: dresses the boy: his face, hair and clothes from lists, his cap and a backpack as boxes to tick, a helmet,
  paints for his skin, hair and eyes, and a colour wheel with a scrap beside it of each thing it can paint: his skin,
  hair and eyes, and each thing he wears (touch a scrap, then the wheel: see The colour wheel, above). "Any old how" is all of it at random; "As he was" puts him back. A photograph stuck in the page is him
  as he stands, so every change is seen as it is made.
- **Places**: the levels, on a map and as a list; "Start this place again"; and, in the desert, "Edit this level".
- **Papyrus**: there only once he has found a leaf of the Book of the Dead in this level: the leaves found (see The gate guardians).
- **Notes**: figures in full or demade, the world's light smooth or in bands (either starts the level again); how
  fast a gamepad's stick turns the camera, and which way up; and how he is moved about, said for whichever of a
  gamepad, the keys and a finger was used last.

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

## Going between levels

Every change of level goes through `Loading` (`scripts/loading.gd`), and nothing else changes the scene: the
notebook's map and list, "Start this place again", the tomb's card and its "Back outside", a doorway of the Valley of
the Kings, both editors' Play and the ways back from them.

```
Loading.go("res://desert.tscn")            # to a level; the page names it from its file
Loading.go("res://tomb.tscn", "Tomb 12")   # or says what it is told
Loading.again()                            # this level again
await Loading.cover("The desert, as it came", work)   # the page over something long done to the level that is there
```

A page of the notebook comes across the picture from the right in a quarter of a second: squared paper, a pencil
drawing of the place (the pyramids, the yard, a tomb's doorway), "On my way to" and its name, and under that what is
being done just now. A scarab walks along the foot of the page the whole time, drawing a pencil line after it, and
the line under the name grows as the level gets on. Behind the page the old level is put away, the new one's file is
read (on another thread where there is one; in one go, with the page saying so first, where there is not, as in a web
build without threads) and the level builds itself. The page is turned away to the left, in a third of a second, only
when the level is built, has stood under it for a few frames with nothing slow in them and the camera still (so
everything in sight has been drawn once, the camera is where it starts and he is on the ground), and the page has
been up for four tenths of a second, so that a quick change is not a flash. A level that cannot be opened is said
so on the page, and he is back where he was (or, at the first start, in the desert).

Most of the wait is the level making itself in code, which stops everything while it runs. So the levels that take
long build in stages and let a frame go by between them: `await Loading.stage("Raising the cliffs", 0.4)` always
does, and `await Loading.breathe("Setting out the dig", 0.6)` does when 40 ms have gone by since the last; at the
end of its `_ready` the level says `Loading.built()`. With no page up these do nothing and take no time. The desert
is staged where `scripts/desert.gd` calls its builders (each thing it stands on the ground, then the wind and the far
hills), the test yard between its stations. What cannot be split is a step: the page says what is being made, stands
still while it is, and moves on. On a desk that is the desert's ground (0.3 s), the first hound of the test yard
(0.7 s) and the whole of a tomb (0.1 to 0.5 s); a phone will be several times that.

While the page is up `Loading.busy` is true, and that is the one place to ask. The game is stopped until the level
is built; for the frames it then stands under the page it runs, but nothing pressed is passed on (the page takes it
all), the Player reads no keys or stick, and a second change asked for is refused. So a tomb's clock, which starts at
his first step, cannot start under the page. A key still held when the page goes works at once.

The game opens with `start.tscn`, which is nothing but the page with the first level building behind it. `Loading`
is not an autoload: the page is a node it puts under the root itself the first time one is wanted. With
`Loading.instant` set there is no page and no waiting, and the scene is changed as it always was: it is set when
nothing is drawn (`--headless`), and by the tools that work the menu and the editors in a window. The tools that
change scene themselves still do.

```
godot --headless --path . --fixed-fps 60 --script tools/loading_test.gd
godot --path . --resolution 1560x720 --script tools/loading_sheets.gd -- <folder>
godot --path . --script tools/loading_times.gd -- res://desert.tscn [through]
```

The first goes every way from each level to the others with the page asked for, and checks that it was across before
the old level went and until the new one stood ready, that nothing pressed meanwhile did anything, and that a tomb's
clock waited for his first step. The second saves a strip of pictures through each change. The third says where the
time goes: on a desk, drawn as the web build draws, the desert took 1.1 s to open before and has the page fully up
for 1.3 s now; the test yard 3.8 s and 3.9 s; a tomb 0.4 to 0.5 s and 0.5 to 0.6 s.

## Layout

| File | What it does |
| --- | --- |
| `scripts/player.gd` | The controller: movement, jumping, stairs, pushing crates, respawn |
| `scripts/character_rig.gd` | Animates the model in code: gait, leg IK, a jointed back, hands, looking about, and the swing of hair and hem |
| `scripts/touch_controls.gd` | Floating stick and jump area |
| `scripts/follow_camera.gd` | The camera: a fixed side view (the tomb seen from the side) or a third-person orbit (the yard), which with `indoors` set keeps itself this side of walls and roofs (the tomb walked through) |
| `scripts/desert.gd` | The desert (`desert.tscn`): makes the level from its layout, and runs its puzzles, checkpoints and people |
| `scripts/level_layout.gd`, `scripts/level_editor.gd` | What a level is made of, as data; and the editor inside the game that changes it |
| `scripts/level_editor_phone.gd` | The editor's screen for a phone: a bar, and one sheet or page at a time, all sized for a thumb |
| `tools/editor_test.gd`, `tools/editor_phone_test.gd`, `tools/level_editor_shots.gd`, `tools/touch_audit.gd` | Not part of the game: work the level editor's panels for a desk, and its layout for a phone by touch alone; take a picture of every state of either; and measure what there is to touch on a screen |
| `scripts/desert_terrain.gd` | The desert's ground: dunes, level ground, and water cut into it |
| `scripts/sand_dunes.gd` | Dunes as the wind makes them: crescents, ridges, linked crescents, star dunes, and whole fields of them in rows across the wind |
| `scripts/rock.gd`, `scripts/rock_models.gd` | Living rock drawn by a shader (beds, weathering, joints, sand on its ledges, scree), and what builds meshes of it; and the rock that was modelled (`models/rocks/rocks.glb`) |
| `scripts/rock_formation.gd`, `scripts/rock_field.gd` | A rock of the White Desert (mushroom, dome, haystack, cone, shelf, dark outcrop); and a field of them in one mesh |
| `scripts/cliff.gd` | A cliff or a mesa made from numbers: a flat top, a cliff band, scree, buttresses and gullies, ledges to climb, cuttings for doorways |
| `scripts/kings_valley.gd`, `scripts/tomb_door.gd` | The Valley of the Kings: hills with a wadi cut into them, the peak, the path, and the tomb doorways; and a doorway, which can lead to a tomb |
| `scripts/desert_horizon.gd`, `scripts/desert_scenery.gd` | The far hills round the level; and what makes all of this rock from a level's layout, paints the ground round it, and puts its rows on the editor's Level page |
| `tools/build_rocks.py`, `tools/rocks.blend`, `models/rocks/rocks.glb` | Not part of the game: builds the rock models in Blender; the models to look at and change; and what the game reads |
| `tools/terrain_test.gd`, `tools/terrain_sheets.gd` | Not part of the game: check the dunes and the rock with nothing drawn; and take pictures of them |
| `scripts/pyramid.gd` | A pyramid made from numbers: stepped core, smooth casing, gold cap, ruin (fallen corners, rubble, missing and slipped blocks), a doorway; its mesh and what is solid |
| `scripts/sandstone.gd` | Stone drawn by a shader: blocks in courses, strata, weathering, cracks, rubble; and gold (`Toon.sandstone`, `Toon.gold`) |
| `scripts/sphinx.gd` | A sphinx: a statue to climb on that wakes when he comes between its paws, asks a riddle, is on for good when it is given the thing that answers it, knocks a wrong thing away, and can lie buried in sand until something clears it |
| `scripts/sphinx_mesh.gd` | Its stone: puts together the things of the model a sphinx wants (the lion, and a king's, a ram's or a falcon's head), at its size and as worn as it is; and what of it is solid |
| `tools/build_sphinx.py` | Builds the sphinx in Blender (`tools/sphinx.blend`, `models/sphinx.glb`): one metre long, separate named things and named materials, no bones |
| `tools/sphinx_test.gd`, `tools/sphinx_sheets.gd` | Not part of the game: run the sphinx with nothing drawn and say what happened; and draw it |
| `scripts/temple.gd` | A temple made from numbers: pylon, courts, halls of columns, sanctuary, enclosure wall; set out as Edfu, Luxor, Kom Ombo or your own; ruin, sand, paint |
| `scripts/temple_parts.gd`, `scripts/temple_stone.gd` | Reads the temple's models and places them, builds its plain walls and floors, and keeps what is solid; the shader all its stone is drawn with (courses, rows of relief, paint, granite), the light through its roof, and the figures cut in its pylon |
| `tools/build_temple.py`, `tools/temple.blend`, `models/temple/temple.glb` | The temple's parts as models: the script that builds them in Blender, the file to look at and change them in, and what the game reads |
| `tools/temple_sheets.gd`, `tools/temple_test.gd` | Not part of the game: pictures of every plan and every model, and what each costs; and a run with nothing drawn that walks him in to each sanctuary and throws him at the stone |
| `scripts/abu_simbel.gd` | The temples of Abu Simbel, set out from the models in `models/abu_simbel/abu_simbel.glb`: what is solid, the sand drift, the writing, the dark inside, the sun down the axis |
| `tools/build_abu_simbel.py`, `tools/abu_simbel.blend` | The Blender script that makes those models, and the file it saves to look at and change by hand |
| `scripts/heat_mirage.gd` | Heat over the desert: far things near the level of the eye swim, and pools of sky lie on the far sand |
| `scripts/tomb_parts.gd` | Torches, pressure plates and stone doors |
| `scripts/test_yard.gd` | The test yard (`test_yard.tscn`) |
| `scripts/rope.gd` | A rope to swing on and climb: a pendulum under whoever is on it, a chain otherwise |
| `scripts/grapple.gd` | A grappling hook on a coil of rope: finds what it will catch, flies there, hangs a rope from it, is wound back in |
| `scripts/grapple_point.gd` | Somewhere a hook will catch; marks them on props of its own accord |
| `scripts/ladder.gd`, `scripts/pool.gd` | A ladder; a box of water to swim in |
| `scripts/dust.gd` | Puffs of dust, drawn all at once as one MultiMesh |
| `scripts/train.gd`, `scripts/train_vehicle.gd` | A train: vehicles coupled and run along a line, and carrying whoever rides them; one vehicle, whose wheels turn and rods work |
| `scripts/train_scenery.gd`, `scripts/train_smoke.gd`, `scripts/train_signal.gd` | What goes by a train that stands still; an engine's smoke, steam and sparks; a semaphore signal |
| `tools/build_train.py`, `tools/build_train_scenes.gd` | Build the railway's models in Blender and their scenes in `props/` |
| `tools/train_sheets.gd`, `tools/train_test.gd` | Not part of the game: draw the railway and the boy riding it; ride it with nothing drawn and say what happened |
| `scripts/toon.gd` | Cel shading: two flat tones for the figures, and optionally the world; a shader for hair; the pinstripe in his shirt |
| `scripts/menu.gd`, `scripts/settings.gd` | The in-game menu, which is his notebook, and what it remembers |
| `scripts/notebook.gd`, `scripts/notebook_ink.gd` | What the game has written in the notebook's journal (`Notebook.note(...)`); and the pencil, ink and paper its pages are drawn with |
| `tools/notebook_test.gd` | Not part of the game: takes the notebook out, works every page of it with touches and keys in both levels, checks each took effect, and saves pictures |
| `scripts/loading.gd`, `scripts/start.gd` | Going from one level to another behind a page of the notebook (`Loading.go(...)`), with the level building in stages behind it; and what the game opens with (`start.tscn`), which is that page over the first level |
| `tools/loading_test.gd`, `tools/loading_sheets.gd`, `tools/loading_times.gd` | Not part of the game: go every way between the levels and check the page covered each change and nothing got past it; pictures of each change; and where the time goes when a level is opened |
| `scripts/worn.gd` | What a figure wears that is not part of its model: the backpack and the helmets (`Worn.put_on(figure, &"helmet_anubis")`) |
| `scripts/gear_prop.gd` | A prop whose gold, bronze and brass shine |
| `tools/worn_sheets.gd` | Not part of the game: draws what is worn on everyone who can wear it, and the boy moving in it |
| `scripts/mummy.gd` | The mummy: dormant until disturbed, then lurches after the player; within reach it rears back and swipes an arm at him, and catches him only if the arm finds him |
| `scripts/mummy_rig.gd` | Its own way of moving, laid over the boy's rig: a step and a dragged leg, the swipe, and its loose bandages swinging as chains; and what the other kinds' rigs share |
| `scripts/mummy_priest_rig.gd`, `mummy_brute_rig.gd`, `mummy_crawler_rig.gd`, `mummy_child_rig.gd`, `mummy_royal_rig.gd` | How each of the other kinds of mummy walks and strikes |
| `tools/build_mummy.py` | Builds the mummies in Blender: their proportions, the face under the wrappings, a chain of bones down each loose end, and what each kind has of its own |
| `tools/mummy_sheets.gd` | Not part of the game: drives a mummy of any kind through each thing it does, saves pictures of it, and says which bones shook and whether its feet slid |
| `scripts/medjed.gd` | Medjed: a shroud with two eyes and two feet who stands and looks from side to side; the boy seen in his gaze, drawn as a fan on the floor, is warned and then smitten. The figure is read from its model; its gaze and its sounds are made here |
| `tools/build_medjed.py` | Builds Medjed in Blender (`tools/medjed.blend`, `models/medjed.glb`): the shroud, each eye with its shape keys, each foot, and named materials; no bones |
| `tools/medjed_test.gd`, `tools/medjed_sheets.gd` | Not part of the game: run Medjed with nothing drawn and check each thing he does, and count his rays; and pictures of him and of each of those things |
| `scripts/hound.gd` | A hound, of either breed: chases the player, leaps obstacles and gaps, bays and barks (recordings of dogs, in `audio/hounds/`), braces and barks under what it cannot reach, and plays, sits and sleeps when left alone |
| `scripts/hound_rig.gd` | Animates a hound in code: walk, trot and rotary gallop on three-jointed legs, spine flex, a jaw that keeps time with its voice, a head that watches things, sitting, lying and the bow, a tail on springs, and ears that hang and swing or stand and turn |
| `scripts/fur.gd` | The hound's coat: streaked along the lie of the hair, with a few shells stood off it |
| `scripts/cat.gd` | A cat: wanders, watches the boy, follows him, rubs round his legs, stalks, sleeps in the sun, and goes up out of reach of anything in the group `pursuers` (recordings of cats, in `audio/cat/`) |
| `scripts/cat_rig.gd` | Animates a cat in code, on the hound's rig: the walk that puts each hind paw in the fore paw's print, trot and bound, stalking and springing, jumping up and down, sitting, lying, curled asleep, stretching, washing, and a tail, ears, eyes and whiskers that say what it feels |
| `tools/hound_sheets.gd` | Not part of the game: drives the hounds through each thing they do and saves pictures of it |
| `tools/cat_sheets.gd` | Not part of the game: the same for the cat |
| `tools/cat_test.gd` | Not part of the game: runs a cat with nothing drawn and checks that it wanders, watches, flees a hound up onto something and comes down |
| `scripts/birds.gd` | Birds: a flock of one kind that finds its own perches, ground and water, feeds, goes up when the boy comes near or a gun goes off, wheels, and comes down again; soarers that gather over what lies dead |
| `scripts/bird_kinds.gd`, `scripts/bird_mesh.gd` | What each kind of bird is, as numbers; and the mesh built from them, with the shader that beats its wings and bends its neck and legs for a whole flock in one draw |
| `tools/bird_sheets.gd`, `tools/bird_test.gd`, `tools/bird_place_check.gd` | Not part of the game: pictures of every kind of bird and of what each does, and what they cost; a run with nothing drawn that checks they settle, go up, come down, and stay in range and above the ground; and one that puts them into the desert as the editor would |
| `scripts/ba.gd`, `scripts/ba_mesh.gd` | The Ba, a bird with a man's head that leads the boy from place to place, calls him and comes back for him, and comes and goes with a switch; and its model read and made ready to draw |
| `tools/build_ba.py` | Builds the Ba in Blender (`tools/ba.blend`, `models/ba.glb`): separate named things and named materials, no bones |
| `tools/ba_sheets.gd`, `tools/ba_test.gd` | Not part of the game: pictures of the Ba and of each thing it does; and a run with nothing drawn that checks them |
| `scripts/apophis.gd` | Apophis, the great serpent: a head that hunts the boy by sight and by his trail, and a body laid along the path the head took and bent to it by a shader; held off by fire and sunlight, stopped by a shut door, sent home when what let him out goes off |
| `tools/build_apophis.py`, `tools/apophis.blend`, `models/apophis.glb` | Builds his model in Blender: his head on bones, one length of his body, a knife; the same to open and change; and what the game reads |
| `tools/apophis_test.gd`, `tools/apophis_sheets.gd` | Not part of the game: run him with nothing drawn and check each thing he does; and pictures of him doing them, with what a frame of him costs |
| `tools/build_boy.py` | Builds the boy in Blender: one continuous body, modelled in a T-pose, in shirt, patched overalls and curls, and his cap as a separate object |
| `tools/pose_sheets.gd` | Not part of the game: drives the Player through each thing he does and saves pictures of it |
| `tools/build_hound.py` | Builds the two hounds in Blender from two lists of measurements |
| `tools/cut_hound_audio.py` | Not needed to run the game: cuts the hounds' voices out of the recordings they come from |
| `tools/build_cat.py` | Builds the two cats in Blender, the way the hounds are built |
| `tools/cut_cat_audio.py` | Not needed to run the game: cuts the cat's voice out of the recordings it comes from |
| `tools/build_character.py` | Holds the tools `build_boy.py`, `build_hound.py` and `build_mummy.py` use |
| `scripts/gate_guardian.gd`, `scripts/guardian_mesh.gd` | A keeper of a gate of the underworld: seated, with the head of a beast and knives; asks its name, is on for good when it is said, strikes when it is not; and its model read into one thing to draw for each part that moves |
| `tools/build_guardian.py` | Builds the gate guardians and the leaf of papyrus in Blender (`tools/guardian.blend`, `models/guardian.glb`): the figure in wrappings and in a kilt, the nine heads, the knives; separate named things and named materials, no bones |
| `scripts/book_page.gd`, `scripts/book_of_the_dead.gd` | A leaf of the Book of the Dead to find, with the name of a keeper on it; and the names themselves, the drawings of the keepers, and which leaves he has found in this level |
| `scripts/guardian_panel.gd` | The leaf to read, and the three names to choose from, over the stopped game |
| `scripts/gamepad.gd` | The gamepad: its actions, which of a gamepad, the keys and a finger was used last, and the marks drawn for its buttons |
| `scripts/pad_focus.gd`, `scripts/pad_keyboard.gd` | A gamepad's mark on a screen made of buttons and sliders (a tomb's cards, the editors), and letters to choose for a line of writing |
| `scripts/level_editor_pad.gd`, `scripts/tomb_editor_pad.gd` | The two editors worked with a gamepad, on a desk |
| `scripts/colour_wheel.gd` | The colour wheel: a ring of hues and a square inside it, for a finger, a mouse or a gamepad |
| `tools/gamepad_test.gd`, `tools/gamepad_shots.gd` | Not part of the game: play everything with a gamepad and nothing else, and say what happened; and pictures of the gamepad's mark on everything |
| `tools/guardian_test.gd`, `tools/guardian_sheets.gd` | Not part of the game: run the guardians and the leaves with nothing drawn, by touch, and say what happened; and pictures of them, of the names on the screen of a phone and of the leaf |
| `scripts/khepri.gd`, `scripts/akhet.gd` | Khepri and the sun: a big scarab that rolls a ball of sun over a floor of squares, turning at whatever is in its way; and the horizon it is brought to, which is then on for good |
| `scripts/khepri_court.gd` | The court Khepri is tried in: the test yard's station for it, and what its test and its pictures are run in |
| `tools/build_khepri.py` | Builds Khepri's beetle, the sun's ball, the horizon, the swarm's small scarab and the scarab amulet in Blender (`tools/khepri.blend`, `models/khepri.glb`): named things hinged at their origins and named materials, no bones |
| `tools/khepri_test.gd`, `tools/khepri_sheets.gd` | Not part of the game: run Khepri with nothing drawn and check each thing it does; and draw it |

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

## The crocodile

`Crocodile.new()` is a whole Nile crocodile (`scripts/crocodile.gd`), about 3.4 m long. It lives in water: the `Pool`
it is put in, or the nearest within `water_within` of where it is put (in the desert, any pond or river). The level
editor places one ("Crocodile" on the People page: docile or not, and how far from the water it will come), and there
is one in the test yard's pond, docile until the plate beside the pond is trodden on.

```gdscript
var crocodile := Crocodile.new()
crocodile.docile = true                  # scenery: it floats, basks and watches, and never hunts
crocodile.reach = 5.0                    # how far from the water it will come after him, metres
crocodile.position = Vector3(x, y, z)    # in the water, where it will float; or on the bank, where it will bask
add_child(crocodile)
crocodile.caught.connect(...)            # it has him (the levels knock him down and start him again, as for a hound)
```

Left alone it floats like a log, at a slant, with only its eyes and its nostrils out of the water, and every so often
(`float_for`) hauls out and walks up the bank to bask on its belly with its mouth open (`bask_for`), and slides back in.
It watches the boy within `notice`.

When he comes within `edge` of its water, or into it, it sinks and comes at him under water. **What gives it away is
the line of rings it draws on the surface as it comes**, and in shallow water its back; a few metres off it stops, its
eyes come up with a splash, and after `wind_up` (under half a second) it lunges, up the bank if need be, jaws wide.
If its jaws close on him it sends `caught`, shakes its head, and in the water rolls. It swims faster than he does
(`chase_speed` against his `swim_speeds`), so the water is not safe while it is in it; on land it is slower than he
runs, follows for `reach` metres or `stamina` seconds, gives up, walks back and rests. It is in the group `pursuers`
only while it is hunting.

A burning flare, a lit torch, a shot or a blow (`shot`, `struck`, as the hounds have) and anything thrown that comes
down near it each send it under and keep it there for a while. It is never killed. With no water near it lies about
on land round `home`, and lunges from there.

On land it has three ways of going: the belly crawl (sprawled, one foot at a time, its back and tail bending), the
high walk (lifted clear on straightened legs, in diagonal pairs) and a fast belly run for the water or after him. The
sources, and the note that none of the numbers is a measurement, are at the top of `scripts/crocodile_rig.gd`;
`CrocodileRig` extends `HoundRig` and uses its leg solver and foot path unchanged, with the legs told to fold out to
the side. The model is built by `tools/build_crocodile.py` (`models/crocodile.glb`, and a demade `crocodile_lo.glb`):
nothing is fused or textured, the belly, flanks and tail bands are materials cut along the hide's own edges, and the
scutes are geometry. Its voice (a hiss, a bellow, the clap of its jaws) is made up in code; `voice = false` makes it
silent. Like the hounds, it and the player pass through each other.

```
godot --path . --fixed-fps 60 --resolution 960x960 --script tools/crocodile_sheets.gd -- <folder> [turnaround floating bask look hunt m_crawl m_high m_run m_turn m_swim m_dive m_slide m_return m_haul m_lunge m_gape m_thrash m_roll ...]
godot --headless --path . --fixed-fps 60 --script tools/crocodile_test.gd
```

The stage is a pond with a sloping bank. Add `lo` for the demade model. Under each gait it prints when each foot came
down and how far a planted foot slid, and after each `m_` strip any bone that shook or jumped.


## Apophis

`Apophis` (`scripts/apophis.gd`) is the chase: a very big snake, 12 to 30 m long and half a metre thick, with a head
bigger than the boy's chest. He lies coiled, or out of sight down a hole, until he is let out; then he comes after the
boy and does not give up. `Apophis.new()` is a whole one.

**Where he comes from.** Apep (Apophis is the Greek of it) is the serpent of chaos, who lies in wait in the underworld
every night to stop the sun god's boat. He is first named in the Coffin Texts of the Middle Kingdom, and the books
painted in the royal tombs of the New Kingdom, the Amduat and the Book of Gates, show him in the seventh hour of the
night: a huge snake in many coils on a sandbank, bound, and with knives stuck in him. Set spears him from the prow of
the boat; in the Book of the Dead (spell 17, and the tomb of Inherkha at Deir el-Medina) Ra as a great cat cuts him
with a knife under a tree. A papyrus now in London (Bremner-Rhind) is a whole ritual for overthrowing him: he is spat
on, trampled, speared, cut and burnt in wax, every day. And he is there again the next night: he is never killed.
So what is true to that here is what he is and how he looks (one enormous snake, yellow, in coils, knives in him), that
light and fire drive him back, that he cannot be killed, and that he is back the next time. What is ours: that he is
after a boy and not the sun, that a hand torch is light enough, how he finds his way, and the hole. His markings are
made up too; the paintings give him none to speak of.

**How he is made.** His head is this node, and is what the world stops. Behind it is kept the path the head has
taken, and his body is laid along that path: every part of him passes where his head passed, round the same corners,
over the same kerbs and up the same faces, with a side-to-side wave over it that stands still on the ground while he
slides through it. At rest the path is a coil, so he leaves it as a snake does, sliding out along himself; called
home, he winds himself back in. He is drawn as one tube, which its shader bends along 80 places on the path: nothing
is built each frame but those 80 places.

**What he looks like is a model**, `models/apophis.glb`, built in Blender by `tools/build_apophis.py`, which also
writes `tools/apophis.blend` to open and change. In it are his head (on bones: `head`, `jaw`, `tongue`, `fangs`), one
length of his body (1.15 m of it, a saddle and the plates under it), and a knife. There is no picture on him: his
colours are materials, a face at a time (`back`, `mark`, `edge`, `belly`, `belly_shade`, `mouth`, `tooth`, `tongue`,
`eye`, `pupil`...). The game reads the model when he is made: it lays the one length end to end for as long as he is,
thins it at his neck and down his tail, and makes each of the three one thing to draw, with the materials' colours on
its points. The bones are not used as bones: which bone a point hangs from tells the shader that it goes with the jaw
(which drops), is the tongue (which flicks), or is a fang (which is drawn out as the jaw drops). So to change how he
looks, change the .blend (a material's colour, which faces have it, the shape of his head, where a bone starts) or
the numbers at the top of the script, and build him again:

```
blender --background --python tools/build_apophis.py [-- <folder for pictures of the model>]
godot --headless --path . --import
```

(A model changed by hand in Blender is exported from there as `models/apophis.glb`, glTF binary, +Y up, with its
skin, and without applying the Array modifier that shows a length of him. The body's pattern must meet itself end to
end. He has no demade model: he is about 4000 triangles as he is.)

**The chase.**

- His `speed` (3.6 m/s) is between the boy's walk (1.6) and his run (4.4). He goes a little faster than that on the
  straight (4.0) and a good deal slower in a turn, so a clean run keeps ahead of him and a stumble does not, and a
  boy who doubles back gains a few metres.
- He steers straight for the boy while there is a clear line to him. When there is not, he follows the trail the boy
  left (a place every 0.6 m), which is always a way through. There is no navigation mesh in the game, and he does
  not use one. Held up against something for a second, he tries the other way round it and keeps to the trail; held
  up for three, he goes up it.
- Anything up to `step_over` (1 m) he goes over at once: he rears over it. That is a kerb, a block to push, a crate.
  He swims, his head just under the surface, and he is low enough to go through a crawl.
- **A ledge buys time, not safety.** Under one the boy is up on, he rears against it and sways with his head under the
  boy for `ledge_wait` (3 s). Then he looks along the face to either side for a way up in steps he can go over (the
  end of the ledge, a ramp, a stair) and goes round by it; and if there is none he goes up the face, at
  `climb_speed` (0.6 m/s: four seconds for 2.5 m). So a 2.5 m ledge is worth about seven seconds.
- **The strike.** Only his head catches. Within `strike_distance` (2.3 m) he stops, rears back with his mouth open
  for `strike_warning` (0.6 s), and throws his head at where the boy was two tenths of a second before; `caught` is
  emitted only if it finds him, and is wired as the mummy's is. A step to one side in that moment and he misses, and
  is a second getting his head back. His body is in the way: it pushes the boy aside, and does not hurt him. While
  he is out he is in the group `pursuers`, so the boy stands wary and watches him.
- **Light drives him back.** He will not bring his head nearer a `Fire` or a flare than `light_reach` (2.5 m for a
  torch, 3.4 for a brazier: `Nearby.reach_of`). With the boy inside it he rears, hisses and circles at the edge of
  it, backs off as it comes at him, and strikes only when the light goes out or the boy leaves it. So a torch in the
  hand does not end the chase but holds him off, and a lit brazier is a safe place to stand. A fire that is only in
  his way he goes round. A beam of sunlight (`SunBeam`) is a wall to him, mirrors and all, and he throws himself
  back if it is turned onto his head. `fears_light` off, he fears neither.
- **His voice** is made in the script from noise: a long dry hiss, and the scrape of his scales as he moves. Both
  are louder the nearer his head is to the boy (nothing at forty metres, all of it at three), wherever the camera is,
  because left alone the camera looks the way the boy runs and he is behind it. He spits when he strikes, and his
  head on a door is a thud.

**What stops him, and what does not.**

- `loose` is what lets him out (the level editor's "Let out by": he hunts while what he is linked to is on). When it
  goes off he turns and goes home, back the way he came, and coils up or goes down his hole again. So a lever, a
  lock or a plate that stays down lets him out for good, and a plate that comes up again calls him off.
- "Wakes within" (`alert_distance`) wakes him when the boy comes that near where he rests; then only the boy's
  starting again puts him back.
- **A door shut in front of his head stops him** (`TombParts.Door`, which is the desert's door too), if it closes a
  passage: he batters at it and waits, and comes on when it opens. It must be shut before his head is through; his
  body does not hold it open or mind it shutting. He knows no way to the boy but a clear line and the boy's own
  trail, so he does not go round by another passage, but a gate standing in open ground stops him only until he
  can see the boy past it.
- A beam of sunlight across a passage stops him for as long as it shines, and a fire wide enough to fill one.
- Not stopped by: a pit or a gap (he goes down and comes up the other side), water, a ledge, a kerb, a block pushed
  into his way (he goes over it) unless it is more than 8 m high (`climb_limit`), running a long way (he does not
  tire or lose the trail), or being out of sight. A drop with no bottom takes him out of the world: he is put back
  where he rests, and comes again.
- When the boy is caught and starts again, he is back where he rests.

In the level editor he is "Apophis" on the People page: his length, his speed, how near the boy wakes him (0: only
what he is linked to does), whether he waits coiled or down a hole, whether he fears light, and "Let out by". The
test yard has him at the east end of its north side, coiled at the end of forty metres to be chased along: a torch
to pick up, a kerb, a pillar and a block, a ledge, a brazier, and a passage whose gate the plate beyond it shuts.

```
godot --headless --path . --fixed-fps 60 --script tools/apophis_test.gd [-- trace]
godot --path . --fixed-fps 60 --resolution 960x960 --script tools/apophis_sheets.gd -- <folder> [model head wake hole chase behind kerb ledge torch strike door home daylight cost yard]
```

The first runs him with nothing drawn and ends PASSED or FAILED: each thing above, and that no part of him is ever
under the ground nor his head through a wall. The second draws him (add `--rendering-method gl_compatibility` to see
him as the web build does). A frame of him costs about 0.02 ms to move and 0.06 ms to lay his body (on a desk), and he
is 3000 to 6200 triangles, by his length, in three things to draw (body, head, knives) and their shadows.

## The birds

`Birds.new()` is a flock (`scripts/birds.gd`): so many of one kind, living within so far of where it is put.

```gdscript
var doves := Birds.new()
doves.kind = Birds.Kind.DOVE     # SPARROW, DOVE, HOOPOE, SWALLOW, IBIS, HERON, EGRET, GOOSE, KESTREL, KINGFISHER, VULTURE, GRIFFON, KITE
doves.count = 14
doves.roam = 25.0                # how far from here they go
doves.position = Vector3(x, y, z)
add_child(doves)
```

In the level editor they are "Birds" on the People page (which kind, how many, how far they range). The test yard has
a station of them (doves and sparrows to run at, posts and a broken column for them to go up onto, a hoopoe, a
kestrel), waders, geese, a kingfisher and swallows at its pond, and vultures and kites over it.

- **The kinds** (`scripts/bird_kinds.gd`: measurements, colours, how each holds itself, flies and lives). In flocks
  about a camp or a ruin: house sparrows (hopping, up in a blur and bounding along with their wings shut between
  bursts) and laughing doves (walking with a nodding head). By itself on the ground: the hoopoe, barred black and
  white, its crest going up when it lands or is uneasy, and a flight like a big slow butterfly. Never down: swallows
  (the red-bellied one of the Nile), hawking low over water and dipping into it. At the water's edge: the sacred ibis
  (flies with its neck out and legs trailing), the grey heron (neck drawn back in an S, slow deep beats) and the
  cattle egret; they walk the shallows no deeper than their legs, probe and jab, preen, and stand on one leg. On the
  water: Egyptian geese, in pairs, leaving rings as they paddle, and running along the top of it to get off. On a
  high perch: the kestrel, which goes out to hang in the wind over open ground, wings going fast and shallow and tail
  spread, drops on what it sees and goes back up; and the pied kingfisher, which does the same over water and goes in
  with a splash. High up, in wide circles on still wings: the Egyptian vulture (white, black flight feathers, flat
  wings), the griffon (huge, wings in a shallow V, fingered tips) and, lower, the black kite with its notched tail.
- **Where they are.** A flock looks round it when it has been in the level a moment (and `rescan()` makes it look
  again): for the flat tops of whatever is solid (a column, a wall, a block, the top of a palm's trunk), for any
  Marker3D in the groups `bird_perches` or `perches`, for open ground, and, in anything in the group `water`, for
  shallows and for open water. It uses a few hundred rays, once.
- **The boy, and noise.** Each kind bears him so near and no nearer (`wary`: 3.6 m for a sparrow, 10 m for a heron),
  less if he creeps and more if he runs. Nearly that near, they stop feeding, watch him and edge away; nearer, they
  go up, a flock all together. A flock wheels round for a few seconds and comes down on what is high, and goes back to
  its ground when it has been quiet a while (to other ground, if he is standing on theirs); a heron or a goose goes
  off round in a wide circle and comes down somewhere away from him. Anything in the group `pursuers` puts them up as
  he does, and so does a shot: every gun in the group `guns` is listened to (`fired`), and every bird within 90 m of
  it goes up, the nearest first. `flush(from, within)` does it from code, and `flushed` says how many went.
- **Vultures** come down in narrowing circles over any Node3D in the group `carrion`, and over the boy when he has
  lain knocked down for six seconds; after a dozen more they land round it, hop nearer and tear at it; and they leave
  when it is gone or he gets up.
- **How they are drawn** (`scripts/bird_mesh.gd`). There are no bodies and no bones. A bird is built from its
  measurements as one mesh of about 300 triangles, every point of which says what it is part of (body, wing, neck,
  head, leg, tail, crest); each flock is one MultiMesh, and the vertex shader beats the wings (two halves, the outer
  following late), folds them along the flanks, bends the neck at two joints, nods the head, swings, tucks or trails
  the legs, fans the tail and raises the crest, all from eight numbers a bird. Beyond a distance that goes with its
  size a bird is drawn from a second mesh of 16 to 36 triangles moved by the same shader.
- **What it costs.** `birds.cost` is the script's time each frame in microseconds. On a desktop thirty sparrows cost
  about 0.1 ms a frame on the ground and 0.3 ms while all of them are in the air, and all thirteen flocks in the test
  yard (56 birds) about 0.3 ms together; each flock is two draw calls (and their shadows). A bird standing still
  costs nothing; one on its feet is seen to every other frame; and a flock more than 90 m beyond its range from the
  camera one frame in four.
- They are silent: no recordings have been added.

The kinds were chosen from the birds of the Nile valley as they were in the boy's day and as tombs show them: Charles
Whymper, *Egyptian Birds* (1909), which is of the boy's own decade and has plates of nearly all of these; the birds of
the marsh scenes of the tomb of Nebamun and the geese of Meidum; and the gods' birds (the ibis of Thoth, the falcon of
Horus, the vulture of Nekhbet, and the Egyptian vulture and the hoopoe that are hieroglyphs).

```
godot --path . --resolution 640x480 --script tools/bird_sheets.gd -- <folder> [kinds beat acts takeoff flock flush water soar far yard cost] [sparrow heron ...]
godot --headless --path . --fixed-fps 60 --script tools/bird_test.gd
```

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

## The railway

An engine and tender, two carriages, six kinds of goods vehicle, track, and a halt with what stands by a line (PROPS.md,
"The railway", lists them; the level editor's Railway page places them). A `Train` (`scripts/train.gd`) couples vehicles
and runs them along a line or a Path3D: wheels and rods turn, the bodies rock, the chimney smokes. He boards from a
platform, goes through a carriage or up the ladder at its end and along the roofs, jumps the gaps between vehicles, and
must duck under a low bridge or be knocked down. A ride is staged either with the train really moving or with the train
standing still and the world going by it (`TrainScenery`); the test yard's halt has a plate for each.

```
godot --path . --fixed-fps 60 --resolution 960x960 --script tools/train_sheets.gd -- <folder> [vehicles train dusk moving rods ride world lineside yard]
godot --headless --path . --fixed-fps 60 --script tools/train_test.gd
```

## Web build

```
godot --headless --path . --export-release Web build/index.html
```

`build/` is committed and served by GitHub Pages at https://sclondon.github.io/Outside/build/index.html

## Fire and the torch

`Fire` (`scripts/fire.gd`) is made of particles: a few dozen soft licks of flame, each lit pale at the foot of the fire,
carried up, cooling through orange to dark red and coming apart, each showing the frame for its age from an animated
sheet of flame pictures (`textures/fire_sheet.res`, 8 x 8 frames of flame in red and of smoke in green, painted by
`tools/bake_fire_sheet.gd`; run that again to change how a lick looks). A carried fire streams out behind (`streams`).
Burning oil draws its flames with the same shader (`Fire.flame_shader()`). Smoke is soft puffs from the same sheet;
sparks stream up and wink, and now and then it spits a handful of embers that fall (`sparks`, `spits`); it glows (`glow`,
`glow_reach`: a soft light drawn in the air round it); and the light it casts gutters (`flicker`) and reaches now further
and now less far (`breathing`). `tools/fire_sheets.gd -- <folder>` draws each kind by day and in the dark, a few frames apart.

A `HandTorch` (`scripts/torch.gd`) is a burning torch to carry: act picks it up, and he holds it up in front of him as he
goes; act throws it, duck and act puts it down, and it goes on burning where it lies. There is one by the fire in the test
yard, and "Torch to carry" is on the level editor's Puzzle page.

## Oil

Lamp oil, to spill and to set light to (`scripts/oil.gd`, `oil_jar.gd`, `oil_spill.gd`, `oil_mark.gd`). Nothing new
to press:

- **A jar of oil** (`OilJar`) is picked up with act like any pot. **Duck with it and it pours**: it tips over, and oil
  runs from its mouth for as long as he stays down, in a trail behind him if he sneaks along and in a puddle that
  spreads if he stays where he is. Stand up and it stops. A jar holds 40 measures, about nine metres of trail; a drop
  over it shows what is left while he pours. Act throws it, and **thrown it breaks** (so does one dropped off
  anything much over a metre, shot or kicked): what was in it is a puddle where it broke. Duck and act puts it down
  whole.
- **Oil lies where it fell**, black and shining with a brown edge, the ground stained round it; what touches runs
  together into one puddle. It lies on sand and on stone, on slopes, and not under water.
- **Any flame lights it**: a torch thrown down in it, or held to it by ducking (carried upright, the torch is too high
  to light what he walks over); a brazier or a campfire it has been poured up to; a flare; oil burning beside it.
  **Fire goes along it at a metre a second**, so a trail is a fuse, and each part burns for about seven seconds and
  is then a scorch. A gap stops it; oil poured into the gap carries it over.
- **A full jar in the fire bursts** after a moment (it smokes first): everything in it is alight at once. Shot with
  the flare pistol it does the same. So a fuse laid to a heap of jars is a bomb.
- **Burning oil** lights a cold torch that is in it and anything else that can be kindled; holds scarabs off and burns
  cobwebs, as any fire does; stops a mummy, which stands at the edge of it until it has burnt out; lights a tomb's
  brazier if it burns at its foot; and burns him. He can run through a line of it. If he stands in it he smokes, and
  after half a second he is thrown down and starts again from the last checkpoint. A flame that has only just caught
  does not count, so he has time to step back from what he lights.
- **Water** puts it out: oil that water rises over stops burning, and is oil again when the water has gone.
- **When he starts again** a jar that is broken or spent is whole and full where it began, and a spill laid by the
  level that has burnt is laid afresh. What he poured himself stays as it is.

In the level editor's Puzzle page: "Oil jar" (how much it holds), "Oil spill" (oil already poured: a trail of a
length and width along the way it faces, that can bend; with no length, a puddle) and "Fire dish" (a soot-black
stone dish in the floor). All three are triggers, to be touched when a door or anything else is asked what works it: a jar when it is broken,
a spill when the fire has reached its far end, a dish from the moment oil burns in it. The test yard has a station
out to the east: two jars, a torch and a campfire, a fuse under a cobweb to a heap of jars, and a dish that opens a
gate.

For other code:

```gdscript
Oil.is_burning_at(point, 0.5)        # is oil burning within half a metre of there? (static: ask from anywhere)
Oil.is_flame_at(tree, point, 0.5)    # that, or a Fire (torch, brazier, campfire) or a flare
var oil := Oil.of(self)              # the level's oil (made when first asked for)
oil.pour(from)  oil.spill(at, 40)  oil.lay(from, to)  oil.ignite(at)  oil.douse(at)  oil.clear()
```

`Oil` is in the group `flames` and its `burning` says whether any of it is alight. To be lit by burning oil, be in the
group `kindling` and have `kindle(by)`: it is called, several times a second, while oil burns within 0.3 m of the
node's origin. (Cold torches, in `torches`, are lit without it.) Wherever oil burns a `Fire` stands on it, so
anything that already minds a `Fire` (`Nearby.fires`) needs nothing more.

It is cheap: at most 320 patches of oil in a level (the oldest scorch gives way to new oil), drawn as three draws of
one MultiMesh however many there are, one more for all the flames, and at most six whole fires, three of them casting
light, moved to where the burning is. With all 320 alight it costs 0.04 ms a frame to work out and 0.13 ms to draw.

```
godot --headless --path . --fixed-fps 60 --script tools/oil_test.gd
godot --path . --fixed-fps 60 --resolution 960x960 --script tools/oil_sheets.gd -- <folder> [stone] [yard]
```

The first checks all of the above with nothing drawn and ends with PASSED or FAILED. The second draws it: puddles on
stone by day and by torchlight, a trail burning, a heap of jars bursting, and in the test yard the fuse on sand and the
boy carrying a jar and pouring. Add `--rendering-method gl_compatibility` to see it as the web draws it.

Not done: oil is not slippery, does not float on water, and does not burn through wood or rope.

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

The beetle is a Blender model: the object `scarab` in `models/khepri.glb`, built by `tools/build_khepri.py` with
Khepri (see there for how to build it again; `tools/khepri.blend` is the one to open). It is one unit long, and the
game makes it the size it wants. Because there are so many, three things about it are not as free as in other models.
Its legs are moved by a shader, which knows a leg by the mesh's UV map: U is how far down the leg a point is (0 at the
hip and all over the body, 0.45 at the knee, 1 at the foot) and V which three legs it steps with (1 or 0.5 in Blender).
Points moved keep theirs, and points made from them take it; a leg built from nothing has to be given it. It is all
one colour, the shader's black: its four materials (`scarab_shell`, `scarab_thorax`, `scarab_head`, `scarab_leg`) say
only how much each part shines, by their Roughness (0: wholly). And it should stay near its 124 triangles. Its normals
are set by hand in the build script (the head and legs are lit as flatter than they are), so it is point for point the
beetle the code used to make.

There is no body to a beetle. All of them are one MultiMesh (124 triangles each), moved in one loop and written to it
in one piece; their legs are moved by the shader. The ground is found with a ray straight down, once for each 0.2 m
square round the nest as a beetle first comes to it (28 a frame at most), and remembered; they keep apart by counting
themselves into the same squares. Two hundred of them held in a ring by a torch cost about 0.5 ms a frame on a desk
machine (50: 0.13 ms; 100: 0.26 ms; much the same running over new ground), and it is one draw call.

A `ScarabAmulet` (`scripts/scarab_amulet.gd`) is a scarab of gold and lapis the size of a hand, picked up and thrown
like a rock; a `ScarabSocket` (`scripts/scarab_socket.gd`) is a stone with a hollow for it, and is a pressure plate
that only the amulet presses, so it opens whatever a plate opens. The amulet is the object `scarab_amulet` in the same
model, one unit long: what is `amulet_gold` there is drawn in the game's gold in that colour, and what is
`amulet_stone` in the amulet's own `stone` colour.

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

## Khepri and the sun

`Khepri.new()` (`scripts/khepri.gd`) is a big scarab of lapis and gold, 0.45 m long, rolling a ball of sun 0.7 m
across: backwards, head down, its hind legs on the ball, as the harmless one of the swarm rolls its dung. The sun is
a real light, so a dark room is lit as it comes, and it turns as far as it travels. `Akhet.new()` (`scripts/akhet.gd`)
is where the sun is to be brought: two low hills of sandstone with a cradle of gold between them.

**The model.** The beetle, the ball and the horizon are a Blender model, `models/khepri.glb`, built by
`tools/build_khepri.py`, which also keeps `tools/khepri.blend` to look at and change by hand (the small scarab of
the swarms and the scarab amulet are in it too: see Scarabs). To build it again and have the game take it up:

```
blender --background --python tools/build_khepri.py
godot --headless --path . --import
```

(Changed by hand in `tools/khepri.blend` instead, it is exported from there as glTF to `models/khepri.glb`, +Y up;
running the script again would write over that.) What is in it, each thing named for what it is:

| In the model | What it is |
| --- | --- |
| `khepri` | An empty: the beetle is everything under it. It stands as it sits on a hill when the sun has risen, wing cases open and wings out, facing the game's +Z (Blender's -Y) |
| `body` | The gold shield over the thorax, the dark back under the wing cases, the belly |
| `head` | The head shield with its six teeth, and two eyes of lapis |
| `wing_case_left`, `wing_case_right` | The wing cases (one mesh, turned over for the right). The origin is the hinge; how it is turned in the model is how far it opens. Shut, it is not turned at all |
| `wing_left`, `wing_right` | The wings (one mesh): a fan of seven feathers in bands. The origin is the root; how it is turned is how it is held when it is out |
| `leg_fore_left`, `leg_mid_left`, `leg_hind_left`, and `_right` | The six legs (three meshes). The origin is the hip, which the game swings the leg about; its lowest point is its foot |
| `sun` | The ball. Its colours and the tongues of fire on it are drawn by the game's shader, not taken from the model |
| `akhet` | An empty: the horizon is everything under it |
| `ground`, `hill_east`, `hill_west`, `cradle` | The slab with its strips of gold, the two hills (one mesh) with a band of gold at the foot of each, the dish of gold and its ring |

The beetle has no bones in the model. The game (`Khepri._read`) makes one mesh of everything under `khepri` and gives
each thing a bone of its own at its origin, so moving an origin moves the joint, and nothing has to be weighted.
Its colours are the model's materials (`lapis`, `gold`, `gold_dark`, and the paints of the wings, `wing_gold`,
`wing_lapis`, `wing_turquoise`, `wing_red`, each with a `_shade` for every other feather): change a Base Color, export,
and the beetle changes (sixteen colours at most). A material's Roughness is how much it glints (1: not at all), and a material with Emission is
drawn bright of itself and not lit, as the wings are. The horizon is drawn in the game's own sandstone and gold, in the
colours of the model's `hill_stone`, `ground_stone`, `horizon_gold` and `cradle_bronze`. The beetle is modelled 0.45 m
long and `beetle_length` makes all of it bigger or smaller.

What is still made in the code, and why: the sun's glow and its light, and the column of light it stands on in the
horizon (they are light, sized as the sun rises); the fire on the ball (a shader, so that it is seen to roll); how
the legs step, the wings beat and the cases open (from the hinges the model gives); the sounds; and what is solid:
the ball is a sphere of `Khepri.SUN` and each hill a box from `Akhet.HILL`, so a ball or a hill reshaped in the model
looks different but is solid where it was. The beetle sits on its hill at `Akhet.perch()`, likewise.

**Where it comes from.** Khepri is the sun at dawn. The Egyptians watched the sacred scarab roll its ball of dung
over the ground and saw in it what moves the sun over the sky; and because young beetles seemed to come out of the
ball of themselves, the scarab is the sign for *kheper*, "to come into being", and the god's name means "he who
comes into being". In the books painted in the royal tombs the night's journey ends with a scarab pushing the disc
up out of the eastern horizon. The horizon, *akhet*, is written as the sun between two hills, which is what an
`Akhet` is. Winged scarabs of gold and lapis holding up the sun are among the commonest jewels of the dead, and that
is what the beetle is dressed as. How true the game is to it: the beetle is. A dung beetle does push backwards with
its hind legs, head down; does keep a straight line; and does climb onto its ball and turn about on top of it, to
take its bearings from the sky. In the paintings Khepri holds the disc before him in his fore legs: the game follows
the beetle, not the paintings. That it turns right at a wall, that it can be steered with blocks, and that the
horizon is a cradle that opens doors, are the game's.

**How it moves** is simple, and can be learned by watching, like a wind-up toy on a floor of squares:

- It rolls in a straight line, a metre a second (`pace`), from the middle of one square to the middle of the next
  (`step`, 1 m), until something is in the way: a wall, a pillar, a pushed block, a shut door, a kerb higher than
  0.25 m (`kerb`), the edge of a drop, water, or the boy.
- Then it turns a quarter turn to the right (`turns`: or left); if that is shut too, the other way; if both are, back
  the way it came (`turns_back`; turned off, it waits in a dead end instead); and shut in all round, it waits and tries
  again every second.
- Its squares are its own: counted from where it is put, lying as it is turned, and it sets off along its own +Z. It
  never leaves them, and nothing in it is left to chance, so whoever makes a level can count squares. `square` is
  where it is; `path` is every square it has come to.
- It goes while it is let go (`running`: a lever, a plate or anything else linked to it, or `starts_itself`), and
  finishes its square and stops when it is not. Stopped, the beetle climbs onto the ball and looks about.

So the boy steers the sun through a room by pushing blocks into its way, standing in its way, opening and shutting
doors on it, and working what lets it go. He can also turn it by hand: the act button beside it turns it a quarter
turn (at once if it is stopped, at the next square if it is rolling). He cannot pick it up or push it: walking into it,
he stops against it. If something comes into its way while it is between two squares it goes back to the one it left
and thinks again. If he stands on it, it waits. It cannot be hurt and nothing chases it.

**The horizon.** When the sun comes to the cradle of an `Akhet` the beetle lets it go: it rises between the hills on
a short column of light and stays, the room is lit for good (its light reaches nearly twice as far), and the Akhet is
on, for good: it is a thing that is on or off like a pressure plate, so a door or anything else is linked to it. The
beetle flies up onto a hill and sits there with its wings out. An Akhet takes three squares in a row (a hill, the
cradle, a hill: the hills are solid) and the sun comes in along its Z, from either side; stand it on the sun's squares.

**What the sun does on the way**, from being a light and being heavy:

- It lights a `SunDisc` it passes within 2.2 m of (`sun_reach`), for as long as it is that near, unless something
  solid stands between. (`sun_disc.gd` asks everything in the group `sunlight` whether it `shines_on` it.)
- Scarab swarms keep off it as they do off a flare, so he is safe beside it. It is not a fire: `Nearby.fires` does
  not count it, so it burns no web and lights no torch or oil. `Nearby.feared(tree)` is the fires and the group
  `sunlight` together, and is what the swarm now asks.
- It presses any pressure plate it rolls onto, while it is on it (but not one that only he presses).
- A beam of light is stopped by it, as by anything solid.

`reset()` puts it back where it started, and an Akhet's `reset()` turns it off and sends its sun home. Moved in the
level editor, it starts from where it is put.

```gdscript
var sun := Khepri.new()
sun.turns = Khepri.Turns.RIGHT
sun.position = the_first_square      # and turned to face the way it is to set off
add_child(sun)
var horizon := Akhet.new()
horizon.position = sun.place_of(Vector2i(4, 2))
add_child(horizon)
horizon.changed.connect(func(on: bool) -> void: door.is_open = on)
lever.changed.connect(func(on: bool) -> void: sun.running = on)
```

The level editor has "Khepri and the sun" (which side it turns to, its pace, the size of a square, whether it starts
itself, whether it turns back from a dead end, and what lets it go) and "Horizon (akhet)" (how high the sun rises;
choose a door and then the horizon, as with a plate) on its Puzzle page. Where the ground is not level it goes as far
as a slope of one in four and no further, so in the desert give it level ground.

The test yard has a station for it in the far south-west corner, beyond the jackals: a walled court with a floor of
squares (`scripts/khepri_court.gd`, which says how it is done). The lever by the way in lets the sun go; left alone
it goes round by the walls, through a dark alcove, past a sun disc and over a plate; push the two blocks onto their
marks and it turns twice and comes to the horizon, which opens the door. The plate outside puts it all back.

It is one draw for the beetle, wings and all (about 900 triangles on a skeleton of twelve bones), one for the sun,
one for its glow, and one light without shadows; the horizon is one mesh of four materials. What it asks of the world it asks only at the middle of a square (for each way it tries, six rays down
and a shape swept along it) and once a step while it rolls (the shape again).

```
godot --headless --path . --fixed-fps 60 --script tools/khepri_test.gd
godot --path . --fixed-fps 60 --resolution 960x960 --script tools/khepri_sheets.gd -- <folder> [model camera roll dark sunrise akhet court yard]
```

The first runs it with nothing drawn and ends PASSED or FAILED: it rolls straight at its pace, turns at a wall, the
other way, back from a dead end, waits shut in, is turned by the act button, is turned and stopped by the boy, keeps
off drops and out of water, goes over a low kerb and not a high one, presses a plate, lights a disc, is feared by
scarabs; in its court it never finds the horizon alone, and does with the blocks pushed (by the boy too), the same
way square for square each time; and it is made, linked, kept and moved in the desert as the editor does it. The
second draws it (add `--rendering-method gl_compatibility` for the web's renderer).

## The Ba

`Ba.new()` is a Ba (`scripts/ba.gd`): the part of a dead man that flies out of his tomb by day, which the Book of the
Dead draws as a bird with his own head. Here it is a friend, the spirit of whoever lies in the tomb, and it shows the
boy the way. It is a falcon's body half a metre high, pale, with painted wings (turquoise, a line of gold, long pale
feathers tipped with blue), a man's head in the striped headcloth, and two small arms that it holds up when it calls.
It shines a little, with a soft light round it and a small one that reaches a couple of metres, so it is seen in a
dark tomb. That light is not a fire: nothing that looks for fires finds it.

```gdscript
var ba := Ba.new()
ba.route = [first_place, second_place, the_last_place]   # in the world; or give it Marker3D children
ba.position = where_it_waits
add_child(ba)
ba.arrived.connect(...)     # it has landed at somewhere it was leading him to
ba.finished.connect(...)    # he has come to the last place with it
ba.lead_to(the_door)        # or: one thing, or one place, to lead him to from wherever it is
ba.show_way(points)         # or: fly these places once, look back, and come back (`came_back`): a hint
ba.on = false               # it flies off and is gone; true, and it flies in out of the air
```

- **Leading.** It sits and watches him, its head turned to him. When he comes within `near` (4 m) it takes off and
  flies ahead: to the next place, or `hop` (10 m) towards it, or less far if he could not see it there; lands, turns
  round to look back at him, and waits. If he comes no nearer it calls (two soft notes, made in code, wings half out
  and arms up), and when he has hung back for `patience` seconds (14), or gone well off the other way, it flies back,
  lands beside him on the side it wants him to go, calls, and flies ahead again. Each time it has to come back it
  waits longer before the next. At the last place it stays, or with `leaves_at_end` it goes once he has come.
- **Only there.** With no way to lead it sits where it is put and watches him. With `shy` as well it sits on what is
  high within `roam` of there (the tops of solid things, and any Marker3D in the groups `perches` or `bird_perches`)
  and flits to the perch furthest from him when he comes near.
- **Flying.** A crouch, hard beats to get up, beats and glides by turns, a lean into every turn, and a rearing back
  with its legs down to land; its head stays level through all of it. Before it goes anywhere it finds a way that
  touches nothing, by sweeping a ball along it: straight, or higher (as high as a roof lets it), or round one side.
  If there is no way at all (a shut room) it goes as a spirit can: it fades where it is and comes back where it was
  going (`spirited` counts these). It lands only where there is room for it, on whatever is under the place it was
  given, so a place put a little over a block is the top of the block.
- **It is not a body.** Nothing can touch it, catch it or be stopped by it; hounds, mummies and the rest do not know
  it is there. The boy glances at it (it is in the group `interest`).
- **The model** is `models/ba.glb`, built in Blender by `tools/build_ba.py`, which also keeps `tools/ba.blend` to
  look at and change by hand. It has no bones: it is separate things, each named for what it is (`body`, `head`,
  `wing_arm` and `wing_hand` for the two halves of a wing, `legs`, `arms`; the other wing is the same two turned
  over), and each thing's origin is where it is hinged, so moving an origin moves the joint. Its colours are
  materials with plain names (`feather`, `turquoise`, `gold`, `skin`, `cloth_gold`, `cloth_blue`...); the stripes of
  the headcloth are cut into it. To build it again, and have Godot take it up:

  ```
  blender --background --python tools/build_ba.py
  godot --headless --path . --import
  ```

  (Changed by hand in `tools/ba.blend` instead, it is exported from there as glTF to `models/ba.glb`, +Y up; running
  the script again would overwrite both.)
- **How it is drawn** (`scripts/ba_mesh.gd`). About 980 triangles. Each of its things is made into one mesh in one
  material when the model is first read, every point keeping the colour of the material it had, so a Ba is eight
  things to draw however many colours it is painted in. That material lights it in two flat tones, adds its own
  shine, and thins it away when it comes and goes by leaving out points of it. It casts no shadow.

In the level editor it is "Ba (spirit bird)" on the People page. Its way is a line of points, as a river's is: drag
each, add more with Points, take the last away (down to the one it sits at, which leaves it only there). It has Shy,
how near he comes before it flies on, how far ahead it flies, how long before it comes back for him, whether it goes
at the end, and "Called by": link it to a plate, a lever or anything else that is on or off and it is not there until
that is on (and, unless "Stays once it has come" is off, stays after). With nothing linked it is there from the start.

The test yard has a station for it, out beyond the scarabs and the grappling hook to the north (about -4, -76): one to follow
round a wall to a block, a shy one on three posts, and two plates, one that calls a third out of the air and one that
has it show the way round the wall.

```
godot --path . --fixed-fps 60 --resolution 960x960 --script tools/ba_sheets.gd -- <folder> [model wings far flight lead fetch appear shy show dark yard]
godot --headless --path . --fixed-fps 60 --script tools/ba_test.gd
```

The first draws it (strips are consecutive moments). The second runs it with nothing drawn and ends PASSED or FAILED:
it waits, flies when he nears, lands ahead where he can see it, goes round a wall and under a roof, calls and comes
back when he hangs back or strays, ends at the last place, comes and goes with its switch, goes as a spirit out of a
shut room, flits when shy, shows a way, is made and linked in the desert as the editor makes it, and is never inside
anything solid or under the ground.

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

## Medjed

`Medjed.new()` is a whole one (`scripts/medjed.gd`), facing along his own +Z: a sentinel who cannot be hurt and does
not chase, and whose look is what has to be kept out of.

**Where he comes from, and how true this is.** Spell 17 of the Book of the Dead has one line about him: "I know the
name of that smiter among them who belongs to the House of Osiris, who shoots with his eye, yet is unseen." His name,
Medjed, means the smiter. That line is nearly all that is known. The Greenfield papyrus (the Book of the Dead of
Nestanebetisheru, of about 950 BC, in the British Museum) draws him, twice: a plain dome like a sheet over a post, two
eyes looking out of it, two bare feet under the hem. So what is his own here is the look of him (kept as it is drawn:
the off-white shroud 1.5 m tall, the almond eyes with their dark line and heavy brows, the feet, and nothing else), that
he strikes with his eye, and that he can be unseen. The rest is made up for the game: that he stands guard and looks
from side to side, that there is a moment's warning, that he comes shuffling to look, that a plate or a mirror shuts
his eyes. Nothing old says how his look works, or that anything turns it back.

- **The model** is `models/medjed.glb`, built in Blender by `tools/build_medjed.py`, which also keeps
  `tools/medjed.blend` to look at and change by hand. It has no bones: it is separate things, each named for what it
  is, which the game reads and moves.
  - `shroud`: the sheet. Its origin is the ground under him; the game bobs and rocks it there as he shuffles. The
    swing of the hem is still done by the game, which bends the mesh from its lowest point up for 0.8 m, so a shroud
    reshaped in Blender swings as this one does.
  - `eye_left` and `eye_right` (his own left is +X), hung from the shroud: the dark line round the eye, the white,
    the pupil and the brow, lying just off the cloth. Each has four shape keys: `shut` (the lids closed, the brow
    down), `wide` (as he stares), `look_left` and `look_right` (the pupil moved over). As he usually has them is the
    Basis; the game sets the keys between 0 and 1 and mixes them.
  - `foot_left` and `foot_right`: a bare foot with its toes and the shin over it. A foot's origin is the ground under
    the middle of him, and is what the game lifts, slides and tips it about; it is turned a little toe out.

  Its colours are materials with plain names: `linen` (a warm off-white, so that the sun does not burn it out to
  white), `skin`, `eye_dark` and `eye_white`. The game takes each colour from the model, so changing a material's
  Base Color and exporting changes him; whatever is painted in a material with "white" in its name is what lights up
  as he makes ready. The game lights the shroud and the feet in flat tones as it does everything else, and makes the
  two eyes one mesh in one material when the model is first read. To build it again, and have Godot take it up:

  ```
  blender --background --python tools/build_medjed.py
  godot --headless --path . --import
  ```

  (Changed by hand in `tools/medjed.blend` instead, it is exported from there as glTF to `models/medjed.glb`, +Y up,
  with shape keys; running the script again would overwrite both.) The fan on the floor and the lines from his eyes
  are not in the model: they are drawn from what he can see at that moment.
- **His gaze** is drawn on the floor: a pale fan as far as he sees (`reach`, 9 m) and as wide (`cone`, 30 degrees),
  with rings running out along it and a thin line from each eye down the middle of it. The fan stops at whatever stops
  his sight, so the shadow of a pillar in it is the place to stand. It is laid over what is under it rather than added
  to it, so it shows on pale sand in the sun as well as on a dark floor, in both renderers; it lies on the floor he
  stands on and is tipped as that is, so on ground that rolls it will cut into the rises.
- **He sweeps**: he turns his whole body from side to side through `sweep` degrees (360: round and round) at
  `turn_speed` degrees a second, waits `pause` at each end, and shuffles his feet as he turns. His hem swings after him.
- **Seen**: the boy is in the gaze when he is within reach, inside the cone, and nothing solid is between the eyes and
  both his chest and his head. A wall, a pillar, a door, a block or a crate hides him if it covers either: so a block
  pushed along in front of him is a shield (it covers his chest), and something only knee high hides him when he ducks
  behind it and not when he stands. A mummy or a hound hides nobody. Then the eyes go wide and bright, Medjed stops and
  turns to follow him (`tracks`, 70 degrees a second), the fan closes onto him and turns gold, and a hum rises, for
  `warning` seconds (0.6). In sight at the end of them, he is smitten: a flash, and `caught`, wired as the mummy's is.
  Out of sight in time, it dies down (half as fast as it rose) and he goes back to looking.
- **Unseen** (`unseen`): the shroud is not drawn until he fires, and for three seconds after. The eyes, the feet and
  the gaze are.
- **Follows** (`follows`): having lost the boy he does not go back to looking at once. He shuffles to where he last
  saw him (`shuffle_speed`, 0.5 m/s: never faster), no further than `roam` from his post, looks, turns and shuffles
  home, and turns back to face the way he was put. He sees as he goes. He is flat underneath: any kerb stops him, he
  steps off no edge, and what he cannot get round he does not try to.
- **On or off, as a door is.** Whatever he is linked to shuts his eyes while it is on (`worked`); with
  `wakes_when_worked` it is the other way about, and they are shut until then. With his eyes shut he stands and sees
  nothing.
- **A mirror** (`scripts/mirror.gd`) turned to face him sends his gaze back at him: he shuts his eyes for `dazzle`
  seconds (4) and sweeps on blind, so each time his look crosses the mirror there is that long to move in. It costs
  nothing more, since the fan is already feeling for what stops it. It is not a `SunBeam`: the gaze is not thrown on
  round a corner, and does nothing to a sun disc.
- **Guns** do nothing to him, as they do nothing to a mummy.

```gdscript
var medjed := Medjed.new()
medjed.sweep = 120.0
medjed.follows = true
medjed.position = his_post
add_child(medjed)                 # he finds the boy himself (`Nearby.player`)
medjed.caught.connect(...)
medjed.worked = plate.pressed     # shuts his eyes; `reset()` puts him back at his post
```

What he costs: two rays in a step of the game at the very most. While the boy is in the cone, one to his chest, and
one to his head if that one gets through; otherwise one spoke of the fan, each of the eleven in its turn (so the fan
on the floor is about a sixth of a second behind him). Far from the boy (45 m past his reach) he casts none and draws
no gaze. He is 456 triangles of shroud, 148 of eyes and 250 a foot, and six draws with the gaze.

The level editor has "Medjed" on its People page: how far he looks round and how fast, how far he sees, the warning,
unseen, whether he comes to look and how far, and "Eyes shut by" (with "Shut until then" for the other way about).
The test yard has a station for him out to the east, beyond the light and mirrors: two lanes with a wall between. In
one he stands at the far end with pillars, a block to push, a mirror, a plate that shuts his eyes while it is stood on
and a lever at his feet that shuts them for good; in the other is one that is unseen and comes to look, as far as a
kerb.

```
godot --headless --path . --fixed-fps 60 --script tools/medjed_test.gd
godot --path . --fixed-fps 60 --resolution 960x960 --script tools/medjed_sheets.gd -- <folder> [model eyes sweep smite cover unseen follow mirror side yard]
```

The first runs him with nothing drawn and ends PASSED or FAILED: he sweeps and waits; the boy in the open is smitten
after the warning and not before; behind a block he is not, nor ducked behind a low one; he runs from block to block
while Medjed looks away; a mirror shuts his eyes; one that follows comes, no further than he may and not over a kerb,
and goes home; and in the desert, made as the editor makes him, a plate shuts his eyes and off it the boy is caught.
The second draws him (by day and in the dark by a torch; add `--rendering-method gl_compatibility` for the web's).

In the tombs he keeps a way that has no door (see "Tombs"): he stands at the far end of a plain stretch and looks back
down it, and does not turn. In the tomb's side view the fan is seen nearly edge on: it shows as a pale band along the
floor and the two lines over it, which is enough to see where he looks and how far, but not how wide.

## The sphinx

`Sphinx.new()` (`scripts/sphinx.gd`) is a sphinx of sandstone: a lion lying on a low base with its forepaws out in
front, and on its shoulders a king's head in the striped headcloth, a ram's, or a falcon's (`head`). It is a statue,
and it is alive when it wants to be.

- **Its size** (`size`) is its length: 2.5 m for one of an avenue, 6 for one that stands at a door, 12 and more for a
  landmark. It is solid all over and he climbs about on it: onto the base, a forepaw or a hind paw, from there a haunch
  or an elbow, from there its back, and from its back its head (on a great one each is a ledge to catch). `wear` is how
  weathered it is: lumpy and stained, the cobra gone from its brow past a third, its beard past a half, its nose past
  six tenths. `painted` is as it was new: the headcloth blue and yellow, the face red, the eyes lined in black.
- **It asks for something.** Between its forepaws is a low offering slab, and behind that, against its chest, a stele
  with a round top (an `Inscription`) that has its riddle on it in hieroglyphs. When he comes between the paws its eyes
  open and glow, its head turns a little to look down at him, dust falls from its neck, there is a low sound of stone
  moving (made in code), and the riddle comes up in words across the top of the screen and goes into the notebook. The
  answer is a thing he can carry, put down between the paws or thrown onto the slab.
- **The right thing**: it is taken onto the slab and stays there, the eyes blaze pale gold, and the sphinx is on for
  good. It is a trigger like a pressure plate (`changed`, `on`): link a door, a bridge or a sand fall to it. With
  `opens_itself` the stele sinks into the ground and there is a doorway in its chest, and a passage through it and out
  under its tail: stand its rump against a wall or a pyramid's door and that is the way in. (The way is a tenth of its
  length wide and 0.16 of it high: room to walk through one of 9 m or more. It has been tried at 12.)
- **A wrong thing**: the eyes go red, it growls and shakes its head, and its right forepaw sweeps the slab clear. The
  thing is put down unharmed on the ground beyond its left paw (a jar of oil is not broken), to be picked up again, and
  the riddle is put up once more. It does not hurt him. With `wrathful`, the third wrong thing is one too many: the
  paw is lifted and brought down and it emits `caught`, as a mummy does.
- **Buried** (`buried`, 0 to 1) it lies in a heap of sand to its neck, as the Great Sphinx did for most of its life: a
  `SandPile`, which he can walk up. It sleeps, and the paws and slab are under the sand. While what it is linked to is
  on (a lever, a plate: "Sand cleared by" in the editor) the heap goes down, and is gone in eight seconds
  (`uncover_time`); it stops if the lever is put back. Then it can be woken. With nothing linked to it, the sand is
  only how it looks.

What it can ask for (`wants`), and the riddle that goes with each (`riddle` puts other words in its mouth and on its
stele; the thing wanted stays the same):

| It wants | Its riddle |
| --- | --- |
| A burning torch | I eat wood and am never full. I drink water and I die. Bring me, living, on a stick. |
| A torch that is out | Yesterday I was a sun in the hand. Today I am black and cold. Bring me the stick that waits for fire. |
| The scarab amulet | Khepri rolls the sun up out of the night, as a beetle rolls its ball. Bring me Khepri, in gold and blue stone. |
| The iron, bronze or gold key | I have teeth and bite nothing. I open what is shut. Bring me the black one, of iron. (...the brown one, of bronze; ...the one that shines like the sun.) |
| A canopic jar | I wear a head for a lid. I keep safe what a dead man will want again. |
| A jar of oil | The lamp drinks me. Poured out, I am a black road for fire to run along. Bring me in my jar, unbroken. |
| A stone to throw | I am older than the kings. I have no wings, yet a boy's arm makes me fly. |
| A pot | I was river mud until the fire made me hard. I am all mouth and belly, and my belly is empty. |
| A shovel | I have one iron tongue and a long wooden neck. I eat sand all day and am never fed. |
| A pickaxe | I have two horns of iron and one leg of wood. Where I strike, stone opens. |
| A hand brush | I have a hundred hairs and no head. I wake old kings gently, a grain at a time. |
| A lantern | I am a house of glass with a roof of tin. A flame lives in me and the wind cannot find it. |
| A basket of spoil | I was the leaves of a palm. Now I carry the desert away, one load at a time. |
| A khopesh | I am bronze, and bent like the new moon. The king holds me over his enemies. |
| The grappling hook | I have iron claws and a tail of rope. I climb first, and you come after. |

`Sphinx.what_is(thing)` is the name it knows a thing by (a torch is `torch` or `cold_torch` as it burns or not, so a
torch can be lit to make it right); anything else can be given a name with the meta `sphinx_thing`. A thrown jar of
oil breaks on whatever it hits first, so that one is put down (duck and act).

In the level editor it is "Sphinx" on the Stone page: its length, head, how weathered, painted, what it wants, its own
riddle, buried, opens itself, wrathful, and its stone. Choose a door and touch the sphinx as what opens it; choose the
sphinx and "Sand cleared by" to say what uncovers it. (The "Great sphinx" beside it is the fixed model, 25 m long, that
was called "Sphinx" before.) The test yard has a station out to the west, beyond the puzzle parts: a great one that
wants the amulet and opens itself, with the things to give it in a row; a small ram-headed one that is wrathful; a
painted falcon-headed one; and one buried, with its lever.

What is Egyptian, and what is the game's. Egyptian: the sphinx itself, a lion with the head of the king (and it is
the king: a guardian, not a monster); the ram-headed ones that line the avenue at Karnak, which are Amun's, and the
falcon-headed ones; the headcloth, the cobra and the beard, and that the Great Sphinx has lost the last and its nose;
that it was painted; that it lay buried to its neck; and the Dream Stele that stands between the Great Sphinx's paws,
which says that Thutmose IV, a prince, slept in its shadow, and that it spoke to him in a dream, asked him to clear
away the sand that lay on it, and promised him the throne. Offerings were laid before it. The game's: the riddles. A
sphinx that asks riddles and kills is the Greek one at Thebes, a different creature; no Egyptian sphinx is known to
have asked anything but that the sand be cleared. The riddles here are written for the game, in the manner of the
Egyptian wisdom texts (short sayings, things that speak for themselves), and so are the glowing eyes, the paw that
moves, and the way in through its chest (though people have looked for one in the Great Sphinx for centuries).

**The model** is `models/sphinx.glb`, built in Blender by `tools/build_sphinx.py`, which also keeps
`tools/sphinx.blend` to look at and change by hand. It is one metre long, lying on the ground and facing the game's
+Z (Blender's -Y), and has no bones: it is separate things, each named for what it is, and a thing that turns has its
origin where it is hinged, so moving an origin moves the joint.

| In the model | What it is |
| --- | --- |
| `base` | The block it lies on (0.1 thick in the model; the game makes it as thick as suits the size) |
| `body` | The lion: trunk with its shoulders, ribs and spine, the two haunches, the hind paws, the tail round the right haunch; and the way through it from chest to rump, which is always there |
| `chest_plug`, `rump_plug` | The stone that shuts each end of that way in a sphinx that does not open itself |
| `passage_frames` | The frame round each end of it in one that does |
| `foreleg` | The right foreleg, the one that sweeps the slab: its origin is the elbow. The left is the same turned over (`foreleg_mirror` is only there to be looked at) |
| `king_head` | Neck, ears and the nemes (cap, band, wings, lappets, tail). Its origin is where the neck turns, as is that of every other thing of a head |
| `king_face`, `king_face_worn` | The face; and the same with the nose broken off (worn past six tenths) |
| `king_uraeus`, `king_beard` | The cobra at the brow (gone past a third) and the false beard (gone past a half) |
| `king_eye_l`, `king_eye_r` | The eyes, each its own thing so that it can open and glow: its origin is its middle, its own +Z the way it looks |
| `ram_head`, `ram_eye_l`, `ram_eye_r` | The ram |
| `falcon_head`, `falcon_beak`, `falcon_beak_broken`, `falcon_eye_l`, `falcon_eye_r` | The falcon, its beak, and the beak with its tip gone (worn past seven tenths) |
| `slab`, `stele` | The offering slab and the stele, each about its own foot (the riddle is written on the stele's flat front by the game) |

Its colours are materials with plain names. `stone`, `hollow` (the dark of the way through) and `broken` are always
stone, drawn by the stone shader (`Toon.sandstone`). The rest are paint: `lapis` and `ochre` (the stripes of the
cloth, which are cut into it), `skin`, `kohl` (brows, the lines of the eyes), `horn`. A painted sphinx shows each in
the colour the model gives it, so changing a material's Base Color and exporting again repaints it; a bare one draws
them as stone a little lighter or darker (`SphinxMesh.TONE`). To build it again, and have Godot take it up:

```
blender --background --python tools/build_sphinx.py
godot --headless --path . --import
```

(Changed by hand in `tools/sphinx.blend` instead, it is exported from there as glTF to `models/sphinx.glb`, +Y up,
hidden things too: the other heads and the worn pieces are hidden in the file so that the king can be seen. Running
the script again would overwrite both.)

What is still worked out in the game, and why. Its size: `scripts/sphinx_mesh.gd` makes the meshes `size` times
bigger rather than scaling nodes, because the stone shader works in metres (its courses and cracks would stretch),
and makes the base, slab and stele as thick as suits that size. Its weathering: every point is moved a little, by an
amount that is a slider. What is solid: boxes and hulls from the numbers at the top of that script, which the model
was built round (they are the same in the build script), so a lion made much fatter in Blender wants those changed
too. And the riddle, the sand, the dust and the light of the eyes.

What it costs: about 6,600 triangles for a king and 4,800 for a ram or a falcon (it was 3,000: the face, the paws
and the trunk are finer), in five draws bare (body, the paw that moves, head, two eyes) as before, besides the slab
(three) and the stele (two, one fewer), with one light that is on only while its eyes are; painted, a few more. Two
sphinxes that are the same in every way share their meshes.

```
godot --headless --path . --fixed-fps 60 --script tools/sphinx_test.gd
godot --path . --fixed-fps 60 --resolution 960x960 --script tools/sphinx_sheets.gd -- <folder> [heads faces sizes wear wake right wrong opens wrath buried night yard] [banded]
```

The first runs it with nothing drawn and ends PASSED or FAILED. The second draws it: each head from all round and
close to, every size beside the boy, weathered and painted, each thing it does as a strip of moments, by torchlight,
and its station in the yard.

In a tomb the sphinx has one more thing said to it: `sweep_to`, the place in the world where a thing it refuses is put
down (with none said, out beyond its paw as before). A tomb seen from the side has only one line a thing can lie on.

Not done: the paw that sweeps goes through him if he stands in its way (it does not push him); nothing but the things
he carries can answer it; and the passage through it is a plain straight one.

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

## The gate guardians

The dead of Egypt went down through a row of gates, each kept by a seated demon with the head of a beast and a knife in
its fist. Whoever could say the keeper's name passed; whoever could not was cut down. The names were written in the
Book of the Dead so that the dead man would have them by him. That is the puzzle: a keeper at a gate, and somewhere a
leaf of the book with its name on it.

- **`GateGuardian`** (`scripts/gate_guardian.gd`): the keeper, 1.9 m to the top of its head, seated on a block on a
  plinth, wrapped like a mummy or in a kilt (`dress`), with a long knife upright in each fist (`knives`: or only in the
  right). Its head (`head`) is a crocodile's, snake's, vulture's, hippopotamus's, ram's, jackal's, hare's, lion's or
  bull's, or left alone is the one that goes with its name. It breathes, its head follows him, its eyes show in the
  dark, and its knives twitch when he is within `notice` (5 m).
- **It asks** when he steps onto the threshold of its gateway (`gate_at` metres to its left; 0 and it sits in the
  gateway itself), or when he comes up to it and acts. The game stands still and three names come up, each a button the
  size of a hand with the name in hieroglyphs, and "Step back", which says nothing.
- **The rule.** One of the three is its own; the other two are dealt from the rest of the list. The English is written
  under a name only if he has found the leaf that carries it, and only under the right one: so with the leaf he reads
  the answer, and without it he has one chance in three, or must know the signs from a leaf he read somewhere else.
  The right name: it bows its head, lowers its knives, and is on for good. A wrong name: it rises and strikes, he is
  `caught` (wired as the mummy's is), and the three names are dealt afresh, so a second guess is no better than the
  first. Which names come up is settled by the level (`seed`, which the desert makes from the ground's seed and the
  guardian's number) and by how many wrong answers it has had, never by the clock: a level is the same every time.
- **On or off.** It is on once named, as a pressure plate is (`changed`): choose a door, a bridge or anything else in
  the editor and "Choose what works it". With `bars_way` it needs no door: two great knives stand crossed in its gateway
  (`wide` by `tall`), solid, and swing up out of the way when it is named.
- **`BookPage`** (`scripts/book_page.gd`): a leaf of papyrus, open or `rolled`, that hangs a hand above the ground and
  turns so as to be seen. He takes it by walking onto it (or acting). It comes up large, the game standing still until a
  touch puts it away: the keeper as the papyrus draws him, his name in signs, the name in English, and where it is from.
  Which name it has is `who`; left alone it takes the name of the nearest guardian that has no leaf yet.
- **What he has found** is kept for the level, not for the game (`BookOfTheDead.of(node)`, a node under the level): a
  level started again has forgotten its leaves. Each is written into the journal, and once there is one the notebook
  has a tab more, "Papyrus", with a page of the leaves found: the keeper, his name in signs and in English.

```gdscript
var keeper := GateGuardian.new()
keeper.who = 6                     # its place in BookOfTheDead.NAMES: "He who lives on snakes"
keeper.bars_way = true
keeper.position = beside_the_gateway
add_child(keeper)
keeper.changed.connect(func(on: bool) -> void: door.is_open = on)
keeper.caught.connect(...)

var leaf := BookPage.new()         # (who = -1: the nearest keeper's name)
leaf.position = somewhere_else
add_child(leaf)
```

The level editor has "Gate guardian" (its name, head, what it wears, one knife or two, whether it bars the gateway,
where the gateway is and how big, whether it asks whoever steps onto the threshold, its size) and "Leaf of the Book of
the Dead" (whose name, rolled or not) on its Puzzle page; a guardian is one of the things a door can be opened by. The
test yard has a station, south of the railway and beyond everything else: a wall with three gateways and a keeper at
each, the first keeping a stone door and the others barring their own, the first leaf in the open and each of the
others in the cell behind the gate before.

The figure is a Blender model, `models/guardian.glb`, built by `tools/build_guardian.py`, which also keeps
`tools/guardian.blend` to look at and change by hand:

```
blender --background --python tools/build_guardian.py
godot --headless --path . --import
```

(Changed by hand in `tools/guardian.blend` instead, it is exported from there as glTF to `models/guardian.glb`, +Y up;
running the script again would put back what the script says.) It has no bones. It is separate things, each named for
what it is, and where a thing's origin is put is where the game hinges it:

- `guardian_wrapped` holds the figure in wrappings: `plinth`, `seat` (the block, its back and its line of gold),
  `feet_wrapped`, `thighs_wrapped` and `shins_wrapped` (each pair one thing, lying along the limb from the hip and from
  the knee), `trunk_wrapped` (origin the hips) and, hung from the trunk, `wig` (the cloth down its back, for the heads
  that have one), `neck` (nothing to see: where a head is put), `arm_wrapped_left` and `arm_wrapped_right` (origin the
  shoulder) and in each fist `knife_left` or `knife_right`.
- `guardian_kilt` is the same figure in a kilt, beside the first: `feet_kilt`, `thighs_kilt`, `shins_kilt`,
  `trunk_kilt`, `arm_kilt_left`, `arm_kilt_right`. What it shares with the first is shown again under names ending
  `_again`, which the game does not read.
- `head_crocodile`, `head_snake`, `head_vulture`, `head_hippopotamus`, `head_ram`, `head_jackal`, `head_hare`,
  `head_lion`, `head_bull`: the heads, each facing forward with the top of the neck at its origin. The jackal's is on
  the first figure and the bull's on the second; the rest stand in a row behind.
- `great_knife` (and `great_knife_again`, crossed over it): a knife that bars a gateway, its origin the foot of the
  gateway's side. It is modelled for a gateway 2.2 by 2.6; for another the game makes all of it bigger or smaller.
- `leaf_open`, `leaf_rolled`: the leaf of papyrus. What is written on it the game draws, and lays on by the model's
  texture coordinates.

The colours are the model's materials, named plainly (`linen`, `linen_band`, `skin`, `seat`, `hilt`, `crocodile_belly`,
`ram_horn`, ...), and the game takes each colour from there. A few names mean something to it (`scripts/guardian_mesh.gd`):
`gold` and `blade` shine; `eye` is lit from within; `stone` is drawn as the game's sandstone in that colour; `hide`
(the neck, and the fists of the wrapped figure) is painted in the colour of the head's own hide, which is the head's
material whose name ends `_hide`; a head with anything painted `wig` gets the wig down its back; `papyrus` is written
on and `tie` is the cord of the rolled leaf. The colours of the drawings on the leaf and the buttons are not the
model's: they are `BookOfTheDead.HIDES`.

A head is 660 to 1,200 triangles and the whole of a guardian 1,800 to 2,300 (it was about 1,500). It is ten things to draw (it was thirty):
one for each part that moves, in one material that every guardian shares, each point carrying its colour, and one more
for the stone of the plinth; the two great knives are one each. Where its hips, knees and ankles are as it sits and
rises stays in `scripts/gate_guardian.gd` (`SEATED`, `RISEN`, `ANKLE`, `THIGH`, `SHIN`), since they are worked out as it
moves. The pictures on the leaf and the buttons are drawn in code (`BookOfTheDead.draw_vignette`, `draw_signs`), as is
the writing on the leaf lying on the ground and the shadow under it, and its voice is made in code,
not recorded. `scripts/guardian_panel.gd` is the leaf to read and the names to choose from: nothing on it is under 88
high to touch, or written under 26. With a gamepad the mark is on the first name as it comes up, the d-pad moves it,
A says the name and B steps back.

How true it is. The gates, their seated keepers with beasts' heads and knives, and the passing of each by saying a name
are spells 144 to 147 of the Book of the Dead; in 144 and 147 there are seven gates, each with a keeper, a watcher and
a herald, and in 145 and 146 the portals of the house of Osiris, each with a doorkeeper. The thirteen names here are
theirs (twelve from the seven gates, "Long-horned bull" from the fourth portal of 146), in English that follows the
usual translations. They were set down from memory, not from a book open on the desk: the wording differs from one
translator to the next, the papyri do not agree on which of the three at a gate bears which name, and a name or two
may be given here to the wrong gate. The Egyptian under each (`says`) is the word as best remembered, and the signs
spell it sound by sound with the signs this game has (with the face, the heart, the voice and "life" as the words they
are): it is Egyptian that can be read, but not the spelling of any papyrus. Which beast's head goes with which name is
this game's choice; the papyri draw the keepers with these heads but do not match them so. The three names to choose
from, and the striking down by the keeper himself, are the game's.

```
godot --headless --path . --fixed-fps 60 --script tools/guardian_test.gd
godot --path . --fixed-fps 60 --resolution 960x960 --script tools/guardian_sheets.gd -- <folder> [heads round far idle strike named dark leaf yard]
godot --path . --fixed-fps 60 --resolution 1560x720 --script tools/guardian_sheets.gd -- <folder> panel book yard
```

The first runs it with nothing drawn and ends PASSED or FAILED: without the leaf no English is shown and with it there
is; the same seed deals the same names; "Step back" does nothing; a wrong name, touched on the screen, catches him and
deals new ones; the right one turns the guardian on, unbars its gateway and opens a door linked to it in the desert; a
leaf takes the nearest keeper's name; and a level started again has forgotten its leaves. The second draws it; the
third takes the names and the leaf as a phone shows them, every keeper as the papyrus draws him, and the notebook's page.

## Temples

`Temple` (`scripts/temple.gd`) is an Egyptian temple made from numbers, as `Pyramid` is a pyramid: a row of parts along
an axis, front to back. He comes to it from +Z and walks in towards -Z; the middle of its length is its origin.

- A **pylon**: two leaning towers with the roll up their corners and the cornice on top, slots for the flagstaffs and
  the windows over them, and between the towers the gateway with the sun's winged disc on its lintel. Cut into the face
  of each tower is the king smiting his enemies before a god.
- **Courts** open to the sky, with a ring of columns round them (or two), beams on the columns, and a roof from the
  beams to the wall where the place has one.
- **Halls of columns** under a roof of slabs. A hall's front is a wall with a doorway, or (as the Ptolemies built)
  half-height **screen walls** between the columns of its first row. Light comes down through the roof on to the
  aisle in sheets, with dust in it; with `nave` the middle aisle stands higher than the rest and the light comes in
  through stone grilles between the two roofs.
- **Rooms** before the sanctuary, and the **sanctuary**: a room inside a room, with a way round it and the doors of
  chapels off that; in it the stand the god's boat rested on, and behind that the **naos**, the shrine of one block of
  granite.
- Round it an **enclosure wall** with a walk between it and the temple; a **nilometer** well; a **lake** (a `Pool` in a
  stone tank). Before it **obelisks**, **colossi** and **falcons**, and markers along the way up to it for sphinxes.

`plan` sets it out as one of three real places, or as your own:

| | True to the place | Simplified |
| --- | --- | --- |
| `EDFU` (Horus; Ptolemaic, 237 to 57 BC) | 137 m long; the pylon 79 m wide and 36 m high with four flagstaff slots; the court with its colonnade on three sides; the outer hall of 18 columns behind screen walls and the inner of 12; two rooms; the sanctuary free-standing in its corridor with Nectanebo's grey granite naos (4.2 m); the enclosure wall and the walk inside it; composite capitals; the granite falcons in the double crown, two at the gate and one before the hall; all of it roofed, and dark | The chapels round the sanctuary are shut doors, not rooms. The stairs to the roof, the roof kiosk, the library and robing room are not there. Every capital is the same composite (the real ones are in pairs, each pair different). The nilometer is a round well, not the stair down from the east walk. The mammisi is not built |
| `LUXOR` (Amun; Amenhotep III and Ramesses II, about 1390 to 1213 BC) | Long and open: Ramesses' pylon 65 m wide and 24 m high, his two seated colossi, one of the standing ones, and the one obelisk (25 m) on the left as he comes to it, with the pedestal of the other, which went to Paris in 1833; his court with a double row of papyrus bud columns; the mosque of Abu el-Haggag standing in it on the undug bank, with steps up; the colonnade of fourteen open-papyrus columns 19 m high between walls; the sun court with double rows of bud columns on three sides; the hall of 32 columns; and the roofed rooms behind. No roofs over the courts and colonnade | The first court is skewed off the axis in the real temple (to keep an older shrine): here it is straight. Thutmose III's three-roomed shrine in the first court is left out. The mosque is a plain white hall, dome and minaret. The rooms behind (the Roman chapel, the birth room, Alexander's boat shrine) are two rooms and a sanctuary. It is 235 m long, not 260 |
| `KOM_OMBO` (Sobek and Horus the Elder; Ptolemaic and Roman) | Two of everything along two axes side by side: two gateways, two aisles through both halls and three rooms, two sanctuaries. Its front has gone into the river: pylon, court walls and the sixteen court columns are stumps, with the altar in the court. The 15 and 10 columns of the halls stand to their full height under half a roof; the sanctuaries are down to low walls with the black stone each boat stood on. It stands on a rise with steps up, with the well and a small pool beside it | Which side is whose is not marked. The two walks round it are one. The reliefs (the surgical instruments, the calendar) are not those. The small pool for the crocodiles is a square tank above the ground |
| `CUSTOM` | Whatever the numbers say: width, the height of the pylon, the court and its rows of columns, how many halls and how many columns across and deep, their height and capitals, a higher middle aisle, two of everything, roofed or not, wall, lake, well, obelisks, kings, falcons, a rise | |

`size` is how big: **1 is the size of the real thing**, and that is how the three are placed. Whatever the size,
doorways stay at least 2.2 m wide and 2.9 m high, steps stay steps, and columns never stand so close that he could be
caught between them. `ruin` (with `seed`) takes it apart: roof slabs go, columns snap and their drums lie about, walls
come down to different heights along their length, lintels fall, blocks lie where they fell (never in the way in),
sand drifts into the corners, and past a half the pylon is down to its lower courses. `buried` fills it with sand
inside and out and banks it up round it: 1 is to the tops of the columns of its great hall, as Edfu was until 1860.
`painted` is how much of the old colour is left on capitals, cornices and carving.

**The parts are models, made in Blender.** `tools/build_temple.py` builds every part as an object of its own in
`tools/temple.blend`, and exports them all to `models/temple/temple.glb`:

```
blender --background --python tools/build_temple.py
godot --headless --path . --import
```

Open `tools/temple.blend` to look at a part or change it by hand, export it over `models/temple/temple.glb` (glTF
binary, +Y up, everything), and the game uses what you made. (Running the script again makes them all afresh and
overwrites what was changed by hand; to keep a change, make it in the script.) The objects:

| Object | What it is | How the game uses it |
| --- | --- | --- |
| `column_bud`, `column_open`, `column_composite`, `column_hathor` | A column with its base and capital: a bundle of papyrus stems with closed buds (Luxor's courts), the open papyrus bell (Luxor's colonnade), the composite of leaves and flowers (Edfu, Kom Ombo), Hathor's head. 10 m high, the shaft 1 m in radius | Stretched to the height and thickness wanted |
| `column_..._far` | The same with fewer faces | Drawn in its place from far off, and casts the near one's shadow |
| `column_broken`, `column_drum` | What is left of a snapped column; one drum of a fallen one | Stretched; the drum laid on its side |
| `architrave`, `roof_slab` | A beam and a slab, 1 m each way | Stretched to the length, height and width wanted |
| `cornice`, `cornice_corner`, `torus` | A metre of cornice, the corner where two lengths meet, a metre of the roll | The cornice stretched along a wall top (the roll is not placed yet: the towers and gateway carry their own) |
| `screen_wall` | One of the half-height walls between the columns of a Ptolemaic front, with its cornice | Stretched from column to column |
| `pylon_tower`, `pylon_tower_left` | The right and left towers of a pylon, as Edfu's: slots, windows, rolls, cornice | Stretched to the width, height and depth wanted |
| `pylon_tower_ruin`, `pylon_tower_ruin_left` | A tower down to its lower courses | The same, as high as what is left |
| `pylon_gateway` | The gate between them: jambs, lintel with the winged disc, cornice | Stretched until its opening is the size wanted |
| `naos`, `barque_stand`, `altar`, `well` | The granite shrine; the stand for the god's boat; an altar; the nilometer | Made the size wanted |
| `obelisk`, `obelisk_pedestal` | An obelisk on its pedestal; the pedestal alone | The same |
| `colossus_seated`, `colossus_standing`, `falcon` | The seated and the standing king; Horus as a falcon in the double crown | The same |
| `mosque`, `minaret` | The whitewashed hall with its dome; its minaret | The same |

The game measures each model and stretches it to fit, so a part may be remodelled at any size; what is solid of it is
worked out from its size too (`TempleParts.SOLID`; for the pylon and gateway from `TempleParts.TOWER`, `TOWER_LEAN`
and `GATE`, which must be changed to match if their shape is). What a face is made of is read from the **name of its
material** (`stone`, `stone_coursed`, `stone_relief`, `stone_shaded`, `redgranite`, `greygranite`, `whitewash`,
`dark`, and `..._painted_red` and the other paints: the top of `tools/build_temple.py` lists them), so a face given
one of those materials in Blender is drawn as that. All the materials of a model are made one mesh and one draw when
it is first used; there are no textures and no UVs to keep.

What is built in code is only what is plain: walls (with doorways, and coming down in ruin), floors, the bank the
mosque stands on, steps, the kerb of the lake, fallen blocks, sand, light, and everything that is solid. All of that
is one mesh. The stone of both is one shader (`scripts/temple_stone.gd`): blocks in courses, and on the acres of wall
nobody comes close to, rows of relief (a line of figures with columns of signs between them, none of it real writing),
all of which fades out before it is small enough to shimmer. Where he does come close the writing is real:
`Inscription`s of the king's titles with his name in its ring (Ptolemy at Edfu and Kom Ombo, Ramesses at Luxor)
beside every doorway on the axis and down the obelisk, the offering formula and the praise of Ra in the sanctuary,
and Horus's name on the naos. The king and the god on the pylon are drawn here in code as the hieroglyphs are (their
outlines are in `TempleStone.SMITING` and `GOD`) and cut into the tower's face as an inscription is.

For whoever makes a level, a temple marks its places with `Marker3D`s in groups: `temple_sanctuary` (before each
naos), `temple_doorways` (the foot of every doorway on the way in, each with `wide`, `tall` and `thick` as metadata:
give a "Door" from the Puzzle page those numbers and it fits, though a door there goes no higher than 12 m and the
gate of Edfu is 15.5), `temple_pylon_top`, `temple_court`, `temple_well`, `temple_lake`, `temple_mosque`, and
`temple_avenue` (pairs of places along the way up to the gate, for sphinxes). `ways` is the way in for each axis and
`open` whether he can get all the way (and `shut_by` why not: sand to within 1.45 m of a lintel shuts a doorway).
The tops of its walls, beams, roofs and cornices are solid and can be run along, and their edges caught, like any
other stone; `GrapplePoint`s are put on the gate's cornice and on beams that have open air under them. There are no
stairs up the pylon: its top is marked, and a ladder or a rope must be put there by whoever wants him up it.

Light: under a roof the stone is drawn darker (it is baked into the mesh; the less roof is left, the less dark), and
the sun's shadows do the rest. The boy himself and whatever else is put inside are lit as they are outside, because
the game's light from the sky is the same everywhere: a level that wants him dark in the sanctuary must do that
itself. The lake's water is a `Pool`, which lies square to the world: if a temple with a lake is turned other than
by quarter turns, the water does not turn with its tank.

What it costs, at full size (`tools/temple_sheets.gd` prints it): Edfu is about 24,000 triangles when he is among
its columns and 11,000 from far off, 235 solid shapes, and builds in about 130 ms the first time (when the models
are read) and 25 ms after; Luxor, with 174 columns, is 57,000 and 22,000, 490 shapes, 60 ms; Kom Ombo 11,000 and
5,000, 210 shapes, 20 ms. A whole temple is about twenty-five draws. With the sun's shadows, a frame in Luxor's first
court draws about 60,000 triangles more than the same frame without the temple, and one in Edfu's about 35,000.

In the level editor they are "Temple: Edfu", "Temple: Luxor", "Temple: Kom Ombo" and "Temple (your own)" on the Stone
page, with sliders for the above; move one and it is built again.

```
godot --path . --resolution 1280x960 --script tools/temple_sheets.gd -- <folder> [banded] [edfu] [luxor] [kom_ombo] [custom] [capitals] [ruin] [buried] [painted] [small]
godot --headless --path . --fixed-fps 60 --script tools/temple_test.gd [-- quick]
```

The first draws each plan from the air, as a plan, from his eye on the way up, the pylon, the court, each hall and
the sanctuary, every model (`capitals`), and ruin and sand at several values. The second builds each with nothing
drawn, walks him from before the gate to each sanctuary, runs and jumps him at its stone from every side to see that
he is never inside it or stuck, and does the same ruined and buried.

## Abu Simbel

The two temples Ramesses II had cut into a sandstone cliff above the Nile in Nubia, at their true size, as they
stood in the 1910s: by the river, where they were cut (the lake and the move uphill are fifty years off), with the
sand of the desert above still coming down the gully between them. `AbuSimbel.new()` is the whole place; in the
level editor it is "Abu Simbel" on the Stone page. The node is on the ground before the door of the Great Temple,
which looks along +Z (the river and the sunrise); north is +X, and the Small Temple is 100 m that way.

- **The Great Temple.** A hill of rock 46 m high with the facade cut back into it: 35 m wide, 30 high to the top of
  its cornice, leaning back like a pylon, with the roll round its edge, the row of baboons along the top greeting the
  sun, and over the door the niche with the falcon-headed Ra-Horakhty. Four seated colossi of the king, 20 m high, in
  the double crown and the striped headcloth with the false beard, hands on their knees; the queen, the king's mother
  and a child at the legs of each, and a princess between each pair. The second from the left broke off at the waist
  in an earthquake a few years after it was made: its body and head lie on the terrace before its feet, face up, with
  the crown beside them. In front, the terrace with its steps, its balustrade, falcons and small figures of the king.
- **Inside**, on one line 60 m into the hill and really walked: the great hall (18 m by 16, 10 high) with eight
  pillars, each the king as Osiris with his arms crossed; a second hall of four square pillars; a vestibule; and the
  sanctuary, with a block for the god's boat and Ptah, Amun-Ra, the king and Ra-Horakhty sitting on a bench against the
  far wall. Four long store-rooms open off the first hall. It is dark, lit from the door, less the further in; a torch
  lights it as it would a tomb. The long walls carry the battle of Kadesh, and the ceilings are a night sky, if
  "painted". The king's names are on the facade, down the door, and on the pillars.
- **The Small Temple**, of Hathor and Nefertari: six standing colossi 10 m high in niches between leaning buttresses,
  the king four times and the queen twice, and she as tall as he is, which is the remarkable thing about it. A hall of
  six pillars with the head of Hathor, a vestibule, and a sanctuary where the cow of Hathor comes out of the rock.
- **The sand** (`drift`): at 0 a heap up in the gully; at a half a fan that has reached the terrace; at 1 it lies
  across the north of the great facade, the northern colossi are in it to the chest, and the door is all but shut:
  he walks up it and goes in on his hands and knees under the lintel, as Belzoni did in 1817. A ramp of blown sand up
  the back of the hill is the way to its top.
- **The sun on its axis** (`sun_on_axis`): on two mornings a year the rising sun shines down the whole length of the
  temple onto three of the four gods; Ptah, a god of the dark, stays in shadow. The light is a `SunBeam`, a metre
  above the floor, and whatever stands in its way stops it: sand in the door, a door a level's maker hangs there, the
  boy. While it reaches the sanctuary the temple is on (`changed`), and works whatever a pressure plate works.
- **Climbing.** The pedestals, the feet, what fell (three blocks, the body, the face) and the balustrade are ledges
  he can catch. The laps are 8 m up and the shoulders 13: a `GrapplePoint` at the knees and one at a shoulder of each
  colossus are the way there. Nothing between a colossus's legs and the wall can be got into: it is all one block.
- **For a level's maker**: `Marker3D`s named GreatDoor, GreatHall, GreatSanctuary, GreatTop and SmallDoor, SmallHall,
  SmallSanctuary, SmallTop, in the groups `abu_simbel_door`, `abu_simbel_hall`, `abu_simbel_sanctuary`,
  `abu_simbel_top`. `rock()` is the one place its rock's material comes from, for another to be put in.

**The models.** The stone is made in Blender, by a script, so that it can be looked at and changed:

```
blender --background --python tools/build_abu_simbel.py              # everything again from the numbers in the script
blender --background tools/abu_simbel.blend --python tools/build_abu_simbel.py -- export
                                                                     # only write the .glb again, after changing the .blend by hand
godot --headless --path . --import
```

`tools/abu_simbel.blend` has every part as an object with a plain name, the parts of each temple lying where they
belong and the figures in rows out in front; `models/abu_simbel/abu_simbel.glb` is the same, for the game, which
finds each part by its name: `colossus`, `colossus_broken`, `colossus_fallen`, `crown_fallen`, `small_figure`,
`baboon`, `falcon`, `ra_horakhty`, `king_standing`, `queen_standing`, `osiride_pillar`, `square_pillar`,
`hathor_pillar`, `god_ptah`, `god_amun`, `god_king`, `god_ra`, `cow`, `great_hill`, `small_hill`, `ridge`,
`great_facade`, `small_facade`, `great_inside`, `small_inside` (the top of the script says what each is, and
how it must lie). A shape may be changed freely in the .blend. What is solid is not in the models: the script
`scripts/abu_simbel.gd` makes it from boxes, from the same measurements as the Blender script (so a part that is
moved or made a different size wants the number changed in both), and takes the skin of the hills from the model as
it is. The colour of each point is read by the stone shader (red: how light; green: laid in courses, or inside, a
wall that carries the battle; blue: rough rock, or inside, a half for a ceiling), and must not go above 1.

**What it costs**, at true size with both temples: about 40,000 triangles outside and 18,000 inside (which are only
drawn while the camera is within about 100 m of a temple's door), before Godot's own coarser versions of each mesh
for distance; 52 draw calls at most, 30 of them writing that is only drawn from near; 265 shapes to collide with.
It is made in about 70 ms (the first one, which loads the models, in about 280). The colossi are one mesh drawn three
times and a broken one; pillars, baboons and the small temple's figures are each one mesh drawn many times.

```
godot --headless --path . --fixed-fps 60 --script tools/abu_simbel_test.gd
godot --path . --resolution 1280x800 --script tools/abu_simbel_sheets.gd -- <folder> [figures] [whole] [inside] [drift]
```

The first walks him in at both doors to both sanctuaries, in over the sand at a half and at 1, up the ramp to the
top, throws him at the colossi, what fell and the pillars from many sides to see that he is never inside stone, and
checks the sun and the switch. The second takes the pictures (add `--rendering-method gl_compatibility` for the
web's renderer), and prints what it costs. There is no station for it in the test yard: it is too big.

How true it is. True: where everything is and how big (the facades, the colossi, the halls and their order, the
number of pillars, who sits in the sanctuary and which of them the sun misses, the six colossi of the small temple
and their order, the broken colossus and where it lies, the baboons, the niche, the sand from the north). Made
simpler: the hill is a rounded mass in level beds, not the real cliff; the figures are plain, with no carving on
thrones or kilts and none of the bound captives along the bases; the great temple has four store-rooms where there
are eight, and the two chapels off the vestibule and the two outside are left out; the floors do not rise nor the
ceilings come down towards the sanctuary as the real ones do; the battle on the walls is rows of soldiers, chariots
and the king, not the scenes as they are; the small temple's pillars and sanctuary are plainer than the real ones;
and the writing is the king's names and the stock formulas, not what is carved there. The two temples are set as
they lie to each other only roughly. Below about three quarters of its size the doors get too low and narrow for him.
The sides of the ramp of sand are steeper the nearer the top (up to 62 degrees), where it is banked against the rock:
lying at 33 degrees all the way up, its top stood out 75 m either side of the hill and its upper end was open there,
so that he could walk in under the sand.

### The temples in the shipped desert

The shipped desert (`levels/desert.json`) is 640 m across. What was in it when it was 400 m across is all there, as
far from the north and west edges as it was: 120 m west and 120 m north of where its numbers used to put it (he starts
at -120, 45). East of it a river runs from north to south, 24 m wide, with palms and reeds on its west bank. Three
temples stand by it at their true size, each on level ground that the dunes keep off:

- **Edfu**, in the south, inland: its middle at 60, 175, its gate looking east down a way lined with jackals to the
  water. From the start it is south-east, 220 m to its back wall and 285 m round the wall to the gate; its pylon
  stands over the dunes from where he starts. A keeper with a lion's head bars the sanctuary; the leaf with its name
  is by the well, behind the temple inside the wall; in the sanctuary is the helmet of Horus.
- **Kom Ombo**, on the bank at 160, 20, looking south, its lake on the river side. East of the start, 280 m. A keeper
  with a crocodile's head bars the left-hand sanctuary; its leaf is by the well, west of the temple; inside is the
  helmet of Sobek.
- **Abu Simbel**, in the north-east: the door of the Great Temple at 188, -100, looking east over the river. East-
  north-east of the start, 340 m; its hill is on the skyline from there. The sun is on its axis, but a slab shuts the
  inner halls. A lever at the end of the first store-room on the left (a torch burns there) raises it; the sun reaches
  the gods, the sun disc at their knees stays lit, and the first store-room on the right opens for good: a khopesh
  is in it.

There is a checkpoint before each and one inside each. Luxor is not there (it wants 300 m by 100, and the open ground
left is the level's dunes): it is still on the editor's Stone page. `tools/desert_temples_test.gd` checks where they
stand and does the three things; `tools/desert_walk.gd` walks to each, in and out; `tools/desert_temples_sheets.gd
-- <folder>` takes the pictures and says what each costs.

## Tombs

`tomb.tscn` is a tomb made from a number: the **daily tomb**, the same for everyone on the same day, or one for practice
from any number and at any of three difficulties. He goes in, takes the gold falcon from the burial chamber, and comes out
again; the clock runs from his first step until he is out of the door with it. It is not in the menu's list of levels yet:
add `["Tombs", "res://tomb.tscn"],` to `LEVELS` in `scripts/menu.gd`. Opened like that, or by itself
(`godot res://tomb.tscn`), it is today's tomb, and a card comes up first that offers a random one instead. To open it on a
tomb of your choosing, set `TombLevel.play` first (`{"mode": "daily"}` or `{"mode": "random", "seed": 12, "difficulty": 1}`),
or pass `-- tomb=daily` or `-- tomb=12:1` on the command line. Either takes how it is to be seen as well: `"view": "side"`
(what it is with nothing said) or `"view": "3d"`, and `view=3d` on the command line (`-- tomb=12:1 view=3d`). The card
has the two as "Side-on" and "Walk through", and remembers the last one chosen until the game is closed. A third
button, "Branching", is another kind of tomb altogether (`"shape": "branching"`, `shape=branching`): rooms on a floor
plan with ways off to either side, side chambers, dead ends and loops, and a map. "Tombs that branch", below, has it.

- **Seen from the side**, the tomb is cut open towards the camera like the section drawings of the tombs in the
  Valley of the Kings: its axis runs away to the right and down, he keeps to one line (`SIDE_SCROLL`), and nothing needs
  steering but him. Rooms off the axis are above (a loft: jump at its lip and he takes hold; walk, and he goes under it)
  and below (the chamber at the foot of the well). This is `TombLayout`.
- **Walked through**, the same plan is rooms with four walls and a roof on a floor plan that turns corners, and the
  camera is the one that follows him about the desert, at his back (drag the right of the screen to look about). This
  is `TombLayout3D`; "Tombs walked through", below, has how it is set out. Everything else in this list is true of
  both: the same plans with the same fingerprints, the same locks and keys, the same proof. Only the stone differs, and
  so does what it is to get through: a day's tomb finished the one way is not mixed with the other.
- **The plan** (`TombPlan`, made by `TombGenerator`) knows nothing of either view: rooms, the ways between them, what can be
  carried, and what opens each door. The rooms are a royal tomb's in their order (entrance, corridors, a well, pillared
  halls, a high gallery, antechamber, burial chamber). Locks are put in each with its key somewhere before it:

  | The lock | What opens it |
  | --- | --- |
  | A plate | The block in the room, pushed onto it |
  | A plate | A block that has to be pushed in from the room before |
  | Two plates on one door | The block in the room on one, and on the other a block pushed in from the room before: both |
  | A plate and an offering table | The block, and a canopic jar (found earlier) set on the table: both |
  | A seal stone | Trodden on: it is up in a loft, or at the foot of the well |
  | A door that opens only from behind | Over the wall by the loft, and down a drop that cannot be climbed back |
  | A cold brazier, in a room with no torches | A burning torch (found earlier) brought to it |
  | A pit too wide to jump | The grappling hook (found earlier), thrown at the ring over it |
  | A face too high to catch, the next room at the top of it | A seal stone (at its foot, or in a loft or under a well) lets sand pour in from the roof; he walks up the heap |
  | A gate guardian, his knives crossed in the gateway | His name, which is on a leaf of the Book of the Dead lying somewhere before: in the open in an earlier room, in a loft, at the foot of the well |
  | A sphinx lying at the end of the room | The thing its riddle asks for, found earlier and put down before its paws: a canopic jar, a burning torch, or (in a hard tomb) the grappling hook. It keeps it |
  | No door, but Medjed looking back down the way beyond | What would have opened a door there: the block in the room pushed onto its plate, or a seal stone in a loft or under a well (in a tomb that branches, also a block or a seal stone in a side chamber). It shuts his eyes for good |

  Between rooms: stairs down, a passage to duck through, water to swim (which makes him let go of what he carries), a
  shaft with a ladder, a shaft with a rope. A door, once open, stays open. He carries one thing at a time, and not up
  a ledge, a ladder or a rope.
- **The rope** (`TombPlan.Pass.ROPE`) hangs from a beam under the roof of its shaft, 0.8 m out from the lip, to half a
  metre short of the floor below. Going down he runs off the lip into it, which is taking hold, and lets himself down
  with the stick (or duck, faster). Coming back he jumps into it, climbs with the stick, and at the top, where his feet
  are over the lip, leaps off towards the floor with jump. The Player takes a rope only with both hands free, so
  nothing goes up it; but with his hands full he can still step off the lip and drop, so the plan lets a thing be
  carried down (and the solver then knows it cannot come back: there is never a rope beyond a pit, which the hook has to
  recross). An inscription at its head says what it is.
- **The sand** (`TombPlan.Pass.SAND`) is the one way that goes up: the next room is 3.2 m higher, over a face he cannot
  catch (the highest edge he can reach is 2.75 m), and the room at its foot is tall. What "opens" it is whatever its
  switches are, as for a door: when they are done a `SandFall` in the roof pours a `SandPile` against the face, which
  gets higher at an even pace and is full in eight seconds, its top half a metre under the lip: he walks up it and hops
  onto the floor, with whatever he carries (hands free, he can catch the lip from it sooner). It never empties: dying
  does not undo it. The far half of the heap is in the rock under the next room, where nothing is cut down as far as it
  reaches, and the tomb is cut open further towards the camera round it, since the heap is wider than the tomb. There
  is no loft over the room at its foot and no mummy in the room at its top, and one such way to a tomb at most.
- **The gate guardians** (`GateGuardian`, see "The gate guardians") keep a doorway each, which is the guardian's own
  gate (`bars_way`): there is no slab. Seen from the side he sits against the far wall beside the way, in profile as
  the papyrus draws him, facing whoever comes, with his two great knives crossed on the boy's line; walked through,
  the gateway is the left 2.2 m of the passage and he sits against the wall to the right of it. Each guardian of a
  tomb has a different name and so a different head, dealt by `TombRandom` (`TombLayout.keepers`), and the names he
  offers come from the tomb's number. The leaf (`BookPage`) is taken by walking onto it, takes no hand, and is his
  until he leaves the tomb; in a tomb that is walked through it lies two metres to the right of his line, so that he
  goes to it. Stepping onto the threshold is being asked. With the leaf the right name has its English under it.
  Without it he may guess, one chance in three: a wrong name is a death like any other, which puts him back at the
  last door, the guardian's own, and the names are dealt again. The solver never counts on a guess, and it also
  visits every position a lucky guess could bring about and asks that the tomb can still be finished from each
  (`TombSolver`: "a lucky guess that can strand him" is one of the plans `tools/tomb_test.gd` holds it to). A
  guardian named stays named: dying does not bring his knives down again. No loft is over the room he sits in, and
  no block is pushed through his gateway. **The clock stands still while a leaf is read or a name is chosen**: the
  game is stopped then (mummies and all), and the time counts ticks of play, so reading costs nobody anything, and
  a slow reader is not a slow time. The inscription over his way says that the keeper wants his name, and where the
  leaf is to be looked for.
- **The sphinx** (`Sphinx`, see "The sphinx") is a small one, 2.5 m long (3.2 in a wide room that is walked through),
  that lies at the end of a room and keeps the door on from it. Seen from the side it is cut from the far wall and
  lies out of it towards the camera, face on, its paws just short of his line; walked through, it lies across the
  room from the right, facing his line. As he comes before its paws its eyes open and its riddle comes up, on a line
  of its own under the tomb's captions. What he puts down there the tomb hands to it (`Sphinx.offer`). The right
  thing it keeps, and its door is open for good; the solver knows the thing is used up, so a torch or a hook that a
  brazier or a pit also wants is a second one (the generators give the sphinx its own, and a plan in which the only
  one could be given away is thrown out by the proof). A wrong thing its paw puts back on the floor of the room,
  2.2 m short of where he stood, which seen from the side is on his line (`Sphinx.sweep_to`), to be picked up
  again. It is never `wrathful`, and dying does not undo it. Nothing in a tomb puts a torch out, so a torch brought
  to it is burning. No loft is over its room, and no block is pushed through its door.
- **Medjed** (`Medjed`, see "Medjed") keeps a way with no door in it. Beyond the doorway is a plain stretch 7 m long,
  and he stands half a metre from the far end of it and looks back down it to the doorway (`sweep` 0: he does not
  turn): on the boy's line in a tomb seen from the side, in the middle of the passage in one that is walked through,
  where his look is 90 degrees wide and so as wide as the passage. The boy walks through him, so he is no door
  himself; his look is. It reaches 6.8 m, into the doorway and no further, so the bay and the place to start again
  from are out of it, and anyone can stand at the jamb and see the fan on the floor. Whoever goes on is struck dead
  0.6 s after he is seen, which at a sprint is three and a half metres short of Medjed; and whoever has come round
  behind him (which no tomb the generators make allows) is struck two metres or more short of the doorway.
  `tools/tomb_test.gd -- custom` runs at him flat out down both sides and the middle, and from behind. It is the
  same in all three kinds of tomb: a look that sweeps, with pillars to hide behind, was not tried. To the solver the
  way is a door, and what would have opened the door shuts his eyes (`Medjed.worked`), for good. Dying under his eyes
  is a death like any other, and puts Medjed back at his post as he was (`reset`). No block is pushed down his way.
- **The Ba** (`Ba`, see "The Ba") is the spirit of whoever lies in the tomb, and it is the hint. It locks nothing.
  It sits by the falcon while he is near enough to the burial chamber for that to be drawn, and is not there
  otherwise. "Stuck" does what it did (back at the last door with what he carried, and a death counted), and then
  the Ba comes out of the air beside him, flies to the next thing to do, lands, looks back and returns, with the
  step in words under the clock: the thing to pick up, the block and its plate, the leaf, the guardian, the door to
  go through next. It comes unasked as well when nothing has come of what he does for 45 seconds of play (no room
  he had not stood in, no switch done, nothing taken up or put down), and then not again for half a minute. What it
  shows is the first step of the solver's shortest way to the end from where everything really is at that moment
  (`TombGuide`, `TombSolver.way_from`): which room he is in, what he holds, where each thing lies, which switches
  are done. So it cannot lead him wrong, and where the solver has no way from there (which the proof says cannot
  be) it shows nothing. The way it flies is a place at each corner of his lines and each doorway; where it can find
  no way to fly (a crawl, a shut door) it goes as a spirit does. Once he has the falcon it flies ahead of him all
  the way out, waiting where he can see it, and goes when he is out. It is not a body, opens nothing, and costs no
  time; it is in neither the plan nor the stone, so it is in neither fingerprint. `tools/tomb_test.gd -- ba` (and
  `3d ba`, `branching ba`) asks for the way at every step of tombs as they are played, sends the Ba, presses
  "Stuck", and plays on from the door by the Ba's own way.
- **Apophis** (`Apophis`, see "Apophis") is in no tomb the generators make. The tomb editor can put him in a burial
  chamber by hand ("Apophis", with the other switches of that room; `"apophis": true` in a `TombSpec`): he lies down
  a hole beyond the falcon, comes out when it is taken, and follows the boy out by the boy's own trail. Dying at his
  mouth is a death like any other: the boy is back at the last door with the falcon, the snake is back in his hole
  (he goes there of himself whenever the boy starts again), and he comes out again at once, so a death shakes him
  off only as far as that door is from the burial chamber, and costs a death. Why he is not in generated tombs: he
  goes at 3.6 to 4 m/s against the boy's 4.4, and starts three metres behind him, so a clean run just keeps ahead,
  and nothing else does. A crawl (1.3 m/s for the boy; the snake goes through at full speed), water, a ladder or a
  rope up, the hook to be thrown again over its pit and a mummy's trench to climb out of each cost the boy more
  seconds than he has, and what would give them back (a head start worked out for each tomb from its way out, lit
  braziers placed for it) would have to be proved for every tomb in three views by something that knows how long
  each of those takes him, which `TombSolver` does not. A tomb is proved finishable; with him in it, it would only
  be hoped. So he is by hand, and the editor says of him that nothing proves he can be outrun. `tools/tomb_test.gd
  -- custom` has a tomb of stairs and a doorway with him in it, which the automated player gets out of ahead of
  him, seen from the side and walked through; and it lets him catch the boy, to see both put back.
- **Khepri and the sun** are in no tomb. Seen from the side a tomb has no floor of squares, only a line; and in
  the tombs that are walked through the blocks keep to a lane, which a sun steered about a hall would not. It was
  not forced.
- **How much of this a tomb has.** An easy tomb has at most one of the creatures that keep a way, and that a gate
  guardian whose leaf lies in the open in a room before (a third of easy tombs have one). A middling tomb has up to
  two, of a guardian (leaf in the open, in a loft or under a well), a sphinx (a jar or a torch) and Medjed; a hard
  one up to three, and its sphinx may want the hook (`TombGenerator.KEEPERS`). No two of them keep doors of rooms
  next to one another, so that one or two are on the screen at a time. Every tomb has the Ba. `tools/tomb_test.gd
  -- sweep` counts them over the seeds of each shape and difficulty, and asks the solver of every one afresh:

  | 300 seeds each | a guardian | a sphinx | Medjed | none | two or more | proved | tries thrown away |
  | --- | --- | --- | --- | --- | --- | --- | --- |
  | Down an axis, easy | 90 | 0 | 0 | 210 | 0 | 300 | 0 |
  | Down an axis, middling | 87 | 109 | 84 | 75 | 77 | 300 | 0 |
  | Down an axis, hard | 130 | 110 | 92 | 50 | 124 | 300 | 0 |
  | Branching, easy | 57 | 0 | 0 | 243 | 0 | 300 | 0 |
  | Branching, middling | 76 | 77 | 98 | 77 | 36 | 300 | 1 |
  | Branching, hard | 106 | 86 | 113 | 50 | 93 | 300 | 18 |
- **Mummies** are of a kind chosen with something in the room that kind cannot get past, between it and whatever he has
  to stand still at: a trench for the shambler, the child and the royal one, a kerb for the priest and the crawler, two
  piers too close together for the brute. Each wakes as he passes, loses him after a few seconds of not being able to get
  at him, and stands where it is until he comes by again. The burial chamber's wakes when the falcon is taken.
- **That it can be finished** is proved for every tomb before it is used (`TombSolver`): the plan is played as a board game
  through every position that can be reached, and it passes only if the falcon can be brought out, every room can be
  stood in, and there is no position at all from which it can no longer be finished. A plan that fails is thrown away and
  the next sub-seed tried; after forty, a tomb of plain stairs. `TombReach` then holds every jump, ledge, kerb, crawl and
  swing in the built tomb against what the Player can do, read from `player.tscn`.
- **The same everywhere**: all the dice are `TombRandom` (whole numbers only, nothing from the engine or the clock), seeded
  from the generator's `VERSION`, the seed, the difficulty and the sub-seed. A plan and its stone each have a fingerprint.
  `VERSION` is 3 since the creatures of the funerary texts went in (it was 2 from the two-plate door, the rope and
  the sand): the same number now makes a different tomb than it did (and so does a day). `TombBranching.VERSION`
  went from 1 to 2 with it, for the same reason.
- **The daily tomb** (`TombDaily`): the seed is made from the number of days since 1 January 1970 by the clock at
  Greenwich; tomb #1 was 1 October 2026; the day of the week sets the difficulty. The time counts sixtieths of a second
  of play, not of the wall clock. Dying puts him back at the last door he went through (each end of each room), with
  what he carried back where he last had it at a door, and is counted; "Stuck" does the same when he asks. The best and
  first time for each day and the run of days in a row are kept in `user://tombs.json` (on the web, the browser's
  storage): a day's times seen from the side under `days`, and walked through under `days_3d`, apart (and a practice
  tomb's best likewise); the run of days is one, and a day counts once whichever way its tomb was finished. At the end
  the result can be copied as a line, `Outside daily tomb #9  1:22.8  1 death`, or
  `Outside daily tomb #9, walked through  3:05.0  no deaths`.
- **A leaderboard** is not there, but the finished run is the record one would be sent (`TombDaily.submission`: day, seed,
  difficulty, generator version, the two fingerprints, ticks, the time to the falcon, deaths, when each room was first
  reached). As it stands nothing in it can be trusted: the game runs on the player's machine. To make times worth
  ranking, a server would have to hand out the day's seed itself (so nobody plays tomorrow's tomb early), make the tomb
  itself and check the fingerprints, and be sent the stick and buttons of every tick to play back; and that playback only
  proves anything if the physics come out the same on its machine as on a phone, which Godot's do not promise, so in
  practice it would check what it can (the time against the solver's shortest way at his top speed, the room times in
  order and no faster than he can run between them) and keep a human eye on the top of the table.
- **What others are making** goes in through `TombHooks`, which looks for each by its file and otherwise leaves a
  `Marker3D` in the group `tomb_hooks`: scarab nests in dark rooms, cobwebs across crawls and lofts, a jackal mummy at
  the burial chamber, an inscription over every locked door (until there are real ones, a panel of plain signs, and the
  hint comes up as a caption when he stands under it), and the notebook, which is given each hint as it is read.
- **Tombs made by hand**: `tomb_editor.tscn` (`TombEditor`) is an editor for tombs, for a phone. It is reached from the
  card that comes up at a tomb ("Make a tomb of your own") or from the notebook's Places page while in one. The tomb
  stands on the screen as the game builds it, seen from the side; one finger drags it about, two pinch. The rooms run
  along the bottom in their order: touch one to choose it, "+ Room" to put one after it. The panel at the right changes
  the chosen room: what it is (corridor, well, pillared hall, high gallery, antechamber), dark or lit, a pit, a mummy and
  what holds it back, the torches, hooks and jars that lie in it, the way on (doorway, stairs, crawl, water, ladder,
  rope, a pit to swing over, up the sand) and what locks the door on (the generator's rules, by name; where the way on
  is up the sand, that is what lets the sand in, and with none it is a seal stone at the foot of the face). Whatever a lock needs that is
  nowhere before it is left in the room before, and said. The creatures are among the locks, by name: a gate guardian
  (with the room his leaf lies in, or the room whose loft or well it is in), a sphinx that wants a jar, a torch or the
  hook (the thing is left in the room before if there is none earlier), and Medjed with what shuts his eyes (a block
  on its plate, a seal stone in a loft or under a well; on a floor plan, also a seal stone in any room). The burial
  chamber has a switch for Apophis. "Way through" says their steps in words ("Walk onto the leaf of the Book of the
  Dead, and read the keeper's name", "Put the jar down before the sphinx: it keeps it", "Go to 4 Corridor, through
  the doorway, past Medjed, whose eyes are shut"). `TombSpec.problems` refuses a loft over the room of a guardian or
  a sphinx, a block pushed along a way one of them keeps, any of them on the way up the sand, and Apophis anywhere
  but the burial chamber. Tombs kept before there were any of these open as they were. After every change the solver is run again and what it found
  is said under the buttons; "Way through" lists one way, step by step, or what is wrong. Every change is kept on the
  device (`user://my_tombs.json`), under the tomb's name; "Tombs" has the others, a new one, one of the generator's
  from a number to change by hand, and the tomb as text to copy out or paste in. "Play" plays it (`TombLevel.play =
  {"mode": "custom", "spec": ...}`, or `-- tomb=custom` for the one last worked on), timed like any other and kept
  nowhere; "Edit" there comes back. "Walk it" plays it walked through (`"view": "3d"`, or `-- tomb=custom view=3d`);
  the editor itself shows it only from the side. A tomb that branches is made on a floor plan instead, seen from
  overhead: see "Tombs that branch", below.
  What it makes is a `TombSpec`: the rooms in order, as plain data. It can say only what the generator's own rules can
  make, because those are what `TombLayout` knows how to set in stone: `TombSpec.problems` lists whatever is outside
  them (a locked crawl, a seal stone under a room that is no well, a loft at the foot of the sand, a mummy at the top of
  it), and nothing with a problem is built or played. A
  tomb that can be built but not finished, or in which he could get himself stuck, can still be played: it is said, not
  forbidden.
- **With a gamepad**, on a desk, the editor is worked from its sticks and buttons (`TombEditorPad`,
  `scripts/tomb_editor_pad.gd`: see Gamepad, near the top), and so are the card a tomb opens with, the one it ends
  with, and its Stuck, Edit and map (Back puts the mark on those).
- **The tomb editor on a phone** (`TombPhoneUI`, `scripts/tomb_phone_ui.gd`) is the same editor with other things to
  touch, for a phone held on its side and worked with two thumbs. It is what `tomb_editor.tscn` opens as wherever the
  touch controls are shown (a phone or a tablet, or once a finger has been on the screen: `TombEditor.wants_phone`), and anywhere with `-- phone`
  on the command line (`-- desk` for the other, which is what is described above and is as it was). Nothing in it is
  smaller than 88 by 88 of the 720 the screen is high (about 8 mm on a 6 inch phone) or nearer than 12 to the next
  thing, no words are smaller than 26, and nothing stands within 48 of the left and right edges or 24 of the bottom.
  - *The tomb has the screen.* Down the left edge is one bar for the whole tomb: Play, Undo, Redo, Rooms, Tombs, More.
    Down the right edge are the buttons of the chosen room: Edit and Add, then Copy, Earlier, Later and Remove (a tomb
    down one axis) or Move, Join and Remove (a floor plan). Along the top one strip says what is chosen and what a
    touch will do, and under that whether the tomb can be finished, or the first thing wrong with it; a touch on the
    strip opens the whole list, and a touch on anything in the list goes to the room it is about. At the bottom are
    further off, all of it, and nearer, which do what a pinch does.
  - *Everything else is a page* over the tomb, one at a time, with Done (or Back, on a page opened from another) at
    its top right every time, and dragged up and down with a finger. Rooms lists the rooms, each with what is in it.
    Tombs has the name (the keyboard comes up for that, and for pasted text, and for nothing else; the field is at
    the top of the screen, over it), a new tomb of either shape, the generator's (a number to step or draw afresh,
    then how hard and which shape), a copy of this one, the tomb as text, and the others kept: open, copy, forget
    (which asks). More has Walk it, the way through, other sizes for the rooms, help, and Leave.
  - *A room's page* is opened by Edit, or by a second touch on the chosen room. It leaves a strip of the tomb showing
    at the left with that room in it, and its two arrows go to the room before and the room after, so a tomb can be
    gone through without closing it. What a room is, its mummy, what holds the mummy back, the way and the lock (and
    the room a lock or its stone is in) are each a row that says what it is now; a touch opens a page of rows to
    choose from, each with what it is called and a line about it. Dark and the pit are switches as wide as the page;
    torches, hooks and jars are a minus, the number and a plus.
  - *On a floor plan* the marks are as big as a thumb however far off the plan is seen from: those round a room are
    moved apart until there is a gap between them, and where two or more places a room could be moved to would stand
    on one another, one mark stands for them ("3 here") and a touch on it lists them. Move and Join bring their marks
    into the part of the screen between the bars, and each has List (the same as rows: "North of 3 Antechamber") and
    Cancel; Add, where there is more than one free side, asks which. A touch just beside a room too small to hit is
    taken for it. Remove says the room can be brought back, and Undo is always in the bar.
  - It is a layout and nothing else: what is kept (`user://my_tombs.json`) is what it was, and a tomb made in one
    opens in the other. `tools/tomb_phone_shots.gd` takes a picture of every state of both views and measures each;
    `tools/tomb_editor_test.gd` makes a tomb of each shape with fingers alone and measures as it goes. Neither has been
    held in a hand: the on-screen keyboard, the browser's clipboard and how the edges of a real phone fall are not
    things they can see.
- **Where hand-made tombs are kept** can be set, for the tools: `TombSpec.path` (as `TombDaily.path`), or
  `-- tombs_file=<file>` on the command line. The tools that open the editor all keep to a file of their own.

### Tombs walked through

`TombLayout3D` (`scripts/tomb_layout_3d.gd`) sets a plan out a second way, and `TombBuilder` and `TombLevel` take
either: it is a `TombLayout`, and answers the same questions (which room he is in, whether he is out, whether a thing is
lost, whether a mummy can still get at him).

- **Cells.** Every room that is not a loft or a crypt stands on a square of a floor plan: `TombPlan.Room.cell`, a
  `Vector3i` whose x and z are the square and whose y is the level, counted downwards from the entrance at 0 (a level
  is 1.6 m). A plan whose rooms all have cells is set out as it says. One with none, which is every plan `TombGenerator`
  makes, has them worked out by the layout: down the axis from the entrance, each room ahead of the last or
  round a corner from it as the dice say, never onto a square that is taken. The plan itself is not touched, so its
  fingerprint is the one it has seen from the side. The squares are as big as what stands on them: each column and
  each row of the plan is as wide as its widest room, and a way is made up with plain passage where its rooms are
  further apart than it needs.
- **The rules a plan with cells must keep** (`TombLayout3D.cells_wrong(plan)` lists whatever it does not; a plan that
  breaks them has its cells worked out afresh, and the layout says so in `wrong`):
  - no two rooms on the same square, whatever their levels (a loft and a crypt are part of the room they are off, and
    need no cell);
  - a way joins squares that share a side, and is written going in (`a` nearer the entrance). The first way that ends
    at a room is its way in; the room is laid along it; every other way it has leaves from the bay at its far end,
    ahead, left or right, never beside its way in. So a room has up to three ways on, and a way that closes a loop
    arrives at a bay;
  - how many levels down from `a` to `b`: a doorway, a crawl, water and the pit 0; stairs 1 or more (a flight of eight
    steps each); a ladder shaft and a rope shaft 3; the sand -2 (up);
  - a climb is from a room to its own loft and a shaft to a crypt from a well to its own crypt; a drop is from a loft
    into a room next to the loft's own, which that room must also have a way to, at least two levels down (stairs of
    two flights): the loft goes on over that way as a cutting;
  - a block for the plate of another room stands in the bay in line with the way to that room, which is level: one
    such block to a room.

  `tools/tomb_shapes.gd` has a plan with a side chamber and a loop written out by hand (`branching`);
  `tools/tomb_test.gd -- 3d grid` checks the rules on it, breaks it four ways, builds it and plays it.
- **A room** is laid along the way he comes in, as a run of floors from wall to wall, exactly as the tomb seen from the
  side is a run of spans: so a trench, a kerb or a pit cannot be walked round. A corridor is 5 m wide, a gallery 6, an
  antechamber 7, a hall and the burial chamber 9, with pillars down both sides; the entrance is a court cut into the
  rock, open to the sky. The line he is expected to walk is a metre left of the middle, which leaves the middle for a
  block pushed through from the room before and the right for the room's own block and plate, its offering table, its
  brazier and what lies about to be picked up. A block keeps to its lane, whichever way that runs.
- **A way** between rooms is a passage 3.6 m wide with the whole of what it is in it: a doorway and its door, stairs,
  a crawl 1.4 m wide, water from wall to wall, the head of a ladder or a rope, the sand. A loft is over the bay, so a
  doorway under it is a low one; where a loft drops him into the next room it runs on over the door and the stairs.
- **Walls give him something to kick off**, which the tomb seen from the side has none of beside its ways. A kick off
  a wall takes his feet a metre higher than a jump, so in a corner he can catch a lip 3.7 m up. So the chamber the
  sand comes into is 3.5 m wider on each side than the way on over its face, and the face goes on up to the roof
  beside that way; the pit the hook crosses is wider than the passage to it, its side walls too far apart to go from
  one to the other; and the drop from a loft is two flights (5.1 m), not one. `TombReach` holds all three against the
  Player's numbers, and `tools/tomb_test.gd -- 3d custom` throws him at the face and its corners for fifty seconds.
- **The stone** is cut round all the air at once (`TombLayout3D._shell`): the air is laid on a grid of its own edges,
  and a floor, a roof or a wall is drawn for each square of the grid that touches air, each in one piece from top to
  bottom, then joined to its neighbours. Nothing overlaps, and no face he can jump at has a seam across it for his
  hands to find. `TombBuilder` makes the stone of each room one mesh for each thing it is made of (a handful of draws
  a room, where the boxes would be thirty or forty), and the rooms within two ways of his are drawn. A room has at most
  three torches along its walls (one more in a loft or a crypt, and one or two in a long way out of it), none of which
  casts a shadow. Measured with `tools/tomb3d_sheets.gd -- <folder> cost` on four tombs in the web's renderer, a frame
  walked through took 72 to 81 draws on average and 146 at most, against 53 to 65 and 85 seen from the side.
- **The camera** (`FollowCamera` with `indoors`) is the desert's, 5 m back. Where the view it is asked for is shut off
  by a roof or a wall it comes down flatter behind him before it comes in closer; where the roof is on his back (a
  crawl) it watches him lower; and it asks how far it can stand back five times over, at the middle of what it sees
  and towards each corner, so that no edge of the picture is in stone. Pillars it looks straight past. The faint
  light that keeps him from being a shadow comes from wherever the camera is.

### Tombs that branch

A third kind of tomb: rooms on a floor plan, with ways off to either side, side chambers that hold what a door
further on wants, dead ends, and loops. `TombBranching` (`scripts/tomb_branching.gd`) makes the plan, with a
`cell` for every room, and from there it is a tomb like any other: proved by `TombSolver`, set out by
`TombLayout3D` (it is only ever walked through), built by `TombBuilder`, run by `TombLevel`. It is opened with
`"shape": "branching"` in `TombLevel.play` (`{"mode": "random", "seed": 12, "difficulty": 1, "shape": "branching"}`;
the view is "3d" whatever is asked), with `-- tomb=12:1 shape=branching` on the command line, or with "Branching"
on the card, beside "Side-on" and "Walk through". The other two kinds are what they were: the same plans and the
same stone from the same numbers (`TombBranching.VERSION` is its own: 2, since the creatures went in).

- **How one is made**, each stage only adding what the ones before allow:
  1. *The trunk*: the way from the entrance to the burial chamber, four to seven rooms as the difficulty asks, on
     squares of the plan, turning as the dice say.
  2. *Locks*, each on a way that is the only way to whatever is beyond it, and each put in with its key in one
     move. Most keys go off the way he is on: in a side chamber made for it off the room the door is in or one of
     the two or three before (so that he goes and fetches it), in a loft, at the foot of a well. The rules are
     `TombGenerator`'s (a block and plate, a plate for a block from the room before, the two plates, a brazier, the
     offering table, a seal stone in a loft or under a well, the pit and its hook, the sand, the way over the
     wall), and four more in which what opens the door is down another way: a block and plate in a side chamber,
     a seal stone just inside one, a brazier in a dark one, and a seal stone in one that lets the sand in. A gate
     guardian's leaf lies in the open in a room before, or in a side chamber, a loft or under a well. A side
     chamber that holds something can be locked in its turn. One torch or one hook does for every place it can
     be carried to.
  3. *Dead ends*: rooms off the others with nothing in them, until there are as many rooms off the trunk as the
     difficulty asks (one or two, three or four, four to six).
  4. *The ways themselves* (stairs, a crawl, water, a ladder, a rope), and from them the level of each room.
  5. *Loops*: where two rooms that are not joined stand on squares side by side, a second way between them. Where
     the way round has a lock on it, it is a door that opens only from the far side, by a seal stone just inside
     the room there (a short cut back, which gets him past no lock he has not opened); where it has none, as often
     a plain way (a doorway, a crawl, water, stairs), and then one of the doorways on the old way round may be put
     under water, since there is now a dry way for whatever has to be carried. The loft and its drop over a wall
     are a loop as well, as in the other tombs.
  6. *Mummies* (in a middling or a hard tomb the empty dead ends first) and pits.
- **What keeps it from tying itself in a knot** is asked before each lock goes in, so that few plans have to be
  thrown away: whether every room could still be got to with the locks and keys as they would then be
  (`_reaches_all`: a lock's key is never behind that lock, or behind another whose key is behind it), and whether
  everything that is carried could still be brought to where it is wanted from every room it could be left in
  (`_carry_sound`: nothing wanted at the top can be taken down a rope or a drop). Then `TombSolver` plays it
  through as it does any tomb, and only what passes is handed back. With the creatures in, over seeds 1 to 300 at each difficulty, 300,
  299 and 282 passed at the first try (every one of the others was too tangled to prove in the positions allowed),
  none fell back to the plain tomb, and the worst seed took two tries. Of the tombs down an axis, all of 500 at each
  difficulty passed at the first try.
- **The solver** was already a search over a graph, not along a line, and needed nothing changed to prove these:
  `tools/tomb_test.gd -- branching plans` holds it to seven plans made by hand whose answers are known (a seal
  stone down the other way; a torch beyond water, with and without a crawl round it; a drop and a door opened
  from below; a torch that can be taken down a drop; a hook that can be dropped down a rope beyond its pit, and
  the same with a ladder), and against a thorough way of its own (`solve(plan, true)`: a thing may be put down in
  any room, not only where it could matter), which has to give the same answer. It was given a limit to pass in
  (`TombBranching.MOST_POSITIONS`, 30000): a plan that takes more positions than that to prove is thrown away as
  too tangled, since it is proved on a phone as the tomb is opened. On the machine these were measured on (a desktop, with other tests running beside), a hard
  tomb took 19 ms to prove on average and 281 ms at worst (29370 positions), and 33 ms and 339 ms to make with
  whatever tries were thrown away; a middling one 4 ms and 278 ms to prove (28502 positions); an easy one a tenth of a
  millisecond, 65 positions at most. (With nothing else running the worst were about 180 ms.)
- **What the layout had to learn.** Nothing for most of it: a plan with cells was already set out as it said.
  Two things came of rooms standing to every side of one another, and both are only done for a plan that came
  with its cells, so that the stone of every other tomb is what it was. Where a low room meets higher air (the
  foot of a loft's drop), the stone over the low room is a wall to that air, one square of the grid thick, and
  the edge of a room off to one side can cut that square to a hand's breadth: he could reach over it to the low
  roof behind. There a roof now stands as high as any air within a wall's thickness of it (`_highest_near`). And
  a way that leaves a bay to the side is narrower than the bay is long, which leaves a strip of floor a hand wide
  at the end of the bay; a block pushed straight on out of the bay catches on it. So the generator has no block
  pushed straight on out of a room that has a way off to the side (and keeps side ways off such a room after),
  and `TombFloorSpec.problems` says so of a tomb made by hand.
- **A shut door** used to be something his hands could find the top of: looking down for a ledge from inside the
  wall over the door, the wall is not seen and the top of the slab is, and he pulled himself up into the stone
  and came out on the roof. It was so in every tomb that is walked through, but nothing sent him at a shut door
  from behind until a door that opens only from within. A door there is now as high to run into as the wall over
  it while it is shut (`TombParts.Door.guard`); `tools/tomb_test.gd -- 3d doors` and `-- branching doors` jump at
  every shut door from both sides. (A door under a loft's cutting is left as it was: the floor over that one is
  somewhere he may be.)
- **The map** (`TombMap`, `scripts/tomb_map.gd`) is on the HUD of any tomb whose plan came with cells, in the
  corner under the buttons: a square for each room he has stood in, on the plan's own grid, darker the deeper;
  the ways between them, with a knob on the end of one he has not taken; a red bar across a way whose door is
  still shut or whose sand has not come in, once he has been in a room at either end of it; a mark for a loft or
  a crypt, hollow until he has been in it; the way out, and the falcon; and a red mark for him that points the
  way the camera looks. A touch makes it large, and another small. Only what he has found is on it.
- **The daily tomb** has one that branches as well, from the same seed and at the same difficulty, the same for
  everyone on the day. What is kept of it is kept apart, under `days_branching` in `user://tombs.json` (and a
  practice tomb's best under `seed:difficulty:branching`); days kept before are not touched, and the run of days
  is still one, a day counting once whichever of the three was finished. The line to send says
  `Outside daily tomb #9, branching  4:10.2  2 deaths`, and the record a leaderboard would be sent says
  `"shape": "branching"` and gives `TombBranching.VERSION`.
- **Made by hand.** A `TombSpec` that says `"shape": "branching"` is a tomb on a floor plan (`TombFloorSpec`,
  `scripts/tomb_floor_spec.gd`, has what such a spec says): each room says the square it stands on (`cell`) and
  the room it is entered from (`from`), and since a room has one way in and up to three ways on, its `way` and
  `lock` are of the way INTO it; `lock_in` and `stone_in` say which room the lock's block and plate, brazier,
  table or seal stone are in, which may be any room of the tomb; and `joins` are second ways between two rooms
  side by side, with or without a door that opens only from one of them. `TombSpec.problems` says in plain words
  whatever cannot be built ("5 Corridor and 3 Antechamber stand on the same square", "The second way between 3
  Antechamber and 6 Corridor is a level doorway, and 6 Corridor is 1 level lower: make it stairs", "2 Corridor
  would have two blocks and plates of their own ...: a room has one"), and then asks
  `TombLayout3D.cells_wrong` of the plan as well. `TombFloorSpec.from_plan` takes any of the generator's into
  this form, and it comes back the same tomb. A spec that says nothing of a shape is a tomb down one axis, as
  every spec was: those, and `user://my_tombs.json`, open and play as before.
- **In the tomb editor** such a tomb is seen from overhead with its roofs off ("Tombs" has "A new one" and the
  generator's at each difficulty, under "a tomb that branches"). It is dragged and pinched as the other is. A
  touch on a room chooses it; a "+" stands off each side of the chosen room that a new room could be made on;
  "Move" marks every place the chosen room could go instead ("here": off which room, on which side; only a room
  with nothing beyond it moves, and its second ways do not go with it); "Join" marks every room beside it that a
  second way could be made to ("join"), or has one that a touch takes away ("unjoin"); "Remove" takes it away.
  The panel is the same but for the way and the lock, which are of the way into the chosen room, with the room
  its lock stands in to choose, and a heading for each of its second ways. "Play" and "Walk it" both play it
  walked through. The game is held on its side (the project asks for landscape), so there is no upright layout;
  at 960 by 720 everything is still on the screen.
- **The automated player** plays these from the solver's steps as it does the others
  (`tools/tomb_test.gd -- branching drive`). It had one thing to learn: with loops there is more than one way
  along his lines from one place to another, and the shortest may be through rooms he has no business in and a
  door that is shut, so in a tomb that branches it goes only by the lines of the room it is in and of the room it
  is going to.

| File | What it does |
| --- | --- |
| `scripts/tomb_plan.gd` | What a tomb is before it is built: rooms, ways, things, switches |
| `scripts/tomb_generator.gd` | Makes a plan from a seed; never hands back one that fails |
| `scripts/tomb_branching.gd` | Makes the plan of a tomb that branches from a seed, its rooms on squares of a floor plan; never hands back one that fails |
| `scripts/tomb_solver.gd` | Proves a plan can be finished, by trying everything |
| `scripts/tomb_layout.gd` | Sets a plan out as a tomb seen from the side: every stone and part, as numbers; and what a level asks of either layout |
| `scripts/tomb_layout_3d.gd` | Sets the same plan out as a tomb to be walked through: the cells and their rules, rooms and ways, the stone cut round them, and the lines he is expected to walk |
| `scripts/tomb_reach.gd` | What he can do, from the Player's own numbers, and a layout held against it |
| `scripts/tomb_builder.gd` | Makes either layout into nodes |
| `scripts/tomb_level.gd` | Runs a tomb, seen either way: doors, mummies, checkpoints, the clock, the cards |
| `scripts/tomb_daily.gd` | Which tomb a day has, and what is kept of how it went, for each way of seeing it |
| `scripts/tomb_spec.gd` | A tomb made by hand, as data: what is wrong with it, the plan of it, keeping it |
| `scripts/tomb_floor_spec.gd` | The part of that which is about a tomb that branches: where each room stands, what it is entered from, second ways; what is wrong with it in plain words; and what the editor does to a floor plan |
| `scripts/tomb_map.gd` | The map on the HUD of a tomb that branches |
| `scripts/tomb_editor.gd` | The tomb editor (`tomb_editor.tscn`): a tomb down one axis from the side, one that branches as a floor plan from overhead |
| `scripts/tomb_phone_ui.gd` | What is touched in the tomb editor on a phone: the two bars, the strip, and the pages |
| `tools/tomb_editor_test.gd` | Not part of the game: checks hand-made tombs and the editor, and works the editor as it is on a phone by touches alone, in both views (`tools/tomb_editor_shots.gd` takes pictures of it with a mouse, `tools/tomb_phone_shots.gd` on a phone) |
| `tools/tomb_phone_shots.gd` | Not part of the game: a picture of every state of the editor on a phone, each measured |
| `tools/tomb_phone_probe.gd` | Not part of the game: measures what can be touched on the phone layout against what a thumb needs (88 by 88, 12 apart, clear of the edges, words of 26) |
| `scripts/tomb_hooks.gd` | Where scarabs, cobwebs, jackals, inscriptions and the notebook plug in |
| `scripts/tomb_guide.gd` | What the Ba knows: the level as a position of the solver's, the next step from it, and the places to fly by to show it |
| `scripts/tomb_random.gd` | The dice |
| `tools/tomb_test.gd` | Not part of the game: checks plans, geometry and sameness over hundreds of seeds, and plays tombs through with the real Player, seen from the side or (`3d`) walked through |
| `tools/tomb_sheets.gd` | Not part of the game: draws a tomb's plan, the whole of it as built, and each room as he sees it (from the side) |
| `tools/tomb3d_sheets.gd` | Not part of the game: the same for a tomb walked through (its floor plan, the whole of it from overhead, each room through his camera), and with `kinds` a sheet of every kind of way, switch and barrier as he comes to it |
| `tools/tomb3d_probe.gd` | Not part of the game: prints how a tomb is set out to be walked through (cells, rooms, air, parts, his lines; with `at=x,z` the stone and the parts round a place) |
| `tools/tomb_branch_shots.gd` | Not part of the game: pictures of what a tomb that branches adds to the screen (the card, the map small and large, forks and a loop as he sees them, the editor's floor plan) |
| `tools/tomb_shapes.gd` | Not part of the game: tombs made by hand that the tools share (every lock; the two plates, the rope and the sand; every way; a plan with cells, a side chamber and a loop) |
| `tools/tomb_keeper_shots.gd` | Not part of the game: pictures of the creatures in a tomb as he meets them (each leaf, guardian, sphinx and Medjed, far and near; Apophis coming out; the Ba showing the way), in either view |

```
godot --headless --path . --fixed-fps 60 --script tools/tomb_test.gd -- [plans] [geometry] [same] [kept] [drive] [templates] [custom] [seeds=500] [drive_seeds=1,2,3] [per=3]
godot --headless --path . --fixed-fps 60 --script tools/tomb_test.gd -- 3d [geometry] [same] [drive] [templates] [custom] [grid] [seeds=500] [drive_seeds=1,2,3] [per=3] [pick=<part of a name>]
godot --path . --fixed-fps 60 --resolution 1280x720 --script tools/tomb_test.gd -- templates custom shots=<folder>
godot --path . --fixed-fps 60 --resolution 1280x720 --script tools/tomb_sheets.gd -- <folder> [seed:difficulty ...] [daily]
godot --path . --fixed-fps 60 --resolution 1280x720 --script tools/tomb3d_sheets.gd -- <folder> [seed:difficulty ...] [b<seed>:<difficulty> ...] [daily] [bdaily] [custom] [grid] [kinds]
godot --headless --path . --script tools/tomb3d_probe.gd -- <seed>:<difficulty> [branching] [areas] [parts] [lines] [at=<x>,<z>]
godot --headless --path . --fixed-fps 60 --script tools/tomb_test.gd -- branching [plans] [geometry] [same] [drive] [templates] [map] [doors] [seeds=500] [drive_seeds=1,2,3] [drive_difficulties=0,1,2]
godot --headless --path . --fixed-fps 60 --script tools/tomb_test.gd -- 3d doors
godot --headless --path . --fixed-fps 60 --script tools/tomb_test.gd -- sweep [seeds=300]
godot --headless --path . --fixed-fps 60 --script tools/tomb_test.gd -- [3d | branching] ba [drive_seeds=1,2,3] [drive_difficulties=0,1,2]
godot --headless --path . --fixed-fps 60 --script tools/tomb_test.gd -- [3d] custom pick=guardian|sphinx|medjed|snake
godot --path . --fixed-fps 60 --resolution 1280x720 --script tools/tomb_keeper_shots.gd -- <folder> [side | 3d | branching] [<seed>:<difficulty> | keepers | sphinx | medjed | snake]
godot --path . --fixed-fps 60 --resolution 1280x720 --script tools/tomb_branch_shots.gd -- <folder> [seed:difficulty] [name=<prefix>]
godot --path . --fixed-fps 60 --resolution 1280x720 res://tomb.tscn -- tomb=12:1 shape=branching
godot --headless --path . --fixed-fps 60 --script tools/tomb_editor_test.gd -- [seeds=60] [fuzz=1200] [size=1280x720]
godot --path . --fixed-fps 60 --resolution 1560x720 --script tools/tomb_phone_shots.gd -- <folder> [only=<part of a name>]
godot --path . --resolution 1560x720 res://tomb_editor.tscn -- phone [tombs_file=<file>]
```

Everything after `3d` is asked of the tomb that is walked through. There the automated player is steered about the
floor by the camera, as a thumb's push is: it goes by the lines the layout says he is expected to walk
(`TombLayout3D.walk_lines`), onto the nearest, from corner to corner along them, and off the last to where it is going;
and where the way is not a walk (a rope, the sand, the hook, up into a loft, down into a crypt) it does what he would.
