#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")/.."

export CI=1

if [[ -z "${EXPO_PUBLIC_API_BASE_URL:-}" && -f .env ]]; then
  set -a
  # shellcheck disable=SC1091
  source .env
  set +a
fi

export EXPO_PUBLIC_API_BASE_URL="${EXPO_PUBLIC_API_BASE_URL:-http://localhost:8000}"

bun run icons:android
bunx expo prebuild --platform android --clean

cd android
chmod +x gradlew
./gradlew :app:assembleDebug --no-daemon
