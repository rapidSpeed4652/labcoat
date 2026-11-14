extends Node

var ambient_player: AudioStreamPlayer
var radio_player: AudioStreamPlayer
var sfx_player: AudioStreamPlayer
var alarm_player: AudioStreamPlayer

var sounds: Dictionary = {}

func _ready():
	process_mode = Node.PROCESS_MODE_ALWAYS
	_setup_audio_players()
	_load_sound_assets()
	play_ambient()

func _setup_audio_players():
	ambient_player = AudioStreamPlayer.new()
	ambient_player.bus = "Master"
	ambient_player.volume_db = -12.0
	add_child(ambient_player)
	
	radio_player = AudioStreamPlayer.new()
	radio_player.bus = "Master"
	radio_player.volume_db = -4.0
	add_child(radio_player)
	
	sfx_player = AudioStreamPlayer.new()
	sfx_player.bus = "Master"
	sfx_player.volume_db = -2.0
	add_child(sfx_player)
	
	alarm_player = AudioStreamPlayer.new()
	alarm_player.bus = "Master"
	alarm_player.volume_db = -10.0
	add_child(alarm_player)

func _load_sound_assets():
	var audio_files = [
		"ambient_drone.wav",
		"radio_static.wav",
		"laser_hum.wav",
		"laser_click.wav",
		"laser_overheat.wav",
		"laser_cooldown.wav",
		"mirror_reflect.wav",
		"entity_stalk.wav",
		"entity_absorb.wav",
		"entity_banish.wav",
		"door_open.wav",
		"switch_flip.wav",
		"footstep.wav",
		"dome_alarm.wav",
		"shutter_close.wav",
		"interact.wav"
	]
	
	for file in audio_files:
		var key = file.get_basename()
		var path = "res://assets/audio/" + file
		if ResourceLoader.exists(path):
			sounds[key] = load(path)

func play_ambient():
	if sounds.has("ambient_drone"):
		ambient_player.stream = sounds["ambient_drone"]
		# Loop
		if ambient_player.stream is AudioStreamWAV:
			ambient_player.stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
		ambient_player.play()

func play_sfx(name: String, pitch_scale: float = 1.0, volume_offset_db: float = 0.0):
	if sounds.has(name):
		var p = AudioStreamPlayer.new()
		p.stream = sounds[name]
		p.pitch_scale = pitch_scale
		p.volume_db = sfx_player.volume_db + volume_offset_db
		add_child(p)
		p.play()
		p.finished.connect(func(): p.queue_free())

func play_radio_static():
	if sounds.has("radio_static"):
		radio_player.stream = sounds["radio_static"]
		radio_player.play()

func start_dome_alarm():
	if sounds.has("dome_alarm"):
		alarm_player.stream = sounds["dome_alarm"]
		if alarm_player.stream is AudioStreamWAV:
			alarm_player.stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
		alarm_player.play()

func stop_dome_alarm():
	alarm_player.stop()
