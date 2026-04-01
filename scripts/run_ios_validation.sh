#!/bin/zsh
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
SCHEME="${SCHEME:-MusicBrowser}"
APP_ID="${APP_ID:-com.musicbrowser.app}"
DEVICE_NAME="${DEVICE_NAME:-iPhone 16 Pro}"
DEVICE_ID="${DEVICE_ID:-}"

if ! command -v maestro >/dev/null 2>&1; then
  echo "maestro is required but not installed." >&2
  exit 1
fi

resolve_device_id() {
  if [[ -n "$DEVICE_ID" ]]; then
    return 0
  fi

  DEVICE_ID="$(
    xcrun simctl list devices available |
      rg -m1 "${DEVICE_NAME} \\(([0-9A-F-]+)\\) \\(Booted\\)" -or '$1'
  )"

  if [[ -z "$DEVICE_ID" ]]; then
    DEVICE_ID="$(
      xcrun simctl list devices available |
        rg -m1 "${DEVICE_NAME} \\(([0-9A-F-]+)\\)" -or '$1'
    )"
  fi

  if [[ -z "$DEVICE_ID" ]]; then
    DEVICE_ID="$(
      xcrun simctl list devices available |
        rg -m1 "iPhone .*\\(([0-9A-F-]+)\\) \\(Booted\\)" -or '$1'
    )"
  fi

  if [[ -z "$DEVICE_ID" ]]; then
    DEVICE_ID="$(
      xcrun simctl list devices available |
        rg -m1 "iPhone .*\\(([0-9A-F-]+)\\)" -or '$1'
    )"
  fi

  if [[ -z "$DEVICE_ID" ]]; then
    echo "Unable to resolve a simulator device. Set DEVICE_ID or DEVICE_NAME." >&2
    exit 1
  fi
}

isolate_simulator() {
  local booted_devices
  booted_devices="$(
    xcrun simctl list devices available |
      awk '/Booted/ {
        if (match($0, /\(([0-9A-F-]+)\)/)) {
          print substr($0, RSTART + 1, RLENGTH - 2)
        }
      }'
  )"

  for booted_id in ${(f)booted_devices}; do
    if [[ -n "$booted_id" && "$booted_id" != "$DEVICE_ID" ]]; then
      echo "Shutting down competing simulator $booted_id..."
      xcrun simctl shutdown "$booted_id" >/dev/null 2>&1 || true
    fi
  done

  xcrun simctl boot "$DEVICE_ID" >/dev/null 2>&1 || true
  open -a Simulator --args -CurrentDeviceUDID "$DEVICE_ID" >/dev/null 2>&1 || true
  xcrun simctl bootstatus "$DEVICE_ID" -b
}

wait_for_app_registration() {
  local attempt=1
  while (( attempt <= 15 )); do
    if xcrun simctl get_app_container "$DEVICE_ID" "$APP_ID" app >/dev/null 2>&1; then
      return 0
    fi
    sleep 1
    (( attempt++ ))
  done

  echo "App registration did not settle on simulator $DEVICE_ID." >&2
  exit 1
}

resolve_device_id
isolate_simulator
echo "Using simulator $DEVICE_ID (${DEVICE_NAME})."

echo "Running XCTest on $DEVICE_ID..."
xcodebuild test \
  -scheme "$SCHEME" \
  -destination "platform=iOS Simulator,id=$DEVICE_ID" \
  CODE_SIGNING_ALLOWED=NO

wait_for_app_registration
xcrun simctl privacy "$DEVICE_ID" grant all "$APP_ID" >/dev/null 2>&1 || true
xcrun simctl privacy "$DEVICE_ID" grant media-library "$APP_ID" >/dev/null 2>&1 || true

echo "Running Maestro flows on $DEVICE_ID..."
flows=(
  "$ROOT_DIR/.maestro/launch.yaml"
  "$ROOT_DIR/.maestro/navigation.yaml"
  "$ROOT_DIR/.maestro/albums_layout.yaml"
  "$ROOT_DIR/.maestro/library_az_scroll.yaml"
  "$ROOT_DIR/.maestro/sort_filter.yaml"
  "$ROOT_DIR/.maestro/note_capture.yaml"
  "$ROOT_DIR/.maestro/playback_random.yaml"
)

for flow in "${flows[@]}"; do
  echo "  -> $(basename "$flow")"
  maestro test --device "$DEVICE_ID" --no-reinstall-driver "$flow"
done

echo "iOS validation completed successfully."
