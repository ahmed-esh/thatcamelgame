extends Node3D

const Forms = preload("res://Scripts/QuietSands/forms.gd")
const WATER_SHADER = preload("res://Shaders/QuietSands/water.gdshader")
const MAX_RIPPLES := 20


@export var terrain_path: NodePath
@export var terrain_z_offset: float = -140.0

var terrain: Node3D
var traveler: CharacterBody3D 
var water_mesh: MeshInstance3D
var water_material: ShaderMaterial
var ripples := PackedVector4Array()
var ripple_index := 0
var clock := 0.0

func _ready() -> void:
	add_to_group("oasis_water")

	if terrain == null and not terrain_path.is_empty():
		terrain = get_node_or_null(terrain_path) as Node3D

	ripples.resize(MAX_RIPPLES)
	for i in MAX_RIPPLES:
		ripples[i] = Vector4(0.0, 0.0, -100.0, 0.0)

	water_mesh = get_node_or_null("DreamingWater") as MeshInstance3D
	if water_mesh != null:
		# Preserve any existing material settings, but avoid accidentally modifying
		# the material resource of another mesh instance.
		var existing := water_mesh.material_override as ShaderMaterial
		if existing != null:
			water_material = existing.duplicate() as ShaderMaterial
		else:
			water_material = ShaderMaterial.new()
		water_material.shader = WATER_SHADER
		water_mesh.material_override = water_material
		# The authored scene already has its water/props. Preserve the original
		# behavior of not procedurally creating palms and lights again.
		return

	water_material = ShaderMaterial.new()
	water_material.shader = WATER_SHADER

	var vertices := PackedVector3Array()
	var ids := PackedInt32Array()
	var colors := PackedColorArray()
	for z in 81:
		for x in 111:
			var p := Vector3(float(x - 55), 0.0, float(z - 40))
			vertices.append(p)
			var h: float = float(terrain.call("base_height", p.x, p.z + terrain_z_offset)) if terrain != null else -2.0
			colors.append(Color(clampf(-h / 1.65, 0.0, 1.0), 0.0, 0.0, 1.0))
			if x < 110 and z < 80:
				var i := z * 111 + x
				ids.append_array(PackedInt32Array([i, i + 1, i + 111, i + 1, i + 112, i + 111]))

	var mesh := Forms.surface(vertices, ids)
	var arrays := mesh.surface_get_arrays(0)
	arrays[Mesh.ARRAY_COLOR] = colors
	var water := ArrayMesh.new()
	water.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	Forms.add_mesh(self, water, water_material, Vector3.ZERO, false, "DreamingWater")
	water_mesh = get_node_or_null("DreamingWater") as MeshInstance3D
	if water_mesh != null:
		water_mesh.material_override = water_material

	var palm_scene: PackedScene = load("res://Scenes/QuietSands/palm.tscn")
	var positions := [Vector2(-44, -16), Vector2(-31, -31), Vector2(-13, -40), Vector2(12, -38), Vector2(37, -24), Vector2(50, -2), Vector2(43, 22), Vector2(23, 33), Vector2(4, 43), Vector2(-20, 36), Vector2(-45, 18), Vector2(-51, 2), Vector2(34, 36)]
	for i in 13:
		var p: Vector2 = positions[i]
		var palm := palm_scene.instantiate()
		palm.name = "Palm_%02d" % (i + 1)
		palm.variation = i
		palm.position = Vector3(p.x, float(terrain.call("base_height", p.x, p.y + terrain_z_offset)) - 0.1 if terrain != null else 0.0, p.y)
		palm.rotation.y = i * 2.399
		palm.scale = Vector3.ONE * (0.9 + sin(i * 3.5) * 0.19)
		add_child(palm)

	for p in [Vector3(-29, 2, -10), Vector3(28, 2, 11)]:
		var light := OmniLight3D.new()
		light.position = p
		light.light_color = Color(0.07, 0.62, 0.66)
		light.light_energy = 0.6
		light.omni_range = 26
		add_child(light)

func _process(delta: float) -> void:
	clock += delta
	if water_material == null:
		return
	water_material.set_shader_parameter("ripples", ripples)
	water_material.set_shader_parameter("water_clock", clock)

func get_water_level() -> float:
	if water_mesh == null:
		return global_position.y
	return water_mesh.to_global(Vector3.ZERO).y

func is_water_contact(world_point: Vector3) -> bool:
	if water_mesh == null:
		return false

	# Mesh is 110 by 80 units, centered at its local origin.
	var p: Vector3 = water_mesh.to_local(world_point)
	if absf(p.x) > 55.0 or absf(p.z) > 40.0:
		return false

	var colors: PackedColorArray = water_mesh.mesh.surface_get_arrays(0)[Mesh.ARRAY_COLOR]
	var x := clampf(p.x + 55.0, 0.0, 109.9999)
	var z := clampf(p.z + 40.0, 0.0, 79.9999)
	var i := int(z) * 111 + int(x)
	var u := x - int(x)
	var v := z - int(z)
	var depth := colors[i].r + (colors[i + 1].r - colors[i].r) * u + (colors[i + 111].r - colors[i].r) * v if u + v < 1.0 else colors[i + 112].r + (colors[i + 111].r - colors[i + 112].r) * (1.0 - u) + (colors[i + 1].r - colors[i + 112].r) * (1.0 - v)
	if depth < 0.005:
		return false

	# Allow feet/hooves to be submerged but not several meters above water.
	var level := water_mesh.to_global(Vector3(p.x, 0.0, p.z)).y
	if world_point.y > level + 0.25 or world_point.y < level - 3.0:
		return false

	if terrain != null and terrain.has_method("base_height"):
		var ground: float = float(terrain.call("base_height", world_point.x, world_point.z))
		if ground >= level - 0.03:
			return false

	return true

func add_ripple(world_point: Vector3, strength: float = 1.0) -> bool:
	if not is_water_contact(world_point):
		return false

	# Shader uses DreamingWater's local vertex coordinates, not global X/Z.
	var p: Vector3 = water_mesh.to_local(world_point)
	ripples[ripple_index] = Vector4(p.x, p.z, clock, clampf(strength, 0.1, 2.5))
	ripple_index = (ripple_index + 1) % MAX_RIPPLES
	return true
