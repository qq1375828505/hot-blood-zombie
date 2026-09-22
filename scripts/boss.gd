class_name Boss
extends CharacterBody2D
# V2.3 人形格斗战 Boss：暴走族总长/学生会会长，会格斗技、会嘲讽、会叫人。
# 数据从 EnemyDefs.get_boss_def(boss_id) 读取，兼容 V1.x~V2.2 所有公共接口。

@export var boss_id: String = "street_boss"
const GRAVITY := 980.0
const CONTACT_DAMAGE_RADIUS := 60.0
const CONTACT_COOLDOWN := 1.5
const WEAK_POINT_DURATION := 3.0
const PHASE_TRANSITION_TIME := 0.5
const DEATH_TIME := 2.0
const HEAL_FLASH_TIME := 0.15

# ---- V2.3 格斗技常量 ----
const PUNCH_RANGE := 70.0
const KICK_RANGE := 90.0
const THROW_RANGE := 50.0
const BLOCK_DURATION := 1.0
const BLOCK_COOLDOWN := 4.0
const BLOCK_DAMAGE_MULT := 0.3
const TAUNT_DURATION := 1.5
const TAUNT_COOLDOWN_MIN := 8.0
const TAUNT_COOLDOWN_MAX := 12.0
const POSE_DURATION := 1.5
const SUMMON_PRE_DELAY := 0.8

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

# ---- V2.3 人形身份（从 def 读取）----
var display_name: String = ""
var title: String = ""
var humanoid: bool = true
var taunt_lines: Array = []

# ---- 阶段 / 弱点 ----
var current_phase: int = 1
var phase_transitioning: bool = false
var weak_point_active: bool = false
var weak_point_timer: float = 0.0
var _phase_def: Dictionary = {}
var _base_lifesteal_rate: float = 0.10

# ---- 攻击状态（公共，保持现有命名）----
var attack_cooldown: float = 2.0
const ATTACK_INTERVAL_BASE := 2.6
var dash_state: String = "idle"   # idle / telegraph / dashing
var _dash_timer: float = 0.0
var _dash_dir: float = 1.0
var slam_state: String = "idle"   # idle / telegraph / slamming
var _slam_timer: float = 0.0
var summon_cooldown: float = 0.0
var _contact_cooldown: float = 0.0

# ---- V2.3 格斗技状态机（私有 _ 前缀）----
var _punch_state: String = "idle"  # idle / telegraph / punch1 / punch2 / punch3 / recover
var _punch_timer: float = 0.0
var _punch_step: int = 0

var _kick_state: String = "idle"   # idle / telegraph / kicking / recover
var _kick_timer: float = 0.0

var _throw_state: String = "idle"  # idle / grabbing / throwing / recover
var _throw_timer: float = 0.0
var _throw_succeeded: bool = false

var _block_state: String = "idle"  # idle / blocking / recover
var _block_timer: float = 0.0
var _block_cooldown: float = 4.0   # 初始 4s，避免测试中立即触发

# ---- V2.3 嘲讽 / 摆姿势 / 笑 ----
var _taunt_cooldown: float = 10.0  # 初始较长，避免测试中立即触发
var _taunting: bool = false
var _taunt_timer: float = 0.0
var _posing: bool = false
var _pose_timer: float = 0.0
var _laugh_timer: float = 0.0
var _bubble: Label = null

# ---- V2.3 召唤增强 ----
var _summon_pending: bool = false
var _summon_pre_timer: float = 0.0

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
	# V2.3 人形身份
	display_name = str(def.get("display_name", ""))
	title = str(def.get("title", ""))
	humanoid = bool(def.get("humanoid", true))
	taunt_lines = def.get("taunt_lines", [])
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
	# 嘲讽 / 摆姿势 / 笑 计时
	if _taunt_cooldown > 0.0:
		_taunt_cooldown -= delta
	if _block_cooldown > 0.0:
		_block_cooldown -= delta
	if _laugh_timer > 0.0:
		_laugh_timer -= delta
		if _laugh_timer <= 0.0:
			visual.rotation = 0.0
		else:
			visual.rotation = sin(_laugh_timer * 30.0) * 0.08
	# 阶段切换演出期间不移动
	if phase_transitioning:
		velocity.x = 0.0
		move_and_slide()
		return
	# 摆姿势期间不移动
	if _posing:
		_pose_timer -= delta
		velocity.x = 0.0
		if _pose_timer <= 0.0:
			_posing = false
			weak_point_active = false
			visual.modulate = Color.WHITE
		move_and_slide()
		return
	# 嘲讽期间不移动
	if _taunting:
		_taunt_timer -= delta
		velocity.x = 0.0
		# 手叉腰姿势：微微后仰
		visual.scale = Vector2(1.05, 0.95)
		if _taunt_timer <= 0.0:
			_taunting = false
			weak_point_active = false
			visual.scale = Vector2.ONE
			visual.modulate = Color.WHITE
			_taunt_cooldown = randf_range(TAUNT_COOLDOWN_MIN, TAUNT_COOLDOWN_MAX)
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
	# 嘲讽触发检查
	_update_taunt(delta)
	# 召唤前摇检查
	_update_summon_pre(delta)
	# 格斗技状态机
	_update_punch(delta)
	_update_kick(delta)
	_update_throw(delta)
	_update_block(delta)
	# 旧攻击状态机（仅推进，不自动触发）
	_update_dash(delta)
	_update_slam(delta)
	# 召唤冷却
	_update_summon(delta)
	# 统一攻击决策
	_decide_attack()
	# 追踪玩家
	_move_toward_player(delta)
	_contact_damage()
	move_and_slide()


# ---- 获取朝向 ----
func _get_facing() -> float:
	if visual.scale.x >= 0.0:
		return 1.0
	return -1.0


# ---- 嘲讽气泡 ----
func _show_bubble(text: String, duration: float = 1.5) -> void:
	if _bubble == null or not is_instance_valid(_bubble):
		_bubble = Label.new()
		_bubble.name = "TauntBubble"
		_bubble.add_theme_color_override("font_color", Color.WHITE)
		_bubble.add_theme_color_override("font_outline_color", Color.BLACK)
		_bubble.add_theme_constant_override("outline_size", 4)
		_bubble.position = Vector2(-60, -130)
		_bubble.z_index = 10
		add_child(_bubble)
	_bubble.text = text
	_bubble.visible = true
	var t := get_tree().create_timer(duration)
	t.timeout.connect(func() -> void:
		if is_instance_valid(_bubble):
			_bubble.visible = false)


# ---- 嘲讽系统 ----
func _update_taunt(_delta: float) -> void:
	if _taunting or _posing or phase_transitioning:
		return
	if _taunt_cooldown > 0.0:
		return
	# 嘲讽需要玩家在附近且不在攻击中
	if player == null or not is_instance_valid(player):
		return
	if not _is_all_attacks_idle():
		return
	var dist: float = absf(player.global_position.x - global_position.x)
	if dist > 200.0:
		return
	# 触发嘲讽
	_taunting = true
	_taunt_timer = TAUNT_DURATION
	weak_point_active = true
	weak_point_timer = TAUNT_DURATION
	visual.modulate = Color(1.0, 0.85, 0.3)
	if taunt_lines.size() > 0:
		var line: String = taunt_lines[randi() % taunt_lines.size()]
		_show_bubble(line, TAUNT_DURATION)


# ---- 笑 ----
func _do_laugh() -> void:
	if randf() < 0.20:
		_laugh_timer = 0.5
		_show_bubble("哈哈哈！", 0.6)


# ---- 攻击是否全部空闲 ----
func _is_all_attacks_idle() -> bool:
	return dash_state == "idle" and slam_state == "idle" \
		and _punch_state == "idle" and _kick_state == "idle" \
		and _throw_state == "idle" and _block_state == "idle" \
		and not _summon_pending


# ---- 统一攻击决策 ----
func _decide_attack() -> void:
	if attack_cooldown > 0.0:
		return
	if not _is_all_attacks_idle():
		return
	if player == null or not is_instance_valid(player):
		return
	var dist: float = absf(player.global_position.x - global_position.x)
	var avail: Array = _phase_def.get("attacks", [])
	var roll := randf()
	if dist < 80.0:
		# 近距
		if roll < 0.30 and avail.has("punch_combo"):
			_punch_state = "telegraph"
			_punch_timer = 0.2
			_punch_step = 0
		elif roll < 0.45 and avail.has("throw"):
			_throw_state = "grabbing"
			_throw_timer = 0.4
			_throw_succeeded = false
		elif roll < 0.55 and avail.has("dash_charge"):
			dash_state = "telegraph"
			_dash_timer = 0.35
			_dash_dir = 1.0 if player.global_position.x > global_position.x else -1.0
		elif roll < 0.60 and avail.has("body_slam"):
			slam_state = "telegraph"
			_slam_timer = 0.4
	elif dist <= 150.0:
		# 中距
		if roll < 0.25 and avail.has("high_kick"):
			_kick_state = "telegraph"
			_kick_timer = 0.3
		elif roll < 0.55 and avail.has("dash_charge"):
			dash_state = "telegraph"
			_dash_timer = 0.35
			_dash_dir = 1.0 if player.global_position.x > global_position.x else -1.0
		elif roll < 0.70 and avail.has("body_slam"):
			slam_state = "telegraph"
			_slam_timer = 0.4
	else:
		# 远距
		if roll < 0.40 and avail.has("dash_charge"):
			dash_state = "telegraph"
			_dash_timer = 0.35
			_dash_dir = 1.0 if player.global_position.x > global_position.x else -1.0
		elif roll < 0.60 and avail.has("body_slam"):
			slam_state = "telegraph"
			_slam_timer = 0.4
		# else: 接近玩家（由 _move_toward_player 处理）


# ---- 攻击冷却重置（按阶段缩短）----
func _reset_attack_cooldown() -> void:
	var mult := 1.0
	if current_phase == 2:
		mult = 0.85
	elif current_phase >= 3:
		mult = 0.7
	attack_cooldown = ATTACK_INTERVAL_BASE * mult


# ---- 追踪玩家（按当前阶段 speed_mult）----
func _move_toward_player(_delta: float) -> void:
	if player == null or not is_instance_valid(player):
		velocity.x = 0.0
		return
	# 所有攻击演出中不额外走动
	if not _is_all_attacks_idle():
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


# ---- 阶段切换演出（V2.3：POSE 摆姿势 1.5s + 弱点合并）----
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
	# 0.5s 过渡后进入 POSE 1.5s（期间弱点激活）
	var cb := func() -> void:
		if not is_instance_valid(self):
			return
		phase_transitioning = false
		_posing = true
		_pose_timer = POSE_DURATION
		weak_point_active = true
		weak_point_timer = POSE_DURATION
		visual.modulate = Color(1.0, 0.85, 0.3)
		# 双手交叉姿势：微微旋转
		visual.rotation = -0.15
		var pose_tw := create_tween()
		pose_tw.tween_property(visual, "rotation", 0.0, POSE_DURATION)
		_show_bubble("这才是真正的力量！", POSE_DURATION)
	var t := get_tree().create_timer(PHASE_TRANSITION_TIME)
	t.timeout.connect(cb)


# ---- 受击（V2.3：格挡概率判断）----
func take_damage(dmg: int, _is_melee: bool = false) -> void:
	if dying:
		return
	var final_dmg := int(dmg)
	# 格挡减伤
	if _block_state == "blocking":
		final_dmg = int(round(float(dmg) * BLOCK_DAMAGE_MULT))
	# 弱点窗口伤害×2
	elif weak_point_active:
		final_dmg = int(round(float(dmg) * 2.0))
	hp -= final_dmg
	# super_armor=true：仅扣血，不闪红不后撤（霸体帧）
	if not super_armor:
		visual.modulate = Color(1.0, 0.55, 0.55, 1.0)
	emit_signal("hp_changed", hp, max_hp)
	# 格挡触发判定（20% 概率，冷却就绪，不在攻击中，不在弱点中）
	if not weak_point_active and _block_cooldown <= 0.0 and _is_all_attacks_idle() and not _taunting and not _posing:
		if randf() < 0.20:
			_block_state = "blocking"
			_block_timer = BLOCK_DURATION
			_block_cooldown = BLOCK_COOLDOWN
			visual.modulate = Color(0.7, 0.85, 1.0)
			_show_bubble("挡下了！", 1.0)
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
		if is_instance_valid(self) and not weak_point_active and _block_state != "blocking":
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


# ---- 拳击连击 punch_combo ----
func _update_punch(delta: float) -> void:
	match _punch_state:
		"telegraph":
			_punch_timer -= delta
			visual.modulate = Color(1.0, 0.8, 0.6)
			if _punch_timer <= 0.0:
				_punch_state = "punch1"
				_punch_timer = 0.25
				_punch_step = 1
				_apply_punch_damage(0.3)
		"punch1":
			_punch_timer -= delta
			if _punch_timer <= 0.0:
				_punch_state = "punch2"
				_punch_timer = 0.25
				_punch_step = 2
				_apply_punch_damage(0.3)
		"punch2":
			_punch_timer -= delta
			if _punch_timer <= 0.0:
				_punch_state = "punch3"
				_punch_timer = 0.25
				_punch_step = 3
				_apply_punch_damage(0.6)
		"punch3":
			_punch_timer -= delta
			if _punch_timer <= 0.0:
				_punch_state = "recover"
				_punch_timer = 0.3
		"recover":
			_punch_timer -= delta
			if _punch_timer <= 0.0:
				_punch_state = "idle"
				visual.modulate = Color.WHITE if not weak_point_active else Color(1.0, 0.85, 0.3)
				_reset_attack_cooldown()


func _apply_punch_damage(mult: float) -> void:
	if player == null or not is_instance_valid(player):
		return
	var dx: float = player.global_position.x - global_position.x
	if absf(dx) < PUNCH_RANGE and dx * _get_facing() > -10.0:
		var phase_mult: float = float(_phase_def.get("damage_mult", 1.0))
		var dmg := int(round(float(damage) * mult * phase_mult))
		if player.has_method("take_damage"):
			player.take_damage(dmg)
		apply_lifesteal(dmg)


# ---- 飞踢 high_kick ----
func _update_kick(delta: float) -> void:
	match _kick_state:
		"telegraph":
			_kick_timer -= delta
			visual.modulate = Color(1.0, 0.7, 0.5)
			# 抬腿姿势
			visual.rotation = -0.1
			if _kick_timer <= 0.0:
				visual.rotation = 0.0
				_kick_state = "kicking"
				_kick_timer = 0.15
				# 踢击伤害 + 击退浮空
				if player != null and is_instance_valid(player):
					var dx: float = player.global_position.x - global_position.x
					if absf(dx) < KICK_RANGE:
						var phase_mult: float = float(_phase_def.get("damage_mult", 1.0))
						var dmg := int(round(float(damage) * 0.5 * phase_mult))
						if player.has_method("take_damage"):
							player.take_damage(dmg)
						apply_lifesteal(dmg)
						# 击退 + 浮空
						if "velocity" in player:
							player.velocity.x += _get_facing() * 250.0
							player.velocity.y = -200.0
		"kicking":
			_kick_timer -= delta
			if _kick_timer <= 0.0:
				_kick_state = "recover"
				_kick_timer = 0.4
		"recover":
			_kick_timer -= delta
			if _kick_timer <= 0.0:
				_kick_state = "idle"
				visual.modulate = Color.WHITE if not weak_point_active else Color(1.0, 0.85, 0.3)
				_reset_attack_cooldown()
				_do_laugh()


# ---- 投技 throw ----
func _update_throw(delta: float) -> void:
	match _throw_state:
		"grabbing":
			_throw_timer -= delta
			visual.modulate = Color(1.0, 0.7, 0.8)
			# 伸手抓取
			if player != null and is_instance_valid(player):
				var dist: float = absf(player.global_position.x - global_position.x)
				if dist < THROW_RANGE:
					_throw_succeeded = true
			if _throw_timer <= 0.0:
				if _throw_succeeded:
					_throw_state = "throwing"
					_throw_timer = 0.5
					# 抓取成功：伤害 + 抛出
					var phase_mult: float = float(_phase_def.get("damage_mult", 1.0))
					var dmg := int(round(float(damage) * 0.7 * phase_mult))
					if player != null and is_instance_valid(player):
						if player.has_method("take_damage"):
							player.take_damage(dmg)
						apply_lifesteal(dmg)
						if "velocity" in player:
							player.velocity = Vector2(-_get_facing() * 300.0, -250.0)
					_do_laugh()
				else:
					# 抓取失败，恢复
					_throw_state = "recover"
					_throw_timer = 0.3
		"throwing":
			_throw_timer -= delta
			# 抓取期间玩家无法操作（玩家被击退硬直）
			if _throw_timer <= 0.0:
				_throw_state = "recover"
				_throw_timer = 0.4
		"recover":
			_throw_timer -= delta
			if _throw_timer <= 0.0:
				_throw_state = "idle"
				visual.modulate = Color.WHITE if not weak_point_active else Color(1.0, 0.85, 0.3)
				_reset_attack_cooldown()


# ---- 格挡 block ----
func _update_block(delta: float) -> void:
	match _block_state:
		"blocking":
			_block_timer -= delta
			# 手臂交叉姿势
			var arm_l := visual.get_node_or_null("ArmL")
			var arm_r := visual.get_node_or_null("ArmR")
			if arm_l:
				arm_l.rotation = 1.2
			if arm_r:
				arm_r.rotation = -1.2
			if _block_timer <= 0.0:
				_block_state = "recover"
				_block_timer = 0.3
				if arm_l:
					arm_l.rotation = 0.0
				if arm_r:
					arm_r.rotation = 0.0
				visual.modulate = Color.WHITE if not weak_point_active else Color(1.0, 0.85, 0.3)
		"recover":
			_block_timer -= delta
			if _block_timer <= 0.0:
				_block_state = "idle"


# ---- 冲刺（dash_charge）：telegraph → dashing ----
func _update_dash(delta: float) -> void:
	if not _phase_def.get("attacks", []).has("dash_charge"):
		if dash_state != "idle":
			dash_state = "idle"
		return
	match dash_state:
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
				_reset_attack_cooldown()


# ---- 砸地（body_slam）：telegraph → slamming AoE ----
func _update_slam(delta: float) -> void:
	if not _phase_def.get("attacks", []).has("body_slam"):
		if slam_state != "idle":
			slam_state = "idle"
		return
	match slam_state:
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
				_reset_attack_cooldown()


# ---- 召唤小怪（V2.3：增强版）----
func _update_summon(delta: float) -> void:
	if not bool(_phase_def.get("summon_minions", false)):
		return
	summon_cooldown -= delta
	if summon_cooldown <= 0.0 and not _summon_pending:
		# 召唤前摇：Boss 停下，气泡台词
		_summon_pending = true
		_summon_pre_timer = SUMMON_PRE_DELAY
		weak_point_active = true
		weak_point_timer = SUMMON_PRE_DELAY
		visual.modulate = Color(1.0, 0.85, 0.3)
		var line := "出来吧，小弟们！" if boss_id == "street_boss" else "给我撕碎他。"
		_show_bubble(line, SUMMON_PRE_DELAY)


func _update_summon_pre(delta: float) -> void:
	if not _summon_pending:
		return
	_summon_pre_timer -= delta
	velocity.x = 0.0
	if _summon_pre_timer <= 0.0:
		_summon_pending = false
		weak_point_active = false
		visual.modulate = Color.WHITE
		_do_summon()
		# 召唤冷却最小 8s
		var interval: float = float(_phase_def.get("summon_interval", 12.0))
		summon_cooldown = maxf(interval, 8.0)


func _do_summon() -> void:
	var parent := get_parent()
	if parent == null:
		return
	# 数量：阶段3 为 3~4 只，否则 2~3 只
	var count: int
	if current_phase >= 3:
		count = randi_range(3, 4)
	else:
		count = randi_range(2, 3)
	for i in count:
		var z := ZOMBIE_SCENE.instantiate()
		var side := -80.0 if i % 2 == 0 else 80.0
		z.global_position = global_position + Vector2(side, 0.0)
		parent.add_child(z)
		# 小怪类型：street_boss 召唤 WALKER/DELINQUENT，final_boss 召唤 RUNNER/BOSOZOKU
		var t: int
		if boss_id == "final_boss":
			t = Zombie.Type.RUNNER if i % 2 == 0 else Zombie.Type.BOSOZOKU
		else:
			t = Zombie.Type.WALKER if i % 2 == 0 else Zombie.Type.DELINQUENT
		if z.has_method("setup"):
			z.setup(t, player)


# ---- 死亡（V2.3：人化跪姿遗言）----
func _on_death() -> void:
	if dying:
		return
	dying = true
	velocity = Vector2.ZERO
	# 清除所有攻击状态
	dash_state = "idle"
	slam_state = "idle"
	_punch_state = "idle"
	_kick_state = "idle"
	_throw_state = "idle"
	_block_state = "idle"
	_taunting = false
	_posing = false
	weak_point_active = false
	# 遗言气泡
	var last_words := "不可能...我可是总长..." if boss_id == "street_boss" else "秩序...不会崩塌..."
	_show_bubble(last_words, 2.5)
	# 跪姿 1.0s：身体缩小下沉
	var kneel_tw := create_tween()
	kneel_tw.tween_property(visual, "scale", Vector2(1.0, 0.6), 1.0).set_trans(Tween.TRANS_BACK)
	# 1.0s 后倒地
	var cb := func() -> void:
		if not is_instance_valid(self):
			return
		var fall_dir: float = 1.5 if _get_facing() > 0.0 else -1.5
		var tw := create_tween()
		tw.set_parallel(true)
		tw.tween_property(visual, "rotation", fall_dir, DEATH_TIME * 0.5)
		tw.tween_property(visual, "modulate", Color(1, 1, 1, 0.0), DEATH_TIME)
		emit_signal("died", self)
		var t2 := get_tree().create_timer(DEATH_TIME)
		t2.timeout.connect(func() -> void:
			if is_instance_valid(self):
				queue_free())
	var t := get_tree().create_timer(1.0)
	t.timeout.connect(cb)


func get_current_ability() -> float:
	return current_ability


func get_current_phase() -> int:
	return current_phase
