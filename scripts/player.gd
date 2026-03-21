extends CharacterBody2D

@onready var speed = GameConfig.gamedata.player.move_speed
@onready var jump_force = GameConfig.gamedata.player.jump_force
@onready var gravity = GameConfig.gamedata.player.gravity
@onready var off_xp = GameConfig.gamedata.player.off_xp
@onready var sprite = $Sprite2D
var crouch_texture = preload("res://sprites/player/player-crouch-frames.png")
var idle_texture = preload("res://sprites/player/player-idle-frames.png")

var flags = []

func set_flag(flag_name: String):
	if not flags.has(flag_name):
		flags.append(flag_name)

func has_flag(flag_name: String) -> bool:
	return flags.has(flag_name)
	
@export var block_scene: PackedScene
var tile_size = 64
var facing := 1   # 1 = right, -1 = left
var level_loader
var level
var crouching = false

signal fire_pressed(position, direction, crouching)

func _ready():
	z_index = 10
#	print("Player ready:", self)
#	print("PLAYER world:", global_position)
#	print("SPRITE local:", $Sprite2D.position)
	level_loader = get_parent().get_parent()
	level = get_parent()
	
	# var ts = GameConfig.gamedata.TILE_SIZE
	# print("ts: " + str(ts))
	
func _physics_process(delta):

	# Apply gravity
	if not is_on_floor():
		velocity.y += gravity * delta 
	move_and_slide()

	if Input.is_action_pressed("move_left"):
		facing = -1

	if Input.is_action_pressed("move_right"):
		facing = 1

	# Detect Input
	if Input.is_action_pressed("crouch") and is_on_floor():
		crouch()
		update_animation()
	elif crouching:
		# Check if there's room to stand up!
#		if not is_something_above_head():
		stand_up()
		update_animation()

	# (Your existing movement logic here...)
	# If crouching, you might want to multiply speed by 0.5 or 0.
	
	$Sprite2D.flip_h = facing == 1

	# Horizontal movement
	var direction = Input.get_axis("move_left", "move_right")
	if direction != 0:
		facing = int(direction)
	velocity.x = direction * speed

	# Jump
	if Input.is_action_just_pressed("jump") and is_on_floor():
		velocity.y = -jump_force

	if Input.is_action_just_pressed("fire"):
		fire_pressed.emit(global_position, facing, crouching)

		var _grid = GameConfig.world_to_grid(
			global_position,
			level.x_off,
			level.y_off,
			tile_size
		)

#		print("PLAYER WORLD:", global_position)
#		print("PLAYER GRID:", _grid)

	if crouching: velocity.x = 0
	
	# Move the body
	move_and_slide()

func update_animation():

	if crouching:
		sprite.texture = crouch_texture
	else:
		sprite.texture = idle_texture
		
func crouch():
	if crouching: return
	crouching = true
	
	# Shrink the collision rectangle
#	collision_shape.shape.size.y = crouching_shape_height
#	collision_shape.position.y = crouching_position_y
	
	# Update visual (assuming you have a crouch frame)
	# sprite.frame = CROUCH_FRAME_ID 

func stand_up():
	crouching = false
#	collision_shape.shape.size.y = standing_shape_height
#	collision_shape.position.y = standing_position_y

	
func _input(event):
	if event.is_action_pressed("fire"):
		print("is_action_pressed(fire)")

func _on_collection_zone_area_entered(area):
	# 'area' is the Area2D inside the Item
	var item_node = area.get_parent() 
	
	if item_node.has_node("Receiver"):
		$Interactor.interact(item_node)

func spawn_at(tile_x: int, tile_y: int, x_off: float, y_off: float):
	# Get tile size from config (single source of truth)
	tile_size = GameConfig.gamedata.screen.TILE_SIZE
	# Convert grid coordinates into pixel position
	
#	print("spawn_at: " + str(x_off))
#	print("parent:", get_parent())
	position = GameConfig.grid_to_local(
			tile_x, 
			tile_y, 
			tile_size, 
			x_off, 
			y_off
		)

#	if GameConfig.itemdata.get("is_interactable", false):
	# Create the Receiver node dynamically
#	var receiver = Receiver.new() 
#	receiver.name = "Receiver"
#	add_child(receiver)
		
	# Optionally pass data to the receiver so it knows what to do
#	receiver.action_type = GameConfig.itemdata.get("action_type", "default")	

	
