class_name DesertHorizon
extends MeshInstance3D
## The far hills: mesas and buttes standing all round the level, beyond the
## ground that can be walked on, and behind them the long low cliff where the
## high desert begins, so that the desert does not end at an edge. They stand
## in the haze (their rock is drawn with air between it and the eye), and the
## heat mirage makes their feet swim as it does everything far off.
##
## It is one model (`horizon_mesas` in `tools/rocks.blend`: a ring of hills 100
## from its middle), made as big as the level needs: one draw call, about 1500
## triangles, nothing solid. `hills` is how high they stand: 1 is about a
## tenth as high as they are far.

## How far off the nearest of them are, from the middle of the level, in metres.
@export var distance := 380.0
## How high they stand, 0..1.
@export_range(0.0, 1.0) var hills := 0.6
## Any number: it turns the ring, so that another level has other hills behind it.
@export var seed := 1
@export var colour := Color(0.66, 0.5, 0.37)
## The colour of the air they are seen through.
@export var air := Color(0.8, 0.83, 0.82)


func _ready() -> void:
	build()


## Makes it (again) from its numbers.
func build() -> void:
	mesh = RockModels.mesh("horizon_mesas")
	var wide := distance / 92.0
	basis = Basis(Vector3.UP, seed * 0.7).scaled_local(Vector3(wide, wide * lerpf(0.4, 1.4, hills), wide))
	material_override = Rock.far_material(colour, seed, Color(air, 0.0006))
	cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	visible = hills > 0.0 and mesh != null
