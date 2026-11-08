
extends CanvasLayer

@export_group("Text Animation")
@export var fade_in_duration: float = 0.8
@export var hold_duration: float = 1.8
@export var fade_out_duration: float = 0.8

@onready var few_days_later: Label = $FewDaysLater
@onready var ending_title: Label = $EndingTitle
@onready var animation_player: AnimationPlayer = $"../AnimationPlayer"

var _tween: Tween


func _ready() -> void:
	few_days_later.visible = true
	ending_title.visible = true
	few_days_later.modulate.a = 0.0
	ending_title.modulate.a = 0.0


func show_few_days_later() -> void:
	animation_player.pause()

	if _tween != null:
		_tween.kill()

	few_days_later.modulate.a = 0.0

	_tween = create_tween()

	_tween.tween_property(
		few_days_later,
		"modulate:a",
		1.0,
		fade_in_duration
	).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)

	_tween.tween_interval(hold_duration)

	_tween.tween_property(
		few_days_later,
		"modulate:a",
		0.0,
		fade_out_duration
	).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)

	_tween.tween_callback(animation_player.play)


func show_ending() -> void:
	animation_player.pause()

	if _tween != null:
		_tween.kill()

	ending_title.modulate.a = 0.0

	_tween = create_tween()

	_tween.tween_property(
		ending_title,
		"modulate:a",
		1.0,
		1.5
	).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
