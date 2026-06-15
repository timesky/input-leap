# Input Leap 构建指南

本文档提供 macOS 平台的完整构建说明，支持：
- **macOS 11.7 Big Sur (Intel x86_64)**
- **macOS 26+ (Apple Silicon arm64)**

---

## 目录

1. [macOS 11.7 Intel 构建指南](#macos-117-intel-构建指南)
2. [macOS 26+ M 系列构建指南](#macos-26-m-系列构建指南)
3. [构建脚本](#构建脚本)
4. [创建 Universal Binary](#创建-universal-binary)
5. [常见问题](#常见问题)

---

## macOS 11.7 Intel 构建指南

### 系统要求

| 项目 | 要求 |
|------|------|
| 操作系统 | macOS 11.7 Big Sur |
| Xcode | 13.2.1 (最高支持版本) |
| 处理器 | Intel x86_64 |

### 步骤 1: 安装 Xcode Command Line Tools

打开终端，执行：

```bash
xcode-select --install
```

在弹出的对话框中点击"安装"。完成后验证：

```bash
xcode-select -p
# 应输出: /Library/Developer/CommandLineTools
```

### 步骤 2: 安装 Homebrew

如果尚未安装 Homebrew：

```bash
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
```

安装后添加到 PATH（根据提示操作，通常是）：

```bash
echo 'eval "$(/usr/local/bin/brew shellenv)"' >> ~/.zprofile
eval "$(/usr/local/bin/brew shellenv)"
```

验证安装：

```bash
brew --version
```

### 步骤 3: 安装构建依赖

```bash
# 安装 CMake
brew install cmake

# 验证 CMake 版本 (需要 3.21+)
cmake --version
```

### 步骤 4: 安装 Qt 6

#### 方法 A: 使用 aqtinstall (推荐)

aqtinstall 可以安装特定版本的 Qt，更可控：

```bash
# 安装 aqtinstall
pip3 install aqtinstall

# 安装 Qt 6.5.0 (推荐，兼容 macOS 11.0+)
aqt install-qt mac desktop 6.5.0 clang_64 -O ~/Qt-6.5.0

# 验证安装
ls ~/Qt-6.5.0/6.5.0/macos/lib/QtCore.framework/QtCore
```

#### 方法 B: 使用 Homebrew

```bash
brew install qt@6
```

注意：Homebrew 安装的 Qt 版本可能较新，确保兼容性。

### 步骤 5: 安装 OpenSSL

```bash
brew install openssl@3
```

### 步骤 6: 克隆代码

```bash
# 克隆仓库
cd ~/Workspace
git clone https://github.com/input-leap/input-leap.git
cd input-leap

# 切换到修复分支 (如果有的话)
git checkout fix/macos-command-mapping

# 初始化子模块
git submodule update --init --recursive
```

### 步骤 7: 构建

#### 使用 aqtinstall 安装的 Qt：

```bash
mkdir build && cd build

cmake \
  -DCMAKE_BUILD_TYPE=Release \
  -DCMAKE_OSX_ARCHITECTURES="x86_64" \
  -DCMAKE_OSX_DEPLOYMENT_TARGET=11.0 \
  -DCMAKE_PREFIX_PATH="$HOME/Qt-6.5.0/6.5.0/macos" \
  -DOPENSSL_ROOT_DIR=/usr/local/opt/openssl@3 \
  ..

make -j$(sysctl -n hw.ncpu)
```

#### 使用 Homebrew 安装的 Qt：

```bash
mkdir build && cd build

cmake \
  -DCMAKE_BUILD_TYPE=Release \
  -DCMAKE_OSX_ARCHITECTURES="x86_64" \
  -DCMAKE_OSX_DEPLOYMENT_TARGET=11.0 \
  -DCMAKE_PREFIX_PATH="/usr/local" \
  ..

make -j$(sysctl -n hw.ncpu)
```

### 步骤 8: 查找构建产物

构建完成后：

```bash
# DMG 安装包
ls -la build/bundle/*.dmg

# 可执行文件
ls -la build/bin/
# - input-leap   (GUI 应用)
# - input-leaps  (服务端)
# - input-leapc  (客户端)
```

---

## macOS 26+ M 系列构建指南

### 系统要求

| 项目 | 要求 |
|------|------|
| 操作系统 | macOS 26+ |
| Xcode | 最新版本 |
| 处理器 | Apple Silicon (M1/M2/M3/M4) |

### 步骤 1: 安装 Xcode Command Line Tools

```bash
xcode-select --install
```

### 步骤 2: 安装 Homebrew

```bash
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"

# 添加到 PATH
echo 'eval "$(/opt/homebrew/bin/brew shellenv)"' >> ~/.zprofile
eval "$(/opt/homebrew/bin/brew shellenv)"
```

### 步骤 3: 安装构建依赖

```bash
brew install cmake qt@6 openssl@3
```

### 步骤 4: 克隆代码

```bash
cd ~/Workspace
git clone https://github.com/input-leap/input-leap.git
cd input-leap
git checkout fix/macos-command-mapping
git submodule update --init --recursive
```

### 步骤 5: 构建

```bash
mkdir build && cd build

cmake \
  -DCMAKE_BUILD_TYPE=Release \
  -DCMAKE_OSX_ARCHITECTURES="arm64" \
  -DCMAKE_OSX_DEPLOYMENT_TARGET=11.0 \
  -DCMAKE_PREFIX_PATH="/opt/homebrew" \
  ..

make -j$(sysctl -n hw.ncpu)
```

### 步骤 6: 查找构建产物

```bash
ls -la build/bundle/*.dmg
ls -la build/bin/
```

---

## 构建脚本

项目提供了自动化构建脚本，位于 `scripts/` 目录。

### 在 macOS 11.7 Intel 上运行

```bash
cd input-leap
./scripts/build-macos-intel.sh
```

### 在 macOS 26+ M 系列上运行

```bash
cd input-leap
./scripts/build-macos-arm64.sh
```

---

## 创建 Universal Binary

如果你有两台机器分别构建了 x86_64 和 arm64 版本，可以合并为 Universal Binary。

### 步骤 1: 复制构建产物

将两边的 `build/bin/` 目录内容复制到同一台机器：

```
input-leap/
├── build-arm64/
│   └── bin/
│       ├── input-leap
│       ├── input-leapc
│       └── input-leaps
└── build-x86_64/
    └── bin/
        ├── input-leap
        ├── input-leapc
        └── input-leaps
```

### 步骤 2: 合并二进制文件

```bash
# 创建输出目录
mkdir -p build-universal/bin

# 合并每个二进制文件
for binary in input-leap input-leapc input-leaps; do
  lipo -create \
    build-x86_64/bin/$binary \
    build-arm64/bin/$binary \
    -output build-universal/bin/$binary
done

# 验证
lipo -archs build-universal/bin/input-leaps
# 应输出: x86_64 arm64
```

### 步骤 3: 创建 DMG

合并后需要重新打包 DMG，可使用 `create-dmg` 工具或手动创建。

---

## 常见问题

### Q: CMake 找不到 Qt

**A:** 确保 `CMAKE_PREFIX_PATH` 指向正确的 Qt 安装目录：

```bash
# aqtinstall 安装的 Qt
-DCMAKE_PREFIX_PATH="$HOME/Qt-6.5.0/6.5.0/macos"

# Homebrew 安装的 Qt (Intel Mac)
-DCMAKE_PREFIX_PATH="/usr/local"

# Homebrew 安装的 Qt (M 系列 Mac)
-DCMAKE_PREFIX_PATH="/opt/homebrew"
```

### Q: Qt 框架部署问题 (Library not loaded: @rpath/Qt*.framework)

**A:** 使用官方 Qt 安装而非 Homebrew Qt，避免框架依赖问题：

```bash
# 1. 卸载 Homebrew Qt (如果已安装)
brew uninstall qt

# 2. 使用 aqtinstall 安装官方 Qt
pip3 install aqtinstall
aqt install-qt mac desktop 6.9.0 clang_64 -O ~/Qt

# 3. 构建时指定官方 Qt 路径
cmake -DCMAKE_PREFIX_PATH="$HOME/Qt/6.9.0/macos" ..

# 4. 构建后使用官方 macdeployqt 部署框架
~/Qt/6.9.0/macos/bin/macdeployqt build/bundle/InputLeap.app \
  -executable=build/bundle/InputLeap.app/Contents/MacOS/input-leapc \
  -executable=build/bundle/InputLeap.app/Contents/MacOS/input-leaps
```

**原因：** Homebrew Qt 可能缺少某些框架 (如 QtDBus)，或版本不匹配导致运行时找不到库。

### Q: 链接错误: library 'c++' not found

**A:** 这是 macOS 26 SDK 的问题。使用较旧的 SDK：

```bash
-DCMAKE_OSX_SYSROOT=/Library/Developer/CommandLineTools/SDKs/MacOSX15.sdk
```

### Q: Xcode 版本太旧

**A:** macOS 11.7 支持的最高 Xcode 版本是 13.2.1。可从 Apple Developer 网站下载：

https://developer.apple.com/download/all/?q=xcode%2013.2.1

### Q: Qt 版本不兼容

**A:** 使用 aqtinstall 安装特定版本：

```bash
# 查看可用版本
aqt list-qt mac desktop

# 安装特定版本
aqt install-qt mac desktop 6.5.0 clang_64 -O ~/Qt-6.5.0
```

### Q: OpenSSL 链接错误

**A:** 确保 OpenSSL 路径正确：

```bash
# Intel Mac
-DCMAKE_PREFIX_PATH="/usr/local/opt/openssl@3"

# M 系列 Mac
-DCMAKE_PREFIX_PATH="/opt/homebrew/opt/openssl@3"
```

---

## 构建选项说明

| 选项 | 说明 |
|------|------|
| `CMAKE_BUILD_TYPE` | `Release` 或 `Debug` |
| `CMAKE_OSX_ARCHITECTURES` | `x86_64`、`arm64` 或 `x86_64;arm64` |
| `CMAKE_OSX_DEPLOYMENT_TARGET` | 最低支持的 macOS 版本 |
| `INPUTLEAP_BUILD_GUI` | 是否构建 GUI (ON/OFF) |
| `INPUTLEAP_BUILD_TESTS` | 是否构建测试 (ON/OFF) |

---

## 相关链接

- [Input Leap GitHub](https://github.com/input-leap/input-leap)
- [Qt 下载](https://www.qt.io/download)
- [aqtinstall 文档](https://aqtinstall.readthedocs.io/)
- [Homebrew](https://brew.sh/)
