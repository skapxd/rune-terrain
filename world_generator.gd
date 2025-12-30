extends TileMapLayer

@export_group("Dimensiones")
@export var width: int = 120
@export var height: int = 80
@export var tile_size: int = 32

@export_group("Algoritmo")
@export var noise_frequency: float = 0.05
@export var seed_random: bool = true

# Definición de Colores de la Paleta
const C_AGUA_PROF = Color("#2a3b4e")
const C_AGUA      = Color("#4fa4b8")
const C_ARENA     = Color("#e8c170")
const C_PASTO     = Color("#92c86e")
const C_ROCA      = Color("#5c5e60")
const C_NIEVE     = Color("#dcebf5")

# Diccionario de Biomas
var biomas = {
	0: {"name": "Agua Profunda", "color": C_AGUA_PROF, "solid": true},
	1: {"name": "Agua",          "color": C_AGUA,      "solid": true},
	2: {"name": "Agua -> Arena", "color": C_AGUA,      "mix_color": C_ARENA, "mix_ratio": 0.4, "solid": true},
	3: {"name": "Arena",         "color": C_ARENA,     "solid": false},
	4: {"name": "Arena -> Pasto","color": C_ARENA,     "mix_color": C_PASTO, "mix_ratio": 0.3, "solid": false},
	5: {"name": "Pasto",         "color": C_PASTO,     "solid": false},
	6: {"name": "Pasto -> Roca", "color": C_PASTO,     "mix_color": C_ROCA,  "mix_ratio": 0.3, "solid": false},
	7: {"name": "Roca",          "color": C_ROCA,      "solid": true},
	8: {"name": "Roca -> Nieve", "color": C_ROCA,      "mix_color": C_NIEVE, "mix_ratio": 0.4, "solid": true},
	9: {"name": "Nieve",         "color": C_NIEVE,     "solid": true}
}

func _ready():
	# Try to load existing map first
	var loaded = MapLoader.load_map(self)
	
	if loaded:
		print("Mapa cargado desde JSON.")
		update_camera_limits()
	else:
		print("Generando nuevo mapa...")
		if seed_random:
			randomize()
		setup_atlas_and_physics()
		generate_world()

func _input(event):
	if event.is_action_pressed("ui_accept"): 
		generate_world()

# Called by UI button
func on_generate_pressed():
	setup_atlas_and_physics() # Ensure atlas is fresh/reset
	generate_world()

# Called by UI button
func on_save_pressed():
	# Convert biomas colors to hex strings for JSON safety if needed, 
	# but Color works with JSON.stringify in Godot 4 (saves as html string usually).
	# However, MapLoader expects to read them back.
	# Let's pass the dictionary directly.
	MapLoader.save_map(self, biomas, tile_size)

func setup_atlas_and_physics():
	var ts = TileSet.new()
	ts.tile_size = Vector2i(tile_size, tile_size)
	ts.add_physics_layer(0)
	
	# 1. Preparar la imagen
	var img = Image.create(tile_size * biomas.size(), tile_size, false, Image.FORMAT_RGBA8)
	
	var i = 0
	for id in biomas:
		var base_color = biomas[id]["color"]
		
		# Generación Procedural de Textura (Pixel por Pixel)
		for x in range(tile_size):
			for y in range(tile_size):
				var final_color = base_color
				
				# Si tiene mezcla, aplicamos "ruido"
				if biomas[id].has("mix_color"):
					var mix_color = biomas[id]["mix_color"]
					var ratio = biomas[id]["mix_ratio"]
					
					# Probabilidad simple para el efecto de "salpicado"
					if randf() < ratio:
						final_color = mix_color
				
				img.set_pixel( (i * tile_size) + x, y, final_color )
		
		i += 1
	
	# 2. Configurar el Source
	var source = TileSetAtlasSource.new()
	source.texture = ImageTexture.create_from_image(img)
	source.texture_region_size = Vector2i(tile_size, tile_size)
	
	ts.add_source(source)
	
	# 3. Crear tiles y físicas
	i = 0
	for id in biomas:
		var coords = Vector2i(i, 0)
		source.create_tile(coords)
		
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
	noise.fractal_octaves = 4
	
	for x in range(width):
		for y in range(height):
			var v = noise.get_noise_2d(x, y)
			var tile_id = 1 
			
			if v < -0.4:   tile_id = 0
			elif v < -0.2: tile_id = 1
			elif v < -0.1: tile_id = 2
			elif v < 0.05: tile_id = 3
			elif v < 0.15: tile_id = 4
			elif v < 0.4:  tile_id = 5
			elif v < 0.5:  tile_id = 6
			elif v < 0.65: tile_id = 7
			elif v < 0.75: tile_id = 8
			else:          tile_id = 9
			
			# Map the ID to the atlas coordinates.
			# Our atlas is a horizontal strip. ID 0 is at x=0, ID 1 at x=1, etc.
			# NOTE: We must ensure this mapping matches the 'i' index used in setup_atlas.
			# The original code iterated `for id in biomas`. Dictionaries are not ordered in all Godot versions,
			# but in Godot 4 they preserve insertion order usually.
			# To be safe, we should assume keys 0..9 map to x 0..9 if defined that way.
			# The original code used `i` as the x-coordinate.
			# Let's assume biomas keys 0,1,2... correspond to indices 0,1,2... for now as per original code.
			
			set_cell(Vector2i(x, y), 0, Vector2i(tile_id, 0))
	
	update_camera_limits()

func update_camera_limits():
	var camera = get_node_or_null("../Jugador/Camera2D")
	if camera:
		camera.limit_left = 0
		camera.limit_top = 0
		camera.limit_right = width * tile_size
		camera.limit_bottom = height * tile_size
