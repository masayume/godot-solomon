extends Node
class_name Interactor

func interact(target, action):

	if target.has_node("Receiver"):
		target.get_node("Receiver").receive(action, get_parent())
