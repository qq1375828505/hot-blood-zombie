extends Node
# 输入映射注册（代码注册，避免手写复杂的事件对象）
# 战斗核心需要的 action：move_left, move_right, move_up, move_down, punch, kick, jump, weapon
# 触控按钮由 touch_controls.gd 触发这些 action（子代理C负责触控脚本对接）。
# 同时保留旧 action 名以兼容现有 touch_controls.gd，待子代理C更新后可清理。

func _ready() -> void:
	# ---- 新战斗核心 action ----
	_add_key_action("move_left", [KEY_A, KEY_LEFT])
	_add_key_action("move_right", [KEY_D, KEY_RIGHT])
	_add_key_action("move_up", [KEY_W, KEY_UP])
	_add_key_action("move_down", [KEY_S, KEY_DOWN])
	_add_key_action("jump", [KEY_SPACE])
	_add_key_action("punch", [KEY_J])
	_add_key_action("kick", [KEY_K])
	_add_key_action("weapon", [KEY_L])

	# ---- 旧 action 兼容（touch_controls.gd 当前引用，子代理C更新后可删除）----
	_add_key_action("crouch", [])		# 旧 crouch → 映射到 move_down
	_add_key_action("shoot", [])		# 旧 shoot → 待子代理C映射到 punch
	_add_key_action("melee", [])		# 旧 melee → 待子代理C映射到 kick
	_add_key_action("special", [])		# 旧 special → 待子代理C映射到 weapon
	_add_key_action("restart", [KEY_R])

	# 鼠标左键 = punch（桌面端点击出拳）
	var mb := InputEventMouseButton.new()
	mb.button_index = MOUSE_BUTTON_LEFT
	InputMap.action_add_event("punch", mb)

	# P2 键位（小键盘，与 P1 不冲突）—— 保留旧双人支持
	_add_key_action("p2_move_left", [KEY_KP_4])
	_add_key_action("p2_move_right", [KEY_KP_6])
	_add_key_action("p2_jump", [KEY_KP_8])
	_add_key_action("p2_punch", [KEY_KP_7])
	_add_key_action("p2_kick", [KEY_KP_9])
	_add_key_action("p2_weapon", [KEY_KP_PLUS])


func _add_key_action(action: String, keys: Array) -> void:
	if not InputMap.has_action(action):
		InputMap.add_action(action)
	for k in keys:
		var ev := InputEventKey.new()
		ev.physical_keycode = k
		InputMap.action_add_event(action, ev)
