extends Monster
class_name Goblin

# DESCRIPTION
# State machine: (PATROL → CHARGING → PUNCHING → back to PATROL)
# A forward raycast to detect a block or the Player within range 
# 	(reusing the same raycast pattern as is_ledge_ahead() in monster.gd)

# var direction := -1
var gravity = GameConfig.monsterdata.goblin.gravity

var fall_start_y: float = 0.0
var was_on_floor: bool = true

#SIGNAL-goblin-1 Define the signal with parameters able to destroy a block when hit
signal wall_impact(pos: Vector2, dir: int)

var hitbox: Area2D 

# Punching Logic
@export var punching_time: float = 0.8        # seconds spent winding up before breathing fire
@export var punching_cooldown: float = 2.5    # seconds before it can charge again after breathing

# -- Goblin state machine -------------------
enum GoblinState { PATROL, CHARGING, PUNCHING, FALLING }
var goblin_state: GoblinState = GoblinState.PATROL

func _ready():
	family = "goblin"
	add_to_group("monsters") 
	super._ready()

	detect_range = GameConfig.monsterdata[family].detect_range
		
	hitbox = get_node_or_null("HitBox")
	_setup_hitbox()

	# 3. SAFELY get gravity from the loaded stats, falling back to the default if missing
#	gravity = stats.get("gravity", gravity)
		
#	print("Goblin layer:", collision_layer, " mask: ", collision_mask)
	# Ghost HitBox
	collision_layer = 4   # (or anything, not important)
	collision_mask = 1    # must match Player layer	

	if stats.get("direction") == "left":
		direction = 1
	elif stats.get("direction") == "right":
		direction = -1

	state_animation_finished.connect(_on_state_animation_finished)		

func _physics_process(_delta):

	if not is_falling_to_death:
		if was_on_floor and not is_on_floor():
			fall_start_y = global_position.y   # mark where the fall began
		was_on_floor = is_on_floor()

		if not is_on_floor() and global_position.y - fall_start_y > tile_size * 1.5:
			start_fall_death()
			return

	match goblin_state:
		GoblinState.PATROL:
			_process_patrol(_delta)
		GoblinState.PUNCHING:
			_process_punching(_delta)
		GoblinState.CHARGING:
			_process_charging(_delta)
		GoblinState.FALLING:
			_process_falling(_delta)
			
#	velocity.x = direction * GameConfig.monsterdata.goblin.speed

func _process_patrol(_delta):

	behave(_delta) # includes move_and_slide()

	var ledge_ahead = avoid_ledges and is_on_floor() and is_ledge_ahead(30.0, direction)

	if is_on_wall() or ledge_ahead:
		#SIGNAL-goblin-2 emits defined signal when it hits the wall
		# Pass the goblin's own position (like the player's cast does).
		# create_or_destroy_block() already steps one tile forward in
		# `dir` to find the target cell, so pre-shifting here caused a
		# double offset that overshot past the actual block.
		if is_on_wall():
			wall_impact.emit(global_position, direction)
		direction *= -1
		sprite.flip_h = direction < 0   # keep sprite in sync with direction, same frame
		return # don't also start a charge the same frame we bounced off a wall

	if is_on_floor() and _target_ahead():
		_start_charge()

func _start_charge():
	goblin_state = GoblinState.CHARGING
	change_state("goblin_charging")
	
func _process_charging(_delta):

	velocity.x = direction * GameConfig.monsterdata.goblin.speed * 3

	_apply_gravity(_delta)
	move_and_slide()

	if is_on_wall():
		_start_punch()
		return

	if is_on_floor() and avoid_ledges and is_ledge_ahead(30.0, direction):
		goblin_state = GoblinState.PATROL
		direction *= -1
		sprite.flip_h = direction < 0
		change_state("goblin")
		
func _start_punch():
	goblin_state = GoblinState.PUNCHING
	change_state("goblin_punching")

	# Land the punch right as the pose starts. If the block ahead isn't
	# destructible, whatever handles wall_impact on the receiving end
	# just won't destroy it - same as the normal patrol bounce.
	wall_impact.emit(global_position, direction)

func _process_punching(_delta):
	velocity.x = 0
	_apply_gravity(_delta)
	move_and_slide()
  
	# destroy block 

func _process_falling(_delta):
	velocity.x = 0
	goblin_state = GoblinState.FALLING
	change_state("goblin_falling")  # add this state to monster.cfg,
  
	# destroy block 
	 
func _apply_gravity(_delta):
	if not is_on_floor():
		velocity.y += gravity * _delta
	else:
		velocity.y = 0

func _on_state_animation_finished(state_name: String):
	if state_name == "goblin_punching":
		goblin_state = GoblinState.PATROL
		direction *= -1   # turn away from what it just punched
#		cooldown_timer = breath_cooldown
		change_state("goblin")
		
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

	_apply_gravity(_delta)
	move_and_slide()
