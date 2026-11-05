extends SceneTree

var failures: Array[String] = []
var world: Node3D

func _initialize() -> void:
	call_deferred("run")
	create_timer(120.0).timeout.connect(func(): push_error("Validation timed out"); quit(2))

func check(condition: bool, message: String) -> void:
	print("PASS " if condition else "FAIL ",message)
	if not condition:
		failures.append(message)

func frames(count: int) -> void:
	for i in count:
		await physics_frame

func run() -> void:
	world = load("res://scenes/quiet_sands.tscn").instantiate()
	root.add_child(world)
	await frames(30)
	var p: CharacterBody3D = world.traveler
	var terrain: Node3D = world.terrain
	check(world.ready_to_explore,"Scene initialized")
	check(RenderingServer.get_current_rendering_method()=="forward_plus","Forward+ configured")
	check(terrain.heights.size()==513*513,"Complete 2048 by 2048 heightfield")
	var bake_error := 0.0
	for i in 32:
		var x := (i*67)%513
		var z := (i*131)%513
		bake_error = maxf(bake_error,absf(terrain.heights[z*513+x]-terrain.sculpt(x*4-1024,z*4-1024)))
	check(bake_error<0.0001,"Baked terrain agrees with authored sculpting")
	check(terrain.maximum-terrain.minimum>190 and terrain.maximum-terrain.minimum<250,"Dramatic relief within art target")
	check(world.oasis.get_children().filter(func(n): return n.name.begins_with("Palm_")).size()==13,"Thirteen palm trees")
	check(world.landmarks.get_children().filter(func(n): return n.name.begins_with("AncientRuin_")).size()==6,"Six ruins")
	check(world.landmarks.get_children().filter(func(n): return n.name.begins_with("Outcrop_")).size()==15,"Fifteen outcrops")
	check(world.landmarks.has_node("NaturalArch") and world.landmarks.has_node("SandstoneSpires"),"Both mountain formations")
	check(p.is_on_floor(),"Traveler rests on sand collision")
	check(absf(p.position.y-terrain.base_height(p.position.x,p.position.z))<0.3,"Visible terrain agrees with contact height")
	var start := p.position
	p.auto_move = Vector2(0,-1)
	await frames(90)
	var walk_distance := p.position.distance_to(start)
	check(walk_distance>5,"Walking advances across dunes")
	check(p.footsteps>2,"Walking stamps actual alternating foot positions")
	start = p.position
	p.auto_run = true
	await frames(90)
	check(p.position.distance_to(start)>walk_distance*1.3,"Running increases travel speed")
	p.auto_move = Vector2.ZERO
	p.auto_run = false
	await frames(30)
	var floor_y := p.position.y
	p.auto_jump = true
	await frames(15)
	check(p.position.y>floor_y+0.7 and p.jumps==1,"Jump leaves the surface")
	await frames(80)
	check(p.is_on_floor(),"Landing returns to collision")
	var slope_point := Vector3.ZERO
	var found := false
	for z in range(-800,-500,8):
		if found:
			break
		for x in range(-700,-400,8):
			var n: Vector3 = terrain.normal_at(x,z)
			if n.y>0.8 and n.y<0.88:
				slope_point = Vector3(x,terrain.base_height(x,z)+0.12,z)
				found = true
				break
	check(found,"Composed terrain contains a slideable slip face")
	p.position = slope_point
	p.velocity = Vector3.ZERO
	terrain.follow(p.position)
	await frames(30)
	p.auto_slide = true
	start = p.position
	var old_stamps: int = terrain.stamp_count
	await frames(100)
	check(p.slide_frames>25 and p.position.distance_to(start)>4,"Slope gravity builds sliding momentum")
	check(terrain.stamp_count>old_stamps+3,"Slide deforms a continuous trail")
	p.auto_slide = false
	p.auto_move = Vector2.ZERO
	p.velocity = Vector3.ZERO
	p.position = Vector3(650,25,515)
	terrain.follow(p.position)
	await frames(100)
	var rock_start := p.position.y
	p.yaw = PI*0.5
	p.auto_move = Vector2(0,-1)
	p.auto_run = true
	await frames(210)
	print("CLIMB start_y=",rock_start," end=",p.position," grounded=",p.is_on_floor())
	check(p.position.y>rock_start+7.0 and p.is_on_floor(),"Traveler climbs the sandstone formation")
	p.auto_move = Vector2.ZERO
	p.auto_run = false
	p.position = Vector3(5,0,-140)
	p.velocity = Vector3.ZERO
	terrain.follow(p.position)
	await frames(60)
	p.auto_move = Vector2(0,-1)
	await frames(70)
	check(world.oasis.last_ripple>0,"Wading generates water interaction ripples")
	p.auto_move = Vector2.ZERO
	p.position = slope_point
	p.velocity = Vector3.ZERO
	terrain.follow(p.position)
	await frames(20)
	p.set_physics_process(false)
	var key: Vector2i = terrain.active.keys()[4]
	var probe := Vector3(key.x*16+8,0,key.y*16+8)
	probe.y = terrain.base_height(probe.x,probe.z)
	terrain.stamp(probe,Vector3.FORWARD,0.7,0.9,0.2)
	await frames(3)
	var data: Dictionary = terrain.history[key]
	check(Array(data.depth).min() < -0.1 and Array(data.depth).max() > 0.005,"Footprint has depression and displaced sand rim")
	var shape: HeightMapShape3D = terrain.active[key].collision.shape
	var mesh: ArrayMesh = terrain.active[key].visual.mesh
	var vertices: PackedVector3Array = mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
	var max_difference := 0.0
	for i in vertices.size():
		max_difference = maxf(max_difference,absf(vertices[i].y-shape.map_data[i]))
	check(max_difference<0.0001,"Deformed mesh and collision share exact vertex heights")
	var ray := PhysicsRayQueryParameters3D.create(probe+Vector3.UP*5,probe-Vector3.UP*5,1,[p.get_rid()])
	var hit: Dictionary = world.get_world_3d().direct_space_state.intersect_ray(ray)
	check(not hit.is_empty() and hit.position.y < probe.y-0.07,"Physics ray enters actual footprint depression")
	var interior_error := 0.0
	for i in 40:
		var q := probe+Vector3(sin(i*2.4)*0.73,0,cos(i*3.1)*0.83)
		var grid := Vector2(q.x-key.x*16,q.z-key.y*16)/0.25
		var ix := floori(grid.x)
		var iz := floori(grid.y)
		var u := grid.x-ix
		var v := grid.y-iz
		var a := vertices[iz*65+ix].y
		var b := vertices[iz*65+ix+1].y
		var c := vertices[(iz+1)*65+ix].y
		var d := vertices[(iz+1)*65+ix+1].y
		var expected := a+(b-a)*u+(c-a)*v if u+v<1 else d+(c-d)*(1-u)+(b-d)*(1-v)
		var query := PhysicsRayQueryParameters3D.create(q+Vector3.UP*8,q-Vector3.UP*8,1,[p.get_rid()])
		var contact: Dictionary = world.get_world_3d().direct_space_state.intersect_ray(query)
		if not contact.is_empty():
			interior_error = maxf(interior_error,absf(contact.position.y-expected))
	check(interior_error<0.015,"Collision matches triangle interiors as well as vertices")
	var before: float = Array(data.depth).min()
	terrain.clock += 35
	terrain._rebuild(key)
	check(Array(terrain.history[key].depth).min()>before,"Disturbed geometry settles gradually")
	terrain.follow(Vector3(500,0,-500))
	await frames(2)
	terrain.follow(probe)
	check(terrain.history.has(key) and Array(terrain.history[key].depth).min() < -0.05,"Footprints persist after leaving and revisiting")
	check(terrain.active.size()==9,"Only nine local collision patches remain active")
	var report := {"engine":Engine.get_version_info().string,"failures":failures,"footsteps":p.footsteps,"stamps":terrain.stamp_count,"slide_frames":p.slide_frames,"relief":terrain.maximum-terrain.minimum,"collision_max_error":max_difference,"collision_interior_error":interior_error}
	var file := FileAccess.open("res://validation/results.json",FileAccess.WRITE)
	file.store_string(JSON.stringify(report,"\t"))
	print("VALIDATION_COMPLETE failures=",failures.size())
	call_deferred("finish",0 if failures.is_empty() else 1)

func finish(code: int) -> void:
	world.queue_free()
	await process_frame
	await process_frame
	quit(code)
