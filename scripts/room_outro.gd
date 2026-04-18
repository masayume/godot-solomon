extends Node

class_name RoomOutro

var loader: Node2D
var fx_scene: PackedScene

var door_node: Node2D = null
var key_node: Node2D = null
var player_node: Node2D = null
@onready var audio_player = $AudioStreamPlayer2D

func _init(_loader: Node2D):
	loader = _loader
	fx_scene = loader.fx_scene

func _animate_stars_explode(origin_node: Node2D):
	if origin_node == null: return

	var data = GameConfig.fxdata.get("stars", {})
	var num_stars = data.get("stars_num", 16)
	var move_duration = data.get("move_speed", 1.5)
	var radius = 300.0 
	
	# 1. Define the Room Center (Block 6,8)
	var room_center = GameConfig.grid_to_local(8, 6, loader.tile_size, loader.x_off, loader.y_off) 
	var start_pos = origin_node.global_position 

	# 2. Create a Pivot Node to handle rotation and translation
	var pivot = Node2D.new() 
	loader.add_child(pivot) 
	pivot.global_position = start_pos 
		
	# Play sound (existing logic)
	if GameConfig.itemdata["door"].has("outrosound"): 
		var sfx = load(GameConfig.itemdata["door"].outrosound) 
		if sfx:
			var player_node = loader.get_tree().get_first_node_in_group("playergroup")
			player_node.audio_player.stream = sfx 
			player_node.audio_player.play() 

	# Set up a parallel tween so rotation and movement happen at the same time
	var tween = loader.create_tween().set_parallel(true) 

	# 3. Instantiate stars as children of the pivot
	for i in range(num_stars):
		var star = fx_scene.instantiate() 
		pivot.add_child(star) 
		
		# IMPORTANT: Set 'position' (local), not 'global_position'
		# This makes the star relative to the pivot so it will rotate with it.
		var angle = (PI * 2 / num_stars) * i 
		star.position = Vector2.ZERO # Start at the center of the pivot
		star.setup_fx("stars") 

		# A. Expand the stars outward from the pivot center locally
		var target_local_pos = Vector2(cos(angle), sin(angle)) * radius 
		tween.tween_property(star, "position", target_local_pos, move_duration)\
			.set_trans(Tween.TRANS_SINE)\
			.set_ease(Tween.EASE_OUT)
		
		# B. Fade out the individual stars
		tween.tween_property(star, "modulate:a", 0.0, move_duration) 

	# 4. Animate the Pivot itself
	# Move the whole pivot group to the room center
	tween.tween_property(pivot, "global_position", room_center, move_duration)\
		.set_trans(Tween.TRANS_SINE)\
		.set_ease(Tween.EASE_IN_OUT)

	# Rotate the pivot (this causes all child stars to orbit)
	tween.tween_property(pivot, "rotation", TAU, move_duration) 

	# 5. Cleanup the entire pivot (and all stars inside it) when finished
	await tween.finished 
	pivot.queue_free()


func _animate_stars_explode2DEL(origin_node: Node2D):
	if origin_node == null: return

	var data = GameConfig.fxdata.get("stars", {})
	var num_stars = data.get("stars_num", 16)
	var move_duration = data.get("move_speed", 1.5)
	var radius = 200.0 # Distance stars travel outward
	var center_pos = origin_node.global_position

	# 1. Define the Room Center (Block 6,8)
	var room_center = GameConfig.grid_to_local(6, 8, loader.tile_size, loader.x_off, loader.y_off)
	var start_pos = origin_node.global_position

	# 2. Create a Pivot Node to handle rotation and translation
	var pivot = Node2D.new()
	loader.add_child(pivot)
	pivot.global_position = start_pos # Start at player position
		
	if GameConfig.itemdata["door"].has("outrosound"):
		var sfx = load(GameConfig.itemdata["door"].outrosound)
		if sfx:
			loader.get_tree().get_first_node_in_group("playergroup").audio_player.stream = sfx
			loader.get_tree().get_first_node_in_group("playergroup").audio_player.play() # Plays once when the state starts

	var tween = loader.create_tween().set_parallel(true)

	for i in range(num_stars):
		var star = fx_scene.instantiate()
		pivot.add_child(star)

		# Position stars in a circle relative to pivot (0,0)
		var angle = (PI * 2 / num_stars) * i
		star.position = Vector2(cos(angle), sin(angle)) * radius
		star.setup_fx("stars")

#		# Start all stars at the player/origin position
#		star.global_position = center_pos
#		star.setup_fx("stars") # Uses your looping logic 

		# Calculate destination on the circumference
#		var angle = (PI * 2 / num_stars) * i
		var target_offset = Vector2(cos(angle), sin(angle)) * radius
		var target_pos = center_pos + target_offset
		
		# A. Move the whole pivot group to the room center
		tween.tween_property(star, "global_position", target_pos, move_duration)\
			.set_trans(Tween.TRANS_SINE)\
			.set_ease(Tween.EASE_OUT)

		# B. Rotate the pivot (causes the stars to orbit the moving center)
		# Rotating 360 degrees (TAU) over the duration
		tween.tween_property(pivot, "rotation", TAU, move_duration)
				
		# Fade out as they expand and clean up
		tween.tween_property(star, "modulate:a", 0.0, move_duration)
		
		# Clean up star after tween
		tween.finished.connect(star.queue_free)

	await tween.finished
