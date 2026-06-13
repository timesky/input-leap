#!/bin/bash
#
# Input Leap 构建脚本 - macOS 11.7 Intel (x86_64)
#
# 使用方法:
#   ./scripts/build-macos-intel.sh [选项]
#
# 选项:
#   --debug        构建 Debug 版本
#   --no-gui       不构建 GUI
#   --qt-path PATH 指定 Qt 安装路径
#
# 系统要求:
#   - macOS 11.7 Big Sur
#   - Xcode 13.2.1 或 Command Line Tools
#   - Homebrew
#

set -e

# 颜色输出
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

log_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# 默认配置
BUILD_TYPE="Release"
BUILD_GUI="ON"
QT_PATH=""

# 解析参数
while [[ $# -gt 0 ]]; do
    case $1 in
        --debug)
            BUILD_TYPE="Debug"
            shift
            ;;
        --no-gui)
            BUILD_GUI="OFF"
            shift
            ;;
        --qt-path)
            QT_PATH="$2"
            shift 2
            ;;
        *)
            log_error "未知参数: $1"
            exit 1
            ;;
    esac
done

log_info "======================================"
log_info "Input Leap 构建脚本 - macOS Intel"
log_info "======================================"
log_info "构建类型: $BUILD_TYPE"
log_info "构建 GUI: $BUILD_GUI"

# 检测架构
ARCH=$(uname -m)
if [[ "$ARCH" != "x86_64" ]]; then
    log_warn "当前架构是 $ARCH，此脚本用于 x86_64 构建"
fi

# 检查 Command Line Tools
log_info "检查 Xcode Command Line Tools..."
if ! xcode-select -p &>/dev/null; then
    log_error "未安装 Xcode Command Line Tools"
    log_info "请运行: xcode-select --install"
    exit 1
fi

# 检查 Homebrew
log_info "检查 Homebrew..."
if ! command -v brew &>/dev/null; then
    log_error "未安装 Homebrew"
    log_info "请访问: https://brew.sh/"
    exit 1
fi

# Homebrew 路径 (Intel Mac 使用 /usr/local)
BREW_PREFIX="/usr/local"

# 检查 CMake
log_info "检查 CMake..."
if ! command -v cmake &>/dev/null; then
    log_info "安装 CMake..."
    brew install cmake
fi

# 检查 OpenSSL
log_info "检查 OpenSSL..."
if [[ ! -d "$BREW_PREFIX/opt/openssl@3" ]]; then
    log_info "安装 OpenSSL..."
    brew install openssl@3
fi

# 检查 Qt
log_info "检查 Qt..."
if [[ -n "$QT_PATH" ]]; then
    log_info "使用指定的 Qt 路径: $QT_PATH"
elif [[ -d "$BREW_PREFIX/opt/qt@6" ]]; then
    QT_PATH="$BREW_PREFIX"
    log_info "使用 Homebrew 安装的 Qt"
elif [[ -d "$HOME/Qt-6.5.0/6.5.0/macos" ]]; then
    QT_PATH="$HOME/Qt-6.5.0/6.5.0/macos"
    log_info "使用 aqtinstall 安装的 Qt"
else
    log_info "未找到 Qt，正在安装..."

    # 尝试使用 aqtinstall
    if command -v pip3 &>/dev/null; then
        log_info "安装 aqtinstall..."
        pip3 install aqtinstall

        log_info "安装 Qt 6.5.0..."
        aqt install-qt mac desktop 6.5.0 clang_64 -O ~/Qt-6.5.0
        QT_PATH="$HOME/Qt-6.5.0/6.5.0/macos"
    else
        log_info "使用 Homebrew 安装 Qt..."
        brew install qt@6
        QT_PATH="$BREW_PREFIX"
    fi
fi

# 检查子模块
log_info "检查 Git 子模块..."
if [[ -f ".gitmodules" ]]; then
    git submodule update --init --recursive
fi

# 创建构建目录
BUILD_DIR="build-x86_64"
log_info "创建构建目录: $BUILD_DIR"
rm -rf "$BUILD_DIR"
mkdir -p "$BUILD_DIR"
cd "$BUILD_DIR"

# 配置 CMake
log_info "配置 CMake..."
cmake \
    -DCMAKE_BUILD_TYPE="$BUILD_TYPE" \
    -DCMAKE_OSX_ARCHITECTURES="x86_64" \
    -DCMAKE_OSX_DEPLOYMENT_TARGET=11.0 \
    -DCMAKE_PREFIX_PATH="$QT_PATH" \
    -DOPENSSL_ROOT_DIR="$BREW_PREFIX/opt/openssl@3" \
    -DINPUTLEAP_BUILD_GUI="$BUILD_GUI" \
    -DINPUTLEAP_BUILD_TESTS=ON \
    ..

# 构建
NPROC=$(sysctl -n hw.ncpu)
log_info "开始构建 (使用 $NPROC 个核心)..."
make -j$NPROC

# 检查构建结果
log_info "检查构建结果..."
if [[ -f "bin/input-leaps" ]]; then
    log_info "构建成功!"
    log_info ""
    log_info "构建产物:"
    ls -la bin/

    if [[ "$BUILD_GUI" == "ON" ]] && [[ -f "bundle/"*.dmg ]]; then
        log_info ""
        log_info "DMG 安装包:"
        ls -la bundle/*.dmg
    fi

    # 运行测试
    log_info ""
    log_info "运行单元测试..."
    ./bin/unittests --gtest_filter="*OSX*" 2>&1 | tail -20
else
    log_error "构建失败!"
    exit 1
fi
