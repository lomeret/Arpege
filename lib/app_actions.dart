import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;

import 'state/editor_controller.dart';

void _toast(BuildContext context, String message) {
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(content: Text(message), duration: const Duration(seconds: 3)),
  );
}

/// Opens a PDF file picker then loads the chosen score.
Future<void> pickAndOpenPdf(BuildContext context, EditorController editor) async {
  final result = await FilePicker.platform.pickFiles(
    type: FileType.custom,
    allowedExtensions: ['pdf'],
    dialogTitle: 'Open a score',
  );
  final path = result?.files.single.path;
  if (path == null) return;
  try {
    await editor.openPdf(path);
  } catch (e) {
    if (context.mounted) _toast(context, 'Could not open the PDF: $e');
  }
}

/// Saves the annotations of the current PDF, with visual feedback.
Future<void> saveAnnotationsWithFeedback(
    BuildContext context, EditorController editor) async {
  if (editor.currentPdfPath == null) {
    _toast(context, 'No PDF loaded.');
    return;
  }
  final path = await editor.saveAnnotations();
  if (context.mounted && path != null) {
    _toast(context, 'Annotations saved');
  }
}

/// Loads an arbitrary annotations file (manual import).
Future<void> loadAnnotationsManually(
    BuildContext context, EditorController editor) async {
  if (editor.currentPdfPath == null) {
    _toast(context, 'Please load a PDF first.');
    return;
  }
  final result = await FilePicker.platform.pickFiles(
    type: FileType.custom,
    allowedExtensions: ['json'],
    dialogTitle: 'Load annotations',
  );
  final path = result?.files.single.path;
  if (path == null) return;
  try {
    await editor.loadAnnotationsFromPath(path);
  } catch (e) {
    if (context.mounted) _toast(context, 'Unreadable annotations file: $e');
  }
}

/// Exports the annotated PDF to a destination chosen by the user.
Future<void> exportCurrentPdf(
    BuildContext context, EditorController editor) async {
  if (editor.currentPdfPath == null) {
    _toast(context, 'Please load a PDF first.');
    return;
  }
  final defaultName =
      '${p.basenameWithoutExtension(editor.currentPdfPath!)}_annotated.pdf';
  String? dest = await FilePicker.platform.saveFile(
    dialogTitle: 'Export the annotated PDF',
    fileName: defaultName,
    type: FileType.custom,
    allowedExtensions: ['pdf'],
  );
  if (dest == null) return;
  if (!dest.toLowerCase().endsWith('.pdf')) dest = '$dest.pdf';
  try {
    await editor.exportPdf(dest);
    if (context.mounted) _toast(context, 'Annotated PDF exported');
  } catch (e) {
    if (context.mounted) _toast(context, 'Could not export: $e');
  }
}

/// Shows the list of recent files and opens the chosen one.
Future<void> showRecentFilesDialog(
    BuildContext context, EditorController editor) async {
  final recents = await editor.recentFiles.load();
  if (!context.mounted) return;
  final chosen = await showDialog<String>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: const Text('Recent files'),
      content: SizedBox(
        width: 420,
        child: recents.isEmpty
            ? const Text('(no recent files)')
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
                        Navigator.of(ctx).pop(path);
                      },
                    ),
                ],
              ),
      ),
      actions: [
        TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Close')),
      ],
    ),
  );
  if (chosen == null || !context.mounted) return;
  try {
    await editor.openPdf(chosen);
  } catch (e) {
    if (context.mounted) _toast(context, 'Could not open the PDF: $e');
  }
}

/// Whether exporting through a native file picker is plausible (desktop).
bool get canUseSaveDialog =>
    Platform.isWindows || Platform.isLinux || Platform.isMacOS;
