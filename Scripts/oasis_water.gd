extends MeshInstance3D

@export var terrain: MeshInstance3D
@export var sample_interval := 0.1
@export var water_depth := 3.0
@export var movement_threshold := 0.18
var tracked: Dictionary = {}
var ripples := PackedVector4Array()
var ripple_index := 0
var elapsed := 0.0
var sample_clock := 0.0
var primed := false

func _ready() -> void:
    material_override = material_override.duplicate()
    ripples.resize(12)
    for i in ripples.size():
        ripples[i] = Vector4(0.0, 0.0, -10.0, 0.0)
    call_deferred("prime")

func prime() -> void:
    for node in get_tree().current_scene.find_children("*", "MeshInstance3D", true, false):
        track_mesh(node)
    sample_meshes(true)
    get_tree().node_added.connect(track_mesh)
    primed = true

func track_mesh(node: Node) -> void:
    if not node is MeshInstance3D or node == self:
        return
    if node == terrain or terrain.is_ancestor_of(node):
        return
    var actor := node
    var ancestor := node.get_parent()
    while ancestor != null:
        if ancestor is PhysicsBody3D:
            actor = ancestor
            break
        ancestor = ancestor.get_parent()
    tracked[node] = {"position": Vector3.INF, "wet": false, "actor": actor.get_instance_id()}

func _physics_process(delta: float) -> void:
    elapsed += delta
    material_override.set_shader_parameter("ripple_clock", elapsed)
    if not primed:
        return
    sample_clock += delta
    if sample_clock < sample_interval:
        return
    sample_clock = 0.0
    sample_meshes(false)

func sample_meshes(quiet: bool) -> void:
    var emitted: Dictionary = {}
    var area := get_aabb()
    for node in tracked.keys():
        if not is_instance_valid(node):
            tracked.erase(node)
            continue
        var state: Dictionary = tracked[node]
        if node.mesh == null or not node.is_visible_in_tree():
            state.wet = false
            continue
        var bounds: AABB = global_transform.affine_inverse() * node.global_transform * node.get_aabb()
        var center := bounds.get_center()
        var point := Vector3(clampf(center.x, area.position.x, area.end.x), 0.0, clampf(center.z, area.position.z, area.end.z))
        var wet := bounds.end.x >= area.position.x and bounds.position.x <= area.end.x and bounds.end.z >= area.position.z and bounds.position.z <= area.end.z
        wet = wet and bounds.position.y <= 0.15 and bounds.end.y >= -water_depth
        if wet:
            var world_point := to_global(point)
            wet = terrain.height_at(world_point) < world_point.y - 0.05
        var previous: Vector3 = state.position
        var movement := center.distance_to(previous) if previous.is_finite() else 0.0
        if wet and not quiet and (not state.wet or movement >= movement_threshold) and not emitted.has(state.actor):
            var strength := clampf(0.3 + bounds.size.length() * 0.05 + movement * 0.18, 0.35, 1.0)
            ripples[ripple_index] = Vector4(point.x, point.z, elapsed, strength)
            ripple_index = (ripple_index + 1) % ripples.size()
            emitted[state.actor] = true
            state.position = center
        elif not wet or quiet or not previous.is_finite():
            state.position = center
        state.wet = wet
    material_override.set_shader_parameter("ripples", ripples)
