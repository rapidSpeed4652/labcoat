extends Node

enum Act {
	ACT_1_CONTROL_ROOM,
	ACT_2_GALLERY,
	ACT_3_DOME,
	ENDING,
	GAME_OVER
}

var current_act: Act = Act.ACT_1_CONTROL_ROOM

var has_laser: bool = false
var portable_mirrors_count: int = 1

var act1_door_unlocked: bool = false
var lrrr_calibrated: bool = false
var capacitors_activated: int = 0
const CAPACITORS_REQUIRED: int = 3
var capacitor_sequence: Array[int] = [1, 3, 2]
var current_seq_idx: int = 0
var dome_door_unlocked: bool = false
var dome_puzzle_solved: bool = false
var dome_override_unlocked: bool = false
var shutdown_lever_pulled: bool = false

var current_objective: String = "Locate alignment laser on control desk."

signal objective_updated(new_objective: String)
signal radio_message_started(speaker: String, text: String, duration: float)
signal radio_message_ended()
signal polaroid_opened()
signal polaroid_closed()
signal tape_played(title: String, transcript: String)
signal player_respawn_requested()
signal game_won()
signal game_lost()
signal mirror_count_changed(count: int)
signal flashlight_toggled(is_on: bool)
signal keypad_requested(target_id: String, expected_code: String, title: String)
signal keypad_unlocked(target_id: String)

var airlock_alpha_unlocked: bool = false
var cleanroom_unlocked: bool = false

var is_inspecting_polaroid: bool = false

func _ready():
	process_mode = Node.PROCESS_MODE_ALWAYS
	is_inspecting_polaroid = false
	_setup_inputs()
	call_deferred("_start_intro_radio")

func _setup_inputs():
	var key_actions = {
		"move_forward": [KEY_W, KEY_UP],
		"move_backward": [KEY_S, KEY_DOWN],
		"move_left": [KEY_A, KEY_LEFT],
		"move_right": [KEY_D, KEY_RIGHT],
		"sprint": [KEY_SHIFT],
		"jump": [KEY_SPACE],
		"interact": [KEY_E],
		"toggle_flashlight": [KEY_F],
		"place_mirror": [KEY_Q],
		"toggle_map": [KEY_M, KEY_TAB],
		"restart": [KEY_R],
		"pause": [KEY_ESCAPE]
	}
	for act_name in key_actions:
		if not InputMap.has_action(act_name):
			InputMap.add_action(act_name)
		for k in key_actions[act_name]:
			var ev_k = InputEventKey.new()
			ev_k.keycode = k
			InputMap.action_add_event(act_name, ev_k)
			var ev_p = InputEventKey.new()
			ev_p.physical_keycode = k
			InputMap.action_add_event(act_name, ev_p)
	
	if not InputMap.has_action("fire_laser"):
		InputMap.add_action("fire_laser")
	var ev_lmb = InputEventMouseButton.new()
	ev_lmb.button_index = MOUSE_BUTTON_LEFT
	InputMap.action_add_event("fire_laser", ev_lmb)
	
	if not InputMap.has_action("place_mirror"):
		InputMap.add_action("place_mirror")
	var ev_rmb = InputEventMouseButton.new()
	ev_rmb.button_index = MOUSE_BUTTON_RIGHT
	InputMap.action_add_event("place_mirror", ev_rmb)

func _start_intro_radio():
	await get_tree().create_timer(1.2).timeout
	trigger_radio(
		"FLIGHT DIRECTOR VANCE (HOUSTON)",
		"Mount Hale, this is Houston Flight. Leo, copy? Do not attempt a standard power cut on that Coude line. The dish return loop is drawing power from whatever answered on the other end—cutting line voltage will collapse the collector field and breach the pressurized envelope. We need a clean phase inversion. Check the control desk for an alignment laser, then cycle through Airlock Alpha to benchmark the Apollo 11 array on the crater floor.",
		18.0
	)

func set_objective(text: String):
	current_objective = text
	objective_updated.emit(text)

func trigger_radio(speaker: String, text: String, duration: float = 16.0):
	radio_message_started.emit(speaker, text, duration)
	AudioManager.play_radio_static()

func inspect_polaroid():
	is_inspecting_polaroid = true
	polaroid_opened.emit()

func close_polaroid():
	is_inspecting_polaroid = false
	polaroid_closed.emit()

func play_tape_log(title: String, transcript: String, _voice_clip: String = ""):
	tape_played.emit(title, transcript)

func request_keypad(target_id: String, expected_code: String, title: String):
	keypad_requested.emit(target_id, expected_code, title)

func calibrate_lrrr():
	if lrrr_calibrated:
		return
	lrrr_calibrated = true
	set_objective("Apollo 11 benchmark locked. Return inside and bounce laser onto Sector 1 sensor.")
	trigger_radio(
		"FLIGHT DIRECTOR VANCE (HOUSTON)",
		"Houston confirms benchmark lock on Apollo 11. Array telemetry is active and feeding the internal optical relays. Head back inside—bounce your alignment beam off the gallery mirror to trip the Sector 1 safety release.",
		16.0
	)
	var receptor = get_tree().root.find_child("OpticalReceptor_Act1", true, false)
	if receptor and receptor.has_method("_update_visuals"):
		receptor._update_visuals()

func on_keypad_success(target_id: String):
	keypad_unlocked.emit(target_id)
	match target_id:
		"airlock_alpha":
			airlock_alpha_unlocked = true
			set_objective("Airlock Alpha cycled. Proceed to Apollo 11 array on crater floor.")
			trigger_radio(
				"FLIGHT DIRECTOR VANCE (HOUSTON)",
				"Airlock Alpha cycled. You're clear for surface traverse. Proceed to the Apollo 11 reflector array on the crater floor and align the primary benchmark.",
				16.0
			)
			var door = get_tree().root.find_child("AirlockAlpha_Door", true, false)
			if door and door.has_method("open"):
				door.open()
		"cleanroom_barrier":
			cleanroom_unlocked = true
			set_objective("Cleanroom barrier down. Access lab terminals and review Log 2.")
			var barrier = get_tree().root.find_child("CleanroomLaserBarrier", true, false)
			if barrier:
				if barrier.has_method("deactivate"):
					barrier.deactivate()
				else:
					barrier.queue_free()
			var terminal = get_tree().root.find_child("CleanroomKeypadTerminal", true, false)
			if terminal and terminal.has_method("open"):
				terminal.open()
		"dome_override":
			dome_override_unlocked = true
			set_objective("Azimuth clamps released. Pull main discharge lever.")
			trigger_radio(
				"FLIGHT DIRECTOR VANCE (HOUSTON)",
				"Azimuth 8352 verified. Hydraulic clamps disengaged. Pull the main discharge lever.",
				15.0
			)

func schedule_entity_respawn(spawn_pos: Vector3, delay: float):
	await get_tree().create_timer(delay).timeout
	if current_act != Act.ENDING and current_act != Act.GAME_OVER:
		var entity_scene = load("res://scenes/shadow_entity.tscn")
		if entity_scene:
			var obs = get_tree().root.find_child("Observatory", true, false)
			if obs:
				var entity = entity_scene.instantiate()
				obs.add_child(entity)
				entity.global_position = spawn_pos
				AudioManager.play_sfx("entity_stalk", 1.1)

func pickup_laser():
	has_laser = true
	set_objective("Bounce beam off wall mirror to strike Sector 1 optical sensor.")
	trigger_radio(
		"FLIGHT DIRECTOR VANCE (HOUSTON)",
		"Laser unit acquired. Remember: direct optical output won't disperse those silhouettes—coherent light just scatters off their surface. You have to reflect the beam off polished surfaces to shift the phase.",
		16.0
	)

func unlock_act1_door():
	if act1_door_unlocked:
		return
	act1_door_unlocked = true
	set_objective("Enter Gallery. Synthesize 488nm phase line and energize Bays A, C, B.")
	trigger_radio(
		"FLIGHT DIRECTOR VANCE (HOUSTON)",
		"Sector 1 confirmed open. The primary capacitor bank is segmented across Bays A, B, and C. Check the cleanroom lab for Dr. Thorne's calibration logs before cycling any breakers—they're interlocked to prevent transformer blowouts.",
		16.0
	)

func try_activate_capacitor(idx: int, _breaker: Node) -> bool:
	if current_seq_idx < capacitor_sequence.size() and idx == capacitor_sequence[current_seq_idx]:
		current_seq_idx += 1
		capacitors_activated = current_seq_idx
		
		var dome_door = get_tree().root.find_child("DomeBlastDoor", true, false)
		
		if current_seq_idx == 1:
			set_objective("Bay A coolant loop online (1/3). Next: Bay C Oscillator (Log 2).")
			trigger_radio(
				"FLIGHT DIRECTOR VANCE (HOUSTON)",
				"Bay A coolant loop engaged. Line pressure nominal. Bay C oscillator next—keep away from the flux coil until the oscillator is online.",
				15.0
			)
			if dome_door:
				dome_door.lock_text = "[INTERLOCK: 2 CAPACITORS REMAINING]"
				dome_door.lock_hint = "Energize Bay C and Bay B in sequence."
		elif current_seq_idx == 2:
			set_objective("Bay C Oscillator online (2/3). Final: Bay B Magnetic Flux.")
			trigger_radio(
				"FLIGHT DIRECTOR VANCE (HOUSTON)",
				"Bay C oscillator synchronized. Now energize the magnetic flux in Bay B to complete the bank.",
				15.0
			)
			if dome_door:
				dome_door.lock_text = "[INTERLOCK: 1 CAPACITOR REMAINING]"
				dome_door.lock_hint = "Energize Bay B (Magnetic Flux) to release blast lock."
		elif current_seq_idx == 3:
			dome_door_unlocked = true
			set_objective("Capacitor bank fully charged (3/3). Proceed to Coude Dome.")
			trigger_radio(
				"FLIGHT DIRECTOR VANCE (HOUSTON)",
				"All three capacitor bays online and holding charge. Coude dome blast door interlock cleared. Proceed to the dome.",
				16.0
			)
			if dome_door:
				dome_door.lock_text = "[INTERLOCK CLEARED - ACCESS GRANTED]"
				dome_door.lock_hint = "Blast doors unlocked. Proceed into the Coude Dome."
				if dome_door.has_method("open"):
					dome_door.open()
		return true
	else:
		AudioManager.play_sfx("dome_alarm", 1.0, 5.0)
		trigger_radio(
			"FLIGHT DIRECTOR VANCE (HOUSTON)",
			"Warning: Interlock trip on the capacitor grid. Sequence was Bay A, then C, then B. Resetting breakers now.",
			16.0
		)
		set_objective("[INTERLOCK RESET] Sequence error. Order required: Bay A -> Bay C -> Bay B.")
		reset_all_capacitors()
		
		var obs = get_tree().root.find_child("Observatory", true, false)
		if obs:
			schedule_entity_respawn(Vector3(18.0, 0.0, -4.0), 0.5)
		return false

func reset_all_capacitors():
	current_seq_idx = 0
	capacitors_activated = 0
	var breakers = get_tree().get_nodes_in_group("CapacitorBreakers")
	for b in breakers:
		if b.has_method("reset_breaker"):
			b.reset_breaker()
	var dome_door = get_tree().root.find_child("DomeBlastDoor", true, false)
	if dome_door:
		dome_door.lock_text = "[INTERLOCK: 3 CAPACITORS REQUIRED]"
		dome_door.lock_hint = "Energize Bay A, Bay C, and Bay B in sequence."

func activate_capacitor():
	capacitors_activated += 1
	var remaining = CAPACITORS_REQUIRED - capacitors_activated
	
	var dome_door = get_tree().root.find_child("DomeBlastDoor", true, false)
	if dome_door:
		if remaining <= 0:
			dome_door.lock_text = "[INTERLOCK CLEARED - ACCESS GRANTED]"
			dome_door.lock_hint = "Blast doors unlocked. Proceed into the Coude Dome."
			if dome_door.has_method("open"):
				dome_door.open()
		else:
			dome_door.lock_text = "[INTERLOCK: %d/3 CAPACITORS REMAINING]" % remaining
			dome_door.lock_hint = "Energize %d more capacitor bay(s) in sequence." % remaining
	
	if remaining <= 0:
		dome_door_unlocked = true
		set_objective("Capacitor bank charged. Proceed to Coude Dome.")
		trigger_radio(
			"FLIGHT DIRECTOR VANCE (HOUSTON)",
			"All three capacitors online. Dome blast door is open. Proceed inside and align the mirror triad.",
			16.0
		)
	elif capacitors_activated == 1:
		set_objective("Capacitor 1/3 online. Continue sequence (Check Map [M]).")
		trigger_radio(
			"FLIGHT DIRECTOR VANCE (HOUSTON)",
			"Capacitor One online. Two remaining.",
			15.0
		)
	else:
		set_objective("Capacitor 2/3 online. Final bay remaining (Check Map [M]).")
		trigger_radio(
			"FLIGHT DIRECTOR VANCE (HOUSTON)",
			"Capacitor Two online. Complete the bank at Bay B.",
			15.0
		)

func solve_dome_puzzle():
	if dome_puzzle_solved:
		return
	dome_puzzle_solved = true
	set_objective("Mirror triad locked. Enter Code 8352 at main console.")
	trigger_radio(
		"LEO",
		"Triad locked. Reflected beam cleared the platform. Console access is open.",
		15.0
	)

func pull_shutdown_lever():
	if shutdown_lever_pulled:
		return
	shutdown_lever_pulled = true
	current_act = Act.ENDING
	set_objective("Discharge complete. Evacuate to surface airlock.")
	trigger_radio(
		"FLIGHT DIRECTOR VANCE (HOUSTON)",
		"Discharge confirmed. Beam collapse verified on Houston telemetry. Roof shutter is sealing down. Evacuate to the rover airlock, Leo. Good work.",
		18.0
	)

func player_died():
	current_act = Act.GAME_OVER
	game_lost.emit()

func restart_checkpoint():
	get_tree().paused = false
	player_respawn_requested.emit()

func complete_game():
	current_act = Act.ENDING
	game_won.emit()
