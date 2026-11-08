
extends Node3D

const Forms = preload("res://Scripts/QuietSands/forms.gd")
@export var kind := 0

func _ready() -> void:
	var stone := ShaderMaterial.new()
	stone.shader = load("res://Shaders/QuietSands/stone.gdshader")
	if kind == 0:
		Forms.add_mesh(self,Forms.rock(100,32,1.0,true),stone,Vector3(0,-6,26),true,"ClimbableSandstone")
		Forms.add_mesh(self,Forms.arch(),stone,Vector3(0,22,-13),true,"ErodedNaturalArch")
		for spec in [Vector4(-52,12,18,49),Vector4(53,9,30,63),Vector4(72,2,-27,39),Vector4(-65,0,-45,25)]:
			Forms.add_mesh(self,Forms.rock(12.5,spec.w,spec.x,true),stone,Vector3(spec.x,spec.y,spec.z),true,"WeatheredTower")
		_terrace(stone,Vector3(-40,23,5))
	else:
		Forms.add_mesh(self,Forms.rock(105,42,7.0,true),stone,Vector3(0,-6,0),true,"LayeredMesa")
		for spec in [Vector4(0,26,8,75),Vector4(-31,20,13,60),Vector4(29,19,-5,52),Vector4(12,17,37,45),Vector4(-55,6,-22,37),Vector4(62,0,25,26)]:
			Forms.add_mesh(self,Forms.rock(9.0+spec.w*0.045,spec.w,spec.x+4.0),stone,Vector3(spec.x,spec.y,spec.z),true,"SandstoneSpire")
		_terrace(stone,Vector3(39,25,8))
	for j in 18:
		var a := -1.5+float(j)*0.145
		var t := float(j)/17
		var p := Vector3(cos(a)*(96-t*57),t*31-3,sin(a)*(96-t*57))
		Forms.add_mesh(self,Forms.rock(9.5,4.0,j*0.7,true),stone,p,true,"NaturalClimbingLedge")
	_climbing_buttress(stone)
	for mesh in get_children():
		if mesh is MeshInstance3D:
			for body in mesh.get_children():
				if body is StaticBody3D:
					for collision in body.get_children():
						if collision is CollisionShape3D:
							var shape := (collision as CollisionShape3D).shape
							if shape is ConcavePolygonShape3D:
								(shape as ConcavePolygonShape3D).backface_collision = true

func _climbing_buttress(stone: ShaderMaterial) -> void:
	var vertices := PackedVector3Array()
	var ids := PackedInt32Array()
	var start := Vector3(108,0,65)
	var end := Vector3(12,27 if kind==0 else 37,25)
	var direction := Vector3(end.x-start.x,0,end.z-start.z).normalized()
	var side := Vector3(-direction.z,0,direction.x)
	for j in 65:
		var t := float(j)/64
		var center := start.lerp(end,t)
		center.y = end.y*smoothstep(0,1,t)+0.15*sin(t*19)
		var width := 16.0+sin(t*PI)*8.0
		for k in 13:
			var v := clampf(float(k-6)/5,-1,1)
			var point := center+side*v*width
			point.y = -6.0 if k==0 or k==12 else center.y*(1.0-v*v*0.2)
			vertices.append(point)
			if j<64 and k<12:
				var n := j*13+k
				ids.append_array(PackedInt32Array([n,n+13,n+1,n+1,n+13,n+14]))
	Forms.add_mesh(self,Forms.surface(vertices,ids),stone,Vector3.ZERO,true,"ClimbableErodedButtress")

func _terrace(stone: ShaderMaterial, p: Vector3) -> void:
	Forms.add_mesh(self,Forms.block(Vector3(18,2,14),2),stone,p,true,"CaveArtTerrace")
	Forms.add_mesh(self,Forms.block(Vector3(17,11,3.0),3),stone,p+Vector3(0,5,6),true,"PaintingWall")
	Forms.add_mesh(self,Forms.rock(13.5,5,14,true),stone,p+Vector3(0,11.5,4),true,"WeatheredOverhang")
