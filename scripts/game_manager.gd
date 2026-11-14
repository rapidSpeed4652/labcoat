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
const CAPACITORS_REQUIRED: int = 2
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
		"SUPERVISOR CHEN (RADIO)",
		"Leo, do you copy? The main roof shutter jammed open during the eclipse, and the primary laser is still firing into the dark. Shut down the capacitors and get out of there!",
		8.0
	)

func set_objective(text: String):
	current_objective = text
	objective_updated.emit(text)

func trigger_radio(speaker: String, text: String, duration: float = 6.0):
	radio_message_started.emit(speaker, text, duration)

func inspect_polaroid():
	is_inspecting_polaroid = true
	polaroid_opened.emit()

func close_polaroid():
	is_inspecting_polaroid = false
	polaroid_closed.emit()

func play_tape_log(title: String, transcript: String):
	tape_played.emit(title, transcript)

func pickup_laser():
	has_laser = true
	set_objective("Test bouncing the laser off the wall mirror to power the magnetic door lock.")
	trigger_radio(
		"LEO",
		"Got the alignment laser. Direct light won't work on the security sensor—I need to bounce the beam off that angled wall mirror.",
		6.0
	)

func unlock_act1_door():
	if act1_door_unlocked:
		return
	act1_door_unlocked = true
	set_objective("Enter the Mirror Gallery. Find and activate 2 capacitor breaker switches.")
	trigger_radio(
		"SUPERVISOR CHEN (RADIO)",
		"The gallery door just unlocked on my telemetry board. Watch yourself, Leo... something is causing severe infrared interference in those halls.",
		7.0
	)

func activate_capacitor():
	capacitors_activated += 1
	if capacitors_activated >= CAPACITORS_REQUIRED:
		dome_door_unlocked = true
		set_objective("Capacitors engaged! Head to the Central Telescope Dome.")
		trigger_radio(
			"SUPERVISOR CHEN (RADIO)",
			"Main dome power restored! The blast doors are open. Get to the central console and seal that roof shutter!",
			6.5
		)
	else:
		set_objective("Capacitor 1/2 engaged. Find the remaining breaker in the gallery.")

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
		"SUPERVISOR CHEN (RADIO)",
		"The primary beam just shut down! Shutter is locking. Get out of the facility, Leo. Now!",
		6.0
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
