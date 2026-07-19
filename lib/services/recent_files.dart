import 'dart:convert';
import 'dart:io';

import 'paths.dart';

/// Liste des PDF récemment ouverts — port de `utils/recent_files.py`.
class RecentFiles {
  static const int maxRecent = 10;

  static Future<List<String>> load() async {
    try {
      final file = await AppPaths.recentFilesFile();
      if (!await file.exists()) return [];
      final data = jsonDecode(await file.readAsString()) as Map<String, dynamic>;
      final recent = (data['recent_files'] as List?) ?? const [];
      final paths = recent.map((e) => e as String).toList();
      // Ne conserve que les fichiers qui existent encore.
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
    try {
      final file = await AppPaths.recentFilesFile();
      await file.writeAsString(
        const JsonEncoder.withIndent('  ').convert({'recent_files': recent}),
      );
    } catch (_) {}
    return recent;
  }
}
