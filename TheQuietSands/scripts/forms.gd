extends RefCounted

static func surface(vertices: PackedVector3Array, indices: PackedInt32Array, uvs := PackedVector2Array()) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in vertices.size():
		if uvs.size() == vertices.size():
			st.set_uv(uvs[i])
		st.add_vertex(vertices[i])
	for i in indices:
		st.add_index(i)
	st.generate_normals()
	return st.commit()

static func rings(points: Array, sides: int, seed_value: float, erosion: float) -> ArrayMesh:
	var verts := PackedVector3Array()
	var uv := PackedVector2Array()
	var ids := PackedInt32Array()
	for j in points.size():
		var p: Vector4 = points[j]
		for i in sides+1:
			var a := TAU*i/sides
			var rough := 1.0+erosion*(0.45*sin(a*5.0+seed_value+p.y*0.11)+0.27*sin(a*9.0-seed_value+p.y*0.21)+0.28*sin(p.y*1.4+sin(a*3.0)))
			verts.append(Vector3(cos(a)*p.w*rough+p.x,p.y,sin(a)*p.w*rough+p.z))
			uv.append(Vector2(float(i)/sides,float(j)/(points.size()-1)))
			if j<points.size()-1 and i<sides:
				var k := j*(sides+1)+i
				ids.append_array(PackedInt32Array([k,k+1,k+sides+1,k+1,k+sides+2,k+sides+1]))
	return surface(verts,ids,uv)

static func rock(radius: float, height: float, seed_value: float, mesa := false) -> ArrayMesh:
	var points: Array = []
	for j in 25:
		var t := float(j)/24.0
		var profile := pow(maxf(0.001,1.0-t),0.42)
		if mesa:
			profile = lerpf(1.0,0.39,pow(t,0.6))
		profile *= 1.0+0.028*sin(t*31.0+seed_value)+0.018*sin(t*63.0)
		if j == 24:
			profile = 0.002
		points.append(Vector4(sin(t*2.0+seed_value)*height*0.045,t*height,sin(t*3.0+seed_value*2.0)*height*0.035,radius*profile))
	return rings(points,40,seed_value,0.14)

static func arch() -> ArrayMesh:
	var verts := PackedVector3Array()
	var ids := PackedInt32Array()
	for j in 65:
		var a := PI*float(j)/64.0
		var center := Vector3(cos(a)*31.0,5.0+sin(a)*37.0,0)
		var radial := Vector3(cos(a),sin(a),0)
		for i in 17:
			var b := TAU*float(i)/16.0
			var width := 5.5+1.3*sin(a*5.0)+0.5*sin(b*7.0+a*11.0)
			verts.append(center+radial*cos(b)*width+Vector3(0,0,sin(b)*width*1.3))
			if j<64 and i<16:
				var k := j*17+i
				ids.append_array(PackedInt32Array([k,k+1,k+17,k+1,k+18,k+17]))
	return surface(verts,ids)

static func block(size: Vector3, seed_value: float) -> ArrayMesh:
	var points: Array = []
	points.append(Vector4(0,-size.y*0.5,0,0.001))
	for j in 5:
		var t := float(j)/4
		points.append(Vector4(0,t*size.y-size.y*0.5,0,(0.87 if j==0 or j==4 else 1.0)))
	points.append(Vector4(0,size.y*0.5,0,0.001))
	var mesh := rings(points,8,seed_value,0.045)
	var arrays := mesh.surface_get_arrays(0)
	var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	for i in verts.size():
		verts[i].x *= size.x*0.54
		verts[i].z *= size.z*0.54
	return surface(verts,arrays[Mesh.ARRAY_INDEX])

static func add_mesh(parent: Node3D, mesh: Mesh, material: Material, p := Vector3.ZERO, collision := false, node_name := "Form") -> MeshInstance3D:
	var instance := MeshInstance3D.new()
	instance.name = node_name
	instance.mesh = mesh
	instance.material_override = material
	instance.position = p
	parent.add_child(instance)
	if collision:
		instance.create_trimesh_collision()
	return instance

static func standard(color: Color, roughness := 0.8, emission := Color.BLACK) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.roughness = roughness
	if emission != Color.BLACK:
		mat.emission_enabled = true
		mat.emission = emission
		mat.emission_energy_multiplier = 1.8
	return mat
