extends CharacterBody2D
## 敌人 AI —— 热血物语风格丧尸
## 状态机: IDLE → CHASE → ATTACK → STAGGER(受击) → DEAD(死亡倒地)
## 三种敌人: zombie_normal / zombie_fast / zombie_heavy

# ---- 状态枚举 ----
enum State { IDLE, CHASE, ATTACK, STAGGER, DEAD }

# ---- 信号 ----
signal died(enemy)
signal hp_changed(current: float, max_hp: float)

# ---- 节点引用 ----
@onready var sprite: AnimatedSprite2D = $Sprite
@onready var attack_hitbox: Area2D = $AttackHitbox
@onready var collision: CollisionShape2D = $CollisionShape2D

# ---- 运行时状态 ----
var state: int = State.IDLE
var enemy_type: String = "zombie_normal"
var enemy_data: Dictionary = {}
var target: Node2D = null			# 玩家引用
var facing: float = 1.0
var hp: float = 30.0
var max_hp: float = 30.0
var gravity: float = 1800.0

# 攻击计时
var attack_elapsed: float = 0.0
var attack_phase: int = 0			# 0=telegraph, 1=active, 2=recovery
var has_attacked: bool = false

# 受击
var stagger_timer: float = 0.0
var knockback_vel: Vector2 = Vector2.ZERO
var flash_timer: float = 0.0

# 死亡
var death_timer: float = 0.0

# 占位颜色（用于 modulate 着色提示）
var base_color: Color = Color(1, 1, 1)


func setup(type: String, player_ref: Node2D) -> void:
	## 由 EnemySpawner 调用：设置敌人类型和目标
	enemy_type = type
	enemy_data = CombatConfig.get_enemy(type)
	target = player_ref
	max_hp = enemy_data.get("max_hp", 30.0)
	hp = max_hp
	base_color = Color(1, 1, 1)
	# 根据敌人类型加载对应贴图
	_load_enemy_textures(type)
	_set_sprite_color(base_color)
	# 设置碰撞半径
	var r: float = enemy_data.get("collision_radius", 22.0)
	if collision:
		var shape := CircleShape2D.new()
		shape.radius = r
		collision.shape = shape
	# 初始化攻击 hitbox
	attack_hitbox.monitoring = false


func _ready() -> void:
	if enemy_data.is_empty():
		enemy_data = CombatConfig.get_enemy("zombie_normal")
		max_hp = enemy_data.get("max_hp", 30.0)
		hp = max_hp
		base_color = Color(1, 1, 1)
		_load_enemy_textures(enemy_type)
	_set_state(State.IDLE)


func _physics_process(delta: float) -> void:
	if state == State.DEAD:
		_tick_dead(delta)
		return

	# 重力
	if not is_on_floor():
		velocity.y += gravity * delta
		if velocity.y > 900.0:
			velocity.y = 900.0

	# 受击闪白计时
	if flash_timer > 0.0:
		flash_timer -= delta
		if flash_timer <= 0.0:
			_set_sprite_color(base_color)

	match state:
		State.IDLE:
			_tick_idle(delta)
		State.CHASE:
			_tick_chase(delta)
		State.ATTACK:
			_tick_attack(delta)
		State.STAGGER:
			_tick_stagger(delta)

	move_and_slide()
	_clamp_to_world()


# ============================================================
# 贴图加载：按敌人类型从 assets/enemies/<type>/ 加载帧
# ============================================================
func _load_enemy_textures(type: String) -> void:
	## 根据 e_type 加载对应目录下的丧尸贴图到 AnimatedSprite2D
	var subdir := ""
	match type:
		"zombie_normal":
			subdir = "normal"
		"zombie_fast":
			subdir = "fast"
		"zombie_heavy":
			subdir = "heavy"
		_:
			subdir = "normal"

	var dir_path := "res://assets/enemies/%s/" % subdir
	var dir := DirAccess.open(dir_path)
	if dir == null:
		push_warning("Enemy texture dir not found: " + dir_path)
		return

	# 收集目录下的 PNG 文件
	var textures: Array[Texture2D] = []
	dir.list_dir_begin()
	var file_name := dir.get_next()
	while file_name != "":
		if not dir.current_is_dir() and file_name.ends_with(".png") and not file_name.begins_with("."):
			var tex := load(dir_path + file_name) as Texture2D
			if tex:
				textures.append(tex)
		file_name = dir.get_next()
	dir.list_dir_end()

	if textures.is_empty():
		push_warning("No enemy textures found in " + dir_path)
		return

	# 按文件名排序，取前 N 帧作为 idle 动画
	textures.sort_custom(func(a, b): return a.resource_path < b.resource_path)
	var max_frames: int = min(textures.size(), 8)
	var frames := SpriteFrames.new()
	frames.add_animation("idle")
	for i in range(max_frames):
		frames.add_frame("idle", textures[i])
	frames.set_animation_speed("idle", 4.0)
	frames.set_animation_loop("idle", true)

	sprite.sprite_frames = frames
	sprite.animation = "idle"
	sprite.play("idle")


# ============================================================
# 状态切换
# ============================================================
func _set_state(new_state: int) -> void:
	state = new_state
	match new_state:
		State.IDLE:
			velocity.x = 0.0
		State.CHASE:
			pass
		State.ATTACK:
			velocity.x = 0.0
			attack_elapsed = 0.0
			attack_phase = 0
			has_attacked = false
			attack_hitbox.monitoring = false
		State.STAGGER:
			pass
		State.DEAD:
			velocity = Vector2.ZERO
			attack_hitbox.monitoring = false


# ============================================================
# IDLE: 短暂发呆后开始追击
# ============================================================
func _tick_idle(delta: float) -> void:
	velocity.x = 0.0
	# 直接进入追击（可加短暂延迟）
	_set_state(State.CHASE)


# ============================================================
# CHASE: 朝玩家移动
# ============================================================
func _tick_chase(delta: float) -> void:
	if target == null:
		return
	var dir := signf(target.global_position.x - global_position.x)
	facing = dir
	sprite.scale.x = absf(sprite.scale.x) * facing

	var chase_speed: float = enemy_data.get("chase_speed", 100.0)
	velocity.x = dir * chase_speed

	# 进入攻击距离
	var attack_range: float = enemy_data.get("attack_range", 55.0)
	var dist := absf(target.global_position.x - global_position.x)
	if dist <= attack_range:
		velocity.x = 0.0
		_set_state(State.ATTACK)


# ============================================================
# ATTACK: 攻击玩家（telegraph → active → recovery）
# ============================================================
func _tick_attack(delta: float) -> void:
	attack_elapsed += delta
	var telegraph: float = enemy_data.get("attack_telegraph", 0.45)
	var active: float = enemy_data.get("attack_active", 0.15)
	var recovery: float = enemy_data.get("attack_recovery", 0.5)
	var total: float = telegraph + active + recovery

	# 面向玩家
	if target:
		facing = signf(target.global_position.x - global_position.x)
		if facing == 0.0:
			facing = 1.0
		sprite.scale.x = absf(sprite.scale.x) * facing

	# telegraph: 闪白准备
	if attack_elapsed < telegraph:
		attack_hitbox.monitoring = false
		# 攻击前摇闪橙提示
		var pulse: float = (sin(attack_elapsed * 20.0) + 1.0) * 0.5
		_set_sprite_color(base_color.lerp(Color(1.0, 0.5, 0.0), pulse * 0.6))

	# active: 开启攻击判定
	elif attack_elapsed < telegraph + active:
		attack_hitbox.monitoring = true
		if not has_attacked and target:
			has_attacked = true
			var dmg: float = enemy_data.get("attack_damage", 6.0)
			# 检查是否命中玩家
			var dist := absf(target.global_position.x - global_position.x)
			var attack_range: float = enemy_data.get("attack_range", 55.0)
			if dist <= attack_range + 10.0 and target.has_method("take_damage"):
				var kb := 100.0
				var st := 0.2
				var hs := 0.03
				target.take_damage(dmg, facing, kb, st, hs)

	# recovery: 收招
	else:
		attack_hitbox.monitoring = false
		_set_sprite_color(base_color)
		if attack_elapsed >= total:
			# 回到 CHASE
			if target and is_instance_valid(target):
				var dist2 := absf(target.global_position.x - global_position.x)
				var ar: float = enemy_data.get("attack_range", 55.0)
				if dist2 > ar:
					_set_state(State.CHASE)
				else:
					# 玩家还在面前，再打一次（但间隔）
					attack_elapsed = 0.0
					has_attacked = false
			else:
				_set_state(State.IDLE)


# ============================================================
# STAGGER: 受击硬直
# ============================================================
func take_damage(amount: float, direction: float, knockback: float, stagger_time: float, hitstop: float) -> void:
	## 被玩家攻击调用
	if state == State.DEAD:
		return
	hp -= amount
	hp_changed.emit(hp, max_hp)

	# 抗性计算
	var sb_resist: float = enemy_data.get("stagger_resist", 0.0)
	var kb_resist: float = enemy_data.get("knockback_resist", 0.0)
	var actual_stagger: float = stagger_time * (1.0 - sb_resist)
	var actual_kb: float = knockback * (1.0 - kb_resist)

	# 击退
	knockback_vel = Vector2(direction * actual_kb, -120.0)
	velocity = knockback_vel

	# 闪白
	flash_timer = CombatConfig.FEEL.get("hit_flash_duration", 0.08)
	_set_sprite_color(Color(1.0, 1.0, 1.0))

	# 进入硬直（除非抗性满则不退）
	if actual_stagger > 0.05:
		stagger_timer = actual_stagger
		_set_state(State.STAGGER)
	else:
		# 重怪不进入硬直，只扣血
		_set_sprite_color(Color(1.0, 0.5, 0.5))

	if hp <= 0.0:
		die()


func _tick_stagger(delta: float) -> void:
	stagger_timer -= delta
	# 击退衰减
	velocity.x = move_toward(velocity.x, 0.0, 500.0 * delta)
	if stagger_timer <= 0.0:
		if target and is_instance_valid(target):
			_set_state(State.CHASE)
		else:
			_set_state(State.IDLE)


# ============================================================
# DEAD: 死亡倒地
# ============================================================
func die() -> void:
	hp = 0.0
	hp_changed.emit(hp, max_hp)
	_set_state(State.DEAD)
	death_timer = 0.0
	# 倒地旋转
	sprite.rotation = 90.0 * deg_to_rad(1.0)
	_set_sprite_color(Color(0.3, 0.3, 0.3))
	died.emit(self)


func _tick_dead(delta: float) -> void:
	death_timer += delta
	var fade_dur: float = CombatConfig.FEEL.get("death_fade_duration", 0.5)
	var fall_dur: float = CombatConfig.FEEL.get("death_fall_duration", 0.6)
	# 落地后开始淡出
	if death_timer > fall_dur:
		var alpha: float = 1.0 - (death_timer - fall_dur) / fade_dur
		alpha = clampf(alpha, 0.0, 1.0)
		_set_sprite_color(Color(0.3, 0.3, 0.3, alpha))
	# 完全淡出后 queue_free
	if death_timer >= fall_dur + fade_dur:
		queue_free()


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
