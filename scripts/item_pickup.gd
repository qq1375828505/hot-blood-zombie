extends Area2D
class_name ItemPickup
# 可拾取物（武器 / 回复道具 / 破坏掉落物）。
# 玩家走入触发区即拾取，发出 item_picked 信号；数值结算由 game.gd 连接后处理。

signal item_picked(item_type: String)
@export var item_type: String = "ammo"


func _ready() -> void:
	collision_mask = 1   # 检测玩家（Player 在 layer 1）
	collision_layer = 0
	body_entered.connect(_on_body_entered)
	# V1.1 急救箱：白底 + 红色十字视觉
	if item_type == "first_aid":
		_setup_first_aid_visual()
	# V2.1 近战武器拾取视觉
	elif item_type in ["iron_pipe", "tire", "trash_lid"]:
		_setup_melee_weapon_visual()


func _setup_melee_weapon_visual() -> void:
	var icon: ColorRect = get_node_or_null("Icon") as ColorRect
	if icon == null:
		return
	match item_type:
		"iron_pipe":
			icon.color = Color(0.7, 0.7, 0.72, 1.0)  # 银灰
			icon.offset_left = -12.0
			icon.offset_right = 12.0
			icon.offset_top = -3.0
			icon.offset_bottom = 3.0
		"tire":
			icon.color = Color(0.08, 0.08, 0.08, 1.0)  # 黑
			icon.offset_left = -10.0
			icon.offset_right = 10.0
			icon.offset_top = -10.0
			icon.offset_bottom = 10.0
		"trash_lid":
			icon.color = Color(0.15, 0.35, 0.2, 1.0)  # 深绿
			icon.offset_left = -9.0
			icon.offset_right = 9.0
			icon.offset_top = -9.0
			icon.offset_bottom = 9.0


func _setup_first_aid_visual() -> void:
	var icon: ColorRect = $Icon
	icon.color = Color(0.95, 0.95, 0.95, 1.0)  # 白底
	# 红色十字（竖 + 横）
	var v := ColorRect.new()
	v.color = Color(0.85, 0.1, 0.1, 1.0)
	v.offset_left = -1.5
	v.offset_top = -6.0
	v.offset_right = 1.5
	v.offset_bottom = 6.0
	icon.add_child(v)
	var h := ColorRect.new()
	h.color = Color(0.85, 0.1, 0.1, 1.0)
	h.offset_left = -6.0
	h.offset_top = -1.5
	h.offset_right = 6.0
	h.offset_bottom = 1.5
	icon.add_child(h)


func _on_body_entered(body: Node2D) -> void:
	if body is Player and not is_queued_for_deletion():
		item_picked.emit(item_type)
		queue_free()
