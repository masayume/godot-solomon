extends CharacterBody2D

@export var tile_size: int = 64
@export var variants: int = 6
@export var family: String = "jewel500"

@onready var sprite: Sprite2D = $Sprite2D
@onready var collider = $CollisionShape2D

var debug_label: Label
var action: String = "collect"

func _ready():
	z_index = 0
	set_texture()
	set_random_variant()
	set_collidable()

# If the cfg says collidable=false, disable the main physics body
# so the player can walk through it.
	$CollisionShape2D.disabled = !GameConfig.itemdata.get("collidable", false)
	
	# Ensure the Area2D is ALWAYS enabled for interactions
	$Area2D.monitoring = true


###DEBUG
#	if OS.is_debug_build():
#		_setup_debug_label()

func _setup_debug_label():
	debug_label = Label.new()
	add_child(debug_label)
	
	# Lift it above the sprite
	debug_label.position = Vector2(-20, -40) 
	
	# Make the text small and readable
	debug_label.add_theme_font_size_override("font_size", 10)
	
	# Update the text to show its identity
	_update_debug_text()

func _update_debug_text():
	if not debug_label: return
	
	var has_receiver = has_node("Receiver")
	var text = "ID: %s\n" % name
	text += "Receiver: %s" % ("YES" if has_receiver else "NO")
	
	debug_label.text = text
			
func set_texture():
	var path = "res://sprites/items/%s.png" % family
	sprite.texture = load(path)

func _on_body_entered(body):
	# We use the Interactor node already attached to the Player
	# instead of creating a new one with .new() every time.
	if $Interactor: 
		$Interactor.interact(body)
		
func set_random_variant():
	var tile_index = randi() % variants
	var x = tile_index * tile_size
	sprite.region_enabled = true
	sprite.region_rect = Rect2(x, 0, tile_size, tile_size)

func set_collidable():
	
	if !GameConfig.itemdata.has(family):
		print("ERROR: unknown item family: ", family)
		return
		
#	print("FAMILY:", family, " ITEMKDATA:", GameConfig.itemdata)
	
	var data = GameConfig.itemdata[family]	
	var collidable = data.get("collidable", true)
	
	# print(data)
	collider.disabled = !collidable
