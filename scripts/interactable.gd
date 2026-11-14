extends StaticBody3D

enum InteractType {
	PICKUP_LASER,
	POLAROID,
	TAPE_RECORDER,
	CAPACITOR_SWITCH,
	SHUTDOWN_LEVER,
	EXIT_DOOR
}

@export var interaction_type: InteractType = InteractType.POLAROID
@export var prompt: String = "Interact"
@export var tape_title: String = "Log 77-B: Perseus Calibration"
@export_multiline var tape_transcript: String = "The lunar retroreflector array didn't return the beam. Something else did. We detected a focal return from the Perseus Void... but there is no reflector out there. It didn't bounce back. It held on. It's climbing down the beam."
@export var tape_voice_clip: String = "tape_log_1"

var has_been_used: bool = false

func _ready():
	add_to_group("Interactable")

func get_category_badge() -> String:
	match interaction_type:
		InteractType.PICKUP_LASER:
			return "⚡ [EQUIPMENT: MODEL 74 EMITTER]"
		InteractType.POLAROID:
			return "📷 [EVIDENCE: DR. VANCE'S POLAROID]"
		InteractType.TAPE_RECORDER:
			return "📻 [AUDIO LOG: C-60 REEL CASSETTE]"
		InteractType.CAPACITOR_SWITCH:
			return "⚡ [POWER GRID: AUXILIARY CAPACITOR]"
		InteractType.SHUTDOWN_LEVER:
			return "🚨 [OVERRIDE: EMERGENCY SHUTDOWN]"
		InteractType.EXIT_DOOR:
			return "🚪 [EXIT: MOUNTAIN ESCAPE APERTURE]"
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
			return Color(1.0, 0.55, 0.1)
		InteractType.SHUTDOWN_LEVER:
			return Color(1.0, 0.2, 0.2)
		InteractType.EXIT_DOOR:
			return Color(0.2, 1.0, 0.5)
	return Color(1.0, 1.0, 1.0)

func get_hint() -> String:
	match interaction_type:
		InteractType.PICKUP_LASER:
			return "Heavy optical laser. Raw beam is absorbed by shadows; must bounce off mirrors to banish."
		InteractType.POLAROID:
			return "Last photograph taken before backup power failed. Look closely at the mirror behind him."
		InteractType.TAPE_RECORDER:
			return "Audio log from night astronomer. Press [E] to listen to recorded audio."
		InteractType.CAPACITOR_SWITCH:
			return "Shut down all 3 basement capacitors in the gallery to route power to the Dome blast doors." if not has_been_used else "Capacitor shut down. Power routed to Dome blast door."
		InteractType.SHUTDOWN_LEVER:
			return "Banish the shadow entities using the 3 telescope reflectors before accessing console." if not GameManager.dome_puzzle_solved else "Pull lever to seal dome shutter and sever deep space return beam!"
		InteractType.EXIT_DOOR:
			return "Shutter sealed. Escape into the mountain air." if GameManager.shutdown_lever_pulled else "Locked until primary roof shutter is sealed."
	return ""

func get_interaction_prompt() -> String:
	match interaction_type:
		InteractType.PICKUP_LASER:
			return "Pick up Handheld Alignment Laser"
		InteractType.POLAROID:
			return "Examine Polaroid Photo"
		InteractType.TAPE_RECORDER:
			return "Play Audio Tape (" + tape_title + ")"
		InteractType.CAPACITOR_SWITCH:
			return "Engage Capacitor Breaker" if not has_been_used else "[ENGAGED]"
		InteractType.SHUTDOWN_LEVER:
			if not GameManager.dome_puzzle_solved:
				return "[LOCKED - Shadow entities blocking console]"
			return "PULL EMERGENCY SHUTDOWN LEVER"
		InteractType.EXIT_DOOR:
			if not GameManager.shutdown_lever_pulled:
				return "[SEALED - Roof shutter must be closed first]"
			return "Escape Mount Hale Observatory"
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
				has_been_used = true
				AudioManager.play_sfx("switch_flip", 0.8)
				var lever_mesh = get_node_or_null("LeverHandle")
				if lever_mesh:
					var tween = create_tween()
					tween.tween_property(lever_mesh, "rotation_degrees:x", 60.0, 0.2)
				GameManager.activate_capacitor()
				
		InteractType.SHUTDOWN_LEVER:
			if not GameManager.dome_puzzle_solved:
				AudioManager.play_sfx("laser_click", 0.5)
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
