extends CanvasLayer
# HUD V2.0 街机像素风：顶部黑条（角色名+红色横血槽+黄色能量格 / SCORE / INSERT COIN）
# 左下/右下暗灰武器面板（十字图标 + 武器名 + 大弹药数）。全部函数签名与 V1.x 保持兼容。

# ---- 顶部信息条 ----
@onready var score_label: Label = $ScoreLabel
@onready var wave_label: Label = $InfoBar/WaveLabel
@onready var kills_label: Label = $InfoBar/KillsLabel
@onready var coins_label: Label = $InfoBar/CoinsLabel
@onready var time_label: Label = $InfoBar/TimeLabel
@onready var insert_coin_label: Label = $InsertCoinLabel

# ---- P1 血槽 / 能量格 ----
@onready var hp_fill: ColorRect = $P1Group/HPFill
@onready var crack_rect: ColorRect = $P1Group/CrackRect
@onready var energy_grid: HBoxContainer = $P1Group/EnergyGrid
@onready var hz_label: Label = $P1Group/HzLabel

# ---- P1 武器面板 ----
@onready var weapon_panel: Control = $WeaponPanel
@onready var weapon_name: Label = $WeaponPanel/WeaponName
@onready var ammo_label: Label = $WeaponPanel/AmmoLabel
@onready var grenade_label: Label = $WeaponPanel/GrenadeLabel

@onready var buff_bar: HBoxContainer = $BuffBar

@onready var game_over: PanelContainer = $GameOver
@onready var final_score: Label = $GameOver/Margin/FinalScore

# ---- P2 镜像 ----
@onready var hp_fill2: ColorRect = $P2Group/HPFill2
@onready var crack_rect2: ColorRect = $P2Group/CrackRect2
@onready var energy_grid2: HBoxContainer = $P2Group/EnergyGrid2
@onready var hz_label2: Label = $P2Group/HzLabel2

@onready var weapon_panel2: Control = $WeaponPanel2
@onready var weapon_name2: Label = $WeaponPanel2/WeaponName2
@onready var ammo_label2: Label = $WeaponPanel2/AmmoLabel2
@onready var grenade_label2: Label = $WeaponPanel2/GrenadeLabel2

# ---- Boss 血条 ----
@onready var boss_bar: Control = $BossHealthBar
@onready var boss_fill: ColorRect = $BossHealthBar/BossFill
@onready var boss_name_label: Label = $BossHealthBar/BossNameLabel
@onready var boss_phase_label: Label = $BossHealthBar/BossPhaseLabel

# 血槽填充几何（P1 血槽在 P1Group 内 offset_left=92，宽 186；P2 宽 126，右锚）
const P1_FILL_X := 92.0
const P1_FILL_W := 186.0
const P2_FILL_X := 42.0
const P2_FILL_W := 126.0
const P1_ENERGY_COUNT := 6
const P2_ENERGY_COUNT := 4
const BUFF_ICON_SIZE := 36.0

const HP_COLOR := Color(0.85, 0.15, 0.15, 1)
const ENERGY_ON := Color(1.0, 0.82, 0.25, 1)
const ENERGY_OFF := Color(0.18, 0.18, 0.22, 1)

const BUFF_COLORS := {
	"sports_drink": Color(0.3, 0.6, 0.95, 1),
	"chili_rice": Color(0.9, 0.25, 0.2, 1),
	"iron_pipe": Color(0.55, 0.55, 0.55, 1),
	"armor_vest": Color(0.3, 0.75, 0.35, 1),
}

var _p1_squares: Array[ColorRect] = []
var _p2_squares: Array[ColorRect] = []
var _energy_tween: Tween = null
var _energy_tween2: Tween = null
var _coin_tween: Tween = null
var _hz_tween: Tween = null
var _hz_tween2: Tween = null

func _ready() -> void:
	game_over.visible = false
	_collect_squares()
	_start_coin_blink()
	_apply_safe_area()

func _collect_squares() -> void:
	for c in energy_grid.get_children():
		if c is ColorRect:
			_p1_squares.append(c)
	for c in energy_grid2.get_children():
		if c is ColorRect:
			_p2_squares.append(c)

# INSERT COIN 街机闪烁
func _start_coin_blink() -> void:
	_coin_tween = create_tween().set_loops()
	_coin_tween.tween_property(insert_coin_label, "modulate:a", 0.25, 0.6).set_trans(Tween.TRANS_SINE)
	_coin_tween.tween_property(insert_coin_label, "modulate:a", 1.0, 0.6).set_trans(Tween.TRANS_SINE)

# 安全区适配：把系统安全区换算到画布坐标，叠加到各组 anchors/offsets 上。
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
	# P1 组（左上）
	$TopBarBg.offset_left += left_margin
	$TopBarBg.offset_top += top_margin
	$TopBarBg.offset_bottom += top_margin
	$P1Group.offset_left += left_margin
	$P1Group.offset_top += top_margin
	# P2 组（右上）
	$P2Group.offset_right -= right_margin
	$P2Group.offset_top += top_margin
	insert_coin_label.offset_right -= right_margin
	insert_coin_label.offset_top += top_margin
	score_label.offset_top += top_margin
	# 左下/右下武器面板
	weapon_panel.offset_left += left_margin
	weapon_panel.offset_bottom -= bottom_margin
	weapon_panel2.offset_right -= right_margin
	weapon_panel2.offset_bottom -= bottom_margin
	# buff 区
	buff_bar.offset_left -= right_margin
	buff_bar.offset_top += top_margin
	buff_bar.offset_right -= right_margin
	# Boss 血条
	boss_bar.offset_top += top_margin

# ==================== P1 ====================
func set_hp(v: int, m: int) -> void:
	var pct := 1.0
	if m > 0:
		pct = float(v) / float(m)
	pct = clampf(pct, 0.0, 1.0)
	# 红色横条：左锚定，按比例缩短
	hp_fill.offset_left = P1_FILL_X
	hp_fill.offset_right = P1_FILL_X + P1_FILL_W * pct
	crack_rect.visible = pct < 0.3
	crack_rect.modulate.a = 1.0

func set_energy(v: float, m: float) -> void:
	var pct := 0.0
	if m > 0.0:
		pct = clampf(v / m, 0.0, 1.0)
	var filled := int(round(pct * _p1_squares.size()))
	for i in _p1_squares.size():
		_p1_squares[i].color = ENERGY_ON if i < filled else ENERGY_OFF
	# 满能量闪烁
	if pct >= 1.0:
		if _energy_tween == null or not _energy_tween.is_running():
			_energy_tween = create_tween().set_loops()
			_energy_tween.tween_property(energy_grid, "modulate", Color(1.4, 1.2, 0.6), 0.4).set_trans(Tween.TRANS_SINE)
			_energy_tween.tween_property(energy_grid, "modulate", Color(1, 1, 1), 0.4).set_trans(Tween.TRANS_SINE)
	else:
		if _energy_tween != null and _energy_tween.is_running():
			_energy_tween.kill()
		energy_grid.modulate = Color(1, 1, 1)

func set_ammo(v: int, m: int) -> void:
	ammo_label.text = "%d/%d" % [v, m]

func set_wave(w: int) -> void:
	wave_label.text = "第 %d 波" % w

func set_score(s: int) -> void:
	score_label.text = "SCORE %d" % s

func set_kills(k: int) -> void:
	kills_label.text = "击倒 %d" % k

func set_coins(amount: int) -> void:
	coins_label.text = "金币 %d" % amount

func set_time(t: float) -> void:
	var secs := int(t)
	if secs < 60:
		time_label.text = "%ds" % secs
	else:
		var mm := secs / 60
		var ss := secs % 60
		time_label.text = "%02d:%02d" % [mm, ss]

func set_weapon(name: String) -> void:
	weapon_name.text = name

func set_grenades(count: int) -> void:
	grenade_label.text = "手雷 x%d" % count

func set_buffs(active: Array) -> void:
	for child in buff_bar.get_children():
		child.queue_free()
	var count: int = mini(active.size(), 4)
	buff_bar.visible = count > 0
	for i in count:
		var entry: Dictionary = active[i]
		var buff_name: String = str(entry.get("name", ""))
		var remaining: float = float(entry.get("remaining", 0.0))
		var color: Color = BUFF_COLORS.get(buff_name, Color(0.7, 0.7, 0.7, 1))
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

# ==================== P2 ====================
func set_hp_p2(v: int, m: int) -> void:
	var pct := 1.0
	if m > 0:
		pct = float(v) / float(m)
	pct = clampf(pct, 0.0, 1.0)
	# P2 血槽右锚定，从右侧消耗
	hp_fill2.offset_left = P2_FILL_X + P2_FILL_W * (1.0 - pct)
	hp_fill2.offset_right = P2_FILL_X + P2_FILL_W
	crack_rect2.visible = pct < 0.3

func set_energy_p2(v: float, m: float) -> void:
	var pct := 0.0
	if m > 0.0:
		pct = clampf(v / m, 0.0, 1.0)
	var filled := int(round(pct * _p2_squares.size()))
	for i in _p2_squares.size():
		_p2_squares[i].color = ENERGY_ON if i < filled else ENERGY_OFF
	if pct >= 1.0:
		if _energy_tween2 == null or not _energy_tween2.is_running():
			_energy_tween2 = create_tween().set_loops()
			_energy_tween2.tween_property(energy_grid2, "modulate", Color(0.8, 1.0, 1.4), 0.4).set_trans(Tween.TRANS_SINE)
			_energy_tween2.tween_property(energy_grid2, "modulate", Color(1, 1, 1), 0.4).set_trans(Tween.TRANS_SINE)
	else:
		if _energy_tween2 != null and _energy_tween2.is_running():
			_energy_tween2.kill()
		energy_grid2.modulate = Color(1, 1, 1)

func set_ammo_p2(v: int, m: int) -> void:
	ammo_label2.text = "%d/%d" % [v, m]

func set_weapon_p2(name: String) -> void:
	weapon_name2.text = name

func set_grenades_p2(count: int) -> void:
	grenade_label2.text = "手雷 x%d" % count

func set_buffs_p2(active: Array) -> void:
	pass

# ==================== 半尸化 ====================
func set_half_zombie(active: bool, p_index: int = 1) -> void:
	if p_index == 1:
		if active:
			hz_label.visible = true
			hz_label.modulate = Color(0.4, 1.0, 0.4, 1.0)
			if _hz_tween != null and _hz_tween.is_running():
				_hz_tween.kill()
			_hz_tween = create_tween().set_loops()
			_hz_tween.tween_property(hz_label, "modulate:a", 0.9, 0.5).set_trans(Tween.TRANS_SINE)
			_hz_tween.tween_property(hz_label, "modulate:a", 0.3, 0.5).set_trans(Tween.TRANS_SINE)
		else:
			if _hz_tween != null and _hz_tween.is_running():
				_hz_tween.kill()
			hz_label.visible = false
	else:
		if active:
			hz_label2.visible = true
			hz_label2.modulate = Color(0.4, 1.0, 0.4, 1.0)
			if _hz_tween2 != null and _hz_tween2.is_running():
				_hz_tween2.kill()
			_hz_tween2 = create_tween().set_loops()
			_hz_tween2.tween_property(hz_label2, "modulate:a", 0.9, 0.5).set_trans(Tween.TRANS_SINE)
			_hz_tween2.tween_property(hz_label2, "modulate:a", 0.3, 0.5).set_trans(Tween.TRANS_SINE)
		else:
			if _hz_tween2 != null and _hz_tween2.is_running():
				_hz_tween2.kill()
			hz_label2.visible = false

# ==================== Boss 血条 ====================
func show_boss_bar(boss_name: String, max_hp: int) -> void:
	boss_name_label.text = boss_name
	boss_phase_label.text = "阶段 1/3"
	_set_boss_fill_ratio(1.0)
	boss_bar.visible = true

func set_boss_hp(current: int, max: int, phase: int) -> void:
	var pct := 1.0
	if max > 0:
		pct = float(current) / float(max)
	pct = clampf(pct, 0.0, 1.0)
	_set_boss_fill_ratio(pct)
	boss_phase_label.text = "阶段 %d/3" % phase

func hide_boss_bar() -> void:
	boss_bar.visible = false

func _set_boss_fill_ratio(pct: float) -> void:
	var BAR_W := 800.0
	boss_fill.offset_left = 0.0
	boss_fill.offset_right = BAR_W * pct
