class_name SandTerrain
extends Terrain3D

const SPACING := 0.25
const EXTENT := 256.0
var changed_regions: Dictionary = {}
var changed_collision_tiles: Dictionary = {}
var original_heights: Dictionary = {}
var flush_clock := 0.0
var noise := FastNoiseLite.new()
var active_sand: Dictionary = {}
var glow_cells: Dictionary = {}
var disturbance_image: Image
var disturbance_texture: ImageTexture
var transported_volume := 0.0
var flow_enabled := true
const FLOW_LIMIT := 1800
const FLOW_STEP := 0.1
const NEIGHBORS := [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1), Vector2i(1, 1), Vector2i(-1, 1), Vector2i(1, -1), Vector2i(-1, -1)]

func _ready() -> void:
    add_to_group("deformable_sand")
    noise.seed = 81
    noise.frequency = 0.012
    noise.fractal_octaves = 3
    collision.radius = 128
    disturbance_image = Image.create_empty(1024, 1024, false, Image.FORMAT_R8)
    disturbance_texture = ImageTexture.create_from_image(disturbance_image)
    material.set_shader_param("disturbance_map", disturbance_texture)
    if data.get_region_count() > 0:
        return
    vertex_spacing = SPACING
    region_size = 256
    mesh_size = 64
    mesh_lods = 8
    cull_margin = 80.0
    collision.mode = Terrain3DCollision.DYNAMIC_GAME
    collision.radius = 128
    var texture_asset := Terrain3DTextureAsset.new()
    texture_asset.name = "Golden Sand"
    var texture_image := Image.create_empty(4, 4, false, Image.FORMAT_RGBA8)
    texture_image.fill(Color(0.8, 0.55, 0.28, 1.0))
    texture_image.generate_mipmaps()
    texture_asset.albedo_texture = ImageTexture.create_from_image(texture_image)
    assets.set_texture(0, texture_asset)
    material.show_checkered = false
    material.world_background = Terrain3DMaterial.NONE
    material.shader_override = preload("res://Shaders/sand.gdshader")
    material.shader_override_enabled = true
    noise.seed = 81
    noise.frequency = 0.012
    noise.fractal_octaves = 3
    var heightmap := Image.create_empty(2048, 2048, false, Image.FORMAT_RF)
    for z in 2048:
        for x in 2048:
            var world_x := x * SPACING - EXTENT
            var world_z := z * SPACING - EXTENT
            heightmap.set_pixel(x, z, Color(dune_height(world_x, world_z), 0.0, 0.0))
    data.import_images([heightmap, null, null], Vector3(-EXTENT, 0.0, -EXTENT), 0.0, 1.0)
    material.set_shader_param("disturbance_map", disturbance_texture)

func dune_height(x: float, z: float) -> float:
    var bend := sin(z * 0.018) * 14.0 + sin(z * 0.043) * 4.0
    var wave := sin((x + bend) * 0.047 + z * 0.032)
    var ridges := pow(wave * 0.5 + 0.5, 2.8) * 11.0
    var rolling := sin(z * 0.031 - x * 0.012) * 3.5
    var detail := noise.get_noise_2d(x, z) * 3.2
    return ridges + rolling + detail

func height_at(point: Vector3) -> float:
    var h := data.get_height(point)
    return h if is_finite(h) else dune_height(point.x, point.z)

func stamp(point: Vector3, radius: Vector2, depth: float, angle: float = 0.0) -> void:
    if absf(point.x) > EXTENT - 2.0 or absf(point.z) > EXTENT - 2.0:
        return
    wake_sand(point, maxf(radius.x, radius.y) + 0.6, 1.0)
    illuminate(point, maxf(radius.x, radius.y) + 0.35, 0.8)
    var reach := maxf(radius.x, radius.y) * 1.35
    var center := Vector2i(roundi(point.x / SPACING), roundi(point.z / SPACING))
    var cells := ceili(reach / SPACING)
    for z in range(-cells, cells + 1):
        for x in range(-cells, cells + 1):
            var key := center + Vector2i(x, z)
            var sample_point := Vector3(key.x * SPACING, 0.0, key.y * SPACING)
            var offset := Vector2(sample_point.x - point.x, sample_point.z - point.z).rotated(-angle)
            var distance := (offset / radius).length()
            if distance > 1.3:
                continue
            var current := data.get_height(sample_point)
            if not is_finite(current):
                continue
            if not original_heights.has(key):
                original_heights[key] = current
            var baseline: float = original_heights[key]
            var depression := depth * (1.0 - smoothstep(0.15, 1.0, distance))
            var rim := depth * 0.16 * exp(-pow((distance - 1.04) * 8.0, 2.0))
            var target := baseline - depression + rim
            var updated := minf(current, target) if distance < 0.95 else maxf(current, target)
            if absf(updated - current) < 0.001:
                continue
            set_cell_height(key, updated)

func flush_deformation() -> void:
    if changed_regions.is_empty():
        return
    data.update_maps(Terrain3DRegion.TYPE_HEIGHT, false, false)
    refresh_changed_collision()
    for region: Terrain3DRegion in changed_regions.values():
        region.set_edited(false)
    changed_regions.clear()

func _physics_process(delta: float) -> void:
    flush_clock += delta
    if flush_clock >= FLOW_STEP:
        flush_clock = 0.0
        if flow_enabled:
            simulate_flow(FLOW_STEP)
        fade_disturbance(FLOW_STEP)
        flush_deformation()

func cell_position(key: Vector2i) -> Vector3:
    return Vector3(key.x * SPACING, 0.0, key.y * SPACING)

func cell_height(key: Vector2i) -> float:
    return data.get_pixel(Terrain3DRegion.TYPE_HEIGHT, cell_position(key)).r

func remember_cell(key: Vector2i) -> float:
    if not original_heights.has(key):
        original_heights[key] = cell_height(key)
    return original_heights[key]

func set_cell_height(key: Vector2i, height: float) -> void:
    var point := cell_position(key)
    var region := data.get_regionp(point)
    if region == null or not is_finite(height):
        return
    data.set_height(point, height)
    region.set_edited(true)
    changed_regions[region.location] = region
    var size := collision.shape_size
    for z in [-1, 0]:
        for x in [-1, 0]:
            var tile := Vector2i(floori(float(key.x + x) / size), floori(float(key.y + z) / size))
            changed_collision_tiles[tile] = true

func refresh_changed_collision() -> void:
    var body := collision.get_rid()
    if not body.is_valid():
        return
    collision.update()
    var size := collision.shape_size
    for index in PhysicsServer3D.body_get_shape_count(body):
        var transform := PhysicsServer3D.body_get_shape_transform(body, index)
        if absf(transform.origin.x) > 100000.0:
            continue
        var tile := Vector2i(roundi((transform.origin.x / SPACING - size * 0.5) / size), roundi((transform.origin.z / SPACING - size * 0.5) / size))
        if not changed_collision_tiles.has(tile):
            continue
        var shape := PhysicsServer3D.body_get_shape(body, index)
        var shape_data: Dictionary = PhysicsServer3D.shape_get_data(shape)
        var width: int = shape_data["width"]
        var depth: int = shape_data["depth"]
        var heights := PackedFloat32Array()
        heights.resize(width * depth)
        var minimum := INF
        var maximum := -INF
        for z in depth:
            for x in width:
                var point := transform * Vector3(x - (width - 1) * 0.5, 0.0, z - (depth - 1) * 0.5)
                point.x = snappedf(point.x, SPACING)
                point.z = snappedf(point.z, SPACING)
                var height := data.get_height(point)
                heights[z * width + x] = height
                if is_finite(height):
                    minimum = minf(minimum, height)
                    maximum = maxf(maximum, height)
        shape_data["heights"] = heights
        shape_data["min_height"] = minimum
        shape_data["max_height"] = maximum
        PhysicsServer3D.shape_set_data(shape, shape_data)
    changed_collision_tiles.clear()

func downhill_at(point: Vector3) -> Vector3:
    var distance := 1.2
    var dx := (height_at(point + Vector3.RIGHT * distance) - height_at(point + Vector3.LEFT * distance)) / (distance * 2.0)
    var dz := (height_at(point + Vector3.BACK * distance) - height_at(point + Vector3.FORWARD * distance)) / (distance * 2.0)
    return Vector3(-dx, 0.0, -dz)

func wake_sand(point: Vector3, radius: float, lifetime: float = 1.6) -> void:
    var center := Vector2i(roundi(point.x / SPACING), roundi(point.z / SPACING))
    var cells := ceili(radius / SPACING)
    for z in range(-cells, cells + 1):
        for x in range(-cells, cells + 1):
            if Vector2(x, z).length() * SPACING > radius:
                continue
            var key := center + Vector2i(x, z)
            if absi(key.x) >= 1016 or absi(key.y) >= 1016:
                continue
            if active_sand.size() < FLOW_LIMIT or active_sand.has(key):
                active_sand[key] = maxf(active_sand.get(key, 0.0), lifetime)

func simulate_flow(delta: float) -> void:
    var changes: Dictionary = {}
    var awaken: Dictionary = {}
    for key: Vector2i in active_sand.keys():
        var life: float = active_sand[key] - delta
        if life <= 0.0:
            active_sand.erase(key)
            continue
        active_sand[key] = life
        var source := cell_height(key)
        if not is_finite(source):
            active_sand.erase(key)
            continue
        var best := key
        var best_excess := 0.0
        for direction: Vector2i in NEIGHBORS:
            var neighbor := key + direction
            if absi(neighbor.x) >= 1016 or absi(neighbor.y) >= 1016:
                continue
            var target := cell_height(neighbor)
            var excess := source - target - 0.19 * SPACING * Vector2(direction).length()
            if is_finite(target) and excess > best_excess:
                best_excess = excess
                best = neighbor
        if best == key:
            continue
        var available := maxf(0.0, source - remember_cell(key) + 0.55)
        var room := maxf(0.0, remember_cell(best) + 0.65 - cell_height(best))
        var amount := minf(minf(best_excess * 0.18, 0.035), minf(available * 0.2, room * 0.125))
        if amount < 0.0005:
            continue
        changes[key] = changes.get(key, 0.0) - amount
        changes[best] = changes.get(best, 0.0) + amount
        awaken[best] = maxf(awaken.get(best, 0.0), life - 0.04)
        transported_volume += amount * SPACING * SPACING
        if amount > 0.004:
            illuminate(cell_position(best), 0.35, 0.45)
    for key: Vector2i in changes:
        set_cell_height(key, cell_height(key) + float(changes[key]))
    for key: Vector2i in awaken:
        if active_sand.size() < FLOW_LIMIT or active_sand.has(key):
            active_sand[key] = maxf(active_sand.get(key, 0.0), awaken[key])

func drag_sand(point: Vector3, direction: Vector3, strength: float) -> void:
    if direction.length_squared() < 0.01:
        return
    var center := Vector2i(roundi(point.x / SPACING), roundi(point.z / SPACING))
    var offset := Vector2i(roundi(direction.normalized().x * 3.0), roundi(direction.normalized().z * 3.0))
    var changes: Dictionary = {}
    for z in range(-3, 4):
        for x in range(-3, 4):
            var weight := maxf(0.0, 1.0 - Vector2(x, z).length() / 3.2)
            var key := center + Vector2i(x, z)
            var destination := key + offset
            if absi(destination.x) >= 1016 or absi(destination.y) >= 1016:
                continue
            var source := cell_height(key)
            var target := cell_height(destination)
            if not is_finite(source) or not is_finite(target):
                continue
            var available := maxf(0.0, source - remember_cell(key) + 0.48)
            var room := maxf(0.0, remember_cell(destination) + 0.55 - target)
            var amount := minf(0.045 * weight * clampf(strength, 0.0, 1.0), minf(available * 0.2, room * 0.2))
            changes[key] = changes.get(key, 0.0) - amount
            changes[destination] = changes.get(destination, 0.0) + amount
            transported_volume += amount * SPACING * SPACING
    for key: Vector2i in changes:
        set_cell_height(key, cell_height(key) + float(changes[key]))
    wake_sand(point + direction.normalized() * 0.6, 1.8, 2.0)
    illuminate(point, 1.1, 1.0)

func illuminate(point: Vector3, radius: float, intensity: float) -> void:
    var center := Vector2i(roundi((point.x + EXTENT) * 2.0), roundi((point.z + EXTENT) * 2.0))
    var cells := ceili(radius * 2.0)
    for z in range(-cells, cells + 1):
        for x in range(-cells, cells + 1):
            var pixel := center + Vector2i(x, z)
            if pixel.x < 0 or pixel.y < 0 or pixel.x >= 1024 or pixel.y >= 1024:
                continue
            var value := intensity * maxf(0.0, 1.0 - Vector2(x, z).length() / maxf(radius * 2.0, 1.0))
            if value > float(glow_cells.get(pixel, 0.0)):
                glow_cells[pixel] = value
                disturbance_image.set_pixelv(pixel, Color(value, 0.0, 0.0))

func fade_disturbance(delta: float) -> void:
    if glow_cells.is_empty():
        return
    for pixel: Vector2i in glow_cells.keys():
        var value := maxf(0.0, float(glow_cells[pixel]) - delta * 0.075)
        disturbance_image.set_pixelv(pixel, Color(value, 0.0, 0.0))
        if value <= 0.0:
            glow_cells.erase(pixel)
        else:
            glow_cells[pixel] = value
    disturbance_texture.update(disturbance_image)
