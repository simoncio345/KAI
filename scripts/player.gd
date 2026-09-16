extends CharacterBody3D

@export var speed := 5.5
@export var sprint_speed := 8.5
@export var gravity := 18.0
@export var mouse_sensitivity := 0.0025

var camera_pivot: Node3D
var flashlight: SpotLight3D
var objective_label: Label
var status_label: Label
var telemetry_label: Label
var exposure := 0.0
var samples := 0
var flashlight_on := true

func _ready() -> void:
	camera_pivot = get_node("CameraPivot")
	flashlight = get_node("CameraPivot/Flashlight")
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	create_hud()

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		rotate_y(-event.relative.x * mouse_sensitivity)
		camera_pivot.rotate_x(-event.relative.y * mouse_sensitivity)
		camera_pivot.rotation.x = clamp(camera_pivot.rotation.x, deg_to_rad(-85.0), deg_to_rad(85.0))
	elif event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_ESCAPE:
			Input.mouse_mode = Input.MOUSE_MODE_VISIBLE if Input.mouse_mode == Input.MOUSE_MODE_CAPTURED else Input.MOUSE_MODE_CAPTURED
		elif event.keycode == KEY_F:
			flashlight_on = not flashlight_on
			flashlight.visible = flashlight_on
	elif event is InputEventMouseButton and event.pressed:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

func _physics_process(delta: float) -> void:
	var input := Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	var local_direction := Vector3(input.x, 0.0, input.y)
	var direction := (transform.basis * local_direction).normalized()
	var current_speed := sprint_speed if Input.is_key_pressed(KEY_SHIFT) else speed
	velocity.x = direction.x * current_speed
	velocity.z = direction.z * current_speed
	if not is_on_floor():
		velocity.y -= gravity * delta
	else:
		velocity.y = 0.0
	move_and_slide()
	update_gameplay(delta)

func update_gameplay(delta: float) -> void:
	var gas_center := Vector3(-36.0, 0.0, -36.0)
	var distance_to_gas := Vector2(global_position.x - gas_center.x, global_position.z - gas_center.z).length()
	var gas_level := clamp(100.0 - distance_to_gas * 3.2, 0.0, 100.0)

	if gas_level > 35.0:
		exposure = min(100.0, exposure + delta * gas_level * 0.055)
	else:
		exposure = max(0.0, exposure - delta * 2.0)

	for node in get_tree().get_nodes_in_group("sample"):
		if is_instance_valid(node) and global_position.distance_to(node.global_position) < 2.2:
			node.queue_free()
			samples += 1
			break

	telemetry_label.text = "PROFUNDIDAD  %04dm\nGAS KAI       %03d%%\nEXPOSICIÓN    %03d%%" % [int(abs(global_position.y - 7.0) + 120.0), int(gas_level), int(exposure)]
	objective_label.text = "MUESTRAS  %d/5   |   Localiza el origen del gas" % samples

	if samples >= 5 and global_position.distance_to(Vector3(0, 0, 5)) < 12.0:
		status_label.text = "INVESTIGACIÓN COMPLETA  |  Muestras entregadas en la estación"
	elif samples >= 5:
		status_label.text = "Todas las muestras reunidas. Regresa a KAI // DEEP RESEARCH."
	elif gas_level > 65.0:
		status_label.text = "ALERTA AMBIENTAL  |  Concentración elevada."
	elif gas_level > 35.0:
		status_label.text = "Detector KAI: presencia de gas detectada."
	else:
		status_label.text = "WASD mover   SHIFT correr   F linterna   ESC mouse"

	if exposure >= 100.0:
		status_label.text = "EXPOSICIÓN CRÍTICA  |  Regresa a una zona segura."
		global_position = Vector3(0, 0.2, 0)
		exposure = 0.0

func create_hud() -> void:
	var canvas := CanvasLayer.new()
	canvas.name = "HUD"
	add_child(canvas)

	var panel := ColorRect.new()
	panel.position = Vector2(18, 18)
	panel.size = Vector2(650, 112)
	panel.color = Color(0.008, 0.018, 0.022, 0.86)
	canvas.add_child(panel)

	var title := Label.new()
	title.position = Vector2(18, 10)
	title.text = "KAI // DEEP RESEARCH"
	title.add_theme_font_size_override("font_size", 22)
	panel.add_child(title)

	objective_label = Label.new()
	objective_label.position = Vector2(18, 46)
	objective_label.text = "MUESTRAS  0/5   |   Localiza el origen del gas"
	objective_label.add_theme_font_size_override("font_size", 16)
	panel.add_child(objective_label)

	status_label = Label.new()
	status_label.position = Vector2(18, 150)
	status_label.add_theme_font_size_override("font_size", 15)
	status_label.add_theme_color_override("font_color", Color(0.7, 0.85, 0.86))
	canvas.add_child(status_label)

	telemetry_label = Label.new()
	telemetry_label.position = Vector2(1050, 22)
	telemetry_label.text = "PROFUNDIDAD 0120m\nGAS KAI       000%\nEXPOSICIÓN    000%"
	telemetry_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	telemetry_label.add_theme_font_size_override("font_size", 16)
	canvas.add_child(telemetry_label)

	var crosshair := Label.new()
	crosshair.text = "+"
	crosshair.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	crosshair.add_theme_font_size_override("font_size", 24)
	crosshair.add_theme_color_override("font_color", Color(0.7, 1.0, 0.9, 0.9))
	canvas.add_child(crosshair)
