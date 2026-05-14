extends Area2D

@export var speed: float = 300.0
var direction = Vector2.RIGHT # Initial direction
var is_crawling: bool = false # NEW: Track if we've touched a surface yet

@onready var ray_front = $RayFront
@onready var ray_down = $RayDown

func _ready():
	# Connect to detect monsters
	
	collision_mask = 1 | 4 # Look for Layer 1 (World) and 3 (Monsters)
	
	area_entered.connect(_on_area_entered)
	body_entered.connect(_on_body_entered)

func _physics_process(delta):
	# 1. Move the fireball
	position += direction * speed * delta
	
# 2. SURFACE DETECTION
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
	var target = area
	# Check if the area itself or its parent is a monster
	if not target.is_in_group("monsters"):
		target = area.get_parent()
		
	if target.is_in_group("monsters") and target.has_method("take_damage"):
		target.take_damage()
		explode()

func _on_body_entered(body):
	# If we hit something we can't climb (like a solid door)
	if not body.is_in_group("blocks"):
		explode()

func explode():
	get_parent().spawn_fx("boom", global_position, Vector2i(-1,-1), false)
	queue_free()
