extends CanvasLayer

@onready var book_panel: Control = $BookPanel
@onready var page_image: TextureRect = $BookPanel/PageImage

@export var fireball_page_texture: Texture2D
@export var block_spell_page_texture: Texture2D

# Track which spell is currently displayed
var current_spell: String = "" 
var _active_tween: Tween

func _ready():
	# Start completely hidden
	book_panel.modulate.a = 0.0
	book_panel.visible = false
	book_panel.pivot_offset = book_panel.size / 2.0

func show_spell(spell_name: String):
	# 1. If it's the exact same spell and the book is already open, do nothing!
	if spell_name == current_spell and book_panel.visible:
		return

	# 2. Determine which page to display
	var target_texture: Texture2D
	match spell_name:
		"fireball":
			target_texture = fireball_page_texture
		"block":
			target_texture = block_spell_page_texture
		_:
			return # Unknown spell

	# 3. Kill any existing animation to prevent conflicts
	if _active_tween:
		_active_tween.kill()

	# 4. First time opening? Play the "pop in" animation.
	if not book_panel.visible:
		book_panel.visible = true
		book_panel.scale = Vector2(0.5, 0.5)
		book_panel.modulate.a = 0.0
		
		# Set the texture immediately for the first open
		page_image.texture = target_texture 

		_active_tween = create_tween()
		_active_tween.set_ease(Tween.EASE_OUT)
		_active_tween.set_trans(Tween.TRANS_BACK) # Gives a nice "pop" effect
		_active_tween.set_parallel(true)
		_active_tween.tween_property(book_panel, "scale", Vector2.ONE, 0.25)
		_active_tween.tween_property(book_panel, "modulate:a", 1.0, 0.15)
		
	else:
		# Already open, but changing spells. Play a quick "page turn" crossfade.
		_active_tween = create_tween()
		# Fade out current page
		_active_tween.tween_property(page_image, "modulate:a", 0.0, 0.1)
		# Swap texture at the exact moment it's invisible
		_active_tween.tween_callback(func(): 
			page_image.texture = target_texture
		)
		# Fade in new page
		_active_tween.tween_property(page_image, "modulate:a", 1.0, 0.1)

	# 5. Update the tracker
	current_spell = spell_name
