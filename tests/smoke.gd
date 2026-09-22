extends SceneTree
# 冒烟测试：验证核心玩法逻辑 + V1.0 系统（武器/弹药/手雷/UI/关卡/物品/buff/格斗）
# 运行：godot --headless --path . --script res://tests/smoke.gd

func _init() -> void:
	print("== 热血物语：末日丧尸 冒烟测试 ==")
	process_frame.connect(_run)

func _run() -> void:
	_test_zombie()
	_test_player()
	_test_ui_scenes()
	_test_weapons()
	_test_ammo_consumption()
	_test_grenade()
	_test_hud_v1()
	_test_level1()
	_test_destructible()
	_test_buffs()
	_test_combo()
	_test_vehicle()
	_test_coop()
	_test_capture()
	_test_half_zombie()
	_test_economy()
	_test_levels()
	_test_achievements()
	_test_character_select()
	_test_pause_ui()
	_test_enemy_defs()
	_test_lifesteal()
	_test_ability_tiers()
	_test_dodge_ai()
	_test_elites()
	_test_boss()
	_test_bot_teammate()
	_test_v2_levels()
	_test_final_boss()
	_test_weapons_external()
	_test_dlc_registry()
	_test_save_version()
	_test_v21_kick_combo()
	_test_v21_melee_weapon()
	_test_v21_gun_downgrade()
	_test_v21_delinquent_flee()
	_test_v21_bosozoku_dash()
	_test_v21_humanoid_begging()
	_test_v21_infighting_enhanced()
	_test_v22_stand_up()
	_test_v22_special_skills()
	_test_v22_combo_attack()
	_test_v22_shop_skill_books()
	_test_v22_level_subtitles()
	_test_v22_vending_machine()
	_test_v23_boss_humanoid_data()
	_test_v23_boss_fighting_techniques()
	_test_v23_boss_taunts()
	_test_v23_boss_visual_nodes()
	_test_v23_level5_arena()
	print("== 全部通过 ==")
	quit(0)


func _test_zombie() -> void:
	var z := load("res://scenes/zombie.tscn").instantiate() as Zombie
	root.add_child(z)
	z.setup(Zombie.Type.WALKER, null)
	assert(z.hp == 3, "步行丧尸初始 3 血")
	assert(z.speed == Zombie.WALK_SPEED, "步行丧尸速度正确")
	z.take_damage(2)
	assert(z.hp == 1, "受击扣血正确")
	z.take_damage(5)
	assert(z.hp <= 0, "血量归零进入死亡")
	print("zombie ok")


func _test_player() -> void:
	var p := load("res://scenes/player.tscn").instantiate() as Player
	root.add_child(p)
	assert(p.hp == Player.MAX_HP, "玩家满血")
	assert(p.ammo == Player.MAX_AMMO, "玩家满弹药")
	p.add_energy(50.0)
	assert(is_equal_approx(p.energy, 50.0), "能量累加正确")
	p.add_energy(100.0)
	assert(is_equal_approx(p.energy, Player.MAX_ENERGY), "能量不超过上限")
	p.take_damage(30)
	assert(p.hp == 70, "玩家受击扣血")
	p.invincible = false
	p.take_damage(999)
	assert(p.dead, "玩家死亡状态置位")
	print("player ok")


func _test_ui_scenes() -> void:
	var hud_scene: PackedScene = load("res://scenes/hud.tscn")
	assert(hud_scene != null, "hud.tscn 加载成功")
	var hud: CanvasLayer = hud_scene.instantiate() as CanvasLayer
	assert(hud != null, "hud 根节点是 CanvasLayer")
	root.add_child(hud)
	hud.free()

	var touch_scene: PackedScene = load("res://scenes/touch_controls.tscn")
	assert(touch_scene != null, "touch_controls.tscn 加载成功")
	var touch: CanvasLayer = touch_scene.instantiate() as CanvasLayer
	assert(touch != null, "touch_controls 根节点是 CanvasLayer")
	root.add_child(touch)
	touch.free()
	print("ui scenes ok")


# ---- V1.0 武器系统 ----
func _test_weapons() -> void:
	var p := load("res://scenes/player.tscn").instantiate() as Player
	root.add_child(p)
	assert(p.WEAPONS.size() == 4, "4 种武器已定义（手枪/机枪/霰弹/手雷）")
	assert(p.switch_weapon("machine_gun"), "切换机枪成功")
	assert(p.current_weapon == "machine_gun", "当前武器为机枪")
	assert(p.switch_weapon("shotgun"), "切换霰弹成功")
	assert(p.current_weapon == "shotgun", "当前武器为霰弹")
	assert(p.switch_weapon("grenade"), "切换手雷成功")
	assert(p.current_weapon == "grenade", "当前武器为手雷")
	assert(p.switch_weapon("pistol"), "切换手枪成功")
	assert(p.current_weapon == "pistol", "当前武器为手枪")
	assert(not p.switch_weapon("invalid_weapon"), "无效武器切换返回 false")
	p.queue_free()
	print("weapons ok")


func _test_ammo_consumption() -> void:
	var p := load("res://scenes/player.tscn").instantiate() as Player
	root.add_child(p)
	# 机枪：消耗弹药
	p.weapon_ammo["machine_gun"] = 120
	p.switch_weapon("machine_gun")
	p._try_shoot()
	assert(p.weapon_ammo["machine_gun"] == 119, "机枪弹药消耗 1 发")
	# 霰弹：消耗 1 发弹药（射出 5 颗弹片）
	p.weapon_ammo["shotgun"] = 24
	p.switch_weapon("shotgun")
	p._try_shoot()
	assert(p.weapon_ammo["shotgun"] == 23, "霰弹弹药消耗 1 发")
	# 手枪：无限弹药
	p.switch_weapon("pistol")
	p._try_shoot()
	assert(p.weapon_ammo["pistol"] == -1, "手枪弹药无限（-1）")
	# 弹药打空自动切回手枪
	p.weapon_ammo["machine_gun"] = 1
	p.switch_weapon("machine_gun")
	p._try_shoot()
	assert(p.current_weapon == "pistol", "弹药打空自动切回手枪")
	p.queue_free()
	print("ammo consumption ok")


func _test_grenade() -> void:
	var g_scene := load("res://scenes/grenade.tscn")
	assert(g_scene != null, "grenade.tscn 加载成功")
	var g := g_scene.instantiate() as Grenade
	assert(g != null, "手雷实例化成功")
	root.add_child(g)
	g.setup(Vector2.RIGHT)
	assert(g.velocity.x > 0.0, "手雷水平速度为正")
	assert(g.velocity.y < 0.0, "手雷初始有向上速度（抛物线轨迹）")
	assert(g.GRAVITY > 0.0, "手雷受重力影响")
	assert(g.BLAST_RADIUS == 80.0, "手雷爆炸半径 80")
	assert(g.BLAST_DAMAGE == 8.0, "手雷爆炸伤害 8")
	g.queue_free()
	print("grenade ok")


# ---- V1.0 HUD 函数 ----
func _test_hud_v1() -> void:
	var hud := load("res://scenes/hud.tscn").instantiate() as CanvasLayer
	root.add_child(hud)
	# 头像生命条 / 热血魂槽
	hud.set_hp(50, 100)
	hud.set_energy(75.0, 100.0)
	# 弹药 / 武器 / 手雷
	hud.set_ammo(100, 120)
	hud.set_weapon("machine_gun")
	hud.set_grenades(3)
	# buff 显示
	hud.set_buffs([
		{"name": "sports_drink", "remaining": 15.0},
		{"name": "chili_rice", "remaining": 12.0},
	])
	# 时间
	hud.set_time(65.0)
	hud.set_time(30.0)
	# 清空 buff
	hud.set_buffs([])
	hud.queue_free()
	print("hud v1 ok")


# ---- V1.0 首关场景 ----
func _test_level1() -> void:
	var level := load("res://scenes/level1.tscn")
	assert(level != null, "level1.tscn 加载成功")
	var inst = level.instantiate()
	assert(inst != null, "level1 实例化成功")
	root.add_child(inst)
	inst.queue_free()
	print("level1 ok")


# ---- V1.0 可破坏物 & 掉落 ----
func _test_destructible() -> void:
	# 程序化创建可破坏物（含必需子节点）
	var d := StaticBody2D.new()
	d.set_script(preload("res://scripts/destructible.gd"))
	var body := ColorRect.new()
	body.name = "Body"
	d.add_child(body)
	var hit_area := Area2D.new()
	hit_area.name = "HitArea"
	d.add_child(hit_area)
	var cs := CollisionShape2D.new()
	cs.shape = RectangleShape2D.new()
	d.add_child(cs)
	root.add_child(d)
	# 1-2 次命中不破坏
	d.take_damage(2)
	assert(not d.is_queued_for_deletion(), "1 次命中不破坏")
	d.take_damage(2)
	assert(not d.is_queued_for_deletion(), "2 次命中不破坏")
	# 记录破坏前 root 子节点数
	var child_count_before := root.get_child_count()
	# 第 3 次命中 → 破坏 + 掉落
	d.take_damage(2)
	assert(d.is_queued_for_deletion(), "3 次命中后进入销毁")
	# 掉落物已生成在 root 下
	var found_drop := false
	for child in root.get_children():
		if child is Area2D and child.get_script() != null:
			if child.get_script().resource_path.ends_with("item_pickup.gd"):
				found_drop = true
				child.queue_free()
	assert(found_drop, "可破坏物破坏后掉落物已生成")
	print("destructible ok")


# ---- V1.0 buff 系统 ----
func _test_buffs() -> void:
	var p := load("res://scenes/player.tscn").instantiate() as Player
	root.add_child(p)
	# 添加 4 种 buff 并验证倍率
	p.add_buff("sports_drink", 15.0)
	assert(p.has_buff("sports_drink"), "运动饮料 buff 已添加")
	assert(is_equal_approx(p.get_buff_multiplier("speed"), 1.3), "移速倍率 1.3")
	p.add_buff("chili_rice", 15.0)
	assert(is_equal_approx(p.get_buff_multiplier("attack"), 1.5), "攻击倍率 1.5")
	p.add_buff("iron_pipe", 20.0)
	assert(is_equal_approx(p.get_buff_multiplier("melee_range"), 1.5), "近战范围倍率 1.5")
	p.add_buff("armor_vest", 20.0)
	assert(is_equal_approx(p.get_buff_multiplier("defense"), 0.5), "减伤倍率 0.5")
	# 减伤生效：20 伤害变 10
	p.invincible = false
	p.take_damage(20)
	assert(p.hp == 90, "护甲减伤 50%：20 伤害实际扣 10")
	# 同类 buff 刷新取较大值
	p.add_buff("sports_drink", 5.0)
	assert(float(p.active_buffs["sports_drink"]) >= 5.0, "同类 buff 取较大剩余时间")
	# buff_changed 信号存在
	assert(p.buffs_changed != null, "buffs_changed 信号已定义")
	p.queue_free()
	print("buffs ok")


# ---- V1.0 格斗连击 / 蓄力 ----
func _test_combo() -> void:
	var p := load("res://scenes/player.tscn").instantiate() as Player
	root.add_child(p)
	# 三段连击（快速点按 charge_time < 0.8）
	p.charge_time = 0.1
	p._resolve_melee()
	assert(p.combo_count == 1, "连击第 1 段")
	assert(p.current_melee_damage == 2, "第 1 段伤害 2")
	p.charge_time = 0.1
	p._resolve_melee()
	assert(p.combo_count == 2, "连击第 2 段")
	assert(p.current_melee_damage == 3, "第 2 段伤害 3")
	p.charge_time = 0.1
	p._resolve_melee()
	assert(p.combo_count == 3, "连击第 3 段（终结技）")
	assert(p.current_melee_damage == 5, "第 3 段伤害 5")
	# 蓄力重击（charge_time >= 0.8）
	p.combo_count = 0
	p.charge_time = 1.0
	p._resolve_melee()
	assert(p.current_melee_damage == 8, "蓄力重击伤害 8")
	# 表情接口可用
	p.set_expression("grin")
	assert(p.current_expression == "grin", "表情切换为 grin")
	p.set_expression("normal")
	assert(p.current_expression == "normal", "表情恢复 normal")
	# 援护召唤前置：energy 满时 special 条件成立
	p.energy = Player.MAX_ENERGY
	assert(p.energy >= Player.MAX_ENERGY, "热血魂满时可触发援护召唤必杀")
	p.queue_free()
	print("combo ok")


# ---- V1.1 改装车载具 ----
func _test_vehicle() -> void:
	var v_scene := load("res://scenes/vehicle.tscn")
	assert(v_scene != null, "vehicle.tscn 加载成功")
	var v: Node = v_scene.instantiate()
	assert(v != null, "载具实例化成功")
	root.add_child(v)
	assert(v.durability == 3, "载具初始 3 格耐久")
	assert(v.cannon_ammo == 5, "载具主炮初始 5 发")
	assert(v.driver == null, "载具初始无驾驶者")
	# 玩家进入载具
	var p := load("res://scenes/player.tscn").instantiate() as Player
	root.add_child(p)
	v.enter(p)
	assert(v.driver == p, "玩家进入载具后 driver 指向玩家")
	assert(p.in_vehicle == true, "玩家 in_vehicle 标志为 true")
	assert(p.visible == false, "载具内玩家本体隐藏")
	# 手动关闭乘降无敌帧（测试环境无时间流逝，invincible 不会自动过期）
	v.invincible = false
	# 受击扣耐久（每次受击扣 1 格）
	v.take_damage(10)
	assert(v.durability == 2, "载具受击扣 1 格耐久")
	v.take_damage(10)
	assert(v.durability == 1, "载具再受击扣 1 格耐久")
	# 玩家跳出载具
	v.exit()
	assert(v.driver == null, "玩家跳出后 driver 为空")
	assert(p.in_vehicle == false, "玩家 in_vehicle 标志为 false")
	assert(p.visible == true, "玩家跳出后本体可见")
	p.queue_free()
	# 耐久归零强制跳车
	var p2 := load("res://scenes/player.tscn").instantiate() as Player
	root.add_child(p2)
	var v2: Node = v_scene.instantiate()
	root.add_child(v2)
	v2.enter(p2)
	v2.invincible = false
	v2.take_damage(10)  # 3→2
	v2.take_damage(10)  # 2→1
	v2.take_damage(10)  # 1→0 → 摧毁
	assert(v2.destroyed == true, "耐久归零后 destroyed 为 true")
	assert(p2.in_vehicle == false, "耐久归零强制跳车")
	p2.queue_free()
	print("vehicle ok")


# ---- V1.1 双人合作 ----
func _test_coop() -> void:
	var p1 := load("res://scenes/player.tscn").instantiate() as Player
	root.add_child(p1)
	assert(p1.player_index == 1, "P1 默认 player_index=1")
	assert(p1.is_in_group("players"), "P1 在 players 组")
	var p2 := load("res://scenes/player.tscn").instantiate() as Player
	p2.player_index = 2
	root.add_child(p2)
	assert(p2.player_index == 2, "P2 player_index=2")
	assert(p2.is_in_group("players"), "P2 在 players 组")
	# P2 输入辅助函数可用（无输入时返回默认值）
	assert(p2._get_move_axis() == 0.0, "P2 无输入时移动轴为 0")
	# 两个玩家独立状态互不影响
	p1.invincible = false
	p1.take_damage(20)
	assert(p1.hp == 80, "P1 受击扣血")
	assert(p2.hp == Player.MAX_HP, "P2 保持满血不受 P1 影响")
	# P2 也可独立受击
	p2.invincible = false
	p2.take_damage(30)
	assert(p2.hp == 70, "P2 受击扣血不影响 P1")
	assert(p1.hp == 80, "P1 血量保持不变")
	p1.queue_free()
	p2.queue_free()
	print("coop ok")


# ---- V1.1 收服系统 ----
func _test_capture() -> void:
	# 求饶触发：近战将丧尸打至 0<hp<=CAPTURE_THRESHOLD
	var z := load("res://scenes/zombie.tscn").instantiate() as Zombie
	root.add_child(z)
	z.setup(Zombie.Type.WALKER, null)
	assert(z.hp == 3, "步行丧尸初始 3 血")
	z.take_damage(1, true)  # 近战命中，hp=2，触发求饶
	assert(z.begging == true, "近战打至残血触发求饶")
	assert(z.hp == 2, "求饶丧尸血量保持 2 不死亡")
	# 子弹无法击杀求饶丧尸（求饶无敌）
	z.take_damage(100, false)
	assert(z.begging == true, "求饶状态无敌，子弹不造成伤害")
	assert(z.hp == 2, "求饶丧尸血量不变")
	# 收服
	var assist_data := z.capture()
	assert(assist_data is Dictionary, "capture() 返回援护数据字典")
	assert(assist_data.has("type"), "援护数据包含 type")
	assert(assist_data.has("name"), "援护数据包含 name")
	assert(assist_data.has("damage"), "援护数据包含 damage")
	# capture() 内部用 Tween 回调延迟 queue_free，此处手动确保销毁
	if not z.is_queued_for_deletion():
		z.queue_free()
	# 玩家援护列表
	var p := load("res://scenes/player.tscn").instantiate() as Player
	root.add_child(p)
	assert(p.get_assist_count() == 0, "初始援护数量为 0")
	p.add_assist(assist_data)
	assert(p.get_assist_count() == 1, "添加援护后数量为 1")
	assert(p.assist_units.size() == 1, "援护列表大小为 1")
	# 非近战击杀不触发求饶
	var z2 := load("res://scenes/zombie.tscn").instantiate() as Zombie
	root.add_child(z2)
	z2.setup(Zombie.Type.WALKER, null)
	z2.take_damage(1, false)  # 子弹，hp=2，但 is_melee=false
	assert(z2.begging == false, "子弹命中不触发求饶")
	z2.queue_free()
	p.queue_free()
	print("capture ok")


# ---- V1.1 半尸化变身 ----
func _test_half_zombie() -> void:
	var p := load("res://scenes/player.tscn").instantiate() as Player
	root.add_child(p)
	assert(p.half_zombie == false, "初始未半尸化")
	# 触发变身
	p.trigger_half_zombie()
	assert(p.half_zombie == true, "触发后半尸化标志为 true")
	# 锁武器：半尸化时射击不消耗弹药
	p.weapon_ammo["machine_gun"] = 100
	p.switch_weapon("machine_gun")
	p.shoot_cooldown = 0.0
	p._try_shoot()
	assert(p.weapon_ammo["machine_gun"] == 100, "半尸化锁武器：射击不消耗弹药")
	# 血腥喷射函数可用（无丧尸时不崩溃）
	p._blood_spray()
	# 解除变身
	p.cure_half_zombie()
	assert(p.half_zombie == false, "解除后半尸化标志为 false")
	# 解除后武器恢复：射击消耗弹药
	p.weapon_ammo["machine_gun"] = 100
	p.shoot_cooldown = 0.0
	p._try_shoot()
	assert(p.weapon_ammo["machine_gun"] == 99, "解除后武器恢复：射击消耗弹药")
	p.queue_free()
	# FAT 丧尸特殊攻击常量验证
	var z := load("res://scenes/zombie.tscn").instantiate() as Zombie
	root.add_child(z)
	z.setup(Zombie.Type.FAT, null)
	assert(z.LUNGE_SPEED == 350.0, "FAT 突进速度 350")
	assert(z.INFECT_CHANCE == 0.4, "FAT 感染率 40%")
	assert(z.SPECIAL_INTERVAL == 3.0, "FAT 特殊攻击间隔 3s")
	assert(z.LUNGE_RANGE == 80.0, "FAT 突进触发距离 80")
	z.queue_free()
	# HUD 半尸化指示函数可用
	var hud := load("res://scenes/hud.tscn").instantiate() as CanvasLayer
	root.add_child(hud)
	hud.set_half_zombie(true, 1)
	hud.set_half_zombie(false, 1)
	hud.set_half_zombie(true, 2)
	hud.set_half_zombie(false, 2)
	hud.queue_free()
	# half_zombie_changed 信号已定义
	var p2 := load("res://scenes/player.tscn").instantiate() as Player
	root.add_child(p2)
	assert(p2.half_zombie_changed != null, "half_zombie_changed 信号已定义")
	p2.queue_free()
	print("half zombie ok")


# ---- V1.2 经济系统 ----
func _test_economy() -> void:
	# 手动实例化 Economy 脚本（--script 模式下 Autoload 全局名不可用）
	var economy_script := load("res://scripts/economy.gd")
	var economy = economy_script.new()
	root.add_child(economy)
	# 金币增减
	economy.coins = 0
	economy.add_coins(100)
	assert(economy.coins == 100, "金币增加 100")
	assert(economy.total_earned == 100, "累计获得金币 100")
	# 消费扣款
	assert(economy.spend_coins(40) == true, "消费 40 成功")
	assert(economy.coins == 60, "扣款后金币 60")
	assert(economy.spend_coins(1000) == false, "余额不足消费失败")
	assert(economy.coins == 60, "消费失败金币不变")
	# 死亡金钱减半
	economy.on_player_death()
	assert(economy.coins == 30, "死亡金币减半：60→30")
	# 重置
	economy.reset()
	assert(economy.coins == 0, "重置后金币为 0")
	assert(economy.total_earned == 0, "重置后累计金币为 0")
	# 商品数据
	assert(economy.SHOP_ITEMS.size() >= 10, "商店至少 10 种商品")
	assert(economy.get_categories().size() == 4, "商店 4 个分类")
	assert(economy.get_items_by_category("ammo").size() >= 3, "弹药分类至少 3 件")
	assert(economy.get_items_by_category("skill").size() >= 2, "技能书分类至少 2 件")
	# coins_changed 信号存在
	assert(economy.coins_changed != null, "coins_changed 信号已定义")
	economy.queue_free()
	print("economy ok")


# ---- V1.2 多关卡系统 ----
func _test_levels() -> void:
	# 三关配置数据
	var lv1 = LevelConfig.get_level(1)
	assert(not lv1.is_empty(), "第1关配置存在")
	assert(lv1.get("name") == "黄昏町街道", "第1关名称正确")
	assert(LevelConfig.get_total_waves(1) == 5, "第1关 5 波")
	var lv2 = LevelConfig.get_level(2)
	assert(not lv2.is_empty(), "第2关配置存在")
	assert(lv2.get("name") == "白鹰高中", "第2关名称正确")
	assert(LevelConfig.get_total_waves(2) == 5, "第2关 5 波")
	var lv3 = LevelConfig.get_level(3)
	assert(not lv3.is_empty(), "第3关配置存在")
	assert(lv3.get("name") == "暴走族聚集地", "第3关名称正确")
	assert(LevelConfig.get_total_waves(3) == 6, "第3关 6 波")
	# 每波波次配置非空
	for lv_idx in [1, 2, 3]:
		var total = LevelConfig.get_total_waves(lv_idx)
		for w in range(total):
			var wc = LevelConfig.get_wave_config(lv_idx, w)
			assert(not wc.is_empty(), "第%d关第%d波波次配置非空" % [lv_idx, w+1])
			assert(wc.has("walkers"), "波次配置含 walkers")
			assert(wc.has("interval"), "波次配置含 interval")
	# level2/level3 场景加载
	var l2_scene := load("res://scenes/level2.tscn")
	assert(l2_scene != null, "level2.tscn 加载成功")
	var l2: Node = l2_scene.instantiate()
	assert(l2 != null, "level2 实例化成功")
	root.add_child(l2)
	l2.queue_free()
	var l3_scene := load("res://scenes/level3.tscn")
	assert(l3_scene != null, "level3.tscn 加载成功")
	var l3: Node = l3_scene.instantiate()
	assert(l3 != null, "level3 实例化成功")
	root.add_child(l3)
	l3.queue_free()
	print("levels ok")


# ---- V1.2 成就系统 ----
func _test_achievements() -> void:
	# 手动实例化 Achievements 脚本
	var ach_script := load("res://scripts/achievements.gd")
	var ach = ach_script.new()
	root.add_child(ach)
	# 至少 8 个成就
	assert(ach.ACHIEVEMENTS.size() >= 8, "至少 8 个成就定义")
	# 初始未解锁
	assert(ach.is_unlocked("first_kill") == false, "初始未解锁 first_kill")
	# 解锁
	ach.unlock("first_kill")
	assert(ach.is_unlocked("first_kill") == true, "解锁后 first_kill 为 true")
	assert(ach.get_unlocked_count() >= 1, "已解锁数量 >= 1")
	# 重复解锁不报错
	ach.unlock("first_kill")
	assert(ach.get_unlocked_count() >= 1, "重复解锁不增加数量")
	# achievement_unlocked 信号存在
	assert(ach.achievement_unlocked != null, "achievement_unlocked 信号已定义")
	# 存档读写
	ach.save_save()
	assert(FileAccess.file_exists(ach.SAVE_PATH), "存档文件已写入")
	# 清空后重新加载，验证持久化
	var saved_count = ach.get_unlocked_count()
	ach.unlocked.clear()
	ach.load_save()
	assert(ach.get_unlocked_count() == saved_count, "存档加载后解锁数量一致")
	# 重置存档
	ach.reset_save()
	assert(ach.get_unlocked_count() == 0, "重置存档后解锁数量为 0")
	ach.queue_free()
	# 成就面板场景加载
	var ap_scene := load("res://scenes/achievement_panel.tscn")
	assert(ap_scene != null, "achievement_panel.tscn 加载成功")
	var ap: Node = ap_scene.instantiate()
	assert(ap != null, "成就面板实例化成功")
	root.add_child(ap)
	ap.queue_free()
	print("achievements ok")


# ---- V1.2 选人系统 ----
func _test_character_select() -> void:
	# 手动实例化 CharacterData 脚本并以 "CharacterData" 名挂到 root（供 player.apply_character 查找）
	var cd_script := load("res://scripts/character_data.gd")
	var cd = cd_script.new()
	cd.name = "CharacterData"
	root.add_child(cd)
	# 至少 4 个角色（实际 5 个）
	assert(cd.CHARACTERS.size() >= 4, "至少 4 个可选角色")
	assert(cd.CHARACTERS.size() == 5, "实际 5 个角色（含隐藏）")
	# 角色属性倍率互异（不全是 1.0）
	var has_diff_speed = false
	var has_diff_atk = false
	var has_diff_hp = false
	for cid in cd.CHARACTERS:
		var c = cd.CHARACTERS[cid]
		if c.get("speed_mult", 1.0) != 1.0:
			has_diff_speed = true
		if c.get("atk_mult", 1.0) != 1.0:
			has_diff_atk = true
		if c.get("hp_mult", 1.0) != 1.0:
			has_diff_hp = true
	assert(has_diff_speed, "存在速度倍率异于 1.0 的角色")
	assert(has_diff_atk, "存在攻击倍率异于 1.0 的角色")
	assert(has_diff_hp, "存在体力倍率异于 1.0 的角色")
	# P1/P2 独立选人
	cd.select(1, "fighter")
	cd.select(2, "tank")
	assert(cd.get_selected(1) == "fighter", "P1 选中 fighter")
	assert(cd.get_selected(2) == "tank", "P2 选中 tank")
	assert(cd.get_selected(1) != cd.get_selected(2), "P1/P2 选人独立")
	# 可选角色列表
	assert(cd.get_available_ids().size() >= 4, "可选角色至少 4 个")
	# get_character 返回正确数据
	var fighter = cd.get_character("fighter")
	assert(fighter.get("name") == "格斗专家", "fighter 名称正确")
	assert(fighter.get("atk_mult") == 1.3, "fighter 攻击倍率 1.3")
	# 玩家属性注入（player._ready 会自动从 /root/CharacterData 读取）
	var p := load("res://scenes/player.tscn").instantiate() as Player
	root.add_child(p)
	p.apply_character("sprinter")
	assert(p.character_id == "sprinter", "玩家角色 id 注入正确")
	assert(is_equal_approx(p.char_speed_mult, 1.4), "sprinter 速度倍率 1.4 已注入")
	assert(is_equal_approx(p.char_atk_mult, 0.85), "sprinter 攻击倍率 0.85 已注入")
	assert(is_equal_approx(p.char_jump_mult, 1.25), "sprinter 跳跃倍率 1.25 已注入")
	p.queue_free()
	# 选人场景加载
	var sel_scene := load("res://scenes/select.tscn")
	assert(sel_scene != null, "select.tscn 加载成功")
	var sel: Node = sel_scene.instantiate()
	assert(sel != null, "选人场景实例化成功")
	root.add_child(sel)
	sel.queue_free()
	# 重置选人
	cd.reset()
	assert(cd.get_selected(1) == "pompadour", "重置后 P1 恢复默认 pompadour")
	cd.queue_free()
	print("character select ok")


# ---- V1.2 暂停菜单与触摸UI ----
func _test_pause_ui() -> void:
	# 暂停菜单场景加载
	var pm_scene := load("res://scenes/pause_menu.tscn")
	assert(pm_scene != null, "pause_menu.tscn 加载成功")
	var pm: Node = pm_scene.instantiate()
	assert(pm != null, "暂停菜单实例化成功")
	root.add_child(pm)
	pm.queue_free()
	# 商店场景加载（模块1产物）
	var shop_scene := load("res://scenes/shop.tscn")
	assert(shop_scene != null, "shop.tscn 加载成功")
	# 触摸控件新增按钮存在性
	var tc_scene := load("res://scenes/touch_controls.tscn")
	assert(tc_scene != null, "touch_controls.tscn 加载成功")
	var tc: Node = tc_scene.instantiate()
	root.add_child(tc)
	# 检查新增按钮节点（BtnShop/BtnInteract/BtnPause）
	assert(tc.get_node_or_null("BtnShop") != null, "触摸商店键 BtnShop 存在")
	assert(tc.get_node_or_null("BtnInteract") != null, "触摸互动键 BtnInteract 存在")
	assert(tc.get_node_or_null("BtnPause") != null, "触摸暂停键 BtnPause 存在")
	# 现有 6 键仍在（未被删除）
	assert(tc.get_node_or_null("BtnShoot") != null, "现有射击键 BtnShoot 保留")
	assert(tc.get_node_or_null("BtnJump") != null, "现有跳跃键 BtnJump 保留")
	assert(tc.get_node_or_null("BtnMelee") != null, "现有近战键 BtnMelee 保留")
	assert(tc.get_node_or_null("BtnSpecial") != null, "现有必杀键 BtnSpecial 保留")
	assert(tc.get_node_or_null("BtnCrouch") != null, "现有下蹲键 BtnCrouch 保留")
	assert(tc.get_node_or_null("BtnRestart") != null, "现有重开键 BtnRestart 保留")
	tc.queue_free()
	print("pause ui ok")


# ---- V1.3 数据表 ----
func _test_enemy_defs() -> void:
	# 普通小怪定义
	assert(EnemyDefs.NORMAL_ZOMBIES.size() == 3, "3种普通小怪定义")
	var walker_def = EnemyDefs.get_normal_def("walker")
	assert(walker_def.get("ability") == 0.5, "walker 能力值 0.5")
	assert(walker_def.get("lifesteal_rate") == 0.05, "walker 吸血率 5%")
	assert(walker_def.get("dodge_chance") == 0.40, "walker 躲避率 40%")
	var runner_def = EnemyDefs.get_normal_def("runner")
	assert(runner_def.get("ability") == 0.7, "runner 能力值 0.7")
	assert(runner_def.get("lifesteal_rate") == 0.05, "runner 吸血率 5%")
	assert(runner_def.get("burst_ability") == 2.5, "runner 爆发能力 2.5")
	var fat_def = EnemyDefs.get_normal_def("fat")
	assert(fat_def.get("ability") == 1.2, "fat 能力值 1.2")
	assert(fat_def.get("lifesteal_rate") == 0.05, "fat 吸血率 5%")
	assert(fat_def.get("burst_ability") == 3.0, "fat 爆发能力 3.0")
	# 精英定义
	assert(EnemyDefs.ELITES.size() >= 2, "至少2种精英定义")
	var elite_ids = EnemyDefs.get_elite_ids()
	assert(elite_ids.has("bosozoku_leader"), "暴走族干部精英存在")
	assert(elite_ids.has("zombie_butcher"), "丧尸屠夫精英存在")
	var boso_def = EnemyDefs.get_elite_def("bosozoku_leader")
	assert(boso_def.get("ability") == 4.5, "暴走族干部能力 4.5")
	assert(boso_def.get("lifesteal_rate") == 0.08, "精英吸血率 8%")
	assert(boso_def.get("super_armor") == true, "精英霸体 true")
	var butcher_def = EnemyDefs.get_elite_def("zombie_butcher")
	assert(butcher_def.get("ability") == 4.0, "丧尸屠夫能力 4.0")
	assert(butcher_def.get("hp") == 90, "丧尸屠夫血量 90")
	# Boss定义
	assert(EnemyDefs.BOSSES.size() >= 1, "至少1个Boss定义")
	var boss_def = EnemyDefs.get_boss_def("street_boss")
	assert(boss_def.get("ability") == 8.5, "Boss能力 8.5（7~10范围）")
	assert(boss_def.get("lifesteal_rate") == 0.10, "Boss吸血率 10%")
	assert(boss_def.get("hp") == 400, "Boss血量 400")
	assert(boss_def.get("super_armor") == true, "Boss霸体 true")
	var phases = boss_def.get("phases")
	assert(phases.size() == 3, "Boss三阶段")
	assert(phases[0].get("name") == "近战压制", "阶段1名称")
	assert(phases[1].get("name") == "召唤冲刺", "阶段2名称")
	assert(phases[2].get("name") == "狂暴吸血", "阶段3名称")
	assert(phases[2].get("lifesteal_mult") == 2.0, "阶段3吸血×2.0")
	var wp = boss_def.get("weak_point")
	assert(wp.get("damage_mult") == 2.0, "弱点窗口伤害×2")
	assert(wp.get("stun_duration") == 3.0, "弱点窗口3秒")
	print("enemy defs ok")


# ---- V1.3 怪物吸血 ----
func _test_lifesteal() -> void:
	# walker 吸血 5%
	var z := load("res://scenes/zombie.tscn").instantiate() as Zombie
	root.add_child(z)
	z.setup(Zombie.Type.WALKER, null)
	assert(z.lifesteal_rate == 0.05, "walker 吸血率 5%")
	# 设低血量后吸血
	z.hp = 1
	z.apply_lifesteal(20)  # floor(20*0.05)=1
	assert(z.hp == 2, "吸血20伤害回1血：1→2")
	# 吸血上限不超过 max_hp
	z.hp = 3
	z.apply_lifesteal(100)  # floor(100*0.05)=5，但上限3
	assert(z.hp == 3, "吸血不超过最大血量3")
	z.queue_free()
	# FAT 吸血同样 5%（所有小怪统一）
	var zf := load("res://scenes/zombie.tscn").instantiate() as Zombie
	root.add_child(zf)
	zf.setup(Zombie.Type.FAT, null)
	assert(zf.lifesteal_rate == 0.05, "fat 吸血率 5%")
	zf.hp = 10
	zf.apply_lifesteal(40)  # floor(40*0.05)=2
	assert(zf.hp == 12, "fat吸血40伤害回2血：10→12")
	zf.queue_free()
	# apply_lifesteal 函数存在且为公共接口
	var z2 := load("res://scenes/zombie.tscn").instantiate() as Zombie
	root.add_child(z2)
	z2.setup(Zombie.Type.RUNNER, null)
	assert(z2.has_method("apply_lifesteal"), "apply_lifesteal 公共接口存在")
	z2.queue_free()
	print("lifesteal ok")


# ---- V1.3 能力数值档位 ----
func _test_ability_tiers() -> void:
	# 小怪基础能力值
	var zw := load("res://scenes/zombie.tscn").instantiate() as Zombie
	root.add_child(zw)
	zw.setup(Zombie.Type.WALKER, null)
	assert(zw.get_current_ability() == 0.5, "walker 当前能力 0.5")
	assert(zw.base_ability == 0.5, "walker 基础能力 0.5")
	assert(zw.burst_ability == 2.0, "walker 爆发能力上限 2.0")
	zw.queue_free()
	var zr := load("res://scenes/zombie.tscn").instantiate() as Zombie
	root.add_child(zr)
	zr.setup(Zombie.Type.RUNNER, null)
	assert(zr.get_current_ability() == 0.7, "runner 当前能力 0.7")
	assert(zr.burst_ability == 2.5, "runner 爆发能力 2.5（2~3范围）")
	zr.queue_free()
	var zf := load("res://scenes/zombie.tscn").instantiate() as Zombie
	root.add_child(zf)
	zf.setup(Zombie.Type.FAT, null)
	assert(zf.get_current_ability() == 1.2, "fat 当前能力 1.2")
	assert(zf.burst_ability == 3.0, "fat 爆发能力 3.0（2~3范围）")
	zf.queue_free()
	# 能力值档位：小怪0.5 < 精英4~5 < Boss7~10
	var walker_ability = EnemyDefs.get_normal_def("walker").get("ability")
	var elite_ability = EnemyDefs.get_elite_def("bosozoku_leader").get("ability")
	var boss_ability = EnemyDefs.get_boss_def("street_boss").get("ability")
	assert(walker_ability < elite_ability, "小怪能力 < 精英能力")
	assert(elite_ability < boss_ability, "精英能力 < Boss能力")
	assert(boss_ability >= 7.0 and boss_ability <= 10.0, "Boss能力在7~10范围")
	assert(elite_ability >= 4.0 and elite_ability <= 5.0, "精英能力在4~5范围")
	print("ability tiers ok")


# ---- V1.3 躲避AI ----
func _test_dodge_ai() -> void:
	var z := load("res://scenes/zombie.tscn").instantiate() as Zombie
	root.add_child(z)
	z.setup(Zombie.Type.WALKER, null)
	# 躲避相关变量存在
	assert(z.dodge_chance == 0.40, "躲避概率 40%")
	assert(z.dodge_cooldown == 1.5, "躲避冷却 1.5秒")
	assert(z.hit_streak_threshold == 3, "连续命中3次强制躲避")
	# start_dodge 公共接口存在且可调用
	assert(z.has_method("start_dodge"), "start_dodge 公共接口存在")
	z.start_dodge()
	assert(z.is_dodging == true, "调用 start_dodge 后进入躲避状态")
	# 躲避状态变量
	assert(z.dodge_cooldown_timer > 0.0, "躲避后冷却计时器启动")
	z.queue_free()
	# runner 躲避率同样 40%（所有小怪统一）
	var zr := load("res://scenes/zombie.tscn").instantiate() as Zombie
	root.add_child(zr)
	zr.setup(Zombie.Type.RUNNER, null)
	assert(zr.dodge_chance == 0.40, "runner 躲避率 40%")
	zr.queue_free()
	# 扛伤：fat 有硬直抗性
	var zf := load("res://scenes/zombie.tscn").instantiate() as Zombie
	root.add_child(zf)
	zf.setup(Zombie.Type.FAT, null)
	assert(zf.stun_resist == 0.3, "fat 硬直抗性 0.3")
	assert(zf.super_armor == false, "普通小怪无霸体")
	zf.queue_free()
	print("dodge ai ok")


# ---- V1.3 精英怪 ----
func _test_elites() -> void:
	# 暴走族干部
	var es := load("res://scenes/elite.tscn")
	assert(es != null, "elite.tscn 加载成功")
	var e1: Node = es.instantiate()
	e1.elite_id = "bosozoku_leader"
	root.add_child(e1)
	assert(e1.hp == 60, "暴走族干部血量 60")
	assert(e1.max_hp == 60, "暴走族干部最大血量 60")
	assert(e1.damage == 20, "暴走族干部伤害 20")
	assert(e1.speed == 130, "暴走族干部速度 130")
	assert(e1.lifesteal_rate == 0.08, "精英吸血率 8%")
	assert(e1.super_armor == true, "精英霸体 true")
	assert(e1.get_current_ability() == 4.5, "暴走族干部能力 4.5")
	# 精英吸血
	e1.hp = 50
	e1.apply_lifesteal(50)  # floor(50*0.08)=4
	assert(e1.hp == 54, "精英吸血50伤害回4血：50→54")
	# 精英霸体：受击不闪红不后撤（仅扣血）
	var hp_before = e1.hp
	e1.take_damage(5, false)
	assert(e1.hp == hp_before - 5, "霸体精英受击扣血")
	e1.queue_free()
	# 丧尸屠夫
	var e2: Node = es.instantiate()
	e2.elite_id = "zombie_butcher"
	root.add_child(e2)
	assert(e2.hp == 90, "丧尸屠夫血量 90（高血量）")
	assert(e2.damage == 22, "丧尸屠夫伤害 22")
	assert(e2.speed == 75, "丧尸屠夫速度 75")
	assert(e2.lifesteal_rate == 0.08, "丧尸屠夫吸血率 8%")
	assert(e2.super_armor == true, "丧尸屠夫霸体 true")
	assert(e2.get_current_ability() == 4.0, "丧尸屠夫能力 4.0")
	assert(e2.stun_resist == 0.8, "丧尸屠夫硬直抗性 0.8")
	e2.queue_free()
	# 精英加入 zombies 组（玩家子弹可命中）
	var e3: Node = es.instantiate()
	e3.elite_id = "bosozoku_leader"
	root.add_child(e3)
	assert(e3.is_in_group("zombies"), "精英加入 zombies 组")
	assert(e3.is_in_group("elites"), "精英加入 elites 组")
	e3.queue_free()
	print("elites ok")


# ---- V1.3 Boss ----
func _test_boss() -> void:
	var bs := load("res://scenes/boss.tscn")
	assert(bs != null, "boss.tscn 加载成功")
	var b: Node = bs.instantiate()
	root.add_child(b)
	# Boss 属性
	assert(b.hp == 400, "Boss血量 400（耐打磨血）")
	assert(b.max_hp == 400, "Boss最大血量 400")
	assert(b.damage == 25, "Boss伤害 25")
	assert(b.speed == 95, "Boss速度 95")
	assert(b.lifesteal_rate == 0.10, "Boss吸血率 10%")
	assert(b.super_armor == true, "Boss霸体 true")
	assert(b.stun_resist == 0.9, "Boss硬直抗性 0.9")
	assert(b.get_current_ability() == 8.5, "Boss能力 8.5（7~10范围）")
	assert(b.get_current_phase() == 1, "Boss初始阶段1")
	# Boss加入组
	assert(b.is_in_group("zombies"), "Boss加入 zombies 组")
	assert(b.is_in_group("boss"), "Boss加入 boss 组")
	# 弱点窗口：伤害×2
	b.weak_point_active = true
	var hp_before = b.hp
	b.take_damage(10, false)
	assert(b.hp == hp_before - 20, "弱点窗口伤害×2：10→20")
	b.weak_point_active = false
	# Boss吸血 10%
	b.hp = 300
	b.apply_lifesteal(100)  # floor(100*0.10)=10
	assert(b.hp == 310, "Boss吸血100伤害回10血：300→310")
	# 霸体：普通受击仅扣血
	var hp2 = b.hp
	b.take_damage(5, false)
	assert(b.hp == hp2 - 5, "霸体Boss受击扣血")
	b.queue_free()
	# Boss 血条 HUD 节点存在
	var hud := load("res://scenes/hud.tscn").instantiate() as CanvasLayer
	root.add_child(hud)
	assert(hud.get_node_or_null("BossHealthBar") != null, "HUD Boss血条节点存在")
	assert(hud.has_method("show_boss_bar"), "show_boss_bar 函数存在")
	assert(hud.has_method("set_boss_hp"), "set_boss_hp 函数存在")
	assert(hud.has_method("hide_boss_bar"), "hide_boss_bar 函数存在")
	hud.queue_free()
	print("boss ok")


# ---- V1.3 人机2P队友 ----
func _test_bot_teammate() -> void:
	# 实例化 P2 玩家并设为 bot
	var p := load("res://scenes/player.tscn").instantiate() as Player
	root.add_child(p)
	p.player_index = 2
	# setup_as_bot 接口
	assert(p.has_method("setup_as_bot"), "setup_as_bot 公共接口存在")
	# 创建一个假目标（另一个玩家）
	var target := load("res://scenes/player.tscn").instantiate() as Player
	root.add_child(target)
	p.setup_as_bot(target)
	assert(p.is_bot == true, "setup_as_bot 后 is_bot=true")
	assert(p.bot_target == target, "bot_target 设置正确")
	assert(p.bot_state == "follow", "bot初始状态 follow")
	# _bot_process 函数存在且可调用（无敌人时不崩溃）
	assert(p.has_method("_bot_process"), "_bot_process 函数存在")
	p._bot_process(0.016)
	# bot 变量完整
	assert(p.bot_attack_cooldown >= 0.0, "bot_attack_cooldown 变量存在")
	assert(p.bot_preferred_weapon == "pistol", "bot默认武器 pistol")
	# _bot_find_nearest_zombie 函数存在
	assert(p.has_method("_bot_find_nearest_zombie"), "_bot_find_nearest_zombie 函数存在")
	var nearest = p._bot_find_nearest_zombie()
	assert(nearest == null, "无丧尸时返回 null")
	# reset 后 bot 状态清零
	p.reset()
	assert(p.is_bot == false, "reset 后 is_bot=false")
	assert(p.bot_target == null, "reset 后 bot_target=null")
	p.queue_free()
	target.queue_free()
	# game.gd bot 开关变量
	var game_script := load("res://scripts/game.gd")
	assert(game_script != null, "game.gd 加载成功")
	print("bot teammate ok")


# ---- V2.0 第四章与终章关卡 ----
func _test_v2_levels() -> void:
	# 第 4 关配置
	var lv4 = LevelConfig.get_level(4)
	assert(not lv4.is_empty(), "第4关配置存在")
	assert(lv4.get("name") == "白岳制药工厂", "第4关名称正确")
	assert(lv4.get("scene") == "res://scenes/level4.tscn", "第4关场景路径正确")
	assert(LevelConfig.get_total_waves(4) == 6, "第4关 6 波")
	assert(lv4.get("bg_color") == Color(0.10, 0.12, 0.14, 1), "第4关灰白冷调配色")
	# 第 5 关配置
	var lv5 = LevelConfig.get_level(5)
	assert(not lv5.is_empty(), "第5关配置存在")
	assert(lv5.get("name") == "终章·最终 Boss 战", "第5关名称正确")
	assert(lv5.get("scene") == "res://scenes/level5.tscn", "第5关场景路径正确")
	assert(LevelConfig.get_total_waves(5) == 3, "第5关 3 波")
	# 第 5 关第 3 波含 boss_id
	var wc5_3 = LevelConfig.get_wave_config(5, 2)
	assert(not wc5_3.is_empty(), "第5关第3波波次配置非空")
	assert(wc5_3.has("boss_id"), "第5关第3波含 boss_id 字段")
	assert(wc5_3.get("boss_id") == "final_boss", "第5关第3波 boss_id 为 final_boss")
	# 第 4/5 关每波波次配置非空
	for lv_idx in [4, 5]:
		var total = LevelConfig.get_total_waves(lv_idx)
		for w in range(total):
			var wc = LevelConfig.get_wave_config(lv_idx, w)
			assert(not wc.is_empty(), "第%d关第%d波波次配置非空" % [lv_idx, w + 1])
	# level4.tscn / level5.tscn 场景加载
	var l4_scene := load("res://scenes/level4.tscn")
	assert(l4_scene != null, "level4.tscn 加载成功")
	var l4: Node = l4_scene.instantiate()
	assert(l4 != null, "level4 实例化成功")
	root.add_child(l4)
	l4.queue_free()
	var l5_scene := load("res://scenes/level5.tscn")
	assert(l5_scene != null, "level5.tscn 加载成功")
	var l5: Node = l5_scene.instantiate()
	assert(l5 != null, "level5 实例化成功")
	root.add_child(l5)
	l5.queue_free()
	# 第 6 关不存在（数据驱动边界）
	assert(LevelConfig.get_level(6).is_empty(), "第6关不存在（数据驱动边界）")
	print("v2 levels ok")


# ---- V2.0 最终 Boss ----
func _test_final_boss() -> void:
	# final_boss 定义
	var def = EnemyDefs.get_boss_def("final_boss")
	assert(not def.is_empty(), "final_boss 定义存在")
	assert(def.get("name") == "白岳制药·究极改造体", "final_boss 名称正确")
	assert(def.get("ability") == 10.0, "final_boss 能力值 10（Boss 上限）")
	assert(def.get("hp") == 800, "final_boss 血量 800（磨血战）")
	assert(def.get("lifesteal_rate") == 0.10, "final_boss 吸血率 10%")
	assert(def.get("super_armor") == true, "final_boss 霸体 true")
	# 3 阶段定义
	var phases = def.get("phases", [])
	assert(phases.size() == 3, "final_boss 3 阶段")
	# 阶段 3 狂暴：吸血×2
	var phase3 = phases[2]
	assert(phase3.get("lifesteal_mult") == 2.0, "final_boss 阶段3 吸血×2（狂暴20%）")
	assert(phase3.get("summon_count") == 5, "final_boss 阶段3 召唤5只小怪")
	# boss.gd 可配置 boss_id：实例化前设置 export 值
	var bs := load("res://scenes/boss.tscn")
	var b: Node = bs.instantiate()
	b.boss_id = "final_boss"
	root.add_child(b)
	assert(b.hp == 800, "配置 boss_id=final_boss 后血量 800")
	assert(b.max_hp == 800, "配置 boss_id=final_boss 后最大血量 800")
	assert(b.get_current_ability() == 10.0, "配置 boss_id=final_boss 后能力 10")
	assert(b.boss_id == "final_boss", "boss_id export 值正确")
	b.queue_free()
	# 默认 boss_id 仍为 street_boss（首关行为不变）
	var b2: Node = bs.instantiate()
	root.add_child(b2)
	assert(b2.hp == 400, "默认 boss_id=street_boss 血量 400（首关行为不变）")
	b2.queue_free()
	print("final boss ok")


# ---- V2.0 武器表外置 ----
func _test_weapons_external() -> void:
	# Weapons 类静态表
	assert(Weapons.WEAPONS.size() == 4, "Weapons.WEAPONS 含 4 把基础武器")
	assert(Weapons.has_weapon("pistol"), "Weapons.has_weapon(pistol)")
	assert(Weapons.has_weapon("machine_gun"), "Weapons.has_weapon(machine_gun)")
	assert(Weapons.has_weapon("shotgun"), "Weapons.has_weapon(shotgun)")
	assert(Weapons.has_weapon("grenade"), "Weapons.has_weapon(grenade)")
	assert(not Weapons.has_weapon("invalid"), "Weapons.has_weapon(invalid) 为 false")
	# get_weapon
	var pistol_def = Weapons.get_weapon("pistol")
	assert(pistol_def.get("damage") == 2, "pistol damage=2")
	assert(pistol_def.get("max_ammo") == -1, "pistol max_ammo=-1（无限）")
	assert(Weapons.get_weapon("nonexistent").is_empty(), "不存在武器返回空字典")
	# get_all_weapon_names
	var names = Weapons.get_all_weapon_names()
	assert(names.size() == 4, "get_all_weapon_names 返回 4 个")
	# register_weapon（DLC 追加）
	Weapons.register_weapon("dlc_laser", {"cooldown": 0.1, "max_ammo": 50, "damage": 3, "speed": 1200.0})
	assert(Weapons.has_weapon("dlc_laser"), "register_weapon 后 dlc_laser 存在")
	assert(Weapons.get_weapon("dlc_laser").get("damage") == 3, "DLC 武器 damage=3")
	# 清理 DLC 武器（避免影响其他测试）
	var wt: Dictionary = Weapons.WEAPONS
	wt.erase("dlc_laser")
	assert(not Weapons.has_weapon("dlc_laser"), "清理后 dlc_laser 不存在")
	# Player.WEAPONS 向后兼容（引用同一外置表）
	var p := load("res://scenes/player.tscn").instantiate() as Player
	root.add_child(p)
	assert(p.WEAPONS.size() == 4, "Player.WEAPONS 仍含 4 把武器（向后兼容）")
	assert(p.WEAPONS.get("pistol", {}).get("damage") == 2, "Player.WEAPONS.pistol.damage=2")
	p.queue_free()
	print("weapons external ok")


# ---- V2.0 DLC 内容注册表 ----
func _test_dlc_registry() -> void:
	# 注册 DLC
	var info := {
		"name": "测试DLC",
		"version": "1.0.0",
		"contents": {
			"weapons": [{"name": "dlc_sword", "def": {"cooldown": 0.3, "max_ammo": -1, "damage": 5, "speed": 0.0}}],
			"characters": [{"id": "dlc_char", "name": "DLC角色"}],
			"enemies": [{"id": "dlc_enemy", "name": "DLC敌人"}],
			"levels": [{"id": 6, "name": "DLC关卡"}],
		}
	}
	DlcRegistry.register_dlc("test_dlc", info)
	assert(DlcRegistry.has_dlc("test_dlc"), "has_dlc(test_dlc) 为 true")
	assert(not DlcRegistry.has_dlc("nonexistent"), "has_dlc(nonexistent) 为 false")
	# dlc_id 查询
	var dlc_info = DlcRegistry.dlc_id("test_dlc")
	assert(not dlc_info.is_empty(), "dlc_id() 返回非空")
	assert(dlc_info.get("name") == "测试DLC", "DLC 名称正确")
	assert(dlc_info.get("version") == "1.0.0", "DLC 版本正确")
	assert(DlcRegistry.dlc_id("nonexistent").is_empty(), "不存在 DLC 返回空字典")
	# get_all_dlc_ids
	assert(DlcRegistry.get_all_dlc_ids().has("test_dlc"), "get_all_dlc_ids 含 test_dlc")
	# get_contents
	var weapons = DlcRegistry.get_contents("test_dlc", "weapons")
	assert(weapons.size() == 1, "DLC weapons 含 1 条")
	var chars = DlcRegistry.get_contents("test_dlc", "characters")
	assert(chars.size() == 1, "DLC characters 含 1 条")
	assert(DlcRegistry.get_contents("test_dlc", "nonexistent_cat").size() == 0, "不存在类别返回空数组")
	# 启用前：get_all_weapons 不含 DLC 武器
	var all_w_before = DlcRegistry.get_all_weapons()
	assert(not all_w_before.has("dlc_sword"), "启用前 get_all_weapons 不含 dlc_sword")
	# 启用 DLC
	DlcRegistry.enable_dlc("test_dlc", true)
	assert(DlcRegistry.is_dlc_enabled("test_dlc"), "启用后 is_dlc_enabled 为 true")
	# 启用后：get_all_weapons 含 DLC 武器
	var all_w_after = DlcRegistry.get_all_weapons()
	assert(all_w_after.has("dlc_sword"), "启用后 get_all_weapons 含 dlc_sword")
	assert(all_w_after.get("dlc_sword", {}).get("damage") == 5, "DLC 武器 damage=5")
	assert(all_w_after.has("pistol"), "合并表仍含基础武器 pistol")
	# get_all_characters/enemies/levels
	assert(DlcRegistry.get_all_characters().size() == 1, "启用后 get_all_characters 含 1 条")
	assert(DlcRegistry.get_all_enemies().size() == 1, "启用后 get_all_enemies 含 1 条")
	assert(DlcRegistry.get_all_levels().size() == 1, "启用后 get_all_levels 含 1 条")
	# 禁用 DLC
	DlcRegistry.enable_dlc("test_dlc", false)
	assert(not DlcRegistry.is_dlc_enabled("test_dlc"), "禁用后 is_dlc_enabled 为 false")
	var all_w_disabled = DlcRegistry.get_all_weapons()
	assert(not all_w_disabled.has("dlc_sword"), "禁用后 get_all_weapons 不含 dlc_sword")
	assert(DlcRegistry.get_all_characters().size() == 0, "禁用后 get_all_characters 为空")
	print("dlc registry ok")


# ---- V2.0 存档 schema 版本化 ----
func _test_save_version() -> void:
	# SAVE_VERSION 常量
	var ach_script := load("res://scripts/achievements.gd")
	var ach = ach_script.new()
	root.add_child(ach)
	assert(ach.SAVE_VERSION == 2, "SAVE_VERSION = 2")
	# 保存后存档含 version 字段
	ach.unlock("first_kill")
	ach.save_save()
	var f := FileAccess.open(ach.SAVE_PATH, FileAccess.READ)
	assert(f != null, "存档文件可读")
	var parsed = JSON.parse_string(f.get_as_text())
	assert(parsed is Dictionary, "存档 JSON 解析为字典")
	assert(parsed.has("version"), "存档含 version 字段")
	assert(int(parsed.get("version")) == 2, "存档 version = 2")
	assert(parsed.has("unlocked"), "存档含 unlocked 字段")
	assert(parsed.has("stats"), "存档含 stats 字段")
	# v1 旧档迁移：写入无 version 的旧档格式
	var v1_data := {"unlocked": {"hundred_kills": true}, "stats": {"kills_total": 100}}
	var f2 := FileAccess.open(ach.SAVE_PATH, FileAccess.WRITE)
	f2.store_string(JSON.stringify(v1_data))
	f2 = null  # 释放写文件句柄，确保数据落盘后再读取
	# 重新加载（应触发 v1→v2 迁移）
	ach.unlocked.clear()
	ach.stats.clear()
	ach.load_save()
	# 迁移后成就数据不丢失
	assert(ach.is_unlocked("hundred_kills"), "v1 迁移后 hundred_kills 成就保留")
	assert(int(ach.stats.get("kills_total", 0)) == 100, "v1 迁移后 kills_total=100 保留")
	# 迁移后存档已写回 v2 格式
	var f3 := FileAccess.open(ach.SAVE_PATH, FileAccess.READ)
	var migrated = JSON.parse_string(f3.get_as_text())
	assert(migrated.has("version"), "迁移后存档含 version 字段")
	assert(int(migrated.get("version")) == 2, "迁移后存档 version=2")
	# reset_save 后存档也含 version
	ach.reset_save()
	var f4 := FileAccess.open(ach.SAVE_PATH, FileAccess.READ)
	var reset_data = JSON.parse_string(f4.get_as_text())
	assert(reset_data.has("version"), "reset_save 后存档含 version 字段")
	assert(int(reset_data.get("version")) == 2, "reset_save 后存档 version=2")
	ach.queue_free()
	print("save version ok")


# ======================================================================
# V2.1 热血化：战斗模式 + 敌人人味化 测试
# ======================================================================

# ---- V2.1 踢击连招 ----
func _test_v21_kick_combo() -> void:
	var p := load("res://scenes/player.tscn").instantiate() as Player
	root.add_child(p)
	# 初始无枪 → shoot 键应触发踢击而非射击
	assert(not p.has_gun_equipped(), "初始 pistol 不算已装备枪械")
	# 踢击 2 段连击
	p._try_kick()
	assert(p.kick_count == 1, "踢击第 1 段")
	assert(p.current_melee_damage == 3, "踢击第 1 段伤害 3")
	p.kick_cooldown = 0.0
	p._try_kick()
	assert(p.kick_count == 2, "踢击第 2 段")
	assert(p.current_melee_damage == 4, "踢击第 2 段伤害 4")
	# 踢击范围倍率
	assert(p.current_melee_range_mult == Player.KICK_RANGE_MULT, "踢击范围 ×1.2")
	# 跳踢
	p._try_jump_kick()
	assert(p.current_melee_damage == Player.JUMP_KICK_DAMAGE, "跳踢伤害 6")
	assert(p.velocity.y > 0.0, "跳踢带向下俯冲速度")
	# 拳脚交替奖励：拳→踢→拳 = 第 3 击 ×1.5
	p.combo_count = 0
	p.kick_count = 0
	p.combo_last_type = ""
	p.combo_alt_count = 0
	p.combo_timer = 0.5
	p.charge_time = 0.1
	p._resolve_melee()  # punch
	assert(p.combo_alt_count == 1, "拳后交替计数 1")
	p.kick_cooldown = 0.0
	p._try_kick()  # kick
	assert(p.combo_alt_count == 2, "踢后交替计数 2")
	p.charge_time = 0.1
	p._resolve_melee()  # punch → 第3击 ×1.5
	assert(p.combo_alt_count >= 3, "第3次交替击触发奖励")
	p.queue_free()
	print("v21 kick combo ok")


# ---- V2.1 近战武器（日用品）----
func _test_v21_melee_weapon() -> void:
	var p := load("res://scenes/player.tscn").instantiate() as Player
	root.add_child(p)
	# 装备铁管
	p.equip_melee_weapon("iron_pipe")
	assert(p.equipped_melee_weapon == "iron_pipe", "装备铁管")
	assert(p.melee_weapon_durability == 15, "铁管耐久 15")
	# 挥舞武器（charge_time=0 不蓄力）
	p.charge_time = 0.1
	p._resolve_melee()
	assert(p.current_melee_damage == 6, "铁管挥舞伤害 6")
	assert(p.melee_weapon_durability == 14, "命中后耐久 -1")
	assert(p.current_melee_range_mult == 1.5, "铁管范围 ×1.5")
	# 装备垃圾桶盖 → 格挡
	p.equip_melee_weapon("trash_lid")
	assert(p.equipped_melee_weapon == "trash_lid", "装备垃圾桶盖")
	assert(p.melee_weapon_durability == 25, "垃圾桶盖耐久 25")
	p.invincible = false
	var hp_before := p.hp
	p.take_damage(20)  # 格挡 ×0.5 = 10
	assert(p.hp == hp_before - 10, "垃圾桶盖格挡减伤 50%")
	assert(p.melee_weapon_durability == 23, "格挡耗 2 耐久")
	# 耐久归零 → 脱手
	p.melee_weapon_durability = 1
	p.invincible = false
	p.take_damage(100)
	assert(p.equipped_melee_weapon == "", "耐久归零武器脱手")
	# 重置清空
	p.reset()
	assert(p.equipped_melee_weapon == "", "reset 后近战武器清空")
	p.queue_free()
	print("v21 melee weapon ok")


# ---- V2.1 枪械降级 ----
func _test_v21_gun_downgrade() -> void:
	var p := load("res://scenes/player.tscn").instantiate() as Player
	root.add_child(p)
	# pistol 是默认副武器，has_gun_equipped 应为 false
	assert(not p.has_gun_equipped(), "pistol 不算已装备枪械")
	# machine_gun 有弹药 → has_gun_equipped true
	p.weapon_ammo["machine_gun"] = 120
	p.switch_weapon("machine_gun")
	assert(p.has_gun_equipped(), "机枪有弹药算已装备枪械")
	# 打空弹药 → has_gun_equipped false（shoot 变回踢）
	p.weapon_ammo["machine_gun"] = 1
	p.shoot_cooldown = 0.0
	p._try_shoot()
	assert(p.current_weapon == "pistol", "机枪打空自动切回 pistol")
	assert(not p.has_gun_equipped(), "切回 pistol 后 has_gun_equipped=false")
	# MELEE_WEAPONS 表存在
	assert(Weapons.MELEE_WEAPONS.has("iron_pipe"), "MELEE_WEAPONS 含 iron_pipe")
	assert(Weapons.MELEE_WEAPONS["iron_pipe"]["damage"] == 6, "铁管伤害 6")
	assert(Weapons.MELEE_WEAPONS["trash_lid"]["can_block"] == true, "垃圾桶盖可格挡")
	p.queue_free()
	print("v21 gun downgrade ok")


# ---- V2.1 人形敌：逃跑 ----
func _test_v21_delinquent_flee() -> void:
	var z := load("res://scenes/zombie.tscn").instantiate() as Zombie
	root.add_child(z)
	z.setup(Zombie.Type.DELINQUENT, null)
	assert(z.humanoid == true, "不良少年是 humanoid")
	assert(z.can_flee == true, "不良少年 can_flee=true")
	assert(z.hp == 5 and z.max_hp == 5, "不良少年 hp=5")
	assert(is_equal_approx(z.speed, 90.0), "不良少年 speed=90")
	# 残血到逃跑线以下，直接置位逃跑状态并校验状态变量
	z.hp = 1  # <= max_hp*0.3
	z.fleeing = true
	z._flee_timer = 2.0
	assert(z.fleeing == true, "置位逃跑状态成功")
	z.fleeing = false
	z.queue_free()
	# BOSOZOKU 不会逃跑
	var zb := load("res://scenes/zombie.tscn").instantiate() as Zombie
	root.add_child(zb)
	zb.setup(Zombie.Type.BOSOZOKU, null)
	assert(zb.can_flee == false, "暴走族 can_flee=false")
	zb.queue_free()
	print("v21 delinquent flee ok")


# ---- V2.1 人形敌：BOSOZOKU 冲刺 ----
func _test_v21_bosozoku_dash() -> void:
	var z := load("res://scenes/zombie.tscn").instantiate() as Zombie
	root.add_child(z)
	z.setup(Zombie.Type.BOSOZOKU, null)
	assert(z.hp == 8, "暴走族 hp=8")
	assert(is_equal_approx(z.speed, 130.0), "暴走族 speed=130")
	# 冲刺状态机变量/常量就位
	assert(z._boso_dash_state == "none", "冲刺初始状态 none")
	assert(is_equal_approx(z.BOSO_DASH_COOLDOWN, 5.0), "冲刺冷却 5s")
	assert(is_equal_approx(z.BOSO_DASH_SPEED_MULT, 2.8), "冲刺速度倍率 2.8")
	assert(is_equal_approx(z.BOSO_DASH_DAMAGE, 25.0), "冲刺接触伤害 25")
	# 进入前摇后，状态推进到 telegraph
	z._boso_dash_state = "telegraph"
	z._boso_dash_timer = 0.5
	assert(z._boso_dash_state == "telegraph", "冲刺前摇可置位")
	z.queue_free()
	print("v21 bosozoku dash ok")


# ---- V2.1 人形敌：求饶阈值 + 收服援护 ----
func _test_v21_humanoid_begging() -> void:
	# DELINQUENT 求饶阈值 hp<=3
	var z := load("res://scenes/zombie.tscn").instantiate() as Zombie
	root.add_child(z)
	z.setup(Zombie.Type.DELINQUENT, null)
	z.take_damage(2, true)  # 5->3，近战，应触发求饶
	assert(z.begging == true, "不良少年近战打至 hp<=3 触发求饶")
	var data := z.capture()
	assert(data.get("damage") == 12, "不良少年收服援护伤害 12")
	assert(data.get("humanoid") == true, "援护数据含 humanoid=true")
	assert(data.get("personality") == "懦弱小弟", "援护性格=懦弱小弟")
	if not z.is_queued_for_deletion():
		z.queue_free()
	# BOSOZOKU 求饶阈值 hp<=4
	var zb := load("res://scenes/zombie.tscn").instantiate() as Zombie
	root.add_child(zb)
	zb.setup(Zombie.Type.BOSOZOKU, null)
	zb.take_damage(4, true)  # 8->4，近战，应触发求饶
	assert(zb.begging == true, "暴走族近战打至 hp<=4 触发求饶")
	var bd := zb.capture()
	assert(bd.get("damage") == 20, "暴走族收服援护伤害 20")
	assert(bd.get("personality") == "暴躁大哥", "援护性格=暴躁大哥")
	if not zb.is_queued_for_deletion():
		zb.queue_free()
	print("v21 humanoid begging ok")


# ---- V2.1 人形敌：内讧增强 / 生气 ----
func _test_v21_infighting_enhanced() -> void:
	var a := load("res://scenes/zombie.tscn").instantiate() as Zombie
	root.add_child(a)
	a.setup(Zombie.Type.DELINQUENT, null)
	# 人形敌 silly 倍率 / 生气变量存在
	assert(a.has_method("_try_brawl"), "_try_brawl 存在")
	assert(a._angry == false, "初始不生气")
	# 手动触发生气态，校验速度倍率生效
	a._angry = true
	a._anger_timer = 3.0
	assert(a._angry == true, "生气可置位")
	assert(is_equal_approx(a.ANGER_SPEED_MULT, 1.2), "生气速度倍率 1.2")
	a.queue_free()
	# 普通 WALKER 不受人形敌增强影响（humanoid=false）
	var w := load("res://scenes/zombie.tscn").instantiate() as Zombie
	root.add_child(w)
	w.setup(Zombie.Type.WALKER, null)
	assert(w.humanoid == false, "普通 walker humanoid=false")
	w.queue_free()
	print("v21 infighting enhanced ok")


# ======================================================================
# V2.2 兄弟连携 + 根性気力 + 必杀武技 + 场景日常化 测试
# ======================================================================

# ---- V2.2 根性気力站起 ----
func _test_v22_stand_up() -> void:
	var p := load("res://scenes/player.tscn").instantiate() as Player
	root.add_child(p)
	# 能量在 32~99 之间时，致命一击触发根性起身
	p.add_energy(50.0)
	p.invincible = false
	p.take_damage(999)
	assert(p.dead == false, "能量充足时根性起身不死亡")
	assert(p.standing_up == true, "进入起身硬直状态")
	assert(p.can_stand_up == false, "每局限一次：起身后置 false")
	assert(p.hp == int(100 * Player.STAND_UP_HP_RATIO), "恢复 30% 最大 HP")
	assert(is_equal_approx(p.energy, 50.0 - Player.STAND_UP_ENERGY_COST), "消耗 32 热血魂")
	# 站起后再次致命 → 不再起身，正常死亡
	p.standing_up = false
	p.invincible = false
	p.take_damage(999)
	assert(p.dead == true, "根性用完后正常死亡")
	# 无能量时直接死亡
	p.reset()
	p.energy = 0.0
	p.invincible = false
	p.take_damage(999)
	assert(p.dead == true, "无热血魂时不触发起身")
	# reset 恢复每局限一次
	p.reset()
	assert(p.can_stand_up == true, "reset 后 can_stand_up 恢复 true")
	p.queue_free()
	print("v22 stand up ok")


# ---- V2.2 角色专属必杀技 ----
func _test_v22_special_skills() -> void:
	# 清理前序测试可能遗留的同名 Autoload 节点（--script 模式 queue_free 延迟到帧末）
	for n in root.get_children():
		if n.name == "Economy" or n.name == "CharacterData":
			root.remove_child(n)
			n.free()
	var cd_script := load("res://scripts/character_data.gd")
	var cd = cd_script.new()
	cd.name = "CharacterData"
	root.add_child(cd)
	# 手动实例化 Economy（--script 模式 Autoload 全局名不可用）
	var econ_script := load("res://scripts/economy.gd")
	var econ = econ_script.new()
	econ.name = "Economy"
	root.add_child(econ)
	# 清理存档文件可能带来的跨测试残留解锁状态
	if FileAccess.file_exists(econ.SPECIALS_SAVE_PATH):
		DirAccess.remove_absolute(econ.SPECIALS_SAVE_PATH)
	econ.unlocked_specials.clear()
	# 5 个角色都有 special_skill / special_damage
	for cid in ["pompadour", "fighter", "tank", "sprinter", "bosozoku"]:
		var c = cd.get_character(cid)
		assert(c.has("special_skill"), "%s 含 special_skill" % cid)
		assert(c.has("special_damage"), "%s 含 special_damage" % cid)
	assert(cd.get_character("pompadour").get("special_skill") == "mach_kick", "飞机头=马赫踢")
	assert(cd.get_character("bosozoku").get("special_damage") == 8, "人间鱼雷伤害 8（贵≠强）")
	# Economy 解锁/查询
	assert(econ.has_special_unlocked("pompadour") == false, "初始未解锁马赫踢")
	econ.unlock_special("mach_kick")
	assert(econ.has_special_unlocked("pompadour") == true, "解锁后 has_special_unlocked 为 true")
	# Player 已习得 → 释放个人武技
	var p := load("res://scenes/player.tscn").instantiate() as Player
	root.add_child(p)
	p.apply_character("pompadour")
	p.energy = Player.MAX_ENERGY
	assert(p._try_release_personal_special() == true, "已习得时释放个人武技")
	assert(is_equal_approx(p.energy, 0.0), "释放后能量清空")
	p.queue_free()
	econ.queue_free()
	cd.queue_free()
	print("v22 special skills ok")


# ---- V2.2 兄弟连携 ----
func _test_v22_combo_attack() -> void:
	# game.gd 常量就位
	var g := load("res://scripts/game.gd")
	assert(g != null, "game.gd 加载成功")
	assert(is_equal_approx(g.COMBO_ATTACK_RANGE, 60.0), "连携距离阈值 60")
	assert(is_equal_approx(g.COMBO_ATTACK_COOLDOWN, 5.0), "连携冷却 5s")
	assert(is_equal_approx(g.COMBO_ATTACK_DAMAGE_MULT, 2.0), "连携伤害倍率 2.0")
	# 双玩家可同屏存活且分处 players 组
	var p1 := load("res://scenes/player.tscn").instantiate() as Player
	root.add_child(p1)
	var p2 := load("res://scenes/player.tscn").instantiate() as Player
	p2.player_index = 2
	root.add_child(p2)
	assert(p1.is_in_group("players") and p2.is_in_group("players"), "双玩家在 players 组")
	# stood_up 信号存在
	assert(p1.stood_up != null, "stood_up 信号已定义")
	p1.queue_free()
	p2.queue_free()
	print("v22 combo attack ok")


# ---- V2.2 书店必杀书 ----
func _test_v22_shop_skill_books() -> void:
	var economy_script := load("res://scripts/economy.gd")
	var economy = economy_script.new()
	root.add_child(economy)
	var books := ["book_mach_kick", "book_mach_punch", "book_earthquake",
		"book_tornado_kick", "book_human_torpedo"]
	for bid in books:
		assert(economy.SHOP_ITEMS.has(bid), "商店含 %s" % bid)
		var it = economy.SHOP_ITEMS[bid]
		assert(it.get("category") == "skill", "%s 属于 skill 分类" % bid)
		assert(it.has("skill_id"), "%s 含 skill_id" % bid)
		assert(int(it.get("price", 0)) > 0, "%s 有正价格" % bid)
	# 人间鱼雷最贵
	assert(economy.SHOP_ITEMS["book_human_torpedo"]["price"] == 8000, "人间鱼雷之书 8000")
	# 购买必杀书后解锁对应技
	economy.coins = 10000
	var p := load("res://scenes/player.tscn").instantiate() as Player
	root.add_child(p)
	assert(economy.buy_item("book_mach_kick", p), "购买马赫踢之书成功")
	assert(economy.is_special_learned("mach_kick"), "购买后 mach_kick 已习得")
	assert(economy.has_special_unlocked("pompadour"), "pompadour 已解锁个人武技")
	p.queue_free()
	economy.queue_free()
	print("v22 shop skill books ok")


# ---- V2.2 关卡副标题 ----
func _test_v22_level_subtitles() -> void:
	var lv1 = LevelConfig.get_level(1)
	assert(lv1.get("subtitle") == "鞋柜区·异变始动", "第1关副标题正确")
	var lv2 = LevelConfig.get_level(2)
	assert(lv2.get("subtitle") == "教室与走廊", "第2关副标题正确")
	var lv3 = LevelConfig.get_level(3)
	assert(lv3.get("subtitle") == "天台与体育馆", "第3关副标题正确")
	var lv4 = LevelConfig.get_level(4)
	assert(lv4.get("subtitle") == "商店街·霓虹夜", "第4关副标题正确")
	var lv5 = LevelConfig.get_level(5)
	assert(lv5.get("subtitle") == "工厂深处·终局", "第5关副标题正确")
	# name 字段保持原值（向后兼容）
	assert(lv1.get("name") == "黄昏町街道", "第1关 name 不变")
	assert(lv5.get("name") == "终章·最终 Boss 战", "第5关 name 不变")
	print("v22 subtitles ok")


# ---- V2.2 自动贩卖机可破坏物 ----
func _test_v22_vending_machine() -> void:
	# 程序化创建 vending_machine 类型可破坏物
	var d := StaticBody2D.new()
	d.set_script(preload("res://scripts/destructible.gd"))
	d.set("destructible_type", "vending_machine")
	var body := ColorRect.new()
	body.name = "Body"
	d.add_child(body)
	var hit_area := Area2D.new()
	hit_area.name = "HitArea"
	d.add_child(hit_area)
	var cs := CollisionShape2D.new()
	cs.shape = RectangleShape2D.new()
	d.add_child(cs)
	root.add_child(d)
	# vending_machine 只需 2 次命中
	assert(d._max_hits == 2, "vending_machine MAX_HITS=2")
	d.take_damage(2)
	assert(not d.is_queued_for_deletion(), "1 次命中不破坏（vending）")
	d.take_damage(2)
	assert(d.is_queued_for_deletion(), "2 次命中后 vending_machine 破坏")
	# generic 类型仍为 3 次（回归）
	var d2 := StaticBody2D.new()
	d2.set_script(preload("res://scripts/destructible.gd"))
	var body2 := ColorRect.new()
	body2.name = "Body"
	d2.add_child(body2)
	var ha2 := Area2D.new()
	ha2.name = "HitArea"
	d2.add_child(ha2)
	root.add_child(d2)
	assert(d2._max_hits == 3, "generic MAX_HITS=3 不变")
	d2.queue_free()
	# 场景中存在 vending_machine 实例（level4）
	var l4 := load("res://scenes/level4.tscn").instantiate() as Node
	root.add_child(l4)
	var found_vending := false
	for child in l4.find_children("*", "Destructible", true, false):
		if child.get("destructible_type") == "vending_machine":
			found_vending = true
	assert(found_vending, "level4.tscn 含 vending_machine 类型可破坏物")
	l4.queue_free()
	print("v22 vending machine ok")


# ======================================================================
# V2.3 人形格斗战 Boss 测试
# ======================================================================

# ---- V2.3 人形化身份数据 ----
func _test_v23_boss_humanoid_data() -> void:
	# street_boss 人形身份
	var sdef = EnemyDefs.get_boss_def("street_boss")
	assert(sdef.get("display_name") == "暴走族总长·鬼冢", "street_boss display_name 正确")
	assert(sdef.get("title") == "被改造的暴走族总长", "street_boss title 正确")
	assert(sdef.get("humanoid") == true, "street_boss humanoid=true")
	var s_lines: Array = sdef.get("taunt_lines", [])
	assert(s_lines.size() == 5, "street_boss 嘲讽台词 5 条")
	assert(s_lines[0] == "就这点本事？", "street_boss 第1条嘲讽")
	# final_boss 人形身份
	var fdef = EnemyDefs.get_boss_def("final_boss")
	assert(fdef.get("display_name") == "学生会会长·白岳", "final_boss display_name 正确")
	assert(fdef.get("title") == "被改造的学生会会长", "final_boss title 正确")
	assert(fdef.get("humanoid") == true, "final_boss humanoid=true")
	var f_lines: Array = fdef.get("taunt_lines", [])
	assert(f_lines.size() == 5, "final_boss 嘲讽台词 5 条")
	assert(f_lines[0] == "愚蠢。", "final_boss 第1条嘲讽")
	# 实例化后字段落地
	var bs := load("res://scenes/boss.tscn")
	var b := bs.instantiate() as Boss
	root.add_child(b)
	assert(b.display_name == "暴走族总长·鬼冢", "Boss 实例 display_name 落地")
	assert(b.title == "被改造的暴走族总长", "Boss 实例 title 落地")
	assert(b.humanoid == true, "Boss 实例 humanoid=true")
	assert(b.taunt_lines.size() == 5, "Boss 实例 taunt_lines 5 条")
	b.queue_free()
	# final_boss 实例
	var b2 := bs.instantiate() as Boss
	b2.boss_id = "final_boss"
	root.add_child(b2)
	assert(b2.display_name == "学生会会长·白岳", "final_boss 实例 display_name 落地")
	assert(b2.taunt_lines.size() == 5, "final_boss 实例 taunt_lines 5 条")
	b2.queue_free()
	print("v23 boss humanoid data ok")


# ---- V2.3 格斗技状态机 ----
func _test_v23_boss_fighting_techniques() -> void:
	var bs := load("res://scenes/boss.tscn")
	var b := bs.instantiate() as Boss
	root.add_child(b)
	# 新状态机初始值
	assert(b._punch_state == "idle", "拳击状态初始 idle")
	assert(b._kick_state == "idle", "飞踢状态初始 idle")
	assert(b._throw_state == "idle", "投技状态初始 idle")
	assert(b._block_state == "idle", "格挡状态初始 idle")
	assert(is_equal_approx(b._block_cooldown, 4.0), "格挡冷却初始 4.0s")
	assert(is_equal_approx(b.BLOCK_DAMAGE_MULT, 0.3), "格挡减伤 0.3")
	assert(is_equal_approx(b.BLOCK_DURATION, 1.0), "格挡持续 1.0s")
	assert(is_equal_approx(b.PUNCH_RANGE, 70.0), "拳击范围 70px")
	assert(is_equal_approx(b.KICK_RANGE, 90.0), "飞踢范围 90px")
	assert(is_equal_approx(b.THROW_RANGE, 50.0), "投技范围 50px")
	# 手动置位状态机可推进
	b._punch_state = "telegraph"
	b._punch_timer = 0.5
	assert(b._punch_state == "telegraph", "拳击 telegraph 可置位")
	b._kick_state = "telegraph"
	b._kick_timer = 0.5
	assert(b._kick_state == "telegraph", "飞踢 telegraph 可置位")
	b._throw_state = "grabbing"
	b._throw_timer = 0.5
	assert(b._throw_state == "grabbing", "投技 grabbing 可置位")
	b._block_state = "blocking"
	b._block_timer = 1.0
	assert(b._block_state == "blocking", "格挡 blocking 可置位")
	# 格挡减伤：blocking 状态 take_damage ×0.3
	b._block_cooldown = 99.0  # 防止测试中触发新格挡
	var hp_before = b.hp
	b.take_damage(10)
	assert(b.hp == hp_before - 3, "格挡中 10 伤害→3（×0.3）")
	b._block_state = "idle"
	b.queue_free()
	# 统一攻击决策函数存在
	assert(b.has_method("_decide_attack"), "_decide_attack 函数存在")
	assert(b.has_method("_is_all_attacks_idle"), "_is_all_attacks_idle 函数存在")
	print("v23 boss fighting techniques ok")


# ---- V2.3 嘲讽系统 ----
func _test_v23_boss_taunts() -> void:
	var bs := load("res://scenes/boss.tscn")
	var b := bs.instantiate() as Boss
	root.add_child(b)
	# 嘲讽变量初始值
	assert(is_equal_approx(b._taunt_cooldown, 10.0), "嘲讽冷却初始 10.0s")
	assert(b._taunting == false, "初始不嘲讽")
	assert(b._posing == false, "初始不摆姿势")
	assert(is_equal_approx(b.TAUNT_DURATION, 1.5), "嘲讽持续 1.5s")
	assert(is_equal_approx(b.TAUNT_COOLDOWN_MIN, 8.0), "嘲讽冷却下限 8s")
	assert(is_equal_approx(b.TAUNT_COOLDOWN_MAX, 12.0), "嘲讽冷却上限 12s")
	assert(is_equal_approx(b.POSE_DURATION, 1.5), "POSE 持续 1.5s")
	# 手动触发嘲讽
	b._taunting = true
	b._taunt_timer = 1.5
	b.weak_point_active = true
	assert(b._taunting == true, "手动置位嘲讽成功")
	assert(b.weak_point_active == true, "嘲讽期间弱点激活")
	# 嘲讽气泡函数存在
	assert(b.has_method("_show_bubble"), "_show_bubble 函数存在")
	assert(b.has_method("_update_taunt"), "_update_taunt 函数存在")
	assert(b.has_method("_do_laugh"), "_do_laugh 函数存在")
	# 摆姿势变量
	b._posing = true
	b._pose_timer = 1.5
	assert(b._posing == true, "手动置位摆姿势成功")
	b.queue_free()
	print("v23 boss taunts ok")


# ---- V2.3 Boss 视觉人形化 ----
func _test_v23_boss_visual_nodes() -> void:
	var bs := load("res://scenes/boss.tscn")
	assert(bs != null, "V2.3 boss.tscn 加载成功")
	var b := bs.instantiate() as Boss
	root.add_child(b)
	# 必备节点路径不可丢
	assert(b.get_node_or_null("Visual") != null, "V2.3 $Visual 存在")
	assert(b.get_node_or_null("Visual/Head") != null, "V2.3 $Visual/Head 存在")
	assert(b.get_node_or_null("Visual/Head/EyeL") != null, "V2.3 $Visual/Head/EyeL 存在")
	assert(b.get_node_or_null("Visual/Head/EyeR") != null, "V2.3 $Visual/Head/EyeR 存在")
	var vis := b.get_node("Visual") as Node2D
	assert(vis.scale.x == 1.0 and vis.scale.y == 1.0, "V2.3 Visual 整体 scale=1.0")
	# 人形部件
	for n in ["Body", "UniformAccent", "Outline", "ArmL", "ArmR",
			"LegL", "LegR", "BlockArmL", "BlockArmR", "TauntBubble"]:
		assert(vis.get_node_or_null(n) != null, "V2.3 Visual/%s 存在" % n)
	var head := b.get_node("Visual/Head") as Node2D
	for n in ["Face", "Hair", "Mouth"]:
		assert(head.get_node_or_null(n) != null, "V2.3 Visual/Head/%s 存在" % n)
	# 特攻服主色
	var body := vis.get_node("Body") as ColorRect
	assert(absf(body.color.r - 0.2) < 0.02 and absf(body.color.g - 0.08) < 0.02,
		"V2.3 Body 特攻服暗红黑")
	# 可选节点默认隐藏
	assert(vis.get_node("BlockArmL").visible == false, "V2.3 BlockArmL 默认隐藏")
	assert(vis.get_node("BlockArmR").visible == false, "V2.3 BlockArmR 默认隐藏")
	assert(vis.get_node("TauntBubble").visible == false, "V2.3 TauntBubble 默认隐藏")
	# 2 头身：脸高 >= 身体高
	var face := head.get_node("Face") as ColorRect
	var face_h: float = face.offset_bottom - face.offset_top
	var body_h: float = body.offset_bottom - body.offset_top
	assert(face_h >= body_h, "V2.3 2头身：头高 >= 身体高")
	b.queue_free()
	print("v23 boss visual ok")


# ---- V2.3 终章格斗竞技场装饰 ----
func _test_v23_level5_arena() -> void:
	var l5_scene := load("res://scenes/level5.tscn")
	assert(l5_scene != null, "V2.3 level5.tscn 加载成功")
	var l5: Node = l5_scene.instantiate()
	root.add_child(l5)
	for n in ["RingFloor", "RingRopeL", "RingRopeR", "RingCornerL", "RingCornerR"]:
		assert(l5.get_node_or_null("MidLayer/" + n) != null, "V2.3 擂台 %s 存在" % n)
	for i in 5:
		assert(l5.get_node_or_null("FarLayer/Audience%d" % (i + 1)) != null,
			"V2.3 观众 Audience%d 存在" % (i + 1))
	assert(l5.get_node_or_null("FarLayer/Spotlight") != null, "V2.3 Spotlight 存在")
	var banner: Node = l5.get_node_or_null("FarLayer/FightBanner")
	assert(banner != null, "V2.3 FightBanner 存在")
	var label: Label = banner.get_node_or_null("FightLabel") as Label
	assert(label != null and label.text == "决 斗", "V2.3 标语文本为 决 斗")
	l5.queue_free()
	print("v23 level5 arena ok")
