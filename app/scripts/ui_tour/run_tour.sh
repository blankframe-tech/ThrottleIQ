#!/usr/bin/env bash
# Runs the automated UI screenshot tour (integration_test/ui_tour_test.dart)
# on an iOS simulator.
#
# usage: scripts/ui_tour/run_tour.sh <sim-udid> <out-dir> [combo_id,combo_id,...]
#
# Screenshots land in <out-dir>/<NN_color_vibe_brightness>/NNN__section__name.png.
# Combo ids look like `calming_curvy_light`; omit to run all 28.
# Env: TOUR_FROM=<n> skips the first n tour parts; TOUR_DUMP=1 logs on-screen text;
#      TOUR_LOCALE=bn walks the app in Bangla and logs layout overflows to the tour log.
#
# Why not `flutter test -d`? Every `flutter test` run reinstalls the app, and
# a reinstall of a new build resets simulator permissions, so the location
# prompt lands on top of the screenshots (and granting while the app runs
# kills it). Instead the tour is built once as a normal app, installed,
# granted, and launched directly: an integration test runs by itself on
# launch, and progress/completion come through the screenshot handshake.
set -euo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")/../.."

UDID="$1"; OUT="$2"; COMBOS="${3:-}"
BUNDLE=com.bft.throttleiq
ALL=$(python3 - <<'EOF'
colors = ['carbonMono', 'editorial', 'nocturne', 'trailSocial', 'calming', 'retro', 'analystBlue']
print(','.join(f'{c}_{v}_{b}' for c in colors for v in ('curvy', 'boxy') for b in ('light', 'dark')))
EOF
)
[ -z "$COMBOS" ] && COMBOS="$ALL"
mkdir -p "$OUT"
LOGS="$OUT/.logs"; mkdir -p "$LOGS"
APP_COPY="$LOGS/Runner-$UDID.app"

build_and_install() {  # $1 = comma-separated combos
  local defines=(--dart-define=TOUR_COMBOS="$1" --dart-define=TOUR_FROM="${TOUR_FROM:-0}")
  [ "${TOUR_DUMP:-0}" = 1 ] && defines+=(--dart-define=TOUR_DUMP_TEXTS=true)
  [ -n "${TOUR_LOCALE:-}" ] && defines+=(--dart-define=TOUR_LOCALE="${TOUR_LOCALE}")
  # Serialize builds: two runners share one build/ directory.
  while ! mkdir "$PWD/build/.ui_tour_build.lock" 2>/dev/null; do sleep 5; done
  flutter build ios --simulator --debug -t integration_test/ui_tour_test.dart "${defines[@]}" \
    > "$LOGS/build-$UDID.log" 2>&1 || { rmdir "$PWD/build/.ui_tour_build.lock"; echo "build failed, see $LOGS/build-$UDID.log"; exit 1; }
  rm -rf "$APP_COPY"; cp -R build/ios/iphonesimulator/Runner.app "$APP_COPY"
  rmdir "$PWD/build/.ui_tour_build.lock"
  xcrun simctl terminate "$UDID" "$BUNDLE" 2>/dev/null || true
  xcrun simctl install "$UDID" "$APP_COPY"
  for svc in location-always motion photos camera; do
    xcrun simctl privacy "$UDID" grant "$svc" "$BUNDLE" 2>/dev/null || true
  done
  local c; c=$(xcrun simctl get_app_container "$UDID" "$BUNDLE" data)
  rm -rf "$c/Documents/tour"
}

# (Captured first: `| grep -q` exits early, and under pipefail the SIGPIPE'd
# launchctl would make a running app look dead.)
app_running() { local l; l=$(xcrun simctl spawn "$UDID" launchctl list 2>/dev/null || true); [[ "$l" == *"UIKitApplication:$BUNDLE"* ]]; }

xcrun simctl bootstatus "$UDID" -b >/dev/null
# Clean, consistent status bar and a fixed Dhaka location for every shot.
xcrun simctl status_bar "$UDID" override --time 9:41 --dataNetwork wifi --wifiMode active \
  --wifiBars 3 --cellularMode active --cellularBars 4 --batteryState charged --batteryLevel 100
xcrun simctl location "$UDID" set 23.7937,90.4066

xcrun simctl spawn "$UDID" log stream --style compact --predicate 'eventMessage CONTAINS "[tour]"' \
  >> "$LOGS/tour-$UDID.log" 2>&1 &
LOGGER=$!
trap 'kill $LOGGER 2>/dev/null || true; pkill -f "snap_watcher.py $UDID" 2>/dev/null || true' EXIT

REMAINING="$COMBOS"
for attempt in 1 2 3 4 5 6; do
  echo "[run_tour] attempt $attempt: $REMAINING"
  for c in ${REMAINING//,/ }; do rm -rf "$OUT"/[0-9][0-9]_"$c"; done
  build_and_install "$REMAINING"
  python3 scripts/ui_tour/snap_watcher.py "$UDID" "$BUNDLE" "$OUT" >> "$LOGS/watcher-$UDID.log" 2>&1 &
  WATCHER=$!
  xcrun simctl launch "$UDID" "$BUNDLE" >/dev/null
  misses=0
  while kill -0 $WATCHER 2>/dev/null; do
    sleep 20
    if app_running; then misses=0; else misses=$((misses + 1)); fi
    if [ $misses -ge 2 ]; then
      echo "[run_tour] app died; will resume"
      kill $WATCHER 2>/dev/null || true
      break
    fi
  done
  wait $WATCHER 2>/dev/null || true
  # A combo is complete once its done_ marker was seen by the watcher.
  REMAINING=$(python3 - "$REMAINING" "$LOGS/watcher-$UDID.log" <<'EOF'
import sys, re
remaining = [c for c in sys.argv[1].split(',') if c]
done = set(re.findall(r'\[watcher\] done \d\d_(\S+)', open(sys.argv[2]).read()))
print(','.join(c for c in remaining if c not in done))
EOF
)
  if [ -z "$REMAINING" ]; then echo "[run_tour] all combos done"; exit 0; fi
  # The combo that was in flight is re-shot from scratch.
done
echo "[run_tour] gave up; still remaining: $REMAINING"
exit 1
