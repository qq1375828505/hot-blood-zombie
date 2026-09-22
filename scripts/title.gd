extends Control
# 开场标题画面：暗灰废墟 + 白色"热血" + 金色"末日丧尸" + 闪烁 PRESS START

@onready var press_label: Label = $PressLabel
@onready var title_red: Label = $TitleLayer/TitleRed
@onready var title_gold: Label = $TitleLayer/TitleGold

var _blink: float = 0.0
var _can_advance: bool = true


func _ready() -> void:
	# 立即允许进入，不等延时（安卓触摸卡死修复）
	pass


func _process(delta: float) -> void:
	if _can_advance and press_label != null:
		_blink += delta * 4.0
		press_label.modulate.a = 0.4 + 0.6 * (0.5 + 0.5 * sin(_blink))


# 用 _input 而非 _unhandled_input，双保险确保触摸事件被捕获
func _input(event: InputEvent) -> void:
	if not _can_advance:
		return
	if event is InputEventScreenTouch and event.pressed:
		_advance()
	elif event is InputEventMouseButton and event.pressed:
		_advance()
	elif event is InputEventKey and event.pressed:
		_advance()


func _advance() -> void:
	_can_advance = false
	get_tree().change_scene_to_file("res://scenes/select.tscn")
