extends CanvasLayer
# 移动端触摸控件：左下角虚拟摇杆 + 右下角动作按钮群。
# 仅在具备触摸屏的设备上显示；桌面端自动隐藏，不影响键鼠操作。
# 通过 Input.action_press / Input.action_release 驱动已注册输入动作。

const DEAD_ZONE := 15.0          # 摇杆水平死区（像素），超过才触发方向
const KNOB_RADIUS := 52.0        # 摇杆头最大拖动半径（像素）
const NORMAL_BG := Color(0.18, 0.18, 0.22, 0.82)
const PRESSED_BG := Color(0.48, 0.48, 0.58, 0.95)
const SHOOT_BG := Color(0.62, 0.16, 0.16, 0.92)
const SHOOT_PRESSED := Color(0.9, 0.32, 0.32, 1.0)
const BASE_BG := Color(0.22, 0.22, 0.28, 0.55)
const KNOB_BG := Color(0.55, 0.55, 0.65, 0.95)

var joy_area: Control
var joy_base: ColorRect
var joy_knob: ColorRect
var joy_index := -1
var joy_h_dir := ""              # "", "left", "right"
var buttons: Dictionary = {}

# ---- V1.2 追加：自定义按钮（商店/暂停），不映射 Input 动作，直接调用 game 节点 ----
var custom_buttons: Dictionary = {}

# ---- V1.2 P2 触摸双人（可选，预留接口）----
# V1.2 不实现完整 P2 触摸布局（需第二套摇杆+按钮，屏占比复杂），仅预留开关变量。
# 桌面端 P2 仍使用小键盘键位（V1.1 已实现），不受影响。P2 触摸布局留作后续扩展。
var p2_touch_enabled: bool = false


func _ready() -> void:
	var show_touch := OS.has_feature("mobile")
	# 进一步检测触摸屏能力（桌面接外接触屏时也启用）
	if DisplayServer.is_touchscreen_available():
		show_touch = true
	if not show_touch:
		visible = false
		return

	joy_area = $JoyArea
	joy_base = $JoyArea/JoyBase
	joy_knob = $JoyArea/JoyBase/JoyKnob
	joy_base.visible = false
	joy_base.color = BASE_BG
	joy_knob.color = KNOB_BG

	_register_button("BtnShoot", "shoot", SHOOT_BG, SHOOT_PRESSED)
	_register_button("BtnJump", "jump", NORMAL_BG, PRESSED_BG)
	_register_button("BtnMelee", "melee", NORMAL_BG, PRESSED_BG)
	_register_button("BtnSpecial", "special", NORMAL_BG, PRESSED_BG)
	_register_button("BtnCrouch", "crouch", NORMAL_BG, PRESSED_BG)
	_register_button("BtnRestart", "restart", NORMAL_BG, PRESSED_BG)

	# ---- V1.2 追加：互动键复用 crouch 动作（载具上下车/收服求饶丧尸/拾取）----
	_register_button("BtnInteract", "crouch", NORMAL_BG, PRESSED_BG)
	# ---- V1.2 追加：商店键 / 暂停键（不映射 Input 动作，按下直接调用 game 函数）----
	_register_custom_button("BtnShop", "shop")
	_register_custom_button("BtnPause", "pause")


# ---- V1.2 追加：注册不映射 Input 动作的自定义触摸按钮（商店/暂停）----
func _register_custom_button(node_name: String, kind: String) -> void:
	var n := get_node_or_null(node_name)
	if n == null:
		return
	var bg := n.get_node_or_null("Bg") as ColorRect
	custom_buttons[n] = { "kind": kind, "index": -1, "bg": bg, "normal": NORMAL_BG, "pressed": PRESSED_BG }
	if bg:
		bg.color = NORMAL_BG


func _register_button(node_name: String, action: String, normal: Color, pressed: Color) -> void:
	var n := get_node_or_null(node_name)
	if n == null:
		return
	var bg := n.get_node_or_null("Bg") as ColorRect
	buttons[n] = { "action": action, "index": -1, "bg": bg, "normal": normal, "pressed": pressed }
	if bg:
		bg.color = normal


func _input(event: InputEvent) -> void:
	if not visible:
		return
	if event is InputEventScreenTouch:
		_touch(event as InputEventScreenTouch)
	elif event is InputEventScreenDrag:
		_drag(event as InputEventScreenDrag)


func _touch(ev: InputEventScreenTouch) -> void:
	if ev.pressed:
		if joy_index == -1 and joy_area.get_global_rect().has_point(ev.position):
			joy_index = ev.index
			joy_base.visible = true
			_move_knob(ev.position)
			return
		for b in buttons:
			var info: Dictionary = buttons[b]
			if info["index"] == -1 and b.get_global_rect().has_point(ev.position):
				info["index"] = ev.index
				Input.action_press(info["action"])
				if info["bg"]:
					info["bg"].color = info["pressed"]
				# restart：仅在结算界面显示时直接重开，避免误触打断正常游戏
				if info["action"] == "restart" and _is_game_over():
					get_tree().reload_current_scene()
				return
	else:
		if ev.index == joy_index:
			_release_joy()
			return
		for b in buttons:
			var info: Dictionary = buttons[b]
			if info["index"] == ev.index:
				Input.action_release(info["action"])
				info["index"] = -1
				if info["bg"]:
					info["bg"].color = info["normal"]
				return

	# ---- V1.2 追加：自定义按钮（商店/暂停）独立多点触控跟踪，可与摇杆/其他键同时按下 ----
	if ev.pressed:
		for b in custom_buttons:
			var info: Dictionary = custom_buttons[b]
			if info["index"] == -1 and b.get_global_rect().has_point(ev.position):
				info["index"] = ev.index
				if info["bg"]:
					info["bg"].color = info["pressed"]
				_on_custom_button_pressed(info["kind"])
				return
	else:
		for b in custom_buttons:
			var info: Dictionary = custom_buttons[b]
			if info["index"] == ev.index:
				info["index"] = -1
				if info["bg"]:
					info["bg"].color = info["normal"]
				return


# ---- V1.2 追加：自定义按钮按下回调（商店开关 / 暂停菜单开关），找不到 game 节点不报错 ----
func _on_custom_button_pressed(kind: String) -> void:
	var g := _find_game()
	if g == null:
		return
	if kind == "shop" and g.has_method("_toggle_shop"):
		g._toggle_shop()
	elif kind == "pause" and g.has_method("toggle_pause"):
		g.toggle_pause()


# ---- V1.2 追加：查找游戏主节点（当前场景根即 Game），找不到返回 null ----
func _find_game() -> Node:
	var cs := get_tree().current_scene
	if cs and (cs.has_method("_toggle_shop") or cs.has_method("toggle_pause")):
		return cs
	var root_game := get_node_or_null("/root/Game")
	if root_game:
		return root_game
	return null


func _drag(ev: InputEventScreenDrag) -> void:
	if ev.index != joy_index:
		return
	_move_knob(ev.position)


func _move_knob(world_pos: Vector2) -> void:
	var center := joy_base.global_position + joy_base.size * 0.5
	var off := world_pos - center
	if off.length() > KNOB_RADIUS:
		off = off.normalized() * KNOB_RADIUS
	joy_knob.position = joy_base.size * 0.5 - joy_knob.size * 0.5 + off
	var h := off.x
	if absf(h) > DEAD_ZONE:
		var dir := "right" if h > 0.0 else "left"
		if joy_h_dir != dir:
			_release_h_dir()
			Input.action_press("move_" + dir)
			joy_h_dir = dir
	else:
		_release_h_dir()


func _release_joy() -> void:
	_release_h_dir()
	joy_index = -1
	joy_base.visible = false
	joy_knob.position = joy_base.size * 0.5 - joy_knob.size * 0.5


func _release_h_dir() -> void:
	if joy_h_dir == "left":
		Input.action_release("move_left")
	elif joy_h_dir == "right":
		Input.action_release("move_right")
	joy_h_dir = ""


func _is_game_over() -> bool:
	var hud := get_parent().get_node_or_null("HUD")
	if hud == null:
		return false
	var go := hud.get_node_or_null("GameOver")
	return go != null and go.visible
