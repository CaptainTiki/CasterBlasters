# HealthComponent.gd
extends Node
class_name HealthComponent

# Signals for decoupled communication
signal health_changed(new_health: int, max_health: int)
signal took_damage(damage_amount: int)
signal died
signal healed(heal_amount: int)

# Health properties
@export var max_health: int = 100
@export var current_health: int
@export var is_invincible: bool = false
@export var invincibility_duration: float = 0.5

# Private variables
var _invincibility_timer: Timer

func _ready():
	# Initialize health to max if not set
	if current_health <= 0:
		current_health = max_health
	
	# Setup invincibility timer
	_invincibility_timer = Timer.new()
	_invincibility_timer.wait_time = invincibility_duration
	_invincibility_timer.one_shot = true
	_invincibility_timer.timeout.connect(_on_invincibility_ended)
	add_child(_invincibility_timer)
	
	# Emit initial health state
	health_changed.emit(current_health, max_health)

func take_damage(amount: int, damage_type: String = "physical") -> bool:
	# Return false if damage was blocked
	if is_invincible or amount <= 0:
		return false
	
	var final_damage = amount
	
	# Check for armor component
	var armor_comp = get_parent().get_node("ArmorComponent") as ArmorComponent
	if armor_comp:
		final_damage = armor_comp.process_damage(amount, damage_type)
	
	current_health = max(0, current_health - final_damage)
	took_damage.emit(final_damage)
	health_changed.emit(current_health, max_health)
	
	# Start invincibility frames
	if invincibility_duration > 0:
		is_invincible = true
		_invincibility_timer.start()
	
	# Check for death
	if current_health <= 0:
		died.emit()
		return true
	
	return true

func heal(amount: int) -> void:
	if amount <= 0:
		return
	
	var old_health = current_health
	current_health = min(max_health, current_health + amount)
	
	if current_health > old_health:
		healed.emit(amount)
		health_changed.emit(current_health, max_health)

func get_health_percentage() -> float:
	return float(current_health) / float(max_health)

func is_alive() -> bool:
	return current_health > 0

func is_at_max_health() -> bool:
	return current_health >= max_health

func set_max_health(new_max: int) -> void:
	max_health = new_max
	current_health = min(current_health, max_health)
	health_changed.emit(current_health, max_health)

func _on_invincibility_ended():
	is_invincible = false

# Optional: Visual feedback method (override in specific implementations)
func _on_damage_visual_feedback():
	# This can be overridden by the parent node
	# or connected to a signal for visual effects
	pass
