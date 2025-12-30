extends TileMapLayer

@export_group("Dimensiones")
@export var width: int = 120
@export var height: int = 80
@export var tile_size: int = 32

@export_group("Algoritmo")
@export var noise_frequency: float = 0.05
@export var seed_random: bool = true

# Diccionario de Biomas: Color, Sólido (Colisión), Fricción
var biomas = {
	0: {"name": "Muro",   "color": Color("#1e1e2e"), "solid": true},   # Gris Oscuro
	1: {"name": "Piso",   "color": Color("#a6e3a1"), "solid": false},  # Verde
	2: {"name": "Hielo",  "color": Color("#89dceb"), "solid": false},  # Cian (Prueba de Física)
	3: {"name": "Agua",   "color": Color("#1fb6ff"), "solid": true}    # Azul
}

func _ready():
	if seed_random:
		randomize()
	setup_atlas_and_physics()
	generate_world()

func _input(event):
	# Regenerar con la tecla 'R' o Espacio
	if event.is_action_pressed("ui_accept"): 
		generate_world()

func setup_atlas_and_physics():
	var ts = TileSet.new()
	ts.tile_size = Vector2i(tile_size, tile_size)
	ts.add_physics_layer(0) # Capa 0 para colisiones estándar
	
	# 1. Preparar la imagen (Textura)
	var img = Image.create(tile_size * biomas.size(), tile_size, false, Image.FORMAT_RGBA8)
	
	var i = 0
	for id in biomas:
		var color = biomas[id]["color"]
		img.fill_rect(Rect2i(i * tile_size, 0, tile_size, tile_size), color)
		i += 1
	
	# 2. Configurar el Source
	var source = TileSetAtlasSource.new()
	source.texture = ImageTexture.create_from_image(img)
	source.texture_region_size = Vector2i(tile_size, tile_size)
	
	# Agregamos el source al TileSet ANTES de crear tiles para asegurar consistencia
	ts.add_source(source)
	
	# 3. Crear tiles y físicas
	i = 0
	for id in biomas:
		var coords = Vector2i(i, 0)
		source.create_tile(coords)
		
		# Configuración de Colisiones para Godot 4.5
		if biomas[id]["solid"]:
			var data = source.get_tile_data(coords, 0)
			if data:
				var rect = PackedVector2Array([
					Vector2(-tile_size/2.0, -tile_size/2.0),
					Vector2(tile_size/2.0, -tile_size/2.0),
					Vector2(tile_size/2.0, tile_size/2.0),
					Vector2(-tile_size/2.0, tile_size/2.0)
				])
				data.add_collision_polygon(0)
				data.set_collision_polygon_points(0, 0, rect)
		i += 1
	
	self.tile_set = ts

func generate_world():
	clear()
	var noise = FastNoiseLite.new()
	noise.seed = randi()
	noise.frequency = noise_frequency
	noise.noise_type = FastNoiseLite.TYPE_PERLIN
	
	for x in range(width):
		for y in range(height):
			var v = noise.get_noise_2d(x, y)
			var tile_id = 1 # Suelo normal por defecto
			
			# Lógica de distribución de terreno
			if v < -0.35: tile_id = 3   # Agua profunda
			elif v < -0.15: tile_id = 2  # Hielo/Resbaladizo
			elif v > 0.45: tile_id = 0   # Muros/Montañas
			
			set_cell(Vector2i(x, y), 0, Vector2i(tile_id, 0))
