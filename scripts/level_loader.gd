extends Node2D

@export var block_scene: PackedScene
@export var player_scene: PackedScene

@onready var level_label: Label = $"../../UI/LevelInfo"

func _ready():
	load_level(99)

#func grid_to_local(tile_x: int, tile_y: int, ts: int, xoff, yoff) -> Vector2:
#	return Vector2(
#		xoff + tile_x * ts,
#		-yoff - tile_y * ts
#	)

func spawn_player_deferred(start, x_off, y_off):
	var player = player_scene.instantiate()

	# Add player safely after tree is ready
	get_parent().call_deferred("add_child", player)

	# Also defer the spawn call to next frame
	player.call_deferred(
		"spawn_at",
		start[0],
		start[1],
		x_off,
		y_off
	)

func load_level(id: int):
	var path = "res://levels/level_%02d.json" % id
	var file = FileAccess.open(path, FileAccess.READ)
	var data = JSON.parse_string(file.get_as_text())

	var tile_size = data["tile_size"]
	var width = data["block_width"]
	var height = data["block_height"]
	var player_start = data["player_start"]

	var screen_size = get_viewport_rect().size
	
	# show level info: level_loader reads it → exposes it → UI displays it.
	level_label.text = "LEVEL %d - %s" % [data["id"], data["name"]]

	var x_off = (-screen_size[0] / 2) + ((width / 2) * tile_size) / 2
	var y_off = -((height / 2) * tile_size) 

	# Spawn Player AFTER offsets are known
	var player = player_scene.instantiate()
	# Add to the SAME parent as Level
	# Don't call add_child() while the scene tree is still inside _ready() construction.
	# Godot prevents modifying the tree while it's building it.
	get_parent().call_deferred("add_child", player)
	
	spawn_player_deferred(
		Vector2(player_start[0],   # grid X
		player_start[1]),   # grid Y
		x_off,             # same centering offset used for blocks
		y_off
	)
	print("player_start: [" + str(player_start[0]) + ","  + str(player_start[1]) + "] x_off:"  + str(x_off) + " y_off:"  + str(y_off))


	# Spawn blocks
	for b in data["blocks"]:
		# Create a new block instance from scene
		var block = block_scene.instantiate()

		# Extract grid coordinates from JSON
		var block_x = b["pos"][0]
		var block_y = b["pos"][1]

		# Convert grid position into pixel position
		block.position = GameConfig.grid_to_local(
			block_x,        # grid column
			block_y,        # grid row
			tile_size,      # size of one tile in pixels
			x_off,          # horizontal centering offset
			y_off           # vertical centering offset
		)

		# Assign gameplay property
		block.family = b["family"]

		# Add block to Level node
		add_child(block)

#	for b in data["blocks"]:
#		var block = block_scene.instantiate()
#		var block_x = (b["pos"][0])
#		var block_y = (b["pos"][1])
#		block.position = GameConfig.grid_to_local(block_x, block_y, tile_size, x_off, y_off)
#		block.family = b["family"]
#		print("block.family: " + str(block.family) + "; block position " + str(block.position) )
#		add_child(block)
