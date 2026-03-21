extends Node
class_name Receiver

var data: Dictionary = {}

func _ready():
###DEBUG_5l 	
	# This will print: "Receiver added to: Key_Gold_01 with logic: collectible"
	print("DEBUG: Receiver added to: ", get_parent().name, " with action_type: ", data.get("action_type", "NONE"))
	
	# Optional: Draw a small icon or change the parent's color to prove it's active
	if OS.is_debug_build():
		get_parent().modulate = Color.GREEN # Turns the item green if it has a receiver
		
func receive(action, source):
	print("Received action from: ", source.name)	
	match GameConfig.itemdata.get("action_type"):
		"collect":
			_handle_collection(source)
		"door":
			_handle_door(source)

func _handle_collection(player):
	var flag = GameConfig.itemdata.get("on_collect_flag")
	player.set_flag(flag, true) # Player now "owns" the key state
	print("collected: ", GameConfig.itemdata.get("name"))
	get_parent().queue_free()

func _handle_door(player):
	var requirement = GameConfig.itemdata.get("requires_flag")
	if player.has_flag(requirement):
		print("Level Complete!")
		# get_tree().change_scene_to_file(...)
	else:
		print("Door is locked. You need: ", requirement)
