# BaseEnemy.gd
extends CharacterBody3D
class_name BaseEnemy

@export var enemy_type: String = "basic"
@onready var health_component = $HealthComponent

func _ready():
	# Connect health signals
	health_component.died.connect(_on_enemy_died)
	health_component.took_damage.connect(_on_enemy_damaged)

func _on_enemy_died():
	# Drop loot, play death effect, update score
	GameManager.enemy_killed.emit(enemy_type)
	_spawn_death_effect()
	queue_free()

func _on_enemy_damaged(amount: int):
	# Enemy-specific damage reaction
	_play_hurt_sound()
	# Maybe change AI state to "angry" or "fleeing"

func _spawn_death_effect():
	# Particle effects, sound, etc.
	pass

func _play_hurt_sound():
	# Audio feedback
	pass
