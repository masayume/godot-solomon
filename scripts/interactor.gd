# interactor.gd
extends Node
class_name Interactor

func interact(target: Node):
	var receiver = target.get_node_or_null("Receiver")
	if receiver:
		# We pass 'get_parent()' so the Receiver knows 
		# which entity (the Player) initiated the contact.
#		print("SUCCESS: Interactor found Receiver on ", target.name)
		receiver.receive("interact", get_parent())
	else:
		print("FAILURE: ", target.name, " has no Receiver node!")
		
