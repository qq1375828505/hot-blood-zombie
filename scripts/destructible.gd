extends StaticBody2D
class_name Destructible
# 可破坏街景物（自动贩卖机 / 垃圾桶 / 轮胎 / 木箱）。
# 命中方式：子节点 HitArea(Area2D) 检测子弹(Area2D, layer=1) 的 area_entered，
#   命中后调用 take_damage 并销毁子弹；3 次后破坏、弹出掉落物。
# 不阻挡玩家：根 StaticBody2D 放在第 4 层（layer 4, 值 8），玩家/丧尸 mask=3 不与其碰撞。

@export var item_type: String = "ammo"   # 破坏后掉落物类型
const MAX_HITS := 3
var _hits := 0


func _ready() -> void:
	var area := get_node_or_null("HitArea") as Area2D
	if area:
		area.area_entered.connect(_on_area_entered)


func _on_area_entered(area: Area2D) -> void:
	if _hits >= MAX_HITS:
		return
	take_damage(2)
	if is_instance_valid(area):
		area.queue_free()


func take_damage(_dmg: int) -> void:
	_hits += 1
	var body := get_node_or_null("Body") as ColorRect
	if body:
		var f: float = clampf(1.0 - float(_hits) / float(MAX_HITS), 0.15, 1.0)
		body.modulate = Color(f, f, f)
	# 命中左右抖动
	var shake := create_tween()
	shake.tween_property(self, "position:x", position.x + 3.0, 0.05)
	shake.tween_property(self, "position:x", position.x - 3.0, 0.05)
	shake.tween_property(self, "position:x", position.x, 0.04)
	if _hits >= MAX_HITS:
		_destroy()


func _destroy() -> void:
	_spawn_drop()
	queue_free()


func _spawn_drop() -> void:
	var drop_script := preload("res://scripts/item_pickup.gd")
	var drop := Area2D.new()
	drop.set_script(drop_script)
	drop.set("item_type", item_type)

	var parent_node := get_parent()
	var local_pos := to_local(global_position)
	parent_node.add_child(drop)
	drop.position = local_pos

	# 触发碰撞体
	var cs := CollisionShape2D.new()
	var shape := RectangleShape2D.new()
	shape.size = Vector2(18, 14)
	cs.shape = shape
	drop.add_child(cs)

	# 掉落物视觉（弹药盒/金币）
	var vr := ColorRect.new()
	vr.color = Color(1.0, 0.85, 0.3, 1.0) if item_type == "coin" else Color(0.9, 0.7, 0.2, 1.0)
	vr.offset_left = -8.0
	vr.offset_top = -5.0
	vr.offset_right = 8.0
	vr.offset_bottom = 5.0
	drop.add_child(vr)

	# 弹出动画：上抛后落地
	var tw := get_tree().create_tween()
	tw.tween_property(drop, "position:y", local_pos.y - 44.0, 0.18).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_property(drop, "position:y", local_pos.y - 4.0, 0.24).set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_IN)
