extends CanvasLayer

signal cutscene_finished()

@onready var cam: Camera3D = $CutsceneCamera
@onready var letterbox_top: ColorRect = $LetterboxTop
@onready var letterbox_bottom: ColorRect = $LetterboxBottom
@onready var radio_subtitle: Label = $SubtitleBox/MessageLabel
@onready var speaker_label: Label = $SubtitleBox/SpeakerLabel
@onready var subtitle_box: Control = $SubtitleBox

var is_playing: bool = false
var rover_instance: Node3D = null

func _ready():
	visible = false
	process_mode = Node.PROCESS_MODE_ALWAYS

func _input(event: InputEvent):
	if is_playing and (event.is_action_pressed("interact") or event.is_action_pressed("pause") or (event is InputEventKey and event.pressed and (event.keycode == KEY_SPACE or event.keycode == KEY_ESCAPE or event.keycode == KEY_ENTER))):
		finish_cutscene()

func play_ending_sequence():
	if is_playing:
		return
	is_playing = true
	visible = true
	
	var player = get_tree().get_first_node_in_group("Player")
	if player:
		player.set_physics_process(false)
		player.set_process_input(false)
		
	cam.current = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	
	letterbox_top.position.y = -120.0
	letterbox_bottom.position.y = 800.0
	var lt = create_tween().set_parallel(true)
	lt.tween_property(letterbox_top, "position:y", 0.0, 0.8).set_trans(Tween.TRANS_QUAD)
	lt.tween_property(letterbox_bottom, "position:y", 540.0, 0.8).set_trans(Tween.TRANS_QUAD)
	
	cam.global_position = Vector3(24.0, 1.2, -26.0)
	cam.look_at(Vector3(24.0, 9.0, -32.0), Vector3.UP)
	
	AudioManager.play_sfx("quindar_intro")
	AudioManager.play_sfx("shutter_close", 0.8)
	
	speaker_label.text = "FLIGHT DIRECTOR VANCE (HOUSTON)"
	radio_subtitle.text = "Mount Hale, this is Houston Flight. Leo, copy? Primary Coude return loop has collapsed. Resonance readings flatline."
	
	var shot1_tween = create_tween()
	shot1_tween.tween_property(cam, "global_position", Vector3(24.0, 3.2, -24.0), 5.0).set_trans(Tween.TRANS_SINE)
	await shot1_tween.finished
	
	if not is_playing:
		return
		
	var ext = get_tree().root.find_child("LunarExterior", true, false)
	if ext:
		var rover_scene = load("res://scenes/props/prop_lunar_rover.tscn")
		if rover_scene:
			rover_instance = rover_scene.instantiate()
			ext.add_child(rover_instance)
			rover_instance.global_position = Vector3(0.0, 0.0, 12.0)
			rover_instance.rotation_degrees.y = 15.0
			
	cam.global_position = Vector3(-6.0, 4.5, 24.0)
	cam.look_at(Vector3(0.0, 1.5, 12.0), Vector3.UP)
	
	radio_subtitle.text = "All roof shutters confirmed sealed. We've locked onto your rover transponder on the Mare Tranquillitatis beacon. Outstanding work, Leo... You're heading home."
	AudioManager.play_voice("radio_ending")
	
	var shot2_tween = create_tween().set_parallel(true)
	shot2_tween.tween_property(cam, "global_position", Vector3(-12.0, 6.0, 32.0), 7.0).set_trans(Tween.TRANS_SINE)
	if rover_instance:
		shot2_tween.tween_property(rover_instance, "global_position", Vector3(4.0, 0.0, -18.0), 7.0).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	await shot2_tween.finished
	
	finish_cutscene()

func finish_cutscene():
	if not is_playing:
		return
	is_playing = false
	visible = false
	AudioManager.play_sfx("quindar_outro")
	cutscene_finished.emit()
	var ui = get_tree().get_first_node_in_group("UI")
	if ui and ui.win_screen:
		ui.win_screen.visible = true
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
