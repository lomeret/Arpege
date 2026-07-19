import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;

import 'services/recent_files.dart';
import 'state/editor_controller.dart';

void _toast(BuildContext context, String message) {
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(content: Text(message), duration: const Duration(seconds: 3)),
  );
}

/// Ouvre un sélecteur de fichiers PDF puis charge la partition choisie.
Future<void> pickAndOpenPdf(BuildContext context, EditorController editor) async {
  final result = await FilePicker.platform.pickFiles(
    type: FileType.custom,
    allowedExtensions: ['pdf'],
    dialogTitle: 'Ouvrir une partition',
  );
  final path = result?.files.single.path;
  if (path == null) return;
  try {
    await editor.openPdf(path);
  } catch (e) {
    if (context.mounted) _toast(context, 'Impossible d\'ouvrir le PDF : $e');
  }
}

/// Sauvegarde les annotations du PDF courant, avec retour visuel.
Future<void> saveAnnotationsWithFeedback(
    BuildContext context, EditorController editor) async {
  if (editor.currentPdfPath == null) {
    _toast(context, 'Aucun PDF chargé.');
    return;
  }
  final path = await editor.saveAnnotations();
  if (context.mounted && path != null) {
    _toast(context, 'Annotations sauvegardées');
  }
}

/// Charge un fichier d'annotations arbitraire (import manuel).
Future<void> loadAnnotationsManually(
    BuildContext context, EditorController editor) async {
  if (editor.currentPdfPath == null) {
    _toast(context, 'Veuillez d\'abord charger un PDF.');
    return;
  }
  final result = await FilePicker.platform.pickFiles(
    type: FileType.custom,
    allowedExtensions: ['json'],
    dialogTitle: 'Charger des annotations',
  );
  final path = result?.files.single.path;
  if (path == null) return;
  try {
    await editor.loadAnnotationsFromPath(path);
  } catch (e) {
    if (context.mounted) _toast(context, 'Fichier d\'annotations illisible : $e');
  }
}

/// Exporte le PDF annoté vers une destination choisie par l'utilisateur.
Future<void> exportCurrentPdf(
    BuildContext context, EditorController editor) async {
  if (editor.currentPdfPath == null) {
    _toast(context, 'Veuillez d\'abord charger un PDF.');
    return;
  }
  final defaultName =
      '${p.basenameWithoutExtension(editor.currentPdfPath!)}_annote.pdf';
  String? dest = await FilePicker.platform.saveFile(
    dialogTitle: 'Exporter le PDF annoté',
    fileName: defaultName,
    type: FileType.custom,
    allowedExtensions: ['pdf'],
  );
  if (dest == null) return;
  if (!dest.toLowerCase().endsWith('.pdf')) dest = '$dest.pdf';
  try {
    await editor.exportPdf(dest);
    if (context.mounted) _toast(context, 'PDF annoté exporté');
  } catch (e) {
    if (context.mounted) _toast(context, 'Impossible d\'exporter : $e');
  }
}

/// Affiche la liste des fichiers récents et ouvre celui choisi.
Future<void> showRecentFilesDialog(
    BuildContext context, EditorController editor) async {
  final recents = await RecentFiles.load();
  if (!context.mounted) return;
  await showDialog<void>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: const Text('Fichiers récents'),
      content: SizedBox(
        width: 420,
        child: recents.isEmpty
            ? const Text('(aucun fichier récent)')
            : Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  for (final path in recents)
                    ListTile(
                      dense: true,
                      title: Text(p.basename(path)),
                      subtitle: Text(path,
                          maxLines: 1, overflow: TextOverflow.ellipsis),
                      onTap: () {
                        Navigator.of(ctx).pop();
                        editor.openPdf(path);
                      },
                    ),
                ],
              ),
      ),
      actions: [
        TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Fermer')),
      ],
    ),
  );
}

/// Indique si l'export via sélecteur natif est plausible (desktop).
bool get canUseSaveDialog =>
    Platform.isWindows || Platform.isLinux || Platform.isMacOS;
