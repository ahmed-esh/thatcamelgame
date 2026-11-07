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
## Pushing uphill on a steep slope cancels the slide. This is how far "uphill" the input must point
## (0 = any uphill component, 1 = straight up the slope). Sideways input still slides.
@export_range(0.0, 1.0, 0.01) var uphill_input_threshold : float = 0.2
## How fast existing slide momentum is cancelled while pushing uphill (units/sec^2).
@export var uphill_slide_cancel_decay : float = 40.0
## If true, movement input is ignored while sliding or carrying slide momentum (camera look still works).
@export var lock_input_while_sliding : bool = true

@export_group("Visuals")
## How quickly the camel's visuals lerp to match the ground normal (higher = snappier).
@export var ground_align_speed : float = 8.0
## The visuals only re-align when the ground normal differs from the last normal they aligned to
## by more than this many degrees. Raise it to ignore bumps; lower it to follow finer detail.
@export_range(0.0, 45.0, 0.1) var ground_align_threshold : float = 8.0

@onready var animation_tree: AnimationTree = $AnimationTree
@onready var animation_player: AnimationPlayer = $VisualContainer/camel_man/AnimationPlayer
@onready var hoof_skeleton: Skeleton3D = $VisualContainer/camel_man/Camel_Rig/Skeleton3D

@onready var _camera_pivot = $SpringAnchor
@onready var camera_target: Node3D = $SpringAnchor/SpringArm3D/CameraTarget

@onready var mount_left_start: Node3D = $VisualContainer/camel_man/mount_left_start
@onready var mount_right_start: Node3D = $VisualContainer/camel_man/mount_right_start
@onready var skeleton_3d: Skeleton3D = $VisualContainer/camel_man/man_root/Rider_Placement/Character_Rig/Skeleton3D
@onready var leave_position: Node3D = $VisualContainer/camel_man/LeavePosition

const SLIDE_STATE := &"camel_man_slide_added_camel_slide"
const RIDE_IDLE_STATE := &"ride_idle"

## Slide must be active this long (seconds) before the slide animation starts.
@export var slide_anim_start_delay : float = 0.12
## Slide must be inactive this long before returning to ride_idle.
@export var slide_anim_end_grace : float = 0.15

var _slide_on_time : float = 0.0
var _slide_off_time : float = 0.0
var _slide_anim_playing : bool = false


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
var _pushing_uphill : bool = false
var _default_snap_length : float
var _visual_yaw : float = 0.0
var _visual_up : Vector3 = Vector3.UP        # what the model is currently using as "up" (smoothed)
var _aligned_normal : Vector3 = Vector3.UP   # last ground normal the visuals committed to
var hoof_distance := 0.0
var hoof_index := 0
const HOOF_BONES := ["front_L_foot", "rear_R_foot", "front_R_foot", "rear_L_foot"]


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


## Horizontal direction of steepest descent on the current floor.
func _get_downhill() -> Vector3:
	var downhill := Vector3.DOWN.slide(get_floor_normal())
	downhill.y = 0
	return downhill.normalized()

## True if we're on a steep slope and the player is steering up it. Slides only apply to downhill
## or sideways movement, so walking up a steep hill is allowed.
func _is_pushing_uphill(move_dir: Vector3) -> bool:
	if move_dir.length() < 0.1 or not _is_on_steep_slope():
		return false
	return move_dir.normalized().dot(_get_downhill()) < -uphill_input_threshold


## True while sliding, or while still carrying meaningful slide momentum.
## Used to keep the camel glued to the ground instead of bouncing off slope changes.
## Never true while the player is pushing uphill, so climbing isn't fought by gravity/snap/lock.
func _is_slide_active() -> bool:
	if _pushing_uphill:
		return false
	return _is_sliding or _slide_velocity.length() > 1.0

func _update_slide_animation(delta: float) -> void:
	if _is_slide_active():
		_slide_off_time = 0.0
		_slide_on_time += delta
		if not _slide_anim_playing and _slide_on_time >= slide_anim_start_delay:
			_slide_anim_playing = true
			state_machine.start(SLIDE_STATE)
	else:
		_slide_on_time = 0.0
		_slide_off_time += delta
		if _slide_anim_playing and _slide_off_time >= slide_anim_end_grace:
			_slide_anim_playing = false
			state_machine.travel(RIDE_IDLE_STATE)

func _update_slide(delta: float) -> void:
	# Only slide when on a steep slope AND not pushing uphill.
	_is_sliding = _is_on_steep_slope() and not _pushing_uphill

	if _is_sliding:
		var n := get_floor_normal()
		var downhill := _get_downhill()

		# Steeper slopes accelerate faster.
		var steepness := sin(n.angle_to(Vector3.UP))
		_slide_velocity += downhill * slide_acceleration * steepness * delta
		_slide_velocity = _slide_velocity.limit_length(max_slide_speed)
	elif _pushing_uphill:
		# Player is climbing: quickly drop any leftover downhill momentum.
		_slide_velocity = _slide_velocity.move_toward(Vector3.ZERO, uphill_slide_cancel_decay * delta)
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
	var cam_basis: Basis = get_viewport().get_camera_3d().global_basis
	var forward := -cam_basis.z
	forward.y = 0
	forward = forward.normalized()

	var right := cam_basis.x
	right.y = 0
	right = right.normalized()

	# input_dir.y is negative when pressing Up, so negate it to move along forward.
	var direction := (right * input_dir.x + forward * -input_dir.y).normalized()

	# Is the player steering up a steep slope? Checked on the raw input, before any lock.
	_pushing_uphill = _is_pushing_uphill(direction)

	# No steering or accelerating while sliding, including while still carrying slide momentum
	# (on flat ground or mid-bounce) - except when deliberately pushing uphill.
	if lock_input_while_sliding and _is_slide_active():
		input_dir = Vector2.ZERO
		direction = Vector3.ZERO
	if (input_dir.y != 0): is_accelerating = true
	else: is_accelerating = false
	var turn_dir = input_dir.x

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
	
	_update_slide_animation(delta)
	_update_visuals(delta)
	_update_hoofprints(delta)


func _update_hoofprints(delta: float) -> void:
	var terrain := get_node_or_null("../SculptedDesert")
	if terrain == null or not is_on_floor() or _is_sliding:
		hoof_distance = 0.0
		return
	var horizontal := Vector3(velocity.x, 0.0, velocity.z)
	var speed := horizontal.length()
	if speed < 0.8:
		hoof_distance = 0.0
		return
	hoof_distance += speed * delta
	var stride := 0.95 if speed > 7.0 else 1.3
	if hoof_distance < stride:
		return
	hoof_distance = fmod(hoof_distance, stride)
	var bone := hoof_skeleton.find_bone(HOOF_BONES[hoof_index % HOOF_BONES.size()])
	hoof_index += 1
	if bone < 0:
		return
	var point := hoof_skeleton.to_global(hoof_skeleton.get_bone_global_pose(bone).origin)
	var ground: float = float(terrain.base_height(point.x, point.z))
	if absf(point.y - ground) > 0.7:
		return
	point.y = ground
	terrain.stamp(point, horizontal.normalized(), 0.34, 0.42, 0.135 if speed < 7.0 else 0.05)

## Handles facing direction (yaw) and tilting the model to the ground normal while sliding.
func _update_visuals(delta: float) -> void:
	# While sliding / carrying slide momentum, face the direction of travel.
	# Writing it into _prev_dir means the camel keeps that facing after the slide ends.
	if _is_slide_active():
		var slide_dir := Vector3(_slide_velocity.x, 0.0, _slide_velocity.z)
		if slide_dir.length() > 0.5:
			_prev_dir = slide_dir.normalized()

	# Yaw: face the movement direction.
	var target_yaw := Vector3.BACK.signed_angle_to(_prev_dir, Vector3.UP)
	_visual_yaw = lerp_angle(_visual_yaw, target_yaw, rotation_speed * delta)

	# Tilt: only commit to a new ground normal once it differs enough from the last committed one.
	# In the air, keep whatever we last committed to.
	if is_on_floor():
		var ground_up := get_floor_normal().normalized()
		if rad_to_deg(_aligned_normal.angle_to(ground_up)) > ground_align_threshold:
			_aligned_normal = ground_up

	# Smoothly move toward the committed normal.
	# Lerp + normalize (instead of Vector3.slerp) so drift can never produce a non-unit vector.
	var new_up := _visual_up.lerp(_aligned_normal, clampf(ground_align_speed * delta, 0.0, 1.0))
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
	Global.is_camel = false
	animation_tree.animation_finished.disconnect(on_dismount)

func on_mount(anim_name):
	if (anim_name != &"mount_right" and anim_name != &"mount_left"):
		return
	
	is_transitioning = false
	is_active = true
	Global.is_camel = true
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
