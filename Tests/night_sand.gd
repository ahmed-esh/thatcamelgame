extends SceneTree

var failures: Array[String] = []

func _initialize() -> void:
    call_deferred("run")

func check(condition: bool, message: String) -> void:
    if not condition:
        failures.append(message)
        push_error(message)

func sum_patch(sand: SandTerrain, center: Vector2i, radius: int) -> float:
    var total := 0.0
    for z in range(-radius, radius + 1):
        for x in range(-radius, radius + 1):
            total += sand.cell_height(center + Vector2i(x, z))
    return total

func run() -> void:
    var scene: Node3D = load("res://Scenes/main.tscn").instantiate()
    root.add_child(scene)
    current_scene = scene
    var sand: SandTerrain = scene.sand
    var player: DesertTraveler = scene.traveler
    sand.set_physics_process(false)
    var center := Vector2i(160, 160)
    for z in range(-25, 26):
        for x in range(-25, 26):
            sand.set_cell_height(center + Vector2i(x, z), 15.0 - x * 0.12)
    sand.flush_deformation()
    sand.original_heights.clear()
    var before := sum_patch(sand, center, 25)
    var source_before := sand.cell_height(center)
    sand.wake_sand(sand.cell_position(center), 1.4, 1.0)
    for i in 8:
        sand.simulate_flow(0.1)
    var after := sum_patch(sand, center, 25)
    check(absf(after - before) < 0.005, "Avalanche transport must conserve sand volume")
    check(sand.transported_volume > 0.01, "Disturbed slopes must transfer sand downhill")
    check(sand.cell_height(center) != source_before, "Flow must change actual terrain heights")
    before = after
    sand.drag_sand(sand.cell_position(center), Vector3.RIGHT, 1.0)
    after = sum_patch(sand, center, 25)
    check(absf(after - before) < 0.005, "Dragging must move sand without destroying it")
    for i in 40:
        sand.simulate_flow(0.1)
    check(sand.active_sand.is_empty(), "An undisturbed avalanche must settle")
    sand.flush_deformation()
    sand.set_physics_process(true)
    var start := sand.cell_position(center) + Vector3.UP * (sand.cell_height(center) + 0.5)
    player.global_position = start
    player.velocity = Vector3.ZERO
    player.slide_velocity = Vector3.ZERO
    player.update_camera(1.0, true)
    sand.collision.update(true)
    var saw_slide := false
    var saw_spray := false
    for i in 85:
        await physics_frame
        saw_slide = saw_slide or player.sliding
        saw_spray = saw_spray or player.slide_spray.emitting
    check(saw_slide, "A traveler standing on a steep slope must start slipping")
    check(saw_spray, "Sliding must emit a sand spray")
    check(player.position.x > start.x + 1.0, "The traveler must move downhill without movement input")
    check(player.position.y > sand.height_at(player.position) - 0.5, "Sliding must stay above the changing collision surface")
    var point := Vector3(40.0, 0.0, 40.0)
    sand.flush_deformation()
    await physics_frame
    var query := PhysicsRayQueryParameters3D.create(point + Vector3.UP * 25.0, point + Vector3.UP * 8.0)
    var hit := player.get_world_3d().direct_space_state.intersect_ray(query)
    check(not hit.is_empty(), "Updated collision must exist at tile boundaries")
    if not hit.is_empty():
        check(absf(hit.position.y - sand.height_at(point)) < 0.08, "Updated collision must match the moving sand height")
    check(not sand.glow_cells.is_empty(), "Disturbed sand must leave luminous traces")
    for i in 140:
        sand.fade_disturbance(0.1)
    check(sand.glow_cells.is_empty(), "Sand luminescence must fade away")
    print("NIGHT_SAND_CHECKS: ", "PASS" if failures.is_empty() else failures)
    quit(0 if failures.is_empty() else 1)
