extends CanvasLayer
# 成就面板 UI：列出全部成就及解锁状态，可暂停游戏查看。

@onready var title_label: Label = $TitleLabel
@onready var progress_label: Label = $ProgressLabel
@onready var scroll: ScrollContainer = $ScrollContainer
@onready var list: VBoxContainer = $ScrollContainer/List
@onready var close_button: Button = $CloseButton


func _ready() -> void:
	# 面板在游戏暂停时仍需响应输入与刷新
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false
	close_button.pressed.connect(close)
	_refresh_list()


func open() -> void:
	visible = true
	_refresh_list()
	get_tree().paused = true


func close() -> void:
	visible = false
	get_tree().paused = false


func _refresh_list() -> void:
	for c in list.get_children():
		c.queue_free()
	var all: Dictionary = Achievements.get_all()
	var unlocked_count := 0
	for id in all.keys():
		var data: Dictionary = all[id]
		var is_unlocked := Achievements.is_unlocked(id)
		if is_unlocked:
			unlocked_count += 1
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 12)
		var icon_l := Label.new()
		icon_l.text = str(data.get("icon", ""))
		icon_l.add_theme_font_size_override("font_size", 22)
		var name_l := Label.new()
		name_l.text = str(data.get("name", ""))
		name_l.add_theme_font_size_override("font_size", 18)
		var desc_l := Label.new()
		desc_l.text = "  —  " + str(data.get("desc", ""))
		desc_l.add_theme_font_size_override("font_size", 16)
		var mark_l := Label.new()
		if is_unlocked:
			mark_l.text = "  ✓"
			name_l.add_theme_color_override("font_color", Color.WHITE)
			desc_l.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7))
			mark_l.add_theme_color_override("font_color", Color(0.3, 1.0, 0.4))
		else:
			mark_l.text = "  🔒"
			name_l.add_theme_color_override("font_color", Color(0.45, 0.45, 0.45))
			desc_l.add_theme_color_override("font_color", Color(0.35, 0.35, 0.35))
		row.add_child(icon_l)
		row.add_child(name_l)
		row.add_child(desc_l)
		row.add_child(mark_l)
		list.add_child(row)
	progress_label.text = "已解锁 %d / %d" % [unlocked_count, all.size()]


func _unhandled_input(event: InputEvent) -> void:
	if not visible:
		return
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_ESCAPE or event.keycode == KEY_B:
			close()
	elif event.is_action_pressed("ui_cancel"):
		close()
