extends Node3D

@export var max_bounces: int = 6
@export var max_range: float = 80.0
@export var heat_buildup_rate: float = 0.22 # ~4.5 seconds to 100%
@export var heat_cooldown_rate: float = 0.35
@export var overheat_lockout_time: float = 3.0

var heat: float = 0.0
var is_overheated: bool = false
var overheat_timer: float = 0.0
var is_firing: bool = false

var last_mirror_ping_time: float = 0.0
var hum_player: AudioStreamPlayer3D

# Beam visual segments pool
var beam_segments: Array[MeshInstance3D] = []
var bounce_lights: Array[OmniLight3D] = []
const POOL_SIZE: int = 8

var laser_mat_raw: ShaderMaterial
var laser_mat_reflected: ShaderMaterial

signal heat_changed(current_heat: float, is_overheat: bool)
signal laser_fired(is_active: bool)

func _ready():
	_setup_materials()
	_setup_pool()
	_setup_hum_audio()

func _setup_materials():
	var shader = load("res://assets/shaders/laser_beam.gdshader")
	laser_mat_raw = ShaderMaterial.new()
	laser_mat_raw.shader = shader
	laser_mat_raw.set_shader_parameter("laser_color", Color(0.0, 0.8, 1.0, 1.0))
	laser_mat_raw.set_shader_parameter("core_color", Color(0.8, 0.95, 1.0, 1.0))
	laser_mat_raw.set_shader_parameter("intensity", 3.0)
	
	laser_mat_reflected = ShaderMaterial.new()
	laser_mat_reflected.shader = shader
	laser_mat_reflected.set_shader_parameter("laser_color", Color(0.2, 1.0, 0.6, 1.0))
	laser_mat_reflected.set_shader_parameter("core_color", Color(1.0, 1.0, 1.0, 1.0))
	laser_mat_reflected.set_shader_parameter("intensity", 4.5)

func _setup_pool():
	for i in range(POOL_SIZE):
		var mesh_inst = MeshInstance3D.new()
		var cyl = CylinderMesh.new()
		cyl.top_radius = 0.018
		cyl.bottom_radius = 0.018
		cyl.height = 1.0
		mesh_inst.mesh = cyl
		mesh_inst.visible = false
		mesh_inst.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(mesh_inst)
		beam_segments.append(mesh_inst)
		
		var light = OmniLight3D.new()
		light.light_color = Color(0.1, 0.9, 1.0)
		light.light_energy = 2.0
		light.omni_range = 3.5
		light.visible = false
		add_child(light)
		bounce_lights.append(light)

func _setup_hum_audio():
	hum_player = AudioStreamPlayer3D.new()
	var hum_stream = load("res://assets/audio/laser_hum.wav")
	if hum_stream is AudioStreamWAV:
		hum_stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
	hum_player.stream = hum_stream
	hum_player.volume_db = -8.0
	hum_player.unit_size = 5.0
	add_child(hum_player)

func _process(delta: float):
	# Handle Overheating & Cooldown
	if is_overheated:
		overheat_timer -= delta
		heat = overheat_timer / overheat_lockout_time
		if overheat_timer <= 0.0:
			is_overheated = false
			heat = 0.0
			AudioManager.play_sfx("laser_cooldown")
		heat_changed.emit(heat, is_overheated)
		_hide_beam()
		return
	
	# Laser firing state
	if is_firing and not is_overheated and GameManager.has_laser:
		heat += heat_buildup_rate * delta
		if heat >= 1.0:
			# Overheated!
			heat = 1.0
			is_overheated = true
			overheat_timer = overheat_lockout_time
			is_firing = false
			_stop_hum()
			AudioManager.play_sfx("laser_overheat")
			heat_changed.emit(heat, is_overheated)
			_hide_beam()
			return
		
		_cast_beam(delta)
		if not hum_player.playing:
			hum_player.play()
		# Slight pitch increase as heat rises
		hum_player.pitch_scale = 1.0 + (heat * 0.4)
	else:
		heat = max(0.0, heat - heat_cooldown_rate * delta)
		_hide_beam()
		_stop_hum()
	
	heat_changed.emit(heat, is_overheated)

func set_firing(firing: bool):
	if is_overheated or not GameManager.has_laser:
		is_firing = false
		return
	
	if firing != is_firing:
		is_firing = firing
		laser_fired.emit(is_firing)
		if is_firing:
			AudioManager.play_sfx("laser_click")
		else:
			_stop_hum()

func _stop_hum():
	if hum_player and hum_player.playing:
		hum_player.stop()

func _hide_beam():
	for seg in beam_segments:
		seg.visible = false
	for l in bounce_lights:
		l.visible = false

func _cast_beam(delta: float):
	var space_state = get_world_3d().direct_space_state
	if not space_state:
		return
	
	var current_origin = global_position
	var current_dir = -global_transform.basis.z.normalized()
	var bounce = 0
	var is_reflected = false
	var segment_idx = 0
	
	# Exclude player from raycast
	var player = get_tree().get_first_node_in_group("Player")
	var exclude_rids = []
	if player:
		exclude_rids.append(player.get_rid())
	
	while bounce < max_bounces and segment_idx < POOL_SIZE:
		var ray_target = current_origin + current_dir * max_range
		var query = PhysicsRayQueryParameters3D.create(current_origin, ray_target)
		query.exclude = exclude_rids
		query.collide_with_areas = true
		query.collide_with_bodies = true
		
		var hit = space_state.intersect_ray(query)
		
		if hit.is_empty():
			# Reached max distance into void / air
			_render_segment(segment_idx, current_origin, ray_target, is_reflected)
			segment_idx += 1
			break
		
		var hit_pos = hit.position
		var hit_normal = hit.normal
		var collider = hit.collider
		
		_render_segment(segment_idx, current_origin, hit_pos, is_reflected)
		_render_bounce_light(segment_idx, hit_pos, is_reflected)
		segment_idx += 1
		
		# Check collider type
		if collider.is_in_group("Mirror") or (collider.get_parent() and collider.get_parent().is_in_group("Mirror")):
			# Mirror bounce!
			current_dir = current_dir.bounce(hit_normal).normalized()
			current_origin = hit_pos + hit_normal * 0.02
			is_reflected = true
			bounce += 1
			
			var now = Time.get_ticks_msec() / 1000.0
			if now - last_mirror_ping_time > 0.4:
				last_mirror_ping_time = now
				AudioManager.play_sfx("mirror_reflect", 1.0 + bounce * 0.15)
		
		elif collider.is_in_group("ShadowEntity") or (collider.get_parent() and collider.get_parent().is_in_group("ShadowEntity")):
			var entity = collider if collider.is_in_group("ShadowEntity") else collider.get_parent()
			if entity.has_method("on_laser_hit"):
				entity.on_laser_hit(is_reflected, delta)
			break # Absorbed or stopped by entity
		
		elif collider.is_in_group("OpticalReceptor") or (collider.get_parent() and collider.get_parent().is_in_group("OpticalReceptor")):
			var receptor = collider if collider.is_in_group("OpticalReceptor") else collider.get_parent()
			if receptor.has_method("on_laser_hit"):
				receptor.on_laser_hit(is_reflected, delta)
			break
		
		else:
			# Normal wall / non-reflective surface
			break
	
	# Hide unused segments in pool
	for i in range(segment_idx, POOL_SIZE):
		beam_segments[i].visible = false
		bounce_lights[i].visible = false

func _render_segment(idx: int, p_from: Vector3, p_to: Vector3, reflected: bool):
	if idx >= beam_segments.size():
		return
	var seg = beam_segments[idx]
	seg.visible = true
	
	var length = p_from.distance_to(p_to)
	if length < 0.01:
		seg.visible = false
		return
	
	var mesh = seg.mesh as CylinderMesh
	if mesh:
		mesh.height = length
	
	# Center position
	seg.global_position = (p_from + p_to) * 0.5
	
	# Orient cylinder along direction
	var dir = (p_to - p_from).normalized()
	var up = Vector3.UP
	if abs(dir.dot(up)) > 0.99:
		up = Vector3.RIGHT
	seg.look_at(seg.global_position + dir, up)
	# Godot CylinderMesh aligns along Y axis, rotate 90 deg on X to align along Z
	seg.rotate_object_local(Vector3.RIGHT, deg_to_rad(90))
	
	seg.material_override = laser_mat_reflected if reflected else laser_mat_raw

func _render_bounce_light(idx: int, pos: Vector3, reflected: bool):
	if idx >= bounce_lights.size():
		return
	var light = bounce_lights[idx]
	light.visible = true
	light.global_position = pos
	light.light_color = Color(0.2, 1.0, 0.7) if reflected else Color(0.1, 0.85, 1.0)
	light.light_energy = 3.0 if reflected else 1.8
