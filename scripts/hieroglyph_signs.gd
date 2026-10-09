class_name HieroglyphSigns
## The signs `Hieroglyphs` writes with: the Egyptian "alphabet" (the signs that
## stand for one consonant each) and the commonest of the rest: signs for two
## and three consonants, signs that are a whole word, the determinatives that
## end a word and say what kind of thing it is, and the numerals.
##
## Each is drawn here, in code, as an outline: nothing is taken from a font.
## They are drawn as they are carved: a filled shape, with only as much inside
## it as it needs to be told from its neighbours. All of them face left, which
## is how they stand in a text read from left to right.
##
## A sign is known by its number in Gardiner's sign list (G17 is the owl), which
## is what Egyptologists call it by. `SIGNS` gives for each:
##     0   what it is a picture of
##     1   how it is typed, in the Manuel de Codage (the usual way of typing
##         Egyptian in plain letters: A i a w b p f m n r h H x X z s S q k g t T d D,
##         and names like anx and nfr for the longer ones); "" if it has none
##     2   how that is written out by Egyptologists, or what it means
##     3   what it does: "1" one consonant, "2" two or three, "w" a word,
##         "d" a determinative, "n" a numeral
##     4   its paint, where signs are painted: b blue, g green, r red ochre,
##         y yellow, k black, w white
##     5   how wide and how tall it is. A whole square of writing (a quadrat) is
##         100 by 100: a tall sign fills its height, a flat one its width, and a
##         small one neither, and that is what they are packed by.
##     6   the drawing: a list of strokes, each a line of text (see below)
##
## A stroke is a letter, then numbers. Points are "x,y" from the top left of the
## sign's own box; a "c" after one makes a corner of it in a curve.
##     F points          a filled shape with straight sides
##     S points          a filled shape, rounded through its points
##     L width points    a line
##     C width points    a curved line
##     P width points    a line that closes on itself
##     Q width points    a curved line that closes on itself
##     O x,y rx,ry       a filled oval
##     R width x,y rx,ry a ring
## With "-" before the letter it is cut out of the rest instead.

const SIGNS := {
	# The alphabet.
	"G1": ["vulture", "A", "ꜣ", "1", "y", 78, 100, ["S 2,13c 12,3 24,4 30,16 42,34 60,60 77,88c 60,84 44,76 30,70 21,52 19,30 13,19 5,20c", "L 6 33,68 33,96 21,96", "L 6 46,74 46,96 35,96"]],
	"M17": ["reed leaf", "i", "i", "1", "g", 30, 100, ["F 11,2 20,0 27,7 27,100 20,100 20,80 3,70"]],
	"Z4": ["two strokes", "y", "y", "1", "k", 40, 32, ["L 6 5,4 14,28", "L 6 25,4 34,28"]],
	"D36": ["forearm", "a", "ꜥ", "1", "r", 100, 30, ["S 2,22c 6,15 14,12 18,17 26,19c 82,19c 85,3c 96,3c 97,29c 24,29c 10,30 4,28c"]],
	"G43": ["quail chick", "w", "w", "1", "y", 62, 100, ["S 2,17c 13,5 24,3 31,13 35,28 50,42 59,60 56,71c 40,76 24,70 15,54 14,36 11,24c", "L 6 29,70 29,96 17,96", "L 6 41,72 41,96 31,96"]],
	"Z7": ["coil", "W", "w", "1", "k", 36, 50, ["C 6 31,47 14,38 6,23 13,8 25,7 30,17 25,26 17,22"]],
	"D58": ["foot", "b", "b", "1", "r", 56, 100, ["S 36,2c 52,2c 54,90c 50,99c 6,99c 2,93c 8,86 28,84 34,70c"]],
	"Q3": ["stool", "p", "p", "1", "g", 40, 48, ["P 7 6,6 34,6 34,42 6,42"]],
	"I9": ["horned viper", "f", "f", "1", "y", 100, 30, ["C 8 12,17 24,11 38,20 54,22 70,16 84,20 96,23", "O 10,16 8,6", "L 4 7,13 3,2", "L 4 12,12 15,2"]],
	"G17": ["owl", "m", "m", "1", "y", 70, 100, ["S 9,8c 14,2 34,2 39,8c 41,24 50,40 62,64 68,91c 54,87 42,80 26,74 14,54 10,30", "-O 17,13 3.5,3.5", "-O 31,13 3.5,3.5", "L 6 25,72 25,96 14,96", "L 6 38,78 38,96 28,96"]],
	"N35": ["ripple of water", "n", "n", "1", "b", 100, 18, ["L 6 2,15 10,3 18,15 26,3 34,15 42,3 50,15 58,3 66,15 74,3 82,15 90,3 98,15"]],
	"D21": ["mouth", "r", "r", "1", "r", 100, 26, ["Q 6 4,13c 26,4 50,3 74,4 96,13c 74,22 50,23 26,22"]],
	"O4": ["reed shelter", "h", "h", "1", "b", 62, 62, ["L 8 5,58 5,5 57,5 57,58 32,58 32,28"]],
	"V28": ["twisted wick", "H", "ḥ", "1", "g", 28, 100, ["C 5 14,3 22,12 14,24 6,36 14,48 22,60 14,72 3,97", "C 5 14,3 6,12 14,24 22,36 14,48 6,60 14,72 25,97"]],
	"Aa1": ["placenta", "x", "ḫ", "1", "y", 44, 44, ["O 22,22 20,20", "-L 3.5 7,13 37,13", "-L 3.5 3,22 41,22", "-L 3.5 7,31 37,31"]],
	"F32": ["belly and tail", "X", "ẖ", "1", "r", 100, 28, ["S 4,14 14,6 26,7 36,11 60,11 80,7 94,10 98,15 92,20 78,19 60,17 36,17 26,21 14,22", "L 4 9,7 7,1", "L 4 19,6 19,0", "L 4 29,8 31,2", "L 4 9,21 7,27", "L 4 19,22 19,28", "L 4 29,20 31,26"]],
	"O34": ["door bolt", "z", "z", "1", "k", 100, 16, ["L 5 2,8 98,8", "O 44,8 6,6", "O 56,8 6,6"]],
	"S29": ["folded cloth", "s", "s", "1", "w", 26, 100, ["C 7 6,98c 6,14c 7,6 13,3 19,6 20,14c 20,58c"]],
	"N37": ["pool", "S", "š", "1", "b", 100, 26, ["P 6 4,4 96,4 96,22 4,22"]],
	"N29": ["hill slope", "q", "q", "1", "y", 44, 46, ["S 2,44c 14,36 24,9 35,3 42,10c 42,44c"]],
	"V31": ["basket with a handle", "k", "k", "1", "g", 100, 32, ["S 4,4c 88,4c 80,20 64,28 46,29 28,28 12,20", "R 4 91,11 6,8"]],
	"W11": ["jar stand", "g", "g", "1", "r", 44, 48, ["S 4,4c 40,4c 40,10c 34,13 36,30 40,45c 22,47 4,45c 8,30 10,13 4,10c", "-F 22,18 27,36 17,36"]],
	"X1": ["loaf of bread", "t", "t", "1", "k", 40, 22, ["S 2,21c 6,8 20,2 34,8 38,21c"]],
	"V13": ["tethering rope", "T", "ṯ", "1", "g", 100, 26, ["C 6 10,5c 80,5c 92,8 95,13 92,18 80,21c 10,21c", "O 8,5 6,4.5", "O 8,21 6,4.5"]],
	"D46": ["hand", "d", "d", "1", "r", 100, 28, ["S 3,17 10,9 30,8 44,10c 58,5 64,11c 96,10c 96,25c 30,25 10,25"]],
	"I10": ["cobra", "D", "ḏ", "1", "y", 100, 96, ["C 8 12,10 16,22 26,28 54,27 80,29 90,42 92,70 96,94", "O 10,8 9,6"]],
	"E23": ["lion", "l", "l, rw", "1", "y", 100, 56, ["S 3,54c 5,47 18,45 20,35 14,26 16,12 26,4 38,6 44,16 46,27 62,25 80,27 90,35 95,54c", "C 5 89,36 97,25 93,12 86,17"]],
	"V4": ["lasso", "wA", "wꜣ, o", "1", "g", 66, 100, ["C 6 60,97 59,50 55,15 40,4 27,10 23,30 22,50", "R 5 22,68 8,16", "L 5 4,48 42,57"]],

	# Signs that are a word, or two or three consonants at once.
	"S34": ["sandal strap", "anx", "ꜥnḫ, life", "2", "b", 46, 100, ["Q 6 23,41 12,25 14,9 23,4 32,9 34,25", "L 7 3,45 43,45", "L 7 23,45 23,97"]],
	"S40": ["sceptre with an animal's head", "wAs", "wꜣs, power", "2", "g", 30, 100, ["L 5 18,10 18,84", "L 6 26,4 5,21", "L 4 17,10 11,2", "L 4.5 18,82 11,89 11,98", "L 4.5 18,82 25,89 25,98"]],
	"R11": ["pillar", "Dd", "ḏd, lasting", "2", "g", 42, 100, ["S 11,98c 31,98c 27,72 27,44c 15,44c 15,72", "L 6 4,13 38,13", "L 6 4,23 38,23", "L 6 4,33 38,33", "L 6 4,43 38,43", "L 9 21,5 21,44"]],
	"N5": ["sun", "ra", "rꜥ, sun, day", "w", "r", 50, 50, ["R 6 25,25 21,21", "O 25,25 5.5,5.5"]],
	"D10": ["eye of Horus", "wDAt", "wḏꜣt, the sound eye", "w", "b", 100, 76, ["C 7 5,15 30,5 60,7 96,23", "Q 6 8,35c 30,23 56,23 86,35c 60,44 34,44", "O 46,34 9,8", "L 6 44,46 44,73", "C 6 52,46 66,61 84,70 95,64 92,56 86,59"]],
	"L1": ["scarab", "xpr", "ḫpr, become", "2", "b", 62, 100, ["O 31,58 20,30", "O 31,23 13,9", "C 5 20,36 8,23 7,5", "C 5 42,36 54,23 55,5", "L 5 13,54 2,62", "L 5 49,54 60,62", "C 5 16,76 6,86 10,98", "C 5 46,76 56,86 52,98", "-L 3.5 31,36 31,86", "-L 3.5 13,43 49,43"]],
	"F35": ["heart and windpipe", "nfr", "nfr, good", "2", "r", 30, 100, ["O 15,78 13,20", "L 5 15,4 15,62", "L 5 4,17 26,17"]],
	"O1": ["house", "pr", "pr, house", "2", "w", 86, 44, ["L 7 33,40 5,40 5,5 81,5 81,40 53,40"]],
	"O49": ["town with crossroads", "niwt", "niwt, town", "w", "b", 50, 50, ["R 6 25,25 21,21", "L 6 11,11 39,39", "L 6 39,11 11,39"]],
	"N35A": ["three ripples", "mw", "mw, water", "2", "b", 100, 68, ["L 6 2,15 10,3 18,15 26,3 34,15 42,3 50,15 58,3 66,15 74,3 82,15 90,3 98,15", "L 6 2,40 10,28 18,40 26,28 34,40 42,28 50,40 58,28 66,40 74,28 82,40 90,28 98,40", "L 6 2,65 10,53 18,65 26,53 34,65 42,53 50,65 58,53 66,65 74,53 82,65 90,53 98,65"]],
	"R4": ["loaf on a mat", "Htp", "ḥtp, offering, peace", "2", "g", 100, 40, ["F 3,26 97,26 97,38 3,38", "F 50,1 58,14 55,25 45,25 42,14"]],
	"M23": ["sedge", "sw", "sw; nsw, king", "2", "g", 48, 100, ["C 5 26,98c 26,20c 24,8 16,3 7,7", "C 4.5 26,68 14,65 4,56", "C 4.5 26,68 38,65 46,56", "C 4.5 26,78 13,77 3,69", "C 4.5 26,78 39,77 47,69"]],
	"X8": ["cone of bread", "di", "di, give", "2", "y", 46, 100, ["P 6 23,5 42,95 4,95", "L 5 15,95 23,64 31,95"]],
	"R8": ["flag on a pole", "nTr", "nṯr, god", "2", "y", 44, 100, ["L 6 38,3 38,97", "F 38,5 5,3 5,19 22,17 38,24"]],
	"V30": ["basket", "nb", "nb, lord, all", "2", "g", 100, 32, ["S 3,4c 97,4c 88,20 70,29 50,30 30,29 12,20"]],
	"N16": ["land with grains of sand", "tA", "tꜣ, land", "2", "k", 100, 24, ["L 9 7,7 93,7", "O 34,19 3.5,3.5", "O 50,19 3.5,3.5", "O 66,19 3.5,3.5"]],
	"G5": ["falcon", "G5", "ḥr, Horus", "w", "y", 74, 100, ["S 3,15c 11,5 23,2 33,8 37,22 47,40 60,64 71,93c 57,91 44,80 28,72 18,52 14,34 14,24 9,20c", "-C 3.5 22,13 23,22 17,27", "L 6 28,70 28,96 16,96", "L 6 41,78 41,96 31,96"]],
	"G39": ["pintail duck", "sA", "sꜣ, son", "2", "y", 100, 92, ["S 24,46 36,37 60,39 80,48 98,59c 78,66 56,71 36,69 25,60", "C 7 31,48 25,32 21,19 15,11", "O 14,10 8,6.5", "L 4.5 9,11 1,14", "L 5 44,68 44,90 33,90", "L 5 59,68 59,90 48,90"]],
	"L2": ["bee", "bit", "bit, bee; king of the north", "2", "y", 100, 92, ["O 43,63 12,9", "O 27,64 7,8", "S 42,56 49,26 63,5 74,7 70,31 55,57c", "S 57,57 78,28 97,23 96,37 75,55c", "S 53,62 72,55 92,65 98,81 86,77 70,73c", "L 4 36,70 30,89", "L 4 44,72 42,91", "L 4 52,72 54,89", "C 3.5 25,58 18,42 12,31", "C 3.5 23,60 12,52 5,43"]],
	"D4": ["eye", "ir", "ir, do, make", "2", "k", 100, 36, ["Q 6 4,20c 24,7 50,4 76,9 96,20c 74,30 50,32 26,30", "O 46,18 10,10"]],
	"Q1": ["throne", "st", "st, seat", "2", "b", 46, 100, ["F 4,98 4,86 20,86 20,44 31,44 31,4 44,4 44,98"]],
	"N14": ["star", "dwA", "sbꜣ, star; dwꜣ, praise", "2", "y", 60, 60, ["F 30,3 34.7,25.5 57.6,23 37.6,34.5 47,55.5 30,40 13,55.5 22.4,34.5 2.4,23 25.3,25.5"]],
	"N1": ["sky", "pt", "pt, sky", "w", "b", 100, 26, ["F 3,3 97,3 97,24 88,14 12,14 3,24"]],
	"S12": ["collar of beads", "nbw", "nbw, gold", "w", "y", 100, 52, ["C 7 8,50c 8,11c 14,4c 86,4c 92,11c 92,50c", "C 5 12,9 30,26 50,30 70,26 88,9", "O 30,35 3.5,3.5", "O 40,39 3.5,3.5", "O 50,40 3.5,3.5", "O 60,39 3.5,3.5", "O 70,35 3.5,3.5"]],
	"D2": ["face", "Hr", "ḥr, face, upon", "2", "r", 56, 60, ["O 28,26 20,22", "O 6,26 5,7", "O 50,26 5,7", "F 22,45 34,45 36,58 20,58", "-L 3.5 15,22 24,22", "-L 3.5 32,22 41,22", "-L 3.5 22,36 34,36"]],
	"D28": ["two arms raised", "kA", "kꜣ, spirit", "2", "r", 86, 70, ["L 9 12,64 74,64", "L 8 12,64 12,20", "L 8 74,64 74,20", "L 4 12,22 6,4", "L 4 12,22 17,4", "L 4 74,22 69,4", "L 4 74,22 80,4"]],
	"U6": ["hoe", "mr", "mr, love", "2", "r", 72, 100, ["C 6 8,3 30,48 62,97", "L 7 8,3 68,52", "L 4 24,50 44,28"]],
	"N28": ["hill with the sun rising", "xa", "ḫꜥ, rise, appear", "2", "y", 100, 50, ["S 3,36c 20,13 50,4 80,13 97,36c 84,44c 68,27 50,21 32,27 16,44c", "S 24,48c 31,34 50,28 69,34 76,48c"]],
	"W24": ["bowl", "nw", "nw", "2", "b", 44, 50, ["O 22,31 19,18", "L 6 9,6 35,6", "F 14,6 30,6 30,15 14,15"]],
	"O29": ["wooden column", "aA", "ꜥꜣ, great", "2", "r", 100, 24, ["S 2,12c 10,5 16,10c 40,8 70,4 92,6 98,12 92,18 70,20 40,16 16,14c 10,19"]],
	"P8": ["oar", "xrw", "ḫrw, voice", "2", "r", 22, 100, ["F 6,2 16,2 13,62 9,62", "S 11,57c 18,74 16,90 11,98c 6,90 4,74"]],
	"Aa11": ["platform", "mAa", "mꜣꜥ, true", "2", "b", 100, 18, ["F 22,3 97,3 97,15 3,15"]],
	"F34": ["heart", "ib", "ib, heart", "w", "r", 44, 52, ["S 12,4c 32,4c 30,12c 40,16 42,22c 36,25 34,40 28,50c 16,50c 10,40 8,25 2,22c 4,16 14,12c"]],
	"O31": ["door", "O31", "ꜥꜣ, door", "w", "r", 100, 26, ["F 3,3 97,3 97,10 90,10 90,23 14,23 12,10 3,10"]],
	"Y5": ["board with playing pieces", "mn", "mn, lasting", "2", "k", 100, 38, ["F 3,16 97,16 97,36 3,36", "L 5 12,4 12,17", "L 5 27,4 27,17", "L 5 42,4 42,17", "L 5 58,4 58,17", "L 5 73,4 73,17", "L 5 88,4 88,17"]],
	"F31": ["three fox skins", "ms", "ms, born", "2", "y", 50, 100, ["L 5 25,24 9,50 9,98", "L 5 25,24 25,98", "L 5 25,24 41,50 41,98", "L 4 25,24 25,4", "L 4 25,22 10,8", "L 4 25,22 40,8", "F 9,50 3,68 15,68", "F 25,50 19,68 31,68", "F 41,50 35,68 47,68"]],
	"U28": ["fire drill", "DA", "ḏꜣ; wḏꜣ, sound", "2", "r", 34, 100, ["S 17,3c 24,30 23,62 19,83c 15,83c 11,62 10,30", "F 5,86 29,86 29,97 5,97"]],
	"W19": ["milk jug in a net", "mi", "mi, like", "2", "r", 34, 100, ["Q 5 17,62 9,40 10,13 17,5 24,13 25,40", "O 17,81 13,13", "L 4 2,74 32,74"]],
	"U23": ["chisel", "Ab", "ꜣb, mr", "2", "r", 26, 100, ["L 4 5,4 21,4", "S 8,8c 18,8c 20,22 17,34c 9,34c 6,22", "S 9,33c 17,33c 15,60 16,80 16,98c 10,98c 10,80 11,60"]],
	"N26": ["two hills", "Dw", "ḏw, mountain", "2", "r", 80, 54, ["S 3,52c 3,22c 8,6 18,4 24,16 32,36 40,42 48,36 56,16 62,4 72,6 77,22c 77,52c"]],
	"N27": ["sun between two hills", "Axt", "ꜣḫt, horizon", "w", "r", 86, 60, ["S 3,58c 3,38c 8,26 16,26 24,38 34,50 43,52 52,50 62,38 70,26 78,26 83,38c 83,58c", "O 43,24 16,16", "-O 43,24 6,6"]],
	"S43": ["walking stick", "mdw", "mdw, words", "2", "y", 16, 100, ["L 6 8,4 8,90", "O 8,92 6,6"]],
	"S38": ["crook", "HqA", "ḥqꜣ, ruler", "2", "y", 30, 100, ["C 5 10,97c 10,24c 10,9 18,4 25,10 21,20"]],
	"G26": ["ibis on a standard", "G26", "ḏḥwty, Thoth", "w", "k", 96, 100, ["O 58,34 22,11", "F 76,29 96,37 78,43", "C 6 40,31 31,23 28,11", "O 26,8 7,5.5", "C 4 22,8 12,12 6,27", "L 4 52,44 50,65", "L 4 63,44 63,65", "L 6 20,67 86,67", "L 6 56,67 56,98", "L 4 30,67 40,81"]],
	"Q7": ["brazier", "Q7", "fire", "d", "r", 50, 100, ["S 24,62 10,42 14,16 26,3 25,23 37,37 38,56c", "F 13,62 47,62 41,75 19,75", "L 6 30,75 30,96", "L 6 18,96 42,96"]],

	# Determinatives: they are not read, and say what kind of thing the word before them is.
	"A1": ["seated man", "A1", "a man, a name; I", "d", "r", 66, 100, ["O 28,14 11,12", "S 21,27c 40,27c 46,50 48,66c 28,66c 22,50", "C 6 26,35 13,41 5,30", "C 6 40,37 51,50 45,61", "S 8,98c 62,98c 60,88 48,82 48,64c 30,64c 20,60 10,72 16,84c"]],
	"A2": ["man with his hand to his mouth", "A2", "eat, speak, think, feel", "d", "r", 66, 100, ["O 28,14 11,12", "S 21,27c 40,27c 46,50 48,66c 28,66c 22,50", "C 6 26,36 12,36 15,19", "C 6 40,37 51,50 45,61", "S 8,98c 62,98c 60,88 48,82 48,64c 30,64c 20,60 10,72 16,84c"]],
	"B1": ["seated woman", "B1", "a woman", "d", "y", 52, 100, ["S 14,98c 47,98c 47,62 41,38 39,25c 24,25c 18,40 22,54 10,74 8,90", "O 28,14 10,11", "F 33,5 42,13 46,48 37,48 37,20"]],
	"A40": ["seated god", "A40", "a god; a king", "d", "y", 52, 100, ["S 14,98c 47,98c 47,62 41,38 39,25c 24,25c 18,40 22,54 10,74 8,90", "O 28,14 10,11", "F 33,5 42,13 45,40 37,40 37,20", "C 4 20,22 15,32 20,37"]],
	"A14": ["fallen man", "A14", "die; an enemy", "d", "r", 90, 100, ["O 22,24 9,9", "C 14 31,32 46,35 62,53", "L 10 62,55 46,84", "L 8 46,87 82,91", "L 6 30,38 24,62 34,70", "C 4 15,30 11,60 14,96"]],
	"A53": ["mummy standing", "A53", "a mummy; a likeness", "d", "w", 26, 100, ["S 9,3 17,2 22,9 21,19 17,22c 22,27 23,45 21,72 18,90 21,98c 3,98c 8,90 7,72 5,45 6,27 10,22c 6,17 5,9"]],
	"Z1": ["stroke", "Z1", "the thing itself; one", "n", "k", 12, 46, ["L 7 6,4 6,42"]],
	"Z2": ["three strokes", "Z2", "more than one", "d", "k", 80, 30, ["L 6 10,4 10,26", "L 6 40,4 40,26", "L 6 70,4 70,26"]],
	"D54": ["legs walking", "D54", "go, come", "d", "r", 66, 52, ["L 8 4,47 18,46 38,5 58,46 46,47"]],
	"Y1": ["roll of papyrus", "Y1", "writing; a thought", "d", "w", 100, 30, ["F 3,14 97,14 97,28 3,28", "O 50,11 9,6", "L 4 38,3 46,12", "L 4 62,3 54,12"]],
	"N25": ["hills", "xAst", "ḫꜣst, the desert, a foreign land", "d", "r", 100, 44, ["S 3,42c 3,10c 10,3 18,10 26,26 34,28 42,12 50,4 58,12 66,28 74,26 82,10 90,3 97,10c 97,42c"]],
	"N8": ["sun with rays", "N8", "light, shine", "d", "y", 60, 88, ["R 6 30,23 19,19", "L 6 20,43 8,85", "L 6 30,45 30,85", "L 6 40,43 52,85"]],
	"H8": ["egg", "H8", "a goddess; a woman's name", "d", "w", 30, 44, ["S 8,4 20,6 27,24 24,40 12,40 4,22"]],
	"E16": ["jackal on a shrine", "E16", "inpw, Anubis", "d", "k", 100, 100, ["F 16,62 84,62 84,98 16,98", "-F 42,76 58,76 58,98 42,98", "F 10,54 90,54 90,62 10,62", "S 22,54c 24,44 38,42 46,37 70,37 84,41 88,54c", "S 40,44 32,31 16,31 4,27c 16,20 27,18 29,5c 35,15 40,5c 45,22 48,38", "C 5 86,46 94,60 96,90"]],
	"O24": ["pyramid", "O24", "a pyramid", "d", "y", 60, 100, ["F 30,3 54,84 6,84", "F 2,88 58,88 58,98 2,98"]],
	"O25": ["obelisk", "O25", "an obelisk", "d", "r", 30, 100, ["F 15,2 22,16 24,86 6,86 8,16", "F 2,90 28,90 28,98 2,98"]],
	"I12": ["cobra reared up", "I12", "a goddess; a snake", "d", "y", 70, 100, ["S 14,10 26,4 38,10 35,30 27,60 17,79 8,70 13,40", "O 15,8 9,5", "C 7 14,79 30,89 56,81 66,95"]],
	"X4": ["long loaf", "X4", "bread, food", "d", "y", 100, 28, ["S 14,3c 86,3c 97,14 86,25c 14,25c 3,14", "-F 50,6 57,14 50,22 43,14"]],
	"W22": ["beer jug", "W22", "beer; a pot", "d", "r", 34, 56, ["S 8,10c 26,10c 28,14 32,26 30,42 24,54c 10,54c 4,42 2,26 6,14", "L 5 5,5 29,5"]],
	"F1": ["head of an ox", "F1", "cattle", "d", "r", 62, 56, ["S 14,30 30,22 46,24 54,34 48,50 34,52 20,50 6,46 4,40c", "C 5 30,24 22,14 10,4", "C 5 40,22 48,12 58,4", "L 4 50,30 60,26"]],
	"H1": ["head of a duck", "H1", "fowl", "d", "y", 60, 60, ["C 9 37,57 37,40 46,27 44,13 35,7", "O 34,12 10,8", "F 26,8 2,16 4,20 26,18"]],

	# Numerals.
	"V20": ["hobble for cattle", "10", "ten", "n", "k", 30, 36, ["C 7 5,34c 5,14c 8,5 15,3 22,5 25,14c 25,34c"]],
	"V1": ["coil of rope", "100", "a hundred", "n", "k", 34, 60, ["C 6 22,58 14,40 8,26 12,10 22,5 30,12 26,22 19,20"]],
	"M12": ["lotus", "1000", "ḫꜣ, a thousand", "n", "g", 40, 100, ["L 5 20,28 20,86", "S 6,6 20,2 34,6c 25,14c 34,21c 20,28 6,22", "S 8,98c 10,88 20,84 30,88 32,98c", "L 4 12,78 20,86 28,78"]],
}

## How each paint is mixed: the colours the Egyptians had (blue frit, green
## frit, red and yellow ochre, soot black, gypsum white), faded by the years.
const PAINTS := {
	"b": Color(0.16, 0.42, 0.56), "g": Color(0.26, 0.48, 0.36), "r": Color(0.62, 0.24, 0.14),
	"y": Color(0.82, 0.62, 0.22), "k": Color(0.12, 0.1, 0.09), "w": Color(0.9, 0.87, 0.78),
}

## The order they are shown in on the chart (tools/glyph_sheets.gd), group by group.
const GROUPS := [["The alphabet: one consonant each", "1"], ["Two and three consonants, and whole words", "2w"], ["Determinatives", "d"], ["Numerals", "n"]]


## The sign a name in the Manuel de Codage stands for ("nfr" is F35), or the
## code itself if that is what was given; "" if it is neither.
static func code_of(name: String) -> String:
	if SIGNS.has(name):
		return name
	if _names.is_empty():
		for code: String in SIGNS:
			var typed: String = SIGNS[code][1]
			if typed != "" and not _names.has(typed):
				_names[typed] = code
		# (other names the same signs go by)
		for other: Array in [["sbA", "N14"], ["wDA", "U28"], ["rw", "E23"], ["l", "E23"], ["o", "V4"], ["nsw", "M23"], ["Hr", "D2"], ["1", "Z1"], ["xA", "M12"]]:
			_names[other[0]] = other[1]
	return _names.get(name, "")


static var _names := {}
