extends Node

var config := ConfigFile.new()

var game := {}
var player := {}
var blocks := {}
var magic := {}
var scoring := {}

func _ready():
	load_config()

func load_config():
	var err = config.load("res://config/game.cfg")
	if err != OK:
		push_error("Failed to load game.cfg")
		return

	game = load_section("game")
	player = load_section("player")
	blocks = load_section("blocks")
	magic = load_section("magic")
	scoring = load_section("scoring")

func load_section(section_name: String) -> Dictionary:
	var dict := {}
	var keys = config.get_section_keys(section_name)
	for key in keys:
		dict[key] = config.get_value(section_name, key)
	return dict
