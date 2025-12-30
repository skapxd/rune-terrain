extends CharacterBody2D

const SPEED = 300.0
const ACCEL = 1500.0
const FRICTION = 1200.0

@onready var tilemap: TileMapLayer = $"../GeneradorDeMundo"

func _physics_process(delta):
	var input_dir = Input.get_vector("ui_left", "ui_right", "ui_up", "ui_down")
	
	# Lógica de detección de terreno (Opcional para el laboratorio)
	var current_tile = tilemap.local_to_map(global_position)
	var tile_data = tilemap.get_cell_tile_data(current_tile)
	
	var current_accel = ACCEL
	if tile_data:
		# Si el tile es 'Hielo' (ID 2), bajamos la fricción
		var atlas_coords = tilemap.get_cell_atlas_coords(current_tile)
		if atlas_coords.x == 2:
			current_accel = 200.0 # Se siente resbaladizo
	
	if input_dir != Vector2.ZERO:
		velocity = velocity.move_toward(input_dir * SPEED, current_accel * delta)
	else:
		velocity = velocity.move_toward(Vector2.ZERO, FRICTION * delta)

	move_and_slide()
