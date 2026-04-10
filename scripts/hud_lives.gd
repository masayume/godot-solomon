extends HBoxContainer

@export var life_icon: Texture2D # Assign your small player sprite here

func _ready():
	# Connect to the manager's signal
	GameManager.lives_changed.connect(update_icons)
	# Initial draw
	update_icons(GameManager.current_lives)

func update_icons(count: int):
	# 1. Clear current icons
	for child in get_children():
		child.queue_free()
	
	# 2. Add new icons based on the count
	for i in range(count):
		var rect = TextureRect.new()
		rect.texture = life_icon
		# Keep the player symbol from stretching
		rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		add_child(rect)
