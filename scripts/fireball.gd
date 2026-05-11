extends Area2D

@export var speed: float = 200.0
var direction = Vector2.RIGHT # Initial direction

@onready var ray_front = $RayFront
@onready var ray_down = $RayDown

func _ready():
	# Connect to detect monsters
	area_entered.connect(_on_area_entered)
	body_entered.connect(_on_body_entered)

func _physics_process(delta):
	# 1. Move the fireball
	position += direction * speed * delta
	
	# 2. EDGE FOLLOWING LOGIC
	# Case A: We hit a wall in front -> Rotate UP
	if ray_front.is_colliding():
		var normal = ray_front.get_collision_normal()
		direction = Vector2(normal.y, -normal.x) # Rotate 90 degrees
		rotation = direction.angle()
		
	# Case B: We lost the floor -> Rotate DOWN/AROUND the corner
	elif not ray_down.is_colliding():
		# This part is trickier; usually involves rotating -90 degrees
		# and snapping to the corner.
		direction = Vector2(-direction.y, direction.x)
		rotation = direction.angle()

func _on_area_entered(area):
	if area.is_in_group("monsters"):
		area.take_damage() # Or however your monsters die
		explode()

func _on_body_entered(body):
	# If we hit something we can't climb (like a solid door)
	if not body.is_in_group("blocks"):
		explode()

func explode():
	# Here you REUSE your fx system!
	# Spawn a "poof" or "boom" at current position
	# get_parent().spawn_fx("poof", global_position, ...)
	queue_free()
