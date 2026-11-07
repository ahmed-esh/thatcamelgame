extends Node3D

@export var debug_mode := true
@export var man_offset := Vector3(-2.5, 3.0, 0.0)
@export var women_offset := Vector3(2.5, 3.0, 0.0)
@export var mounted_height := 2.0

var _lines: Array[Label3D] = []
var _texts: Dictionary = {}
var _scales: Dictionary = {}
var _line_index := 0
var _graphic: Sprite3D
var _label: Label3D
var _tween: Tween
var _typing := false
var _transitioning := false
var _world_scale: Vector3

func _ready() -> void:
	_world_scale = global_basis.get_scale()
	for graphic: Sprite3D in [$man, $women]:
		_scales[graphic] = graphic.scale
		for conversation in graphic.get_children():
			for label: Label3D in conversation.get_children():
				_texts[label] = label.text
	_reset()

func oasis() -> void:
	_start("Oasis")

func p1() -> void:
	_start("P1")

func p2() -> void:
	_start("P2")

func p3() -> void:
	_start("P3")

func p4() -> void:
	_start("P4")

func p5() -> void:
	_start("P5")

func _reset() -> void:
	if _tween != null:
		_tween.kill()
	_typing = false
	_transitioning = false
	_label = null
	_graphic = null
	_lines.clear()
	for graphic: Sprite3D in [$man, $women]:
		graphic.hide()
		graphic.scale = _scales[graphic]
		for conversation in graphic.get_children():
			conversation.hide()
			for label: Label3D in conversation.get_children():
				label.hide()
				label.text = _texts[label]

func _start(conversation: String) -> void:
	_reset()
	for graphic: Sprite3D in [$man, $women]:
		for label: Label3D in graphic.get_node(conversation).get_children():
			_lines.append(label)
	_lines.sort_custom(func(a: Label3D, b: Label3D) -> bool:
		var a_round := int(str(a.name).get_slice("_", 0))
		var b_round := int(str(b.name).get_slice("_", 0))
		if a_round != b_round:
			return a_round < b_round
		if a.get_parent().get_parent() != b.get_parent().get_parent():
			return a.get_parent().get_parent() == $man
		return str(a.name).naturalnocasecmp_to(str(b.name)) < 0
	)
	_line_index = 0
	_show_line()

func _show_line() -> void:
	_label = _lines[_line_index]
	_graphic = _label.get_parent().get_parent()
	_label.get_parent().show()
	_label.text = ""
	_label.show()
	_graphic.scale = _scales[_graphic] * 0.05
	_graphic.show()
	_transitioning = true
	_tween = create_tween()
	_tween.tween_property(_graphic, "scale", _scales[_graphic], 0.2).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_tween.tween_callback(_begin_typing)

func _begin_typing() -> void:
	_transitioning = false
	_typing = true
	var text: String = _texts[_label]
	_tween = create_tween()
	_tween.tween_method(_reveal_text, 0, text.length(), text.length() / 35.0)
	_tween.tween_callback(func(): _typing = false)

func _reveal_text(count: int) -> void:
	_label.text = String(_texts[_label]).left(count)

func _advance() -> void:
	if _transitioning or _label == null:
		return
	if _typing:
		_tween.kill()
		_label.text = _texts[_label]
		_typing = false
		return
	_transitioning = true
	_tween = create_tween()
	_tween.tween_property(_graphic, "scale", _scales[_graphic] * 0.05, 0.15).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	_tween.tween_callback(_finish_line)

func _finish_line() -> void:
	_label.hide()
	_label.text = _texts[_label]
	_label.get_parent().hide()
	_graphic.hide()
	_graphic.scale = _scales[_graphic]
	_line_index += 1
	if _line_index == _lines.size():
		_reset()
	else:
		_show_line()

func _input(event: InputEvent) -> void:
	if not event is InputEventKey or not event.pressed or event.echo:
		return
	if debug_mode and event.keycode >= KEY_1 and event.keycode <= KEY_6:
		get_viewport().set_input_as_handled()
		call(["oasis", "p1", "p2", "p3", "p4", "p5"][event.keycode - KEY_1])
	elif _label != null and event.keycode in [KEY_SPACE, KEY_ENTER, KEY_KP_ENTER]:
		get_viewport().set_input_as_handled()
		_advance()

func _process(_delta: float) -> void:
	var mounted := Global.camel != null and (Global.camel.is_active or Global.camel.is_transitioning)
	var target: Node3D = Global.camel if mounted else Global.player
	var camera := get_viewport().get_camera_3d()
	if target == null or camera == null:
		return
	global_position = target.global_position
	global_basis = camera.global_basis.orthonormalized().scaled(_world_scale)
	for graphic: Sprite3D in [$man, $women]:
		var offset := man_offset if graphic == $man else women_offset
		if mounted:
			offset.y += mounted_height
		graphic.global_position = target.global_position + camera.global_basis.orthonormalized() * offset
