# Empaquetage & installation d'Arpège

Ce dossier contient les générateurs d'installeurs pour distribuer Arpège aux
utilisateurs finaux (sans qu'ils aient à installer Flutter).

| Cible | Générateur | Produit | Sortie |
| --- | --- | --- | --- |
| Windows | `build_installer.py` (Inno Setup) | `Arpege-Setup-<version>.exe` | `dist/` |
| Debian/Ubuntu | `build_deb.py` (dpkg-deb) | `arpege_<version>_amd64.deb` | `dist/` |

> Rappel : un build desktop Flutter n'est **pas** un exécutable autonome, mais un
> dossier (exe + bibliothèques + `data/`). Ces installeurs empaquettent tout le
> dossier et ajoutent l'intégration système (menu, icône, désinstallation).
> Chaque installeur se génère **sur la plateforme cible** (Windows sur Windows,
> `.deb` sur Linux/WSL).

---

## Windows (`.exe`)

### Prérequis
- [Flutter](https://docs.flutter.dev/get-started/install) (voir README principal)
- Visual Studio 2022 (« Desktop development with C++ ») + **Mode développeur** Windows
- [Inno Setup 6](https://jrsoftware.org/isdl.php)

### Générer l'installeur
Depuis **PowerShell**, à la racine du projet :

```powershell
python installer\build_installer.py
# 1) flutter build windows --release
# 2) Inno Setup empaquette build\windows\x64\runner\Release\
# → dist\Arpege-Setup-1.0.0.exe
```

### Installer / désinstaller
- **Installer** : double-clic sur `dist\Arpege-Setup-1.0.0.exe`, suivre l'assistant.
  (Installe dans `Program Files\Arpege`, crée le raccourci menu Démarrer.)
- **Désinstaller** : Paramètres Windows → Applications → *Arpège* → Désinstaller.

---

## Debian / Ubuntu (`.deb`)

### Prérequis
- Flutter avec le desktop Linux activé :
  ```bash
  flutter config --enable-linux-desktop
  ```
- Dépendances de build :
  ```bash
  sudo apt-get install -y clang cmake ninja-build pkg-config libgtk-3-dev
  ```
- `dpkg-deb` (paquet `dpkg`, présent par défaut sur Debian/Ubuntu)

### Générer le paquet
À la racine du projet :

```bash
python3 installer/build_deb.py
# 1) flutter build linux --release
# 2) assemble l'arbo Debian + dpkg-deb --build
# → dist/arpege_1.0.0_amd64.deb
```

### Installer

**Méthode recommandée — `apt`** (installe aussi les dépendances système) :

```bash
sudo apt install ./dist/arpege_1.0.0_amd64.deb
```

> ⚠️ Le `./` (ou un chemin absolu) est **obligatoire** : sans lui, `apt` cherche un
> paquet nommé « arpege » dans les dépôts et échoue.

**Alternative — `dpkg`** (puis réparer les dépendances si besoin) :

```bash
sudo dpkg -i ./dist/arpege_1.0.0_amd64.deb
sudo apt -f install        # tire les dépendances manquantes signalées par dpkg
```

### Lancer
- Depuis le menu des applications : **Arpège**
- Ou en ligne de commande : `arpege`

### Désinstaller
```bash
sudo apt remove arpege        # (ou : sudo dpkg -r arpege)
```

### Où est installée l'app ?
| Chemin | Contenu |
| --- | --- |
| `/opt/arpege/` | le bundle complet (exe + `lib/*.so` + `data/`) |
| `/usr/bin/arpege` | symlink de lancement (dans le `PATH`) |
| `/usr/share/applications/arpege.desktop` | entrée menu |
| `/usr/share/pixmaps/arpege.png` | icône |

### Note WSL
Le script construit l'arbo du paquet dans `/tmp` (et non dans le repo) puis
normalise les permissions. C'est nécessaire car sous WSL le repo est sur `/mnt/c`
(drvfs) où tout est en 777 et `chmod` est ignoré — `dpkg-deb` refuse alors le
dossier de contrôle `DEBIAN`. Le `.deb` final est écrit dans `dist/` sans souci.

Un `.deb` cible **Debian/Ubuntu** (`apt`/`dpkg`). Pour Fedora/Arch, il faudrait un
`.rpm`/`PKGBUILD` ; pour un exécutable unique multi-distros, un **AppImage**.
