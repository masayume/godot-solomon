extends Node2D

@export var block_scene: PackedScene
@export var player_scene: PackedScene
@export var monster_scene: PackedScene

@onready var level_label: Label = $"../../UI/LevelInfo"
const Grid = preload("res://scripts/grid.gd")

#var monster_scene = preload("res://Monster.tscn")
var tile_size
var x_off: float
var y_off: float
var blocks := {} 	## blocks dictionary to check/update; Vector2i  →  Block node
var monsters := {} 	## monsters dictionary to check/update; Vector2i  →  Block node

func _ready():
	center_level()
	load_level(1)

func center_level():
	# print("THIS NODE:", get_path())
	var screen_size = get_viewport_rect().size
	var level_root = get_parent()

	if level_root == null:
		print("ERROR: level_root not found")
		return

	tile_size = GameConfig.gamedata.TILE_SIZE
	var width = GameConfig.gamedata.LEVEL_WIDTH
	var height = GameConfig.gamedata.LEVEL_HEIGHT

	var level_pixels = Vector2(width * tile_size, height * tile_size)

	level_root.position = (screen_size - level_pixels) / 2 + Vector2(0, 512.0)
	print("LEVEL POSITION:", level_root.position)

###DEBUG
#func _process(delta):
#	print("LEVEL POS:", position)

		
func spawn_monster(tile_x, tile_y):
	var monster = monster_scene.instantiate()
	monster.position = Vector2(tile_x * tile_size, tile_y * tile_size)
#	level.add_child(monster)
	call_deferred("add_child", monster)

func _on_player_fire(pos, dir, crouching):
	create_or_destroy_block(pos, dir, crouching)

func create_or_destroy_block(pos, dir, crouching):

	var cell = Grid.world_to_grid(pos, x_off, y_off, tile_size)

#	print("create/destroy block at: " + str(pos) + " " + str(dir))
# var destructible = config.get_value("block_" + block.block_type, "destructible", false)

#	var dir = Vector2i(1,0)   # right
#	var dir = Vector2i(-1,0)  # left

	if crouching:
		cell.y -= 1

	var target = Vector2i(cell.x + dir, cell.y)
			
	if blocks.has(target):
		var block = blocks[target]
		
#		if block.family == "earth":
		if GameConfig.blockdata[block.family]["destructible"]:
			block.queue_free()
			blocks.erase(target)

	else:
#		add_block(cell[0], cell[1], 'earth')
		add_block(target.x, target.y, 'earth')


###DEBUGz	
#	print(blocks)zzz


func spawn_player(px, py, xoff, yoff):

	var player = player_scene.instantiate()

	# add to the SAME node that holds the blocks
	add_child(player)

	# now the transform chain is correct
	player.spawn_at(px, py, xoff, yoff)
	player.fire_pressed.connect(_on_player_fire)


func load_level(id: int):
	var path = "res://levels/level_%02d.json" % id
	var file = FileAccess.open(path, FileAccess.READ)
	var data = JSON.parse_string(file.get_as_text())

	tile_size = data["tile_size"]
	var width = data["block_width"]
	var height = data["block_height"]
	var player_start = data["player_start"]

	var screen_size = get_viewport_rect().size

	var level_pixel_size = Vector2(
		width * tile_size,
		height * tile_size
	)
	
	var LevelRoot = get_parent()
	LevelRoot.position.x = (screen_size.x - level_pixel_size.x) / 2
	LevelRoot.position.y = -tile_size -(screen_size.y - level_pixel_size.y) / 2
	
	# show level info: level_loader reads it → exposes it → UI displays it.
	level_label.text = "LEVEL %d - %s" % [data["id"], data["name"]]

	x_off = (-screen_size[0] / 2) + ((width / 2) * tile_size) / 2
	y_off = -((height / 2) * tile_size) 

	spawn_player(
		player_start[0],   # grid X
		player_start[1],   # grid Y
		x_off,       	   # same centering offset used for blocks
		y_off
	)
	# print("player_start: [" + str(player_start[0]) + ","  + str(player_start[1]) + "] x_off:"  + str(x_off) + " y_off:"  + str(y_off))

	if data.has("monsters"):
		for m in data["monsters"]:
			# Create a new monster instance from scene		
			add_monster(m["pos"][0], m["pos"][1], m["family"])

	# Spawn blocks
	for b in data["blocks"]:
		# Create a new block instance from scene
		add_block(b["pos"][0], b["pos"][1], b["family"])


func add_block(bx, by, type):
	var block = block_scene.instantiate()

	var block_x = bx
	var block_y = by

	block.family = type
	
	block.add_to_group("debug_collision")

	add_child(block)
	var cell = Vector2i(bx, by)
	blocks[cell] = block

	
###DEBUG
#	print(str(type) + " block added at [" + str(bx) + "," + str(by) + "]")
		
	block.position = GameConfig.grid_to_local(
		block_x,        # grid column
		block_y,        # grid row
		tile_size,      # size of one tile in pixels
		x_off,          # horizontal centering offset
		y_off           # vertical centering offset
	)	

func add_monster(mx, my, type):
	var monster = monster_scene.instantiate()

	var monster_x = mx
	var monster_y = my

	monster.family = type
	
	monster.add_to_group("debug_collision")

	add_child(monster)
	var cell = Vector2i(mx, my)
# 	blocks[cell] = block

	monster.position = GameConfig.grid_to_local(
		monster_x,        # grid column
		monster_y,        # grid row
		tile_size,      # size of one tile in pixels
		x_off,          # horizontal centering offset
		y_off           # vertical centering offset
	)	


# DEBUGGING 
func debug_block(block):
	var shape = block.get_node("CollisionShape2D")
	print("---- BLOCK TREE ----")
	print(block.get_tree_string_pretty())
	print("Block global:", block.global_position)
	print("Shape global:", shape.global_position)
	print("Shape local:", shape.position)
	print("Shape parent:", shape.get_parent())
	print(block.get_class())
	shape.debug_color = Color(randf(), randf(), randf())
	print("Top level:", shape.top_level)
		
