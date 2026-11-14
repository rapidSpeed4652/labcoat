extends CharacterBody3D

@export var walk_speed: float = 4.4
@export var sprint_speed: float = 6.8
@export var acceleration: float = 24.0
@export var friction: float = 28.0
@export var jump_velocity: float = 4.2
@export var mouse_sensitivity: float = 0.002

var gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity", 9.8)

@onready var camera: Camera3D = $Camera3D
@onready var laser_mount: Node3D = $Camera3D/LaserMount
@onready var laser_system: Node3D = $Camera3D/LaserMount/LaserSystem
@onready var portable_mirror_scene = preload("res://scenes/portable_mirror.tscn")

var default_gun_pos: Vector3 = Vector3(0.28, -0.22, -0.45)
var weapon_bob_timer: float = 0.0
var sway_offset: Vector2 = Vector2.ZERO
var footstep_distance: float = 0.0
var step_interval: float = 2.2
var is_sprinting: bool = false
var checkpoint_pos: Vector3 = Vector3.ZERO

# Health & Survival
var health: float = 100.0
var max_health: float = 100.0
var time_since_damage: float = 0.0

signal health_changed(current_health: float, maximum_health: float)

# Targeted interactable
var current_interactable: Node = null

func _ready():
	add_to_group("Player")
	floor_snap_length = 0.4
	floor_constant_speed = true
	floor_max_angle = deg_to_rad(45.0)
	
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	checkpoint_pos = global_position
	
	GameManager.player_respawn_requested.connect(respawn_at_checkpoint)
	_update_gun_visibility()

func _unhandled_input(event: InputEvent):
	# Recapture mouse on any click inside window
	if event is InputEventMouseButton and event.pressed:
		if Input.mouse_mode != Input.MOUSE_MODE_CAPTURED and not get_tree().paused and not GameManager.is_inspecting_polaroid:
			Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
			get_viewport().set_input_as_handled()
			return

func _input(event: InputEvent):
	if GameManager.is_inspecting_polaroid:
		if event.is_action_pressed("interact") or event.is_action_pressed("pause") or event.is_action_pressed("fire_laser"):
			GameManager.close_polaroid()
		elif event is InputEventKey and event.pressed and (event.keycode == KEY_E or event.keycode == KEY_ESCAPE or event.physical_keycode == KEY_E):
			GameManager.close_polaroid()
		return
	
	# Mouse look: rock solid pitch & yaw with zero drift
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		var mouse_x = event.relative.x * mouse_sensitivity
		var mouse_y = event.relative.y * mouse_sensitivity
		
		# Yaw on player body
		rotate_y(-mouse_x)
		
		# Pitch directly on camera rotation.x
		camera.rotation.x = clamp(camera.rotation.x - mouse_y, deg_to_rad(-85.0), deg_to_rad(85.0))
		
		# Weapon lag sway
		sway_offset.x = clamp(sway_offset.x - mouse_x * 0.15, -0.03, 0.03)
		sway_offset.y = clamp(sway_offset.y - mouse_y * 0.15, -0.03, 0.03)
	
	if event.is_action_pressed("fire_laser"):
		if laser_system and GameManager.has_laser:
			laser_system.set_firing(true)
	elif event.is_action_released("fire_laser"):
		if laser_system:
			laser_system.set_firing(false)
	
	if event.is_action_pressed("place_mirror") or (event is InputEventKey and event.pressed and (event.keycode == KEY_Q or event.physical_keycode == KEY_Q)):
		_try_place_portable_mirror()
	
	if event.is_action_pressed("interact") or (event is InputEventKey and event.pressed and (event.keycode == KEY_E or event.keycode == KEY_F or event.physical_keycode == KEY_E or event.physical_keycode == KEY_F)):
		_try_interact()
	
	if event.is_action_pressed("restart") or (event is InputEventKey and event.pressed and (event.keycode == KEY_R or event.physical_keycode == KEY_R)):
		GameManager.restart_checkpoint()

func _physics_process(delta: float):
	if GameManager.is_inspecting_polaroid:
		if laser_system:
			laser_system.set_firing(false)
		velocity = Vector3.ZERO
		return
	
	_update_gun_visibility()
	
	# Gravity & Ground Snapping
	if not is_on_floor():
		velocity.y -= gravity * delta
	else:
		velocity.y = -0.5 # downward stickiness to prevent ground bounce
		var jump_triggered = Input.is_action_just_pressed("jump") or Input.is_key_pressed(KEY_SPACE) or Input.is_physical_key_pressed(KEY_SPACE)
		if jump_triggered:
			velocity.y = jump_velocity
	
	# Health regeneration after delay
	time_since_damage += delta
	if time_since_damage > 4.5 and health < max_health and health > 0.0:
		health = min(max_health, health + delta * 25.0)
		health_changed.emit(health, max_health)

	# Sprint check with direct hardware fallback
	is_sprinting = Input.is_action_pressed("sprint") or Input.is_key_pressed(KEY_SHIFT) or Input.is_physical_key_pressed(KEY_SHIFT)
	var target_speed = sprint_speed if is_sprinting else walk_speed
	
	# Movement input with direct hardware WASD fallback
	var input_dir = Input.get_vector("move_left", "move_right", "move_forward", "move_backward")
	if input_dir == Vector2.ZERO:
		var left = 1.0 if (Input.is_key_pressed(KEY_A) or Input.is_physical_key_pressed(KEY_A) or Input.is_key_pressed(KEY_LEFT)) else 0.0
		var right = 1.0 if (Input.is_key_pressed(KEY_D) or Input.is_physical_key_pressed(KEY_D) or Input.is_key_pressed(KEY_RIGHT)) else 0.0
		var fwd = 1.0 if (Input.is_key_pressed(KEY_W) or Input.is_physical_key_pressed(KEY_W) or Input.is_key_pressed(KEY_UP)) else 0.0
		var back = 1.0 if (Input.is_key_pressed(KEY_S) or Input.is_physical_key_pressed(KEY_S) or Input.is_key_pressed(KEY_DOWN)) else 0.0
		input_dir = Vector2(right - left, back - fwd)
	
	var direction = (transform.basis * Vector3(input_dir.x, 0, input_dir.y)).normalized()
	
	if direction != Vector3.ZERO:
		var target_vel = direction * target_speed
		velocity.x = move_toward(velocity.x, target_vel.x, acceleration * delta * target_speed)
		velocity.z = move_toward(velocity.z, target_vel.z, acceleration * delta * target_speed)
		
		# Footsteps & weapon bob
		if is_on_floor():
			var h_speed = Vector2(velocity.x, velocity.z).length()
			weapon_bob_timer += delta * (h_speed * 2.5)
			
			footstep_distance += h_speed * delta
			var required_step = step_interval * (0.75 if is_sprinting else 1.0)
			if footstep_distance >= required_step:
				footstep_distance = 0.0
				AudioManager.play_sfx("footstep", randf_range(0.9, 1.1), -5.0)
	else:
		velocity.x = move_toward(velocity.x, 0.0, friction * delta * target_speed)
		velocity.z = move_toward(velocity.z, 0.0, friction * delta * target_speed)
		weapon_bob_timer = move_toward(weapon_bob_timer, 0.0, delta * 3.0)
	
	move_and_slide()
	_update_weapon_sway_and_bob(delta)
	_update_interaction_target()

func _update_weapon_sway_and_bob(delta: float):
	if not laser_mount:
		return
	sway_offset = sway_offset.lerp(Vector2.ZERO, delta * 10.0)
	var bob_x = cos(weapon_bob_timer * 0.5) * 0.015
	var bob_y = sin(weapon_bob_timer) * 0.018
	var target_mount_pos = default_gun_pos + Vector3(sway_offset.x + bob_x, sway_offset.y + bob_y, 0.0)
	laser_mount.position = laser_mount.position.lerp(target_mount_pos, delta * 14.0)

func _update_gun_visibility():
	if laser_mount:
		laser_mount.visible = GameManager.has_laser

func _update_interaction_target():
	var ui = get_tree().get_first_node_in_group("UI")
	current_interactable = null
	
	var cam_pos = camera.global_position
	var cam_forward = -camera.global_transform.basis.z.normalized()
	var max_reach = 3.4
	var best_dot = 0.55
	var best_candidate: Node = null
	var best_dist: float = max_reach
	
	var interactables = get_tree().get_nodes_in_group("Interactable")
	for item in interactables:
		if not is_instance_valid(item):
			continue
		var item_pos = item.global_position
		var center_pos = item_pos
		var mesh_child = item.get_node_or_null("MeshInstance3D")
		if mesh_child:
			center_pos = mesh_child.global_position
			
		var to_item = center_pos - cam_pos
		var dist = to_item.length()
		if dist <= max_reach:
			var dot = cam_forward.dot(to_item.normalized())
			if dot > best_dot:
				var space_state = get_world_3d().direct_space_state
				var query = PhysicsRayQueryParameters3D.create(cam_pos, center_pos)
				query.exclude = [get_rid()]
				var hit = space_state.intersect_ray(query)
				if hit.is_empty() or hit.collider == item or hit.collider.get_parent() == item:
					if dist < best_dist:
						best_dist = dist
						best_candidate = item
	
	current_interactable = best_candidate
	if ui and ui.has_method("set_targeted_object"):
		ui.set_targeted_object(current_interactable)

func _try_interact():
	if current_interactable and is_instance_valid(current_interactable) and current_interactable.has_method("interact"):
		current_interactable.interact()

func _try_place_portable_mirror():
	if GameManager.portable_mirrors_count <= 0:
		return
	
	var spawn_pos = global_position - global_transform.basis.z * 1.6
	spawn_pos.y = global_position.y
	
	var mirror = portable_mirror_scene.instantiate()
	get_parent().add_child(mirror)
	mirror.global_position = spawn_pos
	mirror.rotation.y = rotation.y + deg_to_rad(45.0)
	
	GameManager.portable_mirrors_count -= 1
	GameManager.mirror_count_changed.emit(GameManager.portable_mirrors_count)
	AudioManager.play_sfx("interact", 1.2)

func take_damage(amount: float, knockback_dir: Vector3 = Vector3.ZERO):
	if health <= 0.0:
		return
	health = max(0.0, health - amount)
	time_since_damage = 0.0
	
	if knockback_dir != Vector3.ZERO:
		velocity += knockback_dir * 7.5
		velocity.y = 2.0
	
	AudioManager.play_sfx("entity_absorb", 0.75, 4.0)
	health_changed.emit(health, max_health)
	
	var ui = get_tree().get_first_node_in_group("UI")
	if ui and ui.has_method("flash_damage"):
		ui.flash_damage()
	
	if health <= 0.0:
		GameManager.player_died()

func respawn_at_checkpoint():
	health = max_health
	time_since_damage = 0.0
	health_changed.emit(health, max_health)
	global_position = checkpoint_pos
	velocity = Vector3.ZERO
	if laser_system:
		laser_system.set_firing(false)
		laser_system.heat = 0.0
		laser_system.is_overheated = false
	GameManager.current_act = GameManager.Act.ACT_1_CONTROL_ROOM if not GameManager.act1_door_unlocked else (GameManager.Act.ACT_3_DOME if GameManager.dome_door_unlocked else GameManager.Act.ACT_2_GALLERY)
