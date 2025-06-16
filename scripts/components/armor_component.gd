# ArmorComponent.gd
extends Node
class_name ArmorComponent

# Signals
signal armor_changed(current: int, maximum: int)
signal armor_depleted
signal armor_restored

# Armor properties
@export var max_armor: int = 50
@export var current_armor: int
@export var armor_type: String = "basic"  # basic, heavy, magical, etc.

# Damage reduction
@export var damage_reduction_percent: float = 0.25  # 25% damage reduction
@export var magic_resistance: float = 0.1  # Extra resistance to magic damage
@export var physical_resistance: float = 0.15  # Extra resistance to physical damage

# Armor regeneration
@export var regenerates: bool = false
@export var regen_delay: float = 5.0  # Time before regen starts
@export var regen_rate: float = 2.0  # Armor per second
@export var regen_amount: int = 1  # Amount per tick

# Private variables
var regen_timer: Timer
var is_regenerating: bool = false

func _ready():
	# Initialize armor
	if current_armor <= 0:
		current_armor = max_armor
	
	# Set up regeneration timer if enabled
	if regenerates:
		regen_timer = Timer.new()
		regen_timer.wait_time = regen_delay
		regen_timer.one_shot = true
		regen_timer.timeout.connect(_start_regeneration)
		add_child(regen_timer)
	
	# Emit initial state
	armor_changed.emit(current_armor, max_armor)

func _process(delta):
	if regenerates and is_regenerating and current_armor < max_armor:
		_regenerate_armor(delta)

func process_damage(base_damage: int, damage_type: String = "physical") -> int:
	# Calculate damage reduction
	var reduction = damage_reduction_percent
	
	# Add type-specific resistance
	match damage_type.to_lower():
		"magic", "magical", "spell":
			reduction += magic_resistance
		"physical", "melee", "projectile":
			reduction += physical_resistance
	
	# Clamp reduction to reasonable limits (max 90% reduction)
	reduction = clamp(reduction, 0.0, 0.9)
	
	# Calculate actual damage
	var reduced_damage = int(base_damage * (1.0 - reduction))
	
	# Armor absorbs some damage
	var armor_damage = min(current_armor, reduced_damage / 2)  # Armor takes half the reduced damage
	var health_damage = reduced_damage - armor_damage
	
	# Apply armor damage
	if armor_damage > 0:
		_take_armor_damage(armor_damage)
	
	return max(1, health_damage)  # Always do at least 1 damage

func _take_armor_damage(damage: int):
	current_armor = max(0, current_armor - damage)
	armor_changed.emit(current_armor, max_armor)
	
	# Stop regeneration and restart timer
	if regenerates:
		is_regenerating = false
		if regen_timer:
			regen_timer.start()
	
	# Check if armor is depleted
	if current_armor <= 0:
		armor_depleted.emit()

func _start_regeneration():
	if current_armor < max_armor:
		is_regenerating = true

func _regenerate_armor(delta):
	var regen_this_frame = regen_rate * delta
	current_armor = min(max_armor, current_armor + int(regen_this_frame))
	
	armor_changed.emit(current_armor, max_armor)
	
	if current_armor >= max_armor:
		is_regenerating = false
		armor_restored.emit()

# ===================================
# PUBLIC METHODS
# ===================================

func repair_armor(amount: int):
	var old_armor = current_armor
	current_armor = min(max_armor, current_armor + amount)
	
	if current_armor > old_armor:
		armor_changed.emit(current_armor, max_armor)
		
		if old_armor <= 0 and current_armor > 0:
			armor_restored.emit()

func set_max_armor(new_max: int):
	max_armor = new_max
	current_armor = min(current_armor, max_armor)
	armor_changed.emit(current_armor, max_armor)

func get_armor_percentage() -> float:
	return float(current_armor) / float(max_armor)

func has_armor() -> bool:
	return current_armor > 0

func is_armor_full() -> bool:
	return current_armor >= max_armor

func get_damage_reduction() -> float:
	return damage_reduction_percent

func set_armor_type(new_type: String):
	armor_type = new_type
	# You could modify resistances based on armor type here
	_apply_armor_type_bonuses()

func _apply_armor_type_bonuses():
	# Modify resistances based on armor type
	match armor_type.to_lower():
		"heavy":
			physical_resistance = 0.3
			magic_resistance = 0.05
			damage_reduction_percent = 0.4
		"magical":
			physical_resistance = 0.1
			magic_resistance = 0.4
			damage_reduction_percent = 0.3
		"light":
			physical_resistance = 0.15
			magic_resistance = 0.15
			damage_reduction_percent = 0.2
		"basic":
			physical_resistance = 0.15
			magic_resistance = 0.1
			damage_reduction_percent = 0.25
