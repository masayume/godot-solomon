extends Node
class_name Receiver

var data: Dictionary = {}

func _log():
###DEBUG_5l 	
	# This will print: "Receiver added to: Key_Gold_01 with logic: collectible"
	# Optional: Draw a small icon or change the parent's color to prove it's active
#	print("DEBUG: Receiver added to: ", get_parent().name, " with action_type: ", data.get("action_type", "NONE"))	
	return

func _ready():
#	if OS.is_debug_build():
#		get_parent().modulate = Color.GREEN # Turns the item green if it has a receiver
	_log()

func receive(action, source):
	print(get_parent().name, " received ", action, " from: ", source.name)	
#	match GameConfig.itemdata.get("action_type"):
	match data.get("action_type"):
		"collect":
			_handle_collection(source)
		"door":
			_handle_door(source)

func _handle_collection(player):
	var flag = GameConfig.itemdata.get("on_collect_flag")
	player.set_flag(flag, true) # Player now "owns" the key state
	print("collected: ", GameConfig.itemdata.get("name"))

	var item_name = data.get("name")
	if item_name == "extra_life":
		GameManager.add_life()
		print("Life added via GameManager")
		
	get_parent().queue_free()

func _handle_door(player):
	var requirement = GameConfig.itemdata.get("requires_flag")
	if player.has_flag(requirement):
		print("Level Complete!")
		# get_tree().change_scene_to_file(...)
	else:
		print("Door is locked. You need: ", requirement)
