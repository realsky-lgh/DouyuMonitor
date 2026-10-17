#!/usr/bin/env bash
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
BUILD_DIR="$REPO_ROOT/native/out/build/linux-x64-release"
PKG_OUTPUT_DIR="$REPO_ROOT/out/packages"

mkdir -p "$PKG_OUTPUT_DIR"

# 1. 确保构建完成
echo "==> 检查并构建 Release 目标..."
cmake --build "$REPO_ROOT/native/out/build/linux-x64-release" --target douyu_monitor_native

if [ ! -f "$BUILD_DIR/douyu_monitor_native" ]; then
    echo "错误: 未找到可执行文件 $BUILD_DIR/douyu_monitor_native"
    exit 1
fi

if [ ! -d "$BUILD_DIR/streamget_service" ]; then
    echo "错误: 未找到解析服务目录 $BUILD_DIR/streamget_service"
    exit 1
fi

# 2. 提取版本号
VERSION=$(grep -m1 "project(DouyuMonitorNative VERSION" "$REPO_ROOT/native/CMakeLists.txt" | sed -E 's/.*VERSION ([0-9.]+).*/\1/')
if [ -z "$VERSION" ]; then
    VERSION="0.2.20"
fi
echo "==> 当前打包版本: $VERSION"

WORK_DIR="$(mktemp -d /tmp/douyu_package_XXXXXX)"
trap 'rm -rf "$WORK_DIR"' EXIT

# 3. 准备图标资源
echo "==> 提取应用各尺寸图标..."
ICON_DIR="$WORK_DIR/icons"
mkdir -p "$ICON_DIR"
python3 -c "
import os
from PIL import Image

ico_path = '$REPO_ROOT/native/app/assets/douyu_monitor.ico'
img = Image.open(ico_path)

sizes = [16, 24, 32, 48, 64, 128, 256, 512]
for s in sizes:
    d = os.path.join('$ICON_DIR', f'{s}x{s}')
    os.makedirs(d, exist_ok=True)
    resized = img.resize((s, s), Image.Resampling.LANCZOS)
    resized.save(os.path.join(d, 'douyu-monitor.png'))

img.save('$ICON_DIR/douyu_monitor.png')
"

# 4. 构建通用 Linux 便携包 (.tar.gz)
echo "==> 构建通用便携归档包 (DouyuMonitor-${VERSION}-linux-x64.tar.gz)..."
PORTABLE_DIR="$WORK_DIR/DouyuMonitor-${VERSION}-linux-x64"
mkdir -p "$PORTABLE_DIR"

cp -r "$BUILD_DIR/douyu_monitor_native" "$PORTABLE_DIR/"
cp -r "$BUILD_DIR/streamget_service" "$PORTABLE_DIR/"
cp -r "$ICON_DIR" "$PORTABLE_DIR/"
cp "$ICON_DIR/douyu_monitor.png" "$PORTABLE_DIR/"

cat > "$PORTABLE_DIR/launch.sh" << 'EOF'
#!/usr/bin/env bash
set -e
APP_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$APP_DIR"

if [[ "$ALL_PROXY" == socks://* ]]; then
    export ALL_PROXY="socks5://${ALL_PROXY#socks://}"
fi
if [[ "$all_proxy" == socks://* ]]; then
    export all_proxy="socks5://${all_proxy#socks://}"
fi

exec "$APP_DIR/douyu_monitor_native" "$@"
EOF
chmod +x "$PORTABLE_DIR/launch.sh"

cat > "$PORTABLE_DIR/install.sh" << 'EOF'
#!/usr/bin/env bash
set -e
SRC_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TARGET_DIR="$HOME/.local/opt/DouyuMonitor"

echo "正在安装斗鱼监控到 $TARGET_DIR ..."
mkdir -p "$TARGET_DIR"
cp -r "$SRC_DIR/douyu_monitor_native" "$TARGET_DIR/"
cp -r "$SRC_DIR/streamget_service" "$TARGET_DIR/"
cp -r "$SRC_DIR/douyu_monitor.png" "$TARGET_DIR/"
cp -r "$SRC_DIR/launch.sh" "$TARGET_DIR/"
chmod +x "$TARGET_DIR/launch.sh" "$TARGET_DIR/douyu_monitor_native"

# 图标安装
if [ -d "$SRC_DIR/icons" ]; then
    for size in 16 24 32 48 64 128 256 512; do
        if [ -f "$SRC_DIR/icons/${size}x${size}/douyu-monitor.png" ]; then
            dest="$HOME/.local/share/icons/hicolor/${size}x${size}/apps"
            mkdir -p "$dest"
            cp "$SRC_DIR/icons/${size}x${size}/douyu-monitor.png" "$dest/"
        fi
    done
    gtk-update-icon-cache -f -t "$HOME/.local/share/icons/hicolor" 2>/dev/null || true
fi

# 桌面快捷方式
DESKTOP_DIR="$HOME/.local/share/applications"
mkdir -p "$DESKTOP_DIR"
cat > "$DESKTOP_DIR/douyu-monitor.desktop" << DESK
[Desktop Entry]
Version=1.0
Type=Application
Name=斗鱼监控
GenericName=Douyu Monitor
Comment=斗鱼多路直播监控客户端
Exec=$TARGET_DIR/launch.sh %U
Icon=douyu-monitor
Terminal=false
Categories=AudioVideo;Player;
Keywords=douyu;monitor;live;stream;tv;斗鱼;直播;监控;
StartupNotify=true
StartupWMClass=douyu_monitor_native
DESK
chmod +x "$DESKTOP_DIR/douyu-monitor.desktop"

if [ -d "$HOME/桌面" ]; then
    cp "$DESKTOP_DIR/douyu-monitor.desktop" "$HOME/桌面/"
    chmod +x "$HOME/桌面/douyu-monitor.desktop"
    gio set "$HOME/桌面/douyu-monitor.desktop" metadata::trusted true 2>/dev/null || true
elif [ -d "$HOME/Desktop" ]; then
    cp "$DESKTOP_DIR/douyu-monitor.desktop" "$HOME/Desktop/"
    chmod +x "$HOME/Desktop/douyu-monitor.desktop"
    gio set "$HOME/Desktop/douyu-monitor.desktop" metadata::trusted true 2>/dev/null || true
fi

update-desktop-database "$HOME/.local/share/applications/" 2>/dev/null || true
echo "安装成功！已在应用菜单和桌面创建快捷方式。"
EOF
chmod +x "$PORTABLE_DIR/install.sh"

cat > "$PORTABLE_DIR/uninstall.sh" << 'EOF'
#!/usr/bin/env bash
set -e
echo "正在卸载斗鱼监控..."
rm -rf "$HOME/.local/opt/DouyuMonitor"
rm -f "$HOME/.local/share/applications/douyu-monitor.desktop"
rm -f "$HOME/桌面/douyu-monitor.desktop" 2>/dev/null || true
rm -f "$HOME/Desktop/douyu-monitor.desktop" 2>/dev/null || true
for size in 16 24 32 48 64 128 256 512; do
    rm -f "$HOME/.local/share/icons/hicolor/${size}x${size}/apps/douyu-monitor.png"
done
update-desktop-database "$HOME/.local/share/applications/" 2>/dev/null || true
echo "已彻底清除斗鱼监控及其快捷方式。"
EOF
chmod +x "$PORTABLE_DIR/uninstall.sh"

cat > "$PORTABLE_DIR/README.txt" << EOF
====================================
斗鱼监控 (DouyuMonitor) Linux 便携版
版本: v${VERSION}
====================================

一、直接运行 (无需安装):
  直接在终端执行:
    ./launch.sh

二、一键安装到系统应用菜单与桌面快捷方式:
  在终端执行:
    ./install.sh
  完成后即可在系统应用程序菜单或桌面双击启动。

三、卸载:
  执行:
    ./uninstall.sh

四、运行依赖要求:
  1. Qt 6 (6.4+) 运行库:
     - Ubuntu/Debian: sudo apt install libqt6quick6 libqt6qml6 libqt6core6 libqt6websockets6 qml6-module-qtquick-controls
     - Arch Linux: sudo pacman -S qt6-base qt6-declarative qt6-websockets
     - Fedora: sudo dnf install qt6-qtbase qt6-qtdeclarative qt6-qtwebsockets
  2. mpv 视频解码核心:
     - Ubuntu/Debian: sudo apt install libmpv2 或 libmpv1
     - Arch Linux: sudo pacman -S mpv
     - Fedora: sudo dnf install mpv-libs
EOF

tar -czf "$PKG_OUTPUT_DIR/DouyuMonitor-${VERSION}-linux-x64.tar.gz" -C "$WORK_DIR" "DouyuMonitor-${VERSION}-linux-x64"

# 5. 构建 Debian / Ubuntu .deb 安装包
echo "==> 构建 Debian/Ubuntu 安装包 (douyu-monitor_${VERSION}_amd64.deb)..."
DEB_ROOT="$WORK_DIR/deb_root"
mkdir -p "$DEB_ROOT/opt/douyu-monitor"
mkdir -p "$DEB_ROOT/usr/share/applications"
mkdir -p "$DEB_ROOT/usr/local/bin"
mkdir -p "$DEB_ROOT/DEBIAN"

cp -r "$BUILD_DIR/douyu_monitor_native" "$DEB_ROOT/opt/douyu-monitor/"
cp -r "$BUILD_DIR/streamget_service" "$DEB_ROOT/opt/douyu-monitor/"
cp "$PORTABLE_DIR/launch.sh" "$DEB_ROOT/opt/douyu-monitor/"
cp "$ICON_DIR/douyu_monitor.png" "$DEB_ROOT/opt/douyu-monitor/"

for size in 16 24 32 48 64 128 256 512; do
    if [ -f "$ICON_DIR/${size}x${size}/douyu-monitor.png" ]; then
        dest="$DEB_ROOT/usr/share/icons/hicolor/${size}x${size}/apps"
        mkdir -p "$dest"
        cp "$ICON_DIR/${size}x${size}/douyu-monitor.png" "$dest/"
    fi
done

cat > "$DEB_ROOT/usr/share/applications/douyu-monitor.desktop" << 'EOF'
[Desktop Entry]
Version=1.0
Type=Application
Name=斗鱼监控
GenericName=Douyu Monitor
Comment=斗鱼多路直播监控与弹幕客户端
Exec=/usr/local/bin/douyu-monitor %U
Icon=douyu-monitor
Terminal=false
Categories=AudioVideo;Player;
Keywords=douyu;monitor;live;stream;tv;斗鱼;直播;监控;
StartupNotify=true
StartupWMClass=douyu_monitor_native
EOF
chmod +x "$DEB_ROOT/usr/share/applications/douyu-monitor.desktop"

# 软链接到 /usr/local/bin
ln -sf "/opt/douyu-monitor/launch.sh" "$DEB_ROOT/usr/local/bin/douyu-monitor"

cat > "$DEB_ROOT/DEBIAN/control" << EOF
Package: douyu-monitor
Version: ${VERSION}
Section: video
Priority: optional
Architecture: amd64
Maintainer: realsky-lgh <realsky-lgh@github.com>
Depends: libc6, libmpv2 | libmpv1, python3
Recommends: qml6-module-qtquick-controls | libqt6quickcontrols2-6
Description: 斗鱼多路直播监控与弹幕客户端
 专为 Linux 打造的高性能斗鱼直播监控工具，支持多路视频硬件解码播放、手机扫码登录、弹幕交互与自发弹幕即时回显。
EOF

cat > "$DEB_ROOT/DEBIAN/postinst" << 'EOF'
#!/bin/sh
set -e
gtk-update-icon-cache -f -t /usr/share/icons/hicolor 2>/dev/null || true
update-desktop-database /usr/share/applications/ 2>/dev/null || true
exit 0
EOF
chmod 755 "$DEB_ROOT/DEBIAN/postinst"

cat > "$DEB_ROOT/DEBIAN/postrm" << 'EOF'
#!/bin/sh
set -e
gtk-update-icon-cache -f -t /usr/share/icons/hicolor 2>/dev/null || true
update-desktop-database /usr/share/applications/ 2>/dev/null || true
exit 0
EOF
chmod 755 "$DEB_ROOT/DEBIAN/postrm"

dpkg-deb --build --root-owner-group "$DEB_ROOT" "$PKG_OUTPUT_DIR/douyu-monitor_${VERSION}_amd64.deb"

# 6. 生成 SHA256 校验码
echo "==> 计算校验和..."
(cd "$PKG_OUTPUT_DIR" && sha256sum DouyuMonitor-${VERSION}-linux-x64.tar.gz douyu-monitor_${VERSION}_amd64.deb > SHA256SUMS.txt)

echo "========================================="
echo "打包全部成功！文件已存放在: $PKG_OUTPUT_DIR"
ls -lh "$PKG_OUTPUT_DIR"
echo "========================================="
