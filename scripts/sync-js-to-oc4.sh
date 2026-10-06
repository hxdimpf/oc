#!/bin/bash
# sync-js-to-oc4.sh — copy shared frontend JS from OC5 to OC4, rewriting asset paths
# Usage: ./sync-js-to-oc4.sh [file.js ...]     (no args: every file in oc5/public/js)
#
# OC5 is the primary dev target for shared JS. OC4 serves the same files under
# /_frontend/ and keeps coords.js in shared/ instead of lib/, so a plain cp breaks
# OC4. This applies exactly those path differences and nothing else.

set -euo pipefail

SRC="${OC5_DIR:-$HOME/src/oc5}/public/js"
DST="${OC4_DIR:-$HOME/src/oc4}/public/_frontend/js"

cd "$SRC"
FILES=("$@")
[ ${#FILES[@]} -eq 0 ] && FILES=(*.js)

for f in "${FILES[@]}"; do
    f=$(basename "$f")
    sed -e "s#'/vendor/#'/_frontend/vendor/#g" \
        -e "s#'/css/#'/_frontend/css/#g" \
        -e "s#\`/images/#\`/_frontend/images/#g" \
        -e "s#'\.\./lib/coords\.js'#'../shared/coords.js'#g" \
        "$SRC/$f" > "$DST/$f"
    echo "  $f"
done
