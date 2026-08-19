extends CanvasLayer

# This script will handle swapping the spell page, animating the book opening, 
# and automatically closing it after a short delay.

# Reference to the inner panel that we will animate
@onready var book_panel: Control = $BookPanel
@onready var page_image: TextureRect = $BookPanel/PageImage

# Assign these in the Inspector later!
@export var fireball_page_texture: Texture2D
@export var block_spell_page_texture: Texture2D

var _close_timer: Timer
var _active_tween: Tween

func _ready():
	# Start completely hidden
	book_panel.modulate.a = 0.0
	book_panel.visible = false
	book_panel.pivot_offset = book_panel.size / 2.0 # Scale from the center
	
	# Setup a timer to auto-close the book
	_close_timer = Timer.new()
	_close_timer.one_shot = true
	_close_timer.timeout.connect(_close_book)
	add_child(_close_timer)

# Called by the player when a spell is cast
func show_spell(spell_name: String):
	# 1. Determine which page to display
	var target_texture: Texture2D
	match spell_name:
		"fireball":
			target_texture = fireball_page_texture
		"block":
			target_texture = block_spell_page_texture
		_:
			return # Unknown spell, do nothing
			
	page_image.texture = target_texture
	
	# 2. Kill any existing animation to prevent conflicts if player spams the button
	if _active_tween:
		_active_tween.kill()
		
	# 3. Open the book with a quick scale and fade-in animation
	book_panel.visible = true
	book_panel.scale = Vector2(0.5, 0.5)
	book_panel.modulate.a = 0.0
	
	_active_tween = create_tween()
	_active_tween.set_ease(Tween.EASE_OUT)
	_active_tween.set_trans(Tween.TRANS_BACK) # Gives a nice "pop" effect
	_active_tween.set_parallel(true)
	_active_tween.tween_property(book_panel, "scale", Vector2.ONE, 0.25)
	_active_tween.tween_property(book_panel, "modulate:a", 1.0, 0.15)
	
	# 4. Keep it open for 1.2 seconds, then trigger close
	_close_timer.start(1.2)

func _close_book():
	if _active_tween:
		_active_tween.kill()
		
	_active_tween = create_tween()
	_active_tween.set_ease(Tween.EASE_IN)
	_active_tween.set_trans(Tween.TRANS_QUAD)
	_active_tween.set_parallel(true)
	_active_tween.tween_property(book_panel, "scale", Vector2(0.8, 0.8), 0.2)
	_active_tween.tween_property(book_panel, "modulate:a", 0.0, 0.2)
	
	# Hide completely when finished to save rendering
	_active_tween.chain().tween_callback(func(): book_panel.visible = false)
