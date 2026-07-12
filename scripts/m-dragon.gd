extends Monster
class_name Dragon

# DESCRIPTION
# State machine: (PATROL → CHARGING → BREATHING → back to PATROL)
# A forward raycast to detect a block or the Player within range 
# 	(reusing the same raycast pattern as is_ledge_ahead() in monster.gd)

var direction := -1
var gravity = GameConfig.monsterdata.dragon.gravity

var fall_start_y: float = 0.0
var was_on_floor: bool = true

var hitbox: Area2D 

# Fireball Logic
@export var fireball_scene: PackedScene
@export var detect_range: float = 220.0     # how far ahead the Dragon can "see"
@export var charge_time: float = 0.8        # seconds spent winding up before breathing fire
@export var breath_cooldown: float = 2.5    # seconds before it can charge again after breathing

#SIGNAL-dragon-1 Define the signal with parameters able to destroy a block when hit
signal wall_impact(pos: Vector2, dir: int)

# -- Fire breath state machine -------------------
enum BreathState { PATROL, CHARGING, BREATHING }
var breath_state: BreathState = BreathState.PATROL

var charge_timer: float = 0.0
var cooldown_timer: float = 0.0

func _ready():
	family = "dragon"
	add_to_group("monsters") 
	super._ready()
	
	hitbox = get_node_or_null("HitBox")
	_setup_hitbox()
	
#	print("Dragon layer:", collision_layer, " mask: ", collision_mask)
	# Dragon HitBox
	collision_layer = 4   # (or anything, not important)
	collision_mask = 1    # must match Player layer	
	
	state_animation_finished.connect(_on_state_animation_finished)


func _physics_process(_delta):

	if not is_falling_to_death:
		if was_on_floor and not is_on_floor():
			fall_start_y = global_position.y   # mark where the fall began
		was_on_floor = is_on_floor()

		if not is_on_floor() and global_position.y - fall_start_y > tile_size * 1.5:
			start_fall_death()
			return

	match breath_state:
		BreathState.PATROL:
			_process_patrol(_delta)
		BreathState.CHARGING:
			_process_charging(_delta)
		BreathState.BREATHING:
			_process_breathing(_delta)
			
			
#	velocity.x = direction * GameConfig.monsterdata.dragon.speed

#	behave(_delta) # includes move_and_slide()

###DEBUG
#	print("on_wall=", is_on_wall(), " slides=", get_slide_collision_count(),
#		" my_layer=", collision_layer, " my_mask=", collision_mask,
#		" collider_disabled=", collider.disabled)
#	for i in get_slide_collision_count():
#		var c = get_slide_collision(i)
#		print("  -> hit:", c.get_collider().name, " layer=", c.get_collider().collision_layer)

func _process_patrol(_delta):
	if cooldown_timer > 0:
		cooldown_timer -= _delta

	behave(_delta) # includes move_and_slide()

	if is_on_wall():
		#SIGNAL-dragon-2 emits defined signal when it hits the wall
		# Pass the Dragon's own position (like the player's cast does).
		# create_or_destroy_block() already steps one tile forward in
		# `dir` to find the target cell, so pre-shifting here caused a
		# double offset that overshot past the actual block.
		wall_impact.emit(global_position, direction)
		direction *= -1
		return # don't also start a charge the same frame we bounced off a wall
	
#		var probe_pos = global_position + Vector2(direction * tile_size * 0.5, 0)
#		wall_impact.emit(probe_pos, direction)
#		direction *= -1

	# Look for a block or the Player straight ahead; wind up a fire breath
	if cooldown_timer <= 0 and is_on_floor() and _target_ahead():
		_start_charge()

func _process_charging(_delta):
	velocity.x = 0
	_apply_gravity(_delta)
	move_and_slide()
 
	charge_timer -= _delta
	if charge_timer <= 0:
		_breathe_fire()
 
func _process_breathing(_delta):
	velocity.x = 0
	_apply_gravity(_delta)
	move_and_slide()
	# Returns to PATROL automatically once the "dragon_breath" animation
	# finishes - see _on_state_animation_finished() below.

func _apply_gravity(_delta):
	if not is_on_floor():
		velocity.y += gravity * _delta
	else:
		velocity.y = 0

func _start_charge():
	breath_state = BreathState.CHARGING
	charge_timer = charge_time
	change_state("dragon_charge")  # add this state to monster.cfg (see notes)


 
func _breathe_fire():
	breath_state = BreathState.BREATHING
	change_state("dragon_breath")  # add this state to monster.cfg, loop = false
 
	if not fireball_scene:
		push_warning("Dragon '%s' has no fireball_scene assigned - can't breathe fire!" % name)
		return
 
	var fb = fireball_scene.instantiate()
 
	# Fly straight, ignore the player-fireball crawl/surface logic
	fb.is_monster_projectile = true
	fb.loader = get_tree().get_first_node_in_group("level_loader")
 
	var shoot_dir = Vector2(direction, 0)
	var spawn_distance = 40.0  # tweak to match the Dragon's mouth/sprite pivot
	fb.global_position = global_position + shoot_dir * spawn_distance
	fb.direction = shoot_dir
	fb.rotation = shoot_dir.angle()
 
	# Add to the level (not to the Dragon) so it doesn't move with it
	get_parent().add_child(fb)


func _on_state_animation_finished(state_name: String):
	if state_name == "dragon_breath":
		breath_state = BreathState.PATROL
		cooldown_timer = breath_cooldown
		
## Raycasts straight ahead of the Dragon looking for a destructible block or
## the Player, so it knows when to stop and charge up its fire breath.
func _target_ahead() -> bool:
	var space_state = get_world_2d().direct_space_state
	var origin = global_position
	var target = origin + Vector2(direction * detect_range, 0)
 
	var query = PhysicsRayQueryParameters2D.create(origin, target)
	query.collision_mask = 1 | 2  # Walls/blocks (Layer 1) + Player (Layer 2)
	query.exclude = [self]
 
	var result = space_state.intersect_ray(query)
	if result.is_empty():
		return false
 
	var body = result.collider
	return body.is_in_group("blockgroup") or body.has_method("trigger_death_from_monster")
 
		
		
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
#	print("Dragon hit body:", body)
	if body.has_method("trigger_death_from_monster"):
		body.trigger_death_from_monster()

func behave(_delta):
	velocity.x = direction * GameConfig.monsterdata[family].speed

	sprite.flip_h = velocity.x < 0

	_apply_gravity(_delta)

	move_and_slide()

	# Turn around at walls OR ledges - never walk off an edge during normal patrol
#	if is_on_wall() or (avoid_ledges and is_on_floor() and is_ledge_ahead(20.0, direction)):
#		direction *= -1

#	var wall = is_on_wall()
	var ledge = avoid_ledges and is_on_floor() and is_ledge_ahead(20.0, direction)

	if ledge:
		direction *= -1
