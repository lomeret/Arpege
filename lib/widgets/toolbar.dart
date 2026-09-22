import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../app_actions.dart';
import '../pdf/pdf_renderer.dart';
import '../state/editor_controller.dart';
import '../theme.dart';
import 'page_order_dialog.dart';

/// Top toolbar (port of `build_toolbar` + menu entries).
class ArpegeToolbar extends StatelessWidget {
  final VoidCallback? onTogglePanels;
  /// Current state of the right-hand panels (lights up the toggle button).
  final bool panelsOpen;
  const ArpegeToolbar({super.key, this.onTogglePanels, this.panelsOpen = true});

  Future<void> _managePages(BuildContext context, EditorController editor) async {
    if (!editor.renderer.isOpen) return;
    final seq = editor.effectiveSequence.isEmpty
        ? editor.defaultSequence
        : editor.effectiveSequence;
    final result = await showPageOrderDialog(
      context,
      pageCount: editor.renderer.pageCount,
      sequence: List.of(seq),
      thumbProvider: editor.renderer.renderThumbnail,
    );
    if (result != null) editor.applyPageSequence(result);
  }

  @override
  Widget build(BuildContext context) {
    final editor = context.watch<EditorController>();
    final hasPdf = editor.currentPdfPath != null;

    return Container(
      height: 56,
      color: AppColors.mantle,
      padding: const EdgeInsets.symmetric(horizontal: 10),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            FilledButton.icon(
              style: FilledButton.styleFrom(
                  backgroundColor: AppColors.blue,
                  foregroundColor: AppColors.crust),
              icon: const Icon(Icons.folder_open, size: 18),
              label: const Text('Open'),
              onPressed: () => pickAndOpenPdf(context, editor),
            ),
            _sep(),
            _iconBtn(Icons.chevron_left, 'Previous page (←)',
                hasPdf ? editor.prevPage : null),
            _chip(editor.pageChipText, 86),
            _iconBtn(Icons.chevron_right, 'Next page (→)',
                hasPdf ? editor.nextPage : null),
            _sep(),
            _iconBtn(Icons.remove, 'Zoom out (Ctrl+-)',
                hasPdf ? editor.zoomOut : null),
            _ZoomChip(editor: editor),
            _iconBtn(Icons.add, 'Zoom in (Ctrl++)',
                hasPdf ? editor.zoomIn : null),
            _iconBtn(Icons.fit_screen, 'Fit to window (Ctrl+0)',
                hasPdf ? editor.fitView : null),
            _iconBtn(Icons.auto_stories, 'Manage pages',
                hasPdf ? () => _managePages(context, editor) : null),
            _ToggleBtn(
              icon: Icons.menu_book,
              tip: 'Two-page spread (Ctrl+D)',
              selected: editor.spreadView,
              onTap: hasPdf
                  ? () => editor.toggleSpread(!editor.spreadView)
                  : null,
            ),
            _sep(),
            _iconBtn(Icons.undo, 'Undo (Ctrl+Z)',
                editor.history.canUndo ? editor.undo : null),
            _iconBtn(Icons.redo, 'Redo (Ctrl+Y)',
                editor.history.canRedo ? editor.redo : null),
            const SizedBox(width: 24),
            Tooltip(
              message: editor.hasUnsavedChanges
                  ? 'Unsaved changes — save now (Ctrl+S)'
                  : 'Annotations saved (Ctrl+S)',
              child: FilledButton.icon(
                style: FilledButton.styleFrom(
                    backgroundColor: editor.hasUnsavedChanges
                        ? AppColors.peach
                        : AppColors.green,
                    foregroundColor: AppColors.crust),
                icon: Icon(
                    editor.hasUnsavedChanges ? Icons.save_as : Icons.save,
                    size: 18),
                label: const Text('Save'),
                onPressed: () => saveAnnotationsWithFeedback(context, editor),
              ),
            ),
            const SizedBox(width: 6),
            OutlinedButton.icon(
              icon: const Icon(Icons.ios_share, size: 18),
              label: const Text('Export'),
              onPressed: () => exportCurrentPdf(context, editor),
            ),
            _sep(),
            PopupMenuButton<String>(
              icon: const Icon(Icons.more_horiz),
              tooltip: 'More',
              onSelected: (v) {
                switch (v) {
                  case 'recent':
                    showRecentFilesDialog(context, editor);
                    break;
                  case 'load':
                    loadAnnotationsManually(context, editor);
                    break;
                  case 'clear':
                    editor.clearCurrentPage();
                    break;
                }
              },
              itemBuilder: (ctx) => const [
                PopupMenuItem(value: 'recent', child: Text('Recent files…')),
                PopupMenuItem(
                    value: 'load', child: Text('Load annotations…')),
                PopupMenuDivider(),
                PopupMenuItem(
                    value: 'clear', child: Text('Clear current page')),
              ],
            ),
            if (onTogglePanels != null)
              _ToggleBtn(
                icon: Icons.view_sidebar,
                tip: panelsOpen
                    ? 'Hide panels (F9)'
                    : 'Show panels (F9)',
                selected: panelsOpen,
                onTap: onTogglePanels,
              ),
          ],
        ),
      ),
    );
  }

  Widget _sep() => Container(
        width: 1,
        height: 28,
        margin: const EdgeInsets.symmetric(horizontal: 8),
        color: AppColors.surface0,
      );

  Widget _iconBtn(IconData icon, String tip, VoidCallback? onPressed) =>
      IconButton(icon: Icon(icon), tooltip: tip, onPressed: onPressed);

  Widget _chip(String text, double width) => Container(
        constraints: BoxConstraints(minWidth: width),
        margin: const EdgeInsets.symmetric(horizontal: 4),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          color: AppColors.surface0,
          borderRadius: BorderRadius.circular(9),
        ),
        alignment: Alignment.center,
        child: Text(text, style: const TextStyle(fontWeight: FontWeight.w600)),
      );
}

class _ZoomChip extends StatelessWidget {
  final EditorController editor;
  const _ZoomChip({required this.editor});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder(
      valueListenable: editor.viewTransform,
      builder: (context, matrix, _) {
        final scale = matrix.getMaxScaleOnAxis();
        final percent = scale * PdfRenderer.renderDpi / 72.0 * 100;
        final label = editor.currentPdfPath == null
            ? '—'
            : '${percent.toStringAsFixed(0)} %';
        return Container(
          constraints: const BoxConstraints(minWidth: 66),
          margin: const EdgeInsets.symmetric(horizontal: 4),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
          decoration: BoxDecoration(
            color: AppColors.surface0,
            borderRadius: BorderRadius.circular(9),
          ),
          alignment: Alignment.center,
          child: Text(label, style: const TextStyle(fontWeight: FontWeight.w600)),
        );
      },
    );
  }
}

class _ToggleBtn extends StatelessWidget {
  final IconData icon;
  final String tip;
  final bool selected;
  final VoidCallback? onTap;
  const _ToggleBtn(
      {required this.icon,
      required this.tip,
      required this.selected,
      required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tip,
      child: Material(
        color: selected ? AppColors.blue : Colors.transparent,
        borderRadius: BorderRadius.circular(9),
        child: InkWell(
          borderRadius: BorderRadius.circular(9),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(8),
            child: Icon(icon,
                color: selected ? AppColors.crust : AppColors.text),
          ),
        ),
      ),
    );
  }
}
