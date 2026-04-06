extends Node
class_name RoomIntro

var loader: Node2D
var fx_scene: PackedScene

var door_node: Node2D = null
var key_node: Node2D = null
var player_node: Node2D = null

func _init(_loader: Node2D):
	loader = _loader
	fx_scene = loader.fx_scene

func play_intro(data: Dictionary):
	
	# wait for player to be registered on the scene tree in next frame
	await loader.get_tree().process_frame
	
	# 1. Show Room Name (3 Seconds)
	loader.level_label.text = "Round %d - %s" % [data["id"], data["name"]]
	loader.level_label.visible = true
	loader.intro_room_label.text = "Round %d - %s" % [data["id"], data["name"]]
	loader.intro_room_label.visible = true
		
	# 2. Spawn everything at 50% opacity
#	_spawn_dimmed_content(data)
	
	await loader.get_tree().create_timer(1.0).timeout
	loader.intro_room_label.visible = false
	await loader.get_tree().create_timer(1.0).timeout
	loader.intro_room_label.text = "READY!"
	
	# 3. Door Animation (Placeholder for your door logic)
	await _animate_door()

	# 4. Star to Key
	door_node = loader.get_tree().get_first_node_in_group("doorgroup")
	key_node = loader.get_tree().get_first_node_in_group("keygroup")
	player_node = loader.get_tree().get_first_node_in_group("playergroup")
	await _animate_star_to_target(door_node, key_node) # fx from door to key position

	# 5. Star to Player
	await _animate_stars_twirl_out(player_node) # fx stars twirl around player position
	
	# 6. Finalize: Make everything else (blocks/monsters) 100% visible
	_reveal_all_content()

func _animate_door():
	# get door node
	door_node = loader.get_tree().get_first_node_in_group("doorgroup")
	door_node.visible = true

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

# Inside game_intro.gd
func _animate_stars_twirl_out(target_node: Node2D):
	if target_node == null: return

	var data = GameConfig.fxdata.get("stars", {})
	var num_stars = data.get("stars_num", 16)
	var move_duration = data.get("move_speed", 1.5)
	var radius = data.get("radius", 200.0) # Starting distance from player
	var center_pos = target_node.global_position
	var star_nodes = []

	# 1. Spawn stars in a circle
	for i in range(num_stars):
		var star = fx_scene.instantiate()
		loader.add_child(star)
		
		# Calculate position on circumference
		var angle = (PI * 2 / num_stars) * i
		var spawn_offset = Vector2(cos(angle), sin(angle)) * radius
		star.global_position = center_pos + spawn_offset
		
		star.setup_fx("stars")
		star_nodes.append({"node": star, "angle": angle})

	# 2. Create Tween for the twirl and inward movement
	var tween = loader.create_tween().set_parallel(true)
	for item in star_nodes:
		var s_node = item["node"]
		var start_angle = item["angle"]
		
		# Twirl effect: move position using a custom step or simple inward tween
		# For a true spiral, we animate a property and update position in a loop, 
		# but for this structure, we move them to center while rotating a container 
		# OR simply tweening to center:
		tween.tween_property(s_node, "global_position", center_pos, move_duration)\
			.set_trans(Tween.TRANS_SINE)\
			.set_ease(Tween.EASE_IN_OUT)
			
		# Optional: Fade them out as they hit the center
		tween.tween_property(s_node, "modulate:a", 0.0, move_duration).set_delay(move_duration * 0.1)

	await tween.finished
	
	# 3. Clean up and reveal player
	for item in star_nodes:
		if is_instance_valid(item["node"]): item["node"].queue_free()
	
	loader.spawn_fx("foop", center_pos, Vector2i(-1,-1), false)
	target_node.modulate.a = 1.0
	target_node.visible = true	

func _animate_stars_explode(origin_node: Node2D):
	if origin_node == null: return

	var data = GameConfig.fxdata.get("stars", {})
	var num_stars = data.get("stars_num", 16)
	var move_duration = data.get("move_speed", 1.5)
	var radius = 200.0 # Distance stars travel outward
	var center_pos = origin_node.global_position
	
	var tween = loader.create_tween().set_parallel(true)

	for i in range(num_stars):
		var star = fx_scene.instantiate()
		loader.add_child(star)
		
		# Start all stars at the player/origin position
		star.global_position = center_pos
		star.setup_fx("stars") # Uses your looping logic 

		# Calculate destination on the circumference
		var angle = (PI * 2 / num_stars) * i
		var target_offset = Vector2(cos(angle), sin(angle)) * radius
		var target_pos = center_pos + target_offset
		
		# Move outward
		tween.tween_property(star, "global_position", target_pos, move_duration)\
			.set_trans(Tween.TRANS_SINE)\
			.set_ease(Tween.EASE_OUT)
			
		# Fade out as they expand
		tween.tween_property(star, "modulate:a", 0.0, move_duration)
		
		# Clean up star after tween
		tween.finished.connect(star.queue_free)

	await tween.finished


func _animate_star_to_target(source_node: Node2D, dest_node: Node2D):
	if source_node == null or dest_node == null:
		print("Intro Error: Missing source or destination node")
		return

	# 1. Create the star at the source position (the door)
	var star = fx_scene.instantiate()
	loader.add_child(star)
	star.global_position = source_node.global_position 
	if star.has_method("setup_fx"):
		star.setup_fx("star") # matches [star] section in fx.cfg 

	# 2. Get the specific movement duration from config
	var fx_data = GameConfig.fxdata.get("star", {})
	# Fallback to 1.0 if move_speed is missing in cfg
	var move_duration = fx_data.get("move_speed", 1.0)
	
	# 3.1 Setup the Tween for movement
	var target_pos = dest_node.global_position 
	var tween = loader.create_tween()	
	
	# 3.2 Trans_Sine + Ease_In_Out gives it that smooth "magical" feel
	# Use move_duration for the time parameter
	tween.tween_property(star, "global_position", target_pos, move_duration)\
		.set_trans(Tween.TRANS_SINE)\
		.set_ease(Tween.EASE_IN_OUT)	
		
	
	# 4. Wait for the star to arrive
	await tween.finished 
	
	# 5. Trigger arrival effects
	# We pass a dummy grid pos because spawn_fx usually expects one
	var grid_pos = Vector2i(-1, -1) 
	#loader.spawn_fx("star", target_pos, grid_pos, false) 
	loader.spawn_fx("foop", target_pos, Vector2i(-1, -1), false)
	
	# 5. Reveal the destination node
	dest_node.modulate.a = 1.0 
	
	# 6. Clean up the star
	star.queue_free()


func _reveal_all_content():
	# Make everything else full opacity and start physics
	for node in loader.get_children():
		node.modulate.a = 1.0
		node.visible = true
	
	loader.get_tree().call_group("monstergroup", "set_physics_process", true)
	var player = loader.get_tree().get_first_node_in_group("playergroup")
	if player: player.set_process_input(true)
