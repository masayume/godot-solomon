extends Monster
class_name Fairy

# var direction := -1
var direction := 1

var gravity = GameConfig.monsterdata.fairy.gravity

var hitbox: Area2D 


func _ready():
	family = "fairy"
	add_to_group("monsters") 
	super._ready()

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


func _setup_hitbox():
	if not hitbox: return
	
	# the hitbox is configured as an item layer so the Player's CollectionZone finds it
	hitbox.collision_layer = 4 # Or whichever layer your items use (e.g. Layer 3 or 4)
	hitbox.collision_mask = 0  # It doesn't need to monitor anything; the player monitors it




func behave(_delta):
	# Use state-specific speed if defined in config, otherwise fallback to default family speed
	var state_data = GameConfig.monsterdata.get(current_state, stats)
	var current_speed = state_data.get("speed", stats.get("speed", 0))
		
	velocity.x = direction * current_speed
	sprite.flip_h = velocity.x < 0

	# Apply gravity
	if not is_on_floor():
		velocity.y += gravity * _delta
	else:
		velocity.y = 0
		
	# simple back-and-forth
	if is_on_wall():
		direction *= -1
		
	move_and_slide()
