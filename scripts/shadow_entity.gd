extends CharacterBody3D

@export var move_speed: float = 1.6
@export var agitated_speed_mult: float = 1.4
@export var detection_radius: float = 14.0
@export var close_detection_radius: float = 4.0
@export var banish_health: float = 0.4 # Seconds of reflected beam exposure to destroy

var current_banish_time: float = 0.0
var absorb_timer: float = 0.0
var banish_stun_timer: float = 0.0
var attack_cooldown: float = 0.0
var is_banished: bool = false
var is_active: bool = true

var stalk_audio: AudioStreamPlayer3D
var sfx_audio: AudioStreamPlayer3D
var mesh_instance: MeshInstance3D
var entity_mat: ShaderMaterial

var gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity", 9.8)

func _ready():
	add_to_group("ShadowEntity")
	_setup_visuals()
	_setup_audio()

func _setup_visuals():
	mesh_instance = $MeshInstance3D
	var shader = load("res://assets/shaders/shadow_entity.gdshader")
	entity_mat = ShaderMaterial.new()
	entity_mat.shader = shader
	mesh_instance.material_override = entity_mat

func _setup_audio():
	stalk_audio = AudioStreamPlayer3D.new()
	var stalk_stream = load("res://assets/audio/entity_stalk.wav")
	if stalk_stream is AudioStreamWAV:
		stalk_stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
	stalk_audio.stream = stalk_stream
	stalk_audio.volume_db = -6.0
	stalk_audio.unit_size = 6.0
	stalk_audio.max_distance = 25.0
	add_child(stalk_audio)
	stalk_audio.play()
	
	sfx_audio = AudioStreamPlayer3D.new()
	sfx_audio.unit_size = 8.0
	add_child(sfx_audio)

func _physics_process(delta: float):
	if is_banished or not is_active:
		return
	
	# Gravity
	if not is_on_floor():
		velocity.y -= gravity * delta
	else:
		velocity.y = 0.0
	
	# Decay timers
	if attack_cooldown > 0.0:
		attack_cooldown = max(0.0, attack_cooldown - delta)
	
	if banish_stun_timer > 0.0:
		banish_stun_timer = max(0.0, banish_stun_timer - delta)
	
	# Decay absorb flash
	if absorb_timer > 0.0:
		absorb_timer = max(0.0, absorb_timer - delta * 1.8)
		entity_mat.set_shader_parameter("absorb_factor", absorb_timer)
	
	# Slowly recover banish health if laser stops hitting
	if current_banish_time > 0.0 and banish_stun_timer <= 0.0:
		current_banish_time = max(0.0, current_banish_time - delta * 0.35)
		entity_mat.set_shader_parameter("banish_progress", current_banish_time / banish_health)
	
	# Stalk Player with Line-of-Sight and Proximity Hearing
	var player = get_tree().get_first_node_in_group("Player")
	if player:
		var dist = global_position.distance_to(player.global_position)
		var has_awareness = false
		
		# 1. Close proximity hearing in the dark, or agitated by raw beam
		if dist < close_detection_radius or absorb_timer > 0.1:
			has_awareness = true
		elif dist < detection_radius:
			# 2. Line of Sight Raycast check (cannot see through closed solid walls)
			var space_state = get_world_3d().direct_space_state
			if space_state:
				var from_pos = global_position + Vector3(0, 1.8, 0)
				var to_pos = player.global_position + Vector3(0, 1.6, 0)
				var query = PhysicsRayQueryParameters3D.create(from_pos, to_pos)
				query.exclude = [get_rid(), player.get_rid()]
				query.collision_mask = 1 # Environment geometry
				var hit = space_state.intersect_ray(query)
				if hit.is_empty():
					has_awareness = true
		
		if has_awareness:
			var target_pos = Vector3(player.global_position.x, global_position.y, player.global_position.z)
			var dir = (target_pos - global_position).normalized()
			
			var speed = move_speed
			if absorb_timer > 0.1:
				speed *= agitated_speed_mult
			
			# Heavy stun slowdown when actively struck by reflected beam
			if banish_stun_timer > 0.0:
				speed *= 0.15
			
			velocity.x = dir.x * speed
			velocity.z = dir.z * speed
			
			# Face player
			if dir.length() > 0.1:
				look_at(target_pos, Vector3.UP)
			
			# Attack range
			if dist < 1.35 and attack_cooldown <= 0.0 and banish_stun_timer <= 0.0:
				_attack_player(player)
		else:
			velocity.x = move_toward(velocity.x, 0.0, delta * 3.0)
			velocity.z = move_toward(velocity.z, 0.0, delta * 3.0)
	
	move_and_slide()

func on_laser_hit(is_reflected: bool, delta: float):
	if is_banished:
		return
	
	if not is_reflected:
		# RAW UNREFLECTED BEAM: Absorbed! Entity agitates and tracks player!
		absorb_timer = 1.0
		entity_mat.set_shader_parameter("absorb_factor", 1.0)
		if not sfx_audio.playing:
			sfx_audio.stream = load("res://assets/audio/entity_absorb.wav")
			sfx_audio.play()
	else:
		# REFLECTED BEAM: Destructive light! Heavy stun and rapid dissolution!
		banish_stun_timer = 0.35
		current_banish_time += delta
		var progress = clamp(current_banish_time / banish_health, 0.0, 1.0)
		entity_mat.set_shader_parameter("banish_progress", progress)
		
		if not sfx_audio.playing or sfx_audio.stream.resource_path.ends_with("absorb.wav"):
			sfx_audio.stream = load("res://assets/audio/entity_banish.wav")
			sfx_audio.play()
		
		if current_banish_time >= banish_health:
			banish()

func banish():
	if is_banished:
		return
	is_banished = true
	velocity = Vector3.ZERO
	AudioManager.play_sfx("entity_banish", 1.2, 4.0)
	
	# Death dissolve tween
	var tween = create_tween()
	tween.tween_property(self, "scale", Vector3(0.01, 2.5, 0.01), 0.35)
	tween.tween_callback(queue_free)

func _attack_player(player: Node):
	attack_cooldown = 1.6 # Window for player to escape or counter-attack
	AudioManager.play_sfx("entity_absorb", 0.7, 6.0)
	
	var knock_dir = (player.global_position - global_position).normalized()
	if knock_dir.length_squared() < 0.01:
		knock_dir = -global_transform.basis.z
	
	if player.has_method("take_damage"):
		player.take_damage(40.0, knock_dir)
	else:
		GameManager.player_died()
