import 'dart:io';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;

import '../models/score.dart';
import '../models/setlist.dart';
import '../services/json_file.dart';
import '../services/library_repository.dart';
import '../services/logger.dart';
import '../services/recent_files_repository.dart';

String _uuidHex() {
  final rnd = Random.secure();
  final bytes = List<int>.generate(16, (_) => rnd.nextInt(256));
  return bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
}

String _nowIso() => DateTime.now().toIso8601String();

/// Central library: scores, metadata and setlists.
class LibraryController extends ChangeNotifier {
  LibraryController({
    LibraryRepository? repository,
    RecentFilesRepository? recentFiles,
  })  : _repository = repository ?? FileLibraryRepository(),
        _recentFiles = recentFiles ?? FileRecentFilesRepository();

  final LibraryRepository _repository;
  final RecentFilesRepository _recentFiles;

  List<Score> scores = [];
  List<Setlist> setlists = [];

  /// Last storage failure, for the UI to show. Cleared by [clearError].
  String? get lastError => _lastError;
  String? _lastError;

  void clearError() {
    if (_lastError == null) return;
    _lastError = null;
    notifyListeners();
  }

  void _reportError(String message, Object error) {
    logError(message, error);
    _lastError = error is StorageException ? '$message: ${error.message}' : message;
  }

  Future<void> load() async {
    try {
      final data = await _repository.load();
      scores = List.of(data.scores);
      setlists = List.of(data.setlists);
    } catch (e, st) {
      // The repository has already moved the unreadable file aside, so
      // nothing is lost — but say so instead of showing an empty library as
      // if it were normal.
      scores = [];
      setlists = [];
      logError('Could not load the library', e, st);
      _reportError('Library could not be loaded, a copy was kept aside', e);
    }
    notifyListeners();
  }

  Future<void> save() async {
    try {
      await _repository.save(LibraryData(scores: scores, setlists: setlists));
    } catch (e, st) {
      logError('Could not save the library', e, st);
      _reportError('Library could not be saved', e);
    }
  }

  // ---- Scores ----------------------------------------------------

  Score? getScore(String id) {
    for (final s in scores) {
      if (s.id == id) return s;
    }
    return null;
  }

  Score? getScoreByPath(String path) {
    for (final s in scores) {
      if (s.path == path) return s;
    }
    return null;
  }

  Score _newScore(String path) => Score(
        id: _uuidHex(),
        path: path,
        added: _nowIso(),
        lastOpened: _nowIso(),
        title: p.basenameWithoutExtension(path),
      );

  Future<Score> addOrTouch(String path) async {
    var score = getScoreByPath(path);
    if (score == null) {
      score = _newScore(path);
      scores.add(score);
    } else {
      score.lastOpened = _nowIso();
    }
    await save();
    notifyListeners();
    return score;
  }

  Future<void> updateMetadata(String id, Map<String, String> fields) async {
    final score = getScore(id);
    if (score == null) return;
    fields.forEach((key, value) {
      if (Score.metadataFields.contains(key)) score.set(key, value);
    });
    await save();
    notifyListeners();
  }

  Future<void> removeScore(String id) async {
    final score = getScore(id);
    scores.removeWhere((s) => s.id == id);
    for (final sl in setlists) {
      sl.scoreIds.removeWhere((sid) => sid == id);
    }
    // Also remove it from "recent files", otherwise `importPaths` re-adds
    // the score on the next startup and the removal looks like it did nothing.
    if (score != null) {
      try {
        await _recentFiles.remove(score.path);
      } catch (e, st) {
        logError('Could not update the recent files list', e, st);
      }
    }
    await save();
    notifyListeners();
  }

  /// Scores whose metadata contains [query], sorted by title.
  List<Score> search(String query) {
    final q = query.trim().toLowerCase();
    List<Score> results;
    if (q.isEmpty) {
      results = List.of(scores);
    } else {
      results = scores.where((s) {
        final haystack =
            Score.metadataFields.map((f) => s.get(f)).join(' ').toLowerCase();
        return haystack.contains(q) || s.path.toLowerCase().contains(q);
      }).toList();
    }
    results.sort((a, b) => a.title.toLowerCase().compareTo(b.title.toLowerCase()));
    return results;
  }

  // ---- Setlists ------------------------------------------------------

  Setlist? getSetlist(String id) {
    for (final sl in setlists) {
      if (sl.id == id) return sl;
    }
    return null;
  }

  Future<Setlist> addSetlist(String name) async {
    final sl = Setlist(id: _uuidHex(), name: name, scoreIds: []);
    setlists.add(sl);
    await save();
    notifyListeners();
    return sl;
  }

  Future<void> renameSetlist(String id, String name) async {
    final sl = getSetlist(id);
    if (sl != null) {
      sl.name = name;
      await save();
      notifyListeners();
    }
  }

  Future<void> removeSetlist(String id) async {
    setlists.removeWhere((sl) => sl.id == id);
    await save();
    notifyListeners();
  }

  Future<void> addToSetlist(String setlistId, String scoreId) async {
    final sl = getSetlist(setlistId);
    if (sl != null && !sl.scoreIds.contains(scoreId)) {
      sl.scoreIds.add(scoreId);
      await save();
      notifyListeners();
    }
  }

  Future<void> removeFromSetlist(String setlistId, String scoreId) async {
    final sl = getSetlist(setlistId);
    if (sl != null) {
      sl.scoreIds.removeWhere((sid) => sid == scoreId);
      await save();
      notifyListeners();
    }
  }

  Future<void> setSetlistOrder(String setlistId, List<String> scoreIds) async {
    final sl = getSetlist(setlistId);
    if (sl != null) {
      sl.scoreIds = List.of(scoreIds);
      await save();
      notifyListeners();
    }
  }

  List<Score> setlistScores(String setlistId) {
    final sl = getSetlist(setlistId);
    if (sl == null) return [];
    final result = <Score>[];
    for (final sid in sl.scoreIds) {
      final score = getScore(sid);
      if (score != null) result.add(score);
    }
    return result;
  }

  // ---- Migration -----------------------------------------------------

  /// Imports the legacy "recent files" list into the library.
  Future<void> importRecentFiles() async {
    try {
      await importPaths(await _recentFiles.load());
    } catch (e, st) {
      logError('Could not import the recent files', e, st);
    }
  }

  Future<void> importPaths(List<String> paths) async {
    var changed = false;
    for (final path in paths) {
      if (path.isNotEmpty &&
          await File(path).exists() &&
          getScoreByPath(path) == null) {
        scores.add(_newScore(path));
        changed = true;
      }
    }
    if (changed) {
      await save();
      notifyListeners();
    }
  }
}
