extends SceneTree

var failures: Array[String] = []

func _initialize() -> void:
    call_deferred("run")

func check(condition: bool, message: String) -> void:
    if not condition:
        failures.append(message)
        push_error(message)

func run() -> void:
    var scene: Node3D = load("res://Scenes/main.tscn").instantiate()
    root.add_child(scene)
    current_scene = scene
    var sand: SandTerrain = scene.sand
    var player: DesertTraveler = scene.traveler
    check(sand.data.get_region_count() == 64, "Expected 64 editable terrain regions")
    var point := Vector3(0.0, 0.0, 32.0)
    var original := sand.height_at(point)
    sand.stamp(point, Vector2(0.6, 0.6), 0.2)
    sand.flush_deformation()
    check(sand.height_at(point) < original - 0.15, "Sand must physically depress at a region boundary")
    var depressed := sand.height_at(point)
    for i in 20:
        sand.stamp(point, Vector2(0.6, 0.6), 0.2)
    sand.flush_deformation()
    check(absf(sand.height_at(point) - depressed) < 0.01, "Repeated contact must not drill through the terrain")
    for i in 80:
        await physics_frame
    check(player.is_on_floor(), "Traveler must settle onto terrain collision")
    var start := player.global_position
    var edits_before := sand.original_heights.size()
    Input.action_press("move_forward")
    for i in 150:
        await physics_frame
    Input.action_release("move_forward")
    print("WALK: ", start, " -> ", player.global_position, " edits ", edits_before, " -> ", sand.original_heights.size(), " floor ", player.is_on_floor(), " velocity ", player.velocity)
    check(player.global_position.distance_to(start) > 4.0, "Traveler must move over the dunes")
    check(sand.original_heights.size() > edits_before + 20, "Walking must leave a sequence of impressions")
    for i in 30:
        await physics_frame
    Input.action_press("jump")
    await physics_frame
    await physics_frame
    Input.action_release("jump")
    check(player.velocity.y > 0.0, "Jump must lift the traveler")
    for i in 100:
        await physics_frame
    check(player.is_on_floor(), "Traveler must land after jumping")
    var stone_point := player.global_position + Vector3(2.0, 3.0, 0.0)
    var stone: SandBody = scene.spawn_stone(stone_point)
    for i in 140:
        await physics_frame
    check(stone.last_stamp.is_finite(), "Rigid objects must leave sand impressions on contact")
    var query := PhysicsRayQueryParameters3D.create(point + Vector3.UP * (original + 3.0), point + Vector3.UP * (original - 3.0))
    var hit := player.get_world_3d().direct_space_state.intersect_ray(query)
    check(not hit.is_empty(), "Terrain must retain collision after deformation")
    if not hit.is_empty():
        check(absf(hit.position.y - sand.height_at(point)) < 0.08, "Collision must match the deformed height")
    print("DESERT_CHECKS: ", "PASS" if failures.is_empty() else failures)
    quit(0 if failures.is_empty() else 1)
