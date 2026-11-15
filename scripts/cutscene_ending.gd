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
var rocket_instance: Node3D = null
var ext_instance: Node3D = null
var dynamic_bursts: Array[Node3D] = []
var active_tweens: Array[Tween] = []

func _ready():
	visible = false
	process_mode = Node.PROCESS_MODE_ALWAYS

func _input(event: InputEvent):
	if is_playing and (event.is_action_pressed("interact") or event.is_action_pressed("pause") or (event is InputEventKey and event.pressed and (event.keycode == KEY_SPACE or event.keycode == KEY_ESCAPE or event.keycode == KEY_ENTER))):
		finish_cutscene()

func _clean_tweens():
	for t in active_tweens:
		if t and t.is_valid():
			t.kill()
	active_tweens.clear()

func play_ending_sequence():
	if is_playing:
		return
	is_playing = true
	visible = true
	_clean_tweens()
	
	var player = get_tree().get_first_node_in_group("Player")
	if player:
		player.set_physics_process(false)
		player.set_process_input(false)
		
	cam.current = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	
	letterbox_top.position.y = -120.0
	letterbox_bottom.position.y = 800.0
	var lt = create_tween().set_parallel(true)
	active_tweens.append(lt)
	lt.tween_property(letterbox_top, "position:y", 0.0, 0.8).set_trans(Tween.TRANS_QUAD)
	lt.tween_property(letterbox_bottom, "position:y", 540.0, 0.8).set_trans(Tween.TRANS_QUAD)
	
	cam.global_position = Vector3(24.0, 1.2, -26.0)
	cam.look_at(Vector3(24.0, 9.0, -32.0), Vector3.UP)
	
	AudioManager.play_sfx("quindar_intro")
	AudioManager.play_sfx("shutter_close", 0.8)
	
	speaker_label.text = "FLIGHT DIRECTOR VANCE (HOUSTON)"
	radio_subtitle.text = "Mount Hale, this is Houston Flight! Resonance cascade in progress! Core shutters sealing!"
	
	var shot1_tween = create_tween()
	active_tweens.append(shot1_tween)
	shot1_tween.tween_property(cam, "global_position", Vector3(24.0, 3.2, -24.0), 4.2).set_trans(Tween.TRANS_SINE)
	await shot1_tween.finished
	
	if not is_playing:
		return
		
	var ext = get_tree().root.find_child("LunarExterior", true, false)
	if not ext:
		var ext_scene = load("res://scenes/lunar_exterior.tscn")
		if ext_scene:
			ext = ext_scene.instantiate()
			get_tree().current_scene.add_child(ext)
			ext_instance = ext
			
	if ext and not rover_instance:
		var rover_scene = load("res://scenes/props/prop_lunar_rover.tscn")
		if rover_scene:
			rover_instance = rover_scene.instantiate()
			ext.add_child(rover_instance)
			rover_instance.global_position = Vector3(12.0, 0.0, 24.0)
			rover_instance.rotation_degrees.y = 205.0
			
	cam.global_position = Vector3(20.0, 3.8, 38.0)
	cam.look_at(Vector3(12.0, 1.2, 24.0), Vector3.UP)
	
	radio_subtitle.text = "Capacitor bay secondary overload! Dome structural breach! Gun it, Leo, reach the ascent module!"
	
	var shot2_tween = create_tween().set_parallel(true)
	active_tweens.append(shot2_tween)
	shot2_tween.tween_property(cam, "global_position", Vector3(6.0, 5.0, 12.0), 5.5).set_trans(Tween.TRANS_SINE)
	if rover_instance:
		shot2_tween.tween_property(rover_instance, "global_position", Vector3(-18.0, 0.0, -22.0), 5.5).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		
	get_tree().create_timer(0.6).timeout.connect(func():
		if is_playing and ext:
			_spawn_explosion(ext, Vector3(28.0, 4.0, -8.0), 1.1)
	)
	get_tree().create_timer(2.2).timeout.connect(func():
		if is_playing and ext:
			_spawn_explosion(ext, Vector3(42.0, 3.0, -26.0), 0.9)
	)
	await shot2_tween.finished
	
	if not is_playing:
		return
		
	if ext and not rocket_instance:
		var rocket_scene = load("res://scenes/props/prop_lunar_rocket.tscn")
		if rocket_scene:
			rocket_instance = rocket_scene.instantiate()
			ext.add_child(rocket_instance)
			rocket_instance.global_position = Vector3(-35.0, 0.0, -45.0)
			
	if rover_instance:
		rover_instance.global_position = Vector3(-28.0, 0.0, -42.0)
		rover_instance.rotation_degrees.y = 120.0
		
	cam.global_position = Vector3(-44.0, 2.2, -34.0)
	cam.look_at(Vector3(-35.0, 4.2, -45.0), Vector3.UP)
	
	radio_subtitle.text = "Boarding hatch sealed! Terminal countdown initiated... 3... 2... 1... Main engine ignition!"
	
	if rocket_instance:
		var flame = rocket_instance.get_node_or_null("%FlamePlume")
		var light = rocket_instance.get_node_or_null("%PlumeLight")
		var thrust = rocket_instance.get_node_or_null("%ThrustParticles")
		if flame:
			flame.visible = true
		if light:
			light.visible = true
		if thrust:
			thrust.emitting = true
			
	AudioManager.play_sfx("rocket_thruster")
	
	var shot3_tween = create_tween().set_parallel(true)
	active_tweens.append(shot3_tween)
	shot3_tween.tween_property(cam, "global_position", Vector3(-42.0, 6.5, -28.0), 5.5).set_trans(Tween.TRANS_SINE)
	if rocket_instance:
		shot3_tween.tween_property(rocket_instance, "global_position:y", 45.0, 5.5).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	await shot3_tween.finished
	
	if not is_playing:
		return
		
	cam.global_position = Vector3(-10.0, 52.0, 50.0)
	cam.look_at(Vector3(15.0, 6.0, -15.0), Vector3.UP)
	
	radio_subtitle.text = "Mount Hale has been cleansed. Trajectory nominal. You're coming home, Leo. Mission accomplished."
	
	if ext:
		_spawn_explosion(ext, Vector3(24.0, 3.0, -30.0), 0.75, 4.0)
		get_tree().create_timer(0.4).timeout.connect(func():
			if is_playing and ext:
				_spawn_explosion(ext, Vector3(16.0, 5.0, -25.0), 0.85, 3.0)
		)
		get_tree().create_timer(0.8).timeout.connect(func():
			if is_playing and ext:
				_spawn_explosion(ext, Vector3(32.0, 4.0, -36.0), 0.7, 4.0)
		)
		
	var shot4_tween = create_tween().set_parallel(true)
	active_tweens.append(shot4_tween)
	shot4_tween.tween_property(cam, "global_position", Vector3(-15.0, 62.0, 60.0), 5.0).set_trans(Tween.TRANS_SINE)
	if rocket_instance:
		shot4_tween.tween_property(rocket_instance, "global_position", Vector3(10.0, 180.0, -90.0), 5.0).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	await shot4_tween.finished
	
	finish_cutscene()

func _spawn_explosion(parent: Node3D, pos: Vector3, pitch: float = 1.0, vol: float = 0.0):
	AudioManager.play_sfx("explosion", pitch, vol)
	var burst_scene = load("res://scenes/props/prop_explosion_burst.tscn")
	if burst_scene and parent:
		var burst = burst_scene.instantiate()
		parent.add_child(burst)
		burst.global_position = pos
		dynamic_bursts.append(burst)
		var bt = create_tween().set_parallel(true)
		var fb = burst.get_node_or_null("%Fireball")
		var bl = burst.get_node_or_null("%BurstLight")
		if fb:
			bt.tween_property(fb, "scale", Vector3(2.5, 2.5, 2.5), 0.4)
			bt.tween_property(fb, "scale", Vector3.ZERO, 1.2).set_delay(0.4)
		if bl:
			bt.tween_property(bl, "light_energy", 0.0, 1.6)
		bt.chain().tween_callback(func():
			if is_instance_valid(burst):
				burst.queue_free()
		)

func finish_cutscene():
	if not is_playing:
		return
	is_playing = false
	visible = false
	_clean_tweens()
	
	for b in dynamic_bursts:
		if is_instance_valid(b):
			b.queue_free()
	dynamic_bursts.clear()
	
	if is_instance_valid(rover_instance):
		rover_instance.queue_free()
		rover_instance = null
		
	if is_instance_valid(rocket_instance):
		rocket_instance.queue_free()
		rocket_instance = null
		
	if is_instance_valid(ext_instance):
		ext_instance.queue_free()
		ext_instance = null
		
	AudioManager.play_sfx("quindar_outro")
	cutscene_finished.emit()
	var ui = get_tree().get_first_node_in_group("UI")
	if ui and ui.win_screen:
		ui.win_screen.visible = true
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
