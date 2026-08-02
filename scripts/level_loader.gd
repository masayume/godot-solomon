extends Node2D

@export var block_scene: PackedScene
@export var player_scene: PackedScene
@export var monster_scene: PackedScene
@export var item_scene: PackedScene
@export var fx_scene: PackedScene      # Assign Fx.tscn to Level in the Inspector

var scenes = {
	"fairy": preload("res://scenes/m-Fairy.tscn"),

	"blueflame": preload("res://scenes/m-Blueflame.tscn"),
	"orangeflame": preload("res://scenes/m-Orangeflame.tscn"),
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

signal level_started # used by room_intro.gd

@onready var level_label: Label = $"../UI/LevelInfo"
@onready var intro_room_label: Label = $"../UI/IntroRoomLabel"
# @onready var entity_spawner: EntitySpawner = $EntitySpawner
# @onready var timer_label: RichTextLabel = $"../UI/Timer"

# 1. Update your UI reference
@onready var ui_node = $"../UI" 
@onready var timer_label: RichTextLabel = $"../UI/Timer" # Ensure this Label exists in your UI scene

var current_bonus: int = 0
var bonus_timer: Timer
var room_outro: RoomOutro
var room_active: bool = true

@onready var bg = $"Background"

var tile_size
var x_off: float
var y_off: float
var current_level
var player
var doorx
var doory

# blocks dictionary to check/update; Vector2i  →  Block node
# Delegated property access so external scripts reading level_loader.blocks don't break
var blocks: Dictionary:
	get: return block_manager.blocks
	set(value): block_manager.blocks = value
	
var current_level_data: Dictionary
#2DEL var item_nodes := {} ## NEW: tracks instantiated item nodes; Vector2i -> Item node
#2DEL var monsters := {} 	## monsters dictionary to check/update; Vector2i  →  Block node

# LAZY INIT of entity_spawner to avoid errors like object of type 'null instance'
var _entity_spawner: EntitySpawner
var entity_spawner: EntitySpawner:
	get:
		if not is_instance_valid(_entity_spawner):
			# 1. Try to find the node in the scene tree
			_entity_spawner = get_node_or_null("EntitySpawner") as EntitySpawner
			
			# 2. If it's missing, create it automatically on the fly
			if not _entity_spawner:
				_entity_spawner = EntitySpawner.new()
				_entity_spawner.name = "EntitySpawner"
				_entity_spawner.item_scene = item_scene # pass scene reference
				add_child(_entity_spawner)
				
		return _entity_spawner

# LAZY INIT of block_manager to avoid errors like object of type 'null instance'
var _block_manager: BlockManager
var block_manager: BlockManager:
	get:
		if not is_instance_valid(_block_manager):
			_block_manager = get_node_or_null("BlockManager") as BlockManager
			if not _block_manager:
				_block_manager = BlockManager.new()
				_block_manager.name = "BlockManager"
				_block_manager.block_scene = block_scene
				add_child(_block_manager)
		return _block_manager
		
func _ready():
	# Sets the engine's background clearing color to pure black
	RenderingServer.set_default_clear_color(Color.BLACK)
	
	add_to_group("level_loader")
	center_level()
	current_level = GameConfig.gamedata.sequence.initial_level
	load_level(current_level)

# ------------------------------------------------------------------
#  ENTITY SPAWNER DELEGATION (Facade)
#  Keeps external calls from block.gd, room_intro.gd, player.gd working
# ------------------------------------------------------------------

func add_item(ix: int, iy: int, type: String, showing: bool = false, is_hidden: bool = false) -> Node2D:
	return entity_spawner.add_item(ix, iy, type, showing, is_hidden)

func add_monster(monster_data: Dictionary) -> Node2D:
	return entity_spawner.add_monster(monster_data)

func _spawn_all_monsters(data: Dictionary):
	entity_spawner.spawn_all_monsters(data)

func spawn_fairy():
	entity_spawner.spawn_fairy()

# Directly reference dictionaries from entity_spawner where needed:
var item_nodes: Dictionary:
	get: return entity_spawner.item_nodes

var monsters: Dictionary:
	get: return entity_spawner.monsters


# ------------------------------------------------------------------
#  BLOCK MANAGER DELEGATION (Facade)
# ------------------------------------------------------------------

func add_block(bx: int, by: int, type: String, showing: bool = false) -> Node2D:
	return block_manager.add_block(bx, by, type, showing)

func create_or_destroy_block(pos, dir, crouching, is_player = false):
	block_manager.create_or_destroy_block(pos, dir, crouching, is_player)

func _on_foop_finished(grid_pos, type):
	block_manager.on_foop_finished(grid_pos, type)

func destroy_block_at(cell: Vector2i) -> bool:
	return block_manager.destroy_block_at(cell)

func remove_block_at_pos(world_pos: Vector2):
	block_manager.remove_block_at_pos(world_pos)

func spawn_block_at_world_pos(world_pos: Vector2, type: String):
	block_manager.spawn_block_at_world_pos(world_pos, type)

func replace_block(world_pos: Vector2, new_family: String):
	block_manager.replace_block(world_pos, new_family)

func remove_block_node(block_node: Node):
	block_manager.remove_block_node(block_node)

func replace_block_node(block_node: Node, new_family: String):
	block_manager.replace_block_node(block_node, new_family)
	
	
	
	
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


func spawn_fx(fx_type: String, world_pos: Vector2, grid_pos: Vector2i, should_spawn_block: bool):
	var fx = fx_scene.instantiate()
	add_child(fx)

	# ==========================================
	# 🔧 FORCE VISUAL CENTERING FOR ALL FX
	# ==========================================
	var fx_sprite = fx.get_node_or_null("Sprite2D")
	if fx_sprite:
		# Ensure the sprite draws from its center, not its top-left corner
		fx_sprite.centered = true 
		# Reset any accidental local offsets
		fx_sprite.position = Vector2.ZERO 
		fx_sprite.offset = Vector2.ZERO
	# ==========================================

	fx.global_position = world_pos
	
	# NOTE !
	# fx.gd _on_timer_timeout_ only emits that signal if it's a "one-shot" effect that deletes itself.
	
	if should_spawn_block:
		# Connect the signal so we know when to call add_block
		fx.animation_finished.connect(_on_foop_finished)
	
	fx.setup_fx(fx_type, grid_pos)


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

###DEBUG cell coordinates
#	print("[CHECK] door(", doorx, ",", doory, ") -> grid_to_local=",
#	GameConfig.grid_to_local(doorx, doory, tile_size, x_off, y_off))
	
	# Instantiate the intro helper function
	var intro_manager = RoomIntro.new(self)
#	print("calling play intro")
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
	
	room_active = active
	
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

	# Toggle monsters
	get_tree().call_group("monstergroup", "set_physics_process", active)

	print("Start")
	await get_tree().create_timer(5.0).timeout
	print("Resumed after 5 seconds")


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

# external blocks secret hint system
func _inject_hidden_item_border_hints(level_data: Dictionary, hint_family: String = "stone_marker"):
	if not level_data.has("items") or not level_data.has("blocks"):
		return

	# 1. Auto-detect outer wall boundaries (e.g., x=16, y=13)
	var max_x: int = 0
	var max_y: int = 0
	for block in level_data["blocks"]:
		max_x = max(max_x, block["pos"][0])
		max_y = max(max_y, block["pos"][1])

	# 2. Assign random border target positions for each hidden item
	var hint_targets: Array[Dictionary] = []

	for item in level_data["items"]:
		if item.get("type") == "hidden" and item.has("pos"):
			var h_pos = Vector2i(item["pos"][0], item["pos"][1])
			
			# Pick top (0) or bottom (max_y) for X coordinate hint
			var target_row_for_x = [0, max_y].pick_random()
			
			# Pick left (0) or right (max_x) for Y coordinate hint
			var target_col_for_y = [0, max_x].pick_random()

			hint_targets.append({
				"pos": h_pos,
				"row_for_x": target_row_for_x,
				"col_for_y": target_col_for_y
			})

	# 3. Swap wall blocks matching the chosen random coordinates
	for block in level_data["blocks"]:
		var bx: int = block["pos"][0]
		var by: int = block["pos"][1]

		for target in hint_targets:
			# X-coordinate marker (at either top or bottom row)
			if bx == target["pos"].x and by == target["row_for_x"]:
				block["family"] = hint_family

			# Y-coordinate marker (at either left or right column)
			if bx == target["col_for_y"] and by == target["pos"].y:
				block["family"] = hint_family


func _inject_hidden_item_border_hints2DEL(level_data: Dictionary, hint_family: String = "stonehint"):
	var hidden_positions: Array[Vector2i] = []

	# 1. Collect coordinates of all hidden items
	if level_data.has("items"):
		for item in level_data["items"]:
			if item.get("type") == "hidden" and item.has("pos"):
				hidden_positions.append(Vector2i(item["pos"][0], item["pos"][1]))

	# 2. Swap wall blocks matching top (X) and left (Y) coordinates
	if level_data.has("blocks"):
		for block in level_data["blocks"]:
			var bx: int = block["pos"][0]
			var by: int = block["pos"][1]

			for h_pos in hidden_positions:
				# Mark X coordinate on the top wall [hx, 0]
				if bx == h_pos.x and by == 0:
					block["family"] = hint_family
				
				# Mark Y coordinate on the left wall [0, hy]
				if bx == 0 and by == h_pos.y:
					block["family"] = hint_family


func show_ending_credits():
	print("show_ending_credits")

func clear_current_level():

	block_manager.clear()
	entity_spawner.clear()

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
		if child.name != "Background" and child.name != "BlockManager" and child.name != "EntitySpawner":
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

	_inject_hidden_item_border_hints(data, "stonehint")
	
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

	var items_to_spawn : Array

#	print("[DATA]: ", data)
	
	if data.has("items_configs") and data["items_configs"].size() > 0:
		var config_index : int = randi() % data["items_configs"].size()
		print("[BONUS] picked item config ", config_index)
		items_to_spawn = data["items_configs"][config_index]
		
	else:
		items_to_spawn = data.get("items", [])	
		print("[BONUS] normal items ")

#	if data.has("items"):
	if items_to_spawn:
#		for i in data["items"]:
		for i in items_to_spawn:

			# var is_secret = i.get("type") == "hidden"
			var is_hidden : bool = i.get("type", "") == "hidden"
			
			# Spawn the item. Your add_item function ALREADY correctly 
			# registers this node into the item_nodes dictionary!
			add_item(i["pos"][0], i["pos"][1], i["family"], false, is_hidden)
			
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
