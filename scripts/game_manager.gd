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
var capacitors_activated: int = 0
const CAPACITORS_REQUIRED: int = 3
var dome_door_unlocked: bool = false
var dome_puzzle_solved: bool = false
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
		"interact": [KEY_E, KEY_F],
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
		"Leo, this is Vance at Earth Station. Do you copy? The October eclipse triggered a rogue cascade—the Mount Hale primary laser locked onto a deep space return vector and jammed the roof shutter wide open! Shut down the three auxiliary capacitors in the lower galleries and seal that dome before the anomaly bridges into full stability!",
		17.0,
		"radio_intro"
	)

func set_objective(text: String):
	current_objective = text
	objective_updated.emit(text)

func trigger_radio(speaker: String, text: String, duration: float = 6.0, voice_clip: String = ""):
	radio_message_started.emit(speaker, text, duration)
	if voice_clip != "":
		AudioManager.play_voice(voice_clip)

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

func pickup_laser():
	has_laser = true
	set_objective("BOUNCE LASER: Aim beam at the wall mirror so the reflection hits the Optical Receptor.")
	trigger_radio(
		"SUPERVISOR VANCE (EARTH STATION)",
		"Good, you found the alignment laser. Remember Dr. Thorne's notes: direct coherent light is useless against the shadow apparitions—it only feeds them! You must bounce the beam off mirrors. Reflected light inverts their quantum phase and burns their silhouette away!",
		12.5,
		"radio_laser_acquired"
	)

func unlock_act1_door():
	if act1_door_unlocked:
		return
	act1_door_unlocked = true
	set_objective("Enter the Sub-surface Gallery. Shut down all 3 auxiliary capacitors in Bays A, B, and C.")
	trigger_radio(
		"SUPERVISOR VANCE (EARTH STATION)",
		"Security aperture unsealed! Enter the central gallery spine. Open your tactical schematic with M or TAB. Watch the observation windows—sensors detect abnormal electromagnetic movement out on the crater rim.",
		13.5,
		"radio_act1_unlocked"
	)

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
			dome_door.lock_hint = "Shut down %d more auxiliary capacitor(s) in the bays to unlock." % remaining
	
	if remaining <= 0:
		dome_door_unlocked = true
		set_objective("All 3 capacitors offline! Dome blast doors UNLOCKED. Head to the Central Dome.")
		trigger_radio(
			"SUPERVISOR VANCE (EARTH STATION)",
			"All three capacitors offline! Power redirected to the central dome! The heavy blast doors are open! Leo, get to the dome and align the tertiary mirror array!",
			10.5,
			"radio_cap3"
		)
	elif capacitors_activated == 1:
		set_objective("Capacitor 1/3 offline. Shut down 2 more in the bays (Check Map [M]).")
		trigger_radio(
			"SUPERVISOR VANCE (EARTH STATION)",
			"Capacitor One offline! Cryogenic surge detected in Bay B. Two remaining! Keep your distance from those corrupted drones!",
			8.5,
			"radio_cap1"
		)
	else:
		set_objective("Capacitor 2/3 offline. Shut down Bay C (Check Map [M]).")
		trigger_radio(
			"SUPERVISOR VANCE (EARTH STATION)",
			"Capacitor Two disengaged! One auxiliary capacitor remains in Bay C. The entity signatures are converging on your coordinates!",
			8.5,
			"radio_cap2"
		)

func solve_dome_puzzle():
	if dome_puzzle_solved:
		return
	dome_puzzle_solved = true
	set_objective("Triangle alignment complete! The entities are banished. Pull the manual shutdown lever!")
	trigger_radio(
		"LEO",
		"It worked! The reflected beam cage vaporized them! The central console is clear!",
		5.5
	)

func pull_shutdown_lever():
	if shutdown_lever_pulled:
		return
	shutdown_lever_pulled = true
	current_act = Act.ENDING
	set_objective("Shutter sealed! Proceed to the main exit door.")
	trigger_radio(
		"SUPERVISOR VANCE (EARTH STATION)",
		"Shutter sealed! Beam collapse confirmed on Earth telemetry! The return vector is severed! Head through the pressurized mountain hatch, Leo. You did it!",
		10.0,
		"radio_ending"
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
