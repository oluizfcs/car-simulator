extends VehicleBody3D

const FORCE = 500
const STEER_MAX = 0.45
const STEER_SPEED = 1.8
const FORCA_TURBO = 12000.0
const FORCA_CONTROLE_AR = 3500.0
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
var capo_aberto: bool = false
var farol_ligado: bool = false

func _ready() -> void:
	atualizar_farois()

func _physics_process(delta: float) -> void:
	var velocidade_kmh = linear_velocity.length() * 3.6
	var input_direcao = Input.get_axis("right", "left")
	var desvirar = Input.is_action_pressed("flip")
	
	# 1. Quanto mais rápido o carro está, menos o volante vira (evita rodar em alta velocidade)
	# A 0 km/h vira 100% do STEER_MAX; a 120 km/h vira cerca de 35%
	var fator_velocidade = clamp(1.0 - (velocidade_kmh / 180.0), 0.35, 1.0)
	var angulo_alvo = input_direcao * STEER_MAX * fator_velocidade
	var velocidade_volante = STEER_SPEED if input_direcao != 0 else STEER_SPEED * 1.8
	steering = move_toward(steering, angulo_alvo, delta * velocidade_volante)

	engine_force = Input.get_axis("down", "up") * FORCE

	if label:
		label.text = "%d km/h" % round(velocidade_kmh)
		
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
		roda_traseira_esquerda.get_skidinfo() < 0.85 or 
		(Input.is_action_pressed("ui_select") and velocidade_kmh > 15.0)
	)
	
	var derrapando_dir = roda_traseira_direita.is_in_contact() and (
		roda_traseira_direita.get_skidinfo() < 0.5 or 
		(Input.is_action_pressed("ui_select") and velocidade_kmh > 15.0)
	)

	if fumaca_esq:
		fumaca_esq.emitting = derrapando_esq
	if fumaca_dir:
		fumaca_dir.emitting = derrapando_dir
	
	var usando_turbo = Input.is_action_pressed("turbo")
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

func atualizar_farois() -> void:
	if grupo_farois:
		grupo_farois.visible = farol_ligado
		
	if mat_farol1 && mat_farol2:
		mat_farol1.emission_energy_multiplier = 8.0 if farol_ligado else 0.0
		mat_farol2.emission_energy_multiplier = 8.0 if farol_ligado else 0.0
