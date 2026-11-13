extends Area3D

var prompt_label: Label3D
var _consumed := false
var _inside := false
var _prompt_tween: Tween
var _interaction_audio: AudioStreamPlayer3D

func _ready() -> void:
	add_to_group("oasis_water_interaction")
	_interaction_audio = AudioStreamPlayer3D.new()
	_interaction_audio.stream = load("res://sounds/interaction2.mp3")
	_interaction_audio.volume_db = -2.0
	add_child(_interaction_audio)

func set_prompt(label: Label3D) -> void:
	prompt_label = label

func _physics_process(_delta: float) -> void:
	var eligible := Global.player != null and Global.game_started and not Global.is_camel and not Global.got_water and not _consumed and overlaps_body(Global.player)
	if eligible and get_parent().has_method("is_water_contact"):
		eligible = get_parent().is_water_contact(Global.player.global_position)
	if eligible == _inside:
		return
	_inside = eligible
	Global.can_get_water = eligible

func _on_body_entered(_body: Node3D) -> void:
	pass

func _on_body_exited(_body: Node3D) -> void:
	pass

func show_prompt(message: String) -> void:
	if prompt_label == null:
		return
	if _prompt_tween != null:
		_prompt_tween.kill()
	prompt_label.text = message
	prompt_label.scale = Vector3.ONE * 0.82
	prompt_label.modulate.a = 0.0
	prompt_label.show()
	_prompt_tween = create_tween().set_parallel(true)
	_prompt_tween.tween_property(prompt_label, "modulate:a", 1.0, 0.25)
	_prompt_tween.tween_property(prompt_label, "scale", Vector3.ONE, 0.32).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

func hide_prompt(animated: bool) -> void:
	if prompt_label == null:
		return
	if _prompt_tween != null:
		_prompt_tween.kill()
	if not animated:
		prompt_label.hide()
		return
	_prompt_tween = create_tween().set_parallel(true)
	_prompt_tween.tween_property(prompt_label, "modulate:a", 0.0, 0.28)
	_prompt_tween.tween_property(prompt_label, "scale", Vector3.ONE * 1.22, 0.28).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	_prompt_tween.chain().tween_callback(prompt_label.hide)

func consume() -> void:
	if _consumed:
		return
	_consumed = true
	_inside = false
	Global.can_get_water = false
	hide_prompt(true)
	_interaction_audio.play()
