import 'dart:convert';
import 'dart:io';

import 'paths.dart';

/// List of recently opened PDFs — port of `utils/recent_files.py`.
class RecentFiles {
  static const int maxRecent = 10;

  static Future<List<String>> load() async {
    try {
      final file = await AppPaths.recentFilesFile();
      if (!await file.exists()) return [];
      final data = jsonDecode(await file.readAsString()) as Map<String, dynamic>;
      final recent = (data['recent_files'] as List?) ?? const [];
      final paths = recent.map((e) => e as String).toList();
      // Only keep files that still exist.
      return [
        for (final path in paths)
          if (await File(path).exists()) path
      ];
    } catch (_) {
      return [];
    }
  }

  static Future<List<String>> add(String filePath) async {
    var recent = await load();
    recent = recent.where((p) => p != filePath).toList();
    recent.insert(0, filePath);
    if (recent.length > maxRecent) recent = recent.sublist(0, maxRecent);
    await _write(recent);
    return recent;
  }

  /// Removes a path from the recent list (used when permanently deleting a
  /// score, otherwise it would reappear on the next startup).
  static Future<void> remove(String filePath) async {
    final recent = (await load()).where((p) => p != filePath).toList();
    await _write(recent);
  }

  static Future<void> _write(List<String> recent) async {
    try {
      final file = await AppPaths.recentFilesFile();
      await file.writeAsString(
        const JsonEncoder.withIndent('  ').convert({'recent_files': recent}),
      );
    } catch (_) {}
  }
}
