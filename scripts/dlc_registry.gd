class_name DlcRegistry
extends RefCounted
# V2.0 DLC 内容注册表（数据驱动）：支持后续 DLC 追加武器/角色/敌人/关卡而不改核心脚本。
# 所有内容以 Dictionary/Array 存储，通过 register_dlc() 注册，enable_dlc() 控制启用。
# 设计意图：核心脚本只依赖 DlcRegistry 统一接口取数，DLC 内容以纯数据形式注入，零侵入。

# ---- 静态存储 ----
# dlc_id -> {name:String, version:String, enabled:bool,
#            contents:{weapons:Array, characters:Array, enemies:Array, levels:Array}}
static var _dlcs: Dictionary = {}

# 已注册的 DLC 武器合并表（cache）：weapon_name -> def
# 在 register_dlc / enable_dlc 时重建，仅包含当前已启用 DLC 的武器
static var _weapon_overrides: Dictionary = {}


# 注册一个 DLC。info 含 name/version/contents。若已存在则覆盖（打印提示）。
# contents 示例：{"weapons": [...], "characters": [...], "enemies": [...], "levels": [...]}
static func register_dlc(dlc_id: String, info: Dictionary) -> void:
	if _dlcs.has(dlc_id):
		print("DlcRegistry: 覆盖已存在的 DLC [", dlc_id, "]")
	var contents: Dictionary = info.get("contents", {})
	# 补全 contents 默认结构，避免空指针
	for cat in ["weapons", "characters", "enemies", "levels"]:
		if not contents.has(cat):
			contents[cat] = []
	_dlcs[dlc_id] = {
		"name": info.get("name", dlc_id),
		"version": info.get("version", "0.0.0"),
		"enabled": info.get("enabled", false),
		"contents": contents,
	}
	_rebuild_weapon_overrides()


# 是否存在指定 DLC
static func has_dlc(dlc_id: String) -> bool:
	return _dlcs.has(dlc_id)


# 返回 DLC 信息字典，不存在返回 {}
static func dlc_id(dlc_id: String) -> Dictionary:
	return _dlcs.get(dlc_id, {})


# 返回全部已注册 DLC id 数组
static func get_all_dlc_ids() -> Array:
	return _dlcs.keys()


# 返回指定 DLC 指定类别的条目列表
# category: "weapons" / "characters" / "enemies" / "levels"
static func get_contents(dlc_id: String, category: String) -> Array:
	var info: Dictionary = _dlcs.get(dlc_id, {})
	var contents: Dictionary = info.get("contents", {})
	return contents.get(category, [])


# 返回基础武器表 + 所有已启用 DLC 武器的合并表
# DLC 武器格式兼容两种：{name, def} 或直接 {name: def}
static func get_all_weapons() -> Dictionary:
	var merged: Dictionary = Weapons.WEAPONS.duplicate(true)
	# _weapon_overrides 已是当前已启用 DLC 武器的合并结果
	for w_name in _weapon_overrides:
		merged[w_name] = _weapon_overrides[w_name]
	return merged


# 返回所有已启用 DLC 追加的角色列表（基础角色此处为空，后续可扩展从基础配置读取）
static func get_all_characters() -> Array:
	return _collect_enabled_contents("characters")


# 返回所有已启用 DLC 追加的敌人列表
static func get_all_enemies() -> Array:
	return _collect_enabled_contents("enemies")


# 返回所有已启用 DLC 追加的关卡列表
static func get_all_levels() -> Array:
	return _collect_enabled_contents("levels")


# 启用/禁用 DLC（影响 get_all_* 合并结果）
static func enable_dlc(dlc_id: String, enabled: bool) -> void:
	if not _dlcs.has(dlc_id):
		return
	_dlcs[dlc_id]["enabled"] = enabled
	_rebuild_weapon_overrides()


# 是否启用了指定 DLC
static func is_dlc_enabled(dlc_id: String) -> bool:
	var info: Dictionary = _dlcs.get(dlc_id, {})
	return bool(info.get("enabled", false))


# ---- 内部辅助 ----

# 汇总所有已启用 DLC 的某类别条目
static func _collect_enabled_contents(category: String) -> Array:
	var result: Array = []
	for dlc_id in _dlcs:
		if not is_dlc_enabled(dlc_id):
			continue
		for item in get_contents(dlc_id, category):
			result.append(item)
	return result


# 从 DLC contents.weapons 条目中提取武器名与定义
# 支持格式一：{"name": "xxx", "def": {...}}
# 支持格式二：{"xxx": {...}}
static func _extract_weapon_entry(entry: Dictionary) -> Dictionary:
	var result := {}
	if entry.has("name") and entry.has("def"):
		# 格式一
		result["name"] = str(entry["name"])
		result["def"] = entry["def"]
	else:
		# 格式二：取第一个键值对
		for k in entry:
			result["name"] = str(k)
			result["def"] = entry[k]
			break
	return result


# 重建 _weapon_overrides：遍历所有已启用 DLC，合并其 weapons 条目
static func _rebuild_weapon_overrides() -> void:
	_weapon_overrides.clear()
	for dlc_id in _dlcs:
		if not is_dlc_enabled(dlc_id):
			continue
		var weapons: Array = get_contents(dlc_id, "weapons")
		for entry in weapons:
			if not (entry is Dictionary):
				continue
			var parsed: Dictionary = _extract_weapon_entry(entry)
			if not parsed.is_empty():
				_weapon_overrides[parsed["name"]] = parsed["def"]
