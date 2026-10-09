class_name TombRandom
extends RefCounted
## The dice a tomb is made with. Nothing here comes from the engine's own
## random numbers, from the clock or from a float: only whole numbers and the
## same few operations on every device, so that one seed gives one tomb
## everywhere, and goes on doing so whatever engine the game is next built with.
## (splitmix64: the state steps by a fixed odd number and is then stirred.)

var _state := 0


func _init(seed_value: int) -> void:
	_state = seed_value


## The next whole number, any of the 64 bits.
func next() -> int:
	_state += -7046029254386353131
	return stir(_state)


## A whole number from 0 up to but not including `count`.
func below(count: int) -> int:
	if count <= 1:
		return 0
	return int(((next() >> 1) & 0x7FFFFFFFFFFFFFFF) % count)


## A whole number from `low` to `high`, both included.
func between(low: int, high: int) -> int:
	return low + below(high - low + 1)


## True `per_cent` times in a hundred.
func chance(per_cent: int) -> bool:
	return below(100) < per_cent


## Thousandths: a number from `low` to `high` in steps of a thousandth of the
## way, for where a thing stands. (Made from a whole number, so it is the same
## float everywhere.)
func spread(low: float, high: float) -> float:
	return low + (high - low) * float(below(1001)) / 1000.0


## One of `weights.size()` choices, each as likely as its weight (whole numbers).
func weighted(weights: Array) -> int:
	var total := 0
	for weight: int in weights:
		total += maxi(weight, 0)
	if total <= 0:
		return -1
	var roll := below(total)
	for i in weights.size():
		roll -= maxi(weights[i], 0)
		if roll < 0:
			return i
	return weights.size() - 1


## Puts a list in a random order, in place.
func shuffle(list: Array) -> void:
	for i in range(list.size() - 1, 0, -1):
		var j := below(i + 1)
		var kept: Variant = list[i]
		list[i] = list[j]
		list[j] = kept


## Stirs a whole number into another that looks nothing like it.
static func stir(value: int) -> int:
	var z := value
	z = (z ^ ((z >> 30) & 0x3FFFFFFFF)) * -4658895280553007687
	z = (z ^ ((z >> 27) & 0x1FFFFFFFFF)) * -7723592293110705685
	return z ^ ((z >> 31) & 0x1FFFFFFFF)


## Several whole numbers stirred into one seed.
static func mix(values: Array) -> int:
	var seed_value := 0x2545F491
	for value: int in values:
		seed_value = stir(seed_value ^ value)
	return seed_value


## A fingerprint of a text (FNV-1a over its bytes), as sixteen hex digits:
## the same on every device, which a String's own hash is not promised to be.
static func fingerprint(text: String) -> String:
	var value := -3750763034362895579
	for byte: int in text.to_utf8_buffer():
		value = (value ^ byte) * 1099511628211
	var digits := ""
	for i in 16:
		digits = "0123456789abcdef"[value & 15] + digits
		value = (value >> 4) & 0x0FFFFFFFFFFFFFFF
	return digits
