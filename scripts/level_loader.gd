extends Node2D

@export var block_scene: PackedScene
@export var player_scene: PackedScene
@export var monster_scene: PackedScene
@export var item_scene: PackedScene
@export var fx_scene: PackedScene      # Assign Fx.tscn to Level in the Inspector

var scenes = {
	"fairy": preload("res://scenes/m-Fairy.tscn"),

	"blueflame": preload("res://scenes/m-Blueflame.tscn"),
	"chimera": preload("res://scenes/m-Chimera.tscn"),
	"demonhead": preload("res://scenes/m-Demonhead.tscn"),
	"dragon": preload("res://scenes/m-Dragon.tscn"),
	"earthmage": preload("res://scenes/m-Earthmage.tscn"),
	"gargoyle": preload("res://scenes/m-Gargoyle.tscn"),
	"ghost": preload("res://scenes/m-Ghost.tscn"),
	"goblin": preload("res://scenes/m-Goblin.tscn"),
	"nuel": preload("res://scenes/m-Nuel.tscn"),
	"pannel": preload("res://scenes/m-Pannel.tscn"),
	"salamander": preload("res://scenes/m-Salamander.tscn"),
	"serpent": preload("res://scenes/m-Serpent.tscn"),
	"spark": preload("res://scenes/m-Spark.tscn"),
}

signal level_started

@onready var level_label: Label = $"../UI/LevelInfo"
@onready var intro_room_label: Label = $"../UI/IntroRoomLabel"
# @onready var timer_label: RichTextLabel = $"../UI/Timer"

# 1. Update your UI reference
@onready var ui_node = $"../UI" 
@onready var timer_label: RichTextLabel = $"../UI/Timer" # Ensure this Label exists in your UI scene

var current_bonus: int = 0
var bonus_timer: Timer
var room_outro: RoomOutro

@onready var bg = $"Background"

var tile_size
var x_off: float
var y_off: float
var blocks := {} 	## blocks dictionary to check/update; Vector2i  →  Block node
var monsters := {} 	## monsters dictionary to check/update; Vector2i  →  Block node
var current_level
var player
var doorx
var doory

var current_level_data: Dictionary
var item_nodes := {} ## NEW: tracks instantiated item nodes; Vector2i -> Item node

func _ready():
	# Sets the engine's background clearing color to pure black
	RenderingServer.set_default_clear_color(Color.BLACK)
	
	add_to_group("level_loader")
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


#func spawn_item(tile_x, tile_y):
#	var item = item_scene.instantiate()
#	item.position = Vector2(tile_x * tile_size, tile_y * tile_size)
#	call_deferred("add_child", item)


func _on_player_spell(pos, dir, crouching):
	create_or_destroy_block(pos, dir, crouching, true)

func _on_player_fireball(_pos, _dir, _crouching):
	return
	
func create_or_destroy_block(pos, dir, crouching, is_player=false):

#	print("[CAST] pos=", pos, " dir=", dir, " crouching=", crouching)
	var half_tile = tile_size / 2.0
		
	# 1. Find which cell the player is in
#	var cell = GameConfig.world_to_grid(pos, x_off, y_off, tile_size)

	# Offset pos upward by half a tile so we get the cell the player's body
	# occupies, not the floor cell their feet are touching
#	var body_pos = Vector2(pos.x, pos.y - half_tile)
	
	# Use round() not floor() — snaps to nearest cell symmetrically.
	# floor() is biased: it shifts left for right-casting and right for left-casting.
#	var cell_x = int(round((pos.x - x_off - half_tile) / tile_size)) + 1
#	var cell_y = int(round(-(pos.y + y_off + half_tile) / tile_size)) + 1
	var cell_x = int(round((pos.x - x_off - half_tile) / tile_size)) + 1
	var cell_y = int(-floor((pos.y + y_off + half_tile) / tile_size)) + 1  # floor for Y

	var cell = Vector2i(cell_x, cell_y)

	
#	print("[CAST] cell=", cell, " target=", Vector2i(cell.x + dir, cell.y), " blocks.has=", blocks.has(Vector2i(cell.x + dir, cell.y)))


	# 2. Snap: re-derive the exact center of that cell in world space.
	#    This eliminates all sub-pixel drift and jump-height sensitivity.
#	var snapped = GameConfig.grid_to_local(cell.x, cell.y, tile_size, x_off, y_off)

	# 3. Re-convert from the snapped center — now guaranteed to be exact
#	cell = GameConfig.world_to_grid(snapped, x_off, y_off, tile_size)

	if crouching:
		cell.y -= 1

	var target = Vector2i(cell.x + dir, cell.y)

###DEBUG_2l
#	print("[CAST] pos=", pos, " cell=", cell, " target=", target, " has=", blocks.has(target))
#	print("[CAST] pos=", pos, " x_off=", x_off, " y_off=", y_off, " tile_size=", tile_size, " cell=", cell, " target=", target)
	
	### DESTROY BLOCK playing fx "poof"
	
	# 1. If there is already a block at the target position
	if blocks.has(target):
		var block = blocks[target]
		
		# Only destroy if the config says it is destructible
		if GameConfig.blockdata[block.family]["destructible"]:

			# Play Poof (Destruction)
			spawn_fx("poof", block.global_position, target, false)

			if GameConfig.blockdata["earth"].has("sound"):
				var sfx = load(GameConfig.blockdata["earth"].get("sound"))
				if sfx:
					player.audio_player.stream = sfx
					player.audio_player.play() # Plays once when the state starts

			# Force the block to instantly disappear before queue_free 
			# removes it at the end of the frame
			block.hide()
			block.queue_free()
			blocks.erase(target)

			# ---------------------------------------------------------
			# Check if destroying this block revealed a hidden item
			# ---------------------------------------------------------
			if item_nodes.has(target):
				var item_node = item_nodes[target]
				
				# Ensure the item hasn't been collected and freed already
				if is_instance_valid(item_node):
					# Check if this node is flagged as a hidden item
					if item_node.get_meta("is_hidden_item", false):

						# 2. NEW: Brute force the Godot renderer
						item_node.show() # Safer than visible = true
						item_node.modulate.a = 1.0 # Force full opacity
						item_node.z_index = 50 # Force it to draw over the background and grid
						
						# Explicitly force the child sprite to wake up
						var sprite = item_node.get_node_or_null("Sprite2D")
						if sprite:
							sprite.show()
							
						item_node.set_meta("is_hidden_item", false) # No longer hidden
						
						# 3. Add a debug print just to prove it fired correctly
						print("Item Revealed: ", item_node.name, " at ", item_node.global_position)
						
						# --- Re-enable the player collision mask SAFELY with a tiny delay ---
						var area = item_node.get_node_or_null("Area2D")
						if area:
							get_tree().create_timer(0.15).timeout.connect(func():
								if is_instance_valid(area):
									area.set_collision_layer_value(3, true)
									area.set_collision_mask_value(2, true)
							)
							
				# The item was already collected. Clean up the dead reference!
				else:
					item_nodes.erase(target)					
			# ---------------------------------------------------------

		else:
			# It's a stone block (not destructible)
			# Do nothing here so it doesn't fall into the 'else' below
			print("Hit indestructible block: ", block.family)
			if GameConfig.blockdata[block.family].has("sound"):
				var sfx = load(GameConfig.blockdata[block.family].get("sound"))
				if sfx:
					player.audio_player.stream = sfx
					player.audio_player.play() # Plays once when the state starts

			return
			
	# CREATE BLOCK after playing fx "foop"
	# 2. ONLY create a block if the target space is confirmed EMPTY
	elif not blocks.has(target) and is_player:

		# PLAY FOOP FX; Calculate world position for the new block

		var spawn_pos = GameConfig.grid_to_local(target.x, target.y, tile_size, x_off, y_off)
		
		# Play Foop and wait for it to finish before adding the block
		spawn_fx("foop", spawn_pos, target, true)


###TODO "tween" to these effects so they also scale or fade out while the frames are playing


func spawn_fx(fx_type: String, world_pos: Vector2, grid_pos: Vector2i, should_spawn_block: bool):
	var fx = fx_scene.instantiate()
	add_child(fx)
	fx.global_position = world_pos
	
	# NOTE !
	# fx.gd _on_timer_timeout_ only emits that signal if it's a "one-shot" effect that deletes itself.
	
	if should_spawn_block:
		# Connect the signal so we know when to call add_block
		fx.animation_finished.connect(_on_foop_finished)
	
	fx.setup_fx(fx_type, grid_pos)


func _on_foop_finished(grid_pos, type):
	# NOW create the actual block 
	# add_block(grid_pos.x, grid_pos.y, type)
	add_block(grid_pos.x, grid_pos.y, type, true)


func load_level(id: int):
	var path = "res://levels/level_%02d.json" % id
	var file = FileAccess.open(path, FileAccess.READ)
	print("path: ", path)
	var data = JSON.parse_string(file.get_as_text())
	
	timer_label.text = ""
	current_level_data = data
	
	tile_size = data["tile_size"]
	var width = data["block_width"]
	var height = data["block_height"]
#	var player_start = data["player_start"]

	var screen_size = get_viewport_rect().size

	var level_pixel_size = Vector2(
		width * tile_size,
		height * tile_size
	)
	
	var LevelRoot = get_parent()
	LevelRoot.position.x = (screen_size.x - level_pixel_size.x) / 2
	LevelRoot.position.y = -tile_size -(screen_size.y - level_pixel_size.y) / 2
	
	# show level info: level_loader reads it → exposes it → UI displays it.
	# Hide UI or show Level Card
#	level_label.text = "ROOM %d - %s" % [data["id"], data["name"]]
#	level_label.visible = true 

	x_off = (-screen_size[0] / 2) + ((width / 2) * tile_size) / 2
	y_off = -((height / 2) * tile_size) 

	if bg and bg.has_method("refresh_background"):
		bg.refresh_background()
		
	# 1. Background stays visible, but we delay gameplay
	# Wrap your spawning in an intro sequence
	# 2. Spawn the level content but keep it invisible
	_spawn_level_content_hidden(data)

	# Instantiate the intro helper function
	var intro_manager = RoomIntro.new(self)
	print("calling play intro")
	intro_manager.play_intro(data)
	
	# 1. Initialize value from game.cfg
	current_bonus = GameConfig.gamedata.game.room_bonus

#	print("[GRID ORIGIN] LevelRoot.pos=", get_parent().position, 
#	  " x_off=", x_off, " y_off=", y_off, 
#	  " ts=", tile_size,
#	  " cell(1,1)=", GameConfig.grid_to_local(1, 1, tile_size, x_off, y_off))

#	for cell in blocks:
#		print("[BLOCK] ", cell, " = ", blocks[cell].family)


func toggle_monsters(active: bool):
		get_tree().call_group("monstergroup", "set_physics_process", active)

func toggle_room_activity(active: bool):
	# Toggle monsters
	get_tree().call_group("monstergroup", "set_physics_process", active)
	
	# Visual darkening or revealing of elements 
	for item in get_tree().get_nodes_in_group("itemgroup"):
		# If the room is waking up, ONLY reveal items that aren't marked as secret hidden items
		if active:
			if not item.get_meta("is_hidden_item", false):
				item.visible = active
		else:
			item.visible = false

	for monster in get_tree().get_nodes_in_group("monstergroup"):
		monster.visible = active
		
	for block in get_tree().get_nodes_in_group("blockgroup"):
		block.visible = active

func remove_block_at_pos(world_pos: Vector2):
	# Find the block by node reference, not by coordinate conversion
	for cell in blocks:
		if blocks[cell] == world_pos:  # world_pos is actually the block node here
			blocks[cell].queue_free()
			blocks.erase(cell)
			return

func remove_block_at_posOLD(world_pos: Vector2):
	# Convert the world position to grid coordinates 
	var grid_pos = GameConfig.world_to_grid(world_pos, x_off, y_off, tile_size)
	var cell = Vector2i(grid_pos.x, grid_pos.y)
	
	if blocks.has(cell):
		blocks[cell].queue_free()
		blocks.erase(cell)

func spawn_block_at_world_pos(world_pos: Vector2, type: String):
	# Convert world position to grid and use the existing add_block logic 
	var grid_pos = GameConfig.world_to_grid(world_pos, x_off, y_off, tile_size)
	add_block(grid_pos.x, grid_pos.y, type, true)

func replace_block(world_pos: Vector2, new_family: String):
	# Remove the old one and spawn the new one at the same spot
	remove_block_at_pos(world_pos)
	spawn_block_at_world_pos(world_pos, new_family)

func remove_block_node(block_node: Node) -> void:
	for cell in blocks:
		if blocks[cell] == block_node:
			block_node.queue_free()
			blocks.erase(cell)
			return

func replace_block_node(block_node: Node, new_family: String) -> void:
	for cell in blocks:
		if blocks[cell] == block_node:
			block_node.queue_free()
			blocks.erase(cell)
			add_block(cell.x, cell.y, new_family, true)
			return
			

func add_block(bx, by, type, showing = false):
	var block = block_scene.instantiate()

	var block_x = bx
	var block_y = by

	block.family = type
	block.name = "BL_" + str(block.family)
		
	block.add_to_group("debug_collision")
	block.add_to_group("blockgroup")

	block.visible = showing
	
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


func add_item(ix, iy, type, showing = false, is_hidden = false):
	var item = item_scene.instantiate()

	var item_x = ix
	var item_y = iy

	item.family = type
	item.name = "IT_" + str(item.family)
	
	# Create a custom metadata property on the item node dynamically
	item.set_meta("is_hidden_item", is_hidden)
	
#	item.add_to_group("debug_collision")
	item.add_to_group("itemgroup")

	if (item.family == "door"):
		doorx = ix
		doory = iy
		item.add_to_group("doorgroup")

	if (item.family == "key"):
		item.add_to_group("keygroup")

	# 2. Interaction Logic (The Sensor)
	var area = item.get_node("Area2D")
	
	# Reset everything first to be safe
	area.collision_layer = 0
	area.collision_mask = 0
	
	# Who am I? (Layer 3: Interactables)
	area.set_collision_layer_value(3, true)      # Sensor is on Interactable layer

	# Who am I looking for? (Layer 2: Player)
	# area.set_collision_mask_value(2, true)       # Sensor looks for the Player

	# Disable both Layer AND Mask IF HIDDEN
	if is_hidden:
		area.set_collision_layer_value(3, false) # HIDDEN from the player
		area.set_collision_mask_value(2, false)  # BLIND to the player
	else:
		area.set_collision_layer_value(3, true)  # Sensor is on Interactable layer
		area.set_collision_mask_value(2, true)   # Sensor looks for the Player

	###DEBUG item area layer check (interaction)
#	print("DEBUG: ", item.name, " Area Layer: ", area.collision_layer)
#	print("DEBUG: ", item.name, " Area Mask: ", area.collision_mask)


	# 3. Add the Receiver component
	var receiver = Receiver.new()
	receiver.name = "Receiver"
	receiver.data = GameConfig.itemdata[type]
	item.add_child(receiver)

	# Tell the item to refresh its debug info
#	if item.has_method("_update_debug_text"):
#		item._update_debug_text()
	
	item.visible = showing	
	add_child(item)

	# NEW: Store the item node in our dictionary by its grid position
	var cell = Vector2i(ix, iy)
	item_nodes[cell] = item
	
	item.position = GameConfig.grid_to_local(
		item_x,        # grid column
		item_y,        # grid row
		tile_size,      # size of one tile in pixels
		x_off,          # horizontal centering offset
		y_off           # vertical centering offset
	)	

func spawn_player(px, py, xoff, yoff):

	player = player_scene.instantiate()
	player.add_to_group("playergroup")

	# add to the SAME node that holds the blocks
	add_child(player)

	if GameConfig.gamedata.game.collider_debug:
		_debug_node_shapes(player, Color(0, 1, 0, 0.7)) # Green
		
	# now the transform chain is correct
	player.visible=false
	player.spawn_at(px, py, xoff, yoff)
	player.spell_pressed.connect(_on_player_spell)
	player.fireball_pressed.connect(_on_player_fireball)
	print("player spawned")


func start_level_transition():
	
# 1. Get current level info from the CFG
	var section = "level_" + str(current_level)

	current_level += 1
	print("section: ", section)

	# 2. Find the next ID
#	var next_id = GameConfig.gamedata[section].next_level

	# 2. Extract the 'next_level' ID from the config instead of using += 1
	# This ensures level 99 correctly points to level 1
	var next_id = -1
	if GameConfig.gamedata.has(section):
		next_id = GameConfig.gamedata[section].get("next_level", -1)
	
	print("Transitioning from: ", section, " to next_id: ", next_id)

	# 3. Handle the end of the game	
	if next_id == -1:
		print("Victory! No more levels.")
		show_ending_credits()
		return
	
	# 4. Update the current level tracker
	current_level = next_id
	
	# 5. Show the Level Card UI
	var next_name = "level_" + str(next_id)
	level_label.text = "NEXT: " + next_name 

	# Instantiate the intro helper to play the outro
	var hud = get_tree().get_first_node_in_group("hud_lives")
	if hud:
		hud.set_player_active(false)

	var intro_manager = RoomOutro.new(self)
#	print("calling play intro")
	intro_manager._animate_stars_explode(player)

	# disable the current player's logic so they don't move or collide with things 
	# while the stars are exploding, and then they are removed before the next level loads.
	player.visible = false
	player.set_physics_process(false)
	player.set_process_input(false)
	

	# 3. Show UI and Wait
#	show_level_card(next_id, next_name)
	
	# 4. Use a Timer or await to pause for 'n' seconds
	await get_tree().create_timer(3.0).timeout 
	
	#GameConfig.gamedata.sequence.initial_level
	
	# GameConfig.score += current_bonus # Global score tracking
	# 1. Decrease by 10 points
	var bonus_multiplier = 1

	if player.has_flag("time2x"):
		bonus_multiplier = 2
	elif player.has_flag("time5x"):
		bonus_multiplier =  5	
	
	var tween = player._update_score_with_effect(current_bonus * bonus_multiplier)
	
	# blank in bonus value
	
	if tween:
		await tween.finished
		
	# 5. Clear and Load
	clear_current_level()

	# 1. Calculate Bonus Score, Show "your rest bonus" (current_bonus)
	await show_bonus_card(current_bonus)
	
	load_level(next_id)


func show_bonus_card(bonus):
	intro_room_label.text = "Your rest bonus %d" % bonus
	intro_room_label.visible = true
		
	# 2. Spawn everything at 50% opacity
#	_spawn_dimmed_content(data)
	
	await self.get_tree().create_timer(2.0).timeout
	intro_room_label.visible = false

	print("your rest bonus: ", bonus)
	
func show_ending_credits():
	print("show_ending_credits")

func clear_current_level():
	# Clear the dictionaries [cite: 5, 6]
	for block in blocks.values():
		block.queue_free()
	blocks.clear()
	# Reset offsets 
	blocks = {}

	monsters.clear()
	monsters = {}

	item_nodes.clear()
	item_nodes = {}

	
	for child in get_children(): 
		if child.name != "Background":
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
		
	

func _spawn_level_content_hidden(data):

	if bg:
#		print("black background found via search")
		bg.modulate = Color(0, 0, 0, 1)
	else:
		print("Background NOT found. Check if the node name is exactly 'Background'")
			
	var player_start = data["player_start"]

	# 1. Clear previous level data if any 
	blocks.clear()
	monsters.clear()

	###############################
	#  2. Spawn Blocks (Hidden)   #
	###############################
	for b in data["blocks"]:
		# Create a new block instance from scene
		add_block(b["pos"][0], b["pos"][1], b["family"], false)

	#################################################
	# 3. Spawn Monsters (Hidden + Physics Disabled) #
	#################################################
	if data.has("monsters"):
		_spawn_all_monsters(data) # Refactor your m loop into this
	
	#################################
	# 	4. Spawn Items (Hidden)		#
	#################################
	item_nodes.clear() # Reset on level load
	if data.has("items"):
		for i in data["items"]:

			var is_secret = i.get("type") == "hidden"
			
			# Spawn the item. Your add_item function ALREADY correctly 
			# registers this node into the item_nodes dictionary!
			add_item(i["pos"][0], i["pos"][1], i["family"], false, is_secret)
			
	# 5. Spawn Player (Hidden + Input Disabled)
	spawn_player(
		player_start[0],   # grid X
		player_start[1],   # grid Y
		x_off,       	   # same centering offset used for blocks
		y_off
	)
#	print("player_start: [" + str(player_start[0]) + ","  + str(player_start[1]) + "] x_off:"  + str(x_off) + " y_off:"  + str(y_off))

	player = get_tree().get_first_node_in_group("playergroup")
	player.visible = false
	player.set_process_input(false)

func spawn_fairy():
	var instance = scenes["fairy"].instantiate()	
	instance.family = "fairy"

	instance.name = "MO_fairy"

	instance.add_to_group("debug_collision")
	instance.add_to_group("monstergroup")

	# 2. Interaction Logic (The Sensor)
	var area = Area2D.new()
	area.name = "HitBox"

	# ---  Give the HitBox an actual collision shape ---
	var collision_shape = CollisionShape2D.new()
	var box_shape = RectangleShape2D.new()

	# Set the size of the hitbox. If your tiles are 64x64, 
	# a 32x32 bounding box matches a standard collectible item size.
	box_shape.size = Vector2(32, 32) 
	collision_shape.shape = box_shape
	area.add_child(collision_shape)
	# -----------------------------------------------------
		
	# Reset everything first to be safe
	instance.collision_mask = 0
	area.collision_layer = 0
	area.collision_mask = 3

	area.set_deferred("monitoring", true)
	area.set_deferred("monitorable", true) # can be seen by Player CollectionZone
	
	# Who am I? (Layer 3: Interactables)
	area.set_collision_layer_value(4, true)      # Sensor is on Interactable layer

	# Who am I looking for? (Layer 2: Player)
	area.set_collision_mask_value(2, true)       # Sensor looks for the Player

			# CONSOLIDATION: Force Layer 4 for Monsters
	instance.collision_layer = 4
	instance.collision_mask = 3 # Can see Walls (1) and Player (2)

	# 3. Add the Receiver component
	if not instance.has_node("Receiver"):
		var receiver = Receiver.new()
		receiver.name = "Receiver"
		print("for ", instance.family, " added receiver for ",  GameConfig.monsterdata[instance.family] )
		receiver.data = GameConfig.monsterdata[instance.family]
		instance.add_child(receiver)

	# IMPORTANT: Ensure the HitBox (Area2D) exists and is on Layer 4
	var hitbox = instance.get_node_or_null("HitBox")
	if hitbox:
		hitbox.collision_layer = 4
		hitbox.collision_mask = 0 # It just exists to be 'seen' by the player

	print("fairy door coords: ", doorx, ", ", doory)

	instance.position = GameConfig.grid_to_local(
		doorx,
		doory,
		tile_size,
		x_off,
		y_off
	)

	#	add_child(instance)

	# Safely defer adding the entire fairy to the level tree 
	# until the physics engine finishes flushing queries
	call_deferred("add_child", instance)
	instance.add_child(area)
	
func add_monster(monster_data): # i.e. monster_data: { "pos": [12.0, 5.0], "family": "blueflame" }

	# Create a new monster instance from scene		
	var instance = scenes[monster_data["family"]].instantiate()
	instance.family = monster_data["family"]

	if instance.family == "spark":
		var start_surface = monster_data["attached"]
		print("spark attached to ", start_surface) 
		instance.current_surface = start_surface 
		# Adjust position to be flush with the block edge
		var spawn_pos = GameConfig.grid_to_local(monster_data["pos"][0], monster_data["pos"][1], tile_size, x_off, y_off)

		match start_surface:
			"bottom": spawn_pos.y += (tile_size / 2) - 1 
			"top":    spawn_pos.y -= (tile_size / 2) - 1
			"left":   spawn_pos.x -= (tile_size / 2) - 1
			"right":  spawn_pos.x += (tile_size / 2) - 1

		instance.position = spawn_pos

	#SIGNAL-ghost-3 Connect the signal from Ghost			
	#LAMBDA for wall impact to pass 'false' for the 'crouching' parameter
	# Only connect if the specific monster has the signal defined
	if instance.has_signal("wall_impact"):
		instance.wall_impact.connect(
			func(pos, dir): create_or_destroy_block(pos, dir, false)
		)
				
	if monster_data.has("shoot_direction"):
		var dir = monster_data["shoot_direction"]
		instance.set_meta("shoot_direction", dir)
		if dir == "up":
			instance.rotation_degrees = -90
			print(instance.family, " UP")
		elif dir == "down":
			instance.rotation_degrees = 90
			print(instance.family, " DOWN")
		elif dir == "left":
	#		monster.rotation_degrees = 180		
			instance.scale.x = -1
			print(instance.family, " LEFT")

	instance.name = "MO_" + str(instance.family)

	instance.add_to_group("debug_collision")
	instance.add_to_group("monstergroup")

	if instance.family == "ghost" or instance.family == "spark" or instance.family == "dragon" :
		debug_monster(instance)

	# 2. Interaction Logic (The Sensor)
	var area = Area2D.new()
	area.name = "HitBox"

	# Reset everything first to be safe
	instance.collision_mask = 0
	area.collision_layer = 0
	area.collision_mask = 3

	area.set_deferred("monitoring", true)
	area.set_deferred("monitorable", true) # can be seen by Player CollectionZone

	# Who am I? (Layer 3: Interactables)
	area.set_collision_layer_value(4, true)      # Sensor is on Interactable layer

	# Who am I looking for? (Layer 2: Player)
	area.set_collision_mask_value(2, true)       # Sensor looks for the Player

	# CONSOLIDATION: Force Layer 4 for Monsters
	instance.collision_layer = 4
	instance.collision_mask = 3 # Can see Walls (1) and Player (2)

	# 3. Add the Receiver component
	if not instance.has_node("Receiver"):
		var receiver = Receiver.new()
		receiver.name = "Receiver"
		print("for ", instance.family, " added receiver for ",  GameConfig.monsterdata[instance.family] )
		receiver.data = GameConfig.monsterdata[instance.family]
		instance.add_child(receiver)

	# IMPORTANT: Ensure the HitBox (Area2D) exists and is on Layer 4
	var hitbox = instance.get_node_or_null("HitBox")
	if hitbox:
		hitbox.collision_layer = 4
		hitbox.collision_mask = 0 # It just exists to be 'seen' by the player
		
	# 2. Fix the collision mask at runtime just to be sure

	add_child(instance)
	instance.add_child(area)
						
	if instance.family != "spark":
		instance.position = GameConfig.grid_to_local(
			monster_data["pos"][0],
			monster_data["pos"][1],
			tile_size,
			x_off,
			y_off
		)

	if GameConfig.gamedata.game.collider_debug:
		_debug_node_shapes(instance, Color(1, 0, 0, 0.7)) # Red
				
	return instance

func _spawn_all_monsters(data):
	if data.has("monsters"):
		for m in data["monsters"]:

			var instance = add_monster(m)

			instance.visible = false
			instance.set_physics_process(false) 


func start_level_timer():
	
	print ("*** timer start !", current_bonus)
	
	# 2. Setup the internal timer node for 10 updates per second
	if not bonus_timer:
		bonus_timer = Timer.new()
		bonus_timer.wait_time = 0.1 # 10 times per second
		bonus_timer.timeout.connect(_on_bonus_tick)

		ui_node.add_child(bonus_timer)
	
	bonus_timer.start()
	_update_timer_display()

func _on_bonus_tick():

	# 1. Decrease by 10 points
	var decrease_amount = 10

	if player.has_flag("time2x"):
		decrease_amount = 10 * 2
	elif player.has_flag("time5x"):
		decrease_amount = 10 * 5

	current_bonus -= decrease_amount
	
	# 2. Check for "Hurry Up" threshold (2000)
	var hurry_threshold = GameConfig.gamedata.game.get("hurry_up", 2000)
	if current_bonus <= hurry_threshold:
		timer_label.modulate = Color.RED
	else:
		timer_label.modulate = Color.WHITE

	# 3. Check for Time Over
	if current_bonus <= 0:
		current_bonus = 0
		bonus_timer.stop()
		room_outro.time_over_outro()
	
	_update_timer_display()

func _update_timer_display():
	# Keep the timer always at the same width for arcade feel
	timer_label.text = str(current_bonus).lpad(5, " ")

func stop_level_timer():
	if bonus_timer:
		bonus_timer.stop()

	

# 3. Add this helper function to the bottom of level_loader.gd
func _force_debug_shapes(node: Node, default_color: Color):
	var shapes = node.find_children("*", "CollisionShape2D", true)
	for shape in shapes:
		shape.z_index = 300
		shape.visible = true 
		if shape.get_parent() is Area2D:
			shape.modulate = Color(1, 1, 0, 0.8) # Yellow for Hitboxes
		else:
			shape.modulate = default_color

# function to debug EVERYTHING
func _debug_node_shapes(node: Node, color: Color):
	var shapes = node.find_children("*", "CollisionShape2D", true)
	for shape in shapes:
		shape.z_index = 500
		shape.visible = true
		# If it's a HitBox/Area2D, make it Yellow. If Physics, use the passed color.
		if shape.get_parent() is Area2D:
			shape.modulate = Color(1, 1, 0, 0.7) # Yellow Hitbox
		else:
			shape.modulate = color
		print("Debug: Showing shape for ", node.name, " in ", shape.get_parent().name)


func debug_monster(monster):
	print("--- DEBUG SPARK ---")
	print("Position: ", monster.position)
	print("Scale: ", monster.scale)
	print("Visible: ", monster.visible)
	var shape = monster.get_node_or_null("CollisionShape2D")
	if shape:
		print("Shape Found: ", shape.shape)
		shape.debug_color = Color(1, 0, 0, 0.5) # Force it to Red
