#level.gd
extends Node3D
class_name Level

@export var player_scene: PackedScene = preload("res://scenes/player/player.tscn")
@export var death_zone_y: float = -20.0

@onready var player_spawner = $PlayerSpawner
@onready var camera_controller = $CameraController
@onready var death_zone = $DeathZone

var current_player: Player = null
var is_level_active: bool = true

func _ready():
	spawn_player()
	setup_death_zone()

func spawn_player():
	if player_spawner and player_scene:
		current_player = player_scene.instantiate()
		add_child(current_player)
		current_player.global_position = player_spawner.global_position
		
		# Connect player signals
		current_player.player_died.connect(_on_player_died)
		
		# Tell camera to follow this player
		if camera_controller:
			camera_controller.set_target(current_player)
		
		print("Player spawned at: ", player_spawner.global_position)

func setup_death_zone():
	if death_zone:
		death_zone.position.y = death_zone_y
		death_zone.body_entered.connect(_on_death_zone_entered)

func _on_death_zone_entered(body):
	if body is Player and body == current_player:
		kill_player()

func kill_player():
	if current_player and is_level_active:
		current_player.die()

func _on_player_died():
	print("Player died!")
	is_level_active = false
	
	# Stop camera tracking
	if camera_controller:
		camera_controller.stop_tracking()
	
	# TODO: Respawn logic, game over screen, etc.
	await get_tree().create_timer(2.0).timeout
	restart_level()

func restart_level():
	# Simple restart for now
	get_tree().reload_current_scene()
