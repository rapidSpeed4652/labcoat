extends StaticBody3D

@export var is_rotatable: bool = false
@export var rotation_step_deg: float = 45.0
@export var prompt_message: String = "Rotate Mirror"

var current_angle_deg: float = 0.0

func _ready():
	add_to_group("Mirror")
	if is_rotatable:
		add_to_group("Interactable")

func get_mirror_normal() -> Vector3:
	return global_transform.basis.z.normalized()

func get_category_badge() -> String:
	return "🪞 [OPTICS: RETRO-REFLECTOR MIRROR]"

func get_category_color() -> Color:
	return Color(0.3, 0.9, 1.0)

func get_hint() -> String:
	return "Inverts and reflects laser beams. Reflected beams vaporize shadow entities and unlock optical door sensors."

func get_interaction_prompt() -> String:
	if is_rotatable:
		return prompt_message + " [" + str(int(current_angle_deg)) + "°]"
	return "Wall Calibration Mirror"

func interact():
	if not is_rotatable:
		return
	current_angle_deg = fmod(current_angle_deg + rotation_step_deg, 360.0)
	rotate_y(deg_to_rad(rotation_step_deg))
	AudioManager.play_sfx("switch_flip", 0.9)
