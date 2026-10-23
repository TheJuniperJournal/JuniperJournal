#!/bin/sh
set -eu
cd "$(dirname "$0")/.."
WEB_FLUTTER_BIN="${FLUTTER_BIN:-flutter}"
WEB_CONFIG_DIR="$(mktemp -d -t juniper-public)"
WEB_PUBLIC_CONFIG="$WEB_CONFIG_DIR/public.json"
trap 'rm -f "$WEB_PUBLIC_CONFIG"; rmdir "$WEB_CONFIG_DIR"' EXIT HUP INT TERM
python3 tool/web_config.py "${JUNIPER_ENV_FILE:-.env}" "$WEB_PUBLIC_CONFIG"
"$WEB_FLUTTER_BIN" build web --release --dart-define-from-file="$WEB_PUBLIC_CONFIG" "$@"

# Opt in for local preview; production/offline caching keeps Flutter defaults.
if [ "${JUNIPER_PREVIEW_CACHE_BUST:-0}" = "1" ]; then
python3 - <<'PYBUILD'
from pathlib import Path
import hashlib
root = Path('build/web')
revision = hashlib.sha256((root / 'main.dart.js').read_bytes()).hexdigest()[:12]
bootstrap = root / 'flutter_bootstrap.js'
bootstrap.write_text(bootstrap.read_text().replace('"mainJsPath":"main.dart.js"', '"mainJsPath":"main.dart.js?revision=' + revision + '"'))
index = root / 'index.html'
index.write_text(index.read_text().replace('src="flutter_bootstrap.js"', 'src="flutter_bootstrap.js?revision=' + revision + '"'))
PYBUILD
fi
