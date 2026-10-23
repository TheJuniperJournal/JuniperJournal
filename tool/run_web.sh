#!/bin/sh
set -eu
cd "$(dirname "$0")/.."
WEB_FLUTTER_BIN="${FLUTTER_BIN:-flutter}"
WEB_CONFIG_DIR="$(mktemp -d -t juniper-public)"
WEB_PUBLIC_CONFIG="$WEB_CONFIG_DIR/public.json"
trap 'rm -f "$WEB_PUBLIC_CONFIG"; rmdir "$WEB_CONFIG_DIR"' EXIT HUP INT TERM
python3 tool/web_config.py "${JUNIPER_ENV_FILE:-.env}" "$WEB_PUBLIC_CONFIG"
"$WEB_FLUTTER_BIN" run -d chrome --web-hostname=127.0.0.1 --web-port=5174 --dart-define-from-file="$WEB_PUBLIC_CONFIG" "$@"
