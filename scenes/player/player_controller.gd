# PlayerController.gd
extends CharacterBody3D
class_name PlayerController

# Movement settings
@export_group("Movement")
@export var move_speed: float = 300.0
@export var jump_velocity: float = 600.0
@export var gravity: float = 1500.0
@export var acceleration: float = 1000.0
@export var friction: float = 800.0
@export var air_control: float = 0.5  # How much control in air (0-1)

@export_group("Dodge Roll")
@export var roll_speed: float = 500.0
@export var roll_duration: float = 0.3
@export var roll_cooldown: float = 1.0
@export var roll_invincibility: bool = true

@export_group("Ground Check")
@export var coyote_time: float = 0.1  # Grace time after leaving platform
@export var jump_buffer_time: float = 0.15  # Early jump input buffer

# Input tracking
var input_vector: Vector2
var jump_buffered: bool = false
var was_on_floor: bool = false
var coyote_timer: float = 0.0
var jump_buffer_timer: float = 0.0

# Roll state
var is_rolling: bool = false
var roll_timer: float = 0.0
var roll_cooldown_timer: float = 0.0
var roll_direction: Vector3

# Facing direction
var facing_right: bool = true
var last_move_direction: float = 0.0

# Component references
@onready var health_component: HealthComponent = $HealthComponent
@onready var weapon_component: WeaponComponent = $WeaponComponent
@onready var armor_component: ArmorComponent = $ArmorComponent
@onready var mesh_instance: MeshInstance3D = $MeshInstance3D
@onready var collision_shape: CollisionShape3D = $CollisionShape3D
@onready var ground_check: RayCast3D = $GroundCheck
@onready var audio_player: AudioStreamPlayer3D = $AudioPlayer

# Audio clips
@export_group("Audio")
@export var jump_sound: AudioStream
@export var land_sound: AudioStream
@export var roll_sound: AudioStream
@export var hurt_sound: AudioStream

# Visual effects
@export_group("Effects")
@export var damage_flash_duration: float = 0.2
@export var damage_flash_color: Color = Color.RED

# Animation/visual state
var is_flashing: bool = false

func _ready():
	# Connect component signals
	if health_component:
		health_component.took_damage.connect(_on_took_damage)
		health_component.died.connect(_on_player_died)
		health_component.health_changed.connect(_on_health_changed)
	
	if weapon_component:
		weapon_component.weapon_fired.connect(_on_weapon_fired)
	
	# Set up ground check
	if not ground_check:
		ground_check = RayCast3D.new()
		add_child(ground_check)
		ground_check.position = Vector3(0, -1, 0)
		ground_check.target_position = Vector3(0, -0.1, 0)
		ground_check.enabled = true
	
	# Add to players group for camera
	add_to_group("players")
	
	# Initialize velocity to zero
	velocity = Vector3.ZERO

func _process(delta: float) -> void:
	_handle_input()
	_update_timers(delta)
	_handle_roll(delta)
	
	if not is_rolling:
		_handle_movement(delta)
		_handle_jump(delta)
		
	_apply_gravity(delta)
	_update_facing_direction()

func _physics_process(delta):
	# Move the character
	move_and_slide()
	
	# Check for landing
	_check_landing()

func _handle_input():
	# Movement input
	input_vector.x = Input.get_axis("move_left", "move_right")
	input_vector.y = Input.get_axis("move_up", "move_down")  # For aiming
	
	# Jump input with buffering
	if Input.is_action_just_pressed("jump"):
		jump_buffered = true
		jump_buffer_timer = jump_buffer_time
	
	# Roll input
	if Input.is_action_just_pressed("dodge_roll") and _can_roll():
		_start_roll()
	
	# Weapon input
	if weapon_component:
		if Input.is_action_pressed("fire"):
			weapon_component.start_firing()
		else:
			weapon_component.stop_firing()
		
		if Input.is_action_just_pressed("reload"):
			weapon_component.reload()

func _update_timers(delta):
	# Coyote time
	if is_on_floor():
		coyote_timer = coyote_time
		was_on_floor = true
	else:
		coyote_timer = max(0, coyote_timer - delta)
	
	# Jump buffer
	if jump_buffer_timer > 0:
		jump_buffer_timer -= delta
	else:
		jump_buffered = false
	
	# Roll cooldown
	if roll_cooldown_timer > 0:
		roll_cooldown_timer -= delta

func _handle_movement(delta):
	if input_vector.x != 0:
		# Accelerate towards target speed
		var target_velocity = input_vector.x * move_speed
		var accel = acceleration
		
		# Reduce acceleration in air
		if not is_on_floor():
			accel *= air_control
		
		velocity.x = move_toward(velocity.x, target_velocity, accel * delta)
		last_move_direction = input_vector.x
	else:
		# Apply friction
		var friction_force = friction
		if not is_on_floor():
			friction_force *= air_control
		
		velocity.x = move_toward(velocity.x, 0, friction_force * delta)

func _handle_jump(delta):
	# Check if we can jump (on ground or coyote time)
	var can_jump = coyote_timer > 0
	
	if jump_buffered and can_jump:
		velocity.y = jump_velocity
		jump_buffered = false
		coyote_timer = 0  # Consume coyote time
		_play_sound(jump_sound)

func _apply_gravity(delta):
	if not is_on_floor():
		velocity.y -= gravity * delta

func _update_facing_direction():
	if last_move_direction > 0:
		facing_right = true
	elif last_move_direction < 0:
		facing_right = false
	
	# Flip sprite/mesh based on facing direction
	if mesh_instance:
		var scale = mesh_instance.scale
		scale.x = abs(scale.x) * (1 if facing_right else -1)
		mesh_instance.scale = scale

func _can_roll() -> bool:
	return not is_rolling and roll_cooldown_timer <= 0 and is_on_floor()

func _start_roll():
	is_rolling = true
	roll_timer = roll_duration
	roll_cooldown_timer = roll_cooldown
	
	# Set roll direction
	if input_vector.x != 0:
		roll_direction = Vector3(input_vector.x, 0, 0).normalized()
	else:
		roll_direction = Vector3(1 if facing_right else -1, 0, 0)
	
	# Enable invincibility if configured
	if roll_invincibility and health_component:
		health_component.is_invincible = true
	
	_play_sound(roll_sound)

func _handle_roll(delta):
	if is_rolling:
		roll_timer -= delta
		
		# Apply roll movement
		velocity.x = roll_direction.x * roll_speed
		
		if roll_timer <= 0:
			_end_roll()

func _end_roll():
	is_rolling = false
	
	# Disable invincibility
	if health_component:
		health_component.is_invincible = false

func _check_landing():
	# Play landing sound
	if is_on_floor() and not was_on_floor and velocity.y <= 0:
		_play_sound(land_sound)
	
	was_on_floor = is_on_floor()

# ===================================
# COMPONENT SIGNAL HANDLERS
# ===================================

func _on_took_damage(damage_amount: int):
	_play_sound(hurt_sound)
	_flash_damage()
	
	# Add camera shake
	var level = get_tree().get_first_node_in_group("levels") as BaseLevel
	if level:
		level.add_camera_shake(damage_amount * 0.1)

func _on_player_died():
	# Handle death - disable input, play death animation, etc.
	set_physics_process(false)
	GameManager.player_died.emit()

func _on_health_changed(current: int, maximum: int):
	# Update UI
	GameManager.update_health_ui(current, maximum)

func _on_weapon_fired(projectile_count: int):
	# Add slight camera shake for weapon firing
	var level = get_tree().get_first_node_in_group("levels") as BaseLevel
	if level:
		level.add_camera_shake(1.0)

# ===================================
# VISUAL EFFECTS
# ===================================

func _flash_damage():
	if is_flashing:
		return
	
	is_flashing = true
	var original_color = mesh_instance.get_surface_override_material(0)
	
	# Create material if none exists
	var flash_material = StandardMaterial3D.new()
	flash_material.albedo_color = damage_flash_color
	flash_material.emission_enabled = true
	flash_material.emission = damage_flash_color
	
	mesh_instance.set_surface_override_material(0, flash_material)
	
	# Tween back to normal
	var tween = create_tween()
	tween.tween_interval(damage_flash_duration)
	tween.tween_callback(_end_damage_flash)

func _end_damage_flash():
	is_flashing = false
	mesh_instance.set_surface_override_material(0, null)

# ===================================
# UTILITY METHODS
# ===================================

func _play_sound(sound: AudioStream):
	if sound and audio_player:
		audio_player.stream = sound
		audio_player.play()

func get_facing_direction() -> int:
	return 1 if facing_right else -1

func is_moving() -> bool:
	return abs(velocity.x) > 10.0

func get_health_component() -> HealthComponent:
	return health_component

func get_weapon_component() -> WeaponComponent:
	return weapon_component

# ===================================
# PUBLIC METHODS FOR EXTERNAL CONTROL
# ===================================

func set_invincible(invincible: bool):
	if health_component:
		health_component.is_invincible = invincible

func add_health(amount: int):
	if health_component:
		health_component.heal(amount)

func set_weapon(weapon_data: WeaponData):
	if weapon_component:
		weapon_component.set_weapon(weapon_data)
