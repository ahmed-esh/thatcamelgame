extends CharacterBody3D

const Forms = preload("res://scripts/forms.gd")
var terrain: Node3D
var camera: Camera3D
var body: Node3D
var left_foot: MeshInstance3D
var right_foot: MeshInstance3D
var scarf_material: ShaderMaterial
var dust: GPUParticles3D
var yaw := -2.55
var pitch := 0.24
var orbit_distance := 12.5
var phase := 0.0
var last_step := 0
var sliding := false
var slide_distance := 0.0
var landing_speed := 0.0
var was_grounded := false
var camera_ready := false
var automated := false
var auto_move := Vector2.ZERO
var auto_run := false
var auto_slide := false
var auto_jump := false
var step_audio: AudioStreamPlayer3D
var slide_audio: AudioStreamPlayer3D
var footsteps := 0
var jumps := 0
var slide_frames := 0

func _ready() -> void:
	name = "Traveler"
	floor_max_angle = deg_to_rad(57)
	floor_snap_length = 0.65
	safe_margin = 0.04
	var capsule := CapsuleShape3D.new()
	capsule.radius = 0.38
	capsule.height = 1.9
	var shape := CollisionShape3D.new()
	shape.shape = capsule
	shape.position.y = 1.0
	add_child(shape)
	body = Node3D.new()
	add_child(body)
	body.rotation.y = yaw
	var cloak := ShaderMaterial.new()
	cloak.shader = load("res://shaders/cloth.gdshader")
	var rings: Array = []
	for j in 13:
		var t := float(j)/12
		rings.append(Vector4(0,0.22+t*1.6,0,lerpf(0.72,0.22,t)+sin(t*PI)*0.06))
	Forms.add_mesh(body,Forms.rings(rings,32,2,0.04),cloak,Vector3.ZERO,false,"Cloak")
	var hood := SphereMesh.new()
	hood.radius = 0.35
	hood.height = 0.72
	Forms.add_mesh(body,hood,cloak,Vector3(0,1.94,0),false,"Hood")
	var face := SphereMesh.new()
	face.radius = 0.25
	face.height = 0.43
	Forms.add_mesh(body,face,Forms.standard(Color(0.004,0.006,0.018)),Vector3(0,1.94,-0.19),false,"Veil")
	var eye := SphereMesh.new()
	eye.radius = 0.035
	eye.height = 0.05
	var cyan := Forms.standard(Color(0.08,0.7,0.8),0.4,Color(0.1,0.8,1))
	for x in [-0.09,0.09]:
		Forms.add_mesh(body,eye,cyan,Vector3(x,1.98,-0.423),false,"MoonEye")
	var boots := CapsuleMesh.new()
	boots.radius = 0.115
	boots.height = 0.35
	var boot_mat := Forms.standard(Color(0.025,0.035,0.07))
	left_foot = Forms.add_mesh(body,boots,boot_mat,Vector3(-0.25,0.14,0),false,"LeftFoot")
	right_foot = Forms.add_mesh(body,boots,boot_mat,Vector3(0.25,0.14,0),false,"RightFoot")
	scarf_material = ShaderMaterial.new()
	scarf_material.shader = load("res://shaders/cloth.gdshader")
	scarf_material.set_shader_parameter("scarf",true)
	scarf_material.set_shader_parameter("color",Color(0.07,0.18,0.25))
	var vertices := PackedVector3Array()
	var uvs := PackedVector2Array()
	var ids := PackedInt32Array()
	for j in 41:
		var t := float(j)/40
		for x in 2:
			vertices.append(Vector3((x-0.5)*0.25*(1.0-t*0.65),1.72-t*0.36,0.2+t*3.8))
			uvs.append(Vector2(x,t))
		if j<40:
			var k := j*2
			ids.append_array(PackedInt32Array([k,k+1,k+2,k+1,k+3,k+2]))
	Forms.add_mesh(body,Forms.surface(vertices,ids,uvs),scarf_material,Vector3.ZERO,false,"Scarf")
	camera = Camera3D.new()
	camera.fov = 68
	camera.near = 0.12
	camera.far = 3000
	camera.top_level = true
	add_child(camera)
	camera.current = true
	_build_dust()
	step_audio = AudioStreamPlayer3D.new()
	step_audio.max_distance = 30
	step_audio.volume_db = -12
	add_child(step_audio)
	slide_audio = AudioStreamPlayer3D.new()
	slide_audio.max_distance = 40
	slide_audio.volume_db = -32
	add_child(slide_audio)
	if not automated:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		yaw -= event.relative.x*0.0025
		pitch = clampf(pitch+event.relative.y*0.002,0.03,1.1)
	if event is InputEventKey and event.pressed and event.keycode==KEY_ESCAPE:
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	if event is InputEventMouseButton and event.pressed:
		if event.button_index==MOUSE_BUTTON_LEFT:
			Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
		elif event.button_index==MOUSE_BUTTON_WHEEL_UP:
			orbit_distance = maxf(6,orbit_distance-1)
		elif event.button_index==MOUSE_BUTTON_WHEEL_DOWN:
			orbit_distance = minf(23,orbit_distance+1)

func _physics_process(delta: float) -> void:
	if terrain == null:
		return
	terrain.follow(global_position)
	var input := auto_move if automated else Input.get_vector("left","right","forward","back")
	var running := auto_run if automated else Input.is_action_pressed("run")
	var request_slide := auto_slide if automated else Input.is_action_pressed("slide")
	var request_jump := auto_jump if automated else Input.is_action_just_pressed("jump")
	auto_jump = false
	var wish := Vector3(cos(yaw)*input.x+sin(yaw)*input.y,0,-sin(yaw)*input.x+cos(yaw)*input.y)
	var grounded := is_on_floor()
	var n := get_floor_normal() if grounded else Vector3.UP
	var slope := Vector2(n.x,n.z).length()
	sliding = grounded and request_slide and (slope>0.12 or Vector2(velocity.x,velocity.z).length()>5.0)
	var horizontal := Vector3(velocity.x,0,velocity.z)
	if sliding:
		slide_frames += 1
		horizontal += Vector3(n.x,0,n.z)*26.0*delta+wish*7.0*delta
		horizontal = horizontal.move_toward(Vector3.ZERO,1.8*delta).limit_length(34)
		floor_stop_on_slope = false
	else:
		floor_stop_on_slope = true
		var speed := 13.0 if running else 6.5
		if Vector2(global_position.x/47,(global_position.z+140)/34).length()<1.0:
			speed *= 0.62
		horizontal = horizontal.move_toward(wish*speed,(22.0 if grounded else 5.0)*delta)
	velocity.x = horizontal.x
	velocity.z = horizontal.z
	velocity.y -= 23.0*delta
	if request_jump and grounded:
		velocity.y = 9.3
		jumps += 1
	landing_speed = velocity.y
	move_and_slide()
	global_position.x = clampf(global_position.x,-1018,1018)
	global_position.z = clampf(global_position.z,-1018,1018)
	var speed := horizontal.length()
	if speed>0.2:
		body.rotation.y = lerp_angle(body.rotation.y,atan2(-horizontal.x,-horizontal.z),1.0-exp(-delta*10))
	var old_phase := phase
	if grounded and speed>0.3:
		phase += speed*delta*2.7
	left_foot.position = Vector3(-0.25,0.14+maxf(0,sin(phase))*0.22,cos(phase)*0.23)
	right_foot.position = Vector3(0.25,0.14+maxf(0,-sin(phase))*0.22,-cos(phase)*0.23)
	body.rotation.z = lerpf(body.rotation.z,(-input.x*0.13 if sliding else 0.0),delta*6)
	body.position.y = -0.21 if sliding else sin(phase*2)*minf(speed,1.0)*0.025
	scarf_material.set_shader_parameter("motion",speed/12.0)
	if grounded and speed>0.4 and not sliding and floori(phase/PI)!=floori(old_phase/PI):
		var foot := left_foot if sin(phase)<0 else right_foot
		var point := foot.global_position
		point.y = global_position.y
		if absf(point.y-terrain.base_height(point.x,point.z))<0.7:
			terrain.stamp(point,-body.global_basis.z,0.28,0.46,0.105)
			footsteps += 1
			step_audio.pitch_scale = randf_range(0.85,1.15)
			step_audio.play()
	if is_on_floor() and not was_grounded and landing_speed < -4.5 and absf(global_position.y-terrain.base_height(global_position.x,global_position.z))<0.7:
		terrain.stamp(global_position,-body.global_basis.z,0.9,0.95,minf(0.24,-landing_speed*0.013))
	if sliding:
		slide_distance += speed*delta
		if slide_distance>0.32 and absf(global_position.y-terrain.base_height(global_position.x,global_position.z))<0.8:
			slide_distance = 0
			terrain.stamp(global_position,-body.global_basis.z,0.65,0.72,0.11)
	dust.emitting = grounded and speed>5.0
	dust.amount_ratio = 0.85 if sliding else 0.12
	slide_audio.volume_db = lerpf(slide_audio.volume_db,-16.0 if sliding else -50.0,delta*4)
	was_grounded = is_on_floor()

func _process(delta: float) -> void:
	if camera == null:
		return
	var focus := global_position+Vector3(0,2.6,0)
	var offset := Vector3(sin(yaw)*cos(pitch),sin(pitch),cos(yaw)*cos(pitch))*orbit_distance
	var desired := focus+offset
	var ray := PhysicsRayQueryParameters3D.create(focus,desired,1,[get_rid()])
	var hit := get_world_3d().direct_space_state.intersect_ray(ray)
	if not hit.is_empty():
		desired = hit.position+hit.normal*0.45
	if not camera_ready:
		camera.global_position = desired
		camera_ready = true
	camera.global_position = camera.global_position.lerp(desired,1.0-exp(-delta*7))
	camera.look_at(focus)
	camera.fov = lerpf(camera.fov,73.0 if sliding else 68.0,delta*2)

func _build_dust() -> void:
	dust = GPUParticles3D.new()
	dust.amount = 160
	dust.lifetime = 1.4
	dust.position.y = 0.13
	dust.visibility_aabb = AABB(Vector3(-20,-5,-20),Vector3(40,20,40))
	var process := ParticleProcessMaterial.new()
	process.direction = Vector3(0,1,0)
	process.spread = 75
	process.initial_velocity_min = 0.4
	process.initial_velocity_max = 2.7
	process.gravity = Vector3(0.8,-1.2,0.4)
	process.scale_min = 0.007
	process.scale_max = 0.025
	process.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	process.emission_sphere_radius = 0.4
	process.color = Color(0.22,0.5,0.8,0.45)
	dust.process_material = process
	var mesh := SphereMesh.new()
	mesh.radius = 1
	mesh.height = 2
	mesh.radial_segments = 6
	mesh.rings = 3
	mesh.material = Forms.standard(Color(0.3,0.5,0.8),0.9,Color(0.04,0.1,0.15))
	dust.draw_pass_1 = mesh
	add_child(dust)
