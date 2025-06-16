
# Projectile.gd
extends Area3D

@export var damage: int = 25
@export var damage_type: String = "magical"  # physical, magical, fire, ice, etc.
@export var projectile_speed: float = 1000.0
@export var lifetime: float = 5.0  # Auto-destroy after 5 seconds

var velocity: Vector3

func _ready():
	# Auto-destroy after lifetime
	var timer = Timer.new()
	timer.wait_time = lifetime
	timer.one_shot = true
	timer.timeout.connect(queue_free)
	add_child(timer)
	timer.start()

func _physics_process(delta):
	# Move projectile
	if velocity != Vector3.ZERO:
		position += velocity * delta

func set_velocity(new_velocity: Vector3):
	velocity = new_velocity

func set_damage(new_damage: int):
	damage = new_damage

func _on_body_entered(body):
	# Look for HealthComponent on the hit object
	var health_comp = body.get_node("HealthComponent") as HealthComponent
	if health_comp:
		health_comp.take_damage(damage, damage_type)
		queue_free()  # Destroy projectile
