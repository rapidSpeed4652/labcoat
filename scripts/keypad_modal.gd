extends Control

signal code_submitted(code: String)
signal code_matched(target_id: String)
signal closed()

@export var current_target_id: String = ""
@export var expected_code: String = ""
@export var prompt_title: String = "SECURITY KEYPAD ACCESS"

@onready var display_label: Label = $Center/Panel/VBox/DisplayContainer/DisplayLabel
@onready var title_label: Label = $Center/Panel/VBox/TitleLabel
@onready var status_label: Label = $Center/Panel/VBox/StatusLabel

var input_buffer: String = ""
const MAX_DIGITS: int = 8

func _ready():
	_bind_buttons()
	_update_display()
	status_label.text = "[ENTER AUTHORIZED ACCESS CODE]"
	status_label.modulate = Color(0.3, 0.85, 1.0)

func open(target_id: String, code: String, title: String = "SECURITY KEYPAD ACCESS"):
	current_target_id = target_id
	expected_code = code
	prompt_title = title
	title_label.text = title
	input_buffer = ""
	status_label.text = "[ENTER AUTHORIZED ACCESS CODE]"
	status_label.modulate = Color(0.3, 0.85, 1.0)
	_update_display()
	visible = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

func close():
	visible = false
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	closed.emit()

func _bind_buttons():
	for i in range(10):
		var btn = get_node_or_null("Center/Panel/VBox/Grid/Btn_" + str(i))
		if btn:
			btn.pressed.connect(func(): _on_digit_pressed(str(i)))
	
	var btn_clr = get_node_or_null("Center/Panel/VBox/Grid/Btn_CLR")
	if btn_clr:
		btn_clr.pressed.connect(_on_clear_pressed)
		
	var btn_ent = get_node_or_null("Center/Panel/VBox/Grid/Btn_ENT")
	if btn_ent:
		btn_ent.pressed.connect(_on_enter_pressed)
		
	var btn_close = get_node_or_null("Center/Panel/VBox/BtnClose")
	if btn_close:
		btn_close.pressed.connect(close)

func _input(event: InputEvent):
	if not visible:
		return
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode >= KEY_0 and event.keycode <= KEY_9:
			_on_digit_pressed(str(event.keycode - KEY_0))
			get_viewport().set_input_as_handled()
		elif event.keycode == KEY_BACKSPACE:
			_on_clear_pressed()
			get_viewport().set_input_as_handled()
		elif event.keycode == KEY_ENTER or event.keycode == KEY_KP_ENTER:
			_on_enter_pressed()
			get_viewport().set_input_as_handled()
		elif event.keycode == KEY_ESCAPE:
			close()
			get_viewport().set_input_as_handled()

func _on_digit_pressed(digit: String):
	if input_buffer.length() < MAX_DIGITS:
		input_buffer += digit
		AudioManager.play_sfx("keypad_beep")
		_update_display()

func _on_clear_pressed():
	input_buffer = ""
	AudioManager.play_sfx("keypad_beep", 0.8)
	_update_display()

func _on_enter_pressed():
	code_submitted.emit(input_buffer)
	if expected_code != "" and input_buffer == expected_code:
		AudioManager.play_sfx("switch_flip", 1.2)
		status_label.text = "[ACCESS GRANTED - PROTOCOL ENGAGED]"
		status_label.modulate = Color(0.2, 1.0, 0.4)
		display_label.text = "GRANTED"
		code_matched.emit(current_target_id)
		await get_tree().create_timer(0.6).timeout
		close()
	else:
		AudioManager.play_sfx("access_denied")
		status_label.text = "[ERR: INVALID CODE - CHECK AUDIO/POLAROID LORE]"
		status_label.modulate = Color(1.0, 0.25, 0.2)
		display_label.text = "DENIED"
		await get_tree().create_timer(0.8).timeout
		input_buffer = ""
		_update_display()

func _update_display():
	if input_buffer.is_empty():
		display_label.text = "----"
	else:
		display_label.text = input_buffer
