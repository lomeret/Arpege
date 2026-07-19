import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;

import '../models/score.dart';
import '../models/setlist.dart';
import '../services/paths.dart';

String _uuidHex() {
  final rnd = Random.secure();
  final bytes = List<int>.generate(16, (_) => rnd.nextInt(256));
  return bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
}

String _nowIso() => DateTime.now().toIso8601String();

/// Bibliothèque centrale : partitions, métadonnées et setlists.
/// Port de `features/library.py`, exposé comme ChangeNotifier.
class LibraryController extends ChangeNotifier {
  List<Score> scores = [];
  List<Setlist> setlists = [];

  Future<void> load() async {
    try {
      final file = await AppPaths.libraryFile();
      if (await file.exists()) {
        final data = jsonDecode(await file.readAsString()) as Map<String, dynamic>;
        scores = ((data['scores'] as List?) ?? const [])
            .map((s) => Score.fromJson(Map<String, dynamic>.from(s as Map)))
            .toList();
        setlists = ((data['setlists'] as List?) ?? const [])
            .map((s) => Setlist.fromJson(Map<String, dynamic>.from(s as Map)))
            .toList();
      }
    } catch (_) {
      scores = [];
      setlists = [];
    }
    notifyListeners();
  }

  Future<void> save() async {
    try {
      final file = await AppPaths.libraryFile();
      final data = {
        'version': 1,
        'scores': scores.map((s) => s.toJson()).toList(),
        'setlists': setlists.map((s) => s.toJson()).toList(),
      };
      await file.writeAsString(const JsonEncoder.withIndent('  ').convert(data));
    } catch (_) {}
  }

  // ---- Partitions ----------------------------------------------------

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
    scores.removeWhere((s) => s.id == id);
    for (final sl in setlists) {
      sl.scoreIds.removeWhere((sid) => sid == id);
    }
    await save();
    notifyListeners();
  }

  /// Partitions dont les métadonnées contiennent [query], triées par titre.
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
