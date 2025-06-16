#camera_controller.gd

extends Camera3D
class_name CameraController

@export_group("Following")
@export var follow_speed: float = 5.0  # How fast camera catches up
@export var offset: Vector3 = Vector3(0, 5, 10)  # Camera offset from target
@export var look_ahead: float = 2.0  # How far ahead to look based on movement

@export_group("Bounds")
@export var use_bounds: bool = false
@export var min_bounds: Vector3
@export var max_bounds: Vector3

var target: Node3D = null
var is_tracking: bool = false
var target_position: Vector3

func _ready():
	# Set up camera for 2.5D side-scrolling
	projection = PROJECTION_PERSPECTIVE
	fov = 50

func set_target(new_target: Node3D):
	target = new_target
	is_tracking = true
	
	if target:
		# Immediately snap to target position on first frame
		target_position = target.global_position + offset
		global_position = target_position
		look_at(target.global_position, Vector3.UP)

func stop_tracking():
	is_tracking = false

func _process(delta):
	if not is_tracking or not target:
		return
	
	update_target_position()
	move_camera(delta)
	update_camera_look()

func update_target_position():
	var base_position = target.global_position + offset
	
	# Add look-ahead based on player movement
	if target is CharacterBody3D:
		var player_velocity = target.velocity
		var look_ahead_offset = Vector3(player_velocity.x * look_ahead * 0.1, 0, 0)
		base_position += look_ahead_offset
	
	# Apply bounds if enabled
	if use_bounds:
		base_position.x = clamp(base_position.x, min_bounds.x, max_bounds.x)
		base_position.y = clamp(base_position.y, min_bounds.y, max_bounds.y)
		base_position.z = clamp(base_position.z, min_bounds.z, max_bounds.z)
	
	target_position = base_position

func move_camera(delta):
	global_position = global_position.lerp(target_position, follow_speed * delta)

func update_camera_look():
	if target:
		var look_target = target.global_position
		look_at(look_target, Vector3.UP)
