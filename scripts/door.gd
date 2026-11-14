extends StaticBody3D

@export var is_open: bool = false
@export var open_offset: Vector3 = Vector3(0.0, 3.2, 0.0)
@export var slide_duration: float = 1.0

var closed_pos: Vector3

@onready var lock_sign: OmniLight3D = $LockSignLight
@onready var status_mesh: MeshInstance3D = $StatusMesh

func _ready():
	closed_pos = position
	if is_open:
		position = closed_pos + open_offset
		_update_visuals(true)
	else:
		_update_visuals(false)

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
