import 'dart:io';

import 'json_file.dart';
import 'logger.dart';
import 'paths.dart';

/// The list of recently opened PDFs.
abstract class RecentFilesRepository {
  Future<List<String>> load();
  Future<void> add(String filePath);
  Future<void> remove(String filePath);
}

class FileRecentFilesRepository implements RecentFilesRepository {
  FileRecentFilesRepository({StorageLocations? locations})
      : _locations = locations ?? AppPaths();

  final StorageLocations _locations;

  static const int maxRecent = 10;

  @override
  Future<List<String>> load() async {
    final file = await _locations.recentFilesFile();
    final Map<String, dynamic>? data;
    try {
      data = await readJsonObject(file);
    } on StorageException catch (e) {
      // Not worth bothering the user about: this list is a convenience, it
      // is rebuilt as soon as scores are opened again.
      logError('Recent files list unreadable, starting empty', e);
      return [];
    }
    if (data == null) return [];

    final recent = (data['recent_files'] as List?) ?? const [];
    final paths = recent.whereType<String>();
    return [
      for (final path in paths)
        if (await File(path).exists()) path
    ];
  }

  @override
  Future<void> add(String filePath) async {
    final recent = (await load())..removeWhere((p) => p == filePath);
    recent.insert(0, filePath);
    await _write(recent.take(maxRecent).toList());
  }

  @override
  Future<void> remove(String filePath) async {
    final recent = (await load())..removeWhere((p) => p == filePath);
    await _write(recent);
  }

  Future<void> _write(List<String> recent) async {
    final file = await _locations.recentFilesFile();
    await writeJsonObjectAtomically(file, {'recent_files': recent});
  }
}
