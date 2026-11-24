extends "res://scripts/interactable.gd"

func _ready() -> void:
	prompt_text = "Отдохнуть"
	add_to_group("rest_spot")
	add_to_group("path_poi")
	var col := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(2.3, 1.0, 0.9)
	col.shape = shape
	col.position.y = 0.5
	add_child(col)

func interact(player: Node) -> void:
	if player != null and player.has_method("toggle_rest"):
		player.toggle_rest(self)

func toggle_rest(player: Node) -> void:
	interact(player)
