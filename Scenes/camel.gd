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
		#velocity.z = move_toward(velocity.z, max_speed * direction.z, acceleration * delta)
		
		## check if the direction is completely 180
		if (direction.dot(velocity) < 0): 
			velocity.x = 0
			velocity.z = 0
	else:
		velocity.x = move_toward(velocity.x, 0, deceleration * delta)
		#velocity.z = move_toward(velocity.z, 0, deceleration * delta)
	
	move_and_slide()
	
	if (direction.length() > 0.2):
		_prev_dir = direction
	
	# manage visuals.
	var target_angle := Vector3.BACK.signed_angle_to(_prev_dir, Vector3.UP) # this means the difference in 
	visuals.global_rotation.y = lerp_angle(visuals.rotation.y, target_angle, rotation_speed * delta)

func GET_ON_CAMEL() -> void:
	Global.player.is_active = false
	is_transitioning = true
	
	Global.player.visible = false
	
	var dist
	if (abs((mount_left_start.global_position - Global.player.global_position).length()) >= abs((mount_right_start.global_position - Global.player.global_position).length())) :
		state_machine.start("mount_right")
	else:
		state_machine.start("mount_left")
	
	await Global.main_camera.lerp_to_new(Global.camel_camera_node)
	is_transitioning = false
	is_active = true

func GET_OFF_CAMEL() -> void:
	# the only way to determine whether we are on or off the camel. 
	if (is_active == false): return
	is_active = false
	
	
	
	await Global.main_camera.lerp_to_new(Global.player_camera_node)
	
	Global.player.is_active = true
	state_machine.travel("camel_idle")
	pass
