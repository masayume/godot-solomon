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

	var screen_size = get_viewport_rect().size
	var level_pixel_size = Vector2(w * ts, h * ts)

	# X: normal
	position.x = (screen_size.x - level_pixel_size.x) / 2

	# Y: bottom-left system (THIS is the correct one)
	position.y = screen_size.y / 2 + level_pixel_size.y / 2
	
	
func load_level(id: int):
	var path = "res://levels/level_%02d.json" % id
	var file = FileAccess.open(path, FileAccess.READ)
	var data = JSON.parse_string(file.get_as_text())

	var tile_size = data["tile_size"]
	
	# show level info: level_loader reads it → exposes it → UI displays it.
	level_label.text = "LEVEL %d - %s" % [data["id"], data["name"]]

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
		block.position = Vector2(b["pos"][0] * tile_size, -b["pos"][1] * tile_size)
		block.family = b["family"]
		add_child(block)
