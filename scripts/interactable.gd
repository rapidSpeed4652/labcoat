extends StaticBody3D

enum InteractType {
	PICKUP_LASER,
	POLAROID,
	TAPE_RECORDER,
	CAPACITOR_SWITCH,
	SHUTDOWN_LEVER,
	EXIT_DOOR,
	LRRR_ARRAY,
	PORTABLE_MIRROR_PICKUP
}

@export var interaction_type: InteractType = InteractType.POLAROID
@export var prompt: String = "Interact"
@export var tape_title: String = "Log 77-B: Perseus Calibration"
@export_multiline var tape_transcript: String = "The lunar retroreflector array didn't return the beam..."
@export var tape_voice_clip: String = "tape_log_1"
@export var capacitor_index: int = 1

var has_been_used: bool = false

func _ready():
	add_to_group("Interactable")
	if interaction_type == InteractType.CAPACITOR_SWITCH:
		add_to_group("CapacitorBreakers")

func get_category_badge() -> String:
	match interaction_type:
		InteractType.PICKUP_LASER:
			return "[EQUIPMENT: MODEL 74 ALIGNMENT LASER]"
		InteractType.POLAROID:
			return "[PHOTOGRAPH: DR. THORNE'S POLAROID]"
		InteractType.TAPE_RECORDER:
			return "[AUDIO LOG: CASSETTE RECORDER]"
		InteractType.CAPACITOR_SWITCH:
			var bay_name = "Bay A (Cryo)" if capacitor_index == 1 else ("Bay B (Flux)" if capacitor_index == 2 else "Bay C (Oscillator)")
			return "[CAPACITOR %s: %s]" % [bay_name, "DISCHARGED" if has_been_used else "ARMED"]
		InteractType.SHUTDOWN_LEVER:
			if not GameManager.dome_puzzle_solved:
				return "[FIRING CONSOLE: PLATFORM BLOCKED]"
			if not GameManager.dome_override_unlocked:
				return "[FIRING CONSOLE: AZIMUTH CODE REQUIRED]"
			return "[PRIMARY DISCHARGE TRIGGER]"
		InteractType.EXIT_DOOR:
			return "[AIRLOCK: SURFACE ROVER EXIT]"
		InteractType.LRRR_ARRAY:
			return "[LUNAR SURFACE: APOLLO 11 LRRR ARRAY]"
		InteractType.PORTABLE_MIRROR_PICKUP:
			return "[OPTICAL GEAR: +2 TRIPOD MIRRORS]"
	return "[INTERACTABLE]"

func get_category_color() -> Color:
	match interaction_type:
		InteractType.PICKUP_LASER:
			return Color(0.1, 0.9, 1.0)
		InteractType.POLAROID:
			return Color(1.0, 0.85, 0.3)
		InteractType.TAPE_RECORDER:
			return Color(0.9, 0.75, 0.2)
		InteractType.CAPACITOR_SWITCH:
			return Color(0.2, 1.0, 0.4) if has_been_used else Color(1.0, 0.55, 0.1)
		InteractType.SHUTDOWN_LEVER:
			return Color(1.0, 0.2, 0.2)
		InteractType.EXIT_DOOR:
			return Color(0.2, 1.0, 0.5)
		InteractType.LRRR_ARRAY:
			return Color(0.2, 0.9, 1.0)
		InteractType.PORTABLE_MIRROR_PICKUP:
			return Color(0.2, 0.9, 1.0)
	return Color(1.0, 1.0, 1.0)

func get_hint() -> String:
	match interaction_type:
		InteractType.PICKUP_LASER:
			return "Handheld optical alignment laser. Direct beam suppresses entities; reflected beam vaporizes them."
		InteractType.POLAROID:
			return "Dr. Thorne's photograph. Note on margin records the airlock keypad code."
		InteractType.TAPE_RECORDER:
			return "Audio log from Dr. Thorne. Press [E] to play cassette recording."
		InteractType.CAPACITOR_SWITCH:
			if has_been_used:
				return "Capacitor safely isolated in sequence."
			return "Discharge in verified order (Bay A -> Bay C -> Bay B) to avoid interlock reset."
		InteractType.SHUTDOWN_LEVER:
			if not GameManager.dome_puzzle_solved:
				return "Clear the platform using the 3 rotating telescope reflectors."
			if not GameManager.dome_override_unlocked:
				return "Enter the 4-digit Master Azimuth code from Log 3 on the keypad."
			return "Engage discharge lever to collapse the optical return loop and seal the roof shutter."
		InteractType.EXIT_DOOR:
			return "Return loop collapsed. Evacuate to surface rover." if GameManager.shutdown_lever_pulled else "Locked until main laser loop has been discharged."
		InteractType.LRRR_ARRAY:
			if GameManager.lrrr_calibrated:
				return "Apollo 11 corner cubes aligned to Azimuth 214°. Pinging Earth Station."
			return "Calibrate Apollo 11 array to Azimuth 214° to benchmark the optical system."
		InteractType.PORTABLE_MIRROR_PICKUP:
			return "Precision optical tripod mirrors for complex multi-bounce routing."
	return ""

func get_interaction_prompt() -> String:
	match interaction_type:
		InteractType.PICKUP_LASER:
			return "Pick up Handheld Alignment Laser"
		InteractType.POLAROID:
			return "Examine Dr. Thorne's Polaroid Photo"
		InteractType.TAPE_RECORDER:
			return "Play Audio Tape (" + tape_title + ")"
		InteractType.CAPACITOR_SWITCH:
			return "Engage Capacitor Isolation Breaker" if not has_been_used else "[DISCHARGED & ISOLATED]"
		InteractType.SHUTDOWN_LEVER:
			if not GameManager.dome_puzzle_solved:
				return "[LOCKED - Reflected beam triangle required to clear platform]"
			if not GameManager.dome_override_unlocked:
				return "[E] Enter Master Azimuth Code (Check Log 3)"
			return "DISCHARGE MAIN LASER CAVITY"
		InteractType.EXIT_DOOR:
			if not GameManager.shutdown_lever_pulled:
				return "[SEALED - Main laser discharge required first]"
			return "Evacuate to Lunar Surface Rover"
		InteractType.LRRR_ARRAY:
			if GameManager.lrrr_calibrated:
				return "[ALIGNED - AZIMUTH 214° BENCHMARK ACTIVE]"
			return "Calibrate Apollo 11 Retroreflector Array (Azimuth 214°)"
		InteractType.PORTABLE_MIRROR_PICKUP:
			return "Pick up Portable Tripod Mirrors (+2)"
	return prompt

func interact():
	match interaction_type:
		InteractType.PICKUP_LASER:
			GameManager.pickup_laser()
			AudioManager.play_sfx("interact")
			queue_free()
			
		InteractType.POLAROID:
			AudioManager.play_sfx("interact")
			GameManager.inspect_polaroid()
			
		InteractType.TAPE_RECORDER:
			AudioManager.play_sfx("interact")
			AudioManager.play_sfx("radio_static")
			GameManager.play_tape_log(tape_title, tape_transcript, tape_voice_clip)
			
		InteractType.CAPACITOR_SWITCH:
			if not has_been_used:
				var success = GameManager.try_activate_capacitor(capacitor_index, self)
				if success:
					has_been_used = true
					AudioManager.play_sfx("switch_flip", 0.75, 2.0)
					var lever_mesh = get_node_or_null("LeverHandle")
					if lever_mesh:
						var tween = create_tween()
						tween.tween_property(lever_mesh, "rotation_degrees:x", -8.0, 0.05).set_trans(Tween.TRANS_BACK)
						tween.tween_property(lever_mesh, "rotation_degrees:x", 72.0, 0.22).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
						tween.tween_property(lever_mesh, "rotation_degrees:x", 65.0, 0.08).set_trans(Tween.TRANS_SINE)
					var light = get_node_or_null("StatusLight")
					if light:
						var lt = create_tween()
						lt.tween_property(light, "light_color", Color(0.85, 0.95, 1.0), 0.06)
						lt.tween_property(light, "light_energy", 6.0, 0.06)
						lt.tween_property(light, "light_color", Color(0.2, 1.0, 0.4), 0.16)
						lt.tween_property(light, "light_energy", 3.0, 0.16)
				
		InteractType.SHUTDOWN_LEVER:
			if not GameManager.dome_puzzle_solved:
				AudioManager.play_sfx("laser_click", 0.5)
				return
			if not GameManager.dome_override_unlocked:
				GameManager.request_keypad("dome_override", "8352", "MASTER AZIMUTH OVERRIDE")
				return
			if not has_been_used:
				has_been_used = true
				AudioManager.play_sfx("switch_flip", 0.5, 3.0)
				AudioManager.play_sfx("shutter_close")
				var lever_mesh = get_node_or_null("LeverHandle")
				if lever_mesh:
					var tween = create_tween()
					tween.tween_property(lever_mesh, "rotation_degrees:x", -10.0, 0.08).set_trans(Tween.TRANS_BACK)
					tween.tween_property(lever_mesh, "rotation_degrees:x", 78.0, 0.32).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
					tween.tween_property(lever_mesh, "rotation_degrees:x", 70.0, 0.12).set_trans(Tween.TRANS_SINE)
				var beacon = get_node_or_null("BeaconLight")
				if beacon:
					var bt = create_tween()
					bt.tween_property(beacon, "light_color", Color(0.2, 0.9, 1.0), 0.1)
					bt.tween_property(beacon, "light_energy", 8.0, 0.1)
					bt.tween_property(beacon, "light_color", Color(0.2, 1.0, 0.4), 0.3)
					bt.tween_property(beacon, "light_energy", 3.0, 0.3)
				GameManager.pull_shutdown_lever()
				
		InteractType.EXIT_DOOR:
			if not GameManager.shutdown_lever_pulled:
				AudioManager.play_sfx("laser_click", 0.5)
				return
			AudioManager.play_sfx("door_open")
			GameManager.complete_game()
			
		InteractType.LRRR_ARRAY:
			if not GameManager.lrrr_calibrated:
				GameManager.calibrate_lrrr()
				var beam = get_node_or_null("LRRR_BeaconBeam")
				if beam:
					beam.visible = true
				var light = get_node_or_null("BeaconLight")
				if light:
					light.light_color = Color(0.1, 0.9, 1.0)
					light.light_energy = 4.0
					
		InteractType.PORTABLE_MIRROR_PICKUP:
			GameManager.portable_mirrors_count += 2
			GameManager.mirror_count_changed.emit(GameManager.portable_mirrors_count)
			AudioManager.play_sfx("interact")
			queue_free()

func reset_breaker():
	has_been_used = false
	var lever_mesh = get_node_or_null("LeverHandle")
	if lever_mesh:
		var tween = create_tween()
		tween.tween_property(lever_mesh, "rotation_degrees:x", -6.0, 0.22).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		tween.tween_property(lever_mesh, "rotation_degrees:x", 0.0, 0.08)
	var light = get_node_or_null("StatusLight")
	if light:
		light.light_color = Color(1.0, 0.7, 0.1)
		light.light_energy = 2.5
