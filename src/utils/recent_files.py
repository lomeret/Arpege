import json
import os

MAX_RECENT = 10


def _config_dir():
    path = os.path.join(os.path.expanduser("~"), "Documents", "Arpège", "config")
    os.makedirs(path, exist_ok=True)
    return path


def _config_file():
    return os.path.join(_config_dir(), "recent_files.json")


def load_recent_files():
    """Retourne la liste des chemins PDF récents, du plus récent au plus ancien."""
    path = _config_file()
    if not os.path.exists(path):
        return []
    try:
        with open(path, 'r', encoding='utf-8') as f:
            data = json.load(f)
        recent = data.get('recent_files', [])
        return [p for p in recent if os.path.exists(p)]
    except (json.JSONDecodeError, OSError):
        return []


def add_recent_file(file_path):
    """Ajoute un fichier en tête de la liste des récents (sans doublon)."""
    recent = load_recent_files()
    recent = [p for p in recent if p != file_path]
    recent.insert(0, file_path)
    recent = recent[:MAX_RECENT]
    try:
        with open(_config_file(), 'w', encoding='utf-8') as f:
            json.dump({'recent_files': recent}, f, indent=2, ensure_ascii=False)
    except OSError:
        pass
    return recent
