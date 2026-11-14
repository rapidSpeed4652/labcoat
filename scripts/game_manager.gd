extends Node

# Game Acts
enum Act {
	ACT_1_CONTROL_ROOM,
	ACT_2_GALLERY,
	ACT_3_DOME,
	ENDING,
	GAME_OVER
}

var current_act: Act = Act.ACT_1_CONTROL_ROOM

# Inventory & Equipment
var has_laser: bool = false
var portable_mirrors_count: int = 1

# Puzzle states
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

# Current active objective
var current_objective: String = "Inspect the control room. Find the handheld alignment laser."

# Signals
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
	# Ensure default actions have both keycode and physical_keycode registered
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
			# Register keycode
			var ev_k = InputEventKey.new()
			ev_k.keycode = k
			InputMap.action_add_event(act_name, ev_k)
			# Register physical_keycode
			var ev_p = InputEventKey.new()
			ev_p.physical_keycode = k
			InputMap.action_add_event(act_name, ev_p)
	
	# Mouse button actions
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
		"SUPERVISOR VANCE (EARTH STATION)",
		"Leo, this is Vance at Earth Station. Listen carefully: DO NOT try to shut down the laser or cut main power! The Boötes rift has formed a self-sustaining quantum bridge—cutting power will invert spacetime and swallow the station! We must execute the RETRO-INVERSION PROTOCOL: overcharge and phase-invert the laser to fire a 100-Petawatt Hyper-Pulse back down the bridge, annihilating the rift at its source! Find the alignment laser and calibrate the Apollo 11 array on the lunar crater floor to lock our Stokes baseline sync!",
		9.5
	)

func set_objective(text: String):
	current_objective = text
	objective_updated.emit(text)

func trigger_radio(speaker: String, text: String, duration: float = 6.0):
	radio_message_started.emit(speaker, text, duration)
	AudioManager.play_radio_static()

func inspect_polaroid():
	is_inspecting_polaroid = true
	polaroid_opened.emit()

func close_polaroid():
	is_inspecting_polaroid = false
	polaroid_closed.emit()

func play_tape_log(title: String, transcript: String, voice_clip: String = ""):
	tape_played.emit(title, transcript)
	if voice_clip != "":
		AudioManager.play_voice(voice_clip)

func request_keypad(target_id: String, expected_code: String, title: String):
	keypad_requested.emit(target_id, expected_code, title)

func calibrate_lrrr():
	if lrrr_calibrated:
		return
	lrrr_calibrated = true
	set_objective("Apollo 11 LRRR Calibrated! Re-enter the base and bounce laser onto the Sector 1 sensor.")
	trigger_radio(
		"SUPERVISOR VANCE (EARTH STATION)",
		"Telemetry lock confirmed! Apollo 11 retroreflectors are pinging our Earth beacon! Stokes baseline sync locked! Return inside and bounce the laser off the wall mirror to open Sector 1!",
		7.5
	)
	var receptor = get_tree().root.find_child("OpticalReceptor_Act1", true, false)
	if receptor and receptor.has_method("_update_visuals"):
		receptor._update_visuals()

func on_keypad_success(target_id: String):
	keypad_unlocked.emit(target_id)
	match target_id:
		"airlock_alpha":
			airlock_alpha_unlocked = true
			set_objective("Airlock Alpha UNSEALED! Suit up and step out onto the lunar surface.")
			trigger_radio(
				"SUPERVISOR VANCE (EARTH STATION)",
				"Airlock Alpha cycled! You're cleared for exterior lunar traverse. Head to the Apollo 11 array on the crater floor and align the primary benchmark!",
				7.0
			)
			var door = get_tree().root.find_child("AirlockAlpha_Door", true, false)
			if door and door.has_method("open"):
				door.open()
		"cleanroom_barrier":
			cleanroom_unlocked = true
			set_objective("Laser grid deactivated! Access the Spectrometry Lab and recover Tape Log 2.")
			var barrier = get_tree().root.find_child("CleanroomLaserBarrier", true, false)
			if barrier:
				barrier.queue_free()
			var terminal = get_tree().root.find_child("CleanroomKeypadTerminal", true, false)
			if terminal and terminal.has_method("open"):
				terminal.open()
		"dome_override":
			dome_override_unlocked = true
			set_objective("Master Azimuth clamp released! PULL THE MASTER RETRO-INVERSION TRIGGER!")
			trigger_radio(
				"SUPERVISOR VANCE (EARTH STATION)",
				"Master Azimuth frequency 8352 verified! The hydraulic firing clamps have released! PULL THE RETRO-INVERSION TRIGGER!",
				6.0
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
	set_objective("BOUNCE LASER: Aim beam at the wall mirror so the reflection hits the Optical Receptor.")
	trigger_radio(
		"SUPERVISOR VANCE (EARTH STATION)",
		"Good, you found the alignment laser. Direct coherent light is useless against the shadow apparitions—it only feeds them! You must bounce the beam off mirrors. Reflected light inverts their quantum phase and burns their silhouette away!",
		7.0
	)

func unlock_act1_door():
	if act1_door_unlocked:
		return
	act1_door_unlocked = true
	set_objective("Enter the Gallery. Synthesize 488nm phase code and energize Bays A, C, and B.")
	trigger_radio(
		"SUPERVISOR VANCE (EARTH STATION)",
		"Security aperture unsealed! Enter the central gallery spine. Open your tactical schematic with M or TAB. We must acquire the 488nm carrier wave from the cleanroom, then charge the 3 capacitor bays in harmonic resonance to power the 100-Petawatt retro-strike!",
		7.5
	)

func try_activate_capacitor(idx: int, _breaker: Node) -> bool:
	if current_seq_idx < capacitor_sequence.size() and idx == capacitor_sequence[current_seq_idx]:
		current_seq_idx += 1
		capacitors_activated = current_seq_idx
		
		var dome_door = get_tree().root.find_child("DomeBlastDoor", true, false)
		
		if current_seq_idx == 1:
			set_objective("Step 1/3: Bay A Cryo-Coolant primed! Next: Bay C (Laser Oscillator) [Check Thorne's Log 2].")
			trigger_radio(
				"SUPERVISOR VANCE (EARTH STATION)",
				"Cryo-coolant loop primed! Cryogenic temperature stabilized for 100-Petawatt pulse. Now energize Bay C's oscillator before touching the magnetic flux loop!",
				6.5
			)
			if dome_door:
				dome_door.lock_text = "[BLAST LOCK: 2 CAPACITORS REMAINING]"
				dome_door.lock_hint = "Energize Bay C and Bay B in harmonic sequence."
		elif current_seq_idx == 2:
			set_objective("Step 2/3: Oscillator energized! Final: Bay B (Magnetic Flux Chamber).")
			trigger_radio(
				"SUPERVISOR VANCE (EARTH STATION)",
				"Oscillator in phase lock! Magnetic flux loop is now ready to charge in Bay B. Complete the sequence, Leo!",
				6.5
			)
			if dome_door:
				dome_door.lock_text = "[BLAST LOCK: 1 CAPACITOR REMAINING]"
				dome_door.lock_hint = "Energize Bay B (Magnetic Flux) to release blast lock."
		elif current_seq_idx == 3:
			dome_door_unlocked = true
			set_objective("All 3 bays energized! 100-Petawatt resonance achieved! Head into the Coudé Dome.")
			trigger_radio(
				"SUPERVISOR VANCE (EARTH STATION)",
				"100-Petawatt resonance cascade locked! The carrier wave is inverted! The Coudé Dome blast doors are OPEN! Get to the dome, align the triad, and prepare the retro-strike!",
				7.5
			)
			if dome_door:
				dome_door.lock_text = "[BLAST LOCK DISENGAGED - ACCESS GRANTED]"
				dome_door.lock_hint = "Blast doors unlocked. Head into the Coudé Dome."
				if dome_door.has_method("open"):
					dome_door.open()
		return true
	else:
		# Sequence violation!
		AudioManager.play_sfx("dome_alarm", 1.0, 5.0)
		trigger_radio(
			"SUPERVISOR VANCE (EARTH STATION)",
			"WARNING! Harmonic sequence mismatch! Arc fault tripped the breaker interlock! Thorne's log explicitly states: Bay A (1) -> Bay C (3) -> Bay B (2)! Follow the sequence!",
			7.0
		)
		set_objective("[ARC FAULT: GRID RESET] Sequence violated! Required: Bay A -> Bay C -> Bay B (1 -> 3 -> 2)!")
		reset_all_capacitors()
		
		# Punish mistake: spawn an aggressive Void Stalker in the gallery spine!
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
		dome_door.lock_text = "[BLAST LOCK: 3 AUXILIARY CAPACITORS REQUIRED]"
		dome_door.lock_hint = "Energize all 3 auxiliary capacitors in Bay A, Bay B, and Bay C in harmonic sequence."

func activate_capacitor():
	capacitors_activated += 1
	var remaining = CAPACITORS_REQUIRED - capacitors_activated
	
	# Update Dome Blast Door live telemetry if present
	var dome_door = get_tree().root.find_child("DomeBlastDoor", true, false)
	if dome_door:
		if remaining <= 0:
			dome_door.lock_text = "[BLAST LOCK DISENGAGED - ACCESS GRANTED]"
			dome_door.lock_hint = "Blast doors unlocked. Head into the Coudé Dome."
			if dome_door.has_method("open"):
				dome_door.open()
		else:
			dome_door.lock_text = "[BLAST LOCK: %d/3 CAPACITORS REMAINING]" % remaining
			dome_door.lock_hint = "Energize %d more auxiliary capacitor(s) in sequence." % remaining
	
	if remaining <= 0:
		dome_door_unlocked = true
		set_objective("All 3 bays energized! 100-Petawatt resonance achieved! Head into the Coudé Dome.")
		trigger_radio(
			"SUPERVISOR VANCE (EARTH STATION)",
			"All three capacitors energized! Power redirected to the central dome! The heavy blast doors are open! Leo, get to the dome and align the triad!",
			7.0
		)
	elif capacitors_activated == 1:
		set_objective("Capacitor 1/3 energized. Continue sequence in bays (Check Map [M]).")
		trigger_radio(
			"SUPERVISOR VANCE (EARTH STATION)",
			"Capacitor One energized! Cryogenic surge detected in Bay B. Two remaining! Keep your distance from those Void Phantoms!",
			6.5
		)
	else:
		set_objective("Capacitor 2/3 energized. Finish sequence at Bay B (Check Map [M]).")
		trigger_radio(
			"SUPERVISOR VANCE (EARTH STATION)",
			"Capacitor Two online! One auxiliary capacitor remains in Bay B. The entity signatures are converging on your coordinates!",
			6.5
		)

func solve_dome_puzzle():
	if dome_puzzle_solved:
		return
	dome_puzzle_solved = true
	set_objective("Equilateral triad locked! The entities are banished. Enter Code 8352 at the Firing Terminal!")
	trigger_radio(
		"LEO",
		"It worked! The reflected equilateral beam cage collapsed the entity nexus! The Firing Terminal is clear!",
		5.5
	)

func pull_shutdown_lever():
	if shutdown_lever_pulled:
		return
	shutdown_lever_pulled = true
	current_act = Act.ENDING
	set_objective("Rift collapsed! Evacuate via the West Rover Air-Lock.")
	trigger_radio(
		"SUPERVISOR VANCE (EARTH STATION)",
		"RETRO-INVERSION STRIKE SUCCESSFUL! The 100-Petawatt pulse bounced back down the bridge! Destructive interference confirmed across all deep-space sensors—the Boötes rift has collapsed! Head to the West Rover Air-Lock, Leo. You saved us all!",
		8.0
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
