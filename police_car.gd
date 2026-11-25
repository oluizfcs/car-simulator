extends CharacterBody3D

@export var velocidade_maxima: float = 28.0
@export var velocidade_turbo: float = 65.0          # Velocidade voando no turbo (~235 km/h)
@export var velocidade_curva: float = 5.0
@export var distancia_parada: float = 4.8
@export var altura_y_fixa: float = 0.0
@export var forca_empurrao_player: float = 18.0

@export var distancia_ativar_turbo: float = 55.0    # Distância 3D real (X, Y, Z)
@export var tempo_para_turbo: float = 4.0           # Reduzido para 4 segundos

@onready var luz_azul: OmniLight3D = $LuzAzul
@onready var luz_vermelha: OmniLight3D = $LuzVermelha
@onready var fogo_turbo_esq: GPUParticles3D = get_node_or_null("fogoTurboEsquerda")
@onready var fogo_turbo_dir: GPUParticles3D = get_node_or_null("fogoTurboDireita")

var alvo: Node3D = null
var tempo_giroflex: float = 0.0
var impulso_externo: Vector3 = Vector3.ZERO
var rotacao_capotamento: Vector3 = Vector3.ZERO
var voando_por_buzina: bool = false

var tempo_longe: float = 0.0
var tempo_voando: float = 0.0
var usando_turbo: bool = false

func _ready() -> void:
	add_to_group("viaturas_policia")
	add_to_group("objetos_resetaveis")
	alvo = get_tree().get_first_node_in_group("player")
	
	collision_mask = 0
	global_position.y = altura_y_fixa
	_atualizar_particulas_turbo(false)

func _physics_process(delta: float) -> void:
	# 1. Efeito Giroflex
	tempo_giroflex += delta * 10.0
	var alternar = sin(tempo_giroflex) > 0.0
	if luz_azul: luz_azul.visible = alternar
	if luz_vermelha: luz_vermelha.visible = not alternar

	# 2. Estado de Voo / Capotamento após buzina (tem prioridade sobre o turbo)
	if voando_por_buzina:
		usando_turbo = false
		tempo_longe = 0.0
		tempo_voando = 0.0
		_atualizar_particulas_turbo(false)
		
		velocity.y -= 20.0 * delta
		impulso_externo.x = move_toward(impulso_externo.x, 0.0, 3.0 * delta)
		impulso_externo.z = move_toward(impulso_externo.z, 0.0, 3.0 * delta)
		velocity.x = impulso_externo.x
		velocity.z = impulso_externo.z
		
		rotation += rotacao_capotamento * delta
		move_and_slide()
		
		if global_position.y <= altura_y_fixa and velocity.y <= 0.0:
			global_position.y = altura_y_fixa
			velocity = Vector3.ZERO
			impulso_externo = Vector3.ZERO
			voando_por_buzina = false
			rotation = Vector3(0.0, rotation.y, 0.0)
		return

	if not (alvo and is_instance_valid(alvo)):
		return

	var diferenca = alvo.global_position - global_position
	var distancia_3d = diferenca.length() # Distância real considerando X, Y e Z
	var direcao_plana = Vector3(diferenca.x, 0.0, diferenca.z)
	var distancia_plana = direcao_plana.length()

	# 3. Controle do cronômetro de distância 3D para o Turbo (4 segundos)
	if not usando_turbo:
		if distancia_3d > distancia_ativar_turbo:
			tempo_longe += delta
			if tempo_longe >= tempo_para_turbo:
				usando_turbo = true
				tempo_longe = 0.0
				tempo_voando = 0.0
				_atualizar_particulas_turbo(true)
		else:
			tempo_longe = max(0.0, tempo_longe - delta * 2.0)

	# 4. Modo TURBO VOADOR (vai direto na direção 3D do jogador pelo ar)
	if usando_turbo:
		tempo_voando += delta
		var alvo_voo = alvo.global_position + Vector3(0, 1.2, 0)
		var dir_3d = (alvo_voo - global_position).normalized()
		
		# Aponta a frente da viatura diretamente para o jogador no espaço 3D
		var rot_y = atan2(dir_3d.x, dir_3d.z)
		var rot_x = -asin(clamp(dir_3d.y, -0.8, 0.8))
		rotation.y = lerp_angle(rotation.y, rot_y, 8.0 * delta)
		rotation.x = lerp_angle(rotation.x, rot_x, 8.0 * delta)
		rotation.z = lerp_angle(rotation.z, 0.0, 8.0 * delta)
		
		velocity = dir_3d * velocidade_turbo
		move_and_slide()
		
		if distancia_3d <= 24.0:
			usando_turbo = false
			tempo_voando = 0.0
			_atualizar_particulas_turbo(false)
			rotation.x = 0.0
			rotation.z = 0.0
		return

	# 5. Perseguição normal no chão (com pouso suave caso tenha acabado de sair do turbo)
	if global_position.y > altura_y_fixa + 0.05:
		velocity.y -= 25.0 * delta
	else:
		velocity.y = 0.0
		global_position.y = altura_y_fixa

	if distancia_plana > distancia_parada:
		var dir_norm = direcao_plana.normalized()
		var rotacao_alvo = atan2(dir_norm.x, dir_norm.z)
		rotation.y = lerp_angle(rotation.y, rotacao_alvo, velocidade_curva * delta)

		var frente = global_transform.basis.z
		velocity.x = frente.x * velocidade_maxima
		velocity.z = frente.z * velocidade_maxima
	else:
		velocity.x = 0.0
		velocity.z = 0.0
		if alvo is RigidBody3D and distancia_plana > 0.1:
			var empurrao = direcao_plana.normalized() * forca_empurrao_player
			alvo.apply_central_force(empurrao * 150.0)

	# 6. Separação entre viaturas
	for outra in get_tree().get_nodes_in_group("viaturas_policia"):
		if outra != self and is_instance_valid(outra):
			var sep = global_position - outra.global_position
			sep.y = 0.0
			if sep.length() < 3.5 and sep.length() > 0.01:
				velocity += sep.normalized() * 10.0

	move_and_slide()

	if global_position.y < altura_y_fixa:
		global_position.y = altura_y_fixa
		velocity.y = 0.0

func _atualizar_particulas_turbo(ativo: bool) -> void:
	if fogo_turbo_esq:
		fogo_turbo_esq.emitting = ativo
	if fogo_turbo_dir:
		fogo_turbo_dir.emitting = ativo

func aplicar_impulso_buzina(impulso: Vector3) -> void:
	voando_por_buzina = true
	usando_turbo = false
	tempo_voando = 0.0
	_atualizar_particulas_turbo(false)
	
	global_position.y += 0.2
	impulso_externo = Vector3(impulso.x, 0.0, impulso.z)
	velocity.y = max(impulso.y, 26.0)
	
	rotacao_capotamento = Vector3(
		randf_range(-8.0, 8.0),
		randf_range(-6.0, 6.0),
		randf_range(-8.0, 8.0)
	)

func resetar_objeto() -> void:
	queue_free()
