extends Node3D

const SIZE := 2048.0
const GRID := 513
const STEP := 4.0
const TILE := 16.0
const RES := 65
const DETAIL := 0.25
const RIDGES := [
	[-680.0,-815.0,0.35,340.0,118.0,102.0,0.55],
	[-350.0,-730.0,-0.3,410.0,130.0,148.0,0.48],
	[185.0,-840.0,0.2,460.0,155.0,176.0,0.64],
	[650.0,-610.0,-0.55,360.0,145.0,155.0,0.7],
	[-825.0,-335.0,0.65,380.0,140.0,135.0,0.4],
	[-355.0,-295.0,0.0,220.0,88.0,80.0,0.7],
	[170.0,-300.0,-0.6,300.0,93.0,110.0,0.8],
	[560.0,-100.0,0.3,400.0,120.0,132.0,0.48],
	[870.0,100.0,-0.5,310.0,125.0,125.0,0.65],
	[-710.0,115.0,-0.35,370.0,150.0,160.0,0.5],
	[-180.0,180.0,0.7,340.0,125.0,138.0,0.7],
	[205.0,300.0,0.3,470.0,160.0,185.0,0.6],
	[-830.0,765.0,0.2,320.0,120.0,140.0,0.5],
	[-210.0,750.0,-0.55,350.0,135.0,155.0,0.6],
	[240.0,915.0,-0.2,450.0,100.0,165.0,0.4],
	[850.0,850.0,0.65,350.0,135.0,165.0,0.7],
	[-520.0,-565.0,0.4,120.0,40.0,24.0,0.7],
	[370.0,-530.0,-0.2,150.0,45.0,29.0,0.7],
	[-90.0,-600.0,0.3,160.0,45.0,31.0,0.8]]

var heights := PackedFloat32Array()
var material: ShaderMaterial
var local_material: ShaderMaterial
var active: Dictionary = {}
var history: Dictionary = {}
var cell := Vector2i(9999,9999)
var indices := PackedInt32Array()
var clock := 0.0
var settle_clock := 0.0
var settle_index := 0
var stamp_count := 0
var minimum := 1000.0
var maximum := -1000.0

func _ready() -> void:
	material = $Dunes_0_0.material_override if has_node("Dunes_0_0") else load("res://Terrain/QuietSands/sand.tres").duplicate()
	local_material = material.duplicate()
	local_material.set_shader_parameter("local_surface", true)
	if ResourceLoader.exists("res://Scenes/QuietSands/terrain_heightfield.res"):
		var baked: HeightMapShape3D = load("res://Scenes/QuietSands/terrain_heightfield.res")
		heights = baked.map_data
	else:
		heights.resize(GRID * GRID)
		for z in GRID:
			for x in GRID:
				heights[z * GRID + x] = sculpt(x * STEP - 1024.0, z * STEP - 1024.0)
	for h in heights:
		minimum = minf(minimum,h)
		maximum = maxf(maximum,h)
	if not has_node("Dunes_0_0"):
		for z in 16:
			for x in 16:
				_build_distant(x, z)
	indices = grid_indices(RES)

func sculpt(x: float, z: float) -> float:
	var h := 7.0 + 4.0 * sin(x * 0.003 + z * 0.001) + 3.0 * cos(z * 0.005)
	for r in RIDGES:
		var dx: float = x - r[0]
		var dz: float = z - r[1]
		var u: float = (dx * cos(r[2]) + dz * sin(r[2])) / r[3]
		var v: float = -dx * sin(r[2]) + dz * cos(r[2])
		var arc: float = r[4] * (0.8 * u * u - 0.2) + 10.0 * sin(u * 4.0 + r[2])
		var across: float = (v - arc) / r[4]
		var width: float = lerpf(1.0, r[6], smoothstep(-0.10,0.12,across))
		var crest: float = exp(-pow(absf(across / width), 1.65) * 2.3)
		h += r[5] * 0.8 * crest * exp(-pow(absf(u), 4.0) * 2.0)
	h += 1.4 * sin(x * 0.025 + sin(z * 0.013) * 1.7) * sin(z * 0.018)
	var pool := Vector2(x / 47.0, (z + 140.0) / 34.0).length()
	var shore := -1.35 + 1.35 * pool * pool + 0.30 * sin(x * 0.095) * smoothstep(0.5,1.7,pool)
	h = lerpf(shore, h, smoothstep(1.2, 2.9, pool))
	for mountain in [Vector2(560,460), Vector2(-550,630)]:
		var d := Vector2(x,z).distance_to(mountain)
		h = lerpf(6.0 + 0.8 * sin(x * 0.02), h, smoothstep(90.0, 200.0, d))
	var opening_distance := Vector2((x+616)/1.2,z+696).length()
	var opening_height := 126.0-(x+616)*0.16-(z+696)*0.10
	h = lerpf(opening_height,h,smoothstep(42.0,165.0,opening_distance))
	return h

func base_height(x: float, z: float) -> float:
	var gx := clampf((x + 1024.0) / STEP, 0, 511.9999)
	var gz := clampf((z + 1024.0) / STEP, 0, 511.9999)
	var ix := int(gx)
	var iz := int(gz)
	var u := gx - ix
	var v := gz - iz
	var a := heights[iz * GRID + ix]
	var b := heights[iz * GRID + ix + 1]
	var c := heights[(iz + 1) * GRID + ix]
	var d := heights[(iz + 1) * GRID + ix + 1]
	if u + v < 1.0:
		return a + (b - a) * u + (c - a) * v
	return d + (c - d) * (1.0 - u) + (b - d) * (1.0 - v)

func normal_at(x: float, z: float) -> Vector3:
	return Vector3(base_height(x-1,z)-base_height(x+1,z),2.0,base_height(x,z-1)-base_height(x,z+1)).normalized()

func grid_indices(n: int) -> PackedInt32Array:
	var result := PackedInt32Array()
	result.resize((n-1)*(n-1)*6)
	var i := 0
	for z in n-1:
		for x in n-1:
			var a := z*n+x
			for k in [a,a+1,a+n,a+1,a+n+1,a+n]:
				result[i] = k
				i += 1
	return result

func _build_distant(cx: int, cz: int) -> void:
	var verts := PackedVector3Array()
	var normals := PackedVector3Array()
	for z in 33:
		for x in 33:
			var wx := -1024.0 + cx * 128.0 + x * STEP
			var wz := -1024.0 + cz * 128.0 + z * STEP
			verts.append(Vector3(wx,base_height(wx,wz),wz))
			normals.append(normal_at(wx,wz))
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = verts
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_INDEX] = grid_indices(33)
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays)
	var instance := MeshInstance3D.new()
	instance.mesh = mesh
	instance.material_override = material
	instance.name = "Dunes_%s_%s" % [cx,cz]
	add_child(instance)

func follow(p: Vector3) -> void:
	var next := Vector2i(floori(p.x / TILE),floori(p.z / TILE))
	if next == cell:
		return
	cell = next
	var wanted: Dictionary = {}
	for z in range(cell.y-1,cell.y+2):
		for x in range(cell.x-1,cell.x+2):
			var key := Vector2i(x,z)
			wanted[key] = true
			if not active.has(key):
				_create_patch(key)
	for key in active.keys():
		if not wanted.has(key):
			active[key].node.queue_free()
			active.erase(key)
	material.set_shader_parameter("patch_min",Vector2(cell-Vector2i.ONE)*TILE)
	material.set_shader_parameter("patch_max",Vector2(cell+Vector2i(2,2))*TILE)

func _create_patch(key: Vector2i) -> void:
	if not history.has(key):
		var depth := PackedFloat32Array()
		depth.resize(RES*RES)
		var glow := depth.duplicate()
		var base_vertices := PackedVector3Array()
		var base_normals := PackedVector3Array()
		base_vertices.resize(RES*RES)
		base_normals.resize(RES*RES)
		for z in RES:
			for x in RES:
				var wx := key.x*TILE+x*DETAIL
				var wz := key.y*TILE+z*DETAIL
				base_vertices[z*RES+x] = Vector3(wx,base_height(wx,wz),wz)
				base_normals[z*RES+x] = normal_at(wx,wz)
		history[key] = {"depth":depth,"glow":glow,"time":clock,"base_vertices":base_vertices,"base_normals":base_normals}
	var root := StaticBody3D.new()
	root.name = "Sand_%s_%s" % [key.x,key.y]
	root.collision_layer = 1
	add_child(root)
	var visual := MeshInstance3D.new()
	visual.material_override = local_material
	root.add_child(visual)
	var collision := CollisionShape3D.new()
	collision.position = Vector3(key.x*TILE+8.0,0,key.y*TILE+8.0)
	collision.scale = Vector3(DETAIL,1,DETAIL)
	root.add_child(collision)
	active[key] = {"node":root,"visual":visual,"collision":collision}
	_rebuild(key)

func _rebuild(key: Vector2i) -> void:
	var record: Dictionary = history[key]
	var depths: PackedFloat32Array = record.depth
	var glow_values: PackedFloat32Array = record.glow
	var base_normals: PackedVector3Array = record.base_normals
	var decay := exp(-(clock - float(record.time)) / 110.0)
	var glow_decay := exp(-(clock - float(record.time)) / 9.0)
	var verts: PackedVector3Array = record.base_vertices.duplicate()
	var normals := PackedVector3Array()
	var colors := PackedColorArray()
	var data := PackedFloat32Array()
	verts.resize(RES*RES)
	normals.resize(RES*RES)
	colors.resize(RES*RES)
	data.resize(RES*RES)
	for z in RES:
		for x in RES:
			var i := z*RES+x
			depths[i] *= decay
			glow_values[i] *= glow_decay
			data[i] = verts[i].y+depths[i]
			verts[i].y = data[i]
			colors[i] = Color(glow_values[i],0,0,1)
	for z in RES:
		for x in RES:
			var i := z*RES+x
			var n := base_normals[i]
			var ddx := (depths[z*RES+maxi(x-1,0)]-depths[z*RES+mini(x+1,RES-1)]) / (DETAIL*2)
			var ddz := (depths[maxi(z-1,0)*RES+x]-depths[mini(z+1,RES-1)*RES+x]) / (DETAIL*2)
			normals[i] = (n+Vector3(ddx,0,ddz)).normalized()
	record.depth = depths
	record.glow = glow_values
	record.time = clock
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = verts
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_COLOR] = colors
	arrays[Mesh.ARRAY_INDEX] = indices
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays)
	active[key].visual.mesh = mesh
	var shape := HeightMapShape3D.new()
	shape.map_width = RES
	shape.map_depth = RES
	shape.map_data = data
	active[key].collision.shape = shape

func stamp(p: Vector3, direction: Vector3, width: float, length: float, depth: float) -> void:
	stamp_count += 1
	var dir := Vector2(direction.x,direction.z).normalized()
	if dir.length_squared() < 0.1:
		dir = Vector2(0,1)
	var side := Vector2(-dir.y,dir.x)
	var extent := maxf(width,length)*1.5
	for key in active:
		var origin := Vector2(key)*TILE
		if not Rect2(origin-Vector2.ONE*extent,Vector2.ONE*(TILE+extent*2)).has_point(Vector2(p.x,p.z)):
			continue
		var record: Dictionary = history[key]
		var depths: PackedFloat32Array = record.depth
		var glow_values: PackedFloat32Array = record.glow
		var decay := exp(-(clock-float(record.time))/110.0)
		var glow_decay := exp(-(clock-float(record.time))/9.0)
		for i in RES*RES:
			depths[i] *= decay
			glow_values[i] *= glow_decay
		record.time = clock
		var dirty := false
		for z in range(maxi(0,floori((p.z-extent-origin.y)/DETAIL)),mini(RES,ceili((p.z+extent-origin.y)/DETAIL)+1)):
			for x in range(maxi(0,floori((p.x-extent-origin.x)/DETAIL)),mini(RES,ceili((p.x+extent-origin.x)/DETAIL)+1)):
				var delta := origin+Vector2(x,z)*DETAIL-Vector2(p.x,p.z)
				var r := Vector2(delta.dot(side)/width,delta.dot(dir)/length).length()
				if r > 1.45:
					continue
				var depression := -depth*exp(-r*r*4.5)
				var berm := depth*0.23*exp(-pow((r-0.95)*4.5,2))
				var i := z*RES+x
				depths[i] = clampf(depths[i]+depression+berm,-0.32,0.12)
				glow_values[i] = maxf(glow_values[i],exp(-r*r*3.5)*0.65)
				dirty = true
		record.depth = depths
		record.glow = glow_values
		if dirty:
			_rebuild(key)

func _process(delta: float) -> void:
	clock += delta
	settle_clock += delta
	if settle_clock > 0.18 and not active.is_empty():
		settle_clock = 0
		settle_index = (settle_index+1)%active.size()
		var key: Vector2i = active.keys()[settle_index]
		if history[key].glow.count(0.0) != RES*RES:
			_rebuild(key)
	if history.size() > 256:
		var candidates := history.keys().filter(func(key): return not active.has(key))
		candidates.sort_custom(func(a,b): return history[a].time<history[b].time)
		for i in mini(history.size()-256,candidates.size()):
			history.erase(candidates[i])
