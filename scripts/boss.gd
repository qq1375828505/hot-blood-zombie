class_name Boss
extends CharacterBody2D
# V1.3 首关 Boss「街头混混头目」：3 段磨血战、阶段切换演出、弱点窗口、召唤小怪、狂暴吸血。
# 独立实现，不继承 Zombie/Elite；数据全部从 EnemyDefs.get_boss_def(boss_id) 读取。
# V2.0：boss_id 改为 @export，由场景/生成方指定（默认 street_boss 保持首关行为不变）。

@export var boss_id: String = "street_boss"
const GRAVITY := 980.0
const CONTACT_DAMAGE_RADIUS := 60.0
const CONTACT_COOLDOWN := 1.5
const WEAK_POINT_DURATION := 3.0
const PHASE_TRANSITION_TIME := 0.5
const DEATH_TIME := 2.0
const HEAL_FLASH_TIME := 0.15

signal died(b: Node2D)
signal phase_changed(phase: int)
signal hp_changed(current: int, max: int)

# ---- 数据驱动属性（从 EnemyDefs 读取后落地）----
var hp: int = 400
var max_hp: int = 400
var damage: int = 25
var speed: float = 95.0
var lifesteal_rate: float = 0.10
var super_armor: bool = true
var stun_resist: float = 0.9
var current_ability: float = 8.5

var dash_speed: float = 480.0
var dash_range: float = 220.0
var slam_radius: float = 130.0
var slam_damage: int = 32

# ---- 阶段 / 弱点 ----
var current_phase: int = 1
var phase_transitioning: bool = false
var weak_point_active: bool = false
var weak_point_timer: float = 0.0
var _phase_def: Dictionary = {}
var _base_lifesteal_rate: float = 0.10

# ---- 攻击状态 ----
var attack_cooldown: float = 2.0
const ATTACK_INTERVAL_BASE := 2.6
var dash_state: String = "idle"   # idle / telegraph / dashing
var _dash_timer: float = 0.0
var _dash_dir: float = 1.0
var slam_state: String = "idle"   # idle / telegraph / slamming
var _slam_timer: float = 0.0
var summon_cooldown: float = 0.0
var _contact_cooldown: float = 0.0

var player: Node2D = null
var dying: bool = false

const ZOMBIE_SCENE := preload("res://scenes/zombie.tscn")

@onready var visual: Node2D = $Visual
@onready var eye_l: ColorRect = $Visual/Head/EyeL
@onready var eye_r: ColorRect = $Visual/Head/EyeR


func _ready() -> void:
	var def := EnemyDefs.get_boss_def(boss_id)
	if def.is_empty():
		push_error("Boss 定义缺失：" + boss_id)
		return
	max_hp = int(def.get("hp", 400))
	hp = max_hp
	damage = int(def.get("damage", 25))
	speed = float(def.get("speed", 95.0))
	_base_lifesteal_rate = float(def.get("lifesteal_rate", 0.10))
	lifesteal_rate = _base_lifesteal_rate
	super_armor = bool(def.get("super_armor", true))
	stun_resist = float(def.get("stun_resist", 0.9))
	current_ability = float(def.get("ability", 8.5))
	dash_speed = float(def.get("dash_speed", 480.0))
	dash_range = float(def.get("dash_range", 220.0))
	slam_radius = float(def.get("slam_radius", 130.0))
	slam_damage = int(def.get("slam_damage", 32))
	add_to_group("zombies")
	add_to_group("boss")
	_apply_phase_def(1)
	emit_signal("hp_changed", hp, max_hp)


func setup(target: Node2D) -> void:
	player = target


func _physics_process(delta: float) -> void:
	if dying:
		return
	# 重力
	if not is_on_floor():
		velocity.y += GRAVITY * delta
	else:
		velocity.y = 0.0
	# 接触伤害冷却
	if _contact_cooldown > 0.0:
		_contact_cooldown -= delta
	# 阶段切换演出期间不移动
	if phase_transitioning:
		velocity.x = 0.0
		move_and_slide()
		return
	# 弱点窗口计时
	if weak_point_active:
		weak_point_timer -= delta
		if weak_point_timer <= 0.0:
			weak_point_active = false
			visual.modulate = Color.WHITE
	# 阶段判定
	_check_phase()
	# 行为
	_update_dash(delta)
	_update_slam(delta)
	_update_summon(delta)
	_move_toward_player(delta)
	_contact_damage()
	move_and_slide()


# ---- 追踪玩家（按当前阶段 speed_mult）----
func _move_toward_player(_delta: float) -> void:
	if player == null or not is_instance_valid(player):
		velocity.x = 0.0
		return
	# 冲刺/砸地演出中不额外走动
	if dash_state != "idle" or slam_state != "idle":
		velocity.x = 0.0
		return
	var dir: float = 0.0
	var dx: float = player.global_position.x - global_position.x
	if absf(dx) > 8.0:
		dir = 1.0 if dx > 0.0 else -1.0
		visual.scale.x = absf(visual.scale.x) * dir
	velocity.x = dir * speed


# ---- 阶段判定：按 hp 比例切换 ----
func _check_phase() -> void:
	var ratio := float(hp) / float(max_hp)
	var new_phase := 1
	if ratio < 0.33:
		new_phase = 3
	elif ratio < 0.66:
		new_phase = 2
	if new_phase != current_phase:
		_on_phase_change(new_phase)


func _apply_phase_def(phase: int) -> void:
	var def := EnemyDefs.get_boss_def(boss_id)
	var phases: Array = def.get("phases", [])
	_phase_def = {}
	for p in phases:
		if int(p.get("phase", 1)) == phase:
			_phase_def = p
			break
	if _phase_def.is_empty():
		return
	speed = float(def.get("speed", 95.0)) * float(_phase_def.get("speed_mult", 1.0))
	# 阶段3 吸血强化
	if phase == 3:
		lifesteal_rate = _base_lifesteal_rate * float(_phase_def.get("lifesteal_mult", 2.0))
	else:
		lifesteal_rate = _base_lifesteal_rate


# ---- 阶段切换演出 ----
func _on_phase_change(new_phase: int) -> void:
	current_phase = new_phase
	_apply_phase_def(new_phase)
	phase_transitioning = true
	weak_point_active = false
	# 身体放大 1.2→1.0 演出
	visual.scale = Vector2(1.2, 1.2)
	var tw := create_tween()
	tw.tween_property(visual, "scale", Vector2.ONE, 0.35).set_trans(Tween.TRANS_BACK)
	# 屏幕震动简化为 visual 抖动
	var shake := create_tween()
	for i in 4:
		shake.tween_property(visual, "position:x", randf_range(-6.0, 6.0), 0.05)
	shake.tween_property(visual, "position:x", 0.0, 0.05)
	# 阶段3 眼睛变红
	if new_phase >= 3:
		eye_l.color = Color(1.0, 0.1, 0.1, 1.0)
		eye_r.color = Color(1.0, 0.1, 0.1, 1.0)
	elif new_phase >= 2:
		eye_l.color = Color(1.0, 0.6, 0.1, 1.0)
		eye_r.color = Color(1.0, 0.6, 0.1, 1.0)
	emit_signal("phase_changed", new_phase)
	# 0.5s 后结束切换，开启 3 秒弱点窗口
	var cb := func() -> void:
		if not is_instance_valid(self):
			return
		phase_transitioning = false
		weak_point_active = true
		weak_point_timer = WEAK_POINT_DURATION
		visual.modulate = Color(1.0, 0.85, 0.3)
	var t := get_tree().create_timer(PHASE_TRANSITION_TIME)
	t.timeout.connect(cb)


# ---- 受击 ----
func take_damage(dmg: int, _is_melee: bool = false) -> void:
	if dying:
		return
	var final_dmg := int(dmg)
	# 弱点窗口伤害×2
	if weak_point_active:
		final_dmg = int(round(float(dmg) * 2.0))
	hp -= final_dmg
	# super_armor=true：仅扣血，不闪红不后撤（霸体帧）
	if not super_armor:
		visual.modulate = Color(1.0, 0.55, 0.55, 1.0)
	emit_signal("hp_changed", hp, max_hp)
	if hp <= 0:
		hp = 0
		_on_death()


# ---- 吸血 ----
func apply_lifesteal(damage_dealt: int) -> void:
	if dying:
		return
	var heal := int(floor(float(damage_dealt) * lifesteal_rate))
	heal = maxi(heal, 1)
	hp = mini(hp + heal, max_hp)
	# 泛绿视觉 0.15s
	visual.modulate = Color(0.6, 1.0, 0.6)
	var tw := create_tween()
	tw.tween_interval(HEAL_FLASH_TIME)
	tw.tween_callback(func() -> void:
		if is_instance_valid(self) and not weak_point_active:
			visual.modulate = Color.WHITE)
	emit_signal("hp_changed", hp, max_hp)


# ---- 接触伤害 ----
func _contact_damage() -> void:
	if player == null or not is_instance_valid(player):
		return
	if _contact_cooldown > 0.0:
		return
	var d: float = global_position.distance_to(player.global_position)
	if d < CONTACT_DAMAGE_RADIUS:
		var mult: float = float(_phase_def.get("damage_mult", 1.0))
		var dmg := int(round(float(damage) * mult))
		if player.has_method("take_damage"):
			player.take_damage(dmg)
		_contact_cooldown = CONTACT_COOLDOWN
		apply_lifesteal(dmg)


# ---- 冲刺（dash_charge）：telegraph → dashing ----
func _update_dash(delta: float) -> void:
	if not _phase_def.get("attacks", []).has("dash_charge"):
		return
	match dash_state:
		"idle":
			attack_cooldown -= delta
			if attack_cooldown <= 0.0 and player != null and is_instance_valid(player):
				var dist: float = absf(player.global_position.x - global_position.x)
				if dist > 120.0 and dist < 480.0:
					dash_state = "telegraph"
					_dash_timer = 0.35
					_dash_dir = 1.0 if player.global_position.x > global_position.x else -1.0
		"telegraph":
			_dash_timer -= delta
			visual.modulate = Color(1.0, 0.7, 0.7)
			if _dash_timer <= 0.0:
				dash_state = "dashing"
				_dash_timer = dash_range / dash_speed
		"dashing":
			velocity.x = _dash_dir * dash_speed
			_dash_timer -= delta
			if _dash_timer <= 0.0:
				dash_state = "idle"
				visual.modulate = Color.WHITE if not weak_point_active else Color(1.0, 0.85, 0.3)
				attack_cooldown = ATTACK_INTERVAL_BASE


# ---- 砸地（body_slam）：telegraph → slamming AoE ----
func _update_slam(delta: float) -> void:
	if not _phase_def.get("attacks", []).has("body_slam"):
		return
	match slam_state:
		"idle":
			attack_cooldown -= delta
			if attack_cooldown <= 0.0 and player != null and is_instance_valid(player):
				var dist: float = absf(player.global_position.x - global_position.x)
				if dist < slam_radius * 0.8:
					slam_state = "telegraph"
					_slam_timer = 0.4
		"telegraph":
			velocity.x = 0.0
			_slam_timer -= delta
			if _slam_timer <= 0.0:
				slam_state = "slamming"
				_slam_timer = 0.25
				# AoE 砸地
				if player != null and is_instance_valid(player):
					var dist: float = global_position.distance_to(player.global_position)
					if dist < slam_radius and player.has_method("take_damage"):
						player.take_damage(slam_damage)
						apply_lifesteal(slam_damage)
		"slamming":
			_slam_timer -= delta
			if _slam_timer <= 0.0:
				slam_state = "idle"
				attack_cooldown = ATTACK_INTERVAL_BASE


# ---- 召唤小怪 ----
func _update_summon(delta: float) -> void:
	if not bool(_phase_def.get("summon_minions", false)):
		return
	summon_cooldown -= delta
	if summon_cooldown <= 0.0:
		_summon_minions()
		summon_cooldown = float(_phase_def.get("summon_interval", 12.0))


func _summon_minions() -> void:
	var count: int = int(_phase_def.get("summon_count", 3))
	var parent := get_parent()
	if parent == null:
		return
	for i in count:
		var z := ZOMBIE_SCENE.instantiate()
		var side := -80.0 if i % 2 == 0 else 80.0
		z.global_position = global_position + Vector2(side, 0.0)
		parent.add_child(z)
		# walker / runner 混合
		var t: int = Zombie.Type.RUNNER if i % 2 == 1 else Zombie.Type.WALKER
		if z.has_method("setup"):
			z.setup(t, player)
		if z.has_signal("died") and self.has_signal("died"):
			pass


# ---- 死亡 ----
func _on_death() -> void:
	if dying:
		return
	dying = true
	velocity = Vector2.ZERO
	# 倒地 + 放大 + 闪白 + 淡出
	var tw := create_tween()
	tw.set_parallel(true)
	tw.tween_property(visual, "scale", Vector2(1.4, 0.6), DEATH_TIME * 0.6)
	tw.tween_property(visual, "modulate", Color(1, 1, 1, 0.0), DEATH_TIME)
	emit_signal("died", self)
	var t := get_tree().create_timer(DEATH_TIME)
	t.timeout.connect(func() -> void:
		if is_instance_valid(self):
			queue_free())


func get_current_ability() -> float:
	return current_ability


func get_current_phase() -> int:
	return current_phase
