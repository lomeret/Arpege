import 'dart:convert';
import 'dart:io';

import 'logger.dart';

/// A storage operation that failed in a way the user should hear about.
class StorageException implements Exception {
  StorageException(this.message, {this.path, this.cause});

  final String message;
  final String? path;
  final Object? cause;

  @override
  String toString() =>
      path == null ? message : '$message ($path)';
}

const _encoder = JsonEncoder.withIndent('  ');

/// Reads a JSON object from [file].
///
/// Returns `null` when the file does not exist. Throws [StorageException]
/// when it exists but cannot be read or parsed — callers decide what to do
/// with a corrupt file, they never get a silent empty result.
Future<Map<String, dynamic>?> readJsonObject(File file) async {
  if (!await file.exists()) return null;
  String content;
  try {
    content = await file.readAsString();
  } catch (e, st) {
    logError('Cannot read ${file.path}', e, st);
    throw StorageException('File could not be read',
        path: file.path, cause: e);
  }
  try {
    final decoded = jsonDecode(content);
    if (decoded is! Map) {
      throw const FormatException('Root value is not a JSON object');
    }
    return Map<String, dynamic>.from(decoded);
  } catch (e, st) {
    logError('Cannot parse ${file.path}', e, st);
    throw StorageException('File is not valid JSON',
        path: file.path, cause: e);
  }
}

/// Writes [data] to [file] atomically.
///
/// The payload goes to a sibling `.tmp` file which is then renamed over the
/// target: a crash or a power cut can lose the new version, never leave a
/// truncated one in its place. `rename` replaces an existing destination on
/// every platform the app targets.
Future<void> writeJsonObjectAtomically(
    File file, Map<String, dynamic> data) async {
  final String payload;
  try {
    payload = _encoder.convert(data);
  } catch (e, st) {
    logError('Cannot serialize data for ${file.path}', e, st);
    throw StorageException('Data could not be serialized',
        path: file.path, cause: e);
  }

  final temp = File('${file.path}.tmp');
  try {
    await file.parent.create(recursive: true);
    await temp.writeAsString(payload, flush: true);
    await temp.rename(file.path);
  } catch (e, st) {
    logError('Cannot write ${file.path}', e, st);
    try {
      if (await temp.exists()) await temp.delete();
    } catch (_) {
      // Best effort: a leftover .tmp is harmless, it is overwritten next time.
    }
    throw StorageException('File could not be written',
        path: file.path, cause: e);
  }
}

/// Moves an unreadable file aside so the next write does not destroy it.
///
/// Returns the path it was moved to, or `null` if it could not be moved.
Future<String?> quarantineFile(File file) async {
  final stamp = DateTime.now()
      .toIso8601String()
      .replaceAll(RegExp(r'[:.]'), '-');
  final target = '${file.path}.corrupt-$stamp';
  try {
    await file.rename(target);
    logInfo('Quarantined unreadable file to $target');
    return target;
  } catch (e, st) {
    logError('Cannot quarantine ${file.path}', e, st);
    return null;
  }
}
