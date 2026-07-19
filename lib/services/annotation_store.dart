import 'dart:convert';
import 'dart:io';

import '../models/annotation_document.dart';
import 'paths.dart';

/// Lecture/écriture du fichier d'annotations propre à chaque PDF.
/// Schéma identique à l'ancien `main.py`.
class AnnotationStore {
  /// Charge les annotations associées à [pdfPath], ou `null` si aucun fichier.
  static Future<AnnotationDocument?> load(String pdfPath) async {
    final file = await AppPaths.annotationsFileFor(pdfPath);
    if (!await file.exists()) return null;
    final data = jsonDecode(await file.readAsString()) as Map<String, dynamic>;
    return AnnotationDocument.fromJson(data);
  }

  /// Charge un fichier d'annotations depuis un chemin arbitraire (import manuel).
  static Future<AnnotationDocument> loadFromPath(String jsonPath) async {
    final content = await File(jsonPath).readAsString();
    final data = jsonDecode(content) as Map<String, dynamic>;
    return AnnotationDocument.fromJson(data);
  }

  /// Lit la date de création existante pour la préserver lors des sauvegardes.
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
