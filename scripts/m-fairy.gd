extends Monster
class_name Fairy

# var direction := -1

var gravity = GameConfig.monsterdata.fairy.gravity

var hitbox: Area2D 
var loader: Node = null

const HINT_RADIUS: float = 110.0     # ~1.7 tiles at 64px - tune to taste
const HINT_INTERVAL: float = 3.2     # seconds between twinkle pulses while nearby

var _hint_timer: float = 0.0

func _ready():
	family = "fairy"
	add_to_group("monsters") 
	super._ready()

	loader = get_tree().get_first_node_in_group("level_loader")

	# Force visibility of collision for this specific instance
	# if you want to be 100% sure during debug
	if get_node_or_null("CollisionShape2D"):
		get_node("CollisionShape2D").visible = true

	hitbox = get_node_or_null("HitBox")
	_setup_hitbox()
	
#	print("Fairy layer:", collision_layer, " mask: ", collision_mask)
	# Ghost HitBox
	collision_layer = 4   # (or anything, not important)
	collision_mask = 1    # must match Player layer	
		

func _physics_process(_delta):

	behave(_delta) # includes move_and_slide()

	if is_on_wall():
		direction *= -1

	_hint_timer -= _delta
	if _hint_timer <= 0:
		_hint_timer = HINT_INTERVAL
		_hint_nearby_hidden_items()

func _hint_nearby_hidden_items():
	if not loader:
		return

	for item in loader.item_nodes.values():
		if not is_instance_valid(item):
			continue
		if not item.get_meta("is_hidden_item", false):
			continue

		if global_position.distance_to(item.global_position) <= HINT_RADIUS:
			loader.spawn_fx("twinkle", item.global_position, Vector2i(-1, -1), false)


func _setup_hitbox():
	if not hitbox: return
	
	# the hitbox is configured as an item layer so the Player's CollectionZone finds it
	hitbox.collision_layer = 4 # Or whichever layer your items use (e.g. Layer 3 or 4)
	hitbox.collision_mask = 0  # It doesn't need to monitor anything; the player monitors it
	

func behave(_delta):
	velocity.x = direction * GameConfig.monsterdata[family].speed
	sprite.flip_h = velocity.x < 0

	# Apply gravity
	if not is_on_floor():
		velocity.y += gravity * _delta
	else:
		velocity.y = 0

	# Check if the fairy just hit the floor
	if is_on_floor():
		# Define how high you want the bounce to be. 
		# Negative values move UP in Godot's 2D coordinate system.
		# You can also use a variable like GameConfig.monsterdata[family].bounce_force
		var bounce_force = GameConfig.monsterdata[family].bounce_force 
		velocity.y = bounce_force
				
	# simple back-and-forth
#	if is_on_wall():
#		direction *= -1
		
	move_and_slide()
