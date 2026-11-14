extends CharacterBody3D

@export var walk_speed: float = 4.8
@export var sprint_speed: float = 7.5
@export var acceleration: float = 18.0
@export var friction: float = 22.0
@export var jump_velocity: float = 4.5
@export var mouse_sensitivity: float = 0.0022

var gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity", 9.8)

@onready var camera: Camera3D = $Camera3D
@onready var laser_mount: Node3D = $Camera3D/LaserMount
@onready var laser_system: Node3D = $Camera3D/LaserMount/LaserSystem
@onready var gun_mesh: MeshInstance3D = $Camera3D/LaserMount/GunBody
@onready var portable_mirror_scene = preload("res://scenes/portable_mirror.tscn")

var default_cam_y: float = 1.6
var bob_timer: float = 0.0
var sway_offset: Vector2 = Vector2.ZERO
var footstep_distance: float = 0.0
var step_interval: float = 2.0
var is_sprinting: bool = false
var checkpoint_pos: Vector3 = Vector3.ZERO

# Targeted interactable
var current_interactable: Node = null

func _ready():
	add_to_group("Player")
	floor_snap_length = 0.35
	floor_constant_speed = true
	floor_max_angle = deg_to_rad(45.0)
	
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	checkpoint_pos = global_position
	default_cam_y = camera.position.y
	
	GameManager.player_respawn_requested.connect(respawn_at_checkpoint)
	_update_gun_visibility()

func _unhandled_input(event: InputEvent):
	# Recapture mouse on click
	if event is InputEventMouseButton and event.pressed:
		if Input.mouse_mode != Input.MOUSE_MODE_CAPTURED and not get_tree().paused and not GameManager.is_inspecting_polaroid:
			Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
			get_viewport().set_input_as_handled()
			return

func _input(event: InputEvent):
	if GameManager.is_inspecting_polaroid:
		if event.is_action_pressed("interact") or event.is_action_pressed("pause") or event.is_action_pressed("fire_laser"):
			GameManager.close_polaroid()
		return
	
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		var mouse_x = -event.relative.x * mouse_sensitivity
		var mouse_y = -event.relative.y * mouse_sensitivity
		rotate_y(mouse_x)
		camera.rotate_x(mouse_y)
		camera.rotation.x = clamp(camera.rotation.x, deg_to_rad(-85), deg_to_rad(85))
		
		# Weapon sway target
		sway_offset.x = clamp(sway_offset.x - event.relative.x * 0.0008, -0.04, 0.04)
		sway_offset.y = clamp(sway_offset.y - event.relative.y * 0.0008, -0.04, 0.04)
	
	if event.is_action_pressed("fire_laser"):
		if laser_system and GameManager.has_laser:
			laser_system.set_firing(true)
	elif event.is_action_released("fire_laser"):
		if laser_system:
			laser_system.set_firing(false)
	
	if event.is_action_pressed("place_mirror"):
		_try_place_portable_mirror()
	
	if event.is_action_pressed("interact"):
		_try_interact()
	
	if event.is_action_pressed("restart"):
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
		velocity.y = -0.5 # downward stickiness
		if Input.is_action_just_pressed("jump"):
			velocity.y = jump_velocity
	
	# Sprint check
	is_sprinting = Input.is_action_pressed("sprint")
	var current_target_speed = sprint_speed if is_sprinting else walk_speed
	
	# Movement input
	var input_dir = Input.get_vector("move_left", "move_right", "move_forward", "move_backward")
	var direction = (transform.basis * Vector3(input_dir.x, 0, input_dir.y)).normalized()
	
	if direction != Vector3.ZERO:
		var target_vel = direction * current_target_speed
		velocity.x = move_toward(velocity.x, target_vel.x, acceleration * delta * current_target_speed)
		velocity.z = move_toward(velocity.z, target_vel.z, acceleration * delta * current_target_speed)
		
		# Head bobbing & footsteps
		if is_on_floor():
			var h_speed = Vector2(velocity.x, velocity.z).length()
			bob_timer += delta * (h_speed * 2.4)
			camera.position.y = default_cam_y + sin(bob_timer) * 0.035
			
			footstep_distance += h_speed * delta
			var required_step = step_interval * (0.75 if is_sprinting else 1.0)
			if footstep_distance >= required_step:
				footstep_distance = 0.0
				AudioManager.play_sfx("footstep", randf_range(0.9, 1.1), -4.0)
	else:
		velocity.x = move_toward(velocity.x, 0.0, friction * delta * current_target_speed)
		velocity.z = move_toward(velocity.z, 0.0, friction * delta * current_target_speed)
		camera.position.y = move_toward(camera.position.y, default_cam_y, delta * 2.0)
	
	move_and_slide()
	_update_weapon_sway(delta)
	_update_interaction_target()

func _update_weapon_sway(delta: float):
	if not laser_mount:
		return
	# Smoothly return sway to center
	sway_offset = sway_offset.lerp(Vector2.ZERO, delta * 8.0)
	var target_pos = Vector3(0.28 + sway_offset.x, -0.22 + sway_offset.y, -0.45)
	laser_mount.position = laser_mount.position.lerp(target_pos, delta * 12.0)

func _update_gun_visibility():
	if laser_mount:
		laser_mount.visible = GameManager.has_laser

func _update_interaction_target():
	var ui = get_tree().get_first_node_in_group("UI")
	current_interactable = null
	
	# Best candidate search in front of player
	var cam_pos = camera.global_position
	var cam_forward = -camera.global_transform.basis.z.normalized()
	var max_reach = 3.2
	var best_dot = 0.6 # within ~50 deg cone
	var best_candidate: Node = null
	var best_dist: float = max_reach
	
	var interactables = get_tree().get_nodes_in_group("Interactable")
	for item in interactables:
		if not is_instance_valid(item):
			continue
		var item_pos = item.global_position
		var to_item = item_pos - cam_pos
		var dist = to_item.length()
		if dist <= max_reach:
			var dot = cam_forward.dot(to_item.normalized())
			if dot > best_dot:
				# Check direct line of sight
				var space_state = get_world_3d().direct_space_state
				var query = PhysicsRayQueryParameters3D.create(cam_pos, item_pos)
				query.exclude = [get_rid()]
				var hit = space_state.intersect_ray(query)
				if hit.is_empty() or hit.collider == item or hit.collider.get_parent() == item:
					if dist < best_dist:
						best_dist = dist
						best_candidate = item
	
	current_interactable = best_candidate
	if ui:
		if current_interactable and current_interactable.has_method("get_interaction_prompt"):
			var prompt = current_interactable.get_interaction_prompt()
			if not prompt.is_empty():
				ui.show_interaction_prompt(prompt)
				return
		ui.hide_interaction_prompt()

func _try_interact():
	if current_interactable and is_instance_valid(current_interactable) and current_interactable.has_method("interact"):
		current_interactable.interact()

func _try_place_portable_mirror():
	if GameManager.portable_mirrors_count <= 0:
		return
	
	var spawn_pos = global_position - global_transform.basis.z * 1.5
	spawn_pos.y = global_position.y
	
	var mirror = portable_mirror_scene.instantiate()
	get_parent().add_child(mirror)
	mirror.global_position = spawn_pos
	mirror.rotation.y = rotation.y + deg_to_rad(45.0)
	
	GameManager.portable_mirrors_count -= 1
	GameManager.mirror_count_changed.emit(GameManager.portable_mirrors_count)
	AudioManager.play_sfx("interact", 1.2)

func respawn_at_checkpoint():
	global_position = checkpoint_pos
	velocity = Vector3.ZERO
	if laser_system:
		laser_system.set_firing(false)
		laser_system.heat = 0.0
		laser_system.is_overheated = false
	GameManager.current_act = GameManager.Act.ACT_1_CONTROL_ROOM if not GameManager.act1_door_unlocked else (GameManager.Act.ACT_3_DOME if GameManager.dome_door_unlocked else GameManager.Act.ACT_2_GALLERY)
