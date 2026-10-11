extends RefCounted
## Not part of the game. Walks every control that can be seen under a node and
## measures the ones a finger is meant to land on: how big each is, how near
## the next, and how near the ends of the screen. Used by the pictures of the
## level editor (`tools/level_editor_shots.gd`) and by its check for a phone
## (`tools/editor_phone_test.gd`).

## The least a thing to touch may measure, each way; the least between two; and
## how far it must keep from the left and right ends, and from the bottom.
const LEAST := 88.0
const APART := 12.0
const ENDS := 48.0
const FOOT := 16.0
const TEXT := 26


## Everything under `from` that is on show and takes a touch: [control, its rectangle on the screen].
static func touchables(from: Node) -> Array:
	var found: Array = []
	_walk(from, found, Rect2(Vector2.ZERO, from.get_viewport().get_visible_rect().size))
	return found


static func _walk(node: Node, found: Array, clip: Rect2) -> void:
	for child: Node in node.get_children():
		var control := child as Control
		if control == null:
			_walk(child, found, clip)
			continue
		if not control.is_visible_in_tree():
			continue
		var within := clip
		if control.clip_contents or control is ScrollContainer:
			within = clip.intersection(control.get_global_rect())
		var takes := control is BaseButton or control is Slider or control is LineEdit or control is TextEdit or control.has_meta(&"touch")
		if takes and control.mouse_filter != Control.MOUSE_FILTER_IGNORE and not control.has_meta(&"not_touch"):
			var seen := control.get_global_rect().intersection(clip)
			# (what has been scrolled out of sight, or all but, is not there to be touched)
			if seen.size.x > 4.0 and seen.size.y > 4.0:
				found.append([control, control.get_global_rect(), seen])
		_walk(child, found, within)


## The size of the smallest writing on show under `from`.
static func smallest_text(from: Node) -> int:
	var least := 999
	for label: Node in from.find_children("*", "Control", true, false):
		var control := label as Control
		if not control.is_visible_in_tree():
			continue
		var words := ""
		if control is Label:
			words = (control as Label).text
		elif control is Button:
			words = (control as Button).text
		elif control is LineEdit:
			words = "x"
		elif control is TextEdit:
			words = "x"
		if words.strip_edges() == "":
			continue
		least = mini(least, control.get_theme_font_size(&"font_size"))
	return least


static func _name(control: Control) -> String:
	var words := ""
	if control is Button:
		words = (control as Button).text
	if words == "" and control.has_meta(&"word"):
		words = String(control.get_meta(&"word"))
	if words == "":
		words = control.get_class()
	return words.replace("\n", " ")


## Measures a state of the screen. Gives back {count, least (the smallest side of anything), smallest (the name and
## size of the thing with the shortest side: of the smallest of them, if several have it), area (how big that is),
## small (how many are under LEAST), close (how many pairs overlap or stand nearer than APART), edge (how many are in
## the margins), text (the smallest writing), lines (what is wrong, in words)}.
static func measure(from: Node, margins := true) -> Dictionary:
	var all := touchables(from)
	var screen := from.get_viewport().get_visible_rect().size
	var result := {"count": all.size(), "least": 9999.0, "area": 1.0e9, "smallest": "", "small": 0, "close": 0, "edge": 0, "text": smallest_text(from), "lines": []}
	for entry: Array in all:
		var control: Control = entry[0]
		var whole: Rect2 = entry[1]
		var side := minf(whole.size.x, whole.size.y)
		if side < result["least"] - 0.5 or (side < result["least"] + 0.5 and whole.get_area() < result["area"]):
			result["least"] = minf(side, result["least"])
			result["area"] = whole.get_area()
			result["smallest"] = "%s %dx%d" % [_name(control), int(whole.size.x), int(whole.size.y)]
		if whole.size.x < LEAST - 0.5 or whole.size.y < LEAST - 0.5:
			result["small"] += 1
			result["lines"].append("small: %s %dx%d" % [_name(control), int(whole.size.x), int(whole.size.y)])
		var seen: Rect2 = entry[2]
		if margins and (seen.position.x < ENDS - 0.5 or seen.end.x > screen.x - ENDS + 0.5 or seen.end.y > screen.y - FOOT + 0.5):
			result["edge"] += 1
			result["lines"].append("in the margin: %s at %s" % [_name(control), seen])
	for i in all.size():
		for j in range(i + 1, all.size()):
			var a: Control = all[i][0]
			var b: Control = all[j][0]
			if a.is_ancestor_of(b) or b.is_ancestor_of(a):
				continue
			var first: Rect2 = all[i][2]
			var second: Rect2 = all[j][2]
			if first.grow(APART * 0.5 - 0.5).intersects(second.grow(APART * 0.5 - 0.5)):
				result["close"] += 1
				result["lines"].append("%s: %s and %s" % ["overlap" if first.intersects(second) else "too near", _name(a), _name(b)])
	return result


static func line(state: String, result: Dictionary) -> String:
	return "%-22s %2d to touch, smallest %s, %d under %d, %d too near, %d in the margins, least text %d" % [state, result["count"], result["smallest"], result["small"], int(LEAST), result["close"], result["edge"], result["text"]]
