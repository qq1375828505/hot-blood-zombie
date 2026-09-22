# 热血物语：末日丧尸（Hot-Blood Zombie）

不良少年 × 丧尸射击的 2.5D 横版动作游戏。灵感来自热血系列（国夫君/くにおくん）的校园不良风格与合金弹头（Metal Slug）的横版射击玩法，全部内容原创。

- 引擎：Godot 4.3（GDScript，gl_compatibility 渲染）
- 目标平台：Android（首发） / Windows / macOS / Web（同一套工程导出）
- 题材：原创。城市爆发丧尸病毒，热血不良少年持枪保卫校园与街道
- 打包方式：**GitHub Actions 自动打包**（推送到 main 即自动出安卓 APK），不在本地打包

## 玩法

横版丧尸射击 + 波次生存，热血系列风格包装：

- 移动 / 跳跃 / 下蹲，拳脚近战回能量，持枪射击消耗弹药
- 四种武器：手枪 / 冲锋枪 / 霰弹枪 / 手雷，黑市可购买升级
- 热血必杀：能量攒满后释放全屏震荡波清场
- 格斗连击 / 蓄力重击 / 援护召唤（收服丧尸后可用）
- 载具改装（火神炮 + 主炮）、半尸化变身、友军伤害开关
- 5 名可选角色（倍率差异化，暴走族总长为隐藏角色）
- 丧尸三种基础型 + 2 种精英 + 多阶段 Boss，全部带吸血/躲避/扛伤 AI
- 2P 为纯 AI 人机队友（单机游戏，无真实双人输入）
- 经济黑市 / 成就系统 / 关卡推进（黄昏町→白鹰高中→暴走族聚集地）

## 操作（桌面端）

| 按键 | 动作 |
|---|---|
| A / D 或 ← → | 移动 |
| W / ↑ / 空格 | 跳跃 |
| S / ↓ | 下蹲（减速） |
| J 或 鼠标左键 | 射击 |
| K | 近战（回能量） |
| L | 热血必杀（能量满时） |
| R | 死亡后重开 |

## 操作（移动端）

- 左侧虚拟摇杆控制移动
- 右侧触屏按钮：跳跃 / 下蹲 / 射击 / 近战 / 必杀 / 重开，另附商店 / 互动 / 暂停键
- HUD 按 6.9 寸横屏安全区适配
- headless / 桌面环境下触控层自动隐藏，不影响桌面键鼠调试

## GitHub 打包（推荐方式）

本工程配置了 GitHub Actions 工作流（`.github/workflows/godot-ci.yml`），推送到 `main` 分支后自动执行：

1. 无头导入（检查脚本/场景错误）
2. 冒烟测试（`tests/smoke.gd`）
3. 导出安卓调试版 APK（arm64-v8a，横屏）
4. 上传 APK 到 Actions 产物（Artifacts）

推送方法：

```bash
git init
git add .
git commit -m "热血物语：末日丧尸 V2.0"
git branch -M main
git remote add origin https://github.com/<你的用户名>/<仓库名>.git
git push -u origin main
```

在 GitHub 仓库页面点「Actions」查看构建，构建成功后点顶部「Summary」→「Artifacts」下载 `hot-blood-zombie-android-apk` 即可安装。

打正式发布 tag 可自动触发一次打包：

```bash
git tag v2.0
git push origin v2.0
```

> 注意：CI 使用 `barichello/godot-ci:4.3` 镜像（内置 Godot 4.3 + Android SDK + 导出模板），无需本地装 SDK。正式上架商店时需在 `export_presets.cfg` 配置自己的 release keystore，并在本地导出签名 AAB（keystore 密钥不能提交到仓库）。

## 本地导出（备选）

- 首发平台为 Android（横屏，arm64-v8a）。
- 导出步骤：用 Godot 4.3 打开本工程 → 菜单「项目」→「导出…」→ 选择已配置好的 `Android` 预设 →「导出项目」，输出 APK 或 AAB。
- 环境依赖：需准备 Android SDK / Build-Tools / Platform-Tools 与 JDK 17，并在 Godot 编辑器「编辑器设置 → 导出 → Android」中指定 SDK 路径与调试 keystore，详见 Godot 官方导出文档。
- 签名：debug 包使用 Godot 默认 debug keystore；release 包需在 `export_presets.cfg` 的 `keystore/release` 处配置自己的发布签名 keystore 与别名密码后再出包。

## 安装包大小说明

- Godot 4.3 空工程的 APK 一般约 30–60MB（引擎本体随包分发，区别于老像素游戏只有几百 KB）。
- 使用 AAB（Android App Bundle）+ 架构拆分（仅 arm64-v8a）可压缩到约 25–45MB，由 Google Play 按设备分发最小包。
- 随着美术 / 音频资源增加体积会增长；当前色块占位阶段，体积接近空工程基线。

## 运行

1. 安装 [Godot 4.3](https://godotengine.org/download)
2. 用 Godot 打开本目录 `project.godot`
3. 按 F5 运行（主场景 `scenes/select.tscn`：选人 → 游戏）

命令行无头运行（服务器/CI 验证）：

```bash
godot --headless --path . --quit
```

## 目录结构

```
hot-blood-zombie/
├── project.godot          # 工程配置（主场景 select.tscn，autoload：InputSetup/Economy/Achievements/CharacterData）
├── icon.svg
├── scenes/                # select / main / player / zombie / bullet / hud / touch_controls
│                          # level1~3 / vehicle / grenade / item_pickup / shop
│                          # achievement_panel / pause_menu / elite / boss
├── scripts/
│   ├── input_setup.gd     # autoload：代码注册输入映射
│   ├── game.gd            # 波次生成、关卡推进、商店/成就/暂停接线、精英与 Boss 生成
│   ├── player.gd          # 主角：移动/跳跃/射击/近战/必杀/受击/角色倍率注入/2P 人机 AI
│   ├── zombie.gd          # 丧尸：三类 AI、吸血、躲避、包围、半尸化、收服求饶
│   ├── enemy_defs.gd      # 能力值数据表（玩家 1 / 小怪 0.5 爆发 2~3 / 精英 4~4.5 / Boss 8.5、吸血率）
│   ├── elite.gd           # 2 种精英（暴走族干部 / 丧尸屠夫）
│   ├── boss.gd            # 街头混混头目：三阶段磨血战 + 弱点窗口
│   ├── economy.gd         # Autoload：金币、黑市商店、技能书
│   ├── achievements.gd    # Autoload：8 成就 + user:// 存档
│   ├── character_data.gd  # Autoload：5 角色倍率
│   ├── level_config.gd    # 3 关数据驱动配置
│   ├── select.gd          # 选人界面（P2 固定电脑）
│   ├── shop.gd / pause_menu.gd / achievement_panel.gd
│   ├── bullet.gd / grenade.gd / vehicle.gd / item_pickup.gd / buff.gd / destructible.gd
│   └── hud.gd             # HUD：血条/能量/弹药/金币/Boss 血条/结算
├── tests/
│   └── smoke.gd           # 冒烟测试（27 项断言，CI 与本地均可运行）
├── docs/
│   └── 热血物语末日丧尸_情报收集总报告.md  # 五线情报调研报告（UI/系统/开源/美术/氛围）
├── .github/workflows/godot-ci.yml  # GitHub Actions：冒烟测试 + 安卓 APK 导出
└── assets/                # 美术与音频占位（当前为程序化色块，可后续替换）
```

## 情报与设计文档

- 《热血物语：末日丧尸 游戏立项规划书》（飞书在线文档，含 HUD 布局示意与版本路线）
- 《热血物语：末日丧尸 故事背景设定》（飞书在线文档，五章推进表）
- 《热血物语：末日丧尸 内容框架与扩展性规划》（飞书在线文档，DLC 三层架构 + 数据外置清单）
- 《热血物语：末日丧尸 情报收集总报告》：见 `docs/` 目录

## 开发路线

- V0.1 原型：核心循环可玩，色块占位
- V0.3：安卓适配（触摸键位、6.9 寸横屏 UI、导出预设）
- V1.0：真实 UI、原创角色动画、武器系统、首关场景、热血四特点（搞笑/格斗连击/物品互动/buff）
- V1.1：载具、收服系统、半尸化变身、本地双人
- V1.2：经济黑市、3 关卡、成就系统、移动端优化、选人环节
- V1.3：怪物战斗深度（吸血、能力框架、躲避/扛伤/包围 AI、精英×2、Boss 磨血战、2P 纯 AI 人机）
- V2.0：第四章白岳工厂 + 终章 Boss 战、DLC 注册表、GitHub 自动打包发布

## 许可

MIT License，见 [LICENSE](LICENSE)。
