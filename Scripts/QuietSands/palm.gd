extends Node3D

const Forms = preload("res://Scripts/QuietSands/forms.gd")
@export var variation := 0

func _ready() -> void:
	var bark := ShaderMaterial.new()
	bark.shader = load("res://Shaders/QuietSands/palm.gdshader")
	var leaves := bark.duplicate()
	leaves.set_shader_parameter("leaf",true)
	var rng := RandomNumberGenerator.new()
	rng.seed = 78+variation*23
	var lean := rng.randf_range(0.8,2.0)
	var points: Array = []
	for j in 41:
		var t := float(j)/40
		points.append(Vector4(lean*t*t,10*t,0.25*sin(t*3),lerpf(0.55,0.22,t)*(1.0+0.085*sin(t*115))))
	Forms.add_mesh(self,Forms.rings(points,16,variation*0.9,0.04),bark,Vector3.ZERO,true,"CarvedTrunk")
	var vertices := PackedVector3Array()
	var ids := PackedInt32Array()
	var uvs := PackedVector2Array()
	for frond in 12:
		var a := TAU*frond/12.0+rng.randf_range(-0.18,0.18)
		var length := rng.randf_range(6.5,9.0)
		var rise := rng.randf_range(1.7,3.2)
		var droop := rng.randf_range(3.0,5.0)
		var direction := Vector3(cos(a),0,sin(a))
		var side := Vector3(-sin(a),0,cos(a))
		var start := vertices.size()
		for j in 33:
			var t := float(j)/32
			var center := Vector3(lean,10,0)+direction*t*length+Vector3(0,rise*sin(t*PI*0.9)-droop*t*t,0)
			var width := sin(pow(t,0.7)*PI)*0.9
			width *= 1.0 if j%2==0 else 0.60
			for k in 3:
				vertices.append(center+side*(k-1)*width+Vector3(0,-absf(k-1)*width*0.22,0))
				uvs.append(Vector2(float(k)/2,t))
			if j<32:
				for k in 2:
					var n := start+j*3+k
					ids.append_array(PackedInt32Array([n,n+3,n+1,n+1,n+3,n+4]))
	Forms.add_mesh(self,Forms.surface(vertices,ids,uvs),leaves,Vector3.ZERO,false,"FoldedFronds")
