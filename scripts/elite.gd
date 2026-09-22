class_name Elite
extends CharacterBody2D
# V1.3 精英怪基类：暴走族干部 / 丧尸屠夫
# 独立于 Zombie 类实现，行为模式参考 zombie.gd；数据全部读取 EnemyDefs.get_elite_def(elite_id)
# 加入 "zombies" 组（子弹/必杀可命中）与 "elites" 组（便于查询）

const GRAVITY := 980.0

# ---- 接触伤害 ----
const CONTACT_RANGE_X := 40.0
const CONTACT_RANGE_Y := 55.0
const CONTACT_COOLDOWN := 1.2

# ---- 受击 / 霸体 / 躲避 ----
const KNOCKBACK_SPEED := 30.0
const KNOCKBACK_DURATION := 0.1
const HURT_FLASH := 0.12
const HEAL_FLASH := 0.15
const DODGE_DURATION := 0.3
const DODGE_SPEED_MULT := 1.8

# ---- 暴走族干部：近战突进 ----
const BOSOZOKU_TELEGRAPH := 0.3
const BOSOZOKU_DASH_TIME := 0.25

# ---- 丧尸屠夫：挥击范围攻击 ----
const BUTCHER_TELEGRAPH := 0.2
const BUTCHER_SWING_TIME := 0.2
const BUTCHER_SWING_ANGLE := deg_to_rad(120.0)

@export var elite_id: String = "bosozoku_leader"  # 场景中设置，区分两种精英

# ---- 数据驱动属性（从 EnemyDefs 读取）----
var hp: int = 60
var max_hp: int = 60
var damage: int = 20
var speed: float = 130.0
var lifesteal_rate: float = 0.08        # 精英吸血 8%
var dodge_chance: float = 0.50
var dodge_cooldown: float = 1.5
var super_armor: bool = true
var stun_resist: float = 0.0
var current_ability: float = 4.5

# ---- 干部突进参数 ----
var dash_speed: float = 420.0
var dash_range: float = 160.0
var dash_cooldown: float = 3.5
var dash_damage: int = 25

# ---- 屠夫挥击参数 ----
var swing_radius: float = 100.0
var swing_damage: int = 28
var swing_cooldown: float = 2.5

var player: Node2D = null
var dying: bool = false
var attack_cooldown: float = 0.0

# ---- 躲避状态 ----
var dodge_cooldown_timer: float = 0.0
var is_dodging: bool = false
var dodge_dir: float = 1.0
var _dodge_timer: float = 0.0

# ---- 受击后撤 ----
var _knockback_timer: float = 0.0
var _knockback_vx: float = 0.0

# ---- 干部突进状态机：idle / telegraph / dashing ----
var dash_state: String = "idle"
var dash_timer: float = 0.0
var dash_cooldown_timer: float = 0.0
var dash_dir: float = 1.0
var dash_damage_done: bool = false

# ---- 屠夫挥击状态机：idle / telegraph / swinging ----
var swing_state: String = "idle"
var swing_timer: float = 0.0
var swing_cooldown_timer: float = 0.0
var swing_damage_done: bool = false

var _anim_time: float = 0.0
var _hurt_tween: Tween
var _heal_tween: Tween

@onready var visual: Node2D = $Visual
@onready var head: Node2D = $Visual/Head
@onready var body_rect: ColorRect = $Visual/Body
@onready var face: ColorRect = $Visual/Head/Face
@onready var eye_l: ColorRect = $Visual/Head/EyeL
@onready var eye_r: ColorRect = $Visual/Head/EyeR
@onready var mouth: ColorRect = $Visual/Head/Mouth
@onready var arm_l: Node2D = $Visual/ArmL
@onready var arm_r: Node2D = $Visual/ArmR
@onready var leg_l: Node2D = $Visual/LegL
@onready var leg_r: Node2D = $Visual/LegR
@onready var weapon: ColorRect = $Visual/Weapon
@onready var collision_shape: CollisionShape2D = $CollisionShape2D

signal died(e: Node2D)


func _ready() -> void:
	add_to_group("zombies")
	add_to_group("elites")
	_setup_from_defs()
	# 初始手臂前伸姿势
	arm_l.rotation = 1.45
	arm_r.rotation = 1.45
	# 武器旋转原点放在手握处
	weapon.pivot_offset = Vector2(0.0, -4.0)


# 从 EnemyDefs 读取全部数值并设置外观/缩放/碰撞尺寸
func _setup_from_defs() -> void:
	var d: Dictionary = EnemyDefs.get_elite_def(elite_id)
	hp = int(d.get("hp", 60))
	max_hp = hp
	damage = int(d.get("damage", 20))
	speed = float(d.get("speed", 130.0))
	lifesteal_rate = float(d.get("lifesteal_rate", 0.08))
	dodge_chance = float(d.get("dodge_chance", 0.50))
	dodge_cooldown = float(d.get("dodge_cooldown", 1.5))
	stun_resist = float(d.get("stun_resist", 0.0))
	super_armor = bool(d.get("super_armor", true))
	current_ability = float(d.get("ability", 4.5))
	# 干部突进
	dash_speed = float(d.get("dash_speed", 420.0))
	dash_range = float(d.get("dash_range", 160.0))
	dash_cooldown = float(d.get("dash_cooldown", 3.5))
	dash_damage = int(d.get("dash_damage", 25))
	# 屠夫挥击
	swing_radius = float(d.get("swing_radius", 100.0))
	swing_damage = int(d.get("swing_damage", 28))
	swing_cooldown = float(d.get("swing_cooldown", 2.5))

	# 外观：干部深紫瘦高 / 屠夫暗红矮壮
	face.color = Color(0.6, 0.5, 0.42)
	eye_l.color = Color(1.0, 0.15, 0.15)   # 精英红眼
	eye_r.color = Color(1.0, 0.15, 0.15)
	match elite_id:
		"bosozoku_leader":
			body_rect.color = Color(0.25, 0.12, 0.45)   # 深紫
			visual.scale = Vector2(1.0, 1.1)            # 瘦高
			collision_shape.shape.size = Vector2(30, 50)
			weapon.color = Color(0.72, 0.72, 0.78)      # 金属球棒
		"zombie_butcher":
			body_rect.color = Color(0.5, 0.1, 0.12)     # 暗红
			visual.scale = Vector2(1.4, 1.0)            # 矮壮
			collision_shape.shape.size = Vector2(40, 56)
			weapon.color = Color(0.85, 0.88, 0.92)      # 大菜刀


func setup(target: Node2D) -> void:
	player = target


func _physics_process(delta: float) -> void:
	if dying:
		velocity = Vector2.ZERO
		move_and_slide()
		return
	if not is_on_floor():
		velocity.y += GRAVITY * delta
	attack_cooldown = maxf(attack_cooldown - delta, 0.0)
	dodge_cooldown_timer = maxf(dodge_cooldown_timer - delta, 0.0)
	dash_cooldown_timer = maxf(dash_cooldown_timer - delta, 0.0)
	swing_cooldown_timer = maxf(swing_cooldown_timer - delta, 0.0)

	var want_track: bool = player and is_instance_valid(player) and not player.dead
	var dir := 0.0
	if want_track:
		dir = signf(player.global_position.x - global_position.x)
		if dir != 0.0:
			visual.scale.x = dir * absf(visual.scale.x)

	# 按 elite_id 调用对应攻击模式
	match elite_id:
		"bosozoku_leader":
			_process_bosozoku(delta, want_track, dir)
		"zombie_butcher":
			_process_butcher(delta, want_track, dir)

	# 基础移动：躲避 / 前摇 / 突进 / 挥击 / 后撤覆盖普通追踪
	if is_dodging:
		_process_dodge_move(delta)
	elif dash_state == "dashing":
		pass  # 速度由 _process_bosozoku 驱动
	elif dash_state == "telegraph" or swing_state == "telegraph" or swing_state == "swinging":
		velocity.x = 0.0
	elif _knockback_timer > 0.0:
		_knockback_timer -= delta
		velocity.x = _knockback_vx
	else:
		velocity.x = dir * speed

	# 接触伤害（突进中由 _process_bosozoku 单独结算，避免重复）
	if want_track and attack_cooldown <= 0.0 and dash_state != "dashing":
		var dx: float = player.global_position.x - global_position.x
		var dy: float = player.global_position.y - global_position.y
		if absf(dx) < CONTACT_RANGE_X and absf(dy) < CONTACT_RANGE_Y:
			player.take_damage(damage)
			attack_cooldown = CONTACT_COOLDOWN
			if not player.dead:
				apply_lifesteal(damage)

	# 简单行走动画（前摇/突进/躲避期间不摆腿，避免姿势打架）
	if dash_state != "telegraph" and swing_state != "telegraph" and not is_dodging:
		_update_walk_anim(delta, velocity.x != 0.0)

	move_and_slide()


# ---- 暴走族干部：躲避子弹 + 近战突进 ----
func _process_bosozoku(delta: float, want_track: bool, dir: float) -> void:
	match dash_state:
		"telegraph":
			# 前摇 0.3s：身体下蹲 + 武器高举
			dash_timer -= delta
			visual.position.y = 6.0
			weapon.rotation = -1.2
			if dash_timer <= 0.0:
				dash_state = "dashing"
				dash_timer = BOSOZOKU_DASH_TIME
				dash_dir = dir if dir != 0.0 else 1.0
				dash_damage_done = false
				visual.position.y = 0.0
		"dashing":
			velocity.x = dash_dir * dash_speed
			dash_timer -= delta
			visual.rotation = dash_dir * 0.1
			# 冲锋中接触玩家造成突进伤害并吸血（一次突进只触发一次）
			if want_track and not dash_damage_done:
				var dx: float = player.global_position.x - global_position.x
				var dy: float = player.global_position.y - global_position.y
				if absf(dx) < CONTACT_RANGE_X and absf(dy) < CONTACT_RANGE_Y:
					player.take_damage(dash_damage)
					dash_damage_done = true
					if not player.dead:
						apply_lifesteal(dash_damage)
			if dash_timer <= 0.0:
				dash_state = "idle"
				dash_cooldown_timer = dash_cooldown
				visual.rotation = 0.0
				weapon.rotation = 0.0
		_:
			if dash_cooldown_timer > 0.0 or not want_track:
				return
			var dx: float = player.global_position.x - global_position.x
			var dy: float = player.global_position.y - global_position.y
			if absf(dx) < dash_range and absf(dy) < 80.0:
				dash_state = "telegraph"
				dash_timer = BOSOZOKU_TELEGRAPH


# ---- 丧尸屠夫：高血量 + 挥击范围攻击 + 吸血 ----
func _process_butcher(delta: float, want_track: bool, dir: float) -> void:
	match swing_state:
		"telegraph":
			# 前摇 0.2s：武器高举
			swing_timer -= delta
			weapon.rotation = -1.5
			if swing_timer <= 0.0:
				swing_state = "swinging"
				swing_timer = BUTCHER_SWING_TIME
				swing_damage_done = false
		"swinging":
			swing_timer -= delta
			var t: float = 1.0 - clampf(swing_timer / BUTCHER_SWING_TIME, 0.0, 1.0)
			var facing: float = signf(visual.scale.x)
			if facing == 0.0:
				facing = 1.0
			# 横扫：武器旋转 120°
			weapon.rotation = -1.5 + facing * BUTCHER_SWING_ANGLE * t
			# 对范围内玩家造成挥击伤害并吸血（一次挥击只触发一次）
			if want_track and not swing_damage_done:
				var dist: float = global_position.distance_to(player.global_position)
				var dy: float = absf(player.global_position.y - global_position.y)
				if dist <= swing_radius and dy < 80.0:
					player.take_damage(swing_damage)
					swing_damage_done = true
					if not player.dead:
						apply_lifesteal(swing_damage)
			if swing_timer <= 0.0:
				swing_state = "idle"
				swing_cooldown_timer = swing_cooldown
				weapon.rotation = 0.0
		_:
			if swing_cooldown_timer > 0.0 or not want_track:
				return
			var dx: float = player.global_position.x - global_position.x
			var dy: float = player.global_position.y - global_position.y
			if absf(dx) < swing_radius and absf(dy) < 80.0:
				swing_state = "telegraph"
				swing_timer = BUTCHER_TELEGRAPH


# ---- 受击结算 ----
func take_damage(dmg: int, is_melee: bool = false) -> void:
	if dying:
		return
	hp -= dmg
	# 霸体帧：仅扣血，不闪红不后撤；非霸体闪红 0.12s + 轻微后撤
	if super_armor:
		_knockback_timer = 0.0
	else:
		visual.modulate = Color(1.0, 0.55, 0.55, 1.0)
		if _hurt_tween and _hurt_tween.is_valid():
			_hurt_tween.kill()
		_hurt_tween = create_tween()
		_hurt_tween.tween_interval(HURT_FLASH)
		_hurt_tween.tween_callback(func() -> void:
			if is_instance_valid(self):
				visual.modulate = Color.WHITE
		)
		if hp > 0:
			var facing: float = signf(visual.scale.x)
			if facing == 0.0:
				facing = 1.0
			_knockback_vx = -facing * KNOCKBACK_SPEED * (1.0 - stun_resist)
			_knockback_timer = KNOCKBACK_DURATION
	# 躲避判定：子弹命中且冷却结束时概率侧移（近战不触发）
	if not is_melee and hp > 0 and dodge_cooldown_timer <= 0.0:
		if randf() < dodge_chance:
			start_dodge()
	if hp <= 0:
		dying = true
		died.emit(self)
		_start_death_anim()


# ---- 吸血：按造成伤害比例回血，至少 1 点，不超过 max_hp，泛绿 0.15s ----
func apply_lifesteal(damage_dealt: int) -> void:
	if dying or damage_dealt <= 0:
		return
	var heal := int(floor(float(damage_dealt) * lifesteal_rate))
	if heal < 1:
		heal = 1
	if hp + heal > max_hp:
		heal = max_hp - hp
	if heal <= 0:
		return
	hp += heal
	visual.modulate = Color(0.6, 1.0, 0.6)
	if _heal_tween and _heal_tween.is_valid():
		_heal_tween.kill()
	_heal_tween = create_tween()
	_heal_tween.tween_interval(HEAL_FLASH)
	_heal_tween.tween_callback(func() -> void:
		if is_instance_valid(self):
			visual.modulate = Color.WHITE
	)


# ---- 躲避：0.3s 侧移，速度 ×1.8，视觉微旋，冷却 dodge_cooldown ----
func start_dodge() -> void:
	if dying or is_dodging:
		return
	is_dodging = true
	_dodge_timer = DODGE_DURATION
	dodge_cooldown_timer = dodge_cooldown
	if player and is_instance_valid(player) and not player.dead:
		var away: float = signf(global_position.x - player.global_position.x)
		dodge_dir = away if away != 0.0 else (1.0 if randf() < 0.5 else -1.0)
	else:
		dodge_dir = 1.0 if randf() < 0.5 else -1.0


func _process_dodge_move(delta: float) -> void:
	_dodge_timer -= delta
	velocity.x = dodge_dir * speed * DODGE_SPEED_MULT
	visual.rotation = dodge_dir * 0.15
	if _dodge_timer <= 0.0:
		is_dodging = false
		visual.rotation = 0.0


# ---- 当前能力值（从 EnemyDefs 读取的 ability）----
func get_current_ability() -> float:
	return current_ability


func _start_death_anim() -> void:
	velocity = Vector2.ZERO
	if _hurt_tween and _hurt_tween.is_valid():
		_hurt_tween.kill()
	if _heal_tween and _heal_tween.is_valid():
		_heal_tween.kill()
	var t := create_tween()
	t.set_parallel(true)
	t.tween_property(visual, "rotation", -PI / 2.0, 0.4)
	t.tween_property(visual, "modulate:a", 0.0, 0.6)
	t.chain().tween_callback(func() -> void:
		if is_instance_valid(self):
			queue_free()
	)


# ---- 行走动画：腿交替摆动 ----
func _update_walk_anim(delta: float, moving: bool) -> void:
	_anim_time += delta
	var k := 1.0 - exp(-12.0 * delta)
	if moving:
		var ph := _anim_time * TAU / 0.45
		leg_l.rotation = lerp_angle(leg_l.rotation, sin(ph) * 0.35, k)
		leg_r.rotation = lerp_angle(leg_r.rotation, sin(ph + PI) * 0.35, k)
		visual.position.y = sin(ph * 2.0) * 1.0
	else:
		leg_l.rotation = lerp_angle(leg_l.rotation, 0.0, k)
		leg_r.rotation = lerp_angle(leg_r.rotation, 0.0, k)
		visual.position.y = lerpf(visual.position.y, 0.0, k)
