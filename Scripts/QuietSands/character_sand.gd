extends GPUParticles3D

@export var skeleton_path: NodePath
@export var feet: PackedStringArray

@onready var character: CharacterBody3D = get_parent()
@onready var skeleton: Skeleton3D = get_node(skeleton_path)
@onready var terrain: Node3D = get_node("../../SculptedDesert")

var phase := 0.0
var step := 0

func _physics_process(delta: float) -> void:
	var speed := Vector2(character.velocity.x, character.velocity.z).length()
	var moving: bool = character.is_active and character.is_on_floor() and speed > 0.4
	var ground := character.global_position + position
	var on_sand := absf(ground.y - terrain.base_height(ground.x, ground.z)) < 0.7
	emitting = moving and on_sand
	if not moving or not on_sand:
		return
	phase += speed * delta * 2.7
	if phase < PI:
		return
	phase -= PI
	var bone := skeleton.find_bone(feet[step % feet.size()])
	var point := skeleton.to_global(skeleton.get_bone_global_pose(bone).origin)
	point.y = terrain.base_height(point.x, point.z)
	terrain.stamp(point, character.velocity.normalized(), 0.28, 0.46, 0.105)
	step += 1
