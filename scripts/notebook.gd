class_name Notebook
## What the game has written in the boy's field notebook: the Journal pages of
## the menu (scripts/menu.gd shows them; this only keeps them). Like Settings,
## it lasts across level changes, not across runs.
##
## To write in it, from anywhere:
##   Notebook.note("The door in the east wall will not move.")
##   Notebook.note("A plate in the floor. It gives when I stand on it.", "The long room")
##   Notebook.sketch("scarab", "On the lintel. 4 in. across.")
##   Notebook.find("A blue bead", "In the sand by the well.", "pot")
##   Notebook.task("Find a way into the pyramid", "way_in")   ...and later   Notebook.done("way_in")
##   Notebook.translation(signs, "An offering which the king gives...", "North wall")
##
## A sketch is the name of one of the drawings in NotebookInk.SKETCHES, a
## Texture2D, or a Callable(on: CanvasItem, rect: Rect2) that draws it. The
## signs of a translation are the same, or a String, which is written out as it
## is: so when there are real hieroglyphs to read, what reads them can hand over
## a picture of the signs, or a function that draws them, with what they say.
##
## Each of these returns the entry it made, a Dictionary, which may be changed
## afterwards (call `touched()` if it is). `unread` counts what has been written
## since the journal was last looked at: the notebook in the corner of the
## screen shows a mark while there is anything.

## The entries, oldest first. Each has "kind" (&"note", &"sketch", &"find",
## &"task" or &"translation"), "heading", "text", and what its kind needs:
## "sketch"; "signs" and "where"; "id" and "done"; "number".
static var entries: Array[Dictionary] = []
## How many have been written since the journal was last open.
static var unread := 0
## Goes up at every change, so that whatever shows the journal knows to draw it again.
static var version := 0

static var _finds := 0
static var _placeholders_in := false


## Writes a note: a paragraph in his hand, under a heading if one is given.
static func note(text: String, heading := "") -> Dictionary:
	return _add({"kind": &"note", "heading": heading, "text": text})


## Draws something, with a line or two under it.
static func sketch(what: Variant, caption := "", heading := "") -> Dictionary:
	return _add({"kind": &"sketch", "heading": heading, "text": caption, "sketch": what})


## Records a find, numbered as it comes, with a small drawing of it if there is one.
static func find(name: String, text := "", what: Variant = null) -> Dictionary:
	_finds += 1
	return _add({"kind": &"find", "heading": name, "text": text, "sketch": what, "number": _finds})


## Something to be done, with a box to tick. Give it an `id` to tick it by later.
static func task(text: String, id := "") -> Dictionary:
	return _add({"kind": &"task", "heading": "", "text": text, "id": id, "done": false})


## Ticks off the task of that id. True if there was one.
static func done(id: String) -> bool:
	for entry in entries:
		if entry["kind"] == &"task" and entry.get("id", "") == id and not entry["done"]:
			entry["done"] = true
			touched()
			return true
	return false


## An inscription and what it says: `signs` as they are on the wall (see the
## top of this file for what that may be), `meaning` in English, and where it was.
static func translation(signs: Variant, meaning: String, where := "") -> Dictionary:
	return _add({"kind": &"translation", "heading": where, "text": meaning, "signs": signs, "where": where})


## Whether there is already an entry with this text (so that the same thing is not written twice).
static func has(text: String) -> bool:
	for entry in entries:
		if entry["text"] == text:
			return true
	return false


## Call after changing an entry that is already in.
static func touched() -> void:
	version += 1


## The journal has been looked at.
static func read() -> void:
	if unread != 0:
		unread = 0
		version += 1


## Tears out every page.
static func clear() -> void:
	entries.clear()
	unread = 0
	_finds = 0
	version += 1


static func _add(entry: Dictionary) -> Dictionary:
	entries.append(entry)
	unread += 1
	version += 1
	return entry


## PLACEHOLDERS. A few entries so that the journal is not blank before the game
## writes anything of its own: they show what each kind of entry looks like and
## are not part of any story. Take the call to this out of GameMenu._ready (and
## this with it) once the levels write their own.
static func placeholders() -> void:
	if _placeholders_in:
		return
	_placeholders_in = true
	note("Came up from Cairo by the night train. Sand in everything. Father says I may keep this book so long as I write in it every day.", "Tuesday")
	task("Have a look at the big pyramid", "placeholder_pyramid")
	sketch("pyramid", "The dig from the camp. Two pyramids, the small one fallen in on the north side.")
	find("Beetle, blue glaze", "In the spoil by the well. 1 1/2 in. long, pierced end to end.", "scarab")
	translation("glyphs", "\"...given life, like the sun, for ever.\"  (so Father says: I can only read the sun)", "On a block by the path")
	# (they are part of the book as he was given it, not news)
	unread = 0
