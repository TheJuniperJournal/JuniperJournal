#!/bin/sh
set -eu
cd "$(dirname "$0")/.."
JUNIPER_FIREBASE_BIN="${FIREBASE_BIN:-firebase}"
JUNIPER_PREVIEW_CHANNEL="${1:-web-review}"
sh tool/build_web.sh
"$JUNIPER_FIREBASE_BIN" hosting:channel:deploy "$JUNIPER_PREVIEW_CHANNEL" --project the-juniper-journal --expires 7d
