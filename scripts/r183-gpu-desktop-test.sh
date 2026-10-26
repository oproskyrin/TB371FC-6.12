#!/bin/sh
set -eu
test -e /dev/dri/by-path/platform-msm-render
test -e /dev/dri/by-path/platform-9c000000.framebuffer-card
test -f /run/r183-software-rollback.sh
test ! -e /run/systemd/system/r149-plasma.service.d/90-r183-gpu.conf
mkdir -p /run/r183 /run/systemd/system/r149-plasma.service.d
systemctl cat r149-plasma.service > /run/r183/before-service.txt
date -Iseconds > /run/r183/test-start.txt
systemd-run --unit=r183-software-rollback --on-active=180s /bin/sh /run/r183-software-rollback.sh
cat > /run/systemd/system/r149-plasma.service.d/90-r183-gpu.conf <<'EOF'
[Service]
UnsetEnvironment=KWIN_COMPOSE LIBGL_ALWAYS_SOFTWARE QT_QUICK_BACKEND
Environment=KWIN_DRM_DEVICES=/dev/dri/by-path/platform-msm-card:/dev/dri/by-path/platform-9c000000.framebuffer-card
Environment=KWIN_DRM_FORCE_GL_FINISH_PRESENT=1
Environment="QT_LOGGING_RULES=kwin_wayland_drm.debug=true"
EOF
systemctl stop r149-plasma.service
loginctl terminate-user alarm || true
systemctl daemon-reload
systemctl start r149-plasma.service
echo 'R183: GPU desktop trial started; automatic QPainter rollback in 180 seconds'
