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
@onready var mirror_label: Label = $Control/MirrorPanel/MirrorLabel
@onready var laser_panel: Control = $Control/LaserPanel

@onready var radio_box: Control = $Control/RadioBox
@onready var radio_speaker: Label = $Control/RadioBox/VBox/SpeakerLabel
@onready var radio_text: Label = $Control/RadioBox/VBox/MessageLabel

@onready var polaroid_modal: Control = $Control/PolaroidModal
@onready var death_screen: Control = $Control/DeathScreen
@onready var win_screen: Control = $Control/WinScreen
@onready var pause_menu: Control = $Control/PauseMenu
@onready var crt_overlay: ColorRect = $Control/CRTOverlay

var typewriter_tween: Tween
var current_target_obj: Node = null

func _ready():
	process_mode = Node.PROCESS_MODE_ALWAYS
	add_to_group("UI")
	target_card.visible = false
	polaroid_modal.visible = false
	death_screen.visible = false
	win_screen.visible = false
	radio_box.visible = false
	pause_menu.visible = false
	
	_set_reticle_state(false)
	
	GameManager.objective_updated.connect(update_objective)
	GameManager.radio_message_started.connect(show_radio_message)
	GameManager.polaroid_opened.connect(_on_polaroid_opened)
	GameManager.polaroid_closed.connect(_on_polaroid_closed)
	GameManager.mirror_count_changed.connect(_on_mirror_count_changed)
	GameManager.game_lost.connect(_on_game_lost)
	GameManager.game_won.connect(_on_game_won)
	GameManager.player_respawn_requested.connect(_on_player_respawn)
	
	update_objective(GameManager.current_objective)
	_on_mirror_count_changed(GameManager.portable_mirrors_count)

func _input(event: InputEvent):
	if event.is_action_pressed("pause"):
		if polaroid_modal.visible:
			GameManager.close_polaroid()
			return
		if not death_screen.visible and not win_screen.visible:
			toggle_pause()

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
	
	# Extract badge, prompt, and hint
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
	radio_speaker.text = speaker
	radio_text.text = ""
	
	if typewriter_tween:
		typewriter_tween.kill()
	
	typewriter_tween = create_tween()
	typewriter_tween.tween_property(radio_text, "visible_characters", text.length(), 1.0).from(0)
	radio_text.text = text
	
	await get_tree().create_timer(duration).timeout
	if radio_speaker.text == speaker:
		radio_box.visible = false

func _on_polaroid_opened():
	polaroid_modal.visible = true

func _on_polaroid_closed():
	polaroid_modal.visible = false

func _on_mirror_count_changed(count: int):
	mirror_label.text = "PORTABLE MIRRORS: " + str(count) + " [RMB/Q PLACE]"

func _on_game_lost():
	death_screen.visible = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

func _on_player_respawn():
	death_screen.visible = false
	pause_menu.visible = false
	get_tree().paused = false
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

func _on_game_won():
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
