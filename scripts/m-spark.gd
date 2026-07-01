extends Monster
class_name Spark

var direction := -1

var current_surface: String = "bottom"

var gravity = GameConfig.monsterdata.spark.gravity

var hitbox: Area2D 

var airborne_time: float = 0.0
const MAX_AIRBORNE_BEFORE_FLY_STRAIGHT := 0.12  # seconds with no floor before giving up on corner-snapping
const WALL_PROBE_DIST := 26.0 # Long enough to reach the wall from the center of a tile
const WALL_REACH := 38.0      # How far to shoot rays inward to find the wall
const EDGE_LOOKAHEAD := 36.0  # How far forward to shift the Yellow ray (should be about half your tile size)

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

# --- DEBUG VARIABLES ---
var debug_rays: Array = []
@export var show_debug_rays: bool = false # Set to true when you want to see them

func _ready():
	
	# FIX: Target the Sprite node directly for transparency
	if has_node("Sprite2D") and show_debug_rays:
		$Sprite2D.modulate.a = 0.5
	elif has_node("AnimatedSprite2D") and show_debug_rays:
		$AnimatedSprite2D.modulate.a = 0.5
	
	family = "spark"
	add_to_group("monsters") 
	super._ready()

	# If your monster data passes "attached", assign it here
		
	z_index = 30
	# Initial rotation based on the starting surface
#	rotation = surface_normals[current_surface].angle() + PI/2
	# 1. the spawner already set 'current_surface' before this runs.
	# 2. We MUST use + PI/2 so the Spark's "feet" point into the block, not away from it.
	rotation = surface_normals[current_surface].angle() + (PI / 2.0)
	
	# Force visibility of collision for this specific instance
	# if you want to be 100% sure during debug
	if get_node_or_null("CollisionShape2D"):
		get_node("CollisionShape2D").visible = true

	hitbox = get_node_or_null("HitBox")
	_setup_hitbox()

#	print("Spark layer:", collision_layer, " mask: ", collision_mask)
	# Ghost HitBox
	collision_layer = 4   # (or anything, not important)
	collision_mask = 1    # must match Player layer	

	# Run this once, e.g. in Spark's _ready() after a short delay, or via a button
#	var loader = get_tree().get_first_node_in_group("level_loader")

###DEBUG
#	var block_world_pos = GameConfig.grid_to_local(4, 10, loader.tile_size, loader.x_off, loader.y_off)
#	print("[GRID CHECK] block[4,10] world center=", block_world_pos)

###DEBUG
#	var cell = GameConfig.world_to_grid(Vector2(-42.92522, -150.0), loader.x_off, loader.y_off, loader.tile_size)
#	print("[WHAT BLOCK] Spark crawling position resolves to cell=", cell)

###DEBUG
#	for row in range(6, 12):
#		var wpos = GameConfig.grid_to_local(4, row, loader.tile_size, loader.x_off, loader.y_off)
#		cell = Vector2i(4, row)
#		print("[BLOCK CHECK](col 4) cell=", cell, " world=", wpos, " has_block=", loader.blocks.has(cell))

#	for row in range(6, 12):
#		cell = Vector2i(3, row)
#		print("[BLOCK CHECK](col 3) cell=", cell, " has_block=", loader.blocks.has(cell))

###DEBUG
#	var cell_here = GameConfig.world_to_grid(Vector2(-85.00317, -127.0), loader.x_off, loader.y_off, loader.tile_size)
#	print("[WHAT IS BELOW] world_y=-127 resolves to cell=", cell_here, " has_block=", loader.blocks.has(cell_here))


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
	# Clear old debug lines every frame
	debug_rays.clear()
	
	# Reset velocity completely to erase base monster gravity/accelerations
	velocity = Vector2.ZERO
	
	var speed = GameConfig.monsterdata[family].speed
	
	var local_forward = Vector2.RIGHT.rotated(rotation) * direction
	var local_down = Vector2.DOWN.rotated(rotation)
	up_direction = -local_down

	# 1. GROUND CHECK (Color: GREEN) - Are we currently hugging a wall?
	var is_grounded = _raycast_from(global_position, local_down, WALL_REACH, Color.GREEN)
	
	if is_grounded:
		# FIX: Check if there is a wall directly blocking our forward movement
		var wall_ahead = _raycast_from(global_position, local_forward, EDGE_LOOKAHEAD, Color.RED)

		# Shift forward just enough to peek over the edge
		var front_edge = global_position + (local_forward * EDGE_LOOKAHEAD)
		
		# 2. FLOOR AHEAD CHECK (Color: YELLOW)
		var floor_ahead = _raycast_from(front_edge, local_down, WALL_REACH, Color.YELLOW)
		
		# MODIFIED: Only execute convex wrapping if the floor drops off AND we aren't blocked by a wall ahead
		if not floor_ahead and not wall_ahead:
			# The floor drops off. Look backward-down for the adjacent wall face.
			var wrap_origin = front_edge + (local_down * WALL_REACH)
			
			# 3. WALL BEHIND CHECK (Color: BLUE/CYAN)
			var wall_behind = _raycast_from(wrap_origin, -local_forward, WALL_REACH, Color.CYAN)
						
			if wall_behind:
				# Edge found! Wrap around the corner. Turn 90 degrees around the corner
				rotation += (PI / 2.0) * direction
				_update_current_surface()
				
				# Nudge forward/down so we mount the new face without snagging
				global_position += local_forward * 4.0 + local_down * 4.0
				queue_redraw()
				return

	# 4. MOVEMENT
	velocity = local_forward * speed
	
	# Apply a tiny inward force to stick to the wall (only if grounded)
	if is_grounded:
		velocity += local_down * 2.0 

	move_and_slide()
	
	# 5. CONCAVE CHECK (Wall directly in front)
	if get_slide_collision_count() > 0:
		for i in range(get_slide_collision_count()):
			var col = get_slide_collision(i)
			# If we collide with a wall opposing our forward movement
			if col.get_normal().dot(local_forward) < -0.5:
				rotation -= (PI / 2.0) * direction
				_update_current_surface()
				queue_redraw()
				return
				
	# Tell Godot to update the canvas drawings this frame
	queue_redraw()	
	
func behaveOLD(_delta):

	# 1. Calculate intended move direction
	up_direction = surface_normals.get(current_surface, Vector2.UP)
	var move_dir = Vector2.RIGHT.rotated(rotation)
	var next_velocity = move_dir * direction * GameConfig.monsterdata[family].speed
	
	# 2. Check for upcoming corner BEFORE applying velocity
	var ahead_dir = move_dir * direction
	# Use a slightly offset origin to "peek" around the corner
	if _raycast_from(global_position + (move_dir * 4.0), ahead_dir, SHORT_PROBE):
		# We are about to hit a wall. 
		# Trigger the turn immediately and adjust position to avoid the block
		rotation += PI/2 * direction
		_update_current_surface()
		# Teleport slightly away from the corner to avoid getting stuck
		global_position += move_dir * 2.0 
		return # Skip this frame's move_and_slide
		
	# 3. Only apply velocity if not blocked
	velocity = next_velocity

	move_and_slide()	
###DEBUG
#	print("[VELOCITY-CHECK] rotation=", rad_to_deg(rotation), " move_dir=", Vector2.RIGHT.rotated(rotation), " velocity=", velocity, " direction=", direction)

###DEBUG
#	print("[SPEED-CHECK] speed=", GameConfig.monsterdata[family].speed, " move_dir=", move_dir, " direction=", direction, " product=", move_dir * direction * GameConfig.monsterdata[family].speed)

#	if get_slide_collision_count() > 0:
#		for i in range(get_slide_collision_count()):
#			var col = get_slide_collision(i)
###DEBUG
#			print("[COLLISION] collider=", col.get_collider(), " normal=", col.get_normal(), " position=", col.get_position())
		
#	var ahead_dir = move_dir * direction
#	var concave_hit = _raycast_from(global_position, ahead_dir, SHORT_PROBE)
#	var concave_hit = _is_wall_ahead(ahead_dir)
#	if concave_hit:

###DEBUG
#		print("[CONCAVE] pos=", global_position, " surface_before=", current_surface,
#			  " rotation_before=", rad_to_deg(rotation), " ahead_dir=", ahead_dir)

#		rotation += PI/2 * direction
#		_update_current_surface()
#		global_position -= ahead_dir * 8.0

###DEBUG
#		print("[CONCAVE] surface_after=", current_surface, " rotation_after=", rad_to_deg(rotation))
		
#		return
#		pass

#	var still_attached = _raycast_from(global_position, -up_direction, PROBE_DIST)

###DEBUG
#	print("[ATTACH] surface=", current_surface, " up_direction=", up_direction, " probe_dir=", -up_direction, " attached=", still_attached)
#	print("[ATTACH] pos=", global_position, " surface=", current_surface, " attached=", still_attached)

#	if still_attached:
#		return # Still crawling normally, nothing to do

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

#	print("[CONVEX-CHECK] pos=", global_position, " surface=", current_surface,
#		  " prospective_surface=", prospective_surface, " found=", found)

	if found:
		rotation = prospective_rotation
		current_surface = prospective_surface
		global_position = trial_pos
#		print("[TURN-CONVEX] surface=", current_surface, " rotation=", rad_to_deg(rotation), " direction=", direction, " move_dir_after=", Vector2.RIGHT.rotated(rotation))
		pass
	else:
		velocity.y += gravity * _delta

func _is_wall_ahead(ahead_dir: Vector2) -> bool:
	if _raycast_from(global_position, ahead_dir, SHORT_PROBE):
		return true
	if _raycast_from(global_position, -ahead_dir, SHORT_PROBE):
		return true
	return false


func _draw():

###DEBUG Spark raycasts
	# If the toggle is off, do not draw the rays
	if not show_debug_rays:
		return
		
	# This native Godot function paints shapes on the screen.
	for ray in debug_rays:
		draw_line(ray.start, ray.end, ray.color, 2.0)
		# Draw a little dot at the tip so you know which way it's pointing
		draw_circle(ray.end, 2.5, ray.color)

#func _raycast_from(origin: Vector2, dir: Vector2, distance: float) -> bool:
func _raycast_from(origin: Vector2, dir: Vector2, distance: float, debug_color: Color = Color.RED) -> bool:
	var space_state = get_world_2d().direct_space_state
	var end_point = origin + (dir * distance)
	# Save the line data for _draw() to use

	debug_rays.append({
		"start": to_local(origin), 
		"end": to_local(end_point), 
		"color": debug_color
	})	
	
	var query = PhysicsRayQueryParameters2D.create(origin, origin + dir * distance)
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

func _update_current_surface() -> void:
	current_surface = _surface_for_rotation(rotation)
#	print("Spark swapped surface to: ", current_surface)

func _update_current_surfaceOLD():
	# Use the current rotation (snapped to 90 deg) to find the new surface
	var angle = int(round(rad_to_deg(rotation))) % 360
	if angle < 0: angle += 360

	match angle:
		0, 360: current_surface = "bottom"
		90:      current_surface = "left"
		180:     current_surface = "top"
		270:     current_surface = "right"
