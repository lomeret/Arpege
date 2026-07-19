#!/usr/bin/env bash
# Compile Arpège pour Linux (exécutable natif GTK).
# Prérequis : Flutter + toolchain desktop Linux :
#   sudo apt-get install -y clang cmake ninja-build pkg-config libgtk-3-dev
set -euo pipefail
cd "$(dirname "$0")"

flutter config --enable-linux-desktop
flutter pub get
flutter build linux --release

echo
echo "Build terminé : build/linux/x64/release/bundle/"
echo "Exécutable : build/linux/x64/release/bundle/arpege"
