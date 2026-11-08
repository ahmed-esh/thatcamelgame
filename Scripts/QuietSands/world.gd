
extends "res://Scenes/GameManager.gd"

const Terrain = preload("res://Scripts/QuietSands/terrain.gd")
const Traveler = preload("res://Scripts/QuietSands/traveler.gd")
const Forms = preload("res://Scripts/QuietSands/forms.gd")
var terrain: Node3D
var traveler: CharacterBody3D
var camel: CharacterBody3D
var environment: WorldEnvironment
var oasis: Node3D
var landmarks: Node3D
var ready_to_explore := false
var _painting_sprites: Dictionary = {}
var _painting_seen: Dictionary = {}
var _active_painting := 0
var _coverup_revealed := false
var _water_prompt_bound := false
var _prompt_mode := ""
var _camel_hint_finished := false
var _water_interaction: Area3D
var _interaction_audio: AudioStreamPlayer3D
var _oasis_dialogue_played := false
var _oasis_dialogue_finished := false
var _left_camel_after_water := false
var _next_painting := 1
var _dismount_area: Area3D
var _waypoint: Node3D
var _waypoint_star: Sprite3D
var _waypoint_target: Node3D
var _waypoint_transition: Tween
var _painting_triggers: Dictionary = {}

func _physics_process(_delta: float) -> void:
	if camel != null:
		traveler = camel if camel.is_active or camel.is_transitioning else $Player
		var companion: Node3D = camel if not camel.is_active and not camel.is_transitioning and Global.game_started else null
		terrain.follow(traveler.global_position, companion)
		oasis.traveler = traveler
		_check_paintings()
		_check_return_to_camel()
		_update_interaction_prompt()
		_update_waypoint_position()

func _process(_delta: float) -> void:
	if Global.game_started and not _water_prompt_bound and _water_interaction != null and Global.main_camera != null:
		_bind_water_prompt()
	if environment == null:
		return
	var view := get_viewport().get_camera_3d()
	if view != null:
		var near_water := Vector2(view.global_position.x,view.global_position.z+140.0).length()<180.0
		environment.environment.ssr_enabled = near_water

func _ready() -> void:
	super._ready()
	_setup_input()
	if has_node("SculptedDesert"):
		terrain = $SculptedDesert
		traveler = $Player
		camel = $Camel
		environment = $WorldEnvironment
		landmarks = $Landmarks
		oasis = $Landmarks/Oasis
		oasis.terrain = terrain
		oasis.traveler = traveler
		terrain.follow(traveler.position)
		ready_to_explore = true
		_setup_paintings_and_water()
		_setup_waypoint()
		super._ready()
		return
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

func _setup_paintings_and_water() -> void:
	for i in range(1, 5):
		var painting := get_node_or_null("painintgs/P%d" % i) as Sprite3D
		if painting != null:
			_painting_sprites[i] = painting
			var trigger := painting.get_node_or_null("DialogueTrigger") as Area3D
			if trigger == null:
				for child in painting.get_children():
					if child is Area3D:
						trigger = child
						break
			if trigger != null:
				trigger.monitoring = true
				trigger.collision_mask |= $Player.collision_layer | $Camel.collision_layer
				_painting_triggers[i] = trigger
	var manager: Node = get_node("Dialouge manger")
	manager.connect("conversation_finished", Callable(self, "_on_painting_finished"))
	var water_scene: PackedScene = load("res://Scenes/BoxColliderToGetWater.tscn")
	_water_interaction = water_scene.instantiate() as Area3D
	oasis.add_child(_water_interaction)
	_water_interaction.position = Vector3.ZERO
	var shape_node := _water_interaction.get_node("CollisionShape3D") as CollisionShape3D
	var box := BoxShape3D.new()
	var water_mesh := $Landmarks/Oasis/DreamingWater as MeshInstance3D
	var water_bounds := water_mesh.get_aabb()
	var oasis_size := Vector3(
		water_bounds.size.x * absf(water_mesh.scale.x),
		8.0,
		water_bounds.size.z * absf(water_mesh.scale.z)
	)
	box.size = oasis_size * 0.7
	shape_node.position = water_mesh.transform * water_bounds.get_center()
	shape_node.rotation = water_mesh.rotation
	shape_node.shape = box
	_dismount_area = Area3D.new()
	_dismount_area.name = "OasisDismountArea"
	_dismount_area.collision_layer = 0
	_dismount_area.collision_mask = _water_interaction.collision_mask
	oasis.add_child(_dismount_area)
	var outer_shape := CollisionShape3D.new()
	var outer_box := BoxShape3D.new()
	outer_box.size = oasis_size
	outer_shape.shape = outer_box
	outer_shape.position = shape_node.position
	outer_shape.rotation = shape_node.rotation
	_dismount_area.add_child(outer_shape)
	_interaction_audio = AudioStreamPlayer3D.new()
	_interaction_audio.volume_db = -2
	add_child(_interaction_audio)

func _make_waypoint_texture() -> ImageTexture:
	var picture := Image.create(64, 64, false, Image.FORMAT_RGBA8)
	for y in range(64):
		for x in range(64):
			var dx := (float(x) - 31.5) / 31.5
			var dy := (float(y) - 31.5) / 31.5
			var radius := sqrt(dx * dx + dy * dy)
			var glow := exp(-radius * 5.5) * 0.38
			var rays := exp(-absf(dx) * 16.0 - absf(dy) * 2.6) + exp(-absf(dy) * 16.0 - absf(dx) * 2.6)
			var alpha := clampf(glow + rays * 0.42, 0.0, 0.7) * (1.0 - smoothstep(0.5, 1.0, radius))
			picture.set_pixel(x, y, Color(0.7, 0.9, 1.0, alpha))
	return ImageTexture.create_from_image(picture)

func _setup_waypoint() -> void:
	_waypoint = Node3D.new()
	_waypoint.name = "DestinationLight"
	add_child(_waypoint)
	_waypoint_star = Sprite3D.new()
	_waypoint_star.texture = _make_waypoint_texture()
	_waypoint_star.pixel_size = 0.03
	_waypoint_star.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_waypoint_star.shaded = false
	_waypoint_star.fixed_size = true
	_waypoint_star.no_depth_test = true
	_waypoint_star.modulate = Color(0.76, 0.9, 1.0, 0.0)
	_waypoint.add_child(_waypoint_star)
	var bob := create_tween().set_loops()
	bob.tween_property(_waypoint_star, "position:y", 0.85, 1.8).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	bob.tween_property(_waypoint_star, "position:y", 0.0, 1.8).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	var shimmer := create_tween().set_loops()
	shimmer.tween_property(_waypoint_star, "scale", Vector3.ONE * 1.08, 1.5).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	shimmer.tween_property(_waypoint_star, "scale", Vector3.ONE, 1.5).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_update_waypoint_position()

func _update_waypoint_position() -> void:
	if _waypoint == null:
		return
	var target: Node3D = null
	if Global.game_started and not Global.in_cutscene:
		target = oasis
		if _oasis_dialogue_finished:
			target = _painting_sprites.get(_next_painting) as Node3D
	if target == _waypoint_target:
		return
	_waypoint_target = target
	if _waypoint_transition != null and _waypoint_transition.is_running():
		_waypoint_transition.kill()
	_waypoint_transition = create_tween()
	if _waypoint_star.modulate.a > 0.01:
		_waypoint_transition.tween_property(_waypoint_star, "modulate:a", 0.0, 0.45).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	if target != null:
		_waypoint_transition.tween_property(_waypoint, "global_position", target.global_position + Vector3.UP * 9.0, 0.001)
		_waypoint_transition.tween_property(_waypoint_star, "modulate:a", 0.68, 0.65).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)

func _bind_water_prompt() -> void:
	var prompt: Label3D = dialogue_label
	if prompt == null:
		return
	prompt.reparent(Global.main_camera, false)
	prompt.position = Vector3(0.0, -0.75, -2.4)
	prompt.rotation = Vector3.ZERO
	prompt.scale = Vector3.ONE
	prompt.pixel_size = 0.003
	prompt.font_size = 46
	prompt.no_depth_test = true
	prompt.text = ""
	prompt.hide()
	_water_interaction.call("set_prompt", prompt)
	_water_prompt_bound = true

func _update_interaction_prompt() -> void:
	if not _water_prompt_bound or Global.player == null:
		return
	if Global.is_camel or camel.is_transitioning:
		_camel_hint_finished = true
	var mode := ""
	if Global.game_started and not Global.in_cutscene and not Global.dialogue_active:
		if not Global.got_water and Global.is_camel and _dismount_area != null and _dismount_area.overlaps_body(camel):
			mode = "dismount"
		elif Global.player.is_active and Global.can_get_water and not Global.got_water:
			mode = "water"
		elif Global.player.is_active and not _camel_hint_finished and Global.player.area_3d.overlaps_body(camel):
			mode = "camel"
	if mode == _prompt_mode:
		return
	_prompt_mode = mode
	if mode == "water":
		_water_interaction.call("show_prompt", "Press E to get water")
	elif mode == "dismount":
		_water_interaction.call("show_prompt", "Press E to get off the camel")
	elif mode == "camel":
		_water_interaction.call("show_prompt", "Press E to get on the camel")
	else:
		_water_interaction.call("hide_prompt", true)

func _check_paintings() -> void:
	if not Global.game_started or Global.in_cutscene or Global.dialogue_active or not _oasis_dialogue_finished or _active_painting != 0:
		return
	if not _painting_sprites.has(_next_painting):
		return
	var painting: Sprite3D = _painting_sprites[_next_painting]
	var trigger := _painting_triggers.get(_next_painting) as Area3D
	if trigger == null:
		return
	if not trigger.overlaps_body($Player) and not trigger.overlaps_body(camel):
		return
	_active_painting = _next_painting
	_play_interaction_audio("res://sounds/interaction1.mp3", painting.global_position)
	get_node("Dialouge manger").call("p%d" % _active_painting)

func _check_return_to_camel() -> void:
	if _oasis_dialogue_played or not Global.got_water or Global.in_cutscene or Global.dialogue_active:
		return
	if camel.is_active or camel.is_transitioning or not Global.player.is_active:
		return
	var near_camel := Global.player.area_3d.overlaps_body(camel)
	if not near_camel:
		_left_camel_after_water = true
	elif _left_camel_after_water:
		_oasis_dialogue_played = true
		get_node("Dialouge manger").call("oasis")

func _on_painting_finished(conversation: String) -> void:
	if conversation == "Oasis":
		_oasis_dialogue_finished = true
		_update_waypoint_position()
		return
	if not conversation.begins_with("P") or _active_painting == 0:
		return
	var id := _active_painting
	_active_painting = 0
	_painting_seen[id] = true
	_next_painting = id + 1
	_glow_painting(_painting_sprites[id])
	_update_waypoint_position()
	if _painting_seen.has(1) and _painting_seen.has(2) and _painting_seen.has(3) and not _coverup_revealed:
		_coverup_revealed = true
		Global.in_cutscene = true
		await _sink_coverup()
	else:
		Global.in_cutscene = false

func _glow_painting(painting: Sprite3D) -> void:
	var original_scale := painting.scale
	var tween := create_tween()
	tween.tween_property(painting, "modulate", Color(1.65, 1.4, 1.9), 0.55).set_trans(Tween.TRANS_SINE)
	tween.parallel().tween_property(painting, "scale", original_scale * 1.1, 0.55).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(painting, "modulate", Color(1.18, 1.12, 1.32), 0.85).set_trans(Tween.TRANS_SINE)
	tween.parallel().tween_property(painting, "scale", original_scale, 0.85)

func _play_interaction_audio(path: String, location: Vector3) -> void:
	if _interaction_audio == null:
		return
	_interaction_audio.stream = load(path)
	_interaction_audio.global_position = location
	_interaction_audio.play()

func _sink_coverup() -> void:
	var coverup: Node3D = $Landmarks/coverup
	var center := Vector3.ZERO
	var spires: Array[MeshInstance3D] = []
	for child in coverup.get_children():
		if child is MeshInstance3D:
			spires.append(child)
			center += child.global_position
	if spires.is_empty():
		Global.in_cutscene = false
		return
	center /= float(spires.size())
	var radius := 0.0
	for spire in spires:
		radius = maxf(radius, Vector2(spire.global_position.x, spire.global_position.z).distance_to(Vector2(center.x, center.z)))
	var distance := maxf(30.0, radius * 2.0)
	var shot := Node3D.new()
	shot.name = "CoverupCameraTarget"
	add_child(shot)
	shot.global_position = center + Vector3(distance * 0.55, maxf(20.0, radius * 0.7), distance)
	shot.look_at(center + Vector3(0.0, 3.0, 0.0), Vector3.UP)
	await Global.main_camera.lerp_to_new(shot)
	_play_interaction_audio("res://sounds/interaction3.mp3", center)
	var start := coverup.position
	var motion := create_tween().set_parallel(true)
	motion.tween_property(coverup, "position:y", -122.131, 4.2).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	motion.tween_method(Callable(self, "_shake_coverup").bind(coverup, start), 0.0, 1.0, 4.2)
	for i in range(16):
		var spire: MeshInstance3D = spires[i % spires.size()]
		terrain.call("_sand_burst", spire.global_position, Vector3(0.7, 0.0, 0.4), 1.6, true)
		await get_tree().create_timer(0.26).timeout
	if motion.is_running():
		await motion.finished
	coverup.position.x = start.x
	coverup.position.z = start.z
	var follow_target: Node3D = Global.camel_camera_node if Global.is_camel else Global.player_camera_node
	await Global.main_camera.lerp_to_new(follow_target)
	shot.queue_free()
	Global.in_cutscene = false

func _shake_coverup(t: float, coverup: Node3D, start: Vector3) -> void:
	var intensity := sin(t * PI) * 0.22
	coverup.position.x = start.x + sin(t * 115.0) * intensity
	coverup.position.z = start.z + cos(t * 137.0) * intensity

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
	environment.name = "WorldEnvironment"
	var env := Environment.new()
	var sky := Sky.new()
	var sky_material := ShaderMaterial.new()
	sky_material.shader = load("res://Shaders/QuietSands/sky.gdshader")
	sky.sky_material = sky_material
	sky.radiance_size = Sky.RADIANCE_SIZE_256
	env.background_mode = Environment.BG_SKY
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.32,0.37,0.43)
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
	moon.light_color = Color(0.95,0.88,0.78)
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
	var oasis_scene: PackedScene = load("res://Scenes/QuietSands/oasis.tscn")
	oasis = oasis_scene.instantiate()
	oasis.position = Vector3(0,0,-140)
	oasis.set("terrain",terrain)
	oasis.set("traveler",traveler)
	landmarks.add_child(oasis)
	for spec in [["res://Scenes/QuietSands/natural_arch.tscn",Vector3(560,6,460)],["res://Scenes/QuietSands/sandstone_spires.tscn",Vector3(-550,6,630)]]:
		var scene: PackedScene = load(spec[0])
		var mountain := scene.instantiate()
		mountain.position = spec[1]
		landmarks.add_child(mountain)
	var ruin_scene: PackedScene = load("res://Scenes/QuietSands/ruin.tscn")
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
	stone.shader = load("res://Shaders/QuietSands/stone.gdshader")
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
	wind.autoplay = true
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
	water.autoplay = true
	add_child(water)
	water.play()

func _build_wind_sand() -> void:
	var dust_material := ShaderMaterial.new()
	dust_material.shader = load("res://Shaders/QuietSands/wind_sand.gdshader")
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
