extends Node


@export var foot_markers: Array[NodePath] = []
@export var use_animation_events: bool = false
@export_range(0.2, 4.0, 0.05) var step_distance: float = 0.9
@export_range(0.1, 2.5, 0.05) var impact_strength: float = 0.65
@export_range(0.0, 3.0, 0.05) var minimum_speed: float = 0.4

@export var splash_scene: PackedScene

var _actor: CharacterBody3D
var _water: Node
var _accumulated_distance: float = 0.0
var _next_foot: int = 0
var _step_sound: AudioStreamPlayer3D
var _terrain: Node3D

func _ready() -> void:
	_actor = get_parent() as CharacterBody3D
	if _actor == null:
		push_error("WaterFootsteps must be a direct child of a CharacterBody3D")
	_water = get_tree().get_first_node_in_group("oasis_water")
	_terrain = get_node_or_null("../../SculptedDesert") as Node3D
	_step_sound = AudioStreamPlayer3D.new()
	_step_sound.stream = load("res://sounds/FOOTSTEPS.mp3")
	_step_sound.volume_db = 7 if _actor is Camel else 2
	_step_sound.max_distance = 50.0
	_step_sound.unit_size = 2.0
	_step_sound.max_polyphony = 3
	_actor.call_deferred("add_child", _step_sound)

func _physics_process(delta: float) -> void:
	if _actor == null or use_animation_events or foot_markers.is_empty():
		return
	if _actor is Person and not (_actor as Person).is_active:
		_accumulated_distance = 0.0
		_step_sound.stop()
		return
	if _actor is Camel and not ((_actor as Camel).is_active or (_actor as Camel)._following_player):
		_accumulated_distance = 0.0
		_step_sound.stop()
		return

	if not _on_sculpted_desert() and _step_sound.is_playing():
		_step_sound.stop()
	var horizontal_speed := Vector2(_actor.velocity.x, _actor.velocity.z).length()
	if horizontal_speed < minimum_speed:
		_accumulated_distance = 0.0
		_step_sound.stop()
		return

	_accumulated_distance += horizontal_speed * delta
	if _accumulated_distance < step_distance:
		return

	_accumulated_distance = fmod(_accumulated_distance, maxf(step_distance, 0.01))
	footstep(_next_foot)
	_next_foot = (_next_foot + 1) % foot_markers.size()

# For the best synchronization, set use_animation_events=true and call this
# from Call Method Tracks on actual animated foot-contact frames.
func footstep(foot_index: int) -> void:
	if _actor == null or foot_index < 0 or foot_index >= foot_markers.size():
		return

	var horizontal_speed := Vector2(_actor.velocity.x, _actor.velocity.z).length()
	if horizontal_speed < minimum_speed:
		return

	if not is_instance_valid(_water):
		_water = get_tree().get_first_node_in_group("oasis_water")
	var marker := get_node_or_null(foot_markers[foot_index]) as Node3D
	if marker == null:
		return

	var point := marker.global_position
	var is_sliding := (_actor is Camel and (_actor as Camel)._is_slide_active()) or (_actor is Person and (_actor as Person)._slide_active())
	if not is_sliding and _on_sculpted_desert():
		_step_sound.pitch_scale = randf_range(0.9, 1.1)
		_step_sound.play()
	if _water == null or not _water.has_method("add_ripple"):
		return
	var strength := clampf(impact_strength * (0.75 + horizontal_speed / 12.0), 0.1, 2.5)
	var created := bool(_water.call("add_ripple", point, strength))
	if created and splash_scene != null:
		_spawn_splash(point, strength)

func _spawn_splash(contact_point: Vector3, strength: float) -> void:
	var effect := splash_scene.instantiate() as GPUParticles3D
	if effect == null:
		push_warning("splash_scene root must be GPUParticles3D")
		return

	var scene_root := get_tree().current_scene
	if scene_root == null:
		effect.queue_free()
		return

	scene_root.add_child(effect)
	var water_y: float = float(_water.call("get_water_level"))
	effect.global_position = Vector3(contact_point.x, water_y + 0.015, contact_point.z)
	effect.scale = Vector3.ONE * clampf(0.65 + strength * 0.35, 0.7, 1.65)
	effect.one_shot = true
	effect.restart()
	get_tree().create_timer(effect.lifetime + 0.25).timeout.connect(effect.queue_free)

func _on_sculpted_desert() -> bool:
	if _terrain == null or not _actor.is_on_floor():
		return false
	var from := _actor.global_position + Vector3.UP * 0.7
	var to := _actor.global_position + Vector3.DOWN * 3.5
	var query := PhysicsRayQueryParameters3D.create(from, to)
	query.exclude = [_actor.get_rid()]
	query.collision_mask = 1
	var hit := _actor.get_world_3d().direct_space_state.intersect_ray(query)
	if hit.is_empty():
		return false
	var surface: Node = hit.collider as Node
	return surface != null and (surface == _terrain or _terrain.is_ancestor_of(surface))
