# 《River City Rival Showdown》PC 丧尸版改造说明

> 改造日期：2026-09-23
> 游戏：River City Rival Showdown（热血物语 リバーシティライバルステステメント）
> 版本：PC Steam 版（StandaloneWindows64）

---

## 一、概述

### 改造目标
将开放世界清版动作游戏《River City Rival Showdown》改造为 **「末日丧尸」主题 Mod**，核心体验方向：

- **敌人血厚耐打**（HP ×2.5）
- **敌人行动迟缓**（移动速度 ×0.5）
- **丧尸潮式刷怪**（单屏存活数量 ×2、后备 stock ×1.5、难度人数区间扩大）
- **视觉丧尸化**（敌人贴图改为灰绿皮肤 + 暗红血迹 + 破损衣服 + 整体压暗）
- **标题UI焕新**（简体中文菜单标题改为「热血物语：末日丧尸」）

### 设计原则
- 主角（国夫 Kunio / 阿力 Riki）的数值与贴图**完全不动**
- 剧情 Boss / 队友角色为避免破坏主线节奏，保持原样
- 只修改**开放世界杂兵**（校名_序号 命名的街头敌人）
- 所有修改只改**数值**，不改表结构、字段名、数据类型
- 不修改 `Assembly-CSharp.dll`（逻辑代码无需改动）

---

## 二、修改文件清单

### 被替换的 4 个 Bundle 文件

| # | 文件名 | 修改内容 | 原文件路径 | 备份位置 |
|---|---|---|---|---|
| 1 | `nk21_data_assets_all.bundle` | 游戏数值表（HP/速度/刷怪量/人数区间） | `River City Rival Showdown_Data/StreamingAssets/aa/StandaloneWindows64/nk21_data_assets_all.bundle` | `_backup/nk21_data_assets_all.bundle` |
| 2 | `nk21_charasprite_assets_all.bundle` | 角色大图集（敌人 sprite 丧尸化，主角保留） | `River City Rival Showdown_Data/StreamingAssets/aa/StandaloneWindows64/nk21_charasprite_assets_all.bundle` | `_backup/nk21_charasprite_assets_all.bundle` |
| 3 | `nk21_chara_npc_assets_all.bundle` | NPC 图集（7 个 NPC sprite 丧尸化） | `River City Rival Showdown_Data/StreamingAssets/aa/StandaloneWindows64/nk21_chara_npc_assets_all.bundle` | `_backup/nk21_chara_npc_assets_all.bundle` |
| 4 | `nk21_event_assets_ttr_menu_sc.bundle` | 简体中文菜单图（叠加新标题文字） | `River City Rival Showdown_Data/StreamingAssets/aa/StandaloneWindows64/nk21_event_assets_ttr_menu_sc.bundle` | `_backup/nk21_event_assets_ttr_menu_sc.bundle` |

### 文件大小变化

| 文件名 | 原始大小 | 修改后大小 | 说明 |
|---|---|---|---|
| nk21_data_assets_all.bundle | 156,414 B | 1,190,523 B | UnityPy 写出未压缩，体积增大属正常 |
| nk21_charasprite_assets_all.bundle | 880,043 B | 34,499,257 B | 纹理改为未压缩 RGBA32 |
| nk21_chara_npc_assets_all.bundle | 8,505 B | 153,553 B | NPC 图集未压缩写出 |
| nk21_event_assets_ttr_menu_sc.bundle | 248,606 B | 5,326,089 B | 菜单图未压缩写出 |

---

## 三、游戏数值修改

### 3.1 mstActorParamater（角色参数表，287 行）

这是核心数值表，定义了所有角色的 HP、速度、攻击力等属性。

**修改规则：**
- 对 **203 个开放世界杂兵**（`eenumcharacterid` 对应校名_序号命名的敌人）：
  - **HP = round(HP × 2.5)**
  - **speed = max(1, round(speed × 0.5))**
- 主角（Kunio / Riki，含所有变体）和剧情 Boss **完全不改**

**修改统计：**
- HP 字段修改：203 处
- speed 字段修改：203 处
- 总字段变更：406 处

**修改示例：**

| 敌人 | eid | HP 原值 | HP 新值 | speed 原值 | speed 新值 |
|---|---|---|---|---|---|
| Sakajuku_00 | 26 | 24 | 60 | 4 | 2 |
| Senridai_00 | 35 | 73 | 183 | 7 | 4 |
| Reihou_00 | 101 | 270 | 675 | 9 | 4 |

**未修改字段：** punch / kick / weapon / throwing / tough / luck / resdown / resstun / resbreak / critical 等全部保持原值——保证「丧尸打得疼但走得慢」的体验。

### 3.2 mstGroupParamater（按天覆写表，2417 行）

该表对同一敌人按 `day`（游戏天数）给出属性覆写值（day=0 表示沿用 mstActorParamater）。

**修改规则：**
- 对属于 204 个杂兵、且 `day != 100`、且值 > 0 的行：
  - **hp × 2.5**（115 处）
  - **speed × 0.5**（119 处）
- **跳过 day = 100 的行**：这些是 FoDD（Forever of Double Dragon）/ 线上对战模式的独立数值，含 -5 等哨兵值，修改会破坏该模式平衡
- 负的哨兵值（如 -5）一律不碰

**修改统计：** 总字段变更 234 处（hp 115 + speed 119）

### 3.3 mstEnemyPop（刷怪生成器表，154 行）

只改 `stock > 0` 或 `activeamount > 0` 的生成器（其余行沿用默认值）：

| 生成器 ID | stock 原→新 | activeamount 原→新 |
|---|---|---|
| STAGE01_GEN_01 | 30 → 45 | 5 → 10 |
| S001_GEN_MAIN_E071 | 100 → 150 | 10 → 20 |
| S067_GEN_RIKI_E587 | 100 → 150 | 10 → 20 |
| S009_GEN_MAIN_E033 | 20 → 30 | 6 → 12 |
| S009_GEN_MAIN_E035 | 20 → 30 | 6 → 12 |

- stock × 1.5（后备数量增加）
- activeamount × 2.0（单屏同时存活数量翻倍）
- delay / refilldelay 不改（避免刷新逻辑异常）

### 3.4 mstMobEnemyValue（难度人数分布表，11 行）

该表按杂兵强度档（mobenemyvalue）给出各难度刷出人数区间。

**修改规则：**
- `easymin / normalmin / hardmin / veryhardmin` × 1.3
- `*max`（各难度上限）× 1.5

**修改统计：** 总字段变更 73 处

**示例：** no=2, value=1 时：normalmax 1→2、hardmax 2→3、veryhardmin 2→3、veryhardmax 3→4。

### 3.5 其他表（经检查不修改）

| 表名 | 不修改原因 |
|---|---|
| mstAIActSet / mstAIInputSet | 只存动作/输入 ID（PUNCH/KICK/JUMP/GUARD…），无速度/反应时间数值字段，无法通过改表实现「反应变慢」 |
| mstEnemyPopPosition | 只有坐标 posx/y/z，无数量/间隔字段 |
| mstBonusEnemyData | 只有奖励敌人的出场舞台/时段/坐标，无属性字段 |
| mstPlayerInitialData | 主角初始装备/金钱，按约束不动 |
| mstSystemDefine | 16 行匿名 int/float 配置，含义不确定，不瞎改 |
| mstNpcManage / mstEventBattleGroup | NPC 与剧情战斗配置，含大量剧情敌我混合，不动 |

---

## 四、贴图修改

### 4.1 修改效果（丧尸风格）

对敌人 sprite 区域内的可见像素（alpha > 10）应用以下效果：

1. **灰绿皮肤**：检测肤色像素（R>G+8 且 R>B+15），将 R 压向 40、G 抬至 55、B 抬至 50，呈现灰绿色
2. **整体降饱和 + 偏绿**：所有可见像素向灰色靠拢，G 通道 +8，呈死灰绿色
3. **整体变暗 15%**（×0.85）
4. **暗红血迹**：随机在角色身上撒半透明暗红斑点（RGB 60-110, 5-25, 5-25）
5. **破损线条**：随机在衣服区域画深色（RGB 20,15,15）短横线

### 4.2 修改的 Sprite 数量

**nk21_charasprite_assets_all.bundle（角色大图集）：**
- 图集尺寸：2048 × 2048，Texture2D format = 4（RGBA32）
- 总 Sprite 数量：1163 个
- **敌人 sprite：1120 个**（28 个角色分组，已丧尸化）
- **主角 sprite：43 个**（charaid=9，编号 900~942，完全保留未动，像素差 = 0）

按 charaid 分组修改明细：

| charaid 组 | sprite 编号范围 | 数量 | 状态 |
|---|---|---|---|
| 0 | 0~26 | 27 | 丧尸化 |
| 1 | 100~117 | 18 | 丧尸化 |
| 2 | 200~233 | 34 | 丧尸化 |
| 3 | 300~328 | 29 | 丧尸化 |
| 4 | 400~435 | 36 | 丧尸化 |
| 5 | 500~518 | 19 | 丧尸化 |
| 6 | 600~660 | 61 | 丧尸化 |
| 7 | 700~766 | 57 | 丧尸化 |
| 8 | 800~853 | 54 | 丧尸化 |
| **9** | **900~942** | **43** | **【主角·保留】** |
| 10 | 1000~1033 | 30 | 丧尸化 |
| 11 | 1100~1143 | 44 | 丧尸化 |
| 12 | 1200~1228 | 28 | 丧尸化 |
| 13 | 1300~1371 | 59 | 丧尸化 |
| 14 | 1401~1479 | 79 | 丧尸化 |
| 16 | 1600~1674 | 75 | 丧尸化 |
| 18 | 1800~1828 | 29 | 丧尸化 |
| 20 | 2000~2049 | 50 | 丧尸化 |
| 30 | 3000~3018 | 19 | 丧尸化 |
| 31 | 3100~3148 | 49 | 丧尸化 |
| 40 | 4000~4022 | 23 | 丧尸化 |
| 41 | 4100~4199 | 100 | 丧尸化 |
| 42 | 4200~4299 | 100 | 丧尸化 |
| 43 | 4300~4349 | 50 | 丧尸化 |
| 61 | 6172~6177 | 6 | 丧尸化 |
| 62 | 6294~6297 | 4 | 丧尸化 |
| 80 | 8000~8021 | 22 | 丧尸化 |
| 90 | 9004~9006 | 3 | 丧尸化 |
| 95 | 9500~9513 | 14 | 丧尸化 |

**nk21_chara_npc_assets_all.bundle（NPC 图集）：**
- 图集尺寸：128 × 128（hiroshi_Atlas）
- 7 个 NPC sprite（编号 000, 001, 002, 003, 026, 106, 107）已丧尸化

### 4.3 主角保留情况

- **国夫（Kunio）**：charaid = 9，sprite 编号 900~942（共 43 个），像素差 = 0，完全未修改
- **阿力（Riki）**：数值与贴图均未修改（数据层面 Riki 行在 mstActorParamater 中同样保留原值）
- 主角判定依据：`mstPlayerInitialData` 表中玩家角色名为 `9_cha_n_knio`（knio = kunio = 国夫）

---

## 五、标题 UI 修改

### 5.1 修改内容

在 `nk21_event_assets_ttr_menu_sc.bundle`（简体中文菜单教程图）的 **9 张菜单图**顶部叠加新标题：

- **标题文字**：「热血物语：末日丧尸」
- **字体**：Noto Sans CJK Black 粗体
- **颜色**：红色带阴影
- **衬底**：半透明深色横幅

### 5.2 修改位置说明

- 修改的是 `nk21_event_assets_ttr_menu_sc.bundle` 中的 9 张 1024×576 简体中文菜单教程画面
- 这些画面是游戏内的新手教学（Tutorial）截图，非游戏启动主标题
- **游戏主标题 Logo** 位于 `level0` 场景文件（SceneStartLogo / SceneTenchiTitle）中，属于 Unity 场景资产，不在 Addressables bundle 范围内，本次未直接修改

### 5.3 未修改的 UI Bundle

| Bundle | 检查结果 |
|---|---|
| nk21_ui_assets_all.bundle | 29 个 Texture2D + 734 个 Sprite，均为血条/地图/图标等 UI 组件，未发现独立游戏标题 logo；247 个 MonoBehaviour 的 m_Text 均为日文 UI 标签，无游戏标题文本。**未修改** |
| nk21_event_assets_ttr_00.bundle / 各语言 ttr_menu | 均为教程画面，非主标题。**未修改** |
| sp_ui_assets_all.bundle / event_bg.bundle | 分别为 restart 纹理与淡入淡出背景。**未修改** |

---

## 六、未修改项说明

### 6.1 Assembly-CSharp.dll 未修改

- **原因**：所有敌人数值都在数据表 bundle（`nk21_data_assets_all.bundle`）中，DLL 只包含逻辑代码，不包含数值配置
- 经 strings 分析确认：`CActorParameter` 类读取的数据表结构不变，无需改动逻辑代码
- DLL 修改存在反编译/重编译风险，且本次需求纯数值/贴图层面，无此必要

### 6.2 主角未修改

- 国夫（Kunio）：`mstActorParamater` 中 `charanametableid = Kunio` 的所有行（含 eid 0/247/252 等 SP/FoDD 变体）全部保留原值
- 阿力（Riki）：同上，eid 13/828/829 等变体全部保留
- 主角贴图（sprite 900~942）像素差 = 0

### 6.3 AI 表无速度字段说明

- `mstAIActSet`（15 行）：只存动作 ID（action1~8）
- `mstAIInputSet`（8 行）：只存输入名（PUNCH/KICK/JUMP/GUARD/AI_SP_MOVE_1~4 等）
- 两张 AI 表**没有任何反应时间/移动速度的数值字段**
- 丧尸的「迟缓」感完全由 `mstActorParamater.speed × 0.5` 体现

### 6.4 FoDD / day=100 模式跳过说明

- `mstGroupParamater` 中 `day = 100` 的行对应 FoDD（Forever of Double Dragon）/ 线上对战模式的独立数值
- 该模式有自己的平衡体系，且部分行含 -5 等哨兵值
- 修改会破坏该模式平衡，故**全部跳过 day=100 的行**

---

## 七、安装与回退方法

### 安装方法（已自动完成）

本 Mod 已自动安装到位，4 个修改后的 bundle 文件已覆盖到游戏目录对应位置。无需额外操作。

### 回退方法

如需恢复原版：

1. 打开游戏根目录下的 `_backup/` 文件夹
2. 将其中的 4 个原始 bundle 文件复制回原位置（覆盖修改版）：

```
_backup/nk21_data_assets_all.bundle
  → River City Rival Showdown_Data/StreamingAssets/aa/StandaloneWindows64/

_backup/nk21_charasprite_assets_all.bundle
  → River City Rival Showdown_Data/StreamingAssets/aa/StandaloneWindows64/

_backup/nk21_chara_npc_assets_all.bundle
  → River City Rival Showdown_Data/StreamingAssets/aa/StandaloneWindows64/

_backup/nk21_event_assets_ttr_menu_sc.bundle
  → River City Rival Showdown_Data/StreamingAssets/aa/StandaloneWindows64/
```

3. 覆盖完成后即恢复为原版游戏

---

## 八、已知限制

1. **Linux 下无法运行验证**：本游戏为 Windows 可执行文件（.exe + UnityPlayer.dll），在 Linux 环境下无法直接启动。验证仅通过 UnityPy 文件级加载校验完成，未做实际运行测试。建议在 Windows 系统下启动游戏确认效果。

2. **主标题 Logo 未直接修改**：游戏启动时的主标题画面（SceneStartLogo / SceneTenchiTitle）位于 Unity 场景文件（level0）中，不在本次修改的 Addressables bundle 范围内。本次标题修改仅体现在简体中文教程菜单画面上叠加「热血物语：末日丧尸」文字。

3. **贴图效果为程序化生成**：丧尸风格效果（灰绿皮肤、血迹、破损线条）为程序化像素处理，非手绘美术修改。不同角色的效果一致性可能略有差异。

4. **文件体积增大**：由于 UnityPy 写出时默认不做 LZ4/LZMA 压缩，修改后的 bundle 文件体积比原版大（尤其 charasprite 图集从 ~880KB 增至 ~34MB）。Unity 可正常加载未压缩 bundle，不影响运行，但会占用更多磁盘空间和内存。

5. **多语言菜单未修改**：仅修改了简体中文（sc）菜单图。日文/英文/韩文/繁体中文的菜单图未叠加新标题文字。

6. **剧情角色未做丧尸化**：剧情 Boss、队友角色的贴图保持原样，仅开放世界杂兵做了丧尸化处理。

---

## 附录：技术验证记录

使用 UnityPy 1.25.3 对替换后的 4 个 bundle 进行加载校验，结果如下：

| Bundle | 校验项 | 结果 |
|---|---|---|
| nk21_data_assets_all.bundle | MonoBehaviour 数量 = 52 | ✓ 通过 |
| nk21_data_assets_all.bundle | mstActorParamater 表行数 = 287 | ✓ 通过 |
| nk21_charasprite_assets_all.bundle | Texture2D 尺寸 = 2048×2048 | ✓ 通过 |
| nk21_charasprite_assets_all.bundle | Texture2D format = 4 (RGBA32) | ✓ 通过 |
| nk21_charasprite_assets_all.bundle | Sprite 数量 = 1163 | ✓ 通过 |
| nk21_chara_npc_assets_all.bundle | 正常加载（12 个对象） | ✓ 通过 |
| nk21_event_assets_ttr_menu_sc.bundle | Texture2D 数量 = 9 | ✓ 通过 |
| River City Rival Showdown.exe | 未被修改 | ✓ 原始时间戳 |
| UnityPlayer.dll | 未被修改 | ✓ 原始时间戳 |

对比参考图：
- 大图集前后对比：`artifacts/atlas_before_after_comparison.png`
- 标题前后对比：`artifacts/title_before_after_comparison.png`
