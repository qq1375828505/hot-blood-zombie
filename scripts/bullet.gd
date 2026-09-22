class_name Bullet
extends Area2D
# 子弹：直线飞行，命中丧尸造成伤害。速度/颜色按武器区分。

var dir := Vector2.RIGHT
var damage := 2
var speed := 640.0
var life := 2.0

@onready var rect: ColorRect = $Rect

func setup(d: Vector2, dmg: int, spd: float = 640.0, weapon_name: String = "") -> void:
	dir = d
	damage = dmg
	speed = spd
	match weapon_name:
		"machine_gun":
			rect.color = Color(0.4, 0.9, 1.0, 1)   # 机枪 → 青
		"shotgun":
			rect.color = Color(1.0, 0.6, 0.2, 1)   # 霰弹 → 橙
		_:
			rect.color = Color(1.0, 0.9, 0.3, 1)   # 手枪 → 黄

func _ready() -> void:
	body_entered.connect(_on_hit)

func _physics_process(delta: float) -> void:
	position += dir * speed * delta
	life -= delta
	if life <= 0.0:
		queue_free()

func _on_hit(body: Node2D) -> void:
	if body.has_method("take_damage"):
		body.take_damage(damage)
	queue_free()
