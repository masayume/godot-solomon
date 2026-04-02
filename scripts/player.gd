extends CharacterBody2D

@onready var speed = GameConfig.gamedata.player.move_speed
@onready var jump_force = GameConfig.gamedata.player.jump_force
@onready var gravity = GameConfig.gamedata.player.gravity
@onready var off_xp = GameConfig.gamedata.player.off_xp
@onready var sprite = $Sprite2D
@onready var score_label: RichTextLabel = $"../../../UI/Score"

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
	level_loader = get_parent().get_parent()
	level = get_parent()
	$CollectionZone.area_entered.connect(_on_interaction_detector_area_entered)
	
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
#		print("is_action_pressed(fire)")
		return
		
###MAIN_INTERACTION player interacts with items
func _on_interaction_detector_area_entered(area: Area2D):
	# The 'area' is the child of the Item. We want the Item itself.
	###DEBUG player area interaction
	print("DEBUG: Player Area hit SOMETHING: ", area.name, " (Parent: ", area.get_parent().family, ")")

	var target = area.get_parent() 
	var item_type = target.family
	var item_info = GameConfig.itemdata[item_type]

	if item_info.has("action_type"):
		if item_info["action_type"] == "collect":
			area.get_parent().queue_free() # Remove the item node

	# 1. Set Player Flags (e.g., "has_key")
	if GameConfig.itemdata[area.get_parent().family].has("on_collect_flag"):
		print(GameConfig.itemdata[area.get_parent().family].on_collect_flag)
		self.set_flag(GameConfig.itemdata[area.get_parent().family].on_collect_flag)
		print("player ", flags)

###TODO: align score/level in UI 
	# 2. Increase Score (Assuming a global score variable)
	if GameConfig.itemdata[area.get_parent().family].has("score"):
		GameConfig.score += GameConfig.itemdata[area.get_parent().family].score
		print("score: ", GameConfig.score)
		score_label.text = "[right][color=green]1p[/color] [color=white]" + str(GameConfig.score) + "[/color][/right]"
	
	# If the item is a door
	if item_type == "door":
		if self.has_flag("has_key"):
			print("Access Granted!")
			# Trigger level load on the loader 
			var loader = get_tree().current_scene.find_child("Level", true, false)
			loader.start_level_transition()
		else:
			print("The door is locked. You need the key flag!")
			# Optional: Play a "locked" sound or animation	

	###DEBUG main player interaction with item code
#	if target.has_node("Receiver"):
#		print("DEBUG: Receiver FOUND on ", target.name)		
#		$CollectionZone.interact(target)
#	else:
#		print("DEBUG: No Receiver found on ", target.name)


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

	
