extends Node

var blocks_data = {}
var gamedata = {}
var gridutils = {}

func _ready():
	load_config()

func load_config():
	var cfg = ConfigFile.new()
	var err = cfg.load("res://data/blocks.cfg")
	if err != OK:
		print("Failed to load blocks.cfg")
		return

	for section in cfg.get_sections():
		var d = {}
		for key in cfg.get_section_keys(section):
			d[key] = cfg.get_value(section, key)
		blocks_data[section] = d

	var gdcfg = ConfigFile.new()
	err = gdcfg.load("res://config/game.cfg")
	if err != OK:
		print("Failed to load game.cfg")
		return

	gamedata.TILE_SIZE = gdcfg.get_value("screen", "TILE_SIZE")
	gamedata.LEVEL_WIDTH = gdcfg.get_value("screen", "LEVEL_WIDTH")
	gamedata.LEVEL_HEIGHT = gdcfg.get_value("screen", "LEVEL_HEIGHT")
	
	# Read values from the config file
	gamedata.move_speed = cfg.get_value("player", "move_speed", 100)
	gamedata.jump_force = cfg.get_value("player", "jump_force", 300)
	gamedata.gravity = cfg.get_value("player", "gravity", 800)

func grid_to_local(tile_x: int, tile_y: int, tile_size: int, x_off: float, y_off: float) -> Vector2:    
	# Convert grid X coordinate into pixel X position
	var world_x = tile_x * tile_size + x_off

	# Convert grid Y coordinate into pixel Y position
	# Negative because your grid grows upward, but Godot Y grows downward
	var world_y = -tile_y * tile_size - y_off

	# Return final local position in pixels
	return Vector2(world_x, world_y)
