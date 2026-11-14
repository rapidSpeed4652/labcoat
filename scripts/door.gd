extends StaticBody3D

@export var is_open: bool = false
@export var open_offset: Vector3 = Vector3(0.0, 3.2, 0.0)
@export var slide_duration: float = 1.0
@export var door_name: String = "Security Door"
@export var lock_text: String = "[LOCKED - SENSOR OVERRIDE REQUIRED]"
@export var lock_hint: String = "Aim laser at the wall mirror so the reflection strikes the Optical Receptor."
@export var requires_keypad: bool = false
@export var keypad_code: String = ""
@export var keypad_id: String = ""
@export var keypad_title: String = "DOORWAY SECURITY ACCESS"

var closed_pos: Vector3

@onready var lock_sign: OmniLight3D = $LockSignLight
@onready var status_mesh: MeshInstance3D = $StatusMesh
@onready var status_label: Label3D = get_node_or_null("StatusLabel")

func _ready():
	add_to_group("Interactable")
	closed_pos = position
	if is_open:
		position = closed_pos + open_offset
		_update_visuals(true)
	else:
		_update_visuals(false)
		
	if requires_keypad and GameManager.has_signal("keypad_unlocked"):
		GameManager.keypad_unlocked.connect(func(target_id):
			if target_id == keypad_id:
				open()
		)

func get_category_badge() -> String:
	return "🚪 [ACCESS DOOR: " + ("UNLOCKED" if is_open else "LOCKED") + "]"

func get_category_color() -> Color:
	return Color(0.2, 1.0, 0.4) if is_open else Color(1.0, 0.3, 0.2)

func get_interaction_prompt() -> String:
	if is_open:
		return "[ACCESS GRANTED - DOORWAY CLEAR]"
	if requires_keypad:
		return "[E] Enter Authorization Code (Check Polaroid/Lore Clues)"
	return lock_text

func get_hint() -> String:
	if is_open:
		return "Door is open."
	if requires_keypad:
		return "Keypad locked. Clue is recorded in Dr. Thorne's Polaroid or Audio Tapes."
	return lock_hint

func interact():
	if is_open:
		return
	if requires_keypad:
		GameManager.request_keypad(keypad_id, keypad_code, keypad_title)
	else:
		AudioManager.play_sfx("laser_click", 0.5)

func open():
	if is_open:
		return
	is_open = true
	_update_visuals(true)
	var tween = create_tween()
	tween.tween_property(self, "position", closed_pos + open_offset, slide_duration).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	AudioManager.play_sfx("door_open")

func close():
	if not is_open:
		return
	is_open = false
	_update_visuals(false)
	var tween = create_tween()
	tween.tween_property(self, "position", closed_pos, slide_duration).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	AudioManager.play_sfx("door_open", 0.8)

func _update_visuals(open_state: bool):
	if lock_sign:
		lock_sign.light_color = Color(0.1, 1.0, 0.3) if open_state else Color(1.0, 0.15, 0.1)
		lock_sign.light_energy = 2.5
	if status_mesh:
		var mat = StandardMaterial3D.new()
		mat.albedo_color = Color(0.1, 1.0, 0.3) if open_state else Color(1.0, 0.15, 0.1)
		mat.emission_enabled = true
		mat.emission = Color(0.1, 1.0, 0.3) if open_state else Color(1.0, 0.15, 0.1)
		mat.emission_energy_multiplier = 3.0
		status_mesh.material_override = mat
	if status_label:
		if open_state:
			status_label.text = "[ACCESS GRANTED - LOCK DISENGAGED]"
			status_label.modulate = Color(0.2, 1.0, 0.4)
		else:
			status_label.text = lock_text
			status_label.modulate = Color(1.0, 0.25, 0.2)
