extends CharacterBody3D

@export var speed: float = 5.5
@export var sprint_speed: float = 8.5
@export var gravity: float = 18.0
@export var mouse_sensitivity: float = 0.0025

var camera_pivot: Node3D
var camera: Camera3D
var flashlight: SpotLight3D
var objective_label: Label
var status_label: Label
var telemetry_label: Label
var interaction_label: Label
var narrator_panel: ColorRect
var narrator_label: Label
var generator: Node
var exposure: float = 0.0
var samples: int = 0
var flashlight_on: bool = true
var game_finished: bool = false
var narration_index: int = 0
var narration_timer: float = 0.0

var narration: Array[String] = [
	"KAI-01. Registro de voz de la expedición. Si estás escuchando esto, ya has entrado en la zona de investigación.",
	"Hace tres días, nuestros sensores detectaron un gas desconocido bajo estas cavernas. La concentración sigue aumentando.",
	"No sabemos qué lo produce. Los análisis iniciales descartan una fuente industrial conocida.",
	"La estación que tienes delante fue abandonada hace once años. Sus últimos registros mencionan anomalías en el subsuelo.",
	"Tu misión es sencilla: excava, recoge las muestras y descubre qué está liberando el gas.",
	"El detector acaba de registrar un cambio. El gas se está desplazando por la caverna.",
	"Cada minuto que pasa, la zona contaminada aumenta. Tenemos que llegar al origen antes de que las lecturas saturen los sensores.",
	"Cinco muestras deberían ser suficientes para comparar la composición. Después podremos reconstruir el origen del fenómeno."
]

func _ready() -> void:
	camera_pivot = get_node("CameraPivot")
	camera = get_node("CameraPivot/Camera3D")
	flashlight = get_node("CameraPivot/Camera3D/Flashlight")
	generator = get_parent().get_node_or_null("WorldGenerator")
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	create_hud()
	if generator and generator.has_signal("sample_found"):
		generator.sample_found.connect(_on_sample_found)
	call_deferred("start_narration")

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED and not game_finished:
		rotate_y(-event.relative.x * mouse_sensitivity)
		camera_pivot.rotate_x(-event.relative.y * mouse_sensitivity)
		camera_pivot.rotation.x = clampf(camera_pivot.rotation.x, deg_to_rad(-85.0), deg_to_rad(85.0))
	elif event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_ESCAPE:
			Input.mouse_mode = Input.MOUSE_MODE_VISIBLE if Input.mouse_mode == Input.MOUSE_MODE_CAPTURED else Input.MOUSE_MODE_CAPTURED
		elif event.keycode == KEY_F and not game_finished:
			flashlight_on = not flashlight_on
			flashlight.visible = flashlight_on
		elif event.keycode == KEY_E and not game_finished:
			dig_forward()
	elif event is InputEventMouseButton and event.pressed and not game_finished:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

func _physics_process(delta: float) -> void:
	if game_finished:
		velocity = Vector3.ZERO
		return

	var input: Vector2 = Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	var local_direction := Vector3(input.x, 0.0, input.y)
	var direction := (transform.basis * local_direction).normalized()
	var current_speed: float = sprint_speed if Input.is_key_pressed(KEY_SHIFT) else speed
	velocity.x = direction.x * current_speed
	velocity.z = direction.z * current_speed

	if not is_on_floor():
		velocity.y -= gravity * delta
	else:
		velocity.y = 0.0

	move_and_slide()
	update_gameplay(delta)
	update_interaction()
	update_narration(delta)

func update_gameplay(delta: float) -> void:
	var gas_center := Vector3(-36.0, 0.0, -36.0)
	var distance_to_gas: float = Vector2(global_position.x - gas_center.x, global_position.z - gas_center.z).length()
	var gas_level: float = clampf(100.0 - distance_to_gas * 3.2, 0.0, 100.0)

	if gas_level > 35.0:
		exposure = minf(100.0, exposure + delta * gas_level * 0.055)
	else:
		exposure = maxf(0.0, exposure - delta * 2.0)

	telemetry_label.text = "PROFUNDIDAD  %04dm\nGAS KAI       %03d%%\nEXPOSICIÓN    %03d%%" % [int(abs(global_position.y - 7.0) + 120.0), int(gas_level), int(exposure)]
	objective_label.text = "MUESTRAS  %d/5\nExcava el suelo y analiza la evidencia." % samples

	if gas_level > 80.0:
		status_label.text = "ALERTA MÁXIMA | El gas está saturando la zona."
	elif gas_level > 55.0:
		status_label.text = "ALERTA | La nube de gas se está acercando."
	elif gas_level > 35.0:
		status_label.text = "Detector KAI | Presencia de gas detectada."
	else:
		status_label.text = "WASD mover | SHIFT correr | F linterna | E excavar"

	if exposure >= 100.0:
		status_label.text = "EXPOSICIÓN CRÍTICA | Regresando a la estación."
		global_position = Vector3(0, 1.4, 0)
		exposure = 0.0
		say_narration("La exposición ha superado el límite seguro. Regresa a la estación y continúa desde una zona protegida.")

func update_interaction() -> void:
	var from := camera.global_position
	var to := from + (-camera.global_transform.basis.z * 4.0)
	var query := PhysicsRayQueryParameters3D.create(from, to)
	query.exclude = [get_rid()]
	var hit := get_world_3d().direct_space_state.intersect_ray(query)
	if hit.is_empty():
		interaction_label.text = ""
		return
	var collider = hit.get("collider")
	if collider is StaticBody3D and collider.is_in_group("diggable") and not bool(collider.get_meta("dug", false)):
		interaction_label.text = "E  |  EXCAVAR SUELO"
	else:
		interaction_label.text = ""

func dig_forward() -> void:
	if not generator:
		return
	var from := camera.global_position
	var to := from + (-camera.global_transform.basis.z * 4.0)
	var query := PhysicsRayQueryParameters3D.create(from, to)
	query.exclude = [get_rid()]
	var hit := get_world_3d().direct_space_state.intersect_ray(query)
	if hit.is_empty():
		return
	var collider = hit.get("collider")
	if collider is StaticBody3D and collider.is_in_group("diggable"):
		if generator.dig_ground(collider):
			say_narration("La capa de suelo acaba de hundirse. Hay material desconocido debajo. Esta muestra podría ser importante.")

func _on_sample_found(sample_number: int, position: Vector3) -> void:
	samples = sample_number
	status_label.text = "MUESTRA %d/5 RECUPERADA | Anomalía detectada." % samples
	if samples == 1:
		say_narration("Primera muestra recuperada. Su composición no coincide con ninguna de nuestras muestras de referencia.")
	elif samples == 3:
		say_narration("Tres muestras. Todas contienen el mismo compuesto. Esto ya no parece una anomalía aislada.")
	elif samples == 5:
		say_narration("Tenemos cinco muestras. Voy a comparar los resultados. La misión KAI-01 entra en su fase final.")
		show_ending()

func start_narration() -> void:
	if narration.size() > 0:
		say_narration(narration[0])
		narration_index = 1
		narration_timer = 8.0

func update_narration(delta: float) -> void:
	if narration_index >= narration.size():
		return
	narration_timer -= delta
	if narration_timer <= 0.0:
		say_narration(narration[narration_index])
		narration_index += 1
		narration_timer = 11.0

func say_narration(text: String) -> void:
	narrator_label.text = "KAI // REGISTRO DE VOZ\n\n" + text
	narrator_panel.visible = true
	var voices: PackedStringArray = DisplayServer.tts_get_voices()
	var selected_voice := ""
	for voice in voices:
		if voice.to_lower().contains("es"):
			selected_voice = voice
			break
	DisplayServer.tts_speak(text, selected_voice, 1.0, 1.0, 1.0, 0, true)

func show_ending() -> void:
	game_finished = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	var overlay := ColorRect.new()
	overlay.name = "EndingOverlay"
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.color = Color(0.005, 0.01, 0.014, 0.97)
	get_node("HUD").add_child(overlay)

	var title := Label.new()
	title.text = "KAI // INFORME FINAL"
	title.position = Vector2(0, 110)
	title.size = Vector2(1280, 60)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 38)
	overlay.add_child(title)

	var story := Label.new()
	story.text = "Las cinco muestras contienen el mismo compuesto desconocido.\n\nLos análisis indican que el gas se origina en una zona mucho más profunda que la estación.\nLa expansión observada en la caverna es compatible con una fuente activa bajo el subsuelo.\n\nEl informe KAI-01 queda abierto. La investigación ha localizado el origen, pero todavía no explica qué existe allí abajo.\n\nINVESTIGACIÓN COMPLETADA\nORIGEN DEL GAS: LOCALIZADO"
	story.position = Vector2(180, 225)
	story.size = Vector2(920, 300)
	story.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	story.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	story.add_theme_font_size_override("font_size", 20)
	overlay.add_child(story)

	var close := Label.new()
	close.text = "KAI-01 | Fin del capítulo 1"
	close.position = Vector2(0, 590)
	close.size = Vector2(1280, 40)
	close.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	close.add_theme_font_size_override("font_size", 16)
	overlay.add_child(close)

func create_hud() -> void:
	var canvas := CanvasLayer.new()
	canvas.name = "HUD"
	add_child(canvas)

	var panel := ColorRect.new()
	panel.position = Vector2(18, 18)
	panel.size = Vector2(650, 118)
	panel.color = Color(0.008, 0.018, 0.022, 0.9)
	canvas.add_child(panel)

	var title := Label.new()
	title.position = Vector2(18, 10)
	title.text = "KAI // DEEP RESEARCH"
	title.add_theme_font_size_override("font_size", 22)
	panel.add_child(title)

	objective_label = Label.new()
	objective_label.position = Vector2(18, 48)
	objective_label.text = "MUESTRAS  0/5\nExcava el suelo y analiza la evidencia."
	objective_label.add_theme_font_size_override("font_size", 16)
	panel.add_child(objective_label)

	status_label = Label.new()
	status_label.position = Vector2(18, 154)
	status_label.add_theme_font_size_override("font_size", 15)
	status_label.add_theme_color_override("font_color", Color(0.7, 0.85, 0.86))
	canvas.add_child(status_label)

	telemetry_label = Label.new()
	telemetry_label.position = Vector2(1030, 22)
	telemetry_label.size = Vector2(225, 90)
	telemetry_label.text = "PROFUNDIDAD 0120m\nGAS KAI       000%\nEXPOSICIÓN    000%"
	telemetry_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	telemetry_label.add_theme_font_size_override("font_size", 16)
	canvas.add_child(telemetry_label)

	interaction_label = Label.new()
	interaction_label.position = Vector2(520, 620)
	interaction_label.add_theme_font_size_override("font_size", 20)
	interaction_label.add_theme_color_override("font_color", Color(0.7, 1.0, 0.9, 1.0))
	canvas.add_child(interaction_label)

	var crosshair := Label.new()
	crosshair.text = "+"
	crosshair.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	crosshair.add_theme_font_size_override("font_size", 24)
	crosshair.add_theme_color_override("font_color", Color(0.7, 1.0, 0.9, 0.9))
	canvas.add_child(crosshair)

	narrator_panel = ColorRect.new()
	narrator_panel.position = Vector2(70, 500)
	narrator_panel.size = Vector2(1140, 105)
	narrator_panel.color = Color(0.005, 0.015, 0.018, 0.94)
	canvas.add_child(narrator_panel)

	narrator_label = Label.new()
	narrator_label.position = Vector2(20, 14)
	narrator_label.size = Vector2(1100, 80)
	narrator_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	narrator_label.add_theme_font_size_override("font_size", 17)
	narrator_label.add_theme_color_override("font_color", Color(0.82, 0.95, 0.94))
	narrator_panel.add_child(narrator_label)
