extends SceneTree

var world: Node3D
var view: Camera3D

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	root.size = Vector2i(1440,900)
	world = load("res://scenes/quiet_sands.tscn").instantiate()
	var start_time := Time.get_ticks_msec()
	root.add_child(world)
	print("WORLD_BUILD_MS ",Time.get_ticks_msec()-start_time)
	await process_frame
	world.traveler.set_physics_process(false)
	world.traveler.set_process(false)
	view = Camera3D.new()
	view.fov = 66
	view.far = 3000
	root.add_child(view)
	view.current = true
	var start: Vector3 = world.traveler.position
	await shoot("01_start",start+Vector3(-9,6,-14),start+Vector3(70,10,105))
	await shoot("02_moonlit_dunes",Vector3(-380,180,-610),Vector3(100,40,160))
	await shoot("03_oasis",Vector3(-95,45,-229),Vector3(0,4,-140))
	await shoot("04_natural_arch",Vector3(455,55,300),Vector3(560,36,460))
	await shoot("05_sandstone_spires",Vector3(-697,65,430),Vector3(-550,44,630))
	var ruin: Node3D = world.landmarks.get_node("AncientRuin_1")
	await shoot("07_ancient_ruins",ruin.position+Vector3(-24,15,-37),ruin.position+Vector3(0,4,0))
	var p := Vector3(-610,0,-680)
	p.y = world.terrain.base_height(p.x,p.z)
	world.terrain.follow(p)
	for i in 16:
		var step := p+Vector3(0.25 if i%2==0 else -0.25,0,float(i)*0.8)
		world.terrain.stamp(step,Vector3.FORWARD,0.28,0.46,0.14)
	await shoot("06_footprints",p+Vector3(3.2,4.0,-3.8),p+Vector3(0,0,3.5))
	for layer in range(1,7):
		world.terrain.material.set_shader_parameter("layer_view",layer)
		world.terrain.local_material.set_shader_parameter("layer_view",layer)
		await shoot("layer_%s" % layer,p+Vector3(3.2,4.0,-3.8),p+Vector3(0,0,3.5))
	world.terrain.material.set_shader_parameter("layer_view",0)
	world.terrain.local_material.set_shader_parameter("layer_view",0)
	await shoot("08_sand_overhead",p+Vector3(0,13,-0.1),p)
	var grazing := p+Vector3(-2,0,-6)
	grazing.y = world.terrain.base_height(grazing.x,grazing.z)+0.8
	var grazing_target := p+Vector3(0,0,6)
	grazing_target.y = world.terrain.base_height(grazing_target.x,grazing_target.z)+0.2
	await shoot("09_sand_grazing",grazing,grazing_target)
	for i in 35:
		var slide := p+Vector3(6.0+sin(i*0.08),0,i*0.35)
		world.terrain.stamp(slide,Vector3.FORWARD,0.65,0.72,0.09)
	await shoot("10_sliding_trail",p+Vector3(11,7,-5),p+Vector3(5,0,6))
	world.traveler.set_physics_process(true)
	world.traveler.set_process(true)
	world.traveler.camera.current = true
	world.traveler.auto_move = Vector2(0,-1)
	world.traveler.auto_run = true
	for i in 30:
		await process_frame
	var frame_times: Array[float] = []
	var previous := Time.get_ticks_usec()
	for i in 120:
		await process_frame
		var now := Time.get_ticks_usec()
		frame_times.append(float(now-previous)/1000.0)
		previous = now
	frame_times.sort()
	var total := 0.0
	for timing in frame_times:
		total += timing
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://captures/11_exploration.png")
	var report := {"engine":Engine.get_version_info().string,"renderer":RenderingServer.get_current_rendering_method(),"device":RenderingServer.get_video_adapter_name(),"resolution":"1440x900","mean_frame_ms":total/frame_times.size(),"p95_frame_ms":frame_times[114],"max_frame_ms":frame_times.back(),"measured_frames":frame_times.size(),"moving_footsteps":world.traveler.footsteps}
	var file := FileAccess.open("res://validation/render_results.json",FileAccess.WRITE)
	file.store_string(JSON.stringify(report,"\t"))
	print("RENDERED_MOVEMENT ",JSON.stringify(report))
	print("CAPTURES_COMPLETE")
	call_deferred("finish")

func shoot(label: String, from: Vector3, target: Vector3) -> void:
	view.position = from
	view.look_at(target)
	var start := Time.get_ticks_usec()
	for i in 24:
		await process_frame
	await RenderingServer.frame_post_draw
	var screenshot := root.get_texture().get_image()
	var path := "res://captures/%s.png" % label
	var result := screenshot.save_png(path)
	print("CAPTURE ",label," result=",result)
	print("FRAME_AVERAGE_MS ",label," ",(Time.get_ticks_usec()-start)/24000.0)

func finish() -> void:
	view.queue_free()
	world.queue_free()
	await process_frame
	await process_frame
	quit()
