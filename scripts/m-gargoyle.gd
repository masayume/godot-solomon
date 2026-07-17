extends Monster
class_name Gargoyle

# var direction := -1

var gravity = GameConfig.monsterdata.gargoyle.gravity
# var gravity: float = 980.0

var fall_start_y: float = 0.0
var was_on_floor: bool = true

var hitbox: Area2D 

# RayCast2D to search for Player
@onready var player_sight: RayCast2D = get_node_or_null("RayCast4Player")
var shoot_cooldown: float = 0.0
const SHOOT_COOLDOWN_TIME := 1.5

func _ready():
	family = "gargoyle"
	add_to_group("monsters") 
	super._ready()
	
	hitbox = get_node_or_null("HitBox")
	_setup_hitbox()

	# 3. SAFELY get gravity from the loaded stats, falling back to the default if missing
	gravity = stats.get("gravity", gravity)
		
#	print("Gargoyle layer:", collision_layer, " mask: ", collision_mask)
	# Ghost HitBox
	collision_layer = 4   # (or anything, not important)
	collision_mask = 1    # must match Player layer	

	if player_sight:
		player_sight.collision_mask = 2 | 1   # see Player (2) and Walls (1, to block sight)
		player_sight.enabled = true


func _physics_process(_delta):
	if not is_falling_to_death:
		if was_on_floor and not is_on_floor():
			fall_start_y = global_position.y   # mark where the fall began
		was_on_floor = is_on_floor()

		if not is_on_floor() and global_position.y - fall_start_y > tile_size * 1.5:
			start_fall_death()
			return

	velocity.x = direction * GameConfig.monsterdata.gargoyle.speed

	behave(_delta) # includes move_and_slide()

#	if is_on_wall():
#		direction *= -1

	_check_player_sight(_delta)


func _check_player_sight(delta):
	if shoot_cooldown > 0.0:
		shoot_cooldown -= delta
		return

	if not player_sight:
		return

	# Point the ray in the direction the Gargoyle is facing
	player_sight.target_position = Vector2(400 * direction, 0)
	player_sight.force_raycast_update()

	if player_sight.is_colliding():
		var target = player_sight.get_collider()
		if target.has_method("trigger_death_from_monster"):
			_shoot_fireball()
			shoot_cooldown = SHOOT_COOLDOWN_TIME


func _shoot_fireball():
	var fb_scene = load("res://scenes/p-Fireball.tscn")  # adjust path to match your project
	var fb = fb_scene.instantiate()

	fb.is_monster_projectile = true
	fb.direction = Vector2(direction, 0)
#	fb.collision_mask = 1 | 2   # world + player, not other monsters

	var loader = get_tree().get_first_node_in_group("level_loader")
	fb.loader = loader
#	var spawn_distance = 60.0  # increase clearance
#	fb.global_position = global_position + Vector2(direction * spawn_distance, -4)

	# Compute spawn in local space, then convert to world space
#	var local_spawn = global_position + Vector2(direction * 60.0, -4)
#	fb.global_position = get_parent().to_global(local_spawn)
	fb.global_position = global_position + Vector2(direction * 60.0, -4)
	
#	print("global_position (Gargoyle): ", global_position)
#	print("[SHOOT] direction=", direction, " spawn=", fb.global_position)
	get_parent().add_child(fb)

	# Fix: set the collision mask after add_child so it runs after _ready():
	# _ready() fires when the fireball is added to the scene via get_parent().add_child(fb), 
	# which happens after fb.collision_mask = 1 | 2 is set. So _ready() overwrites it back
	# to 1 | 2 | 4, re-enabling monster detection.
	fb.collision_mask = 1 | 2

#	for child in fb.get_children():
#		print("[FIREBALL CHILD] ", child.name, " type: ", child.get_class())
	
	var spr = fb.get_node_or_null("Sprite2D") 
	if spr:
		spr.flip_h = direction < 0  # flip when moving left
	
	# Prevent immediate self-collision on the frame it spawns
	fb.set_deferred("monitoring", false)
	await get_tree().physics_frame
	fb.set_deferred("monitoring", true)
	

func _setup_hitbox():
	if not hitbox: return
	
	# Ensure Hitbox is set to detect the Player (Layer 2)
	hitbox.collision_layer = 4 # Hitbox needs to be found by fireballs...
	hitbox.collision_mask = 2  # Monitor the Player's Layer
	
#	if not hitbox.area_entered.is_connected(_on_hitbox_entered):
#		hitbox.area_entered.connect(_on_hitbox_entered)
	if not hitbox.body_entered.is_connected(_on_hitbox_body_entered):
		hitbox.body_entered.connect(_on_hitbox_body_entered)

func _on_hitbox_body_entered(body):
	# If we hit the player's physical body
#	print("Ghost hit body:", body)
	if body.has_method("trigger_death_from_monster"):
		body.trigger_death_from_monster()

func behave(_delta):
	velocity.x = direction * GameConfig.monsterdata[family].speed
	sprite.flip_h = velocity.x < 0

	# Apply gravity
	if not is_on_floor():
		velocity.y += gravity * _delta
	else:
		velocity.y = 0
		
	# simple back-and-forth
#	if is_on_wall():
#		direction *= -1

	move_and_slide()

	# Turn around at walls OR ledges - never walk off an edge during normal patrol
	if is_on_wall() or (avoid_ledges and is_on_floor() and is_ledge_ahead(20.0, direction)):
		direction *= -1
