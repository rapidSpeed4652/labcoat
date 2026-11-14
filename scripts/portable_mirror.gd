extends StaticBody3D

@export var is_pickup: bool = true

func _ready():
	add_to_group("Mirror")
	add_to_group("Interactable")

func get_mirror_normal() -> Vector3:
	return global_transform.basis.z.normalized()

func get_category_badge() -> String:
	return "🔭 [PORTABLE: TRIPOD RETRO-REFLECTOR]"

func get_category_color() -> Color:
	return Color(0.2, 0.9, 1.0)

func get_hint() -> String:
	return "Portable optical mirror. Can be picked up and deployed at custom angles to bounce laser beams around corners."

func get_interaction_prompt() -> String:
	return "Pick up Portable Mirror"

func interact():
	GameManager.portable_mirrors_count += 1
	GameManager.mirror_count_changed.emit(GameManager.portable_mirrors_count)
	AudioManager.play_sfx("interact")
	queue_free()
