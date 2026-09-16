extends Node3D

var generator: Node3D
var player: CharacterBody3D

func _ready() -> void:
	generator = preload("res://scripts/world_generator.gd").new()
	add_child(generator)
	create_player()
	create_environment()

func create_player() -> void:
	player = CharacterBody3D.new()
	player.name = "Scientist"
	player.position = Vector3(0, 4, 10)
	player.set_script(preload("res://scripts/player.gd"))

	var collision := CollisionShape3D.new()
	var capsule := CapsuleShape3D.new()
	capsule.radius = 0.45
	capsule.height = 1.8
	collision.shape = capsule
	collision.position.y = 0.9
	player.add_child(collision)

	var body := MeshInstance3D.new()
	var mesh := CapsuleMesh.new()
	mesh.radius = 0.45
	mesh.height = 1.8
	body.mesh = mesh
	body.position.y = 0.9
	body.visible = false
	player.add_child(body)

	var camera_pivot := Node3D.new()
	camera_pivot.name = "CameraPivot"
	camera_pivot.position = Vector3(0, 1.55, 0)
	player.add_child(camera_pivot)

	var camera := Camera3D.new()
	camera.name = "Camera3D"
	camera.current = true
	camera.fov = 78.0
	camera.near = 0.05
	camera_pivot.add_child(camera)

	var flashlight := SpotLight3D.new()
	flashlight.name = "Flashlight"
	flashlight.light_color = Color(0.86, 0.94, 1.0)
	flashlight.light_energy = 4.0
	flashlight.spot_range = 28.0
	flashlight.spot_angle = 32.0
	flashlight.spot_attenuation = 1.3
	flashlight.shadow_enabled = true
	camera_pivot.add_child(flashlight)

	add_child(player)

func create_environment() -> void:
	var sun := DirectionalLight3D.new()
	sun.name = "Sun"
	sun.rotation_degrees = Vector3(-48, -32, 0)
	sun.light_energy = 1.0
	sun.shadow_enabled = true
	sun.directional_shadow_max_distance = 180.0
	add_child(sun)

	var fill := DirectionalLight3D.new()
	fill.name = "FillLight"
	fill.rotation_degrees = Vector3(-20, 145, 0)
	fill.light_energy = 0.25
	fill.light_color = Color(0.45, 0.55, 0.65)
	add_child(fill)

	var environment := WorldEnvironment.new()
	environment.name = "WorldEnvironment"
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.025, 0.045, 0.055)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.25, 0.32, 0.35)
	env.ambient_light_energy = 0.75
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.fog_enabled = true
	env.fog_light_color = Color(0.10, 0.14, 0.15)
	env.fog_light_energy = 0.7
	env.fog_density = 0.012
	env.fog_height = 2.0
	env.fog_height_density = 0.04
	environment.environment = env
	add_child(environment)
