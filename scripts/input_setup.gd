extends Node
# 输入映射注册（代码注册，避免手写复杂的事件对象）
# 桌面端：A/D 或方向键移动，W/空格 跳跃，S 下蹲，J/鼠标左键 射击，K 近战，L 必杀，R 重开

func _ready() -> void:
	_add_key_action("move_left", [KEY_A, KEY_LEFT])
	_add_key_action("move_right", [KEY_D, KEY_RIGHT])
	_add_key_action("jump", [KEY_W, KEY_UP, KEY_SPACE])
	_add_key_action("crouch", [KEY_S, KEY_DOWN])
	_add_key_action("shoot", [KEY_J])
	_add_key_action("melee", [KEY_K])
	_add_key_action("special", [KEY_L])
	_add_key_action("restart", [KEY_R])

	# ---- V1.1 本地双人：P2 键位（小键盘，与 P1 完全不冲突）----
	_add_key_action("p2_move_left", [KEY_KP_4])
	_add_key_action("p2_move_right", [KEY_KP_6])
	_add_key_action("p2_jump", [KEY_KP_8])
	_add_key_action("p2_crouch", [KEY_KP_5])
	_add_key_action("p2_shoot", [KEY_KP_ENTER])
	_add_key_action("p2_melee", [KEY_KP_ADD])
	_add_key_action("p2_special", [KEY_KP_SUBTRACT])
	_add_key_action("p2_restart", [KEY_KP_MULTIPLY])

	if not InputMap.has_action("shoot"):
		InputMap.add_action("shoot")
	var mb := InputEventMouseButton.new()
	mb.button_index = MOUSE_BUTTON_LEFT
	InputMap.action_add_event("shoot", mb)


func _add_key_action(action: String, keys: Array) -> void:
	if not InputMap.has_action(action):
		InputMap.add_action(action)
	for k in keys:
		var ev := InputEventKey.new()
		ev.physical_keycode = k
		InputMap.action_add_event(action, ev)
