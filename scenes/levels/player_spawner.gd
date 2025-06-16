#player_spawner.gd

extends Node3D
class_name PlayerSpawner

@export var show_debug_marker: bool = true

func _ready():
	if show_debug_marker:
		create_debug_marker()

func create_debug_marker():
	# Visual indicator in editor
	var mesh_instance = MeshInstance3D.new()
	var sphere_mesh = SphereMesh.new()
	sphere_mesh.radius = 0.5
	sphere_mesh.height = 1.0
	mesh_instance.mesh = sphere_mesh
	
	# Create a bright material so it's visible
	var material = StandardMaterial3D.new()
	material.albedo_color = Color.GREEN
	material.emission_enabled = true
	material.emission = Color.GREEN * 0.3
	mesh_instance.material_override = material
	
	add_child(mesh_instance)
	
	# Only show in editor
	if not Engine.is_editor_hint():
		mesh_instance.visible = false
