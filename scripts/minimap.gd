extends Control

const WORLD_CENTER_X: float = 15.5
const WORLD_CENTER_Z: float = -18.0
const WORLD_SPAN_X: float = 44.0
const WORLD_SPAN_Z: float = 58.0

@export var is_fullscreen_map: bool = false

var pulse_time: float = 0.0

func _process(delta: float):
	if is_visible_in_tree():
		pulse_time += delta * 4.0
		queue_redraw()

func world_to_map(world_pos: Vector3) -> Vector2:
	var w = size.x - 20.0
	var h = size.y - 28.0
	var ox = 10.0
	var oy = 20.0
	
	var scale_x = w / WORLD_SPAN_X
	var scale_z = h / WORLD_SPAN_Z
	var s = min(scale_x, scale_z)
	
	var center_canvas = Vector2(ox + w * 0.5, oy + h * 0.5)
	var dx = (world_pos.x - WORLD_CENTER_X) * s
	var dy = (world_pos.z - WORLD_CENTER_Z) * s
	
	return center_canvas + Vector2(dx, dy)

func world_rect_to_map(x1: float, z1: float, x2: float, z2: float) -> Rect2:
	var p1 = world_to_map(Vector3(x1, 0, z1))
	var p2 = world_to_map(Vector3(x2, 0, z2))
	var top_left = Vector2(min(p1.x, p2.x), min(p1.y, p2.y))
	var sz = Vector2(abs(p2.x - p1.x), abs(p2.y - p1.y))
	return Rect2(top_left, sz)

func _draw():
	var bg_col = Color(0.02, 0.05, 0.08, 0.85) if not is_fullscreen_map else Color(0.01, 0.03, 0.06, 0.95)
	draw_rect(Rect2(Vector2.ZERO, size), bg_col, true)
	
	var frame_col = Color(0.15, 0.6, 0.8, 0.7) if not is_fullscreen_map else Color(0.2, 0.85, 0.95, 0.9)
	draw_rect(Rect2(Vector2.ZERO, size), frame_col, false, 2.0)
	
	if not is_fullscreen_map:
		var grid_col = Color(0.1, 0.35, 0.45, 0.25)
		draw_line(Vector2(size.x * 0.5, 0), Vector2(size.x * 0.5, size.y), grid_col, 1.0)
		draw_line(Vector2(0, size.y * 0.5), Vector2(size.x, size.y * 0.5), grid_col, 1.0)
		draw_arc(size * 0.5, size.x * 0.4, 0, TAU, 32, grid_col, 1.0)
	
	var room_fill = Color(0.06, 0.18, 0.25, 0.6)
	var room_border = Color(0.2, 0.75, 0.9, 0.8)
	var rooms = [
		["CONTROL", -6.0, -6.0, 6.0, 6.0],
		["LRRR SITE", -6.0, -14.0, 6.0, -7.0],
		["H1", 6.0, -2.0, 24.0, 2.0],
		["CLEANROOM", 26.0, -4.0, 35.0, 0.0],
		["BAY-A (CRYO)", 11.0, 2.0, 19.0, 10.0],
		["H2", 22.0, -16.0, 26.0, 0.0],
		["ARCHIVE", 13.0, -16.0, 22.0, -12.0],
		["BAY-B (FLUX)", 13.0, -12.0, 22.0, -4.0],
		["BAY-C (OSC)", 26.0, -12.0, 35.0, -4.0],
		["VESTIBULE", 22.0, -18.0, 26.0, -16.0],
		["COUDÉ DOME", 10.0, -46.0, 38.0, -18.0],
		["EXIT", 0.0, -34.0, 10.0, -30.0]
	]
	
	for r in rooms:
		var rect = world_rect_to_map(r[1], r[2], r[3], r[4])
		draw_rect(rect, room_fill, true)
		draw_rect(rect, room_border, false, 1.5)
		
		if is_fullscreen_map:
			var font = ThemeDB.fallback_font
			var font_size = 11
			var text = r[0]
			var text_pos = rect.position + rect.size * 0.5 - Vector2(text.length() * 3.0, -4.0)
			draw_string(font, text_pos, text, HORIZONTAL_ALIGNMENT_CENTER, -1, font_size, Color(0.6, 0.9, 1.0, 0.75))
	
	var act1_door_pos = world_to_map(Vector3(6.0, 0, 0))
	var act1_open = GameManager.act1_door_unlocked
	var act1_door_col = Color(0.2, 1.0, 0.4) if act1_open else Color(1.0, 0.2, 0.2)
	draw_circle(act1_door_pos, 3.5, act1_door_col)
	
	var dome_door_pos = world_to_map(Vector3(24.0, 0, -16.0))
	var dome_open = GameManager.dome_door_unlocked
	var dome_door_col = Color(0.2, 1.0, 0.4) if dome_open else Color(1.0, 0.3, 0.1)
	draw_circle(dome_door_pos, 4.0, dome_door_col)
	
	var exit_door_pos = world_to_map(Vector3(0.0, 0, -32.0))
	var exit_open = GameManager.shutdown_lever_pulled
	var exit_door_col = Color(0.2, 1.0, 0.5) if exit_open else Color(0.8, 0.2, 0.2)
	draw_circle(exit_door_pos, 3.5, exit_door_col)
	
	var caps = [
		Vector3(15.0, 0, 9.7),
		Vector3(13.3, 0, -8.0),
		Vector3(34.7, 0, -8.0)
	]
	var caps_count = GameManager.capacitors_activated
	for i in range(caps.size()):
		var cp = world_to_map(caps[i])
		var is_flipped = (i < caps_count)
		var c_col = Color(0.2, 1.0, 0.4) if is_flipped else Color(1.0, 0.7, 0.1)
		_draw_diamond(cp, 4.0, c_col, is_flipped)
	
	var rec_pos = world_to_map(Vector3(5.8, 0, -0.6))
	var rec_col = Color(0.2, 1.0, 0.5) if act1_open else Color(0.1, 0.9, 1.0)
	_draw_star(rec_pos, 3.5, rec_col)
	
	var stations = [
		Vector3(33.0, 0, -36.5),
		Vector3(24.0, 0, -23.0),
		Vector3(15.0, 0, -36.5)
	]
	for st in stations:
		var st_pos = world_to_map(st)
		var st_col = Color(0.3, 0.9, 1.0) if not GameManager.dome_puzzle_solved else Color(0.2, 1.0, 0.4)
		draw_circle(st_pos, 2.5, st_col)
	
	var tree = get_tree()
	if tree:
		var entities = tree.get_nodes_in_group("ShadowEntity")
		for ent in entities:
			if is_instance_valid(ent) and not ent.is_banished and ent.is_active:
				var ep = world_to_map(ent.global_position)
				var pulse = 0.5 + 0.5 * sin(pulse_time * 2.0)
				var ent_col = Color(0.9, 0.1, 0.3, 0.8 + 0.2 * pulse)
				draw_circle(ep, 3.0 + pulse * 1.5, ent_col)
	
	var player = tree.get_first_node_in_group("Player") if tree else null
	if player:
		var pp = world_to_map(player.global_position)
		var fwd = -player.camera.global_transform.basis.z if player.camera else -player.global_transform.basis.z
		var fwd_2d = Vector2(fwd.x, fwd.z).normalized() * 8.0
		
		var left_wing = fwd_2d.rotated(2.5) * 0.55
		var right_wing = fwd_2d.rotated(-2.5) * 0.55
		var player_col = Color(0.2, 0.95, 1.0)
		
		draw_colored_polygon([pp + fwd_2d, pp + left_wing, pp + right_wing], player_col)
		draw_circle(pp, 3.5, Color(1.0, 1.0, 1.0))
		
		var ping_r = fmod(pulse_time * 8.0, 16.0)
		var ping_alpha = max(0.0, 1.0 - ping_r / 16.0) * 0.6
		draw_arc(pp, ping_r, 0, TAU, 24, Color(0.2, 0.9, 1.0, ping_alpha), 1.0)

func _draw_diamond(center: Vector2, size_r: float, col: Color, filled: bool):
	var pts = [
		center + Vector2(0, -size_r),
		center + Vector2(size_r, 0),
		center + Vector2(0, size_r),
		center + Vector2(-size_r, 0)
	]
	if filled:
		draw_colored_polygon(pts, col)
	else:
		for i in range(4):
			draw_line(pts[i], pts[(i + 1) % 4], col, 1.5)

func _draw_star(center: Vector2, size_r: float, col: Color):
	draw_line(center - Vector2(size_r, 0), center + Vector2(size_r, 0), col, 2.0)
	draw_line(center - Vector2(0, size_r), center + Vector2(0, size_r), col, 2.0)
	draw_line(center - Vector2(size_r * 0.7, size_r * 0.7), center + Vector2(size_r * 0.7, size_r * 0.7), col, 1.2)
	draw_line(center - Vector2(-size_r * 0.7, size_r * 0.7), center + Vector2(-size_r * 0.7, size_r * 0.7), col, 1.2)
