class_name TouchControls
extends Control
## Touch input: a floating stick on the left of the screen, jump anywhere on the right.
##
## The stick appears wherever the thumb lands and its base trails the thumb when
## dragged past the rim, so the player never has to look for it or re-centre.

signal jump_pressed
signal jump_released

## Fraction of the screen width (from the left) that belongs to the stick.
@export_range(0.2, 0.8) var stick_zone := 0.5
## Stick travel in viewport pixels.
@export var stick_radius := 105.0
@export_range(0.0, 0.5) var dead_zone := 0.14
@export var tint := Color(1.0, 1.0, 1.0)

## Stick output, length 0..1. X is right, Y is down the screen.
var move := Vector2.ZERO
var jump_held := false

var _stick_index := -1
var _jump_index := -1
var _stick_origin := Vector2.ZERO
var _stick_knob := Vector2.ZERO
var _stick_alpha := 0.0
var _jump_alpha := 0.0
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
		_release(_stick_index)
		_release(_jump_index)


func _press(index: int, pos: Vector2) -> void:
	_hint_alpha = 1.0
	if pos.x < size.x * stick_zone:
		if _stick_index == -1:
			_stick_index = index
			_stick_origin = pos
			_stick_knob = pos
			move = Vector2.ZERO
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

	var jump_centre := Vector2(size.x * 0.88, size.y - size.x * 0.12)
	var jump_radius := stick_radius * 0.62
	draw_arc(jump_centre, jump_radius, 0.0, TAU, 40, Color(tint, lerpf(0.09, 0.3, _jump_alpha)), 2.0, true)
	draw_circle(jump_centre, jump_radius * lerpf(0.0, 0.8, _jump_alpha), Color(tint, 0.16 * _jump_alpha))
