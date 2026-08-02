extends Node2D
class_name BlockManager

@export var block_scene: PackedScene

var blocks := {}  ## Vector2i -> Block node

@onready var loader = get_parent()

func clear():
	for block in blocks.values():
		if is_instance_valid(block):
			block.queue_free()
	blocks.clear()

func add_block(bx: int, by: int, type: String, showing: bool = false) -> Node2D:
	var block = block_scene.instantiate()
	block.family = type
	block.name = "BL_" + str(block.family)
		
	block.add_to_group("debug_collision")
	block.add_to_group("blockgroup")
	block.visible = showing
	
	loader.add_child(block)
	var cell = Vector2i(bx, by)
	blocks[cell] = block
	block.set_meta("grid_pos", cell)
		
	block.position = GameConfig.grid_to_local(
		bx, by, loader.tile_size, loader.x_off, loader.y_off
	)
	return block

func create_or_destroy_block(pos: Vector2, dir: int, crouching: bool, is_player: bool = false):
	var half_tile = loader.tile_size / 2.0
	var cell_x = int(round((pos.x - loader.x_off - half_tile) / loader.tile_size)) + 1
	var cell_y = int(-floor((pos.y + loader.y_off + half_tile) / loader.tile_size)) + 1
	var cell = Vector2i(cell_x, cell_y)

	if crouching:
		cell.y -= 1

	var target = Vector2i(cell.x + dir, cell.y)

	# 1. If there is already a block at the target position
	if blocks.has(target):
		var block = blocks[target]
		
		if GameConfig.blockdata[block.family]["destructible"]:
			loader.spawn_fx("poof", block.global_position, target, false)

			if GameConfig.blockdata["earth"].has("sound"):
				var sfx = load(GameConfig.blockdata["earth"].get("sound"))
				if sfx and loader.player and loader.player.audio_player:
					loader.player.audio_player.stream = sfx
					loader.player.audio_player.play()

			block.hide()
			block.queue_free()
			blocks.erase(target)

			# Reveal hidden item logic
			if loader.item_nodes.has(target):
				var item_node = loader.item_nodes[target]
				if is_instance_valid(item_node):
					if item_node.get_meta("is_hidden_item", false):
						item_node.show()
						item_node.modulate.a = 1.0
						item_node.z_index = 50
						
						var sprite = item_node.get_node_or_null("Sprite2D")
						if sprite:
							sprite.show()
							
						item_node.set_meta("is_hidden_item", false)
						
						var area = item_node.get_node_or_null("Area2D")
						if area:
							get_tree().create_timer(0.15).timeout.connect(func():
								if is_instance_valid(area):
									area.set_collision_layer_value(3, true)
									area.set_collision_mask_value(2, true)
							)
				else:
					loader.item_nodes.erase(target)

		else:
			print("Hit indestructible block: ", block.family)
			if GameConfig.blockdata[block.family].has("sound"):
				var sfx = load(GameConfig.blockdata[block.family].get("sound"))
				if sfx and loader.player and loader.player.audio_player:
					loader.player.audio_player.stream = sfx
					loader.player.audio_player.play()
			return

	# 2. ONLY create a block if the target space is empty
	elif not blocks.has(target) and is_player:
		var local_pos = GameConfig.grid_to_local(target[0], target[1], loader.tile_size, loader.x_off, loader.y_off)
		var global_pos = loader.to_global(local_pos) 
		loader.spawn_fx("foop", global_pos, target, true)

func on_foop_finished(grid_pos, type):
	add_block(grid_pos.x, grid_pos.y, type, true)

func destroy_block_at(cell: Vector2i) -> bool:
	print("[DESTROY_BLOCK_AT] frame=", Engine.get_physics_frames(), " cell=", cell, " has_block=", blocks.has(cell))
	if not blocks.has(cell):
		return false
 
	var block = blocks[cell]
	var bdata = GameConfig.blockdata.get(block.family, {})
	if not bdata.get("destructible", false):
		return false
 
	var local_pos = GameConfig.grid_to_local(cell.x, cell.y, loader.tile_size, loader.x_off, loader.y_off)
	loader.spawn_fx("poof", loader.to_global(local_pos), cell, false)
 
	blocks.erase(cell)
	block.queue_free()
	return true

func remove_block_at_pos(world_pos: Vector2):
	var cell = GameConfig.world_to_grid(world_pos, loader.x_off, loader.y_off, loader.tile_size)
	if blocks.has(cell):
		blocks[cell].queue_free()
		blocks.erase(cell)

func spawn_block_at_world_pos(world_pos: Vector2, type: String):
	var grid_pos = GameConfig.world_to_grid(world_pos, loader.x_off, loader.y_off, loader.tile_size)
	add_block(grid_pos.x, grid_pos.y, type, true)

func replace_block(world_pos: Vector2, new_family: String):
	var cell = GameConfig.world_to_grid(world_pos, loader.x_off, loader.y_off, loader.tile_size)
	if blocks.has(cell):
		blocks[cell].queue_free()
		blocks.erase(cell)
	add_block(cell.x, cell.y, new_family, true)

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
