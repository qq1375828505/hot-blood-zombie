extends CanvasLayer
# 移动端触摸控件 V2.1：左下角常驻半透明大摇杆 + 右下角大圆按钮组。
# 强制显示：打开游戏即出现虚拟按键，不做设备检测。
# 摇杆：左右 = move_left/move_right（按住），上 = jump（轻点），下 = crouch（按住）。
# 右下红按钮=拳(punch)、蓝按钮=跳(jump)、黄按钮=武器(weapon)、白按钮=脚踢(kick)。
# 按钮通过 Input.action_press / Input.action_release 驱动已注册输入动作，与键盘共用同一套 action。

const DEAD_ZONE := 15.0
const KNOB_RADIUS := 55.0

# 各按钮正常/按下配色（按下提亮 + 提高不透明度）
const SHOOT_NORMAL := Color(0.85, 0.15, 0.15, 0.85)
const SHOOT_PRESSED := Color(1.0, 0.38, 0.38, 1.0)
const JUMP_NORMAL := Color(0.2, 0.45, 0.85, 0.85)
const JUMP_PRESSED := Color(0.4, 0.65, 1.0, 1.0)
const SPECIAL_NORMAL := Color(0.95, 0.75, 0.15, 0.85)
const SPECIAL_PRESSED := Color(1.0, 0.9, 0.35, 1.0)
const WHITE_NORMAL := Color(0.92, 0.92, 0.95, 0.8)
const WHITE_PRESSED := Color(1.0, 1.0, 1.0, 0.95)
const SMALL_NORMAL := Color(0.85, 0.85, 0.9, 0.5)
const SMALL_PRESSED := Color(0.95, 0.95, 1.0, 0.85)
const CUSTOM_NORMAL := Color(0.25, 0.25, 0.3, 0.5)
const CUSTOM_PRESSED := Color(0.45, 0.45, 0.55, 0.85)

var joy_area: Control
var joy_base: Panel
var joy_knob: Panel
var joy_index := -1
var joy_h_dir := ""
var joy_v_dir := ""
var buttons: Dictionary = {}
var custom_buttons: Dictionary = {}

var p2_touch_enabled: bool = false


func _ready() -> void:
	# 强制显示虚拟按键：不做设备检测，打开游戏即出现
	visible = true

	joy_area = $JoyArea
	joy_base = $JoyArea/JoyBase
	joy_knob = $JoyArea/JoyBase/JoyKnob
	joy_base.visible = true

	_register_button("BtnShoot", "punch", SHOOT_NORMAL, SHOOT_PRESSED)
	_register_button("BtnJump", "jump", JUMP_NORMAL, JUMP_PRESSED)
	_register_button("BtnMelee", "kick", WHITE_NORMAL, WHITE_PRESSED)
	_register_button("BtnSpecial", "weapon", SPECIAL_NORMAL, SPECIAL_PRESSED)
	_register_button("BtnCrouch", "crouch", SMALL_NORMAL, SMALL_PRESSED)
	_register_button("BtnRestart", "restart", CUSTOM_NORMAL, CUSTOM_PRESSED)

	# 互动键复用 crouch 动作
	_register_button("BtnInteract", "crouch", SMALL_NORMAL, SMALL_PRESSED)
	# 商店 / 暂停（自定义回调）
	_register_custom_button("BtnShop", "shop")
	_register_custom_button("BtnPause", "pause")


# 把按钮 Panel 的共享 stylebox 复制成独立实例，避免按一个按钮污染其它。
func _make_unique_style(node: Node) -> StyleBoxFlat:
	var panel := node as Panel
	if panel == null:
		return null
	var sb := panel.get_theme_stylebox("panel") as StyleBoxFlat
	if sb == null:
		return null
	var dup := sb.duplicate() as StyleBoxFlat
	panel.add_theme_stylebox_override("panel", dup)
	return dup


func _register_button(node_name: String, action: String, normal: Color, pressed: Color) -> void:
	var n := get_node_or_null(node_name)
	if n == null:
		return
	var sb := _make_unique_style(n)
	if sb:
		sb.bg_color = normal
	buttons[n] = { "action": action, "index": -1, "style": sb, "normal": normal, "pressed": pressed }


func _register_custom_button(node_name: String, kind: String) -> void:
	var n := get_node_or_null(node_name)
	if n == null:
		return
	var sb := _make_unique_style(n)
	if sb:
		sb.bg_color = CUSTOM_NORMAL
	custom_buttons[n] = { "kind": kind, "index": -1, "style": sb, "normal": CUSTOM_NORMAL, "pressed": CUSTOM_PRESSED }


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
			_move_knob(ev.position)
			return
		for b in buttons:
			var info: Dictionary = buttons[b]
			if info["index"] == -1 and b.get_global_rect().has_point(ev.position):
				info["index"] = ev.index
				Input.action_press(info["action"])
				if info["style"]:
					info["style"].bg_color = info["pressed"]
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
				if info["style"]:
					info["style"].bg_color = info["normal"]
				return

	# 自定义按钮（商店/暂停）
	if ev.pressed:
		for b in custom_buttons:
			var info: Dictionary = custom_buttons[b]
			if info["index"] == -1 and b.get_global_rect().has_point(ev.position):
				info["index"] = ev.index
				if info["style"]:
					info["style"].bg_color = info["pressed"]
				_on_custom_button_pressed(info["kind"])
				return
	else:
		for b in custom_buttons:
			var info: Dictionary = custom_buttons[b]
			if info["index"] == ev.index:
				info["index"] = -1
				if info["style"]:
					info["style"].bg_color = info["normal"]
				return


func _on_custom_button_pressed(kind: String) -> void:
	var g := _find_game()
	if g == null:
		return
	if kind == "shop" and g.has_method("_toggle_shop"):
		g._toggle_shop()
	elif kind == "pause" and g.has_method("toggle_pause"):
		g.toggle_pause()


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

	# ---- 水平轴：左右移动（按住） ----
	var h := off.x
	if absf(h) > DEAD_ZONE:
		var dir := "right" if h > 0.0 else "left"
		if joy_h_dir != dir:
			_release_h_dir()
			Input.action_press("move_" + dir)
			joy_h_dir = dir
	else:
		_release_h_dir()

	# ---- 垂直轴：上 = 跳（轻点），下 = 蹲（按住） ----
	var v := off.y
	if v < -DEAD_ZONE:
		# 上推 → 跳（仅在进入上推边缘时触发一次）
		if joy_v_dir != "up":
			_release_v_dir()
			Input.action_press("jump")
			Input.action_release("jump")
			joy_v_dir = "up"
	elif v > DEAD_ZONE:
		# 下推 → 蹲（按住）
		if joy_v_dir != "down":
			_release_v_dir()
			Input.action_press("crouch")
			joy_v_dir = "down"
	else:
		_release_v_dir()


func _release_joy() -> void:
	_release_h_dir()
	_release_v_dir()
	joy_index = -1
	# 摇杆底座常驻：只复位 knob，不隐藏
	joy_knob.position = joy_base.size * 0.5 - joy_knob.size * 0.5


func _release_h_dir() -> void:
	if joy_h_dir == "left":
		Input.action_release("move_left")
	elif joy_h_dir == "right":
		Input.action_release("move_right")
	joy_h_dir = ""


func _release_v_dir() -> void:
	if joy_v_dir == "down":
		Input.action_release("crouch")
	joy_v_dir = ""


func _is_game_over() -> bool:
	var hud := get_parent().get_node_or_null("HUD")
	if hud == null:
		return false
	var go := hud.get_node_or_null("GameOver")
	return go != null and go.visible
