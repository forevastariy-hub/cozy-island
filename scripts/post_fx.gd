extends CanvasLayer

var mat: ShaderMaterial
var daynight: Node

func _ready() -> void:
	layer = 1
	var rect := ColorRect.new()
	rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	mat = ShaderMaterial.new()
	mat.shader = load("res://scripts/post_fx.gdshader")
	rect.material = mat
	add_child(rect)

func _process(_delta: float) -> void:
	if mat == null:
		return
	var a := (Game.time_of_day - 6.0) / 24.0 * TAU
	var sun_dir := Vector3(cos(a), sin(a), 3.0).normalized()
	var elev := sun_dir.y
	mat.set_shader_parameter("warm_mix", clampf(elev * 2.0, 0.0, 1.0))

	var wet := 0.0
	if daynight != null:
		wet = clampf(daynight.rain_strength, 0.0, 1.0)
	mat.set_shader_parameter("rain_mix", wet)
