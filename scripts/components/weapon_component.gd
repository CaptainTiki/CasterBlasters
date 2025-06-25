# weapon_component.gd
extends Node3D
class_name WeaponComponent

signal weapon_fired(projectile: Node3D)

# Weapon settings
@export_group("Weapon Stats")
@export var fire_rate: float = 0.15  # Time between shots
@export var projectile_speed: float = 20.0
@export var projectile_damage: int = 10
@export var muzzle_offset: Vector3 = Vector3(1.0, 0, 0)  # Offset from weapon origin
@export var recoil_force: float = 2.0

@export_group("Weapon Visuals")
@export var weapon_model: Node3D
@export var muzzle_flash: GPUParticles3D
@export var weapon_rotation_speed: float = 10.0
@export var weapon_base_rotation: Vector3 = Vector3.ZERO  # Base rotation of the weapon model

@export_group("Projectile")
@export var projectile_scene: PackedScene
@export var projectile_parent_path: NodePath = "/root/Main/Projectiles"  # Where to spawn projectiles

# Internal state
var is_firing: bool = false
var fire_cooldown: float = 0.0
var current_aim_angle: float = 0.0
var player: Player
var aiming_controller: AimingController

# Weapon mounting
@onready var mount_point: Node3D = $MountPoint
@onready var weapon_pivot: Node3D = $MountPoint/WeaponPivot

func _ready():
	setup_weapon()
	find_player_references()

func setup_weapon():
	"""Initialize weapon structure"""
	# Create mount point if it doesn't exist
	if not mount_point:
		mount_point = Node3D.new()
		mount_point.name = "MountPoint"
		add_child(mount_point)
	
	# Create weapon pivot for rotation
	if not weapon_pivot:
		weapon_pivot = Node3D.new()
		weapon_pivot.name = "WeaponPivot"
		mount_point.add_child(weapon_pivot)
	
	# Parent weapon model to pivot if it exists
	if weapon_model and weapon_model.get_parent() != weapon_pivot:
		weapon_model.reparent(weapon_pivot)
		weapon_model.position = Vector3.ZERO
		weapon_model.rotation = weapon_base_rotation

func find_player_references():
	"""Find player and aiming controller"""
	# Try to find player in the tree
	player = get_parent().get_parent() as Player
	if player:
		aiming_controller = player.get_node("Components/AimingController") as AimingController
		if aiming_controller:
			print("🔫 Weapon connected to aiming system!")
		else:
			print("⚠️ Weapon: No AimingController found!")
	else:
		print("⚠️ Weapon: No Player found!")

func _process(delta):
	if fire_cooldown > 0:
		fire_cooldown -= delta
	
	# Update weapon rotation based on aim
	update_weapon_rotation(delta)
	
	# Handle firing
	if is_firing and fire_cooldown <= 0:
		fire_weapon()

func update_weapon_rotation(delta):
	"""Rotate weapon based on current aim direction"""
	if not aiming_controller or not weapon_pivot:
		return
	
	# Get aim angle from controller
	var target_angle = aiming_controller.get_aim_angle_degrees()
	
	# Convert to radians and apply to weapon
	var target_rotation_rad = deg_to_rad(target_angle)
	
	# Apply rotation based on player facing direction
	if player:
		if player.facing_direction < 0:
			# When facing left, we need to flip the aim angle
			target_rotation_rad = -target_rotation_rad
	
	# Smoothly rotate the weapon
	var current_z_rotation = weapon_pivot.rotation.z
	var new_z_rotation = lerp_angle(current_z_rotation, target_rotation_rad, weapon_rotation_speed * delta)
	weapon_pivot.rotation.z = new_z_rotation
	
	# Store current angle for projectile spawning
	current_aim_angle = rad_to_deg(new_z_rotation)

func start_firing():
	"""Called by player when fire button is pressed"""
	is_firing = true

func stop_firing():
	"""Called by player when fire button is released"""
	is_firing = false

func fire_weapon():
	"""Spawn a projectile and handle firing effects"""
	if not projectile_scene:
		print("⚠️ No projectile scene assigned!")
		return
	
	fire_cooldown = fire_rate
	
	# Spawn projectile
	var projectile = spawn_projectile()
	
	# Trigger visual effects
	trigger_muzzle_flash()
	
	# Apply recoil to player
	apply_recoil()
	
	# Emit signal
	weapon_fired.emit(projectile)

func spawn_projectile() -> Node3D:
	"""Create and configure a projectile"""
	var projectile = projectile_scene.instantiate()
	
	# Get spawn position (weapon position + muzzle offset)
	var spawn_position = get_muzzle_world_position()
	
	# Get firing direction from aiming controller
	var fire_direction = aiming_controller.get_aim_direction_vector() if aiming_controller else Vector3.FORWARD
	
	# Find projectile parent
	var projectile_parent = get_node(projectile_parent_path)
	if not projectile_parent:
		projectile_parent = get_tree().root
	
	projectile_parent.add_child(projectile)
	
	# Set projectile properties
	projectile.global_position = spawn_position
	
	# Configure projectile (assuming it has these methods)
	if projectile.has_method("setup"):
		projectile.setup(fire_direction, projectile_speed, projectile_damage)
	else:
		# Fallback: try to set properties directly
		if "velocity" in projectile:
			projectile.velocity = fire_direction * projectile_speed
		if "damage" in projectile:
			projectile.damage = projectile_damage
	
	return projectile

func get_muzzle_world_position() -> Vector3:
	"""Calculate the world position of the muzzle"""
	if not weapon_pivot:
		return global_position
	
	# Apply muzzle offset considering weapon rotation
	var rotated_offset = weapon_pivot.transform.basis * muzzle_offset
	return weapon_pivot.global_position + rotated_offset

func trigger_muzzle_flash():
	"""Play muzzle flash effect"""
	if muzzle_flash:
		muzzle_flash.restart()
		muzzle_flash.emitting = true

func apply_recoil():
	"""Apply recoil force to the player"""
	if player and aiming_controller:
		var recoil_direction = -aiming_controller.get_aim_direction_vector()
		var recoil_vector = recoil_direction * recoil_force
		player.apply_knockback(recoil_vector)

func get_weapon_rotation_degrees() -> float:
	"""Get current weapon rotation in degrees"""
	if weapon_pivot:
		return rad_to_deg(weapon_pivot.rotation.z)
	return 0.0

# Debug visualization
func _draw():
	if Engine.is_editor_hint():
		# Draw muzzle position in editor
		var muzzle_pos = muzzle_offset
		# Draw a small sphere at muzzle position
		# Note: In Godot 4, you'd typically use Gizmos for this
		pass
