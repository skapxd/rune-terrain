# **🧪 Laboratorio de Terreno Procedural (Godot 4.5.1+)**

Este laboratorio elimina la dependencia de assets artísticos. Genera texturas, físicas y biomas orgánicos mediante código, permitiendo iterar mecánicas de juego en un entorno de "Greyboxing" puro.

## **🏗️ Estructura de la Escena**

Para un funcionamiento óptimo en Godot 4.5.1+, configura la escena así:

* **Node2D** (LaboratorioMundo)  
  * **TileMapLayer** (GeneradorDeMundo) \-\> *Controla la malla y físicas*  
  * **CharacterBody2D** (Jugador) \-\> *Cuerpo de pruebas*  
    * **Sprite2D** \-\> *Textura: "Nuevo PlaceholderTexture2D"*  
    * **CollisionShape2D** \-\> *Círculo de colisión*  
    * **Camera2D** \-\> *Habilitar 'Position Smoothing'*

## **💻 Script: Generador de Mundo (Optimizado)**

Este script utiliza TileSetAtlasSource para inyectar una textura generada en RAM directamente al motor de físicas de Godot.  
`extends TileMapLayer`

`@export_group("Dimensiones")`  
`@export var width: int = 120`  
`@export var height: int = 80`  
`@export var tile_size: int = 32`

`@export_group("Algoritmo")`  
`@export var noise_frequency: float = 0.05`  
`@export var seed_random: bool = true`

`# Diccionario de Biomas: Color, Sólido (Colisión), Fricción`  
`var biomas = {`  
	`0: {"name": "Muro",   "color": Color("#1e1e2e"), "solid": true},   # Gris Oscuro`  
	`1: {"name": "Piso",   "color": Color("#a6e3a1"), "solid": false},  # Verde`  
	`2: {"name": "Hielo",  "color": Color("#89dceb"), "solid": false},  # Cian (Prueba de Física)`  
	`3: {"name": "Agua",   "color": Color("#1fb6ff"), "solid": true}    # Azul`  
`}`

`func _ready():`  
	`if seed_random:`  
		`randomize()`  
	`setup_atlas_and_physics()`  
	`generate_world()`

`func _input(event):`  
	`# Regenerar con la tecla 'R' o Espacio`  
	`if event.is_action_pressed("ui_accept"):`   
		`generate_world()`

`func setup_atlas_and_physics():`  
	`var ts = TileSet.new()`  
	`ts.tile_size = Vector2i(tile_size, tile_size)`  
	`ts.add_physics_layer(0) # Capa 0 para colisiones estándar`  
	  
	`# Creamos el Atlas en memoria`  
	`var img = Image.create(tile_size * biomas.size(), tile_size, false, Image.FORMAT_RGBA8)`  
	`var source = TileSetAtlasSource.new()`  
	  
	`var i = 0`  
	`for id in biomas:`  
		`var color = biomas[id]["color"]`  
		`img.fill_rect(Rect2i(i * tile_size, 0, tile_size, tile_size), color)`  
		  
		`var coords = Vector2i(i, 0)`  
		`source.create_tile(coords)`  
		  
		`# Configuración de Colisiones para Godot 4.5`  
		`if biomas[id]["solid"]:`  
			`var data = source.get_tile_data(coords, 0)`  
			`var rect = PackedVector2Array([`  
				`Vector2(-tile_size/2.0, -tile_size/2.0),`  
				`Vector2(tile_size/2.0, -tile_size/2.0),`  
				`Vector2(tile_size/2.0, tile_size/2.0),`  
				`Vector2(-tile_size/2.0, tile_size/2.0)`  
			`])`  
			`data.add_collision_polygon(0)`  
			`data.set_collision_polygon_points(0, 0, rect)`  
		`i += 1`  
	  
	`source.texture = ImageTexture.create_from_image(img)`  
	`ts.add_source(source)`  
	`self.tile_set = ts`

`func generate_world():`  
	`clear()`  
	`var noise = FastNoiseLite.new()`  
	`noise.seed = randi()`  
	`noise.frequency = noise_frequency`  
	`noise.noise_type = FastNoiseLite.TYPE_PERLIN`  
	  
	`for x in range(width):`  
		`for y in range(height):`  
			`var v = noise.get_noise_2d(x, y)`  
			`var tile_id = 1 # Suelo normal por defecto`  
			  
			`# Lógica de distribución de terreno`  
			`if v < -0.35: tile_id = 3   # Agua profunda`  
			`elif v < -0.15: tile_id = 2  # Hielo/Resbaladizo`  
			`elif v > 0.45: tile_id = 0   # Muros/Montañas`  
			  
			`set_cell(Vector2i(x, y), 0, Vector2i(tile_id, 0))`

## **🏃 Script: Movimiento de Prueba con Fricción**

Este script de jugador detecta en qué tipo de terreno estás parado para ajustar la velocidad, demostrando la utilidad del laboratorio:  
`extends CharacterBody2D`

`const SPEED = 300.0`  
`const ACCEL = 1500.0`  
`const FRICTION = 1200.0`

`@onready var tilemap: TileMapLayer = $"../GeneradorDeMundo"`

`func _physics_process(delta):`  
	`var input_dir = Input.get_vector("ui_left", "ui_right", "ui_up", "ui_down")`  
	  
	`# Lógica de detección de terreno (Opcional para el laboratorio)`  
	`var current_tile = tilemap.local_to_map(global_position)`  
	`var tile_data = tilemap.get_cell_tile_data(current_tile)`  
	  
	`var current_accel = ACCEL`  
	`if tile_data:`  
		`# Si el tile es 'Hielo' (ID 2), bajamos la fricción`  
		`var atlas_coords = tilemap.get_cell_atlas_coords(current_tile)`  
		`if atlas_coords.x == 2:`  
			`current_accel = 200.0 # Se siente resbaladizo`  
	  
	`if input_dir != Vector2.ZERO:`  
		`velocity = velocity.move_toward(input_dir * SPEED, current_accel * delta)`  
	`else:`  
		`velocity = velocity.move_toward(Vector2.ZERO, FRICTION * delta)`

	`move_and_slide()`

## **🔬 Nuevas Posibilidades en v4.5**

1. **Detección de Datos:** El script del jugador ahora muestra cómo usar get\_cell\_tile\_data para cambiar el comportamiento (ej. resbalar en el color cian).  
2. **Rendimiento:** TileMapLayer en la 4.5 está mucho mejor optimizado para capas grandes, por lo que puedes aumentar width y height a 500+ sin tirones.  
3. **Terrenos (Auto-tiling):** Si decides añadir arte más adelante, el sistema de "Terrains" de la 4.5 es más intuitivo para conectar tiles de forma inteligente.