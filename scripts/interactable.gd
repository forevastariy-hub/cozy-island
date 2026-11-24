class_name Interactable
extends StaticBody3D

var prompt_text := "Действие"

func get_prompt() -> String:
	return prompt_text

func interact(_player: Node) -> void:
	pass
