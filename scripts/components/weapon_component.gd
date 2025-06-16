# WeaponComponent.gd
extends Node3D
class_name WeaponComponent

# Signals
signal weapon_fired(projectile_count: int)
signal weapon_reloaded
signal ammo_changed(current: int, max: int)
signal weapon_switched(weapon_name: String)

# Current weapon data
@export var current_weapon: WeaponData
@export var auto_fire: bool = true

# State variables
var current_ammo: int
var is_firing: bool = false
var can_fire: bool = true
var is_reloading: bool = false

# Internal timers and counters
var _fire_timer: float = 0.0
var _burst_shots_fired: int = 0
var _burst_timer: float = 0.0

# References
@export var muzzle_point: Node3D  # Where projectiles spawn
@export var audio_player: AudioStreamPlayer3D

func _ready():
	if current_weapon:
		_initialize_weapon()
	
	if not audio_player:
		audio_player = AudioStreamPlayer3D.new()
		add_child(audio_player)

func _process(delta):
	# Update timers
	if _fire_timer > 0:
		_fire_timer -= delta
		if _fire_timer <= 0:
			can_fire = true
	
	if _burst_timer > 0:
		_burst_timer -= delta
		if _burst_timer <= 0 and _burst_shots_fired < current_weapon.burst_count:
			_fire_single_shot()

func set_weapon(weapon_data: WeaponData):
	current_weapon = weapon_data
	_initialize_weapon()
	weapon_switched.emit(weapon_data.weapon_name)

func _initialize_weapon():
	if not current_weapon:
		return
		
	current_ammo = current_weapon.magazine_size
	_burst_shots_fired = 0
	is_reloading = false
	can_fire = true
	ammo_changed.emit(current_ammo, current_weapon.magazine_size)

func start_firing():
	is_firing = true
	if can_fire and not is_reloading:
		_attempt_fire()

func stop_firing():
	is_firing = false

func _attempt_fire():
	if not can_fire or is_reloading or not current_weapon:
		return
	
	# Check ammo
	if not current_weapon.infinite_ammo and current_ammo <= 0:
		_play_sound(current_weapon.empty_sound)
		return
	
	# Start burst sequence
	_burst_shots_fired = 0
	_fire_single_shot()

func _fire_single_shot():
	if not current_weapon or not muzzle_point:
		return
	
	# Consume ammo
	if not current_weapon.infinite_ammo:
		current_ammo -= 1
		ammo_changed.emit(current_ammo, current_weapon.magazine_size)
	
	# Spawn projectiles
	_spawn_projectiles()
	
	# Play effects
	_play_sound(current_weapon.fire_sound)
	_spawn_muzzle_flash()
	
	# Update burst tracking
	_burst_shots_fired += 1
	
	# Set up next shot timing
	if _burst_shots_fired < current_weapon.burst_count:
		_burst_timer = current_weapon.burst_delay
	else:
		# Burst complete, set fire rate cooldown
		_fire_timer = current_weapon.fire_rate
		can_fire = false
		
		# Continue auto fire if still holding trigger
		if auto_fire and is_firing and (current_weapon.infinite_ammo or current_ammo > 0):
			# Will fire again when timer expires
			pass
	
	weapon_fired.emit(current_weapon.projectiles_per_shot)

func _spawn_projectiles():
	for i in range(current_weapon.projectiles_per_shot):
		var projectile = current_weapon.projectile_scene.instantiate()
		get_tree().current_scene.add_child(projectile)
		
		# Position at muzzle
		projectile.global_position = muzzle_point.global_position
		
		# Calculate firing direction with spread
		var base_direction = -muzzle_point.global_transform.basis.z
		var spread_radians = deg_to_rad(current_weapon.spread_angle)
		var random_spread = randf_range(-spread_radians, spread_radians)
		
		# Apply spread (rotate around Y axis for horizontal spread)
		var spread_direction = base_direction.rotated(Vector3.UP, random_spread)
		
		# Set projectile velocity
		if projectile.has_method("set_velocity"):
			projectile.set_velocity(spread_direction * current_weapon.projectile_speed)
		
		# Set projectile damage
		if projectile.has_method("set_damage"):
			projectile.set_damage(current_weapon.damage)

func _spawn_muzzle_flash():
	if current_weapon.muzzle_flash_scene and muzzle_point:
		var flash = current_weapon.muzzle_flash_scene.instantiate()
		muzzle_point.add_child(flash)

func reload():
	if is_reloading or current_ammo >= current_weapon.magazine_size:
		return
	
	is_reloading = true
	can_fire = false
	_play_sound(current_weapon.reload_sound)
	
	# Wait for reload time
	await get_tree().create_timer(current_weapon.reload_time).timeout
	
	current_ammo = current_weapon.magazine_size
	is_reloading = false
	can_fire = true
	
	ammo_changed.emit(current_ammo, current_weapon.magazine_size)
	weapon_reloaded.emit()

func _play_sound(sound: AudioStream):
	if sound and audio_player:
		audio_player.stream = sound
		audio_player.play()

func get_ammo_percentage() -> float:
	if current_weapon.infinite_ammo:
		return 1.0
	return float(current_ammo) / float(current_weapon.magazine_size)
