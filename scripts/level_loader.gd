extends Node2D

@export var block_scene: PackedScene
@export var player_scene: PackedScene
@export var monster_scene: PackedScene
@export var item_scene: PackedScene
@export var fx_scene: PackedScene      # Assign Fx.tscn to Level in the Inspector

var scenes = {
	"chimera": preload("res://scenes/m-Chimera.tscn"),
	"demonhead": preload("res://scenes/m-Demonhead.tscn"),
	"dragon": preload("res://scenes/m-Dragon.tscn"),
	"earthmage": preload("res://scenes/m-Earthmage.tscn"),
	"gargoyle": preload("res://scenes/m-Gargoyle.tscn"),
	"ghost": preload("res://scenes/m-Ghost.tscn"),
	"goblin": preload("res://scenes/m-Goblin.tscn"),
	"nuel": preload("res://scenes/m-Nuel.tscn"),
	"pannel": preload("res://scenes/m-Pannel.tscn"),
	"serpent": preload("res://scenes/m-Serpent.tscn"),
	"spark": preload("res://scenes/m-Spark.tscn"),
}

@onready var level_label: Label = $"../../UI/LevelInfo"

const Grid = preload("res://scripts/grid.gd")

var tile_size
var x_off: float
var y_off: float
var blocks := {} 	## blocks dictionary to check/update; Vector2i  →  Block node
var monsters := {} 	## monsters dictionary to check/update; Vector2i  →  Block node
var current_level

func _ready():
	center_level()
	current_level = GameConfig.gamedata.sequence.initial_level
	load_level(current_level)

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
	create_or_destroy_block(pos, dir, crouching, true)

func create_or_destroy_block(pos, dir, crouching, is_player=false):

###DEBUG
#	print("create/destroy block at: " + str(pos) + " " + str(dir))
# 	var destructible = config.get_value("block_" + block.block_type, "destructible", false)
	
	var cell = Grid.world_to_grid(pos, x_off, y_off, tile_size)
	if crouching:
		cell.y -= 1
	var target = Vector2i(cell.x + dir, cell.y)
	
	### DESTROY BLOCK playing fx "poof"
	
	# 1. If there is already a block at the target position
	if blocks.has(target):
		var block = blocks[target]
		
		# Only destroy if the config says it is destructible
		if GameConfig.blockdata[block.family]["destructible"]:
			# Play Poof (Destruction)
			spawn_fx("poof", block.global_position, target, false)
			block.queue_free()
			blocks.erase(target)
		else:
			# It's a stone block (not destructible)
			# Do nothing here so it doesn't fall into the 'else' below
			print("Hit indestructible block: ", block.family)
			return
			
	# CREATE BLOCK after playing fx "foop"
	# 2. ONLY create a block if the target space is confirmed EMPTY
	elif not blocks.has(target) and is_player:
		# PLAY FOOP FX
		# Calculate world position for the new block
###TODO poof fx position is OK; foop position is at block_x-1...
		var spawn_pos = GameConfig.grid_to_local(target.x+1, target.y, tile_size, x_off, y_off)
#		var spawn_pos = GameConfig.grid_to_local(target.x, target.y, tile_size, x_off, y_off)
		
		# Play Foop and wait for it to finish before adding the block
		spawn_fx("foop", spawn_pos, target, true)

###TODO "tween" to these effects so they also scale or fade out while the frames are playing


func spawn_fx(fx_type: String, world_pos: Vector2, grid_pos: Vector2i, should_spawn_block: bool):
	var fx = fx_scene.instantiate()
	add_child(fx)
	fx.global_position = world_pos
	
	if should_spawn_block:
		# Connect the signal so we know when to call add_block
		fx.animation_finished.connect(_on_foop_finished)
	
	fx.setup_fx(fx_type, grid_pos)


func _on_foop_finished(grid_pos, type):
	# NOW create the actual block 
	add_block(grid_pos.x, grid_pos.y, type)

	
func spawn_player(px, py, xoff, yoff):

	var player = player_scene.instantiate()
	player.add_to_group("playergroup")

	# add to the SAME node that holds the blocks
	add_child(player)

	# now the transform chain is correct
	player.spawn_at(px, py, xoff, yoff)
	player.fire_pressed.connect(_on_player_fire)
	

func load_level(id: int):
	var path = "res://levels/level_%02d.json" % id
	var file = FileAccess.open(path, FileAccess.READ)
	print("path: ", path)
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
			var instance = scenes[m["family"]].instantiate()
			instance.family = m["family"]

			if instance.family == "spark":
#				var start_surface = GameConfig.monsterdata.spark.get("attached", "bottom")
				var start_surface = m["attached"]
				instance.current_surface = start_surface 
				# Adjust position to be flush with the block edge
				match start_surface:
					"bottom": instance.position.y += (tile_size / 2) # Push down to floor
					"top":    instance.position.y -= (tile_size / 2) # Push up to ceiling
					"left":   instance.position.x -= (tile_size / 2) # Push left to wall
					"right":  instance.position.x += (tile_size / 2) # Push right to wall

			#SIGNAL-ghost-3 Connect the signal from Ghost			
			#LAMBDA for wall impact to pass 'false' for the 'crouching' parameter
			# Only connect if the specific monster has the signal defined
			if instance.has_signal("wall_impact"):
				instance.wall_impact.connect(
					func(pos, dir): create_or_destroy_block(pos, dir, false)
				)
			
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
	monster.add_to_group("monstergroup")

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
	item.add_to_group("itemgroup")

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
	

func start_level_transition():
	
# 1. Get current level info from the CFG
	var section = "level_" + str(current_level)
	current_level += 1
	print("section: ", section)
	# 2. Find the next ID
	var next_id = GameConfig.gamedata[section].next_level
	
	print("next_id:", next_id)
	
	if next_id == -1:
		print("Victory! No more levels.")
		show_ending_credits()
		return

	# 3. Get metadata for the UI
	var next_name = "level_" + str(next_id)
	print("next_name: ", next_name )
	
	# 4. Show the "Level Card" for N seconds
	level_label.text = "NEXT: " + next_name 
	await get_tree().create_timer(3.0).timeout	
	
	# 1. Calculate Bonus Score
	var bonus = calculate_bonus()
	GameConfig.score += bonus # Global score tracking
	
	# 2. Get next level data from game.cfg
#	var current_level_id = GameConfig.gamedata.current_level
#	var next_level_id = GameConfig.gamedata.levels[current_level_id].next_level
#	var next_level_name = GameConfig.gamedata.levels[next_level_id].name
	
	# 3. Show UI and Wait
	show_level_card(next_id, next_name)
	
	# 4. Use a Timer or await to pause for 'n' seconds
	await get_tree().create_timer(3.0).timeout 
	
	#GameConfig.gamedata.sequence.initial_level
	
	# 5. Clear and Load
	clear_current_level()
	load_level(next_id)

func load_new_level(id: int):
	# Clear current dictionaries [cite: 3, 4, 5]
	blocks.clear() 
	monsters.clear()
	
	# Delete all physical nodes
	for child in get_children():
		child.queue_free()
		
	# Update global state
	GameConfig.current_level_id = id
	
	# Call your existing JSON loader [cite: 3]
	load_level(id)

	
func calculate_bonus():
	# calculate bonus score
	print("calculate_bonus")
	return 100

func show_level_card(level_id, level_name):
	print("show_level_card")
	

func show_ending_credits():
	print("show_ending_credits")

func clear_current_level():
	# Clear the dictionaries [cite: 5, 6]
	for block in blocks.values():
		block.queue_free()
	blocks.clear()
	# Reset offsets 
	blocks = {}
	
	for child in get_children(): 
		child.queue_free()



# DEBUGGING 

# Inside level_loader.gd

func _input(event):
	# Trigger transition when 'N' is pressed
	if event is InputEventKey and event.pressed:
		if event.keycode == KEY_N:
			print("DEBUG: Manual level skip triggered.")
			start_level_transition()

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
		
