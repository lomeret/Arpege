import 'dart:convert';
import 'dart:io';

import '../models/annotation_document.dart';
import 'paths.dart';

/// Read/write of the annotations file specific to each PDF.
/// Same schema as the old `main.py`.
class AnnotationStore {
  /// Loads the annotations for [pdfPath], or `null` if no file exists.
  static Future<AnnotationDocument?> load(String pdfPath) async {
    final file = await AppPaths.annotationsFileFor(pdfPath);
    if (!await file.exists()) return null;
    final data = jsonDecode(await file.readAsString()) as Map<String, dynamic>;
    return AnnotationDocument.fromJson(data);
  }

  /// Loads an annotations file from an arbitrary path (manual import).
  static Future<AnnotationDocument> loadFromPath(String jsonPath) async {
    final content = await File(jsonPath).readAsString();
    final data = jsonDecode(content) as Map<String, dynamic>;
    return AnnotationDocument.fromJson(data);
  }

  /// Reads the existing creation date to preserve it across saves.
  static Future<String?> existingCreatedDate(String pdfPath) async {
    final file = await AppPaths.annotationsFileFor(pdfPath);
    if (!await file.exists()) return null;
    try {
      final data = jsonDecode(await file.readAsString()) as Map<String, dynamic>;
      return data['created_date'] as String?;
    } catch (_) {
      return null;
    }
  }

  static Future<String> save({
    required String pdfPath,
    required AnnotationDocument doc,
    required int totalPages,
    String? createdIso,
  }) async {
    final file = await AppPaths.annotationsFileFor(pdfPath);
    final name = pdfPath.split(RegExp(r'[\\/]')).last.replaceAll(RegExp(r'\.pdf$', caseSensitive: false), '');
    final json = doc.toFileJson(
      pdfPath: pdfPath,
      pdfName: name,
      totalPages: totalPages,
      nowIso: DateTime.now().toIso8601String(),
      createdIso: createdIso,
    );
    await file.writeAsString(const JsonEncoder.withIndent('  ').convert(json));
    return file.path;
  }
}
