extends Node2D
## 波次刷怪器 —— 按波次表刷怪，清完一波出下一波
## 由 main.tscn 实例化，持有玩家引用和敌人场景引用

signal wave_started(wave_num: int)
signal wave_cleared(wave_num: int)
signal all_waves_cleared
signal enemy_count_changed(active: int, total_remaining: int)
signal enemy_died(enemy)

@export var enemy_scene: PackedScene		# 敌人场景（enemy.tscn）
@export var player_path: NodePath		# 玩家路径

var player: Node2D = null
var waves_config: Dictionary = {}
var current_wave: int = -1
var active_enemies: Array = []
var pending_spawns: Array = []			# 当前波次待刷的敌人列表 [(type, pos), ...]
var spawn_timer: float = 0.0
var wave_phase: int = 0					# 0=等待, 1=刷怪中, 2=清怪中, 3=完成
var wave_interval_timer: float = 0.0
var spawn_interval: float = 0.8


func _ready() -> void:
	waves_config = CombatConfig.get_waves()
	spawn_interval = waves_config.get("spawn_interval", 0.8)
	if player_path:
		player = get_node_or_null(player_path)
	# 延迟开始第一波
	wave_interval_timer = 2.0		# 开场2秒后出第一波
	wave_phase = 0


func _physics_process(delta: float) -> void:
	match wave_phase:
		0:	# 等待下一波
			wave_interval_timer -= delta
			if wave_interval_timer <= 0.0:
				_start_next_wave()
		1:	# 刷怪中
			spawn_timer -= delta
			if spawn_timer <= 0.0 and pending_spawns.size() > 0:
				_spawn_next_enemy()
				spawn_timer = spawn_interval
			# 待刷完后进入清怪阶段
			if pending_spawns.is_empty() and active_enemies.is_empty():
				_on_wave_cleared()
		2:	# 清怪中（等场上敌人全部死亡）
			if active_enemies.is_empty():
				_on_wave_cleared()


func _start_next_wave() -> void:
	var waves: Array = waves_config.get("waves", [])
	current_wave += 1
	if current_wave >= waves.size():
		wave_phase = 3
		all_waves_cleared.emit()
		return

	# 构建本波次待刷列表
	pending_spawns.clear()
	var wave_groups: Array = waves[current_wave]
	for group in wave_groups:
		var e_type: String = group.get("type", "zombie_normal")
		var count: int = group.get("count", 1)
		for i in range(count):
			pending_spawns.append(e_type)

	wave_phase = 1
	spawn_timer = 0.0
	wave_started.emit(current_wave + 1)
	enemy_count_changed.emit(active_enemies.size(), pending_spawns.size() + active_enemies.size())


func _spawn_next_enemy() -> void:
	if pending_spawns.is_empty():
		return
	var max_active: int = waves_config.get("max_active_enemies", 8)
	if active_enemies.size() >= max_active:
		return

	var e_type: String = pending_spawns.pop_front()
	var enemy = enemy_scene.instantiate() as CharacterBody2D
	# 生成位置：屏幕左右两侧随机
	var margin: float = waves_config.get("spawn_margin", 80.0)
	var side := randi() % 2		# 0=左, 1=右
	var spawn_x: float
	if side == 0:
		spawn_x = CombatConfig.get_world().get("left_bound", 60.0) + margin + randi() % 100
	else:
		spawn_x = CombatConfig.get_world().get("right_bound", 1220.0) - margin - randi() % 100
	var spawn_y: float = CombatConfig.get_world().get("ground_y", 560.0) - 30.0
	enemy.global_position = Vector2(spawn_x, spawn_y)
	# 先加入场景树，确保 @onready 变量（sprite 等）已初始化
	add_child(enemy)
	# 设置敌人类型和目标（内部调用 _load_enemy_textures 切换贴图）
	if enemy.has_method("setup"):
		enemy.setup(e_type, player)
	# 连接死亡信号
	if enemy.has_signal("died"):
		enemy.died.connect(_on_enemy_died)
	active_enemies.append(enemy)
	enemy_count_changed.emit(active_enemies.size(), pending_spawns.size() + active_enemies.size())


func _on_enemy_died(enemy) -> void:
	active_enemies.erase(enemy)
	enemy_died.emit(enemy)
	enemy_count_changed.emit(active_enemies.size(), pending_spawns.size() + active_enemies.size())


func _on_wave_cleared() -> void:
	wave_cleared.emit(current_wave + 1)
	# 检查是否全部波次完成
	var waves: Array = waves_config.get("waves", [])
	if current_wave + 1 >= waves.size():
		wave_phase = 3
		all_waves_cleared.emit()
	else:
		wave_phase = 0
		wave_interval_timer = waves_config.get("wave_interval", 3.0)


func get_active_count() -> int:
	return active_enemies.size()
