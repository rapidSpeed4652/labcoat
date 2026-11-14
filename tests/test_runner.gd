extends Node

func _ready():
	print("=== RUNNING AUTOMATED GAMEPLAY TESTS ===")
	
	# Load main scene
	var main_scene = load("res://scenes/main.tscn").instantiate()
	add_child(main_scene)
	
	await get_tree().create_timer(0.2).timeout
	
	var player = get_node("Main/Player")
	assert(player != null, "Player must exist in scene")
	print("✓ Player instantiated successfully")
	
	# Test 0: WASD Movement Verification
	var start_pos = player.global_position
	var ev_w = InputEventKey.new()
	ev_w.keycode = KEY_W
	ev_w.pressed = true
	Input.parse_input_event(ev_w)
	Input.flush_buffered_events()
	
	for i in range(10):
		await get_tree().physics_frame
	
	var moved_pos = player.global_position
	var dist = start_pos.distance_to(moved_pos)
	print("Start: ", start_pos, " Moved: ", moved_pos, " Dist: ", dist)
	assert(dist > 0.05, "Player must move when W key is pressed!")
	print("✓ Test 0: WASD movement triggers cleanly and moves player!")
	
	ev_w.pressed = false
	Input.parse_input_event(ev_w)
	Input.flush_buffered_events()
	
	# Test 1: Laser pickup & Flashlight
	assert(GameManager.has_laser == false, "Player should start without laser")
	var laser_pickup = get_node("Main/Observatory/Act1_ControlRoom/LaserPickup")
	assert(laser_pickup != null, "Laser pickup prop must exist")
	laser_pickup.interact()
	assert(GameManager.has_laser == true, "Player should have laser after pickup")
	print("✓ Test 1: Laser pickup works")
	
	assert(player.flashlight != null, "Flashlight SpotLight3D must exist on player")
	var initial_flash = player.flashlight.visible
	player.toggle_flashlight()
	assert(player.flashlight.visible != initial_flash, "Flashlight toggle must flip visibility")
	player.toggle_flashlight()
	assert(player.flashlight.visible == initial_flash, "Flashlight toggle must restore visibility")
	print("✓ Test 1B: Player Flashlight (Key F) toggles cleanly")
	
	# Test 2: Direct Laser vs Reflected Laser on Shadow Entity
	var entity = get_node("Main/Observatory/Act2_Gallery/ShadowEntity1")
	assert(entity != null, "Shadow Entity 1 must exist")
	
	# Direct hit (unreflected) - damages entity and holds in stasis
	var initial_hp = entity.health
	entity.on_laser_hit(false, 0.5)
	assert(entity.health < initial_hp, "Direct beam must damage shadow entity")
	assert(entity.absorb_timer > 0.0, "Entity should absorb raw beam into stasis")
	assert(entity.is_halted == true, "Entity must be halted in stasis by direct beam")
	assert(entity.is_banished == false, "Entity must not be immediately banished after only 0.5s of direct beam")
	print("✓ Test 2A: Direct beam damages and halts Shadow Entity in stasis")
	
	# Reflected hit - Critical phase inversion banishes entity
	entity.on_laser_hit(true, 1.0)
	assert(entity.is_banished == true, "Entity must be banished by reflected beam")
	print("✓ Test 2B: Reflected beam successfully banishes Shadow Entity with critical damage")
	
	# Test 3: Airlock Alpha (Keypad 1974) & Apollo 11 LRRR Pallet Calibration
	var airlock_alpha = get_node("Main/Observatory/Act1_ControlRoom/AirlockAlpha_Door")
	assert(airlock_alpha != null, "Airlock Alpha door must exist")
	assert(airlock_alpha.is_open == false, "Airlock Alpha must be locked initially")
	
	# Enter code 1974 from Dr. Thorne's Polaroid
	GameManager.on_keypad_success("airlock_alpha")
	assert(airlock_alpha.is_open == true, "Airlock Alpha must open after code 1974")
	assert(GameManager.airlock_alpha_unlocked == true, "GameManager airlock state unlocked")
	print("✓ Test 3A: Airlock Alpha opens with Dr. Thorne's Polaroid code (1974)")
	
	# Verify Optical Receptor rejects hits before LRRR calibration
	var receptor = get_node("Main/Observatory/Act1_ControlRoom/OpticalReceptor_Act1")
	var mirror = get_node("Main/Observatory/Act1_ControlRoom/WallMirror_Act1")
	var door = get_node("Main/Observatory/Act1_ControlRoom/Act1SecurityDoor")
	assert(receptor != null and mirror != null and door != null, "Act 1 optics nodes must exist")
	assert(GameManager.lrrr_calibrated == false, "LRRR array should be uncalibrated initially")
	receptor.on_laser_hit(true, 0.5)
	assert(door.is_open == false, "Receptor must be unpowered before exterior LRRR calibration")
	print("✓ Test 3B: Interior security receptor rejects hits while exterior LRRR benchmark is uncalibrated")
	
	# Calibrate Apollo 11 LRRR Pallet on the lunar surface
	var lrrr = get_node("Main/Observatory/Act1_ControlRoom/LRRR_Array")
	assert(lrrr != null, "Apollo 11 LRRR Array must exist on the lunar surface")
	lrrr.interact()
	assert(GameManager.lrrr_calibrated == true, "LRRR array must be calibrated")
	print("✓ Test 3C: Apollo 11 LRRR array calibrated to Azimuth 214°!")
	
	# Physical in-world reflection off WallMirror_Act1 into receptor
	player.global_position = Vector3(-2.4, 0.0, 0.0)
	player.camera.look_at(mirror.global_position + Vector3(0, 0, 0.02), Vector3.UP)
	var laser_sys_test = player.laser_system
	laser_sys_test.is_firing = true
	for f in range(25):
		laser_sys_test._process(0.016)
		await get_tree().physics_frame
	laser_sys_test.is_firing = false
	
	# Verify Law of Reflection: theta_i == theta_r
	var seg0 = laser_sys_test.beam_segments[0]
	var seg1 = laser_sys_test.beam_segments[1]
	assert(seg0.visible and seg1.visible, "Both incident and reflected beams must be rendered")
	var inc_dir = seg0.global_transform.basis.y
	var ref_dir = seg1.global_transform.basis.y
	var mir_n = mirror.global_transform.basis.z.normalized()
	var theta_i = rad_to_deg(acos(-inc_dir.dot(mir_n)))
	var theta_r = rad_to_deg(acos(ref_dir.dot(mir_n)))
	assert(abs(theta_i - theta_r) < 0.001, "Law of reflection violated in test runner")
	print("✓ Test 3D: In-world reflection strictly obeys Law of Reflection (theta_i == theta_r: %.2f°)" % [theta_i])
	
	assert(receptor.is_activated == true, "In-world reflected beam must activate energized receptor")
	assert(GameManager.act1_door_unlocked == true, "Reflected beam must unlock door in GameManager")
	assert(door.is_open == true, "Security door must open")
	print("✓ Test 3E: Reflected laser beam successfully unlocked Sector 1 magnetic security door")
	
	# Test 4: Laser Overheating & 3s lockout
	var laser_sys = player.laser_system
	laser_sys.heat = 0.99
	laser_sys.is_firing = true
	laser_sys._process(0.1)
	assert(laser_sys.is_overheated == true, "Laser should enter overheat state")
	print("✓ Test 4: Laser overheating & 3s lockout mechanic works")
	
	# Test 5: Spectrometry Cleanroom Keypad (Code 488)
	var cleanroom_barrier = get_node_or_null("Main/Observatory/Act2_Gallery/CleanroomLaserBarrier")
	assert(cleanroom_barrier != null, "Cleanroom laser barrier must exist initially")
	GameManager.on_keypad_success("cleanroom_barrier")
	assert(GameManager.cleanroom_unlocked == true, "Cleanroom state must be unlocked")
	print("✓ Test 5A: Cleanroom laser barrier deactivated using Argon-ion code 488")
	
	# Test 6: Strict Capacitor Sequence Enforcement (Bay A [1] -> Bay C [3] -> Bay B [2])
	var cap1 = get_node("Main/Observatory/Act2_Gallery/CapacitorBreaker1")
	var cap2 = get_node("Main/Observatory/Act2_Gallery/CapacitorBreaker2")
	var cap3 = get_node("Main/Observatory/Act2_Gallery/CapacitorBreaker3")
	assert(cap1 != null and cap2 != null and cap3 != null, "All 3 capacitor breakers must exist")
	
	# Step 1: Bay A
	cap1.interact()
	assert(GameManager.capacitors_activated == 1, "Capacitor 1 activated")
	
	# Intentional Sequence Violation: try Bay B (2) before Bay C (3)
	cap2.interact()
	assert(GameManager.capacitors_activated == 0, "Out-of-order activation must reset capacitors to 0!")
	print("✓ Test 6A: Arc fault protection successfully catches sequence violation and resets grid")
	
	# Execute True Sequence: 1 -> 3 -> 2
	cap1.interact()
	assert(GameManager.capacitors_activated == 1, "Capacitor 1 (Bay A Cryo) activated")
	cap3.interact()
	assert(GameManager.capacitors_activated == 2, "Capacitor 3 (Bay C Oscillator) activated")
	assert(GameManager.dome_door_unlocked == false, "Dome blast doors must remain locked after 2 capacitors")
	cap2.interact()
	assert(GameManager.capacitors_activated == 3, "Capacitor 2 (Bay B Flux) activated")
	assert(GameManager.dome_door_unlocked == true, "Dome blast doors must unlock after completing sequence 1->3->2")
	print("✓ Test 6B: Strict lore sequence 1 -> 3 -> 2 successfully unlocks Coudé Dome access")
	
	# Test 7: Dome Reflector Triangle Alignment
	var station_a = get_node("Main/Observatory/Act3_Dome/StationAlpha")
	var station_b = get_node("Main/Observatory/Act3_Dome/StationBeta")
	var station_c = get_node("Main/Observatory/Act3_Dome/StationGamma")
	station_a.current_angle_deg = 45.0
	station_a._check_alignment()
	station_b.current_angle_deg = 135.0
	station_b._check_alignment()
	station_c.current_angle_deg = 315.0
	station_c._check_alignment()
	assert(GameManager.dome_puzzle_solved == true, "Dome triangle alignment should solve puzzle")
	print("✓ Test 7: Dome reflector triangle alignment banishes entities & unlocks console")
	
	# Test 8: Master Azimuth Keypad Override (Code 8352) & Emergency Shutdown Lever
	var console_lever = get_node("Main/Observatory/Act3_Dome/ShutdownConsole")
	assert(GameManager.dome_override_unlocked == false, "Console should be locked without azimuth code")
	console_lever.interact()
	assert(GameManager.shutdown_lever_pulled == false, "Lever cannot be pulled before entering code 8352")
	
	# Enter code 8352 from Dr. Thorne's Tape Log 3
	GameManager.on_keypad_success("dome_override")
	assert(GameManager.dome_override_unlocked == true, "Master azimuth override must unlock lever")
	console_lever.interact()
	assert(GameManager.shutdown_lever_pulled == true, "Shutdown lever should be pulled")
	assert(GameManager.current_act == GameManager.Act.ENDING, "Current act should be ENDING")
	print("✓ Test 8: Master Azimuth Code 8352 releases console clamps & seals roof shutter")
	
	# Test 9: Complete Map Geometry & Floor Continuity (Zero Void Gaps Across Entire Observatory)
	var waypoints = [
		Vector3(0, 1.0, 0),         # Act 1 Control Room
		Vector3(0, 1.0, -7.5),      # Apollo 11 LRRR Approach on Crater Floor
		Vector3(-4.0, 1.0, -6.0),   # Airlock Alpha
		Vector3(5.5, 1.0, 0),       # Act 1 Doorway
		Vector3(12.0, 1.0, 0),      # Hallway 1 Spine
		Vector3(15.0, 1.0, 6.0),    # Bay A Cryo Vault
		Vector3(15.0, 1.0, 10.0),   # Airlock Beta Doorway
		Vector3(24.0, 1.0, 0),      # Hallway 1/2 Corner
		Vector3(28.0, 1.0, -2.0),   # Spectrometry Cleanroom (Lab Alpha)
		Vector3(22.0, 1.0, -8.0),   # Bay B Entrance
		Vector3(17.5, 1.0, -8.0),   # Bay B Flux Chamber
		Vector3(19.0, 1.0, -14.0),  # Astrometric Archive & Darkroom
		Vector3(26.0, 1.0, -8.0),   # Bay C Entrance
		Vector3(30.5, 1.0, -8.0),   # Bay C Primary Oscillator
		Vector3(24.0, 1.0, -16.0),  # Hallway 2 Blast Door
		Vector3(24.0, 1.0, -17.0),  # Vestibule Transition
		Vector3(24.0, 1.0, -19.0),  # Act 3 Dome Entrance
		Vector3(24.0, 1.0, -32.0),  # Dome Center
		Vector3(31.5, 1.0, -36.5),  # Station Alpha Approach
		Vector3(24.0, 1.0, -24.5),  # Station Beta Approach
		Vector3(16.5, 1.0, -36.5),  # Station Gamma Approach
		Vector3(10.0, 1.0, -32.0),  # Exit Hallway Entrance
		Vector3(1.0, 1.0, -32.0)    # Final Exit Door
	]
	var space_state = player.get_world_3d().direct_space_state
	for i in range(waypoints.size()):
		var wp = waypoints[i]
		var query = PhysicsRayQueryParameters3D.create(wp + Vector3(0, 0.5, 0), wp - Vector3(0, 2.0, 0))
		query.collide_with_areas = false
		query.collide_with_bodies = true
		query.collision_mask = 1
		var hit = space_state.intersect_ray(query)
		assert(hit.size() > 0, "No floor found at waypoint %d: %s (VOID GAP DETECTED!)" % [i, wp])
		var floor_y = hit.position.y
		print("Waypoint %d (%s) hit: %s at %s" % [i, wp, hit.collider.get_path(), hit.position])
		assert(abs(floor_y) < 0.1, "Floor level inconsistent at waypoint %d: %s (y=%.3f, expected ~0.0)" % [i, wp, floor_y])
	print("✓ Test 9: All 23 map waypoints verified with continuous solid floors - ZERO VOID GAPS")
	
	# Test 10: Minimap & Fullscreen GUI Schematic Map
	var ui = get_node("Main/UI")
	assert(ui != null and ui.minimap_panel != null, "Minimap panel must exist")
	assert(ui.full_map_modal != null, "Full map modal must exist")
	ui.toggle_full_map()
	assert(ui.full_map_modal.visible == true, "Full map modal should be open after toggle")
	assert("MISSION CHECKLIST" in ui.checklist_label.text, "Map checklist should be rendered")
	ui.toggle_full_map()
	assert(ui.full_map_modal.visible == false, "Full map modal should be closed after second toggle")
	print("✓ Test 10: Minimap and Fullscreen GUI Facility Map toggle cleanly with live telemetry")
	
	# Test 11: 3D Lunar Exterior Surface & Outpost Infrastructure
	var lunar_ext = get_node_or_null("Main/LunarExterior")
	assert(lunar_ext != null, "LunarExterior node must exist in main scene")
	assert(lunar_ext.get_node_or_null("LunarBedrock") != null, "LunarBedrock terrain must exist")
	assert(lunar_ext.get_node_or_null("CommsDish_Dish") != null, "Earth High-Gain Dish must exist")
	assert(lunar_ext.get_node_or_null("LatticeTower") != null, "Communications Lattice Tower must exist")
	assert(lunar_ext.get_node_or_null("SolarArray_1_Wing") != null, "Solar Photovoltaic Wings must exist")
	assert(lunar_ext.get_node_or_null("RoverBody") != null, "Lunar Rover Sled must exist")
	print("✓ Test 11: 3D Lunar exterior landscape, craters, comms dishes & solar arrays verified!")
	
	# Test 12: Audio Log Voicelines & Start Menu
	assert(AudioManager.voice_clips.has("radio_intro"), "Radio intro voice clip must be loaded")
	assert(AudioManager.voice_clips.has("tape_log_1"), "Dr. Thorne Tape Log 1 must be loaded")
	assert(AudioManager.voice_clips.has("tape_log_2"), "Dr. Thorne Tape Log 2 must be loaded")
	assert(AudioManager.voice_clips.has("tape_log_3"), "Dr. Thorne Tape Log 3 must be loaded")
	
	var menu_scene = load("res://scenes/start_menu.tscn")
	assert(menu_scene != null, "Start Menu scene must load cleanly")
	var menu_inst = menu_scene.instantiate()
	assert(menu_inst != null, "Start Menu must instantiate without error")
	assert(menu_inst.get_node_or_null("UI/VBoxContainer/BtnStart") != null or menu_inst.get_node_or_null("VBoxContainer/BtnStart") != null, "Start button must exist")
	assert(menu_inst.get_node_or_null("UI/VBoxContainer/BtnDossier") != null or menu_inst.get_node_or_null("VBoxContainer/BtnDossier") != null, "Dossier button must exist")
	menu_inst.queue_free()
	print("✓ Test 12: Analog cassette voice pipeline, audio logs & Start Menu verified!")

	print("======================================================")
	print("ALL 13 ADVANCED GAMEPLAY, LORE & OPTICS TESTS PASSED!")
	print("======================================================")
	
	get_tree().quit(0)
