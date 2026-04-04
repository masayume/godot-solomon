extends Node
class_name GameIntro

var loader: Node2D
var fx_scene: PackedScene

func _init(_loader: Node2D):
	loader = _loader
	fx_scene = loader.fx_scene

func play_intro(data: Dictionary):
	
	# wait for player to be registered on the scene tree in next frame
	await loader.get_tree().process_frame
	
	# 1. Show Room Name (3 Seconds)
	loader.level_label.text = "Stage %d - %s" % [data["id"], data["name"]]
	loader.level_label.visible = true
	loader.intro_room_label.text = "Stage %d - %s" % [data["id"], data["name"]]
	loader.intro_room_label.visible = true
		
	# 2. Spawn everything at 50% opacity
#	_spawn_dimmed_content(data)
	
	await loader.get_tree().create_timer(3.0).timeout
	loader.intro_room_label.visible = false

	# 3. Door Animation (Placeholder for your door logic)
	# await _animate_door()

	# 4. Star to Key
	await _animate_star_to_target(data, "key")

	# 5. Star to Player
	await _animate_star_to_target(data, "player")
	
	# 6. Finalize: Make everything else (blocks/monsters) 100% visible
	_reveal_all_content()

func _spawn_dimmed_content(data):
	# Call loader functions with 0.5 opacity
	for b in data["blocks"]:
		loader.add_block(b["pos"][0], b["pos"][1], b["family"], 0.5)
	
	if data.has("items"):
		for i in data["items"]:
			loader.add_item(i["pos"][0], i["pos"][1], i["family"], 0.5)

	loader.spawn_player(data["player_start"][0], data["player_start"][1], loader.x_off, loader.y_off)
	
	# Pause monsters [cite: 15]
	loader._spawn_monster_logic(data) 
	loader.get_tree().call_group("monstergroup", "set_physics_process", false)
	loader.get_tree().call_group("monstergroup", "set_modulate", Color(1,1,1,0.5))

func _animate_star_to_target(data, target_type: String):
	var target_pos: Vector2
	var grid_pos: Vector2i
	var target_node: Node2D

	if target_type == "key":
		for i in data["items"]:
			if i["family"] == "key":
				grid_pos = Vector2i(i["pos"][0], i["pos"][1])
				target_pos = GameConfig.grid_to_local(grid_pos.x, grid_pos.y, loader.tile_size, loader.x_off, loader.y_off)
				# Find the actual node in the scene
				for item in loader.get_tree().get_nodes_in_group("itemgroup"):
					if item.family == "key": target_node = item
				break
	else: # Player
		grid_pos = Vector2i(data["player_start"][0], data["player_start"][1])
		target_node = loader.get_tree().get_first_node_in_group("playergroup")
		target_pos = target_node.global_position
				
	if target_node:
		var star = fx_scene.instantiate()
		loader.add_child(star)
		star.global_position = Vector2(0,0) # Starting point (the door)
		
		var tween = loader.create_tween()
		tween.tween_property(star, "global_position", target_pos, 1.2).set_trans(Tween.TRANS_SINE)
		await tween.finished
		
		loader.spawn_fx("foop", target_pos, grid_pos, false)
		target_node.modulate.a = 1.0 # Pop to full visibility
		star.queue_free()

func _reveal_all_content():
	# Make everything else full opacity and start physics
	for node in loader.get_children():
		node.modulate.a = 1.0
	
	loader.get_tree().call_group("monstergroup", "set_physics_process", true)
	var player = loader.get_tree().get_first_node_in_group("playergroup")
	if player: player.set_process_input(true)
