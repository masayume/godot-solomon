extends Node2D
signal animation_finished(grid_pos, type)

@onready var sprite = $Sprite2D
@onready var timer = $Timer

var current_frame_index = 0
var frame_sequence = []
var target_grid_pos: Vector2i
var block_type: String

		
	# Calculate total duration if you need it for other logic:
	# var total_duration = data["frames"].size() * data["anim_speed"]

func setup_fx(fx_name: String, g_pos: Vector2i = Vector2i.ZERO, b_type: String = "earth"):
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

func _on_timer_timeout():
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
