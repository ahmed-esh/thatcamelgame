extends Area3D


# Called when the node enters the scene tree for the first time
func _on_body_entered(body: Node3D) -> void:
	if (Global.is_camel): return
	if (!Global.game_started): return
	if (body is not Person): return
	Global.can_get_water = true
	


func _on_body_exited(body: Node3D) -> void:
	if (Global.is_camel): return
	if (!Global.game_started): return
	if (body is not Person): return
	Global.can_get_water = false
