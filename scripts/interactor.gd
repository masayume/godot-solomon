# interactor.gd
extends Node
class_name Interactor

func interact(target):
	# The Interactor only cares if a Receiver exists.
	# It doesn't care if the target is a Key, a Door, or a Monster.
	var receiver = target.get_node_or_null("Receiver")
	if receiver:
		# We pass 'get_parent()' so the Receiver knows 
		# which entity (the Player) initiated the contact.
		receiver.receive("interact", get_parent())
