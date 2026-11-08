class_name Person
extends CharacterBody3D

@export var max_speed : float
@export var acceleration : float
@export var deceleration : float
@export var is_active : bool:
	set(value):
		if value and not is_active:
			_target_yaw = visuals.global_rotation.y   # pick up wherever the model is now
		is_active = value

@export var rotation_speed : float
@export var tilt_limit_lower : float = 20
@export var tilt_limit_higher : float = 70

@export_group("Sliding")
@export var slide_angle_threshold: float = 35.0
@export var slide_acceleration: float = 25.0
@export var max_slide_speed: float = 14.0
@export var slide_momentum_decay: float = 3.0
@export var slide_snap_length: float = 2.5
@export var slide_gravity_multiplier: float = 6.0
@export var uphill_input_threshold: float = 0.2

var _target_yaw

var mouse_sensitivity : float = 1
var desiredVelocity : Vector3
var can_get_on_camel : bool
var _prev_dir : Vector3
var _slide_velocity := Vector3.ZERO
var _is_sliding := false
var _slide_animation_playing := false
var _default_snap_length := 0.0

@onready var camera_target: Node3D = $CameraPivot/SpringArm3D/CameraTarget
@onready var _camera_pivot = $CameraPivot
@onready var area_3d: Area3D = $Area3D
@onready var animation_tree: AnimationTree = $AnimationTree
@onready var visuals : Node3D = $man

@onready var man: Node3D = $man
var state_machine : AnimationNodeStateMachinePlayback

func _ready() -> void:
	_default_snap_length = floor_snap_length
	floor_max_angle = deg_to_rad(65.0)
	_setup_slide_animation()
	_target_yaw = visuals.global_rotation.y
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	animation_tree.advance_expression_base_node = self.get_path()
	Global.player = self
	Global.player_camera_node = camera_target
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

	if event is InputEventMouseMotion:
		_camera_pivot.rotation.x -= event.screen_relative.y * mouse_sensitivity
		var radians = _camera_pivot.rotation.x
		_camera_pivot.rotation.x = deg_to_rad(clamp(rad_to_deg(radians), -tilt_limit_higher, tilt_limit_lower))
		_camera_pivot.rotation.y += -event.screen_relative.x * mouse_sensitivity
	
	if Global.in_cutscene: return
	if event.is_action_pressed("Mount"):
		if (!Global.got_water and Global.can_get_water):
			_get_water_event()
			return

		for areas in area_3d.get_overlapping_bodies():
			if (areas is not Camel): continue
			Global.camel.GET_ON_CAMEL()
			return


func _setup_slide_animation() -> void:
	var library: AnimationLibrary = load("res://LJ_models/added slide/camel_man_slide_added.glb") as AnimationLibrary
	var player: AnimationPlayer = $man/AnimationPlayer
	if library != null and not player.has_animation_library(&"camel_man_slide_added"):
		player.add_animation_library(&"camel_man_slide_added", library)
	var machine: AnimationNodeStateMachine = animation_tree.tree_root
	if not machine.has_node(&"man_slide"):
		var animation := AnimationNodeAnimation.new()
		animation.animation = &"camel_man_slide_added/man_slide"
		machine.add_node(&"man_slide", animation, Vector2(640, -170))
		for from_name in [&"man_idle", &"man_walk"]:
			var transition := AnimationNodeStateMachineTransition.new()
			transition.xfade_time = 0.2
			machine.add_transition(from_name, &"man_slide", transition)
		var transition := AnimationNodeStateMachineTransition.new()
		transition.xfade_time = 0.2
		machine.add_transition(&"man_slide", &"man_idle", transition)

func _slide_active() -> bool:
	return _is_sliding or _slide_velocity.length() > 1.0

func _physics_process(delta: float) -> void:
	if not is_active:
		return

	var slide_was_active := _slide_active()
	if not is_on_floor() or slide_was_active:
		velocity += get_gravity() * (slide_gravity_multiplier if slide_was_active else 1.0) * delta

	var input_dir := Vector2.ZERO
	if not Global.in_cutscene:
		input_dir = Input.get_vector("Left", "Right", "Up", "Down")
	var cam_basis: Basis = get_viewport().get_camera_3d().global_basis
	var forward := -cam_basis.z
	forward.y = 0
	forward = forward.normalized()
	var right := cam_basis.x
	right.y = 0
	right = right.normalized()
	var direction := (right * input_dir.x + forward * -input_dir.y).normalized()

	var on_steep_slope := is_on_floor() and rad_to_deg(get_floor_normal().angle_to(Vector3.UP)) >= slide_angle_threshold
	var downhill := Vector3.ZERO
	if on_steep_slope:
		downhill = Vector3.DOWN.slide(get_floor_normal())
		downhill.y = 0
		downhill = downhill.normalized()
	var pushing_uphill := on_steep_slope and direction.dot(downhill) < -uphill_input_threshold
	_is_sliding = on_steep_slope and not pushing_uphill
	var previous_slide_velocity := _slide_velocity
	if _is_sliding:
		var steepness := sin(get_floor_normal().angle_to(Vector3.UP))
		_slide_velocity += downhill * slide_acceleration * steepness * delta
		_slide_velocity = _slide_velocity.limit_length(max_slide_speed)
	elif pushing_uphill:
		_slide_velocity = _slide_velocity.move_toward(Vector3.ZERO, 40.0 * delta)
	elif is_on_floor():
		_slide_velocity = _slide_velocity.move_toward(Vector3.ZERO, slide_momentum_decay * delta)

	if _slide_active() and not pushing_uphill:
		direction = Vector3.ZERO
	velocity.x -= previous_slide_velocity.x
	velocity.z -= previous_slide_velocity.z
	if direction.length() > 0.01:
		velocity.x = move_toward(velocity.x, max_speed * direction.x, acceleration * delta)
		velocity.z = move_toward(velocity.z, max_speed * direction.z, acceleration * delta)
		if direction.dot(velocity) < 0:
			velocity.x = 0
			velocity.z = 0
	else:
		velocity.x = move_toward(velocity.x, 0, deceleration * delta)
		velocity.z = move_toward(velocity.z, 0, deceleration * delta)
	velocity.x += _slide_velocity.x
	velocity.z += _slide_velocity.z

	var sliding_now := _slide_active()
	floor_snap_length = maxf(slide_snap_length, 2.5) if sliding_now else _default_snap_length
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
	if _slide_velocity.length() > Vector2(velocity.x, velocity.z).length():
		_slide_velocity = _slide_velocity.limit_length(Vector2(velocity.x, velocity.z).length())

	if sliding_now and not _slide_animation_playing:
		_slide_animation_playing = true
		state_machine.travel(&"man_slide")
	elif not sliding_now and _slide_animation_playing:
		_slide_animation_playing = false
		state_machine.travel(&"man_idle")
	if sliding_now and _slide_velocity.length() > 0.2:
		_target_yaw = Vector3.BACK.signed_angle_to(_slide_velocity.normalized(), Vector3.UP)
	elif direction.length() > 0.2:
		_target_yaw = Vector3.BACK.signed_angle_to(direction, Vector3.UP)
	visuals.global_rotation.y = lerp_angle(visuals.global_rotation.y, _target_yaw, rotation_speed * delta)

func _get_water_event() -> void:
	Global.in_cutscene = true
	get_tree().call_group("oasis_water_interaction", "consume")
	animation_tree.animation_finished.connect(_on_water_fin)
	state_machine.start("get_water")

func _on_water_fin(anim_name: StringName) -> void:
	if anim_name != &"man_scoop_water": return
	_on_finish_get_water()
	animation_tree.animation_finished.disconnect(_on_water_fin)

func _on_finish_get_water() -> void:
	Global.got_water = true
	Global.in_cutscene = false
