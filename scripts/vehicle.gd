class_name Vehicle
extends CharacterBody2D
# 不良改装战车：横版载具，无限火神机枪＋有限主炮，3格耐久，乘降无敌帧

const GRAVITY := 980.0
const MOVE_SPEED := 180.0
const MAX_DURABILITY := 3
const VULCAN_INTERVAL := 0.08
const CANNON_INTERVAL := 0.8
const INVINCIBLE_DURATION := 0.5
const BLAST_RADIUS := 100.0

const BULLET_SCENE := preload("res://scenes/bullet.tscn")
const GRENADE_SCENE := preload("res://scenes/grenade.tscn")

var driver: Player = null
var durability: int = MAX_DURABILITY
var vulcan_cooldown: float = 0.0
var cannon_ammo: int = 5
var cannon_cooldown: float = 0.0
var invincible: bool = false
var invincible_timer: float = 0.0
var facing: int = 1
var hit_flash_timer: float = 0.0
var destroyed: bool = false

@onready var visual: Node2D = $Visual
@onready var turret: Node2D = $Visual/Turret
@onready var vulcan_gun: ColorRect = $Visual/Turret/VulcanGun
@onready var cannon_gun: ColorRect = $Visual/Turret/CannonGun
@onready var wheel_l: ColorRect = $Visual/WheelL
@onready var wheel_r: ColorRect = $Visual/WheelR


func _ready() -> void:
	add_to_group("vehicles")


func enter(p: Player) -> void:
	if destroyed:
		return
	driver = p
	p.visible = false
	p.in_vehicle = true
	p.current_vehicle = self
	invincible = true
	invincible_timer = INVINCIBLE_DURATION
	p.global_position = global_position
	# 车身下压演出
	var tw := create_tween()
	visual.scale = Vector2(1.0, 1.0)
	tw.tween_property(visual, "scale:y", 0.95, 0.08)
	tw.tween_property(visual, "scale:y", 1.0, 0.12)


func exit() -> void:
	if driver == null:
		return
	var p := driver
	driver = null
	p.visible = true
	p.in_vehicle = false
	p.current_vehicle = null
	p.global_position = global_position + Vector2(facing * -40.0, 0.0)
	invincible = true
	invincible_timer = INVINCIBLE_DURATION
	p.set_invincible(INVINCIBLE_DURATION)
	# 跳出演出：车身轻微弹起
	var tw := create_tween()
	tw.tween_property(visual, "scale:y", 1.05, 0.06)
	tw.tween_property(visual, "scale:y", 1.0, 0.10)


func take_damage(dmg: int) -> void:
	if invincible or destroyed:
		return
	durability -= 1
	hit_flash_timer = 0.15
	visual.modulate = Color(1.0, 0.3, 0.3, 1.0)
	if durability <= 0:
		_destroy()


func _destroy() -> void:
	destroyed = true
	# 强制跳车保命
	if driver != null:
		exit()
	# 爆炸演出：放大 + 闪白 + 淡出
	visual.modulate = Color(1.0, 1.0, 1.0, 1.0)
	var tw := create_tween()
	tw.set_parallel(true)
	tw.tween_property(visual, "scale", Vector2(1.5, 1.5), 0.3)
	tw.tween_property(visual, "modulate:a", 0.0, 0.4)
	# AOE 伤害周围丧尸
	for z in get_tree().get_nodes_in_group("zombies"):
		if z is Zombie and not z.is_queued_for_deletion():
			if global_position.distance_to(z.global_position) <= BLAST_RADIUS:
				z.take_damage(8)
	# 延迟销毁
	var wait := create_tween()
	wait.tween_interval(0.5)
	wait.tween_callback(func() -> void:
		if is_instance_valid(self):
			queue_free()
	)


func _physics_process(delta: float) -> void:
	# 冷却计时
	vulcan_cooldown = maxf(vulcan_cooldown - delta, 0.0)
	cannon_cooldown = maxf(cannon_cooldown - delta, 0.0)
	if invincible_timer > 0.0:
		invincible_timer = maxf(invincible_timer - delta, 0.0)
		if invincible_timer <= 0.0:
			invincible = false
	if hit_flash_timer > 0.0:
		hit_flash_timer = maxf(hit_flash_timer - delta, 0.0)
		if hit_flash_timer <= 0.0:
			visual.modulate = Color.WHITE

	# 重力
	if not is_on_floor():
		velocity.y += GRAVITY * delta

	if destroyed:
		move_and_slide()
		return

	if driver == null:
		velocity.x = move_toward(velocity.x, 0.0, 500.0 * delta)
		move_and_slide()
		return

	# 驾驶中：读取驾驶员输入
	var axis := driver._get_move_axis()
	velocity.x = axis * MOVE_SPEED
	if axis != 0.0:
		facing = signi(int(axis))
		turret.scale.x = facing

	# 火神机枪
	if driver._is_shoot_pressed() and vulcan_cooldown <= 0.0:
		_fire_vulcan()
	# 主炮
	if driver._is_special_pressed() and cannon_cooldown <= 0.0 and cannon_ammo > 0:
		_fire_cannon()
	# 跳车（crouch 键按下即跳出）
	if driver._is_crouch_held():
		exit()

	# 轮子旋转动画
	var spin := delta * 8.0 * (velocity.x / MOVE_SPEED)
	wheel_l.rotation += spin
	wheel_r.rotation += spin

	move_and_slide()


func _fire_vulcan() -> void:
	vulcan_cooldown = VULCAN_INTERVAL
	var b := BULLET_SCENE.instantiate()
	b.global_position = turret.global_position + Vector2(facing * 20.0, 0.0)
	b.setup(Vector2(facing, 0.0), 1, 900.0)
	b.modulate = Color(1.0, 0.6, 0.2, 1.0)
	var parent_node := get_parent()
	if parent_node != null and parent_node.has_node("Bullets"):
		parent_node.get_node("Bullets").add_child(b)
	else:
		get_tree().current_scene.add_child(b)
	# 炮管后坐
	vulcan_gun.position.x = -2.0
	var tw := create_tween()
	tw.tween_property(vulcan_gun, "position:x", 0.0, 0.06)


func _fire_cannon() -> void:
	cannon_cooldown = CANNON_INTERVAL
	cannon_ammo -= 1
	var g := GRENADE_SCENE.instantiate()
	g.global_position = turret.global_position + Vector2(facing * 25.0, -5.0)
	g.velocity = Vector2(facing * 600.0, -100.0)
	var parent_node := get_parent()
	if parent_node != null and parent_node.has_node("Bullets"):
		parent_node.get_node("Bullets").add_child(g)
	else:
		get_tree().current_scene.add_child(g)
	# 炮管后坐 + 车身震动
	cannon_gun.position.x = -3.0
	var tw := create_tween()
	tw.tween_property(cannon_gun, "position:x", 0.0, 0.1)
	# 车身小震动
	visual.position.x = -2.0 * facing
	var shake := create_tween()
	shake.tween_property(visual, "position:x", 0.0, 0.15)
