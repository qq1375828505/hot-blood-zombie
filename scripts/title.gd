extends Control
# 开场标题画面：还原 FC 热血系列开场
# 浅蓝天空 + 白色城市剪影 + 绿草地 + 粉红"热血"大字 + 闪烁 PRESS START

@onready var press_label: Label = $PressLabel
@onready var title_red: Label = $TitleLayer/TitleRed
@onready var title_gold: Label = $TitleLayer/TitleGold

var _blink: float = 0.0
var _can_advance: bool = false


func _ready() -> void:
	# 开场停 0.8 秒后才允许按键进入，避免误触
	await get_tree().create_timer(0.8).timeout
	_can_advance = true


func _process(delta: float) -> void:
	if _can_advance and press_label != null:
		_blink += delta * 4.0
		press_label.modulate.a = 0.4 + 0.6 * (0.5 + 0.5 * sin(_blink))


func _unhandled_input(event: InputEvent) -> void:
	if not _can_advance:
		return
	if event is InputEventScreenTouch and event.pressed:
		_advance()
	elif event.is_action_pressed("ui_accept") or event.is_action_pressed("restart"):
		_advance()
	elif event is InputEventKey and event.pressed:
		_advance()


func _advance() -> void:
	_can_advance = false
	get_tree().change_scene_to_file("res://scenes/select.tscn")
