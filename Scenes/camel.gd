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

@export_group("Sliding")
## Slope angle (degrees) above which the camel starts sliding.
@export var slide_angle_threshold : float = 35.0
## How strongly gravity pulls the camel down the slope while sliding.
@export var slide_acceleration : float = 25.0
## Maximum speed that can be reached from sliding alone.
@export var max_slide_speed : float = 20.0
## How fast slide momentum bleeds off once NOT on a steep slope (units/sec^2).
## Keep this low so momentum carries over onto flat ground.
@export var slide_momentum_decay : float = 3.0
## Gravity is multiplied by this while sliding, which keeps the camel pressed to the slope.
@export var slide_gravity_multiplier : float = 4.0
## Floor snap distance while sliding. Larger = hugs bumps and dips in the terrain better.
@export var slide_snap_length : float = 1.0

@export_group("Visuals")
## How quickly the camel's visuals lerp to match the ground normal (higher = snappier).
@export var ground_align_speed : float = 8.0
## How much the visuals follow the ground's tilt. 0 = always upright, 1 = fully match the
## ground normal, above 1 = exaggerate the tilt. Lower this if bumpy terrain makes it jittery.
@export_range(0.0, 2.0, 0.01) var ground_align_sensitivity : float = 0.5

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

var _slide_velocity : Vector3 = Vector3.ZERO  # horizontal momentum from sliding
var _is_sliding : bool = false
var _default_snap_length : float
var _visual_yaw : float = 0.0
var _visual_up : Vector3 = Vector3.UP


func _ready() -> void:
	_default_snap_length = floor_snap_length
	_visual_yaw = visuals.global_rotation.y
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
		# Can't dismount while sliding down a slope.
		if _is_sliding:
			return
		GET_OFF_CAMEL()
		return
	
	# Mouselook implemented using `screen_relative` for resolution-independent sensitivity.
	if event is InputEventMouseMotion:
		_camera_pivot.rotation.x -= event.screen_relative.y * mouse_sensitivity
		# Prevent the camera from rotating too far up or down.
		_camera_pivot.rotation.x = deg_to_rad(clamp(rad_to_deg(_camera_pivot.rotation.x), -tilt_limit, tilt_limit))
		_camera_pivot.rotation.y += -event.screen_relative.x * mouse_sensitivity


## Returns true if the floor we're standing on is steep enough to slide on.
func _is_on_steep_slope() -> bool:
	if not is_on_floor():
		return false
	var floor_angle := rad_to_deg(get_floor_normal().angle_to(Vector3.UP))
	return floor_angle >= slide_angle_threshold


## True while sliding, or while still carrying meaningful slide momentum.
## Used to keep the camel glued to the ground instead of bouncing off slope changes.
func _is_slide_active() -> bool:
	return _is_sliding or _slide_velocity.length() > 1.0


func _update_slide(delta: float) -> void:
	_is_sliding = _is_on_steep_slope()

	if _is_sliding:
		var n := get_floor_normal()
		# Direction of steepest descent along the surface (horizontal part).
		var downhill := Vector3.DOWN.slide(n)
		downhill.y = 0
		downhill = downhill.normalized()

		# Steeper slopes accelerate faster.
		var steepness := sin(n.angle_to(Vector3.UP))
		_slide_velocity += downhill * slide_acceleration * steepness * delta
		_slide_velocity = _slide_velocity.limit_length(max_slide_speed)
	elif is_on_floor():
		# Off the steep slope but on the ground: slowly bleed off momentum.
		# (Airborne = no friction, so momentum is preserved in the air.)
		_slide_velocity = _slide_velocity.move_toward(Vector3.ZERO, slide_momentum_decay * delta)


func _physics_process(delta: float) -> void:
	# deactivate the man in the game. 
	if (!is_active && !is_transitioning):
		$VisualContainer/camel_man/man_root.visible = false
	if (!is_active && is_transitioning):
		$VisualContainer/camel_man/man_root.visible = true
		pass

	if (!is_active): 
		return

	# Heavy gravity while sliding (even on the floor) keeps the camel pressed down.
	var slide_active := _is_slide_active()
	if not is_on_floor() or slide_active:
		var gravity_scale := slide_gravity_multiplier if slide_active else 1.0
		velocity += get_gravity() * gravity_scale * delta

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

	# Strip last frame's slide velocity so input logic only works on walking velocity.
	velocity.x -= _slide_velocity.x
	velocity.z -= _slide_velocity.z
	
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
	
	# Update slide momentum and add it back on top of walking velocity.
	_update_slide(delta)
	velocity.x += _slide_velocity.x
	velocity.z += _slide_velocity.z
	
	# A longer snap distance while sliding makes the body follow the terrain downward.
	floor_snap_length = slide_snap_length if _is_slide_active() else _default_snap_length
	
	move_and_slide()

	# If we hit a wall, the engine reduced our real velocity; clamp slide momentum
	# to it so we don't keep phantom momentum after crashing into something.
	var horizontal_real := Vector3(velocity.x, 0, velocity.z)
	if _slide_velocity.length() > horizontal_real.length():
		_slide_velocity = _slide_velocity.limit_length(horizontal_real.length())
	
	if (direction.length() > 0.2):
		_prev_dir = direction
	
	_update_visuals(delta)


## Handles facing direction (yaw) and tilting the model to the ground normal while sliding.
func _update_visuals(delta: float) -> void:
	# Yaw: face the movement direction.
	var target_yaw := Vector3.BACK.signed_angle_to(_prev_dir, Vector3.UP)
	_visual_yaw = lerp_angle(_visual_yaw, target_yaw, rotation_speed * delta)

	# Tilt: "up" for the model is always the ground normal. In the air, hold the current tilt.
	var target_up := _visual_up
	if is_on_floor():
		var ground_up := get_floor_normal().normalized()
		# Scale how far we lean away from upright toward the ground normal.
		target_up = Vector3.UP.lerp(ground_up, ground_align_sensitivity)
		if target_up.length_squared() > 0.0001:
			target_up = target_up.normalized()
		else:
			target_up = Vector3.UP
	# Lerp + normalize (instead of Vector3.slerp) so drift can never produce a non-unit vector.
	var new_up := _visual_up.lerp(target_up, clampf(ground_align_speed * delta, 0.0, 1.0))
	if new_up.length_squared() > 0.0001:
		_visual_up = new_up.normalized()

	# Build the final rotation: yaw around world up first, then tilt so up -> _visual_up.
	var yaw_q := Quaternion(Vector3.UP, _visual_yaw)
	var tilt_q := Quaternion(Vector3.UP, _visual_up)
	var final_basis := Basis(tilt_q * yaw_q).scaled(visuals.global_basis.get_scale())
	visuals.global_basis = final_basis

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
