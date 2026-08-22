extends CanvasLayer

@onready var book_panel: Control = $BookPanel
@onready var page_image: TextureRect = $BookPanel/PageImage

var current_spell: String = "" 
var _active_tween: Tween

func _ready():
	# Start completely hidden
	book_panel.modulate.a = 0.0
	book_panel.visible = false
	book_panel.pivot_offset = book_panel.size / 2.0 # Scale the whole book from the center

func show_spell(spell_name: String):
	# 1. If it's the exact same spell and the book is already open, do nothing!
	if spell_name == current_spell and book_panel.visible:
		return

	# 2. Determine which page to display from GameConfig
	var texture_path = "res://sprites/ui/spellbook/default-page-1.png" # Fallback
	
	if GameConfig.spellbookdata.has(spell_name):
		texture_path = GameConfig.spellbookdata[spell_name].get("texture", texture_path)
	
	var target_texture = load(texture_path)
	if not target_texture:
		push_warning("Failed to load spellbook texture for: " + spell_name)
		return

	# 3. Kill any existing animation to prevent conflicts
	if _active_tween:
		_active_tween.kill()

	# 4. First time opening? Play the "pop in" animation for the whole book.
	if not book_panel.visible:
		book_panel.visible = true
		book_panel.scale = Vector2(0.5, 0.5)
		book_panel.modulate.a = 0.0
		
		page_image.texture = target_texture 

		_active_tween = create_tween()
		_active_tween.set_ease(Tween.EASE_OUT)
		_active_tween.set_trans(Tween.TRANS_BACK) # Gives a nice "pop" effect
		_active_tween.set_parallel(true)
		_active_tween.tween_property(book_panel, "scale", Vector2.ONE, 0.25)
		_active_tween.tween_property(book_panel, "modulate:a", 1.0, 0.15)
		
	else:
		# Already open: Animate a physical page turn!
		_animate_page_turn(target_texture)

	# 5. Update the tracker
	current_spell = spell_name

func _animate_page_turn(new_texture: Texture2D):
	# Set the pivot to the left-center of the page so it flips like a book
	page_image.pivot_offset = Vector2(0, page_image.size.y / 2.0)
	
	_active_tween = create_tween()
	_active_tween.set_trans(Tween.TRANS_QUAD)
	
	# 1. Close the current page (squash X axis to nearly 0)
	_active_tween.tween_property(page_image, "scale:x", 0.05, 0.1)
	
	# 2. Swap the texture at the exact moment it's "closed"
	_active_tween.tween_callback(func():
		page_image.texture = new_texture
		# Reset scale slightly to avoid 0-width rendering glitches in Godot
		page_image.scale.x = 0.05 
	)
	
	# 3. Open the new page (expand X axis back to 1)
	_active_tween.tween_property(page_image, "scale:x", 1.0, 0.15).set_ease(Tween.EASE_OUT)
