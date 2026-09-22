#!/usr/bin/env python3
"""Construit Arpège (Windows release) puis fabrique l'installeur avec Inno Setup.

À lancer depuis Windows (PowerShell ou cmd), à la racine du projet :

    python installer\\build_installer.py

Prérequis : Flutter et Inno Setup 6 installés (https://jrsoftware.org/isdl.php).
Le setup.exe final est déposé dans le dossier dist\\.
"""
from __future__ import annotations

import os
import re
import shutil
import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
ISS = ROOT / "installer" / "arpege.iss"


def read_version() -> str:
    """Lit la version depuis pubspec.yaml (sans le numéro de build « +N »)."""
    text = (ROOT / "pubspec.yaml").read_text(encoding="utf-8")
    m = re.search(r"^version:\s*([0-9]+\.[0-9]+\.[0-9]+)", text, re.MULTILINE)
    return m.group(1) if m else "1.0.0"


def read_build_number() -> str | None:
    """Numéro de build (CI : nombre de commits sur la branche, cf. release.yml).
    Absent en local -> pas de 4ᵉ segment de version, comportement inchangé."""
    return os.environ.get("ARPEGE_BUILD_NUMBER") or None


def find_iscc() -> str | None:
    """Localise le compilateur Inno Setup (ISCC.exe)."""
    found = shutil.which("ISCC") or shutil.which("ISCC.exe")
    if found:
        return found
    for base in (
        r"C:\Program Files (x86)\Inno Setup 6",
        r"C:\Program Files\Inno Setup 6",
    ):
        candidate = Path(base) / "ISCC.exe"
        if candidate.exists():
            return str(candidate)
    return None


def run(cmd, **kwargs) -> None:
    printable = cmd if isinstance(cmd, str) else " ".join(str(c) for c in cmd)
    print(f"\n> {printable}")
    subprocess.run(cmd, check=True, **kwargs)


def main() -> int:
    build = read_build_number()

    # 1) Build Windows release (flutter est un .bat -> shell=True sous Windows).
    build_flag = f" --build-number={build}" if build else ""
    run(f"flutter build windows --release{build_flag}", cwd=ROOT, shell=True)

    # 2) Packaging Inno Setup.
    iscc = find_iscc()
    if not iscc:
        print(
            "\nERREUR : ISCC.exe (Inno Setup) introuvable.\n"
            "Installe Inno Setup 6 : https://jrsoftware.org/isdl.php",
            file=sys.stderr,
        )
        return 1
    # 4 segments (x.y.z.build) quand un build number CI est fourni, sinon x.y.z.
    version = read_version()
    full_version = f"{version}.{build}" if build else version
    run([iscc, f"/DMyAppVersion={full_version}", str(ISS)])

    # ASCII only : la console Windows (cp1252) ne sait pas encoder les emoji.
    print(f"\nOK - Installeur genere dans : {ROOT / 'dist'}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
