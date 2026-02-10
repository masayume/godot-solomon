extends Node2D

@export var block_scene: PackedScene
@export var player_scene: PackedScene

func _ready():
	load_level(1)

func load_level(id: int):
	var path = "res://levels/level_%02d.json" % id
	var file = FileAccess.open(path, FileAccess.READ)
	var data = JSON.parse_string(file.get_as_text())

	var tile_size = data["tile_size"]

	# Spawn player
	var p = player_scene.instantiate()
	p.position = Vector2(
		data["player_start"][0] * tile_size,
		data["player_start"][1] * tile_size
	)
	add_child(p)

	# Spawn blocks
	for b in data["blocks"]:
		var block = block_scene.instantiate()
		block.position = Vector2(b[0] * tile_size, b[1] * tile_size)
		add_child(block)
	
