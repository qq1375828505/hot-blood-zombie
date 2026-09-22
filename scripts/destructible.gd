extends StaticBody2D
class_name Destructible
# 可破坏街景物（自动贩卖机 / 垃圾桶 / 轮胎 / 木箱 / 课桌椅）。
# 命中方式：子节点 HitArea(Area2D) 检测子弹(Area2D, layer=1) 的 area_entered，
#   命中后调用 take_damage 并销毁子弹；N 次后破坏、弹出掉落物。
# 不阻挡玩家：根 StaticBody2D 放在第 4 层（layer 4, 值 8），玩家/丧尸 mask=3 不与其碰撞。
# V2.2：新增 destructible_type 字段区分 generic / vending_machine；
#   vending_machine 2 次命中破坏，掉落 1~2 个补给品。

@export var item_type: String = "ammo"   # 破坏后掉落物类型（generic 类型使用）
@export var destructible_type: String = "generic"  # "generic" 或 "vending_machine"

const DEFAULT_MAX_HITS := 3
const VENDING_MAX_HITS := 2
const VENDING_DROPS: Array[String] = ["food_drink", "food_onigiri", "food_noodles", "first_aid"]

var _hits := 0
var _max_hits: int = DEFAULT_MAX_HITS


func _ready() -> void:
	if destructible_type == "vending_machine":
		_max_hits = VENDING_MAX_HITS
		_setup_vending_machine_visual()
	var area := get_node_or_null("HitArea") as Area2D
	if area:
		area.area_entered.connect(_on_area_entered)


func _setup_vending_machine_visual() -> void:
	# 自动贩卖机外观：红色主体 + 上方展示窗 + 下方取货口
	var body := get_node_or_null("Body") as ColorRect
	if body:
		body.color = Color(0.75, 0.15, 0.15, 1.0)  # 饮料品牌红
		# 适配高大矩形 24x50
		body.offset_left = -12.0
		body.offset_right = 12.0
		body.offset_top = -25.0
		body.offset_bottom = 25.0
	# 展示窗（浅蓝色 18x15）
	var display := get_node_or_null("DisplayWindow") as ColorRect
	if display == null:
		display = ColorRect.new()
		display.name = "DisplayWindow"
		add_child(display)
	display.offset_left = -9.0
	display.offset_right = 9.0
	display.offset_top = -20.0
	display.offset_bottom = -5.0
	display.color = Color(0.40, 0.70, 0.95, 1.0)
	# 取货口（黑色 12x6）
	var hole := get_node_or_null("PickupHole") as ColorRect
	if hole == null:
		hole = ColorRect.new()
		hole.name = "PickupHole"
		add_child(hole)
	hole.offset_left = -6.0
	hole.offset_right = 6.0
	hole.offset_top = 12.0
	hole.offset_bottom = 18.0
	hole.color = Color(0.05, 0.05, 0.05, 1.0)


func _on_area_entered(area: Area2D) -> void:
	if _hits >= _max_hits:
		return
	take_damage(2)
	if is_instance_valid(area):
		area.queue_free()


func take_damage(_dmg: int) -> void:
	_hits += 1
	var body := get_node_or_null("Body") as ColorRect
	if body:
		var f: float = clampf(1.0 - float(_hits) / float(_max_hits), 0.15, 1.0)
		body.modulate = Color(f, f, f)
	# 命中左右抖动
	var shake := create_tween()
	shake.tween_property(self, "position:x", position.x + 3.0, 0.05)
	shake.tween_property(self, "position:x", position.x - 3.0, 0.05)
	shake.tween_property(self, "position:x", position.x, 0.04)
	if _hits >= _max_hits:
		_destroy()


func _destroy() -> void:
	_spawn_drop()
	queue_free()


func _spawn_drop() -> void:
	if destructible_type == "vending_machine":
		_spawn_vending_drops()
	else:
		_spawn_single_drop(item_type, 0.0)


func _spawn_vending_drops() -> void:
	# 自动贩卖机破坏：随机掉落 1~2 个补给品
	var num_drops := randi_range(1, 2)
	for i in range(num_drops):
		var drop_item: String = VENDING_DROPS[randi() % VENDING_DROPS.size()]
		_spawn_single_drop(drop_item, float(i * 18.0) - 9.0)


func _spawn_single_drop(drop_item: String, offset_x: float) -> void:
	var drop_script := preload("res://scripts/item_pickup.gd")
	var drop := Area2D.new()
	drop.set_script(drop_script)
	drop.set("item_type", drop_item)

	var parent_node := get_parent()
	var local_pos := to_local(global_position)
	parent_node.add_child(drop)
	drop.position = local_pos + Vector2(offset_x, 0.0)

	# 触发碰撞体
	var cs := CollisionShape2D.new()
	var shape := RectangleShape2D.new()
	shape.size = Vector2(18, 14)
	cs.shape = shape
	drop.add_child(cs)

	# 掉落物视觉（弹药盒/金币/近战武器）
	var vr := ColorRect.new()
	var drop_size := Vector2(16, 10)
	match drop_item:
		"coin":
			vr.color = Color(1.0, 0.85, 0.3, 1.0)
		"iron_pipe":
			vr.color = Color(0.7, 0.7, 0.72, 1.0)  # 银灰
			drop_size = Vector2(22, 6)
		"tire":
			vr.color = Color(0.08, 0.08, 0.08, 1.0)  # 黑
			drop_size = Vector2(20, 20)
		"trash_lid":
			vr.color = Color(0.15, 0.35, 0.2, 1.0)  # 深绿
			drop_size = Vector2(18, 18)
		"food_drink":
			vr.color = Color(0.20, 0.50, 0.90, 1.0)  # 饮料蓝
			drop_size = Vector2(8, 12)
		"food_onigiri":
			vr.color = Color(0.95, 0.95, 0.95, 1.0)  # 饭团白
			drop_size = Vector2(14, 10)
		"food_noodles":
			vr.color = Color(0.85, 0.20, 0.15, 1.0)  # 泡面红
			drop_size = Vector2(14, 10)
		"first_aid":
			vr.color = Color(0.95, 0.95, 0.95, 1.0)  # 急救箱白
			drop_size = Vector2(16, 12)
		_:
			vr.color = Color(0.9, 0.7, 0.2, 1.0)  # 弹药盒
	vr.offset_left = -drop_size.x / 2.0
	vr.offset_top = -drop_size.y / 2.0
	vr.offset_right = drop_size.x / 2.0
	vr.offset_bottom = drop_size.y / 2.0
	drop.add_child(vr)

	# 弹出动画：上抛后落地
	var tw := get_tree().create_tween()
	tw.tween_property(drop, "position:y", drop.position.y - 44.0, 0.18).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_property(drop, "position:y", drop.position.y - 4.0, 0.24).set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_IN)
