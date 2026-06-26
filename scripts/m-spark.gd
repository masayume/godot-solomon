extends Monster
class_name Spark

var direction := -1

var current_surface: String = "bottom"

var gravity = GameConfig.monsterdata.spark.gravity

var hitbox: Area2D 

var airborne_time: float = 0.0
const MAX_AIRBORNE_BEFORE_FLY_STRAIGHT := 0.12  # seconds with no floor before giving up on corner-snapping

# We'll use this to handle rotation based on surface
var surface_normals = {
	"bottom": Vector2.UP,
	"top": Vector2.DOWN,
	"left": Vector2.RIGHT,
	"right": Vector2.LEFT
}

const PROBE_DIST := 26.0
const SHORT_PROBE := 10.0   # tight distance to avoid hitting unrelated nearby blocks

var last_floor_position: Vector2 = Vector2.ZERO

func _ready():
	family = "spark"
	add_to_group("monsters") 
	super._ready()

	z_index = 30
	# Initial rotation based on the starting surface
#	rotation = surface_normals[current_surface].angle() + PI/2
	rotation = surface_normals[current_surface].angle() - PI/2   # flip sign of the offset

	# Force visibility of collision for this specific instance
	# if you want to be 100% sure during debug
	if get_node_or_null("CollisionShape2D"):
		get_node("CollisionShape2D").visible = true

	hitbox = get_node_or_null("HitBox")
	_setup_hitbox()

	print("Spark layer:", collision_layer, " mask: ", collision_mask)
	# Ghost HitBox
	collision_layer = 4   # (or anything, not important)
	collision_mask = 1    # must match Player layer	

	# Run this once, e.g. in Spark's _ready() after a short delay, or via a button
	var loader = get_tree().get_first_node_in_group("level_loader")

	var block_world_pos = GameConfig.grid_to_local(4, 10, loader.tile_size, loader.x_off, loader.y_off)
	print("[GRID CHECK] block[4,10] world center=", block_world_pos)

	var cell = GameConfig.world_to_grid(Vector2(-42.92522, -150.0), loader.x_off, loader.y_off, loader.tile_size)
	print("[WHAT BLOCK] Spark crawling position resolves to cell=", cell)

	for row in range(6, 12):
		var wpos = GameConfig.grid_to_local(4, row, loader.tile_size, loader.x_off, loader.y_off)
		cell = Vector2i(4, row)
		print("[BLOCK CHECK](col 4) cell=", cell, " world=", wpos, " has_block=", loader.blocks.has(cell))

	for row in range(6, 12):
		cell = Vector2i(3, row)
		print("[BLOCK CHECK](col 3) cell=", cell, " has_block=", loader.blocks.has(cell))

	var cell_here = GameConfig.world_to_grid(Vector2(-85.00317, -127.0), loader.x_off, loader.y_off, loader.tile_size)
	print("[WHAT IS BELOW] world_y=-127 resolves to cell=", cell_here, " has_block=", loader.blocks.has(cell_here))
		
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

func _physics_process(_delta):
	behave(_delta) # includes move_and_slide()

func behave(_delta):
	
	print("[VELOCITY-CHECK] rotation=", rad_to_deg(rotation), " move_dir=", Vector2.RIGHT.rotated(rotation), " velocity=", velocity, " direction=", direction)

	up_direction = surface_normals.get(current_surface, Vector2.UP)
	var move_dir = Vector2.RIGHT.rotated(rotation)

	print("[SPEED-CHECK] speed=", GameConfig.monsterdata[family].speed, " move_dir=", move_dir, " direction=", direction, " product=", move_dir * direction * GameConfig.monsterdata[family].speed)

	velocity = move_dir * direction * GameConfig.monsterdata[family].speed
	move_and_slide()

	if get_slide_collision_count() > 0:
		for i in range(get_slide_collision_count()):
			var col = get_slide_collision(i)
			print("[COLLISION] collider=", col.get_collider(), " normal=", col.get_normal(), " position=", col.get_position())
		
	var ahead_dir = move_dir * direction
	var concave_hit = _raycast_from(global_position, ahead_dir, SHORT_PROBE)
#	var concave_hit = _is_wall_ahead(ahead_dir)
	if concave_hit:

		print("[CONCAVE] pos=", global_position, " surface_before=", current_surface,
			  " rotation_before=", rad_to_deg(rotation), " ahead_dir=", ahead_dir)

		rotation += PI/2 * direction
		_update_current_surface()
		global_position -= ahead_dir * 8.0

		print("[CONCAVE] surface_after=", current_surface, " rotation_after=", rad_to_deg(rotation))
		
#		return
		pass

#	var still_attached = _is_still_attached()
	var still_attached = _raycast_from(global_position, -up_direction, PROBE_DIST)

#	print("[ATTACH] surface=", current_surface, " up_direction=", up_direction, " probe_dir=", -up_direction, " attached=", still_attached)
	print("[ATTACH] pos=", global_position, " surface=", current_surface, " attached=", still_attached)

	if still_attached:
		return # Still crawling normally, nothing to do

#	print("[STOP-CONVEX-CHECK] pos=", global_position, " surface=", current_surface, " still_attached=", still_attached)

	var turn = -PI/2 * direction
	var prospective_rotation = rotation + turn
	var prospective_surface = _surface_for_rotation(prospective_rotation)
	var prospective_normal = surface_normals[prospective_surface]

	var found = false
	var trial_pos = global_position
	for step_dir in [-up_direction, up_direction]:
		var candidate_pos = global_position + step_dir * PROBE_DIST
		if _raycast_from(candidate_pos, prospective_normal, SHORT_PROBE):
			found = true
			trial_pos = candidate_pos
			break

	print("[CONVEX-CHECK] pos=", global_position, " surface=", current_surface,
		  " prospective_surface=", prospective_surface, " found=", found)

	if found:
		rotation = prospective_rotation
		current_surface = prospective_surface
		global_position = trial_pos
#		direction *= -1   # ADD THIS — convex wrap reverses effective travel direction		
		print("[TURN-CONVEX] surface=", current_surface, " rotation=", rad_to_deg(rotation), " direction=", direction, " move_dir_after=", Vector2.RIGHT.rotated(rotation))
		pass
	else:
		velocity.y += gravity * _delta

func _is_wall_ahead(ahead_dir: Vector2) -> bool:
	if _raycast_from(global_position, ahead_dir, SHORT_PROBE):
		return true
	if _raycast_from(global_position, -ahead_dir, SHORT_PROBE):
		return true
	return false
	
func behave2DEL(_delta):
	up_direction = surface_normals.get(current_surface, Vector2.UP)
	var move_dir = Vector2.RIGHT.rotated(rotation)
	velocity = move_dir * direction * GameConfig.monsterdata[family].speed
	move_and_slide()

	# ── 1. Concave corner: wall directly ahead in travel direction ──────────
	var ahead_dir = move_dir * direction
	var concave_hit = _raycast_from(global_position, ahead_dir, SHORT_PROBE)
	print("[CONCAVE] pos=", global_position, " surface=", current_surface,
		  " ahead_dir=", ahead_dir, " hit=", concave_hit)

	if concave_hit:
		rotation += PI/2 * direction
		_update_current_surface()
		global_position -= ahead_dir * 8.0
		print("[CONCAVE TURN] new_rotation=", rad_to_deg(rotation), " new_surface=", current_surface)
		return
			
	if _raycast_from(global_position, ahead_dir, SHORT_PROBE):
		rotation += PI/2 * direction
		_update_current_surface()
		global_position -= ahead_dir * 4.0
		return  # handled this frame, don't also check convex

	# ── 2. Convex corner: current wall no longer found right next to us ────
	var still_attached = _raycast_from(global_position, -up_direction, PROBE_DIST)
	if still_attached:
		return  # still crawling normally, nothing to do

	var turn = -PI/2 * direction
	var prospective_rotation = rotation + turn
	var prospective_surface = _surface_for_rotation(prospective_rotation)
	var prospective_normal = surface_normals[prospective_surface]

	var found = false
	var trial_pos = global_position

	for step_dir in [-up_direction, up_direction]:
		var candidate_pos = global_position + step_dir * PROBE_DIST
		if _raycast_from(candidate_pos, prospective_normal, SHORT_PROBE):
			found = true
			trial_pos = candidate_pos
			break

	if found:
		rotation = prospective_rotation
		current_surface = prospective_surface
		global_position = trial_pos
	else:
		velocity.y += gravity * _delta


func _raycast_from(origin: Vector2, dir: Vector2, distance: float) -> bool:
	var space_state = get_world_2d().direct_space_state
	var query = PhysicsRayQueryParameters2D.create(origin, origin + dir * distance)
	query.exclude = [self]
	query.collision_mask = 1
	var result = space_state.intersect_ray(query)
	return not result.is_empty()

func _is_still_attached() -> bool:
	# Try both perpendicular directions — whichever finds a wall is correct.
	# This avoids relying on surface_normals' sign convention, which has
	# proven unreliable to reason about directly.
	var hit_down = _raycast_from(global_position, up_direction, PROBE_DIST)
	var hit_up = _raycast_from(global_position, -up_direction, PROBE_DIST)
	print("[ATTACH-DETAIL] pos=", global_position, " probe_down(", up_direction, ")=", hit_down,
		  " probe_up(", -up_direction, ")=", hit_up)
	return hit_down or hit_up

func _raycast_hits_wall(dir: Vector2, distance: float) -> bool:
	var space_state = get_world_2d().direct_space_state
	var query = PhysicsRayQueryParameters2D.create(global_position, global_position + dir * distance)
	query.exclude = [self]
	query.collision_mask = 1
	var result = space_state.intersect_ray(query)
	return not result.is_empty()


func _surface_for_rotation(rot: float) -> String:
	var angle = int(round(rad_to_deg(rot))) % 360
	if angle < 0: angle += 360
	match angle:
		0, 360: return "bottom"
		90:     return "left"
		180:    return "top"
		270:    return "right"
	return "bottom"
	
func _has_adjacent_surface_to_snap_to(prospective_normal: Vector2, from_pos: Vector2) -> bool:
	var space_state = get_world_2d().direct_space_state
	var check_dir = prospective_normal
	var probe_end = from_pos + check_dir * 30.0
	var query = PhysicsRayQueryParameters2D.create(from_pos, probe_end)
	query.exclude = [self]
	query.collision_mask = 1
	var result = space_state.intersect_ray(query)
	print("[PROBE2] from=", from_pos, " to=", probe_end, " hit=", result)
	return not result.is_empty()

	
func _update_current_surface():
	# Use the current rotation (snapped to 90 deg) to find the new surface
	var angle = int(round(rad_to_deg(rotation))) % 360
	if angle < 0: angle += 360

	match angle:
		0, 360: current_surface = "bottom"
		90:      current_surface = "left"
		180:     current_surface = "top"
		270:     current_surface = "right"
