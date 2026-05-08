extends HBoxContainer

# Asset paths
const PATH_LEFT = "res://sprites/ui/parch_left.png"
const PATH_RIGHT = "res://sprites/ui/parch_right.png"
const PATH_EMPTY = "res://sprites/ui/parch_slot0.png"
const PATH_FILLED = "res://sprites/ui/parch_slot1.png"

# State variables
var total_slots: int = 3 # Player starts with 3 slots
var filled_slots: int = 0 # Starts with 0 filled

func _ready():
	# Ensure the container doesn't add extra spacing between the 32x32 sprites
	add_theme_constant_override("separation", 0)
	render_scroll()

## Adds a new empty capacity slot (from Parchment)
func add_capacity():
	total_slots += 1
	render_scroll()

## Fills the rightmost empty slot (from Blue Lantern)
func fill_fireball():
	if filled_slots < total_slots:
		filled_slots += 1
		render_scroll()

## Clears and rebuilds the horizontal row of sprites
func render_scroll():
	# 1. Clear existing sprites
	for child in get_children():
		child.queue_free()
	
	# 2. Add Left Edge
	_add_sprite(PATH_LEFT)
	
	# 3. Add Slots
	# Note: To fill from right-to-left as requested, 
	# we place empty slots first, then filled slots.
	var empty_count = total_slots - filled_slots
	
	for i in range(empty_count):
		_add_sprite(PATH_EMPTY)
		
	for i in range(filled_slots):
		_add_sprite(PATH_FILLED)
	
	# 4. Add Right Edge
	_add_sprite(PATH_RIGHT)

func _add_sprite(path: String):
	var tex = TextureRect.new()
	tex.texture = load(path)
	# Ensure the sprite stays at its 32x32 size
	tex.stretch_mode = TextureRect.STRETCH_KEEP
	add_child(tex)
