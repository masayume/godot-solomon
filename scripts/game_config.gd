extends Node

var gamedata = {}
var blockdata = {}
var gridutils = {}
var monsterdata = {}

func _ready():
	load_config()

func load_config():
	var cfg = ConfigFile.new()
	var err = cfg.load("res://config/blocks.cfg")
	if err != OK:
		print("Failed to load blocks.cfg")
		return

	for section in cfg.get_sections():
		var data := {}
		for key in cfg.get_section_keys(section):
			data[key] = cfg.get_value(section, key)
		blockdata[section] = data

	var mcfg = ConfigFile.new()
	err = mcfg.load("res://config/monsters.cfg")
	if err != OK:
		print("Failed to load monsters.cfg")
		return

	for section in mcfg.get_sections():
		var data := {}
		for key in mcfg.get_section_keys(section):
			data[key] = mcfg.get_value(section, key)
		monsterdata[section] = data

	var gdcfg = ConfigFile.new()
	err = gdcfg.load("res://config/game.cfg")
	if err != OK:
		print("Failed to load game.cfg")
		return

	gamedata.TILE_SIZE = gdcfg.get_value("screen", "TILE_SIZE")
	gamedata.LEVEL_WIDTH = gdcfg.get_value("screen", "LEVEL_WIDTH")
	gamedata.LEVEL_HEIGHT = gdcfg.get_value("screen", "LEVEL_HEIGHT")
	
	# Read values from the config file
	gamedata.move_speed = gdcfg.get_value("player", "move_speed", 100)
	gamedata.jump_force = gdcfg.get_value("player", "jump_force", 300)
	gamedata.gravity = gdcfg.get_value("player", "gravity", 800)
	gamedata.off_xp = gdcfg.get_value("player", "off_xp", 200)

func grid_to_local(tile_x: int, tile_y: int, tile_size: int, x_off: float, y_off: float) -> Vector2:    
	var half_tile = tile_size / 2.0
	
	# 1. (tile_x - 1) makes grid 1 start at 0 pixels.
	# 2. Add half_tile to center the player/block origin in the grid cell.
	var world_x = (tile_x - 1) * tile_size + x_off + half_tile

	# Negative because logic Y grows UP (1 to 11), but Godot Y grows DOWN.
	# Subtract half_tile to stay centered in the cell vertically.
	var world_y = -(tile_y - 1) * tile_size - y_off - half_tile

	return Vector2(world_x, world_y)

func world_to_grid(world_pos: Vector2, x_off: float, y_off: float, tile_size: int) -> Vector2i:

	var local_x = world_pos.x - x_off
	var local_y = world_pos.y + y_off

	var grid_x = floor(local_x / tile_size) 
	var grid_y = - (floor(local_y / tile_size)) + 1

#	print("world_to_grid:" + str(grid_x) + " " + str(grid_y)) 
	return Vector2i(grid_x, grid_y)
