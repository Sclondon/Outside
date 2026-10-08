class_name Toon
## Cel shading for the figures: light falls on them in flat bands with a hard
## edge instead of a soft gradient.


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
			part.set_surface_override_material(surface, flat)
