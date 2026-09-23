# 战斗核心框架说明 (COMBAT_FRAMEWORK.md)

## 架构概览

```
main.tscn (战斗测试场景)
├── Camera2D
├── Ground (StaticBody2D)
├── Background (ColorRect)
├── Player (player.tscn)          ← player.gd
│   ├── Sprite (ColorRect)
│   ├── CollisionShape2D
│   └── Hitbox (Area2D)           ← hitbox.gd
├── EnemySpawner (Node2D)         ← enemy_spawner.gd
├── HUD (CanvasLayer)             ← hud.gd
│   ├── HPBar (ProgressBar)
│   ├── WaveLabel
│   ├── EnemyLabel
│   └── CenterMsg
└── TouchControls (touch_controls.tscn)  ← 子代理C负责
```

---

## 玩家状态机 (player.gd)

```
         ┌──────────────────────────────────┐
         ▼                                  │
       IDLE ──→ WALK ──→ PUNCH/KICK/WEAPON ─┘ (收招完回到IDLE/WALK)
         │         │              │
         │         └──→ JUMP ←────┘ (空中可出拳)
         │
         └──→ HURT (受击硬直，击退+闪白)
              └──→ DEAD (血量归零)
```

**状态枚举**: `State.IDLE, WALK, PUNCH, KICK, WEAPON, JUMP, HURT, DEAD`

### 攻击帧结构

每套攻击三段式（秒）：

| 阶段 | 说明 | 判定框 |
|------|------|--------|
| telegraph | 起手前摇 | 关闭 |
| active | 判定帧 | **开启** |
| recovery | 收招硬直 | 关闭 |

**连击取消**: 在 recovery 的 `cancel_window` 时段内再次按攻击键，可衔接下一击。

### 四套攻击

| 攻击 | 按键 | 伤害 | 连击上限 | 特点 |
|------|------|------|----------|------|
| punch (拳) | J / 左键 | 8 | 3段 | 快，轻击退 |
| kick (脚) | K | 14 | 2段 | 中速，重击退 |
| weapon (武器) | L | 25 | 1段 | 慢速，重击 |
| jump (跳踢) | 空中J | 12 | 1段 | 空中判定 |

---

## 敌人状态机 (enemy.gd)

```
IDLE ──→ CHASE ──→ ATTACK ──→ CHASE (循环)
           ↑           │
           │           ▼
           └──── STAGGER (受击硬直)
                       │
                       ▼
                     DEAD (倒地+淡出)
```

### 三种敌人

| 类型 | 血量 | 速度 | 攻击伤害 | 硬直抗性 | 击退抗性 | 颜色 |
|------|------|------|----------|----------|----------|------|
| 普通丧尸 | 30 | 100 | 6 | 0% | 0% | 绿 |
| 快速丧尸 | 18 | 200 | 4 | 0% | 10% | 黄 |
| 重装丧尸 | 80 | 55 | 12 | 50% | 60% | 紫 |

---

## 波次系统 (enemy_spawner.gd)

- 开场2秒后出第1波
- 每波清完后间隔3秒出下一波
- 同波次内每0.8秒刷一只
- 同屏敌人上限8只
- 从屏幕左右两侧边缘生成

### 波次表

| 波次 | 普通 | 快速 | 重装 |
|------|------|------|------|
| 1 | 2 | 0 | 0 |
| 2 | 3 | 1 | 0 |
| 3 | 2 | 2 | 1 |
| 4 | 0 | 4 | 2 |
| 5 | 5 | 3 | 2 |

---

## 打击手感参数 (FEEL)

| 参数 | 默认值 | 说明 |
|------|--------|------|
| hitstop_global_scale | 1.0 | 全局顿帧倍率 |
| camera_shake_amount | 6.0 px | 屏幕震动幅度 |
| camera_shake_duration | 0.15s | 震动时长 |
| hit_flash_duration | 0.08s | 受击闪白 |
| death_fall_duration | 0.6s | 倒地时长 |
| death_fade_duration | 0.5s | 淡出时长 |

---

## 如何调整手感

### 调打击感
在 `combat_config.gd` 的 `ATTACKS` 字典中调整：
- **想要更脆**: 增大 `hitstop` 到 0.05-0.08
- **想要更硬**: 减小 `hitstop` 到 0.02-0.03
- **击退更强**: 增大 `knockback`
- **连段更快**: 减小 `telegraph` 和 `recovery`

### 调敌人强度
在 `ENEMIES` 字典中调整：
- 重装丧尸不硬直 → 调高 `stagger_resist`
- 丧尸太快 → 调低 `chase_speed`

### 调波次难度
在 `WAVES.waves` 数组中增删敌人组。

---

## 贴图接入接口

当前用 ColorRect 占位色块。接入真实贴图时：

1. 将 `player.tscn` 中的 `ColorRect` 替换为 `AnimatedSprite2D`
2. 在 `player.gd` 的 `load_character_textures(char_name)` 中加载 `res://assets/characters/<char_name>/` 下的帧序列
3. 贴图命名格式: `NNN_XX.png`（NNN=动画组号, XX=帧号）
4. 同理替换 `enemy.tscn` 的 Sprite

---

## 输入映射

| Action | 键盘 | 说明 |
|--------|------|------|
| move_left | A / ← | 左移 |
| move_right | D / → | 右移 |
| move_up | W / ↑ | (预留) |
| move_down | S / ↓ | (预留) |
| jump | Space | 跳跃 |
| punch | J / 左键 | 拳击 |
| kick | K | 脚踢 |
| weapon | L | 武器 |
| restart | R | 重开 |

触控按钮由 `touch_controls.gd` 触发（子代理C负责对接）。

---

## 替换逆向数据

子代理A的逆向数据就绪后（enemies.json / waves.json / combat_stats.json）：
1. 读取 JSON 数值
2. 替换 `combat_config.gd` 中对应字典的数值
3. 无需修改任何逻辑代码
