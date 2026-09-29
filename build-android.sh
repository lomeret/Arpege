#!/usr/bin/env bash
# Builds Arpège for Android (APK + App Bundle).
# Requirements: Flutter + Android SDK + JDK 17.
set -euo pipefail
cd "$(dirname "$0")"

flutter pub get
flutter build apk --release
flutter build appbundle --release

echo
echo "APK: build/app/outputs/flutter-apk/app-release.apk"
echo "AAB: build/app/outputs/bundle/release/app-release.aab"
