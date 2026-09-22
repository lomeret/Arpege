#!/usr/bin/env python3
"""Builds Arpège (Linux release) then packages an installable .deb.

Linux equivalent of installer/build_installer.py (Inno Setup for Windows).

Run on a Debian/Ubuntu machine, from the project root:

    python3 installer/build_deb.py

Requirements:
  - Flutter with Linux desktop enabled (flutter config --enable-linux-desktop)
    and its build dependencies (clang, cmake, ninja-build, libgtk-3-dev, pkg-config).
  - dpkg-deb (the "dpkg" package, present by default on Debian/Ubuntu).

The final .deb is dropped into dist/. On install, apt automatically pulls in
the system dependencies declared in DEBIAN/control (GTK3…).
"""
from __future__ import annotations

import os
import re
import shutil
import subprocess
import sys
import tempfile
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent

# --- Package metadata -------------------------------------------------
APP_ID = "com.lomeret.arpege"   # must match APPLICATION_ID (linux/CMakeLists.txt)
BINARY = "arpege"               # = BINARY_NAME (linux/CMakeLists.txt)
APP_NAME = "Arpège"
MAINTAINER = "Louis Meret <louismeretfrogboys@gmail.com>"
ARCH = "amd64"

# Runtime dependencies. GTK3 is the Flutter embedder's shell; the rest
# (glibc, libstdc++) is almost always present but declared for safety.
# The "| *t64" alternatives cover distros past the 64-bit time_t transition
# (Ubuntu 24.04+, Debian trixie) where libgtk-3-0 is named libgtk-3-0t64.
DEPENDS = (
    "libgtk-3-0 | libgtk-3-0t64, "
    "libglib2.0-0 | libglib2.0-0t64, "
    "libstdc++6, libc6"
)

# --- Locations ----------------------------------------------------------
BUNDLE = ROOT / "build" / "linux" / "x64" / "release" / "bundle"
DIST = ROOT / "dist"
# The package tree is staged on the native Linux FS (/tmp), NOT in the repo:
# under WSL the repo sits on /mnt/c (drvfs) where everything is 777 and chmod
# is ignored, which dpkg-deb refuses for the DEBIAN control folder.
STAGE = Path(tempfile.gettempdir()) / "arpege-deb-build"
INSTALL_DIR = f"opt/{BINARY}"          # -> /opt/arpege


def read_version() -> str:
    """Reads the version from pubspec.yaml (without the "+N" build number)."""
    text = (ROOT / "pubspec.yaml").read_text(encoding="utf-8")
    m = re.search(r"^version:\s*([0-9]+\.[0-9]+\.[0-9]+)", text, re.MULTILINE)
    return m.group(1) if m else "1.0.0"


def read_build_number() -> str | None:
    """Build number (CI: number of commits on the branch, see release.yml).
    Absent locally -> no Debian revision, unchanged behavior."""
    return os.environ.get("ARPEGE_BUILD_NUMBER") or None


def desktop_entry() -> str:
    return (
        "[Desktop Entry]\n"
        "Type=Application\n"
        f"Name={APP_NAME}\n"
        "GenericName=Sheet Music Annotation\n"
        "Comment=PDF sheet music viewer and annotator\n"
        f"Exec={BINARY}\n"
        f"Icon={BINARY}\n"
        "Terminal=false\n"
        "Categories=AudioVideo;Audio;Music;Graphics;Viewer;\n"
        f"StartupWMClass={APP_ID}\n"
    )


def run(cmd, **kwargs) -> None:
    printable = cmd if isinstance(cmd, str) else " ".join(str(c) for c in cmd)
    print(f"\n> {printable}")
    subprocess.run(cmd, check=True, **kwargs)


def normalize_perms(root: Path) -> None:
    """Forces sane permissions (files copied from /mnt/c arrive as 777).
    Directories -> 0755, files -> 0644; the executable is set back to 0755
    further down. dpkg-deb requires a DEBIAN folder in 0755-0775."""
    for dirpath, dirnames, filenames in os.walk(root):
        os.chmod(dirpath, 0o755)
        for name in filenames:
            full = os.path.join(dirpath, name)
            if os.path.islink(full):
                continue  # don't follow a symlink (e.g. /usr/bin/arpege)
            os.chmod(full, 0o644)


def build_tree(version: str) -> Path:
    """Assembles the package tree and returns its root."""
    if STAGE.exists():
        shutil.rmtree(STAGE)

    # /opt/arpege <- full bundle (exe + lib/ + data/)
    appdir = STAGE / INSTALL_DIR
    appdir.parent.mkdir(parents=True, exist_ok=True)
    shutil.copytree(BUNDLE, appdir)

    # /usr/bin/arpege -> symlink to the exe (Flutter resolves /proc/self/exe,
    # so lib/ and data/ are correctly found next to the real target).
    bindir = STAGE / "usr" / "bin"
    bindir.mkdir(parents=True, exist_ok=True)
    (bindir / BINARY).symlink_to(f"/{INSTALL_DIR}/{BINARY}")

    # .desktop menu entry
    appsdir = STAGE / "usr" / "share" / "applications"
    appsdir.mkdir(parents=True, exist_ok=True)
    (appsdir / f"{BINARY}.desktop").write_text(desktop_entry(), encoding="utf-8")

    # Icon (pixmaps: size-independent fallback location)
    pix = STAGE / "usr" / "share" / "pixmaps"
    pix.mkdir(parents=True, exist_ok=True)
    shutil.copy(ROOT / "assets" / "Logo.png", pix / f"{BINARY}.png")

    # DEBIAN/control
    size_kb = sum(f.stat().st_size for f in STAGE.rglob("*") if f.is_file()) // 1024
    debian = STAGE / "DEBIAN"
    debian.mkdir(parents=True, exist_ok=True)
    (debian / "control").write_text(
        f"Package: {BINARY}\n"
        f"Version: {version}\n"
        "Section: sound\n"
        "Priority: optional\n"
        f"Architecture: {ARCH}\n"
        f"Depends: {DEPENDS}\n"
        f"Installed-Size: {size_kb}\n"
        f"Maintainer: {MAINTAINER}\n"
        f"Description: {APP_NAME} — PDF sheet music annotation\n"
        " PDF sheet music viewer and annotator (sharps, flats, text\n"
        " indications, free drawing), with a library and setlists.\n",
        encoding="utf-8",
    )

    # postinst: refreshes the menu and icon cache after installation
    postinst = debian / "postinst"
    postinst.write_text(
        "#!/bin/sh\n"
        "set -e\n"
        "command -v update-desktop-database >/dev/null 2>&1 && "
        "update-desktop-database -q || true\n"
        "command -v gtk-update-icon-cache >/dev/null 2>&1 && "
        "gtk-update-icon-cache -q -t /usr/share/icons/hicolor || true\n",
        encoding="utf-8",
    )

    # Normalizes EVERYTHING (0755 dirs / 0644 files), then makes executable
    # only the files that need to be. Required because the bundle copied
    # from /mnt/c arrives as 777, which dpkg-deb refuses for DEBIAN.
    normalize_perms(STAGE)
    os.chmod(appdir / BINARY, 0o755)
    os.chmod(postinst, 0o755)

    return STAGE


def main() -> int:
    if shutil.which("dpkg-deb") is None:
        print("ERROR: dpkg-deb not found (install the \"dpkg\" package).",
              file=sys.stderr)
        return 1

    version = read_version()
    build = read_build_number()
    # Debian revision (standard upstream_version-debian_revision format) when
    # a CI build number is provided, otherwise just x.y.z.
    full_version = f"{version}-{build}" if build else version

    # 1) Build the Linux release.
    build_flag = f" --build-number={build}" if build else ""
    run(f"flutter build linux --release{build_flag}", cwd=ROOT, shell=True)
    if not BUNDLE.exists():
        print(f"ERROR: bundle not found after the build: {BUNDLE}",
              file=sys.stderr)
        return 1

    # 2) Package tree.
    pkgroot = build_tree(full_version)

    # 3) Build the .deb (--root-owner-group: root:root files without sudo).
    DIST.mkdir(exist_ok=True)
    out = DIST / f"{BINARY}_{full_version}_{ARCH}.deb"
    run(["dpkg-deb", "--root-owner-group", "--build", str(pkgroot), str(out)])

    print(f"\n✅ Package built: {out}")
    print(f"   Install:    sudo apt install {out}")
    print(f"   (or:        sudo dpkg -i {out} && sudo apt -f install)")
    print(f"   Uninstall:  sudo apt remove {BINARY}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
