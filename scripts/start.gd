extends Node
## What the game opens with (`start.tscn`): nothing but the notebook's page, behind which the first
## level builds itself. Without it the first thing seen would be a still picture for as long as that takes.


func _ready() -> void:
	Loading.go(Loading.FIRST, "", true)
