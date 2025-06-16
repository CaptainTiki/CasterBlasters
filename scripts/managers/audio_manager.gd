# AudioManager.gd
extends Node

# Audio players
var music_player: AudioStreamPlayer
var sfx_players: Array[AudioStreamPlayer] = []
var voice_player: AudioStreamPlayer

# Settings
var master_volume: float = 1.0
var music_volume: float = 0.7
var sfx_volume: float = 0.8
var voice_volume: float = 0.9

# Music state
var current_music: AudioStream
var is_music_playing: bool = false

# SFX pool management
const SFX_POOL_SIZE = 10
var sfx_pool_index: int = 0

func _ready():
	# Create music player
	music_player = AudioStreamPlayer.new()
	music_player.bus = "Music"  # Assumes you have audio buses set up
	add_child(music_player)
	
	# Create SFX player pool
	for i in range(SFX_POOL_SIZE):
		var sfx_player = AudioStreamPlayer.new()
		sfx_player.bus = "SFX"
		sfx_players.append(sfx_player)
		add_child(sfx_player)
	
	# Create voice player
	voice_player = AudioStreamPlayer.new()
	voice_player.bus = "Voice"
	add_child(voice_player)
	
	# Load saved volume settings
	_load_audio_settings()

# ===================================
# MUSIC METHODS
# ===================================

func play_music(music: AudioStream, fade_in: bool = true):
	if current_music == music and is_music_playing:
		return  # Already playing this track
	
	if fade_in and is_music_playing:
		# Fade out current, then fade in new
		fade_out_music()
		await music_player.finished
	
	current_music = music
	music_player.stream = music
	music_player.volume_db = linear_to_db(0.0 if fade_in else music_volume)
	music_player.play()
	is_music_playing = true
	
	if fade_in:
		fade_in_music()

func fade_in_music(duration: float = 1.0):
	var tween = create_tween()
	tween.tween_method(_set_music_volume, 0.0, music_volume, duration)

func fade_out_music(duration: float = 1.0):
	var tween = create_tween()
	tween.tween_method(_set_music_volume, music_volume, 0.0, duration)
	tween.tween_callback(stop_music).set_delay(duration)

func stop_music():
	music_player.stop()
	is_music_playing = false
	current_music = null

func pause_music():
	music_player.stream_paused = true

func resume_music():
	music_player.stream_paused = false

func _set_music_volume(volume: float):
	music_player.volume_db = linear_to_db(volume * master_volume)

# ===================================
# SFX METHODS
# ===================================

func play_sfx(sound: AudioStream, volume_modifier: float = 1.0) -> AudioStreamPlayer:
	var player = _get_available_sfx_player()
	if not player:
		return null  # All players busy
	
	player.stream = sound
	player.volume_db = linear_to_db(sfx_volume * volume_modifier * master_volume)
	player.play()
	return player

func play_sfx_2d(sound: AudioStream, position: Vector2, volume_modifier: float = 1.0):
	# For 2D positional audio - you'd need AudioStreamPlayer2D nodes
	# This is a simplified version
	play_sfx(sound, volume_modifier)

func play_sfx_3d(sound: AudioStream, position: Vector3, volume_modifier: float = 1.0):
	# For 3D positional audio - you'd need AudioStreamPlayer3D nodes
	# This is a simplified version for now
	play_sfx(sound, volume_modifier)

func _get_available_sfx_player() -> AudioStreamPlayer:
	# Round-robin through SFX players
	for i in range(SFX_POOL_SIZE):
		var player_index = (sfx_pool_index + i) % SFX_POOL_SIZE
		var player = sfx_players[player_index]
		
		if not player.playing:
			sfx_pool_index = (player_index + 1) % SFX_POOL_SIZE
			return player
	
	# All busy, force use the next one
	var player = sfx_players[sfx_pool_index]
	sfx_pool_index = (sfx_pool_index + 1) % SFX_POOL_SIZE
	return player

# ===================================
# VOICE METHODS
# ===================================

func play_voice(voice_clip: AudioStream):
	voice_player.stream = voice_clip
	voice_player.volume_db = linear_to_db(voice_volume * master_volume)
	voice_player.play()

func stop_voice():
	voice_player.stop()

func is_voice_playing() -> bool:
	return voice_player.playing

# ===================================
# VOLUME CONTROL
# ===================================

func set_master_volume(volume: float):
	master_volume = clamp(volume, 0.0, 1.0)
	_update_all_volumes()
	_save_audio_settings()

func set_music_volume(volume: float):
	music_volume = clamp(volume, 0.0, 1.0)
	_set_music_volume(music_volume)
	_save_audio_settings()

func set_sfx_volume(volume: float):
	sfx_volume = clamp(volume, 0.0, 1.0)
	_save_audio_settings()

func set_voice_volume(volume: float):
	voice_volume = clamp(volume, 0.0, 1.0)
	_save_audio_settings()

func _update_all_volumes():
	_set_music_volume(music_volume)
	# SFX and voice volumes are applied when played

# ===================================
# AUDIO SETTINGS PERSISTENCE
# ===================================

func _save_audio_settings():
	var config = ConfigFile.new()
	config.set_value("audio", "master_volume", master_volume)
	config.set_value("audio", "music_volume", music_volume)
	config.set_value("audio", "sfx_volume", sfx_volume)
	config.set_value("audio", "voice_volume", voice_volume)
	config.save("user://audio_settings.cfg")

func _load_audio_settings():
	var config = ConfigFile.new()
	if config.load("user://audio_settings.cfg") == OK:
		master_volume = config.get_value("audio", "master_volume", 1.0)
		music_volume = config.get_value("audio", "music_volume", 0.7)
		sfx_volume = config.get_value("audio", "sfx_volume", 0.8)
		voice_volume = config.get_value("audio", "voice_volume", 0.9)
		_update_all_volumes()

# ===================================
# CONVENIENCE METHODS
# ===================================

func play_ui_sound(sound: AudioStream):
	# UI sounds usually want to be a bit quieter
	play_sfx(sound, 0.6)

func play_weapon_sound(sound: AudioStream):
	# Weapon sounds want to be prominent
	play_sfx(sound, 1.2)

func play_explosion_sound(sound: AudioStream):
	# Explosions are LOUD
	play_sfx(sound, 1.5)

func play_ambient_sound(sound: AudioStream):
	# Ambient sounds are background
	play_sfx(sound, 0.4)
