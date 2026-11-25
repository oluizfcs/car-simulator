extends Control

# Arraste o nó Pivot/SpringArm3D da sua câmera para este campo no Inspetor!
@export var pivo_camera: Node3D
@export var sensibilidade_toque: float = 0.005

@onready var btn_menu_extras: Button = $BtnMenuExtras
@onready var lista_extras: VBoxContainer = $ListaExtras
@export var carro: VehicleBody3D

var dedo_camera_id: int = -1

func _ready() -> void:
	# Detecta automaticamente se é celular/tablet (nativo ou navegador mobile)
	var eh_mobile = OS.has_feature("mobile") or OS.has_feature("web_android") or OS.has_feature("web_ios") or DisplayServer.is_touchscreen_available()

	visible = eh_mobile
	
	if not eh_mobile:
		set_process_input(false)
		return

	$ListaExtras/BtnMenu.pressed.connect(func():
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		get_tree().change_scene_to_file("res://menu_inicial.tscn")
	)
	$ListaExtras/BtnBuzina.pressed.connect(func():
		if carro:
			carro.som_buzina.play()
			carro.onda_de_choque_buzina()
	)
	$ListaExtras/BtnFarol.pressed.connect(func():
		if carro:
			carro.farol_ligado = !carro.farol_ligado
			carro.atualizar_farois()
	)
	$ListaExtras/BtnCapo.pressed.connect(func():
		if carro:
			carro.capo_aberto = !carro.capo_aberto
	)
	$ListaExtras/BtnCamera.pressed.connect(func():
		var ev = InputEventAction.new()
		ev.action = "toggle_camera"
		ev.pressed = true
		Input.parse_input_event(ev)
		
		var ev_release = InputEventAction.new()
		ev_release.action = "toggle_camera"
		ev_release.pressed = false
		Input.parse_input_event(ev_release)
	)
	$ListaExtras/BtnReset.pressed.connect(func():
		if carro:
			carro.resetar_tudo()
			lista_extras.visible = false
	)

	if lista_extras:
		lista_extras.visible = false
	if btn_menu_extras:
		btn_menu_extras.pressed.connect(_alternar_lista_extras)

func _alternar_lista_extras() -> void:
	if lista_extras:
		lista_extras.visible = not lista_extras.visible

# Controle de câmera arrastando o dedo na tela (multitoque independente dos botões)
func _unhandled_input(event: InputEvent) -> void:
	if not visible or not pivo_camera:
		return

	if event is InputEventScreenTouch:
		if event.pressed:
			# Ignora toques na faixa inferior (onde ficam os pedais e setas)
			var altura_tela = get_viewport_rect().size.y
			if event.position.y < altura_tela * 0.72 and dedo_camera_id == -1:
				dedo_camera_id = event.index
		else:
			if event.index == dedo_camera_id:
				dedo_camera_id = -1

	elif event is InputEventScreenDrag:
		if event.index == dedo_camera_id:
			if pivo_camera.has_method("rotacionar_por_toque"):
				pivo_camera.rotacionar_por_toque(event.relative)
			# Limita a inclinação vertical da câmera para não atravessar o chão
			var rot_x = clamp(pivo_camera.rotation.x - event.relative.y * sensibilidade_toque, deg_to_rad(-45.0), deg_to_rad(15.0))
			pivo_camera.rotation.x = rot_x
