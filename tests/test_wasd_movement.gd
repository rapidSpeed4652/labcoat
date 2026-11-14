extends SceneTree
func _init():
    print("=== TESTING WASD MOVEMENT ===")
    var main = load("res://scenes/main.tscn").instantiate()
    root.add_child(main)
    
    await create_timer(0.1).timeout
    
    var player = root.get_node("Main/Player")
    assert(player != null, "Player must exist")
    var start_pos = player.global_position
    print("Start position: ", start_pos)
    
    # Simulate W key press (keycode W)
    var ev_w = InputEventKey.new()
    ev_w.keycode = KEY_W
    ev_w.pressed = true
    Input.parse_input_event(ev_w)
    Input.flush_buffered_events()
    
    # Process physics frames
    for i in range(15):
        player._physics_process(0.016)
    
    var end_pos = player.global_position
    print("End position after W pressed: ", end_pos)
    var moved_dist = start_pos.distance_to(end_pos)
    print("Distance moved forward: ", moved_dist)
    assert(moved_dist > 0.1, "Player MUST move forward when W is pressed!")
    print("✓ PASSED: W key successfully triggers player movement!")
    
    quit()
