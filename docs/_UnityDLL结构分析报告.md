# 《River City Rival Showdown》Assembly-CSharp.dll 结构分析报告

> 分析目标：`River City Showdown_Data/Managed/Assembly-CSharp.dll`（约 2.3 MB，2051 个 TypeDef）
> 分析工具：dnfile 0.18.0（PE/.NET 元数据遍历 + ECMA-II 签名解析）、UnityPy 1.25.3（Addressables bundle 反序列化）
> 分析日期：2026-09-23
> 性质：只读分析，未修改任何文件。原始备份见 `_backup/Assembly-CSharp.dll.orig`。

---

## 0. 总体结论速览

- 程序集采用 **UnityQuickSheet** 数据驱动架构：所有数值表都是 `mstX`（ScriptableObject 表）+ `mstXData`（行类），行类字段与导出的 Excel 列一一对应，表本体存放在 Addressables bundle 中（不在 DLL 里硬编码数值）。
- 运行时逻辑主要在 **`NK21`** 命名空间（536 类），故事模式追加内容在 **`NKSP`**（114 类），多人联机在 **`NK21.Multiplay`**（53 类）。
- 玩家/敌人角色均为 `NK21.ActorControl`（运行时控制器）+ `NK21.CActorParameter`（参数容器，MonoBehaviour）。
- 战斗伤害统一由 `NK21.CDamageCalculator` 计算，受击硬直/击退/倒地由 `mstAttackCollisionData` + `mstDamageReactionData` + `mstHitVectorData` 三张表驱动。
- **载具系统：未找到**（DLL 与 bundle 中均无 Vehicle/Car/Bike/Mount 相关类）。
- 可破坏物系统存在：`NK21.CBreakBox` / `CBreakGround` / `CBreakStep` / `CBreakTurret` 等。

---

## 1. 全局类清单（按命名空间分组）

DLL 共 13 个命名空间、2051 个类型。业务相关的核心命名空间如下（仅列业务类，编译器生成的 `<>c__DisplayClass*` 状态机类、Pia 联机原生封装、Nex 服务等已省略）。

### 1.1 全局命名空间 `(global)` —— 1321 类
主要是 **枚举** 和 **UnityQuickSheet 主表行类**（`mst*Data`）：

- 枚举：`EnumCharacterID`(728 个角色ID)、`EnumAction`、`EnumWazaID`、`EnumItemType`、`EnumItemCategory`、`EnumItemCategory2`、`EnumWeaponItem`、`EnumConsumableItem`、`EnumEquipNameID`、`EnumAttribute`、`EnumDamageType`、`EnumHitTarget`、`EnumStatusEffectFunc`、`EnumActionState`、`EnumCommand`、`EnumInput`、`EnumKeyID`、`AI_TYPE`、`AI_ACTION`、`AI_Command`、`ATTACK_DATA`、`PICK_TYPE`、`STATE` 等。
- 主表行类（行结构，详见第 3 节）：`mstActorParamaterData`、`mstNpcParamaterData`、`mstActionData`、`mstAttackCollisionData`、`mstAttackSPDataData`、`mstDamageReactionData`、`mstHitVectorData`、`mstThrowData`、`mstBulletDataData`、`mstBulletActionData`、`mstWeaponDataData`、`mstWeaponActionDataData`、`mstItemDataData`、`mstDropTableData`、`mstMoney_DropSetData`、`mstConsumable_DropSetData`、`mstStatusTableData`、`mstLevelTableData`、`mstCharacterNameData`、`mstFieldItemData`、`mstItemActionData`、`mstSkillCommonData`、`mstWazaSettingData` 等。
- 运行时数据容器：`CharaStatus`、`CharaSkill`、`ActionState`、`ReserveAttackData`、`SpawnData`、`StageData`、`TransitInfo`、`PlayerSelectInfo`、`CharaSelectInfo`、`MoneyInfo`、`SpawnEnemyArgument`、`CloneDamageInfo`、`EnemyActionSync`。
- 网络同步：`CWeaponReleaseSync`、`CStratagemSync`、`CloneWeaponRelease`、`CloneActorDead`、`CloneStageState` 等。

### 1.2 `NK21` —— 536 类（核心游戏逻辑）
- 参数/战斗：`CActorParameter`、`CActorHitChecker`、`ActorControl`、`CActorNpcControl`、`CActorManager`、`CDamageCalculator`、`CDamageActionControl`、`CDamageCountControl`、`CAttackCollision`、`DamageAccumulate`、`CComboCountController`、`HitChecker`、`ItemHitChecker`、`PullChecker`、`CPickObjectControl`、`ThrowControl`。
- AI：`CAiStateMachine`、`CAiStateBase`、`CAiCharacterState`、`CAiNavMeshControl`、`CAiNavMeshSurface`、`CAiShortMove`、`CAiShortAttack`、`CAISpMove`、`CNpcGenerator`、`CGeneratorBase`、`CNpcPool`。
- 关卡/场景：`CStageTransitManager`、`CStageState`、`CTransitCollider`、`CEventCollider`、`CEventGimmick`、`CRestorePoint`、`SceneSelector`、`WorldScene`、`SceneName`。
- 商店/物品：`CShopMenuController`、`CShopItem`、`CShopItemList`、`CShopEquipList`、`CShopButton`、`CBulkBuyDialog`、`CItemManager`、`CItemDropControl`、`CDropItemControl`、`CBulletItemControl`、`CItemGenerator`、`CItemUseControl`。
- UI/菜单：`CMainUIManager`、`CPlayerPanelController`、`CHpGaugeController`、`CLifeGaugeController`、`CEnemyGaugeController`、`CEventBattleManager`、`CPauseMenuDialog`、`CPauseMenuStatus`、`CPauseMenuSkill`、`CTenchiCharaSelectMenu`、`CTenchiTitleMenu`、`CTenchiPauseMenu`、`CTenchiResult`。
- 存档/系统：`CSaveData`、`CStorySaveData`、`CSystemDefine`、`GlobalData`、`TenchiGameManager`、`ResourceManager`、`SceneLoading`、`InputManager`、`CSoundManager`、`CLocalizeManager`。
- 主表 ScriptableObject（表本体类）：`mstShop`、`mstShopData`、`mstShopAssort`、`mstStageDefine`、`mstChapter`、`mstEnemyPop`、`mstEnemyGroup`、`mstNpcManage`、`mstItemManage`、`mstEquipData`、`mstConsumableData`、`mstPlayerInitialData`、`mstGroupParamater`、`mstSystemDefine` 等。

### 1.3 `NKSP` —— 114 类（故事模式/FreeBattle 追加）
- 战斗追加：`CComboControl`、`CActorComboControl`、`COMBO_TYPE`。
- 模式/UI：`CFoDDGameManager`、`CFoDDModeManager`、`CFoDDCharaSelect`、`CFoDDTitle`、`CFoDDBattleUIManager`、`CEventManager`、`CEventTimeControl`、`CDateUpdateControl`。
- 成就：`Achievements`（枚举）、`AchievementsCollector`。
- 追加主表：`mstMobEnemyGroup`、`mstMobEnemyValue`、`mstEventData`、`mstBattleClubGroup`、`mstBonusEnemyData`、`mstEnemyPopPosition` 等。

### 1.4 `NK21.Multiplay` —— 53 类
联机房间/同步：`CMultiplayManager`、`CPiaManager`、`CMultiplayGameSteam`、`CNetPlayerPositionSync`、`COnlinePlayerStatus` 等。

### 1.5 其他命名空间
`NexPlugin`（任天堂 NEX 网络服务封装，9 类）、`DebugCanvas`、`NKSP.CpuBooster`、`NKSP.FODD`、`UnityQuickSheet`、`StringOperationUtil` 等基础设施。

---

## 2. 逐系统分析

### 2.1 角色选择系统

**核心类**
- `NK21.CTenchiCharaSelectMenu`（模式选择/1P-2P 选人菜单，继承 `NK21.CTenchiTitleMenuBase`）
- 全局 `CharaSelectInfo`、`PlayerSelectInfo`、`CharaInfo`（选人数据载体）
- `NKSP.CFoDDCharaSelect`（FreeBattle/对战模式选人）
- 全局 `EnumCharacterID`（728 个角色枚举，含 ANAME_KUNIO / ANAME_RIKI / ANAME_YAMADA / ANAME_RYUICHI / ANAME_ONIZUKA / 各校学生等）
- 表类 `mstCharacterName` + 行类 `mstCharacterNameData`（角色名本地化表）

**CTenchiCharaSelectMenu 关键字段**
| 字段 | 类型 | 含义 |
|---|---|---|
| `m_CharacterList` | `CharaSelectInfo[]` | 可选角色列表 |
| `m_PlayerCursorList` | `PlayerSelectInfo[]` | 各玩家光标状态 |
| `m_CurrentPlayerCursor` | `PlayerSelectInfo` | 当前操作玩家 |
| `m_LifeCountMax` / `m_LifeCountIndex` | int | 生命条数设置 |
| `m_FriendryFireIndex` | int | 友方火力设置 |
| `m_PlayerIndex` / `m_PlayerCount` | int | 玩家索引/人数 |
| `m_IsSyncEnable` / `m_PiaClone` | bool / CPiaCloneController | 联机同步开关 |

**关键方法**
- `Open(MenuStyle)` / `Show()` / `Hide()` / `Stay(int)`：菜单进出。
- `CharacterSelectEnter(int, EnumCharacterID)` / `IsCharacterSelected(EnumCharacterID)`：确认/查询某角色是否被选。
- `_getCharaSelectInfo(EnumCharacterID)`：按角色 ID 取选人信息。
- `GetUnselectedChara(...)`：获取未被占用角色。
- `SetPlayerUseCharacterOpen(int,int)`、`IsScelectedCharaOpen(EnumCharacterID,int)`：角色解锁状态。
- `StartGame()` / `OnGameStart(bool)`：开始游戏。

**数据来源**：角色解锁/初始属性来自 `mstPlayerInitialData`（bundle）与 `mstActorParamater`；角色名本地化来自 `mstCharacterName`。
**注入点建议**：
- 强制解锁全部角色：hook `IsScelectedCharaOpen` 恒返回 true，或修改 `SetPlayerUseCharacterOpen`。
- 修改可选角色列表：改写 `m_CharacterList`，或直接改 `CTenchiCharaSelectMenu.StartGame` 传入的 `EnumCharacterID`。

---

### 2.2 战斗系统（核心）

**运行时核心类**
- `NK21.CActorParameter`（MonoBehaviour，挂在角色上，承载 HP/SP/攻防/速度等实时参数）
- `NK21.CDamageCalculator`（单例，伤害计算）
- `NK21.ActorControl`（角色行为控制器，玩家与 NPC 共用）
- `NK21.CAttackCollision`（攻击判定盒）、`NK21.CDamageActionControl`（受击表现）
- `NK21.CComboCountController`（连招数 UI/计数，故事模式）、`NKSP.CComboControl` + `NKSP.CActorComboControl`（拳/踢连击计数逻辑，`COMBO_TYPE` 区分 Punch/Kick）

**CActorParameter 关键字段**
| 字段 | 类型 | 含义 |
|---|---|---|
| `m_Hp` / `m_Sp` | int | 当前 HP / SP |
| `m_Level` | int | 等级 |
| `m_Speed` | float | 移速 |
| `m_ResDown` / `m_ResStun` / `m_ResBreak` | int | 受身/眩晕/破坏耐性（百分比） |
| `m_Critical` | int | 会心率 |
| `m_MaxDamage` / `m_GutsHpRate` | int | 单次最大伤害上限 / 濒死保底 |
| `m_ArmorCount` | int | 护甲值（免伤次数） |
| `m_BasicStatus` / `m_LastStatus` | `CharaStatus` | 基础/含装备结算后属性 |
| `m_CharaSkill` | `CharaSkill` | 已学技能 |
| `m_InvalidAccumulates` | `DamageAccumulate[]` | 免疫的异常状态集合 |
| `Wep_Items` | `List<ItemControl>` | 手持武器列表 |

**CActorParameter 关键方法**
- `SetParameter(EnumCharacterID, bool, mstGroupParamaterData)` / `SetInitParameter(...)`：按角色表初始化。
- `GetParameter(EnumParameter)` / `GetParameter(PARAM)` / `GetParameterFloat(PARAM)`：读攻击/速度等派生属性。
- `SetDamage(int)`：扣血（HP 注入点）；`SetRecovery(int)` / `SetRecovery_SP(int)`：回血。
- `IsDead()`、`ResetHp()`、`RecalcLastStatus()`：死亡判定与重算。
- `GetCritical(int)`、`GetSkillLevel(int)`：暴击/技能等级。

**CDamageCalculator 关键方法（伤害管线注入点）**
- `int CalcDealtDamage(mstAttackCollisionData, ActorControl)`：基础伤害（读攻击表 `damage` 字段）。
- `int CalcMagnificateDamage(CAttackCollision, ActorControl, int, bool, EnumParameter)`：乘区放大。
- `int CalcFinalDamage(CAttackCollision, ActorControl, float, ActorControl)`：**最终伤害汇总（玩家→敌人、敌人→玩家都走这里）**。
- `bool CalcCritical(CAttackCollision, CActorParameter, ref)`：暴击判定。
- `float CalcCriticalDamage(CRITICAL_DAMAGE_TYPE, int)`：暴击倍率（倍率数组 `m_CriticalDamageArray`）。
- `int CalcSpDamage(...)`、`int CalcConsumeSP(CActorParameter, mstWazaSettingData)`：SP 伤害/必杀 SP 消耗。
- `int GetWeaponPower(EnumItemType, int)`：武器攻击力取值。

**攻击/受击数据表（bundle 驱动）**
- `mstAttackCollisionData`（421 行，表类 `mstAttackCollision`）：每次攻击判定一行，字段含 `damage`、`validframe`(判定帧数)、`damageframe`、`guardframe`(防御帧)、`downvalue`(down 值)、`stanvalue`(眩晕值)、`breakvalue`(破坏值)、`hitstop`(顿帧)、`airhit`(浮空)、`downhit`、`score`、`eenumwazaid`、`spdataid`、`damagereactionid`。
- `mstDamageReactionData`（388 行）：受击反应，按 地面前/地面后/空中前/空中后/倒地前/倒地后 分别指定动画 ID 与击退向量（`groundblown`/`airblown`/`downblown`）。
- `mstHitVectorData`（93 行）：击退方向向量表。
- `mstAttackSPDataData`（10 行）：攻击/受击/防御时的 SP 增减（`hitsp`/`damegesp`/`guardsp`）。
- `mstThrowData`（85 行）：投掷物轨迹（`vecx/vecy`、`isgravity`、`ispenetrate`、`validframe`、关联攻击判定 `eattack_data`）。

**连击/蓄力/冲刺**
- `NKSP.CComboControl`：`MaxComboCount`/`InitMaxComboCount`、`IncComboCount()`、`SetComboCountMax(COMBO_TYPE,int)`、`IsComboCountMax()` —— 拳/踢连段上限在此。
- `NK21.CChargeGaugeController` / `CSPcharge`（bundle: `CChargeGaugePool`）：蓄力/SP 槽。
- `mstAttackSPData` 与 `mstWazaSettingData` 支持必杀技（Waza）；`ReserveAttackData`（值类型）持有 `ATTACK_DATA` + `EnumWazaID`，用于缓存待发攻击。

**数据来源**：角色基础值在 `mstActorParamater`（bundle，287 行）；攻击数值/帧/硬直在 `sp_actioncollision_assets_all.bundle`；动作状态机在 `sp_charaaction_assets_all.bundle`。
**注入点建议**：
- 改玩家攻防/HP：改 `mstActorParamater` 表对应行，或 hook `CActorParameter.SetParameter`/`GetParameter`。
- 改伤害倍率/无敌：hook `CDamageCalculator.CalcFinalDamage`（乘 0 = 无敌，乘大数 = 秒杀）。
- 改拳/踢连段数：改 `NKSP.CComboControl.SetComboCountMax` 或 `MaxComboCount`。
- 改硬直/击退：直接改 bundle 中 `mstAttackCollision` 的 `downvalue/stanvalue` 与 `mstDamageReaction` 的 `*blown` 向量。

---

### 2.3 武器系统

**核心类**
- 表类 `mstWeaponData` + 行类 `mstWeaponDataData`（武器数值，79 行）
- 表类 `mstWeaponActionData` + 行类 `mstWeaponActionDataData`（武器动作/出招表，15 行）
- 全局 `mstBulletDataData` + `mstBulletActionDataData`（弹道/子弹行为，24 行）
- `NK21.CBulletItemControl`（飞行道具/子弹运行时）、`NK21.CItemManager`（武器/子弹/掉落物生成与查找）
- `NK21.CWeaponReleaseSync` + 全局 `CloneWeaponRelease`（联机武器释放同步）
- `NK21.CPickObjectControl`（拾取）

**mstWeaponDataData 字段结构（武器数值表行）**
| 字段 | 类型 | 含义 |
|---|---|---|
| `eenumweaponitem` | `EnumWeaponItem` | 武器枚举 ID |
| `eenumitemtype` | `EnumItemType` | 物品大类（区分近战/投掷等） |
| `weaponpower` | int | 武器攻击力 |
| `throwpower` | int | 投掷攻击力 |
| `throwaction` | int | 投掷动作 ID |
| `weaponstatuseffectid` | int | 命中附加异常状态 ID（-1 无） |
| `weaponaccumulatevalue` | int | 异常状态积累值 |
| `throwstatuseffectid` / `throwaccumulatevalue` | int | 投掷命中的异常 |

**mstWeaponActionDataData 字段（武器出招表行）**
`eenumitemcategory2`(武器小类)、`eenumaction`(动作ID)、`replacement`(替换动作)、`eenumactpattern`、`eenuminput`、`eenumkeyid[]`(触发按键)、`eflagandcheck[]`/`eflagorcheck[]`/`eflagnotcheck[]`(动作前置 flag)。

**枪械 vs 近战 / 弹药**
- 没有独立"弹药/弹匣"系统：`EnumWeaponItem` + `EnumItemType` 区分武器大类；飞行物走 `mstBulletDataData`（仅 `EnumBulletData`+`EnumEffect`+`EnumBulletAction` 三个引用），子弹由 `CBulletItemControl` 运行时生成（`CItemManager.CreateBulletItemObject`）。
- 武器状态以手持物品挂在 `CActorParameter.Wep_Items`。

**数据来源**：bundle `sp_itemdata_assets_all.bundle`（mstWeaponData / mstItemData / mstBulletData / mstConsumableData / mstFieldItem / mstBulletAction）。
**注入点建议**：改武器伤害直接改 `mstWeaponData` 行的 `weaponpower/throwpower`；hook `CDamageCalculator.GetWeaponPower` 可统一放大。改弹药/无限子弹需改 `CItemUseControl` / `CItemManager` 的消耗逻辑。

---

### 2.4 商店系统

**核心类**
- `NK21.CShopMenuController`（商店菜单控制器）
- 表：`mstShop`（+`mstShopData`，185 行）、`mstShopAssort`（+`mstShopAssortData`，商品陈列）、`mstShopStaff`（店员）、`mstShopEquipSkill`
- 消费道具表 `NK21.mstConsumableDataData`（77 行，含价格 `buyingprice1..4`/`price`/`maxstock`）
- UI：`CShopItem`、`CShopItemList`、`CShopEquipList`、`CShopButton`、`CBulkBuyDialog`、`CShopPreviewWindow`
- 购买记录：`NK21.CShopBuyInfo`（存在存档 `CStorySaveData.m_ShopBuyInfo`）

**CShopMenuController 关键字段**
`ShopID`(NK21.SHOP)、`m_ShopType`(SHOP_TYPE)、`ShopMode`、`Clerk`(店员 Actor)、`m_ShopMaster`/`m_ShopAssort`/`m_ShopStaff`/`m_ShopEquipSkill`/`m_FoodComment`/`m_FoodEffect` 等表引用。

**关键方法**
- `Open(NK21.SHOP)` / `OpenFromPacket(SHOP)`：进入商店（联机）。
- `Close(int)` / `CloseFromPacket(int)`：退出。
- `_corShopIn/_corShopOut/_corShopBuy/_corShopBuy_Cook/_corShopBuy_Machine/_corShopBuy_Sentou/_corShopBuy_Smile`（从协程名可见：商店有烹饪/自动售货机/钱汤/微笑等多种购买子流程）。
- `SendShopItemData()`：同步商品数据。

**mstShopData 行结构**：`id`(SHOP)、`category`(SHOP_TYPE)、`staff_1..3`(SHOP_STAFF)、`assort_1..3`(SHOP_ASSORT)。
**mstShopAssortData 行结构**：`consumableid`(EnumConsumableItem)、`equipid`(EnumEqipNameID)、`eattime`、`buylimit`、`sellcondition`(SELL_CONDITION)。

**数据来源**：bundle `nk21_data_assets_all.bundle`（mstShop / mstShopAssort / mstShopStaff / mstShopEquipSkill / mstFoodComment / mstFoodEffect）。
**注入点建议**：改价格改 `mstConsumableData` 的 `buyingprice*`/`price`；hook `CShopMenuController.Close` 或购买协程可实现免费购买/无限购买；`mstShopAssortData.buylimit` 控制限购。

---

### 2.5 成就系统

**核心类**
- `NKSP.Achievements`（枚举，36 个成就 ID）
- `NKSP.AchievementsCollector`（成就管理/解锁）
- 底层：`Aplus.SteamServices.SteamAchievement` / `ISteamAchievementsService`（来自 `SteamServices.dll`）
- `NK21.ACHIEVE_ID` / `NK21.ACHIEVE_GRADE`（故事模式成就等级枚举）

**Achievements 枚举成员（Steam 成就）**
`COMPLETE_ALL`、`CLEAR_STORY_1..4`、`CLEAR_STORY_YAMADA/RIKI`、`DEFEAT_FODD_ALEX/ROXY`、`LEARN_SPECIALS_5/10`、`LEARN_ULTRAS_3`、`CLEAR_TIGER_GYM`、`OBTAIN_UNIQUE_ITEM`、`VISIT_HIDDEN_SHOP`、`EAT_ALL_FOODS`、`READ_THAT_MAGAZINE`、`CLEAR_EVENT_1..7`、`REACH_LEVEL_10/50/99`、`DEFEAT_BONUS_ENEMY`、`EAT_ONIGIRI_50`、`FODD_SCORE_400K`、`EARN_MONEY_500K`、`CLEAR_DIFFICULTY_1..4`。

**AchievementsCollector 关键方法**
- `IEnumerator Initialize()` / `StoreAchievementsData()`：初始化/持久化（存档协程名 `AchievementsStoreCoroutine` 见 `CSaveData`）。
- `bool IsUnlocked(Achievements)`：查询是否解锁。
- `void Unlock(Achievements)`：**解锁单个成就（注入点）**。
- `void Progress(Achievements, uint)`：更新进度（如累计金钱/饭团数）。
- `UpdateAllComplete()`：全完成成就。

**数据来源**：成就定义硬编码在 DLL（枚举）；解锁状态经 AesKey 加密存储（`Cryptographer`、`AesKey` 字段），通过 Steam SDK 上报。
**注入点建议**：批量解锁可 hook `Unlock`/`IsUnlocked`，或遍历枚举调用 `Unlock`；进度类 hook `Progress`。

---

### 2.6 敌人 AI 系统

**核心类**
- `NK21.CAiStateMachine`（状态机）、`NK21.CAiStateBase`（状态基类，Enter/Exec/Exit）、`NK21.CAiCharacterState`
- `NK21.CAiNavMeshControl` / `CAiNavMeshSurface`（寻路）、`CAiShortMove`、`CAiShortAttack`、`CAISpMove`
- 生成：`NK21.CNpcGenerator`、`NK21.CGeneratorBase`、`NK21.CEventNpcGenerator`、`NK21.CNpcPool`
- 表：`mstAIBase`/`mstAIBaseData`、`mstAIActSet`/`mstAIActSetData`、`mstAIInputSet`/`mstAIInputSetData`、`mstAITest`
- 敌人群组/生成表：`NK21.mstEnemyGroup`/`mstEnemyGroupData`、`NK21.mstEnemyPop`/`mstEnemyPopData`、`NKSP.mstMobEnemyGroup`/`mstMobEnemyValue`、`NKSP.mstEnemyPopPosition`
- 网络：`SpawnEnemyArgument`、`EnemyActionSync`、`EEnemyAIActionFlag`

**CAiStateMachine 字段/方法**
字段：`CurrentState`、`OldState`、`GlobalState`（均 `CAiStateBase`）。
方法：`ChangeState(CAiStateBase)`、`RevertState()`、`SetCurrentState(...)`、`ClearState()`、`Exec()`。
`CAiStateBase`：`Enter(CActorNpcControl)` / `Exec(...)` / `Exit(...)`，Owner 为 `CActorNpcControl`。

**mstEnemyPopData 行结构（敌人生成点，154 行）**
`id`(如 STAGE01_GEN_01)、`stock`(总刷新数)、`activeamount`(同屏上限)、`delay`/`refilldelay`(刷新延迟)、`stageid`(STAGE)、`dayvalue`、`timezone`(EVENT_TIMEZONE)、`group_1..7`+`prob_1..7`(7 组敌群及概率)、`flag_op`、`progress`(PROGRESS)、`flag_1..4`、`order`、`point`。

**mstEnemyGroupData 行结构（敌群成员）**
`belong`、`groupid`、`mobenemyvalue`、`charaid_1..8`(8 个 `EnumCharacterID`)、`droptable`。

**数据来源**：bundle `nk21_data_assets_all.bundle`（mstEnemyPop/mstEnemyGroup/mstMobEnemyValue/mstMobEnemyGroup/mstEnemyPopPosition）；AI 动作表在 `mstAIActSet/mstAIInputSet`。
**注入点建议**：改同屏敌人数量/刷新频率改 `mstEnemyPop` 的 `activeamount/stock/refilldelay`；改敌群组成改 `mstEnemyGroup` 的 `charaid_*`；改 AI 难度改 `mstMobEnemyValue`（按难度 min/max 缩放）。

---

### 2.7 关卡/场景系统

**核心类**
- `NK21.CStageTransitManager`（关卡切换管理器，106 方法，核心）
- `NK21.CStageState`、`NK21.TransitInfo`、`NK21.CTransitCollider`、`NK21.CEventCollider`
- `NK21.WorldScene`、`NK21.SceneSelector`、`NK21.SceneLoading`、全局 `SceneName`、`STAGE_ADDRESS`
- `NK21.CRestorePoint`（存档点/恢复点）、`NKSP.CEventManager`（事件/日期时间推进）
- 表：`NK21.mstStageDefine`/`mstStageDefineData`(82 关)、`NK21.mstChapter`/`mstChapterData`(6 章)、`NK21.mstStageFogColor`、`NK21.mstStageNavMesh`

**CStageTransitManager 关键字段**
`StageDefine`、`StageFogColor`、`StageNavMeshSetting`、`m_CurrentStage`/`m_NextStage`、`m_EnemyPopData`(mstEnemyPop)、`m_NpcManageData`、`m_CompanionData`、`m_ItemManageData`、`m_WaitStageName`(STAGE)、`m_PrevStage`、`FastTravelCost`。

**关键方法**
- `Transit(TransitInfo, bool×6)`：**关卡切换（传送注入点）**。
- `_setNewStage(...)` / `OnLoadStageFinished(...)`：加载完成回调。
- `Restart(string,bool,bool)`、`ReLoad()`、`Return(string)`、`RegenerateCurrentStage()`。
- `SetDay(float)` / `EventSet(mstEventDataData, STAGE)`：推进日期/触发事件。
- `BakeNavMesh()` / `_setNavMeshBakeData(STAGE)`：烘焙寻路。

**mstStageDefineData 行结构（82 关）**
`id`(STAGE)、`name`、`namemesid`、`noonbgm/eveningbgm/nightbgm/battlebgm`、`minimapid`、`isfasttravel`、`openday/opentime/openflag`、`moveup/movedown/moveleft/moveright`(四方向邻接关)、`closetargets_1..6`(触发事件后关闭的邻接)、`leftend/rightend`。

**数据来源**：bundle `nk21_data_assets_all.bundle`。
**注入点建议**：免费快速旅行改 `FastTravelCost`；解锁关卡移动改 `mstStageDefine` 的 `openflag/openday`；直接传送 hook `Transit` 并指定 `STAGE`。

---

### 2.8 经济/金钱系统

**核心类**
- `NK21.CStorySaveData.m_Money`（int，**当前持有金钱，存档字段**）
- 初始金钱：`NK21.mstPlayerInitialDataData.money`（首周目 1000，其余 999999）
- 掉落：`mstMoney_DropSetData`（34 行，`moneydrop_day1..4` 按日期）、`mstDropTableData`（93 行，按稀有度 c/uc/r/l 指向 moneytable）
- UI：`MoneyInfo`、`NK21.CMainUIManager`（`_corUpdateMoneyText`）
- 伤害类型含金钱伤害：`CDamageCalculator.CalcMoneyDamage(...)`

**mstPlayerInitialDataData 行结构**
`id`、`name`、`gakuran/bontan/belt/shoes/button`(初始装备 EnumEqipNameID)、`money`、`inventorycapacity`(127)、`treasurecapacity`(20)、`abilities`、`inventories`。

**mstMoney_DropSetData 行结构**：`moneydrop_day1/2/3/4`（按日期段的掉落金额）。
**mstDropTableData 行结构**：`uniquedroptable`、`moneytable_c/uc/r/l`、`consumabletable_c/uc/r/l`。

**数据来源**：bundle `nk21_data_assets_all.bundle`(mstPlayerInitialData) + `sp_itemdrop_assets_all.bundle`(mstMoney_DropSet/mstDropTable)。
**注入点建议**：改持有金钱直接改 `CStorySaveData.m_Money`（或 hook 购买扣费处）；改敌人掉钱改 `mstMoney_DropSet`/`mstDropTable`；初始金钱改 `mstPlayerInitialData.money`。

---

### 2.9 载具系统

**未找到。** 在全部 2051 个类名、方法名及所有 bundle 的 MonoScript 类名中检索 `Vehicle/Car/Bike/Motorcycle/Mount/Horse/Ride/Slug`，均无对应业务类（仅命中 `CAmountSelector`、`CEventCardKeyControl` 等无关词）。本作无载具/骑行玩法。

---

### 2.10 可破坏物系统

**核心类**（均在 `NK21`，基类 `NK21.CGimmickAnimeControl` / `CGimmickManager`）
- `NK21.CBreakBox`（可破坏箱，挂 HP，破坏后掉道具）、`CBreakBoxChecker`
- `NK21.CBreakGround`（可破坏地面）、`CBreakGroundManager`、`CBreakGround_minimun`
- `NK21.CBreakStep`（可破坏台阶）、`CBreakStepManager`
- `NK21.CBreakTurret`、`CRockFall`、`CRoundRock`/`CRoundRockManager`（落石/滚石）
- 其他机关：`COpenChest`(宝箱)、`CFireTrap`、`CSpearTrap`、`CMoveStep`/`CMoveGround`(移动平台)、`CDoorControll`、`CPushButton`、`CDownBridge`。

**CBreakBox 关键字段/方法**
字段：`m_HP`、`m_isBreak`、`m_IsCreateItem`(CITEMTYPE)、`itemType`、`gotItem`、`m_BreakEffect`、`m_BlockEndFlags`(破坏后设置的 FLAG[])。
方法：`BreakObject(int)`、`ItemHitFunc(CAttackCollision)`、`OnCollisionEnter(Collision)`、`SetItemEffect_Default/Fire/Thunder`。

**数据来源**：场景内预设（Prefab 在 `nk21_*_assets_all.bundle`），破坏后掉落物走 `CItemDropControl`/`CItemManager`；破坏解锁的地图 flag 写在场景配置。
**注入点建议**：hook `CBreakBox.BreakObject` 实现一击破坏；`m_HP` 归零即破。

---

## 3. 数据 bundle 分析

### 3.1 `nk21_data_assets_all.bundle`（52 个主表 ScriptableObject）
所有表均为 UnityQuickSheet 产物：含 `SheetName`（源 Excel 路径）、`WorksheetName`、`dataArray`（行数组）。清单：

| 表类名 | 源 Excel | 行数(约) | 用途 |
|---|---|---|---|
| `mstActorParamater` | Paramater/ActorParamater.xlsx | 287 | 角色/敌人基础参数(HP/SP/punch/kick/weapon/speed/tough/luck/耐性) |
| `mstGroupParamater` | — | — | 组队参数 |
| `mstPlayerInitialData` | — | 3 | 初始金钱/装备/背包容量 |
| `mstLevelTable` | Paramater/LevelTable.xlsx | 100 | 等级经验/获得 LP |
| `mstEnemyPop` | Manage/Enemy_Group.xlsx | 154 | 敌人生成点 |
| `mstEnemyGroup` | — | — | 敌群成员 |
| `mstMobEnemyValue`(NKSP) | Enemy_Group.xlsx | 11 | 各难度敌人数值缩放 |
| `mstMobEnemyGroup`(NKSP) | — | — | 追加敌群 |
| `mstStageDefine` | Manage/StageDefine.xlsx | 82 | 关卡定义/BGM/邻接/开启条件 |
| `mstStageFogColor` / `mstStageNavMesh` | — | — | 雾色/寻路 |
| `mstChapter` | Manage/StoryDefine.xlsx | 6 | 章节/推荐等级/初始关 |
| `mstShop` | Shop/ShopData.xlsx | 185 | 商店 |
| `mstShopAssort` / `mstShopStaff` / `mstShopEquipSkill` | — | — | 商店陈列/店员 |
| `mstAIActSet` / `mstAIInputSet` / `mstAITest` | — | — | AI 动作/输入 |
| `mstSkillValueTable` / `mstLvLpSkillTable` | — | — | 技能数值 |
| `mstWazaMenu` / `mstWazaMenu_FoDD` | — | — | 必杀技菜单 |
| `mstNpcManage` / `mstCompanion` / `mstItemManage` | — | — | NPC/同伴/场景物品配置 |
| `mstTalkEvent` / `mstEventBattleGroup` / `mstBonusEnemyData` | — | — | 对话/事件战/追加敌人 |
| `mstTenchiRound` / `mstTenchiRoundBattle` / `mstTenchiStageFlag` | — | — | 天道模式(回合制) |
| `mstEffectDamageParamSet` / `mstSEData` / `mstBGMConvData` / `mstVoiceDefine` / `mstFoodCommentData` / `mstFoodEffectData` / `mstRarityRankTable` / `mstEquipSeriesTable` / `mstSystemDefine` | — | — | 效果/音效/BGM/语音/食物/稀有度/装备系列/系统常量 |

### 3.2 其余关键表所在 bundle
| Bundle | 包含主表 |
|---|---|
| `sp_itemdata_assets_all.bundle` | `mstWeaponData`(79)、`mstItemData`(166)、`mstConsumableData`(77)、`mstFieldItem`、`mstBulletData`(24)、`mstBulletAction` |
| `sp_itemdrop_assets_all.bundle` | `mstDropTable`(93)、`mstMoney_DropSet`(34)、`mstConsumable_DropSet` |
| `sp_actioncollision_assets_all.bundle` | `mstAttackCollision`(421)、`mstDamageReaction`(388)、`mstHitVector`(93)、`mstAttackSPData`(10) |
| `sp_actiondata_assets_all.bundle` | `mstThrowData`(85)、`mstWeaponActionData`(15)、`mstActionCommon`、`mstActionTemplate`、`mstActionFlagSet`、`mstActionPos` |
| `sp_charaaction_assets_all.bundle` | `mstAction` 系列(AttackAction 347 / SPAttackAction 972 / DamageAction 1173 / PlayerAction / SWeaponAction / WeaponAttackAction 等共 17 个表) |

### 3.3 关键表行字段结构（实测 row0）
- **mstActorParamater 行**：`eenumcharacterid, charanametableid, graphicid, eai_type, eitem, level, hp, sp, punch, kick, weapon, throwing, speed, tough, luck, resdown(100), resstun(100), resbreak(100), critical, statustable[], skilltable[], wazatable[], damagecollision`。
- **mstAttackCollision 行**：`eattack_data, collisionid, damagereactionid, validframe, damage, damagetype, hitstop, damageframe, guardframe, downvalue, stanvalue, breakvalue, statuseffectid, accumulatevalue, reactvalue, airhit, downhit, eenumparameter, eenumhittarget, eenumeffect, eenumwazaid, spdataid, typea, typeb, cameraid, deg_hit, score`。
- **mstDamageReaction 行**：`egroundfront/back, eairfront/back, edownfront/back`(动画ID)、`vecgroundfront/back...`(向量ID)、`groundblown/airblown/downblown`(Vector3)。
- **mstWeaponData 行**：见 2.3。
- **mstEnemyPop / mstShop / mstStageDefine / mstDropTable / mstMoney_DropSet / mstPlayerInitialData**：见对应系统节。

---

## 4. 修改可行性评估

### 4.1 容易（改数据 bundle 即可，无需动 IL）
| 目标 | 改哪里 |
|---|---|
| 角色 HP/攻/防/速度 | `sp...`/`nk21_data` 中 `mstActorParamater` 行 |
| 攻击伤害/判定帧/硬直/down/眩晕/破坏 | `sp_actioncollision` 中 `mstAttackCollision` |
| 受击击退距离/倒地 | `mstDamageReaction` 的 `*blown` 向量 |
| 武器/投掷攻击力 | `sp_itemdata` 中 `mstWeaponData.weaponpower/throwpower` |
| 商店价格/限购 | `mstConsumableData.buyingprice*`、`mstShopAssortData.buylimit` |
| 敌人同屏数/刷新/敌群组成 | `mstEnemyPop.activeamount/stock`、`mstEnemyGroup.charaid_*` |
| 初始金钱/掉钱 | `mstPlayerInitialData.money`、`mstMoney_DropSet` |
| 关卡开启/快速旅行 | `mstStageDefine.openflag`、`CStageTransitManager.FastTravelCost` |

> 前提：UnityPy 可改写 bundle 中的 `dataArray` 并重新打包；Addressables 的 catalog/校验可能需要同步处理。

### 4.2 中等（需改少量 IL 或 hook 单方法）
| 目标 | 注入点 |
|---|---|
| 玩家无敌/秒杀 | hook `CDamageCalculator.CalcFinalDamage` 返回固定值 |
| 无限 HP/SP | hook `CActorParameter.SetDamage` 不扣血，或改 `m_Hp` setter |
| 连段数提升 | hook `NKSP.CComboControl.SetComboCountMax` / `MaxComboCount` |
| 金钱锁定/免费购物 | 改 `CStorySaveData.m_Money` 或商店购买扣费处 |
| 一键解锁角色 | hook `CTenchiCharaSelectMenu.IsScelectedCharaOpen` 恒 true |
| 批量解锁成就 | 遍历 `NKSP.Achievements` 调 `AchievementsCollector.Unlock` |
| 一击破坏场景物 | hook `NK21.CBreakBox.BreakObject` |

### 4.3 较难（需理解状态机/联机同步）
| 目标 | 难点 |
|---|---|
| 新增招式/改 AI 行为 | 需理解 `mstAction` 动作脚本(`eenumfunc`/`funcvalue`)与 `CAiStateMachine` |
| 新增武器/弹药系统 | 武器与 `EnumWeaponItem`/`EnumItemType`、出招表 `mstWeaponActionData`、`CBulletItemControl` 多处耦合 |
| 联机下生效 | 涉及 `CloneWeaponRelease`/`EnemyActionSync`/`CPiaManager` 同步，单机改动需同步网络包 |
| 改存档加密 | 成就/存档经 `Cryptographer`(AES, `AesKey`) 加密，直接改存档需配套解密 |

### 4.4 备注
- 数值表全部数据驱动，**绝大多数平衡性玩法只需改 bundle 数据**，这是本游戏最友好的修改路径。
- 联机（Steam/Pia）相关逻辑与单机共存，若仅单机修改可不触碰 `NK21.Multiplay` 命名空间。
- 原始 DLL 备份 `_backup/Assembly-CSharp.dll.orig` 与 bundle 副本已就位，修改前请保留。

---

## 附录：分析脚本位置
- `_analysis_scripts/step1_enum_types.py`：枚举全部 TypeDef（产物 `type_dump.txt`、`type_list.json`）
- `_analysis_scripts/step2_deep_types.py`：解析字段/方法签名（产物 `deep_types.json`）
- `_analysis_scripts/step3_bundle.py` / `step4_bundle_fields.py` / `dump_rows.py` / `scan_all_bundles.py`：bundle 结构与表行字段分析
