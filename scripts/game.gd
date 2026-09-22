extends Node2D
# 主控：波次生成、多武器子弹/手雷/近战/必杀结算、拾取结算、buff、时间追踪、援护召唤

const ZOMBIE_SCENE := preload("res://scenes/zombie.tscn")
const BULLET_SCENE := preload("res://scenes/bullet.tscn")
const GRENADE_SCENE := preload("res://scenes/grenade.tscn")
const PICKUP_SCENE := preload("res://scenes/item_pickup.tscn")
const SHOP_SCENE := preload("res://scenes/shop.tscn")
const PAUSE_MENU_SCENE := preload("res://scenes/pause_menu.tscn")
const ELITE_SCENE := preload("res://scenes/elite.tscn")  # V1.3 精英怪通用场景
const GROUND_Y := 520.0
const SPAWN_WAIT := 1.1
const WAVE_BREAK := 3.0
const BLAST_GROUP := "zombies"

var score := 0
var kills := 0
var wave := 0
var alive_needed := 0
var game_over := false
var spawn_timer: Timer
var next_wave_timer: Timer

# ---- V1.2 多关卡系统（数据驱动，LevelConfig 提供波次表）----
var current_level: int = 1            # 当前关卡 1/2/3
var level_transitioning: bool = false # 过关过场期间禁止生成丧尸
var _spawn_queue: Array = []          # 当前波次待生成丧尸类型队列
var _transition_label: Label = null  # 过关/换关横幅（运行时创建，不改 hud.tscn）

# ---- V1.0 时间追踪 ----
var elapsed_time: float = 0.0
var _time_ui_timer := 0.0

@onready var player: Player = $Player
@onready var player2: Player = $Player2
@onready var zombies: Node2D = $Zombies
@onready var bullets: Node2D = $Bullets
@onready var hud: CanvasLayer = $HUD
@onready var vehicle: CharacterBody2D = $Vehicle

# ---- V1.2 黑市商店 UI（运行时实例化，按 B 打开/关闭）----
var shop: CanvasLayer = null

# ---- V1.2 暂停菜单（ESC / 触屏暂停键开关，process_mode=ALWAYS）----
var is_paused: bool = false
var pause_menu: CanvasLayer = null

# ---- V1.1 双人合作 ----
var friendly_fire: bool = true  # 友军伤害开关（近战可误伤友方）
var _zombie_target_timer := 0.0
const ZOMBIE_TARGET_INTERVAL := 0.5

# ---- V1.4 人机队友（bot）：2P 始终为 AI，桌面/安卓均生效 ----
var bot_enabled: bool = true

# ---- V2.2 兄弟连携：双人同刻 melee → 合体技 ----
const COMBO_ATTACK_RANGE := 60.0
const COMBO_ATTACK_COOLDOWN := 5.0
const COMBO_ATTACK_DAMAGE_MULT := 2.0
const COMBO_ATTACK_WINDOW := 0.3       # 双方 melee 时间窗口（秒）
const COMBO_HIT_RANGE := 150.0         # 合体技前方命中范围
var _combo_cooldown: float = 0.0
var _p1_melee_time: float = -999.0
var _p2_melee_time: float = -999.0


func _ready() -> void:
	spawn_timer = Timer.new()
	spawn_timer.wait_time = SPAWN_WAIT
	spawn_timer.timeout.connect(_spawn_zombie)
	add_child(spawn_timer)

	next_wave_timer = Timer.new()
	next_wave_timer.one_shot = true
	next_wave_timer.timeout.connect(_start_wave)
	add_child(next_wave_timer)

	player.shoot_requested.connect(_on_shoot_requested)
	player.melee_requested.connect(_on_melee_requested)
	player.special_used.connect(_on_special_used)
	player.hp_changed.connect(hud.set_hp)
	player.energy_changed.connect(hud.set_energy)
	player.ammo_changed.connect(hud.set_ammo)
	player.died.connect(_on_player_died)
	# ---- V1.0 新信号 ----
	player.weapon_changed.connect(hud.set_weapon)
	player.grenade_changed.connect(hud.set_grenades)
	player.buffs_changed.connect(hud.set_buffs)
	player.grenade_requested.connect(_on_grenade_requested)

	# ---- V1.1 P2 信号连接：HUD 直连 P2 函数，战斗事件用 lambda 捕获玩家引用 ----
	player2.hp_changed.connect(hud.set_hp_p2)
	player2.energy_changed.connect(hud.set_energy_p2)
	player2.ammo_changed.connect(hud.set_ammo_p2)
	player2.weapon_changed.connect(hud.set_weapon_p2)
	player2.grenade_changed.connect(hud.set_grenades_p2)
	player2.buffs_changed.connect(hud.set_buffs_p2)
	player2.shoot_requested.connect(func(pos: Vector2, dir: Vector2) -> void:
		_on_shoot_requested(pos, dir, player2))
	player2.melee_requested.connect(func(pos: Vector2, dir: Vector2) -> void:
		_on_melee_requested(pos, dir, player2))
	player2.special_used.connect(func() -> void:
		_on_special_used(player2))
	player2.grenade_requested.connect(func(pos: Vector2, dir: Vector2) -> void:
		_on_grenade_requested(pos, dir, player2))
	player2.died.connect(_on_player_died)
	# ---- V1.1 半尸化状态同步 HUD ----
	player.half_zombie_changed.connect(_on_half_zombie_changed)
	player2.half_zombie_changed.connect(_on_half_zombie_changed)
	# ---- V2.2 根性起身信号（仅日志/反馈，不破坏现有连接）----
	player.stood_up.connect(_on_player_stood_up)
	player2.stood_up.connect(func(p_index: int) -> void: _on_player_stood_up(p_index))

	# 连接场景中已放置的拾取物 + 监听后续动态生成的拾取物
	_scan_for_pickups(self)
	get_tree().node_added.connect(_on_node_added)

	hud.set_hp(player.MAX_HP, player.MAX_HP)
	hud.set_energy(0.0, player.MAX_ENERGY)
	hud.set_score(0)
	hud.set_kills(0)
	hud.set_weapon(player.current_weapon)
	hud.set_grenades(int(player.weapon_ammo.get("grenade", 0)))
	hud.set_buffs([])
	hud.set_time(0.0)
	player._refresh_ammo_hud()
	# ---- V1.1 P2 HUD 初始化 ----
	hud.set_hp_p2(player2.MAX_HP, player2.MAX_HP)
	hud.set_energy_p2(0.0, player2.MAX_ENERGY)
	hud.set_weapon_p2(player2.current_weapon)
	hud.set_grenades_p2(int(player2.weapon_ammo.get("grenade", 0)))
	hud.set_buffs_p2([])
	player2._refresh_ammo_hud()
	# ---- V1.1 载具注册 ----
	vehicle.add_to_group("vehicles")
	_start_wave()
	# ---- V1.1 动态生成急救箱 ----
	_spawn_first_aid_kit()

	# ---- V1.2 黑市商店：实例化并隐藏，B 键开关；金币变化同步 HUD ----
	var shop_inst: CanvasLayer = SHOP_SCENE.instantiate()
	shop_inst.name = "Shop"
	add_child(shop_inst)
	shop_inst.visible = false
	shop = shop_inst
	Economy.coins_changed.connect(hud.set_coins)
	hud.set_coins(Economy.coins)

	# ---- V1.2 暂停菜单：实例化并隐藏，ESC 或触屏 BtnPause 开关 ----
	var pm_inst: CanvasLayer = PAUSE_MENU_SCENE.instantiate()
	pm_inst.name = "PauseMenu"
	add_child(pm_inst)
	pm_inst.visible = false
	pause_menu = pm_inst

	# ---- V1.4 人机队友：2P 始终由电脑控制（桌面/安卓均生效）----
	if bot_enabled:
		var p2_node := get_node_or_null("Player2")
		if p2_node != null and p2_node.has_method("setup_as_bot"):
			p2_node.setup_as_bot(player)


func _physics_process(delta: float) -> void:
	if game_over:
		return
	elapsed_time += delta
	_time_ui_timer -= delta
	if _time_ui_timer <= 0.0:
		_time_ui_timer = 0.5
		hud.set_time(elapsed_time)
	# ---- V1.1 每 0.5s 刷新丧尸目标为最近存活玩家 ----
	_zombie_target_timer -= delta
	if _zombie_target_timer <= 0.0:
		_zombie_target_timer = ZOMBIE_TARGET_INTERVAL
		_update_zombie_targets()
	# ---- V2.2 合体技冷却倒计时 + 救援加速检测 ----
	_combo_cooldown = maxf(_combo_cooldown - delta, 0.0)
	_apply_rescue_haste()


# ---- V1.1 双玩家：丧尸周期性切换到最近的存活玩家 ----
func _get_nearest_alive_player(from_pos: Vector2) -> Player:
	var p1_alive := not player.dead
	var p2_alive := not player2.dead
	if p1_alive and not p2_alive:
		return player
	if p2_alive and not p1_alive:
		return player2
	if not p1_alive and not p2_alive:
		return player
	var d1: float = from_pos.distance_squared_to(player.global_position)
	var d2: float = from_pos.distance_squared_to(player2.global_position)
	return player if d1 <= d2 else player2


func _update_zombie_targets() -> void:
	for child in zombies.get_children():
		if child is Zombie and not child.is_queued_for_deletion():
			var z: Zombie = child
			z.player = _get_nearest_alive_player(z.global_position)


func _start_wave() -> void:
	if game_over:
		return
	if level_transitioning:
		return
	wave += 1
	# ---- V1.2 数据驱动：本关波次是否已全部打完 ----
	var total: int = LevelConfig.get_total_waves(current_level)
	if wave > total:
		_on_level_cleared()
		return
	var wc: Dictionary = LevelConfig.get_wave_config(current_level, wave - 1)
	_build_spawn_queue(wc)
	alive_needed = _spawn_queue.size()
	spawn_timer.wait_time = float(wc.get("interval", SPAWN_WAIT))
	hud.set_wave(wave)
	spawn_timer.start()
	# V2.0：Boss 波——普通丧尸生成完毕后延迟 1 秒召唤 Boss（不占用 alive_needed 计数）
	var boss_id: String = String(wc.get("boss_id", ""))
	if boss_id != "":
		var t := get_tree().create_timer(1.0)
		t.timeout.connect(func() -> void:
			if is_instance_valid(self) and not game_over and not level_transitioning:
				spawn_boss(Vector2(640, 420), boss_id))


# ---- V1.2 按 wave_config 构建本波丧尸类型队列并打散 ----
func _build_spawn_queue(wc: Dictionary) -> void:
	_spawn_queue.clear()
	for i in int(wc.get("walkers", 0)):
		_spawn_queue.append(Zombie.Type.WALKER)
	for i in int(wc.get("runners", 0)):
		_spawn_queue.append(Zombie.Type.RUNNER)
	for i in int(wc.get("fat", 0)):
		_spawn_queue.append(Zombie.Type.FAT)
	_spawn_queue.shuffle()


func _spawn_zombie() -> void:
	if game_over or level_transitioning:
		return
	if alive_needed <= 0:
		spawn_timer.stop()
		next_wave_timer.start(WAVE_BREAK)
		return
	alive_needed -= 1
	var z := ZOMBIE_SCENE.instantiate()
	var from_left := randf() < 0.5
	z.global_position = Vector2(-60.0 if from_left else 1340.0, 470.0)
	zombies.add_child(z)
	# ---- V1.2 从本波队列按配置类型生成（队列空时回退步行者，兼容旧逻辑）----
	var t: int = Zombie.Type.WALKER
	if not _spawn_queue.is_empty():
		t = int(_spawn_queue.pop_front())
	z.setup(t, _get_nearest_alive_player(z.global_position))
	z.add_to_group(BLAST_GROUP)
	z.died.connect(_on_zombie_died)


# ---- V1.2 关卡切换：释放旧 Level 节点，从 LevelConfig 加载新场景并重置波次 ----
func load_level(index: int) -> void:
	current_level = index
	level_transitioning = false
	# 清空本关残留战斗丧尸（发呆演出丧尸随 Level 节点一起释放）
	for child in zombies.get_children():
		child.queue_free()
	# 释放旧 Level 节点
	var old_level := $World.get_node_or_null("Level")
	if old_level != null:
		old_level.queue_free()
	# 从配置加载新关卡场景
	var lv: Dictionary = LevelConfig.get_level(index)
	var path: String = lv.get("scene", "")
	if path == "":
		return
	var packed: PackedScene = load(path)
	if packed == null:
		return
	var new_level: Node = packed.instantiate()
	new_level.name = "Level"
	$World.add_child(new_level)
	# 重置波次并启动第一波
	wave = 0
	_spawn_queue.clear()
	hud.hide_game_over()
	var lv_name: String = lv.get("name", "")
	_show_transition_banner("第%d关：%s" % [index, lv_name])
	print("V1.2 加载关卡：%s" % lv_name)
	_start_wave()


# ---- V1.2 本关所有波次清完：推进下一关或通关 ----
func _on_level_cleared() -> void:
	level_transitioning = true
	spawn_timer.stop()
	next_wave_timer.stop()
	# V2.0 数据驱动：下一关存在则推进，否则进入最终胜利
	var next_lv: Dictionary = LevelConfig.get_level(current_level + 1)
	if not next_lv.is_empty():
		var lv_name: String = LevelConfig.get_level(current_level).get("name", "")
		print("V1.2 关卡通过：%s，准备进入下一关" % lv_name)
		_show_transition_banner("第%d关 通过！" % current_level)
		await get_tree().create_timer(2.0).timeout
		if is_instance_valid(self) and not game_over:
			load_level(current_level + 1)
	else:
		print("V2.0 全部关卡通关！")
		_show_transition_banner("终章通关！热血物语完结！")
		await get_tree().create_timer(2.5).timeout
		if is_instance_valid(self) and not game_over:
			hud.show_game_over(score, wave)
			game_over = true


# ---- V1.2 过关/换关横幅（运行时创建 Label，不侵入 hud.tscn）----
func _show_transition_banner(text: String) -> void:
	if _transition_label == null or not is_instance_valid(_transition_label):
		_transition_label = Label.new()
		_transition_label.position = Vector2(340.0, 240.0)
		_transition_label.size = Vector2(600.0, 100.0)
		_transition_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_transition_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		_transition_label.add_theme_font_size_override("font_size", 44)
		_transition_label.add_theme_color_override("font_color", Color(1.0, 0.9, 0.3, 1.0))
		add_child(_transition_label)
	_transition_label.text = text
	_transition_label.visible = true
	_transition_label.modulate = Color(1, 1, 1, 1)
	var tw := create_tween()
	tw.tween_interval(1.8)
	tw.tween_property(_transition_label, "modulate:a", 0.0, 0.4)
	tw.tween_callback(func() -> void:
		if is_instance_valid(_transition_label):
			_transition_label.visible = false
			_transition_label.modulate = Color(1, 1, 1, 1)
	)


# ---- 子弹 / 手雷 ----
func _on_shoot_requested(pos: Vector2, dir: Vector2, source_player: Player = player) -> void:
	var b := BULLET_SCENE.instantiate()
	b.global_position = pos
	var w: String = source_player.current_weapon
	var base_dmg: int = int(Player.WEAPONS.get(w, {}).get("damage", 2))
	var spd: float = float(Player.WEAPONS.get(w, {}).get("speed", 640.0))
	var dmg := int(round(base_dmg * source_player.get_buff_multiplier("attack")))
	b.setup(dir, dmg, spd, w)
	# V1.1 记录子弹发射者（子弹 collision_mask=2 仅检测丧尸层，本就不命中玩家；
	# 该属性供后续友军伤害/归属统计使用。bullet.gd 不可改，用 set 动态挂属性）
	b.set("owner_player", source_player)
	bullets.add_child(b)


func _on_grenade_requested(pos: Vector2, dir: Vector2, source_player: Player = player) -> void:
	var g := GRENADE_SCENE.instantiate()
	g.global_position = pos
	g.setup(dir)
	bullets.add_child(g)


func _on_melee_requested(pos: Vector2, dir: Vector2, source_player: Player = player) -> void:
	# ---- V2.2 记录 melee 时间戳，供双人合体技检测 ----
	if source_player == player:
		_p1_melee_time = elapsed_time
	elif source_player == player2:
		_p2_melee_time = elapsed_time
	_check_combo_attack()
	var range_x := 60.0 * source_player.get_buff_multiplier("melee_range")
	var dmg := int(round(source_player.current_melee_damage * source_player.get_buff_multiplier("attack")))
	for child in zombies.get_children():
		if child is Zombie and not child.is_queued_for_deletion():
			var z: Zombie = child
			var dx: float = z.global_position.x - source_player.global_position.x
			var dy: float = absf(z.global_position.y - source_player.global_position.y)
			if dx * float(source_player.facing) > 0.0 and absf(dx) < range_x and dy < 64.0:
				if z.begging:
					# 求饶丧尸：近战收服而非伤害
					_capture_zombie(z, source_player)
				else:
					# 传入 is_melee=true，残血近战可触发求饶
					z.take_damage(dmg, true)
				source_player.add_energy(8.0)
	# ---- V1.1 友军伤害：近战范围内可命中另一名存活玩家 ----
	if friendly_fire:
		var other: Player = player2 if source_player == player else player
		if not other.dead and not other.is_queued_for_deletion():
			var odx: float = other.global_position.x - source_player.global_position.x
			var ody: float = absf(other.global_position.y - source_player.global_position.y)
			if odx * float(source_player.facing) > 0.0 and absf(odx) < range_x and ody < 64.0:
				other.take_damage(dmg)


func _on_special_used(source_player: Player = player) -> void:
	# 热血必杀：全屏震荡 + 援护召唤演出（只打丧尸，不伤害友军）
	for z in zombies.get_children():
		if z is Zombie and not z.is_queued_for_deletion():
			z.take_damage(60)
			score += 5
	hud.set_score(score)
	summon_assist("default", source_player)


# ======================================================================
# V2.2 兄弟连携 / 救援增强 / 死亡回上街区
# ======================================================================

# 双人合体技检测：P1/P2 都存活、距离 < 60、0.3s 内双方都按了 melee、冷却就绪
func _check_combo_attack() -> void:
	if _combo_cooldown > 0.0 or game_over or level_transitioning:
		return
	if player.dead or player2.dead:
		return
	if player.global_position.distance_to(player2.global_position) >= COMBO_ATTACK_RANGE:
		return
	if absf(_p1_melee_time - _p2_melee_time) > COMBO_ATTACK_WINDOW:
		return
	_trigger_combo_attack()


# 合体技效果：双方同时前冲，对前方 150px 敌人造成 (P1.atk + P2.atk)×2 伤害
func _trigger_combo_attack() -> void:
	_combo_cooldown = COMBO_ATTACK_COOLDOWN
	player.velocity.x += player.facing * 200.0
	player2.velocity.x += player2.facing * 200.0
	player.set_expression("grin")
	player2.set_expression("grin")
	var mid: Vector2 = (player.global_position + player2.global_position) * 0.5
	var fdir := player.facing
	var p1_atk: int = maxi(player.current_melee_damage, 2)
	var p2_atk: int = maxi(player2.current_melee_damage, 2)
	var dmg: int = int(round((p1_atk + p2_atk) * COMBO_ATTACK_DAMAGE_MULT))
	for z in zombies.get_children():
		if z is Zombie and not z.is_queued_for_deletion():
			var dx: float = z.global_position.x - mid.x
			var dy: float = absf(z.global_position.y - mid.y)
			if dx * float(fdir) > 0.0 and absf(dx) < COMBO_HIT_RANGE and dy < 80.0:
				z.take_damage(dmg)
				score += 5
	hud.set_score(score)
	print("V2.2 兄弟连携触发！伤害 %d" % dmg)


# 救援加速：P2 贴近起身中的 P1（<30px）时，将其站起时间减半一次
func _apply_rescue_haste() -> void:
	if player.standing_up and not player.dead and not player2.dead:
		if not player._stand_up_hastened \
				and player.global_position.distance_to(player2.global_position) < 30.0:
			player._stand_up_timer *= 0.5
			player._stand_up_hastened = true


# 根性起身反馈
func _on_player_stood_up(p_index: int) -> void:
	print("V2.2 根性起身：P%d 凭气势站了起来！" % p_index)


# 死亡回上街区：当前关 > 1 时，延迟 2s 回到上一关并重整玩家
var _rollback_in_progress: bool = false
func _rollback_to_previous_level() -> void:
	if _rollback_in_progress:
		return
	_rollback_in_progress = true
	level_transitioning = true
	spawn_timer.stop()
	next_wave_timer.stop()
	_show_transition_banner("回到上一个街区...")
	print("V2.2 死亡回上街区：第%d关 → 第%d关" % [current_level, current_level - 1])
	await get_tree().create_timer(2.0).timeout
	if not is_instance_valid(self):
		return
	# 玩家状态重置：hp满、energy清、武器回pistol、近战清空
	player.reset()
	player2.reset()
	# reset() 会把 is_bot 置 false，需重新把 P2 设回 bot
	if bot_enabled:
		player2.setup_as_bot(player)
	_rollback_in_progress = false
	load_level(current_level - 1)


# ---- V1.1 收服结算 ----
func _capture_zombie(z: Zombie, capturer: Player) -> void:
	var unit_data: Dictionary = z.capture()
	capturer.add_assist(unit_data)
	capturer.set_expression("grin")
	score += 15
	hud.set_score(score)


# 援护召唤（V1.1 收服系统：优先消耗已收服单位，无则回退默认墨镜大个子）
func summon_assist(assist_type: String, source_player: Player = player) -> void:
	source_player.set_expression("grin")
	# 优先使用已收服的援护单位（消耗品，召唤一次用一个）
	if not source_player.assist_units.is_empty():
		var unit_data: Dictionary = source_player.assist_units.pop_front()
		_spawn_captured_assist(unit_data, source_player)
		return
	if assist_type != "default":
		return
	_spawn_default_assist(source_player)


# V1.0 默认援护：墨镜大个子从左冲入
func _spawn_default_assist(caster: Player) -> void:
	var assist := Area2D.new()
	assist.collision_layer = 0
	assist.collision_mask = 0
	var body := ColorRect.new()
	body.color = Color(0.18, 0.18, 0.24, 1)
	body.offset_left = -22.0
	body.offset_top = -86.0
	body.offset_right = 22.0
	body.offset_bottom = 0.0
	assist.add_child(body)
	# 墨镜
	var gl := ColorRect.new()
	gl.color = Color(0.0, 0.0, 0.0, 1)
	gl.position = Vector2(-16.0, -72.0)
	gl.size = Vector2(13.0, 6.0)
	assist.add_child(gl)
	var gr := ColorRect.new()
	gr.color = Color(0.0, 0.0, 0.0, 1)
	gr.position = Vector2(3.0, -72.0)
	gr.size = Vector2(13.0, 6.0)
	assist.add_child(gr)
	assist.position = Vector2(-80.0, 470.0)
	add_child(assist)
	# 伤害碰撞区
	var hit := Area2D.new()
	hit.collision_layer = 0
	hit.collision_mask = 2  # 检测丧尸（layer 2）
	var cs := CollisionShape2D.new()
	var shape := CircleShape2D.new()
	shape.radius = 40.0
	cs.shape = shape
	hit.add_child(cs)
	assist.add_child(hit)
	hit.body_entered.connect(func(b: Node2D) -> void:
		if b is Zombie and not b.is_queued_for_deletion():
			b.take_damage(10)
	)
	# 从左冲入，跑过屏幕后消失
	var tw := create_tween()
	tw.tween_property(assist, "position:x", 1420.0, 1.6).set_trans(Tween.TRANS_LINEAR)
	tw.tween_callback(func() -> void:
		if is_instance_valid(assist):
			assist.queue_free()
	)


# V1.1 收服援护演出：三种类型外观/速度/伤害各异
func _spawn_captured_assist(unit_data: Dictionary, caster: Player) -> void:
	var ztype: int = int(unit_data.get("type", 0))
	var dmg: int = int(unit_data.get("damage", 10))
	# 玩家在左半屏→援护从左冲入；右半屏→从右冲入
	var from_left := caster.global_position.x < 700.0
	var body_color := Color(0.55, 0.30, 0.80, 1)  # Walker 紫色不良少年
	var dur := 1.4
	var w := 44.0
	var h := 86.0
	match ztype:
		Zombie.Type.RUNNER:
			body_color = Color(0.18, 0.66, 0.44, 1)  # 绿色快速单位
			dur = 0.9
			w = 34.0
			h = 70.0
		Zombie.Type.FAT:
			body_color = Color(0.62, 0.42, 0.22, 1)  # 棕色大个子
			dur = 2.3
			w = 60.0
			h = 100.0
		_:
			body_color = Color(0.55, 0.30, 0.80, 1)
			dur = 1.4
			w = 44.0
			h = 86.0
	var assist := Area2D.new()
	assist.collision_layer = 0
	assist.collision_mask = 0
	var body := ColorRect.new()
	body.color = body_color
	body.offset_left = -w / 2.0
	body.offset_top = -h
	body.offset_right = w / 2.0
	body.offset_bottom = 0.0
	assist.add_child(body)
	var start_x := -80.0 if from_left else 1420.0
	var end_x := 1420.0 if from_left else -80.0
	assist.position = Vector2(start_x, 470.0)
	add_child(assist)
	var hit := Area2D.new()
	hit.collision_layer = 0
	hit.collision_mask = 2  # 检测丧尸（layer 2）
	var cs := CollisionShape2D.new()
	var shape := CircleShape2D.new()
	shape.radius = 40.0
	cs.shape = shape
	hit.add_child(cs)
	assist.add_child(hit)
	hit.body_entered.connect(func(b: Node2D) -> void:
		if b is Zombie and not b.is_queued_for_deletion():
			b.take_damage(dmg)
	)
	var tw := create_tween()
	tw.tween_property(assist, "position:x", end_x, dur).set_trans(Tween.TRANS_LINEAR)
	tw.tween_callback(func() -> void:
		if is_instance_valid(assist):
			assist.queue_free()
	)


# ---- 物品拾取结算 ----
func _scan_for_pickups(node: Node) -> void:
	if node is ItemPickup:
		_try_connect_pickup(node)
	for c in node.get_children():
		_scan_for_pickups(c)


func _on_node_added(node: Node) -> void:
	if node is ItemPickup:
		_try_connect_pickup(node)


func _try_connect_pickup(n: Node) -> void:
	if n is ItemPickup and not n.item_picked.is_connected(_on_item_picked):
		n.item_picked.connect(_on_item_picked)


func _on_item_picked(item_type: String) -> void:
	match item_type:
		"weapon_mg":
			player.switch_weapon("machine_gun")
			player.weapon_ammo["machine_gun"] = 120
			player._refresh_ammo_hud()
		"weapon_shotgun":
			player.switch_weapon("shotgun")
			player.weapon_ammo["shotgun"] = 24
			player._refresh_ammo_hud()
		"weapon_grenade":
			player.weapon_ammo["grenade"] = int(player.weapon_ammo.get("grenade", 0)) + 3
			player._refresh_ammo_hud()
		"food_onigiri":
			player.heal(25)
		"food_noodles":
			player.heal(15)
			player.add_energy(20.0)
		"food_drink":
			player.add_buff("sports_drink", 15.0)
		"chili_rice":
			player.add_buff("chili_rice", 15.0)
		"iron_pipe":
			# V2.1：iron_pipe 现为近战武器（不再是 buff），装备到最近存活玩家
			_get_nearest_alive_player(player.global_position).equip_melee_weapon("iron_pipe")
		"tire":
			_get_nearest_alive_player(player.global_position).equip_melee_weapon("tire")
		"trash_lid":
			_get_nearest_alive_player(player.global_position).equip_melee_weapon("trash_lid")
		"armor_vest":
			player.add_buff("armor_vest", 20.0)
		"ammo":
			_refill_ammo()
		"first_aid":
			# 拾取者（最近存活玩家）解除半尸化并回血 30
			var healer: Player = _get_nearest_alive_player(Vector2(920, 480))
			healer.cure_half_zombie()
			healer.heal(30)
			score += 10
			hud.set_score(score)


func _refill_ammo() -> void:
	# V2.1：pistol 为无限弹药副武器，不需要补 ammo；仅补 machine_gun/shotgun
	var target := player.current_weapon
	if target == "pistol" or target == "grenade":
		target = "machine_gun"
	var mx := player.get_weapon_max_ammo(target)
	if mx > 0 and player.current_weapon != "pistol":
		player.weapon_ammo[target] = mini(int(player.weapon_ammo.get(target, 0)) + 10, mx)
	player._refresh_ammo_hud()


# ---- V1.1 半尸化状态同步 HUD ----
func _on_half_zombie_changed(active: bool, p_index: int) -> void:
	hud.set_half_zombie(active, p_index)


# ---- V1.1 动态生成急救箱（玩家走过即拾取，item_picked 由 _on_node_added 自动连接）----
func _spawn_first_aid_kit() -> void:
	var p := PICKUP_SCENE.instantiate()
	p.item_type = "first_aid"
	p.global_position = Vector2(920, 480)
	add_child(p)


func _spawn_buff_drop(pos: Vector2, buff_name: String) -> void:
	var p := PICKUP_SCENE.instantiate()
	p.item_type = buff_name
	add_child(p)
	p.global_position = pos


func _on_zombie_died(z: Node2D) -> void:
	kills += 1
	score += 10
	hud.set_kills(kills)
	hud.set_score(score)
	# V1.1 掉落物/能量给最近存活玩家
	var recipient: Player = _get_nearest_alive_player(z.global_position)
	# V2.1：普通丧尸不再掉 ammo，改为 50% 能量 + 50% 金币
	if randf() < 0.5:
		recipient.add_energy(15.0)
	else:
		Economy.add_coins(randi_range(5, 10))
	# 10% 概率掉落随机 buff 道具（V2.1：过滤掉 iron_pipe，它现在是武器不是 buff）
	if randf() < 0.10:
		var pool: Array = BuffDefs.DROP_POOL.filter(func(b: Variant) -> bool: return str(b) != "iron_pipe")
		if not pool.is_empty():
			var bt: String = str(pool[randi() % pool.size()])
			_spawn_buff_drop(z.global_position, bt)
	# V2.1：精英/Boss 死亡 15% 概率掉落实用枪械（machine_gun/shotgun）
	if z.is_in_group("elites") or z.is_in_group("boss"):
		if randf() < 0.15:
			var wt: String = "weapon_mg" if randf() < 0.5 else "weapon_shotgun"
			_spawn_buff_drop(z.global_position, wt)
	# ---- V1.2 金币掉落（按丧尸类型，不影响既有掉落物/buff/能量逻辑）----
	if z is Zombie:
		match z.ztype:
			Zombie.Type.WALKER:
				Economy.add_coins(randi_range(5, 10))
			Zombie.Type.RUNNER:
				Economy.add_coins(randi_range(8, 15))
			Zombie.Type.FAT:
				Economy.add_coins(randi_range(20, 40))


func _on_player_died() -> void:
	# ---- V1.2 死亡金钱减半（学热血物语回档：每次玩家死亡金币折半）----
	Economy.on_player_death()
	# ---- V1.1 载具：玩家死亡时强制跳车兜底（伤害重定向理论上不会触发）----
	if player.in_vehicle and is_instance_valid(player.current_vehicle):
		player.current_vehicle.exit()
	if player2.in_vehicle and is_instance_valid(player2.current_vehicle):
		player2.current_vehicle.exit()
	# V1.1 双玩家：两人都死亡才 game over，单人死亡继续游戏
	if not player.dead and not player2.dead:
		return
	if not (player.dead and player2.dead):
		return
	# ---- V2.2 死亡回上街区：当前关 > 1 时回退上一关，否则保持 game over ----
	if current_level > 1:
		_rollback_to_previous_level()
		return
	game_over = true
	spawn_timer.stop()
	next_wave_timer.stop()
	hud.show_game_over(score, wave)


func _unhandled_input(event: InputEvent) -> void:
	if game_over and (event.is_action_pressed("restart") or event.is_action_pressed("p2_restart")):
		# V1.2 重开：清空金币/累计/永久技能（Economy 为跨场景 Autoload）
		Economy.reset()
		get_tree().reload_current_scene()
		return
	# ---- V1.2 暂停时冻结快捷键（商店/跳关等），暂停菜单自身处理 ESC/R ----
	if is_paused:
		return
	# ---- V1.2 ESC 暂停/继续（桌面端；移动端用触屏 BtnPause）----
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_ESCAPE and not game_over and not Economy.shop_open:
		toggle_pause()
		return
	# ---- V1.2 B 键开关黑市商店（游戏未结束且商店未开时响应；打开后由商店自身在暂停中处理 B 关闭）----
	if not game_over and not Economy.shop_open:
		if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_B:
			_toggle_shop()
	# ---- V1.2 关卡选择（简化调试）：数字键 1/2/3/4/5 直接跳关 ----
	if not game_over and not level_transitioning:
		if event is InputEventKey and event.pressed and not event.echo:
			if event.keycode == KEY_1:
				load_level(1)
			elif event.keycode == KEY_2:
				load_level(2)
			elif event.keycode == KEY_3:
				load_level(3)
			elif event.keycode == KEY_4:
				load_level(4)
			elif event.keycode == KEY_5:
				load_level(5)


# ---- V1.2 黑市商店开关 ----
func _toggle_shop() -> void:
	if game_over or shop == null:
		return
	if Economy.shop_open:
		shop.close()
	else:
		shop.open()


# ---- V1.2 暂停菜单开关（桌面 ESC / 触屏 BtnPause / 菜单按钮共用）----
func toggle_pause() -> void:
	is_paused = not is_paused
	get_tree().paused = is_paused
	if is_paused:
		if pause_menu == null or not is_instance_valid(pause_menu):
			var pm_inst: CanvasLayer = PAUSE_MENU_SCENE.instantiate()
			pm_inst.name = "PauseMenu"
			add_child(pm_inst)
			pause_menu = pm_inst
		pause_menu.open()
	else:
		if pause_menu and is_instance_valid(pause_menu):
			pause_menu.close()


# ---- V1.2 重新开始（暂停菜单"重新开始"复用；含 Economy.reset）----
func _restart_game() -> void:
	is_paused = false
	get_tree().paused = false
	Economy.reset()
	get_tree().reload_current_scene()


# ---- V1.4 人机队友开关回调（保留供调试/未来扩展；2P 始终为 AI）----
func set_bot_enabled(enabled: bool) -> void:
	bot_enabled = enabled
	var p2_node := get_node_or_null("Player2")
	if p2_node == null:
		return
	if enabled and p2_node.has_method("setup_as_bot"):
		p2_node.setup_as_bot(player)
	elif not enabled:
		p2_node.set("is_bot", false)


# ---- V1.3 首关 Boss 生成（独立函数，不改既有波次/经济/双人/暂停逻辑）----
const BOSS_SCENE := preload("res://scenes/boss.tscn")

func spawn_boss(pos: Vector2, boss_id: String = "street_boss") -> Node:
	var boss := BOSS_SCENE.instantiate() as Node
	# V2.0：在 add_child 前设置 export 值（_ready 在 add_child 时执行）
	boss.boss_id = boss_id
	boss.global_position = pos
	zombies.add_child(boss)
	if boss.has_method("setup"):
		boss.setup(player)
	# 信号连接：血量/阶段 → HUD，死亡 → 隐藏血条
	if boss.has_signal("hp_changed"):
		boss.hp_changed.connect(func(cur: int, mx: int) -> void:
			if is_instance_valid(boss):
				hud.set_boss_hp(cur, mx, boss.get_current_phase()))
	if boss.has_signal("phase_changed"):
		boss.phase_changed.connect(func(ph: int) -> void:
			if is_instance_valid(boss):
				hud.set_boss_hp(boss.hp, boss.max_hp, ph))
	if boss.has_signal("died"):
		boss.died.connect(func(_b: Node2D) -> void:
			hud.hide_boss_bar()
			# V2.1：Boss 死亡 15% 概率掉落实用枪械
			if randf() < 0.15:
				var wt: String = "weapon_mg" if randf() < 0.5 else "weapon_shotgun"
				_spawn_buff_drop(_b.global_position, wt))
	# V2.0：HUD 血条名称从 Boss 定义读取（不再写死）
	var boss_def: Dictionary = EnemyDefs.get_boss_def(boss_id)
	var boss_name: String = String(boss_def.get("name", boss_id))
	var boss_max_hp: int = int(boss_def.get("hp", 400))
	hud.show_boss_bar(boss_name, boss_max_hp)
	return boss


# ---- V1.3 精英怪生成（独立函数，不改既有波次/经济/双人/暂停逻辑）----
# elite_id: "bosozoku_leader"（暴走族干部）/ "zombie_butcher"（丧尸屠夫）
func spawn_elite(elite_id: String, pos: Vector2) -> Node:
	var e: Node = ELITE_SCENE.instantiate()
	e.elite_id = elite_id
	e.global_position = pos
	zombies.add_child(e)
	# 追踪目标：最近存活玩家
	e.setup(_get_nearest_alive_player(pos))
	# 死亡结算（独立 lambda，不新增命名函数；精英给更高击杀分）
	if e.has_signal("died"):
		e.died.connect(func(_eb: Node2D) -> void:
			kills += 1
			score += 50
			hud.set_kills(kills)
			hud.set_score(score)
			# V2.1：精英死亡 15% 概率掉落实用枪械
			if randf() < 0.15:
				var wt: String = "weapon_mg" if randf() < 0.5 else "weapon_shotgun"
				_spawn_buff_drop(_eb.global_position, wt))
	return e
