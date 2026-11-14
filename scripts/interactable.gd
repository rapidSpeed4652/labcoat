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
			return "⚡ [EQUIPMENT: MODEL 74 EMITTER]"
		InteractType.POLAROID:
			return "📷 [EVIDENCE: DR. THORNE'S POLAROID]"
		InteractType.TAPE_RECORDER:
			return "📻 [AUDIO LOG: C-60 REEL CASSETTE]"
		InteractType.CAPACITOR_SWITCH:
			var bay_name = "Bay A (Cryo)" if capacitor_index == 1 else ("Bay B (Flux)" if capacitor_index == 2 else "Bay C (Oscillator)")
			return "⚡ [CAPACITOR %s: %s]" % [bay_name, "DISCHARGED" if has_been_used else "ACTIVE"]
		InteractType.SHUTDOWN_LEVER:
			if not GameManager.dome_puzzle_solved:
				return "🚨 [CONSOLE: BLOCKED BY SHADOW NEXUS]"
			if not GameManager.dome_override_unlocked:
				return "🔒 [CONSOLE: MASTER AZIMUTH CLAMPED]"
			return "🚨 [OVERRIDE: EMERGENCY SHUTDOWN LEVER]"
		InteractType.EXIT_DOOR:
			return "🚪 [EXIT: MOUNTAIN ESCAPE APERTURE]"
		InteractType.LRRR_ARRAY:
			return "🔭 [LUNAR APPARATUS: APOLLO 11 LRRR ARRAY]"
		InteractType.PORTABLE_MIRROR_PICKUP:
			return "🔭 [OPTICAL ITEM: +2 PORTABLE MIRRORS]"
	return "🔍 [INTERACTABLE]"

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
			return "Heavy optical laser. Raw beam is absorbed by shadows; must bounce off mirrors to banish."
		InteractType.POLAROID:
			return "Dr. Thorne's last photograph. Read the handwritten margin note for the Airlock Alpha code."
		InteractType.TAPE_RECORDER:
			return "Audio log from Dr. Thorne. Press [E] to play cassette recording."
		InteractType.CAPACITOR_SWITCH:
			if has_been_used:
				return "Capacitor safely isolated in sequence."
			return "Follow Dr. Thorne's Astrometric Log to discharge in sequence (Bay A -> Bay C -> Bay B) or risk arc blowout!"
		InteractType.SHUTDOWN_LEVER:
			if not GameManager.dome_puzzle_solved:
				return "Banish the shadow entities using the 3 telescope reflectors before accessing console."
			if not GameManager.dome_override_unlocked:
				return "Hydraulic clamps locked. Enter the 4-digit Master Azimuth override code from Tape Log 3."
			return "Pull lever to seal dome roof shutter and sever the Boötes return vector!"
		InteractType.EXIT_DOOR:
			return "Shutter sealed. Escape through the pressurized mountain hatch." if GameManager.shutdown_lever_pulled else "Locked until primary roof shutter is sealed."
		InteractType.LRRR_ARRAY:
			if GameManager.lrrr_calibrated:
				return "Apollo 11 corner cubes aligned to Azimuth 214°. Pinging Earth Station."
			return "Align quartz corner cube retroreflector array to Azimuth 214° to re-energize Sector 1 sensor."
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
				return "[LOCKED - Shadow nexus surrounds console]"
			if not GameManager.dome_override_unlocked:
				return "[E] Enter Master Azimuth Code (Check Tape Log 3)"
			return "PULL EMERGENCY SHUTDOWN LEVER"
		InteractType.EXIT_DOOR:
			if not GameManager.shutdown_lever_pulled:
				return "[SEALED - Roof shutter must be closed first]"
			return "Escape Mount Hale Observatory"
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
					AudioManager.play_sfx("switch_flip", 0.8)
					var lever_mesh = get_node_or_null("LeverHandle")
					if lever_mesh:
						var tween = create_tween()
						tween.tween_property(lever_mesh, "rotation_degrees:x", 60.0, 0.2)
					var light = get_node_or_null("StatusLight")
					if light:
						light.light_color = Color(0.2, 1.0, 0.4)
				
		InteractType.SHUTDOWN_LEVER:
			if not GameManager.dome_puzzle_solved:
				AudioManager.play_sfx("laser_click", 0.5)
				return
			if not GameManager.dome_override_unlocked:
				GameManager.request_keypad("dome_override", "8352", "MASTER AZIMUTH OVERRIDE")
				return
			if not has_been_used:
				has_been_used = true
				AudioManager.play_sfx("switch_flip", 0.6)
				AudioManager.play_sfx("shutter_close")
				var lever_mesh = get_node_or_null("LeverHandle")
				if lever_mesh:
					var tween = create_tween()
					tween.tween_property(lever_mesh, "rotation_degrees:x", 65.0, 0.3)
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
		tween.tween_property(lever_mesh, "rotation_degrees:x", 0.0, 0.2)
	var light = get_node_or_null("StatusLight")
	if light:
		light.light_color = Color(1.0, 0.7, 0.1)
