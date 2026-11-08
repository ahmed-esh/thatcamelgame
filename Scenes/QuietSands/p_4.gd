
extends Sprite3D

@export_group("Planes Animation")
@export var rise_distance: float = 3.0
@export var rise_duration: float = 1.4
@export var starting_scale: float = 0.85

@export_group("Transition")
@export var pause_duration: float = 0.4
@export var fade_duration: float = 1.2

@onready var planes: Sprite3D = $planes
@onready var people_dying: Sprite3D = $peopledying

var _planes_position: Vector3
var _planes_scale: Vector3
var _animation_tween: Tween
var _is_playing: bool = false
var _finished: bool = false


func _ready() -> void:
	_planes_position = planes.position
	_planes_scale = planes.scale

	planes.modulate.a = 0.0
	people_dying.modulate.a = 0.0

	planes.visible = true
	people_dying.visible = true


func play_animation() -> void:
	if _is_playing or _finished:
		return

	_is_playing = true

	planes.position = _planes_position + Vector3.DOWN * rise_distance
	planes.scale = _planes_scale * starting_scale
	planes.modulate.a = 0.0

	_animation_tween = create_tween()

	_animation_tween.tween_property(
		planes,
		"position",
		_planes_position,
		rise_duration
	).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

	_animation_tween.parallel().tween_property(
		planes,
		"modulate:a",
		1.0,
		rise_duration * 0.7
	).set_trans(Tween.TRANS_SINE)

	_animation_tween.parallel().tween_property(
		planes,
		"scale",
		_planes_scale,
		rise_duration
	).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

	_animation_tween.tween_interval(pause_duration)

	_animation_tween.tween_property(
		self,
		"modulate:a",
		0.0,
		fade_duration
	).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)

	_animation_tween.parallel().tween_property(
		people_dying,
		"modulate:a",
		1.0,
		fade_duration
	).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)

	_animation_tween.tween_callback(_animation_finished)


func _animation_finished() -> void:
	_is_playing = false
	_finished = true
