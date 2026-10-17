# 斗鱼监控 (DouyuMonitor) Linux 客户端使用指南

本文档介绍如何在主流 Linux 发行版（Ubuntu、Debian、Linux Mint、Arch Linux、Fedora、openSUSE 等）上安装、配置与使用**斗鱼监控**客户端。

---

## 1. 系统要求与运行环境

- **操作系统**: 64位 Linux (x86_64 / amd64)
- **桌面环境**: GNOME、KDE Plasma、XFCE 等主流 X11 / Wayland 桌面
- **核心依赖**:
  - **Qt 6**: 6.4 或更高版本（核心/界面/网络/WebSocket）
  - **libmpv**: `libmpv.so.2` 或 `libmpv.so.1`（用于多路高性能视频硬解播放）
  - **Python 3**: 内置解析服务已打包，系统只需具备基本 Python 3 运行支持即可

### 各发行版依赖安装命令

#### Ubuntu / Debian / Linux Mint / Deepin / UOS
```bash
sudo apt update
sudo apt install -y libc6 libmpv2 libqt6quick6 libqt6qml6 libqt6core6 libqt6websockets6 qml6-module-qtquick-controls python3
```

#### Arch Linux / Manjaro
```bash
sudo pacman -S --needed mpv qt6-base qt6-declarative qt6-websockets python
```

#### Fedora / RHEL
```bash
sudo dnf install -y mpv-libs qt6-qtbase qt6-qtdeclarative qt6-qtwebsockets python3
```

---

## 2. 安装方法

### 方式一：Debian / Ubuntu 系列一键安装（推荐 .deb）

在 Release 或构建目录中获取 `douyu-monitor_<version>_amd64.deb`，执行：

```bash
# 使用 apt 自动解决依赖并安装
sudo apt install ./douyu-monitor_*_amd64.deb
```

- **安装路径**: `/opt/douyu-monitor/`
- **命令行启动**: 在任意终端直接输入 `douyu-monitor` 即可运行。
- **桌面启动**: 直接在应用菜单或桌面搜索“斗鱼监控”点击启动。
- **卸载方法**:
  ```bash
  sudo apt remove douyu-monitor
  ```

---

### 方式二：全 Linux 通用免 root 便携版安装（.tar.gz）

适用于 Arch Linux、Fedora、openSUSE 或不想使用 root 权限的用户：

1. **解压发布包**:
   ```bash
   tar -zxvf DouyuMonitor-*-linux-x64.tar.gz
   cd DouyuMonitor-*-linux-x64
   ```

2. **直接免安装运行**:
   ```bash
   ./launch.sh
   ```

3. **一键集成到当前用户的应用菜单与桌面**:
   ```bash
   ./install.sh
   ```
   安装后会自动在 `~/.local/opt/DouyuMonitor` 部署，并在应用抽屉和桌面生成原生图标。

4. **卸载**:
   ```bash
   ./uninstall.sh
   ```

---

## 3. 核心功能与操作指南

### 3.1 手机斗鱼扫码登录与免密记住登录
- **登录入口**:
  - 点击右上角顶栏的用户头像图标；或者
  - 将鼠标悬停在任意正在播放的房间画面下半部分，点击浮现的弹幕条右侧“登录”按钮。
- **扫码认证**:
  - 屏幕中央弹出登录二维码对话框，使用手机斗鱼 App 扫码并确认登录。
  - 登录成功后，用户昵称和头像将自动同步显示。
- **自动记住登录（持久化免扫码）**:
  - 凭据安全保存在用户受限目录 `~/.local/share/DouyuMonitor/douyu_monitor_native/auth_session.json`（权限严格受限为 `0600`，有效期 30 天）。
  - 下次启动客户端自动登录，无需重复扫码！
  - 如需退出登录，点击右上角头像下拉菜单中的“退出登录”即可。

### 3.2 弹幕交互与本地即时回显（Local Echo）
- **发弹幕**:
  - 鼠标移动到正在播放的直播间画面下方，即可唤出半透明弹幕输入框。
  - 输入弹幕后按 **Enter 回车键** 或点击右侧“发送”。
- **自发弹幕即时飘屏**:
  - 敲击回车瞬间，自己发送的弹幕会以**专属亮绿边框、荧光青绿字体**以最高层级立即在当前画面飘过，一眼可见！
- **实时状态反馈气泡**:
  - 回车发送后，输入框正上方会立即浮现状态气泡：
    - `正在发送弹幕...`
    - `✓ 弹幕发送成功`（收到斗鱼弹幕网关确认）
    - 遇到错误明确提示（如“您已被房管禁言”、“弹幕包含违禁敏感词”等）。

### 3.3 布局与多路播放控制
- **添加房间**:
  - 快捷键 `Ctrl+Shift+A`，或点击左侧侧边栏“+”号输入房间号或主播名。
- **画质切换**:
  - 鼠标移动到画面上方工具条，点击画质下拉选单即可切换“原画”、“蓝光”、“超清”、“高清”。
- **全屏与宫格切换**:
  - 双击任意房间画面可切换单房充满/全屏；再次双击恢复多房宫格监控。
- **多声道/单声道独立音频切换**:
  - 右上角喇叭图标支持“单声道”（自动聚焦主画面或点击画面听声音）与“多声道”（多路声音同时播放并可独立调节音量）。

---

## 4. 常见问题排查 (Troubleshooting)

1. **画面黑屏或提示等待播放**:
   - 检查系统是否安装了 `libmpv`：执行 `ldd ~/.local/opt/DouyuMonitor/douyu_monitor_native | grep mpv`。
   - 若缺失，Ubuntu/Debian 请运行 `sudo apt install libmpv2`。
2. **弹幕连接提示需要认证**:
   - 某些特定分区（如赛事/高并发直播间）要求斗鱼账号登录，请点击右上角头像使用手机斗鱼扫码登录。
3. **网络代理环境下使用**:
   - 启动脚本 `launch.sh` 已内置对标准 `all_proxy` / `http_proxy` 格式的自动规范化与兼容支持。
