extends Node3D

@export var main_menu: Node3D
@export var camera_start_location: Node3D

var is_game_started : bool

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	Global.main_camera.set_camera_parent(camera_start_location)
	is_game_started = false

func _unhandled_input(event: InputEvent) -> void:
	if (event is InputEventKey and event.pressed and !is_game_started):
		is_game_started = true
		on_game_start()

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass

func on_game_start() -> void:
	await Global.main_camera.lerp_to_new(Global.player_camera_node)
	Global.player.is_active = true
	pass
