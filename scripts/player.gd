#player.gd

extends CharacterBody3D
class_name Player

signal player_died

# Movement Settings (exported for tuning)
@export_group("Movement")
@export var move_speed: float = 8.0
@export var jump_velocity: float = 12.0
@export var gravity: float = 25.0
@export var acceleration: float = 40.0
@export var deceleration: float = 50.0
@export var air_control: float = 0.6

@export_group("Physics")
@export var max_fall_speed: float = 20.0
@export var coyote_time: float = 0.1
@export var jump_buffer: float = 0.1

# Animation Settings
@export_group("Animation")
@export var turn_speed: float = 10.0  # How fast character turns around

# Internal state
var is_alive: bool = true
var coyote_timer: float = 0.0
var jump_buffer_timer: float = 0.0
var was_on_floor: bool = false
var facing_direction: int = 1  # 1 = right, -1 = left
var is_moving: bool = false
var is_jumping: bool = false
var is_firing: bool = false

# Components
@onready var animation_player: AnimationPlayer = $YBot/AnimationPlayer
@onready var character_model: Node3D = $YBot
@onready var collision_shape = $CollisionShape3D

func _ready():
	setup_player_collision()
	setup_animations()

func setup_player_collision():
	# Set up collision for the character
	if collision_shape.shape == null:
		var capsule_shape = CapsuleShape3D.new()
		capsule_shape.radius = 0.4
		capsule_shape.height = 1.8
		collision_shape.shape = capsule_shape

func setup_animations():
	if animation_player:
		# Start with idle animation
		play_animation("rifle aiming idle/mixamo_com")
		print("Animation Player found with animations: ", animation_player.get_animation_list())
	else:
		print("WARNING: No AnimationPlayer found! Make sure XBot is properly imported.")

func _physics_process(delta):
	if not is_alive:
		return
	
	handle_input()
	handle_gravity(delta)
	handle_jumping(delta)
	handle_movement(delta)
	handle_character_facing(delta)
	update_animations()
	
	was_on_floor = is_on_floor()
	move_and_slide()

func handle_input():
	# Check for firing input
	is_firing = Input.is_action_pressed("fire")
	
	# Movement input
	var input_dir = Input.get_axis("move_left", "move_right")
	is_moving = abs(input_dir) > 0.1

func handle_gravity(delta):
	if not is_on_floor():
		velocity.y -= gravity * delta
		velocity.y = max(velocity.y, -max_fall_speed)
	
	# Update jumping state
	is_jumping = not is_on_floor() and velocity.y > 0

func handle_jumping(delta):
	# Update timers
	if was_on_floor and not is_on_floor():
		coyote_timer = coyote_time
	elif coyote_timer > 0:
		coyote_timer -= delta
	
	if jump_buffer_timer > 0:
		jump_buffer_timer -= delta
	
	# Check for jump input
	if Input.is_action_just_pressed("jump"):
		jump_buffer_timer = jump_buffer
	
	# Execute jump
	if jump_buffer_timer > 0 and (is_on_floor() or coyote_timer > 0):
		velocity.y = jump_velocity
		jump_buffer_timer = 0
		coyote_timer = 0

func handle_movement(delta):
	var input_dir = Input.get_axis("move_left", "move_right")
	var target_speed = input_dir * move_speed
	
	# Update facing direction based on movement
	if abs(input_dir) > 0.1:
		facing_direction = sign(input_dir)
	
	var control_factor = 1.0 if is_on_floor() else air_control
	var accel = acceleration if abs(input_dir) > 0 else deceleration
	
	velocity.x = move_toward(velocity.x, target_speed, accel * control_factor * delta)

func handle_character_facing(delta):
	if character_model:
		# Determine target rotation based on facing direction
		var target_y_rotation = 0.0 if facing_direction > 0 else PI
		
		# Smoothly rotate the character model
		var current_rotation = character_model.rotation.y
		var new_rotation = lerp_angle(current_rotation, target_y_rotation, turn_speed * delta)
		character_model.rotation.y = new_rotation

func update_animations():
	if not animation_player:
		return
	
	# Determine which animation to play based on state
	var target_animation = get_target_animation()
	play_animation(target_animation)

func get_target_animation() -> String:
	# Priority order: jumping -> firing -> moving -> idle
	
	if is_jumping:
		return "rifle jump/mixamo_com"
	
	if is_firing and is_on_floor():
		return "firing rifle/mixamo_com"
	
	if is_moving and is_on_floor():
		# Check if we're moving backwards while aiming
		var movement_dir = sign(velocity.x)
		if movement_dir != 0 and movement_dir != facing_direction:
			return "run backwards/mixamo_com"
		else:
			return "rifle run/mixamo_com"
	
	return "rifle aiming idle/mixamo_com"

func play_animation(anim_name: String):
	if animation_player and animation_player.has_animation(anim_name):
		if animation_player.current_animation != anim_name:
			animation_player.play(anim_name)
	else:
		print("Animation not found: ", anim_name)

func apply_knockback(force: Vector3):
	if is_alive:
		velocity += force

func take_hit():
	"""Play hit reaction animation"""
	if is_alive and animation_player:
		play_animation("hit reaction/mixamo_com")
		# You might want to add invincibility frames here

func die():
	if not is_alive:
		return
	
	print("Player is dying...")
	is_alive = false
	
	# TODO: Death animation, ragdoll physics, etc.
	
	player_died.emit()

func _input(event):
	if event.is_action_pressed("ui_accept"):
		print("Player position: ", global_position)
		print("Current animation: ", animation_player.current_animation if animation_player else "No AnimationPlayer")
