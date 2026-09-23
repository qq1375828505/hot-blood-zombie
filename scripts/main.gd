extends Node2D
## 战斗场景控制器 —— 选人 → 战斗 → 金币掉落 → 商店 → 成就 → 下一关
## 对外暴露 kills / wave 供成就系统轮询，暴露 _toggle_shop() 供触摸商店按钮调用

# ---- 供成就系统读取的公开状态 ----
var kills: int = 0
var wave: int = 0

# ---- 节点引用 ----
@onready var player: CharacterBody2D = $Player
@onready var spawner: Node2D = $EnemySpawner
@onready var hud: CanvasLayer = $HUD
@onready var camera: Camera2D = $Camera2D

# ---- 运行时 ----
var _shop: CanvasLayer = null
var _game_over: bool = false


func _ready() -> void:
	# 配置刷怪器
	spawner.enemy_scene = preload("res://scenes/enemy.tscn")
	spawner.player_path = NodePath("../Player")
	spawner.player = player
	# HUD 初始化
	hud.setup(player, spawner)
	# 玩家命中 → 镜头震动
	if player.has_signal("attack_landed"):
		player.attack_landed.connect(_on_attack_landed)
	# 玩家死亡
	if player.has_signal("died"):
		player.died.connect(_on_player_died)
	# 波次开始 → 更新 wave（成就系统轮询）
	if spawner.has_signal("wave_started"):
		spawner.wave_started.connect(_on_wave_started)
	# 敌人死亡 → 击杀计数
	if spawner.has_signal("enemy_died"):
		spawner.enemy_died.connect(_on_enemy_killed)
	# 全部波次清完 → 关卡完成 → 商店
	if spawner.has_signal("all_waves_cleared"):
		spawner.all_waves_cleared.connect(_on_all_waves_cleared)
	# 金币变化 → HUD 实时刷新
	if not Economy.coins_changed.is_connected(_on_coins_changed):
		Economy.coins_changed.connect(_on_coins_changed)
	_on_coins_changed(Economy.coins)


func _on_wave_started(wave_num: int) -> void:
	wave = wave_num


func _on_enemy_killed(_enemy) -> void:
	kills += 1
	if hud.has_method("set_kills"):
		hud.set_kills(kills)


func _on_coins_changed(amount: int) -> void:
	if hud.has_method("set_coins"):
		hud.set_coins(amount)


func _on_attack_landed(hitstop_duration: float) -> void:
	## 命中顿帧 + 屏幕震动
	var feel: Dictionary = CombatConfig.get_feel()
	var shake_amt: float = feel.get("camera_shake_amount", 6.0)
	var shake_dur: float = feel.get("camera_shake_duration", 0.15)
	var orig_x := camera.offset.x
	var orig_y := camera.offset.y
	var tween := create_tween()
	# X 轴震动
	tween.tween_property(camera, "offset:x", orig_x + shake_amt, 0.03)
	tween.tween_property(camera, "offset:x", orig_x - shake_amt, 0.06)
	tween.tween_property(camera, "offset:x", orig_x + shake_amt * 0.5, 0.04)
	tween.tween_property(camera, "offset:x", orig_x, shake_dur)
	# Y 轴震动（错开相位）
	tween.tween_interval(0.02)
	tween.tween_property(camera, "offset:y", orig_y + shake_amt * 0.4, 0.04)
	tween.tween_property(camera, "offset:y", orig_y, shake_dur)


# ============================================================
# 商店开关（触摸商店按钮 / 通关后自动打开）
# ============================================================
func _toggle_shop() -> void:
	if _shop != null and is_instance_valid(_shop):
		_close_shop()
	else:
		_open_shop()


func _open_shop() -> void:
	if _shop != null and is_instance_valid(_shop):
		return
	var shop_scene: PackedScene = load("res://scenes/shop.tscn")
	_shop = shop_scene.instantiate() as CanvasLayer
	add_child(_shop)
	# shop.open() 内部会 get_tree().paused = true（shop.tscn process_mode=WHEN_PAUSED）
	_shop.open()


func _close_shop() -> void:
	if _shop != null and is_instance_valid(_shop):
		_shop.close()
		_shop.queue_free()
	_shop = null


# ============================================================
# 全部波次清完 → 关卡完成 → 商店 → 重开（金币保留）
# ============================================================
func _on_all_waves_cleared() -> void:
	if _game_over:
		return
	# 居中提示 2 秒
	hud.center_msg.text = "关卡完成！"
	hud.center_msg.modulate.a = 1.0
	await get_tree().create_timer(2.0).timeout
	if not is_inside_tree():
		return
	# 自动打开商店
	_open_shop()
	# 等商店关闭后重开当前场景（Economy 为 Autoload，金币保留）
	while _shop != null and is_instance_valid(_shop) and Economy.shop_open:
		await get_tree().create_timer(0.5).timeout
	if _game_over or not is_inside_tree():
		return
	get_tree().reload_current_scene()


# ============================================================
# 玩家死亡 → 金币减半 → 游戏结束
# ============================================================
func _on_player_died() -> void:
	if _game_over:
		return
	_game_over = true
	# 清掉商店（若开着）并恢复时间
	_close_shop()
	# 金币减半
	Economy.on_player_death()
	hud.center_msg.text = "你死了！金币减半 → %d" % Economy.coins
	hud.center_msg.modulate.a = 1.0
	await get_tree().create_timer(3.0).timeout
	if not is_inside_tree():
		return
	hud.center_msg.text = "按重开键重新开始"
	# 显示 GameOver 面板，让触摸重开键生效（touch_controls._is_game_over 检测该节点）
	var go := hud.get_node_or_null("GameOver")
	if go:
		go.visible = true
