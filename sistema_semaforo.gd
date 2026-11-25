extends Node3D

@export var tempo_verde: float = 6.0
@export var tempo_amarelo: float = 2.0
@export var tempo_vermelho: float = 6.0

# Arraste o arquivo ViaturaPolicia.tscn para este campo no Inspetor!
@export var cena_viatura: PackedScene
@export var max_viaturas_ativas: int = 3

@onready var semaforo_vermelho: OmniLight3D = $semaforo/vermelho
@onready var semaforo_amarelo: OmniLight3D = $semaforo/amarelo
@onready var semaforo_verde: OmniLight3D = $semaforo/verde

@onready var pedestres_vermelho: OmniLight3D = $pedestres/vermelho
@onready var pedestres_amarelo: OmniLight3D = $pedestres/amarelo
@onready var pedestres_verde: OmniLight3D = $pedestres/verde

@onready var area_deteccao: Area3D = $AreaDeteccao
@onready var ponto_spawn: Marker3D = $PontoSpawnPolicia

var cooldown_multa: float = 0.0

func _ready() -> void:
	if area_deteccao:
		area_deteccao.body_entered.connect(_on_area_deteccao_body_entered)
	iniciar_ciclo()

func _process(delta: float) -> void:
	if cooldown_multa > 0.0:
		cooldown_multa -= delta

func _on_area_deteccao_body_entered(body: Node3D) -> void:
	# Verifica se quem entrou na área foi o carro, se o sinal está vermelho e se não está em cooldown
	if body.is_in_group("player") and semaforo_vermelho.visible and cooldown_multa <= 0.0:
		cooldown_multa = 5.0 # Evita spawnar várias viaturas no mesmo segundo
		print("INFRAÇÃO: Furou o sinal vermelho! Chamando polícia...")
		chamar_policia()
		chamar_policia()
		chamar_policia()

func chamar_policia() -> void:
	if not cena_viatura or not ponto_spawn:
		return
		
	# Limita o número total de viaturas na cidade para manter 60 FPS no navegador
	var viaturas_atuais = get_tree().get_nodes_in_group("viaturas_policia").size()
	if viaturas_atuais >= max_viaturas_ativas:
		return

	var viatura = cena_viatura.instantiate()
	get_tree().current_scene.add_child(viatura)
	viatura.global_transform = ponto_spawn.global_transform

func iniciar_ciclo() -> void:
	while is_inside_tree():
		# 1. Carros: VERDE | Pedestres: VERMELHO
		_definir_luzes(false, false, true,   true, false, false)
		await get_tree().create_timer(tempo_verde).timeout

		# 2. Carros: AMARELO | Pedestres: VERMELHO
		_definir_luzes(false, true, false,   true, false, false)
		await get_tree().create_timer(tempo_amarelo).timeout

		# 3. Carros: VERMELHO | Pedestres: VERDE
		_definir_luzes(true, false, false,   false, false, true)
		await get_tree().create_timer(tempo_vermelho).timeout

		# 4. Carros: VERMELHO | Pedestres: AMARELO
		_definir_luzes(true, false, false,   false, true, false)
		await get_tree().create_timer(tempo_amarelo).timeout

func _definir_luzes(
	car_vm: bool, car_am: bool, car_vd: bool,
	ped_vm: bool, ped_am: bool, ped_vd: bool
) -> void:
	semaforo_vermelho.visible = car_vm
	semaforo_amarelo.visible = car_am
	semaforo_verde.visible = car_vd

	pedestres_vermelho.visible = ped_vm
	pedestres_amarelo.visible = ped_am
	pedestres_verde.visible = ped_vd
