extends CanvasLayer
# 暂停菜单 UI（V1.4）：暂停/继续/重开/成就/商店/返回主菜单。
# process_mode=ALWAYS（process_mode=3），游戏暂停时仍可交互；按钮均为 Button，触屏可点。
# 音量项为简化标签（Godot 音频总线较复杂，V1.2 仅显示 100%，不做实际滑块）。
# V1.4：2P 始终为 AI 队友，移除人机队友开关按钮。

@onready var resume_button: Button = $ButtonContainer/ResumeButton
@onready var restart_button: Button = $ButtonContainer/RestartButton
@onready var achievements_button: Button = $ButtonContainer/AchievementsButton
@onready var shop_button: Button = $ButtonContainer/ShopButton
@onready var main_menu_button: Button = $ButtonContainer/MainMenuButton
@onready var close_button: Button = $CloseButton


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false
	resume_button.pressed.connect(_on_resume)
	restart_button.pressed.connect(_on_restart)
	achievements_button.pressed.connect(_on_achievements)
	shop_button.pressed.connect(_on_shop)
	main_menu_button.pressed.connect(_on_main_menu)
	close_button.pressed.connect(_on_resume)


func open() -> void:
	visible = true


func close() -> void:
	visible = false


# 查找游戏主节点（当前场景根即 Game），找不到返回 null
func _get_game() -> Node:
	var cs := get_tree().current_scene
	if cs and (cs.has_method("toggle_pause") or cs.has_method("_restart_game") or cs.has_method("_toggle_shop")):
		return cs
	return null


func _on_resume() -> void:
	close()
	var g := _get_game()
	if g and g.has_method("toggle_pause"):
		g.toggle_pause()


func _on_restart() -> void:
	close()
	var g := _get_game()
	if g and g.has_method("_restart_game"):
		g._restart_game()


func _on_achievements() -> void:
	# Achievements Autoload 已自带 _toggle_panel()（H 键同款），暂停下仍可打开
	var ach := get_node_or_null("/root/Achievements")
	if ach and ach.has_method("_toggle_panel"):
		ach._toggle_panel()
	else:
		print("V1.2 暂停菜单：Achievements 不可用")


func _on_shop() -> void:
	close()
	var g := _get_game()
	if g == null:
		return
	if g.has_method("_toggle_shop"):
		g._toggle_shop()
	# 商店接管暂停状态（shop.open 内部 set paused=true），重置 is_paused 标志避免状态残留
	if "is_paused" in g:
		g.set("is_paused", false)


func _on_main_menu() -> void:
	close()
	get_tree().paused = false
	Economy.reset()
	get_tree().change_scene_to_file("res://scenes/select.tscn")


func _unhandled_input(event: InputEvent) -> void:
	if not visible:
		return
	# 桌面端 R（restart 动作）或 ESC：继续游戏
	if event.is_action_pressed("restart"):
		_on_resume()
		return
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_ESCAPE:
		_on_resume()
