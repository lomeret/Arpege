# Arpège — PDF Sheet Music Editor

Arpège is a cross-platform app (Windows, Android, Linux) for musicians:
it lets you open, annotate, and organize PDF sheet music. Rewritten in
**Flutter/Dart** from the original Python/Qt app, it shares a single
codebase across all three targets.

## Features

- **PDF viewing**: high-quality rendering (pdfium), zoom (scroll wheel/pinch), pan,
  fit-to-window.
- **Annotations**: free-hand pencil (color + 3 thicknesses), sharps ♯, flats ♭, text
  indications. Eraser to remove an element.
- **Undo / Redo** on annotation changes.
- **Navigation**: previous/next page, first/last, tap the left/right half of the
  screen to turn the page.
- **Two-page spread view**: bottom half of the current page above, top half of the
  next one below, to anticipate page turns.
- **Page management**: reorder, hide, duplicate pages in a custom sequence that
  never alters the original PDF.
- **Bookmarks** per score.
- **Library** of scores with metadata (title, composer, arranger, key, tempo,
  genre, notes) and search.
- **Setlists**: ordered lists of songs, previous/next song navigation.
- **Recent files**.
- **Annotated PDF export**: merges the annotations as vector graphics into a copy
  of the PDF.

Data stays **compatible with the old Python app**: same JSON files at the same
locations.

- Library and setlists: `~/Documents/Arpège/config/library.json`
- Recent files: `~/Documents/Arpège/config/recent_files.json`
- Annotations (one per PDF): `~/Documents/Arpège/annotations/<name>_annotations.json`

(On Android, these files live in the app's private documents folder.)

## Keyboard shortcuts (desktop)

| Shortcut | Action |
| --- | --- |
| `Ctrl+O` | Open a PDF |
| `Ctrl+S` | Save annotations |
| `Ctrl+E` | Export the annotated PDF |
| `Ctrl+Z` / `Ctrl+Y` | Undo / Redo |
| `←` / `→`, `Page Up` / `Page Down` | Previous / next page |
| `Home` / `End` | First / last page |
| `Ctrl+ +` / `Ctrl+ -` / `Ctrl+0` | Zoom in / out / fit |
| `Ctrl+D` | Two-page spread view |
| `Ctrl+B` | Add a bookmark |
| `Alt+←` / `Alt+→` | Previous / next song (setlist) |
| `Esc` | Deselect the current tool |

## Development

Requirements: [Flutter](https://docs.flutter.dev/get-started/install) (stable, ≥ 3.24).

```bash
flutter pub get
flutter run          # launches on the connected target (desktop or Android device)
flutter analyze      # static analysis
```

## Building the executables

> Flutter desktop builds are **host-only**: a Windows `.exe` is built on
> Windows, a Linux binary on Linux. Android can be built from any host.
> The CI workflow [`.github/workflows/build.yml`](.github/workflows/build.yml) automatically
> produces all three artifacts (Linux, Android, Windows).

> **Minimum version: Flutter ≥ 3.41 / Dart ≥ 3.10.** Required by `pdfrx 2.4.7`.
> An older version fails dependency resolution (`pdfrx requires SDK ^3.10.0`)
> or compilation (`_PdfTextRenderBox is missing implementations`). On an
> older version: `flutter upgrade`.

The scripts below are just wrappers; you can call `flutter` directly. On
Windows, everything is driven from **PowerShell** (`flutter build …`),
including the Android APK.

### Linux

```bash
sudo apt-get install -y clang cmake ninja-build pkg-config libgtk-3-dev
flutter config --enable-linux-desktop
./build-linux.sh                 # or: flutter build linux --release
# → build/linux/x64/release/bundle/  (a folder, not a single exe)
```

> For a **clean install** (a `.deb` package with a menu entry, icon, and
> dependencies handled by `apt`): `python3 installer/build_deb.py`, then
> `sudo apt install ./dist/arpege_*.deb`.
> Details and uninstall instructions: [installer/README.md](installer/README.md).

### Android

```bash
./build-android.sh              # wrapper around the command below
flutter build apk --release     # direct equivalent
# → build/app/outputs/flutter-apk/app-release.apk
```

### Windows (on a Windows machine)

Requirements: Visual Studio 2022 ("Desktop development with C++") and Windows
**Developer Mode** enabled (pdfrx uses symbolic links at build time).

```powershell
./build-windows.ps1             # wrapper around the command below
flutter build windows           # direct equivalent
# → build\windows\x64\runner\Release\arpege.exe
```

> ⚠️ The compiled app is **not** a standalone `.exe`: distribute the whole
> `Release\` folder (exe + `flutter_windows.dll` + `pdfium.dll` + `data\`), or
> generate a single installer with `python installer\build_installer.py`.
> Details: [installer/README.md](installer/README.md).

## Installers (distributing to users)

To distribute the packaged app (Windows `.exe` installer or Debian `.deb`
package), with build, install and uninstall instructions: see
**[installer/README.md](installer/README.md)**.

## Architecture

```
lib/
  main.dart              entry point, providers, responsive layout, shortcuts
  theme.dart              dark theme (Catppuccin Mocha)
  models/                Score, Setlist, Notation/DrawingPath, Bookmark, AnnotationDocument
  services/              paths, library, recent files, annotations, PDF export
  state/                 LibraryController, EditorController, HistoryManager
  pdf/pdf_renderer.dart  page rendering via pdfrx
  widgets/               score view (zoom/pan/drawing), toolbars, panels, dialogs
```

Main dependencies: `pdfrx` (rendering), `syncfusion_flutter_pdf` (export),
`provider` (state), `path_provider`, `file_picker`.

## License

MIT.
