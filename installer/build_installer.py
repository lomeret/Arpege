#!/usr/bin/env python3
"""Builds Arpège (Windows release) then packages the installer with Inno Setup.

Run from Windows (PowerShell or cmd), from the project root:

    python installer\\build_installer.py

Requirements: Flutter and Inno Setup 6 installed (https://jrsoftware.org/isdl.php).
The final setup.exe is dropped into the dist\\ folder.
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
    """Reads the version from pubspec.yaml (without the "+N" build number)."""
    text = (ROOT / "pubspec.yaml").read_text(encoding="utf-8")
    m = re.search(r"^version:\s*([0-9]+\.[0-9]+\.[0-9]+)", text, re.MULTILINE)
    return m.group(1) if m else "1.0.0"


def read_build_number() -> str | None:
    """Build number (CI: number of commits on the branch, see release.yml).
    Absent locally -> no 4th version segment, unchanged behavior."""
    return os.environ.get("ARPEGE_BUILD_NUMBER") or None


def find_iscc() -> str | None:
    """Locates the Inno Setup compiler (ISCC.exe)."""
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

    # 1) Build the Windows release (flutter is a .bat -> shell=True on Windows).
    build_flag = f" --build-number={build}" if build else ""
    run(f"flutter build windows --release{build_flag}", cwd=ROOT, shell=True)

    # 2) Inno Setup packaging.
    iscc = find_iscc()
    if not iscc:
        print(
            "\nERROR: ISCC.exe (Inno Setup) not found.\n"
            "Install Inno Setup 6: https://jrsoftware.org/isdl.php",
            file=sys.stderr,
        )
        return 1
    # 4 segments (x.y.z.build) when a CI build number is provided, else x.y.z.
    version = read_version()
    full_version = f"{version}.{build}" if build else version
    run([iscc, f"/DMyAppVersion={full_version}", str(ISS)])

    # ASCII only: the Windows console (cp1252) can't encode emoji.
    print(f"\nOK - Installer generated in: {ROOT / 'dist'}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
