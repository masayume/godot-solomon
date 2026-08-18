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

# --- Crawling (Spark-style) ---
var crawl_dir: int = 1              # 1 = forward, -1 = backward along the surface
var is_turning: bool = false
var turn_duration: float = 0.25
const CRAWL_PROBE_DIST := 26.0      # center-to-surface distance while crawling (tune to sprite size)
const CRAWL_LOOKAHEAD := 36.0       # how far ahead to look for corners
const CRAWL_REACH := 38.0           # how far rays reach to find a surface
const CRAWL_ADHESION := 15.0        # pull toward the surface

# NEW: If true, it flies straight and ignores crawling logic
var is_monster_projectile: bool = false 

@onready var ray_front = $RayFront
@onready var ray_down = $RayDown

@onready var sprite: Sprite2D = $Sprite2D
var _burn_tween: Tween
var lifetime: float = 1.0  # seconds the crawling fireball lives

func _ready():
	
	_apply_projectile_data()
	print("fireball ready: family=", family, " loader=", loader)	
	# Connect to detect monsters
	
	collision_mask = 1 | 2 | 4 # Look for Layer 1 (World) Layer 2 (Player) and 3 (Monsters)
	
	area_entered.connect(_on_area_entered)
	body_entered.connect(_on_body_entered)

	_start_burn_effect()
	if is_crawling and GameConfig.fb_duration:
#		var duration = GameConfig.projectiledata["fireball"].get("duration")
		print("fireball duration: ", GameConfig.fb_duration)
		get_tree().create_timer(GameConfig.fb_duration).timeout.connect(explode)	
	else:
		print("fireball duration: ", GameConfig.fb_duration)
		get_tree().create_timer(lifetime).timeout.connect(explode)

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
	# Standing/jumping shots and monster projectiles fly straight, no raycasts
	if is_monster_projectile or not is_crawling:
		velocity_y += gravity * delta
		position += direction * speed * delta + Vector2(0, velocity_y) * delta
		return
	
	# Crouching shot → crawl along surfaces like the Spark
	_crawl(delta)


func _crawl(delta):
	if is_turning:
		return
	
	var local_forward = Vector2.RIGHT.rotated(rotation) * crawl_dir
	var local_down    = Vector2.DOWN.rotated(rotation)
	
	# --- 1. ATTACHMENT: not on a surface yet → fall forward until we find one ---
	var grounded = _surface_hit(global_position, local_down, CRAWL_REACH)
	if not grounded:
		velocity_y += gravity * delta
		position += local_forward * speed * delta + Vector2(0, velocity_y) * delta
		if _surface_hit(global_position, local_down, CRAWL_REACH):
			_snap_to_surface(local_down)
		return
	
	# --- 2. CONCAVE corner (wall directly ahead) → turn up ---
	if _surface_hit(global_position, local_forward, CRAWL_LOOKAHEAD):
		rotation -= (PI / 2.0) * crawl_dir
		var new_down = Vector2.DOWN.rotated(rotation)
		global_position += new_down * (CRAWL_LOOKAHEAD - CRAWL_PROBE_DIST)
		return
	
	# --- 3. CONVEX corner (floor drops off ahead) → turn down around the edge ---
	var front_edge  = global_position + local_forward * CRAWL_LOOKAHEAD
	var floor_ahead = _surface_hit(front_edge, local_down, CRAWL_REACH)
	if not floor_ahead:
		is_turning = true
		var target_rotation = rotation + (PI / 2.0) * crawl_dir
		var new_down        = Vector2.DOWN.rotated(target_rotation)
		var target_position = global_position + local_forward * CRAWL_LOOKAHEAD + new_down * 4.0
		var tween = create_tween()
		tween.set_parallel(true)
		tween.tween_property(self, "global_position", target_position, turn_duration)
		tween.tween_property(self, "rotation", target_rotation, turn_duration)
		tween.chain().tween_callback(func(): is_turning = false)
		return
	
	# --- 4. CRAWL along the surface with adhesion ---
	var move = local_forward * speed + local_down * CRAWL_ADHESION
	position += move * delta
	_snap_to_surface(local_down)


# Casts a ray against the world layer (blocks) and returns true if it hits
func _surface_hit(origin: Vector2, dir: Vector2, distance: float) -> bool:
	var space_state = get_world_2d().direct_space_state
	var query = PhysicsRayQueryParameters2D.create(origin, origin + dir * distance)
	query.exclude = [self]
	query.collision_mask = 1          # blocks/world layer
	var result = space_state.intersect_ray(query)
	return not result.is_empty()


# Snaps the fireball's center to exactly CRAWL_PROBE_DIST away from the surface
func _snap_to_surface(local_down: Vector2):
	var space_state = get_world_2d().direct_space_state
	var query = PhysicsRayQueryParameters2D.create(global_position, global_position + local_down * CRAWL_REACH)
	query.exclude = [self]
	query.collision_mask = 1
	var result = space_state.intersect_ray(query)
	if result:
		global_position = result.position - local_down * CRAWL_PROBE_DIST
		
func _physics_process2DEL(delta):

	# 1. Move the fireball
	# velocity_y stays 0 for gravity=0 projectiles (e.g. fireball), so this
	# is identical to the old `position += direction * speed * delta` then.
	velocity_y += gravity * delta
	position += direction * speed * delta + Vector2(0, velocity_y) * delta
		
	# 2. SURFACE DETECTION (ONLY for player fireballs)
	if not is_monster_projectile and is_crawling:
	# If we aren't crawling yet, look for the first wall
		if not is_crawling:
			if ray_front.is_colliding():
				is_crawling = true
				_align_to_surface(ray_front.get_collision_normal())
			elif ray_down.is_colliding():
				# NEW: If we hit the floor, start crawling immediately
				is_crawling = true 
		else:
			# EDGE FOLLOWING LOGIC (Only runs once we are on a surface)

			# --- FIX: Ensure it's actually attached to a surface ---
			# If we are falling through the air, both rays will be false. 
			# We don't want to rotate if we're just falling!
			var is_attached = ray_front.is_colliding() or ray_down.is_colliding()

			if is_attached:
				if ray_front.is_colliding():
					# Case A: Hit a wall in front -> Rotate UP
					_align_to_surface(ray_front.get_collision_normal())
				elif not ray_down.is_colliding():
					# Case B: Lost the floor -> Rotate DOWN around the corner
					direction = Vector2(-direction.y, direction.x) 
					rotation = direction.angle()
					# Snap position slightly forward so ray_down hits the side of the new tile
					position += direction * 5
								
#			if ray_front.is_colliding():
#			# Case A: Hit a wall in front -> Rotate UP
#				_align_to_surface(ray_front.get_collision_normal())
#			
#			elif not ray_down.is_colliding():
#				# Case B: Lost the floor -> Rotate DOWN around the corner
#				# We rotate clockwise to "wrap" around the tile
#				direction = Vector2(-direction.y, direction.x) 
#				rotation = direction.angle()
#				# Snap position slightly forward so ray_down hits the side of the new tile
#				position += direction * 5
			
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
	if body.has_method("trigger_death_from_monster"):
		body.trigger_death_from_monster()

	# ── CRAWLING: ignore block collisions entirely ──
	# The fireball is supposed to crawl along blocks, not explode on them
	if is_crawling and body.is_in_group("blockgroup"):
		return

	# ── block hit (only for straight-flying fireballs) ──
	if body.is_in_group("blockgroup"):
		var bfamily = body.get("family")
		var bdata = GameConfig.blockdata.get(bfamily, {})
		var is_destructible = bdata.get("destructible", false)
		var contact_pos = global_position

		if body.has_meta("grid_pos") and loader:
			var cell = body.get_meta("grid_pos")
			var local_pos = GameConfig.grid_to_local(cell.x, cell.y, loader.tile_size, loader.x_off, loader.y_off)
			contact_pos = loader.to_global(local_pos)

		if is_destructible:
			if loader:
				loader.remove_block_node(body)
			explode(contact_pos)
		else:
			explode(contact_pos)
		return

	if body.is_in_group("monsters") and body.has_method("take_damage"):
		body.take_damage()
		explode()
		return
		
func _on_body_entered2DEL(body):

###DEBUG_3l instance name, class, groups (is_in_group)
	print("fireball hits: ", body.name, " type: ", body.get_class())
	print("body groups: ", body.get_groups())  # <-- ADD THIS LINE
	print("is in 'blocks' group: ", body.is_in_group("blockgroup"))
	
#	print("fireball hits: ", body)
	if body.has_method("trigger_death_from_monster"):
		body.trigger_death_from_monster()	

	# ── block hit ─────────────────────────────────────────────────────────
	if body.is_in_group("blockgroup"):
#		print("block hit by fireball")
		var bfamily = body.get("family")
		var bdata = GameConfig.blockdata.get(bfamily, {})
		var is_destructible = bdata.get("destructible", false)

		var contact_pos = global_position  # fallback if no grid_pos found

###DEBUG fireball expoding position
#		print("EXPLODE dir=", direction, " has_grid_meta=", body.has_meta("grid_pos"),
#		" cell=", (body.get_meta("grid_pos") if body.has_meta("grid_pos") else "n/a"),
#		" contact_pos=", contact_pos, " fireball_pos=", global_position)
				
		if body.has_meta("grid_pos") and loader:
			var cell = body.get_meta("grid_pos")
			var local_pos = GameConfig.grid_to_local(cell.x, cell.y, loader.tile_size, loader.x_off, loader.y_off)
	
			contact_pos = loader.to_global(local_pos)

		if is_destructible:
			if loader:
				loader.remove_block_node(body)
			explode(contact_pos)
		else:
			explode(contact_pos)  # bounce/hit fx at the block's true position, don't destroy it
		return


	if body.is_in_group("monsters") and body.has_method("take_damage"):
		body.take_damage()
		explode()
		return

	# 
	if body.is_in_group("monsters") and body.has_method("take_damage"):
		body.take_damage()
		explode()
		return
		
	# If we hit something we can't climb (like a solid door)
	if not body.is_in_group("blockgroup"):
		explode()

func explode(explosion_pos: Vector2 = global_position):
	if loader:
		loader.spawn_fx("boom", explosion_pos, Vector2i(-1,-1), false)
	else:
		get_parent().spawn_fx("boom", explosion_pos, Vector2i(-1,-1), false)

#	if loader:
#		var local_pos = loader.to_local(explosion_pos)
#		loader.spawn_fx("boom", local_pos, Vector2i(-1,-1), false)
#	else:
#		var local_pos = get_parent().to_local(explosion_pos)
#		get_parent().spawn_fx("boom", local_pos, Vector2i(-1,-1), false)

	queue_free()

#	var local_pos = get_parent().to_local(explosion_pos)
#	get_parent().spawn_fx("boom", local_pos, Vector2i(-1,-1), false)
	
#	queue_free()
	
