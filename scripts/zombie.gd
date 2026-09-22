class_name Zombie
extends CharacterBody2D
# 丧尸：三种类型（步行 / 疾跑 / 胖子），追踪玩家并近身撕咬
# 附带随机荒谬行为：发呆 / 整理头发 / 互殴 / 偷吃

enum Type { WALKER, RUNNER, FAT }

const GRAVITY := 980.0
const WALK_SPEED := 70.0
const RUN_SPEED := 155.0
const FAT_SPEED := 45.0

var ztype: Type = Type.WALKER
var hp := 3
var max_hp: int = 3  # V1.1 记录最大血量
var speed := WALK_SPEED
var player: Node2D = null
var attack_cooldown := 0.0
var dying := false

# ---- V1.1 收服系统 ----
var begging: bool = false  # 是否处于求饶状态
const CAPTURE_THRESHOLD := 2  # 求饶血量阈值（0 < hp <= 2 且最后一击为近战）

# ---- V1.1 FAT 特殊攻击：撕咬突进 ----
var special_cooldown: float = 0.0  # 特殊攻击冷却
const SPECIAL_INTERVAL := 3.0  # 特殊攻击间隔（秒）
var lunging: bool = false  # 是否正在突进撕咬
var lunge_timer: float = 0.0  # 突进持续计时
const LUNGE_DURATION := 0.3  # 突进持续时间
const LUNGE_SPEED := 350.0  # 突进速度
const LUNGE_RANGE := 80.0  # 触发突进的距离阈值
const INFECT_CHANCE := 0.4  # 撕咬命中后触发半尸化的概率（40%）
var lunge_dir: float = 1.0  # 突进方向
var bit_player: bool = false  # 本次突进是否已咬中（避免重复伤害）

# ---- V1.3 吸血系统（所有 Zombie 类型生效，比例读取 EnemyDefs）----
var lifesteal_rate: float = 0.05        # 小怪5% / 精英8% / Boss10%
var _heal_tween: Tween                   # 回血泛绿反馈 tween（与受击闪红区分）

# ---- V1.3 能力数值档位（乘数层叠加，不推翻 V1.0 常量）----
var _type_name: String = "walker"
var base_ability: float = 0.5
var burst_ability: float = 2.0
var current_ability: float = 0.5

# ---- V1.3 AI：躲避 ----
var dodge_cooldown_timer: float = 0.0
var dodge_cooldown: float = 1.5
var dodge_chance: float = 0.40
var hit_streak_threshold: int = 3
var consecutive_hits: int = 0
var is_dodging: bool = false
var dodge_dir: float = 1.0
var _dodge_timer: float = 0.0
const DODGE_DURATION := 0.3
const DODGE_SPEED_MULT := 1.8

# ---- V1.3 AI：扛伤（后撤 / 硬直抗性 / 霸体帧）----
var stun_resist: float = 0.0
var super_armor: bool = false
var _knockback_timer: float = 0.0
var _knockback_vx: float = 0.0
const KNOCKBACK_SPEED := 30.0
const KNOCKBACK_DURATION := 0.1

# ---- V1.3 AI：包围 ----
var _zid: float = 0.0
var _surround_role: float = 0.0
const SURROUND_HORDE := 3
const SURROUND_RANGE := 200.0
const SURROUND_Y := 20.0

# ---- V1.3 AI：疾跑冲锋爆发（runner 专用）----
var dash_cooldown_timer: float = 0.0
var dash_state: String = "none"   # none / telegraph / dash
var _dash_timer: float = 0.0
var dash_dir: float = 1.0
var runner_dashing: bool = false
const DASH_COOLDOWN := 4.0
const DASH_RANGE := 150.0
const DASH_TELEGRAPH := 0.4
const DASH_DURATION := 0.25
const DASH_SPEED_MULT := 2.5
const DASH_DAMAGE_MULT := 1.5
var _eye_orig_l: Color = Color(1, 1, 1)
var _eye_orig_r: Color = Color(1, 1, 1)

# ---- V1.3 同类互殴吞噬回血 ----
var _brawl_heal_accum: float = 0.0

# 荒谬行为状态机：none / zone_out / fix_hair / brawl / snack
var silly_state := "none"
var silly_timer := 0.0
var _silly_tween: Tween

var _anim_time := 0.0
var _hurt_tween: Tween

@onready var visual: Node2D = $Visual
@onready var head: Node2D = $Visual/Head
@onready var body_rect: ColorRect = $Visual/Body
@onready var eye_l: ColorRect = $Visual/Head/EyeL
@onready var eye_r: ColorRect = $Visual/Head/EyeR
@onready var arm_l: Node2D = $Visual/ArmL
@onready var arm_r: Node2D = $Visual/ArmR
@onready var leg_l: Node2D = $Visual/LegL
@onready var leg_r: Node2D = $Visual/LegR
@onready var beg_label: Label = $Visual/BegLabel
@onready var mouth: ColorRect = $Visual/Head/Mouth

signal died(z: Node2D)


func _ready() -> void:
	# 丧尸前伸姿势：手臂从下垂转到指向身前(+x 本地方向)
	arm_l.rotation = 1.45
	arm_r.rotation = 1.45


func setup(t: Type, target: Node2D) -> void:
	ztype = t
	player = target
	match t:
		Type.WALKER:
			hp = 3
			speed = WALK_SPEED
			body_rect.color = Color(0.52, 0.38, 0.72)
			visual.scale = Vector2.ONE
		Type.RUNNER:
			hp = 2
			speed = RUN_SPEED
			body_rect.color = Color(0.18, 0.66, 0.44)
			visual.scale = Vector2(0.8, 0.85)
		Type.FAT:
			hp = 14
			speed = FAT_SPEED
			body_rect.color = Color(0.62, 0.42, 0.22)
			visual.scale = Vector2(1.7, 1.15)
	max_hp = hp

	# V1.3：从 EnemyDefs 数据驱动读取能力档位 / 吸血 / 躲避参数
	# 注意：hp/speed 仍使用上方 V1.0 既有常量赋值，此处只做乘数层/标注层叠加
	match t:
		Type.WALKER:
			_type_name = "walker"
		Type.RUNNER:
			_type_name = "runner"
		Type.FAT:
			_type_name = "fat"
	var def: Dictionary = EnemyDefs.get_normal_def(_type_name)
	lifesteal_rate = float(def.get("lifesteal_rate", 0.05))
	dodge_chance = float(def.get("dodge_chance", 0.40))
	dodge_cooldown = float(def.get("dodge_cooldown", 1.5))
	stun_resist = float(def.get("stun_resist", 0.0))
	super_armor = bool(def.get("super_armor", false))
	hit_streak_threshold = int(def.get("hit_streak_threshold", 3))
	base_ability = float(def.get("ability", 0.5))
	burst_ability = float(def.get("burst_ability", 2.0))
	current_ability = base_ability
	_zid = randf() * TAU
	_surround_role = randf()
	# 记录眼睛原色（冲锋前摇会临时染红，结束后恢复）
	_eye_orig_l = eye_l.color
	_eye_orig_r = eye_r.color


func _physics_process(delta: float) -> void:
	if dying:
		velocity = Vector2.ZERO
		return
	if begging:
		# 求饶状态：不追踪不攻击，只维持重力与碰撞，保持跪姿
		if not is_on_floor():
			velocity.y += GRAVITY * delta
		velocity.x = 0.0
		move_and_slide()
		return
	if not is_on_floor():
		velocity.y += GRAVITY * delta
	attack_cooldown = maxf(attack_cooldown - delta, 0.0)
	special_cooldown = maxf(special_cooldown - delta, 0.0)
	dodge_cooldown_timer = maxf(dodge_cooldown_timer - delta, 0.0)
	dash_cooldown_timer = maxf(dash_cooldown_timer - delta, 0.0)

	var want_track: bool = player and is_instance_valid(player) and not player.dead
	var dir := 0.0
	if want_track:
		dir = signf(player.global_position.x - global_position.x)

	# V1.3 疾跑冲锋状态机（前摇红眼 / 高速冲锋），在普通追踪之前驱动
	_process_runner_dash(delta, want_track)

	if silly_state != "none":
		# 荒谬行为进行中：不追踪玩家、不攻击
		velocity.x = 0.0
		silly_timer -= delta
		_update_silly_anim(delta)
		if silly_timer <= 0.0:
			_end_silly()
	else:
		_maybe_start_silly(delta, dir)
		if silly_state == "none":
			if dash_state == "telegraph":
				# 冲锋前摇：僵住蓄力（红眼在 _process_runner_dash 中处理）
				velocity.x = 0.0
			elif is_dodging:
				# V1.3 躲避：侧移优先，覆盖普通追踪
				_process_dodge_move(delta)
			elif _knockback_timer > 0.0:
				# V1.3 扛伤：受击后撤窗口
				_knockback_timer -= delta
				velocity.x = _knockback_vx
			else:
				velocity.x = dir * speed
				if runner_dashing:
					# V1.3 爆发：冲锋速度叠加（speed × 2.5）
					velocity.x = dash_dir * speed * DASH_SPEED_MULT
				if dir != 0.0:
					visual.scale.x = dir * absf(visual.scale.x)
				if want_track and attack_cooldown <= 0.0 \
						and absf(player.global_position.x - global_position.x) < 42.0 \
						and absf(player.global_position.y - global_position.y) < 64.0:
					var contact_dmg := 10
					if runner_dashing:
						# 爆发状态接触伤害 × 1.5
						contact_dmg = int(round(10.0 * DASH_DAMAGE_MULT))
					player.take_damage(contact_dmg)
					attack_cooldown = 1.0
					# V1.3 吸血：玩家未死亡则按实际造成伤害回血
					if not player.dead:
						apply_lifesteal(contact_dmg)
		# V1.3 包围：成群时部分丧尸叠加上下包抄视觉偏移
		if silly_state == "none" and not is_dodging:
			_apply_surround_offset(delta, want_track)

	# ---- V1.1 FAT 撕咬突进：覆盖正常追踪速度（不干扰 begging/silly 状态）----
	_process_lunge(delta)
	# V1.3 能力档位随爆发状态更新
	_update_current_ability()

	move_and_slide()
	if silly_state == "none":
		_update_walk_anim(delta, velocity.x != 0.0)


func _maybe_start_silly(delta: float, dir: float) -> void:
	if dir == 0.0:
		return
	# 5%/秒 发呆；2%/秒 偷吃
	if randf() < 0.05 * delta:
		_start_zone_out()
	elif randf() < 0.02 * delta:
		_start_snack()
	if silly_state == "none":
		_try_brawl(delta)


func _start_zone_out() -> void:
	silly_state = "zone_out"
	silly_timer = 1.5
	velocity.x = 0.0
	eye_l.rotation = 0.6
	eye_r.rotation = 0.6


func _start_snack() -> void:
	silly_state = "snack"
	silly_timer = 1.0
	velocity.x = 0.0


func _start_brawl() -> void:
	silly_state = "brawl"
	silly_timer = 1.0
	velocity.x = 0.0
	_brawl_heal_accum = 0.0  # V1.3 互殴吞噬回血累计器


func _try_brawl(delta: float) -> void:
	# 3%/秒，与身边 40px 内的另一只丧尸互殴
	if randf() >= 0.03 * delta:
		return
	var par := get_parent()
	if par == null:
		return
	var other: Zombie = null
	var best := 40.0
	for c in par.get_children():
		if c == self or not c is Zombie:
			continue
		var z: Zombie = c
		if z.dying or z.silly_state != "none":
			continue
		var d := absf(z.global_position.x - global_position.x)
		if d < best:
			best = d
			other = z
	if other != null:
		_start_brawl()
		other._start_brawl()


func _end_silly() -> void:
	eye_l.rotation = 0.0
	eye_r.rotation = 0.0
	head.rotation = 0.0
	if silly_state == "zone_out" and randf() < 0.30:
		# 发呆后 30% 概率整理头发
		silly_state = "fix_hair"
		silly_timer = 0.8
		if _silly_tween and _silly_tween.is_valid():
			_silly_tween.kill()
		_silly_tween = create_tween()
		_silly_tween.tween_property(arm_l, "rotation", -1.2, 0.2)
		return
	silly_state = "none"
	arm_l.rotation = 1.45
	arm_r.rotation = 1.45
	if _silly_tween and _silly_tween.is_valid():
		_silly_tween.kill()


func _update_silly_anim(delta: float) -> void:
	_anim_time += delta
	match silly_state:
		"zone_out":
			visual.rotation = sin(_anim_time * 5.0) * 0.1
			visual.position.y = 0.0
		"fix_hair":
			visual.rotation = 0.0
			visual.position.y = 0.0
		"brawl":
			visual.rotation = 0.0
			visual.position.y = 0.0
			arm_l.rotation = 1.45 + sin(_anim_time * 22.0) * 0.5
			arm_r.rotation = 1.45 + sin(_anim_time * 22.0 + PI) * 0.5
			# V1.3 同类互殴吞噬：brawl 期间每秒回复 1 血（不超过 max_hp）
			_brawl_heal_accum += delta
			if _brawl_heal_accum >= 1.0:
				_brawl_heal_accum -= 1.0
				if hp < max_hp:
					hp = mini(hp + 1, max_hp)
		"snack":
			visual.rotation = 0.0
			head.rotation = 0.35 + sin(_anim_time * 12.0) * 0.05
			visual.position.y = 0.0


func _update_walk_anim(delta: float, moving: bool) -> void:
	_anim_time += delta
	var k := 1.0 - exp(-12.0 * delta)
	if moving:
		var ph := _anim_time * TAU / 0.45
		var t_ll := sin(ph) * 0.35
		var t_rl := sin(ph + PI) * 0.35
		leg_l.rotation = lerp_angle(leg_l.rotation, t_ll, k)
		leg_r.rotation = lerp_angle(leg_r.rotation, t_rl, k)
		visual.position.y = sin(ph * 2.0) * 1.0
		visual.rotation = sin(ph) * 0.08
	else:
		leg_l.rotation = lerp_angle(leg_l.rotation, 0.0, k)
		leg_r.rotation = lerp_angle(leg_r.rotation, 0.0, k)
		visual.position.y = lerpf(visual.position.y, 0.0, k)
		visual.rotation = lerpf(visual.rotation, 0.0, k)


func take_damage(dmg: int, is_melee: bool = false) -> void:
	if dying or begging:
		return
	hp -= dmg
	# V1.3 扛伤：霸体帧不闪红（仅扣血）；普通丧尸受击闪红
	if not super_armor:
		visual.modulate = Color(1.0, 0.55, 0.55, 1.0)
		if _hurt_tween and _hurt_tween.is_valid():
			_hurt_tween.kill()
		_hurt_tween = create_tween()
		_hurt_tween.tween_interval(0.12)
		_hurt_tween.tween_callback(func() -> void:
			if is_instance_valid(self):
				visual.modulate = Color.WHITE
		)
	# V1.3 扛伤：受击轻微后撤（霸体/死血不后撤；fat 有硬直抗性×(1-stun_resist)）
	if super_armor:
		_knockback_timer = 0.0
	elif hp > 0 and silly_state == "none":
		var facing: float = signf(visual.scale.x)
		if facing == 0.0:
			facing = 1.0
		_knockback_vx = -facing * KNOCKBACK_SPEED * (1.0 - stun_resist)
		_knockback_timer = KNOCKBACK_DURATION
	# V1.3 躲避：子弹命中触发（近战不触发），连续被命中达阈值强制躲避
	if not is_melee and hp > 0 and silly_state == "none":
		consecutive_hits += 1
		if dodge_cooldown_timer <= 0.0:
			if randf() < dodge_chance or consecutive_hits >= hit_streak_threshold:
				start_dodge()
	if hp <= 0:
		died.emit(self)
		_start_death_anim()
	elif is_melee and hp > 0 and hp <= CAPTURE_THRESHOLD:
		# 最后一击为近战且残血进入求饶
		_enter_begging()


# ---- V1.1 求饶状态 ----
func _enter_begging() -> void:
	begging = true
	silly_state = "none"
	if _silly_tween and _silly_tween.is_valid():
		_silly_tween.kill()
	if _hurt_tween and _hurt_tween.is_valid():
		_hurt_tween.kill()
	velocity = Vector2.ZERO
	visual.modulate = Color.WHITE
	# 下蹲跪姿
	visual.position.y = 10.0
	visual.scale.y = 0.75
	arm_l.rotation = -2.0
	arm_r.rotation = 2.0
	head.rotation = 0.2
	# 求饶指示
	beg_label.visible = true
	# 从 zombies 组移除：必杀/手雷 AOE 不再命中求饶丧尸
	remove_from_group("zombies")


# ---- V1.1 收服：返回援护数据并播放收服演出 ----
func capture() -> Dictionary:
	var dmg := 10
	var nm := "Walker"
	match ztype:
		Type.RUNNER:
			dmg = 8
			nm = "Runner"
		Type.FAT:
			dmg = 18
			nm = "FAT"
		_:
			dmg = 10
			nm = "Walker"
	var start_scale: Vector2 = visual.scale
	var t := create_tween()
	t.tween_property(visual, "scale", start_scale * 1.3, 0.15)
	t.tween_property(visual, "scale", start_scale, 0.15)
	t.tween_callback(func() -> void:
		if is_instance_valid(self):
			queue_free()
	)
	return {"type": ztype, "name": nm, "damage": dmg}


func _start_death_anim() -> void:
	dying = true
	silly_state = "none"
	velocity = Vector2.ZERO
	if _hurt_tween and _hurt_tween.is_valid():
		_hurt_tween.kill()
	if _silly_tween and _silly_tween.is_valid():
		_silly_tween.kill()
	var t := create_tween()
	t.set_parallel(true)
	t.tween_property(visual, "rotation", -PI / 2.0, 0.4)
	t.tween_property(visual, "modulate:a", 0.0, 0.6)
	t.chain().tween_callback(func() -> void:
		if is_instance_valid(self):
			queue_free()
	)


# ---- V1.1 FAT 丧尸特殊攻击：撕咬突进 ----
func _process_lunge(delta: float) -> void:
	if dying or begging:
		return
	var want_track: bool = player and is_instance_valid(player) and not player.dead
	if lunging:
		# 高速突进，覆盖正常追踪速度；仍受重力与碰撞（move_and_slide 在外层）
		velocity.x = lunge_dir * LUNGE_SPEED
		lunge_timer -= delta
		# 突进中与玩家重叠则撕咬（一次突进只咬一次）
		if want_track and not bit_player:
			var dx: float = player.global_position.x - global_position.x
			var dy: float = player.global_position.y - global_position.y
			if absf(dx) < 30.0 and absf(dy) < 50.0:
				_lunge_bite(player)
		if lunge_timer <= 0.0:
			lunging = false
			bit_player = false
			mouth.scale = Vector2.ONE
			visual.rotation = 0.0
		return
	# 非突进状态：FAT 丧尸在冷却结束且靠近玩家时启动突进
	if ztype != Type.FAT:
		return
	if special_cooldown > 0.0:
		return
	if not want_track:
		return
	var dx: float = player.global_position.x - global_position.x
	var dy: float = player.global_position.y - global_position.y
	if absf(dx) < LUNGE_RANGE and absf(dy) < 80.0:
		lunging = true
		lunge_timer = LUNGE_DURATION
		special_cooldown = SPECIAL_INTERVAL
		bit_player = false
		lunge_dir = signf(dx)
		if lunge_dir == 0.0:
			lunge_dir = 1.0
		# 视觉表现：嘴巴张大，身体前倾
		mouth.scale = Vector2(1.5, 2.0)
		visual.rotation = 0.1 * lunge_dir


func _lunge_bite(target: Player) -> void:
	if bit_player:
		return
	bit_player = true
	target.take_damage(15)  # 撕咬高伤害
	# V1.3 吸血：玩家未死亡则按撕咬 15 伤害回血
	if not target.dead:
		apply_lifesteal(15)
	if randf() < INFECT_CHANCE:
		target.trigger_half_zombie()  # 40% 概率触发半尸化变身
	# 撕咬演出：嘴巴闭合再张开
	mouth.scale = Vector2(0.6, 0.4)
	var tw := create_tween()
	tw.tween_property(mouth, "scale", Vector2(1.5, 2.0), 0.08)


# =====================================================================
# V1.3 扩展：吸血系统 / 能力档位 / AI 强化（躲避·扛伤·包围·爆发）
# =====================================================================

# ---- 公共接口：吸血 ----
# 按造成伤害 * lifesteal_rate 回复自身血量，至少 1 点（伤害>0 时），不超过 max_hp
func apply_lifesteal(damage_dealt: int) -> void:
	if dying or begging:
		return
	if damage_dealt <= 0:
		return
	var heal := int(floor(float(damage_dealt) * lifesteal_rate))
	if heal < 1:
		heal = 1
	if hp + heal > max_hp:
		heal = max_hp - hp
	if heal <= 0:
		return
	hp += heal
	# 回血视觉反馈：身体短暂泛绿（与受击闪红区分），0.15s 后恢复
	if _heal_tween and _heal_tween.is_valid():
		_heal_tween.kill()
	visual.modulate = Color(0.6, 1.0, 0.6)
	_heal_tween = create_tween()
	_heal_tween.tween_interval(0.15)
	_heal_tween.tween_callback(func() -> void:
		if is_instance_valid(self):
			visual.modulate = Color.WHITE
	)


# ---- 公共接口：当前能力值 ----
# 返回基础 ability 或爆发 ability（突进/冲锋时为 burst_ability）
func get_current_ability() -> float:
	return current_ability


# 每帧根据是否处于爆发状态更新能力档位（标注层，不改 V1.0 常量）
func _update_current_ability() -> void:
	if lunging or runner_dashing or dash_state == "telegraph":
		current_ability = burst_ability
	else:
		current_ability = base_ability


# ---- 公共接口：手动触发躲避 ----
func start_dodge() -> void:
	if dying or begging or silly_state != "none" or is_dodging:
		return
	is_dodging = true
	_dodge_timer = DODGE_DURATION
	dodge_cooldown_timer = dodge_cooldown
	# 侧移方向：优先远离玩家方向，否则随机侧方
	if player and is_instance_valid(player) and not player.dead:
		var away: float = signf(global_position.x - player.global_position.x)
		dodge_dir = away if away != 0.0 else (1.0 if randf() < 0.5 else -1.0)
	else:
		dodge_dir = 1.0 if randf() < 0.5 else -1.0


# 躲避移动：0.3s 侧向 ×1.8 速度，视觉微旋 ±0.15rad，结束后重置连击
func _process_dodge_move(delta: float) -> void:
	_dodge_timer -= delta
	velocity.x = dodge_dir * speed * DODGE_SPEED_MULT
	visual.rotation = dodge_dir * 0.15
	if _dodge_timer <= 0.0:
		is_dodging = false
		consecutive_hits = 0
		visual.rotation = 0.0


# ---- AI：包围 ----
# 同屏 >=3 只丧尸且靠近玩家时，部分丧尸（30%）叠加上下正弦偏移，制造包抄视觉
func _apply_surround_offset(delta: float, want_track: bool) -> void:
	if not want_track:
		return
	if _surround_role >= 0.30:
		return
	var par := get_parent()
	if par == null:
		return
	var count := 0
	for c in par.get_children():
		if c == self or not c is Zombie:
			continue
		var z: Zombie = c
		if z.dying:
			continue
		if absf(z.global_position.x - player.global_position.x) < SURROUND_RANGE \
				and absf(z.global_position.y - player.global_position.y) < 120.0:
			count += 1
	# count 为其他丧尸数，+1 含自己
	if count + 1 >= SURROUND_HORDE:
		velocity.y += sin(_anim_time * 2.0 + _zid) * SURROUND_Y


# ---- AI：疾跑冲锋爆发（runner 专用）----
# 前摇 0.4s 红眼 → 冲锋 0.25s（speed×2.5，接触伤害×1.5），冷却 4s
func _process_runner_dash(delta: float, want_track: bool) -> void:
	if dying or begging or ztype != Type.RUNNER:
		return
	match dash_state:
		"telegraph":
			_dash_timer -= delta
			if _dash_timer <= 0.0:
				dash_state = "dash"
				_dash_timer = DASH_DURATION
				runner_dashing = true
				if want_track:
					dash_dir = signf(player.global_position.x - global_position.x)
				else:
					dash_dir = 1.0
				if dash_dir == 0.0:
					dash_dir = 1.0
		"dash":
			_dash_timer -= delta
			if _dash_timer <= 0.0:
				dash_state = "none"
				runner_dashing = false
				dash_cooldown_timer = DASH_COOLDOWN
				_restore_eye_color()
		_:
			if dash_cooldown_timer > 0.0:
				return
			if not want_track:
				return
			var dx: float = player.global_position.x - global_position.x
			var dy: float = player.global_position.y - global_position.y
			if absf(dx) < DASH_RANGE and absf(dy) < 80.0:
				if randf() < 0.6:
					dash_state = "telegraph"
					_dash_timer = DASH_TELEGRAPH
					dash_dir = signf(dx)
					if dash_dir == 0.0:
						dash_dir = 1.0
					# 冲锋前摇：眼睛变红
					eye_l.color = Color(1, 0.2, 0.2)
					eye_r.color = Color(1, 0.2, 0.2)


# 恢复眼睛原色
func _restore_eye_color() -> void:
	if is_instance_valid(eye_l):
		eye_l.color = _eye_orig_l
	if is_instance_valid(eye_r):
		eye_r.color = _eye_orig_r
