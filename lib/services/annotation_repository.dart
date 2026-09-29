import 'dart:io';

import '../models/annotation_document.dart';
import 'json_file.dart';
import 'paths.dart';

/// An annotation document as it was found on disk.
///
/// [createdIso] is carried alongside the document so the original creation
/// date survives a save; it is not part of the editable model.
class StoredAnnotations {
  StoredAnnotations({required this.doc, this.createdIso});

  final AnnotationDocument doc;
  final String? createdIso;
}

/// Read/write of the annotations attached to a PDF.
abstract class AnnotationRepository {
  /// Loads the annotations for [pdfPath], or `null` if none were ever saved.
  /// Throws [StorageException] if a file exists but cannot be read.
  Future<StoredAnnotations?> load(String pdfPath);

  /// Loads an annotations file from an arbitrary path (manual import).
  Future<AnnotationDocument> import(String jsonPath);

  /// Persists [doc] and returns the path it was written to.
  Future<String> save({
    required String pdfPath,
    required AnnotationDocument doc,
    required int totalPages,
    String? createdIso,
  });
}

/// File-backed implementation. Keeps the schema of the old `main.py`, so
/// existing `<name>_annotations.json` files still load.
class FileAnnotationRepository implements AnnotationRepository {
  FileAnnotationRepository({StorageLocations? locations})
      : _locations = locations ?? AppPaths();

  final StorageLocations _locations;

  @override
  Future<StoredAnnotations?> load(String pdfPath) async {
    final file = await _locations.annotationsFileFor(pdfPath);
    final Map<String, dynamic>? data;
    try {
      data = await readJsonObject(file);
    } on StorageException {
      // Move the unreadable file aside: the next save must not silently
      // destroy annotations the user may still be able to recover by hand.
      await quarantineFile(file);
      rethrow;
    }
    if (data == null) return null;
    return StoredAnnotations(
      doc: AnnotationDocument.fromJson(data),
      createdIso: data['created_date'] as String?,
    );
  }

  @override
  Future<AnnotationDocument> import(String jsonPath) async {
    final data = await readJsonObject(File(jsonPath));
    if (data == null) {
      throw StorageException('File not found', path: jsonPath);
    }
    return AnnotationDocument.fromJson(data);
  }

  @override
  Future<String> save({
    required String pdfPath,
    required AnnotationDocument doc,
    required int totalPages,
    String? createdIso,
  }) async {
    final file = await _locations.annotationsFileFor(pdfPath);
    final name = pdfPath
        .split(RegExp(r'[\\/]'))
        .last
        .replaceAll(RegExp(r'\.pdf$', caseSensitive: false), '');
    final json = doc.toFileJson(
      pdfPath: pdfPath,
      pdfName: name,
      totalPages: totalPages,
      nowIso: DateTime.now().toIso8601String(),
      createdIso: createdIso,
    );
    await writeJsonObjectAtomically(file, json);
    return file.path;
  }
}
