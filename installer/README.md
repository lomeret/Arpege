# Packaging & installing Arpège

This folder contains the installer builders used to ship Arpège to end users
(without requiring them to install Flutter).

| Target | Builder | Output | Location |
| --- | --- | --- | --- |
| Windows | `build_installer.py` (Inno Setup) | `Arpege-Setup-<version>.exe` | `dist/` |
| Debian/Ubuntu | `build_deb.py` (dpkg-deb) | `arpege_<version>_amd64.deb` | `dist/` |

> Reminder: a Flutter desktop build is **not** a standalone executable, but a
> folder (exe + libraries + `data/`). These installers package the whole
> folder and add system integration (menu, icon, uninstall).
> Each installer must be built **on the target platform** (Windows on
> Windows, `.deb` on Linux/WSL).

---

## Windows (`.exe`)

### Requirements
- [Flutter](https://docs.flutter.dev/get-started/install) (see the main README)
- Visual Studio 2022 ("Desktop development with C++") + Windows **Developer Mode**
- [Inno Setup 6](https://jrsoftware.org/isdl.php)

### Building the installer
From **PowerShell**, at the project root:

```powershell
python installer\build_installer.py
# 1) flutter build windows --release
# 2) Inno Setup packages build\windows\x64\runner\Release\
# → dist\Arpege-Setup-1.0.0.exe
```

### Install / uninstall
- **Install**: double-click `dist\Arpege-Setup-1.0.0.exe`, follow the wizard.
  (Installs into `Program Files\Arpege`, creates a Start Menu shortcut.)
- **Uninstall**: Windows Settings → Apps → *Arpège* → Uninstall.

---

## Debian / Ubuntu (`.deb`)

### Requirements
- Flutter with Linux desktop enabled:
  ```bash
  flutter config --enable-linux-desktop
  ```
- Build dependencies:
  ```bash
  sudo apt-get install -y clang cmake ninja-build pkg-config libgtk-3-dev
  ```
- `dpkg-deb` (the `dpkg` package, present by default on Debian/Ubuntu)

### Building the package
At the project root:

```bash
python3 installer/build_deb.py
# 1) flutter build linux --release
# 2) assembles the Debian tree + dpkg-deb --build
# → dist/arpege_1.0.0_amd64.deb
```

### Installing

**Recommended — `apt`** (also installs system dependencies):

```bash
sudo apt install ./dist/arpege_1.0.0_amd64.deb
```

> ⚠️ The `./` (or an absolute path) is **required**: without it, `apt` looks
> for a package named "arpege" in the repositories and fails.

**Alternative — `dpkg`** (then fix dependencies if needed):

```bash
sudo dpkg -i ./dist/arpege_1.0.0_amd64.deb
sudo apt -f install        # pulls in missing dependencies flagged by dpkg
```

### Launching
- From the application menu: **Arpège**
- Or from the command line: `arpege`

### Uninstalling
```bash
sudo apt remove arpege        # (or: sudo dpkg -r arpege)
```

### Where is the app installed?
| Path | Contents |
| --- | --- |
| `/opt/arpege/` | the full bundle (exe + `lib/*.so` + `data/`) |
| `/usr/bin/arpege` | launcher symlink (on the `PATH`) |
| `/usr/share/applications/arpege.desktop` | menu entry |
| `/usr/share/pixmaps/arpege.png` | icon |

### WSL note
The script stages the package tree in `/tmp` (not in the repo) then
normalizes permissions. This is required because under WSL the repo sits on
`/mnt/c` (drvfs) where everything is 777 and `chmod` is ignored — `dpkg-deb`
then refuses the `DEBIAN` control folder. The final `.deb` is written to
`dist/` without issue.

A `.deb` targets **Debian/Ubuntu** (`apt`/`dpkg`). For Fedora/Arch, you'd need
an `.rpm`/`PKGBUILD`; for a single multi-distro executable, an **AppImage**.
