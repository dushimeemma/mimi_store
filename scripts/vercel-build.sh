#!/usr/bin/env bash
set -euo pipefail

FLUTTER_VERSION="${FLUTTER_VERSION:-3.47.1}"
FLUTTER_DIR="${PWD}/.vercel_flutter"
API_BASE_URL="${API_BASE_URL:-https://mimi-store-gg46.onrender.com/api/v1}"

if [[ ! -x "${FLUTTER_DIR}/bin/flutter" ]]; then
  git clone --depth 1 --branch "${FLUTTER_VERSION}" \
    https://github.com/flutter/flutter.git "${FLUTTER_DIR}"
fi

export PATH="${FLUTTER_DIR}/bin:${PATH}"

flutter config --no-analytics --enable-web
flutter precache --web

if [[ ! -d web ]]; then
  flutter create --platforms=web --project-name mimi_store .
fi

flutter pub get
flutter build web --release --dart-define="API_BASE_URL=${API_BASE_URL}"
