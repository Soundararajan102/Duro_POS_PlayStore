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

if [[ -z "${EXPO_PUBLIC_API_BASE_URL:-}" ]]; then
  echo "EXPO_PUBLIC_API_BASE_URL is required (set in frontend/.env)" >&2
  exit 1
fi

bun run icons:android
bunx expo prebuild --platform android --clean

if [[ -n "${ANDROID_KEYSTORE_BASE64:-}" ]]; then
  echo "Setting up production keystore..."
  echo "$ANDROID_KEYSTORE_BASE64" | base64 -d > android/app/upload.keystore
  cat <<EOF > android/keystore.properties
storeFile=upload.keystore
keyAlias=$ANDROID_KEY_ALIAS
storePassword=$ANDROID_KEYSTORE_PASSWORD
keyPassword=$ANDROID_KEY_PASSWORD
EOF
fi

cd android
chmod +x gradlew
./gradlew :app:bundleRelease --no-daemon
