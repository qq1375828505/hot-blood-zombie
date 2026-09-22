extends CanvasLayer
# HUD V1.0 真实 UI 视觉：顶部信息带 / 左上头像生命条 / 热血魂槽 / 左下弹药手雷 / 结算面板

@onready var top_bar: HBoxContainer = $Top
@onready var wave_label: Label = $Top/WaveLabel
@onready var score_label: Label = $Top/ScoreLabel
@onready var kills_label: Label = $Top/KillsLabel
@onready var time_label: Label = $Top/TimeLabel
@onready var coins_label: Label = $Top/CoinsLabel

@onready var avatar_hp: Control = $AvatarHP
@onready var avatar_tex: TextureRect = $AvatarHP/AvatarTex
@onready var crack_rect: ColorRect = $AvatarHP/AvatarTex/CrackRect
@onready var hp_blocks: HBoxContainer = $AvatarHP/HPBlocks

@onready var energy_slot: Control = $EnergySlot
@onready var seg1: ColorRect = $EnergySlot/Seg1
@onready var seg2: ColorRect = $EnergySlot/Seg2
@onready var seg3: ColorRect = $EnergySlot/Seg3

@onready var ammo_grenade: Control = $AmmoGrenade
@onready var weapon_name: Label = $AmmoGrenade/WeaponName
@onready var ammo_label: Label = $AmmoGrenade/AmmoLabel
@onready var grenade_label: Label = $AmmoGrenade/GrenadeLabel

@onready var buff_bar: HBoxContainer = $BuffBar

@onready var game_over: PanelContainer = $GameOver
@onready var final_score: Label = $GameOver/Margin/FinalScore

# ---- V1.1 P2 HUD 节点（镜像到右侧）----
@onready var avatar_hp2: Control = $AvatarHP2
@onready var avatar_tex2: TextureRect = $AvatarHP2/AvatarTex2
@onready var crack_rect2: ColorRect = $AvatarHP2/AvatarTex2/CrackRect2
@onready var hp_blocks2: HBoxContainer = $AvatarHP2/HPBlocks2

@onready var energy_slot2: Control = $EnergySlot2
@onready var seg1_2: ColorRect = $EnergySlot2/Seg1_2
@onready var seg2_2: ColorRect = $EnergySlot2/Seg2_2
@onready var seg3_2: ColorRect = $EnergySlot2/Seg3_2

@onready var ammo_grenade2: Control = $AmmoGrenade2
@onready var weapon_name2: Label = $AmmoGrenade2/WeaponName2
@onready var ammo_label2: Label = $AmmoGrenade2/AmmoLabel2
@onready var grenade_label2: Label = $AmmoGrenade2/GrenadeLabel2

# ---- V1.1 半尸化状态指示 ----
@onready var hz_border: ColorRect = $AvatarHP/HalfZombieBorder
@onready var hz_label: Label = $AvatarHP/HalfZombieLabel
@onready var hz_border2: ColorRect = $AvatarHP2/HalfZombieBorder2
@onready var hz_label2: Label = $AvatarHP2/HalfZombieLabel2

# ---- V1.3 Boss 血条（新增节点，不影响 V1.0-V1.2 已有节点）----
@onready var boss_bar: Control = $BossHealthBar
@onready var boss_bg: ColorRect = $BossHealthBar/BossBg
@onready var boss_fill: ColorRect = $BossHealthBar/BossFill
@onready var boss_name_label: Label = $BossHealthBar/BossNameLabel
@onready var boss_phase_label: Label = $BossHealthBar/BossPhaseLabel

const HP_BLOCK_COUNT := 10
const ENERGY_W := 160.0
const SEG_W := ENERGY_W / 3.0
const BUFF_ICON_SIZE := 36.0

# buff 名称 → 色块颜色映射（卡通硬边纯色块）
const BUFF_COLORS := {
	"sports_drink": Color(0.3, 0.6, 0.95, 1),   # 运动饮料/移速 → 蓝
	"chili_rice": Color(0.9, 0.25, 0.2, 1),     # 辣椒饭团/攻击 → 红
	"iron_pipe": Color(0.55, 0.55, 0.55, 1),    # 铁管/近战范围 → 灰
	"armor_vest": Color(0.3, 0.75, 0.35, 1),     # 护甲背心/减伤 → 绿
}

var _hp_rects: Array[ColorRect] = []
var _energy_tween: Tween = null
var _hp_rects2: Array[ColorRect] = []
var _energy_tween2: Tween = null
var _hz_tween: Tween = null
var _hz_tween2: Tween = null

func _ready() -> void:
	game_over.visible = false
	_build_hp_blocks()
	_build_hp_blocks2()
	_apply_safe_area()

# 程序化生成 10 个离散生命格（小方块），避免 tscn 冗长
func _build_hp_blocks() -> void:
	for i in HP_BLOCK_COUNT:
		var r := ColorRect.new()
		r.custom_minimum_size = Vector2(6, 10)
		r.color = Color(1.0, 0.35, 0.25, 1)  # FC 热血红橙
		hp_blocks.add_child(r)
		_hp_rects.append(r)

# V1.1 P2 生命格
func _build_hp_blocks2() -> void:
	for i in HP_BLOCK_COUNT:
		var r := ColorRect.new()
		r.custom_minimum_size = Vector2(6, 10)
		r.color = Color(0.95, 0.35, 0.75, 1)  # 友方洋红
		hp_blocks2.add_child(r)
		_hp_rects2.append(r)

# 适配 Android 刘海/打孔屏安全区：把屏幕物理安全区换算到画布坐标系，
# 叠加到顶部信息带、头像、魂槽、弹药手雷区的 anchors/offsets 上。
func _apply_safe_area() -> void:
	var safe := Rect2(DisplayServer.get_display_safe_area())
	if safe == Rect2():
		return
	var visible := get_viewport().get_visible_rect()
	var xform := get_viewport().get_canvas_transform().affine_inverse()
	var a: Vector2 = xform * safe.position
	var b: Vector2 = xform * safe.end
	var left_margin: float = a.x - visible.position.x
	var top_margin: float = a.y - visible.position.y
	var right_margin: float = visible.end.x - b.x
	var bottom_margin: float = visible.end.y - b.y
	# 顶部信息带：向下、向右让出刘海/状态栏，右侧让出圆角/挖孔
	top_bar.offset_left += left_margin
	top_bar.offset_top += top_margin
	top_bar.offset_right -= right_margin
	# 左上角头像生命条
	avatar_hp.offset_left += left_margin
	avatar_hp.offset_top += top_margin
	# 热血魂槽（在头像下方）
	energy_slot.offset_left += left_margin
	energy_slot.offset_top += top_margin
	# 左下角弹药手雷区
	ammo_grenade.offset_left += left_margin
	ammo_grenade.offset_right -= right_margin
	ammo_grenade.offset_bottom -= bottom_margin
	# 右上角 buff 区
	buff_bar.offset_left -= right_margin
	buff_bar.offset_top += top_margin
	buff_bar.offset_right -= right_margin
	# ---- V1.1 P2 右侧镜像节点安全区 ----
	avatar_hp2.offset_right -= right_margin
	avatar_hp2.offset_top += top_margin
	energy_slot2.offset_right -= right_margin
	energy_slot2.offset_top += top_margin
	ammo_grenade2.offset_left -= right_margin
	ammo_grenade2.offset_right -= right_margin
	ammo_grenade2.offset_bottom -= bottom_margin
	# ---- V1.3 Boss 血条顶部安全区偏移 ----
	boss_bar.offset_top += top_margin

func set_hp(v: int, m: int) -> void:
	var pct := 1.0
	if m > 0:
		pct = float(v) / float(m)
	pct = clampf(pct, 0.0, 1.0)
	# 离散生命格：按比例点亮小方块
	var filled := int(round(pct * HP_BLOCK_COUNT))
	for i in _hp_rects.size():
		_hp_rects[i].visible = i < filled
	# 头像随 HP 变暗（modulate 亮度）
	var bright := 0.25 + 0.75 * pct
	avatar_tex.modulate = Color(bright, bright, bright)
	# 低于 30% 显示红色裂纹/破碎效果
	crack_rect.visible = pct < 0.3

func set_energy(v: float, m: float) -> void:
	var pct := 0.0
	if m > 0.0:
		pct = clampf(v / m, 0.0, 1.0)
	var fill_w := pct * ENERGY_W
	# 三段伪渐变填充：灰 / 黄 / 红，按能量百分比裁剪各段宽度
	seg1.visible = fill_w > 0.5
	seg1.offset_left = 0.0
	seg1.offset_right = minf(fill_w, SEG_W)
	seg2.visible = fill_w > SEG_W + 0.5
	seg2.offset_left = SEG_W
	seg2.offset_right = SEG_W + minf(maxf(fill_w - SEG_W, 0.0), SEG_W)
	seg3.visible = fill_w > 2.0 * SEG_W + 0.5
	seg3.offset_left = 2.0 * SEG_W
	seg3.offset_right = 2.0 * SEG_W + minf(maxf(fill_w - 2.0 * SEG_W, 0.0), SEG_W)
	# 满能量时槽位发光闪烁，未满时停止
	if pct >= 1.0:
		if _energy_tween == null or not _energy_tween.is_running():
			_energy_tween = create_tween().set_loops()
			_energy_tween.tween_property(energy_slot, "modulate", Color(1.4, 1.2, 0.6), 0.4).set_trans(Tween.TRANS_SINE)
			_energy_tween.tween_property(energy_slot, "modulate", Color(1, 1, 1), 0.4).set_trans(Tween.TRANS_SINE)
	else:
		if _energy_tween != null and _energy_tween.is_running():
			_energy_tween.kill()
		energy_slot.modulate = Color(1, 1, 1)

func set_ammo(v: int, m: int) -> void:
	ammo_label.text = "弹药 %d / %d" % [v, m]

func set_wave(w: int) -> void:
	wave_label.text = "第 %d 波" % w

func set_score(s: int) -> void:
	score_label.text = "分数 %d" % s

func set_kills(k: int) -> void:
	kills_label.text = "击倒 %d" % k

# V1.2：金币显示（由 game.gd 连接 Economy.coins_changed）
func set_coins(amount: int) -> void:
	coins_label.text = "金币 %d" % amount

# 新增：时间显示，秒数格式化为 "MM:SS"（>=60s）或 "Ns"
func set_time(t: float) -> void:
	var secs := int(t)
	if secs < 60:
		time_label.text = "时间 %ds" % secs
	else:
		var mm := secs / 60
		var ss := secs % 60
		time_label.text = "时间 %02d:%02d" % [mm, ss]

# 新增：当前武器名称
func set_weapon(name: String) -> void:
	weapon_name.text = name

# 新增：手雷数量
func set_grenades(count: int) -> void:
	grenade_label.text = "手雷 x%d" % count

# 新增：刷新 buff 图标区。active 元素为 {name: String, remaining: float}，最多 4 个，空数组隐藏。
func set_buffs(active: Array) -> void:
	# 清空旧 buff 子节点
	for child in buff_bar.get_children():
		child.queue_free()
	# 最多显示 4 个
	var count: int = mini(active.size(), 4)
	buff_bar.visible = count > 0
	for i in count:
		var entry: Dictionary = active[i]
		var buff_name: String = str(entry.get("name", ""))
		var remaining: float = float(entry.get("remaining", 0.0))
		var color: Color = BUFF_COLORS.get(buff_name, Color(0.7, 0.7, 0.7, 1))
		# 单个 buff 单元：色块图标 + 下方剩余时间
		var item := Control.new()
		item.custom_minimum_size = Vector2(BUFF_ICON_SIZE, 54.0)
		var icon := ColorRect.new()
		icon.color = color
		icon.position = Vector2(0, 0)
		icon.size = Vector2(BUFF_ICON_SIZE, BUFF_ICON_SIZE)
		item.add_child(icon)
		var timer_lbl := Label.new()
		timer_lbl.text = "%ds" % int(ceil(remaining))
		timer_lbl.position = Vector2(0, BUFF_ICON_SIZE + 2)
		timer_lbl.size = Vector2(BUFF_ICON_SIZE, 14)
		timer_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		timer_lbl.add_theme_font_size_override("font_size", 12)
		timer_lbl.add_theme_color_override("font_color", Color(1, 1, 1, 0.95))
		item.add_child(timer_lbl)
		buff_bar.add_child(item)

func show_game_over(s: int, w: int) -> void:
	if OS.has_feature("mobile"):
		final_score.text = "分数 %d · 撑到第 %d 波\n点击重开按钮重新开始" % [s, w]
	else:
		final_score.text = "分数 %d · 撑到第 %d 波\n按 R 或小键盘 * 重新开始" % [s, w]
	game_over.visible = true

func hide_game_over() -> void:
	game_over.visible = false


# ==================== V1.1 P2 HUD 函数 ====================
func set_hp_p2(v: int, m: int) -> void:
	var pct := 1.0
	if m > 0:
		pct = float(v) / float(m)
	pct = clampf(pct, 0.0, 1.0)
	var filled := int(round(pct * HP_BLOCK_COUNT))
	for i in _hp_rects2.size():
		_hp_rects2[i].visible = i < filled
	var bright := 0.25 + 0.75 * pct
	# P2 头像保持蓝色调 modulate（白底亮起来时偏蓝）
	avatar_tex2.modulate = Color(0.7 * bright + 0.3, 0.85 * bright + 0.15, 1.0)
	crack_rect2.visible = pct < 0.3


func set_energy_p2(v: float, m: float) -> void:
	var pct := 0.0
	if m > 0.0:
		pct = clampf(v / m, 0.0, 1.0)
	var fill_w := pct * ENERGY_W
	seg1_2.visible = fill_w > 0.5
	seg1_2.offset_left = 0.0
	seg1_2.offset_right = minf(fill_w, SEG_W)
	seg2_2.visible = fill_w > SEG_W + 0.5
	seg2_2.offset_left = SEG_W
	seg2_2.offset_right = SEG_W + minf(maxf(fill_w - SEG_W, 0.0), SEG_W)
	seg3_2.visible = fill_w > 2.0 * SEG_W + 0.5
	seg3_2.offset_left = 2.0 * SEG_W
	seg3_2.offset_right = 2.0 * SEG_W + minf(maxf(fill_w - 2.0 * SEG_W, 0.0), SEG_W)
	if pct >= 1.0:
		if _energy_tween2 == null or not _energy_tween2.is_running():
			_energy_tween2 = create_tween().set_loops()
			_energy_tween2.tween_property(energy_slot2, "modulate", Color(0.8, 1.0, 1.4), 0.4).set_trans(Tween.TRANS_SINE)
			_energy_tween2.tween_property(energy_slot2, "modulate", Color(1, 1, 1), 0.4).set_trans(Tween.TRANS_SINE)
	else:
		if _energy_tween2 != null and _energy_tween2.is_running():
			_energy_tween2.kill()
		energy_slot2.modulate = Color(1, 1, 1)


func set_ammo_p2(v: int, m: int) -> void:
	ammo_label2.text = "弹药 %d / %d" % [v, m]


func set_weapon_p2(name: String) -> void:
	weapon_name2.text = name


func set_grenades_p2(count: int) -> void:
	grenade_label2.text = "手雷 x%d" % count


func set_buffs_p2(active: Array) -> void:
	# V1.1 P2 暂无独立 buff 图标区（节点清单仅含头像/魂槽/弹药手雷三组）。
	# 接口保留供后续模块使用；当前不渲染，避免覆盖 P1 的 BuffBar。
	pass


# ==================== V1.1 半尸化状态指示 ====================
func set_half_zombie(active: bool, p_index: int = 1) -> void:
	if p_index == 1:
		if active:
			# 头像变绿 + 标签显示 + 绿色边框脉动
			avatar_tex.modulate = Color(0.5, 1.0, 0.5, 1.0)
			hz_label.visible = true
			hz_border.color = Color(0.3, 1.0, 0.3, 0.5)
			if _hz_tween != null and _hz_tween.is_running():
				_hz_tween.kill()
			_hz_tween = create_tween().set_loops()
			_hz_tween.tween_property(hz_border, "modulate:a", 0.9, 0.5).set_trans(Tween.TRANS_SINE)
			_hz_tween.tween_property(hz_border, "modulate:a", 0.3, 0.5).set_trans(Tween.TRANS_SINE)
		else:
			if _hz_tween != null and _hz_tween.is_running():
				_hz_tween.kill()
			avatar_tex.modulate = Color.WHITE
			hz_label.visible = false
			hz_border.modulate = Color(0, 0, 0, 0)
	else:
		if active:
			avatar_tex2.modulate = Color(0.5, 1.0, 0.5, 1.0)
			hz_label2.visible = true
			hz_border2.color = Color(0.3, 1.0, 0.3, 0.5)
			if _hz_tween2 != null and _hz_tween2.is_running():
				_hz_tween2.kill()
			_hz_tween2 = create_tween().set_loops()
			_hz_tween2.tween_property(hz_border2, "modulate:a", 0.9, 0.5).set_trans(Tween.TRANS_SINE)
			_hz_tween2.tween_property(hz_border2, "modulate:a", 0.3, 0.5).set_trans(Tween.TRANS_SINE)
		else:
			if _hz_tween2 != null and _hz_tween2.is_running():
				_hz_tween2.kill()
			# P2 头像恢复原有偏蓝调
			avatar_tex2.modulate = Color(0.7, 0.85, 1.0, 1.0)
			hz_label2.visible = false
			hz_border2.modulate = Color(0, 0, 0, 0)


# ==================== V1.3 Boss 血条 ====================
# 显示 Boss 血条并初始化（Boss 出场时调用）
func show_boss_bar(boss_name: String, max_hp: int) -> void:
	boss_name_label.text = boss_name
	boss_phase_label.text = "阶段 1/3"
	_set_boss_fill_ratio(1.0)
	boss_bar.visible = true


# 刷新 Boss 当前血量与阶段（连接 boss.hp_changed / phase_changed）
func set_boss_hp(current: int, max: int, phase: int) -> void:
	var pct := 1.0
	if max > 0:
		pct = float(current) / float(max)
	pct = clampf(pct, 0.0, 1.0)
	_set_boss_fill_ratio(pct)
	boss_phase_label.text = "阶段 %d/3" % phase


# 隐藏 Boss 血条（Boss 死亡时调用）
func hide_boss_bar() -> void:
	boss_bar.visible = false


# 内部：按比例调整 BossFill 宽度（血条总宽 800，左侧锚定）
func _set_boss_fill_ratio(pct: float) -> void:
	var BAR_W := 800.0
	boss_fill.offset_left = 0.0
	boss_fill.offset_right = BAR_W * pct
