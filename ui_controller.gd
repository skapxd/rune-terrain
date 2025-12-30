extends CanvasLayer

@onready var generator = $"../GeneradorDeMundo"

func _ready():
	$VBoxContainer/BtnGenerate.pressed.connect(_on_generate_pressed)
	$VBoxContainer/BtnSave.pressed.connect(_on_save_pressed)

func _on_generate_pressed():
	if generator:
		generator.on_generate_pressed()

func _on_save_pressed():
	if generator:
		generator.on_save_pressed()
