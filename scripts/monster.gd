extends CharacterBody2D
class_name Monster

@export var tile_size: int = 64
@export var variants: int = 6
# @export var family: String = "ghost"
@export var family: String

@onready var sprite: Sprite2D = $Sprite2D
@onready var collider = $CollisionShape2D

var stats = {}

func _ready():
	z_index = 20
	add_to_group("monstergroup")
	
	set_collision_layer_value(4, true)  # Monster Layer (Box 4)
	set_collision_mask_value(1, true)   # Only see Walls (Box 1)
		
	set_texture()
	set_random_variant()
	set_collidable()

	if not GameConfig.monsterdata.has(family):
		push_error("CONFIG ERROR: Monster family '%s' not found in GameConfig!" % family)
		return

	stats = GameConfig.monsterdata[family]

	_ensure_receiver_setup()
	_force_hitbox_setup()
	apply_stats()


func _force_hitbox_setup():
	# If HitBox is missing from the .tscn (common in inherited scenes), CREATE IT
	var hb = get_node_or_null("HitBox")
	if not hb:
		print("[DEBUG] HitBox missing in scene tree for ", name, ". Creating one programmatically.")
		hb = Area2D.new()
		hb.name = "HitBox"
		add_child(hb)
		
		# We need a shape for the new Area2D
		var shape = CollisionShape2D.new()
		var circle = CircleShape2D.new()
		circle.radius = 20.0 # Default hazard size
		shape.shape = circle
		hb.add_child(shape)

	# Setup detection layers
	hb.collision_layer = 0
	hb.collision_mask = 0
	hb.set_collision_layer_value(4, true) # Is a Monster
	hb.set_collision_mask_value(2, true)  # LOOKS FOR PLAYER (Layer 2)
	
	hb.monitoring = true
	hb.monitorable = true
	
	# Connect signal
	if not hb.body_entered.is_connected(_on_hitbox_entered):
		hb.body_entered.connect(_on_hitbox_entered)
		print("[SUCCESS] Hitbox connected for ", name)

func _ensure_receiver_setup():
	var receiver = get_node_or_null("Receiver")
	if not receiver:
		receiver = Receiver.new()
		receiver.name = "Receiver"
		add_child(receiver)
		print("[DEBUG] Created missing Receiver node for ", name)
	
	receiver.data = {
		"action_type": "hazard",
		"family": family
	}

func _ensure_receiver_setup2DEL():
	var receiver = get_node_or_null("Receiver")
	if not receiver:
		receiver = Receiver.new()
		receiver.name = "Receiver"
		add_child(receiver)
	
	# This data is what receiver.gd uses to decide what to do
	receiver.data = {
		"action_type": "hazard",
		"family": family
	}

	if not receiver.has_method("receive"):
		push_warning("RECEIVER ERROR: Node exists but is missing 'receive' method on %s" % name)


func _setup_hitbox():
	# The HitBox is the Area2D node defined in Monster.tscn
	var hb = get_node_or_null("HitBox")
	if not hb:
		push_warning("NODE ERROR: Monster '%s' is missing a 'HitBox' Area2D!" % name)
		return
		
	hb.collision_layer = 0
	hb.collision_mask = 0
		
	# Hitbox is a 'Monster' (Layer 4)
	hb.set_collision_layer_value(4, true)
	# Hitbox MUST look for 'Player' (Layer 2)
	hb.set_collision_mask_value(2, true)
		
	hb.monitoring = true
	hb.monitorable = true # Player needs to see it too
		
	# Connect to body_entered because the Player is a CharacterBody2D
	if not hb.body_entered.is_connected(_on_hitbox_entered):
		hb.body_entered.connect(_on_hitbox_entered)

func _on_hitbox_entered(body: Node2D):
	# If the thing entering the Area is the Player
	if body.has_method("trigger_death_from_monster"):
		var receiver = get_node_or_null("Receiver")
		if receiver:
			# Pass the interaction to the receiver
			receiver.receive("monster_hit", body)
		else:
			# Fallback if receiver failed
			body.trigger_death_from_monster()
			
			
func apply_stats():

	# --- common Sprite setup ---
	if stats.has("sprite"):
		$Sprite2D.texture = load(stats["sprite"])
#		print(stats)

	sprite.hframes = stats.get("hframes", 1)
	sprite.vframes = 1
	sprite.region_enabled = false
	
#	sprite.hframes = GameConfig.monsterdata[family].hframes
#	sprite.vframes = 1

	set_texture()


		
func _physics_process(_delta: float):
	# Let children define behavior
	pass	
	
func set_texture():
#	var path = "res://sprites/monsters/%s.png" % family
	var path = GameConfig.monsterdata[family].sprite
	sprite.texture = load(path)
	# 🔥 FORCE RESET EVERYTHING RELATED TO REGION/SLICING
	sprite.region_enabled = false
	sprite.region_rect = Rect2(0, 0, 0, 0)
	
func set_random_variant():
	var tile_index = randi() % variants
	var x = tile_index * tile_size
	sprite.region_enabled = true
	sprite.region_rect = Rect2(x, 0, tile_size, tile_size)

func _on_body_entered(body):
	# We use the Interactor node already attached to the Player
	# instead of creating a new one with .new() every time.
	if $Interactor: 
		$Interactor.interact(body)
		
func set_collidable():
		
	if !GameConfig.monsterdata.has(family):
		print("ERROR: unknown monster family:", family)
		return
		
#	print("FAMILY:", family, " BLOCKDATA:", GameConfig.blockdata)
	
	var data = GameConfig.monsterdata[family]	
	var collidable = data.get("collidable", true)
	
	# print(data)
	collider.disabled = !collidable
