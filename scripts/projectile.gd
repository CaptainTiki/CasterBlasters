# projectile.gd
extends Area3D
class_name Projectile

# Projectile properties
@export var lifetime: float = 5.0
@export var damage: int = 10
@export var explosion_effect: PackedScene

# Movement
var velocity: Vector3 = Vector3.ZERO
var speed: float = 20.0

# Visual
@onready var mesh_instance: MeshInstance3D = $MeshInstance3D
@onready var trail_particles: GPUParticles3D = $TrailParticles
@onready var collision_shape: CollisionShape3D = $CollisionShape3D

# Internal
var time_alive: float = 0.0

func _ready():
	setup_projectile()
	connect_signals()

func setup_projectile():
	"""Initialize projectile components"""
	# Create mesh if it doesn't exist
	if not mesh_instance:
		mesh_instance = MeshInstance3D.new()
		add_child(mesh_instance)
		
		# Create a simple sphere mesh
		var sphere_mesh = SphereMesh.new()
		sphere_mesh.radius = 0.1
		sphere_mesh.height = 0.2
		mesh_instance.mesh = sphere_mesh
	
	# Create collision if it doesn't exist
	if not collision_shape:
		collision_shape = CollisionShape3D.new()
		add_child(collision_shape)
		
		var sphere_shape = SphereShape3D.new()
		sphere_shape.radius = 0.1
		collision_shape.shape = sphere_shape
	
	# Set collision layers
	collision_layer = 16  # Projectile layer
	collision_mask = 1 | 2 | 4  # Collide with: environment, enemies, obstacles

func connect_signals():
	"""Connect collision signals"""
	body_entered.connect(_on_body_entered)
	area_entered.connect(_on_area_entered)

func setup(direction: Vector3, projectile_speed: float, projectile_damage: int):
	"""Called by weapon to configure the projectile"""
	velocity = direction.normalized() * projectile_speed
	speed = projectile_speed
	damage = projectile_damage
	
	# Orient projectile to face direction of travel
	if direction.length() > 0:
		look_at(global_position + direction, Vector3.UP)

func _physics_process(delta):
	# Move projectile
	global_position += velocity * delta
	
	# Update lifetime
	time_alive += delta
	if time_alive >= lifetime:
		destroy()

func _on_body_entered(body: Node3D):
	"""Handle collision with bodies"""
	# Check if we hit something we can damage
	if body.has_method("take_damage"):
		body.take_damage(damage, velocity.normalized())
	
	# Create impact effect and destroy
	create_impact_effect()
	destroy()

func _on_area_entered(area: Area3D):
	"""Handle collision with areas"""
	# Similar to body collision but for Area3D nodes
	if area.has_method("take_damage"):
		area.take_damage(damage, velocity.normalized())
	
	create_impact_effect()
	destroy()

func create_impact_effect():
	"""Spawn impact effect at collision point"""
	if explosion_effect:
		var effect = explosion_effect.instantiate()
		get_tree().root.add_child(effect)
		effect.global_position = global_position
		
		# If the effect has a play method, call it
		if effect.has_method("play"):
			effect.play()

func destroy():
	"""Clean up projectile"""
	queue_free()
