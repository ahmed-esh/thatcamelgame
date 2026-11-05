extends Node3D

const Forms = preload("res://Scripts/QuietSands/forms.gd")
var terrain: Node3D
var traveler: CharacterBody3D
var water_material: ShaderMaterial
var ripples := PackedVector4Array()
var ripple_index := 0
var clock := 0.0
var last_ripple := 0.0

func _ready() -> void:
	water_material = ShaderMaterial.new()
	water_material.shader = load("res://Shaders/QuietSands/water.gdshader")
	ripples.resize(8)
	for i in 8:
		ripples[i] = Vector4(0,0,-100,0)
	if has_node("DreamingWater"):
		water_material = $DreamingWater.material_override
		return
	var vertices := PackedVector3Array()
	var ids := PackedInt32Array()
	var colors := PackedColorArray()
	for z in 81:
		for x in 111:
			var p := Vector3((x-55)*1.0,0,(z-40)*1.0)
			vertices.append(p)
			var h: float = terrain.base_height(p.x,p.z-140) if terrain != null else -2.0
			colors.append(Color(clampf(-h/1.65,0,1),0,0,1))
			if x<110 and z<80:
				var i := z*111+x
				ids.append_array(PackedInt32Array([i,i+1,i+111,i+1,i+112,i+111]))
	var mesh := Forms.surface(vertices,ids)
	var arrays := mesh.surface_get_arrays(0)
	arrays[Mesh.ARRAY_COLOR] = colors
	var water := ArrayMesh.new()
	water.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays)
	Forms.add_mesh(self,water,water_material,Vector3.ZERO,false,"DreamingWater")
	var palm_scene: PackedScene = load("res://Scenes/QuietSands/palm.tscn")
	var positions := [Vector2(-44,-16),Vector2(-31,-31),Vector2(-13,-40),Vector2(12,-38),Vector2(37,-24),Vector2(50,-2),Vector2(43,22),Vector2(23,33),Vector2(4,43),Vector2(-20,36),Vector2(-45,18),Vector2(-51,2),Vector2(34,36)]
	for i in 13:
		var p: Vector2 = positions[i]
		var palm := palm_scene.instantiate()
		palm.name = "Palm_%02d" % (i+1)
		palm.variation = i
		palm.position = Vector3(p.x,terrain.base_height(p.x,p.y-140)-0.1 if terrain!=null else 0,p.y)
		palm.rotation.y = i*2.399
		palm.scale = Vector3.ONE*(0.9+sin(i*3.5)*0.19)
		add_child(palm)
	for p in [Vector3(-29,2,-10),Vector3(28,2,11)]:
		var light := OmniLight3D.new()
		light.position = p
		light.light_color = Color(0.07,0.62,0.66)
		light.light_energy = 0.6
		light.omni_range = 26
		add_child(light)

func _process(delta: float) -> void:
	clock += delta
	if traveler != null:
		var p := traveler.global_position-global_position
		if p.y<1.0 and Vector2(p.x/47,p.z/34).length()<1.1 and traveler.velocity.length()>0.5 and clock-last_ripple>0.45:
			ripples[ripple_index] = Vector4(p.x,p.z,clock,clampf(traveler.velocity.length()/7,0.2,1.0))
			ripple_index = (ripple_index+1)%8
			last_ripple = clock
	water_material.set_shader_parameter("ripples",ripples)
	water_material.set_shader_parameter("water_clock",clock)
