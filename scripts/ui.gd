extends CanvasLayer

@onready var prompt_label: Label = $Control/TargetCard/VBox/ActionLabel
@onready var badge_label: Label = $Control/TargetCard/VBox/BadgeLabel
@onready var hint_label: Label = $Control/TargetCard/VBox/HintLabel
@onready var target_card: Control = $Control/TargetCard
@onready var crosshair_dot: ColorRect = $Control/Crosshair/Dot
@onready var crosshair_bracket_l: Label = $Control/Crosshair/BracketL
@onready var crosshair_bracket_r: Label = $Control/Crosshair/BracketR

@onready var objective_label: Label = $Control/ObjectivePanel/ObjectiveLabel
@onready var heat_bar: ProgressBar = $Control/LaserPanel/HeatBar
@onready var heat_label: Label = $Control/LaserPanel/HeatLabel
@onready var flashlight_label: Label = $Control/FlashlightPanel/FlashlightLabel
@onready var mirror_label: Label = $Control/MirrorPanel/MirrorLabel
@onready var laser_panel: Control = $Control/LaserPanel

@onready var radio_box: Control = $Control/RadioBox
@onready var radio_speaker: Label = $Control/RadioBox/VBox/SpeakerLabel
@onready var radio_text: Label = $Control/RadioBox/VBox/MessageLabel

@onready var polaroid_modal: Control = $Control/PolaroidModal
@onready var tape_modal: Control = $Control/TapeModal
@onready var tape_title_label: Label = $Control/TapeModal/Center/Panel/VBox/TitleLabel
@onready var tape_transcript_label: RichTextLabel = $Control/TapeModal/Center/Panel/VBox/TranscriptLabel
@onready var keypad_modal: Control = $Control/KeypadModal

@onready var death_screen: Control = $Control/DeathScreen
@onready var win_screen: Control = $Control/WinScreen
@onready var pause_menu: Control = $Control/PauseMenu
@onready var crt_overlay: ColorRect = $Control/CRTOverlay
@onready var minimap_panel: Control = $Control/MinimapPanel
@onready var full_map_modal: Control = $Control/FullMapModal
@onready var checklist_label: Label = $Control/FullMapModal/Center/Panel/VBox/ContentHBox/Sidebar/ChecklistLabel
@onready var map_close_btn: Button = $Control/FullMapModal/Center/Panel/VBox/ContentHBox/Sidebar/CloseButton

var typewriter_tween: Tween
var current_target_obj: Node = null

func _ready():
	process_mode = Node.PROCESS_MODE_ALWAYS
	add_to_group("UI")
	target_card.visible = false
	polaroid_modal.visible = false
	tape_modal.visible = false
	death_screen.visible = false
	win_screen.visible = false
	radio_box.visible = false
	pause_menu.visible = false
	if full_map_modal:
		full_map_modal.visible = false
	if map_close_btn:
		map_close_btn.pressed.connect(toggle_full_map)
	
	_set_reticle_state(false)
	
	GameManager.objective_updated.connect(update_objective)
	GameManager.radio_message_started.connect(show_radio_message)
	GameManager.polaroid_opened.connect(_on_polaroid_opened)
	GameManager.polaroid_closed.connect(_on_polaroid_closed)
	GameManager.tape_played.connect(_on_tape_played)
	GameManager.mirror_count_changed.connect(_on_mirror_count_changed)
	GameManager.game_lost.connect(_on_game_lost)
	GameManager.game_won.connect(_on_game_won)
	GameManager.player_respawn_requested.connect(_on_player_respawn)
	GameManager.flashlight_toggled.connect(update_flashlight)
	
	update_objective(GameManager.current_objective)
	_on_mirror_count_changed(GameManager.portable_mirrors_count)
	update_flashlight(true)
	
	if keypad_modal:
		keypad_modal.visible = false
		GameManager.keypad_requested.connect(_on_keypad_requested)
		keypad_modal.code_matched.connect(GameManager.on_keypad_success)

func _input(event: InputEvent):
	if keypad_modal and keypad_modal.visible:
		return
		
	if event.is_action_pressed("toggle_map"):
		if not death_screen.visible and not win_screen.visible and not polaroid_modal.visible and not tape_modal.visible and not pause_menu.visible:
			toggle_full_map()
			get_viewport().set_input_as_handled()
			return
	
	if event.is_action_pressed("pause") or event.is_action_pressed("interact") or (event is InputEventMouseButton and event.pressed):
		if tape_modal.visible:
			tape_modal.visible = false
			Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
			get_viewport().set_input_as_handled()
			return
		if polaroid_modal.visible:
			GameManager.close_polaroid()
			get_viewport().set_input_as_handled()
			return
	
	if event.is_action_pressed("pause"):
		if full_map_modal and full_map_modal.visible:
			toggle_full_map()
			get_viewport().set_input_as_handled()
			return
		if not death_screen.visible and not win_screen.visible:
			toggle_pause()

func toggle_full_map():
	if not full_map_modal:
		return
	var opening = not full_map_modal.visible
	full_map_modal.visible = opening
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE if opening else Input.MOUSE_MODE_CAPTURED
	if opening:
		_update_map_checklist()

func _update_map_checklist():
	if not checklist_label:
		return
	var text = "MISSION CHECKLIST & TELEMETRY:\n\n"
	text += "[x] Equipment: Model 74 Alignment Laser\n" if GameManager.has_laser else "[ ] Equipment: Model 74 Alignment Laser\n"
	text += "[x] Apollo 11 LRRR: BENCHMARK SYNC\n" if GameManager.lrrr_calibrated else "[ ] Apollo 11 LRRR: PENDING CALIBRATION\n"
	text += "[x] Sector 1 Sensor: UNLOCKED\n" if GameManager.act1_door_unlocked else "[ ] Sector 1 Sensor: LOCKED (BOUNCE BEAM)\n"
	text += "[x] Cleanroom Laser Grid: OFFLINE\n" if GameManager.cleanroom_unlocked else "[ ] Cleanroom Laser Grid: ACTIVE (CODE 488)\n"
	text += "[x] Bay A Cryo-Coolant (1): ENERGIZED\n" if GameManager.capacitors_activated >= 1 else "[ ] Bay A Cryo-Coolant (1): PENDING\n"
	text += "[x] Bay C Oscillator (3): ENERGIZED\n" if GameManager.capacitors_activated >= 2 else "[ ] Bay C Oscillator (3): PENDING\n"
	text += "[x] Bay B Magnetic Flux (2): ENERGIZED\n" if GameManager.capacitors_activated >= 3 else "[ ] Bay B Magnetic Flux (2): PENDING\n"
	text += "[x] Dome Blast Doors: OPEN\n" if GameManager.dome_door_unlocked else "[ ] Dome Blast Doors: SEALED (3/3 REQ)\n"
	text += "[x] Coudé Equilateral Triad: ALIGNED\n" if GameManager.dome_puzzle_solved else "[ ] Coudé Equilateral Triad: PENDING\n"
	text += "[x] Master Azimuth Code: UNLOCKED\n" if GameManager.dome_override_unlocked else "[ ] Master Azimuth Code: CLAMPED (8352)\n"
	text += "[x] Primary Cavity Discharge: COMPLETE\n" if GameManager.shutdown_lever_pulled else "[ ] Primary Cavity Discharge: ARMED\n"
	text += "[x] Surface Rover Evacuation: CLEARED\n" if GameManager.current_act == GameManager.Act.ENDING else "[ ] Surface Rover Evacuation: SEALED\n"
	checklist_label.text = text

func toggle_pause():
	var new_paused = not get_tree().paused
	get_tree().paused = new_paused
	pause_menu.visible = new_paused
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE if new_paused else Input.MOUSE_MODE_CAPTURED

func _process(_delta: float):
	laser_panel.visible = GameManager.has_laser
	
	var player = get_tree().get_first_node_in_group("Player")
	if player and player.laser_system:
		var sys = player.laser_system
		heat_bar.value = sys.heat * 100.0
		if sys.is_overheated:
			heat_label.text = "OVERHEAT! 3s COOLDOWN"
			heat_label.modulate = Color(1.0, 0.2, 0.2)
			heat_bar.modulate = Color(1.0, 0.2, 0.2)
		else:
			heat_label.text = "EMITTER HEAT: " + str(int(sys.heat * 100.0)) + "%"
			heat_label.modulate = Color(0.2, 0.9, 1.0)
			heat_bar.modulate = Color(0.2, 0.9, 1.0)

func set_targeted_object(obj: Node):
	current_target_obj = obj
	if not obj or not is_instance_valid(obj):
		target_card.visible = false
		_set_reticle_state(false)
		return
	
	target_card.visible = true
	_set_reticle_state(true)
	
	var badge = obj.get_category_badge() if obj.has_method("get_category_badge") else "🔍 [OBJECT]"
	var badge_col = obj.get_category_color() if obj.has_method("get_category_color") else Color(1, 0.9, 0.4)
	var prompt = obj.get_interaction_prompt() if obj.has_method("get_interaction_prompt") else "Interact"
	var hint = obj.get_hint() if obj.has_method("get_hint") else ""
	
	badge_label.text = badge
	badge_label.modulate = badge_col
	prompt_label.text = "[E] " + prompt if not prompt.begins_with("[") else prompt
	hint_label.text = hint
	hint_label.visible = not hint.is_empty()

func _set_reticle_state(is_targeting: bool):
	if is_targeting:
		crosshair_dot.color = Color(1.0, 0.85, 0.2, 1.0)
		crosshair_bracket_l.visible = true
		crosshair_bracket_r.visible = true
	else:
		crosshair_dot.color = Color(0.2, 0.9, 1.0, 0.6)
		crosshair_bracket_l.visible = false
		crosshair_bracket_r.visible = false

func update_objective(text: String):
	objective_label.text = text

func show_radio_message(speaker: String, text: String, duration: float):
	AudioManager.play_radio_static()
	radio_box.visible = true
	radio_box.modulate.a = 1.0
	radio_speaker.text = speaker
	radio_text.text = ""
	
	if typewriter_tween:
		typewriter_tween.kill()
	
	var calc_duration = max(duration, max(16.0, text.length() * 0.08))
	
	typewriter_tween = create_tween()
	typewriter_tween.tween_property(radio_text, "visible_characters", text.length(), 0.8).from(0)
	radio_text.text = text
	
	await get_tree().create_timer(calc_duration).timeout
	if radio_speaker.text == speaker:
		var fade_tween = create_tween()
		fade_tween.tween_property(radio_box, "modulate:a", 0.0, 0.6)
		await fade_tween.finished
		if radio_speaker.text == speaker:
			radio_box.visible = false
			radio_box.modulate.a = 1.0

func _on_polaroid_opened():
	polaroid_modal.visible = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	AudioManager.play_sfx("entity_stalk", 0.9)

func _on_polaroid_closed():
	polaroid_modal.visible = false
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

func _on_tape_played(title: String, transcript: String):
	if tape_modal:
		tape_modal.visible = true
		tape_title_label.text = "▶ [CASSETTE AUDIO RECORDING // " + title.to_upper() + "]"
		tape_transcript_label.text = transcript
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

func _on_keypad_requested(target_id: String, expected_code: String, title: String):
	if keypad_modal:
		keypad_modal.open(target_id, expected_code, title)

func _on_mirror_count_changed(count: int):
	mirror_label.text = "PORTABLE MIRRORS: " + str(count) + " [RMB/Q PLACE]"

func update_flashlight(is_on: bool):
	if flashlight_label:
		flashlight_label.text = "FLASHLIGHT: " + ("ON" if is_on else "OFF") + " [F TOGGLE]"
		flashlight_label.modulate = Color(0.2, 0.9, 1.0) if is_on else Color(0.5, 0.6, 0.7)

func _on_game_lost():
	death_screen.visible = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

func _on_player_respawn():
	death_screen.visible = false
	pause_menu.visible = false
	get_tree().paused = false
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

func _on_game_won():
	var cutscene = get_tree().root.find_child("EndingCutscene", true, false)
	if cutscene and cutscene.has_method("play_ending_sequence"):
		cutscene.play_ending_sequence()
	else:
		win_screen.visible = true
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

func _on_restart_button_pressed():
	GameManager.restart_checkpoint()

func _on_resume_button_pressed():
	toggle_pause()

func _on_crt_toggle_toggled(button_pressed: bool):
	if crt_overlay:
		crt_overlay.visible = button_pressed

func flash_damage():
	if crt_overlay:
		var tween = create_tween()
		tween.tween_property(crt_overlay, "modulate", Color(2.5, 0.3, 0.3, 1.0), 0.06)
		tween.tween_property(crt_overlay, "modulate", Color(1.0, 1.0, 1.0, 1.0), 0.4)

func _on_quit_button_pressed():
	get_tree().quit()
