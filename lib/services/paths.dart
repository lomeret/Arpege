import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

/// Emplacements de stockage, compatibles avec l'ancienne app Python.
///
/// Sur desktop, `getApplicationDocumentsDirectory()` renvoie le dossier
/// « Documents » de l'utilisateur → on retrouve `~/Documents/Arpège/…`.
/// Sur Android, il renvoie un dossier privé à l'application.
class AppPaths {
  static String? _baseDir;

  static Future<String> _base() async {
    if (_baseDir != null) return _baseDir!;
    final docs = await getApplicationDocumentsDirectory();
    final base = p.join(docs.path, 'Arpège');
    await Directory(base).create(recursive: true);
    _baseDir = base;
    return base;
  }

  static Future<Directory> configDir() async {
    final dir = Directory(p.join(await _base(), 'config'));
    await dir.create(recursive: true);
    return dir;
  }

  static Future<Directory> annotationsDir() async {
    final dir = Directory(p.join(await _base(), 'annotations'));
    await dir.create(recursive: true);
    return dir;
  }

  static Future<File> libraryFile() async =>
      File(p.join((await configDir()).path, 'library.json'));

  static Future<File> recentFilesFile() async =>
      File(p.join((await configDir()).path, 'recent_files.json'));

  static Future<File> annotationsFileFor(String pdfPath) async {
    final name = p.basenameWithoutExtension(pdfPath);
    return File(p.join((await annotationsDir()).path, '${name}_annotations.json'));
  }
}
