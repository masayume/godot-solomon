extends Node

# State variables
var current_lives: int = 0
var max_lives: int = 6

# Signal to notify UI when things change
signal lives_changed(new_count)

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
