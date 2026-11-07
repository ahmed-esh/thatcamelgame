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

var _target_yaw

var mouse_sensitivity : float = 1
var desiredVelocity : Vector3
var can_get_on_camel : bool
var _prev_dir : Vector3

@onready var camera_target: Node3D = $CameraPivot/SpringArm3D/CameraTarget
@onready var _camera_pivot = $CameraPivot
@onready var area_3d: Area3D = $Area3D
@onready var animation_tree: AnimationTree = $AnimationTree
@onready var visuals : Node3D = $man

@onready var man: Node3D = $man
var state_machine : AnimationNodeStateMachinePlayback

func _ready() -> void:
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


func _physics_process(delta: float) -> void:
	if (not is_active): return

	if not is_on_floor():
		velocity += get_gravity() * delta

	# During a cutscene, input is zeroed but physics and animation still run.
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

	if direction:
		velocity.x = move_toward(velocity.x, max_speed * direction.x, acceleration * delta)
		velocity.z = move_toward(velocity.z, max_speed * direction.z, acceleration * delta)

		if (direction.dot(velocity) < 0):
			velocity.x = 0
			velocity.z = 0
	else:
		velocity.x = move_toward(velocity.x, 0, deceleration * delta)
		velocity.z = move_toward(velocity.z, 0, deceleration * delta)

	move_and_slide()
	if (direction.length() > 0.2):
		_target_yaw = Vector3.BACK.signed_angle_to(direction, Vector3.UP)

	visuals.global_rotation.y = lerp_angle(visuals.global_rotation.y, _target_yaw, rotation_speed * delta)

func _get_water_event() -> void:
	Global.in_cutscene = true
	animation_tree.animation_finished.connect(_on_water_fin)
	state_machine.start("get_water")

func _on_water_fin(anim_name: StringName) -> void:
	if anim_name != &"man_scoop_water": return
	_on_finish_get_water()
	animation_tree.animation_finished.disconnect(_on_water_fin)

func _on_finish_get_water() -> void:
	Global.got_water = true
	Global.in_cutscene = false
