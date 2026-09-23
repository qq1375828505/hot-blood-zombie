extends Node2D
## 战斗测试场景控制器 —— 直接进入战斗
## 连接玩家、刷怪器、HUD、镜头震动

@onready var player: CharacterBody2D = $Player
@onready var spawner: Node2D = $EnemySpawner
@onready var hud: CanvasLayer = $HUD
@onready var camera: Camera2D = $Camera2D


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


func _on_player_died() -> void:
	## 玩家死亡后显示重开提示
	print("玩家死亡！按 R 重开")
