extends Node3D

@export_group("Referências")
@export var carro_alvo: Node3D
@export var spring_arm: SpringArm3D
@export var cam_terceira_pessoa: Camera3D
@export var cam_primeira_pessoa: Camera3D

@export_group("Controles do Mouse")
@export var sensibilidade_mouse: float = 0.005
@export var zoom_min: float = 2.0
@export var zoom_max: float = 12.0
@export var velocidade_zoom: float = 0.5

@export_group("Suavidade e Retorno")
@export var suavidade_posicao: float = 22.0 # Alto para não ficar para trás no turbo
@export var suavidade_rotacao: float = 3.5 # Atraso estilo jogo de corrida nas curvas
@export var delay_retorno: float = 1.2 # Tempo após soltar o botão direito para voltar
@export var velocidade_retorno: float = 2.5 # Velocidade do snap de volta para trás
@export var fov_normal: float = 75.0
@export var fov_turbo: float = 95.0
@export var tremor_turbo: float = 0.04 # Intensidade da vibração do motor/escapamento

const ANGULO_X_PADRAO_3P: float = -0.25

var em_primeira_pessoa: bool = false
var rotacionando_mouse: bool = false
var rotacao_x: float = ANGULO_X_PADRAO_3P
var rotacao_y: float = 0.0
var zoom_alvo: float = 5.0
var tempo_sem_mouse: float = 99.0

func _ready() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE # Mouse visível por padrão
	cam_terceira_pessoa.current = true
	cam_primeira_pessoa.current = false
	
	if spring_arm:
		zoom_alvo = spring_arm.spring_length
		if carro_alvo is CollisionObject3D:
			spring_arm.add_excluded_object((carro_alvo as CollisionObject3D).get_rid())
	
	if carro_alvo:
		global_position = carro_alvo.global_position + Vector3(0, 1.2, 0)
		rotacao_y = _angulo_traseiro_carro()

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("toggle_camera"):
		alternar_camera()

	# Botão direito segura para girar a câmera, solta para voltar ao normal
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_RIGHT:
			rotacionando_mouse = event.pressed
			if rotacionando_mouse:
				Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
				tempo_sem_mouse = 0.0
			else:
				Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
				tempo_sem_mouse = 0.0
		
		# Zoom com o scroll do mouse em 3ª pessoa
		elif not em_primeira_pessoa and event.pressed:
			if event.button_index == MOUSE_BUTTON_WHEEL_UP:
				zoom_alvo = clamp(zoom_alvo - velocidade_zoom, zoom_min, zoom_max)
			elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
				zoom_alvo = clamp(zoom_alvo + velocidade_zoom, zoom_min, zoom_max)

	# Só gira a câmera enquanto o botão direito estiver pressionado
	if event is InputEventMouseMotion and rotacionando_mouse:
		tempo_sem_mouse = 0.0
		rotacao_y -= event.relative.x * sensibilidade_mouse
		rotacao_x -= event.relative.y * sensibilidade_mouse
		
		if em_primeira_pessoa:
			rotacao_y = clamp(rotacao_y, deg_to_rad(-110), deg_to_rad(110))
			rotacao_x = clamp(rotacao_x, deg_to_rad(-40), deg_to_rad(45))
		else:
			rotacao_x = clamp(rotacao_x, deg_to_rad(-80), deg_to_rad(15))

func _physics_process(delta: float) -> void:
	if not carro_alvo:
		return

	if not rotacionando_mouse:
		tempo_sem_mouse += delta

	if not em_primeira_pessoa:
		# 1. Segue a posição do carro rápido o bastante para o turbo não deixar a câmera para trás
		var pos_alvo = carro_alvo.global_position + Vector3(0, 1.2, 0)
		global_position = global_position.lerp(pos_alvo, 1.0 - exp(-suavidade_posicao * delta))
		
		# Trava de segurança: no turbo extremo, nunca deixa a câmera afastar mais que 1.2m do pivô
		if global_position.distance_to(pos_alvo) > 1.2:
			global_position = pos_alvo + (global_position - pos_alvo).normalized() * 1.2
		
		# 2. Alinha atrás do carro com atraso suave (quando não está segurando o botão direito)
		if not rotacionando_mouse and tempo_sem_mouse >= delay_retorno:
			var alvo_y = _angulo_traseiro_carro()
			# Usa a velocidade de retorno lenta logo após soltar o mouse, e a suavidade de curva depois
			var vel_atual = velocidade_retorno if tempo_sem_mouse < (delay_retorno + 1.5) else suavidade_rotacao
			rotacao_y = lerp_angle(rotacao_y, alvo_y, 1.0 - exp(-vel_atual * delta))
			rotacao_x = lerp(rotacao_x, ANGULO_X_PADRAO_3P, 1.0 - exp(-vel_atual * delta))
		
		rotation = Vector3(rotacao_x, rotacao_y, 0.0)
		if spring_arm:
			spring_arm.spring_length = lerp(spring_arm.spring_length, zoom_alvo, 10.0 * delta)
	else:
		# Na primeira pessoa, volta devagar a olhar reto para o para-brisa
		if not rotacionando_mouse and tempo_sem_mouse >= delay_retorno:
			rotacao_y = lerp(rotacao_y, 0.0, 1.0 - exp(-velocidade_retorno * delta))
			rotacao_x = lerp(rotacao_x, 0.0, 1.0 - exp(-velocidade_retorno * delta))
			
		cam_primeira_pessoa.rotation = Vector3(rotacao_x, rotacao_y, 0.0)
		
	# --- EFEITO DE VELOCIDADE NO TURBO (FOV Dinâmico + Tremor) ---
	var usando_turbo = Input.is_action_pressed("turbo")
	var cam_ativa = cam_primeira_pessoa if em_primeira_pessoa else cam_terceira_pessoa
	
	if cam_ativa:
		# 1. Estica o campo de visão (FOV) suavemente no turbo
		var fov_alvo = fov_turbo if usando_turbo else fov_normal
		cam_ativa.fov = lerp(cam_ativa.fov, fov_alvo, 6.0 * delta)
		
		# 2. Adiciona uma micro-vibração (Camera Shake) enquanto o fogo sai do escapamento
		if usando_turbo:
			cam_ativa.h_offset = randf_range(-tremor_turbo, tremor_turbo)
			cam_ativa.v_offset = randf_range(-tremor_turbo, tremor_turbo)
		else:
			cam_ativa.h_offset = lerp(cam_ativa.h_offset, 0.0, 15.0 * delta)
			cam_ativa.v_offset = lerp(cam_ativa.v_offset, 0.0, 15.0 * delta)

func _angulo_traseiro_carro() -> float:
	var frente = carro_alvo.global_transform.basis.z
	return atan2(-frente.x, -frente.z)

func alternar_camera() -> void:
	em_primeira_pessoa = not em_primeira_pessoa
	tempo_sem_mouse = delay_retorno + 2.0 # Já inicia perfeitamente alinhado
	
	if em_primeira_pessoa:
		rotacao_x = 0.0
		rotacao_y = 0.0
		cam_primeira_pessoa.current = true
		cam_terceira_pessoa.current = false
	else:
		cam_terceira_pessoa.current = true
		cam_primeira_pessoa.current = false
		rotacao_y = _angulo_traseiro_carro()
		rotacao_x = ANGULO_X_PADRAO_3P

func rotacionar_por_toque(relativo: Vector2) -> void:
	tempo_sem_mouse = 0.0 # Zera o contador para a câmera não voltar enquanto você arrasta o dedo
	rotacao_y -= relativo.x * sensibilidade_mouse
	rotacao_x -= relativo.y * sensibilidade_mouse
	
	if em_primeira_pessoa:
		rotacao_y = clamp(rotacao_y, deg_to_rad(-110), deg_to_rad(110))
		rotacao_x = clamp(rotacao_x, deg_to_rad(-40), deg_to_rad(45))
	else:
		rotacao_x = clamp(rotacao_x, deg_to_rad(-80), deg_to_rad(15))
