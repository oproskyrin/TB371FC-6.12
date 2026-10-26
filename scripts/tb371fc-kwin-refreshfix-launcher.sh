#!/bin/sh
export KWIN_DRM_RENDERLOOP_REFRESH_RATE_MHZ=60000
export LD_LIBRARY_PATH=/opt/tb371fc-kwin-renderloopfix/lib${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}
exec /opt/tb371fc-kwin-renderloopfix/bin/kwin_wayland "$@"
