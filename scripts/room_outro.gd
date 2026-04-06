extends Node

class_name RoomOutro

var loader: Node2D
var fx_scene: PackedScene

var door_node: Node2D = null
var key_node: Node2D = null
var player_node: Node2D = null

func _init(_loader: Node2D):
	loader = _loader
	fx_scene = loader.fx_scene

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
