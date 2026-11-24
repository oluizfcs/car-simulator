extends VehicleBody3D

const FORCE = 500
const STEER_MAX = 0.45
const STEER_SPEED = 1.8
const FORCA_TURBO = 12000.0
const FORCA_CONTROLE_AR = 3500.0
const ALCANCE_BUZINA: float = 18.0
const FORCA_BUZINA: float = 250.0
@onready var roda_traseira_esquerda: VehicleWheel3D = $traseiraEsquerda
@onready var roda_traseira_direita: VehicleWheel3D = $traseiraDireita
@onready var roda_dianteira_esquerda: VehicleWheel3D = $dianteiraEsquerda
@onready var roda_dianteira_direita: VehicleWheel3D = $dianteiraDireita
@onready var hood: MeshInstance3D = $Hood
@onready var mat_freio: StandardMaterial3D = $Chassi.get_active_material(6)
@onready var grupo_farois: Node3D = $Farois
@onready var mat_farol1: StandardMaterial3D = $Chassi.get_active_material(4)
@onready var mat_farol2: StandardMaterial3D = $Chassi.get_active_material(5)
@onready var fogo_turbo_esq: GPUParticles3D = $Particulas/fogoTurboEsquerda
@onready var fogo_turbo_dir: GPUParticles3D = $Particulas/fogoTurboDireita
@onready var fumaca_esq: GPUParticles3D = $Particulas/fumacaDriftEsquerda
@onready var fumaca_dir: GPUParticles3D = $Particulas/fumacaDriftDireita
@onready var som_idle: AudioStreamPlayer3D = $SomMotorIdle
@onready var som_high: AudioStreamPlayer3D = $SomMotorHigh
@onready var som_pneu: AudioStreamPlayer3D = $SomPneu
@onready var som_batida: AudioStreamPlayer3D = $SomBatida
@onready var arco_velocidade: TextureProgressBar = $CanvasLayer/PainelVelocimetro/Margem/ArcoVelocidade
@onready var label_valor_vel: Label = $CanvasLayer/PainelVelocimetro/Margem/ArcoVelocidade/CentroTexto/ValorVel
@onready var linhas_velocidade: ColorRect = $CanvasLayer/ColorRect
@onready var som_buzina: AudioStreamPlayer3D = $SomBuzina
var capo_aberto: bool = false
var farol_ligado: bool = false
var rpm_suavizado: float = 0.0
var filtro_motor: AudioEffectLowPassFilter
var volume_pneu_atual: float = 0.0
var cooldown_batida: float = 0.0
var velocidade_anterior: Vector3 = Vector3.ZERO
var transform_inicial: Transform3D

func _ready() -> void:
	transform_inicial = global_transform
	atualizar_farois()
		
	var bus_idx = AudioServer.get_bus_index("Motor")
	if bus_idx != -1 and AudioServer.get_bus_effect_count(bus_idx) > 0:
		filtro_motor = AudioServer.get_bus_effect(bus_idx, 0)

func _physics_process(delta: float) -> void:
	var velocidade_kmh = linear_velocity.length() * 3.6
	
	if Input.is_action_just_pressed("reset"):
		resetar_tudo()
	
	# --- DETECÇÃO DE IMPACTO REAL (Força G / Desaceleração brusca) ---
	# Mede quantos km/h o carro perdeu ou mudou de direção bruscamente em 1 único frame
	var forca_impacto_kmh = (linear_velocity - velocidade_anterior).length() * 3.6
	
	if cooldown_batida > 0.0:
		cooldown_batida -= delta
	elif forca_impacto_kmh > 35.0 and som_batida:
		# Só toca em impactos fortes (> 35 km/h de pancada seca) e toca o áudio inteiro
		var intensidade = clamp((forca_impacto_kmh - 35.0) / 80.0, 0.4, 1.0)
		som_batida.volume_db = linear_to_db(intensidade)
		som_batida.pitch_scale = randf_range(0.9, 1.1)
		som_batida.play()
		cooldown_batida = 1.0 # Evita tocar de novo no rebote da mesma batida
	
	var usando_turbo = Input.is_action_pressed("turbo")
	var input_direcao = Input.get_axis("right", "left")
	var desvirar = Input.is_action_pressed("flip")
	
	# 1. Quanto mais rápido o carro está, menos o volante vira (evita rodar em alta velocidade)
	# A 0 km/h vira 100% do STEER_MAX; a 120 km/h vira cerca de 35%
	var fator_velocidade = clamp(1.0 - (velocidade_kmh / 180.0), 0.35, 1.0)
	var angulo_alvo = input_direcao * STEER_MAX * fator_velocidade
	var velocidade_volante = STEER_SPEED if input_direcao != 0 else STEER_SPEED * 1.8
	steering = move_toward(steering, angulo_alvo, delta * velocidade_volante)
	
	# Aceleração
	var acel = Input.get_axis("down", "up")
	engine_force = acel * FORCE
	
	if label_valor_vel:
		label_valor_vel.text = "%d" % round(velocidade_kmh / 2)

	if arco_velocidade:
		# Suaviza o movimento da barra
		arco_velocidade.value = lerp(arco_velocidade.value, velocidade_kmh, clampf(10.0 * delta, 0.0, 1.0))
		
	if Input.is_action_pressed("ui_select"):
		roda_traseira_esquerda.wheel_friction_slip = 0.8
		roda_traseira_direita.wheel_friction_slip = 0.8
		roda_dianteira_esquerda.wheel_friction_slip = 0.85
		roda_dianteira_direita.wheel_friction_slip = 0.85
	else:
		roda_traseira_esquerda.wheel_friction_slip = 3.0
		roda_traseira_direita.wheel_friction_slip = 3.0
		roda_dianteira_esquerda.wheel_friction_slip = 3.0
		roda_dianteira_direita.wheel_friction_slip = 3.0
	
	var derrapando_esq = roda_traseira_esquerda.is_in_contact() and (
		roda_traseira_esquerda.get_skidinfo() < 0.60 or 
		(Input.is_action_pressed("ui_select") and velocidade_kmh > 15.0)
	)
	
	if Input.is_action_just_pressed("horn"):
		som_buzina.play()
		onda_de_choque_buzina()
	
	var esta_acelerando = Input.is_action_pressed("up") or Input.is_action_pressed("turbo")
	
	var derrapando_dir = roda_traseira_direita.is_in_contact() and (
		roda_traseira_direita.get_skidinfo() < 0.60 or 
		(Input.is_action_pressed("ui_select") and velocidade_kmh > 15.0)
	)
	
	if cooldown_batida > 0.0:
		cooldown_batida -= delta

	# --- SOM DE CANTAR PNEU ---
	if som_pneu:
		var esta_derrapando = derrapando_esq or derrapando_dir
		var alvo_volume_pneu = 1.0 if esta_derrapando else 0.0
		
		# Faz o som entrar e sair suavemente (evita cortes secos)
		volume_pneu_atual = lerp(volume_pneu_atual, alvo_volume_pneu, 10.0 * delta)
		
		if volume_pneu_atual > 0.01:
			som_pneu.volume_db = linear_to_db(volume_pneu_atual * 0.4) # 
			som_pneu.pitch_scale = clamp(lerp(0.85, 1.0, velocidade_kmh / 140.0), 0.85, 1.3)
		else:
			som_pneu.volume_db = -80.0

	if fumaca_esq:
		fumaca_esq.emitting = derrapando_esq
	if fumaca_dir:
		fumaca_dir.emitting = derrapando_dir
	
	if usando_turbo:
		var direcao_frente = global_transform.basis.z
		apply_central_force(direcao_frente * FORCA_TURBO)
	
	if fogo_turbo_dir && fogo_turbo_esq:
		fogo_turbo_esq.emitting = usando_turbo
		fogo_turbo_dir.emitting = usando_turbo
	
	var no_ar = (
		not roda_traseira_esquerda.is_in_contact() and
		not roda_traseira_direita.is_in_contact() and
		not roda_dianteira_esquerda.is_in_contact() and
		not roda_dianteira_direita.is_in_contact()
	)

	atualizar_som_motor(delta, velocidade_kmh, esta_acelerando, no_ar)

	if no_ar:
		var pitch = Input.get_axis("up", "down")
		var yaw = Input.get_axis("right", "left")
		
		apply_torque(global_transform.basis.x * pitch * FORCA_CONTROLE_AR)
		apply_torque(global_transform.basis.y * yaw * (FORCA_CONTROLE_AR * 0.7))
		
		angular_damp = 3.0
	else:
		angular_damp = 0.0
	
	if desvirar:
		global_position.y += 0.2
		global_rotation = Vector3(global_rotation.x, global_rotation.y, 0)
		
	if Input.is_action_just_pressed("toggle_hood"):
		capo_aberto = !capo_aberto
		
	var angulo_alvo_capo = -150.0 if capo_aberto else -90.0
	hood.rotation_degrees.x = move_toward(hood.rotation_degrees.x, angulo_alvo_capo, 120.0 * delta)
	
	var freando = Input.is_action_pressed("down") or Input.is_action_pressed("ui_select")
	
	if mat_freio:
		mat_freio.emission_energy_multiplier = 6.0 if freando else 0.0
	
	if Input.is_action_just_pressed("toggle_headlights"):
		farol_ligado = !farol_ligado
		atualizar_farois()
	
	if linhas_velocidade and linhas_velocidade.material:
		var alvo_linhas = 1.0 if usando_turbo else 0.0
		var atual = linhas_velocidade.material.get_shader_parameter("intensidade")
		linhas_velocidade.material.set_shader_parameter("intensidade", lerp(atual, alvo_linhas, 8.0 * delta))
	
	velocidade_anterior = linear_velocity

func atualizar_farois() -> void:
	if grupo_farois:
		grupo_farois.visible = farol_ligado
		
	if mat_farol1 && mat_farol2:
		mat_farol1.emission_energy_multiplier = 8.0 if farol_ligado else 0.0
		mat_farol2.emission_energy_multiplier = 8.0 if farol_ligado else 0.0

func atualizar_som_motor(delta: float, velocidade_kmh: float, acelerando: bool, no_ar: bool) -> void:
	# 1. Calcula a intensidade do motor de 0.0 (parado) até 1.0
	var rpm_alvo = clamp(velocidade_kmh / 400.0, 0.0, 1.0)
	
	# Se estiver no ar, o motor cai para marcha lenta (a menos que ative o turbo)
	if no_ar and not Input.is_action_pressed("turbo"):
		rpm_alvo = 0.1
	elif Input.is_action_pressed("turbo") or (Input.is_action_pressed("ui_select") and acelerando):
		rpm_alvo = max(rpm_alvo, 0.85)
		
	# Suaviza a subida/descida do som
	rpm_suavizado = lerp(rpm_suavizado, rpm_alvo, 6.0 * delta)

	# 2. Reduz o volume geral do motor durante o voo (0.25 = -12 dB mais baixo)
	var fator_volume = 0.25 if (no_ar and not Input.is_action_pressed("turbo")) else 1.0

	# 3. Crossfade contínuo entre o som grave (Idle) e o som forte (High RPM)
	var peso_high = smoothstep(0.1, 0.7, rpm_suavizado)
	som_idle.volume_db = linear_to_db((1.0 - peso_high * 0.85) * fator_volume)
	som_high.volume_db = linear_to_db(peso_high * fator_volume)

	# 4. Sobe o tom (Pitch) continuamente conforme a velocidade aumenta
	som_idle.pitch_scale = lerp(0.85, 1.5, rpm_suavizado)
	som_high.pitch_scale = lerp(0.7, 1.6, rpm_suavizado)

	# 5. Fecha o filtro grave no voo (450 Hz) para dar efeito abafado de altitude
	if filtro_motor:
		var freq_alvo = 450.0 if (no_ar and not Input.is_action_pressed("turbo")) else (18000.0 if acelerando else 900.0)
		filtro_motor.cutoff_hz = lerp(filtro_motor.cutoff_hz, freq_alvo, 10.0 * delta)

func resetar_tudo() -> void:
	# 1. Reseta o carro (posição, rotação, velocidades e volante)
	linear_velocity = Vector3.ZERO
	angular_velocity = Vector3.ZERO
	velocidade_anterior = Vector3.ZERO
	engine_force = 0.0
	steering = 0.0
	global_transform = transform_inicial
	
	# 2. Reseta todos os cones e objetos físicos do mapa
	get_tree().call_group("objetos_resetaveis", "resetar_objeto")

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		get_tree().change_scene_to_file("res://menu_inicial.tscn")

func onda_de_choque_buzina() -> void:
	# Ponto de origem da onda: um pouco à frente do para-choque dianteiro
	var origem_onda = global_position + (global_transform.basis.z * 2.5)
	
	# Pega todos os cones e objetos físicos do grupo que você já criou
	for obj in get_tree().get_nodes_in_group("objetos_resetaveis"):
		if obj is RigidBody3D:
			var diferenca = obj.global_position - origem_onda
			var distancia = diferenca.length()
			
			if distancia <= ALCANCE_BUZINA:
				# Quanto mais perto do carro, mais forte o cone voa (de 0.2 até 1.0)
				var fator_proximidade = clamp(1.0 - (distancia / ALCANCE_BUZINA), 0.2, 1.0)
				var direcao = diferenca.normalized()
				
				# Adiciona um pouco de altura (Vector3.UP) para o cone levantar voo e capotar
				var impulso = (direcao + Vector3.UP * 0.45).normalized() * FORCA_BUZINA * fator_proximidade
				
				obj.sleeping = false # Acorda o RigidBody3D caso esteja parado
				obj.apply_central_impulse(impulso)
				# Dá um leve giro aleatório no ar para não voarem todos retos iguais
				obj.apply_torque_impulse(Vector3(randf_range(-2, 2), randf_range(-2, 2), randf_range(-2, 2)))
				
	var anel = get_node_or_null("OndaBuzina")
	if anel:
		# Faz o anel ignorar o movimento/rotação do pai (carro) no espaço 3D
		anel.top_level = true
		
		# Posiciona exatamente onde o carro está no momento do disparo (rente ao chão)
		anel.global_position = origem_onda - Vector3(0, 0.3, 0)
		anel.global_rotation = Vector3.ZERO
		anel.visible = true
		anel.scale = Vector3(0.5, 0.5, 0.5)
		
		var tween = create_tween()
		tween.tween_property(anel, "scale", Vector3(ALCANCE_BUZINA, 0.5, ALCANCE_BUZINA), 0.35)
		tween.tween_callback(func(): anel.visible = false)
