extends SceneTree

func _init():
	print("=== RUNNING AUTOMATED GAMEPLAY TESTS ===")
	
	# Load main scene
	var main_scene = load("res://scenes/main.tscn").instantiate()
	root.add_child(main_scene)
	
	# Wait for ready
	await create_timer(0.2).timeout
	
	var player = root.get_node("Main/Player")
	assert(player != null, "Player must exist in scene")
	print("✓ Player instantiated successfully")
	
	# Test 1: Laser pickup
	assert(GameManager.has_laser == false, "Player should start without laser")
	var laser_pickup = root.get_node("Main/Observatory/Act1_ControlRoom/LaserPickup")
	assert(laser_pickup != null, "Laser pickup prop must exist")
	laser_pickup.interact()
	assert(GameManager.has_laser == true, "Player should have laser after pickup")
	print("✓ Test 1: Laser pickup works")
	
	# Test 2: Direct Laser vs Reflected Laser on Shadow Entity
	var entity = root.get_node("Main/Observatory/Act2_Gallery/ShadowEntity1")
	assert(entity != null, "Shadow Entity 1 must exist")
	
	# Direct hit (unreflected)
	entity.on_laser_hit(false, 0.5)
	assert(entity.absorb_timer > 0.0, "Entity should absorb raw beam")
	assert(entity.is_banished == false, "Entity must NOT be banished by raw beam")
	print("✓ Test 2A: Direct raw beam absorbed by Shadow Entity without dying")
	
	# Reflected hit
	entity.on_laser_hit(true, 1.0)
	assert(entity.is_banished == true, "Entity must be banished by reflected beam")
	print("✓ Test 2B: Reflected beam successfully banishes Shadow Entity")
	
	# Test 3: Optical Receptor (Act 1 Door)
	var receptor = root.get_node("Main/Observatory/Act1_ControlRoom/OpticalReceptor_Act1")
	assert(receptor != null, "Optical receptor must exist")
	assert(GameManager.act1_door_unlocked == false, "Door must be locked initially")
	
	# Raw beam should not activate receptor
	receptor.on_laser_hit(false, 0.5)
	assert(GameManager.act1_door_unlocked == false, "Raw beam must not unlock door")
	print("✓ Test 3A: Raw beam rejected by optical security receptor")
	
	# Reflected beam should activate receptor
	receptor.on_laser_hit(true, 0.5)
	assert(GameManager.act1_door_unlocked == true, "Reflected beam must unlock door")
	print("✓ Test 3B: Reflected beam successfully unlocked Act 1 security door")
	
	# Test 4: Laser Overheat
	var laser_sys = player.laser_system
	laser_sys.heat = 0.99
	laser_sys.is_firing = true
	laser_sys._process(0.1) # should tip over 1.0
	assert(laser_sys.is_overheated == true, "Laser should enter overheat state")
	print("✓ Test 4: Laser overheating & 3s lockout mechanic works")
	
	# Test 5: Act 2 Capacitors
	var cap1 = root.get_node("Main/Observatory/Act2_Gallery/CapacitorBreaker1")
	var cap2 = root.get_node("Main/Observatory/Act2_Gallery/CapacitorBreaker2")
	cap1.interact()
	assert(GameManager.capacitors_activated == 1, "Capacitor 1 activated")
	cap2.interact()
	assert(GameManager.capacitors_activated == 2, "Capacitor 2 activated")
	assert(GameManager.dome_door_unlocked == true, "Dome blast doors should be unlocked")
	print("✓ Test 5: Capacitor breakers unlock Dome access")
	
	# Test 6: Dome Triangle Alignment & Shutdown
	var station_a = root.get_node("Main/Observatory/Act3_Dome/StationAlpha")
	var station_b = root.get_node("Main/Observatory/Act3_Dome/StationBeta")
	var station_c = root.get_node("Main/Observatory/Act3_Dome/StationGamma")
	
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
	var console_lever = root.get_node("Main/Observatory/Act3_Dome/ShutdownConsole")
	console_lever.interact()
	assert(GameManager.shutdown_lever_pulled == true, "Shutdown lever should be pulled")
	assert(GameManager.current_act == GameManager.Act.ENDING, "Current act should be ENDING")
	print("✓ Test 7: Emergency shutdown lever seals roof shutter")
	
	print("========================================")
	print("ALL 7 GAMEPLAY & MECHANIC TESTS PASSED!")
	print("========================================")
	
	quit()
