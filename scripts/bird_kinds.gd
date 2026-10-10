class_name BirdKinds
## What each kind of bird is: its measurements and colours (from which
## `BirdMesh` builds it), how it holds itself, how it flies and how it lives.
## They are the birds of the Nile valley and of the desert either side of it,
## most of them as common in a tomb painting as on the bank: README.md says where they come from.
##
## Lengths are metres on the living bird; `size` is how much bigger than life
## it is drawn (a sparrow at its true size is a speck on a phone).
##
## A bird is built flying, beak towards +Z, with its feet under it, and its
## colours are places in `palette`. The numbers under `stand`, `fly`, `peck`
## and `rest` are how its neck is held: the bend of the lower half, the bend of
## the upper half on that (radians, up), and where its bill points (above the
## level).

## How a kind lives. FLOCK: on the ground together, up together, wheeling, and
## down again. FORAGER: one or two walking about by themselves. SKIMMER: never
## down, hawking low over water and ground. WADER: at the water's edge.
## WATERFOWL: on the water. HOVERER: on a high perch, out to hang in the air
## over one spot, and down on what it sees. SOARER: in wide circles high up.
enum Habit { FLOCK, FORAGER, SKIMMER, WADER, WATERFOWL, HOVERER, SOARER }
## The outline of a wing: broad and square with fingered tips, pointed and
## swept, or short and round.
enum Wing { BROAD, POINTED, ROUND }

const NAMES: Array[String] = ["Sparrows", "Doves", "Hoopoe", "Swallows", "Sacred ibis", "Grey heron", "Cattle egret",
	"Egyptian goose", "Kestrel", "Pied kingfisher", "Egyptian vulture", "Griffon vulture", "Black kite"]

## What a kind has unless it says otherwise.
const USUAL := {
	"size": 1.0, "sides": 6, "stance": 0.3, "neck": 0.02, "neck_r": 0.02, "head": 0.03, "head_long": 1.3, "bill": 0.02, "bill_r": 0.008, "bill_curve": 0.0,
	"leg": 0.05, "leg_r": 0.004, "foot": 0.02, "trail": 0.0, "tail": 0.08, "tail_w": 0.04, "tail_shape": "round", "fingers": 0, "crest": 0.0, "eye": 0.3,
	"wing_bars": [], "wing_stations": 5,
	"stand": [0.2, 0.0, 0.0], "fly": [0.0, 0.0, 0.0], "peck": [-0.3, -0.3, -1.0], "rest": [0.3, 0.0, 0.0], "peck_tip": 0.8,
	"speed": 8.0, "turn": 10.0, "beat": 5.0, "depth": 0.8, "glide": 0.0, "dihedral": 0.05, "droop": 0.0, "bound": 0.0, "bound_rise": 0.0,
	"wary": 4.0, "cruise": 5.0, "hops": false, "walk": 0.35, "far": 30.0, "wade": 0.0, "soar_height": 60.0, "soar_wide": 30.0,
}

const TABLE: Array[Dictionary] = [
	# House sparrow: about the camp and the ruins in a chattering crowd, hopping, up all at once in a blur of wings.
	{
		"habit": Habit.FLOCK, "size": 1.5, "body": Vector3(0.062, 0.062, 0.105), "head": 0.023, "bill": 0.011, "bill_r": 0.007, "leg": 0.03, "foot": 0.016,
		"span": 0.23, "chord": 0.065, "wing": Wing.ROUND, "wing_stations": 3, "tail": 0.055, "tail_w": 0.022, "tail_shape": "square", "stance": 0.5,
		"palette": [Color(0.5, 0.33, 0.2), Color(0.8, 0.76, 0.68), Color(0.48, 0.47, 0.45), Color(0.2, 0.18, 0.16), Color(0.62, 0.48, 0.38), Color(0.3, 0.2, 0.13), Color(0.55, 0.27, 0.14), Color(0.08, 0.07, 0.07)],
		"body_cols": [0, 1, 0, 1, 6, 7], "neck_cols": [6, 6], "head_cols": [2, 1], "bill_col": 3, "eye_col": 7, "leg_col": 4,
		"wing_cols": [6, 5, 5, 0, 5, 5, 5], "tail_cols": [5, 5],
		"speed": 7.5, "turn": 22.0, "beat": 13.0, "depth": 1.0, "bound": 0.5, "bound_rise": 0.12, "wary": 3.6, "cruise": 3.5, "hops": true, "walk": 0.5, "far": 16.0, "peck_tip": 1.0,
	},
	# Laughing dove (the palm dove): pink-brown, blue-grey on the wing; walks with a nodding head, goes up with a clap.
	{
		"habit": Habit.FLOCK, "size": 1.25, "body": Vector3(0.1, 0.1, 0.2), "neck": 0.035, "neck_r": 0.03, "head": 0.027, "bill": 0.016, "bill_r": 0.005, "leg": 0.05, "foot": 0.025,
		"span": 0.5, "chord": 0.125, "wing": Wing.ROUND, "tail": 0.115, "tail_w": 0.045, "tail_shape": "round", "stance": 0.35,
		"palette": [Color(0.56, 0.4, 0.3), Color(0.83, 0.7, 0.64), Color(0.72, 0.52, 0.5), Color(0.2, 0.17, 0.17), Color(0.75, 0.35, 0.35), Color(0.25, 0.2, 0.2), Color(0.5, 0.56, 0.66), Color(0.95, 0.94, 0.9)],
		"body_cols": [0, 1, 0, 1, 2, 2], "neck_cols": [2, 2], "head_cols": [2, 2], "bill_col": 3, "eye_col": 3, "leg_col": 4,
		"wing_cols": [0, 6, 6, 6, 5, 5, 5], "tail_cols": [5, 7],
		"stand": [0.5, -0.1, 0.0], "peck": [-0.5, -0.3, -1.1],
		"speed": 10.0, "turn": 16.0, "beat": 6.5, "depth": 0.95, "wary": 4.6, "cruise": 5.0, "walk": 0.3, "far": 22.0, "peck_tip": 0.75,
	},
	# Hoopoe: cinnamon, barred black and white on wing and tail, a fan of a crest; flies like a big slow butterfly.
	{
		"habit": Habit.FORAGER, "size": 1.3, "body": Vector3(0.08, 0.08, 0.17), "neck": 0.03, "neck_r": 0.022, "head": 0.024, "bill": 0.055, "bill_r": 0.004, "bill_curve": 0.25,
		"leg": 0.04, "foot": 0.022, "crest": 0.075, "span": 0.46, "chord": 0.16, "wing": Wing.ROUND, "wing_stations": 7, "tail": 0.1, "tail_w": 0.04, "tail_shape": "square", "stance": 0.3,
		"palette": [Color(0.8, 0.56, 0.36), Color(0.9, 0.8, 0.7), Color(0.8, 0.56, 0.36), Color(0.25, 0.2, 0.18), Color(0.4, 0.38, 0.36), Color(0.08, 0.08, 0.08), Color(0.96, 0.95, 0.9), Color(0.08, 0.08, 0.08)],
		"body_cols": [6, 1, 0, 1, 0, 0], "neck_cols": [0, 0], "head_cols": [0, 0], "bill_col": 3, "eye_col": 5, "leg_col": 4,
		"wing_cols": [0, 5, 6, 5, 5, 6, 5], "wing_bars": [5, 6], "tail_cols": [6, 5],
		"stand": [0.45, -0.1, -0.1], "peck": [-0.4, -0.3, -1.2],
		"speed": 6.5, "turn": 12.0, "beat": 5.0, "depth": 1.05, "bound": 0.75, "bound_rise": 0.28, "wary": 4.5, "cruise": 3.0, "walk": 0.35, "far": 22.0, "peck_tip": 0.5,
	},
	# Barn swallow, the red-bellied one that stays on the Nile all year: never still, skimming the water.
	{
		"habit": Habit.SKIMMER, "size": 1.5, "body": Vector3(0.045, 0.045, 0.115), "head": 0.02, "bill": 0.008, "bill_r": 0.006, "leg": 0.014, "foot": 0.008,
		"span": 0.33, "chord": 0.06, "wing": Wing.POINTED, "tail": 0.1, "tail_w": 0.05, "tail_shape": "fork", "stance": 0.2,
		"palette": [Color(0.1, 0.13, 0.25), Color(0.72, 0.38, 0.22), Color(0.1, 0.13, 0.25), Color(0.08, 0.08, 0.08), Color(0.12, 0.1, 0.1), Color(0.08, 0.09, 0.14), Color(0.5, 0.15, 0.1), Color(0.05, 0.05, 0.05)],
		"body_cols": [0, 1, 0, 1, 0, 6], "neck_cols": [0, 6], "head_cols": [0, 6], "bill_col": 3, "eye_col": 7, "leg_col": 4,
		"wing_cols": [0, 5, 5, 0, 5, 5, 5], "tail_cols": [5, 5],
		"speed": 10.0, "turn": 26.0, "beat": 7.5, "depth": 0.8, "glide": 0.45, "dihedral": 0.0, "droop": 0.1, "wary": 1.0, "cruise": 1.2, "far": 18.0,
	},
	# Sacred ibis: Thoth's bird. White, with a bare black head and neck, a long bill bent down, and black plumes over its tail.
	{
		"habit": Habit.WADER, "sides": 8, "body": Vector3(0.18, 0.19, 0.42), "neck": 0.27, "neck_r": 0.024, "head": 0.034, "head_long": 1.5, "bill": 0.17, "bill_r": 0.014, "bill_curve": 0.55,
		"leg": 0.3, "leg_r": 0.008, "foot": 0.07, "trail": 1.0, "span": 1.18, "chord": 0.27, "wing": Wing.BROAD, "tail": 0.1, "tail_w": 0.07, "stance": 0.3,
		"palette": [Color(0.96, 0.95, 0.92), Color(0.88, 0.88, 0.86), Color(0.09, 0.09, 0.1), Color(0.09, 0.09, 0.1), Color(0.15, 0.15, 0.16), Color(0.1, 0.1, 0.14)],
		"body_cols": [5, 0, 0, 1, 0, 1], "neck_cols": [2, 2], "head_cols": [2, 2], "bill_col": 3, "eye_col": -1, "leg_col": 4,
		"wing_cols": [0, 0, 5, 0, 0, 5, 5], "tail_cols": [5, 5],
		"stand": [0.75, -0.35, -0.35], "fly": [-0.2, 0.0, -0.1], "peck": [-0.75, -0.5, -1.25], "rest": [1.3, -1.2, -0.5], "peck_tip": 0.45,
		"speed": 9.5, "turn": 6.0, "beat": 3.4, "depth": 0.7, "glide": 0.25, "wary": 7.0, "cruise": 8.0, "walk": 0.3, "far": 45.0, "wade": 0.2,
	},
	# Grey heron: the tall grey fisher, still as a post, its neck an S; flies slowly, neck drawn back and legs out behind.
	{
		"habit": Habit.WADER, "sides": 8, "body": Vector3(0.19, 0.2, 0.5), "neck": 0.46, "neck_r": 0.027, "head": 0.036, "head_long": 1.7, "bill": 0.125, "bill_r": 0.013,
		"leg": 0.45, "leg_r": 0.008, "foot": 0.09, "trail": 1.0, "span": 1.75, "chord": 0.36, "wing": Wing.BROAD, "tail": 0.12, "tail_w": 0.07, "stance": 0.5,
		"palette": [Color(0.6, 0.63, 0.68), Color(0.9, 0.9, 0.9), Color(0.95, 0.95, 0.94), Color(0.88, 0.7, 0.25), Color(0.55, 0.48, 0.3), Color(0.2, 0.22, 0.27), Color(0.1, 0.1, 0.12)],
		"body_cols": [0, 1, 0, 1, 0, 1], "neck_cols": [1, 2], "head_cols": [6, 2], "bill_col": 3, "eye_col": 6, "leg_col": 4,
		"wing_cols": [0, 5, 5, 0, 5, 5, 5], "tail_cols": [0, 0],
		"stand": [1.1, -1.0, 0.0], "fly": [2.0, -2.65, 0.0], "peck": [-1.2, -0.3, -1.05], "rest": [1.35, -2.3, -0.1], "peck_tip": 0.35,
		"speed": 8.5, "turn": 4.5, "beat": 2.3, "depth": 0.62, "glide": 0.15, "droop": 0.2, "wary": 10.0, "cruise": 9.0, "walk": 0.22, "far": 60.0, "wade": 0.3,
	},
	# Cattle egret: small, white, short in the neck and hunched; walks about the wet ground jabbing at things.
	{
		"habit": Habit.WADER, "sides": 8, "body": Vector3(0.12, 0.13, 0.28), "neck": 0.17, "neck_r": 0.022, "head": 0.028, "head_long": 1.5, "bill": 0.06, "bill_r": 0.009,
		"leg": 0.2, "leg_r": 0.006, "foot": 0.05, "trail": 1.0, "span": 0.9, "chord": 0.21, "wing": Wing.BROAD, "tail": 0.07, "tail_w": 0.045, "stance": 0.55,
		"palette": [Color(0.97, 0.97, 0.95), Color(0.9, 0.9, 0.9), Color(0.93, 0.78, 0.55), Color(0.92, 0.65, 0.2), Color(0.3, 0.3, 0.22), Color(0.12, 0.12, 0.12)],
		"body_cols": [0, 1, 0, 1, 2, 1], "neck_cols": [0, 0], "head_cols": [2, 0], "bill_col": 3, "eye_col": 5, "leg_col": 4,
		"wing_cols": [0, 0, 0, 0, 0, 1, 1], "tail_cols": [0, 0],
		"stand": [0.9, -1.1, 0.0], "fly": [1.9, -2.5, 0.0], "peck": [-0.9, -0.3, -1.1], "rest": [1.4, -2.1, 0.0], "peck_tip": 0.45,
		"speed": 8.0, "turn": 7.0, "beat": 3.6, "depth": 0.7, "glide": 0.1, "droop": 0.15, "wary": 6.0, "cruise": 6.0, "walk": 0.35, "far": 40.0, "wade": 0.12,
	},
	# Egyptian goose: brown and buff, a dark patch round the eye, and a white forewing that flashes when it flies.
	{
		"habit": Habit.WATERFOWL, "sides": 8, "body": Vector3(0.25, 0.25, 0.52), "neck": 0.2, "neck_r": 0.036, "head": 0.045, "head_long": 1.35, "bill": 0.05, "bill_r": 0.018,
		"leg": 0.16, "leg_r": 0.011, "foot": 0.08, "span": 1.4, "chord": 0.29, "wing": Wing.BROAD, "tail": 0.1, "tail_w": 0.07, "stance": 0.4, "eye": 0.65,
		"palette": [Color(0.5, 0.36, 0.24), Color(0.8, 0.72, 0.62), Color(0.85, 0.8, 0.72), Color(0.85, 0.5, 0.55), Color(0.85, 0.45, 0.5), Color(0.1, 0.1, 0.1), Color(0.96, 0.96, 0.94), Color(0.42, 0.2, 0.12), Color(0.1, 0.45, 0.3)],
		"body_cols": [5, 1, 0, 1, 1, 7], "neck_cols": [1, 2], "head_cols": [2, 2], "bill_col": 3, "eye_col": 7, "leg_col": 4,
		"wing_cols": [6, 6, 8, 6, 5, 5, 5], "tail_cols": [5, 5],
		"stand": [0.85, -0.25, 0.0], "fly": [-0.2, 0.0, 0.0], "peck": [-0.9, -0.4, -1.2], "rest": [1.2, -0.9, 0.0], "peck_tip": 0.35,
		"speed": 11.0, "turn": 6.0, "beat": 3.9, "depth": 0.65, "wary": 6.5, "cruise": 7.0, "walk": 0.35, "far": 50.0,
	},
	# Kestrel: the little rufous falcon that hangs in the wind over one spot, tail spread, and drops. (Horus is a falcon.)
	{
		"habit": Habit.HOVERER, "size": 1.15, "body": Vector3(0.09, 0.09, 0.2), "head": 0.034, "bill": 0.02, "bill_r": 0.012, "bill_curve": 1.0, "leg": 0.06, "leg_r": 0.006, "foot": 0.03,
		"span": 0.75, "chord": 0.13, "wing": Wing.POINTED, "tail": 0.16, "tail_w": 0.06, "tail_shape": "round", "stance": 0.95,
		"palette": [Color(0.7, 0.4, 0.22), Color(0.88, 0.78, 0.6), Color(0.55, 0.6, 0.68), Color(0.3, 0.3, 0.35), Color(0.9, 0.75, 0.2), Color(0.2, 0.17, 0.15), Color(0.6, 0.64, 0.7), Color(0.08, 0.08, 0.08)],
		"body_cols": [6, 1, 0, 1, 0, 1], "neck_cols": [2, 1], "head_cols": [2, 1], "bill_col": 3, "eye_col": 7, "leg_col": 4,
		"wing_cols": [0, 0, 5, 0, 5, 5, 5], "tail_cols": [6, 7],
		"stand": [-0.5, 0.0, 0.0], "rest": [-0.5, 0.0, 0.0], "peck": [-0.9, -0.2, -1.0], "peck_tip": 0.5,
		"speed": 9.0, "turn": 12.0, "beat": 5.5, "depth": 0.7, "glide": 0.4, "wary": 8.0, "cruise": 10.0, "far": 30.0,
	},
	# Pied kingfisher: black and white, big-headed; hovers over the water with its bill pointing down, and goes in after it.
	{
		"habit": Habit.HOVERER, "size": 1.3, "body": Vector3(0.07, 0.07, 0.15), "head": 0.034, "head_long": 1.4, "bill": 0.06, "bill_r": 0.009, "leg": 0.02, "foot": 0.014, "crest": 0.0,
		"span": 0.46, "chord": 0.1, "wing": Wing.POINTED, "wing_stations": 7, "tail": 0.07, "tail_w": 0.035, "tail_shape": "square", "stance": 0.8,
		"palette": [Color(0.1, 0.1, 0.1), Color(0.96, 0.96, 0.95), Color(0.1, 0.1, 0.1), Color(0.08, 0.08, 0.08), Color(0.1, 0.1, 0.1)],
		"body_cols": [0, 1, 0, 1, 0, 0], "neck_cols": [1, 1], "head_cols": [0, 1], "bill_col": 3, "eye_col": 0, "leg_col": 4, "eye": 0.5,
		"wing_cols": [0, 1, 0, 0, 1, 0, 0], "wing_bars": [1, 0], "tail_cols": [1, 0],
		"stand": [-0.7, 0.0, -0.15], "rest": [-0.7, 0.0, -0.15], "peck": [-0.9, 0.0, -1.0],
		"speed": 9.0, "turn": 14.0, "beat": 9.0, "depth": 0.8, "wary": 6.0, "cruise": 4.0, "far": 24.0,
	},
	# Egyptian vulture: Pharaoh's chicken. White with black flight feathers, a bare yellow face, a wedge of a tail; soars on flat wings.
	{
		"habit": Habit.SOARER, "sides": 8, "body": Vector3(0.2, 0.2, 0.42), "neck": 0.08, "neck_r": 0.035, "head": 0.042, "head_long": 1.4, "bill": 0.055, "bill_r": 0.014, "bill_curve": 0.9,
		"leg": 0.14, "leg_r": 0.01, "foot": 0.06, "span": 1.65, "chord": 0.36, "wing": Wing.BROAD, "fingers": 5, "tail": 0.25, "tail_w": 0.11, "tail_shape": "wedge", "stance": 0.6,
		"palette": [Color(0.95, 0.92, 0.84), Color(0.9, 0.87, 0.78), Color(0.95, 0.75, 0.2), Color(0.85, 0.65, 0.2), Color(0.9, 0.75, 0.6), Color(0.1, 0.1, 0.1)],
		"body_cols": [0, 1, 0, 1, 0, 1], "neck_cols": [0, 0], "head_cols": [0, 2], "bill_col": 3, "eye_col": 5, "leg_col": 4,
		"wing_cols": [0, 5, 5, 0, 5, 5, 5], "tail_cols": [0, 0],
		"stand": [0.2, 0.0, -0.2], "fly": [-0.2, 0.0, -0.2], "peck": [-0.8, -0.3, -1.2], "peck_tip": 0.5,
		"speed": 9.0, "turn": 4.0, "beat": 2.3, "depth": 0.5, "glide": 0.92, "dihedral": 0.03, "wary": 9.0, "cruise": 12.0, "hops": true, "walk": 0.5, "far": 60.0,
		"soar_height": 38.0, "soar_wide": 30.0,
	},
	# Griffon vulture: Nekhbet's bird. Huge, tawny, dark in wing and tail, with a pale head on a long bare neck; soars on wings held up in a shallow V.
	{
		"habit": Habit.SOARER, "sides": 8, "body": Vector3(0.32, 0.3, 0.7), "neck": 0.24, "neck_r": 0.045, "head": 0.06, "head_long": 1.4, "bill": 0.07, "bill_r": 0.02, "bill_curve": 0.9,
		"leg": 0.2, "leg_r": 0.014, "foot": 0.09, "span": 2.6, "chord": 0.62, "wing": Wing.BROAD, "fingers": 6, "tail": 0.26, "tail_w": 0.15, "tail_shape": "square", "stance": 0.6,
		"palette": [Color(0.72, 0.58, 0.38), Color(0.78, 0.66, 0.46), Color(0.92, 0.9, 0.82), Color(0.75, 0.7, 0.55), Color(0.5, 0.5, 0.48), Color(0.2, 0.16, 0.13)],
		"body_cols": [0, 1, 0, 1, 2, 1], "neck_cols": [2, 2], "head_cols": [2, 2], "bill_col": 3, "eye_col": 5, "leg_col": 4,
		"wing_cols": [0, 5, 5, 0, 5, 5, 5], "tail_cols": [5, 5],
		"stand": [0.9, -1.3, -0.25], "fly": [1.0, -1.6, -0.3], "peck": [-0.6, -0.3, -1.1], "rest": [1.2, -1.8, -0.3], "peck_tip": 0.45,
		"speed": 11.0, "turn": 3.0, "beat": 1.5, "depth": 0.45, "glide": 0.97, "dihedral": 0.2, "wary": 10.0, "cruise": 14.0, "hops": true, "walk": 0.5, "far": 80.0,
		"soar_height": 50.0, "soar_wide": 40.0,
	},
	# Black kite: the brown scavenger of every town on the Nile; lower than the vultures, forever twisting its forked tail.
	{
		"habit": Habit.SOARER, "sides": 8, "body": Vector3(0.14, 0.14, 0.34), "neck": 0.03, "neck_r": 0.035, "head": 0.04, "bill": 0.03, "bill_r": 0.014, "bill_curve": 1.0,
		"leg": 0.09, "leg_r": 0.008, "foot": 0.04, "span": 1.5, "chord": 0.28, "wing": Wing.BROAD, "fingers": 5, "tail": 0.27, "tail_w": 0.12, "tail_shape": "notch", "stance": 0.8,
		"palette": [Color(0.42, 0.3, 0.2), Color(0.5, 0.34, 0.22), Color(0.6, 0.52, 0.42), Color(0.9, 0.75, 0.2), Color(0.9, 0.75, 0.2), Color(0.2, 0.15, 0.12), Color(0.6, 0.5, 0.38)],
		"body_cols": [0, 1, 0, 1, 0, 1], "neck_cols": [2, 2], "head_cols": [2, 2], "bill_col": 3, "eye_col": 5, "leg_col": 4,
		"wing_cols": [0, 0, 5, 6, 5, 5, 5], "tail_cols": [0, 1],
		"stand": [-0.3, 0.0, 0.0], "fly": [0.0, 0.0, -0.3], "peck": [-0.8, -0.2, -1.1], "peck_tip": 0.5,
		"speed": 8.0, "turn": 6.0, "beat": 2.7, "depth": 0.55, "glide": 0.85, "dihedral": 0.02, "droop": 0.12, "wary": 9.0, "cruise": 10.0, "hops": true, "far": 55.0,
		"soar_height": 22.0, "soar_wide": 18.0,
	},
]

static var _whole := {}


## Everything about a kind (its place in `TABLE`), with what it does not say filled in.
static func of(kind: int) -> Dictionary:
	if not _whole.has(kind):
		var made := USUAL.duplicate()
		made.merge(TABLE[kind], true)
		_whole[kind] = made
	return _whole[kind]
