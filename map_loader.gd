class_name MapLoader
extends Node

const SAVE_PATH = "res://map_data.json"

# Saves the current state of a TileMapLayer to a JSON file with CSV-style grid data
static func save_map(layer: TileMapLayer, biomes_config: Dictionary, tile_size: int):
	# Determine the bounds of the map
	var rect = layer.get_used_rect()
	
	# Create the grid data (List of CSV strings)
	var grid_rows = []
	for y in range(rect.position.y, rect.end.y):
		var row_values = []
		for x in range(rect.position.x, rect.end.x):
			var coords = Vector2i(x, y)
			# We only need the atlas_coords.x which corresponds to the Biome ID in this system
			# If cell is empty, we can use -1
			if layer.get_cell_source_id(coords) != -1:
				var atlas_coords = layer.get_cell_atlas_coords(coords)
				row_values.append(str(atlas_coords.x))
			else:
				row_values.append("-1")
		
		# Join the row into a comma-separated string
		grid_rows.append(",".join(row_values))

	var data = {
		"version": "1.0",
		"tile_size": tile_size,
		"origin_x": rect.position.x, # Save origin in case map isn't at 0,0
		"origin_y": rect.position.y,
		"legend": _serialize_biomes(biomes_config),
		"grid": grid_rows
	}
	
	var file = FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file:
		# Indent with tab for readability, creating that "CSV inside JSON" look
		file.store_string(JSON.stringify(data, "\t"))
		print("Map saved to: ", ProjectSettings.globalize_path(SAVE_PATH))
	else:
		printerr("Error saving map to: ", SAVE_PATH)

static func _serialize_biomes(biomes: Dictionary) -> Dictionary:
	var serialized = {}
	for id in biomes:
		var b = biomes[id].duplicate()
		if b.has("color") and b["color"] is Color:
			# to_html(false) excludes alpha channel if we want strict hex matching
			# Check if alpha is 1 (opaque) to keep it clean, or just always force false if you don't use transparency
			var c = b["color"] as Color
			b["color"] = c.to_html(false) if c.a >= 0.99 else c.to_html()
			
		if b.has("mix_color") and b["mix_color"] is Color:
			var c = b["mix_color"] as Color
			b["mix_color"] = c.to_html(false) if c.a >= 0.99 else c.to_html()
			
		serialized[str(id)] = b # Ensure ID is stringified explicitly to avoid JSON ambiguity
	return serialized

# Loads a map from JSON into a TileMapLayer
# Returns true if successful, false otherwise
static func load_map(layer: TileMapLayer) -> bool:
	if not FileAccess.file_exists(SAVE_PATH):
		return false
	
	var file = FileAccess.open(SAVE_PATH, FileAccess.READ)
	if not file:
		return false
	
	var json_text = file.get_as_text()
	var json = JSON.new()
	var error = json.parse(json_text)
	
	if error != OK:
		printerr("JSON Parse Error: ", json.get_error_message())
		return false
	
	var data = json.data
	
	# 1. Reconstruct the TileSet based on saved legend
	var tile_size = int(data.get("tile_size", 32))
	var origin_x = int(data.get("origin_x", 0))
	var origin_y = int(data.get("origin_y", 0))
	
	var biomes = {}
	# Handle legacy or new format check if needed, but we assume new format now
	if data.has("legend"):
		for k in data["legend"]:
			biomes[int(k)] = _convert_biome_from_json(data["legend"][k])
	
	_setup_atlas_and_physics(layer, biomes, tile_size)
	
	# 2. Set the cells from the CSV-style grid
	layer.clear()
	
	var grid = data.get("grid", [])
	for y_offset in range(grid.size()):
		var row_string = grid[y_offset]
		var cell_values = row_string.split(",")
		
		for x_offset in range(cell_values.size()):
			var biome_id = int(cell_values[x_offset])
			
			if biome_id != -1:
				var coords = Vector2i(origin_x + x_offset, origin_y + y_offset)
				# In this system, Source ID is always 0, and Atlas X is the Biome ID
				layer.set_cell(coords, 0, Vector2i(biome_id, 0))
		
	return true

static func _convert_biome_from_json(biome_data: Dictionary) -> Dictionary:
	var new_biome = biome_data.duplicate()
	if new_biome.has("color") and new_biome["color"] is String:
		new_biome["color"] = Color(new_biome["color"])
	if new_biome.has("mix_color") and new_biome["mix_color"] is String:
		new_biome["mix_color"] = Color(new_biome["mix_color"])
	return new_biome

static func _setup_atlas_and_physics(layer: TileMapLayer, biomes: Dictionary, tile_size: int):
	var ts = TileSet.new()
	ts.tile_size = Vector2i(tile_size, tile_size)
	ts.add_physics_layer(0)
	
	var img = Image.create(tile_size * biomes.size(), tile_size, false, Image.FORMAT_RGBA8)
	
	var i = 0
	var sorted_keys = biomes.keys()
	sorted_keys.sort()
	
	# Map biome ID to atlas position
	var id_to_atlas_x = {}
	
	for id in sorted_keys:
		var biome = biomes[id]
		var base_color = biome["color"]
		id_to_atlas_x[id] = i
		
		for x in range(tile_size):
			for y in range(tile_size):
				var final_color = base_color
				if biome.has("mix_color"):
					var mix_color = biome["mix_color"]
					var ratio = biome["mix_ratio"]
					if randf() < ratio:
						final_color = mix_color
				img.set_pixel((i * tile_size) + x, y, final_color)
		i += 1
	
	var source = TileSetAtlasSource.new()
	source.texture = ImageTexture.create_from_image(img)
	source.texture_region_size = Vector2i(tile_size, tile_size)
	ts.add_source(source)
	
	for id in sorted_keys:
		var biome = biomes[id]
		var atlas_idx = id_to_atlas_x[id]
		var coords = Vector2i(atlas_idx, 0)
		
		if not source.has_tile(coords):
			source.create_tile(coords)
		
		if biome.get("solid", false):
			var tile_data = source.get_tile_data(coords, 0)
			if tile_data:
				var rect = PackedVector2Array([
					Vector2(-tile_size/2.0, -tile_size/2.0),
					Vector2(tile_size/2.0, -tile_size/2.0),
					Vector2(tile_size/2.0, tile_size/2.0),
					Vector2(-tile_size/2.0, tile_size/2.0)
				])
				tile_data.add_collision_polygon(0)
				tile_data.set_collision_polygon_points(0, 0, rect)
	
	layer.tile_set = ts