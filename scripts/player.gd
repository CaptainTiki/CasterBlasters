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
@onready var animation_tree: AnimationTree = $AnimationTree
@onready var character_model: Node3D = $YBot
@onready var collision_shape = $CollisionShape3D
@onready var aiming_controller: AimingController = $Components/AimingController
@onready var weapon_component: WeaponComponent = $Components/WeaponComponent

func _ready():
	setup_player_collision()
	setup_animation_tree()
	setup_aiming()

func setup_player_collision():
	# Set up collision for the character
	if collision_shape.shape == null:
		var capsule_shape = CapsuleShape3D.new()
		capsule_shape.radius = 0.4
		capsule_shape.height = 1.8
		collision_shape.shape = capsule_shape

func setup_animation_tree():
	"""Initialize the AnimationTree system"""
	if animation_tree:
		print("🎭 AnimationTree found and ready!")
		# Ensure the animation tree is active
		animation_tree.active = true
	else:
		print("❌ WARNING: No AnimationTree found! Make sure to add one to the scene.")

func setup_aiming():
	"""Connect the aiming controller"""
	if aiming_controller:
		aiming_controller.aim_direction_changed.connect(_on_aim_direction_changed)
		print("🎯 Aiming controller connected!")
	else:
		print("❌ WARNING: No AimingController found!")

func _physics_process(delta):
	if not is_alive:
		return
	
	handle_input()
	handle_gravity(delta)
	handle_jumping(delta)
	handle_movement(delta)
	handle_character_facing(delta)
	handle_firing()
	
	# Animation updates are handled by AimingController
	
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
	var previous_jumping = is_jumping
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

func handle_firing():
	"""Handle weapon firing with aiming direction integration"""
	if weapon_component:
		if is_firing:
			weapon_component.start_firing()
		else:
			weapon_component.stop_firing()

func _on_aim_direction_changed(direction_name: String):
	"""Respond to aiming direction changes from AimingController"""
	# Here you can add any player-specific responses to aiming changes
	# For example: sound effects, UI updates, special abilities, etc.
	pass

func apply_knockback(force: Vector3):
	if is_alive:
		velocity += force

func take_hit():
	"""Play hit reaction"""
	if is_alive:
		# Trigger hit reaction through AnimationTree if you have one-shot nodes set up
		if animation_tree and animation_tree.has_parameter("trigger_hit"):
			animation_tree.set("parameters/trigger_hit", true)
		print("💥 Player hit!")

func die():
	if not is_alive:
		return
	
	print("💀 Player is dying...")
	is_alive = false
	
	# Trigger death animation through AnimationTree if available
	if animation_tree and animation_tree.has_parameter("trigger_death"):
		animation_tree.set("parameters/trigger_death", true)
	
	player_died.emit()

func _input(event):
	if event.is_action_pressed("debug_player_info"):
		print("🎮 Player Debug Info:")
		print("  Position: ", global_position)
		print("  Facing: ", "RIGHT" if facing_direction > 0 else "LEFT")
		print("  Moving: ", is_moving)
		print("  Jumping: ", is_jumping)
		print("  Firing: ", is_firing)
		print("  Velocity: ", velocity)
		
		if aiming_controller:
			print("  Input Mode: ", aiming_controller.get_input_mode_name())
			print("  Aim Direction: ", aiming_controller.get_aim_direction_name())
			print("  Blend Position: ", aiming_controller.get_blend_position())

# Getter functions for external systems
func get_aim_direction_vector() -> Vector3:
	"""Get the aiming direction for weapon/projectile systems"""
	if aiming_controller:
		return aiming_controller.get_aim_direction_vector()
	else:
		return Vector3.FORWARD * facing_direction

func get_aim_angle_degrees() -> float:
	"""Get aim angle for weapon systems"""
	if aiming_controller:
		return aiming_controller.get_aim_angle_degrees()
	else:
		return 0.0

func get_weapon_mount_position() -> Vector3:
	"""Get the position where weapons should be mounted"""
	# This would typically be a bone attachment point
	# For now, return a position relative to the player
	return global_position + Vector3(0.5 * facing_direction, 1.0, 0)
