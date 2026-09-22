class_name Player
extends CharacterBody2D
# 热血不良主角：移动 / 跳跃 / 多武器射击 / 连击蓄力格斗 / buff / 热血必杀

signal shoot_requested(pos: Vector2, dir: Vector2)
signal melee_requested(pos: Vector2, dir: Vector2)
signal special_used
signal hp_changed(hp: int, max_hp: int)
signal energy_changed(energy: float, max_energy: float)
signal ammo_changed(ammo: int, max_ammo: int)
signal died
# ---- V1.0 新增信号 ----
signal grenade_requested(pos: Vector2, dir: Vector2)
signal weapon_changed(name: String)
signal grenade_changed(count: int)
signal buffs_changed(active: Array)
# ---- V1.1 半尸化变身系统 ----
signal half_zombie_changed(active: bool, player_index: int)

const GRAVITY := 980.0
const SPEED := 260.0
const JUMP_VELOCITY := -430.0
const MAX_HP := 100
const MAX_AMMO := 24
const MAX_ENERGY := 100.0

# ---- 武器定义表（V2.0 外置至 Weapons 单例）：冷却 / 最大弹药（-1 无限）/ 伤害 / 子弹速度 ----
# 使用 static var 引用 Weapons.WEAPONS（Weapons.WEAPONS 为 static var，支持 DLC 运行时追加）。
# 保持 Player.WEAPONS 对外可访问（game.gd 中 Player.WEAPONS.get(w, {}) 引用不变）。
static var WEAPONS := Weapons.WEAPONS

var hp := MAX_HP
var ammo := MAX_AMMO  # 遗留弹药计数（冒烟测试 / 旧掉落兼容）
var energy := 0.0
var facing := 1
var invincible := false
var dead := false

# ---- V1.1 多玩家支持：1=P1, 2=P2（在场景实例上覆盖设置）----
@export var player_index: int = 1

# ---- V1.1 收服援护列表：每个元素 Dictionary {"type": int, "name": String, "damage": int} ----
var assist_units: Array = []

# ---- V1.1 载具系统 ----
var in_vehicle: bool = false
var current_vehicle: Node = null
var vehicle_invincible: bool = false
var vehicle_invincible_timer: float = 0.0

# ---- V1.1 半尸化变身系统 ----
var half_zombie: bool = false  # 是否处于半尸化状态
var blood_spray_cooldown: float = 0.0  # 血腥喷射冷却
const BLOOD_SPRAY_INTERVAL := 0.1  # 喷射间隔（高速持续喷射）
const BLOOD_SPRAY_DAMAGE := 5  # 每次喷射伤害
const BLOOD_SPRAY_RANGE := 130.0  # 喷射范围（像素）
const HALF_ZOMBIE_SPEED_MULT := 0.6  # 半尸化移速倍率

# ---- V1.2 角色选择系统：属性倍率（由 CharacterData 注入）----
var character_id: String = "pompadour"
var char_speed_mult: float = 1.0
var char_atk_mult: float = 1.0
var char_hp_mult: float = 1.0
var char_jump_mult: float = 1.0
var char_melee_range_mult: float = 1.0

# ---- V1.0 武器状态 ----
var current_weapon: String = "pistol"
var weapon_ammo: Dictionary = {"pistol": -1, "machine_gun": 0, "shotgun": 0, "grenade": 0}
var shoot_cooldown: float = 0.0

# ---- V1.0 格斗连击 / 蓄力 ----
var combo_count: int = 0
var combo_timer: float = 0.0
var current_melee_damage: int = 2
var charge_time: float = 0.0
const COMBO_WINDOW := 0.5
const CHARGE_THRESHOLD := 0.8
const CHARGE_DAMAGE := 8
const COMBO_DAMAGES := [2, 3, 5]  # 第 1/2/3 段
var _melee_swing_tween: Tween

# ---- V2.1 踢击系统 ----
var kick_count: int = 0
var kick_cooldown: float = 0.0
const KICK_COOLDOWN_TIME := 0.3
const KICK_DAMAGES := [3, 4]  # 第 1/2 段踢
const JUMP_KICK_DAMAGE := 6
const JUMP_KICK_LAND_HARDSTUN := 0.2
const KICK_RANGE_MULT := 1.2
var jump_kick_hardstun: float = 0.0

# ---- V2.1 拳脚交替奖励 ----
var combo_last_type: String = ""  # "punch" / "kick" / ""
var combo_alt_count: int = 0
const COMBO_ALT_BONUS := 1.5

# ---- V2.1 冲刺拳（方向键双击 → dash → 冲刺拳）----
var dash_active: bool = false
var dash_timer: float = 0.0
const DASH_DURATION := 0.2
const DASH_SPEED_MULT := 2.0
const DASH_PUNCH_DAMAGE := 7
var _dash_clock: float = 0.0
var _dash_press_dir: float = 0.0
var _dash_press_time: float = -999.0
var _prev_axis: float = 0.0

# ---- V2.1 近战武器（日用品当武器）----
var equipped_melee_weapon: String = ""
var melee_weapon_durability: int = 0
var current_melee_range_mult: float = 1.0  # 本次 melee_requested 的范围倍率（game.gd 读取）

# ---- V1.0 buff ----
var active_buffs: Dictionary = {}  # name -> 剩余秒数
var _buff_ui_timer := 0.0

# ---- 程序化动画状态 ----
var _anim_state := "idle"
var _anim_time := 0.0
var _hurt_time := 0.0
var _recoil := 0.0
const RECOIL_DURATION := 0.08
const HURT_DURATION := 0.2
var _anim_tweens: Array[Tween] = []

# ---- 夸张表情系统 ----
var current_expression := "normal"
var _expr_tween: Tween
var _expr_timer := 0.0
var _temp_expr := "normal"
var _idle_expr_timer := 4.0

# ---- V1.3 人机队友（bot）：P2 始终由电脑控制 ----
var is_bot: bool = false            # 是否由电脑控制
var bot_target: Node2D = null       # bot 跟随目标（通常 P1）
var bot_attack_cooldown: float = 0.0
var bot_state: String = "follow"    # follow/attack/rescue/retreat/strafe
var bot_preferred_weapon: String = "pistol"
# ---- V1.4 强化 AI：走位/集火/救援辅助变量 ----
var _bot_time: float = 0.0                # 累计时间（正弦走位用）
var _bot_p1_stationary_time: float = 0.0   # P1 站定时长累积

@onready var visual: Node2D = $Visual
@onready var arm_l: Node2D = $Visual/ArmL
@onready var arm_r: Node2D = $Visual/ArmR
@onready var leg_l: Node2D = $Visual/LegL
@onready var leg_r: Node2D = $Visual/LegR
@onready var head: Node2D = $Visual/Head
@onready var eye_l: ColorRect = $Visual/Head/EyeL
@onready var eye_r: ColorRect = $Visual/Head/EyeR
@onready var mouth: ColorRect = $Visual/Head/Mouth
@onready var brow_l: ColorRect = $Visual/Head/BrowL
@onready var brow_r: ColorRect = $Visual/Head/BrowR
@onready var mouth_big: ColorRect = $Visual/Head/MouthBig
@onready var tongue: ColorRect = $Visual/Head/Tongue
@onready var eye_cross_l: ColorRect = $Visual/Head/EyeCrossL
@onready var eye_cross_r: ColorRect = $Visual/Head/EyeCrossR


func _ready() -> void:
	add_to_group("players")
	# V1.2：根据 P1/P2 选人结果注入角色属性（Autoload 不存在时用默认均衡型）
	var cd := get_node_or_null("/root/CharacterData")
	if cd != null:
		apply_character(cd.get_selected(player_index))
	else:
		apply_character("pompadour")


# ---- V1.2 角色属性注入：仅做乘法，不推翻 V1.0 数值基线常量 ----
func apply_character(char_id: String) -> void:
	character_id = char_id
	var data: Dictionary = {}
	var cd := get_node_or_null("/root/CharacterData")
	if cd != null:
		data = cd.get_character(char_id)
	if data.is_empty():
		# Autoload 缺失或未知 id：使用默认倍率（不影响 V1.0 基线）
		char_speed_mult = 1.0
		char_atk_mult = 1.0
		char_hp_mult = 1.0
		char_jump_mult = 1.0
		char_melee_range_mult = 1.0
		return
	char_speed_mult = float(data.get("speed_mult", 1.0))
	char_atk_mult = float(data.get("atk_mult", 1.0))
	char_hp_mult = float(data.get("hp_mult", 1.0))
	char_jump_mult = float(data.get("jump_mult", 1.0))
	char_melee_range_mult = float(data.get("melee_range_mult", 1.0))
	# 体力倍率：不改 MAX_HP 常量，只调整实际 hp 上限
	var actual_max := int(100 * char_hp_mult)
	hp = actual_max
	hp_changed.emit(hp, actual_max)
	# 角色外观颜色区分（Visual 整体着色）
	if visual != null:
		visual.modulate = data.get("color", Color.WHITE)


# ---- V1.1 多玩家输入辅助：根据 player_index 选择 P1/P2 动作名 ----
func _get_move_axis() -> float:
	if player_index == 2:
		return Input.get_axis("p2_move_left", "p2_move_right")
	return Input.get_axis("move_left", "move_right")


func _is_jump_pressed() -> bool:
	if player_index == 2:
		return Input.is_action_just_pressed("p2_jump")
	return Input.is_action_just_pressed("jump")


func _is_crouch_held() -> bool:
	if player_index == 2:
		return Input.is_action_pressed("p2_crouch")
	return Input.is_action_pressed("crouch")


func _is_shoot_pressed() -> bool:
	if player_index == 2:
		return Input.is_action_just_pressed("p2_shoot")
	return Input.is_action_just_pressed("shoot")


func _is_melee_pressed() -> bool:
	if player_index == 2:
		return Input.is_action_just_pressed("p2_melee")
	return Input.is_action_just_pressed("melee")


func _is_melee_held() -> bool:
	if player_index == 2:
		return Input.is_action_pressed("p2_melee")
	return Input.is_action_pressed("melee")


func _is_special_pressed() -> bool:
	if player_index == 2:
		return Input.is_action_just_pressed("p2_special")
	return Input.is_action_just_pressed("special")


func _physics_process(delta: float) -> void:
	# 冷却 / 连击窗口 / buff 倒计时（无论生死都推进，死时也无害）
	shoot_cooldown = maxf(shoot_cooldown - delta, 0.0)
	blood_spray_cooldown = maxf(blood_spray_cooldown - delta, 0.0)
	kick_cooldown = maxf(kick_cooldown - delta, 0.0)
	jump_kick_hardstun = maxf(jump_kick_hardstun - delta, 0.0)
	_dash_clock += delta
	if combo_timer > 0.0:
		combo_timer = maxf(combo_timer - delta, 0.0)
		if combo_timer <= 0.0:
			combo_count = 0
			kick_count = 0
			combo_last_type = ""
			combo_alt_count = 0
	_update_buffs(delta)

	if dead:
		velocity.x = move_toward(velocity.x, 0.0, 2000.0 * delta)
		velocity.y += GRAVITY * delta
		move_and_slide()
		_set_anim("death")
		_update_anim(delta)
		_update_expression(delta)
		return

	# ---- V1.1 载具内状态：玩家隐藏，由载具接管输入 ----
	if in_vehicle and current_vehicle and is_instance_valid(current_vehicle):
		global_position = current_vehicle.global_position
		if vehicle_invincible_timer > 0.0:
			vehicle_invincible_timer = maxf(vehicle_invincible_timer - delta, 0.0)
			if vehicle_invincible_timer <= 0.0:
				vehicle_invincible = false
		return
	elif in_vehicle:
		# 载具已被销毁但标记未清除，恢复正常
		in_vehicle = false
		current_vehicle = null

	# ---- V1.3 人机队友：bot 不读键盘，velocity 由 _bot_process 直接驱动 ----
	if is_bot and not in_vehicle:
		_bot_process(delta)
		if not is_on_floor():
			velocity.y += GRAVITY * delta
		move_and_slide()
		visual.scale.x = facing
		if not is_on_floor():
			_set_anim("jump")
		elif velocity.x != 0.0:
			_set_anim("run")
		else:
			_set_anim("idle")
		_update_anim(delta)
		_update_expression(delta)
		return

	# ---- V1.1 载具进入：crouch 刚按下且附近有空载具时进入（bot 不读键盘，跳过）----
	if not in_vehicle and not is_bot:
		var crouch_just := false
		if player_index == 2:
			crouch_just = Input.is_action_just_pressed("p2_crouch")
		else:
			crouch_just = Input.is_action_just_pressed("crouch")
		if crouch_just:
			for v in get_tree().get_nodes_in_group("vehicles"):
				if v is CharacterBody2D and v.get("driver") == null and not v.get("destroyed"):
					if global_position.distance_to(v.global_position) < 80.0:
						v.enter(self)
						break

	var dir := _get_move_axis()
	var crouching := _is_crouch_held() and is_on_floor()
	# ---- V1.1 半尸化：不能下蹲 + 移速降低（载具内不生效）----
	if half_zombie and not in_vehicle:
		crouching = false
	# ---- V2.1 方向键双击检测（dash）----
	if dir != 0.0 and _prev_axis == 0.0 and not dash_active:
		var sdir := signf(dir)
		if sdir == _dash_press_dir and (_dash_clock - _dash_press_time) < 0.3:
			dash_active = true
			dash_timer = DASH_DURATION
		_dash_press_dir = sdir
		_dash_press_time = _dash_clock
	_prev_axis = dir
	# ---- V2.1 dash 状态推进 ----
	if dash_active:
		dash_timer = maxf(dash_timer - delta, 0.0)
		if dash_timer <= 0.0:
			dash_active = false
	var speed := SPEED * get_buff_multiplier("speed") * (0.5 if crouching else 1.0)
	if dash_active:
		speed *= DASH_SPEED_MULT
	velocity.x = dir * speed
	if half_zombie and not in_vehicle:
		velocity.x *= HALF_ZOMBIE_SPEED_MULT
	# V1.2：角色速度倍率（不改 SPEED 常量）
	velocity.x *= char_speed_mult
	if dir != 0.0:
		facing = signf(dir)

	if not is_on_floor():
		velocity.y += GRAVITY * delta
	if _is_jump_pressed() and is_on_floor():
		velocity.y = JUMP_VELOCITY * char_jump_mult

	move_and_slide()

	visual.scale.x = facing

	if not is_on_floor():
		_set_anim("jump")
	elif velocity.x != 0.0:
		_set_anim("run")
	else:
		_set_anim("idle")
	_update_anim(delta)
	_update_expression(delta)

	if _is_shoot_pressed():
		# V2.1：空中按 shoot = 跳踢；地面按 shoot = 有枪射击 / 无枪踢击
		if not is_on_floor():
			_try_jump_kick()
		elif has_gun_equipped():
			_try_shoot()
		else:
			_try_kick()

	# ---- V1.1 半尸化：血腥喷射代替射击（按住持续喷射，0.1s 间隔）----
	if half_zombie and not in_vehicle:
		var _spray_held := false
		if player_index == 2:
			_spray_held = Input.is_action_pressed("p2_shoot")
		else:
			_spray_held = Input.is_action_pressed("shoot")
		if _spray_held and blood_spray_cooldown <= 0.0:
			_blood_spray()

	# ---- 近战：按下开始蓄力，松开结算（快速点按=连击，长按>=0.8s=蓄力重击）----
	if _is_melee_pressed():
		charge_time = 0.0
	if _is_melee_held():
		charge_time += delta
	elif charge_time > 0.0:
		_resolve_melee()
		charge_time = 0.0

	if _is_special_pressed() and energy >= MAX_ENERGY:
		energy = 0.0
		energy_changed.emit(energy, MAX_ENERGY)
		_temp_expr = "grin"
		_expr_timer = 0.5
		special_used.emit()


func _set_anim(n: String) -> void:
	if n == _anim_state:
		return
	_anim_state = n
	if n == "death":
		_start_death_anim()


func _start_death_anim() -> void:
	for t in _anim_tweens:
		if t.is_valid():
			t.kill()
	_anim_tweens.clear()
	var t := create_tween()
	_anim_tweens.append(t)
	t.set_parallel(true)
	t.tween_property(visual, "rotation", PI / 2.0, 0.5)
	t.tween_property(visual, "position:y", visual.position.y + 8.0, 0.5)


func _update_anim(delta: float) -> void:
	_anim_time += delta
	if _hurt_time > 0.0:
		_hurt_time = maxf(_hurt_time - delta, 0.0)
	if _recoil > 0.0:
		_recoil = maxf(_recoil - delta, 0.0)

	if _anim_state == "death":
		return

	var k := 1.0 - exp(-18.0 * delta)
	var body_y := 0.0
	var body_rot := 0.0
	var t_arm_l := 0.0
	var t_arm_r := 0.0
	var t_leg_l := 0.0
	var t_leg_r := 0.0

	match _anim_state:
		"idle":
			body_y = sin(_anim_time * 3.0) * 2.0
		"run":
			var ph := _anim_time * TAU / 0.25
			t_leg_l = sin(ph) * 0.6
			t_leg_r = sin(ph + PI) * 0.6
			t_arm_l = sin(ph + PI) * 0.5
			t_arm_r = sin(ph) * 0.5
			body_rot = deg_to_rad(4.0)
			body_y = -absf(sin(ph)) * 1.0
		"jump":
			t_leg_l = deg_to_rad(-30.0)
			t_leg_r = deg_to_rad(-20.0)
			t_arm_l = deg_to_rad(-40.0)
			t_arm_r = deg_to_rad(-50.0)
			body_rot = deg_to_rad(6.0)

	arm_l.rotation = lerp_angle(arm_l.rotation, t_arm_l, k)
	arm_r.rotation = lerp_angle(arm_r.rotation, t_arm_r, k)
	leg_l.rotation = lerp_angle(leg_l.rotation, t_leg_l, k)
	leg_r.rotation = lerp_angle(leg_r.rotation, t_leg_r, k)

	visual.position.y = body_y
	visual.position.x = -4.0 * facing * (_recoil / RECOIL_DURATION)
	visual.rotation = body_rot + (deg_to_rad(-8.0) if _hurt_time > 0.0 else 0.0)

	# 蓄力时身体微微发抖（±1px）
	var charging := _is_melee_held() and charge_time > 0.3 and not dead
	if charging:
		visual.position.x += randf_range(-1.0, 1.0)
		visual.position.y += randf_range(-1.0, 1.0)


# ---- 夸张表情 ----
func set_expression(expr: String) -> void:
	current_expression = expr
	_apply_expression()


func _apply_expression() -> void:
	if _expr_tween and _expr_tween.is_valid():
		_expr_tween.kill()
	var flattened := current_expression == "flattened"
	var stare := current_expression == "stare"
	var grin := current_expression == "grin"
	var want_tongue := current_expression == "tongue_out"

	eye_l.visible = not flattened
	eye_r.visible = not flattened
	eye_cross_l.visible = flattened
	eye_cross_r.visible = flattened
	brow_l.visible = stare
	brow_r.visible = stare
	mouth.visible = not grin and not want_tongue
	mouth_big.visible = grin or want_tongue
	tongue.visible = want_tongue

	_expr_tween = create_tween()
	_expr_tween.set_parallel(true)
	_expr_tween.tween_property(head, "scale:y", 0.6 if flattened else 1.0, 0.1)
	var eye_s := Vector2(1.5, 1.5) if stare else (Vector2(1.0, 0.3) if grin else Vector2.ONE)
	_expr_tween.tween_property(eye_l, "scale", eye_s, 0.1)
	_expr_tween.tween_property(eye_r, "scale", eye_s, 0.1)


func _update_expression(delta: float) -> void:
	if _expr_timer > 0.0:
		_expr_timer = maxf(_expr_timer - delta, 0.0)
	var forced := "normal"
	if dead:
		forced = "normal"
	elif hp < MAX_HP * 0.3:
		forced = "flattened"
	elif _expr_timer > 0.0:
		forced = _temp_expr
	else:
		_idle_expr_timer -= delta
		if _idle_expr_timer <= 0.0:
			_idle_expr_timer = randf_range(3.0, 5.0)
			_temp_expr = "grin" if randf() < 0.5 else "tongue_out"
			_expr_timer = 0.8
			forced = _temp_expr
	if forced != current_expression:
		set_expression(forced)


# ---- V1.0 武器系统 ----
func switch_weapon(name: String) -> bool:
	if not WEAPONS.has(name):
		return false
	if name != current_weapon:
		current_weapon = name
		shoot_cooldown = 0.0
		weapon_changed.emit(name)
	_refresh_ammo_hud()
	return true


func get_weapon_max_ammo(name: String) -> int:
	return int(WEAPONS.get(name, {}).get("max_ammo", -1))


func _refresh_ammo_hud() -> void:
	var cur: int = int(weapon_ammo.get(current_weapon, -1))
	var mx := get_weapon_max_ammo(current_weapon)
	ammo_changed.emit(cur, mx)
	grenade_changed.emit(int(weapon_ammo.get("grenade", 0)))


# ---- V2.1 判断当前是否装备了可射击的枪械（非 pistol 且弹药 > 0）----
# 用于区分 shoot 键是"射击"还是"踢击"
func has_gun_equipped() -> bool:
	if half_zombie:
		return false
	if current_weapon == "pistol":
		return false
	var cur: int = int(weapon_ammo.get(current_weapon, 0))
	return cur > 0


func _try_shoot() -> void:
	if half_zombie:  # V1.1 半尸化：锁武器，不发射子弹
		return
	if dead or shoot_cooldown > 0.0:
		return
	var cur: int = int(weapon_ammo.get(current_weapon, -1))
	if cur == 0:  # 有限弹药打空
		return
	if cur > 0:
		weapon_ammo[current_weapon] = cur - 1
	shoot_cooldown = float(WEAPONS[current_weapon].cooldown)

	var d := Vector2(facing, 0.0)
	var muzzle := global_position + Vector2(16.0 * facing, -14.0)
	match current_weapon:
		"pistol", "machine_gun":
			shoot_requested.emit(muzzle, d)
		"shotgun":
			# 5 颗扇形弹片，±20° 散布
			for i in 5:
				var ang_deg := -20.0 + float(i) * 10.0
				shoot_requested.emit(muzzle, d.rotated(deg_to_rad(ang_deg)))
		"grenade":
			grenade_requested.emit(muzzle, d)

	_recoil = RECOIL_DURATION

	# 弹药耗尽（非手枪）自动切回手枪
	var now: int = int(weapon_ammo.get(current_weapon, -1))
	if now == 0 and current_weapon != "pistol":
		switch_weapon("pistol")
	else:
		_refresh_ammo_hud()


# ---- V1.0 格斗连击 / 蓄力 ----
# V2.1 扩展：dash 期间触发冲刺拳；装备近战武器时改为武器挥舞；
# 否则走原拳连击/蓄力逻辑。拳踢交替时第 3 击伤害 ×1.5。
func _resolve_melee() -> void:
	if dead:
		return
	# ---- V2.1 冲刺拳（dash 期间按 melee）----
	if dash_active:
		dash_active = false
		dash_timer = 0.0
		current_melee_damage = DASH_PUNCH_DAMAGE
		current_melee_range_mult = 1.0
		velocity.x += facing * 300.0
		_temp_expr = "grin"
		_expr_timer = 0.5
		_play_melee_anim(1, true)
		_register_combo_alt("punch")
		current_melee_damage = int(round(float(current_melee_damage) * char_atk_mult))
		if combo_alt_count >= 3:
			current_melee_damage = int(round(float(current_melee_damage) * COMBO_ALT_BONUS))
		melee_requested.emit(global_position, Vector2(facing, 0.0))
		return
	# ---- V2.1 近战武器挥舞（装备日用品武器后 melee 键改为挥武器）----
	if equipped_melee_weapon != "":
		var wdef: Dictionary = Weapons.MELEE_WEAPONS.get(equipped_melee_weapon, {})
		var wdmg: int = int(wdef.get("damage", 4))
		current_melee_range_mult = float(wdef.get("range_mult", 1.0))
		current_melee_damage = int(round(float(wdmg) * char_atk_mult))
		melee_weapon_durability -= 1
		_temp_expr = "grin"
		_expr_timer = 0.5
		_play_melee_anim(1, false)
		_register_combo_alt("punch")
		if combo_alt_count >= 3:
			current_melee_damage = int(round(float(current_melee_damage) * COMBO_ALT_BONUS))
		melee_requested.emit(global_position, Vector2(facing, 0.0))
		if melee_weapon_durability <= 0:
			_break_melee_weapon()
		return
	# ---- 原拳连击 / 蓄力（徒手）----
	current_melee_range_mult = 1.0
	if charge_time >= CHARGE_THRESHOLD:
		# 蓄力重击
		current_melee_damage = CHARGE_DAMAGE
		combo_count = 0
		combo_timer = 0.0
		_temp_expr = "stare"
		_expr_timer = 0.4
		_play_melee_anim(-1, true)
	else:
		# 连击推进
		combo_count = (combo_count % 3) + 1
		combo_timer = COMBO_WINDOW
		current_melee_damage = COMBO_DAMAGES[combo_count - 1]
		_temp_expr = "grin"
		_expr_timer = 0.5
		var side := 1 if combo_count % 2 == 1 else -1
		_play_melee_anim(side, combo_count == 3)
	# V1.2：角色攻击倍率作用于近战伤害（不改 COMBO/CHARGE 基线常量）
	current_melee_damage = int(round(float(current_melee_damage) * char_atk_mult))
	_register_combo_alt("punch")
	if combo_alt_count >= 3:
		current_melee_damage = int(round(float(current_melee_damage) * COMBO_ALT_BONUS))
	melee_requested.emit(global_position, Vector2(facing, 0.0))


# ---- V2.1 拳脚交替计数：追踪拳/踢交替，第 3 次交替击触发 ×1.5 ----
func _register_combo_alt(attack_type: String) -> void:
	if combo_last_type != "" and combo_last_type != attack_type and combo_timer > 0.0:
		combo_alt_count += 1
	else:
		combo_alt_count = 1
	combo_last_type = attack_type
	combo_timer = COMBO_WINDOW


# ---- V2.1 踢击（shoot 键在无枪时触发）----
func _try_kick() -> void:
	if dead or kick_cooldown > 0.0 or half_zombie:
		return
	kick_cooldown = KICK_COOLDOWN_TIME
	kick_count = (kick_count % 2) + 1
	current_melee_damage = KICK_DAMAGES[kick_count - 1]
	current_melee_range_mult = KICK_RANGE_MULT
	_register_combo_alt("kick")
	current_melee_damage = int(round(float(current_melee_damage) * char_atk_mult))
	if combo_alt_count >= 3:
		current_melee_damage = int(round(float(current_melee_damage) * COMBO_ALT_BONUS))
	_temp_expr = "grin"
	_expr_timer = 0.4
	var leg: Node2D = leg_r
	if leg and _melee_swing_tween and _melee_swing_tween.is_valid():
		_melee_swing_tween.kill()
	_melee_swing_tween = create_tween()
	_anim_tweens.append(_melee_swing_tween)
	_melee_swing_tween.tween_property(leg, "rotation", -0.8, 0.08)
	_melee_swing_tween.tween_property(leg, "rotation", 0.0, 0.14)
	velocity.x += facing * 120.0
	melee_requested.emit(global_position, Vector2(facing, 0.0))


# ---- V2.1 跳踢（空中按 shoot）----
func _try_jump_kick() -> void:
	if dead or half_zombie:
		return
	current_melee_damage = JUMP_KICK_DAMAGE
	current_melee_range_mult = KICK_RANGE_MULT
	velocity.y += 200.0
	_register_combo_alt("kick")
	current_melee_damage = int(round(float(current_melee_damage) * char_atk_mult))
	if combo_alt_count >= 3:
		current_melee_damage = int(round(float(current_melee_damage) * COMBO_ALT_BONUS))
	_temp_expr = "grin"
	_expr_timer = 0.3
	var leg: Node2D = leg_l
	if leg and _melee_swing_tween and _melee_swing_tween.is_valid():
		_melee_swing_tween.kill()
	_melee_swing_tween = create_tween()
	_anim_tweens.append(_melee_swing_tween)
	_melee_swing_tween.tween_property(leg, "rotation", -1.2, 0.1)
	_melee_swing_tween.tween_property(leg, "rotation", 0.0, 0.15)
	melee_requested.emit(global_position, Vector2(facing, 0.0))


# ---- V2.1 装备近战武器（日用品）----
func equip_melee_weapon(weapon_name: String) -> void:
	if not Weapons.MELEE_WEAPONS.has(weapon_name):
		return
	if equipped_melee_weapon != "":
		_break_melee_weapon()
	equipped_melee_weapon = weapon_name
	melee_weapon_durability = int(Weapons.MELEE_WEAPONS[weapon_name].get("durability", 10))
	_temp_expr = "grin"
	_expr_timer = 0.4


# ---- V2.1 武器脱手（耐久归零或更换）----
func _break_melee_weapon() -> void:
	if equipped_melee_weapon == "":
		return
	var fly := ColorRect.new()
	fly.color = Color(0.6, 0.6, 0.6, 1.0)
	fly.size = Vector2(12, 4)
	fly.position = Vector2(10.0 * facing, -20.0)
	add_child(fly)
	var tw := create_tween()
	tw.set_parallel(true)
	tw.tween_property(fly, "position", Vector2(10.0 * facing, -20.0) + Vector2(facing * 120.0, -30.0), 0.35).set_trans(Tween.TRANS_QUAD)
	tw.tween_property(fly, "modulate:a", 0.0, 0.35)
	tw.chain().tween_callback(func() -> void:
		if is_instance_valid(fly):
			fly.queue_free())
	equipped_melee_weapon = ""
	melee_weapon_durability = 0
	current_melee_range_mult = 1.0


func _play_melee_anim(side: int, lunge: bool) -> void:
	var arm: Node2D = arm_r if side >= 0 else arm_l
	if _melee_swing_tween and _melee_swing_tween.is_valid():
		_melee_swing_tween.kill()
	_melee_swing_tween = create_tween()
	_anim_tweens.append(_melee_swing_tween)
	_melee_swing_tween.tween_property(arm, "rotation", -1.5, 0.08)
	_melee_swing_tween.tween_property(arm, "rotation", 0.0, 0.14)
	if lunge:
		velocity.x += facing * 260.0


# ---- V1.0 buff 系统 ----
func add_buff(name: String, duration: float) -> void:
	if active_buffs.has(name):
		active_buffs[name] = maxf(float(active_buffs[name]), duration)
	else:
		active_buffs[name] = duration
	_push_buffs()


func has_buff(name: String) -> bool:
	return active_buffs.has(name) and float(active_buffs[name]) > 0.0


func get_buff_multiplier(stat: String) -> float:
	match stat:
		"speed":
			return 1.3 if has_buff("sports_drink") else 1.0
		"attack":
			return 1.5 if has_buff("chili_rice") else 1.0
		"melee_range":
			# V1.0: iron_pipe buff 提供 ×1.5；V2.1: 叠加武器/踢击范围与角色近战范围
			var m := 1.5 if has_buff("iron_pipe") else 1.0
			return m * current_melee_range_mult * char_melee_range_mult
		"defense":
			return 0.5 if has_buff("armor_vest") else 1.0
	return 1.0


func _update_buffs(delta: float) -> void:
	if active_buffs.is_empty():
		return
	var changed := false
	for k in active_buffs.keys():
		active_buffs[k] = float(active_buffs[k]) - delta
		if float(active_buffs[k]) <= 0.0:
			active_buffs.erase(k)
			changed = true
	_buff_ui_timer -= delta
	if changed or _buff_ui_timer <= 0.0:
		_buff_ui_timer = 0.5
		_push_buffs()


func _push_buffs() -> void:
	var arr: Array = []
	for k in active_buffs.keys():
		arr.append({"name": k, "remaining": float(active_buffs[k])})
	buffs_changed.emit(arr)


func _try_melee() -> void:
	# 保留兼容入口（实际连击在 _physics_process 中按下/松开驱动）
	if dead:
		return
	melee_requested.emit(global_position, Vector2(facing, 0.0))


func take_damage(dmg: int) -> void:
	# ---- V1.1 载具伤害重定向：伤害打在载具上，玩家不掉血 ----
	if in_vehicle and current_vehicle and is_instance_valid(current_vehicle):
		current_vehicle.take_damage(dmg)
		return
	# ---- V1.1 跳车无敌帧期间不掉血 ----
	if vehicle_invincible:
		return
	if invincible or dead:
		return
	var real := int(round(float(dmg) * get_buff_multiplier("defense")))
	# ---- V2.1 垃圾桶盖格挡：受击伤害 ×0.5，每次格挡耗 2 点耐久 ----
	if equipped_melee_weapon == "trash_lid" and melee_weapon_durability > 0:
		real = int(round(float(real) * 0.5))
		melee_weapon_durability -= 2
		if melee_weapon_durability <= 0:
			_break_melee_weapon()
	real = maxi(real, 0)
	hp = maxi(hp - real, 0)
	hp_changed.emit(hp, MAX_HP)
	invincible = true
	visual.modulate = Color(1.0, 0.45, 0.45, 1.0)
	_hurt_time = HURT_DURATION
	_temp_expr = "stare"
	_expr_timer = 0.3
	var flash := create_tween()
	_anim_tweens.append(flash)
	flash.tween_interval(HURT_DURATION)
	flash.tween_callback(func() -> void:
		visual.modulate = Color.WHITE
		_hurt_time = 0.0
	)
	var wait := create_tween()
	_anim_tweens.append(wait)
	wait.tween_interval(0.5)
	wait.tween_callback(func() -> void:
		invincible = false
	)
	if hp <= 0:
		dead = true
		died.emit()


func add_energy(amount: float) -> void:
	energy = clampf(energy + amount, 0.0, MAX_ENERGY)
	energy_changed.emit(energy, MAX_ENERGY)


func add_ammo(amount: int) -> void:
	ammo = clampi(ammo + amount, 0, MAX_AMMO)
	# 兼容旧掉落：同时补当前主武器弹药（手持手枪/手雷时补机枪）
	var target := current_weapon
	if target == "pistol" or target == "grenade":
		target = "machine_gun"
	var mx := get_weapon_max_ammo(target)
	if mx > 0:
		weapon_ammo[target] = mini(int(weapon_ammo.get(target, 0)) + amount, mx)
	_refresh_ammo_hud()


func heal(amount: int) -> void:
	hp = mini(hp + amount, MAX_HP)
	hp_changed.emit(hp, MAX_HP)


# ---- V1.1 半尸化变身系统 ----
func trigger_half_zombie() -> void:
	if half_zombie:
		return
	half_zombie = true
	set_expression("flattened")  # 变身时表情夸张
	# 变身演出：身体 scale 1.0→1.2→1.0，modulate 闪绿
	var s0: Vector2 = visual.scale
	var t := create_tween()
	t.tween_property(visual, "scale", s0 * 1.2, 0.15).set_trans(Tween.TRANS_BACK)
	t.tween_property(visual, "scale", s0, 0.15)
	var g := create_tween()
	g.tween_property(visual, "modulate", Color(0.5, 1.0, 0.5, 1.0), 0.12)
	g.tween_property(visual, "modulate", Color.WHITE, 0.2)
	half_zombie_changed.emit(true, player_index)


func cure_half_zombie() -> void:
	if not half_zombie:
		return
	half_zombie = false
	set_expression("normal")
	visual.modulate = Color.WHITE
	modulate = Color.WHITE
	blood_spray_cooldown = 0.0
	half_zombie_changed.emit(false, player_index)


func _blood_spray() -> void:
	blood_spray_cooldown = BLOOD_SPRAY_INTERVAL
	# 检测前方扇形范围内的丧尸
	var face_vec := Vector2(facing, 0.0)
	for z in get_tree().get_nodes_in_group("zombies"):
		if z is Zombie and not z.is_queued_for_deletion():
			var to_z: Vector2 = z.global_position - global_position
			if to_z.length() < BLOOD_SPRAY_RANGE and to_z.normalized().dot(face_vec) > 0.0:
				z.take_damage(BLOOD_SPRAY_DAMAGE)
	# 视觉：3-5 个红色粒子朝 facing 扇形飞出，0.3s 后 queue_free
	var count := 3 + randi() % 3
	for i in count:
		var p := ColorRect.new()
		p.color = Color(0.8, 0.05, 0.05, 0.9)
		p.size = Vector2(6, 6)
		p.position = Vector2(8.0 * facing, -20.0)
		add_child(p)
		var spread := deg_to_rad(randf_range(-30.0, 30.0))
		var vel := Vector2(facing, 0.0).rotated(spread) * randf_range(120.0, 220.0)
		var tw := create_tween()
		tw.set_parallel(true)
		tw.tween_property(p, "position", p.position + vel * 0.3, 0.3).set_trans(Tween.TRANS_LINEAR)
		tw.tween_property(p, "modulate:a", 0.0, 0.3)
		tw.chain().tween_callback(func() -> void:
			if is_instance_valid(p):
				p.queue_free())


# ---- V1.1 收服援护接口 ----
func add_assist(unit_data: Dictionary) -> void:
	assist_units.append(unit_data)


func get_assist_count() -> int:
	return assist_units.size()


# ---- V1.1 载具：设置跳车无敌帧 ----
func set_invincible(duration: float) -> void:
	vehicle_invincible = true
	vehicle_invincible_timer = duration


func reset() -> void:
	for t in _anim_tweens:
		if t.is_valid():
			t.kill()
	_anim_tweens.clear()
	hp = MAX_HP
	ammo = MAX_AMMO
	energy = 0.0
	dead = false
	invincible = false
	velocity = Vector2.ZERO
	visual.position = Vector2.ZERO
	visual.rotation = 0.0
	visual.modulate = Color.WHITE
	arm_l.rotation = 0.0
	arm_r.rotation = 0.0
	leg_l.rotation = 0.0
	leg_r.rotation = 0.0
	_anim_state = "idle"
	_anim_time = 0.0
	_hurt_time = 0.0
	_recoil = 0.0
	# ---- V1.0 新增状态复位 ----
	current_weapon = "pistol"
	weapon_ammo = {"pistol": -1, "machine_gun": 0, "shotgun": 0, "grenade": 0}
	shoot_cooldown = 0.0
	combo_count = 0
	combo_timer = 0.0
	current_melee_damage = 2
	charge_time = 0.0
	active_buffs = {}
	_buff_ui_timer = 0.0
	# ---- V2.1 拳脚/冲刺/近战武器状态复位 ----
	kick_count = 0
	kick_cooldown = 0.0
	combo_last_type = ""
	combo_alt_count = 0
	dash_active = false
	dash_timer = 0.0
	jump_kick_hardstun = 0.0
	_dash_clock = 0.0
	_dash_press_dir = 0.0
	_dash_press_time = -999.0
	_prev_axis = 0.0
	equipped_melee_weapon = ""
	melee_weapon_durability = 0
	current_melee_range_mult = 1.0
	# ---- V1.1 援护列表清空 ----
	assist_units = []
	# ---- V1.1 载具状态复位 ----
	in_vehicle = false
	current_vehicle = null
	vehicle_invincible = false
	vehicle_invincible_timer = 0.0
	# ---- V1.1 半尸化状态复位 ----
	half_zombie = false
	blood_spray_cooldown = 0.0
	# ---- V1.3 人机队友状态复位 ----
	is_bot = false
	bot_target = null
	bot_attack_cooldown = 0.0
	bot_state = "follow"
	_bot_time = 0.0
	_bot_p1_stationary_time = 0.0
	if _expr_tween and _expr_tween.is_valid():
		_expr_tween.kill()
	current_expression = "normal"
	_temp_expr = "normal"
	_expr_timer = 0.0
	_idle_expr_timer = 4.0
	head.scale = Vector2.ONE
	eye_l.scale = Vector2.ONE
	eye_r.scale = Vector2.ONE
	eye_l.visible = true
	eye_r.visible = true
	eye_cross_l.visible = false
	eye_cross_r.visible = false
	brow_l.visible = false
	brow_r.visible = false
	mouth.visible = true
	mouth_big.visible = false
	tongue.visible = false
	hp_changed.emit(hp, MAX_HP)
	energy_changed.emit(energy, MAX_ENERGY)
	weapon_changed.emit(current_weapon)
	_refresh_ammo_hud()
	_push_buffs()
	# V1.2：重开恢复角色属性（倍率 + 角色对应 hp 上限 + 外观色），最后调用覆盖复位值
	apply_character(character_id)


# ======================================================================
# V1.4 人机队友（bot）控制层：强化走位/集火/救援，不改 P1 输入与既有逻辑
# ======================================================================

# 由 game.gd 调用：把 P2 设为 bot
func setup_as_bot(target: Node2D) -> void:
	is_bot = true
	bot_target = target
	bot_state = "follow"
	bot_attack_cooldown = 0.0
	_bot_time = 0.0
	_bot_p1_stationary_time = 0.0
	switch_weapon(bot_preferred_weapon)


# 遍历 zombies 组，返回最近存活丧尸；无则返回 null
func _bot_find_nearest_zombie() -> Node2D:
	var best: Node2D = null
	var best_sq: float = INF
	for z in get_tree().get_nodes_in_group("zombies"):
		if z is Zombie and not z.is_queued_for_deletion():
			var z_alive: bool = not z.dying
			if not z_alive:
				continue
			var sq: float = global_position.distance_squared_to(z.global_position)
			if sq < best_sq:
				best_sq = sq
				best = z
	return best


# ---- V2.1 bot：查找附近的近战武器拾取物（铁管/轮胎/垃圾桶盖）----
func _bot_find_nearby_weapon_pickup() -> Node2D:
	var best: Node2D = null
	var best_d: float = 120.0
	for n in get_tree().root.find_children("*", "ItemPickup", true, false):
		if n is ItemPickup and not n.is_queued_for_deletion():
			if Weapons.MELEE_WEAPONS.has(n.item_type):
				var d: float = global_position.distance_to(n.global_position)
				if d < best_d:
					best_d = d
					best = n
	return best


# 遍历所有敌对单位（zombies 组含普通丧尸/精英/Boss），按威胁优先级返回最优目标
# 精英/Boss > 普通丧尸；距离近者优先
func _bot_find_best_target() -> Node2D:
	var best_regular: Node2D = null
	var best_regular_sq: float = INF
	var best_threat: Node2D = null
	var best_threat_sq: float = INF
	for n in get_tree().get_nodes_in_group("zombies"):
		if n == null or n.is_queued_for_deletion():
			continue
		# Elite / Boss 也在 zombies 组，且有 dying 属性
		var is_dying: bool = false
		if "dying" in n:
			is_dying = bool(n.get("dying"))
		if is_dying:
			continue
		var sq: float = global_position.distance_squared_to(n.global_position)
		# 判断是否高威胁（精英/Boss 组，或 FAT 普通丧尸）
		var is_high_threat := false
		if n.is_in_group("elites") or n.is_in_group("boss"):
			is_high_threat = true
		elif n is Zombie and n.ztype == Zombie.Type.FAT:
			is_high_threat = true
		if is_high_threat:
			if sq < best_threat_sq:
				best_threat_sq = sq
				best_threat = n
		else:
			if sq < best_regular_sq:
				best_regular_sq = sq
				best_regular = n
	# 优先返回高威胁目标
	if best_threat != null:
		return best_threat
	return best_regular


# 查找 P1 正在面对的方向上最近的敌对单位（用于配合 P1 集火）
# P1 facing 方向 ±300px 范围内的最近目标，优先精英/Boss
func _bot_find_focus_target() -> Node2D:
	if not is_instance_valid(bot_target):
		return null
	var p1_face: int = bot_target.facing
	var p1_pos: Vector2 = bot_target.global_position
	var best: Node2D = null
	var best_d: float = 300.0
	var best_threat: Node2D = null
	var best_threat_d: float = 300.0
	for n in get_tree().get_nodes_in_group("zombies"):
		if n == null or n.is_queued_for_deletion():
			continue
		var is_dying: bool = false
		if "dying" in n:
			is_dying = bool(n.get("dying"))
		if is_dying:
			continue
		var to_n: Vector2 = n.global_position - p1_pos
		# 只看 P1 面向方向的敌人
		if to_n.x != 0 and signf(to_n.x) != p1_face:
			continue
		var d: float = to_n.length()
		if d > 300.0:
			continue
		var is_high_threat := n.is_in_group("elites") or n.is_in_group("boss")
		if is_high_threat:
			if d < best_threat_d:
				best_threat_d = d
				best_threat = n
		else:
			if d < best_d:
				best_d = d
				best = n
	if best_threat != null:
		return best_threat
	return best


# 统计指定位置附近 radius 内的存活敌对单位数量
func _bot_count_hostiles_near(pos: Vector2, radius: float) -> int:
	var count := 0
	for n in get_tree().get_nodes_in_group("zombies"):
		if n == null or n.is_queued_for_deletion():
			continue
		var is_dying: bool = false
		if "dying" in n:
			is_dying = bool(n.get("dying"))
		if is_dying:
			continue
		if pos.distance_to(n.global_position) < radius:
			count += 1
	return count


# bot AI 主循环：撤退 > 救援 > 侧移避险 > 集火 > 攻击 > 跟随（含走位/1P指令影响）
func _bot_process(delta: float) -> void:
	bot_attack_cooldown = maxf(bot_attack_cooldown - delta, 0.0)
	_bot_time += delta
	var speed: float = SPEED * char_speed_mult * get_buff_multiplier("speed")
	var move_dir: float = 0.0
	var do_shoot := false
	var do_melee := false
	var do_kick := false  # V2.1 bot 踢击触发
	var target_valid := is_instance_valid(bot_target)

	# ---- V2.1 bot 拾取附近近战武器：无武器时移动到附近武器拾取物 ----
	if equipped_melee_weapon == "" and bot_state == "follow":
		var wp := _bot_find_nearby_weapon_pickup()
		if wp != null:
			var wdx: float = wp.global_position.x - global_position.x
			if absf(wdx) > 20.0:
				move_dir = signf(wdx)
				facing = int(move_dir)

	# ---- 追踪 P1 站定状态（1P 指令影响：站定时靠拢防守阵型）----
	if target_valid:
		if absf(bot_target.velocity.x) < 5.0 and bot_target.is_on_floor():
			_bot_p1_stationary_time += delta
		else:
			_bot_p1_stationary_time = 0.0

	# ---- 查找自身最近的高威胁单位（精英/Boss/FAT）----
	var danger_enemy: Node2D = null
	var danger_dist: float = INF
	for n in get_tree().get_nodes_in_group("zombies"):
		if n == null or n.is_queued_for_deletion():
			continue
		var is_dying: bool = false
		if "dying" in n:
			is_dying = bool(n.get("dying"))
		if is_dying:
			continue
		var is_threat := n.is_in_group("elites") or n.is_in_group("boss")
		if not is_threat and n is Zombie and n.ztype == Zombie.Type.FAT:
			is_threat = true
		if is_threat:
			var d: float = global_position.distance_to(n.global_position)
			if d < danger_dist:
				danger_dist = d
				danger_enemy = n

	# ========== 优先级 0：生存撤退（血量<30% 且精英/Boss 在 150px 内）==========
	if target_valid and hp < MAX_HP * 0.3 and danger_enemy != null and danger_dist < 150.0:
		bot_state = "retreat"
		var away: float = signf(global_position.x - danger_enemy.global_position.x)
		if away == 0.0:
			away = -1.0
		move_dir = away
		facing = -int(signf(away))  # 撤退时面朝来敌方向，边退边打
		velocity.x = move_dir * speed * 1.2
		if not is_on_floor():
			velocity.y += GRAVITY * delta
		move_and_slide()
		visual.scale.x = facing
		_set_anim("run")
		_update_anim(delta)
		_update_expression(delta)
		return

	# ========== 优先级 1：救援 P1 ==========
	var p1_need_rescue := false
	if target_valid:
		if bot_target.dead:
			p1_need_rescue = true
		elif bot_target.hp < MAX_HP * 0.3:
			# P1 血量危险，且附近有敌人
			var p1_near_enemy := _bot_count_hostiles_near(bot_target.global_position, 100.0) > 0
			if p1_near_enemy:
				p1_need_rescue = true
		# P1 被 >=2 只丧尸包围
		var p1_surrounded := _bot_count_hostiles_near(bot_target.global_position, 80.0) >= 2
		if p1_surrounded:
			p1_need_rescue = true

	if p1_need_rescue:
		if hp > MAX_HP * 0.2:
			# 自身血量>20%：冲入敌群近战挡枪式救援
			bot_state = "rescue"
			var dx: float = bot_target.global_position.x - global_position.x
			if absf(dx) > 24.0:
				move_dir = signf(dx)
				facing = int(move_dir)
			else:
				move_dir = 0.0
				if dx != 0:
					facing = int(signf(dx))
			# 身边有丧尸就连续近战
			var zr: Node2D = _bot_find_best_target()
			if zr != null and global_position.distance_to(zr.global_position) < 70.0:
				var dz: float = zr.global_position.x - global_position.x
				facing = int(signf(dz)) if dz != 0 else facing
				do_melee = true
		else:
			# 自身血量<=20%：不冲入，改为远程射击支援
			bot_state = "attack"
			var zr2: Node2D = _bot_find_best_target()
			if zr2 != null:
				var dz2: float = zr2.global_position.x - global_position.x
				facing = int(signf(dz2)) if dz2 != 0 else facing
				var d2: float = global_position.distance_to(zr2.global_position)
				if d2 < 350.0 and d2 > 150.0 and has_gun_equipped() and bot_attack_cooldown <= 0.0:
					do_shoot = true
					bot_attack_cooldown = 0.3

	# ========== 优先级 2：侧移避险（血量<50% 且精英/Boss 在 100px 内，不直线后退）==========
	if bot_state != "rescue" and bot_state != "retreat":
		if danger_enemy != null and danger_dist < 100.0 and hp < MAX_HP * 0.5:
			bot_state = "strafe"
			# 侧向移动（垂直于敌人方向，这里用水平侧移拉开距离）
			var away_x: float = signf(global_position.x - danger_enemy.global_position.x)
			if away_x == 0.0:
				away_x = 1.0
			move_dir = away_x * 0.8  # 侧移速度稍慢于逃跑
			facing = -int(away_x)  # 面朝敌人方向保持攻击朝向

	# ========== 优先级 3：配合 P1 集火 ==========
	if bot_state != "rescue" and bot_state != "retreat" and bot_state != "strafe":
		var focus_target := _bot_find_focus_target()
		if focus_target != null:
			bot_state = "attack"
			var to_focus: Vector2 = focus_target.global_position - global_position
			var fd: float = to_focus.length()
			var fdx: float = to_focus.x
			facing = int(signf(fdx)) if fdx != 0 else facing
			# 同步集火：靠拢到敌人 200px 内射击
			if fd > 200.0:
				move_dir = signf(fdx)
			elif fd < 60.0:
				do_melee = true
				move_dir = 0.0
			else:
				move_dir = 0.0
				if fd > 150.0 and has_gun_equipped() and bot_attack_cooldown <= 0.0:
					do_shoot = true
					bot_attack_cooldown = 0.3

	# ========== 优先级 4：自动攻击最优目标（兜底）==========
	if bot_state == "follow" or (bot_state == "attack" and not target_valid):
		var z: Node2D = _bot_find_best_target()
		if z != null:
			var to_z: Vector2 = z.global_position - global_position
			var dist: float = to_z.length()
			var face_vec := Vector2(facing, 0.0)
			var dot: float = 0.0
			if to_z.length_squared() > 0.01:
				dot = face_vec.normalized().dot(to_z.normalized())
			if dist < 350.0 and dot > 0.0:
				bot_state = "attack"
				facing = int(signf(to_z.x)) if to_z.x != 0 else facing
				if dist < 60.0:
					do_melee = true
					move_dir = 0.0
				elif dist < 150.0:
					# V2.1 中距离：用踢击代替射击
					if bot_attack_cooldown <= 0.0:
						do_kick = true
						bot_attack_cooldown = 0.3
				elif has_gun_equipped() and bot_attack_cooldown <= 0.0:
					do_shoot = true
					bot_attack_cooldown = 0.3
			elif dist < 350.0:
				facing = int(signf(to_z.x)) if to_z.x != 0 else facing
				bot_state = "attack"

	# ========== 优先级 5：跟随 P1（含聪明走位 + 1P 指令影响）==========
	if bot_state == "follow" and target_valid:
		var dx2: float = bot_target.global_position.x - global_position.x
		var d2d: float = absf(dx2)

		# 1P 指令影响：P1 站定超过 1 秒 → 靠拢到 80-100px 防守阵型
		if _bot_p1_stationary_time > 1.0:
			if d2d > 100.0:
				move_dir = signf(dx2)
				facing = int(move_dir)
			elif d2d < 80.0:
				# 太近了，缓慢后退到 80px
				move_dir = -signf(dx2) * 0.4 if dx2 != 0 else 0.0
				if dx2 != 0:
					facing = int(signf(dx2))
			else:
				move_dir = 0.0
		else:
			# 正常跟随：最佳距离 80-150px
			if d2d > 150.0:
				# 距离太远，快速靠拢
				move_dir = signf(dx2)
				facing = int(move_dir)
			elif d2d < 60.0:
				# 太近了，缓慢后退避免重叠卡位
				move_dir = -signf(dx2) * 0.5 if dx2 != 0 else 0.0
				if dx2 != 0:
					facing = int(signf(dx2))
			else:
				# 80-150px 区间：叠加正弦左右晃动走位
				var sway: float = sin(_bot_time * 1.5) * 15.0
				var desired_x: float = bot_target.global_position.x + sway
				var sway_dx: float = desired_x - global_position.x
				if absf(sway_dx) > 6.0:
					move_dir = signf(sway_dx) * 0.5
					facing = int(signf(sway_dx))
				else:
					move_dir = 0.0

	# ---- 执行攻击动作 ----
	if do_melee:
		_try_melee()
	if do_kick:
		_try_kick()
	if do_shoot:
		_try_shoot()
	# ---- V2.1 bot 跳踢：空中且敌人在下方时触发 ----
	if not is_on_floor() and bot_state == "attack":
		var tgt := _bot_find_best_target()
		if tgt != null and tgt.global_position.y > global_position.y:
			_try_jump_kick()

	# ---- 应用移动与动画（retreat 已提前 return）----
	if bot_state != "retreat":
		velocity.x = move_dir * speed
		if not is_on_floor():
			velocity.y += GRAVITY * delta
		move_and_slide()
		visual.scale.x = facing
		if not is_on_floor():
			_set_anim("jump")
		elif velocity.x != 0.0:
			_set_anim("run")
		else:
			_set_anim("idle")
		_update_anim(delta)
		_update_expression(delta)
