extends RefCounted
## Not part of the game. Measures what is on the screen of the tomb editor's
## phone layout (`TombPhoneUI`) against what a thumb needs, for the tools that
## look at it (`tools/tomb_phone_shots.gd`, `tools/tomb_editor_test.gd`).
##
## `measure(editor)` walks everything that can be touched and is showing, and
## every word, and says in `wrong` whatever:
##  - can be touched and is under 88 by 88;
##  - is nearer than 12 to another thing that can be touched, or over it;
##  - stands within 48 of the left or right of the screen, 24 of the bottom, or off it;
##  - is one of the engine's own small buttons or sliders;
##  - is written smaller than 26;
##  - is a mark on the floor plan under 88 across, or within 12 of another.
## With that it gives the numbers: `count` things to touch, the `smallest` of
## them, the `nearest` two are to each other, the least `margin` to the sides
## and to the `foot`, the smallest `text`, and of the `marks` on a floor plan
## how many, the smallest (`mark`, across) and how near two are (`mark_gap`).

const TOUCH := 88.0
const GAP := 12.0
const EDGE := 48.0
const FOOT := 24.0
const TEXT := 26


static func measure(editor: TombEditor) -> Dictionary:
	var said := {"wrong": PackedStringArray(), "count": 0, "smallest": Vector2(INF, INF), "nearest": INF, "margin": INF, "foot": INF, "text": 9999,
		"marks": 0, "mark": INF, "mark_gap": INF}
	var wrong: PackedStringArray = said["wrong"]
	var phone := editor._phone
	if phone == null:
		wrong.append("the editor is not laid out for a phone")
		return said
	var screen := Rect2(Vector2.ZERO, editor._pad.size)
	var within := phone.scroller().get_global_rect()
	var seen: Array = []
	for control in phone.touches():
		var rect := control.get_global_rect()
		var name := _name(control)
		said["count"] += 1
		if control is BaseButton or control is Range:
			wrong.append("%s is one of the engine's own buttons or sliders" % name)
		if rect.size.x < TOUCH - 0.5 or rect.size.y < TOUCH - 0.5:
			wrong.append("%s is %.0f by %.0f" % [name, rect.size.x, rect.size.y])
		if rect.size.x * rect.size.y < (said["smallest"] as Vector2).x * (said["smallest"] as Vector2).y:
			said["smallest"] = rect.size
		# (a row of a page shows as much of itself as the page has scrolled to)
		var showing := rect.intersection(within) if phone.scroller().is_ancestor_of(control) else rect
		said["margin"] = minf(said["margin"], minf(showing.position.x, screen.end.x - showing.end.x))
		said["foot"] = minf(said["foot"], screen.end.y - showing.end.y)
		if showing.position.x < EDGE - 0.5 or showing.end.x > screen.end.x - EDGE + 0.5:
			wrong.append("%s is %.0f from the side of the screen" % [name, minf(showing.position.x, screen.end.x - showing.end.x)])
		if showing.end.y > screen.end.y - FOOT + 0.5 or showing.position.y < -0.5:
			wrong.append("%s is %.0f from the bottom of the screen" % [name, screen.end.y - showing.end.y])
		for other: Array in seen:
			var apart := _apart(showing, other[1])
			said["nearest"] = minf(said["nearest"], apart)
			if apart < GAP - 0.5:
				wrong.append("%s and %s are %.0f apart" % [name, other[0], apart])
		seen.append([name, showing])
	_words(phone, said, wrong)
	if phone.page == "" and editor._floor:
		var marks: Array = editor._marks
		said["marks"] = marks.size()
		for i in marks.size():
			var across := float(marks[i][1]) * 2.0
			said["mark"] = minf(said["mark"], across)
			if across < TOUCH - 0.5:
				wrong.append("a mark on the plan is %.0f across" % across)
			for j in i:
				var apart := (marks[i][0] as Vector2).distance_to(marks[j][0]) - float(marks[i][1]) - float(marks[j][1])
				said["mark_gap"] = minf(said["mark_gap"], apart)
				if apart < GAP - 0.5:
					wrong.append("two marks on the plan are %.0f apart" % apart)
	return said


## The numbers in a line, to print.
static func line(said: Dictionary) -> String:
	var smallest: Vector2 = said["smallest"]
	var text := "%d to touch" % int(said["count"])
	if int(said["count"]) > 0:
		text += ", smallest %.0f x %.0f" % [smallest.x, smallest.y]
		text += ", nearest two %s apart" % ("-" if said["nearest"] == INF else "%.0f" % float(said["nearest"]))
		text += ", %.0f from the sides, %.0f from the bottom" % [float(said["margin"]), float(said["foot"])]
	text += ", smallest words %s" % ("-" if int(said["text"]) == 9999 else str(said["text"]))
	if int(said["marks"]) > 0:
		text += "; %d marks, smallest %.0f across, nearest two %s apart" % [int(said["marks"]), float(said["mark"]), "-" if said["mark_gap"] == INF else "%.0f" % float(said["mark_gap"])]
	return text


# How far apart two things are: the gap between them across or up and down, whichever is the larger (under 0 if one is over the other).
static func _apart(a: Rect2, b: Rect2) -> float:
	var across := maxf(a.position.x - b.end.x, b.position.x - a.end.x)
	var down := maxf(a.position.y - b.end.y, b.position.y - a.end.y)
	return maxf(across, down)


static func _words(node: Node, said: Dictionary, wrong: PackedStringArray) -> void:
	for child in node.get_children():
		var control := child as Control
		if control == null or not control.visible:
			continue
		var size := 9999
		if control is Label and (control as Label).text != "":
			size = control.get_theme_font_size(&"font_size")
		elif control is LineEdit or control is TextEdit or control is Button:
			size = control.get_theme_font_size(&"font_size")
		if size < 9999:
			said["text"] = mini(said["text"], size)
			if size < TEXT:
				wrong.append("%s is written at %d" % [_name(control), size])
		_words(child, said, wrong)


static func _name(control: Control) -> String:
	if control is TombPhoneUI.Touch:
		return (control as TombPhoneUI.Touch).key
	if control is Label:
		return "\"%s\"" % (control as Label).text.left(24)
	return String(control.name)
