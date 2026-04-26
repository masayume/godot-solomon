extends HBoxContainer

@export var life_icon: Texture2D # the small player sprite

# We track this to subtract 1 while the player is active in the stage
var is_player_in_stage: bool = false

func _ready():

	self.add_to_group("hud_lives")

	# Connect to the manager's signal
#	GameManager.lives_changed.connect(update_icons)

	# Connect to the manager's signal
	if GameManager.has_signal("lives_changed"):
		GameManager.lives_changed.connect(_on_lives_changed)
		
	# Initial draw
	update_icons(GameManager.current_lives)


func _on_lives_changed(new_total: int):
	update_icons(new_total)

## Call this when the player is spawned into the level
func set_player_active(active: bool):
	is_player_in_stage = active
	update_icons(GameManager.current_lives)
		
func update_icons(total_count: int):
	# 1. Clear current icons
	for child in get_children():
		child.queue_free()

	# 2. Calculate displayed icons
	# The Player in 'LevelRoot/Level' is "using" one life.
	# We show the remaining "reserve" lives in the 'UI/ContLives' container.
	var display_count = total_count
	if is_player_in_stage:
		display_count = max(0, total_count - 1)

	# 3. Add new icons based on the display count
	for i in range(display_count):
		var rect = TextureRect.new()
		rect.texture = life_icon
		rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		# Optional: set a custom size for the icons
		rect.custom_minimum_size = Vector2(32, 32)
		add_child(rect)

#	# 2. Add new icons based on the count
#	for i in range(count):
#		var rect = TextureRect.new()
#		rect.texture = life_icon
#		# Keep the player symbol from stretching
#		rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
#		add_child(rect)
