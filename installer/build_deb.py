#!/usr/bin/env python3
"""Construit Arpège (Linux release) puis fabrique un paquet .deb installable.

Équivalent Linux de installer/build_installer.py (Inno Setup pour Windows).

À lancer sur une machine Debian/Ubuntu, à la racine du projet :

    python3 installer/build_deb.py

Prérequis :
  - Flutter avec le desktop Linux activé (flutter config --enable-linux-desktop)
    et ses dépendances de build (clang, cmake, ninja-build, libgtk-3-dev, pkg-config).
  - dpkg-deb (paquet « dpkg », présent par défaut sur Debian/Ubuntu).

Le .deb final est déposé dans dist/. À l'installation, apt tire automatiquement
les dépendances système déclarées dans DEBIAN/control (GTK3…).
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

# --- Métadonnées du paquet -------------------------------------------------
APP_ID = "com.lomeret.arpege"   # doit correspondre à APPLICATION_ID (linux/CMakeLists.txt)
BINARY = "arpege"               # = BINARY_NAME (linux/CMakeLists.txt)
APP_NAME = "Arpège"
MAINTAINER = "Louis Meret <louismeretfrogboys@gmail.com>"
ARCH = "amd64"

# Dépendances runtime. GTK3 est le shell de l'embedder Flutter ; le reste
# (glibc, libstdc++) est quasi toujours présent mais déclaré par sûreté.
# Les alternatives « | *t64 » couvrent les distros post-transition time_t 64 bits
# (Ubuntu 24.04+, Debian trixie) où libgtk-3-0 s'appelle libgtk-3-0t64.
DEPENDS = (
    "libgtk-3-0 | libgtk-3-0t64, "
    "libglib2.0-0 | libglib2.0-0t64, "
    "libstdc++6, libc6"
)

# --- Emplacements ----------------------------------------------------------
BUNDLE = ROOT / "build" / "linux" / "x64" / "release" / "bundle"
DIST = ROOT / "dist"
# L'arbo du paquet est montée sur le FS Linux natif (/tmp), PAS dans le repo :
# sous WSL le repo est sur /mnt/c (drvfs) où tout est en 777 et chmod est ignoré,
# ce que dpkg-deb refuse pour le dossier de contrôle DEBIAN.
STAGE = Path(tempfile.gettempdir()) / "arpege-deb-build"
INSTALL_DIR = f"opt/{BINARY}"          # → /opt/arpege


def read_version() -> str:
    """Lit la version depuis pubspec.yaml (sans le numéro de build « +N »)."""
    text = (ROOT / "pubspec.yaml").read_text(encoding="utf-8")
    m = re.search(r"^version:\s*([0-9]+\.[0-9]+\.[0-9]+)", text, re.MULTILINE)
    return m.group(1) if m else "1.0.0"


def desktop_entry() -> str:
    return (
        "[Desktop Entry]\n"
        "Type=Application\n"
        f"Name={APP_NAME}\n"
        "GenericName=Annotation de partitions\n"
        "Comment=Lecteur et annotateur de partitions PDF\n"
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
    """Force des permissions saines (les fichiers copiés depuis /mnt/c arrivent
    en 777). Dossiers → 0755, fichiers → 0644 ; l'exécutable est remis en 0755
    plus loin. dpkg-deb exige un dossier DEBIAN en 0755–0775."""
    for dirpath, dirnames, filenames in os.walk(root):
        os.chmod(dirpath, 0o755)
        for name in filenames:
            full = os.path.join(dirpath, name)
            if os.path.islink(full):
                continue  # ne pas suivre un symlink (ex. /usr/bin/arpege)
            os.chmod(full, 0o644)


def build_tree(version: str) -> Path:
    """Assemble l'arborescence du paquet et renvoie sa racine."""
    if STAGE.exists():
        shutil.rmtree(STAGE)

    # /opt/arpege ← bundle complet (exe + lib/ + data/)
    appdir = STAGE / INSTALL_DIR
    appdir.parent.mkdir(parents=True, exist_ok=True)
    shutil.copytree(BUNDLE, appdir)

    # /usr/bin/arpege → symlink vers l'exe (Flutter résout /proc/self/exe,
    # donc lib/ et data/ sont bien retrouvés à côté de la cible réelle).
    bindir = STAGE / "usr" / "bin"
    bindir.mkdir(parents=True, exist_ok=True)
    (bindir / BINARY).symlink_to(f"/{INSTALL_DIR}/{BINARY}")

    # Entrée menu .desktop
    appsdir = STAGE / "usr" / "share" / "applications"
    appsdir.mkdir(parents=True, exist_ok=True)
    (appsdir / f"{BINARY}.desktop").write_text(desktop_entry(), encoding="utf-8")

    # Icône (pixmaps : emplacement de repli indépendant de la taille)
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
        f"Description: {APP_NAME} — annotation de partitions PDF\n"
        " Lecteur et annotateur de partitions musicales (dièses, bémols,\n"
        " indications texte, dessin libre), avec bibliothèque et setlists.\n",
        encoding="utf-8",
    )

    # postinst : rafraîchit le menu et le cache d'icônes après installation
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

    # Normalise TOUT (0755 dossiers / 0644 fichiers), puis rend exécutables
    # les seuls fichiers qui doivent l'être. Indispensable car le bundle copié
    # depuis /mnt/c arrive en 777, ce que dpkg-deb refuse pour DEBIAN.
    normalize_perms(STAGE)
    os.chmod(appdir / BINARY, 0o755)
    os.chmod(postinst, 0o755)

    return STAGE


def main() -> int:
    if shutil.which("dpkg-deb") is None:
        print("ERREUR : dpkg-deb introuvable (installe le paquet « dpkg »).",
              file=sys.stderr)
        return 1

    version = read_version()

    # 1) Build Linux release.
    run("flutter build linux --release", cwd=ROOT, shell=True)
    if not BUNDLE.exists():
        print(f"ERREUR : bundle introuvable après le build : {BUNDLE}",
              file=sys.stderr)
        return 1

    # 2) Arborescence du paquet.
    pkgroot = build_tree(version)

    # 3) Construction du .deb (--root-owner-group : fichiers root:root sans sudo).
    DIST.mkdir(exist_ok=True)
    out = DIST / f"{BINARY}_{version}_{ARCH}.deb"
    run(["dpkg-deb", "--root-owner-group", "--build", str(pkgroot), str(out)])

    print(f"\n✅ Paquet généré : {out}")
    print(f"   Installer :  sudo apt install {out}")
    print(f"   (ou :        sudo dpkg -i {out} && sudo apt -f install)")
    print(f"   Désinstaller : sudo apt remove {BINARY}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
