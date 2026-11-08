extends Node3D

const SIZE := 2048.0
const GRID := 513
const STEP := 4.0
const TILE := 16.0
const RES := 65
const DETAIL := 0.25
const FLOW_INTERVAL := 0.1
const FLOW_LIMIT := 900
const FLOW_SPAN := RES - 1
const FLOW_NEIGHBORS := [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1), Vector2i(1, 1), Vector2i(-1, 1), Vector2i(1, -1), Vector2i(-1, -1)]
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
var companion_cell := Vector2i(9999,9999)
var indices := PackedInt32Array()
var clock := 0.0
var settle_clock := 0.0
var settle_index := 0
var flow_clock := 0.0
var flowing: Dictionary = {}
var sand_bursts: Array[GPUParticles3D] = []
var burst_cursor := 0
var last_drag_time := -1.0
var stamp_count := 0
var minimum := 1000.0
var maximum := -1000.0

func _ready() -> void:
	material = $Dunes_0_0.material_override if has_node("Dunes_0_0") else load("res://Terrain/QuietSands/sand.tres").duplicate()
	local_material = material.duplicate()
	local_material.set_shader_parameter("local_surface", true)
	_build_sand_bursts()
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

func _build_sand_bursts() -> void:
	var grain_mesh := QuadMesh.new()
	grain_mesh.size = Vector2(0.075, 0.075)
	var grain_material := StandardMaterial3D.new()
	grain_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	grain_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	grain_material.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	grain_material.vertex_color_use_as_albedo = true
	grain_material.albedo_color = Color(0.84, 0.68, 0.49, 0.8)
	grain_mesh.material = grain_material
	var gradient := Gradient.new()
	gradient.set_color(0, Color(1.0, 1.0, 1.0, 0.0))
	gradient.add_point(0.12, Color(1.0, 1.0, 1.0, 0.9))
	gradient.add_point(0.55, Color(1.0, 1.0, 1.0, 0.55))
	gradient.set_color(gradient.get_point_count() - 1, Color(1.0, 1.0, 1.0, 0.0))
	var ramp := GradientTexture1D.new()
	ramp.gradient = gradient
	for i in 8:
		var burst := GPUParticles3D.new()
		burst.name = "SandContact_%d" % i
		burst.amount = 18
		burst.amount_ratio = 1.0
		burst.lifetime = 0.65
		burst.one_shot = true
		burst.explosiveness = 1.0
		burst.emitting = false
		burst.local_coords = false
		burst.visibility_aabb = AABB(Vector3(-3, -2, -3), Vector3(6, 5, 6))
		var process := ParticleProcessMaterial.new()
		process.direction = Vector3.UP
		process.spread = 70.0
		process.initial_velocity_min = 0.65
		process.initial_velocity_max = 2.0
		process.gravity = Vector3(0.0, -4.5, 0.0)
		process.scale_min = 0.45
		process.scale_max = 1.2
		process.color_ramp = ramp
		burst.process_material = process
		burst.draw_pass_1 = grain_mesh
		add_child(burst)
		sand_bursts.append(burst)

func _sand_burst(point: Vector3, direction: Vector3, strength: float, sliding: bool) -> void:
	if sand_bursts.is_empty():
		return
	var burst := sand_bursts[burst_cursor]
	burst_cursor = (burst_cursor + 1) % sand_bursts.size()
	burst.global_position = Vector3(point.x, base_height(point.x, point.z) + 0.06, point.z)
	var travel := Vector3(direction.x, 0.0, direction.z).normalized()
	var process: ParticleProcessMaterial = burst.process_material
	process.direction = (Vector3.UP * (0.4 if sliding else 0.85) + travel * (1.0 if sliding else 0.35)).normalized()
	process.spread = 38.0 if sliding else 72.0
	process.initial_velocity_min = (0.8 if sliding else 0.5) * strength
	process.initial_velocity_max = (2.7 if sliding else 1.8) * strength
	burst.amount_ratio = clampf(strength * 0.65, 0.35, 1.0)
	burst.emitting = true
	burst.restart()

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

func follow(p: Vector3, companion: Node3D = null) -> void:
	var next := Vector2i(floori(p.x / TILE), floori(p.z / TILE))
	var next_companion := Vector2i(9999, 9999)
	if companion != null:
		var q: Vector3 = companion.global_position
		next_companion = Vector2i(floori(q.x / TILE), floori(q.z / TILE))
	if next == cell and next_companion == companion_cell:
		return
	cell = next
	companion_cell = next_companion
	var wanted: Dictionary = {}
	for center in [cell, companion_cell]:
		if center == Vector2i(9999, 9999):
			continue
		for z in range(center.y - 1, center.y + 2):
			for x in range(center.x - 1, center.x + 2):
				var key := Vector2i(x, z)
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
		var compaction := depth.duplicate()
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
		history[key] = {"depth":depth,"glow":glow,"compaction":compaction,"time":clock,"base_vertices":base_vertices,"base_normals":base_normals}
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
	var compaction: PackedFloat32Array = record.compaction
	var base_normals: PackedVector3Array = record.base_normals
	var decay := exp(-(clock - float(record.time)) / 110.0)
	var glow_decay := exp(-(clock - float(record.time)) / 9.0)
	var compact_decay := exp(-(clock - float(record.time)) / 65.0)
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
			compaction[i] *= compact_decay
			data[i] = verts[i].y+depths[i]
			verts[i].y = data[i]
			colors[i] = Color(glow_values[i], compaction[i], 0, 1)
	for z in RES:
		for x in RES:
			var i := z*RES+x
			var n := base_normals[i]
			var ddx := (depths[z*RES+maxi(x-1,0)]-depths[z*RES+mini(x+1,RES-1)]) / (DETAIL*2)
			var ddz := (depths[maxi(z-1,0)*RES+x]-depths[mini(z+1,RES-1)*RES+x]) / (DETAIL*2)
			normals[i] = (n+Vector3(ddx,0,ddz)).normalized()
	record.depth = depths
	record.glow = glow_values
	record.compaction = compaction
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
	var dir := Vector2(direction.x, direction.z).normalized()
	if dir.length_squared() < 0.1:
		dir = Vector2(0, 1)
	var side := Vector2(-dir.y, dir.x)
	var surface_normal := normal_at(p.x, p.z)
	var downhill := Vector2(surface_normal.x, surface_normal.z)
	if downhill.length_squared() > 0.0001:
		downhill = downhill.normalized()
	var extent := maxf(width, length) * 1.9
	var affected: Dictionary = {}
	var removed := 0.0
	var displaced := 0.0
	for key in active:
		var origin := Vector2(key) * TILE
		if not Rect2(origin - Vector2.ONE * extent, Vector2.ONE * (TILE + extent * 2.0)).has_point(Vector2(p.x, p.z)):
			continue
		var record: Dictionary = history[key]
		var depths: PackedFloat32Array = record.depth
		var glow_values: PackedFloat32Array = record.glow
		var compaction: PackedFloat32Array = record.compaction
		var decay := exp(-(clock - float(record.time)) / 110.0)
		var glow_decay := exp(-(clock - float(record.time)) / 9.0)
		var compact_decay := exp(-(clock - float(record.time)) / 65.0)
		for i in RES * RES:
			depths[i] *= decay
			glow_values[i] *= glow_decay
			compaction[i] *= compact_decay
		record.depth = depths
		record.glow = glow_values
		record.compaction = compaction
		record.time = clock
		for z in range(maxi(0, floori((p.z - extent - origin.y) / DETAIL)), mini(RES, ceili((p.z + extent - origin.y) / DETAIL) + 1)):
			for x in range(maxi(0, floori((p.x - extent - origin.x) / DETAIL)), mini(RES, ceili((p.x + extent - origin.x) / DETAIL) + 1)):
				var delta := origin + Vector2(x, z) * DETAIL - Vector2(p.x, p.z)
				var distance := Vector2(delta.dot(side) / width, delta.dot(dir) / length).length()
				var irregularity := 1.0 + 0.10 * sin(delta.x * 11.7 + p.z * 0.14) * cos(delta.y * 8.7 + p.x * 0.12)
				var radius := distance * irregularity
				if radius > 1.7:
					continue
				var outward := delta.normalized() if delta.length_squared() > 0.0001 else Vector2.ZERO
				var press := 1.0 - smoothstep(0.45, 1.05, radius)
				var spill_bias := clampf(0.40 + 0.75 * outward.dot(downhill) + 0.35 * absf(outward.dot(side)) + 0.15 * outward.dot(dir), 0.08, 1.5)
				var spill := exp(-pow((radius - 1.13) * 3.0, 2.0)) * spill_bias
				if press < 0.001 and spill < 0.001:
					continue
				if not affected.has(key):
					affected[key] = []
				affected[key].append([z * RES + x, press, spill, exp(-radius * radius * 3.5) * 0.65])
				removed += press
				displaced += spill
	var spill_scale := removed * 0.75 / maxf(displaced, 0.0001)
	for key in affected:
		var record: Dictionary = history[key]
		var depths: PackedFloat32Array = record.depth
		var glow_values: PackedFloat32Array = record.glow
		var compaction: PackedFloat32Array = record.compaction
		for point in affected[key]:
			var i: int = point[0]
			depths[i] = clampf(depths[i] + depth * (-float(point[1]) + float(point[2]) * spill_scale), -0.32, 0.14)
			glow_values[i] = maxf(glow_values[i], float(point[3]))
			compaction[i] = maxf(compaction[i], clampf(float(point[1]) * 0.9 + float(point[2]) * 0.15, 0.0, 1.0))
		record.compaction = compaction
		record.depth = depths
		record.glow = glow_values
		record.stamp_time = clock
		_rebuild(key)
	_wake_sand(p, extent * 1.25, 1.8 + minf(Vector2(surface_normal.x, surface_normal.z).length() * 2.0, 1.5))
	if not affected.is_empty():
		_sand_burst(p, direction, clampf(depth / 0.105, 0.7, 2.0), false)

func _flow_patch(point: Vector2i) -> Vector2i:
	return Vector2i(floori(float(point.x) / FLOW_SPAN), floori(float(point.y) / FLOW_SPAN))

func _flow_index(point: Vector2i, patch: Vector2i) -> int:
	return (point.y - patch.y * FLOW_SPAN) * RES + point.x - patch.x * FLOW_SPAN

func _flow_height(point: Vector2i) -> float:
	var patch := _flow_patch(point)
	if not active.has(patch):
		return INF
	var record: Dictionary = history[patch]
	var index := _flow_index(point, patch)
	var base: PackedVector3Array = record.base_vertices
	var depths: PackedFloat32Array = record.depth
	return base[index].y + depths[index]

func _flow_base(point: Vector2i) -> float:
	var patch := _flow_patch(point)
	var record: Dictionary = history[patch]
	var base: PackedVector3Array = record.base_vertices
	return base[_flow_index(point, patch)].y

func _wake_sand(point: Vector3, radius: float, lifetime: float) -> void:
	var center := Vector2i(roundi(point.x / DETAIL), roundi(point.z / DETAIL))
	var cells := ceili(radius / DETAIL)
	for z in range(-cells, cells + 1):
		for x in range(-cells, cells + 1):
			if Vector2(x, z).length() * DETAIL > radius:
				continue
			var position := center + Vector2i(x, z)
			if not active.has(_flow_patch(position)):
				continue
			if flowing.size() < FLOW_LIMIT or flowing.has(position):
				flowing[position] = maxf(float(flowing.get(position, 0.0)), lifetime)

func _apply_flow(point: Vector2i, amount: float, changed: Dictionary) -> void:
	var patch := _flow_patch(point)
	var xs := [patch.x]
	var zs := [patch.y]
	if point.x == patch.x * FLOW_SPAN:
		xs.append(patch.x - 1)
	if point.y == patch.y * FLOW_SPAN:
		zs.append(patch.y - 1)
	for z in zs:
		for x in xs:
			var tile := Vector2i(x, z)
			if not history.has(tile):
				continue
			var record: Dictionary = history[tile]
			var depths: PackedFloat32Array = record.depth
			var index := _flow_index(point, tile)
			depths[index] = clampf(depths[index] + amount, -0.32, 0.14)
			record.depth = depths
			if active.has(tile):
				changed[tile] = true

func _simulate_flow(delta: float) -> void:
	if flowing.is_empty():
		return
	var changes: Dictionary = {}
	var awaken: Dictionary = {}
	for point: Vector2i in flowing.keys():
		var life := float(flowing[point]) - delta
		if life <= 0.0 or not active.has(_flow_patch(point)):
			flowing.erase(point)
			continue
		flowing[point] = life
		var source := _flow_height(point)
		var best := point
		var best_excess := 0.0
		for direction: Vector2i in FLOW_NEIGHBORS:
			var neighbor := point + direction
			var destination := _flow_height(neighbor)
			if not is_finite(destination):
				continue
			var excess := source - destination - 0.19 * DETAIL * Vector2(direction).length()
			if excess > best_excess:
				best_excess = excess
				best = neighbor
		if best == point:
			continue
		var loose := maxf(0.0, source - _flow_base(point))
		var slope_normal := normal_at(point.x * DETAIL, point.y * DETAIL)
		var steepness := smoothstep(0.24, 0.68, Vector2(slope_normal.x, slope_normal.z).length())
		var room := maxf(0.0, _flow_base(best) + 0.14 - _flow_height(best))
		var amount := minf(minf(best_excess * (0.14 + steepness * 0.10), 0.013 + steepness * 0.010), minf(loose * 0.24, room * 0.20))
		if amount < 0.0005:
			continue
		changes[point] = float(changes.get(point, 0.0)) - amount
		changes[best] = float(changes.get(best, 0.0)) + amount
		awaken[best] = maxf(float(awaken.get(best, 0.0)), life - 0.04)
	var dirty: Dictionary = {}
	for point: Vector2i in changes:
		_apply_flow(point, float(changes[point]), dirty)
	for point: Vector2i in awaken:
		if flowing.size() < FLOW_LIMIT or flowing.has(point):
			flowing[point] = maxf(float(flowing.get(point, 0.0)), float(awaken[point]))
	for key: Vector2i in dirty:
		_rebuild(key)

func drag_sand(point: Vector3, direction: Vector3, strength: float) -> void:
	if clock - last_drag_time < 0.09:
		return
	var movement := Vector2(direction.x, direction.z)
	var power := clampf(strength, 0.0, 1.0)
	if movement.length_squared() < 0.0001 or power <= 0.0:
		return
	movement = movement.normalized()
	var offset := Vector2i(roundi(movement.x * 3.0), roundi(movement.y * 3.0))
	if offset == Vector2i.ZERO:
		return
	var center := Vector2i(roundi(point.x / DETAIL), roundi(point.z / DETAIL))
	var changes: Dictionary = {}
	for z in range(-3, 4):
		for x in range(-3, 4):
			var weight := maxf(0.0, 1.0 - Vector2(x, z).length() / 3.2)
			if weight <= 0.0:
				continue
			var source := center + Vector2i(x, z)
			var destination := source + offset
			var source_height := _flow_height(source)
			var destination_height := _flow_height(destination)
			if not is_finite(source_height) or not is_finite(destination_height):
				continue
			var available := maxf(0.0, source_height - _flow_base(source) + 0.32)
			var room := maxf(0.0, _flow_base(destination) + 0.14 - destination_height)
			var amount := minf(0.045 * weight * power, minf(available * 0.2, room * 0.35))
			if amount < 0.0005:
				continue
			changes[source] = float(changes.get(source, 0.0)) - amount
			changes[destination] = float(changes.get(destination, 0.0)) + amount
	if changes.is_empty():
		return
	last_drag_time = clock
	var dirty: Dictionary = {}
	for key: Vector2i in changes:
		_apply_flow(key, float(changes[key]), dirty)
	for key: Vector2i in dirty:
		_rebuild(key)
	_wake_sand(point + Vector3(movement.x, 0.0, movement.y) * 0.4, 1.5, 2.4)
	_sand_burst(point, direction, 0.9 + power * 0.4, true)

func _process(delta: float) -> void:
	clock += delta
	flow_clock += delta
	if flow_clock >= FLOW_INTERVAL:
		flow_clock = fmod(flow_clock, FLOW_INTERVAL)
		_simulate_flow(FLOW_INTERVAL)
	settle_clock += delta
	if settle_clock > 0.18 and not active.is_empty():
		settle_clock = 0
		settle_index = (settle_index + 1) % active.size()
		var key: Vector2i = active.keys()[settle_index]
		if history[key].glow.count(0.0) != RES * RES:
			_rebuild(key)
	if history.size() > 256:
		var candidates := history.keys().filter(func(key): return not active.has(key))
		candidates.sort_custom(func(a,b): return history[a].time < history[b].time)
		for i in mini(history.size() - 256, candidates.size()):
			history.erase(candidates[i])
