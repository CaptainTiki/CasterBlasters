# Base_Level.gd - Common level functionality
extends Node3D
class_name BaseLevel

# Level configuration
@export_group("Level Settings")
@export var level_name: String = "Test Level"
@export var next_level_scene: PackedScene
@export var background_music: AudioStream
@export var level_time_limit: float = 0.0  # 0 = no limit

@export_group("Player Spawn")
@export var player_spawn_point: Node3D
@export var player_scene: PackedScene

@export_group("Level Bounds")
@export var level_width: float = 2000.0
@export var level_height: float = 600.0

# Internal references
var player: Node3D
var level_camera: LevelCamera
var activation_zones: Array[Area3D] = []
var level_complete: bool = false

# Signals
signal level_started
signal level_completed
signal player_spawned(player_node: Node3D)

func _ready():
	_setup_level()
	_setup_camera()
	_spawn_player()
	_find_activation_zones()
	
	# Connect to game manager
	GameManager.player_died.connect(_on_player_died)
	
	level_started.emit()

func _setup_level():
	# Play background music
	if background_music:
		AudioManager.play_music(background_music)
	
	# Set up level timer if needed
	if level_time_limit > 0:
		var timer = Timer.new()
		timer.wait_time = level_time_limit
		timer.one_shot = true
		timer.timeout.connect(_on_time_limit_reached)
		add_child(timer)
		timer.start()

func _setup_camera():
	# Find existing camera in the scene or create one
	level_camera = get_node("LevelCamera") as LevelCamera
	if not level_camera:
		# Create camera if none exists in the scene
		level_camera = preload("res://scenes/level_camera.tscn").instantiate()
		add_child(level_camera)
	
	# Configure camera for this level
	level_camera.set_level_bounds(level_width, level_height)

func _spawn_player():
	if not player_scene:
		push_error("No player scene assigned to level!")
		return
	
	player = player_scene.instantiate()
	add_child(player)
	
	# Add to players group for camera tracking
	player.add_to_group("players")
	
	# Position player at spawn point
	if player_spawn_point:
		player.global_position = player_spawn_point.global_position
	
	player_spawned.emit(player)
	GameManager.set_current_player(player)

func _find_activation_zones():
	# Find all activation zones in the level
	activation_zones = []
	_recursive_find_activation_zones(self)
	
	# Connect to each zone
	for zone in activation_zones:
		if not zone.body_entered.is_connected(_on_activation_zone_entered):
			zone.body_entered.connect(_on_activation_zone_entered)

func _recursive_find_activation_zones(node: Node):
	if node is Area3D and node.is_in_group("activation_zone"):
		activation_zones.append(node)
	
	for child in node.get_children():
		_recursive_find_activation_zones(child)

func _on_activation_zone_entered(body):
	# Activate enemies in this zone
	if body == player:
		var zone = body.get_parent() as Area3D
		_activate_enemies_in_zone(zone)

func _activate_enemies_in_zone(zone: Area3D):
	# Find enemies that are children of this zone
	for child in zone.get_children():
		if child.is_in_group("enemies") and child.has_method("activate"):
			child.activate()

func complete_level():
	if level_complete:
		return
	
	level_complete = true
	level_completed.emit()
	
	# Transition to next level
	if next_level_scene:
		GameManager.load_level(next_level_scene)

func _on_player_died():
	# Handle player death - restart level or game over
	GameManager.restart_current_level()

func _on_time_limit_reached():
	# Handle time limit - could be instant death or just a warning
	GameManager.time_limit_reached()

# Methods for camera control
func add_camera_shake(strength: float):
	if level_camera:
		level_camera.add_screen_shake(strength)

func set_camera_fixed_position(pos: Vector3):
	if level_camera:
		level_camera.set_fixed_position(pos)

func start_camera_cinematic(start_pos: Vector3, end_pos: Vector3, duration: float):
	if level_camera:
		level_camera.start_cinematic_pan(start_pos, end_pos, duration)

# Virtual methods that can be overridden in specific levels
func _on_level_specific_setup():
	# Override this in individual level scripts for custom logic
	pass

func _on_level_specific_update(delta):
	# Override for level-specific per-frame logic
	pass
