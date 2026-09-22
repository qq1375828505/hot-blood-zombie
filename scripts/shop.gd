extends CanvasLayer
# 黑市商店 UI — V1.2 模块1
# 两层菜单：左侧分类（弹药/装备/食物/技能书），右侧商品行（名称+价格+购买按钮）。
# 打开时暂停游戏（get_tree().paused=true），本节点 process_mode=ALWAYS 保证暂停下仍可点按。
# 移动端友好：全部使用 Button，触屏可点；B 键或“关闭”按钮退出。

var current_category: String = "ammo"
var selected_item: String = ""

@onready var category_list: VBoxContainer = $Panel/CategoryList
@onready var item_list: VBoxContainer = $Panel/ItemList
@onready var coins_label: Label = $Panel/CoinsLabel
@onready var desc_label: Label = $Panel/DescLabel
@onready var close_button: Button = $Panel/CloseButton

var _category_buttons: Dictionary = {}  # category -> Button

# 分类中文名
const CATEGORY_NAMES := {
	"ammo": "弹药",
	"gear": "装备",
	"food": "食物",
	"skill": "技能书",
}


func _ready() -> void:
	# 连接金币变化
	if not Economy.coins_changed.is_connected(_update_coins):
		Economy.coins_changed.connect(_update_coins)
	_build_category_buttons()
	_refresh_items()
	_update_coins(Economy.coins)
	close_button.pressed.connect(close)
	visible = false


# ---- 构建左侧分类按钮 ----
func _build_category_buttons() -> void:
	for cat in Economy.get_categories():
		var btn := Button.new()
		btn.text = CATEGORY_NAMES.get(cat, cat)
		btn.add_theme_font_size_override("font_size", 18)
		btn.custom_minimum_size = Vector2(180, 44)
		var c: String = cat
		btn.pressed.connect(func() -> void: _on_category_selected(c))
		category_list.add_child(btn)
		_category_buttons[c] = btn
	_refresh_category_highlight()


func _on_category_selected(cat: String) -> void:
	current_category = cat
	selected_item = ""
	desc_label.text = "选择分类查看商品"
	_refresh_items()
	_refresh_category_highlight()


func _refresh_category_highlight() -> void:
	for cat in _category_buttons.keys():
		var b: Button = _category_buttons[cat]
		if cat == current_category:
			b.modulate = Color(1.0, 0.85, 0.2, 1.0)   # 选中高亮黄色
		else:
			b.modulate = Color(0.85, 0.85, 0.85, 1.0)


# ---- 构建右侧商品行 ----
func _refresh_items() -> void:
	# 清空旧行
	for child in item_list.get_children():
		child.queue_free()
	var item_ids: Array = Economy.get_items_by_category(current_category)
	if item_ids.is_empty():
		var empty := Label.new()
		empty.text = "（暂无商品）"
		empty.add_theme_color_override("font_color", Color(0.6, 0.6, 0.6, 1))
		item_list.add_child(empty)
		return
	for item_id in item_ids:
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 12)
		var item: Dictionary = Economy.get_item(item_id)
		# 商品名（宽一点）
		var name_lbl := Label.new()
		name_lbl.text = "· " + str(item.get("name", item_id))
		name_lbl.custom_minimum_size = Vector2(320, 40)
		name_lbl.add_theme_font_size_override("font_size", 18)
		name_lbl.add_theme_color_override("font_color", Color(0.95, 0.95, 0.95, 1))
		# 价格
		var price_lbl := Label.new()
		price_lbl.text = "%d 金" % int(item.get("price", 0))
		price_lbl.custom_minimum_size = Vector2(110, 40)
		price_lbl.add_theme_font_size_override("font_size", 18)
		price_lbl.add_theme_color_override("font_color", Color(1.0, 0.78, 0.25, 1))
		# 已拥有的技能书标记
		var owned: bool = current_category == "skill" and Economy.purchased_skills.has(item_id)
		# 购买按钮
		var buy_btn := Button.new()
		buy_btn.text = "已拥有" if owned else "购买"
		buy_btn.disabled = owned
		buy_btn.custom_minimum_size = Vector2(120, 40)
		buy_btn.add_theme_font_size_override("font_size", 18)
		var id: String = item_id
		buy_btn.pressed.connect(func() -> void: _on_buy(id))
		row.add_child(name_lbl)
		row.add_child(price_lbl)
		row.add_child(buy_btn)
		item_list.add_child(row)


# ---- 购买 ----
func _on_buy(item_id: String) -> void:
	var item: Dictionary = Economy.get_item(item_id)
	selected_item = item_id
	var player := _get_player()
	if player == null:
		desc_label.text = "找不到玩家，无法购买"
		return
	if Economy.buy_item(item_id, player):
		desc_label.text = "购买成功！%s" % str(item.get("desc", ""))
		_update_coins(Economy.coins)
		_refresh_items()
	else:
		desc_label.text = "金币不足或已拥有：%s" % str(item.get("desc", ""))


# ---- 取收货玩家：优先最近的存活玩家，否则首个玩家 ----
func _get_player() -> Player:
	var players: Array = get_tree().get_nodes_in_group("players")
	var alive: Player = null
	for p in players:
		if p is Player and not p.dead and not p.is_queued_for_deletion():
			alive = p
			break
	if alive != null:
		return alive
	for p in players:
		if p is Player:
			return p
	return null


# ---- 金币显示 ----
func _update_coins(amount: int) -> void:
	coins_label.text = "金币: %d" % amount


# ---- 打开 / 关闭 ----
func open() -> void:
	visible = true
	Economy.shop_open = true
	get_tree().paused = true
	_update_coins(Economy.coins)
	_refresh_items()


func close() -> void:
	visible = false
	Economy.shop_open = false
	get_tree().paused = false


func _unhandled_input(event: InputEvent) -> void:
	if not visible:
		return
	# B 键或重开键关闭商店
	if event.is_action_pressed("restart"):
		close()
		return
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_B:
			close()
