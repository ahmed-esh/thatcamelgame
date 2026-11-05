extends Node3D

const Forms = preload("res://Scripts/QuietSands/forms.gd")
@export var variant := 0
var terrain: Node3D

func _ready() -> void:
	var stone := ShaderMaterial.new()
	stone.shader = load("res://Shaders/QuietSands/stone.gdshader")
	stone.set_shader_parameter("masonry",true)
	var rng := RandomNumberGenerator.new()
	rng.seed = 100+variant*19
	var rows: int = [5,3,6,4,2,7][variant%6]
	var width: int = [7,9,5,8,6,5][variant%6]
	for side in 2:
		var column_heights: Array[int] = []
		for column in width:
			column_heights.append(maxi(1,rows-int(absf(column-width*0.38)*0.65)-rng.randi_range(0,1)))
		for row in rows:
			for column in width:
				if row>=column_heights[column]:
					continue
				if side==0 and column in [2,3]:
					continue
				var p := Vector3((column-width/2.0)*2.3+(row%2)*0.8,row*1.35,side*9.0)
				p.y += _ground(p)-global_position.y
				var block := Forms.add_mesh(self,Forms.block(Vector3(2.25,1.28,1.8),rng.randf()*20),stone,p,true,"WeatheredMasonry")
				block.rotation = Vector3(rng.randf_range(-0.04,0.04),rng.randf_range(-0.05,0.05),rng.randf_range(-0.04,0.04))
		if side==0 and rows>=4:
			var lintel_position := Vector3((2.5-width/2.0)*2.3,3.4,0)
			lintel_position.y += _ground(lintel_position)-global_position.y
			Forms.add_mesh(self,Forms.block(Vector3(7.2,1.15,2.0),variant+3),stone,lintel_position,true,"BrokenDoorLintel")
	for i in (3 if variant%2==0 else 2):
		var height := rng.randf_range(7,15)
		var p := Vector3(-10+i*10,0,-3)
		p.y = _ground(p)-global_position.y
		var points: Array = []
		for j in 13:
			var t := float(j)/12
			points.append(Vector4(0,t*height,0,(1.1+0.1*sin(t*35))*(1.0-t*0.2)))
		Forms.add_mesh(self,Forms.rings(points,12,i+variant,0.09),stone,p,true,"SurvivingPillar")
		Forms.add_mesh(self,Forms.block(Vector3(3,0.7,2.8),i),stone,p+Vector3(0,height,0),true,"CarvedCapital")
	for i in 12:
		var p := Vector3(rng.randf_range(-15,15),0,rng.randf_range(-7,13))
		p.y = _ground(p)-global_position.y-0.45
		var rubble := Forms.add_mesh(self,Forms.block(Vector3(rng.randf_range(1,3),1.5,2),i),stone,p,true,"BuriedStone")
		rubble.rotation = Vector3(rng.randf_range(-0.4,0.4),rng.randf()*TAU,rng.randf_range(-0.5,0.5))
	if variant in [0,2,5]:
		var rune := Forms.standard(Color(0.15,0.33,0.36),0.8,Color(0.08,0.3,0.33))
		for j in 5:
			var glyph := BoxMesh.new()
			glyph.size = Vector3(0.055,0.5,0.06)
			var p := Vector3(-10,2+j*0.7,-4.05)
			p.y += _ground(Vector3(-10,0,-3))-global_position.y
			var line := Forms.add_mesh(self,glyph,rune,p,false,"WornInscription")
			line.rotation.z = 0.4 if j%2==0 else -0.4
		var light := OmniLight3D.new()
		light.position = Vector3(0,3,3)
		light.light_color = Color(1,0.57,0.26)
		light.light_energy = 0.3
		light.omni_range = 13
		add_child(light)

func _ground(p: Vector3) -> float:
	if terrain == null:
		return global_position.y
	var wp := to_global(p)
	return terrain.base_height(wp.x,wp.z)
