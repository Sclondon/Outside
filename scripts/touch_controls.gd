class_name TouchControls
extends Control
## Touch input: a floating stick on the left of the screen; on the right, two
## small buttons (duck, act) and jump anywhere else.
##
## The stick appears wherever the thumb lands and its base trails the thumb when
## dragged past the rim, so the player never has to look for it or re-centre.

signal jump_pressed
signal jump_released
signal act_pressed

## Fraction of the screen width (from the left) that belongs to the stick.
@export_range(0.2, 0.8) var stick_zone := 0.5
## Stick travel in viewport pixels.
@export var stick_radius := 105.0
@export_range(0.0, 0.5) var dead_zone := 0.14
@export var tint := Color(1.0, 1.0, 1.0)

## Stick output, length 0..1. X is right, Y is down the screen.
var move := Vector2.ZERO
var jump_held := false
var duck_held := false

var _stick_index := -1
var _jump_index := -1
var _duck_index := -1
var _act_index := -1
var _stick_origin := Vector2.ZERO
var _stick_knob := Vector2.ZERO
var _stick_alpha := 0.0
var _jump_alpha := 0.0
var _duck_alpha := 0.0
var _act_alpha := 0.0
var _hint_alpha := 0.0


func _init() -> void:
	add_to_group(&"touch_controls")


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	# Only advertise the controls on devices that can actually use them.
	_hint_alpha = 1.0 if DisplayServer.is_touchscreen_available() else 0.0


func _input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		var pos: Vector2 = make_input_local(event).position
		if event.pressed:
			_press(event.index, pos)
		else:
			_release(event.index)
	elif event is InputEventScreenDrag and event.index == _stick_index:
		_drag(make_input_local(event).position)


func _notification(what: int) -> void:
	# Touches never get a release event if the app loses focus mid-press.
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT or what == NOTIFICATION_APPLICATION_PAUSED:
		for index: int in [_stick_index, _jump_index, _duck_index, _act_index]:
			_release(index)


func _button_radius() -> float:
	return stick_radius * 0.5


## Duck sits under the thumb's resting place, act beside it.
func _duck_centre() -> Vector2:
	return Vector2(size.x * 0.93, size.y - size.x * 0.055)


func _act_centre() -> Vector2:
	return Vector2(size.x * 0.81, size.y - size.x * 0.055)


func _press(index: int, pos: Vector2) -> void:
	_hint_alpha = 1.0
	var reach := _button_radius() * 1.3
	if pos.x < size.x * stick_zone:
		if _stick_index == -1:
			_stick_index = index
			_stick_origin = pos
			_stick_knob = pos
			move = Vector2.ZERO
	elif pos.distance_to(_duck_centre()) < reach:
		if _duck_index == -1:
			_duck_index = index
			duck_held = true
	elif pos.distance_to(_act_centre()) < reach:
		if _act_index == -1:
			_act_index = index
			act_pressed.emit()
	elif _jump_index == -1:
		_jump_index = index
		jump_held = true
		jump_pressed.emit()


func _release(index: int) -> void:
	if index == -1:
		return
	if index == _stick_index:
		_stick_index = -1
		move = Vector2.ZERO
	elif index == _jump_index:
		_jump_index = -1
		jump_held = false
		jump_released.emit()
	elif index == _duck_index:
		_duck_index = -1
		duck_held = false
	elif index == _act_index:
		_act_index = -1


func _drag(pos: Vector2) -> void:
	var offset := pos - _stick_origin
	var distance := offset.length()
	if distance > stick_radius:
		_stick_origin = pos - offset / distance * stick_radius
		offset = pos - _stick_origin
		distance = stick_radius
	_stick_knob = pos
	var strength := inverse_lerp(dead_zone, 1.0, distance / stick_radius)
	move = offset / distance * clampf(strength, 0.0, 1.0) if distance > 0.0 else Vector2.ZERO


func _process(delta: float) -> void:
	var blend := 1.0 - exp(-14.0 * delta)
	_stick_alpha = lerpf(_stick_alpha, 1.0 if _stick_index != -1 else 0.0, blend)
	_jump_alpha = lerpf(_jump_alpha, 1.0 if jump_held else 0.0, blend)
	_duck_alpha = lerpf(_duck_alpha, 1.0 if duck_held else 0.0, blend)
	_act_alpha = lerpf(_act_alpha, 1.0 if _act_index != -1 else 0.0, blend)
	queue_redraw()


func _draw() -> void:
	if _hint_alpha <= 0.0:
		return
	var rest := Vector2(size.x * 0.14, size.y - size.x * 0.13)
	var origin := _stick_origin if _stick_index != -1 else rest
	var knob := _stick_knob if _stick_index != -1 else rest
	var ring := Color(tint, lerpf(0.07, 0.22, _stick_alpha))
	draw_arc(origin, stick_radius, 0.0, TAU, 48, ring, 2.0, true)
	draw_circle(knob, stick_radius * 0.36, Color(tint, lerpf(0.05, 0.28, _stick_alpha)))

	var jump_centre := Vector2(size.x * 0.87, size.y - size.x * 0.17)
	_draw_button(jump_centre, stick_radius * 0.62, _jump_alpha)
	_draw_button(_duck_centre(), _button_radius(), _duck_alpha)
	_draw_button(_act_centre(), _button_radius(), _act_alpha)
	# Duck: a chevron pointing down. Act: an open hand, drawn as a dot.
	var duck := _duck_centre()
	var mark := Color(tint, 0.3)
	draw_polyline([duck + Vector2(-12.0, -6.0), duck + Vector2(0.0, 7.0), duck + Vector2(12.0, -6.0)], mark, 2.0, true)
	draw_circle(_act_centre(), 7.0, mark)


func _draw_button(centre: Vector2, radius: float, pressed: float) -> void:
	draw_arc(centre, radius, 0.0, TAU, 40, Color(tint, lerpf(0.09, 0.3, pressed)), 2.0, true)
	draw_circle(centre, radius * lerpf(0.0, 0.8, pressed), Color(tint, 0.16 * pressed))
