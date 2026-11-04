extends Label3D

## How long one full fade cycle takes, in seconds.
@export var duration: float = 1.0
## Alpha multiplier over time. X = time (0-1 across the duration), Y = opacity (0 = transparent, 1 = original).
@export var fade_curve: Curve

var _time: float = 0.0
var _base_modulate: Color
var _base_outline: Color


func _ready() -> void:
	_base_modulate = modulate
	_base_outline = outline_modulate

	# Default curve: fully visible -> fully transparent, then loops back
	if fade_curve == null:
		fade_curve = Curve.new()
		fade_curve.add_point(Vector2(0.0, 1.0))
		fade_curve.add_point(Vector2(1.0, 0.0))


func _process(delta: float) -> void:
	_time = fmod(_time + delta, duration)
	var t := _time / duration
	var alpha := clampf(fade_curve.sample(t), 0.0, 1.0)

	modulate = Color(_base_modulate, _base_modulate.a * alpha)
	outline_modulate = Color(_base_outline, _base_outline.a * alpha)
