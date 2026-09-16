extends Node3D

var generator: Node3D
var player: CharacterBody3D

func _ready() -> void:
	generator = preload("res://scripts/world_generator.gd").new()
	add_child(generator)
	create_player()
	create_underground_environment()

func create_player() -> void:
	player = CharacterBody3D.new()
	player.name = "Scientist"
	player.position = Vector3(0, 0.2, 0)
	player.set_script(preload("res://scripts/player_dig.gd"))

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
	camera.far = 180.0
	camera_pivot.add_child(camera)

	var flashlight := SpotLight3D.new()
	flashlight.name = "Flashlight"
	flashlight.light_color = Color(0.78, 0.9, 1.0)
	flashlight.light_energy = 5.5
	flashlight.spot_range = 32.0
	flashlight.spot_angle = 30.0
	flashlight.spot_attenuation = 1.15
	flashlight.shadow_enabled = true
	camera.add_child(flashlight)

	add_child(player)

func create_underground_environment() -> void:
	var environment := WorldEnvironment.new()
	environment.name = "UndergroundEnvironment"
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.003, 0.006, 0.009)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.055, 0.075, 0.085)
	env.ambient_light_energy = 0.28
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.glow_enabled = true
	env.glow_intensity = 0.65
	env.glow_bloom = 0.08
	env.fog_enabled = true
	env.fog_light_color = Color(0.035, 0.065, 0.07)
	env.fog_light_energy = 0.55
	env.fog_density = 0.018
	env.fog_height = 1.0
	env.fog_height_density = 0.035
	environment.environment = env
	add_child(environment)

	var weak_light := OmniLight3D.new()
	weak_light.name = "EmergencyLight"
	weak_light.position = Vector3(0, 3.8, 0)
	weak_light.light_color = Color(0.08, 0.35, 0.4)
	weak_light.light_energy = 1.0
	weak_light.omni_range = 10.0
	add_child(weak_light)
