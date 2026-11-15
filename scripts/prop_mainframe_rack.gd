extends Node3D

@onready var reel_left: Node3D = get_node_or_null("ReelLeft")
@onready var reel_right: Node3D = get_node_or_null("ReelRight")
@onready var led_root: Node3D = get_node_or_null("StatusLEDs")

var rot_speed_l: float = 1.4
var rot_speed_r: float = 1.2
var blink_timer: float = 0.0

func _process(delta: float):
	if reel_left:
		reel_left.rotate_z(rot_speed_l * delta)
	if reel_right:
		reel_right.rotate_z(rot_speed_r * delta)
		
	blink_timer += delta
	if blink_timer > 0.12 and led_root:
		blink_timer = 0.0
		var children = led_root.get_children()
		if children.size() > 0:
			var rand_idx = randi() % children.size()
			var led = children[rand_idx]
			if led is OmniLight3D:
				led.visible = not led.visible
