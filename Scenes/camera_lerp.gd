class_name CustomCamera
extends Camera3D

@export var target: Node3D
@export var follow_speed: float = 5.0
@export var transition_lerp_speed: float = 2.0

@export var arrive_distance: float = 0.01
@export var arrive_angle: float = 0.01

@export_group("Deadzone")
## The camera ignores target movement smaller than this (world units). Once the target gets further
## away than this, the camera follows just enough to keep it at this distance.
## Set to 0 to disable. Ignored while transitioning between targets.
@export var position_deadzone: float = 0.1
## Same idea for rotation, in degrees. Leave at 0 to follow rotation exactly.
@export_range(0.0, 45.0, 0.1) var rotation_deadzone_degrees: float = 0.0

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

	# The deadzone is turned off during transitions so the camera can actually arrive at the target.
	var pos_dz: float = 0.0 if is_transitioning else position_deadzone
	var rot_dz: float = 0.0 if is_transitioning else deg_to_rad(rotation_deadzone_degrees)

	# --- Position ---
	var goal_pos: Vector3 = target.global_position
	var offset: Vector3 = global_position - goal_pos
	var dist: float = offset.length()
	if dist <= pos_dz:
		# Inside the deadzone: don't move.
		goal_pos = global_position
	else:
		# Outside: follow, but only until the target is back at the edge of the deadzone.
		goal_pos += offset / dist * pos_dz
	global_position = global_position.lerp(goal_pos, weight)

	# --- Rotation ---
	var current_rot: Quaternion = global_transform.basis.get_rotation_quaternion()
	var target_rot: Quaternion = target.global_transform.basis.get_rotation_quaternion()
	var goal_rot: Quaternion = target_rot
	var angle: float = current_rot.angle_to(target_rot)
	if angle <= rot_dz:
		goal_rot = current_rot
	elif rot_dz > 0.0:
		# Rotate only until we're within the deadzone angle of the target.
		goal_rot = target_rot.slerp(current_rot, rot_dz / angle)
	global_transform.basis = Basis(current_rot.slerp(goal_rot, weight))

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
