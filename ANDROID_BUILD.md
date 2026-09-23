# 安卓横屏打包说明

本文档说明本工程的安卓横屏配置、虚拟按键方案、CI 自动打包流程，以及本地导出 APK 和手机安装测试的方法。

---

## 1. 横屏配置

横屏由两处配置共同保证，缺一不可：

### `project.godot`（工程级）

```ini
[display]
window/handheld/orientation=1   ; 1 = 强制横屏（0=竖屏, 1=横屏, 2=自动）
```

### `export_presets.cfg`（导出预设级）

```ini
[preset.0]
name="Android"

[preset.0.options]
screen/orientation=1                    ; 1 = 横屏
screen/orientations/landscape=true      ; 允许正向横屏
screen/orientations/landscape_reverse=true  ; 允许反向横屏（180°翻转）
screen/orientations/portrait=false     ; 禁止竖屏
screen/orientations/portrait_reverse=false ; 禁止反向竖屏
```

> 两项均已验证为正确值。修改横屏/竖屏策略时需同时改这两处。

---

## 2. 虚拟按键（触摸控件）

文件：`scripts/touch_controls.gd` + `scenes/touch_controls.tscn`

### 设计原则

- **强制显示**：`_ready()` 中直接 `visible = true`，不做 `OS.has_feature("mobile")` 或触摸设备检测。任何场景实例化 `touch_controls.tscn` 后虚拟按键立即出现。
- **半透明大按钮**：主按钮约 96~120px，背景透明度 0.5~0.85，不遮挡游戏主体。
- **共用 Input Action**：摇杆和按钮通过 `Input.action_press()` / `Input.action_release()` 触发已注册的 action，与键盘输入完全共用同一套映射（定义在 `scripts/input_setup.gd`）。

### 布局

| 位置 | 控件 | 触发的 Action | 说明 |
|------|------|---------------|------|
| 左下角 | 虚拟摇杆 | `move_left` / `move_right`（按住） | 水平移动 |
| 左下角 | 摇杆上推 | `jump`（轻点） | 跳跃 |
| 左下角 | 摇杆下推 | `crouch`（按住） | 下蹲 |
| 右下角 | 大红色按钮 | `shoot` | 射击（主武器） |
| 右下角 | 蓝色按钮 | `jump` | 跳跃 |
| 右下角 | 白色按钮 | `melee` | 近战拳击 |
| 右下角 | 黄色按钮 | `special` | 必杀技 |
| 左上角 | 小按钮 | `crouch` | 下蹲（备用） |
| 右侧中部 | 小按钮 | `crouch` | 互动键 |
| 右上角 | 小按钮 | 自定义回调 | 商店（$） |
| 右上角 | 小按钮 | 自定义回调 | 暂停（II） |
| 右上角 | 小按钮 | `restart` | 重新开始 |

### 键盘对照

| 触屏 | 键盘 |
|------|------|
| 摇杆左右 | A / D 或 ← / → |
| 摇杆上推 / 跳跃键 | W / ↑ / 空格 |
| 摇杆下推 / 下蹲键 | S / ↓ |
| 射击键 | J / 鼠标左键 |
| 近战键 | K |
| 必杀键 | L |
| 重开键 | R |

---

## 3. CI 自动打包流程

工作流文件：`.github/workflows/godot-ci.yml`

### 触发条件

- push 到 `main` / `master` 分支
- 向 `main` / `master` 发起 Pull Request
- push tag（`v*.*.*`）时自动创建 Release 并附带 APK

### 构建步骤

```
test job（barichello/godot-ci:4.3 容器）
  ├── 检出代码
  ├── godot --headless --import          ← 无头导入，检查脚本/场景零错误
  └── godot --headless --script res://tests/smoke.gd  ← 冒烟测试全部断言

export-android job（needs: test，同一镜像）
  ├── 检出代码
  ├── 生成 debug keystore（~/.android/debug.keystore）
  ├── 配置导出模板 + JDK 路径
  ├── godot --headless --export-debug "Android" build/android/hot-blood-zombie.apk
  └── 上传 APK 为 artifact（android-apk）

release job（needs: export-android，仅 push 触发）
  ├── 下载 APK artifact
  └── 创建 GitHub Release 附带 APK
```

### 关键配置确认

| 项目 | 值 |
|------|----|
| Docker 镜像 | `barichello/godot-ci:4.3` |
| Godot 版本 | 4.3 stable |
| 渲染方式 | `gl_compatibility`（移动端兼容） |
| 导出预设名 | `Android`（与 `--export-debug "Android"` 命令一致） |
| APK 输出路径 | `build/android/hot-blood-zombie.apk` |
| Debug keystore | CI 自动生成，alias=`androiddebugkey`，密码=`android` |
| 架构 | arm64-v8a |

> CI 中所有 `godot ... | tail` 管道均加了 `set -euo pipefail`，确保 godot 返回非零时 CI 步骤失败。

---

## 4. 本地导出 APK

### 前置要求

1. **Godot 4.3**（与 CI 镜像版本一致）
2. **Android 导出模板**：Godot 编辑器 → Editor → Manage Export Templates → Download and Install（选择 4.3.stable）
3. **Android SDK / JDK 17**：
   - 安装 Android SDK（命令行工具即可）
   - 安装 JDK 17
   - Godot 编辑器 → Editor Settings → Export → Android：
     - `Java SDK Path`：JDK 安装目录
     - `Android SDK Path`：Android SDK 目录
     - `Debug Keystore`：指向 debug keystore（可用 `keytool` 生成）

### 生成 debug keystore（如没有）

```bash
keytool -keyalg RSA -genkeypair -alias androiddebugkey \
  -keypass android -storepass android \
  -keystore ~/.android/debug.keystore \
  -dname "CN=Android Debug,O=Android,C=US" -validity 9999
```

### 命令行导出

```bash
cd /path/to/hot-blood-zombie

# 1. 无头导入（首次或改动后）
godot --headless --import

# 2. 冒烟测试
godot --headless --path . --script res://tests/smoke.gd

# 3. 导出 debug APK
mkdir -p build/android
godot --headless --export-debug "Android" "build/android/hot-blood-zombie.apk"
```

> 导出前确保 `export_presets.cfg` 中 debug keystore 路径已配置，或通过环境变量传入：
> ```bash
> export GODOT_ANDROID_KEYSTORE_DEBUG_PATH=~/.android/debug.keystore
> export GODOT_ANDROID_KEYSTORE_DEBUG_USER=androiddebugkey
> export GODOT_ANDROID_KEYSTORE_DEBUG_PASSWORD=android
> ```

### 当前环境说明

本开发环境未安装 Godot，无法本地执行 `--import` 或 `--export-debug`。实际打包由 GitHub Actions 完成。如需本地验证，请按上述前置要求安装 Godot 4.3 + Android 导出模板。

---

## 5. 手机安装测试

### 方法一：从 CI Artifact 下载

1. 推送代码到 GitHub 后，进入仓库 **Actions** 页面
2. 等待 "导出安卓 APK" 工作流完成
3. 点击该次运行 → 底部 **Artifacts** → 下载 `android-apk`
4. 解压得到 `hot-blood-zombie.apk`

### 方法二：从 GitHub Release 下载

push tag（如 `v1.1.0`）后，工作流会自动创建 Release 并附带 APK，直接在 Releases 页面下载。

### 安装到手机

```bash
# 手机开启 USB 调试，连接电脑
adb install -r hot-blood-zombie.apk
```

或直接把 APK 传到手机，点击安装（需开启"允许安装未知来源应用"）。

### 验收清单

- [ ] 安装后启动游戏，画面强制横屏显示
- [ ] 左下角虚拟摇杆和右下角按钮自动出现（无需任何操作）
- [ ] 摇杆左右移动角色，上推跳跃，下推下蹲
- [ ] 射击/近战/必杀/跳跃按钮响应正常
- [ ] 按钮半透明，不遮挡画面主体
- [ ] 商店 / 暂停按钮可正常呼出对应界面
