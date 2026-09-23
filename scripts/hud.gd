extends CanvasLayer
## 简单战斗 HUD —— 显示玩家HP、波次信息、剩余敌人数

@onready var hp_bar: ProgressBar = $HPBar
@onready var hp_label: Label = $HPBar/Label
@onready var wave_label: Label = $WaveLabel
@onready var enemy_label: Label = $EnemyLabel
@onready var center_msg: Label = $CenterMsg
@onready var kills_label: Label = get_node_or_null("KillsLabel")
@onready var coins_label: Label = get_node_or_null("CoinsLabel")

var player: Node2D = null
var spawner: Node = null


func setup(player_ref: Node2D, spawner_ref: Node) -> void:
	player = player_ref
	spawner = spawner_ref
	# 连接信号
	if player and player.has_signal("hp_changed"):
		player.hp_changed.connect(_on_hp_changed)
	if spawner:
		if spawner.has_signal("wave_started"):
			spawner.wave_started.connect(_on_wave_started)
		if spawner.has_signal("wave_cleared"):
			spawner.wave_cleared.connect(_on_wave_cleared)
		if spawner.has_signal("enemy_count_changed"):
			spawner.enemy_count_changed.connect(_on_enemy_count_changed)
		if spawner.has_signal("all_waves_cleared"):
			spawner.all_waves_cleared.connect(_on_all_cleared)
	# 初始化
	_on_hp_changed(player.hp, player.max_hp)
	wave_label.text = "准备..."
	enemy_label.text = "敌人: 0"
	set_kills(0)
	set_coins(Economy.coins)


func set_kills(n: int) -> void:
	if kills_label:
		kills_label.text = "击倒 %d" % n


func set_coins(n: int) -> void:
	if coins_label:
		coins_label.text = "金币 %d" % n


func _on_hp_changed(current: float, max_hp: float) -> void:
	hp_bar.max_value = max_hp
	hp_bar.value = current
	hp_label.text = "HP: %d / %d" % [int(current), int(max_hp)]


func _on_wave_started(wave_num: int) -> void:
	wave_label.text = "第 %d 波" % wave_num
	_show_center_msg("第 %d 波来袭！" % wave_num, 1.5)


func _on_wave_cleared(wave_num: int) -> void:
	_show_center_msg("第 %d 波 清除！" % wave_num, 1.5)


func _on_enemy_count_changed(active: int, total: int) -> void:
	enemy_label.text = "敌人: %d (剩余 %d)" % [active, total]


func _on_all_cleared() -> void:
	_show_center_msg("全部波次清除！胜利！", 3.0)


func _show_center_msg(text: String, duration: float) -> void:
	center_msg.text = text
	center_msg.modulate.a = 1.0
	var tw := get_tree().create_timer(duration)
	tw.timeout.connect(func():
		var tween := create_tween()
		tween.tween_property(center_msg, "modulate:a", 0.0, 0.5)
	)
