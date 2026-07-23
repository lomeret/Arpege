# Arpège — Éditeur de partitions PDF

Arpège est une application multiplateforme (Windows, Android, Linux) pour musiciens :
elle permet d'ouvrir, d'annoter et d'organiser des partitions PDF. Réécrite en
**Flutter/Dart** à partir de l'application Python/Qt d'origine, elle partage une base de
code unique pour les trois cibles.

## Fonctionnalités

- **Lecture PDF** : rendu haute qualité (pdfium), zoom (molette/pincement), déplacement,
  ajustement à la fenêtre.
- **Annotations** : crayon libre (couleur + 3 épaisseurs), dièses ♯, bémols ♭, indications
  textuelles. Gomme pour supprimer un élément.
- **Annuler / Rétablir** sur les modifications d'annotations.
- **Navigation** : pages précédente/suivante, première/dernière, appui sur la moitié
  gauche/droite pour tourner la page.
- **Vue double page** : moitié basse de la page courante au-dessus, moitié haute de la
  suivante en dessous, pour anticiper les tournes.
- **Gestion des pages** : réordonner, masquer, dupliquer les pages dans une séquence
  personnalisée qui n'altère jamais le PDF d'origine.
- **Signets** par partition.
- **Bibliothèque** de partitions avec métadonnées (titre, compositeur, arrangeur, tonalité,
  tempo, genre, notes) et recherche.
- **Setlists** : listes ordonnées de morceaux, navigation morceau précédent/suivant.
- **Fichiers récents**.
- **Export PDF annoté** : fusionne les annotations en vectoriel dans une copie du PDF.

Les données restent **compatibles avec l'ancienne app Python** : mêmes fichiers JSON aux
mêmes emplacements.

- Bibliothèque et setlists : `~/Documents/Arpège/config/library.json`
- Fichiers récents : `~/Documents/Arpège/config/recent_files.json`
- Annotations (une par PDF) : `~/Documents/Arpège/annotations/<nom>_annotations.json`

(Sur Android, ces fichiers se trouvent dans le dossier de documents privé de l'application.)

## Raccourcis clavier (desktop)

| Raccourci | Action |
| --- | --- |
| `Ctrl+O` | Ouvrir un PDF |
| `Ctrl+S` | Sauvegarder les annotations |
| `Ctrl+E` | Exporter le PDF annoté |
| `Ctrl+Z` / `Ctrl+Y` | Annuler / Rétablir |
| `←` / `→`, `Page↑` / `Page↓` | Page précédente / suivante |
| `Début` / `Fin` | Première / dernière page |
| `Ctrl+ +` / `Ctrl+ -` / `Ctrl+0` | Zoom avant / arrière / ajuster |
| `Ctrl+D` | Vue double page |
| `Ctrl+B` | Ajouter un signet |
| `Alt+←` / `Alt+→` | Morceau précédent / suivant (setlist) |
| `Échap` | Désélectionner l'outil |

## Développement

Prérequis : [Flutter](https://docs.flutter.dev/get-started/install) (stable, ≥ 3.24).

```bash
flutter pub get
flutter run          # lance sur la cible connectée (desktop ou appareil Android)
flutter analyze      # analyse statique
```

## Compilation des exécutables

> Les builds desktop de Flutter sont **host-only** : un `.exe` Windows se compile sur
> Windows, un binaire Linux sur Linux. Android se compile depuis n'importe quel hôte.
> Le workflow CI [`.github/workflows/build.yml`](.github/workflows/build.yml) produit
> automatiquement les trois artefacts (Linux, Android, Windows).

> **Version minimale : Flutter ≥ 3.41 / Dart ≥ 3.10.** Requis par `pdfrx 2.4.7`.
> Une version antérieure fait échouer la résolution (`pdfrx requires SDK ^3.10.0`)
> ou la compilation (`_PdfTextRenderBox is missing implementations`). Sur une
> version trop ancienne : `flutter upgrade`.

Les scripts ci-dessous ne sont que des enveloppes ; on peut appeler `flutter`
directement. Sous Windows, tout se pilote depuis **PowerShell** (`flutter build …`),
y compris l'APK Android.

### Linux

```bash
sudo apt-get install -y clang cmake ninja-build pkg-config libgtk-3-dev
./build-linux.sh
# → build/linux/x64/release/bundle/arpege
```

### Android

```bash
./build-android.sh              # enveloppe de la commande ci-dessous
flutter build apk --release     # équivalent direct
# → build/app/outputs/flutter-apk/app-release.apk
```

### Windows (sur une machine Windows)

Prérequis : Visual Studio 2022 (« Desktop development with C++ ») et le **Mode
développeur** Windows activé (pdfrx utilise des liens symboliques à la compilation).

```powershell
./build-windows.ps1             # enveloppe de la commande ci-dessous
flutter build windows           # équivalent direct
# → build\windows\x64\runner\Release\arpege.exe
```

> ⚠️ L'app compilée n'est **pas** un `.exe` autonome : distribuer tout le dossier
> `Release\` (exe + `flutter_windows.dll` + `pdfium.dll` + `data\`), ou générer un
> installeur unique avec `python installer\build_installer.py` (voir `installer/`).

## Architecture

```
lib/
  main.dart              point d'entrée, providers, layout responsive, raccourcis
  theme.dart             thème sombre (Catppuccin Mocha)
  models/                Score, Setlist, Notation/DrawingPath, Bookmark, AnnotationDocument
  services/              chemins, bibliothèque, fichiers récents, annotations, export PDF
  state/                 LibraryController, EditorController, HistoryManager
  pdf/pdf_renderer.dart  rendu des pages via pdfrx
  widgets/               vue partition (zoom/pan/dessin), barres, panneaux, dialogues
```

Dépendances principales : `pdfrx` (rendu), `syncfusion_flutter_pdf` (export),
`provider` (état), `path_provider`, `file_picker`.

## Licence

MIT.
