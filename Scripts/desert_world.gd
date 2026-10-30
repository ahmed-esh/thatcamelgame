extends Node3D

@onready var sand: SandTerrain = $Sand
var traveler: DesertTraveler
var stone_material: Material
var gold_material: Material
var rng := RandomNumberGenerator.new()
var capture_frames := 0
var capture_path := ""
var floating_shards: Array[MeshInstance3D] = []
var magic_time := 0.0

func _ready() -> void:
    rng.seed = 24
    configure_input()
    if not has_node("Scenery"):
        build_light()
    stone_material = make_toon_material(Color("535978"))
    gold_material = make_toon_material(Color("49b9b0"), 0.55)
    traveler = DesertTraveler.new()
    traveler.sand = sand
    traveler.position = Vector3(6.0, sand.height_at(Vector3(6.0, 0.0, 32.0)) + 1.0, 32.0)
    add_child(traveler)
    sand.set_camera(traveler.camera)
    if not has_node("Scenery"):
        build_landmarks()
    build_dust()
    build_magic()
    for p in [Vector3(11.0, 0.0, 25.0), Vector3(2.0, 0.0, 19.0), Vector3(15.0, 0.0, 13.0)]:
        spawn_stone(p + Vector3(0.0, sand.height_at(p) + 1.8, 0.0))
    for argument in OS.get_cmdline_user_args():
        if argument.begins_with("--capture="):
            capture_path = argument.trim_prefix("--capture=")

func configure_input() -> void:
    var bindings := {
        "move_forward": [KEY_W, KEY_UP], "move_back": [KEY_S, KEY_DOWN],
        "move_left": [KEY_A, KEY_LEFT], "move_right": [KEY_D, KEY_RIGHT],
        "run": [KEY_SHIFT], "jump": [KEY_SPACE], "drop_stone": [KEY_E],
        "release_mouse": [KEY_ESCAPE], "reset_traveler": [KEY_R]
    }
    for action: String in bindings:
        if not InputMap.has_action(action):
            InputMap.add_action(action)
        for key: int in bindings[action]:
            var event := InputEventKey.new()
            event.physical_keycode = key
            InputMap.action_add_event(action, event)

func build_light() -> void:
    var environment := WorldEnvironment.new()
    var settings := Environment.new()
    settings.background_mode = Environment.BG_SKY
    var sky := Sky.new()
    var sky_material := ShaderMaterial.new()
    sky_material.shader = preload("res://Shaders/desert_sky.gdshader")
    sky.sky_material = sky_material
    settings.sky = sky
    settings.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
    settings.ambient_light_color = Color("7a75a8")
    settings.ambient_light_energy = 0.4
    settings.tonemap_mode = Environment.TONE_MAPPER_FILMIC
    settings.fog_enabled = true
    settings.fog_light_color = Color("1f244a")
    settings.fog_light_energy = 0.5
    settings.fog_density = 0.0024
    settings.fog_sky_affect = 0.0
    environment.environment = settings
    add_child(environment)
    var sun := DirectionalLight3D.new()
    sun.rotation_degrees = Vector3(-27.0, -32.0, 0.0)
    sun.light_color = Color("c7e0ff")
    sun.light_energy = 1.05
    sun.shadow_enabled = true
    sun.directional_shadow_max_distance = 150.0
    sun.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_4_SPLITS
    sun.shadow_bias = 0.04
    add_child(sun)

func make_material(color: Color) -> StandardMaterial3D:
    var material := StandardMaterial3D.new()
    material.albedo_color = color
    material.roughness = 0.88
    return material

func mesh_node(mesh: Mesh, point: Vector3, material: Material, parent: Node = self) -> MeshInstance3D:
    var node := MeshInstance3D.new()
    node.mesh = mesh
    node.position = point
    node.material_override = material
    parent.add_child(node)
    return node

func block(point: Vector3, size: Vector3, material: Material, solid: bool = true, parent: Node = self) -> MeshInstance3D:
    var mesh := BoxMesh.new()
    mesh.size = size
    var node := mesh_node(mesh, point, material, parent)
    if solid:
        var body := StaticBody3D.new()
        var collision := CollisionShape3D.new()
        var shape := BoxShape3D.new()
        shape.size = size
        collision.shape = shape
        body.add_child(collision)
        node.add_child(body)
    return node

func build_landmarks() -> void:
    build_mountain(Vector3(-8.0, -8.0, -236.0), 68.0, 110.0, Color("6b5d59"))
    build_mountain(Vector3(-62.0, -9.0, -260.0), 39.0, 105.0, Color("847b74"))
    build_mountain(Vector3(72.0, -12.0, -282.0), 48.0, 105.0, Color("8d8277"))
    var shrine_pos := Vector3(-8.0, 60.0, -236.0)
    block(shrine_pos + Vector3(-2.4, 2.0, 0.0), Vector3(2.2, 12.0, 3.8), stone_material, false)
    block(shrine_pos + Vector3(2.4, 2.0, 0.0), Vector3(2.2, 12.0, 3.8), stone_material, false)
    var beacon := make_material(Color("ffe8ac"))
    beacon.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
    block(shrine_pos + Vector3(0.0, 2.0, -0.6), Vector3(0.45, 10.0, 0.4), beacon, false)
    build_arch(Vector3(-13.0, 0.0, -32.0), -0.1, 1.0)
    build_arch(Vector3(25.0, 0.0, -109.0), 0.18, 1.4)
    for i in 11:
        var p := Vector3(-19.0 + sin(i * 0.8) * 7.0, 0.0, 6.0 - i * 12.0)
        p.y = sand.height_at(p)
        var height := rng.randf_range(1.7, 4.2)
        var pillar := block(p + Vector3(0.0, height * 0.42, 0.0), Vector3(0.8, height, 0.8), stone_material)
        pillar.rotation_degrees.z = rng.randf_range(-13.0, 13.0)
        block(Vector3(0.0, height * 0.26, -0.411), Vector3(0.38, 0.08, 0.025), gold_material, false, pillar)
    for i in 35:
        var p := Vector3(rng.randf_range(-90.0, 100.0), 0.0, rng.randf_range(-150.0, 26.0))
        p.y = sand.height_at(p) - 0.1
        var size := Vector3(rng.randf_range(0.5, 2.2), rng.randf_range(0.35, 0.8), rng.randf_range(0.5, 1.8))
        var rubble := block(p, size, stone_material)
        rubble.rotation = Vector3(rng.randf_range(-0.2, 0.2), rng.randf_range(0.0, TAU), rng.randf_range(-0.15, 0.15))

func build_arch(point: Vector3, angle: float, size: float) -> void:
    var root := Node3D.new()
    root.position = Vector3(point.x, sand.height_at(point) - 0.5, point.z)
    root.rotation.y = angle
    root.scale = Vector3.ONE * size
    add_child(root)
    for side in [-1.0, 1.0]:
        block(Vector3(side * 3.4, 3.0, 0.0), Vector3(1.65, 7.0, 2.2), stone_material, true, root)
        block(Vector3(side * 3.4, 6.3, 0.0), Vector3(2.05, 0.5, 2.55), gold_material, true, root)
        block(Vector3(side * 3.4, 0.3, 0.0), Vector3(2.1, 0.65, 2.65), stone_material, true, root)
        for i in 3:
            block(Vector3(side * 3.4, 2.2 + i * 0.55, 1.11), Vector3(0.24, 0.24, 0.035), gold_material, false, root).rotation.z = PI / 4.0
    for i in 9:
        var a := float(i) * PI / 8.0
        var wedge := block(Vector3(cos(a) * 3.4, 6.45 + sin(a) * 3.4, 0.0), Vector3(1.55, 1.0, 2.1), stone_material, true, root)
        wedge.rotation.z = a + PI / 2.0
    var banner_material := ShaderMaterial.new()
    banner_material.shader = preload("res://Shaders/cloth.gdshader")
    banner_material.set_shader_parameter("scarf", true)
    var banner := PlaneMesh.new()
    banner.size = Vector2(0.85, 4.5)
    banner.subdivide_depth = 24
    banner.orientation = PlaneMesh.FACE_Z
    var flag := mesh_node(banner, Vector3(3.4, 4.0, 1.3), banner_material, root)
    flag.rotation.z = -0.08

func build_mountain(point: Vector3, height: float, radius: float, color: Color) -> void:
    var surface := SurfaceTool.new()
    surface.begin(Mesh.PRIMITIVE_TRIANGLES)
    var rings := 14
    var segments := 70
    for ring in rings:
        for segment in segments:
            for corner in [Vector2i(0, 0), Vector2i(1, 0), Vector2i(1, 1), Vector2i(0, 0), Vector2i(1, 1), Vector2i(0, 1)]:
                var t := float(ring + corner.x) / rings
                var angle := float(segment + corner.y) / segments * TAU
                var r := radius * t
                var ridge := sin(angle * 7.0 + t * 4.0) * 0.065 + sin(angle * 13.0) * 0.025
                var h := height * pow(1.0 - t, 1.5) + ridge * height * sin(t * PI)
                surface.add_vertex(Vector3(cos(angle) * r, h, sin(angle) * r * 0.65))
    surface.generate_normals()
    var material := make_material(color)
    material.cull_mode = BaseMaterial3D.CULL_DISABLED
    mesh_node(surface.commit(), point, material)

func build_dust() -> void:
    var dust := GPUParticles3D.new()
    dust.name = "WindblownSand"
    dust.amount = 500
    dust.lifetime = 9.0
    dust.preprocess = 9.0
    dust.visibility_aabb = AABB(Vector3(-90.0, -15.0, -90.0), Vector3(180.0, 60.0, 180.0))
    var process := ParticleProcessMaterial.new()
    process.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
    process.emission_box_extents = Vector3(65.0, 5.0, 65.0)
    process.direction = Vector3(1.0, 0.05, 0.2)
    process.spread = 8.0
    process.initial_velocity_min = 2.5
    process.initial_velocity_max = 5.5
    process.gravity = Vector3.ZERO
    process.scale_min = 0.2
    process.scale_max = 1.3
    var gradient := Gradient.new()
    gradient.set_color(0, Color(1.0, 1.0, 1.0, 0.0))
    gradient.add_point(0.2, Color.WHITE)
    gradient.add_point(0.7, Color.WHITE)
    gradient.set_color(1, Color(1.0, 1.0, 1.0, 0.0))
    var texture := GradientTexture1D.new()
    texture.gradient = gradient
    process.color_ramp = texture
    dust.process_material = process
    var quad := QuadMesh.new()
    quad.size = Vector2(1.0, 0.13)
    var material := ShaderMaterial.new()
    material.shader = preload("res://Shaders/dust.gdshader")
    quad.material = material
    dust.draw_pass_1 = quad
    dust.position.y = 5.0
    traveler.add_child(dust)

func spawn_stone(point: Vector3) -> SandBody:
    var stone := SandBody.new()
    stone.mass = 8.0
    stone.position = point
    var sphere := SphereMesh.new()
    sphere.radius = 0.65
    sphere.height = 1.3
    sphere.radial_segments = 16
    sphere.rings = 8
    mesh_node(sphere, Vector3.ZERO, stone_material, stone)
    var shape := SphereShape3D.new()
    shape.radius = 0.65
    var collision := CollisionShape3D.new()
    collision.shape = shape
    stone.add_child(collision)
    var physics := PhysicsMaterial.new()
    physics.friction = 0.8
    physics.bounce = 0.1
    stone.physics_material_override = physics
    add_child(stone)
    return stone

func _unhandled_input(event: InputEvent) -> void:
    if event.is_action_pressed("drop_stone") and get_tree().get_nodes_in_group("sand_objects").size() < 32:
        var forward := Vector3.FORWARD.rotated(Vector3.UP, traveler.yaw)
        var stone := spawn_stone(traveler.global_position + forward * 2.0 + Vector3.UP * 2.5)
        stone.linear_velocity = forward * 3.0

func _process(delta: float) -> void:
    magic_time += delta
    for i in floating_shards.size():
        var shard := floating_shards[i]
        var base: Vector3 = shard.get_meta("anchor")
        shard.position = base + Vector3.UP * sin(magic_time * 0.75 + i * 1.7) * 0.35
        shard.rotation.y += delta * 0.3
    if capture_path.is_empty():
        return
    capture_frames += 1
    if capture_frames == 100:
        await RenderingServer.frame_post_draw
        get_viewport().get_texture().get_image().save_png(capture_path)
        get_tree().quit()

func make_toon_material(color: Color, glow: float = 0.0) -> ShaderMaterial:
    var material := ShaderMaterial.new()
    material.shader = preload("res://Shaders/toon_stone.gdshader")
    material.set_shader_parameter("stone_color", color)
    material.set_shader_parameter("glow_strength", glow)
    return material

func build_magic() -> void:
    var crystal_material := make_toon_material(Color("68bbcb"), 0.65)
    for i in 9:
        var point := Vector3(-14.0 + sin(i * 1.9) * 5.0, 0.0, 16.0 - i * 16.0)
        point.y = sand.height_at(point) + 2.3 + sin(i * 1.5)
        var crystal := PrismMesh.new()
        crystal.size = Vector3(0.28, 0.85, 0.28)
        var shard := mesh_node(crystal, point, crystal_material)
        shard.set_meta("anchor", point)
        shard.rotation.z = 0.2
        floating_shards.append(shard)
        var halo := QuadMesh.new()
        halo.size = Vector2(1.5, 1.5)
        var halo_material := ShaderMaterial.new()
        halo_material.shader = preload("res://Shaders/magic_particle.gdshader")
        halo_material.set_shader_parameter("intensity", 0.2)
        mesh_node(halo, Vector3.ZERO, halo_material, shard)
    for point in [Vector3(-13.0, 0.0, -32.0), Vector3(25.0, 0.0, -109.0)]:
        var lamp := OmniLight3D.new()
        lamp.position = point + Vector3.UP * (sand.height_at(point) + 5.0)
        lamp.light_color = Color("62d8db")
        lamp.light_energy = 1.8
        lamp.omni_range = 14.0
        add_child(lamp)
    var beam := PlaneMesh.new()
    beam.orientation = PlaneMesh.FACE_Z
    beam.size = Vector2(9.0, 65.0)
    var beam_material := ShaderMaterial.new()
    beam_material.shader = preload("res://Shaders/beacon.gdshader")
    var beacon := mesh_node(beam, Vector3(-8.0, 95.0, -236.0), beam_material)
    beacon.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
    var motes := GPUParticles3D.new()
    motes.amount = 100
    motes.lifetime = 8.0
    motes.preprocess = 8.0
    motes.visibility_aabb = AABB(Vector3(-35.0, -10.0, -35.0), Vector3(70.0, 40.0, 70.0))
    var process := ParticleProcessMaterial.new()
    process.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
    process.emission_box_extents = Vector3(26.0, 4.0, 26.0)
    process.direction = Vector3(0.5, 1.0, 0.0)
    process.spread = 40.0
    process.initial_velocity_min = 0.15
    process.initial_velocity_max = 0.5
    process.gravity = Vector3.ZERO
    process.scale_min = 0.06
    process.scale_max = 0.18
    var gradient := Gradient.new()
    gradient.set_color(0, Color(1.0, 1.0, 1.0, 0.0))
    gradient.add_point(0.25, Color.WHITE)
    gradient.add_point(0.65, Color.WHITE)
    gradient.set_color(1, Color(1.0, 1.0, 1.0, 0.0))
    var fade := GradientTexture1D.new()
    fade.gradient = gradient
    process.color_ramp = fade
    motes.process_material = process
    var quad := QuadMesh.new()
    quad.size = Vector2.ONE
    var mote_material := ShaderMaterial.new()
    mote_material.shader = preload("res://Shaders/magic_particle.gdshader")
    quad.material = mote_material
    motes.draw_pass_1 = quad
    motes.position.y = 3.0
    traveler.add_child(motes)
