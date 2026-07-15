# Music Sheet Editor

Music Sheet Editor is a Python application designed for musicians to manage and annotate their PDF music sheets. This application allows users to select PDF files, make modifications such as adding sharps, flats, and annotations, and navigate through their music sheets seamlessly.

## Features

- **PDF Handling**: Load and save PDF music sheets with ease.
- **Annotation Management**: Add, remove, and list annotations on music sheets.
- **Music Notation Editing**: Modify music notation by adding sharps, flats, and other indications.
- **Eraser Tool**: Click near a symbol or a pencil stroke to delete just that element.
- **Undo / Redo**: `Ctrl+Z` / `Ctrl+Y` step back and forward through annotation edits.
- **Zoom & Pan**: Mouse wheel to zoom (centered on the cursor), right-click drag to pan.
- **Two-page Spread View**: "Affichage > Vue double page" shows two consecutive pages side by
  side, so page turns can be anticipated while playing.
- **Keyboard Navigation**: Left/Right, Page Up/Down, Home/End to move between pages; `Esc` to
  deselect the current tool.
- **Recent Files**: "Fichier > Fichiers récents" reopens a previously annotated score in one click.
- **Annotated PDF Export**: "Fichier > Exporter PDF annoté..." merges all annotations into a new,
  shareable/printable PDF.
- **User-Friendly Interface**: Intuitive interface for easy navigation and interaction with music sheets.

## Installation

1. Clone the repository:
   ```
   git clone https://github.com/lomeret/Arpege.git
   ```
2. Navigate to the project directory:
   ```
   cd Arpege
   ```
3. Create and activate a virtual environment:
   ```
   python -m venv venv
   # Windows
   venv\Scripts\activate
   # macOS/Linux
   source venv/bin/activate
   ```
4. Install the required dependencies:
   ```
   pip install -r requirements.txt
   ```

## Usage

To run the application, activate the virtual environment (see above) then execute:
```
python src/main.py
```

Follow the on-screen instructions to select and edit your PDF music sheets.

### Keyboard shortcuts

| Shortcut | Action |
| --- | --- |
| `Ctrl+O` | Open a PDF |
| `Ctrl+S` | Save annotations |
| `Ctrl+Z` / `Ctrl+Y` | Undo / Redo |
| `Left` / `Right`, `Page Up` / `Page Down` | Previous / next page |
| `Home` / `End` | First / last page |
| `Ctrl+ +` / `Ctrl+ -` / `Ctrl+0` | Zoom in / out / reset |
| Mouse wheel | Zoom at cursor |
| Right-click drag | Pan the view |
| `Esc` | Deactivate the current tool |

## Contributing

Contributions are welcome! Please feel free to submit a pull request or open an issue for any suggestions or improvements.

## License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.