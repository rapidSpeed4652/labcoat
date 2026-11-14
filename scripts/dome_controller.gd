extends Node3D

@export var station_alpha: Node3D
@export var station_beta: Node3D
@export var station_gamma: Node3D
@export var roof_shutter: Node3D
@export var central_beam: MeshInstance3D
@export var triangle_beam_mesh: MeshInstance3D
@export var emergency_lights_root: Node3D

var puzzle_complete: bool = false
var shutdown_triggered: bool = false

func _ready():
	if station_alpha and station_alpha.has_signal("alignment_changed"):
		station_alpha.alignment_changed.connect(_on_station_alignment)
	if station_beta and station_beta.has_signal("alignment_changed"):
		station_beta.alignment_changed.connect(_on_station_alignment)
	if station_gamma and station_gamma.has_signal("alignment_changed"):
		station_gamma.alignment_changed.connect(_on_station_alignment)
	
	if triangle_beam_mesh:
		triangle_beam_mesh.visible = false
	if emergency_lights_root:
		emergency_lights_root.visible = false

func _process(_delta: float):
	if GameManager.shutdown_lever_pulled and not shutdown_triggered:
		shutdown_triggered = true
		_perform_shutdown()

func _on_station_alignment(_station: Node, _is_correct: bool):
	if puzzle_complete:
		return
	
	var a_ok = station_alpha and station_alpha.is_aligned
	var b_ok = station_beta and station_beta.is_aligned
	var c_ok = station_gamma and station_gamma.is_aligned
	
	if a_ok and b_ok and c_ok:
		_trigger_dome_solve()

func _trigger_dome_solve():
	puzzle_complete = true
	if triangle_beam_mesh:
		triangle_beam_mesh.visible = true
	
	# Banish all remaining shadow entities in dome
	var entities = get_tree().get_nodes_in_group("ShadowEntity")
	for e in entities:
		if e.has_method("banish"):
			e.banish()
	
	AudioManager.play_sfx("entity_banish", 1.0, 6.0)
	AudioManager.play_sfx("mirror_reflect", 1.5, 4.0)
	GameManager.solve_dome_puzzle()

func _perform_shutdown():
	AudioManager.play_sfx("mirror_reflect", 0.6, 6.0)
	var beam_light = get_node_or_null("BeamLight")
	
	# 100-Petawatt Inverted Hyper-Pulse Surge
	if central_beam:
		var tween = create_tween()
		tween.tween_property(central_beam, "scale", Vector3(3.2, 1.0, 3.2), 0.35).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
		if beam_light:
			beam_light.light_color = Color(0.85, 0.95, 1.0)
			tween.parallel().tween_property(beam_light, "light_energy", 24.0, 0.35)
		tween.tween_interval(0.25)
		tween.tween_callback(func():
			if central_beam:
				central_beam.visible = false
			if triangle_beam_mesh:
				triangle_beam_mesh.visible = false
			if beam_light:
				beam_light.visible = false
		)
	else:
		if triangle_beam_mesh:
			triangle_beam_mesh.visible = false
		if beam_light:
			beam_light.visible = false
	
	# Shutter close animation
	if roof_shutter:
		var tween = create_tween()
		tween.tween_property(roof_shutter, "position:y", roof_shutter.position.y - 4.0, 3.0).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	
	# Emergency amber lights flicker on
	if emergency_lights_root:
		emergency_lights_root.visible = true
		for child in emergency_lights_root.get_children():
			if child is OmniLight3D or child is SpotLight3D:
				var t = create_tween()
				t.tween_property(child, "light_energy", child.light_energy, 0.5)
