class_name Toon
## Cel shading for the figures: light falls on them in flat bands with a hard
## edge instead of a soft gradient, and a dark line is drawn round each one.

## Thickness of the outline, metres.
const OUTLINE := 0.007

static var _outline: StandardMaterial3D


## Reshades every mesh under `model`. Its own materials are left untouched.
static func apply(model: Node) -> void:
	for part: MeshInstance3D in model.find_children("*", "MeshInstance3D", true, false):
		for surface in part.mesh.get_surface_count():
			var flat := part.mesh.surface_get_material(surface).duplicate() as StandardMaterial3D
			if flat == null:
				continue
			flat.diffuse_mode = BaseMaterial3D.DIFFUSE_TOON
			flat.specular_mode = BaseMaterial3D.SPECULAR_DISABLED
			flat.roughness = 1.0
			flat.next_pass = _outline_material()
			part.set_surface_override_material(surface, flat)


## The outline is the mesh drawn again slightly swollen, inside out and black,
## so only its rim shows round the real one.
static func _outline_material() -> StandardMaterial3D:
	if _outline == null:
		_outline = StandardMaterial3D.new()
		_outline.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		_outline.albedo_color = Color(0.02, 0.02, 0.025)
		_outline.cull_mode = BaseMaterial3D.CULL_FRONT
		_outline.grow = true
		_outline.grow_amount = OUTLINE
	return _outline
