#!/usr/bin/env bash
set -e

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
BUILD_DIR="$REPO_ROOT/native/out/build/linux-x64-release"
TARGET_DIR="$HOME/.local/opt/DouyuMonitor"

if [ ! -f "$BUILD_DIR/douyu_monitor_native" ]; then
    echo "未找到构建产物，正在构建..."
    cmake --build --preset linux-x64-release --target douyu_monitor_native
fi

echo "正在安装到 $TARGET_DIR ..."
mkdir -p "$TARGET_DIR"
cp --remove-destination -r "$BUILD_DIR/douyu_monitor_native" "$TARGET_DIR/"
cp --remove-destination -r "$BUILD_DIR/streamget_service" "$TARGET_DIR/"

python3 -c "
import os
from PIL import Image

ico_path = '$REPO_ROOT/native/app/assets/douyu_monitor.ico'
img = Image.open(ico_path)

sizes = [16, 24, 32, 48, 64, 128, 256, 512]
base_dir = os.path.expanduser('~/.local/share/icons/hicolor')

for s in sizes:
    d = os.path.join(base_dir, f'{s}x{s}', 'apps')
    os.makedirs(d, exist_ok=True)
    resized = img.resize((s, s), Image.Resampling.LANCZOS)
    resized.save(os.path.join(d, 'douyu-monitor.png'))

img.save('$TARGET_DIR/douyu_monitor.png')
"
gtk-update-icon-cache -f -t "$HOME/.local/share/icons/hicolor" 2>/dev/null || true

cat > "$TARGET_DIR/launch.sh" << 'EOF'
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

chmod +x "$TARGET_DIR/launch.sh"

DESKTOP_ENTRY="$HOME/.local/share/applications/douyu-monitor.desktop"
cat > "$DESKTOP_ENTRY" << EOF
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
EOF

chmod +x "$DESKTOP_ENTRY"
if [ -d "$HOME/桌面" ]; then
    cp "$DESKTOP_ENTRY" "$HOME/桌面/"
    chmod +x "$HOME/桌面/douyu-monitor.desktop"
    gio set "$HOME/桌面/douyu-monitor.desktop" metadata::trusted true 2>/dev/null || true
fi

update-desktop-database "$HOME/.local/share/applications/" 2>/dev/null || true
echo "安装完成！可在系统应用菜单或桌面上启动'斗鱼监控'。"
