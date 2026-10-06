#!/usr/bin/env bash
# Boots a simulator, installs the built app and captures each screen in screenshot mode.
# Usage: ios/scripts/screenshots.sh <path/to/AICab.app> <output dir>
set -euo pipefail
APP="$1"
OUT="$2"
mkdir -p "$OUT"

UDID=$(xcrun simctl list devices available -j | python3 -c '
import json, sys
devices = json.load(sys.stdin)["devices"]
phones = [d for runtime, ds in devices.items() if "iOS" in runtime for d in ds if d["name"].startswith("iPhone") and "Pro" in d["name"] and "Max" not in d["name"]]
phones.sort(key=lambda d: d["name"])
print(phones[-1]["udid"])')
echo "Using simulator $UDID"
xcrun simctl boot "$UDID" || true
xcrun simctl bootstatus "$UDID" -b
xcrun simctl status_bar "$UDID" override --time "9:41" --batteryState charged --batteryLevel 100 --cellularBars 4 --wifiBars 3 || true
xcrun simctl install "$UDID" "$APP"
BUNDLE=com.aicab.app

shoot() {
  local name="$1"; shift
  xcrun simctl terminate "$UDID" "$BUNDLE" >/dev/null 2>&1 || true
  xcrun simctl launch "$UDID" "$BUNDLE" "$@" >/dev/null
  sleep 6
  xcrun simctl io "$UDID" screenshot "$OUT/$name.png" >/dev/null
  echo "captured $name"
}

for step in welcome tailor name age weekly streak habits reminders icon theme insight familiarity weakSpots knownBuilder placement topics; do
  shoot "onboarding-$step" -screenshot onboarding -onboardingStep "$step"
done
for screen in words toast coach topics journey practice challenge flashcards levelTest profile voices gallery stats paywall widget term share; do
  shoot "$screen" -screenshot "$screen"
done
