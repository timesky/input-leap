#!/bin/bash
#
# Input Leap 构建脚本 - macOS 26+ M 系列 (arm64)
#
# 使用方法:
#   ./scripts/build-macos-arm64.sh [选项]
#
# 选项:
#   --debug        构建 Debug 版本
#   --no-gui       不构建 GUI
#   --universal    尝试构建 Universal Binary (需要 Qt Universal)
#
# 系统要求:
#   - macOS 26+
#   - Xcode 或 Command Line Tools
#   - Homebrew (Apple Silicon 版本)
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
BUILD_UNIVERSAL="OFF"

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
        --universal)
            BUILD_UNIVERSAL="ON"
            shift
            ;;
        *)
            log_error "未知参数: $1"
            exit 1
            ;;
    esac
done

log_info "======================================"
log_info "Input Leap 构建脚本 - macOS M 系列"
log_info "======================================"
log_info "构建类型: $BUILD_TYPE"
log_info "构建 GUI: $BUILD_GUI"
log_info "Universal Binary: $BUILD_UNIVERSAL"

# 检测架构
ARCH=$(uname -m)
if [[ "$ARCH" != "arm64" ]]; then
    log_warn "当前架构是 $ARCH，此脚本用于 arm64 构建"
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

# Homebrew 路径 (M 系列使用 /opt/homebrew)
BREW_PREFIX="/opt/homebrew"

# 检查构建依赖
log_info "检查构建依赖..."
DEPS_NEEDED=0

if ! command -v cmake &>/dev/null; then
    log_info "需要安装: cmake"
    DEPS_NEEDED=1
fi

if [[ ! -d "$BREW_PREFIX/opt/qt@6" ]]; then
    log_info "需要安装: qt@6"
    DEPS_NEEDED=1
fi

if [[ ! -d "$BREW_PREFIX/opt/openssl@3" ]]; then
    log_info "需要安装: openssl@3"
    DEPS_NEEDED=1
fi

if [[ $DEPS_NEEDED -eq 1 ]]; then
    log_info "安装缺失的依赖..."
    brew install cmake qt@6 openssl@3
fi

# 检查子模块
log_info "检查 Git 子模块..."
if [[ -f ".gitmodules" ]]; then
    git submodule update --init --recursive
fi

# 确定架构
if [[ "$BUILD_UNIVERSAL" == "ON" ]]; then
    ARCHITECTURES="x86_64;arm64"
    log_warn "Universal Binary 构建需要 Qt 和 OpenSSL 的 Universal 版本"
    log_warn "Homebrew 安装的依赖可能不支持 Universal Binary"

    # 检查是否有 Qt Universal
    if [[ -d "$HOME/Qt-6.9.0/6.9.0/macos" ]]; then
        QT_PATH="$HOME/Qt-6.9.0/6.9.0/macos"
        log_info "使用 Qt Universal: $QT_PATH"
    else
        log_error "未找到 Qt Universal 版本"
        log_info "请安装 Qt Universal:"
        log_info "  pip3 install aqtinstall"
        log_info "  aqt install-qt mac desktop 6.9.0 clang_64 -O ~/Qt-6.9.0"
        exit 1
    fi
else
    ARCHITECTURES="arm64"
    QT_PATH="$BREW_PREFIX"
fi

# 创建构建目录
if [[ "$BUILD_UNIVERSAL" == "ON" ]]; then
    BUILD_DIR="build-universal"
else
    BUILD_DIR="build-arm64"
fi

log_info "创建构建目录: $BUILD_DIR"
rm -rf "$BUILD_DIR"
mkdir -p "$BUILD_DIR"
cd "$BUILD_DIR"

# 查找合适的 SDK
SDK_PATH=""
if [[ -d "/Library/Developer/CommandLineTools/SDKs/MacOSX15.sdk" ]]; then
    SDK_PATH="/Library/Developer/CommandLineTools/SDKs/MacOSX15.sdk"
    log_info "使用 SDK: macOS 15"
elif [[ -d "/Library/Developer/CommandLineTools/SDKs/MacOSX.sdk" ]]; then
    SDK_PATH="/Library/Developer/CommandLineTools/SDKs/MacOSX.sdk"
    log_info "使用 SDK: 默认"
fi

# 配置 CMake
log_info "配置 CMake..."
CMAKE_ARGS=(
    -DCMAKE_BUILD_TYPE="$BUILD_TYPE"
    -DCMAKE_OSX_ARCHITECTURES="$ARCHITECTURES"
    -DCMAKE_OSX_DEPLOYMENT_TARGET=11.0
    -DCMAKE_PREFIX_PATH="$QT_PATH"
    -DINPUTLEAP_BUILD_GUI="$BUILD_GUI"
    -DINPUTLEAP_BUILD_TESTS=ON
)

if [[ -n "$SDK_PATH" ]]; then
    CMAKE_ARGS+=(-DCMAKE_OSX_SYSROOT="$SDK_PATH")
fi

cmake "${CMAKE_ARGS[@]}" ..

# 构建
NPROC=$(sysctl -n hw.ncpu)
log_info "开始构建 (使用 $NPROC 个核心)..."
make -j$NPROC

# 检查构建结果
log_info "检查构建结果..."
if [[ -f "bin/input-leaps" ]]; then
    log_info "构建成功!"

    # 显示架构
    log_info ""
    log_info "二进制架构:"
    for bin in input-leap input-leaps input-leapc; do
        if [[ -f "bin/$bin" ]]; then
            archs=$(lipo -archs "bin/$bin" 2>/dev/null || echo "N/A")
            log_info "  $bin: $archs"
        fi
    done

    log_info ""
    log_info "构建产物:"
    ls -la bin/

    if [[ "$BUILD_GUI" == "ON" ]] && compgen -G "bundle/*.dmg" > /dev/null; then
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
