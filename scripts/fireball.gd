extends Area2D

# DESCRIPTION
# handles both block-destruction and player-kill via is_monster_projectile, 
# the blockgroup check, and trigger_death_from_monster(). 
# Pannel's _attempt_shoot() is basically the template to follow for the Dragon's breath as well
#

var loader : Node = null

# Which entry in projectiles.cfg this instance uses. Set this right after
# instantiate() (before add_child) to pick a different projectile type -
# e.g. fb.family = "rock" - without needing a different scene.
@export var family: String = "fireball"
 
@export var speed: float = 300.0
var direction = Vector2.RIGHT # Initial direction
var explosion_fx: String = "boom"   # which fx.cfg entry to spawn on impact 
var velocity_y: float = 0.0   # vertical speed accumulated from gravity

# Track if it touched a surface yet
var is_crawling: bool = false 

# NEW: If true, it flies straight and ignores crawling logic
var is_monster_projectile: bool = false 

@onready var ray_front = $RayFront
@onready var ray_down = $RayDown

@onready var sprite: Sprite2D = $Sprite2D
var _burn_tween: Tween

func _ready():
	
	_apply_projectile_data()
	
	# Connect to detect monsters
	
	collision_mask = 1 | 2 | 4 # Look for Layer 1 (World) Layer 2 (Player) and 3 (Monsters)
	
	area_entered.connect(_on_area_entered)
	body_entered.connect(_on_body_entered)

	_start_burn_effect()


## Pulls this projectile's stats/appearance from projectiles.cfg (via
## GameConfig.projectiledata), keyed by `family`. Any @export default above
## is used as a fallback if the cfg is missing a key, so this stays safe
## even for an unrecognized family.
func _apply_projectile_data():
	var data = GameConfig.projectiledata.get(family, {})
	if data.is_empty():
		push_warning("Projectile family '%s' not found in projectiles.cfg" % family)
		return
 
	speed = data.get("speed", speed)
	gravity = data.get("gravity", gravity)
	explosion_fx = data.get("explosion_fx", explosion_fx)
 
	if data.has("sprite"):
		var tex = load(data["sprite"])
		if tex:
			sprite.texture = tex
 
	sprite.scale = Vector2(data.get("scalex", 1.0), data.get("scaley", 1.0))
 

func _start_burn_effect():
	_burn_tween = create_tween()
	_burn_tween.set_loops()  # infinite loop

	# Random scale flicker every 120 ms - feels like an unstable flame 
	_burn_tween.tween_method(_apply_random_scale, 0.0, 1.0, 0.120)
	_burn_tween.tween_callback(func(): pass)  # placeholder to keep the loop ticking

func _apply_random_scale(_t: float):
	var s = randf_range(0.75, 1.25)
	sprite.scale = Vector2(s, s)
	
		
func _physics_process(delta):
	# 1. Move the fireball

	# velocity_y stays 0 for gravity=0 projectiles (e.g. fireball), so this
	# is identical to the old `position += direction * speed * delta` then.
	velocity_y += gravity * delta
	position += direction * speed * delta + Vector2(0, velocity_y) * delta
		
	# 2. SURFACE DETECTION (ONLY for player fireballs)
	if not is_monster_projectile:
	# If we aren't crawling yet, look for the first wall
		if not is_crawling:
			if ray_front.is_colliding():
				is_crawling = true
				_align_to_surface(ray_front.get_collision_normal())
		else:
			# EDGE FOLLOWING LOGIC (Only runs once we are on a surface)
			if ray_front.is_colliding():
			# Case A: Hit a wall in front -> Rotate UP
				_align_to_surface(ray_front.get_collision_normal())
			
			elif not ray_down.is_colliding():
				# Case B: Lost the floor -> Rotate DOWN around the corner
				# We rotate clockwise to "wrap" around the tile
				direction = Vector2(-direction.y, direction.x) 
				rotation = direction.angle()
				# Snap position slightly forward so ray_down hits the side of the new tile
				position += direction * 5
			
func _align_to_surface(normal: Vector2):
	# Align movement direction parallel to the surface normal
	direction = Vector2(normal.y, -normal.x) 
	rotation = direction.angle()
	
func _on_area_entered(area):

###DEBUG fireball hit
	print("fireball area_entered: ", area.name, " owner=", area.get_parent().name, " groups=", area.get_parent().get_groups())

	var target = area
	# Check if the area itself or its parent is a monster
	if not target.is_in_group("monsters"):
		target = area.get_parent()
#		print("Hit by fireball: ", target)
		
	if target.is_in_group("monsters") and target.has_method("take_damage"):
		target.take_damage()
		explode()

func _on_body_entered(body):

###DEBUG_3l instance name, class, groups (is_in_group)
	print("fireball hits: ", body.name, " type: ", body.get_class())
	print("body groups: ", body.get_groups())  # <-- ADD THIS LINE
	print("is in 'blocks' group: ", body.is_in_group("blockgroup"))
	
#	print("fireball hits: ", body)
	if body.has_method("trigger_death_from_monster"):
		body.trigger_death_from_monster()	

	# ── block hit ─────────────────────────────────────────────────────────
	if body.is_in_group("blockgroup"):
		print("block hit by fireball")
		var family = body.get("family")
		if family and GameConfig.blockdata.has(family):
			if GameConfig.blockdata[family]["destructible"]:
				# Tell the level loader to remove it
				if loader:
					loader.remove_block_node(body)
#				explode(body.global_position)
				# Offset toward the block from the fireball's current position
				var contact_pos = global_position + (body.global_position - global_position) * 0.5
				explode(contact_pos)
				return
			# else: indestructible - fireball bounces/crawls, don't explode
			else:
				explode(global_position)	

	# 
	if body.is_in_group("monsters") and body.has_method("take_damage"):
		body.take_damage()
		explode()
		return
		
	# If we hit something we can't climb (like a solid door)
	if not body.is_in_group("blockgroup"):
		explode()

func explode(explosion_pos: Vector2 = global_position):
	var local_pos = get_parent().to_local(explosion_pos)
	get_parent().spawn_fx("boom", local_pos, Vector2i(-1,-1), false)
	
	queue_free()
	
