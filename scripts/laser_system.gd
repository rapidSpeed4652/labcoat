extends Node3D

@export var max_bounces: int = 6
@export var max_range: float = 80.0
@export var heat_buildup_rate: float = 0.22 # ~4.5 seconds to 100%
@export var heat_cooldown_rate: float = 0.35
@export var overheat_lockout_time: float = 3.0

# Physical Optical Path Tracing Constants
const WAVELENGTH_NM: float = 488.0 # Argon-ion laser (Cyan)
const BEAM_WAIST_0: float = 0.016 # Initial beam radius in meters
const AIR_EXTINCTION_COEFF: float = 0.014 # Beer-Lambert extinction in dusty air
const FRESNEL_R0_GLASS: float = 0.043 # Crown glass (n = 1.52)
const MIRROR_REFLECTANCE: float = 0.95 # Dielectric-enhanced silver coating

var heat: float = 0.0
var is_overheated: bool = false
var overheat_timer: float = 0.0
var is_firing: bool = false

var last_mirror_ping_time: float = 0.0
var hum_player: AudioStreamPlayer3D

# Visual Segments Pool (Cylinders for primary path)
var beam_segments: Array[MeshInstance3D] = []
var bounce_lights: Array[OmniLight3D] = []
# Secondary chromatic dispersion fringe segments
var dispersion_segments: Array[MeshInstance3D] = []
const POOL_SIZE: int = 8

var laser_mat_raw: ShaderMaterial
var laser_mat_reflected: ShaderMaterial
var laser_mat_dispersion: ShaderMaterial

signal heat_changed(current_heat: float, is_overheat: bool)
signal laser_fired(is_active: bool)

func _ready():
	_setup_materials()
	_setup_pool()
	_setup_hum_audio()

func _setup_materials():
	var shader = load("res://assets/shaders/laser_beam.gdshader")
	
	# Primary Coherent Beam (Raw Unreflected - Cyan 488nm)
	laser_mat_raw = ShaderMaterial.new()
	laser_mat_raw.shader = shader
	laser_mat_raw.set_shader_parameter("laser_color", Color(0.0, 0.85, 1.0, 1.0))
	laser_mat_raw.set_shader_parameter("core_color", Color(0.9, 0.98, 1.0, 1.0))
	laser_mat_raw.set_shader_parameter("intensity", 4.0)
	
	# Reflected Beam (Phase-Inverted Optical Bounce - Emerald/Cyan 505nm)
	laser_mat_reflected = ShaderMaterial.new()
	laser_mat_reflected.shader = shader
	laser_mat_reflected.set_shader_parameter("laser_color", Color(0.2, 1.0, 0.65, 1.0))
	laser_mat_reflected.set_shader_parameter("core_color", Color(1.0, 1.0, 1.0, 1.0))
	laser_mat_reflected.set_shader_parameter("intensity", 5.5)
	
	# Chromatic Dispersion Fringe Ray (Prismatic violet/red fringe)
	laser_mat_dispersion = ShaderMaterial.new()
	laser_mat_dispersion.shader = shader
	laser_mat_dispersion.set_shader_parameter("laser_color", Color(0.8, 0.2, 1.0, 0.7))
	laser_mat_dispersion.set_shader_parameter("core_color", Color(1.0, 0.4, 0.8, 0.9))
	laser_mat_dispersion.set_shader_parameter("intensity", 2.2)

func _setup_pool():
	for i in range(POOL_SIZE):
		# Primary path-traced beam cylinder
		var mesh_inst = MeshInstance3D.new()
		var cyl = CylinderMesh.new()
		cyl.top_radius = BEAM_WAIST_0
		cyl.bottom_radius = BEAM_WAIST_0
		cyl.height = 1.0
		mesh_inst.mesh = cyl
		mesh_inst.visible = false
		mesh_inst.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(mesh_inst)
		beam_segments.append(mesh_inst)
		
		# Secondary Chromatic Dispersion Fringe segment
		var disp_mesh = MeshInstance3D.new()
		var disp_cyl = CylinderMesh.new()
		disp_cyl.top_radius = BEAM_WAIST_0 * 0.6
		disp_cyl.bottom_radius = BEAM_WAIST_0 * 0.6
		disp_cyl.height = 1.0
		disp_mesh.mesh = disp_cyl
		disp_mesh.visible = false
		disp_mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(disp_mesh)
		dispersion_segments.append(disp_mesh)
		
		# Indirect diffuse bounce & volumetric scatter light
		var light = OmniLight3D.new()
		light.light_color = Color(0.1, 0.9, 1.0)
		light.light_energy = 2.5
		light.omni_range = 4.0
		light.shadow_enabled = false
		# Volumetric fog interaction for true beam scatter
		light.light_volumetric_fog_energy = 2.0
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
	
	if is_firing and not is_overheated and GameManager.has_laser:
		heat += heat_buildup_rate * delta
		if heat >= 1.0:
			heat = 1.0
			is_overheated = true
			overheat_timer = overheat_lockout_time
			is_firing = false
			_stop_hum()
			AudioManager.play_sfx("laser_overheat")
			heat_changed.emit(heat, is_overheated)
			_hide_beam()
			return
		
		_trace_optical_path(delta)
		if not hum_player.playing:
			hum_player.play()
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
	for d in dispersion_segments:
		d.visible = false
	for l in bounce_lights:
		l.visible = false

# =========================================================
# REAL-TIME OPTICAL PATH TRACING & RADIATIVE TRANSFER
# =========================================================
func _trace_optical_path(delta: float):
	var space_state = get_world_3d().direct_space_state
	if not space_state:
		return
	
	var player = get_tree().get_first_node_in_group("Player")
	var exclude_rids = []
	if player:
		exclude_rids.append(player.get_rid())
	
	# 1. Primary Camera Convergence Ray
	var cam = get_viewport().get_camera_3d()
	var aim_target: Vector3
	if cam:
		var cam_pos = cam.global_position
		var cam_dir = -cam.global_transform.basis.z.normalized()
		var cam_query = PhysicsRayQueryParameters3D.create(cam_pos, cam_pos + cam_dir * max_range)
		cam_query.exclude = exclude_rids
		cam_query.collide_with_areas = true
		cam_query.collide_with_bodies = true
		var cam_hit = space_state.intersect_ray(cam_query)
		if not cam_hit.is_empty():
			aim_target = cam_hit.position
		else:
			aim_target = cam_pos + cam_dir * max_range
	else:
		aim_target = global_position - global_transform.basis.z * max_range
	
	# 2. Path Tracing State Initialization
	var current_origin = global_position
	var current_dir = (aim_target - current_origin).normalized()
	var bounce = 0
	var is_reflected = false
	var segment_idx = 0
	var cumulative_distance = 0.0
	var current_radiance = 1.0 # Normalized physical radiance L_0
	
	while bounce < max_bounces and segment_idx < POOL_SIZE and current_radiance > 0.05:
		var ray_target = current_origin + current_dir * max_range
		var query = PhysicsRayQueryParameters3D.create(current_origin, ray_target)
		query.exclude = exclude_rids
		query.collide_with_areas = true
		query.collide_with_bodies = true
		
		var hit = space_state.intersect_ray(query)
		
		if hit.is_empty():
			# Beam travels out to max range
			var seg_length = current_origin.distance_to(ray_target)
			cumulative_distance += seg_length
			_render_path_segment(segment_idx, current_origin, ray_target, is_reflected, cumulative_distance, current_radiance)
			segment_idx += 1
			break
		
		var hit_pos = hit.position
		var hit_normal = hit.normal.normalized()
		var collider = hit.collider
		var seg_length = current_origin.distance_to(hit_pos)
		cumulative_distance += seg_length
		
		# Beer-Lambert physical extinction through dusty participating medium
		current_radiance *= exp(-AIR_EXTINCTION_COEFF * seg_length)
		
		# Render the primary beam segment with physical Gaussian divergence
		_render_path_segment(segment_idx, current_origin, hit_pos, is_reflected, cumulative_distance, current_radiance)
		
		# Render path-traced indirect bounce light (diffuse scatter)
		_render_indirect_scatter(segment_idx, hit_pos, hit_normal, is_reflected, current_radiance)
		
		# Check Surface Material Properties for Path Tracing
		if collider.is_in_group("Mirror") or (collider.get_parent() and collider.get_parent().is_in_group("Mirror")):
			# Specular Reflection: Law of Reflection
			var cos_theta = clamp(abs(current_dir.dot(hit_normal)), 0.0, 1.0)
			# Fresnel-Schlick Reflectance approximation
			var fresnel = FRESNEL_R0_GLASS + (1.0 - FRESNEL_R0_GLASS) * pow(1.0 - cos_theta, 5.0)
			var total_reflectance = lerp(fresnel, MIRROR_REFLECTANCE, 0.85)
			current_radiance *= total_reflectance
			
			# Calculate exact specular reflection direction
			var reflected_dir = current_dir.bounce(hit_normal).normalized()
			
			# Secondary Prismatic Chromatic Dispersion Ray
			_render_dispersion_ray(segment_idx, hit_pos, reflected_dir, hit_normal, seg_length * 0.4)
			
			current_dir = reflected_dir
			current_origin = hit_pos + hit_normal * 0.02
			is_reflected = true
			bounce += 1
			
			var now = Time.get_ticks_msec() / 1000.0
			if now - last_mirror_ping_time > 0.35:
				last_mirror_ping_time = now
				AudioManager.play_sfx("mirror_reflect", 1.0 + bounce * 0.15)
			
			segment_idx += 1
			
		elif collider.is_in_group("ShadowEntity") or (collider.get_parent() and collider.get_parent().is_in_group("ShadowEntity")):
			var entity = collider if collider.is_in_group("ShadowEntity") else collider.get_parent()
			if entity.has_method("on_laser_hit"):
				entity.on_laser_hit(is_reflected, delta)
			segment_idx += 1
			break
			
		elif collider.is_in_group("OpticalReceptor") or (collider.get_parent() and collider.get_parent().is_in_group("OpticalReceptor")):
			var receptor = collider if collider.is_in_group("OpticalReceptor") else collider.get_parent()
			if receptor.has_method("on_laser_hit"):
				receptor.on_laser_hit(is_reflected, delta)
			segment_idx += 1
			break
			
		else:
			# Non-specular diffuse boundary: beam terminates in diffuse scatter
			segment_idx += 1
			break
	
	# Hide unused segments in pool
	for i in range(segment_idx, POOL_SIZE):
		beam_segments[i].visible = false
		dispersion_segments[i].visible = false
		bounce_lights[i].visible = false

# =========================================================
# PHYSICAL BEAM DIVERGENCE & RADIANCE RENDERING
# =========================================================
func _render_path_segment(idx: int, p_from: Vector3, p_to: Vector3, reflected: bool, total_dist: float, radiance: float):
	if idx >= beam_segments.size():
		return
	var seg = beam_segments[idx]
	seg.visible = true
	
	var length = p_from.distance_to(p_to)
	if length < 0.01:
		seg.visible = false
		return
	
	# Gaussian Beam Divergence w(z) = w_0 * sqrt(1 + (z/z_R)^2)
	var z_ratio = total_dist / 35.0
	var physical_radius = BEAM_WAIST_0 * sqrt(1.0 + z_ratio * z_ratio)
	
	var mesh = seg.mesh as CylinderMesh
	if mesh:
		mesh.height = length
		mesh.top_radius = physical_radius
		mesh.bottom_radius = physical_radius * 0.95
	
	seg.global_position = (p_from + p_to) * 0.5
	var dir = (p_to - p_from).normalized()
	var up = Vector3.UP
	if abs(dir.dot(up)) > 0.99:
		up = Vector3.RIGHT
	seg.look_at(seg.global_position + dir, up)
	seg.rotate_object_local(Vector3.RIGHT, deg_to_rad(90))
	
	# Apply material with physical radiance intensity
	var mat = laser_mat_reflected if reflected else laser_mat_raw
	mat.set_shader_parameter("intensity", (5.5 if reflected else 4.0) * radiance)
	seg.material_override = mat

func _render_dispersion_ray(idx: int, hit_pos: Vector3, reflected_dir: Vector3, normal: Vector3, length: float):
	if idx >= dispersion_segments.size():
		return
	var d_seg = dispersion_segments[idx]
	d_seg.visible = true
	
	# Slightly dispersed chromatic angle (prismatic refraction fringe)
	var cross = reflected_dir.cross(normal).normalized()
	var dispersed_dir = (reflected_dir + cross * 0.04).normalized()
	var end_pos = hit_pos + dispersed_dir * min(length, 4.0)
	
	var dist = hit_pos.distance_to(end_pos)
	var mesh = d_seg.mesh as CylinderMesh
	if mesh:
		mesh.height = dist
	
	d_seg.global_position = (hit_pos + end_pos) * 0.5
	d_seg.look_at(d_seg.global_position + dispersed_dir, Vector3.UP)
	d_seg.rotate_object_local(Vector3.RIGHT, deg_to_rad(90))
	d_seg.material_override = laser_mat_dispersion

func _render_indirect_scatter(idx: int, pos: Vector3, normal: Vector3, reflected: bool, radiance: float):
	if idx >= bounce_lights.size():
		return
	var light = bounce_lights[idx]
	light.visible = true
	# Offset along surface normal for indirect hemispherical scatter
	light.global_position = pos + normal * 0.08
	light.light_color = Color(0.2, 1.0, 0.7) if reflected else Color(0.1, 0.85, 1.0)
	light.light_energy = (3.6 if reflected else 2.2) * radiance
	light.omni_range = 4.5 * radiance
	light.light_volumetric_fog_energy = 2.5 * radiance
