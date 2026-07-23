#!/usr/bin/env python3
"""Construit Arpège (Windows release) puis fabrique l'installeur avec Inno Setup.

À lancer depuis Windows (PowerShell ou cmd), à la racine du projet :

    python installer\\build_installer.py

Prérequis : Flutter et Inno Setup 6 installés (https://jrsoftware.org/isdl.php).
Le setup.exe final est déposé dans le dossier dist\\.
"""
from __future__ import annotations

import shutil
import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
ISS = ROOT / "installer" / "arpege.iss"


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
    # 1) Build Windows release (flutter est un .bat -> shell=True sous Windows).
    run("flutter build windows --release", cwd=ROOT, shell=True)

    # 2) Packaging Inno Setup.
    iscc = find_iscc()
    if not iscc:
        print(
            "\nERREUR : ISCC.exe (Inno Setup) introuvable.\n"
            "Installe Inno Setup 6 : https://jrsoftware.org/isdl.php",
            file=sys.stderr,
        )
        return 1
    run([iscc, str(ISS)])

    print(f"\n✅ Installeur généré dans : {ROOT / 'dist'}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
