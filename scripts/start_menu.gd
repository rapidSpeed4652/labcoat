extends Control

@onready var btn_start: Button = $VBoxContainer/BtnStart
@onready var btn_dossier: Button = $VBoxContainer/BtnDossier
@onready var btn_controls: Button = $VBoxContainer/BtnControls
@onready var btn_quit: Button = $VBoxContainer/BtnQuit

@onready var dossier_modal: Control = $DossierModal
@onready var controls_modal: Control = $ControlsModal

func _ready():
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	dossier_modal.visible = false
	controls_modal.visible = false
	
	btn_start.pressed.connect(_on_start_pressed)
	btn_dossier.pressed.connect(_on_dossier_pressed)
	btn_controls.pressed.connect(_on_controls_pressed)
	btn_quit.pressed.connect(_on_quit_pressed)
	
	$DossierModal/Center/Panel/VBox/BtnCloseDossier.pressed.connect(func(): dossier_modal.visible = false)
	$ControlsModal/Center/Panel/VBox/BtnCloseControls.pressed.connect(func(): controls_modal.visible = false)
	
	var am = get_node_or_null("/root/AudioManager")
	if am and am.has_method("play_ambient"):
		am.play_ambient()

func _on_start_pressed():
	var am = get_node_or_null("/root/AudioManager")
	if am:
		if am.has_method("play_sfx"):
			am.play_sfx("switch_flip")
		if am.has_method("play_radio_static"):
			am.play_radio_static()
	get_tree().change_scene_to_file("res://scenes/main.tscn")

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
