extends Control
# V2.0 角色选择界面：暗灰废墟色调 + 白色像素标题 + 金色高亮选中
# P1 选角色，P2 固定为电脑 AI 队友；卡片由 _build_cards() 程序化生成

var current_selector: int = 1  # 始终为 P1

@onready var cards_container: HBoxContainer = $Center/VBox/CardsContainer
@onready var p1_indicator: Label = $BottomBar/P1Indicator
@onready var p2_indicator: Label = $BottomBar/P2Indicator
@onready var start_button: Button = $BottomBar/StartButton
@onready var subtitle: Label = $TitleBar/SubTitleLabel

const CARD_SIZE := Vector2(210, 330)
const BAR_MAX := 1.5  # 属性条满格对应倍率
const BAR_FULL_WIDTH := 140.0

const COL_GOLD := Color(1.0, 0.85, 0.30, 1)
const COL_GOLD_GLOW := Color(1.0, 0.85, 0.30, 0.25)
const COL_GRAY_BORDER := Color(0.30, 0.30, 0.32, 1)
const COL_PANEL := Color(0.08, 0.08, 0.10, 1)


func _ready() -> void:
	_build_cards()
	_update_indicators()
	_update_subtitle()
	if start_button != null:
		start_button.pressed.connect(_on_start)


func _build_cards() -> void:
	# 清空旧卡片
	for c in cards_container.get_children():
		c.queue_free()
	var ids: Array = CharacterData.get_available_ids()
	for char_id in ids:
		var data: Dictionary = CharacterData.get_character(char_id)
		if data.is_empty():
			continue
		var card := _make_card(char_id, data)
		cards_container.add_child(card)
		_mark_card(card, char_id)


func _make_card(char_id: String, data: Dictionary) -> Control:
	# 外层包裹：负责外发光 + 黄色箭头（自包含，随选中态切换）
	var outer := Control.new()
	outer.custom_minimum_size = CARD_SIZE
	outer.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	outer.size_flags_vertical = Control.SIZE_SHRINK_CENTER

	# 外发光（默认透明）
	var glow := ColorRect.new()
	glow.set_anchors_preset(Control.PRESET_FULL_RECT)
	glow.offset_left = -8
	glow.offset_top = -8
	glow.offset_right = 8
	glow.offset_bottom = 8
	glow.color = Color(1.0, 0.85, 0.30, 0.0)
	outer.add_child(glow)

	# 卡片面板
	var card := PanelContainer.new()
	card.set_anchors_preset(Control.PRESET_FULL_RECT)
	var style := StyleBoxFlat.new()
	style.bg_color = COL_PANEL
	style.border_color = COL_GRAY_BORDER
	style.set_border_width_all(2)
	style.set_content_margin_all(10)
	card.add_theme_stylebox_override("panel", style)
	outer.add_child(card)

	var vbox := VBoxContainer.new()
	vbox.alignment = VBoxContainer.ALIGNMENT_CENTER
	vbox.add_theme_constant_override("separation", 6)
	card.add_child(vbox)

	# 像素头像（用 ColorRect 拼出简化半身像）
	var avatar_wrap := CenterContainer.new()
	vbox.add_child(avatar_wrap)
	avatar_wrap.add_child(_make_pixel_avatar(data))

	# 角色名
	var name_lbl := Label.new()
	name_lbl.text = data.get("name", "?")
	name_lbl.add_theme_font_size_override("font_size", 24)
	name_lbl.add_theme_color_override("font_color", Color.WHITE)
	name_lbl.add_theme_color_override("font_outline_color", Color(0, 0, 0, 1))
	name_lbl.add_theme_constant_override("outline_size", 4)
	name_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(name_lbl)

	# 描述
	var desc_lbl := Label.new()
	desc_lbl.text = data.get("desc", "")
	desc_lbl.add_theme_font_size_override("font_size", 12)
	desc_lbl.add_theme_color_override("font_color", Color(0.72, 0.72, 0.75, 1))
	desc_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	desc_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	desc_lbl.custom_minimum_size = Vector2(185, 38)
	vbox.add_child(desc_lbl)

	# 属性条
	vbox.add_child(_make_stat_bar("速度", float(data.get("speed_mult", 1.0)), Color(0.3, 0.9, 0.4)))
	vbox.add_child(_make_stat_bar("攻击", float(data.get("atk_mult", 1.0)), Color(0.9, 0.35, 0.3)))
	vbox.add_child(_make_stat_bar("体力", float(data.get("hp_mult", 1.0)), Color(0.95, 0.85, 0.3)))

	# 选择按钮（仅 P1 可用）
	var btn := Button.new()
	btn.text = "选择"
	btn.add_theme_font_size_override("font_size", 16)
	btn.custom_minimum_size = Vector2(100, 32)
	btn.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	btn.pressed.connect(_on_select.bind(char_id))
	vbox.add_child(btn)

	# 选中指示箭头（黄色三角形，指向右侧；仅选中时显示）
	var arrow := Polygon2D.new()
	arrow.color = COL_GOLD
	arrow.polygon = PackedVector2Array([Vector2(0, 0), Vector2(22, 14), Vector2(0, 28)])
	arrow.position = Vector2(CARD_SIZE.x - 4, CARD_SIZE.y / 2.0 - 14)
	arrow.visible = false
	outer.add_child(arrow)

	outer.set_meta("char_id", char_id)
	outer.set_meta("card_panel", card)
	outer.set_meta("glow", glow)
	outer.set_meta("arrow", arrow)
	outer.set_meta("select_button", btn)
	return outer


# 用 ColorRect 拼一个简化像素半身像：肤色 + 头发 + 角色主色躯干
func _make_pixel_avatar(data: Dictionary) -> Control:
	var box := Control.new()
	box.custom_minimum_size = Vector2(130, 130)
	var skin := Color(0.95, 0.80, 0.62)
	var hair := Color(0.08, 0.08, 0.10)
	var torso: Color = data.get("color", Color.WHITE)

	var bg := ColorRect.new()
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.color = Color(0.05, 0.05, 0.07, 1)
	box.add_child(bg)

	# 躯干/肩膀（角色主色）
	var body := ColorRect.new()
	body.offset_left = 16
	body.offset_top = 80
	body.offset_right = 114
	body.offset_bottom = 130
	body.color = torso
	box.add_child(body)

	# 立领
	var collar := ColorRect.new()
	collar.offset_left = 52
	collar.offset_top = 80
	collar.offset_right = 78
	collar.offset_bottom = 94
	collar.color = Color(0.12, 0.12, 0.14, 1)
	box.add_child(collar)

	# 脖子
	var neck := ColorRect.new()
	neck.offset_left = 56
	neck.offset_top = 68
	neck.offset_right = 74
	neck.offset_bottom = 84
	neck.color = skin.darkened(0.08)
	box.add_child(neck)

	# 脸
	var face := ColorRect.new()
	face.offset_left = 44
	face.offset_top = 30
	face.offset_right = 86
	face.offset_bottom = 74
	face.color = skin
	box.add_child(face)

	# 头发
	var hair_rect := ColorRect.new()
	hair_rect.offset_left = 40
	hair_rect.offset_top = 18
	hair_rect.offset_right = 90
	hair_rect.offset_bottom = 42
	hair_rect.color = hair
	box.add_child(hair_rect)

	# 眼睛
	var eye_l := ColorRect.new()
	eye_l.offset_left = 52
	eye_l.offset_top = 48
	eye_l.offset_right = 58
	eye_l.offset_bottom = 54
	eye_l.color = Color(0.08, 0.06, 0.06, 1)
	box.add_child(eye_l)

	var eye_r := ColorRect.new()
	eye_r.offset_left = 72
	eye_r.offset_top = 48
	eye_r.offset_right = 78
	eye_r.offset_bottom = 54
	eye_r.color = Color(0.08, 0.06, 0.06, 1)
	box.add_child(eye_r)

	return box


func _make_stat_bar(label_text: String, mult: float, bar_color: Color) -> Control:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)
	var lbl := Label.new()
	lbl.text = label_text
	lbl.custom_minimum_size = Vector2(36, 16)
	lbl.add_theme_font_size_override("font_size", 13)
	lbl.add_theme_color_override("font_color", Color(0.85, 0.85, 0.85, 1))
	row.add_child(lbl)
	var track := ColorRect.new()
	track.color = Color(0.1, 0.1, 0.12, 1)
	track.custom_minimum_size = Vector2(BAR_FULL_WIDTH, 12)
	row.add_child(track)
	var fill := ColorRect.new()
	fill.color = bar_color
	var w := clampf(mult, 0.0, BAR_MAX) / BAR_MAX * BAR_FULL_WIDTH
	fill.custom_minimum_size = Vector2(w, 12)
	# 进度条叠加在轨道左侧
	fill.set_anchors_preset(Control.PRESET_LEFT_WIDE)
	fill.offset_left = 0
	fill.offset_top = 0
	fill.offset_right = w
	fill.offset_bottom = 12
	track.add_child(fill)
	return row


func _on_select(char_id: String) -> void:
	# P2 固定为电脑 AI，不参与轮选；只记录 P1 选择
	CharacterData.select(1, char_id)
	_update_indicators()
	_update_subtitle()
	_mark_all_cards()


func _update_indicators() -> void:
	var p1_name: String = CharacterData.get_character(CharacterData.selected_p1).get("name", "?")
	if p1_indicator != null:
		p1_indicator.text = "P1: " + p1_name
	if p2_indicator != null:
		p2_indicator.text = "P2：电脑（AI 队友）"


func _update_subtitle() -> void:
	if subtitle != null:
		subtitle.text = "选择你的角色 —— P2 由电脑 AI 自动控制"


func _mark_all_cards() -> void:
	for c in cards_container.get_children():
		var char_id: String = c.get_meta("char_id", "")
		_mark_card(c, char_id)


func _mark_card(card: Control, char_id: String) -> void:
	var panel := card.get_meta("card_panel", null) as PanelContainer
	if panel == null:
		return
	var st := panel.get_theme_stylebox("panel") as StyleBoxFlat
	var glow := card.get_meta("glow", null) as ColorRect
	var arrow := card.get_meta("arrow", null) as Polygon2D
	var is_p1 := CharacterData.selected_p1 == char_id
	if st != null:
		if is_p1:
			st.border_color = COL_GOLD
			st.set_border_width_all(5)
		else:
			st.border_color = COL_GRAY_BORDER
			st.set_border_width_all(2)
	if glow != null:
		glow.color = COL_GOLD_GLOW if is_p1 else Color(1.0, 0.85, 0.30, 0.0)
	if arrow != null:
		arrow.visible = is_p1


func _on_start() -> void:
	# P2 固定为默认角色 pompadour（飞机头主角），由 AI 控制
	CharacterData.select(2, "pompadour")
	get_tree().change_scene_to_file("res://scenes/main.tscn")


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_accept") or event.is_action_pressed("restart"):
		_on_start()
		get_viewport().set_input_as_handled()
	elif event is InputEventKey and event.pressed and event.keycode == KEY_ENTER:
		_on_start()
		get_viewport().set_input_as_handled()
