extends StaticBody3D

@export var is_open: bool = false
@export var open_offset: Vector3 = Vector3(0.0, 3.2, 0.0) # Slides upward or sideways
@export var slide_duration: float = 1.0

var closed_pos: Vector3

func _ready():
	closed_pos = position
	if is_open:
		position = closed_pos + open_offset

func open():
	if is_open:
		return
	is_open = true
	var tween = create_tween()
	tween.tween_property(self, "position", closed_pos + open_offset, slide_duration).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	AudioManager.play_sfx("door_open")

func close():
	if not is_open:
		return
	is_open = false
	var tween = create_tween()
	tween.tween_property(self, "position", closed_pos, slide_duration).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	AudioManager.play_sfx("door_open", 0.8)
