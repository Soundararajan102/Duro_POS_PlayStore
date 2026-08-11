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
  echo "$ANDROID_KEYSTORE_BASE64" | base64 -d > android/upload.keystore
  cat <<EOF > android/keystore.properties
storeFile=upload.keystore
keyAlias=$ANDROID_KEY_ALIAS
storePassword=$ANDROID_KEYSTORE_PASSWORD
keyPassword=$ANDROID_KEY_PASSWORD
EOF

  echo "Patching build.gradle to use production keystore..."
  node -e "
const fs = require('fs');
const path = 'android/app/build.gradle';
let content = fs.readFileSync(path, 'utf8');

const releaseConfig = \`
        release {
            if (project.file('../keystore.properties').exists()) {
                def props = new Properties()
                props.load(new FileInputStream(project.file('../keystore.properties')))
                storeFile file(props.getProperty('storeFile'))
                storePassword props.getProperty('storePassword')
                keyAlias props.getProperty('keyAlias')
                keyPassword props.getProperty('keyPassword')
            }
        }
\`;

// Add the release signing block
content = content.replace(/signingConfigs\s*\{/, 'signingConfigs {' + releaseConfig);

// The prebuild generates two 'signingConfig signingConfigs.debug' lines (one for debug, one for release).
// We need to change the second one to 'signingConfig signingConfigs.release'.
let parts = content.split('signingConfig signingConfigs.debug');
if (parts.length >= 3) {
    content = parts[0] + 'signingConfig signingConfigs.debug' + parts[1] + 'signingConfig signingConfigs.release' + parts.slice(2).join('signingConfig signingConfigs.debug');
}
fs.writeFileSync(path, content);
"
fi

cd android
chmod +x gradlew
./gradlew :app:bundleRelease --no-daemon
