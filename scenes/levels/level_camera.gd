# LevelCamera.gd
extends Camera3D
class_name LevelCamera

# Camera configuration
@export_group("Camera Settings")
@export var follow_speed: float = 5.0
@export var zoom_level: float = 20.0  # Orthogonal size for 2.5D
@export var camera_distance: float = 10.0  # Z distance from action
@export var look_ahead_distance: float = 3.0  # How far ahead to look

@export_group("Camera Bounds")
@export var use_level_bounds: bool = true
@export var level_width: float = 2000.0
@export var level_height: float = 600.0
@export var boundary_padding: float = 50.0

@export_group("Co-op Settings")
@export var coop_zoom_out_factor: float = 1.5  # How much to zoom out with 2 players
@export var max_player_distance: float = 15.0  # Max distance before zooming out

@export_group("Camera Effects")
@export var shake_enabled: bool = true
@export var shake_decay: float = 5.0

# Internal state
var target_position: Vector3
var target_zoom: float
var players: Array[Node] = []
var shake_strength: float = 0.0
var shake_offset: Vector3 = Vector3.ZERO

# Camera modes
enum CameraMode {
	FOLLOW_SINGLE,
	FOLLOW_MULTIPLE,
	FIXED_POSITION,
	CINEMATIC
}

var current_mode: CameraMode = CameraMode.FOLLOW_SINGLE

func _ready():
	#set the camera to process after the player is moved
	process_priority = 1
	
	# Set up camera for 2.5D
	projection = PROJECTION_ORTHOGONAL
	size = zoom_level
	position.z = camera_distance
	
	# Connect to game manager
	if GameManager:
		GameManager.player_spawned.connect(_on_player_spawned)
		GameManager.level_changed.connect(_on_level_changed)
	
	target_zoom = zoom_level
	_find_players()

func _process(delta):
	_update_players_list()
	_update_target_position()

func _physics_process(delta: float) -> void:
	_update_camera_position(delta)
	_update_camera_zoom(delta)
	_update_shake_effect(delta)

func _find_players():
	players.clear()
	players = get_tree().get_nodes_in_group("players")
	
	# Update camera mode based on player count
	if players.size() <= 1:
		current_mode = CameraMode.FOLLOW_SINGLE
	else:
		current_mode = CameraMode.FOLLOW_MULTIPLE

func _update_players_list():
	# Refresh player list in case players joined/left
	var current_players = get_tree().get_nodes_in_group("players")
	if current_players.size() != players.size():
		_find_players()

func _update_target_position():
	if players.is_empty():
		return
	
	match current_mode:
		CameraMode.FOLLOW_SINGLE:
			if players.size() > 0:
				target_position = players[0].global_position
				target_position += _get_look_ahead_offset(players[0])
		
		CameraMode.FOLLOW_MULTIPLE:
			target_position = _get_center_point_between_players()
		
		CameraMode.FIXED_POSITION:
			# Target position is manually set
			pass
		
		CameraMode.CINEMATIC:
			# Handled by external cinematic system
			pass
	
	# Apply level bounds
	if use_level_bounds:
		target_position = _clamp_to_level_bounds(target_position)

func _get_center_point_between_players() -> Vector3:
	if players.is_empty():
		return Vector3.ZERO
	
	var center = Vector3.ZERO
	for player in players:
		center += player.global_position
	center /= players.size()
	
	# Adjust zoom based on player spread
	_calculate_coop_zoom()
	
	return center

func _get_look_ahead_offset(player: Node3D) -> Vector3:
	# Look ahead in the direction the player is moving
	if player.has_method("get_velocity"):
		var velocity = player.get_velocity()
		if velocity.length() > 0.1:
			return velocity.normalized() * look_ahead_distance
	
	return Vector3.ZERO

func _calculate_coop_zoom():
	if players.size() < 2:
		target_zoom = zoom_level
		return
	
	# Find the maximum distance between any two players
	var max_distance = 0.0
	for i in range(players.size()):
		for j in range(i + 1, players.size()):
			var distance = players[i].global_position.distance_to(players[j].global_position)
			max_distance = max(max_distance, distance)
	
	# Zoom out if players are far apart
	if max_distance > max_player_distance:
		var zoom_factor = 1.0 + (max_distance - max_player_distance) / max_player_distance
		target_zoom = zoom_level * min(zoom_factor, coop_zoom_out_factor)
	else:
		target_zoom = zoom_level

func _clamp_to_level_bounds(pos: Vector3) -> Vector3:
	var half_width = (size * get_viewport().get_visible_rect().size.x / get_viewport().get_visible_rect().size.y) / 2
	var half_height = size / 2
	
	pos.x = clamp(pos.x, -level_width/2 + half_width + boundary_padding, 
				  level_width/2 - half_width - boundary_padding)
	pos.y = clamp(pos.y, -level_height/2 + half_height + boundary_padding, 
				  level_height/2 - half_height - boundary_padding)
	
	return pos

func _update_camera_position(delta):
	var final_target = target_position
	final_target.z = camera_distance
	
	# Apply shake offset
	final_target += shake_offset
	
	# Smooth movement
	global_position = global_position.lerp(final_target, follow_speed * delta)

func _update_camera_zoom(delta):
	# Smooth zoom transitions
	size = lerp(size, target_zoom, follow_speed * delta)

func _update_shake_effect(delta):
	if shake_strength > 0:
		# Generate random shake offset
		shake_offset = Vector3(
			randf_range(-shake_strength, shake_strength),
			randf_range(-shake_strength, shake_strength),
			0
		)
		
		# Decay shake over time
		shake_strength = max(0, shake_strength - shake_decay * delta)
	else:
		shake_offset = Vector3.ZERO

# ===================================
# PUBLIC METHODS
# ===================================

func add_screen_shake(strength: float):
	if shake_enabled:
		shake_strength = max(shake_strength, strength)

func set_camera_mode(mode: CameraMode):
	current_mode = mode

func set_fixed_position(pos: Vector3):
	current_mode = CameraMode.FIXED_POSITION
	target_position = pos

func set_level_bounds(width: float, height: float):
	level_width = width
	level_height = height

func focus_on_player(player_index: int = 0):
	if player_index < players.size():
		current_mode = CameraMode.FOLLOW_SINGLE
		# Move the target player to front of array
		if player_index > 0:
			var temp = players[0]
			players[0] = players[player_index]
			players[player_index] = temp

# ===================================
# SIGNAL CALLBACKS
# ===================================

func _on_player_spawned(player: Node3D):
	if player and not player in players:
		players.append(player)
		_find_players()

func _on_level_changed(level_name: String):
	# Reset camera state for new level
	players.clear()
	shake_strength = 0.0
	shake_offset = Vector3.ZERO
	current_mode = CameraMode.FOLLOW_SINGLE
	
	# Find players in new level
	await get_tree().process_frame  # Wait one frame for level to load
	_find_players()

# ===================================
# CINEMATIC METHODS (for cutscenes/boss intros)
# ===================================

func start_cinematic_pan(start_pos: Vector3, end_pos: Vector3, duration: float):
	current_mode = CameraMode.CINEMATIC
	var tween = create_tween()
	tween.tween_method(_set_cinematic_position, start_pos, end_pos, duration)
	tween.tween_callback(_end_cinematic)

func _set_cinematic_position(pos: Vector3):
	target_position = pos

func _end_cinematic():
	_find_players()  # Return to normal follow mode
