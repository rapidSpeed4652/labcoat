extends StaticBody3D

@export var station_name: String = "Station Alpha"
@export var target_angle_deg: float = 45.0
@export var current_angle_deg: float = 0.0

var is_aligned: bool = false
signal alignment_changed(station: Node, is_correct: bool)

func _ready():
	add_to_group("Mirror")
	add_to_group("Interactable")
	add_to_group("DomeReflector")
	rotation_degrees.y = current_angle_deg
	_check_alignment()

func get_mirror_normal() -> Vector3:
	return global_transform.basis.z.normalized()

func get_category_badge() -> String:
	return "📡 [ASTRONOMY: " + station_name.to_upper() + "]"

func get_category_color() -> Color:
	return Color(0.1, 1.0, 0.4) if is_aligned else Color(0.2, 0.85, 1.0)

func get_hint() -> String:
	if is_aligned:
		return "ALIGNED: Beam locked into triangle trajectory across dome."
	return "Rotate 45° to reflect beam toward the next dome station."

func get_interaction_prompt() -> String:
	var status = " [ALIGNED ✓]" if is_aligned else ""
	return "Rotate " + station_name + " (" + str(int(current_angle_deg)) + "°)" + status

func interact():
	current_angle_deg = fmod(current_angle_deg + 45.0, 360.0)
	
	var tween = create_tween()
	tween.tween_property(self, "rotation_degrees:y", current_angle_deg, 0.25).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	
	AudioManager.play_sfx("switch_flip", 0.7)
	AudioManager.play_sfx("footstep", 0.6)
	
	_check_alignment()

func _check_alignment():
	var diff = abs(fmod(current_angle_deg - target_angle_deg + 360.0, 360.0))
	var now_aligned = (diff < 5.0 or diff > 355.0)
	if now_aligned != is_aligned:
		is_aligned = now_aligned
		alignment_changed.emit(self, is_aligned)
		if is_aligned:
			AudioManager.play_sfx("mirror_reflect", 1.4)
