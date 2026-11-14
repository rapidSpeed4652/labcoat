extends Control

@onready var btn_start: Button = $UI/VBoxContainer/BtnStart
@onready var btn_missions: Button = $UI/VBoxContainer/BtnMissions
@onready var btn_dossier: Button = $UI/VBoxContainer/BtnDossier
@onready var btn_controls: Button = $UI/VBoxContainer/BtnControls
@onready var btn_quit: Button = $UI/VBoxContainer/BtnQuit

@onready var dossier_modal: Control = $UI/DossierModal
@onready var controls_modal: Control = $UI/ControlsModal
@onready var missions_modal: Control = $UI/MissionsModal
@onready var camera_pivot: Node3D = $CameraPivot

var rot_speed: float = 0.04

func _ready():
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	dossier_modal.visible = false
	controls_modal.visible = false
	missions_modal.visible = false
	
	btn_start.pressed.connect(func(): _launch_mission(1))
	btn_missions.pressed.connect(_on_missions_pressed)
	btn_dossier.pressed.connect(_on_dossier_pressed)
	btn_controls.pressed.connect(_on_controls_pressed)
	btn_quit.pressed.connect(_on_quit_pressed)
	
	$UI/DossierModal/Center/Panel/VBox/BtnCloseDossier.pressed.connect(func(): dossier_modal.visible = false)
	$UI/ControlsModal/Center/Panel/VBox/BtnCloseControls.pressed.connect(func(): controls_modal.visible = false)
	$UI/MissionsModal/Center/Panel/VBox/BtnCloseMissions.pressed.connect(func(): missions_modal.visible = false)
	
	# Mission chapter selector buttons
	$UI/MissionsModal/Center/Panel/VBox/M1_Btn.pressed.connect(func(): _launch_mission(1))
	$UI/MissionsModal/Center/Panel/VBox/M2_Btn.pressed.connect(func(): _launch_mission(2))
	$UI/MissionsModal/Center/Panel/VBox/M3_Btn.pressed.connect(func(): _launch_mission(3))
	$UI/MissionsModal/Center/Panel/VBox/M4_Btn.pressed.connect(func(): _launch_mission(4))
	
	var am = get_node_or_null("/root/AudioManager")
	if am and am.has_method("play_ambient"):
		am.play_ambient()

func _process(delta: float):
	if camera_pivot:
		camera_pivot.rotation.y += rot_speed * delta

func _launch_mission(mission_num: int):
	var am = get_node_or_null("/root/AudioManager")
	if am:
		if am.has_method("play_sfx"):
			am.play_sfx("switch_flip")
		if am.has_method("play_radio_static"):
			am.play_radio_static()
			
	# Configure game manager starting act/objective if selecting later mission
	var gm = get_node_or_null("/root/GameManager")
	if gm:
		match mission_num:
			1: # Mission 1: Command Deck Breach
				gm.current_act = gm.Act.ACT_1_CONTROL_ROOM
				gm.has_laser = false
			2: # Mission 2: EVA Lunar Surface
				gm.current_act = gm.Act.ACT_1_CONTROL_ROOM
				gm.has_laser = true
				gm.act1_door_unlocked = true
			3: # Mission 3: Capacitor Research Bays
				gm.current_act = gm.Act.ACT_2_GALLERY
				gm.has_laser = true
				gm.act1_door_unlocked = true
			4: # Mission 4: Coudé Dome Finale
				gm.current_act = gm.Act.ACT_3_DOME
				gm.has_laser = true
				gm.act1_door_unlocked = true
				gm.capacitors_activated = 3
				gm.dome_door_unlocked = true
				
	get_tree().change_scene_to_file("res://scenes/main.tscn")

func _on_missions_pressed():
	var am = get_node_or_null("/root/AudioManager")
	if am and am.has_method("play_sfx"):
		am.play_sfx("interact")
	missions_modal.visible = true

func _on_dossier_pressed():
	var am = get_node_or_null("/root/AudioManager")
	if am and am.has_method("play_sfx"):
		am.play_sfx("interact")
	dossier_modal.visible = true

func _on_controls_pressed():
	var am = get_node_or_null("/root/AudioManager")
	if am and am.has_method("play_sfx"):
		am.play_sfx("interact")
	controls_modal.visible = true

func _on_quit_pressed():
	get_tree().quit()
