class_name DesertTraveler
extends CharacterBody3D

var sand: SandTerrain
var visual := Node3D.new()
var camera := Camera3D.new()
var yaw := 0.0
var pitch := 0.08
var camera_distance := 8.5
var stride := 0.0
var foot_side := 1.0
var grounded_last := false
var cloth_material: ShaderMaterial
var spawn_point := Vector3.ZERO
var sliding := false
var slide_velocity := Vector3.ZERO
var slide_clock := 0.0
var slide_spray: GPUParticles3D
var slide_sparks: GPUParticles3D
var airborne_time := 0.0

func _ready() -> void:
    name = "Traveler"
    floor_snap_length = 0.85
    floor_max_angle = deg_to_rad(52.0)
    var collider := CollisionShape3D.new()
    var capsule := CapsuleShape3D.new()
    capsule.radius = 0.3
    capsule.height = 1.65
    collider.shape = capsule
    collider.position.y = 0.86
    add_child(collider)
    add_child(visual)
    build_traveler()
    build_slide_effects()
    camera.fov = 58.0
    camera.far = 1800.0
    camera.top_level = true
    add_child(camera)
    camera.current = true
    spawn_point = position
    update_camera(1.0, true)

func build_traveler() -> void:
    cloth_material = ShaderMaterial.new()
    cloth_material.shader = preload("res://Shaders/cloth.gdshader")
    var robe := CylinderMesh.new()
    robe.top_radius = 0.23
    robe.bottom_radius = 0.67
    robe.height = 1.35
    robe.radial_segments = 48
    robe.rings = 14
    var body := MeshInstance3D.new()
    body.mesh = robe
    body.material_override = cloth_material
    body.position.y = 0.92
    visual.add_child(body)
    var hood := MeshInstance3D.new()
    var sphere := SphereMesh.new()
    sphere.radius = 0.33
    sphere.height = 0.72
    hood.mesh = sphere
    hood.scale = Vector3(0.85, 1.0, 0.9)
    hood.position = Vector3(0.0, 1.72, -0.015)
    hood.material_override = cloth_material
    visual.add_child(hood)
    var face := MeshInstance3D.new()
    var face_mesh := SphereMesh.new()
    face_mesh.radius = 0.22
    face_mesh.height = 0.45
    face.mesh = face_mesh
    face.scale = Vector3(0.8, 1.0, 0.35)
    face.position = Vector3(0.0, 1.73, -0.26)
    var dark := StandardMaterial3D.new()
    dark.albedo_color = Color("241b26")
    dark.roughness = 1.0
    face.material_override = dark
    visual.add_child(face)
    for side in [-1.0, 1.0]:
        var eye := MeshInstance3D.new()
        var eye_mesh := SphereMesh.new()
        eye_mesh.radius = 0.024
        eye_mesh.height = 0.065
        eye.mesh = eye_mesh
        eye.position = Vector3(side * 0.075, 1.77, -0.335)
        var glow := StandardMaterial3D.new()
        glow.albedo_color = Color("fff1bc")
        glow.emission_enabled = true
        glow.emission = Color("ffdc88")
        eye.material_override = glow
        visual.add_child(eye)
    var scarf := MeshInstance3D.new()
    var surface := SurfaceTool.new()
    surface.begin(Mesh.PRIMITIVE_TRIANGLES)
    for i in 40:
        var a := float(i) / 40.0
        var b := float(i + 1) / 40.0
        for uv in [Vector2(0.0, a), Vector2(1.0, a), Vector2(1.0, b), Vector2(0.0, a), Vector2(1.0, b), Vector2(0.0, b)]:
            surface.set_uv(uv)
            surface.add_vertex(Vector3((uv.x - 0.5) * (0.23 - uv.y * 0.06), 1.5 - uv.y * 0.25 + sin(uv.y * 3.0) * 0.25, 0.2 + uv.y * 3.6))
    surface.generate_normals()
    scarf.mesh = surface.commit()
    var scarf_material := ShaderMaterial.new()
    scarf_material.shader = preload("res://Shaders/cloth.gdshader")
    scarf_material.set_shader_parameter("scarf", true)
    scarf.material_override = scarf_material
    scarf.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
    visual.add_child(scarf)

func _unhandled_input(event: InputEvent) -> void:
    if event is InputEventMouseButton and event.pressed:
        if event.button_index == MOUSE_BUTTON_LEFT:
            Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
        elif event.button_index == MOUSE_BUTTON_WHEEL_UP:
            camera_distance = maxf(4.0, camera_distance - 0.5)
        elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
            camera_distance = minf(15.0, camera_distance + 0.5)
    if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
        yaw -= event.relative.x * 0.003
        pitch = clampf(pitch - event.relative.y * 0.0025, -0.65, 0.5)
    if event.is_action_pressed("release_mouse"):
        Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
    if event.is_action_pressed("reset_traveler"):
        global_position = spawn_point
        velocity = Vector3.ZERO
        slide_velocity = Vector3.ZERO
        sliding = false

func _physics_process(delta: float) -> void:
    var stick := Input.get_vector("move_left", "move_right", "move_forward", "move_back")
    var heading := Vector3(stick.x, 0.0, stick.y).rotated(Vector3.UP, yaw)
    var speed := 7.8 if Input.is_action_pressed("run") else 4.2
    var downhill := sand.downhill_at(global_position)
    var slope := downhill.length()
    var on_sand := absf(global_position.y - sand.height_at(global_position)) < 0.8
    if is_on_floor():
        airborne_time = 0.0
        if on_sand and slope > (0.17 if sliding else 0.28):
            sliding = true
        elif slope < 0.17 or not on_sand:
            sliding = false
    else:
        airborne_time += delta
        if airborne_time > 0.22:
            sliding = false
    if sliding:
        slide_velocity += downhill * 22.0 * delta
        slide_velocity = slide_velocity.move_toward(Vector3.ZERO, delta * 0.9)
        slide_velocity = slide_velocity.limit_length(13.5)
        var desired := slide_velocity + heading * 1.7
        velocity.x = move_toward(velocity.x, desired.x, delta * 11.0)
        velocity.z = move_toward(velocity.z, desired.z, delta * 11.0)
    else:
        slide_velocity = slide_velocity.move_toward(Vector3.ZERO, delta * 9.0)
        velocity.x = move_toward(velocity.x, heading.x * speed + slide_velocity.x, delta * 14.0)
        velocity.z = move_toward(velocity.z, heading.z * speed + slide_velocity.z, delta * 14.0)
    floor_stop_on_slope = not sliding
    if is_on_floor():
        velocity.y = -1.5
        if Input.is_action_just_pressed("jump"):
            velocity.y = 6.5
            sliding = false
    else:
        velocity.y -= 19.0 * delta
    move_and_slide()
    global_position.x = clampf(global_position.x, -246.0, 246.0)
    global_position.z = clampf(global_position.z, -246.0, 246.0)
    if global_position.y < -40.0:
        global_position = spawn_point
        velocity = Vector3.ZERO
    var horizontal_speed := Vector2(velocity.x, velocity.z).length()
    var facing := Vector3(velocity.x, 0.0, velocity.z) if sliding else heading
    if facing.length() > 0.1:
        visual.rotation.y = lerp_angle(visual.rotation.y, atan2(-facing.x, -facing.z), 1.0 - exp(-delta * 10.0))
    visual.rotation.x = lerpf(visual.rotation.x, -0.24 if sliding else 0.0, 1.0 - exp(-delta * 8.0))
    cloth_material.set_shader_parameter("motion", horizontal_speed / 8.0)
    visual.position.y = sin(stride * TAU / 1.45) * 0.035 if is_on_floor() else 0.06
    slide_spray.emitting = sliding and is_on_floor() and horizontal_speed > 1.2
    slide_sparks.emitting = slide_spray.emitting
    if slide_spray.emitting:
        var powder: ParticleProcessMaterial = slide_spray.process_material
        powder.direction = Vector3(velocity.x, 1.7, velocity.z).normalized()
        powder.initial_velocity_min = horizontal_speed * 0.22
        powder.initial_velocity_max = horizontal_speed * 0.42 + 1.0
        visual.position.y -= 0.15
    slide_clock += delta
    if sliding and is_on_floor() and slide_clock >= 0.1:
        slide_clock = 0.0
        sand.drag_sand(global_position, downhill, horizontal_speed / 7.0)
    if is_on_floor():
        if not grounded_last:
            sand.stamp(global_position, Vector2(0.6, 0.65), 0.16)
        stride += horizontal_speed * delta
        if stride >= 0.9 and not sliding:
            stride = fmod(stride, 0.9)
            foot_side *= -1.0
            var foot := global_position + Vector3(foot_side * 0.21, 0.0, -0.08).rotated(Vector3.UP, visual.rotation.y)
            sand.stamp(foot, Vector2(0.25, 0.43), 0.15, -visual.rotation.y)
    grounded_last = is_on_floor()
    for i in get_slide_collision_count():
        var contact := get_slide_collision(i)
        var body := contact.get_collider()
        if body is RigidBody3D:
            body.apply_central_impulse(-contact.get_normal() * 1.8)
    update_camera(delta)

func update_camera(delta: float, instant: bool = false) -> void:
    var focus := global_position + Vector3(0.0, 1.45, 0.0)
    var offset := Vector3(0.0, 2.4 - pitch * 7.0, camera_distance).rotated(Vector3.UP, yaw)
    var desired := focus + offset
    desired.y = maxf(desired.y, sand.height_at(desired) + 1.2)
    var query := PhysicsRayQueryParameters3D.create(focus, desired)
    query.exclude = [get_rid()]
    var hit := get_world_3d().direct_space_state.intersect_ray(query)
    if not hit.is_empty():
        desired = hit.position + hit.normal * 0.35
    camera.global_position = desired if instant else camera.global_position.lerp(desired, 1.0 - exp(-delta * 8.0))
    camera.look_at(focus + Vector3(0.0, 1.2, 0.0), Vector3.UP)

func build_slide_effects() -> void:
    slide_spray = create_slide_particles(150, 1.25, false)
    slide_sparks = create_slide_particles(55, 1.8, true)
    var aura := OmniLight3D.new()
    aura.position.y = 1.2
    aura.light_color = Color("5df4df")
    aura.light_energy = 0.55
    aura.omni_range = 4.0
    aura.omni_attenuation = 1.8
    add_child(aura)

func create_slide_particles(count: int, lifetime: float, sparks: bool) -> GPUParticles3D:
    var particles := GPUParticles3D.new()
    particles.amount = count
    particles.lifetime = lifetime
    particles.emitting = false
    particles.position.y = 0.22
    particles.visibility_aabb = AABB(Vector3(-10.0, -5.0, -10.0), Vector3(20.0, 14.0, 20.0))
    var process := ParticleProcessMaterial.new()
    process.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
    process.emission_sphere_radius = 0.6
    process.direction = Vector3(0.0, 0.4, 1.0)
    process.spread = 45.0
    process.initial_velocity_min = 0.8
    process.initial_velocity_max = 3.0
    process.gravity = Vector3(0.0, -2.5, 0.0)
    process.scale_min = 0.035 if sparks else 0.35
    process.scale_max = 0.10 if sparks else 0.8
    var gradient := Gradient.new()
    gradient.set_color(0, Color(1.0, 1.0, 1.0, 0.0))
    gradient.add_point(0.12, Color.WHITE)
    gradient.set_color(1, Color(1.0, 1.0, 1.0, 0.0))
    var texture := GradientTexture1D.new()
    texture.gradient = gradient
    process.color_ramp = texture
    particles.process_material = process
    var quad := QuadMesh.new()
    quad.size = Vector2.ONE
    var shader_material := ShaderMaterial.new()
    shader_material.shader = preload("res://Shaders/magic_particle.gdshader") if sparks else preload("res://Shaders/dust.gdshader")
    if not sparks:
        shader_material.set_shader_parameter("tint", Color("82b6d9"))
        shader_material.set_shader_parameter("opacity", 0.7)
    quad.material = shader_material
    particles.draw_pass_1 = quad
    add_child(particles)
    return particles
