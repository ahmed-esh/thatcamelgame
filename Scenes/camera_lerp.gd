class_name CustomCamera
extends Camera3D

@export var target: Node3D
@export var follow_speed: float = 5.0
@export var transition_lerp_speed: float = 2.0

@export var arrive_distance: float = 0.01
@export var arrive_angle: float = 0.01

var current_lerp_speed: float
var is_transitioning: bool = false

func _ready() -> void:
	Global.main_camera = self
	process_priority = 100
	current_lerp_speed = follow_speed

func _process(delta: float) -> void:
	if target == null:
		return

	var weight: float = 1.0 - exp(-current_lerp_speed * delta)

	global_position = global_position.lerp(target.global_position, weight)

	var current_rot: Quaternion = global_transform.basis.get_rotation_quaternion()
	var target_rot: Quaternion = target.global_transform.basis.get_rotation_quaternion()
	global_transform.basis = Basis(current_rot.slerp(target_rot, weight))

func set_camera_parent(new_target: Node3D) -> void:
	target = new_target

# this checks if we are close to the new target.
func _is_at_target() -> bool:
	var pos_close: bool = global_position.distance_to(target.global_position) <= arrive_distance
	var current_rot: Quaternion = global_transform.basis.get_rotation_quaternion()
	var target_rot: Quaternion = target.global_transform.basis.get_rotation_quaternion()
	var rot_close: bool = current_rot.angle_to(target_rot) <= arrive_angle
	return pos_close and rot_close

## Returns true when the camera reaches the new target.
## Returns false if a transition is already running (call is ignored),
## or if the target was freed mid-transition.
func lerp_to_new(new_target: Node3D) -> bool:
	if is_transitioning:
		return false

	is_transitioning = true
	current_lerp_speed = transition_lerp_speed
	target = new_target

	while not _is_at_target():
		await get_tree().process_frame

	is_transitioning = false
	current_lerp_speed = follow_speed
	return true
