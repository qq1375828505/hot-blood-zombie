# 融合方案 03：Buff 系统 + 敌人 AI 增强 + 波次刷怪 注入方案

> 目标：把 Godot 项目 `hot-blood-zombie` 的「4 种 Buff / 5 种普通敌 AI / 打残收服 / 精英 / Boss 三阶段 / 波次刷怪」设计，翻译为对 Unity 游戏 **River City Rival Showdown**（`Assembly-CSharp.dll`，命名空间 `NK21.*`）的 **Harmony 注入方案**。
>
> 环境约束：仅 Python 3.12 + dnfile 0.18.0（只读 .NET 元数据），无 dnSpy / ilspycmd / 编译器，**不改 DLL 方法体、不重编译 DLL**。本文所有类名 / 字段名 / 方法名 / 枚举成员名均来自 dnfile 直接解析（证据见第 2 节）；方法内部语义为命名推断。
>
> 调查日期：2026-09-23

---

## 1. Godot Buff + 敌人 AI 设计摘要（从 .gd 提取）

### 1.1 Buff 系统（`buff.gd`，30 行常量定义）

| Buff 键 | 来源物品 | 效果 | 持续时间 |
|---|---|---|---|
| `sports_drink` | 运动饮料 | **移动速度 +30%** | 15.0 s |
| `chili_rice` | 辣炒饭 | **攻击伤害 +50%** | 15.0 s |
| `iron_pipe` | 铁管（增益化） | **近战范围 +50%** | 20.0 s |
| `armor_vest` | 防弹背心 | **受到伤害 −50%** | 20.0 s |

- 掉落：丧尸死亡 **10%** 概率掉落，随机池 `["chili_rice","iron_pipe","armor_vest"]`（不含 sports_drink，后者靠拾取）。
- 叠加/倒计时/倍率结算在 `player.gd` 的 `active_buffs` 字典中实现；本文件只维护常量与文案，便于扩展。

### 1.2 普通敌人 5 种 AI 行为（`zombie.gd`，962 行）

敌人类型枚举 `Type { WALKER, RUNNER, FAT, DELINQUENT, BOSOZOKU }`，行为由状态/计时器驱动：

| 行为 | 触发 | 实现要点 |
|---|---|---|
| **发呆（zone_out / look_at_watch / fix_hair）** | 5%/秒 随机；人形敌倍率 1.5× | `silly_state` 非追踪状态，受击 20% 概率惊醒 |
| **互殴（brawl / argue）** | 3%/秒（人形 8%/秒），40~60px 内找同类 | 互殴期间每秒回 1 血；结束后 30% 人形敌"记仇" |
| **偷吃（snack）** | 2%/秒 | 纯演出 silly_state |
| **逃跑（flee）** | 仅 `can_flee` 类型，HP ≤ 30%（`flee_hp_ratio`） | 每帧 5% 概率进入，远离玩家、速度 ×1.3、持续 ~2s |
| **躲避（dodge）** | 远程子弹命中；连续被命中 ≥ `hit_streak_threshold(3)` | 0.3s 侧移 ×1.8 速，冷却 1.5s，概率 40% |
| **包抄（surround）** | 同屏 ≥3 只且靠近玩家 | 30% 个体叠加上下正弦偏移 `±SURROUND_Y(20px)` |
| **爆发冲锋** | runner 冲锋前摇 0.4s（红眼 telegraph）→ ×2.5 速冲刺 | `dash_state = telegraph/dash` |

**打残收服（核心特色）**：
- 求饶血量阈值 `CAPTURE_THRESHOLD = 2`（不良少年 3、暴走族 4）；**最后一击必须是近战**且 `0 < HP ≤ 阈值` → 进入 `begging`（下跪、举手、气泡"饶命！"），并从 `zombies` 组移除（不再被 AOE 命中）。
- 逃跑中被近战命中还有 40% 概率直接求饶。
- 玩家对求饶者调用 `capture()` → 返回援护数据（伤害值/性格标签/人形标记），敌人变为同伴。

### 1.3 精英敌人（`elite.gd`，412 行；定义在 `enemy_defs.gd`）

| 精英 | 特殊技能 | 关键数值 |
|---|---|---|
| `bosozoku_leader` 暴走族干部 | `dodge_bullets`（躲子弹）+ `melee_dash`（突进） | HP 60，伤害 20，霸体，眩晕抗性 0.7，突进 420 速/3.5s 冷却/25 伤 |
| `zombie_butcher` 丧尸屠夫 | `swing_aoe`（挥击范围攻击）+ `high_lifesteal` | HP 90，伤害 22，霸体，眩晕抗性 0.8，挥击半径 100/28 伤/2.5s |

精英吸血 8%（普通小怪 5%）。

### 1.4 Boss 三阶段（`boss.gd`，811 行；定义在 `enemy_defs.gd`）

两个 Boss：`street_boss`（暴走族总长·鬼冢，HP 400）、`final_boss`（学生会会长·白岳，HP 800）。

- **阶段判定**：每帧 `_check_phase()`，按 `HP / maxHP` 阈值：`< 0.66` → 阶段 2，`< 0.33` → 阶段 3。
- **阶段 1（近战压制）**：`punch_combo` + `body_slam`，speed/damage 倍率 1.0。
- **阶段 2（召唤冲刺）**：加 `dash_charge`，speed ×1.2~1.3，damage ×1.2~1.3，每 11~12s 召唤 3~4 小怪。
- **阶段 3（狂暴吸血）**：再加 `lifesteal_frenzy`，speed ×1.5~1.6，damage ×1.4~1.5，召唤间隔缩到 9~10s、数量 4~5，吸血率 ×2（→20%）。
- **阶段转换演出**：身体 1.2→1.0 回弹 + 抖动 + 眼睛变色（阶段2 橙、阶段3 红）+ 0.5s 过渡后摆姿势 1.5s，期间 **弱点激活（伤害 ×2）**。
- 吸血：Boss 基础 10%，按造成伤害回血不超过最大血。

### 1.5 波次配置（`level_config.gd`，99 行）

5 关，每关 `wave_config[]`，每波 `{walkers, runners, fat, interval}`：

| 关 | 名称 | 波数 | 趋势 |
|---|---|---|---|
| 1 | 黄昏町街道 | 5 | 3~5 walkers，0~1 runner，interval 1.5→0.9 |
| 2 | 白鹰高中 | 5 | 4~6 walkers，1~3 runner，0~2 fat |
| 3 | 暴走族聚集地 | 6 | 5~8 walkers，2~5 runner，1~3 fat |
| 4 | 白岳制药工厂 | 6 | 5~8 walkers，2~5 runner，1~4 fat |
| 5 | 终章·最终 Boss 战 | 3 | 前 2 波混合，**第 3 波 `boss_id = "final_boss"`** |

`interval` 即同波敌人之间的生成间隔（秒）。`level.gd`（67 行）仅做背景色/BGM 氛围演出，不参与刷怪逻辑。

---

## 2. Unity 原版相关系统元数据清单（dnfile 证据）

> 以下全部来自 `dnfile 0.18.0` 解析 `Assembly-CSharp.dll`（2051 类型 / 20761 字段）。方法可见性按 `mdPublic / mdFamily / mdPrivate` 标志判定。

### 2.1 AI 状态机框架

**`NK21.CAiStateMachine`**（FSM 容器，4 字段 / 14 方法）
- 字段（C# 属性 backing）：`Owner`、`CurrentState`、`OldState`、`GlobalState`
- 方法：`get/set_Owner`、`get/set_CurrentState`、`get/set_OldState`、`get_GlobalState/set_GlobalState`、`Exec()`、`ChangeState()`、`RevertState()`、`SetCurrentState()`、`ClearState()`

**`NK21.CAiStateBase`**（抽象基类，1 字段 / 6 方法）
- 字段：`Name`（属性）
- 方法（均为 `public virtual`）：`Enter()`、`Exec()`、`Exit()`
- **这是新增 AI 状态的基类：继承它、重写 Enter/Exec/Exit 即可挂到 `CAiStateMachine`。**

**现有 AI 状态（均继承 CAiStateBase 的 Enter/Exec/Exit 模式）**
- `NK21.CAiShortAttack`（单例，`Enter/Exec/Exit` virtual）
- `NK21.CAiShortMove`（单例，`Enter/Exec/Exit` virtual，另有 `_setNaviMove`、`NextAI*`、`_execPickUp` 等私有决策方法）

**AI 输入与导航组件（`NK21.CActorNpcControl` 持有）**
- `NK21.CAiInputHelper`：方向 `m_DiretionX/Z`、速度 `m_VelocityX/Z`，按钮 `m_Punch/m_Kick/m_Jump/m_Dash/m_Throw/m_Guard/m_Ranbu/m_PAndK/m_SpMove1..6`；方法 `ResetInputFlag()`、`ClearDirection()`、`ClearVelocity()`
- `NK21.CAiNavMeshControl`：`SetPath()`、`AddCornerIndex()`、`m_CornerIndex`、`m_ValidPath`、`targetTransform`

### 2.2 阵营（收服机制关键）

**枚举 `AI_TRIBE = { OPPOSITION, COMPANION }`**（dnfile 实测仅这两个成员）。

阵营字段实际挂在 **`NK21.CActorNpcControl`**（不是 `CActorParameter`）：
- 字段：`<m_AITribe>k__BackingField`
- 方法：**`get_m_AITribe()` / `set_m_AITribe(AI_TRIBE)`** ← 打残收服的原生切换点
- 同对象还持有：`StateMachine`、`m_AiInputHelper`、`m_NavMeshControl`、`m_Target`、`m_Gauge`、`opponentList`、`DropTable`、`IsBossDrop`、`shortrange/longrange/m_NowRange`、`m_AiList`
- 关键方法：`SetAI_PlayerTarget()`、`SetAI_TargetPos()`、`SetAI_FrontMove()`、`SetAI_Velocity()`、`SetAI_AutoAttack()`、`SetMarkCharacter()`、`GetMarkNearestDistance()`、`ActorDead()`、`IsDefeatAllOpponent()`、`Exec()`、`FixedExec()`、`GetAIHP()`

> **结论："打残收服"不需要新建阵营系统——只要在敌人残血时把它的 `CActorNpcControl.m_AITribe` 从 `OPPOSITION` 改成 `COMPANION`，并把目标从玩家切到敌方单位，原版 AI 即会自动把它当友军。**

### 2.3 状态效果 / Buff 系统

**`NK21.CStatusEffect`**（单个 buff 实例，16 字段 / 39 方法）
- 字段：`ID`、`ItemID`、`EffectValue1`、`EffectValue2`、`EffectTime`、`EffectDamage`、`EffectType`、`EffectTableData`、`EffectData`、`FrameCount`、`IsEternal`、`MarkHpRatio`、`CurrentHpRatio`、`CurrentSpRatio`、`CountEndCallback`、`IsNotRemoved`
- 方法：`IsActive`、`IsIconVisible`、`CountTime()`、`CountGameTime()`、`Disable()`，及全部字段 get/set

**`NK21.CStatusEffectManager`**（**buff 堆叠核心**，挂在 actor 上，7 字段 / 33 方法）
- 字段：`EFFECT_NUM`、`m_Effects`（效果列表）、`m_IconManager`、`m_TargetActor`、`m_DamageList`、`SkipOnlineSync`
- 方法：`Exec()`、`UpdateCountGameTime()`、**`AddEffect()`**、**`CreateEffect()`**、**`RecalcBuffEffect()`**、`ActEffectParam()`、**`GetEffectParamValue()`**、**`RemoveEffect()`**、`RemoveDebuffEffects()`、`RemoveAllEffects()`、`GetEffect()`、`IsEffect()`、`IsAnyGoodEffect()`、`IsAnyBadEffect()`、`IsDebuff()`、`GetEffectAll()`、`SetEffectAll()`、`ConvAccumulateToEffect()`、`ConvEffectToAccumulate()`

**数据表行类（ScriptableObject 行）**
- `.mstStatusEffectDataData`：`id`、`edamageaccumulate`、`damagereactionid`、`etype`、`effectframe`、`effectcontinuatevalue`、`damageinterval`、`damage`、`eparam1`、`value1`、`eparam2`、`value2`
- `.mstStatusEffectTableData`：`id`、`edamageaccumulate`、`eparam`、`eenumdamagetype`、`eenumeffect`、`eenumse`、`effectpos`
- （外层 sheet：`.mstStatusEffectData` 含 `SheetName/WorksheetName/dataArray`）

> **重要诚实发现**：`EnumStatusEffectFunc` 经 dnfile 实测**仅含 `NUM` 一个成员**（+ `value__`）。也就是说原版并不用枚举来列举"buff 功能类型"，buff 语义编码在 `mstStatusEffectDataData.etype / eparam1 / value1 / eparam2 / value2` 这张数据表里。注入新 buff = 往这张表加行 + 用 `EffectType/EffectValue1/2` 标识，而不是扩枚举。

**伤害计算接入点（`NK21.CDamageCalculator`，单例）**
- 字段：`_instance`（单例）、`m_Random`、`m_CriticalDamageArray`
- 方法：`static get_Instance()`、**`static Buff_Mul(...)`**、**`static Buff_Add(...)`**、`CalcDealtDamage()`（2 重载）、`CalcFinalDamage()`、`CalcMagnificateDamage()`、`CalcMagnificateStatusEffectDamage()`、`CalcCritical()`、`CalcSpDamage()`、`CalcMoneyDamage()`、`CalcConsumeSP()`、`GetWeaponPower()`
- **`Buff_Mul` / `Buff_Add` 均为 `public static`**——这是把"攻击 +50% / 受伤 −50%"乘进去的原生钩子。

**角色运行时参数（`NK21.CActorParameter`，32 字段 / 75 方法）**
- 字段：`m_Hp`、`m_Sp`、`m_Speed`、`m_ArmorCount`、`m_ResDown/m_ResStun/m_ResBreak`、`m_Critical`、`m_GutsHpRate`、**`m_SetHpCallback`**、**`m_SetHpCallback_BOSS`**、`m_SetSpCallback`、`m_SetMaxHPSPCallback`、`m_BasicStatus`、`m_LastStatus`、`m_CharaSkill`、`PlayerBuffValue`
- 方法：`get_HP/set_HP`、`get_HpRateFloat()`、`ResetHp()`、`SetDamage()`、`SetRecovery()`、`IsDead()`、`SetBuffValue()`、`GetBuffValue()`、`GetParameter()`、`SetParameter()`、`RecalcLastStatus()`、`SetBasicStatus()`

> **`m_SetHpCallback_BOSS` 是 Boss 三阶段的完美钩子**：它是一个委托，HP 变化时被回调，可在里面读 `get_HpRateFloat()` 触发阶段切换。

### 2.4 Boss 血条 / 特写

- **`NK21.BossGaugeBase`**：字段 `m_Target`、`m_CanvasGroup`、`m_StatusIconManager`、`Name_Image`、`isShow`、`useGauge`；方法 **`get_Ber_Per()`**（HP 比率）、`Show()`、`Hide()`、`CheckVisible()`、`Exec()`
- **`NK21.CEnemyGaugeController`**：字段 `IsIdle`、`IsVisible`、`m_Target`、`m_OffsetY`；方法 `Init()`、`Exec()`、`Show()`、`Hide()`、`UpdateVisible()`
- **`NK21.CEnemyGaugeManager`**：字段 `m_GaugePrefab`、`m_GaugePool`；方法 **`Attach()` / `Detach()`** / `UpdateVisible()`
- **`NK21.mstBossCutInDefineData`**：`id`、`charactername`、`nameid`、`titleid`、`addressn/e/j/all`（Boss 特写台词/标题本地化）

### 2.5 敌人数据 / 生成

- **`NK21.mstEnemyGroupData`**（敌人群组行，dnfile 实测名，**非** `mstEnemyGroupDataData`）：`no`、`belong`、`groupid`、`mobenemyvalue`、**`charaid_1..charaid_8`**（每群最多 8 个角色 ID）、`droptable`
- **`NK21.mstEnemyPopData`**（刷点行）：`no`、`id`、`stock`、`activeamount`、`delay`、`refilldelay`、`stageid`、`dayvalue`、`timezone`、**`group_1..group_7` + `prob_1..prob_7`**（最多 7 群按概率抽取）、`flag_op`、`progress`、`flag_1..flag_4`、`order`、`point`；方法 `IsStoryProgressMatch()`、`IsFlagsMatch()`
- **`NKSP.mstMobEnemyValueData`**：`no`、`mobenemyvalue`、`easymin/max`、`normalmin/max`、`hardmin/max`、`veryhardmin/max`；方法 `GetMobEnemyCount()`（按难度取数量）
- **`NK21.mstActorParamaterData`**（角色基础值行）：`id`、`eenumcharacterid`、`eai_type`、`level`、`hp`、`sp`、`punch`、`kick`、`weapon`、`throwing`、`speed`、`tough`、`luck`、`resdown/resstun/resbreak`、`critical`、`statustable`、`skilltable`、`wazatable`

**生成器体系**
- `NK21.CGeneratorBase`：`m_StageID`、`m_Label`、`Position`、`Label`
- `NK21.CNpcGenerator`：`GeneratorID`、`m_EnemyData`、`m_ActiveEnemyNum`、`m_EnemyCount`、`m_EnemyCoroutine`、`m_CurrentStage`；方法 `Clear()`、`IsExtinct()`、`CallOnPacketSpawnEnemyRecieved()`
- `NK21.CEventNpcGenerator`：`GeneratorID`、`m_EnemyData`、`m_EventBattleGroupData`；方法 **`GenerateEnemy()`**、`GenerateCompanion()`、`GenerateEventBattleNpc()`、`GenerateFoddBattleNpc()`、`LotteryBattleClubGroup()`
- `NK21.CActorNpcManager`（总调度）：`RegisterGenerator()`、`ActivateGenerator()`、`ActivateEventBattleGenerator()`、`ActivateFoddBattleGenerator()`、`ActivateGenerator_BonusEnemy()`、**`AddEnemySpawnDelegate()` / `CallOnEnemySpawn()`**、**`AddCompanionSpawnDelegate()` / `CallOnCompanionSpawn()`**

### 2.6 AI 行为模式枚举

**`EnumActPattern`（44 项，dnfile 实测）**：
`NORMAL, STAND, DAMAGE, PUNCH_Ground, PUNCH_Air, KICK_Ground, KICK_Air, SWeaponAttack_Dash, SWeaponAttack_Ground, SWeaponAttack_Air, BWeaponAttack_Ground, BWeaponAttack_Air, EQUIP_GroundThrow, EQUIP_JumpThrow, Throw, PandK, Dash_Punch, Dash_Kick, Punchi_First, Kick_First, Dash, Guard, SP_Ground_Only, SP_Dash_Max, SP_Ground_Stand_and_Dash, SP_Dash_Only, SP_Jump, SP_Jump_Up, SP_Kagami, SP_Weapon_Ground, SP_Throw, SP_NekketsuCounter, SP_EQUIP_GroundThrow, SP_Naname_Jump, SP_Vertical_Jump, SP_Weapon_V_Jump, BWeaponThrow_Dash, SWeaponThrow_Dash, SP_Break, Tsubame_Jump, Walk, BWeapon_Stand, NUM, END`

> 其中 `Walk / Dash / Guard / DAMAGE / STAND` 足以驱动"发呆/移动/防守/挨打"；`PUNCH_* / KICK_* / Throw / SP_*` 驱动攻击选择。

---

## 3. Buff 系统注入方案

### 3.1 设计：把 Godot 4 buff 映射到原版 CStatusEffect

原版已有 `CStatusEffectManager.m_Effects` 列表 + `AddEffect/RemoveEffect/RecalcBuffEffect` + 静态 `CDamageCalculator.Buff_Mul/Buff_Add`，**不需要新写 buff 框架**，只需：
1. 在 `mstStatusEffectDataData` 表里登记 4 个新 buff 行（ID 自定，避开已占用）；
2. 用 Harmony 给 `CStatusEffectManager.RecalcBuffEffect` 打 Postfix，按 `EffectType` 把 4 种 buff 折算到 `CActorParameter.SetBuffValue`；
3. 用 Harmony 给 `CDamageCalculator.Buff_Mul` / `Buff_Add` 打 Postfix 叠加"攻击+50% / 受伤−50%"。

| Godot buff | 映射 EffectType | 数值落点 | 时长 |
|---|---|---|---|
| `sports_drink` 速度+30% | SPEED_UP | `CActorParameter.m_Speed` ×1.3 | 15s |
| `chili_rice` 攻击+50% | ATTACK_UP | `CDamageCalculator.Buff_Mul` ×1.5 | 15s |
| `iron_pipe` 近战范围+50% | RANGE_UP | 攻击判定距离 ×1.5（改 `m_NowRange`） | 20s |
| `armor_vest` 受伤−50% | DEFENSE_UP | `Buff_Mul`（受伤侧）×0.5 | 20s |

叠加规则：同名 buff 刷新时间不叠加；不同 buff 乘区独立；`IsEternal=false`，靠 `EffectTime` + `CountGameTime` 倒计时，到点 `Disable()`。

### 3.2 C# Harmony 参考代码

```csharp
using HarmonyLib;
using NK21;
using UnityEngine;

// ============================================================
//  自定义 buff ID（与 mstStatusEffectDataData 新增行对应）
//  取一个不与原版冲突的高位段，例如 9000+
// ============================================================
public static class ZombieBuffIDs
{
    public const int SPEED_UP     = 9001; // sports_drink  速度 +30%
    public const int ATTACK_UP    = 9002; // chili_rice    攻击 +50%
    public const int RANGE_UP     = 9003; // iron_pipe     近战范围 +50%
    public const int DEFENSE_UP   = 9004; // armor_vest    受伤 -50%
}

// ============================================================
//  3.2.1 拾取/击杀掉落 → 给目标 actor 上 buff
//  调用方：击杀敌人后 10% 概率、或拾取道具时
// ============================================================
public static class ZombieBuffApplier
{
    // 给指定 actor 施加一个限时 buff（走原版 AddEffect 通道）
    public static void ApplyBuff(CActorParameter targetParam, int effectId, float durationSec)
    {
        if (targetParam == null) return;

        // 原版 CStatusEffect 实例：用公开 setter 填字段
        var eff = new CStatusEffect();
        eff.set_ID(effectId);
        eff.set_EffectTime(durationSec * 60f);   // 原版按帧计时（60fps），秒→帧
        eff.set_IsEternal(false);
        eff.set_IsNotRemoved(false);
        eff.set_FrameCount(0);

        switch (effectId)
        {
            case ZombieBuffIDs.SPEED_UP:
                eff.set_EffectValue1(1.30f);     // 速度倍率
                eff.set_EffectType(21);          // 自定义类型标记（对齐 etype 表新增行）
                break;
            case ZombieBuffIDs.ATTACK_UP:
                eff.set_EffectValue1(1.50f);     // 攻击倍率
                eff.set_EffectType(22);
                break;
            case ZombieBuffIDs.RANGE_UP:
                eff.set_EffectValue1(1.50f);
                eff.set_EffectType(23);
                break;
            case ZombieBuffIDs.DEFENSE_UP:
                eff.set_EffectValue1(0.50f);     // 受伤倍率（乘到受伤侧）
                eff.set_EffectType(24);
                break;
        }

        // CStatusEffectManager 挂在 actor 上；通过 targetParam 所在 actor 取到。
        // 具体取引用方式依原版 actor 聚合结构而定（见 3.3 备注）。
        CStatusEffectManager mgr = StatusEffectResolver.Resolve(targetParam);
        if (mgr != null)
            mgr.AddEffect(eff);                  // 原版堆叠/去重/倒计时由它负责
    }
}

// ============================================================
//  3.2.2 Postfix：RecalcBuffEffect 重算时，把 4 种 buff 写进参数
//  原版每帧/效果变化时调用 RecalcBuffEffect
// ============================================================
[HarmonyPatch(typeof(CStatusEffectManager), "RecalcBuffEffect")]
public static class Patch_RecalcBuffEffect
{
    static void Postfix(CStatusEffectManager __instance)
    {
        CActorParameter p = __instance.m_TargetActor;   // 字段经 dnfile 确认存在
        if (p == null) return;

        float speedMul = 1f, rangeMul = 1f;
        // 遍历 m_Effects，按 ID 叠加（同名取最新）
        foreach (CStatusEffect e in __instance.m_Effects)
        {
            if (e == null || !e.get_IsActive()) continue;
            switch (e.get_ID())
            {
                case ZombieBuffIDs.SPEED_UP:  speedMul *= e.get_EffectValue1(); break;
                case ZombieBuffIDs.RANGE_UP:  rangeMul *= e.get_EffectValue1(); break;
            }
        }
        // 速度倍率写回运行时参数（m_Speed 字段、get/set 经 dnfile 确认）
        p.m_Speed = Mathf.Max(1f, p.m_Speed * speedMul);
        // 攻击/防御倍率交给 CDamageCalculator 的 Buff_Mul（见下），这里用 SetBuffValue 存住
        p.SetBuffValue(ZombieBuffIDs.ATTACK_UP,  AttackMulOf(__instance));
        p.SetBuffValue(ZombieBuffIDs.DEFENSE_UP, DefenseMulOf(__instance));
    }

    static float AttackMulOf(CStatusEffectManager m)
    {
        float mul = 1f;
        foreach (CStatusEffect e in m.m_Effects)
            if (e != null && e.get_IsActive() && e.get_ID() == ZombieBuffIDs.ATTACK_UP)
                mul *= e.get_EffectValue1();
        return mul;
    }
    static float DefenseMulOf(CStatusEffectManager m)
    {
        float mul = 1f;
        foreach (CStatusEffect e in m.m_Effects)
            if (e != null && e.get_IsActive() && e.get_ID() == ZombieBuffIDs.DEFENSE_UP)
                mul *= e.get_EffectValue1();
        return mul;
    }
}

// ============================================================
//  3.2.3 Postfix：静态 Buff_Mul —— 攻击方 ATTACK_UP 乘算
//  签名经 dnfile 确认：public static Buff_Mul(...)
// ============================================================
[HarmonyPatch(typeof(CDamageCalculator), "Buff_Mul")]
public static class Patch_Buff_Mul
{
    // 原版返回一个累计倍率；Postfix 在返回值上乘上我方攻击 buff
    static void Postfix(CActorParameter attacker, ref float __result)
    {
        if (attacker == null) return;
        float atkBuff = attacker.GetBuffValue(ZombieBuffIDs.ATTACK_UP); // 默认 1
        if (atkBuff > 1f) __result *= atkBuff;
    }
}

// 防御 buff 一般作用在"受伤侧"。若原版 Buff_Mul 同时用于攻防两侧，
// 则再打 CalcDealtDamage 的 Postfix，对受害方乘 DefenseMul：
[HarmonyPatch(typeof(CDamageCalculator), "CalcDealtDamage")]
public static class Patch_CalcDealtDamage_Defense
{
    static void Postfix(CActorParameter ___target, ref int __result)
    {
        // 字段名 ___target 需按 IL 形参名微调（见 3.3 备注）
        if (___target == null) return;
        float def = ___target.GetBuffValue(ZombieBuffIDs.DEFENSE_UP);
        if (def < 1f) __result = Mathf.Max(1, (int)(__result * def));
    }
}
```

### 3.3 备注（注入时需现场确认）

- `CStatusEffectManager.m_TargetActor`、`CActorParameter.SetBuffValue/GetBuffValue`、`m_Speed` 字段均经 dnfile 确认存在；但 `Buff_Mul` / `CalcDealtDamage` 的**形参名**无法只读元数据确定（需 IL）。Harmony 里用 `___参数类型` 反射注入或 `[HarmonyArgument(0)]` 按位置取参即可。
- 取 `CStatusEffectManager` 实例：原版它是 actor 聚合成员，建议在第一次 patch 命中时用 `Traverse` 或公共 getter 缓存 `m_TargetActor → 其持有的 manager`，避免每帧查找。
- UI 图标：复用原版 `CStatusEffectIcon / CStatusEffectIconManager`（dnfile 确认存在），把新 buff 挂到 `m_IconManager` 即可显示，无需自写 HUD。

---

## 4. 敌人 AI 增强注入方案

### 4.1 框架：在 CAiStateMachine 下新增 Godot 风格状态

原版 `CAiStateBase` 是抽象类，三个 virtual 钩子 `Enter/Exec/Exit`。新增状态 = 继承它，挂到 `CActorNpcControl.StateMachine`（即 `CAiStateMachine`）。

```csharp
// 所有新增状态的基类：持有 NPC 控制器，方便取输入/导航/目标
public abstract class ZombieAiStateBase : CAiStateBase
{
    protected CActorNpcControl npc;        // dnfile 确认：StateMachine.Owner 类型
    protected CAiInputHelper input;        // npc.m_AiInputHelper（dnfile 字段）
    protected CAiNavMeshControl navi;      // npc.m_NavMeshControl

    public void Bind(CActorNpcControl ctrl)
    {
        npc   = ctrl;
        input = ctrl.m_AiInputHelper;
        navi  = ctrl.m_NavMeshControl;
    }
}

// ---- 状态① 发呆（zone_out）：原地不动，随机结束 ----
public class AiSillyIdle : ZombieAiStateBase
{
    float timer;
    public override void Enter()
    {
        timer = UnityEngine.Random.Range(1.0f, 2.5f);
        input.ClearDirection();
    }
    public override void Exec()
    {
        timer -= Time.deltaTime;
        input.m_VelocityX = 0f;            // 站桩
        // 取最大血量用 glue 解析器（CActorParameter.get_HpRateFloat / IsDead 经 dnfile 确认）
        float ratio = ParamResolver.HpRatioOf(npc);
        if (timer <= 0f || ratio <= 0.3f)
            npc.SetNextAIAction();          // 超时或被打残 → 回追击
    }
    public override void Exit() { }
}

// ---- 状态② 逃跑（flee）：远离目标，血线恢复或计时结束 ----
public class AiFlee : ZombieAiStateBase
{
    float timer = 2.0f;
    public override void Enter() { timer = 2.0f; }
    public override void Exec()
    {
        timer -= Time.deltaTime;
        // 目标方向取反 → 远离玩家；速度由外部 speedMult 处理
        Vector3 dir = npc.TargetDirectionVector;   // dnfile：get_TargetDirectionVector
        input.m_VelocityX = -dir.x * 1.3f;
        input.m_DiretionX = -dir.x;
        if (timer <= 0f) npc.SetNextAIAction();
    }
    public override void Exit() { }
}

// ---- 状态③ 躲避（dodge）：0.3s 侧移 ----
public class AiDodge : ZombieAiStateBase
{
    float t = 0.3f; float side;
    public override void Enter()
    {
        t = 0.3f;
        side = (UnityEngine.Random.value < 0.5f) ? -1f : 1f;
    }
    public override void Exec()
    {
        t -= Time.deltaTime;
        input.m_VelocityX = side * 1.8f;     // 侧移
        if (t <= 0f) npc.SetNextAIAction();
    }
    public override void Exit() { input.ClearVelocity(); }
}

// ---- 状态④ 包抄（surround）：横向偏移追击 ----
public class AiFlank : ZombieAiStateBase
{
    float sine;
    public override void Exec()
    {
        sine += Time.deltaTime * 3f;
        Vector3 dir = npc.TargetDirectionVector;
        input.m_VelocityX = dir.x + Mathf.Sin(sine) * 0.3f;
        input.m_DiretionX = dir.x;
    }
    public override void Enter() { }
    public override void Exit() { }
}

// ---- 状态⑤ 互殴（brawl）：转向另一只敌对 NPC 攻击 ----
public class AiBrawl : ZombieAiStateBase
{
    public override void Exec()
    {
        CActorNpcCell other = ZombieAiRegistry.FindNearestFriend(npc, range: 1.5f);
        if (other == null) { npc.SetNextAIAction(); return; }
        npc.SetAI_PlayerTarget(other.Transform);   // 复用目标设置
        input.m_Punch = true;                       // 出拳
    }
    public override void Enter() { }
    public override void Exit() { input.m_Punch = false; }
}
```

### 4.2 打残收服：利用 `AI_TRIBE.COMPANION` 切换阵营

这是整个方案的关键原生机制。残血时把敌人阵营从 `OPPOSITION` 改为 `COMPANION`：

```csharp
// ============================================================
//  Postfix：敌人受击后检查是否满足"打残收服"
//  挂在 CActorNpcControl.ActorDead 之前的伤害结算路径，
//  或直接 patch CActorParameter.SetDamage 的 Postfix。
// ============================================================
[HarmonyPatch(typeof(CActorParameter), "SetDamage")]
public static class Patch_CaptureOnLowHP
{
    static void Postfix(CActorParameter __instance)
    {
        // 非敌人 / 已死 / 已是同伴 → 跳过
        CActorNpcControl npc = NpcLocator.Of(__instance);
        if (npc == null) return;
        if (npc.get_m_AITribe() == AI_TRIBE.COMPANION) return;
        if (__instance.IsDead()) return;

        float ratio = __instance.get_HpRateFloat();   // dnfile 确认
        const float CAPTURE_RATIO = 0.30f;            // Godot: flee_hp_ratio=0.3
        if (ratio > CAPTURE_RATIO) return;

        // 仅"最后一击为近战"才求饶（Godot: is_melee && 0<hp<=阈值）
        // 这里由伤害来源标记 melee（外层传入），简化为：残血即触发
        if (ZombieBattleFlags.LastHitWasMelee(__instance))
        {
            // 1) 阵营切换：OPPOSITION → COMPANION（原生方法）
            npc.set_m_AITribe(AI_TRIBE.COMPANION);

            // 2) 目标改为敌方（原版会自动让它去打 OPPOSITION）
            npc.SetAI_TargetPos(Vector3.zero);

            // 3) 触发收服演出：暂停、下跪、气泡（复用 BossGaugeBase/演出或自写）
            ZombieRecruitPopup.Show(npc);

            // 4) 通知刷怪系统：本敌转为同伴，不计入"待击杀"
            CActorNpcManager.CallOnCompanionSpawn?.Invoke(npc);
        }
    }
}
```

> **为什么可行**：`opponentList`（dnfile 字段）是原版维护的敌对列表，切换 `m_AITribe` 后 AI 的目标筛选会自然把它从"要打的敌人"挪到"队友"。这就是调查报告指出的"不需要全新增系统"。

### 4.3 精英敌人配置

精英 = 在 `mstEnemyGroupData` 里把 `charaid_1..8` 指到高属性角色 ID，并在 `mstActorParamaterData` 对应行写高 HP/punch/stun_resist，再用 patch 给它附加特殊技能状态：

```csharp
// 按 charaid 判定精英，给它挂"躲子弹/突进/范围挥击"AI 状态
[HarmonyPatch(typeof(CActorNpcControl), "Init")]
public static class Patch_EliteInit
{
    static void Postfix(CActorNpcControl __instance)
    {
        var def = ZombieEliteTable.Lookup(__instance);   // 自定义查表
        if (def == null) return;                          // 普通敌不处理

        // 霸体 / 眩晕抗性：写回参数（glue 解析器：npc.m_MyOwner → 其 CActorParameter）
        CActorParameter p = ParamResolver.Of(npc);   // m_ResStun / m_ResBreak 经 dnfile 确认
        p.m_ResStun = def.stunResist;               // 0.7 / 0.8
        if (def.abilities.Contains("dodge_bullets"))
            ZombieEliteRegistry.RegisterDodge(__instance);
        if (def.abilities.Contains("melee_dash"))
            ZombieEliteRegistry.RegisterDash(__instance, def.dashSpeed, def.dashCd);
        if (def.abilities.Contains("swing_aoe"))
            ZombieEliteRegistry.RegisterSwing(__instance, def.swingRadius, def.swingCd);
    }
}
```

---

## 5. Boss 三阶段注入方案

### 5.1 利用 `m_SetHpCallback_BOSS` 做阶段转换

`CActorParameter.m_SetHpCallback_BOSS` 是 HP 变化委托。Boss 注册它，每帧 HP 变化时读 `get_HpRateFloat()` 判断阈值：

```csharp
public class BossPhaseController
{
    CActorParameter param;
    CActorNpcControl npc;
    int phase = 1;

    public void Bind(CActorNpcControl bossNpc)
    {
        npc = bossNpc;
        param = ParamResolver.Of(npc);          // glue：npc.m_MyOwner → CActorParameter（m_SetHpCallback_BOSS 经 dnfile 确认）
        // 把我们的回调挂到原版 Boss HP 回调链（字段经 dnfile 确认存在）
        param.m_SetHpCallback_BOSS = (System.Action<float>)OnHpChanged;
    }

    void OnHpChanged(float _hp)
    {
        float r = param.get_HpRateFloat();      // dnfile 确认
        int newPhase = 1;
        if      (r < 0.33f) newPhase = 3;
        else if (r < 0.66f) newPhase = 2;

        if (newPhase == phase) return;
        phase = newPhase;
        OnPhaseChange(newPhase);
    }

    void OnPhaseChange(int p)
    {
        var def = ZombieBossTable.Get(npc);     // {speedMult, dmgMult, attacks, summon, lifestealMult}
        // 1) 改速度
        param.m_Speed = def.baseSpeed * def.speedMult;
        // 2) 改攻击模式：切 AI 状态 / 限定 EnumActPattern 白名单
        ZombieActPatternLimiter.SetAllowed(npc, def.attacks);   // 如 {PUNCH_Ground, KICK_Ground, Dash, Throw}
        // 3) 阶段3 吸血强化
        if (p == 3) param.SetBuffValue(/*lifesteal*/12, def.lifestealMult);
        // 4) 演出：摆姿势 + 弱点窗口 + 血条变色
        BossGaugeFx.PlayPhaseTransition(npc, p);
        // 5) 召唤小怪
        if (def.summonMinions)
            ZombieWaveRunner.ScheduleSummon(npc, def.summonCount, def.summonInterval);
    }
}
```

### 5.2 每阶段攻击模式切换

原版 `EnumActPattern`（44 项）已覆盖全部需要的攻击：阶段 1 放 `PUNCH_Ground / KICK_Ground / Throw`；阶段 2 加 `Dash / Dash_Punch`；阶段 3 再加 `SP_Ground_Only`（狂暴技能）。用一个 patch 限制 AI 候选：

```csharp
[HarmonyPatch(typeof(CAiShortMove), "NextAI")]
public static class Patch_PhaseActLimiter
{
    static void Postfix(CAiShortMove __instance, ref EnumActPattern __result)
    {
        var allowed = ZombieActPatternLimiter.GetAllowed(__instance);
        if (allowed != null && !allowed.Contains(__result))
            __result = ZombieActPatternLimiter.Fallback(__instance);  // 退到白名单内
    }
}
```

### 5.3 Boss 血条 / 特写对接

- 血条：`CEnemyGaugeManager.Attach(npc)` 把 Boss 挂到 Boss 血条；`BossGaugeBase.get_Ber_Per()` 读 HP 比率；阶段切换时调 `BossGaugeFx` 改颜色。
- 特写：`mstBossCutInDefineData`（id/charactername/nameid/titleid）已定义 Boss 名字与称号，阶段 2/3 触发时复用 `CLuaTalkManager.StartBossCutIn` 风格的演出（或自写一张 1.5s 定格）。
- 弱点窗口：阶段切换后 3s 内给 Boss 上一个临时 `DEFENSE_UP=0.5` 反向（即受伤 ×2），用 `CStatusEffectManager.AddEffect` 实现。

---

## 6. 波次刷怪系统注入方案

### 6.1 原版生成机制分析

原版是**开放世界刷点**模型，不是清版波次：
- `mstEnemyPopData`：每个刷点有 `activeamount`（同屏上限）、`delay`（首次延迟）、`refilldelay`（补怪间隔）、`group_1..7 + prob_1..7`（按概率抽群）、`stageid/dayvalue/timezone`（昼夜/进度门控）。
- `mstEnemyGroupData`：一个群 = `charaid_1..8`（最多 8 个角色）+ `droptable`。
- `CNpcGenerator`：持有 `m_EnemyData`、`m_ActiveEnemyNum`、`m_EnemyCoroutine`，协程式补怪；`IsExtinct()` 判断是否清完。
- `CActorNpcManager`：`ActivateGenerator()` 激活刷点；`AddEnemySpawnDelegate/CallOnEnemySpawn` 提供生成回调钩子。

### 6.2 实现 Godot 式波次配置

不改原版生成器，而是**在其上做一个波次调度器**：用 `mstEnemyPopData` 的 `group/prob` 表达"每波敌种"，用协程按 `interval` 连续调 `GenerateEnemy`：

```csharp
// 波次定义（对应 Godot level_config.gd 的 wave_config）
public class ZombieWaveDef
{
    public int walkers, runners, fat;     // 各敌种数量
    public float interval;                 // 同波生成间隔
    public string bossId;                 // 末波 Boss（可选）
}

public class ZombieWaveRunner : MonoBehaviour
{
    ZombieWaveDef[] waves;
    int waveIndex;
    CEventNpcGenerator gen;               // dnfile：GenerateEnemy 入口

    public void StartWave(int levelIdx)
    {
        waves = ZombieLevelTable.Get(levelIdx).waves;   // 5 关波次表
        waveIndex = 0;
        StartCoroutine(RunWave());
    }

    System.Collections.IEnumerator RunWave()
    {
        while (waveIndex < waves.Length)
        {
            var w = waves[waveIndex];
            // 按 interval 逐个刷：walker→runner→fat
            for (int i = 0; i < w.walkers; i++) { gen.GenerateEnemy(CharaId.Walker); yield return new WaitForSeconds(w.interval); }
            for (int i = 0; i < w.runners; i++) { gen.GenerateEnemy(CharaId.Runner); yield return new WaitForSeconds(w.interval); }
            for (int i = 0; i < w.fat; i++)     { gen.GenerateEnemy(CharaId.Fat);     yield return new WaitForSeconds(w.interval); }

            if (w.bossId != null) SpawnBoss(w.bossId);

            // 等本波敌人清完（或被收服）再进下一波
            yield return new WaitUntil(() => gen.IsExtinct() || AllRecruitedOrDead());
            waveIndex++;
        }
        StageClear();
    }

    void SpawnBoss(string id)
    {
        var boss = gen.GenerateEnemy(ZombieBossTable.CharaIdOf(id));
        new BossPhaseController().Bind(boss);                 // 接第 5 节
        CEnemyGaugeManager.Instance.Attach(boss);             // 接 Boss 血条
    }
}
```

> 实现要点：`CEventNpcGenerator.GenerateEnemy`、`CNpcGenerator.IsExtinct`、`CActorNpcManager.CallOnEnemySpawn` 均经 dnfile 确认。波次"间隔"= `WaitForSeconds(w.interval)`；"每波种类/数量"= 查 `ZombieLevelTable`（镜像 Godot `level_config.gd` 的 5 关数据）。

---

## 7. 数据表修改清单

> 数值字面量在 ScriptableObject 资源（.asset）里，经 Addressables 加载，不在 DLL 内。以下是**需要在资源侧新增/修改的行**。

### 7.1 `mstStatusEffectDataData`（新增 4 行 buff）

| id | etype | eparam1 | value1 | eparam2 | value2 | effectframe | effectcontinuatevalue | damageinterval | damage |
|---|---|---|---|---|---|---|---|---|---|
| 9001 | SPEED_UP | SPEED | 1.30 | — | — | 900（15s×60） | — | — | — |
| 9002 | ATTACK_UP | PUNCH/KICK | 1.50 | — | — | 900 | — | — | — |
| 9003 | RANGE_UP | ATK_RANGE | 1.50 | — | — | 1200（20s） | — | — | — |
| 9004 | DEFENSE_UP | DEF | 0.50 | — | — | 1200 | — | — | — |

### 7.2 `mstEnemyGroupData`（新增精英/Boss 群）

| no | belong | groupid | mobenemyvalue | charaid_1..8 | droptable |
|---|---|---|---|---|---|
| 901 | ELITE | elite_boso | 高 | ch=暴走族干部 ID，其余空 | 精英掉落表 |
| 902 | ELITE | elite_butcher | 高 | ch=丧尸屠夫 ID | 精英掉落表 |
| 910 | BOSS | boss_Street | 极高 | ch=鬼冢 ID | Boss 掉落 |
| 911 | BOSS | boss_Final | 极高 | ch=白岳 ID | Boss 掉落 |

### 7.3 `mstActorParamaterData`（新角色/调数值）

- 为 4 种普通敌 + 2 精英 + 2 Boss 各配一行：`hp / punch / kick / speed / tough / resstun / critical`。
- 对应 Godot：walker hp3、runner hp2、fat hp14；精英 hp60~90；Boss hp400~800。
- 新增 `eai_type` 标记（发呆/逃跑/躲避倾向），供 patch 选择 AI 状态。

### 7.4 `mstEnemyPopData`（波次刷点）

- 每关配 1 个刷点行：`stageid`=对应关、`activeamount`=本波同屏上限、`delay/refilldelay`=0（波次由脚本控制）、`group_1..N` 指到 `mstEnemyGroupData` 的群 id。

---

## 8. 可行性评估

| 子系统 | 可行性 | 理由（基于 dnfile 证据） |
|---|---|---|
| **Buff 系统** | **高** | 原版已有完整 `CStatusEffectManager`（AddEffect/RemoveEffect/RecalcBuffEffect）+ 静态 `Buff_Mul/Buff_Add` + `CActorParameter.SetBuffValue/GetBuffValue`。4 种 buff 只是加数据表行 + 两个 Postfix。无需新框架。 |
| **打残收服（阵营切换）** | **高** | `AI_TRIBE={OPPOSITION,COMPANION}` + `CActorNpcControl.set_m_AITribe` 是原生方法。残血改阵营即可，目标筛选靠原版 `opponentList` 自动完成。这是本方案风险最低的亮点。 |
| **新增普通敌 AI 状态** | **高** | `CAiStateBase` 抽象 virtual Enter/Exec/Exit + `CAiStateMachine.ChangeState/SetCurrentState` 是标准 FSM。继承基类即可，导航/输入用现成 `CAiNavMeshControl.SetPath`、`CAiInputHelper`。 |
| **精英敌人** | **中-高** | 数据驱动（`mstEnemyGroupData` 指 charaid + `mstActorParamaterData` 调属性）容易；"躲子弹/突进/范围挥击"需自写 3 个 AI 状态并 patch `Init` 注册，工作量集中在行为调参。 |
| **Boss 三阶段** | **高** | `m_SetHpCallback_BOSS` 委托 + `get_HpRateFloat()` 是完美钩子；攻击模式用 `EnumActPattern` 白名单 patch `CAiShortMove.NextAI`；血条 `CEnemyGaugeManager.Attach`、特写 `mstBossCutInDefineData` 现成。 |
| **波次刷怪** | **中** | 原版是开放世界补怪模型（`mstEnemyPopData`+`CNpcGenerator`），没有现成"波次"概念。好在 `CEventNpcGenerator.GenerateEnemy` + `IsExtinct` + `CallOnEnemySpawn` 够用，外层包一个协程波次调度器即可。难点是让"波次清完才进下一波"与原版自动补怪不冲突（需临时把 `activeamount` 设为波次目标、关 refill）。 |
| **数据表新增行** | **中** | DLL 不含数值，需在 Addressables 的 .asset 资源侧加行。若不打算动资源，也可在运行时 patch `mstEnemyGroupData.dataArray` 直接 push 新对象——但依赖资源加载时机，需在 `OnEnable`/首次访问前注入。 |

### 总体结论

**本融合方案技术上成立，且最大限度复用了原版原生机制：**
- Buff → 复用 `CStatusEffectManager` + `Buff_Mul/Buff_Add`；
- 收服 → 复用 `AI_TRIBE` 阵营切换（**最关键的原生彩蛋**）；
- AI → 继承 `CAiStateBase` 挂入 `CAiStateMachine`；
- Boss 三阶段 → 挂 `m_SetHpCallback_BOSS`；
- 波次 → 在 `CEventNpcGenerator` 外包协程调度。

**主要不确定性**（受只读元数据限制，需在有 dnSpy/ILSpy 的环境二次确认）：
1. `Buff_Mul` / `CalcDealtDamage` 的确切形参签名（Harmony 用位置取参兜底）；
2. `CStatusEffectManager` 如何从 actor 聚合中获取（建议首次命中时缓存）；
3. 数值表行的实际数值在 .asset 资源，本方案只给结构不给字面值。
