extends Node

var gamedata = {}
var blockdata = {}
var gridutils = {}
var monsterdata = {}
var itemdata = {}
var fxdata = {}
var score = 0
var current_level_id

func _ready():
	load_config()

func load_config():

	# LOAD BLOCKS CONFIGURATION DATA	
	var cfg = ConfigFile.new()
	var err = cfg.load("res://config/blocks.cfg")
	if err != OK:
		print("ERROR: Failed to load blocks.cfg")
		return

	for section in cfg.get_sections():
		var data := {}
		for key in cfg.get_section_keys(section):
			data[key] = cfg.get_value(section, key)
		blockdata[section] = data

	# LOAD MONSTERS CONFIGURATION DATA	
	var mcfg = ConfigFile.new()
	err = mcfg.load("res://config/monsters.cfg")
	if err != OK:
		print("ERROR: Failed to load monsters.cfg")
		return

	for section in mcfg.get_sections():
		var data := {}
		for key in mcfg.get_section_keys(section):
			data[key] = mcfg.get_value(section, key)
		monsterdata[section] = data

	# LOAD GAME CONFIGURATION DATA	
	var gdcfg = ConfigFile.new()
	err = gdcfg.load("res://config/game.cfg")
	if err != OK:
		print("ERROR: Failed to load game.cfg")
		return

	for section in gdcfg.get_sections():
		var data := {}
		for key in gdcfg.get_section_keys(section):
			data[key] = gdcfg.get_value(section, key)
		gamedata[section] = data

	# LOAD ITEM CONFIGURATION DATA	
	var icfg = ConfigFile.new()
	err = icfg.load("res://config/items.cfg")
	if err != OK:
		print("ERROR: Failed to load items.cfg")
		return

	for section in icfg.get_sections():
		var data := {}
		for key in icfg.get_section_keys(section):
			data[key] = icfg.get_value(section, key)
		itemdata[section] = data


	# LOAD ITEM CONFIGURATION DATA	
	var fxcfg = ConfigFile.new()
	err = fxcfg.load("res://config/fx.cfg")
	if err != OK:
		print("ERROR: Failed to load fx.cfg")
		return

	for section in fxcfg.get_sections():
		var data := {}
		for key in fxcfg.get_section_keys(section):
			data[key] = fxcfg.get_value(section, key)
		fxdata[section] = data

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
