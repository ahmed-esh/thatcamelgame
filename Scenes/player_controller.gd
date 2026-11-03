class_name Person
extends CharacterBody3D

@export var max_speed : float
@export var acceleration : float
@export var deceleration : float
@export var is_active : bool
var mouse_sensitivity : float = 1
@export var tilt_limit : float = 75

var desiredVelocity : Vector3
var can_get_on_camel : bool

@onready var camera_target: Node3D = $CameraPivot/SpringArm3D/CameraTarget

@onready var _camera_pivot = $CameraPivot
@onready var area_3d: Area3D = $Area3D




func _ready() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	
	# Setting cam. 
	Global.player = self
	Global.player_camera_node = camera_target
	mouse_sensitivity = Global.mouse_sens
	
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
	
	# Getting on camels
	if event.is_action_pressed("Mount"):
		print("hi")
		for areas in area_3d.get_overlapping_bodies():
			print(areas.name)
			
			if (areas is not Camel): continue
			
			# this is a camel, we will proceed.
			print("something worked")
			Global.camel.GET_ON_CAMEL()
			return
		# what is if nothign is detected, idk die. 
	
	
	
	# Mouselook implemented using `screen_relative` for resolution-independent sensitivity.
	if event is InputEventMouseMotion:
		_camera_pivot.rotation.x -= event.screen_relative.y * mouse_sensitivity
		# Prevent the camera from rotating too far up or down.
		_camera_pivot.rotation.x = clampf(_camera_pivot.rotation.x, -tilt_limit, tilt_limit)
		_camera_pivot.rotation.y += -event.screen_relative.x * mouse_sensitivity

func _physics_process(delta: float) -> void:
	if (not is_active): return
	
	if not is_on_floor():
		velocity += get_gravity() * delta

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
