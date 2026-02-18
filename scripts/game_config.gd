extends Node

var blocks_data = {}
var gamedata = {}

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
