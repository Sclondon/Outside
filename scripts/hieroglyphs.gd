class_name Hieroglyphs
## Writing in hieroglyphs: text goes in, and what comes out is which signs
## stand where (`write`), and a picture of them to carve into stone (`texture`,
## which `Inscription` uses). `read` gives back in plain words what a text says,
## for the game to show as its translation.
##
## What can be written (`write("...")`):
##
## - Plain English, or anything in Latin letters. A word the dictionary below
##   has (king, god, life, sun, water, house, gold, Anubis...) is written as the
##   Egyptians wrote it, determinative and all. Any other is spelled out sound
##   by sound with the alphabet, the way a name is in a museum shop: sh, ch, kh,
##   th, ph and qu are one sound each, a doubled letter is written once, a
##   silent final e is left out, and "the", "a" and "an" are not written (there
##   were no such words). Numbers in figures are written as numerals.
## - `<Tut>`: a king's name, in a cartouche (the ring of rope round it).
##   `[Name]`: a name in a serekh (the palace front older kings' names stand in).
##   `(Name)`: somebody's name, with the seated man after it that marks one.
## - `{...}`: signs given outright, in the Manuel de Codage: Gardiner numbers
##   (G17) or the letters and names in `HieroglyphSigns` (m, anx, nfr),
##   with `-` or a space between one square and the next, `:` to put one sign
##   over another and `*` to put them side by side: `{Htp:t*p}`. After a `|`
##   comes what it means, for `read`: `{anx-DA-s|life, prosperity, health}`.
##   A text that is nothing but Gardiner numbers needs no braces.
## - `@name`: one of the texts in `InscriptionTexts`.
## - A new line starts a new line of writing (`\n`, typed as that or as a real one).
##
## How it is set out. Egyptian is not strung out like letters: signs are packed
## into squares (quadrats), flat ones stacked, small ones tucked together, tall
## ones standing alone, and the squares follow each other in rows or in
## columns. The signs face the way the reading starts from: left, here, unless
## `rtl` is asked for, which is the way the Egyptians liked best. Lines can be
## ruled between the rows or columns. All of it is worked out from the text
## alone: the same text is always the same writing.
##
## A layout is a Dictionary:
##     source    the text it was made from
##     size      how wide and tall it is, in hundredths of a square
##     signs     [code, x, y, width, height] for each, from the top left
##     frames    [kind, x, y, width, height]: rules, cartouches, serekhs
##     lines     how many rows (or columns) it took
##     columns, rtl   as asked for
##     says, reading  how an Egyptologist would write it out, and what it means

## Between signs in a square, between squares, and the extra between words.
const GAP_IN := 8.0
const GAP := 10.0
const WORD_GAP := 10.0
## How thick a ruled line is, and how far the writing stays from it.
const RULE := 5.0
const RULE_MARGIN := 9.0
## How much smaller the signs in a cartouche or serekh are.
const FRAMED := 0.78
## How many dots of the picture a square of writing gets, and how many dots
## beyond the edge of a sign its picture still knows how far off the edge is.
const DOTS := 64
const REACH := 4.0
const PAD := 6
## The biggest picture made (dots along one side, and in all).
const MAX_SIDE := 2048
const MAX_AREA := 2048 * 512

## English words as Egyptian wrote them: how it is said, and the signs.
const WORDS := {
	"king": ["nsw", "sw*t:n"], "pharaoh": ["pr-ꜥꜣ", "pr:aA"], "god": ["nṯr", "nTr-Z1"], "gods": ["nṯrw", "nTr-nTr-nTr"],
	"goddess": ["nṯrt", "nTr-t:r-I12"], "life": ["ꜥnḫ", "anx-n:x"], "live": ["ꜥnḫ", "anx-n:x"], "lives": ["ꜥnḫ", "anx-n:x"], "living": ["ꜥnḫ", "anx-n:x"],
	"sun": ["rꜥ", "r:a-ra:Z1"], "ra": ["rꜥ", "ra:Z1-A40"], "re": ["rꜥ", "ra:Z1-A40"], "day": ["hrw", "h:r-w-ra:Z1"],
	"water": ["mw", "mw"], "river": ["itrw", "i-t:r-w-mw"], "nile": ["ḥꜥpy", "H-a:p-i*i-mw"], "house": ["pr", "pr:Z1"],
	"gold": ["nbw", "nbw:Z2"], "death": ["mwt", "m-t-A14"], "die": ["mwt", "m-t-A14"], "dies": ["mwt", "m-t-A14"], "dead": ["mwt", "m-t-A14"],
	"anubis": ["inpw", "i-n:p-w-E16"], "osiris": ["wsir", "st:ir-A40"], "horus": ["ḥr", "G5-A40"], "isis": ["ꜣst", "st*t:H8-B1"],
	"thoth": ["ḏḥwty", "G26-t:y-A40"], "amun": ["imn", "i-mn:n-A40"], "amen": ["imn", "i-mn:n-A40"], "amon": ["imn", "i-mn:n-A40"],
	"ptah": ["ptḥ", "p:t-H-A40"], "aten": ["itn", "i-t:n-ra"], "seth": ["stẖ", "s-t:X-A40"], "sobek": ["sbk", "s-b-k-A40"],
	"nut": ["nwt", "nw:t-pt"], "maat": ["mꜣꜥt", "mAa:a:t-B1"], "truth": ["mꜣꜥt", "mAa:a:t-Y1"], "true": ["mꜣꜥ", "mAa:a-Y1"],
	"man": ["z", "z:Z1-A1"], "woman": ["zt", "z:t-B1"], "people": ["rmṯ", "r:T-A1*B1:Z2"], "men": ["rmṯ", "r:T-A1*B1:Z2"],
	"son": ["sꜣ", "sA-Z1"], "daughter": ["sꜣt", "sA-t-B1"], "father": ["it", "i-t:f-A1"],
	"lord": ["nb", "nb"], "lady": ["nbt", "nb:t"], "all": ["nb", "nb"], "every": ["nb", "nb"], "any": ["nb", "nb"],
	"great": ["ꜥꜣ", "aA:a-A-Y1"], "good": ["nfr", "nfr-f:r"], "beautiful": ["nfr", "nfr-f:r"], "beauty": ["nfrw", "nfr-f:r-w"],
	"heart": ["ib", "ib:Z1"], "name": ["rn", "r:n"], "sky": ["pt", "p*t:pt"], "heaven": ["pt", "p*t:pt"],
	"earth": ["tꜣ", "tA:Z1"], "land": ["tꜣ", "tA:Z1"], "star": ["sbꜣ", "s-b-A-sbA"], "stars": ["sbꜣw", "s-b-A-sbA-Z2"],
	"door": ["ꜥꜣ", "aA:O31"], "gate": ["ꜥꜣ", "aA:O31"], "tomb": ["is", "i-s-pr"], "city": ["niwt", "niwt:t*Z1"], "town": ["niwt", "niwt:t*Z1"],
	"eye": ["irt", "ir:t*Z1"], "mouth": ["r", "r:Z1"], "hand": ["ḏrt", "d:t*Z1"], "face": ["ḥr", "Hr:Z1"],
	"bread": ["t", "t:X4"], "beer": ["ḥnqt", "H-n:q-t*W22"], "light": ["sšp", "s-S:p-N8"], "fire": ["ḫt", "x:t-Q7"], "flame": ["ḫt", "x:t-Q7"],
	"open": ["wn", "w-n:O31"], "opens": ["wn", "w-n:O31"], "go": ["šm", "S-m-D54"], "goes": ["šm", "S-m-D54"], "walk": ["šm", "S-m-D54"], "walks": ["šm", "S-m-D54"],
	"come": ["ii", "i*i-D54"], "comes": ["ii", "i*i-D54"], "enter": ["ꜥq", "a:q-D54"], "enters": ["ꜥq", "a:q-D54"],
	"follow": ["šms", "S-m-s-D54"], "follows": ["šms", "S-m-s-D54"], "see": ["mꜣꜣ", "m-A-A-ir"], "sees": ["mꜣꜣ", "m-A-A-ir"],
	"hear": ["sḏm", "s-D-m-A2"], "hears": ["sḏm", "s-D-m-A2"], "say": ["ḏd", "D:d"], "says": ["ḏd", "D:d"], "speak": ["ḏd", "D:d"], "speaks": ["ḏd", "D:d"],
	"words": ["mdw", "mdw-Z2"], "give": ["di", "di"], "gives": ["di", "di"], "given": ["di", "di"],
	"love": ["mri", "mr:r-i-A2"], "loves": ["mri", "mr:r-i-A2"], "beloved": ["mry", "mr-i*i"],
	"forever": ["ḏt", "D:t:tA"], "eternity": ["ḏt", "D:t:tA"], "eternal": ["ḏt", "D:t:tA"],
	"power": ["wꜣs", "wAs"], "health": ["snb", "s-n:b-Y1"], "peace": ["ḥtp", "Htp:t*p"], "offering": ["ḥtp", "Htp:t*p"], "rest": ["ḥtp", "Htp:t*p"],
	"scarab": ["ḫprr", "xpr:r"], "become": ["ḫpr", "xpr:r"], "becomes": ["ḫpr", "xpr:r"], "book": ["mḏꜣt", "m-DA-A-t:Y1"], "writing": ["mḏꜣt", "m-DA-A-t:Y1"],
	"in": ["m", "m"], "of": ["n", "n"], "to": ["n", "n"], "for": ["n", "n"], "and": ["ḥnꜥ", "H-n:a"], "with": ["ḥnꜥ", "H-n:a"],
	"this": ["pn", "p:n"], "on": ["ḥr", "Hr"], "upon": ["ḥr", "Hr"], "under": ["ẖr", "X:r"], "like": ["mi", "mi"], "as": ["mi", "mi"],
	"i": ["ink", "i-n:k-A1"], "he": ["sw", "sw-w"], "him": ["sw", "sw-w"], "you": ["ṯw", "T-w"], "who": ["nty", "n:t*y"], "which": ["nty", "n:t*y"],
	"desert": ["ḫꜣst", "xAst:t*Z1"], "mountain": ["ḏw", "Dw:Z1"], "horizon": ["ꜣḫt", "Axt:t*pr"],
	"pyramid": ["mr", "Ab-r-O24"], "obelisk": ["tḫn", "t:x:n-O25"], "mummy": ["sꜥḥ", "s-a:H-A53"], "cat": ["miw", "mi-i-w"],
	"cobra": ["iꜥrt", "i-a:r:t-I12"], "snake": ["ḥfꜣw", "H-f-A-w-I12"], "serpent": ["ḥfꜣw", "H-f-A-w-I12"],
	"bird": ["ꜣpd", "A-p:d-sA"], "ox": ["kꜣ", "kA:Z1-F1"], "bull": ["kꜣ", "kA:Z1-F1"], "spirit": ["kꜣ", "kA:Z1"], "soul": ["kꜣ", "kA:Z1"],
	"way": ["wꜣt", "w-A-t:D54"], "road": ["wꜣt", "w-A-t:D54"], "path": ["wꜣt", "w-A-t:D54"],
	"enemy": ["ḫfty", "x:f:t-y-A14"], "beware": ["sꜣw", "s-A-w-A2"], "fear": ["snḏ", "s-n:D-A2"], "silence": ["gr", "g:r-A2"], "silent": ["gr", "g:r-A2"],
	"egypt": ["kmt", "k-m-t:niwt"], "thousand": ["ḫꜣ", "1000"], "hundred": ["št", "100"], "ten": ["mḏw", "10"],
	"one": ["wꜥ", "Z1"], "two": ["snwy", "Z1*Z1"], "three": ["ḫmtw", "Z1*Z1*Z1"], "four": ["fdw", "Z1*Z1:Z1*Z1"],
}

## Kings' names, as they stand in their cartouches.
const KINGS := {
	"tut": ["twt-ꜥnḫ-imn", "i-mn:n-t-w-t-anx"], "tutankhamun": ["twt-ꜥnḫ-imn", "i-mn:n-t-w-t-anx"], "tutankhamen": ["twt-ꜥnḫ-imn", "i-mn:n-t-w-t-anx"],
	"nebkheperure": ["nb-ḫprw-rꜥ", "ra-xpr-Z2:nb"], "khufu": ["ḫwfw", "x-w-f-w"], "cheops": ["ḫwfw", "x-w-f-w"], "khafre": ["ḫꜥ.f-rꜥ", "ra-xa-f"],
	"menkaure": ["mn-kꜣw-rꜥ", "ra-mn-kA-kA-kA"], "ramesses": ["rꜥ-ms-sw", "ra-ms-s-sw"], "ramses": ["rꜥ-ms-sw", "ra-ms-s-sw"],
	"thutmose": ["ḏḥwty-ms", "G26-ms-s"], "amenhotep": ["imn-ḥtp", "i-mn:n-Htp:t*p"], "sneferu": ["snfrw", "s-nfr-f:r-w"],
	"teti": ["tti", "t:t-i"], "pepi": ["ppy", "p:p-i*i"], "cleopatra": ["qliwpꜣdrꜣt", "q-l-i-wA-p-A-d:r-A-t:H8"], "ptolemy": ["ptwlmys", "p:t-wA-l-m-i*i-s"],
}

## One sound each, for spelling out: the sounds of two letters first.
const PAIRS := {"sh": ["N37"], "ch": ["V13"], "kh": ["Aa1"], "th": ["V13"], "ph": ["I9"], "ck": ["V31"], "qu": ["N29", "G43"],
	"ee": ["M17", "M17"], "oo": ["G43"], "ou": ["G43"], "ay": ["M17", "M17"], "ai": ["M17", "M17"], "ey": ["M17", "M17"], "ea": ["M17"], "ie": ["M17"]}
const LETTERS := {"a": ["G1"], "b": ["D58"], "d": ["D46"], "e": ["M17"], "f": ["I9"], "g": ["W11"], "h": ["O4"], "i": ["M17"], "j": ["I10"],
	"k": ["V31"], "l": ["E23"], "m": ["G17"], "n": ["N35"], "o": ["V4"], "p": ["Q3"], "q": ["N29"], "r": ["D21"], "s": ["S29"], "t": ["X1"],
	"u": ["G43"], "v": ["I9"], "w": ["G43"], "x": ["V31", "S29"], "y": ["M17", "M17"], "z": ["O34"]}
const SKIPPED: Array[String] = ["the", "a", "an"]

static var _outlines := {}
static var _cells := {}
static var _sized := {}
static var _textures := {}
static var _code_form: RegEx


## Sets a text out in hieroglyphs. `options`:
##     columns   true for columns read downwards, not rows (false)
##     rtl       true to read from the right, the signs facing right (false)
##     wrap      how long a row (or how tall a column) may be, in squares (0: one line)
##     limit     how many rows or columns there is room for (0: as many as it takes)
##     fill      true to go on repeating the text until `limit` lines are full (false)
##     rules     true for ruled lines between the rows or columns (true)
static func write(text: String, options := {}) -> Dictionary:
	var parsed := _parse(text)
	var layout := _set_out(parsed["words"], options)
	layout["source"] = text
	layout["says"] = parsed["says"]
	layout["reading"] = parsed["reading"]
	layout["unknown"] = parsed["unknown"]
	return layout


## What a text says, in plain words: `text` is what was given to `write`, or a
## layout that `write` made.
static func read(text: Variant) -> String:
	if text is Dictionary:
		return (text as Dictionary).get("reading", "")
	return _parse(String(text))["reading"]


## How an Egyptologist would write a text out in letters (ḥtp di nsw...).
static func says(text: String) -> String:
	return _parse(text)["says"]


## The signs a text is written with, by their Gardiner numbers, a square at a
## time: for looking at what `write` has made of something.
static func spelled(text: String) -> String:
	var out := PackedStringArray()
	for word: Dictionary in _parse(text)["words"]:
		var squares := PackedStringArray()
		for group: Array in word["groups"]:
			var rows := PackedStringArray()
			for row: Array in group:
				rows.append("*".join(PackedStringArray(row)))
			squares.append(":".join(rows))
		var whole := "-".join(squares)
		out.append({"cartouche": "<%s>", "serekh": "[%s]"}.get(word["frame"], "%s") % whole)
	return " ".join(out)


# ---- From text to words, each a list of squares of signs. ----

# What a text is made of: {words, reading, says, unknown}. A word is
# {groups, frame, starts_line}; a group (a square) is rows of sign codes.
static func _parse(text: String) -> Dictionary:
	var gloss := ""
	var written_out := ""
	if text.begins_with("@"):
		var named: Dictionary = InscriptionTexts.TEXTS.get(text.substr(1).strip_edges(), {})
		if named.is_empty():
			return {"words": [], "reading": "", "says": "", "unknown": [text]}
		text = named["write"]
		gloss = named["means"]
		written_out = named["says"]
	text = text.replace("\\n", "\n")
	if _code_form == null:
		_code_form = RegEx.new()
		_code_form.compile("^(Aa|[A-Z])[0-9]+[A-Z]?$")
	var words: Array = []
	var reading := PackedStringArray()
	var said := PackedStringArray()
	var unknown: Array = []
	# (a text that is all Gardiner numbers is signs given outright)
	var direct := _all_codes(text)
	var whole_direct := direct
	var frame := ""
	var framed: Dictionary = {}
	var person := false
	var starts_line := false
	var i := 0
	var count := text.length()
	while i < count:
		var c := text[i]
		if c == "\n":
			starts_line = true
			reading.append("\n")
			i += 1
		elif c == " " or c == "\t":
			i += 1
		elif c == "{":
			direct = true
			i += 1
		elif c == "}":
			direct = whole_direct
			i += 1
		elif c == "|" and direct:
			# (what the signs mean, up to the closing brace)
			var end := text.find("}", i)
			if end < 0:
				end = count
			reading.append(text.substr(i + 1, end - i - 1).strip_edges())
			i = end
		elif c == "<" or c == "[":
			frame = "cartouche" if c == "<" else "serekh"
			framed = {"groups": [], "frame": frame, "starts_line": starts_line}
			starts_line = false
			i += 1
		elif (c == ">" or c == "]") and frame != "":
			if not framed["groups"].is_empty():
				words.append(framed)
			frame = ""
			i += 1
		elif c == "(" or c == ")":
			person = c == "("
			i += 1
		else:
			var end := i
			while end < count and not (text[end] in " \t\n{}<>[]()" or (direct and text[end] == "|")):
				end += 1
			var word := text.substr(i, end - i)
			i = end
			var groups: Array = []
			var sound := ""
			if direct:
				groups = _squares(word, unknown)
				sound = _sounds(groups)
			elif _code_form.search(word) != null and HieroglyphSigns.SIGNS.has(word):
				# (a Gardiner number among the English: that sign)
				groups = [[[word]]]
				sound = _sounds(groups)
			else:
				reading.append(word)
				var made := _english(word, frame != "", unknown)
				groups = made[0]
				sound = made[1]
				if person and i < count and text[i] == ")" and not groups.is_empty():
					groups.append([["A1"]])
			if groups.is_empty():
				continue
			said.append(sound)
			if frame != "":
				framed["groups"].append_array(groups)
			else:
				words.append({"groups": groups, "frame": "", "starts_line": starts_line})
				starts_line = false
	if frame != "" and not framed["groups"].is_empty():
		words.append(framed)
	var plain := " ".join(reading).replace(" \n ", "\n").replace("\n ", "\n").replace(" \n", "\n")
	if gloss != "":
		plain = gloss
	elif whole_direct or plain.strip_edges() == "":
		plain = "[%s]" % " ".join(said) if not said.is_empty() else ""
	return {"words": words, "reading": plain, "says": written_out if written_out != "" else " ".join(said), "unknown": unknown}


static func _all_codes(text: String) -> bool:
	var any := false
	for token: String in text.replace("\\n", " ").replace("\n", " ").replace("-", " ").replace(":", " ").replace("*", " ").replace("<", " ").replace(">", " ").split(" ", false):
		if _code_form.search(token) == null or not HieroglyphSigns.SIGNS.has(token):
			return false
		any = true
	return any


# Signs given outright (`Htp:t*p-nb`), as squares.
static func _squares(typed: String, unknown: Array) -> Array:
	var groups: Array = []
	for square: String in typed.split("-", false):
		var rows: Array = []
		for line: String in square.split(":", false):
			var row: Array = []
			for item: String in line.split("*", false):
				var code := HieroglyphSigns.code_of(item)
				if code == "" and item.is_valid_int():
					for group: Array in _number(int(item)):
						groups.append(group)
				elif code == "":
					unknown.append(item)
				else:
					row.append(code)
			if not row.is_empty():
				rows.append(row)
		if not rows.is_empty():
			groups.append(rows)
	return groups


# The sounds of some squares, written out.
static func _sounds(groups: Array) -> String:
	var out := ""
	for group: Array in groups:
		for row: Array in group:
			for code: String in row:
				var sign: Array = HieroglyphSigns.SIGNS[code]
				if sign[3] in ["1", "2", "w"]:
					out += String(sign[2]).get_slice(",", 0).get_slice(";", 0)
	return out


# An English word: [its squares, how it is said].
static func _english(word: String, royal: bool, unknown: Array) -> Array:
	var letters := ""
	for c in word.to_lower():
		if (c >= "a" and c <= "z") or (c >= "0" and c <= "9"):
			letters += c
	if letters == "" or letters in SKIPPED:
		return [[], ""]
	if letters.is_valid_int():
		return [_number(int(letters)), letters]
	if royal and KINGS.has(letters):
		return [_squares(KINGS[letters][1], unknown), KINGS[letters][0]]
	if WORDS.has(letters):
		return [_squares(WORDS[letters][1], unknown), WORDS[letters][0]]
	# (more than one of something the dictionary has: the word, and three strokes)
	if letters.ends_with("s") and WORDS.has(letters.left(-1)):
		var groups := _squares(WORDS[letters.left(-1)][1], unknown)
		groups.append([["Z2"]])
		return [groups, WORDS[letters.left(-1)][0] + "w"]
	var codes := _spell(letters)
	return [_pack(codes), _sounds([[codes]])]


## Spells a word out sound by sound: the Gardiner numbers of its signs.
static func _spell(letters: String) -> Array:
	var codes: Array = []
	var vowels := 0
	for c in letters:
		if c in "aeiouy":
			vowels += 1
	var i := 0
	var count := letters.length()
	while i < count:
		var c := letters[i]
		var two := letters.substr(i, 2)
		if PAIRS.has(two):
			codes.append_array(PAIRS[two])
			i += 2
			continue
		# (a doubled letter is one sound)
		if i + 1 < count and letters[i + 1] == c and not c in "aeiou":
			i += 1
			continue
		if c == "e" and i == count - 1 and vowels > 1 and i > 0 and not letters[i - 1] in "aeiou":
			break
		if c == "c":
			codes.append("S29" if i + 1 < count and letters[i + 1] in "eiy" else "V31")
		elif LETTERS.has(c):
			codes.append_array(LETTERS[c])
		i += 1
	return codes


# A number in numerals: so many thousands, hundreds, tens and ones, each kind in a square of its own.
static func _number(value: int) -> Array:
	var groups: Array = []
	value = clampi(value, 0, 9999)
	for kind: Array in [[1000, "M12"], [100, "V1"], [10, "V20"], [1, "Z1"]]:
		var many: int = (value / int(kind[0])) % 10
		if many == 0:
			continue
		var per_row := 3 if many <= 6 else (many + 1) / 2
		var rows: Array = []
		while many > 0:
			var row: Array = []
			for k in mini(per_row, many):
				row.append(kind[1])
			many -= row.size()
			rows.append(row)
		groups.append(rows)
	return groups


# Packs a run of signs into squares, as a scribe would: flat signs one over
# another, small ones side by side or over each other, a pair of thin tall
# ones together, and the big ones each alone.
static func _pack(codes: Array) -> Array:
	var groups: Array = []
	var rows: Array = []
	var high := 0.0
	for code: String in codes:
		var sign: Array = HieroglyphSigns.SIGNS[code]
		var wide: float = sign[5]
		var tall: float = sign[6]
		var placed := false
		if not rows.is_empty():
			var last: Array = rows[rows.size() - 1]
			var last_wide := -GAP_IN
			var last_tall := 0.0
			for other: String in last:
				last_wide += float(HieroglyphSigns.SIGNS[other][5]) + GAP_IN
				last_tall = maxf(last_tall, HieroglyphSigns.SIGNS[other][6])
			if tall >= 80.0:
				# (a tall thin one stands beside another, and beside nothing else)
				if rows.size() == 1 and last_tall >= 80.0 and last_wide + GAP_IN + wide <= 84.0:
					last.append(code)
					placed = true
			elif last_tall < 80.0:
				# (a small one goes beside the last small one once there is something over them; otherwise under it)
				if wide <= 50.0 and last_wide <= 50.0 and last_wide + GAP_IN + wide <= 100.0 and (rows.size() > 1 or high + GAP_IN + tall > 104.0):
					last.append(code)
					high = high - last_tall + maxf(last_tall, tall)
					placed = true
				elif high + GAP_IN + tall <= 104.0:
					rows.append([code])
					high += GAP_IN + tall
					placed = true
		if not placed:
			if not rows.is_empty():
				groups.append(rows)
			rows = [[code]]
			high = tall
	if not rows.is_empty():
		groups.append(rows)
	return groups


# ---- From words to where each sign stands. ----

# How big a square is, and where its signs stand in it: {size, signs: [code, x, y, w, h]}.
static func _square(group: Array, shrink := 1.0) -> Dictionary:
	var wide := 0.0
	var tall := -GAP_IN
	var sizes: Array = []
	for row: Array in group:
		var row_wide := -GAP_IN
		var row_tall := 0.0
		for code: String in row:
			row_wide += float(HieroglyphSigns.SIGNS[code][5]) + GAP_IN
			row_tall = maxf(row_tall, HieroglyphSigns.SIGNS[code][6])
		sizes.append(Vector2(row_wide, row_tall))
		wide = maxf(wide, row_wide)
		tall += row_tall + GAP_IN
	var scale := minf(1.0, minf(100.0 / wide, 100.0 / tall)) * shrink
	var signs: Array = []
	var y := 0.0
	for r in group.size():
		var x: float = (wide - sizes[r].x) * 0.5
		for code: String in group[r]:
			var sign: Array = HieroglyphSigns.SIGNS[code]
			signs.append([code, x * scale, (y + (sizes[r].y - float(sign[6])) * 0.5) * scale, float(sign[5]) * scale, float(sign[6]) * scale])
			x += float(sign[5]) + GAP_IN
		y += sizes[r].y + GAP_IN
	return {"size": Vector2(wide, tall) * scale, "signs": signs}


# Sets words out in rows or columns. It works along a line and across it: for
# rows, along is x and across is y; for columns they change places at the end.
static func _set_out(words: Array, options: Dictionary) -> Dictionary:
	var columns: bool = options.get("columns", false)
	var rules: bool = options.get("rules", true)
	var wrap: float = float(options.get("wrap", 0.0)) * 100.0
	var limit: int = options.get("limit", 0)
	var fill: bool = options.get("fill", false) and limit > 0 and wrap > 0.0 and not words.is_empty()
	var margin := RULE_MARGIN if rules else 5.0
	var pitch := 100.0 + margin * 2.0 + (RULE if rules else 0.0)
	var signs: Array = []
	var frames: Array = []
	var line := 0
	var along := 0.0
	var longest := 0.0
	var index := 0
	var first := true
	while index < words.size() or fill:
		var word: Dictionary = words[index % words.size()]
		index += 1
		# The blocks of the word: things that are not broken across lines, each
		# {long, signs [code, along, across, w, h], frame}.
		var blocks: Array = []
		if word["frame"] != "":
			blocks.append(_framed(word, columns))
		else:
			blocks = _blocks(word["groups"], columns, 1.0)
		var word_long := -GAP
		for block: Dictionary in blocks:
			word_long += float(block["long"]) + GAP
		if word["starts_line"] and along > 0.0 and not (fill and index > words.size()):
			line += 1
			along = 0.0
		if not first and along > 0.0:
			along += WORD_GAP
			# (a word that would fit on a line is not broken across two)
			if wrap > 0.0 and along + word_long > wrap and word_long <= wrap:
				line += 1
				along = 0.0
		if fill and line >= limit:
			break
		first = false
		for block: Dictionary in blocks:
			if wrap > 0.0 and along > 0.0 and along + float(block["long"]) > wrap:
				line += 1
				along = 0.0
				if fill and line >= limit:
					break
			var across := line * pitch + (RULE if rules else 0.0) + margin
			for sign: Array in block["signs"]:
				signs.append([sign[0], along + float(sign[1]), across + float(sign[2]), sign[3], sign[4], line])
			if block.has("frame"):
				var frame: Array = block["frame"]
				frames.append([frame[0], along + float(frame[1]), across + float(frame[2]), frame[3], frame[4]])
			along += float(block["long"]) + GAP
			longest = maxf(longest, along - GAP)
		if fill and line >= limit:
			break
	var lines := line + 1 if (along > 0.0 or line == 0) else line
	if fill:
		lines = limit
		longest = maxf(longest, wrap)
	var side := 6.0
	var deep := lines * pitch + (RULE if rules else 0.0)
	if rules:
		for n in lines + 1:
			frames.append(["rule", -side, n * pitch, longest + side * 2.0, RULE])
	var size := Vector2(longest + side * 2.0, deep)
	# Along and across become x and y: as they are for rows, changed over for columns.
	for sign: Array in signs:
		sign[1] = float(sign[1]) + side
		if columns:
			var swap: float = sign[1]
			sign[1] = sign[2]
			sign[2] = swap
		sign.resize(5)
	for frame: Array in frames:
		frame[1] = float(frame[1]) + side
		if columns:
			frame.assign([String(frame[0]) + "_v", frame[2], frame[1], frame[4], frame[3]])
	if columns:
		size = Vector2(size.y, size.x)
	return {"size": size, "signs": signs, "frames": frames, "lines": lines, "columns": columns, "rtl": options.get("rtl", false), "rules": rules}


# The squares of a word as blocks along the line. In a column, squares that
# will stand side by side across it are put together first.
static func _blocks(groups: Array, columns: bool, shrink: float) -> Array:
	var blocks: Array = []
	if not columns:
		for group: Array in groups:
			var square := _square(group, shrink)
			var size: Vector2 = square["size"]
			var placed: Array = []
			for sign: Array in square["signs"]:
				placed.append([sign[0], sign[1], float(sign[2]) + (100.0 * shrink - size.y) * 0.5, sign[3], sign[4]])
			blocks.append({"long": size.x, "signs": placed})
		return blocks
	var band: Array = []
	var band_wide := 0.0
	var squares: Array = []
	for group: Array in groups:
		squares.append(_square(group, shrink))
	squares.append({})
	for square: Dictionary in squares:
		var wide: float = square["size"].x if not square.is_empty() else INF
		if not band.is_empty() and band_wide + GAP_IN * shrink + wide > 100.0 * shrink:
			# (this band across the column is full: set it down)
			var tall := 0.0
			for held: Dictionary in band:
				tall = maxf(tall, held["size"].y)
			var x := (100.0 * shrink - band_wide) * 0.5
			var placed: Array = []
			for held: Dictionary in band:
				for sign: Array in held["signs"]:
					# (as [code, along, across, w, h]: along is down the column)
					placed.append([sign[0], float(sign[2]) + (tall - float(held["size"].y)) * 0.5, x + float(sign[1]), sign[3], sign[4]])
				x += float(held["size"].x) + GAP_IN * shrink
			blocks.append({"long": tall, "signs": placed})
			band = []
			band_wide = 0.0
		if not square.is_empty():
			band_wide += wide + (GAP_IN * shrink if not band.is_empty() else 0.0)
			band.append(square)
	return blocks


# A name in its cartouche or serekh, as one block.
static func _framed(word: Dictionary, columns: bool) -> Dictionary:
	var inner := _blocks(word["groups"], columns, FRAMED)
	var serekh: bool = word["frame"] == "serekh"
	# How far in the name starts, and how much room there is after it (for the
	# rope's knot, or the palace front under the name).
	var before := 9.0 if serekh else 13.0
	var after := 36.0 if serekh and columns else (9.0 if serekh else 21.0)
	var inset := (100.0 - 100.0 * FRAMED) * 0.5
	var signs: Array = []
	var along := before
	for block: Dictionary in inner:
		for sign: Array in block["signs"]:
			signs.append([sign[0], along + float(sign[1]), inset + float(sign[2]), sign[3], sign[4]])
		along += float(block["long"]) + GAP * FRAMED
	var long := along - GAP * FRAMED + after
	return {"long": long, "signs": signs, "frame": [word["frame"], 0.0, 0.0, long, 100.0]}


# ---- From outlines to a picture. ----

## The outline of a sign: [the shapes that are it, the shapes cut out of it],
## each a list of points, in the sign's own box.
static func outline(code: String) -> Array:
	if not _outlines.has(code):
		_outlines[code] = _drawn(HieroglyphSigns.SIGNS[code][7])
	return _outlines[code]


# Strokes (see HieroglyphSigns) as shapes: [filled, cut out].
static func _drawn(strokes: Array) -> Array:
	var filled: Array = []
	var cut: Array = []
	for stroke: String in strokes:
		var words := stroke.split(" ", false)
		var kind := words[0]
		var into := filled
		if kind.begins_with("-"):
			kind = kind.substr(1)
			into = cut
		var from := 1
		var width := 0.0
		if kind in ["L", "C", "P", "Q", "R"]:
			width = float(words[1])
			from = 2
		var points := PackedVector2Array()
		var corners := PackedByteArray()
		for k in range(from, words.size()):
			var word := words[k]
			corners.append(1 if word.ends_with("c") or kind in ["F", "L", "P"] else 0)
			var pair := word.trim_suffix("c").split(",")
			points.append(Vector2(float(pair[0]), float(pair[1])))
		if kind in ["O", "R"]:
			var middle := points[0]
			var radius := points[1]
			points = PackedVector2Array()
			for k in 20:
				points.append(middle + Vector2(cos(TAU * k / 20.0), sin(TAU * k / 20.0)) * radius)
		elif kind in ["S", "C", "Q"]:
			points = _curved(points, corners, kind != "C")
		if kind in ["F", "S", "O"]:
			if Geometry2D.is_polygon_clockwise(points):
				points.reverse()
			into.append(points)
		else:
			var closed := kind in ["P", "Q", "R"]
			if closed:
				points.append(points[0])
			into.append_array(Geometry2D.offset_polyline(points, width * 0.5, Geometry2D.JOIN_ROUND, Geometry2D.END_JOINED if closed else Geometry2D.END_ROUND))
	return [filled, cut]


# A curve through points; where one is a corner the curve turns sharply there.
static func _curved(points: PackedVector2Array, corners: PackedByteArray, closed: bool) -> PackedVector2Array:
	var out := PackedVector2Array()
	var count := points.size()
	var spans := count if closed else count - 1
	for i in spans:
		var j := (i + 1) % count
		var a := points[i]
		var b := points[j]
		var a_corner := corners[i] == 1 or (not closed and i == 0)
		var b_corner := corners[j] == 1 or (not closed and j == count - 1)
		var leave := (b - a) if a_corner else (b - points[(i - 1 + count) % count]) * 0.5
		var arrive := (b - a) if b_corner else (points[(j + 1) % count] - a) * 0.5
		var steps := 1 if a_corner and b_corner else 6
		for k in steps:
			var t := k / float(steps)
			var t2 := t * t
			var t3 := t2 * t
			out.append(a * (2.0 * t3 - 3.0 * t2 + 1.0) + leave * (t3 - 2.0 * t2 + t) + b * (-2.0 * t3 + 3.0 * t2) + arrive * (t3 - t2))
	if not closed:
		out.append(points[count - 1])
	return out


# The shapes a frame is made of, `wide` by `tall`.
static func _frame_outline(kind: String, wide: float, tall: float) -> Array:
	var upright := kind.ends_with("_v")
	var long := tall if upright else wide
	var strokes: Array = []
	var w := 5.0
	if kind.begins_with("cartouche"):
		# A loop of rope, and the knot across its end.
		var end := long - 8.0
		var r := 34.0
		var round := PackedStringArray()
		var middles: Array[Vector2] = [Vector2(end - r, 2.5 + r), Vector2(end - r, 97.5 - r), Vector2(2.5 + r, 97.5 - r), Vector2(2.5 + r, 2.5 + r)]
		for corner in 4:
			for k in 7:
				var turn := deg_to_rad(corner * 90.0 - 90.0 + k * 15.0)
				round.append(_pt(middles[corner].x + cos(turn) * r, middles[corner].y + sin(turn) * r, upright))
		strokes = ["P 5 " + " ".join(round), "L 6 %s %s" % [_pt(long - 3.0, 4.0, upright), _pt(long - 3.0, 96.0, upright)]]
	else:
		# A palace: its wall round the name, and its panelled front (under the name in a column, round it in a row).
		strokes = ["P 5 %s %s %s %s" % [_pt(2.5, 2.5, upright), _pt(long - 2.5, 2.5, upright), _pt(long - 2.5, 97.5, upright), _pt(2.5, 97.5, upright)]]
		if upright:
			strokes.append("L 4 %s %s" % [_pt(long - 31.0, 2.5, upright), _pt(long - 31.0, 97.5, upright)])
			for k in 5:
				strokes.append("L 4 %s %s" % [_pt(long - 26.0, 16.0 + k * 17.0, upright), _pt(long - 5.0, 16.0 + k * 17.0, upright)])
	return _drawn(strokes)


static func _pt(along: float, across: float, upright: bool, corner := false) -> String:
	return ("%.1f,%.1f" % ([across, along] if upright else [along, across])) + ("c" if corner else "")


# How far each dot of a picture `wide` by `tall` is inside the shapes (or
# outside them), as the alpha of an image in one colour: a half is the edge
# itself, more is inside, and it reaches 0 and 1 at `REACH` dots from the edge.
# The shapes are scaled by `scale` and moved by `shift` first.
static func _field(shapes: Array, scale: float, shift: Vector2, wide: int, tall: int, colour: Color) -> Image:
	# Every side of every shape, as (x0, y0, x1, y1), and whether it is of a shape cut out.
	var sides := PackedFloat32Array()
	var cuts := PackedByteArray()
	for which in 2:
		for shape: PackedVector2Array in shapes[which]:
			var count := shape.size()
			for i in count:
				var a := shape[i] * scale + shift
				var b := shape[(i + 1) % count] * scale + shift
				sides.append_array([a.x, a.y, b.x, b.y])
				cuts.append(which)
	var by_row := _sweep(sides, cuts, 0, wide, tall)
	var by_column := _sweep(sides, cuts, 1, tall, wide)
	var data := PackedByteArray()
	data.resize(wide * tall * 4)
	var r := int(colour.r8)
	var g := int(colour.g8)
	var b := int(colour.b8)
	var across: PackedFloat32Array = by_row[0]
	var down: PackedFloat32Array = by_column[0]
	var inside: PackedByteArray = by_row[1]
	var at := 0
	for y in tall:
		for x in wide:
			var h := across[y * wide + x]
			var v := down[x * tall + y]
			# (an edge that is `h` away sideways and `v` away up or down is this far off)
			var d := h * v / sqrt(h * h + v * v) if h < 99.0 and v < 99.0 else minf(h, v)
			var alpha := 0.5 + (d if inside[y * wide + x] == 1 else -d) / (REACH * 2.0)
			data[at] = r
			data[at + 1] = g
			data[at + 2] = b
			data[at + 3] = clampi(int(alpha * 255.0 + 0.5), 0, 255)
			at += 4
	return Image.create_from_data(wide, tall, false, Image.FORMAT_RGBA8, data)


# Along every line of dots (rows for `axis` 0, columns for 1): how far each dot
# is from the nearest place on that line where the shapes begin or end, and
# whether it is inside them. [distances, inside], line after line.
static func _sweep(sides: PackedFloat32Array, cuts: PackedByteArray, axis: int, long: int, lines: int) -> Array:
	var far := PackedFloat32Array()
	far.resize(long * lines)
	far.fill(100.0)
	var inside := PackedByteArray()
	inside.resize(long * lines)
	# Which sides cross each line.
	var crossing: Array = []
	crossing.resize(lines)
	var other := 1 - axis
	for s in cuts.size():
		var from := sides[s * 4 + other]
		var to := sides[s * 4 + 2 + other]
		if from == to:
			continue
		for n in range(maxi(ceili(minf(from, to) - 0.5), 0), mini(floori(maxf(from, to) - 0.5), lines - 1) + 1):
			if crossing[n] == null:
				crossing[n] = PackedInt32Array()
			crossing[n].append(s)
	var keys := PackedInt64Array()
	var edges := PackedFloat32Array()
	for n in lines:
		if crossing[n] == null:
			continue
		var level := n + 0.5
		keys.clear()
		for s: int in crossing[n]:
			var from := sides[s * 4 + other]
			var to := sides[s * 4 + 2 + other]
			if (from <= level) == (to <= level):
				continue
			var where := sides[s * 4 + axis] + (level - from) * (sides[s * 4 + 2 + axis] - sides[s * 4 + axis]) / (to - from)
			# (sorted by where it is; what it is rides along in the last bits)
			keys.append((int(where * 256.0) + 1048576) * 4 + cuts[s] * 2 + (1 if to > from else 0))
		keys.sort()
		# The places where the inside begins or ends: in any shape that is it, and in none cut out of it.
		edges.clear()
		var filled := 0
		var cut := 0
		var was := false
		for key in keys:
			var turn := 1 if key & 1 else -1
			if key & 2:
				cut += turn
			else:
				filled += turn
			var now := filled != 0 and cut == 0
			if now != was:
				edges.append(((key >> 2) - 1048576) / 256.0)
				was = now
		var count := edges.size()
		if count == 0:
			continue
		var next := 0
		var base := n * long
		var first := maxi(int(edges[0] - REACH - 1.0), 0)
		for k in range(first, mini(long, int(edges[count - 1] + REACH + 2.0))):
			var here := k + 0.5
			while next < count and edges[next] < here:
				next += 1
			var gap := 100.0
			if next > 0:
				gap = here - edges[next - 1]
			if next < count:
				gap = minf(gap, edges[next] - here)
			far[base + k] = gap
			inside[base + k] = next & 1
	return [far, inside]


## The picture of one sign, `DOTS` to the square, with `PAD` dots round it.
static func cell(code: String) -> Image:
	if not _cells.has(code):
		var sign: Array = HieroglyphSigns.SIGNS[code]
		var scale := DOTS / 100.0
		_cells[code] = _field(outline(code), scale, Vector2(PAD, PAD), ceili(float(sign[5]) * scale) + PAD * 2, ceili(float(sign[6]) * scale) + PAD * 2, HieroglyphSigns.PAINTS[sign[4]])
	return _cells[code]


## How many dots to the square a layout is drawn at: `DOTS`, or fewer if it is
## so big that its picture would be too large.
static func dots_for(layout: Dictionary) -> float:
	var size: Vector2 = layout["size"] / 100.0
	return minf(DOTS, minf(MAX_SIDE / maxf(size.x, size.y), sqrt(MAX_AREA / maxf(size.x * size.y, 0.01))))


## The picture of a layout, to carve by: in its alpha how far inside a sign
## each dot is (a half is the edge), and in its colour the paint of the sign
## there. It is made once and kept.
static func texture(layout: Dictionary) -> ImageTexture:
	var key := "%s|%s|%s|%s|%s" % [layout["source"], layout["size"], layout["columns"], layout["rtl"], layout["rules"]]
	if _textures.has(key):
		return _textures[key]
	var made := ImageTexture.create_from_image(picture(layout))
	_textures[key] = made
	return made


## Forgets the pictures made so far (they are made again when next wanted).
static func forget() -> void:
	_textures.clear()
	_sized.clear()


## The picture of a layout, as an image (see `texture`).
static func picture(layout: Dictionary) -> Image:
	var dots := dots_for(layout)
	var scale := dots / 100.0
	var size: Vector2 = layout["size"]
	var wide := maxi(ceili(size.x * scale), 4)
	var tall := maxi(ceili(size.y * scale), 4)
	var image := Image.create(wide, tall, false, Image.FORMAT_RGBA8)
	image.fill(Color(0.45, 0.4, 0.32, 0.0))
	# Under every sign, its own paint, so that the colour is right to the very edge of it.
	for sign: Array in layout["signs"]:
		var paint: Color = HieroglyphSigns.PAINTS[HieroglyphSigns.SIGNS[sign[0]][4]]
		image.fill_rect(Rect2i(int(float(sign[1]) * scale), int(float(sign[2]) * scale), ceili(float(sign[3]) * scale), ceili(float(sign[4]) * scale)), Color(paint, 0.0))
	for frame: Array in layout["frames"]:
		var kind: String = frame[0]
		if kind.begins_with("rule"):
			_rule(image, Rect2(Vector2(frame[1], frame[2]) * scale, Vector2(frame[3], frame[4]) * scale), HieroglyphSigns.PAINTS["b"])
			continue
		var key := "%s|%d|%d|%.3f" % [kind, int(frame[3]), int(frame[4]), scale]
		if not _sized.has(key):
			_sized[key] = _field(_frame_outline(kind, frame[3], frame[4]), scale, Vector2(PAD, PAD), ceili(float(frame[3]) * scale) + PAD * 2, ceili(float(frame[4]) * scale) + PAD * 2, HieroglyphSigns.PAINTS["k"])
		var drawn: Image = _sized[key]
		image.blend_rect(drawn, Rect2i(Vector2i.ZERO, drawn.get_size()), Vector2i(roundi(float(frame[1]) * scale) - PAD, roundi(float(frame[2]) * scale) - PAD))
	for sign: Array in layout["signs"]:
		var whole := cell(sign[0])
		# (how much smaller than its own picture it is here)
		var shrink := float(sign[3]) / float(HieroglyphSigns.SIGNS[sign[0]][5]) * scale * 100.0 / DOTS
		var drawn := whole
		if absf(shrink - 1.0) > 0.01:
			var to := Vector2i(maxi(roundi(whole.get_width() * shrink), 2), maxi(roundi(whole.get_height() * shrink), 2))
			var key := "%s|%d|%d" % [sign[0], to.x, to.y]
			if not _sized.has(key):
				var copy := whole.duplicate() as Image
				copy.resize(to.x, to.y, Image.INTERPOLATE_CUBIC if shrink < 0.6 else Image.INTERPOLATE_BILINEAR)
				_sized[key] = copy
			drawn = _sized[key]
		image.blend_rect(drawn, Rect2i(Vector2i.ZERO, drawn.get_size()), Vector2i(roundi(float(sign[1]) * scale - PAD * shrink), roundi(float(sign[2]) * scale - PAD * shrink)))
	if layout["rtl"]:
		image.flip_x()
	image.generate_mipmaps()
	return image


# A ruled line, as a sign is drawn: a half at its edges, more inside.
static func _rule(image: Image, where: Rect2, colour: Color) -> void:
	var upright := where.size.x < where.size.y
	var from := where.position.x if upright else where.position.y
	var to := where.end.x if upright else where.end.y
	for n in range(floori(from - REACH), ceili(to + REACH)):
		var inside := minf(n + 0.5 - from, to - n - 0.5)
		var alpha := clampf(0.5 + inside / (REACH * 2.0), 0.0, 1.0)
		if alpha <= 0.0:
			continue
		var strip := Rect2i(n, int(where.position.y), 1, ceili(where.size.y)) if upright else Rect2i(int(where.position.x), n, ceili(where.size.x), 1)
		image.fill_rect(strip.intersection(Rect2i(Vector2i.ZERO, image.get_size())), Color(colour, alpha))
