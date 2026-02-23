extends Node2D

@export var block_scene: PackedScene
@export var player_scene: PackedScene

@onready var level_label: Label = $"../../UI/LevelInfo"

func _ready():

	center_level()	
	load_level(99)

func center_level():
	var ts = GameConfig.gamedata.TILE_SIZE
	var w = GameConfig.gamedata.LEVEL_WIDTH
	var h = GameConfig.gamedata.LEVEL_HEIGHT

#	var screen_size = get_viewport_rect().size
#	var level_pixel_size = Vector2(w * ts, h * ts)


func load_level(id: int):
	var path = "res://levels/level_%02d.json" % id
	var file = FileAccess.open(path, FileAccess.READ)
	var data = JSON.parse_string(file.get_as_text())

	var tile_size = data["tile_size"]
	var width = data["block_width"]
	var height = data["block_height"]

	var screen_size = get_viewport_rect().size
	
	# show level info: level_loader reads it → exposes it → UI displays it.
	level_label.text = "LEVEL %d - %s" % [data["id"], data["name"]]

	var position_x = (-screen_size[0] / 2) + ((width / 2) * tile_size) / 2
	var position_y = -((height / 2) * tile_size) 

#	# Spawn player
#	var p = player_scene.instantiate()
#	p.position = Vector2(
#		data["player_start"][0] * tile_size,
#		data["player_start"][1] * tile_size
#	)
#	add_child(p)

	# Spawn blocks
	for b in data["blocks"]:
		var block = block_scene.instantiate()
		
		var block_x =  position_x + (b["pos"][0] * tile_size)
		var block_y = -position_y - (b["pos"][1] * tile_size)
		
		block.position = Vector2(block_x, block_y)
		block.family = b["family"]
		
		print("screen_size: " + str(screen_size) + " " + str(b["pos"][0]) + "," + str(b["pos"][1]) +  ": (" + b["family"] + ")")
		print("x: " + str(block_x) + " pos.x: " + str(block_x) + " + " + str( b["pos"][0] * tile_size ) )
		print("y: " + str(block_y) + " -pos.y: " + str(block_y) + " - " + str(b["pos"][1] * tile_size ) )
	
		add_child(block)
