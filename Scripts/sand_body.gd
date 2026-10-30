class_name SandBody
extends RigidBody3D

@export var footprint_radius := 0.65
@export var sink_depth := 0.24
var sand: SandTerrain
var stamp_clock := 0.0
var last_stamp := Vector3.INF

func _ready() -> void:
    sand = get_tree().get_first_node_in_group("deformable_sand") as SandTerrain
    contact_monitor = true
    max_contacts_reported = 4
    continuous_cd = true
    add_to_group("sand_objects")

func _physics_process(delta: float) -> void:
    if sand == null:
        return
    stamp_clock += delta
    if stamp_clock < 0.12:
        return
    stamp_clock = 0.0
    var height := sand.height_at(global_position)
    if global_position.y - footprint_radius > height + 0.18:
        return
    if global_position.distance_to(last_stamp) < 0.15:
        return
    var pressure := clampf(mass / 8.0, 0.4, 1.4)
    sand.stamp(global_position, Vector2.ONE * footprint_radius, sink_depth * pressure)
    last_stamp = global_position
