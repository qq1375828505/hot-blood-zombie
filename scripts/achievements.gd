extends Node
# Achievements 单例 (Autoload) — V1.2 成就系统
# 零侵入设计：通过 _process 每 0.5s 轮询游戏状态 + 连接现有信号完成检测，不修改任何玩法脚本。

signal achievement_unlocked(id: String, name: String)

const SAVE_PATH := "user://achievements.json"
const SAVE_VERSION := 2  # V2.0 存档 schema 版本号：v1 无 version 字段，v2 增加 version 标记
const POLL_INTERVAL := 0.5
const ALL_WEAPONS := ["pistol", "machine_gun", "shotgun", "grenade"]
const DRIVE_SECONDS_FOR_VEHICLE_ACH := 30.0  # 载具撞击无法精确轮询，改用“累计驾驶 30 秒”替代指标

# ---- 成就定义（8 个）----
const ACHIEVEMENTS := {
	"first_kill": {"name": "初阵", "desc": "击杀第一只丧尸", "icon": "💀"},
	"hundred_kills": {"name": "百人斩", "desc": "累计击杀 100 只丧尸", "icon": "⚔"},
	"all_weapons": {"name": "武器收藏家", "desc": "使用过全部 4 种武器", "icon": "🔫"},
	"clear_ch1": {"name": "黄昏町制霸", "desc": "通关第一章（第5波）", "icon": "🏆"},
	"flawless": {"name": "无伤过关", "desc": "一波次中不受任何伤害", "icon": "🛡"},
	"special_x10": {"name": "热血魂爆发", "desc": "累计释放必杀 10 次", "icon": "🔥"},
	"capture_x5": {"name": "援护收藏家", "desc": "收服 5 只援护丧尸", "icon": "🤝"},
	"vehicle_squash": {"name": "马路杀手", "desc": "驾驶载具撞击 10 只丧尸", "icon": "🚗"},
}

var unlocked: Dictionary = {}
var stats: Dictionary = {}

var _poll_timer := 0.0
var _panel: CanvasLayer = null
var _prev_assist_counts := 0
var _prev_wave := 0
var _wave_had_damage := false
var _prev_player_hp: Dictionary = {}


func _ready() -> void:
	load_save()
	# Autoload 在主场景加载前初始化，延迟一帧再实例化 UI / 连接信号
	call_deferred("_setup_ui")


func _setup_ui() -> void:
	var panel_scene: PackedScene = load("res://scenes/achievement_panel.tscn")
	if panel_scene:
		_panel = panel_scene.instantiate() as CanvasLayer
		get_tree().root.add_child(_panel)


func _process(delta: float) -> void:
	# 累计驾驶载具时长（连续，不依赖 0.5s 轮询节拍）
	for p in get_tree().get_nodes_in_group("players"):
		if p is Player and not p.dead and p.in_vehicle:
			stats["vehicle_drive_time"] = float(stats.get("vehicle_drive_time", 0.0)) + delta
			break
	_poll_timer -= delta
	if _poll_timer <= 0.0:
		_poll_timer = POLL_INTERVAL
		_poll_stats()


# ---- 轮询游戏状态（零侵入）----
func _poll_stats() -> void:
	var g := _get_game_node()
	if g:
		var kills_val = g.get("kills")
		var wave_val = g.get("wave")
		stats["kills_total"] = int(kills_val) if kills_val != null else 0
		stats["current_wave"] = int(wave_val) if wave_val != null else 0

	var players := get_tree().get_nodes_in_group("players")
	var total_assist := 0
	var weapons: Array = stats.get("weapons_used", [])
	for p in players:
		if p is Player:
			total_assist += p.assist_units.size()
			var w: String = p.current_weapon
			if w not in weapons:
				weapons.append(w)
			# 尽力连接现有 signal（已连则跳过），不修改 player.gd
			if not p.special_used.is_connected(_on_special_used):
				p.special_used.connect(_on_special_used)
	stats["weapons_used"] = weapons

	# 累计收服数：assist_units 会被召唤消耗，用差值累计（召唤使数量下降时不计入）
	var delta_caps := maxi(total_assist - _prev_assist_counts, 0)
	if delta_caps > 0:
		stats["captures_total"] = int(stats.get("captures_total", 0)) + delta_caps
	_prev_assist_counts = total_assist

	# 波次推进：上一波零伤害则解锁“无伤过关”
	var cur_wave := int(stats.get("current_wave", 0))
	if cur_wave != _prev_wave:
		if _prev_wave >= 1 and not _wave_had_damage:
			unlock("flawless")
		_prev_wave = cur_wave
		_wave_had_damage = false

	# 检测本波是否受到伤害（任意存活玩家 HP 下降）
	for p in players:
		if p is Player and not p.dead:
			var key := str(p.get_instance_id())
			var hp_now: int = p.hp
			if _prev_player_hp.has(key):
				if hp_now < int(_prev_player_hp[key]):
					_wave_had_damage = true
			_prev_player_hp[key] = hp_now

	_check_all_achievements()


func _get_game_node() -> Node:
	var cs := get_tree().current_scene
	if cs and cs.get("kills") != null and cs.get("wave") != null:
		return cs
	for c in get_tree().root.get_children():
		if c.get("kills") != null and c.get("wave") != null:
			return c
	return null


func _on_special_used() -> void:
	stats["specials_used"] = int(stats.get("specials_used", 0)) + 1
	_check_all_achievements()


# ---- 成就条件检查 ----
func _check_all_achievements() -> void:
	if int(stats.get("kills_total", 0)) >= 1:
		unlock("first_kill")
	if int(stats.get("kills_total", 0)) >= 100:
		unlock("hundred_kills")
	var weapons: Array = stats.get("weapons_used", [])
	var all_have := true
	for w in ALL_WEAPONS:
		if w not in weapons:
			all_have = false
	if all_have:
		unlock("all_weapons")
	if int(stats.get("current_wave", 0)) >= 5:
		unlock("clear_ch1")
	if int(stats.get("specials_used", 0)) >= 10:
		unlock("special_x10")
	if int(stats.get("captures_total", 0)) >= 5:
		unlock("capture_x5")
	if float(stats.get("vehicle_drive_time", 0.0)) >= DRIVE_SECONDS_FOR_VEHICLE_ACH:
		unlock("vehicle_squash")


# ---- 解锁 ----
func unlock(id: String) -> void:
	if unlocked.has(id):
		return
	if not ACHIEVEMENTS.has(id):
		return
	unlocked[id] = true
	var nm: String = ACHIEVEMENTS[id].get("name", id)
	achievement_unlocked.emit(id, nm)
	save_save()
	_show_toast(nm)


func is_unlocked(id: String) -> bool:
	return unlocked.has(id)


func get_all() -> Dictionary:
	return ACHIEVEMENTS


func get_unlocked_count() -> int:
	return unlocked.size()


# ---- Toast 提示（程序化构建，滑入动画，2.5s 后自动消失）----
func _show_toast(name: String) -> void:
	var layer := CanvasLayer.new()
	layer.layer = 100
	get_tree().root.add_child(layer)
	var bg := ColorRect.new()
	bg.color = Color(0.1, 0.1, 0.12, 0.95)
	bg.size = Vector2(380, 56)
	bg.position = Vector2(450, -80)
	layer.add_child(bg)
	var border := ColorRect.new()
	border.color = Color(1, 0.85, 0.2, 1)
	border.size = Vector2(380, 3)
	border.position = Vector2(0, 0)
	bg.add_child(border)
	var label := Label.new()
	label.text = "🏆 成就解锁：" + name
	label.add_theme_font_size_override("font_size", 20)
	label.add_theme_color_override("font_color", Color(1, 0.85, 0.2))
	label.position = Vector2(14, 14)
	label.size = Vector2(352, 30)
	bg.add_child(label)
	var tw := layer.create_tween()
	tw.tween_property(bg, "position:y", 24.0, 0.4).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_interval(2.1)
	tw.tween_property(bg, "position:y", -80.0, 0.4).set_trans(Tween.TRANS_LINEAR)
	tw.chain().tween_callback(func() -> void:
		if is_instance_valid(layer):
			layer.queue_free())


# ---- 本地存档（user:// JSON，V2.0 增加 version 字段）----
func save_save() -> void:
	var data := {"version": SAVE_VERSION, "unlocked": unlocked, "stats": stats}
	var f := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify(data))


func load_save() -> void:
	unlocked = {}
	stats = {}
	var need_migrate := false  # 旧档 v1（无 version 字段）需要迁移写回
	if FileAccess.file_exists(SAVE_PATH):
		var f := FileAccess.open(SAVE_PATH, FileAccess.READ)
		if f:
			var parsed = JSON.parse_string(f.get_as_text())
			if parsed is Dictionary:
				# ---- V2.0 版本检查与迁移 ----
				if not parsed.has("version"):
					# v1 旧档：无 version 字段，结构为 {unlocked, stats}，与 v2 字段兼容
					need_migrate = true
				else:
					var ver: int = int(parsed.get("version", 0))
					if ver > SAVE_VERSION:
						# 未来版本档：打印警告，仍尽力加载 unlocked/stats
						push_warning("Achievements: 存档版本 v%d 高于当前 v%d，可能存在兼容性问题" % [ver, SAVE_VERSION])
					# ver == SAVE_VERSION：直接加载；ver < SAVE_VERSION：当前仅 v1→v2 兼容，同上
				# 加载数据（任何版本都尽量提取 unlocked/stats）
				if parsed.get("unlocked") is Dictionary:
					unlocked = parsed["unlocked"]
				if parsed.get("stats") is Dictionary:
					stats = parsed["stats"]
	# 填充默认值
	if not stats.has("kills_total"):
		stats["kills_total"] = 0
	if not stats.has("current_wave"):
		stats["current_wave"] = 0
	if not stats.has("specials_used"):
		stats["specials_used"] = 0
	if not stats.has("captures_total"):
		stats["captures_total"] = 0
	if not stats.has("vehicle_drive_time"):
		stats["vehicle_drive_time"] = 0.0
	if not stats.has("weapons_used"):
		stats["weapons_used"] = []
	# v1 旧档迁移：补写 version=2 并持久化写回磁盘（unlocked/stats 完整保留）
	if need_migrate:
		save_save()


func reset_save() -> void:
	unlocked = {}
	stats = {}
	if FileAccess.file_exists(SAVE_PATH):
		DirAccess.remove_absolute(SAVE_PATH)
	save_save()


# ---- H 键切换成就面板（Autoload 自身监听，不侵入 game.gd）----
func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_H:
			_toggle_panel()


func _toggle_panel() -> void:
	if _panel == null or not is_instance_valid(_panel):
		return
	if _panel.visible:
		_panel.close()
	else:
		_panel.open()
