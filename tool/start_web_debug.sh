#!/bin/sh

set -eu

web_port="${DJINN_WEB_PORT:-8080}"
case "$web_port" in
  '' | *[!0-9]*)
    echo 'DJINN_WEB_PORT must be a numeric port.' >&2
    exit 2
    ;;
esac

project_dir=$(CDPATH= cd -- "$(dirname "$0")/.." && pwd)

exec proot-distro login ubuntu -- bash -lc "
  cd '$project_dir'
  /home/flutteruser/flutter/bin/flutter config --enable-web >/dev/null
  exec /home/flutteruser/flutter/bin/flutter run \\
    -d web-server \\
    -t lib/main_web.dart \\
    --web-hostname=0.0.0.0 \\
    --web-port='$web_port'
"
