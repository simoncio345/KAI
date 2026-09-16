extends CharacterBody3D

@export var speed := 6.0
@export var sprint_speed := 9.0
@export var gravity := 18.0
@export var mouse_sensitivity := 0.0025

var camera_pivot: Node3D
var camera: Camera3D
var flashlight: SpotLight3D
var hud_label: Label
var objective_label: Label
var status_label: Label
var exposure := 0.0
var samples := 0
var flashlight_on := true
var gas_warning := false

func _ready() -> void:
	camera_pivot = get_node("CameraPivot")
	camera = get_node("CameraPivot/Camera3D")
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
			if Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
				Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
			else:
				Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
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
	var gas_center := Vector3(-25.0, 0.0, -25.0)
	var gas_distance := Vector2(global_position.x - gas_center.x, global_position.z - gas_center.z).length()
	gas_warning = gas_distance < 18.0
	if gas_warning:
		exposure = min(100.0, exposure + delta * 5.0)
	else:
		exposure = max(0.0, exposure - delta * 1.5)

	for node in get_tree().get_nodes_in_group("sample"):
		if is_instance_valid(node) and global_position.distance_to(node.global_position) < 2.2:
			node.queue_free()
			samples += 1
			break

	if samples >= 5 and global_position.distance_to(Vector3(22.0, 0.0, 22.0)) < 10.0:
		objective_label.text = "CASO RESUELTO: origen localizado"
		status_label.text = "REGRESA AL LABORATORIO"
	else:
		objective_label.text = "Muestras: %d/5   |   Encuentra la causa del gas" % samples
		if samples >= 5:
			status_label.text = "Ya tienes las 5 muestras. Vuelve al laboratorio."
		elif gas_warning:
			status_label.text = "ALERTA: zona contaminada  |  Exposición: %d%%" % int(exposure)
		else:
			status_label.text = "F: linterna   SHIFT: correr   ESC: liberar/capturar mouse"

	if exposure >= 100.0:
		status_label.text = "EXPOSICIÓN CRÍTICA. SAL DE LA ZONA CONTAMINADA."
		global_position = Vector3(0, 4, 10)
		exposure = 0.0

func create_hud() -> void:
	var canvas := CanvasLayer.new()
	canvas.name = "HUD"
	add_child(canvas)

	var panel := ColorRect.new()
	panel.position = Vector2(18, 18)
	panel.size = Vector2(600, 92)
	panel.color = Color(0.02, 0.04, 0.05, 0.78)
	canvas.add_child(panel)

	hud_label = Label.new()
	hud_label.position = Vector2(18, 12)
	hud_label.text = "KAI // PROTOCOLO DE INVESTIGACIÓN"
	hud_label.add_theme_font_size_override("font_size", 20)
	panel.add_child(hud_label)

	objective_label = Label.new()
	objective_label.position = Vector2(18, 42)
	objective_label.text = "Muestras: 0/5   |   Encuentra la causa del gas"
	objective_label.add_theme_font_size_override("font_size", 16)
	panel.add_child(objective_label)

	status_label = Label.new()
	status_label.position = Vector2(18, 112)
	status_label.text = "F: linterna   SHIFT: correr   ESC: liberar/capturar mouse"
	status_label.add_theme_font_size_override("font_size", 15)
	status_label.add_theme_color_override("font_color", Color(0.75, 0.85, 0.88))
	canvas.add_child(status_label)

	var crosshair := Label.new()
	crosshair.text = "+"
	crosshair.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	crosshair.add_theme_font_size_override("font_size", 24)
	crosshair.add_theme_color_override("font_color", Color(0.8, 1.0, 0.9, 0.9))
	canvas.add_child(crosshair)
