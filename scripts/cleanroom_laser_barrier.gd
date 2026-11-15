extends StaticBody3D

@onready var col_shape: CollisionShape3D = $CollisionShape3D
@onready var warning_light: OmniLight3D = $WarningLight
@onready var grid_label: Label3D = $GridLabel
@onready var beams_root: Node3D = $Beams
@onready var left_pylon_light: OmniLight3D = get_node_or_null("LeftPylon/PylonLight")
@onready var right_pylon_light: OmniLight3D = get_node_or_null("RightPylon/PylonLight")

var is_deactivated: bool = false

func _ready():
	add_to_group("CleanroomBarrier")

func deactivate():
	if is_deactivated:
		return
	is_deactivated = true
	
	if col_shape:
		col_shape.set_deferred("disabled", true)
		
	AudioManager.play_sfx("switch_flip", 0.6, 2.0)
	AudioManager.play_sfx("laser_cooldown", 0.9, 1.0)
	
	var tween = create_tween().set_parallel(true)
	if warning_light:
		tween.tween_property(warning_light, "light_color", Color(0.2, 1.0, 0.4), 0.3)
		tween.tween_property(warning_light, "light_energy", 0.5, 0.8)
	if left_pylon_light:
		tween.tween_property(left_pylon_light, "light_color", Color(0.2, 1.0, 0.4), 0.3)
	if right_pylon_light:
		tween.tween_property(right_pylon_light, "light_color", Color(0.2, 1.0, 0.4), 0.3)
	if grid_label:
		grid_label.text = "[ARGON-ION LASER BARRIER: DEACTIVATED]"
		grid_label.modulate = Color(0.2, 1.0, 0.4)
		
	if beams_root:
		for beam in beams_root.get_children():
			if beam is MeshInstance3D:
				var bt = create_tween()
				bt.tween_property(beam, "scale:x", 0.0, 0.35).set_trans(Tween.TRANS_QUAD)
				bt.tween_property(beam, "scale:z", 0.0, 0.35).set_trans(Tween.TRANS_QUAD)
				bt.tween_callback(func(): beam.visible = false)
