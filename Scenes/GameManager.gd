extends Node3D

@export var camera_start_location: Node3D

@export_group("Dialogue")
@export var dialogue_resource: DialogueResource
@export var dialogue_start: String = "start"
@export var dialogue_label: Label3D
@export var characters_per_second: float = 40.0
@export var title_fade_duration: float = 0.8

var is_game_started : bool
var _dialogue_running := false
var _is_typing := false
var _skip_typing := false
var _advance_pressed := false

@export var MainText: Label3D
@export var SubText: Label3D
@export var lights : Node3D


func _ready() -> void:
	Global.main_camera.set_camera_parent(camera_start_location)
	is_game_started = false
	if dialogue_label:
		dialogue_label.text = ""
		dialogue_label.visible = false


func _unhandled_input(event: InputEvent) -> void:
	# 1. Any key starts the sequence.
	if (event is InputEventKey and event.pressed and !is_game_started):
		is_game_started = true
		start_dialogue()
		return

	# 2. Any key or mouse click advances / skips typing while dialogue is running.
	if _dialogue_running and _is_advance_event(event):
		if _is_typing:
			_skip_typing = true
		else:
			_advance_pressed = true
		get_viewport().set_input_as_handled()


func _is_advance_event(event: InputEvent) -> bool:
	# Escape is left alone so it can still free the mouse.
	if event.is_action_pressed("ui_cancel"):
		return false
	if event is InputEventKey:
		return event.pressed and not event.echo
	if event is InputEventMouseButton:
		return event.pressed
	return false


func start_dialogue() -> void:
	if _dialogue_running:
		return
	if dialogue_resource == null or dialogue_label == null:
		push_warning("Dialogue resource or Label3D is not assigned.")
		return

	# 3. Fade out the two title labels before the dialogue appears.
	await _fade_out_title_labels()

	_dialogue_running = true
	dialogue_label.text = ""
	dialogue_label.visible = true

	# 4. Run through every dialogue line.
	var line: DialogueLine = await DialogueManager.get_next_dialogue_line(dialogue_resource, dialogue_start)
	while line != null:
		await _show_line(line)

		# Choices are not displayed yet; this just takes the first one.
		var next_id: String = line.next_id
		if line.responses.size() > 0:
			next_id = line.responses[0].next_id

		line = await DialogueManager.get_next_dialogue_line(dialogue_resource, next_id)

	# 5. No more dialogue left.
	dialogue_label.text = ""
	dialogue_label.visible = false
	_dialogue_running = false

	await on_dialogue_end()


func _fade_out_title_labels() -> void:
	var tween := create_tween().set_parallel(true)
	tween.tween_property(MainText, "modulate:a", 0.0, title_fade_duration)
	tween.tween_property(SubText, "modulate:a", 0.0, title_fade_duration)
	await tween.finished
	MainText.visible = false
	SubText.visible = false


func _show_line(line: DialogueLine) -> void:
	var new_text := _strip_bbcode(line.text)
	if line.character != "":
		new_text = "%s: %s" % [line.character, new_text]

	_is_typing = true
	_skip_typing = false
	_advance_pressed = false

	# Keep what's already on screen and add the new line underneath.
	var existing := dialogue_label.text
	var prefix := existing + "\n" if existing != "" else ""

	# Label3D has no visible_characters, so reveal the new line manually.
	dialogue_label.text = prefix

	var delay := 1.0 / maxf(characters_per_second, 1.0)
	for i in range(1, new_text.length() + 1):
		if _skip_typing:
			break
		dialogue_label.text = prefix + new_text.substr(0, i)
		await get_tree().create_timer(delay).timeout

	dialogue_label.text = prefix + new_text
	_is_typing = false
	_advance_pressed = false

	# Wait for the player to press advance.
	while not _advance_pressed:
		await get_tree().process_frame
	_advance_pressed = false


func _strip_bbcode(text: String) -> String:
	var regex := RegEx.new()
	regex.compile("\\[/?[^\\]]+\\]")
	return regex.sub(text, "", true)


func on_dialogue_end() -> void:
	lights.visible = false
	await Global.main_camera.lerp_to_new(Global.player_camera_node)
	Global.in_cutscene = false
	Global.player.is_active = true
	Global.is_camel = false
	Global.game_started = true
