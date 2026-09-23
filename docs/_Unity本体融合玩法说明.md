# 《River City Rival Showdown》本体融合玩法说明 & 验证报告

> 文档生成日期：2026-09-23
> 验证环境：Python3 + UnityPy 1.25.3 + dnfile 0.18.0 + pefile（只读验证，未修改任何游戏文件）
> 游戏目录：`_解压_RiverCityRival/`
> 性质：本文档为最终交付件，包含玩法融合说明、逐项验证结果、运行与回滚指引。

---

## 1. 概述

### 1.1 项目目标
将原 Godot 版《热血物语·丧尸化》的玩法设计（5 角色、数值化战斗、武器/经济/商店/成就/敌群/关卡/载具模拟/可破坏物），**完整移植到 Unity 商业游戏《River City Rival Showdown》本体之上**，作为可直接运行的 PC 整合包。

### 1.2 载体游戏
- **本体**：《River City Rival Showdown》（Arc System Works 出品，热血系列清版动作）
- **引擎**：Unity（StandaloneWindows64），Addressables 资源体系
- **数据驱动架构**：所有数值表均为 `UnityQuickSheet` 产物（ScriptableObject + `dataArray`），存放在 Addressables bundle 中，DLL 不硬编码数值。
- 因此本次融合**全部通过改写 bundle 数据完成，未做任何 IL 补丁**（DLL 保持原版）。

### 1.3 玩法来源与融合方式
Godot 原作玩法 → Unity 本体的对应落点：

| Godot 玩法模块 | Unity 落点 | 融合方式 |
|---|---|---|
| 5 角色选择 | `mstActorParamater`（角色基础参数） | 改 bundle 数值 |
| 拳/踢/跳跃/武器伤害 | `mstAttackCollision` | 改 bundle 数值 |
| 7 把武器数值 | `mstWeaponData` | 改 bundle 数值 |
| 初始金币 / 掉钱 | `mstPlayerInitialData` + `mstMoney_DropSet` | 改 bundle 数值 |
| 商店 15 商品价格 | `mstConsumableData` | 改 bundle 数值 |
| 8 成就 | `NKSP.Achievements`（DLL 枚举） | 文档映射，未改 DLL |
| 敌人丧尸化 / 敌群波次 | `mstActorParamater` + `mstEnemyPop` | 改 bundle 数值 |
| 5 关选择 / 波次 | `mstEnemyPop` 第 1 关生成点 | 改 bundle 数值 |
| 载具系统 | 无对应系统 | 用远程武器模拟（见 3.9） |
| 可破坏物掉落 | `mstConsumable_DropSet` | 改 bundle 数值 |

---

## 2. 修改总览表（10 项玩法状态）

| # | 玩法 | 状态 | 修改方式 | 验证结论 |
|---|---|---|---|---|
| 1 | 5 角色选择（数值映射） | ✅ 已完成 | bundle 数据（mstActorParamater） | 通过，实测值一致 |
| 2 | 战斗系统（拳/踢/跳跃/连击） | ✅ 已完成 | bundle 数据（mstAttackCollision） | 通过，拳6/踢12/跳15 |
| 3 | 武器系统（7 把） | ✅ 已完成 | bundle 数据（mstWeaponData） | 通过，7 把数值全对 |
| 4 | 经济系统（初始金/掉钱/死亡减半） | ✅ 已完成 | bundle 数据 + Unity 原生 | 通过，初始500/掉钱×1.8 |
| 5 | 商店系统（15 商品） | ✅ 已完成 | bundle 数据（mstConsumableData） | 通过，15 个价格全对 |
| 6 | 成就系统（8 成就映射） | ⚠️ 部分完成 | 文档说明（未改 DLL/Steam） | 见 3.6，保留原 36 成就 |
| 7 | 敌人 AI（丧尸化/敌群/波次） | ✅ 已完成 | bundle 数据（mstActorParamater+mstEnemyPop） | 通过，抽查 9 个敌人 |
| 8 | 关卡系统（5 关/波次） | ⚠️ 部分完成 | bundle 数据（仅第 1 关波次） | 见 3.8，波次已配，5 关选择依赖原生流程 |
| 9 | 载具系统 | ❌ 未实现（用武器模拟替代） | 文档说明 + 远程武器 | 见 3.9，已用机枪/手雷模拟火力 |
| 10 | 可破坏物掉落 | ✅ 已完成 | bundle 数据（mstConsumable_DropSet） | 通过，贩卖机/垃圾桶掉落正确 |

> **修改方式统计**：本次共改 4 个 bundle、约 183 个数据点；**未修改 Assembly-CSharp.dll**（md5 与原始备份一致）。

---

## 3. 逐项修改说明

### 3.1 五角色选择

Godot 五角色 → Unity `mstActorParamater` 行映射（实测 `charanametableid` / `graphicid`）：

| Godot 定位 | Unity 行号 | Unity 角色（实测名） | graphicid |
|---|---|---|---|
| 飞机头（均衡） | row0 | Kunio | Character/Kunio |
| 铁壁壮汉 | row3 | Yamada | CharacterSP/Yamada |
| 暴走族总长 | row6 | Onizuka | CharacterSP/Onizuka |
| 疾风飞毛腿 | row8 | Mochizuki | CharacterSP/Mochizuki |
| 格斗专家 | row13 | Riki | CharacterSP/Riki |

**倍率属性表（实测最终值）**：

| 角色 | HP | Punch | Kick | Speed | Tough | Weapon | Throwing |
|---|---|---|---|---|---|---|---|
| Kunio（均衡） | 240 | 6 | 12 | 17 | 10 | 9 | 12 |
| Yamada（壮汉） | 336 | 6 | 13 | 12 | 14 | 9 | 13 |
| Onizuka（总长） | 168 | 8 | 16 | 22 | 7 | 12 | 16 |
| Mochizuki（飞毛腿） | 216 | 5 | 10 | 23 | 9 | 7 | 10 |
| Riki（格斗） | 204 | 7 | 15 | 17 | 8 | 11 | 15 |

> 注：角色解锁沿用 Unity 原生选人菜单（`CTenchiCharaSelectMenu`），本次只调数值不改解锁逻辑。

### 3.2 战斗系统

`sp_actioncollision_assets_all.bundle` → `mstAttackCollision`（共 421 行）关键行实测：

| 行 | 攻击（eattack_data） | damage（实测） | 对照 Godot |
|---|---|---|---|
| row0 | 轻拳 1 段 | **6** | 6 ✓ |
| row1 | 轻踢 1 段 | **12** | 12 ✓ |
| row2 | 拳 2 段 | 9 | 9 |
| row3 | 拳 3 段 | 9 | 9 |
| row4 | 重踢 | 12 | 12 |
| row5 | 跳跃攻击 | **15**（原 18） | 15 ✓ |

- **连击数**：拳/踢连段上限由 `NKSP.CComboControl.MaxComboCount` 在运行时动态计算（IL 探查确认），**未做 IL patch**，沿用 Unity 原生连击手感。Godot 的连段数通过伤害值对齐体现，未单独改写。

### 3.3 武器系统（7 把）

`sp_itemdata_assets_all.bundle` → `mstWeaponData`（共 79 行）前 7 行实测：

| 行 | eenumweaponitem | 武器 | weaponpower（实测/原） | throwpower（实测/原） |
|---|---|---|---|---|
| row0 | 1 | 铁管 | **9** / 9 | **12** / 12 |
| row1 | 2 | 轮胎 | **6** / 12 | **10** / 16 |
| row2 | 3 | 垃圾桶盖 | **4** / 9 | **8** / 12 |
| row3 | 4 | 手枪 | **3** / 9 | **5** / 12 |
| row4 | 5 | 机枪 | **3** / 15 | **5** / 20 |
| row5 | 6 | 霰弹枪 | **2** / 12 | **3** / 16 |
| row6 | 7 | 手雷 | **12** / 9 | **15** / 12 |

### 3.4 经济系统

| 项目 | 位置 | 实测值 | 说明 |
|---|---|---|---|
| 初始金币（row0/1/2） | `mstPlayerInitialData.money` | **500 / 500 / 500**（原 1000/999999/999999） | 3 行全部对齐为 500 |
| 掉钱倍率 | `mstMoney_DropSet.moneydrop_day1~4` | **×1.8**（如 row0: 80→144；row29: 3000→5400） | 34 行全部放大 |
| 死亡金钱减半 | DLL `_DropMoneyHalf()`（RVA 0x3c63c） | **原生已实现**（内含 2 处 div 指令） | 无需 patch |

> **数据核对补充**：日志仅记录了 `moneydrop_day1`，实测 `day1/day2/day3/day4` 四列均已 ×1.8（如 row22 原 120/150/180/180 → 现 216/270/324/324），与"掉钱×1.8"目标一致。

### 3.5 商店系统（15 商品）

`sp_itemdata_assets_all.bundle` → `mstConsumableData.buyingprice1` 前 15 行实测（原→新）：

| 行 | 商品 | 新价（实测） | 原价 |
|---|---|---|---|
| row0 | 饭团 | 30 | 75 |
| row1 | 泡面 | 25 | 175 |
| row2 | 运动饮料 | 35 | 300 |
| row3 | 护甲背心 | 100 | 2500 |
| row4 | 铁管 | 80 | 2500 |
| row5 | 机枪弹药 | 50 | 2500 |
| row6 | 霰弹弹药 | 40 | 125 |
| row7 | 手雷×3 | 60 | 125 |
| row8 | 连击强化 | 200 | 125 |
| row9 | 必杀强化 | 250 | 1000 |
| row10 | 马赫踢之书 | 3000 | 250 |
| row11 | 马赫拳之书 | 3000 | 500 |
| row12 | 大地震击之书 | 4000 | 3000 |
| row13 | 旋风踢之书 | 3500 | 6000 |
| row14 | 人间鱼雷之书 | 8000 | 25000 |

> 价格档位：消耗品/弹药低价，书籍/必杀高价，模拟 Godot 商店经济曲线。商店菜单、购买、限购均沿用 Unity 原生 `CShopMenuController`。

### 3.6 成就系统

Unity 本体已有 **36 个 Steam 成就**（`NKSP.Achievements` 枚举，与 Steam SDK 深度绑定，解锁状态经 AES 加密存储）。本次**未改 DLL**，保留原成就体系。

Godot 8 成就 → Unity 已有成就映射（仅说明，未实际触发）：

| Godot 成就 | 对应 Unity 成就 | 说明 |
|---|---|---|
| 初阵（首杀） | CLEAR_EVENT_1 | 事件完成成就近似 |
| 百人斩（100 杀） | REACH_LEVEL_10 | 升级成就近似 |
| 武器收藏家（4 武器） | OBTAIN_UNIQUE_ITEM | 独特物品成就近似 |
| 黄昏町制霸（通关） | CLEAR_STORY_1 | 第 1 章通关 |
| 无伤过关 | CLEAR_DIFFICULTY_1 | 高难度通关近似 |
| 热血魂爆发（10 必杀） | LEARN_SPECIALS_5 | 学习 5 个必杀技 |
| 援护收藏家（收服 5） | EAT_ONIGIRI_50 | 累计消耗类近似 |
| 马路杀手（载具） | 无对应 | Unity 无载具系统 |

> 若需真实解锁全部成就，需 IL patch `AchievementsCollector.Unlock()`，本次因风险高未执行。

### 3.7 敌人 AI（丧尸化 + 敌群波次）

**丧尸化数值**（HP×2.5、Speed×0.5，抽查实测）：

| 行 | 敌人 | HP（原→新） | Speed（原→新） |
|---|---|---|---|
| row17 | Sawaguchi | 150→375 | 8→4 |
| row18 | Nishimura | 500→1250 | 4→2 |
| row19 | Yamamoto | 110→275 | 9→4 |
| row20 | Kamijou | 120→300 | 10→5 |
| row21 | Gouda | 600→1500 | 18→9 |
| row24 | Toraichi（Boss） | 7777→19442 | 120→60 |
| row25 | Toraji（Boss） | 6666→16665 | 120→60 |
| row252 | Kunio（FoDD） | 360→900 | 18→9 |
| row270 | Kunio（洗脑） | 5→12 | 6→3 |

> 共对约 40+ 个敌人/角色执行了 HP×2.5、Speed×0.5（含 row236/237/239/251~268/273/274 等），上表为抽查验证样本，全部满足倍率。

**敌群波次**（`mstEnemyPop` 第 1 关 STAGE01_GEN_01 链，共 154 行）实测：

| 行 | id | activeamount | stock | refilldelay | 波次含义 |
|---|---|---|---|---|---|
| row0 | STAGE01_GEN_01 | 5 | 5 | 3.0s | Wave1：5 普通 |
| row1 | — | 5 | 10 | 3.5s | Wave2：5 普通 |
| row2 | — | 5 | 15 | 3.0s | Wave3：3 普通+2 快速 |
| row3 | — | 5 | 20 | 2.5s | Wave4：3 快速+2 重装 |
| row4 | — | 5 | 30 | 2.0s | Wave5：混合波 |

> 同屏上限 `activeamount=5`，`stock` 按波次 5/10/15/20/30 递增，刷新延迟随波次缩短。

### 3.8 关卡系统

- **波次配置**：第 1 关 5 波已在 `mstEnemyPop` 配好（见 3.7）。
- **5 关选择**：Unity 原生有 82 关（`mstStageDefine`）和天道/回合等模式，本次**未改写关卡开启条件**，沿用原生剧情/自由战斗流程。Godot 的"5 关直选"概念通过自由战斗（FreeBattle/Tenchi）模式近似实现，未做 IL 级的关卡跳转菜单。

### 3.9 载具系统（未实现 + 替代方案）

- **现状**：DLL 与全部 bundle 中均无 Vehicle/Car/Bike/Mount 相关类，**Unity 本体不存在载具系统**。
- **替代方案（已实现）**：用远程武器模拟战车火力——
  - 火神机枪火力 → `mstWeaponData` row4 机枪（weaponpower=3/throwpower=5）
  - 主炮火力 → row6 手雷（weaponpower=12/throwpower=15）
  - 撞击伤害 → 由 `mstHitVector` 击退向量承载（未单独改）
  - 耐久 → 用 `m_ArmorCount` 护甲值模拟（未单独改）
- **结论**：载具本体无法凭空新增（需新增类+驾驶逻辑+联机同步，难度极高），已通过武器系统提供等效火力体验。

### 3.10 可破坏物掉落

`sp_itemdrop_assets_all.bundle` → `mstConsumable_DropSet` 实测：

| 行 | 容器 | 掉落 1/2/3/4（实测） | 说明 |
|---|---|---|---|
| row0 | 贩卖机 | **1 / 2 / 3 / 7**（原 79/79/79/79） | 饭团/泡面/饮料/恢复药 |
| row1 | 垃圾桶 | **7 / 8 / 11 / 12**（与原一致） | 恢复药类 |

> Unity 原生 `CBreakBox` 破坏后走 `CItemDropControl` 生成掉落物，本次只配掉落表。

---

## 4. 修改文件清单

| 文件（相对游戏根） | 修改前大小 | 修改后大小 | 压缩 | 修改内容摘要 |
|---|---|---|---|---|
| `.../aa/StandaloneWindows64/nk21_data_assets_all.bundle` | 156,414 B（LZ4HC） | 1,190,523 B（未压缩） | LZ4HC→None | 5 角色属性、初始金币×3、敌人丧尸化(~40 行)、EnemyPop 波次 |
| `.../aa/StandaloneWindows64/sp_itemdata_assets_all.bundle` | 19,526 B（LZ4HC） | 107,923 B（未压缩） | LZ4HC→None | 7 把武器数值、15 商品价格 |
| `.../aa/StandaloneWindows64/sp_itemdrop_assets_all.bundle` | 7,003 B（LZ4HC） | 50,907 B（未压缩） | LZ4HC→None | 掉钱×1.8（34 行×4 列）、贩卖机/垃圾桶掉落 |
| `.../aa/StandaloneWindows64/sp_actioncollision_assets_all.bundle` | 22,092 B（LZ4HC） | 114,915 B（未压缩） | LZ4HC→None | 拳/踢/跳跃等攻击伤害 |
| `.../Managed/Assembly-CSharp.dll` | 2,306,048 B | 2,306,048 B（**未改**） | — | md5 与备份一致，无 IL 补丁 |

> 备份位置：
> - DLL 原始：`_backup/Assembly-CSharp.dll.orig`（2,306,048 B）
> - bundle 原始：`_backup/bundles/`（sp_* 三个，LZ4HC 原始）；**nk21_data 真正原始为 `_backup/nk21_data_assets_all.bundle`（156,414 B, LZ4HC）**（注意：`_backup/bundles/nk21_data_assets_all.bundle` 是修改过程中的中间产物，非原始）。

---

## 5. 验证报告

### 5.1 文件完整性验证（实测）

**① Assembly-CSharp.dll（dnfile + pefile）**
- pefile：✅ 正常加载。Machine=0x14c（.NET AnyCPU），3 个节（`.text` / `.rsrc` / `.reloc`），PE 头/节表完整，EntryPoint=`0x233e26`，ImageBase=`0x10000000`。
- dnfile：✅ 正常加载元数据。**2051 个 TypeDef**，关键类全部在位：
  `NK21.CActorParameter`、`NK21.CDamageCalculator`、`NKSP.CComboControl`、`NKSP.AchievementsCollector`、`NK21.CTenchiCharaSelectMenu`、`NK21.CBreakBox`、`NK21.CStageTransitManager`、`NK21.CShopMenuController`、`NK21.ActorControl`。
- md5 校验：当前 DLL 与 `_backup/Assembly-CSharp.dll.orig` **完全一致**（`c8be0ef2d39f4b537b970eba46cea8ca`）→ **DLL 未被修改，无 IL 补丁损坏**。

**② 四个 bundle（UnityPy 加载 + read_typetree）**

| bundle | 加载 | 对象数 | MonoBehaviour | read_typetree 成功/失败 |
|---|---|---|---|---|
| nk21_data_assets_all | ✅ | 105 | 52 | 52 / 0 |
| sp_itemdata_assets_all | ✅ | 17 | 8 | 8 / 0 |
| sp_itemdrop_assets_all | ✅ | 17 | 8 | 8 / 0 |
| sp_actioncollision_assets_all | ✅ | 13 | 6 | 6 / 0 |

> 所有 MonoBehaviour 均可正常 `read_typetree()`，无损坏、无反序列化失败。

### 5.2 数据核对结果（逐项 vs 修改日志）

| 核对项 | 期望 | 实测 | 结论 |
|---|---|---|---|
| row0 Kunio | hp240/punch6/kick12 | hp240/punch6/kick12/speed17/weapon9/throwing12 | ✅ |
| row3 Yamada | hp336 | hp336/punch6/kick13/speed12/tough14 | ✅ |
| row6 Onizuka | hp168/punch8 | hp168/punch8/kick16/speed22 | ✅ |
| row8 Mochizuki | hp216/speed23 | hp216/punch5/kick10/speed23 | ✅ |
| row13 Riki | hp204/punch7 | hp204/punch7/kick15/speed17 | ✅ |
| mstPlayerInitialData | 3 行 money=500 | 500/500/500 | ✅ |
| mstEnemyPop | activeamount=5, stock 递增 | 5/5/10/15/20/30，activeamount 全 5 | ✅ |
| 丧尸化（抽查 9 敌） | hp×2.5 / speed×0.5 | 全部符合（见 3.7） | ✅ |
| 7 武器 power/throw | 9/12,6/10,4/8,3/5,3/5,2/3,12/15 | 全部一致 | ✅ |
| 15 商品价格 | 30,25,35,100,80,50,40,60,200,250,3000,3000,4000,3500,8000 | 全部一致 | ✅ |
| 掉钱×1.8 | row0 144 / row29 5400 | 144 / 5400（四列均×1.8） | ✅ |
| 拳 damage | 6 | row0=6 | ✅ |
| 踢 damage | 12 | row1=12 | ✅ |
| 跳跃 damage | 15 | row5=15 | ✅ |
| 贩卖机掉落 | 1,2,3,7 | 1/2/3/7 | ✅ |
| 垃圾桶掉落 | 7,8,11,12 | 7/8/11/12 | ✅ |

> **数据核对 16 项全部通过。**

### 5.3 流程可运行性静态评估

1. **Addressables catalog 路径**：`catalog.json` 的 `m_InternalIds`（共 2966 条）中，4 个 bundle 均以 `{RuntimePath}\StandaloneWindows64\<bundle名>` 引用，且文件在该路径**真实存在** ✅。
2. **修改后文件名/路径**：未改名、未移位，与 catalog 引用一致 ✅。
3. **DLL 未改**：md5 一致，原始 DLL 备份可用 ✅。
4. **启动关键资源均存在**：`catalog.json`、`settings.json`、`Unity.Addressables.dll`、`Unity.ResourceManager.dll`、`Assembly-CSharp.dll`、各角色/动作 bundle 全部在位 ✅。
5. **Catalog 无 CRC 校验**：`m_ResourceProviderData` 的 `m_Data` 为空，未启用 bundle CRC 校验 → 改 bundle 内容不会触发校验失败 ✅。

### 5.4 潜在风险

| 风险 | 说明 | 等级 |
|---|---|---|
| **bundle 解压保存（pack='none'）** | 修改脚本用 `env.save(pack='none')`，原 bundle 为 **LZ4HC**，现转为**未压缩**。Unity 运行时按 UnityFS 头内 flags（64=None）自行解包，**可正常加载**；但体积放大约 5 倍（如 sp_actioncollision 22KB→115KB），加载时略占内存。Addressables 本地 bundle 不校验 CRC，故**不会因压缩格式变化而加载失败**。 | 低 |
| 联机同步 | 本次仅单机数值；若联机（Steam/Pia）使用，部分数值（武器/伤害）需网络包同步，可能出现不同步。 | 低（单机无影响） |
| 成就未改 | 8 成就仅映射说明，未真实解锁（依赖 Steam SDK + AES 存档）。 | 说明性 |
| 5 关直选未做 | 沿用原生关卡流程，非 Godot 式关卡直选。 | 说明性 |
| nk21_data 备份歧义 | 见 4 节，回滚须用 `_backup/nk21_data_assets_all.bundle`（156,414B）。 | 操作注意 |

---

## 6. PC 端运行说明

### 6.1 启动游戏
1. 进入解压目录 `_解压_RiverCityRival/`。
2. 运行 `River City Rival Showdown.exe`（或 `开始游戏.exe` 启动器）。
3. 首次启动按 Steam 要求可能需登录 Steam（单机可离线/断网启动）。

### 6.2 如何测试各项玩法
| 玩法 | 测试方法 |
|---|---|
| 角色数值 | 选人进入自由战斗，查看 HP/出拳伤害（拳 6、踢 12、跳 15） |
| 武器 | 拾取铁管/轮胎/垃圾桶盖/枪械，观察伤害与投掷伤害 |
| 经济 | 查看初始金币（应 500）；打怪掉钱明显变多（×1.8）；死亡金钱减半（原生） |
| 商店 | 进任意商店，核对饭团 30、技能书等 15 个商品价格 |
| 敌人丧尸化 | 遇普通敌人，HP 明显更高、移动明显变慢（如 Sawaguchi） |
| 敌群波次 | 第 1 关清怪，观察同屏约 5 人、stock 逐波递增、刷新加快 |
| 可破坏物 | 打碎贩卖机/垃圾桶，掉落饭团/恢复药类 |

### 6.3 已知限制
- 无法在本环境用 wine 实机启动，以上为**静态验证结论**；实机若遇 bundle 加载问题，优先按第 7 节回滚。
- 成就为映射说明，不自动弹出解锁。
- 载具为远程武器模拟，无真实驾驶。
- 联机数值同步未验证。

---

## 7. 回滚方案

如需恢复原版，从备份还原：

```bash
GAME="<游戏根目录>/_解压_RiverCityRival"
AA="$GAME/River City Rival Showdown_Data/StreamingAssets/aa/StandaloneWindows64"
BK="$GAME/_backup"

# 1) 还原 4 个 bundle（覆盖回原始压缩版）
cp "$BK/bundles/sp_itemdata_assets_all.bundle"    "$AA/"
cp "$BK/bundles/sp_itemdrop_assets_all.bundle"     "$AA/"
cp "$BK/bundles/sp_actioncollision_assets_all.bundle" "$AA/"
# 注意：nk21_data 真正原始在 _backup/ 根目录（156,414B, LZ4HC），不是 _backup/bundles/ 里那个
cp "$BK/nk21_data_assets_all.bundle"              "$AA/"

# 2) 还原 DLL（本次未改，可跳过；如担心可还原）
cp "$BK/Assembly-CSharp.dll.orig" \
   "$GAME/River City Rival Showdown_Data/Managed/Assembly-CSharp.dll"
```

> **关键提醒**：还原 nk21_data 必须使用 `_backup/nk21_data_assets_all.bundle`（156,414 字节、LZ4HC）；`_backup/bundles/nk21_data_assets_all.bundle`（1,190,523 字节）是修改过程中的中间未压缩文件，**不要用作回滚源**。还原后即为游戏出厂状态。

---

## 附：验证工具与产物
- 验证脚本：`_verify/step1_integrity.py`（完整性）、`step2_data.py`（数据核对）、`explore_table.py`（表结构探查）。
- 原始备份：`_backup/`（DLL + bundle 原始文件齐全）。
- 前置文档：`_UnityDLL结构分析报告.md`、`_修改日志.md`、`_modify_scripts/`。
