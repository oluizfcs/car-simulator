extends Control

@export var pivo_camera: Node3D
@export var sensibilidade_toque: float = 0.005

@onready var btn_menu_extras: Button = $BtnMenuExtras
@onready var lista_extras: VBoxContainer = $ListaExtras
@export var carro: VehicleBody3D

var dedo_camera_id: int = -1

func _ready() -> void:
	var eh_mobile = OS.has_feature("mobile") or OS.has_feature("web_android") or OS.has_feature("web_ios") or DisplayServer.is_touchscreen_available()
	visible = eh_mobile
	
	if not eh_mobile:
		set_process_input(false)
		set_process_unhandled_input(false)
		return

	# Conecta TODOS os TouchScreenButton filhos (e netos) para nunca dispararem a câmera
	_registrar_touch_buttons(self)

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
	if has_node("ListaExtras/BtnMenu"):
		$ListaExtras/BtnMenu.pressed.connect(func():
			Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
			get_tree().change_scene_to_file("res://menu_inicial.tscn")
		)

	if lista_extras:
		lista_extras.visible = false
	if btn_menu_extras:
		btn_menu_extras.pressed.connect(_alternar_lista_extras)

# Varre todos os TouchScreenButton dentro de ControlesMobile e bloqueia a câmera ao pressioná-los
func _registrar_touch_buttons(no: Node) -> void:
	for filho in no.get_children():
		if filho is TouchScreenButton:
			filho.pressed.connect(func():
				dedo_camera_id = -1
			)
		_registrar_touch_buttons(filho)

func _alternar_lista_extras() -> void:
	if lista_extras:
		lista_extras.visible = not lista_extras.visible

func _unhandled_input(event: InputEvent) -> void:
	if not visible or not pivo_camera:
		return

	if event is InputEventScreenTouch:
		if event.pressed:	
			# Restringe a área da câmera apenas à faixa superior livre (acima dos botões)
			var tamanho_tela = get_viewport_rect().size
			if event.position.y < tamanho_tela.y * 0.55 and dedo_camera_id == -1:
				dedo_camera_id = event.index
		else:
			if event.index == dedo_camera_id:
				dedo_camera_id = -1

	elif event is InputEventScreenDrag:
		if event.index == dedo_camera_id:
			# Ignora saltos bruscos de coordenadas que navegadores mobile às vezes enviam no multitoque
			if event.relative.length() > 80.0:
				return
			if pivo_camera.has_method("rotacionar_por_toque"):
				pivo_camera.rotacionar_por_toque(event.relative)
