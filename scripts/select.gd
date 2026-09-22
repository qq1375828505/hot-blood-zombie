extends Control
# V1.4 角色选择界面：P1 选角色，P2 固定为电脑 AI 队友

var current_selector: int = 1  # 始终为 P1

@onready var cards_container: HBoxContainer = $Center/VBox/CardsContainer
@onready var p1_indicator: Label = $BottomBar/P1Indicator
@onready var p2_indicator: Label = $BottomBar/P2Indicator
@onready var start_button: Button = $BottomBar/StartButton
@onready var subtitle: Label = $TitleBar/SubTitleLabel

const CARD_SIZE := Vector2(200, 320)
const BAR_MAX := 1.5  # 属性条满格对应倍率
const BAR_FULL_WIDTH := 140.0


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
	var card := PanelContainer.new()
	card.custom_minimum_size = CARD_SIZE
	card.size_flags_horizontal = Control.SIZE_SHRINK_CENTER

	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.05, 0.05, 0.08, 1)
	style.border_color = Color(1, 0.2, 0.6, 1)  # 洋红边框
	style.set_border_width_all(3)
	style.set_content_margin_all(8)
	card.add_theme_stylebox_override("panel", style)

	var vbox := VBoxContainer.new()
	vbox.alignment = VBoxContainer.ALIGNMENT_CENTER
	vbox.add_theme_constant_override("separation", 6)
	card.add_child(vbox)

	# 头像色块（带角色名首字）
	var avatar_wrap := CenterContainer.new()
	vbox.add_child(avatar_wrap)
	var avatar := ColorRect.new()
	avatar.color = data.get("color", Color.WHITE)
	avatar.custom_minimum_size = Vector2(96, 96)
	avatar.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	avatar_wrap.add_child(avatar)
	var avatar_label := Label.new()
	avatar_label.text = str(data.get("name", "?")).substr(0, 1)
	avatar_label.add_theme_font_size_override("font_size", 48)
	avatar_label.add_theme_color_override("font_color", Color(0, 0, 0, 1))
	avatar_label.set_anchors_preset(Control.PRESET_CENTER)
	avatar.add_child(avatar_label)

	# 角色名
	var name_lbl := Label.new()
	name_lbl.text = data.get("name", "?")
	name_lbl.add_theme_font_size_override("font_size", 20)
	name_lbl.add_theme_color_override("font_color", Color.WHITE)
	name_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_lbl.autowrap_mode = TextServer.AUTOWRAP_OFF
	vbox.add_child(name_lbl)

	# 描述
	var desc_lbl := Label.new()
	desc_lbl.text = data.get("desc", "")
	desc_lbl.add_theme_font_size_override("font_size", 13)
	desc_lbl.add_theme_color_override("font_color", Color(0.75, 0.75, 0.78, 1))
	desc_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	desc_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	desc_lbl.custom_minimum_size = Vector2(180, 50)
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

	card.set_meta("char_id", char_id)
	card.set_meta("select_button", btn)
	return card


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
	if not card.has_theme_stylebox_override("panel"):
		return
	var st := card.get_theme_stylebox("panel") as StyleBoxFlat
	if st == null:
		return
	var is_p1 := CharacterData.selected_p1 == char_id
	if is_p1:
		st.border_color = Color(1, 0.85, 0.2, 1)  # P1：黄色
	else:
		st.border_color = Color(1, 0.2, 0.6, 1)  # 未选中：洋红


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
