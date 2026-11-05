extends Node3D

const Terrain = preload("res://scripts/terrain.gd")
const Traveler = preload("res://scripts/traveler.gd")
const Forms = preload("res://scripts/forms.gd")
var terrain: Node3D
var traveler: CharacterBody3D
var environment: WorldEnvironment
var oasis: Node3D
var landmarks: Node3D
var ready_to_explore := false

func _ready() -> void:
	_setup_input()
	_build_atmosphere()
	terrain = Terrain.new()
	terrain.name = "SculptedDesert"
	add_child(terrain)
	var grains := _grain_texture()
	terrain.material.set_shader_parameter("grain_texture",grains)
	terrain.local_material.set_shader_parameter("grain_texture",grains)
	traveler = Traveler.new()
	traveler.terrain = terrain
	traveler.automated = OS.get_cmdline_user_args().has("--validate") or OS.get_cmdline_user_args().has("--capture")
	traveler.position = Vector3(-616,terrain.base_height(-616,-696)+0.1,-696)
	terrain.follow(traveler.position)
	add_child(traveler)
	landmarks = Node3D.new()
	landmarks.name = "Landmarks"
	add_child(landmarks)
	_build_landmarks()
	_build_wind_sand()
	_build_audio()
	ready_to_explore = true
	print("QUIET_SANDS_READY terrain=2048x2048 relief=",terrain.maximum-terrain.minimum," palms=13 ruins=6 outcrops=15 renderer=",RenderingServer.get_current_rendering_method())

func _setup_input() -> void:
	var bindings := {"forward":[KEY_W,KEY_UP],"back":[KEY_S,KEY_DOWN],"left":[KEY_A,KEY_LEFT],"right":[KEY_D,KEY_RIGHT],"run":[KEY_SHIFT],"jump":[KEY_SPACE],"slide":[KEY_CTRL,KEY_C]}
	for action in bindings:
		if not InputMap.has_action(action):
			InputMap.add_action(action)
		for key in bindings[action]:
			var event := InputEventKey.new()
			event.physical_keycode = key
			InputMap.action_add_event(action,event)

func _build_atmosphere() -> void:
	environment = WorldEnvironment.new()
	var env := Environment.new()
	var sky := Sky.new()
	var sky_material := ShaderMaterial.new()
	sky_material.shader = load("res://shaders/sky.gdshader")
	sky.sky_material = sky_material
	sky.radiance_size = Sky.RADIANCE_SIZE_256
	env.background_mode = Environment.BG_SKY
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.32,0.4,0.65)
	env.ambient_light_energy = 0.65
	env.ambient_light_sky_contribution = 0.0
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.tonemap_exposure = 1.2
	env.glow_enabled = true
	env.glow_intensity = 0.45
	env.glow_bloom = 0.04
	env.glow_hdr_threshold = 1.2
	env.fog_enabled = true
	env.fog_light_color = Color(0.105,0.12,0.27)
	env.fog_light_energy = 0.6
	env.fog_density = 0.00065
	env.fog_sky_affect = 0.0
	env.volumetric_fog_enabled = true
	env.volumetric_fog_density = 0.00018
	env.volumetric_fog_albedo = Color(0.22,0.28,0.52)
	env.volumetric_fog_length = 350
	env.volumetric_fog_emission = Color(0.001,0.001,0.004)
	env.ssao_enabled = true
	env.ssao_radius = 2.0
	env.ssao_intensity = 1.1
	env.ssr_enabled = true
	environment.environment = env
	add_child(environment)
	var moon := DirectionalLight3D.new()
	moon.name = "Moonlight"
	moon.light_color = Color(0.65,0.77,1.0)
	moon.light_energy = 1.7
	moon.shadow_enabled = true
	moon.directional_shadow_max_distance = 650
	moon.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_4_SPLITS
	moon.shadow_bias = 0.025
	moon.shadow_normal_bias = 1.2
	moon.light_angular_distance = 0.7
	add_child(moon)
	moon.look_at(-Vector3(0.42,0.34,0.84).normalized(),Vector3.UP)

func _grain_texture() -> ImageTexture:
	var rng := RandomNumberGenerator.new()
	rng.seed = 74109
	var image := Image.create(256,256,false,Image.FORMAT_RGBA8)
	for y in 256:
		for x in 256:
			var a := clampf(rng.randfn(0.5,0.18),0.0,1.0)
			var b := clampf(rng.randfn(0.5,0.18),0.0,1.0)
			image.set_pixel(x,y,Color(a,b,rng.randf(),1))
	image.generate_mipmaps()
	return ImageTexture.create_from_image(image)

func _build_landmarks() -> void:
	var oasis_scene: PackedScene = load("res://scenes/oasis.tscn")
	oasis = oasis_scene.instantiate()
	oasis.position = Vector3(0,0,-140)
	oasis.set("terrain",terrain)
	oasis.set("traveler",traveler)
	landmarks.add_child(oasis)
	for spec in [["res://scenes/natural_arch.tscn",Vector3(560,6,460)],["res://scenes/sandstone_spires.tscn",Vector3(-550,6,630)]]:
		var scene: PackedScene = load(spec[0])
		var mountain := scene.instantiate()
		mountain.position = spec[1]
		landmarks.add_child(mountain)
	var ruin_scene: PackedScene = load("res://scenes/ruin.tscn")
	var positions := [Vector2(-460,-440),Vector2(350,-510),Vector2(470,-60),Vector2(-390,190),Vector2(150,420),Vector2(670,740)]
	for i in positions.size():
		var p: Vector2 = positions[i]
		var ruin := ruin_scene.instantiate()
		ruin.name = "AncientRuin_%s" % (i+1)
		ruin.variant = i
		ruin.position = Vector3(p.x,terrain.base_height(p.x,p.y)-0.8,p.y)
		ruin.rotation.y = [0.3,-0.7,1.8,0.9,-0.4,2.3][i]
		ruin.set("terrain",terrain)
		landmarks.add_child(ruin)
	var stone := ShaderMaterial.new()
	stone.shader = load("res://shaders/stone.gdshader")
	var outcrops := [Vector2(-710,-620),Vector2(-510,-400),Vector2(-370,-465),Vector2(300,-550),Vector2(410,-460),Vector2(510,-80),Vector2(-420,220),Vector2(-350,165),Vector2(130,480),Vector2(630,710),Vector2(720,770),Vector2(400,410),Vector2(-440,540),Vector2(80,-90),Vector2(-75,-180)]
	for i in outcrops.size():
		var p: Vector2 = outcrops[i]
		var height: float = [4.0,8.0,3.0,6.0,14.0][i%5]
		var rock := Forms.add_mesh(landmarks,Forms.rock(3.5+float(i%4)*2.0,height,float(i)*2.1,i%3==0),stone,Vector3(p.x,terrain.base_height(p.x,p.y)-1.2,p.y),true,"Outcrop_%02d" % (i+1))
		rock.rotation.y = i*2.4

func _build_audio() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 187
	var wind := AudioStreamPlayer.new()
	wind.name = "WindAcrossDunes"
	wind.stream = _noise_sound(rng,6.0,0.013,true)
	wind.volume_db = -26
	add_child(wind)
	wind.play()
	traveler.step_audio.stream = _noise_sound(rng,0.22,0.38,false)
	traveler.slide_audio.stream = _noise_sound(rng,2.0,0.12,true)
	traveler.slide_audio.play()
	var water := AudioStreamPlayer3D.new()
	water.name = "OasisWater"
	water.stream = _noise_sound(rng,4.0,0.05,true)
	water.position = Vector3(0,0,-140)
	water.volume_db = -22
	water.unit_size = 12
	water.max_distance = 90
	add_child(water)
	water.play()

func _build_wind_sand() -> void:
	var dust_material := ShaderMaterial.new()
	dust_material.shader = load("res://shaders/wind_sand.gdshader")
	for p in [Vector2(-350,-745),Vector2(180,-870),Vector2(-190,150),Vector2(200,268),Vector2(-710,90)]:
		var dust := GPUParticles3D.new()
		dust.name = "WindAcrossCrest"
		dust.position = Vector3(p.x,terrain.base_height(p.x,p.y)+0.7,p.y)
		dust.amount = 32
		dust.lifetime = 5.0
		dust.preprocess = 2.0
		dust.visibility_aabb = AABB(Vector3(-40,-10,-40),Vector3(80,40,80))
		var process := ParticleProcessMaterial.new()
		process.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
		process.emission_box_extents = Vector3(22,0.3,3)
		process.direction = Vector3(0.87,0.06,0.49)
		process.spread = 12
		process.initial_velocity_min = 1.0
		process.initial_velocity_max = 3.0
		process.gravity = Vector3(0,0.05,0)
		process.scale_min = 1.0
		process.scale_max = 3.0
		var gradient := Gradient.new()
		gradient.colors = PackedColorArray([Color(1,1,1,0),Color(1,1,1,0.7),Color(1,1,1,0)])
		gradient.offsets = PackedFloat32Array([0,0.3,1])
		var texture := GradientTexture1D.new()
		texture.gradient = gradient
		process.color_ramp = texture
		dust.process_material = process
		var mesh := QuadMesh.new()
		mesh.size = Vector2(3,1.3)
		mesh.material = dust_material
		dust.draw_pass_1 = mesh
		add_child(dust)

func _noise_sound(rng: RandomNumberGenerator, seconds: float, smoothing: float, looping: bool) -> AudioStreamWAV:
	var count := int(seconds*22050)
	var data := PackedByteArray()
	data.resize(count*2)
	var previous := 0.0
	for i in count:
		previous = lerpf(previous,rng.randf_range(-1,1),smoothing)
		var t := float(i)/count
		var envelope := (0.65+sin(t*TAU)*0.2) if looping else pow(1.0-t,2.5)*minf(t*35.0,1.0)
		var seam := minf(1.0,minf(t,1.0-t)*70.0) if looping else 1.0
		data.encode_s16(i*2,int(previous*envelope*seam*24000))
	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = 22050
	stream.data = data
	if looping:
		stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
		stream.loop_end = count
	return stream
