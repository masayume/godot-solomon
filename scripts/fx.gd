extends Node2D
signal animation_finished(grid_pos, type)

@onready var sprite = $Sprite2D
@onready var timer = $Timer

var current_frame_index = 0
var frame_sequence = []
var target_grid_pos: Vector2i
var block_type: String
var is_looping: bool = false # Add this variable
var fx_name_stored

	# Calculate total duration if you need it for other logic:
	# var total_duration = data["frames"].size() * data["anim_speed"]

func setup_fx(fx_name: String, g_pos: Vector2i = Vector2i.ZERO, b_type: String = "earth"):
	target_grid_pos = g_pos
	block_type = b_type
	fx_name_stored = fx_name
	
	# Load data from GameConfig dictionary
	var data = GameConfig.fxdata.get(fx_name, {})
	if data.is_empty():
		queue_free()
		return
	
	# Determine if this effect should loop (e.g., if it has a move_speed)
	is_looping = data.has("move_speed") 

	sprite.texture = load(data["sprite"])
	sprite.hframes = data["hframes"]
	frame_sequence = data["frames"]
	
	sprite.frame = frame_sequence[0]
	timer.wait_time = data["anim_speed"]
	# Ensure we don't connect the signal multiple times if setup is called again
	if not timer.timeout.is_connected(_on_timer_timeout):
		timer.timeout.connect(_on_timer_timeout)
#	else:
#		sprite.frame = frame_sequence[0]
#		timer.wait_time = data["anim_speed"]
#		timer.timeout.connect(_on_timer_timeout)	
	timer.start()

# even if an effect is manually cleaned up or reaches its end, it notifies the loader.
func _on_timer_timeout():
	current_frame_index += 1
	
	if current_frame_index < frame_sequence.size():
		sprite.frame = frame_sequence[current_frame_index]
	else:
		# If it's a looping effect (like the star), restart frames
		var move_speed = GameConfig.fxdata.get(fx_name_stored, {}).get("move_speed", 0)
		if move_speed > 0:
			current_frame_index = 0
			sprite.frame = frame_sequence[0]
		else:
			# ONE-SHOT EFFECT (foop/poof): 
			# 1. Emit the signal BEFORE queue_free so the block can spawn
			animation_finished.emit(target_grid_pos, block_type)
			queue_free()

#		if is_looping:
#			# Restart the frame sequence instead of killing the node [cite: 66]
#			current_frame_index = 0
#			sprite.frame = frame_sequence[0]
#		else:
#			# Standard "one-shot" behavior for poof/foop 
#			animation_finished.emit(target_grid_pos, block_type)
#			queue_free()

func setup_block_fx(fx_name: String, g_pos: Vector2i = Vector2i.ZERO, b_type: String = "earth"):
	target_grid_pos = g_pos
	block_type = b_type
	
#func setup_fx(fx_name: String):
	# Load data from your GameConfig dictionary
	var data = GameConfig.fxdata.get(fx_name, {})
	if data.is_empty():
		queue_free()
		return
	
	# Configure Sprite
	sprite.texture = load(data["sprite"])
	sprite.hframes = data["hframes"]
	frame_sequence = data["frames"]
	
	# Start Animation
	sprite.frame = frame_sequence[0]
	timer.wait_time = data["anim_speed"]
	timer.timeout.connect(_on_timer_timeout)
	timer.start()

func _on_timer_timeout2DEL():
	current_frame_index += 1
	if current_frame_index < frame_sequence.size():
		sprite.frame = frame_sequence[current_frame_index]
	else:
		animation_finished.emit(target_grid_pos, block_type) # Tell loader we are done
		queue_free() # Destroy FX when animation finishes
		
#func _on_timer_timeout():
#	current_frame_index += 1
#	
#	if current_frame_index < frame_sequence.size():
#		sprite.frame = frame_sequence[current_frame_index]
#	else:
#		queue_free() # Destroy FX when animation finishes
