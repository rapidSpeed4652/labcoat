extends CharacterBody3D

@export var walk_speed: float = 4.2
@export var sprint_speed: float = 6.8
@export var jump_velocity: float = 4.0
@export var mouse_sensitivity: float = 0.0025

var gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity", 9.8)

@onready var camera: Camera3D = $Camera3D
@onready var interact_ray: RayCast3D = $Camera3D/InteractRay
@onready var laser_mount: Node3D = $Camera3D/LaserMount
@onready var laser_system: Node3D = $Camera3D/LaserMount/LaserSystem
@onready var portable_mirror_scene = preload("res://scenes/portable_mirror.tscn")

var footstep_distance: float = 0.0
var step_interval: float = 2.2
var is_sprinting: bool = false
var checkpoint_pos: Vector3 = Vector3.ZERO

func _ready():
	add_to_group("Player")
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	checkpoint_pos = global_position
	
	GameManager.player_respawn_requested.connect(respawn_at_checkpoint)
	_update_gun_visibility()

func _input(event: InputEvent):
	if GameManager.is_inspecting_polaroid:
		if event.is_action_pressed("interact") or event.is_action_pressed("pause") or event.is_action_pressed("fire_laser"):
			GameManager.close_polaroid()
		return
	
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		rotate_y(-event.relative.x * mouse_sensitivity)
		camera.rotate_x(-event.relative.y * mouse_sensitivity)
		camera.rotation.x = clamp(camera.rotation.x, deg_to_rad(-85), deg_to_rad(85))
	
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
		return
	
	_update_gun_visibility()
	
	# Gravity
	if not is_on_floor():
		velocity.y -= gravity * delta
	else:
		if Input.is_action_just_pressed("jump"):
			velocity.y = jump_velocity
	
	# Sprint check
	is_sprinting = Input.is_action_pressed("sprint")
	var current_speed = sprint_speed if is_sprinting else walk_speed
	
	# Input direction
	var input_dir = Input.get_vector("move_left", "move_right", "move_forward", "move_backward")
	var direction = (transform.basis * Vector3(input_dir.x, 0, input_dir.y)).normalized()
	
	if direction != Vector3.ZERO:
		velocity.x = direction.x * current_speed
		velocity.z = direction.z * current_speed
		
		# Head bobbing & footstep audio
		if is_on_floor():
			var dist = velocity.length() * delta
			footstep_distance += dist
			if footstep_distance >= (step_interval * (0.7 if is_sprinting else 1.0)):
				footstep_distance = 0.0
				AudioManager.play_sfx("footstep", randf_range(0.9, 1.1), -4.0)
	else:
		velocity.x = move_toward(velocity.x, 0.0, current_speed * delta * 8.0)
		velocity.z = move_toward(velocity.z, 0.0, current_speed * delta * 8.0)
	
	move_and_slide()
	_check_interaction_prompt()

func _update_gun_visibility():
	if laser_mount:
		laser_mount.visible = GameManager.has_laser

func _check_interaction_prompt():
	if not interact_ray:
		return
	
	var ui = get_tree().get_first_node_in_group("UI")
	if not ui:
		return
	
	if interact_ray.is_colliding():
		var col = interact_ray.get_collider()
		var interactable = col if col.is_in_group("Interactable") else (col.get_parent() if col.get_parent() and col.get_parent().is_in_group("Interactable") else null)
		if interactable and interactable.has_method("get_interaction_prompt"):
			var prompt_text = interactable.get_interaction_prompt()
			ui.show_interaction_prompt(prompt_text)
			return
	
	ui.hide_interaction_prompt()

func _try_interact():
	if not interact_ray or not interact_ray.is_colliding():
		return
	
	var col = interact_ray.get_collider()
	var interactable = col if col.is_in_group("Interactable") else (col.get_parent() if col.get_parent() and col.get_parent().is_in_group("Interactable") else null)
	if interactable and interactable.has_method("interact"):
		interactable.interact()

func _try_place_portable_mirror():
	if GameManager.portable_mirrors_count <= 0:
		return
	
	var spawn_pos = global_position - global_transform.basis.z * 1.5
	spawn_pos.y = global_position.y - 0.7
	
	var mirror = portable_mirror_scene.instantiate()
	get_parent().add_child(mirror)
	mirror.global_position = spawn_pos
	
	# Angle mirror at 45 degrees relative to camera look
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
