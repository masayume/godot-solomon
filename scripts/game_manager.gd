extends Node

# State variables
var current_lives: int = 0
var max_lives: int = 6

# Signal to notify UI when things change
signal lives_changed(new_count)

var is_player_active: bool = false:
	set(value):
		is_player_active = value
		# Notify the HUD to redraw whenever this state changes
		lives_changed.emit(current_lives) # Trigger the HUD redraw
		print("is_player_active set to ", value)

var _hud_ref = null

func register_hud_lives(node):
	_hud_ref = node

func set_player_in_game(active: bool):
	is_player_active = active
	print("set player active: 1 life on stage")
	
func _ready():
	# Initialize from parsed GameConfig data 
	current_lives = GameConfig.gamedata.get("start_lives", 3)
	max_lives = GameConfig.gamedata.get("max_lives", 6)

func add_life():
	if current_lives < max_lives:
		current_lives += 1
		lives_changed.emit(current_lives) # emit signal to UI

func remove_life():
	current_lives -= 1
	lives_changed.emit(current_lives) # emit signal to UI
	if current_lives <= 0:
		handle_game_over()

func handle_game_over():
	print("Game Over Logic Here")
