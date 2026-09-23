extends Area2D
## 攻击判定框 —— 挂在玩家攻击节点下，active 期间检测敌人碰撞体。
## 由 player.gd 在攻击 active 帧打开 monitoring，命中后调用敌人的 take_damage()。

signal hit_landed(target)		# 命中信号，携带被击中的敌人节点

var attack_data: Dictionary = {}	# 当前攻击的数值（从 CombatConfig 传入）
var has_hit: bool = false			# 本次 active 是否已命中过（防止单次攻击多次命中同一目标）


func _ready() -> void:
	body_entered.connect(_on_body_entered)


func setup(data: Dictionary, hit_size: Vector2) -> void:
	## 配置 hitbox：传入攻击数值字典和判定框尺寸
	attack_data = data
	var cs := get_node_or_null("CollisionShape2D") as CollisionShape2D
	if cs:
		var rect := RectangleShape2D.new()
		rect.size = hit_size
		cs.shape = rect
	# 初始关闭
	monitoring = false
	has_hit = false


func activate() -> void:
	## 打开判定
	has_hit = false
	monitoring = true


func deactivate() -> void:
	## 关闭判定
	monitoring = false


func _on_body_entered(body: Node2D) -> void:
	if has_hit:
		return
	# 检测到带 take_damage 方法的敌人
	if body.has_method("take_damage"):
		has_hit = true
		var dmg: float = attack_data.get("damage", 10.0)
		var kb: float = attack_data.get("knockback", 200.0)
		var stagger: float = attack_data.get("stagger", 0.3)
		var hs: float = attack_data.get("hitstop", 0.04)
		# 计算击退方向：从攻击发起者指向目标
		var attacker := get_parent().get_parent() as Node2D
		var dir := 1.0
		if attacker and body is Node2D:
			dir = signf((body as Node2D).global_position.x - attacker.global_position.x)
			if dir == 0.0:
				dir = 1.0
		body.take_damage(dmg, dir, kb, stagger, hs)
		hit_landed.emit(body)
