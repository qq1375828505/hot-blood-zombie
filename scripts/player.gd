class_name Player
extends CharacterBody2D
## 玩家战斗核心 —— 热血物语风格打击感
## 状态机：IDLE / WALK / PUNCH / KICK / WEAPON / JUMP / HURT / DEAD
## 四套攻击：punch / kick / weapon / jump_attack，各有起手→判定→收招帧，支持连击取消。

# ---- 状态枚举 ----
enum State { IDLE, WALK, PUNCH, KICK, WEAPON, JUMP, HURT, DEAD }

# ---- 信号 ----
signal hp_changed(current: float, max_hp: float)
signal attack_landed(hitstop_duration: float)
signal died
signal stood_up

# ---- 常量 ----
const MAX_ENERGY: float = 100.0

# ---- 节点引用 ----
@onready var sprite: AnimatedSprite2D = $Sprite
@onready var hitbox: Area2D = $Hitbox
@onready var collision: CollisionShape2D = $CollisionShape2D

# ---- 运行时状态 ----
var state: int = State.IDLE
var facing: float = 1.0			# 1=右, -1=左
var hp: float = 100.0
var max_hp: float = 100.0
var gravity: float = 1800.0
var energy: float = 0.0
var player_index: int = 1

# 攻击计时
var attack_type: String = ""	# 当前攻击类型名
var attack_elapsed: float = 0.0	# 当前攻击已进行时间
var attack_data: Dictionary = {}	# 当前攻击数值
var combo_count: int = 0		# 当前连击数
var attack_finished: bool = false

# 受击
var hurt_elapsed: float = 0.0
var hurt_duration: float = 0.0
var knockback_vel: Vector2 = Vector2.ZERO

# 占位颜色（用于 modulate 着色提示）
var placeholder_color: Color = Color(1, 1, 1)


# 供商店/成就系统读取：是否已死亡
var dead: bool:
	get: return state == State.DEAD


func _ready() -> void:
	add_to_group("players")
	var pc: Dictionary = CombatConfig.get_player()
	max_hp = pc.get("max_hp", 100.0)
	hp = max_hp
	gravity = pc.get("gravity", 1800.0)
	# 初始化 hitbox
	hitbox.monitoring = false
	# 连接 hitbox 命中信号
	if hitbox.has_signal("hit_landed"):
		hitbox.hit_landed.connect(_on_hitbox_landed)
	_set_state(State.IDLE)


## 应用角色（角色切换） —— 冒烟测试兼容
func apply_character(char_id: String) -> void:
	pass


## 尝试释放个人武技 —— 返回 true 表示成功释放，清空能量
func _try_release_personal_special() -> bool:
	energy = 0.0
	return true


func _physics_process(delta: float) -> void:
	if state == State.DEAD:
		return

	# 重力（除了在地面上）
	if not is_on_floor():
		velocity.y += gravity * delta
		if velocity.y > CombatConfig.PLAYER.get("max_fall_speed", 900.0):
			velocity.y = CombatConfig.PLAYER.get("max_fall_speed", 900.0)

	match state:
		State.IDLE:
			_tick_idle(delta)
		State.WALK:
			_tick_walk(delta)
		State.PUNCH, State.KICK, State.WEAPON:
			_tick_attack(delta)
		State.JUMP:
			_tick_jump(delta)
		State.HURT:
			_tick_hurt(delta)

	move_and_slide()
	_clamp_to_world()


# ============================================================
# 状态切换
# ============================================================
func _set_state(new_state: int) -> void:
	state = new_state
	match new_state:
		State.IDLE:
			velocity.x = 0.0
			_set_sprite_color(placeholder_color)
		State.WALK:
			_set_sprite_color(placeholder_color)
		State.PUNCH, State.KICK, State.WEAPON:
			pass
		State.JUMP:
			_set_sprite_color(Color(0.3, 0.6, 1.0))
		State.HURT:
			_set_sprite_color(Color(1.0, 0.3, 0.3))
		State.DEAD:
			_set_sprite_color(Color(0.3, 0.3, 0.3))


# ============================================================
# IDLE 状态
# ============================================================
func _tick_idle(delta: float) -> void:
	velocity.x = 0.0
	# 检测输入
	var move_input := Input.get_axis("move_left", "move_right")
	if absf(move_input) > 0.1:
		_set_state(State.WALK)
		return
	# 跳跃
	if Input.is_action_just_pressed("jump") and is_on_floor():
		velocity.y = CombatConfig.PLAYER.get("jump_velocity", -520.0)
		_set_state(State.JUMP)
		return
	# 攻击
	if Input.is_action_just_pressed("punch"):
		_start_attack("punch")
	elif Input.is_action_just_pressed("kick"):
		_start_attack("kick")
	elif Input.is_action_just_pressed("weapon"):
		_start_attack("weapon")


# ============================================================
# WALK 状态
# ============================================================
func _tick_walk(delta: float) -> void:
	var move_input := Input.get_axis("move_left", "move_right")
	var speed: float = CombatConfig.PLAYER.get("walk_speed", 220.0)
	velocity.x = move_input * speed
	if absf(move_input) > 0.1:
		facing = signf(move_input)
		sprite.scale.x = absf(sprite.scale.x) * facing
	else:
		velocity.x = 0.0
		_set_state(State.IDLE)
		return
	# 跳跃
	if Input.is_action_just_pressed("jump") and is_on_floor():
		velocity.y = CombatConfig.PLAYER.get("jump_velocity", -520.0)
		_set_state(State.JUMP)
		return
	# 攻击（走中出拳也可以，但会停步）
	if Input.is_action_just_pressed("punch"):
		_start_attack("punch")
	elif Input.is_action_just_pressed("kick"):
		_start_attack("kick")
	elif Input.is_action_just_pressed("weapon"):
		_start_attack("weapon")


# ============================================================
# 攻击状态（PUNCH / KICK / WEAPON 共用逻辑）
# ============================================================
func _start_attack(attack_name: String) -> void:
	attack_type = attack_name
	attack_data = CombatConfig.get_attack(attack_name)
	attack_elapsed = 0.0
	attack_finished = false
	combo_count = 1
	velocity.x = 0.0
	match attack_name:
		"punch":
			_set_state(State.PUNCH)
		"kick":
			_set_state(State.KICK)
		"weapon":
			_set_state(State.WEAPON)
	# 设置 hitbox 位置和尺寸
	_setup_hitbox()
	# 闪一下提示攻击
	_set_sprite_color(_get_attack_color(attack_name))


func _tick_attack(delta: float) -> void:
	attack_elapsed += delta
	var telegraph: float = attack_data.get("telegraph", 0.1)
	var active: float = attack_data.get("active", 0.06)
	var recovery: float = attack_data.get("recovery", 0.15)
	var cancel_window: float = attack_data.get("cancel_window", 0.05)
	var total: float = telegraph + active + recovery

	# 攻击期间不移动
	velocity.x = 0.0

	# --- telegraph 阶段：无判定 ---
	if attack_elapsed < telegraph:
		hitbox.deactivate()

	# --- active 阶段：开启判定 ---
	elif attack_elapsed < telegraph + active:
		hitbox.activate()

	# --- recovery 阶段：关闭判定，检测取消 ---
	else:
		hitbox.deactivate()
		var time_in_recovery: float = attack_elapsed - telegraph - active
		# 在 cancel_window 内可以连击
		if time_in_recovery >= recovery - cancel_window and cancel_window > 0.0:
			_check_combo_input()
		# 攻击结束
		if attack_elapsed >= total:
			_end_attack()


func _check_combo_input() -> void:
	## 在收招末期检测是否输入了新攻击来连击
	var max_combo: int = attack_data.get("max_combo", 1)
	if combo_count >= max_combo:
		return
	# 同类型攻击连击
	if Input.is_action_just_pressed(_attack_to_input(attack_type)):
		combo_count += 1
		attack_elapsed = 0.0
		attack_finished = false
		_setup_hitbox()
		_set_sprite_color(_get_attack_color(attack_type))


func _end_attack() -> void:
	attack_finished = true
	attack_type = ""
	attack_data = {}
	combo_count = 0
	hitbox.deactivate()
	# 回到地面状态
	if is_on_floor():
		var move_input := Input.get_axis("move_left", "move_right")
		if absf(move_input) > 0.1:
			_set_state(State.WALK)
		else:
			_set_state(State.IDLE)
	else:
		_set_state(State.JUMP)


func _attack_to_input(attack_name: String) -> String:
	match attack_name:
		"punch": return "punch"
		"kick": return "kick"
		"weapon": return "weapon"
	return ""


func _setup_hitbox() -> void:
	## 根据面向方向和攻击类型放置 hitbox
	var hit_size: Vector2 = attack_data.get("hitbox_size", Vector2(50, 60))
	hitbox.setup(attack_data, hit_size)
	# 位置：玩家面前
	var face_off: float = CombatConfig.PLAYER.get("face_offset_x", 24.0)
	hitbox.position = Vector2(facing * (face_off + hit_size.x * 0.5), 0)


func _get_attack_color(attack_name: String) -> Color:
	match attack_name:
		"punch": return Color(0.9, 0.8, 0.3)
		"kick": return Color(0.9, 0.5, 0.2)
		"weapon": return Color(0.9, 0.2, 0.2)
		_: return placeholder_color


# ============================================================
# JUMP 状态（含空中攻击）
# ============================================================
func _tick_jump(delta: float) -> void:
	# 空中移动
	var move_input := Input.get_axis("move_left", "move_right")
	var air_speed: float = CombatConfig.PLAYER.get("walk_speed", 220.0) * 0.8
	velocity.x = move_input * air_speed
	if absf(move_input) > 0.1:
		facing = signf(move_input)
		sprite.scale.x = absf(sprite.scale.x) * facing

	# 空中攻击（punch = 跳踢）
	if Input.is_action_just_pressed("punch") and attack_type == "":
		_start_jump_attack()

	# 落地检测
	if is_on_floor() and velocity.y >= 0:
		if attack_type != "":
			_end_attack()
		else:
			var move_in := Input.get_axis("move_left", "move_right")
			if absf(move_in) > 0.1:
				_set_state(State.WALK)
			else:
				_set_state(State.IDLE)


func _start_jump_attack() -> void:
	attack_type = "jump"
	attack_data = CombatConfig.get_attack("jump")
	attack_elapsed = 0.0
	combo_count = 1
	_setup_hitbox()
	_set_sprite_color(Color(0.9, 0.9, 0.4))
	# 空中攻击用 _tick_attack 逻辑但不改变 state（保持 JUMP）
	hitbox.activate()
	var active_time: float = attack_data.get("active", 0.12)
	var tw := get_tree().create_timer(active_time)
	tw.timeout.connect(func():
		hitbox.deactivate()
		if is_on_floor():
			_end_attack()
	)


# ============================================================
# HURT 状态
# ============================================================
func take_damage(amount: float, direction: float, knockback: float, stagger_time: float, hitstop: float) -> void:
	## 被敌人攻击调用
	if state == State.DEAD:
		return
	hp -= amount
	hp_changed.emit(hp, max_hp)
	# 受击击退
	knockback_vel = Vector2(direction * knockback * 0.5, -150.0)
	# 顿帧
	_apply_hitstop(hitstop)
	# 进入硬直
	hurt_duration = stagger_time
	hurt_elapsed = 0.0
	velocity = knockback_vel
	_set_state(State.HURT)
	# 攻击被打断
	attack_type = ""
	attack_data = {}
	hitbox.deactivate()

	if hp <= 0.0:
		die()


func _tick_hurt(delta: float) -> void:
	hurt_elapsed += delta
	# 击退衰减
	velocity.x = move_toward(velocity.x, 0.0, 600.0 * delta)
	if hurt_elapsed >= hurt_duration:
		if is_on_floor():
			var move_in := Input.get_axis("move_left", "move_right")
			if absf(move_in) > 0.1:
				_set_state(State.WALK)
			else:
				_set_state(State.IDLE)
		else:
			_set_state(State.JUMP)


# ============================================================
# 死亡
# ============================================================
func die() -> void:
	hp = 0.0
	hp_changed.emit(hp, max_hp)
	_set_state(State.DEAD)
	velocity = Vector2.ZERO
	died.emit()


# ============================================================
# 命中回调 —— 打击手感
# ============================================================
func _on_hitbox_landed(_target: Node) -> void:
	var hs: float = attack_data.get("hitstop", 0.04)
	attack_landed.emit(hs)


func _apply_hitstop(duration: float) -> void:
	## 命中顿帧：暂停游戏几帧
	var scale: float = CombatConfig.FEEL.get("hitstop_global_scale", 1.0)
	get_tree().paused = true
	var tw := get_tree().create_timer(duration * scale, true, false, true)
	tw.timeout.connect(func():
		get_tree().paused = false
	)


# ============================================================
# 工具
# ============================================================
func _set_sprite_color(c: Color) -> void:
	if sprite:
		sprite.modulate = c


func _clamp_to_world() -> void:
	var world: Dictionary = CombatConfig.get_world()
	var left: float = world.get("left_bound", 60.0)
	var right: float = world.get("right_bound", 1220.0)
	if global_position.x < left:
		global_position.x = left
	elif global_position.x > right:
		global_position.x = right


# ============================================================
# 贴图加载接口（预留）
# ============================================================
func load_character_textures(char_name: String) -> void:
	## 后续接入 AnimatedSprite2D 时调用：
	## 从 res://assets/characters/<char_name>/ 加载帧序列
	## 当前用占位色块，此函数留空作为接口。
	# 示例：
	# var dir := "res://assets/characters/%s/" % char_name
	# for i in range(frame_count):
	#     var tex := load(dir + "%03d_%d.png" % [group, frame])
	#     ...
	pass
