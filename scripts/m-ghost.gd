extends Monster
class_name Ghost

var direction := -1
var gravity = GameConfig.monsterdata.ghost.gravity

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
	super._ready() # Calls Monster._ready() which triggers change_state(family)
	
	# ghost opacity 80%
	sprite.modulate.a = 0.7 + (sin(bob_time * 5.0) * 0.1)

	setup_trail()

	# Force visibility of collision for this specific instance
	# if you want to be 100% sure during debug
	if get_node_or_null("CollisionShape2D"):
		get_node("CollisionShape2D").visible = true

	hitbox = get_node_or_null("HitBox")
	_setup_hitbox()

	print("Ghost layer:", collision_layer, " mask: ", collision_mask)
	# Ghost HitBox
	collision_layer = 4   # (or anything, not important)
	collision_mask = 1    # must match Player layer	

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


func _process(delta):
	animate(delta)
#	var current_pos = global_position 

	var current_offset = eye_offset
	if $Sprite2D.flip_h:
		current_offset.x *= -1
	var eye_global_pos = global_position + current_offset
	
	trail.add_point(eye_global_pos)
	
	if trail.get_point_count() > max_points:
		trail.remove_point(0)
				
func _physics_process(_delta):

	bob_time += _delta
#	velocity.x = direction * GameConfig.monsterdata.ghost.speed

	# 4. Dynamically update the trail based on movement
	if sprite.material is ShaderMaterial:
		# Length increases with speed; flip direction based on 'direction' variable 
		var movement_factor = abs(velocity.x) / 1000.0 
		var trail_offset = movement_factor * -direction # Trail stays behind movement
		sprite.material.set_shader_parameter("trail_length", trail_offset)
		
	behave(_delta) # includes move_and_slide()


func behave(_delta):
	var state_data = GameConfig.monsterdata.get(current_state, stats)
	var current_speed = state_data.get("speed", stats.get("speed", 0))
	
	velocity.x = direction * current_speed
	sprite.flip_h = velocity.x < 0

	# Apply gravity
	if not is_on_floor():
		velocity.y += gravity * _delta
	else:
		velocity.y = 0
		
	# simple back-and-forth
	if is_on_wall():
		direction *= -1
		
	move_and_slide()
	
	# Horizontal movement
	
	# Vertical Bobbing
	# Adjust 2.0 for speed and 10.0 for height/intensity

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
