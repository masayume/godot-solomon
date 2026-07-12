extends Monster
class_name Ghost

var direction := -1
var gravity = GameConfig.monsterdata.ghost.gravity
# var gravity: float = 980.0

var bob_time := 0.0
var trail: Line2D
var max_points: int = 77
@export var eye_offset: Vector2 = Vector2(25, -22)

var hitbox: Area2D 

#SIGNAL-ghost-1 Define the signal with parameters able to destroy a block when hit
signal wall_impact(pos: Vector2, dir: int)

func _ready():
	family = "ghost"
	add_to_group("monsters") 
	super._ready()
	
	# ghost opacity 80%
	sprite.modulate.a = 0.7 + (sin(bob_time * 5.0) * 0.1)
	setup_trail()

	hitbox = get_node_or_null("HitBox")
	_setup_hitbox()

	# 3. SAFELY get gravity from the loaded stats, falling back to the default if missing
	gravity = stats.get("gravity", gravity)

	if stats.get("direction") == "left":
		direction = 1
	elif stats.get("direction") == "right":
		direction = -1
	
	print("Ghost layer:", collision_layer, " mask: ", collision_mask)
	# Ghost HitBox
	collision_layer = 4   # (or anything, not important)
	collision_mask = 1    # must match Player layer	


func _physics_process(_delta):

	var current_offset = eye_offset
	if $Sprite2D.flip_h:
		current_offset.x *= -1
	var eye_global_pos = global_position + current_offset
	
	trail.add_point(eye_global_pos)
	
	if trail.get_point_count() > max_points:
		trail.remove_point(0)
		
	bob_time += _delta

	velocity.x = direction * GameConfig.monsterdata.ghost.speed

	# 4. Dynamically update the trail based on movement
	if sprite.material is ShaderMaterial:
		# Length increases with speed; flip direction based on 'direction' variable 
		var movement_factor = abs(velocity.x) / 1000.0 
		var trail_offset = movement_factor * -direction # Trail stays behind movement
		sprite.material.set_shader_parameter("trail_length", trail_offset)
	

	behave(_delta) # includes move_and_slide()

	if is_on_wall():
		#SIGNAL-ghost-2 emits defined signal when it hits the wall
		# shift the Ghost's reported position forward by half a tile (in its direction of travel) 
		# before emitting, so it samples from inside the block it's touching rather than from its center
		var probe_pos = global_position + Vector2(direction * tile_size * 0.5, 0)
		wall_impact.emit(probe_pos, direction)
		direction *= -1

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

	velocity.y = sin(bob_time * 2.0) * 10.0

func setup_trail():
	trail = Line2D.new()
	trail.z_index = 100
	trail.top_level = true
	trail.global_position = Vector2.ZERO # Force the "origin" of the line to the world center
#	trail.self_modulate.a = 0.2  # 40% opacity
	# 1. Visual Configuration
	trail.width = 22.0
	trail.width_curve = Curve.new()
	trail.width_curve.add_point(Vector2(0, 0)) # Start thick
	trail.width_curve.add_point(Vector2(1, 1)) # End at zero
	trail.default_color = Color(5.0, 0.2, 0.2, 1.0) # High RAW Red for Glow
	trail.begin_cap_mode = Line2D.LINE_CAP_ROUND
	trail.joint_mode = Line2D.LINE_JOINT_ROUND
	
	trail.texture_mode = Line2D.LINE_TEXTURE_TILE # Or LINE_TEXTURE_STRETCH
	trail.antialiased = true

	# 2. Add the Shader
	var mat = ShaderMaterial.new()
	mat.shader = load("res://resources/shaders/m-trail.gdshader") # Point to your shader file
	trail.material = mat
	
	# 3. Positioning Logic
	# top_level = true makes the Line2D ignore the Ghost's movement 
	# so it stays behind in "World Space"
	trail.top_level = true 
	add_child(trail)
