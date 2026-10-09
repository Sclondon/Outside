class_name GearProp
extends Prop
## A prop with metal in it (a khopesh, a gilded helmet on its stand, a brass
## level): a Prop whose gold, bronze and brass shine. tools/build_prop_scenes.gd
## gives this script to any prop that tools/build_props.py marked `shiny`.


func _ready() -> void:
	super._ready()
	var model := get_node_or_null(^"Model")
	if model:
		# (a frame later: see Worn.shine)
		Worn.shine.call_deferred(model)
