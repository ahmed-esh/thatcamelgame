
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
@export var slide_angle_threshold : float = 35.0
@export var slide_acceleration : float = 25.0
@export var max_slide_speed : float = 20.0
@export var slide_momentum_decay : float = 3.0
@export var slide_gravity_multiplier : float = 4.0
@export var slide_snap_length : float = 1.0
@export_range(0.0, 1.0, 0.01) var uphill_input_threshold : float = 0.2
@export var uphill_slide_cancel_decay : float = 40.0
@export var lock_input_while_sliding : bool = true

@export_group("Sprint")
@export var sprint_speed: float = 20.0
@export var sprint_top_speed: float = 25.0
@export var sprint_acceleration_time: float = 1.6
@export var sprint_top_speed_delay: float = 1.2
@export var sprint_top_speed_time: float = 1.1
@export var sprint_camera_delay: float = 1.7
@export var sprint_camera_time: float = 2.8
@export var sprint_fov_increase: float = 11.0
@export var sprint_camera_back: float = 3.0
@export var sprint_camera_up: float = 1.0

@export_group("Follow")
@export var follow_start_distance: float = 10.0
@export var follow_stop_distance: float = 4.0

@export_group("Visuals")
@export var ground_align_speed : float = 8.0
@export_range(0.0, 45.0, 0.1) var ground_align_threshold : float = 8.0

@onready var animation_tree: AnimationTree = $AnimationTree
@onready var animation_player: AnimationPlayer = $VisualContainer/camel_man/AnimationPlayer
@onready var hoof_skeleton: Skeleton3D = $VisualContainer/camel_man/Camel_Rig/Skeleton3D
@onready var _camera_pivot = $SpringAnchor
@onready var _spring_arm: SpringArm3D = $SpringAnchor/SpringArm3D
@onready var camera_target: Node3D = $SpringAnchor/SpringArm3D/CameraTarget
@onready var mount_left_start: Node3D = $VisualContainer/camel_man/mount_left_start
@onready var mount_right_start: Node3D = $VisualContainer/camel_man/mount_right_start
@onready var skeleton_3d: Skeleton3D = $VisualContainer/camel_man/man_root/Rider_Placement/Character_Rig/Skeleton3D
@onready var leave_position: Node3D = $VisualContainer/camel_man/LeavePosition

const SLIDE_STATE := &"camel_man_slide_added_camel_slide"
const RIDE_IDLE_STATE := &"ride_idle"

@export var slide_anim_start_delay : float = 0.12
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
var _slide_velocity : Vector3 = Vector3.ZERO
var _is_sliding : bool = false
var _pushing_uphill : bool = false
var _default_snap_length : float
var _following_player := false
var _visual_yaw : float = 0.0
var _visual_up : Vector3 = Vector3.UP
var _aligned_normal : Vector3 = Vector3.UP
var hoof_distance := 0.0
var hoof_index := 0
const HOOF_BONES := ["front_L_foot", "rear_R_foot", "front_R_foot", "rear_L_foot"]
var _normal_speed: float
var _normal_spring_length: float
var _normal_camera_pivot_position: Vector3
var _normal_camera_fov: float
var _normal_fov_captured := false
var _sprinting := false
var _sprint_time := 0.0
var _sprint_camera_started := false
var _sprint_speed_tween: Tween
var _sprint_camera_tween: Tween

func _ready() -> void:
	floor_max_angle = deg_to_rad(65.0)
	_default_snap_length = floor_snap_length
	_normal_speed = max_speed
	_normal_spring_length = _spring_arm.spring_length
	_normal_camera_pivot_position = _camera_pivot.position
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

	if event is InputEventMouseButton and event.pressed \
			and Input.mouse_mode != Input.MOUSE_MODE_CAPTURED:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
		return

	if (not is_active): return

	if (event.is_action_pressed("Mount")):
		if Global.dialogue_active:
			return
		if _is_sliding:
			return
		GET_OFF_CAMEL()
		return

	if event is InputEventMouseMotion:
		_camera_pivot.rotation.x -= event.screen_relative.y * mouse_sensitivity
		_camera_pivot.rotation.x = deg_to_rad(clamp(rad_to_deg(_camera_pivot.rotation.x), -tilt_limit, tilt_limit))
		_camera_pivot.rotation.y += -event.screen_relative.x * mouse_sensitivity

func _is_on_steep_slope() -> bool:
	if not is_on_floor():
		return false
	var floor_angle := rad_to_deg(get_floor_normal().angle_to(Vector3.UP))
	return floor_angle >= slide_angle_threshold

func _get_downhill() -> Vector3:
	var downhill := Vector3.DOWN.slide(get_floor_normal())
	downhill.y = 0
	return downhill.normalized()

func _is_pushing_uphill(move_dir: Vector3) -> bool:
	if move_dir.length() < 0.1 or not _is_on_steep_slope():
		return false
	return move_dir.normalized().dot(_get_downhill()) < -uphill_input_threshold

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

func _update_sprint(delta: float) -> void:
	var moving := Input.get_vector("Left", "Right", "Up", "Down").length() > 0.1
	var requested := is_active and not is_transitioning and not Global.in_cutscene and moving and Input.is_action_pressed("run") and not _is_slide_active()
	if not requested:
		_stop_sprint()
		return
	if not _sprinting:
		_sprinting = true
		_sprint_time = 0.0
		_sprint_camera_started = false
		if _sprint_speed_tween != null:
			_sprint_speed_tween.kill()
		_sprint_speed_tween = create_tween()
		_sprint_speed_tween.tween_property(self, "max_speed", sprint_speed, sprint_acceleration_time).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
		_sprint_speed_tween.tween_interval(sprint_top_speed_delay)
		_sprint_speed_tween.tween_property(self, "max_speed", sprint_top_speed, sprint_top_speed_time).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_sprint_time += delta
	if _sprint_camera_started or _sprint_time < sprint_camera_delay or Global.main_camera == null:
		return
	_sprint_camera_started = true
	if not _normal_fov_captured:
		_normal_camera_fov = Global.main_camera.fov
		_normal_fov_captured = true
	if _sprint_camera_tween != null:
		_sprint_camera_tween.kill()
	_sprint_camera_tween = create_tween().set_parallel(true)
	_sprint_camera_tween.tween_property(_spring_arm, "spring_length", _normal_spring_length + sprint_camera_back, sprint_camera_time).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_sprint_camera_tween.tween_property(_camera_pivot, "position", _normal_camera_pivot_position + Vector3.UP * sprint_camera_up, sprint_camera_time).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_sprint_camera_tween.tween_property(Global.main_camera, "fov", _normal_camera_fov + sprint_fov_increase, sprint_camera_time).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)

func _stop_sprint() -> void:
	if not _sprinting:
		return
	_sprinting = false
	_sprint_time = 0.0
	if _sprint_speed_tween != null:
		_sprint_speed_tween.kill()
	_sprint_speed_tween = create_tween()
	_sprint_speed_tween.tween_property(self, "max_speed", _normal_speed, 0.5).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	if not _sprint_camera_started:
		return
	_sprint_camera_started = false
	if _sprint_camera_tween != null:
		_sprint_camera_tween.kill()
	_sprint_camera_tween = create_tween().set_parallel(true)
	_sprint_camera_tween.tween_property(_spring_arm, "spring_length", _normal_spring_length, 0.85).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	_sprint_camera_tween.tween_property(_camera_pivot, "position", _normal_camera_pivot_position, 0.85).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	if Global.main_camera != null:
		_sprint_camera_tween.tween_property(Global.main_camera, "fov", _normal_camera_fov, 0.85).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)

func _update_slide(delta: float) -> void:
	_is_sliding = _is_on_steep_slope() and not _pushing_uphill
	if _is_sliding:
		var n := get_floor_normal()
		var downhill := _get_downhill()
		var steepness := sin(n.angle_to(Vector3.UP))
		_slide_velocity += downhill * slide_acceleration * steepness * delta
		_slide_velocity = _slide_velocity.limit_length(max_slide_speed)
	elif _pushing_uphill:
		_slide_velocity = _slide_velocity.move_toward(Vector3.ZERO, uphill_slide_cancel_decay * delta)
	elif is_on_floor():
		_slide_velocity = _slide_velocity.move_toward(Vector3.ZERO, slide_momentum_decay * delta)

func _physics_process(delta: float) -> void:
	if not is_active and not is_transitioning:
		$VisualContainer/camel_man/man_root.visible = false
	if not is_active and is_transitioning:
		$VisualContainer/camel_man/man_root.visible = true

	if not is_active and not is_transitioning and Global.player != null and Global.player.is_active and not Global.in_cutscene:
		var gap := Vector2(Global.player.global_position.x - global_position.x, Global.player.global_position.z - global_position.z).length()
		if gap > follow_start_distance:
			_following_player = true
		elif gap < follow_stop_distance:
			_following_player = false
	else:
		_following_player = false

	_update_sprint(delta)

	if not is_active and not _following_player and _slide_velocity.length() < 0.2 and Vector2(velocity.x, velocity.z).length() < 0.2:
		return
	if is_transitioning and not is_active:
		return

	var slide_active := _is_slide_active()
	if not is_on_floor() or slide_active:
		var gravity_scale := slide_gravity_multiplier if slide_active else 1.0
		velocity += get_gravity() * gravity_scale * delta

	var input_dir := Vector2.ZERO
	var direction := Vector3.ZERO
	if is_active:
		if not Global.in_cutscene:
			input_dir = Input.get_vector("Left", "Right", "Up", "Down")
		var cam_basis: Basis = get_viewport().get_camera_3d().global_basis
		var forward := -cam_basis.z
		forward.y = 0
		forward = forward.normalized()
		var right := cam_basis.x
		right.y = 0
		right = right.normalized()
		direction = (right * input_dir.x + forward * -input_dir.y).normalized()
	elif _following_player:
		direction = Global.player.global_position - global_position
		direction.y = 0
		direction = direction.normalized()

	_pushing_uphill = _is_pushing_uphill(direction)
	if lock_input_while_sliding and _is_slide_active():
		input_dir = Vector2.ZERO
		direction = Vector3.ZERO
	is_accelerating = direction.length() > 0.2

	velocity.x -= _slide_velocity.x
	velocity.z -= _slide_velocity.z
	if direction.length() > 0.01:
		velocity.x = move_toward(velocity.x, max_speed * direction.x, acceleration * delta)
		velocity.z = move_toward(velocity.z, max_speed * direction.z, acceleration * delta)
		if direction.dot(velocity) < 0:
			velocity.x = 0
			velocity.z = 0
	else:
		velocity.x = move_toward(velocity.x, 0, deceleration * delta)
		velocity.z = move_toward(velocity.z, 0, deceleration * delta)

	_update_slide(delta)
	velocity.x += _slide_velocity.x
	velocity.z += _slide_velocity.z
	var sliding_now := _is_slide_active()
	floor_snap_length = maxf(slide_snap_length, 3.0) if sliding_now else _default_snap_length
	if sliding_now and is_on_floor():
		var n := get_floor_normal()
		var descent := -(n.x * velocity.x + n.z * velocity.z) / maxf(n.y, 0.15)
		velocity.y = minf(velocity.y, descent - 1.5)
	var was_grounded := is_on_floor()
	move_and_slide()
	if sliding_now and was_grounded and not is_on_floor():
		apply_floor_snap()
	if sliding_now and is_on_floor():
		var terrain := get_node_or_null("../SculptedDesert")
		if terrain != null:
			var point := global_position
			point.y = terrain.base_height(point.x, point.z)
			terrain.drag_sand(point, velocity, clampf(_slide_velocity.length() / max_slide_speed, 0.25, 1.0))

	var horizontal_real := Vector3(velocity.x, 0, velocity.z)
	if _slide_velocity.length() > horizontal_real.length():
		_slide_velocity = _slide_velocity.limit_length(horizontal_real.length())
	if direction.length() > 0.2:
		_prev_dir = direction
	_update_slide_animation(delta)
	_update_visuals(delta)
	_update_hoofprints(delta)

func _update_hoofprints(delta: float) -> void:
	var terrain := get_node_or_null("../SculptedDesert")
	if terrain == null or not is_on_floor():
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

func _update_visuals(delta: float) -> void:
	if _is_slide_active():
		var slide_dir := Vector3(_slide_velocity.x, 0.0, _slide_velocity.z)
		if slide_dir.length() > 0.5:
			_prev_dir = slide_dir.normalized()

	var target_yaw := Vector3.BACK.signed_angle_to(_prev_dir, Vector3.UP)
	_visual_yaw = lerp_angle(_visual_yaw, target_yaw, rotation_speed * delta)

	if is_on_floor():
		var ground_up := get_floor_normal().normalized()
		if rad_to_deg(_aligned_normal.angle_to(ground_up)) > ground_align_threshold:
			_aligned_normal = ground_up

	var new_up := _visual_up.lerp(_aligned_normal, clampf(ground_align_speed * delta, 0.0, 1.0))
	if new_up.length_squared() > 0.0001:
		_visual_up = new_up.normalized()

	var yaw_q := Quaternion(Vector3.UP, _visual_yaw)
	var tilt_q := Quaternion(Vector3.UP, _visual_up)
	var final_basis := Basis(tilt_q * yaw_q).scaled(visuals.global_basis.get_scale())
	visuals.global_basis = final_basis

func GET_ON_CAMEL() -> void:
	if Global.dialogue_active:
		return
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

func GET_OFF_CAMEL() -> void:
	if Global.dialogue_active:
		return
	_stop_sprint()
	is_active = false
	is_transitioning = true

	Global.player.global_position = leave_position.global_position
	Global.player.global_basis = leave_position.global_basis

	snap_player_to_ground_up()

	animation_tree.animation_finished.connect(on_dismount)
	state_machine.start("dismount")
	await Global.main_camera.lerp_to_new(Global.player_camera_node)

func on_dismount(anim_name):
	if anim_name != &"dismount":
		return
	Global.player.animation_tree.active = true
	$VisualContainer/camel_man/man_root.visible = false
	Global.player.visible = true
	Global.player.is_active = true
	is_transitioning = false
	Global.is_camel = false
	state_machine.start(RIDE_IDLE_STATE)
	animation_tree.animation_finished.disconnect(on_dismount)

func on_mount(anim_name):
	if (anim_name != &"mount_right" and anim_name != &"mount_left"):
		return
	is_transitioning = false
	is_active = true
	Global.is_camel = true
	animation_tree.animation_finished.disconnect(on_mount)

func snap_player_to_ground_up(start_below: float = 8.0, max_up: float = 1.5) -> void:
	var player: Person = Global.player
	var space := get_world_3d().direct_space_state

	var from := player.global_position + Vector3.UP * max_up
	var to := player.global_position + Vector3.DOWN * start_below

	var query := PhysicsRayQueryParameters3D.create(from, to)
	query.exclude = [player.get_rid(), get_rid()]
	query.collide_with_areas = false
	query.hit_back_faces = true
	query.hit_from_inside = true

	var hit := space.intersect_ray(query)
	if hit.is_empty():
		return

	player.global_position.y = hit.position.y + _player_half_height()

func _player_half_height() -> float:
	var shape_node: CollisionShape3D = Global.player.get_node_or_null("CollisionShape3D")
	if shape_node and shape_node.shape is CapsuleShape3D:
		return shape_node.shape.height * 0.5
	return 0.05
