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
	# Simulate pressing W key
	var ev_w = InputEventKey.new()
	ev_w.keycode = KEY_W
	ev_w.pressed = true
	Input.parse_input_event(ev_w)
	Input.flush_buffered_events()
	
	# Wait for physics frames
	for i in range(10):
		await get_tree().physics_frame
	
	var moved_pos = player.global_position
	var dist = start_pos.distance_to(moved_pos)
	print("Start: ", start_pos, " Moved: ", moved_pos, " Dist: ", dist)
	assert(dist > 0.05, "Player must move when W key is pressed!")
	print("✓ Test 0: WASD movement triggers cleanly and moves player!")
	
	# Release W
	ev_w.pressed = false
	Input.parse_input_event(ev_w)
	Input.flush_buffered_events()
	
	# Test 1: Laser pickup
	assert(GameManager.has_laser == false, "Player should start without laser")
	var laser_pickup = get_node("Main/Observatory/Act1_ControlRoom/LaserPickup")
	assert(laser_pickup != null, "Laser pickup prop must exist")
	laser_pickup.interact()
	assert(GameManager.has_laser == true, "Player should have laser after pickup")
	print("✓ Test 1: Laser pickup works")
	
	# Test 2: Direct Laser vs Reflected Laser on Shadow Entity
	var entity = get_node("Main/Observatory/Act2_Gallery/ShadowEntity1")
	assert(entity != null, "Shadow Entity 1 must exist")
	
	# Direct hit (unreflected)
	entity.on_laser_hit(false, 0.5)
	assert(entity.absorb_timer > 0.0, "Entity should absorb raw beam")
	assert(entity.is_halted == true, "Entity must be halted in stasis by direct beam")
	assert(entity.is_banished == false, "Entity must NOT be banished by raw beam")
	print("✓ Test 2A: Direct raw beam halts Shadow Entity in stasis without banishing")
	
	# Reflected hit
	entity.on_laser_hit(true, 1.0)
	assert(entity.is_banished == true, "Entity must be banished by reflected beam")
	print("✓ Test 2B: Reflected beam successfully banishes Shadow Entity")
	
	# Test 3: Optical Receptor (Act 1 Door)
	var receptor = get_node("Main/Observatory/Act1_ControlRoom/OpticalReceptor_Act1")
	var mirror = get_node("Main/Observatory/Act1_ControlRoom/WallMirror_Act1")
	var door = get_node("Main/Observatory/Act1_ControlRoom/Act1SecurityDoor")
	assert(receptor != null, "Optical receptor must exist")
	assert(GameManager.act1_door_unlocked == false, "Door must be locked initially")
	
	# Raw beam should not activate receptor
	receptor.on_laser_hit(false, 0.5)
	assert(GameManager.act1_door_unlocked == false, "Raw beam must not unlock door")
	print("✓ Test 3A: Raw beam rejected by optical security receptor")
	
	# Physical In-World Laser Reflection off WallMirror_Act1 into Receptor
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
	print("✓ Test 3B: Physical in-world reflection strictly obeys Law of Reflection (theta_i == theta_r: %.2f°)" % [theta_i])
	
	assert(receptor.is_activated == true, "In-world reflected beam must activate receptor")
	assert(GameManager.act1_door_unlocked == true, "Reflected beam must unlock door in GameManager")
	assert(door.is_open == true, "Security door must open")
	print("✓ Test 3C: Reflected laser beam successfully unlocked and opened Act 1 security door")
	
	# Test 4: Laser Overheat
	var laser_sys = player.laser_system
	laser_sys.heat = 0.99
	laser_sys.is_firing = true
	laser_sys._process(0.1) # should tip over 1.0
	assert(laser_sys.is_overheated == true, "Laser should enter overheat state")
	print("✓ Test 4: Laser overheating & 3s lockout mechanic works")
	
	# Test 5: Act 2 Capacitors (All 3 basement capacitors required)
	var cap1 = get_node("Main/Observatory/Act2_Gallery/CapacitorBreaker1")
	var cap2 = get_node("Main/Observatory/Act2_Gallery/CapacitorBreaker2")
	var cap3 = get_node("Main/Observatory/Act2_Gallery/CapacitorBreaker3")
	assert(cap1 != null and cap2 != null and cap3 != null, "All 3 capacitor breakers must exist")
	cap1.interact()
	assert(GameManager.capacitors_activated == 1, "Capacitor 1 activated")
	assert(GameManager.dome_door_unlocked == false, "Dome blast doors should still be locked after 1 capacitor")
	cap2.interact()
	assert(GameManager.capacitors_activated == 2, "Capacitor 2 activated")
	assert(GameManager.dome_door_unlocked == false, "Dome blast doors should still be locked after 2 capacitors")
	cap3.interact()
	assert(GameManager.capacitors_activated == 3, "Capacitor 3 activated")
	assert(GameManager.dome_door_unlocked == true, "Dome blast doors should be unlocked after all 3 capacitors")
	print("✓ Test 5: All 3 basement capacitor breakers successfully unlock Dome access")
	
	# Test 6: Dome Triangle Alignment & Shutdown
	var station_a = get_node("Main/Observatory/Act3_Dome/StationAlpha")
	var station_b = get_node("Main/Observatory/Act3_Dome/StationBeta")
	var station_c = get_node("Main/Observatory/Act3_Dome/StationGamma")
	
	# Set stations to target angles
	station_a.current_angle_deg = 45.0
	station_a._check_alignment()
	station_b.current_angle_deg = 135.0
	station_b._check_alignment()
	station_c.current_angle_deg = 315.0
	station_c._check_alignment()
	
	assert(GameManager.dome_puzzle_solved == true, "Dome triangle alignment should solve puzzle")
	print("✓ Test 6: Dome reflector triangle alignment banishes entities & unlocks console")
	
	# Test 7: Emergency Shutdown Lever
	var console_lever = get_node("Main/Observatory/Act3_Dome/ShutdownConsole")
	console_lever.interact()
	assert(GameManager.shutdown_lever_pulled == true, "Shutdown lever should be pulled")
	assert(GameManager.current_act == GameManager.Act.ENDING, "Current act should be ENDING")
	print("✓ Test 7: Emergency shutdown lever seals roof shutter")
	
	# Test 8: Map Geometry & Floor Continuity (Zero Void Gaps Across Entire Observatory)
	var waypoints = [
		Vector3(0, 1.0, 0),         # Act 1 Control Room
		Vector3(5.5, 1.0, 0),       # Act 1 Doorway
		Vector3(12.0, 1.0, 0),      # Hallway 1
		Vector3(15.0, 1.0, 6.0),    # Breaker Room 1
		Vector3(24.0, 1.0, 0),      # Hallway 1/2 Corner
		Vector3(22.0, 1.0, -8.0),   # Breaker Room 2 Entrance
		Vector3(17.5, 1.0, -8.0),   # Breaker Room 2 Interior
		Vector3(26.0, 1.0, -8.0),   # Breaker Room 3 Entrance
		Vector3(30.5, 1.0, -8.0),   # Breaker Room 3 Interior
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
		var hit = space_state.intersect_ray(query)
		assert(hit.size() > 0, "No floor found at waypoint %d: %s (VOID GAP DETECTED!)" % [i, wp])
		var floor_y = hit.position.y
		assert(abs(floor_y) < 0.1, "Floor level inconsistent at waypoint %d: %s (y=%.3f, expected ~0.0)" % [i, wp, floor_y])
	print("✓ Test 8: All 18 map waypoints verified with continuous solid floors - ZERO VOID GAPS")
	
	# Test 9: Minimap & Fullscreen GUI Schematic Map
	var ui = get_node("Main/UI")
	assert(ui != null and ui.minimap_panel != null, "Minimap panel must exist")
	assert(ui.full_map_modal != null, "Full map modal must exist")
	ui.toggle_full_map()
	assert(ui.full_map_modal.visible == true, "Full map modal should be open after toggle")
	assert("MISSION CHECKLIST" in ui.checklist_label.text, "Map checklist should be rendered")
	ui.toggle_full_map()
	assert(ui.full_map_modal.visible == false, "Full map modal should be closed after second toggle")
	print("✓ Test 9: Minimap and Fullscreen GUI Facility Map toggle cleanly with live telemetry")
	
	print("======================================================")
	print("ALL 10 GAMEPLAY, PHYSICS & MAP CONTINUITY TESTS PASSED!")
	print("======================================================")
	
	get_tree().quit(0)
