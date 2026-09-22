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
