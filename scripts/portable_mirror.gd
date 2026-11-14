extends StaticBody3D

@export var is_pickup: bool = true

func _ready():
	add_to_group("Mirror")
	add_to_group("Interactable")

func get_interaction_prompt() -> String:
	return "Pick up Portable Mirror"

func interact():
	GameManager.portable_mirrors_count += 1
	GameManager.mirror_count_changed.emit(GameManager.portable_mirrors_count)
	AudioManager.play_sfx("interact")
	queue_free()
