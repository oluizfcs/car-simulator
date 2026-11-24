extends Control

@export_file("*.tscn") var cena_jogo: String = "res://main.tscn"

@onready var botao_jogar: Button = $Centro/CaixaMenu/BotaoJogar
@onready var caixa_menu: VBoxContainer = $Centro/CaixaMenu
@onready var eixo_camera: Node3D = $Palco3D/EixoCamera
@onready var sol: DirectionalLight3D = $Palco3D/DirectionalLight3D
@onready var painel_controles: PanelContainer = $Centro/PainelControles
@onready var painel_creditos: PanelContainer = $Centro/PainelCreditos
@onready var botao_controles: Button = $Centro/CaixaMenu/BotaoControles
@onready var botao_creditos: Button = $Centro/CaixaMenu/BotaoCreditos
@onready var voltar_controles: Button = $Centro/PainelControles/Margem/VBox/VoltarControles
@onready var voltar_creditos: Button = $Centro/PainelCreditos/Margem/VBox/VoltarCreditos

func _ready() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	
	_mostrar_menu_principal()
	
	botao_jogar.pressed.connect(_on_jogar_pressed)
	botao_controles.pressed.connect(_on_controles_pressed)
	botao_creditos.pressed.connect(_on_creditos_pressed)
	
	voltar_controles.pressed.connect(_mostrar_menu_principal)
	voltar_creditos.pressed.connect(_mostrar_menu_principal)

func _process(delta: float) -> void:
	if eixo_camera:
		eixo_camera.rotate_y(0.35 * delta)
	if sol:
		sol.rotate_y(0.35 * delta)

func _unhandled_input(event: InputEvent) -> void:
	# Permite apertar ESC para fechar Controles ou Créditos
	if event.is_action_pressed("ui_cancel") and not caixa_menu.visible:
		_mostrar_menu_principal()

func _mostrar_menu_principal() -> void:
	caixa_menu.visible = true
	painel_controles.visible = false
	painel_creditos.visible = false
	botao_jogar.grab_focus()

func _on_controles_pressed() -> void:
	caixa_menu.visible = false
	painel_controles.visible = true
	painel_creditos.visible = false
	voltar_controles.grab_focus()

func _on_creditos_pressed() -> void:
	caixa_menu.visible = false
	painel_controles.visible = false
	painel_creditos.visible = true
	voltar_creditos.grab_focus()

func _on_jogar_pressed() -> void:
	if cena_jogo != "":
		get_tree().change_scene_to_file(cena_jogo)
