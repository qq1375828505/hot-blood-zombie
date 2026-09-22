extends Node2D
# 关卡主控（V1.0 黄昏町街道）：远景霓虹灯闪烁 + 发呆丧尸/整理头发氛围演出。
# 物品拾取（item_pickup.gd）与可破坏物（destructible.gd）均通过信号与 game.gd 解耦，
# 具体数值结算由后续在 game.gd 中连接 item_picked 信号处理。
# V1.2：新增 level_index 导出（1=街道 / 2=白鹰高中 / 3=暴走族聚集地），
# 追加 "flicker" 组（教室灯光快速闪）与 "fire" 组（火光颜色渐变），不改 level1 霓虹逻辑。

@export var level_index: int = 1


func _ready() -> void:
	_setup_neon_flicker()
	_setup_idle_shows()
	# V1.2 追加：新关卡氛围闪烁（level1 无 flicker/fire 组节点，调用为空操作）
	_setup_flicker()
	_setup_fire_glow()


func _setup_neon_flicker() -> void:
	# 远景霓虹招牌：透明度循环闪烁
	for c in find_children("*", "ColorRect", true, false):
		if c is ColorRect and c.is_in_group("neon"):
			var tw := create_tween().set_loops()
			tw.tween_property(c, "modulate:a", 0.35, 0.5)
			tw.tween_property(c, "modulate:a", 1.0, 0.7)


func _setup_idle_shows() -> void:
	# 放置的 zombie 实例未调用 setup()，player=null，原地站立发呆。
	# 标记 hair_fix 的丧尸循环抬臂摸头；其余丧尸头部微微摇摆。
	for z in find_children("*", "Zombie", true, false):
		if not (z is Node2D):
			continue
		if z.is_in_group("hair_fix") and z.has_node("Visual/ArmR"):
			var arm: Node2D = z.get_node("Visual/ArmR")
			var tw := create_tween().set_loops()
			tw.tween_property(arm, "rotation", -2.3, 0.5)
			tw.tween_property(arm, "rotation", 1.45, 0.6)
		elif z.has_node("Visual/Head"):
			var hd: Node2D = z.get_node("Visual/Head")
			var tw := create_tween().set_loops()
			tw.tween_property(hd, "rotation", 0.15, 1.2)
			tw.tween_property(hd, "rotation", -0.12, 1.2)


# ---- V1.2 追加：flicker 组（教室灯/走廊灯快速明暗闪）----
func _setup_flicker() -> void:
	for c in find_children("*", "ColorRect", true, false):
		if c is ColorRect and c.is_in_group("flicker"):
			var tw := create_tween().set_loops()
			tw.tween_property(c, "modulate:a", 0.45, 0.18)
			tw.tween_property(c, "modulate:a", 1.0, 0.22)
			tw.tween_property(c, "modulate:a", 0.6, 0.12)
			tw.tween_property(c, "modulate:a", 1.0, 0.30)


# ---- V1.2 追加：fire 组（远处火光颜色在橙红/亮黄间渐变）----
func _setup_fire_glow() -> void:
	for c in find_children("*", "ColorRect", true, false):
		if c is ColorRect and c.is_in_group("fire"):
			var base: Color = c.color
			var hot := Color(1.0, 0.85, 0.35, base.a)
			var dim := Color(0.85, 0.25, 0.10, base.a)
			var tw := create_tween().set_loops()
			tw.tween_property(c, "color", hot, 0.45).set_trans(Tween.TRANS_SINE)
			tw.tween_property(c, "color", dim, 0.7).set_trans(Tween.TRANS_SINE)
			tw.tween_property(c, "color", base, 0.35).set_trans(Tween.TRANS_SINE)
