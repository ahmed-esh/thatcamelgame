extends SceneTree

func _initialize() -> void:
	var terrain := preload("res://scripts/terrain.gd").new()
	var heights := PackedFloat32Array()
	heights.resize(513*513)
	for z in 513:
		for x in 513:
			heights[z*513+x] = terrain.sculpt(x*4.0-1024,z*4.0-1024)
	var resource := HeightMapShape3D.new()
	resource.map_width = 513
	resource.map_depth = 513
	resource.map_data = heights
	var result := ResourceSaver.save(resource,"res://scenes/terrain_heightfield.res")
	terrain.free()
	print("TERRAIN_BAKED result=",result)
	quit(result)
