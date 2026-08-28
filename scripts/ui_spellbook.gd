extends CanvasLayer

@onready var book_panel: Control = $BookPanel
@onready var page_image: TextureRect = $BookPanel/PageImage

var current_spell: String = "" 
var _active_tween: Tween
var base_pages: TextureRect # Spellbook backround created programmatically

func _ready():
	
	# START spellbook background via code -----------------------
	base_pages = TextureRect.new()
	base_pages.name = "BasePages"

	# Make it scale nicely within the parent panel
	base_pages.expand_mode = TextureRect.EXPAND_FIT_HEIGHT_PROPORTIONAL
	base_pages.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED

	# Pick a random default page from the config array
	var default_data = GameConfig.spellbookdata.get("default", {})
	var stack_textures = default_data.get("stack_textures", ["res://sprites/ui/spellbook/default-page-1.png"])

	# Ensure we have at least one texture, then pick randomly
	if stack_textures.size() > 0:
		var random_tex_path = stack_textures[randi() % stack_textures.size()]
		var stack_texture = load(random_tex_path)
###DEBUG print log with visible icons
		if stack_texture:
			base_pages.texture = stack_texture
			print("✅ Spellbook: Successfully loaded background texture: ", random_tex_path)
		else:
			print("❌ Spellbook ERROR: Failed to load background texture at: ", random_tex_path)
	
	# Offset slightly to create the "thick book" illusion
	base_pages.set_anchors_preset(Control.PRESET_FULL_RECT)
	base_pages.position = Vector2(4, 4) 

	# Add to BookPanel and force it to be the FIRST child (rendered behind everything else)
	book_panel.add_child(base_pages)
	book_panel.move_child(base_pages, 0)
	# END spellbook background via code -----------------------

	# We wait 1 frame so Godot finishes calculating PageImage's exact layout.
	# Then we clone its anchors/offsets and add the 4px "thickness" offset.
	call_deferred("_sync_background_layout")

	book_panel.visible = true
	book_panel.modulate.a = 1.0
	book_panel.scale = Vector2.ONE
	book_panel.pivot_offset = book_panel.size / 2.0 

	# But the active spell page is hidden until a spell is cast
#	page_image.visible = false

# Called automatically after _ready() finishes the current frame
func _sync_background_layout():
	if not base_pages or not page_image:
		return
		
	# 1. Clone Anchors exactly
	base_pages.anchor_left = page_image.anchor_left
	base_pages.anchor_top = page_image.anchor_top
	base_pages.anchor_right = page_image.anchor_right
	base_pages.anchor_bottom = page_image.anchor_bottom
	
	# 2. Clone Offsets and add the 4px "thick book" shift
	base_pages.offset_left = page_image.offset_left + 4
	base_pages.offset_top = page_image.offset_top + 4
	base_pages.offset_right = page_image.offset_right + 4
	base_pages.offset_bottom = page_image.offset_bottom + 4
	
	# 3. Clone Texture stretch behaviors so it scales identically
	base_pages.expand_mode = page_image.expand_mode
	base_pages.stretch_mode = page_image.stretch_mode
	
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
