#!/bin/sh
set -eu
cd "$(dirname "$0")/.."
JUNIPER_ENV_FILE="${JUNIPER_ENV_FILE:-.env.staging}"
export JUNIPER_ENV_FILE
python3 - "$JUNIPER_ENV_FILE" <<'PY'
import pathlib, sys
sys.path.insert(0, 'tool')
from web_config import public_config
config = public_config(pathlib.Path(sys.argv[1]).read_text())
url = config['SUPABASE_URL']
if 'mltoisbukuhkxrdvndxl' in url.lower() or 'YOUR-STAGING' in url or not url:
    raise SystemExit('Staging requires a separate backend. Refusing to use production or a placeholder.')
if url.startswith(('http://localhost', 'http://127.0.0.1')):
    raise SystemExit('A hosted staging site needs a hosted test backend; local URLs are for local tests only.')
print('Separate staging backend verified.')
PY
JUNIPER_PREVIEW_CACHE_BUST=1 sh tool/build_web.sh
"${FIREBASE_BIN:-firebase}" hosting:channel:deploy staging --expires 7d --project the-juniper-journal
