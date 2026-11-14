extends StaticBody3D

@export var requires_reflected_beam: bool = true
@export var target_door: NodePath
@export var activation_time_required: float = 0.3 # must hold beam briefly
@export var is_permanent: bool = true

var current_charge: float = 0.0
var is_activated: bool = false

@onready var indicator_light: OmniLight3D = $IndicatorLight
@onready var indicator_mesh: MeshInstance3D = $IndicatorMesh

signal activated()

func _ready():
	add_to_group("OpticalReceptor")
	_update_visuals()

func _process(delta: float):
	if is_activated and is_permanent:
		return
	
	# Slowly lose charge if not continuously hit
	if current_charge > 0.0:
		current_charge = max(0.0, current_charge - delta * 0.5)
		_update_visuals()

func on_laser_hit(is_reflected: bool, delta: float):
	if is_activated and is_permanent:
		return
	
	if requires_reflected_beam and not is_reflected:
		# Direct raw beam rejected!
		return
	
	current_charge += delta
	_update_visuals()
	
	if current_charge >= activation_time_required and not is_activated:
		trigger_activation()

func trigger_activation():
	is_activated = true
	current_charge = activation_time_required
	_update_visuals()
	activated.emit()
	AudioManager.play_sfx("switch_flip", 1.2)
	AudioManager.play_sfx("door_open")
	
	if target_door:
		var door_node = get_node_or_null(target_door)
		if door_node and door_node.has_method("open"):
			door_node.open()
	
	GameManager.unlock_act1_door()

func _update_visuals():
	if not indicator_light or not indicator_mesh:
		return
	
	var mat = indicator_mesh.get_surface_override_material(0)
	if not mat:
		mat = StandardMaterial3D.new()
		indicator_mesh.set_surface_override_material(0, mat)
	
	if is_activated:
		indicator_light.light_color = Color(0.1, 1.0, 0.3)
		indicator_light.light_energy = 2.5
		mat.albedo_color = Color(0.1, 1.0, 0.3)
		mat.emission_enabled = true
		mat.emission = Color(0.1, 1.0, 0.3)
		mat.emission_energy_multiplier = 3.0
	elif current_charge > 0.0:
		indicator_light.light_color = Color(1.0, 0.8, 0.1)
		indicator_light.light_energy = 1.0
		mat.albedo_color = Color(1.0, 0.8, 0.1)
		mat.emission_enabled = true
		mat.emission = Color(1.0, 0.8, 0.1)
	else:
		indicator_light.light_color = Color(1.0, 0.1, 0.1)
		indicator_light.light_energy = 0.8
		mat.albedo_color = Color(1.0, 0.1, 0.1)
		mat.emission_enabled = true
		mat.emission = Color(1.0, 0.1, 0.1)
		mat.emission_energy_multiplier = 1.0
