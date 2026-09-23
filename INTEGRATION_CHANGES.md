# 丧尸版特色玩法整合变更清单

> 整合时间：2026-09-23
> 工程路径：`/home/user/Doubao/chats/38443725384655106/hot-blood-zombie/`
> 基准：Unity PC 丧尸版（已改好的 asset bundle）→ Godot 安卓工程

---

## 一、敌人贴图丧尸化

### 处理方式：Pillow 滤镜（备选方案）

Unity bundle 提取方案因以下原因未采用：Godot 帧图为 21×34 像素的微幅切片（共 784 张），而 Unity bundle 内为纹理图集，逐帧匹配切片坐标复杂度高、风险大。改用 Pillow 程序化滤镜，效果稳定可复现。

### 滤镜效果

| 效果 | 实现 |
|------|------|
| 肤色→灰绿色 | 检测暖色肤色像素（R>G>B、中等亮度），R 通道降至 52%、G 降至 78%、B 降至 68%，整体偏冷绿 |
| 暗红色血迹 | 每帧随机 2~5 个血斑，半径 1~2px，暗红 RGB(90~130, 8~22, 8~18)，半透明叠加 |
| Alpha 通道 | 完全保持不变（全量 784 张验证通过） |
| 帧图尺寸 | 完全保持不变 |

### 处理数量

| 目录 | 文件数 | 处理结果 | 身体像素变色比例 |
|------|--------|----------|-----------------|
| `onizuka/`（鬼冢） | 287 | PASS | 56.3%（暴露皮肤最多） |
| `sugata/`（疾风） | 250 | PASS | 18.1% |
| `gouda/`（铁壁） | 247 | PASS | 16.3% |
| **合计** | **784** | **全部 PASS** | **31.6%** |

### 备份位置

原始帧图已备份至：`assets/characters/_original_backup/{onizuka,sugata,gouda}/`

---

## 二、战斗数值变更（combat_config.gd）

### 修改规则（对齐 Unity 丧尸版）

- **HP × 2.5**
- **walk_speed × 0.5**
- **chase_speed × 0.5**

### 变更前后对比

| 敌人类型 | 参数 | 修改前 | 修改后 | 倍率 |
|----------|------|--------|--------|------|
| **zombie_normal** | max_hp | 40.0 | 100.0 | ×2.5 |
| | walk_speed | 60.0 | 30.0 | ×0.5 |
| | chase_speed | 90.0 | 45.0 | ×0.5 |
| **zombie_fast** | max_hp | 120.0 | 300.0 | ×2.5 |
| | walk_speed | 150.0 | 75.0 | ×0.5 |
| | chase_speed | 200.0 | 100.0 | ×0.5 |
| **zombie_heavy** | max_hp | 550.0 | 1375.0 | ×2.5 |
| | walk_speed | 45.0 | 22.5 | ×0.5 |
| | chase_speed | 55.0 | 27.5 | ×0.5 |

### 未修改的部分

- ✅ 玩家属性（PLAYER）：未动
- ✅ 攻击参数（ATTACKS）：未动
- ✅ 波次配置（WAVES）：未动
- ✅ 打击手感（FEEL）：未动
- ✅ 场景边界（WORLD）：未动
- ✅ 敌人其他属性（attack_range, attack_damage, stagger_resist 等）：未动

### 注释更新

- ENEMIES 区块头注释新增：`丧尸化修改（对齐 Unity PC 丧尸版）：HP ×2.5，walk/chase 速度 ×0.5`
- 每个数值行注释标注：`逆向中位XXX ×2.5（丧尸化：HP提升）` / `逆向 XXX ×0.5（丧尸化：速度减半）`

---

## 三、配置检查结果

| # | 检查项 | 文件 | 要求 | 实际 | 结果 |
|---|--------|------|------|------|------|
| 1 | 横屏方向 | `project.godot` | `window/handheld/orientation=1` | 第30行：`window/handheld/orientation=1` | **PASS** |
| 1 | 视口宽度 | `project.godot` | `window/size/viewport_width=1280` | 第28行：`window/size/viewport_width=1280` | **PASS** |
| 1 | 视口高度 | `project.godot` | `window/size/viewport_height=720` | 第29行：`window/size/viewport_height=720` | **PASS** |
| 2 | 导出方向 | `export_presets.cfg` | `screen/orientation=1` | 第35行：`screen/orientation=1` | **PASS** |
| 2 | 横屏导出 | `export_presets.cfg` | `screen/orientations/landscape=true` | 第36行：`screen/orientations/landscape=true` | **PASS** |
| 3 | 战斗场景 | `scenes/main.tscn` | 含 Player + EnemySpawner + HUD + TouchControls | 第51行 Player、第54行 EnemySpawner、第57行 HUD、第123行 TouchControls（直接在场景中） | **PASS** |
| 4 | 强制显示虚拟键 | `scripts/touch_controls.gd` | `_ready()` 中 `visible=true`，不做设备检测 | 第39行：`visible = true`，注释明确"不做设备检测" | **PASS** |
| 5 | 触控 action 对齐 | `scripts/input_setup.gd` | punch/kick/weapon/jump 已注册 | 第13行 jump、第14行 punch、第15行 kick、第16行 weapon | **PASS** |

**配置检查总计：8/8 PASS，无需修正。**

---

## 四、产出物清单

| 产出物 | 位置 |
|--------|------|
| 丧尸化敌人帧图 | `assets/characters/onizuka/`（287张） |
| | `assets/characters/sugata/`（250张） |
| | `assets/characters/gouda/`（247张） |
| 原始帧图备份 | `assets/characters/_original_backup/` |
| 更新的战斗数值 | `scripts/combat_config.gd` |
| 本变更清单 | `INTEGRATION_CHANGES.md` |
