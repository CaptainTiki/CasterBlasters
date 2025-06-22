# aiming_controller.gd
extends Node
class_name AimingController

signal aim_direction_changed(direction_name: String)

enum AimDirection {
	UP,
	FORWARD_UP,
	FORWARD,
	FORWARD_DOWN,
	DOWN
}

enum InputMode {
	MOUSE_KEYBOARD,
	CONTROLLER
}

# Export settings
@export_group("Aiming Settings")
@export var mouse_sensitivity: float = 1.0
@export var controller_sensitivity: float = 2.0
@export var aim_deadzone: float = 0.1
@export var blend_smoothing: float = 8.0  # How fast blendspace responds

# References
@export var player: Player
@export var animation_tree: AnimationTree

# Input mode system
var current_input_mode: InputMode = InputMode.MOUSE_KEYBOARD
var input_mode_names = {
	InputMode.MOUSE_KEYBOARD: "MOUSE_KEYBOARD",
	InputMode.CONTROLLER: "CONTROLLER"
}

# Animation state tracking
var current_aim_direction: AimDirection = AimDirection.FORWARD
var current_blend_position: Vector2 = Vector2.ZERO
var target_blend_position: Vector2 = Vector2.ZERO

# BlendSpace parameters (these match your AnimationTree setup)
var locomotion_blend_space_path = "parameters/LocomotionState/blend_position"
var combat_blend_space_path = "parameters/CombatState/blend_position"
var state_machine_path = "parameters/playback"

func _ready():
	setup_animation_tree()
	print("🎭 Animation Tree Conductor initialized!")
	print("   Press \\ to cycle input modes!")

func setup_animation_tree():
	if not animation_tree:
		print("❌ ERROR: No AnimationTree assigned!")
		return
	
	if not animation_tree.tree_root:
		print("❌ ERROR: AnimationTree has no root node!")
		return
	
	# Start the animation tree
	animation_tree.active = true
	
	# Set initial state to Locomotion
	var state_machine: AnimationNodeStateMachinePlayback = animation_tree.get(state_machine_path)
	if state_machine:
		state_machine.start("LocomotionState")
		print("✅ AnimationTree started in Locomotion state!")
	else:
		print("❌ Could not find StateMachine playback!")

func _input(event):
	if event.is_action_pressed("cycle_input_mode"):
		cycle_input_mode()
	
	# MASTER DEBUG COMMAND! 🔍
	if event.is_action_pressed("ui_accept"):
		print_complete_debug_info()

func cycle_input_mode():
	match current_input_mode:
		InputMode.MOUSE_KEYBOARD:
			current_input_mode = InputMode.CONTROLLER
		InputMode.CONTROLLER:
			current_input_mode = InputMode.MOUSE_KEYBOARD
	
	print("🎮 Input Mode: ", input_mode_names[current_input_mode])

func _process(delta):
	if not player or not animation_tree:
		return
	
	update_aiming_input()
	update_movement_blending(delta)
	update_animation_states()

func update_aiming_input():
	"""Calculate aim input and convert to blend space coordinates"""
	var aim_input = get_aim_input()
	var new_direction = calculate_aim_direction(aim_input)
	
	# Convert to blend space position
	target_blend_position = aim_input_to_blend_position(aim_input)
	
	if new_direction != current_aim_direction:
		current_aim_direction = new_direction
		aim_direction_changed.emit(get_aim_direction_name())
		print("🎯 Aim: ", get_aim_direction_name(), " | Blend: ", target_blend_position)

func get_aim_input() -> Vector2:
	match current_input_mode:
		InputMode.MOUSE_KEYBOARD:
			return get_mouse_keyboard_input()
		InputMode.CONTROLLER:
			return get_controller_input()
		_:
			return Vector2.ZERO

func get_mouse_keyboard_input() -> Vector2:
	# Mouse Y for vertical aiming, keyboard X for horizontal movement
	if Input.get_mouse_mode() == Input.MOUSE_MODE_CAPTURED:
		return Vector2.ZERO
	
	var mouse_pos = get_viewport().get_mouse_position()
	var screen_center = get_viewport().get_visible_rect().size / 2
	var mouse_y_offset = (mouse_pos.y - screen_center.y) / screen_center.y
	mouse_y_offset *= mouse_sensitivity
	
	var keyboard_x_input = Input.get_action_strength("move_right") - Input.get_action_strength("move_left")
	
	return Vector2(keyboard_x_input, mouse_y_offset)

func get_controller_input() -> Vector2:
	var controller_input = Vector2(
		Input.get_action_strength("move_right") - Input.get_action_strength("move_left"),
		Input.get_action_strength("move_down") - Input.get_action_strength("move_up")
	)
	
	if controller_input.length() > aim_deadzone:
		return controller_input * controller_sensitivity
	else:
		return Vector2.ZERO

func calculate_aim_direction(aim_input: Vector2) -> AimDirection:
	"""Convert input to discrete aim direction for gameplay logic"""
	if aim_input.length() < 0.1:
		return AimDirection.FORWARD
	
	# Pure vertical inputs
	if abs(aim_input.x) < 0.1:
		if aim_input.y < -0.5:
			return AimDirection.UP
		elif aim_input.y > 0.5:
			return AimDirection.DOWN
	
	# Pure horizontal
	if abs(aim_input.y) < 0.1:
		return AimDirection.FORWARD
	
	# Diagonal combinations
	if aim_input.y < -0.1:
		return AimDirection.FORWARD_UP
	elif aim_input.y > 0.1:
		return AimDirection.FORWARD_DOWN
	else:
		return AimDirection.FORWARD

func aim_input_to_blend_position(aim_input: Vector2) -> Vector2:
	"""Convert raw input to BlendSpace2D coordinates"""
	# X-axis: Movement (for locomotion blending)
	# Y-axis: Aiming direction (for vertical aim blending)
	
	# Clamp and smooth the input
	var blend_x = clamp(aim_input.x, -1.0, 1.0)
	var blend_y = clamp(aim_input.y, -1.0, 1.0)
	
	return Vector2(blend_x, blend_y)

func update_movement_blending(delta):
	"""Smooth blend position updates for natural animation transitions"""
	if not animation_tree:
		return
	
	# Smooth interpolation to target position
	current_blend_position = current_blend_position.lerp(target_blend_position, blend_smoothing * delta)
	
	# Apply to animation tree blend spaces
	animation_tree.set(locomotion_blend_space_path, current_blend_position)
	
	# If in combat state, also update combat blend space
	var state_machine: AnimationNodeStateMachinePlayback = animation_tree.get(state_machine_path)
	if state_machine and state_machine.get_current_node() == "CombatState":
		animation_tree.set(combat_blend_space_path, current_blend_position)

func update_animation_states():
	"""Handle state transitions based on player actions"""
	if not animation_tree or not player:
		return
	
	var state_machine: AnimationNodeStateMachinePlayback = animation_tree.get(state_machine_path)
	if not state_machine:
		print("❌ ERROR: Could not get StateMachine playback!")
		return
	
	var current_state = state_machine.get_current_node()
	
	# DETECTIVE WORK - Let's see what's happening!
	# Only print when state changes to reduce console spam
	var should_debug = false
	
	# Handle jumping
	if player.is_jumping and current_state != "JumpState":
		state_machine.travel("JumpState")
		print("🦘 Transitioning to Jump!")
		should_debug = true
		return
	
	# Handle combat vs locomotion
	if player.is_firing and current_state == "LocomotionState":
		state_machine.travel("CombatState")
		print("💥 Transitioning to Combat!")
		should_debug = true
	elif not player.is_firing and current_state == "CombatState":
		state_machine.travel("LocomotionState")
		print("🚶 Transitioning to Locomotion!")
		should_debug = true
	
	# Return from jump to appropriate state
	if not player.is_jumping and current_state == "JumpState":
		if player.is_firing:
			state_machine.travel("CombatState")
			print("🎯 Landing in Combat mode!")
		else:
			state_machine.travel("LocomotionState")
			print("🎯 Landing in Locomotion mode!")
		should_debug = true
	
	# Print detailed debug info only during state changes
	if should_debug:
		print("  📊 State: ", current_state, " → Jumping: ", player.is_jumping, " | Firing: ", player.is_firing)

func get_aim_direction_name() -> String:
	match current_aim_direction:
		AimDirection.UP:
			return "UP"
		AimDirection.FORWARD_UP:
			return "FORWARD_UP"
		AimDirection.FORWARD:
			return "FORWARD"
		AimDirection.FORWARD_DOWN:
			return "FORWARD_DOWN"
		AimDirection.DOWN:
			return "DOWN"
		_:
			return "UNKNOWN"

func get_current_input_mode_name() -> String:
	return input_mode_names[current_input_mode]

func get_blend_position() -> Vector2:
	"""Get current blend position for debugging"""
	return current_blend_position

func get_aim_direction_vector() -> Vector3:
	"""Convert current aim direction to world space vector for weapon systems"""
	var angle_radians = deg_to_rad(get_aim_angle_degrees())
	var direction = Vector3(0, sin(angle_radians), cos(angle_radians))
	
	# Apply character facing direction
	if player and player.facing_direction < 0:
		direction.x *= -1
	
	return direction

func get_aim_angle_degrees() -> float:
	"""Get aim angle in degrees for weapon/projectile systems"""
	match current_aim_direction:
		AimDirection.UP:
			return -90.0
		AimDirection.FORWARD_UP:
			return -45.0
		AimDirection.FORWARD:
			return 0.0
		AimDirection.FORWARD_DOWN:
			return 45.0
		AimDirection.DOWN:
			return 90.0
		_:
			return 0.0

func print_complete_debug_info():
	"""The Ultimate Animation System Detective Report! 🕵️‍♂️"""
	print("\n🔍 ==================== ANIMATION SYSTEM DEBUG REPORT ====================")
	
	if not player:
		print("❌ CRITICAL: No player reference!")
		return
	
	if not animation_tree:
		print("❌ CRITICAL: No animation tree reference!")
		return
	
	print("🎭 ANIMATION TREE STATUS:")
	print("  Active: ", animation_tree.active)
	print("  Tree Root: ", animation_tree.tree_root)
	
	var state_machine: AnimationNodeStateMachinePlayback = animation_tree.get(state_machine_path)
	if state_machine:
		print("  Current State: ", state_machine.get_current_node())
		print("  Travel Path: ", state_machine.get_travel_path())
	else:
		print("  ❌ StateMachine: NOT FOUND!")
	
	# 🦘 JUMP ANIMATION INVESTIGATION!
	print("\n🦘 JUMP STATE INVESTIGATION:")
	var jump_state_node = animation_tree.tree_root.get_node("JumpState")
	if jump_state_node:
		print("  JumpState Node Found: ✅")
		print("  Node Type: ", jump_state_node.get_class())
		
		# Try different methods to get the animation info
		if jump_state_node.has_method("get_animation"):
			var jump_anim = jump_state_node.get_animation()
			print("  Jump Animation (method): ", jump_anim)
		elif "animation" in jump_state_node:
			var jump_anim = jump_state_node.animation
			print("  Jump Animation (property): ", jump_anim)
		else:
			print("  🔍 Investigating available properties...")
			var property_list = jump_state_node.get_property_list()
			for prop in property_list:
				if "anim" in prop.name.to_lower():
					print("    Found animation-related property: ", prop.name, " = ", jump_state_node.get(prop.name))
		
		# Check if animation exists in AnimationPlayer
		var anim_player = get_node("../YBot/AnimationPlayer") if has_node("../YBot/AnimationPlayer") else null
		if anim_player:
			print("  📚 Available animations in AnimationPlayer:")
			var anim_list = anim_player.get_animation_list()
			for anim_name in anim_list:
				print("    - '", anim_name, "'")
				if "jump" in anim_name.to_lower():
					print("      ^ This looks like a jump animation! 🦘")
		else:
			print("  ❌ AnimationPlayer not found!")
	else:
		print("  ❌ JumpState Node: NOT FOUND!")
	
	print("\n🎮 PLAYER STATUS:")
	print("  Position: ", player.global_position)
	print("  Velocity: ", player.velocity)
	print("  is_on_floor(): ", player.is_on_floor())
	print("  is_jumping: ", player.is_jumping)
	print("  is_firing: ", player.is_firing)
	print("  is_moving: ", player.is_moving)
	print("  facing_direction: ", player.facing_direction)
	
	print("\n🎯 AIMING STATUS:")
	print("  Current Aim Direction: ", get_aim_direction_name())
	print("  Target Blend Position: ", target_blend_position)
	print("  Current Blend Position: ", current_blend_position)
	print("  Input Mode: ", get_current_input_mode_name())
	
	print("\n📊 BLENDSPACE VALUES:")
	if animation_tree.active:
		var locomotion_blend = animation_tree.get(locomotion_blend_space_path)
		var combat_blend = animation_tree.get(combat_blend_space_path)
		print("  Locomotion BlendSpace: ", locomotion_blend)
		print("  Combat BlendSpace: ", combat_blend)
	else:
		print("  ❌ AnimationTree not active - no blend values!")
	
	print("🔍 ========================================================================\n")
