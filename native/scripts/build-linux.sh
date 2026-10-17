#!/usr/bin/env bash
# Build DouyuMonitor for Linux (Ubuntu) using the system Qt 6 and libmpv.
#
# Required system packages (Ubuntu 24.04+):
#   sudo apt install qt6-declarative-dev qt6-declarative-private-dev qt6-websockets-dev \
#     libmpv-dev qml6-module-qtquick qml6-module-qtquick-controls \
#     qml6-module-qtquick-templates qml6-module-qtquick-window \
#     qml6-module-qtquick-layouts qml6-module-qtqml-workerscript qml6-module-qttest \
#     ninja-build python3-venv pkg-config
set -euo pipefail

native_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
repo_root="$(cd "${native_root}/.." && pwd)"
venv="${native_root}/.venv"
python="${venv}/bin/python"

# 1. Python environment for the StreamGet service.
if [[ ! -x "${python}" ]]; then
    python3 -m venv "${venv}"
fi
"${python}" -m pip install --quiet --requirement "${native_root}/service/requirements.txt"
"${python}" -m pip install --quiet --requirement "${native_root}/service/requirements-build.txt"

# 2. Package streamget_service with PyInstaller (onedir, same layout as Windows).
dist="${native_root}/out/service"
work="${native_root}/out/pyinstaller"
mkdir -p "${dist}" "${work}"
"${python}" -m PyInstaller --noconfirm --clean --onedir --log-level WARN \
    --name streamget_service \
    --paths "${repo_root}" --distpath "${dist}" --workpath "${work}" --specpath "${work}" \
    --add-data "${native_root}/app/resources/hamster_agent_roster.json:native/app/resources" \
    "${native_root}/service/streamget_service.py"
test -x "${dist}/streamget_service/streamget_service"

# 3. Configure and build the native client (POST_BUILD copies the service next to it).
cd "${native_root}"
cmake --preset linux-x64-release
cmake --build --preset linux-x64-release --target douyu_monitor_native

echo "Built: ${native_root}/out/build/linux-x64-release/douyu_monitor_native"
