class_name Camel
extends CharacterBody3D

@export var max_speed : float
@export var acceleration : float
@export var deceleration : float

@export var turn_accel : float
@export var start_turn_speed : float
@export var max_turn_speed : float

@export var is_active : bool
@export var tilt_limit : float = 75
@export var visuals : Node3D
@export var rotation_speed : float = 12

@onready var animation_tree: AnimationTree = $AnimationTree
@onready var animation_player: AnimationPlayer = $VisualContainer/camel_man/AnimationPlayer

@onready var _camera_pivot = $SpringAnchor
@onready var camera_target: Node3D = $SpringAnchor/SpringArm3D/CameraTarget

@onready var mount_left_start: Node3D = $VisualContainer/camel_man/mount_left_start
@onready var mount_right_start: Node3D = $VisualContainer/camel_man/mount_right_start
@onready var skeleton_3d: Skeleton3D = $VisualContainer/camel_man/man_root/Rider_Placement/Character_Rig/Skeleton3D
@onready var leave_position: Node3D = $VisualContainer/camel_man/LeavePosition

var mouse_sensitivity : float = 1
var desiredVelocity : Vector3

var camera
var _prev_dir : Vector3 = Vector3(1,0,0)
var state_machine : AnimationNodeStateMachinePlayback
var is_transitioning : bool = false
var is_accelerating : bool = false
var current_turn_speed : float


func _ready() -> void:
	animation_tree.advance_expression_base_node = self.get_path()
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	Global.camel = self
	Global.camel_camera_node  = camera_target
	mouse_sensitivity = Global.mouse_sens
	state_machine = animation_tree["parameters/playback"]

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		return

	# Click to capture the mouse again.
	if event is InputEventMouseButton and event.pressed \
			and Input.mouse_mode != Input.MOUSE_MODE_CAPTURED:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
		return
	
	if (not is_active): return
	
	if (event.is_action_pressed("Mount")):
			GET_OFF_CAMEL()
			return
	
	# Mouselook implemented using `screen_relative` for resolution-independent sensitivity.
	if event is InputEventMouseMotion:
		_camera_pivot.rotation.x -= event.screen_relative.y * mouse_sensitivity
		# Prevent the camera from rotating too far up or down.
		_camera_pivot.rotation.x = deg_to_rad(clamp(rad_to_deg(_camera_pivot.rotation.x), -tilt_limit, tilt_limit))
		_camera_pivot.rotation.y += -event.screen_relative.x * mouse_sensitivity

func _physics_process(delta: float) -> void:
	# deactivate the man in the game. 
	if (!is_active && !is_transitioning):
		$VisualContainer/camel_man/man_root.visible = false
	if (!is_active && is_transitioning):
		$VisualContainer/camel_man/man_root.visible = true
		pass

	if (!is_active): 
		return

	if not is_on_floor():
		velocity += get_gravity() * delta

	## Handle jump.
	#if Input.is_action_just_pressed("ui_accept") and is_on_floor():
		#velocity.y = JUMP_VELOCITY
	var input_dir := Input.get_vector("Left", "Right", "Up", "Down")
	if (input_dir.y != 0): is_accelerating = true
	else: is_accelerating = false
	var turn_dir = input_dir.x
	
	var cam_basis: Basis = get_viewport().get_camera_3d().global_basis
	var forward := -cam_basis.z
	forward.y = 0
	forward = forward.normalized()

	var right := cam_basis.x
	right.y = 0
	right = right.normalized()

	# input_dir.y is negative when pressing Up, so negate it to move along forward.
	var direction := (right * input_dir.x + forward * -input_dir.y).normalized()

	
	if direction:
		velocity.x = move_toward(velocity.x, max_speed * direction.x, acceleration * delta)
		velocity.z = move_toward(velocity.z, max_speed * direction.z, acceleration * delta)
		
		## check if the direction is completely 180
		if (direction.dot(velocity) < 0): 
			velocity.x = 0
			velocity.z = 0
	else:
		velocity.x = move_toward(velocity.x, 0, deceleration * delta)
		velocity.z = move_toward(velocity.z, 0, deceleration * delta)
	
	move_and_slide()
	
	if (direction.length() > 0.2):
		_prev_dir = direction
	
	# manage visuals.
	var target_angle := Vector3.BACK.signed_angle_to(_prev_dir, Vector3.UP) # this means the difference in 
	visuals.global_rotation.y = lerp_angle(visuals.rotation.y, target_angle, rotation_speed * delta)

func GET_ON_CAMEL() -> void:
	Global.player.is_active = false
	Global.player.animation_tree.active = false
	is_transitioning = true
	Global.player.visible = false
	
	
	animation_tree.animation_finished.connect(on_mount)
	if (abs((mount_left_start.global_position - Global.player.global_position).length()) >= abs((mount_right_start.global_position - Global.player.global_position).length())) :
		state_machine.start("mount_right")
	else:
		state_machine.start("mount_left")
		
	Global.main_camera.lerp_to_new(Global.camel_camera_node)
	# this finishes states based on the animation's callback


func GET_OFF_CAMEL() -> void:
	# the only way to determine whether we are on or off the camel. 
	is_active = false
	is_transitioning = true
	
	Global.player.global_position = leave_position.global_position
	Global.player.global_basis = leave_position.global_basis
	#Global.player.global_position.y += Global.player.man.global_position.y + 0.3
	#var offset : Vector3 = Vector3(0,0,0.3)
	
	#Global.player.global_position += offset
	snap_player_to_ground_up()
	# wait until the state is moved.
	animation_tree.animation_finished.connect(on_dismount)
	state_machine.start("dismount")
	# move the player to the dismount position
	
	await Global.main_camera.lerp_to_new(Global.player_camera_node)

func on_dismount(anim_name):
	if anim_name != &"dismount":
		return
	Global.player.animation_tree.active = true
	$VisualContainer/camel_man/man_root.visible = false
	#Global.player.visuals.global_rotation = -mount_left_start.global_rotation
	Global.player.visible = true
	Global.player.is_active = true
	is_transitioning = false
	animation_tree.animation_finished.disconnect(on_dismount)

func on_mount(anim_name):
	if (anim_name != &"mount_right" and anim_name != &"mount_left"):
		return
	
	is_transitioning = false
	is_active = true
	animation_tree.animation_finished.disconnect(on_mount)



## Casts upward from below the player and puts them on the first surface found.
func snap_player_to_ground_up(start_below: float = 1.0, max_up: float = 5.0) -> void:
	var player: Person = Global.player
	var space := get_world_3d().direct_space_state

	var from := player.global_position + Vector3.DOWN * start_below
	var to := player.global_position + Vector3.UP * max_up

	var query := PhysicsRayQueryParameters3D.create(from, to)
	query.exclude = [player.get_rid(), get_rid()]
	query.collide_with_areas = false
	query.hit_back_faces = true     # default, but explicit: needed when starting inside terrain
	query.hit_from_inside = true    # needed if the ground is a solid convex shape (box, etc.)

	var hit := space.intersect_ray(query)
	if hit.is_empty():
		return   # nothing above, so the player is probably not buried

	player.global_position.y = hit.position.y + _player_half_height()

func _player_half_height() -> float:
	var shape_node: CollisionShape3D = Global.player.get_node_or_null("CollisionShape3D")
	if shape_node and shape_node.shape is CapsuleShape3D:
		return shape_node.shape.height * 0.5
	return 0.05
