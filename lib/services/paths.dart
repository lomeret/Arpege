import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

/// Where the app keeps its data on disk.
///
/// An interface rather than a set of static helpers, so repositories can be
/// pointed at a temporary directory in tests instead of the real user
/// profile.
abstract class StorageLocations {
  Future<File> libraryFile();
  Future<File> recentFilesFile();
  Future<File> annotationsFileFor(String pdfPath);
}

/// Storage locations compatible with the old Python app.
///
/// On desktop, `getApplicationDocumentsDirectory()` returns the user's
/// "Documents" folder -> we end up with `~/Documents/Arpège/…`.
/// On Android, it returns a directory private to the app.
class AppPaths implements StorageLocations {
  /// Production locations, resolved through `path_provider`.
  AppPaths() : _fixedBase = null;

  /// Locations rooted at an explicit directory (tests, portable installs).
  AppPaths.at(String baseDir) : _fixedBase = baseDir;

  final String? _fixedBase;

  /// Cached only for the `path_provider` case: the platform call is not free
  /// and the answer never changes while the app runs.
  static String? _cachedBase;

  Future<String> _base() async {
    final fixed = _fixedBase;
    if (fixed != null) {
      await Directory(fixed).create(recursive: true);
      return fixed;
    }
    final cached = _cachedBase;
    if (cached != null) return cached;
    final docs = await getApplicationDocumentsDirectory();
    final base = p.join(docs.path, 'Arpège');
    await Directory(base).create(recursive: true);
    _cachedBase = base;
    return base;
  }

  Future<Directory> configDir() async {
    final dir = Directory(p.join(await _base(), 'config'));
    await dir.create(recursive: true);
    return dir;
  }

  Future<Directory> annotationsDir() async {
    final dir = Directory(p.join(await _base(), 'annotations'));
    await dir.create(recursive: true);
    return dir;
  }

  @override
  Future<File> libraryFile() async =>
      File(p.join((await configDir()).path, 'library.json'));

  @override
  Future<File> recentFilesFile() async =>
      File(p.join((await configDir()).path, 'recent_files.json'));

  @override
  Future<File> annotationsFileFor(String pdfPath) async {
    final name = p.basenameWithoutExtension(pdfPath);
    return File(
        p.join((await annotationsDir()).path, '${name}_annotations.json'));
  }
}
