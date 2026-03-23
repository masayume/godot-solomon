extends Node2D

@export var block_scene: PackedScene
@export var player_scene: PackedScene
@export var monster_scene: PackedScene
@export var item_scene: PackedScene
@export var fx_scene: PackedScene      # Assign Fx.tscn to Level in the Inspector

var scenes = {
	"ghost": preload("res://scenes/m-Ghost.tscn"),
	"goblin": preload("res://scenes/m-Goblin.tscn")	
}

@onready var level_label: Label = $"../../UI/LevelInfo"

const Grid = preload("res://scripts/grid.gd")

var tile_size
var x_off: float
var y_off: float
var blocks := {} 	## blocks dictionary to check/update; Vector2i  →  Block node
var monsters := {} 	## monsters dictionary to check/update; Vector2i  →  Block node

func _ready():
	center_level()
	load_level(99)

func center_level():
	# print("THIS NODE:", get_path())
	var screen_size = get_viewport_rect().size
	var level_root = get_parent()

	if level_root == null:
		print("ERROR: level_root not found")
		return

	tile_size = GameConfig.gamedata.screen.TILE_SIZE
	var width = GameConfig.gamedata.screen.LEVEL_WIDTH
	var height = GameConfig.gamedata.screen.LEVEL_HEIGHT

	var level_pixels = Vector2(width * tile_size, height * tile_size)

	level_root.position = (screen_size - level_pixels) / 2 + Vector2(0, 512.0)
	print("LEVEL POSITION:", level_root.position)

###DEBUG
#func _process(delta):
#	print("LEVEL POS:", position)g

		
func spawn_monster(tile_x, tile_y):
	var monster = monster_scene.instantiate()
	monster.position = Vector2(tile_x * tile_size, tile_y * tile_size)
#	level.add_child(monster)
	call_deferred("add_child", monster)


func spawn_item(tile_x, tile_y):
	var item = item_scene.instantiate()
	item.position = Vector2(tile_x * tile_size, tile_y * tile_size)
	call_deferred("add_child", item)


func _on_player_fire(pos, dir, crouching):
	create_or_destroy_block(pos, dir, crouching)

func create_or_destroy_block(pos, dir, crouching):

###DEBUG
#	print("create/destroy block at: " + str(pos) + " " + str(dir))
# 	var destructible = config.get_value("block_" + block.block_type, "destructible", false)

	var cell = Grid.world_to_grid(pos, x_off, y_off, tile_size)
	if crouching:
		cell.y -= 1

	var target = Vector2i(cell.x + dir, cell.y)
			
	### DESTROY BLOCK playing fx "poof"
	if blocks.has(target):
		var block = blocks[target]
		
		if GameConfig.blockdata[block.family]["destructible"]:
			# Play Poof (Destruction)
			spawn_fx("poof", block.global_position, target, false)
			block.queue_free()
			blocks.erase(target)

	### CREATE BLOCK after playing fx "foop"
	else:

		# PLAY FOOP FX
		# Calculate world position for the new block

###TODO poof fx position is OK; foop position is at block_x-1...
		var spawn_pos = GameConfig.grid_to_local(target.x+1, target.y, tile_size, x_off, y_off)
#		var spawn_pos = GameConfig.grid_to_local(target.x, target.y, tile_size, x_off, y_off)
		
		# Play Foop and wait for it to finish before adding the block
		spawn_fx("foop", spawn_pos, target, true)
#		spawn_fx_old("foop", spawn_pos, target)

###TODO "tween" to these effects so they also scale or fade out while the frames are playing


func spawn_fx(fx_type: String, world_pos: Vector2, grid_pos: Vector2i, should_spawn_block: bool):
	var fx = fx_scene.instantiate()
	add_child(fx)
	fx.global_position = world_pos
	
	if should_spawn_block:
		# Connect the signal so we know when to call add_block
		fx.animation_finished.connect(_on_foop_finished)
	
	fx.setup_fx(fx_type, grid_pos)


func spawn_fx_old(fx_type: String, world_pos: Vector2, grid_pos: Vector2i):
	var fx = fx_scene.instantiate()
	add_child(fx)
	fx.global_position = world_pos
	
	# Only connect the 'spawn block' logic if it's the creation effect (foop)
	if fx_type == "foop":
		fx.animation_finished.connect(_on_foop_finished)
		
	fx.setup_fx(fx_type, grid_pos, "earth")

func _on_foop_finished(grid_pos, type):
	# NOW create the actual block 
	add_block(grid_pos.x, grid_pos.y, type)

	
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

	# Spawn monsters
	if data.has("monsters"):
		for m in data["monsters"]:
			# Create a new monster instance from scene		
#			add_monster(m["pos"][0], m["pos"][1], m["family"], m.get("direction", null))
			var instance = scenes[m["family"]].instantiate()
			instance.family = m["family"]
#			print(m["family"], " instanced")

			instance.position = GameConfig.grid_to_local(
				m["pos"][0],
				m["pos"][1],
				tile_size,
				x_off,
				y_off
			)
			add_child(instance)

	# Spawn blocks
	for b in data["blocks"]:
		# Create a new block instance from scene
		add_block(b["pos"][0], b["pos"][1], b["family"])

	# Spawn items
	if data.has("items"):
		for i in data["items"]:
			# Create a new block instance from scene
			add_item(i["pos"][0], i["pos"][1], i["family"])


func add_block(bx, by, type):
	var block = block_scene.instantiate()

	var block_x = bx
	var block_y = by

	block.family = type
	block.name = "BL_" + str(block.family)
		
	block.add_to_group("debug_collision")

	add_child(block)
	var cell = Vector2i(bx, by)
	blocks[cell] = block
		
	block.position = GameConfig.grid_to_local(
		block_x,        # grid column
		block_y,        # grid row
		tile_size,      # size of one tile in pixels
		x_off,          # horizontal centering offset
		y_off           # vertical centering offset
	)	

func add_monster(mx, my, type, dir):
	var monster = monster_scene.instantiate()

	var monster_x = mx
	var monster_y = my

	monster.family = type
	monster.name = "MO_" + str(monster.family)

	monster.add_to_group("debug_collision")

	add_child(monster)

	if dir == "up":
		monster.rotation_degrees = -90
	elif dir == "down":
		monster.rotation_degrees = 90
	elif dir == "left":
#		monster.rotation_degrees = 180		
		monster.scale.x = -1

	monster.position = GameConfig.grid_to_local(
		monster_x,        # grid column
		monster_y,        # grid row
		tile_size,      # size of one tile in pixels
		x_off,          # horizontal centering offset
		y_off           # vertical centering offset
	)	


func add_item(ix, iy, type):
	var item = item_scene.instantiate()

	var item_x = ix
	var item_y = iy

	item.family = type
	item.name = "IT_" + str(item.family)
	
	item.add_to_group("debug_collision")

###TODO: fix duplicate collision_layer_mask/value
	# 1. Physical Blocking Logic
	if GameConfig.itemdata.get("is_interactable", true):
		item.set_collision_layer_value(3, true)  # It is an Interactable
		item.set_collision_mask_value(2, true)   # It blocks the Player
	else:
		item.set_collision_layer_value(3, false) # Player walks through it
		item.set_collision_mask_value(2, false)


	# 2. Interaction Logic (The Sensor)
	var area = item.get_node("Area2D")
	
	# Reset everything first to be safe
	area.collision_layer = 0
	area.collision_mask = 0
	
	# Who am I? (Layer 3: Interactables)
	area.set_collision_layer_value(3, true)      # Sensor is on Interactable layer

	# Who am I looking for? (Layer 2: Player)
	area.set_collision_mask_value(2, true)       # Sensor looks for the Player

	###DEBUG item area layer check (interaction)
#	print("DEBUG: ", item.name, " Area Layer: ", area.collision_layer)
#	print("DEBUG: ", item.name, " Area Mask: ", area.collision_mask)


	# 3. Add the Receiver component
	var receiver = Receiver.new()
	receiver.name = "Receiver"

#	print(GameConfig.itemdata[type])
	receiver.data = GameConfig.itemdata[type]
	item.add_child(receiver)

	# Tell the item to refresh its debug info
	if item.has_method("_update_debug_text"):
		item._update_debug_text()
		
	add_child(item)

	item.position = GameConfig.grid_to_local(
		item_x,        # grid column
		item_y,        # grid row
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
		
