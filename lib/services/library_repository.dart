import '../models/score.dart';
import '../models/setlist.dart';
import 'json_file.dart';
import 'paths.dart';

/// The whole library as stored in a single file.
class LibraryData {
  LibraryData({required this.scores, required this.setlists});

  LibraryData.empty()
      : scores = const [],
        setlists = const [];

  final List<Score> scores;
  final List<Setlist> setlists;
}

abstract class LibraryRepository {
  /// Returns the stored library, or an empty one when nothing was ever saved.
  ///
  /// Throws [StorageException] when a file exists but cannot be read. The
  /// caller must not answer that by saving over it — the implementation has
  /// already moved the unreadable file aside, but an empty save would still
  /// look to the user like the library vanished.
  Future<LibraryData> load();

  Future<void> save(LibraryData data);
}

class FileLibraryRepository implements LibraryRepository {
  FileLibraryRepository({StorageLocations? locations})
      : _locations = locations ?? AppPaths();

  final StorageLocations _locations;

  static const int _formatVersion = 1;

  @override
  Future<LibraryData> load() async {
    final file = await _locations.libraryFile();
    final Map<String, dynamic>? data;
    try {
      data = await readJsonObject(file);
    } on StorageException {
      // Preserve the bytes: they may still be recoverable by hand, and the
      // next save must not overwrite them.
      await quarantineFile(file);
      rethrow;
    }
    if (data == null) return LibraryData.empty();

    return LibraryData(
      scores: ((data['scores'] as List?) ?? const [])
          .map((s) => Score.fromJson(Map<String, dynamic>.from(s as Map)))
          .toList(),
      setlists: ((data['setlists'] as List?) ?? const [])
          .map((s) => Setlist.fromJson(Map<String, dynamic>.from(s as Map)))
          .toList(),
    );
  }

  @override
  Future<void> save(LibraryData data) async {
    final file = await _locations.libraryFile();
    await writeJsonObjectAtomically(file, {
      'version': _formatVersion,
      'scores': data.scores.map((s) => s.toJson()).toList(),
      'setlists': data.setlists.map((s) => s.toJson()).toList(),
    });
  }
}
