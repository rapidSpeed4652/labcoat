extends CharacterBody3D

@export var max_health: float = 60.0
var health: float = 60.0

@export var move_speed: float = 2.4
@export var sprint_speed: float = 4.2
@export var detection_radius: float = 22.0
@export var close_detection_radius: float = 4.5
@export var can_respawn: bool = true
@export var respawn_time: float = 22.0

var absorb_timer: float = 0.0
var banish_stun_timer: float = 0.0
var halt_timer: float = 0.0
var is_halted: bool = false
var attack_cooldown: float = 0.0
var charge_timer: float = 0.0
var glitch_timer: float = 0.0
var is_banished: bool = false
var is_active: bool = true

var stalk_audio: AudioStreamPlayer3D
var sfx_audio: AudioStreamPlayer3D
var eye_light: OmniLight3D
var health_label: Label3D
var mesh_instance: MeshInstance3D
var shader_mat: ShaderMaterial

var gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity", 9.8)

func _ready():
	add_to_group("ShadowEntity")
	add_to_group("Interactable")
	health = max_health
	_setup_visuals()
	_setup_audio()
	_update_hud()

func _setup_visuals():
	mesh_instance = get_node_or_null("MeshInstance3D")
	eye_light = get_node_or_null("EyeLight")
	health_label = get_node_or_null("HealthLabel")
	
	if mesh_instance and mesh_instance.mesh:
		var orig_mat = mesh_instance.mesh.material
		if orig_mat is ShaderMaterial:
			shader_mat = orig_mat.duplicate()
			mesh_instance.material_override = shader_mat

func _setup_audio():
	stalk_audio = AudioStreamPlayer3D.new()
	var stalk_stream = load("res://assets/audio/entity_stalk.wav")
	if stalk_stream is AudioStreamWAV:
		stalk_stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
	stalk_audio.stream = stalk_stream
	stalk_audio.volume_db = -8.0
	stalk_audio.unit_size = 6.0
	stalk_audio.max_distance = 22.0
	add_child(stalk_audio)
	stalk_audio.play()
	
	sfx_audio = AudioStreamPlayer3D.new()
	sfx_audio.unit_size = 9.0
	sfx_audio.max_distance = 25.0
	add_child(sfx_audio)

func _update_hud():
	if health_label:
		if is_banished:
			health_label.text = "[ANOMALY BANISHED]"
			health_label.modulate = Color(0.2, 1.0, 0.4)
		elif is_halted:
			health_label.text = "[PHOTON STASIS PINNED - HP: %d/%d]" % [int(max(0, health)), int(max_health)]
			health_label.modulate = Color(0.2, 0.9, 1.0)
		elif charge_timer > 0.0:
			var pct = int((charge_timer / 1.8) * 100.0)
			health_label.text = "[! QUANTUM SURGE %d%% - HP: %d]" % [pct, int(max(0, health))]
			health_label.modulate = Color(1.0, 0.25, 0.1)
		else:
			health_label.text = "[VOID PHANTOM: %d/%d HP]" % [int(max(0, health)), int(max_health)]
			health_label.modulate = Color(0.3, 0.85, 1.0)

func _physics_process(delta: float):
	if is_banished or not is_active:
		return
	
	# Light hover gravity
	if not is_on_floor():
		velocity.y -= gravity * 0.4 * delta
	else:
		velocity.y = 0.0
	
	if attack_cooldown > 0.0:
		attack_cooldown = max(0.0, attack_cooldown - delta)
	
	if banish_stun_timer > 0.0:
		banish_stun_timer = max(0.0, banish_stun_timer - delta)
	
	if halt_timer > 0.0:
		halt_timer = max(0.0, halt_timer - delta)
		is_halted = (halt_timer > 0.0)
	else:
		is_halted = false
	
	if absorb_timer > 0.0:
		absorb_timer = max(0.0, absorb_timer - delta * 2.0)
	
	# Update Shader Visual Effects
	if shader_mat:
		shader_mat.set_shader_parameter("absorb_intensity", clamp(absorb_timer / 0.5, 0.0, 1.5))
		shader_mat.set_shader_parameter("banish_intensity", clamp(banish_stun_timer / 0.5, 0.0, 2.0))
	
	_update_hud()
	
	var player = get_tree().get_first_node_in_group("Player")
	if player:
		var dist = global_position.distance_to(player.global_position)
		var has_awareness = false
		
		if dist < close_detection_radius or absorb_timer > 0.05:
			has_awareness = true
		elif dist < detection_radius:
			var space_state = get_world_3d().direct_space_state
			if space_state:
				var from_pos = global_position + Vector3(0, 1.2, 0)
				var to_pos = player.global_position + Vector3(0, 1.5, 0)
				var query = PhysicsRayQueryParameters3D.create(from_pos, to_pos)
				query.exclude = [get_rid(), player.get_rid()]
				query.collision_mask = 1
				var hit = space_state.intersect_ray(query)
				if hit.is_empty():
					has_awareness = true
		
		if has_awareness:
			var target_pos = Vector3(player.global_position.x, global_position.y, player.global_position.z)
			var dir = (target_pos - global_position).normalized()
			var is_player_overheated = (player.laser_system and player.laser_system.is_overheated)
			
			# Hunger surge visuals
			if is_player_overheated:
				if shader_mat:
					shader_mat.set_shader_parameter("surge_color", Color(1.0, 0.15, 0.1, 1.0))
				if eye_light:
					eye_light.light_color = Color(1.0, 0.15, 0.1, 1.0)
			else:
				if shader_mat:
					shader_mat.set_shader_parameter("surge_color", Color(1.0, 0.15, 0.1, 0.0))
				if eye_light:
					eye_light.light_color = Color(0.1, 0.85, 1.0, 1.0)
			
			# Psychological Phase Glitch: When player looks away, teleport closer!
			var cam = player.get_node_or_null("Camera3D")
			if cam and dist > 5.5 and dist < 18.0 and not is_halted:
				var cam_fwd = -cam.global_transform.basis.z.normalized()
				var to_ent = (global_position - player.global_position).normalized()
				var dot = cam_fwd.dot(to_ent)
				if dot < 0.2: # Player is facing away
					glitch_timer += delta
					if glitch_timer >= 2.8:
						glitch_timer = 0.0
						_perform_phase_glitch(dir, player)
				else:
					glitch_timer = max(0.0, glitch_timer - delta)
			
			if not is_halted and banish_stun_timer <= 0.0:
				if dist > 2.5:
					charge_timer = 0.0
					var cur_speed = sprint_speed if is_player_overheated else move_speed
					velocity.x = dir.x * cur_speed
					velocity.z = dir.z * cur_speed
				else:
					velocity.x = 0.0
					velocity.z = 0.0
					if attack_cooldown <= 0.0:
						charge_timer += delta
						if charge_timer >= 1.6:
							_discharge_attack(player)
			else:
				velocity.x = 0.0
				velocity.z = 0.0
			
			if global_position.distance_squared_to(target_pos) > 0.1 and not is_halted:
				look_at(target_pos, Vector3.UP)
		else:
			charge_timer = 0.0
			velocity.x = move_toward(velocity.x, 0.0, delta * 3.0)
			velocity.z = move_toward(velocity.z, 0.0, delta * 3.0)
	
	move_and_slide()

func _perform_phase_glitch(dir: Vector3, player: Node):
	var teleport_step = 3.5
	var dest = global_position + dir * teleport_step
	var space_state = get_world_3d().direct_space_state
	if space_state:
		var q = PhysicsRayQueryParameters3D.create(global_position + Vector3(0, 1.0, 0), dest + Vector3(0, 1.0, 0))
		q.exclude = [get_rid(), player.get_rid()]
		q.collision_mask = 1
		var hit = space_state.intersect_ray(q)
		if hit.is_empty():
			global_position = dest
			AudioManager.play_sfx("entity_glitch", randf_range(0.9, 1.2), 3.0)
			# Brief glitch flicker tween
			var tween = create_tween()
			tween.tween_property(self, "scale", Vector3(1.3, 0.8, 1.3), 0.08)
			tween.tween_property(self, "scale", Vector3(1.0, 1.0, 1.0), 0.08)

func on_laser_hit(is_reflected: bool, delta: float):
	if is_banished:
		return
	
	charge_timer = 0.0
	halt_timer = 0.5
	is_halted = true
	
	var time_step = max(0.016, delta)
	
	if not is_reflected:
		# Direct beam does ZERO damage! Only holds in photon stasis / feeds raw photons
		absorb_timer = 0.6
		if not sfx_audio.playing:
			sfx_audio.stream = load("res://assets/audio/entity_absorb.wav")
			sfx_audio.play()
	else:
		# Reflected beam: CRITICAL PHASE INVERSION! Burns away the silhouette!
		var dmg = 250.0 * time_step
		health -= dmg
		banish_stun_timer = 0.6
		if not sfx_audio.playing or sfx_audio.stream.resource_path.ends_with("absorb.wav"):
			sfx_audio.stream = load("res://assets/audio/entity_banish.wav")
			sfx_audio.play()
	
	_update_hud()
	
	if health <= 0.0:
		banish()

func banish():
	if is_banished:
		return
	is_banished = true
	health = 0.0
	velocity = Vector3.ZERO
	_update_hud()
	AudioManager.play_sfx("entity_banish", 1.2, 5.0)
	
	if can_respawn and GameManager.has_method("schedule_entity_respawn"):
		GameManager.schedule_entity_respawn(global_position, respawn_time)
	
	# Death explosion pop
	var tween = create_tween()
	tween.tween_property(self, "scale", Vector3(2.0, 0.1, 2.0), 0.25)
	tween.tween_callback(queue_free)

func _discharge_attack(player: Node):
	charge_timer = 0.0
	attack_cooldown = 2.5
	AudioManager.play_sfx("entity_absorb", 1.4, 5.0)
	
	var knock_dir = (player.global_position - global_position).normalized()
	if knock_dir.length_squared() < 0.01:
		knock_dir = -global_transform.basis.z
	
	if player.has_method("take_damage"):
		player.take_damage(25.0, knock_dir)
	else:
		GameManager.player_died()

func get_category_badge() -> String:
	return "👁 [VOID PHANTOM: BOÖTES SILHOUETTE - %d HP]" % int(max(0, health))

func get_category_color() -> Color:
	return Color(0.2, 0.85, 1.0)

func get_interaction_prompt() -> String:
	return "DIRECT BEAM STUNS • BOUNCE OFF MIRRORS TO VAPORIZE!"

func get_hint() -> String:
	return "Raw coherent light is absorbed, pinning the phantom with photon pressure. Bouncing light off mirrors inverts its quantum phase and dissolves it!"
