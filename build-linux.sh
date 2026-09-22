#!/usr/bin/env bash
# Builds Arpège for Linux (native GTK executable).
# Requirements: Flutter + Linux desktop toolchain:
#   sudo apt-get install -y clang cmake ninja-build pkg-config libgtk-3-dev
set -euo pipefail
cd "$(dirname "$0")"

flutter config --enable-linux-desktop
flutter pub get
flutter build linux --release

echo
echo "Build finished: build/linux/x64/release/bundle/"
echo "Executable: build/linux/x64/release/bundle/arpege"
