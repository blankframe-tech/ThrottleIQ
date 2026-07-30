#!/usr/bin/env bash
# Launch the ThrottleIQ app on a booted iOS Simulator.
#
# Usage: ./scripts/run_ios_sim.sh
#
# Notes:
# - Uses whichever simulator is currently booted. If none is booted, boots
#   the first available iPhone simulator.
# - First run after a `pod` version bump or clean checkout can take 10-15
#   minutes: `pod install` may shallow-clone large pods (e.g. the Firebase
#   iOS SDK) and the first Xcode build compiles everything from scratch.
#   Subsequent runs are much faster.
set -euo pipefail

cd "$(dirname "${BASH_SOURCE[0]}")/.."

DEVICE_ID=$(xcrun simctl list devices | awk -F'[()]' '/Booted/ && /iPhone/ {print $2; exit}')

if [ -z "${DEVICE_ID:-}" ]; then
  echo "No booted simulator found. Booting the first available iPhone simulator..."
  DEVICE_ID=$(xcrun simctl list devices available | awk -F'[()]' '/iPhone/ {print $2; exit}')
  xcrun simctl boot "$DEVICE_ID"
  open -a Simulator
fi

echo "Running on simulator: $DEVICE_ID"
flutter run -d "$DEVICE_ID"
