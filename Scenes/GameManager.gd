extends Node3D


# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	Global.main_camera.set_camera_parent(Global.player_camera_node)
	pass
	


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass
