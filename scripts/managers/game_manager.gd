# GameManager.gd
extends Node

signal player_died
signal player_spawned
signal enemy_killed(enemy_type: String)
signal level_complete

var player_health: int = 100
var score: int = 0
var current_level: BaseLevel

var current_level_scene: PackedScene
var player_reference: Node3D

signal level_changed(level_name: String)

func load_level(level_scene: PackedScene):
	# Clean up current level
	if current_level:
		current_level.queue_free()
	
	# Load new level
	current_level_scene = level_scene
	current_level = level_scene.instantiate()
	get_tree().current_scene.add_child(current_level)
	
	# Connect level signals
	current_level.level_completed.connect(_on_level_completed)
	current_level.player_spawned.connect(_on_player_spawned)
	
	level_changed.emit(current_level.level_name)

func restart_current_level():
	if current_level_scene:
		load_level(current_level_scene)

func set_current_player(player: Node3D):
	player_reference = player
	
func _on_level_completed():
	print("Level completed: ", current_level.level_name)

func _on_player_spawned(player: Node3D):
	set_current_player(player)
