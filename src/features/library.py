"""Bibliothèque de partitions : stockage central des morceaux, métadonnées et setlists.

Les données sont conservées dans ``~/Documents/Arpège/config/library.json``. Les annotations
et signets propres à chaque partition restent dans le fichier d'annotations correspondant.
"""

import json
import os
import uuid
from datetime import datetime

METADATA_FIELDS = ["title", "composer", "arranger", "key", "tempo", "genre", "notes"]


def _config_dir():
    path = os.path.join(os.path.expanduser("~"), "Documents", "Arpège", "config")
    os.makedirs(path, exist_ok=True)
    return path


def _library_file():
    return os.path.join(_config_dir(), "library.json")


def _now():
    return datetime.now().isoformat()


class Library:
    """Charge, interroge et enregistre la bibliothèque de partitions."""

    def __init__(self):
        self.scores = []      # liste de dicts (voir _new_score)
        self.setlists = []    # liste de dicts {id, name, score_ids}
        self.load()

    # ---- Persistance ----------------------------------------------------

    def load(self):
        path = _library_file()
        if not os.path.exists(path):
            self.scores = []
            self.setlists = []
            return
        try:
            with open(path, 'r', encoding='utf-8') as f:
                data = json.load(f)
            self.scores = data.get('scores', [])
            self.setlists = data.get('setlists', [])
        except (json.JSONDecodeError, OSError):
            self.scores = []
            self.setlists = []

    def save(self):
        data = {'version': 1, 'scores': self.scores, 'setlists': self.setlists}
        try:
            with open(_library_file(), 'w', encoding='utf-8') as f:
                json.dump(data, f, indent=2, ensure_ascii=False)
        except OSError:
            pass

    # ---- Partitions -----------------------------------------------------

    def _new_score(self, path):
        score = {
            'id': uuid.uuid4().hex,
            'path': path,
            'added': _now(),
            'last_opened': _now(),
        }
        for field in METADATA_FIELDS:
            score[field] = ''
        # Titre par défaut : nom du fichier sans extension
        score['title'] = os.path.splitext(os.path.basename(path))[0]
        return score

    def get_score(self, score_id):
        return next((s for s in self.scores if s['id'] == score_id), None)

    def get_score_by_path(self, path):
        return next((s for s in self.scores if s['path'] == path), None)

    def add_or_touch(self, path):
        """Ajoute la partition si absente, sinon met à jour sa date d'ouverture."""
        score = self.get_score_by_path(path)
        if score is None:
            score = self._new_score(path)
            self.scores.append(score)
        else:
            score['last_opened'] = _now()
        self.save()
        return score

    def update_metadata(self, score_id, **fields):
        score = self.get_score(score_id)
        if not score:
            return None
        for key, value in fields.items():
            if key in METADATA_FIELDS:
                score[key] = value
        self.save()
        return score

    def remove_score(self, score_id):
        self.scores = [s for s in self.scores if s['id'] != score_id]
        for setlist in self.setlists:
            setlist['score_ids'] = [sid for sid in setlist['score_ids'] if sid != score_id]
        self.save()

    def search(self, query):
        """Retourne les partitions dont les métadonnées contiennent la requête."""
        query = (query or '').strip().lower()
        if not query:
            results = list(self.scores)
        else:
            results = []
            for score in self.scores:
                haystack = ' '.join(str(score.get(f, '')) for f in METADATA_FIELDS).lower()
                if query in haystack or query in score.get('path', '').lower():
                    results.append(score)
        results.sort(key=lambda s: s.get('title', '').lower())
        return results

    def existing_scores(self):
        """Partitions dont le fichier existe encore sur le disque."""
        return [s for s in self.scores if os.path.exists(s.get('path', ''))]

    # ---- Setlists -------------------------------------------------------

    def get_setlist(self, setlist_id):
        return next((sl for sl in self.setlists if sl['id'] == setlist_id), None)

    def add_setlist(self, name):
        setlist = {'id': uuid.uuid4().hex, 'name': name, 'score_ids': []}
        self.setlists.append(setlist)
        self.save()
        return setlist

    def rename_setlist(self, setlist_id, name):
        setlist = self.get_setlist(setlist_id)
        if setlist:
            setlist['name'] = name
            self.save()

    def remove_setlist(self, setlist_id):
        self.setlists = [sl for sl in self.setlists if sl['id'] != setlist_id]
        self.save()

    def add_to_setlist(self, setlist_id, score_id):
        setlist = self.get_setlist(setlist_id)
        if setlist and score_id not in setlist['score_ids']:
            setlist['score_ids'].append(score_id)
            self.save()

    def remove_from_setlist(self, setlist_id, score_id):
        setlist = self.get_setlist(setlist_id)
        if setlist:
            setlist['score_ids'] = [sid for sid in setlist['score_ids'] if sid != score_id]
            self.save()

    def set_setlist_order(self, setlist_id, score_ids):
        setlist = self.get_setlist(setlist_id)
        if setlist:
            setlist['score_ids'] = list(score_ids)
            self.save()

    def setlist_scores(self, setlist_id):
        """Partitions d'une setlist, dans l'ordre, en ignorant les ids introuvables."""
        setlist = self.get_setlist(setlist_id)
        if not setlist:
            return []
        scores = []
        for sid in setlist['score_ids']:
            score = self.get_score(sid)
            if score:
                scores.append(score)
        return scores

    # ---- Migration ------------------------------------------------------

    def import_paths(self, paths):
        """Importe une liste de chemins (ex. anciens fichiers récents) sans doublon."""
        changed = False
        for path in paths:
            if path and os.path.exists(path) and self.get_score_by_path(path) is None:
                self.scores.append(self._new_score(path))
                changed = True
        if changed:
            self.save()
