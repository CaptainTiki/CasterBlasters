# skeletal_aiming_modifier.gd - THE BONE COMMANDER! 🦴⚔️
extends SkeletonModifier3D
class_name SkeletalAimingModifier

# This runs AFTER AnimationTree and adjusts bones for aiming
# Think of this as the "fine-tuning conductor" after the main orchestra plays!

@export_group("Aiming Control")
@export var aim_strength: float = 0.8  # How much to override animation (0.0 to 1.0)
@export var spine_influence: float = 0.4  # How much spine contributes
@export var arm_influence: float = 0.9   # How much arms contribute
@export var smoothing_speed: float = 12.0  # How fast we interpolate

@export_group("Bone Configuration - Mixamo Rig")
@export var spine_bone_names: Array[String] = [
	"mixamorig_Spine",
	"mixamorig_Spine1", 
	"mixamorig_Spine2"
]
@export var right_arm_bone_name: String = "mixamorig_RightArm"
@export var left_arm_bone_name: String = "mixamorig_LeftArm"
@export var right_shoulder_name: String = "mixamorig_RightShoulder"
@export var left_shoulder_name: String = "mixamorig_LeftShoulder"

@export_group("Debug & Visualization")
@export var enable_debug_prints: bool = true
@export var show_bone_gizmos: bool = false

# Aiming state - our magical targeting system! 🎯
var current_aim_angle: float = 0.0  # In radians
var target_aim_angle: float = 0.0
var last_aim_direction: String = ""

# Bone indices (cached for SPEED!) ⚡
var spine_bone_indices: Array[int] = []
var right_arm_bone_idx: int = -1
var left_arm_bone_idx: int = -1
var right_shoulder_idx: int = -1
var left_shoulder_idx: int = -1

# References to other components
var aiming_controller: AimingController
var player: Player
var skeleton: Skeleton3D

# Performance tracking
var bones_found: bool = false
var last_bone_search_time: float = 0.0

func _ready():
	if enable_debug_prints:
		print("🦴 === SKELETAL AIMING MODIFIER - BONE COMMANDER ACTIVATED! ===")
	
	# Find our components with some detective work! 🕵️‍♂️
	_find_components()
	
	# Give the skeleton a moment to be ready
	call_deferred("_delayed_setup")

func _delayed_setup():
	"""Give everything a chance to initialize before we start bone hunting!"""
	skeleton = get_skeleton()
	if skeleton:
		_discover_bone_structure()
	else:
		if enable_debug_prints:
			print("❌ CRITICAL: No skeleton found! Are we attached to the right node?")

func _find_components():
	"""Hunt down our aiming controller and player like a bone-sniffing detective! 🔍"""
	
	# Try multiple paths to find the aiming controller
	var possible_paths = [
		"../../Components/AimingController",
		"../Components/AimingController", 
		"../../AimingController",
		"../AimingController"
	]
	
	for path in possible_paths:
		if has_node(path):
			aiming_controller = get_node(path)
			break
	
	if aiming_controller:
		aiming_controller.aim_direction_changed.connect(_on_aim_direction_changed)
		if enable_debug_prints:
			print("  🎯 Connected to AimingController!")
	else:
		if enable_debug_prints:
			print("  ❌ WARNING: Could not find AimingController!")
	
	# Find the player
	player = get_node("../../../") if has_node("../../../") else null
	if player and enable_debug_prints:
		print("  🎮 Found Player reference!")

func _discover_bone_structure():
	"""Map out the bone kingdom like a skeletal cartographer! 🗺️"""
	if not skeleton:
		return
	
	if enable_debug_prints:
		print("🦴 === BONE DISCOVERY EXPEDITION ===")
		print("  Total bones in skeleton: ", skeleton.get_bone_count())
	
	# Clear previous discoveries
	spine_bone_indices.clear()
	
	# Hunt for spine bones
	for spine_name in spine_bone_names:
		var bone_idx = skeleton.find_bone(spine_name)
		if bone_idx != -1:
			spine_bone_indices.append(bone_idx)
			if enable_debug_prints:
				print("  🎯 Found spine bone: ", spine_name, " at index ", bone_idx)
		else:
			if enable_debug_prints:
				print("  ❓ Spine bone not found: ", spine_name)
	
	# Hunt for arm bones
	right_arm_bone_idx = skeleton.find_bone(right_arm_bone_name)
	left_arm_bone_idx = skeleton.find_bone(left_arm_bone_name)
	right_shoulder_idx = skeleton.find_bone(right_shoulder_name)
	left_shoulder_idx = skeleton.find_bone(left_shoulder_name)
	
	if enable_debug_prints:
		print("  🦾 Right Arm: ", right_arm_bone_idx, " (", right_arm_bone_name, ")")
		print("  🦾 Left Arm: ", left_arm_bone_idx, " (", left_arm_bone_name, ")")
		print("  🦾 Right Shoulder: ", right_shoulder_idx, " (", right_shoulder_name, ")")
		print("  🦾 Left Shoulder: ", left_shoulder_idx, " (", left_shoulder_name, ")")
	
	# Check if we found essential bones
	bones_found = spine_bone_indices.size() > 0 or right_arm_bone_idx != -1 or left_arm_bone_idx != -1
	
	if bones_found:
		if enable_debug_prints:
			print("  ✅ Bone discovery successful! Ready to aim! 🎯")
	else:
		if enable_debug_prints:
			print("  ❌ BONE DISCOVERY FAILED! Let's investigate...")
			_debug_print_all_bones()

func _debug_print_all_bones():
	"""Print ALL bones for debugging - our skeletal phonebook! 📞"""
	if not skeleton or not enable_debug_prints:
		return
	
	print("🦴 === COMPLETE BONE INVENTORY ===")
	for i in range(skeleton.get_bone_count()):
		var bone_name = skeleton.get_bone_name(i)
		print("  [", i, "] ", bone_name)
		
		# Highlight bones that contain common keywords
		var lower_name = bone_name.to_lower()
		if "spine" in lower_name or "arm" in lower_name or "shoulder" in lower_name:
			print("    ^ 🎯 This looks promising for aiming!")
	print("🦴 === END BONE INVENTORY ===")

func _process_modification():
	"""THE MAIN EVENT! This is where the magic happens! ✨"""
	
	if not bones_found:
		# Try to rediscover bones periodically
		if Time.get_ticks_msec() - last_bone_search_time > 1000:  # Every second
			_discover_bone_structure()
			last_bone_search_time = Time.get_ticks_msec()
		return
	
	if not skeleton:
		skeleton = get_skeleton()
		return
	
	# Get the current target angle from aiming controller
	_update_target_aim_angle()
	
	# Smoothly interpolate to target angle (buttery smooth! 🧈)
	var delta = get_process_delta_time()
	current_aim_angle = lerp_angle(current_aim_angle, target_aim_angle, smoothing_speed * delta)
	
	# Apply aiming rotations to bones - THE MONEY SHOT! 💰
	_apply_aiming_to_bones()

func _update_target_aim_angle():
	"""Get the target aiming angle from our aiming controller buddy!"""
	if aiming_controller:
		var new_target = deg_to_rad(aiming_controller.get_aim_angle_degrees())
		
		# Only update if there's a significant change (reduce jitter)
		if abs(new_target - target_aim_angle) > 0.01:
			target_aim_angle = new_target

func _apply_aiming_to_bones():
	"""Apply the aiming rotation to our bone squad! 🦴⚔️"""
	
	# Apply to spine bones (distributed across spine chain)
	for i in range(spine_bone_indices.size()):
		var bone_idx = spine_bone_indices[i]
		var spine_factor = spine_influence / spine_bone_indices.size()  # Distribute influence
		_apply_aim_rotation_to_bone(bone_idx, current_aim_angle * spine_factor)
	
	# Apply to shoulders (for better arm positioning)
	if right_shoulder_idx != -1:
		_apply_aim_rotation_to_bone(right_shoulder_idx, current_aim_angle * arm_influence * 0.5)
	if left_shoulder_idx != -1:
		_apply_aim_rotation_to_bone(left_shoulder_idx, current_aim_angle * arm_influence * 0.5)
	
	# Apply to arms (main aiming adjustment)
	if right_arm_bone_idx != -1:
		_apply_aim_rotation_to_bone(right_arm_bone_idx, current_aim_angle * arm_influence)
	if left_arm_bone_idx != -1:
		_apply_aim_rotation_to_bone(left_arm_bone_idx, current_aim_angle * arm_influence)

func _apply_aim_rotation_to_bone(bone_idx: int, rotation_angle: float):
	"""Apply rotation to a specific bone while respecting the animation! 🎭"""
	
	if bone_idx == -1 or not skeleton:
		return
	
	# Get the current pose from the animation (our base choreography)
	var current_pose = skeleton.get_bone_pose_rotation(bone_idx)
	
	# Create the aiming rotation (around X-axis for up/down aiming)
	var aim_rotation = Quaternion.from_euler(Vector3(rotation_angle, 0, 0))
	
	# Blend the aiming rotation with the animation pose
	# This is like adding a "director's note" to the choreography!
	var final_rotation = current_pose.slerp(current_pose * aim_rotation, aim_strength)
	
	# Apply the blended rotation
	skeleton.set_bone_pose_rotation(bone_idx, final_rotation)

func _on_aim_direction_changed(direction_name: String):
	"""Respond to aiming direction changes like a bone-based GPS! 🧭"""
	if direction_name != last_aim_direction:
		last_aim_direction = direction_name
		if enable_debug_prints:
			print("🎯 Skeletal Aiming: Adjusting for ", direction_name, 
				  " (target angle: ", rad_to_deg(target_aim_angle), "°)")

# ===================================
# PUBLIC DEBUG & UTILITY METHODS 🛠️
# ===================================

func set_aim_angle_debug(angle_degrees: float):
	"""For testing - manually set aim angle like a bone puppeteer! 🎭"""
	target_aim_angle = deg_to_rad(angle_degrees)
	if enable_debug_prints:
		print("🎯 Debug: Setting aim angle to ", angle_degrees, "°")

func get_current_aim_degrees() -> float:
	"""Get current aim angle in degrees for debugging"""
	return rad_to_deg(current_aim_angle)

func force_bone_rediscovery():
	"""Force a new bone discovery expedition! 🗺️"""
	bones_found = false
	if skeleton:
		_discover_bone_structure()

func get_bone_discovery_status() -> Dictionary:
	"""Get a full report on our bone discovery mission! 📊"""
	return {
		"bones_found": bones_found,
		"spine_bones": spine_bone_indices.size(),
		"has_right_arm": right_arm_bone_idx != -1,
		"has_left_arm": left_arm_bone_idx != -1,
		"has_right_shoulder": right_shoulder_idx != -1,
		"has_left_shoulder": left_shoulder_idx != -1,
		"current_aim_degrees": get_current_aim_degrees(),
		"target_aim_degrees": rad_to_deg(target_aim_angle)
	}

func _input(event):
	"""Debug input handling - because debugging is an adventure! 🎮"""
	if not enable_debug_prints:
		return
	
	# Press 'B' for bone discovery report
	if event is InputEventKey and event.pressed:
		match event.keycode:
			KEY_B:
				var status = get_bone_discovery_status()
				print("🦴 === BONE STATUS REPORT ===")
				for key in status:
					print("  ", key, ": ", status[key])
				print("🦴 === END REPORT ===")
			
			KEY_R:
				print("🔄 Forcing bone rediscovery...")
				force_bone_rediscovery()
			
			KEY_T:
				print("🎯 Testing aim angles...")
				set_aim_angle_debug(45.0)
				await get_tree().create_timer(1.0).timeout
				set_aim_angle_debug(-45.0)
				await get_tree().create_timer(1.0).timeout
				set_aim_angle_debug(0.0)
