#!/bin/bash
# test-deploy.sh — comprehensive smoke test for OC3, OC4, OC5
# Usage: ./test-deploy.sh [oc3|oc4|oc5|all]
# Exit code 0 = all pass, 1 = failures found

set -euo pipefail

WHAT="${1:-all}"
FAILS=0
BASE="${OC_BASE_URL:-http://oc4.baiti.net}"
BASE3="${OC_BASE_URL:-http://oc3.baiti.net}"
BASE5="${OC_BASE_URL:-http://oc5.baiti.net}"

check() {
  local label="$1" url="$2" expect="${3:-200}"
  local code
  code=$(curl -sk -o /dev/null -w "%{http_code}" "$url" 2>/dev/null || echo "000")
  if [ "$code" != "$expect" ]; then
    echo "  FAIL: $label → $code (expected $expect)"
    FAILS=$((FAILS + 1))
  fi
}

test_oc4() {
  echo "=== OC4 ($BASE) ==="
  # Pages
  for p in / /login /livemap /caches /user; do
    check "page $p" "$BASE$p"
  done
  # /cache/new redirects to login (302) for anonymous
  check "page /cache/new" "$BASE/cache/new" 302

  # Static assets (base template)
  for p in /_frontend/css/oc-style.css /_frontend/vendor/bootstrap/bootstrap.min.css \
           /_frontend/vendor/bootstrap/bootstrap.bundle.min.js /_frontend/js/loader.js \
           /images/oclogo.png; do
    check "asset $p" "$BASE$p"
  done

  # Map page assets (loader.js references) and JS module imports
  for p in /_frontend/vendor/leaflet/leaflet.css /_frontend/vendor/leaflet/leaflet.js \
           /_frontend/vendor/leaflet-draw/leaflet.draw.css /_frontend/vendor/leaflet-draw/leaflet.draw.js \
           /_frontend/vendor/leaflet.markercluster/MarkerCluster.css \
           /_frontend/vendor/leaflet.markercluster/MarkerCluster.Default.css \
           /_frontend/vendor/leaflet.markercluster/leaflet.markercluster.js \
           /_frontend/css/map.css /_frontend/vendor/tabulator/tabulator.min.css \
           /_frontend/shared/coords.js; do
    check "map asset $p" "$BASE$p"
  done

  # Images (spot-check key files from each category)
  for p in /images/attributes/flashlight.png /images/attributes/train.png \
           /images/waypoints/wp_parking.png /images/waypoints/wp_final.png \
           /images/cacheTypes/drivein-active-untried.svg /images/cacheTypes/traditional-active-untried.svg \
           /images/flags/de.svg /images/logTypes/found.svg /images/logTypes/dnf.svg \
           /images/ratings/difficulty-20.svg; do
    check "image $p" "$BASE$p"
  done

  # API
  check "page cache detail" "$BASE/cache/OC1001"
  check "api cache" "$BASE/api/cache/OC1001"
  check "api user home" "$BASE/api/user/home"
}

test_oc5() {
  echo "=== OC5 ($BASE5) ==="
  # Pages
  for p in / /login /livemap /caches /cache/new /user /register /sitemap.xml; do
    check "page $p" "$BASE5$p"
  done
  # 404 page
  check "404 page" "$BASE5/nonexistent" 404

  # Static assets
  for p in /css/oc-style.css /js/loader.js /images/oclogo.png \
           /vendor/bootstrap/bootstrap.min.css /vendor/leaflet/leaflet.css \
           /css/map.css /vendor/tabulator/tabulator.min.css /lib/coords.js; do
    check "asset $p" "$BASE5$p"
  done

  # Images
  for p in /images/attributes/flashlight.png /images/waypoints/wp_parking.png \
           /images/logTypes/found.svg /images/flags/de.svg \
           /images/cacheTypes/drivein-active-untried.svg; do
    check "image $p" "$BASE5$p"
  done

  # API
  check "api live" "$BASE5/api/caches/live?lat1=52.0&lat2=53.0&lon1=9.0&lon2=10.0&minDiff=2&maxDiff=10"
  check "api search" "$BASE5/api/caches/search?q=test"
  check "api waypoints" "$BASE5/api/caches/waypoints?wp=OC10001"
  check "api users" "$BASE5/api/users/search?q=root"
  check "page cache detail" "$BASE5/cache/OC1001"
  check "api cache" "$BASE5/api/cache/OC1001"
  check "api user home" "$BASE5/api/user/home"
}

test_oc3() {
  echo "=== OC3 ($BASE3) ==="
  check "page /" "$BASE3/"
}

echo "Testing: $WHAT"
echo ""

case "$WHAT" in
  all)
    test_oc3
    test_oc4
    test_oc5
    ;;
  oc3) test_oc3 ;;
  oc4) test_oc4 ;;
  oc5) test_oc5 ;;
  *) echo "Unknown target: $WHAT"; exit 1 ;;
esac

echo ""
if [ "$FAILS" -eq 0 ]; then
  echo "✓ All tests passed"
else
  echo "✗ $FAILS failure(s)"
  exit 1
fi
