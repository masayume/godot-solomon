extends Node

var blocks_data = {}

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
