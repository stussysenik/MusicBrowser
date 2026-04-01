#!/bin/bash
# MusicBrowser - Device Build, Deploy & Test
# Usage: ./scripts/device_test.sh [--logs-only] [--tests-only]

set -euo pipefail

DEVICE="senik"
SCHEME="MusicBrowser"
APP_ID="com.musicbrowser.app"

echo "=== MusicBrowser Device Test ==="
echo "Device: $DEVICE"
echo "Scheme: $SCHEME"
echo ""

if [[ "${1:-}" == "--logs-only" ]]; then
    echo ">>> Streaming logs from $DEVICE..."
    flowdeck logs "$APP_ID"
    exit 0
fi

if [[ "${1:-}" == "--tests-only" ]]; then
    echo ">>> Running unit tests on simulator..."
    flowdeck test --simulator "iPhone 16 Pro" --progress
    exit 0
fi

# Step 1: Build and deploy to device
echo ">>> Step 1: Build & deploy to device..."
flowdeck run --device "$DEVICE" --launch-options="-demo-mode" -l &
RUN_PID=$!

# Give app time to launch
sleep 5

# Step 2: Run unit tests on simulator (in parallel)
echo ""
echo ">>> Step 2: Running unit tests on simulator..."
flowdeck test --simulator "iPhone 16 Pro" --progress 2>&1 || true

echo ""
echo ">>> Done! App running on $DEVICE with logs streaming (PID: $RUN_PID)"
echo ">>> Press Ctrl+C to stop"
wait $RUN_PID
