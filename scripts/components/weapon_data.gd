# WeaponData.gd
extends Resource
class_name WeaponData

@export var weapon_name: String
@export var damage: int = 25
@export var fire_rate: float = 0.1  # Time between shots
@export var projectile_speed: float = 1000.0
@export var spread_angle: float = 0.0  # Degrees of spread
@export var projectiles_per_shot: int = 1  # For shotgun-style weapons
@export var burst_count: int = 1  # How many shots per trigger pull
@export var burst_delay: float = 0.05  # Time between burst shots
@export var reload_time: float = 1.0
@export var magazine_size: int = 30
@export var infinite_ammo: bool = false

# Projectile properties
@export var projectile_scene: PackedScene
@export var muzzle_flash_scene: PackedScene

# Audio
@export var fire_sound: AudioStream
@export var reload_sound: AudioStream
@export var empty_sound: AudioStream
