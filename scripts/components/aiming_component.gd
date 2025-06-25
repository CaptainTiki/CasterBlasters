# aiming_controller.gd
extends Node3D
class_name AimingController

signal aim_direction_changed(direction_name: String)

# Input mode enum
enum InputMode {
	MOUSE,
	CONTROLLER
}

# Aiming directions
enum AimDirection {
	UP = 0,
	UP_FORWARD = 1,
	FORWARD = 2,
	DOWN_FORWARD = 3,
	DOWN = 4
}

# Export variables
@export var player: Player
@export var animation_tree: AnimationTree
@export var mouse_sensitivity: float = 0.3
@export var controller_deadzone: float = 0.2
@export var transition_speed: float = 10.0
@export var debug_mode: bool = true

# Current state
var current_input_mode: InputMode = InputMode.MOUSE
var current_aim_direction: AimDirection = AimDirection.FORWARD
var target_aim_direction: AimDirection = AimDirection.FORWARD
var aim_blend_position: Vector2 = Vector2.ZERO
var is_aiming_extreme: bool = false  # For straight up/down aiming

# Mouse aiming
var viewport_center: Vector2
var mouse_relative_y: float = 0.0

# Controller aiming
var controller_aim_input: Vector2 = Vector2.ZERO

# Animation state names
const STATE_LOCOMOTION = "LocomotionState"
const STATE_COMBAT = "CombatState"
const STATE_JUMP = "JumpState"

# Aiming angle thresholds (in normalized values -1 to 1)
const THRESHOLD_UP = 0.6
const THRESHOLD_UP_FORWARD = 0.3
const THRESHOLD_DOWN_FORWARD = -0.3
const THRESHOLD_DOWN = -0.6

func _ready():
	setup_viewport()
	
	if not player:
		player = get_parent().get_parent() as Player
		if not player:
			push_error("AimingController: No player reference found!")
	
	if not animation_tree:
		animation_tree = player.get_node("AnimationTree")
		if not animation_tree:
			push_error("AimingController: No AnimationTree found!")
	
	print("🎯 AimingController initialized - Mode: ", get_input_mode_name())

func setup_viewport():
	viewport_center = get_viewport().get_visible_rect().size / 2.0

func _process(delta):
	if not player or not player.is_alive:
		return
	
	# Update input mode and gather input
	update_input_mode()
	gather_aim_input(delta)
	
	# Calculate target aim direction
	calculate_aim_direction()
	
	# Smoothly transition aim
	update_aim_blend(delta)
	
	# Update animation tree
	update_animation_state()

func update_input_mode():
	"""Detect and switch between mouse and controller input"""
	# Check for controller input
	var controller_input = Input.get_vector("move_left", "move_right", "move_up", "move_down")
	var has_controller_input = controller_input.length() > controller_deadzone
	
	# Check for significant mouse movement
	var mouse_delta = Input.get_last_mouse_velocity().length()
	var has_mouse_input = mouse_delta > 10.0

func gather_aim_input(delta):
	"""Gather aim input based on current input mode"""
	match current_input_mode:
		InputMode.MOUSE:
			gather_mouse_input()
		InputMode.CONTROLLER:
			gather_controller_input()

func gather_mouse_input():
	"""Calculate aim based on mouse position relative to screen center"""
	var mouse_pos = get_viewport().get_mouse_position()
	var screen_size = get_viewport().get_visible_rect().size
	
	# Normalize mouse Y position (-1 to 1, where -1 is top, 1 is bottom)
	mouse_relative_y = ((mouse_pos.y / screen_size.y) - 0.5) * 2.0
	mouse_relative_y = clamp(mouse_relative_y, -1.0, 1.0)
	
	# Check if we have horizontal movement input
	var move_input = Input.get_axis("move_left", "move_right")
	is_aiming_extreme = abs(move_input) < 0.1

func gather_controller_input():
	"""Calculate aim based on controller stick input"""
	# Get left stick for combined movement/aiming
	var left_stick = Input.get_vector("move_left", "move_right", "move_up", "move_down")
	
	# Apply deadzone
	if left_stick.length() < controller_deadzone:
		controller_aim_input = Vector2.ZERO
		is_aiming_extreme = true
	else:
		controller_aim_input = left_stick.normalized()
		# Check if we're aiming straight up/down (no horizontal input)
		is_aiming_extreme = abs(controller_aim_input.x) < 0.1

func calculate_aim_direction():
	"""Convert input to discrete aim direction"""
	var aim_value: float = 0.0
	
	# Get the vertical aim value based on input mode
	match current_input_mode:
		InputMode.MOUSE:
			aim_value = -mouse_relative_y  # Inverted because screen Y is down
		InputMode.CONTROLLER:
			aim_value = -controller_aim_input.y  # Controller Y is already correct
	
	# Handle extreme aiming (straight up/down) when no horizontal movement
	if is_aiming_extreme:
		if aim_value > THRESHOLD_UP_FORWARD:
			target_aim_direction = AimDirection.UP
		elif aim_value < THRESHOLD_DOWN_FORWARD:
			target_aim_direction = AimDirection.DOWN
		else:
			target_aim_direction = AimDirection.FORWARD
	else:
		# Normal 45-degree increment aiming
		if aim_value > THRESHOLD_UP:
			target_aim_direction = AimDirection.UP_FORWARD
		elif aim_value > THRESHOLD_UP_FORWARD:
			target_aim_direction = AimDirection.UP_FORWARD
		elif aim_value < THRESHOLD_DOWN:
			target_aim_direction = AimDirection.DOWN_FORWARD
		elif aim_value < THRESHOLD_DOWN_FORWARD:
			target_aim_direction = AimDirection.DOWN_FORWARD
		else:
			target_aim_direction = AimDirection.FORWARD
	
	# Emit signal if direction changed
	if target_aim_direction != current_aim_direction:
		current_aim_direction = target_aim_direction
		aim_direction_changed.emit(get_aim_direction_name())

func update_aim_blend(delta):
	"""Smoothly transition the blend position for animations"""
	var target_blend = get_blend_position_for_direction(current_aim_direction)
	aim_blend_position = aim_blend_position.lerp(target_blend, transition_speed * delta)

func get_blend_position_for_direction(direction: AimDirection) -> Vector2:
	"""Convert aim direction to blend tree position"""
	# X axis: movement (will be set by player movement)
	# Y axis: aim direction
	match direction:
		AimDirection.UP:
			return Vector2(0, 1.0)
		AimDirection.UP_FORWARD:
			return Vector2(0, 0.5)
		AimDirection.FORWARD:
			return Vector2(0, 0.0)
		AimDirection.DOWN_FORWARD:
			return Vector2(0, -0.5)
		AimDirection.DOWN:
			return Vector2(0, -1.0)
	
	return Vector2.ZERO

func update_animation_state():
	"""Update the animation tree with current aim blend"""
	if not animation_tree:
		return
	
	# Get movement input for X axis of blend space
	var move_input = Input.get_axis("move_left", "move_right")
	var movement_blend = move_input * player.facing_direction
	
	# Combine movement and aim for final blend position
	var final_blend = Vector2(movement_blend, aim_blend_position.y)
	
	# Update the blend position
	animation_tree.set("parameters/" + STATE_LOCOMOTION + "/blend_position", final_blend)
	
	# Handle state transitions
	if player.is_jumping:
		animation_tree.set("parameters/conditions/is_jumping", true)
	else:
		animation_tree.set("parameters/conditions/is_jumping", false)
	
	if player.is_firing:
		animation_tree.set("parameters/conditions/is_firing", true)
	else:
		animation_tree.set("parameters/conditions/is_firing", false)

func get_aim_direction_vector() -> Vector3:
	"""Get the world-space aim direction for projectiles"""
	var base_forward = Vector3.FORWARD * player.facing_direction
	
	match current_aim_direction:
		AimDirection.UP:
			return Vector3.UP
		AimDirection.UP_FORWARD:
			return (base_forward + Vector3.UP).normalized()
		AimDirection.FORWARD:
			return base_forward
		AimDirection.DOWN_FORWARD:
			return (base_forward + Vector3.DOWN).normalized()
		AimDirection.DOWN:
			return Vector3.DOWN
	
	return base_forward

func get_aim_angle_degrees() -> float:
	"""Get aim angle in degrees for weapon rotation"""
	match current_aim_direction:
		AimDirection.UP:
			return 90.0
		AimDirection.UP_FORWARD:
			return 45.0
		AimDirection.FORWARD:
			return 0.0
		AimDirection.DOWN_FORWARD:
			return -45.0
		AimDirection.DOWN:
			return -90.0
	
	return 0.0

func get_aim_direction_name() -> String:
	"""Get human-readable aim direction"""
	match current_aim_direction:
		AimDirection.UP:
			return "UP"
		AimDirection.UP_FORWARD:
			return "UP_FORWARD"
		AimDirection.FORWARD:
			return "FORWARD"
		AimDirection.DOWN_FORWARD:
			return "DOWN_FORWARD"
		AimDirection.DOWN:
			return "DOWN"
	
	return "UNKNOWN"

func get_input_mode_name() -> String:
	"""Get human-readable input mode"""
	match current_input_mode:
		InputMode.MOUSE:
			return "MOUSE"
		InputMode.CONTROLLER:
			return "CONTROLLER"
	
	return "UNKNOWN"

func get_blend_position() -> Vector2:
	"""Get current blend position for debugging"""
	return aim_blend_position

func _input(event):
	"""Handle debug input for switching modes manually"""
	if debug_mode:
		if event.is_action_pressed("switch_input_mode"):
			current_input_mode = InputMode.CONTROLLER if current_input_mode == InputMode.MOUSE else InputMode.MOUSE
			print("🔄 Manually switched to: ", get_input_mode_name())
		
		if event.is_action_pressed("debug_aim_info"):
			print("🎯 Aim Debug Info:")
			print("  Input Mode: ", get_input_mode_name())
			print("  Aim Direction: ", get_aim_direction_name())
			print("  Blend Position: ", aim_blend_position)
			print("  Is Extreme Aim: ", is_aiming_extreme)
			if current_input_mode == InputMode.MOUSE:
				print("  Mouse Y: ", mouse_relative_y)
			else:
				print("  Controller Input: ", controller_aim_input)
