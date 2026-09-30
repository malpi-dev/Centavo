#!/usr/bin/env bash
# Builds the release APK, installs it on the connected device/emulator and runs
# the Maestro flows in .maestro/. Run it locally before tagging a release
# (E2E is not part of CI).
set -euo pipefail

cd "$(dirname "$0")/.."

command -v maestro >/dev/null || { echo "maestro not found (see docs/implementation/fase-13-pulido-y-e2e.md)"; exit 1; }
command -v adb >/dev/null || { echo "adb not found"; exit 1; }
adb get-state >/dev/null 2>&1 || { echo "No device/emulator connected"; exit 1; }

flutter build apk --release
adb install -r build/app/outputs/flutter-apk/app-release.apk
maestro test .maestro/ "$@"
