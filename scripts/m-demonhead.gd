extends Monster
class_name Demonhead

var gravity = GameConfig.monsterdata.demonhead.gravity

#SIGNAL-demonhead-1 Define the signal with parameters able to destroy a block when hit
signal wall_impact(pos: Vector2, dir: int)

var hitbox: Area2D 

func _ready():
	family = "demonhead"
	add_to_group("monsters") 
	super._ready()
	
	direction = 1

	hitbox = get_node_or_null("HitBox")
	_setup_hitbox()

#	print("Demonhead layer:", collision_layer, " mask: ", collision_mask)
	# Ghost HitBox
	collision_layer = 4   # (or anything, not important)
	collision_mask = 1    # must match Player layer	


func _physics_process(_delta):

	behave(_delta) # includes move_and_slide()

###DEBUG mega debug demonhead double collision
#	if get_slide_collision_count() > 0:
#		var c = get_slide_collision(0)
#		var collider = c.get_collider()
#		print("[DH] frame=", Engine.get_physics_frames(),
#			" pos=", global_position,
#			" dir=", direction,
#			" vel=", velocity,
#			" on_wall=", is_on_wall(),
#			" on_floor=", is_on_floor(),
#			" collider=", (collider.name if collider else "null"),
#			" collider_global=", (collider.global_position if collider else "n/a"),
#			" grid_pos=", (collider.get_meta("grid_pos") if collider and collider.has_meta("grid_pos") else "none"),
#			" dist=", (global_position.distance_to(collider.global_position) if collider else -1))


	if is_on_wall():

		#SIGNAL-demonhead-2 Emit the signal instead of calling a parent method directly
		_base_destroy_block_ahead()
		# Hit something without grid metadata (not a registered block) -
		# fall back to the old signal path, harmless no-op for non-blocks.
		wall_impact.emit(global_position, direction)

		direction *= -1


#func _destroy_block_ahead():
#	if get_slide_collision_count() > 0:
#		var collider = get_slide_collision(0).get_collider()
#		if collider and collider.is_in_group("blockgroup") and collider.has_meta("grid_pos"):
#			var loader = get_parent()
#			loader.destroy_block_at(collider.get_meta("grid_pos"))
#			return

#	# Hit something without grid metadata (not a registered block) -
#	# fall back to the old signal path, harmless no-op for non-blocks.
#	wall_impact.emit(global_position, direction)

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
	velocity.x = 2 * direction * GameConfig.monsterdata[family].speed

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
