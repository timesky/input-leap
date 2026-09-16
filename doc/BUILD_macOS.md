# Input Leap macOS 构建 / 打包 / 安装指南

覆盖两种目标机器：

- **Apple Silicon（arm64）** — macOS 26 及以上
- **Intel（x86_64）** — macOS 11.7 Big Sur

---

## 目录

1. [版本选型（先看这个）](#1-版本选型先看这个)
2. [环境准备](#2-环境准备)
3. [构建](#3-构建)
4. [打包（dmg）](#4-打包dmg)
5. [安装与授权](#5-安装与授权)
6. [验证](#6-验证)
7. [故障排查](#7-故障排查)
8. [升级已部署的机器](#8-升级已部署的机器)

---

## 1. 版本选型（先看这个）

### 1.1 Qt 版本由**目标系统**决定，选错直接跑不起来

| 目标机器 | 架构 | 能用的 Qt | 备注 |
|---|---|---|---|
| macOS 26+ (M 系列) | arm64 | **Qt 6.9.x** | 已验证 6.9.0 |
| macOS 11.7 Big Sur (Intel) | x86_64 | **Qt 6.5.x（必须）** | Qt ≥ 6.6 跑不了 Big Sur |

依据（Qt 官方 supported-platforms）：

- Qt **6.5**：Target Platform = *macOS 11 or higher*
- Qt **6.8**：Target Platform = *macOS 12 or higher*
- Qt 6.9.0 实测 `minos 12.0`

可以自己验证：

```bash
otool -l <Qt>/lib/QtCore.framework/QtCore | grep -A3 LC_BUILD_VERSION | grep minos
```

### 1.2 哪些程序依赖 Qt

| 程序 | 作用 | 依赖 Qt |
|---|---|---|
| `input-leap` | GUI | **是** |
| `input-leaps` | 服务端 | 否 |
| `input-leapc` | 客户端 | 否 |

推论：

- 服务端如果只用命令行跑 `input-leaps`，Qt 版本不受 1.1 约束
- **用 GUI 就必须满足 1.1 的版本要求**

### 1.3 交叉编译不可行

在 Apple Silicon 上交叉编译 x86_64 会在链接 OpenSSL 时失败——Homebrew 的 `openssl@3` 只有 arm64 切片：

```bash
lipo -archs /opt/homebrew/Cellar/openssl@3/*/lib/libcrypto.a   # 输出: arm64
```

**Intel 版本请在 Intel 机器上原生构建。**

---

## 2. 环境准备

### 2.1 通用依赖

```bash
xcode-select --install
brew install cmake openssl@3
```

Homebrew 前缀：Apple Silicon 是 `/opt/homebrew`，Intel 是 `/usr/local`。

Big Sur 上 Xcode Command Line Tools 最高只能装 **13.2.1**。

### 2.2 获取源码

```bash
git clone <仓库地址> input-leap
cd input-leap
git checkout <目标分支>
git submodule update --init --recursive
```

### 2.3 安装 Qt

**不要用 `brew install qt@6`** —— 它只装最新版（6.9），在 Big Sur 上用不了。用 `aqtinstall` 装指定版本：

```bash
pip3 install aqtinstall

# 查看可用版本/架构名
aqt list-qt mac desktop

# Apple Silicon (arm64) / macOS 26
aqt install-qt mac desktop 6.9.0 clang_64 -O ~/Qt-6.9.0

# Intel (x86_64) / Big Sur —— 必须 6.5.x
aqt install-qt mac desktop 6.5.3 clang_64 -O ~/Qt-6.5.0
```

验证：

```bash
# 架构
lipo -archs ~/Qt-6.9.0/6.9.0/macos/lib/QtCore.framework/QtCore

# 最低系统版本（Big Sur 目标必须 <= 11.x）
otool -l ~/Qt-6.5.3/6.5.3/macos/lib/QtCore.framework/QtCore \
  | grep -A3 LC_BUILD_VERSION | grep minos
```

---

## 3. 构建

### 3.1 Apple Silicon（arm64）

```bash
cd input-leap
mkdir -p build-arm64 && cd build-arm64

cmake \
  -DCMAKE_BUILD_TYPE=Release \
  -DCMAKE_OSX_ARCHITECTURES=arm64 \
  -DCMAKE_OSX_DEPLOYMENT_TARGET=11.0 \
  -DCMAKE_OSX_SYSROOT=/Library/Developer/CommandLineTools/SDKs/MacOSX15.sdk \
  -DCMAKE_PREFIX_PATH="$HOME/Qt-6.9.0/6.9.0/macos" \
  -DINPUTLEAP_BUILD_GUI=ON \
  -DINPUTLEAP_BUILD_TESTS=OFF \
  ..

make -j$(sysctl -n hw.ncpu)
```

### 3.2 Intel（x86_64 / Big Sur）

```bash
cd input-leap
mkdir -p build-x86_64 && cd build-x86_64

cmake \
  -DCMAKE_BUILD_TYPE=Release \
  -DCMAKE_OSX_ARCHITECTURES=x86_64 \
  -DCMAKE_OSX_DEPLOYMENT_TARGET=11.0 \
  -DCMAKE_PREFIX_PATH="$HOME/Qt-6.5.3/6.5.3/macos" \
  -DOPENSSL_ROOT_DIR=/usr/local/opt/openssl@3 \
  -DINPUTLEAP_BUILD_GUI=ON \
  -DINPUTLEAP_BUILD_TESTS=OFF \
  ..

make -j$(sysctl -n hw.ncpu)
```

> Intel 上 `CMAKE_OSX_SYSROOT` 一般不用指定（原生 SDK 就是 11.x，不会遇到 `library 'c++' not found`）。
> 如果 CMake 找不到 OpenSSL，显式加 `-DOPENSSL_ROOT_DIR=/usr/local/opt/openssl@3`。

### 3.3 CMake 选项说明

| 选项 | 说明 |
|---|---|
| `CMAKE_BUILD_TYPE` | `Release` 才生成 dmg；`Debug` 只生成 bundle |
| `CMAKE_OSX_ARCHITECTURES` | `arm64` / `x86_64` / `x86_64;arm64` |
| `CMAKE_OSX_DEPLOYMENT_TARGET` | **必设**。不设的话产物 `minos` 会等于当前 SDK 版本（如 15.4），目标机器跑不了。Big Sur 填 `11.0` |
| `CMAKE_OSX_SYSROOT` | 遇到 `library 'c++' not found` 时指向 `MacOSX15.sdk` |
| `CMAKE_PREFIX_PATH` | Qt 安装路径（`<Qt>/<版本>/macos`） |
| `OPENSSL_ROOT_DIR` | Intel Homebrew 上可能需要显式指定 |
| `INPUTLEAP_BUILD_GUI` | 打包含 GUI 时保持 `ON` |
| `INPUTLEAP_BUILD_TESTS` | **打包必须 `OFF`**，否则 `unittests` / `integtests` / `guiunittests` 会被一起塞进发布包 |

---

## 4. 打包（dmg）

### 4.1 打包是自动的，不要手动跑脚本

`CMakeLists.txt` 已经把 `build_dist.sh` 挂成了 `InputLeap_MacOS` 目标，属于 `ALL`：

```cmake
add_custom_target(InputLeap_MacOS ALL
                  bash build_dist.sh
                  DEPENDS input-leap input-leaps input-leapc
                  WORKING_DIRECTORY ${INPUTLEAP_BUNDLE_DIR})
```

所以上面 `make` 的时候它**已经执行过了**。产物目录：

```bash
ls -lh build-arm64/bundle/          # 或 build-x86_64/bundle/
```

- `Release`：调 `macdeployqt` 生成 `InputLeap-<版本>.dmg`
- `Debug`：只生成 `InputLeap.app`，并提示 `Disk image (dmg) only created for Release builds`

### 4.2 ⚠️ 不要用 `bundle/build_installer.sh`

它已废弃且是坏的，会把 bundle 搞坏：

1. 脚本里的 `QT_PLATFORM_PLUGIN-NOTFOUND` 是 CMake `find_library` 的失败标记被原样替换进去的，`cp` 会直接报错退出
2. 更严重的是它**先 `rm -rf InputLeap.app/Contents/MacOS`**，再用 `cp build/bin/*` 重建，然后在报错处退出 —— **后面的 `reref_dylibs.sh` 根本没执行，bundle 的 rpath 会被永久破坏**

如果 bundle 已经被它弄坏，删掉重建即可：

```bash
rm -rf build-arm64/bundle
cd build-arm64 && cmake .. && make -j$(sysctl -n hw.ncpu)
```

### 4.3 ⚠️ 代码签名（最关键的一步，已在脚本里自动处理）

**症状**：App 双击无反应、或从终端运行**立刻退出且完全没有输出**，退出码 **137**（= 128+9，被 `SIGKILL`）。

**原因**：`macdeployqt` 会改写链接了 Qt 的可执行文件的 install name / rpath。**只有 GUI `input-leap` 链接 Qt** —— 所以它的签名在改写后失效，而 `input-leapc` / `input-leaps` 不依赖 Qt、没被改写，签名保持有效。

macOS（尤其是 Apple Silicon）**拒绝执行签名无效的二进制**，会在 exec 阶段直接 `SIGKILL`，进程死得不留任何输出。

自己验证：

```bash
B=build-arm64/bundle/InputLeap.app
for b in input-leap input-leapc input-leaps; do
  printf "%-13s " "$b"
  out=$(codesign -v "$B/Contents/MacOS/$b" 2>&1)
  [ -z "$out" ] && echo "签名有效 ✓" || echo "签名无效 ✗ → $out"
done
```

典型输出（修复前）：

```
input-leap    签名无效 ✗ → code has no resources but signature indicates they must be present
input-leapc   签名有效 ✓
input-leaps   签名有效 ✓
```

**修复**：部署之后、打包 dmg 之前，对整个 app 重签名（没有 Developer ID 就用 ad-hoc `-`）：

```bash
codesign --force --deep --sign - InputLeap.app
```

**`build_dist.sh.in` 已经内置了这一步**，正常情况下 `make` 就会自动完成，不需要你手动执行。
但如果你手工拷过 bundle、或用旧脚本打过包，就需要手动补一次。

> 注意：重签名会改变签名，所以**必须在生成 dmg 之前做**，否则 dmg 里装的是没签名的 app。
> 这也是脚本里不再用 `macdeployqt -dmg`、改成先部署 → 重签名 → 再用 `hdiutil` 打 dmg 的原因。

### 4.4 打包结果自检

```bash
B=build-arm64/bundle/InputLeap.app/Contents/MacOS

# 1. 不该有测试程序
ls "$B"                      # 期望只有 input-leap / input-leapc / input-leaps

# 2. 架构正确
lipo -archs "$B/input-leapc"

# 3. 最低系统版本正确
otool -l "$B/input-leapc" | grep -A3 LC_BUILD_VERSION | grep minos

# 4. 签名有效（重要，见 4.3）
codesign -v ../../bundle/InputLeap.app 2>&1 || echo "签名无效，需要重签名"

# 5. Qt 依赖可解析（GUI）
for lib in $(otool -L "$B/input-leap" | awk 'NR>1{print $1}' | grep "@loader_path"); do
  p=$(echo "$lib" | sed "s|@loader_path|$B|")
  [ -e "$p" ] && echo "OK   $lib" || echo "缺失 $lib"
done

# 6. Qt 平台插件在位
ls ../bundle/InputLeap.app/Contents/PlugIns/platforms/     # 应有 libqcocoa.dylib
```

### 4.5 快速判断 App 起不来的原因

从终端运行 GUI，看**退出码**：

```bash
/Applications/InputLeap.app/Contents/MacOS/input-leap; echo "退出码=$?"
```

| 退出码 | 含义 | 处理 |
|---|---|---|
| **137** | 被 `SIGKILL`，代码签名无效 | 见 4.3，重签名 |
| **1**（无输出） | 辅助功能未授权，程序主动退出 | 见 5.2 |
| 保持运行 | 正常 | — |


---

## 5. 安装与授权

### 5.1 安装步骤

```bash
# 方式一：从 dmg
hdiutil attach build-arm64/bundle/InputLeap-*.dmg
cp -R /Volumes/InputLeap/InputLeap.app /Applications/
hdiutil detach /Volumes/InputLeap

# 方式二：直接拷 bundle
cp -R build-arm64/bundle/InputLeap.app /Applications/
```

**必须放到 `/Applications`**（至少不能是 `/Volumes/`）。
`src/gui/src/main.cpp` 里有硬性检查：从 `/Volumes/`（即挂载的 dmg 里）直接运行会弹
「Please drag InputLeap to the Applications folder」然后退出。

### 5.2 ⚠️ 授予辅助功能权限（不授权 App 会静默退出）

首次打开会弹「InputLeap 想要控制这台电脑」。**如果不授权，程序会立即退出，且 stdout 零输出** —— 看起来完全就是"App 打不开"，非常容易误判成程序有 bug。

手动添加：

> **系统设置 → 隐私与安全性 → 辅助功能 → 点 `+` → 选择 `/Applications/InputLeap.app` → 勾选**

`input-leapc` 是独立二进制，也需要被信任（给父 app 授权通常可以覆盖）。

对应代码：`src/gui/src/main.cpp`

```cpp
if (!checkMacAssistiveDevices())   // 内部调 AXIsProcessTrusted()
{
    return 1;                      // 静默退出
}
```

### 5.3 重新编译后授权会失效（已实测确认）

macOS 按 **app 身份（路径 + 代码签名）** 记录授权。**每次重新编译，二进制签名就变了，旧授权立即失效**，表现为 App 又打不开了。

实测记录（同一路径 `build/bundle/InputLeap.app`，同一份代码）：

| 操作 | GUI 结果 |
|---|---|
| 授权后首次使用 | 正常启动，拉起客户端并连上服务端 |
| `rm -rf build/bundle` + 重新构建后 | **立刻退出，stdout 零输出** |

处理：在辅助功能列表里把 InputLeap **删掉（`−`）再重新添加（`+`）**，然后重新打开 App 并在弹窗里允许。

**结论：长期使用请固定一个位置（推荐 `/Applications`），不要用 `build-*/bundle` 这种每次构建都会重建的路径。** 并且每次替换 app 之后都要重新走一遍 5.2 的授权。

#### 快速判断是不是这个原因

从终端跑 GUI，如果**立刻退出且没有任何输出**，就是被这道权限门拦住了：

```bash
/Applications/InputLeap.app/Contents/MacOS/input-leap
# 立刻返回、无任何输出 → 去 5.2 授权
```


### 5.4 首次连接说明

客户端模式下在 GUI 里填服务端地址（服务器 IP + 端口），点「启动 / Start」。
如果 `autoStart` 已开启且之前启动过，GUI 启动时会自动拉起客户端。

---

## 6. 验证

### 6.1 确认关键修复已编入二进制

```bash
nm -C /Applications/InputLeap.app/Contents/MacOS/input-leapc | grep updateActiveGroupCache
# 有输出 = 已编入
```

### 6.2 确认架构与最低系统版本

```bash
B=/Applications/InputLeap.app/Contents/MacOS
lipo -archs "$B/input-leapc"
otool -l "$B/input-leapc" | grep -A3 LC_BUILD_VERSION | grep minos
```

### 6.3 确认真的连上了服务端

```bash
lsof -nP -iTCP:24801 | grep input
# 期望：
# input-lea  <pid> ... TCP 192.168.x.x:xxxxx->192.168.x.y:24801 (ESTABLISHED)
```

服务端是否在监听：

```bash
nc -z -v <服务端IP> 24801
```

### 6.4 查看客户端实际收到的启动参数

从终端跑 GUI，它会打印拼好的命令（`MainWindow.cpp` 里的 `qDebug() << args`）：

```bash
/Applications/InputLeap.app/Contents/MacOS/input-leap
```

### 6.5 单独测试客户端能否连接（不启动 GUI）

`input-leap` 只在鼠标移到客户端屏幕边缘时才转发输入，所以单独跑客户端不会劫持操作：

```bash
/Applications/InputLeap.app/Contents/MacOS/input-leapc \
  -f --no-tray --debug DEBUG1 --name <屏幕名> --enable-drag-drop --disable-crypto \
  "<服务端IP>:24801"
```

---

## 7. 故障排查

| 现象 | 原因 | 处理 |
|---|---|---|
| App 点不开 / 从终端运行**立刻退出、退出码 137** | **代码签名无效**，被 `SIGKILL` | 见 4.3，`codesign --force --deep --sign - InputLeap.app` |
| App 点不开 / 从终端运行**退出码 1、零输出** | 辅助功能未授权，程序主动退出 | 见 5.2 / 4.5 |
| 弹「Please drag InputLeap to the Applications folder」 | 从 `/Volumes/` 直接运行 | 拷到 `/Applications` |
| 授权过了、签名也没问题但还是打不开 | 重新编译导致签名变化、授权失效 | 见 5.3，辅助功能列表里删掉再重新添加 |
| 连不上服务端 | 先确认 App 真的起来了（`pgrep`）；再确认客户端里填的服务端 IP/端口 | `lsof -nP -iTCP:<端口>`；`nc -z -v <服务端IP> <端口>` |
| dmg 里混进了 `unittests` 等 | 没关测试 | 构建时加 `-DINPUTLEAP_BUILD_TESTS=OFF` |
| 构建报 `library 'c++' not found` | 新 SDK 问题 | 加 `-DCMAKE_OSX_SYSROOT=/Library/Developer/CommandLineTools/SDKs/MacOSX15.sdk` |
| CMake 找不到 Qt | 路径不对 | `-DCMAKE_PREFIX_PATH="<Qt>/<版本>/macos"` |
| 产物在旧系统上跑不起来 | 没设 deployment target | 加 `-DCMAKE_OSX_DEPLOYMENT_TARGET=11.0` 并重新构建 |
| Big Sur 上 GUI 起不来 | Qt 版本 ≥ 6.6 | 换 Qt 6.5.x（见 1.1） |
| 菜单栏托盘图标不显示、菜单栏抖动 | 可能是托盘图标为空导致 NSStatusItem 宽度为 0（**尚未确认**） | 临时规避：关掉自动隐藏，让主窗口常驻 |

### 关于托盘图标问题

如果遇到「托盘图标不显示 + 菜单栏持续抖动」，临时规避是关掉自动隐藏：

```bash
defaults write com.github.InputLeap autoHide -bool false
defaults write com.github.InputLeap minimizeToTray -bool false
```

相关代码在 `src/gui/src/MainWindow.cpp` 的 `createTrayIcon()` 与 `set_icon()`，
图标来自 Qt 资源 `:/res/icons/128x128/input-leap-*-mask.png`。
需要能实际观察界面才能确认根因。

---

## 8. 升级已部署的机器

### 8.1 客户端（arm64，Mac mini）

```bash
# 备份
sudo mv /Applications/InputLeap.app /Applications/InputLeap.app.bak

# 安装新版
cp -R <新构建>/build-arm64/bundle/InputLeap.app /Applications/

# 重新授权辅助功能（见 5.3）
open /Applications/InputLeap.app
```

### 8.2 服务端（x86_64，Big Sur Intel）

在 Intel 机器上构建（见 3.2），然后同样替换 `/Applications/InputLeap.app` 并重新授权。

**只换 `input-leaps` 也可以**（它不依赖 Qt）：把新构建的
`build-x86_64/bin/input-leaps` 覆盖到服务端 `InputLeap.app/Contents/MacOS/input-leaps` 即可，
GUI 不用动。但注意覆盖后整个 bundle 的签名会变化，可能仍需要重新授权。

### 8.3 升级后自检清单

```bash
# 1. 进程在跑
pgrep -fl input-leap

# 2. 连接已建立
lsof -nP -iTCP:24801 | grep input

# 3. 修复已编入
nm -C /Applications/InputLeap.app/Contents/MacOS/input-leapc | grep updateActiveGroupCache
```

---

## 附：为什么不用 Xcode 图形界面

本项目用 CMake + Makefile 构建，Xcode 工程没有维护。请使用本文档的命令行流程。
